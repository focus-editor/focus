open_file_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    using open_file_dialog;

    if event.type == .KEYBOARD && event.key_pressed {
        action := map_event_to_action(event, Action_Open_File_Dialog);
        if action == {
            case .close_dialog;             hide_open_file_dialog();                                                                                                             return true;
            case .open_entry_in_place;      open_file_dialog_open_entry(entries.selected, .in_place);                                                                            return true;
            case .open_entry_on_the_side;   open_file_dialog_open_entry(entries.selected, .on_the_side);                                                                         return true;
            case .open_entry_on_the_left;   open_file_dialog_open_entry(entries.selected, .left);                                                                                return true;
            case .open_entry_on_the_right;  open_file_dialog_open_entry(entries.selected, .right);                                                                               return true;
            case .open_entry_in_explorer;   open_file_dialog_open_entry_in_explorer(entries.selected);                                                                           return true;
            case .open_directory;           open_file_dialog_open_entry(entries.selected, .in_place, folder_only = true, maybe_open_root_dir = event.key_code == #char "/");     return true;
            case .pop_directory;            if pop_directory() return true;

            case .toggle_expand;            toggle_expand();                    return true;
            case .move_up;                  move_cursor(-1, wrap = true);       return true;
            case .move_down;                move_cursor( 1, wrap = true);       return true;
            case .move_up_fast;             move_cursor(-5);                    return true;
            case .move_down_fast;           move_cursor( 5);                    return true;
            case .move_up_one_page;         move_cursor(-entries.per_page);     return true;
            case .move_down_one_page;       move_cursor( entries.per_page);     return true;
        }

        handled := maybe_handle_text_input_event(*input, event);
        return handled;
    } else if event.type == .TEXT_INPUT {
        char := event.utf32;
        if open_file_dialog.mode == .navigate && (char == #char "/" || char == #char "\\") return true;  // these are special chars, don't handle

        if char == 127 return true;  // there seems to be a bug in the Input module
                                // which generates a TEXT_INPUT event for DEL
                                // when Ctrl+Backspace is pressed

        text_input_type_char(*open_file_dialog.input, char);
        refresh_entries(clear_input = false);
        return true;
    }
    return false;
}

init_open_file_dialog :: () {
    // There used to be more stuff here
    open_file_dialog.initted = true;
    refresh_entries();
}

deinit_open_file_dialog :: () {
    using open_file_dialog;

    initted = false;

    pool_allocator := get_pool_allocator();
    push_allocator(pool_allocator);

    reset(*memory_pool);

    scroll_to_cursor = .snap;
    entries.scroll_y = 0;
    entries.selected = 0;
    array_reset(*entries.filtered);
}

show_open_file_dialog :: (mode: Open_File_Dialog.Mode, from_root := false) {
    if !from_root {
        // Derive the path chunks from the current open file
        editor, buffer := get_active_editor_and_buffer();
        if active_global_widget == .editors && buffer && buffer.has_file then set_path_chunks_from_file(buffer.file.full_path);
    } else {
        clear_path_chunks();
    }

    active_global_widget = .open_file_dialog;
    open_file_dialog.mode = mode;

    refresh_entries();
}

hide_open_file_dialog :: () {
    activate_editors();
}

open_file_dialog_open_entry :: (selected: s64, placement: Editor_Placement, folder_only := false, maybe_open_root_dir := false) {
    using open_file_dialog;
    if selected >= entries.filtered.count return;

    entry := entries.filtered[selected];
    
    if path_chunks.count == 0 && maybe_open_root_dir {
        // We are selecting our first chunk and we just pushed the "/" key.
        // In this special case, we will open "/" if it is in the list.
        
        for entries.filtered {
            if it.entry_name == "/" {
                entry = it;
                break;
            }
        }
    }

    if entry.type == {
        case .nothing;
            return;

        case .file;
            if folder_only return;
            if entry.buffer_id >= 0 {
                editors_open_buffer(entry.buffer_id, placement);
            } else {
                path := entry.full_path;
                editors_open_file(path, placement);
            }
            hide_open_file_dialog();

        case .drive;
            clear_path_chunks();
            entry_name := copy_string(entry.name);
            array_add(*path_chunks, entry_name);
            root_dir = entry_name;
            refresh_entries();

        case .project_dir;
            clear_path_chunks();
            array_add(*path_chunks, copy_string(entry.name));
            root_dir = entry.full_path;
            refresh_entries();

        case .folder;
            array_add(*path_chunks, copy_string(entry.name));
            refresh_entries();
    }
}

open_file_dialog_open_entry_in_explorer :: (selected: s64) {
    using open_file_dialog;
    if selected >= entries.filtered.count return;
    entry := entries.filtered[selected];
    
    path: string = ---;
    #if OS == .WINDOWS {
        if ends_with(entry.name, ":") path = tprint("%/", entry.name); // Drive letter. We need to add a slash.
        else                          path = entry.full_path;          // Not a drive letter.
    } else {
        path = ifx entry.name == "/" then "/" else entry.full_path;
    }
    
    platform_open_in_explorer(path, reveal = entry.type == .file);
}

