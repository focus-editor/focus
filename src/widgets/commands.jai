commands_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    return dialog_handle_event(*commands_dialog, event);
}

commands_execute_selected :: (placement: Editor_Placement = .in_place) {
    hide_dialog(*commands_dialog);

    using commands_dialog;
    if selected >= filtered.count return;

    command := filtered[selected].details;
    for * commands { if command.action == it.action { it.num_times_used += 1; break; } }

    if command.is_build_command {
        action := cast(Action_Build) command.action;
        maybe_execute_a_build_command(action);
    } else {
        action := cast(Action_Editors) command.action;

        if action == .do_nothing return;

        handled := handle_common_editor_action(action, placement);
        if !handled {
            editor, buffer := get_active_editor_and_buffer();
            active_editor_handle_event(editor, buffer, Input.Event.{}, action);
        }
    }
}

// Some commands open a new editor, for those we want to be able to select a specific pane
commands_open_in_pane :: (number: s64) {
    using commands_dialog;
    if selected >= filtered.count return;

    command := filtered[selected].details;
    if command.is_build_command return;

    pane := editors_find_pane_by_number(number);
    if !pane return;

    handled := true;
    action := cast(Action_Editors) command.action;
    if action == {
        case .edit_current_theme;                               edit_current_theme(pane);
        case .open_global_config;                               editors_open_global_config(pane);
        case .open_project_config;                              editors_open_project_config(pane);
        case .show_default_config;                              editors_show_default_config(pane);
        case .show_troubleshooting_info;                        editors_show_troubleshooting_info(pane);
        case .create_new_file;                                  editors_create_new_file(pane);
        case;                                                   handled = false;
    }

    hide_dialog(*commands_dialog);
}

commands_refresh_after_config_change :: () {
    // Add base commands first (should only do it once)
    if !commands then array_add(*commands, ..base_commands);

    // Free previous build commands
    for base_commands.count .. commands.count - 1 {
        free(commands[it].name);
    }
    array_resize(*commands, base_commands.count);

    // Add build commands on top of that
    for config.build.commands {
        array_add(*commands, Command.{
            action = cast(u16) (it_index + 1),
            name = sprint("Build Command: %", it.name),
            is_build_command = true,
        });
    }

    refresh_dialog_entries(*commands_dialog);
}

commands_dialog: Commands_Dialog;

Commands_Dialog :: struct {
    using #as generic_dialog: Generic_Choice_Dialog(Command);
    generic_dialog.global_widget_id = .commands_dialog;
    generic_dialog.refresh_entries  = commands_refresh_entries;
    generic_dialog.open_entry         = commands_execute_selected;
    generic_dialog.open_entry_in_pane = commands_open_in_pane;
};

#scope_file

