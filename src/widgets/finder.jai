init_finder :: () {
    // Create a thread group with one thread for searching (we don't need more).
    // NOTE: it MUST be one thread, otherwise our pool allocation strategy won't work
    init(*thread_group, num_threads = 1, group_proc = search_in_project_threadproc);
    thread_group.name = "Finder";
    thread_group.logging = false;
    
    start(*thread_group);
}

deinit_finder :: () {
    shutdown(*thread_group);
    reset(*memory_pools[0]);
    reset(*memory_pools[1]);
}

finder_handle_event :: (event: Input.Event) {
    if event.type == {
        case .KEYBOARD;
            if event.key_pressed {
                if event.key_code == {
                    case .ESCAPE;   shrink_if_enlarged(); deactivate_finder(); return;
                    case #char "B"; if only_ctrl_pressed(event.modifier_flags) { close_finder(); return; }
                    case #char "P"; if only_ctrl_pressed(event.modifier_flags) { show_open_file_dialog(); return; }
                    case #char "F"; if only_ctrl_shift_pressed(event.modifier_flags) { activate_finder(); return; }
                }
                finder_handle_key_press(event.key_code, event.modifier_flags);
            }

        case .TEXT_INPUT;
            finder_handle_text_input(event.utf32);
    }
}

finder_handle_key_press :: (key_code: Input.Key_Code, mods: Mods) {
    using finder;

    if active_part == .input {
        handled := text_input_handle_keypress(*input, key_code, mods);
        if handled return;
    }

    if key_code == {
        case #char "L";
            if only_ctrl_shift_pressed(mods) toggle_enlarged();

        case .ENTER;
            if active_part == .input || !last_search.results {
                search_in_project(to_string(input.text), case_sensitive = only_shift_pressed(mods));
            } else {
                finder_open_selected_result(on_the_side = only_ctrl_pressed(mods));
            }

        case .ARROW_UP;    move_cursor_up  (jump_by_file = only_ctrl_pressed(mods));
        case .ARROW_DOWN;  move_cursor_down(jump_by_file = only_ctrl_pressed(mods));
        case .PAGE_UP;     move_cursor_up  (jump_by_file = true);
        case .PAGE_DOWN;   move_cursor_down(jump_by_file = true);
        case .TAB;         if only_shift_pressed(mods) then move_cursor_up(); else move_cursor_down();
    }
}

finder_handle_text_input :: (char: u32) {
    if char == 127 return;  // there seems to be a bug in the Input module
                            // which generates a TEXT_INPUT event for DEL
                            // when Ctrl+Backspace is pressed

    if finder.active_part == .input {
        text_input_type_char(*finder.input, char);
    }

}

finder_is_open :: inline () -> bool {
    return finder.openness > 0;
}

finder_is_active :: inline () -> bool {
    return active_global_widget == .finder;
}

toggle_finder :: () {
    if finder_is_open() then close_finder(); else open_finder();
}

activate_finder :: (part: Finder.Active_Part = .input, select_text := true) {
    using finder;

    active_global_widget = .finder;
    if last_search.results {
        active_part = part;
    } else {
        active_part = .input;  // we don't always have results, but we always have the input
    }

    if select_text {
        input.cursor.sel = 0;
        input.cursor.pos = get_num_chars(input.text);
    }
}

deactivate_finder :: inline () {
    // Currently the only one other global widget available when the finder is open is the editors,
    // because open_file_dialog is modal and will close if finder opens.
    // If that changes we may have to change this code, too.
    active_global_widget = .editors;
}

open_finder :: () {
    using finder;
    activate_finder();
    start_animation(*open_anim, openness, default_openness);
}

close_finder :: () {
    active_global_widget = .editors;

    start_animation(*finder.open_anim, finder.openness, 0);
}

open_finder_from_editor :: () {
    editor, buffer := get_active_editor_and_buffer();

    // If there was some text selected that doesn't span more than one line, use it for search
    if editor && editor.cursors.count == 1 {
        cursor := editor.cursors[0];
        selected_text := get_selected_string(cursor, buffer);
        if selected_text && cursor.sel.line == cursor.pos.line {
            array_resize(*finder.input.text, selected_text.count);
            memcpy(finder.input.text.data, selected_text.data, selected_text.count);
        }
    }

    if !finder_is_open() then open_finder(); else activate_finder(); return;
}

