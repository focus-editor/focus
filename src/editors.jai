#add_context current_editor_id := -1;

editors_handle_event :: (event: Input.Event) -> handled: bool {
    mods := event.modifier_flags;

    context.current_editor_id = editors.active;
    defer context.current_editor_id = -1;

    if event.type == {
        case .KEYBOARD;
            if event.key_pressed {
                action, mapping := map_event_to_action(event, Action_Editors);
                return active_editor_handle_event(event, action);
            } else {
                hold_actions_to_be_stopped := map_key_release_to_hold_actions(event, Action_Editors);
                for hold_actions_to_be_stopped {
                    if it == {
                        case .scroll_viewport_up;           #through;
                        case .scroll_viewport_up_fast;      if editor_smooth_scroll.direction == .up then editor_smooth_scroll.direction = .none;

                        case .scroll_viewport_down;         #through;
                        case .scroll_viewport_down_fast;    if editor_smooth_scroll.direction == .down then editor_smooth_scroll.direction = .none;

                        case .scroll_viewport_left;         if editor_smooth_scroll.direction == .left then editor_smooth_scroll.direction = .none;
                        case .scroll_viewport_right;        if editor_smooth_scroll.direction == .right then editor_smooth_scroll.direction = .none;
                    }
                }
                // @Incomplete: Does stopping hold actions actually count as handling an event in the sense that it should suppress other event handlers?
                return hold_actions_to_be_stopped.count > 0;
            }

        case .TEXT_INPUT;
            if !key_sequence_input_state.key_sequence_in_progress {
                active_editor_type_char(event.utf32);
                return true;
            }
    }

    return false;
}



activate_editors :: () {
    active_global_widget = .editors;
    cursors_start_blinking();
}

editors_handle_file_drop :: (files: [] string) {
    if editors.layout == .Double && files.count == 1 {
        // Open file in the closest editor - will be handled by the drawing code because we only know the layout then
        just_dropped_file = files[0];
    } else {
        if files.count == 1 {
            // When one file, open in a single editor
            editors_open_file(files[0]);
        } else {
            // When more than 2 files, open all of them, but put the first 2 side by side
            for 1..files.count-1 {
                editors_open_file(files[it]);  // create a buffer and an editor
            }
            editors_open_file(files[0], .left);
            editors_open_file(files[1], .right);
        }
    }
}

active_editor_handle_event :: (event: Input.Event, action: Action_Editors) -> handled: bool {
    editor, buffer := get_active_editor_and_buffer();
    if !editor return false;

    shift_pressed := event.modifier_flags.shift_pressed;
    ctrl_pressed  := event.modifier_flags.ctrl_pressed;

    if editor.search_bar.active {
        using editor.search_bar;
        old_search_str := copy_temporary_string(to_string(input.text));
        handled := text_input_handle_event(*input, event);
        if handled {
            if old_search_str != to_string(input.text) then search_and_update_results(editor, buffer, jump = true);
            return true;
        }

        action := map_event_to_action(event, Action_Search_Dialog);

        if action == {
            case .toggle_expand;                    search_bar_toggle_expand(editor);                                             return true;
            case .toggle_case_sensitive;            search_bar_toggle_case_sensitive(editor, buffer);                             return true;
            case .toggle_whole_word;                search_bar_toggle_whole_word(editor, buffer);                                 return true;

            case .search_in_buffer;                 open_search_bar(editor, buffer, remember_cursor_position = false);            return true;
            case .search_in_buffer_dropdown_mode;   open_search_bar(editor, buffer, .dropdown, remember_cursor_position = false); return true;

            case .move_up;                          search_bar_move_cursor(editor, buffer, -1, wrap = true);                      return true;
            case .move_down;                        search_bar_move_cursor(editor, buffer,  1, wrap = true);                      return true;
            case .move_up_fast;                     search_bar_move_cursor(editor, buffer, -5);                                   return true;
            case .move_down_fast;                   search_bar_move_cursor(editor, buffer,  5);                                   return true;

            case .close_current_editor;             close_search_bar(editor); close_current_editor();                             return true;
            case .close_other_editor;               close_other_editor();                                                         return true;
        }

        if mode == .classic {
            if action == {
                case .close_dialog;                 close_search_bar(editor);                                return true;
                case .open_entry_in_place;          search_bar_move_cursor(editor, buffer,  1, wrap = true); return true;
            }
        } else {
            if action == {
                case .close_dialog;                 close_search_bar(editor, jump_to_original_cursor = true);      return true;

                case .move_up_one_page;             search_bar_move_cursor(editor, buffer, -per_page);             return true;
                case .move_down_one_page;           search_bar_move_cursor(editor, buffer,  per_page);             return true;

                case .open_entry_in_place;          close_search_bar(editor);                                      return true;
                case .open_entry_on_the_side;       search_bar_open_selected_result(editor, buffer, .on_the_side); return true;
                case .open_entry_on_the_left;       search_bar_open_selected_result(editor, buffer, .left);        return true;
                case .open_entry_on_the_right;      search_bar_open_selected_result(editor, buffer, .right);       return true;
            }
        }
        return false;
    }

    cursors := editor.cursors;

    // We always want to put some actions in a separate edit group (e.g. block indent)
    new_group := false;
    for cursor : cursors { if new_edit_group_required_for_action(action, cursor) { new_group = true; break; } }
    if new_group || frame_time - buffer.last_edit_time >= EDIT_GROUP_TIMEOUT then new_edit_group(buffer, editor);  // do it before action

    // We want to remember where cursors were before we do any edits
    if buffer.edits.count == 0 {
        array_resize(*buffer.cursors, cursors.count);
        for * cursor, i : buffer.cursors { <<cursor = cursors[i].state; }
    }

    keep_selection := false;
    enabled_whole_words := false;

    if action == {
        // General actions (which are not associated with any cursor)
        case .toggle_expand;                    toggle_expand();
        case .search_in_buffer;                 open_search_bar(editor, buffer);
        case .search_in_buffer_dropdown_mode;   open_search_bar(editor, buffer, .dropdown);
        case .close_current_editor;             close_current_editor();
        case .close_other_editor;               close_other_editor();
        case .save;                             save_buffer(editor, buffer);
        case .save_all;                         save_all   (editor, buffer);
        case .switch_to_left_editor;            switch_to_editor(.left);
        case .switch_to_right_editor;           switch_to_editor(.right);
        case .switch_to_other_editor;           switch_to_editor(.other);
        case .duplicate_editor;                 switch_to_editor(.other, duplicate_current = true);
        case .move_editor_to_the_left;          if editors.active == editors.right then swap_panes();
        case .move_editor_to_the_right;         if editors.active == editors.left  then swap_panes();
        case .center_viewport_on_cursor;        center_viewport_on_cursor           (editor, buffer);
        case .move_cursor_to_viewport_center;   move_cursor_to_viewport_center      (editor, buffer);
        case .remove_additional_cursors;        remove_additional_cursors           (editor);
        case .scroll_viewport_up;               smooth_scroll(editor, direction = .up);                 activate_hold_action(action, event);
        case .scroll_viewport_up_fast;          smooth_scroll(editor, direction = .up, fast = true);    activate_hold_action(action, event);
        case .scroll_viewport_down;             smooth_scroll(editor, direction = .down);               activate_hold_action(action, event);
        case .scroll_viewport_down_fast;        smooth_scroll(editor, direction = .down, fast = true);  activate_hold_action(action, event);
        case .scroll_viewport_left;             smooth_scroll(editor, direction = .left, fast = true);  activate_hold_action(action, event);
        case .scroll_viewport_right;            smooth_scroll(editor, direction = .right, fast = true); activate_hold_action(action, event);
        case .undo;                             undo                                (editor, buffer); keep_selection = true;
        case .redo;                             redo                                (editor, buffer); keep_selection = true;
        case .select_all;                       select_all                          (editor, buffer); keep_selection = true;
        case .create_cursor_above;              create_cursor                       (editor, buffer, .above); keep_selection = true;
        case .create_cursor_below;              create_cursor                       (editor, buffer, .below); keep_selection = true;
        case .move_to_previous_editor_history;  move_to_previous_editor_history     ();
        case .move_to_next_editor_history;      move_to_next_editor_history         ();

        case .select_word;                      select_word(editor, buffer); keep_selection = true;
        case .select_word_or_create_another_cursor; enabled_whole_words = select_word_or_create_another_cursor(editor, buffer); keep_selection = true;

        // Actions that do something per cursor
        case .move_left;                        move_cursors_left                   (editor, buffer, by = .char,      shift_pressed);
        case .move_left_by_word;                move_cursors_left                   (editor, buffer, by = .word,      shift_pressed);
        case .move_left_by_word_ends;           move_cursors_left                   (editor, buffer, by = .word_ends, shift_pressed);
        case .move_right;                       move_cursors_right                  (editor, buffer, by = .char,      shift_pressed);
        case .move_right_by_word;               move_cursors_right                  (editor, buffer, by = .word,      shift_pressed);
        case .move_right_by_word_ends;          move_cursors_right                  (editor, buffer, by = .word_ends, shift_pressed);
        case .move_up;                          move_cursors_vertically             (editor, buffer, -1, shift_pressed);
        case .move_down;                        move_cursors_vertically             (editor, buffer,  1, shift_pressed);
        case .move_up_fast;                     move_cursors_vertically             (editor, buffer, -5, shift_pressed);
        case .move_down_fast;                   move_cursors_vertically             (editor, buffer,  5, shift_pressed);
        case .move_up_to_empty_line;            move_cursors_to_empty_line          (editor, buffer, .up);
        case .move_down_to_empty_line;          move_cursors_to_empty_line          (editor, buffer, .down);
        case .move_up_one_page;                 move_cursors_by_page                (editor, buffer, .up);
        case .move_down_one_page;               move_cursors_by_page                (editor, buffer, .down);
        case .jump_to_line_start;               move_cursors_home                   (editor, buffer);
        case .jump_to_line_end;                 move_cursors_end                    (editor, buffer);
        case .jump_to_file_start;               move_to_file_start                  (editor, buffer);
        case .jump_to_file_end;                 move_to_file_end                    (editor, buffer);

        case .indent_or_go_to_next_tabstop;     indent_or_tab                       (editor, buffer); keep_selection = true;
        case .indent;                           indent_lines                        (editor, buffer); keep_selection = true;
        case .unindent;                         unindent_lines                      (editor, buffer); keep_selection = true;
        case .toggle_comment;                   toggle_comment                      (editor, buffer); keep_selection = true;
        case .select_line;                      select_lines                        (editor, buffer); keep_selection = true;

        case .break_line;                       break_line                          (editor, buffer);
        case .new_line_below_without_breaking;  new_line_below                      (editor, buffer);
        case .new_line_above_without_breaking;  new_line_above                      (editor, buffer);

        case .copy;                             copy_selection_to_clipboard         (editor, buffer);
        case .cut;                              copy_selection_to_clipboard         (editor, buffer, cut = true);
        case .paste;                            paste_from_clipboard                (editor, buffer);

        case .delete_left_char;                 delete_left_char                    (editor, buffer);
        case .delete_right_char;                delete_right_char                   (editor, buffer);
        case .delete_word_left;                 delete_word_left                    (editor, buffer);
        case .delete_word_right;                delete_word_right                   (editor, buffer);
        case .delete_word_left_no_underscore;   delete_word_left_no_underscore      (editor, buffer);
        case .delete_word_right_no_underscore;  delete_word_right_no_underscore     (editor, buffer);

        case .duplicate_lines;                  duplicate_lines                     (editor, buffer); keep_selection = true;
        case .move_selected_lines_up;           move_lines_up                       (editor, buffer); keep_selection = true;
        case .move_selected_lines_down;         move_lines_down                     (editor, buffer); keep_selection = true;

        case .join_lines;                       join_lines                          (editor, buffer);                  keep_selection = true;
        case .join_lines_no_spaces_in_between;  join_lines                          (editor, buffer, in_between = ""); keep_selection = true;

        case .delete_line;                      delete_line                         (editor, buffer);
        case .delete_line_and_go_up;            delete_line                         (editor, buffer, go_up = true);

        case .delete_to_start_of_line;          delete_to_start_of_line             (editor, buffer);
        case .delete_to_end_of_line;            delete_to_end_of_line               (editor, buffer);

        case;                                   return false;
    }

    if new_group then new_edit_group(buffer, editor);  // do it after action

    if is_a_move_action(action) && shift_pressed then keep_selection = true;

    if editor.cursor_moved && !keep_selection {
        for * cursors { it.sel = it.pos; }  // remove selection
    }

    // NOTE: even though we also do it in refresh_open_buffers, we do it here
    // so that if more than one event is processed in the same frame, the next one
    // sees the cursors in valid places and up to date
    if buffer.dirty rescan_for_lines(buffer);
    for * cursors put_cursor_in_valid_spot(it, buffer);
    if cursors.count > 1 then organise_cursors(editor);  // sort and maybe merge overlapping cursors

    if editor.cursor_moved && !enabled_whole_words then editor.search_whole_words = false;
    if editor.cursor_moved then editor.refresh_highlights = true;  // update or remove highlights
    if editor.cursor_moved then cursors_start_blinking();

    return true;
}

