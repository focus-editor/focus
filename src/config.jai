load_global_config :: () {
    global_config, success, error_msg := load_config(tprint("%/global.focus-config", exe_dir), create_if_doesnt_exist = !DEBUG);
    if !success {
        if error_msg then log_error(error_msg);
        return;
    }
    merge_configs(*config, global_config);
}

load_project_config :: (project_name: string) -> success: bool {
    config_path := tprint("%/projects/%.focus-config", exe_dir, project_name);
    project_config, success, error_msg := load_config(config_path);
    if !success {
        if error_msg then log_error(error_msg);
        return false;
    }
    merge_configs(*config, project_config);
    return true;
}

#scope_file

load_config :: (file_path: string, create_if_doesnt_exist := false) -> Config, success: bool, error_msg: string /* tmp */ {
    empty: Config;
    
    if !file_exists(file_path) {
        if !create_if_doesnt_exist return empty, false, "";  // no error message because it's not an error
        
        // Create one with default contents
        success := write_entire_file(file_path, DEFAULT_CONFIG_FILE_DATA);
        if !success return empty, false, tprint("Couldn't create a config file '%'", file_path);
    }
    
    file_data, success_read := read_entire_file(file_path);
    if !success_read return empty, false, tprint("Couldn't read file '%'", file_path);
    
    config, success_parse := parse_config("Global Config", file_path, file_data);
    if !success_parse return empty, false, tprint("Couldn't parse config file '%'", file_path);
    
    return config, true, "";
}

merge_configs :: (dst: *Config, src: Config) {
    // Workspace
    if src.workspace.workspace_dirs         then dst.workspace.workspace_dirs         = src.workspace.workspace_dirs;
    if src.workspace.ignore_dirs            then dst.workspace.ignore_dirs            = src.workspace.ignore_dirs;
    if src.workspace.allow_file_extensions  then dst.workspace.allow_file_extensions  = src.workspace.allow_file_extensions;
    if src.workspace.ignore_file_extensions then dst.workspace.ignore_file_extensions = src.workspace.ignore_file_extensions;
    
    // TODO: other sections;
}

parse_config :: (name: string, filename: string, file_data: string) -> Config, success: bool {
    handler: Text_File_Handler;
    // NOTE: we don't free on purpose, because some of the parsed data will point into the file data
    
    start_from_memory(*handler, name, filename, file_data);
    if handler.failed return Config.{}, false;
    
    parser: Config_Parser;
    result: Config;
    
    // Will be filled as the file parses
    workspace_dirs:         [..] string;
    ignore_dirs:            [..] string;
    allow_file_extensions:  [..] string;
    ignore_file_extensions: [..] string;
    
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
                if begins_with(line, "[") {
                    if line == {
                        case "[workspace dirs]";         parser.workspace_subsection = .workspace_dirs;
                        case "[ignore dirs]";            parser.workspace_subsection = .ignore_dirs;
                        case "[allow file extensions]";  parser.workspace_subsection = .allow_file_extensions;
                        case "[ignore file extensions]"; parser.workspace_subsection = .ignore_file_extensions;
                        case; log_error("Unknown subsection '%'", line); return result, false;
                    }
                    continue;
                }
                if #complete parser.workspace_subsection == {
                    case .none;
                        log_error("Expected a subsection definition, got '%'", line);
                        return result, false;
                    case .workspace_dirs;
                        dir_path := line;
                        if file_exists(dir_path) {
                            array_add(*workspace_dirs, dir_path);
                        } else {
                            log_error("Directory '%' doesn't exist, skipping...", dir_path);
                        }
                    case .ignore_dirs;
                        dirs := split(line, cast(u8) #char " ");
                        for dir : dirs {
                            if !dir continue;
                            array_add(*ignore_dirs, dir);
                        }
                    case .allow_file_extensions;
                        extensions := split(line, cast(u8) #char " ");
                        for extensions {
                            if !it continue;
                            array_add(*allow_file_extensions, it);
                        }
                    case .ignore_file_extensions;
                        extensions := split(line, cast(u8) #char " ");
                        for extensions {
                            if !it continue;
                            array_add(*ignore_file_extensions, it);
                        }
                }                
                
            case .settings;
                // TODO
                
            case .keymap;
                // TODO
                
            case .colors;
                // TODO
                                
        }
    }
    
    // Cast away the extendable arrays into array views
    result.workspace.workspace_dirs = workspace_dirs;
    result.workspace.ignore_dirs = ignore_dirs;
    result.workspace.allow_file_extensions = allow_file_extensions;
    result.workspace.ignore_file_extensions = ignore_file_extensions;
    
    return result, true;
}


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

