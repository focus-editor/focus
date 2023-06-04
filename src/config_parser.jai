// Adapted code from modules/Keymap

parse_config :: (name: string, filename: string, file_data: string) -> Config, success: bool, error_msg: string /* temp */, warnings: [] string /* temp */ {
    parser: Config_Parser;
    result: Config;

    // NOTE: we don't free on purpose, because some of the parsed data will point into the file data
    trimmed_data := trim_left(file_data, " \t\n\r");  // skip empty lines, otherwise the handler will crash!
    start_from_memory(*parser.handler, name, filename, trimmed_data);
    if parser.handler.failed return Config.{}, false, tprint("The text file handler couldn't parse file '%'.\nPlease check that the version number is specified at the top, otherwise check the error log.", filename), .[];

    warnings: [..] string;
    warnings.allocator = temp;

    while true {
        line, found := consume_next_line(*parser.handler);
        if !found break;

        // Maybe switch to a different top section
        if begins_with(line, "[[") {
            error, error_msg := switch_top_section(*parser, line);
            if error return Config.{}, false, error_msg, .[];
            continue;
        }

        success:   bool;
        error_msg: string;

        if #complete parser.top_section == {
            case .workspace;    success, error_msg = parse_workspace_line(*parser, line);
            case .settings;     success, error_msg = parse_settings_line(*parser, line);
            case .keymap;       success, error_msg = parse_keymap_line(*parser, line);
            case .style;        success, error_msg = parse_style_line(*parser, line);
            case .platform;     success, error_msg = platform_parse_config_line(*parser, line);
            case .none;
                error_msg := log_parser_error(parser.handler, "Expected a top-level section definition, got '%'", line);
                return result, false, error_msg, .[];
        }

        if !success return result, false, error_msg, warnings;
        if success && error_msg then array_add(*warnings, error_msg);
    }

    // Cast away the extendable arrays into array views
    result.workspace.workspace_dirs                   = parser.data.workspace_dirs;
    result.workspace.ignore_dirs                      = parser.data.ignore_dirs;
    result.workspace.allow_file_extensions            = parser.data.allow_file_extensions;
    result.workspace.allow_file_extension_wildcards   = parser.data.allow_file_extension_wildcards;
    result.workspace.ignore_file_extensions           = parser.data.ignore_file_extensions;
    result.workspace.ignore_file_extension_wildcards  = parser.data.ignore_file_extension_wildcards;

    // Merge and store keymaps in the config
    // (keys defined in the common section need to be present in the other sections unless overridden there)
    array_extend(*parser.data.keymap_editors,          parser.data.keymap_common);
    array_extend(*parser.data.keymap_open_file_dialog, parser.data.keymap_common);
    array_extend(*parser.data.keymap_search_dialog,    parser.data.keymap_common);

    result.keymap.common           = parser.data.keymap_common;
    result.keymap.editors          = parser.data.keymap_editors;
    result.keymap.open_file_dialog = parser.data.keymap_open_file_dialog;
    result.keymap.search_dialog    = parser.data.keymap_search_dialog;

    // Copy settings
    parser.parsed.settings.line_height_scale_percent = clamp(parser.parsed.settings.line_height_scale_percent, 50, 1000);
    result.settings = parser.parsed.settings;

    // Style
    result.style.font           = parser.data.font;
    result.style.font_size      = parser.data.font_size;
    result.style.parsed_colors  = parser.data.parsed_colors;  // @leak

    result.platform = parser.parsed.platform;

    return result, true, "", warnings;
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