active_editor_type_char :: (char: u32) {
    if char == 127 return;  // there seems to be a bug in the Input module
                            // which generates a TEXT_INPUT event for DEL
                            // when Ctrl+Backspace is pressed

    editor, buffer := get_active_editor_and_buffer();
    if !editor return;

    if editor.search_bar.active {
        text_input_type_char(*editor.search_bar.input, char);
        search_and_update_results(editor, buffer, jump = true);
        editor.search_bar.scroll_to_selected = .snap;
        return;
    }

    utf8_char := convert_utf32_to_utf8(char);

    new_group := false;  // we always want to remember cursor state when a selection is replaced with anything
    for editor.cursors { if has_selection(it) { new_group = true; break; } }

    if new_group || frame_time - buffer.last_edit_time >= EDIT_GROUP_TIMEOUT {
        new_edit_group(buffer, editor);
    }

    if buffer.edits.count == 0 {
        // We want to remember where cursors were before we do any edits
        array_resize(*buffer.cursors, editor.cursors.count);
        for * cursor, i : buffer.cursors { <<cursor = editor.cursors[i].state; }
    }

    offset_delta: s32 = 0;
    buf_len := cast(s32) buffer.bytes.count;
    for * cursor : editor.cursors {
        new_len := cast(s32) buffer.bytes.count;
        if new_len != buf_len {
            offset_delta += new_len - buf_len;
            cursor.pos += offset_delta;
            cursor.sel += offset_delta;
            buf_len = new_len;
        }

        if has_selection(cursor) {
            selection := get_selection(cursor);
            delete_range(buffer, selection);
            cursor.pos = selection.start;
        }
        insert_char_at_offset(buffer, cursor.pos, utf8_char);

        cursor.pos = next_char_offset(buffer.bytes, cursor.pos);
        cursor.sel = cursor.pos;
    }

    if new_group then new_edit_group(buffer, editor);  // make sure selection operations have a dedicated group

    rescan_for_lines(buffer);
    if editor.cursors.count > 1 then organise_cursors(editor);
    for * cursor : editor.cursors  cursor.col_wanted = -1;

    buffer.last_edit_time = frame_time;
    editor.cursor_moved = .unimportant;
    cursors_start_blinking();
}

get_active_editor_and_buffer :: () -> *Editor, *Buffer {
    if editors.layout == .None return null, null;
    editor := *open_editors[editors.active];
    buffer := *open_buffers[editor.buffer_id];
    return editor, buffer;
}

refresh_all_editors_for_buffer :: (buffer_id: s64) {
    buffer := *open_buffers[buffer_id];
    for * editor, editor_id : open_editors {
        if editor.buffer_id != buffer_id continue;

        adjust_cursors_and_viewport(editor, buffer, editor_id);
        editor.refresh_highlights = true;
        if search_bar_is_open(editor) search_and_update_results(editor, buffer);
    }
    array_reset_keeping_memory(*buffer.edit_notifications);
}

adjust_cursors_and_viewport :: (editor: *Editor, buffer: Buffer, current_editor_id: s64) {
    // When edits are made in another editor for the same buffer, this editor's cursors
    // need to be adjusted. The viewport glue point also needs to move.
    for edit : buffer.edit_notifications {
        if edit.editor_id == current_editor_id continue;  // this editor's cursors have already moved

        // Adjust viewport
        using edit;
        using editor.viewport.glue_point;
        if buffer_pos >= offset then buffer_pos = max(buffer_pos + delta, offset);

        for * cursor : editor.cursors {
            if cursor.pos >= offset then cursor.pos = max(cursor.pos + delta, offset);
            if cursor.sel >= offset then cursor.sel = max(cursor.sel + delta, offset);
        }
    }

    for *cursor : editor.cursors { put_cursor_in_valid_spot(cursor, buffer); }
    if editor.cursors.count > 1 then organise_cursors(editor);
}

editors_open_file :: (path: string, placement: Editor_Placement = .in_place) {
    full_path, success := get_absolute_path(path);  // returns temporary storage
    path_overwrite_separators(full_path, separator = #char "/");
    if !file_exists(full_path) || !success {
        log_error("Couldn't open file %", path);
        add_user_error(tprint("Couldn't open file %", path), dismiss_in_seconds = 60);
        return;
    }
    buffer_id := find_or_create_buffer(full_path);
    if buffer_id < 0 && full_path.count > 248 {
        log_error("Couldn't open file because path is too long for Windows: %\n", full_path);
        add_user_error("Couldn't open file. Path is too long.");  // not including full path for obvious reasons
        return;
    }

    if !file_is_watched(full_path) start_watching_file(full_path);

    editors_open_buffer(buffer_id, placement);
}

editors_open_global_config :: (placement: Editor_Placement) {
    editors_open_file(global_config_path, placement);
}

editors_open_project_config :: (placement: Editor_Placement) {
    if project_config_path {
        editors_open_file(project_config_path, placement);
    } else {
        add_user_warning("No project is active. Please open a project first.", dismiss_in_seconds = 5);
    }
}

editors_create_new_file :: (placement: Editor_Placement = .in_place) {
    buffer_id := find_or_create_an_empty_buffer();

    editors_open_buffer(buffer_id, placement);
}

editors_open_buffer :: (buffer_id: s64, placement: Editor_Placement = .in_place) {
    if #complete editors.layout == {
        case .None;
            editors.active = find_or_create_editor(buffer_id);
            editors.layout = .Single;

        case .Single;
            if placement == .in_place {
                // Open in place
                editors.active  = find_or_create_editor(buffer_id);
            } else if placement == .on_the_side || placement == .right {
                // Open on the right
                editors.right  = find_or_create_editor(buffer_id, editors.active);
                editors.left   = editors.active;
                editors.active = editors.right;
                editors.layout = .Double;
                editors_start_moving_splitter(0.5, start = 1.0);
            } else {
                // Open on the left
                editors.left   = find_or_create_editor(buffer_id, editors.active);
                editors.right  = editors.active;
                editors.active = editors.left;
                editors.layout = .Double;
                editors_start_moving_splitter(0.5, start = 0.0);
            }

        case .Double;
            on_the_right := (
                placement == .right ||
                (placement == .in_place    && editors.active == editors.right) ||
                (placement == .on_the_side && editors.active == editors.left)
            );

            if on_the_right {
                // Open on the right (obviously)
                editors.right  = find_or_create_editor(buffer_id, editors.left);
                editors.active = editors.right;
            } else {
                // Open on the left
                editors.left   = find_or_create_editor(buffer_id, editors.right);
                editors.active = editors.left;
            }
    }
    buffer := *open_buffers[buffer_id];
    if buffer.num_times_opened < 255 then buffer.num_times_opened += 1;

    update_window_title(buffer_id);
    maybe_mark_buffer_as_deleted(buffer_id);  // check in case we missed that it's deleted
    session_notify_modified_buffer(buffer_id);
    cursors_start_blinking();
}

move_viewport :: (editor: *Editor, dir: enum { left; up; right; down; }) {
    using editor.viewport;
    if dir == {
        case .left; #through;
        case .right;
            horiz_delta := cast(s32) (10 * char_size);
            new_target := ifx dir == .left then scroll_x.target - horiz_delta else scroll_x.target + horiz_delta;
            if new_target < 0 then new_target = 0;
            start_animation(*scroll_x, left, new_target, snappy = true);

        case .up; #through;
        case .down;
            vert_delta := cast(s32) (10 * line_height);
            new_target := ifx dir == .up then scroll_y.target - vert_delta else scroll_y.target + vert_delta;
            new_target = clamp(new_target, 0, get_max_y_scroll(open_buffers[editor.buffer_id]));
            start_animation(*scroll_y, top, new_target, snappy = true);
    }
}


center_viewport_on_cursor :: (using editor: *Editor, buffer: Buffer) {
    editor.scroll_to_cursor = .yes;
}


move_cursor_to_viewport_center :: (editor: *Editor, buffer: Buffer) {
    cursor := leave_only_original_cursor(editor);
    // We assume that editors always take up most of the screen vertically.
    // If that ever changes we'll need to change this code (and do it when we know the layout)
    cursor_px_pos := editor.viewport.top +  window_height / 2;
    coords := Coords.{ line = xx (cursor_px_pos / line_height), col = 0 };
    cursor.pos = coords_to_offset(buffer, coords);
    cursor.sel = cursor.pos;
    editor.cursor_moved = .refresh_only;
}



leave_only_original_cursor :: (using editor: *Editor) -> *Cursor {
    // Remove all cursors except the original one
    cursor := cursors[min(original_cursor, cursors.count-1)];
    cursor.clipboard = .{ start = 0, count = xx max(clipboard.count, 0) };
    cursors.count = 1;
    original_cursor = 0;
    main_cursor = 0;
    cursors[0] = cursor;
    return *cursors[0];
}

organise_cursors :: (using editor: *Editor, selection_mode: *Selection_Mode = xx 0) {
    compare_cursors :: (c1: Cursor, c2: Cursor) -> s64 {
        return min(c1.pos, c1.sel) - min(c2.pos, c2.sel);
    }

    maybe_subsume :: (c1: *Cursor, c2: Cursor) -> bool {
        s1 := get_selection(c1);
        s2 := get_selection(c2);
        if s1.end < s2.start || s2.end < s1.start return false;  // cursors are disjoint
        if s1.start != s1.end && s2.start != s2.end && (s1.end == s2.start || s2.end == s1.start) && (s1.start < s1.end || s2.start < s2.end) return false;  // adjacent cursors with a selection

        new_start := min(s1.start, s2.start);
        new_end   := max(s1.end,   s2.end);

        if c1.pos == s1.end || c2.pos == s2.end {
            c1.sel = new_start;
            c1.pos = new_end;
        } else {
            c1.pos = new_start;
            c1.sel = new_end;
        }

        return true;
    }

    if original_cursor >= cursors.count then original_cursor = main_cursor;  // we don't remember original cursor on edits (maybe we should)

    main_cursor_offset     := cursors[main_cursor].pos;
    original_cursor_offset := cursors[original_cursor].pos;

    quick_sort(cursors, compare_cursors);

    // Adjust main and original cursor indices because they could've moved
    for cursor, i : cursors {
        if cursor.pos == main_cursor_offset     then main_cursor = i;
        if cursor.pos == original_cursor_offset then original_cursor = i;
    }

    // Merge overlapping cursors
    i := 0;
    reset_clipboard : = false;
    while (i < cursors.count - 1) {
        cursor      := *cursors[i];
        next_cursor := cursors[i+1];
        if maybe_subsume(cursor, next_cursor) {
            if cursor.clipboard.start + cursor.clipboard.count + 1 == next_cursor.clipboard.start {
                cursor.clipboard.count += 1 + next_cursor.clipboard.count;  // "\n" + whatever was selected
            } else {
                reset_clipboard = true;
            }
            if selection_mode && (main_cursor == i || main_cursor == i+1) then selection_mode.min_range = get_selection(cursor);  // preserve the selection when dragging
            array_ordered_remove_by_index(*cursors, i+1);
            if main_cursor     > i then main_cursor -= 1;
            if original_cursor > i then original_cursor -= 1;
        } else {
            i += 1;
        }
    }

    if reset_clipboard {
        // Cursors have mixed beyond repair
        cursors[main_cursor].clipboard = .{ start = 0, count = xx max(clipboard.count, 0) };
    }
}

get_max_y_scroll :: (buffer: Buffer) -> s32 {
    assert(!buffer.dirty);
    return max(cast(s32) ((buffer.line_starts.count - 2)  * line_height), 0);
}

add_paste_animation :: (using editor: *Editor, range: Offset_Range) {
    if config.settings.disable_that_annoying_paste_effect return;

    anim := array_add(*paste_animations);
    anim.range = range;
    anim.started_at = frame_time;
}

select_word :: (buffer: Buffer, cursor: *Cursor) {
    pos       := cursor.pos;
    pos_left  := ifx cursor.pos > 0 then prev_char_offset(buffer.bytes, pos) else 0;
    char      := get_char_at_offset(buffer, pos);
    char_left := get_char_at_offset(buffer, pos_left);

    if !is_word_char(char) && is_word_char(char_left) {
        pos  = pos_left;  // favor the word to the left
        char = char_left;
    }

    char_type := get_char_type(char);
    if char_type == .other return;

    cursor.pos = scan_through_similar_chars_on_the_right(buffer, pos, char_type, skip_one_space = false);
    cursor.sel = scan_through_similar_chars_on_the_left (buffer, pos, char_type, skip_one_space = false);
}

