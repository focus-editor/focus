init_workspace :: () {
    for path : config.workspace.members {
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
    working_dir := get_working_directory_from_workspace(config.workspace.members);
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

    start(*file_list_thread_group);
    add_work(*file_list_thread_group, cast(*void) 0);  // a dummy piece of work
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
                file_ranges := NewArray(num_ranges, [] string,, allocator = get_scan_pool_allocator());

                for 0..num_ranges-1 {
                    file_range := *file_ranges[it];
                    start := it * files_per_thread;
                    count := min(files_per_thread, files_to_scan.count - start);
                    if count <= 0 break;
                    file_range.* = array_view(files_to_scan, start, count);

                    logging_name := sprint("Scan [%:%]", start, start + count);
                    this_allocation_is_not_a_leak(logging_name.data);  // this is actually a leak, but Thread_Group won't free it and we can't seem to be able to either
                    add_work(*scanner_thread_group, file_range, logging_name);

                    num_jobs_to_complete += 1;
                }
            }
            redraw_requested = true;  // make sure we start scanning as soon as possible

            return;
        }

        results := get_completed_work(*scanner_thread_group);

        num_jobs_completed += results.count;
        if num_jobs_completed >= num_jobs_to_complete {
            workspace_scan_complete = true;
            shutdown(*scanner_thread_group);
            scanner_thread_group = Thread_Group.{};

            reset(*scan_memory_pool);

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

    workspace_scan_complete = true;
}

reload_workspace :: (automatic := false) {
    // Make sure no threads are running
    if file_list_thread_group.initted then shutdown(*file_list_thread_group);
    if scanner_thread_group.initted   then shutdown(*scanner_thread_group);

    // Deinit things
    deinit_finder();
    hide_build_panel();
    deinit_build_system();
    deinit_color_preview();
    deinit_open_file_dialog();
    deinit_file_watcher();
    deinit_cursor_history();
    deinit_buffers();
    deinit_editors();

    // Reinit things
    init_file_watcher();
    array_reset_keeping_memory(*project_dirs);
    array_reset_keeping_memory(*unique_project_dirs);
    for project_files  free(it);
    array_reset_keeping_memory(*project_files);
    init_workspace();
    init_editors();
    init_buffers();

    // !!!!!!!! Get rid of this and instead preserve project editors
    // Preserve all editors and buffers which belong to the new workspace. Remove the rest.
    new_open_editors: [..] Editor;
    new_open_buffers: Simple_Bucket_Array(Buffer, items_per_bucket = 1024, max_buckets = 1024);
    new_most_recent_buffers: [..] s64;

    editor_id_map: Table(s64, s64);
    editor_id_map.allocator = temp;

    buffers_to_refresh_from_disk: [..] s64;
    buffers_to_refresh_from_disk.allocator = temp;

    for * buffer, old_buffer_id : open_buffers {
        buffer := *open_buffers[old_buffer_id];
        if should_keep_buffer_when_reloading_workspace(buffer) {
            new_buffer_id := new_open_buffers.count;

            if buffer.has_file {
                table_add(*buffers_table, copy_string(buffer.file.full_path), new_buffer_id);
                start_watching_file_if_not_already(buffer.file.full_path);
                buffer.file = get_file_info_from_full_path(buffer.file.full_path);  // refresh file info to reflect new project dirs
                array_add(*buffers_to_refresh_from_disk, new_buffer_id);
            }
            recalculate_settings(buffer);

            bucket_array_add(*new_open_buffers, buffer.*);

            if array_unordered_remove_by_value(*most_recent_buffers, old_buffer_id, stop_after_first = true) {
                array_add(*new_most_recent_buffers, new_buffer_id);
            }

            // @speed: O(n*m) here. Hopefully OK because people don't create as many editors as there are buffers
            for editor, old_editor_id : open_editors {
                if editor.buffer_id != old_buffer_id continue;

                new_editor := editor;
                new_editor.buffer_id = new_buffer_id;
                new_editor_id := new_open_editors.count;
                array_add(*new_open_editors, new_editor);

                table_add(*editor_id_map, old_editor_id, new_editor_id);
            }

        } else {
            free_buffer(buffer);
        }
    }

    array_reset(*open_editors);
    open_editors = new_open_editors;

    array_reset(*most_recent_buffers);
    most_recent_buffers = new_most_recent_buffers;

    bucket_array_reset(*open_buffers);
    open_buffers = new_open_buffers;

    // !!!!!!!!!!!!!!!!!!
    // // Reopen visible editors, if any of them are preserved
    // if editors.layout != .None {
    //     new_active, active_preserved := table_find(*editor_id_map, editors.active);
    //     new_left,   left_preserved   := table_find(*editor_id_map, editors.left);
    //     new_right,  right_preserved  := table_find(*editor_id_map, editors.right);

    //     if active_preserved then editors.active = new_active;

    //     if left_preserved && right_preserved {
    //         // Keep the layout
    //         editors.left  = new_left;
    //         editors.right = new_right;
    //     } else if left_preserved {
    //         editors.layout = .Single;
    //         editors.left   = new_left;
    //         editors.right  = new_left;
    //         editors.active = new_left;
    //     } else if right_preserved {
    //         editors.layout = .Single;
    //         editors.left   = new_right;
    //         editors.right  = new_right;
    //         editors.active = new_right;
    //     } else {
    //         editors = Editor_State.{};  // reset everything
    //     }
    //     if editors.left == editors.right && editors.layout == .Double {
    //         editors.active = editors.left;
    //         editors.layout = .Single;
    //     }
    // }

    if !automatic then show_open_file_dialog(.search);

    init_build_system();  // must do after we've cleared editors and buffers

    if editors_get_layout() == .None {
        update_window_title();
    } else {
        // TODO: when we're able to preserve layouts, make sure to run this to update the window title etc
        // make_editor_active(editors.active);
    }

    start_workspace_scan();

    clear_user_messages(.workspace);
    add_success_message("Workspace has been reloaded", dismiss_in_seconds = 3);
}

should_keep_buffer_when_reloading_workspace :: (using buffer: Buffer) -> bool {
    // If this is a special buffer we can recreate it later.
    // If the buffer is unsaved, we're throwing it away (because the user decided not to save it)
    if !has_file || deleted return false;

    if is_our_config_file(file.full_path) return true;
    if should_ignore_file(file.full_path) return false;

    for project_files  if platform_path_equals(file.full_path, it) return true;

    return dir_is_within_project(get_parent_dir_path(file.full_path));
}


#scope_file

file_list_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    reset(*scan_memory_pool);
    scan_pool_allocator := get_scan_pool_allocator();
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
    file_range := cast(*[] string) work;

    for path : file_range.* {
        auto_release_temp();
        if !should_ignore_file(path) {
            buffer_id, created := find_or_create_buffer(path);
            if buffer_id < 0 {
                log_error("Couldn't open file because path is too long for %: \"%\"\n", OS, path);
                continue;
            }
            if !created then reload_from_disk(buffer_id, force = true);  // when refreshing workspace we want up to date data from disk
        }
    }

    return .CONTINUE;
}


#scope_file

get_scan_pool_allocator :: () -> Allocator {
    a: Allocator;
    a.proc = flat_pool_allocator_proc;
    a.data = *scan_memory_pool;
    return a;
}

file_list_thread_group:     Thread_Group;
scanner_thread_group:       Thread_Group;

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

// Other modules might want to know whether the scan is complete
workspace_scan_complete := true;
