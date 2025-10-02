/*
I hoped not to have to use a thread pool but there is nothing better that can be done on macOS. Pthreads are used
directly because this is meant for macOS so I would like to use some macOS-sepcific functions to attempt to get
the best performance. Perhaps it would be better to use the Thread module and on macOS and access the internal
pthread handle. Though after testing, I am not sure if this even does what I expected or makes a difference.
A better testing methodology is needed to test if this actually works and is better in a measurable way.

On macOS, the default AIO system that we used to use creates 4 threads and syncronously runs operations on them.
We will do the same for now. Additionally, we will pin these threads to the efficiency cores (actually this
doesn't seem to always work) if you are running on a mac with them and increase the IO priority for those threads.

So syncronization.

At the top level, there is an rr_index that is used to pick with thread to submit to. Each request
does an atomic increment to spread the load out amoung all of the threads. If the CAS fails on
one of the threads, the next one will be tried so that contention will hopefully tend to spread
out. Obviously all of this would need performance testing to see if it really the best thing.

For the submission side, you first try to claim a request and ensure that you are not claiming more than the
availble number of submission slots based on how many have been reaped. You then set your request as being valid
and increment the number of available requests so the thread knows there is one ready. If that was the first
request submitted after the thread decided to wait, it uses the blocker to wake up the thread. On the thread's
side, it checks if there are any available requests. It checks if the request is valid (because one thread could
make theirs valid before a previous request does). If not, it waits for a little while and then uses the blocker
to just wait for someone to update if it is taking a while. After it is done handling the request, it makes the
request invalid again, indicates that it has reaped the request, and decrements the number of requests submitted.

On the completion side, there is a bitmap of available indexes to place a completion. The thread uses that to find
a free slot and fill it with a completion. If the slot actually wasn't free, it checks the next one that says it is
free. If the one that it put in is the first, it notifies the blocker. If there were no free slots, it waits a bit
then uses the blocker to wait for someone to free a completion. On the other side, there is an overal version marker
that is incremented any time the first completion in a thread is filled. This allows someone who checked every thread
to see if an entry was added since they started searching. Only if not do they use the blocker to wait for one to
happen. So to find a completion for a thread, do a bitscan for one in the bitmap and attempt to be the first to reset
the bit as not having a completion (this happening before reading the completion is why the valid flag exists). If
there was success in finding a completion for this thread, we wait until the completion is valid (which probably
doesn't actually have to happen?) then the completion is read and valid is set to false so a new completion can be put
in that place. If we happened to read the completion that would be written to last, then we are probably the first
to make a free space in the completion queue so we use the blocker to alert the thread that it now has more space.
*/

// @Question is 4 worker threads and 32 requests each a good number or should they be different or variable?
// @Note, this is about 145k with no user_data at the moment! Maybe we can or should make it smaller?
Queue :: struct(User_Data: Type) {
    completion_version: u64;
    completion_blocker: Blocker;
    rr_index: u64;
    worker_threads: [THREADS] Worker_Thread(User_Data);

    THREADS :: 4;
    SUBMISSION_ENTRIES :: 32;
    COMPLETION_ENTRIES :: 32;
}

File :: struct(User_Data: Type) {
    descriptor: s32;
    unfinished_operations: *s64;
}

