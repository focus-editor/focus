parse_config :: (name: string, filename: string, file_data: string) -> Config, success: bool {
    handler: Text_File_Handler;
    // NOTE: we don't free on purpose, because some of the parsed data will point into the file data
    
    start_from_memory(*handler, name, filename, file_data);
    if handler.failed return Config.{}, false;
    
    parser: Config_Parser;
    result: Config;
    
    while true {
        line, found := consume_next_line(*handler);
        if !found break;
        
        // Maybe switch to a different top section
        if begins_with(line, "[[") {
            error := switch_top_section(*parser, line);
            if error return Config.{}, false;
            continue;
        }
        
        if #complete parser.top_section == {
            case .none;
                log_error("Expected a top-level section definition, got '%'", line);
                return result, false;
                
            case .workspace;
                success := parse_workspace_line(*parser, line);
                if !success return result, false;
                
            case .settings;
                // TODO
                
            case .keymap;
                success := parse_keymap_line(*parser, line);
                if !success return result, false;
                
            case .colors;
                // TODO
                                
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
            if seen_top_sections & .workspace { log_error("The section '[[workspace]]' is defined twice. This is an error."); return true; }
            seen_top_sections |= .workspace;
            
        case "[[keymap]]";
            top_section = .keymap;
            if seen_top_sections & .keymap { log_error("The section '[[keymap]]' is defined twice. This is an error."); return true; }
            seen_top_sections |= .keymap;
            
        case "[[colors]]";
            top_section = .colors;
            if seen_top_sections & .colors { log_error("The section '[[colors]]' is defined twice. This is an error."); return true; }
            seen_top_sections |= .colors;
            
        case "[[settings]]";
            top_section = .settings;
            if seen_top_sections & .settings { log_error("The section '[[settings]]' is defined twice. This is an error."); return true; }
            seen_top_sections |= .settings;
            
        case;
            log_error("Expected one of the following top-level sections: '[[workspace]]', '[[settings]]', '[[keymap]]', '[[colors]]', but found '%'", line);
            return true;
    }
    
    return false;
}

parse_workspace_line :: (using parser: *Config_Parser, line: string) -> success: bool {
    if begins_with(line, "[") {
        if line == {
            case "[workspace dirs]";         workspace_subsection = .workspace_dirs;
            case "[ignore dirs]";            workspace_subsection = .ignore_dirs;
            case "[allow file extensions]";  workspace_subsection = .allow_file_extensions;
            case "[ignore file extensions]"; workspace_subsection = .ignore_file_extensions;
            case; log_error("Unknown subsection '%'", line); return false;
        }
        return true;
    }
    if #complete workspace_subsection == {
        case .none;
            log_error("Expected a subsection definition, got '%'", line);
            return false;
        case .workspace_dirs;
            dir_path := line;
            if file_exists(dir_path) {
                array_add(*data.workspace_dirs, dir_path);
            } else {
                log_error("Directory '%' doesn't exist, skipping...", dir_path);
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
    return true;
}


#scope_file

Config_Parser :: struct {
    top_section: enum {
        none;
        workspace;
        keymap;
        colors;
        settings;
    } = .none;
    
    seen_top_sections: enum_flags {
        workspace;
        keymap;
        colors;
        settings;
    };
    
    workspace_subsection: enum {
        none;
        workspace_dirs;
        ignore_dirs;
        allow_file_extensions;
        ignore_file_extensions;
    };
    
    // Will be filled during parsing
    data: struct {
        // Workspace
        workspace_dirs:         [..] string;
        ignore_dirs:            [..] string;
        allow_file_extensions:  [..] string;
        ignore_file_extensions: [..] string;
    };
}

#import "Text_File_Handler";