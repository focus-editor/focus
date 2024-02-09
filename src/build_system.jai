init_build_system :: () {
    assert(build_buffer_id < 0 && build_editor_id < 0, "Build system already initialised");

    build_buffer_id = find_or_create_an_empty_buffer();
    build_editor_id = find_or_create_editor(build_buffer_id);
    editor, buffer := *open_editors[build_editor_id], *open_buffers[build_buffer_id];
    buffer.readonly = true;
    buffer.deleted  = true;  // so that it doesn't appear in the open file dialog
    if config.settings.build_panel_line_wrap_always_on then editor.line_wrap = .on; else editor.line_wrap = .off;

    init(*build_mutex);

    thread_group = Thread_Group.{};  // in case we need to reinitialise it later
    init(*thread_group, num_threads = 1, group_proc = build_threadproc);
    start(*thread_group);
}

deinit_build_system :: () {
    assert(build_buffer_id >= 0 && build_editor_id >= 0, "Build system is not initialized");
    shutdown(*thread_group);

    // Assuming that the editor and the buffer will be cleaned up separately
    build_buffer_id = -1;
    build_editor_id = -1;
    running_command = null;
}

execute_build_command :: (command: *Build_Command) {
    if running_command != null {
        add_user_warning("Build command [%] is still running", running_command.name, dismiss_in_seconds = 5, tag = .build);
        return;
    }

    // Validate command
    {
        using command;
        if build_working_dir {
            if contains(build_working_dir, "\\") {
                build_working_dir = copy_string(build_working_dir);  // @leak
                path_overwrite_separators(build_working_dir, #char "/");
                build_working_dir = trim_right(build_working_dir, "/");
            }
            is_dir, success := is_directory(build_working_dir);
            if !is_dir || !success then add_user_warning("Build directory '%' doesn't seem to be a valid directory", build_working_dir);
        }
        if run_working_dir {
            if contains(run_working_dir, "\\") {
                run_working_dir = copy_string(run_working_dir);  // @leak
                path_overwrite_separators(run_working_dir, #char "/");
                run_working_dir = trim_right(run_working_dir, "/");
            }
            is_dir, success := is_directory(run_working_dir);
            if !is_dir || !success then add_user_warning("Run directory '%' doesn't seem to be a valid directory", run_working_dir);
        }
        if !build_command && !run_command {
            add_user_error("Can't run [%]:\nbuild_command or run_command must be specified in the config", name);
            return;
        }
    }

    log("Executing build command [%]\n", command.name);

    // Add an empty line between commands
    if last_command_result.finished then print_to_output_panel_from_main_thread("\n");

    if command.clear_build_output_before_running then build_clear_output();

    last_command_result = .{};

    print_to_output_panel_from_main_thread(tprint("%\n", command.name), mark_as = .header);

    allocator := Allocator.{ proc = flat_pool_allocator_proc, data = *memory_pool };
    push_allocator(allocator);

    running_command = New(Build_Command);
    running_command.* = command.*;
    running_command.name              = copy_string(command.name);
    running_command.build_command     = copy_string(command.build_command);
    running_command.build_working_dir = copy_string(command.build_working_dir);
    running_command.run_command       = copy_string(command.run_command);
    running_command.run_working_dir   = copy_string(command.run_working_dir);
    running_command.error_regex       = copy_string(command.error_regex);

    // We never want a timeout of 0 seconds because the command will never run.
    // People probably expect 0 to be no timeout, so we convert it to -1, which means no timeout
    if command.timeout_in_seconds == 0 then running_command.timeout_in_seconds = -1;

    if command.open_panel_on_build {
        show_build_panel();
    } else if !build_panel_is_shown {
        add_success_message("Running [%]…", running_command.name, dismiss_in_seconds = 3);
    }

    add_work(*thread_group, running_command);
    // Now don't modify running_command as it's being accessed from thread
}

build_clear_output :: () {
    if build_buffer_id < 0 return;
    editor, buffer := get_build_editor_and_buffer();

    array_reset_keeping_memory(*buffer.regions);  // TODO: should we lock buffer content_lock before accessing this?
    delete_range_raw(buffer, 0, buffer.bytes.count);
    rescan_for_lines(buffer);
    rescan_for_wrapped_lines(editor, buffer);
}

build_kill_running_command :: () {
    if !running_command {
        add_user_warning("No command is currently running", dismiss_in_seconds = 3);
        return;
    }
    lock(*build_mutex);
    kill_process(*running_process);
    unlock(*build_mutex);
}

build_system_update :: () {
    assert(build_buffer_id >= 0 && build_editor_id >= 0, "Build system is not initialized");

    // Print to build output panel, if we have anything to print
    {
        lock(*build_mutex);
        defer unlock(*build_mutex);

        output := builder_to_string(*stdout);
        print_to_output_panel_from_main_thread(output);

        error_output := builder_to_string(*stderr);
        print_to_output_panel_from_main_thread(error_output);
    }

    // Check if a command has finished executing
    results := get_completed_work(*thread_group);
    if results {
        // We only process one command at a time, so this means our running command has finished
        assert(running_command != null, "Build thread has finished work, but no command running");
        assert(results.count == 1 && results[0] == running_command, "Build thread command mismatch");

        log("Build command [%] finished\n", running_command.name);

        assert(last_command_result.finished);

        message: string;
        kind: Buffer_Region.Kind = .none;

        result := ifx last_command_result.run.finished then last_command_result.run else last_command_result.build;
        failed_command := ifx last_command_result.run.finished then running_command.run_command else running_command.build_command;

        if result.timeout_reached {
            message = tprint("TIMED OUT after % seconds", running_command.timeout_in_seconds);
            kind = .warning;
        } else {
            if #complete result.process_result.type == {
                case .UNSTARTED; #through;
                case .FAILED_TO_LAUNCH;
                    message = tprint("ERROR: couldn't launch '%'", failed_command);
                    if !is_absolute_path(failed_command) then message = tprint("%. Try specifying a full path to the executable.", message);
                    kind = .error;
                case .STILL_RUNNING;
                    message = "ERROR: the command is still running. This is a bug.";
                    kind = .error;
                case .SIGNALED;
                    message = tprint("ERROR: the process signaled %", result.process_result.signal);
                    kind = .error;
                case .EXITED;
                    exit_code := result.process_result.exit_code;
                    if exit_code != 0 {
                        message = tprint("ERROR: exit code %", exit_code);
                        kind = .error;
                    } else {
                        message = "DONE";
                        kind = .success;
                    }
            }
        }

        print_to_output_panel_from_main_thread(tprint("%\n", message), mark_as = kind, add_newline_if_missing = true);

        if kind == .success {
            if running_command.close_panel_on_success then hide_build_panel();
            if !running_command.open_panel_on_build   then add_success_message("Finished [%]", running_command.name, dismiss_in_seconds = 3);
        } else {
            // Always show the panel on errors
            show_build_panel();
        }

        running_command = null;
        reset(*memory_pool);
    }
}

toggle_build_panel :: () {
    if build_panel_is_shown {
        hide_build_panel();
    } else {
        show_build_panel();
    }
}

show_build_panel :: () {
    // Maybe hide other popups
    if #complete active_global_widget == {
        case .editors;                  // nothing to do

        case .unsaved_buffers_dialog;   // do nothing, we still want to see them
        case .confirm_overwrite_dialog; // do nothing, we still want to see them

        case .open_file_dialog;         #through;
        case .delete_file_dialog;       #through;
        case .finder;                   #through;
        case .go_to_line_dialog;        #through;
        case .open_project_dialog;      #through;
        case .theme_dialog;             #through;
        case .commands_dialog;          active_global_widget = .editors;
    }
    if !build_panel_is_shown {
        previously_active_editor = editors.active;
    }
    build_panel_is_shown = true;
}

