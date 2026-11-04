parse_config :: (name: string, file_path: string, file_data: string, for_highlighting := false, as_theme := false) -> Config_Parse_Result {
    // Use a pool or temporary allocator. Some parsed strings refer directly to file_data
    if !#compile_time assert(context.allocator.proc == flat_pool_allocator_proc || context.allocator.proc == temp.proc, "parse_config must use a pool or a temp allocator");

    using parser: Config_Parser;
    parser.parse_for_highlighting = for_highlighting;
    parser.parse_as_theme = as_theme;
    if file_path then parser.config_dir = get_parent_dir_path(file_path);

    // Skip leading empty lines before the handler tries to read the version
    start_from_memory(*handler, name, file_path, trim_left(file_data, " \t\n\r"));
    if handler.failed {
        result.error_msg = tprint("Couldn't parse file '%'.\nPlease check that the version number is specified at the top in brackets, otherwise check the error log.", file_path);
        return result;
    }

    result.config.version = ifx handler.version > 0 then handler.version else CURRENT_CONFIG_VERSION;

    if result.config.version != CURRENT_CONFIG_VERSION {
        // A version mismatch is a warning, we still attempt to parse the file
        array_add(*result.warnings, tprint("Invalid version [%] in file '%'. The only supported version is [%].", result.config.version, file_path, CURRENT_CONFIG_VERSION));
    }

    if parse_as_theme then section = .style;

    while true {
        line, found := consume_next_line(*handler);
        if !found break;

        parser.line = line;
        line_offset = xx (line.data - file_data.data);

        if begins_with(line, "[") {
            handled, message := parse_header(*parser);
            if message {
                highlight(*parser, line, .error);
                array_add(*result.warnings, diagnostic(*parser, message));
            }
            if handled continue;
        }

        if section == .none {
            highlight(*parser, line, .error);
            array_add(*result.warnings, diagnostic(*parser, tprint("Line outside of any section: '%'. This is an error.", line)));
            continue;
        }

        if section == .keymap && subsection == .none {
            highlight(*parser, line, .error);
            array_add(*result.warnings, diagnostic(*parser, tprint("Line outside of subsection: '%'. This is an error.", line)));
            continue;
        }

        success := true;
        message: string;
        if #complete section == {
            case .workspace;      success, message = parse_workspace(*parser);
            case .settings;       success, message = parse_settings(*parser);
            case .keymap;         success, message = parse_keymap(*parser);
            case .style;          success, message = parse_style(*parser);
            case .build_commands; success, message = parse_build(*parser);
            case .linux;          success, message = parse_linux(*parser);
            case .none;
        }

        if !success && !parse_for_highlighting {
            result.error_msg = diagnostic(*parser, message);
            return result;
        }
        if success && message then warn(*parser, message);
    }

    // Common mappings follow section-specific mappings so the latter take precedence
    array_add(*result.config.keymap_editors,          ..result.config.keymap_common);
    array_add(*result.config.keymap_open_file_dialog, ..result.config.keymap_common);
    array_add(*result.config.keymap_search_dialog,    ..result.config.keymap_common);

    // These overrides bypass the clamping applied to the global settings
    for *result.config.file_specific_settings {
        if it.overrides.tab_size.is_set then Clamp(*it.overrides.tab_size.value, 1, 100);
    }

    result.success = true;

    return result;
}

keymap_map_key_code_to_string :: (key_code: u32) -> string {
    if #char "!" <= key_code && key_code <= #char "~" {
        s := string.{1, xx *key_code};
        return tprint("%", s);
    }

    for KEY_NAMES {
        if cast(u32) it.code == key_code return it.name;
    }

    return "??";
}

#scope_file

Section :: enum {
    none;
    workspace;
    settings;
    keymap;
    style;
    build_commands;
    linux;
}

Subsection :: enum {
    none;

    ignore;
    allow;
    file_associations;

    editors;
    open_file_dialog;
    search_dialog;
    common;

    fonts;
    colors;
}

config_names :: ($T: Type) -> [] string {
    names :: #run -> [] string {
        result: [..] string;

        for type_info(T).names array_add(*result, replace(it, "_", " "));

        return result;
    }

    return names;
}

subsection_parent :: (subsection: Subsection) -> Section {
    if #complete subsection == {
        case .none;              return .none;

        case .ignore;            return .workspace;
        case .allow;             return .workspace;
        case .file_associations; return .workspace;

        case .editors;           return .keymap;
        case .open_file_dialog;  return .keymap;
        case .search_dialog;     return .keymap;
        case .common;            return .keymap;

        case .fonts;             return .style;
        case .colors;            return .style;
    }
}

