init_finder :: () {
    num_cpus := get_num_cpus();
    num_threads := max(num_cpus - 1, 1);

    thread_group = Thread_Group.{};
    init(*thread_group, num_threads, group_proc = search_threadproc);
    thread_group.name = "Finder";
    thread_group.logging = false;
    for * thread_group.worker_info { it.thread.starting_context.logger_data = context.logger_data; }

    start(*thread_group);

    finder.initted = true;
}

deinit_finder :: () {
    if finder.initted shutdown(*thread_group);
    finder.initted = false;
}

finder_handle_event :: (event: Input.Event) -> handled: bool {
    using finder;

    if event.type == .KEYBOARD && event.key_pressed {
        handled := text_input_handle_event(*input, event);
        if handled { start_new_search(); return true; }

        action, mapping := map_event_to_action(event, Action_Search_Dialog);
        if action == {
            case .toggle_expand;            toggle_expand();                                        return true;
            case .toggle_case_sensitive;    finder_toggle_case_sensitive();                         return true;
            case .toggle_whole_word;        finder_toggle_whole_word();                             return true;

            case .move_up;                  move_cursor(-1, wrap = true);                           return true;
            case .move_down;                move_cursor( 1, wrap = true);                           return true;
            case .move_up_fast;             move_cursor(-5);                                        return true;
            case .move_down_fast;           move_cursor( 5);                                        return true;
            case .move_up_one_page;         move_cursor(-per_page);                                 return true;
            case .move_down_one_page;       move_cursor( per_page);                                 return true;

            case .close_dialog;             finder_close();                                         return true;
            case .open_entry_in_place;      finder_open_selected_result(selected, .in_place);       return true;
            case .open_entry_on_the_side;   finder_open_selected_result(selected, .on_the_side);    return true;
            case .open_entry_on_the_left;   finder_open_selected_result(selected, .left);           return true;
            case .open_entry_on_the_right;  finder_open_selected_result(selected, .right);          return true;
        }
        return false;

    } else if event.type == .TEXT_INPUT {
        char := event.utf32;
        if char == 127 return true;  // there seems to be a bug in the Input module
                                     // which generates a TEXT_INPUT event for DEL
                                     // when Ctrl+Backspace is pressed

        text_input_type_char(*finder.input, char);
        start_new_search();
        return true;
    }
    return false;
}

finder_is_open :: () -> bool {
    return active_global_widget == .finder;
}

finder_open :: () {
    active_global_widget = .finder;

    using finder;
    input.cursor.sel = 0;
    input.cursor.pos = xx input.text.count;

    if need_to_refresh_results {
        need_to_refresh_results = false;
        reset_results();
        start_new_search(force = true);
    }
}

finder_close :: () {
    activate_editors();
}

finder_open_from_editor :: () {
    editor, buffer := get_active_editor_and_buffer();

    // If there was some text selected that doesn't span more than one line, use it for search
    if editor && editor.cursors.count == 1 {
        cursor := editor.cursors[0];
        selected_text := get_selected_string(cursor, buffer);
        if selected_text && selected_text != to_string(finder.input.text) && offset_to_line(editor, buffer, cursor.pos) == offset_to_line(editor, buffer, cursor.sel) {
            replace_text(*finder.input, selected_text);
            reset_results();
            start_new_search();
        }
    }

    finder_open();
}

finder_update :: () {
    using finder;
    if !initted return;

    // If a buffer has changed while we have the finder window open, we have to refresh
    if finder_is_open() && need_to_refresh_results {
        need_to_refresh_results = false;
        reset_results();
        start_new_search(force = true);
    }

    tasks := get_completed_work(*thread_group);
    for tasks {
        task := cast(*Search_Task) it;

        if request.id != task.request_id {
            // Old task, ignore
            free_task(task);
            continue;
        }

        array_add(*request.completed_tasks, task);
        request.num_tasks_left -= 1;
        if request.num_tasks_left == 0 {
            // Received all data, collect all results for displaying
            total_results := 0;
            for request.completed_tasks total_results += it.num_results;
            array_resize(*results, total_results, initialize = false);
            i := 0;
            for request.completed_tasks {
                memcpy(results.data + i, it.results.data, it.num_results * size_of(Search_Result));
                i += it.num_results;
            }

            compare_search_results :: (r1: Search_Result, r2: Search_Result) -> s64 {
                return cast,no_check(s64) r1.sort_key - cast,no_check(s64) r2.sort_key;
            }

            quick_sort(results, compare_search_results);

            needle = copy_string(request.needle);

            // Clean up task data
            for request.completed_tasks free_task(it);
            array_reset_keeping_memory(*request.completed_tasks);

            scroll_y = 0;
            scroll_anim.target = 0;
            selected = 0;
            request.in_progress = false;
        }
    }

    if request.in_progress then redraw_requested = true;
}

