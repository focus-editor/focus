#add_context config: *Config;
#add_context config_snapshot: *Config_Snapshot;
#add_context buffer_settings_cache: Buffer_Settings_Cache;

// Increment this if your PR adds a setting, color or default keybinding (and amend the relevant array
// in config_migrator.jai).  You don't need to increase it for each such change; once per PR is best.
CURRENT_CONFIG_VERSION :: 25;

get_global_config_path :: inline () -> string /* temp */ {
    return tprint("%/global.focus-config", config_dir);
}

load_config :: (config_path: string) -> Loaded_Config {
    file_data, success_read := read_entire_file(config_path,, temp);
    if !success_read {
        error_msg := tprint("Couldn't read the config file '%'", config_path);
        log_error(error_msg);
        add_user_error(error_msg);
        return .{};
    }
    return load_config(config_path, file_data);
}

load_config :: (config_path: string, file_contents: string) -> Loaded_Config {
    loaded_config: Loaded_Config;
    loaded_config.memory_pool = New(Flat_Pool);

    allocator := Allocator.{ proc = flat_pool_allocator_proc, data = loaded_config.memory_pool };
    push_allocator(allocator);

    path := copy_string(config_path);
    file_data := copy_string(file_contents);

    // Convert to absolute path if we can
    abs_path, ok := get_absolute_path(path,, temp);
    if ok then path = copy_string(abs_path);
    path_overwrite_separators(path, #char "/");
    loaded_config.path = path;
    loaded_config.hash = calculate_hash(to_bytes(file_data));

    // Attempt a migration
    migrated, new_file_data := maybe_migrate_config(path, file_data);
    if migrated {
        // Try parsing after migration to verify it's OK
        result := parse_config(path, path, new_file_data);
        if !result.success {
            add_user_error("We attempted to migrate config file '%' to version [%],\nbut it doesn't parse after migration. Please migrate manually using the default config as a reference.", path, CURRENT_CONFIG_VERSION);
            return loaded_config;
        }

        // All good
        write_entire_file(tprint("%.bak", path), file_data);
        file_data = new_file_data;

        // Replace the old config's file
        success := write_entire_file(path, new_file_data);
        if success {
            loaded_config.hash = calculate_hash(to_bytes(new_file_data));
            add_success_message("Config file '%' has been migrated to version [%]", path, CURRENT_CONFIG_VERSION);
        } else {
            add_user_error("We migrated config file '%' to version [%],\nbut could't save the file. Is it writable?", path, CURRENT_CONFIG_VERSION);
        }
    }

    parse_result := parse_config(path, path, file_data);
    if !parse_result.success {
        if !parse_result.error_msg then panic_messagebox("No error message on a config error. This is a bug.");
        add_user_error(parse_result.error_msg, tag = .config);
        return loaded_config;
    }
    if parse_result.warnings {
        add_success_message(tprint("Config file % loaded with warnings", path), dismiss_in_seconds = 30, tag = .config);
        for parse_result.warnings add_user_warning(it, dismiss_in_seconds = 30, tag = .config);
    }

    loaded_config.loaded = true;
    loaded_config.parsed_config = parse_result.config;

    return loaded_config;
}

// Only used when global config fails to load or parse
load_default_config_fallback :: (config_path: string) -> Loaded_Config {
    loaded_config: Loaded_Config;
    loaded_config.memory_pool = New(Flat_Pool);

    allocator := Allocator.{ proc = flat_pool_allocator_proc, data = loaded_config.memory_pool };
    push_allocator(allocator);

    loaded_config.path = copy_string(config_path);

    parse_result := parse_config(loaded_config.path, loaded_config.path, DEFAULT_CONFIG_FILE_DATA);

    loaded_config.parsed_config = parse_result.config;
    loaded_config.loaded = true;

    return loaded_config;
}

merge_and_apply_configs :: (new_global: *Loaded_Config, new_project: *Loaded_Config = null) -> changed: bool {
    log("Merging configs. Global: '%', Project: '%'", new_global.path, ifx new_project then new_project.path else "-");

    new_config: Config;
    new_config.style = DEFAULT_CONFIG.style;
    new_config.memory_pool = New(Flat_Pool);
    pool_allocator := allocator_of(new_config.memory_pool);

    if new_global.loaded {
        merge_configs(*new_config, new_global.parsed_config);
    } else {
        log_error("Using previous global config because new one (%) failed to load", new_global.path);
        merge_configs(*new_config, global_config.parsed_config);
    }

    if new_project && new_project.loaded {
        log("Using project config '%'", new_project.path);
        merge_configs(*new_config, new_project.parsed_config);
        new_config.project_path = copy_string(new_project.path,, pool_allocator);
    }
    else if new_project && !new_project.loaded {
        if project_config.loaded {
            log_error("Using previous project config version because the new one (%) failed to load", new_project.path);
            merge_configs(*new_config, project_config.parsed_config);
            new_config.project_path = copy_string(project_config.path,, pool_allocator);
        } else {
            log_error("Not using project config because it failed to load and there was no previous version");
        }
    }

    clamp_config_values(*new_config);

    // Replace the config if changed
    diff: Config_Diff;
    if context.config {
        diff = get_config_diff(context.config, new_config);
    } else {
        // We don't have any config yet
        diff.changed = true;
        diff.settings_changed = true;
        diff.build_config_changed = true;
        diff.style_changed = true;
    }

    // Remember this before transferring ownership out of new_project.
    remember_project := new_project && new_project.loaded;

    // Keep the latest parsed sources even when their changes are masked by overrides.
    replace_loaded_config(*global_config,  new_global);
    replace_loaded_config(*project_config, new_project);

    if diff.changed {
        if remember_project then add_to_most_recent_projects(project_config.path);

        build_comment_words_automaton(*new_config,, pool_allocator);
        replace_and_apply_config(new_config, diff);
    }
    else {
        log("Merged config unchanged, skip applying");
        free_config(*new_config);
    }

    return diff.changed;
}

#scope_file

clamp_config_values :: (new_config: *Config) {
    settings := *new_config.settings;

    Clamp(*settings.tab_size, 1, 100);

    Clamp(*settings.line_height_scale_percent,  50,  1000);
    Clamp(*settings.build_panel_height_percent, 10,  100);
    Clamp(*settings.build_panel_width_percent,  10,  100);

    Clamp(*settings.scrollbar_width_scale, 0.0, 10.0);
    Clamp(*settings.scrollbar_min_opacity, 0.0,  1.0);
    Clamp(*settings.scrollbar_max_opacity, settings.scrollbar_min_opacity,  1.0);

    Clamp(*settings.scrollbar_fade_in_sensitivity,    0.0, 100.0);
    Clamp(*settings.scrollbar_fade_out_delay_seconds, 0.0, 1000.0);

    Clamp(*settings.cursor_position_after_jump, 0.0, 1.0);

    if settings.window_width  != -1    Clamp(*settings.window_width,  100, 10000);
    if settings.window_height != -1    Clamp(*settings.window_height, 100, 3000);
    if settings.window_x      != -1000 Clamp(*settings.window_x,     -500, 10000);
    if settings.window_y      != -1000 Clamp(*settings.window_y,     -500, 3000);
}

replace_and_apply_config :: (new_config: Config, diff: Config_Diff) {
    publish_new_config_snapshot(new_config);

    new_snapshot := acquire_current_config_snapshot();
    release_config_snapshot(context.config_snapshot);
    context_set_config_snapshot(new_snapshot);

    // Apply new config

    if diff.style_changed {
        apply_style(context.config.style);
    }

    // Update languages before any settings-dependent refreshes.
    if diff.file_associations_changed {
        for * buffer : open_buffers {
            if !buffer.has_file continue;
            lang := get_lang_from_path(buffer.file.full_path);
            if lang != buffer.lang {
                set_buffer_language(buffer, lang);
            }
        }
    }

    if diff.tab_size_changed {
        // Refresh all editors which have line wrap on
        for * editor : open_editors {
            buffer := *open_buffers[editor.buffer_id];
            if line_wrap_is_active(editor) then rescan_for_wrapped_lines(editor, buffer);
        }
    }

    if diff.settings_changed || diff.file_specific_settings_changed {
        build_panel_width  = context.config.settings.build_panel_width_percent  / 100.0;
        build_panel_height = context.config.settings.build_panel_height_percent / 100.0;
        build_panel_height_anim.target = build_panel_height;
        build_panel_set_line_wrap(context.config.settings.build_panel_line_wrap_always_on);

        // In case indentation rules changed, refresh them for all open editors
        for editor : open_editors {
            buffer := *open_buffers[editor.buffer_id];

            maybe_detect_and_set_indentation(buffer);
        }
    }

    if diff.workspace_members_changed || diff.allow_ignore_changed {
        if unsaved_buffers_exist() {
            clear_user_messages();
            if diff.workspace_members_changed then add_user_warning("Workspace members have changed in the config.\nWorkspace will need to reload, however there are unsaved changes.", tag = .workspace);
            if diff.allow_ignore_changed      then add_user_warning("Workspace ignore rules have changed in the config.\nWorkspace will need to reload, however there are unsaved changes.", tag = .workspace);
        }
        should_reload_workspace = true;
    }


    if !context.config.settings.enable_temporary_editors then make_all_editors_permanent();

    if diff.fonts_changed {
        init_fonts_and_dependent_things();
    }

    if diff.build_config_changed {
        commands_refresh_after_config_change();
    }

    dont_ignore_next_window_resize = true;

    platform_apply_config();

    {
        editor_id := get_active_editor_id();
        if editor_id < 0 then editor_id = get_visible_editor_id(editors.active_pane);

        buffer_id := ifx editor_id >= 0 then open_editors[editor_id].buffer_id else -1;
        update_window_title(buffer_id);
    }

    array_reset_keeping_memory(*active_hold_actions);  // NOTE: this doesn't actually stop the actions, it's just here so that we don't
                                                       //       keep pointers to old keymaps when the config is reloaded
    array_reset_keeping_memory(*key_sequence_input.potential_multipart_matches);
    array_reset_keeping_memory(*key_sequence_input.new_multipart_matches);
    key_sequence_input.active_sequence_length = 0;
}

Config_Diff :: struct {
    changed:                         bool;

    workspace_members_changed:       bool;
    allow_ignore_changed:            bool;
    file_associations_changed:       bool;

    settings_changed:                bool;
    comment_highlight_words_changed: bool;
    file_specific_settings_changed:  bool;
    tab_size_changed:                bool;

    keymap_changed:                  bool;
    build_config_changed:            bool;

    style_changed:                   bool;
    fonts_changed:                   bool;

    linux_config_changed:            bool;

    project_changed:                 bool;
}


get_config_diff :: (old: Config, new: Config) -> Config_Diff {
    diff: Config_Diff;

    diff.workspace_members_changed       = workspace_members_changed(old, new);
    diff.allow_ignore_changed            = allow_ignore_changed(old, new);
    diff.file_associations_changed       = file_associations_changed(old, new);

    diff.settings_changed                = settings_changed(old, new);
    diff.comment_highlight_words_changed = comment_highlight_words_changed(old, new);
    diff.file_specific_settings_changed  = file_specific_settings_changed(old, new);
    diff.tab_size_changed                = old.settings.tab_size != new.settings.tab_size;

    diff.keymap_changed                  = keymap_changed(old, new);
    diff.build_config_changed            = build_config_changed(old, new);

    diff.style_changed                   = style_changed(old, new);
    diff.fonts_changed                   = fonts_changed(old, new);

    diff.linux_config_changed            = linux_config_changed(old, new);

    diff.project_changed                 = old.project_path != new.project_path;

    diff.changed =
        diff.workspace_members_changed ||
        diff.allow_ignore_changed ||
        diff.file_associations_changed ||
        diff.settings_changed ||
        diff.comment_highlight_words_changed ||
        diff.file_specific_settings_changed ||
        diff.keymap_changed ||
        diff.build_config_changed ||
        diff.style_changed ||
        diff.fonts_changed ||
        diff.linux_config_changed ||
        diff.project_changed;


    return diff;
}

workspace_members_changed :: (old: Config, new: Config) -> changed: bool {
    // Even if the workspace members are reordered we still want to refresh workspace
    return !arrays_are_equal(old.workspace.members, new.workspace.members);
}

allow_ignore_changed :: (old: Config, new: Config) -> changed: bool {
    return
        !arrays_contain_the_same_items(old.workspace.allow,  new.workspace.allow) ||
        !arrays_contain_the_same_items(old.workspace.ignore, new.workspace.ignore);
}

file_associations_changed :: (old: Config, new: Config) -> changed: bool {
    return !arrays_are_equal(new.workspace.file_associations, old.workspace.file_associations);
}

settings_changed :: (old: Config, new: Config) -> changed: bool {
    #insert -> string {
        b: String_Builder;
        for setting : type_info(Settings).members {
            print_to_builder(*b, "if new.settings.%1 != old.settings.%1  return true;\n", setting.name);
        }
        return builder_to_string(*b);
    }
    return false;
}

