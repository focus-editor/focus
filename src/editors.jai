editors_handle_event :: (event: Input.Event) {
    mods := event.modifier_flags;

    if event.type == {
        case .KEYBOARD;
            // Maybe open/switch to other widgets
            if event.key_pressed {
                if event.key_code == {
                    case #char "P"; if only_ctrl_pressed(mods)       { show_open_file_dialog();   return; }
                    case #char "F"; if only_ctrl_shift_pressed(mods) { finder_open_from_editor(); return; }
                }
            }

            // Let the active editor handle the event
            if event.key_pressed then editors_handle_key_press  (event.key_code, mods);
                                 else editors_handle_key_release(event.key_code, mods);

        case .TEXT_INPUT;
            editors_handle_text_input(event.utf32);
    }
}

editors_handle_key_press :: (key_code: Input.Key_Code, mods: Mods) {
    editor, buffer := get_active_editor_and_buffer();
    if !editor return;

    if editor.search_bar.active {
        using editor.search_bar;
        old_search_str := copy_temporary_string(to_string(input.text));
        handled := text_input_handle_keypress(*input, key_code, mods);
        if handled && old_search_str != to_string(input.text) then search_and_update_results(editor, buffer, jump = true);

        if key_code == {
            case .ESCAPE;
                close_search_bar(editor);
            case .ENTER; #through;
            case .ARROW_DOWN;
                jump_to_next_search_result(editor, buffer);
            case .ARROW_UP;
                jump_to_prev_search_result(editor, buffer);

            // TODO: consider falling through (and closing) for some other combinations such as ctrl+z, ctrl+alt+arrows etc
        }
        return;
    }

    cursors := editor.cursors;

    cursor_moved   := false;
    keep_selection := false;
    enabled_whole_words := false;
    save_buffer := false;

    // Handle general actions (which are not associated with any cursor)
    handled := false;

    // We want to remember where cursors were before we do any edits
    if buffer.edits.count == 0 {
        array_resize(*buffer.cursors, editor.cursors.count);
        for * cursor, i : buffer.cursors { <<cursor = editor.cursors[i].state; }
    }

    if frame_time - buffer.last_edit_time >= EDIT_GROUP_TIMEOUT then new_edit_group(buffer, editor);

    if key_code == {
        case #char "W";
            if only_ctrl_pressed(mods) {
                close_current_editor();
                handled = true;
            } else if only_ctrl_shift_pressed(mods) {
                close_other_editor();
                handled = true;
            }

        case #char "F";
            if only_ctrl_pressed(mods) {
                open_search_bar(editor, buffer);
                handled = true;
            }

        case #char "D";
            if only_ctrl_pressed(mods) {
                created := maybe_create_additional_cursor(editor, buffer);
                keep_selection = true;
                if created {
                    cursor_moved = true;
                    handled = true;
                }
            }

        case #char "Z";
            if only_ctrl_pressed(mods) {
                new_edit_group(buffer, editor);
                maybe_undo(buffer, editor);
                keep_selection = true;
                cursor_moved = true;
                handled = true;
            }
            if only_ctrl_shift_pressed(mods) {
                maybe_redo(buffer, editor);
                keep_selection = true;
                cursor_moved = true;
                handled = true;
            }

        case #char "C";
            if only_alt_pressed(mods) {
                move_cursor_to_viewport_center(editor, buffer);
                cursor_moved = true;
                handled = true;
            }

        case #char "A";
            if only_ctrl_pressed(mods) {
                cursor := leave_only_original_cursor(editor);
                select_all(cursor, buffer);
                keep_selection = true;
                handled = true;
            }

        case #char "L";
            if only_ctrl_shift_pressed(mods) && editors_layout == .Double {
                editor_expanded = !editor_expanded;
                if editor_expanded {
                    editors_start_moving_splitter(ifx editor_active == editor_left then 0.9 else 0.1);
                } else {
                    editors_start_moving_splitter(0.5);  // back to center
                }
            }

        case #char "S";
            if only_ctrl_pressed(mods) {
                // Buffer will be saved at the end of the function
                save_buffer = true;
                handled = true;
            }

        case .ESCAPE;
            if search_bar_is_open(editor) {
                close_search_bar(editor);
            } else {
                cursor := leave_only_original_cursor(editor);
                remove_selection(cursor);
                cursor_moved = true;
                handled = true;
            }

        case .ARROW_LEFT;
            if only_ctrl_alt_pressed(mods) {
                switch_to_pane(.left);
                handled = true;
            } else if only_ctrl_alt_shift_pressed(mods) {
                if editor_active == editor_right then swap_panes();
                handled = true;
            }

        case .ARROW_RIGHT;
            if only_ctrl_alt_pressed(mods) {
                switch_to_pane(.right);
                handled = true;
            } else if only_ctrl_alt_shift_pressed(mods) {
                if editor_active == editor_left then swap_panes();
                handled = true;
            }

        case .ARROW_UP; #through;
        case .ARROW_DOWN;
            if only_alt_pressed(mods) {
                if !editor_smooth_scroll.active {
                    // Start smooth scrolling
                    editor_smooth_scroll.active     = true;
                    editor_smooth_scroll.started_at = frame_time;
                    editor_smooth_scroll.start_y    = editor.viewport.top;
                    editor_smooth_scroll.up         = key_code == .ARROW_UP;
                }
                handled = true;
            }

        case #char "1";
            if only_ctrl_pressed(mods) {
                switch_to_pane(.left, dup_editor = true);
                handled = true;
            }

        case #char "2";
            if only_ctrl_pressed(mods) {
                switch_to_pane(.right, dup_editor = true);
                handled = true;
            }
    }

    // Process individual cursors
    if !handled {
        cursor_delta := 0;
        buf_len := buffer.bytes.count;
        offsets := remember_cursor_offsets(editor, buffer);

        // We always want to put some actions in a separate edit group (e.g. block indent)
        new_group := false;
        for cursor : cursors { if new_edit_group_required_for_action(key_code, mods, cursor) { new_group = true; break; } }
        if new_group then new_edit_group(buffer, editor);  // do it before action

        for *cursor, i : cursors {
            // Adjust cursor if the previous cursor has changed the buffer
            new_len := buffer.bytes.count;
            if new_len != buf_len || buffer.dirty {
                recalculate_lines(buffer);
                cursor_delta += new_len - buf_len;
                cursor.pos = offset_to_pos(buffer, offsets[i].pos + cursor_delta);
                cursor.sel = offset_to_pos(buffer, offsets[i].sel + cursor_delta);
                buf_len = new_len;
            }

            // Handle keypress for cursor
            if key_code == {
                case .ARROW_LEFT;
                    move_cursor_left(cursor, buffer, mods);
                    cursor_moved = true;
                case .ARROW_RIGHT;
                    move_cursor_right(cursor, buffer, mods);
                    cursor_moved = true;

                case .ARROW_UP;
                    if only_alt_shift_pressed(mods) && cursors.count == 1 {
                        // TODO: support multiple cursors here someday too
                        move_lines_up(cursor, buffer);
                        keep_selection = true;
                    } else if only_ctrl_pressed(mods) || only_ctrl_shift_pressed(mods) {
                        move_cursor_to_empty_line(cursor, buffer, mods, .up);
                    } else {
                        move_cursor_vertically(cursor, buffer, mods, .up);
                    }
                    cursor_moved = true;
                case .ARROW_DOWN;
                    if only_alt_shift_pressed(mods) && cursors.count == 1 {
                        move_lines_down(cursor, buffer);
                        keep_selection = true;
                    } else if only_ctrl_pressed(mods) || only_ctrl_shift_pressed(mods) {
                        move_cursor_to_empty_line(cursor, buffer, mods, .down);
                    } else {
                        move_cursor_vertically(cursor, buffer, mods, .down);
                    }
                    cursor_moved = true;
                case .HOME;
                    move_cursor_home(cursor, buffer, mods);
                    cursor_moved = true;
                case .END;
                    move_cursor_end(cursor, buffer, mods);
                    cursor_moved = true;
                case .ENTER;
                    handle_enter(cursor, buffer, mods);
                    cursor_moved = true;
                case .BACKSPACE;
                    handle_backspace(cursor, buffer, mods);
                    cursor_moved = true;
                case .DELETE;
                    handle_delete(cursor, buffer, mods);
                    cursor_moved = true;
                case .PAGE_UP;
                    move_cursor_by_page(cursor, buffer, mods, .up);
                    cursor_moved = true;
                case .PAGE_DOWN;
                    move_cursor_by_page(cursor, buffer, mods, .down);
                    cursor_moved = true;
                case .TAB;
                    keep_selection = handle_tab(cursor, buffer, mods);
                    cursor_moved = true;

                case #char "D";
                    if only_ctrl_shift_pressed(mods) && cursors.count == 1 {
                        duplicate_lines(cursor, buffer);
                        keep_selection = true;
                        cursor_moved = true;
                    } else if only_ctrl_pressed(mods) && !has_selection(cursor) {
                        select_word(cursor, buffer);
                        editor.search_whole_words = true;
                        enabled_whole_words = true;
                        cursor_moved = true;
                    }

                case #char "C";
                    if only_ctrl_pressed(mods) {
                        copy_selection_to_clipboard(cursor, buffer, cursors.count == 1);
                    }

                case #char "X";
                    if only_ctrl_pressed(mods) {
                        copy_selection_to_clipboard(cursor, buffer, cursors.count == 1, cut = true);
                        cursor_moved = true;
                    }

                case #char "V";
                    if only_ctrl_pressed(mods) {
                        all_clipboards_empty := true;
                        for c : cursors { if c.clipboard { all_clipboards_empty = false; break; } }
                        range := paste_from_clipboard(cursor, buffer, cursors.count == 1 || all_clipboards_empty);
                        add_paste_animation(editor, range);
                        cursor_moved = true;
                    }

                case #char "L";
                    if only_ctrl_pressed(mods) {
                        select_lines(cursor, buffer);
                        keep_selection = true;
                        cursor_moved = true;
                    }

                case #char "/";
                    if only_ctrl_pressed(mods) {
                        if buffer.lang == .Jai {
                            comment_block(cursor, buffer);
                        }
                        keep_selection = true;
                        cursor_moved = true;
                    }
            }
        }

        if new_group then new_edit_group(buffer, editor);  // do it after action
    }

    if !mods.shift_pressed && cursor_moved && !keep_selection {
        for *cursor : cursors { remove_selection(cursor); }
    }
    if cursor_moved && !enabled_whole_words then editor.search_whole_words = false;

    if buffer.dirty recalculate_lines(buffer);
    if buffer.was_dirty_during_frame {
        // We have to check if buffer was dirty during frame, because we have to unmark it
        // as dirty before calculating offsets/positions sometimes, in which case
        // it will reach this code not dirty but this code still needs to execute
        buffer.was_dirty_during_frame = false;

        buffer.needs_coloring = true;
        buffer.modified = true;
        buffer.last_edit_time = frame_time;

        array_reset_keeping_memory(*editor.highlights);

        if search_bar_is_open(editor) search_and_update_results(editor, buffer);

        // Make sure the cursors in all editors for this buffer are in valid places
        for *e : open_editors {
            if e.buffer_id != editor.buffer_id continue;
            for *cursor : e.cursors { put_cursor_in_valid_spot(cursor, buffer); }
            if e != editor && e.cursors.count > 1 then organise_cursors(e);
        }
    }
    if cursors.count > 1 then organise_cursors(editor);  // sort and maybe merge overlapping cursors
    if cursor_moved then array_reset_keeping_memory(*editor.highlights);

    if save_buffer && buffer.has_file {
        // Handle save last so that the buffer is not marked as modified
        new_edit_group(buffer, editor);
        // TODO:
        // - strip trailing whitespace
        // - recalculate lines
        // - adjust cursors
        save_buffer_to_disk(buffer);
    }

    editor.cursor_moved = cursor_moved;
}

