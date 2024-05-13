// We have a crappy parser here which only does some very superficial parsing.
// The reason is because it's much simpler than keeping valid parsers for each historical version.

maybe_migrate_config :: (name: string, file_data: string) -> migrated: bool, modified_data := "" {
    trimmed_data := trim_left(file_data, " \t\n\r");  // skip empty lines, otherwise the handler will crash!
    start_from_memory(*handler, name, name, trimmed_data);
    if handler.failed return false;
    if handler.version >= CURRENT_CONFIG_VERSION || handler.version <= 0 return false;

    is_global_config := contains_nocase(name, "global.focus-config");

    assume_section := "";
    if ends_with_nocase(name, ".focus-theme") then assume_section = "style";

    // Do one full pass to collect information, not touching anything
    config_info: Config_Info;
    {
        config_info.version = handler.version;

        current_section := assume_section;
        current_subsection: string;

        while true {
            line, found := consume_next_line(*handler);
            if !found break;

            line_start_offset := line.data - trimmed_data.data;

            if begins_with(line, "[[") && ends_with(line, "]]") {
                current_section = trim(line, " \t[]");
            } else if begins_with(line, "[") && ends_with(line, "]") {
                current_subsection = trim(line, " \t[]");  // NOTE: doesn't validate and it's OK
            }

            if current_section == {
                case "settings";
                    setting_name, setting_value := break_by_spaces(line);
                    setting_name = trim_right(setting_name, ":");

                    config_info.last_setting_offset = line_start_offset;
                    table_set(*config_info.settings_present, setting_name, true);

                case "style";
                    if current_subsection == "colors" {
                        color_name, color_value := break_by_spaces(line);
                        color_name = trim_right(color_name, ":");

                        config_info.last_color_offset = line_start_offset;

                        for RENAMED_COLORS {
                            if color_name == it.old_name || color_name == it.new_name {
                                table_set(*config_info.colors_present, it.old_name, color_value);
                                table_set(*config_info.colors_present, it.new_name, color_value);
                            }
                        }
                        for ADDED_COLORS {
                            if color_name == it.name then table_set(*config_info.colors_present, color_name, color_value);
                        }
                    }
                case "keymap";
                    success, key_sequence_str, action_name := split_from_right_by_any(line, " \t");
                    if success {
                        key := tprint("%_%", current_subsection, action_name);
                        table_set(*config_info.keybinds_present, key, true);
                    }
                    if current_subsection == "common"  then config_info.last_common_keybind_offset  = line_start_offset;
                    if current_subsection == "editors" then config_info.last_editors_keybind_offset = line_start_offset;
            }
        }
    }

    // Now do a modification pass
    modified_data: [..] u8;
    {
        array_resize(*modified_data, trimmed_data.count, initialize = false);
        focus_memcpy(modified_data.data, trimmed_data.data, trimmed_data.count);

        // Insert new settings
        if config_info.last_setting_offset >= 0 && is_global_config {
            insert_offset := config_info.last_setting_offset + get_line_length(modified_data, config_info.last_setting_offset);
            inserted_bytes := 0;

            there_are_settings_to_add := false;
            for added : ADDED_SETTINGS {
                if !table_contains(*config_info.settings_present, added.name) && valid_version(added.version, config_info.version) { there_are_settings_to_add = true; break; }
            }
            if there_are_settings_to_add {
                heading := tprint("\n# Added after migration to version [%]\n", CURRENT_CONFIG_VERSION);
                array_insert_bytes_at(*modified_data, insert_offset + inserted_bytes, cast([]u8) heading);
                inserted_bytes += heading.count;
            }
            for added : ADDED_SETTINGS {
                if !table_contains(*config_info.settings_present, added.name) && valid_version(added.version, config_info.version) {
                    padding := get_tmp_spaces(SETTING_VALUES_INDENT - added.name.count - 1);
                    setting := tprint("%1:%2%3\n", added.name, padding, added.value);
                    array_insert_bytes_at(*modified_data, insert_offset + inserted_bytes, cast([]u8) setting);
                    inserted_bytes += setting.count;
                }
            }

            // Adjust the offsets we remembered
            if config_info.last_color_offset           >= config_info.last_setting_offset then config_info.last_color_offset           += inserted_bytes;
            if config_info.last_common_keybind_offset  >= config_info.last_setting_offset then config_info.last_common_keybind_offset  += inserted_bytes;
            if config_info.last_editors_keybind_offset >= config_info.last_setting_offset then config_info.last_editors_keybind_offset += inserted_bytes;
        }

        // Insert new colors
        if config_info.last_color_offset >= 0 {
            insert_offset := config_info.last_color_offset + get_line_length(modified_data, config_info.last_color_offset);
            inserted_bytes := 0;

            there_are_colors_to_add := false;
            for added : ADDED_COLORS {
                if !table_contains(*config_info.colors_present, added.name) && valid_version(added.version, config_info.version) { there_are_colors_to_add = true; break; }
            }
            if there_are_colors_to_add {
                heading := tprint("\n# Added after migration to version [%]\n", CURRENT_CONFIG_VERSION);
                array_insert_bytes_at(*modified_data, insert_offset + inserted_bytes, cast([]u8) heading);
                inserted_bytes += heading.count;
            }
            for added : ADDED_COLORS {
                if !table_contains(*config_info.colors_present, added.name) && valid_version(added.version, config_info.version) {
                    value := added.default;
                    if added.value_from {
                        source_value, success := table_find(*config_info.colors_present, added.value_from);
                        if success && source_value then value = source_value;
                    }
                    padding := get_tmp_spaces(COLOR_VALUES_INDENT - added.name.count - 1);
                    color := tprint("%1:%2%3\n", added.name, padding, value);
                    array_insert_bytes_at(*modified_data, insert_offset + inserted_bytes, cast([]u8) color);
                    inserted_bytes += color.count;
                }
            }

            // Adjust the offsets we remembered
            if config_info.last_common_keybind_offset  >= config_info.last_color_offset then config_info.last_common_keybind_offset  += inserted_bytes;
            if config_info.last_editors_keybind_offset >= config_info.last_color_offset then config_info.last_editors_keybind_offset += inserted_bytes;
        }

        // Insert new keybinds into the editors section
        if config_info.last_editors_keybind_offset >= 0 {
            SUBSECTION :: "editors";
            insert_offset := config_info.last_editors_keybind_offset + get_line_length(modified_data, config_info.last_editors_keybind_offset);
            inserted_bytes := 0;

            // Maybe print a heading
            for added : ADDED_KEYBINDS {
                if added.subsection != SUBSECTION continue;
                if !table_contains(*config_info.keybinds_present, tprint("%_%", SUBSECTION, added.action)) && valid_version(added.version, config_info.version) {
                    heading := tprint("\n# Added after migration to version [%]\n", CURRENT_CONFIG_VERSION);
                    array_insert_bytes_at(*modified_data, insert_offset + inserted_bytes, cast([]u8) heading);
                    inserted_bytes += heading.count;
                    break;
                }
            }

            for added : ADDED_KEYBINDS {
                if added.subsection != SUBSECTION continue;
                if !table_contains(*config_info.keybinds_present, tprint("%_%", SUBSECTION, added.action)) && valid_version(added.version, config_info.version) {
                    key_combo := added.key_combo;
                    if OS == .MACOS then key_combo = added.key_combo_mac;
                    padding := get_tmp_spaces(KEYBINDS_INDENT - key_combo.count);
                    key_binding := tprint("%1%2%3\n", key_combo, padding, added.action);
                    array_insert_bytes_at(*modified_data, insert_offset + inserted_bytes, cast([]u8) key_binding);
                    inserted_bytes += key_binding.count;
                }
            }

            // Adjust the offsets we remembered
            if config_info.last_common_keybind_offset  >= config_info.last_editors_keybind_offset then config_info.last_common_keybind_offset  += inserted_bytes;
        }

        // Insert new keybinds into the common section
        if config_info.last_common_keybind_offset >= 0 {
            SUBSECTION :: "common";
            insert_offset := config_info.last_common_keybind_offset + get_line_length(modified_data, config_info.last_common_keybind_offset);
            inserted_bytes := 0;

            // Maybe print a heading
            for added : ADDED_KEYBINDS {
                if added.subsection != SUBSECTION continue;
                if !table_contains(*config_info.keybinds_present, tprint("%_%", SUBSECTION, added.action)) && valid_version(added.version, config_info.version) {
                    heading := tprint("\n# Added after migration to version [%]\n", CURRENT_CONFIG_VERSION);
                    array_insert_bytes_at(*modified_data, insert_offset + inserted_bytes, cast([]u8) heading);
                    inserted_bytes += heading.count;
                    break;
                }
            }

            for added : ADDED_KEYBINDS {
                if added.subsection != SUBSECTION continue;
                if !table_contains(*config_info.keybinds_present, tprint("%_%", SUBSECTION, added.action)) && valid_version(added.version, config_info.version) {
                    key_combo := added.key_combo;
                    if OS == .MACOS then key_combo = added.key_combo_mac;
                    padding := get_tmp_spaces(KEYBINDS_INDENT - key_combo.count);
                    key_binding := tprint("%1%2%3\n", key_combo, padding, added.action);
                    array_insert_bytes_at(*modified_data, insert_offset + inserted_bytes, cast([]u8) key_binding);
                    inserted_bytes += key_binding.count;
                }
            }
        }

        // Bump version from [whatever] to [current]
        assert(begins_with(cast(string) modified_data, tprint("[%]", config_info.version)));
        new_version_number := tprint("[%]", CURRENT_CONFIG_VERSION);
        focus_memcpy(modified_data.data, new_version_number.data, new_version_number.count);

        current_section := assume_section;
        current_subsection: string;
        offset_difference := 0;  // difference between original and modified, in bytes

        data_with_insertions := copy_temporary_string(cast(string) modified_data);

        // Do replacements and deletions
        start_from_memory(*handler, name, name, data_with_insertions);

        while true {
            line, found := consume_next_line(*handler);
            if !found break;

            line_start_offset := line.data - data_with_insertions.data + offset_difference;

            if begins_with(line, "[[") && ends_with(line, "]]") {
                current_section = trim(line, " \t[]");
                current_subsection = "";
                continue;
            }
            if begins_with(line, "[") && ends_with(line, "]") {
                current_subsection = trim(line, " \t[]");  // NOTE: doesn't validate and it's OK

                if current_subsection == "user interface" {
                    // Remove the subsection, but leave everything that was there intact
                    offset_difference += replace_line(*modified_data, line_start_offset, "[fonts]\n");
                    current_subsection = "";
                }
                continue;
            }

            if current_section == {
                case "settings";
                    setting_name, setting_value := break_by_spaces(line);
                    setting_name = trim_right(setting_name, ":");

                    // TODO: check version when we have version [3]
                    for removed : REMOVED_SETTINGS {
                        if setting_name == removed.name {
                            offset_difference += replace_line(*modified_data, line_start_offset, "");
                        }
                    }

                case "style";
                    if current_subsection == "colors" {
                        color_name, color_value := break_by_spaces(line);
                        color_name = trim_right(color_name, ":");
                        #insert -> string {
                            b: String_Builder;
                            append(*b, "if color_name == {\n");
                            for RENAMED_COLORS {
                                code := #string JAI
                                    case "%1";
                                        padding  := get_tmp_spaces(COLOR_VALUES_INDENT - "%2".count - 1);
                                        new_line := tprint("%2:%%1%%2\n", padding, color_value);
                                        offset_difference += replace_line(*modified_data, line_start_offset, new_line);
                                JAI
                                print_to_builder(*b, code, it.old_name, it.new_name);
                            }
                            append(*b, "}\n");
                            return builder_to_string(*b);
                        }
                    }

                case "keymap";
                    success, key_sequence_str, action_name := split_from_right_by_any(line, " \t");
                    if success {
                         if current_subsection == "editors" {
                            if action_name == "remove_additional_cursors" && to_lower_copy_new(trim(key_sequence_str),, allocator = temp) == "escape" {
                                // Rebind action to "escape"
                                new_binding := tprint("Escape                      escape\n");
                                offset_difference += replace_line(*modified_data, line_start_offset, new_binding);
                            }
                        }
                        for RENAMED_KEYBINDS {
                            if action_name == it.old_name && (!it.subsection || it.subsection == current_subsection) {
                                action_offset := action_name.data - data_with_insertions.data + offset_difference;
                                offset_difference += replace_line(*modified_data, action_offset, tprint("%\n", it.new_name));
                            }
                        }
                    }
            }
        }
    }

    return true, cast(string) modified_data;
}


