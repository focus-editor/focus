/*
I belive that io_uring is meant to have a separate ring for each thread. I think this makes a lot of sense for the
kinds of applications that Linux is usually used for like databases, HPC, internet services, etc. But for games or
other centralized applications, we want a queue that allows any thread to submit to and and any of a pool of threads
to pull from. Since io_uring isn't made for that, I'm not sure what the performance will be like. The submission
entries each take up exactly one cache line which is fine but we then need to write that index into the submission
array which requires us to allocate a slot then spin until anyone before us is done which could be a problem if
one of those threads has a context switch. There are a few other options I have thought of but none of them are
wait-free. Maybe one of them is a better choice or there is something that I have not thought of. Let us know if you
have a better idea. The completion queue is not as bad since we can copy the next completion entry then use an atomic
compare exchange to see if someone else read it first. Still not wait-free but probably the best that we can do.

The only part of the syncronization that is a bit complex is in the submission queue.

So, for the submission queue, there are two parts, there are the actual entries that we fill out, and the
array where we put the indexes. Having this separation built into the ring is really great. So to allocate an
entry, I have a head and a tail. I put new entries on the tail, and I increment the head once the next entry
can be submitted. So I start off with a CAS loop to increment the tail and take the old value as my index. The
reason for a CAS loop rather than an atomic intrement is so that I can check if the completion queue is full.
Once an index has been selected, I write my entry into that index. Multiple threads can be writing this index
at the same time. But without a much more complex design, the write into the array and call into the OS need
to be serialized. So all threads wait until the head pointer catches up. Reguardless of if the add succeeded
or not, the head pointer will be increased. So once the thread is sure that it is the only one, it puts the
index of its entry into the submission array. It then increments the submission tail to let Linux know that it
can submit that entry. If we find out that it failed, we decrement the tail again so that the next entry can
try. Then reguardless of what happens, we increment the entry head so that the next entry can give it a go.

One issue with the queue is that subsiquent requests are submitted later. Like requests that happen after an open
or the actual read request in a read entire file. The problem with that is that if the queue is full at that time,
there is no nice way to get the caller to resubmit after dequeuing a few requests. So right now, I am keeping track
of how many requests are in flight and making sure that is not more than the number of completion entries. This will
work great for a single thread like the one that I am using in count_lines_in_tree, but it may still cause requests
to return incomplete if there are multiple threads. A good accounting method is a job for a day when I am less tired.
*/

Queue :: struct(User_Data: Type) {
    ring_fd: s32;
    io_queue: *void;
    io_queue_size: u64;

    submission_tail:      *u32;
    submission_head:      *u32;
    submission_mask:      *u32;
    submission_array:     *u32;

    submission_entries: [] io_uring_sqe;
    submission_entry_tail: u32;
    submission_entry_head: u32;

    submitted: u32;

    completion_head: *u32;
    completion_tail: *u32;
    completion_mask: *u32;
    completion_entries: [] io_uring_cqe;
}

File :: struct(User_Data: Type) {
    using internal: *struct {
        waiting_operations: *File_Operation(User_Data);
        descriptor: s32;
        descriptor_status: enum u8 #specified {
            INVALID :: 0x0;
            VALID   :: 0x1;
        }
        unfinished_operations: u8 = 2;
    };
}