get_selected_text_all_cursors :: (using editor: Editor, buffer: Buffer) -> string {  // returns view into buffer
    // Returns a selected string only if all cursors have the same text selected.
    // Otherwise returns an empty string.

    text := get_selected_string(cursors[main_cursor], buffer);
    if text.count == 0 return "";

    for cursor : cursors {
        if text != get_selected_string(cursor, buffer) return "";
    }

    return text;
}

new_edit_group :: (buffer: *Buffer, editor: *Editor) {
    if buffer.edits.count == 0 return;

    new_group := array_add(*buffer.undos);
    new_group.edits = to_owned_array(*buffer.edits);  // @Speed: could group all char inserts into one if needed
    new_group.cursors = to_owned_array(*buffer.cursors);

    // Remember cursor state
    array_resize(*buffer.cursors, editor.cursors.count);
    for * cursor, i : buffer.cursors { <<cursor = editor.cursors[i].state; }
}

close_current_editor :: () {
    if editors.layout == {
        case .None;     return;
        case .Single;
            editors.layout = .None;  // close immediately
            update_window_title();

        case .Double;
            // Start the animation (the layout will change when the animation is finished)
            if editors.active == editors.left {
                editors_start_moving_splitter(0.0);  // close left
                make_editor_active(editors.right);
            } else {
                editors_start_moving_splitter(1.0);  // close right
                make_editor_active(editors.left);
            }
            editors.closing = true;
    }
}


close_other_editor :: () {
    if editors.layout == {
        case .None;     return;
        case .Single;   return;  // don't do anything
        case .Double;
            // Start the animation (the layout will change when the animation is finished)
            if editors.active == editors.left {
                editors_start_moving_splitter(1.0);  // close right
            } else {
                editors_start_moving_splitter(0.0);  // close left
            }
            editors.closing = true;
    }
}

finish_closing_editor :: () {
    if editors.layout == .Double then editors.layout = .Single;
    editors.closing = false;
}

search_bar_is_open :: inline (using editor: *Editor) -> bool {
    return search_bar.active;  // used to be more stuff in here
}

open_search_bar :: (using editor: *Editor, buffer: Buffer, requested_mode: Search_Bar.Mode = .classic, remember_cursor_position := true) {
    using editor.search_bar;
    active = true;
    mode = requested_mode;

    // If there was some text selected that doesn't span more than one line, use it for search
    if cursors.count == 1 {
        cursor := cursors[0];
        selected_text := get_selected_string(cursor, buffer);
        if selected_text && offset_to_line(buffer, cursor.pos) == offset_to_line(buffer, cursor.sel) {
            replace_text(*input, selected_text);
        }
    }

    // Select text when opening
    input.cursor.sel = 0;
    input.cursor.pos = xx input.text.count;

    search_point_offset = get_selection(cursors[main_cursor]).start;

    if remember_cursor_position {
        original_cursor_position = cursors[main_cursor].state;
        jumped = false;
    }

    search_and_update_results(editor, buffer);
    scroll_y = 0;
    scroll_to_selected = .snap;
}

close_search_bar :: inline (editor: *Editor, jump_to_original_cursor := false) {
    using editor.search_bar;
    active = false;  // stop receiving input immediately

    if jump_to_original_cursor && jumped {
        cursor := leave_only_original_cursor(editor);
        cursor.state = original_cursor_position;
        editor.scroll_to_cursor = .yes;
    }

    reset_search_results(*editor.search_bar);
    editor.refresh_highlights = true;
}

search_bar_toggle_expand :: (using editor: *Editor) {
    using search_bar;

    if width_percentage != WIDTH_EXPANDED {
        start_animation(*width_anim, width_percentage, WIDTH_EXPANDED, snappy = true);
    } else {
        start_animation(*width_anim, width_percentage, WIDTH_NORMAL, snappy = true);
    }
}

search_bar_toggle_whole_word :: (using editor: *Editor, buffer: Buffer) {
    using search_bar;

    if !active return;
    whole_word = !whole_word;
    search_and_update_results(editor, buffer);
}

search_bar_toggle_case_sensitive :: (using editor: *Editor, buffer: Buffer) {
    using search_bar;

    if !active return;
    case_sensitive = !case_sensitive;
    search_and_update_results(editor, buffer);
}

search_bar_move_cursor :: (using editor: *Editor, buffer: Buffer, delta: s64, wrap := false, snap := true) {
    using search_bar;

    selected_result += delta;

    if wrap {
        if selected_result < 0 then selected_result = max(0, results.count - 1);
        if selected_result >= results.count then selected_result = 0;
    } else {
        if selected_result < 0 then selected_result = 0;
        if selected_result >= results.count then selected_result = results.count - 1;
    }

    jump_to_search_result(editor, buffer, move_search_point = true);

    scroll_to_selected = ifx snap then Scroll_Mode.snap else .yes;
}

search_bar_open_selected_result :: (editor: Editor, buffer: Buffer, placement: Editor_Placement) {
    using editor.search_bar;

    active = false;  // close it immediately

    result := results[selected_result];

    old_layout := editors.layout;
    editors_open_buffer(editor.buffer_id, placement);

    // Select the search result
    active_editor, active_buffer := get_active_editor_and_buffer();
    match_start := min(result.offset,                    xx active_buffer.bytes.count);  // buffer could've changed, so offset may not be valid any more
    match_end   := min(result.offset + input.text.count, xx active_buffer.bytes.count);
    cursor := leave_only_original_cursor(active_editor);
    cursor.sel = xx match_start;
    cursor.pos = xx match_end;

    active_editor.scroll_to_cursor = .yes;
    if old_layout == .Single && editors.layout == .Double {
        // We've just opened a new editor, so need to let it know it's being opened,
        // so that it can use the target rect width for its scroll calculations
        // (otherwise it'll be too small and the scroll will not animate where expected)
        active_editor.scroll_to_cursor = .yes_new_editor;
    }
}

search_and_update_results :: (using editor: *Editor, buffer: Buffer, jump := false) {
    reset_search_results(*search_bar);

    using search_bar;
    needle := to_string(input.text);
    if !needle return;

    buffer_str := to_string(buffer.bytes);

    assert(buffer_str.count < S32_MAX && needle.count < S32_MAX);
    skip_table := bmh_prepare_skip_table(needle, case_sensitive);
    offset := 0;
    i := 0;
    while true {
        if case_sensitive {
            offset = inline bmh_find_index_from_left(buffer_str, needle, start_index = offset, skip_table, case_sensitive = true);
        } else {
            offset = inline bmh_find_index_from_left(buffer_str, needle, start_index = offset, skip_table, case_sensitive = false);
        }
        if offset < 0 break;

        if !whole_word || (whole_word && match_whole_word(buffer_str, offset, needle.count)) {
            result := array_add(*results);
            result.offset = offset;
            result.line = offset_to_line(buffer, offset);
            if selected_result < 0 && result.offset >= search_point_offset then selected_result = i;
            i += 1;
        }
        offset += needle.count;
    }

    if selected_result < 0 && i > 0 then selected_result = i - 1;  // all results are before cursor, select the closest one
    if selected_result >= 0 && jump then jump_to_search_result(editor, buffer);
}

jump_to_search_result :: (using editor: *Editor, buffer: Buffer, move_search_point := false) {
    using search_bar;
    if !results || selected_result < 0 return;

    result := results[selected_result];
    cursor := leave_only_original_cursor(editor);
    cursor.sel = xx result.offset;
    cursor.pos = xx (result.offset + input.text.count);
    scroll_to_cursor = .yes;

    if move_search_point {
        search_point_offset = xx result.offset;
    }

    jumped = true;

    cursors_start_blinking();
}

reset_search_results :: (using search_bar: *Search_Bar) {
    array_reset(*results);
    selected_result = -1;
}

editors_snap_splitter :: (pos: float) {
    pos = clamp(pos, 0.1, 0.9);
    splitter_pos = pos;
    splitter_anim.target = pos;
}

editors_start_moving_splitter :: (target: float, start := -1.0) {
    if start >= 0 then splitter_pos = start;
    if !config.settings.disable_file_open_close_animations {
        start_animation(*splitter_anim, splitter_pos, target, snappy = true);
    } else {
        splitter_anim.target = target;
        splitter_pos = target;
    }
    redraw_requested = true;
}

init_buffers :: () {
    // 3000 * 70% = 2100 is a reasonable number of text files in a workspace, which
    // most codebases will hopefully not exceed (so that we don't have to grow the hash table)
    init(*buffers_table, slots_to_allocate = 3000);

    init(*open_buffers_lock);
}

set_lang_from_path :: (buffer: *Buffer, path: string) {
    extension, found_extension := get_lowercase_extension(path, greedy = false);
    if found_extension {
        if extension == {
            case "jai";            buffer.lang = .Jai;
            case "focus-config";   buffer.lang = .Focus_Config;
            case "cs";             buffer.lang = .CSharp;

            case "c";   #through;
            case "h";   #through;
            case "cpp"; #through;
            case "cxx"; #through;
            case "c++"; #through;
            case "hpp"; #through;
            case "cc";
                buffer.lang = .C;
        }
    }

    path_, basename, _, basename_with_extension := path_decomp(path);

    if equal_nocase(basename, "todo") || equal_nocase(basename_with_extension, "FOCUS-CHANGELOG.txt") {
        buffer.lang = .Worklog;
    }
}

select_lines :: (editor: *Editor, buffer: Buffer) {
    for * cursor : editor.cursors select_line(cursor, buffer);
    editor.cursor_moved = .selection;
}

select_line :: (cursor: *Cursor, buffer: Buffer) {
    selection  := get_selection(cursor);
    start_line := offset_to_line(buffer, selection.start);
    end\ _line := ifx selection.start != selection.end then offset_to_line(buffer, selection.end) else start_line;
    cursor.sel = get_line_start_offset(buffer, start_line);
    cursor.pos = get_line_start_offset(buffer, end_line+1);
}

scan_through_similar_chars_on_the_left :: (using buffer: Buffer, offset: s32, char_type: Char_Type = .none, skip_one_space := true) -> offset: s32 {
    if !buffer.bytes return 0;

    line_start := bytes.data + line_starts[offset_to_line(buffer, offset)];
    char: u32;
    t := bytes.data + offset;
    t, char = unicode_prev_character(t);
    if char_type != .none && char_type != get_char_type(char) return offset;
    if skip_one_space && char == #char " " && t > line_start then t, char = unicode_prev_character(t);

    if get_char_type(char) == {
        case .space;
            while t > bytes.data && is_space_char(char)  { t, char = unicode_prev_character(t); }
            if char != #char " " then t = unicode_next_character(t);
        case .word;
            while t > bytes.data && is_word_char(char) { t, char = unicode_prev_character(t); }
            if !is_word_char(char) then t = unicode_next_character(t);
        case .non_word;
            while t > bytes.data && is_non_word_char(char) { t, char = unicode_prev_character(t); }
            if !is_non_word_char(char) then t = unicode_next_character(t);
    }

    if t < bytes.data then t = bytes.data;

    return cast(s32) max(0, t - bytes.data);
}

scan_through_similar_chars_on_the_right :: (using buffer: Buffer, offset: s32, only: Char_Type = .none, skip_one_space := true) -> offset: s32 {
    if !buffer.bytes return 0;
    if offset >= bytes.count return offset;  // nowhere to go

    s: string = ---;
    s.data  = *bytes[offset];
    s.count = (bytes.data + bytes.count) - s.data;

    char := utf8_next_character(*s);
    if only == {
        case .word;     if !is_word_char(char)     return offset;
        case .non_word; if !is_non_word_char(char) return offset;
        case .space;    if  char != #char " "      return offset;
    }
    if skip_one_space && char == #char " " && s then char = utf8_next_character(*s);

    if char == #char " " {
        // Only spaces
        while s && char == #char " "  { char = utf8_next_character(*s); }
        if char != #char " " { s.data, char = unicode_prev_character(s.data); }
    } else if is_word_char(char) {
        // Only word chars
        while s && is_word_char(char) { char = utf8_next_character(*s); }
        if !is_word_char(char) { s.data, char = unicode_prev_character(s.data); }
    } else if char != #char "\n" {
        // Only non-word chars
        while s && is_non_word_char(char) { char = utf8_next_character(*s); }
        if !is_non_word_char(char) { s.data, char = unicode_prev_character(s.data); }
    }

    return cast(s32) min(bytes.count, s.data - bytes.data);
}

cursors_start_blinking :: inline () {
    cursor_blink_start = frame_time;
    platform_set_refresh_timer(window);
    cursors_blinking = true;
}

cursors_stop_blinking :: inline () {
    cursors_blinking = false;
    platform_kill_refresh_timer(window);
}

