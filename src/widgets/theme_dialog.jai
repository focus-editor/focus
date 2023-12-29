theme_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    return dialog_handle_event(*theme_dialog, event);
}

theme_dialog: Theme_Dialog;

Theme_Dialog :: struct {
    using #as generic_dialog: Generic_Choice_Dialog(Theme);
    generic_dialog.global_widget_id    = .theme_dialog;
    generic_dialog.refresh_entries     = theme_dialog_refresh_entries;
    generic_dialog.after_refresh       = preview_selected_theme;
    generic_dialog.open_entry_in_place = apply_selected_theme;
    generic_dialog.on_move             = preview_selected_theme;
    generic_dialog.on_show             = remember_current_theme;
    generic_dialog.on_hide             = maybe_revert_theme;
};

#scope_file

remember_current_theme :: () {
    // print("Show\n");
    print("Current theme: %\n", config.style.theme);
}

apply_selected_theme :: () {
    using theme_dialog;
    if selected >= filtered.count return;

    // Change project config if it has a style section, otherwise change global config
    config_to_change := ifx project_config.loaded && project_config.parsed_config.offsets.style_section >= 0 then *project_config else *global_config;

    buffer_id := find_or_create_buffer(config_to_change.path);
    buffer := *open_buffers[buffer_id];
    if buffer.dirty rescan_for_lines(buffer);

    // Parse the buffer again because we can't trust the offsets we remembered when we last parsed it
    result := parse_config(config_to_change.path, config_to_change.path, cast(string) buffer.bytes, for_highlighting = true /* lying */);
    offsets := result.config.offsets;  // even if it fails to parse, it's OK, the offsets might just be -1

    theme := filtered[selected];

    if offsets.theme_line >= 0 {
        // Replace theme
        line := offset_to_real_line(buffer, offsets.theme_line);
        line_end_offset := get_real_line_end_offset(buffer, line);
        replace_range(buffer, .{ cast(s32) offsets.theme_line, line_end_offset }, tprint("theme: %", theme.config_name));
    } else if offsets.style_section >= 0 {
        // Add theme to the style section
        line := offset_to_real_line(buffer, offsets.style_section);
        line_end_offset := get_real_line_end_offset(buffer, line);
        insert_string_at_offset(buffer, line_end_offset, tprint("\n\ntheme: %", theme.config_name));
    } else {
        // No style section - add at the bottom
        insert_string_at_offset(buffer, buffer.bytes.count, tprint("\n[[style]]\n\ntheme: %\n\n", theme.config_name));
    }

    rescan_for_lines(buffer);
    save_buffer(buffer, buffer_id);
    add_success_message("Theme has been saved to %", config_to_change.path);

    hide_dialog(*theme_dialog);
}

maybe_revert_theme :: () {
    reset_color_map_to_default();
    if global_config.loaded  then apply_style(global_config.parsed_config);
    if project_config.loaded then apply_style(project_config.parsed_config);
    init_fonts_and_dependent_things();
}

preview_selected_theme :: () {
    using theme_dialog;
    if !filtered || selected < 0 || selected >= filtered.count return;

    theme := filtered[selected];
    if theme.config_name == "default" {
        reset_color_map_to_default();
        init_fonts_and_dependent_things();
        return;
    }

    push_allocator(temp);
    auto_release_temp();

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
    if global_config.loaded  then apply_style(global_config.parsed_config);
    if project_config.loaded then apply_style(project_config.parsed_config);

    result.config.font = copy_string(result.config.font);  // @leak
    apply_style(result.config);
    init_fonts_and_dependent_things();
}

// NOTE: assuming we're allocating from a pool
theme_dialog_refresh_entries :: (filter: Fuzzy_Filter) {
    using theme_dialog;

    themes: [..] Theme;

    array_add(*themes, .{ name = "Default", config_name = "default", path = "" });

    visitor :: (info: *File_Visit_Info, themes: *[..] Theme) {
        if !ends_with_nocase(info.full_name, ".focus-theme") return;

        full_path := copy_string(info.full_name);
        path, basename, extension, name := path_decomp(full_path);

        name_parts := split(copy_string(basename), "-");
        for part : name_parts {
            if !part { remove part; continue; }
            part[0] = to_upper(part[0]);  // capitalize
        }

        array_add(themes, .{ name = join(..name_parts, " "), config_name = basename, path = full_path });
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
    name:        string;  // display name
    config_name: string;
    path:        string;
}