hide_build_panel :: () {
    if editors.active != editors.left && editors.active != editors.right && editors.left >= 0 && editors.right >= 0 {
        // If we still have the same editors open when the panel was opened, go back to the previously active one,
        // otherwise default to left.
        make_editor_active(ifx previously_active_editor == editors.right then editors.right else editors.left);
    }
    build_panel_is_shown = false;
}

toggle_build_panel_height :: () {
    target := ifx build_panel_is_expanded then config.settings.build_panel_height_percent / 100.0 else 1.0;
    target = clamp(target, 0.1, 1.0);

    if !config.settings.disable_file_open_close_animations {
        start_animation(*build_panel_height_anim, build_panel_height, target);
    } else {
        build_panel_height_anim.target = target;
        build_panel_height = target;
    }
    build_panel_is_expanded = !build_panel_is_expanded;
}

build_panel_set_height :: (height: float) {
    height = clamp(height, 0.1, 1.0);
    build_panel_height_anim.target = height;
    build_panel_height = height;
    build_panel_is_expanded = !(height < 1.0);
}

build_panel_set_width :: (width: float) {
    build_panel_width = clamp(width, 0.1, 1.0);
}

build_panel_get_position :: () -> Build_Panel_Position {
    if config.settings.build_panel_stays_in_one_place return .right;

    if #complete editors.layout == {
        case .None;     saved_position = .right;
        case .Single;   saved_position = .right;
        case .Double;   if editor_closing then saved_position = .right;
                        else if editors.active == editors.left  then saved_position = .right;
                        else if editors.active == editors.right then saved_position = .left;
    }
    return saved_position;
}

