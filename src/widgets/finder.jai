init_finder :: () {
    num_cpus := clamp(get_number_of_processors(), 2, 200);
    #if (OS == .WINDOWS) || (OS == .LINUX) {
        num_cpus /= 2; // this routine reports hyperthreads, so, divide by two, because of Intel marketing.
    }
    
    init(*thread_group, num_threads = max(num_cpus - 1, 1), group_proc = search_threadproc);
    thread_group.name = "Finder";
    thread_group.logging = false;
    
    start(*thread_group);
    
    finder.initted = true;
}

finder_handle_event :: (event: Input.Event) {
    if event.type == {
        case .KEYBOARD;
            if event.key_pressed {
                if event.key_code == {
                    case .ESCAPE;   finder_close(); return;
                    case #char "P"; if only_ctrl_pressed(event.modifier_flags) { show_open_file_dialog(); return; }
                }
                finder_handle_key_press(event.key_code, event.modifier_flags);
            }

        case .TEXT_INPUT;
            finder_handle_text_input(event.utf32);
    }
}

finder_handle_key_press :: (key_code: Input.Key_Code, mods: Mods) {
    using finder;

    handled := text_input_handle_keypress(*input, key_code, mods);
    if handled {
        start_new_search();
        return;
    }

    if key_code == {
        // case #char "L";    if only_ctrl_shift_pressed(mods) toggle_enlarged();
        case .ENTER;       finder_open_selected_result(on_the_side = only_ctrl_pressed(mods));
        // case .ARROW_UP;    move_cursor_up  (jump_by_file = only_ctrl_pressed(mods));
        // case .ARROW_DOWN;  move_cursor_down(jump_by_file = only_ctrl_pressed(mods));
        // case .PAGE_UP;     move_cursor_up  (jump_by_file = true);
        // case .PAGE_DOWN;   move_cursor_down(jump_by_file = true);
        // case .TAB;         if only_shift_pressed(mods) then move_cursor_up(); else move_cursor_down();
    }
    
    start_new_search();
}

finder_handle_text_input :: (char: u32) {
    if char == 127 return;  // there seems to be a bug in the Input module
                            // which generates a TEXT_INPUT event for DEL
                            // when Ctrl+Backspace is pressed

    text_input_type_char(*finder.input, char);
    start_new_search();
}

finder_open :: () {
    active_global_widget = .finder;
    using finder;
    input.cursor.sel = 0;
    input.cursor.pos = get_num_chars(input.text);
}

finder_close :: () {
    active_global_widget = .editors;
}

finder_open_from_editor :: () {
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
    
    finder_open();
}

finder_update :: () {

}

finder_open_selected_result :: (on_the_side := false) {
    using finder;
    // if search_in_progress return;
    // 
    // result := last_search.results[cursor.result];
    // needle := last_search.needle;
    // 
    // active_global_widget = .editors;
    // shrink_if_enlarged();
    // 
    // old_layout := editors_layout;    
    // editors_open_file(result.file.full_path, on_the_side = on_the_side);

    // // Select the search result
    // editor, buffer := get_active_editor_and_buffer();

    // // We search in buffer again and try to select the result we want (provided it hasn't changed).
    // // This is because while we search the file may have CRLF line endings, buf we strip them
    // // when we load the buffer, so if we just remember offsets they may not match, unfortunately!
    // // The easiest thing for now is to just repeat the search.
    // buffer_str := to_string(buffer.bytes);
    // found := true;
    // offset := 0;
    // for 0 .. cursor.line {
    //     if last_search.case_sensitive {
    //         offset = find_index_from_left(buffer_str, needle, start_index = offset);
    //     } else {
    //         offset = find_index_from_left_nocase(buffer_str, needle, start_index = offset);
    //     }
    //     if offset < 0 {
    //         found = false;  // probably the buffer has changed
    //         break;
    //     }
    //     offset += needle.count;
    // }
    // if found {
    //     cursor := leave_only_original_cursor(editor);
    //     cursor.sel = offset_to_pos(buffer, offset - needle.count);
    //     cursor.pos = offset_to_pos(buffer, offset);
    // }

    // editor.scroll_to_cursor = .yes;
    // if old_layout == .Single && editors_layout == .Double {
    //     // We've just opened a new editor, so need to let it know it's being opened,
    //     // so that it can use the target rect width for its scroll calculations
    //     // (otherwise it'll be too small and the scroll will not animate where expected)
    //     editor.scroll_to_cursor = .yes_new_editor;
    // }
}

