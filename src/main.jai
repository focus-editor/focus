main :: () {
    #if DEBUG && OS != .LINUX {
        UA :: #import "Unmapping_Allocator";
        context.allocator = UA.get_unmapping_allocator();
    }

    focus_allocator = context.allocator;  // to be used as a default allocator where we need it

    cpu_info = get_cpu_info();

    // Meow hash relies on AES instruction support, so fall back to a standard hash function
    if !check_feature(cpu_info.feature_leaves, x86_Feature_Flag.AES) then calculate_hash = fallback_hash;

    platform_setup();

    // Remember important directories
    config_dir = platform_config_dir();
    data_dir   = platform_data_dir();
    assert(config_dir.count > 0, "Empty config dir");
    assert(!ends_with(config_dir, "/"), "Config dir '%' ends with a '/'. This is a bug.", config_dir);
    assert(data_dir.count > 0, "Empty data dir");
    assert(!ends_with(data_dir, "/"), "Data dir '%' ends with a '/'. This is a bug.", data_dir);
    platform_get_fonts_dir();  // warm-up the fonts dir so that the config highlighter can later use it without heap allocations

    temp_dir     = sprint("%/temp",     data_dir);
    projects_dir = sprint("%/projects", config_dir);
    themes_dir   = sprint("%/themes",   config_dir);

    projects_dir_existed := file_exists(projects_dir);

    if !make_directory_if_it_does_not_exist(projects_dir) then panic_messagebox("Couldn't create folder %. Is the directory writable?", projects_dir);
    if !make_directory_if_it_does_not_exist(temp_dir)     then panic_messagebox("Couldn't create folder % for temporary files. Is the directory writable?", temp_dir);
    if !make_directory_if_it_does_not_exist(themes_dir)   then panic_messagebox("Couldn't create folder % for themes. Is the directory writable?", themes_dir);
    if !projects_dir_existed then write_entire_file(tprint("%/Example Project.focus-config", projects_dir), EXAMPLE_PROJECT_FILE_DATA);

    fill_in_missing_default_themes();

    init_file_watcher();
    defer deinit_file_watcher();

    init_buffers();
    load_global_config(fallback_to_default_on_failure = true);

    window_x, window_y, window_width, window_height = platform_get_centered_window_dimensions(config.settings.open_on_the_biggest_monitor);

    if config.settings.window_width  > 0 then window_width  = xx config.settings.window_width;
    if config.settings.window_height > 0 then window_height = xx config.settings.window_height;
    if config.settings.window_x != -1000 then window_x      = xx config.settings.window_x;
    if config.settings.window_y != -1000 then window_y      = xx config.settings.window_y;

    window_generic_title = ifx DEBUG then "Focus (debug mode)" else "Focus";
    platform_create_window();

    // Process command line parameters
    focus_executable_args = get_command_line_arguments();

    args := focus_executable_args;
    if args.count == 3 && args[1] == "-project" {
        // - `focus.exe -project "Project Name"` or `focus.exe -project <path/to/project>` will load a project. No other arguments are allowed.
        project := args[2];
        success: bool;
        if ends_with(project, ".focus-config") {
            success = load_project_config(project);
        } else {
            config_path := tprint("%/%.focus-config", projects_dir, project);
            success = load_project_config(config_path);
        }
        if !success then add_user_error("Couldn't load project config '%' provided in the command line arguments", project);
    }
    else if args.count >= 2 {
        // - `focus.exe <path1> <path2> ...` will open files or add directories to the workspace
        dirs_from_args: [..] string;
        dirs_from_args.allocator = temp;

        for path : array_view(args, 1, args.count - 1) {
            if is_directory(path) {
                dir := trim_right(path, "\\/");
                project_config_path := tprint("%/.focus-config", dir);
                if !project_config.loaded && file_exists(project_config_path) {
                    success := load_project_config(project_config_path);
                    if !success then add_user_error("Tried to load project config from % but couldn't due to errors", project_config_path);
                } else {
                    array_add(*dirs_from_args, dir);
                }
            } else if file_exists(path) {
                editors_open_file(path);
            } else {
                if path == "-project" {
                    add_user_error("The '-project' command line argument is used incorrectly.\nCorrect usage: focus -project <project name or path>.\nNo other arguments are allowed in this case.");
                } else if starts_with(path, "-") {
                    add_user_error("Invalid command line parameter '%'.", path);
                } else {
                    add_user_error("Invalid command line parameter '%'.\nAttempted to load it as a file or a directory, but it doesn't exist.", path);
                }
            }
        }

        for < dir : dirs_from_args  add_directory_to_workspace(dir, index = 0);
    }

    // Maybe load project from a .focus-config file in the current directory
    if !project_config.loaded {
        if file_exists(".focus-config") {
            project_config_path, success := get_absolute_path(".focus-config",, temp);
            if success {
                success := load_project_config(project_config_path);
                if !success then add_user_error("Tried to load project config from % but couldn't due to errors", project_config_path);
            }
        }
    }

    if !project_config.loaded && !project_dirs {
        session = maybe_load_previous_session();

        // Maybe load most recent project
        if config.settings.load_most_recent_project_on_start {
            most_recent_projects := get_most_recent_projects();
            if most_recent_projects {
                success := load_project_config(most_recent_projects[0]);
                if !success then add_user_error("Couldn't load most recent project '%'", most_recent_projects[0]);
            }
        }
    } else {
        session = start_fresh_session();
    }

    if project_config.loaded then update_window_title();

    init_workspace();
    init_build_system();

    // This may generate window resize events if DPI/scaling settings need to be
    // applied, so make sure to only call it after the window is created.
    platform_apply_config();
    Simp.set_color_map(COLOR_MAP);

    #if OS == .MACOS {
        // On macOS, attempting to maximize the window before a frame has been drawn results in a crash, so we delay it until the end of the first frame.
        should_maximize := config.settings.maximize_on_start;
    } else {
        if config.settings.maximize_on_start then platform_maximize_window(window);
    }
    #if OS == .WINDOWS {
        // A hacky workaround to display the dark title bar properly. Nothing else we've tried worked
        if config.settings.dark_titlebar && !config.settings.maximize_on_start {
            ShowWindow(window, SW_HIDE);
            ShowWindow(window, SW_SHOW);
        }
    }

    platform_enable_drag_and_drop(window);

    window_width, window_height = Simp.get_render_dimensions(window);
    screen = make_rect(0, 0, window_width, window_height);
    Simp.set_render_target(window);

    // Init logger after we know the session dir and the config
    init_logger();
    defer deinit_logger();  // closes log file handles

    if !check_feature(cpu_info.feature_leaves, x86_Feature_Flag.AES) then log_error("CPU doesn't support AES instructions. A slower hash function will be used.");

    // Requires the session to be created and the configs to be loaded
    start_workspace_scan();

    dpi_scale = platform_get_dpi_scale(window);
    init_fonts_and_dependent_things();
    old_line_height = line_height;

    window_has_focus := true;
    window_resized   := false;

    shift_key: struct {
        last_press:   Apollo_Time = #run to_apollo(-1);
        last_release: Apollo_Time = #run to_apollo(-1);
        press_count := 0;
    };

    while true {
        if !redraw_requested platform_wait_message();

        Input.update_window_events();

        current_time := current_time_monotonic();
        frame_dt   = min(to_float64_seconds(current_time - frame_time), MAX_FRAME_DT);
        frame_time = current_time;
        frame_time64 = to_float64_seconds(frame_time);

        old_line_height = line_height;
        for Input.get_window_resizes() {
            Simp.update_window(it.window);
            if (it.window == window) {
                should_reinit := dont_ignore_next_window_resize || ((it.width != window_width) || (it.height != window_height));
                window_width = it.width;
                window_height = it.height;
                if should_reinit {
                    // Cleanup: revisit this code, it's been touched by multiple people and needs simplification
                    screen    = make_rect(0, 0, window_width, window_height);
                    dpi_scale = platform_get_dpi_scale(window);
                    init_fonts_and_dependent_things();
                    dont_ignore_next_window_resize = false;
                }
                window_resized = true;
            }
        }

        // Don't do anything when window is resized to a size that's too small
        if window_width < MIN_WINDOW_WIDTH || window_height < MIN_WINDOW_HEIGHT continue;

        update_mouse_state();

        redraw_requested = false;
        window_resized   = false;
        dont_scroll_this_frame = false;
        window_has_focus = Input.input_application_has_focus;  // so that we always redraw when the window first loses focus

        workspace_update();
        finder_update();

        for * editor : open_editors {
            using editor;
            cursor_moved = .has_not_moved;
            if old_line_height != line_height {
                // Adjust viewport position
                lines_scrolled := viewport.top / old_line_height;
                viewport.scroll_y.target = xx (lines_scrolled * line_height);
                viewport.top = viewport.scroll_y.target;
            }
        }

        // Keyboard and text input events may be generated for the same keypress.
        // If we handle it as a keyboard event we will need to ignore its text input duplicates
        num_text_input_events_to_ignore := 0;

        for event : Input.events_this_frame {
            // General events
            if event.type == {
                case .QUIT;
                    defer_action_quit();

                case .KEYBOARD;
                    // Double shift click
                    if config.settings.double_shift_to_search_in_workspace && event.key_code == .SHIFT {
                        using shift_key;
                        if !event.key_pressed then last_release = frame_time;
                        if event.key_pressed && only_shift_pressed(event.modifier_flags) {
                            if last_press < last_release && press_count > 0 && to_float64_seconds(frame_time - last_press) < 0.2 {
                                if finder_is_open() then finder_close();
                                else finder_open_from_editor();
                                press_count = 0;
                            } else {
                                press_count = 1;
                            }
                            last_press = frame_time;
                        }
                        if event.key_pressed then last_press = frame_time;
                    }

                case .MOUSE_V_WHEEL;
                    #if OS != .MACOS {
                        if ctrl_or_cmd_pressed() {
                            if event.wheel_delta < 0  {
                                decrease_font_size();
                                dont_scroll_this_frame = true;
                            } else if event.wheel_delta > 0 {
                                increase_font_size();
                                dont_scroll_this_frame = true;
                            }
                        }
                    }
                case .DRAG_AND_DROP_FILES;
                    editors_handle_file_drop(event.files);
                case .TEXT_INPUT;
                    if num_text_input_events_to_ignore {
                        num_text_input_events_to_ignore -= 1;
                        continue;
                    }
            }

            // Maybe handle a common action that applies to all widgets
            handled := false;

            // Pass events to the active widget.
            // Note that the active widget may change during the frame, so the following events
            // will be sent to the new widget, that's why we check global widget for each event.
            if #complete active_global_widget == {
                case .editors;                      handled = editors_handle_event(event);
                case .finder;                       handled = finder_handle_event(event);
                case .open_file_dialog;             handled = open_file_dialog_handle_event(event);
                case .delete_file_dialog;           handled = dialog_handle_event(*delete_file_dialog, event);
                case .go_to_line_dialog;            handled = go_to_line_dialog_handle_event(event);
                case .switch_to_project_dialog;     handled = switch_to_project_dialog_handle_event(event);
                case .unsaved_buffers_dialog;       handled = dialog_handle_event(*unsaved_buffers_dialog, event);
                case .confirm_overwrite_dialog;     handled = dialog_handle_event(*confirm_overwrite_dialog, event);
                case .commands_dialog;              handled = dialog_handle_event(*commands_dialog, event);
                case .kill_running_command_dialog;  handled = dialog_handle_event(*kill_running_command_dialog, event);
                case .theme_dialog;                 handled = theme_dialog_handle_event(event);
                case .language_dialog;              handled = language_dialog_handle_event(event);
            }

            if !handled {
                action := map_event_to_action(event, Action_Editors);
                handled = handle_common_editor_action(action);
            }
            if !handled {
                action := map_event_to_action(event, Action_Build);
                handled = maybe_execute_a_build_command(action);
            }

            if handled && event.type == .KEYBOARD then num_text_input_events_to_ignore = event.text_input_count;
            #if OS == .MACOS {
                // @Hack:
                // On macOS the shortcut Cmd-Q seems to be handled by the system.
                // If the user presses Cmd-Q, we first get a normal .KEYBOARD and a .TEXT_INPUT events, then a .QUIT event.
                // Since we're not handling the .KEYBOARD event, we're not ignoring the following .TEXT_INPUT, which
                // sometimes results in the letter q being pressed.
                // Unless there's a good simple way to avoid that we have to filter it out ourselves
                if event.type == .KEYBOARD && event.key_code == #char "Q" && event.key_pressed && event.cmd_meta_pressed then num_text_input_events_to_ignore += 1;
            }

            key_sequence_input_process_event(event, handled);
        }

        execute_deferred_actions();

        build_system_update();
        maybe_revert_temporary_theme();
        refresh_open_buffers();

        draw_frame();

        pointer_end_frame();

        maybe_save_editor_history();

        reset_temporary_storage();

        #if OS == .MACOS {
            if should_maximize {
                should_maximize = false;
                platform_maximize_window(window);
            }
        }

        // #if DEBUG FrameMark();

        if should_quit break;

        if to_float64_seconds(current_time_monotonic() - frame_time) <= QUICK_FRAME_DT {
            // It should be ok to sleep a bit after a quick frame to avoid pegging the core.
            sleep_milliseconds(2);
        }
    }

    #if DEBUG_MEMORY_LEAKS {
        log("========= LEAK REPORT =========\n");
        report := make_leak_report();
        log_leak_report(report);
        log("========= END OF REPORT =======\n");
    }
}

