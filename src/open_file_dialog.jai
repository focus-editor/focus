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

dialog_entries :: #run Open_File_Dialog.Entry.[
    .{ name = "main.exe",   proj = "focus", path = "", icon = .unknown },
    .{ name = "LOG.md",     proj = "focus", path = "src",    icon = .worklog },
    .{ name = ".gitignore", proj = "focus", path = "",    icon = .git },
    .{ name = "run.bat", proj = "focus", path = "",    icon = .text },
    .{ name = "Simple_String.jai", proj = "jai-beta", path = "modules/Basic", icon = .jai },
    .{ name = "README.md", proj = "focus", path = "", icon = .text },
    .{ name = "vasia.txt", proj = "focus", path = "", icon = .text },
    .{ name = "glfw.cpp", proj = "glfw", path = "src/main", icon = .cpp },
    .{ name = "image.jpg", proj = "glfw", path = "src", icon = .image },
    .{ name = "sound.ogg", proj = "focus", path = "src/audio", icon = .audio },
    .{ name = "Font Awesome Free-Regular 400.ttf", proj = "focus", path = "fonts", icon = .font },
    .{ name = "LICENSE.txt", proj = "focus", path = "fonts/font-awesome", icon = .key },
];

Open_File_Dialog :: struct {
    text: [..] u8;           // filter text
    entries: [..] Entry;     // filtered entries
    all_entries: [..] Entry; // all file entries in the project (not updated too often)

    cursor: Cursor;
    scroll_x: s32;
    scroll_anim: Scroll_Animation;
    show := false;

    Cursor :: struct {
        pos, sel: s32;  // cursor position (in chars, not bytes)
    }

    Entry :: struct {
        proj: string;
        path: string;
        name: string;
        icon: File_Icon;
    }
}

File_Icon :: enum u32 {
    unknown :: 0xf15b;
    text    :: 0xf15c;
    jai     :: 0xf574;
    cpp     :: 0xf1c9;
    worklog :: 0xf46d;
    git     :: 0xf387;
    image   :: 0xf1c5;
    audio   :: 0xf1c7;
    font    :: 0xf031;
    key     :: 0xf084;
}

BULLET_CHAR :: #run to_string(*convert_utf32_to_utf8(0x2022));
