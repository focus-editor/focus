// Parser will be configured by a metaprogram below using the following section definitions
CONFIG_SECTIONS :: Config_Section.[
    .{
        name = "workspace",
        subsections = .[
            "ignore",
            "allow",
            "file associations",
        ],
        parse_function = "parse_workspace_line",
        allow_lines_outside_subsection = true,
    },
    .{
        name = "settings",
        parse_function = "parse_settings_line",
        allow_arbitrary_subsections = true,
    },
    .{
        name = "keymap",
        subsections = .[
            "editors",
            "open file dialog",
            "search dialog",
            "common",
        ],
        parse_function = "parse_keymap_line",
    },
    .{
        name = "style",
        subsections = .[
            "fonts",
            "colors",
        ],
        parse_function = "parse_style_line",
        allow_lines_outside_subsection = true,
    },
    .{
        name = "build commands",
        parse_function = "parse_build_line",
        allow_arbitrary_subsections = true,
    },
    .{
        name = "linux",
        parse_function = "parse_linux_config_line",
    },
];

parse_config :: (name: string, file_path: string, file_data: string, for_highlighting := false, as_theme := false) -> Config_Parse_Result {
    // NOTE: This function allocates a lot and never frees.
    if !#compile_time  assert(context.allocator.proc == flat_pool_allocator_proc || context.allocator.proc == temp.proc, "parse_config must use a pool or a temp allocator");

    using parser: Config_Parser;
    parser.parse_for_highlighting = for_highlighting;
    parser.parse_as_theme = as_theme;
    if file_path then parser.config_path = get_parent_dir_path(file_path);

    trimmed_data := trim_left(file_data, " \t\n\r");  // skip empty lines, otherwise the handler will crash!
    start_from_memory(*handler, name, file_path, trimmed_data);
    if handler.failed {
        result.error_msg = tprint("Couldn't parse file '%'.\nPlease check that the version number is specified at the top in brackets, otherwise check the error log.", file_path);
        return result;
    }

    result.error_msg = "";
    result.config.version = ifx handler.version > 0 then handler.version else CURRENT_CONFIG_VERSION;

    if result.config.version != CURRENT_CONFIG_VERSION {
        // We will still attempt to parse the config, but it's expected that it can fail when there's a version mismatch
        error_msg := tprint("Invalid version [%] in file '%'. The only supported version is [%].", result.config.version, file_path, CURRENT_CONFIG_VERSION);
        array_add(*result.warnings, error_msg);
    }

    if as_theme then active_section = .style;

    while true {
        line, found := consume_next_line(*handler);
        if !found break;

        line_start_offset = cast(s32) (line.data - file_data.data);

        // Maybe switch sections
        if begins_with(line, "[") {
            handled, error_msg := maybe_switch_section(*parser, line, fix_section = ifx parse_as_theme then .style else .none);
            if error_msg {
                add_highlight(*parser, 0, line.count, .error);
                array_add(*result.warnings, log_parser_error(parser, error_msg));
            }
            if handled continue;
        }

        // Check if we have an active_section
        if active_section == .none {
            add_highlight(*parser, 0, line.count, .error);
            error_msg := log_parser_error(parser, "Line outside of any section: '%'. This is an error.", line);
            array_add(*result.warnings, error_msg);
            continue;
        }

        // Check if we allow lines outside of subsection
        if active_subsection == .none && !section_allows_lines_outside_subsection(active_section) {
            add_highlight(*parser, 0, line.count, .error);
            error_msg := log_parser_error(parser, "Line outside of subsection: '%'. This is an error.", line);
            array_add(*result.warnings, error_msg);  // not a big deal
            continue;
        }

        // Parse a line from within a section
        success:   bool;
        error_msg: string;
        #insert -> string {
            b: String_Builder;

            append(*b, "if #complete active_section == {\n");
            for section : CONFIG_SECTIONS {
                print_to_builder(*b, "    case .%;  success, error_msg = %(*parser, line);\n", replace(section.name, " ", "_"), section.parse_function);
            }
            code := #string JAI
                case .none;
                    if !parse_for_highlighting {
                        result.error_msg = log_parser_error(parser, "Expected a top-level section definition, got '%%'", line);
                        return result;
                    }
            JAI
            print_to_builder(*b, code);
            append(*b, "}\n");

            return builder_to_string(*b);
        }

        if error_msg then error_msg = log_parser_error(parser, error_msg);  // enrich with file/line information

        if !success && !parse_for_highlighting {
            result.error_msg = error_msg;
            return result;
        }
        if success && error_msg then array_add(*result.warnings, error_msg);
    }

    // Detect color reference loops and highlight them
    // TODO: @colorref

    // Mix the common key mappings into every keymap to support common actions
    array_add(*result.config.keymap_editors,          ..result.config.keymap_common);
    array_add(*result.config.keymap_open_file_dialog, ..result.config.keymap_common);
    array_add(*result.config.keymap_search_dialog,    ..result.config.keymap_common);

    // Clamp overridden values
    // TODO: maybe combine with the clamping code in apply_config somehow
    for * result.config.file_specific_settings {
        if it.overrides.tab_size.is_set then Clamp(*it.overrides.tab_size.value, 1, 100);
    }

    result.success   = true;

    return result;
}

keymap_map_key_code_to_string :: (key_code: u32) -> string /* temp */ {
    if #char "!" <= key_code && key_code <= #char "~" {
        // Ascii printable range
        s: string;
        s.data  = xx *key_code;
        s.count = 1;
        return tprint("%", s);  // couldn't find a way to print a char
    }

    for STRING_TO_CODE_MAP {
        if cast(u32) it.code == key_code return it.str;
    }

    return "??";
}

get_theme_file_from_name :: (name: string) -> string /* temp */ {
    theme_name := to_lower_copy(name,, temp);
    return tprint("%/%.focus-theme", themes_dir, theme_name);
}


#scope_file

