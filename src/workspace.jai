start_initial_scan_of_workspace_files :: () {
    init(*scanner_thread, num_threads = xx project_dirs.count, group_proc = initial_scan_threadproc);
    scanner_thread.name = "Project Scanner";
    scanner_thread.logging = true;
    
    init(*buffer_mutex);
    
    start(*scanner_thread);
    
    for * project_dirs add_work(*scanner_thread, it, it.path);
}

maybe_update_workspace_buffers :: () {
    if !initial_scan_complete {
        // Check if the scan is already done
        results := get_completed_work(*scanner_thread);
        num_dirs_scanned += results.count;
        if num_dirs_scanned >= project_dirs.count {
            initial_scan_complete = true;
            shutdown(*scanner_thread);
                        
            // Merge the scanned buffers with the buffers the user may have opened while we were scanning
            // (this happens in the main thread so no synchronization is required)
            // We're assuming the number of scanned buffers will be way higher than the open ones, so we don't copy them
            open_buffers_copy := array_copy(open_buffers);
            open_buffers = scanned_buffers;
            
            // Recreate the path to id hash table
            table_reset(*buffers_table);
            for buffer, buffer_id : open_buffers {
                table_add(*buffers_table, buffer.file.full_path, buffer_id);
            }
            
            // Overwrite the open buffers on top of the scanned ones - they may be more recent
            for buffer, old_buffer_id : open_buffers_copy {
                new_buffer_id := open_buffers.count;  // in case we append
                if buffer.has_file {
                    scanned_buffer_id, success := table_find(*buffers_table, buffer.file.full_path);
                    if success {
                        // Overwrite
                        deinit(*open_buffers[scanned_buffer_id]);
                        open_buffers[scanned_buffer_id] = buffer;
                        new_buffer_id = scanned_buffer_id;
                    } else {
                        // This is a new buffer - append
                        array_add(*open_buffers, buffer);
                        table_set(*buffers_table, buffer.file.full_path, new_buffer_id);
                    }
                } else {
                    // This is a buffer without a file, so append
                    // NOTE: we're not adding it to the table because there's no path
                    array_add(*open_buffers, buffer);
                }
                // Reroute the editors
                for * editor : open_editors {
                    if editor.buffer_id == old_buffer_id then editor.buffer_id = new_buffer_id;
                }
            }
        }
        return;
    }
}

#scope_file

initial_scan_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    dir := << cast(*Project_Dir) work;
        
    // Visit every file in the project and maybe open a buffer for it
    Visitor_Data :: struct {
        queue: *File_Async.Queue(string);
        files_left_to_read: s64;
    }
    using visitor_data: Visitor_Data;
    queue = File_Async.initialize_queue(string);
    defer File_Async.destroy_queue(queue);
    
    visit_files(dir.path, recursive = true, *visitor_data, visitor_func, visit_directories = true);
    
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
        
        for allowed_ext : workspace.allow_file_extensions {
            // Allow known text file extensions since they are the most common
            if ends_with_nocase(file.short_name, allowed_ext) break;
            
            // Then check for common known binary file extensions
            for workspace.ignore_file_extensions {
                if ends_with_nocase(file.short_name, it) return;  // TODO: do a wildcard match
            }
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
    
    return .STOP;  // don't need this thread any more
}

create_buffer_for_file :: (path: string, file_data: string) {
    if find_index_from_left(file_data, byte = 0) >= 0 return;  // if a file has zeroes it's definitely not a well-formed text file
    
    lock(*buffer_mutex);
    buffer := array_add(*scanned_buffers);
    unlock(*buffer_mutex);
    
    fill_in_buffer_from_file_data(buffer, path, file_data);
}

Workspace :: struct {
    ignore_dirs: [] string = string.[".build", ".git", "bin"];
    allow_file_extensions: [] string = string.[".jai", ".c", ".cpp", ".h", ".txt", ".md"];
    ignore_file_extensions: [] string = string.[
        ".exe", ".pdb", ".ttf", ".otf", ".dll", ".lib", ".dylib", ".so", ".so.0", ".so.1", ".so.2", ".a", 
        ".jpg", ".png", ".gif", ".jpeg", ".ico", ".tif", ".tiff", ".tga", ".bmp",
        ".mp3", ".wav", ".ogg",
        ".blend", ".obj", ".fbx", ".dae", ".3ds",
        ".mpg", ".mpeg", ".psd", ".codex",
    ];
}

workspace: Workspace;  // TODO: load from a config file
scanner_thread: Thread_Group;

buffer_mutex: Mutex;

scanned_buffers:  [..] Buffer;
initial_scan_complete := false;
num_dirs_scanned := 0;

#scope_file

File_Async :: #import "File_Async";