handle_common_editor_action :: (action: Action_Editors, placement: Editor_Placement = .in_place) -> handled: bool {
    if action == {
        case .quit;                                             defer_action_quit();                                return true;

        case .open_another_editor_instance;                     open_another_editor_instance();                     return true;

        case .increase_font_size;                               increase_font_size();                               return true;
        case .decrease_font_size;                               decrease_font_size();                               return true;
        case .reset_font_size_to_default;                       reset_font_size_to_default();                       return true;

        case .open_project;                                     print("UNIMPLEMENTED\n");  /* !!!!!!!!!!!! */       return true;
        case .switch_to_project;                                show_dialog(*switch_to_project_dialog);             return true;
        case .close_project;                                    close_project();                                    return true;

        case .choose_theme;                                     show_dialog(*theme_dialog);                         return true;
        case .edit_current_theme;                               edit_current_theme(placement);                      return true;

        case .open_projects_directory;                          platform_open_in_explorer(projects_dir);            return true;
        case .open_global_config;                               editors_open_global_config(placement);              return true;
        case .open_project_config;                              editors_open_project_config(placement);             return true;
        case .show_default_config;                              editors_show_default_config(placement);             return true;
        case .show_troubleshooting_info;                        editors_show_troubleshooting_info(placement);       return true;

        case .go_to_line;                                       show_go_to_line_dialog();                           return true;
        case .create_new_file;                                  editors_create_new_file(placement);                 return true;
        case .create_new_file_on_the_side;                      editors_create_new_file(.on_the_side);              return true;

        case .go_to_next_build_error;                           go_to_next_build_error(.in_place);                  return true;
        case .go_to_next_build_error_on_the_side;               go_to_next_build_error(.on_the_side);               return true;
        case .go_to_previous_build_error;                       go_to_previous_build_error(.in_place);              return true;
        case .go_to_previous_build_error_on_the_side;           go_to_previous_build_error(.on_the_side);           return true;

        case .open_file_by_name;                                show_open_file_dialog(.search);                     return true;
        case .navigate_to_file;                                 show_open_file_dialog(.navigate);                   return true;
        case .navigate_to_file_from_root;                       show_open_file_dialog(.navigate, from_root = true); return true;
        case .switch_between_open_files;                        show_open_file_dialog(.open_editors);               return true;

        case .show_commands;                                    show_dialog(*commands_dialog);                      return true;
        case .toggle_fullscreen;                                editor_toggle_fullscreen();                         return true;

        case .move_to_previous_editor_history;                  move_to_previous_editor_history();                  return true;
        case .move_to_next_editor_history;                      move_to_next_editor_history();                      return true;

        case .move_to_previous_buffer;                          move_to_previous_editor_history(by_buffer = true);  return true;
        case .move_to_next_buffer;                              move_to_next_editor_history    (by_buffer = true);  return true;

        case .toggle_build_panel;                               toggle_build_panel();                               return true;

        case .build_kill_running_command;                       build_kill_running_command();                       return true;
        case .build_clear_output;                               build_clear_output();                               return true;

        // TODO: search_in_buffer
        case .search_in_project;
            if active_global_widget == .editors then finder_open_from_editor(); else finder_open();                 return true;
    }
    return false;
}

