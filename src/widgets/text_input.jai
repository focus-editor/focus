text_input_handle_event :: (using input: *Text_Input, event: Input.Event) -> handled: bool {
    old_text := copy_temporary_string(to_string(text));
    if edits.count == 0 {
        // Always remember cursor before any edits
        cursor_before_edits = cursor;
    }
    if frame_time - last_edit_time >= EDIT_GROUP_TIMEOUT then new_edit_group(input);

    action := map_event_to_action(event, Action_Common);
    
    extend_selection := event.shift_pressed;
    
    if action == {
        case .copy;                     copy(input);
        case .cut;                      cut(input);
        case .paste;                    paste(input);
        case .undo;                     undo(input);
        case .redo;                     redo(input);
        case .select_word;              select_word(input);
        case .select_all;               select_all(input);
        case .move_left;                move_cursor(input, -1, extend_selection);
        case .move_left_by_word;        move_cursor(input, -5, extend_selection);   // TODO 
        case .move_left_by_word_ends;   move_cursor(input, -5, extend_selection);   // TODO
        case .move_right;               move_cursor(input,  1, extend_selection);
        case .move_right_by_word;       move_cursor(input,  5, extend_selection);   // TODO
        case .move_right_by_word_ends;  move_cursor(input,  5, extend_selection);   // TODO
        case .home;                     move_home(input, extend_selection);
        case .end;                      move_end (input, extend_selection);
        case .delete_left_char;         delete_left_char (input);
        case .delete_right_char;        delete_right_char(input);
        case;                           return false;
    }
    
    if old_text != to_string(text) then last_edit_time = frame_time;

    return true;
}

text_input_type_char :: (using input: *Text_Input, char: u32) {
    if edits.count == 0 {
        // Always remember cursor before any edits
        cursor_before_edits = cursor;
    } else {
        // If we're replacing any selection, we always want a new edit group
        if cursor.pos != cursor.sel || frame_time - last_edit_time >= EDIT_GROUP_TIMEOUT then new_edit_group(input);
    }

    num_chars := get_num_chars(text);
    cursor.pos = clamp(cursor.pos, 0, num_chars);  // make sure cursor is in the correct position
    cursor.sel = clamp(cursor.sel, 0, num_chars);
    
    utf8_char := convert_utf32_to_utf8(char);
    if cursor.pos == cursor.sel {
        // No selection
        offset := get_char_offset(text, cursor.pos);
        new_insert_char_edit(input, offset, utf8_char);
        insert_string_raw(input, offset, to_string(*utf8_char));
    } else {
        // Selection
        left  := get_char_offset(text, min(cursor.pos, cursor.sel));
        right := get_char_offset(text, max(cursor.pos, cursor.sel));
        replace_range(input, left, right, to_string(*utf8_char));
    }
    cursor.pos = min(cursor.pos, cursor.sel) + 1;
    cursor.sel = cursor.pos;
    
    last_edit_time = frame_time;
}

text_input_fully_clear :: (using input: *Text_Input) {
    new_edit_group(input);
    clear_undos(input);
    clear_redos(input);
    array_reset(*text);
    cursor.pos = 0;
    cursor.sel = 0;
}

get_selected_offsets :: (text: [..] u8, cursor: Text_Input.Cursor) -> left: s64, right: s64 {
    str := to_string(text);
    left  := pos_to_offset(str, min(cursor.sel, cursor.pos));
    right := pos_to_offset(str, max(cursor.sel, cursor.pos));
    return left, right;
}

get_num_chars :: (bytes: [] u8) -> s32 {
    if !bytes return 0;
    num_chars: s32 = 0;
    i := 0;
    while i < bytes.count {
        i += 1 + trailingBytesForUTF8[bytes[i]];
        num_chars += 1;
    }
    return num_chars;
}

get_char_offset :: (bytes: [] u8, pos: s32) -> s32 {
    offset: s32 = 0;
    for i : 0..pos-1 {
        byte := bytes[offset];
        offset += 1 + trailingBytesForUTF8[byte];
    }
    return offset;
}

select_all :: (using input: *Text_Input) {
    cursor.pos = 0;
    cursor.sel = get_num_chars(text);
}