finder_open_selected_result :: (selected_num := -1, placement: Editor_Placement) {
    using finder;
    if request.in_progress return;
    if selected_num >= 0 then selected = selected_num;
    if selected >= results.count return;

    activate_editors();

    result := results[selected];

    old_layout := editors.layout;
    editors_open_buffer(result.buffer_id, placement);

    // Select the search result
    editor, buffer := get_active_editor_and_buffer();
    match_start := min(result.match_offset,                xx buffer.bytes.count);  // buffer could've changed, so offset may not be valid any more
    match_end   := min(result.match_offset + needle.count, xx buffer.bytes.count);
    cursor := leave_only_original_cursor(editor);
    cursor.sel = xx match_start;
    cursor.pos = xx match_end;

    editor.scroll_to_cursor = .yes;
    if old_layout == .Single && editors.layout == .Double {
        // We've just opened a new editor, so need to let it know it's being opened,
        // so that it can use the target rect width for its scroll calculations
        // (otherwise it'll be too small and the scroll will not animate where expected)
        editor.scroll_to_cursor = .yes_new_editor;
    }
}

finder_toggle_whole_word :: () {
    using finder;

    whole_word = !whole_word;
    start_new_search(force = true);
}

finder_toggle_case_sensitive :: () {
    using finder;

    case_sensitive = !case_sensitive;
    start_new_search(force = true);
}

#scope_file

move_cursor :: (delta: s64, wrap := false, snap := true) {
    using finder;

    selected += delta;

    if wrap {
        if selected < 0 then selected = max(0, results.count - 1);
        if selected >= results.count then selected = 0;
    } else {
        if selected < 0 then selected = 0;
        if selected >= results.count then selected = results.count - 1;
    }
    scroll_to_cursor = ifx snap then Scroll_Mode.snap else .yes;
}

start_new_search :: (force := false) {
    using finder;

    if !initted return;

    if !input.text {
        reset_search_request(*request, new_needle = "");
        reset_results();
        return;
    }
    if request.needle == to_string(input.text) && !force return;  // needle hasn't changed, no need to repeat

    request.case_sensitive = case_sensitive;
    request.whole_word     = whole_word;

    reset_search_request(*request, new_needle = to_string(input.text));
    request.in_progress = true;

    num_threads := thread_group.worker_info.count;
    assert(num_threads > 0);

    buffers_per_thread := open_buffers.count / num_threads + 1;
    buffer_start_index := 0;

    while buffer_start_index < open_buffers.count {
        task := New(Search_Task);
        task.request_id = request.id;
        task.needle = copy_string(request.needle);  // we have to copy because otherwise we'd have to sync with other threads
        task.skip_table = array_copy(request.skip_table);
        task.buffer_start_index = cast(s32) buffer_start_index;
        task.buffer_end_index   = cast(s32) min(buffer_start_index + buffers_per_thread - 1, open_buffers.count - 1);
        task.case_sensitive = request.case_sensitive;
        task.whole_word = request.whole_word;

        add_work(*thread_group, task, needle);
        request.num_tasks_left += 1;  // only modified in the main thread so no atomics needed

        buffer_start_index += buffers_per_thread;
    }
}