editors_handle_key_release :: (key_code: Input.Key_Code, mods: Mods) {
    if key_code == {
        case .ARROW_UP; #through;
        case .ARROW_DOWN;
            editor_smooth_scroll.active = false;
    }
}

editors_handle_text_input :: (char: u32) {
    if char == 127 return;  // there seems to be a bug in the Input module
                            // which generates a TEXT_INPUT event for DEL
                            // when Ctrl+Backspace is pressed

    editor, buffer := get_active_editor_and_buffer();
    if !editor return;

    if editor.search_bar.active {
        text_input_type_char(*editor.search_bar.input, char);
        search_and_update_results(editor, buffer, jump = true);
        return;
    }

    utf8_char := convert_utf32_to_utf8(char);

    if buffer.edits.count == 0 {
        // We want to remember where cursors were before we do any edits
        array_resize(*buffer.cursors, editor.cursors.count);
        for * cursor, i : buffer.cursors { <<cursor = editor.cursors[i].state; }
    } else {
        // We always want to remember cursor state when a selection is replaced with anything
        new_group := false;
        for editor.cursors { if has_selection(it) { new_group = true; break; } }
        if new_group || frame_time - buffer.last_edit_time >= EDIT_GROUP_TIMEOUT {
            new_edit_group(buffer, editor);
        }
    }

    cursor_delta := 0;
    buf_len := buffer.bytes.count;
    offsets := remember_cursor_offsets(editor, buffer);

    for *cursor, i : editor.cursors {
        // Adjust cursor if the previous cursor has changed the buffer
        new_len := buffer.bytes.count;
        if new_len != buf_len || buffer.dirty {
            recalculate_lines(buffer);
            cursor_delta += new_len - buf_len;
            cursor.pos = offset_to_pos(buffer, offsets[i].pos + cursor_delta);
            cursor.sel = offset_to_pos(buffer, offsets[i].sel + cursor_delta);
            buf_len = new_len;
        }

        if has_selection(cursor) {
            str := to_string(*utf8_char);
            selection := get_selection(cursor);
            replace_range(buffer, selection, str);
            cursor.pos = selection.start;
        } else {
            insert_char_at_pos(buffer, cursor.pos, utf8_char);
        }
        cursor.pos.col += 1;  // we know it's just one symbol
        cursor.col_wanted = cursor.pos.col;
        remove_selection(cursor);
    }

    if buffer.dirty then recalculate_lines(buffer);

    array_reset_keeping_memory(*editor.highlights);
    if search_bar_is_open(editor) search_and_update_results(editor, buffer);

    editor.cursor_moved = true;
    buffer.modified = true;
    buffer.needs_coloring = true;
    buffer.last_edit_time = frame_time;
}

