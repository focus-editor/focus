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
            if active_part == .input || search_results.count == 0 {
                search_in_project(to_string(input.text));
            } else {
                open_selected_result(mods);
            }

        case .ARROW_UP;    move_cursor_up(mods);
        case .ARROW_DOWN;  move_cursor_down(mods);
        case .TAB;         if only_shift_pressed(mods) then move_cursor_up(mods); else move_cursor_down(mods);
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

activate_finder :: inline () {
    using finder;

    active_global_widget = .finder;
    finder.active_part = .input;

    // Select text when opening
    input.cursor.sel = 0;
    input.cursor.pos = get_num_chars(input.text);
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

finder: Finder;


#scope_file

open_selected_result :: (mods: Mods) {
    using finder;
    result := search_results[cursor.result];
    active_global_widget = .editors;
    shrink_if_enlarged();
    editors_open_file(result.file.full_path, on_the_side = only_ctrl_pressed(mods));

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
        offset = find_index_from_left(buffer_str, needle, start_index = offset);
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

    editor.scroll_to_cursor = true;
}

move_cursor_up :: (mods: Mods) {
    using finder.cursor;
    
    if !finder.search_results return;
    finder.active_part = .results;

    if only_ctrl_pressed(mods) {
        if line == 0 && result > 0 then result -= 1;
        line = 0;
    } else {
        if line == 0 && result > 0 {
            result -= 1;
            line = cast(s32) finder.search_results[result].lines.count - 1;
        } else if line > 0 {
            line -= 1;
        }
    }
    if result < 0 then result = 0;
    finder.scroll_to_cursor = true;
}

move_cursor_down :: (mods: Mods) {
    using finder.cursor;
    
    if !finder.search_results return;
    finder.active_part = .results;

    max_result := cast(s32) finder.search_results.count - 1;

    if only_ctrl_pressed(mods) {
        if result < max_result {
            result += 1;
            line = 0;
        } else {
            line = cast(s32) finder.search_results[result].lines.count - 1;  // jump to last line
        }
    } else if result >= 0 && result <= max_result {
        if line < finder.search_results[result].lines.count - 1 {
            line += 1;
        } else if result < max_result {
            result += 1;
            line = 0;
        }
    }
    if result < 0 then result = 0;
    finder.scroll_to_cursor = true;
}

search_in_project :: (needle: string) {
    if needle.count < 3 return;

    allocator := get_pool_allocator();
    push_allocator(allocator);

    array_reset(*finder.search_results);
    finder.total_results = 0;

    reset(*memory_pool);  // to avoid having to free each search result

    all_files: [..] File_Info;  // will be allocated from pool, no need to free

    // @Speed: probably can be sped up by not collecting everything upfront
    // and just scheduling search as we go (it takes 10ms on my machine to scan everything)
    // Also as an alternative could check out the code in count_lines_in_tree.jai,
    // maybe the code it uses to read dir entries is faster
    collect_files(project_dirs, dst = *all_files);

    queue := File_Async.initialize_queue(File_Info);
    defer File_Async.destroy_queue(queue);

    files_left_to_read := all_files.count;
    skip_table := bmh_prepare_skip_table(needle);

    for file : all_files {
        result := File_Async.read_entire_file(queue, file.full_path, file);
        if result.code == .FullQueue {
            file_info, data, success := File_Async.wait_for_completion(queue);
            if success.code == .Success {
                files_left_to_read -= 1;
                search_in_file(file_info, to_string(data), needle, skip_table);
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
            search_in_file(file_info, to_string(data), needle, skip_table);
        } else {
            log_error("Error while waiting for completion: %\n", success);
            break;
        }
    }

    // Reset scroll
    finder.scroll_y = 0;
    finder.scroll_anim.target = 0;

    finder.cursor = .{ result = -1, line = 0};
    finder.needle = copy_string(needle);

    // for result : finder.search_results {
    //     print("% =======\n", result.file.name);
    //     for line : result.lines {
    //         print("offset: %, line: '%'\n", line.global_offset, line.str);
    //     }
    // }
}

search_in_file :: (file: File_Info, contents: string, needle: string, skip_table: [] s32) {
    lines: [..] Search_Result.Line;
    
    if finder.total_results >= Finder.MAX_RESULTS return;

    file_end := contents.data + contents.count;
    offset := 0;
    while true {
        offset = inline bmh_find_index_from_left(contents, needle, start_index = offset, skip_table);
        if offset < 0 break;

        str := slice(contents, offset, needle.count);

        // Expand to left newline
        last_nonwhitespace := str.data;
        while str.data > contents.data && <<(str.data - 1) != #char "\r" && <<(str.data - 1) != #char "\n" {
            str.data  -= 1;
            str.count += 1;
            if !inline is_space(<<str.data) then last_nonwhitespace = str.data;
        }
        str.count -= last_nonwhitespace - str.data;
        str.data   = last_nonwhitespace;

        // Expand to right newline
        end := str.data + str.count;
        while end < file_end && <<end != #char "\n" {
            end += 1;
        }
        str.count = end - str.data;

        line := array_add(*lines);
        line.str = str;
        // line.global_offset = cast(s32) offset;
        line.offset_within = cast(s32) offset - cast(s32)(str.data - contents.data);
        
        finder.total_results += 1;
        if finder.total_results >= Finder.MAX_RESULTS break;

        offset += needle.count;
    }

    if lines.count > 0 {
        result := array_add(*finder.search_results);
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

    search_results: [..] Search_Result;
    needle: string;  // to remember what we searched with as the input text may change
    total_results: int;
    
    cursor: struct { result: s32; line: s32; };
    scroll_y: s32;
    scroll_anim: Tween_Animation(s32);
    scroll_to_cursor: bool;

    active_part: enum { input; results; } = .input;

    open_anim: Tween_Animation(float);

    default_openness := 0.2;  // if the user drags it then we remember it

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

get_pool_allocator :: () -> Allocator {
    a: Allocator;
    a.proc = flat_pool_allocator_proc;
    a.data = *memory_pool;
    return a;
}

memory_pool: Flat_Pool;

#scope_file

File_Async :: #import "File_Async";