comment_highlight_words_changed :: (old: Config, new: Config) -> changed: bool {
    return old.settings.comment_highlight_words1 != new.settings.comment_highlight_words1 ||
           old.settings.comment_highlight_words2 != new.settings.comment_highlight_words2 ||
           old.settings.comment_highlight_words3 != new.settings.comment_highlight_words3 ||
           old.settings.comment_highlight_words4 != new.settings.comment_highlight_words4;
}

file_specific_settings_changed :: (old: Config, new: Config) -> changed: bool {
    return !arrays_are_equal(old.file_specific_settings, new.file_specific_settings);
}

keymap_changed :: (old: Config, new: Config) -> changed: bool {
    return !arrays_are_equal(old.keymap.common,           new.keymap.common)           ||
           !arrays_are_equal(old.keymap.editors,          new.keymap.editors)          ||
           !arrays_are_equal(old.keymap.open_file_dialog, new.keymap.open_file_dialog) ||
           !arrays_are_equal(old.keymap.search_dialog,    new.keymap.search_dialog)    ||
           !arrays_are_equal(old.keymap.build,            new.keymap.build);
}

build_config_changed :: (old: Config, new: Config) -> changed: bool {
    return old.build.defaults != new.build.defaults ||
           !arrays_are_equal(old.build.commands, new.build.commands) ||
           !arrays_are_equal(old.build.keymap,   new.build.keymap);
}

