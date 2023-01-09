init_workspace :: (exe_dir: string) {
    if !make_directory_if_it_does_not_exist("projects") then panic_messagebox("Couldn't create folder %/projects. Is the directory writable?", exe_dir);
    if !make_directory_if_it_does_not_exist("temp")     then panic_messagebox("Couldn't create folder %/temp for temporary files. Is the directory writable?", exe_dir);
    
    // @Cleanup: remove and do properly
    initial_project_dirs := string.[ "W:/focus", "C:/jai" ];
    for path, i : initial_project_dirs {
        dir: Project_Dir = ---;
        dir.path = path;
        dir.path_prefix_len = find_index_of_any_from_right(path, ".\\/") + 1;
        // TODO: check whether project path exists - add to error log
        array_add(*project_dirs, dir);
    }

    // Start initial scan of the workspace files
    init(*scanner_thread, num_threads = 1, group_proc = initial_scan_threadproc);
    scanner_thread.name = "Project Scanner";
    scanner_thread.logging = true;
        
    start(*scanner_thread);
    
    for * project_dirs add_work(*scanner_thread, it, it.path);
}

maybe_update_workspace_buffers :: () {
    if !initial_scan_complete {
        results := get_completed_work(*scanner_thread);
        
        num_dirs_scanned += results.count;
        if num_dirs_scanned >= project_dirs.count {
            initial_scan_complete = true;
            shutdown(*scanner_thread);
            merge_scanned_buffers_into_open_buffers();
            start_file_watcher();
            init_open_file_dialog();
            init_finder();
        }
        return;
    }
    
    if finder.request.in_progress return;  // don't refresh any buffers while there's an active search request (to avoid a race).
                                           // it should finish soon enough so we can update the buffers after that
    
    files_changed := process_changes(*file_watcher);
    if files_changed {
        if watcher_file_modified.count > 0 && !should_ignore_file(watcher_file_modified) {
            refresh_buffer_from_disk(path = watcher_file_modified);
        }
        // @Speed: it should be ok to rescan everything recursively, because
        // most of the files will already be loaded and they won't refresh if unchanged
        for dirs_to_rescan visit_files(it, recursive = true, null, visitor_func, visit_directories = true);
    }
    
    visitor_func :: (file: *File_Visit_Info, userdata: *void) {
        if file.is_directory {
            for config.workspace.ignore_dirs {
                if equal_nocase(file.short_name, it) {  // TODO: do a wildcard match
                    file.descend_into_directory = false;
                    return;
                }
            }
            return;
        }
        if file.is_symlink return;
        
        if should_ignore_file(file.full_name) return;
        
        refresh_buffer_from_disk(path = file.full_name);
    }
    
    array_reset(*dirs_to_rescan);
    watcher_file_modified = "";
}

#scope_file

should_ignore_file :: (path: string) -> bool {    
    // Allow known text file extensions since they are the most common
    for allowed_ext : config.workspace.allow_file_extensions {
        if ends_with_nocase(path, allowed_ext) return false;
    }
    
    // Then check for common known binary file extensions
    for config.workspace.ignore_file_extensions {
        if ends_with_nocase(path, it) return true;  // TODO: do a wildcard match
    }
    
    // Check for zeroes in the file - if there are any, it's not a well-formed text file.
    // Sorry non-binary files, there are only 2 digits, please don't cancel me.
    // There's a small chance that a binary file will have no zeroes, but it's the easiest
    // thing to check, so that's what we're doing.
    file_data, success := read_entire_file(path);
    if !success return true;
    has_zeroes := find_index_from_left(file_data, byte = 0) >= 0;
    free(file_data);
    if has_zeroes return true;  // ignore
    
    // In this case the file will be read again, but it's OK because:
    // 1. It should happen rarely
    // 2. The file will be in the filesystem cache
    return false;
}

initial_scan_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    dir := << cast(*Project_Dir) work;
    
    visit_files(dir.path, recursive = true, null, visitor_func, visit_directories = true);
    
    visitor_func :: (file: *File_Visit_Info, userdata: *void) {
        if file.is_directory {
            for config.workspace.ignore_dirs {
                if equal_nocase(file.short_name, it) {  // TODO: do a wildcard match
                    file.descend_into_directory = false;
                    return;
                }
            }
            return;
        }
        if file.is_symlink return;
        
        if should_ignore_file(file.full_name) return;
        
        file_data, success := read_entire_file(file.full_name);
        if !success return; 
        
        buffer := array_add(*scanned_buffers);    
        fill_in_buffer_from_file_data(buffer, file.full_name, file_data);
    }
    
    /* -
       commented out the async file reader code for now, because there seems to be a bug with
       the io completion ports module - it doesn't close handles when using read_entire_file etc.
       NOTE: this has been fixed, so could uncomment and adapt this code

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
            for config.workspace.ignore_dirs {
                if equal_nocase(file.short_name, it) {  // TODO: do a wildcard match
                    file.descend_into_directory = false;
                    return;
                }
            }
            return;
        }
        if file.is_symlink return;
        
        for allowed_ext : config.workspace.allow_file_extensions {
            // Allow known text file extensions since they are the most common
            if ends_with_nocase(file.short_name, allowed_ext) break;
            
            // Then check for common known binary file extensions
            for config.workspace.ignore_file_extensions {
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
    */
    
    return .CONTINUE;
}