maybe_execute_a_build_command :: (action: Action_Build) -> handled: bool {
    if action == INVALID_KEYMAP_ACTION return false;

    command_id := cast(s64) action;
    assert(command_id <= config.build.commands.count, "A keymap was bound to a nonexistent build command %. Number of build commands: %. This is a bug", command_id, config.build.commands.count);

    if config.settings.save_all_file_backed_buffers_on_build {
        for * buffer, buffer_id : open_buffers {
            if buffer.modified && buffer.has_file {
                save_buffer(buffer, buffer_id);
            }
        }
    } else if config.settings.save_current_buffer_on_build {
        editor, buffer := get_active_editor_and_buffer();
        if editor && buffer.has_file save_buffer(buffer, editor.buffer_id);
    }

    defer_action_build_command(command_id);

    return true;
}

init_fonts_and_dependent_things :: () {
    push_allocator(focus_allocator);  // we sometimes call this from within a temp allocator

    font_size = clamp(font_size, MIN_FONT_SIZE, MAX_FONT_SIZE);
    delta := font_size - DEFAULT_FONT_SIZE;
    font_ui_size            = clamp(DEFAULT_FONT_UI_SIZE            + delta, MIN_FONT_SIZE, MAX_FONT_SIZE);
    font_ui_big_size        = clamp(DEFAULT_FONT_UI_BIG_SIZE        + delta, MIN_FONT_SIZE, MAX_FONT_SIZE);
    font_ui_medium_size     = clamp(DEFAULT_FONT_UI_MEDIUM_SIZE     + delta, MIN_FONT_SIZE, MAX_FONT_SIZE);
    font_ui_small_size      = clamp(DEFAULT_FONT_UI_SMALL_SIZE      + delta, MIN_FONT_SIZE, MAX_FONT_SIZE);
    font_ui_very_small_size = clamp(DEFAULT_FONT_UI_VERY_SMALL_SIZE + delta, MIN_FONT_SIZE, MAX_FONT_SIZE);
    font_icons_size         = clamp(DEFAULT_FONT_ICONS_SIZE         + delta, MIN_FONT_SIZE, MAX_FONT_SIZE);
    font_icons_small_size   = clamp(DEFAULT_FONT_ICONS_SMALL_SIZE   + delta, MIN_FONT_SIZE, MAX_FONT_SIZE);
    font_icons_tiny_size    = clamp(DEFAULT_FONT_ICONS_TINY_SIZE    + delta, MIN_FONT_SIZE, MAX_FONT_SIZE);

    font = Simp.get_font_at_size(main_font_name, main_font_data, cast(int) (font_size * dpi_scale));
    assert(font != null, "Couldn't init main text font\n");

    font_ui = Simp.get_font_at_size(FONT_UI.name, FONT_UI.data, cast(int) (font_ui_size * dpi_scale));
    assert(font_ui != null, "Couldn't init main ui font\n");
    font_ui_line_height = cast(float) font_ui.default_line_spacing;

    font_ui_big = Simp.get_font_at_size(FONT_UI.name, FONT_UI.data, cast(int) (font_ui_big_size * dpi_scale));
    assert(font_ui_big != null, "Couldn't init big ui font\n");
    font_ui_big_line_height = cast(float) font_ui_big.default_line_spacing;

    font_ui_medium = Simp.get_font_at_size(FONT_UI.name, FONT_UI.data, cast(int) (font_ui_medium_size * dpi_scale));
    assert(font_ui_medium != null, "Couldn't init medium ui font\n");
    font_ui_medium_line_height = cast(float) font_ui_medium.default_line_spacing;

    font_ui_bold = Simp.get_font_at_size(FONT_UI_BOLD.name, FONT_UI_BOLD.data, cast(int) (font_ui_size * dpi_scale));
    assert(font_ui_bold != null, "Couldn't init bold ui font\n");

    font_ui_small = Simp.get_font_at_size(FONT_UI.name, FONT_UI.data, cast(int) (font_ui_small_size * dpi_scale));
    assert(font_ui_small != null, "Couldn't init small ui font\n");

    font_ui_very_small = Simp.get_font_at_size(FONT_UI.name, FONT_UI.data, cast(int) (font_ui_very_small_size * dpi_scale));
    assert(font_ui_very_small != null, "Couldn't init small ui font\n");

    font_icons = Simp.get_font_at_size(FONT_ICONS.name, FONT_ICONS.data, cast(int) (font_icons_size * dpi_scale));
    assert(font_icons != null, "Couldn't init main icon font\n");

    font_icons_small = Simp.get_font_at_size(FONT_ICONS.name, FONT_ICONS.data, cast(int) (font_icons_small_size * dpi_scale));
    assert(font_icons_small != null, "Couldn't init main icon font\n");

    font_icons_tiny = Simp.get_font_at_size(FONT_ICONS.name, FONT_ICONS.data, cast(int) (font_icons_tiny_size * dpi_scale));
    assert(font_icons_tiny != null, "Couldn't init tiny icon font\n");

    // WORKAROUND:
    // Make a dummy call with most common chars for each font so that
    // we have all the font atlases loaded in the GPU memory once
    // (TODO: maybe there's an easy way for Simp to only update textures on flush?)
    COMMON_CHARS :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789… ~!@#$%^&*()-|\"':;_+={}[]\\/`,.<>?АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчщъыьэюя¶•";
    Simp.prepare_text(font,             COMMON_CHARS);
    Simp.prepare_text(font_ui,          COMMON_CHARS);
    Simp.prepare_text(font_ui_bold,     COMMON_CHARS);
    Simp.prepare_text(font_ui_small,    COMMON_CHARS);
    Simp.prepare_text(font_ui_big,      COMMON_CHARS);
    Simp.prepare_text(font_ui_medium,   COMMON_CHARS);

    common_icons: String_Builder;
    common_icons.allocator = temp;
    for enum_values_as_enum(Icon) {
        char := convert_utf32_to_utf8(xx it);
        append(*common_icons, to_string(*char));
    }
    append(*common_icons, PEN_ICON);
    append(*common_icons, XMARK_ICON);
    icons_string := builder_to_string(*common_icons,, allocator = temp);

    Simp.prepare_text(font_icons,       icons_string);
    Simp.prepare_text(font_icons_tiny, icons_string);

    // Things that depend on char size
    char_size       = cast(float) font.em_width;
    char_x_advance  = cast(float) font.x_advance;
    old_line_height = line_height;
    line_height     = floor(cast(float) font.default_line_spacing * cast(float)config.settings.line_height_scale_percent / 100.0);
    scrollbar_size  = floor(1.5 * char_size);
    rounding_radius = floor(char_size / 2);
    rounding_radius_large = floor(char_size / 1.5);
    rounding_radius_small = floor(char_size / 3);
}

