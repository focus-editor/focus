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
        case .cut;                      delete_selection(input, copy_to_clipboard = true);
        case .paste;                    paste(input);
        case .undo;                     undo(input);
        case .redo;                     redo(input);
        case .select_word;              select_word(input);
        case .select_all;               select_all(input);
        case .move_left;                move_cursor_left(input,  by = .char,      extend_selection);
        case .move_left_by_word;        move_cursor_left(input,  by = .word,      extend_selection);
        case .move_left_by_word_ends;   move_cursor_left(input,  by = .word_ends, extend_selection);
        case .move_right;               move_cursor_right(input, by = .char,      extend_selection);
        case .move_right_by_word;       move_cursor_right(input, by = .word,      extend_selection);
        case .move_right_by_word_ends;  move_cursor_right(input, by = .word_ends, extend_selection);
        case .jump_to_line_start; #through;
        case .jump_to_file_start;       move_home(input, extend_selection);
        case .jump_to_line_end; #through;
        case .jump_to_file_end;         move_end (input, extend_selection);
        case .delete_left_char;         delete_left_char (input);
        case .delete_right_char;        delete_right_char(input);
        case .delete_word_left;         delete_word_left(input);
        case .delete_word_right;        delete_word_right(input);
        case .delete_to_start_of_line;  delete_to_start_of_line(input);
        case .delete_to_end_of_line;    delete_to_end_of_line(input);
        case;                           return false;
    }

    if old_text != to_string(text) then last_edit_time = frame_time;

    return true;
}

