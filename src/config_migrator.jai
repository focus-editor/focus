// We have a crappy parser here which only does some very superficial parsing.
// The reason is because it's much simpler than keeping valid parsers for each historical version.

maybe_migrate_config :: (name: string, file_data: string) -> Migration_Result, modified_data := "" {
    trimmed_data := trim_left(file_data, " \t\n\r");  // skip empty lines, otherwise the handler will crash!
    start_from_memory(*handler, name, name, trimmed_data);
    if handler.failed return .no_need_to_migrate;  // let it proceed and fail later
    if handler.version >= CURRENT_CONFIG_VERSION return .no_need_to_migrate;

    // Do one full pass to collect information, not touching anything
    config_info: Config_Info;
    {
        current_section: string;
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

                    #insert -> string {
                        b: String_Builder;
                        append(*b, "if setting_name == {\n");
                        for added : ADDED_SETTINGS  print_to_builder(*b, "    case \"%1\";  config_info.settings_present |= .%1;\n", added.name);
                        append(*b, "}\n");
                        return builder_to_string(*b);
                    }

                case "style";
                    if current_subsection == "colors" {
                        color_name, color_value := break_by_spaces(line);
                        color_name = trim_right(color_name, ":");

                        config_info.last_color_offset = line_start_offset;

                        // Remember colors
                        #insert -> string {
                            b: String_Builder;
                            for RENAMED_COLORS {
                                print_to_builder(*b, "if color_name == \"%1\" || color_name == \"%2\" then config_info.colors_present.%2 = color_value;\n", it.old_name, it.new_name);
                            }
                            for ADDED_COLORS {
                                print_to_builder(*b, "if color_name == \"%1\" then config_info.colors_present.%1 = color_value;\n", it.name);
                            }
                            return builder_to_string(*b);
                        }
                    }
            }
        }
    }

    // Now do a modification pass
    modified_data: [..] u8;
    {
        array_resize(*modified_data, trimmed_data.count, initialize = false);
        memcpy(modified_data.data, trimmed_data.data, trimmed_data.count);

        // Insert new settings
        if config_info.last_setting_offset >= 0 {
            insert_offset := config_info.last_setting_offset + get_line_length(modified_data, config_info.last_setting_offset);
            inserted_bytes := 0;

            there_are_settings_to_add := false;
            #insert -> string {
                b: String_Builder;
                for added : ADDED_SETTINGS {
                    print_to_builder(*b, "if !(config_info.settings_present & .%) then there_are_settings_to_add = true;\n", added.name);
                }
                return builder_to_string(*b);
            }

            if there_are_settings_to_add {
                heading := "\n# Settings added after last migration\n";
                array_insert_bytes_at(*modified_data, insert_offset + inserted_bytes, cast([]u8) heading);
                inserted_bytes += heading.count;
            }

            #insert -> string {
                b: String_Builder;
                for added : ADDED_SETTINGS {
                    code := #string JAI
                        if !(config_info.settings_present & .%1) {
                            setting := "%1:%2%3\n";
                            array_insert_bytes_at(*modified_data, insert_offset + inserted_bytes, cast([]u8) setting);
                            inserted_bytes += setting.count;
                        }
                    JAI
                    padding := get_tmp_spaces(SETTING_VALUES_INDENT - added.name.count - 1);
                    print_to_builder(*b, code, added.name, padding, added.value);
                }
                return builder_to_string(*b);
            }
        }

        // Insert new colors
        if config_info.last_color_offset >= 0 {
            insert_offset := config_info.last_color_offset + get_line_length(modified_data, config_info.last_color_offset);
            inserted_bytes := 0;

            there_are_colors_to_add := false;
            #insert -> string {
                b: String_Builder;
                for added : ADDED_COLORS {
                    print_to_builder(*b, "if !config_info.colors_present.% then there_are_colors_to_add = true;\n", added.name);
                }
                return builder_to_string(*b);
            }

            if there_are_colors_to_add {
                heading := "\n# Colors added after last migration\n";
                array_insert_bytes_at(*modified_data, insert_offset + inserted_bytes, cast([]u8) heading);
                inserted_bytes += heading.count;
            }

            #insert -> string {
                b: String_Builder;
                for added : ADDED_COLORS {
                    code := #string JAI
                        if !config_info.colors_present.%1 {
                            %3  // get value
                            color := tprint("%1:%2%%\n", value);
                            array_insert_bytes_at(*modified_data, insert_offset + inserted_bytes, cast([]u8) color);
                            inserted_bytes += color.count;
                        }
                    JAI
                    padding := get_tmp_spaces(COLOR_VALUES_INDENT - added.name.count - 1);
                    value_getter := tprint("value := \"%\";", added.default);
                    if added.value_from {
                        value_getter = tprint("%1 if config_info.colors_present.%2 then value = config_info.colors_present.%2;", value_getter, added.value_from);
                    }
                    print_to_builder(*b, code, added.name, padding, value_getter);
                }
                return builder_to_string(*b);
            }
        }

        // Bump version [1] -> [2]
        assert(begins_with(cast(string) modified_data, "[1]"));
        modified_data[1] = cast(u8) #char "2";

        current_section: string;
        current_subsection: string;
        offset_difference := 0;  // difference between original and modified, in bytes

        start_from_memory(*handler, name, name, cast(string) trimmed_data);  // we use trimmed data here on purpose as it will stay unchanged

        while true {
            line, found := consume_next_line(*handler);
            if !found break;

            line_start_offset := line.data - trimmed_data.data + offset_difference;

            if begins_with(line, "[[") && ends_with(line, "]]") {
                current_section = trim(line, " \t[]");
                current_subsection = "";
                continue;
            }
            if begins_with(line, "[") && ends_with(line, "]") {
                current_subsection = trim(line, " \t[]");  // NOTE: doesn't validate and it's OK

                if current_subsection == "user interface" {
                    // Remove the subsection, but leave everything that was there intact
                    offset_difference += replace_line(*modified_data, line_start_offset, "");
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

            }
        }
    }

    return .migrated_successfully, cast(string) modified_data;
}


