init_workspace :: () {
    for path : config.workspace.workspace_dirs {
        add_directory_to_workspace(path);
    }
}

add_directory_to_workspace :: (path: string, index := -1) {
    full_path := copy_string(get_absolute_path(path));
    path_overwrite_separators(full_path, #char "/");
    
    if !is_directory(full_path) {
        log_error("Couldn't add % to workspace. Directory doesn't exist or is invalid.", full_path);
        return;
    }
    
    dir: Project_Dir;
    dir.path = trim_right(full_path, "/");
    dir.path_prefix_len = find_index_of_any_from_right(dir.path, "./") + 1;
    
    in_project, parent_dir := dir_is_within_project(dir.path);
    if in_project {
        log_error("Directory % is already in the project: %", dir.path, parent_dir);
        return;
    }
    
    if index < 0 {
        array_add(*project_dirs, dir);
    } else {
        array_insert_at(*project_dirs, dir, index);
    }
}

start_initial_workspace_scan :: () {
    scan_pool_allocator := get_scan_pool_allocator();
    
    // Get the list of all files in the project
    {
        push_allocator(scan_pool_allocator);
        
        for project_dirs visit_files(it.path, recursive = true, null, maybe_add_file_to_scan_list, visit_directories = true);
        
        maybe_add_file_to_scan_list :: (file: *File_Visit_Info, userdata: *void) {
            if file.is_directory {
                if should_ignore_dir(file.full_name) {
                    file.descend_into_directory = false;
                    return;
                }
                return;
            }
            if file.is_symlink return;
            
            // NOTE: not checking whether we should ignore the file here,
            // because it may involve reading the file and checking for zeroes,
            // and we'd rather it's done in threads (also if later we find there are no
            // zeroes in the file then the file data will be in cache ready to use)
            array_add(*files_to_scan, copy_string(file.full_name));
        }
    }
    
    num_cpus := get_num_cpus();
    num_threads := max(num_cpus - 1, 1);
    
    files_per_thread := (files_to_scan.count / num_cpus) + 1;
    
    init(*scanner_thread_group, num_threads = num_threads, group_proc = directory_scan_threadproc);
    scanner_thread_group.name = "Workspace Scanner";
    scanner_thread_group.logging = DEBUG;
        
    start(*scanner_thread_group);
    
    file_ranges: = NewArray(num_threads, [] string, allocator = scan_pool_allocator);
    for 0..num_threads-1 {
        file_range := *file_ranges[it];
        start := it * files_per_thread;
        count := min(files_per_thread, files_to_scan.count - start);
        if count <= 0 continue;
        << file_range = array_view(files_to_scan, start, count);
        
        add_work(*scanner_thread_group, file_range, sprint("Scan [%:%]", start, start + count));
    }
}

maybe_update_workspace_buffers :: () {
    if !initial_scan_complete {
        results := get_completed_work(*scanner_thread_group);
        
        num_jobs_to_complete -= results.count;
        if num_jobs_to_complete <= 0 {
            initial_scan_complete = true;
            shutdown(*scanner_thread_group);
            
            reset(*scan_memory_pool);
            
            start_file_watcher();
            init_open_file_dialog();
            init_finder();
        }
        return;
    }
        
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
            if should_ignore_dir(file.full_name) {
                file.descend_into_directory = false;
                return;
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

start_watching_file :: (file_path: string) {
    parent_dir := get_parent_dir_path(file_path);
    if !array_find(watch_dirs, parent_dir) {
        parent_dir = copy_string(parent_dir);
        array_add(*watch_dirs, parent_dir);
        add_directories(*file_watcher, parent_dir);
    }
    full_path := copy_string(get_absolute_path(file_path));
    path_overwrite_separators(full_path, #char "/");
    array_add_if_unique(*watch_files, full_path);
}

file_is_watched :: (file_path: string) -> bool {
    parent_dir := get_parent_dir_path(file_path);
    if dir_is_within_project(parent_dir) return true;  // project dirs are watched
    for watch_files {
        if equal_nocase(it, file_path) return true;
    }
    return false;
}

#scope_file

directory_scan_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    file_range := cast(*[] string) work;
    
    for path : << file_range {
        if should_ignore_file(path) continue;
        find_or_create_buffer(path);
    }
    
    return .CONTINUE;
}

start_file_watcher :: () {
    if !init(*file_watcher, file_change_callback) {
        log_error("Could not initialize workspace file watcher");
        // TODO: add the error to the error log when we have it
        return;
    }
    
    for project_dirs add_directories(*file_watcher, it.path);
    dirs_to_rescan.allocator = temp;
    
    // Add directories that contain standalone files which we want to watch
    for watch_dirs {
        if dir_is_within_project(it) {
            remove it;
            continue;
        }
        add_directories(*file_watcher, it);
    }
}

file_change_callback :: (watcher: *File_Watcher(void), change: *File_Change, user_data: *void) {
    print("%\n", <<change);
    
    // If the change is in one of the ignored dirs, ignore it
    if should_ignore_dir(change.full_path) return;
    
    // If the change is caused by watching a dir containing a standalone file, ignore it
    parent_dir := get_parent_dir_path(change.full_path);
    if !dir_is_within_project(parent_dir) && !file_is_watched(change.full_path) return;
    
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
    // That's probably how Sublime Text modifies files, but still, processing each message here would
    // be harder than just rescanning the containing folder.
    // So instead of processing each event the easiest option here would be to add W:/focus-zig/src
    // to the scanning queue

    // if change.events & .MODIFIED      then buffer_maybe_changed_on_disk(change.full_path);
    // if change.events & .REMOVED       then buffer_maybe_deleted_on_disk(change.full_path);
    // if change.events & .SCAN_CHILDREN then refresh_buffers_in_directory(change.full_path);
    
    if (change.events & .REMOVED) || (change.events & .MOVED_FROM) then maybe_mark_buffer_as_deleted(change.full_path);
}

#scope_file

get_scan_pool_allocator :: () -> Allocator {
    a: Allocator;
    a.proc = flat_pool_allocator_proc;
    a.data = *scan_memory_pool;
    return a;
}

file_watcher: File_Watcher;
dirs_to_rescan: [..] string;    // will use temporary storage
watcher_file_modified: string;  // will contain the path of a file if if was modified and it was the only event in a group,
                                // otherwise it won't be used and a scan will be done instead
                                
watch_dirs:  [..] string;       // dirs we watch which are not project dirs
watch_files: [..] string;       // files outside of projects that we want to watch

scanner_thread_group: Thread_Group;

scan_memory_pool: Flat_Pool;
files_to_scan: [..] string;

initial_scan_complete := false;
num_jobs_to_complete := 0;