open_file_dialog_truncate_path_chunks :: (chunk_index: s64) {
    using open_file_dialog;

    if chunk_index >= path_chunks.count return;

    for i : chunk_index + 1 .. path_chunks.count - 1 {
        free(path_chunks[i]);
    }
    path_chunks.count = chunk_index + 1;

    refresh_entries();
}

open_file_dialog_maybe_expand :: () {
    using open_file_dialog;
    if width_percentage < WIDTH_EXPANDED then toggle_expand();
    redraw_requested = true;
}


#scope_file

maybe_handle_text_input_event :: (using input: *Text_Input, event: Input.Event) -> handled: bool {
    input_text := copy_temporary_string(to_string(text));
    handled := text_input_handle_event(input, event);
    if handled {
        if input_text != to_string(input.text) then refresh_entries(clear_input = false);
        return true;
    }
    return false;
}

move_cursor :: (delta: s64, wrap := false, snap := true) {
    using open_file_dialog.entries;

    selected += delta;

    if wrap {
        if selected < 0 then selected = max(0, filtered.count - 1);
        if selected >= filtered.count then selected = 0;
    } else {
        if selected < 0 then selected = 0;
        if selected >= filtered.count then selected = filtered.count - 1;
    }
    open_file_dialog.scroll_to_cursor = ifx snap then Scroll_Mode.snap else .yes;
}

pop_directory :: () -> handled: bool {
    using open_file_dialog;
    if mode != .navigate || input.text || !path_chunks return false;

    last := pop(*path_chunks);
    free(last);

    refresh_entries();

    return true;
}

set_path_chunks_from_file :: (file_path: string) {
    using open_file_dialog;

    clear_path_chunks();

    parent_dir := get_parent_dir_path(file_path);

    is_project_dir, project_dir := dir_is_within_project(parent_dir);
    if is_project_dir {
        root_dir = copy_string(project_dir.path);  // leak
        array_add(*path_chunks, copy_string(project_dir.name));
    } else {
        #if OS != .WINDOWS then array_add(*path_chunks, copy_string("/"));
        root_dir = "";
    }

    advance(*parent_dir, project_dir.path.count);

    for chunk : split(parent_dir, cast(u8) #char "/") {
        trimmed := trim(chunk);
        if !trimmed continue;
        array_add(*path_chunks, copy_string(trimmed));
    }
}

clear_path_chunks :: () {
    for open_file_dialog.path_chunks free(it);
    array_reset(*open_file_dialog.path_chunks);
}

