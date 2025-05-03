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
        previous_section: string;
        current_subsection:  string;
        previous_subsection: string;

        while true {
            line, found := consume_next_line(*handler);
            if !found break;

            line_start_offset := line.data - trimmed_data.data;

            just_entered_section := false;

            if begins_with(line, "[[") && ends_with(line, "]]") {
                previous_section = current_section;
                current_section = trim(line, " \t[]");
                current_subsection = "";
                just_entered_section = true;

                if config_info.version < 5 {
                    using config_info.workspace_v5_rewrite;
                    if current_section == "workspace" {
                        workspace_section.start = xx line_start_offset;
                        workspace_section.end   = xx trimmed_data.count;
                    } else if previous_section == "workspace" {
                        workspace_section.end = xx line_start_offset;
                    }
                }
            } else if begins_with(line, "[") && ends_with(line, "]") {
                previous_subsection = current_subsection;
                current_subsection = trim(line, " \t[]");  // NOTE: doesn't validate and it's OK
                just_entered_section = true;
            }

            if current_section == {
                case "workspace";
                    if config_info.version < 5 && !just_entered_section {
                        // Workspace structure has changed in version [5]
                        using config_info.workspace_v5_rewrite;

                        if current_subsection == {
                            case "workspace dirs";          array_add(*workspace_dirs, line);
                            case "file associations";       array_add(*file_associations, line);
                            case "allow file extensions";   for extension : split(line, " ")  array_add(*allowed_extensions, extension);
                            case "ignore file extensions";  for extension : split(line, " ")  array_add(*ignored_extensions, extension);
                            case "ignore dirs";             for dir : split(line, " ")  array_add(*ignored_dirs, dir);
                        }
                    }
                case "settings";
                    setting_name, setting_value := break_by_spaces(line);
                    setting_name = trim_right(setting_name, ":");

                    if !current_subsection then config_info.last_setting_offset = line_start_offset;
                    table_set(*config_info.settings_present, setting_name, true);

                case "style";
                    if current_subsection == "colors" {
                        color_name, color_value := break_by_spaces(line);
                        color_name = trim_right(color_name, ":");

                        config_info.last_color_offset = line_start_offset;

                        table_set(*config_info.colors_present, color_name, color_value);

                        for RENAMED_COLORS {
                            if color_name == it.old_name || color_name == it.new_name {
                                table_set(*config_info.colors_present, it.old_name, color_value);
                                table_set(*config_info.colors_present, it.new_name, color_value);
                            }
                        }
                    }
                case "keymap";
                    success, key_sequence_str, action_name := split_from_right_by_any(line, " \t");
                    if success {
                        key := tprint("%_%", current_subsection, action_name);
                        table_set(*config_info.keybinds_present, key, true);
                    }
                    if current_subsection == "common"        then config_info.last_common_keybind_offset  = line_start_offset;
                    if current_subsection == "editors"       then config_info.last_editors_keybind_offset = line_start_offset;
                    if current_subsection == "search dialog" then config_info.last_search_keybind_offset  = line_start_offset;
            }
        }
    }

    // Now do a modification pass
    modified_data: [..] u8;
    {
        array_resize(*modified_data, trimmed_data.count, initialize = false);
        focus_memcpy(modified_data.data, trimmed_data.data, trimmed_data.count);

        // Migrate workspace to version [5]
        if config_info.version < 5 && config_info.workspace_v5_rewrite.workspace_section.start >= 0 {
            using config_info.workspace_v5_rewrite;

            // Remove the workspace section and recreate it
            old_section_length := workspace_section.end - workspace_section.start;
            assert(old_section_length > 0);
            array_delete_bytes(*modified_data, workspace_section.start, old_section_length);

            // Allow any file extensions which were in the original config but which aren't in the builtin allow list
            allow_contents: string;
            {
                b: String_Builder;
                for allowed_extensions {
                    if contains_any_character(it, "*?") {
                        print_to_builder(*b, "%\n", it);   // add as is
                    } else {
                        extension := trim_left(trim(it), ".");
                        if !is_known_text_file_extension(extension) then print_to_builder(*b, "*.%\n", extension);  // convert to a wildcard
                    }
                }
                allow_contents = trim(builder_to_string(*b));
            }

            // Ignore any file extensions which were in the original config but which aren't in the builtin ignore list
            ignore_contents: string;
            {
                b: String_Builder;
                for ignored_dirs {
                    print_to_builder(*b, "%\n", it);
                }
                for ignored_extensions {
                    if contains_any_character(it, "*?") {
                        print_to_builder(*b, "%\n", it);   // add as is
                    } else {
                        extension := trim_left(trim(it), ".");
                        if !is_known_binary_file_extension(extension) then print_to_builder(*b, "*.%\n", extension);  // convert to a wildcard
                    }
                }
                ignore_contents = trim(builder_to_string(*b));
            }


            // Construct a migrated version
            WORKSPACE_TOP_LEVEL :: #string DONE
[[workspace]]
# These directories and files will be scanned when a workspace is opened so that search etc. works.
%
DONE
            IGNORE_SECTION :: #string DONE
[ignore]
# Files and directories matching the following wildcards will not be loaded or descended into
# Example:
# *.js - will ignore all files with a '.js' extension
# tmp* - will ignore any files or directories which start with 'tmp'
# C:/project/dirname/** - will ignore everything under `dirname`
# C:/project/dirname/*  - will ignore all files under `dirname`, but not recursively
%

DONE
            ALLOW_SECTION :: #string DONE
[allow]
# Files and directories matching the wildcards in this section will be loaded, even if they are ignored in the previous section.
# NOTE: known binary file extensions are ignored by default (*.exe, *.obj etc.). If this is not what you want, you can explicitly allow them here.
%

DONE
            FILE_ASSOCIATIONS_SECTION :: #string DONE
[file associations]
# Optional file associations in the format `<wildcard1> <wildcard2> ... : <language>`
# Example:
# *.hpp *.hh *.h : cpp
# todo.txt : todo
%

DONE

            b: String_Builder;

            print_to_builder(*b, WORKSPACE_TOP_LEVEL, join(..workspace_dirs, separator = "\n"));
            if workspace_dirs then append(*b, "\n");

            if ignore_contents {
                print_to_builder(*b, IGNORE_SECTION, ignore_contents);
            }

            if allow_contents {
                print_to_builder(*b, ALLOW_SECTION, allow_contents);
            }

            if is_global_config {
                print_to_builder(*b, FILE_ASSOCIATIONS_SECTION, join(..file_associations, separator = "\n"));  // add even if not present
                if file_associations then append(*b, "\n");
            }

            new_section := builder_to_string(*b);

            array_insert_bytes_at(*modified_data, workspace_section.start, cast([]u8) new_section);

            // Adjust the offsets we remembered
            bytes_delta := new_section.count - old_section_length;
            if config_info.last_setting_offset         >= workspace_section.end then config_info.last_setting_offset         += bytes_delta;
            if config_info.last_color_offset           >= workspace_section.end then config_info.last_color_offset           += bytes_delta;
            if config_info.last_common_keybind_offset  >= workspace_section.end then config_info.last_common_keybind_offset  += bytes_delta;
            if config_info.last_editors_keybind_offset >= workspace_section.end then config_info.last_editors_keybind_offset += bytes_delta;
            if config_info.last_search_keybind_offset  >= workspace_section.end then config_info.last_search_keybind_offset  += bytes_delta;
        }

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
            if config_info.last_search_keybind_offset  >= config_info.last_setting_offset then config_info.last_search_keybind_offset  += inserted_bytes;
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
            if config_info.last_search_keybind_offset  >= config_info.last_color_offset then config_info.last_search_keybind_offset  += inserted_bytes;
        }

        insert_new_keybinds :: (last_keybind_offset_for_subsection: int, subsection: string) #expand {
            if last_keybind_offset_for_subsection <= 0 return;

            insert_offset := last_keybind_offset_for_subsection + get_line_length(modified_data, last_keybind_offset_for_subsection);
            inserted_bytes := 0;

            // Maybe print a heading
            for added : ADDED_KEYBINDS {
                if added.subsection != subsection continue;
                if !table_contains(*config_info.keybinds_present, tprint("%_%", subsection, added.action)) && valid_version(added.version, config_info.version) {
                    heading := tprint("\n# Added after migration to version [%]\n", CURRENT_CONFIG_VERSION);
                    array_insert_bytes_at(*modified_data, insert_offset + inserted_bytes, cast([]u8) heading);
                    inserted_bytes += heading.count;
                    break;
                }
            }

            for added : ADDED_KEYBINDS {
                if added.subsection != subsection continue;
                if !table_contains(*config_info.keybinds_present, tprint("%_%", subsection, added.action)) && valid_version(added.version, config_info.version) {
                    key_combo := added.key_combo;
                    if OS == .MACOS then key_combo = added.key_combo_mac;
                    padding := get_tmp_spaces(KEYBINDS_INDENT - key_combo.count);
                    key_binding := tprint("%1%2%3\n", key_combo, padding, added.action);
                    array_insert_bytes_at(*modified_data, insert_offset + inserted_bytes, cast([]u8) key_binding);
                    inserted_bytes += key_binding.count;
                }
            }

            if config_info.last_common_keybind_offset  > last_keybind_offset_for_subsection then config_info.last_common_keybind_offset  += inserted_bytes;
            if config_info.last_editors_keybind_offset > last_keybind_offset_for_subsection then config_info.last_editors_keybind_offset += inserted_bytes;
            if config_info.last_search_keybind_offset  > last_keybind_offset_for_subsection then config_info.last_search_keybind_offset  += inserted_bytes;
        }

        insert_new_keybinds(config_info.last_editors_keybind_offset, "editors");
        insert_new_keybinds(config_info.last_common_keybind_offset,  "common");
        insert_new_keybinds(config_info.last_search_keybind_offset,  "search dialog");

        // Bump version from [whatever] to [current]
        assert(begins_with(cast(string) modified_data, tprint("[%]", config_info.version)));
        new_version_line := tprint("[%]  # Version number. Do not delete.\n", CURRENT_CONFIG_VERSION);
        replace_line(*modified_data, 0, new_version_line);

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

                    for setting : RENAMED_SETTINGS {
                        if setting_name == setting.name && valid_version(setting.version, config_info.version) {
                            if !setting.new_name {
                                // Removed setting
                                offset_difference += replace_line(*modified_data, line_start_offset, "");
                            } else {
                                // Renamed setting
                                indent  := cast(s64) (setting_value.data - setting_name.data);
                                padding := get_tmp_spaces(indent - setting.new_name.count - 1);
                                comment := ifx setting.comment then tprint("  # %", setting.comment) else "";

                                value := setting_value;
                                for map : setting.value_map {
                                    if setting_value == map.old_value {
                                        value = map.new_value;
                                        break;
                                    }
                                }
                                new_line := tprint("%1:%2%3%4\n", setting.new_name, padding, value, comment);
                                offset_difference += replace_line(*modified_data, line_start_offset, new_line);
                            }
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
                                        if valid_version(%3, config_info.version) {
                                            force_value_from := "%4";
                                            if force_value_from {
                                                source_value, success := table_find(*config_info.colors_present, force_value_from);
                                                if success && source_value then color_value = source_value;
                                            }
                                            padding  := get_tmp_spaces(COLOR_VALUES_INDENT - "%2".count - 1);
                                            new_line := tprint("%2:%%1%%2\n", padding, color_value);
                                            offset_difference += replace_line(*modified_data, line_start_offset, new_line);
                                        }
                                JAI
                                print_to_builder(*b, code, it.old_name, it.new_name, it.version, it.value_from);
                            }
                            append(*b, "}\n");
                            return builder_to_string(*b);
                        }
                    }

                case "keymap";
                    success, key_sequence_str, action_name := split_from_right_by_any(line, " \t");
                    if success {
                         if current_subsection == "editors" {
                            if action_name == "remove_additional_cursors" && to_lower_copy(trim(key_sequence_str),, allocator = temp) == "escape" {
                                // Rebind action to "escape"
                                new_binding := tprint("Escape                      escape\n");
                                offset_difference += replace_line(*modified_data, line_start_offset, new_binding);
                            }
                        }
                        for RENAMED_KEYBINDS {
                            if action_name == it.old_name && (!it.subsection || it.subsection == current_subsection) {
                                if it.new_name {
                                    // Renamed
                                    action_offset := action_name.data - data_with_insertions.data + offset_difference;
                                    offset_difference += replace_line(*modified_data, action_offset, tprint("%\n", it.new_name));
                                } else {
                                    // Removed
                                    offset_difference += replace_line(*modified_data, line_start_offset, "");
                                }
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
    .{  2, "build_panel_width_percent",                          "50" },
    .{  2, "build_panel_height_percent",                         "50" },
    .{  2, "build_panel_stays_in_one_place",                     "false  # if false, the build panel will flip to the inactive pane in two pane layouts" },
    .{  2, "build_panel_line_wrap_always_on",                    "true" },
    .{  2, "highlight_line_with_cursor",                         "false" },
    .{  2, "draw_indent_guides",                                 "false" },
    .{  2, "auto_surround_with_brackets_and_quotes",             "false" },
    .{  2, "scroll_beyond_last_line",                            "true" },
    .{  2, "show_cursors_off_screen",                            "true" },
    .{  2, "persist_local_search_results",                       "false  # if true, search results will stay highlighted and you have to dismiss them using the `escape` action" },

    .{  3, "save_current_buffer_on_build",                       "false" },
    .{  3, "save_all_file_backed_buffers_on_build",              "false" },
    .{  3, "disable_viewport_chasing_cursor_near_the_edge",      "false  # if true, the viewport will not scroll smoothly to cursor when you move the cursor outside it by small amounts" },
    .{  3, "status_bar_show_selected_text_length",               "false" },

    .{  4, "window_width",                                       "-1" },
    .{  4, "window_height",                                      "-1" },
    .{  4, "insert_final_newline_on_save",                       "false" },
    .{  4, "status_bar_position",                                "bottom  # options: top, bottom" },

    .{  5, "load_most_recent_project_on_start",                  "false" },
    .{  5, "color_preview_popup",                                "enabled  # options: enabled, minimized, disabled" },
    .{  5, "highlight_matching_brackets",                        "false" },

    .{  6, "search_is_case_sensitive_when_uppercase_present",    "false" },
    .{  6, "projects_sorting_order",                             "most_recent_first  #options: most_recent_first, alphabetical, alphabetical_no_case" },

    .{  7, "show_ruler_at_column",                               "0" },

    .{ 11, "detect_indentation",                                 "true  # if true, existing files will be scanned to detect indentation, new files will use the `indent_using` and `tab_size` settings" },
    .{ 11, "status_bar_show_indentation",                        "true" },
    .{ 11, "status_bar_show_line_col",                           "true" },

    .{ 15, "show_scrollbar_marks",                               "true" },

    .{ 16, "scrollbar_width_scale",                              "1.0" },
    .{ 16, "scrollbar_min_opacity",                              "0.0   # if you want the scrollbar to be always visible, set this to 1.0" },
    .{ 16, "scrollbar_max_opacity",                              "1.0" },
    .{ 16, "scrollbar_fade_in_sensitivity",                      "10.0  # controls when the scrollbar appears as the mouse pointer gets close" },
    .{ 16, "scrollbar_fade_out_delay_seconds",                   "1.0   # how long the scrollbar stays visible after scrolling" },
    .{ 16, "scroll_behind_first_line",                           "false" },
    .{ 18, "active_pane_border_width",                           "1.0   # set the width to 0.0 to disable" },
    .{ 18, "inactive_pane_dim_overlay_opacity",                  "0.1   # controls how dim the inactive panes should be" },
];

RENAMED_SETTINGS :: Renamed_Setting.[
    .{  2, "max_entries_in_open_file_dialog", "", .[], "" },  // removed

    .{  6, "strip_trailing_whitespace_on_save",   "strip_trailing_whitespace_on_save",    .[.{"true", "except_lines_with_cursor"}, .{"false", "disabled"}], "options: all, except_lines_with_cursor, disabled"},
    .{  6, "disable_that_annoying_paste_effect",  "show_paste_effect",                    .[.{"true", "false"}, .{"false", "true"}], ""},

    .{ 11, "insert_spaces_when_pressing_tab",     "indent_using",                         .[.{"true", "spaces"}, .{"false", "tabs"}], "options: spaces, tabs"},
    .{ 11, "show_cursors_off_screen",             "status_bar_show_cursors_off_screen",   .[], ""},
    .{ 11, "show_selected_text_length",           "status_bar_show_selected_text_length", .[], ""},

    .{ 17, "editor_history_size", "", .[], "" },  // removed
];

SETTING_VALUES_INDENT :: #run -> int {
    length := 0;
    for ADDED_SETTINGS {
        length = max(length, it.name.count);
    }
    return length + 2;
}

RENAMED_COLORS :: Renamed_Color.[
    .{ 2,  "background",           "background0", "" },
    .{ 2,  "background_dark",      "background1", "" },
    .{ 2,  "background_highlight", "background2", "" },
    .{ 2,  "background_light",     "background3", "" },
    .{ 2,  "background_bright",    "background4", "" },

    .{ 4,  "code_string",          "code_string_literal", "" },

    .{ 17, "splitter",             "splitter",    "background1" },  // force replace value from background1
];


#if !NO_OUTPUT_BUILD {
    original_color_count :: 45;
    expected_added_color_count :: cast(int) Color.NONE - original_color_count;
    #assert expected_added_color_count <= ADDED_COLORS.count  "When you add a new Color you need to add an entry to ADDED_COLORS! Be sure to increment CURRENT_CONFIG_VERSION if you haven't already.";
    #assert expected_added_color_count >= ADDED_COLORS.count  "One or more Colors have been removed. This should not happen!";
}