style_changed :: (old: Config, new: Config) -> changed: bool {
    return old.style != new.style;
}

fonts_changed :: (old: Config, new: Config) -> changed: bool {
    // TODO: cleanup this mess with things that depend on zoom and not fonts
    return !style_font_fields_are_equal(old.style, new.style) ||
           old.settings.show_tab_characters_in_selection != new.settings.show_tab_characters_in_selection ||
           old.settings.line_height_scale_percent        != new.settings.line_height_scale_percent        ||
           old.settings.scrollbar_width_scale            != new.settings.show_tab_characters_in_selection;
}

linux_config_changed :: (old: Config, new: Config) -> changed: bool {
    return old.linux != new.linux;
}


#scope_export

maybe_defer_refresh_config_or_theme :: (path: string) {
    if is_our_config_file(path) || is_current_theme(path) {
        defer_action_refresh_config_or_theme(path);
    }
}

refresh_config :: (path: string) {
    is_global_config  := platform_path_equals(path, global_config.path);
    is_project_config := platform_path_equals(path, project_config.path);

    if !is_global_config && !is_project_config {
        log_error("Attempted to refresh config from file '%', but it is not a global config or a current project config", path);
        return;
    }

    file_data, success_read := read_entire_file(path,, temp);
    if !success_read {
        error_msg := tprint("Attempted to refresh config from file '%', but couldn't read the file", path);
        log_error(error_msg);
        add_user_error(error_msg);
        return;
    }

    current_config := ifx is_global_config then *global_config else *project_config;
    config_type    := ifx is_global_config then "global" else "project";

    if current_config.hash == calculate_hash(to_bytes(file_data)) {
        log("[refresh_config] Previous % config has identical hash, skip refreshing: '%'", config_type, path);
        return;
    }

    // Always clear messages even if the configs are technically unchanged.
    // Suppose the user had a bad line which produced an error and then deleted it and saved,
    // then the generated config hasn't changed but the error should still go away
    clear_user_messages(.config);

    loaded_config := load_config(path, file_data);
    current_config.hash = loaded_config.hash;

    if !loaded_config.loaded {
        log_error("Attempted to refresh % config from file '%', but it has errors", config_type, path);
        free_loaded_config(*loaded_config);
        return;
    }

    if is_global_config {
        changed := merge_and_apply_configs(*loaded_config, ifx project_config.loaded then *project_config else null);
        if changed {
            add_success_message("Global config changes have been applied", dismiss_in_seconds = 3, tag = .config);
        }
    }
    else if is_project_config {
        changed := merge_and_apply_configs(*global_config, *loaded_config);
        if changed {
            add_success_message("Config changes for project '%' have been applied", get_current_project_name(), dismiss_in_seconds = 3, tag = .config);
        }
    }
}