get_active_editor_and_buffer :: () -> *Editor, *Buffer {
    if editors_layout == .None return null, null;
    editor := *open_editors[editor_active];
    buffer := *open_buffers[editor.buffer_id];
    return editor, buffer;
}

editors_open_file :: (path: string, on_the_side := false) {
    full_path := get_absolute_path(path);
    buffer_id := find_or_create_buffer(full_path);

    editors_open_buffer(buffer_id, on_the_side);
}

editors_open_buffer :: (buffer_id: s64, on_the_side := false) {
    if #complete editors_layout == {
        case .None;
            editor_active = find_or_create_editor(buffer_id);
            editors_layout = .Single;

        case .Single;
            if !on_the_side {
                // Open in place
                editor_active  = find_or_create_editor(buffer_id);
            } else {
                // Open on the right
                editor_right   = find_or_create_editor(buffer_id, editor_active);
                editor_left    = editor_active;
                editor_active  = editor_right;
                editors_layout = .Double;
                editors_start_moving_splitter(0.5, start = 1.0);
            }

        case .Double;
            on_the_right := on_the_side;
            if editor_active == editor_right then on_the_right = !on_the_right;

            if on_the_right {
                // Open on the right (obviously)
                editor_right = find_or_create_editor(buffer_id, editor_left);
                editor_active = editor_right;
            } else {
                // Open on the left
                editor_left = find_or_create_editor(buffer_id, editor_right);
                editor_active = editor_left;
            }
    }
}

move_viewport :: (editor: *Editor, dir: enum { left; up; right; down; }) {
    using editor.viewport;
    if dir == {
        case .left; #through;
        case .right;
            horiz_delta := cast(s32) (10 * char_size);
            new_target := ifx dir == .left then scroll_x.target - horiz_delta else scroll_x.target + horiz_delta;
            if new_target < 0 then new_target = 0;
            start_animation(*scroll_x, left, new_target);

        case .up; #through;
        case .down;
            vert_delta := cast(s32) (10 * line_height);
            new_target := ifx dir == .up then scroll_y.target - vert_delta else scroll_y.target + vert_delta;
            new_target = clamp(new_target, 0, get_max_y_scroll(open_buffers[editor.buffer_id]));
            start_animation(*scroll_y, top, new_target);
    }
}

move_cursor_to_viewport_center :: (editor: *Editor, buffer: Buffer) {
    cursor := leave_only_original_cursor(editor);
    // We assume that editors always take up most of the screen vertically.
    // If that ever changes we'll need to change this code (and do it when we know the layout)
    cursor_px_pos := editor.viewport.top +  window_height / 2;
    cursor.pos.line = xx (cursor_px_pos / line_height);
    cursor.pos.col = 0;
    cursor.pos = make_valid_pos(buffer, cursor.pos);
    remove_selection(cursor);
}

leave_only_original_cursor :: (using editor: *Editor) -> *Cursor {
    // Remove all cursors except the original one
    for *cursor : cursors {
        maybe_free_and_clear(*cursor.clipboard);
    }
    cursor := cursors[original_cursor];
    cursors.count = 1;
    original_cursor = 0;
    main_cursor = 0;
    cursors[original_cursor] = cursor;
    return *cursors[original_cursor];
}

remember_cursor_offsets :: (using editor: *Editor, buffer: Buffer) -> []Cursor_Offsets /* temporary storage */ {
    // When editing with multiple cursors it's convenient to remember where cursors
    // are in the buffer before we start so we can then easily adjust their positions later
    offsets := NewArray(cursors.count, Cursor_Offsets, initialized = false, allocator = temp);
    for cursor, i : cursors {
        offsets[i].pos = pos_to_offset(buffer, cursor.pos);
        offsets[i].sel = pos_to_offset(buffer, cursor.sel);
    }
    return offsets;
}

organise_cursors :: (using editor: *Editor) {
    compare_cursors :: (c1: Cursor, c2: Cursor) -> s64 {
        s1 := get_selection(c1);
        s2 := get_selection(c2);
        if s1.start < s2.start return -1;
        if s2.start < s1.start return  1;
        return 0;
    }

    maybe_subsume :: (c1: *Cursor, c2: Cursor) -> bool {
        s1 := get_selection(c1);
        s2 := get_selection(c2);
        if s1.end < s2.start || s2.end < s1.start return false;  // cursors are disjoint

        new_start := ifx s1.start < s2.start then s1.start else s2.start;  // for some reason min() didn't work
        new_end   := ifx s1.end   < s2.end   then s2.end   else s1.end;    // max()

        if c1.pos == s1.end || c2.pos == s2.end {
            c1.sel = new_start;
            c1.pos = new_end;
        } else {
            c1.pos = new_start;
            c1.sel = new_end;
        }

        return true;
    }

    main_cursor_pos     := cursors[main_cursor].pos;
    original_cursor_pos := cursors[original_cursor].pos;

    quick_sort(cursors, compare_cursors);

    // Adjust main and original cursor indices because they could've moved
    for cursor, i : cursors {
        if cursor.pos == main_cursor_pos     then main_cursor = i;
        if cursor.pos == original_cursor_pos then original_cursor = i;
    }

    // Merge overlapping cursors
    i := 0;
    while (i < cursors.count - 1) {
        cursor := *cursors[i];
        if maybe_subsume(cursor, cursors[i+1]) {
            array_ordered_remove_by_index(*cursors, i+1);
            if main_cursor     > i then main_cursor -= 1;
            if original_cursor > i then original_cursor -= 1;
        } else {
            i += 1;
        }
    }
}

get_max_y_scroll :: (buffer: Buffer) -> s32 {
    assert(!buffer.dirty);
    return max(cast(s32) ((buffer.lines.count - 1)  * line_height), 0);
}

add_paste_animation :: (using editor: *Editor, range: Range) {
    anim := array_add(*paste_animations);
    anim.range = range;
    anim.started_at = frame_time;
}