build_panel_is_active :: inline () -> bool {
    return build_panel_is_shown && build_editor_id >= 0 && editors.active == build_editor_id;
}

build_panel_get_editor_id :: inline () -> s64 {
    assert(build_editor_id >= 0);
    return build_editor_id;
}

build_panel_set_line_wrap :: (enable: bool) {
    if build_editor_id < 0 return;
    editor := *open_editors[build_editor_id];
    if  enable && editor.line_wrap == .off then editor.line_wrap = .to_enable;
    if !enable && editor.line_wrap == .on  then editor.line_wrap = .to_disable;
}

build_panel_is_shown := false;

build_panel_width:  float = 0.5;
build_panel_height: float = 0.5;
build_panel_height_anim: Tween_Animation(float);


#scope_file

get_build_editor_and_buffer :: () -> *Editor, *Buffer {
    assert(build_buffer_id >= 0 && build_editor_id >= 0);

    buffer := *open_buffers[build_buffer_id];
    editor := *open_editors[build_editor_id];

    return editor, buffer;
}

build_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    command := cast(*Build_Command) work;

    log("Executing build command [%]\n", command.name);

    allocator := Allocator.{ proc = flat_pool_allocator_proc, data = *memory_pool };
    push_allocator(allocator);

    defer {
        // Writing to a global var here and below but it's OK because it won't be accessed until the thread is done
        last_command_result.finished = true;
        platform_wake_up_main_thread();
    }

    if command.build_command {
        write_output_from_build_thread(*stdout, tprint("> %\n", command.build_command));

        result, timeout_reached := run_command_while_monitoring_output(
            ..break_command_into_strings(command.build_command),
            working_directory = command.build_working_dir,
            timeout_ms = command.timeout_in_seconds * 1000,
        );

        last_command_result.build = .{ finished = true, timeout_reached = timeout_reached, process_result = result };

        // Don't run the run command if failed
        if result.type != .EXITED || result.exit_code != 0 return .CONTINUE;
    }

    if command.run_command {
        // Run if the build command has succeeded or doesn't exist
        if command.build_command then write_output_from_build_thread(*stdout, "\n");
        write_output_from_build_thread(*stdout, tprint("> %\n", command.run_command));

        result, timeout_reached := run_command_while_monitoring_output(
            ..break_command_into_strings(command.run_command),
            working_directory = command.run_working_dir,
        );
        last_command_result.run = .{ finished = true, timeout_reached = timeout_reached, process_result = result };
    }

    return .CONTINUE;
}

