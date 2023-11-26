init_build_system :: () {
    assert(build_buffer_id < 0 && build_editor_id < 0, "Build system already initialised");

    build_buffer_id = find_or_create_an_empty_buffer();
    build_editor_id = find_or_create_editor(build_buffer_id);
    editor, buffer := *open_editors[build_editor_id], *open_buffers[build_buffer_id];
    editor.line_wrap = .on;
    buffer.readonly = true;
    buffer.deleted  = true;  // so that it doesn't appear in the open file dialog

    init(*output_mutex);

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
        add_user_warning(tprint("Build command [%] is still running", running_command.name), dismiss_in_seconds = 5, tag = .build);
        return;
    }

    // TODO: validate mandatory fields etc

    log("Executing build command [%]\n", command.name);
    print_to_output_panel_from_main_thread(tprint("[%]\n", command.name));

    allocator := get_pool_allocator();
    push_allocator(allocator);

    running_command = New(Build_Command);
    running_command.* = command.*;
    running_command.name              = copy_string(command.name);
    running_command.build_command     = copy_string(command.build_command);
    running_command.build_working_dir = copy_string(command.build_working_dir);
    running_command.run_command       = copy_string(command.run_command);
    running_command.run_working_dir   = copy_string(command.run_working_dir);
    running_command.error_regex       = copy_string(command.error_regex);

    if command.open_panel_on_build then build_panel_is_shown = true;

    add_work(*thread_group, running_command);
    // Now don't modify running_command as it's being accessed from thread
}

build_system_update :: () {
    assert(build_buffer_id >= 0 && build_editor_id >= 0, "Build system is not initialized");

    results := get_completed_work(*thread_group);
    if results {
        // We only process one command at a time, so this means our running command has finished
        assert(running_command != null, "Build thread has finished work, but no command running");
        assert(results.count == 1 && results[0] == running_command, "Build thread command mismatch");

        log("Build command [%] finished\n", running_command.name);

        if running_command.close_panel_on_success {
            // TODO: if exit code is not 0 or there are errors, that shouldn't be a success?
            build_panel_is_shown = false;
        }

        running_command = null;
        reset(*memory_pool);
    }

    // Print to build output panel, if we have anything to print
    {
        lock(*output_mutex);
        defer unlock(*output_mutex);

        output := builder_to_string(*stdout);
        print_to_output_panel_from_main_thread(output);

        error_output := builder_to_string(*stderr);
        print_to_output_panel_from_main_thread(error_output);
    }
}

print_to_output_panel_from_main_thread :: (s: string) {
    assert(build_buffer_id >= 0 && build_editor_id >= 0);
    if !s return;

    buffer := *open_buffers[build_buffer_id];
    insert_string_raw(buffer, buffer.bytes.count, s);

    editor := *open_editors[build_editor_id];
    cursor := leave_only_original_cursor(editor);
    cursor.pos = xx buffer.bytes.count;
    cursor.sel = cursor.pos;
    editor.scroll_to_cursor = .yes;
}

toggle_build_panel :: () {
    build_panel_is_shown = !build_panel_is_shown;
}

toggle_build_panel_height :: () {
    // TODO
}

build_panel_get_editor_id :: inline () -> s64 {
    assert(build_editor_id >= 0);
    return build_editor_id;
}

build_panel_is_shown := false;


#scope_file

build_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    command := cast(*Build_Command) work;

    log("Executing build command [%]\n", command.name);

    allocator := get_pool_allocator();
    push_allocator(allocator);

    result, timeout_reached := run_command_while_monitoring_output(
        ..break_command_into_strings(command.build_command),
        working_directory = command.build_working_dir,
        timeout_ms = command.timeout_in_seconds * 1000,
    );

    platform_wake_up_main_thread();

    return .CONTINUE;
}

get_pool_allocator :: () -> Allocator {
    a: Allocator;
    a.proc = flat_pool_allocator_proc;
    a.data = *memory_pool;
    return a;
}

thread_group: Thread_Group;

build_buffer_id := -1;
build_editor_id := -1;

running_command: *Build_Command = null;

memory_pool: Flat_Pool;

// To avoid potential crashes, the build thread will not write directly to the output buffer because it could be
// used by the main thread at the same time, and instead will use these string builders to buffer output,
// which the main thread will pick up at its convenience.
// We never write to buffers from threads, because if we did, a lot of code would have to be littered with locks.
stdout: String_Builder;
stderr: String_Builder;
output_mutex: Mutex;


#scope_file

// Adapted the run_command function from the Process module to allow for monitoring output

run_command_while_monitoring_output :: (args: .. string, working_directory := "", timeout_ms := -1, arg_quoting := Process_Argument_Quoting.QUOTE_IF_NEEDED) -> (process_result: Process_Result, timeout_reached := false) {
    process: Process;
    launched := create_process(*process, .. args, working_directory, capture_and_return_output = true, arg_quoting = arg_quoting);
    if !launched return .{type = .FAILED_TO_LAUNCH};
    defer deinit(*process);

    timeout_reached := false;

    // A string builder to buffer error output so that we can print it out at the end
    error_builder:  String_Builder;

    start_time := current_time_monotonic();
    remaining_timeout_ms := timeout_ms;

    while true {
        output_buffer, error_buffer: [4096] u8;
        success, num_output_bytes, num_error_bytes := read_from_process(*process, output_buffer, error_buffer, remaining_timeout_ms);

        if num_output_bytes {
            write_output_from_build_thread(*stdout, to_string(output_buffer.data, num_output_bytes));
        }

        if num_error_bytes {
            append(*error_builder, to_string(error_buffer.data, num_error_bytes));
        }

        if !success {
            log_error("Could not read output of command \"%\"", get_quoted_command_string(args));
            kill_process(*process);
            break;
        }

        if timeout_ms >= 0 {
            now := current_time_monotonic();
            remaining_timeout_ms = timeout_ms - to_milliseconds(now - start_time);

            if remaining_timeout_ms <= 0 {
                // We’ve hit a timeout! Time to kill the child. (will be reaped below)
                timeout_reached = true;
                success := kill_process(*process);
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

    success, process_result := get_process_result(*process);
    if !success {
        error_code, error_string := System.get_error_value_and_string();
        log_error("Could not get process result for command \"%\": % %", get_quoted_command_string(args), error_code, error_string);
        kill_process(*process);
        process_result = .{type = .EXITED, exit_code = 1};
    }

    return process_result, timeout_reached;
}

write_output_from_build_thread :: (builder: *String_Builder, s: string) {
    if !s return;
    lock(*output_mutex);
    defer unlock(*output_mutex);
    append(builder, s);
}

System :: #import "System";