#scope_file

valid_version :: inline (added_version: int, config_version: int) -> bool {
    return added_version <= CURRENT_CONFIG_VERSION && added_version > config_version;
}

replace_line :: (buffer: *[..] u8, line_start_offset: s64, str: string) -> difference: s64 {
    length := get_line_length(buffer.*, line_start_offset);
    // print("Replacing '%' with '%'\n", to_string(buffer.data + line_start_offset, length), str);
    array_delete_bytes(buffer, line_start_offset, length);
    array_insert_bytes_at(buffer, line_start_offset, cast([]u8) str);
    return str.count - length;
}

get_line_length :: (buffer: [..] u8, line_start_offset: s64) -> length: s64 {
    for i : line_start_offset .. buffer.count-1 {
        if buffer[i] == #char "\n" return i + 1 - line_start_offset;  // including the newline
    }
    return buffer.count - line_start_offset;
}

ADDED_SETTINGS :: Added_Setting.[
    .{ 2, "build_panel_width_percent",                          "50" },
    .{ 2, "build_panel_height_percent",                         "50" },
    .{ 2, "build_panel_stays_in_one_place",                     "false  # if false, the build panel will flip to the inactive pane in two pane layouts" },
    .{ 2, "build_panel_line_wrap_always_on",                    "true" },
    .{ 2, "highlight_line_with_cursor",                         "false" },
    .{ 2, "draw_indent_guides",                                 "false" },
    .{ 2, "auto_surround_with_brackets_and_quotes",             "false" },
    .{ 2, "scroll_beyond_last_line",                            "true" },
    .{ 2, "show_cursors_off_screen",                            "true" },
    .{ 2, "persist_local_search_results",                       "false  # if true, search results will stay highlighted and you have to dismiss them using the `escape` action" },

    .{ 3, "save_current_buffer_on_build",                       "false" },
    .{ 3, "save_all_file_backed_buffers_on_build",              "false" },
    .{ 3, "disable_viewport_chasing_cursor_near_the_edge",      "false  # if true, the viewport will not scroll smoothly to cursor when you move the cursor outside it by small amounts" },
    .{ 3, "show_selected_text_length",                          "false" },

    .{ 4, "window_width",                                       "-1" },
    .{ 4, "window_height",                                      "-1" },
    .{ 4, "insert_final_newline_on_save",                       "false" },
    .{ 4, "status_bar_position",                                "bottom" },
];

