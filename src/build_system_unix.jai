read_from_process :: (process: *Process, output_buffer: [] u8, timeout_ms := -1) -> success: bool, output_bytes: int {
    success := true;
    output_bytes: int;

    // We don't handle error pipe output here, go away
    if !process.error.eof return false, 0;

    #if OS == .LINUX || OS == .ANDROID {
        if process.output.eof return false, 0;

        poll_fds : [1]pollfd = .[
            .{ fd = process.output.handle, events = POLLIN },
        ];
        num_fds := 1;

        poll_timeout_ms := cast(s32) timeout_ms;
        num_events := poll(poll_fds.data, cast(nfds_t) num_fds, poll_timeout_ms);
        if num_events == -1 {
            error_code := System.get_error_value();
            if error_code == EINTR {
                return true, 0; // Got interrupted, try again.
            }

            error_string := System.get_error_string(error_code);
            log_error("Couldn't poll events: % %", error_code, error_string);
            return false, 0;
        }

        for i: 0..num_fds-1 {
            it := poll_fds[i];
            handle := it.fd;
            pipe := *process.output;

            if it.revents & POLLNVAL {
                log_error("Pipe % of % reported invalid value: %", pipe.*, process.*, it);
                success = false;
            }

            read_success: bool;
            if it.revents & POLLIN {
                assert(handle == process.output.handle);
                read_success, output_bytes = read_pipe(*process.output, output_buffer);
                success &&= read_success;
            } else if it.revents & POLLHUP {
                pipe.eof = true;
            }
        }
    } else {
        #assert(OS == .MACOS);

        timeout_spec_pointer: *timespec = null;
        timeout_spec: timespec;
        if timeout_ms >= 0 {
            timeout_spec.tv_sec = timeout_ms / 1000;
            timeout_spec.tv_nsec = (timeout_ms % 1000) * 1000 * 1000;
            timeout_spec_pointer = *timeout_spec;
        }

        events: [1] Kevent64;
        num_events := kevent64(process.kevent_queue, null, 0, events.data, events.count, 0, timeout_spec_pointer);
        if num_events == -1 {
            error_code := System.get_error_value();
            if error_code == EINTR {
                return true, 0; // Got interrupted, try again.
            }

            error_string := System.get_error_string(error_code);
            log_error("Could not read events from the event queue: % %", error_code, error_string);
            return false, 0;
        }

        for 0..num_events-1 {
            event := events[it];
            if event.filter == .READ {
                handle := cast(s32) event.ident;
                assert(handle == process.output.handle);

                pipe := *process.output;
                read_success:, output_bytes = read_pipe(pipe, output_buffer);
                read_everything := (event.data == output_bytes);

                if event.flags & .EOF && read_everything {
                    pipe.eof = true;
                }
                success &&= read_success;
            }
        }
    }

    return success, output_bytes;
}

