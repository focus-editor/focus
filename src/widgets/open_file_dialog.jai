open_file_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    using open_file_dialog;

    open_file_dialog_maybe_refresh_entries();

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

            case .open_directory;           handled := open_file_dialog_open_entry(entries.selected, .in_place, folder_only = true);
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

open_file_dialog_maybe_refresh_entries :: () {
    using open_file_dialog;
    if !should_refresh_entries return;

    // Remember selected entries to preserve them
    old_selected_index := entries.selected;
    old_selected_entry := remember_entry(old_selected_index);
    old_pressed_entry  := remember_entry(entries.selected_by_mouse);

    rebuild_entries();

    filtered := entries.filtered;
    entries.selected = clamp(old_selected_index, 0, filtered.count - 1);

    // Try to preserve the old selected entry
    if old_selected_entry.type != .nothing && !entry_matches(*old_selected_entry, *filtered[entries.selected]) {
        for * entry : filtered {
            if entry_matches(*old_selected_entry, entry) {
                entries.selected = it_index;
                break;
            }
        }
    }

    // Try to preserve viewport position
    if entries.selected != old_selected_index {
        old_y := old_selected_index * entries.row_height - entries.scroll_y;
        if old_y < entries.viewport_height && old_y + entries.row_height > 0 {
            delta := cast(s32) ((entries.selected - old_selected_index) * entries.row_height);
            entries.scroll_y += delta;
            entries.scroll_anim.start  += delta;
            entries.scroll_anim.target += delta;
        }
    }

    pressed := entries.selected_by_mouse;
    if pressed >= 0 && (pressed >= filtered.count || !entry_matches(*old_pressed_entry, *filtered[pressed])) {
        entries.selected_by_mouse = -1;  // drop the selected by mouse index only if we lost it
    }
}

