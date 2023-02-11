open_file_dialog_handle_event :: (event: Input.Event) {
    if event.type == {
        case .KEYBOARD;
            if event.key_pressed {
                if event.key_code == {
                    case .ESCAPE;   hide_open_file_dialog(); return;
                    case #char "L"; if only_ctrl_shift_pressed(event.modifier_flags) { toggle_expand(); return; }
                }
                open_file_dialog_handle_key_press(event.key_code, event.modifier_flags);
            }

        case .TEXT_INPUT;
            open_file_dialog_handle_text_input(event.utf32);
    }
}

init_open_file_dialog :: () {
    // There used to be more stuff here
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
            placement := ifx only_ctrl_pressed(mods) then Editor_Placement.on_the_side else .in_place;
            open_file_dialog_open_entry(entries.selected, placement);
            
        case #char "1";
            if only_ctrl_pressed(mods) open_file_dialog_open_entry(entries.selected, placement = .left);
            
        case #char "2";
            if only_ctrl_pressed(mods) open_file_dialog_open_entry(entries.selected, placement = .right);

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

open_file_dialog_open_entry :: (selected: s64, placement: Editor_Placement) {
    using open_file_dialog;
    if selected >= entries.filtered.count return;
    path := entries.filtered[selected].full_path;
    editors_open_file(path, placement);
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
    
    pool_allocator := get_pool_allocator();
    push_allocator(pool_allocator);

    reset(*memory_pool);  // to avoid having to free each string

    scroll_to_cursor = true;
    entries.scroll_y = 0;
    entries.selected = 0;
    array_reset(*entries.filtered);
    
    filter_chars := decode_utf8_string_to_temp_char_substrings(to_string(input.text));

    // @MEMORY SAFETY: if we ever delete buffers from open_buffers and free memory, this will have to copy everything!
    num_entries := 0;
    for buffer : open_buffers {
        if !buffer.has_file || buffer.deleted continue;  // NOTE: we might still want to see externally deleted buffers.
                                                         // Maybe use 'deleted' and 'modified_on_disk' to distingiush the buffers
                                                         // we haven't deleted ourselves?
                                                         // Alternatively, if there's an editor for a deleted buffer we probably
                                                         // still want to see it here
        
        score, name_highlights, path_highlights := fuzzy_match(buffer, filter_chars);
        if score < 0 continue;
        
        entry := array_add(*entries.filtered);
        entry.file = buffer.file;
        entry.name_highlights = name_highlights;
        entry.path_highlights = path_highlights;
        entry.score = score;
        
        if buffer.modified         then entry.flags |= .MODIFIED;
        if buffer.modified_on_disk then entry.flags |= .MODIFIED_ON_DISK;
        
        num_entries += 1;
        if num_entries >= MAX_ENTRIES_TO_SHOW break;
    }
    
    quick_sort(entries.filtered, compare_score);
    
    compare_score :: (e1: Entry, e2: Entry) -> s64 {
        score_diff := e2.score - e1.score;
        if score_diff != 0 return score_diff;
        
        // TODO: compare alphabetically
        return 0;
    }
}

fuzzy_match :: (buffer: Buffer, chars: [] string) -> score: s64, name_highlights: [] bool, path_highlights: [] bool {
    assert(buffer.has_file);
    name := buffer.file.name;
    path := buffer.file.path;  // TODO: for non-file buffers replace these with something else
    
    name_highlights := NewArray(name.count, bool, initialized = true);  // allocates from the pool
    path_highlights := NewArray(path.count, bool, initialized = true);  // we "leak" if there's no match but that should be ok
    
    if !chars return 0, name_highlights, path_highlights;
    
    MAX_CHARS :: 200;
    
    match_str :: (str: string, chars: [] string, out_highlights: [] bool) -> score: s64 {
        score := 0;
        pos := 0;
        for char : chars {
            index := find_index_from_left_nocase(str, char, pos);
            if index < 0 return -1;
            out_highlights[index] = true;
            score += MAX_CHARS - index;  // the closer to the beginning, the better
            pos = index + char.count;
        }
        return score;
    }
    
    // Search in the name
    name_score := match_str(name, chars, name_highlights);
    
    // Search in the path
    path_score := match_str(path, chars, path_highlights);
    
    score := MAX_CHARS * name_score + path_score;  // name score is much more important
    
    return score, name_highlights, path_highlights;
}

toggle_expand :: () {
    using open_file_dialog;
    
    if width_percentage != WIDTH_EXPANDED {
        start_animation(*width_anim, width_percentage, WIDTH_EXPANDED, snappy = true);
    } else {
        start_animation(*width_anim, width_percentage, WIDTH_NORMAL, snappy = true);
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
    
    width_percentage := WIDTH_NORMAL;  // how much of the screen the popup occupies
    width_anim: Tween_Animation(float) = #run Tween_Animation(float).{ start = WIDTH_NORMAL, target = WIDTH_NORMAL, speed = 0.1 };
    WIDTH_NORMAL   :: 0.4;
    WIDTH_EXPANDED :: 0.8;
}

#scope_file

Entry :: struct {
    using file: File_Info;
    flags: enum_flags u8 {
        MODIFIED;
        MODIFIED_ON_DISK;
    }
    name_highlights: [] bool;
    path_highlights: [] bool;
    score: s64;
}