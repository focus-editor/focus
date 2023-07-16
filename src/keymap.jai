map_event_to_action :: (event: Input.Event, $Action: Type) -> Action, Key_Mapping {
    using key_sequence_input_state;

    invalid_action := cast(Action) 0xFFFF;
    invalid_mapping := Key_Mapping.{};

    if event.type != .KEYBOARD return invalid_action, invalid_mapping;
    if !event.key_pressed      return invalid_action, invalid_mapping;

    // Check for modifier keys being pressed by themselves; this shouldn't reset a key sequence that's in progress.
    key_combo_input_this_frame = event.key_code != .ALT && event.key_code != .CTRL && event.key_code != .SHIFT && event.key_code != .CMD && event.key_code != .META;

    keys_to_search := get_keymap_for_action_type(Action);
    if matches_for_current_key_sequence.count > 0  keys_to_search = matches_for_current_key_sequence;

    event_key_code := cast(u32) event.key_code;

    for key_mapping: keys_to_search {
        if current_key_sequence_length >= key_mapping.key_sequence.count  continue;
        if minimum_key_sequence_length > 0 && key_mapping.key_sequence.count < minimum_key_sequence_length  continue;

        key_sequence := key_mapping.key_sequence;
        combo := key_sequence[current_key_sequence_length];

        if combo.key_code == event_key_code && combo.mods.packed == (event.modifier_flags.packed | combo.ignore.packed) {
            if key_sequence.count == current_key_sequence_length + 1 {
                found_match = true;
                return cast(Action) key_mapping.action, key_mapping;
            } else {
                array_add(*new_matches_for_current_key_sequence, key_mapping);
                minimum_key_sequence_length = key_sequence.count;
                key_sequence_in_progress = true;
            }
        }
    }

    #if Action == Action_Open_File_Dialog {
        // Hard-coded case: When the Open File dialog is active, "/" or "\" opens a directory.
        if event.key_code == {
            case #char "/";  #through;
            case #char "\\"; return .open_directory, invalid_mapping;
        }
    }

    return invalid_action, invalid_mapping;
}

dump_key_mappings :: () {
    dump_keys :: (title: string, key_mapping: []Key_Mapping, action_type: Type) #expand {
        print("\n%\n", title);
        for keymap: key_mapping {
            for key_combo: keymap.key_sequence
                print("% %\n", key_combo_strings(key_combo), cast(action_type)keymap.action);
        }
    }
    dump_keys("File", config.keymap.open_file_dialog, Action_Open_File_Dialog);
    dump_keys("Search", config.keymap.search_dialog, Action_Search_Dialog);
    dump_keys("Editor", config.keymap.editors, Action_Editors);
    dump_keys("Common", config.keymap.common, Action_Common);
}


activate_hold_action :: (action: $Action_Type, event: Input.Event) {
    _, matched_mapping := map_event_to_action(event, Action_Type);  // we map it here again to avoid passing it in through multiple functions

    if matched_mapping.key_sequence.count != 1  return; // Don't support hold actions for multipart key sequences.

    hold_action := Hold_Action.{ action_type = Action_Type, matched_mapping = matched_mapping };

    // NOTE: array_add_if_unique didn't work because it couldn't find the operator == for Hold_Actions.
    // I tried making it public but it didn't help.
    // array_add_if_unique(*active_hold_actions, hold_action);

    for active_hold_actions {
        if it == hold_action return;  // already there
    }
    array_add(*active_hold_actions, hold_action);
}