print_to_output_panel_from_main_thread :: (s: string, mark_as: Buffer_Region.Kind = .none, add_newline_if_missing := false) {
    if !s return;

    editor, buffer := get_build_editor_and_buffer();

    if add_newline_if_missing && buffer.bytes.count > 0 && buffer.bytes[buffer.bytes.count-1] != #char "\n" {
        insert_string_raw(buffer, buffer.bytes.count, "\n");
    }

    start := cast(s32) buffer.bytes.count;
    insert_string_raw(buffer, buffer.bytes.count, s);
    end   := cast(s32) buffer.bytes.count;

    cursor := leave_only_original_cursor(editor);
    cursor.pos = xx buffer.bytes.count;
    cursor.sel = cursor.pos;
    editor.scroll_to_cursor = .yes;

    if mark_as != .none {
        array_add(*buffer.regions, Buffer_Region.{ start = start, end = end, kind = mark_as });
    }

    // Maybe forget some bytes at the beginning
    if buffer.bytes.count > MAX_BUILD_OUTPUT_BUFFER_SIZE {
        bytes_to_forget := cast(s32) (buffer.bytes.count - MAX_BUILD_OUTPUT_BUFFER_SIZE);
        delete_range_raw(buffer, 0, bytes_to_forget);
        for * region : buffer.regions {
            region.start -= bytes_to_forget;
            region.end   -= bytes_to_forget;
            if region.start < 0 || region.end < 0 then remove region;  // will have to sort later because they must be sorted
        }
        compare_regions :: (r1: Buffer_Region, r2: Buffer_Region) -> s64 {
            return r1.start - r2.start;
        }
        quick_sort(buffer.regions, compare_regions);
    }
}

thread_group: Thread_Group;

build_buffer_id := -1;
build_editor_id := -1;

previously_active_editor := -1;
saved_position := Build_Panel_Position.right;

build_panel_is_expanded := false;

running_command: *Build_Command = null;
running_process: Process;

last_command_result: struct {
    build: Command_Result;
    run:   Command_Result;
    finished := false;
};

memory_pool: Flat_Pool;

// To avoid potential crashes, the build thread will not write directly to the output buffer because it could be
// used by the main thread at the same time, and instead will use these string builders to buffer output,
// which the main thread will pick up at its convenience.
// We never write to buffers from threads, because if we did, a lot of code would have to be littered with locks.
stdout: String_Builder;
stderr: String_Builder;
build_mutex: Mutex;

Build_Panel_Position :: enum { left; right; }

Command_Result :: struct {
    finished:        bool;
    timeout_reached: bool;
    process_result:  Process_Result;
}

MAX_BUILD_OUTPUT_BUFFER_SIZE :: 6 * 1024 * 1024;


#scope_file

// Adapted the run_command function from the Process module to allow for monitoring output

