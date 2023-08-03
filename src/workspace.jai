init_workspace :: () {
    for path : config.workspace.workspace_dirs {
        add_directory_to_workspace(path);
    }
}

add_directory_to_workspace :: (path: string, index := -1) {
    full_path, success := get_absolute_path(path);
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

start_initial_workspace_scan :: () {
    file_list_ready = false;
    workspace_scan_complete = false;
    array_reset(*files_to_scan);

    // Get the list of all files in the project asynchronously (depending on the size it can cause a startup delay otherwise)
    file_list_thread_group = Thread_Group.{};  // if we don't do this it can't be reused
    init(*file_list_thread_group, num_threads = 1, group_proc = file_list_threadproc);
    file_list_thread_group.name    = "Async workspace file list builder";
    file_list_thread_group.logging = DEBUG;
    for * file_list_thread_group.worker_info { it.thread.starting_context.logger_data = context.logger_data; }

    start(*file_list_thread_group);
    add_work(*file_list_thread_group, cast(*void) 0);  // a dummy piece of work
}

get_workspace_scan_progress :: () -> float {
    return clamp(cast(float) num_jobs_completed / num_jobs_to_complete, 0.0, 1.0);
}

maybe_update_workspace_buffers :: () {
    if !workspace_scan_complete {
        if !file_list_ready {
            results := get_completed_work(*file_list_thread_group);
            if results {
                file_list_ready = true;
                shutdown(*file_list_thread_group);
                file_list_thread_group = Thread_Group.{};

                // Start the actual scanning of the workspace
                num_jobs_to_complete = 0;

                num_cpus := get_num_cpus();
                num_threads := max(num_cpus - 1, 1);

                scanner_thread_group = Thread_Group.{};  // if we don't do this it can't be reused
                init(*scanner_thread_group, num_threads = num_threads, group_proc = directory_scan_threadproc);
                scanner_thread_group.name    = "Workspace Scanner";
                scanner_thread_group.logging = DEBUG;
                for * scanner_thread_group.worker_info { it.thread.starting_context.logger_data = context.logger_data; }

                start(*scanner_thread_group);

                files_per_thread := min((files_to_scan.count / num_threads) + 1, MAX_FILES_PER_JOB);
                num_ranges  := (files_to_scan.count / files_per_thread) + 1;
                file_ranges := NewArray(num_ranges, [] string, allocator = get_scan_pool_allocator());

                for 0..num_ranges-1 {
                    file_range := *file_ranges[it];
                    start := it * files_per_thread;
                    count := min(files_per_thread, files_to_scan.count - start);
                    if count <= 0 break;
                    << file_range = array_view(files_to_scan, start, count);

                    add_work(*scanner_thread_group, file_range, sprint("Scan [%:%]", start, start + count));

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
    files_changed := process_changes(*file_watcher);
    if files_changed {
        if watcher_file_modified.count > 0 && (!should_ignore_file(watcher_file_modified) || is_our_config_file(watcher_file_modified)) {
            #if DEBUG_FILE_REFRESH log("Attempting to refresh based on watcher_file_modified: %\n", watcher_file_modified);
            refresh_buffer_from_disk(path = watcher_file_modified);
        }

        visitor_func :: (file: *File_Visit_Info, userdata: *void) {
            if file.is_directory {
                if should_ignore_dir(file.full_name) {
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
    watcher_file_modified = "";
}

hard_reload_workspace :: () {
    // Make sure no threads are running
    if file_list_thread_group.initted then shutdown(*file_list_thread_group);
    if scanner_thread_group.initted   then shutdown(*scanner_thread_group);

    deinit_finder();
    deinit_open_file_dialog();
    deinit_file_watcher();

    old_editor_state := remember_visible_editors_and_buffers();

    // Remove all editors and buffers (safe to do now without any threads)
    remove_all_editors();
    remove_all_buffers();

    // Start again
    init_file_watcher();
    array_reset_keeping_memory(*project_dirs);
    init_workspace();
    init_buffers();
    reopen_visible_editors(old_editor_state);
    start_initial_workspace_scan();

    add_success_message("Workspace has been reloaded", dismiss_in_seconds=3);
}

remember_visible_editors_and_buffers :: () -> Visible_Editor_State {
    save_editor_state :: (state: *Visible_Editor_State.State, editor: *Editor, buffer: *Buffer) {
        state.file_path = copy_temporary_string(buffer.file.full_path);
        state.cursors = NewArray(editor.cursors.count, Cursor.State, initialized = false);
        for * cursor, i : state.cursors { <<cursor = editor.cursors[i].state; }
        state.main_cursor = editor.main_cursor;
        state.viewport = editor.viewport;
    }

    using state: Visible_Editor_State;

    layout = editors.layout;

    if editors.layout == {
        case .None;     // nothing to do
        case .Single;
            editor := *open_editors[editors.active];
            buffer := *open_buffers[editor.buffer_id];
            if buffer.has_file && !buffer.modified {
                save_editor_state(*left, editor, buffer);
            } else {
                layout = .None;  // we don't reopen unmodified buffers, at least for now
            }
        case .Double;
            left_editor  := *open_editors[editors.left];
            left_buffer  := *open_buffers[left_editor.buffer_id];

            right_editor := *open_editors[editors.right];
            right_buffer := *open_buffers[right_editor.buffer_id];

            if left_buffer.has_file && !left_buffer.modified && right_buffer.has_file && !right_buffer.modified {
                save_editor_state(*left,  left_editor, left_buffer);
                save_editor_state(*right, right_editor, right_buffer);
            } else if left_buffer.has_file && !left_buffer.modified {
                save_editor_state(*left, left_editor, left_buffer);
                layout = .Single;
            } else if right_buffer.has_file && !right_buffer.modified {
                save_editor_state(*left, right_editor, right_buffer);
                layout = .Single;
            } else {
                layout = .None;
            }

            state.left_active = editors.active == editors.left;
    }

    return state;
}

reopen_visible_editors :: (using old_state: Visible_Editor_State) {
    restore_editor_state :: (state: Visible_Editor_State.State, placement: Editor_Placement) {
        editors_open_file(state.file_path, placement);
        editor := *open_editors[editors.active];
        restore_cursor_state(editor, state.cursors);
        editor.main_cursor = state.main_cursor;
        editor.viewport = state.viewport;
        if !file_is_watched(state.file_path) then start_watching_file(state.file_path);
    }

    editors = Editor_State.{};
    editors.layout = layout;

    if layout == {
        case .None; return;
        case .Single;
            restore_editor_state(left, .in_place);
        case .Double;
            restore_editor_state(left,  .left);
            restore_editor_state(right, .right);
            if left_active then make_editor_active(editors.left);;
    }
    redraw_requested = true;
}

Visible_Editor_State :: struct {
    layout: Editor_State.Layout;
    left_active: bool;
    left: State;
    right: State;

    State :: struct {
        file_path: string;
        cursors: [] Cursor.State;
        main_cursor: s64;
        viewport: Viewport;
    }
}

start_watching_file :: (file_path: string) {
    parent_dir := get_parent_dir_path(file_path);
    if !array_find(watch_dirs, parent_dir) {
        parent_dir = copy_string(parent_dir);
        array_add(*watch_dirs, parent_dir);
        add_directories(*file_watcher, parent_dir);
    }
    full_path, success := get_absolute_path(file_path);
    if !success {
        log_error("Couldn't start watching file % because it's not found", file_path);
        return;
    }
    full_path = copy_string(full_path);
    path_overwrite_separators(full_path, #char "/");
    array_add_if_unique(*watch_files, full_path);
}

stop_watching_file :: (file_path: string) {
    full_path, success := get_absolute_path(file_path);
    if !success then return;
    path_overwrite_separators(full_path, #char "/");

    found, index := array_find(watch_files, full_path);
    if found then array_unordered_remove_by_index(*watch_files, index);
}

file_is_watched :: (file_path: string) -> bool {
    parent_dir := get_parent_dir_path(file_path);
    if dir_is_within_project(parent_dir) return true;  // project dirs are watched
    for watch_files {
        if equal_nocase(it, file_path) return true;
    }
    return false;
}

init_file_watcher :: () {
    assert(!file_watcher_initted);
    file_watcher = File_Watcher.{};
    if !init(*file_watcher, file_change_callback) {
        add_user_error("Could not initialize the workspace file watcher. Files won't be reloaded. This is likely a bug.");
        file_watcher_initted = false;
    } else {
        file_watcher_initted = true;
    }
}

deinit_file_watcher :: () {
    if !file_watcher_initted return;
    deinit(file_watcher);
    array_reset_keeping_memory(*watch_files);
    file_watcher_initted = false;
}

#scope_file

file_list_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    reset(*scan_memory_pool);
    scan_pool_allocator := get_scan_pool_allocator();
    push_allocator(scan_pool_allocator);

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

    for project_dirs visit_files(it.path, recursive = true, null, maybe_add_file_to_scan_list, visit_directories = true);

    return .STOP;  // don't need you no mo
}

directory_scan_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    file_range := cast(*[] string) work;

    for path : << file_range {
        if !should_ignore_file(path) {
            find_or_create_buffer(path);
        }
    }

    return .CONTINUE;
}

start_file_watcher :: () {
    if !file_watcher_initted {
        log_error("Trying to start the file watcher, but it's not initialized. This is a bug.\n");
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
    #if DEBUG_FILE_REFRESH {
        b: String_Builder;
        b.allocator = temp;
        print_to_builder(*b, "%", <<change);
        defer log("File change: %\n", builder_to_string(*b, allocator = temp));
    }

    // If the change is in one of the ignored dirs, ignore it
    if should_ignore_dir(change.full_path) && !is_our_config_file(change.full_path) {
        #if DEBUG_FILE_REFRESH append(*b, " - ignore because of dir");
        return;
    }

    // If the change is caused by watching a dir containing a standalone file, ignore it
    parent_dir := get_parent_dir_path(change.full_path);
    if !dir_is_within_project(parent_dir) && !file_is_watched(change.full_path) {
        #if DEBUG_FILE_REFRESH append(*b, " - ignore because of parent dir");
        return;
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

    #if DEBUG_FILE_REFRESH {
        if watcher_file_modified print_to_builder(*b, " | watcher_file_modified: %", watcher_file_modified);
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

file_watcher: File_Watcher;
file_watcher_initted := false;

dirs_to_rescan: [..] string;    // will use temporary storage
watcher_file_modified: string;  // will contain the path of a file if if was modified and it was the only event in a group,
                                // otherwise it won't be used and a scan will be done instead

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