should_draw_cursors :: inline () -> bool {
    if !cursors_blinking return true;

    ms_since_start := cast(s64) ((frame_time - cursor_blink_start) * 1000);
    if ms_since_start > CURSOR_BLINK_TIMEOUT_MS {
        cursors_stop_blinking();
        return true;
    }
    return (ms_since_start / CURSOR_BLINK_SPEED_MS) % 2 == 0;
}

cursors_have_the_same_clipboard :: (using editor: Editor) -> bool, clipboard: Cursor.Clipboard {
    same_clipboard := true;
    first_str := get_clipboard_string(editor, cursors[0]);

    for cursor : cursors {
        if first_str != get_clipboard_string(editor, cursor) {
            same_clipboard = false;
            break;
        }
    }

    return same_clipboard, cursors[0].clipboard;
}

get_clipboard_string :: (editor: Editor, cursor: Cursor) -> string {
    start := clamp(cursor.clipboard.start, 0, cast(s32) editor.clipboard.count - 1);
    count := clamp(cursor.clipboard.count, 0, cast(s32) editor.clipboard.count - start);
    return slice(editor.clipboard, max(start, 0), count);
}

remove_all_editors :: () {
    editors = Editor_State.{};
    for * open_editors free_editor(it);
    array_reset_keeping_memory(*open_editors);
}

viewport_remember_glue_point :: (using viewport: *Viewport, buffer: Buffer) {
    glue_point.buffer_pos = get_line_start_offset(buffer, top / cast(s32) line_height);
    glue_point.offset_within_line = top % cast(s32) line_height;
}

viewport_glue_to_point :: (using viewport: *Viewport, buffer: Buffer) -> changed: bool {
    old_top := top;
    line := offset_to_line(buffer, glue_point.buffer_pos);
    top = line * cast(s32) line_height + glue_point.offset_within_line;
    scroll_y.target = top;
    return top != old_top;
}

restore_cursor_state :: (using editor: *Editor, cursor_state: [] Cursor.State) {
    if cursor_state.count == 0 return;  // the first undo doesn't have any remembered cursors

    array_resize(*cursors, cursor_state.count);
    for * cursor, i : cursors {
        cursor.state = cursor_state[i];
        cursor.col_wanted = -1;
        cursor.clipboard.start = 0;
        cursor.clipboard.count = cast(s32)editor.clipboard.count;
    }
    if main_cursor >= cursors.count then main_cursor = cursors.count - 1;  // maybe we should remember it too
}

make_editor_active :: (editor_id: s64) {
    assert(editor_id < open_editors.count, "Trying to activate editor %, but the last available one is %", editor_id, open_editors.count - 1);
    editors.active = editor_id;
    update_window_title(open_editors[editor_id].buffer_id);
}

update_window_title :: (buffer_id: s64 = -1) {
    title := window_generic_title;
    if current_project_name then title = tprint("% - %", current_project_name, title);
    if buffer_id >= 0 {
        buffer := open_buffers[buffer_id];
        if buffer.has_file {
            title = tprint("% • % • %", buffer.file.name, buffer.file.path, title);
        } else {
            title = tprint("% • %", get_buffer_name(buffer), title);
        }
    }
    platform_set_window_title(title);
}

#scope_file

create_cursor :: (using editor: *Editor, buffer: Buffer, where: enum { above; below; }) {
    organise_cursors(editor);

    edge_cursor := ifx where == .above then cursors[0] else cursors[cursors.count-1];
    original    := cursors[original_cursor];
    original_pos_coords := offset_to_coords(buffer, original.pos);
    original_sel_coords := offset_to_coords(buffer, original.sel);

    cursor := array_add(*cursors);
    << cursor  = edge_cursor;

    pos_coords := offset_to_coords(buffer, cursor.pos);
    if where == .above then pos_coords.line -= 1; else pos_coords.line += 1;
    pos_coords.col = original_pos_coords.col;

    cursor.pos = coords_to_offset(buffer, pos_coords);
    cursor.col_wanted = original_pos_coords.col;

    if has_selection(original) {
        sel_coords := pos_coords;
        sel_coords.line += original_sel_coords.line - original_pos_coords.line;
        sel_coords.col  += original_sel_coords.col  - original_pos_coords.col;
        cursor.sel = coords_to_offset(buffer, sel_coords);
    } else {
        cursor.sel = cursor.pos;
    }
    main_cursor = cursors.count - 1;

    organise_cursors(editor);

    cursor_moved = .refresh_only;
}


select_word :: (using editor: *Editor, buffer: Buffer) {
    editor.cursor_moved = .unimportant;
    for * editor.cursors {
        if has_selection(it) continue;
        select_word(buffer, it);
        editor.search_whole_words = true;
    }
}


select_word_or_create_another_cursor :: (using editor: *Editor, buffer: Buffer) -> whole_words: bool {
    editor.cursor_moved = .selection;

    selected_text := get_selected_text_all_cursors(editor, buffer);
    if selected_text {
        // Cursors have the same text selected - attempt to create another cursor
        buffer_str := to_string(buffer.bytes);

        search_func: (s: string, substring: string, start_index := 0) -> s64;
        search_func = ifx search_whole_words then find_index_from_left_whole_word else find_index_from_left;

        // Search from the main cursor downwards, possibly with a wraparound
        start_offset := get_selection(cursors[main_cursor]).end;
        found_offset := -1;
        if main_cursor == cursors.count - 1 {
            // Main cursor is last - search with a wraparound
            end_offset  := get_selection(cursors[0]).start;
            before_wrap := slice(buffer_str, start_offset, buffer_str.count - start_offset);
            after_wrap  := slice(buffer_str, 0, end_offset);

            index := search_func(before_wrap, selected_text);
            if index >= 0 then found_offset = start_offset + index;
            if found_offset < 0 then found_offset = search_func(after_wrap, selected_text);
        } else {
            // Main cursor is not last - search until the next cursor only
            end_offset := get_selection(cursors[main_cursor+1]).start;
            target_range := slice(buffer_str, start_offset, end_offset - start_offset);
            index := search_func(target_range, selected_text);
            if index >= 0 then found_offset = start_offset + index;
        }
        if found_offset < 0 {
            if main_cursor != original_cursor {
                main_cursor = original_cursor;  // go back to original and stop
            }
            return editor.search_whole_words;  // found no matches
        }

        same_clipboard, clipboard := cursors_have_the_same_clipboard(editor);

        new_cursor := array_add(*cursors);
        new_cursor.sel = cast(s32) found_offset;
        new_cursor.pos = cast(s32) (found_offset + selected_text.count);
        if same_clipboard then new_cursor.clipboard = clipboard;

        main_cursor = cursors.count - 1;

    } else {
        // Cursors either don't have anything selected, or the selected text is different
        for * editor.cursors {
            if has_selection(it) continue;
            select_word(buffer, it);
            editor.search_whole_words = true;
        }
    }

    return editor.search_whole_words;
}

save_buffer :: (editor: *Editor, buffer: *Buffer) {
    new_edit_group(buffer, editor);

    if buffer.has_file {
        maybe_mark_buffer_as_deleted(editor.buffer_id);  // check in case we missed that it's deleted
        session_notify_modified_buffer(editor.buffer_id);
    }
    save_buffer_to_disk(buffer, editor.buffer_id);
}

save_all :: (editor: *Editor, buffer: *Buffer) {
    new_edit_group(buffer, editor);

    for * buffer, buffer_id : open_buffers {
        if !buffer.modified continue;
        save_buffer_to_disk(buffer, buffer_id);
    }
}

switch_to_editor :: (side: enum { left; right; other; }, duplicate_current := false) {
    if editors.layout == {
        case .None; return;

        case .Single;
            duplicated_editor := duplicate_active_editor();

            if side == {
                case .left;
                    editors.left   = duplicated_editor;
                    editors.right  = editors.active;
                    editors.active = editors.left;
                    editors_start_moving_splitter(0.5, start = 0.0);
                case .right; #through;
                case .other;
                    editors.left   = editors.active;
                    editors.right  = duplicated_editor;
                    editors.active = editors.right;
                    editors_start_moving_splitter(0.5, start = 1.0);
            }
            editors.layout = .Double;

        case .Double;
            if side == .other {
                if editors.active == editors.left then side = .right; else side = .left;
            }
            if duplicate_current {
                duplicated_editor := duplicate_active_editor();

                if side == .left {
                    editors.left   = duplicated_editor;
                    editors.right  = editors.active;
                } else {
                    editors.right  = duplicated_editor;
                    editors.left   = editors.active;
                }
                editors.active = duplicated_editor;
            }
            editors.active = ifx side == .left then editors.left else editors.right;
    }

    editor := *open_editors[editors.active];
    maybe_mark_buffer_as_deleted(editor.buffer_id);  // check in case we missed that it's deleted

    update_window_title(open_editors[editors.active].buffer_id);
    cursors_start_blinking();
}

duplicate_active_editor :: () -> s64 {
    current_editor       := *open_editors[editors.active];
    duplicated_editor_id := find_or_create_editor(current_editor.buffer_id, editors.active);
    duplicated_editor    := *open_editors[duplicated_editor_id];

    // Duplicate cursors
    if duplicated_editor.cursors then array_reset(*duplicated_editor.cursors);
    for current_editor.cursors { array_add(*duplicated_editor.cursors, it); }
    duplicated_editor.main_cursor     = current_editor.main_cursor;
    duplicated_editor.original_cursor = current_editor.original_cursor;

    // Copy clipboard
    if duplicated_editor.clipboard then free(duplicated_editor.clipboard);
    duplicated_editor.clipboard = copy_string(current_editor.clipboard);

    // Move viewport
    duplicated_editor.viewport.scroll_x = current_editor.viewport.scroll_x;
    duplicated_editor.viewport.scroll_y = current_editor.viewport.scroll_y;

    return duplicated_editor_id;
}

set_editor_panes :: (left_editor_id: s64, right_editor_id: s64, active_editor_id: s64 = -1) {
    if left_editor_id < 0  return;

    if right_editor_id >= 0 {
        editors.left   = left_editor_id;
        editors.right  = right_editor_id;

        if editors.layout != .Double {
            editors_start_moving_splitter(0.5, start = 1.0);
            editors.layout = .Double;
        }
    }
    else {
        editors.layout = .Single;
    }

    make_editor_active(ifx active_editor_id > -1 else left_editor_id);
}

swap_panes :: () {
    if editors.layout != .Double return;
    tmp := editors.left;
    editors.left  = editors.right;
    editors.right = tmp;

    // NOTE: this line started crashing with an access violation - @compilerbug?
    // editors.left, editors.right = swap(editors.left, editors.right);
}

toggle_expand :: () {
    if editors.layout != .Double return;

    editors.expanded = !editors.expanded;
    if editors.expanded {
        editors_start_moving_splitter(ifx editors.active == editors.left then 0.9 else 0.1);
    } else {
        editors_start_moving_splitter(0.5);  // back to center
    }
}

smooth_scroll :: (editor: Editor, direction: Smooth_Scroll_Direction, fast := false) {
    editor_smooth_scroll.direction = direction;
    if editor_smooth_scroll.direction != .none {
        editor_smooth_scroll.started_at = frame_time;
        editor_smooth_scroll.start_x    = editor.viewport.left;
        editor_smooth_scroll.start_y    = editor.viewport.top;
        editor_smooth_scroll.fast       = fast;
    }
}

find_or_create_editor :: (buffer_id: s64, unwanted_existing_editor: s64 = -1) -> editor_id: s64, created: bool {
    assert(buffer_id >= 0 && buffer_id < open_buffers.count, "Attempt to create editor for nonexistent buffer");
    for open_editors
        if it.buffer_id == buffer_id && it_index != unwanted_existing_editor
            return it_index, false;

    editor_id := open_editors.count;
    editor := array_add(*open_editors);
    editor.buffer_id = buffer_id;
    array_add(*editor.cursors, Cursor.{});

    open_buffers[buffer_id].num_editors_open += 1;
    assert(open_buffers[buffer_id].num_editors_open <= 2);

    return editor_id, true;
}

undo :: (editor: *Editor, buffer: *Buffer) {
    new_edit_group(buffer, editor);

    if buffer.undos.count == 0 return;

    edit_group := pop(*buffer.undos);
    // Revert edits in the backwards order
    for < e : edit_group.edits {
        if #complete e.type == {
            case .delete;  using e.delete;  insert_string_raw(buffer, offset_range.start, old_bytes);
            case .replace; using e.replace; replace_range_raw(buffer, offset_range.start, offset_range.start + xx new_bytes.count, old_bytes);
            case .insert;  using e.insert;  delete_range_raw (buffer, offset, offset + new_bytes.count);
            case .insert_char; using e.insert_char;  delete_range_raw (buffer, offset, offset + char.count);
        }
    }
    // Add a new redo group
    redo := array_add(*buffer.redos);
    redo.edits = edit_group.edits;
    redo.cursors = to_owned_array(*buffer.cursors);

    array_extend(*buffer.cursors, edit_group.cursors);
    restore_cursor_state(editor, edit_group.cursors);
    array_free(edit_group.cursors);

    editor.cursor_moved = .large_edit;
}

