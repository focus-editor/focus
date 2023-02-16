parse_config :: (name: string, filename: string, file_data: string) -> Config, success: bool {
    parser: Config_Parser;
    result: Config;
    
    // NOTE: we don't free on purpose, because some of the parsed data will point into the file data    
    start_from_memory(*parser.handler, name, filename, file_data);
    if parser.handler.failed return Config.{}, false;
    
    while true {
        line, found := consume_next_line(*parser.handler);
        if !found break;
        
        // Maybe switch to a different top section
        if begins_with(line, "[[") {
            error := switch_top_section(*parser, line);
            if error return Config.{}, false;
            continue;
        }
        
        if #complete parser.top_section == {
            case .none;
                error(parser.handler, "Expected a top-level section definition, got '%'", line);
                return result, false;
                
            case .workspace;
                success := parse_workspace_line(*parser, line);
                if !success return result, false;
                
            case .settings;
                // TODO
                
            case .keymap;
                success := parse_keymap_line(*parser, line);
                if !success return result, false;
                                
        }
    }
    
    // Cast away the extendable arrays into array views
    result.workspace.workspace_dirs = parser.data.workspace_dirs;
    result.workspace.ignore_dirs = parser.data.ignore_dirs;
    result.workspace.allow_file_extensions = parser.data.allow_file_extensions;
    result.workspace.ignore_file_extensions = parser.data.ignore_file_extensions;
    
    return result, true;
}


#scope_file

switch_top_section :: (using parser: *Config_Parser, line: string) -> error: bool {
    if line == {
        case "[[workspace]]";
            top_section = .workspace;
            if seen_top_sections & .workspace { error(handler, "The section '[[workspace]]' is defined twice. This is an error."); return true; }
            seen_top_sections |= .workspace;
            
        case "[[keymap]]";
            top_section = .keymap;
            if seen_top_sections & .keymap { error(handler, "The section '[[keymap]]' is defined twice. This is an error."); return true; }
            seen_top_sections |= .keymap;
            
        case "[[settings]]";
            top_section = .settings;
            if seen_top_sections & .settings { error(handler, "The section '[[settings]]' is defined twice. This is an error."); return true; }
            seen_top_sections |= .settings;
            
        case;
            error(handler, "Expected one of the following top-level sections: '[[workspace]]', '[[settings]]', '[[keymap]]', but found '%'", line);
            return true;
    }
    
    return false;
}