Config_Parser :: struct {
    handler: Text_File_Handler;

    result: Config_Parse_Result;

    config_dir: string;  // base directory for relative workspace paths
    line: string;
    line_offset:    s32;  // byte offset after leading whitespace
    section_offset: s32;  // offset of the last section or subsection header

    section:    Section;
    subsection: Subsection;

    seen_sections:    [#run type_info(Section).names.count] bool;
    seen_subsections: [#run type_info(Subsection).names.count] bool;

    // Retain earlier locations so duplicate highlighting can recolor them
    settings: [..] Seen_Setting;
    keys:     [..] Seen_Key;
    colors:   [..] Seen_Color;
    settings.allocator = temp;
    keys.allocator     = temp;
    colors.allocator   = temp;

    parse_for_highlighting: bool;
    parse_as_theme:         bool;
    key_error:              bool;  // keep parsing invalid keys for highlighting, but skip duplicate overlays
}

highlight :: inline (p: *Config_Parser, text: string, token: Token_Type) {
    if !p.parse_for_highlighting || !text return;

    array_add(*p.result.highlights, .{
        offset     = xx (p.line_offset + text.data - p.line.data),
        count      = xx text.count,
        token_type = token,
    });
}

highlight_at :: inline (p: *Config_Parser, offset: s64, count: s64, token: Token_Type) {
    if !p.parse_for_highlighting return;

    array_add(*p.result.highlights, .{
        offset     = xx offset,
        count      = xx count,
        token_type = token,
    });
}

diagnostic :: (p: *Config_Parser, message: string) -> string {
    if p.parse_for_highlighting return "";

    formatted := tprint("Line % of '%': %", p.handler.line_number, p.handler.full_path, message);
    log_error("%", formatted);

    return formatted;
}

warn :: (p: *Config_Parser, message: string) {
    if !p.parse_for_highlighting then array_add(*p.result.warnings, diagnostic(p, message));
}

assignment :: (line: string) -> name: string, value: string {
    name, value := break_by_spaces(line);

    return trim_right(name, ":"), value;
}

parse_header :: (using p: *Config_Parser) -> handled: bool, message: string {
    if begins_with(line, "[[") {
        // Top-level section
        if parse_as_theme return true, "No top-level sections are allowed here (section is fixed to [[style]])";
        if !ends_with(line, "]]") return true, tprint("Invalid section '%'. Section definitions must end with ]]", line);

        name := trim(line, " \t[]");
        found, index := array_find(config_names(Section), name);
        if !found || index == 0 return true, tprint("Unknown top-level section %", line);

        section = xx index;
        subsection = .none;
        section_offset = line_offset;

        if seen_sections[index] return true, tprint("Section [[%]] is defined twice. This is an error.", name);
        seen_sections[index] = true;

        highlight(p, line, .header1);
        if section == .style then result.config.offsets.style_section = line_offset;
    }
    else {
        // Subsection
        if !ends_with(line, "]") return true, tprint("Invalid subsection '%'. Subsection definitions must end with ]", line);
        if section == .none return true, tprint("Subsection '%' is outside of any section. This is an error.", line);

        // These sections parse their own file-match rules or arbitrary command names
        if section == .settings || section == .build_commands return false, "";

        name := trim(line, " \t[]");
        found, index := array_find(config_names(Subsection), name);
        if !found || index == 0 || subsection_parent(cast(Subsection) index) != section {
            options: [..] string;
            options.allocator = temp;

            for config_names(Subsection) {
                if subsection_parent(cast(Subsection) it_index) == section then array_add(*options, it);
            }

            section_name := config_names(Section)[section];
            if !options return true, tprint("Unexpected subsection of [[%]]: '%'. This section doesn't allow any subsections.", section_name, line);
            return true, tprint("Unknown subsection of [[%]]: '%'.\nAvailable options: [%].", section_name, line, join(..options, "], [",, temp));
        }

        subsection = xx index;
        section_offset = line_offset;

        if seen_subsections[index] return true, tprint("Subsection [%] is defined twice. This is an error.", name);
        seen_subsections[index] = true;

        if subsection == .colors then result.config.offsets.colors_section_start = line_offset;

        if !parse_as_theme || subsection == .colors then highlight(p, line, .header2);
    }

    if subsection != .colors && result.config.offsets.colors_section_start >= 0 && result.config.offsets.colors_section_end < 0 {
        result.config.offsets.colors_section_end = line_offset;
    }
    return true, "";
}

read_value :: (value: string, $T: Type) -> val: T, success: bool, expected: string {
    val: T;
    success: bool;
    remaining := value;

    #if T == string {
        return trim(value), true, "";
    }
    else #if T == bool {
        val, success = parse_bool(*remaining);
        return val, success, "'true' or 'false'";
    }
    else #if type_info(T).type == .INTEGER {
        number, ok := parse_int(*remaining);
        return xx number, ok, "a valid integer";
    }
    else #if type_info(T).type == .FLOAT {
        number, ok := parse_float(*remaining);
        return xx number, ok, "a valid float";
    }
    else #if type_info(T).type == .ENUM {
        info := type_info(T);
        found, index := array_find(info.names, value);
        if found return xx info.values[index], true, "";
        return val, false, tprint("valid values: %", join(..info.names, ", "));
    }
    else {
        #assert false, "Unsupported config value type";
    }
}