redo :: (editor: *Editor, buffer: *Buffer) {
    if buffer.redos.count == 0 return;

    edit_group := pop(*buffer.redos);
    // Replay edits in the normal order
    for e : edit_group.edits {
        if #complete e.type == {
            case .delete;  using e.delete;  delete_range_raw (buffer, offset_range.start, offset_range.end);
            case .replace; using e.replace; replace_range_raw(buffer, offset_range.start, offset_range.end, new_bytes);
            case .insert;  using e.insert;  insert_string_raw(buffer, offset, new_bytes);
            case .insert_char; using e.insert_char; insert_string_raw(buffer, offset, to_string(*char));
        }
    }
    // Add a new undo group
    undo := array_add(*buffer.undos);
    undo.edits = edit_group.edits;
    undo.cursors = to_owned_array(*buffer.cursors);

    array_extend(*buffer.cursors, edit_group.cursors);
    restore_cursor_state(editor, edit_group.cursors);
    array_free(edit_group.cursors);

    editor.cursor_moved = .large_edit;
}

new_edit_group_required_for_action :: (action: Action_Editors, cursor: Cursor) -> bool {
    if action == {
        case .break_line;                       if has_selection(cursor) return true;
        case .new_line_below_without_breaking;  if has_selection(cursor) return true;
        case .new_line_above_without_breaking;  if has_selection(cursor) return true;
        case .delete_left_char;                 if has_selection(cursor) return true;
        case .delete_right_char;                if has_selection(cursor) return true;

        case .cut;                              return true;
        case .paste;                            return true;
        case .toggle_comment;                   return true;
        case .indent_or_go_to_next_tabstop;     return true;
        case .indent;                           return true;
        case .unindent;                         return true;
        case .duplicate_lines;                  return true;
        case .move_selected_lines_up;           return true;
        case .move_selected_lines_down;         return true;
        case .delete_word_left;                 return true;
        case .delete_word_right;                return true;
        case .delete_word_left_no_underscore;   return true;
        case .delete_word_right_no_underscore;  return true;
        case .join_lines;                       return true;
        case .join_lines_no_spaces_in_between;  return true;
    }

    return false;
}

is_a_move_action :: (action: Action_Editors) -> bool {
    if action == {
        case .move_left;                        return true;
        case .move_left_by_word;                return true;
        case .move_left_by_word_ends;           return true;
        case .move_right;                       return true;
        case .move_right_by_word;               return true;
        case .move_right_by_word_ends;          return true;
        case .move_up;                          return true;
        case .move_down;                        return true;
        case .move_up_fast;                     return true;
        case .move_down_fast;                   return true;
        case .move_up_to_empty_line;            return true;
        case .move_down_to_empty_line;          return true;
        case .move_up_one_page;                 return true;
        case .move_down_one_page;               return true;
        case .jump_to_line_start;               return true;
        case .jump_to_line_end;                 return true;
        case .jump_to_file_start;               return true;
        case .jump_to_file_end;                 return true;
    }
    return false;
}

move_cursors_left :: (editor: *Editor, using buffer: *Buffer, by: enum { char; word; word_ends; }, extend_selection: bool) {
    skip_one_space := editor.cursors.count == 1;

    for * cursor : editor.cursors {
        if has_selection(cursor) && !extend_selection {
            cursor.pos = get_selection(cursor).start;
        } else if by == .char {
            if cursor.pos > 0 then cursor.pos = prev_char_offset(bytes, cursor.pos);
        } else {
            if by == {
                case .word;
                    context.underscore_is_part_of_word = false;
                    cursor.pos = scan_through_similar_chars_on_the_left(buffer, cursor.pos, skip_one_space = skip_one_space);
                    context.underscore_is_part_of_word = true;
                case .word_ends;
                    char_type := get_char_type(get_char_at_offset(buffer, cursor.pos));
                    if char_type != .word then cursor.pos = scan_through_similar_chars_on_the_left(buffer, cursor.pos, char_type, skip_one_space = false);
                    cursor.pos = scan_through_similar_chars_on_the_left(buffer, cursor.pos, skip_one_space = skip_one_space);
            }
        }
        cursor.col_wanted = -1;
    }
    editor.cursor_moved = .unimportant;
}

move_cursors_right :: (editor: *Editor, using buffer: *Buffer, by: enum { char; word; word_ends; }, extend_selection: bool) {
    skip_one_space := editor.cursors.count == 1;

    for * cursor : editor.cursors {
        if cursor.pos >= bytes.count continue;  // nowhere to go

        if has_selection(cursor) && !extend_selection {
            cursor.pos = get_selection(cursor).end;
        } else if by == .char {
            cursor.pos = next_char_offset(bytes, cursor.pos);
        } else {
            if by == {
                case .word;
                    context.underscore_is_part_of_word = false;
                    cursor.pos = scan_through_similar_chars_on_the_right(buffer, cursor.pos, skip_one_space = skip_one_space);
                    context.underscore_is_part_of_word = true;
                case .word_ends;
                    char := get_char_at_offset(buffer, cursor.pos);
                    char_type := get_char_type(char);
                    if char_type != .word  then cursor.pos = scan_through_similar_chars_on_the_right(buffer, cursor.pos, char_type, skip_one_space = false);
                    char_type = get_char_type(get_char_at_offset(buffer, cursor.pos));
                    if char_type != .other && char != #char "\n" then cursor.pos = scan_through_similar_chars_on_the_right(buffer, cursor.pos, skip_one_space = skip_one_space);
            }
        }
        cursor.col_wanted = -1;
    }

    editor.cursor_moved = .unimportant;
}

move_cursors_vertically :: (editor: *Editor, using buffer: Buffer, delta: s32, extend_selection: bool) {
    for * cursor : editor.cursors {
        if has_selection(cursor) && !extend_selection {
            selection := get_selection(cursor);
            new_pos := ifx delta < 0 then selection.start else selection.end;
            if cursor.pos != new_pos {
                // Move cursor to the beginning of the selection and update col_wanted
                cursor.pos = new_pos;
                coords := offset_to_coords(buffer, cursor.pos);
                cursor.col_wanted = coords.col;
            }
        }
        coords := offset_to_coords(buffer, cursor.pos);
        coords.line += delta;
        if cursor.col_wanted < 0 then cursor.col_wanted = coords.col;
        coords.col = cursor.col_wanted;
        cursor.pos = coords_to_offset(buffer, coords);
    }

    if delta < 0  editor.cursor_moved = .moved_up;
    else          editor.cursor_moved = .moved_down;
}

move_cursors_to_empty_line :: (editor: *Editor, buffer: Buffer, dir: enum { up; down; }) {
    for * cursor : editor.cursors {
        line := offset_to_line(buffer, cursor.pos);
        if dir == .up {
            while line > 0 {
                line -= 1;
                if is_empty(buffer, line) break;
            }
        } else {
            while line < buffer.line_starts.count - 2 {
                line += 1;
                if is_empty(buffer, line) break;
            }
        }
        cursor.pos = coords_to_offset(buffer, Coords.{ line = line, col = cursor.col_wanted });
    }

    if dir == .up  editor.cursor_moved = .moved_up;
    else           editor.cursor_moved = .moved_down;
}

move_cursors_by_page :: (editor: *Editor, buffer: Buffer, dir: enum { up; down; }) {
    page_size := cast(s32) (window_height / line_height);

    for * cursor : editor.cursors {
        line := offset_to_line(buffer, cursor.pos);
        if dir == .up {
            line -= page_size;
        } else {
            line += page_size;
        }
        cursor.pos = coords_to_offset(buffer, Coords.{ line = line, col = cursor.col_wanted });
    }

    if dir == .up  editor.cursor_moved = .moved_up;
    else           editor.cursor_moved = .moved_down;
}

move_cursors_home :: (editor: *Editor, buffer: Buffer) {
    for * cursor : editor.cursors {
        line := offset_to_line(buffer, cursor.pos);
        start, end := get_line_start_offset(buffer, line), get_line_end_offset(buffer, line);

        text_start_col: s32 = 0;
        i := start;
        while i < end {
            byte := buffer.bytes[i];
            if byte != #char " " && byte != #char "\t" break;
            text_start_col += 1;
            i += 1 + trailingBytesForUTF8[byte];
        }
        if cursor.pos > i || cursor.pos == start then cursor.pos = i; else cursor.pos = start;
        cursor.col_wanted = -1;
    }

    editor.cursor_moved = .unimportant;
}

move_cursors_end :: (editor: *Editor, buffer: Buffer) {
    for * cursor : editor.cursors {
        line := offset_to_line(buffer, cursor.pos);
        cursor.pos = get_line_end_offset(buffer, line);
        cursor.col_wanted = -1;
    }

    editor.cursor_moved = .unimportant;
}

move_to_file_start :: (editor: *Editor, buffer: Buffer) {
    cursor := leave_only_original_cursor(editor);
    cursor.pos = 0;
    cursor.col_wanted = 0;
    editor.cursor_moved = .jumped;
}

move_to_file_end :: (editor: *Editor, buffer: Buffer) {
    cursor := leave_only_original_cursor(editor);
    cursor.pos = cast(s32) buffer.bytes.count;
    cursor.col_wanted = -1;
    editor.cursor_moved = .jumped;
}

break_line :: (editor: *Editor, buffer: *Buffer) {
    // Remember by how much we need to indent the new lines upfront to avoid any scanning of the dirty buffer later
    Space :: struct { start: s32; count: s32; original_start: s32; }  // not a string to avoid invalid pointers
    space_per_cursor := NewArray(editor.cursors.count, Space, initialized = false, allocator = temp);
    for cursor : editor.cursors {
        selection := get_selection(cursor);
        start := get_line_start_offset(buffer, offset_to_line(buffer, selection.start));
        whitespace_bytes := count_whitespace(buffer.bytes, start, selection.start);
        space_per_cursor[it_index] = .{ start = start, count = whitespace_bytes, original_start = start };
    }

    offset_delta := 0;
    for * cursor : editor.cursors {
        space := *space_per_cursor[it_index];
        prev_space := space_per_cursor[max(it_index-1, 0)];
        if space.original_start == prev_space.original_start then space.start = prev_space.start; else space.start += xx offset_delta;  // handle cursors on the same line well
        space_str := to_string(array_view(buffer.bytes, space.start, space.count));
        insert_str := tprint("\n%", space_str);

        cursor.pos += xx offset_delta;
        cursor.sel += xx offset_delta;

        selection := get_selection(cursor);
        if selection.start != selection.end {
            replace_range(buffer, selection, insert_str);
            offset_delta += insert_str.count - (selection.end - selection.start);
        } else {
            insert_string_at_offset(buffer, cursor.pos, insert_str);
            offset_delta += insert_str.count;
        }
        cursor.pos = selection.start + xx insert_str.count;
        cursor.col_wanted = -1;
    }

    editor.cursor_moved = .unimportant;
}

new_line_below :: (editor: *Editor, buffer: *Buffer) {
    Line_Info :: struct { end: s32; space: struct { start, count, original_start: s32; }; last_line: bool; };
    line_info_per_cursor := NewArray(editor.cursors.count, Line_Info, initialized = false, allocator = temp);
    for cursor : editor.cursors {
        selection := get_selection(cursor);
        last_line := offset_to_line(buffer, selection.end);
        start := get_line_start_offset(buffer, last_line);
        end   := get_line_start_offset(buffer, last_line+1);
        whitespace_bytes := count_whitespace(buffer.bytes, start, end);
        line_info_per_cursor[it_index] = .{ end = end, space = .{ start = start, count = whitespace_bytes, original_start = start }, last_line = is_last_line(buffer, last_line) };
    }

    offset_delta := 0;
    for * cursor : editor.cursors {
        line_info := *line_info_per_cursor[it_index];
        prev_line_info := line_info_per_cursor[max(it_index-1, 0)];
        if line_info.space.original_start == prev_line_info.space.original_start then line_info.space.start = prev_line_info.space.start; else line_info.space.start += xx offset_delta;  // handle cursors on the same line well
        line_info.end += xx offset_delta;
        whitespace_str := to_string(array_view(buffer.bytes, line_info.space.start, line_info.space.count));  // construct string from offsets to avoid memory errors on buffer reallocation
        insert_str := ifx line_info.last_line then tprint("\n%\n", whitespace_str) else tprint("%\n", whitespace_str);

        insert_string_at_offset(buffer, line_info.end, insert_str);

        offset_delta += insert_str.count;
        cursor.pos = line_info.end + xx insert_str.count - 1;
        cursor.col_wanted = -1;
    }

    editor.cursor_moved = .unimportant;
}