refresh_entries :: (clear_input := true) {
    using open_file_dialog;

    // Do it before pushing the pool allocator because the input uses use the global heap
    if clear_input then text_input_fully_clear(*input);

    pool_allocator := get_pool_allocator();
    push_allocator(pool_allocator);

    reset(*memory_pool);  // to avoid having to free each string

    // Scan folder on every keystroke, that should be ok because we don't do it recursively.
    // It also means we will always have the most recent contents of the dir and can use the memory pool
    scan_current_folder();

    scroll_to_cursor = .snap;
    entries.scroll_y = 0;
    entries.selected = 0;
    array_reset(*entries.filtered);

    filter_chars := decode_utf8_string_to_temp_char_substrings(to_string(input.text));

    if #complete mode == {
        case .navigate;
            if !path_chunks {
                // Display project dirs and drives
                for project_dirs {
                    score, name_highlights := fuzzy_match(it.name, filter_chars);
                    if score < 0 continue;

                    entry := array_add(*entries.filtered);
                    entry.type = .project_dir;
                    entry.full_path = it.path;
                    entry.name = it.name;
                    entry.entry_name = it.name;
                    entry.path = it.path;
                    entry.icon = .folder;
                    entry.project_dir_id = xx (it_index + 1);
                    entry.name_highlights = name_highlights;
                    entry.path_highlights = NewArray(entry.path.count, bool);

                    dir_id_part: u64 = (cast,trunc(u64) (127 - entry.project_dir_id)) << 56;
                    score_part:  u64 = (cast,trunc(u64) score)                        << 16;
                    entry.sort_key = dir_id_part | score_part;
                }
                for platform_enumerate_logical_drives() {
                    name := copy_string(it);

                    score, name_highlights := fuzzy_match(name, filter_chars);
                    if score < 0 continue;

                    entry := array_add(*entries.filtered);
                    entry.type = .drive;
                    entry.full_path = "";
                    entry.name = name;
                    entry.entry_name = name;
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

                    entry.entry_name = entry.name;
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

            // This bit will be set when we want to make sure an entry appears on top
            top_priority_bit: u64 = 1 << 62;  // NOT the topmost bit because we'll be converting to s64 later

            for buffer, buffer_id : open_buffers {
                if buffer.deleted && !buffer.modified continue;  // NOTE: we might still want to see externally deleted buffers.
                                                                 // Maybe use 'deleted' and 'modified_on_disk' to distingiush the buffers
                                                                 // we haven't deleted ourselves?
                                                                 // Alternatively, if there's an editor for a deleted buffer we probably
                                                                 // still want to see it here

                buffer_name := get_buffer_name(buffer);
                name_score, name_highlights := fuzzy_match(buffer_name, filter_chars);
                path_score, path_highlights := fuzzy_match(buffer.file.path, filter_chars);
                score := 200 * name_score + path_score;  // name score is much more important
                if score < 0 continue;

                entry := array_add(*entries.filtered);
                entry.buffer_id = buffer_id;
                entry.file = buffer.file;
                entry.entry_name = buffer_name;
                if !buffer.has_file {
                    entry.entry_name = copy_string(buffer_name);
                    entry.icon = File_Icon.text;
                }
                entry.name_highlights = name_highlights;
                entry.path_highlights = path_highlights;
                // NOTE: there's space left in the sort key in case we need to add more parameters
                dir_id_part:     u64 = (cast,trunc(u64) (63 - buffer.file.project_dir_id))  << 55;
                score_part:      u64 = (cast,trunc(u64) score)                              << 16;
                times_open_part: u64 = (cast,trunc(u64) buffer.num_times_opened)            <<  0;
                entry.sort_key = dir_id_part | score_part | times_open_part;

                if buffer.modified         then { entry.flags |= .MODIFIED;         entry.sort_key |= top_priority_bit; }
                if buffer.modified_on_disk then { entry.flags |= .MODIFIED_ON_DISK; entry.sort_key |= top_priority_bit; }

                num_entries += 1;
                if num_entries >= config.settings.max_entries_in_open_file_dialog break;
            }
    }

    compare_entries :: (e1: Entry, e2: Entry) -> s64 {
        key_diff := cast,no_check(s64) e2.sort_key - cast,no_check(s64) e1.sort_key;
        if key_diff != 0 return key_diff;
        return memcmp(e1.name.data, e2.name.data, min(e1.name.count, e2.name.count));
    }

    quick_sort(entries.filtered, compare_entries);

    if !entries.filtered {
        array_add(*entries.filtered, Entry.{
            file = File_Info.{
                full_path = "",
                name = "",
                path = "",
                icon = .dots,
            },
            type = .nothing,
            name_highlights = .[],
            path_highlights = .[],
        });
    }
}

scan_current_folder :: () {
    using open_file_dialog;
    if mode != .navigate || !path_chunks return;

    path_chunks_trimmed := array_view(path_chunks, 1, path_chunks.count - 1);
    dir_path := sprint("%/%", root_dir, join(..path_chunks_trimmed, separator = "/"));

    // Reset current files
    array_reset(*current_files);

    visitor_func :: (file: *File_Visit_Info, userdata: *void) {
        if file.had_error || file.is_symlink return;
        if file.is_directory {
            if should_ignore_dir(file.full_name) return;
        } else {
            if should_ignore_file(file.full_name) return;
        }

        full_path: string = ---;   // one allocation in the pool, the rest are views into it
        #if OS == .WINDOWS {
            // Fix an extra slash in Windows (ugh)
            b: String_Builder;
            previous_char_was_slash := false;
            for 0..file.full_name.count - 1 {
                c := file.full_name.data[it];
                if c == #char "/" {
                    if previous_char_was_slash continue; // Ignore double slashes
                    previous_char_was_slash = true;
                } else {
                    previous_char_was_slash = false;
                }
                
                append(*b, c);
            }
            
            full_path = builder_to_string(*b);
        } else {
            full_path = copy_string(file.full_name);
        }
        
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

    // Scan the current folder
    visit_files(dir_path, recursive = false, null, visitor_func, visit_directories = true);
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

#scope_export

open_file_dialog: Open_File_Dialog;

#scope_file

Open_File_Dialog :: struct {
    initted := false;

    mode: Mode;
    scroll_to_cursor: Scroll_Mode = .no;

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

Entry :: struct {
    buffer_id := -1;  // not all entries have buffers
    using file: File_Info;
    flags: enum_flags u8 {  // TODO: remove and just use the buffer pointer, now it should be safe
        MODIFIED;
        MODIFIED_ON_DISK;
    }
    type: enum u8 { file; folder; drive; project_dir; nothing; } = .file;
    entry_name: string;
    name_highlights: [] bool;
    path_highlights: [] bool;
    sort_key: u64;
}
