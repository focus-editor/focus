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
            if editor then active_editor_handle_event(editor, buffer, Input.Event.{}, action);
        }
    }
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
            name = sprint("Build: %", it.name),
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
        cmd( "Create New File On The Side",       .create_new_file_on_the_side,      .Single ),

        cmd( "Search In Workspace",               .search_in_project,                .None   ),

        cmd( "Select All",                        .select_all,                       .Single ),
        cmd( "Select Line",                       .select_line,                      .Single ),
        cmd( "Select All Occurrences",            .select_all_occurrences,           .Single ),
        cmd( "Swap Selections",                   .swap_selections,                  .Single ),

        cmd( "Go To Line",                        .go_to_line,                       .Single ),

        cmd( "Close All Files",                   .close_all_editors,                .Single ),
        cmd( "Close Other Files",                 .close_other_editors,              .Single ),
        cmd( "Close File",                        .close_current_editor,             .Single ),
        cmd( "Close Other File",                  .close_other_editor,               .Double ),
        cmd( "Close Left File",                   .close_left_editor,                .Double ),
        cmd( "Close Right File",                  .close_right_editor,               .Double ),

        cmd( "Save",                              .save,                             .Single ),
        cmd( "Save As",                           .save_as,                          .Single ),
        cmd( "Save All",                          .save_all,                         .Single ),

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

        cmd( "Center View On Cursor",             .center_viewport_on_cursor,        .Single ),
        cmd( "Move Cursor To Screen Center",      .move_cursor_to_viewport_center,   .Single ),
        cmd( "Remove Additional Cursors",         .remove_additional_cursors,        .Single ),

        cmd( "Add Cursors To Line Ends",          .add_cursors_to_line_ends,         .Single ),
        cmd( "Add Cursors To Line Starts",        .add_cursors_to_line_starts,       .Single ),
        cmd( "Align Cursors",                     .align_cursors,                    .Single ),

        cmd( "Cursor: Go Back",                   .move_to_previous_editor_history,  .None   ),
        cmd( "Cursor: Go Forward",                .move_to_next_editor_history,      .None   ),

        cmd( "New Line Below Without Breaking",   .new_line_below_without_breaking,  .Single ),
        cmd( "New Line Above Without Breaking",   .new_line_above_without_breaking,  .Single ),

        cmd( "Strip Trailing Whitespace",         .strip_trailing_whitespace,        .Single ),

        cmd( "Switch To Left Pane",               .switch_to_left_editor,            .Double ),
        cmd( "Switch To Right Pane",              .switch_to_right_editor,           .Double ),
        cmd( "Switch To Other Pane",              .switch_to_other_editor,           .Double ),

        cmd( "Duplicate File On The Side",        .duplicate_editor,                 .Single ),
        cmd( "Duplicate File To The Left",        .duplicate_editor_to_the_left,     .Single ),
        cmd( "Duplicate File To The Right",       .duplicate_editor_to_the_right,    .Single ),

        cmd( "Move Pane To The Left",             .move_editor_to_the_left,          .Double ),
        cmd( "Move Pane To The Right",            .move_editor_to_the_right,         .Double ),

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