initialize_queue :: ($User_Data: Type) -> *Queue(User_Data), result := Error.{} {
    queue := New(Queue(User_Data));
    // Make sure our process is set to high priority because otherwise our per-thread settings will be ignored.
    #if OS == .MACOS then setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_PROCESS, IOPOL_IMPORTANT);

    lock_attributes: pthread_mutexattr_t;
    pthread_mutexattr_init(*lock_attributes); // Can't fail on macOS
    defer pthread_mutexattr_destroy(*lock_attributes);
    pthread_mutexattr_settype(*lock_attributes, PTHREAD_MUTEX_NORMAL);
    // These locks should have almost no contention and fairness doesn't matter
    // so make it first fit. This is the default but if we don't set it, it can
    // be controlled by an environment variable which sounds like a terrible idea.
    PTHREAD_MUTEX_POLICY_FIRSTFIT_NP :: 3; // Doesn't exist prior to 10.14 (mutexes are always FAIRSHARE before then)
    #if OS == .MACOS then pthread_mutexattr_setpolicy_np(*lock_attributes, PTHREAD_MUTEX_POLICY_FIRSTFIT_NP);
    pthread_mutexattr_setprotocol(*lock_attributes, PTHREAD_PRIO_INHERIT);
    pthread_mutex_init(*queue.completion_blocker.lock, *lock_attributes); // Can't fail on macOS

    pthread_cond_init(*queue.completion_blocker.condition, null); // Can't fail on macOS

    thread_attributes: pthread_attr_t;
    pthread_attr_init(*thread_attributes); // Can't fail on macOS
    defer pthread_attr_destroy(*thread_attributes);
    pthread_attr_setinheritsched(*thread_attributes, PTHREAD_EXPLICIT_SCHED);
    // Only schedule on efficiency cores if they exist
    #if OS == .MACOS then pthread_attr_set_qos_class_np(*thread_attributes, xx QOS_CLASS.BACKGROUND, 0);

    for * cast([]Worker_Thread(User_Data))queue.worker_threads {
        pthread_mutex_init(*it.requests_blocker.lock, *lock_attributes);
        pthread_cond_init(*it.requests_blocker.condition, null);

        td := *it.thread_data;
        td.queue = queue;
        td.thread_id = xx it_index;
        // We may want to combine all these strings into one allocation
        // and hand out substrings to it. Maybe even free it later?
        td.name = sprint("Worker thread % for queue %\0", it_index, queue);

        ts := *td.ts;
        set_initial_data(ts, TEMPORARY_STORAGE_SIZE, td.ts_data.data);

        td.thread_context = context;
        td.thread_context.temporary_storage = ts;

        failed := pthread_create(*it.handle, *thread_attributes, #bake_arguments worker_pthread_start(User_Data = User_Data), xx *it.thread_data);
        if failed {
            // The man page seems to indicate that pthread_create actually
            // returns this but I hope that errno will return it as well.
            code := errno();
            // We probably ran out of memory.
            pthread_mutex_destroy(*queue.completion_blocker.lock);
            pthread_cond_destroy(*queue.completion_blocker.condition);
            for 0..it_index-1 {
                pthread_mutex_destroy(*queue.worker_threads[it].requests_blocker.lock);
                pthread_cond_destroy(*queue.worker_threads[it].requests_blocker.condition);
                pthread_cancel(queue.worker_threads[it].handle);
                pthread_detach(queue.worker_threads[it].handle);
            }
            free(queue);
            return null, error(.Catastrophic, code);
        }
    }

    return queue;
}

destroy_queue :: inline (queue: *Queue) {
    if !queue return;
    pthread_mutex_destroy(*queue.completion_blocker.lock);
    pthread_cond_destroy(*queue.completion_blocker.condition);
    for * queue.worker_threads {
        pthread_mutex_destroy(*it.requests_blocker.lock);
        pthread_cond_destroy(*it.requests_blocker.condition);
        pthread_cancel(it.handle);
        pthread_detach(it.handle);
    }
    free(queue);
}

open_file  :: (queue: *Queue($T), file_path: string, keep_existing_content := true) -> File(T), result := Error.{} {
    using file: File(T);
    descriptor = open(temp_c_string(file_path), O_RDWR | O_CREAT | O_CLOEXEC | (ifx keep_existing_content cast(s32)0 else O_TRUNC), 0x1B4); // 0o664
    if descriptor == -1 return file, error(.FileAccessFailed, errno());
    unfinished_operations = New(s64, false);
    <<unfinished_operations = 1;
    return file;
}
close_file :: inline (queue: *Queue, file: File) {
    finish_operation(file);
}

read_entire_file  :: inline (queue: *Queue($T), file_path: string, user_data: T) -> result := Error.{} {
    return submit_to_queue(queue, get_operation(0, file_path, .[], .READ_ENTIRE_FILE, user_data));
}
write_entire_file :: inline (queue: *Queue($T), file_path: string, data: [] u8, user_data: T) -> result := Error.{} {
    return submit_to_queue(queue, get_operation(0, file_path, data, .WRITE_ENTIRE_FILE, user_data));
}

read_file  :: inline (queue: *Queue($T), file: File, position: s64, data: [] u8, user_data: T) -> result := Error.{} {
    atomic_increment(file.unfinished_operations);
    return submit_to_queue(queue, get_operation(position, file, data, .READ, user_data));
}
write_file :: inline (queue: *Queue($T), file: File, position: s64, data: [] u8, user_data: T) -> result := Error.{} {
    atomic_increment(file.unfinished_operations);
    return submit_to_queue(queue, get_operation(position, file, data, .WRITE, user_data));
}

wait_for_completion :: (queue: *Queue($T), check_only := false) -> T, data: [] u8, result := Error.{} {
    while true {
        starting_version := queue.completion_version;
        for * queue.worker_threads {
            bit_index: u32 = ---;
            success := false;
            while !success {
                available := bit_scan_forward(it.available_indexes);
                if !available break;

                bit_index = cast(u32)available - 1;
                available_indexes_ptr := *it.available_indexes; // @ToDo Fix this using some magic!

                #if CPU == .X64 {
                    #asm {
                        lock_btr.d [available_indexes_ptr], bit_index;
                        setc success;
                    }
                } else {
                    mask := 1 << bit_index;

                    while true {
                        old := it.available_indexes;
                        if old & mask == 0 then break;

                        new := cast(u32) old & ~mask;

                        if compare_and_swap(available_indexes_ptr, old, new) {
                            success = true;
                            break;
                        }
                    }
                }
            }
            if success {
                completion := *it.waiting_completions[bit_index];

                #if CPU == .X64 {
                    MAX_WAIT :: 16;
                    wait     := 1;
                    while !completion.valid {
                        for 1..wait #asm { pause; }
                        if wait < MAX_WAIT then wait <<= 1;
                    }
                }

                data := completion.data;
                user_data := completion.user_data;
                completion.valid = false;

                if bit_index == 0 {
                    // Since bits should be filled top to bottom, we will usually only get
                    // this if the queue was full or close to it. We we will always get
                    // it when it is full. So it's a reasonable time to wake someone up.
                    wake_up(*it.completions_blocker);
                }

                return user_data, data, completion.success;
            }
        }
        if starting_version == queue.completion_version {
            // Seems like nothing has been added so we have to wait
            if check_only {
                // Actually we aren't going to wait
                never: T;
                return never, .[], error(.DidNotWait);
            }
            lock(*queue.completion_blocker);
            while starting_version == queue.completion_version {
                block(*queue.completion_blocker);
            }
            unlock(*queue.completion_blocker);
        }
    }
    never: T;
    return never, .[], error(.Catastrophic);
}

