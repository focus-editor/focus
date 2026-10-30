theme_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    return dialog_handle_event(*theme_dialog, event);
}

theme_dialog: Theme_Dialog;

Theme_Dialog :: struct {
    using #as generic_dialog: Generic_Choice_Dialog(Theme);
    generic_dialog.global_widget_id = .theme_dialog;
    generic_dialog.refresh_entries  = theme_dialog_refresh_entries;
    generic_dialog.after_refresh    = preview_selected_theme;
    generic_dialog.open_entry       = apply_selected_theme;
    generic_dialog.on_move          = preview_selected_theme;
};

edit_current_theme :: (placement: Editor_Placement) {
    if !context.config.style.theme {
        add_user_warning("No theme is currently active");
        return;
    }
    if context.config.style.theme == "default" {
        add_user_warning("Default theme is active. It's immutable.\nIf you want to edit it, copy [colors] from the default config and adjust them.");
        editors_show_default_config(placement);
        return;
    }
    theme_path := get_theme_path_from_name(context.config.style.theme);
    editors_open_file(theme_path, placement);
}

edit_current_theme :: (pane: *Editor_Pane) {
    if !pane return;

    if !context.config.style.theme {
        add_user_warning("No theme is currently active");
        return;
    }
    if context.config.style.theme == "default" {
        add_user_warning("Default theme is active. It's immutable.\nIf you want to edit it, copy [colors] from the default config and adjust them.");
        editors_show_default_config(pane);
        return;
    }
    theme_path := get_theme_path_from_name(context.config.style.theme);
    editors_open_file_in_pane(theme_path, pane);
}

maybe_revert_temporary_theme :: () {
    if temporary_theme && active_global_widget != .theme_dialog {
        revert_temporary_theme();
    }
}

revert_temporary_theme :: () {
    apply_style(context.config.style);
    set_temporary_theme("");
}

get_theme_path_from_name :: (name: string) -> string /* temp */ {
    theme_name := to_lower_copy(name,, temp);
    return tprint("%/%.focus-theme", themes_dir, theme_name);
}

#scope_file

set_temporary_theme :: (theme_name: string) {
    free(temporary_theme,, allocator = focus_allocator);
    temporary_theme = copy_string(theme_name,, allocator = focus_allocator);
}

get_last_config_with_style :: () -> *Loaded_Config {
    return ifx project_config.loaded && project_config.parsed_config.offsets.style_section >= 0 then *project_config else *global_config;
}

apply_selected_theme :: (_: Editor_Placement) {
    using theme_dialog;
    if selected < 0 || selected >= filtered.count return;

    theme := filtered[selected];

    // Verify the theme is okay
    theme_result := load_theme(theme.config_name, path = theme.path, save_migration = false,, temp);
    if !theme_result.success {
        add_user_error(theme_result.error_msg);
        return;
    }

    config_to_change := get_last_config_with_style();

    buffer_id := find_or_create_buffer(config_to_change.path);
    buffer := *open_buffers[buffer_id];
    if buffer.dirty rescan_for_lines(buffer);
    if buffer.readonly {
        add_user_error("Can't modify config '%' because it's read-only", config_to_change.path);
        return;
    }

    // Parse the buffer again because we can't trust the offsets we remembered when we last parsed it
    result := parse_config(config_to_change.path, config_to_change.path, to_string(buffer.bytes), for_highlighting = true /* lying */,, allocator = temp);
    offsets := result.config.offsets;  // even if it fails to parse, it's OK, the offsets might just be -1

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
    saved := save_buffer(buffer);
    if saved {
        add_success_message("Theme has been saved to %", config_to_change.path);
        hide_dialog(theme_dialog);
    } else {
        add_user_error("Couldn't save theme to %", config_to_change.path);
    }
}

preview_selected_theme :: () {
    using theme_dialog;
    if !filtered || selected < 0 || selected >= filtered.count {
        revert_temporary_theme();
        return;
    }

    auto_release_temp();
    push_allocator(temp);

    theme := filtered[selected];

    set_temporary_theme(theme.config_name);

    theme_result := load_theme(theme.config_name, path = theme.path, save_migration = false);

    if !theme_result.success {
        add_user_error(theme_result.error_msg);
        revert_temporary_theme();
        return;
    }

    // Construct a temporary style
    style := DEFAULT_CONFIG.style;

    target_config := get_last_config_with_style();

    if global_config.loaded {
        parsed_config := global_config.parsed_config;
        if target_config == *global_config {
            parsed_config.theme  = theme.config_name;
            parsed_config.colors = theme_result.config.colors;
        }
        merge_style(*style, parsed_config);
    }
    if project_config.loaded {
        parsed_config := project_config.parsed_config;
        if target_config == *project_config {
            parsed_config.theme  = theme.config_name;
            parsed_config.colors = theme_result.config.colors;
        }
        merge_style(*style, parsed_config);
    }

    apply_style(style);
}

theme_dialog_refresh_entries :: (filter: Fuzzy_Filter) {
    using theme_dialog;

    assert(context.allocator.proc == flat_pool_allocator_proc, "Non-pool allocator is used in theme dialog. This is a bug.");

    themes: [..] Theme;

    array_add(*themes, .{ name = "Default", config_name = "default", path = "" });

    visitor :: (info: *File_Visit_Info, themes: *[..] Theme) {
        if !ends_with_nocase(info.full_name, ".focus-theme") return;

        full_path := copy_string(info.full_name);
        path, basename, extension, name := path_decomp(full_path);

        name_parts := split(copy_string(basename), "-",, allocator = temp);
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

        // Sort our current theme on top when we first open the dialog
        if !filter.full_string && theme.config_name == context.config.style.theme then entry.sort_key |= cast(u64) 1 << 62;
    }
}

Theme :: struct {
    name:        string;  // display name
    config_name: string;
    path:        string;
}

temporary_theme: string;