#scope_export

config: Config = DEFAULT_CONFIG;

Config :: struct {
    workspace: Workspace;
    keymap: Keymap;
    colors: Colors;
}

Workspace :: struct {
    workspace_dirs: [] string;
    ignore_dirs: [] string;
    allow_file_extensions:  [] string;
    ignore_file_extensions: [] string;
}

Keymap :: struct {
    // TODO
}

Color :: struct {
    #as vec4 : Vector4 = ---;

    #place vec4;
    using components : struct { r, g, b, a : float = 1; };

    #place vec4;
    floats : [4] float = ---;
}

Colors :: struct {
    NONE :: Color.{ r = -1, g = -1, b = -1, a = -1 };  // an invalid color to denote no color

    BACKGROUND              :: Color.{ r = 0.086, g = 0.133, b = 0.165 };
    BACKGROUND_DARK         :: Color.{ r = 0.065, g = 0.101, b = 0.125 };
    BACKGROUND_HIGHLIGHT    :: Color.{ r = 0.097, g = 0.15, b = 0.185 };
    BACKGROUND_LIGHT        :: Color.{ r = 0.102, g = 0.158, b = 0.195 };
    BACKGROUND_BRIGHT       :: Color.{ r = 0.131, g = 0.202, b = 0.25 };
    SELECTION_ACTIVE        :: Color.{ r = 0.11, g = 0.267, b = 0.29 };
    SELECTION_INACTIVE      :: Color.{ r = 0.11, g = 0.267, b = 0.29, a = 0.5 };
    SELECTION_HIGHLIGHT     :: Color.{ r = 0.99, g = 0.93, b = 0.99, a = 0.15 };
    SEARCH_RESULT_ACTIVE    :: Color.{ r = 0.559, g = 0.469, b = 0.184 };
    SEARCH_RESULT_INACTIVE  :: Color.{ r = 0.99, g = 0.93, b = 0.99, a = 0.15 };
    SCROLLBAR               :: Color.{ r = 0.20, g = 0.80, b = 0.80, a = 0.1 };
    SCROLLBAR_HOVER         :: Color.{ r = 0.20, g = 0.80, b = 0.80, a = 0.3 };
    SCROLLBAR_BACKGROUND    :: Color.{ r = 0.065, g = 0.101, b = 0.125, a = 0.3 };
    CURSOR                  :: Color.{ r = 0.15, g = 0.7, b = 0.7 };
    CURSOR_INACTIVE         :: Color.{ r = 0.10, g = 0.4, b = 0.4 };
    PASTE_ANIMATION         :: Color.{ r = 0.11, g = 0.267, b = 0.29 };
    SPLITTER                :: Color.{ r = 0.131, g = 0.202, b = 0.25 };
    SPLITTER_HOVER          :: Color.{ r = 0.110, g = 0.267, b = 0.29 };
    LETTER_HIGHLIGHT        :: Color.{ r = 0.35, g = 0.6, b = 0.6 };

    LIST_CURSOR_LITE        :: Color.{ r = 0.20, g = 0.80, b = 0.80, a = 0.1 };  // @TODO: do without alpha?
    LIST_CURSOR             :: Color.{ r = 0.20, g = 0.80, b = 0.80, a = 0.3 };

    SHADOW_DARK         :: Color.{ r = 0.057, g = 0.089, b = 0.11, a = 0.5 };
    SHADOW_TRANSPARENT  :: Color.{ r = 0.057, g = 0.089, b = 0.11, a = 0 };  // for interpolation

    UI_DEFAULT          :: Color.{ r = 0.75, g = 0.79, b = 0.86, a = 1.0 };
    UI_DIM              :: Color.{ r = 0.533, g = 0.569, b = 0.616, a = 1.0 };
    UI_WARNING          :: Color.{ r = 0.85, g = 0.68, b = 0.33, a = 1.0 };
    UI_ERROR            :: Color.{ r = 1.00, g = 0.00, b = 0.00, a = 1.0 };
    UI_TEXT_INPUT_LABEL :: Color.{ r = 0.233, g = 0.269, b = 0.316, a = 1.0 };

    CODE_DEFAULT        :: Color.{ r = 0.75, g = 0.79, b = 0.86, a = 1.0 };
    CODE_COMMENT        :: Color.{ r = 0.533, g = 0.569, b = 0.616, a = 1.0 };
    CODE_TYPE           :: Color.{ r = 0.51, g = 0.67, b = 0.64, a = 1.0 };
    CODE_FUNCTION       :: Color.{ r = 0.816, g = 0.776, b = 0.663, a = 1.0 };
    CODE_PUNCTUATION    :: Color.{ r = 0.75, g = 0.79, b = 0.86, a = 1.0 };
    CODE_OPERATION      :: Color.{ r = 0.88, g = 0.68, b = 0.51, a = 1.0 };
    CODE_STRING         :: Color.{ r = 0.835, g = 0.74, b = 0.494, a = 1.0 };
    CODE_VALUE          :: Color.{ r = 0.84, g = 0.60, b = 0.71, a = 1.0 };
    CODE_HIGHLIGHT      :: Color.{ r = 0.85, g = 0.61, b = 0.46, a = 1.0 };
    CODE_ERROR          :: Color.{ r = 1.00, g = 0.00, b = 0.00, a = 1.0 };
    CODE_KEYWORD        :: Color.{ r = 0.902, g = 0.493, b = 0.457, a = 1.0 };
};