select_word :: (using cursor: *Cursor, buffer: Buffer) {
    // Decode the characters on the line for scanning
    chars := get_temp_unicode_chars_for_line(buffer, pos.line, max_char = 5000);  // arbitrary limit
    if !chars return;  // empty line

    col := -1;
    if is_word_char(chars[pos.col]) {
        col = pos.col;
    } else if pos.col > 0 && is_word_char(chars[pos.col - 1]) {
        col = pos.col - 1;
    } else {
        return;  // cursor not on a word
    }

    // Go left
    start := col;
    while start >= 0 {
        if !is_word_char(chars[start]) then { start += 1; break; }
        start -= 1;
    }
    if start < 0 then start = 0;

    // Go right
    end := col + 1;
    while end < chars.count - 1 && is_word_char(chars[end]) { end += 1; }

    assert(start <= end);
    sel.col = xx start;
    pos.col = xx end;
}

get_selected_text_all_cursors :: (using editor: Editor, buffer: Buffer) -> string {  // returns view into buffer
    // Returns a selected string only if all cursors have the same text selected.
    // Otherwise returns an empty string.
    empty: string;

    text := get_selected_string(cursors[main_cursor], buffer);
    if text.count == 0 return empty;

    for cursor : cursors {
        if text != get_selected_string(cursor, buffer) return empty;
    }

    return text;
}

new_edit_group :: (buffer: *Buffer, editor: *Editor) {
    if buffer.edits.count == 0 return;

    new_group := array_add(*buffer.undos);
    new_group.edits = to_owned_array(*buffer.edits);  // @Speed: could group all char inserts into one if needed
    new_group.cursors = to_owned_array(*buffer.cursors);

    // Remember cursor state
    array_resize(*buffer.cursors, editor.cursors.count);
    for * cursor, i : buffer.cursors { <<cursor = editor.cursors[i].state; }
}

close_current_editor :: () {
    if editors_layout == {
        case .None;     return;
        case .Single;   editors_layout = .None;  // close immediately
        case .Double;
            // Start the animation (the layout will change when the animation is finished)
            if editor_active == editor_left {
                editors_start_moving_splitter(0.0);  // close left
                editor_active = editor_right;
            } else {
                editors_start_moving_splitter(1.0);  // close right
                editor_active = editor_left;
            }
            editor_closing = true;
    }
}


close_other_editor :: () {
    if editors_layout == {
        case .None;     return;
        case .Single;   return;  // don't do anything
        case .Double;
            // Start the animation (the layout will change when the animation is finished)
            if editor_active == editor_left {
                editors_start_moving_splitter(1.0);  // close right
            } else {
                editors_start_moving_splitter(0.0);  // close left
            }
            editor_closing = true;
    }
}

finish_closing_editor :: () {
    if editors_layout == .Double then editors_layout = .Single;
    editor_closing = false;
}

search_bar_is_open :: inline (using editor: *Editor) -> bool {
    return search_bar.openness > 0.0 || search_bar.active;
}

open_search_bar :: (using editor: *Editor, buffer: Buffer) {
    using editor.search_bar;
    active = true;

    // If there was some text selected that doesn't span more than one line, use it for search
    if cursors.count == 1 {
        cursor := cursors[0];
        selected_text := get_selected_string(cursor, buffer);
        if selected_text && cursor.sel.line == cursor.pos.line {
            array_resize(*input.text, selected_text.count);
            memcpy(input.text.data, selected_text.data, selected_text.count);
        }
    }

    // Select text when opening
    input.cursor.sel = 0;
    input.cursor.pos = get_num_chars(input.text);

    search_point_offset = pos_to_offset(buffer, get_selection(cursors[main_cursor]).start);

    search_and_update_results(editor, buffer);

    start_animation(*open_anim, openness, 1.0, speed = xx 0.2);
}

close_search_bar :: inline (editor: *Editor) {
    using editor.search_bar;
    active = false;  // stop receiving input immediately

    reset_search_results(*editor.search_bar);
    array_reset_keeping_memory(*editor.highlights);

    start_animation(*open_anim, openness, 0.0, speed = xx 0.2);
}

search_and_update_results :: (using editor: *Editor, buffer: Buffer, jump := false) {
    reset_search_results(*search_bar);

    using search_bar;
    needle := to_string(input.text);
    if !needle return;

    buffer_str := to_string(buffer.bytes);

    // Use Boyer-Moore-Horspool to search
    assert(buffer_str.count < S32_MAX && needle.count < S32_MAX);
    skip_table := bmh_prepare_skip_table(needle, case_sensitive = false);
    offset := 0;
    i := 0;
    while true {
        offset = inline bmh_find_index_from_left(buffer_str, needle, start_index = offset, skip_table, case_sensitive = false);
        if offset < 0 break;

        result := array_add(*results);
        result.offset = offset;
        result.start_pos = offset_to_pos(buffer, offset);
        if selected_result < 0 && result.offset >= search_point_offset then selected_result = i;

        offset += needle.count;
        i += 1;
    }

    if selected_result < 0 && i > 0 then selected_result = i - 1;  // all results are before cursor, select the closes one
    if selected_result >= 0 && jump then jump_to_search_result(editor, buffer);
}

jump_to_search_result :: (using editor: *Editor, buffer: Buffer, move_search_point := false) {
    using search_bar;
    if !results || selected_result < 0 return;

    result := results[selected_result];
    cursor := leave_only_original_cursor(editor);
    cursor.sel = result.start_pos;
    cursor.pos = offset_to_pos(buffer, result.offset + input.text.count);
    scroll_to_cursor = .yes;

    if move_search_point then search_point_offset = xx result.offset;
}

jump_to_prev_search_result :: (using editor: *Editor, buffer: Buffer) {
    using search_bar;
    if !results return;
    selected_result -= 1;
    if selected_result < 0 then selected_result = results.count - 1;
    jump_to_search_result(editor, buffer, move_search_point = true);
}

jump_to_next_search_result :: (using editor: *Editor, buffer: Buffer) {
    using search_bar;
    if !results return;
    selected_result = (selected_result + 1) % results.count;
    jump_to_search_result(editor, buffer, move_search_point = true);
}

reset_search_results :: (using search_bar: *Search_Bar) {
    array_reset(*results);
    selected_result = -1;
}

editors_snap_splitter :: (pos: float) {
    pos = clamp(pos, 0.1, 0.9);
    splitter_pos = pos;
    splitter_anim.target = pos;
}

editors_start_moving_splitter :: (target: float, start := -1.0) {
    if start >= 0 then splitter_pos = start;
    start_animation(*splitter_anim, splitter_pos, target, snappy = true);
    redraw_requested = true;
}

init_buffers :: () {
    // 3000 * 70% = 2100 is a reasonable number of text files in a workspace, which 
    // most codebases will hopefully not exceed (so that we don't have to grow the hash table)
    init(*buffers_table, slots_to_allocate = 3000);
}

