// Parser will be configured by a metaprogram below using the following section definitions
CONFIG_SECTIONS :: Config_Section.[
    .{
        name = "workspace",
        subsections = .[
            "workspace dirs",
            "ignore dirs",
            "allow file extensions",
            "ignore file extensions",
        ],
        parse_function = "parse_workspace_line",
    },
    .{
        name = "settings",
        parse_function = "parse_settings_line",
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
            "user interface",
            "colors",
        ],
        parse_function = "parse_style_line",
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

#add_context parse_for_highlighting: bool;

parse_config :: (name: string, filename: string, file_data: string, for_highlighting := false) -> Config_Parse_Result {
    context.parse_for_highlighting = for_highlighting;

    using parser: Config_Parser;

    // NOTE: we don't free on purpose, because some of the parsed data will point into the file data
    trimmed_data := trim_left(file_data, " \t\n\r");  // skip empty lines, otherwise the handler will crash!
    start_from_memory(*handler, name, filename, trimmed_data);
    if handler.failed {
        result.error_msg = tprint("Couldn't parse file '%'.\nPlease check that the version number is specified at the top in brackets, otherwise check the error log.", filename);
        return result;
    }

    // TODO: proper version handling and migration
    result.config.version = handler.version;
    if result.config.version < 1 || result.config.version > 2 {
        result.error_msg = tprint("Invalid config version [%] in file '%'. Supported versions are: [1], [2].", result.config.version, filename);
        return result;
    }

    while true {
        line, found := consume_next_line(*handler);
        if !found break;

        line_start_offset = cast(s32) (line.data - file_data.data);

        // Maybe switch sections
        if begins_with(line, "[") {
            error_msg := maybe_switch_section(*parser, line);
            if error_msg {
                add_highlight(*parser, 0, line.count, .error);
                if !for_highlighting {
                    result.error_msg = log_parser_error(handler, error_msg);
                    return result;  // this is a hard error, we don't want to proceed
                }
            }
            continue;
        }

        // Check if we allow lines outside of subsection
        if active_subsection == .none && !array_find(SECTIONS_ALLOWING_LINES_AT_TOP_LEVEL, active_section) {
            add_highlight(*parser, 0, line.count, .error);
            error_msg := log_parser_error(handler, "A keymap line is specified outside of a subsection: '%'. This is an error.", line);
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
                print_to_builder(*b, "    case .%;  success, error_msg = %(*parser, line);", replace(section.name, " ", "_"), section.parse_function);
            }
            code := #string JAI
                case .none;
                    if !context.parse_for_highlighting {
                        result.error_msg = log_parser_error(handler, "Expected a top-level section definition, got '%%'", line);
                        return result;
                    }
            JAI;
            print_to_builder(*b, code);
            append(*b, "}\n");

            return builder_to_string(*b);
        }

        if error_msg then error_msg = log_parser_error(handler, error_msg);  // enrich with file/line information

        if !success && !context.parse_for_highlighting {
            result.error_msg = error_msg;
            return result;
        }
        if success && error_msg then array_add(*result.warnings, error_msg);
    }

    // Mix the common key mappings into every keymap to support common actions
    array_extend(*result.config.keymap_editors,          result.config.keymap_common);
    array_extend(*result.config.keymap_open_file_dialog, result.config.keymap_common);
    array_extend(*result.config.keymap_search_dialog,    result.config.keymap_common);

    result.success   = true;
    result.error_msg = "";

    return result;
}

