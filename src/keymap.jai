INVALID_KEYMAP_ACTION :: 0xFFFF;

map_event_to_action :: (event: Input.Event, $Action: Type) -> Action, Key_Mapping {
    invalid_action := cast(Action) INVALID_KEYMAP_ACTION;
    if event.type != .KEYBOARD || !event.key_pressed return invalid_action, .{};

    using key_sequence_input;

    key_mappings := get_keymap_for_action_type(Action);
    if potential_multipart_matches {
        filtered_mappings: [..] Key_Mapping;
        filtered_mappings.allocator = temp;
        for potential_multipart_matches {
            if it.action_type == Action then array_add(*filtered_mappings, it.mapping);
        }
        key_mappings = filtered_mappings;
    }

    for key_mappings {
        if active_sequence_length >= it.key_sequence.count continue;

        combo := it.key_sequence[active_sequence_length];

        if combo.key_code == xx event.key_code && combo.mods.packed == (event.modifier_flags.packed | combo.ignore.packed) {
            if it.key_sequence.count == active_sequence_length + 1 {
                // print("Found match. Action type: %. Action: %\n", Action, cast(Action) it.action);
                return cast(Action) it.action, it;
            } else {
                // We have to remember the types of potential matches,
                // otherwise we might accidentally trigger the wrong one
                array_add(*new_multipart_matches, Typed_Key_Mapping.{ mapping = it, action_type = Action });
            }
        }
    }

    #if Action == Action_Open_File_Dialog {
        // Hard-coded case: When the Open File dialog is active, "/" or "\" opens a directory.
        if event.key_code == {
            case #char "/";  #through;
            case #char "\\"; return .open_directory, .{};
        }
    }

    return invalid_action, .{};
}

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

map_key_release_to_hold_actions :: (event: Input.Event, $Action: Type) -> [] Action /* temporary storage */ {
    if event.type != .KEYBOARD || event.key_pressed return .[];

    actions: [..] Action;
    actions.allocator = temp;

    for active_hold_actions {
        if it.action_type != Action continue;
        combo := it.matched_mapping.key_sequence[it.matched_mapping.key_sequence.count-1];

        if combo.key_code == cast(u32) event.key_code ||
          (event.key_code == .SHIFT && combo.mods.shift_pressed    && !combo.ignore.shift_pressed)    ||
          (event.key_code == .CTRL  && combo.mods.ctrl_pressed     && !combo.ignore.ctrl_pressed)     ||
          (event.key_code == .ALT   && combo.mods.alt_pressed      && !combo.ignore.alt_pressed)      ||
          (event.key_code == .CMD   && combo.mods.cmd_meta_pressed && !combo.ignore.cmd_meta_pressed)
        {
            // We have released a button that's part of the key combo which activated this action
            array_add(*actions, cast(Action) it.matched_mapping.action);
            remove it;  // actually remove the action from the active actions
        }
    }

    return actions;
}

get_first_matching_key_sequence_from_action :: (action: $T) -> [][] string /* temp */ {
    keymap := get_keymap_for_action_type(type_of(action));
    key_sequence: [] Key_Combo = ---;
    found := false;
    action_code := cast(u32) action;

    for mapping: keymap {
        if action_code == mapping.action {
            key_sequence = mapping.key_sequence;
            found = true;
            break;
        }
    }
    if !found return .[];

    key_sequence_parts: [..][] string;
    key_sequence_parts.allocator = temp;
    for key_sequence  array_add(*key_sequence_parts, key_combo_strings(it));
    return key_sequence_parts;
}

key_combo_strings :: (combo: Key_Combo) -> [] string /* temp */ {
    keys: [..] string;
    keys.allocator = temp;
    array_reserve(*keys, 5);  // modifiers + key

    #if OS == .LINUX {
        if combo.mods.cmd_meta_pressed then array_add(*keys, "Meta");
    }
    if combo.mods.ctrl_pressed  then array_add(*keys, "Ctrl");
    if combo.mods.alt_pressed   then array_add(*keys, "Alt");
    if combo.mods.shift_pressed then array_add(*keys, "Shift");
    #if OS == .MACOS {
        if combo.mods.cmd_meta_pressed then array_add(*keys, "Cmd");
    }

    key_name := keymap_map_key_code_to_string(combo.key_code);
    array_add(*keys, key_name);
    return keys;
}

key_sequence_matches :: (s1: [] Key_Combo, s2: [] Key_Combo) -> bool {
    for 0 .. min(s1.count, s2.count)-1 {
        c1, c2 := s1[it], s2[it];
        ignore_mask := c1.ignore.packed | c2.ignore.packed;
        if (c1.key_code != c2.key_code) || (c1.mods.packed | ignore_mask != c2.mods.packed | ignore_mask) return false;
    }
    return true;
}