map_key_release_to_hold_actions :: (event: Input.Event, $Action: Type) -> [] Action /* temporary storage */ {
    if event.type != .KEYBOARD || event.key_pressed return .[];

    actions: [..] Action;
    actions.allocator = temp;

    for active_hold_actions {
        if it.action_type != Action continue;
        combo := it.matched_mapping.key_sequence[0];

        if combo.key_code == cast(u32) event.key_code ||
          (event.key_code == .SHIFT && combo.mods.shift_pressed    && !combo.ignore.shift_pressed)    ||
          (event.key_code == .CTRL  && combo.mods.ctrl_pressed     && !combo.ignore.ctrl_pressed)     ||
          (event.key_code == .ALT   && combo.mods.alt_pressed      && !combo.ignore.alt_pressed)      ||
          (event.key_code == .CMD   && combo.mods.cmd_meta_pressed && !combo.ignore.cmd_meta_pressed)
        {
            // We have released a button that's part of the key combo which activated this action
            array_add(*actions, cast(Action) it.matched_mapping.action);
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

    return builder_to_string(*b, allocator = temp);
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
    } else {
        #assert(false, "In map_event_to_action, the passed action type is not supported.");
    }
}

active_hold_actions: [..] Hold_Action;

// We have to get store the matched mapping because one action may be matched
// by multiple key combos, so when a key is released, in order to deactivate the action
// we need to check whether it actually belongs to the combo that activated the action!
Hold_Action :: struct {
    action_type: Type;
    matched_mapping: Key_Mapping;
}

operator == :: (a: Hold_Action, b: Hold_Action) -> bool {
    return memcmp(*a, *b, size_of(Hold_Action)) == 0;
}

reset_key_sequence :: () {
    using key_sequence_input_state;
    array_reset_keeping_memory(*matches_for_current_key_sequence);
    minimum_key_sequence_length = 0;
    current_key_sequence_length = 0;
    key_sequence_in_progress = false;
}

#scope_export

start_key_sequence_handling :: () {
    using key_sequence_input_state;
    key_combo_input_this_frame = false;
    found_match = false;
    array_reset_keeping_memory(*new_matches_for_current_key_sequence);
}

end_key_sequence_handling :: () {
    using key_sequence_input_state;
    if new_matches_for_current_key_sequence.count > 0 { // Input occurred this frame, and we have a new list of key combo candidates.
        current_key_sequence_length += 1;
        array_reset_keeping_memory(*matches_for_current_key_sequence);
        array_add(*matches_for_current_key_sequence, ..new_matches_for_current_key_sequence);
    } else if key_combo_input_this_frame { // Input occurred this frame, but no candidates are left; reset the active key combo.
        reset_key_sequence();
    }

    if found_match  reset_key_sequence();
}

key_sequence_input_state: Key_Sequence_Input_State;

Key_Sequence_Input_State :: struct {
    matches_for_current_key_sequence: [..] Key_Mapping;
    new_matches_for_current_key_sequence: [..] Key_Mapping;
    current_key_sequence_length: int;
    minimum_key_sequence_length: int;
    key_sequence_in_progress: bool;
    key_combo_input_this_frame: bool;
    found_match: bool;
}

Key_Mapping :: struct {
    key_sequence: [] Key_Combo;
    action: u32;  // NOTE: tried to use a union with actual enums here, but the compiler crashes @compilerbug
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

ACTIONS_COMMON :: string.[
    "do_nothing",   // to disable key combinations

    "quit",

    "open_project",
    "switch_to_project",  // same as open_project, renaming for consistency
    "open_projects_directory",
    "open_global_config",
    "open_project_config",
    "open_error_log",

    "show_commands",
    "search_in_buffer",
    "search_in_buffer_dropdown_mode",
    "search_in_project",
    "go_to_line",
    "show_open_file_dialog_in_search_mode",
    "show_open_file_dialog_in_navigate_mode",
    "show_open_file_dialog_in_navigate_mode_from_root",
    "copy",
    "cut",
    "paste",
    "undo",
    "redo",
    "select_word",
    "select_all",
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
    "close_current_editor",
    "close_other_editor",
    "close_left_editor",
    "close_right_editor",

    "dump_key_mappings",
];

ACTIONS_EDITORS :: #run arrays_concat(ACTIONS_COMMON, string.[
    "select_word_or_create_another_cursor",
    "create_cursor_above",
    "create_cursor_below",
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
    "save",
    "save_all",
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
]);

ACTIONS_OPEN_FILE_DIALOG :: #run arrays_concat(ACTIONS_COMMON, string.[
    "close_dialog",
    "open_entry_in_place",
    "open_entry_on_the_side",
    "open_entry_on_the_left",
    "open_entry_on_the_right",
    "open_entry_in_explorer",
    "open_directory",
    "pop_directory",
]);

ACTIONS_SEARCH_DIALOG :: #run arrays_concat(ACTIONS_COMMON, string.[
    "close_dialog",
    "open_entry_in_place",
    "open_entry_on_the_side",
    "open_entry_on_the_left",
    "open_entry_on_the_right",
    "toggle_case_sensitive",
    "toggle_whole_word",
]);

// Used for testing strings in parser
Keymap_Action_Strings :: #run -> Table(string, void) {
    table: Table(string, void);
    nothing: void;

    for ACTIONS_EDITORS             table_set(*table, it, nothing);
    for ACTIONS_OPEN_FILE_DIALOG    table_set(*table, it, nothing);
    for ACTIONS_SEARCH_DIALOG       table_set(*table, it, nothing);

    return table;
}