add_highlight :: inline (parser: *Config_Parser, offset_from_line_start: s64, count: s64, type: Focus_Config_Token, line_start_offset := -1) {
    if !context.parse_for_highlighting return;

    offset := parser.line_start_offset + offset_from_line_start;
    if line_start_offset >= 0 then offset = line_start_offset + offset_from_line_start;

    array_add(
        *parser.result.highlights,
        Code_Highlight.{ offset = cast(s32) offset, count = cast(s32) count, color_num = cast(u8) type },
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

map_color_name_to_color_struct :: (config: *Config, color_name: string) -> *Color {
    if color_name == {
        case "background";                      return *config.colors.BACKGROUND;
        case "background_dark";                 return *config.colors.BACKGROUND_DARK;
        case "background_highlight";            return *config.colors.BACKGROUND_HIGHLIGHT;
        case "background_light";                return *config.colors.BACKGROUND_LIGHT;
        case "background_bright";               return *config.colors.BACKGROUND_BRIGHT;
        case "selection_active";                return *config.colors.SELECTION_ACTIVE;
        case "selection_inactive";              return *config.colors.SELECTION_INACTIVE;
        case "selection_highlight";             return *config.colors.SELECTION_HIGHLIGHT;
        case "search_result_active";            return *config.colors.SEARCH_RESULT_ACTIVE;
        case "search_result_inactive";          return *config.colors.SEARCH_RESULT_INACTIVE;
        case "scrollbar";                       return *config.colors.SCROLLBAR;
        case "scrollbar_hover";                 return *config.colors.SCROLLBAR_HOVER;
        case "scrollbar_background";            return *config.colors.SCROLLBAR_BACKGROUND;
        case "cursor";                          return *config.colors.CURSOR;
        case "cursor_inactive";                 return *config.colors.CURSOR_INACTIVE;
        case "paste_animation";                 return *config.colors.PASTE_ANIMATION;
        case "splitter";                        return *config.colors.SPLITTER;
        case "splitter_hover";                  return *config.colors.SPLITTER_HOVER;
        case "letter_highlight";                return *config.colors.LETTER_HIGHLIGHT;
        case "list_cursor_lite";                return *config.colors.LIST_CURSOR_LITE;
        case "list_cursor";                     return *config.colors.LIST_CURSOR;
        case "shadow_dark";                     return *config.colors.SHADOW_DARK;
        case "shadow_transparent";              return *config.colors.SHADOW_TRANSPARENT;
        case "text_input_label";                return *config.colors.TEXT_INPUT_LABEL;

        case "ui_default";                      return *config.colors.UI_DEFAULT;
        case "ui_dim";                          return *config.colors.UI_DIM;
        case "ui_neutral";                      return *config.colors.UI_NEUTRAL;
        case "ui_warning";                      return *config.colors.UI_WARNING;
        case "ui_warning_dim";                  return *config.colors.UI_WARNING_DIM;
        case "ui_error";                        return *config.colors.UI_ERROR;
        case "ui_error_bright";                 return *config.colors.UI_ERROR_BRIGHT;
        case "ui_success";                      return *config.colors.UI_SUCCESS;

        case "code_default";                    return *config.colors.CODE_DEFAULT;
        case "code_comment";                    return *config.colors.CODE_COMMENT;
        case "code_type";                       return *config.colors.CODE_TYPE;
        case "code_function";                   return *config.colors.CODE_FUNCTION;
        case "code_punctuation";                return *config.colors.CODE_PUNCTUATION;
        case "code_operation";                  return *config.colors.CODE_OPERATION;
        case "code_string";                     return *config.colors.CODE_STRING;
        case "code_value";                      return *config.colors.CODE_VALUE;
        case "code_highlight";                  return *config.colors.CODE_HIGHLIGHT;
        case "code_error";                      return *config.colors.CODE_ERROR;
        case "code_keyword";                    return *config.colors.CODE_KEYWORD;
    }

    return xx 0;
}


#scope_file

log_parser_error :: (handler: Text_File_Handler, format: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) -> string {
    if context.parse_for_highlighting return "";  // Don't want to log anything

    // Like the "error" function in the handler module, but it also returns the message because we want it
    new_format := tprint("Line % of '%': %", handler.line_number, handler.full_path, format);
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

    .{ "F1",                F1 },
    .{ "F2",                F2 },
    .{ "F3",                F3 },
    .{ "F4",                F4 },
    .{ "F5",                F5 },
    .{ "F6",                F6 },
    .{ "F7",                F7 },
    .{ "F8",                F8 },
    .{ "F9",                F9 },
    .{ "F10",               F10 },
    .{ "F11",               F11 },
    .{ "F12",               F12 },

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

    // We don't support mouse wheel events because we'd need to block scrolling
    // if they are handled and we don't want to do it just yet.
    // .{ "MouseWheelUp",      MOUSE_WHEEL_UP },
    // .{ "MouseWheelDown",    MOUSE_WHEEL_DOWN },
];

maybe_switch_section :: (using parser: *Config_Parser, line: string) -> error: string {
    if begins_with(line, "[[") {
        // Top section
        if !ends_with(line, "]]") return tprint("Invalid section '%'. Section definitions must end with ]]", line);
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
                        if seen_sections & .%2 return tprint("Section [[%1]] is defined twice. This is an error.");
                        seen_sections |= .%2;
                JAI;
                print_to_builder(*b, code, section.name, replace(section.name, " ", "_"));
            }
            code := #string JAI
                case;
                    return tprint("Unknown top-level section %%", line);
            JAI;
            print_to_builder(*b, code);
            append(*b, "}\n");
            return builder_to_string(*b);
        }
        add_highlight(parser, 0, line.count, .header_top_level);
    } else {
        // Subsection
        if !ends_with(line, "]") return tprint("Invalid subsection '%'. Subsection definitions must end with ]", line);
        subsection_name := trim(line, " \t[]");

        #insert -> string {
            b: String_Builder;
            append(*b, "if subsection_name == {\n");
            for section : CONFIG_SECTIONS {
                for subsection : section.subsections {
                    code := #string JAI
                        case "%1";
                            active_subsection = .%2;
                            section_offset = line_start_offset;
                            if seen_subsections & .%2 return tprint("Subsection [%1] is defined twice. This is an error.");
                            seen_subsections |= .%2;
                    JAI;
                    print_to_builder(*b, code, subsection, replace(tprint("%_%", section.name, subsection), " ", "_"));
                }
            }
            code := #string JAI
                case;
                    return tprint("Unknown subsection %%", line);
            JAI;
            print_to_builder(*b, code);
            append(*b, "}\n");
            return builder_to_string(*b);
        }
        add_highlight(parser, 0, line.count, .header);
    }

    return "";
}