#scope_file

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
    .{ 2, "build_panel_width_percent",                  "50" },
    .{ 2, "build_panel_height_percent",                 "50" },
    .{ 2, "build_panel_stays_in_one_place",             "false  # if true, the build panel will flip to the inactive pane in two pane layouts" },
    .{ 2, "build_panel_line_wrap_always_on",            "true" },
    .{ 2, "highlight_line_with_cursor",                 "false" },
    .{ 2, "draw_indent_guides",                         "false" },
    .{ 2, "auto_surround_with_brackets_and_quotes",     "false" },
    .{ 2, "scroll_beyond_last_line",                    "true" },
    .{ 2, "show_cursors_off_screen",                    "true" },
];

REMOVED_SETTINGS :: Removed_Setting.[
    .{ 2, "max_entries_in_open_file_dialog" },
];

SETTING_VALUES_INDENT :: #run -> int {
    length := 0;
    for ADDED_SETTINGS {
        length = max(length, it.name.count);
    }
    return max(length, 40);  // 40 is based on the current indent, but might get longer later if we have longer setting names
}

RENAMED_COLORS :: Renamed_Color.[
    .{ 2, "background",           "background0" },
    .{ 2, "background_dark",      "background1" },
    .{ 2, "background_highlight", "background2" },
    .{ 2, "background_light",     "background3" },
    .{ 2, "background_bright",    "background4" },
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
];

COLOR_VALUES_INDENT :: #run -> int {
    length := 0;
    for RENAMED_COLORS  length = max(length, it.old_name.count);
    for RENAMED_COLORS  length = max(length, it.new_name.count);
    for ADDED_COLORS    length = max(length, it.name.count);
    return max(length, 41);  // 41 is based on the current indent, but might get longer later if we have longer names
}

handler: Text_File_Handler;

Config_Info :: struct {
    settings_present: Settings_Present;
    colors_present: Colors_Present;
    last_setting_offset := -1;
    last_color_offset   := -1;
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

// Settings_Present:
#insert -> string {
    b: String_Builder;
    append(*b, "Settings_Present :: enum_flags {\n");
    for ADDED_SETTINGS  print_to_builder(*b, "    %;\n", it.name);
    append(*b, "}\n");
    return builder_to_string(*b);
}

