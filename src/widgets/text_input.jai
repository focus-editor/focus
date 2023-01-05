text_input_handle_keypress :: (using input: *Text_Input, key_code: Input.Key_Code, mods: Mods) -> handled: bool {
    if key_code == {
        case .ARROW_LEFT; #through;
        case .ARROW_RIGHT;
            if cursor.pos != cursor.sel && !mods.shift_pressed {
                if key_code == .ARROW_LEFT {
                    cursor.pos = min(cursor.pos, cursor.sel);
                } else {
                    cursor.pos = max(cursor.pos, cursor.sel);
                }
                cursor.sel = cursor.pos;
            } else {
                step := cast(s32) ifx mods.ctrl_pressed || mods.alt_pressed then 5 else 1;
                cursor.pos += ifx key_code == .ARROW_LEFT then -step else step;
                cursor.pos = clamp(cursor.pos, 0, get_num_chars(text));
                if !mods.shift_pressed then cursor.sel = cursor.pos;
            }

        case .HOME;
            cursor.pos = 0;
            if !mods.shift_pressed then cursor.sel = cursor.pos;

        case .END;
            cursor.pos = get_num_chars(text);
            if !mods.shift_pressed then cursor.sel = cursor.pos;

        case .BACKSPACE; #through;
        case .DELETE;
            if cursor.pos == cursor.sel {
                cursor.sel = ifx key_code == .DELETE then cursor.pos + 1 else cursor.pos - 1;
                cursor.sel = clamp(cursor.sel, 0, get_num_chars(text));
            }

            left, right := get_selected_offsets(text, cursor);

            if left != right then array_delete_bytes(*text, left, right - left);

            cursor.pos = min(cursor.sel, cursor.pos);
            cursor.sel = cursor.pos;

        case #char "A";
            if only_ctrl_pressed(mods) {
                cursor.pos = 0;
                cursor.sel = get_num_chars(text);
            }

        case #char "C"; #through;
        case #char "X";
            if only_ctrl_pressed(mods) && cursor.pos != cursor.sel {
                left, right := get_selected_offsets(text, cursor);

                os_clipboard_set_text(slice(to_string(text), left, right - left));

                if key_code == #char "X" {
                    if left != right then array_delete_bytes(*text, left, right - left);
                    cursor.pos = min(cursor.sel, cursor.pos);
                    cursor.sel = cursor.pos;
                }
            }

        case #char "V";
            if only_ctrl_pressed(mods) {
                str := os_clipboard_get_text();
                defer free(str);

                left, right := get_selected_offsets(text, cursor);

                if cursor.pos != cursor.sel {
                    array_delete_bytes(*text, left, right - left);
                }
                array_insert_bytes_at(*text, left, to_bytes(str));

                cursor.pos = get_num_chars(array_view(text, 0, left + str.count));
                cursor.sel = cursor.pos;
            }
            
        case #char "D";
            if only_ctrl_pressed(mods) {
                select_word(input);
            }

        case;
            return false;
    }

    return true;
}

text_input_type_char :: (using input: *Text_Input, char: u32) {
    utf8_char := convert_utf32_to_utf8(char);
    bytes := array_view(utf8_char.bytes, 0, utf8_char.count);

    num_chars := get_num_chars(text);
    cursor.pos = clamp(cursor.pos, 0, num_chars);  // make sure cursor is in the correct position
    cursor.sel = clamp(cursor.sel, 0, num_chars);

    if cursor.pos == cursor.sel {
        // No selection
        offset := get_char_offset(text, cursor.pos);
        array_insert_bytes_at(*text, offset, bytes);
    } else {
        // Selection
        left  := get_char_offset(text, min(cursor.pos, cursor.sel));
        right := get_char_offset(text, max(cursor.pos, cursor.sel));
        array_delete_bytes(*text, left, right - left);
        array_insert_bytes_at(*text, left, bytes);
    }
    cursor.pos = min(cursor.pos, cursor.sel) + 1;
    cursor.sel = cursor.pos;
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


select_word :: (using input: *Text_Input) {
    // Decode the characters on the line for scanning
    chars := decode_utf8_string_to_temp_chars(to_string(text), max_char = MAX_TEXT_INPUT_LENGTH);
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


#scope_export

Text_Input :: struct {
    text: [..] u8;
    cursor: Cursor;
    scroll_x: s32;
    scroll_anim: Tween_Animation(s32);
    
    mouse_selection_mode: bool;  // to indicate the mouse is being dragged to select text

    Cursor :: struct {
        pos, sel: s32;  // cursor position (in chars, not bytes)
    }
}

MAX_TEXT_INPUT_LENGTH :: 5000;  // in chars