parse_workspace_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string /* temp */ {
    // Always highlight in default colors. If there's an issue with a workspace dir, we'll highlight the part which doesn't exist
    add_highlight(parser, 0, line.count, .default);

    if active_subsection == {
        case .workspace_workspace_dirs;
            dir_path, success := get_absolute_path(line);
            path_overwrite_separators(line,     #char "/");
            path_overwrite_separators(dir_path, #char "/");
            if !success || !platform_path_equals(line, dir_path) {
                add_highlight(parser, 0, line.count, .error);
                return true, tprint("Invalid directory '%'. Maybe it's not an absolute path or has a double slash?", line);
            }

            dir_path = copy_string(dir_path);
            if file_exists(dir_path) {
                array_add(*result.config.workspace_dirs, dir_path);
            } else {
                if context.parse_for_highlighting {
                    // Highlight the bad chunk
                    for chunk : split(dir_path, "/") {
                        dir_prefix := slice(dir_path, 0, cast(s64)(chunk.data - dir_path.data) + chunk.count);
                        if !file_exists(dir_prefix) {
                            add_highlight(parser, cast(s64)(chunk.data - dir_path.data), chunk.count, .error);
                            break;
                        }
                    }
                }
                return true, tprint("Directory '%' doesn't exist.", dir_path);
            }
        case .workspace_ignore_dirs;
            dirs := split(line, cast(u8) #char " ");
            for dir : dirs {
                if !dir continue;
                path_overwrite_separators(dir, #char "/");
                array_add(*result.config.ignore_dirs, dir);
            }
        case .workspace_allow_file_extensions;
            extensions := split(line, cast(u8) #char " ");
            for extensions {
                if !it continue;
                if contains_any_character(it, "*?") {
                    array_add(*result.config.allow_file_extension_wildcards, trim_left(it, ".\t "));
                } else {
                    array_add(*result.config.allow_file_extensions, trim_left(it, "\t "));
                }
            }
        case .workspace_ignore_file_extensions;
            extensions := split(line, cast(u8) #char " ");
            for extensions {
                if !it continue;
                if contains_any_character(it, "*?") {
                    array_add(*result.config.ignore_file_extension_wildcards, trim_left(it, ".\t "));
                } else {
                    array_add(*result.config.ignore_file_extensions, trim_left(it, "\t "));
                }
            }
    }
    return true, "";
}

parse_style_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string /* temp */ {
    add_highlight(parser, 0, line.count, .default);

    if active_subsection == {
        case .style_user_interface;
            setting, value := break_by_spaces(line);
            setting = trim_right(setting, ":");
            if setting == {
                case "font";
                    found, error_msg := find_font_by_name(value);
                    if found {
                        result.config.font = value;
                    } else {
                        add_highlight(parser, xx (value.data - line.data), value.count, .error);
                        result.config.font = "default";
                        return true, error_msg;
                    }
                case "font_size";
                    value_copy := value;
                    int_val, success := parse_int(*value_copy);
                    if success {
                        result.config.font_size = int_val;
                    } else {
                        add_highlight(parser, xx (value.data - line.data), value.count, .error);
                        result.config.font_size = DEFAULT_FONT_SIZE;
                        return false, tprint("Couldn't parse '%' - expected a valid integer, got '%'", setting, value);
                    }
                case;
                    add_highlight(parser, 0, setting.count, .error);
                    return true, tprint("Unknown style option '%'", setting);
            }
        case .style_colors;
            color_name, value := break_by_spaces(line);
            color_name = trim_right(color_name, ":");
            color_ptr := map_color_name_to_color_struct(*Config.{}, color_name);
            if !color_ptr {
                add_highlight(parser, 0, color_name.count, .error);
                return true, tprint("Unknown color '%'", color_name);
            }
            color, success := hex_to_color(value);
            if !success {
                add_highlight(parser, xx (value.data - line.data), value.count, .error);
                return true, tprint("Couldn't parse '%'. Expected a color in the form RRGGBB or RRGGBBAA, got '%'", color_name, value);
            }
            array_add(*result.config.colors, Parsed_Color.{ color_name, color });

            is_duplicate := false;
            for seen_colors {
                if color_ptr != it.color_ptr continue;
                add_highlight(parser, 0, it.line_length,   .comment, line_start_offset = it.line_start_offset);
                add_highlight(parser, 0, color_name.count, .warning, line_start_offset = it.line_start_offset);
                is_duplicate = true;
            }
            if is_duplicate then add_highlight(parser, 0, line.count, .warning);

            array_add(*seen_colors, Seen_Color.{ line_start_offset = line_start_offset, line_length = xx line.count, color_ptr = color_ptr });
    }

    return true, "";
}

color_to_hex :: (using color: Color, exclude_hash := false) -> string /* temp  */ {
    r_u8 := cast(u8)(255 * r);
    g_u8 := cast(u8)(255 * g);
    b_u8 := cast(u8)(255 * b);
    a_u8 := cast(u8)(255 * a);

    h :: #bake_arguments formatInt(base=16, minimum_digits=2);
    format := "#%1%2%3%4";
    if exclude_hash advance(*format, 1);

    return tprint(format, h(r_u8), h(g_u8), h(b_u8), h(a_u8));
}

hex_to_color :: (src_hex: string) -> Color, success: bool {
    hex := src_hex;
    if hex.count == 6 then hex = tprint("%FF", hex);
    if hex.count != 8 return Color.{}, false;

    r := slice(hex, 0, 2);
    g := slice(hex, 2, 2);
    b := slice(hex, 4, 2);
    a := slice(hex, 6, 2);

    to_float :: (byte_str: string) -> float {
        hex_digit_to_int :: (char: u8) -> int {
            char = to_upper(char);
            if #char "0" <= char && char <= #char "9" return char - #char "0";
            if #char "A" <= char && char <= #char "F" return 10 + char - #char "A";
            return -1;
        }

        d1, d0 := cast(float)hex_digit_to_int(byte_str[0]), cast(float) hex_digit_to_int(byte_str[1]);
        if d1 < 0 || d0 < 0 return -1;

        return (16 * d1 + d0) / 255;
    }

    c := Color.{ r = to_float(r), g = to_float(g), b = to_float(b), a = to_float(a) };

    return c, c.r >= 0 && c.g >= 0 && c.b >= 0 && c.a >= 0;
}

parse_build_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string /* temp */ {
    using result.config.build;

    if begins_with(line, "[") {
        // Add a new command
        name := trim(line, "[]");
        if !name {
            add_highlight(parser, 0, line.count, .error);
            return false, tprint("Command name can't be empty: %", line);
        }

        if commands {
            last_command := *commands[commands.count-1];
            if !last_command.build_command && !last_command.run_command {
                return false, tprint("Command '%' must have at least build_command or run_command configured", last_command.name);
            }
        }

        command := array_add(*commands);
        command.name = name;  // points into the file data!

        return true, "";
    }

    target := *defaults;
    if commands then target = *commands[commands.count-1];

    option_name, option_value := break_by_spaces(line);
    option_name = trim_right(option_name, ":");

    value := option_value;  // will be destroyed by parsing

    #insert -> string {
        b: String_Builder;

        append(*b, "if option_name == {\n");

        for option : type_info(Build_Config.Command).members {
            print_to_builder(*b, "    case \"%\";\n", option.name);
            if option.type.type == {
                case .BOOL;
                    code := #string END
                        bool_val, success := parse_bool(*value);
                        if success {
                            target.%1 = bool_val;
                        } else {
                            return false, tprint("Couldn't parse '%1' - expected 'true' or 'false', got '%%'", option_value);
                        }
                    END;
                    print_to_builder(*b, code, option.name);

                case .STRING;
                    code := #string END
                        if value {
                            target.%1 = value;  // points into the file data!
                        } else {
                            return false, tprint("Build command option '%%' can't be empty", option_name);
                        }
                    END;
                    print_to_builder(*b, code, option.name);
            }
        }

        code := #string END
            case;
                return false, tprint("Unrecognized build command option '%'.", option_name);
        END;
        append(*b, code);

        append(*b, "}\n");

        return builder_to_string(*b);
    }

    return true, "";
}

parse_settings_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string /* temp */ {
    setting_name, setting_value := break_by_spaces(line);
    setting_name = trim_right(setting_name, ":");

    value := setting_value;  // will be destroyed by parsing

    add_highlight(parser, 0, line.count, .default);

    #insert -> string {
        b: String_Builder;

        append(*b, "if setting_name == {\n");

        for setting : type_info(Settings).members {
            print_to_builder(*b, "    case \"%\";\n", setting.name);
            if setting.type.type == {
                case .BOOL;
                    code := #string END
                        bool_val, success := parse_bool(*value);
                        if success {
                            add_highlight(parser, cast(s64)(setting_value.data - line.data), setting_value.count, .value);
                            result.config.settings.%1 = bool_val;
                        } else {
                            add_highlight(parser, cast(s64)(setting_value.data - line.data), setting_value.count, .error);
                            return true, tprint("Couldn't parse '%1' - expected 'true' or 'false', got '%%'", setting_value);
                        }
                    END;
                    print_to_builder(*b, code, setting.name);

                case .INTEGER;
                    code := #string END
                        int_val, success := parse_int(*value);
                        if success {
                            add_highlight(parser, cast(s64)(setting_value.data - line.data), setting_value.count, .value);
                            result.config.settings.%1 = int_val;
                        } else {
                            add_highlight(parser, cast(s64)(setting_value.data - line.data), setting_value.count, .error);
                            return true, tprint("Couldn't parse '%1' - expected a valid integer, got '%%'", setting_value);
                        }
                    END;
                    print_to_builder(*b, code, setting.name);
            }
        }

        code := #string END
            case;
                add_highlight(parser, 0, line.count, .error);
                return true, tprint("Unrecognized setting '%'.", setting_name);
        END;
        append(*b, code);

        append(*b, "}\n");

        return builder_to_string(*b);
    }

    added := array_add_if_unique(*result.config.set_settings, setting_name);
    if !added {
        // Duplicate setting, highlight all of them
        add_highlight(parser, 0, setting_name.count, .warning);
        for seen_settings {
            if setting_name != it.setting_name continue;
            add_highlight(parser, 0, it.line_length,        .comment, line_start_offset = it.line_start_offset);
            add_highlight(parser, 0, it.setting_name.count, .warning, line_start_offset = it.line_start_offset);
        }
    }

    array_add(*seen_settings, Seen_Setting.{ line_start_offset = line_start_offset, line_length = xx line.count, setting_name = setting_name });

    return true, "";
}

parse_keymap_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string /* temp */ {
    add_highlight(parser, 0, line.count, .default);

    // Parse key sequence and action
    key_sequence: [..] Key_Combo;
    key_sequence_error_message: string;
    action_name: string;
    item: string;
    rest_of_line := line;

    line_parsed_with_error = false;  // reset

    while true {
        // The last item we encounter will be interpreted as the action name, all parts before it will be parsed as key combinations.
        item, rest_of_line = break_by_spaces(rest_of_line);
        if !rest_of_line {
            action_name = item;
            break;
        }

        key_combo, key_ok, msg := parse_key_combo(parser, item, line);
        if !key_ok {
            key_sequence_error_message = msg;
            break;
        }

        array_add(*key_sequence, key_combo);
    }

    if key_sequence.count == 0 || !action_name {
        error_msg := tprint("Invalid key sequence: '%'.\n%", line, key_sequence_error_message);
        add_highlight(parser, 0, line.count, .error);
        return true, error_msg;
    }

    // Parse actions
    map_action :: (name: string, key_sequence: [] Key_Combo, available_actions: [] string, target_keymap: *[..] Key_Mapping, subsection: string) #expand {
        found, index := array_find(available_actions, name);
        if found {
            array_add(target_keymap, Key_Mapping.{ key_sequence = key_sequence, action = cast(u32) index });
        } else {
            if context.parse_for_highlighting {
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

    if context.parse_for_highlighting && !line_parsed_with_error {
        // Highlight any other keymaps which match the key sequence of this one
        is_duplicate := false;
        for seen_keymaps {
            if it.section_offset == section_offset && key_sequence_matches(it.key_sequence, key_sequence) {
                add_highlight(parser, 0, it.line_length, .warning, line_start_offset = it.line_start_offset );
                is_duplicate = true;
                break;
            }
        }
        if is_duplicate {
            action_name_offset := cast(s64)(action_name.data - line.data);
            add_highlight(parser, 0, action_name_offset, .warning);
            add_highlight(parser, action_name_offset, action_name.count, .comment);
        }

        // Remember the keymap
        array_add(*seen_keymaps, Seen_Keymap.{
            line_start_offset  = line_start_offset,
            line_length        = xx line.count,
            key_sequence       = key_sequence,
            section_offset     = section_offset,  // NOTE: this won't work well while we still allow to redefine existing subsections
        });
    }

    return true, "";
}

parse_key_combo :: (using parser: *Config_Parser, key_name: string, line: string) -> Key_Combo, success: bool, error_msg: string /* temp */ {
    combo: Key_Combo;

    // Parse modifier flags
    modifier_string := key_name;
    while true {
        found, mod_key, remainder := split_from_left(modifier_string, cast(u8) #char "-");
        if !found break;

        valid_mod_key := true;

        if to_lower_copy(mod_key, allocator = temp) == {
            case "ctrl";    combo.mods.ctrl_pressed       = true;
            case "shift";   combo.mods.shift_pressed      = true;
            case "alt";     combo.mods.alt_pressed        = true;
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
                if !context.parse_for_highlighting {
                    return combo, false, tprint("Unknown modifier key '%'", mod_key);
                } else {
                    add_highlight(parser, cast(s64)(mod_key.data - line.data), mod_key.count, .error);
                    line_parsed_with_error = true;
                }
        }
        modifier_string = remainder;

        if valid_mod_key then add_highlight(parser, cast(s64)(mod_key.data - line.data), mod_key.count, .modifier_key);
    }

    key_string := modifier_string;
    if !key_string {
        add_highlight(parser, 0, line.count, .error);
        return combo, false, tprint("Missing key code after modifier flags: '%'", key_name);
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
            key_code += cast,trunc(u32) (#char "A" - #char "a");  // This is a negative number; but we cast it to u32 and get the same result, because, twos-complement. The trunc is to make this legal.
        }

        if s.count > 0 {
            // There are extra characters, report an error
            if !context.parse_for_highlighting {
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

    result.config.linux.scaling_factor = 0.0;

    if setting == {
        case "scaling_factor";
            val := value;  // parse_float destroys the string
            f_val, success := parse_float(*val);
            if !success {
                add_highlight(parser, xx (value.data - line.data), value.count, .error);
                return true, tprint("Couldn't parse '%' - expected a valid float, got '%'", setting, value);
            }
            // @TODO: scaling factors under 1.0 break the editor widget on Wayland,
            //        investigate why this happens
            lower_limit := ifx DEBUG then 0.5 else 1.0;
            if (f_val != 0.0) && (f_val < lower_limit || f_val > 5.0) {
                add_highlight(parser, xx (value.data - line.data), value.count, .error);
                return true, tprint("Couldn't parse '%' - value out of the expected range ([% ... 5.0])", lower_limit, setting);;
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


#scope_export

// A struct to represent the raw parsed config, where not everything might be present
// (we need to know what's missing so that we can properly merge the global config with the project config, for example)
Parsed_Config :: struct {
    version: int;

    // Workspace
    workspace_dirs:         [..] string;
    ignore_dirs:            [..] string;
    allow_file_extensions:  [..] string;
    allow_file_extension_wildcards:  [..] string;
    ignore_file_extensions: [..] string;
    ignore_file_extension_wildcards: [..] string;

    // Keymap
    keymap_common:           [..] Key_Mapping;
    keymap_editors:          [..] Key_Mapping;
    keymap_open_file_dialog: [..] Key_Mapping;
    keymap_search_dialog:    [..] Key_Mapping;

    // Settings
    settings: Settings;
    set_settings: [..] string;  // so that we know which options were included in the config, and only touch those when merging

    // Style
    font:      string;
    font_size: int;
    colors:    [..] Parsed_Color;

    // Build commands
    build: Build_Config;

    linux: Linux_Config;
};

Config_Parse_Result :: struct {
    config:     Parsed_Config;
    success:    bool;
    error_msg:  string;         // temp
    warnings:   [..] string;
    highlights: [..] Code_Highlight;
    warnings.allocator   = temp;  // I love jai
    highlights.allocator = temp;
}

Parsed_Color :: struct {
    color_name: string;
    color: Color;
}

#scope_file

Config_Section :: struct {
    name: string;
    parse_function: string;
    // parse_function: #type (parser: *Config_Parser, line: string) -> success: bool, error: string;
    subsections: [] string;
    allow_arbitrary_subsections := false;
}

Config_Parser :: struct {
    handler: Text_File_Handler;

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
}

#insert -> string {
    b: String_Builder;

    // Section
    append(*b, "Section :: enum {\n");
    append(*b, "    none;\n");
    for section : CONFIG_SECTIONS {
        print_to_builder(*b, "    %;\n", replace(section.name, " ", "_"));
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

    // Sections allowing top level lines
    append(*b, "SECTIONS_ALLOWING_LINES_AT_TOP_LEVEL :: Section.[\n");
    for section : CONFIG_SECTIONS {
        if !section.subsections {
            print_to_builder(*b, "    .%,\n", replace(section.name, " ", "_"));
        }
    }
    append(*b, "];\n");

    return builder_to_string(*b);
}

Seen_Setting :: struct {
    using seen_line: Seen_Line;
    setting_name: string;
}

Seen_Keymap :: struct {
    using seen_line: Seen_Line;
    key_sequence:   [] Key_Combo;
    section_offset: s32;
}

Seen_Color :: struct {
    using seen_line: Seen_Line;
    color_ptr: *Color;
}

Seen_Line :: struct {
    line_start_offset: s32;
    line_length:       s32;  // for highlighting the whole line if needed
}


#import "Text_File_Handler";