// Colors_Present:
#insert -> string {
    b: String_Builder;
    colors: [..] string;
    for ADDED_COLORS {
        array_add_if_unique(*colors, it.name);
        if it.value_from then array_add_if_unique(*colors, it.value_from);
    }
    for RENAMED_COLORS {
        array_add_if_unique(*colors, it.old_name);
        array_add_if_unique(*colors, it.new_name);
    }

    append(*b, "Colors_Present :: struct {\n");
    for colors  print_to_builder(*b, "    %: string;\n", it);
    append(*b, "}\n");
    return builder_to_string(*b);
}

Migration_Result :: enum {
    no_need_to_migrate;
    migrated_successfully;
    doesnt_parse_after_migration;
}


// ================================= TESTS ====================================

RUN_TESTS :: true;

// Yes we do unit tests now! Don't you dare submit a PR without tests and 100% coverage.
// Also your code must comply with the SOLID principles. Are we real programmers or what?

#if RUN_TESTS #run,stallable {
    run_test("Settings migration", "global.focus-config", SETTINGS_1, .migrated_successfully, SETTINGS_1_EXPECTED);
    run_test("New colors",         "global.focus-config", COLORS_1,   .migrated_successfully, COLORS_1_EXPECTED);
}

run_test :: (test_name: string, file_name: string, config_data: string, expected_result: Migration_Result, expected_data: string) {
    result, modified_data := maybe_migrate_config(file_name, config_data);
    assert(result == expected_result, "%: Expected result %, got %", test_name, expected_result, result);
    if modified_data != expected_data {
        print("========================\n");
        print("%", cast(string) modified_data);
        print("========================\n");
    }
    assert(modified_data == expected_data, "%: expected data mismatch", test_name);
}

// Test that settings are added and removed correctly

SETTINGS_1 :: #string FOCUS_CONFIG

[1]  # Version number. Do not delete.

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
FOCUS_CONFIG

SETTINGS_1_EXPECTED :: #string FOCUS_CONFIG
[2]  # Version number. Do not delete.

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

# Settings added after last migration
build_panel_height_percent:             50
build_panel_stays_in_one_place:         false  # if true, the build panel will flip to the inactive pane in two pane layouts
build_panel_line_wrap_always_on:        true
highlight_line_with_cursor:             false
draw_indent_guides:                     false
auto_surround_with_brackets_and_quotes: false
scroll_beyond_last_line:                true

[[keymap]]
# ...
FOCUS_CONFIG


// Test that new colors are added correctly

COLORS_1 :: #string FOCUS_CONFIG
  [1]   # Version number. Do not delete.

[[style]]

[user interface]
font:       default
font_size:  14

[colors]
background:                              15212AFF
background_dark:                         10191FFF
background_highlight:                    18262FFF
background_light:                        1A2831FF
background_bright:                       21333FFF

scrollbar_hover:                         FFCCCC4C
scrollbar_background:                    FF191F4C

FOCUS_CONFIG

COLORS_1_EXPECTED :: #string FOCUS_CONFIG
[2]   # Version number. Do not delete.

[[style]]

font:       default
font_size:  14

[colors]
background0:                             15212AFF
background1:                             10191FFF
background2:                             18262FFF
background3:                             1A2831FF
background4:                             21333FFF

scrollbar_hover:                         FFCCCC4C
scrollbar_background:                    FF191F4C

# Colors added after last migration
code_warning:                            E4D97DFF
region_scope_export:                     15212AFF
region_scope_file:                       15212AFF
region_scope_module:                     15212AFF
region_header:                           1A5152FF
region_success:                          226022FF
region_warning:                          986032FF
region_error:                            772222FF
build_panel_background:                  1A2831FF
build_panel_scrollbar:                   33CCCC19
build_panel_scrollbar_hover:             33CCCC4C
build_panel_scrollbar_background:        10191F4C
build_panel_title_bar:                   1C303AFF

FOCUS_CONFIG