refresh_current_theme :: () {
    clear_user_messages(.config);

    loaded_global := load_config(global_config.path);
    if !loaded_global.loaded {
        free_loaded_config(*loaded_global);
        return;
    }

    loaded_project: Loaded_Config;
    loaded_project_ptr: *Loaded_Config = null;

    if project_config.loaded {
        loaded_project = load_config(project_config.path);
        if !loaded_project.loaded {
            free_loaded_config(*loaded_project);
            free_loaded_config(*loaded_global);
            return;
        }

        loaded_project_ptr = *loaded_project;
    }

    merge_and_apply_configs(*loaded_global, loaded_project_ptr);
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
    return context.config.style.theme && platform_path_equals(path, tprint("%/%.focus-theme", themes_dir, context.config.style.theme));
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
    COLOR_MAP = DEFAULT_CONFIG.style.colors;
}

apply_style :: (style: Style) {
    // Replace color map
    COLOR_MAP = style.colors;

    // Load and replace all fonts. If any fail to load they will fall back to defaults
    load_and_replace_font(*loaded_fonts.main,           style.font,                .main);
    load_and_replace_font(*loaded_fonts.ui,             style.font_ui,             .ui);
    load_and_replace_font(*loaded_fonts.ui_bold,        style.font_ui_bold,        .ui_bold);
    load_and_replace_font(*loaded_fonts.ui_bold_italic, style.font_ui_bold_italic, .ui_bold_italic);

    if default_font_main_size != style.font_size {
        font_main_size = style.font_size;
        default_font_main_size = style.font_size;
    }

    if default_font_ui_size != style.font_ui_size {
        font_ui_size = style.font_ui_size;
        default_font_ui_size = style.font_ui_size;
    }

    platform_set_border_color();
}

// TODO: remove
apply_style :: (parsed: Parsed_Config) {
    apply_parsed_colors(parsed.colors);
    platform_set_border_color();
}

// TODO: remove
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

replace_loaded_config :: (dst: *Loaded_Config, src: *Loaded_Config) {
    if dst == src return;

    // A failed config must not replace the previously valid one
    if src && !src.loaded {
        free_loaded_config(src);
        return;
    }

    free_loaded_config(dst);

    if src {
        dst.* = src.*;
        src.* = .{};
    }
}

free_loaded_config :: (using loaded_config: *Loaded_Config) {
    if loaded_config == null return;

    if memory_pool {
        fini(memory_pool);
        free(memory_pool);
        memory_pool = null;
    }

    loaded_config.* = .{};
}

free_config :: (config: *Config) {
    if config.memory_pool == null return;

    fini(config.memory_pool);
    free(config.memory_pool);
    config.* = .{};
}


#scope_file

merge_configs :: (dst: *Config, parsed: Parsed_Config) {
    if !dst.memory_pool then dst.memory_pool = New(Flat_Pool);

    // Do a deep copy of everything so that the destination config owns its own data
    push_allocator(allocator_of(dst.memory_pool));

    // Completely replace the workspace subsections if present
    if parsed.members           then dst.workspace.members           = deep_copy(parsed.members);
    if parsed.ignore            then dst.workspace.ignore            = deep_copy(parsed.ignore);
    if parsed.allow             then dst.workspace.allow             = deep_copy(parsed.allow);
    if parsed.file_associations then dst.workspace.file_associations = deep_copy(parsed.file_associations);

    // Build config completely overrides the previous config if present
    if parsed.build.commands    then dst.build = deep_copy(parsed.build);

    // Keymap
    merge_keymaps :: (dst_keymap: *[] Key_Mapping, src_keymap: [] Key_Mapping) {
        if !src_keymap.count return;

        merged: [..] Key_Mapping;

        for src_keymap {
            mapping := it;
            mapping.key_sequence = array_copy(it.key_sequence);
            array_add(*merged, mapping);
        }
        for dst_keymap.* {
            mapping := it;
            mapping.key_sequence = array_copy(it.key_sequence);
            array_add(*merged, mapping);
        }
        dst_keymap.* = merged;
    }

    merge_keymaps(*dst.keymap.common,           parsed.keymap_common);
    merge_keymaps(*dst.keymap.editors,          parsed.keymap_editors);
    merge_keymaps(*dst.keymap.open_file_dialog, parsed.keymap_open_file_dialog);
    merge_keymaps(*dst.keymap.search_dialog,    parsed.keymap_search_dialog);

    // Settings
    #insert -> string {
        b: String_Builder;
        for setting : type_info(Settings).members {
            if setting.type.type == .STRING {
                print_to_builder(*b, "if array_find(parsed.set_settings, \"%1\") { dst.settings.%1 = copy_string(parsed.settings.%1); }\n", setting.name);
            } else {
                print_to_builder(*b, "if array_find(parsed.set_settings, \"%1\") { dst.settings.%1 = parsed.settings.%1; }\n", setting.name);
            }
        }
        return builder_to_string(*b);
    }

    // Merge file-specific settings
    // NOTE: if you have file-specific settings in the global config, they will take priority over any
    //       non-file-specific settings added in the project config
    {
        old_count := dst.file_specific_settings.count;
        array_resize(*dst.file_specific_settings, old_count + parsed.file_specific_settings.count);
        for setting, i : parsed.file_specific_settings {
            dst.file_specific_settings[old_count + i] = deep_copy(setting);
        }
    }

    // Style
    if parsed.theme                     then dst.style.theme = copy_string(parsed.theme);
    for parsed.colors  dst.style.colors[it.color_id] = it.color;

    if parsed.font                      then dst.style.font                 = copy_string(parsed.font);
    if parsed.font_ui                   then dst.style.font_ui              = copy_string(parsed.font_ui);
    if parsed.font_ui_bold              then dst.style.font_ui_bold         = copy_string(parsed.font_ui_bold);
    if parsed.font_ui_bold_italic       then dst.style.font_ui_bold_italic  = copy_string(parsed.font_ui_bold_italic);

    if parsed.font_size    > 0          then dst.style.font_size            = parsed.font_size;
    if parsed.font_ui_size > 0          then dst.style.font_ui_size         = parsed.font_ui_size;

    if parsed.font_anti_aliasing.is_set then dst.style.font_anti_aliasing   = parsed.font_anti_aliasing.value;
    if parsed.font_hinting.is_set       then dst.style.font_hinting         = parsed.font_hinting.value;

    // Platform config
    dst.linux = deep_copy(parsed.linux);
}