#scope_file

File_Operation_Action :: enum u8 {
    READ;
    WRITE;
    READ_ENTIRE_FILE;
    WRITE_ENTIRE_FILE;
}

File_Operation :: struct(User_Data: Type) {
    position: s64;
    union {
        // This is a path for READ_ENTIRE_FILE and WRITE_ENTIRE_FILE;
        file: File(User_Data);
        file_path: string;
    }
    data: [] u8; // Location to read to or write from and length

    action: File_Operation_Action;

    user_data: User_Data;
}

get_operation :: inline (position: s64, file_path: string, data: [] u8, action: File_Operation_Action, user_data: $T) -> File_Operation(T) {
    operation: File_Operation(T);
    operation.position  = position;
    operation.file_path = file_path;
    operation.data      = data;
    operation.action    = action;
    operation.user_data = user_data;
    return operation;
}
get_operation :: inline (position: s64, file: File($T), data: [] u8, action: File_Operation_Action, user_data: T) -> File_Operation(T) {
    operation: File_Operation(T);
    operation.position  = position;
    operation.file      = file;
    operation.data      = data;
    operation.action    = action;
    operation.user_data = user_data;
    return operation;
}

finish_operation :: inline (file: File) {
    if atomic_decrement(file.unfinished_operations) {
        free(file.unfinished_operations);
        close(file.descriptor); // Report errors
    }
}