key_sequence_for_action_as_string :: (action: $T) -> string /* temp */ {
    key_sequence := get_first_matching_key_sequence_from_action(action);
    if !key_sequence return "";

    b: String_Builder;
    b.allocator = temp;

    for combo: key_sequence {
        for combo {
            print_to_builder(*b, "%", it);
            if it_index < combo.count - 1  print_to_builder(*b, " + ");
        }
        if it_index < key_sequence.count - 1  print_to_builder(*b, "  ");
    }

    return builder_to_string(*b,, allocator = temp);
}

key_sequence_input_process_event :: (event: Input.Event, handled: bool) {
    using key_sequence_input;

    // Modifier keys pressed by themselves should't reset key sequence
    key_combo_event := event.type == .KEYBOARD && event.key_pressed &&
                       event.key_code != .ALT && event.key_code != .CTRL && event.key_code != .SHIFT &&
                       event.key_code != .CMD && event.key_code != .META;

    if handled || (key_combo_event && !new_multipart_matches) || active_widget != active_global_widget {
        // Reset current key sequence
        array_reset_keeping_memory(*potential_multipart_matches);
        array_reset_keeping_memory(*new_multipart_matches);
        active_sequence_length = 0;
    }

    if new_multipart_matches {
        // Starting or continuing a multipart combo
        active_sequence_length += 1;
        array_reset_keeping_memory(*potential_multipart_matches);
        array_add(*potential_multipart_matches, ..new_multipart_matches);
        array_reset_keeping_memory(*new_multipart_matches);
    }

    // Remember the current active widget. If it changes as a result of an event,
    // we want to reset any key sequence in progress, even if that event wasn't a keyboard event
    active_widget = active_global_widget;
}

key_sequence_input_in_progress :: inline () -> bool {
    return key_sequence_input.potential_multipart_matches.count > 0;
}

#scope_file

get_keymap_for_action_type :: ($Action: Type) -> [] Key_Mapping #expand {
    #if Action == Action_Common {
        return config.keymap.common;
    } else #if Action == Action_Editors {
        return config.keymap.editors;
    } else #if Action == Action_Open_File_Dialog {
        return config.keymap.open_file_dialog;
    } else #if Action == Action_Search_Dialog {
        return config.keymap.search_dialog;
    } else #if Action == Action_Build {
        return config.build.keymap;
    } else {
        #assert(false, "In map_event_to_action, the passed action type is not supported.");
    }
}

operator == :: (a: Hold_Action, b: Hold_Action) -> bool {
    return memcmp(*a, *b, size_of(Hold_Action)) == 0;
}

#scope_export

key_sequence_input: struct {
    active_sequence_length := 0;
    potential_multipart_matches: [..] Typed_Key_Mapping;
    new_multipart_matches:       [..] Typed_Key_Mapping;
    active_widget: Active_Global_Widget = .editors;
}

Key_Mapping :: struct {
    key_sequence: [] Key_Combo;
    action: u32;  // NOTE: tried to use a union with actual enums here, but the compiler crashes @compilerbug
}

Typed_Key_Mapping :: struct {
    mapping: Key_Mapping;
    action_type: Type;
}

Key_Combo :: struct {
    key_code: u32;
    mods: Mods;
    ignore: Mods;
}

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
    "do_nothing",   // to disable key combinations (DEPRECATED). TODO: auto-remove when we have a config migration system

    "quit",

    "open_another_editor_instance",

    "open_project",
    "switch_to_project",
    "close_project",

    "choose_theme",
    "edit_current_theme",

    "choose_language",

    "open_projects_directory",
    "open_global_config",
    "open_project_config",
    "show_default_config",

    "toggle_fullscreen",
    "toggle_build_panel",
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
    "move_left_by_word",
    "move_left_by_word_ends",
    "move_right",
    "move_right_by_word",
    "move_right_by_word_ends",
    "jump_to_line_start",
    "jump_to_line_end",
    "jump_to_file_start",
    "jump_to_file_end",
    "jump_to_matching_bracket",
    "delete_left_char",
    "delete_right_char",
    "delete_word_left",
    "delete_word_right",
    "delete_word_left_no_underscore",
    "delete_word_right_no_underscore",
    "delete_to_start_of_line",
    "delete_to_end_of_line",
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
    "select_all_occurrences",
    "create_cursor_above",
    "create_cursor_below",
    "align_cursors",
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
]);


active_hold_actions: [..] Hold_Action;

// We have to get store the matched mapping because one action may be matched
// by multiple key combos, so when a key is released, in order to deactivate the action
// we need to check whether it actually belongs to the combo that activated the action!
Hold_Action :: struct {
    action_type: Type;
    matched_mapping: Key_Mapping;
}
