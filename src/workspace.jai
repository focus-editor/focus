scan_buffers_and_init_file_watcher :: () {
    init(*scanner_thread, num_threads = 1, group_proc = do_initial_scan_threadproc);
    scanner_thread.name = "Project Scanner";
    scanner_thread.logging = true;
    
    start(*scanner_thread);
    
    add_work(*scanner_thread, *project_dirs, "Initial scan");
}

#scope_file

do_initial_scan_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    dirs := << cast(*[] Project_Dir) work;
    
    // Visit every file in the project and maybe open a buffer for it
    Visitor_Data :: struct {
        queue: *File_Async.Queue(string);
        files_left_to_read: s64;
    }
    using visitor_data: Visitor_Data;
    queue = File_Async.initialize_queue(string);
    defer File_Async.destroy_queue(queue);
    
    for dirs visit_files(it.path, recursive = true, *visitor_data, visitor_func, visit_directories = true);
    
    visitor_func :: (file: *File_Visit_Info, using visitor_data: *Visitor_Data) {
        if file.is_directory {
            for workspace.ignore_dirs {
                if equal_nocase(file.short_name, it) {  // TODO: do a wildcard match
                    file.descend_into_directory = false;
                    return;
                }
            }
            return;
        }
        if file.is_symlink return;
        
        for workspace.ignore_file_extensions {
            if ends_with_nocase(file.short_name, it) return;  // TODO: do a wildcard match
        }
    
        // Start an asynchronous read
        file_path := copy_temporary_string(file.full_name);
        result := File_Async.read_entire_file(queue, file_path, file_path);
        files_left_to_read += 1;
        if result.code == .FullQueue {
            full_path, data, success := File_Async.wait_for_completion(queue);
            if success.code == .Success {
                create_buffer_for_file(full_path, to_string(data));
            } else {
                log_error("Error while waiting for completion: %\n", success);
            }
            files_left_to_read -= 1;
            result = File_Async.read_entire_file(queue, file_path, file_path);
        }
        if result.code != .Success {
            log_error("Error while trying to read file % asynchronously: %\n", file_path, result);
            files_left_to_read -= 1;
        }
    }
    
    // Finish reading files
    for 1 .. files_left_to_read {
        full_path, data, success := File_Async.wait_for_completion(queue);
        if success.code == .Success {
            create_buffer_for_file(full_path, to_string(data));
        } else {
            log_error("Error while waiting for completion: %\n", success);
        }
    }
    
    print("Total size: % Mb\n", cast(float) total_size / (1024 * 1024));
    
    return .STOP;  // don't need this thread any more
}

create_buffer_for_file :: (path: string, data: string) {
    if not_a_text_file(data) return;
    if !ends_with_nocase(path, ".jai") && !ends_with_nocase(path, ".cpp") && !ends_with_nocase(path, ".h") print("%\n", path);
    total_size += data.count;
}

total_size := 0;

not_a_text_file :: (file_data: string) -> bool {
    bytes := to_bytes(file_data);
    for byte : bytes { 
        if byte == 0 return true;
    }
    return false;
}


get_pool_allocator :: () -> Allocator {
    a: Allocator;
    a.proc = flat_pool_allocator_proc;
    a.data = *memory_pool;
    return a;
}

Workspace :: struct {
    ignore_dirs: [] string = string.[".build", ".git", "bin"];
    ignore_file_extensions: [] string = string.[
        ".exe", ".pdb", ".ttf", ".otf", ".dll", ".lib", ".dylib", ".so", ".so.0", ".so.1", ".so.2", ".a", 
        ".jpg", ".png", ".gif", ".jpeg", ".ico", ".tif", ".tiff", ".tga", ".bmp",
        ".mp3", ".wav", ".ogg",
        ".mpeg", ".psd", ".codex",
    ];
}

workspace: Workspace;  // TODO: load from a config file
scanner_thread: Thread_Group;
memory_pool: Flat_Pool;

#scope_file

File_Async :: #import "File_Async";