move_cursor_left :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
    if has_selection(cursor) && !mods.shift_pressed {
        pos = get_selection(cursor).start;
        remove_selection(cursor);
    } else {
        pos.col -= xx ifx mods.ctrl_pressed then 5 else 1;
        if pos.col < 0 {
            if pos.line > 0 { pos.line -= 1; pos.col = buffer.lines[pos.line].num_chars; }
            else pos.col = 0;
        }
    }
    col_wanted = pos.col;
}

move_cursor_right :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
    if has_selection(cursor) && !mods.shift_pressed {
        pos = get_selection(cursor).end;
        remove_selection(cursor);
    } else {
        line_len := buffer.lines[pos.line].num_chars;
        if pos.col >= line_len && pos.line < buffer.lines.count - 1 {
            pos.line += 1;
            pos.col   = 0;
        } else if pos.col < line_len {
            pos.col += xx ifx mods.ctrl_pressed then 5 else 1;
        }
    }
    col_wanted = pos.col;
}

move_cursor_up :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
    if has_selection(cursor) && !mods.shift_pressed {
        pos = get_selection(cursor).start;
        remove_selection(cursor);
        col_wanted = pos.col;
    }
    pos.line -= xx ifx mods.ctrl_pressed then 5 else 1;
    if pos.line < 0 then pos.line = 0;
    pos.col = col_wanted;
    line_len := buffer.lines[pos.line].num_chars;
    if pos.col > line_len {
        pos.col = line_len;
    }
}

move_cursor_down :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
    if has_selection(cursor) && !mods.shift_pressed {
        pos = get_selection(cursor).end;
        remove_selection(cursor);
        col_wanted = pos.col;
    }
    pos.line += xx ifx mods.ctrl_pressed then 5 else 1;
    if pos.line > buffer.lines.count - 1 then pos.line = cast(s32) buffer.lines.count - 1;
    pos.col = col_wanted;
    line_len := buffer.lines[pos.line].num_chars;
    if pos.col > line_len {
        pos.col = line_len;
    }
}

move_cursor_page :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods, dir: enum { up; down; }) {
    page_size := cast(s32) (window_height / line_height);
    if dir == .up {
        pos.line -= page_size;
    } else {
        pos.line += page_size;
    }
    pos = make_valid_pos(buffer, pos);
}

move_cursor_home :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
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

move_cursor_end :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
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
        buffer_insert_string_at_pos(buffer, insert_pos, insert);
    } else if only_ctrl_shift_pressed(mods) {
        // Insert line above
        insert[indent] = #char "\n";
        insert_pos.col = 0;
        buffer_insert_string_at_pos(buffer, insert_pos, insert);
    } else if nothing_pressed(mods) {
        // Break line normally
        insert[0] = #char "\n";
        indent = min(indent, pos.col);  // don't indent too much
        insert.count = indent + 1;
        if has_selection(cursor) {
            selection := get_selection(cursor);
            buffer_replace_range(buffer, selection, insert);
            pos = selection.start;
        } else {
            buffer_insert_string_at_pos(buffer, insert_pos, insert);
        }
        pos.line += 1;
    } else {
        return; // Not a supported operation
    }

    pos.col = indent;
    col_wanted = pos.col;
}

handle_backspace :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
    // Either remove the selection
    if has_selection(cursor) {
        range := get_selection(cursor);
        buffer_delete_range(buffer, range);
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
    buffer_delete_range(buffer, range);

    pos = range.start;
    col_wanted = pos.col;
}

handle_delete :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
    if has_selection(cursor) {
        range := get_selection(cursor);
        buffer_delete_range(buffer, range);
        pos = range.start;
    } else {
        range: Range = ---;
        range.start = pos;
        range.end = pos;
        range.end.col += 1;
        buffer_delete_range(buffer, range);
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
        buffer_insert_string_at_pos(buffer, pos, spaces);
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
        buffer_replace_range(buffer, range, to_string(new_bytes));
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
        buffer_replace_range(buffer, range, to_string(new_bytes));

        // Adjust selection
        pos.col += TAB_SIZE;
        sel.col += TAB_SIZE;
    }

    col_wanted = pos.col;

    return true;
}

select_word :: (using cursor: *Cursor, buffer: Buffer) {
    assert(!buffer.dirty);

    line := buffer.lines[pos.line];
    str: string = ---;
    str.data = buffer.bytes.data + line.start;
    str.count = line.end - line.start;
    if str.count <= 0 return;  // empty line

    // @Speed: we don't need to decode the whole string (especially if it's long).
    // Instead we could scan left and right to find a space or something, and decode that
    chars := decode_utf8_string_to_temp_chars(str);
    assert(chars.count == line.num_chars + 1);

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
    buffer_insert_string_at_offset(buffer, offset, tprint("\n%", str));

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

    buffer_delete_range(buffer, range);
    buffer_insert_string_at_offset(buffer, offset, tprint("%\n", str));

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

    buffer_delete_range(buffer, range);
    recalculate_lines(buffer);
    buffer_insert_string_at_pos(buffer, insert_pos, tprint("%\n", str));

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
        buffer_delete_range(buffer, selection);
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

    buffer_replace_range(buffer, selection, str);

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

    if new_bytes.count > 0 then buffer_replace_range(buffer, range, to_string(new_bytes));
}

#scope_file

is_word_char :: (ch: u32) -> bool {
    return
        (#char "a" <= ch && ch <= #char "z") ||
        (#char "A" <= ch && ch <= #char "Z") ||
        (#char "0" <= ch && ch <= #char "9") ||
        (#char "а" <= ch && ch <= #char "я") ||
        (#char "А" <= ch && ch <= #char "Я") ||
        (ch == #char "_");
}

TAB_SIZE :: 4;

#import "Clipboard";