initialize_queue :: ($User_Data: Type) -> *Queue(User_Data), result := Error.{} {
    using queue: Queue(User_Data);

    params: io_uring_params;
    ring_fd = io_uring_setup(128, *params); // Entries is between 1 and 4096. Not sure how many we want
    if ring_fd < 0 return null, error(.Catastrophic, errno()); // io_uring is not supported or not new enough

    submission_queue_size := params.sq_off.array + params.sq_entries * size_of(u32);
    completion_queue_size := params.cq_off.cqes + params.cq_entries * size_of(io_uring_cqe);

    // IORING_FEAT_SINGLE_MMAP is required. IORING_FEAT_RW_CUR_POS is not required but
    // proves that we are on a new enough kernel for the opcode types that we do require
    if !flags_set(params.features, IORING_FEAT_SINGLE_MMAP | IORING_FEAT_RW_CUR_POS) return null, error(.Catastrophic);

    if completion_queue_size > submission_queue_size then submission_queue_size = completion_queue_size;
    io_queue_size = submission_queue_size;
    io_queue = mmap(null, io_queue_size, PROT_READ | PROT_WRITE, MAP_SHARED | MAP_POPULATE, ring_fd, IORING_OFF_SQ_RING);
    if !io_queue return null, error(.Catastrophic, errno());

    submission_tail = io_queue + params.sq_off.tail;
    submission_head = io_queue + params.sq_off.head;
    submission_mask = io_queue + params.sq_off.ring_mask;
    submission_array = io_queue + params.sq_off.array;

    submission_entries.count = params.sq_entries;
    submission_entries.data = mmap(null, params.sq_entries * size_of(io_uring_sqe), PROT_READ | PROT_WRITE, MAP_SHARED | MAP_POPULATE, ring_fd, IORING_OFF_SQES);
    if !submission_entries.data {
        code := errno();
        munmap(io_queue, io_queue_size);
        return null, error(.Catastrophic, code);
    }

    completion_head = io_queue + params.cq_off.head;
    completion_tail = io_queue + params.cq_off.tail;
    completion_mask = io_queue + params.cq_off.ring_mask;
    completion_entries.data = io_queue + params.cq_off.cqes;
    completion_entries.count = params.cq_entries;

    new_queue := New(Queue(User_Data), false);
    <<new_queue = queue;

    return new_queue;
}

destroy_queue :: (using queue: *Queue) {
    munmap(io_queue, io_queue_size);
    munmap(submission_entries.data, xx (submission_entries.count * size_of(io_uring_sqe)));
    close(ring_fd); // It shouldn't be possible to have a non EINTR error here
    free(queue);
}

open_file :: (queue: *Queue($T), file_path: string, keep_existing_content := true) -> File(T), result := Error.{} {
    file: File(T) = ---;
    file.internal = New(type_of(<<file.internal));

    operation := New(File_Operation(queue.User_Data));
    operation.file = file;
    operation.action = .OPEN;

    file_path_c := temp_c_string(file_path);
    submitted := submit_sq_entry(queue, #code {
        using entry;

        opcode   = IORING_OP_OPENAT;
        fd       = AT_FDCWD;
        addr     = xx file_path_c;
        len      = 0x1B4; // 0o664
        other_flags = O_RDWR | O_CREAT | O_CLOEXEC | (ifx keep_existing_content cast(u32)0 else O_TRUNC);

        user_data = xx operation;
    });
    if submitted.code != .Success {
        free(operation);
        free(file.internal);
        file.internal = null;
        return file, submitted;
    }

    return file;
}

close_file :: inline (queue: *Queue, file: File) {
    // unfinished_operations was set to 2 in open_file which this decrement
    // pairs to and allows closure once all operations are finished.
    finish_completion(queue, file);
}

read_entire_file :: (queue: *Queue($T), file_path: string, user_data: T) -> result := Error.{} {
    file: File(T) = ---;
    file.internal = New(type_of(<<file.internal));
    file.unfinished_operations = 2;

    operation := New(File_Operation(queue.User_Data));
    operation.file = file;
    operation.action = .OPEN;

    read_operation := New(File_Operation(T));
    read_operation.file = file;
    read_operation.action = .READ_ENTIRE_FILE;

    statx := New(statx_t);
    read_operation.statx = statx;
    read_operation.statx_identifier = -1; // Indicates that this is the statx pointer and not the final buffer
    read_operation.user_data = user_data;

    // This is allowed because we created the file so we know that no one else is trying to do this
    file.waiting_operations = read_operation;

    file_path_c := temp_c_string(file_path);
    submitted := submit_sq_entry(queue, #code {
        entry.opcode      = IORING_OP_OPENAT;
        entry.fd          = AT_FDCWD;
        entry.addr        = xx file_path_c;
        entry.len         = 0x1B4; // 0o664
        entry.other_flags = O_RDONLY | O_CREAT | O_CLOEXEC;

        entry.user_data = xx operation;
    });
    if submitted.code != .Success {
        free(operation);
        free(read_operation);
        free(file.internal);
        free(statx);
        return submitted;
    }
    return;
}
write_entire_file :: (queue: *Queue($T), file_path: string, data: [] u8, user_data: T) -> result := Error.{} {
    file: File(T) = ---;
    file.internal = New(type_of(<<file.internal));
    file.unfinished_operations = 3;

    operation := New(File_Operation(queue.User_Data));
    operation.file = file;
    operation.action = .OPEN;

    // This is allowed because we created the file so we know that no one else is trying to do this
    file.waiting_operations = get_operation(file, 0, data, user_data, .WRITE_ENTIRE_FILE);

    file_path_c := temp_c_string(file_path);
    submitted := submit_sq_entry(queue, #code {
        entry.opcode   = IORING_OP_OPENAT;
        entry.fd       = AT_FDCWD;
        entry.addr     = xx file_path_c;
        entry.len      = 0x1B4; // 0o664
        entry.other_flags = O_WRONLY | O_CREAT | O_CLOEXEC | O_TRUNC;

        entry.user_data = xx operation;
    });
    if submitted.code != .Success {
        free(file.internal);
        free(operation);
        free(file.waiting_operations);
        return submitted;
    }
    return;
}

