switch_to_project_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    return dialog_handle_event(*switch_to_project_dialog, event);
}

open_selected_project :: () {
    if build_command_is_running() {
        add_user_warning("A build command is currently running. Please kill it or let it finish before switching projects.", dismiss_in_seconds = 5, tag = .build);
        return;
    }

    hide_dialog(*switch_to_project_dialog);

    using switch_to_project_dialog;
    if selected >= filtered.count return;

    entry := filtered[selected];

    success := load_project_config(entry.name, force = true);
    if success {
        should_reload_workspace = true;
        automatic_workspace_reload = false;
        if unsaved_buffers_exist() {
            show_unsaved_buffers_dialog(.reload_workspace);
            should_reload_workspace = false;
        }
    } else {
        add_user_error("Couldn't load project config for %", entry.name, dismiss_in_seconds = 10, tag = .config);
    }
}

switch_to_project_dialog: Switch_To_Project_Dialog;

Switch_To_Project_Dialog :: struct {
    using #as generic_dialog: Generic_Choice_Dialog(Project_Config);
    generic_dialog.global_widget_id    = .switch_to_project_dialog;
    generic_dialog.refresh_entries     = switch_to_project_refresh_entries;
    generic_dialog.open_entry_in_place = open_selected_project;
};

#scope_file

// NOTE: assuming we're allocating from a pool
switch_to_project_refresh_entries :: (filter: Fuzzy_Filter) {
    using switch_to_project_dialog;

    project_configs: [..] Project_Config;

    visitor :: (info: *File_Visit_Info, project_configs: *[..] Project_Config) {
        if !ends_with_nocase(info.full_name, ".focus-config") return;

        full_path := copy_string(info.full_name);
        path, basename, extension, name := path_decomp(full_path);

        array_add(project_configs, Project_Config.{ name = basename, path = full_path });
    }
    visit_files(projects_dir, recursive = true, *project_configs, visitor, visit_files = true, visit_directories = false);

    for project : project_configs {
        score, highlights := fuzzy_match(project.name, filter);
        if score <= 0 && filter.full_string continue;

        entry := array_add(*filtered);
        entry.details = project;
        entry.highlights = highlights;
        entry.sort_key = cast(u64) score;
    }
}

Project_Config :: struct {
    name: string;
    path: string;
}
