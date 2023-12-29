commands_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    return dialog_handle_event(*commands_dialog, event);
}

commands_execute_selected :: (placement: Editor_Placement = .in_place) {
    hide_dialog(*commands_dialog);

    using commands_dialog;
    if selected >= filtered.count return;

    command := filtered[selected].details;
    for * commands { if command.action == it.action { it.num_times_used += 1; break; } }

    if command.action == .do_nothing return;

    handled := handle_common_editor_action(command.action, placement);
    if !handled {
        editor, buffer := get_active_editor_and_buffer();
        if editor then active_editor_handle_event(editor, buffer, Input.Event.{}, command.action);
    }
}

commands_dialog: Commands_Dialog;

Commands_Dialog :: struct {
    using #as generic_dialog: Generic_Choice_Dialog(Command);
    generic_dialog.global_widget_id = .commands_dialog;
    generic_dialog.refresh_entries  = commands_refresh_entries;
    generic_dialog.open_entry_in_place     = #bake_arguments commands_execute_selected(placement = .in_place);
    generic_dialog.open_entry_on_the_side  = #bake_arguments commands_execute_selected(placement = .on_the_side);
    generic_dialog.open_entry_on_the_left  = #bake_arguments commands_execute_selected(placement = .left);
    generic_dialog.open_entry_on_the_right = #bake_arguments commands_execute_selected(placement = .right);
};

#scope_file

commands_refresh_entries :: (filter: Fuzzy_Filter) {
    using commands_dialog;

    for command : commands {
        if command.requires_layout == .Single && editors.layout == .None   continue;
        if command.requires_layout == .Double && editors.layout != .Double continue;
        if !project_config.loaded && (command.action == .open_project_config || command.action == .close_project) continue;

        score, highlights := fuzzy_match(command.name, filter);
        if score <= 0 && filter.full_string continue;

        entry := array_add(*filtered);
        entry.details    = command;
        entry.highlights = highlights;

        score_part: u64 = (cast,trunc(u64) score) << 32;
        used_part: u64  = (cast,trunc(u64) command.num_times_used);
        entry.sort_key = score_part | used_part;
    }
}