finder_open_selected_result :: (on_the_side := false) {
    using finder;
    if search_in_progress return;
    
    result := last_search.results[cursor.result];
    needle := last_search.needle;
    
    active_global_widget = .editors;
    shrink_if_enlarged();
    
    old_layout := editors_layout;    
    editors_open_file(result.file.full_path, on_the_side = on_the_side);

    // Select the search result
    editor, buffer := get_active_editor_and_buffer();

    // We search in buffer again and try to select the result we want (provided it hasn't changed).
    // This is because while we search the file may have CRLF line endings, buf we strip them
    // when we load the buffer, so if we just remember offsets they may not match, unfortunately!
    // The easiest thing for now is to just repeat the search.
    buffer_str := to_string(buffer.bytes);
    found := true;
    offset := 0;
    for 0 .. cursor.line {
        if last_search.case_sensitive {
            offset = find_index_from_left(buffer_str, needle, start_index = offset);
        } else {
            offset = find_index_from_left_nocase(buffer_str, needle, start_index = offset);
        }
        if offset < 0 {
            found = false;  // probably the buffer has changed
            break;
        }
        offset += needle.count;
    }
    if found {
        cursor := leave_only_original_cursor(editor);
        cursor.sel = offset_to_pos(buffer, offset - needle.count);
        cursor.pos = offset_to_pos(buffer, offset);
    }

    editor.scroll_to_cursor = .yes;
    if old_layout == .Single && editors_layout == .Double {
        // We've just opened a new editor, so need to let it know it's being opened,
        // so that it can use the target rect width for its scroll calculations
        // (otherwise it'll be too small and the scroll will not animate where expected)
        editor.scroll_to_cursor = .yes_new_editor;
    }
}

finder_set_openness :: (value: float) {
    using finder;
    openness = clamp(value, 0, Finder.MAX_OPENNESS);;
    if openness < Finder.MIN_OPENNESS then openness = 0;  // fully close if too small
    open_anim.target = openness;
    if openness == 0 then deactivate_finder();
    default_openness = ifx openness > Finder.MIN_OPENNESS then openness else Finder.DEFAULT_OPENNESS;
}

maybe_animate_finder :: () {
    using finder;
    if openness != open_anim.target {
        redraw_requested = true;
        openness = get_animation_value(open_anim);
    }
}

finder_update :: () {
    using finder;
    if !search_in_progress return;
    
    redraw_requested = true;
    
    results := get_completed_work(*thread_group);
    if results {
        assert(results.count == 1);
        
        // Point finder to the new results
        request := cast(*Search_Request) results[0];
        last_search = << request;
        
        free_old_memory_pool();
        
        // Reset scroll and cursor
        scroll_y = 0;
        scroll_anim.target = 0;
        cursor = .{ result = -1, line = 0};
                
        search_in_progress = false;
    }
}

finder: Finder;


#scope_file

move_cursor_up :: (jump_by_file := false) {
    using finder.cursor;
    
    search_results := finder.last_search.results;
    
    if !search_results return;
    if result < 0 || (line == 0 && result == 0) {
        finder.active_part = .input;  // "move" back to the input
        result = -1;
        return;
    }

    if jump_by_file {
        if line == 0 && result > 0 then result -= 1;
        line = 0;
    } else {
        if line == 0 && result > 0 {
            result -= 1;
            line = cast(s32) search_results[result].lines.count - 1;
        } else if line > 0 {
            line -= 1;
        }
    }
    if result < 0 then result = 0;
    finder.scroll_to_cursor = true;
}

move_cursor_down :: (jump_by_file := false) {
    using finder.cursor;
    
    search_results := finder.last_search.results;
    
    if !search_results return;
    finder.active_part = .results;

    max_result := cast(s32) search_results.count - 1;

    if jump_by_file {
        if result < max_result {
            result += 1;
            line = 0;
        } else {
            line = cast(s32) search_results[result].lines.count - 1;  // jump to last line
        }
    } else if result >= 0 && result <= max_result {
        if line < search_results[result].lines.count - 1 {
            line += 1;
        } else if result < max_result {
            result += 1;
            line = 0;
        }
    }
    if result < 0 then result = 0;
    finder.scroll_to_cursor = true;
}