build_comment_words_automaton :: (new_config: *Config) {
    highlight_words_settings := string.[
        new_config.settings.comment_highlight_words1,
        new_config.settings.comment_highlight_words2,
        new_config.settings.comment_highlight_words3,
        new_config.settings.comment_highlight_words4,
    ];
    token_types := Token_Type.[
        .comment_highlight1,
        .comment_highlight2,
        .comment_highlight3,
        .comment_highlight4,
    ];

    words: [..] Highlight_Word;
    words.allocator = temp;

    for setting : highlight_words_settings {
        word_list  := split(setting, ",",, temp);
        token_type := token_types[it_index];
        for word_list {
            word := trim(it);
            if word then array_add(*words, .{ word, token_type });
        }
    }

    new_config.comment_words_automaton = build_aho_corasick_automaton(words);
}

Font_Kind :: enum {
    main;
    ui;
    ui_bold;
    ui_bold_italic;
}

load_and_replace_font :: (dst: *Loaded_Font, name: string, kind: Font_Kind) {
    loaded_font, success := load_font_by_name(name, kind);
    if !success {
        add_user_error("Couldn't load font '%'", name);
        loaded_font = load_font_by_name("default", kind);
    }
    dst.* = loaded_font;
}

load_font_by_name :: (name: string, kind: Font_Kind) -> Loaded_Font, success: bool {
    if name == "default" {
        if #complete kind == {
            case .main;             return FONT_MAIN,           true;
            case .ui;               return FONT_UI,             true;
            case .ui_bold;          return FONT_UI_BOLD,        true;
            case .ui_bold_italic;   return FONT_UI_BOLD_ITALIC, true;
        }
    }

    push_allocator(focus_allocator);  // we sometimes call this from within a temp allocator, but we will always want to persist fonts

    font_path := find_font_by_name(name);
    if font_path {
        found, cached_font := table_find(*font_cache, font_path);
        if found return cached_font, true;

        font_data, success := read_entire_file(font_path);
        if success {
            loaded_font := Loaded_Font.{ copy_string(name), font_data };
            table_set(*font_cache, copy_string(font_path), loaded_font);
            return loaded_font, true;
        }
    }

    return .{}, false;
}

font_cache: Table(string, Loaded_Font);  // path -> loaded font

#scope_export

// Info about currently loaded configs, useful when reloading etc.
global_config:  Loaded_Config;
project_config: Loaded_Config;

Config :: struct {
    memory_pool: *Flat_Pool;

    workspace: Workspace;
    keymap:    Keymap;

    settings:  Settings;
    file_specific_settings: [] File_Specific_Settings;

    style:     Style;
    build:     Build_Config;
    linux:     Linux_Config;

    project_path: string;

    comment_words_automaton: Aho_Corasick_Automaton;
}

Style :: struct {
    theme: string;

    colors: [COLOR_MAP_SIZE] Vector4;

    font                := "default";
    font_ui             := "default";
    font_ui_bold        := "default";
    font_ui_bold_italic := "default";

    font_size:      int = DEFAULT_FONT_MAIN_SIZE;
    font_ui_size:   int = DEFAULT_FONT_UI_SIZE;

    font_anti_aliasing: Font_Anti_Aliasing = .lcd;
    font_hinting := true;
}

operator== :: (a: Style, b: Style) -> bool {
    #insert -> string {
        builder: String_Builder;
        for type_info(Style).members {
            if it.type.type == .ARRAY {
                print_to_builder(*builder, "if !arrays_are_equal(a.%1, b.%1)  return false;\n", it.name);
            } else {
                print_to_builder(*builder, "if a.%1 != b.%1  return false;\n", it.name);
            }
        }
        return builder_to_string(*builder);
    }
    return true;
}

style_font_fields_are_equal :: (a: Style, b: Style) -> bool {
    #insert -> string {
        builder: String_Builder;
        for type_info(Style).members {
            if contains(it.name, "font") {
                print_to_builder(*builder, "if a.%1 != b.%1  return false;\n", it.name);
            }
        }
        return builder_to_string(*builder);
    }
    return true;
}

Loaded_Font :: struct {
    name: string;
    data: string;
}

