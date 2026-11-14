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

    files_to_refresh: [..] File_Refresh;
    affected_paths:   [..] string;
    dirs_to_scan:     [..] string;

    files_to_refresh.allocator = temp;
    affected_paths.allocator  = temp;
    dirs_to_scan.allocator     = temp;

    for changes  color_preview_invalidate_theme(it.full_path);

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

        if change.events & (.REMOVED | .MOVED) then array_add(*affected_paths, path);

        if !path_is_within_project(path) {
            for watched_path : watch_files {
                if path_is_within_other_path(watched_path, path) {
                    array_add(*files_to_refresh, .{
                        path = watched_path,
                        check_contents = platform_path_equals(watched_path, path),  // force refresh on direct events
                    });
                }
            }
            continue;
        }

        is_dir, success := is_directory(path);

        if (change.events & .SCAN_CHILDREN) || (success && is_dir) {
            update_scan_queue(*dirs_to_scan, path);
            continue;
        }

        // Known buffers still need checking even if their files disappear
        if find_buffer_id_by_path(path) >= 0 {
            array_add(*files_to_refresh, .{ path = path, check_contents = true });
            continue;
        }

        if success {
            if !should_ignore_file(path) || is_our_config_file(path) {
                array_add(*files_to_refresh, .{ path = path, check_contents = true });
            }
            continue;
        }

        if change.events & (.ADDED | .REMOVED | .MOVED) {
            parent_dir := get_parent_dir_path(path);
            if parent_dir && path_is_within_project(parent_dir) then update_scan_queue(*dirs_to_scan, parent_dir);
        }
    }

    // Scan the scan queue
    visitor_func :: (file: *File_Visit_Info, files_to_refresh: *[..] File_Refresh) {
        path := file.full_name;

        if file.is_directory {
            if !should_descend_into_dir(path) then file.descend_into_directory = false;
            return;
        }
        if file.is_symlink return;

        if find_buffer_id_by_path(path) >= 0 return;  // let the scanner discover only new files
        if should_ignore_file(path) && !is_our_config_file(path) return;

        array_add(files_to_refresh, .{ path = copy_temporary_string(path), check_contents = false });
    }

    for dirs_to_scan {
        array_add(*affected_paths, it);

        log("Scanning dir: %\n", it);
        visit_files(it, recursive = true, *files_to_refresh, visitor_func, visit_directories = true);
    }

    // We have to check all open buffers because if e.g. a directory is deleted, we won't get a notification
    // for every file within that directory and must check ourselves
    for * buffer : open_buffers {
        if buffer.internal || !buffer.has_file || !buffer.file.full_path continue;

        for affected_path : affected_paths {
            if path_is_within_other_path(buffer.file.full_path, affected_path) {
                array_add(*files_to_refresh, .{ path = copy_temporary_string(buffer.file.full_path), check_contents = false });
                break;
            }
        }
    }

    // Deduplicate file refreshes
    {
        path_to_index: Table(string, int);
        path_to_index.allocator = temp;

        for files_to_refresh {
            found, index := table_find(*path_to_index, it.path);
            if found {
                files_to_refresh[index].check_contents |= it.check_contents;
                remove it;
            } else {
                table_add(*path_to_index, it.path, it_index);
            }
        }
    }

    process_moves_within_project(files_to_refresh);

    for files_to_refresh {
        refresh_buffer_from_disk_by_path(it.path, check_contents = it.check_contents);
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

#scope_file

file_changed_callback :: (watcher: *File_Watcher(void), change: *File_Change, user_data: *void) {
    array_add(*watchers.changes, File_Change.{
        full_path = copy_temporary_string(change.full_path),
        events = change.events,
        time_of_last_change = change.time_of_last_change,
    });
}

process_moves_within_project :: (files_to_refresh: [] File_Refresh) {
    have_new_project_paths := false;
    for files_to_refresh {
        path := it.path;
        if path_is_within_project(path) && find_buffer_id_by_path(path) < 0 {
            have_new_project_paths = true;
            break;
        }
    }
    if !have_new_project_paths return;

    buffers_by_identity: Table(File_Identity, Buffer_Id, given_hash_function = get_file_identity_hash, given_compare_function = same_identity);
    buffers_by_identity.allocator = temp;

    for * buffer : open_buffers {
        if buffer.internal || !buffer.has_file || !buffer.file.full_path continue;
        if buffer.deleted && frame_time64 - buffer.time_when_deleted > 5.0 continue;  // don't check old deleted buffers in case their filesystem identity is reused by the OS
        if !is_valid(buffer.file_identity) continue;
        if !path_is_within_project(buffer.file.full_path) continue;

        existing := table_find_pointer(*buffers_by_identity, buffer.file_identity);
        if existing {
            existing.* = -1;  // ambiguous identity
        } else {
            table_add(*buffers_by_identity, buffer.file_identity, buffer.id);
        }
    }

    move_destinations: Table(Buffer_Id, string);
    move_destinations.allocator = temp;

    for files_to_refresh {
        dest_path := it.path;

        if !path_is_within_project(dest_path) continue;
        if find_buffer_id_by_path(dest_path) >= 0 continue;  // an existing association takes precedence over identity matching

        identity := get_file_identity(dest_path);
        if !is_valid(identity) continue;

        found, buffer_id := table_find(*buffers_by_identity, identity);
        if !found || buffer_id < 0 continue;

        buffer := get_buffer(buffer_id);

        // Do not follow and old object into a backup while its original path exists
        if !path_is_missing(buffer.file.full_path) continue;

        in_project, project_dir := path_is_within_project(buffer.file.full_path);
        if !in_project continue;

        // If a workspace root is renamed, we consider that a delete (because it also lives in the config and that is the source of truth for the workspace)
        root_is_directory, root_success := is_directory(project_dir.path);
        if !root_success || !root_is_directory continue;

        existing_destination := table_find_pointer(*move_destinations, buffer_id);
        if existing_destination {
            if !platform_path_equals(existing_destination.*, dest_path) {
                existing_destination.* = "";  // multiple destinations are ambiguous
            }
            continue;
        }

        table_add(*move_destinations, buffer_id, dest_path);
    }

    if move_destinations.count == 0 return;

    for buffer_id, key : buffers_table {
        destination := table_find_pointer(*move_destinations, buffer_id);
        if !destination || !destination.* continue;

        remove buffer_id;
        free(key);
    }

    moved_any := false;

    for dest_path, buffer_id : move_destinations {
        if !dest_path continue;

        buffer := get_buffer(buffer_id);
        assert(find_buffer_id_by_path(dest_path) < 0);

        new_file := get_file_info_from_full_path(copy_string(dest_path));
        new_lang := get_lang_from_path(dest_path);

        table_add(*buffers_table, copy_string(dest_path), buffer_id);

        lock(*buffer.content_lock);
        lock(*buffer.settings_lock);

        old_path := buffer.file.full_path;

        buffer.file = new_file;
        buffer.lang = new_lang;
        buffer.settings_revision += 1;
        buffer.needs_tokenizing = true;
        buffer.deleted = false;

        free(old_path);

        unlock(*buffer.settings_lock);
        unlock(*buffer.content_lock);

        maybe_detect_and_set_indentation(buffer);
        refresh_all_editors_for_buffer(buffer_id);

        moved_any = true;
    }

    if moved_any {
        finder.need_to_refresh_results = true;
        open_file_dialog.should_refresh_entries = true;

        _, active_buffer := get_active_editor_and_buffer();
        if active_buffer then update_window_title(active_buffer.id);
    }
}

File_Refresh :: struct {
    path: string;
    check_contents: bool;
}

watchers : struct {
    initialized := false;

    project_watcher:  File_Watcher;   // recursive
    external_watcher: File_Watcher;   // non-recursive

    changes: [..] File_Change;
}

watch_dirs:  [..] string;       // dirs we watch which are not project dirs
watch_files: [..] string;       // files outside of projects that we want to watch

