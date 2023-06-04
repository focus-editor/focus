open_project_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    using open_project_dialog;

    if event.type == .KEYBOARD && event.key_pressed {
        action, mapping := map_event_to_action(event, Action_Open_File_Dialog);
        if action == {
            case .close_dialog;             hide_open_project_dialog();     return true;
            case .open_entry_in_place;      open_selected_project();        return true;
            case .open_entry_on_the_side;   open_selected_project();        return true;

            case .move_up;                  move_cursor(-1, wrap = true);   return true;
            case .move_down;                move_cursor( 1, wrap = true);   return true;
            case .move_up_fast;             move_cursor(-5);                return true;
            case .move_down_fast;           move_cursor( 5);                return true;
            case .move_up_one_page;         move_cursor(-per_page);         return true;
            case .move_down_one_page;       move_cursor( per_page);         return true;
        }

        handled := maybe_handle_text_input_event(*input, event);
        return handled;

    } else if event.type == .TEXT_INPUT {
        char := event.utf32;
        if char == 127 return true;  // there seems to be a bug in the Input module
                                // which generates a TEXT_INPUT event for DEL
                                // when Ctrl+Backspace is pressed

        text_input_type_char(*open_project_dialog.input, char);
        refresh_entries();
        return true;
    }
    return false;
}

show_open_project_dialog :: () {
    active_global_widget = .open_project_dialog;

    text_input_fully_clear(*open_project_dialog.input);

    refresh_entries();
}

hide_open_project_dialog :: () {
    activate_editors();
}

open_selected_project :: () {
    hide_open_project_dialog();

    using open_project_dialog;
    if selected >= filtered.count return;

    entry := filtered[selected];

    success := load_project_config(entry.name);
    if success {
        should_reload_workspace = true;
        if unsaved_buffers_exist() {
            show_unsaved_buffers_dialog(.reload_workspace);
            should_reload_workspace = false;
        }
    } else {
        add_user_error(tprint("Couldn't load project config for %", entry.name), dismiss_in_seconds = 10);
    }
}

#scope_file

refresh_entries :: () {
    using open_project_dialog;

    array_reset_keeping_memory(*filtered);

    scroll_to_cursor = .snap;
    scroll_y = 0;
    selected = 0;

    filter_chars := decode_utf8_string_to_temp_char_substrings(to_string(input.text));

    Project_Config :: struct {
        name: string;
        path: string;
    }
    project_configs: [..] Project_Config;
    project_configs.allocator = temp;

    // Get all session dirs
    visitor :: (info: *File_Visit_Info, project_configs: *[..] Project_Config) {
        if !ends_with_nocase(info.full_name, ".focus-config") return;

        full_path := copy_string(info.full_name);   // @leak: we leak project file names for now
        path, basename, extension, name := path_decomp(full_path);

        array_add(project_configs, Project_Config.{
            name = basename,
            path = full_path,
        });
    }
    visit_files(projects_dir, recursive = true, *project_configs, visitor, visit_files = true, visit_directories = false);

    for project : project_configs {
        score, highlights := fuzzy_match(project.name, filter_chars);
        if score < 0 continue;

        entry := array_add(*filtered);
        entry.name = project.name;
        entry.highlights = highlights;
        entry.sort_key = cast(u64) score;
    }

    compare_entries :: (e1: Entry, e2: Entry) -> s64 {
        key_diff := cast,no_check(s64) e2.sort_key - cast,no_check(s64) e1.sort_key;
        if key_diff != 0 return key_diff;
        return memcmp(e1.name.data, e2.name.data, min(e1.name.count, e2.name.count));
    }

    quick_sort(filtered, compare_entries);
}

move_cursor :: (delta: s64, wrap := false, snap := true) {
    using open_project_dialog;

    selected += delta;

    if wrap {
        if selected < 0 then selected = max(0, filtered.count - 1);
        if selected >= filtered.count then selected = 0;
    } else {
        if selected < 0 then selected = 0;
        if selected >= filtered.count then selected = filtered.count - 1;
    }
    scroll_to_cursor = ifx snap then Scroll_Mode.snap else .yes;
}

maybe_handle_text_input_event :: (using input: *Text_Input, event: Input.Event) -> handled: bool {
    input_text := copy_temporary_string(to_string(text));
    handled := text_input_handle_event(input, event);
    if handled {
        if input_text != to_string(input.text) then refresh_entries();
        return true;
    }
    return false;
}


#scope_export

open_project_dialog: Open_Project_Dialog;


#scope_file

Open_Project_Dialog :: struct {
    input: Text_Input;
    filtered: [..] Entry;
    selected: s64;
    selected_by_mouse: s64 = -1;  // to remember which entry the left mouse button went down on

    scroll_y: s32;
    scroll_anim := #run Tween_Animation(s32).{ speed = xx 0.1, func = .lerp };
    per_page: s64 = 10;

    scroll_to_cursor: Scroll_Mode = .no;
};

Entry :: struct {
    name: string;
    highlights: [] bool;
    sort_key: u64;
}
