map_event_to_action :: (event: Input.Event, $Action: Type) -> Action, Key_Mapping {
    invalid_action  := cast(Action) 0xFFFF;
    invalid_mapping := Key_Mapping.{};
    
    if event.type != .KEYBOARD return invalid_action, invalid_mapping;
    if !event.key_pressed return invalid_action, invalid_mapping;
    
    keymap := get_keymap_for_action_type(Action);

    event_key_code := cast(u32) event.key_code;
    
    for keymap {
        if it.combo.key_code == event_key_code && it.combo.mods.packed == (event.modifier_flags.packed | it.combo.ignore.packed) {
            return cast(Action) it.action, it;
        }
    }
    return invalid_action, invalid_mapping;
}

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

map_key_release_to_hold_actions :: (event: Input.Event, $Action: Type) -> [] Action /* temporary storage */ {
    if event.type != .KEYBOARD || event.key_pressed return .[];
    
    actions: [..] Action;
    actions.allocator = temp;
    
    for active_hold_actions {
        if it.action_type != Action continue;
        combo := it.matched_mapping.combo;
        if combo.key_code == cast(u32) event.key_code || 
          (event.key_code == .SHIFT && combo.mods.shift_pressed && !combo.ignore.shift_pressed) ||
          (event.key_code == .CTRL  && combo.mods.ctrl_pressed  && !combo.ignore.ctrl_pressed)  ||
          (event.key_code == .ALT   && combo.mods.alt_pressed   && !combo.ignore.alt_pressed)
        {
            // We have released a button that's part of the key combo which activated this action
            array_add(*actions, cast(Action) it.matched_mapping.action);
        }
    }
    
    return actions;
}

get_first_matching_key_combo_from_action :: (action: Action_Common) -> [] string /* temp */ {
    keymap := get_keymap_for_action_type(type_of(action));
    combo: Key_Combo = ---;
    found := false;
    action_code := cast(u32) action;
    
    for mapping : keymap {
        if action_code == mapping.action {
            combo = mapping.combo;
            found = true;
            break;
        }
    }
    if !found return .[];
    
    keys: [..] string;
    keys.allocator = temp;
    array_reserve(*keys, 4);  // modifiers + key
    
    if combo.mods.ctrl_pressed  then array_add(*keys, "Ctrl");
    if combo.mods.alt_pressed   then array_add(*keys, "Alt");
    if combo.mods.shift_pressed then array_add(*keys, "Shift");
    
    key_name := keymap_map_key_code_to_string(combo.key_code);
    array_add(*keys, key_name);
    
    return keys;
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

#scope_export

Key_Mapping :: struct {
    combo:  Key_Combo;
    action: u32;  // NOTE: tried to use a union with actual enums here, but the compiler crashes @compilerbug
}

Key_Combo :: struct {
    key_code: u32;
    mods: Mods;  
    ignore: Mods;
} #no_padding;

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
    "increase_font_size",
    "decrease_font_size",
    "reset_font_size_to_default",
    "close_current_editor",
    "close_other_editor",
];

ACTIONS_EDITORS :: #run arrays_concat(ACTIONS_COMMON, string.[
    "select_word_or_create_another_cursor",
    "duplicate_lines",
    "delete_line_and_go_up",
    "delete_line",
    "delete_to_start_of_line",
    "delete_to_end_of_line",
    "move_selected_lines_up",
    "move_selected_lines_down",
    "join_lines",
    "join_lines_no_spaces_in_between",
    "indent_or_go_to_next_tabstop",
    "unindent",
    "indent",
    "save",
    "toggle_comment",
    "select_line",
    "scroll_viewport_up",
    "scroll_viewport_up_fast",
    "scroll_viewport_down",
    "scroll_viewport_down_fast",
    "scroll_viewport_left",
    "scroll_viewport_right",
    "move_up_to_empty_line",
    "move_down_to_empty_line",
    "move_cursor_to_viewport_center",
    "remove_additional_cursors",
    "break_line",
    "new_line_below_without_breaking",
    "new_line_above_without_breaking",
    "switch_to_left_editor",
    "switch_to_right_editor",
    "switch_to_other_editor",
    "duplicate_editor",
    "move_editor_to_the_left",
    "move_editor_to_the_right",
]);

ACTIONS_OPEN_FILE_DIALOG :: #run arrays_concat(ACTIONS_COMMON, string.[
    "close_dialog",
    "open_entry_in_place",
    "open_entry_on_the_side",
    "open_entry_on_the_left",
    "open_entry_on_the_right",
    "open_directory",
    "pop_directory",
]);

ACTIONS_SEARCH_DIALOG :: #run arrays_concat(ACTIONS_COMMON, string.[
    "close_dialog",
    "open_entry_in_place",
    "open_entry_on_the_side",
    "open_entry_on_the_left",
    "open_entry_on_the_right",
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