new_line_above :: (editor: *Editor, buffer: *Buffer) {
    Line_Info :: struct { start: s32; space: struct { start, count, original_start: s32; }; };
    line_info_per_cursor := NewArray(editor.cursors.count, Line_Info, initialized = false, allocator = temp);
    for cursor : editor.cursors {
        selection  := get_selection(cursor);
        first_line := offset_to_line(buffer, selection.start);
        start := get_line_start_offset(buffer, first_line);
        end   := get_line_start_offset(buffer, first_line+1);
        whitespace_bytes := count_whitespace(buffer.bytes, start, end);
        line_info_per_cursor[it_index] = .{ start = start, space = .{ start = start, count = whitespace_bytes, original_start = start } };
    }

    offset_delta := 0;
    for * cursor : editor.cursors {
        line_info := *line_info_per_cursor[it_index];
        prev_line_info := line_info_per_cursor[max(it_index-1, 0)];
        if line_info.space.original_start == prev_line_info.space.original_start then line_info.space.start = prev_line_info.space.start; else line_info.space.start += xx offset_delta;  // handle cursors on the same line well
        line_info.start += xx offset_delta;
        whitespace_str := to_string(array_view(buffer.bytes, line_info.space.start, line_info.space.count));  // construct string from offsets to avoid memory errors on buffer reallocation
        insert_str := tprint("%\n", whitespace_str);

        insert_string_at_offset(buffer, line_info.start, insert_str);

        offset_delta += insert_str.count;
        cursor.pos = line_info.start + xx insert_str.count - 1;
        cursor.col_wanted = -1;
    }

    editor.cursor_moved = .unimportant;
}

delete_word_left :: (editor: *Editor, buffer: *Buffer) {
    skip_one_space := editor.cursors.count == 1;  // we don't want to skip space when editing with multiple cursors
                                                  // because this may surprise people when they see one result with one
                                                  // cursor and a different result with another based on how many
                                                  // spaces there are to the next word
    for * cursor : editor.cursors {
        if !has_selection(cursor) then cursor.pos = scan_through_similar_chars_on_the_left(buffer, cursor.pos, skip_one_space = skip_one_space);
    }
    organise_cursors(editor);  // resolve overlapping selections
    delete_left_char(editor, buffer);
}

delete_word_right :: (editor: *Editor, buffer: *Buffer) {
    skip_one_space := editor.cursors.count == 1;  // see above
    for * cursor : editor.cursors {
        if !has_selection(cursor) then cursor.pos = scan_through_similar_chars_on_the_right(buffer, cursor.pos, skip_one_space = skip_one_space);
    }
    organise_cursors(editor);  // resolve overlapping selections
    delete_right_char(editor, buffer);
}

delete_word_left_no_underscore :: (editor: *Editor, buffer: *Buffer) {
    context.underscore_is_part_of_word = false;
    delete_word_left(editor, buffer);
    context.underscore_is_part_of_word = true;
}

delete_word_right_no_underscore :: (editor: *Editor, buffer: *Buffer) {
    context.underscore_is_part_of_word = false;
    delete_word_right(editor, buffer);
    context.underscore_is_part_of_word = true;
}

delete_left_char :: (editor: *Editor, buffer: *Buffer) {
    // NOTE: we don't have to worry about a cursor with no selection being immediately next
    //       to the non-cursor end of another cursor's selection (thanks to organise_cursors),
    //       so it should be safe to delete at least one character to the left of every cursor if there is one
    range_per_cursor := NewArray(editor.cursors.count, Offset_Range, initialized = false, allocator = temp);
    for cursor : editor.cursors {
        if has_selection(cursor) {
            range_per_cursor[it_index] = get_selection(cursor);
        } else if cursor.pos == 0 {
            range_per_cursor[it_index] = Offset_Range.{};
        } else {
            coords := offset_to_coords(buffer, cursor.pos);
            chars_to_delete := coords.col % TAB_SIZE;
            if coords.col == 0      then chars_to_delete = 1;
            if chars_to_delete == 0 then chars_to_delete = TAB_SIZE;
            if chars_to_delete > 1 {
                // Don't delete more than one char unless the cursor is between line start and text start
                whitespace_bytes := count_whitespace(buffer.bytes, get_line_start_offset(buffer, coords.line), cursor.pos);
                if whitespace_bytes < coords.col then chars_to_delete = 1;
            }
            start := cursor.pos;
            for i : 0..chars_to_delete-1 {
                offset, byte := prev_char_offset(buffer.bytes, start);
                if i == 0 || byte == #char " " start = offset; else break;
            }
            range_per_cursor[it_index] = .{ start = start, end = cursor.pos };
        }
    }

    offset_delta := 0;
    for * cursor : editor.cursors {
        range := range_per_cursor[it_index];
        range.start -= xx offset_delta;
        range.end   -= xx offset_delta;

        delete_range(buffer, range);

        cursor.pos = range.start;
        cursor.col_wanted = -1;

        offset_delta += (range.end - range.start);
    }

    editor.cursor_moved = .unimportant;
}

delete_right_char :: (editor: *Editor, buffer: *Buffer) {
    // NOTE: we don't have to worry about a cursor with no selection being immediately next
    //       to the non-cursor end of another cursor's selection (thanks to organise_cursors),
    //       so it should be safe to delete at least one character to the right of every cursor if there is one

    offset_delta := 0;
    for * cursor : editor.cursors {
        cursor.pos -= xx offset_delta;
        cursor.sel -= xx offset_delta;

        range: Offset_Range;

        if has_selection(cursor) {
            range = get_selection(cursor);
        } else if cursor.pos < buffer.bytes.count {
            end := cursor.pos + 1 + trailingBytesForUTF8[buffer.bytes[cursor.pos]];
            range = .{ start = cursor.pos, end = min(end, cast(s32) buffer.bytes.count) };
        }

        if range.start != range.end {
            delete_range(buffer, range);
            cursor.pos = range.start;
            cursor.col_wanted = -1;
            offset_delta += (range.end - range.start);
        }
    }

    editor.cursor_moved = .unimportant;
}

get_tmp_spaces :: (num: s64) -> string {
    spaces := talloc_string(num);
    memset(spaces.data, cast(u8) #char " ", num);
    return spaces;
}

indent_or_tab :: (editor: *Editor, buffer: *Buffer) {
    indent := true;
    for editor.cursors { if !has_selection(it) { indent = false; break; } }

    if indent {
        indent_lines(editor, buffer);
    } else {
        insert_tab_at_each_cursor(editor, buffer);
    }
}

insert_tab_at_each_cursor :: (editor: *Editor, buffer: *Buffer) {
    spaces := get_tmp_spaces(TAB_SIZE);

    offset_delta: s32 = 0;
    buf_len := cast(s32) buffer.bytes.count;

    for * cursor : editor.cursors {
        new_len := cast(s32) buffer.bytes.count;
        if new_len != buf_len {
            offset_delta += new_len - buf_len;
            cursor.pos += offset_delta;
            cursor.sel += offset_delta;
            buf_len = new_len;
        }

        selection := get_selection(cursor);

        if selection.start != selection.end {
            cursor.pos = selection.start;
            delete_range(buffer, selection);
        }

        if config.settings.insert_spaces_when_pressing_tab {
            // Insert spaces to the next tabstop
            cursor_col := find_col_by_scanning_left(buffer, cursor.pos);  // @line_wrap: check
            to_next_tabstop := TAB_SIZE - cursor_col % TAB_SIZE;
            spaces.count = to_next_tabstop;
            insert_string_at_offset(buffer, cursor.pos, spaces);
            cursor.pos += to_next_tabstop;
        } else {
            // Insert tab
            insert_string_at_offset(buffer, cursor.pos, "\t");
            cursor.pos += 1;
        }
        cursor.sel = cursor.pos;
        cursor.col_wanted = -1;
    }

    editor.cursor_moved = .unimportant;
}

get_line_starts_for_lines_with_cursors_tmp :: (editor: *Editor, buffer: *Buffer) -> [..] s64 /* tmp */, last_line_end_offset: s64 {
    line_starts: [..] s64;
    line_starts.allocator = temp;

    last_added := -1;
    last_line_end_offset := 0;
    for cursor : editor.cursors {
        selection := get_selection(cursor);
        start_line := offset_to_line(buffer, selection.start);
        end_line   := ifx selection.start != selection.end then offset_to_line(buffer, selection.end) else start_line;
        for start_line..end_line {
            line_start := get_line_start_offset(buffer, it);
            if last_added < line_start { array_add(*line_starts, line_start); last_added = line_start; }
        }
        last_line_end_offset = get_line_start_offset(buffer, end_line+1);
    }

    return line_starts, last_line_end_offset;
}

indent_lines :: (editor: *Editor, buffer: *Buffer) {
    spaces   := ifx config.settings.insert_spaces_when_pressing_tab get_tmp_spaces(TAB_SIZE) else "\t";
    tab_size := cast(s32) spaces.count;

    // Find lines which will be affected (we don't want to indent the same line more than once if it has more than 1 cursor on it)
    line_starts, last_line_end_offset := get_line_starts_for_lines_with_cursors_tmp(editor, buffer);

    // Indent cursors
    for * cursor : editor.cursors {
        pos := cursor.pos;
        sel := cursor.sel;
        for line_start : line_starts { // @tabs
            if line_start <= pos then cursor.pos += tab_size;
            if line_start <= sel then cursor.sel += tab_size;
            if line_start > pos && line_start > sel break;
        }
        cursor.col_wanted += tab_size;
    }

    // Build a replacement string
    b: String_Builder;  // not using the temp allocator because the string may be too large
    array_add(*line_starts, last_line_end_offset);
    for 0..line_starts.count-2 {
        start, end := line_starts[it], line_starts[it+1];
        append(*b, spaces);
        append(*b, to_string(array_view(buffer.bytes, start, end-start)));
    }
    new_str := builder_to_string(*b);
    defer free(new_str);

    range := Offset_Range.{ start = xx line_starts[0], end = xx last_line_end_offset };
    replace_range(buffer, range, new_str);

    editor.cursor_moved = .unimportant;
}

unindent_lines :: (editor: *Editor, buffer: *Buffer) {
    // Find lines which will be affected (we don't want to unindent the same line more than once if it has more than 1 cursor on it)
    line_starts, last_line_end_offset := get_line_starts_for_lines_with_cursors_tmp(editor, buffer);
    array_add(*line_starts, last_line_end_offset);

    // Remove spaces and keep a running offset delta to unindent cursors
    // (properly handle the case when cursor is in the deleted range)
    b: String_Builder;  // not using the temp allocator because the string may be too large
    spaces_removed := 0;
    for 0..line_starts.count-2 {
        start, end := line_starts[it], line_starts[it+1];
        if start >= buffer.bytes.count continue;
        spaces_at_line_start := 0;
        if buffer.bytes[start] == #char "\t" {
            // When seeing a tab, just remove it (and do nothing else)
            spaces_at_line_start = 1;
        } else {
            for start..min(start + TAB_SIZE, end - 1) - 1 {
                if buffer.bytes[it] != #char " " break;
                spaces_at_line_start += 1;
            }
        }
        adjusted_start := start - spaces_removed;
        for * cursor : editor.cursors {
            if cursor.pos > adjusted_start then cursor.pos -= xx min(cursor.pos - adjusted_start, spaces_at_line_start);
            if cursor.sel > adjusted_start then cursor.sel -= xx min(cursor.sel - adjusted_start, spaces_at_line_start);
        }
        new_start := start + spaces_at_line_start;
        append(*b, to_string(array_view(buffer.bytes, new_start, end-new_start)));
        spaces_removed += spaces_at_line_start;
    }
    new_str := builder_to_string(*b);
    defer free(new_str);

    range := Offset_Range.{ start = xx line_starts[0], end = xx last_line_end_offset };
    replace_range(buffer, range, new_str);

    for * cursor : editor.cursors { cursor.col_wanted = -1; }

    editor.cursor_moved = .unimportant;
}

remove_additional_cursors :: (editor: *Editor) {
    cursor := leave_only_original_cursor(editor);
    cursor.sel = cursor.pos;
    editor.cursor_moved = .refresh_only;
}

select_all :: (editor: *Editor, buffer: Buffer) {
    cursor := leave_only_original_cursor(editor);
    cursor.sel = 0;
    cursor.pos = cast(s32) buffer.bytes.count;
}

Line_Range :: struct { prev_line_start: s32; next_line_end: s32; range: Offset_Range; is_last: bool; next_line_is_last: bool; };