text_input_type_char :: (using input: *Text_Input, char: u32) {
    if key_sequence_input_state.key_sequence_in_progress  return;

    if edits.count == 0 {
        // Always remember cursor before any edits
        cursor_before_edits = cursor;
    } else {
        // If we're replacing any selection, we always want a new edit group
        if has_selection(cursor) || frame_time - last_edit_time >= EDIT_GROUP_TIMEOUT then new_edit_group(input);
    }

    cursor.pos = clamp(cursor.pos, 0, xx text.count);  // make sure cursor is in the correct position
    cursor.sel = clamp(cursor.sel, 0, xx text.count);

    utf8_char := convert_utf32_to_utf8(char);
    if !has_selection(cursor) {
        // No selection
        new_insert_char_edit(input, cursor.pos, utf8_char);
        insert_string_raw(input, cursor.pos, to_string(*utf8_char));
    } else {
        // Selection
        left  := min(cursor.pos, cursor.sel);
        right := max(cursor.pos, cursor.sel);
        replace_range(input, left, right, to_string(*utf8_char));
    }
    cursor.pos = min(cursor.pos, cursor.sel) + utf8_char.count;
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

get_selected_offsets :: inline (cursor: Text_Input.Cursor) -> left: s64, right: s64 {
    left  := min(cursor.sel, cursor.pos);
    right := max(cursor.sel, cursor.pos);
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

select_all :: (using input: *Text_Input) {
    cursor.pos = 0;
    cursor.sel = xx text.count;
}

select_word :: (using input: *Text_Input) {
    pos       := cursor.pos;
    pos_left  := ifx cursor.pos > 0 then prev_char_offset(text, pos) else 0;
    char      := get_char_at_offset(input, pos);
    char_left := get_char_at_offset(input, pos_left);

    if !is_word_char(char) && is_word_char(char_left) {
        pos  = pos_left;  // favor the word to the left
        char = char_left;
    }

    char_type := get_char_type(char);
    if char_type == .other return;

    cursor.pos = scan_through_similar_chars_on_the_right(input, pos, char_type, skip_one_space = false);
    cursor.sel = scan_through_similar_chars_on_the_left (input, pos, char_type, skip_one_space = false);
}

replace_text :: (using input: *Text_Input, new_text: string) {
    if edits.count == 0 then cursor_before_edits = cursor;
    new_edit_group(input);
    replace_range(input, 0, text.count, new_text);
}

#scope_file

copy :: (using input: Text_Input) {
    if !has_selection(cursor) return;
    left, right := get_selected_offsets(cursor);
    os_clipboard_set_text(slice(to_string(text), left, right - left));
}

paste :: (using input: *Text_Input) {
    str := os_clipboard_get_text();
    defer free(str);

    left, right := get_selected_offsets(cursor);

    if has_selection(cursor) {
        replace_range(input, left, right, str);
    } else {
        insert_string_at_offset(input, left, str);
    }

    cursor.pos = xx (left + str.count);
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

move_cursor_left :: (using input: *Text_Input, by: enum { char; word; word_ends; }, extend_selection := false) {
    if has_selection(cursor) && !extend_selection {
        // Jump to selection edge
        cursor.pos = min(cursor.pos, cursor.sel);
        cursor.sel = cursor.pos;
    } else {
        // Move normally
        if by == {
            case .char;
                if cursor.pos > 0 {
                    cursor.pos = prev_char_offset(text, cursor.pos);
                    cursor.pos = clamp(cursor.pos, 0, xx text.count);
                }
            case .word;
                context.underscore_is_part_of_word = false;
                cursor.pos = scan_through_similar_chars_on_the_left(input, cursor.pos);
                context.underscore_is_part_of_word = true;
            case .word_ends;
                char := get_char_at_offset(input, cursor.pos);
                char_type := get_char_type(char);
                if char_type != .word then cursor.pos = scan_through_similar_chars_on_the_left(input, cursor.pos, char_type, skip_one_space = false);
                char_type = get_char_type(get_char_at_offset(input, cursor.pos));
                if char_type != .other && char != #char "\n" then cursor.pos = scan_through_similar_chars_on_the_left(input, cursor.pos);
        }
        if !extend_selection then cursor.sel = cursor.pos;
    }
}

move_cursor_right :: (using input: *Text_Input, by: enum { char; word; word_ends; }, extend_selection := false) {
    if has_selection(cursor) && !extend_selection {
        // Jump to selection edge
        cursor.pos = max(cursor.pos, cursor.sel);
        cursor.sel = cursor.pos;
    } else {
        // Move normally
        if cursor.pos < text.count {
            if by == {
                case .char;
                    cursor.pos = next_char_offset(text, cursor.pos);
                    cursor.pos = clamp(cursor.pos, 0, xx text.count);
                case .word;
                    context.underscore_is_part_of_word = false;
                    cursor.pos = scan_through_similar_chars_on_the_right(input, cursor.pos);
                    context.underscore_is_part_of_word = true;
                case .word_ends;
                    char := get_char_at_offset(input, cursor.pos);
                    char_type := get_char_type(char);
                    if char_type != .word then cursor.pos = scan_through_similar_chars_on_the_right(input, cursor.pos, char_type, skip_one_space = false);
                    char_type = get_char_type(get_char_at_offset(input, cursor.pos));
                    if char_type != .other && char != #char "\n" then cursor.pos = scan_through_similar_chars_on_the_right(input, cursor.pos);
            }
            if !extend_selection then cursor.sel = cursor.pos;
        }
    }
}

move_home :: inline (using input: *Text_Input, extend_selection := false) {
    cursor.pos = 0;
    if !extend_selection then cursor.sel = cursor.pos;
}

move_end :: inline (using input: *Text_Input, extend_selection := false) {
    cursor.pos = xx text.count;
    if !extend_selection then cursor.sel = cursor.pos;
}

delete_left_char :: inline (using input: *Text_Input) {
    if !has_selection(cursor) && cursor.pos > 0 {
        // No selection - create one
        cursor.sel = prev_char_offset(text, cursor.pos);
        cursor.sel = clamp(cursor.sel, 0, xx text.count);
    }
    delete_selection(input);
}

delete_right_char :: inline (using input: *Text_Input) {
    if !has_selection(cursor) && cursor.pos < text.count {
        // No selection - create one
        cursor.sel = next_char_offset(text, cursor.pos);
        cursor.sel = clamp(cursor.sel, 0, xx text.count);
    }
    delete_selection(input);
}

delete_word_left :: inline (using input: *Text_Input) {
    if !has_selection(cursor) then cursor.pos = scan_through_similar_chars_on_the_left(input, cursor.pos);
    delete_left_char(input);
}

delete_word_right :: inline (using input: *Text_Input) {
    if !has_selection(cursor) then cursor.pos = scan_through_similar_chars_on_the_right(input, cursor.pos);
    delete_right_char(input);
}

delete_to_start_of_line :: inline (using input: *Text_Input) {
    cursor.sel = 0;
    delete_selection(input, copy_to_clipboard = true);
}

delete_to_end_of_line :: inline (using input: *Text_Input) {
    cursor.sel = xx text.count;
    delete_selection(input, copy_to_clipboard = true);
}

delete_selection :: inline (using input: *Text_Input, copy_to_clipboard := false) {
    left, right := get_selected_offsets(cursor);
    if right > left {
        if copy_to_clipboard then os_clipboard_set_text(slice(to_string(text), left, right - left));
        delete_range(input, left, right);
    }

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

has_selection :: inline (using cursor: Text_Input.Cursor) -> bool {
    return cursor.pos != cursor.sel;
}

scan_through_similar_chars_on_the_left :: (using input: Text_Input, offset: s32, char_type: Char_Type = .none, skip_one_space := true) -> offset: s32 {
    if !text return 0;

    line_start := text.data;
    char: u32;
    t := text.data + offset;
    t, char = unicode_prev_character(t);
    if char_type != .none && char_type != get_char_type(char) return offset;
    if skip_one_space && char == #char " " && t > line_start then t, char = unicode_prev_character(t);

    if get_char_type(char) == {
        case .space;
            while t > text.data && is_space_char(char)  { t, char = unicode_prev_character(t); }
            if char != #char " " then t = unicode_next_character(t);
        case .word;
            while t > text.data && is_word_char(char) { t, char = unicode_prev_character(t); }
            if !is_word_char(char) then t = unicode_next_character(t);
        case .non_word;
            while t > text.data && is_non_word_char(char) { t, char = unicode_prev_character(t); }
            if !is_non_word_char(char) then t = unicode_next_character(t);
    }

    if t < text.data then t = text.data;

    return cast(s32) max(0, t - text.data);
}

scan_through_similar_chars_on_the_right :: (using input: Text_Input, offset: s32, only: Char_Type = .none, skip_one_space := true) -> offset: s32 {
    if !text return 0;
    if offset >= text.count return offset;  // nowhere to go

    s: string = ---;
    s.data  = *text[offset];
    s.count = (text.data + text.count) - s.data;

    char := utf8_next_character(*s);
    if only == {
        case .word;     if !is_word_char(char)     return offset;
        case .non_word; if !is_non_word_char(char) return offset;
        case .space;    if  char != #char " "      return offset;
    }
    if skip_one_space && char == #char " " && s then char = utf8_next_character(*s);

    if char == #char " " {
        // Only spaces
        while s && char == #char " "  { char = utf8_next_character(*s); }
        if char != #char " " { s.data, char = unicode_prev_character(s.data); }
    } else if is_word_char(char) {
        // Only word chars
        while s && is_word_char(char) { char = utf8_next_character(*s); }
        if !is_word_char(char) { s.data, char = unicode_prev_character(s.data); }
    } else if char != #char "\n" {
        // Only non-word chars
        while s && is_non_word_char(char) { char = utf8_next_character(*s); }
        if !is_non_word_char(char) { s.data, char = unicode_prev_character(s.data); }
    }

    return cast(s32) min(text.count, s.data - text.data);
}

get_char_at_offset :: (using input: Text_Input, offset: s32) -> u32 {
    str := get_char_at_offset_as_string(input, offset);
    if !str return 0;

    char := utf8_next_character(*str);
    return char;
}

get_char_at_offset_as_string :: (using input: Text_Input, offset: s32) -> string {
    if offset >= text.count return "";
    char: string = ---;
    char.data  = *text[offset];
    char.count = 1 + trailingBytesForUTF8[text[offset]];
    return char;
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