fill_in_buffer_from_file_data :: (buffer: *Buffer, path: string, file_data: string) {
    for project_dirs {
        if begins_with_nocase(path, it.path) {
            buffer.project_dir_index = cast(u8)it_index;
        }
    }
    buffer.file = get_file_info_from_full_path(path);
    buffer.has_file = true;
    remember_last_modtime_and_size(buffer);
    
    buffer.bytes = resizable(to_bytes(file_data));
    remove_crlf(buffer);

    if ends_with_nocase(path, ".jai") {
        buffer.lang = .Jai;
    } else if ends_with(path, "LOG.md") {
        buffer.lang = .Worklog;
    }

    recalculate_lines(buffer);
    recalculate_colors(buffer);
}

#scope_file

maybe_create_additional_cursor :: (using editor: *Editor, buffer: Buffer) -> created: bool {
    selected_text := get_selected_text_all_cursors(editor, buffer);
    if selected_text.count == 0 return false;
    buffer_str := to_string(buffer.bytes);

    search_func: (s: string, substring: string, start_index := 0) -> s64;
    search_func = ifx search_whole_words then find_index_from_left_whole_word else find_index_from_left;

    // Search from the main cursor downwards, possibly with a wraparound
    start_offset := pos_to_offset(buffer, get_selection(cursors[main_cursor]).end);
    found_offset := -1;
    if main_cursor == cursors.count - 1 {
        // Main cursor is last - search with a wraparound
        end_offset  := pos_to_offset(buffer, get_selection(cursors[0]).start);
        before_wrap := slice(buffer_str, start_offset, buffer_str.count - start_offset);
        after_wrap  := slice(buffer_str, 0, end_offset);

        index := search_func(before_wrap, selected_text);
        if index >= 0 then found_offset = start_offset + index;
        if found_offset < 0 then found_offset = search_func(after_wrap, selected_text);
    } else {
        // Main cursor is not last - search until the next cursor only
        end_offset := pos_to_offset(buffer, get_selection(cursors[main_cursor+1]).start);
        target_range := slice(buffer_str, start_offset, end_offset - start_offset);
        index := search_func(target_range, selected_text);
        if index >= 0 then found_offset = start_offset + index;
    }
    if found_offset < 0 {
        if main_cursor != original_cursor {
            main_cursor = original_cursor;  // go back to original and stop
            return true;  // make sure we jump to it
        }
        return false;  // found no matches
    }

    new_cursor := array_add(*cursors);
    new_cursor.sel = offset_to_pos(buffer, found_offset);
    new_cursor.pos = offset_to_pos(buffer, found_offset + selected_text.count);
    main_cursor = cursors.count - 1;

    return true;
}

switch_to_pane :: (side: enum { left; right; }, dup_editor := false) {
    if editors_layout == {
        case .None; return;

        case .Single;
            if !dup_editor return;
            current_editor := *open_editors[editor_active];
            new_editor := find_or_create_editor(current_editor.buffer_id, editor_active);
            if side == .left {
                editor_left   = new_editor;
                editor_right  = editor_active;
                editor_active = editor_left;
                editors_start_moving_splitter(0.5, start = 0.0);
            } else {
                editor_left   = editor_active;
                editor_right  = new_editor;
                editor_active = editor_right;
                editors_start_moving_splitter(0.5, start = 1.0);
            }
            editors_layout = .Double;

        case .Double;
            editor_active = ifx side == .left then editor_left else editor_right;
    }
}

swap_panes :: () {
    if editors_layout != .Double return;
    editor_left, editor_right = swap(editor_left, editor_right);
}

find_or_create_editor :: (buffer_id: s64, existing_editor: s64 = -1) -> editor_id: s64 {
    assert(buffer_id >= 0 && buffer_id < open_buffers.count, "Attempt to create editor for nonexistent buffer");
    for open_editors {
        if it.buffer_id == buffer_id && it_index != existing_editor return it_index;
    }
    editor_id := open_editors.count;
    editor := array_add(*open_editors);
    editor.buffer_id = buffer_id;
    array_add(*editor.cursors, Cursor.{});
    return editor_id;
}

maybe_undo :: (buffer: *Buffer, editor: *Editor) {
    if buffer.undos.count == 0 return;
    edit_group := pop(*buffer.undos);
    // Revert edits in the backwards order
    for < e : edit_group.edits {
        if #complete e.type == {
            case .delete;  using e.delete;  insert_string_raw(buffer, offset_range.start, old_bytes);
            case .replace; using e.replace; replace_range_raw(buffer, offset_range.start, offset_range.start + xx new_bytes.count, old_bytes);
            case .insert;  using e.insert;  delete_range_raw (buffer, offset, offset + new_bytes.count);
            case .insert_char; using e.insert_char;  delete_range_raw (buffer, offset, offset + char.count);
        }
    }
    // Add a new redo group
    redo := array_add(*buffer.redos);
    redo.edits = edit_group.edits;
    redo.cursors = to_owned_array(*buffer.cursors);

    array_extend(*buffer.cursors, edit_group.cursors);
    restore_cursor_state(editor, edit_group.cursors);
    array_free(edit_group.cursors);
}

maybe_redo :: (buffer: *Buffer, editor: *Editor) {
    if buffer.redos.count == 0 return;
    edit_group := pop(*buffer.redos);
    // Replay edits in the normal order
    for e : edit_group.edits {
        if #complete e.type == {
            case .delete;  using e.delete;  delete_range_raw (buffer, offset_range.start, offset_range.end);
            case .replace; using e.replace; replace_range_raw(buffer, offset_range.start, offset_range.end, new_bytes);
            case .insert;  using e.insert;  insert_string_raw(buffer, offset, new_bytes);
            case .insert_char; using e.insert_char; insert_string_raw(buffer, offset, to_string(*char));
        }
    }
    // Add a new undo group
    undo := array_add(*buffer.undos);
    undo.edits = edit_group.edits;
    undo.cursors = to_owned_array(*buffer.cursors);

    array_extend(*buffer.cursors, edit_group.cursors);
    restore_cursor_state(editor, edit_group.cursors);
    array_free(edit_group.cursors);
}

restore_cursor_state :: (using editor: *Editor, cursor_state: []Cursor.State) {
    if cursor_state.count == 0 return;  // the first undo doesn't have any remembered cursors

    for * cursors maybe_free_and_clear(*it.clipboard);
    array_resize(*cursors, cursor_state.count);
    for * cursor, i : cursors {
        cursor.state = cursor_state[i];
        cursor.col_wanted = cursor.pos.col;
        cursor.clipboard.count = 0;
        cursor.clipboard.data = null;
    }
    if main_cursor >= cursors.count then main_cursor = cursors.count - 1;  // maybe we should remember it too
}