ADDED_COLORS :: Added_Color.[
    .{  2, "code_warning",                     "",                       "E4D97DFF" },
    .{  2, "region_scope_export",              "background0",            "15212AFF" },
    .{  2, "region_scope_file",                "background0",            "131C22FF" },
    .{  2, "region_scope_module",              "background0",            "1A2831FF" },
    .{  2, "region_header",                    "",                       "1A5152FF" },
    .{  2, "region_success",                   "",                       "226022FF" },
    .{  2, "region_warning",                   "",                       "986032FF" },
    .{  2, "region_error",                     "",                       "772222FF" },
    .{  2, "build_panel_background",           "background3",            "1A2831FF" },
    .{  2, "build_panel_scrollbar",            "scrollbar",              "33CCCC19" },
    .{  2, "build_panel_scrollbar_hover",      "scrollbar_hover",        "33CCCC4C" },
    .{  2, "build_panel_scrollbar_background", "scrollbar_background",   "10191F4C" },
    .{  2, "build_panel_title_bar",            "",                       "1C303AFF" },

    .{  3, "region_heredoc",                   "background1",            "090e12FF" },

    .{  4, "code_invalid",                     "code_error",             "FF0000FF" },
    .{  4, "code_multiline_string",            "code_string_literal",    "D4BC7DFF" },
    .{  4, "code_raw_string",                  "code_string_literal",    "D4BC7DFF" },
    .{  4, "code_char_literal",                "code_string_literal",    "D4BC7DFF" },
    .{  4, "code_identifier",                  "code_default",           "BFC9DBFF" },
    .{  4, "code_note",                        "code_operation",         "E0AD82FF" },
    .{  4, "code_number",                      "code_value",             "D699B5FF" },
    .{  4, "code_multiline_comment",           "code_comment",           "87919DFF" },
    .{  4, "code_modifier",                    "code_keyword",           "E67D74FF" },
    .{  4, "code_attribute",                   "code_keyword",           "E67D74FF" },
    .{  4, "code_enum_variant",                "code_default",           "BFC9DBFF" },
    .{  4, "code_macro",                       "code_operation",         "E0AD82FF" },
    .{  4, "code_builtin_variable",            "code_value",             "D699B5FF" },
    .{  4, "code_builtin_function",            "code_operation",         "E0AD82FF" },
    .{  4, "code_builtin_exception",           "code_operation",         "E0AD82FF" },
    .{  4, "code_directive",                   "code_keyword",           "E67D74FF" },
    .{  4, "code_directive_modifier",          "code_keyword",           "E67D74FF" },
    .{  4, "code_header",                      "code_keyword",           "E67D74FF" },
    .{  4, "code_header2",                     "code_operation",         "E0AD82FF" },
    .{  4, "code_header3",                     "code_operation",         "E0AD82FF" },
    .{  4, "code_header4",                     "code_operation",         "E0AD82FF" },
    .{  4, "code_header5",                     "code_operation",         "E0AD82FF" },
    .{  4, "code_header6",                     "code_operation",         "E0AD82FF" },

    .{  7, "ruler",                            "cursor_inactive",        "FCEDFC26" },

    .{  8, "bracket_highlight",                "selection_highlight",    "E8FCFE30" },
    .{  8, "indent_guide",                     "selection_highlight",    "FCEDFC26" },

    .{ 17, "active_pane_border",               "cursor_inactive",        "19666688" },

    .{ 18, "inactive_pane_dim_overlay",        "",                       "050505FF" },
];