commands_refresh_entries :: (filter: Fuzzy_Filter) {
    using commands_dialog;

    editor_layout := editors_get_layout();

    for command : commands {
        if command.requires_layout == .Single && editor_layout == .None   continue;
        if command.requires_layout == .Multi && editor_layout != .Multi continue;
        if !project_config.loaded && (command.action == xx Action_Editors.open_project_config || command.action == xx Action_Editors.close_project) continue;

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

commands: [..] Command;

base_commands := #run -> [] Command {
    cmd :: inline (name: string, action: Action_Editors, requires_layout: Editor_State.Layout = .None) -> Command {
        return Command.{ action = xx action, name = name, requires_layout = requires_layout };
    }

    common_commands := Command.[
        cmd( "Quit",                              .quit,                             .None   ),

        cmd( "Open File By Name",                 .open_file_by_name,                .None   ),
        cmd( "Navigate To File",                  .navigate_to_file,                 .None   ),
        cmd( "Navigate To File From Root",        .navigate_to_file_from_root,       .None   ),
        cmd( "Switch Between Open Files" ,        .switch_between_open_files,        .None   ),

        cmd( "Switch To Project",                 .switch_to_project,                .None   ),
        cmd( "Close Project",                     .close_project,                    .None   ),
        cmd( "Reload Workspace",                  .reload_workspace,                 .None   ),
        cmd( "Open Directory With Project Files", .open_projects_directory,          .None   ),
        cmd( "Open Project Config",               .open_project_config,              .None   ),
        cmd( "Open Global Config",                .open_global_config,               .None   ),
        cmd( "Show Default Config (readonly)",    .show_default_config,              .None   ),

        cmd( "Choose Theme",                      .choose_theme,                     .None   ),
        cmd( "Edit Current Theme",                .edit_current_theme,               .None   ),

        cmd( "Create New File",                   .create_new_file,                  .None   ),
        cmd( "Create New File In Side Pane",      .create_new_file_in_side_pane,     .Single ),

        cmd( "Search In Workspace",               .search_in_project,                .None   ),

        cmd( "Select All",                        .select_all,                       .Single ),
        cmd( "Select Line",                       .select_line,                      .Single ),
        cmd( "Select All Occurrences",            .select_all_occurrences,           .Single ),
        cmd( "Swap Selections",                   .swap_selections,                  .Single ),

        cmd( "Go To Line",                        .go_to_line,                       .Single ),

        cmd( "Close Editor",                      .close_editor,                     .Single ),
        cmd( "Close Other Editors In Pane",       .close_other_editors_in_pane,      .Single ),
        cmd( "Close All Editors",                 .close_all_editors,                .Single ),

        cmd( "Close Pane",                        .close_pane,                       .Single ),
        cmd( "Close Other Panes",                 .close_other_panes,                .Single ),
        cmd( "Close Left Pane",                   .close_left_pane,                  .Single ),
        cmd( "Close Right Pane",                  .close_right_pane,                 .Single ),
        cmd( "Close Top Pane",                    .close_top_pane,                   .Single ),
        cmd( "Close Bottom Pane",                 .close_bottom_pane,                .Single ),

        cmd( "Save",                              .save,                             .Single ),
        cmd( "Save As",                           .save_as,                          .Single ),
        cmd( "Save All",                          .save_all,                         .Single ),

        cmd( "Open File Directory",               .open_file_directory,              .Single ),

        cmd( "Move Current File",                 .move_current_file,                .Single ),
        cmd( "Delete Current File",               .delete_current_file,              .Single ),

        cmd( "Join Lines",                        .join_lines,                       .Single ),
        cmd( "Join Lines (no spaces in between)", .join_lines_no_spaces_in_between,  .Single ),

        cmd( "Duplicate Lines",                   .duplicate_lines,                  .Single ),
        cmd( "Delete Line",                       .delete_line,                      .Single ),
        cmd( "Delete Line And Go Up",             .delete_line_and_go_up,            .Single ),
        cmd( "Delete To Start Of Line",           .delete_to_start_of_line,          .Single ),
        cmd( "Delete To End Of Line",             .delete_to_end_of_line,            .Single ),
        cmd( "Cut To Start Of Line",              .cut_to_start_of_line,             .Single ),
        cmd( "Cut To End Of Line",                .cut_to_end_of_line,               .Single ),
        cmd( "Move Selected Lines Up",            .move_selected_lines_up,           .Single ),
        cmd( "Move Selected Lines Down",          .move_selected_lines_down,         .Single ),
        cmd( "Move Up To Empty Line",             .move_up_to_empty_line,            .Single ),
        cmd( "Move Down To Empty Line",           .move_down_to_empty_line,          .Single ),

        cmd( "Center Viewport On Cursor",         .center_viewport_on_cursor,        .Single ),
        cmd( "Move Cursor To Viewport Center",    .move_cursor_to_viewport_center,   .Single ),
        cmd( "Remove Additional Cursors",         .remove_additional_cursors,        .Single ),

        cmd( "Add Cursors To Line Ends",          .add_cursors_to_line_ends,         .Single ),
        cmd( "Add Cursors To Line Starts",        .add_cursors_to_line_starts,       .Single ),
        cmd( "Align Cursors",                     .align_cursors,                    .Single ),

        cmd( "Cursor: Go Back",                   .cursor_go_back,                   .None   ),
        cmd( "Cursor: Go Forward",                .cursor_go_forward,                .None   ),

        cmd( "Go To Previous Buffer",             .go_to_previous_buffer,            .Single ),
        cmd( "Go To Next Buffer",                 .go_to_next_buffer,                .Single ),

        cmd( "New Line Below Without Breaking",   .new_line_below_without_breaking,  .Single ),
        cmd( "New Line Above Without Breaking",   .new_line_above_without_breaking,  .Single ),

        cmd( "Strip Trailing Whitespace",         .strip_trailing_whitespace,        .Single ),

        cmd( "Switch To Left Pane",               .switch_to_left_pane,              .Multi  ),
        cmd( "Switch To Right Pane",              .switch_to_right_pane,             .Multi  ),
        cmd( "Switch To Top Pane",                .switch_to_top_pane,               .Multi  ),
        cmd( "Switch To Bottom Pane",             .switch_to_bottom_pane,            .Multi  ),
        cmd( "Switch To Side Pane",               .switch_to_side_pane,              .Multi  ),

        cmd( "Switch To Pane 1",                  .switch_to_pane_1,                 .Multi  ),
        cmd( "Switch To Pane 2",                  .switch_to_pane_2,                 .Multi  ),
        cmd( "Switch To Pane 3",                  .switch_to_pane_3,                 .Multi  ),
        cmd( "Switch To Pane 4",                  .switch_to_pane_4,                 .Multi  ),
        cmd( "Switch To Pane 5",                  .switch_to_pane_5,                 .Multi  ),
        cmd( "Switch To Pane 6",                  .switch_to_pane_6,                 .Multi  ),
        cmd( "Switch To Pane 7",                  .switch_to_pane_7,                 .Multi  ),
        cmd( "Switch To Pane 8",                  .switch_to_pane_8,                 .Multi  ),
        cmd( "Switch To Pane 9",                  .switch_to_pane_9,                 .Multi  ),

        cmd( "Split Left",                        .split_left,                       .Single ),
        cmd( "Split Right",                       .split_right,                      .Single ),
        cmd( "Split Top",                         .split_top,                        .Single ),
        cmd( "Split Bottom",                      .split_bottom,                     .Single ),

        cmd( "Duplicate Editor",                  .duplicate_editor,                 .Single ),
        cmd( "Duplicate Editor Left",             .duplicate_editor_left,            .Single ),
        cmd( "Duplicate Editor Right",            .duplicate_editor_right,           .Single ),
        cmd( "Duplicate Editor Top",              .duplicate_editor_top,             .Single ),
        cmd( "Duplicate Editor Bottom",           .duplicate_editor_bottom,          .Single ),

        cmd( "Reopen Closed Editor",              .reopen_closed_editor,             .None   ),

        cmd( "Move Editor Left",                  .move_editor_left,                 .Single ),
        cmd( "Move Editor Right",                 .move_editor_right,                .Single ),
        cmd( "Move Editor Top" ,                  .move_editor_top,                  .Single ),
        cmd( "Move Editor Bottom",                .move_editor_bottom,               .Single ),

        cmd( "Rotate Panes Clockwise",            .rotate_panes_clockwise,           .Multi  ),
        cmd( "Rotate Panes Counterclockwise",     .rotate_panes_counterclockwise,    .Multi  ),

        cmd( "Toggle Block Comment",              .toggle_block_comment,             .Single ),
        cmd( "Toggle Line Wrap",                  .toggle_line_wrap,                 .Single ),
        cmd( "Toggle Line Numbers",               .toggle_line_numbers,              .Single ),
        cmd( "Toggle Fullscreen",                 .toggle_fullscreen,                .None   ),

        cmd( "Build: Kill Running Command",       .build_kill_running_command,       .None   ),
        cmd( "Build: Clear Build Output",         .build_clear_output,               .None   ),
        cmd( "Build: Toggle Build Panel",         .build_panel_toggle,               .None   ),
        cmd( "Build: Toggle Build Panel Focus",   .build_panel_toggle_focus,         .None   ),

        cmd( "Autoindent Region",                 .autoindent_region,                .Single ),

        cmd( "Open Another Editor Instance",      .open_another_editor_instance,     .None   ),
        cmd( "Copy Current Line Info",            .copy_current_line_info,           .Single ),

        cmd( "Choose Language Syntax",            .choose_language,                  .Single ),
        cmd( "Reload File From Disk",             .reload_from_disk,                 .Single ),

        cmd( "Indentation: Detect From File Contents",          .indentation_detect_from_buffer_contents,  .Single),
        cmd( "Indentation: Use Defaults For File",              .indentation_use_defaults_for_buffer,      .Single),
        cmd( "Indentation: Convert File Indentation To Tabs",   .indentation_convert_to_tabs_for_buffer,   .Single),
        cmd( "Indentation: Convert File Indentation To Spaces", .indentation_convert_to_spaces_for_buffer, .Single),
    ];

    linux_commands := Command.[
        cmd( "Show Troubleshooting Information",  .show_troubleshooting_info,        .None   ),
    ];

    result: [..] Command;

    array_add(*result, ..common_commands);
    #if OS == .LINUX then array_add(*result, ..linux_commands);

    return result;
}

Command :: struct {
    action: u16 = xx Action_Editors.do_nothing;
    name: string;
    requires_layout: Editor_State.Layout = .None;
    num_times_used := 0;
    is_build_command := false;
}