new_edit_group_required_for_action :: (key_code: Input.Key_Code, mods: Mods, cursor: Cursor) -> bool {
    // NOTE: we could abstract away actions instead of checking keys here directly, but
    // I won't do it for now because I want to avoid needless refactoring

    if key_code == {
        case .BACKSPACE; #through;
        case .DELETE;    #through; // delete range
        case .ENTER;               // replace range with newline
            if has_selection(cursor) return true;

        case .ARROW_UP; #through;
        case .ARROW_DOWN;
            if only_ctrl_alt_pressed(mods) return true;  // move lines up or down

        case .TAB;  // any indentation
            return true;

        case #char "D";
            if only_ctrl_shift_pressed(mods) return true;  // duplicate lines

        case #char "V";
            if only_ctrl_pressed(mods) return true;  // paste

        case #char "X";
            if only_ctrl_pressed(mods) return true;  // cut
    }

    return false;
}

scan_until_word_char :: (condition: bool, chars: [] u32, start: s32, direction: enum { left; right; }) -> index: s32 {
    i := start;
    if direction == .left {
        while i >= 0 {
            if is_word_char(chars[i]) == condition break;
            i -= 1;
        }
    } else {
        while i < chars.count {
            if is_word_char(chars[i]) == condition break;
            i += 1;
        }
    }
    return i;
}

move_cursor_left :: (using cursor: *Cursor, buffer: Buffer, mods: Mods) {
    if has_selection(cursor) && !mods.shift_pressed {
        pos = get_selection(cursor).start;
        remove_selection(cursor);
    } else {
        pos.col -= 1;
        if pos.col < 0 {
            if pos.line > 0 { pos.line -= 1; pos.col = buffer.lines[pos.line].num_chars; }
            else pos.col = 0;
        }
        if pos.col > 0 && (mods.ctrl_pressed || mods.alt_pressed) {
            chars := get_temp_unicode_chars_for_line(buffer, pos.line, max_char = pos.col);

            i := pos.col;
            if mods.alt_pressed {
                if is_word_char(chars[i]) {
                    i = scan_until_word_char(false, chars, i, .left);
                } else {
                    i = scan_until_word_char(true, chars, i, .left);
                }
            } else if mods.ctrl_pressed {
                // Scan until we see a word char, then a non-word char
                i = scan_until_word_char(true,  chars, i, .left);
                i = scan_until_word_char(false, chars, i, .left);
            }
            pos.col = i + 1;
            pos = make_valid_pos(buffer, pos);
        }
    }
    col_wanted = pos.col;
}

move_cursor_right :: (using cursor: *Cursor, buffer: Buffer, mods: Mods) {
    if has_selection(cursor) && !mods.shift_pressed {
        pos = get_selection(cursor).end;
        remove_selection(cursor);
    } else {
        line_len := buffer.lines[pos.line].num_chars;
        if pos.col >= line_len && pos.line < buffer.lines.count - 1 {
            pos.line += 1;
            pos.col   = 0;
        } else if pos.col < line_len {
            pos.col += 1;
            if pos.col < buffer.lines[pos.line].num_chars && (mods.ctrl_pressed || mods.alt_pressed) {
                chars := get_temp_unicode_chars_for_line(buffer, pos.line, max_char = 5000);  // arbitrary limit

                i := pos.col - 1;
                if mods.alt_pressed {
                    if is_word_char(chars[i]) {
                        i = scan_until_word_char(false, chars, i, .right);
                    } else {
                        i = scan_until_word_char(true, chars, i, .right);
                    }
                } else if mods.ctrl_pressed {
                    // Scan until we see a word char, then a non-word char
                    i = scan_until_word_char(true,  chars, i, .right);
                    i = scan_until_word_char(false, chars, i, .right);
                }
                pos.col = i;
                pos = make_valid_pos(buffer, pos);
            }
        }
    }
    col_wanted = pos.col;
}

move_cursor_vertically :: (using cursor: *Cursor, buffer: Buffer, mods: Mods, dir: enum { up; down; }) {
    if has_selection(cursor) && !mods.shift_pressed {
        selection := get_selection(cursor);
        pos = ifx dir == .up then selection.start else selection.end;
        remove_selection(cursor);
        col_wanted = pos.col;
    }
    if dir == .up {
        pos.line -= 1;
        if pos.line < 0 then pos.line = 0;
    } else {
        pos.line += 1;
        if pos.line > buffer.lines.count - 1 then pos.line = cast(s32) buffer.lines.count - 1;
    }

    pos.col = col_wanted;
    line_len := buffer.lines[pos.line].num_chars;
    if pos.col > line_len {
        pos.col = line_len;
    }
}

move_cursor_to_empty_line :: (using cursor: *Cursor, buffer: Buffer, mods: Mods, dir: enum { up; down; }) {
    if has_selection(cursor) && !mods.shift_pressed then remove_selection(cursor);

    if dir == .up {
        while pos.line > 0 {
            pos.line -= 1;
            line := buffer.lines[pos.line];
            if line.text_start == line.end break;
        }
    } else {
        while pos.line < buffer.lines.count - 1 {
            pos.line += 1;
            line := buffer.lines[pos.line];
            if line.text_start == line.end break;
        }
    }

    pos = make_valid_pos(buffer, pos);
}

move_cursor_by_page :: (using cursor: *Cursor, buffer: Buffer, mods: Mods, dir: enum { up; down; }) {
    page_size := cast(s32) (window_height / line_height);
    if dir == .up {
        pos.line -= page_size;
    } else {
        pos.line += page_size;
    }
    pos = make_valid_pos(buffer, pos);
}

move_cursor_home :: (using cursor: *Cursor, buffer: Buffer, mods: Mods) {
    text_start_col: s32= 0;
    line := buffer.lines[pos.line];
    i := line.start;
    while i < line.end {
        byte := buffer.bytes[i];
        if byte != #char " " break;
        text_start_col += 1;
        i += 1 + trailingBytesForUTF8[byte];
    }
    if pos.col > text_start_col || pos.col == 0 then pos.col = text_start_col;
    else pos.col = 0;
    col_wanted = pos.col;
}

move_cursor_end :: (using cursor: *Cursor, buffer: Buffer, mods: Mods) {
    pos.col = buffer.lines[pos.line].num_chars;
    col_wanted = pos.col;
}

handle_enter :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
    line := buffer.lines[pos.line];
    indent := line.text_start - line.start;
    insert := talloc_string(indent + 1);
    memset(insert.data, #char " ", indent + 1);

    insert_pos := pos;
    if only_ctrl_pressed(mods) {
        // Insert line below without breaking
        insert[0] = #char "\n";
        insert_pos.col = line.num_chars;
        pos.line += 1;
        insert_string_at_pos(buffer, insert_pos, insert);
    } else if only_ctrl_shift_pressed(mods) {
        // Insert line above
        insert[indent] = #char "\n";
        insert_pos.col = 0;
        insert_string_at_pos(buffer, insert_pos, insert);
    } else if nothing_pressed(mods) {
        // Break line normally
        insert[0] = #char "\n";
        indent = min(indent, pos.col);  // don't indent too much
        insert.count = indent + 1;
        if has_selection(cursor) {
            selection := get_selection(cursor);
            replace_range(buffer, selection, insert);
            pos = selection.start;
        } else {
            insert_string_at_pos(buffer, insert_pos, insert);
        }
        pos.line += 1;
    } else {
        return; // Not a supported operation
    }

    pos.col = indent;
    col_wanted = pos.col;
    sel = pos;
}