COLOR_VALUES_INDENT :: #run -> int {
    length := 0;
    for RENAMED_COLORS  length = max(length, it.old_name.count);
    for RENAMED_COLORS  length = max(length, it.new_name.count);
    for ADDED_COLORS    length = max(length, it.name.count);
    return max(length, 40);  // 40 is based on the current indent, but might get longer later if we have longer names
}

ADDED_KEYBINDS :: Added_Keybind.[
    .{ 2, "editors", "add_cursors_to_line_ends",                    "Alt-Shift-I",         "Alt-Shift-I"      },
    .{ 2, "editors", "add_cursors_to_line_starts",                  "Alt-Shift-Ctrl-I",    "Alt-Shift-Ctrl-I" },
    .{ 2, "editors", "align_cursors",                               "Alt-A",               "Alt-Cmd-A"        },
    .{ 2, "editors", "select_all_occurrences",                      "Ctrl-Shift-A",        "Cmd-Shift-A"      },
    .{ 2, "common",  "build_panel_toggle",                          "Ctrl-B",              "Cmd-B"            },
    .{ 2, "common",  "toggle_fullscreen",                           "F11",                 "F11"              },
    .{ 2, "common",  "switch_between_open_files",                   "Ctrl-Tab",            "Ctrl-Tab"         },

    .{ 3, "common",  "open_another_editor_instance",                "Ctrl-Shift-Alt-N",    "Cmd-Shift-Alt-N"  },
    .{ 3, "common",  "go_to_next_build_error",                      "F8",                  "F8"               },
    .{ 3, "common",  "go_to_next_build_error_on_the_side",          "Ctrl-F8",             "Cmd-F8"           },
    .{ 3, "common",  "go_to_previous_build_error",                  "Shift-F8",            "Shift-F8"         },
    .{ 3, "common",  "go_to_previous_build_error_on_the_side",      "Shift-Ctrl-F8",       "Shift-Cmd-F8"     },

    .{ 5, "common",  "jump_to_matching_bracket",                    "{Shift}-Ctrl-M",      "{Shift}-Cmd-M"    },

    .{ 7, "editors", "change_case_cycle",                           "Ctrl-U",              "Cmd-U"    },

    .{ 9, "editors", "revert_select_word_or_create_another_cursor", "Ctrl-R",              "Cmd-R"    },
    .{ 9, "editors", "move_selection_to_next_word",                 "Ctrl-Y",              "Cmd-Y"    },

    .{ 10, "search dialog", "go_to_next_input",                     "Tab",                 "Tab"           },
    .{ 10, "search dialog", "go_to_previous_input",                 "Shift-Tab",           "Shift-Tab"     },

    .{ 12, "editors", "move_left_through_word",                     "{Shift}-Meta-ArrowLeft",  "{Shift}-Ctrl-ArrowLeft" },
    .{ 12, "editors", "move_right_through_word",                    "{Shift}-Meta-ArrowRight", "{Shift}-Ctrl-ArrowRight" },
    .{ 12, "editors", "delete_left_through_word",                   "{Shift}-Meta-Backspace",  "{Shift}-Ctrl-Backspace" },
    .{ 12, "editors", "delete_right_through_word",                  "{Shift}-Meta-Delete",     "{Shift}-Ctrl-Delete" },

    .{ 14, "common", "open_entry_in_place",                         "Enter",                "Enter"     },
    .{ 14, "common", "focus_next_ui_element",                       "Tab",                  "Tab"       },
    .{ 14, "common", "focus_previous_ui_element",                   "Shift-Tab",            "Shift-Tab" },

    .{ 17, "common", "close_pane",                                  "Ctrl-Shift-W",                 "Cmd-Shift-W"          },
    .{ 17, "common", "close_left_pane",                             "Ctrl-Alt-W ArrowLeft",         "Cmd-Opt-W ArrowLeft"  },
    .{ 17, "common", "close_right_pane",                            "Ctrl-Alt-W ArrowRight",        "Cmd-Opt-W ArrowRight" },
    .{ 17, "common", "close_top_pane",                              "Ctrl-Alt-W ArrowUp",           "Cmd-Opt-W ArrowUp"    },
    .{ 17, "common", "close_bottom_pane",                           "Ctrl-Alt-W ArrowDown",         "Cmd-Opt-W ArrowDown"  },
    .{ 17, "common", "close_other_panes",                           "Ctrl-Shift-Alt-W",             "Cmd-Shift-Opt-W"      },

    .{ 17, "editors", "move_editor_left",                           "Ctrl-Alt-S ArrowLeft",         "Ctrl-Cmd-S ArrowLeft" },
    .{ 17, "editors", "move_editor_right",                          "Ctrl-Alt-S ArrowRight",        "Ctrl-Cmd-S ArrowRight" },
    .{ 17, "editors", "move_editor_top",                            "Ctrl-Alt-S ArrowUp",           "Ctrl-Cmd-S ArrowUp"   },
    .{ 17, "editors", "move_editor_bottom",                         "Ctrl-Alt-S ArrowDown",         "Ctrl-Cmd-S ArrowDown" },

    .{ 17, "editors", "split_left",                                 "Ctrl-Alt-X ArrowLeft",         "Cmd-Opt-X ArrowLeft"  },
    .{ 17, "editors", "split_right",                                "Ctrl-Alt-X ArrowRight",        "Cmd-Opt-X ArrowRight" },
    .{ 17, "editors", "split_top",                                  "Ctrl-Alt-X ArrowUp",           "Cmd-Opt-X ArrowUp"    },
    .{ 17, "editors", "split_bottom",                               "Ctrl-Alt-X ArrowDown",         "Cmd-Opt-X ArrowDown"  },

    .{ 17, "editors", "duplicate_editor_left",                      "Ctrl-Alt-D ArrowLeft",         "Cmd-Opt-D ArrowLeft"  },
    .{ 17, "editors", "duplicate_editor_right",                     "Ctrl-Alt-D ArrowRight",        "Cmd-Opt-D ArrowRight" },
    .{ 17, "editors", "duplicate_editor_top",                       "Ctrl-Alt-D ArrowUp",           "Cmd-Opt-D ArrowUp"    },
    .{ 17, "editors", "duplicate_editor_bottom",                    "Ctrl-Alt-D ArrowDown",         "Cmd-Opt-D ArrowDown"  },

    .{ 17, "common",  "switch_to_top_pane",                         "Ctrl-Shift-1",                 "Cmd-Shift-1" },
    .{ 17, "common",  "switch_to_bottom_pane",                      "Ctrl-Shift-2",                 "Cmd-Shift-2" },
    .{ 17, "common",  "switch_to_left_pane",                        "Ctrl-Alt-Shift-ArrowLeft",     "Cmd-Opt-Shift-ArrowLeft"  },
    .{ 17, "common",  "switch_to_right_pane",                       "Ctrl-Alt-Shift-ArrowRight",    "Cmd-Opt-Shift-ArrowRight" },
    .{ 17, "common",  "switch_to_top_pane",                         "Ctrl-Alt-Shift-ArrowUp",       "Cmd-Opt-Shift-ArrowUp"    },
    .{ 17, "common",  "switch_to_bottom_pane",                      "Ctrl-Alt-Shift-ArrowDown",     "Cmd-Opt-Shift-ArrowDown"  },
    .{ 17, "common",  "switch_to_pane_1",                           "Ctrl-1",                       "Cmd-1" },
    .{ 17, "common",  "switch_to_pane_2",                           "Ctrl-2",                       "Cmd-2" },
    .{ 17, "common",  "switch_to_pane_3",                           "Ctrl-3",                       "Cmd-3" },
    .{ 17, "common",  "switch_to_pane_4",                           "Ctrl-4",                       "Cmd-4" },
    .{ 17, "common",  "switch_to_pane_5",                           "Ctrl-5",                       "Cmd-5" },
    .{ 17, "common",  "switch_to_pane_6",                           "Ctrl-6",                       "Cmd-6" },
    .{ 17, "common",  "switch_to_pane_7",                           "Ctrl-7",                       "Cmd-7" },
    .{ 17, "common",  "switch_to_pane_8",                           "Ctrl-8",                       "Cmd-8" },
    .{ 17, "common",  "switch_to_pane_9",                           "Ctrl-9",                       "Cmd-9" },

    .{ 18, "editors", "reopen_closed_editor",                       "Ctrl-Shift-T",                 "Cmd-Shift-T"  },
];

