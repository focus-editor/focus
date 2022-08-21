move_cursor_left :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
    pos.col -= xx ifx mods.ctrl_pressed then 5 else 1;
    if pos.col < 0 {
        if pos.line > 0 { pos.line -= 1; pos.col = buffer.lines[pos.line].num_chars; }
        else pos.col = 0;
    }
    col_wanted = pos.col;
}

move_cursor_right :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
    line_len := buffer.lines[pos.line].num_chars;
    if pos.col >= line_len && pos.line < buffer.lines.count - 1 {
        pos.line += 1;
        pos.col   = 0;
    } else if pos.col < line_len {
        pos.col += xx ifx mods.ctrl_pressed then 5 else 1;
    }
    col_wanted = pos.col;
}

move_cursor_up :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
    pos.line -= xx ifx mods.ctrl_pressed then 5 else 1;
    if pos.line < 0 then pos.line = 0;
    pos.col = col_wanted;
    line_len := buffer.lines[pos.line].num_chars;
    if pos.col > line_len {
        pos.col = line_len;
    }
}

move_cursor_down :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
    pos.line += xx ifx mods.ctrl_pressed then 5 else 1;
    if pos.line > buffer.lines.count - 1 then pos.line = cast(s32) buffer.lines.count - 1;
    pos.col = col_wanted;
    line_len := buffer.lines[pos.line].num_chars;
    if pos.col > line_len {
        pos.col = line_len;
    }
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
    } else if only_ctrl_shift_pressed(mods) {
        // Insert line above
        insert[indent] = #char "\n";
        insert_pos.col = 0;
    } else if nothing_pressed(mods) {
        // Break line
        insert[0] = #char "\n";
        indent = min(indent, pos.col);  // don't indent too much
        insert.count = indent + 1;
        pos.line += 1;
    } else {
        return; // Not a supported operation
    }
    insert_string_at_pos(buffer, insert_pos, insert);

    pos.col = indent;
    col_wanted = pos.col;
}

handle_backspace :: (using cursor: *Cursor, buffer: *Buffer, mods: Mods) {
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
    range: Range = ---;
    range.start = pos;
    range.end = pos;
    range.end.col += 1;
    buffer_delete_range(buffer, range);

    col_wanted = pos.col;
}

#scope_file

TAB_SIZE :: 4;