bad_value :: (p: *Config_Parser, name: string, value: string, expected: string) -> string {
    highlight(p, value, .error);
    if begins_with(expected, "valid values:") return tprint("Couldn't parse '%' - %", name, expected);
    return tprint("Couldn't parse '%' - expected %, got '%'", name, expected, value);
}

read_setting :: (p: *Config_Parser, name: string, value: string, target: *$T, override: *Option(T) = null) -> string {
    val, ok, expected := read_value(value, T);
    if !ok return bad_value(p, name, value, expected);

    highlight(p, value, .value);

    if override then override.* = some(val);
    else target.* = val;
    return "";
}

remember_setting :: (p: *Config_Parser, name: string, build := false) {
    if !p.parse_for_highlighting return;

    duplicate := false;
    for p.settings {
        if it.name != name || (build && it.section_offset != p.section_offset) continue;
        highlight_at(p, it.line_start_offset, it.line_length, .comment);
        highlight_at(p, it.line_start_offset, it.name.count, .warning);
        duplicate = true;
    }
    if duplicate then highlight(p, ifx build then p.line else name, .warning);

    array_add(*p.settings, .{
        seen_line = .{p.line_offset, xx p.line.count, ifx build then p.section_offset else 0},
        name      = name,
    });
}

parse_settings :: (using p: *Config_Parser) -> bool, string {
    if begins_with(line, "[") {
        highlight(p, line, .header2);
        rule := trim(line, "[] ");
        wildcards: [..] string;
        langs: [..] Buffer.Lang;

        if begins_with_nocase(rule, "file:") {
            advance(*rule, 5);
            for split(rule, cast(u8) #char ",") array_add(*wildcards, copy_string(trim(it)));
        } else if begins_with_nocase(rule, "lang:") {
            advance(*rule, 5);
            for split(rule, cast(u8) #char ",",, temp) {
                lang, found := get_lang_from_name(trim(it));
                if !found {
                    if it then highlight(p, it, .error);
                    available :: #run get_supported_buffer_langs_lowercase();
                    if !it return true, tprint("Expected language name. Available languages:\n%", join(..available, ", ",, temp));
                    return true, tprint("Unknown language name: '%'\nAvailable languages:\n%", it, join(..available, ", ",, temp));
                }
                array_add(*langs, lang);
            }
        } else {
            highlight(p, line, .error);
            return true, tprint("Expected a file-specific settings subsection of the form [file: <wildcard1>, <wildcard2>, ...], or [lang: <lang1>, <lang2>, ...], got:\n%", line);
        }

        entry := array_add(*result.config.file_specific_settings);
        entry.match_rules = .{wildcards = wildcards, langs = langs};

        // Avoid highlighting duplicate settings across file-specific blocks
        array_reset_keeping_memory(*settings);
        section_offset = line_offset;

        return true, "";
    }
    highlight(p, line, .default);
    name, value := assignment(line);
    recognized := false;
    message: string;

    #insert -> string {
        b: String_Builder;
        append(*b, "if name == {\n");
        for type_info(Settings).members {
            print_to_builder(*b, "case \"%\";\nrecognized = true;\n", it.name);
            print_to_builder(*b, "override: *Option(type_of(Settings.%));\n", it.name);
            if array_find(it.notes, "overridable") {
                print_to_builder(*b, "if result.config.file_specific_settings then override = *result.config.file_specific_settings[result.config.file_specific_settings.count-1].overrides.%;\n", it.name);
            }
            print_to_builder(*b, "message = read_setting(p, name, value, *result.config.settings.%, override);\n", it.name);
        }
        append(*b, "}\n");
        return builder_to_string(*b);
    }
    if !recognized {
        highlight(p, line, .error);
        return true, tprint("Unrecognized setting '%'.", name);
    }
    if message return true, message;

    if !result.config.file_specific_settings {
        array_add_if_unique(*result.config.set_settings, name);
    } else if !is_overridable_setting(name) {
        highlight(p, line, .error);
        return true, tprint("Setting '%' cannot be used in a file-specific section.\nAvailable options are:%", name, join(..get_overridable_setting_names(), "\n - ", before_first = true));
    }

    remember_setting(p, name);

    return true, "";
}