search_in_project :: (needle: string, case_sensitive: bool) {
    if !needle return;
    if finder.search_in_progress return;
    
    assert(thread_group.worker_info.count == 1, "Only ONE thread is allowed for project-wide search!");
    
    search_request := New(Search_Request, allocator = get_free_pool_allocator());
    search_request.needle = copy_string(needle);
    search_request.case_sensitive = case_sensitive;
    
    finder.search_in_progress = true;
    
    add_work(*thread_group, search_request, search_request.needle);
}

search_in_project_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    request := cast(*Search_Request) work;
    needle  := request.needle; 
    
    allocator := get_free_pool_allocator();
    push_allocator(allocator);
    
    all_files: [..] File_Info;  // will be allocated from pool, no need to free

    // @Speed: probably can be sped up by not collecting everything upfront
    // and just scheduling search as we go (it takes 10ms on my machine to scan everything)
    // Also as an alternative could check out the code in count_lines_in_tree.jai,
    // maybe the code it uses to read dir entries is faster?
    collect_files(project_dirs, dst = *all_files);

    queue := File_Async.initialize_queue(File_Info);
    defer File_Async.destroy_queue(queue);

    files_left_to_read := all_files.count;
    skip_table := ifx request.case_sensitive then bmh_prepare_skip_table(needle, true) else bmh_prepare_skip_table(needle, false);

    for file : all_files {
        result := File_Async.read_entire_file(queue, file.full_path, file);
        if result.code == .FullQueue {
            file_info, data, success := File_Async.wait_for_completion(queue);
            if success.code == .Success {
                files_left_to_read -= 1;
                if request.case_sensitive {
                    search_in_file(request, file_info, to_string(data), needle, skip_table, true);
                } else {
                    search_in_file(request, file_info, to_string(data), needle, skip_table, false);
                }
            } else {
                log_error("Error while waiting for completion: %\n", success);
                files_left_to_read = 0;
                break;
            }
            result = File_Async.read_entire_file(queue, file.full_path, file);
        }
        if result.code != .Success {
            log_error("Error while trying to read file % asynchronously: %\n", file.full_path, result);
            files_left_to_read = 0;
            break;
        }
    }

    for 1 .. files_left_to_read {
        file_info, data, success := File_Async.wait_for_completion(queue);
        if success.code == .Success {
            if request.case_sensitive {
                search_in_file(request, file_info, to_string(data), needle, skip_table, true);
            } else {
                search_in_file(request, file_info, to_string(data), needle, skip_table, false);
            }
        } else {
            log_error("Error while waiting for completion: %\n", success);
            break;
        }
    }
    
    return .CONTINUE;
}

search_in_file :: (request: *Search_Request, file: File_Info, contents: string, needle: string, skip_table: [] s32, $case_sensitive := false) {
    lines: [..] Search_Result.Line;
    
    if request.limit_reached return;

    file_end := contents.data + contents.count;
    offset := 0;
    while true {
        offset = inline bmh_find_index_from_left(contents, needle, start_index = offset, skip_table, case_sensitive);
        if offset < 0 break;

        str := slice(contents, offset, needle.count);

        MAX_CHARS_TO_THE_SIDE :: 50;  // don't want to go all the way to the newlines if the line is too long
        // TODO: go by chars, not bytes!
        
        // Expand to the left newline
        last_nonwhitespace := str.data;
        i := 0;
        while str.data > contents.data && <<(str.data - 1) != #char "\r" && <<(str.data - 1) != #char "\n" && i < MAX_CHARS_TO_THE_SIDE {
            str.data  -= 1;
            str.count += 1;
            if !inline is_space(<<str.data) then last_nonwhitespace = str.data;
            i += 1;
        }
        str.count -= last_nonwhitespace - str.data;
        str.data   = last_nonwhitespace;

        cut_on_left := i >= MAX_CHARS_TO_THE_SIDE;

        // Expand to the right newline
        end := str.data + str.count;
        i = 0;
        while end < file_end && <<end != #char "\n" && i < MAX_CHARS_TO_THE_SIDE {
            end += 1;
            i += 1;
        }
        str.count = end - str.data;
        
        cut_on_right := i >= MAX_CHARS_TO_THE_SIDE;

        line := array_add(*lines);
        line.str = str;
        line.offset_within = cast(s32) offset - cast(s32)(str.data - contents.data);
        if cut_on_left then line.offset_within += 3;  // account for the ellipsis on the left
        
        if cut_on_left && cut_on_right {
            line.str = sprint("…%…", line.str);
        } else if cut_on_left {
            line.str = sprint("…%",  line.str);
        } else if cut_on_right {
            line.str = sprint("%…",  line.str);
        }
        
        request.total_results += 1;
        if request.total_results >= Finder.MAX_RESULTS {
            request.limit_reached = true;
            break;
        }

        offset += needle.count;
    }

    if lines.count > 0 {
        result := array_add(*request.results);
        result.file = file;
        result.lines = xx lines;
    }
}

