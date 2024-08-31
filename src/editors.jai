#add_context current_editor_id := -1;

editors_handle_event :: (event: Input.Event) -> handled: bool {
    mods := event.modifier_flags;

    if event.type == {
        case .KEYBOARD;
            if event.key_pressed {
                action, mapping := map_event_to_action(event, Action_Editors);
                if active_hold_actions && !is_hold_action(action) return true;  // don't execute any non-hold actions while hold actions are active

                editor, buffer := get_active_editor_and_buffer();
                if editor {
                    return active_editor_handle_event(editor, buffer, event, action);
                } else {
                    if action == {
                        case .escape;           #through;
                        case .close_dialog;     hide_build_panel();     return true;
                    }
                    return false;
                }
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
            if config.settings.hide_mouse_when_typing platform_show_cursor(false);
            if !key_sequence_input_in_progress() {
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

active_editor_handle_event :: (editor: *Editor, buffer: *Buffer, event: Input.Event, action: Action_Editors) -> handled: bool {
    context.current_editor_id = editors.active;  // used for edit notifications
    defer context.current_editor_id = -1;

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

        // Handle editor actions which make sense while the search bar is open
        editor_action := map_event_to_action(event, Action_Editors);
        if editor_action == {
            case .select_all_occurrences;           select_all_occurrences(editor, buffer, to_string(input.text)); close_search_bar(editor); return true;
        }

        // Handle search dialog actions
        action := map_event_to_action(event, Action_Search_Dialog);
        if action == {
            case .toggle_expand;                    search_bar_toggle_expand(editor);                                                   return true;
            case .toggle_case_sensitive;            search_bar_toggle_case_sensitive(editor, buffer);                                   return true;
            case .toggle_whole_word;                search_bar_toggle_whole_word(editor, buffer);                                       return true;
            case .toggle_regex_search;              search_bar_toggle_regex_search(editor, buffer);                                     return true;

            case .search_in_buffer;                 open_search_bar(editor, buffer, remember_cursor_position = false);                  return true;
            case .search_in_buffer_dropdown_mode;   open_search_bar(editor, buffer, .dropdown, remember_cursor_position = false);       return true;

            case .move_up;                          search_bar_move_cursor(editor, buffer, -1, wrap = true);                            return true;
            case .move_down;                        search_bar_move_cursor(editor, buffer,  1, wrap = true);                            return true;
            case .move_up_fast;                     search_bar_move_cursor(editor, buffer, -5);                                         return true;
            case .move_down_fast;                   search_bar_move_cursor(editor, buffer,  5);                                         return true;

            case .close_all_editors;                close_search_bar(editor); close_all_editors();                                      return true;
            case .close_other_editors;              close_search_bar(editor); close_other_editors();                                    return true;
            case .close_current_editor;             close_search_bar(editor); close_editor(.current);                                   return true;
            case .close_other_editor;               close_editor(.other);                                                               return true;
            case .close_left_editor;                if editors.active == editors.left  close_search_bar(editor); close_editor(.left);   return true;
            case .close_right_editor;               if editors.active == editors.right close_search_bar(editor); close_editor(.right);  return true;

            case .choose_language;                  close_search_bar(editor); show_dialog(*language_dialog);                            return true;
        }

        if mode == .classic {
            if action == {
                case .escape;                       #through;
                case .close_dialog;                 close_search_bar(editor);                                       return true;
                case .open_entry_in_place;          search_bar_move_cursor(editor, buffer,  1, wrap = true);        return true;
            }
        } else {
            if action == {
                case .escape;                       #through;
                case .close_dialog;                 close_search_bar(editor, jump_to_original_cursor = true);       return true;

                case .move_up_one_page;             search_bar_move_cursor(editor, buffer, -per_page);              return true;
                case .move_down_one_page;           search_bar_move_cursor(editor, buffer,  per_page);              return true;

                case .open_entry_in_place;          close_search_bar(editor, jump_to_selected_result = true);       return true;
                case .open_entry_on_the_side;       search_bar_open_selected_result(editor, buffer, .on_the_side);  return true;
                case .open_entry_on_the_left;       search_bar_open_selected_result(editor, buffer, .left);         return true;
                case .open_entry_on_the_right;      search_bar_open_selected_result(editor, buffer, .right);        return true;
            }
        }
        return false;
    }

    // We always want to put some actions in a separate edit group (e.g. block indent)
    new_group := false;
    for cursor : editor.cursors { if new_edit_group_required_for_action(action, cursor) { new_group = true; break; } }
    if new_group || (to_float64_seconds(frame_time) - buffer.last_edit_time) >= EDIT_GROUP_TIMEOUT then new_edit_group(buffer, editor);  // do it before action

    // We want to remember where cursors were before we do any edits
    if buffer.edits.count == 0 {
        resize(*buffer.cursors, editor.cursors.count);
        for * cursor, i : buffer.cursors { cursor.* = editor.cursors[i]; }
    }

    keep_selection := false;
    enabled_whole_words := false;

    handled := true;

    if action == {
        // General actions (which are not associated with any cursor)
        case .toggle_expand;                    toggle_expand();
        case .search_in_buffer;                 open_search_bar(editor, buffer);
        case .search_in_buffer_dropdown_mode;   open_search_bar(editor, buffer, .dropdown);
        case .close_all_editors;                close_all_editors();
        case .close_other_editors;              close_other_editors();
        case .close_current_editor;             close_editor(.current);
        case .close_other_editor;               close_editor(.other);
        case .close_left_editor;                close_editor(.left);
        case .close_right_editor;               close_editor(.right);

        case .close_dialog;                     hide_build_panel();
        case .escape;                           if editor.cursors.count == 1 hide_build_panel();
                                                remove_additional_cursors(editor);
                                                reset_search_results(*editor.search_bar);
                                                editor.refresh_selection = true;

        case .save;                             save(editor, editors.active);
        case .save_all;                         save_all();
        case .save_as;                          defer_action_save_as(editor.buffer_id);
        case .move_current_file;                defer_action_move   (editor.buffer_id);
        case .delete_current_file;              defer_action_delete (editor.buffer_id);

        case .switch_to_left_editor;            switch_to_editor(.left);
        case .switch_to_right_editor;           switch_to_editor(.right);
        case .switch_to_other_editor;           switch_to_editor(.other);
        case .duplicate_editor;                 switch_to_editor(.other, duplicate_current = true);
        case .duplicate_editor_to_the_left;     switch_to_editor(.left, duplicate_current = true);
        case .duplicate_editor_to_the_right;    switch_to_editor(.right, duplicate_current = true);

        case .move_editor_to_the_left;          if editors.active == editors.right then swap_panes();
        case .move_editor_to_the_right;         if editors.active == editors.left  then swap_panes();

        case .scroll_viewport_up;               smooth_scroll(editor, direction = .up);                 activate_hold_action(action, event);
        case .scroll_viewport_up_fast;          smooth_scroll(editor, direction = .up, fast = true);    activate_hold_action(action, event);
        case .scroll_viewport_down;             smooth_scroll(editor, direction = .down);               activate_hold_action(action, event);
        case .scroll_viewport_down_fast;        smooth_scroll(editor, direction = .down, fast = true);  activate_hold_action(action, event);
        case .scroll_viewport_left;             smooth_scroll(editor, direction = .left, fast = true);  activate_hold_action(action, event);
        case .scroll_viewport_right;            smooth_scroll(editor, direction = .right, fast = true); activate_hold_action(action, event);
        case .select_word;                      select_word(editor, buffer); keep_selection = true;
        case .select_word_or_create_another_cursor; enabled_whole_words = select_word_or_create_another_cursor(editor, buffer); keep_selection = true;
        case .select_all_occurrences;               enabled_whole_words = select_all_occurrences              (editor, buffer); keep_selection = true;

        case .toggle_line_wrap;                 toggle_line_wrap                    (editor);
        case .toggle_line_numbers;              toggle_line_numbers                 ();
        case .copy_current_line_info;           copy_current_line_info              (editor, buffer);
        case .center_viewport_on_cursor;        center_viewport_on_cursor           (editor, buffer);
        case .move_cursor_to_viewport_center;   move_cursor_to_viewport_center      (editor, buffer);
        case .remove_additional_cursors;        remove_additional_cursors           (editor);
        case .add_cursors_to_line_ends;         add_cursors_to_line_ends            (editor, buffer);
        case .add_cursors_to_line_starts;       add_cursors_to_line_starts          (editor, buffer);
        case .swap_selections;                  swap_selections                     (editor, buffer);           keep_selection = true;
        case .select_all;                       select_all                          (editor, buffer);           keep_selection = true;
        case .create_cursor_above;              create_cursor                       (editor, buffer, .above);   keep_selection = true;
        case .create_cursor_below;              create_cursor                       (editor, buffer, .below);   keep_selection = true;
        case .strip_trailing_whitespace;        strip_trailing_whitespace           (buffer, editor.buffer_id); keep_selection = true;

        case .choose_language;                  show_dialog                         (*language_dialog);

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
        case .jump_to_matching_bracket;         move_to_matching_bracket            (editor, buffer, shift_pressed); keep_selection = true;

        case .select_line;                      select_lines                        (editor, buffer); keep_selection = true;
        case .copy;                             copy_selection_to_clipboard         (editor, buffer);

        case;                                   handled = false;
    }

    if !handled {
        if buffer.readonly return false;

        if action == {
            case .indent_or_go_to_next_tabstop;     indent_or_tab                       (editor, buffer); keep_selection = true;
            case .indent;                           indent_lines                        (editor, buffer); keep_selection = true;
            case .unindent;                         unindent_lines                      (editor, buffer); keep_selection = true;
            case .autoindent_region;                autoindent_region                   (editor, buffer); keep_selection = true;

            case .toggle_comment;                   toggle_comment                      (editor, buffer); keep_selection = true;
            case .toggle_block_comment;             toggle_block_comment                (editor, buffer); keep_selection = true;

            case .break_line;                       break_line                          (editor, buffer);
            case .new_line_below_without_breaking;  new_line_below                      (editor, buffer);
            case .new_line_above_without_breaking;  new_line_above                      (editor, buffer);

            case .cut;                              copy_selection_to_clipboard         (editor, buffer, cut = true);
            case .paste;                            paste_from_clipboard                (editor, buffer);

            case .undo;                             undo                                (editor, buffer); keep_selection = true;
            case .redo;                             redo                                (editor, buffer); keep_selection = true;
            case .align_cursors;                    align_cursors                       (editor, buffer); keep_selection = true;

            case .delete_left_char;                 delete_left_char                    (editor, buffer);
            case .delete_right_char;                delete_right_char                   (editor, buffer);
            case .delete_word_left;                 delete_word_left                    (editor, buffer);
            case .delete_word_right;                delete_word_right                   (editor, buffer);
            case .delete_word_left_no_underscore;   delete_word_left                    (editor, buffer,, underscore_is_part_of_word = false);
            case .delete_word_right_no_underscore;  delete_word_right                   (editor, buffer,, underscore_is_part_of_word = false);

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
    }

    if new_group then new_edit_group(buffer, editor);  // do it after action

    if is_a_move_action(action) && shift_pressed then keep_selection = true;

    if editor.cursor_moved && !keep_selection {
        for * editor.cursors { it.sel = it.pos; }  // remove selection
    }

    // NOTE: even though we also do it in refresh_open_buffers, we do it here
    // so that if more than one event is processed in the same frame, the next one
    // sees the cursors in valid places and up to date
    if buffer.dirty {
        rescan_for_lines(buffer);
        if line_wrap_is_active(editor) then rescan_for_wrapped_lines(editor, buffer);
        if !is_empty(editor.search_bar.results) then search_and_update_results(editor, buffer, jump = false);
    }
    for * editor.cursors put_cursor_in_valid_spot(it, buffer);
    if editor.cursors.count > 1 then organise_cursors(editor);  // sort and maybe merge overlapping cursors

    if editor.cursor_moved != .has_not_moved {
        if !enabled_whole_words then editor.search_whole_words = false;
        editor.refresh_selection = true;  // update or remove highlights etc
        cursors_start_blinking();
    }

    return true;
}

active_editor_type_char :: (char: u32) {
    editor, buffer := get_active_editor_and_buffer();
    if !editor return;

    context.current_editor_id = editors.active;  // used for edit notifications
    defer context.current_editor_id = -1;

    if editor.search_bar.active {
        text_input_type_char(*editor.search_bar.input, char);
        search_and_update_results(editor, buffer, jump = true);
        editor.search_bar.scroll_to_selected = .snap;
        return;
    }

    if buffer.readonly return;

    utf8_char := convert_utf32_to_utf8(char);

    new_group := false;  // we always want to remember cursor state when a selection is replaced with anything
    for editor.cursors { if has_selection(it) { new_group = true; break; } }

    if new_group || (to_float64_seconds(frame_time) - buffer.last_edit_time) >= EDIT_GROUP_TIMEOUT {
        new_edit_group(buffer, editor);
    }

    if buffer.edits.count == 0 {
        // We want to remember where cursors were before we do any edits
        resize(*buffer.cursors, editor.cursors.count);
        for * cursor, i : buffer.cursors { cursor.* = editor.cursors[i]; }
    }

    offset_delta: s32 = 0;
    buf_len := cast(s32) buffer.bytes.count;

    should_surround_selection     := config.settings.auto_surround_with_brackets_and_quotes && all_cursors_have_selection(editor) && is_balanceable_char(char);
    should_insert_closing_bracket := config.settings.auto_close_brackets && all_cursors_can_auto_insert_closing_bracket(editor, buffer) && is_auto_closeable_char(char);

    for * cursor : editor.cursors {
        new_len := cast(s32) buffer.bytes.count;
        if new_len != buf_len {
            offset_delta += new_len - buf_len;
            buf_len = new_len;
        }
        cursor.pos += offset_delta;
        cursor.sel += offset_delta;

        if should_surround_selection {
            selection := get_selection(cursor);
            insert_char_at_offset(buffer, selection.end  , convert_utf32_to_utf8(get_balancing_char(char)));
            insert_char_at_offset(buffer, selection.start, utf8_char);

            cursor.pos = selection.end   + 1;
            cursor.sel = selection.start + 1;
        } else if should_insert_closing_bracket {
            insert_char_at_offset(buffer, cursor.pos, convert_utf32_to_utf8(get_balancing_char(char)));
            insert_char_at_offset(buffer, cursor.pos, utf8_char);

            cursor.pos = next_char_offset(buffer.bytes, cursor.pos);
            cursor.sel = cursor.pos;
        } else {
            if has_selection(cursor) {
                selection := get_selection(cursor);
                delete_range(buffer, selection);
                cursor.pos = selection.start;
            }
            insert_char_at_offset(buffer, cursor.pos, utf8_char);

            cursor.pos = next_char_offset(buffer.bytes, cursor.pos);
            cursor.sel = cursor.pos;
        }
    }

    if new_group then new_edit_group(buffer, editor);  // make sure selection operations have a dedicated group

    rescan_for_lines(buffer);
    if line_wrap_is_active(editor) then rescan_for_wrapped_lines(editor, buffer);

    if editor.cursors.count > 1 then organise_cursors(editor);
    for * cursor : editor.cursors  cursor.col_wanted = -1;

    buffer.last_edit_time = frame_time64;
    editor.cursor_moved = .unimportant;
    cursors_start_blinking();
    if !is_empty(editor.search_bar.results) then search_and_update_results(editor, buffer, jump = false);
}

get_active_editor_and_buffer :: () -> *Editor, *Buffer {
    if editors.layout == .None && !build_panel_is_active() return null, null;
    editor := *open_editors[editors.active];
    buffer := *open_buffers[editor.buffer_id];
    return editor, buffer;
}

refresh_all_editors_for_buffer :: (buffer_id: s64) {
    buffer := *open_buffers[buffer_id];

    for * editor, editor_id : open_editors {
        if editor.buffer_id != buffer_id continue;

        if editor.line_wrap == .on then rescan_for_wrapped_lines(editor, buffer);

        // Adjust cursors and viewport.
        // When edits are made in another editor for the same buffer, this editor's cursors
        // need to be adjusted. The viewport glue point also needs to move.
        for edit : buffer_edit_notifications {
            if edit.buffer_id != buffer_id continue;  // this is a notification for a different buffer
            if edit.editor_id == editor_id continue;  // this editor's cursors have already moved

            // Adjust viewport
            using editor.viewport.glue_point;
            if buffer_pos >= edit.offset then buffer_pos = max(buffer_pos + edit.delta, edit.offset);

            for * cursor : editor.cursors {
                if cursor.pos >= edit.offset then cursor.pos = max(cursor.pos + edit.delta, edit.offset);
                if cursor.sel >= edit.offset then cursor.sel = max(cursor.sel + edit.delta, edit.offset);
            }
        }
        for * cursor : editor.cursors { put_cursor_in_valid_spot(cursor, buffer); }
        if editor.cursors.count > 1 then organise_cursors(editor);

        editor.refresh_selection = true;
        if !is_empty(editor.search_bar.results) then search_and_update_results(editor, buffer);
    }

    // Clear applied notifications
    for buffer_edit_notifications {
        if it.buffer_id == buffer_id  remove it;
    }
}

editors_open_file :: (path: string, placement: Editor_Placement = .in_place) -> success: bool {
    full_path, success := get_absolute_path(path,, temp);
    path_overwrite_separators(full_path, separator = #char "/");
    if !file_exists(full_path) || !success {
        log_error("Couldn't open file %", path);
        add_user_error("Couldn't open file %", path, dismiss_in_seconds = 60);
        return false;
    }
    buffer_id := find_or_create_buffer(full_path);
    if buffer_id < 0 && full_path.count > 248 {
        log_error("Couldn't open file because path is too long for Windows: %\n", full_path);
        add_user_error("Couldn't open file. Path is too long.");  // not including full path for obvious reasons
        return false;
    }

    start_watching_file_if_not_already(full_path);

    editors_open_buffer(buffer_id, placement);
    return true;
}

editors_open_global_config :: (placement: Editor_Placement) {
    editors_open_file(global_config.path, placement);
}

editors_open_project_config :: (placement: Editor_Placement) {
    if project_config.loaded {
        editors_open_file(project_config.path, placement);
    } else {
        add_user_warning("No project is active. Please open a project first.", dismiss_in_seconds = 5);
    }
}

editors_show_default_config :: (placement: Editor_Placement) {
    if global_config_buffer_id < 0 {
        global_config_buffer_id = find_or_create_an_empty_buffer();
        buffer := *open_buffers[global_config_buffer_id];
        replace_range_raw(buffer, 0, xx buffer.bytes.count, DEFAULT_CONFIG_FILE_DATA);
        buffer.meow_hash = calculate_hash(to_view(buffer.bytes));
        buffer.readonly = true;
        buffer.internal = true;
        buffer.lang = .Focus_Config;
        buffer.file.name = "Default Focus Config";
        buffer.file.icon = .gear;
        rescan_for_lines(buffer);
    }

    editors_open_buffer(global_config_buffer_id, placement);
}

editors_show_troubleshooting_info :: (placement: Editor_Placement) {
    if global_troubleshooting_buffer_id < 0 {
        global_troubleshooting_buffer_id = find_or_create_an_empty_buffer();
        buffer := *open_buffers[global_troubleshooting_buffer_id];
        buffer.readonly = true;
        buffer.internal = true;
        buffer.lang = .Plain_Text;
        buffer.file.name = "Troubleshooting Info";
        buffer.file.icon = .debug;
        buffer.has_file = true;
    }

    buffer := *open_buffers[global_troubleshooting_buffer_id];
    replace_range_raw(buffer, 0, xx buffer.bytes.count, platform_get_troubleshooting_info());
    buffer.meow_hash = calculate_hash(to_view(buffer.bytes));
    rescan_for_lines(buffer);

    editors_open_buffer(global_troubleshooting_buffer_id, placement);
}

editors_create_new_file :: (placement: Editor_Placement = .in_place) {
    buffer_id := find_or_create_an_empty_buffer();

    editors_open_buffer(buffer_id, placement);
}

editors_open_buffer :: (buffer_id: s64, placement: Editor_Placement = .in_place) {
    if build_panel_is_active() then build_panel_lose_focus();

    if #complete editors.layout == {
        case .None;
            editors.active = find_or_create_editor(buffer_id);
            editors.left  = editors.active;  // we don't use it but editor history needs it
            editors.right = editors.active;
            editors.layout = .Single;

        case .Single;
            if placement == .in_place {
                // Open in place
                editors.left  = find_or_create_editor(buffer_id);
                editors.active = editors.left;
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

    make_editor_active(editors.active);
    maybe_mark_buffer_as_deleted(buffer_id);  // check in case we missed that it's deleted
    session_notify_modified_buffer(buffer_id);
    cursors_start_blinking();
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
    cursor.pos = coords_to_offset(editor, buffer, coords);
    cursor.sel = cursor.pos;
    editor.cursor_moved = .refresh_only;
}

go_to_line :: (editor: *Editor, buffer: Buffer, line: s64, col: s32 = -1) {
    line_num   := clamp(line - 1, 0, get_max_real_line_num(buffer));
    line_start := get_real_line_start_offset(buffer, cast(s32) line_num);
    line_end   := get_real_line_end_offset  (buffer, cast(s32) line_num);

    cursor := leave_only_original_cursor(editor);
    if col < 0 {
        cursor.pos = line_start + count_whitespace(buffer.bytes, line_start, line_end);
        cursor.sel = line_end;  // to make the line visible
    } else {
        cursor.pos = line_start + count_bytes_knowing_number_of_chars(buffer.bytes, line_start, line_end, col - 1);
        if cursor.pos > line_end then cursor.pos = line_end;
        cursor.sel = cursor.pos;
    }
    add_paste_animation(editors.active, .{ line_start, line_end});
    editor.cursor_moved = .jumped;
    editor.scroll_to_cursor = .yes;
}

leave_only_original_cursor :: (using editor: *Editor) -> *Cursor {
    // Remove all cursors except the original one
    cursor := cursors[min(original_cursor, cursors.count-1)];
    cursors.count = 1;
    original_cursor = 0;
    main_cursor = 0;
    cursors[0] = cursor;
    return *cursors[0];
}

leave_only_main_cursor :: (using editor: *Editor) -> *Cursor {
    // Remove all cursors except the main one
    cursor := cursors[min(main_cursor, cursors.count-1)];
    cursors.count = 1;
    original_cursor = 0;
    main_cursor = 0;
    cursors[0] = cursor;
    return *cursors[0];
}

organise_cursors :: (using editor: *Editor, selection_mode: *Selection_Mode = null) {
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

    quick_sort(to_view(cursors), compare_cursors);

    // Adjust main and original cursor indices because they could've moved
    for cursor, i : cursors {
        if cursor.pos == main_cursor_offset     then main_cursor = i;
        if cursor.pos == original_cursor_offset then original_cursor = i;
    }

    // Merge overlapping cursors
    i := 0;
    while (i < cursors.count - 1) {
        cursor      := *cursors[i];
        next_cursor := cursors[i+1];
        if maybe_subsume(cursor, next_cursor) {
            if selection_mode && (main_cursor == i || main_cursor == i+1) then selection_mode.min_range = get_selection(cursor);  // preserve the selection when dragging
            ordered_remove_by_index(*cursors, cast(s32)i+1);
            if main_cursor     > i then main_cursor -= 1;
            if original_cursor > i then original_cursor -= 1;
        } else {
            i += 1;
        }
    }
}

calculate_selected_text_length :: (using editor: *Editor, buffer: Buffer) {
    num_selected_bytes = 0;
    num_selected_chars = 0;

    for cursor : cursors {
        text := get_selected_string(cursor, buffer);
        num_selected_bytes += xx text.count;
        num_selected_chars += num_chars_in_string(text);
    }
}

get_max_line_num :: (editor: Editor, buffer: Buffer) -> s32 {
    assert(!buffer.dirty);
    return cast(s32) get_line_starts(editor, buffer).count - 2;
}

get_max_real_line_num :: inline (buffer: Buffer) -> s32 {
    return cast(s32) buffer.line_starts.count - 2;
}

get_max_y_scroll :: (editor: Editor, buffer: Buffer) -> s32 {
    assert(!buffer.dirty);
    return max(cast(s32) (get_max_line_num(editor, buffer)  * line_height), 0);
}

add_paste_animation :: (editor_id: s64, range: Offset_Range) {
    if !config.settings.show_paste_effect return;

    anim := array_add(*editor_paste_animations);
    anim.editor_id = editor_id;
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

all_cursors_have_selection ::  (using editor: Editor) -> bool {
    for cursors { if !has_selection(it) return false; }
    return true;
}

all_cursors_can_auto_insert_closing_bracket :: (using editor: Editor, buffer: Buffer) -> bool {
    for editor.cursors {
        if has_selection(it) return false;
        ch := get_char_at_offset(buffer, it.pos);

        if !is_whitespace_char(xx ch) && !(is_non_word_char(ch) && !is_auto_closeable_char(ch)) {
            return false;
        }
    }
    return true;
}

all_cursors_can_auto_delete_closing_bracket :: (using editor: Editor, buffer: Buffer) -> bool {
    closing: u32; // Make sure all cursors have the same type of closing bracket

    for editor.cursors {
        if it.pos - 1 < 0 || has_selection(it) return false;

        ch_prev := get_char_at_offset(buffer, it.pos - 1);
        ch_curr := get_char_at_offset(buffer, it.pos);

        if !is_auto_closeable_char(ch_prev) return false;

        if !closing then closing = get_balancing_char(ch_prev);

        if ch_curr != closing return false;
    }
    return true;
}

close_editor :: (position: enum { current; other; left; right; }) {
    using editors;
    if position == {
        case .current; close_current_editor();
        case .other;   close_other_editor();
        case .left;    if layout == .Double { if active == left  close_current_editor(); else if active == right close_other_editor(); }
        case .right;   if layout == .Double { if active == right close_current_editor(); else if active == left  close_other_editor(); }
    }
}

close_current_editor :: () {
    if build_panel_is_active() { toggle_build_panel(); return; }
    close_editor_by_id(editors.active);
}

close_other_editor :: () {
    if build_panel_is_active() return;  // what exactly do you want to close?

    if editors.layout == {
        case .None;     return;
        case .Single;   return;  // don't do anything
        case .Double;   close_editor_by_id(ifx editors.active == editors.left then editors.right else editors.left);
    }
}

close_editor_by_id :: (editor_id: s64, skip_animation := false) {
    if editors.layout == {
        case .None;
            do_things_on_editor_close(editor_id);

        case .Single;
            if editor_id == editors.active {
                editors.layout = .None;
                update_window_title();
            }
            do_things_on_editor_close(editor_id);

        case .Double;
            if editor_id == editors.left || editor_id == editors.right {
                editor_closing_id = editor_id;
                if !config.settings.disable_file_open_close_animations && !skip_animation {
                    // Start the animation (the layout will change when the animation is finished)
                    editors_start_moving_splitter(ifx editor_id == editors.left then 0.0 else 1.0);
                    make_editor_active(ifx editor_id == editors.left then editors.right else editors.left);
                } else {
                    make_editor_active(ifx editor_id == editors.left then editors.right else editors.left);
                    finish_closing_editor();
                }
            } else {
                do_things_on_editor_close(editor_id);
            }
    }
}

close_editors_for_buffer :: (buffer_id: s64) {
    should_skip_animation := false;
    if editors.layout == .Double {
        left_editor  := *open_editors[editors.left];
        right_editor := *open_editors[editors.right];
        should_skip_animation = left_editor.buffer_id == buffer_id && right_editor.buffer_id == buffer_id;
    }
    for editor, editor_id : open_editors {
        if editor.buffer_id == buffer_id then close_editor_by_id(editor_id, skip_animation = should_skip_animation);
    }
}

finish_closing_editor :: () {
    if editors.layout == .Double {
        editors.layout = .Single;
        editors.left  = editors.active;  // editor history needs it for comparison
        editors.right = editors.active;
    }
    do_things_on_editor_close(editor_closing_id);
    editor_closing_id = -1;
}

do_things_on_editor_close :: (editor_id: s64) {
    if editor_id < 0 return;
    editor := *open_editors[editor_id];
    buffer := *open_buffers[editor.buffer_id];

    buffer_is_still_visible := false;
    if #complete editors.layout == {
        case .None;
        case .Single; buffer_is_still_visible = open_editors[editors.active].buffer_id == editor.buffer_id;
        case .Double; buffer_is_still_visible = open_editors[editors.left].buffer_id == editor.buffer_id || open_editors[editors.right].buffer_id == editor.buffer_id;
    }
    if !buffer_is_still_visible {
        array_ordered_remove_by_value(*most_recent_buffers, editor.buffer_id);
        if !buffer.modified then buffer.num_times_opened = 0;  // deprioritise it in the full file list
        if !buffer.has_file { buffer.deleted = true; buffer.modified = false; }  // get rid of newly created buffers we're closing
    }
}

close_other_editors :: () {
    array_reset_keeping_memory(*most_recent_buffers);

    using editors;
    left_valid  := left  >= 0 && left  < open_editors.count;
    right_valid := right >= 0 && right < open_editors.count;
    if left_valid  then array_add_if_unique(*most_recent_buffers, open_editors[left].buffer_id);
    if right_valid then array_add_if_unique(*most_recent_buffers, open_editors[right].buffer_id);

    close_other_editor();
}

close_all_editors :: () {
    editors.layout = .None;
    array_reset_keeping_memory(*most_recent_buffers);
    update_window_title();
}

search_bar_is_open :: inline (using editor: *Editor) -> bool {
    return search_bar.active;  // used to be more stuff in here
}

open_search_bar :: (using editor: *Editor, buffer: Buffer, requested_mode: Search_Bar.Mode = .classic, remember_cursor_position := true) {
    using editor.search_bar;
    active = true;
    mode = requested_mode;
    case_sensitive_toggled_manually = false;  // forget when reopening

    // If there was some text selected that doesn't span more than one line, use it for search
    if cursors.count == 1 {
        cursor := cursors[0];
        selected_text := get_selected_string(cursor, buffer);
        if selected_text && offset_to_line(editor, buffer, cursor.pos) == offset_to_line(editor, buffer, cursor.sel) {
            replace_text(*input, selected_text);
        }
    }

    // Select text when opening
    input.cursor.sel = 0;
    input.cursor.pos = xx input.text.count;

    search_point_offset = get_selection(cursors[main_cursor]).start;

    if remember_cursor_position {
        original_cursor_position = cursors[main_cursor];
        jumped = false;
    }

    search_and_update_results(editor, buffer);
    scroll_y = 0;
    scroll_to_selected = .snap;
}

close_search_bar :: inline (editor: *Editor, jump_to_original_cursor := false, jump_to_selected_result := false) {
    using editor.search_bar;
    active = false;  // stop receiving input immediately

    if jump_to_original_cursor && jumped {
        cursor := leave_only_original_cursor(editor);
        cursor.* = original_cursor_position;
        editor.scroll_to_cursor = .yes;
    }

    if jump_to_selected_result && !is_empty(results) {
        cursor := leave_only_original_cursor(editor);
        cursor.sel = xx results[selected_result].offset;
        cursor.pos = xx (cursor.sel + results[selected_result].count);
        editor.scroll_to_cursor = .yes;
    }

    if !config.settings.persist_local_search_results {
        reset_search_results(*editor.search_bar);
        editor.refresh_selection = true;
    }
}

search_bar_toggle_expand :: (using editor: *Editor) {
    using search_bar;

    target_width := ifx width_percentage != WIDTH_EXPANDED then WIDTH_EXPANDED else WIDTH_NORMAL;
    start_animation(*width_anim, width_percentage, target_width);
}

search_bar_toggle_whole_word :: (using editor: *Editor, buffer: Buffer) {
    using search_bar;

    if !active return;
    whole_word = !whole_word;

    search_and_update_results(editor, buffer);
    redraw_requested = true;
}

search_bar_toggle_case_sensitive :: (using editor: *Editor, buffer: Buffer) {
    using search_bar;

    if !active return;
    case_sensitive = !case_sensitive;
    case_sensitive_toggled_manually = true;

    search_and_update_results(editor, buffer);
    redraw_requested = true;
}

search_bar_toggle_regex_search :: (using editor: *Editor, buffer: Buffer) {
    using search_bar;

    if !active return;
    regex_search = !regex_search;

    search_and_update_results(editor, buffer);
    redraw_requested = true;
}

search_bar_move_cursor :: (using editor: *Editor, buffer: Buffer, delta: s32, wrap := false, snap := true) {
    using search_bar;

    selected_result += delta;

    if wrap {
        if selected_result < 0 then selected_result = max(results.count - 1, 0);
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
    if results.count <= 0 {
        // Don't do anything because there aren't even any results to open
        // @Todo: should we deactivate it and move to the other open editor (as if it wasn't open)?
        return;
    }

    active = false;  // close it immediately

    result := results[selected_result];

    old_layout := editors.layout;
    editors_open_buffer(editor.buffer_id, placement);

    // Select the search result
    active_editor, active_buffer := get_active_editor_and_buffer();
    match_start := min(result.offset,                xx active_buffer.bytes.count);  // buffer could've changed, so offset may not be valid any more
    match_end   := min(result.offset + result.count, xx active_buffer.bytes.count);
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

    needle := to_string(search_bar.input.text);
    if !needle return;

    if config.settings.search_is_case_sensitive_when_uppercase_present && !search_bar.case_sensitive_toggled_manually {
        search_bar.case_sensitive = contains_uppercase_ascii(needle);
    }

    assert(buffer.bytes.count < S32_MAX && needle.count < S32_MAX);

    if search_bar.regex_search {
        find_all_using_regex(*search_bar, needle, buffer);
    } else {
        find_all(*search_bar, needle, buffer);
    }

    if search_bar.selected_result < 0 && search_bar.results.count > 0 then search_bar.selected_result = search_bar.results.count - 1;  // all results are before cursor, select the closest one
    if search_bar.selected_result >= 0 && jump then jump_to_search_result(editor, buffer);
}

free_editor :: (using editor: *Editor) {
    reset(*cursors);
    reset(*highlights);
    reset(*search_bar.results);
    reset(*wrapped_line_starts);
}

#scope_file

find_all_using_regex :: (using search_bar: *Search_Bar, needle: string, buffer: Buffer) {
    re_text := ifx whole_word then tprint("\\w%\\w", needle) else needle;
    flags := BASE_REGEX_FLAGS;
    if !case_sensitive then flags |= .FoldCase;

    regex: re.Regexp;
    regex, regex_is_valid = re.compile(re_text, flags);
    if !regex_is_valid return;
    defer re.uninit(*regex);

    buffer_str := to_string(buffer.bytes);

    while true {
        if buffer_str.count <= 0 break;

        matched, captures := re.match(buffer_str, regex,, allocator = temp);
        if !matched break;

        c := captures[0];
        offset := c.data - buffer.bytes.data;
        count  := c.count;
        if offset < 0 || offset >= buffer.bytes.count break;

        advance_amount := c.data - buffer_str.data + count;
        if advance_amount > 0 then advance(*buffer_str, advance_amount);

        if count == 0 || starts_with(buffer_str, #char "\n") then advance_to_next_line(*buffer_str);  // some matches could be of 0 length, which is valid, skip to the next line in this case, because otherwise we could have to look at every byte and that takes too long

        // Valid result, add it to the list
        if selected_result < 0 && offset >= search_point_offset then selected_result = results.count;

        result := add(*results);
        result.offset = cast(s32) offset;
        result.count  = cast(s32) count;
        result.line   = offset_to_real_line(buffer, offset);

        if results.count >= 5000 break;
    }
}

find_all :: (using search_bar: *Search_Bar, needle: string, buffer: Buffer) {
    buffer_str := to_string(buffer.bytes);

    offset := 0;
    skip_table := bmh_prepare_skip_table(needle, case_sensitive);

    while true {
        if case_sensitive {
            offset = inline bmh_find_index_from_left(buffer_str, needle, start_index = offset, skip_table, case_sensitive = true);
        } else {
            offset = inline bmh_find_index_from_left(buffer_str, needle, start_index = offset, skip_table, case_sensitive = false);
        }
        if offset < 0 break;
        if whole_word && !match_whole_word(buffer_str, offset, needle.count) { offset += needle.count; continue; }

        // Valid result, add it to the list
        if selected_result < 0 && offset >= search_point_offset then selected_result = results.count;

        result := add(*results);
        result.offset = cast(s32) offset;
        result.count  = cast(s32) needle.count;
        result.line   = offset_to_real_line(buffer, offset);

        offset += needle.count;
    }
}

#scope_export

jump_to_search_result :: (using editor: *Editor, buffer: Buffer, move_search_point := false) {
    using search_bar;
    if !results || selected_result < 0 return;

    result := results[selected_result];
    cursor := leave_only_original_cursor(editor);
    cursor.sel = xx result.offset;
    cursor.pos = xx (result.offset + result.count);
    scroll_to_cursor = .yes;

    if move_search_point {
        search_point_offset = xx result.offset;
    }

    jumped = true;

    cursors_start_blinking();
}

reset_search_results :: (using search_bar: *Search_Bar) {
    reset(*results);
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
        start_animation(*splitter_anim, splitter_pos, target);
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

    global_config_buffer_id = -1;
    global_troubleshooting_buffer_id = -1;
}

deinit_buffers :: () {
    for buffer_id, buffer_path : buffers_table {
        free(buffer_path);
    }
    deinit(*buffers_table);
}

get_lang_from_path :: (full_path: string) -> Buffer.Lang {
    lang: Buffer.Lang = .Plain_Text;

    path_, basename, extension, basename_with_extension := path_decomp(full_path);

    // Try to get lang from the user-provided mapping first
    for config.workspace.file_associations {
        if wildcard_match(basename_with_extension, it.wildcard) return it.lang;
    }

    // Get lang from the builtin mapping
    lowercase_extension := to_lower_copy_new(extension,, temp);
    if lowercase_extension == {
        case "jai";             lang = .Jai;
        case "cs";              lang = .CSharp;
        case "focus-config";    lang = .Focus_Config;
        case "focus-theme";     lang = .Focus_Theme;
        case "go";              lang = .Golang;
        case "lua";             lang = .Lua;
        case "odin";            lang = .Odin;
        case "py";              lang = .Python;
        case "rpy";             lang = .RenPy;
        case "rs";              lang = .Rust;
        case "json";            lang = .Json;
        case "yang";            lang = .Yang;
        case "zig";             lang = .Zig;
        case "tal";             lang = .Uxntal;
        case "md";              lang = .Markdown;
        case "bat";             lang = .Batch;
        case "cmd";             lang = .Batch;

        case "ts";              lang = .Js;
        case "tsx";             lang = .Js;
        case "jsx";             lang = .Js;
        case "js";              lang = .Js;

        case "vert";            lang = .Glsl;
        case "frag";            lang = .Glsl;
        case "geom";            lang = .Glsl;
        case "tese";            lang = .Glsl;
        case "tesc";            lang = .Glsl;
        case "glsl";            lang = .Glsl;
        case "comp";            lang = .Glsl;

        case "hlsl";            lang = .Hlsl;
        case "hlsli";           lang = .Hlsl;
        case "fx";              lang = .Hlsl;
        case "fxh";             lang = .Hlsl;

        case "c";               lang = .C;
        case "h";               lang = .C;
        case "inl";             lang = .Cpp;
        case "cpp";             lang = .Cpp;
        case "cxx";             lang = .Cpp;
        case "c++";             lang = .Cpp;
        case "hpp";             lang = .Cpp;
        case "ipp";             lang = .Cpp;
        case "cc";              lang = .Cpp;
        case "hh";              lang = .Cpp;
        case "m";               lang = .Cpp;
        case "mm";              lang = .Cpp;

        case "html";            lang = .Html;
        case "htm";             lang = .Html;
        case "xhtml";           lang = .Html;
        case "css";             lang = .Css;
        case "scss";            lang = .Css;

        case "xml";             lang = .Xml;
        case "xsd";             lang = .Xml;
        case "dtd";             lang = .Xml;
        case "xaml";            lang = .Xml;
        case "svg";             lang = .Xml;
        case "vcproj";          lang = .Xml;
        case "vcxproj";         lang = .Xml;
        case "csproj";          lang = .Xml;

        case;
            // Files named `.focus_config` are assumed to have no extension
            if equal_nocase(basename_with_extension, ".focus-config") then lang = .Focus_Config;
    }

    if equal_nocase(basename_with_extension, "FOCUS-CHANGELOG.txt") then lang = .Todo;

    return lang;
}

select_lines :: (editor: *Editor, buffer: Buffer) {
    for * cursor : editor.cursors select_line(cursor, buffer);
    editor.cursor_moved = .selection;
}

select_line :: (cursor: *Cursor, buffer: Buffer) {
    selection  := get_selection(cursor);
    start_line := offset_to_real_line(buffer, selection.start);
    end\ _line := ifx selection.start != selection.end then offset_to_real_line(buffer, selection.end) else start_line;
    cursor.sel = get_real_line_start_offset(buffer, start_line);
    cursor.pos = get_real_line_start_offset(buffer, end_line+1);
}

scan_through_similar_chars_on_the_left :: (using buffer: Buffer, offset: s32, char_type: Char_Type = .none, skip_one_space := true) -> offset: s32 {
    if !buffer.bytes return 0;

    line_start := bytes.data + line_starts[offset_to_real_line(buffer, offset)];
    char: u32;
    t := bytes.data + offset;
    t, char = unicode_prev_character(t);
    if char_type != .none && char_type != get_char_type(char) return offset;
    if skip_one_space && is_unicode_space(char) && t > line_start then t, char = unicode_prev_character(t);

    if get_char_type(char) == {
        case .space;
            while t > bytes.data && is_space_or_underscore(char)  { t, char = unicode_prev_character(t); }
            if !is_unicode_space(char) then t = unicode_next_character(t);
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
        case .space;    if !is_unicode_space(char) return offset;
    }
    if skip_one_space && is_unicode_space(char) && s then char = utf8_next_character(*s);

    if is_space_or_underscore(char) {
        // Only spaces
        while s && is_space_or_underscore(char)  { char = utf8_next_character(*s); }
        if !is_unicode_space(char) { s.data, char = unicode_prev_character(s.data); }
    } else if is_word_char(char) {
        // Only word chars
        while s && is_word_char(char) { char = utf8_next_character(*s); }
        if !is_word_char(char) { s.data, char = unicode_prev_character(s.data); }
    } else if !is_unicode_linebreak(char) {
        // Only non-word chars
        while s && is_non_word_char(char) { char = utf8_next_character(*s); }
        if !is_non_word_char(char) { s.data, char = unicode_prev_character(s.data); }
    }

    return min(bytes.count, cast(s32)(s.data - bytes.data));
}

cursors_start_blinking :: inline () {
    if config.settings.cursor_blink_time_in_seconds <= 0 return;

    cursor_blink_start = frame_time;
    platform_set_refresh_timer(window);
    cursors_blinking = true;
}

cursors_stop_blinking :: inline () {
    cursors_blinking = false;
    platform_kill_refresh_timer(window);
}

should_draw_cursors :: inline () -> bool {
    if !cursors_blinking || config.settings.cursor_blink_time_in_seconds <= 0 return true;

    ms_since_start := cast(s64) (to_float64_seconds(frame_time - cursor_blink_start) * 1000);
    if ms_since_start > config.settings.cursor_blink_time_in_seconds * 1000 {
        cursors_stop_blinking();
        return true;
    }
    return (ms_since_start / CURSOR_BLINK_SPEED_MS) % 2 == 0;
}

viewport_remember_glue_point :: (using editor: *Editor, buffer: Buffer) {
    viewport.glue_point.buffer_pos = get_line_start_offset(editor, buffer, viewport.top / cast(s32) line_height);
    viewport.glue_point.offset_within_line = viewport.top % cast(s32) line_height;
    redraw_requested = true;
}

snap_viewport_top_to_target :: (using editor: *Editor, buffer: Buffer, top_target: s32) {
    viewport.scroll_y.target = top_target;  // snap
    viewport.top = top_target;
    viewport_remember_glue_point(editor, buffer);
    redraw_requested = true;
}

snap_viewport_left_to_target :: (using editor: *Editor, left_target: s32) {
    viewport.scroll_x.target = left_target;
    viewport.left = left_target;
}

viewport_glue_to_point :: (editor: *Editor, buffer: Buffer) -> changed: bool {
    using editor.viewport;

    old_top := top;
    glue_point.buffer_pos = clamp(glue_point.buffer_pos, 0, cast(s32)max(0, buffer.bytes.count-1));
    line := offset_to_line(editor, buffer, glue_point.buffer_pos);
    top = line * cast(s32) line_height + glue_point.offset_within_line;
    scroll_y.target = top;
    return top != old_top;
}

make_editor_active :: (editor_id: s64) {
    assert(editor_id < open_editors.count, "Trying to activate editor %, but the last available one is %", editor_id, open_editors.count - 1);
    if is_build_panel(editor_id)         then build_panel_on_activate();

    editors.active = editor_id;

    buffer_id := open_editors[editor_id].buffer_id;
    update_window_title(buffer_id);

    array_ordered_remove_by_value(*most_recent_buffers, buffer_id);
    array_insert_at(*most_recent_buffers, buffer_id, 0);
}

update_window_title :: (buffer_id: s64 = -1) {
    title := window_generic_title;
    current_project_name := get_current_project_name();
    if project_config.loaded && current_project_name then title = tprint("% - %", current_project_name, title);
    if buffer_id >= 0 {
        buffer := open_buffers[buffer_id];
        if buffer.has_file {
            title = tprint("% • % • %", buffer.file.name, buffer.file.path, title);
        } else {
            buffer_name := get_buffer_name(buffer);
            if buffer_name then title = tprint("% • %", buffer_name, title);
        }
    }
    platform_set_window_title(title);
}

line_wrap_is_active :: inline (editor: Editor) -> bool {
    // Even if it's marked to disable, it's still active until the next frame
    return editor.line_wrap == .on || editor.line_wrap == .to_disable;
}

find_or_create_editor :: (buffer_id: s64, unwanted_existing_editor: s64 = -1) -> editor_id: s64, created: bool {
    assert(buffer_id >= 0 && buffer_id < open_buffers.count, "Attempt to create editor for nonexistent buffer");
    for open_editors {
        if it.buffer_id == buffer_id && it_index != unwanted_existing_editor
            return it_index, false;
    }

    editor_id := open_editors.count;
    editor := array_add(*open_editors);
    editor.buffer_id = buffer_id;
    add(*editor.cursors, Cursor.{});

    if config.settings.line_wrap_is_on_by_default {
        editor.line_wrap = .to_enable;
        redraw_requested = true;
    }

    open_buffers[buffer_id].num_editors_open += 1;
    assert(open_buffers[buffer_id].num_editors_open <= 2);

    return editor_id, true;
}

new_edit_group :: (buffer: *Buffer, editor: *Editor) {
    if buffer.edits.count == 0 return;

    new_group := add(*buffer.undos);
    new_group.edits = to_owned_array(*buffer.edits);  // @Speed: could group all char inserts into one if needed
    new_group.cursors_before = to_owned_array(*buffer.cursors);
    new_group.cursors_after  = to_view(copy(editor.cursors));

    // Remember cursor state
    resize(*buffer.cursors, editor.cursors.count);
    for * cursor, i : buffer.cursors { cursor.* = editor.cursors[i]; }
}

save_all :: () {
    unsaved_buffer_ids := get_unsaved_buffer_ids();
    for < unsaved_buffer_ids  save(it);
}

#scope_file

delete_cursor :: (using editor: *Editor, buffer: Buffer, where: enum { above; below; }) {
    organise_cursors(editor);
    if where == .above { // we shrink upwards
        main_cursor -= 1;
    } else { // we shrink downwards
        new_cursors: [] Cursor = to_view(cursors);
        new_cursors.data += 1;
        new_cursors.count -= 1;
        for new_cursors cursors[it_index] = it;
        original_cursor -= 1;
    }
    cursors.count -= 1;
    organise_cursors(editor);
    cursor_moved = .refresh_only;
}

create_cursor :: (using editor: *Editor, buffer: Buffer, where: enum { above; below; }) {
    organise_cursors(editor);

    if where == .above && original_cursor < main_cursor {
        // Should delete the bottom cursor instead
        assert(cursors.count > 1);
        cursors.count -= 1;
        main_cursor = clamp(main_cursor, 0, cursors.count - 1);
    } else if where == .below && main_cursor < original_cursor {
        // Should delete the top cursor instead
        assert(cursors.count > 1);
        ordered_remove_by_index(*cursors, 0);
        if main_cursor     > 0 then main_cursor -= 1;
        if original_cursor > 0 then original_cursor -= 1;
    } else {
        // Create cursor
        edge_cursor := ifx where == .above then cursors[0] else cursors[cursors.count-1];
        original    := cursors[original_cursor];
        original_pos_coords := offset_to_coords(editor, buffer, original.pos);
        original_sel_coords := offset_to_coords(editor, buffer, original.sel);

        add(*cursors, edge_cursor);
        cursor := *cursors[cursors.count-1];

        pos_coords := offset_to_coords(editor, buffer, cursor.pos);
        if where == .above then pos_coords.line -= 1; else pos_coords.line += 1;
        pos_coords.col = original_pos_coords.col;

        cursor.pos = coords_to_offset(editor, buffer, pos_coords);
        cursor.col_wanted = original_pos_coords.col;

        if has_selection(original) {
            sel_coords := pos_coords;
            sel_coords.line += original_sel_coords.line - original_pos_coords.line;
            sel_coords.col  += original_sel_coords.col  - original_pos_coords.col;
            cursor.sel = coords_to_offset(editor, buffer, sel_coords);
        } else {
            cursor.sel = cursor.pos;
        }
        main_cursor = cursors.count - 1;
    }

    organise_cursors(editor);

    cursor_moved = .refresh_only;
}

restore_cursor_state :: (using editor: *Editor, cursor_state: [] Cursor) {
    if cursor_state.count == 0 return;

    resize(*cursors, cursor_state.count);
    for * cursor, i : cursors {
        cursor.* = cursor_state[i];
        cursor.col_wanted = -1;
    }
    if main_cursor >= cursors.count then main_cursor = cursors.count - 1;  // maybe we should remember it too

    editor.cursor_moved = .jumped;
}

// @TODO: have another look at the code and at the very least avoid rescanning for each cursor.
// Also, check potential corner cases.
align_cursors :: (using editor: *Editor, buffer: *Buffer) {
    // Don't work if a cursor has a selection larger than one line
    for editor.cursors {
        pos_line := offset_to_real_line(buffer, it.pos);
        sel_line := offset_to_real_line(buffer, it.sel);
        if pos_line != sel_line return;
    }

    // Merge cursors if they are on the same line and set positions at the start of selections
    for * editor.cursors {
        line  := offset_to_real_line(buffer, it.pos);
        start := min(it.pos, it.sel);
        end   := max(it.pos, it.sel);

        for * other: editor.cursors {
            if it == other continue;
            other_line := offset_to_real_line(buffer, other.pos);
            if other_line != line continue;

            start = min(start, other.pos, other.sel);
            end   = max(end  , other.pos, other.sel);
        }

        it.pos = start;
        it.sel = end;
    }
    organise_cursors(editor);

    // Compute the values needed to align the cursors
    rightmost_col, largest_selection: s32;
    for editor.cursors {
        coords := get_real_cursor_coords(buffer, it);
        rightmost_col     = max(rightmost_col, min(coords.pos.col, coords.sel.col));
        largest_selection = max(largest_selection, abs(it.pos - it.sel));
    }

    offset_delta := 0;
    for * editor.cursors {
        it.pos += xx offset_delta;
        it.sel += xx offset_delta;
        it.col_wanted = -1;

        coords              := get_real_cursor_coords(buffer, it);
        selection_start_col := min(coords.pos.col, coords.sel.col);
        selection_size      := abs(it.pos - it.sel);

        // Compute the number of spaces and if we need to insert them before of after the cursor selection
        spaces_before, spaces_after: s32;
        if has_selection(it) {
            spaces_before = rightmost_col - selection_start_col;
            spaces_after  = ifx selection_size != largest_selection then largest_selection - selection_size;
        } else {
            spaces_before = rightmost_col - coords.pos.col + largest_selection;
        }
        str_before, str_after := get_tmp_spaces(spaces_before), get_tmp_spaces(spaces_after);

        insert_string_at_offset(buffer, max(it.pos, it.sel), str_after);
        insert_string_at_offset(buffer, min(it.pos, it.sel), str_before);

        // insert_string_at_offset() make the buffer dirty
        // we rescan to clean it else we can't call get_real_cursor_coords for the next cursors
        rescan_for_lines(buffer);
        if line_wrap_is_active(editor) then rescan_for_wrapped_lines(editor, buffer);

        // Keep selections aligned
        if it.pos < it.sel Swap(*it.pos, *it.sel); // Shouldn't be necessary since it's already reverted in the merge step
        it.pos += xx (str_before.count + str_after.count);
        it.sel = it.pos - largest_selection;
        offset_delta += str_before.count + str_after.count;
    }

    editor.cursor_moved = .large_edit;
}

select_word :: (editor: *Editor, buffer: Buffer) {
    editor.cursor_moved = .unimportant;
    for * editor.cursors {
        if has_selection(it) && editor.cursors.count > 1 continue;
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
        search_func = ifx search_whole_words && is_all_word_chars(selected_text) then find_index_from_left_whole_word else find_index_from_left;

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

        new_cursor := add(*cursors);
        new_cursor.sel = cast(s32) found_offset;
        new_cursor.pos = cast(s32) (found_offset + selected_text.count);

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

select_all_occurrences :: (using editor: *Editor, buffer: Buffer, search_str := "") -> whole_words: bool {
    editor.cursor_moved = .has_not_moved;

    // If main_cursor don't have selection check if it can select a word
    if !search_str && !has_selection(cursors[main_cursor]) {
        copy := cursors[main_cursor];
        select_word(buffer, *copy);
        text := get_selected_string(copy, buffer);

        // main_cursor can't select a word, do nothing
        if is_all_whitespace(text) return editor.search_whole_words;

        select_word(buffer, *cursors[main_cursor]);
        if is_all_word_chars(text) editor.search_whole_words = true;
    }

    // Remove all cursors except the main one
    leave_only_main_cursor(editor);

    // Begin search from the main cursor downwards with a wraparound
    buffer_str    := to_string(buffer.bytes);
    selected_text := ifx !search_str then get_selected_string(cursors[main_cursor], buffer) else search_str;
    search_func   := ifx !search_str && search_whole_words && is_all_word_chars(selected_text) then find_index_from_left_whole_word else find_index_from_left;
    initial       := get_selection(cursors[main_cursor]);
    offset        := cast(s64) initial.end;
    wrapped       := false;

    while true {
        offset = search_func(buffer_str, selected_text, offset);

        if offset == initial.start break;  // We found all occurrences in the file, exit loop

        if offset == -1 {
            // Maybe wrap around
            if !wrapped { offset = 0; wrapped = true; continue; } else break;
        }

        new_cursor := add(*cursors);
        new_cursor.sel = cast(s32) offset;
        new_cursor.pos = cast(s32) (offset + selected_text.count);

        MAX_CURSORS :: 5000; // @Todo Make it a setting ?
        if cursors.count >= MAX_CURSORS {
            add_user_warning("The maximum number of occurrences to be selected at once has been limited to %.", MAX_CURSORS);
            break;
        }

        offset += selected_text.count;
    }

    organise_cursors(editor);
    cursors_start_blinking();

    return editor.search_whole_words;
}

save :: (editor: Editor, editor_id: s64) {
    buffer_id := editor.buffer_id;

    // When hitting save while in the color preview panel, save the target config file instead
    if is_color_preview_panel(editor_id) then buffer_id = color_preview_get_target_buffer_id();

    save(buffer_id);
}

save :: (buffer_id: s64) {
    buffer := *open_buffers[buffer_id];
    if buffer.readonly || buffer.internal return;

    if buffer.has_file {
        save_buffer(buffer, buffer_id);
    } else {
        defer_action_save_as(buffer_id);
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
            if side == {
                case .left;  if editors.active == editors.left  then return;
                case .right; if editors.active == editors.right then return;
                case .other; if editors.active == editors.left  then side = .right; else side = .left;
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

    make_editor_active(editors.active);
    cursors_start_blinking();
}

duplicate_active_editor :: () -> s64 {
    current_editor       := *open_editors[editors.active];
    duplicated_editor_id := find_or_create_editor(current_editor.buffer_id, editors.active);
    duplicated_editor    := *open_editors[duplicated_editor_id];

    // Duplicate cursors
    if !is_empty(duplicated_editor.cursors) then reset(*duplicated_editor.cursors);
    for current_editor.cursors { add(*duplicated_editor.cursors, it); }
    duplicated_editor.main_cursor     = current_editor.main_cursor;
    duplicated_editor.original_cursor = current_editor.original_cursor;

    // Move viewport
    duplicated_editor.viewport.scroll_x = current_editor.viewport.scroll_x;
    duplicated_editor.viewport.scroll_y = current_editor.viewport.scroll_y;

    return duplicated_editor_id;
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
    if build_panel_is_active() {
        toggle_build_panel_height();
    } else {
        toggle_editor_expand(!editors.expanded);
    }
}

toggle_editor_expand :: (expanded: bool) {
    if editors.layout != .Double return;

    editors.expanded = expanded;
    if editors.expanded {
        editors_start_moving_splitter(ifx editors.active == editors.left then 0.9 else 0.1);
    } else {
        editors_start_moving_splitter(0.5);  // back to center
    }
}

smooth_scroll :: (editor: Editor, direction: Smooth_Scroll_Direction, fast := false) {
    // Only set this if there's a new set of inputs. Since keystrokes will repeat if held down for long,
    // the start_*/started_at values would be reset constantly in the middle of scrolling, causing stutter.
    if direction != editor_smooth_scroll.direction || fast != editor_smooth_scroll.fast {
        editor_smooth_scroll.direction  = direction;
        editor_smooth_scroll.started_at = frame_time;
        editor_smooth_scroll.start_x    = editor.viewport.left;
        editor_smooth_scroll.start_y    = editor.viewport.top;
        editor_smooth_scroll.fast       = fast;
    }
}

cursors_match :: (c1: Array(Cursor), c2: [] Cursor) -> bool {
    if c1.count != c2.count return false;

    for 0 .. c1.count-1 {
        if c1[it].pos != c2[it].pos return false;  // we don't compare sel on purpose, to avoid jumping between selections too much
    }

    return true;
}

undo :: (editor: *Editor, buffer: *Buffer) {
    new_edit_group(buffer, editor);
    if buffer.undos.count == 0 return;

    edit_group := peek(buffer.undos);

    // Maybe put cursors in the position right before the undo edits, unless they are already there
    if !cursors_match(editor.cursors, edit_group.cursors_after) {
        restore_cursor_state(editor, edit_group.cursors_after);
        return;  // let people hit undo again to see the changes for more visual feedback
    }

    // Revert edits in the backwards order
    for < e : edit_group.edits {
        if #complete e.type == {
            case .delete;      using e.delete;       insert_string_raw(buffer, offset_range.start, old_bytes);
            case .replace;     using e.replace;      replace_range_raw(buffer, offset_range.start, offset_range.start + xx new_bytes.count, old_bytes);
            case .insert;      using e.insert;       delete_range_raw (buffer, offset, offset + cast(s32) new_bytes.count);
            case .insert_char; using e.insert_char;  delete_range_raw (buffer, offset, offset + cast(s32)char.count);
        }
    }

    pop(*buffer.undos);
    add(*buffer.redos, edit_group);  // push onto the redo stack
    restore_cursor_state(editor, edit_group.cursors_before);

    editor.cursor_moved = .large_edit;
}

redo :: (editor: *Editor, buffer: *Buffer) {
    if buffer.redos.count == 0 return;

    edit_group := peek(buffer.redos);

    // Maybe put cursors in the position right before the redo edits, unless they are already there
    if !cursors_match(editor.cursors, edit_group.cursors_before) {
        restore_cursor_state(editor, edit_group.cursors_before);
        return;  // let people hit undo again to see the changes for more visual feedback
    }

    // Replay edits in the normal order
    for e : edit_group.edits {
        if #complete e.type == {
            case .delete;      using e.delete;      delete_range_raw (buffer, offset_range.start, offset_range.end);
            case .replace;     using e.replace;     replace_range_raw(buffer, offset_range.start, offset_range.end, new_bytes);
            case .insert;      using e.insert;      insert_string_raw(buffer, offset, new_bytes);
            case .insert_char; using e.insert_char; insert_string_raw(buffer, offset, to_string(*char));
        }
    }

    pop(*buffer.redos);
    add(*buffer.undos, edit_group);  // push onto the undo stack
    restore_cursor_state(editor, edit_group.cursors_after);

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
        case .toggle_block_comment;             return true;
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
                    cursor.pos = scan_through_similar_chars_on_the_left(buffer, cursor.pos, skip_one_space = skip_one_space,, underscore_is_part_of_word = false);
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
                    cursor.pos = scan_through_similar_chars_on_the_right(buffer, cursor.pos, skip_one_space = skip_one_space,, underscore_is_part_of_word = false);
                case .word_ends;
                    char := get_char_at_offset(buffer, cursor.pos);
                    char_type := get_char_type(char);
                    if char_type != .word  then cursor.pos = scan_through_similar_chars_on_the_right(buffer, cursor.pos, char_type, skip_one_space = false);
                    char_type = get_char_type(get_char_at_offset(buffer, cursor.pos));
                    if char_type != .other && !is_unicode_linebreak(char) then cursor.pos = scan_through_similar_chars_on_the_right(buffer, cursor.pos, skip_one_space = skip_one_space);
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
                coords := offset_to_coords(editor, buffer, cursor.pos);
                cursor.col_wanted = coords.col;
            }
        }
        coords := offset_to_coords(editor, buffer, cursor.pos);
        coords.line += delta;
        if cursor.col_wanted < 0 then cursor.col_wanted = coords.col;
        coords.col = cursor.col_wanted;
        cursor.pos = coords_to_offset(editor, buffer, coords);
    }

    if delta < 0  editor.cursor_moved = .moved_up;
    else          editor.cursor_moved = .moved_down;
}

move_cursors_to_empty_line :: (editor: *Editor, buffer: Buffer, dir: enum { up; down; }) {
    for * cursor : editor.cursors {
        line := offset_to_real_line(buffer, cursor.pos);
        if dir == .up {
            while line > 0 {
                line -= 1;
                if is_empty(buffer, line) break;
            }
        } else {
            max_line := get_max_real_line_num(buffer);
            while line < max_line {
                line += 1;
                if is_empty(buffer, line) break;
            }
        }
        cursor.pos = real_coords_to_offset(buffer, Coords.{ line = line, col = cursor.col_wanted });
    }

    if dir == .up  editor.cursor_moved = .moved_up;
    else           editor.cursor_moved = .moved_down;
}

move_cursors_by_page :: (editor: *Editor, buffer: Buffer, dir: enum { up; down; }) {
    page_size := cast(s32) (window_height / line_height);

    for * cursor : editor.cursors {
        line := offset_to_line(editor, buffer, cursor.pos);
        if dir == .up {
            line -= page_size;
        } else {
            line += page_size;
        }
        cursor.pos = coords_to_offset(editor, buffer, Coords.{ line = line, col = cursor.col_wanted });
    }

    if dir == .up  editor.cursor_moved = .moved_up;
    else           editor.cursor_moved = .moved_down;
}

move_cursors_home :: (editor: *Editor, buffer: Buffer) {
    for * cursor : editor.cursors {
        line := offset_to_real_line(buffer, cursor.pos);
        start, end := get_real_line_start_offset(buffer, line), get_real_line_end_offset(buffer, line);

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
        line := offset_to_real_line(buffer, cursor.pos);
        cursor.pos = get_real_line_end_offset(buffer, line);
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

move_to_matching_bracket :: (using editor: *Editor, buffer: Buffer, keep_selection: bool) {
    for * cursor : cursors {
        pos: s32 = -1;
        if is_bracket(buffer, cursor.pos) {
            pos = cursor.pos;
        } else if is_bracket(buffer, cursor.pos - 1) {
            pos = cursor.pos - 1;
        }
        if pos < 0 continue;

        offset := find_matching_bracket(buffer, pos);
        if offset < 0 continue;

        if keep_selection then cursor.sel = cursor.pos;
        cursor.pos = offset;
        if !keep_selection then cursor.sel = offset;
    }

    editor.cursor_moved = .jumped;
}

break_line :: (editor: *Editor, buffer: *Buffer) {
    new_edit_group(buffer, editor);

    // Remember by how much we need to indent the new lines upfront to avoid any scanning of the dirty buffer later
    Space :: struct { start: s32; count: s32; original_start: s32; }  // not a string to avoid invalid pointers
    space_per_cursor := NewArray(editor.cursors.count, Space, initialized = false,, allocator = temp);
    for cursor : editor.cursors {
        selection := get_selection(cursor);
        start := get_real_line_start_offset(buffer, offset_to_real_line(buffer, selection.start));
        whitespace_bytes := count_whitespace(buffer.bytes, start, selection.start);
        space_per_cursor[it_index] = .{ start = start, count = whitespace_bytes, original_start = start };
    }

    offset_delta := 0;
    for * cursor : editor.cursors {
        space := *space_per_cursor[it_index];
        prev_space := space_per_cursor[max(it_index-1, 0)];
        if space.original_start == prev_space.original_start then space.start = prev_space.start; else space.start += xx offset_delta;  // handle cursors on the same line well
        space_str := cast(string) to_view(buffer.bytes, space.start, space.count);
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
    new_edit_group(buffer, editor);

    Line_Info :: struct { end: s32; space: struct { start, count, original_start: s32; }; last_line: bool; };
    line_info_per_cursor := NewArray(editor.cursors.count, Line_Info, initialized = false,, allocator = temp);
    for cursor : editor.cursors {
        selection := get_selection(cursor);
        last_line := offset_to_real_line(buffer, selection.end);
        start := get_real_line_start_offset(buffer, last_line);
        end   := get_real_line_start_offset(buffer, last_line+1);
        whitespace_bytes := count_whitespace(buffer.bytes, start, end);
        line_info_per_cursor[it_index] = .{ end = end, space = .{ start = start, count = whitespace_bytes, original_start = start }, last_line = is_last_real_line(buffer, last_line) };
    }

    offset_delta := 0;
    for * cursor : editor.cursors {
        line_info := *line_info_per_cursor[it_index];
        prev_line_info := line_info_per_cursor[max(it_index-1, 0)];
        if line_info.space.original_start == prev_line_info.space.original_start then line_info.space.start = prev_line_info.space.start; else line_info.space.start += xx offset_delta;  // handle cursors on the same line well
        line_info.end += xx offset_delta;
        whitespace_str := cast(string) to_view(buffer.bytes, line_info.space.start, line_info.space.count);  // construct string from offsets to avoid memory errors on buffer reallocation
        insert_str := ifx line_info.last_line then tprint("\n%\n", whitespace_str) else tprint("%\n", whitespace_str);

        insert_string_at_offset(buffer, line_info.end, insert_str);

        offset_delta += insert_str.count;
        cursor.pos = line_info.end + xx insert_str.count - 1;
        cursor.col_wanted = -1;
    }

    editor.cursor_moved = .unimportant;
}

new_line_above :: (editor: *Editor, buffer: *Buffer) {
    new_edit_group(buffer, editor);

    Line_Info :: struct { start: s32; space: struct { start, count, original_start: s32; }; };
    line_info_per_cursor := NewArray(editor.cursors.count, Line_Info, initialized = false,, allocator = temp);
    for cursor : editor.cursors {
        selection  := get_selection(cursor);
        first_line := offset_to_real_line(buffer, selection.start);
        start := get_real_line_start_offset(buffer, first_line);
        end   := get_real_line_start_offset(buffer, first_line+1);
        whitespace_bytes := count_whitespace(buffer.bytes, start, end);
        line_info_per_cursor[it_index] = .{ start = start, space = .{ start = start, count = whitespace_bytes, original_start = start } };
    }

    offset_delta := 0;
    for * cursor : editor.cursors {
        line_info := *line_info_per_cursor[it_index];
        prev_line_info := line_info_per_cursor[max(it_index-1, 0)];
        if line_info.space.original_start == prev_line_info.space.original_start then line_info.space.start = prev_line_info.space.start; else line_info.space.start += xx offset_delta;  // handle cursors on the same line well
        line_info.start += xx offset_delta;
        whitespace_str := cast(string) to_view(buffer.bytes, line_info.space.start, line_info.space.count);  // construct string from offsets to avoid memory errors on buffer reallocation
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

delete_left_char :: (editor: *Editor, buffer: *Buffer) {
    should_delete_closing_bracket := config.settings.auto_close_brackets && all_cursors_can_auto_delete_closing_bracket(editor, buffer);

    // NOTE: we don't have to worry about a cursor with no selection being immediately next
    //       to the non-cursor end of another cursor's selection (thanks to organise_cursors),
    //       so it should be safe to delete at least one character to the left of every cursor if there is one
    range_per_cursor := NewArray(editor.cursors.count, Offset_Range, initialized = false,, allocator = temp);
    for cursor : editor.cursors {
        if should_delete_closing_bracket {
            range_per_cursor[it_index] = .{ start = cursor.pos - 1, end = cursor.pos + 1 };
        } else if has_selection(cursor) {
            range_per_cursor[it_index] = get_selection(cursor);
        } else if cursor.pos == 0 {
            range_per_cursor[it_index] = Offset_Range.{};
        } else {
            coords := offset_to_real_coords(buffer, cursor.pos);
            chars_to_delete := coords.col % TAB_SIZE;
            if coords.col == 0      then chars_to_delete = 1;
            if chars_to_delete == 0 then chars_to_delete = TAB_SIZE;
            if chars_to_delete > 1 {
                // Don't delete more than one char unless the cursor is between line start and text start
                whitespace_bytes := count_whitespace(buffer.bytes, get_real_line_start_offset(buffer, coords.line), cursor.pos);
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
        cursor.sel = range.start;
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
            buf_len = new_len;
        }
        cursor.pos += offset_delta;
        cursor.sel += offset_delta;

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

get_line_starts_for_lines_with_cursors_tmp :: (editor: *Editor, buffer: *Buffer) -> [..] s32 /* tmp */, last_line_end_offset: s32 {
    line_starts: [..] s32;
    line_starts.allocator = temp;

    last_added := -1;
    last_line_end_offset: s32 = 0;
    for cursor : editor.cursors {
        selection := get_selection(cursor);
        start_line := offset_to_real_line(buffer, selection.start);
        end_line   := ifx selection.start != selection.end then offset_to_real_line(buffer, selection.end) else start_line;
        selection_end_col := offset_to_real_coords(buffer, selection.end).col;
        if selection_end_col == 0 then end_line = max(start_line, end_line - 1);  // don't include the last line if the cursor is at the very beginning of it
        for start_line..end_line {
            line_start := get_real_line_start_offset(buffer, it);
            if last_added < line_start { array_add(*line_starts, line_start); last_added = line_start; }
        }
        last_line_end_offset = get_real_line_start_offset(buffer, end_line+1);
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
        for line_start : line_starts {
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
        append(*b, cast(string) to_view(buffer.bytes, start, end-start));
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
        spaces_at_line_start: s32 = 0;
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
        append(*b, cast(string) to_view(buffer.bytes, new_start, end-new_start));
        spaces_removed += spaces_at_line_start;
    }
    new_str := builder_to_string(*b);
    defer free(new_str);

    range := Offset_Range.{ start = xx line_starts[0], end = xx last_line_end_offset };
    replace_range(buffer, range, new_str);

    for * cursor : editor.cursors { cursor.col_wanted = -1; }

    editor.cursor_moved = .unimportant;
}

autoindent_region :: (editor: *Editor, buffer: *Buffer) {
    // We assume that any {, [ or ( left unclosed means that the next line should be indented.
    // This is not true for Python, for example, we might handle other cases later

    // We tokenize on demand here rather than storing tokens when highlighting to save space (they are needed very rarely).
    // This will also help us find the line to base the indentation of subsequent lines off of, as lines containing things
    // such as multiline comments or here-strings can not be used as a base.
    tokens := tokenize_for_indentation(buffer);

    if !tokens {
        add_user_warning("Autoindenting is not supported for % files", buffer.lang, dismiss_in_seconds = 3);
        return;
    }

    line_ranges := get_whole_line_ranges_for_cursors(editor, buffer);

    replacements: [..] string;
    replacements.allocator = temp;

    for * line_range : line_ranges {
        // Determine the base indentation level by looking backwards at the first nonempty line
        base_level: int;
        {
            token, token_id := find_closest_indentation_token(tokens, line_range.start);
            line_num        := offset_to_real_line(buffer, token.start);
            line_start      := get_real_line_start_offset(buffer, line_num);

            while line_num > 0 && token_id > 0 {
                token = find_closest_indentation_token(tokens, line_start);
                if token.type != .maybe_multiline || (token.start + token.len) <= line_start break;
                line_num   = offset_to_real_line(buffer, token.start);
                line_start = get_real_line_start_offset(buffer, line_num);
            }

            level, next_level := get_base_indent_from_line(buffer, line_num, tokens);
            if line_range.start != line_start {
                base_level = next_level;  // derived the level from a line above, not the first line of the range
            } else {
                base_level = level;
            }

            // #if DEBUG {
            //     print("BASE LINE FOR INDENT:\n%\n", get_real_line_as_string(buffer, line_num));
            //     print("base_level: %, next_level: %\n", level, next_level);
            // }
        }

        // Build a replacement string for the whole range.
        replacement: string;
        {
            b: String_Builder;
            b.allocator = temp;

            range_str := get_range_as_string(buffer, line_range.range);
            if ends_with(range_str, "\n") then range_str.count -= 1;
            lines_in_range := split(range_str, cast(u8) #char "\n",, allocator = temp);

            level := base_level;
            start, end: s32;
            current_delta, next_delta: int;

            for line, i : lines_in_range {
                if line {
                    // Check the line's tokens to see if we need to change the indentation level
                    start = cast(s32) (line.data - buffer.bytes.data);
                    end   = cast(s32) (start + line.count);
                    current_delta, next_delta = get_indentation_changes_from_tokens_within_range(tokens, start, end);
                    level = max(0, level + current_delta);
                } else {
                    start = end + 1;  // can't use pointer arithmetic here
                    next_delta = 0;
                }

                if !offset_is_within_multiline_token(tokens, start) {
                    // Indent the line
                    whitespace := ifx config.settings.insert_spaces_when_pressing_tab then get_tmp_spaces(level * TAB_SIZE) else get_tmp_tabs(level);
                    append(*b, whitespace);
                    append(*b, trim(line));
                    append(*b, "\n");
                } else {
                    // Don't indent
                    append(*b, line);
                    append(*b, "\n");
                }

                level = max(0, level + next_delta);
            }

            replacement = builder_to_string(*b,, allocator = temp);
        }

        array_add(*replacements, replacement);
    }

    assert(line_ranges.count == replacements.count);

    offset_delta := 0;

    for * line, i : line_ranges {
        line.range.start += xx offset_delta;
        line.range.end   += xx offset_delta;

        new_str := replacements[i];
        replace_range(buffer, line.range, new_str);

        delta := cast(s32) (new_str.count - (line.range.end - line.range.start));
        offset_delta += delta;

        for * cursor : editor.cursors {
            // TODO: handle the case when the cursor is within the range
            if cursor.pos >= line.start then cursor.pos = max(cursor.pos + delta, line.start);
            if cursor.sel >= line.start then cursor.sel = max(cursor.sel + delta, line.start);
        }
    }

    editor.cursor_moved = .unimportant;
}

remove_additional_cursors :: (editor: *Editor) {
    cursor := leave_only_original_cursor(editor);
    cursor.sel = cursor.pos;
    editor.cursor_moved = .refresh_only;
}

add_cursors_to_line_starts :: (using editor: *Editor, buffer: Buffer) {
    if buffer.bytes.count <= 0 return;

    line_ranges := get_whole_line_ranges_for_cursors(editor, buffer);
    reset_keeping_memory(*cursors);  // reset after getting ranges (obviously)

    pos: s32;

    for * line_range : line_ranges {
        line_num := offset_to_line(editor, buffer, line_range.start);
        while true {
            pos = buffer.line_starts[line_num];
            if pos >= line_range.end break;
            add(*cursors, Cursor.{ pos = pos, sel = pos, col_wanted = -1 });
            line_num += 1;
        }
    }

    if !cursors then add(*cursors, Cursor.{ pos = pos, sel = pos, col_wanted = -1 });

    main_cursor     = clamp(main_cursor,     0, cursors.count - 1);
    original_cursor = clamp(original_cursor, 0, cursors.count - 1);

    editor.cursor_moved = .unimportant;
}

add_cursors_to_line_ends :: (editor: *Editor, buffer: Buffer) {
    add_cursors_to_line_starts(editor, buffer);
    move_cursors_end(editor, buffer);
}

swap_selections :: (using editor: *Editor, buffer: *Buffer) {
    if cursors.count != 2 return;

    c1, c2 := *cursors[0], *cursors[1];

    string0     := copy_temporary_string(get_selected_string(c1, buffer));
    string1     := copy_temporary_string(get_selected_string(c2, buffer));

    string_dif  := string0.count - string1.count;

    selection0  := get_selection(c1);
    selection1  := get_selection(c2);

    pos_offset0 := selection0.start - c1.pos;
    sel_offset0 := selection0.start - c1.sel;

    pos_offset1 := selection1.start - c2.pos;
    sel_offset1 := selection1.start - c2.sel;

    replace_range(buffer, selection1, string0);
    replace_range(buffer, selection0, string1);

    c1.pos = selection0.start - pos_offset1;
    c1.sel = selection0.start - sel_offset1;

    c2.pos = selection1.start - pos_offset0 - xx string_dif;
    c2.sel = selection1.start - sel_offset0 - xx string_dif;
}

select_all :: (editor: *Editor, buffer: Buffer) {
    cursor := leave_only_original_cursor(editor);
    cursor.sel = 0;
    cursor.pos = cast(s32) buffer.bytes.count;
    editor.refresh_selection = true;
}

Line_Range :: struct {
    using range: Offset_Range;
    prev_line_start: s32;
    next_line_end: s32;
    is_last: bool;
    next_line_is_last: bool;
};

get_whole_line_ranges_for_cursors :: (editor: Editor, buffer: Buffer, merge_adjacent := true, select_next_for_single_lines := false) -> [] Line_Range /* tmp */ {
    line_ranges: [..] Line_Range;
    line_ranges.allocator = temp;
    {
        last_end_line := -1;
        for cursor : editor.cursors {
            selection := get_selection(cursor);
            start_line := offset_to_real_line(buffer, selection.start);
            end_line   := ifx selection.start != selection.end then offset_to_real_line(buffer, selection.end) else start_line;
            if start_line == end_line && select_next_for_single_lines then end_line += 1;

            next_line_end := get_real_line_start_offset(buffer, end_line+2);

            should_extend := line_ranges.count > 0 && (
                (merge_adjacent  && start_line <= last_end_line+1) ||
                (!merge_adjacent && start_line <= last_end_line)
            );

            if should_extend {
                // Extend last line range
                line_ranges[line_ranges.count-1].range.end         = get_real_line_start_offset(buffer, end_line+1);
                line_ranges[line_ranges.count-1].next_line_end     = next_line_end;
                line_ranges[line_ranges.count-1].is_last           = is_last_real_line(buffer, end_line);
                line_ranges[line_ranges.count-1].next_line_is_last = !is_last_real_line(buffer, end_line) && is_last_real_line(buffer, end_line + 1);
            } else {
                // Add a new line range
                array_add(*line_ranges, Line_Range.{
                    prev_line_start   = get_real_line_start_offset(buffer, start_line-1),
                    next_line_end     = next_line_end,
                    range             = .{ start = get_real_line_start_offset(buffer, start_line), end = get_real_line_start_offset(buffer, end_line+1) },
                    is_last           = is_last_real_line(buffer, end_line),
                    next_line_is_last = !is_last_real_line(buffer, end_line) && is_last_real_line(buffer, end_line + 1),
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
        if line.is_last then str = tprint("\n%", str);  // make sure duplication works correctly on the last line of the buffer
        insert_string_at_offset(buffer, line.range.end, str);
        add_paste_animation(editors.active, .{ start = line.range.end, end = line.range.end + cast(s32)str.count });

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
        if line.prev_line_start == line.range.start then continue;  // we're at the top
        prev_line_range := Offset_Range.{ start = line.prev_line_start, end = line.range.start };
        view     := get_range_as_string(buffer, prev_line_range);
        prev_str := ifx line.is_last then tprint("\n%", view) else copy_temporary_string(view);
        length   := cast(s32) view.count;  // this length should *not* include the optional newline character

        delete_range(buffer, prev_line_range);
        insert_string_at_offset(buffer, line.range.end - length, prev_str);

        for * cursor : editor.cursors {
            if line.range.start <= cursor.pos && cursor.pos <= line.range.end {  // no need to check for cursor.sel because we have whole line ranges
                cursor.pos -= xx length;
                cursor.sel -= xx length;
            }
        }
    }

    editor.cursor_moved = .moved_up_with_edit;
}

move_lines_down :: (editor: *Editor, buffer: *Buffer) {
    lines := get_whole_line_ranges_for_cursors(editor, buffer);

    for line : lines {
        if line.next_line_end == line.range.end then continue;  // we're at the bottom
        next_line_range := Offset_Range.{ start = line.range.end, end = line.next_line_end };
        view     := get_range_as_string(buffer, next_line_range);
        next_str := ifx line.next_line_is_last then tprint("%\n", view) else copy_temporary_string(view);
        length   := next_str.count;  // contrary to move_lines_up, this length *must* include the optional newline character

        delete_range(buffer, next_line_range);
        insert_string_at_offset(buffer, line.range.start, next_str);

        for * cursor : editor.cursors {
            if line.range.start <= cursor.pos && cursor.pos <= line.range.end {  // no need to check for cursor.sel because we have whole line ranges
                cursor.pos += xx length;
                cursor.sel += xx length;
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
        range.start += xx offset_delta;
        range.end   += xx offset_delta;

        range_str := get_range_as_string(buffer, range.range);
        individual_lines := split(trim_right(range_str, " \t"), cast(u8) #char "\n",, allocator = temp);
        if individual_lines.count <= 1 continue;  // nothing to join

        first_line         := individual_lines[0];
        first_line_trimmed := trim_right(first_line, " \t");
        remaining_lines    := array_view(individual_lines, 1, individual_lines.count - 1);

        delete_offset := range.start + first_line_trimmed.count;
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

        new_str := builder_to_string(*b,, allocator = temp);
        replace_range(buffer, range.range, new_str);
        add_paste_animation(editors.active, .{ start = range.start + cast(s32)first_line.count, end = range.start + cast(s32)new_str.count });

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
        if has_selection(cursor) continue;

        line := offset_to_real_line(buffer, cursor.pos);
        start, end := get_real_line_start_offset(buffer, line), get_real_line_end_offset(buffer, line);

        text_start_col: s32 = 0;
        i := start;
        while i < end {
            byte := buffer.bytes[i];
            if byte != #char " " && byte != #char "\t" break;
            text_start_col += 1;
            i += 1 + trailingBytesForUTF8[byte];
        }
        if cursor.pos > i then cursor.pos = i; else cursor.pos = start;
        cursor.col_wanted = -1;
    }
    organise_cursors(editor);  // resolve overlapping selections
    copy_selection_to_clipboard(editor, buffer, cut = true, cut_lines_without_selection = false);
}

delete_to_end_of_line :: (editor: *Editor, buffer: *Buffer) {
    for * cursor : editor.cursors {
        if has_selection(cursor) continue;
        cursor.pos = get_real_line_end_offset(buffer, offset_to_real_line(buffer, cursor.pos));
    }
    organise_cursors(editor);  // resolve overlapping selections
    copy_selection_to_clipboard(editor, buffer, cut = true, cut_lines_without_selection = false);
}

copy_selection_to_clipboard :: (editor: *Editor, buffer: *Buffer, cut := false, cut_lines_without_selection := true) {
    // Check if there's anything to copy else we exit early so we don't trash the clipboard
    any_selection := false;
    for editor.cursors { if has_selection(it) { any_selection = true; break; } }
    if !any_selection && !cut && !config.settings.copy_whole_line_without_selection return;

    if cut && cut_lines_without_selection {
        // When cutting, cut whole lines for cursors which don't have selection.
        // The easiest thing to do is to pre-select lines before removing anything
        for * editor.cursors { if !has_selection(it) select_line(it, buffer); }
        organise_cursors(editor);
    }

    // We are sure now we're copying something, so dump all the previous clipboard slices
    array_reset(*clipboard.slices);

    // Fill the internal clipboard and the slices from the current editor cursors
    b: String_Builder;
    offset := 0;
    for * cursor : editor.cursors {
        is_last_cursor := it_index == editor.cursors.count - 1;
        // Get string from the cursor and format it if necessary
        str: string;
        if has_selection(cursor) {
            selected_str := get_selected_string(cursor, buffer);
            str = ifx !is_last_cursor then join(selected_str, "\n") else selected_str;
        } else if cut || config.settings.copy_whole_line_without_selection {
            line_num := offset_to_real_line(buffer, cursor.pos);
            str = get_real_line_as_string(buffer, line_num);
        } else {
            str = ifx !is_last_cursor then "\n" else "";
        }
        append(*b, str);

        // Add a new clipboard slice for each cursor
        array_add(*clipboard.slices, .{ xx offset, xx str.count, has_selection(cursor) });

        offset += str.count;
    }

    combined_str := builder_to_string(*b);
    if combined_str {
        os_clipboard_set_text(combined_str);
        if clipboard.text then free(clipboard.text);
        clipboard.text = combined_str;  // now it owns it
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
            cursor.sel = cursor.pos;
            offset_delta += selection.end - selection.start;
        }
        editor.cursor_moved = .refresh_only;
    }
}

paste_from_clipboard :: (editor: *Editor, buffer: *Buffer) {
    system_clipboard_text := os_clipboard_get_text();

    // Don't paste CRLF from other editors
    clipboard_bytes := to_bytes(system_clipboard_text);
    remove_crlf_in_place(*clipboard_bytes);
    system_clipboard_text = cast(string) clipboard_bytes;

    if system_clipboard_text != clipboard.text {
        // Editor clipboard and system clipboard are out of sync - drop the editor one
        if clipboard.text free(clipboard.text);
        clipboard.text = system_clipboard_text;
        array_reset(*clipboard.slices);
    } else {
        free(system_clipboard_text);
    }

    offset_delta := 0;
    for * cursor : editor.cursors {
        cursor.pos += xx offset_delta;
        cursor.sel += xx offset_delta;
        cursor.col_wanted = -1;

        // If there is only one slice without selection, insert slice at cursor line
        if !has_selection(cursor) && clipboard.slices.count == 1 && !clipboard.slices[0].was_selected {
            line_num   := offset_to_real_line(buffer, cursor.pos);
            line_start := get_real_line_start_offset(buffer, line_num);
            str        := clipboard.text;

            // insert_string_at_offset() make the buffer dirty
            // we rescan to clean it else we can't call offset_to_line for the next cursors
            insert_string_at_offset(buffer, line_start, str);
            rescan_for_lines(buffer);
            if line_wrap_is_active(editor) then rescan_for_wrapped_lines(editor, buffer);

            cursor.pos   += xx str.count;
            offset_delta += str.count;
            add_paste_animation(editors.active, .{ line_start, line_start + cast(s32) str.count });
        }
        // If they have the same number of entries paste one slice per cursor
        else if editor.cursors.count == clipboard.slices.count {
            clipboard_slice := clipboard.slices[it_index];
            selection       := get_selection(cursor);
            count           := clipboard_slice.count - 1; // Don't paste the last newline of the slice
            if it_index == clipboard.slices.count - 1 && clipboard_slice.was_selected then count += 1; // If the last slice was selected, it didn't have newline
            str             := slice(clipboard.text, clipboard_slice.start, max(0, count));

            replace_range(buffer, selection, str);

            cursor.pos    = xx (selection.start + str.count);
            offset_delta += str.count - (selection.end - selection.start);
            add_paste_animation(editors.active, .{ selection.start, selection.start + cast(s32) str.count });
        }
        // Paste the entire clipboard for each cursor
        else {
            selection := get_selection(cursor);
            str       := clipboard.text;

            replace_range(buffer, selection, str);

            cursor.pos    = xx (selection.start + str.count);
            offset_delta += str.count - (selection.end - selection.start);
            add_paste_animation(editors.active, .{ selection.start, selection.start + cast(s32) str.count });
        }
    }

    editor.cursor_moved = .large_edit;
}

toggle_comment :: (editor: *Editor, buffer: *Buffer, is_fallback := false) {
    comment: string = ---;

    if #complete buffer.lang == {
        case .Jai;    #through;
        case .C;      #through;
        case .Cpp;    #through;
        case .CSharp; #through;
        case .Glsl;   #through;
        case .Hlsl;   #through;
        case .Golang; #through;
        case .Js;     #through;
        case .Json;   #through;
        case .Odin;   #through;
        case .Rust;   #through;
        case .Yang;   #through;
        case .Zig;
            comment = "//";

        case .Lua;
            comment = "--";

        case .Python;       #through;
        case .RenPy;        #through;
        case .Focus_Config; #through;
        case .Focus_Theme;
            comment = "#";

        case .Batch;
            comment = "rem";

        // Single-line comments are not supported, fallback to multi-line comment
        case .Css;      #through;
        case .Xml;      #through;
        case .Html;     #through;
        case .Uxntal;   #through;
        case .Markdown;
            assert(!is_fallback, "Infinite recursion");
            toggle_block_comment(editor, buffer, true);
            return;

        // No support for comments at all
        case .Plain_Text;        #through;
        case .Todo;              #through;
        case .Focus_Build_Panel;
            return;
    }

    // Get the affected lines
    line_starts, last_line_end_offset := get_line_starts_for_lines_with_cursors_tmp(editor, buffer);
    last_line := line_starts.count - 1;
    array_add(*line_starts, last_line_end_offset); // So that line_starts[it+1] will always work.

    // NOTE: Before commenting/uncommenting, we loop over the selected lines once to do the following:
    //       A. Remember if the line is empty, because empty lines are ignored.
    //       B. Determine whether we're adding or removing comments.
    //       C. Find the minimum indent (which is only for adding comments, but we don't know if we need it until the end of the loop)
    //       Minimum indent works as follows:

    //         if foo {
    //             bar();
    //         }
    // ^^^^^^^^   <- minimum indent

    //       To make this work intuitively and robustly, we have to measure the VISUAL width of the minimum indent.
    //       We cannot count the whitespace characters because there may be tabs, and tabs have weird alignment rules.

    // We're using a single bit on the line start offset to mark lines as empty. This saves us from having to loop over every line *again*
    // once we start adding/removing comments. Since it is the sign bit, this doesn't overwrite any bits that could be part of valid offsets.
    // We set this bit manually instead of multiplying with -1 because this way it also works for offset 0.
    EMPTY_LINE_BIT  :: (cast(s32) 1) >>> 1;
    LINE_START_MASK :: ~EMPTY_LINE_BIT;

    min_indent  := -1;
    add_comment := false;
    for 0..last_line {
        start, end := line_starts[it], line_starts[it+1];
        str := cast(string) to_view(buffer.bytes, start, end-start);

        // NOTE: 'str' may actually be multiple lines! This happens when you have two cursors and they are spaced multiple lines apart.
        //       You get the start offsets of both lines, and with start=[i] and end=[i+1] you are selecting the whole region in between
        //       those lines. Having multiple lines inside 'str' may seem weird but it's usually not a problem. Since we are using
        //       line-comments, placing or removing a comment from the start of 'str' will only affect the first line, the lines below
        //       are unchanged. And that's exactly what should happen, since we only want to modify the first line and leave the rest
        //       unaffected.

        indent        := 0;
        is_empty_line := true;
        trimmed_str: string = ---;
        for c : cast([]u8) str {
            if c == {
                case #char "\t"; indent += TAB_SIZE - (indent % TAB_SIZE); continue c;
                case #char " ";  indent += 1;                              continue c;

                // In this case, this one line is empty, but str contains multiple lines. See the large comment above.
                case #char "\r"; #through;
                case #char "\n";
                    break c;

                case;
                    trimmed_str   = slice(str, it_index, str.count - it_index);
                    is_empty_line = false;
                    break c;
            }
        }

        if is_empty_line                                      then { line_starts[it] |= EMPTY_LINE_BIT; continue; }
        if min_indent < 0 || indent < min_indent              then min_indent = indent;
        if !add_comment && !begins_with(trimmed_str, comment) then add_comment = true;
    }

    if editor.cursors.count == 1 && !has_selection(editor.cursors[0]) && (line_starts[0] & EMPTY_LINE_BIT) {
        // Inserts a comment at the cursor position if there's only one cursor and the current line is empty.

        cursor := *editor.cursors[0];
        insert_string_at_offset(buffer, cursor.pos, tprint("% ", comment));

        cursor.pos += xx (comment.count + 1);
        cursor.sel = cursor.pos;
        cursor.col_wanted = -1;

        editor.cursor_moved = .unimportant;

        return;
    }

    // Build a replacement string
    b: String_Builder;  // not using temp because the string may be too large

    if add_comment {
        assert(min_indent > -1);

        use_spaces := config.settings.insert_spaces_when_pressing_tab;
        new_whitespace := ifx use_spaces then get_tmp_spaces(min_indent) else {
            tab_count := min_indent / TAB_SIZE; // Aligns the indentation with tab columns because of integer division.
            min_indent = tab_count * TAB_SIZE;  // Update min_indent too. If you use tabs, your comments will align with tab columns.
            get_tmp_tabs(tab_count);
        }

        adjustment := 0;
        for 0..last_line {
            start, end := line_starts[it] & LINE_START_MASK, line_starts[it+1] & LINE_START_MASK;
            str        := cast(string) to_view(buffer.bytes, start, end-start);
            if line_starts[it] & EMPTY_LINE_BIT { append(*b, str); continue; }

            // Count how many characters are in the minimum indent, then cut off those characters since they will be replaced with new_whitespace
            indent, old_whitespace_count := 0;
            while indent < min_indent {
                c := str[old_whitespace_count];
                if c == {
                    case #char " ";  indent += 1;
                    case #char "\t"; indent += TAB_SIZE - (indent % TAB_SIZE);
                    case;            assert(false, "Unexpected character 0x%, (expected only tabs/spaces)\n", formatInt(c, base=16));
                }
                old_whitespace_count += 1;
            }
            if indent > min_indent then old_whitespace_count -= 1;
            trimmed_str := advance(str, old_whitespace_count);

            append(*b, new_whitespace);
            append(*b, comment);
            append(*b, " ");
            append(*b, trimmed_str);

            adjusted_start             := start + adjustment;
            adjusted_old_comment_start := start + adjustment + old_whitespace_count;
            adjusted_new_comment_start := start + adjustment + new_whitespace.count;

            line_length_difference := -old_whitespace_count + new_whitespace.count + (comment.count + 1);

            for * cursor : editor.cursors {
                if      cursor.pos > adjusted_old_comment_start then cursor.pos += xx line_length_difference;
                else if cursor.pos >= adjusted_start            then cursor.pos  = xx adjusted_new_comment_start;
                if      cursor.sel > adjusted_old_comment_start then cursor.sel += xx line_length_difference;
                else if cursor.sel >= adjusted_start            then cursor.sel  = xx adjusted_new_comment_start;
            }
            adjustment += line_length_difference;
        }
    } else { // Remove comments
        adjustment := 0;
        for 0..last_line {
            start, end := line_starts[it] & LINE_START_MASK, line_starts[it+1] & LINE_START_MASK;
            str        := cast(string) to_view(buffer.bytes, start, end-start);
            if line_starts[it] & EMPTY_LINE_BIT { append(*b, str); continue; }

            found, whitespace, after_comment := split_from_left(str, comment);
            assert(found, "When un-commenting, all non-empty lines should have a comment.");

            len_comment := comment.count;
            if begins_with(after_comment, " ") { advance(*after_comment, 1); len_comment += 1; }

            append(*b, whitespace);
            append(*b, after_comment);

            adjusted_comment_start := start + whitespace.count + adjustment;
            for * cursor : editor.cursors {
                if cursor.pos > adjusted_comment_start then cursor.pos -= xx min(len_comment, cursor.pos - adjusted_comment_start);
                if cursor.sel > adjusted_comment_start then cursor.sel -= xx min(len_comment, cursor.sel - adjusted_comment_start);
            }
            adjustment -= len_comment;
        }
    }

    new_str := builder_to_string(*b);
    defer free(new_str);

    range := Offset_Range.{ start = xx line_starts[0] & LINE_START_MASK, end = xx last_line_end_offset };
    replace_range(buffer, range, new_str);

    for * cursor : editor.cursors { cursor.col_wanted = -1; }

    editor.cursor_moved = .unimportant;
}

toggle_block_comment :: (editor: *Editor, buffer: *Buffer, is_fallback := false) {
    comment_start: string = ---;
    comment_end:   string = ---;

    if #complete buffer.lang == {
        case .Jai;    #through;
        case .C;      #through;
        case .Cpp;    #through;
        case .Css;    #through;
        case .CSharp; #through;
        case .Glsl;   #through;
        case .Hlsl;   #through;
        case .Golang; #through;
        case .Js;     #through;
        case .Json;   #through;
        case .Odin;   #through;
        case .Rust;   #through;
        case .Yang;
            comment_start = "/*";
            comment_end   = "*/";

        case .Lua;
            comment_start = "--[[";
            comment_end   = "]]";

        case .Xml;  #through;
        case .Html;
            comment_start = "<!--";
            comment_end   = "-->";

        case .Uxntal;
            comment_start = "(";
            comment_end   = ")";

        // Available with extensions
        case .Markdown;
            comment_start = "<!---";
            comment_end   = "--->";

        // Muilti-line comments are not supported, fallback to multiple single-line comments
        case .Batch;        #through;
        case .Python;       #through; // Yes, we could use multi-line strings but they have to be properly indented, so let's just fallback to several single-line comments and not to create more headache
        case .RenPy;        #through; // Yeah, there is a trick but meh (https://lemmasoft.renai.us/forums/viewtopic.php?p=299664#p299664 in case someone would like to implement it)
        case .Zig;          #through;
        case .Focus_Config; #through;
        case .Focus_Theme;
            assert(!is_fallback, "Infinite recursion");
            toggle_comment(editor, buffer, true);
            return;

        // No support for comments at all
        case .Plain_Text;        #through;
        case .Todo;              #through;
        case .Focus_Build_Panel;
            return;
    }

    remove_comment := true;

    indices: [..] s64;

    indices.allocator = temp;

    for cursor : editor.cursors {
        selection := get_selection(cursor);

        split_left := to_string(buffer.bytes);
        split_left.count = selection.start;

        split_right := to_string(buffer.bytes);
        split_right.data  += selection.end;
        split_right.count -= selection.end;

        start_search_index       := find_index_from_right(split_left, comment_start);
        start_search_index_limit := find_index_from_right(split_left, comment_end);

        end_search_index         := find_index_from_left(split_right, comment_end);
        end_search_index_limit   := find_index_from_left(split_right, comment_start);

        if end_search_index_limit == -1 then end_search_index_limit = S64_MAX;

        if start_search_index < start_search_index_limit && end_search_index > end_search_index_limit {
            // We are between two comments, don't remove them...
            remove_comment = false;
            break;
        }

        if start_search_index == -1 || end_search_index == -1 {
            // There is either no comment start or comment end in the file, add new comment.
            remove_comment = false;
            break;
        }

        end_search_index += selection.end;

        array_add(*indices, start_search_index);
        array_add(*indices, end\ _search_index);
    }

    if remove_comment {
        quick_sort(indices, (a, b) => (b - a));

        for index : indices {
            bytes_from_index: string;
            bytes_from_index.data = buffer.bytes.data + index;
            bytes_from_index.count = buffer.bytes.count - index;

            count_removed := 0;

            if starts_with(bytes_from_index, comment_start) {
                delete_range(buffer, .{xx index, xx (index + comment_start.count)});
                count_removed = comment_start.count;
            } else if starts_with(bytes_from_index, comment_end) {
                delete_range(buffer, .{xx index, xx (index + comment_end.count)});
                count_removed = comment_end.count;
            }

            if count_removed {
                for * cursor : editor.cursors {
                    if cursor.pos > index {
                        cursor.pos -= xx count_removed;
                    }
                    if cursor.sel > index {
                        cursor.sel -= xx count_removed;
                    }
                }
            }
        }
    } else {
        comment_total_length := cast(s32)(comment_start.count + comment_end.count);

        for * cursor : editor.cursors {
            move_count := cast(s32)it_index * comment_total_length;

            selection := get_selection(cursor);

            // If it's a fallback we want to comment out lines entirely, not just selection (as we do in toggle_comment)
            if is_fallback {
                selection_start_line_index := offset_to_real_line(buffer, selection.start);
                selection_end_line_index   := offset_to_real_line(buffer, selection.end);

                selection.start = get_real_line_start_offset(buffer, selection_start_line_index);
                selection.end   = get_real_line_end_offset(buffer, selection_end_line_index);
            }

            start_pos := selection.start + move_count;
            end_pos   := selection.end   + move_count + cast(s32) comment_start.count;

            insert_string_at_offset(buffer, start_pos, comment_start);
            insert_string_at_offset(buffer, end_pos,   comment_end);
            cursor.pos += cast(s32)comment_start.count + move_count;
            cursor.sel += cast(s32)comment_start.count + move_count;
        }
    }

    editor.cursor_moved = .unimportant;
}

toggle_line_wrap :: (editor: *Editor) {
    if line_wrap_is_active(editor) {
        editor.line_wrap = .to_disable;
    } else {
        editor.line_wrap = .to_enable;
    }
    redraw_requested = true;
}

toggle_line_numbers :: () {
    config.settings.show_line_numbers = !config.settings.show_line_numbers;
    redraw_requested = true;
}

copy_current_line_info :: (using editor: *Editor, buffer: Buffer) {
    file_path: string = copy_temporary_string(ifx buffer.has_file then buffer.file.full_path else "<in-memory-buffer>");
    path_overwrite_separators(file_path, PATH_SEPARATOR);  // match the system separator
    coords := offset_to_real_coords(buffer, cursors[main_cursor].pos);
    line_info := tprint("%:%", file_path, coords.line + 1);
    os_clipboard_set_text(line_info);
    add_success_message("String '%' copied to clipboard", line_info, dismiss_in_seconds = 5);
}

#scope_export

Editor :: struct {
    buffer_id: s64;

    viewport:   Viewport;
    search_bar: Search_Bar;

    cursors: Array(Cursor);
    highlights: Array(Text_Highlight);
    wrapped_line_starts: Array(s32);  // empty when line wrap is off

    main_cursor: s32;      // newly added cursors become main so that we jump to them
    original_cursor: s32;  // we remember the original cursor when first creating multiple cursors (and go back to it on escape)

    num_selected_chars: s32;  // across all cursors
    num_selected_bytes: s32;

    last_width_in_chars: s32 = S32_MAX;

    scroll_to_cursor: enum u8 { no; yes; yes_new_editor; }  // trigger a scroll so that the cursor is in the center vertically
    line_wrap:        enum u8 { off; to_enable; to_disable; on; };
    refresh_selection  := false;
    search_whole_words := false;  // used when creating new cursors
    cursor_moved := Cursor_Movement.has_not_moved; // this may trigger a scroll so that the cursor is within acceptable bounds
}

Cursor_Movement :: enum u8 {
    has_not_moved;
    moved_up;
    moved_down;
    moved_up_with_edit;
    moved_down_with_edit;
    unimportant;  // don't move this one, it's a boundary

    // movements above here can be merged in history
    jumped;
    large_edit;
    selection;
    refresh_only;
}

Viewport :: struct {
    scroll_y := #run Tween_Animation(s32).{ speed = 0.1, func = .lerp };
    scroll_x := #run Tween_Animation(s32).{ speed = 0.1, func = .lerp };
    top:  s32;
    left: s32;
    glue_point: Glue_Point;

    Glue_Point :: struct { buffer_pos: s32; offset_within_line: s32; }
}

Search_Bar :: struct {
    results: Array(Text_Highlight);
    input: Text_Input;

    width_anim := #run Tween_Animation(float).{ start = WIDTH_NORMAL, target = WIDTH_NORMAL };
    WIDTH_NORMAL   :: 0.5;
    WIDTH_EXPANDED :: 0.9;

    scroll_anim := #run Tween_Animation(s32).{ speed = 0.1, func = .lerp };
    scroll_y: s32;

    width_percentage: float = WIDTH_NORMAL;  // how much of the screen the popup occupies

    selected_result: s32 = -1;
    search_point_offset: s32;  // the point used to determine the next search result. Fixed so that we can set cursor without jumping around

    original_cursor_position: Cursor;  // remember the main cursor position so we can go back to it on Esc

    per_page: s16 = 10;

    // TODO: put into enum_flags
    scroll_to_selected: Scroll_Mode = .no;
    mode: Mode = .classic;
    active:         bool;  // it receives keyboard input when active.
    case_sensitive: bool;
    case_sensitive_toggled_manually: bool;
    whole_word:     bool;
    regex_search:   bool;
    regex_is_valid: bool;
    jumped:         bool;

    Mode :: enum u8 { classic; dropdown; }
}

// What to select when dragging
Selection_Mode :: struct {
    type: enum { chars; words; lines; } = .chars;
    range:     Offset_Range;
    min_range: Offset_Range;
}

Scroll_Mode :: enum u8 { no; yes; snap; };

Text_Highlight :: struct {
    offset: s32;    // we'll convert this to position range, but only for the visible highlights
    count: s32;
    line: s32;      // useful to know the line number to display in the scrollbar area
}

Paste_Animation :: struct {
    editor_id: s64;
    range: Offset_Range;
    coords_range: Coords_Range;
    initted := false;
    started_at: Apollo_Time;
    SPEED :: 0.3;
}

Editor_State :: struct {
    layout: Layout = .None;

    active: s64 = -1;
    left:   s64 = -1;
    right:  s64 = -1;

    expanded := false;  // whether the active editor should be larger

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

open_buffers_lock: Mutex;  // must hold while adding a new buffer

open_buffers: Simple_Bucket_Array(Buffer, items_per_bucket = 1024, max_buckets = 1024);  // 8 Kb for pointer array, ~1 million buffers is the maximum
open_editors: [..] Editor;

// A map from full buffer path to buffer id (only for the open buffers, obviously)
buffers_table: Table(string, s64,
                     given_hash_function = x => Hash.get_hash(to_lower_copy_new(x,, temp)),
                     given_compare_function = platform_path_equals);

most_recent_buffers: [..] s64;  // updated when an editor is activated, used to switch between open files

editors: Editor_State;
editor_closing_id := -1;  // holds the id of the editor being closed (so that we can change the layout when it's done closing)

editor_paste_animations: [..] Paste_Animation;

editor_history: Editor_History;

clipboard: struct {
    text: string;
    slices: [..] Clipboard_Slice;
}

Clipboard_Slice :: struct {
    start: s32;
    count: s32;
    was_selected: bool;
}

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
    started_at: Apollo_Time;
    start_x: s32;
    start_y: s32;
};

splitter_pos:  float = 0.5;  // 0.5 means it's in the middle
splitter_anim: Tween_Animation(float);

Editor_History :: struct {
    frames: [..] Editor_History_Frame;
    start   := 0;
    end     := 0;
    current := 0;
    initted := false;
}

Editor_History_Frame :: struct {
    using editor_state: Editor_State;
    pos: s32;
    cursor_movement : Cursor_Movement;
}

operator== :: (a: Editor_History_Frame, b: Editor_History_Frame) -> bool {
    return a.editor_state == b.editor_state && a.pos == b.pos;
}

operator== :: (a: Editor_State, b: Editor_State) -> bool {
    return a.active == b.active
        && a.left   == b.left
        && a.right  == b.right
        && a.layout == b.layout
        && a.expanded == b.expanded;
}

next_history_index :: (f: s64) -> s64 {
    return (f + 1) % config.settings.editor_history_size;
}

previous_history_index :: (f: s64) -> s64 {
    if f == 0  return editor_history.frames.count - 1;
    else       return f - 1;
}

maybe_save_editor_history :: () {
    if editor_closing_id >= 0 return;

    using editor_history;

    // Set the initial size and then handle potential editor history size changes in case someone edits the config
    if frames.count != config.settings.editor_history_size {
        array_resize(*frames, config.settings.editor_history_size);
        initted = false;
    }

    editor, buffer := get_active_editor_and_buffer();

    frame := Editor_History_Frame.{
        editor_state = editors,
        pos = ifx editor then editor.cursors[editor.main_cursor].pos else 0,
        cursor_movement = ifx editor then editor.cursor_moved else .has_not_moved,
    };

    if !initted {
        initted = true;
        start, end, current = 0;
        frames[current] = frame;
        return;
    }

    if editor && editor.cursor_moved == .refresh_only || frames[current] == frame return;

    previous_index := current;
    current = next_history_index(current);
    num_previous_frames := ifx start <= current then current - start else frames.count - start + current;

    should_merge_frame := false;
    previous_frame := frames[previous_index];
    if frames_are_mergeable(frame, previous_frame) && num_previous_frames >= 2 {
        // We want to keep the first frame of a move type, and then keep overwriting the second frame
        // of that type. So, check if this is the third frame of that type.
        previous_previous_frame := frames[previous_history_index(previous_index)];
        if frames_are_mergeable(previous_previous_frame, previous_frame) then should_merge_frame = true;
    }

    // When a pane closes it may result in two updates: the cursor moving over to the
    // other pane and then the pane being closed.  In these cases we should overwrite the
    // former with the latter so it is stored as a single step.
    should_merge_frame |=
           previous_frame.layout == .Double && frame.layout == .Single
        && previous_frame.active == frame.active
        && previous_frame.left   == frame.left
        && previous_frame.right  == frame.right;

    // If all editors are closed, we remember this state, but later override it
    // (if we just didn't write anything to history when layout is None, we wouldn't be able
    // to reopen the previous editor by going back in history without additional handling)
    should_merge_frame |= previous_frame.layout == .None;

    if should_merge_frame {
        current = previous_index;
    } else {
        if end != previous_index && frame.editor_state == previous_frame.editor_state {
            // We don't want to destroy the last frame when we've only moved the cursor after going back in history,
            // so we'll keep the last frame unless the editor state has changed
            new_end := next_history_index(current);
            frames[new_end] = frames[end];
            end = new_end;
        } else {
            end = current;
        }
    }

    // Push the start point if we've looped around
    if end == previous_history_index(start) then start = next_history_index(start);

    // print("STORE: current: %, start: %, end: %. STATE: %\n", current, start, end, frame.editor_state);
    frames[current] = frame;
}

frames_are_mergeable :: (a: Editor_History_Frame, b: Editor_History_Frame) -> bool {
    return a.cursor_movement <= .unimportant
        && a.cursor_movement == b.cursor_movement
        && a.editor_state == b.editor_state;
}

move_to_previous_editor_history :: (by_buffer := false) {
    using editor_history;
    // print("BACK: current: %, start: %, end: %\n", current, start, end);
    if current == start return;

    old_frame := frames[current];
    current = previous_history_index(current);
    if by_buffer {
        while current != start && old_frame.editor_state == frames[current].editor_state {
            current = previous_history_index(current);
        }
    }
    move_to_editor_history_frame(frames[current], old_frame);
    // print("   -> current: %, start: %, end: %. RESTORE: %\n", current, start, end, frames[current]);
}

move_to_next_editor_history :: (by_buffer := false) {
    using editor_history;
    // print("FORW: current: %, start: %, end: %\n", current, start, end);
    if current == end return;

    old_frame := frames[current];
    current = next_history_index(current);
    if by_buffer {
        while current != end && old_frame.editor_state == frames[current].editor_state {
            current = next_history_index(current);
        }
    }
    move_to_editor_history_frame(frames[current], old_frame);
    // print("   -> current: %, start: %, end: %. RESTORE: %\n", current, start, end, frames[current]);
}

move_to_editor_history_frame :: (frame: Editor_History_Frame, old_frame: Editor_History_Frame) {
    editors = frame.editor_state;
    if editors.active < 0 || editors.layout == .None {
        update_window_title();  // reset
        return;
    }

    make_editor_active(editors.active);
    editor := *open_editors[editors.active];

    // Animations
    if old_frame.layout == .Single && frame.layout == .Double {
        // Opening another pane
        if old_frame.active == frame.left {
            editors_start_moving_splitter(0.5, start = 1.0);  // open from the right
            open_editors[frame.left ].scroll_to_cursor = .yes;
            open_editors[frame.right].scroll_to_cursor = .yes_new_editor;
        } else if old_frame.active == frame.right {
            editors_start_moving_splitter(0.5, start = 0.0);  // open from the left
            open_editors[frame.left ].scroll_to_cursor = .yes_new_editor;
            open_editors[frame.right].scroll_to_cursor = .yes;
        } else {
            editors_start_moving_splitter(0.5, start = 0.5);  // both editors are new - snap
            open_editors[frame.left ].scroll_to_cursor = .yes;
            open_editors[frame.right].scroll_to_cursor = .yes;
        }
    } else if old_frame.layout == .Double && frame.layout == .Single {
        // Closing a pane
        if (frame.active == old_frame.left || frame.active == old_frame.right) {
            editor_closing_id = frame.active;
            editors.layout = .Double;  // will change when the animation finishes
            if frame.active == old_frame.left {
                editors.right = old_frame.right;  // make sure we're drawing the correct buffer while it closes
                editors.left  = editors.active;
                if !config.settings.disable_file_open_close_animations {
                    editors_start_moving_splitter(1.0);  // close right
                } else {
                    finish_closing_editor();
                }
            } else {
                editors.left  = old_frame.left;  // make sure we're drawing the correct buffer while it closes
                editors.right = editors.active;
                if !config.settings.disable_file_open_close_animations {
                    editors_start_moving_splitter(0.0);  // close left
                } else {
                    finish_closing_editor();
                }
            }
        }
        editor.scroll_to_cursor = .yes;
    } else {
        editor.scroll_to_cursor = .yes;
    }
    if frame.expanded != old_frame.expanded && editor_closing_id < 0 then toggle_editor_expand(frame.expanded);  // do it last

    cursor := leave_only_original_cursor(editor);
    cursor.pos = frame.pos;
    cursor.sel = cursor.pos;

    put_cursor_in_valid_spot(cursor, open_buffers[editor.buffer_id]);
}

#scope_file

cursor_blink_start: Apollo_Time;
cursors_blinking := false;

global_config_buffer_id := -1;
global_troubleshooting_buffer_id := -1;

CURSOR_BLINK_SPEED_MS   :: 500;

#import "Clipboard";