REMOVED_SETTINGS :: Removed_Setting.[
    .{ 2, "max_entries_in_open_file_dialog" },
];

SETTING_VALUES_INDENT :: #run -> int {
    length := 0;
    for ADDED_SETTINGS {
        length = max(length, it.name.count);
    }
    return length + 2;
}

RENAMED_COLORS :: Renamed_Color.[
    .{ 2, "background",           "background0" },
    .{ 2, "background_dark",      "background1" },
    .{ 2, "background_highlight", "background2" },
    .{ 2, "background_light",     "background3" },
    .{ 2, "background_bright",    "background4" },

    .{ 4, "code_string",          "code_string_literal" },
];

ADDED_COLORS :: Added_Color.[
    .{ 2, "code_warning",                     "",                       "E4D97DFF" },
    .{ 2, "region_scope_export",              "background0",            "15212AFF" },
    .{ 2, "region_scope_file",                "background0",            "131C22FF" },
    .{ 2, "region_scope_module",              "background0",            "1A2831FF" },
    .{ 2, "region_header",                    "",                       "1A5152FF" },
    .{ 2, "region_success",                   "",                       "226022FF" },
    .{ 2, "region_warning",                   "",                       "986032FF" },
    .{ 2, "region_error",                     "",                       "772222FF" },
    .{ 2, "build_panel_background",           "background3",            "1A2831FF" },
    .{ 2, "build_panel_scrollbar",            "scrollbar",              "33CCCC19" },
    .{ 2, "build_panel_scrollbar_hover",      "scrollbar_hover",        "33CCCC4C" },
    .{ 2, "build_panel_scrollbar_background", "scrollbar_background",   "10191F4C" },
    .{ 2, "build_panel_title_bar",            "",                       "1C303AFF" },

    .{ 3, "region_heredoc",                   "background1",            "090e12FF" },

    .{ 4, "code_invalid",                     "code_error",             "FF0000FF" },
    .{ 4, "code_multiline_string",            "code_string_literal",    "D4BC7DFF" },
    .{ 4, "code_raw_string",                  "code_string_literal",    "D4BC7DFF" },
    .{ 4, "code_char_literal",                "code_string_literal",    "D4BC7DFF" },
    .{ 4, "code_identifier",                  "code_default",           "BFC9DBFF" },
    .{ 4, "code_note",                        "code_operation",         "E0AD82FF" },
    .{ 4, "code_number",                      "code_value",             "D699B5FF" },
    .{ 4, "code_multiline_comment",           "code_comment",           "87919DFF" },
    .{ 4, "code_modifier",                    "code_keyword",           "E67D74FF" },
    .{ 4, "code_attribute",                   "code_keyword",           "E67D74FF" },
    .{ 4, "code_enum_variant",                "code_default",           "BFC9DBFF" },
    .{ 4, "code_macro",                       "code_operation",         "E0AD82FF" },
    .{ 4, "code_builtin_variable",            "code_value",             "D699B5FF" },
    .{ 4, "code_builtin_function",            "code_operation",         "E0AD82FF" },
    .{ 4, "code_builtin_exception",           "code_operation",         "E0AD82FF" },
    .{ 4, "code_directive",                   "code_keyword",           "E67D74FF" },
    .{ 4, "code_directive_modifier",          "code_keyword",           "E67D74FF" },
    .{ 4, "code_header",                      "code_keyword",           "E67D74FF" },
    .{ 4, "code_header2",                     "code_operation",         "E0AD82FF" },
    .{ 4, "code_header3",                     "code_operation",         "E0AD82FF" },
    .{ 4, "code_header4",                     "code_operation",         "E0AD82FF" },
    .{ 4, "code_header5",                     "code_operation",         "E0AD82FF" },
    .{ 4, "code_header6",                     "code_operation",         "E0AD82FF" },
];

COLOR_VALUES_INDENT :: #run -> int {
    length := 0;
    for RENAMED_COLORS  length = max(length, it.old_name.count);
    for RENAMED_COLORS  length = max(length, it.new_name.count);
    for ADDED_COLORS    length = max(length, it.name.count);
    return max(length, 40);  // 40 is based on the current indent, but might get longer later if we have longer names
}