toggle_enlarged :: () {
    using finder;
    if values_are_close(openness, Finder.ENLARGED_OPENNESS) || openness > Finder.ENLARGED_OPENNESS {
        // Shrink
        start_animation(*open_anim, openness, Finder.DEFAULT_OPENNESS);
    } else {
        // Enlarge
        start_animation(*open_anim, openness, Finder.ENLARGED_OPENNESS);
    }
}

shrink_if_enlarged :: () {
    using finder;
    if values_are_close(openness, Finder.ENLARGED_OPENNESS) || openness > Finder.ENLARGED_OPENNESS {
        start_animation(*open_anim, openness, default_openness);
    }
}

Finder :: struct {
    openness: float = 0;  // percentage of window width. Zero means it's hidden
    input: Text_Input;

    last_search: Search_Request;
    search_in_progress: bool;  // it's ok to use a bool here as a flag because only the main thread will read and write it
    
    cursor: Selected_Result;
    
    scroll_y: s32;
    scroll_anim: Tween_Animation(s32);
    scroll_to_cursor: bool;

    active_part: Active_Part = .input;

    open_anim: Tween_Animation(float);

    default_openness := DEFAULT_OPENNESS;  // if the user drags it then we'll remember it
    
    Selected_Result :: struct { result: s32; line: s32; }
    Active_Part :: enum { input; results; }

    MIN_OPENNESS      :: 0.005;
    MAX_OPENNESS      :: 0.8;
    DEFAULT_OPENNESS  :: 0.2;
    ENLARGED_OPENNESS :: 0.5;

    MAX_RESULTS :: 5000;  // lines, not files
}

Search_Result :: struct {
    file: File_Info;
    lines: [] Line;

    Line :: struct {
        str: string;
        offset_within: s32;  // result offset from the beginning of the string (for highlighting)
        // global_offset: s32;  // offset from the beginning of the file // NOTE: don't use for now because of CRLF
    }
}

Search_Request :: struct {
    results: [..] Search_Result;
    needle: string;
    total_results:  int;
    limit_reached:  bool;
    case_sensitive: bool;
}

get_free_pool_allocator :: () -> Allocator {
    a: Allocator;
    a.proc = flat_pool_allocator_proc;
    a.data = *memory_pools[available_pool_index];
    return a;
}

free_old_memory_pool :: () {
    old_pool_index := ifx available_pool_index == 0 then 1 else 0;
    reset(*memory_pools[old_pool_index]);
    available_pool_index = old_pool_index;
}

// We use 2 memory pools. When a new search starts, it will choose the next available pool
// and will allocate all the results and all the auxiliary data from there.
// When the search is finished, finder will display the results using data from this pool.
// When another search starts, it will use the second pool, while finder is still displaying
// the old results using the first pool.
// When the second search finishes, it will replace the old results with the new results
// and reset the old pool, making it available for the next search.
// This way we avoid any copying of data, which we would have to do with just 1 pool.
memory_pools: [2] Flat_Pool;
available_pool_index := 0;

thread_group: Thread_Group;

#scope_file

File_Async :: #import "File_Async";