read_file :: inline (queue: *Queue($T), file: File(T), position: s64, data: [] u8, user_data: T) -> result := Error.{} {
    operation := get_operation(file, position, data, user_data, .READ);
    return submit_or_add(queue, file, operation);
}
write_file :: inline (queue: *Queue($T), file: File(T), position: s64, data: [] u8, user_data: T) -> result := Error.{} {
    operation := get_operation(file, position, data, user_data, .WRITE);
    return submit_or_add(queue, file, operation);
}

wait_for_completion :: (queue: *Queue($T), check_only := false) -> T, data: [] u8, result := Error.{} {
    while true {
        entry: io_uring_cqe = ---;
        success := false;
        entry, success = get_cq_entry(queue);
        needs_to_wait := false;
        while !success {
            if check_only {
                nothing: T;
                return nothing, .[], error(.DidNotWait);
            }
            if needs_to_wait sleep_milliseconds(1); // @ToDo Consider removing this
            result := io_uring_enter(queue.ring_fd, 0, 1, xx IORING_ENTER_GETEVENTS);
            if result == -1 then result = -errno();
            if result < 0 if result == {
                case -EAGAIN; needs_to_wait = true; // Man page says wait and retry.
                case -EBUSY; // CQ is already full so just take an event.
                case -EINTR; // Retry without waiting.
                case; // Ring is being deleted or something strange happened.
                    nothing: T;
                    return nothing, .[], error(.Catastrophic, -result);
            }
            entry, success = get_cq_entry(queue);
        }
        atomic_decrement(*queue.submitted);

        original_request := cast(*File_Operation(T))entry.user_data;
        if entry.res == -EOPNOTSUPP {
            // Somehow, our version checking went wrong. We have to bail
            return original_request.user_data, .[], error(.Catastrophic, EOPNOTSUPP);
        }
        if #complete original_request.action == {
            case .OPEN;
                if entry.res < 0 {
                    defer free(original_request);
                    return original_request.user_data, .[], error(.FileAccessFailed, -entry.res);
                }
                original_request.file.descriptor = entry.res;
                original_request.file.descriptor_status = .VALID;
                submit_ops_saved_to_file(queue, original_request.file);
                finish_completion(queue, original_request.file);
            case .CLOSE;
                // Errors are unimportant for now and thus ignored
                free(original_request.file.internal);
                free(original_request);
            case .READ_ENTIRE_FILE;
                if original_request.statx_identifier == -1 {
                    // This was a statx request
                    statx := original_request.statx;
                    size := statx.stx_size;
                    free(statx);

                    if entry.res < 0 {
                        // ENOMEM is a bit more catestrophic than other errors
                        defer free(original_request);
                        if entry.res == -ENOMEM {
                            return original_request.user_data, .[], error(.Catastrophic, -entry.res);
                        } else {
                            return original_request.user_data, .[], error(.FileAccessFailed, -entry.res);
                        }
                    }

                    original_request.data = NewArray(xx size, u8, initialized = false);

                    submitted := submit_sq_entry(queue, #code {
                        using entry;

                        opcode = IORING_OP_READ;
                        fd     = original_request.file.descriptor;
                        addr   = xx original_request.data.data;
                        len    = cast,no_check(u32)Min(original_request.data.count, 0xFFFFFFFF);
                        off    = 0;

                        user_data = xx original_request;
                    });
                    if submitted.code != .Success {
                        if submitted.code == .FullQueue {
                            // This wouldn't make sense to return to the user since they can't just wait and
                            // try again or something. Incomplete is fine because trying again may help. @ToDo
                            // Consider how to best help the user since there's no real reason we should get
                            // them to try again, at least not from scratch since we did get the file size back!
                            submitted.code = .Incomplete;
                        }
                        free(original_request.data.data);
                        defer free(original_request);
                        return original_request.user_data, .[], submitted;
                    }
                    continue;
                }
                #through;
            case .READ;
                if entry.res < 0 {
                    // None of the possible errors ask for retry, lucky this was designed far better than before
                    defer free(original_request);
                    finish_completion(queue, original_request.file);
                    original_request.data.count = original_request.completed_data;
                    return original_request.user_data, original_request.data, error(.Incomplete, -entry.res);
                }
                original_request.completed_data += entry.res;
                if original_request.completed_data < original_request.data.count {
                    submitted := submit_sq_entry(queue, #code {
                        using entry;

                        opcode = IORING_OP_READ;
                        fd     = original_request.file.descriptor;
                        addr   = xx (original_request.data.data + original_request.completed_data);
                        len    = cast,no_check(u32)Min(original_request.data.count - original_request.completed_data, 0xFFFFFFFF);
                        off    = xx (original_request.position + original_request.completed_data);

                        user_data = xx original_request;
                    });
                    if submitted.code != .Success {
                        if submitted.code == .FullQueue {
                            // @ToDo See similar comment above (or remove this if that comment is gone!)
                            submitted.code = .Incomplete;
                        }
                        defer free(original_request);
                        finish_completion(queue, original_request.file);
                        original_request.data.count = original_request.completed_data;
                        return original_request.user_data, original_request.data, submitted;
                    }
                } else {
                    defer free(original_request);
                    finish_completion(queue, original_request.file);
                    return original_request.user_data, original_request.data;
                }
            case .WRITE_ENTIRE_FILE; #through;
            case .WRITE;
                if entry.res < 0 {
                    // None of the possible errors ask for retry, lucky this was designed far better than before
                    defer free(original_request);
                    finish_completion(queue, original_request.file);
                    original_request.data.count = original_request.completed_data;
                    return original_request.user_data, original_request.data, error(.Incomplete, -entry.res);
                }
                original_request.completed_data += entry.res;
                if original_request.completed_data < original_request.data.count {
                    submitted := submit_sq_entry(queue, #code {
                        using entry;

                        opcode = IORING_OP_WRITE;
                        fd     = original_request.file.descriptor;
                        addr   = xx (original_request.data.data + original_request.completed_data);
                        len    = cast,no_check(u32)Min(original_request.data.count - original_request.completed_data, 0xFFFFFFFF);
                        off    = xx (original_request.position + original_request.completed_data);

                        user_data = xx original_request;
                    });
                    if submitted.code != .Success {
                        if submitted.code == .FullQueue {
                            // @ToDo See similar comment above (or remove this if that comment is gone!)
                            submitted.code = .Incomplete;
                        }
                        defer free(original_request);
                        finish_completion(queue, original_request.file);
                        original_request.data.count = original_request.completed_data;
                        return original_request.user_data, original_request.data, submitted;
                    }
                } else {
                    defer free(original_request);
                    finish_completion(queue, original_request.file);
                    return original_request.user_data, original_request.data;
                }
        }
    }
    never: T; // Execution can't reach this point
    return never, .[];
}