Loaded_Config :: struct {
    loaded := false;
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

operator== :: (a: Linux_Config, b: Linux_Config) -> bool {
    #insert -> string {
        builder: String_Builder;
        for type_info(Linux_Config).members {
            print_to_builder(*builder, "if a.%1 != b.%1  return false;\n", it.name);
        }
        return builder_to_string(*builder);
    }
    return true;
}

Workspace :: struct {
    members:            [] string;
    ignore:             [] File_Pattern;
    allow:              [] File_Pattern;
    file_associations:  [] File_Association;
}

File_Pattern :: struct {
    pattern: string;  // pre-lowercased on Windows
    should_match_whole_path: bool;
    pattern_type: Pattern_Type;

    Pattern_Type :: enum { LITERAL; EXTENSION; WILDCARD; }
}

construct_file_pattern :: (pattern: string) -> File_Pattern {
    should_match_whole_path := contains(pattern, #char "/");

    pattern_type: File_Pattern.Pattern_Type;

    #if OS == .WINDOWS {
        final_pattern := to_lower_copy(pattern);
    } else {
        final_pattern := pattern;
    }

    // Try to classify as an extension pattern first (e.g. "*.exe" -> store just "exe").
    // Only valid as a partial-match pattern — "src/*.exe" stays a WILDCARD.
    ext, is_ext_pattern := is_extension_pattern(pattern);
    if is_ext_pattern && !should_match_whole_path {
        pattern_type = .EXTENSION;
        final_pattern = ext;
    } else if contains_wildcards(pattern) {
        pattern_type = .WILDCARD;
    } else {
        pattern_type = .LITERAL;
    }

    return File_Pattern.{
        pattern = final_pattern,
        should_match_whole_path = should_match_whole_path,
        pattern_type = pattern_type,
    };
}

contains_wildcards :: inline (s: string) -> bool {
    for 0..s.count-1 {
        c := s[it];
        if c == #char "*" || c == #char "?" return true;
    }
    return false;
}

is_extension_pattern :: (pattern: string) -> extension: string, is_extension: bool {
    if pattern.count < 3       return "", false;  // need at least "*.x"
    if pattern[0] != #char "*" return "", false;
    if pattern[1] != #char "." return "", false;

    ext := slice(pattern, 2, pattern.count - 2);

    // Reject if the extension part itself contains wildcards (e.g. "*.*", "*.?", "*.e*e")
    for 0..ext.count-1 {
        c := ext[it];
        if c == #char "*" || c == #char "?" return "", false;
    }

    return ext, true;
}

operator== :: (a: File_Pattern, b: File_Pattern) -> bool {
    return a.pattern == b.pattern && a.should_match_whole_path == b.should_match_whole_path && a.pattern_type == b.pattern_type;
}

// The array_find function in Basic doesn't seem to work well with the compare function
array_find :: (array: [] File_Pattern, item: File_Pattern) -> bool, s64 {
    for array if it == item return true, it_index;
    return false, -1;  // Not found.
}

Settings :: struct {
    // Global settings that apply to the editor as a whole
    maximize_on_start                                       := false;   @v1
    open_on_the_biggest_monitor                             := true;    @v1
    window_width                                            := -1;      @v4
    window_height                                           := -1;      @v4
    window_x                                                := -1000;   @v1  // using -1000 because -1 could be a valid value someone might want
    window_y                                                := -1000;   @v1
    cursor_blink_time_in_seconds                            := 5;       @v1
    disable_viewport_chasing_cursor_near_the_edge           := false;   @v3
    smooth_scrolling                                        := true;    @v1
    show_paste_effect                                       := true;    @v6
    line_height_scale_percent                               := 120;     @v1
    can_cancel_go_to_line                                   := true;    @v1
    hide_mouse_when_typing                                  := true;    @v1
    dark_titlebar                                           := false;   @v1
    colored_titlebar                                        := true;    @v1
    copy_whole_line_without_selection                       := false;   @v1
    prefer_system_file_dialogs                              := false;   @v1
    persist_local_search_results                            := false;   @v2
    search_is_case_sensitive_when_uppercase_present         := false;   @v6
    load_most_recent_project_on_start                       := false;   @v5
    build_panel_width_percent                               := 50;      @v2
    build_panel_height_percent                              := 50;      @v2
    build_panel_stays_in_one_place                          := false;   @v2
    build_panel_line_wrap_always_on                         := true;    @v2
    projects_sorting_order                                  := Projects_Sorting_Order.most_recent_first;    @v6
    color_preview_popup                                     := Color_Preview_Popup.enabled;                 @v5
    save_current_buffer_on_build                            := false;   @v3
    save_all_file_backed_buffers_on_build                   := false;   @v3
    double_shift_to_search_in_workspace                     := false;   @v1
    scrollbar_width_scale                                   := 1.0;     @v16
    scrollbar_min_opacity                                   := 0.0;     @v16
    scrollbar_max_opacity                                   := 1.0;     @v16
    scrollbar_fade_in_sensitivity                           := 10.0;    @v16
    scrollbar_fade_out_delay_seconds                        := 1.0;     @v16
    status_bar_position                                     := Status_Bar_Position.bottom;                  @v4
    active_pane_border_width                                := 1.0;     @v18
    inactive_pane_dim_overlay_opacity                       := 0.1;     @v18
    comment_highlight_words1                                := "";      @v19
    comment_highlight_words2                                := "";      @v19
    comment_highlight_words3                                := "";      @v19
    comment_highlight_words4                                := "";      @v19
    enable_temporary_editors                                := true;    @v23
    cursor_position_after_jump                              := 0.45;    @v23
    closing_last_editor_in_pane_should_close_pane           := true;    @v23
    closing_last_editor_should_exit_program                 := false;   @v23
    show_pane_numbers                                       := false;   @v23
    show_tab_characters_in_selection                        := true;    @v24

    // TODO
    // load_last_session_on_start:         true

    // Settings which can be overridden in a file-specific block
    show_line_numbers                                       := false;                                               @v1  @overridable
    cursor_as_block                                         := true;                                                @v1  @overridable
    highlight_selection_occurrences                         := true;                                                @v1  @overridable
    highlight_line_with_cursor                              := false;                                               @v2  @overridable
    highlight_matching_brackets                             := false;                                               @v5  @overridable
    strip_trailing_whitespace_on_save                       := Strip_Trailing_Whitespace.except_lines_with_cursor;  @v6  @overridable
    insert_final_newline_on_save                            := false;                                               @v4  @overridable
    scroll_behind_first_line                                := false;                                               @v16 @overridable
    scroll_beyond_last_line                                 := true;                                                @v2  @overridable
    max_editor_width                                        := -1;                                                  @v1  @overridable
    line_wrap_is_on_by_default                              := false;                                               @v1  @overridable
    show_ruler_at_column                                    := 0;                                                   @v7  @overridable
    draw_indent_guides                                      := false;                                               @v2  @overridable
    auto_surround_with_brackets_and_quotes                  := false;                                               @v2  @overridable
    auto_close_brackets                                     := false;                                               @v1  @overridable
    detect_indentation                                      := true;                                                @v11 @overridable
    indent_using                                            := Indentation.spaces;                                  @v11 @overridable
    tab_size                                                := 4;                                                   @v1  @overridable
    status_bar_show_indentation                             := true;                                                @v11 @overridable
    status_bar_show_line_col                                := true;                                                @v11 @overridable
    status_bar_show_cursors_off_screen                      := true;                                                @v11 @overridable
    status_bar_show_selected_text_length                    := false;                                               @v3  @overridable
    show_scrollbar_marks                                    := true;                                                @v15 @overridable
    line_endings                                            := Line_Endings.lf;                                     @v25 @overridable
}

