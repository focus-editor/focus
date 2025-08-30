init_file_watcher :: () {
    if watchers.initialized return;

    watchers.project_watcher = File_Watcher.{};
    if !init(*watchers.project_watcher, file_changed_callback, watch_recursively = true) {
        add_user_error("Could not initialize the workspace file watcher. Files won't be reloaded. This is likely a bug.");
        return;
    }

    watchers.external_watcher = File_Watcher.{};
    if !init(*watchers.external_watcher, file_changed_callback, watch_recursively = false) {
        add_user_error("Could not initialize the workspace file watcher. Files won't be reloaded. This is likely a bug.");
        deinit(*watchers.project_watcher);
        return;
    }

    init(*file_watch_thread_group, num_threads = 1, file_watch_threadproc);

    watchers.initialized = true;
}

deinit_file_watcher :: () {
    if !watchers.initialized return;

    shutdown(*file_watch_thread_group);
    file_watch_thread_group = Thread_Group.{};

    deinit(watchers.project_watcher);
    deinit(watchers.external_watcher);
    for watch_files  free(it);
    array_reset_keeping_memory(*watch_files);
    for watch_dirs  free(it);
    array_reset_keeping_memory(*watch_dirs);
    watchers.initialized = false;
    watchers.started = false;
}

maybe_start_file_watcher :: () {
    if watchers.started return;

    if !watchers.initialized {
        log_error("Trying to start the file watcher, but it's not initialized. This is a bug.\n");
        return;
    }

    for unique_project_dirs {
        added := add_directories(*watchers.project_watcher, it);
        if !added log_error("Couldn't start watching directory '%'", it);
    }

    // Add directories that contain standalone files which we want to watch
    for watch_dirs {
        if dir_is_within_project(it) {
            remove it;
            continue;
        }
        added := add_directories(*watchers.external_watcher, it);
        if !added log_error("Couldn't start watching directory '%'", it);
    }

    // Start watching config files
    if global_config.loaded  then start_watching_file_if_not_already(global_config.path);
    if project_config.loaded then start_watching_file_if_not_already(project_config.path);

    start(*file_watch_thread_group);
    watchers.started = true;
}

file_watcher_process_changes :: () {
    // First, gather events from both file watchers in the main thread
    array_reset_keeping_memory(*watchers.project_changes);
    array_reset_keeping_memory(*watchers.external_changes);

    files_changed :=  process_changes(*watchers.project_watcher);
    files_changed ||= process_changes(*watchers.external_watcher);

    // Second, send all the changes to the file watcher thread to process them in the background
    if files_changed {
        task := New(File_Watcher_Background_Task);
        for watchers.project_changes {
            change := array_add(*task.project_changes);
            change.* = it;
            change.full_path = copy_string(it.full_path);
        }
        for watchers.external_changes {
            change := array_add(*task.external_changes);
            change.* = it;
            change.full_path = copy_string(it.full_path);
        }
        add_work(*file_watch_thread_group, task);
    }

    // Third, get the resulting actions from the thread and execute them.
    // The reason we're using a thread is because  we may need to scan a lot of files
    // and potentially check all open buffers (to detect file deletions when a dir gets removed),
    // which can be very expensive on large projects and we can't do it in the main thread.
    // However, the resulting list of actions after all the scanning is done is expected to be small,
    // so we handle them here in the main thread.
    results := get_completed_work(*file_watch_thread_group);
    for results {
        work := cast(*File_Watcher_Background_Task) it;

        // Free work item
        for work.project_changes   free(it.full_path);
        for work.external_changes  free(it.full_path);
        array_free(work.project_changes);
        array_free(work.external_changes);
        free(work);
    }

    // if files_changed {
    //     using watchers;

    //     // Most commonly we will receive only a single MODIFIED event for a single file (after saving a buffer)
    //     // In this case we don't want to rescan anything, but only if no other events were received in the same frame
    //     if project_changes.count == 1 && project_changes[0].events == .MODIFIED {
    //         change := pop(*project_changes);
    //         refresh_buffer_from_disk_by_path(path = change.full_path);
    //     }
    //     if external_changes.count == 1 && external_changes[0].events == .MODIFIED {
    //         change := pop(*external_changes);
    //         parent_dir := get_parent_dir_path(change.full_path);
    //         if dir_is_within_project(parent_dir) || file_is_watched(change.full_path) {
    //             // We only want to refresh if the modified event is for a file we care about
    //             refresh_buffer_from_disk_by_path(path = change.full_path);
    //         }
    //     }

    //     // When a file or a folder is renamed or moved, we should receive 2 MOVED events in a single batch.
    //     // On Windows they will be tagged as MOVED_FROM and MOVED_TO, but e.g. on macos they won't be, so
    //     // we can't rely on that, therefore we'll have to check for file existence instead
    //     maybe_process_file_or_directory_moves(*project_changes);
    //     maybe_process_file_or_directory_moves(*external_changes);

    //     // Maybe add to scanning queue
    //     dirs_to_scan: [..] string;
    //     dirs_to_scan.allocator = temp;

    //     maybe_add_to_queue :: (dirs_to_scan: *[..] string, dir: string) {
    //         add_to_queue := true;
    //         for dirs_to_scan.* {
    //             if begins_with_nocase(dir, it) {
    //                 add_to_queue = false;  // parent or itself is already in the queue
    //                 break;
    //             }
    //             if begins_with_nocase(it, dir) remove it;  // we're adding a parent of this dir
    //         }
    //         if add_to_queue array_add_if_unique(dirs_to_scan, dir);
    //     }

    //     for change : project_changes {
    //         dir: string;
    //         is_directory, success := is_directory(change.full_path);
    //         if success && is_directory {
    //             dir = change.full_path;  // we got an event for a dir within the project
    //         } else if should_watch_file_for_changes(change.full_path) {
    //             dir = get_parent_dir_path(change.full_path);
    //         }
    //         if dir && dir_is_within_project(dir) then maybe_add_to_queue(*dirs_to_scan, dir);

    //         if (change.events & .REMOVED) || (change.events & .MOVED_FROM) then maybe_mark_buffer_as_deleted(change.full_path);
    //     }

    //     for change : external_changes {
    //         if (change.events & .REMOVED) || (change.events & .MOVED_FROM) then maybe_mark_buffer_as_deleted(change.full_path);
    //     }

    //     visitor_func :: (file: *File_Visit_Info, userdata: *void) {
    //         if file.is_directory {
    //             if !should_descend_into_dir(file.full_name) then file.descend_into_directory = false;
    //             return;
    //         }
    //         if file.is_symlink return;

    //         if !should_watch_file_for_changes(file.full_name) return;

    //         refresh_buffer_from_disk_by_path(path = file.full_name);
    //     }

    //     if dirs_to_scan {
    //         print("Scanning dirs: %\n", dirs_to_scan);
    //     }

    //     // @Speed: this may be super expensive on crazy projects like Unreal,
    //     // TODO! do this asynchronously
    //     for dirs_to_scan {
    //         visit_files(it, recursive = true, null, visitor_func, visit_directories = true);
    //     }
    // }
}