#scope_file

File_Operation_Action :: enum u8 {
    OPEN;
    CLOSE;
    READ;
    WRITE;
    READ_ENTIRE_FILE;
    WRITE_ENTIRE_FILE;
}

File_Operation :: struct(User_Data: Type) {
    next: *#this; // Allows this operation to be used as part of a linked list

    position: s64;
    completed_data: s64;
    file: File(User_Data);
    union {
        data: [] u8; // Location to read to or write from and length
        struct {
            statx: *statx_t;
            // Set to -1 to indicate that this is a statx request and thus the pointer is valid
            statx_identifier: s64;
        }
    }

    action: File_Operation_Action;

    user_data: User_Data;
}

flags_set :: inline (value: $T, flags: T) -> bool {
    return value & flags == flags;
}

get_operation :: (file: File($T), position: s64, data: [] u8, user_data: T, action: File_Operation_Action) -> *File_Operation(T) {
    operation := New(File_Operation(T));
    operation.file      = file;
    operation.position  = position;
    operation.data      = data;
    operation.user_data = user_data;
    operation.action    = action;
    return operation;
}

finish_completion :: (queue: *Queue, file: File) {
    if atomic_decrement(*file.unfinished_operations) { // All operations are complete and the file was closed
        operation := New(File_Operation(queue.User_Data));
        operation.file = file;
        operation.action = .CLOSE;

        submitted := submit_sq_entry(queue, #code {
            using entry;

            opcode = IORING_OP_CLOSE;
            fd     = file.descriptor;

            user_data = xx operation;
        });
        if submitted.code != .Success {
            // If we somehow were not able to close it on the ring, let's just do it ourselves.
            free(operation);
            close(operation.file.descriptor); // May want to report errors here...
            free(operation.file.internal);
        }
    }
}