map_name_to_color :: (name: string) -> Color {
    if begins_with(name, "code_") {
        // Use the Token_Type enum to validate the name and map into Color
        advance(*name, "code_".count);
        valid_token_names := type_info(Token_Type).names;
        found, idx := array_find(valid_token_names, name);
        if found return xx idx;
    }

    if name == {
        case "background0";                             return .BACKGROUND_0;
        case "background1";                             return .BACKGROUND_1;
        case "background2";                             return .BACKGROUND_2;
        case "background3";                             return .BACKGROUND_3;
        case "background4";                             return .BACKGROUND_4;
        case "selection_active";                        return .SELECTION_ACTIVE;
        case "selection_inactive";                      return .SELECTION_INACTIVE;
        case "selection_highlight";                     return .SELECTION_HIGHLIGHT;
        case "bracket_highlight";                       return .BRACKET_HIGHLIGHT;
        case "search_result_active";                    return .SEARCH_RESULT_ACTIVE;
        case "search_result_inactive";                  return .SEARCH_RESULT_INACTIVE;
        case "scrollbar";                               return .SCROLLBAR;
        case "scrollbar_hover";                         return .SCROLLBAR_HOVER;
        case "scrollbar_background";                    return .SCROLLBAR_BACKGROUND;
        case "cursor";                                  return .CURSOR;
        case "cursor_inactive";                         return .CURSOR_INACTIVE;
        case "paste_animation";                         return .PASTE_ANIMATION;
        case "splitter";                                return .SPLITTER;
        case "splitter_hover";                          return .SPLITTER_HOVER;
        case "ruler";                                   return .RULER;
        case "indent_guide";                            return .INDENT_GUIDE;
        case "letter_highlight";                        return .LETTER_HIGHLIGHT;
        case "list_cursor_lite";                        return .LIST_CURSOR_LITE;
        case "list_cursor";                             return .LIST_CURSOR;
        case "shadow_dark";                             return .SHADOW_DARK;
        case "shadow_transparent";                      return .SHADOW_TRANSPARENT;
        case "text_input_label";                        return .TEXT_INPUT_LABEL;
        case "char_under_cursor";                       return .CHAR_UNDER_CURSOR;
        case "active_pane_border";                      return .ACTIVE_PANE_BORDER;
        case "inactive_pane_dim_overlay";               return .INACTIVE_PANE_DIM_OVERLAY;

        case "ui_default";                              return .UI_DEFAULT;
        case "ui_dim";                                  return .UI_DIM;
        case "ui_neutral";                              return .UI_NEUTRAL;
        case "ui_warning";                              return .UI_WARNING;
        case "ui_warning_dim";                          return .UI_WARNING_DIM;
        case "ui_error";                                return .UI_ERROR;
        case "ui_error_bright";                         return .UI_ERROR_BRIGHT;
        case "ui_success";                              return .UI_SUCCESS;

        case "region_scope_export";                     return .REGION_SCOPE_EXPORT;
        case "region_scope_file";                       return .REGION_SCOPE_FILE;
        case "region_scope_module";                     return .REGION_SCOPE_MODULE;
        case "region_header";                           return .REGION_HEADER;
        case "region_success";                          return .REGION_SUCCESS;
        case "region_warning";                          return .REGION_WARNING;
        case "region_error";                            return .REGION_ERROR;
        case "region_heredoc";                          return .REGION_HEREDOC;

        case "build_panel_background";                  return .BUILD_PANEL_BACKGROUND;
        case "build_panel_scrollbar";                   return .BUILD_PANEL_SCROLLBAR;
        case "build_panel_scrollbar_hover";             return .BUILD_PANEL_SCROLLBAR_HOVER;
        case "build_panel_scrollbar_background";        return .BUILD_PANEL_SCROLLBAR_BACKGROUND;
        case "build_panel_title_bar";                   return .BUILD_PANEL_TITLE_BAR;
    }

    return .NONE;
}

add_highlight :: inline (parser: *Config_Parser, offset_from_line_start: s64, count: s64, type: Token_Type, line_start_offset := -1) {
    if !parser.parse_for_highlighting return;

    offset := parser.line_start_offset + offset_from_line_start;
    if line_start_offset >= 0 then offset = line_start_offset + offset_from_line_start;

    array_add(
        *parser.result.highlights,
        Code_Highlight.{ offset = cast(s32) offset, count = cast(s32) count, token_type = type },
    );
}

keymap_map_key_string :: (key_string: string) -> u32 {
    for STRING_TO_CODE_MAP {
        if equal_nocase(key_string, it.str) {
            return cast(u32) it.code;
        }
    }
    return 0;
}

log_parser_error :: (parser: Config_Parser, format: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) -> string {
    if parser.parse_for_highlighting return "";  // Don't want to log anything

    // Like the "error" function in the handler module, but it also returns the message because we want it
    new_format := tprint("Line % of '%': %", parser.handler.line_number, parser.handler.full_path, format);
    message := tprint(new_format, .. args);
    log(message, flags=Log_Flags.ERROR|flags, loc=loc);

    return message;
} @PrintLike

