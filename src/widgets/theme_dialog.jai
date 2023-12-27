theme_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    return dialog_handle_event(*theme_dialog, event);
}

apply_selected_theme :: () {
    // hide_dialog(*theme_dialog);

    // using theme_dialog;
    // if selected >= filtered.count return;

    // command := filtered[selected].details;
    // for * commands { if command.action == it.action { it.num_times_used += 1; break; } }

    // if command.action == .do_nothing return;

    // handled := handle_common_editor_action(command.action, placement);
    // if !handled {
    //     editor, buffer := get_active_editor_and_buffer();
    //     if editor then active_editor_handle_event(editor, buffer, Input.Event.{}, command.action);
    // }
}

theme_dialog: Theme_Dialog;

Theme_Dialog :: struct {
    using #as generic_dialog: Generic_Choice_Dialog(Theme);
    generic_dialog.global_widget_id    = .theme_dialog;
    generic_dialog.refresh_entries     = theme_dialog_refresh_entries;
    generic_dialog.open_entry_in_place = apply_selected_theme;
    generic_dialog.on_move             = preview_selected_theme;
    generic_dialog.on_show             = remember_current_theme;
    generic_dialog.on_hide             = maybe_revert_theme;
};

#scope_file

remember_current_theme :: () {
    print("Show\n");
}

maybe_revert_theme :: () {
    reset_color_map_to_default();
    if global_config.loaded  then apply_style(*config.style, global_config.parsed_config);
    if project_config.loaded then apply_style(*config.style, project_config.parsed_config);
    init_fonts_and_dependent_things();
}

preview_selected_theme :: () {
    using theme_dialog;
    if !filtered || selected < 0 || selected >= filtered.count return;

    // push_allocator(temp);  // TODO: re-enable and copy things that need to live longer

    theme := filtered[selected];
    if !theme.path {
        // Custom theme
        reset_color_map_to_default();
        if global_config.loaded  then apply_style(*config.style, global_config.parsed_config);
        if project_config.loaded then apply_style(*config.style, project_config.parsed_config);
        init_fonts_and_dependent_things();
        return;
    }

    // We read and parse files each time without caching anything because we want flexibility and because it's cheap
    file_data, success := read_entire_file(theme.path);
    if !success {
        add_user_error("Couldn't read theme file '%'", theme.path);
        return;
    }

    migrated, new_file_data := maybe_migrate_config(theme.path, file_data, assume_section = "style");
    if migrated {
        success := write_entire_file(theme.path, new_file_data);
        if !success then add_user_error("We migrated theme file '%' to version [%],\nbut could't save the file. Is it writable?", theme.path, CURRENT_CONFIG_VERSION);
        file_data = new_file_data;
    }

    result := parse_config(theme.name, theme.path, file_data, as_theme = true);
    if !result.success {
        add_user_error("Couldn't parse theme file '%'.\nError: %", theme.path, result.error_msg);
        return;
    }

    reset_color_map_to_default();
    if global_config.loaded  then apply_style(*config.style, global_config.parsed_config);
    if project_config.loaded then apply_style(*config.style, project_config.parsed_config);
    apply_style(*config.style, result.config);
    init_fonts_and_dependent_things();
}

// NOTE: assuming we're allocating from a pool
theme_dialog_refresh_entries :: (filter: Fuzzy_Filter) {
    using theme_dialog;

    themes: [..] Theme;

    array_add(*themes, .{ name = "Custom", path = "" });

    visitor :: (info: *File_Visit_Info, themes: *[..] Theme) {
        if !ends_with_nocase(info.full_name, ".focus-theme") return;

        full_path := copy_string(info.full_name);
        path, basename, extension, name := path_decomp(full_path);

        name_parts := split(copy_string(basename), "-");
        for part : name_parts {
            if !part { remove part; continue; }
            part[0] = to_upper(part[0]);  // capitalize
        }

        array_add(themes, .{ name = join(..name_parts, " "), path = full_path });
    }
    visit_files(themes_dir, recursive = false, *themes, visitor, visit_files = true, visit_directories = false);

    for theme : themes {
        score, highlights := fuzzy_match(theme.name, filter);
        if score <= 0 && filter.full_string continue;

        entry := array_add(*filtered);
        entry.details = theme;
        entry.highlights = highlights;
        entry.sort_key = cast(u64) score;
    }
}

Theme :: struct {
    name: string;
    path: string;
}

