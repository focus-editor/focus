Queue :: struct(User_Data: Type) {
    completion_port: HANDLE;
}

File :: struct(User_Data: Type) {
    handle: HANDLE;
    unfinished_operations: *u64;
}

Operation_Data :: struct(User_Data: Type) {
    using base: OVERLAPPED;
    result_data: [] u8;
    handled: s64;
    file: File(User_Data);
    request: RW;
    user_data: User_Data;
}

initialize_queue :: ($User_Data: Type) -> *Queue(User_Data), result := Error.{} {
    completion_port := CreateIoCompletionPort(INVALID_HANDLE_VALUE, null, 0, 0);
    if !completion_port return null, error(.Catastrophic, GetLastError());
    queue := Basic.New(Queue(User_Data));
    queue.completion_port = completion_port;
    return queue;
}

destroy_queue :: (queue: *Queue) {
    CloseHandle(queue.completion_port); // There is nothing we can do about any errors here
    Basic.free(queue);
}

open_file :: (queue: *Queue($T), file_path: string, keep_existing_content := true) -> File(T), result := Error.{} {
    file: File(T);
    file_path_utf16, could_convert := utf8_to_wide(file_path,, Basic.temp);
    if !could_convert return file, error(.FileAccessFailed, GetLastError());
    file.handle = CreateFileW(
        file_path_utf16,
        FILE_GENERIC_READ | FILE_GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        null,
        ifx keep_existing_content cast(u32)OPEN_ALWAYS else CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OVERLAPPED,
        null
    );
    if file.handle == INVALID_HANDLE_VALUE return file, error(.FileAccessFailed, GetLastError());

    if !CreateIoCompletionPort(file.handle, queue.completion_port, 0, 0) {
        code := GetLastError();
        CloseHandle(file.handle);
        file.handle = INVALID_HANDLE_VALUE;

        return file, error(.Catastrophic, code);
    }
    file.unfinished_operations = Basic.New(u64);
    file.unfinished_operations.* = 1;
    return file;
}

close_file :: inline (queue: *Queue, file: File) {
    finish_operation(file);
}

read_entire_file :: (queue: *Queue($T), file_path: string, user_data: T) -> result := Error.{} {
    file: File(T);
    file_path_utf16, could_convert := utf8_to_wide(file_path,, Basic.temp);
    if !could_convert return error(.FileAccessFailed, GetLastError());
    file.handle = CreateFileW(
        file_path_utf16,
        FILE_GENERIC_READ,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        null,
        OPEN_EXISTING,
        FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OVERLAPPED,
        null
    );
    if file.handle == INVALID_HANDLE_VALUE return error(.FileAccessFailed, GetLastError());

    if !CreateIoCompletionPort(file.handle, queue.completion_port, 0, 0) {
        code := GetLastError();
        CloseHandle(file.handle);

        return error(.Catastrophic, code);
    }

    file_info: FILE_STANDARD_INFO = ---;
    if !GetFileInformationByHandleEx(file.handle, FileStandardInfo, *file_info, size_of(FILE_STANDARD_INFO)) {
        code := GetLastError();
        CloseHandle(file.handle);

        return error(.FileAccessFailed, code);
    }

    file_data := Basic.NewArray(file_info.EndOfFile.QuadPart, u8, initialized = false);

    file.unfinished_operations = Basic.New(u64);
    file.unfinished_operations.* = 0;

    return read_file(queue, file, 0, file_data, user_data);
}

write_entire_file :: (queue: *Queue($T), file_path: string, data: [] u8, user_data: T) -> result := Error.{} {
    file: File(T);
    file_path_utf16, could_convert := utf8_to_wide(file_path,, Basic.temp);
    if !could_convert return error(.FileAccessFailed, GetLastError());
    file.handle = CreateFileW(
        file_path_utf16,
        FILE_GENERIC_WRITE,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        null,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL | FILE_FLAG_OVERLAPPED,
        null
    );
    if file.handle == INVALID_HANDLE_VALUE return error(.FileAccessFailed, GetLastError());
    if !CreateIoCompletionPort(file.handle, queue.completion_port, 0, 0) {
        code := GetLastError();
        CloseHandle(file.handle);

        return error(.Catastrophic, code);
    }

    file.unfinished_operations = Basic.New(u64);
    file.unfinished_operations.* = 0;
    return write_file(queue, file, 0, data, user_data);
}