search_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    using task := cast(*Search_Task) work;

    for buffer_id : buffer_start_index .. buffer_end_index {
        // Search in buffer
        buffer := *open_buffers[buffer_id];
        if (buffer.deleted && !buffer.modified) || buffer.binary continue;  // do not search

        // Make sure the buffer contents doesn't change while we're scanning it
        lock(*buffer.content_lock);
        defer unlock(*buffer.content_lock);

        contents := to_string(buffer.bytes);

        // Sort key parts
        dir_id_part:    u64 = (cast,trunc(u64) (buffer.file.project_dir_id + 1)) << 56;
        buffer_id_part: u64 = (cast,trunc(u64) buffer_id)                        << 32;
        if buffer.modified || buffer.modified_on_disk then dir_id_part = 0;  // make sure modified buffers are on top

        file_end := contents.data + contents.count;
        offset := 0;
        while true {
            if case_sensitive {
                offset = inline bmh_find_index_from_left(contents, needle, start_index = offset, skip_table, case_sensitive = true);
            } else {
                offset = inline bmh_find_index_from_left(contents, needle, start_index = offset, skip_table, case_sensitive = false);
            }
            if offset < 0 break;

            if !whole_word || (whole_word && match_whole_word(contents, offset, needle.count)) {
                result := *results[num_results];
                result.buffer_id    = buffer_id;
                result.match_offset = xx offset;

                offset_part: u64 = (cast,trunc(u64) offset) << 0;
                result.sort_key = dir_id_part | buffer_id_part | offset_part;

                num_results += 1;
                if num_results >= MAX_RESULTS_PER_WORKER break buffer_id;
            }

            offset += needle.count;
        }
    }

    return .CONTINUE;  // we want to reuse this thread for future searches
}

reset_search_request :: (using request: *Search_Request, new_needle: string) { //@nocheckin: add whole_word / case sensitive parameters
    id += 1;
    for completed_tasks free_task(it);
    array_reset_keeping_memory(*completed_tasks);
    if needle then free(needle);
    needle = copy_string(new_needle);
    skip_table = bmh_prepare_skip_table(needle, case_sensitive);
    num_tasks_left = 0;
    in_progress = false;
}

reset_results :: () {
    using finder;
    if needle then free(needle);
    needle = "";
    array_reset_keeping_memory(*results);
    scroll_y = 0;
    scroll_anim.target = 0;
    selected = 0;
}

free_task :: (task: *Search_Task) {
    free(task.needle);
    array_free(task.skip_table);
    free(task);
}

toggle_expand :: () {
    using finder;

    if width_percentage != WIDTH_EXPANDED {
        start_animation(*width_anim, width_percentage, WIDTH_EXPANDED, snappy = true);
    } else {
        start_animation(*width_anim, width_percentage, WIDTH_NORMAL, snappy = true);
    }
}

#scope_export

finder: Finder;

Finder :: struct {
    initted := false;  // will be initialized when the initial workspace scan completes

    input: Text_Input;

    request: Search_Request;
    needle: string;  // to remember what search string the results below correspond to
    results: [..] Search_Result;

    case_sensitive: bool;
    whole_word: bool;

    selected: s64;
    selected_by_mouse: s64 = -1;  // to remember which entry the left mouse button went down on. Do we need it?
    per_page := 10;

    scroll_y: s32;
    scroll_anim := #run Tween_Animation(s32).{ speed = xx 0.1, func = .lerp };
    scroll_to_cursor: Scroll_Mode = .no;

    width_percentage := WIDTH_NORMAL;  // how much of the screen the popup occupies
    width_anim := #run Tween_Animation(float).{ start = WIDTH_NORMAL, target = WIDTH_NORMAL };
    WIDTH_NORMAL   :: 0.7;
    WIDTH_EXPANDED :: 0.95;

    need_to_refresh_results: bool;  // when a buffer is modified and we have some search results, we have to search again,
                                    // otherwise the search results may point to an offset which no longer exists or is invalid
}

#scope_file

Search_Result :: struct {
    // Line numbers and boundaries will be calculated at draw time only for the visible entries
    // as they require doing an additional search in buffer.
    buffer_id:    s32;
    match_offset: s32;
    sort_key:     u64;
}

// When we start a new search, a new request it created, and all the results from
// any unfinished tasks from a previous search will be discarded when they arrive
Search_Request :: struct {
    id: s64 = -1;
    num_tasks_left: s32;
    completed_tasks: [..] *Search_Task;
    needle: string;
    skip_table: [256] s32;
    in_progress: bool;
    case_sensitive: bool;
    whole_word: bool;
}

// A task received by a worker thread
Search_Task :: struct {
    request_id:  s64;
    needle: string;
    skip_table: [] s32;
    case_sensitive: bool;
    whole_word: bool;

    // Will search in these buffers
    buffer_start_index: s32;
    buffer_end_index:   s32;

    // To be filled by the worker thread
    num_results: s64;
    results: [MAX_RESULTS_PER_WORKER] Search_Result;
}

thread_group: Thread_Group;

MAX_RESULTS_PER_WORKER :: 1000;
