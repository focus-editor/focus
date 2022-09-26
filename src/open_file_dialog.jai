open_file_dialog_handle_keypress :: (key_code: Input.Key_Code, mods: Mods) {
    using open_file_dialog;

    if key_code == {
        case .ARROW_LEFT; #through;
        case .ARROW_RIGHT;
            step := cast(s32) ifx mods.ctrl_pressed || mods.alt_pressed then 5 else 1;
            cursor.pos += ifx key_code == .ARROW_LEFT then -step else step;
            cursor.pos = clamp(cursor.pos, 0, get_num_chars(text));
            if !mods.shift_pressed then cursor.sel = cursor.pos;

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
    }
}

open_file_dialog_handle_text_input :: (char: u32) {
    if char == 127 return;  // there seems to be a bug in the Input module
                            // which generates a TEXT_INPUT event for DEL
                            // when Ctrl+Backspace is pressed

    using open_file_dialog;

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

// TODO: make this a general function as a version of it is used in editor scrolling?
animate_scrolling :: (using animation: *Scroll_Animation, current: s32) -> (new_value: s32, scrolling: bool) {
    if current == target return current, false;

    new_value: s32;

    t := (frame_time - started_at) / SPEED;
    if t >= 1 || t < 0 {
        new_value = target;
    } else {
        new_value = start + xx (cast(float)(target - start) * t);
    }

    return new_value, true;
}


#scope_file

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

get_selected_offsets :: (text: [..] u8, cursor: Open_File_Dialog.Cursor) -> left: s64, right: s64 {
    str := to_string(text);
    left  := pos_to_offset(str, min(cursor.sel, cursor.pos));
    right := pos_to_offset(str, max(cursor.sel, cursor.pos));
    return left, right;
}


#scope_export

Open_File_Dialog :: struct {
    text: [..] u8;
    cursor: Cursor;
    scroll_x: s32;
    scroll_anim: Scroll_Animation;
    show := false;

    Cursor :: struct { pos, sel: s32; }  // cursor position (in chars, not bytes)
}