read_file :: inline (queue: *Queue($T), file: File, position: s64, data: [] u8, user_data: T) -> result := Error.{} {
    atomic_increment(file.unfinished_operations);
    if !ReadFile(
        file.handle,
        data.data,
        cast,no_check(u32)Basic.Min(data.count, 0xFFFFFFFF),
        null,
        get_operation_data(position, file, user_data, data, .READ)
    ) && GetLastError() != ERROR_IO_PENDING then {
        finish_operation(file);
        return error(.Catastrophic, GetLastError());
    }
    return;
}
write_file :: inline (queue: *Queue($T), file: File, position: s64, data: [] u8, user_data: T) -> result := Error.{} {
    atomic_increment(file.unfinished_operations);
    if !WriteFile(
        file.handle,
        data.data,
        cast,no_check(u32)Basic.Min(data.count, 0xFFFFFFFF),
        null,
        get_operation_data(position, file, user_data, data, .WRITE)
    ) && GetLastError() != ERROR_IO_PENDING then {
        finish_operation(file);
        return error(.Catastrophic, GetLastError());
    }
    return;
}

wait_for_completion :: (queue: *Queue($T), check_only := false) -> T, data: [] u8, result := Error.{} {
    bytes_transferred: u32;
    completion_key: u64;
    overlapped: *OVERLAPPED;
    operation_data: *Operation_Data(T);
    defer Basic.free(operation_data);
    while true {
        if !GetQueuedCompletionStatus(
            queue.completion_port,
            *bytes_transferred,
            *completion_key,
            *overlapped,
            ifx check_only then cast(u32)0 else WIN_TIMEOUT_INFINITE
        ) then {
            if overlapped == null {
                // GetQueuedCompletionStatus itself failed
                code := GetLastError();
                empty: T;
                if code == WAIT_TIMEOUT {
                    return empty, .[], error(.DidNotWait, code);
                } else {
                    return empty, .[], error(.Catastrophic, code);
                }
            } else {
                // The IO failed
                operation_data = xx overlapped;
                operation_data.handled += bytes_transferred;
                // Only return the amount of data that we actually got.
                operation_data.result_data.count = operation_data.handled;
                finish_operation(operation_data.file);
                return operation_data.user_data, operation_data.result_data, error(.Incomplete, GetLastError());
            }
        }
        operation_data = xx overlapped; // We passed in an Operation_Data(T) so we will get one out
        operation_data.handled += bytes_transferred;
        if operation_data.handled < operation_data.result_data.count {
            operation_data.Offset64 += bytes_transferred;
            if operation_data.request == .READ {
                if !ReadFile(
                    operation_data.file.handle,
                    operation_data.result_data.data + operation_data.handled,
                    cast,no_check(u32)Basic.Min(operation_data.result_data.count - operation_data.handled, 0xFFFFFFFF),
                    null,
                    operation_data
                ) && GetLastError() != ERROR_IO_PENDING then {
                    operation_data.result_data.count = operation_data.handled;
                    return operation_data.user_data, operation_data.result_data, error(.Incomplete, GetLastError());
                }
            } else {
                if !WriteFile(
                    operation_data.file.handle,
                    operation_data.result_data.data + operation_data.handled,
                    cast,no_check(u32)Basic.Min(operation_data.result_data.count - operation_data.handled, 0xFFFFFFFF),
                    null,
                    operation_data
                ) && GetLastError() != ERROR_IO_PENDING then  {
                    operation_data.result_data.count = operation_data.handled;
                    return operation_data.user_data, operation_data.result_data, error(.Incomplete, GetLastError());
                }
            }
        } else {
            finish_operation(operation_data.file);
            break;
        }
    }
    return operation_data.user_data, operation_data.result_data;
}

#scope_file
RW :: enum u8 { READ; WRITE; }
get_operation_data :: inline (position: s64, file: File, user_data: $T, result_data: [] u8, rw: RW) -> *Operation_Data(T) {
    operation_data: *Operation_Data(T) = Basic.New(Operation_Data(T));
    operation_data.Offset64 = cast(u64)position;
    operation_data.result_data = result_data;
    operation_data.file = file;
    operation_data.request = rw;
    operation_data.user_data = user_data;
    return operation_data;
}

finish_operation :: inline (file: File) {
    if atomic_decrement(file.unfinished_operations) {
        CloseHandle(file.handle);
        Basic.free(file.unfinished_operations);
    }
}

#import "Windows";
#import "Windows_Utf8";
#import "Atomics";
Basic :: #import "Basic";
