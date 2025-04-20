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
    reset_results();
    text_input_fully_clear(*finder.input);
    finder.initted = false;
}

finder_handle_event :: (event: Input.Event) -> handled: bool {
    using finder;

    if event.type == .KEYBOARD && event.key_pressed {
        handled := text_input_handle_event(get_active_input(), event);
        if handled { start_new_search(); return true; }

        action, mapping := map_event_to_action(event, Action_Search_Dialog);
        if action == {
            case .toggle_expand;            toggle_expand();                                        return true;
            case .toggle_case_sensitive;    finder_toggle_case_sensitive();                         return true;
            case .toggle_whole_word;        finder_toggle_whole_word();                             return true;
            case .toggle_regex_search;      finder_toggle_regex_search();                           return true;

            case .move_up;                  move_cursor(-1, wrap = true);                           return true;
            case .move_down;                move_cursor( 1, wrap = true);                           return true;
            case .move_up_fast;             move_cursor(-5);                                        return true;
            case .move_down_fast;           move_cursor( 5);                                        return true;
            case .move_up_one_page;         move_cursor(-per_page);                                 return true;
            case .move_down_one_page;       move_cursor( per_page);                                 return true;

            case .escape;                     #through;
            case .close_dialog;               finder_close();                                       return true;
            case .focus_next_ui_element;      finder_go_to_next_input();                            return true;
            case .focus_previous_ui_element;  finder_go_to_previous_input();                        return true;

            case .open_entry;               finder_open_selected_result(.in_place);                 return true;
            case .open_entry_in_side_pane;  finder_open_selected_result(.on_the_side);              return true;

            case .switch_to_left_pane;      finder_open_selected_result(.left);                     return true;
            case .switch_to_right_pane;     finder_open_selected_result(.right);                    return true;
            case .switch_to_top_pane;       finder_open_selected_result(.top);                      return true;
            case .switch_to_bottom_pane;    finder_open_selected_result(.bottom);                   return true;

            case .switch_to_pane_1;         finder_open_selected_result_in_pane(1);                 return true;
            case .switch_to_pane_2;         finder_open_selected_result_in_pane(2);                 return true;
            case .switch_to_pane_3;         finder_open_selected_result_in_pane(3);                 return true;
            case .switch_to_pane_4;         finder_open_selected_result_in_pane(4);                 return true;
            case .switch_to_pane_5;         finder_open_selected_result_in_pane(5);                 return true;
            case .switch_to_pane_6;         finder_open_selected_result_in_pane(6);                 return true;
            case .switch_to_pane_7;         finder_open_selected_result_in_pane(7);                 return true;
            case .switch_to_pane_8;         finder_open_selected_result_in_pane(8);                 return true;
            case .switch_to_pane_9;         finder_open_selected_result_in_pane(9);                 return true;
        }
        return false;

    } else if event.type == .TEXT_INPUT {
        text_input_type_char(get_active_input(), event.utf32);
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

    case_sensitive_toggled_manually = false;

    if need_to_refresh_results {
        need_to_refresh_results = false;
        reset_results();
        start_new_search(force = true);
    }
}

finder_close :: () {
    activate_editors();
}

finder_activate_input :: inline (input: Finder.Active_Input) {
    finder.active_input = input;
}

finder_go_to_next_input :: () {
    NUM_INPUTS :: #run enum_highest_value(Finder.Active_Input) + 1;
    next_input := (cast(u32) finder.active_input + 1) % NUM_INPUTS;
    finder_activate_input(cast(Finder.Active_Input) next_input);
}

finder_go_to_previous_input :: () {
    NUM_INPUTS :: #run enum_highest_value(Finder.Active_Input) + 1;
    current_input := cast(u32) finder.active_input;
    next_input := ifx current_input == 0 then NUM_INPUTS - 1 else current_input - 1;
    finder_activate_input(cast(Finder.Active_Input) next_input);
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

        if task.worker_limit_reached then finder.result_limit_reached = true;

        array_add(*request.completed_tasks, task);
        request.num_tasks_left -= 1;
        if request.num_tasks_left == 0 {
            // Received all data, collect all results for displaying
            total_results := 0;
            for request.completed_tasks total_results += it.num_results;
            array_resize(*results, total_results, initialize = false);
            i := 0;
            for request.completed_tasks {
                focus_memcpy(results.data + i, it.results.data, it.num_results * size_of(Search_Result));
                i += it.num_results;
            }

            compare_search_results :: (r1: Search_Result, r2: Search_Result) -> s64 {
                return cast,no_check(s64) r1.sort_key - cast,no_check(s64) r2.sort_key;
            }

            quick_sort(results, compare_search_results);

            if needle then free(needle);
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

finder_open_selected_result :: (placement: Editor_Placement, selected_num := -1) {
    using finder;
    if request.in_progress return;
    if selected_num >= 0 then selected = selected_num;
    if selected >= results.count return;

    result := results[selected];
    editors_open_buffer(result.buffer_id, placement);
    jump_to_search_result(result);
}

finder_open_selected_result_in_pane :: (number: s64) {
    target_pane := editors_find_pane_by_number(number);
    if !target_pane {
        add_user_error("Pane number % doesn't exist", number, dismiss_in_seconds = 3);
        return;
    }

    result := finder.results[finder.selected];
    editors_open_buffer_in_pane(result.buffer_id, target_pane);
    jump_to_search_result(result);
}

jump_to_search_result :: (result: Search_Result) {
    activate_editors();
    editor, buffer := get_active_editor_and_buffer();
    match_start := min(result.match_offset,                      xx buffer.bytes.count);  // buffer could've changed, so offset may not be valid any more
    match_end   := min(result.match_offset + result.match_count, xx buffer.bytes.count);
    cursor := leave_only_original_cursor(editor);
    cursor.sel = xx match_start;
    cursor.pos = xx match_end;

    editor.scroll_to_cursor = .yes;
}

finder_toggle_whole_word :: () {
    using finder;

    whole_word = !whole_word;
    start_new_search(force = true);
}

finder_toggle_case_sensitive :: () {
    using finder;

    case_sensitive = !case_sensitive;
    case_sensitive_toggled_manually = true;

    start_new_search(force = true);
}

finder_toggle_regex_search :: () {
    using finder;

    regex_search = !regex_search;
    start_new_search(force = true);
}

#scope_file

get_active_input :: () -> *Text_Input {
    using finder;

    if #complete active_input == {
        case .input;    return *input;
        case .include;  return *include;
        case .exclude;  return *exclude;
    }
}

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

    new_needle, new_include, new_exclude := to_string(input.text), to_string(include.text), to_string(exclude.text);

    if !new_needle {
        reset_search_request(*request, new_needle, new_include, new_exclude);
        reset_results();
        return;
    }

    if !force && request.needle == new_needle && request.include == new_include && request.exclude == new_exclude return;  // nothing has changed, no need to repeat

    if config.settings.search_is_case_sensitive_when_uppercase_present && !case_sensitive_toggled_manually {
        case_sensitive = contains_uppercase_ascii(new_needle);
    }

    request.case_sensitive = case_sensitive;
    request.whole_word     = whole_word;
    request.regex_search   = regex_search;
    if regex_search {
        regex: re.Regexp;

        flags := BASE_REGEX_FLAGS;
        if !case_sensitive flags |= .FoldCase;

        regex, regex_is_valid = re.compile(new_needle, flags);
        if !regex_is_valid return;  // only search if the regex is valid

        re.uninit(*regex);
    }

    reset_search_request(*request, new_needle, new_include, new_exclude);
    request.in_progress = true;

    num_threads := thread_group.worker_info.count;
    assert(num_threads > 0);

    buffers_per_thread := open_buffers.count / num_threads + 1;
    buffer_start_index := 0;

    while buffer_start_index < open_buffers.count {
        task := New(Search_Task);
        task.request_id = request.id;
        task.needle  = copy_string(request.needle);  // we have to copy because otherwise we'd have to sync with other threads
        task.include = copy_string(request.include);
        task.exclude = copy_string(request.exclude);
        task.skip_table = array_copy(request.skip_table);
        task.buffer_start_index = cast(s32) buffer_start_index;
        task.buffer_end_index   = cast(s32) min(buffer_start_index + buffers_per_thread - 1, open_buffers.count - 1);
        task.case_sensitive = request.case_sensitive;
        task.whole_word = request.whole_word;
        task.regex_search = request.regex_search;

        add_work(*thread_group, task, needle);
        request.num_tasks_left += 1;  // only modified in the main thread so no atomics needed

        buffer_start_index += buffers_per_thread;
    }

    if regex_search && regex_is_valid  reset_results();
}

search_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    using task := cast(*Search_Task) work;

    regex: re.Regexp;
    if regex_search {
        // Compile the regex for each threadproc for thread safety
        re_text := ifx whole_word then tprint("\\w%\\w", needle) else needle;
        flags := BASE_REGEX_FLAGS;
        if !case_sensitive then flags |= .FoldCase;
        regex = re.compile(re_text, flags);  // NOTE: the validity of this regex has been determined by previous code
    }
    defer if regex_search then re.uninit(*regex);

    // Split wildcards into arrays
    includes: [..] string;
    excludes: [..] string;
    includes.allocator = temp;
    excludes.allocator = temp;
    for rule : split(include, cast(u8) #char ",",, temp) {
        trimmed := trim(rule);
        if trimmed then array_add(*includes, trimmed);
    }
    for rule : split(exclude, cast(u8) #char ",",, temp) {
        trimmed := trim(rule);
        if trimmed then array_add(*excludes, trimmed);
    }

    for buffer_id : buffer_start_index .. buffer_end_index {
        // Search in buffer
        buffer := *open_buffers[buffer_id];
        if (buffer.deleted && !buffer.modified) || buffer.binary || buffer.internal  continue;  // do not search
        if !should_include_buffer(buffer, includes) || should_exclude_buffer(buffer, excludes)  continue;

        // Make sure the buffer contents doesn't change while we're scanning it
        lock(*buffer.content_lock);
        defer unlock(*buffer.content_lock);

        // Sort key parts
        dir_id_part:    u64 = (cast,trunc(u64) (buffer.file.project_dir_id + 1)) << 56;
        buffer_id_part: u64 = (cast,trunc(u64) buffer_id)                        << 32;
        if buffer.modified || buffer.modified_on_disk then dir_id_part = 0;  // make sure modified buffers are on top
        buffer_sort_key: u64 = dir_id_part | buffer_id_part;

        if regex_search {
            find_all_using_regex(task, regex, buffer, buffer_id, buffer_sort_key);
        } else {
            find_all(task, buffer, buffer_id, buffer_sort_key);
        }

        if num_results >= MAX_RESULTS_PER_WORKER { worker_limit_reached = true; break; }
    }

    return .CONTINUE;  // we want to reuse this thread for future searches
}