update_mouse_state :: () {
    x, y := get_mouse_pointer_position(window, false);
    mouse.pointer.x = xx x;
    mouse.pointer.y = xx (window_height - y);
    mouse.moved_this_frame = (mouse.pointer != mouse.previous_position);
    if mouse.moved_this_frame {
        platform_show_cursor(true);
    }
    mouse.previous_position = mouse.pointer;

    if shift_pressed() {
        mouse.scroll_x_delta = cast(s32) (cast(float) Input.mouse_wheel_delta.vertical * WHEEL_SENSITIVITY);
    } else {
        mouse.scroll_x_delta = cast(s32) (cast(float) Input.mouse_wheel_delta.horizontal * WHEEL_SENSITIVITY);
        mouse.scroll_y_delta = cast(s32) (cast(float) Input.mouse_wheel_delta.vertical   * WHEEL_SENSITIVITY);
    }
    mouse.smooth_scroll = (mouse.scroll_y_delta % 120) == 0;  // @Robustness: hard-coded typical delta, but it really should be ok for now
    if !config.settings.smooth_scrolling then mouse.smooth_scroll = false;

    update_button :: (button: *Mouse_Button_State, key: Input.Key_Code) {
        button.is_down       = key_state(key) & .DOWN  != 0;  // NOTE: this doesn't include just_pressed!
        button.just_pressed  = key_state(key) & .START != 0;
        button.just_released = key_state(key) & .END   != 0;

        if button.just_pressed {
            time_from_last_click := to_float64_seconds(frame_time - button.last_down_time);
            time_from_last_double_click := to_float64_seconds(frame_time - button.last_double_click_time);
            distance_from_last_click := mouse.pointer - button.last_down_pos;
            max_distance := max(abs(distance_from_last_click.x), abs(distance_from_last_click.y));
            button.last_down_pos  = mouse.pointer;
            button.last_down_time = frame_time;
            button.just_double_clicked = time_from_last_click < DOUBLE_CLICK_SPEED && max_distance < DOUBLE_CLICK_TOLERANCE;
            button.just_triple_clicked = time_from_last_double_click < DOUBLE_CLICK_SPEED && max_distance < DOUBLE_CLICK_TOLERANCE;
            if button.just_triple_clicked then button.just_double_clicked = false;  // exclusive
            if button.just_double_clicked {
                button.last_double_click_time = frame_time;
            }
        } else {
            button.just_double_clicked = false;
            button.just_triple_clicked = false;
        }

        button.is_dragging = button.is_down && mouse.pointer != button.last_down_pos;
    }

    update_button(*mouse.left,   .MOUSE_BUTTON_LEFT);
    update_button(*mouse.right,  .MOUSE_BUTTON_RIGHT);
    update_button(*mouse.middle, .MOUSE_BUTTON_MIDDLE);
}