ADDED_KEYBINDS :: Added_Keybind.[
    .{ 2, "editors", "add_cursors_to_line_ends",        "Alt-Shift-I",      "Alt-Shift-I"      },
    .{ 2, "editors", "add_cursors_to_line_starts",      "Alt-Shift-Ctrl-I", "Alt-Shift-Ctrl-I" },
    .{ 2, "editors", "align_cursors",                   "Alt-A",            "Alt-Cmd-A"        },
    .{ 2, "editors", "select_all_occurrences",          "Ctrl-Shift-A",     "Cmd-Shift-A"      },
    .{ 2, "common",  "toggle_build_panel",              "Ctrl-B",           "Cmd-B"            },
    .{ 2, "common",  "toggle_fullscreen",               "F11",              "F11"              },
    .{ 2, "common",  "switch_between_open_files",       "Ctrl-Tab",         "Ctrl-Tab"         },

    .{ 3, "common",  "open_another_editor_instance",              "Ctrl-Shift-Alt-N",   "Cmd-Shift-Alt-N" },
    .{ 3, "common",  "go_to_next_build_error",                    "F8",                 "F8"              },
    .{ 3, "common",  "go_to_next_build_error_on_the_side",        "Ctrl-F8",            "Cmd-F8"          },
    .{ 3, "common",  "go_to_previous_build_error",                "Shift-F8",           "Shift-F8"        },
    .{ 3, "common",  "go_to_previous_build_error_on_the_side",    "Shift-Ctrl-F8",      "Shift-Cmd-F8"    },
];

RENAMED_KEYBINDS :: Renamed_Keybind.[
    .{ 2, "",  "show_open_file_dialog_in_search_mode",              "open_file_by_name"          },
    .{ 2, "",  "show_open_file_dialog_in_navigate_mode",            "navigate_to_file"           },
    .{ 2, "",  "show_open_file_dialog_in_navigate_mode_from_root",  "navigate_to_file_from_root" },
    .{ 2, "",  "show_open_file_dialog_in_open_editors_mode",        "switch_between_open_files"  },
];

KEYBINDS_INDENT :: 28;

handler: Text_File_Handler;

Config_Info :: struct {
    version: int;

    settings_present: Table(string, bool);  // e.g. build_panel_width_percent -> true means it's present
    colors_present: Table(string, string);  // e.g. code_warning -> E4D97DFF (store a value we've seen)
    keybinds_present: Table(string, bool);

    last_setting_offset := -1;
    last_color_offset   := -1;
    last_common_keybind_offset  := -1;
    last_editors_keybind_offset := -1;
};

Added_Setting :: struct {
    version: int;
    name:    string;
    value:   string;
}

Removed_Setting :: struct {
    version: int;
    name:    string;
}

Added_Color :: struct {
    version:    int;
    name:       string;
    value_from: string;
    default:    string;
}

Renamed_Color :: struct {
    version:   int;
    old_name:  string;
    new_name:  string;
}

Added_Keybind :: struct {
    version:    int;
    subsection: string;
    action:     string;
    key_combo:  string;
    key_combo_mac: string;
}

Renamed_Keybind :: struct {
    version:    int;
    subsection: string;
    old_name:   string;
    new_name:   string;
}


// ================================= TESTS ====================================

RUN_TESTS :: false;

// Yes we do unit tests now! Don't you dare submit a PR without tests and 100% coverage.
// Also your code must comply with the SOLID principles. Are we real programmers or what?

#if RUN_TESTS #run,stallable {
    run_test("Settings migration [1] to [4]",   "global.focus-config",  SETTINGS_1_TO_4,               SETTINGS_1_TO_4_EXPECTED);
    run_test("Settings migration [2] to [4]",   "global.focus-config",  SETTINGS_2_TO_4,               SETTINGS_2_TO_4_EXPECTED);
    run_test("Project settings [1] to [4]",     "project.focus-config", PROJECT_SETTINGS_1_TO_4,       PROJECT_SETTINGS_1_TO_4_EXPECTED);
    run_test("Сolors [1] to [4]",               "global.focus-config",  COLORS_1_TO_4,                 COLORS_1_TO_4_EXPECTED);
    run_test("Сolors [2] to [4]",               "global.focus-config",  COLORS_2_TO_4,                 COLORS_2_TO_4_EXPECTED);
    run_test("Settings and colors [1] to [4]",  "global.focus-config",  COLORS_AND_SETTINGS_1_TO_4,    COLORS_AND_SETTINGS_1_TO_4_EXPECTED);
    run_test("Keybinds [1] to [4]",             "global.focus-config",  KEYBINDS_1_TO_4,               KEYBINDS_1_TO_4_EXPECTED);
    run_test("Keybinds [2] to [4]",             "global.focus-config",  KEYBINDS_2_TO_4,               KEYBINDS_2_TO_4_EXPECTED);
    run_test("Theme [1] to [4]",                "nord.focus-theme",     THEME_1_TO_4,                  THEME_1_TO_4_EXPECTED);
    run_test("Theme [3] to [4]",                "zenburn.focus-theme",  THEME_3_TO_4,                  THEME_3_TO_4_EXPECTED);
}

run_test :: (test_name: string, file_name: string, config_data: string, expected_data: string) {
    migrated, modified_data := maybe_migrate_config(file_name, config_data);
    assert(migrated, "%: unexpectedly did not migrate successfully", test_name);
    if modified_data != expected_data {
        print("EXPECTED DATA ========================\n");
        print("%", cast(string) expected_data);
        print("ACTUAL DATA ==========================\n");
        print("%", cast(string) modified_data);
        print("======================================\n");
    }
    assert(modified_data == expected_data, "%: expected data mismatch", test_name);
}

// Test that settings are added and removed correctly

SETTINGS_1_TO_4 :: #string FOCUS_CONFIG

[1]  # Version number. Do not delete.

[[workspace]]

[workspace dirs]
# These directories will be scanned when a workspace is opened so that search etc. works.
# Example:

[[keymap]]
[common]
Ctrl-P                      show_open_file_dialog_in_search_mode

[[settings]]

maximize_on_start:                      false
tab_size:                               4
build_panel_width_percent:              50
max_entries_in_open_file_dialog:        2000
insert_spaces_when_pressing_tab:        true
prefer_system_file_dialogs:             false  # Windows only
show_cursors_off_screen:                true
persist_local_search_results:           false

FOCUS_CONFIG

SETTINGS_1_TO_4_EXPECTED :: #string FOCUS_CONFIG
[4]  # Version number. Do not delete.

[[workspace]]