commands := #run -> [] Command {
    base_commands := Command.[
        .{ .open_file_by_name,                     "Open File By Name",                  .None,    0 },
        .{ .navigate_to_file,                      "Navigate To File",                   .None,    0 },
        .{ .navigate_to_file_from_root,            "Navigate To File From Root",         .None,    0 },
        .{ .switch_between_open_files,             "Switch Between Open Files" ,         .None,    0 },

        .{ .switch_to_project,                     "Switch To Project",                  .None,    0 },
        .{ .close_project,                         "Close Project",                      .None,    0 },
        .{ .open_projects_directory,               "Open Directory With Project Files",  .None,    0 },
        .{ .open_project_config,                   "Open Project Config",                .None,    0 },
        .{ .open_global_config,                    "Open Global Config",                 .None,    0 },
        .{ .show_default_config,                   "Show Default Config (readonly)",     .None,    0 },

        .{ .choose_theme,                          "Choose Theme",                       .None,    0 },
        .{ .edit_current_theme,                    "Edit Current Theme",                 .None,    0 },

        .{ .create_new_file,                       "Create New File",                    .None,    0 },
        .{ .create_new_file_on_the_side,           "Create New File On The Side",        .Single,  0 },

        .{ .search_in_project,                     "Search In Workspace",                .None,    0 },

        .{ .select_all,                            "Select All",                         .Single,  0 },
        .{ .select_line,                           "Select Line",                        .Single,  0 },
        .{ .select_all_occurrences,                "Select All Occurrences",             .Single,  0 },
        .{ .swap_selections,                       "Swap Selections",                    .Single,  0 },

        .{ .go_to_line,                            "Go To Line",                         .Single,  0 },

        .{ .close_current_editor,                  "Close File",                         .Single,  0 },
        .{ .close_other_editor,                    "Close Other File",                   .Double,  0 },
        .{ .close_left_editor,                     "Close Left File",                    .Double,  0 },
        .{ .close_right_editor,                    "Close Right File",                   .Double,  0 },

        .{ .save,                                  "Save",                               .Single,  0 },
        .{ .save_as,                               "Save As",                            .Single,  0 },
        .{ .save_all,                              "Save All",                           .Single,  0 },

        .{ .delete_current_file,                   "Delete Current File",                .Single,  0 },

        .{ .join_lines,                            "Join Lines",                         .Single,  0 },
        .{ .join_lines_no_spaces_in_between,       "Join Lines (no spaces in between)",  .Single,  0 },

        .{ .duplicate_lines,                       "Duplicate Lines",                    .Single,  0 },
        .{ .delete_line,                           "Delete Line",                        .Single,  0 },
        .{ .delete_line_and_go_up,                 "Delete Line And Go Up",              .Single,  0 },
        .{ .delete_to_start_of_line,               "Delete To Start Of Line",            .Single,  0 },
        .{ .delete_to_end_of_line,                 "Delete To End Of Line",              .Single,  0 },
        .{ .move_selected_lines_up,                "Move Selected Lines Up",             .Single,  0 },
        .{ .move_selected_lines_down,              "Move Selected Lines Down",           .Single,  0 },
        .{ .move_up_to_empty_line,                 "Move Up To Empty Line",              .Single,  0 },
        .{ .move_down_to_empty_line,               "Move Down To Empty Line",            .Single,  0 },

        .{ .center_viewport_on_cursor,             "Center View On Cursor",              .Single,  0 },
        .{ .move_cursor_to_viewport_center,        "Move Cursor To Screen Center",       .Single,  0 },
        .{ .remove_additional_cursors,             "Remove Additional Cursors",          .Single,  0 },

        .{ .add_cursors_to_line_ends,              "Add Cursors To Line Ends",           .Single,  0 },
        .{ .add_cursors_to_line_starts,            "Add Cursors To Line Starts",         .Single,  0 },
        .{ .align_cursors,                         "Align Cursors",                      .Single,  0 },

        .{ .move_to_previous_editor_history,       "Move To Previous Cursor Position",   .None,    0 },
        .{ .move_to_next_editor_history,           "Move To Next Cursor Position",       .None,    0 },

        .{ .new_line_below_without_breaking,       "New Line Below Without Breaking",    .Single,  0 },
        .{ .new_line_above_without_breaking,       "New Line Above Without Breaking",    .Single,  0 },

        .{ .switch_to_left_editor,                 "Switch To Left Pane",                .Double,  0 },
        .{ .switch_to_right_editor,                "Switch To Right Pane",               .Double,  0 },
        .{ .switch_to_other_editor,                "Switch To Other Pane",               .Double,  0 },

        .{ .duplicate_editor,                      "Duplicate File On The Side",         .Single,  0 },
        .{ .duplicate_editor_to_the_left,          "Duplicate File To The Left",         .Single,  0 },
        .{ .duplicate_editor_to_the_right,         "Duplicate File To The Right",        .Single,  0 },

        .{ .move_editor_to_the_left,               "Move Pane To The Left",              .Double,  0 },
        .{ .move_editor_to_the_right,              "Move Pane To The Right",             .Double,  0 },

        .{ .toggle_block_comment,                  "Toggle Block Comment",               .Single,  0 },
        .{ .toggle_line_wrap,                      "Toggle Line Wrap",                   .Single,  0 },
        .{ .toggle_line_numbers,                   "Toggle Line Numbers",                .Single,  0 },
        .{ .toggle_fullscreen,                     "Toggle Fullscreen",                  .None,    0 },
        .{ .toggle_build_panel,                    "Toggle Build Panel",                 .None,    0 },

        .{ .build_kill_running_command,            "Build: Kill Running Command",        .None,    0 },

        .{ .autoindent_region,                     "Autoindent Region",                  .Single,  0 },
    ];

    linux_commands := Command.[
        .{ .show_troubleshooting_info,             "Show Troubleshooting Information",   .None,    0 },
    ];

    commands: [..] Command;

    array_extend(*commands, base_commands);
    #if OS == .LINUX then array_extend(*commands, linux_commands);

    return commands;
}

Command :: struct {
    action: Action_Editors = .do_nothing;
    name: string;
    requires_layout: Editor_State.Layout = .None;
    num_times_used := 0;
}

