// Generate action enums from the corresponding arrays below
#insert -> string {
    b: String_Builder;
    init_string_builder(*b);

    define_enum :: (b: *String_Builder, enum_name: string, values: [] string) {
        print_to_builder(b, "% :: enum u16 {\n", enum_name);
        for v : values print_to_builder(b, "    %;\n", v);
        print_to_builder(b, "}\n");
    }

    define_enum(*b, "Action_Common",           ACTIONS_COMMON);
    define_enum(*b, "Action_Editors",          ACTIONS_EDITORS);
    define_enum(*b, "Action_Open_File_Dialog", ACTIONS_OPEN_FILE_DIALOG);
    define_enum(*b, "Action_Search_Dialog",    ACTIONS_SEARCH_DIALOG);

    return builder_to_string(*b);
}

Action_Build :: #type,distinct u32;  // holds the index of the build command in the list

ACTIONS_COMMON :: string.[
    "do_nothing",   // to disable key combinations (DEPRECATED)

    "quit",

    "open_another_editor_instance",

    "open_project",
    "switch_to_project",
    "close_project",
    "reload_workspace",

    "choose_theme",
    "edit_current_theme",

    "choose_language",

    "open_projects_directory",
    "open_global_config",
    "open_project_config",
    "show_default_config",

    "toggle_fullscreen",
    "build_panel_toggle",
    "build_panel_toggle_focus",
    "build_kill_running_command",
    "build_clear_output",
    "show_troubleshooting_info",

    "show_commands",
    "search_in_buffer",
    "search_in_buffer_dropdown_mode",
    "search_in_project",
    "go_to_line",

    "open_file_by_name",
    "navigate_to_file",
    "navigate_to_file_from_root",
    "switch_between_open_files",

    "copy",
    "cut",
    "paste",
    "undo",
    "redo",
    "select_word",
    "select_all",
    "swap_selections",
    "toggle_expand",
    "move_up",
    "move_up_fast",
    "move_up_one_page",
    "move_down",
    "move_down_fast",
    "move_down_one_page",
    "move_left",
    "move_left_by_character_type",
    "move_left_by_character_type_fast",
    "move_left_through_word_throttled",
    "move_left_through_word",
    "move_right",
    "move_right_by_character_type",
    "move_right_by_character_type_fast",
    "move_right_through_word_throttled",
    "move_right_through_word",
    "jump_to_line_start",
    "jump_to_line_end",
    "jump_to_file_start",
    "jump_to_file_end",
    "jump_to_matching_bracket",
    "delete_left_char",
    "delete_left_by_character_type",
    "delete_left_by_character_type_fast",
    "delete_left_through_word",
    "delete_left_through_word_throttled",
    "delete_right_char",
    "delete_right_by_character_type",
    "delete_right_by_character_type_fast",
    "delete_right_through_word",
    "delete_right_through_word_throttled",
    "delete_to_start_of_line",
    "delete_to_end_of_line",
    "cut_to_start_of_line",
    "cut_to_end_of_line",
    "increase_font_size",
    "decrease_font_size",
    "reset_font_size_to_default",
    "strip_trailing_whitespace",
    "close_all_editors",
    "close_current_editor",
    "close_other_editors",
    "close_other_editor",
    "close_left_editor",
    "close_right_editor",
    "close_dialog",
    "escape",

    "go_to_next_build_error",
    "go_to_next_build_error_on_the_side",
    "go_to_previous_build_error",
    "go_to_previous_build_error_on_the_side",
];

