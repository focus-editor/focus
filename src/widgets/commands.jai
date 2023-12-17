commands_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    return dialog_handle_event(*commands_dialog, event);
}

commands_execute_selected :: (placement: Editor_Placement = .in_place) {
    hide_dialog(*commands_dialog);

    using commands_dialog;
    if selected >= filtered.count return;

    command := filtered[selected].details;
    // for * commands { if command.action == it.action { it.num_times_used += 1; break; } }

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
        if score < 0 continue;

        entry := array_add(*filtered);
        entry.details    = command;
        entry.highlights = highlights;

        score_part: u64 = (cast,trunc(u64) score) << 32;
        entry.sort_key = score_part;
    }
}

commands := #run Command.[
    .{ .show_open_file_dialog_in_search_mode,               "Open File By Name",                  .None },
    .{ .show_open_file_dialog_in_navigate_mode,             "Navigate To File",                   .None },
    .{ .show_open_file_dialog_in_navigate_mode_from_root,   "Navigate To File From Root",         .None },
    .{ .show_open_file_dialog_in_open_editors_mode,         "Switch Between Open Files" ,         .None },

    .{ .switch_to_project,                                  "Switch To Project",                  .None },
    .{ .close_project,                                      "Close Project",                      .None },
    .{ .open_projects_directory,                            "Open Directory With Project Files",  .None },
    .{ .open_project_config,                                "Open Project Config",                .None },
    .{ .open_global_config,                                 "Open Global Config",                 .None },
    .{ .show_default_config,                                "Show Default Config (readonly)",     .None },
    .{ .show_troubleshooting_info,                          "Show Troubleshooting Information",   .None },

    .{ .create_new_file,                                    "Create New File",                    .None },
    .{ .create_new_file_on_the_side,                        "Create New File On The Side",        .Single },

    .{ .search_in_project,                                  "Search In Workspace",                .None },

    .{ .select_all,                                         "Select All",                         .Single },
    .{ .select_line,                                        "Select Line",                        .Single },
    .{ .select_all_occurrences,                             "Select All Occurrences",             .Single },
    .{ .swap_selections,                                    "Swap Selections",                    .Single },

    .{ .go_to_line,                                         "Go To Line",                         .Single },

    .{ .close_current_editor,                               "Close File",                         .Single },
    .{ .close_other_editor,                                 "Close Other File",                   .Double },
    .{ .close_left_editor,                                  "Close Left File",                    .Double },
    .{ .close_right_editor,                                 "Close Right File",                   .Double },

    .{ .save,                                               "Save",                               .Single },
    .{ .save_as,                                            "Save As",                            .Single },
    .{ .save_all,                                           "Save All",                           .Single },

    .{ .delete_current_file,                                "Delete Current File",                .Single },

    .{ .join_lines,                                         "Join Lines",                         .Single },
    .{ .join_lines_no_spaces_in_between,                    "Join Lines (no spaces in between)",  .Single },

    .{ .duplicate_lines,                                    "Duplicate Lines",                    .Single },
    .{ .delete_line,                                        "Delete Line",                        .Single },
    .{ .delete_line_and_go_up,                              "Delete Line And Go Up",              .Single },
    .{ .delete_to_start_of_line,                            "Delete To Start Of Line",            .Single },
    .{ .delete_to_end_of_line,                              "Delete To End Of Line",              .Single },
    .{ .move_selected_lines_up,                             "Move Selected Lines Up",             .Single },
    .{ .move_selected_lines_down,                           "Move Selected Lines Down",           .Single },
    .{ .move_up_to_empty_line,                              "Move Up To Empty Line",              .Single },
    .{ .move_down_to_empty_line,                            "Move Down To Empty Line",            .Single },

    .{ .center_viewport_on_cursor,                          "Center View On Cursor",              .Single },
    .{ .move_cursor_to_viewport_center,                     "Move Cursor To Screen Center",       .Single },
    .{ .remove_additional_cursors,                          "Remove Additional Cursors",          .Single },

    .{ .add_cursors_to_line_ends,                           "Add Cursors To Line Ends",           .Single },
    .{ .add_cursors_to_line_starts,                         "Add Cursors To Line Starts",         .Single },
    .{ .align_cursors,                                      "Align Cursors",                      .Single },

    .{ .move_to_previous_editor_history,                    "Move To Previous Cursor Position",   .None },
    .{ .move_to_next_editor_history,                        "Move To Next Cursor Position",       .None },

    .{ .new_line_below_without_breaking,                    "New Line Below Without Breaking",    .Single },
    .{ .new_line_above_without_breaking,                    "New Line Above Without Breaking",    .Single },

    .{ .switch_to_left_editor,                              "Switch To Left Pane",                .Double },
    .{ .switch_to_right_editor,                             "Switch To Right Pane",               .Double },
    .{ .switch_to_other_editor,                             "Switch To Other Pane",               .Double },

    .{ .duplicate_editor,                                   "Duplicate File On The Side",         .Single },
    .{ .duplicate_editor_to_the_left,                       "Duplicate File To The Left",         .Single },
    .{ .duplicate_editor_to_the_right,                      "Duplicate File To The Right",        .Single },

    .{ .move_editor_to_the_left,                            "Move Pane To The Left",              .Double },
    .{ .move_editor_to_the_right,                           "Move Pane To The Right",             .Double },

    .{ .toggle_line_wrap,                                   "Toggle Line Wrap",                   .Single },
    .{ .toggle_line_numbers,                                "Toggle Line Numbers",                .Single },
    .{ .toggle_fullscreen,                                  "Toggle Fullscreen",                  .None },

    .{ .autoindent_region,                                  "Autoindent Region",                  .Single },
];

Command :: struct {
    action: Action_Editors = .do_nothing;
    name: string;
    requires_layout: Editor_State.Layout = .None;
}