run_command_while_monitoring_output :: (args: .. string, working_directory := "", timeout_ms := -1, arg_quoting := Process_Argument_Quoting.QUOTE_IF_NEEDED) -> (process_result: Process_Result, timeout_reached := false) {
    process  := *running_process;  // accessing a global! NOTE: this is assuming we only ever have one running command
    lock(*build_mutex);
    process.* = Process.{};
    unlock(*build_mutex);

    launched := create_process(process, .. args, working_directory, capture_and_return_output = true, arg_quoting = arg_quoting);
    if !launched {
        executable := args[0];
        if is_absolute_path(executable) return .{type = .FAILED_TO_LAUNCH};
        // Retry with an absolute path if possible
        args[0] = tprint("%/%", working_directory, executable);
        launched := create_process(process, .. args, working_directory, capture_and_return_output = true, arg_quoting = arg_quoting);
        if !launched return .{type = .FAILED_TO_LAUNCH};
    }
    defer {
        lock(*build_mutex);
        deinit(process);
        unlock(*build_mutex);
    }

    timeout_reached := false;

    // A string builder to buffer error output so that we can print it out at the end
    error_builder:  String_Builder;

    start_time := current_time_monotonic();
    remaining_timeout_ms := timeout_ms;

    while true {
        output_buffer, error_buffer: [4096] u8;
        success, num_output_bytes, num_error_bytes := read_from_process(process, output_buffer, error_buffer, remaining_timeout_ms);

        if num_output_bytes {
            write_output_from_build_thread(*stdout, to_string(output_buffer.data, num_output_bytes));
            platform_wake_up_main_thread();
        }

        if num_error_bytes {
            append(*error_builder, to_string(error_buffer.data, num_error_bytes));
        }

        if !success {
            log_error("Could not read output of command \"%\"", get_quoted_command_string(args));
            kill_process(process);
            break;
        }

        if timeout_ms >= 0 {
            now := current_time_monotonic();
            remaining_timeout_ms = timeout_ms - to_milliseconds(now - start_time);

            if remaining_timeout_ms <= 0 {
                // We’ve hit a timeout! Time to kill the child. (will be reaped below)
                timeout_reached = true;
                success := kill_process(process);
                if !success {
                    error_code, error_string := System.get_error_value_and_string();
                    log_error("Could not kill child for command \"%\": % %", get_quoted_command_string(args), error_code, error_string);
                }
                break;
            }
        }

        if process.output.eof && process.error.eof break;
    }

    // Print error output
    write_output_from_build_thread(*stderr, builder_to_string(*error_builder));

    success, process_result := get_process_result(process);
    if !success {
        error_code, error_string := System.get_error_value_and_string();
        log_error("Could not get process result for command \"%\": % %", get_quoted_command_string(args), error_code, error_string);
        kill_process(process);
        process_result = .{type = .EXITED, exit_code = 1};
    }

    return process_result, timeout_reached;
}

write_output_from_build_thread :: (builder: *String_Builder, s: string) {
    if !s return;
    lock(*build_mutex);
    defer unlock(*build_mutex);
    append(builder, s);
}