parse_workspace :: (using p: *Config_Parser) -> bool, string {
    highlight(p, line, .default);

    if subsection == .none {
        path := copy_temporary_string(line);
        path_overwrite_separators(path, #char "/");
        path = trim_right(path, "/");

        relative := !is_absolute_path(path) && config_dir;
        absolute := path;
        if relative then absolute = ifx path == "." then config_dir else tprint("%/%", config_dir, path);

        if file_exists(absolute) {
            array_add(*result.config.members, copy_string(absolute));
        } else {
            highlight_missing_path(p, path, line, ifx relative then config_dir else "");
            return true, tprint("Attempted to load '%', but it doesn't exist", absolute);
        }
    } else if subsection == .ignore || subsection == .allow {
        target := *result.config.ignore;
        if subsection == .allow then target = *result.config.allow;

        item := trim_right(copy_string(trim(line, "\t ")), "/");
        path_overwrite_separators(item, #char "/");
        if begins_with(item, "./") {
            // Expand relative patterns for each workspace directory already parsed
            advance(*item, 2);
            for result.config.members {
                is_dir, ok := is_directory(it);
                if is_dir && ok then add_file_pattern(target, sprint("%/%", it, item));
            }
        } else {
            add_file_pattern(target, item);
        }
    } else if subsection == .file_associations {
        found, patterns, name := split_from_left(line, cast(u8) #char ":");
        patterns, name = trim(patterns), trim(name);

        if !found || !patterns || !name {
            highlight(p, line, .comment);  // don't flag an incomplete entry as an error while typing
            return true, tprint("Invalid file association: '%'\nThe correct format is: '<wildcard1> <wildcard2> ... : <language>'", line);
        }

        lang, ok := get_lang_from_name(name);
        if !ok {
            highlight(p, name, .error);
            available :: #run get_supported_buffer_langs_lowercase();
            return true, tprint("Unknown language name: '%'\nAvailable languages:\n%", name, join(..available, ", ",, temp));
        }
        for split(patterns, cast(u8) #char " ",, temp) {
            array_add(*result.config.file_associations, .{wildcard = trim(it), lang = lang});
        }
    }
    return true, "";
}

add_file_pattern :: (target: *[..] File_Pattern, pattern: string) {
    #if OS == .WINDOWS then to_lower_in_place(pattern);
    array_add(target, construct_file_pattern(pattern));
}

highlight_missing_path :: (p: *Config_Parser, path: string, source: string, base: string) {
    if !p.parse_for_highlighting return;

    for split(path, "/",, temp) {
        prefix := slice(path, 0, it.data - path.data + it.count);
        if !prefix continue;

        absolute := ifx base then tprint("%/%", base, prefix) else prefix;
        if !file_exists(absolute) {
            highlight_at(p, p.line_offset + source.data - p.line.data + it.data - path.data, it.count, .error);
            break;
        }
    }
}

parse_style :: (using p: *Config_Parser) -> bool, string {
    if parse_as_theme && subsection != .colors {
        // Theme files ignore font and other non-color settings
        highlight(p, line, .comment);
        return true, "";
    }
    highlight(p, line, .default);
    name, value := assignment(line);

    if subsection == .colors {
        ok, message := parse_color(p, name, value);
        return ok, message;
    }

    if subsection == .fonts {
        ok, message := parse_font(p, name, value);
        return ok, message;
    }

    if name != "theme" {
        highlight(p, name, .error);
        return true, tprint("Unknown style option '%'. Available option: theme.", name);
    }

    result.config.theme = value;
    result.config.offsets.theme_line = line_offset;

    path := get_theme_path_from_name(value);
    if value != "default" && !file_exists(path) {
        highlight(p, value, .error);
        return true, tprint("Couldn't find theme file '%'", path);
    }
    return true, "";
}

parse_font :: (p: *Config_Parser, name: string, value: string) -> bool, string {
    target: *string;

    if name == {
        case "font";                target = *p.result.config.font;
        case "font_ui";             target = *p.result.config.font_ui;
        case "font_ui_bold";        target = *p.result.config.font_ui_bold;
        case "font_ui_bold_italic"; target = *p.result.config.font_ui_bold_italic;
    }

    if target {
        found, message := find_font_by_name(value);
        target.* = ifx found then value else "default";
        if !found then highlight(p, value, .error);
        return true, ifx found then "" else message;
    }

    if name == "font_size" || name == "font_ui_size" {
        remaining := value;
        number, ok := parse_int(*remaining);
        size := *p.result.config.font_size;
        fallback := DEFAULT_FONT_MAIN_SIZE;

        if name == "font_ui_size" {
            size = *p.result.config.font_ui_size;
            fallback = DEFAULT_FONT_UI_SIZE;
        }

        size.* = ifx ok then number else fallback;
        if !ok return false, bad_value(p, name, value, "a valid integer");
        return true, "";
    }

    if name == "hinting" {
        val, ok, expected := read_value(value, bool);
        if !ok return true, bad_value(p, name, value, expected);
        p.result.config.font_hinting = some(val);
        highlight(p, value, .value);
        return true, "";
    }

    if name == "anti_aliasing" {
        val, ok := read_value(value, Font_Anti_Aliasing);
        if !ok {
            highlight(p, value, .error);
            return true, tprint("Couldn't parse '%' - valid values: %", name, type_info(Font_Anti_Aliasing).names);
        }
        p.result.config.font_anti_aliasing = some(val);
        highlight(p, value, .value);
        return true, "";
    }

    highlight(p, name, .error);
    return true, tprint("Unknown font option '%'. Available options: ", name);
}

COLOR_NAMES :: #run -> [] string {
    names: [..] string;

    for type_info(Color).names {
        name := to_lower_copy(it);
        name = replace(name, "background_", "background");
        array_add(*names, name);
    }

    return names;
}

map_name_to_color :: (name: string) -> Color {
    if begins_with(name, "code_") {
        advance(*name, 5);
        found, index := array_find(type_info(Token_Type).names, name);
        if found return xx index;
        return .NONE;
    }

    found, index := array_find(COLOR_NAMES, name);
    if found && name != "none" then return xx type_info(Color).values[index];
    return .NONE;
}

parse_color :: (using p: *Config_Parser, name: string, value: string) -> bool, string {
    if result.config.theme then highlight(p, line, .comment);

    id := map_name_to_color(name);
    if id == .NONE {
        highlight(p, name, .error);
        return true, tprint("Unknown color '%'", name);
    }

    if begins_with(value, "$") {
        // Record references for later use, the parser does not resolve them
        reference := value;
        advance(*reference, 1);
        other := map_name_to_color(reference);
        if other == .NONE {
            highlight(p, value, .error);
            return true, tprint("Attempted to reference an unknown color '$%'", reference);
        }

        highlight(p, value, .value);
        array_add(*result.config.color_refs, .{
            color_name   = name,
            color        = id,
            wants_to_use = other,
            seen_line    = .{line_offset, xx line.count, section_offset},
        });
    } else {
        color, ok := hex_to_color_vec4(value);
        if !ok {
            highlight(p, value, .error);
            return true, tprint("Couldn't parse '%'. Expected a color in the form RRGGBB or RRGGBBAA, got '%'", name, value);
        }
        array_add(*result.config.colors, .{id, color});
    }

    duplicate := false;
    for colors {
        if it.color != id continue;
        highlight_at(p, it.line_start_offset, it.line_length, .warning);
        highlight_at(p, it.line_start_offset, name.count, .warning);
        duplicate = true;
    }
    if duplicate then highlight(p, line, .warning);

    array_add(*colors, .{
        seen_line = .{line_offset, xx line.count, section_offset},
        color     = id,
    });
    return true, "";
}

highlight_variables :: (p: *Config_Parser, value: string, for_working_dir := false) -> found: bool {
    found := false;

    for name, index: BUILD_VARIABLE_NAMES {
        if for_working_dir && build_variable_is_command_only(cast(Build_Variable) index) continue;

        start := 0;
        while true {
            index := find_index_from_left(value, name, start);
            if index < 0 break;
            highlight_at(p, p.line_offset + value.data - p.line.data + index, name.count, .value);
            found = true;
            start = index + name.count;
        }
    }

    return found;
}

parse_build :: (using p: *Config_Parser) -> bool, string {
    using result.config.build;

    key_error = false;

    if begins_with(line, "[") {
        name := trim(line, "[]");
        if !name {
            highlight(p, line, .error);
            return true, tprint("Command name can't be empty: %", line);
        }
        highlight(p, line, .header2);
        command := array_add(*commands);
        command.* = defaults;  // Inherit the defaults as they stood when this command was encountered
        command.name = name;
        section_offset = line_offset;
        return true, "";
    }

    highlight(p, line, .default);

    target := *defaults;
    if commands then target = *commands[commands.count-1];

    name, value := assignment(line);

    if name == "key_binding" {
        sequence, message := parse_key_sequence(p, value);
        if !sequence return true, tprint("Invalid key combination: '%'. Error: %", value, message);

        action := cast(u32) commands.count;
        replaced := false;
        for *keymap {
            // The most recent binding for a command replaces its earlier binding
            if it.action != action continue;
            it.key_sequence = sequence;
            replaced = true;
            break;
        }
        if !replaced then array_add(*keymap, .{sequence, action});

        saved := section_offset;
        section_offset = 0;  // Build bindings must also be compared with bindings from other sections
        remember_key(p, sequence);
        section_offset = saved;
    } else {
        recognized := false;
        message: string;

        #insert -> string {
            b: String_Builder;
            append(*b, "if name == {\n");
            for type_info(Build_Command).members {
                if array_find(it.notes, "dontparse") continue;
                print_to_builder(*b, "case \"%\"; recognized = true; message = read_build_value(p, name, value, *target.%);\n", it.name, it.name);
            }
            append(*b, "}\n");
            return builder_to_string(*b);
        }
        if !recognized {
            highlight(p, line, .error);
            return true, tprint("Unrecognized build command option '%'.", name);
        }
        if message return true, message;

        if name == "build_working_dir" || name == "run_working_dir" {
            // Paths containing variables cannot be validated until the command runs
            if highlight_variables(p, value, for_working_dir = true) return true, "";

            path := copy_temporary_string(value);
            path_overwrite_separators(path, #char "/");

            base := get_working_directory_from_workspace(result.config.members);
            relative := !is_absolute_path(path) && base;
            absolute := ifx relative then tprint("%/%", base, path) else path;

            if file_exists(absolute) {
                if name == "build_working_dir" then target.build_working_dir = copy_string(absolute);
                else target.run_working_dir = copy_string(absolute);
                return true, "";
            }

            // An empty workspace does not provide a base for checking relative paths
            if !is_absolute_path(path) && !base return true, "";
            highlight_missing_path(p, path, value, ifx relative then base else "");
            return true, tprint("Tried to use '%' as a working dir in a build command, but it doesn't exist.", absolute);
        }

        if name == "build_command" || name == "run_command" then highlight_variables(p, value);
        if name == "error_regex" {
            _, valid := re.compile(value, .LikePerl & ~.OneLine);
            if !valid {
                highlight(p, value, .error);
                return true, tprint("Error regex is invalid: '%'", value);
            }
        }
    }

    if !key_error then remember_setting(p, name, build = true);
    return true, "";
}

read_build_value :: (p: *Config_Parser, name: string, value: string, target: *$T) -> string {
    #if T == string {
        if !value return tprint("Build command option '%' can't be empty", name);
        target.* = value;
    } else {
        val, ok, expected := read_value(value, T);
        if !ok {
            #if type_info(T).type == .INTEGER {
                highlight(p, value, .error);
                return tprint("Couldn't parse '%' - a valid integer, got '%'", name, value);
            } else {
                return bad_value(p, name, value, expected);
            }
        }
        target.* = val;
        highlight(p, value, .value);
    }
    return "";
}

