load_global_config :: (fallback_to_default_on_failure := false) -> success: bool, changed: bool, there_were_warnings: bool {
    global_config_path = sprint("%/global.focus-config", config_dir);

    if !file_exists(global_config_path) {
        // Create one with default contents
        success := write_entire_file(global_config_path, DEFAULT_CONFIG_FILE_DATA);
        if !success panic_messagebox("Couldn't create a new config file '%'.\nIs the directory writable?", global_config_path);
    }

    success, changed, there_were_warnings := load_and_merge_config(global_config_path, into = Config.{}, hash = *global_config_hash);
    if !success && fallback_to_default_on_failure {
        config = DEFAULT_CONFIG;
        saved_global_config = config;
    }
    if success then saved_global_config = config;

    return success, changed, there_were_warnings;
}

load_project_config :: (project: string = "") -> success: bool, changed: bool, there_were_warnings: bool {
    if !project && !current_project_name {
        log_error("Attempted to load an empty project config. This is a bug.");
        return false, false, false;
    }
    project_name := ifx project then project else current_project_name;
    config_path  := sprint("%/%.focus-config", projects_dir, project_name);

    success, changed, there_were_warnings := load_and_merge_config(config_path, into = saved_global_config, hash = *project_config_hash);
    if success {
        current_project_name = project_name;
        project_config_path  = config_path;
    }

    return success, changed, there_were_warnings;
}

