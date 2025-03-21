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

key_sequence_input_process_event :: (event: Input.Event, handled: bool) -> handled: bool {
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
        handled = true;
    }

    // Remember the current active widget. If it changes as a result of an event,
    // we want to reset any key sequence in progress, even if that event wasn't a keyboard event
    active_widget = active_global_widget;

    return handled;
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