[workspace dirs]
# These directories will be scanned when a workspace is opened so that search etc. works.
# Example:

[[keymap]]
[common]
Ctrl-P                      open_file_by_name

# Added after migration to version [4]
Ctrl-B                      toggle_build_panel
F11                         toggle_fullscreen
Ctrl-Tab                    switch_between_open_files
Ctrl-Shift-Alt-N            open_another_editor_instance
F8                          go_to_next_build_error
Ctrl-F8                     go_to_next_build_error_on_the_side
Shift-F8                    go_to_previous_build_error
Shift-Ctrl-F8               go_to_previous_build_error_on_the_side

[[settings]]

maximize_on_start:                      false
tab_size:                               4
build_panel_width_percent:              50
insert_spaces_when_pressing_tab:        true
prefer_system_file_dialogs:             false  # Windows only
show_cursors_off_screen:                true
persist_local_search_results:           false

# Added after migration to version [4]
build_panel_height_percent:                    50
build_panel_stays_in_one_place:                false  # if false, the build panel will flip to the inactive pane in two pane layouts
build_panel_line_wrap_always_on:               true
highlight_line_with_cursor:                    false
draw_indent_guides:                            false
auto_surround_with_brackets_and_quotes:        false
scroll_beyond_last_line:                       true
save_current_buffer_on_build:                  false
save_all_file_backed_buffers_on_build:         false
disable_viewport_chasing_cursor_near_the_edge: false  # if true, the viewport will not scroll smoothly to cursor when you move the cursor outside it by small amounts
show_selected_text_length:                     false
window_width:                                  -1
window_height:                                 -1
insert_final_newline_on_save:                  false
status_bar_position:                           bottom

FOCUS_CONFIG

SETTINGS_2_TO_4 :: #string FOCUS_CONFIG
[2]  # Version number. Do not delete.

[[workspace]]

[workspace dirs]
# These directories will be scanned when a workspace is opened so that search etc. works.
# Example:

[[keymap]]
[common]
Ctrl-P                      open_file_by_name

# Added after migration to version [2]
Ctrl-B                      toggle_build_panel
F11                         toggle_fullscreen
Ctrl-Tab                    switch_between_open_files

[[settings]]

maximize_on_start:                      false
tab_size:                               4
build_panel_width_percent:              50
insert_spaces_when_pressing_tab:        true
prefer_system_file_dialogs:             false  # Windows only
show_cursors_off_screen:                true
persist_local_search_results:           false

# Added after migration to version [2]
highlight_line_with_cursor:             false
draw_indent_guides:                     false
auto_surround_with_brackets_and_quotes: false
scroll_beyond_last_line:                true

FOCUS_CONFIG

SETTINGS_2_TO_4_EXPECTED :: #string FOCUS_CONFIG
[4]  # Version number. Do not delete.

[[workspace]]

[workspace dirs]
# These directories will be scanned when a workspace is opened so that search etc. works.
# Example:

[[keymap]]
[common]
Ctrl-P                      open_file_by_name

# Added after migration to version [2]
Ctrl-B                      toggle_build_panel
F11                         toggle_fullscreen
Ctrl-Tab                    switch_between_open_files

# Added after migration to version [4]
Ctrl-Shift-Alt-N            open_another_editor_instance
F8                          go_to_next_build_error
Ctrl-F8                     go_to_next_build_error_on_the_side
Shift-F8                    go_to_previous_build_error
Shift-Ctrl-F8               go_to_previous_build_error_on_the_side

[[settings]]

maximize_on_start:                      false
tab_size:                               4
build_panel_width_percent:              50
insert_spaces_when_pressing_tab:        true
prefer_system_file_dialogs:             false  # Windows only
show_cursors_off_screen:                true
persist_local_search_results:           false

# Added after migration to version [2]
highlight_line_with_cursor:             false
draw_indent_guides:                     false
auto_surround_with_brackets_and_quotes: false
scroll_beyond_last_line:                true

# Added after migration to version [4]
save_current_buffer_on_build:                  false
save_all_file_backed_buffers_on_build:         false
disable_viewport_chasing_cursor_near_the_edge: false  # if true, the viewport will not scroll smoothly to cursor when you move the cursor outside it by small amounts
show_selected_text_length:                     false
window_width:                                  -1
window_height:                                 -1
insert_final_newline_on_save:                  false
status_bar_position:                           bottom

FOCUS_CONFIG

// Settings should not be added to project configs, only removed

PROJECT_SETTINGS_1_TO_4 :: #string FOCUS_CONFIG

[1]  # Version number. Do not delete.

[[workspace]]

[workspace dirs]
# These directories will be scanned when a workspace is opened so that search etc. works.
# Example:

[[keymap]]
[common]
Ctrl-P                      show_open_file_dialog_in_search_mode

[[settings]]

maximize_on_start:                      false
tab_size:                               4
build_panel_width_percent:              50
max_entries_in_open_file_dialog:        2000
insert_spaces_when_pressing_tab:        true
prefer_system_file_dialogs:             false  # Windows only
show_cursors_off_screen:                true
persist_local_search_results:           false

FOCUS_CONFIG

PROJECT_SETTINGS_1_TO_4_EXPECTED :: #string FOCUS_CONFIG
[4]  # Version number. Do not delete.

[[workspace]]

[workspace dirs]
# These directories will be scanned when a workspace is opened so that search etc. works.
# Example:

[[keymap]]
[common]
Ctrl-P                      open_file_by_name

# Added after migration to version [4]
Ctrl-B                      toggle_build_panel
F11                         toggle_fullscreen
Ctrl-Tab                    switch_between_open_files
Ctrl-Shift-Alt-N            open_another_editor_instance
F8                          go_to_next_build_error
Ctrl-F8                     go_to_next_build_error_on_the_side
Shift-F8                    go_to_previous_build_error
Shift-Ctrl-F8               go_to_previous_build_error_on_the_side

[[settings]]

maximize_on_start:                      false
tab_size:                               4
build_panel_width_percent:              50
insert_spaces_when_pressing_tab:        true
prefer_system_file_dialogs:             false  # Windows only
show_cursors_off_screen:                true
persist_local_search_results:           false

FOCUS_CONFIG


// Test that new colors are added correctly

COLORS_1_TO_4 :: #string FOCUS_CONFIG
  [1]   # Version number. Do not delete.

[[style]]

[user interface]
font:       default
font_size:  14

[colors]
background:                             15212AFF
background_dark:                        10191FFF
background_highlight:                   18262FFF
background_light:                       1A2831FF
background_bright:                      21333FFF

