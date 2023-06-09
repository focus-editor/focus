load_global_config :: (create_if_doesnt_exist := false) -> success: bool, changed: bool, there_were_warnings: bool {
    global_config_path = sprint("%/global.focus-config", config_dir);

    if create_if_doesnt_exist && !file_exists(global_config_path) {
        // Create one with default contents
        success := write_entire_file(global_config_path, DEFAULT_CONFIG_FILE_DATA);
        if !success panic_messagebox("Couldn't create a new config file '%'.\nIs the directory writable?", global_config_path);
    }

    success, changed, there_were_warnings := load_and_merge_config(global_config_path, hash = *global_config_hash);

    return success, changed, there_were_warnings;
}

load_project_config :: (project: string = "") -> success: bool, changed: bool, there_were_warnings: bool {
    if !project && !current_project_name {
        log_error("Attempted to load an empty project config. This is a bug.");
        return false, false, false;
    }
    project_name := ifx project then project else current_project_name;
    config_path  := sprint("%/%.focus-config", projects_dir, project_name);

    success, changed, there_were_warnings := load_and_merge_config(config_path, into = config, hash = *project_config_hash);
    if success {
        current_project_name = project_name;
        project_config_path  = config_path;
    }

    return success, changed, there_were_warnings;
}

maybe_refresh_config :: (path: string) {
    if !is_our_config_file(path) return;

    old_workspace_dirs := array_copy_tmp(config.workspace.workspace_dirs);

    if path == global_config_path {
        success, changed, there_were_warnings := load_global_config();
        if success && changed && !there_were_warnings {
            clear_user_messages();
            add_success_message("Global config changes have been applied", dismiss_in_seconds = 3);
        }
        if current_project_name {
            success, changed, there_were_warnings = load_project_config(current_project_name);
            if success && changed && !there_were_warnings {
                add_success_message(tprint("Config changes for project '%' have been applied", current_project_name), dismiss_in_seconds = 3);
            }
        }
    } else if path == project_config_path {
        success, changed, there_were_warnings := load_project_config();
        if success && changed && !there_were_warnings {
            clear_user_messages();
            add_success_message(tprint("Config changes for project '%' have been applied", current_project_name), dismiss_in_seconds = 3);
        }
    }

    // Detect changes in workspace dirs
    dirs_added: [..] string;
    dirs_added.allocator = temp;
    dirs_removed: [..] string;
    dirs_removed.allocator = temp;

    for new_dir : config.workspace.workspace_dirs {
        exists := array_find(old_workspace_dirs, new_dir);
        if !exists array_add(*dirs_added, new_dir);
    }
    for old_dir : old_workspace_dirs {
        exists := array_find(config.workspace.workspace_dirs, old_dir);
        if !exists array_add(*dirs_removed, old_dir);
    }

    if dirs_added || dirs_removed {
        should_reload_workspace = true;
        if unsaved_buffers_exist() {
            show_unsaved_buffers_dialog(.reload_workspace);
            clear_user_messages();
            add_user_warning("Workspace directories have changed in the config.\nWorkspace will need to reload, however there are unsaved changes.");
            should_reload_workspace = false;
        }
    }

    dont_ignore_next_window_resize = true;
    platform_apply_config(*config.platform);

    if current_editor_history_size < config.settings.editor_history_size && editor_history.head < editor_history.tail {
         editor_history.head    = 0;
         editor_history.tail    = 0;
         editor_history.current = 0;
         current_editor_history_size = config.settings.editor_history_size;
    }
}

is_our_config_file :: (path: string) -> bool {
    return path != "" && (path == global_config_path || path == project_config_path);
}