submit_or_add :: (queue: *Queue($T), file: File(T), operation: *File_Operation) -> result := Error.{} {
    atomic_increment(*operation.file.unfinished_operations);
    if atomic_read(*file.descriptor_status) == .VALID {
        return submit_operation(queue, operation);
    } else {
        next := file.waiting_operations;
        done: bool;

        wait := 1;
        WAIT_MAX :: 16;
        while !done {
            operation.next = next;
            done, next = compare_and_swap(*file.waiting_operations, next, operation);

            if !done {
                for 1..wait {
                    pause();
                }
                if wait < WAIT_MAX {
                    wait <<= 1;
                }
            }
        }

        if atomic_read(*file.descriptor_status) == .VALID {
            return submit_ops_saved_to_file(queue, file);
        }
        return;
    }
}

submit_ops_saved_to_file :: (queue: *Queue($T), file: File(T)) -> Error {
    ops := atomic_swap(*file.waiting_operations, null);
    success: Error;
    while ops {
        next := ops.next;
        submitted := submit_operation(queue, ops);
        if success.code == .Success && submitted.code != .Success {
            success = submitted;
        }
        ops = next;
    }
    return success;
}

submit_operation :: (queue: *Queue($T), operation: *File_Operation(T)) -> result := Error.{} {
    if #complete operation.action == {
        case .OPEN; #through;
        case .CLOSE;
            // Open and close file operations shouldn't be handled by submit_operation...
            return error(.Catastrophic);
        case .READ;
            return submit_sq_entry(queue, #code {
                using entry;

                opcode = IORING_OP_READ;
                fd     = operation.file.descriptor;
                addr   = xx operation.data.data;
                // Linux claims to only read 0x7FFFFFFF. My tests shows what it will only read 0x7FFFF000. We
                // are allowed to ask for the full u32 max so we might as well in case this changes in the future
                len    = cast,no_check(u32)Min(operation.data.count, 0xFFFFFFFF);
                off    = xx operation.position;

                user_data = xx operation;
            });
        case .WRITE_ENTIRE_FILE; #through;
        case .WRITE;
            return submit_sq_entry(queue, #code {
                using entry;

                opcode = IORING_OP_WRITE;
                fd     = operation.file.descriptor;
                addr   = xx operation.data.data;
                len    = cast,no_check(u32)Min(operation.data.count, 0xFFFFFFFF);
                off    = xx operation.position;

                user_data = xx operation;
            });
        case .READ_ENTIRE_FILE;
            return submit_sq_entry(queue, #code {
                using entry;

                opcode      = IORING_OP_STATX;
                fd          = operation.file.descriptor;
                other_flags = AT_EMPTY_PATH | AT_STATX_SYNC_AS_STAT;
                addr        = xx "".data;
                len         = STATX_SIZE;
                off         = xx operation.statx;

                user_data = xx operation;
            });
    }
}

