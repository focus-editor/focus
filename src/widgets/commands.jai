commands_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    using commands_dialog;

    if event.type == .KEYBOARD && event.key_pressed {
        action, mapping := map_event_to_action(event, Action_Open_File_Dialog);
        if action == {
            case .close_dialog;             hide_commands_dialog();                     return true;
            case .open_entry_in_place;      commands_execute_selected(.in_place);       return true;
            case .open_entry_on_the_side;   commands_execute_selected(.on_the_side);    return true;
            case .open_entry_on_the_left;   commands_execute_selected(.left);           return true;
            case .open_entry_on_the_right;  commands_execute_selected(.right);          return true;

            case .move_up;                  move_cursor(-1, wrap = true);               return true;
            case .move_down;                move_cursor( 1, wrap = true);               return true;
            case .move_up_fast;             move_cursor(-5);                            return true;
            case .move_down_fast;           move_cursor( 5);                            return true;
            case .move_up_one_page;         move_cursor(-per_page);                     return true;
            case .move_down_one_page;       move_cursor( per_page);                     return true;
        }

        handled := maybe_handle_text_input_event(*input, event);
        return handled;

    } else if event.type == .TEXT_INPUT {
        char := event.utf32;
        if char == 127 return true;  // there seems to be a bug in the Input module
                                // which generates a TEXT_INPUT event for DEL
                                // when Ctrl+Backspace is pressed

        text_input_type_char(*commands_dialog.input, char);
        refresh_entries();
        return true;
    }
    return false;
}

show_commands_dialog :: () {
    active_global_widget = .commands_dialog;

    text_input_fully_clear(*commands_dialog.input);

    refresh_entries();
}

hide_commands_dialog :: () {
    activate_editors();
}

commands_execute_selected :: (placement: Editor_Placement = .in_place) {
    hide_commands_dialog();

    using commands_dialog;
    if selected >= filtered.count return;

    command := filtered[selected].command;
    for * commands { if command.action == it.action { it.num_times_used += 1; break; } }

    if command.action == .do_nothing return;

    handled := handle_common_editor_action(command.action, placement);
    if !handled then active_editor_handle_event(Input.Event.{}, command.action);
}

#scope_file

refresh_entries :: () {
    using commands_dialog;

    array_reset_keeping_memory(*filtered);

    editor, buffer := get_active_editor_and_buffer();

    scroll_to_cursor = .snap;
    scroll_y = 0;
    selected = 0;

    filter_chars := decode_utf8_string_to_temp_char_substrings(to_string(input.text));

    for command : commands {
        if command.requires_layout == .Single && editors.layout == .None   continue;
        if command.requires_layout == .Double && editors.layout != .Double continue;

        score, highlights := fuzzy_match(command.name, filter_chars);
        if score < 0 continue;

        entry := array_add(*filtered);
        entry.command    = command;
        entry.highlights = highlights;

        score_part: u64 = (cast,trunc(u64) score) << 32;
        used_part:  u64 = (cast,trunc(u64) command.num_times_used) << 0;
        entry.sort_key = score_part | used_part;
    }

    compare_entries :: (e1: Entry, e2: Entry) -> s64 {
        key_diff := cast,no_check(s64) e2.sort_key - cast,no_check(s64) e1.sort_key;
        if key_diff != 0 return key_diff;
        return memcmp(e1.name.data, e2.name.data, min(e1.name.count, e2.name.count));
    }

    quick_sort(filtered, compare_entries);
}

move_cursor :: (delta: s64, wrap := false, snap := true) {
    using commands_dialog;

    selected += delta;

    if wrap {
        if selected < 0 then selected = max(0, filtered.count - 1);
        if selected >= filtered.count then selected = 0;
    } else {
        if selected < 0 then selected = 0;
        if selected >= filtered.count then selected = filtered.count - 1;
    }
    scroll_to_cursor = ifx snap then Scroll_Mode.snap else .yes;
}

maybe_handle_text_input_event :: (using input: *Text_Input, event: Input.Event) -> handled: bool {
    input_text := copy_temporary_string(to_string(text));
    handled := text_input_handle_event(input, event);
    if handled {
        if input_text != to_string(input.text) then refresh_entries();
        return true;
    }
    return false;
}


#scope_export

commands_dialog: Commands_Dialog;


#scope_file

