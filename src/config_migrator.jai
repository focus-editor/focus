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
            }

            if current_section == "settings" {
                setting_name, setting_value := break_by_spaces(line);
                setting_name = trim_right(setting_name, ":");

                config_info.last_settings_line_offset = line_start_offset;

                #insert -> string {
                    b: String_Builder;
                    append(*b, "if setting_name == {\n");
                    for added : ADDED_SETTINGS  print_to_builder(*b, "    case \"%1\";  config_info.settings_present |= .%1;\n", added.name);
                    append(*b, "}\n");
                    return builder_to_string(*b);
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
        if config_info.last_settings_line_offset >= 0 {
            insert_offset := config_info.last_settings_line_offset + get_line_length(modified_data, config_info.last_settings_line_offset);
            inserted_bytes := 0;

            there_are_settings_to_add := false;
            #insert -> string {
                b: String_Builder;
                for added : ADDED_SETTINGS {
                    print_to_builder(*b, "if !(config_info.settings_present & .%) then there_are_settings_to_add = true;\n", added.name);
                }
                return builder_to_string(*b);
            }

            if there_are_settings_to_add{
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

        // Bump version [1] -> [2]
        assert(begins_with(cast(string) modified_data, "[1]"));
        modified_data[1] = cast(u8) #char "2";
        start_from_memory(*handler, name, name, cast(string) modified_data);

        current_section: string;
        current_subsection: string;
        offset_difference := 0;  // difference between original and modified, in bytes

        while true {
            line, found := consume_next_line(*handler);
            if !found break;

            line_start_offset := line.data - modified_data.data + offset_difference;

            if begins_with(line, "[[") && ends_with(line, "]]") {
                current_section = trim(line, " \t[]");
                continue;
            }

            if current_section == "settings" {
                setting_name, setting_value := break_by_spaces(line);
                setting_name = trim_right(setting_name, ":");

                // TODO: check version when we have version [3]
                for removed : REMOVED_SETTINGS {
                    if setting_name == removed.name {
                        offset_difference += replace_line(*modified_data, line_start_offset, "");
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

SETTING_VALUES_INDENT :: #run -> int {
    length := 0;
    for ADDED_SETTINGS {
        length = max(length, it.name.count);
    }
    return max(length, 40);  // 40 is based on the current indent, but might get longer later if we have longer setting names
}

REMOVED_SETTINGS :: Removed_Setting.[
    .{ 2, "max_entries_in_open_file_dialog" },
];

handler: Text_File_Handler;

Config_Info :: struct {
    settings_present: Settings_Present;
    last_settings_line_offset := -1;
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

#insert -> string {
    b: String_Builder;
    append(*b, "Settings_Present :: enum_flags {\n");
    for ADDED_SETTINGS  print_to_builder(*b, "    %;\n", it.name);
    append(*b, "}\n");
    return builder_to_string(*b);
}

Migration_Result :: enum {
    no_need_to_migrate;
    migrated_successfully;
    doesnt_parse_after_migration;
}


// ======================== TESTS ===============================

RUN_TESTS :: false;

// Yes we do unit tests now! Don't you dare submit a PR without tests and 100% coverage.
// Also your code must comply with the SOLID principles. Are we real programmers or what?

#if RUN_TESTS #run,stallable {
    result, modified_data := maybe_migrate_config("global.focus-config", TEST1);
    assert(result == .migrated_successfully, "TEST1 result = %", result);
    if modified_data != TEST1_EXPECTED {
        print("========================\n");
        print("%", cast(string) modified_data);
        print("========================\n");
    }
    assert(modified_data == TEST1_EXPECTED, "TEST1 expected mismatch");
}

TEST1 :: #string FOCUS_CONFIG

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

TEST1_EXPECTED :: #string FOCUS_CONFIG
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