should_include_buffer :: (buffer: Buffer, includes: [] string) -> bool {
    if !includes return true;
    return _buffer_matches_wildcards(buffer, includes);
}

should_exclude_buffer :: inline (buffer: Buffer, excludes: [] string) -> bool {
    if !excludes return false;
    return _buffer_matches_wildcards(buffer, excludes);
}

_buffer_matches_wildcards :: (buffer: Buffer, wildcards: [] string) -> bool {
    path := ifx buffer.has_file then buffer.file.full_path else "";  // defaulting to "" in case there's an all-catch wildcard
    path_chunks := split(path, cast(u8) #char "/",, allocator = temp);

    for wildcards {
        if contains(it, cast(u8) #char "/") {
            // Match whole path
            if platform_path_begins_with(path, it) || path_wildcard_match(path, it) return true;
        } else {
            // Match partial path
            for chunk : path_chunks {
                if path_wildcard_match(chunk, it) return true;
            }
        }
    }

    return false;
}

find_all_using_regex :: (using task: *Search_Task, regex: re.Regexp, buffer: Buffer, buffer_id: s32, buffer_sort_key: u64) {
    buffer_str := to_string(buffer.bytes);

    while true {
        if buffer_str.count <= 0 break;

        auto_release_temp();  // this is very important because the regex library allocates a lot and we need to throw it away immediately

        matched, captures := re.match(buffer_str, regex,, allocator = temp);
        if !matched break;

        c := captures[0];
        offset := c.data - buffer.bytes.data;
        count  := c.count;
        if offset < 0 || offset >= buffer.bytes.count break;

        advance_amount := c.data - buffer_str.data + count;
        if advance_amount > 0 then advance(*buffer_str, advance_amount);

        if count == 0 || starts_with(buffer_str, #char "\n") then advance_to_next_line(*buffer_str);  // some matches could be of 0 length, which is valid, skip to the next line in this case, because otherwise we could have to look at every byte and that takes too long

        // Valid result, add to the list
        result := *results[num_results];
        result.buffer_id    = buffer_id;
        result.match_offset = xx offset;
        result.match_count  = xx count;

        offset_part: u64 = (cast,trunc(u64) offset) << 0;
        result.sort_key = buffer_sort_key | offset_part;

        num_results += 1;
        if num_results >= MAX_RESULTS_PER_WORKER { worker_limit_reached = true; break; }
    }
}

find_all :: (using task: *Search_Task, buffer: Buffer, buffer_id: s32, buffer_sort_key: u64) {
    buffer_str := to_string(buffer.bytes);
    offset := 0;

    while true {
        if case_sensitive {
            offset = inline bmh_find_index_from_left(buffer_str, needle, start_index = offset, skip_table, case_sensitive = true);
        } else {
            offset = inline bmh_find_index_from_left(buffer_str, needle, start_index = offset, skip_table, case_sensitive = false);
        }
        if offset < 0 break;
        if whole_word && !match_whole_word(buffer_str, offset, needle.count) { offset += needle.count; continue; }

        result := *results[num_results];
        result.buffer_id    = buffer_id;
        result.match_offset = xx offset;
        result.match_count  = xx needle.count;

        offset_part: u64 = (cast,trunc(u64) offset) << 0;
        result.sort_key = buffer_sort_key | offset_part;

        num_results += 1;
        if num_results >= MAX_RESULTS_PER_WORKER { worker_limit_reached = true; break; }

        offset += needle.count;
    }
}

reset_search_request :: (using request: *Search_Request, new_needle: string, new_include: string, new_exclude: string) {
    id += 1;
    for completed_tasks free_task(it);
    array_reset_keeping_memory(*completed_tasks);

    if needle  then free(needle);
    if include then free(include);
    if exclude then free(exclude);
    needle  = copy_string(new_needle);
    include = copy_string(new_include);
    exclude = copy_string(new_exclude);

    skip_table = bmh_prepare_skip_table(needle, case_sensitive);
    num_tasks_left = 0;
    in_progress = false;
    finder.result_limit_reached = false;
}

reset_results :: () {
    using finder;
    if needle then free(needle);
    needle = "";
    result_limit_reached = false;
    array_reset_keeping_memory(*results);
    scroll_y = 0;
    scroll_anim.target = 0;
    selected = 0;
}

free_task :: (task: *Search_Task) {
    free(task.needle);
    free(task.include);
    free(task.exclude);
    array_free(task.skip_table);
    free(task);
}

toggle_expand :: () {
    using finder;

    target_width := ifx width_percentage != WIDTH_EXPANDED then WIDTH_EXPANDED else WIDTH_NORMAL;
    start_animation(*width_anim, width_percentage, target_width);
}

#scope_export

finder: Finder;

Finder :: struct {
    initted := false;  // will be initialized when the initial workspace scan completes

    input: Text_Input;
    include: Text_Input;
    exclude: Text_Input;
    active_input: Active_Input = .input;
    Active_Input :: enum { input; include; exclude; }

    request: Search_Request;
    needle: string;  // to remember what search string the results below correspond to
    results: [..] Search_Result;
    result_limit_reached: bool;

    case_sensitive: bool;
    case_sensitive_toggled_manually: bool;
    whole_word: bool;
    regex_search: bool;
    regex_is_valid: bool;

    selected: s64;
    selected_by_mouse: s64 = -1;  // to remember which entry the left mouse button went down on. Do we need it?
    per_page := 10;

    scroll_y: s32;
    scroll_anim := #run Tween_Animation(s32).{ duration = 0.1, func = .lerp };
    scroll_to_cursor: Scroll_Mode = .no;

    width_percentage := WIDTH_NORMAL;  // how much of the screen the popup occupies
    width_anim := #run Tween_Animation(float).{ start = WIDTH_NORMAL, target = WIDTH_NORMAL };
    WIDTH_NORMAL   :: 0.7;
    WIDTH_EXPANDED :: 0.95;

    search_input_width  := 0.7;  // how much of the total width is allocated for the search input
    include_input_width := 0.5;  // splitter position between the filter inputs

    need_to_refresh_results: bool;  // when a buffer is modified and we have some search results, we have to search again,
                                    // otherwise the search results may point to an offset which no longer exists or is invalid
}

#scope_file

Search_Result :: struct {
    // Line numbers and boundaries will be calculated at draw time only for the visible entries
    // as they require doing an additional search in buffer.
    buffer_id:    s32;
    match_offset: s32;
    match_count:  s32;
    sort_key:     u64;
}

// When we start a new search, a new request it created, and all the results from
// any unfinished tasks from a previous search will be discarded when they arrive
Search_Request :: struct {
    id: s64 = -1;
    num_tasks_left: s32;
    completed_tasks: [..] *Search_Task;
    needle: string;
    include: string;
    exclude: string;
    skip_table: [256] s32;
    in_progress: bool;
    case_sensitive: bool;
    whole_word: bool;
    regex_search: bool;
}

// A task received by a worker thread
Search_Task :: struct {
    request_id:  s64;
    needle: string;
    include: string;
    exclude: string;
    skip_table: [] s32;
    case_sensitive: bool;
    whole_word: bool;
    regex_search: bool;

    // Will search in these buffers
    buffer_start_index: s32;
    buffer_end_index:   s32;

    // To be filled by the worker thread
    num_results: s64;
    results: [MAX_RESULTS_PER_WORKER] Search_Result;
    worker_limit_reached: bool;
}

thread_group: Thread_Group;

MAX_RESULTS_PER_WORKER :: 1000;
