init_open_file_dialog :: (project_dirs: [] string) {
    using open_file_dialog;

    print("Initting open file dialog\n");  // TODO: remove when not doing this for every file save

    pool_allocator := get_pool_allocator();
    push_allocator(pool_allocator);

    array_reset_keeping_memory(*entries.all);
    reset(*memory_pool);  // to avoid having to free each string

    visitor_data: Visitor_Data = ---;
    visitor_data.ignore_folders = string.[".build", ".git", "bin"];
    visitor_data.ignore_files   = string.[".exe", ".pdb", ".rdbg", ".lib", ".dll", ".ttf", ".otf"];
    visitor_data.entries_dst = *entries.all;

    for dir : project_dirs {
        proj_dir_split := split(dir, "/");
        visitor_data.proj = proj_dir_split[proj_dir_split.count-1];
        visitor_data.proj_full = dir;
        visit_files(dir, recursive = true, visitor_data, file_visitor_func, visit_directories = true);
    }

    recalculate_filtered_entries();
}

open_file_dialog_show :: () {
    using open_file_dialog;
    show = true;
    array_reset_keeping_memory(*input.text);
    recalculate_filtered_entries();
}

open_file_dialog_handle_keypress :: (key_code: Input.Key_Code, mods: Mods) {
    using open_file_dialog;
    using open_file_dialog.input;

    if key_code == {
        case .ENTER;
            open_file_dialog_open_entry(entries.selected, on_the_side = only_ctrl_pressed(mods));

        case .ARROW_LEFT; #through;
        case .ARROW_RIGHT;
            step := cast(s32) ifx mods.ctrl_pressed || mods.alt_pressed then 5 else 1;
            cursor.pos += ifx key_code == .ARROW_LEFT then -step else step;
            cursor.pos = clamp(cursor.pos, 0, get_num_chars(text));
            if !mods.shift_pressed then cursor.sel = cursor.pos;

        case .ARROW_DOWN; #through;
        case .ARROW_UP;
            using entries;
            selected += ifx key_code == .ARROW_UP then -1 else 1;
            if selected < 0 then selected = max(0, filtered.count - 1);
            if selected >= filtered.count then selected = 0;
            scroll_to_cursor = true;

        case .PAGE_UP; #through;
        case .PAGE_DOWN;
            using entries;
            selected += ifx key_code == .PAGE_UP then -entries.per_page else entries.per_page;
            if selected < 0 then selected = 0;
            if selected >= filtered.count then selected = filtered.count - 1;
            scroll_to_cursor = true;

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

            recalculate_filtered_entries();

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

                    recalculate_filtered_entries();
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

                recalculate_filtered_entries();
            }
    }
}

open_file_dialog_open_entry :: (selected: s64, on_the_side: bool) {
    using open_file_dialog;
    path := entries.filtered[selected].full_path;
    editors_open_file(path, on_the_side);
    show = false;
}

open_file_dialog_handle_text_input :: (char: u32) {
    if char == 127 return;  // there seems to be a bug in the Input module
                            // which generates a TEXT_INPUT event for DEL
                            // when Ctrl+Backspace is pressed

    using open_file_dialog.input;

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

    recalculate_filtered_entries();
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

recalculate_filtered_entries :: () {
    using open_file_dialog;

    scroll_to_cursor = true;
    entries.scroll_y = 0;
    entries.selected = 0;
    array_reset_keeping_memory(*entries.filtered);

    if input.text.count == 0 {
        // TODO: still give them scores and sort
        for entry : array_view(entries.all, 0, MAX_ENTRIES_TO_SHOW) {
            array_add(*entries.filtered, entry);
        }
        return;
    }

    str := to_string(input.text);
    num := 0;
    for entry : entries.all {
        if contains_nocase(entry.name, str) {
            array_add(*entries.filtered, entry);
            num += 1;
            if num >= MAX_ENTRIES_TO_SHOW break;
        }
    }
}


#scope_export

Open_File_Dialog :: struct {
    show := false;
    scroll_to_cursor := false;

    input: Input;
    entries: Entries;

    Input :: struct {
        text: [..] u8;
        cursor: Cursor;
        scroll_x: s32;
        scroll_anim: Scroll_Animation;
    }

    Entries :: struct {
        all: [..] File_Info;  // all files in the project

        filtered: [..] File_Info;
        selected: s64;
        selected_by_mouse: s64 = -1;  // to remember which entry the left mouse button went down on

        scroll_y: s32;
        scroll_anim: Scroll_Animation;
        per_page: s64 = 10;
    }

    Cursor :: struct {
        pos, sel: s32;  // cursor position (in chars, not bytes)
    }
}

BULLET_CHAR :: #run to_string(*convert_utf32_to_utf8(0x2022));


#scope_file

// @Cleanup: this logic needs some careful reviewing
// Also TODO: profile how long it takes to scan everything
file_visitor_func :: (file: *File_Visit_Info, config: Visitor_Data) {
    if file.is_directory {
        for config.ignore_folders {
            if equal_nocase(file.short_name, it) {  // TODO: do a wildcard match
                file.descend_into_directory = false;  // ignore
                return;
            }
        }
        return;
    }
    if file.is_symlink return;

    // TODO: do a wildcard match
    for config.ignore_files { if contains_nocase(file.short_name, it) return; }  // maybe ignore

    entry := get_file_info_from_full_path(file.full_name);
    array_add(config.entries_dst, entry);
}

get_pool_allocator :: () -> Allocator {
    a: Allocator;
    a.proc = flat_pool_allocator_proc;
    a.data = *memory_pool;
    return a;
}

memory_pool: Flat_Pool;

// NOTE: could probably make it global
Visitor_Data :: struct {
    ignore_folders: [] string;
    ignore_files:   [] string;
    proj: string;
    proj_full: string;
    entries_dst: *[..] File_Info;
}

MAX_ENTRIES_TO_SHOW :: 200;
