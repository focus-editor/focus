open_file_dialog_handle_event :: (event: Input.Event) {
    using open_file_dialog;
    if event.type == {
        case .KEYBOARD;
            if event.key_pressed {
                if event.key_code == .BACKSPACE {
                    // Checking it here because otherwise the input would handle it
                    if mode == .navigate && !input.text && path_chunks {
                        last := pop(*path_chunks);
                        free(last);
                        
                        refresh_entries(scan_folder = true);
                        return;
                    }
                }
                open_file_dialog_handle_key_press(event.key_code, event.modifier_flags);
            }

        case .TEXT_INPUT;
            char := event.utf32;
            if open_file_dialog.mode == .navigate && (char == #char "/" || char == #char "\\") return;  // these are special chars, don't handle
            
            open_file_dialog_handle_text_input(char);
    }
}

init_open_file_dialog :: () {
    // There used to be more stuff here
    refresh_entries();
}

show_open_file_dialog :: (mode: Open_File_Dialog.Mode, from_root := false) {
    active_global_widget = .open_file_dialog;
    
    open_file_dialog.mode = mode;
    if from_root then clear_path_chunks();
    
    refresh_entries(scan_folder = true);
}

hide_open_file_dialog :: () {
    active_global_widget = .editors;
}

open_file_dialog_handle_key_press :: (key_code: Input.Key_Code, mods: Mods) {
    using open_file_dialog;

    input_text := copy_temporary_string(to_string(input.text));
    handled := text_input_handle_keypress(*input, key_code, mods);
    if handled {
        if input_text != to_string(input.text) then refresh_entries();
        return;
    }

    if key_code == {
        case .ESCAPE;   
            hide_open_file_dialog();
            
        case .TAB;       #through;
        case #char "/";  #through;
        case #char "\\";
            if mode == .navigate {
                open_file_dialog_open_entry(entries.selected, .in_place, folder_only = true);
            }
        
        case #char "L"; 
            if only_ctrl_shift_pressed(mods) then toggle_expand();
        
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

open_file_dialog_open_entry :: (selected: s64, placement: Editor_Placement, folder_only := false) {
    using open_file_dialog;
    if selected >= entries.filtered.count return;
    
    entry := entries.filtered[selected];
    
    if entry.type == {
        case .file;
            if folder_only return;
            path := entry.full_path;
            editors_open_file(path, placement);
            hide_open_file_dialog();
    
        case .drive;
            clear_path_chunks();
            entry_name := copy_string(entry.name);
            array_add(*path_chunks, entry_name);
            root_dir = entry_name;
            refresh_entries(scan_folder = true);
            
        case .project_dir;
            clear_path_chunks();
            array_add(*path_chunks, copy_string(entry.name));
            root_dir = entry.full_path;
            refresh_entries(scan_folder = true);
            
        case .folder;
            array_add(*path_chunks, copy_string(entry.name));
            refresh_entries(scan_folder = true);
    }
}

open_file_dialog_handle_text_input :: (char: u32) {
    if char == 127 return;  // there seems to be a bug in the Input module
                            // which generates a TEXT_INPUT event for DEL
                            // when Ctrl+Backspace is pressed

    text_input_type_char(*open_file_dialog.input, char);

    refresh_entries();
}


#scope_file

clear_path_chunks :: () {
    for open_file_dialog.path_chunks free(it);
    array_reset(*open_file_dialog.path_chunks);
}

refresh_entries :: (scan_folder := false) {
    using open_file_dialog;
    
    if scan_folder {
        // Do it before pushing the pool allocator because the input and the folder scan results 
        // use the global heap
        text_input_fully_clear(*input);
        scan_current_folder();
    }
    
    pool_allocator := get_pool_allocator();
    push_allocator(pool_allocator);

    reset(*memory_pool);  // to avoid having to free each string

    scroll_to_cursor = true;
    entries.scroll_y = 0;
    entries.selected = 0;
    array_reset(*entries.filtered);
    
    filter_chars := decode_utf8_string_to_temp_char_substrings(to_string(input.text));
    
    if #complete mode == {
        case .navigate;
            if !path_chunks {
                // Display project dirs and drives
                for project_dirs {
                    name := advance(it.path, it.path_prefix_len);
                    
                    score, name_highlights := fuzzy_match(name, filter_chars);
                    if score < 0 continue;
                    
                    entry := array_add(*entries.filtered);
                    entry.type = .project_dir;
                    entry.full_path = it.path;
                    entry.name = name;
                    entry.path = it.path;
                    entry.icon = .folder;
                    entry.project_dir_id = xx it_index;
                    entry.name_highlights = name_highlights;
                    entry.path_highlights = NewArray(entry.path.count, bool);
                    
                    dir_id_part: u64 = (cast,trunc(u64) (127 - entry.project_dir_id)) << 56;
                    score_part:  u64 = (cast,trunc(u64) score)                        << 16;
                    entry.sort_key = dir_id_part | score_part;
                }
                #if OS == .WINDOWS {
                    drives := platform_enumerate_logical_drives();
                } else {
                    drives := string.["/"];
                }
                for drives {
                    name := copy_string(it);
                    
                    score, name_highlights := fuzzy_match(name, filter_chars);
                    if score < 0 continue;
                    
                    entry := array_add(*entries.filtered);
                    entry.type = .drive;
                    entry.full_path = "";
                    entry.name = name;
                    entry.path = "";
                    entry.icon = .drive;
                    entry.project_dir_id = 127;
                    entry.name_highlights = name_highlights;
                    entry.path_highlights = .[];
                    
                    dir_id_part: u64 = (cast,trunc(u64) (127 - entry.project_dir_id)) << 56;
                    score_part:  u64 = (cast,trunc(u64) score)                        << 16;
                    entry.sort_key = dir_id_part | score_part;
                }
            } else {
                // Filter current files
                for current_files {
                    score, name_highlights := fuzzy_match(it.name, filter_chars);
                    if score < 0 continue;
                    
                    entry := array_add(*entries.filtered);
                    <<entry = it;
                    
                    entry.name_highlights = name_highlights;
                    entry.path_highlights = .[];
                    
                    is_dir_part: u64 = (cast,trunc(u64) (entry.type == .folder)) << 56;  // directories come first
                    score_part:  u64 = (cast,trunc(u64) score)                   << 16;
                    entry.sort_key = is_dir_part | score_part;
                }
            }
            
        case .search;
            // @MEMORY SAFETY: if we ever delete buffers from open_buffers and free memory, this will have to copy everything!
            num_entries := 0;
            for buffer : open_buffers {
                if !buffer.has_file || buffer.deleted continue;  // NOTE: we might still want to see externally deleted buffers.
                                                                 // Maybe use 'deleted' and 'modified_on_disk' to distingiush the buffers
                                                                 // we haven't deleted ourselves?
                                                                 // Alternatively, if there's an editor for a deleted buffer we probably
                                                                 // still want to see it here
                
                name_score, name_highlights := fuzzy_match(buffer.file.name, filter_chars);
                path_score, path_highlights := fuzzy_match(buffer.file.path, filter_chars);
                score := 200 * name_score + path_score;  // name score is much more important
                if score < 0 continue;
                
                entry := array_add(*entries.filtered);
                entry.file = buffer.file;
                entry.name_highlights = name_highlights;
                entry.path_highlights = path_highlights;
                // NOTE: there's space left in the sort key in case we need to add more parameters
                dir_id_part:     u64 = (cast,trunc(u64) (127 - buffer.file.project_dir_id)) << 56;
                score_part:      u64 = (cast,trunc(u64) score)                              << 16;
                times_open_part: u64 = (cast,trunc(u64) buffer.num_times_opened)            <<  0;
                entry.sort_key = dir_id_part | score_part | times_open_part;
                
                if buffer.modified         then entry.flags |= .MODIFIED;
                if buffer.modified_on_disk then entry.flags |= .MODIFIED_ON_DISK;
                
                num_entries += 1;
                if num_entries >= MAX_ENTRIES_TO_SHOW break;
            }
    }
    
    quick_sort(entries.filtered, compare_entries);
    
    compare_entries :: (e1: Entry, e2: Entry) -> s64 {
        key_diff := cast,no_check(s64) e2.sort_key - cast,no_check(s64) e1.sort_key;
        if key_diff != 0 return key_diff;
        return memcmp(e1.name.data, e2.name.data, min(e1.name.count, e2.name.count));
    }
}

scan_current_folder :: () {
    using open_file_dialog;
    if mode != .navigate || !path_chunks return;
    
    path_chunks_trimmed := array_view(path_chunks, 1, path_chunks.count - 1);
    dir_path := sprint("%/%", root_dir, join(..path_chunks_trimmed, separator = "/"));
    
    // Reset current files
    for current_files free(it.full_path);
    array_reset(*current_files);
    
    // Scan the current folder
    visit_files(dir_path, recursive = false, null, visitor_func, visit_directories = true);
    
    visitor_func :: (file: *File_Visit_Info, userdata: *void) {
        if file.had_error || file.is_symlink return;
        if file.is_directory {
            if should_ignore_dir(file.short_name) return;
        } else {
            if should_ignore_file(file.full_name) return;
        }
        
        full_path := copy_string(file.full_name);  // one allocation, the rest are views into it
        path, basename, extension, name := path_decomp(full_path);
        
        entry := array_add(*open_file_dialog.current_files);
        if file.is_directory then entry.type = .folder;
        entry.full_path = full_path;
        entry.name = name;
        entry.path = "";
        if file.is_directory {
            entry.icon = .folder;
            entry.type = .folder;
        } else {
            entry.icon = get_file_icon(name, extension);
            entry.type = .file;
        }    
    }
}

fuzzy_match :: (str: string, chars: [] string) -> score: s32, highlights: [] bool {
    highlights := NewArray(str.count, bool, initialized = true);  // allocates from the pool
                                                                  // we "leak" if there's no match but that should be ok                                                            
    if !chars return 0, highlights;
    
    MAX_CHARS :: 200;
    
    score: s32;
    pos := 0;
    
    for char : chars {
        index := find_index_from_left_nocase(str, char, pos);
        if index < 0 { score = -1; break; }
        highlights[index] = true;
        score += cast(s32) (MAX_CHARS - index);  // the closer to the beginning, the better
        pos = index + char.count;
    }
    
    if score < 0 then memset(highlights.data, 0, highlights.count);  // no match -> no highlighting
    
    return score, highlights;
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
    mode: Mode;
    scroll_to_cursor := false;

    input: Text_Input;
    
    path_chunks: [..] string;
    root_dir: string;
    current_files: [..] Entry;  // files in the current folder (used in .navigate mode only)

    entries: struct {
        filtered: [..] Entry;
        selected: s64;
        selected_by_mouse: s64 = -1;  // to remember which entry the left mouse button went down on

        scroll_y: s32;
        scroll_anim := #run Tween_Animation(s32).{ speed = xx 0.1, func = .lerp };
        per_page: s64 = 10;
    }
    
    width_percentage := WIDTH_NORMAL;  // how much of the screen the popup occupies
    width_anim := #run Tween_Animation(float).{ start = WIDTH_NORMAL, target = WIDTH_NORMAL };
    WIDTH_NORMAL   :: 0.4;
    WIDTH_EXPANDED :: 0.8;
    
    Mode :: enum {
        search;
        navigate;
    }
}

#scope_file

Entry :: struct {
    using file: File_Info;
    flags: enum_flags u8 {
        MODIFIED;
        MODIFIED_ON_DISK;
    }
    type: enum u8 { file; folder; drive; project_dir; } = .file;
    name_highlights: [] bool;
    path_highlights: [] bool;
    sort_key: u64;
}