editor_toggle_fullscreen :: () {
    fullscreen = !fullscreen;
    toggle_fullscreen(window, fullscreen, *fullscreen_state);  // platform-specific
}

open_another_editor_instance :: () {
    new_window_process := Process.{};
    #if OS == .WINDOWS {
        kill_children := false;
    } else {
        // Not killing children is not yet implemented on non-Windows systems
        kill_children := true;
    }
    create_process(*new_window_process, .. focus_executable_args, "", capture_and_return_output = false, arg_quoting = Process_Argument_Quoting.QUOTE_IF_NEEDED, kill_process_if_parent_exits = kill_children);
}

increase_font_size :: () {
    if (font_size + 1) <= MAX_FONT_SIZE {
        font_size += 1;
        init_fonts_and_dependent_things();
    }
}

decrease_font_size :: () {
    if (font_size - 1) >= MIN_FONT_SIZE {
        font_size -= 1;
        init_fonts_and_dependent_things();
    }
}

reset_font_size_to_default :: () {
    font_size = default_font_size;
    init_fonts_and_dependent_things();
}

panic :: (format_string: string, args: .. Any, exit_code : s32 = 1) {
    log_error(format_string, ..args);
    exit(exit_code);
} @PrintLike

panic_messagebox :: (format_string: string, args: .. Any) {
    #if OS == .WINDOWS {
        message := tprint(format_string, ..args);
        MessageBoxW(null, utf8_to_wide_new(message,, allocator = temp), utf8_to_wide_new("Fatal Error",, allocator = temp), MB_OK);
        exit(1);
    } else {
        panic(format_string, ..args);
    }
} @PrintLike