submit_to_queue :: (queue: *Queue($T), operation: File_Operation(T)) -> result := Error.{} {
    index := atomic_add(*queue.rr_index, 1) % queue.worker_threads.count;
    original_index := index;

    thread := *queue.worker_threads[index];

    our_claim := atomic_read(*thread.claimed_requests);
    success   := false;
    skip      := false;
    MAX_WAIT  :: 16;
    wait      := 1;
    while !success {
        if our_claim - thread.reaped_requests + 1 > queue.SUBMISSION_ENTRIES {
            index = (index + 1) % queue.worker_threads.count;
            if index == original_index return error(.FullQueue); // Give up after one go around even though space could have been cleared
            thread = *queue.worker_threads[index];
            our_claim = atomic_read(*thread.claimed_requests);
            skip = true;
        }
        if !skip {
            success, our_claim = compare_and_swap(*thread.claimed_requests, our_claim, our_claim + 1);
            #if CPU == .X64 {
                if !success {
                    for 1..wait {
                        #asm { pause; }
                        if wait < MAX_WAIT then wait <<= 1;
                    }
                }
            }
        } else {
            wait = 1;
        }
        skip = false;
    }

    our_index := our_claim % queue.SUBMISSION_ENTRIES;
    request := *thread.waiting_requests[our_index];

    request.operation = operation;

    request.valid = true;
    previous_count := atomic_add(*thread.available_requests, 1);
    if previous_count == 0 {
        // Either we are the first request in a while so we need to wake the
        // thread up or a wake-up was requested by having this set to zero.
        wake_up(*thread.requests_blocker);
    }

    return;
}

Blocker :: struct {
    lock: pthread_mutex_t;
    condition: pthread_cond_t;
}

wake_up :: inline (blocker: *Blocker) {
    pthread_mutex_lock(*blocker.lock);
    pthread_cond_broadcast(*blocker.condition);
    pthread_mutex_unlock(*blocker.lock);
}

// Requires the blocker to be locked first
block :: inline (blocker: *Blocker) {
    pthread_cond_wait(*blocker.condition, *blocker.lock);
}

lock :: inline (blocker: *Blocker) {
    pthread_mutex_lock(*blocker.lock);
}

unlock :: inline (blocker: *Blocker) {
    pthread_mutex_unlock(*blocker.lock);
}


// Worker thread procedures
Worker_Thread :: struct(User_Data: Type) {
    handle: pthread_t;

    requests_blocker: Blocker;
    available_requests: s64;
    claimed\ _requests: s64;
    reaped\  _requests: s64;
    // @ToDo: Deal with error on full
    waiting\ _requests: [32] struct {
        valid: bool;
        operation: File_Operation(User_Data);
    };

    available_indexes: u32;
    completions_blocker: Blocker;
    waiting_completions: [32] struct {
        valid:     bool;
        data:   [] u8;
        success:   Error;
        user_data: User_Data;
    };

    thread_data: Thread_Data(User_Data);
}

Thread_Data :: struct(User_Data: Type) {
    queue: *Queue(User_Data);
    thread_id: u8; // This is our interal thread id (the index into worker_threads)
    name: string; // Must be null-terminated!

    ts: Temporary_Storage;
    ts_data: [TEMPORARY_STORAGE_SIZE] u8 #align 64;
    thread_context: #Context;
}