map_color_name_to_color_struct :: (color_name: string) -> *Color, found: bool {
    color: *Color;

    if color_name == {
        case "background";                      color = *Colors.BACKGROUND;
        case "background_dark";                 color = *Colors.BACKGROUND_DARK;
        case "background_highlight";            color = *Colors.BACKGROUND_HIGHLIGHT;
        case "background_light";                color = *Colors.BACKGROUND_LIGHT;
        case "background_bright";               color = *Colors.BACKGROUND_BRIGHT;
        case "selection_active";                color = *Colors.SELECTION_ACTIVE;
        case "selection_inactive";              color = *Colors.SELECTION_INACTIVE;
        case "selection_highlight";             color = *Colors.SELECTION_HIGHLIGHT;
        case "search_result_active";            color = *Colors.SEARCH_RESULT_ACTIVE;
        case "search_result_inactive";          color = *Colors.SEARCH_RESULT_INACTIVE;
        case "scrollbar";                       color = *Colors.SCROLLBAR;
        case "scrollbar_hover";                 color = *Colors.SCROLLBAR_HOVER;
        case "scrollbar_background";            color = *Colors.SCROLLBAR_BACKGROUND;
        case "cursor";                          color = *Colors.CURSOR;
        case "cursor_inactive";                 color = *Colors.CURSOR_INACTIVE;
        case "paste_animation";                 color = *Colors.PASTE_ANIMATION;
        case "splitter";                        color = *Colors.SPLITTER;
        case "splitter_hover";                  color = *Colors.SPLITTER_HOVER;
        case "letter_highlight";                color = *Colors.LETTER_HIGHLIGHT;
        case "list_cursor_lite";                color = *Colors.LIST_CURSOR_LITE;
        case "list_cursor";                     color = *Colors.LIST_CURSOR;
        case "shadow_dark";                     color = *Colors.SHADOW_DARK;
        case "shadow_transparent";              color = *Colors.SHADOW_TRANSPARENT;
        case "text_input_label";                color = *Colors.TEXT_INPUT_LABEL;

        case "ui_default";                      color = *Colors.UI_DEFAULT;
        case "ui_dim";                          color = *Colors.UI_DIM;
        case "ui_neutral";                      color = *Colors.UI_NEUTRAL;
        case "ui_warning";                      color = *Colors.UI_WARNING;
        case "ui_warning_dim";                  color = *Colors.UI_WARNING_DIM;
        case "ui_error";                        color = *Colors.UI_ERROR;
        case "ui_error_bright";                 color = *Colors.UI_ERROR_BRIGHT;
        case "ui_success";                      color = *Colors.UI_SUCCESS;

        case "code_default";                    color = *Colors.CODE_DEFAULT;
        case "code_comment";                    color = *Colors.CODE_COMMENT;
        case "code_type";                       color = *Colors.CODE_TYPE;
        case "code_function";                   color = *Colors.CODE_FUNCTION;
        case "code_punctuation";                color = *Colors.CODE_PUNCTUATION;
        case "code_operation";                  color = *Colors.CODE_OPERATION;
        case "code_string";                     color = *Colors.CODE_STRING;
        case "code_value";                      color = *Colors.CODE_VALUE;
        case "code_highlight";                  color = *Colors.CODE_HIGHLIGHT;
        case "code_error";                      color = *Colors.CODE_ERROR;
        case "code_keyword";                    color = *Colors.CODE_KEYWORD;

        case; return xx 0, false;
    }

    return color, true;
}

Parsed_Color :: struct {
    color_name: string;
    color: Color;
}


#scope_file

log_parser_error :: (handler: Text_File_Handler, format: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) -> string {
    // Like the "error" function in the handler module, but it also returns the message because we want it
    new_format := tprint("Line % of '%': %", handler.line_number, handler.full_path, format);
    message := tprint(new_format, .. args);
    log(message, flags=Log_Flags.ERROR|flags, loc=loc);

    return message;
} @PrintLike