commands := #run Command.[
    .{ .show_open_file_dialog_in_search_mode,               "Open File By Name",                  0, .None },
    .{ .show_open_file_dialog_in_navigate_mode,             "Navigate To File",                   0, .None },
    .{ .show_open_file_dialog_in_navigate_mode_from_root,   "Navigate To File From Root",         0, .None },

    .{ .switch_to_project,                                  "Switch To Project",                  0, .None },
    .{ .open_projects_directory,                            "Open Projects Directory",            0, .None },
    .{ .open_project_config,                                "Open Config For Project",            0, .None },
    .{ .open_global_config,                                 "Open Global Config",                 0, .None },

    .{ .create_new_file,                                    "Create New File",                    0, .None },
    .{ .create_new_file_on_the_side,                        "Create New File On The Side",        0, .Single },

    .{ .search_in_project,                                  "Search In Workspace",                0, .None },

    .{ .select_all,                                         "Select All",                         0, .Single },
    .{ .select_line,                                        "Select Line",                        0, .Single },
    .{ .go_to_line,                                         "Go To Line",                         0, .Single },

    .{ .close_current_editor,                               "Close File",                         0, .Single },
    .{ .close_other_editor,                                 "Close Other File",                   0, .Double },
    .{ .close_left_editor,                                  "Close Left File",                    0, .Double },
    .{ .close_right_editor,                                 "Close Right File",                   0, .Double },

    .{ .save,                                               "Save",                               0, .Single },
    .{ .save_all,                                           "Save All",                           0, .Single },

    .{ .join_lines,                                         "Join Lines",                         0, .Single },
    .{ .join_lines_no_spaces_in_between,                    "Join Lines (no spaces in between)",  0, .Single },

    .{ .duplicate_lines,                                    "Duplicate Lines",                    0, .Single },
    .{ .delete_line,                                        "Delete Line",                        0, .Single },
    .{ .delete_line_and_go_up,                              "Delete Line And Go Up",              0, .Single },
    .{ .delete_to_start_of_line,                            "Delete To Start Of Line",            0, .Single },
    .{ .delete_to_end_of_line,                              "Delete To End Of Line",              0, .Single },
    .{ .move_selected_lines_up,                             "Move Selected Lines Up",             0, .Single },
    .{ .move_selected_lines_down,                           "Move Selected Lines Down",           0, .Single },
    .{ .move_up_to_empty_line,                              "Move Up To Empty Line",              0, .Single },
    .{ .move_down_to_empty_line,                            "Move Down To Empty Line",            0, .Single },

    .{ .center_viewport_on_cursor,                          "Center View On Cursor",              0, .Single },
    .{ .move_cursor_to_viewport_center,                     "Move Cursor To Screen Center",       0, .Single },
    .{ .remove_additional_cursors,                          "Remove Additional Cursors",          0, .Single },

    .{ .move_to_previous_editor_history,                    "Move To Previous Cursor Position",   0, .None },
    .{ .move_to_next_editor_history,                        "Move To Next Cursor Position",       0, .None },

    .{ .new_line_below_without_breaking,                    "New Line Below Without Breaking",    0, .Single },
    .{ .new_line_above_without_breaking,                    "New Line Above Without Breaking",    0, .Single },

    .{ .switch_to_left_editor,                              "Switch To Left Pane",                0, .Double },
    .{ .switch_to_right_editor,                             "Switch To Right Pane",               0, .Double },
    .{ .switch_to_other_editor,                             "Switch To Other Pane",               0, .Double },

    .{ .duplicate_editor,                                   "Duplicate File On The Side",         0, .Single },
    .{ .duplicate_editor_to_the_left,                       "Duplicate File To The Left",         0, .Single },
    .{ .duplicate_editor_to_the_right,                      "Duplicate File To The Right",        0, .Single },

    .{ .move_editor_to_the_left,                            "Move Pane To The Left",              0, .Double },
    .{ .move_editor_to_the_right,                           "Move Pane To The Right",             0, .Double },

    .{ .toggle_line_wrap,                                   "Toggle Line Wrap",                   0, .Single },
    .{ .toggle_line_numbers,                                "Toggle Line Numbers",                0, .Single },
];

Command :: struct {
    action: Action_Editors = .do_nothing;
    name: string;
    num_times_used  := 0;
    requires_layout: Editor_State.Layout = .None;
}

Commands_Dialog :: struct {
    input: Text_Input;
    filtered: [..] Entry;
    selected: s64;
    selected_by_mouse: s64 = -1;  // to remember which entry the left mouse button went down on

    scroll_y: s32;
    scroll_anim := #run Tween_Animation(s32).{ speed = xx 0.1, func = .lerp };
    per_page: s64 = 10;

    scroll_to_cursor: Scroll_Mode = .no;
};

Entry :: struct {
    using command: Command;
    highlights: [] bool;
    sort_key: u64;
}