worker_pthread_start :: (arg: *void, $User_Data: Type) -> *void #c_call {
    td := cast(*Thread_Data(User_Data)) arg;
    #if OS == .MACOS then pthread_setname_np(td.name.data); // @ToDo: Can this be done on Linux?
    global_thread_id: u64 = ---;
    pthread_threadid_np(null, *global_thread_id); // @ToDo: This needs a portable version
    // thread_index is a u32 but macOS returns a u64. Maybe the context should
    // have this as u64 since it seems like that is what all platforms do.
    td.thread_context.thread_index = cast,trunc(u32)global_thread_id;

    // We set this thread to background which decreases our IO priority but we
    // really want to have the highest IO priority so let's set the priority back up
    #if OS == .MACOS then setiopolicy_np(IOPOL_TYPE_DISK, IOPOL_SCOPE_THREAD, IOPOL_IMPORTANT);

    // Hopefully our context is now good to go!
    push_context *td.thread_context {
        worker_thread_start(td.queue, td.thread_id);
    }
    return null;
}

worker_thread_start :: (queue: *Queue, thread_id: u8) {
    thread := *queue.worker_threads[thread_id];
    while true {
        // @ToDo Change cancelation mode
        // @ToDo Finish this...
        if thread.available_requests {
            request := *thread.waiting_requests[thread.reaped_requests % queue.COMPLETION_ENTRIES];
            if !request.valid {
                #if CPU == .X64 {
                    for 0..6 {
                        for 1..(1<<it) #asm { pause; }
                        if request.valid break;
                    }
                }

                if !request.valid {
                    lock(*thread.requests_blocker);
                    replace := atomic_swap(*thread.available_requests, 0);
                    while !request.valid {
                        while !thread.available_requests {
                            block(*thread.requests_blocker);
                        }
                        replace += atomic_swap(*thread.available_requests, 0);
                    }
                    atomic_add(*thread.available_requests, replace);
                    unlock(*thread.requests_blocker);
                }
            }

            handle_request(queue, thread, *request.operation);

            #if false {
                <<request = .{}; // We should only need to set valid to false but clearing helps with debugging
            }
            request.valid = false;

            thread.reaped_requests += 1;
            atomic_decrement(*thread.available_requests);
            reset_temporary_storage();
            pthread_testcancel();
        } else {
            // Looks like there are no requests so let's wait
            lock(*thread.requests_blocker);
            while !thread.available_requests {
                block(*thread.requests_blocker);
            }
            unlock(*thread.requests_blocker);
        }
    }
}

