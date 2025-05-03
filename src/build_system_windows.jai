// Only reads from process.output (the original also reads from process.error)
read_from_process :: (process: *Process, output_buffer: [] u8, timeout_ms := -1) -> success: bool, output_bytes: int {
    if process.output.eof && process.error.eof    return false, 0;

    handles: [1] HANDLE = ---;
    num_handles: u32 = 0;

    if !process.output.eof {
        handles[num_handles] = process.output.overlapped.hEvent;
        num_handles += 1;
    }

    wait_timeout := INFINITE;
    if timeout_ms >= 0  wait_timeout = cast(u32) timeout_ms;

    wait_result := WaitForMultipleObjects(num_handles, handles.data, 0, wait_timeout);
    if wait_result >= num_handles && wait_result != WAIT_TIMEOUT {
        log_error("Unable to read command's output.\n");
        return false, 0;
    }

    success := true;
    output_bytes: int;
    if !process.output.eof {
        read_success: bool;
        read_success, output_bytes = read_pipe(*process.output, output_buffer);
        success &&= read_success;
    }

    return success, output_bytes;
}

// Also passes CREATE_NO_WINDOW to avoid creating a cmd window
create_process_with_single_output_pipe :: (process: *Process, args: .. string, working_directory := "", arg_quoting := Process_Argument_Quoting.QUOTE_IF_NEEDED, kill_process_if_parent_exits := true) -> success: bool {
    startup_info: STARTUPINFOW;
    startup_info.cb = size_of(type_of(startup_info));

    child_input_read:   HANDLE;
    child_output_write: HANDLE;

    {
        success: bool;
        success, child_input_read   = init_named_pipe_pair(*process.input, is_input = true);
        success, child_output_write = init_named_pipe_pair(*process.output, is_input = false);

        startup_info.dwFlags = STARTF_USESTDHANDLES;
        startup_info.hStdInput = child_input_read;
        startup_info.hStdOutput = child_output_write;
        startup_info.hStdError  = child_output_write;
    }

    defer {
        // Close our copies of the write handles (so that we receive EOF when the child closes them too)
        CloseHandle(child_input_read);
        CloseHandle(child_output_write);
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
            error_value, error_string := get_error_value_and_string();
            log_error("Could not create Windows Job Object: % %", error_value, error_string);
            process.job_handle = INVALID_HANDLE_VALUE;
            deinit(process);
            return false;
        }

        job_info: JOBOBJECT_EXTENDED_LIMIT_INFORMATION;
        job_info.BasicLimitInformation.LimitFlags = JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        success := SetInformationJobObject(process.job_handle, .ExtendedLimitInformation, *job_info, size_of(type_of(job_info)));
        if !success {
            error_value, error_string := get_error_value_and_string();
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

    success := CreateProcessW(null, utf8_to_wide(args_string,, temp), null, null, cast(BOOL) 1, CREATE_NO_WINDOW, null, utf8_to_wide(working_directory,, temp), *startup_info, *process.info);
    if !success {
        error_value, error_string := get_error_value_and_string();
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
                error_string := get_error_string(error_value);
                log_error("Could not assign process % to Windows Job Object %: % %", process.info.hProcess, process.job_handle, error_value, error_string);
                // We could decide to not fail in this case, but this might leave dangling processes around.
                // The Right Thing(tm) depends on the exact error, so we will make these decisions whenever we discover a new error condition.
                // -rluba 2022-12-06
                deinit(process);
                return false;
            }
        }
    }

    read_success := issue_read(*process.output);
    if !read_success {
        error_code, error_string := get_error_value_and_string();
        log_error("Couldn't start overlapped IO for standard output: % %", error_code, error_string);
        deinit(process);
        return false;
    }

    return true;
}

issue_read :: (pipe: *Process.Pipe) -> bool {
    result := ReadFile(pipe.handle, null, 0, null, pipe.overlapped); // :ProcessPointers
    if result == 0 && GetLastError() != ERROR_IO_PENDING    return false;

    return true;
}