operator== :: (a: Settings, b: Settings) -> bool {
    #insert -> string {
        builder: String_Builder;
        for type_info(Settings).members {
            print_to_builder(*builder, "if a.%1 != b.%1  return false;\n", it.name);
        }
        return builder_to_string(*builder);
    }
    return true;
}

// Ideally we wouldn't have to do that, but Basic.array_add_if_unique is bugged right now
array_add_if_unique :: (array: *[..] Settings, item: Settings) -> added: bool, index: int {
    for array.* {
        if item == it  return false, it_index;
    }
    array_add(array, item);
    return true, array.count-1;
}

// Generate a struct for the settings that can be overridden
#insert -> string {
    b: String_Builder;
    append(*b, "Settings_Overrides :: struct {\n");

    for setting : type_info(Settings).members {
        if !array_find(setting.notes, "overridable") continue;

        type_name: string;
        if setting.type.type == {
            case .INTEGER;  type_name = "int";
            case .FLOAT;    type_name = "float";
            case .BOOL;     type_name = "bool";
            case .STRING;   type_name = "string";
            case .ENUM;     type_name = (cast(*Type_Info_Enum) setting.type).name;
            case;           compiler_report(tprint("Found an overridable setting '%' of an unsupported type", setting.name));
        }

        print_to_builder(*b, "    %: Option(%);\n", setting.name, type_name);
    }

    append(*b, "}\n");
    return builder_to_string(*b);
}

operator== :: (a: Settings_Overrides, b: Settings_Overrides) -> bool {
    #insert -> string {
        builder: String_Builder;
        for override : type_info(Settings_Overrides).members {
            print_to_builder(*builder, "if a.%1 != b.%1  return false;\n", override.name);
        }
        return builder_to_string(*builder);
    }
    return true;
}

is_overridable_setting :: (name: string) -> bool {
    setting := get_field(type_info(Settings), name);
    return array_find(setting.notes, "overridable");
}

get_overridable_setting_names :: () -> [] string /* temp */ {
    result: [..] string;
    result.allocator = temp;

    for type_info(Settings_Overrides).members {
        array_add(*result, it.name);
    }

    return result;
}

Indentation               :: enum { spaces; tabs; }
Status_Bar_Position       :: enum { bottom; top; }
Strip_Trailing_Whitespace :: enum { except_lines_with_cursor; all; disabled; }
Color_Preview_Popup       :: enum { enabled; minimized; disabled; }
Projects_Sorting_Order    :: enum { most_recent_first; alphabetical; alphabetical_no_case; }
Line_Endings              :: enum { lf; crlf; preserve; }

Font_Anti_Aliasing        :: enum { lcd; normal; }
#poke_name Simp Font_Anti_Aliasing;

File_Specific_Settings :: struct {
    match_rules: Match_Rules;
    overrides:   Settings_Overrides;

    Match_Rules :: struct {
        langs: [] Buffer.Lang;
        wildcards: [] string;
    }
}

operator== :: (a: File_Specific_Settings.Match_Rules, b: File_Specific_Settings.Match_Rules) -> bool {
    return arrays_are_equal(a.langs, b.langs) && arrays_are_equal(a.wildcards, b.wildcards);
}

operator== :: (a: File_Specific_Settings, b: File_Specific_Settings) -> bool {
    return a.match_rules == b.match_rules && a.overrides == b.overrides;
}

