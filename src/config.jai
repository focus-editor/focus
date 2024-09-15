CURRENT_CONFIG_VERSION :: 6;

load_global_config :: (fallback_to_default_on_failure := false, force := false) -> success: bool, changed: bool, there_were_warnings: bool {
    config_path := tprint("%/global.focus-config", config_dir);
    start_watching_file_if_not_already(config_path);

    if !file_exists(config_path) {
        // Create one with default contents
        success := write_entire_file(config_path, DEFAULT_CONFIG_FILE_DATA);
        if !success panic_messagebox("Couldn't create a new config file '%'.\nIs the directory writable?", config_path);
    }

    loaded_config, changed := load_config(config_path, *global_config, force = force);
    if !changed && !force return true, false, false;

    if loaded_config.loaded {
        // Merge into an empty config
        config = Config.{};
        reset_color_map_to_default();
        merge_configs(*config, loaded_config.parsed_config);
        apply_config();
        free_loaded_config(*global_config);
        global_config = loaded_config;
        return true, true, loaded_config.there_were_warnings;
    } else {
        if fallback_to_default_on_failure {
            config = DEFAULT_CONFIG;
            apply_config();
        }
        global_config.hash = loaded_config.hash;
        free_loaded_config(*loaded_config);
        return false, false, false;
    }
}