#scope_file

start_new_search :: (force := false) {
    using finder;
    
    if !initted return;
    
    if !input.text {
        last_request_id += 1;
        array_reset_keeping_memory(*results);
        return;
    }
    if needle == to_string(input.text) && !force return;  // needle hasn't changed, no need to repeat
    
    free(needle);
    needle = copy_string(to_string(input.text));
    skip_table := bmh_prepare_skip_table(needle, case_sensitive = false);
        
    num_threads := thread_group.worker_info.count;
    assert(num_threads > 0);
    
    last_request_id += 1;
    buffers_per_thread := open_buffers.count / num_threads + 1;
    buffer_start_index := 0;
    
    while buffer_start_index < open_buffers.count {
        task := New(Search_Task);
        task.request_id = last_request_id;
        task.needle     = needle;
        task.skip_table = array_copy(skip_table);
        task.buffer_start_index = cast(s32) buffer_start_index;
        task.buffer_end_index   = cast(s32) min(buffer_start_index + buffers_per_thread - 1, open_buffers.count - 1);
        array_reserve(*task.results, 100);  // to avoid copying in some cases
        
        add_work(*thread_group, task);
        
        buffer_start_index += buffers_per_thread;
    }
}

search_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    task := cast(*Search_Task) work;
    // print("Thread % received new work: ================\n%\n==================================\n", thread.index, <<task);
    
    for buffer_id : task.buffer_start_index .. task.buffer_end_index {
        search_in_buffer(task, buffer_id);
    }
    
    return .CONTINUE;  // we want to reuse this thread for future searches
}

search_in_buffer :: (using task: *Search_Task, buffer_id: s32) {
    if results.count >= MAX_RESULTS_PER_WORKER return;
    
    // NOTE: should we make a per-buffer mutex or something? Otherwise we risk crashing 
    // or corrupting memory if people change buffers from under us
    buffer := *open_buffers[buffer_id];
    contents := to_string(buffer.bytes);
    
    file_end := contents.data + contents.count;
    offset := 0;
    while true {
        offset = inline bmh_find_index_from_left(contents, needle, start_index = offset, skip_table, case_sensitive = false);
        if offset < 0 break;

        result := array_add(*results);
        result.buffer_id = buffer_id;
        result.match_offset = xx offset;
        // !!!!!! TODO: add project dir index
        
        if results.count >= MAX_RESULTS_PER_WORKER break;
        
        offset += needle.count;
    }

}

#scope_export

finder: Finder;

Finder :: struct {
    initted := false;  // will be initialized when the initial workspace scan completes
    
    input: Text_Input;
    
    last_request_id: s64;
    needle: string;  // to remember what search string the results below correspond to
    results: [..] Search_Result;
    
    selected: s64;
    // selected_by_mouse: s64 = -1;  // to remember which entry the left mouse button went down on. Do we need it?
    
    scroll_y: s32;
    scroll_anim: Tween_Animation(s32);
    scroll_to_cursor: bool;
}

#scope_file

Search_Result :: struct {
    // Line numbers and boundaries will be calculated at draw time only for the visible entries
    // as they require doing an additional search in buffer.
    buffer_id:    s32;
    match_offset: s32;  
    project_dir:  s32;  // the index of the project dir (for sorting)
}

Search_Task :: struct {
    request_id: s64;    // to distinguish between different search request generations
    needle: string;
    buffer_start_index: s32;
    buffer_end_index:   s32;
    skip_table: [] s32;
    results: [..] Search_Result;
}

thread_group: Thread_Group;

MAX_RESULTS_PER_WORKER :: 2000;