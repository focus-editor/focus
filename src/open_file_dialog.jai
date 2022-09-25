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
    }
}

open_file_dialog_handle_text_input :: (char: u32) {
    if char == 127 return;  // there seems to be a bug in the Input module
                            // which generates a TEXT_INPUT event for DEL
                            // when Ctrl+Backspace is pressed

    using open_file_dialog;

    cursor.pos = clamp(cursor.pos, 0, get_num_chars(text));  // make sure cursor is in the correct position
    offset := get_char_offset(text, cursor.pos);
    // TODO: replace selection

    utf8_char := convert_utf32_to_utf8(char);
    array_insert_bytes_at(*text, offset, array_view(utf8_char.bytes, 0, utf8_char.count));
    cursor.pos += 1;
    cursor.sel = cursor.pos;
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


#scope_export

Open_File_Dialog :: struct {
    text: [..] u8;
    cursor: struct { pos, sel: s32; }  // cursor position (in chars, not bytes)
    show := false;
}