select_word :: (using input: *Text_Input) {
    // Decode the characters on the line for scanning
    chars := decode_utf8_string_to_temp_chars(to_string(text), max_char = 5000);  // arbitrary number
    if !chars return;  // empty line
    
    using cursor;

    col := -1;
    if is_word_char(chars[pos]) {
        col = pos;
    } else if pos > 0 && is_word_char(chars[pos - 1]) {
        col = pos - 1;
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
    sel = xx start;
    pos = xx end;
}

replace_text :: (using input: *Text_Input, new_text: string) {
    if edits.count == 0 then cursor_before_edits = cursor;
    new_edit_group(input);
    replace_range(input, 0, text.count, new_text);
}

#scope_file

copy :: (using input: Text_Input) {
    if cursor.pos == cursor.sel return;
    left, right := get_selected_offsets(text, cursor);
    os_clipboard_set_text(slice(to_string(text), left, right - left));
}

cut :: (using input: *Text_Input) {
    if cursor.pos == cursor.sel return;
    left, right := get_selected_offsets(text, cursor);
    os_clipboard_set_text(slice(to_string(text), left, right - left));
    if right > left then delete_range(input, left, right);
    cursor.pos = min(cursor.sel, cursor.pos);
    cursor.sel = cursor.pos;
}

paste :: (using input: *Text_Input) {
    str := os_clipboard_get_text();
    defer free(str);

    left, right := get_selected_offsets(text, cursor);

    if cursor.pos != cursor.sel {
        replace_range(input, left, right, str);
    } else {
        insert_string_at_offset(input, left, str);
    }

    cursor.pos = get_num_chars(array_view(text, 0, left + str.count));
    cursor.sel = cursor.pos;
}

undo :: (using input: *Text_Input) {
    new_edit_group(input);
    
    if undos.count == 0 return;
    edit_group := pop(*undos);
    // Revert edits in the backwards order
    for < e : edit_group.edits {
        if #complete e.type == {
            case .delete;  using e.delete;  insert_string_raw(input, offset_range.start, old_bytes);
            case .replace; using e.replace; replace_range_raw(input, offset_range.start, offset_range.start + xx new_bytes.count, old_bytes);
            case .insert;  using e.insert;  delete_range_raw (input, offset, offset + new_bytes.count);
            case .insert_char; using e.insert_char;  delete_range_raw (input, offset, offset + char.count);
        }
    }
    // Add a new redo group
    redo := array_add(*redos);
    redo.edits = edit_group.edits;
    redo.cursor = cursor;
    cursor = edit_group.cursor;
    cursor_before_edits = edit_group.cursor;
}

redo :: (using input: *Text_Input) {
    if redos.count == 0 return;
    edit_group := pop(*redos);
    // Replay edits in the normal order
    for e : edit_group.edits {
        if #complete e.type == {
            case .delete;  using e.delete;  delete_range_raw (input, offset_range.start, offset_range.end);
            case .replace; using e.replace; replace_range_raw(input, offset_range.start, offset_range.end, new_bytes);
            case .insert;  using e.insert;  insert_string_raw(input, offset, new_bytes);
            case .insert_char; using e.insert_char; insert_string_raw(input, offset, to_string(*char));
        }
    }
    // Add a new undo group
    undo := array_add(*undos);
    undo.edits = edit_group.edits;
    undo.cursor = cursor;
    cursor = edit_group.cursor;
    cursor_before_edits = edit_group.cursor;
}

move_cursor :: (using input: *Text_Input, delta: s32, extend_selection := false) {
    if cursor.pos != cursor.sel && !extend_selection {
        // Jump to selection edge
        if delta < 0 {
            cursor.pos = min(cursor.pos, cursor.sel);
        } else {
            cursor.pos = max(cursor.pos, cursor.sel);
        }
        cursor.sel = cursor.pos;
    } else {
        // Move normally
        cursor.pos += delta;
        cursor.pos = clamp(cursor.pos, 0, get_num_chars(text));
        if !extend_selection then cursor.sel = cursor.pos;
    }
}

move_home :: inline (using input: *Text_Input, extend_selection := false) {
    cursor.pos = 0;
    if !extend_selection then cursor.sel = cursor.pos;
}

move_end :: inline (using input: *Text_Input, extend_selection := false) {
    cursor.pos = get_num_chars(text);
    if !extend_selection then cursor.sel = cursor.pos;
}

delete_left_char :: inline (using input: *Text_Input) {
    if cursor.pos == cursor.sel {
        // No selection - create one
        cursor.sel = cursor.pos - 1;
        cursor.sel = clamp(cursor.sel, 0, get_num_chars(text));
    }
    delete_selection(input);
}

delete_right_char :: inline (using input: *Text_Input) {
    if cursor.pos == cursor.sel {
        // No selection - create one
        cursor.sel = cursor.pos + 1;
        cursor.sel = clamp(cursor.sel, 0, get_num_chars(text));
    }
    delete_selection(input);
}

delete_selection :: inline (using input: *Text_Input) {
    left, right := get_selected_offsets(text, cursor);
    if right > left then delete_range(input, left, right);

    cursor.pos = min(cursor.sel, cursor.pos);
    cursor.sel = cursor.pos;
}