RENAMED_KEYBINDS :: Renamed_Keybind.[
    .{ 2, "",  "show_open_file_dialog_in_search_mode",              "open_file_by_name"          },
    .{ 2, "",  "show_open_file_dialog_in_navigate_mode",            "navigate_to_file"           },
    .{ 2, "",  "show_open_file_dialog_in_navigate_mode_from_root",  "navigate_to_file_from_root" },
    .{ 2, "",  "show_open_file_dialog_in_open_editors_mode",        "switch_between_open_files"  },

    .{ 11, "",         "do_nothing",                                ""  },  // removed

    .{ 12, "common",   "move_left_by_word",                         "move_left_by_character_type"         },
    .{ 12, "common",   "move_left_by_word_ends",                    "move_left_through_word_throttled"    },
    .{ 12, "common",   "move_right_by_word",                        "move_right_by_character_type"        },
    .{ 12, "common",   "move_right_by_word_ends",                   "move_right_through_word_throttled"   },
    .{ 12, "common",   "delete_word_left_no_underscore",            "delete_left_by_character_type"       },
    .{ 12, "common",   "delete_word_left",                          "delete_left_by_character_type_fast"  },
    .{ 12, "common",   "delete_word_right_no_underscore",           "delete_right_by_character_type"      },
    .{ 12, "common",   "delete_word_right",                         "delete_right_by_character_type_fast" },

    .{ 13, "common",   "toggle_build_panel",                        "build_panel_toggle" },

    .{ 14, "search dialog", "go_to_next_input",                     "focus_next_ui_element"     },
    .{ 14, "search dialog", "go_to_previous_input",                 "focus_previous_ui_element" },

    .{ 17, "",          "open_entry_on_the_left",           "" },  // removed - replaced with switch_to_*_pane
    .{ 17, "",          "open_entry_on_the_right",          "" },  // removed - replaced with switch_to_*_pane

    .{ 17, "",          "close_other_editor",               "" },  // removed
    .{ 17, "",          "close_left_editor",                "" },  // removed
    .{ 17, "",          "close_right_editor",               "" },  // removed

    .{ 17, "",          "close_current_editor",             "close_editor" },

    .{ 17, "editors",   "move_editor_to_the_left",          "" },  // removed
    .{ 17, "editors",   "move_editor_to_the_right",         "" },  // removed
    .{ 17, "editors",   "switch_to_left_editor",            "" },  // removed
    .{ 17, "editors",   "switch_to_right_editor",           "" },  // removed
    .{ 17, "editors",   "switch_to_other_editor",           "switch_to_side_pane" },

    .{ 17, "editors",   "move_to_next_buffer",              "go_to_next_buffer" },
    .{ 17, "editors",   "move_to_previous_buffer",          "go_to_previous_buffer" },
    .{ 17, "editors",   "move_to_next_editor_history",      "cursor_go_forward" },
    .{ 17, "editors",   "move_to_previous_editor_history",  "cursor_go_back" },

    .{ 17, "editors",   "create_new_file_on_the_side",      "create_new_file_in_side_pane" },
    .{ 17, "",          "open_entry_in_place",              "open_entry" },
    .{ 17, "",          "open_entry_on_the_side",           "open_entry_in_side_pane" },

    .{ 17, "common",    "go_to_next_build_error_on_the_side",       "go_to_next_build_error_in_side_pane" },
    .{ 17, "common",    "go_to_previous_build_error_on_the_side",   "go_to_previous_build_error_in_side_pane" },
];

#if !NO_OUTPUT_BUILD {
    // These are the keybinds originally present in the default config - we don't want to complain about them not being in the renamed/added lists
    ORIGINAL_KEYBINDS :: string.[
        "break_line",
        "copy",
        "create_cursor_above",
        "create_cursor_below",
        "create_new_file",
        "create_new_file_on_the_side",
        "cut",
        "decrease_font_size",
        "delete_left_char",
        "delete_right_char",
        "cut_to_end_of_line",
        "delete_to_end_of_line",
        "cut_to_start_of_line",
        "delete_to_start_of_line",
        "delete_word_left",
        "delete_word_left_no_underscore",
        "delete_word_right",
        "delete_word_right_no_underscore",
        "duplicate_editor",
        "duplicate_lines",
        "escape",
        "go_to_line",
        "increase_font_size",
        "indent",
        "indent_or_go_to_next_tabstop",
        "join_lines",
        "join_lines_no_spaces_in_between",
        "jump_to_file_end",
        "jump_to_file_start",
        "jump_to_line_end",
        "jump_to_line_start",
        "move_cursor_to_viewport_center",
        "move_down",
        "move_down_fast",
        "move_down_one_page",
        "move_down_to_empty_line",
        "move_editor_to_the_left",
        "move_editor_to_the_right",
        "move_left",
        "move_left_by_word",
        "move_left_by_word_ends",
        "move_right",
        "move_right_by_word",
        "move_right_by_word_ends",
        "move_selected_lines_down",
        "move_selected_lines_up",
        "move_up",
        "move_up_fast",
        "move_up_one_page",
        "move_up_to_empty_line",
        "new_line_above_without_breaking",
        "new_line_below_without_breaking",
        "open_directory",
        "open_entry_in_explorer",
        "paste",
        "pop_directory",
        "quit",
        "redo",
        "reset_font_size_to_default",
        "save",
        "save_as",
        "scroll_viewport_down",
        "scroll_viewport_down_fast",
        "scroll_viewport_left",
        "scroll_viewport_right",
        "scroll_viewport_up",
        "scroll_viewport_up_fast",
        "search_in_buffer",
        "search_in_buffer_dropdown_mode",
        "search_in_project",
        "select_all",
        "select_line",
        "select_word",
        "select_word_or_create_another_cursor",
        "show_commands",
        "switch_to_left_editor",
        "switch_to_other_editor",
        "switch_to_project",
        "switch_to_right_editor",
        "toggle_case_sensitive",
        "toggle_comment",
        "toggle_expand",
        "toggle_line_numbers",
        "toggle_line_wrap",
        "toggle_regex_search",
        "toggle_whole_word",
        "undo",
        "unindent",
    ];
}

#scope_export
check_added_keybinds :: (config: Parsed_Config) {
    #if !NO_OUTPUT_BUILD {
        expected_keybinds : [..] string;
        for ADDED_KEYBINDS  array_add(*expected_keybinds, it.action);
        for RENAMED_KEYBINDS  array_add(*expected_keybinds, it.new_name);
        for ORIGINAL_KEYBINDS  array_add(*expected_keybinds, it);
        check_keymap :: (keymap: [] Key_Mapping, action_names: [] string) #expand {
            for keymap {
                name := action_names[it.action];
                assert(array_find(expected_keybinds, name), "Keybind \"%\" found in default config which should be added to ADDED_KEYBINDS or RENAMED_KEYBINDS. Be sure to increment CURRENT_CONFIG_VERSION if you haven't already.", name);
            }
        }
        check_keymap(config.keymap_common,           enum_names(Action_Common));
        check_keymap(config.keymap_editors,          enum_names(Action_Editors));
        check_keymap(config.keymap_open_file_dialog, enum_names(Action_Open_File_Dialog));
        check_keymap(config.keymap_search_dialog,    enum_names(Action_Search_Dialog));
    }
}
#scope_file


KEYBINDS_INDENT :: 28;

handler: Text_File_Handler;

Config_Info :: struct {
    version: int;

    settings_present: Table(string, bool);    // e.g. build_panel_width_percent -> true means it's present
    colors_present:   Table(string, string);  // e.g. code_warning -> E4D97DFF (store a value we've seen)
    keybinds_present: Table(string, bool);

    last_setting_offset := -1;
    last_color_offset   := -1;
    last_common_keybind_offset  := -1;
    last_editors_keybind_offset := -1;
    last_search_keybind_offset  := -1;

    workspace_v5_rewrite: Workspace_V5_Rewrite_Info;  // only for migration to version [5]
};

Workspace_V5_Rewrite_Info :: struct {
    workspace_section   := Offset_Range.{ -1, -1 };

    workspace_dirs:     [..] string;
    ignored_dirs:       [..] string;
    ignored_extensions: [..] string;
    allowed_extensions: [..] string;
    file_associations:  [..] string;
}

Added_Setting :: struct {
    version: int;
    name:    string;
    value:   string;
}

Renamed_Setting :: struct {
    version:    int;
    name:       string;
    new_name:   string;
    value_map:  [] Value_Map;
    comment:    string;

    Value_Map :: struct {
        old_value: string;
        new_value: string;
    }
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
    value_from: string;
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

// Yes we do unit tests now! Don't you dare submit a PR without tests and a 100% coverage.
// Also your code must comply with the SOLID principles. Are we real programmers or what?
RUN_TESTS :: !NO_OUTPUT_BUILD && !DEBUG && OS != .MACOS;
MIGRATE_BUILTIN_THEMES :: !NO_OUTPUT_BUILD && !DEBUG;

#if RUN_TESTS #run,stallable {
    run_test("Workspace migration from [3]",  "global.focus-config",  WORKSPACE_3,              WORKSPACE_3_EXPECTED);
    run_test("Settings migration from [1]",   "global.focus-config",  SETTINGS_1,               SETTINGS_1_EXPECTED);
    run_test("Settings migration from [2]",   "global.focus-config",  SETTINGS_2,               SETTINGS_2_EXPECTED);
    run_test("Project settings from [1]",     "project.focus-config", PROJECT_SETTINGS_1,       PROJECT_SETTINGS_1_EXPECTED);
    run_test("Project workspace from [3]",    "project.focus-config", PROJECT_WORKSPACE_3,      PROJECT_WORKSPACE_3_EXPECTED);
    run_test("Сolors from [1]",               "global.focus-config",  COLORS_1,                 COLORS_1_EXPECTED);
    run_test("Сolors from [2]",               "global.focus-config",  COLORS_2,                 COLORS_2_EXPECTED);
    run_test("Colors and settings from [1]",  "global.focus-config",  COLORS_AND_SETTINGS_1,    COLORS_AND_SETTINGS_1_EXPECTED);
    run_test("Keybinds from [1]",             "global.focus-config",  KEYBINDS_1,               KEYBINDS_1_EXPECTED);
    run_test("Theme from [1]",                "nord.focus-theme",     THEME_1,                  THEME_1_EXPECTED);
    run_test("Theme from [3]",                "handmade.focus-theme", THEME_3,                  THEME_3_EXPECTED);
    // run_test("Keybinds from [2]",             "global.focus-config",  KEYBINDS_2,               KEYBINDS_2_EXPECTED);
    // run_test("Workspace migration from [4]",  "global.focus-config",  WORKSPACE_4,              WORKSPACE_4_EXPECTED);

    print("All unit tests passed!\n");

    if MIGRATE_BUILTIN_THEMES #run,stallable {
        for theme : BUILTIN_THEMES {
            theme_file := tprint("config/themes/%.focus-theme", theme.name);
            migrated, modified_data := maybe_migrate_config(theme_file, theme.contents);
            if migrated {
                write_entire_file(theme_file, modified_data);
                print("Migrated builtin theme '%' to version [%]\n", theme.name, CURRENT_CONFIG_VERSION);
            }
        }
    }
}

