init_file_watcher :: () {
    if watchers.initialized return;

    watchers.project_watcher = File_Watcher.{};
    if !init(*watchers.project_watcher, file_changed_callback, watch_recursively = true) {
        add_user_error("Could not initialize the workspace file watcher. Files won't be reloaded. This is likely a bug.");
        watchers.initialized = false;
        return;
    }

    watchers.external_watcher = File_Watcher.{};
    if !init(*watchers.external_watcher, file_changed_callback, watch_recursively = false) {
        add_user_error("Could not initialize the workspace file watcher. Files won't be reloaded. This is likely a bug.");
        watchers.initialized = false;
        deinit(watchers.project_watcher);
        return;
    }

    watchers.initialized = true;
}

deinit_file_watcher :: () {
    if !watchers.initialized return;
    deinit(watchers.project_watcher);
    deinit(watchers.external_watcher);
    for watch_files  free(it);
    array_reset_keeping_memory(*watch_files);
    watchers.initialized = false;
}

start_file_watcher :: () {
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
        if path_is_within_project(it) {
            remove it;
            continue;
        }
        added := add_directories(*watchers.external_watcher, it);
        if !added log_error("Couldn't start watching directory '%'", it);
    }

    // Start watching config files
    if global_config.loaded  then start_watching_file_if_not_already(global_config.path);
    if project_config.loaded then start_watching_file_if_not_already(project_config.path);
    start_watching_config_themes();

    // Make sure all buffers in the current workspace are watched
    // (this should cover workspace reloads)
    for * buffer : open_buffers {
        if buffer.internal || !buffer.has_file || !buffer.file.full_path continue;
        start_watching_file_if_not_already(buffer.file.full_path);
    }
}

file_watcher_process_changes :: () {
    auto_release_temp();

    using watchers;

    // Check for any changes to the files we care about
    array_reset_keeping_memory(*changes);

    process_changes(*project_watcher);
    process_changes(*external_watcher);

    if !changes return;

    paths_to_refresh: [..] string;
    deletion_checks:  [..] string;
    dirs_to_scan:     [..] string;

    paths_to_refresh.allocator = temp;
    deletion_checks.allocator  = temp;
    dirs_to_scan.allocator     = temp;

    for changes  color_preview_invalidate_theme(it.full_path);

    // // Most commonly we will receive only a single MODIFIED event for a single file (after saving a buffer)
    // // In this case we don't want to rescan anything, but only if no other events were received in the same frame
    // if project_changes.count == 1 && project_changes[0].events == .MODIFIED {
    //     change := pop(*project_changes);
    //     if should_watch_file_for_changes(change.full_path) then array_add(*paths_to_refresh, change.full_path);
    // }
    // if external_changes.count == 1 && external_changes[0].events == .MODIFIED {
    //     change := pop(*external_changes);
    //     if file_is_watched(change.full_path) then array_add(*paths_to_refresh, change.full_path);
    // }

    // // When a file or a folder is renamed or moved, we should receive 2 MOVED events in a single batch.
    // // On Windows they will be tagged as MOVED_FROM and MOVED_TO, but e.g. on macos they won't be, so
    // // we can't rely on that, therefore we'll have to check for file existence instead
    // maybe_process_file_or_directory_moves(*changes);

    update_scan_queue :: (dirs_to_scan: *[..] string, dir: string) {
        for dirs_to_scan.* {
            if path_is_within_other_path(dir, it) return;  // dir is already covered
        }
        for dirs_to_scan.* {
            if path_is_within_other_path(it, dir) remove it;  // we're adding a parent of an existing dir
        }
        array_add(dirs_to_scan, dir);
    }

    for change : changes {
        path := change.full_path;

        if (change.events & .REMOVED) || (change.events & .MOVED_FROM) then array_add(*deletion_checks, path);

        if !path_is_within_project(path) {
            for watched_path : watch_files {
                if path_is_within_other_path(watched_path, path) then array_add(*paths_to_refresh, watched_path);
            }
            continue;
        }

        is_dir, success := is_directory(path);

        if (change.events & .SCAN_CHILDREN) || (success && is_dir) {
            update_scan_queue(*dirs_to_scan, path);
            continue;
        }

        if success {
            if should_watch_file_for_changes(path) {
                array_add(*paths_to_refresh, path);
            }
            continue;
        }

        // Known buffers still need checking even if their files disappear
        if find_buffer_id_by_path(path) >= 0 {
            array_add(*paths_to_refresh, path);
            continue;
        }

        if change.events & (.ADDED | .REMOVED | .MOVED) {
            parent_dir := get_parent_dir_path(path);
            if parent_dir && path_is_within_project(parent_dir) then update_scan_queue(*dirs_to_scan, parent_dir);
        }
    }

    // Scan the scan queue
    visitor_func :: (file: *File_Visit_Info, paths_to_refresh: *[..] string) {
        if file.is_directory {
            if !should_descend_into_dir(file.full_name) then file.descend_into_directory = false;
            return;
        }
        if file.is_symlink return;

        if !should_watch_file_for_changes(file.full_name) return;

        array_add(paths_to_refresh, copy_temporary_string(file.full_name));
    }

    for dirs_to_scan {
        print("Scanning dir: %\n", it);
        visit_files(it, recursive = true, *paths_to_refresh, visitor_func, visit_directories = true);
    }

    for deletion_checks {
        maybe_mark_buffer_as_deleted(it);
    }

    for paths_to_refresh {
        refresh_buffer_from_disk_by_path(it);
    }
}

start_watching_config_themes :: () {
    if !watchers.initialized return;

    push_allocator(focus_allocator);

    if global_config.loaded && global_config.theme_path {
        start_watching_file_if_not_already(global_config.theme_path);
    }
    if project_config.loaded && project_config.theme_path {
        start_watching_file_if_not_already(project_config.theme_path);
    }
}

start_watching_file_if_not_already :: (file_path: string) {
    assert(context.allocator.proc == focus_allocator.proc, "Unexpected context allocator for start_watching_file_if_not_already. This is a bug.");
    if file_is_watched(file_path) return;

    log("Start watching file '%'", file_path);

    parent_dir := get_parent_dir_path(file_path);
    if !array_find(watch_dirs, parent_dir) {
        parent_dir = copy_string(parent_dir);
        array_add(*watch_dirs, parent_dir);
        added := add_directories(*watchers.external_watcher, parent_dir);
        if !added {
            log_error("Couldn't start watching the directory '%' containing file '%'", parent_dir, file_path);
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
    if path_is_within_project(parent_dir) return true;  // project dirs are watched
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
    array_add(*watchers.changes, File_Change.{
        full_path = copy_temporary_string(change.full_path),
        events = change.events,
        time_of_last_change = change.time_of_last_change,
    });
}

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
    // TODO

    return .CONTINUE;
}

watchers : struct {
    initialized := false;

    project_watcher:  File_Watcher;   // recursive
    external_watcher: File_Watcher;   // non-recursive

    changes: [..] File_Change;
}

watch_dirs:  [..] string;       // dirs we watch which are not project dirs
watch_files: [..] string;       // files outside of projects that we want to watch

file_watch_thread_group:    Thread_Group;