handle_backspace :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
    // Either remove the selection
    if has_selection(cursor) {
        range := get_selection(cursor);
        delete_range(buffer, range);
        pos = range.start;
        return;
    }

    // Or handle the more complex case with tabs etc
    to_prev_tabstop := pos.col % TAB_SIZE;
    if to_prev_tabstop == 0 && pos.col > 0 then to_prev_tabstop = TAB_SIZE;
    all_spaces := false;
    if to_prev_tabstop > 0 {
        left_pos := pos;
        left_pos.col -= to_prev_tabstop;
        start := pos_to_offset(buffer, left_pos);
        end   := pos_to_offset(buffer, pos);
        all_spaces = true;
        for i : start..end-1 {
            if buffer.bytes[i] != #char " " {
                all_spaces = false;
                break;
            }
        }
    }
    spaces_to_remove := ifx all_spaces then to_prev_tabstop else 1;
    range: Range = ---;
    range.start = pos;
    range.end = pos;
    range.start.col -= spaces_to_remove;
    if range.start.col < 0 {
        range.start.col = 0;
        if range.start.line > 0 {
            range.start.line -= 1;
            range.start.col   = buffer.lines[range.start.line].num_chars;
        }
    }
    delete_range(buffer, range);

    pos = range.start;
    col_wanted = pos.col;
}

handle_delete :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
    if has_selection(cursor) {
        range := get_selection(cursor);
        delete_range(buffer, range);
        pos = range.start;
    } else {
        range: Range = ---;
        range.start = pos;
        range.end = pos;
        range.end.col += 1;
        delete_range(buffer, range);
    }
    col_wanted = pos.col;
}

handle_tab :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) -> keep_selection: bool {
    spaces := "    ";
    assert(spaces.count == TAB_SIZE);

    if !has_selection(cursor) {
        // Insert tab
        to_next_tabstop := TAB_SIZE - pos.col % TAB_SIZE;
        spaces.count = to_next_tabstop;
        insert_string_at_pos(buffer, pos, spaces);
        pos.col += to_next_tabstop;
        col_wanted = pos.col;

        return false;
    }

    // We have a selection
    range := get_selection_whole_lines(cursor, buffer);
    lines := array_view(buffer.lines, range.start.line, range.end.line - range.start.line + 1);
    new_bytes: [..] u8;
    new_bytes.allocator = temp;

    if mods.shift_pressed {
        // Unindent selection
        array_reserve(*new_bytes, bytes_in_range(buffer, range));
        for line, i : lines {
            line_len := line.end - line.start;
            if i < lines.count - 1 then line_len += 1;  // include newline
            spaces_to_remove := min(TAB_SIZE, line.text_start - line.start);
            src := array_view(buffer.bytes, line.start + spaces_to_remove, line_len - spaces_to_remove);
            array_add_bytes(*new_bytes, src);

            // Adjust selection
            line_num := range.start.line + i;
            if line_num == pos.line then pos.col -= xx spaces_to_remove;
            if line_num == sel.line then sel.col -= xx spaces_to_remove;
        }
        replace_range(buffer, range, to_string(new_bytes));
    } else {
        // Indent selection
        array_reserve(*new_bytes, bytes_in_range(buffer, range) + TAB_SIZE * lines.count);
        tab := to_bytes(spaces);
        for line, i : lines {
            array_add_bytes(*new_bytes, tab);

            line_len := line.end - line.start;
            if i < lines.count - 1 then line_len += 1;  // include newline
            src := array_view(buffer.bytes, line.start, line_len);
            array_add_bytes(*new_bytes, src);
        }
        replace_range(buffer, range, to_string(new_bytes));

        // Adjust selection
        pos.col += TAB_SIZE;
        sel.col += TAB_SIZE;
    }

    col_wanted = pos.col;

    return true;
}

select_all :: (using cursor: *Cursor, buffer: Buffer) {
    sel.line = 0;
    sel.col  = 0;
    pos.line = cast(s32) buffer.lines.count - 1;
    pos.col  = buffer.lines[buffer.lines.count - 1].num_chars;
}

select_lines :: (using cursor: *Cursor, buffer: Buffer) {
    range := get_selection_whole_lines(cursor, buffer);
    sel = range.start;
    pos = range.end;
    if !last_line(buffer, pos.line) {
        pos.col = 0;
        pos.line += 1;
    }
    pos = make_valid_pos(buffer, pos);
}

duplicate_lines :: (using cursor: *Cursor, buffer: *Buffer) {
    range := get_selection(cursor);
    str   := copy_lines_to_temp_string(buffer, range);

    offset := buffer.lines[range.end.line].end;
    insert_string_at_offset(buffer, offset, tprint("\n%", str));

    num_lines := range.end.line - range.start.line + 1;
    pos.line += num_lines;
    sel.line += num_lines;
}

move_lines_up :: (cursor: *Cursor, buffer: *Buffer) {
    range := get_selection_whole_lines(cursor, buffer);
    if range.start.line == 0 return;

    // Include the last newline in the selection
    range.end.col += 1;
    range.end = make_valid_pos(buffer, range.end, for_cursor = false);

    str := copy_lines_to_temp_string(buffer, range);

    insert_pos := range.start;
    insert_pos.line -= 1;
    insert_pos.col   = 0;
    offset := pos_to_offset(buffer, insert_pos);

    delete_range(buffer, range);
    insert_string_at_offset(buffer, offset, tprint("%\n", str));

    cursor.pos.line -= 1;
    cursor.sel.line -= 1;
}

move_lines_down :: (cursor: *Cursor, buffer: *Buffer) {
    range := get_selection_whole_lines(cursor, buffer);
    if range.end.line >= buffer.lines.count - 2 return;

    // Include the last newline in the selection
    range.end.col += 1;
    range.end = make_valid_pos(buffer, range.end, for_cursor = false);

    str := copy_lines_to_temp_string(buffer, range);

    insert_pos := range.start;
    insert_pos.line += 1;
    insert_pos.col   = 0;

    delete_range(buffer, range);
    recalculate_lines(buffer);
    insert_string_at_pos(buffer, insert_pos, tprint("%\n", str));

    cursor.pos.line += 1;
    cursor.sel.line += 1;
}