run_test :: (test_name: string, file_name: string, config_data: string, expected_template: string) {
    migrated, modified_data := maybe_migrate_config(file_name, config_data);
    assert(migrated, "%: unexpectedly did not migrate successfully", test_name);

    expected_data := replace(expected_template, "[!latest!]", tprint("[%]", CURRENT_CONFIG_VERSION));

    if modified_data != expected_data {
        simple_diff(test_name, "EXPECTED DATA", cast(string) expected_data, "GENERATED DATA", cast(string) modified_data);
        assert(false, "%: expected data mismatch", test_name);
    }
}

simple_diff :: (main_header: string, header1: string, data1: string, header2: string, data2: string) {
    print("Discrepancy in test: %\n\n", main_header);
    line_number := 1;
    line_start := 0;
    prev_line_start := 0;
    max_output_chars :: 360;
    for i : 0 .. data1.count - 1 {
        if i >= data2.count {
            print("% continues after % runs out:\nLine number: %\n%\n",
                    header1, header2,
                    line_number,
                    slice(data1, line_start, min(data1.count - line_start, max_output_chars)));
            return;
        }
        if data1[i] != data2[i] {
            print("Line number: %\n============== % ==============\n%\n\n============== % ==============\n%\n\n",
                    line_number,
                    header1,
                    slice(data1, prev_line_start, min(data1.count - prev_line_start, max_output_chars)),
                    header2,
                    slice(data2, prev_line_start, min(data2.count - prev_line_start, max_output_chars)));
            return;
        }
        if data1[i] == #char "\n" {
            line_number += 1;
            prev_line_start = line_start;
            line_start = i + 1;
        }
    }

    if data2.count > data1.count {
        print("% continues after % runs out:\nLine number: %\n%\n",
                header2, header1,
                line_number,
                slice(data2, line_start, min(data2.count - line_start, max_output_chars)));
    }
}


WORKSPACE_3 :: #string FOCUS_CONFIG
[3]  # Version number. Do not delete.

[[workspace]]

[ignore dirs]
# The workspace scanner will not descend into the dirs that match these names.
.svn
.git
__pycache__

[workspace dirs]
# These directories will be scanned when a workspace is opened so that search etc. works.
# Example:
C:/projects/project1

[allow file extensions]
# These files are explicitly allowed so that the editor doesn't waste time figuring out
# whether it should ignore these or not (if a file is not explicitly allowed or ignored,
# it will be read to determine if it's binary or not).
.jai .c .cpp .h .hpp .cc .cs .txt .md .focus-* .ini .super-text-file .csv .log .sql *.my-file?1* .py .m .html .xml .plist .js .jsx .ts .tsx .json .yml .yaml .toml .zig .odin

[ignore file extensions]
# Files with the following extensions will not appear in the file open dialog and won't be loaded into memory.
# It makes sense to add all known binary file extensions here.
.exe .pdb .ttf .otf .eot .woff *woff? .dll .lib .dylib .so *so.* .a .o .pdf
.jpg .png .gif .jpeg .ico .tif .tiff .tga .bmp .webp  # maybe someday we'll support opening images
.mp3 .wav .ogg .wma
.blend .blend1 .obj .fbx .dae .3ds .dat .msh2
.mpg .mpeg .psd .codex .webm .wma
.zip .rar .7z
.bin .sys .iso
.nib .exp
.pyc .rpyc
.DS_Store .dmg
*.my-ignore-file .file-ignore

[file associations]
# Optional file associations in the format `<wildcard1> <wildcard2> ... : <language>`
# Example:
# *.hpp *.hh *.h : cpp
todo.txt : todo


[[keymap]]

FOCUS_CONFIG

WORKSPACE_3_EXPECTED :: #string FOCUS_CONFIG
[!latest!]  # Version number. Do not delete.

[[workspace]]
# These directories and files will be scanned when a workspace is opened so that search etc. works.
C:/projects/project1

[ignore]
# Files and directories matching the following wildcards will not be loaded or descended into
# Example:
# *.js - will ignore all files with a '.js' extension
# tmp* - will ignore any files or directories which start with 'tmp'
# C:/project/dirname/** - will ignore everything under `dirname`
# C:/project/dirname/*  - will ignore all files under `dirname`, but not recursively
.svn
.git
__pycache__
*woff?
*so.*
*.my-ignore-file
*.file-ignore

[allow]
# Files and directories matching the wildcards in this section will be loaded, even if they are ignored in the previous section.
# NOTE: known binary file extensions are ignored by default (*.exe, *.obj etc.). If this is not what you want, you can explicitly allow them here.
.focus-*
*.super-text-file
*.my-file?1*

[file associations]
# Optional file associations in the format `<wildcard1> <wildcard2> ... : <language>`
# Example:
# *.hpp *.hh *.h : cpp
# todo.txt : todo
todo.txt : todo


[[keymap]]

FOCUS_CONFIG

PROJECT_WORKSPACE_3 :: #string FOCUS_CONFIG
[3]  # Version number. Do not delete.

[[workspace]]

[ignore dirs]
.svn
.git

[workspace dirs]
# These directories will be scanned when a workspace is opened so that search etc. works.
# Example:
C:/projects/project1

FOCUS_CONFIG

PROJECT_WORKSPACE_3_EXPECTED :: #string FOCUS_CONFIG
[!latest!]  # Version number. Do not delete.

[[workspace]]
# These directories and files will be scanned when a workspace is opened so that search etc. works.
C:/projects/project1

[ignore]
# Files and directories matching the following wildcards will not be loaded or descended into
# Example:
# *.js - will ignore all files with a '.js' extension
# tmp* - will ignore any files or directories which start with 'tmp'
# C:/project/dirname/** - will ignore everything under `dirname`
# C:/project/dirname/*  - will ignore all files under `dirname`, but not recursively
.svn
.git

FOCUS_CONFIG

WORKSPACE_4 :: #string FOCUS_CONFIG
[4]  # Version number. Do not delete.

[[keymap]]
[common]
Ctrl-P                      open_file_by_name


[[workspace]]

[ignore dirs]
# The workspace scanner will not descend into the dirs that match these names.
.svn
.git
__pycache__

[workspace dirs]
# These directories will be scanned when a workspace is opened so that search etc. works.
# Example:
C:/projects/project1

[allow file extensions]
# These files are explicitly allowed so that the editor doesn't waste time figuring out
# whether it should ignore these or not (if a file is not explicitly allowed or ignored,
# it will be read to determine if it's binary or not).
.jai .c .cpp .h .hpp .cc .cs .txt .md .focus-* .ini .super-text-file .csv .log .sql *.my-file?1* .py .m .html .xml .plist .js .jsx .ts .tsx .json .yml .yaml .toml .zig .odin

[file associations]
# Optional file associations in the format `<wildcard1> <wildcard2> ... : <language>`
# Example:
# *.hpp *.hh *.h : cpp
todo.txt : todo
*.hpp *.hh *.h : cpp


FOCUS_CONFIG

WORKSPACE_4_EXPECTED :: #string FOCUS_CONFIG
[!latest!]  # Version number. Do not delete.

[[keymap]]
[common]
Ctrl-P                      open_file_by_name

# Added after migration to version [!latest!]
{Shift}-Ctrl-M              jump_to_matching_bracket


[[workspace]]
# These directories and files will be scanned when a workspace is opened so that search etc. works.
C:/projects/project1

[ignore]
# Files and directories matching the following wildcards will not be loaded or descended into
# Example:
# *.js - will ignore all files with a '.js' extension
# tmp* - will ignore any files or directories which start with 'tmp'
# C:/project/dirname/** - will ignore everything under `dirname`
# C:/project/dirname/*  - will ignore all files under `dirname`, but not recursively
.svn
.git
__pycache__

[allow]
# Files and directories matching the wildcards in this section will be loaded, even if they are ignored in the previous section.
# NOTE: known binary file extensions are ignored by default (*.exe, *.obj etc.). If this is not what you want, you can explicitly allow them here.
.focus-*
*.super-text-file
*.my-file?1*

[file associations]
# Optional file associations in the format `<wildcard1> <wildcard2> ... : <language>`
# Example:
# *.hpp *.hh *.h : cpp
# todo.txt : todo
todo.txt : todo
*.hpp *.hh *.h : cpp


FOCUS_CONFIG

// Test that settings are added and removed correctly

SETTINGS_1 :: #string FOCUS_CONFIG

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
disable_that_annoying_paste_effect:     false
tab_size:                               4
build_panel_width_percent:              50
max_entries_in_open_file_dialog:        2000
insert_spaces_when_pressing_tab:        true
prefer_system_file_dialogs:             false  # Windows only
show_cursors_off_screen:                true
persist_local_search_results:           false
strip_trailing_whitespace_on_save:      true

FOCUS_CONFIG

SETTINGS_1_EXPECTED :: #string FOCUS_CONFIG
[!latest!]  # Version number. Do not delete.

[[workspace]]
# These directories and files will be scanned when a workspace is opened so that search etc. works.

[file associations]
# Optional file associations in the format `<wildcard1> <wildcard2> ... : <language>`
# Example:
# *.hpp *.hh *.h : cpp
# todo.txt : todo


[[keymap]]
[common]
Ctrl-P                      open_file_by_name