CODE_COLOR_MAP :: #run -> [] Vector4 {
    using Simp.Code_Color;

    result: [NUM_COLORS] Vector4;

    result[DEFAULT]         = Colors.CODE_DEFAULT;
    result[COMMENT]         = Colors.CODE_COMMENT;
    result[TYPE]            = Colors.CODE_TYPE;
    result[FUNCTION]        = Colors.CODE_FUNCTION;
    result[PUNCTUATION]     = Colors.CODE_PUNCTUATION;
    result[STRING]          = Colors.CODE_STRING;
    result[VALUE]           = Colors.CODE_VALUE;
    result[VALUE_KEYWORD]   = Colors.CODE_VALUE;
    result[ERROR]           = Colors.CODE_ERROR;
    result[KEYWORD]         = Colors.CODE_KEYWORD;
    result[OPERATION]       = Colors.CODE_OPERATION;

    return result;
}

as_3_floats :: (color: Color) -> [3] float {
    result : [3] float = ---;
    result[0] = color.r;
    result[1] = color.g;
    result[2] = color.b;
    return result;
}

is_none :: (using color: Color) -> bool {
    return r < 0 || g < 0 || b < 0 || a < 0;
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
}

DEFAULT_CONFIG_NAME :: "default.focus-config";  // in the focus project folder

DEFAULT_CONFIG_FILE_DATA :: #run read_entire_file(DEFAULT_CONFIG_NAME);

DEFAULT_CONFIG :: #run -> Config {
    config, success := parse_config("Default Config", DEFAULT_CONFIG_NAME, DEFAULT_CONFIG_FILE_DATA);
    assert(success, "Couldn't parse the default config file '%'", DEFAULT_CONFIG_NAME);
    return config;
};


#import "Text_File_Handler";