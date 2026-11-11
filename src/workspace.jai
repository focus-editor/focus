init_workspace :: () {
    for path : context.config.workspace.members {
        if file_exists(path) && !is_directory(path) {
            add_file_to_workspace(path);
        } else {
            add_directory_to_workspace(path);
        }
    }

    // Build a list of unique project dirs for watching and scanning
    // For example, if project dirs are C:/dir and C:/dir/child, we will only keep the parent C:/dir
    {
        project_dirs_with_slashes: [..] string;
        project_dirs_with_slashes.allocator = temp;
        for project_dirs {
            dir := it.path;
            if !ends_with(dir, #char "/") then dir = tprint("%/", dir);
            array_add(*project_dirs_with_slashes, dir);
        }

        for dir : project_dirs {
            is_unique := true;
            for prefix : project_dirs_with_slashes {
                if dir.path.count > prefix.count && platform_path_begins_with(dir.path, prefix) {
                    is_unique = false;
                    break;
                }
            }
            if is_unique then array_add(*unique_project_dirs, dir.path);
        }
    }

    // Change working directory to the first directory in the list
    working_dir := get_working_directory_from_workspace(context.config.workspace.members);
    if working_dir {
        set_working_directory(working_dir);
    } else {
        set_working_directory(data_dir);
    }
}

get_working_directory_from_workspace :: (members: [] string) -> string {
    if members {
        first_member := members[0];
        if is_directory(first_member) return first_member;
        if file_exists(first_member)  return path_strip_filename(first_member);
    }
    return "";
}

add_file_to_workspace :: (path: string) {
    full_path, success := get_absolute_path(path,, temp);

    if !success || !file_exists(full_path) {
        error_msg := tprint("Couldn't add % to workspace. File doesn't exist or is invalid.", path);
        add_user_error(error_msg, dismiss_in_seconds = 10);
        log_error(error_msg);
        return;
    }

    path_overwrite_separators(full_path, #char "/");

    already_exists := false;
    for project_files {
        if platform_path_equals(full_path, it) {
            already_exists = true;
            break;
        }
    }
    if !already_exists then array_add(*project_files, copy_string(full_path));
}

add_directory_to_workspace :: (path: string, index := -1) {
    full_path, success := get_absolute_path(path,, temp);
    full_path = copy_string(full_path);
    path_overwrite_separators(full_path, #char "/");

    if !is_directory(full_path) || !success {
        error_msg := tprint("Couldn't add % to workspace. Directory doesn't exist or is invalid.", path);
        add_user_error(error_msg, dismiss_in_seconds = 10);
        log_error(error_msg);
        return;
    }

    dir: Project_Dir;
    dir.path = trim_right(full_path, "/");
    dir.path_prefix_len = find_index_from_right(dir.path, #char "/") + 1;
    dir.name = advance(dir.path, dir.path_prefix_len);

    // Disambiguate project names
    // E.g. C:/projects/project1/src/code and C:/projects/project2/src/code should
    // get the names project1/src/code and project2/src/code, not 'code' or 'src/code'
    for i : 0..10 {   // paranoid about infinite looping
        is_ambiguous := false;
        for * project_dirs {
            if it.name == dir.name {
                is_ambiguous = true;
                it.path_prefix_len = find_index_from_right(trim_right(slice(it.path, 0, it.path_prefix_len), "/"), #char "/") + 1;
                it.name = advance(it.path, it.path_prefix_len);
            }
        }
        if !is_ambiguous break;
        dir.path_prefix_len = find_index_from_right(trim_right(slice(dir.path, 0, dir.path_prefix_len), "/"), #char "/") + 1;
        dir.name = advance(dir.path, dir.path_prefix_len);
    }

    if index < 0 {
        array_add(*project_dirs, dir);
    } else {
        array_insert_at(*project_dirs, dir, index);
    }
}

start_workspace_scan :: () {
    file_list_ready = false;
    workspace_scan_complete = false;

    // Get the list of all files in the project asynchronously (depending on the size it can cause a startup delay otherwise)
    file_list_thread_group = Thread_Group.{};  // if we don't do this it can't be reused
    init(*file_list_thread_group, num_threads = 1, group_proc = file_list_threadproc);
    file_list_thread_group.name    = "Async workspace file list builder";
    file_list_thread_group.logging = false;
    for * file_list_thread_group.worker_info { it.thread.starting_context.logger_data = context.logger_data; }

    // Use one config snapshot for the duration of the scan
    assert(scan_config_snapshot == null);
    scan_config_snapshot = acquire_current_config_snapshot();

    start(*file_list_thread_group);
    add_work(*file_list_thread_group, cast(*void) 0);  // a dummy piece of work
}

complete_workspace_scan :: () {
    // Make sure we don't leak any scan job data if it's aborted prematurely
    for job : scan_jobs {
        for * buffer_data : job.results {
            free_buffer_data(buffer_data);
        }
    }
    scan_jobs = .[];

    workspace_scan_complete = true;
    reset(*scan_memory_pool);
    release_config_snapshot(scan_config_snapshot);
    scan_config_snapshot = null;
}

get_workspace_scan_progress :: () -> float {
    return clamp(cast(float) num_jobs_completed / num_jobs_to_complete, 0.0, 1.0);
}

workspace_update :: () {
    if !workspace_scan_complete {
        if !file_list_ready {
            results := get_completed_work(*file_list_thread_group);
            if results {
                file_list_ready = true;
                shutdown(*file_list_thread_group);
                file_list_thread_group = Thread_Group.{};

                // Start the actual scanning of the workspace
                num_jobs_to_complete = 0;
                num_jobs_completed   = 0;

                num_cpus := get_num_cpus();
                num_threads := max(num_cpus - 1, 1);

                scanner_thread_group = Thread_Group.{};  // if we don't do this it can't be reused
                init(*scanner_thread_group, num_threads = num_threads, group_proc = directory_scan_threadproc);
                scanner_thread_group.name    = "Workspace Scanner";
                scanner_thread_group.logging = false;
                for * scanner_thread_group.worker_info { it.thread.starting_context.logger_data = context.logger_data; }

                start(*scanner_thread_group);

                files_per_thread := min((files_to_scan.count / num_threads) + 1, MAX_FILES_PER_JOB);
                num_ranges  := (files_to_scan.count / files_per_thread) + 1;

                scan_jobs = NewArray(num_ranges, Workspace_Scan_Job,, allocator_of(*scan_memory_pool));  // to avoid individual allocations

                for 0..num_ranges-1 {
                    start := it * files_per_thread;
                    count := min(files_per_thread, files_to_scan.count - start);
                    if count <= 0 break;

                    job := *scan_jobs[it];
                    job.paths = array_view(files_to_scan, start, count);
                    array_reserve(*job.results, count,, allocator_of(*scan_memory_pool));  // NOTE: we do this so that threads don't have to grow the arrays concurrently, which is not safe

                    logging_name := sprint("Scan [%:%]", start, start + count,, allocator_of(*scan_memory_pool));
                    add_work(*scanner_thread_group, job, logging_name);

                    num_jobs_to_complete += 1;
                }
            }
            redraw_requested = true;  // make sure we start scanning as soon as possible

            return;
        }

        results := get_completed_work(*scanner_thread_group);

        for results {
            job := cast(*Workspace_Scan_Job) it;

            for * buffer_data : job.results {
                if find_buffer_id_by_path(buffer_data.file.full_path) >= 0 {
                    free_buffer_data(buffer_data);
                } else {
                    publish_prepared_buffer(buffer_data);
                }
            }
        }

        num_jobs_completed += results.count;
        if num_jobs_completed >= num_jobs_to_complete {
            shutdown(*scanner_thread_group);
            scanner_thread_group = Thread_Group.{};

            complete_workspace_scan();

            start_file_watcher();

            init_open_file_dialog();
            init_finder();
        }
        return;
    }

    file_watcher_process_changes();
}

abort_workspace_scanning_and_shut_down_threads :: () {
    if file_list_thread_group.initted {
        shutdown(*file_list_thread_group);
        file_list_thread_group = Thread_Group.{};
    }
    if scanner_thread_group.initted {
        shutdown(*scanner_thread_group);
        scanner_thread_group = Thread_Group.{};
    }

    complete_workspace_scan();
}

reload_workspace :: (automatic := false) {
    should_reload_workspace = false;

    abort_workspace_scanning_and_shut_down_threads();

    // Deinit things
    deinit_finder();
    hide_build_panel();
    deinit_build_system();
    deinit_color_preview();
    deinit_open_file_dialog();
    deinit_file_watcher();
    deinit_cursor_history();
    forget_ignore_table();

    // Reinit things
    init_file_watcher();
    array_reset_keeping_memory(*project_dirs);
    array_reset_keeping_memory(*unique_project_dirs);
    for project_files  free(it);
    array_reset_keeping_memory(*project_files);
    init_workspace();

    // Preserve open buffers and editors if they belong to the new workspace
    buffers_to_remove: [..] Buffer_Id;
    buffers_to_remove.allocator = temp;

    for * buffer : open_buffers {
        if should_keep_buffer_when_reloading_workspace(buffer, automatic) continue;
        array_add(*buffers_to_remove, buffer.id);
    }

    editors_to_remove: [..] Editor_Id;
    editors_to_remove.allocator = temp;

    for * editor : open_editors {
        if !array_find(buffers_to_remove, editor.buffer_id) continue;
        array_add(*editors_to_remove, editor.id);
    }

    for editor_id : editors_to_remove {
        pane := get_pane_by_editor_id(editor_id);
        if pane {
            remove_editor_from_pane(pane, editor_id);
            if !pane.editor_ids then close_pane(pane);
        }
        remove_editor(editor_id);
    }

    for buffer_id : buffers_to_remove {
        array_ordered_remove_by_value(*most_recent_buffers, buffer_id);
        remove_buffer(buffer_id);
    }

    buffer_settings_cache_clear();
    global_config_buffer_id = -1;
    global_troubleshooting_buffer_id = -1;
    array_reset(*editor_paste_animations);

    for buffer_edit_notifications {
        if array_find(buffers_to_remove, it.buffer_id) remove it;
    }

    // Refresh remaining file-backed buffer data
    for * buffer : open_buffers {
        if !buffer.has_file || !buffer.file.full_path continue;

        buffer.file = get_file_info_from_full_path(buffer.file.full_path);
        buffer.settings_revision += 1;
    }

    // Update window title
    activate_editors();
    editor, buffer := get_visible_editor_and_buffer();
    editors.last_active_editor_id = ifx editor then editor.id else -1;
    update_window_title(ifx buffer then buffer.id else -1);

    if !automatic then show_open_file_dialog(.search);

    init_build_system();  // must do after we've cleared editors and buffers

    start_workspace_scan();

    clear_user_messages(.workspace);
    add_success_message("Workspace has been reloaded", dismiss_in_seconds = 3);
}

should_keep_buffer_when_reloading_workspace :: (using buffer: Buffer, automatic: bool) -> bool {
    if internal return false;  // we will recreate any internal buffers

    if automatic && num_times_opened > 0 return true;  // on automatic workspace reloads we keep all buffers which the user opened manually
    if !has_file || !file.full_path return false;

    if should_ignore_file(file.full_path) return false;

    for project_files  if platform_path_equals(file.full_path, it) return true;

    return dir_is_within_project(get_parent_dir_path(file.full_path));
}


#scope_file

file_list_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    context_set_config_snapshot(scan_config_snapshot);
    defer buffer_settings_cache_destroy();

    reset(*scan_memory_pool);
    scan_pool_allocator := allocator_of(*scan_memory_pool);
    table_reset(*file_list_table);

    array_reset(*files_to_scan);
    for project_files {
        full_path := copy_string(it,, allocator=scan_pool_allocator);
        array_add(*files_to_scan, full_path);
        table_add(*file_list_table, full_path, true);
    }

    maybe_add_file_to_scan_list :: (file: *File_Visit_Info, userdata: Allocator) {
        if file.is_directory {
            if !should_descend_into_dir(file.full_name) then file.descend_into_directory = false;
            return;
        }
        if file.is_symlink return;
        if should_ignore_file(file.full_name, check_for_zeroes_if_needed = false) return;

        full_path := copy_string(file.full_name,, allocator=userdata);
        if table_find_pointer(*file_list_table, full_path) return;
        array_add(*files_to_scan, full_path);
        table_add(*file_list_table, full_path, true);
    }

    for unique_project_dirs visit_files(it, recursive = true, scan_pool_allocator, maybe_add_file_to_scan_list, visit_directories = true);

    return .STOP;  // don't need you no mo
}

directory_scan_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    context_set_config_snapshot(scan_config_snapshot);
    defer buffer_settings_cache_destroy();

    job := cast(*Workspace_Scan_Job) work;

    for path : job.paths {
        auto_release_temp();
        if should_ignore_file(path) continue;

        success, buffer_data := load_buffer_data_from_file(path);
        if success  array_add(*job.results, buffer_data);
    }

    return .CONTINUE;
}

Workspace_Scan_Job :: struct {
    paths: [] string;
    results: [..] Buffer_Data;
}

file_list_thread_group:     Thread_Group;
scanner_thread_group:       Thread_Group;

scan_config_snapshot: *Config_Snapshot;

scan_jobs: [] Workspace_Scan_Job;

scan_memory_pool: Flat_Pool;
files_to_scan: [..] string;
file_list_table: Table(string, bool);  // to avoid duplicates

file_list_ready       := false;
num_jobs_to_complete  := 0;
num_jobs_completed    := 0;

MAX_FILES_PER_JOB :: 50;   // we don't want to give huge jobs to threads because then it's more likely
                           // that some threads will finish faster than others and will sit around twiddling
                           // their thumbs while they could be doing work if the work pieces were smaller


#scope_export

// TODO: get rid of this flag if possible, or make it private
workspace_scan_complete := true;