#if OS == .WINDOWS {
    // A copy of the standard create_process function from the Process module, which passes CREATE_NO_WINDOW to avoid creating a cmd window
    create_process :: (process: *Process, args: .. string, working_directory := "", capture_and_return_output := false, arg_quoting := Process_Argument_Quoting.QUOTE_IF_NEEDED, kill_process_if_parent_exits := true) -> success: bool {
        startup_info: STARTUPINFOW;
        startup_info.cb = size_of(type_of(startup_info));

        child_input_read:   HANDLE;
        child_output_write: HANDLE;
        child_error_write:  HANDLE;

        if capture_and_return_output {
            success: bool;
            success, child_input_read = init_named_pipe_pair(*process.input, is_input = true);
            success, child_output_write = init_named_pipe_pair(*process.output, is_input = false);
            success, child_error_write = init_named_pipe_pair(*process.error, is_input = false);

            startup_info.dwFlags = STARTF_USESTDHANDLES;
            startup_info.hStdInput = child_input_read;
            startup_info.hStdOutput = child_output_write;
            startup_info.hStdError  = child_error_write;
            // startup_info.hStdInput  = GetStdHandle(STD_INPUT_HANDLE);
            // startup_info.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
            // startup_info.hStdError  = GetStdHandle(STD_ERROR_HANDLE);
        }

        defer {
            if capture_and_return_output {
                // Close our copies of the write handles (so that we receive EOF when the child closes them too)
                CloseHandle(child_input_read);
                CloseHandle(child_output_write);
                CloseHandle(child_error_write);
            }
        }

        args_string : string = ---;
        if #complete arg_quoting == {
            case .QUOTE_IF_NEEDED;
                args_string = get_quoted_command_string(args);
            case .NEVER_QUOTE;
                args_string = join(..args, separator=" ");
        }

        if kill_process_if_parent_exits {
            // Create a "Job Object" so that the process gets cleaned up if the parent process (=we) exits for some reason.
            // If we don't do this, the child might live on.
            process.job_handle = CreateJobObjectA(null, null);
            if !process.job_handle {
                error_value, error_string := System.get_error_value_and_string();
                log_error("Could not create Windows Job Object: % %", error_value, error_string);
                process.job_handle = INVALID_HANDLE_VALUE;
                deinit(process);
                return false;
            }

            job_info: JOBOBJECT_EXTENDED_LIMIT_INFORMATION;
            job_info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
            success := SetInformationJobObject(process.job_handle, .ExtendedLimitInformation, *job_info, size_of(type_of(job_info)));
            if !success {
                error_value, error_string := System.get_error_value_and_string();
                log_error("Could not configure Windows Job Object: % %", error_value, error_string);
                deinit(process);
                return false;
            }
        }

        // The first argument to CreateProcessW is null, because that is what causes it to
        // search the PATH environment variable to find the thing to run.

        // Do not use CREATE_NO_WINDOW in dwCreationFlags, because if you do, it will mysteriously make the process not inherit
        // console handles. The documentation did not appear to say anything about this, but then again
        // the documentation is contradictory and confusing. Okay, well, if you dig into Process Creation Flags
        // on some other page, it tells you this is not a good idea. Yeah well. Okay.

        success := CreateProcessW(null, utf8_to_wide_new(args_string,, temp), null, null, cast(BOOL) 1, CREATE_NO_WINDOW, null, utf8_to_wide_new(working_directory,, temp), *startup_info, *process.info);
        if !success {
            error_value, error_string := System.get_error_value_and_string();
            log_error("While running the command: '%', we were unable to create the process. Error code: %, description: %\n",
                      get_quoted_command_string(args), error_value, error_string);
            deinit(process);
            return false;
        }

        if kill_process_if_parent_exits {
            success = AssignProcessToJobObject(process.job_handle, process.info.hProcess);
            if !success {
                error_value := GetLastError();

                // Check if the program exited so quickly that we couldn't assign it fast enough:
                already_done := false;
                if error_value == ERROR_ACCESS_DENIED {
                    success, result := get_process_result(process, 0);
                    if result.type == .EXITED already_done = true;
                }

                if !already_done {
                    error_string := System.get_error_string(error_value);
                    log_error("Could not assign process % to Windows Job Object %: % %", process.info.hProcess, process.job_handle, error_value, error_string);
                    // We could decide to not fail in this case, but this might leave dangling processes around.
                    // The Right Thing(tm) depends on the exact error, so we will make these decisions whenever we discover a new error condition.
                    // -rluba 2022-12-06
                    deinit(process);
                    return false;
                }
            }
        }

        if capture_and_return_output {
            success := issue_read(*process.output);
            if !success {
                error_code, error_string := System.get_error_value_and_string();
                log_error("Couldn't start overlapped IO for standard output: % %", error_code, error_string);
                deinit(process);
                return false;
            }

            success = issue_read(*process.error);
            if !success {
                error_code, error_string := System.get_error_value_and_string();
                log_error("Couldn't start overlapped IO for standard error: % %", error_code, error_string);
                deinit(process);
                return false;
            }
        }

        return true;
    }

    issue_read :: (pipe: *Process.Pipe) -> bool {
        result := ReadFile(pipe.handle, null, 0, null, pipe.overlapped); // :ProcessPointers
        if result == 0 && GetLastError() != ERROR_IO_PENDING    return false;

        return true;
    }
}

System :: #import "System";