show_open_file_dialog :: (mode: Open_File_Dialog.Mode, buffer_id_to_save: Buffer_Id = -1, triggered_by: Deferred_Action_Id = -1, from_root := false) {
    if from_root {
        clear_path_chunks();
    } else if mode == .save || mode == .move {
        source := get_buffer(buffer_id_to_save);
        if !source.has_file || !source.file.full_path {
            _, source = find_buffer(editors.last_file_backed_buffer_id);
        }
        if source && source.has_file && source.file.full_path {
            set_path_chunks_from_file(source.file.full_path);
        } else {
            clear_path_chunks();
        }
    } else {
        editor, buffer := get_visible_editor_and_buffer();
        if active_global_widget == .editors && buffer && buffer.has_file then set_path_chunks_from_file(buffer.file.full_path);
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

open_file_dialog_open_entry :: (selected: s64, placement: Editor_Placement, folder_only := false) -> handled: bool {
    using open_file_dialog;

    if selected >= entries.filtered.count   return true;

    entry := entries.filtered[selected];

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

open_file_dialog_invalidate_file :: (path: string) {
    using open_file_dialog;
    if active_global_widget != .open_file_dialog || should_refresh_entries return;

    if mode == .search || mode == .open_editors {
        should_refresh_entries = true;
        return;
    }

    if !path || !path_chunks return;

    push_allocator(temp);
    should_refresh_entries = platform_path_equals(get_parent_dir_path(path), get_current_folder_path());
}

open_file_dialog_invalidate_buffer :: inline (buffer: Buffer) {
    if buffer.internal return;
    open_file_dialog_invalidate_file(ifx buffer.has_file then buffer.file.full_path else "");
}

open_file_dialog_invalidate_directory :: (changes: [] File_Change) {
    using open_file_dialog;
    if active_global_widget != .open_file_dialog || should_refresh_entries return;
    if mode == .search || mode == .open_editors || !path_chunks return;

    push_allocator(temp);
    folder := get_current_folder_path();
    for change : changes {
        path := trim_right(change.full_path, "/");
        if !path then path = change.full_path;

        if (change.events & (.ADDED | .REMOVED | .MOVED)) && platform_path_equals(get_parent_dir_path(path), folder) {
            should_refresh_entries = true;
            return;
        }
        if (change.events & (.REMOVED | .MOVED | .SCAN_CHILDREN)) && path_is_within_other_path(folder, path) {
            should_refresh_entries = true;
            return;
        }
    }
}

construct_open_file_dialog_filter :: (query: string) -> Fuzzy_Filter {
    case_sensitive := open_file_dialog.mode == .search &&
                      context.config.settings.search_is_case_sensitive_when_uppercase_present &&
                      contains_uppercase_ascii(query);
    return construct_fuzzy_filter(query, multi_chunk_search = true, case_sensitive = case_sensitive);
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

    for editor : open_editors {
        if editor.buffer_id != buffer_id continue;
        defer_action_close_editor(editor.id);
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

    is_project_dir, project_dir := path_is_within_project(parent_dir);
    if is_project_dir {
        root_dir = project_dir.path;
        array_add(*path_chunks, copy_string(project_dir.name));
    } else {
        #if OS != .WINDOWS then array_add(*path_chunks, copy_string("/"));
        root_dir = "";
    }

    advance(*parent_dir, project_dir.path.count);

    for chunk : split(parent_dir, cast(u8) #char "/",, allocator = temp) {
        if !chunk continue;
        array_add(*path_chunks, copy_string(chunk));
    }
}

clear_path_chunks :: () {
    open_file_dialog.root_dir = "";

    for open_file_dialog.path_chunks free(it);
    array_reset(*open_file_dialog.path_chunks);
}

refresh_entries :: (clear_input := true) {
    using open_file_dialog;

    if clear_input then text_input_fully_clear(*input);

    scroll_to_cursor = .snap;
    entries.scroll_y = 0;
    entries.scroll_anim.target = 0;
    entries.selected = 0;
    entries.selected_by_mouse = -1;

    rebuild_entries();
}

rebuild_entries :: () {
    using open_file_dialog;
    should_refresh_entries = false;

    entries_allocator := Allocator.{ proc = flat_pool_allocator_proc, data = *memory_pool };
    push_allocator(entries_allocator);

    reset(*memory_pool);  // to avoid having to free each string

    // Scan folder on every keystroke, that should be ok because we don't do it recursively.
    // It also means we will always have the most recent contents of the dir and can use the memory pool
    scan_current_folder();

    array_reset(*entries.filtered);

    // This bit will be set when we want to make sure an entry appears on top
    top_priority_bit: u64 = 1 << 62;  // NOT the topmost bit because we'll be converting to s64 later

    query  := to_string(input.text);
    filter := construct_open_file_dialog_filter(query);
    use_search_score := mode == .search && filter.chunks.count > 0 &&
                        find_index_from_left(query, #char "/")  < 0 &&
                        find_index_from_left(query, #char "\\") < 0;

    maybe_add_a_buffer_entry :: (buffer: Buffer) #expand {
        // @MEMORY SAFETY: if we ever delete buffers from open_buffers and free memory, this will have to copy everything!
        if (buffer.deleted && !buffer.modified) || buffer.internal continue;

        buffer_name := get_buffer_name(buffer);
        score: s32;
        search_score: Search_Score;
        if use_search_score {
            search_score = get_search_score(buffer_name, buffer.file.path, filter);
            if search_score.priority_sum == 0 continue;
        } else {
            name_score, exact_match := fuzzy_match(buffer_name, filter);
            path_score              := fuzzy_match(buffer.file.path, filter, only_exact = exact_match);
            score = 200 * name_score + path_score;
            if score <= 0 && filter.full_string continue;
        }

        entry := array_add(*entries.filtered);
        entry.buffer_id = buffer.id;
        entry.file = buffer.file;
        entry.entry_name = buffer_name;
        if !buffer.has_file {
            entry.entry_name = copy_string(buffer_name);
            entry.icon = Icon.text;
        }

        if buffer.modified          then entry.flags |= .MODIFIED;
        if buffer.modified_on_disk  then entry.flags |= .MODIFIED_ON_DISK;

        if use_search_score {
            entry.search_score = search_score;
            continue;
        }

        // Sort open editors on top
        // @speed: could become slow if too many open buffers
        _, most_recent_buffer_index := array_find(most_recent_buffers, buffer.id);
        if most_recent_buffer_index >= 0 {
            most_recent_buffer_index = most_recent_buffers.count - most_recent_buffer_index;
        } else {
            most_recent_buffer_index = 0;
        }

        member_order := min(buffer.file.workspace_member_index.(int) + 1, 63);

        score_part:      u64 = (cast,trunc(u64) score)                              << 32;
        member_part:     u64 = (cast,trunc(u64) (63 - member_order))                << 24;
        length_part:     u64 = (cast,trunc(u64) (400 - buffer_name.count))          << 16;
        // TODO: put it after score but before other things
        opened_part:     u64 = (cast,trunc(u64) (most_recent_buffer_index + 1))     <<  0;

        if !filter.full_string then length_part = 0;  // don't sort by length when no filtering is applied
        entry.sort_key = member_part | score_part | length_part | opened_part;

        if buffer.modified || buffer.modified_on_disk then entry.sort_key |= top_priority_bit;
    }

    if #complete mode == {
        case .save; #through;
        case .move; #through;
        case .navigate;
            if !path_chunks {
                // Display project dirs and drives
                next_dir_order  := workspace_members.count;
                next_file_order := workspace_members.count;

                for workspace_members {
                    if it.is_directory then next_file_order -= 1;
                }

                for member, member_index : workspace_members {
                    member_order: int;
                    if member.is_directory {
                        member_order = next_dir_order;
                        next_dir_order -= 1;
                    } else {
                        member_order = next_file_order;
                        next_file_order -= 1;
                    }

                    score := fuzzy_match(member.name, filter);
                    if score <=0 && filter.full_string continue;
                    if filter.full_string then score -= xx member.name.count;

                    entry := array_add(*entries.filtered);
                    entry.full_path = member.path;
                    entry.name = member.name;
                    entry.entry_name = member.name;
                    entry.workspace_member_index = member_index.(s16);

                    if member.is_directory {
                        entry.type = .project_dir;
                        entry.path = member.path;
                        entry.icon = .folder;
                    } else {
                        path, _, extension := path_decomp(member.path);
                        entry.type = .file;
                        entry.path = trim_right(path, "/");
                        entry.icon = get_file_icon(member.name, extension);
                    }

                    // Leave bits 16 .. 46 for the nonnegative s32 score
                    member_part: u64 = (cast,trunc(u64) member_order)  << 47;
                    score_part:  u64 = (cast,trunc(u64) max(score, 0)) << 16;
                    entry.sort_key = member_part | score_part;
                }

                for platform_enumerate_logical_drives() {
                    name := copy_string(it);

                    score := fuzzy_match(name, filter);
                    if score <= 0 && filter.full_string continue;
                    if filter.full_string then score -= xx name.count;  // prefer shorter name all other things being equal

                    entry := array_add(*entries.filtered);
                    entry.type = .drive;
                    entry.full_path = "";
                    entry.name = name;
                    entry.entry_name = name;
                    entry.path = "";
                    entry.icon = .drive;

                    entry.sort_key = (cast(u64) max(score, 0)) << 16;
                }
            } else {
                // Filter current files
                for current_files {
                    score := fuzzy_match(it.name, filter);
                    if score <= 0 && filter.full_string continue;
                    if filter.full_string then score -= xx it.name.count;  // prefer shorter name all other things being equal

                    entry := array_add(*entries.filtered);
                    entry.* = it;

                    entry.entry_name = entry.name;

                    // If we have a buffer for this file we want to show if it's modified or modified on disk
                    buffer_id := find_buffer_id_by_path(entry.full_path);
                    if buffer_id >= 0 {
                        buffer := get_buffer(buffer_id);
                        if buffer.modified         then entry.flags |= .MODIFIED;
                        if buffer.modified_on_disk then entry.flags |= .MODIFIED_ON_DISK;
                    }

                    is_dir_part: u64 = (cast,trunc(u64) (entry.type == .folder)) << 56;  // directories come first
                    score_part:  u64 = (cast,trunc(u64) score)                   << 16;
                    entry.sort_key = is_dir_part | score_part;
                }
            }

        case .search;
            // When there's text in the filter input, search in all workspace buffers
            for buffer : open_buffers {
                maybe_add_a_buffer_entry(buffer);
            }

        case .open_editors;
            for buffer_id : most_recent_buffers {
                buffer := get_buffer(buffer_id);
                maybe_add_a_buffer_entry(buffer);
            }
    }

    if (mode == .save || mode == .move) && !is_empty(input.text) && path_chunks {
        folder_path := ifx get_current_folder_path() != "/" else "";
        entry_name: string;
        if mode == .save {
            entry_name = sprint("Save as '%/%'", folder_path, to_string(input.text));
        } else {
            entry_name = sprint("Move to '%/%'", folder_path, to_string(input.text));
        }
        array_add(*entries.filtered, Entry.{
            file = File_Info.{ full_path = "", name = "", path = "", icon = .save },
            entry_name = entry_name,
            type = .save,
            sort_key = (1 << 55),  // show after directories but before files (so that people can easily descend into dirs but save as a new file by default)
        });
    }

    if use_search_score {
        quick_sort(entries.filtered, compare_search_entries);
    } else if !(mode == .open_editors && !input.text) {  // don't sort most recent buffers if no filters are used
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
        });
    }
}

remember_entry :: (index: int) -> Entry {
    filtered := open_file_dialog.entries.filtered;
    if index < 0 || index >= filtered.count return Entry.{ type = .nothing };

    entry := *filtered[index];
    if entry.buffer_id >= 0 return Entry.{ buffer_id = entry.buffer_id };
    if entry.type == .drive return Entry.{ type = .drive, name = copy_temporary_string(entry.name) };
    return Entry.{ type = entry.type, full_path = copy_temporary_string(entry.full_path) };
}

entry_matches :: (target: *Entry, entry: *Entry) -> bool {
    if target.type == .nothing || target.type != entry.type return false;
    if target.buffer_id >= 0 return target.buffer_id == entry.buffer_id;
    if target.type == .drive return platform_path_equals(target.name, entry.name);
    if target.type == .save return true;
    return platform_path_equals(target.full_path, entry.full_path);
}

get_best_search_match :: (name: string, path: string, chunk: Fuzzy_Filter.Chunk, case_sensitive: bool) -> Search_Match {
    name_match := fuzzy_match_chunk(name, chunk, case_sensitive);
    if name_match.kind == .prefix       return Search_Match.{ priority = .name_prefix,      chunk_match = name_match };
    if name_match.kind == .substring    return Search_Match.{ priority = .name_substring,   chunk_match = name_match };

    path_match := fuzzy_match_chunk(path, chunk, case_sensitive);
    if path_match.kind == .prefix || path_match.kind == .substring  return Search_Match.{ priority = .path_substring, chunk_match = path_match };

    if name_match.kind == .scattered return Search_Match.{ priority = .name_scattered, chunk_match = name_match };
    if path_match.kind == .scattered return Search_Match.{ priority = .path_scattered, chunk_match = path_match };

    if case_sensitive || !path || !name return .{};

    // If neither field matches alone, a term can still span the folder and filename
    auto_release_temp();
    path_and_name := tprint("%/%", trim_right(path, "/"), name);
    path_match = fuzzy_match_chunk(path_and_name, chunk, case_sensitive);
    if path_match.kind != .none return Search_Match.{ priority = .path_scattered, chunk_match = path_match };

    return .{};
}

get_search_score :: (name: string, path: string, filter: Fuzzy_Filter) -> Search_Score {
    result: Search_Score;

    for chunk : filter.chunks {
        search_match := get_best_search_match(name, path, chunk, filter.case_sensitive);
        if search_match.priority == .none return .{};

        chunk_match := search_match.chunk_match;
        result.priority_sum   += search_match.priority.(int);
        result.adjacent_pairs += chunk_match.adjacent_pairs;
        result.skipped_bytes  += chunk_match.skipped_bytes;
        result.text_count     += chunk_match.text_count;
        result.offset_sum     += chunk_match.offset;
    }

    return result;
}

compare_search_entries :: (e1: Entry, e2: Entry) -> s64 {
    s1 := e1.search_score;
    s2 := e2.search_score;

    if s1.priority_sum   != s2.priority_sum   return s2.priority_sum   - s1.priority_sum;
    if s1.adjacent_pairs != s2.adjacent_pairs return s2.adjacent_pairs - s1.adjacent_pairs;
    if s1.skipped_bytes  != s2.skipped_bytes  return s1.skipped_bytes  - s2.skipped_bytes;

    member1 := cast,trunc(u16) e1.workspace_member_index;
    member2 := cast,trunc(u16) e2.workspace_member_index;
    if member1 != member2 return member1.(s64) - member2.(s64);

    if e1.workspace_depth != e2.workspace_depth return e1.workspace_depth.(s64) - e2.workspace_depth.(s64);

    if s1.text_count != s2.text_count return s1.text_count - s2.text_count;  // shorter is better
    if s1.offset_sum != s2.offset_sum return s1.offset_sum - s2.offset_sum;

    name_order := compare_strings(e1.entry_name, e2.entry_name);
    if name_order != 0 return name_order;

    return compare_strings(e1.full_path, e2.full_path);
}

get_current_folder_path :: () -> string {
    using open_file_dialog;

    if !path_chunks return "";

    dir_path: string;

    if root_dir {
        path_chunks_trimmed := array_view(path_chunks, 1, path_chunks.count - 1);
        dir_path = sprint("%/%", root_dir, join(..path_chunks_trimmed, separator = "/"));
    } else {
        dir_path = join(..path_chunks, separator = "/");
    }
    while starts_with(dir_path, "//") advance(*dir_path);
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
        entry.workspace_member_index = find_workspace_member_index(full_path);
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

    buffer_id_to_save: Buffer_Id;  // used when `mode` is `.save`

    entries: struct {
        filtered: [..] Entry;
        selected: s64;
        selected_by_mouse: s64 = -1;  // to remember which entry the left mouse button went down on

        scroll_y: s32;
        scroll_anim := #run Tween_Animation(s32).{ duration = 0.1, func = .lerp };
        per_page: s64 = 10;
        row_height: float;
        viewport_height: float;
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
    buffer_id: Buffer_Id = -1;  // not all entries have buffers
    using file: File_Info;
    flags: enum_flags u8 {  // TODO: remove and just use the buffer pointer, now it should be safe
        MODIFIED;
        MODIFIED_ON_DISK;
    }
    type: enum u8 { file; folder; drive; project_dir; save; nothing; } = .file;
    entry_name: string;
    sort_key:   u64;
    search_score: Search_Score;
}

Search_Score :: struct {
    priority_sum:   int;
    adjacent_pairs: int;
    skipped_bytes:  int;
    text_count:     int;
    offset_sum:     int;
}

Search_Match :: struct {
    priority: enum {  // weakest to strongest
        none;
        path_scattered;
        name_scattered;
        path_substring;
        name_substring;
        name_prefix;
    } = .none;

    chunk_match: Fuzzy_Chunk_Match;
}