scrollbar_hover:                        FFCCCC4C
scrollbar_background:                   FF191F4C

FOCUS_CONFIG

COLORS_1_TO_4_EXPECTED :: #string FOCUS_CONFIG
[4]   # Version number. Do not delete.

[[style]]

[fonts]
font:       default
font_size:  14

[colors]
background0:                            15212AFF
background1:                            10191FFF
background2:                            18262FFF
background3:                            1A2831FF
background4:                            21333FFF

scrollbar_hover:                        FFCCCC4C
scrollbar_background:                   FF191F4C

# Added after migration to version [4]
code_warning:                           E4D97DFF
region_scope_export:                    15212AFF
region_scope_file:                      15212AFF
region_scope_module:                    15212AFF
region_header:                          1A5152FF
region_success:                         226022FF
region_warning:                         986032FF
region_error:                           772222FF
build_panel_background:                 1A2831FF
build_panel_scrollbar:                  33CCCC19
build_panel_scrollbar_hover:            33CCCC4C
build_panel_scrollbar_background:       10191F4C
build_panel_title_bar:                  1C303AFF
region_heredoc:                         10191FFF
code_invalid:                           FF0000FF
code_multiline_string:                  D4BC7DFF
code_raw_string:                        D4BC7DFF
code_char_literal:                      D4BC7DFF
code_identifier:                        BFC9DBFF
code_note:                              E0AD82FF
code_number:                            D699B5FF
code_multiline_comment:                 87919DFF
code_modifier:                          E67D74FF
code_attribute:                         E67D74FF
code_enum_variant:                      BFC9DBFF
code_macro:                             E0AD82FF
code_builtin_variable:                  D699B5FF
code_builtin_function:                  E0AD82FF
code_builtin_exception:                 E0AD82FF
code_directive:                         E67D74FF
code_directive_modifier:                E67D74FF
code_header:                            E67D74FF
code_header2:                           E0AD82FF
code_header3:                           E0AD82FF
code_header4:                           E0AD82FF
code_header5:                           E0AD82FF
code_header6:                           E0AD82FF

FOCUS_CONFIG


COLORS_2_TO_4 :: #string FOCUS_CONFIG
  [2]   # Version number. Do not delete.

[[style]]

[user interface]
font:       default
font_size:  14

[colors]
background0:                            15212AFF
background1:                            10191FFF
background2:                            18262FFF
background3:                            1A2831FF
background4:                            21333FFF

scrollbar_hover:                        FFCCCC4C
scrollbar_background:                   FF191F4C

FOCUS_CONFIG

COLORS_2_TO_4_EXPECTED :: #string FOCUS_CONFIG
[4]   # Version number. Do not delete.

[[style]]

[fonts]
font:       default
font_size:  14

[colors]
background0:                            15212AFF
background1:                            10191FFF
background2:                            18262FFF
background3:                            1A2831FF
background4:                            21333FFF

scrollbar_hover:                        FFCCCC4C
scrollbar_background:                   FF191F4C

# Added after migration to version [4]
region_heredoc:                         10191FFF
code_invalid:                           FF0000FF
code_multiline_string:                  D4BC7DFF
code_raw_string:                        D4BC7DFF
code_char_literal:                      D4BC7DFF
code_identifier:                        BFC9DBFF
code_note:                              E0AD82FF
code_number:                            D699B5FF
code_multiline_comment:                 87919DFF
code_modifier:                          E67D74FF
code_attribute:                         E67D74FF
code_enum_variant:                      BFC9DBFF
code_macro:                             E0AD82FF
code_builtin_variable:                  D699B5FF
code_builtin_function:                  E0AD82FF
code_builtin_exception:                 E0AD82FF
code_directive:                         E67D74FF
code_directive_modifier:                E67D74FF
code_header:                            E67D74FF
code_header2:                           E0AD82FF
code_header3:                           E0AD82FF
code_header4:                           E0AD82FF
code_header5:                           E0AD82FF
code_header6:                           E0AD82FF

FOCUS_CONFIG


// Test that new colors and settings are added correctly when they are both present

COLORS_AND_SETTINGS_1_TO_4 :: #string FOCUS_CONFIG
  [1]   # Version number. Do not delete.

[[workspace]]

[workspace dirs]
# These directories will be scanned when a workspace is opened so that search etc. works.
# Example:

[[settings]]

maximize_on_start:                      false
tab_size:                               4
build_panel_width_percent:              50
max_entries_in_open_file_dialog:        2000
insert_spaces_when_pressing_tab:        true
prefer_system_file_dialogs:             false  # Windows only
show_cursors_off_screen:                true

[[keymap]]
# ...

[[style]]

[user interface]
font:       default
font_size:  14

[colors]
background:                             15212AFF
background_dark:                        FF191FFF
background_highlight:                   18262FFF
background_light:                       1A2831FF
background_bright:                      21333FFF

scrollbar_hover:                        FFCCCC4C
scrollbar_background:                   FF191F4C

FOCUS_CONFIG

COLORS_AND_SETTINGS_1_TO_4_EXPECTED :: #string FOCUS_CONFIG
[4]   # Version number. Do not delete.

[[workspace]]

[workspace dirs]
# These directories will be scanned when a workspace is opened so that search etc. works.
# Example:

[[settings]]

maximize_on_start:                      false
tab_size:                               4
build_panel_width_percent:              50
insert_spaces_when_pressing_tab:        true
prefer_system_file_dialogs:             false  # Windows only
show_cursors_off_screen:                true

# Added after migration to version [4]
build_panel_height_percent:                    50
build_panel_stays_in_one_place:                false  # if false, the build panel will flip to the inactive pane in two pane layouts
build_panel_line_wrap_always_on:               true
highlight_line_with_cursor:                    false
draw_indent_guides:                            false
auto_surround_with_brackets_and_quotes:        false
scroll_beyond_last_line:                       true
persist_local_search_results:                  false  # if true, search results will stay highlighted and you have to dismiss them using the `escape` action
save_current_buffer_on_build:                  false
save_all_file_backed_buffers_on_build:         false
disable_viewport_chasing_cursor_near_the_edge: false  # if true, the viewport will not scroll smoothly to cursor when you move the cursor outside it by small amounts
show_selected_text_length:                     false
window_width:                                  -1
window_height:                                 -1
insert_final_newline_on_save:                  false
status_bar_position:                           bottom

[[keymap]]
# ...