parse_workspace_line :: (using parser: *Config_Parser, line: string) -> success: bool {
    if begins_with(line, "[") {
        for WORKSPACE_SUBSECTIONS {
            if line == it { workspace_subsection = xx it_index; return true; }
        }
        error(handler, "Unknown workspace subsection '%'. Available options are: %.", line, join(..WORKSPACE_SUBSECTIONS, ", ", allocator = temp));
        return false;
    }
    if #complete workspace_subsection == {
        case .workspace_dirs;
            dir_path := line;
            if file_exists(dir_path) {
                array_add(*data.workspace_dirs, dir_path);
            } else {
                error(handler, "Directory '%' doesn't exist, skipping...", dir_path);
            }
        case .ignore_dirs;
            dirs := split(line, cast(u8) #char " ");
            for dir : dirs {
                if !dir continue;
                array_add(*data.ignore_dirs, dir);
            }
        case .allow_file_extensions;
            extensions := split(line, cast(u8) #char " ");
            for extensions {
                if !it continue;
                array_add(*data.allow_file_extensions, it);
            }
        case .ignore_file_extensions;
            extensions := split(line, cast(u8) #char " ");
            for extensions {
                if !it continue;
                array_add(*data.ignore_file_extensions, it);
            }
    }
    return true;
}

parse_keymap_line :: (using parser: *Config_Parser, line: string) -> success: bool {
    if begins_with(line, "[") {
        for KEYMAP_SUBSECTIONS {
            if line == it { keymap_subsection = xx it_index; return true; }
        }
        error(handler, "Unknown keymap subsection '%'. Available options are: %.", line, join(..KEYMAP_SUBSECTIONS, ", ", allocator = temp));
        return false;
    }
    
    key_name, action_name := break_by_spaces(line);
    if !action_name {
        error(handler, "Expected a space after the key combo, found '%'", key_name);
        return false;
    }
    
    
    key_combo, key_ok := parse_key_combo(handler, key_name);
    if !key_ok {
        error(handler, "Invalid key combo: '%'. Note that spaces aren't allowed in key combos.", key_name);
        return false;
    }
    
    return true;
}

parse_key_combo :: (handler: Text_File_Handler, key_name: string) -> Key_Combo, success: bool {
    result: Key_Combo;
    
    // Parse modifier flags
    modifier_string := key_name;
    while true {
        found, mod_key, remainder := split_from_left(modifier_string, cast(u8) #char "-");
        if !found break;
        
        if      equal_nocase(mod_key, "ctrl")  result.mods.ctrl_pressed  = true;
        else if equal_nocase(mod_key, "shift") result.mods.shift_pressed = true;
        else if equal_nocase(mod_key, "alt")   result.mods.alt_pressed   = true;
        else {
            error(handler, "Unknown modifier key '%'", mod_key);
            return result, false;
        }
        modifier_string = remainder;
    }
    
    key_string := modifier_string;
    if !key_string {
        error(handler, "Missing key code after modifier flags: '%'", key_name);
        return result, false;
    }
    
    return result, true;
}


#scope_file

Config_Parser :: struct {
    handler: Text_File_Handler;
    
    top_section: enum {
        none;
        workspace;
        keymap;
        settings;
    } = .none;
    
    seen_top_sections: enum_flags {
        workspace;
        keymap;
        settings;
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
    
    // Will be filled during parsing
    data: struct {
        // Workspace
        workspace_dirs:         [..] string;
        ignore_dirs:            [..] string;
        allow_file_extensions:  [..] string;
        ignore_file_extensions: [..] string;
    };
}

Key_Combo :: struct {
    key_code: Input.Key_Code;
    mods: Mods;
}

KEYMAP_COMMON_ACTIONS :: string.[
    "search_in_buffer",
    "search_in_project",
    "show_open_file_dialog_in_search_mode",
    "show_open_file_dialog_in_navigate_mode",
    "show_open_file_dialog_in_navigate_mode_from_root",
    "copy",
    "cut",
    "paste",
    "undo",
    "redo",
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
    "move_left_by_word_end",
    "move_right",
    "move_right_by_word",
    "move_right_by_word_end",
    "home",
    "end",
    "delete_left_char",
    "delete_right_char",
    "increase_font_size",
    "decrease_font_size",
    "reset_font_size_to_default",
];

KEYMAP_EDITORS_ACTIONS :: string.[
    "select_word_or_create_another_cursor",
    "duplicate_lines",
    "move_selected_lines_up",
    "move_selected_lines_down",
    "indent_or_go_to_next_tabstop",
    "unindent",
    "indent",
    "close_current_editor",
    "close_other_editor",
    "save",
    "toggle_comment",
    "scroll_viewport_up",
    "scroll_viewport_down",
    "scroll_viewport_left",
    "scroll_viewport_right",
    "move_cursor_to_viewport_center",
    "remove_additional_cursors",
    "break_line",
    "new_line_below_without_breaking",
    "new_line_above_without_breaking",
    "switch_to_left_editor",
    "switch_to_left_editor",
    "switch_to_right_editor",
    "switch_to_right_editor",
    "move_editor_to_the_left",
    "move_editor_to_the_right",
];

KEYMAP_OPEN_FILE_DIALOG_ACTIONS :: string.[
    "close_dialog",
    "open_entry_in_place",
    "open_entry_on_the_side",
    "open_entry_on_the_left",
    "open_entry_on_the_right",
    "open_directory",
];

KEYMAP_SEARCH_DIALOG_ACTIONS :: string.[
    "close_dialog",
    "open_entry_in_place",
    "open_entry_on_the_side",
    "open_entry_on_the_left",
    "open_entry_on_the_right",
];


#import "Text_File_Handler";