# Added after migration to version [!latest!]
Ctrl-B                      build_panel_toggle
F11                         toggle_fullscreen
Ctrl-Tab                    switch_between_open_files
Ctrl-Shift-Alt-N            open_another_editor_instance
F8                          go_to_next_build_error
Ctrl-F8                     go_to_next_build_error_in_side_pane
Shift-F8                    go_to_previous_build_error
Shift-Ctrl-F8               go_to_previous_build_error_in_side_pane
{Shift}-Ctrl-M              jump_to_matching_bracket
Enter                       open_entry
Tab                         focus_next_ui_element
Shift-Tab                   focus_previous_ui_element
Ctrl-Shift-W                close_pane
Ctrl-Alt-W ArrowLeft        close_left_pane
Ctrl-Alt-W ArrowRight       close_right_pane
Ctrl-Alt-W ArrowUp          close_top_pane
Ctrl-Alt-W ArrowDown        close_bottom_pane
Ctrl-Shift-Alt-W            close_other_panes
Ctrl-Shift-1                switch_to_top_pane
Ctrl-Shift-2                switch_to_bottom_pane
Ctrl-Alt-Shift-ArrowLeft    switch_to_left_pane
Ctrl-Alt-Shift-ArrowRight   switch_to_right_pane
Ctrl-Alt-Shift-ArrowUp      switch_to_top_pane
Ctrl-Alt-Shift-ArrowDown    switch_to_bottom_pane
Ctrl-1                      switch_to_pane_1
Ctrl-2                      switch_to_pane_2
Ctrl-3                      switch_to_pane_3
Ctrl-4                      switch_to_pane_4
Ctrl-5                      switch_to_pane_5
Ctrl-6                      switch_to_pane_6
Ctrl-7                      switch_to_pane_7
Ctrl-8                      switch_to_pane_8
Ctrl-9                      switch_to_pane_9

[[settings]]

maximize_on_start:                      false
show_paste_effect:                      true
tab_size:                               4
build_panel_width_percent:              50
indent_using:                           spaces  # options: spaces, tabs
prefer_system_file_dialogs:             false  # Windows only
status_bar_show_cursors_off_screen:     true
persist_local_search_results:           false
strip_trailing_whitespace_on_save:      except_lines_with_cursor  # options: all, except_lines_with_cursor, disabled

# Added after migration to version [!latest!]
build_panel_height_percent:                      50
build_panel_stays_in_one_place:                  false  # if false, the build panel will flip to the inactive pane in two pane layouts
build_panel_line_wrap_always_on:                 true
highlight_line_with_cursor:                      false
draw_indent_guides:                              false
auto_surround_with_brackets_and_quotes:          false
scroll_beyond_last_line:                         true
save_current_buffer_on_build:                    false
save_all_file_backed_buffers_on_build:           false
disable_viewport_chasing_cursor_near_the_edge:   false  # if true, the viewport will not scroll smoothly to cursor when you move the cursor outside it by small amounts
status_bar_show_selected_text_length:            false
window_width:                                    -1
window_height:                                   -1
insert_final_newline_on_save:                    false
status_bar_position:                             bottom  # options: top, bottom
load_most_recent_project_on_start:               false
color_preview_popup:                             enabled  # options: enabled, minimized, disabled
highlight_matching_brackets:                     false
search_is_case_sensitive_when_uppercase_present: false
projects_sorting_order:                          most_recent_first  #options: most_recent_first, alphabetical, alphabetical_no_case
show_ruler_at_column:                            0
detect_indentation:                              true  # if true, existing files will be scanned to detect indentation, new files will use the `indent_using` and `tab_size` settings
status_bar_show_indentation:                     true
status_bar_show_line_col:                        true
show_scrollbar_marks:                            true
scrollbar_width_scale:                           1.0
scrollbar_min_opacity:                           0.0   # if you want the scrollbar to be always visible, set this to 1.0
scrollbar_max_opacity:                           1.0
scrollbar_fade_in_sensitivity:                   10.0  # controls when the scrollbar appears as the mouse pointer gets close
scrollbar_fade_out_delay_seconds:                1.0   # how long the scrollbar stays visible after scrolling
scroll_behind_first_line:                        false
active_pane_border_width:                        1.0   # set the width to 0.0 to disable
inactive_pane_dim_overlay_opacity:               0.1   # controls how dim the inactive panes should be

FOCUS_CONFIG

SETTINGS_2 :: #string FOCUS_CONFIG
[2]  # Version number. Do not delete.

[[workspace]]

[workspace dirs]
# These directories will be scanned when a workspace is opened so that search etc. works.
# Example:

[[keymap]]
[common]
Ctrl-P                      open_file_by_name

# Added after migration to version [2]
Ctrl-B                      build_panel_toggle
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
disable_that_annoying_paste_effect:     true
strip_trailing_whitespace_on_save:      false

# Added after migration to version [2]
highlight_line_with_cursor:             false
draw_indent_guides:                     false
auto_surround_with_brackets_and_quotes: false
scroll_beyond_last_line:                true

FOCUS_CONFIG

SETTINGS_2_EXPECTED :: #string FOCUS_CONFIG
[!latest!]  # Version number. Do not delete.

[[workspace]]
# These directories and files will be scanned when a workspace is opened so that search etc. works.

[file associations]
# Optional file associations in the format `<wildcard1> <wildcard2> ... : <language>`
# Example:
# *.hpp *.hh *.h : cpp
# todo.txt : todo


[[keymap]]
[common]
Ctrl-P                      open_file_by_name

# Added after migration to version [2]
Ctrl-B                      build_panel_toggle
F11                         toggle_fullscreen
Ctrl-Tab                    switch_between_open_files

# Added after migration to version [!latest!]
Ctrl-Shift-Alt-N            open_another_editor_instance
F8                          go_to_next_build_error
Ctrl-F8                     go_to_next_build_error_in_side_pane
Shift-F8                    go_to_previous_build_error
Shift-Ctrl-F8               go_to_previous_build_error_in_side_pane
{Shift}-Ctrl-M              jump_to_matching_bracket
Enter                       open_entry
Tab                         focus_next_ui_element
Shift-Tab                   focus_previous_ui_element
Ctrl-Shift-W                close_pane
Ctrl-Alt-W ArrowLeft        close_left_pane
Ctrl-Alt-W ArrowRight       close_right_pane
Ctrl-Alt-W ArrowUp          close_top_pane
Ctrl-Alt-W ArrowDown        close_bottom_pane
Ctrl-Shift-Alt-W            close_other_panes
Ctrl-Shift-1                switch_to_top_pane
Ctrl-Shift-2                switch_to_bottom_pane
Ctrl-Alt-Shift-ArrowLeft    switch_to_left_pane
Ctrl-Alt-Shift-ArrowRight   switch_to_right_pane
Ctrl-Alt-Shift-ArrowUp      switch_to_top_pane
Ctrl-Alt-Shift-ArrowDown    switch_to_bottom_pane
Ctrl-1                      switch_to_pane_1
Ctrl-2                      switch_to_pane_2
Ctrl-3                      switch_to_pane_3
Ctrl-4                      switch_to_pane_4
Ctrl-5                      switch_to_pane_5
Ctrl-6                      switch_to_pane_6
Ctrl-7                      switch_to_pane_7
Ctrl-8                      switch_to_pane_8
Ctrl-9                      switch_to_pane_9

[[settings]]

maximize_on_start:                      false
tab_size:                               4
build_panel_width_percent:              50
indent_using:                           spaces  # options: spaces, tabs
prefer_system_file_dialogs:             false  # Windows only
status_bar_show_cursors_off_screen:     true
persist_local_search_results:           false
show_paste_effect:                      false
strip_trailing_whitespace_on_save:      disabled  # options: all, except_lines_with_cursor, disabled

# Added after migration to version [2]
highlight_line_with_cursor:             false
draw_indent_guides:                     false
auto_surround_with_brackets_and_quotes: false
scroll_beyond_last_line:                true

# Added after migration to version [!latest!]
save_current_buffer_on_build:                    false
save_all_file_backed_buffers_on_build:           false
disable_viewport_chasing_cursor_near_the_edge:   false  # if true, the viewport will not scroll smoothly to cursor when you move the cursor outside it by small amounts
status_bar_show_selected_text_length:            false
window_width:                                    -1
window_height:                                   -1
insert_final_newline_on_save:                    false
status_bar_position:                             bottom  # options: top, bottom
load_most_recent_project_on_start:               false
color_preview_popup:                             enabled  # options: enabled, minimized, disabled
highlight_matching_brackets:                     false
search_is_case_sensitive_when_uppercase_present: false
projects_sorting_order:                          most_recent_first  #options: most_recent_first, alphabetical, alphabetical_no_case
show_ruler_at_column:                            0
detect_indentation:                              true  # if true, existing files will be scanned to detect indentation, new files will use the `indent_using` and `tab_size` settings
status_bar_show_indentation:                     true
status_bar_show_line_col:                        true
show_scrollbar_marks:                            true
scrollbar_width_scale:                           1.0
scrollbar_min_opacity:                           0.0   # if you want the scrollbar to be always visible, set this to 1.0
scrollbar_max_opacity:                           1.0
scrollbar_fade_in_sensitivity:                   10.0  # controls when the scrollbar appears as the mouse pointer gets close
scrollbar_fade_out_delay_seconds:                1.0   # how long the scrollbar stays visible after scrolling
scroll_behind_first_line:                        false
active_pane_border_width:                        1.0   # set the width to 0.0 to disable
inactive_pane_dim_overlay_opacity:               0.1   # controls how dim the inactive panes should be

FOCUS_CONFIG

// Settings should not be added to project configs, only removed

PROJECT_SETTINGS_1 :: #string FOCUS_CONFIG

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

PROJECT_SETTINGS_1_EXPECTED :: #string FOCUS_CONFIG
[!latest!]  # Version number. Do not delete.

[[workspace]]
# These directories and files will be scanned when a workspace is opened so that search etc. works.

[[keymap]]
[common]
Ctrl-P                      open_file_by_name

# Added after migration to version [!latest!]
Ctrl-B                      build_panel_toggle
F11                         toggle_fullscreen
Ctrl-Tab                    switch_between_open_files
Ctrl-Shift-Alt-N            open_another_editor_instance
F8                          go_to_next_build_error
Ctrl-F8                     go_to_next_build_error_in_side_pane
Shift-F8                    go_to_previous_build_error
Shift-Ctrl-F8               go_to_previous_build_error_in_side_pane
{Shift}-Ctrl-M              jump_to_matching_bracket
Enter                       open_entry
Tab                         focus_next_ui_element
Shift-Tab                   focus_previous_ui_element
Ctrl-Shift-W                close_pane
Ctrl-Alt-W ArrowLeft        close_left_pane
Ctrl-Alt-W ArrowRight       close_right_pane
Ctrl-Alt-W ArrowUp          close_top_pane
Ctrl-Alt-W ArrowDown        close_bottom_pane
Ctrl-Shift-Alt-W            close_other_panes
Ctrl-Shift-1                switch_to_top_pane
Ctrl-Shift-2                switch_to_bottom_pane
Ctrl-Alt-Shift-ArrowLeft    switch_to_left_pane
Ctrl-Alt-Shift-ArrowRight   switch_to_right_pane
Ctrl-Alt-Shift-ArrowUp      switch_to_top_pane
Ctrl-Alt-Shift-ArrowDown    switch_to_bottom_pane
Ctrl-1                      switch_to_pane_1
Ctrl-2                      switch_to_pane_2
Ctrl-3                      switch_to_pane_3
Ctrl-4                      switch_to_pane_4
Ctrl-5                      switch_to_pane_5
Ctrl-6                      switch_to_pane_6
Ctrl-7                      switch_to_pane_7
Ctrl-8                      switch_to_pane_8
Ctrl-9                      switch_to_pane_9