copy_selection_to_clipboard :: (cursor: *Cursor, buffer: *Buffer, single_cursor: bool, cut := false) {
    selection := get_selection(cursor);
    str := get_string_from_range(selection, buffer);

    if single_cursor && str {
        // Copy to the system clipboard
        os_clipboard_set_text(str);
    } else {
        // Copy to individual cursor's clipboard
        maybe_free_and_clear(*cursor.clipboard);
        if str then cursor.clipboard = copy_string(str);
    }

    if cut {
        delete_range(buffer, selection);
        cursor.pos = selection.start;
        cursor.col_wanted = cursor.pos.col;
    }
}

paste_from_clipboard :: (cursor: *Cursor, buffer: *Buffer, use_system_clipboard: bool) -> Range {
    selection := get_selection(cursor);
    range := selection;

    str: string = ---;
    if use_system_clipboard {
        str = os_clipboard_get_text();  // don't forget to free it!
    } else {
        str = cursor.clipboard;
    }
    if str.count <= 0 return range;

    replace_range(buffer, selection, str);

    recalculate_lines(buffer);
    offset := get_offset(buffer, selection.start);
    new_cursor_pos := offset_to_pos(buffer, offset + str.count);

    cursor.pos = new_cursor_pos;
    cursor.col_wanted = new_cursor_pos.col;

    range.end = new_cursor_pos;

    if use_system_clipboard then free(str);  // maybe there's a better way to do this. Macros, maybe?

    return range;
}

comment_block :: (cursor: *Cursor, buffer: *Buffer) {
    assert(!buffer.dirty);
    range := get_selection_whole_lines(cursor, buffer);
    lines := array_view(buffer.lines, range.start.line, range.end.line - range.start.line + 1);

    min_text_start := -1;
    comment_out := false;
    for line: lines {
        if is_empty(line) {
            if min_text_start < 0 then min_text_start = 0;
            continue;
        }
        start := buffer.bytes.data + line.text_start;  // a pointer to where text starts in the line
        if !comment_out && (line.num_chars < 2 || start[0] != #char "/" || start[1] != #char "/") then comment_out = true;
        len_whitespace := line.text_start - line.start;
        if min_text_start < 0 || len_whitespace < min_text_start then min_text_start = len_whitespace;
    }
    assert(min_text_start >= 0);

    comment := "// ";
    comment_without_space := "//";
    new_bytes: [..] u8;
    new_bytes.allocator = temp;
    array_reserve(*new_bytes, range_length_in_bytes(buffer, range) + lines.count * comment.count);

    if comment_out {
        // Comment out block
        for line, i : lines {
            if !is_empty(line) {
                array_add_bytes(*new_bytes, array_view(buffer.bytes, line.start, min_text_start));
                array_add_bytes(*new_bytes, to_bytes(comment));
                array_add_bytes(*new_bytes, array_view(buffer.bytes, line.start + min_text_start, line.end - line.start - min_text_start));
            }
            if i != lines.count - 1 then array_add(*new_bytes, #char "\n");
        }

        // Only adjust cursor if after comment
        if cursor.pos.col >= min_text_start then cursor.pos.col += xx comment.count;
        if cursor.sel.col >= min_text_start then cursor.sel.col += xx comment.count;
    } else {
        // Uncomment block
        for line, i : lines {
            if !is_empty(line) {
                len_whitespace := line.text_start - line.start;
                array_add_bytes(*new_bytes, array_view(buffer.bytes, line.start, len_whitespace));
                line_text := to_string(array_view(buffer.bytes, line.text_start, line.end - line.text_start));
                chars_to_remove := 0;
                if starts_with(line_text, comment) {
                    chars_to_remove = comment.count;
                } else if starts_with(line_text, comment_without_space) {
                    chars_to_remove = comment_without_space.count;
                }
                array_add_bytes(*new_bytes, array_view(buffer.bytes, line.text_start + chars_to_remove, line.end - line.text_start - chars_to_remove));

                // Adjust cursor
                if cursor.pos.line == range.start.line + i && cursor.pos.col > len_whitespace {
                    cursor.pos.col -= min(cursor.pos.col - len_whitespace, cast(s32) chars_to_remove);
                }
                if cursor.sel.line == range.start.line + i && cursor.sel.col > len_whitespace {
                    cursor.sel.col -= min(cursor.sel.col - len_whitespace, cast(s32) chars_to_remove);
                }
            }
            if i != lines.count - 1 then array_add(*new_bytes, #char "\n");
        }
    }

    if new_bytes.count > 0 then replace_range(buffer, range, to_string(new_bytes));
}

#scope_export

Editor :: struct {
    buffer_id: s64;

    cursors: [..] Cursor;
    main_cursor: s64;      // newly added cursors become main so that we jump to them
    original_cursor: s64;  // we remember the original cursor when first creating multiple cursors (and go back to it on escape)
    search_whole_words := false;  // used when creating new cursors
    cursor_moved       := false;  // this may trigger a scroll so that the cursor is within acceptable bounds
    scroll_to_cursor: enum { no; yes; yes_new_editor; }  // trigger a scroll so that the cursor is in the center vertically

    highlights: [..] Text_Highlight;
    selected_text_length: s64;

    search_bar: Search_Bar;

    viewport: Viewport;

    paste_animations: [..] Paste_Animation;
}

Viewport :: struct {
    top:  s32;
    left: s32;
    scroll_y: Tween_Animation(s32);
    scroll_x: Tween_Animation(s32);
}

Search_Bar :: struct {
    active   := false;      // it receives keyboard input when active. TODO: should we employ a more general imgui approach here?
    openness: float = 0.0;  // 1 is fully open, 0 is fully closed
    open_anim: Tween_Animation(float);

    input: Text_Input;

    results: [..] Text_Highlight;
    selected_result: s64 = -1;
    search_point_offset: s32;  // the point used to determine the next search result. Fixed so that we can set cursor without jumping around

}

Text_Highlight :: struct {
    offset: s64;     // we'll convert this to position range, but only for the visible highlights
    start_pos: Pos;  // useful to know pos immediately to display in the scrollbar area
}

Paste_Animation :: struct {
    range: Range;
    started_at: Time;
    SPEED :: 0.5;
}

open_buffers: [..] Buffer;
open_editors: [..] Editor;
buffers_table: Table(string, s64);

editors_layout: enum {
    None;
    Single;
    Double;
} = .None;

editor_active: s64 = -1;
editor_left:   s64 = -1;
editor_right:  s64 = -1;
editor_expanded := false;  // whether the active editor should be larger
editor_closing  := false;  // whether the active editor is currently being closed (so that we can change the layout when it's done closing)

// Triggered by alt + up/down
editor_smooth_scroll: struct {
    active: bool;
    up:     bool;  // if not up, then down
    started_at: Time;
    start_y: s32;
};

splitter_pos:  float = 0.5;  // 0.5 means it's in the middle
splitter_anim: Tween_Animation(float);


#scope_file

EDIT_GROUP_TIMEOUT :: 0.3;
TAB_SIZE :: 4;

#import "Clipboard";