ACTIONS_EDITORS :: #run arrays_concat(ACTIONS_COMMON, string.[
    "select_word_or_create_another_cursor",
    "revert_select_word_or_create_another_cursor",
    "move_selection_to_next_word",
    "select_all_occurrences",
    "create_cursor_above",
    "create_cursor_below",
    "create_cursors_around",
    "align_cursors",
    "change_case_to_upper",
    "change_case_to_lower",
    "change_case_to_caps",
    "change_case_cycle",
    "add_cursors_to_line_ends",
    "add_cursors_to_line_starts",
    "duplicate_lines",
    "delete_line_and_go_up",
    "delete_line",
    "move_selected_lines_up",
    "move_selected_lines_down",
    "join_lines",
    "join_lines_no_spaces_in_between",
    "indent_or_go_to_next_tabstop",
    "unindent",
    "indent",
    "autoindent_region",
    "save",
    "save_as",
    "save_all",
    "move_current_file",
    "delete_current_file",
    "toggle_comment",
    "toggle_block_comment",
    "select_line",
    "scroll_viewport_up",
    "scroll_viewport_up_fast",
    "scroll_viewport_down",
    "scroll_viewport_down_fast",
    "scroll_viewport_left",
    "scroll_viewport_right",
    "move_up_to_empty_line",
    "move_down_to_empty_line",
    "center_viewport_on_cursor",
    "move_cursor_to_viewport_center",
    "remove_additional_cursors",
    "break_line",
    "new_line_below_without_breaking",
    "new_line_above_without_breaking",
    "switch_to_left_editor",
    "switch_to_right_editor",
    "switch_to_other_editor",
    "duplicate_editor",
    "duplicate_editor_to_the_left",
    "duplicate_editor_to_the_right",
    "move_editor_to_the_left",
    "move_editor_to_the_right",
    "create_new_file",
    "create_new_file_on_the_side",
    "move_to_previous_editor_history",
    "move_to_next_editor_history",
    "move_to_previous_buffer",
    "move_to_next_buffer",
    "toggle_line_wrap",
    "toggle_line_numbers",
    "copy_current_line_info",
    "indentation_detect_from_buffer_contents",
    "indentation_use_defaults_for_buffer",
    "indentation_convert_to_tabs_for_buffer",
    "indentation_convert_to_spaces_for_buffer",
    "reload_from_disk",
]);

ACTIONS_OPEN_FILE_DIALOG :: #run arrays_concat(ACTIONS_COMMON, string.[
    "open_entry_in_place",
    "open_entry_on_the_side",
    "open_entry_on_the_left",
    "open_entry_on_the_right",
    "open_entry_in_explorer",
    "open_directory",
    "pop_directory",
]);

ACTIONS_SEARCH_DIALOG :: #run arrays_concat(ACTIONS_COMMON, string.[
    "open_entry_in_place",
    "open_entry_on_the_side",
    "open_entry_on_the_left",
    "open_entry_on_the_right",
    "toggle_case_sensitive",
    "toggle_whole_word",
    "toggle_regex_search",
    "go_to_next_input",
    "go_to_previous_input",
]);


// This function just remembers that a hold action is now active, so that we can deactivate it on key release.
// The action itself is done elsewhere.
activate_hold_action :: (action: $Action_Type, event: Input.Event) {
    _, matched_mapping := map_event_to_action(event, Action_Type);  // we map it here again to avoid passing it in through multiple functions

    hold_action := Hold_Action.{ action_type = Action_Type, matched_mapping = matched_mapping };

    // NOTE: array_add_if_unique didn't work because it couldn't find the operator == for Hold_Actions.
    // I tried making it public but it didn't help.
    // array_add_if_unique(*active_hold_actions, hold_action);

    for active_hold_actions {
        if it == hold_action return;  // already there
    }
    array_add(*active_hold_actions, hold_action);
}

is_hold_action :: inline (action: Action_Editors) -> bool {
    return action == .scroll_viewport_up ||
           action == .scroll_viewport_up_fast ||
           action == .scroll_viewport_down ||
           action == .scroll_viewport_down_fast ||
           action == .scroll_viewport_left ||
           action == .scroll_viewport_right;
}


active_hold_actions: [..] Hold_Action;

// We have to get store the matched mapping because one action may be matched
// by multiple key combos, so when a key is released, in order to deactivate the action
// we need to check whether it actually belongs to the combo that activated the action!
Hold_Action :: struct {
    action_type: Type;
    matched_mapping: Key_Mapping;
}


#scope_file

operator == :: (a: Hold_Action, b: Hold_Action) -> bool {
    return memcmp(*a, *b, size_of(Hold_Action)) == 0;
}