log_parser_error :: (full_path: string, line_number: int, message: string, flags := Log_Flags.NONE, loc := #caller_location) {
    new_message := tprint("Line % of '%': %", line_number, full_path, message);
    log(new_message, flags=Log_Flags.ERROR|flags, loc=loc);
}

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

    .{ "MouseLeft",         MOUSE_BUTTON_LEFT },
    .{ "MouseRight",        MOUSE_BUTTON_RIGHT },
    .{ "MouseMiddle",       MOUSE_BUTTON_MIDDLE },

    // We don't support mouse wheel events because we'd need to block scrolling
    // if they are handled and we don't want to do it just yet.
    // .{ "MouseWheelUp",      MOUSE_WHEEL_UP },
    // .{ "MouseWheelDown",    MOUSE_WHEEL_DOWN },
];

switch_top_section :: (using parser: *Config_Parser, line: string) -> error: bool, msg: string /* temp */ {
    if line == {
        case "[[workspace]]";
            top_section = .workspace;
            if seen_top_sections & .workspace {
                error_msg := log_parser_error(handler, "The section '[[workspace]]' is defined twice. This is an error.");
                return true, error_msg;
            }
            seen_top_sections |= .workspace;

        case "[[keymap]]";
            top_section = .keymap;
            if seen_top_sections & .keymap {
                error_msg := log_parser_error(handler, "The section '[[keymap]]' is defined twice. This is an error.");
                return true, error_msg;
            }
            seen_top_sections |= .keymap;

        case "[[settings]]";
            top_section = .settings;
            if seen_top_sections & .settings {
                error_msg := log_parser_error(handler, "The section '[[settings]]' is defined twice. This is an error.");
                return true, error_msg;
            }
            seen_top_sections |= .settings;

        case "[[style]]";
            top_section = .style;
            if seen_top_sections & .style {
                error_msg := log_parser_error(handler, "The section '[[style]]' is defined twice. This is an error.");
                return true, error_msg;
            }
            seen_top_sections |= .style;

        case PLATFORM_CONFIG_SECTION;
            top_section = .platform;
            if seen_top_sections & .platform {
                error_msg := log_parser_error(handler, "The section '%' is defined twice. This is an error.", PLATFORM_CONFIG_SECTION);
                return true, error_msg;
            }
            seen_top_sections |= .platform;

        case;
            error_msg := log_parser_error(handler, "Expected one of the following top-level sections: [[workspace]], [[settings]], [[keymap]], [[style]], but found '%'", line);
            return true, error_msg;
    }

    return false, "";
}