merge_scanned_buffers_into_open_buffers :: () {
    // Merge the scanned buffers with the buffers the user may have opened while we were scanning
    // (this happens in the main thread so no synchronization is required)
    // We're assuming the number of scanned buffers will be way higher than the number of open buffers, so we don't copy them
    open_buffers_copy := array_copy(open_buffers);
    open_buffers = scanned_buffers;
        
    // NOTE: as we're adding some pointers from the buffers array to the hash table, we should
    // be very careful if we're ever going to remove buffers from the array, because the memory
    // may become invalid
        
    // Recreate the path-to-id hash table
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

start_file_watcher :: () {
    if !init(*file_watcher, file_change_callback) {
        log_error("Could not initialize workspace file watcher");
        // TODO: add the error to the error log when we have it
        return;
    }
    
    for project_dirs add_directories(*file_watcher, it.path);
    dirs_to_rescan.allocator = temp;    
}

file_change_callback :: (watcher: *File_Watcher(void), change: *File_Change, user_data: *void) {
    // If the change is in one of the ignored dirs, ignore it
    path_parts := split(change.full_path, cast(u8) #char "/");
    for part : path_parts {
        for dir : config.workspace.ignore_dirs {
            if part == dir return;
        }
    }
    
    // Most commonly we will receive only a single MODIFIED event for a single file (after saving a buffer)
    // In this case we don't want to rescan anything, but only if no other events were received in the same frame
    if change.events == .MODIFIED && watcher_file_modified.count == 0 {
        watcher_file_modified = copy_temporary_string(change.full_path);
    } else {
        // There are other events - maybe rollback and add dir to the rescan queue
        if watcher_file_modified.count > 0 {
            dir := get_parent_dir_path(watcher_file_modified);
            maybe_add_to_queue(dir);
            watcher_file_modified.count = -1;  // to indicate that we have seen and rejected a MODIFIED event this frame already
        }
        
        // Figure
        dir: string = ---;
        if change.events & .SCAN_CHILDREN {
            dir = copy_temporary_string(change.full_path);
        } else {
            dir = get_parent_dir_path(change.full_path);
        }
        maybe_add_to_queue(dir);
    }
    
    get_parent_dir_path :: (file_path: string) -> string {
        path := path_strip_filename(file_path);
        if path.count > 1 && path[path.count-1] == #char "/" then path.count -= 1;  // don't include trailing path separator
        return path;
    }
    
    maybe_add_to_queue :: (dir: string) {
        add_to_queue := true;
        for dirs_to_rescan {
            if begins_with_nocase(dir, it) {
                add_to_queue = false;  // parent or itself is already in the queue
                break;
            }
            if begins_with_nocase(it, dir) remove it;  // we're adding a parent of this dir
        }
        if add_to_queue array_add(*dirs_to_rescan, dir);
    }
    
    // NOTE: Instead of processing individual events and using the flags we're simply
    // adding folders to the queue for scanning, because the original events seem to be
    // not very reliable. E.g. when a file W:/focus-zig/src/Editors.zig was changed using Sublime Text,
    // here's the list of events we've got:
    // {"W:/focus-zig/src/Editors.zig", MODIFIED, 51.72142}
    // {"W:/focus-zig/src/nPTuLLfc1yEADcLL", ADDED | MODIFIED | MOVED | MOVED_FROM, 52.296619}
    // {"W:/focus-zig/src/Editors.zig", MOVED | MOVED_TO | REMOVED, 52.296619}
    // {"W:/focus-zig/src", MODIFIED | SCAN_CHILDREN, 52.29665}
    // Not very useful, is it? So we can't really rely on those 
    // So instead of processing each event the easiest option here would be to add W:/focus-zig/src
    // to the scanning queue

    // if change.events & .MODIFIED      then buffer_maybe_changed_on_disk(change.full_path);
    // if change.events & .REMOVED       then buffer_maybe_deleted_on_disk(change.full_path);
    // if change.events & .SCAN_CHILDREN then refresh_buffers_in_directory(change.full_path);
    print("%\n", <<change);
    
    if (change.events & .REMOVED) || (change.events & .MOVED_FROM) then maybe_mark_buffer_as_deleted(change.full_path);
}

file_watcher: File_Watcher;
dirs_to_rescan: [..] string;    // will use temporary storage
watcher_file_modified: string;  // will contain the path of a file if if was modified and it was the only event in a group,
                                // otherwise it won't be used and a scan will be done instead

scanner_thread: Thread_Group;

scanned_buffers: [..] Buffer;
initial_scan_complete := false;
num_dirs_scanned := 0;


#scope_file

File_Async :: #import "File_Async";