[[settings]]

maximize_on_start:                      false
tab_size:                               4
build_panel_width_percent:              50
indent_using:                           spaces  # options: spaces, tabs
prefer_system_file_dialogs:             false  # Windows only
status_bar_show_cursors_off_screen:     true
persist_local_search_results:           false

FOCUS_CONFIG


// Test that new colors are added correctly

COLORS_1 :: #string FOCUS_CONFIG
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
selection_highlight:                    FF000026

FOCUS_CONFIG

COLORS_1_EXPECTED :: #string FOCUS_CONFIG
[!latest!]  # Version number. Do not delete.

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
selection_highlight:                    FF000026

# Added after migration to version [!latest!]
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
build_panel_scrollbar_hover:            FFCCCC4C
build_panel_scrollbar_background:       FF191F4C
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
ruler:                                  FCEDFC26
bracket_highlight:                      FF000026
indent_guide:                           FF000026
active_pane_border:                     19666688
inactive_pane_dim_overlay:              050505FF

FOCUS_CONFIG


COLORS_2 :: #string FOCUS_CONFIG
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

cursor_inactive:                        AABBCCFF

FOCUS_CONFIG

COLORS_2_EXPECTED :: #string FOCUS_CONFIG
[!latest!]  # Version number. Do not delete.

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

cursor_inactive:                        AABBCCFF

# Added after migration to version [!latest!]
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
ruler:                                  AABBCCFF
bracket_highlight:                      E8FCFE30
indent_guide:                           FCEDFC26
active_pane_border:                     AABBCCFF
inactive_pane_dim_overlay:              050505FF

FOCUS_CONFIG


// Test that new colors and settings are added correctly when they are both present

COLORS_AND_SETTINGS_1 :: #string FOCUS_CONFIG
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

COLORS_AND_SETTINGS_1_EXPECTED :: #string FOCUS_CONFIG
[!latest!]  # Version number. Do not delete.

[[workspace]]
# These directories and files will be scanned when a workspace is opened so that search etc. works.

[file associations]
# Optional file associations in the format `<wildcard1> <wildcard2> ... : <language>`
# Example:
# *.hpp *.hh *.h : cpp
# todo.txt : todo


[[settings]]

maximize_on_start:                      false
tab_size:                               4
build_panel_width_percent:              50
indent_using:                           spaces  # options: spaces, tabs
prefer_system_file_dialogs:             false  # Windows only
status_bar_show_cursors_off_screen:     true

# Added after migration to version [!latest!]
build_panel_height_percent:                      50
build_panel_stays_in_one_place:                  false  # if false, the build panel will flip to the inactive pane in two pane layouts
build_panel_line_wrap_always_on:                 true
highlight_line_with_cursor:                      false
draw_indent_guides:                              false
auto_surround_with_brackets_and_quotes:          false
scroll_beyond_last_line:                         true
persist_local_search_results:                    false  # if true, search results will stay highlighted and you have to dismiss them using the `escape` action
save_current_buffer_on_build:                    false
save_all_file_backed_buffers_on_build:           false
disable_viewport_chasing_cursor_near_the_edge:   false  # if true, the viewport will not scroll smoothly to cursor when you move the cursor outside it by small amounts
status_bar_show_selected_text_length:            false
window_width:                                    -1
window_height:                                   -1
insert_final_newline_on_save:                    false
status_bar_position:                             bottom  # options: top, bottom
load_most_recent_project_on_start:               false
color_preview_popup:                             enabled  # options: enabled, minimized, disabled
highlight_matching_brackets:                     false
search_is_case_sensitive_when_uppercase_present: false
projects_sorting_order:                          most_recent_first  #options: most_recent_first, alphabetical, alphabetical_no_case
show_ruler_at_column:                            0
detect_indentation:                              true  # if true, existing files will be scanned to detect indentation, new files will use the `indent_using` and `tab_size` settings
status_bar_show_indentation:                     true
status_bar_show_line_col:                        true
show_scrollbar_marks:                            true
scrollbar_width_scale:                           1.0
scrollbar_min_opacity:                           0.0   # if you want the scrollbar to be always visible, set this to 1.0
scrollbar_max_opacity:                           1.0
scrollbar_fade_in_sensitivity:                   10.0  # controls when the scrollbar appears as the mouse pointer gets close
scrollbar_fade_out_delay_seconds:                1.0   # how long the scrollbar stays visible after scrolling
scroll_behind_first_line:                        false
active_pane_border_width:                        1.0   # set the width to 0.0 to disable
inactive_pane_dim_overlay_opacity:               0.1   # controls how dim the inactive panes should be

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

# Added after migration to version [!latest!]
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
build_panel_scrollbar_hover:            FFCCCC4C
build_panel_scrollbar_background:       FF191F4C
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
ruler:                                  FCEDFC26
bracket_highlight:                      E8FCFE30
indent_guide:                           FCEDFC26
active_pane_border:                     19666688
inactive_pane_dim_overlay:              050505FF

FOCUS_CONFIG


KEYBINDS_1 :: #string FOCUS_CONFIG
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
Alt-F1                      do_nothing

Ctrl-1                      switch_to_left_editor
Ctrl-2                      switch_to_right_editor
Ctrl-,                      switch_to_other_editor

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

KEYBINDS_1_EXPECTED :: #string FOCUS_CONFIG
[!latest!]  # Version number. Do not delete.

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

# Added after migration to version [!latest!]
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
build_panel_scrollbar_hover:            FFCCCC4C
build_panel_scrollbar_background:       FF191F4C
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
ruler:                                  FCEDFC26
bracket_highlight:                      E8FCFE30
indent_guide:                           FCEDFC26
active_pane_border:                     19666688
inactive_pane_dim_overlay:              050505FF

[[keymap]]

# - The first matching combination will be used, so order matters

[editors]   # <- this means that the following key combos will apply only when editing text

Alt-F4                      quit
Escape                      escape
Ctrl-Escape                 remove_additional_cursors

Ctrl-,                      switch_to_side_pane

Ctrl-D                      select_word_or_create_another_cursor
Ctrl-Shift-A                select_all_occurrences

# Added after migration to version [!latest!]
Alt-Shift-I                 add_cursors_to_line_ends
Alt-Shift-Ctrl-I            add_cursors_to_line_starts
Alt-A                       align_cursors
Ctrl-U                      change_case_cycle
Ctrl-R                      revert_select_word_or_create_another_cursor
Ctrl-Y                      move_selection_to_next_word
{Shift}-Meta-ArrowLeft      move_left_through_word
{Shift}-Meta-ArrowRight     move_right_through_word
{Shift}-Meta-Backspace      delete_left_through_word
{Shift}-Meta-Delete         delete_right_through_word
Ctrl-Alt-S ArrowLeft        move_editor_left
Ctrl-Alt-S ArrowRight       move_editor_right
Ctrl-Alt-S ArrowUp          move_editor_top
Ctrl-Alt-S ArrowDown        move_editor_bottom
Ctrl-Alt-X ArrowLeft        split_left
Ctrl-Alt-X ArrowRight       split_right
Ctrl-Alt-X ArrowUp          split_top
Ctrl-Alt-X ArrowDown        split_bottom
Ctrl-Alt-D ArrowLeft        duplicate_editor_left
Ctrl-Alt-D ArrowRight       duplicate_editor_right
Ctrl-Alt-D ArrowUp          duplicate_editor_top
Ctrl-Alt-D ArrowDown        duplicate_editor_bottom
Ctrl-Shift-T                reopen_closed_editor

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

# Added after migration to version [!latest!]
Ctrl-B                      build_panel_toggle
F11                         toggle_fullscreen
Ctrl-Tab                    switch_between_open_files
Ctrl-Shift-Alt-N            open_another_editor_instance
F8                          go_to_next_build_error
Ctrl-F8                     go_to_next_build_error_in_side_pane
Shift-F8                    go_to_previous_build_error
Shift-Ctrl-F8               go_to_previous_build_error_in_side_pane
{Shift}-Ctrl-M              jump_to_matching_bracket
Enter                       open_entry
Tab                         focus_next_ui_element
Shift-Tab                   focus_previous_ui_element
Ctrl-Shift-W                close_pane
Ctrl-Alt-W ArrowLeft        close_left_pane
Ctrl-Alt-W ArrowRight       close_right_pane
Ctrl-Alt-W ArrowUp          close_top_pane
Ctrl-Alt-W ArrowDown        close_bottom_pane
Ctrl-Shift-Alt-W            close_other_panes
Ctrl-Shift-1                switch_to_top_pane
Ctrl-Shift-2                switch_to_bottom_pane
Ctrl-Alt-Shift-ArrowLeft    switch_to_left_pane
Ctrl-Alt-Shift-ArrowRight   switch_to_right_pane
Ctrl-Alt-Shift-ArrowUp      switch_to_top_pane
Ctrl-Alt-Shift-ArrowDown    switch_to_bottom_pane
Ctrl-1                      switch_to_pane_1
Ctrl-2                      switch_to_pane_2
Ctrl-3                      switch_to_pane_3
Ctrl-4                      switch_to_pane_4
Ctrl-5                      switch_to_pane_5
Ctrl-6                      switch_to_pane_6
Ctrl-7                      switch_to_pane_7
Ctrl-8                      switch_to_pane_8
Ctrl-9                      switch_to_pane_9