// We lazily populate the buffer settings cache for each thread.
// Based on our settings usage patterns it should be okay. Trying to do all this work
// upfront and share between threads would result in more complexity.
Buffer_Settings_Cache :: struct {
    table: Table(s64, Entry);
    memory_pool: Flat_Pool;

    Entry :: struct {
        settings: *Settings;
        revision: u64;
    }
}

// NOTE: pointers returned by this function will live until this thread's settings cache is cleared or destroyed.
// Do not store them anywhere.
get_settings :: (buffer: Buffer) -> *Settings {
    original := *open_buffers[buffer.id];  // use the original buffer's mutex and metadata, not the copy
    lock(*original.settings_lock);
    defer unlock(*original.settings_lock);

    found, entry := table_find(*context.buffer_settings_cache.table, buffer.id);
    if !found || entry.revision != original.settings_revision {
        // Update the cache
        entry = Buffer_Settings_Cache.Entry.{ settings = null, revision = original.settings_revision };
        resolved_settings, has_file_specific_settings := resolve_settings(context.config, original);
        if has_file_specific_settings {
            entry.settings = New(Settings,, allocator_of(*context.buffer_settings_cache.memory_pool));
            entry.settings.* = resolved_settings;
        } else {
            entry.settings = *context.config.settings;
        }
        table_set(*context.buffer_settings_cache.table, buffer.id, entry,, allocator_of(*context.buffer_settings_cache.memory_pool));
    }
    return entry.settings;
}

buffer_settings_cache_clear :: () {
    table_reset(*context.buffer_settings_cache.table);
    reset(*context.buffer_settings_cache.memory_pool);
}

buffer_settings_cache_destroy :: () {
    fini(*context.buffer_settings_cache.memory_pool);
    context.buffer_settings_cache = .{};
}

set_buffer_language :: (buffer: *Buffer, lang: Buffer.Lang) {
    lock(*buffer.settings_lock);
    if buffer.lang != lang {
        buffer.lang = lang;
        buffer.needs_tokenizing = true;
        buffer.settings_revision += 1;
    }
    unlock(*buffer.settings_lock);
}

resolve_settings :: (config: Config, buffer: *Buffer) -> Settings, has_file_specific_settings: bool {
    result := config.settings;
    has_file_specific_settings := false;

    for * config.file_specific_settings {
        if !buffer_matches_file_specific_rules(buffer, it.match_rules) continue;
        _override_settings(*result, it.overrides);
        has_file_specific_settings = true;
    }

    return result, has_file_specific_settings;
}

buffer_matches_file_specific_rules :: (buffer: *Buffer, match_rules: File_Specific_Settings.Match_Rules) -> bool {
    if array_find(match_rules.langs, buffer.lang) return true;
    if !buffer.has_file return false;

    for match_rules.wildcards {
        if path_wildcard_match(buffer.file.name, it) || path_wildcard_match(buffer.file.full_path, it) return true;
    }
    return false;
}

#scope_file

_override_settings :: (dst: *Settings, overrides: Settings_Overrides) {
    #insert -> string {
        b: String_Builder;
        for type_info(Settings_Overrides).members {
            code :: #string JAI
                if overrides.%1.is_set { dst.%1 = overrides.%1.value; }
            JAI
            print_to_builder(*b, code, it.name);
        }
        return builder_to_string(*b);
    }
}


#scope_export

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
    name:                               string;  @dontparse

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

operator== :: (a: Build_Command, b: Build_Command) -> bool {
    #insert -> string {
        builder: String_Builder;
        for type_info(Build_Command).members {
            print_to_builder(*builder, "if a.%1 != b.%1  return false;\n", it.name);
        }
        return builder_to_string(*builder);
    }
    return true;
}


#if OS == .MACOS {
    DEFAULT_CONFIG_NAME :: "default_macos.focus-config";
} else {
    DEFAULT_CONFIG_NAME :: "default.focus-config";
}
EXAMPLE_PROJECT_CONFIG_NAME :: "example-project.focus-config";

#if !NO_OUTPUT_BUILD {
    read_default_config_data :: (name: string) -> string {
        data := read_entire_file(tprint("config/%", name));
        data_with_replaced_version, occurrences := replace(data, "[0]  # Version", tprint("[%]  # Version", CURRENT_CONFIG_VERSION));
        assert(occurrences == 1, "Error when trying to replace the default config version in '%'", name);
        return data_with_replaced_version;
    }

    DEFAULT_CONFIG_FILE_DATA  :: #run read_default_config_data(DEFAULT_CONFIG_NAME);
    EXAMPLE_PROJECT_FILE_DATA :: #run read_default_config_data(EXAMPLE_PROJECT_CONFIG_NAME);

    DEFAULT_CONFIG :: #run,stallable -> Config {
        result := parse_config("Default Config", DEFAULT_CONFIG_NAME, DEFAULT_CONFIG_FILE_DATA);
        assert(result.success, "Couldn't parse the default config file '%'. Error: %", DEFAULT_CONFIG_NAME, result.error_msg);
        check_added_keybinds(result.config);
        default_config: Config;
        merge_configs(*default_config, result.config);
        // The compile-time allocator is not part of the embedded config data.
        default_config.memory_pool = null;
        return default_config;
    };

    // Validate the example project config
    #run,stallable {
        result := parse_config("Example Project Config", EXAMPLE_PROJECT_CONFIG_NAME, EXAMPLE_PROJECT_FILE_DATA);
        assert(result.success, "Couldn't parse the example project config file '%'", EXAMPLE_PROJECT_CONFIG_NAME);
    }

} else {
    DEFAULT_CONFIG_FILE_DATA :: "";
    EXAMPLE_PROJECT_FILE_DATA :: "";
    DEFAULT_CONFIG: Config;
}