new_edit_group :: (using input: *Text_Input) {
    if edits.count == 0 return;

    new_group := array_add(*undos);
    new_group.edits = to_owned_array(*edits);
    new_group.cursor = cursor_before_edits;
    
    cursor_before_edits = cursor;
}

insert_string_at_offset :: (using input: *Text_Input, offset: s64, new_str: string) {
    new_insert_edit(input, offset, new_str);
    insert_string_raw(input, offset, new_str);
}

replace_range :: (using input: *Text_Input, start: s64, end: s64, new_str: string) {
    old_str := to_string(array_view(text, start, end - start));
    if new_str == old_str return;
    
    new_replace_edit(input, xx start, xx end, old_str, new_str);
    replace_range_raw(input, start, end, new_str); 
}

delete_range :: (using input: *Text_Input, start: s64, end: s64) {
    old_str := to_string(array_view(text, start, end - start));
    new_delete_edit(input, xx start, xx end, old_str);
    delete_range_raw(input, start, end);
}

delete_range_raw :: (input: *Text_Input, start: s64, end: s64) {
    len := end - start;
    if len <= 0 return;

    array_delete_bytes(*input.text, start, len);
}

insert_string_raw :: (input: *Text_Input, offset: s64, str: string) {
    bytes: [] u8;
    bytes.data  = str.data;
    bytes.count = str.count;
    array_insert_bytes_at(*input.text, offset, bytes);
}

replace_range_raw :: (input: *Text_Input, start: s64, end: s64, str: string) {
    delete_range_raw(input, start, end);
    insert_string_raw(input, start, str);
}

new_replace_edit :: (input: *Text_Input, start: s32, end: s32, old_str: string, new_str: string) {
    edit := array_add(*input.edits);
    edit.type = .replace;
    using edit.replace;
    offset_range.start = start;
    offset_range.end   = end;
    new_bytes = copy_string(new_str);
    old_bytes = copy_string(old_str);

    clear_redos(input);
}

new_insert_edit :: (input: *Text_Input, offset: s64, str: string) {
    edit := array_add(*input.edits);
    edit.type = .insert;
    edit.insert.offset = offset;
    edit.insert.new_bytes = copy_string(str);

    clear_redos(input);
}

new_insert_char_edit :: (input: *Text_Input, offset: s64, char: Utf8_Char) {
    edit := array_add(*input.edits);
    edit.type = .insert_char;
    edit.insert_char.offset = offset;
    edit.insert_char.char = char;

    clear_redos(input);
}

new_delete_edit :: (input: *Text_Input, start: s32, end: s32, old_str: string) {
    edit := array_add(*input.edits);
    edit.type = .delete;
    using edit.delete;
    offset_range.start = start;
    offset_range.end   = end;
    old_bytes = copy_string(old_str);

    clear_redos(input);
}

clear_redos :: (using input: *Text_Input) {
    for * redos deinit(it);
    array_reset_keeping_memory(*redos);
}

clear_undos :: (using input: *Text_Input) {
    for * undos deinit(it);
    array_reset_keeping_memory(*undos);
}

deinit :: inline (using edit_group: *Text_Input.Edit_Group) {
    for edit : edits {
        using edit;
        if #complete type == {
            case .insert;  free(insert.new_bytes);
            case .delete;  free(delete.old_bytes);
            case .replace; free(replace.new_bytes);
                           free(replace.old_bytes);
            case .insert_char;  // nothing to free
        }
    }
    array_free(edits);
}

#scope_export

Text_Input :: struct {
    text: [..] u8;
    cursor: Cursor;
    
    undos: [..] Edit_Group;
    redos: [..] Edit_Group;
    edits: [..] Edit;
    cursor_before_edits: Cursor;
    last_edit_time: Time;
    
    scroll_x: s32;
    scroll_anim: Tween_Animation(s32);
    
    mouse_selection_mode: bool;  // to indicate the mouse is being dragged to select text

    Cursor :: struct {
        pos, sel: s32;  // cursor position (in chars, not bytes)
    }
    
    Edit_Group :: struct {
        edits: [] Edit;
        cursor: Cursor;
    }
    
    // Some copypasta from buffer, but it's ok
    Edit :: struct {
        type: enum { insert; insert_char; replace; delete; };
        union {
            insert: struct {
                offset: s64;
                new_bytes: string;
            };
            insert_char: struct {
                offset: s64;
                char: Utf8_Char;  // same as `insert`, but no need to allocate strings on the heap
                                  // it's probably the most common edit so it's worth it
            };
            replace: struct {
                offset_range: Offset_Range;
                new_bytes: string;
                old_bytes: string;
            };
            delete: struct {
                offset_range: Offset_Range;
                old_bytes: string;
            };
        }
    }
    
    Offset_Range :: struct {
        start, end: s32;  // we won't open large files anyway
    }
}