[[style]]

[fonts]
font:       default
font_size:  14

[colors]
background0:                            15212AFF
background1:                            FF191FFF
background2:                            18262FFF
background3:                            1A2831FF
background4:                            21333FFF

scrollbar_hover:                        FFCCCC4C
scrollbar_background:                   FF191F4C

# Added after migration to version [4]
code_warning:                           E4D97DFF
region_scope_export:                    15212AFF
region_scope_file:                      15212AFF
region_scope_module:                    15212AFF
region_header:                          1A5152FF
region_success:                         226022FF
region_warning:                         986032FF
region_error:                           772222FF
build_panel_background:                 1A2831FF
build_panel_scrollbar:                  33CCCC19
build_panel_scrollbar_hover:            33CCCC4C
build_panel_scrollbar_background:       10191F4C
build_panel_title_bar:                  1C303AFF
region_heredoc:                         FF191FFF
code_invalid:                           FF0000FF
code_multiline_string:                  D4BC7DFF
code_raw_string:                        D4BC7DFF
code_char_literal:                      D4BC7DFF
code_identifier:                        BFC9DBFF
code_note:                              E0AD82FF
code_number:                            D699B5FF
code_multiline_comment:                 87919DFF
code_modifier:                          E67D74FF
code_attribute:                         E67D74FF
code_enum_variant:                      BFC9DBFF
code_macro:                             E0AD82FF
code_builtin_variable:                  D699B5FF
code_builtin_function:                  E0AD82FF
code_builtin_exception:                 E0AD82FF
code_directive:                         E67D74FF
code_directive_modifier:                E67D74FF
code_header:                            E67D74FF
code_header2:                           E0AD82FF
code_header3:                           E0AD82FF
code_header4:                           E0AD82FF
code_header5:                           E0AD82FF
code_header6:                           E0AD82FF

FOCUS_CONFIG


KEYBINDS_1_TO_4 :: #string FOCUS_CONFIG
[1]  # Version number. Do not delete.

[[style]]

[user interface]
font:       default
font_size:  14

[colors]
background:                             15212AFF
background_dark:                        10191FFF
background_highlight:                   18262FFF
background_light:                       1A2831FF
background_bright:                      21333FFF

scrollbar_hover:                        FFCCCC4C
scrollbar_background:                   FF191F4C

[[keymap]]

# - The first matching combination will be used, so order matters

[editors]   # <- this means that the following key combos will apply only when editing text

Alt-F4                      quit
Escape                      remove_additional_cursors
Ctrl-Escape                 remove_additional_cursors

Ctrl-D                      select_word_or_create_another_cursor
Ctrl-Shift-A                select_all_occurrences

[open file dialog]
Tab                         open_directory

[common]
Alt-X                       show_commands
Ctrl-Shift-P                show_commands

Ctrl-P                      show_open_file_dialog_in_search_mode
Ctrl-O                      show_open_file_dialog_in_navigate_mode
Ctrl-Shift-O                show_open_file_dialog_in_navigate_mode_from_root
Ctrl-Tab                    show_open_file_dialog_in_open_editors_mode

Ctrl-Alt-P                  switch_to_project

FOCUS_CONFIG

KEYBINDS_1_TO_4_EXPECTED :: #string FOCUS_CONFIG
[4]  # Version number. Do not delete.

[[style]]

[fonts]
font:       default
font_size:  14

[colors]
background0:                            15212AFF
background1:                            10191FFF
background2:                            18262FFF
background3:                            1A2831FF
background4:                            21333FFF

scrollbar_hover:                        FFCCCC4C
scrollbar_background:                   FF191F4C

# Added after migration to version [4]
code_warning:                           E4D97DFF
region_scope_export:                    15212AFF
region_scope_file:                      15212AFF
region_scope_module:                    15212AFF
region_header:                          1A5152FF
region_success:                         226022FF
region_warning:                         986032FF
region_error:                           772222FF
build_panel_background:                 1A2831FF
build_panel_scrollbar:                  33CCCC19
build_panel_scrollbar_hover:            33CCCC4C
build_panel_scrollbar_background:       10191F4C
build_panel_title_bar:                  1C303AFF
region_heredoc:                         10191FFF
code_invalid:                           FF0000FF
code_multiline_string:                  D4BC7DFF
code_raw_string:                        D4BC7DFF
code_char_literal:                      D4BC7DFF
code_identifier:                        BFC9DBFF
code_note:                              E0AD82FF
code_number:                            D699B5FF
code_multiline_comment:                 87919DFF
code_modifier:                          E67D74FF
code_attribute:                         E67D74FF
code_enum_variant:                      BFC9DBFF
code_macro:                             E0AD82FF
code_builtin_variable:                  D699B5FF
code_builtin_function:                  E0AD82FF
code_builtin_exception:                 E0AD82FF
code_directive:                         E67D74FF
code_directive_modifier:                E67D74FF
code_header:                            E67D74FF
code_header2:                           E0AD82FF
code_header3:                           E0AD82FF
code_header4:                           E0AD82FF
code_header5:                           E0AD82FF
code_header6:                           E0AD82FF

[[keymap]]

# - The first matching combination will be used, so order matters

[editors]   # <- this means that the following key combos will apply only when editing text

Alt-F4                      quit
Escape                      escape
Ctrl-Escape                 remove_additional_cursors

Ctrl-D                      select_word_or_create_another_cursor
Ctrl-Shift-A                select_all_occurrences

# Added after migration to version [4]
Alt-Shift-I                 add_cursors_to_line_ends
Alt-Shift-Ctrl-I            add_cursors_to_line_starts
Alt-A                       align_cursors

[open file dialog]
Tab                         open_directory

[common]
Alt-X                       show_commands
Ctrl-Shift-P                show_commands

Ctrl-P                      open_file_by_name
Ctrl-O                      navigate_to_file
Ctrl-Shift-O                navigate_to_file_from_root
Ctrl-Tab                    switch_between_open_files

Ctrl-Alt-P                  switch_to_project

# Added after migration to version [4]
Ctrl-B                      toggle_build_panel
F11                         toggle_fullscreen
Ctrl-Tab                    switch_between_open_files
Ctrl-Shift-Alt-N            open_another_editor_instance
F8                          go_to_next_build_error
Ctrl-F8                     go_to_next_build_error_on_the_side
Shift-F8                    go_to_previous_build_error
Shift-Ctrl-F8               go_to_previous_build_error_on_the_side

FOCUS_CONFIG


