init_build_system :: () {
    assert(build_buffer_id < 0 && build_editor_id < 0, "Build system already initialised");

    build_buffer_id = find_or_create_an_empty_buffer();
    build_editor_id = find_or_create_editor(build_buffer_id);
    editor, buffer := *open_editors[build_editor_id], *open_buffers[build_buffer_id];
    buffer.readonly = true;
    buffer.deleted  = true;  // so that it doesn't appear in the open file dialog
    insert_string_raw(buffer, 0, "vasia pupkin");

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

    add_work(*thread_group, running_command);
    // Now don't modify running_command as it's being accessed from thread
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

    print("Hello from thread, executing the command [%]:\n%\n", command.name, command.*);

    result, output, error, timeout_reached := run_command_while_monitoring_output(
        ..break_command_into_strings(command.build_command),
        working_directory = command.build_working_dir,
    );

    // TODO: remove
    running_command = null;

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


#scope_file

// Adapted the run_command function from the Process module to allow for monitoring output

run_command_while_monitoring_output :: (args: .. string, working_directory := "", timeout_ms := -1, arg_quoting := Process_Argument_Quoting.QUOTE_IF_NEEDED) -> (process_result: Process_Result, output_string := "", error_string := "", timeout_reached := false) {
    process: Process;
    launched := create_process(*process, .. args, working_directory, capture_and_return_output = true, arg_quoting = arg_quoting);
    if !launched return .{type = .FAILED_TO_LAUNCH};

    defer deinit(*process);

    timeout_reached := false;

    output_builder: String_Builder;
    error_builder:  String_Builder;

    start_time := current_time_monotonic();
    remaining_timeout_ms := timeout_ms;

    while true {
        output_buffer := ensure_contiguous_space_and_return_available_range(*output_builder);
        error_buffer  := ensure_contiguous_space_and_return_available_range(*error_builder);

        success, num_output_bytes, num_error_bytes := read_from_process(*process, output_buffer, error_buffer, remaining_timeout_ms);

        if num_output_bytes {
            advance_through_ensured_space(*output_builder, num_output_bytes);
            print("[o]%\n", to_string(output_buffer.data, num_output_bytes));
        }

        if num_error_bytes {
            advance_through_ensured_space(*error_builder, num_error_bytes);
            print("[e]\n%", to_string(error_buffer.data, num_error_bytes));
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

        if process.output.eof && process.error.eof    break;
    }

    output_string := builder_to_string(*output_builder);
    error_string  := builder_to_string(*error_builder);

    success, process_result := get_process_result(*process);
    if !success {
        error_code, error_string := System.get_error_value_and_string();
        log_error("Could not get process result for command \"%\": % %", get_quoted_command_string(args), error_code, error_string);
        kill_process(*process);
        process_result = .{type = .EXITED, exit_code = 1};
    }

    return process_result, output_string, error_string, timeout_reached;
}

System :: #import "System";