parse_workspace_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string /* temp */ {
    if begins_with(line, "[") {
        for WORKSPACE_SUBSECTIONS {
            if line == it { workspace_subsection = xx it_index; return true, ""; }
        }
        error_msg := log_parser_error(handler, "Unknown workspace subsection '%'.\nAvailable options are: %.", line, join(..WORKSPACE_SUBSECTIONS, ", ", allocator = temp));
        return false, error_msg;
    }
    if #complete workspace_subsection == {
        case .workspace_dirs;
            dir_path, success := get_absolute_path(line);
            dir_path = ifx success then copy_string(dir_path) else copy_string(line);
            path_overwrite_separators(dir_path, #char "/");
            if success && file_exists(dir_path) {
                array_add(*data.workspace_dirs, dir_path);
            } else {
                error_msg := log_parser_error(handler, "Directory '%' doesn't exist.", dir_path);
                return true, error_msg;
            }
        case .ignore_dirs;
            dirs := split(line, cast(u8) #char " ");
            for dir : dirs {
                if !dir continue;
                path_overwrite_separators(dir, #char "/");
                array_add(*data.ignore_dirs, dir);
            }
        case .allow_file_extensions;
            extensions := split(line, cast(u8) #char " ");
            for extensions {
                if !it continue;
                if contains_any_character(it, "*?") {
                    array_add(*data.allow_file_extension_wildcards, trim_left(it, ".\t "));
                } else {
                    array_add(*data.allow_file_extensions, trim_left(it, "\t "));
                }
            }
        case .ignore_file_extensions;
            extensions := split(line, cast(u8) #char " ");
            for extensions {
                if !it continue;
                if contains_any_character(it, "*?") {
                    array_add(*data.ignore_file_extension_wildcards, trim_left(it, ".\t "));
                } else {
                    array_add(*data.ignore_file_extensions, trim_left(it, "\t "));
                }
            }
    }
    return true, "";
}

parse_style_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string /* temp */ {
    if begins_with(line, "[") {
        for STYLE_SUBSECTIONS {
            if line == it { style_subsection = xx it_index; return true, ""; }
        }
        error_msg := log_parser_error(handler, "Unknown style subsection '%'.\nAvailable options are: %.", line, join(..STYLE_SUBSECTIONS, ", ", allocator = temp));
        return false, error_msg;
    }
    if #complete style_subsection == {
        case .user_interface;
            setting, value := break_by_spaces(line);
            setting = trim_right(setting, ":");
            if setting == {
                case "font";
                    found, error := find_font_by_name(value);
                    if found {
                        data.font = value;
                    } else {
                        error_msg := log_parser_error(handler, error);
                        return false, error_msg;
                    }
                case "font_size";
                    value_copy := value;
                    int_val, success := parse_int(*value_copy);
                    if success {
                        data.font_size = int_val;
                    } else {
                        error_msg := log_parser_error(handler, "Couldn't parse '%' - expected a valid integer, got '%'", setting, value);
                        return false, error_msg;
                    }
            }
        case .colors;
            color_name, value := break_by_spaces(line);
            color_name = trim_right(color_name, ":");
            color_ptr, found := map_color_name_to_color_struct(color_name);
            if !found {
                error_msg := log_parser_error(handler, "Unknown color '%'", color_name);
                return false, error_msg;
            }
            color, success := hex_to_color(value);
            if !success {
                error_msg := log_parser_error(handler, "Couldn't parse '%'. Expected a color in the form RRGGBB or RRGGBBAA, got '%'", color_name, value);
                return false, error_msg;
            }
            array_add(*data.parsed_colors, Parsed_Color.{ color_name, color });
    }

    return true, "";
}

color_to_hex :: (using color: Color) -> string /* temp  */ {
    r_u8 := cast(u8)(255 * r);
    g_u8 := cast(u8)(255 * g);
    b_u8 := cast(u8)(255 * b);
    a_u8 := cast(u8)(255 * a);
    return tprint("#%1%2%3%4", formatInt(r_u8, 16), formatInt(g_u8, 16), formatInt(b_u8, 16), formatInt(a_u8, 16));
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

parse_settings_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string /* temp */ {
    setting_name, setting_value := break_by_spaces(line);
    setting_name = trim_right(setting_name, ":");

    value := setting_value;  // will be destroyed by parsing

    #insert -> string {
        b: String_Builder;

        append(*b, "if setting_name == {\n");

        for setting : SETTINGS {
            print_to_builder(*b, "    case \"%\";\n", setting.name);
            if setting.type == {
                case .boolean;
                    code := #string END
                        bool_val, success := parse_bool(*value);
                        if success {
                            parsed.settings.%1 = bool_val;
                        } else {
                            error_msg := log_parser_error(handler, "Couldn't parse '%1' - expected 'true' or 'false', got '%%'", setting_value);
                            return false, error_msg;
                        }
                    END;
                    print_to_builder(*b, code, setting.name);

                case .integer;
                    code := #string END
                        int_val, success := parse_int(*value);
                        if success {
                            parsed.settings.%1 = int_val;
                        } else {
                            error_msg := log_parser_error(handler, "Couldn't parse '%1' - expected a valid integer, got '%%'", setting_value);
                            return false, error_msg;
                        }
                    END;
                    print_to_builder(*b, code, setting.name);
            }
        }

        code := #string END
            case;
                error_msg := log_parser_error(handler, "Unrecognized setting '%'.", setting_name);
                return false, error_msg;
        END;
        append(*b, code);

        append(*b, "}\n");

        return builder_to_string(*b);
    }

    return true, "";
}

parse_keymap_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string /* temp */ {
    if begins_with(line, "[") {
        for KEYMAP_SUBSECTIONS {
            if line == it { keymap_subsection = xx it_index; return true, ""; }
        }
        error_msg := log_parser_error(handler, "Unknown keymap subsection '%'.\nAvailable options are: %.", line, join(..KEYMAP_SUBSECTIONS, ", ", allocator = temp));
        return false, error_msg;
    }

    // Parse key sequence and action
    key_sequence: [..] Key_Combo;
    key_sequence_error_message: string;
    action_name: string;
    item: string;
    rest_of_line := line;

    while true {
        // The last item we encounter will be interpreted as the action name, all parts before it will be parsed as key combinations.
        item, rest_of_line = break_by_spaces(rest_of_line);
        if !rest_of_line {
            action_name = item;
            break;
        }

        key_combo, key_ok, msg := parse_key_combo(parser, item);
        if !key_ok {
            key_sequence_error_message = msg;
            break;
        }

        array_add(*key_sequence, key_combo);
    }

    if key_sequence.count == 0 || !action_name {
        error_msg := tprint("Invalid key sequence: '%'.\n%", line, key_sequence_error_message);
        return false, error_msg;
    }

    // Parse actions
    map_action :: (name: string, key_sequence: [] Key_Combo, available_actions: [] string, target_keymap: *[..] Key_Mapping, subsection: string) #expand {
        found := false;
        for available_actions {
            if name == it {
                array_add(target_keymap, Key_Mapping.{ key_sequence = key_sequence, action = cast(u32) it_index });
                found = true;
                break;
            }
        }
        if !found {
            error_msg := log_parser_error(handler, "Invalid action '%'.\nPossible reasons:\n* It's misspelled\n* It's in the wrong section\nPlease check the default config file for a reference.", name);
            `return false, error_msg;
        }
    }

    if #complete keymap_subsection == {
        case .common;           map_action(action_name, key_sequence, ACTIONS_COMMON,           *data.keymap_common,           "[common]");
        case .editors;          map_action(action_name, key_sequence, ACTIONS_EDITORS,          *data.keymap_editors,          "[editors]");
        case .open_file_dialog; map_action(action_name, key_sequence, ACTIONS_OPEN_FILE_DIALOG, *data.keymap_open_file_dialog, "[open file dialog]");
        case .search_dialog;    map_action(action_name, key_sequence, ACTIONS_SEARCH_DIALOG,    *data.keymap_search_dialog,    "[search dialog]");
    }

    return true, "";
}

parse_key_combo :: (using parser: *Config_Parser, key_name: string) -> Key_Combo, success: bool, error_msg: string /* temp */ {
    result: Key_Combo;

    // Parse modifier flags
    modifier_string := key_name;
    while true {
        found, mod_key, remainder := split_from_left(modifier_string, cast(u8) #char "-");
        if !found break;

        if      equal_nocase(mod_key, "ctrl")       result.mods.ctrl_pressed       = true;
        else if equal_nocase(mod_key, "shift")      result.mods.shift_pressed      = true;
        else if equal_nocase(mod_key, "alt")        result.mods.alt_pressed        = true;
        else if equal_nocase(mod_key, "cmd")        result.mods.cmd_meta_pressed   = true;
        else if equal_nocase(mod_key, "meta")       result.mods.cmd_meta_pressed   = true;
        else if equal_nocase(mod_key, "super")      result.mods.cmd_meta_pressed   = true;
        else if equal_nocase(mod_key, "{ctrl}")     result.ignore.ctrl_pressed     = true;
        else if equal_nocase(mod_key, "{shift}")    result.ignore.shift_pressed    = true;
        else if equal_nocase(mod_key, "{alt}")      result.ignore.alt_pressed      = true;
        else if equal_nocase(mod_key, "{cmd}")      result.ignore.cmd_meta_pressed = true;
        else if equal_nocase(mod_key, "{meta}")     result.ignore.cmd_meta_pressed = true;
        else if equal_nocase(mod_key, "{super}")    result.ignore.cmd_meta_pressed = true;
        else {
            error_msg := log_parser_error(handler, "Unknown modifier key '%'", mod_key);
            return result, false, error_msg;
        }
        modifier_string = remainder;
    }

    key_string := modifier_string;
    if !key_string {
        error_msg := log_parser_error(handler, "Missing key code after modifier flags: '%'", key_name);
        return result, false, error_msg;
    }

    result.key_code = keymap_map_key_string(key_string);

    if !result.key_code {
        s := key_string;
        // Try single key chars, e.g. Ctrl-A, Ctrl-C etc.
        key_code, success := utf8_next_character(*s);
        if success != .CONVERSION_OK {
            error_msg := log_parser_error(handler, "Line contains invalid UTF-8");
            return result, false, error_msg;
        }

        if (key_code >= #char "a") && (key_code <= #char "z") {
            // Uppercase it, since our keyboard codes are uppercase.
            key_code += cast,trunc(u32) (#char "A" - #char "a");  // This is a negative number; but we cast it to u32 and get the same result, because, twos-complement. The trunc is to make this legal.
        }

        if s.count > 0 {
            // There are extra characters, report an error
            error_msg := log_parser_error(handler, "Expected a single char key code or a valid key name, got: '%'.", key_string);
            return result, false, error_msg;
        }

        result.key_code = key_code;
    }

    // Pre-apply the ignore mask
    result.mods.packed |= result.ignore.packed;

    return result, true, "";
}

platform_parse_config_line :: (using parser: *Config_Parser, line: string) -> success: bool, error_msg: string {
    if begins_with(line, "[") {
        for PLATFORM_SUBSECTION_NAMES {
            if line == it { platform_subsection = xx it_index; return true, ""; }
        }
        error_msg := log_parser_error(handler, "Unknown platform subsection '%'.\nAvailable options are: %.", line, join(..PLATFORM_SUBSECTION_NAMES, ", ", allocator = temp));
        return false, error_msg;
    }
    success, error_msg := platform_parse_config_line(*parsed.platform, platform_subsection, line);
    if !success log_parser_error(handler.full_path, handler.line_number, error_msg);
    return success, error_msg;
}

#scope_file

Config_Parser :: struct {
    handler: Text_File_Handler;

    parsed: Config;

    top_section: enum {
        none;
        workspace;
        keymap;
        settings;
        style;
        platform;
    } = .none;

    seen_top_sections: enum_flags {
        workspace;
        keymap;
        settings;
        style;
        platform;
    };

    workspace_subsection: enum {
        workspace_dirs;
        ignore_dirs;
        allow_file_extensions;
        ignore_file_extensions;
    };
    WORKSPACE_SUBSECTIONS :: string.[
        // Must match the order of the enum above
        "[workspace dirs]",
        "[ignore dirs]",
        "[allow file extensions]",
        "[ignore file extensions]",
    ];

    style_subsection: enum {
        user_interface;
        colors;
    };
    STYLE_SUBSECTIONS :: string.[
        // Must match the order of the enum above
        "[user interface]",
        "[colors]",
    ];

    keymap_subsection: enum {
        common;
        editors;
        open_file_dialog;
        search_dialog;
    };
    KEYMAP_SUBSECTIONS :: string.[
        // Must match the order of the enum above
        "[common]",
        "[editors]",
        "[open file dialog]",
        "[search dialog]",
    ];

    platform_subsection: PLATFORM_SUBSECTION_ENUM;

    // Will be filled during parsing
    data: struct {
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

        // Style
        font:           string;
        font_size:      int;
        parsed_colors:  [..] Parsed_Color;  // not putting in a struct so that we can override only a few colors if needed
    };
}



#import "Text_File_Handler";