parse_linux :: (using p: *Config_Parser) -> bool, string {
    highlight(p, line, .default);
    name, value := assignment(line);

    if name == {
        case "scaling_factor";
            val, ok, expected := read_value(value, float);
            if !ok return true, bad_value(p, name, value, expected);
            lower := ifx DEBUG then 0.5 else 1.0;
            if val != 0.0 && (val < lower || val > 5.0) {
                highlight(p, value, .error);
                return true, tprint("Couldn't parse '%' - value out of the expected range ([% ... 5.0])", lower, name);
            }
            result.config.linux.scaling_factor = val;
        case "explorer_command";        result.config.linux.explorer_command = value;
        case "explorer_reveal_command"; result.config.linux.explorer_reveal_command = value;
        case;
            highlight(p, line, .error);
            return true, tprint("Unknown setting '%' in section [[linux]]", name);
    }
    return true, "";
}

ACTION_SECTIONS :: Subsection.[
    .common,
    .editors,
    .open_file_dialog,
    .search_dialog,
];

ACTION_NAMES :: [] string.[
    ACTIONS_COMMON,
    ACTIONS_EDITORS,
    ACTIONS_OPEN_FILE_DIALOG,
    ACTIONS_SEARCH_DIALOG,
];

parse_keymap :: (using p: *Config_Parser) -> bool, string {
    highlight(p, line, .default);
    key_error = false;

    found, sequence_text, action_name := split_from_right_by_any(line, " \t");
    if !found {
        highlight(p, line, .error);
        return true, tprint("Invalid key mapping: '%'. \nExpected format: <key_sequence> <action_name>", line);
    }

    sequence_text = trim_right(sequence_text);
    sequence, message := parse_key_sequence(p, sequence_text);
    if !sequence return true, tprint("Invalid key sequence: '%'. Error: %", sequence_text, message);

    target: *[..] Key_Mapping;
    if subsection == {
        case .common;           target = *result.config.keymap_common;
        case .editors;          target = *result.config.keymap_editors;
        case .open_file_dialog; target = *result.config.keymap_open_file_dialog;
        case .search_dialog;    target = *result.config.keymap_search_dialog;
    }

    _, group := array_find(ACTION_SECTIONS, subsection);
    known, action := array_find(ACTION_NAMES[group], action_name);
    if !known {
        if parse_for_highlighting {
            highlight(p, action_name, .error);
            return true, "";
        }
        message = tprint("Unknown action '%'. Is it misspelled? Please check the default config file for a reference.", action_name);
        for ACTION_SECTIONS {
            if it == subsection || !array_find(ACTION_NAMES[it_index], action_name) continue;
            message = tprint("Action '%' is not available in the [%] section. However, it is available in the [%] section", action_name, config_names(Subsection)[subsection], config_names(Subsection)[it]);
            break;
        }
        return true, message;
    }

    array_add(target, .{sequence, xx action});
    if !key_error then remember_key(p, sequence);
    return true, "";
}