find_font_by_name :: (name: string) -> path: string, error_msg: string /* temp */ {
    if name == "default" return "default", "";

    has_extension := ends_with_nocase(name, ".ttf") || ends_with_nocase(name, ".otf");

    try_path :: (font_path: string) #expand {
        if file_exists(font_path) `return font_path, "";
        array_add(*tried_paths, font_path);
    }

    tried_paths: [..] string;
    tried_paths.allocator = temp;

    try_path(name);

    try_path(tprint("%/%", data_dir, name));
    if !has_extension {
        try_path(tprint("%/%.ttf", data_dir, name));
        try_path(tprint("%/%.otf", data_dir, name));
    }

    // Try to look it up in system fonts
    fonts_dir := platform_get_fonts_dir();

    try_path(tprint("%/%", fonts_dir, name));
    if !has_extension {
        try_path(tprint("%/%.ttf", fonts_dir, name));
        try_path(tprint("%/%.otf", fonts_dir, name));
    }

    if ! #compile_time {
        found, path := platform_find_font_by_name(name);
        if found then return path, "";
    }

    error_msg := tprint("Couldn't find font '%'.\n\nTried the following locations:\n - %\n\nPlease note that you can specify a full path to the desired font file.", name, join(..tried_paths, "\n - ", allocator = temp));
    return "", error_msg;
}

#scope_file

load_and_merge_config :: (file_path: string, into: Config = DEFAULT_CONFIG, hash: *u64) -> success: bool, changed: bool, there_were_warnings: bool {
    new_config, success, changed, error_msg, warnings := load_config(file_path, hash);
    if !success {
        if !error_msg assert(false, "No error message on a config error. This is a bug.");
        log_error(error_msg);
        add_user_error(error_msg);
        return false, false, false;
    }
    if warnings {
        add_user_warning(tprint("Config file % loaded with warnings", file_path), dismiss_in_seconds = 60);
        for warnings add_user_error(it, dismiss_in_seconds = 60);
    }

    config = into;
    merge_configs(*config, new_config);

    TAB_SIZE = clamp(cast(s32) config.settings.tab_size, 1, 100);  // be reasonable, even though 100 is unreasonable

    if !file_is_watched(file_path) start_watching_file(file_path);

    return true, changed, warnings.count > 0;
}

// NOTE: I don't like how the config is currently loaded, passing stuff from function to function,
//       this code should probably be simplified at some point
load_config :: (file_path: string, hash: *u64) -> Config, success: bool, changed: bool, error_msg: string /* tmp */, warnings: [] string /* temp */ {
    empty: Config;

    file_data, success_read := read_entire_file(file_path);
    // NOTE: we're not freeing because the config will take ownership of it
    // (and if you reload it'll leak the old data, which we should fix at some point!)
    if !success_read return empty, false, false, tprint("Couldn't read the config file file '%'", file_path), .[];

    config, success_parse, error_msg, warnings := parse_config(file_path, file_path, file_data);
    if !success_parse return empty, false, false, tprint("Error when loading config file '%'.\n%", file_path, error_msg), .[];

    new_hash := calculate_meow_hash(file_data);
    changed := new_hash != <<hash;
    if changed then <<hash = new_hash;

    return config, true, changed, "", warnings;
}

merge_configs :: (dst: *Config, src: Config) {
    // Workspace
    if src.workspace.workspace_dirs then dst.workspace.workspace_dirs = src.workspace.workspace_dirs;
    if src.workspace.ignore_dirs    then dst.workspace.ignore_dirs    = src.workspace.ignore_dirs;

    if src.workspace.allow_file_extensions || src.workspace.allow_file_extension_wildcards {
        dst.workspace.allow_file_extensions          = src.workspace.allow_file_extensions;
        dst.workspace.allow_file_extension_wildcards = src.workspace.allow_file_extension_wildcards;
    }
    if src.workspace.ignore_file_extensions || src.workspace.ignore_file_extension_wildcards {
        dst.workspace.ignore_file_extensions          = src.workspace.ignore_file_extensions;
        dst.workspace.ignore_file_extension_wildcards = src.workspace.ignore_file_extension_wildcards;
    }

    // Keymap
    merge_keymaps :: (dst_keymap: *[] Key_Mapping, src_keymap: [] Key_Mapping) #expand {
        if !src_keymap return;
        result := resizable(src_keymap);  // the source goes first, because it needs to have priority
        array_extend(*result, <<dst_keymap);
        <<dst_keymap = result;
    }
    merge_keymaps(*dst.keymap.common,           src.keymap.common);
    merge_keymaps(*dst.keymap.editors,          src.keymap.editors);
    merge_keymaps(*dst.keymap.open_file_dialog, src.keymap.open_file_dialog);
    merge_keymaps(*dst.keymap.search_dialog,    src.keymap.search_dialog);

    // Settings
    #insert -> string {
        b: String_Builder;

        for setting : SETTINGS {
            code := #string END
                if src.settings.%1 != DEFAULT_CONFIG.settings.%1 {
                    dst.settings.%1 = src.settings.%1;
                }
            END
            print_to_builder(*b, code, setting.name);
        }

        return builder_to_string(*b);
    }

    // Fonts
    if src.style.font {
        dst.style.font = ifx src.style.font then src.style.font else "default";

        loaded_data, success := load_font_by_name(src.style.font);
        if success {
            main_font_data = loaded_data;
            main_font_name = src.style.font;
        } else {
            // NOTE: this error will be removed by the config success message. Should do something about it
            add_user_error(tprint("Couldn't load font %", src.style.font));
        }
    }
    if src.style.font_size > 0 {
        dst.style.font_size = src.style.font_size;
        font_size = src.style.font_size;
        default_font_size = font_size;
    }

    init_fonts_and_dependent_things();

    // Colors
    for src.style.parsed_colors {
        color_ptr, success := map_color_name_to_color_struct(it.color_name);
        if success {
            <<color_ptr = it.color;
        } else {
            log_error("Couldn't map color name '%' to color pointer. This is a bug", it.color_name);
        }
    }
    CODE_COLOR_MAP = refresh_code_color_map();

    // Platform config
    platform_copy_config(*src.platform, *dst.platform);
}

load_font_by_name :: (name: string) -> font_data: string, success: bool {
    if name == "default" return FONT.data, true;

    font_path := find_font_by_name(name);
    if font_path {
        font_data, success := read_entire_file(font_path);
        return font_data, success;
    }

    return "", false;
}

#scope_export

global_config_path:  string;
global_config_hash:  u64;
project_config_path: string;
project_config_hash: u64;
current_project_name: string;

config: Config = DEFAULT_CONFIG;

Config :: struct {
    workspace: Workspace;
    keymap: Keymap;
    settings: Settings;
    style: Style;
    platform: platform_config;
}

Workspace :: struct {
    workspace_dirs:                  [] string;
    ignore_dirs:                     [] string;
    allow_file_extensions:           [] string;
    ignore_file_extensions:          [] string;
    allow_file_extension_wildcards:  [] string;
    ignore_file_extension_wildcards: [] string;
}

Settings :: struct {
    // NOTE: for various reasons this must match the settings in default.focus-config.
    // Otherwise there will be confusion
    maximize_on_start                   := true;
    open_on_the_biggest_monitor         := true;
    cursor_as_block                     := true;
    highlight_selection_occurrences     := true;
    disable_that_annoying_paste_effect  := false;
    disable_file_open_close_animations  := false;
    double_shift_to_search_in_workspace := false;
    max_entries_in_open_file_dialog     := 2000;
    tab_size                            := 4;
    insert_spaces_when_pressing_tab     := true;
    strip_trailing_whitespace_on_save   := false;
    smooth_scrolling                    := true;
    line_height_scale_percent           := 120;
    max_editor_width                    := -1;
    can_cancel_go_to_line               := true;
    editor_history_size                 := 128;

    // TODO
    // convert_tabs_to_spaces_on_load:     false
    // load_last_session_on_start:         true
}

Keymap :: struct {
    common:           [] Key_Mapping;
    editors:          [] Key_Mapping;
    open_file_dialog: [] Key_Mapping;
    search_dialog:    [] Key_Mapping;
}

Color :: struct {
    #as vec4 : Vector4 = ---;

    #place vec4;
    using components : struct { r, g, b, a : float = 1; };

    #place vec4;
    floats : [4] float = ---;
}

Style :: struct {
    font      := "";
    font_size := -1;

    parsed_colors: [] Parsed_Color;
}

style: Style;

Color_Values :: struct {
    NONE :: Color.{ r = -1, g = -1, b = -1, a = -1 };  // an invalid color to denote no color

    BACKGROUND              := Color.{ r = 0.086, g = 0.133, b = 0.165 };
    BACKGROUND_DARK         := Color.{ r = 0.065, g = 0.101, b = 0.125 };
    BACKGROUND_HIGHLIGHT    := Color.{ r = 0.097, g = 0.15, b = 0.185 };
    BACKGROUND_LIGHT        := Color.{ r = 0.102, g = 0.158, b = 0.195 };
    BACKGROUND_BRIGHT       := Color.{ r = 0.131, g = 0.202, b = 0.25 };
    SELECTION_ACTIVE        := Color.{ r = 0.11, g = 0.267, b = 0.29 };
    SELECTION_INACTIVE      := Color.{ r = 0.11, g = 0.267, b = 0.29, a = 0.5 };
    SELECTION_HIGHLIGHT     := Color.{ r = 0.99, g = 0.93, b = 0.99, a = 0.15 };
    SEARCH_RESULT_ACTIVE    := Color.{ r = 0.559, g = 0.469, b = 0.184 };
    SEARCH_RESULT_INACTIVE  := Color.{ r = 0.99, g = 0.93, b = 0.99, a = 0.15 };
    SCROLLBAR               := Color.{ r = 0.20, g = 0.80, b = 0.80, a = 0.1 };
    SCROLLBAR_HOVER         := Color.{ r = 0.20, g = 0.80, b = 0.80, a = 0.3 };
    SCROLLBAR_BACKGROUND    := Color.{ r = 0.065, g = 0.101, b = 0.125, a = 0.3 };
    CURSOR                  := Color.{ r = 0.15, g = 0.7, b = 0.7 };
    CURSOR_INACTIVE         := Color.{ r = 0.10, g = 0.4, b = 0.4 };
    PASTE_ANIMATION         := Color.{ r = 0.11, g = 0.267, b = 0.29 };
    SPLITTER                := Color.{ r = 0.131, g = 0.202, b = 0.25 };
    SPLITTER_HOVER          := Color.{ r = 0.110, g = 0.267, b = 0.29 };
    LETTER_HIGHLIGHT        := Color.{ r = 0.35, g = 0.6, b = 0.6 };
    LIST_CURSOR_LITE        := Color.{ r = 0.20, g = 0.80, b = 0.80, a = 0.1 };  // @TODO: do without alpha?
    LIST_CURSOR             := Color.{ r = 0.20, g = 0.80, b = 0.80, a = 0.3 };
    SHADOW_DARK             := Color.{ r = 0.057, g = 0.089, b = 0.11, a = 0.5 };
    SHADOW_TRANSPARENT      := Color.{ r = 0.057, g = 0.089, b = 0.11, a = 0 };  // for interpolation
    TEXT_INPUT_LABEL     := Color.{ r = 0.233, g = 0.269, b = 0.316, a = 1.0 };

    UI_DEFAULT              := Color.{ r = 0.75, g = 0.79, b = 0.86, a = 1.0 };
    UI_DIM                  := Color.{ r = 0.533, g = 0.569, b = 0.616, a = 1.0 };
    UI_NEUTRAL              := Color.{ r = 0.3, g = 0.3, b = 0.3, a = 1.0 };
    UI_WARNING              := Color.{ r = 0.85, g = 0.68, b = 0.33, a = 1.0 };
    UI_WARNING_DIM          := Color.{ r = 0.59, g = 0.37, b = 0.19, a = 1.0 };
    UI_ERROR                := Color.{ r = 0.46, g = 0.13, b = 0.13, a = 1.0 };
    UI_ERROR_BRIGHT         := Color.{ r = 1.00, g = 0.00, b = 0.00, a = 1.0 };
    UI_SUCCESS              := Color.{ r = 0.00, g = 0.80, b = 0.00, a = 1.0 };

    CODE_DEFAULT            := Color.{ r = 0.75, g = 0.79, b = 0.86, a = 1.0 };
    CODE_COMMENT            := Color.{ r = 0.533, g = 0.569, b = 0.616, a = 1.0 };
    CODE_TYPE               := Color.{ r = 0.51, g = 0.67, b = 0.64, a = 1.0 };
    CODE_FUNCTION           := Color.{ r = 0.816, g = 0.776, b = 0.663, a = 1.0 };
    CODE_PUNCTUATION        := Color.{ r = 0.75, g = 0.79, b = 0.86, a = 1.0 };
    CODE_OPERATION          := Color.{ r = 0.88, g = 0.68, b = 0.51, a = 1.0 };
    CODE_STRING             := Color.{ r = 0.835, g = 0.74, b = 0.494, a = 1.0 };
    CODE_VALUE              := Color.{ r = 0.84, g = 0.60, b = 0.71, a = 1.0 };
    CODE_HIGHLIGHT          := Color.{ r = 0.85, g = 0.61, b = 0.46, a = 1.0 };
    CODE_ERROR              := Color.{ r = 1.00, g = 0.00, b = 0.00, a = 1.0 };
    CODE_KEYWORD            := Color.{ r = 0.902, g = 0.493, b = 0.457, a = 1.0 };
};

Colors: Color_Values;  // a hack to avoid replacing a lot of code

Code_Color :: enum u8 {
    DEFAULT;
    COMMENT;
    TYPE;
    KEYWORD;
    VALUE_KEYWORD;
    VALUE;
    FUNCTION;
    PUNCTUATION;
    STRING;
    ERROR;
    OPERATION;

    NUM_COLORS;
}

CODE_COLOR_MAP: [Code_Color.NUM_COLORS] Vector4;

refresh_code_color_map :: () -> [Code_Color.NUM_COLORS] Vector4 {
    using Code_Color;

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

Setting :: struct {
    name: string;
    type: enum { boolean; integer; };
}

SETTINGS :: Setting.[
    .{ "maximize_on_start",                   .boolean },
    .{ "open_on_the_biggest_monitor",         .boolean },
    .{ "cursor_as_block",                     .boolean },
    .{ "highlight_selection_occurrences",     .boolean },
    .{ "disable_that_annoying_paste_effect",  .boolean },
    .{ "disable_file_open_close_animations",  .boolean },
    .{ "double_shift_to_search_in_workspace", .boolean },
    .{ "insert_spaces_when_pressing_tab",     .boolean },
    .{ "strip_trailing_whitespace_on_save",   .boolean },
    .{ "smooth_scrolling",                    .boolean },
    .{ "can_cancel_go_to_line",               .boolean },

    .{ "max_entries_in_open_file_dialog",     .integer },
    .{ "tab_size",                            .integer },
    .{ "line_height_scale_percent",           .integer },
    .{ "max_editor_width",                    .integer },
    .{ "editor_history_size",                 .integer },
];

DEFAULT_CONFIG_FILE_DATA  :: #run read_entire_file(DEFAULT_CONFIG_NAME);
EXAMPLE_PROJECT_FILE_DATA :: #run read_entire_file(EXAMPLE_PROJECT_CONFIG_NAME);

#scope_file

#if OS == .MACOS {
    DEFAULT_CONFIG_NAME         :: "default_macos.focus-config";
} else {
    DEFAULT_CONFIG_NAME         :: "default.focus-config";
}
EXAMPLE_PROJECT_CONFIG_NAME :: "example-project.focus-config";


DEFAULT_CONFIG :: #run -> Config {
    config, success := parse_config("Default Config", DEFAULT_CONFIG_NAME, DEFAULT_CONFIG_FILE_DATA);
    assert(success, "Couldn't parse the default config file '%'", DEFAULT_CONFIG_NAME);
    return config;
};

// Validate the example project config
#run {
    _, success := parse_config("Example Project Config", EXAMPLE_PROJECT_CONFIG_NAME, EXAMPLE_PROJECT_FILE_DATA);
    assert(success, "Couldn't parse the example project config file '%'", EXAMPLE_PROJECT_CONFIG_NAME);
}

#load "config_parser.jai";