KEYBINDS_2_TO_4 :: #string FOCUS_CONFIG
[2]  # Version number. Do not delete.

[[keymap]]

# - The first matching combination will be used, so order matters

[editors]   # <- this means that the following key combos will apply only when editing text

Alt-F4                      quit
Escape                      remove_additional_cursors
Ctrl-Escape                 remove_additional_cursors

Ctrl-D                      select_word_or_create_another_cursor
Ctrl-Shift-A                select_all_occurrences

[open file dialog]
Tab                         open_directory

[common]
Alt-X                       show_commands
Ctrl-Shift-P                show_commands

Ctrl-P                      show_open_file_dialog_in_search_mode
Ctrl-O                      show_open_file_dialog_in_navigate_mode
Ctrl-Shift-O                show_open_file_dialog_in_navigate_mode_from_root
Ctrl-Tab                    show_open_file_dialog_in_open_editors_mode

Ctrl-Alt-P                  switch_to_project

FOCUS_CONFIG

KEYBINDS_2_TO_4_EXPECTED :: #string FOCUS_CONFIG
[4]  # Version number. Do not delete.

[[keymap]]

# - The first matching combination will be used, so order matters

[editors]   # <- this means that the following key combos will apply only when editing text

Alt-F4                      quit
Escape                      escape
Ctrl-Escape                 remove_additional_cursors

Ctrl-D                      select_word_or_create_another_cursor
Ctrl-Shift-A                select_all_occurrences

[open file dialog]
Tab                         open_directory

[common]
Alt-X                       show_commands
Ctrl-Shift-P                show_commands

Ctrl-P                      open_file_by_name
Ctrl-O                      navigate_to_file
Ctrl-Shift-O                navigate_to_file_from_root
Ctrl-Tab                    switch_between_open_files

Ctrl-Alt-P                  switch_to_project

# Added after migration to version [4]
Ctrl-Shift-Alt-N            open_another_editor_instance
F8                          go_to_next_build_error
Ctrl-F8                     go_to_next_build_error_on_the_side
Shift-F8                    go_to_previous_build_error
Shift-Ctrl-F8               go_to_previous_build_error_on_the_side

FOCUS_CONFIG

// Test that themes can be migrated properly

THEME_1_TO_4 :: #string FOCUS_CONFIG
  [1]   # Version number. Do not delete.

[user interface]
font:       default
font_size:  14

[colors]
background:                             15212AFF
background_dark:                        10191FFF
background_highlight:                   18262FFF
background_light:                       1A2831FF
background_bright:                      21333FFF

scrollbar_hover:                        FFCCCC4C
scrollbar_background:                   FF191F4C

FOCUS_CONFIG

THEME_1_TO_4_EXPECTED :: #string FOCUS_CONFIG
[4]   # Version number. Do not delete.

[fonts]
font:       default
font_size:  14

[colors]
background0:                            15212AFF
background1:                            10191FFF
background2:                            18262FFF
background3:                            1A2831FF
background4:                            21333FFF

scrollbar_hover:                        FFCCCC4C
scrollbar_background:                   FF191F4C

# Added after migration to version [4]
code_warning:                           E4D97DFF
region_scope_export:                    15212AFF
region_scope_file:                      15212AFF
region_scope_module:                    15212AFF
region_header:                          1A5152FF
region_success:                         226022FF
region_warning:                         986032FF
region_error:                           772222FF
build_panel_background:                 1A2831FF
build_panel_scrollbar:                  33CCCC19
build_panel_scrollbar_hover:            33CCCC4C
build_panel_scrollbar_background:       10191F4C
build_panel_title_bar:                  1C303AFF
region_heredoc:                         10191FFF
code_invalid:                           FF0000FF
code_multiline_string:                  D4BC7DFF
code_raw_string:                        D4BC7DFF
code_char_literal:                      D4BC7DFF
code_identifier:                        BFC9DBFF
code_note:                              E0AD82FF
code_number:                            D699B5FF
code_multiline_comment:                 87919DFF
code_modifier:                          E67D74FF
code_attribute:                         E67D74FF
code_enum_variant:                      BFC9DBFF
code_macro:                             E0AD82FF
code_builtin_variable:                  D699B5FF
code_builtin_function:                  E0AD82FF
code_builtin_exception:                 E0AD82FF
code_directive:                         E67D74FF
code_directive_modifier:                E67D74FF
code_header:                            E67D74FF
code_header2:                           E0AD82FF
code_header3:                           E0AD82FF
code_header4:                           E0AD82FF
code_header5:                           E0AD82FF
code_header6:                           E0AD82FF

FOCUS_CONFIG


THEME_3_TO_4 :: #string FOCUS_CONFIG
  [3]   # Version number. Do not delete.

[user interface]
font:       default
font_size:  14

[colors]
background:                             15212AFF
background_dark:                        10191FFF
background_highlight:                   18262FFF
background_light:                       1A2831FF
background_bright:                      21333FFF

code_string:                            213344FF

scrollbar_hover:                        FFCCCC4C
scrollbar_background:                   FF191F4C

FOCUS_CONFIG

THEME_3_TO_4_EXPECTED :: #string FOCUS_CONFIG
[4]   # Version number. Do not delete.

[fonts]
font:       default
font_size:  14

[colors]
background0:                            15212AFF
background1:                            10191FFF
background2:                            18262FFF
background3:                            1A2831FF
background4:                            21333FFF

code_string_literal:                    213344FF

scrollbar_hover:                        FFCCCC4C
scrollbar_background:                   FF191F4C

# Added after migration to version [4]
code_invalid:                           FF0000FF
code_multiline_string:                  213344FF
code_raw_string:                        213344FF
code_char_literal:                      213344FF
code_identifier:                        BFC9DBFF
code_note:                              E0AD82FF
code_number:                            D699B5FF
code_multiline_comment:                 87919DFF
code_modifier:                          E67D74FF
code_attribute:                         E67D74FF
code_enum_variant:                      BFC9DBFF
code_macro:                             E0AD82FF
code_builtin_variable:                  D699B5FF
code_builtin_function:                  E0AD82FF
code_builtin_exception:                 E0AD82FF
code_directive:                         E67D74FF
code_directive_modifier:                E67D74FF
code_header:                            E67D74FF
code_header2:                           E0AD82FF
code_header3:                           E0AD82FF
code_header4:                           E0AD82FF
code_header5:                           E0AD82FF
code_header6:                           E0AD82FF

FOCUS_CONFIG