remember_key :: (using p: *Config_Parser, sequence: [] Key_Combo) {
    if !parse_for_highlighting return;

    for keys {
        if it.section_offset != section_offset && it.section_offset != 0 && section_offset != 0 continue;
        if !key_sequence_matches(it.sequence, sequence) continue;
        highlight_at(p, it.line_start_offset, it.line_length, .warning);
        highlight(p, line, .warning);
        break;
    }

    array_add(*keys, .{
        seen_line = .{line_offset, xx line.count, section_offset},
        sequence  = sequence,
    });
}

parse_key_sequence :: (p: *Config_Parser, text: string) -> [] Key_Combo, string {
    sequence: [..] Key_Combo;
    remaining := text;

    while remaining {
        word:, remaining = break_by_spaces(remaining);

        combo, ok, message := parse_key_combo(p, word);
        if !ok return .[], message;

        array_add(*sequence, combo);
    }
    return sequence, "";
}

parse_key_combo :: (using p: *Config_Parser, text: string) -> combo: Key_Combo, success: bool, message: string {
    combo: Key_Combo;

    key := text;
    while true {
        found, modifier, rest := split_from_left(key, cast(u8) #char "-");
        if !found break;

        valid := true;
        if to_lower_copy(modifier,, temp) == {
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
                valid = false;
                if !parse_for_highlighting return combo, false, tprint("Unknown modifier key '%'. Allowed modifiers: Ctrl, Shift, Alt, Meta, Super, Cmd.", modifier);
                highlight(p, modifier, .error);
                key_error = true;
        }

        if valid then highlight(p, modifier, .value);
        key = rest;
    }

    if !key {
        highlight(p, text, .error);
        return combo, false, tprint("Missing key code after modifier flags: '%'", text);
    }
    for KEY_NAMES {
        if equal_nocase(key, it.name) {
            combo.key_code = xx it.code;
            break;
        }
    }

    if !combo.key_code {
        // Try a single UTF-8 character when the key has no named code
        remaining := key;
        code, status := utf8_next_character(*remaining);
        if status != .CONVERSION_OK {
            highlight(p, key, .error);
            key_error = true;
            return combo, false, "Line contains invalid UTF-8";
        }

        // Input key codes use uppercase ASCII letters
        if #char "a" <= code && code <= #char "z" then code -= #char "a" - #char "A";

        if remaining {
            if !parse_for_highlighting return combo, false, tprint("Expected a single char key code or a valid key name, got: '%'.", key);
            highlight(p, key, .error);
            key_error = true;
        }

        combo.key_code = code;
    }

    // Pre-apply the ignore mask to match keymap lookup
    combo.mods.packed |= combo.ignore.packed;

    return combo, true, "";
}

Key_Name :: struct {
    name: string;
    code: Input.Key_Code;
}

using Input.Key_Code;

KEY_NAMES :: Key_Name.[
    .{"ArrowUp",        ARROW_UP},
    .{"ArrowDown",      ARROW_DOWN},
    .{"ArrowLeft",      ARROW_LEFT},
    .{"ArrowRight",     ARROW_RIGHT},

    .{"Escape",         ESCAPE},
    .{"Delete",         DELETE},
    .{"Insert",         INSERT},
    .{"End",            END},
    .{"Home",           HOME},
    .{"Backspace",      BACKSPACE},
    .{"PrintScreen",    PRINT_SCREEN},
    .{"Pause",          PAUSE},
    .{"PageUp",         PAGE_UP},
    .{"PageDown",       PAGE_DOWN},
    .{"ScrollLock",     SCROLL_LOCK},
    .{"Enter",          ENTER},
    .{"Return",         ENTER},
    .{"Tab",            TAB},
    .{"Shift",          SHIFT},
    .{"Alt",            ALT},
    .{"Control",        CTRL},
    .{"Space",          #char " "},
    .{"Plus",           #char "+"},
    .{"Minus",          #char "-"},
    .{"Hash",           #char "#"},

    .{"F1",             F1},
    .{"F2",             F2},
    .{"F3",             F3},
    .{"F4",             F4},
    .{"F5",             F5},
    .{"F6",             F6},
    .{"F7",             F7},
    .{"F8",             F8},
    .{"F9",             F9},
    .{"F10",            F10},
    .{"F11",            F11},
    .{"F12",            F12},
    .{"F13",            F13},
    .{"F14",            F14},
    .{"F15",            F15},
    .{"F16",            F16},
    .{"F17",            F17},
    .{"F18",            F18},
    .{"F19",            F19},
    .{"F20",            F20},
    .{"F21",            F21},
    .{"F22",            F22},
    .{"F23",            F23},
    .{"F24",            F24},

    .{"Numpad0",        NUMPAD_0},
    .{"Numpad1",        NUMPAD_1},
    .{"Numpad2",        NUMPAD_2},
    .{"Numpad3",        NUMPAD_3},
    .{"Numpad4",        NUMPAD_4},
    .{"Numpad5",        NUMPAD_5},
    .{"Numpad6",        NUMPAD_6},
    .{"Numpad7",        NUMPAD_7},
    .{"Numpad8",        NUMPAD_8},
    .{"Numpad9",        NUMPAD_9},
    .{"NumpadMultiply", NUMPAD_MULTIPLY},
    .{"NumpadDivide",   NUMPAD_DIVIDE},
    .{"NumpadAdd",      NUMPAD_ADD},
    .{"NumpadSubtract", NUMPAD_SUBTRACT},
    .{"NumpadDecimal",  NUMPAD_DECIMAL},
    .{"NumpadEnter",    NUMPAD_ENTER},

    .{"MouseLeft",      MOUSE_BUTTON_LEFT},
    .{"MouseRight",     MOUSE_BUTTON_RIGHT},
    .{"MouseMiddle",    MOUSE_BUTTON_MIDDLE},
    .{"MouseX1",        MOUSE_BUTTON_X1},
    .{"MouseX2",        MOUSE_BUTTON_X2},

    // Mouse wheel bindings are not supported because handled events would need to block scrolling
];

Seen_Line :: struct {
    line_start_offset: s32;
    line_length:       s32;
    section_offset:    s32;
}

Seen_Setting :: struct {
    using seen_line: Seen_Line;
    name: string;
}

Seen_Key :: struct {
    using seen_line: Seen_Line;
    sequence: [] Key_Combo;
}

Seen_Color :: struct {
    using seen_line: Seen_Line;
    color: Color;
}

// @colorref: not finished
Color_Reference :: struct {
    color_name:   string;
    color:        Color;
    wants_to_use: Color;
    using seen_line: Seen_Line;
}

#scope_export

// A struct to represent the raw parsed config, where not everything might be present
// (we need to know what's missing so that we can properly merge the global config with the project config, for example)
Parsed_Config :: struct {
    version: int;

    // Workspace
    members:           [..] string;
    ignore:            [..] File_Pattern;
    allow:             [..] File_Pattern;
    file_associations: [..] File_Association;

    // Keymap
    keymap_common:           [..] Key_Mapping;
    keymap_editors:          [..] Key_Mapping;
    keymap_open_file_dialog: [..] Key_Mapping;
    keymap_search_dialog:    [..] Key_Mapping;

    // Settings
    settings:               Settings;
    set_settings:           [..] string;  // Only explicitly supplied settings participate in merging
    file_specific_settings: [..] File_Specific_Settings;

    // Style
    theme:               string;
    font:                string;
    font_size:           int;
    font_ui:             string;
    font_ui_bold:        string;
    font_ui_bold_italic: string;
    font_ui_size:        int;
    font_hinting:        Option(bool);
    font_anti_aliasing:  Option(Font_Anti_Aliasing);
    colors:              [..] Parsed_Color;
    color_refs:          [..] Color_Reference;

    // Build
    build: Build_Config;

    // Platform-specific
    linux: Linux_Config;

    // Byte offsets into the file
    offsets: struct {
        style_section := -1;
        theme_line    := -1;

        colors_section_start := -1;
        colors_section_end   := -1;
    };
}

Config_Parse_Result :: struct {
    config:    Parsed_Config;
    success:   bool;
    error_msg: string;  // Temporary storage

    warnings: [..] string;
    warnings.allocator = temp;

    highlights: [..] Code_Highlight;
    highlights.allocator = temp;
}

Parsed_Color :: struct {
    color_id: Color;
    color:    Vector4;
}