create_process_with_single_output_pipe :: (process: *Process, args: .. string, working_directory := "", arg_quoting := Process_Argument_Quoting.QUOTE_IF_NEEDED, kill_process_if_parent_exits := true) -> success: bool {
    // This procedure got insanely complex due to some very subtle ways you can shoot yourself in the foot with fork().
    // We could avoid some of that complexity around :PipeForkRace: by using a global lock to guard the time from where we create the pipes until we fork() instead of the socket and pipe back and forth.
    // But that only fixes the race if _everyone_ uses our procedure. As soon as something, somewhere on a different thread calls fork() directly,
    // it re-introduces the race condition without us being able to do _anything_ about it.
    // I’ve also heard of "close every file handle except the I/O pipes in the child process before exec()" but that does not prevent you from something _else_ calling fork() _without_ closing every file handle,
    // sou you’re still subject to the race.
    // The crazy socketpair() dance is the only solution I could figure out that avoids the :PipeForkRace: condition using only things we can 100% control.
    // On Linux we could use pipe2() + O_CLOEXEC to avoid this, but that doesn’t exist on FreeBSD (macOS + certain consoles), so we have to have this code path anways.
    // (pipe2() would add another code path at the benefit of being faster on Linux, but it would still cause the race if someone calls fork() without following it by exec().
    // But people who do that are probably used to shooting themselves in the foot anyways.)
    //
    // Related: If your child process waits for EOF on its STDIN handle and you might have called fork() in another thread,
    // you should use shutdown(process.stdin.handle, .WR) to guarantee the child will see the EOF, even if you accidentally fork-cloned that handle into another process.
    //  -rluba, 2023-02-23

    //
    // Utility functions to deal with posix silliness:
    //

    repeat_if_interrupted :: (call: Code) -> s64 #expand {
        while true {
            result := #insert call;
            if result < 0 {
                error_code := errno();
                if error_code == EINTR continue; // Got interrupted, try again
            }

            return result;
        }
    }

    add_fd_flags :: (handle: s32, flags: s32) -> s32 {
        return fcntl(handle, F_SETFD, fcntl(handle, F_GETFD) | flags);
    }

    add_fl_flags :: (handle: s32, flags: s32) -> s32 {
        return fcntl(handle, F_SETFL, fcntl(handle, F_GETFL) | flags);
    }


    if !kill_process_if_parent_exits {
        // @Incomplete
        log_error("Not killing the process is not yet implemented for Unix.");
        return false;
    }

    if args.count < 1   return false;

    // Convert working_directory and args to C strings.
    // We do this here so that the child process doesn’t need to allocate after fork(),
    // when the allocator might be in a precarious state. :AllocatorAfterFork:
    // -rluba, 2023-02-13
    working_directory_c := ifx working_directory then temp_c_string(working_directory) else null;
    output_args := NewArray(args.count + 1, *u8,, temp);
    for args output_args[it_index] = temp_c_string(it);
    // the list must be null terminated
    output_args[args.count] = null;

    // IPC socket pair that’s used to receive the parent’s end of the pipes from the child
    // and also to receive error details from the child process if the command could not be executed.
    //
    // If this seems crazy complicated: Yes, it is. But if we create the pipes in the parent, there’s
    // a nasty race condition if the parent has multiple threads that may fork(). If we call pipe() in this
    // parent process, calling fork() in another thread could copy our pipe write handles into a _different_ process.
    // And then we will not receive EOF on these pipes because they are still open in some process that knows nothing about
    // the pipe handles it inherited. So we have to create the pipes in the child (where they can’t be copied by a fork()) and
    // copy the read ends to the parent via an ancillary data message sent over a socketpair().
    // socketpair() does not have the same problem as pipe() because we can unilaterally
    // force an EOF by calling shutdown(), no matter how many processes have cloned the socket handle by accident.
    // :PipeForkRace:
    //  -rluba, 2023-02-23
    sockets: [2] s32;
    result := socketpair(AF_UNIX, .STREAM, 0, *sockets);
    if result != 0 {
        error_code, error_string := System.get_error_value_and_string();
        log_error("Could not create IPC socket pair for command \"%\": % %", get_quoted_command_string(args), error_code, error_string);
        return false;
    }

    // We’ll also use this socket as the stdin for the process instead of a pipe for the same reason. :PipeForkRace:
    process.input.handle = sockets[0];

    // The ancillary message format that we’ll use to send the pipe handles from the child to the parent
    Pipes_Control_Message :: struct {
        header: cmsghdr; // ancillary message header
        fds:    [2] s32; // status and output pipe handles
    }
    #assert(size_of(Pipes_Control_Message) == CMSG_SIZE(2 * size_of(s32)));

    pid := fork();

    if pid < 0 {
        log_error("Couldn’t fork: %\n", errno());
        close_and_reset(*sockets[1]); // sockets[0] will be closed by deinit() because we copied it to process.input.handle above
        deinit(process);

        return false;
    } else if pid == 0 {
        // We're in the child process
        //
        // WARNING: DO NOT ALLOCATE BEFORE THESE LINES FINISH! @Stability
        // Jai’s current default heap allocator maintain locks that might have been taken by different thread at the moment we inherited our parent’s memory.
        // So any call to the allocator could deadlock. We need to reset everything before we touch anything that might allocate.
        // We still try to not use any allocator before exec()-ing, just in case someone does not want use to use the Default_Allocator or something. :AllocatorAfterFork:
        // -rluba, 2023-02-13
        Default_Allocator.unsafe_reset();
        context.allocator.proc = Default_Allocator.allocator_proc;
        context.allocator.data = Default_Allocator.allocator_proc(.STARTUP, 0, 0, null, null);
        temporary_storage_data: [1024] u8 #align 64; // Some temporary storage on the stack, for set_working_directory and error messages.
        temp: Temporary_Storage;
        set_initial_data(*temp, temporary_storage_data.count, temporary_storage_data.data);
        context.temporary_storage = *temp;

        report_and_exit :: (message: string) #expand {
            error := errno();
            write(sockets[1], *error, size_of(type_of(error)));
            size := message.count;
            write(sockets[1], *size, size_of(type_of(size)));
            write(sockets[1], message.data, message.count);
            shutdown(sockets[1], .WR);
            close(sockets[1]);
            // Write a dummy value into the status pipe to signal there’s an error report in the IPC socket. (We write the error code, but it doesn’t matter.)
            repeat_if_interrupted(write(status_pipe[1], *error, size_of(type_of(error))));
            exit(-1);
        }

        // Close our copy of the parent’s end of the socket
        close_and_reset(*sockets[0]);

        status_pipe: [2] s32 = .[-1, -1];
        output_pipe: [2] s32 = .[-1, -1];

        // We need a separate status pipe so we can signal that exec was successful by closing it.
        // We can’t use sockets[1] for that because since it’s remapped to STDIN below
        // closing the socket will not send EOF because there’s still a copy in the file handle table (as STDIN).
        result = pipe(*status_pipe);
        if result != 0 report_and_exit("Could not create status pipe");

        result = add_fd_flags(status_pipe[1], FD_CLOEXEC);
        if result != 0 report_and_exit("Could not set FD_CLOEXEC on the status pipe");

        // Map the the socket to this process' stdin
        if dup2(sockets[1], STDIN_FILENO) == -1 report_and_exit("Could not remap stdin");

        result = pipe(*output_pipe);
        if result != 0 report_and_exit("Could not create output pipe");

        // Map the file descriptors from pipe() to this process' stdout and stderr handles
        if dup2(output_pipe[1], STDOUT_FILENO) == -1 report_and_exit("Could not remap stdout");
        if dup2(output_pipe[1], STDERR_FILENO) == -1 report_and_exit("Could not remap stderr");
        close_and_reset(*output_pipe[1]);

        // Send the parent the read handles of the pipes :PipeForkRace:
        control_message: Pipes_Control_Message;
        control_message.header.cmsg_level = SOL_SOCKET;
        control_message.header.cmsg_type = cast(s32) SCM.RIGHTS;
        control_message.header.cmsg_len = CMSG_LEN(2 * size_of(s32));
        control_message.fds[0] = status_pipe[0];
        control_message.fds[1] = output_pipe[0];

        dummy: s32 = 12345;
        iov: iovec;
        iov.iov_base = *dummy;
        iov.iov_len = 1;

        message_header: msghdr;
        message_header.msg_iov = *iov;
        message_header.msg_iovlen = 1;
        message_header.msg_control = *control_message;
        message_header.msg_controllen = control_message.header.cmsg_len;

        size := repeat_if_interrupted(sendmsg(sockets[1], *message_header, 0));
        if size != 1 report_and_exit("Could not send pipe handles to parent");

        // Wait for the parent to ACK so we know that it has cloned the handles before we close them in the child process:
        size = repeat_if_interrupted(read(sockets[1], *dummy, 1));
        if size != 1 report_and_exit("Could not read sync byte from parent");

        // Close our copy of the parent's pipe handles
        close_and_reset(*status_pipe[0]);
        close_and_reset(*output_pipe[0]);

        // Use chdir directly instead of set_working_directory to avoid temporary allocation, just to be extra safe.
        // Someone might pass in a huge string that causes the temporary allocator to overflow and allocate.
        if working_directory_c {
            libc :: #system_library "libc";
            chdir :: (s: *u8) -> s32 #foreign libc;
            result := chdir(working_directory_c);
            if result == -1 {
                report_and_exit("Could not change working directory");
            }
        }

        // exec* functions don't automatically pass argv[0]
        execvp(output_args[0], output_args.data);

        report_and_exit("execvp() failed");

        // silence not-all-control-paths-return warning
        return false;
    } else {
        // We’re in the parent process
        process.pid = pid;

        // Close our copy of the client’s end of the socket
        close_and_reset(*sockets[1]);

        report_and_cleanup :: (message: string) #expand {
            error_code, error_string := System.get_error_value_and_string();
            log_error("%: % %", message, error_code, error_string);
            kill_process(process);
            get_process_result(process);
            deinit(process);
        }

        control_message: Pipes_Control_Message;

        read_value: OS_Error_Code;
        iov: iovec;
        iov.iov_base = *read_value;
        iov.iov_len = size_of(type_of(read_value));

        message_header: msghdr;
        message_header.msg_iov = *iov;
        message_header.msg_iovlen = 1;
        message_header.msg_control = *control_message;
        message_header.msg_controllen = size_of(type_of(control_message));

        // We’ll either receive a dummy message with ancillary data that contains
        // the pipe handles or we’ll receive an error code without ancillary data.
        size := repeat_if_interrupted(recvmsg(sockets[0], *message_header, 0));
        // log("Size: %, header: %", size, message_header);
        if size == -1 {
            report_and_cleanup("Could not receive pipe handles from child");
            return false;
        }

        error_code: OS_Error_Code;
        error_bytes_read: s64;

        status_read_handle: s32 = -1;
        defer close_and_reset(*status_read_handle);

        received := CMSG_FIRSTHDR(*message_header);
        if (received) {
            // We got pipe handles!
            if received.cmsg_level != SOL_SOCKET || received.cmsg_type != cast(s32) SCM.RIGHTS {
                report_and_cleanup("Could not parse pipe handles from child");
                return false;
            }
            if received.cmsg_len < CMSG_LEN(size_of(s32)) {
                report_and_cleanup("Pipe message from the child is too small");
                return false;
            }

            received_message := cast(*Pipes_Control_Message) received;
            status_read_handle = received_message.fds[0];
            if received.cmsg_len < CMSG_LEN(2 * size_of(s32)) {
                report_and_cleanup("Pipe message from the child is too small");
                return false;
            }

            process.error = .{ handle = -1, eof = true };
            process.output.handle = received_message.fds[1];

            if add_fl_flags(process.output.handle, O_NONBLOCK) == -1 {
                report_and_cleanup("Could not set the child process' stdout pipe to non-blocking");
                return false;
            }

            #if OS == .MACOS {
                process.kevent_queue = kqueue();
                if process.kevent_queue == -1 {
                    report_and_cleanup("Could not create event queue");
                    return false;
                }

                events: [1] Kevent64;
                events[0].ident  = cast(u64) process.output.handle;
                events[0].filter = .READ;
                events[0].flags  = .ADD;
                // @ToDo: We could also add a process event here to get signalled when the process exits.

                result := repeat_if_interrupted(kevent64(process.kevent_queue, events.data, events.count, null, 0, 0, null));
                if result == -1 {
                    report_and_cleanup("Could not register events with the event queue");
                    return false;
                }
            }

            // Doesn’t matter what we write, it’s just to tell the child that we’ve received the handles, so it can close them in its process and proceed.
            size = repeat_if_interrupted(write(sockets[0], *read_value, 1));
            if size != 1 report_and_cleanup("Could not write sync byte to child");
        } else {
            // No ancillary data, so this must be an error code:
            if size != size_of(type_of(error_code)) {
                report_and_cleanup("Received neither pipe handles nor an error code from the child");
                return false;
            }
            error_code = read_value;
            error_bytes_read = size;
        }

        if !error_bytes_read {
            // Try to read from the status pipe.
            // If the exec() was successful, we’ll get EOF because the pipe was automatically closed by O_CLOEXEC.
            // Otherwise we’ll get some dummy data that tells us there’s error details in the socket.
            // We could also send the error details directly in the status pipe. But since we don’t initially have the status pipe
            // we have to be able to read the error from the socket anyways, so switching to sending the error in
            // the status pipe after a certain point just adds complexity. And we already have enough of that.
            //  -rluba, 2023-02-23
            dummy: s32;
            status_bytes_read := repeat_if_interrupted(read(status_read_handle, *dummy, size_of(type_of(dummy))));
            if status_bytes_read < 0 {
                report_and_cleanup("Couldn’t read process status pipe");
                return false;
            }

            if status_bytes_read {
                // Read the error code from the IPC socket.
                error_bytes_read = repeat_if_interrupted(read(sockets[0], *error_code, size_of(type_of(error_code))));
                if error_bytes_read < 0 {
                    report_and_cleanup("Couldn’t read error code from IPC socket");
                    return false;
                }
            }
        }

        assert(error_bytes_read == 0 || error_bytes_read == size_of(type_of(error_code)));

        if error_bytes_read > 0 {
            // Something went wrong. Read the error message
            message_size: s64;
            bytes_read := repeat_if_interrupted(read(sockets[0], *message_size, size_of(type_of(message_size))));
            if bytes_read != size_of(type_of(message_size)) {
                report_and_cleanup("Couldn’t read error message length from IPC socket");
                return false;
            }

            builder: String_Builder;
            builder.allocator = temp;

            message_bytes_read := 0;
            while message_bytes_read < message_size {
                buffer := ensure_contiguous_space_and_return_available_range(*builder);
                bytes_read := repeat_if_interrupted(read(sockets[0], buffer.data, xx buffer.count));
                if bytes_read < 0 {
                    report_and_cleanup("Couldn’t read error message from IPC socket");
                    return false;
                }
                if !bytes_read break;

                advance_through_ensured_space(*builder, bytes_read);
                message_bytes_read += bytes_read;
            }

            error_string := System.get_error_string(error_code);
            log_error("Couldn’t launch process. %: % %", builder_to_string(*builder,, temp), error_code, error_string);
            kill_process(process);
            get_process_result(process);
            deinit(process);
            return false;
        }

        // Once we’re done with using the socket for error messaging,
        // set it up for use as stdin. :PipeForkRace:
        // @Cleanup: Do we really want to force non-blocking I/O on the process’ STDIN pipe?
        // We don’t know for sure what our callee wants to do with it!
        if add_fl_flags(process.input.handle, O_NONBLOCK) == -1 {
            report_and_cleanup("Could not set the child process' stdin pipe to non-blocking");
            return false;
        }

        return true;
    }

}

#scope_file

#import "Basic";
#import "POSIX";
#import "Socket";
#import "Process";
System :: #import "System";
Default_Allocator :: #import "Default_Allocator";

#if OS == .MACOS {
    #import "macos";
}