get_whole_line_ranges_for_cursors :: (editor: Editor, buffer: Buffer, merge_adjacent := true, select_next_for_single_lines := false) -> [] Line_Range /* tmp */ {
    line_ranges: [..] Line_Range;
    line_ranges.allocator = temp;
    // @line_wrap: use real_line_starts
    {
        last_end_line := -1;
        for cursor : editor.cursors {
            selection := get_selection(cursor);
            start_line := offset_to_line(buffer, selection.start);
            end_line   := ifx selection.start != selection.end then offset_to_line(buffer, selection.end) else start_line;
            if start_line == end_line && select_next_for_single_lines then end_line += 1;

            next_line_end := get_line_start_offset(buffer, end_line+2);

            should_extend := line_ranges.count > 0 && (
                (merge_adjacent  && start_line <= last_end_line+1) ||
                (!merge_adjacent && start_line <= last_end_line)
            );

            if should_extend {
                // Extend last line range
                line_ranges[line_ranges.count-1].range.end = get_line_start_offset(buffer, end_line+1);
                line_ranges[line_ranges.count-1].next_line_end = next_line_end;
                line_ranges[line_ranges.count-1].is_last = is_last_line(buffer, end_line);
                line_ranges[line_ranges.count-1].is_last = !is_last_line(buffer, end_line) && is_last_line(buffer, end_line + 1);
            } else {
                // Add a new line range
                array_add(*line_ranges, Line_Range.{
                    prev_line_start   = get_line_start_offset(buffer, start_line-1),
                    next_line_end     = next_line_end,
                    range             = .{ start = get_line_start_offset(buffer, start_line), end = get_line_start_offset(buffer, end_line+1) },
                    is_last           = is_last_line(buffer, end_line),
                    next_line_is_last = !is_last_line(buffer, end_line) && is_last_line(buffer, end_line + 1),
                });
            }
            last_end_line = end_line;
        }
    }
    return line_ranges;
}

duplicate_lines :: (editor: *Editor, buffer: *Buffer) {
    lines := get_whole_line_ranges_for_cursors(editor, buffer, merge_adjacent = false);

    offset_delta := 0;
    for * line : lines {
        line.range.start += xx offset_delta;
        line.range.end   += xx offset_delta;
        str := copy_temporary_string(get_range_as_string(buffer, line.range));
        insert_string_at_offset(buffer, line.range.end, str);
        add_paste_animation(editor, .{ start = line.range.end, end = line.range.end + cast(s32)str.count });

        for * cursor : editor.cursors {
            if line.range.start <= cursor.pos {  // no need to check for cursor.sel because we have whole line ranges
                cursor.pos += xx str.count;
                cursor.sel += xx str.count;
            }
        }

        offset_delta += str.count;
    }

    editor.cursor_moved = .large_edit;
}

move_lines_up :: (editor: *Editor, buffer: *Buffer) {
    lines := get_whole_line_ranges_for_cursors(editor, buffer);

    for line : lines {
        prev_line_range := Offset_Range.{ start = line.prev_line_start, end = line.range.start };
        prev_str := copy_temporary_string(get_range_as_string(buffer, prev_line_range));
        if !prev_str continue;  // we're at the top

        delete_range(buffer, prev_line_range);
        // add_paste_animation(editor, .{ start = prev_line_range.start, end = prev_line_range.start + line.range.end - line.range.start });

        for * cursor : editor.cursors {
            if line.range.start <= cursor.pos && cursor.pos <= line.range.end {  // no need to check for cursor.sel because we have whole line ranges
                cursor.pos -= xx prev_str.count;
                cursor.sel -= xx prev_str.count;
            }
        }
        insert_string_at_offset(buffer, line.range.end - prev_str.count, ifx line.is_last then tprint("\n%", prev_str) else prev_str);
    }

    editor.cursor_moved = .moved_up_with_edit;
}

move_lines_down :: (editor: *Editor, buffer: *Buffer) {
    lines := get_whole_line_ranges_for_cursors(editor, buffer);

    for line : lines {
        next_line_range := Offset_Range.{ start = line.range.end, end = line.next_line_end };
        if next_line_range.end <= next_line_range.start continue;  // we're at the bottom
        next_str := copy_temporary_string(get_range_as_string(buffer, next_line_range));

        delete_range(buffer, next_line_range);
        insert_string_at_offset(buffer, line.range.start, ifx line.next_line_is_last then tprint("%\n", next_str) else next_str);
        // add_paste_animation(editor, .{ start = line.range.start + cast(s32)next_str.count, end = line.range.end + cast(s32)next_str.count });

        for * cursor : editor.cursors {
            if line.range.start <= cursor.pos && cursor.pos <= line.range.end {  // no need to check for cursor.sel because we have whole line ranges
                cursor.pos += xx next_str.count;
                cursor.sel += xx next_str.count;
            }
        }
    }

    editor.cursor_moved = .moved_down_with_edit;
}


join_lines :: (editor: *Editor, buffer: *Buffer, in_between := " ") {
    ranges := get_whole_line_ranges_for_cursors(editor, buffer, merge_adjacent = false, select_next_for_single_lines = true);

    b: String_Builder;
    b.allocator = temp;

    Deletion :: struct { offset: s64; amount: s64; }
    deletions: [..] Deletion;  // for easy cursor adjustments
    deletions.allocator = temp;

    add_deletion :: (amount: s64) #expand {
        if amount != 0 then array_add(*`deletions, Deletion.{ offset = `delete_offset, amount = amount });
    }

    offset_delta := 0;

    for * range : ranges {
        range.range.start += xx offset_delta;
        range.range.end   += xx offset_delta;

        range_str := get_range_as_string(buffer, range.range);
        individual_lines := split(trim_right(range_str, " \t"), cast(u8) #char "\n");
        if individual_lines.count <= 1 continue;  // nothing to join

        first_line         := individual_lines[0];
        first_line_trimmed := trim_right(first_line, " \t");
        remaining_lines    := array_view(individual_lines, 1, individual_lines.count - 1);

        delete_offset := range.range.start + first_line_trimmed.count;
        add_deletion(first_line.count - first_line_trimmed.count);

        append(*b, first_line_trimmed);
        for line : remaining_lines {
            trimmed, left, right := trim_both_sides(line);
            padding := ifx trimmed then in_between.count else 0;
            add_deletion(left + 1 - padding);
            if !trimmed continue;
            append(*b, in_between);
            append(*b, trimmed);
            delete_offset += trimmed.count + in_between.count;
            add_deletion(right);
        }
        append(*b, "\n");
        add_deletion(-1);

        new_str := builder_to_string(*b, do_reset = true);
        replace_range(buffer, range.range, new_str);
        add_paste_animation(editor, .{ start = range.range.start + cast(s32)first_line.count, end = range.range.start + cast(s32)new_str.count });

        offset_delta += new_str.count - range_str.count;
    }


    // Adjust cursors
    for * cursor, cursor_id : editor.cursors {
        for deletion : deletions {
            if cursor.pos >= deletion.offset then cursor.pos = xx max(cursor.pos - deletion.amount, deletion.offset);
            if cursor.sel >= deletion.offset then cursor.sel = xx max(cursor.sel - deletion.amount, deletion.offset);
        }
    }

    editor.cursor_moved = .large_edit;
}

delete_line :: (editor: *Editor, buffer: *Buffer, go_up := false) {
    lines := get_whole_line_ranges_for_cursors(editor, buffer);

    offset_delta := 0;

    for * line : lines {
        line.prev_line_start -= xx offset_delta;
        line.range.start -= xx offset_delta;
        line.range.end   -= xx offset_delta;

        str := get_range_as_string(buffer, line.range);
        delete_range(buffer, line.range);

        for * cursor : editor.cursors {
            if line.range.start <= cursor.pos && cursor.pos <= line.range.end {  // no need to check for cursor.sel because we have whole line ranges
                cursor.pos = ifx go_up then line.prev_line_start else line.range.start;
                cursor.col_wanted = -1;
            } else if cursor.pos >= line.range.end {
                cursor.pos -= xx str.count;
                cursor.sel -= xx str.count;
            }
        }

        offset_delta += str.count;
    }

    editor.cursor_moved = .unimportant;
}

delete_to_start_of_line :: (editor: *Editor, buffer: *Buffer) {
    for * cursor : editor.cursors {
        selection := get_selection(cursor);
        cursor.sel = selection.end;
        cursor.pos = get_line_start_offset(buffer, offset_to_line(buffer, selection.start));
    }
    organise_cursors(editor);  // resolve overlapping selections
    delete_left_char(editor, buffer);
}

delete_to_end_of_line :: (editor: *Editor, buffer: *Buffer) {
    for * cursor : editor.cursors {
        selection := get_selection(cursor);
        cursor.sel = selection.start;
        cursor.pos = get_line_end_offset(buffer, offset_to_line(buffer, selection.end));
    }
    organise_cursors(editor);  // resolve overlapping selections
    delete_right_char(editor, buffer);
}

copy_selection_to_clipboard :: (editor: *Editor, buffer: *Buffer, cut := false) {
    any_selection := false;
    for cursor : editor.cursors { if has_selection(cursor) { any_selection = true; break; } }

    if !any_selection && (cut || config.settings.copy_whole_line_without_selection) {
        // If no cursors have a selection, then pressing cut will cut whole lines
        // (or copy them if it's enabled in the config file)
        for * cursor : editor.cursors {
            // Select the whole line
            line := offset_to_line(buffer, cursor.pos);
            cursor.sel = get_line_start_offset(buffer, line);
            cursor.pos = get_line_start_offset(buffer, line+1);
            cursor.col_wanted = -1;
        }
        organise_cursors(editor);  // resolve overlapping selections
    } else if !any_selection {
        return;  // don't want to trash the clipboard when you accidentally press Ctrl+C
    }

    b: String_Builder;
    offset := 0;
    for * cursor : editor.cursors {
        str := get_selected_string(cursor, buffer);
        append(*b, str);
        if it_index < editor.cursors.count-1 && str && str[str.count-1] != #char "\n" then append(*b, "\n");
        cursor.clipboard = .{ start = xx offset, count = xx str.count };
        offset += str.count + 1;
    }

    combined_str := builder_to_string(*b);
    if combined_str {
        os_clipboard_set_text(combined_str);
        if editor.clipboard then free(editor.clipboard);
        editor.clipboard = combined_str;  // now it owns it
    }

    if cut {
        offset_delta := 0;
        for * cursor : editor.cursors {
            cursor.pos -= xx offset_delta;
            cursor.sel -= xx offset_delta;
            selection := get_selection(cursor);
            delete_range(buffer, selection);
            cursor.col_wanted = -1;
            cursor.pos = selection.start;
            offset_delta += selection.end - selection.start;
        }
        editor.cursor_moved = .refresh_only;
    }
}

paste_from_clipboard :: (editor: *Editor, buffer: *Buffer) {
    system_clipboard_text := os_clipboard_get_text();

    if system_clipboard_text != editor.clipboard {
        // Editor clipboard and system clipboard are out of sync - drop the editor one
        if editor.clipboard free(editor.clipboard);
        editor.clipboard = system_clipboard_text;
        for * cursor : editor.cursors { cursor.clipboard = .{ start = 0, count = xx editor.clipboard.count }; }
    } else {
        free(system_clipboard_text);
    }

    offset_delta := 0;
    for * cursor : editor.cursors {
        cursor.pos += xx offset_delta;
        cursor.sel += xx offset_delta;
        selection := get_selection(cursor);
        str := get_clipboard_string(editor, cursor);
        replace_range(buffer, selection, str);
        cursor.pos = xx (selection.start + str.count);
        cursor.col_wanted = -1;
        offset_delta += str.count - (selection.end - selection.start);

        add_paste_animation(editor, Offset_Range.{ start = selection.start, end = selection.start + cast(s32) str.count });
    }

    editor.cursor_moved = .large_edit;
}