start_watching_file_if_not_already :: (file_path: string) {
    assert(context.allocator.proc == focus_allocator.proc, "Unexpected context allocator for start_watching_file_if_not_already. This is a bug.");
    if file_is_watched(file_path) return;

    parent_dir := get_parent_dir_path(file_path);
    if !array_find(watch_dirs, parent_dir) {
        parent_dir = copy_string(parent_dir);
        array_add(*watch_dirs, parent_dir);
        added := add_directories(*watchers.external_watcher, parent_dir);
        if !added {
            log_error("Couldn't start watching the directory '%' containing file %", parent_dir, file_path);
            return;
        }
        log("Started watching external directory '%'", parent_dir);
    }
    full_path, success := get_absolute_path(file_path,, temp);
    if !success {
        log_error("Couldn't start watching file % because it's not found", file_path);
        return;
    }
    full_path = copy_string(full_path);
    path_overwrite_separators(full_path, #char "/");
    array_add_if_unique(*watch_files, full_path);
}

stop_watching_file :: (file_path: string) {
    full_path, success := get_absolute_path(file_path,, temp);
    if !success then return;
    path_overwrite_separators(full_path, #char "/");

    found, index := array_find(watch_files, full_path);
    if found then array_unordered_remove_by_index(*watch_files, index);
}

file_is_watched :: (file_path: string) -> bool {
    parent_dir := get_parent_dir_path(file_path);
    if dir_is_within_project(parent_dir) return true;  // project dirs are watched
    for watch_files {
        if platform_path_equals(it, file_path) return true;
    }
    return false;
}

should_watch_file_for_changes :: inline (path: string) -> bool {
    return !should_ignore_file(path) ||
            is_our_config_file(path) ||
            find_buffer_id_by_path(path) >= 0;  // if buffer is already open, we want to see changes even if it's ignored
}


#scope_file

file_changed_callback :: (watcher: *File_Watcher(void), change: *File_Change, user_data: *void) {
    dest := ifx watcher == *watchers.project_watcher then *watchers.project_changes else *watchers.external_changes;
    array_add(dest, File_Change.{
        full_path = copy_temporary_string(change.full_path),
        events = change.events,
        time_of_last_change = change.time_of_last_change,
    });
}

// !!!!!!!!!!!!!!!!
maybe_process_file_or_directory_moves :: (changes_ptr: *[] File_Change) {
    changes := changes_ptr.*;

    // Find all MOVED events in the batch
    change1, change2: File_Change;
    num_moved_events := 0;
    for changes {
        if !(it.events & .MOVED) continue;
        if      num_moved_events == 0  change1 = it;
        else if num_moved_events == 1  change2 = it;
        num_moved_events += 1;
    }
    // We only handle the case when there are exactly 2 MOVED events, otherwise we fall back to scanning
    if num_moved_events != 2 return;

    moved_from, moved_to := change1.full_path, change2.full_path;
    if file_exists(moved_from) then moved_from, moved_to = moved_to, moved_from;

    // In fact these could be just due to a race (imagine if some program keeps renaming files very quickly),
    // but there's not much we can do in that case, so we just give up
    if file_exists(moved_from) {
        log_error("Potential File Watcher bug: got 2 MOVED events for files that both exist: %, %\n", change1, change2);
        return;
    }
    if !file_exists(moved_to) {
        log_error("Potential File Watcher bug: got 2 MOVED events, but the target doesn't exist: %, %\n", change1, change2);
        return;
    }

    // At this point we've determined that we have 2 correct MOVED events
    if is_directory(moved_to) {
        // Move dir (TODO)
        print("Moving dir '%' to '%'\n", moved_from, moved_to);
    } else {
        // Move file
        print("Moving file '%' to '%'\n", moved_from, moved_to);
    }
}

file_watch_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    assert(group.worker_info.count == 1);  // should only be only one thread always

    task := cast(*File_Watcher_Background_Task) work;
    project_changes  := task.project_changes;
    external_changes := task.external_changes;

    // Possibilities:
    // - We get a single MODIFIED event for a single file (most common) - no need to scan anything
    // - We get 2 MOVED events in a single batch (either for files or for dirs) - this indicates a move or rename
    //     - Usually when this happens we also get another MODIFIED | SCAN_CHILDREN event for the parent dir
    // - We get a single ADDED event for a file - in this case we might not get an extra SCAN_CHILDREN event for the parent
    //     - However sometimes we do, depending on what program added the file
    // - We get a single ADDED event for a dir - then we seem to always get an extra SCAN_CHILDREN for the parent
    // - We get a single REMOVED event for a dir or a file - then we seem to always get an extra SCAN_CHILDREN for the parent

    // For project changes, collect dirs to scan, then scan the dirs. Do nothing else. Add logging for visibility.
    // For external changes, collect dirs to scan, but when scanning only react to changes to the specific files we're watching
    // Only when this works, think whether this can be optimised

    dirs_to_scan: [..] string;
    dirs_to_scan.allocator = temp;

    for task.project_changes {
        log("[Project file watcher]: %\n", it);
        dir: string;
        is_directory, success := is_directory(it.full_path);
        if success && is_directory {
            dir = it.full_path;
        } else {
            dir = get_parent_dir_path(it.full_path);
        }
        if dir then array_add_if_unique(*dirs_to_scan, dir);
    }

    // !!!!!! TODO: when we have a thread-safe config, get back to this:
    visitor_func :: (file: *File_Visit_Info, userdata: *void) {
        if file.is_directory {
            if !should_descend_into_dir(file.full_name) then file.descend_into_directory = false;
            return;
        }
        if file.is_symlink return;

        if !should_watch_file_for_changes(file.full_name) return;

        // refresh_buffer_from_disk_by_path(path = file.full_name);
    }

    if dirs_to_scan {
        print("Scanning dirs: %\n", dirs_to_scan);
    }

    for dirs_to_scan {
        visit_files(it, recursive = true, null, visitor_func, visit_directories = true);
    }

    for task.external_changes {
        log("[External file watcher]: %\n", it);
    }

    if dirs_to_scan {
        log("[Dirs to scan]: %\n", dirs_to_scan);
    }

    // TODO:
    // Accumulate events for some time, then act on them - avoid double-scanning

    // // Most commonly we will receive only a single MODIFIED event for a single file (after saving a buffer)
    // // In this case we don't want to rescan anything, but only if no other events were received in the same frame
    // if project_changes.count == 1 && project_changes[0].events == .MODIFIED {
    //     change := pop(*project_changes);
    //     array_add(*task.actions, .{ type = .modified, path = change.full_path });
    // }
    // if external_changes.count == 1 && external_changes[0].events == .MODIFIED {
    //     change := pop(*external_changes);
    //     if file_is_watched(change.full_path) {
    //         // We only want to refresh if the modified event is for a file we care about
    //         array_add(*task.actions, .{ type = .modified, path = change.full_path });
    //     }
    // }

    return .CONTINUE;
}

File_Watcher_Background_Task :: struct {
    project_changes:  [..] File_Change;
    external_changes: [..] File_Change;

    // Resulting actions will be written here by the thread
    actions: [..] File_Change_Action;

    File_Change_Action :: struct {
        type: enum { modified; added; removed; moved; };
        path: string;
        moved_to: string;
    }
}

watchers : struct {
    initialized := false;
    started     := false;

    project_watcher:  File_Watcher;   // recursive
    external_watcher: File_Watcher;   // non-recursive

    project_changes:  [..] File_Change;
    external_changes: [..] File_Change;
}

watch_dirs:  [..] string;       // dirs we watch which are not project dirs
watch_files: [..] string;       // files outside of projects that we want to watch

file_watch_thread_group:    Thread_Group;