load_project_config :: (file_path: string, force := false) -> success: bool, changed: bool, there_were_warnings: bool {
    assert(file_path != "", "Attempting to load project config from an empty path. This is a bug.");

    config_path := copy_string(file_path,, temp);
    path_overwrite_separators(config_path, #char "/");

    start_watching_file_if_not_already(config_path);

    loaded_config, changed := load_config(config_path, *project_config, force);
    if !changed && !force return true, false, false;

    if loaded_config.loaded {
        // Merge into an empty config, starting from a loaded global config
        if global_config.loaded {
            config = Config.{};
            reset_color_map_to_default();
            merge_configs(*config, global_config.parsed_config);
        } else {
            config = DEFAULT_CONFIG;
        }
        // Now mix in the project config
        merge_configs(*config, loaded_config.parsed_config);
        apply_config();

        changed := loaded_config.hash != project_config.hash;
        free_loaded_config(*project_config);
        project_config = loaded_config;

        add_to_most_recent_projects(file_path);

        return true, changed, loaded_config.there_were_warnings;
    } else {
        project_config.hash = loaded_config.hash;
        free_loaded_config(*loaded_config);
        return false, false, false;
    }
}

refresh_config :: (path: string) {
    // Deep copy old workspace members and allow/ignore lists (they will be freed by the load config function otherwise)
    old_workspace_members: [..] string;
    old_workspace_members.allocator = temp;
    for config.workspace.members array_add(*old_workspace_members, copy_temporary_string(it));

    old_allow_list: [..] string;
    old_allow_list.allocator = temp;
    for config.workspace.allow array_add(*old_allow_list, copy_temporary_string(it));

    old_ignore_list: [..] string;
    old_ignore_list.allocator = temp;
    for config.workspace.ignore array_add(*old_ignore_list, copy_temporary_string(it));

    // Remember old file associations
    old_file_associations: [..] File_Association;
    old_file_associations.allocator = temp;
    for config.workspace.file_associations array_add(*old_file_associations, .{ copy_temporary_string(it.wildcard), it.lang });

    if platform_path_equals(path, global_config.path) {
        success, changed, there_were_warnings := load_global_config();
        if success && changed && !there_were_warnings {
            clear_user_messages(.config);
            add_success_message("Global config changes have been applied", dismiss_in_seconds = 3, tag = .config);
        }
        if project_config.loaded {
            success, changed, there_were_warnings = load_project_config(project_config.path, force = true);
            if success && changed && !there_were_warnings {
                add_success_message("Config changes for project '%' have been applied", get_current_project_name(), dismiss_in_seconds = 3, tag = .config);
            }
        }
    } else if platform_path_equals(path, project_config.path) {
        success, changed, there_were_warnings := load_project_config(project_config.path);
        if success && changed && !there_were_warnings {
            clear_user_messages(.config);
            add_success_message("Config changes for project '%' have been applied", get_current_project_name(), dismiss_in_seconds = 3, tag = .config);
        }
    } else {
        log_error("Attempted to refresh config from file %, but it is not a global config or a current project config", path);
        return;
    }

    // Detect changes in workspace members or allow_ignore_lists
    members_changed := false;
    if config.workspace.members.count != old_workspace_members.count {
        members_changed = true;
    } else {
        // Even if the workspace members are reordered we still want to refresh workspace
        for i : 0 .. config.workspace.members.count-1 {
            if config.workspace.members[i] != old_workspace_members[i] {
                members_changed = true;
                break;
            }
        }
    }

    allow_ignore_changed := false;
    for config.workspace.allow {
        exists := array_find(old_allow_list, it);
        if !exists { allow_ignore_changed = true; break; }
    }
    for old_allow_list {
        exists := array_find(config.workspace.allow, it);
        if !exists { allow_ignore_changed = true; break; }
    }

    for config.workspace.ignore {
        exists := array_find(old_ignore_list, it);
        if !exists { allow_ignore_changed = true; break; }
    }
    for old_ignore_list {
        exists := array_find(config.workspace.ignore, it);
        if !exists { allow_ignore_changed = true; break; }
    }

    if members_changed || allow_ignore_changed {
        if unsaved_buffers_exist() {
            clear_user_messages();
            if members_changed      then add_user_warning("Workspace members have changed in the config.\nWorkspace will need to reload, however there are unsaved changes.", tag = .workspace);
            if allow_ignore_changed then add_user_warning("Workspace ignore rules have changed in the config.\nWorkspace will need to reload, however there are unsaved changes.", tag = .workspace);
        }
        defer_action_reload_workspace(automatic = true);
    }

    // Detect changes in file associations
    file_associations_changed := config.workspace.file_associations.count != old_file_associations.count;
    if !file_associations_changed {
        for 0 .. old_file_associations.count - 1 {
            if config.workspace.file_associations[it] != old_file_associations[it] {
                file_associations_changed = true;
                break;
            }
        }
    }
    if file_associations_changed {
        // Reassign languages for all buffers in the workspace
        for * buffer : open_buffers {
            if !buffer.has_file continue;
            lang := get_lang_from_path(buffer.file.full_path);
            if lang != buffer.lang {
                buffer.lang = lang;
                retokenize(buffer);
            }
        }
        add_success_message("File associations have been refreshed", dismiss_in_seconds = 3);
    }

    commands_refresh_after_config_change();

    dont_ignore_next_window_resize = true;
}

refresh_current_theme :: () {
    if global_config.loaded  then load_global_config(force = true);
    if project_config.loaded then load_project_config(project_config.path, force = true);
}

is_our_config_file :: (path: string) -> bool {
    return path != "" && (is_current_global_config(path) || is_current_project_config(path));
}

is_current_global_config :: inline (path: string) -> bool {
    return platform_path_equals(path, global_config.path);
}

is_current_project_config :: inline (path: string) -> bool {
    return project_config.loaded && platform_path_equals(path, project_config.path);
}

is_current_theme :: (path: string) -> bool {
    return config.style.theme && platform_path_equals(path, tprint("%/%.focus-theme", themes_dir, config.style.theme));
}

close_project :: () {
    if !project_config.loaded {
        add_user_warning("No project is currently active.", dismiss_in_seconds = 5);
        return;
    }

    defer_action_close_project();
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

    error_msg := tprint("Couldn't find font '%'.\n\nTried the following locations:\n - %\n\nPlease note that you can specify a full path to the desired font file.", name, join(..tried_paths, "\n - ",, allocator = temp));
    return "", error_msg;
}

reset_color_map_to_default :: () {
    COLOR_MAP = DEFAULT_COLOR_MAP;
}

apply_style :: (parsed: Parsed_Config) {
    // Fonts
    if parsed.font {
        loaded_data, success := load_font_by_name(parsed.font);
        if success {
            main_font_data = loaded_data;
            main_font_name = parsed.font;
        } else {
            add_user_error("Couldn't load font %", parsed.font);
        }
    }
    if parsed.font_size > 0 {
        font_size = parsed.font_size;
        default_font_size = font_size;
    }

    apply_parsed_colors(parsed.colors);

    platform_set_border_color();
}

apply_parsed_colors :: (colors: [] Parsed_Color) {
    for colors  COLOR_MAP[it.color_id] = it.color;
    // TODO: @colorref - resolve references
}

get_current_project_name :: () -> string {
    if !project_config.loaded return "";

    path, basename := path_decomp(project_config.path);

    // If the file name is <Project Name>.focus-config, return that
    if basename && basename != ".focus-config" return basename;

    // If the file name is `.focus-config`, return the name of the parent dir
    parent_dir := trim_right(path, "/\\");
    _, __, ___, dir_name := path_decomp(parent_dir);
    return dir_name;
}

get_current_project_dir :: () -> string {
    if !project_config.loaded return "";

    return trim_right(path_strip_filename(project_config.path), "/");
}

#scope_file

load_config :: (path: string, existing: *Loaded_Config, force := false) -> Loaded_Config, changed := true {
    loaded_config: Loaded_Config;
    loaded_config.memory_pool = New(Flat_Pool);

    allocator := Allocator.{ proc = flat_pool_allocator_proc, data = loaded_config.memory_pool };
    push_allocator(allocator);

    file_path := path;

    file_data, success_read := read_entire_file(file_path);
    if !success_read {
        error_msg := tprint("Couldn't read the config file '%'", file_path);
        log_error(error_msg);
        add_user_error(error_msg);
        return loaded_config;
    }

    // Convert to absolute path if we can
    file_path = copy_string(path);
    abs_path, ok := get_absolute_path(path,, temp);
    if ok then file_path = copy_string(abs_path);
    path_overwrite_separators(file_path, #char "/");
    loaded_config.path = file_path;

    loaded_config.hash = calculate_hash(to_bytes(file_data));
    if loaded_config.hash == existing.hash && !force return loaded_config, false;  // unchanged so no need to parse

    // Attempt a migration
    migrated, new_file_data := maybe_migrate_config(file_path, file_data);
    if migrated {
        // Try parsing after migration to verify it's OK
        result := parse_config(file_path, file_path, new_file_data);
        if !result.success {
            add_user_error("We attempted to migrate config file '%' to version [%],\nbut it doesn't parse after migration. Please migrate manually using the default config as a reference.", file_path, CURRENT_CONFIG_VERSION);
            return loaded_config;
        }

        // All good
        write_entire_file(tprint("%.bak", file_path), file_data);
        file_data = new_file_data;

        // Replace the old config's file
        loaded_config.hash = calculate_hash(to_bytes(new_file_data));
        success := write_entire_file(file_path, new_file_data);
        if success {
            add_success_message("Config file '%' has been migrated to version [%]", file_path, CURRENT_CONFIG_VERSION);
        } else {
            add_user_error("We migrated config file '%' to version [%],\nbut could't save the file. Is it writable?", file_path, CURRENT_CONFIG_VERSION);
        }
    }

    parse_result := parse_config(file_path, file_path, file_data);
    if !parse_result.success {
        if !parse_result.error_msg assert(false, "No error message on a config error. This is a bug.");
        add_user_error(parse_result.error_msg, tag = .config);
        return loaded_config;
    }
    if parse_result.warnings {
        add_success_message(tprint("Config file % loaded with warnings", file_path), dismiss_in_seconds = 30, tag = .config);
        for parse_result.warnings add_user_warning(it, dismiss_in_seconds = 30, tag = .config);
        loaded_config.there_were_warnings = true;
    }

    loaded_config.loaded = true;
    loaded_config.parsed_config = parse_result.config;

    return loaded_config;
}

free_loaded_config :: (using loaded_config: *Loaded_Config) {
    path = "";
    parsed_config = Parsed_Config.{};
    if memory_pool {
        reset(memory_pool);
        free(memory_pool);
        memory_pool = null;
    }
}

merge_configs :: (dst: *Config, parsed: Parsed_Config) {
    // Completely replace the workspace subsections if present
    if parsed.members           then dst.workspace.members = parsed.members;
    if parsed.ignore            then dst.workspace.ignore  = parsed.ignore;
    if parsed.allow             then dst.workspace.allow   = parsed.allow;
    if parsed.file_associations then dst.workspace.file_associations = parsed.file_associations;

    // Build config completely overrides the previous config if present
    if parsed.build.commands then dst.build = parsed.build;

    // Keymap
    merge_keymaps :: (dst_keymap: *[] Key_Mapping, src_keymap: *[..] Key_Mapping) #expand {
        if !src_keymap return;
        array_add(src_keymap, ..dst_keymap.*);
        dst_keymap.* = src_keymap.*;
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

    // Style
    if parsed.theme then dst.style.theme = copy_string(parsed.theme); /* @leak */  // TODO: rework how themes and styles are applied
    apply_style(parsed);

    // Platform config
    dst.linux = parsed.linux;
}

apply_config :: () {
    // Make sure the values are within the acceptable range
    old_tab_size := TAB_SIZE;
    TAB_SIZE = clamp(cast(s32) config.settings.tab_size, 1, 100);  // be reasonable mkay (though even 100 is unreasonable)
    if config.settings.tab_size != TAB_SIZE then add_user_warning("Tab size clamped to %", TAB_SIZE);

    if old_tab_size != TAB_SIZE {
        // Refresh all editors which have line wrap on
        for * editor : open_editors {
            buffer := *open_buffers[editor.buffer_id];
            if line_wrap_is_active(editor) then rescan_for_wrapped_lines(editor, buffer);
        }
    }

    clamp_and_warn :: (setting: *$T, min: T, max: T, message: string) {
        old := setting.*;
        clamped := clamp(old, min, max);
        if clamped != old {
            add_user_warning(message, clamped);
            setting.* = clamped;
        }
    }

    clamp_and_warn(*config.settings.line_height_scale_percent,  50,  1000,        "Line height scale clamped to % percent");
    clamp_and_warn(*config.settings.editor_history_size,        4,   1024 * 1024, "Editor history size clamped to %");
    clamp_and_warn(*config.settings.build_panel_height_percent, 10,  100,         "Build panel height clamped to % percent");
    clamp_and_warn(*config.settings.build_panel_width_percent,  10,  100,         "Build panel width clamped to % percent");

    if config.settings.window_width  != -1    clamp_and_warn(*config.settings.window_width,  100, 10000, "Window width clamped to %");
    if config.settings.window_height != -1    clamp_and_warn(*config.settings.window_height, 100, 3000,  "Window height clamped to %");
    if config.settings.window_x      != -1000 clamp_and_warn(*config.settings.window_x,     -500, 10000, "Window X clamped to %");
    if config.settings.window_y      != -1000 clamp_and_warn(*config.settings.window_y,     -500, 3000,  "Window Y clamped to %");

    build_panel_width  = config.settings.build_panel_width_percent  / 100.0;
    build_panel_height = config.settings.build_panel_height_percent / 100.0;
    build_panel_height_anim.target = build_panel_height;
    build_panel_set_line_wrap(config.settings.build_panel_line_wrap_always_on);

    // Must do after the validation
    init_fonts_and_dependent_things();

    platform_apply_config();

    array_reset_keeping_memory(*active_hold_actions);  // NOTE: this doesn't actually stop the actions, it's just here so that we don't
                                                       //       keep pointers to old keymaps when the config is reloaded
}

load_font_by_name :: (name: string) -> font_data: string, success: bool {
    if name == "default" return FONT.data, true;

    push_allocator(focus_allocator);  // we sometimes call this from within a temp allocator, but we will always want to persist fonts

    font_path := find_font_by_name(name);
    if font_path {
        cached_data, found := table_find(*font_cache, font_path);
        if found return cached_data, true;

        font_data, success := read_entire_file(font_path);
        if success {
            table_set(*font_cache, copy_string(font_path), font_data);
            return font_data, true;
        }
    }

    return "", false;
}

font_cache: Table(string, string);  // path -> file data

#scope_export

// Currently active config
config: Config;

// Info about currently loaded configs, useful when reloading etc.
global_config:  Loaded_Config;
project_config: Loaded_Config;


Config :: struct {
    workspace: Workspace;
    keymap:    Keymap;
    settings:  Settings;
    style:     Style;
    build:     Build_Config;
    linux:     Linux_Config;
}

Style :: struct {
    theme: string;
    // TODO: add other things in there at some point
}

Loaded_Config :: struct {
    loaded := false;
    there_were_warnings := false;
    path: string;
    hash: u64;
    parsed_config: Parsed_Config;
    memory_pool: *Flat_Pool;  // must be valid for the lifetime of the config
}

Linux_Config :: struct {
    scaling_factor: float = 0.0;
    explorer_command: string;
    explorer_reveal_command: string;
}

Workspace :: struct {
    members:            [] string;
    ignore:             [] string;
    allow:              [] string;
    file_associations:  [] File_Association;
}

Settings :: struct {
    maximize_on_start                                       := false;
    open_on_the_biggest_monitor                             := true;
    window_width                                            := -1;
    window_height                                           := -1;
    window_x                                                := -1000;  // using -1000 because -1 could be a valid value someone might want
    window_y                                                := -1000;
    cursor_as_block                                         := true;
    cursor_blink_time_in_seconds                            := 5;
    highlight_selection_occurrences                         := true;
    highlight_line_with_cursor                              := false;
    highlight_matching_brackets                             := false;
    show_paste_effect                                       := true;
    disable_file_open_close_animations                      := false;
    disable_viewport_chasing_cursor_near_the_edge           := false;
    double_shift_to_search_in_workspace                     := false;
    tab_size                                                := 4;
    insert_spaces_when_pressing_tab                         := true;
    strip_trailing_whitespace_on_save                       := Strip_Trailing_Whitespace.except_lines_with_cursor;
    insert_final_newline_on_save                            := false;
    smooth_scrolling                                        := true;
    scroll_beyond_last_line                                 := true;
    line_height_scale_percent                               := 120;
    max_editor_width                                        := -1;
    can_cancel_go_to_line                                   := true;
    copy_whole_line_without_selection                       := false;
    editor_history_size                                     := 128;
    line_wrap_is_on_by_default                              := false;
    show_line_numbers                                       := false;
    dark_titlebar                                           := false;
    colored_titlebar                                        := true;
    hide_mouse_when_typing                                  := true;
    draw_indent_guides                                      := false;
    auto_surround_with_brackets_and_quotes                  := false;
    auto_close_brackets                                     := false;
    prefer_system_file_dialogs                              := false;
    show_cursors_off_screen                                 := true;
    persist_local_search_results                            := false;
    search_is_case_sensitive_when_uppercase_present         := false;
    show_selected_text_length                               := false;
    load_most_recent_project_on_start                       := false;

    build_panel_width_percent                               := 50;
    build_panel_height_percent                              := 50;
    build_panel_stays_in_one_place                          := false;
    build_panel_line_wrap_always_on                         := true;

    save_current_buffer_on_build                            := false;
    save_all_file_backed_buffers_on_build                   := false;

    status_bar_position                                     := Status_Bar_Position.bottom;
    color_preview_popup                                     := Color_Preview_Popup.enabled;
    projects_sorting_order                                  := Projects_Sorting_Order.most_recent_first;

    // TODO
    // convert_tabs_to_spaces_on_load:     false
    // load_last_session_on_start:         true
}

Status_Bar_Position :: enum {
    bottom;
    top;
}

Strip_Trailing_Whitespace :: enum {
    except_lines_with_cursor;
    all;
    disabled;
}

Color_Preview_Popup :: enum {
    enabled;
    minimized;
    disabled;
}

Projects_Sorting_Order :: enum {
    most_recent_first;
    alphabetical;
    alphabetical_no_case;
}

Keymap :: struct {
    common:           [] Key_Mapping;
    editors:          [] Key_Mapping;
    open_file_dialog: [] Key_Mapping;
    search_dialog:    [] Key_Mapping;

    build:            [] Key_Mapping;  // treated specially, it's not in the keymap config, but in the build config for convenience
}

File_Association :: struct {
    wildcard: string;
    lang: Buffer.Lang;
}

operator== :: (a: File_Association, b: File_Association) -> bool {
    return a.wildcard == b.wildcard && a.lang == b.lang;
}

Build_Config :: struct {
    defaults: Build_Command;
    defaults.name = "Default Build Command";
    commands: [..] Build_Command;
    keymap: [..] Key_Mapping;  // separate from the other keymaps because it should never merge with the previous config
                               // (because the build commands don't merge so we can't use the previous config's keymaps)
}

Build_Command :: struct {
    name:                   string;  @dontparse

    build_command:                      string;
    build_working_dir:                  string;

    run_command:                        string;
    run_working_dir:                    string;

    error_regex:                        string;

    auto_jump_to_error:                 bool;
    open_panel_on_build:                bool;
    close_panel_on_success:             bool;
    clear_build_output_before_running:  bool;
    substitute_variables:               bool = true;

    timeout_in_seconds:                 int = -1;
}

DEFAULT_CONFIG_FILE_DATA  :: #run read_entire_file(tprint("config/%", DEFAULT_CONFIG_NAME));
EXAMPLE_PROJECT_FILE_DATA :: #run read_entire_file(tprint("config/%", EXAMPLE_PROJECT_CONFIG_NAME));

#scope_file

#if OS == .MACOS {
    DEFAULT_CONFIG_NAME :: "default_macos.focus-config";
} else {
    DEFAULT_CONFIG_NAME :: "default.focus-config";
}
EXAMPLE_PROJECT_CONFIG_NAME :: "example-project.focus-config";


#scope_export

DEFAULT_CONFIG :: #run,stallable -> Config {
    result := parse_config("Default Config", DEFAULT_CONFIG_NAME, DEFAULT_CONFIG_FILE_DATA);
    assert(result.success, "Couldn't parse the default config file '%'. Error: %", DEFAULT_CONFIG_NAME, result.error_msg);
    default_config: Config;
    merge_configs(*default_config, result.config);
    DEFAULT_COLOR_MAP = COLOR_MAP;  // remember the default color map
    return default_config;
};

// Validate the example project config
#run,stallable {
    result := parse_config("Example Project Config", EXAMPLE_PROJECT_CONFIG_NAME, EXAMPLE_PROJECT_FILE_DATA);
    assert(result.success, "Couldn't parse the example project config file '%'", EXAMPLE_PROJECT_CONFIG_NAME);
}