Str_Code :: struct { str: string; code: Input.Key_Code; }
using Input.Key_Code;
STRING_TO_CODE_MAP :: Str_Code.[
    .{ "ArrowUp",           ARROW_UP },
    .{ "ArrowDown",         ARROW_DOWN },
    .{ "ArrowLeft",         ARROW_LEFT },
    .{ "ArrowRight",        ARROW_RIGHT },

    .{ "Escape",            ESCAPE },
    .{ "Delete",            DELETE },
    .{ "Insert",            INSERT },
    .{ "End",               END },
    .{ "Home",              HOME },
    .{ "Backspace",         BACKSPACE },
    .{ "PrintScreen",       PRINT_SCREEN },
    .{ "Pause",             PAUSE },
    .{ "PageUp",            PAGE_UP },
    .{ "PageDown",          PAGE_DOWN },
    .{ "ScrollLock",        SCROLL_LOCK },
    .{ "Enter",             ENTER },
    .{ "Return",            ENTER },
    .{ "Tab",               TAB },
    .{ "Shift",             SHIFT },
    .{ "Alt",               ALT },
    .{ "Control",           CTRL },
    .{ "Space",             #char " " },
    .{ "Plus",              #char "+" },
    .{ "Minus",             #char "-" },

    .{ "F1",                F1  },
    .{ "F2",                F2  },
    .{ "F3",                F3  },
    .{ "F4",                F4  },
    .{ "F5",                F5  },
    .{ "F6",                F6  },
    .{ "F7",                F7  },
    .{ "F8",                F8  },
    .{ "F9",                F9  },
    .{ "F10",               F10 },
    .{ "F11",               F11 },
    .{ "F12",               F12 },

    .{ "F13",               F13 },
    .{ "F14",               F14 },
    .{ "F15",               F15 },
    .{ "F16",               F16 },
    .{ "F17",               F17 },
    .{ "F18",               F18 },
    .{ "F19",               F19 },
    .{ "F20",               F20 },
    .{ "F21",               F21 },
    .{ "F22",               F22 },
    .{ "F23",               F23 },
    .{ "F24",               F24 },

    .{ "Numpad0",           NUMPAD_0 },
    .{ "Numpad1",           NUMPAD_1 },
    .{ "Numpad2",           NUMPAD_2 },
    .{ "Numpad3",           NUMPAD_3 },
    .{ "Numpad4",           NUMPAD_4 },
    .{ "Numpad5",           NUMPAD_5 },
    .{ "Numpad6",           NUMPAD_6 },
    .{ "Numpad7",           NUMPAD_7 },
    .{ "Numpad8",           NUMPAD_8 },
    .{ "Numpad9",           NUMPAD_9 },
    .{ "NumpadMultiply",    NUMPAD_MULTIPLY },
    .{ "NumpadDivide",      NUMPAD_DIVIDE },
    .{ "NumpadAdd",         NUMPAD_ADD },
    .{ "NumpadSubtract",    NUMPAD_SUBTRACT },
    .{ "NumpadDecimal",     NUMPAD_DECIMAL },
    .{ "NumpadEnter",       NUMPAD_ENTER },

    .{ "MouseLeft",         MOUSE_BUTTON_LEFT },
    .{ "MouseRight",        MOUSE_BUTTON_RIGHT },
    .{ "MouseMiddle",       MOUSE_BUTTON_MIDDLE },
    .{ "MouseX1",           MOUSE_BUTTON_X1 },
    .{ "MouseX2",           MOUSE_BUTTON_X2 },

    // We don't support mouse wheel events because we'd need to block scrolling
    // if they are handled and we don't want to do it just yet.
    // .{ "MouseWheelUp",      MOUSE_WHEEL_UP },
    // .{ "MouseWheelDown",    MOUSE_WHEEL_DOWN },
];

maybe_switch_section :: (using parser: *Config_Parser, line: string, fix_section := Section.none) -> handled: bool, error: string {
    if begins_with(line, "[[") {
        if fix_section != .none return true, tprint("No top-level sections are allowed here (section is fixed to [[%]])", fix_section);

        // Top section
        if !ends_with(line, "]]") return true, tprint("Invalid section '%'. Section definitions must end with ]]", line);
        section_name := trim(line, " \t[]");

        #insert -> string {
            b: String_Builder;
            append(*b, "if section_name == {\n");
            for section : CONFIG_SECTIONS {
                code := #string JAI
                    case "%1";
                        active_section = .%2;
                        active_subsection = .none;
                        section_offset = line_start_offset;
                        if seen_sections & .%2 return true, tprint("Section [[%1]] is defined twice. This is an error.");
                        seen_sections |= .%2;
                JAI
                print_to_builder(*b, code, section.name, replace(section.name, " ", "_"));
            }
            code := #string JAI
                case;
                    return true, tprint("Unknown top-level section %%", line);
            JAI
            print_to_builder(*b, code);
            append(*b, "}\n");
            return builder_to_string(*b);
        }
        add_highlight(parser, 0, line.count, .header);

        if active_section == .style then result.config.offsets.style_section = line_start_offset;

        if result.config.offsets.colors_section_start >= 0 && result.config.offsets.colors_section_end < 0 then result.config.offsets.colors_section_end = line_start_offset;

    } else {
        // Subsection
        if !ends_with(line, "]") return true, tprint("Invalid subsection '%'. Subsection definitions must end with ]", line);
        if active_section == .none return true, tprint("Subsection '%' is outside of any section. This is an error.", line);
        if section_allows_arbitrary_subsections(active_section) return false, "";  // pass it on to the line parser

        subsection_name := trim(line, " \t[]");

        section := CONFIG_SECTIONS[active_section];
        if !array_find(section.subsections, subsection_name) {
            if section.subsections {
                return true, tprint("Unknown subsection of [[%]]: '%'.\nAvailable options: [%].", section.name, line, join(..section.subsections, "], [",, temp));
            } else {
                return true, tprint("Unexpected subsection of [[%]]: '%'. This section doesn't allow any subsections.", section.name, line);
            }
        }

        #insert -> string {
            b: String_Builder;
            append(*b, "if subsection_name == {\n");
            for section : CONFIG_SECTIONS {
                for subsection : section.subsections {
                    code := #string JAI
                        case "%1";
                            active_subsection = .%2;
                            section_offset = line_start_offset;
                            if seen_subsections & .%2 return true, tprint("Subsection [%1] is defined twice. This is an error.");
                            seen_subsections |= .%2;
                    JAI
                    print_to_builder(*b, code, subsection, replace(tprint("%_%", section.name, subsection), " ", "_"));
                }
            }
            append(*b, "}\n");
            return builder_to_string(*b);
        }

        if active_subsection == .style_colors {
            result.config.offsets.colors_section_start = line_start_offset;
        } else if result.config.offsets.colors_section_start >= 0 && result.config.offsets.colors_section_end < 0 {
            result.config.offsets.colors_section_end = line_start_offset;
        }

        if parse_as_theme && active_subsection != .style_colors return true, "";  // don't highlight any subsections other than colors

        add_highlight(parser, 0, line.count, .header2);
    }

    return true, "";
}

parse_workspace_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string /* temp */ {
    // Always highlight in default colors. If there's an issue with a workspace dir, we'll highlight the part which doesn't exist
    add_highlight(parser, 0, line.count, .default);

    if active_subsection == {
        case .none;
            path := copy_temporary_string(line);
            path_overwrite_separators(path, #char "/");
            path = trim_right(path, "/");
            relative_to_config := !is_absolute_path(path) && config_path;
            abs_path := path;
            if relative_to_config {
                if path == "." {
                    abs_path = config_path;
                } else {
                    abs_path = tprint("%/%", config_path, path);
                }
            }

            if file_exists(abs_path) {
                array_add(*result.config.members, copy_string(abs_path));
            } else {
                if parse_for_highlighting {
                    // Highlight the bad chunk
                    for chunk : split(path, "/",, temp) {
                        dir_prefix := slice(path, 0, chunk.data - path.data + chunk.count);
                        if !dir_prefix continue;
                        abs_dir_prefix := ifx relative_to_config then tprint("%/%", config_path, dir_prefix) else dir_prefix;
                        if !file_exists(abs_dir_prefix) {
                            add_highlight(parser, chunk.data - path.data, chunk.count, .error);
                            break;
                        }
                    }
                }
                return true, tprint("Attempted to load '%', but it doesn't exist", abs_path);
            }
        case .workspace_ignore;
            item := copy_string(trim(line, "\t "));
            item = trim_right(item, "/");
            path_overwrite_separators(item, #char "/");
            if begins_with(item, "./") {
                advance(*item, 2);
                // Add an expanded entry for each workspace dir
                for member : result.config.members {
                    is_dir, success := is_directory(member);
                    if !is_dir || !success  continue;
                    array_add(*result.config.ignore, sprint("%/%", member, item));
                }
            } else {
                array_add(*result.config.ignore, item);
            }

        case .workspace_allow;
            item := copy_string(trim(line, "\t "));
            item = trim_right(item, "/");
            path_overwrite_separators(item, #char "/");
            if begins_with(item, "./") {
                advance(*item, 2);
                // Add an expanded entry for each workspace dir
                for member : result.config.members {
                    is_dir, success := is_directory(member);
                    if !is_dir || !success  continue;
                    array_add(*result.config.allow, sprint("%/%", member, item));
                }
            } else {
                array_add(*result.config.allow, item);
            }

        case .workspace_file_associations;
            found, wildcards, lang_name := split_from_left(line, cast(u8) #char ":");
            wildcards, lang_name = trim(wildcards), trim(lang_name);
            if !found || !wildcards || !lang_name {
                add_highlight(parser, 0, line.count, .comment);  // don't scream at the user while they're typing
                return true, tprint("Invalid file association: '%'\nThe correct format is: '<wildcard1> <wildcard2> ... : <language>'", line);
            }
            lang, matched := get_lang_from_name(lang_name);
            if !matched {
                add_highlight(parser, lang_name.data - line.data, lang_name.count, .error);
                available_langs := #run get_supported_buffer_langs_lowercase();
                return true, tprint("Unknown language name: '%'\nAvailable languages:\n%", lang_name, join(..available_langs, ", ",, temp));
            }
            for split(wildcards, cast(u8) #char " ",, temp) {
                array_add(*result.config.file_associations, .{ wildcard = trim(it), lang = lang, });
            }
    }
    return true, "";
}

parse_style_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string /* temp */ {
    if parse_as_theme && active_subsection != .style_colors {
        add_highlight(parser, 0, line.count, .comment);
        return true, "";  // ignore anything that's not a color
    }
    add_highlight(parser, 0, line.count, .default);

    if active_subsection == {
        case .style_fonts;
            setting, value := break_by_spaces(line);
            setting = trim_right(setting, ":");

            font_settings := string.[ "font", "font_ui", "font_ui_bold", "font_size", "font_ui_size", "anti_aliasing", "hinting" ];
            if !array_find(font_settings, setting) {
                add_highlight(parser, 0, setting.count, .error);
                return true, tprint("Unknown font option '%'. Available options: ", setting, join(..font_settings, ", ",, temp));
            }

            if setting == {
                case "font";
                    found, error_msg := find_font_by_name(value);
                    if found {
                        result.config.font = value;
                    } else {
                        add_highlight(parser, value.data - line.data, value.count, .error);
                        result.config.font = "default";
                        return true, error_msg;
                    }
                case "font_ui";
                    found, error_msg := find_font_by_name(value);
                    if found {
                        result.config.font_ui = value;
                    } else {
                        add_highlight(parser, value.data - line.data, value.count, .error);
                        result.config.font_ui = "default";
                        return true, error_msg;
                    }
                case "font_ui_bold";
                    found, error_msg := find_font_by_name(value);
                    if found {
                        result.config.font_ui_bold = value;
                    } else {
                        add_highlight(parser, value.data - line.data, value.count, .error);
                        result.config.font_ui_bold = "default";
                        return true, error_msg;
                    }
                case "font_size";
                    value_copy := value;
                    int_val, success := parse_int(*value_copy);
                    if success {
                        result.config.font_size = int_val;
                    } else {
                        add_highlight(parser, value.data - line.data, value.count, .error);
                        result.config.font_size = DEFAULT_FONT_MAIN_SIZE;
                        return false, tprint("Couldn't parse '%' - expected a valid integer, got '%'", setting, value);
                    }
                case "font_ui_size";
                    value_copy := value;
                    int_val, success := parse_int(*value_copy);
                    if success {
                        result.config.font_ui_size = int_val;
                    } else {
                        add_highlight(parser, value.data - line.data, value.count, .error);
                        result.config.font_ui_size = DEFAULT_FONT_UI_SIZE;
                        return false, tprint("Couldn't parse '%' - expected a valid integer, got '%'", setting, value);
                    }
                case "anti_aliasing";
                    enum_info := type_info(Font_Anti_Aliasing);
                    found, idx := array_find(enum_info.names, value);
                    if found {
                        add_highlight(parser, cast(s64)(value.data - line.data), value.count, .value);
                        result.config.font_anti_aliasing = some(cast(Font_Anti_Aliasing) enum_info.values[idx]);
                    } else {
                        add_highlight(parser, cast(s64)(value.data - line.data), value.count, .error);
                        return true, tprint("Couldn't parse '%' - valid values: %", setting, enum_info.names);
                    }
                case "hinting";
                    value_copy := value;
                    bool_val, success := parse_bool(*value_copy);
                    if success {
                        add_highlight(parser, cast(s64)(value.data - line.data), value.count, .value);
                        result.config.font_hinting = some(bool_val);
                    } else {
                        add_highlight(parser, cast(s64)(value.data - line.data), value.count, .error);
                        return true, tprint("Couldn't parse '%1' - expected 'true' or 'false', got '%%'", value);
                    }
            }

        case .style_colors;
            if result.config.theme {
                add_highlight(parser, 0, line.count, .comment);
                return true, "";  // ignore all colors if theme is set
            }

            color_name, value := break_by_spaces(line);
            color_name = trim_right(color_name, ":");

            // Translate color name to color id
            color_id := map_name_to_color(color_name);
            if color_id == .NONE {
                add_highlight(parser, 0, color_name.count, .error);
                return true, tprint("Unknown color '%'", color_name);
            }

            if begins_with(value, "$") {
                // This color refers to another color @colorref
                ref_color_name := value;
                advance(*ref_color_name, 1);
                ref_color_id := map_name_to_color(ref_color_name);
                if ref_color_id == .NONE {
                    add_highlight(parser, value.data - line.data, value.count, .error);
                    return true, tprint("Attempted to reference an unknown color '$%'", ref_color_name);
                }
                add_highlight(parser, value.data - line.data, value.count, .value);
                array_add(*result.config.color_refs, .{
                    color_name = color_name,
                    color = color_id,
                    wants_to_use = ref_color_id,
                    line_start_offset = line_start_offset,
                    line_length = xx line.count,
                    section_offset = section_offset,
                });
            } else {
                // Try to parse the hex value
                color, success := hex_to_color_vec4(value);
                if !success {
                    add_highlight(parser, value.data - line.data, value.count, .error);
                    return true, tprint("Couldn't parse '%'. Expected a color in the form RRGGBB or RRGGBBAA, got '%'", color_name, value);
                }
                array_add(*result.config.colors, Parsed_Color.{ color_id, color });
            }

            // Detect duplicates
            is_duplicate := false;
            for seen_colors {
                if color_id != it.color continue;
                add_highlight(parser, 0, it.line_length,   .warning, line_start_offset = it.line_start_offset);
                add_highlight(parser, 0, color_name.count, .warning, line_start_offset = it.line_start_offset);
                is_duplicate = true;
            }
            if is_duplicate then add_highlight(parser, 0, line.count, .warning);

            array_add(*seen_colors, Seen_Color.{ line_start_offset = line_start_offset, line_length = xx line.count, color = color_id });

        case;
            if parse_as_theme {
                add_highlight(parser, 0, line.count, .error);
                return true, "Unexpected line outside of sections. Available section: [colors]";
            }

            setting, value := break_by_spaces(line);
            setting = trim_right(setting, ":");
            if setting == {
                case "theme";
                    result.config.offsets.theme_line = line_start_offset;

                    theme_file := get_theme_file_from_name(value);
                    if !file_exists(theme_file) && value != "default" {
                        add_highlight(parser, value.data - line.data, value.count, .error);
                        return true, tprint("Couldn't find theme file '%'", theme_file);
                    }
                    result.config.theme = value;

                    if !parse_for_highlighting {
                        theme_parse_result: Config_Parse_Result;

                        // Parse theme
                        if value != "default" {
                            file_data, success := read_entire_file(theme_file);
                            if !success return true, tprint("Couldn't read theme file '%'", theme_file);

                            migrated, new_file_data := maybe_migrate_config(theme_file, file_data);
                            if migrated {
                                add_success_message("Theme file '%' has been migrated to version [%]", theme_file, CURRENT_CONFIG_VERSION);
                                file_data = new_file_data;
                            }
                            theme_parse_result = parse_config(value, theme_file, file_data, as_theme = true);
                            if theme_parse_result.success && migrated then write_entire_file(theme_file, new_file_data);
                        } else {
                            theme_parse_result = parse_config(value, "default", DEFAULT_CONFIG_FILE_DATA);
                        }

                        if !theme_parse_result.success return true, tprint("Couldn't parse theme file '%'.\nError: %", theme_file, theme_parse_result.error_msg);

                        // Copy colors and font data (it points into the theme file data)
                        array_add(*result.config.colors, ..theme_parse_result.config.colors);
                        result.config.font         = theme_parse_result.config.font;
                        result.config.font_ui      = theme_parse_result.config.font_ui;
                        result.config.font_ui_bold = theme_parse_result.config.font_ui_bold;
                        result.config.font_size    = theme_parse_result.config.font_size;
                        result.config.font_ui_size = theme_parse_result.config.font_ui_size;

                        // If font details are not specified in the theme, assume default
                        if !result.config.font         then result.config.font         = "default";
                        if !result.config.font_ui      then result.config.font_ui      = "default";
                        if !result.config.font_ui_bold then result.config.font_ui_bold = "default";
                        if !result.config.font_size    then result.config.font_size    = DEFAULT_FONT_MAIN_SIZE;
                        if !result.config.font_ui_size then result.config.font_ui_size = DEFAULT_FONT_UI_SIZE;
                    }
                case;
                    add_highlight(parser, 0, setting.count, .error);
                    return true, tprint("Unknown style option '%'. Available option: theme.", setting);
            }
    }

    return true, "";
}

parse_build_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string /* temp */ {
    using result.config.build;

    line_parsed_with_error = false;  // reset

    if begins_with(line, "[") {
        // Add a new command
        name := trim(line, "[]");
        if !name {
            add_highlight(parser, 0, line.count, .error);
            return true, tprint("Command name can't be empty: %", line);
        }

        add_highlight(parser, 0, line.count, .header2);

        command := array_add(*commands);
        command.* = defaults;  // inherit everything from defaults
        command.name = name;

        section_offset = line_start_offset;

        return true, "";
    }

    add_highlight(parser, 0, line.count, .default);

    target := *defaults;
    if commands then target = *commands[commands.count-1];

    setting_name, setting_value := break_by_spaces(line);
    setting_name = trim_right(setting_name, ":");

    value := setting_value;  // will be destroyed by parsing

    #insert -> string {
        b: String_Builder;

        append(*b, "if setting_name == {\n");

        for option : type_info(Build_Command).members {
            if array_find(option.notes, "dontparse") continue;

            print_to_builder(*b, "    case \"%\";\n", option.name);

            if option.type.type == {
                case .BOOL;
                    code := #string JAI
                        val, success := parse_bool(*value);
                        if success {
                            target.%1 = val;
                            add_highlight(parser, setting_value.data - line.data, setting_value.count, .value);
                        } else {
                            add_highlight(parser, setting_value.data - line.data, setting_value.count, .error);
                            return true, tprint("Couldn't parse '%1' - expected 'true' or 'false', got '%%'", setting_value);
                        }
                    JAI
                    print_to_builder(*b, code, option.name);

                case .INTEGER;
                    code := #string JAI
                        val, success := parse_int(*value);
                        if success {
                            target.%1 = val;
                            add_highlight(parser, setting_value.data - line.data, setting_value.count, .value);
                        } else {
                            add_highlight(parser, setting_value.data - line.data, setting_value.count, .error);
                            return true, tprint("Couldn't parse '%1' - a valid integer, got '%%'", setting_value);
                        }
                    JAI
                    print_to_builder(*b, code, option.name);

                case .STRING;
                    code := #string JAI
                        if setting_value {
                            target.%1 = setting_value;  // points into the file data!
                        } else {
                            return true, tprint("Build command option '%%' can't be empty", setting_name);
                        }
                    JAI
                    print_to_builder(*b, code, option.name);

                    // Process working directories
                    if option.name == "build_working_dir" || option.name == "run_working_dir" {
                        code := #string JAI
                            // Exit early if variables are used in path
                            vars_used := false;
                            var_names := string.[
                                "%FILE%", "%FILE_DIR%", "%FILE_NAME%", "%FILE_NAME_NO_EXTENSION%", "%PROJECT_CONFIG_DIR%",
                            ];
                            for var : var_names {
                                start_index := 0;
                                while true {
                                    index := find_index_from_left(setting_value, var, start_index);
                                    if index < 0 break;
                                    start_index = index + var.count;
                                    add_highlight(parser, setting_value.data - line.data + index, var.count, .value);
                                    vars_used = true;
                                }
                            }
                            if vars_used return true, "";  // we're unable to validate it at this point
                        JAI
                        append(*b, code);

                        code = #string JAI
                            // Validate path and handle relative paths
                            dir_path := copy_temporary_string(setting_value);
                            path_overwrite_separators(dir_path, #char "/");
                            working_dir := get_working_directory_from_workspace(result.config.members);
                            relative_to_working_dir := !is_absolute_path(dir_path) && working_dir;
                            abs_path := ifx relative_to_working_dir then tprint("%%/%%", working_dir, dir_path) else dir_path;

                            if file_exists(abs_path) {
                                target.%1 = copy_string(abs_path);
                                return true, "";
                            } else {
                                if !is_absolute_path(dir_path) && !working_dir  return true, "";  // if the workspace is empty, don't check relative paths

                                // Highlight the bad chunk
                                for chunk : split(dir_path, "/",, temp) {
                                    dir_prefix := slice(dir_path, 0, chunk.data - dir_path.data + chunk.count);
                                    if !dir_prefix continue;
                                    abs_dir_prefix := ifx relative_to_working_dir then tprint("%%/%%", working_dir, dir_prefix) else dir_prefix;
                                    if !file_exists(abs_dir_prefix) {
                                        add_highlight(parser, setting_value.data - line.data + chunk.data - dir_path.data, chunk.count, .error);
                                        break;
                                    }
                                }
                                return true, tprint("Tried to use '%%' as a working dir in a build command, but it doesn't exist.", abs_path);
                            }
                        JAI
                        print_to_builder(*b, code, option.name);
                    }

                    // Highlight variables in the commands, if present
                    if option.name == "build_command" || option.name == "run_command" {
                        code := #string JAI
                            var_names := string.[
                                "%FILE%", "%FILE_DIR%", "%FILE_NAME%", "%FILE_NAME_NO_EXTENSION%",
                                "%BUILD_WORKING_DIR%", "%RUN_WORKING_DIR%", "%PROJECT_CONFIG_DIR%",
                            ];
                            for var : var_names {
                                start_index := 0;
                                while true {
                                    index := find_index_from_left(setting_value, var, start_index);
                                    if index < 0 break;
                                    start_index = index + var.count;
                                    add_highlight(parser, setting_value.data - line.data + index, var.count, .value);
                                }
                            }
                        JAI
                        append(*b, code);
                    }
            }
        }

        code := #string JAI
            case "key_binding";
                key_sequence, error_msg := parse_key_sequence(parser, setting_value, line);
                if !key_sequence return true, tprint("Invalid key combination: '%'. Error: %", setting_value, error_msg);
                add_keymap_for_build_command(*result.config.build, key_sequence);
                real_section_offset := section_offset;
                section_offset = 0;  // override to 0 so that keymaps are matched with other sections
                maybe_highlight_duplicate_keymaps(parser, line, key_sequence);
                section_offset = real_section_offset;
            case;
                add_highlight(parser, 0, line.count, .error);
                return true, tprint("Unrecognized build command option '%'.", setting_name);
        JAI
        append(*b, code);

        append(*b, "}\n");

        return builder_to_string(*b);
    }

    if setting_name == "error_regex" {
        _, regex_is_valid := re.compile(setting_value, .LikePerl & ~.OneLine);
        if !regex_is_valid {
            add_highlight(parser, setting_value.data - line.data, setting_value.count, .error);
            return true, tprint("Error regex is invalid: '%'", setting_value);
        }
    }

    if parse_for_highlighting && !line_parsed_with_error {
        // Highlight any duplicate settings
        is_duplicate := false;
        for seen_settings {
            if it.section_offset != section_offset || it.setting_name != setting_name continue;
            add_highlight(parser, 0, it.line_length,        .comment, line_start_offset = it.line_start_offset);
            add_highlight(parser, 0, it.setting_name.count, .warning, line_start_offset = it.line_start_offset);
            is_duplicate = true;
        }
        if is_duplicate then add_highlight(parser, 0, line.count, .warning);

        array_add(*seen_settings, Seen_Setting.{
            line_start_offset  = line_start_offset,
            line_length        = xx line.count,
            setting_name       = setting_name,
            section_offset     = section_offset,
        });
    }

    return true, "";
}

add_keymap_for_build_command :: (build_config: *Build_Config, key_sequence: [] Key_Combo) {
    current_command := cast(u32) build_config.commands.count;  // indexed starting from 1 (0 is reserved for the default one)

    for * build_config.keymap {
        if it.action == current_command {
            // Handle the rare case when the user specified 2 key bindings for the same action,
            // in this case we just use the most recent one, which matches existing duplicate highlighting
            it.key_sequence = key_sequence;
            return;
        }
    }

    array_add(*build_config.keymap, Key_Mapping.{ key_sequence, current_command });
}

parse_settings_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string /* temp */ {
    if begins_with(line, "[") && ends_with(line, "]") {
        add_highlight(parser, 0, line.count, .header2);

        // Start a new file-specific section
        match_rule := trim(line, "[] ");

        wildcards: [..] string;
        langs: [..] Buffer.Lang;

        if begins_with_nocase(match_rule, "file:") {
            advance(*match_rule, 5);
            for wildcard : split(match_rule, cast(u8) #char ",") {
                array_add(*wildcards, copy_string(trim(wildcard)));
            }
        } else if begins_with_nocase(match_rule, "lang:") {
            advance(*match_rule, 5);
            available_langs :: #run get_supported_buffer_langs_lowercase();
            for lang_name : split(match_rule, cast(u8) #char ",",, temp) {
                lang, matched := get_lang_from_name(trim(lang_name));
                if matched {
                    array_add(*langs, lang);
                } else if lang_name {
                    add_highlight(parser, lang_name.data - line.data, lang_name.count, .error);
                    return true, tprint("Unknown language name: '%'\nAvailable languages:\n%", lang_name, join(..available_langs, ", ",, temp));
                } else {
                    return true, tprint("Expected language name. Available languages:\n%", join(..available_langs, ", ",, temp));
                }
            }
        } else {
            add_highlight(parser, 0, line.count, .error);
            return true, tprint("Expected a file-specific settings subsection of the form [file: <wildcard1>, <wildcard2>, ...], or [lang: <lang1>, <lang2>, ...], got:\n%", line);
        }

        new_setting_section := array_add(*result.config.file_specific_settings);
        new_setting_section.match_rules = .{ wildcards = wildcards, langs = langs };

        array_reset_keeping_memory(*seen_settings);  // avoid highlighting duplicates across sections

        section_offset = line_start_offset;

        return true, "";
    }

    add_highlight(parser, 0, line.count, .default);

    setting_name, setting_value := break_by_spaces(line);
    setting_name = trim_right(setting_name, ":");

    value := setting_value;  // will be destroyed by parsing

    #insert -> string {
        b: String_Builder;

        construct_parse_code :: (setting_name: string, get_value_code: string, error_message_code: string) -> string {
            template := #string JAI
                // Get value
                %1

                if success {
                    add_highlight(parser, cast(s64) (setting_value.data - line.data), setting_value.count, .value);
                    // Override
                    %2
                } else {
                    add_highlight(parser, cast(s64) (setting_value.data - line.data), setting_value.count, .error);

                    error_msg := %3;
                    return true, error_msg;
                }
            JAI

            override_code := #string JAI
                result.config.settings.%1 = val;
            JAI
            if is_overridable_setting(setting_name) {
                override_code = #string JAI
                    if result.config.file_specific_settings {
                        result.config.file_specific_settings[result.config.file_specific_settings.count-1].overrides.%1 = some(val);
                    } else {
                        result.config.settings.%1 = val;
                    }
                JAI
            }

            code := sprint(
                template,
                get_value_code,
                override_code,
                error_message_code,
            );

            return sprint(code, setting_name);
        }

        append(*b, "if setting_name == {\n");

        for setting : type_info(Settings).members {
            print_to_builder(*b, "    case \"%\";\n", setting.name);
            if setting.type.type == {
                case .BOOL;
                    code := construct_parse_code(
                        setting.name,
                        "val, success := parse_bool(*value);",
                        "tprint(\"Couldn't parse '%1' - expected 'true' or 'false', got '%%'\", setting_value)",
                    );
                    append(*b, code);

                case .INTEGER;
                    code := construct_parse_code(
                        setting.name,
                        "val, success := parse_int(*value);",
                        "tprint(\"Couldn't parse '%1' - expected a valid integer, got '%%'\", setting_value)",
                    );
                    append(*b, code);

                case .FLOAT;
                    code := construct_parse_code(
                        setting.name,
                        "val, success := parse_float(*value);",
                        "tprint(\"Couldn't parse '%1' - expected a valid float, got '%%'\", setting_value)",
                    );
                    append(*b, code);

                case .ENUM;
                    code := construct_parse_code(
                        setting.name,
                        #string JAI
                            enum_type :: type_of(Settings.%1);
                            enum_info := type_info(enum_type);
                            success, idx := array_find(enum_info.names, value);
                            val := cast(enum_type) 0;
                            if success then val = xx enum_info.values[idx];
                        JAI,
                        "tprint(\"Couldn't parse '%1' - valid values: %%\", join(..enum_info.names, \", \"))",
                    );
                    append(*b, code);
            }
        }

        code := #string JAI
            case;
                add_highlight(parser, 0, line.count, .error);
                return true, tprint("Unrecognized setting '%'.", setting_name);
        JAI
        append(*b, code);

        append(*b, "}\n");

        return builder_to_string(*b);
    }

    if !result.config.file_specific_settings {
        // Non-file-specific section
        array_add_if_unique(*result.config.set_settings, setting_name);
    } else if !is_overridable_setting(setting_name) {
        add_highlight(parser, 0, line.count, .error);
        return true, tprint("Setting '%' cannot be used in a file-specific section.\nAvailable options are:%", setting_name, join(..get_overridable_setting_names(), "\n - ", before_first = true));
    }

    // Detect duplicates and highlight them
    is_duplicate := false;
    for seen_settings {
        if setting_name != it.setting_name continue;
        add_highlight(parser, 0, it.line_length,        .comment, line_start_offset = it.line_start_offset);
        add_highlight(parser, 0, it.setting_name.count, .warning, line_start_offset = it.line_start_offset);
        is_duplicate = true;
    }
    if is_duplicate then add_highlight(parser, 0, setting_name.count, .warning);

    array_add(*seen_settings, Seen_Setting.{ line_start_offset = line_start_offset, line_length = xx line.count, setting_name = setting_name });

    return true, "";
}

parse_keymap_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string /* temp */ {
    add_highlight(parser, 0, line.count, .default);

    line_parsed_with_error = false;  // reset

    found_action, key_sequence_str, action_name := split_from_right_by_any(line, " \t");
    if !found_action {
        add_highlight(parser, 0, line.count, .error);
        return true, tprint("Invalid key mapping: '%'. \nExpected format: <key_sequence> <action_name>", line);
    }

    key_sequence_str = trim_right(key_sequence_str);
    key_sequence, error_msg := parse_key_sequence(parser, key_sequence_str, line);
    if !key_sequence return true, tprint("Invalid key sequence: '%'. Error: %", key_sequence_str, error_msg);

    // Parse actions
    map_action :: (name: string, key_sequence: [] Key_Combo, available_actions: [] string, target_keymap: *[..] Key_Mapping, subsection: string) #expand {
        found, index := array_find(available_actions, name);
        if found {
            array_add(target_keymap, Key_Mapping.{ key_sequence = key_sequence, action = cast(u32) index });
        } else {
            if parse_for_highlighting {
                add_highlight(parser, cast(s64)(name.data - line.data), name.count, .error);
                `return true, "";
            } else {
                error_msg := tprint("Unknown action '%'. Is it misspelled? Please check the default config file for a reference.", name);

                // Try to help the user find the right subsection if this action is available elsewhere
                Subsection_Actions :: struct { subsection: string; actions: [] string; };
                subsection_actions := Subsection_Actions.[
                    .{ "[common]",           ACTIONS_COMMON },
                    .{ "[editors]",          ACTIONS_EDITORS },
                    .{ "[open file dialog]", ACTIONS_OPEN_FILE_DIALOG },
                    .{ "[search dialog]",    ACTIONS_SEARCH_DIALOG },
                ];
                for subsection_actions {
                    if it.subsection == subsection continue;  // already checked that and failed
                    if array_find(it.actions, name) {
                        error_msg = tprint("Action '%' is not available in the % section. However, it is available in the % section", name, subsection, it.subsection);
                        break;
                    }
                }
                `return true, error_msg;
            }
        }
    }

    if active_subsection == {
        case .keymap_common;            map_action(action_name, key_sequence, ACTIONS_COMMON,           *result.config.keymap_common,           "[common]");
        case .keymap_editors;           map_action(action_name, key_sequence, ACTIONS_EDITORS,          *result.config.keymap_editors,          "[editors]");
        case .keymap_open_file_dialog;  map_action(action_name, key_sequence, ACTIONS_OPEN_FILE_DIALOG, *result.config.keymap_open_file_dialog, "[open file dialog]");
        case .keymap_search_dialog;     map_action(action_name, key_sequence, ACTIONS_SEARCH_DIALOG,    *result.config.keymap_search_dialog,    "[search dialog]");
    }

    if !line_parsed_with_error then maybe_highlight_duplicate_keymaps(parser, line, key_sequence);

    return true, "";
}

maybe_highlight_duplicate_keymaps :: (using parser: *Config_Parser, line: string, key_sequence: [] Key_Combo) {
    if !parse_for_highlighting return;

    is_duplicate := false;
    for seen_keymaps {
        if (it.section_offset == section_offset || it.section_offset == 0 || section_offset == 0) && key_sequence_matches(it.key_sequence, key_sequence) {
            add_highlight(parser, 0, it.line_length, .warning, line_start_offset = it.line_start_offset );
            is_duplicate = true;
            break;
        }
    }
    if is_duplicate then add_highlight(parser, 0, line.count, .warning);

    // Remember the keymap
    array_add(*seen_keymaps, Seen_Keymap.{
        line_start_offset  = line_start_offset,
        line_length        = xx line.count,
        key_sequence       = key_sequence,
        section_offset     = section_offset,
    });
}

parse_key_sequence :: (using parser: *Config_Parser, key_sequence_str: string, line: string) -> [] Key_Combo, error_msg: string /* temp */ {
    key_sequence: [..] Key_Combo;
    rest_of_line := key_sequence_str;

    while rest_of_line {
        combo_str:, rest_of_line = break_by_spaces(rest_of_line);

        key_combo, success, error_msg := parse_key_combo(parser, combo_str, line);
        if !success return .[], error_msg;

        array_add(*key_sequence, key_combo);
    }

    return key_sequence, "";
}

parse_key_combo :: (using parser: *Config_Parser, combo_str: string, line: string) -> Key_Combo, success: bool, error_msg: string /* temp */ {
    combo: Key_Combo;

    // Parse modifier flags
    modifier_string := combo_str;
    while true {
        found, mod_key, remainder := split_from_left(modifier_string, cast(u8) #char "-");
        if !found break;

        valid_mod_key := true;

        if to_lower_copy(mod_key,, temp) == {
            case "ctrl";    combo.mods.ctrl_pressed       = true;
            case "shift";   combo.mods.shift_pressed      = true;
            case "alt";     combo.mods.alt_pressed        = true;
            case "opt";     combo.mods.alt_pressed        = true;
            case "cmd";     combo.mods.cmd_meta_pressed   = true;
            case "meta";    combo.mods.cmd_meta_pressed   = true;
            case "super";   combo.mods.cmd_meta_pressed   = true;
            case "{ctrl}";  combo.ignore.ctrl_pressed     = true;
            case "{shift}"; combo.ignore.shift_pressed    = true;
            case "{alt}";   combo.ignore.alt_pressed      = true;
            case "{cmd}";   combo.ignore.cmd_meta_pressed = true;
            case "{meta}";  combo.ignore.cmd_meta_pressed = true;
            case "{super}"; combo.ignore.cmd_meta_pressed = true;
            case;
                valid_mod_key = false;
                if !parse_for_highlighting {
                    return combo, false, tprint("Unknown modifier key '%'. Allowed modifiers: Ctrl, Shift, Alt, Meta, Super, Cmd.", mod_key);
                } else {
                    add_highlight(parser, cast(s64)(mod_key.data - line.data), mod_key.count, .error);
                    line_parsed_with_error = true;
                }
        }
        modifier_string = remainder;

        if valid_mod_key then add_highlight(parser, cast(s64)(mod_key.data - line.data), mod_key.count, .value);
    }

    key_string := modifier_string;
    if !key_string {
        add_highlight(parser, combo_str.data - line.data, combo_str.count, .error);
        return combo, false, tprint("Missing key code after modifier flags: '%'", combo_str);
    }

    combo.key_code = keymap_map_key_string(key_string);

    if !combo.key_code {
        s := key_string;
        // Try single key chars, e.g. Ctrl-A, Ctrl-C etc.
        key_code, success := utf8_next_character(*s);
        if success != .CONVERSION_OK {
            add_highlight(parser, cast(s64)(key_string.data - line.data), key_string.count, .error);
            line_parsed_with_error = true;
            return combo, false, tprint("Line contains invalid UTF-8");
        }

        if (key_code >= #char "a") && (key_code <= #char "z") {
            // Uppercase it, since our keyboard codes are uppercase.
            key_code += (#char "a" - #char "A");
        }

        if s.count > 0 {
            // There are extra characters, report an error
            if !parse_for_highlighting {
                return combo, false, tprint("Expected a single char key code or a valid key name, got: '%'.", key_string);
            } else {
                add_highlight(parser, cast(s64)(key_string.data - line.data), key_string.count, .error);
                line_parsed_with_error = true;
            }
        }

        combo.key_code = key_code;
    }

    // Pre-apply the ignore mask
    combo.mods.packed |= combo.ignore.packed;

    return combo, true, "";
}

parse_linux_config_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string {
    add_highlight(parser, 0, line.count, .default);

    setting, value := break_by_spaces(line);
    setting = trim_right(setting, ":");

    if setting == {
        case "scaling_factor";
            val := value;  // parse_float destroys the string
            f_val, success := parse_float(*val);
            if !success {
                add_highlight(parser, value.data - line.data, value.count, .error);
                return true, tprint("Couldn't parse '%' - expected a valid float, got '%'", setting, value);
            }
            // @TODO: scaling factors under 1.0 break the editor widget on Wayland,
            //        investigate why this happens
            lower_limit := ifx DEBUG then 0.5 else 1.0;
            if (f_val != 0.0) && (f_val < lower_limit || f_val > 5.0) {
                add_highlight(parser, value.data - line.data, value.count, .error);
                return true, tprint("Couldn't parse '%' - value out of the expected range ([% ... 5.0])", lower_limit, setting);
            }
            result.config.linux.scaling_factor = f_val;

        case "explorer_command";
            result.config.linux.explorer_command = value;

        case "explorer_reveal_command";
            result.config.linux.explorer_reveal_command = value;

        case;
            add_highlight(parser, 0, line.count, .error);
            return true, tprint("Unknown setting '%' in section [[linux]]", setting);
    }

    return true, "";
}

section_allows_lines_outside_subsection :: inline (section: Section) -> bool {
    return CONFIG_SECTIONS[section].subsections.count == 0 || CONFIG_SECTIONS[section].allow_lines_outside_subsection;
}

section_allows_arbitrary_subsections :: inline (section: Section) -> bool {
    return CONFIG_SECTIONS[section].allow_arbitrary_subsections;
}


#scope_export

// A struct to represent the raw parsed config, where not everything might be present
// (we need to know what's missing so that we can properly merge the global config with the project config, for example)
Parsed_Config :: struct {
    version: int;

    // Workspace
    members:            [..] string;
    ignore:             [..] string;
    allow:              [..] string;
    file_associations:  [..] File_Association;

    // Keymap
    keymap_common:           [..] Key_Mapping;
    keymap_editors:          [..] Key_Mapping;
    keymap_open_file_dialog: [..] Key_Mapping;
    keymap_search_dialog:    [..] Key_Mapping;

    // Settings
    settings: Settings;
    set_settings: [..] string;  // so that we know which options were included in the config, and only touch those when merging
    file_specific_settings: [..] File_Specific_Settings;

    // Style
    theme:        string;
    font:         string;
    font_size:    int;
    font_ui:      string;
    font_ui_bold: string;
    font_ui_size: int;

    font_hinting:       Option(bool);
    font_anti_aliasing: Option(Font_Anti_Aliasing);

    colors:     [..] Parsed_Color;
    color_refs: [..] Color_Reference;  // @colorref: not finished

    // Build commands
    build: Build_Config;

    // Platform-specific
    linux: Linux_Config;

    // Remember offsets to help with modifying configs later
    offsets: struct {
        style_section := -1;
        theme_line    := -1;

        colors_section_start := -1;
        colors_section_end   := -1;
    };
};

Config_Parse_Result :: struct {
    config:     Parsed_Config;
    success:    bool;
    error_msg:  string;  // temp

    warnings:   [..] string;
    highlights: [..] Code_Highlight;
    warnings.allocator   = temp;  // I love jai
    highlights.allocator = temp;
}

Parsed_Color :: struct {
    color_id: Color;
    color: Vector4;
}

#scope_file

Config_Section :: struct {
    name: string;
    parse_function: string;
    subsections: [] string;
    allow_arbitrary_subsections    := false;
    allow_lines_outside_subsection := false;
}

Config_Parser :: struct {
    handler: Text_File_Handler;

    config_path: string;  // to be used for relative paths

    line_start_offset: s32;  // holds the start offset of the line being parsed (ignoring any whitespace at the start)
    section_offset:    s32;  // holds the offset of the last seen section header

    line_parsed_with_error: bool;  // when parsing for highlighting we want to ignore errors but we want to know sometimes whether they have occurred

    seen_settings: [..] Seen_Setting;  // to remember where we've seen something so we can go back if needed
    seen_keymaps:  [..] Seen_Keymap;
    seen_colors:   [..] Seen_Color;
    seen_settings.allocator = temp;
    seen_keymaps.allocator  = temp;
    seen_colors.allocator   = temp;

    result: Config_Parse_Result;  // will be filled during parsing

    active_section:    Section    = .none;
    active_subsection: Subsection = .none;
    seen_sections:     Seen_Sections;
    seen_subsections:  Seen_Subsections;

    parse_for_highlighting := false;
    parse_as_theme         := false;
}

#insert -> string {
    b: String_Builder;

    // Section
    append(*b, "Section :: enum {\n");
    append(*b, "    none :: -1;\n");
    for section : CONFIG_SECTIONS {
        print_to_builder(*b, "    % :: %;\n", replace(section.name, " ", "_"), it_index);
    }
    append(*b, "}\n");

    // Subsection
    append(*b, "Subsection :: enum {\n");
    append(*b, "    none;\n");
    for section : CONFIG_SECTIONS {
        print_to_builder(*b, "    %;\n", replace(section.name, " ", "_"));
        for subsection : section.subsections {
            print_to_builder(*b, "    %_%;\n", replace(section.name, " ", "_"), replace(subsection, " ", "_"));
        }
    }
    append(*b, "}\n");

    // Seen sections
    append(*b, "Seen_Sections :: enum_flags {\n");
    for section : CONFIG_SECTIONS {
        print_to_builder(*b, "    %;\n", replace(section.name, " ", "_"));
    }
    append(*b, "}\n");

    // Seen subsections
    append(*b, "Seen_Subsections :: enum_flags {\n");
    for section : CONFIG_SECTIONS {
        print_to_builder(*b, "    %;\n", replace(section.name, " ", "_"));
        for subsection : section.subsections {
            print_to_builder(*b, "    %_%;\n", replace(section.name, " ", "_"), replace(subsection, " ", "_"));
        }
    }
    append(*b, "}\n");

    return builder_to_string(*b);
}

Seen_Setting :: struct {
    using seen_line: Seen_Line;
    setting_name: string;
}

Seen_Keymap :: struct {
    using seen_line: Seen_Line;
    key_sequence:   [] Key_Combo;
}

Seen_Color :: struct {
    using seen_line: Seen_Line;
    color: Color;
}

Seen_Line :: struct {
    line_start_offset: s32;
    line_length:       s32;  // for highlighting the whole line if needed
    section_offset:    s32;
}

// @colorref: not finished
Color_Reference :: struct {
    color_name: string;
    color: Color;
    wants_to_use: Color;
    using seen_line: Seen_Line;  // to highlight invalid references
}


#import "Text_File_Handler";