unimplemented :: (loc := #caller_location) {
    print("!!!! Unimplemented at %\n", loc);
}

key_state :: inline (key: Input.Key_Code) -> Input.Key_Current_State {
    return Input.input_button_states[key];
}

shift_pressed :: inline () -> bool {
    return key_state(.SHIFT) & .DOWN != 0;
}

only_shift_pressed :: inline (mods: Mods) -> bool {
    return mods.packed == MODS_SHIFT;
}

ctrl_or_cmd_pressed :: inline () -> bool {
    #if OS != .MACOS {
        return key_state(.CTRL) & .DOWN != 0;
    } else {
        return key_state(.CMD) & .DOWN != 0;
    }
}

update_window_size :: (w: s64, h: s64) {
    window_width  = w;
    window_height = h;
    Simp.update_window(window);
    screen = make_rect(0, 0, window_width, window_height);
    new_dpi_scale := platform_get_dpi_scale(window);
    if new_dpi_scale != dpi_scale {
        dpi_scale = new_dpi_scale;
        init_fonts_and_dependent_things();
    }
}

current_time_consensus_backwards_compatible :: () -> Apollo_Time {
    #if WINDOWS7 {
        #assert OS == .WINDOWS;
        // GetSystemTimePreciseAsFileTime is only supported in Windows 8+
        // and that's what Apollo_Time uses.
        // TODO: remove when we drop support for Windows 7
        ft_now: FILETIME;
        GetSystemTimeAsFileTime(*ft_now);

        apollo := filetime_to_apollo(ft_now);
        return apollo;
    } else {
        return current_time_consensus();
    }
}

fill_in_missing_default_themes :: () {
    for theme : BUILTIN_THEMES {
        theme_file := tprint("%/%.focus-theme", themes_dir, theme.name);
        if !file_exists(theme_file) then write_entire_file(theme_file, theme.contents);
    }
}

calculate_hash: (bytes: [] u8) -> u64 = calculate_meow_hash;

// Important directories
config_dir:   string;
data_dir:     string;
temp_dir:     string;
projects_dir: string;
themes_dir:   string;

focus_executable_args: [] string;

window: Window_Type;
window_generic_title: string = ---;
window_width  := 0;
window_height := 0;
window_x  := -1;
window_y  := -1;
dpi_scale := 1.0;

fullscreen: bool;
fullscreen_state: Saved_Window_Info;

redraw_requested := true;  // set to true to render the first frame
should_quit      := false;

frame_time:   Apollo_Time;          // ever-increasing time since start in seconds
frame_time64: float64;              // for when we don't need as much precision
frame_dt: float64 = MAX_FRAME_DT;   // time delta since the last frame
MAX_FRAME_DT:   float64 : (1.0 / 60);
QUICK_FRAME_DT: float64 : (1.0 / 300);  // sorry 300Hz monitor users

EDIT_GROUP_TIMEOUT :: 0.3;  // for undo/redo

screen: Rect;  // contains the current working area rect for convenience

mouse: Mouse_State;

Mouse_State :: struct {
    pointer: Vector2;
    previous_position: Vector2;
    moved_this_frame: bool;
    scroll_x_delta: s32;
    scroll_y_delta: s32;
    smooth_scroll: bool;

    left:   Mouse_Button_State;
    right:  Mouse_Button_State;
    middle: Mouse_Button_State;
}

Mouse_Button_State :: struct {
    is_down:             bool;
    is_dragging:         bool;
    just_pressed:        bool;
    just_released:       bool;
    just_double_clicked: bool;
    just_triple_clicked: bool;

    last_down_pos:  Vector2;
    last_down_time: Apollo_Time;
    last_double_click_time: Apollo_Time;
}

WHEEL_SENSITIVITY :: 1.0;

PEN_ICON            :: #run to_string(*convert_utf32_to_utf8(0xf304));
CASE_SENSITIVE_ICON :: #run to_string(*convert_utf32_to_utf8(0xf031));
WHOLE_WORD_ICON     :: #run to_string(*convert_utf32_to_utf8(0xe4ba));
REGEX_SEARCH_ICON   :: #run to_string(*convert_utf32_to_utf8(0xf621));
BULLET_ICON         :: #run to_string(*convert_utf32_to_utf8(0x2022));
XMARK_ICON          :: #run to_string(*convert_utf32_to_utf8(0xf057));