FOCUS_CONFIG


KEYBINDS_2 :: #string FOCUS_CONFIG
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
Ctrl-P                      show_open_file_dialog_in_search_mode
Ctrl-O                      show_open_file_dialog_in_navigate_mode
Ctrl-Shift-O                show_open_file_dialog_in_navigate_mode_from_root
Ctrl-Tab                    show_open_file_dialog_in_open_editors_mode

Ctrl-Alt-P                  switch_to_project

[search dialog]
Enter                       open_entry

FOCUS_CONFIG

KEYBINDS_2_EXPECTED :: #string FOCUS_CONFIG
[!latest!]  # Version number. Do not delete.

[[keymap]]

# - The first matching combination will be used, so order matters

[editors]   # <- this means that the following key combos will apply only when editing text

Alt-F4                      quit
Escape                      escape
Ctrl-Escape                 remove_additional_cursors

Ctrl-D                      select_word_or_create_another_cursor
Ctrl-Shift-A                select_all_occurrences

# Added after migration to version [!latest!]
Ctrl-U                      change_case_cycle
Ctrl-R                      revert_select_word_or_create_another_cursor
Ctrl-Y                      move_selection_to_next_word
{Shift}-Meta-ArrowLeft      move_left_through_word
{Shift}-Meta-ArrowRight     move_right_through_word
{Shift}-Meta-Backspace      delete_left_through_word
{Shift}-Meta-Delete         delete_right_through_word

[open file dialog]
Tab                         open_directory

[common]
Ctrl-P                      open_file_by_name
Ctrl-O                      navigate_to_file
Ctrl-Shift-O                navigate_to_file_from_root
Ctrl-Tab                    switch_between_open_files

Ctrl-Alt-P                  switch_to_project

# Added after migration to version [!latest!]
Ctrl-Shift-Alt-N            open_another_editor_instance
F8                          go_to_next_build_error
Ctrl-F8                     go_to_next_build_error_in_side_pane
Shift-F8                    go_to_previous_build_error
Shift-Ctrl-F8               go_to_previous_build_error_in_side_pane
{Shift}-Ctrl-M              jump_to_matching_bracket
Enter                       open_entry
Tab                         focus_next_ui_element
Shift-Tab                   focus_previous_ui_element
Ctrl-Shift-W                close_pane
Ctrl-Alt-W ArrowLeft        close_left_pane
Ctrl-Alt-W ArrowRight       close_right_pane
Ctrl-Alt-W ArrowUp          close_top_pane
Ctrl-Alt-W ArrowDown        close_bottom_pane
Ctrl-Shift-Alt-W            close_other_panes
Ctrl-Shift-1                switch_to_top_pane
Ctrl-Shift-2                switch_to_bottom_pane
Ctrl-Alt-Shift-ArrowLeft    switch_to_left_pane
Ctrl-Alt-Shift-ArrowRight   switch_to_right_pane
Ctrl-Alt-Shift-ArrowUp      switch_to_top_pane
Ctrl-Alt-Shift-ArrowDown    switch_to_bottom_pane
Ctrl-1                      switch_to_pane_1
Ctrl-2                      switch_to_pane_2
Ctrl-3                      switch_to_pane_3
Ctrl-4                      switch_to_pane_4
Ctrl-5                      switch_to_pane_5
Ctrl-6                      switch_to_pane_6
Ctrl-7                      switch_to_pane_7
Ctrl-8                      switch_to_pane_8
Ctrl-9                      switch_to_pane_9

[search dialog]
Enter                       open_entry

# Added after migration to version [!latest!]
Tab                         go_to_next_input
Shift-Tab                   go_to_previous_input

FOCUS_CONFIG

// Test that themes can be migrated properly

THEME_1 :: #string FOCUS_CONFIG
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

THEME_1_EXPECTED :: #string FOCUS_CONFIG
[!latest!]  # Version number. Do not delete.

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

# Added after migration to version [!latest!]
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
build_panel_scrollbar_hover:            FFCCCC4C
build_panel_scrollbar_background:       FF191F4C
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
ruler:                                  FCEDFC26
bracket_highlight:                      E8FCFE30
indent_guide:                           FCEDFC26
active_pane_border:                     19666688
inactive_pane_dim_overlay:              050505FF

FOCUS_CONFIG


THEME_3 :: #string FOCUS_CONFIG
[3]  # Version number. Do not delete

[colors]

background0:                            161616FF
background1:                            141414FF
background2:                            18262FFF # unused
background3:                            121212FF
background4:                            121212FF
selection_active:                       0100CDFF
selection_inactive:                     0100CD7F
selection_highlight:                    FCEDFC26 # todo
search_result_active:                   B55F75FF
search_result_inactive:                 B55F754C
scrollbar:                              CDAA7D19
scrollbar_hover:                        CDAA7D4C
scrollbar_background:                   CDAA7D11
cursor:                                 40FF40FF
cursor_inactive:                        40FF4011
paste_animation:                        0100CDFF
splitter:                               CDAA7D19
splitter_hover:                         CDAA7D4C
letter_highlight:                       B8860BFF
list_cursor_lite:                       CDAA7D19
list_cursor:                            CDAA7D4C
shadow_dark:                            1010107F
shadow_transparent:                     10101000
text_input_label:                       7F7F7FFF
char_under_cursor:                      161616FF

ui_default:                             CDAA7DFF
ui_dim:                                 7F7F7FFF
ui_neutral:                             7F7F7FFF
ui_warning:                             FFAD34FF # todo
ui_warning_dim:                         986032FF # todo
ui_error:                               772222FF # todo
ui_error_bright:                        FF0000FF # todo
ui_success:                             227722FF # todo

code_default:                           CDAA7DFF
code_comment:                           7F7F7FFF
code_type:                              B8860BFF
code_function:                          CDAA7DFF
code_punctuation:                       CDAA7DFF
code_operation:                         CDAA7DFF
code_string:                            6B8E23FF
code_value:                             6B8E23FF
code_highlight:                         D89B75FF # unused
code_error:                             FF0000FF # todo
code_warning:                           E4D97DFF # todo
code_keyword:                           B8860BFF

region_scope_export:                    161616FF
region_scope_file:                      161616FF
region_scope_module:                    161616FF
region_header:                          161616FF
region_success:                         227722FF # todo
region_warning:                         986032FF # todo
region_error:                           772222FF # todo
region_heredoc:                         121212FF

build_panel_background:                 161616FF
build_panel_scrollbar:                  CDAA7D19
build_panel_scrollbar_hover:            CDAA7D4C
build_panel_scrollbar_background:       CDAA7D11
build_panel_title_bar:                  121212FF

FOCUS_CONFIG

THEME_3_EXPECTED :: #string FOCUS_CONFIG
[!latest!]  # Version number. Do not delete.

[colors]

background0:                            161616FF
background1:                            141414FF
background2:                            18262FFF # unused
background3:                            121212FF
background4:                            121212FF
selection_active:                       0100CDFF
selection_inactive:                     0100CD7F
selection_highlight:                    FCEDFC26 # todo
search_result_active:                   B55F75FF
search_result_inactive:                 B55F754C
scrollbar:                              CDAA7D19
scrollbar_hover:                        CDAA7D4C
scrollbar_background:                   CDAA7D11
cursor:                                 40FF40FF
cursor_inactive:                        40FF4011
paste_animation:                        0100CDFF
splitter:                               141414FF
splitter_hover:                         CDAA7D4C
letter_highlight:                       B8860BFF
list_cursor_lite:                       CDAA7D19
list_cursor:                            CDAA7D4C
shadow_dark:                            1010107F
shadow_transparent:                     10101000
text_input_label:                       7F7F7FFF
char_under_cursor:                      161616FF

ui_default:                             CDAA7DFF
ui_dim:                                 7F7F7FFF
ui_neutral:                             7F7F7FFF
ui_warning:                             FFAD34FF # todo
ui_warning_dim:                         986032FF # todo
ui_error:                               772222FF # todo
ui_error_bright:                        FF0000FF # todo
ui_success:                             227722FF # todo

code_default:                           CDAA7DFF
code_comment:                           7F7F7FFF
code_type:                              B8860BFF
code_function:                          CDAA7DFF
code_punctuation:                       CDAA7DFF
code_operation:                         CDAA7DFF
code_string_literal:                    6B8E23FF
code_value:                             6B8E23FF
code_highlight:                         D89B75FF # unused
code_error:                             FF0000FF # todo
code_warning:                           E4D97DFF # todo
code_keyword:                           B8860BFF

region_scope_export:                    161616FF
region_scope_file:                      161616FF
region_scope_module:                    161616FF
region_header:                          161616FF
region_success:                         227722FF # todo
region_warning:                         986032FF # todo
region_error:                           772222FF # todo
region_heredoc:                         121212FF

build_panel_background:                 161616FF
build_panel_scrollbar:                  CDAA7D19
build_panel_scrollbar_hover:            CDAA7D4C
build_panel_scrollbar_background:       CDAA7D11
build_panel_title_bar:                  121212FF

# Added after migration to version [!latest!]
code_invalid:                           FF0000FF
code_multiline_string:                  6B8E23FF
code_raw_string:                        6B8E23FF
code_char_literal:                      6B8E23FF
code_identifier:                        CDAA7DFF
code_note:                              CDAA7DFF
code_number:                            6B8E23FF
code_multiline_comment:                 7F7F7FFF
code_modifier:                          B8860BFF
code_attribute:                         B8860BFF
code_enum_variant:                      CDAA7DFF
code_macro:                             CDAA7DFF
code_builtin_variable:                  6B8E23FF
code_builtin_function:                  CDAA7DFF
code_builtin_exception:                 CDAA7DFF
code_directive:                         B8860BFF
code_directive_modifier:                B8860BFF
code_header:                            B8860BFF
code_header2:                           CDAA7DFF
code_header3:                           CDAA7DFF
code_header4:                           CDAA7DFF
code_header5:                           CDAA7DFF
code_header6:                           CDAA7DFF
ruler:                                  40FF4011
bracket_highlight:                      FCEDFC26
indent_guide:                           FCEDFC26
active_pane_border:                     40FF4011
inactive_pane_dim_overlay:              050505FF

FOCUS_CONFIG
