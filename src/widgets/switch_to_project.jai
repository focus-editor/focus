switch_to_project_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    return dialog_handle_event(*switch_to_project_dialog, event);
}

switch_to_project_dialog: Switch_To_Project_Dialog;

Switch_To_Project_Dialog :: struct {
    using #as generic_dialog: Generic_Choice_Dialog(Project_Config);
    generic_dialog.global_widget_id = .switch_to_project_dialog;
    generic_dialog.refresh_entries  = switch_to_project_refresh_entries;
    generic_dialog.open_entry       = open_selected_project;
};


#scope_file

open_selected_project :: (_: Editor_Placement) {
    hide_dialog(*switch_to_project_dialog);

    using switch_to_project_dialog;
    if selected >= filtered.count return;

    entry := filtered[selected];

    defer_action_switch_to_project(entry.path);
}

switch_to_project_refresh_entries :: (filter: Fuzzy_Filter) {
    using switch_to_project_dialog;

    assert(context.allocator.proc == flat_pool_allocator_proc, "Non-pool allocator is used in switch_to_project dialog. This is a bug.");

    project_configs: [..] Project_Config;

    _entry_from_path :: (project_path: string) -> Project_Config {
        full_path := copy_string(project_path);
        config_parent_dir, basename, extension, name := path_decomp(full_path);
        config_parent_dir = trim_right(config_parent_dir, "/");
        if !extension {
            // For `.focus-config` files, derive the name from the parent dir
            _, basename, extension, name = path_decomp(config_parent_dir);
            basename = name;  // don't strip away any "extensions" from the dir
        }
        if platform_path_equals(config_parent_dir, projects_dir) then config_parent_dir = "";  // don't specify path for standard projects
        return Project_Config.{ name = basename, path = full_path, config_parent_dir = config_parent_dir };
    }

    // Load the list of most recent projects
    for get_most_recent_projects()  array_add(*project_configs, _entry_from_path(it));

    // Load the list of projects from the global projects dir
    visitor :: (info: *File_Visit_Info, project_configs: *[..] Project_Config) {
        if !ends_with_nocase(info.full_name, ".focus-config") return;
        array_add_if_unique(project_configs, _entry_from_path(info.full_name));

    }
    visit_files(projects_dir, recursive = true, *project_configs, visitor, visit_files = true, visit_directories = false);

    if #complete config.settings.projects_sorting_order == {
        case .most_recent_first;
            // already sorted this way

        case .alphabetical;
            quick_sort(project_configs, (a, b) => compare_alphabetically(a.name, b.name, false));

        case .alphabetical_no_case;
            quick_sort(project_configs, (a, b) => compare_alphabetically(a.name, b.name, true));
    }

    for project : project_configs {
        score, highlights := fuzzy_match(project.name, filter);
        if score <= 0 && filter.full_string continue;

        entry := array_add(*filtered);
        entry.details = project;
        entry.highlights = highlights;
        entry.sort_key = cast(u64) (score + project_configs.count - it_index);  // sort by the list order originally
    }
}

// Order:
//     1. symbols
//     2. digits
//     3. letters
compare_alphabetically :: (a : string, b : string, $no_case : bool) -> s64 {
    // We do not care about length in the first place
    min_length := min(a.count, b.count);
    for 0 .. min_length - 1 {
        a_u8 : u8 = a[it];
        b_u8 : u8 = b[it];

        a_is_capital := #char "A" <= a_u8 && a_u8 <= #char "Z";
        b_is_capital := #char "A" <= b_u8 && b_u8 <= #char "Z";

        a_is_symbol := !(a_is_capital || (#char "a" <= a_u8 && a_u8 <= #char "z") || (#char "0" <= a_u8 && a_u8 <= #char "9"));
        b_is_symbol := !(b_is_capital || (#char "a" <= b_u8 && b_u8 <= #char "z") || (#char "0" <= b_u8 && b_u8 <= #char "9"));

        // first symbols
        if a_is_symbol {
            if !b_is_symbol return -1;

            a_s64 : s64 = a_u8;
            b_s64 : s64 = b_u8;

            diff := a_s64 - b_s64;
            if diff return diff;

            // both are same symbols, go to the next character
            continue;
        }
        if b_is_symbol return 1;

        // digits goes before letters, so we do not break the order
        a_s64 : s64 = a_u8;
        b_s64 : s64 = b_u8;
        #if no_case {
            if a_is_capital then a_s64 += #char "a" - #char "A";
            if b_is_capital then b_s64 += #char "a" - #char "A";
        }

        diff := a_s64 - b_s64;
        if diff return diff;
    }

    // first goes shorter one
    return a.count - b.count;
}

Project_Config :: struct {
    name: string;
    path: string;
    config_parent_dir: string;
}

operator== :: (a: Project_Config, b: Project_Config) -> bool {
    return platform_path_equals(a.path, b.path);
}

#poke_name Basic operator==;
