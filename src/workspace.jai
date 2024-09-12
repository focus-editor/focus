init_workspace :: () {
    for path : config.workspace.members {
        if file_exists(path) && !is_directory(path) {
            add_file_to_workspace(path);
        } else {
            add_directory_to_workspace(path);
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

    in_project, project_dir := dir_is_within_project(dir.path);
    if in_project {
        error_msg := tprint("Directory % is already in the project. Found existing directory %", dir.path, project_dir.path);
        log_error(error_msg);
        add_user_warning(error_msg, dismiss_in_seconds = 10);
        return;
    }

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
    array_reset(*files_to_scan);
    for project_files  array_add(*files_to_scan, copy_string(it));

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
                    << file_range = array_view(files_to_scan, start, count);

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

    // Check for any changes to the files we care about
    files_changed := process_changes(*watchers.project_watcher);
    files_changed |= process_changes(*watchers.external_watcher);
    if files_changed {
        // NOTE: these count comparisons are intentional because count can be -1
        if watchers.project_file_modified.count > 0 && (!should_ignore_file(watchers.project_file_modified) || is_our_config_file(watchers.project_file_modified)) {
            #if DEBUG_FILE_REFRESH log("Attempting to refresh based on project_file_modified: %\n", watchers.project_file_modified);
            refresh_buffer_from_disk(path = watchers.project_file_modified);
        }
        if watchers.external_file_modified.count > 0 && (!should_ignore_file(watchers.external_file_modified) || is_our_config_file(watchers.external_file_modified)) {
            #if DEBUG_FILE_REFRESH log("Attempting to refresh based on external_file_modified: %\n", watchers.external_file_modified);
            refresh_buffer_from_disk(path = watchers.external_file_modified);
        }

        visitor_func :: (file: *File_Visit_Info, userdata: *void) {
            if file.is_directory {
                if !should_descend_into_dir(file.full_name) {
                    file.descend_into_directory = false;
                    #if DEBUG_FILE_REFRESH log("% - not descending into the directory", file.full_name);
                    return;
                }
                #if DEBUG_FILE_REFRESH log("% - directory. Descending into it...", file.full_name);
                return;
            }
            if file.is_symlink {
                #if DEBUG_FILE_REFRESH log("% - symlink. Ignoring...", file.full_name);
                return;
            }

            if should_ignore_file(file.full_name) && !is_our_config_file(file.full_name) {
                #if DEBUG_FILE_REFRESH log("% - ignoring", file.full_name);
                return;
            }

            #if DEBUG_FILE_REFRESH log("% - attempting to refresh", file.full_name);
            refresh_buffer_from_disk(path = file.full_name);
        }

        // @Speed: it should be ok to rescan everything recursively, because
        // most of the files will already be loaded and they won't refresh if unchanged
        #if DEBUG_FILE_REFRESH {
            if dirs_to_rescan log("Scanning dirs_to_rescan: % ===========================", dirs_to_rescan);
        }

        for dirs_to_rescan visit_files(it, recursive = true, null, visitor_func, visit_directories = true);

        #if DEBUG_FILE_REFRESH {
            if dirs_to_rescan log("Finished scanning =====================================");
        }
    }

    array_reset(*dirs_to_rescan);
    watchers.project_file_modified = "";
    watchers.external_file_modified = "";
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
    deinit_buffers();
    editor_history.initted = false;

    // Reinit things
    init_file_watcher();
    array_reset_keeping_memory(*project_dirs);
    for project_files  free(it);
    array_reset_keeping_memory(*project_files);
    init_workspace();
    init_buffers();

    // Preserve all editors and buffers which belong to the new workspace. Remove the rest.
    new_open_editors: [..] Editor;
    new_open_buffers: Simple_Bucket_Array(Buffer, items_per_bucket = 1024, max_buckets = 1024);
    new_most_recent_buffers: [..] s64;

    editor_id_map: Table(s64, s64);
    editor_id_map.allocator = temp;

    for * buffer, old_buffer_id : open_buffers {
        buffer := *open_buffers[old_buffer_id];
        if should_keep_buffer_when_reloading_workspace(buffer) {
            new_buffer_id := new_open_buffers.count;

            if buffer.has_file {
                table_add(*buffers_table, copy_string(buffer.file.full_path), new_buffer_id);
                start_watching_file_if_not_already(buffer.file.full_path);
                buffer.file = get_file_info_from_full_path(buffer.file.full_path);  // refresh file info to reflect new project dirs
            }

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

    // Reopen visible editors, if any of them are preserved
    if editors.layout != .None {
        new_active, active_preserved := table_find(*editor_id_map, editors.active);
        new_left,   left_preserved   := table_find(*editor_id_map, editors.left);
        new_right,  right_preserved  := table_find(*editor_id_map, editors.right);

        if active_preserved then editors.active = new_active;

        if left_preserved && right_preserved {
            // Keep the layout
            editors.left  = new_left;
            editors.right = new_right;
        } else if left_preserved {
            editors.layout = .Single;
            editors.left   = new_left;
            editors.right  = new_left;
            editors.active = new_left;
        } else if right_preserved {
            editors.layout = .Single;
            editors.left   = new_right;
            editors.right  = new_right;
            editors.active = new_right;
        } else {
            editors = Editor_State.{};  // reset everything
        }
        if editors.left == editors.right && editors.layout == .Double {
            editors.active = editors.left;
            editors.layout = .Single;
        }
    }

    if !automatic then show_open_file_dialog(.search);

    init_build_system();  // must do after we've cleared editors and buffers

    if editors.layout == .None {
        update_window_title();
    } else {
        make_editor_active(editors.active);
    }

    start_workspace_scan();

    clear_user_messages(.workspace);
    add_success_message("Workspace has been reloaded", dismiss_in_seconds = 3);
}

should_keep_buffer_when_reloading_workspace :: (using buffer: Buffer) -> bool {
    if !has_file return false;  // if this is a special buffer we can recreate it later. If the buffer is unsaved, we're throwing it away (because the user decided not to save it)

    if is_our_config_file(file.full_path) return true;
    if should_ignore_file(file.full_path) return false;

    for project_files  if platform_path_equals(file.full_path, it) return true;

    return dir_is_within_project(get_parent_dir_path(file.full_path));
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

init_file_watcher :: () {
    if watchers.initialized return;

    watchers.project_watcher = File_Watcher.{};
    if !init(*watchers.project_watcher, file_change_callback, watch_recursively = true) {
        add_user_error("Could not initialize the workspace file watcher. Files won't be reloaded. This is likely a bug.");
        watchers.initialized = false;
        return;
    }

    watchers.external_watcher = File_Watcher.{};
    if !init(*watchers.external_watcher, file_change_callback, watch_recursively = false) {
        add_user_error("Could not initialize the workspace file watcher. Files won't be reloaded. This is likely a bug.");
        watchers.initialized = false;
        deinit(*watchers.project_watcher);
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

#scope_file

file_list_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    reset(*scan_memory_pool);
    scan_pool_allocator := get_scan_pool_allocator();

    maybe_add_file_to_scan_list :: (file: *File_Visit_Info, userdata: Allocator) {
        if file.is_directory {
            if !should_descend_into_dir(file.full_name) then file.descend_into_directory = false;
            return;
        }
        if file.is_symlink return;

        // NOTE: not checking whether we should ignore the file here,
        // because it may involve reading the file and checking for zeroes,
        // and we'd rather it's done in threads (also if later we find there are no
        // zeroes in the file then the file data will be in cache ready to use)
        array_add(*files_to_scan, copy_string(file.full_name,, allocator=userdata));
    }

    for project_dirs visit_files(it.path, recursive = true, scan_pool_allocator, maybe_add_file_to_scan_list, visit_directories = true);

    return .STOP;  // don't need you no mo
}

directory_scan_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    file_range := cast(*[] string) work;

    for path : << file_range {
        if !should_ignore_file(path) then find_or_create_buffer(path);
    }

    return .CONTINUE;
}

start_file_watcher :: () {
    if !watchers.initialized {
        log_error("Trying to start the file watcher, but it's not initialized. This is a bug.\n");
        return;
    }

    for project_dirs {
        added := add_directories(*watchers.project_watcher, it.path);
        if !added log_error("Couldn't start watching directory '%'", it.path);
    }
    dirs_to_rescan.allocator = temp;

    // Add directories that contain standalone files which we want to watch
    for watch_dirs {
        if dir_is_within_project(it) {
            remove it;
            continue;
        }
        added := add_directories(*watchers.external_watcher, it);
        if !added log_error("Couldn't start watching directory '%'", it);
    }
}

file_change_callback :: (watcher: *File_Watcher(void), change: *File_Change, user_data: *void) {
    #if DEBUG_FILE_REFRESH {
        b: String_Builder;
        b.allocator = temp;
        print_to_builder(*b, "%", <<change);
        change_kind := "Project file";
        if watcher == *watchers.external_watcher change_kind = "External file";
        defer log("% change: %\n", change_kind, builder_to_string(*b,, allocator = temp));
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

    // If the change is in one of the ignored dirs, ignore it
    if should_ignore_path(change.full_path) && !is_our_config_file(change.full_path) {
        #if DEBUG_FILE_REFRESH append(*b, " - ignore because of dir");
        return;
    }

    if watcher == *watchers.external_watcher {
        // If the change is caused by watching a dir containing a standalone file, ignore it
        if !is_directory(change.full_path) {
            parent_dir := get_parent_dir_path(change.full_path);
            if !dir_is_within_project(parent_dir) && !file_is_watched(change.full_path) {
                #if DEBUG_FILE_REFRESH append(*b, " - ignore because of parent dir");
                return;
            }
        }

        watchers.external_file_modified = copy_temporary_string(change.full_path);
    } else {
        assert(watcher == *watchers.project_watcher);

        // Most commonly we will receive only a single MODIFIED event for a single file (after saving a buffer)
        // In this case we don't want to rescan anything, but only if no other events were received in the same frame
        if change.events == .MODIFIED && !watchers.project_file_modified {
            watchers.project_file_modified = copy_temporary_string(change.full_path);
        } else {
            // There are other events - maybe rollback and add dir to the rescan queue
            if watchers.project_file_modified.count > 0 {  // NOTE: this count comparison is intentional because count can be -1
                dir := get_parent_dir_path(watchers.project_file_modified);
                maybe_add_to_queue(dir);
                watchers.project_file_modified.count = -1;  // to indicate that we have seen and rejected a MODIFIED event this frame already
            }

            dir: string = ---;
            if change.events & .SCAN_CHILDREN {
                dir = copy_temporary_string(change.full_path);
            } else {
                dir = get_parent_dir_path(change.full_path);
            }
            if dir_is_within_project(dir) then maybe_add_to_queue(dir);
        }
    }

    #if DEBUG_FILE_REFRESH {
        if watchers.project_file_modified  print_to_builder(*b, " | watchers.project_file_modified: %",  watchers.project_file_modified);
        if watchers.external_file_modified print_to_builder(*b, " | watchers.external_file_modified: %", watchers.external_file_modified);
        if dirs_to_rescan append(*b, " | dirs_to_rescan: ");
        else append(*b, " | dirs_to_rescan: none");
        for dirs_to_rescan print_to_builder(*b, "% | ", it);
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

watchers : struct {
    initialized := false;

    project_watcher:   File_Watcher;  // recursive
    external_watcher: File_Watcher;   // non-recursive

    project_file_modified: string;  // will contain the path of a file if if was modified and it was the only event in a group,
                                    // otherwise it won't be used and a scan will be done instead

    external_file_modified: string;
}

dirs_to_rescan: [..] string;    // will use temporary storage

watch_dirs:  [..] string;       // dirs we watch which are not project dirs
watch_files: [..] string;       // files outside of projects that we want to watch

file_list_thread_group: Thread_Group;
scanner_thread_group: Thread_Group;

scan_memory_pool: Flat_Pool;
files_to_scan: [..] string;

file_list_ready       := false;
num_jobs_to_complete  := 0;
num_jobs_completed    := 0;

MAX_FILES_PER_JOB :: 500;  // we don't want to give huge jobs to threads because then it's more likely
                           // that some threads will finish faster than others and will sit around twiddling
                           // their thumbs while they could be doing work if the work pieces were smaller


#scope_export

// Other modules might want to know whether the scan is complete
workspace_scan_complete := false;
