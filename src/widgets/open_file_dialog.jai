open_file_dialog_handle_event :: (event: Input.Event) {
    if event.type == {
        case .KEYBOARD;
            if event.key_pressed {
                if event.key_code == {
                    case .ESCAPE;   hide_open_file_dialog(); return;
                    // case #char "F"; if only_ctrl_shift_pressed(event.modifier_flags) { if !finder_is_open() then open_finder(); else activate_finder(); return; }
                }
                open_file_dialog_handle_key_press(event.key_code, event.modifier_flags);
            }

        case .TEXT_INPUT;
            open_file_dialog_handle_text_input(event.utf32);
    }
}

init_open_file_dialog :: () {
    using open_file_dialog;

    pool_allocator := get_pool_allocator();
    push_allocator(pool_allocator);

    reset(*memory_pool);  // to avoid having to free each string. NOTE: now we don't even copy strings?

    recalculate_filtered_entries();
}

show_open_file_dialog :: () {
    using open_file_dialog;
    active_global_widget = .open_file_dialog;
    array_reset(*input.text);
    input.cursor.pos = 0;
    input.cursor.sel = 0;
    recalculate_filtered_entries();
}

hide_open_file_dialog :: () {
    active_global_widget = .editors;
}

open_file_dialog_handle_key_press :: (key_code: Input.Key_Code, mods: Mods) {
    using open_file_dialog;

    input_text := copy_temporary_string(to_string(input.text));
    handled := text_input_handle_keypress(*input, key_code, mods);
    if handled {
        if input_text != to_string(input.text) then recalculate_filtered_entries();
        return;
    }

    if key_code == {
        case .ENTER;
            open_file_dialog_open_entry(entries.selected, on_the_side = only_ctrl_pressed(mods));

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
    }
}

open_file_dialog_open_entry :: (selected: s64, on_the_side: bool) {
    using open_file_dialog;
    path := entries.filtered[selected].full_path;
    editors_open_file(path, on_the_side);
    hide_open_file_dialog();
}

open_file_dialog_handle_text_input :: (char: u32) {
    if char == 127 return;  // there seems to be a bug in the Input module
                            // which generates a TEXT_INPUT event for DEL
                            // when Ctrl+Backspace is pressed

    text_input_type_char(*open_file_dialog.input, char);

    recalculate_filtered_entries();
}


#scope_file

recalculate_filtered_entries :: () {
    using open_file_dialog;

    scroll_to_cursor = true;
    entries.scroll_y = 0;
    entries.selected = 0;
    array_reset(*entries.filtered);

    // @MEMORY SAFETY: if we ever delete buffers from open_buffers and free memory, this will have to copy everything!
    str := to_string(input.text);
    num := 0;
    for buffer : open_buffers {
        if !buffer.has_file continue;
        if str && !contains_nocase(buffer.file.full_path, str) continue; 
        
        entry := array_add(*entries.filtered);
        entry.file = buffer.file;
        if buffer.modified         then entry.flags |= .MODIFIED;
        if buffer.modified_on_disk then entry.flags |= .MODIFIED_ON_DISK;
        
        num += 1;
        if num >= MAX_ENTRIES_TO_SHOW break;
    }
}

get_pool_allocator :: () -> Allocator {
    a: Allocator;
    a.proc = flat_pool_allocator_proc;
    a.data = *memory_pool;
    return a;
}

memory_pool: Flat_Pool;

MAX_ENTRIES_TO_SHOW :: 300;

#scope_export

open_file_dialog: Open_File_Dialog;

Open_File_Dialog :: struct {
    scroll_to_cursor := false;

    input: Text_Input;

    entries: struct {
        filtered: [..] Entry;
        selected: s64;
        selected_by_mouse: s64 = -1;  // to remember which entry the left mouse button went down on

        scroll_y: s32;
        scroll_anim: Tween_Animation(s32);
        per_page: s64 = 10;
    }
    
    Entry :: struct {
        using file: File_Info;
        flags: enum_flags u8 {
            MODIFIED;
            MODIFIED_ON_DISK;
        }
    }
}
