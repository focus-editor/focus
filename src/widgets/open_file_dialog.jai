open_file_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    using open_file_dialog;

    if event.type == .KEYBOARD && event.key_pressed {
        action := map_event_to_action(event, Action_Open_File_Dialog);
        if action == {
            case .escape;                   #through;
            case .close_dialog;             close_open_file_dialog(.CANCEL);                                               return true;
            case .close_editor;             maybe_close_file_under_cursor();                                               return true;

            case .open_entry;               open_file_dialog_open_entry(entries.selected, .in_place);                      return true;
            case .open_entry_in_side_pane;  if mode != .save  open_file_dialog_open_entry(entries.selected, .on_the_side); return true;

            case .switch_to_left_pane;      if mode != .save  open_file_dialog_open_entry(entries.selected, .left);        return true;
            case .switch_to_right_pane;     if mode != .save  open_file_dialog_open_entry(entries.selected, .right);       return true;
            case .switch_to_top_pane;       if mode != .save  open_file_dialog_open_entry(entries.selected, .top);         return true;
            case .switch_to_bottom_pane;    if mode != .save  open_file_dialog_open_entry(entries.selected, .bottom);      return true;

            case .switch_to_pane_1;         open_file_dialog_open_entry_in_pane(entries.selected, 1);                      return true;
            case .switch_to_pane_2;         open_file_dialog_open_entry_in_pane(entries.selected, 2);                      return true;
            case .switch_to_pane_3;         open_file_dialog_open_entry_in_pane(entries.selected, 3);                      return true;
            case .switch_to_pane_4;         open_file_dialog_open_entry_in_pane(entries.selected, 4);                      return true;
            case .switch_to_pane_5;         open_file_dialog_open_entry_in_pane(entries.selected, 5);                      return true;
            case .switch_to_pane_6;         open_file_dialog_open_entry_in_pane(entries.selected, 6);                      return true;
            case .switch_to_pane_7;         open_file_dialog_open_entry_in_pane(entries.selected, 7);                      return true;
            case .switch_to_pane_8;         open_file_dialog_open_entry_in_pane(entries.selected, 8);                      return true;
            case .switch_to_pane_9;         open_file_dialog_open_entry_in_pane(entries.selected, 9);                      return true;

            case .open_entry_in_explorer;   open_file_dialog_open_entry_in_explorer(entries.selected);                     return true;

            case .open_directory;           handled := open_file_dialog_open_entry(entries.selected, .in_place, folder_only = true, slash_key_pressed = (event.key_code == #char "/"));
                                            return handled;

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

        text_input_type_char(*open_file_dialog.input, char);
        refresh_entries(clear_input = false);
        return true;
    }
    return false;
}

init_open_file_dialog :: () {
    // There used to be more stuff here
    open_file_dialog.initted = true;
    refresh_entries(clear_input = false);
}

deinit_open_file_dialog :: () {
    using open_file_dialog;

    initted = false;

    clear_path_chunks();

    reset(*memory_pool);

    scroll_to_cursor = .snap;
    entries.scroll_y = 0;
    entries.selected = 0;
    array_reset(*entries.filtered,, allocator = Allocator.{ proc = flat_pool_allocator_proc, data = *memory_pool });
}

open_file_dialog_maybe_refresh_entries :: inline () {
    if !open_file_dialog.should_refresh_entries return;
    refresh_entries(clear_input = false);
    open_file_dialog.should_refresh_entries = false;
}

show_open_file_dialog :: (mode: Open_File_Dialog.Mode, buffer_id_to_save: s64 = -1, triggered_by: Deferred_Action_Id = -1, from_root := false) {
    if !from_root {
        // Derive the path chunks from the current open file
        editor, buffer := get_visible_editor_and_buffer();
        if active_global_widget == .editors && buffer && buffer.has_file then set_path_chunks_from_file(buffer.file.full_path);
    } else {
        clear_path_chunks();
    }

    active_global_widget = .open_file_dialog;

    if mode == .save || mode == .move then assert(triggered_by >= 0);  // must only happen in deferred actions

    open_file_dialog.triggered_by_action = triggered_by;
    open_file_dialog.result = .PENDING;
    open_file_dialog.selected_path = "";
    open_file_dialog.mode = mode;
    open_file_dialog.buffer_id_to_save = buffer_id_to_save;

    refresh_entries();

    if open_file_dialog.mode == .open_editors && open_file_dialog.entries.filtered.count >= 2 {
        open_file_dialog.entries.selected = 1;
    }
}

close_open_file_dialog :: (result: Open_File_Dialog.Result, selected_path := "") {
    open_file_dialog.result = result;

    if open_file_dialog.selected_path {
        free(open_file_dialog.selected_path);
        open_file_dialog.selected_path = "";
    }
    if selected_path then open_file_dialog.selected_path = copy_string(selected_path);

    activate_editors();
}

open_file_dialog_get_result :: (action_id: Deferred_Action_Id) -> Open_File_Dialog.Result, string {
    if action_id != open_file_dialog.triggered_by_action  return .UNINITTED, "";
    if active_global_widget != .open_file_dialog && open_file_dialog.result == .PENDING then close_open_file_dialog(.CANCEL);
    return open_file_dialog.result, open_file_dialog.selected_path;
}

open_file_dialog_open_entry :: (selected: s64, placement: Editor_Placement, folder_only := false, slash_key_pressed := false) -> handled: bool {
    using open_file_dialog;

    // If we are in search mode we want the "/" to show up as text in the search bar, instead of eating it
    if mode == .search && slash_key_pressed return false;

    if selected >= entries.filtered.count   return true;

    entry := entries.filtered[selected];

    if path_chunks.count == 0 && slash_key_pressed {
        // We are selecting our first chunk and we just pushed the "/" key.
        // In this special case, we will open "/" (the root dir) if it is in the list.
        for entries.filtered {
            if it.entry_name == "/" {
                entry = it;
                break;
            }
        }
    }

    if entry.type == {
        case .save;
            if folder_only return true;
            if mode == .save || mode == .move {
                close_open_file_dialog(.SELECTED_PATH, tprint("%/%", get_current_folder_path(), to_string(input.text)));
            }

        case .file;
            if folder_only return true;
            if mode != .save && mode != .move {
                if mode == .open_editors && placement == .in_place && entry.buffer_id >= 0 {
                    editors_show_existing_buffer(entry.buffer_id);
                } else {
                    if entry.buffer_id >= 0 {
                        editors_open_buffer(entry.buffer_id, placement);
                    } else {
                        editors_open_file(entry.full_path, placement);
                    }
                }
            }
            close_open_file_dialog(.SELECTED_PATH, entry.full_path);

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

    return true;
}

open_file_dialog_open_entry_in_pane :: (selected: s64, number: s64) {
    using open_file_dialog;
    if mode == .save || mode == .move return;

    target_pane := editors_find_pane_by_number(number);
    if !target_pane {
        add_user_error("Pane number % doesn't exist", number, dismiss_in_seconds = 3);
        return;
    }

    if selected >= entries.filtered.count  return;
    entry := entries.filtered[selected];

    if entry.type == .file {
        if entry.buffer_id >= 0 {
            editors_open_buffer_in_pane(entry.buffer_id, target_pane);
        } else {
            editors_open_file_in_pane(entry.full_path, target_pane);
        }
        activate_pane(target_pane);
        close_open_file_dialog(.SELECTED_PATH, entry.full_path);
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

maybe_close_file_under_cursor :: () {
    using open_file_dialog;

    if mode == .search then add_user_warning("Closing buffers in this dialog is not supported", dismiss_in_seconds=3);
    if mode != .open_editors return;

    if !entries.filtered return;

    buffer_id  := entries.filtered[entries.selected].buffer_id;

    for editor, editor_id : open_editors {
        if editor.buffer_id != buffer_id continue;
        close_editor_by_id(editor_id);
    }

    refresh_entries(clear_input = false);
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
    if (mode != .navigate && mode != .save && mode != .move) || !is_empty(input.text) || !path_chunks return false;

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

    for chunk : split(parent_dir, cast(u8) #char "/",, allocator = temp) {
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

    entries_allocator := Allocator.{ proc = flat_pool_allocator_proc, data = *memory_pool };
    push_allocator(entries_allocator);

    reset(*memory_pool);  // to avoid having to free each string

    // Scan folder on every keystroke, that should be ok because we don't do it recursively.
    // It also means we will always have the most recent contents of the dir and can use the memory pool
    scan_current_folder();

    scroll_to_cursor = .snap;
    entries.scroll_y = 0;
    entries.selected = 0;
    array_reset(*entries.filtered);

    // This bit will be set when we want to make sure an entry appears on top
    top_priority_bit: u64 = 1 << 62;  // NOT the topmost bit because we'll be converting to s64 later

    maybe_add_a_buffer_entry :: (buffer: Buffer, buffer_id: s64) #expand {
        // @MEMORY SAFETY: if we ever delete buffers from open_buffers and free memory, this will have to copy everything!
        if (buffer.deleted && !buffer.modified) || buffer.internal continue;

        buffer_name := get_buffer_name(buffer);
        name_score, name_highlights, exact_match := fuzzy_match(buffer_name,      filter);
        path_score, path_highlights              := fuzzy_match(buffer.file.path, filter, only_exact=exact_match);
        score := 200 * name_score + path_score;  // name score is much more important
        if score <= 0 && filter.full_string continue;

        entry := array_add(*entries.filtered);
        entry.buffer_id = buffer_id;
        entry.file = buffer.file;
        entry.entry_name = buffer_name;
        if !buffer.has_file {
            entry.entry_name = copy_string(buffer_name);
            entry.icon = Icon.text;
        }
        entry.name_highlights = name_highlights;
        entry.path_highlights = path_highlights;
        // NOTE: there's space left in the sort key in case we need to add more parameters
        score_part:      u64 = (cast,trunc(u64) score)                              << 22;
        dir_id_part:     u64 = (cast,trunc(u64) (63 - buffer.file.project_dir_id))  << 16;
        length_part:     u64 = (cast,trunc(u64) (400 - buffer_name.count))          <<  8;
        times_open_part: u64 = (cast,trunc(u64) buffer.num_times_opened)            <<  0;
        if !filter.full_string then length_part = 0;  // don't sort by length when no filtering is applied
        entry.sort_key = dir_id_part | score_part | length_part | times_open_part;

        if buffer.modified         then { entry.flags |= .MODIFIED;         entry.sort_key |= top_priority_bit; }
        if buffer.modified_on_disk then { entry.flags |= .MODIFIED_ON_DISK; entry.sort_key |= top_priority_bit; }
    }

    filter := construct_fuzzy_filter(to_string(input.text), multi_chunk_search = true);

    if #complete mode == {
        case .save; #through;
        case .move; #through;
        case .navigate;
            if !path_chunks {
                // Display project dirs and drives
                for project_dirs {
                    score, name_highlights := fuzzy_match(it.name, filter);
                    if score <= 0 && filter.full_string continue;
                    if filter.full_string then score -= xx it.name.count;  // prefer shorter name all other things being equal

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
                for project_files {
                    path, _, extension, name := path_decomp(it);
                    score, name_highlights := fuzzy_match(name, filter);
                    if score <= 0 && filter.full_string continue;
                    if filter.full_string then score -= xx name.count;  // prefer shorter name all other things being equal

                    entry := array_add(*entries.filtered);
                    entry.type = .file;
                    entry.full_path = it;
                    entry.name = name;
                    entry.entry_name = name;
                    entry.path = trim_right(path, "/");
                    entry.icon = get_file_icon(name, extension);
                    entry.project_dir_id = xx (it_index + 1 + project_dirs.count);
                    entry.name_highlights = name_highlights;
                    entry.path_highlights = NewArray(entry.path.count, bool);

                    dir_id_part: u64 = (cast,trunc(u64) (127 - entry.project_dir_id)) << 56;
                    score_part:  u64 = (cast,trunc(u64) score)                        << 16;
                    entry.sort_key = dir_id_part | score_part;
                }
                for platform_enumerate_logical_drives() {
                    name := copy_string(it);

                    score, name_highlights := fuzzy_match(name, filter);
                    if score <= 0 && filter.full_string continue;
                    if filter.full_string then score -= xx name.count;  // prefer shorter name all other things being equal

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
                    score, name_highlights := fuzzy_match(it.name, filter);
                    if score <= 0 && filter.full_string continue;
                    if filter.full_string then score -= xx it.name.count;  // prefer shorter name all other things being equal

                    entry := array_add(*entries.filtered);
                    <<entry = it;

                    entry.entry_name = entry.name;
                    entry.name_highlights = name_highlights;
                    entry.path_highlights = .[];

                    // If we have a buffer for this file we want to show if it's modified or modified on disk
                    buffer_id := find_buffer_id_by_path(entry.full_path);
                    if buffer_id >= 0 {
                        buffer := *open_buffers[buffer_id];
                        if buffer.modified         then entry.flags |= .MODIFIED;
                        if buffer.modified_on_disk then entry.flags |= .MODIFIED_ON_DISK;
                    }

                    is_dir_part: u64 = (cast,trunc(u64) (entry.type == .folder)) << 56;  // directories come first
                    score_part:  u64 = (cast,trunc(u64) score)                   << 16;
                    entry.sort_key = is_dir_part | score_part;
                }
            }

        case .search;
            for buffer, buffer_id : open_buffers {
                maybe_add_a_buffer_entry(buffer, buffer_id);
            }

        case .open_editors;
            for buffer_id : most_recent_buffers {
                buffer := *open_buffers[buffer_id];
                maybe_add_a_buffer_entry(buffer, buffer_id);
            }
    }

    if (mode == .save || mode == .move) && !is_empty(input.text) && path_chunks {
        entry_name: string;
        if mode == .save {
            entry_name = sprint("Save as '%/%'", get_current_folder_path(), to_string(input.text));
        } else {
            entry_name = sprint("Move to '%/%'", get_current_folder_path(), to_string(input.text));
        }
        array_add(*entries.filtered, Entry.{
            file = File_Info.{ full_path = "", name = "", path = "", icon = .save },
            entry_name = entry_name,
            type = .save,
            name_highlights = .[],
            path_highlights = .[],
            sort_key = (1 << 55),  // show after directories but before files (so that people can easily descend into dirs but save as a new file by default)
        });
    }

    if !(mode == .open_editors && !input.text) {  // don't sort most recent buffers if no filters are used

        compare_entries :: (e1: Entry, e2: Entry) -> s64 {
            key_diff := cast,no_check(s64) e2.sort_key - cast,no_check(s64) e1.sort_key;
            if key_diff != 0 return key_diff;
            return memcmp(e1.name.data, e2.name.data, min(e1.name.count, e2.name.count));
        }

        quick_sort(entries.filtered, compare_entries);
    }

    if !entries.filtered {
        array_add(*entries.filtered, Entry.{
            file = File_Info.{ full_path = "", name = "", path = "", icon = .dots, },
            type = .nothing,
            name_highlights = .[],
            path_highlights = .[],
        });
    }
}

get_current_folder_path :: () -> string {
    using open_file_dialog;

    if !path_chunks return "";

    dir_path: string;

    if root_dir {
        path_chunks_trimmed := array_view(path_chunks, 1, path_chunks.count - 1);
        dir_path = sprint("%/%", root_dir, join(..path_chunks_trimmed, separator = "/"));
    } else {
        if path_chunks[0] == "/" {
            path_chunks_trimmed := array_view(path_chunks, 1, path_chunks.count - 1);
            dir_path = sprint("/%", join(..path_chunks_trimmed, separator = "/"));
        } else {
            dir_path = join(..path_chunks, separator = "/");
        }
    }
    while dir_path != "/" && ends_with(dir_path, #char "/") dir_path.count -= 1;

    return dir_path;
}

scan_current_folder :: () {
    using open_file_dialog;
    if (mode != .navigate && mode != .save && mode != .move) || !path_chunks return;

    assert(context.allocator.proc == flat_pool_allocator_proc, "Open file dialog must use a pool allocator to scan folders. This is a bug.");

    dir_path := get_current_folder_path();

    // Reset current files
    array_reset(*current_files);

    visitor_func :: (file: *File_Visit_Info, userdata: *void) {
        if file.had_error || file.is_symlink return;

        full_path := copy_string(file.full_name);  // one allocation in the pool, the rest are views into it

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

    target_width := ifx width_percentage != WIDTH_EXPANDED then WIDTH_EXPANDED else WIDTH_NORMAL;
    start_animation(*width_anim, width_percentage, target_width);
}

memory_pool: Flat_Pool;

#scope_export

open_file_dialog: Open_File_Dialog;

#scope_file

Open_File_Dialog :: struct {
    initted := false;
    should_refresh_entries := false;

    mode: Mode;
    triggered_by_action: Deferred_Action_Id = -1;
    result: Result = .UNINITTED;
    selected_path: string;

    scroll_to_cursor: Scroll_Mode = .no;

    input: Text_Input;

    path_chunks: [..] string;
    root_dir: string;
    current_files: [..] Entry;  // files in the current folder (used in .navigate mode only)

    buffer_id_to_save: s64;  // used when `mode` is `.save`

    entries: struct {
        filtered: [..] Entry;
        selected: s64;
        selected_by_mouse: s64 = -1;  // to remember which entry the left mouse button went down on

        scroll_y: s32;
        scroll_anim := #run Tween_Animation(s32).{ duration = 0.1, func = .lerp };
        per_page: s64 = 10;
    }

    width_percentage := WIDTH_NORMAL;  // how much of the screen the popup occupies
    width_anim := #run Tween_Animation(float).{ start = WIDTH_NORMAL, target = WIDTH_NORMAL };
    WIDTH_NORMAL   :: 0.4;
    WIDTH_EXPANDED :: 0.8;

    Mode :: enum {
        search;
        open_editors;
        navigate;
        save;
        move;
    }

    Result :: enum {
        UNINITTED;
        PENDING;
        SELECTED_PATH;
        CANCEL;
    }
}

Entry :: struct {
    buffer_id := -1;  // not all entries have buffers
    using file: File_Info;
    flags: enum_flags u8 {  // TODO: remove and just use the buffer pointer, now it should be safe
        MODIFIED;
        MODIFIED_ON_DISK;
    }
    type: enum u8 { file; folder; drive; project_dir; save; nothing; } = .file;
    entry_name: string;
    name_highlights: [] bool;
    path_highlights: [] bool;
    sort_key: u64;
}
