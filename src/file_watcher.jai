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

    watchers.thread_group = Thread_Group.{};
    init(*watchers.thread_group, num_threads = 1, group_proc = file_watcher_threadproc);
    start(*watchers.thread_group);

    watchers.initialized = true;
}

deinit_file_watcher :: () {
    if !watchers.initialized return;

    shutdown(*watchers.thread_group);

    while watchers.outstanding_tasks.count {
        task := watchers.outstanding_tasks[watchers.outstanding_tasks.count - 1];
        free_file_watcher_task(task);
    }

    deinit(watchers.project_watcher);
    deinit(watchers.external_watcher);

    for watchers.changes  free(it.full_path);
    array_reset_keeping_memory(*watchers.changes);
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
    using watchers;

    // Process async results
    completed_tasks := get_completed_work(*thread_group);
    for completed_tasks {
        task := cast(*File_Watcher_Task) it;

        apply_moves_within_project(task);

        apply_file_watcher_task_results(task);

        free_file_watcher_task(task);
    }

    // Check for new changes
    process_changes(*project_watcher);
    process_changes(*external_watcher);

    if !changes return;

    for changes  color_preview_invalidate_theme(it.full_path);

    process_file_change_batch(changes);

    for changes  free(it.full_path);
    array_reset_keeping_memory(*changes);
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

file_watcher_ignore_pending_results :: (buffer_id: Buffer_Id) {
    for task : watchers.outstanding_tasks {
        array_add_if_unique(*task.ignored_buffer_ids, buffer_id);
    }
}

#scope_file

file_changed_callback :: (watcher: *File_Watcher(void), change: *File_Change, user_data: *void) {
    array_add(*watchers.changes, File_Change.{
        full_path = copy_string(change.full_path),
        events = change.events,
        time_of_last_change = change.time_of_last_change,
    });
}

process_file_change_batch :: (changes: [] File_Change) {
    task := create_file_watcher_task();

    dirs_to_scan: [..] string;
    dirs_to_scan.allocator = temp;

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

        if change.events & (.REMOVED | .MOVED) then add_affected_path(task, path);

        if !path_is_within_project(path) {
            for watched_path : watch_files {
                if path_is_within_other_path(watched_path, path) {
                    add_file_to_refresh(task, watched_path, force = platform_path_equals(watched_path, path));  // force refresh on direct events
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
            add_file_to_refresh(task, path, force = true);
            continue;
        }

        if success {
            if !should_ignore_file(path) || is_our_config_file(path) {
                add_file_to_refresh(task, path, force = true);
                task.have_new_project_paths = true;
            }
            continue;
        }

        if change.events & (.ADDED | .REMOVED | .MOVED) {
            parent_dir := get_parent_dir_path(path);
            if parent_dir && path_is_within_project(parent_dir) then update_scan_queue(*dirs_to_scan, parent_dir);
        }
    }

    // Scan the scan queue
    visitor_func :: (file: *File_Visit_Info, task: *File_Watcher_Task) {
        path := file.full_name;

        if file.is_directory {
            if !should_descend_into_dir(path) then file.descend_into_directory = false;
            return;
        }
        if file.is_symlink return;

        if find_buffer_id_by_path(path) >= 0 return;  // let the scanner discover only new files
        if should_ignore_file(path) && !is_our_config_file(path) return;

        add_file_to_refresh(task, path, force = true);
        task.have_new_project_paths = true;
    }

    for dirs_to_scan {
        add_affected_path(task, it);  // any directory we need to scan is affected

        log("Scanning dir: %\n", it);
        visit_files(it, recursive = true, task, visitor_func, visit_directories = true);
    }

    array_add(*watchers.outstanding_tasks, task);
    add_work(*watchers.thread_group, task);
}

apply_file_watcher_task_results :: (task: *File_Watcher_Task) {
    for * result : task.results {
        buffer_id := find_buffer_id_by_path(result.path);
        if buffer_id >= 0 {
            if array_find(task.ignored_buffer_ids, buffer_id) continue;

            buffer := get_buffer(buffer_id);
            if result.file_exists {
                if result.loaded_data.has_file {
                    replace_buffer_data(buffer, result.loaded_data);
                } else if buffer.deleted {
                    reload_from_disk(buffer.id);
                } else {
                    continue;
                }
                maybe_defer_refresh_config_or_theme(result.path);
                finder.need_to_refresh_results = true;
                open_file_dialog.should_refresh_entries = true;
            } else {
                if !buffer.deleted {
                    buffer.time_when_deleted = frame_time64;
                    buffer.deleted = true;
                    finder.need_to_refresh_results = true;
                    open_file_dialog.should_refresh_entries = true;
                }
            }
        } else {
            if result.file_exists && result.loaded_data.has_file {
                publish_prepared_buffer(*result.loaded_data);
                maybe_defer_refresh_config_or_theme(result.path);
                finder.need_to_refresh_results = true;
                open_file_dialog.should_refresh_entries = true;
            }
        }
    }
}

apply_moves_within_project :: (task: *File_Watcher_Task) {
    if !task.moves return;

    move_destinations: Table(Buffer_Id, string);
    move_destinations.allocator = temp;

    for move : task.moves {
        if array_find(task.ignored_buffer_ids, move.buffer_id) continue;

        buffer := get_buffer(move.buffer_id);

        if buffer.internal || !buffer.has_file continue;
        if !platform_path_equals(buffer.file.full_path, move.old_path) continue;
        if !same_identity(buffer.file_identity, move.identity) continue;

        if buffer.deleted && frame_time64 - buffer.time_when_deleted > 5.0 continue;

        if find_buffer_id_by_path(move.old_path) != move.buffer_id continue;

        // Existing destination associations take precedence
        if find_buffer_id_by_path(move.new_path) >= 0 continue;

        existing_destination := table_find_pointer(*move_destinations, move.buffer_id);
        if existing_destination {
            if !platform_path_equals(existing_destination.*, move.new_path) then existing_destination.* = "";
            continue;
        }

        table_add(*move_destinations, move.buffer_id, move.new_path);
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
        lock(*buffer.metadata_lock);

        old_path := buffer.file.full_path;

        buffer.file = new_file;
        buffer.lang = new_lang;
        buffer.settings_revision += 1;
        buffer.needs_tokenizing = true;
        buffer.deleted = false;

        free(old_path);

        unlock(*buffer.metadata_lock);
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

file_watcher_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    task := cast(*File_Watcher_Task) work;

    context_set_config_snapshot(task.config_snapshot);
    defer buffer_settings_cache_destroy();

    move_sources: Table(File_Identity, File_Watcher_Move_Source, given_hash_function = get_file_identity_hash, given_compare_function = same_identity);
    move_sources.allocator = temp;

    // We have to check all open buffers because if e.g. a directory is deleted, we won't get a notification
    // for every file within that directory and must check ourselves
    if task.affected_paths || task.have_new_project_paths {
        for buffer : task.buffer_ptrs_snapshot {
            buffer_path: string;
            buffer_mod_info: Buffer.Mod_Info;
            buffer_identity: File_Identity;

            {
                lock(*buffer.metadata_lock);
                defer unlock(*buffer.metadata_lock);

                if buffer.internal || !buffer.has_file || !buffer.file.full_path continue;

                buffer_path = copy_temporary_string(buffer.file.full_path);
                buffer_mod_info = buffer.mod_info;
                buffer_identity = buffer.file_identity;
            }

            if task.have_new_project_paths && is_valid(buffer_identity) && path_is_within_project(buffer_path) {
                existing := table_find_pointer(*move_sources, buffer_identity);
                if existing {
                    existing.buffer_id = -1;
                } else {
                    table_add(*move_sources, buffer_identity, .{ buffer_id = buffer.id, path = buffer_path });
                }
            }

            for affected_path : task.affected_paths {
                if path_is_within_other_path(buffer_path, affected_path) {
                    add_file_to_refresh(task, buffer_path, force = false, mod_info = buffer_mod_info);
                    break;
                }
            }
        }
    }

    // Deduplicate file refreshes
    {
        path_to_index: Table(string, int, given_hash_function = get_platform_path_hash, given_compare_function = platform_path_equals);
        path_to_index.allocator = temp;

        for task.files_to_refresh {
            found, index := table_find(*path_to_index, it.path);
            if found {
                task.files_to_refresh[index].force |= it.force;
                remove it;
            } else {
                table_add(*path_to_index, it.path, it_index);
            }
        }
    }

    for task.files_to_refresh {
        if !it.force && !file_has_changed_on_disk(it.path, it.mod_info) {
            array_add(*task.results, .{ path = it.path, file_exists = true });  // main might reload if the buffer exists but was deleted
            continue;
        }

        if path_is_missing(it.path) {
            array_add(*task.results, .{ path = it.path, file_exists = false });
            continue;
        }

        success, buffer_data := load_buffer_data_from_file(it.path);
        if !success {
            log_error("Couldn't load buffer data when refreshing '%'", it.path);
            continue;
        }

        array_add(*task.results, .{ path = it.path, file_exists = true, loaded_data = buffer_data });

        // Process moves

        if !task.have_new_project_paths continue;
        if !is_valid(buffer_data.file_identity) continue;
        if !path_is_within_project(it.path) continue;

        found, source := table_find(*move_sources, buffer_data.file_identity);
        if !found || source.buffer_id < 0 continue;
        if platform_path_equals(source.path, it.path) continue;

        // Don't follow a file into a backup while its original path exists
        if !path_is_missing(source.path) continue;

        in_project, project_dir := path_is_within_project(source.path);
        if !in_project continue;

        // Renaming a workspace root is treated as a deletion
        root_is_directory, root_success := is_directory(project_dir.path);
        if !root_success || !root_is_directory continue;

        array_add(*task.moves, .{
            buffer_id = source.buffer_id,
            old_path = copy_string(source.path,, task.allocator),
            new_path = it.path,
            identity = buffer_data.file_identity,
        });
    }

    reset_temporary_storage();

    return .CONTINUE;
}

create_file_watcher_task :: () -> *File_Watcher_Task {
    task := New(File_Watcher_Task);

    task.allocator = allocator_of(*task.memory_pool);
    task.affected_paths.allocator   = task.allocator;
    task.files_to_refresh.allocator = task.allocator;
    task.results.allocator          = task.allocator;
    task.moves.allocator            = task.allocator;

    task.ignored_buffer_ids.allocator = focus_allocator;  // must not use the task memory pool because the main thread appends to it

    task.buffer_ptrs_snapshot = get_immutable_buffer_ptrs_snapshot();
    begin_buffer_snapshot_use();

    task.config_snapshot = acquire_current_config_snapshot();

    return task;
}

free_file_watcher_task :: (task: *File_Watcher_Task) {
    found, index := array_find(watchers.outstanding_tasks, task);
    assert(found);
    array_unordered_remove_by_index(*watchers.outstanding_tasks, index);

    end_buffer_snapshot_use();
    release_config_snapshot(task.config_snapshot);

    for * task.results  free_buffer_data(*it.loaded_data);

    array_free(task.ignored_buffer_ids);

    fini(*task.memory_pool);
    free(task);
}

add_affected_path :: inline (task: *File_Watcher_Task, path: string) {
    array_add(*task.affected_paths, copy_string(path,, task.allocator));
}

add_file_to_refresh :: inline (task: *File_Watcher_Task, path: string, force: bool, mod_info: Buffer.Mod_Info = .{}) {
    array_add(*task.files_to_refresh, .{
        path = copy_string(path,, task.allocator),
        force = force,
        mod_info = mod_info,
    });
}


File_Watcher_Task :: struct {
    memory_pool: Flat_Pool;
    allocator: Allocator;

    buffer_ptrs_snapshot: [] *Buffer;
    config_snapshot: *Config_Snapshot;

    have_new_project_paths: bool;
    affected_paths:   [..] string;
    files_to_refresh: [..] File_Refresh;

    ignored_buffer_ids: [..] Buffer_Id;  // to handle a data race when a file is saved while the file watcher is working

    results: [..] File_Watcher_Task_Result;
    moves:   [..] File_Watcher_Move;
}

File_Refresh :: struct {
    force: bool;
    path: string;
    mod_info: Buffer.Mod_Info;
}

File_Watcher_Task_Result :: struct {
    path: string;
    file_exists: bool;
    loaded_data: Buffer_Data;
}

File_Watcher_Move :: struct {
    buffer_id: Buffer_Id;
    old_path: string;
    new_path: string;
    identity: File_Identity;
}

File_Watcher_Move_Source :: struct {
    buffer_id: Buffer_Id;
    path: string;
}

watchers : struct {
    initialized := false;

    thread_group: Thread_Group;
    outstanding_tasks: [..] *File_Watcher_Task;

    project_watcher:  File_Watcher;   // recursive
    external_watcher: File_Watcher;   // non-recursive

    changes: [..] File_Change;
}

watch_dirs:  [..] string;       // dirs we watch which are not project dirs
watch_files: [..] string;       // files outside of projects that we want to watch