handle_request :: (queue: *Queue($T), thread: *Worker_Thread, request: *File_Operation(T)) {
    success: Error;
    if request.action == {
        case .READ_ENTIRE_FILE;
            file: File(T);
            if request.file_path.data == null {
                file.descriptor = -1;
            } else {
                file.descriptor = open(temp_c_string(request.file_path), O_RDONLY | O_CLOEXEC, 0x1B4); // 0o664
            }
            if file.descriptor == -1 {
                success = error(.FileAccessFailed, errno());
            } else {
                request.file = file;

                file_metadata: stat_t = ---;
                if fstat(file.descriptor, *file_metadata) == -1 {
                    success = error(.FileAccessFailed, errno());
                    close(file.descriptor);
                } else {
                    file_size := file_metadata.st_size;

                    request.data = NewArray(file_size, u8, initialized = false);
                }
            }
            #through;
        case .READ;
            read := 0;
            while success.code == .Success && read < request.data.count {
                result := pread(
                    request.file.descriptor,
                    request.data.data + read,
                    // macOS states that an error will be returned if asking for more than 0x7FFFFFFF bytes
                    cast,no_check(u64)Min(request.data.count - read, 0x7FFFFFFF),
                    request.position + read
                );
                if result == -1 {
                    result = 0;
                    error_code := errno();
                    if error_code == ETIMEDOUT {
                        // This could be resolved by a retry but probably should only be retried a few times
                        // (or after a wait) so I'm leaving this condition as a place to add that in the future
                        success = error(.Incomplete, error_code);
                    } else if error_code != EINTR {
                        success = error(.Incomplete, error_code);
                    }
                }
                read += result;
            }
            if success.code != .Success {
                request.data.count = read;
            }
            if request.action == .READ {
                finish_operation(request.file);
            } else {
                close(request.file.descriptor);
            }
        case .WRITE_ENTIRE_FILE;
            file: File(T);
            file.descriptor = open(request.file_path.data, O_WRONLY | O_CREAT | O_CLOEXEC | O_TRUNC, 0x1B4); // 0o664
            if file.descriptor == -1 {
                success = error(.FileAccessFailed, errno());
            } else {
                request.file = file;
            }
            #through;
        case .WRITE;
            written := 0;
            while success.code == .Success && written < request.data.count {
                result := pwrite(
                    request.file.descriptor,
                    request.data.data + written,
                    // macOS states that an error will be returned if asking for more than 0x7FFFFFFF bytes
                    cast,no_check(u64)Min(request.data.count - written, 0x7FFFFFFF),
                    request.position + written
                );
                if result == -1 {
                    result = 0;
                    error_code := errno();
                    if error_code != EINTR {
                        success = error(.Incomplete, error_code);
                    }
                }
                written += result;
            }
            if success.code != .Success {
                request.data.count = written;
            }
            if request.action == .WRITE {
                finish_operation(request.file);
            } else {
                close(request.file.descriptor);
            }
    }

    while true {
        bits := ~thread.available_indexes;
        while bits {
            next := bit_scan_reverse(bits) - 1;
            entry := *thread.waiting_completions[next];
            if !entry.valid {
                entry.data = request.data;
                entry.success = success;
                entry.user_data = request.user_data;
                entry.valid = true;
                atomic_bit_test_and_set(*thread.available_indexes, next);
                total_set := popcount(thread.available_indexes);
                if total_set == 1 {
                    atomic_increment(*queue.completion_version);
                    wake_up(*queue.completion_blocker);
                }
                return;
            }

            #if CPU == .X64 {
                #asm {
                    btr bits, next;
                }
            } else {
                bits &= ~(cast(u32) 1 << next);
            }
        }

        #if CPU == .X64 {
            // There were no spaces in the completion queue! Let's wait a little bit.
            MAX_WAIT :: 16;
            wait     := 1;
            while !~thread.available_indexes {
                for 1..wait #asm { pause; }
                if wait == MAX_WAIT then break;
                wait <<= 1;
            }
        }

        // We tried waiting long enough, time to use the lock.
        if !~thread.available_indexes {
            lock(*thread.completions_blocker);
            while !~thread.available_indexes {
                block(*thread.completions_blocker);
            }
            unlock(*thread.completions_blocker);
        }
    }
}

#if CPU != .X64 {
    atomic_bit_test_and_set :: (dest: *$T, $$i: s64) -> bool {
        SIZE :: size_of(T);
        TOTAL_BITS :: SIZE * 8;

        #assert(SIZE == 2 || SIZE == 4 || SIZE == 8);

        bit_index: s64;
        if i < 0 {
            bit_index = TOTAL_BITS + i;
        } else {
            bit_index = i;
        }

        mask: T = cast(T)(1) << cast(u64)bit_index;

        while true {
            old_value := dest.*;

            if old_value & mask return true;

            new_value := old_value | mask;

            success := compare_and_swap(dest, old_value, new_value);
            if success return false;
        }

        return false;
    }
}

#import "Basic";
#import "POSIX";
#import "System";
#import "Atomics";
#import "Bit_Operations";