TAB_SIZE: s32 = 4;

font:               *Simp.Dynamic_Font;
font_ui:            *Simp.Dynamic_Font;
font_ui_bold:       *Simp.Dynamic_Font;
font_ui_big:        *Simp.Dynamic_Font;
font_ui_small:      *Simp.Dynamic_Font;
font_ui_very_small: *Simp.Dynamic_Font;
font_ui_medium:     *Simp.Dynamic_Font;
font_icons:         *Simp.Dynamic_Font;
font_icons_small:   *Simp.Dynamic_Font;
font_icons_tiny:    *Simp.Dynamic_Font;

DEFAULT_FONT_SIZE               :: 14;
DEFAULT_FONT_UI_SIZE            :: 15;
DEFAULT_FONT_UI_BIG_SIZE        :: 28;
DEFAULT_FONT_UI_MEDIUM_SIZE     :: 18;
DEFAULT_FONT_UI_SMALL_SIZE      :: 14;
DEFAULT_FONT_UI_VERY_SMALL_SIZE :: 12;
DEFAULT_FONT_ICONS_SIZE         :: 16;
DEFAULT_FONT_ICONS_SMALL_SIZE   :: 12;
DEFAULT_FONT_ICONS_TINY_SIZE    :: 8;

main_font_name := "default";
main_font_data := #run FONT.data;

default_font_size       := DEFAULT_FONT_SIZE;  // can be changed in the config

font_size               := DEFAULT_FONT_SIZE;  // when changing font size, we change just this one and then derive the other ones from it
font_ui_size            := DEFAULT_FONT_UI_SIZE;
font_ui_big_size        := DEFAULT_FONT_UI_BIG_SIZE;
font_ui_medium_size     := DEFAULT_FONT_UI_MEDIUM_SIZE;
font_ui_small_size      := DEFAULT_FONT_UI_SMALL_SIZE;
font_ui_very_small_size := DEFAULT_FONT_UI_VERY_SMALL_SIZE;
font_icons_size         := DEFAULT_FONT_ICONS_SIZE;
font_icons_small_size   := DEFAULT_FONT_ICONS_SMALL_SIZE;
font_icons_tiny_size    := DEFAULT_FONT_ICONS_TINY_SIZE;

// Depend on font size
char_size:                  float;
char_x_advance:             float;
line_height:                float;
old_line_height:            float;  // to track font changes
font_ui_line_height:        float;
font_ui_big_line_height:    float;
font_ui_medium_line_height: float;
rounding_radius:            float;
rounding_radius_large:      float;
rounding_radius_small:      float;
scrollbar_size:             float;

dont_scroll_this_frame := false;  // because e.g. a mouse wheel event has been handled

// This will be set to `true` in `refresh_config()` to signal that the
// next window resize event should be handled even if the window doesn't actually
// change size. This is needed when changing DPI/scaling options which require
// a full repaint.
dont_ignore_next_window_resize := false;

Mods :: Input.Event.Modifier_Flags;

project_dirs:  [..] Project_Dir;
project_files: [..] string;  // individual files added to project

active_global_widget: Active_Global_Widget = .editors;

Active_Global_Widget :: enum {
    editors;
    finder;
    open_file_dialog;
    delete_file_dialog;
    go_to_line_dialog;
    commands_dialog;
    switch_to_project_dialog;
    unsaved_buffers_dialog;
    confirm_overwrite_dialog;
    kill_running_command_dialog;
    theme_dialog;
    language_dialog;
}

Project_Dir :: struct {
    path: string;          // e.g. "C:/projects/focus"
    path_prefix_len: s64;  // in this case the length of "C:/projects/"
    name: string;          // a view into path
}

Builtin_Theme :: struct {
    name: string;
    contents: string;
}

BUILTIN_THEMES :: #run -> [] Builtin_Theme {
    themes: [..] Builtin_Theme;

    visitor :: (info: *File_Visit_Info, themes: *[..] Builtin_Theme) {
        full_path := info.full_name;
        path, basename, extension, name := path_decomp(full_path);
        if extension != "focus-theme" return;
        file_contents, success := read_entire_file(full_path);
        if !success return;
        array_add(themes, Builtin_Theme.{ name = basename, contents = file_contents });
    }
    visit_files("config/themes", recursive = false, *themes, visitor, visit_files = true, visit_directories = false);

    return themes;
}

// A string which contains the path to a file which was just drag-and-dropped into the editor (for the draw code to use)
just_dropped_file := "";

cpu_info: Cpu_X86;

focus_allocator: Allocator;


#load "array.jai";
#load "layout.jai";
#load "editors.jai";
#load "buffer.jai";
#load "build_system.jai";
#load "unicode.jai";
#load "draw.jai";
#load "pointer_image.jai";
#load "utils.jai";
#load "files.jai";
#load "workspace.jai";
#load "config.jai";
#load "config_parser.jai";
#load "config_migrator.jai";
#load "colors.jai";
#load "keymap.jai";
#load "session.jai";
#load "projects.jai";
#load "meow_hash.jai";
#load "user_messages.jai";
#load "deferred_actions.jai";