toggle_comment :: (editor: *Editor, buffer: *Buffer) {
    comment_without_space: string;
    comment: string;

    if buffer.lang == {
        case .C;            comment_without_space = "//";
        case .CSharp;       comment_without_space = "//";
        case .Jai;          comment_without_space = "//";
        case .Focus_Config; comment_without_space = "#";
        case;               return;
    }
    comment = tprint("% ", comment_without_space);

    // Get the affected lines
    line_starts, last_line_end_offset := get_line_starts_for_lines_with_cursors_tmp(editor, buffer);
    array_add(*line_starts, last_line_end_offset);

    // Figure out whether we're commenting out or removing comments
    min_whitespace := -1;
    add_comment := false;
    for 0..line_starts.count-2 {
        start, end := line_starts[it], line_starts[it+1];
        str := to_string(array_view(buffer.bytes, start, end-start));
        trimmed_str := trim_left(str, " \r\n\t");
        if !trimmed_str continue;

        if !add_comment && !begins_with(trimmed_str, comment_without_space) then add_comment = true;
        len_whitespace := str.count - trimmed_str.count;
        if min_whitespace < 0 || len_whitespace < min_whitespace then min_whitespace = len_whitespace;
    }
    if min_whitespace < 0 then min_whitespace = 0;

    // Build a replacement string
    b: String_Builder;  // not using temp because the string may be too large
    if add_comment {
        // Add comments to nonempty strings
        spaces := get_tmp_spaces(min_whitespace);
        chars_added := 0;
        for 0..line_starts.count-2 {
            start, end := line_starts[it], line_starts[it+1];
            if start > buffer.bytes.count continue;
            str := to_string(array_view(buffer.bytes, start, end-start));
            trimmed_str := trim_left(str, " \r\n\t");
            if !trimmed_str { append(*b, str); continue; }  // append as is

            append(*b, spaces);
            append(*b, comment);
            append(*b, to_string(array_view(buffer.bytes, start + min_whitespace, end - start - min_whitespace)));

            adjusted_start := start + chars_added + min_whitespace;
            for * cursor : editor.cursors {
                if cursor.pos >= adjusted_start then cursor.pos += xx comment.count;
                if cursor.sel >= adjusted_start then cursor.sel += xx comment.count;
            }

            chars_added += comment.count;
        }
    } else {
        // Remove comments from nonempty strings
        chars_removed := 0;
        for 0..line_starts.count-2 {
            start, end := line_starts[it], line_starts[it+1];
            if start > buffer.bytes.count continue;
            str := to_string(array_view(buffer.bytes, start, end-start));
            trimmed_str := trim_left(str, " \r\n\t");
            if !trimmed_str { append(*b, str); continue; }  // append as is

            len_whitespace := str.count - trimmed_str.count;
            append(*b, to_string(array_view(buffer.bytes, start, len_whitespace)));  // spaces before the comment
            advance(*str, len_whitespace);
            len_comment := ifx begins_with(str, comment) then comment.count else comment_without_space.count;
            advance(*str, len_comment);
            append(*b, str);

            adjusted_start := start - chars_removed + len_whitespace;
            for * cursor : editor.cursors {
                if cursor.pos >= adjusted_start then cursor.pos -= xx min(len_comment, cursor.pos - adjusted_start);
                if cursor.sel >= adjusted_start then cursor.sel -= xx min(len_comment, cursor.sel - adjusted_start);
            }

            chars_removed += len_comment;
        }
    }

    new_str := builder_to_string(*b);
    defer free(new_str);

    range := Offset_Range.{ start = xx line_starts[0], end = xx last_line_end_offset };
    replace_range(buffer, range, new_str);

    for * cursor : editor.cursors { cursor.col_wanted = -1; }

    editor.cursor_moved = .unimportant;
}

free_editor :: (using editor: *Editor) {
    array_reset(*cursors);
    if clipboard free(clipboard);
    array_reset(*paste_animations);
    array_reset(*highlights);
    array_reset(*search_bar.results);
}

#scope_export

Editor :: struct {
    buffer_id: s64;

    cursors: [..] Cursor;
    main_cursor: s64;      // newly added cursors become main so that we jump to them
    original_cursor: s64;  // we remember the original cursor when first creating multiple cursors (and go back to it on escape)

    clipboard: string;

    search_whole_words := false;  // used when creating new cursors
    cursor_moved := Cursor_Movement.has_not_moved; // this may trigger a scroll so that the cursor is within acceptable bounds

    new_cursor_just_created_using_mouse := false;  // useful to know in order to handle select-by-drag and select-word with the new cursor
    last_cursor_created_using_mouse_at: Time;

    scroll_to_cursor: enum u8 { no; yes; yes_new_editor; }  // trigger a scroll so that the cursor is in the center vertically

    highlights: [..] Text_Highlight;
    refresh_highlights: bool;
    selected_text_length: s64;

    search_bar: Search_Bar;

    viewport: Viewport;

    paste_animations: [..] Paste_Animation;
}

Cursor_Movement :: enum u8 {
    has_not_moved;
    unimportant;
    moved_up;
    moved_down;
    moved_up_with_edit;
    moved_down_with_edit;
    // movements above here can be merged in history
    jumped;
    large_edit;
    selection;
    refresh_only;
}

Viewport :: struct {
    top:  s32;
    left: s32;
    glue_point: Glue_Point;
    scroll_y := #run Tween_Animation(s32).{ speed = xx 0.1, func = .lerp };
    scroll_x := #run Tween_Animation(s32).{ speed = xx 0.1, func = .lerp };

    max_line_pixel_width: s32;

    Glue_Point :: struct { buffer_pos: s32; offset_within_line: s32; }
}

Search_Bar :: struct {
    active   := false;      // it receives keyboard input when active.
    mode: Mode = .classic;

    width_percentage := WIDTH_NORMAL;  // how much of the screen the popup occupies
    width_anim := #run Tween_Animation(float).{ start = WIDTH_NORMAL, target = WIDTH_NORMAL };
    WIDTH_NORMAL   :: 0.5;
    WIDTH_EXPANDED :: 0.9;

    input: Text_Input;

    results: [..] Text_Highlight;
    selected_result: s64 = -1;
    search_point_offset: s32;  // the point used to determine the next search result. Fixed so that we can set cursor without jumping around
    case_sensitive: bool;
    whole_word: bool;

    original_cursor_position: Cursor.State;  // remember main cursor position so we can go back to it on Esc
    jumped := false;

    per_page := 10;
    scroll_to_selected: Scroll_Mode = .no;
    scroll_anim := #run Tween_Animation(s32).{ speed = xx 0.1, func = .lerp };
    scroll_y: s32;

    Mode :: enum { classic; dropdown; }
}

// What to select when dragging
Selection_Mode :: struct {
    type: enum { chars; words; lines; } = .chars;
    range:     Offset_Range;
    min_range: Offset_Range;
}

Scroll_Mode :: enum { no; yes; snap; };

Text_Highlight :: struct {
    offset: s64;    // we'll convert this to position range, but only for the visible highlights
    line: s32;      // useful to know line immediately to display in the scrollbar area
}

Paste_Animation :: struct {
    range: Offset_Range;
    coords_range: Coords_Range;
    initted := false;
    started_at: Time;
    SPEED :: 0.3;
}

Editor_State :: struct {
    layout: Layout = .None;

    active: s64 = -1;
    left:   s64 = -1;
    right:  s64 = -1;

    expanded := false;  // whether the active editor should be larger
    closing  := false;  // whether the active editor is currently being closed (so that we can change the layout when it's done closing)

    Layout :: enum u8 {
        None    :: 0;
        Single  :: 1;
        Double  :: 2;
    }
}

// When opening a new editor, we can specify where in the layout it should go
Editor_Placement :: enum {
    in_place;
    on_the_side;
    left;
    right;
}

open_buffers: Simple_Bucket_Array(Buffer, items_per_bucket = 1024, max_buckets = 1024);  // 8 Kb for pointer array, ~1 million buffers is the maximum
open_editors: [..] Editor;
buffers_table: Table(string, s64);  // a map from full buffer path to buffer id (only for the open buffers, obviously)

open_buffers_lock: Mutex;  // must hold while adding a new buffer

editors: Editor_State;
editor_history: Editor_History;
current_editor_history_size := -1;

// Keyboard smooth scrolling
Smooth_Scroll_Direction :: enum {
    none;
    up;
    down;
    left;
    right;
}
editor_smooth_scroll: struct {
    direction: Smooth_Scroll_Direction;
    fast: bool;
    started_at: Time;
    start_x: s32;
    start_y: s32;
};

splitter_pos:  float = 0.5;  // 0.5 means it's in the middle
splitter_anim: Tween_Animation(float);


Editor_History :: struct {
    frames : [..] Editor_History_Frame;
    head : int;
    tail : int;
    current : int;
}

Editor_History_Frame :: struct {
    active_editor_id: s64;
    left_editor_id: s64;
    right_editor_id: s64;
    pos: s32;
    cursor_movement : Cursor_Movement;
}

operator== :: (a: Editor_History_Frame, b: Editor_History_Frame) -> bool {
    return a.active_editor_id == b.active_editor_id
        && a.left_editor_id   == b.left_editor_id
        && a.right_editor_id  == b.right_editor_id
        && a.pos == b.pos;
}

next_history_index :: (f: s64) -> s64 {
    return (f + 1) % config.settings.editor_history_size;
}

previous_history_index :: (f: s64) -> s64 {
    if f == 0  return config.settings.editor_history_size - 1;
    else       return f - 1;
}

maybe_save_editor_history :: () -> saved: bool {
    if editors.layout == .None  return false;

    editor := *open_editors[editors.active];
    if editor.cursor_moved == .refresh_only  return false;

    frame := Editor_History_Frame.{
        active_editor_id = editors.active,
        left_editor_id = ifx editors.layout == .None then -1
                         else ifx editors.layout == .Single then editors.active
                         else editors.left,
        right_editor_id = ifx editors.layout == .Double then editors.right else -1,
        pos = editor.cursors[editor.main_cursor].pos,
        cursor_movement = editor.cursor_moved,
    };

    return maybe_add_to_editor_history(*editor_history, frame);
}

maybe_add_to_editor_history :: (using history: *Editor_History, frame: Editor_History_Frame) -> added: bool {
    if frames.count == 0 {
        array_add(*frames, frame);
        head, tail, current = 0;
        return true;
    }

    if frames[current] == frame  return false;

    previous_index := current;
    current = next_history_index(current);
    if current == tail
        tail = next_history_index(tail);

    frames_are_mergable :: (a: Editor_History_Frame, b: Editor_History_Frame) -> bool #expand {
        return a.cursor_movement < .jumped
            && a.cursor_movement == b.cursor_movement
            && a.active_editor_id == b.active_editor_id;
    }

    should_merge_frame := false;
    previous_frame := frames[previous_index];
    if frames_are_mergable(frame, previous_frame) && frames.count > 2 {
        // We want to keep the first frame of a move type, and then keep overwriting the second frame
        // of that type. So, check if this is the third frame of that type.
        previous_previous_frame := frames[previous_history_index(previous_index)];
        if frames_are_mergable(previous_previous_frame, previous_frame)
            should_merge_frame = true;
    }

    // When a pane closes it may result in two updates: the cursor moving over to the
    // other pane and then the pane being closed.  In these cases we should overwrite the
    // former with the latter so it is stored as a single step.
    should_merge_frame |=
       frame.right_editor_id == -1 && previous_frame.right_editor_id != -1
    && frame.active_editor_id == previous_frame.active_editor_id
    && frame.pos == previous_frame.pos
    && (frame.left_editor_id == previous_frame.left_editor_id || frame.left_editor_id == previous_frame.right_editor_id);

    if should_merge_frame {
        current = previous_index;
    }
    else {
        if head != previous_index {
            // We're not at the head of the history; we're going to ditch all the history ahead of where we are,
            // but we'll keep the head frame intact ahead of us, allowing the user to jump back to "the present".
            new_head := next_history_index(current);
            if new_head == tail  tail = next_history_index(tail);
            set_history_frame(new_head, frames[head]);
            head = new_head;
        }
        else {
            head = current;
        }
    }

    set_history_frame(current, frame);

    return true;
}

set_history_frame :: (index: s64, frame: Editor_History_Frame) {
    using editor_history;
    if index < frames.count
        frames[index] = frame;
    else
        array_add(*frames, frame);
}

dump_editor_history :: () {
    using editor_history;
    if frames.count == 0  return;

    print("Editor History:\n");
    i := tail;
    last_index := next_history_index(head);
    while i != last_index {
        print("%\n", frames[i]);
        i = next_history_index(i);
    }
}

move_to_previous_editor_history :: () {
    using editor_history;
    if frames.count == 0 || current == tail
        return;

    current = previous_history_index(current);
    move_to_editor_history_frame(frames[current]);
}

move_to_next_editor_history :: () {
    using editor_history;
    if frames.count == 0 || current == head
        return;

    current = next_history_index(current);
    move_to_editor_history_frame(frames[current]);
}

move_to_editor_history_frame :: (frame: Editor_History_Frame) {
    set_editor_panes(frame.left_editor_id, frame.right_editor_id, frame.active_editor_id);
    editor := *open_editors[editors.active];
    cursor := leave_only_original_cursor(editor);
    cursor.pos = frame.pos;
    cursor.sel = cursor.pos;
    put_cursor_in_valid_spot(cursor, open_buffers[editor.buffer_id]);
    add_paste_animation(editor, get_selection(cursor));
    editor.scroll_to_cursor = .yes;
}


#scope_file

cursor_blink_start: Time;
cursors_blinking := false;

CURSOR_BLINK_SPEED_MS   :: 500;
CURSOR_BLINK_TIMEOUT_MS :: 5_000;  // when to stop blinking on inaction

#import "Clipboard";