refresh_config :: (path: string) {
    old_workspace_dirs := array_copy_tmp(config.workspace.workspace_dirs);

    if platform_path_equals(path, global_config_path) {
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
    } else if platform_path_equals(path, project_config_path) {
        success, changed, there_were_warnings := load_project_config();
        if success && changed && !there_were_warnings {
            clear_user_messages();
            add_success_message(tprint("Config changes for project '%' have been applied", current_project_name), dismiss_in_seconds = 3);
        }
    } else {
        log_error("Attempted to refresh config from file %, but it is not a global config or a current project config", path);
        return;
    }

    // Detect changes in workspace dirs
    dirs_added   := false;
    dirs_removed := false;

    for new_dir : config.workspace.workspace_dirs {
        exists := array_find(old_workspace_dirs, new_dir);
        if !exists { dirs_added = true; break; }
    }
    for old_dir : old_workspace_dirs {
        exists := array_find(config.workspace.workspace_dirs, old_dir);
        if !exists { dirs_removed = true; break; }
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
}

is_our_config_file :: (path: string) -> bool {
    return path != "" && (platform_path_equals(path, global_config_path) || platform_path_equals(path, project_config_path));
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

load_and_merge_config :: (file_path: string, into: Config, hash: *u64) -> success: bool, changed: bool, there_were_warnings: bool {

    file_data, success_read := read_entire_file(file_path);
    // NOTE: we're not freeing because the config will take ownership of it (and if you reload it'll leak the old data, which we should probably fix at some point)
    if !success_read {
        error_msg := tprint("Couldn't read the config file file '%'", file_path);
        log_error(error_msg);
        add_user_error(error_msg);
        return false, false, false;
    }

    parsed_config, success_parse, error_msg, warnings := parse_config(file_path, file_path, file_data);
    if !success_parse {
        if !error_msg assert(false, "No error message on a config error. This is a bug.");
        log_error(error_msg);
        add_user_error(error_msg);
        return false, false, false;
    }
    if warnings {
        add_user_warning(tprint("Config file % loaded with warnings", file_path), dismiss_in_seconds = 60);
        for warnings add_user_error(it, dismiss_in_seconds = 60);
    }

    // Maybe update hash if changed
    new_hash := calculate_meow_hash(file_data);
    changed := new_hash != <<hash;
    if changed then <<hash = new_hash;

    // Merge configs
    config = into;
    merge_configs(*config, parsed_config);

    // Apply colors
    Colors = config.colors;
    CODE_COLOR_MAP = refresh_code_color_map();

    // Make sure the values are within the acceptable range
    clamp_warnings := false;

    old_tab_size := TAB_SIZE;
    TAB_SIZE = clamp(cast(s32) config.settings.tab_size, 1, 100);  // be reasonable (though 100 is unreasonable)
    if config.settings.tab_size != TAB_SIZE {
        add_user_warning(tprint("Tab size clamped to %", TAB_SIZE));
        clamp_warnings = true;
    }
    if old_tab_size != TAB_SIZE {
        // Refresh all editors which have line wrap on
        for * editor : open_editors {
            buffer := *open_buffers[editor.buffer_id];
            if line_wrap_is_active(editor) then rescan_for_wrapped_lines(editor, buffer);
        }
    }

    line_height_scale := config.settings.line_height_scale_percent;
    config.settings.line_height_scale_percent = clamp(line_height_scale, 50, 1000);
    if config.settings.line_height_scale_percent != line_height_scale {
        add_user_warning(tprint("Line height scale clamped to %", config.settings.line_height_scale_percent));
        clamp_warnings = true;
    }

    editor_history_size := config.settings.editor_history_size;
    config.settings.editor_history_size = clamp(editor_history_size, 4, 1024 * 1024);
    if config.settings.editor_history_size != editor_history_size {
        add_user_warning(tprint("Editor history size clamped to %", config.settings.editor_history_size));
        clamp_warnings = true;
    }

    // Must do after the validation
    init_fonts_and_dependent_things();

    if !file_is_watched(file_path) start_watching_file(file_path);

    return true, changed, warnings.count > 0 || clamp_warnings;
}

merge_configs :: (dst: *Config, parsed: Parsed_Config) {
    // Completely replace the workspace subsections if present
    if parsed.workspace_dirs then dst.workspace.workspace_dirs = parsed.workspace_dirs;
    if parsed.ignore_dirs    then dst.workspace.ignore_dirs    = parsed.ignore_dirs;

    if parsed.allow_file_extensions || parsed.allow_file_extension_wildcards {
        dst.workspace.allow_file_extensions          = parsed.allow_file_extensions;
        dst.workspace.allow_file_extension_wildcards = parsed.allow_file_extension_wildcards;
    }
    if parsed.ignore_file_extensions || parsed.ignore_file_extension_wildcards {
        dst.workspace.ignore_file_extensions          = parsed.ignore_file_extensions;
        dst.workspace.ignore_file_extension_wildcards = parsed.ignore_file_extension_wildcards;
    }

    // Keymap
    merge_keymaps :: (dst_keymap: *[] Key_Mapping, src_keymap: *[..] Key_Mapping) #expand {
        if !src_keymap return;
        array_extend(src_keymap, <<dst_keymap);
        <<dst_keymap = <<src_keymap;
    }
    merge_keymaps(*dst.keymap.common,           *parsed.keymap_common);
    merge_keymaps(*dst.keymap.editors,          *parsed.keymap_editors);
    merge_keymaps(*dst.keymap.open_file_dialog, *parsed.keymap_open_file_dialog);
    merge_keymaps(*dst.keymap.search_dialog,    *parsed.keymap_search_dialog);

    // Settings
    #insert -> string {
        b: String_Builder;
        for setting : type_info(Settings).members {
            print_to_builder(*b, "if array_find(parsed.set_settings, \"%1\") { dst.settings.%1 = parsed.settings.%1; }\n", setting.name);
        }
        return builder_to_string(*b);
    }

    // Fonts
    if parsed.font {
        dst.style.font = parsed.font;

        loaded_data, success := load_font_by_name(parsed.font);
        if success {
            main_font_data = loaded_data;
            main_font_name = parsed.font;
        } else {
            // NOTE: this error will be removed by the config success message. Should do something about it
            add_user_error(tprint("Couldn't load font %", parsed.font));
        }
    }
    if parsed.font_size > 0 {
        dst.style.font_size = parsed.font_size;
        font_size = parsed.font_size;
        default_font_size = font_size;
    }

    // Colors
    for parsed.colors {
        color_ptr := map_color_name_to_color_struct(dst, it.color_name);
        if color_ptr {
            <<color_ptr = it.color;
        } else {
            log_error("Couldn't map color name '%' to color pointer. This is a bug", it.color_name);
        }
    }

    // Platform config
    platform_copy_config(*parsed.platform, *dst.platform);
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

config: Config;

// Used to remember the global settings to then apply the project config on top
// when it's reloaded to avoid losing the original global settings
saved_global_config: Config;

Config :: struct {
    workspace: Workspace;
    keymap:    Keymap;
    settings:  Settings;
    style:     Style;
    colors:    Color_Values;
    platform:  Platform_Config;
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
    maximize_on_start                   := false;
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
    copy_whole_line_without_selection   := false;
    editor_history_size                 := 128;
    line_wrap_is_on_by_default          := false;
    show_line_numbers                   := false;
    save_on_edit                        := false;

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

Style :: struct {
    font      := "";
    font_size := -1;
}

style: Style;

Setting :: struct {
    name: string;
    type: enum { boolean; integer; };
}

DEFAULT_CONFIG_FILE_DATA  :: #run read_entire_file(DEFAULT_CONFIG_NAME);
EXAMPLE_PROJECT_FILE_DATA :: #run read_entire_file(EXAMPLE_PROJECT_CONFIG_NAME);

#scope_file

#if OS == .MACOS {
    DEFAULT_CONFIG_NAME :: "default_macos.focus-config";
} else {
    DEFAULT_CONFIG_NAME :: "default.focus-config";
}
EXAMPLE_PROJECT_CONFIG_NAME :: "example-project.focus-config";


#scope_export

DEFAULT_CONFIG :: #run -> Config {
    parsed_config, success := parse_config("Default Config", DEFAULT_CONFIG_NAME, DEFAULT_CONFIG_FILE_DATA);
    assert(success, "Couldn't parse the default config file '%'", DEFAULT_CONFIG_NAME);
    default_config: Config;
    merge_configs(*default_config, parsed_config);
    return default_config;
};

// Validate the example project config
#run {
    _, success := parse_config("Example Project Config", EXAMPLE_PROJECT_CONFIG_NAME, EXAMPLE_PROJECT_FILE_DATA);
    assert(success, "Couldn't parse the example project config file '%'", EXAMPLE_PROJECT_CONFIG_NAME);
}

#load "config_parser.jai";