#load "widgets/generic_choice_dialog.jai";
#load "widgets/generic_confirm_dialog.jai";
#load "widgets/text_input.jai";
#load "widgets/open_file_dialog.jai";
#load "widgets/delete_file_dialog.jai";
#load "widgets/go_to_line_dialog.jai";
#load "widgets/finder.jai";
#load "widgets/unsaved_buffers.jai";
#load "widgets/commands.jai";
#load "widgets/switch_to_project.jai";
#load "widgets/confirm_overwrite.jai";
#load "widgets/kill_running_command.jai";
#load "widgets/theme_dialog.jai";
#load "widgets/language_dialog.jai";
#load "widgets/color_preview.jai";
#load "widgets/color_picker.jai";

#load "langs/common.jai";
#load "langs/jai.jai";
#load "langs/c.jai";
#load "langs/cpp.jai";
#load "langs/css.jai";
#load "langs/csharp.jai";
#load "langs/focus_config.jai";
#load "langs/glsl.jai";
#load "langs/hlsl.jai";
#load "langs/golang.jai";
#load "langs/js.jai";
#load "langs/json.jai";
#load "langs/lua.jai";
#load "langs/odin.jai";
#load "langs/python.jai";
#load "langs/renpy.jai";
#load "langs/xml.jai";
#load "langs/todo.jai";
#load "langs/yang.jai";
#load "langs/zig.jai";
#load "langs/uxntal.jai";
#load "langs/rust.jai";
#load "langs/markdown.jai";
#load "langs/batch.jai";

#if OS == .WINDOWS {
    #load "platform/windows.jai";
    #import "Windows_Utf8";
} else #if OS == .LINUX {
    #load "platform/linux.jai";
} else #if OS == .MACOS {
    #load "platform/macos.jai";
} else {
    #assert false, "Unsupported OS";
}

using Basic :: #import "Basic"()(MEMORY_DEBUGGER = DEBUG);
#import "Atomics";
#import "Compiler";
#import "File";
#import "File_Utilities";
#import "File_Watcher";
#import "Flat_Pool";
#import "Math";
#import "Machine_X64";
#import "Process";
#import "Reflection";
#import "Sloppy_Math";
#import "System";
#import "String";
#import "Sort";
#import "Simple_Bucket_Array";
#import "Thread";
#import "Unicode";
#import "Window_Creation";
#import "Hash_Table";

re   :: #import "uniform";
Hash :: #import "Hash";

// NOTE to future self: remove `.NeverCapture` from `BASE_REGEX_FLAGS` if we ever want to have
//                      find-and-replace with regex capture support
BASE_REGEX_FLAGS : re.ParseFlags : (.LikePerl | .NeverCapture) & ~.OneLine;

// #if DEBUG {
//     #import "Tracy";
// }

File_Async :: #import "File_Async";

Simp  :: #import "Simp";
Input :: #import "Input";

MAX_BUFFER_SIZE_FOR_HIGHLIGHTS :: 5 * 1024 * 1024;

#scope_file

MODS_NONE           :: #run Mods.{}.packed;
MODS_CTRL           :: #run Mods.{ ctrl_pressed  = true }.packed;
MODS_ALT            :: #run Mods.{ alt_pressed   = true }.packed;
MODS_SHIFT          :: #run Mods.{ shift_pressed = true }.packed;
MODS_ALT_SHIFT      :: #run Mods.{ alt_pressed  = true, shift_pressed = true }.packed;
MODS_CTRL_SHIFT     :: #run Mods.{ ctrl_pressed = true, shift_pressed = true }.packed;
MODS_CTRL_ALT       :: #run Mods.{ ctrl_pressed = true, alt_pressed   = true }.packed;
MODS_CTRL_ALT_SHIFT :: #run Mods.{ ctrl_pressed = true, alt_pressed   = true, shift_pressed = true }.packed;


#scope_export

MIN_WINDOW_WIDTH  :: 100;
MIN_WINDOW_HEIGHT :: 100;

DOUBLE_CLICK_SPEED     :: 0.3;  // how many seconds between clicks to consider it a double click
DOUBLE_CLICK_TOLERANCE :: 2;    // how many pixels between the click locations are allowed

// Embed default fonts
FONT         :: #run load_font("FiraCode-Retina.ttf");
FONT_UI      :: #run load_font("OpenSans-Regular.ttf");
FONT_UI_BOLD :: #run load_font("OpenSans-SemiBold.ttf");
FONT_ICONS   :: #run load_font("font-awesome/Font Awesome 6 Free-Solid-900.otf");

MIN_FONT_SIZE :: 4;
MAX_FONT_SIZE :: 30;  // setting a larger size has caused freetype to crash - not sure yet why.
                      // Probably we don't give it enough memory for a glyph bitmap when rendering it?

load_font :: (name: string) -> Embedded_Font {
    path := tprint("fonts/%", name);
    data, success := read_entire_file(path);
    assert(success, "Couldn't load font '%'", path);

    return Embedded_Font.{ name = name, data = data};
}

Embedded_Font :: struct {
    name: string;
    data: string;
}

DEBUG_FILE_REFRESH :: false;  // TODO: remove when done debugging
DEBUG_MEMORY_LEAKS :: false;


#if OS == .LINUX {
    /*
     * EXTREME JANK - nuke once the Jai standard library no longer depends on libc
     */
    focus_memcpy :: (dst: *void, src: *void, size: s64) -> *void #foreign libc "memmove";
    libc :: #system_library "libc";
} else {
    focus_memcpy :: memcpy;
}