// If success is false, there were no entries available.
get_cq_entry :: (queue: *Queue) -> io_uring_cqe, success: bool {
    head := atomic_read(queue.completion_head);
    entry: io_uring_cqe = ---;
    success := false;

    wait := 1;
    WAIT_MAX :: 16;
    while !success {
        if head == atomic_read(queue.completion_tail) return .{}, false;

        // Copy the entry so it can be reused if the cas succeeds
        entry = queue.completion_entries[head & <<queue.completion_mask];

        success, head = compare_and_swap(queue.completion_head, head, head + 1);

        if !success {
            for 1..wait {
                pause();
            }
            if wait < WAIT_MAX {
                wait <<= 1;
            }
        }
    }
    return entry, true;
}

// entry_code is some code that fills out the submission entry. Use entry as a pointer to a submission
// entry. Every opcode has very different needs for setting the members of the entry. It may make
// sense to create procedures for each opcode that we need and have them use this function internally.
submit_sq_entry :: (queue: *Queue, entry_code: Code) -> Error #expand {
    // @ToDo This probably doesn't need to be a CAS loop but that will require some other way of allocating indexes.
    allocated_entry := atomic_read(*queue.submission_entry_tail);
    success := false;
    while !success {
        if allocated_entry - atomic_read(*queue.submission_entry_head) >= queue.submission_entries.count {
            wait := 1;
            WAIT_MAX :: 16;
            while allocated_entry - atomic_read(*queue.submission_entry_head) >= queue.submission_entries.count && wait < WAIT_MAX {
                for 1..wait {
                    pause();
                }
                wait <<= 1;
            }
            if allocated_entry - atomic_read(*queue.submission_entry_head) >= queue.submission_entries.count {
                return error(.FullQueue);
            }
        }
        if atomic_read(*queue.submitted) >= queue.completion_entries.count {
            return error(.FullQueue);
        }
        success, allocated_entry = compare_and_swap(*queue.submission_entry_tail, allocated_entry, allocated_entry + 1);
    }
    defer {
        // I get issues with READ_ENTIRE_FILE if the entry is not cleared. I don't fully know why. @ToDo Ideally
        // this would happen after the serialized portion but that adds complexity. The other option is to find
        // out what exactly needs to be cleared if not everything and just do that as a part of the entry code.
        queue.submission_entries[allocated_entry & <<queue.submission_mask] = .{};
        atomic_increment(*queue.submission_entry_head); // This doesn't really need to be atomic but I'd rather be safe for now.
    }

    if atomic_read(*queue.submitted) >= queue.completion_entries.count {
        return error(.FullQueue, 12);
    }

    {
        `entry := *queue.submission_entries[allocated_entry & <<queue.submission_mask];
        #insert entry_code;
    }

    {
        wait := 1;
        WAIT_MAX :: 16;
        while atomic_read(*queue.submission_entry_head) != allocated_entry {
            for 1..wait {
                pause();
            }
            if wait < WAIT_MAX {
                wait <<= 1;
            }
        }
    }

    queue.submission_array[<<queue.submission_tail & <<queue.submission_mask] = allocated_entry & <<queue.submission_mask;

    <<queue.submission_tail += 1; // We are still syncronized here
    ent := queue.submission_entries[queue.submission_array[(<<queue.submission_tail-1) & <<queue.submission_mask]];
    //if ent.opcode == IORING_OP_READ then print("ENT % % % % %\n", ent.fd, ent.addr, ent.len, ent.off, ent);
    result := io_uring_enter(queue.ring_fd, 1, 0, 0);
    if result == -1 then result = -errno();
    if result == {
        case -EAGAIN; #through; // Kernel out of resources (memory etc.) but CQ not full
        case -EBUSY;
            <<queue.submission_tail -= 1; // Still serialized.
            return error(.FullQueue, -result); // CQ is full so we need to wait or bail.
        case;
            if result > 0 {
                atomic_add(*queue.submitted, 1);
                return .{};
            } else {
                <<queue.submission_tail -= 1; // Still serialized.
                return error(.Catastrophic, -result);
            }
    }
}

#import "Atomics";
#import "Basic"; // Assert and allocation
#import "Linux";
#import "POSIX";
#if CPU == .X64 {
    #import "Machine_X64";
}
