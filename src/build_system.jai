init_build_system :: () {
    assert(build_buffer_id < 0 && build_editor_id < 0, "Build system already initialised");

    build_buffer_id = create_an_empty_buffer();
    build_editor_id = find_or_create_editor(build_buffer_id);
    editor, buffer := *open_editors[build_editor_id], *open_buffers[build_buffer_id];
    buffer.readonly = true;
    buffer.internal = true;
    buffer.lang = .Focus_Build_Panel;
    if config.settings.build_panel_line_wrap_always_on then editor.line_wrap = .on; else editor.line_wrap = .off;

    commands_refresh_after_config_change();

    init(*build_mutex);

    thread_group = Thread_Group.{};  // in case we need to reinitialise it later
    init(*thread_group, num_threads = 1, group_proc = build_threadproc);
    start(*thread_group);
}

deinit_build_system :: () {
    assert(build_buffer_id >= 0 && build_editor_id >= 0, "Build system is not initialized");
    shutdown(*thread_group);

    // Assuming that the editor and the buffer will be cleaned up separately
    build_buffer_id = -1;
    build_editor_id = -1;
    running_command = "";
    last_command_result = .{};
}

execute_build_command :: (command: *Build_Command) {
    assert(workspace_scan_complete);
    assert(!running_command);

    clear_user_messages(.build);

    // Prepare and validate command
    {
        using command;
        if build_working_dir && contains(build_working_dir, "\\") {
            build_working_dir = copy_string(build_working_dir);  // @leak
            path_overwrite_separators(build_working_dir, #char "/");
            build_working_dir = trim_right(build_working_dir, "/");
        }
        if run_working_dir && contains(run_working_dir, "\\") {
            run_working_dir = copy_string(run_working_dir);  // @leak
            path_overwrite_separators(run_working_dir, #char "/");
            run_working_dir = trim_right(run_working_dir, "/");
        }
        if !build_command && !run_command {
            add_user_error("Can't run [%]:\nbuild_command or run_command must be specified in the config", name);
            return;
        }
    }

    log("Executing build command [%]\n", command.name);

    // Add an empty line between commands
    if last_command_result.finished then print_to_output_panel_from_main_thread("\n");

    if command.clear_build_output_before_running then build_clear_output();

    last_command_result = .{};  // this will clear build_errors among other things

    print_to_output_panel_from_main_thread(tprint("%\n", command.name), mark_as = .header);

    reset(*memory_pool);

    push_allocator(get_pool_allocator());

    work := New(Build_Thread_Work);
    work.command           = command.*;
    work.name              = copy_string(command.name);
    work.build_command     = copy_string(command.build_command);
    work.build_working_dir = copy_string(command.build_working_dir);
    work.run_command       = copy_string(command.run_command);
    work.run_working_dir   = copy_string(command.run_working_dir);
    work.error_regex       = copy_string(command.error_regex);

    if command.substitute_variables then substitute_variables(work);

    check_working_dirs(work);

    // We never want a timeout of 0 seconds because the command will never run.
    // People probably expect 0 to be no timeout, so we convert it to -1, which means no timeout
    if command.timeout_in_seconds == 0 then work.timeout_in_seconds = -1;

    if command.open_panel_on_build {
        show_build_panel();
    } else if !build_panel_is_shown {
        add_success_message("Running [%]…", work.name, dismiss_in_seconds = 3,, allocator = focus_allocator);
    }

    add_work(*thread_group, work);
    running_command = work.name;  // work.name should live until a new command is kicked off
}

build_clear_output :: () {
    // It's ok not to lock build_mutex here because we're only supposed to be writing to buffers from the main thread
    // (and this should only be called from the main thread)

    if build_buffer_id < 0 return;
    editor, buffer := get_build_editor_and_buffer();

    push_allocator(focus_allocator);

    delete_range_raw(buffer, 0, buffer.bytes.count);
    rescan_for_lines(buffer);
    if editor.line_wrap == .on then rescan_for_wrapped_lines(editor, buffer);

    lock(*buffer.content_lock);
    reset_keeping_memory(*buffer.regions);
    resize(*buffer.tokens, buffer.bytes.count);
    memset(buffer.tokens.data, 0, buffer.tokens.count);
    unlock(*buffer.content_lock);
}

build_get_running_command_name :: () -> string {
    return running_command;
}

build_kill_running_command :: () {
    if !running_command {
        add_user_warning("No command is currently running", dismiss_in_seconds = 3, tag = .build);
        return;
    }
    lock(*build_mutex);
    kill_process(*running_process);
    unlock(*build_mutex);
}

build_system_update :: () {
    assert(build_buffer_id >= 0 && build_editor_id >= 0, "Build system is not initialized");

    buffer := *open_buffers[build_buffer_id];
    // Print to build output panel, if we have anything to print
    {
        lock(*build_mutex);
        output := builder_to_string(*stdout);
        unlock(*build_mutex);

        print_to_output_panel_from_main_thread(output);
        free(output);
    }

    // Check if a command has finished executing
    results := get_completed_work(*thread_group);
    if results {
        // We only process one command at a time, so this means our running command has finished
        assert(running_command != "", "Build thread has finished work, but no command running");
        assert(results.count == 1, "Build thread returned more than 1 result. This is a bug.");

        finished_command := cast(*Build_Thread_Work) results[0];

        log("Build command [%] finished\n", finished_command.name);

        assert(last_command_result.finished);

        message: string;
        kind: Buffer_Region.Kind = .none;

        result := ifx last_command_result.run.finished then last_command_result.run else last_command_result.build;

        if result.timeout_reached {
            message = tprint("TIMED OUT after % seconds", finished_command.timeout_in_seconds);
            kind = .warning;
        } else {
            if #complete result.process_result.type == {
                case .UNSTARTED; #through;
                case .FAILED_TO_LAUNCH;
                    command := ifx last_command_result.run.finished then finished_command.run_command else finished_command.build_command;
                    message = tprint("ERROR: couldn't launch '%'", command);
                    if is_common_windows_shell_command(command) {
                        message = tprint("%.\nLooks like you're trying to execute a shell command. Try doing 'cmd /C \"%\"' to launch a shell explicitly.", message, command);
                    } else if !is_absolute_path(command) {
                        message = tprint("%. Try specifying a full path to the executable.", message);
                    }
                    kind = .error;
                case .STILL_RUNNING;
                    message = "ERROR: the command is still running. This is a bug.";
                    kind = .error;
                case .SIGNALED;
                    message = tprint("ERROR: the process signaled %", result.process_result.signal);
                    kind = .error;
                case .EXITED;
                    exit_code := result.process_result.exit_code;
                    if exit_code != 0 {
                        message = tprint("ERROR: exit code %", exit_code);
                        kind = .error;
                    } else {
                        message = "DONE";
                        kind = .success;
                    }
            }

            if result.finished then parse_errors_in_failed_command_output(finished_command.error_regex, result);
        }

        // Print the end message and elapsed time
        if last_command_result.build.finished && last_command_result.run.finished {
            message = tprint("%  [Build took %s]", message, formatFloat(last_command_result.build.elapsed_seconds, trailing_width = 3, zero_removal = .NO));
            message = tprint("%  [Run took %s]",   message, formatFloat(last_command_result.run.elapsed_seconds,   trailing_width = 3, zero_removal = .NO));
        } else if last_command_result.build.finished || last_command_result.run.finished {
            command := ifx last_command_result.run.finished then last_command_result.run else last_command_result.build;
            if command.elapsed_seconds > 0 {
                message = tprint("%  [Elapsed: %s]", message, formatFloat(command.elapsed_seconds, trailing_width = 3, zero_removal = .NO));
            }
        }
        print_to_output_panel_from_main_thread(tprint("%\n", message), mark_as = kind, add_newline_if_missing = true);

        if kind == .success {
            if finished_command.close_panel_on_success then hide_build_panel();
            if !finished_command.open_panel_on_build   then add_success_message("Finished [%]", finished_command.name, dismiss_in_seconds = 3);
        } else {
            // Always show the panel on errors
            show_build_panel();
            if finished_command.auto_jump_to_error then go_to_next_build_error();
        }

        running_command = "";
    }
}

build_panel_toggle :: () {
    if build_panel_is_shown {
        hide_build_panel();
    } else {
        show_build_panel();
    }
}

show_build_panel :: () {
    // Maybe hide other popups
    if #complete active_global_widget == {
        case .editors;                  // nothing to do
        case .build_panel;              // nothing to do

        case .unsaved_buffers_dialog;   // do nothing, we still want to see them
        case .confirm_overwrite_dialog; // do nothing, we still want to see them

        case .open_file_dialog;                 #through;
        case .delete_file_dialog;               #through;
        case .kill_running_command_dialog;      #through;
        case .finder;                           #through;
        case .go_to_line_dialog;                #through;
        case .switch_to_project_dialog;         #through;
        case .theme_dialog;                     #through;
        case .language_dialog;                  #through;
        case .commands_dialog;                  active_global_widget = .editors;  // NOTE: build panel will be shown but not focused
    }
    build_panel_is_shown = true;
}

hide_build_panel :: () {
    build_panel_lose_focus();
    build_panel_is_shown = false;
}

is_build_panel :: inline (editor_id: s64) -> bool {
    return editor_id == build_editor_id;
}

build_panel_lose_focus :: () {
    if active_global_widget == .build_panel then active_global_widget = .editors;
}

build_panel_grab_focus :: () {
    if !build_panel_is_shown then show_build_panel();
    active_global_widget = .build_panel;
    cursors_start_blinking();
}

build_panel_toggle_focus :: () {
    if active_global_widget == .build_panel {
        build_panel_lose_focus();
    } else {
        build_panel_grab_focus();
    }
}

build_panel_toggle_height :: () {
    target := ifx build_panel_is_expanded then config.settings.build_panel_height_percent / 100.0 else 1.0;
    target = clamp(target, 0.1, 1.0);

    if !config.settings.disable_file_open_close_animations {
        start_animation(*build_panel_height_anim, build_panel_height, target);
    } else {
        build_panel_height_anim.target = target;
        build_panel_height = target;
    }
    build_panel_is_expanded = !build_panel_is_expanded;
}

build_panel_set_height :: (height: float) {
    height = clamp(height, 0.1, 1.0);
    build_panel_height_anim.target = height;
    build_panel_height = height;
    build_panel_is_expanded = !(height < 1.0);
}

build_panel_set_width :: (width: float) {
    build_panel_width = clamp(width, 0.1, 1.0);
}

build_panel_get_position :: () -> Build_Panel_Position {
    if config.settings.build_panel_stays_in_one_place return .right;

    // Get the center of the active pane
    leaf_pane_rects := gather_leaf_pane_rects();
    center := Vector2.{ -1, -1 };
    for leaf_pane_rects {
        if it.pane == editors.active_pane { center = center_of(it.rect); break; }
    }

    if center.x <= screen.x + screen.w / 2 {
        return .right;
    } else {
        return .left;
    }
}

build_panel_is_active :: inline () -> bool {
    return build_panel_is_shown && active_global_widget == .build_panel;
}

cursor_is_on_build_error :: (cursor: Cursor) -> bool {
    return get_error_id_under_cursor(cursor) >= 0;
}

go_to_build_error_under_cursor :: (cursor: Cursor, placement: Editor_Placement = .in_place) {
    error_id := get_error_id_under_cursor(cursor);
    if error_id < 0 || error_id >= last_command_result.build_errors.count return;
    last_command_result.current_build_error_id = error_id;
    go_to_current_build_error(placement, show_error = false);
}

get_error_id_under_cursor :: (cursor: Cursor) -> error_id: s64 {
    for last_command_result.build_errors {
        if it.file_path_location.start <= cursor.pos && cursor.pos <= it.file_path_location.end return it_index;
    }
    return -1;
}

build_panel_get_editor_id :: inline () -> s64 {
    assert(build_editor_id >= 0);
    return build_editor_id;
}

build_panel_set_line_wrap :: (enable: bool) {
    if build_editor_id < 0 return;
    editor := *open_editors[build_editor_id];
    if  enable && editor.line_wrap == .off then editor.line_wrap = .to_enable;
    if !enable && editor.line_wrap == .on  then editor.line_wrap = .to_disable;
}

go_to_next_build_error :: (placement: Editor_Placement = .in_place) {
    using last_command_result;
    if !can_go_to_build_error() return;

    current_build_error_id = (current_build_error_id + 1) % build_errors.count;
    go_to_current_build_error(placement);
}

go_to_previous_build_error :: (placement: Editor_Placement = .in_place) {
    using last_command_result;
    if !can_go_to_build_error() return;

    current_build_error_id = (current_build_error_id - 1 + build_errors.count) % build_errors.count;
    go_to_current_build_error(placement);
}

build_panel_is_shown := false;

build_panel_width:  float = 0.5;
build_panel_height: float = 0.5;
build_panel_height_anim: Tween_Animation(float);


#scope_file

get_build_editor_and_buffer :: () -> *Editor, *Buffer {
    assert(build_buffer_id >= 0 && build_editor_id >= 0);

    buffer := *open_buffers[build_buffer_id];
    editor := *open_editors[build_editor_id];

    return editor, buffer;
}

build_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    command := cast(*Build_Thread_Work) work;

    log("Executing build command [%]\n", command.name);

    push_allocator(get_pool_allocator());

    defer {
        // Writing to a global var here and below but it's OK because it won't be accessed until the thread is done
        last_command_result.finished = true;
        platform_wake_up_main_thread();
    }

    if command.build_command {
        header := tprint("> %\n", command.build_command);
        write_output_from_build_thread(*stdout, header);

        result, timeout_reached, elapsed_seconds := run_command_while_monitoring_output(
            ..break_command_into_strings(command.build_command),
            working_directory = command.build_working_dir,
            timeout_ms = command.timeout_in_seconds * 1000,
        );

        last_command_result.build_working_dir = copy_string(command.build_working_dir);
        last_command_result.build = .{
            finished = true,
            timeout_reached = timeout_reached,
            process_result = result,
            elapsed_seconds = elapsed_seconds,
        };

        // Don't run the run command if failed
        if result.type != .EXITED || result.exit_code != 0 return .CONTINUE;
    }

    if command.run_command {
        // Run if the build command has succeeded or doesn't exist
        header := tprint("> %\n", command.run_command);
        if command.build_command then header = tprint("\n%", header);
        write_output_from_build_thread(*stdout, header);

        result, timeout_reached, elapsed_seconds := run_command_while_monitoring_output(
            ..break_command_into_strings(command.run_command),
            working_directory = command.run_working_dir,
        );

        last_command_result.run = .{
            finished = true,
            timeout_reached = timeout_reached,
            process_result = result,
            elapsed_seconds = elapsed_seconds,
        };
    }

    return .CONTINUE;
}

print_to_output_panel_from_main_thread :: (s: string, mark_as: Buffer_Region.Kind = .none, add_newline_if_missing := false) {
    if !s return;

    editor, buffer := get_build_editor_and_buffer();

    if add_newline_if_missing && buffer.bytes.count > 0 && buffer.bytes[buffer.bytes.count-1] != #char "\n" {
        insert_string_raw(buffer, buffer.bytes.count, "\n");
    }

    start := cast(s32) buffer.bytes.count;
    insert_string_raw(buffer, buffer.bytes.count, s);
    end   := cast(s32) buffer.bytes.count;

    cursor := leave_only_original_cursor(editor);
    cursor.pos = xx buffer.bytes.count;
    cursor.sel = cursor.pos;
    editor.scroll_to_cursor = .yes;

    if mark_as != .none {
        add(*buffer.regions, Buffer_Region.{ start = start, end = end, kind = mark_as });
    }

    // Maybe forget some bytes at the beginning
    if buffer.bytes.count > MAX_BUILD_OUTPUT_BUFFER_SIZE {
        bytes_to_forget := cast(s32) (buffer.bytes.count - MAX_BUILD_OUTPUT_BUFFER_SIZE);
        bytes_to_forget = to_valid_utf8_char_offset(buffer.bytes, bytes_to_forget);  // don't cut utf8 chars in the middle
        assert(bytes_to_forget >= 0, "Error when trying to forget bytes in the build output. This is a bug.");

        lock(*buffer.content_lock);
        resize(*buffer.tokens, buffer.bytes.count);  // resize first before we delete
        delete_range_raw(buffer, 0, bytes_to_forget);
        delete_range(*buffer.tokens, 0, bytes_to_forget);
        unlock(*buffer.content_lock);

        for * last_command_result.build_errors {
            it.file_path_location.start -= bytes_to_forget;
            it.file_path_location.end   -= bytes_to_forget;
            if it.file_path_location.start < 0 || it.file_path_location.end < 0 then remove it;  // don't bother sorting afterwards because this should almost never happen
        }

        for * region : buffer.regions {
            region.start -= bytes_to_forget;
            region.end   -= bytes_to_forget;
            if region.start < 0 || region.end < 0 then remove region;  // will have to sort later because they must be sorted
        }
        quick_sort(to_view(buffer.regions), (a, b) => (a.start - b.start));
    }
}

substitute_variables :: (using work: *Build_Thread_Work) {
    // Figure out the current file
    file := "";
    active_pane_editor_id := get_active_editor_id();
    if active_pane_editor_id > 0 {
        buffer := open_buffers[open_editors[active_pane_editor_id].buffer_id];
        if buffer.has_file then file = copy_string(buffer.file.full_path);
    }

    file_vars_are_used := false;
    file_vars := string.["%FILE%", "%FILE_DIR%", "%FILE_NAME%", "%FILE_NAME_NO_EXTENSION%"];
    for file_vars {
        if contains(build_command, it) || contains(run_command, it) || contains(build_working_dir, it) || contains(run_working_dir, it) {
            file_vars_are_used = true;
            break;
        }
    }
    if file_vars_are_used {
        if !file then add_user_warning("Couldn't determine the current file, but variables like \%FILE\% are used in the command", dismiss_in_seconds = 10);

        file_dir, file_name_no_extension, _, file_name := path_decomp(file);
        file_dir = trim_right(file_dir, "/");

        build_working_dir = replace(build_working_dir, "%FILE%",                   file);
        build_working_dir = replace(build_working_dir, "%FILE_DIR%",               file_dir);
        build_working_dir = replace(build_working_dir, "%FILE_NAME%",              file_name);
        build_working_dir = replace(build_working_dir, "%FILE_NAME_NO_EXTENSION%", file_name_no_extension);

        run_working_dir   = replace(run_working_dir,   "%FILE%",                   file);
        run_working_dir   = replace(run_working_dir,   "%FILE_DIR%",               file_dir);
        run_working_dir   = replace(run_working_dir,   "%FILE_NAME%",              file_name);
        run_working_dir   = replace(run_working_dir,   "%FILE_NAME_NO_EXTENSION%", file_name_no_extension);

        build_command     = replace(build_command,     "%FILE%",                   file);
        build_command     = replace(build_command,     "%FILE_DIR%",               file_dir);
        build_command     = replace(build_command,     "%FILE_NAME%",              file_name);
        build_command     = replace(build_command,     "%FILE_NAME_NO_EXTENSION%", file_name_no_extension);

        run_command       = replace(run_command,       "%FILE%",                   file);
        run_command       = replace(run_command,       "%FILE_DIR%",               file_dir);
        run_command       = replace(run_command,       "%FILE_NAME%",              file_name);
        run_command       = replace(run_command,       "%FILE_NAME_NO_EXTENSION%", file_name_no_extension);
    }

    // Replace %PROJECT_CONFIG_DIR% if used
    if contains(build_command, "%PROJECT_CONFIG_DIR%") || contains(run_command, "%PROJECT_CONFIG_DIR%") || contains(build_working_dir, "%PROJECT_CONFIG_DIR%") || contains(run_working_dir, "%PROJECT_CONFIG_DIR%") {
        project_dir := get_current_project_dir();
        if project_dir {
            build_working_dir = replace(build_working_dir, "%PROJECT_CONFIG_DIR%", project_dir);
            run_working_dir   = replace(run_working_dir,   "%PROJECT_CONFIG_DIR%", project_dir);
            build_command     = replace(build_command,     "%PROJECT_CONFIG_DIR%", project_dir);
            run_command       = replace(run_command,       "%PROJECT_CONFIG_DIR%", project_dir);
        } else {
            add_user_warning("Variable '%PROJECT_CONFIG_DIR%' is used in the build command, but there is no active project", dismiss_in_seconds = 10);
        }
    }

    build_command = replace(build_command, "%BUILD_WORKING_DIR%", build_working_dir);
    build_command = replace(build_command, "%RUN_WORKING_DIR%",   run_working_dir);

    run_command   = replace(run_command,   "%BUILD_WORKING_DIR%", build_working_dir);
    run_command   = replace(run_command,   "%RUN_WORKING_DIR%",   run_working_dir);
}

is_common_windows_shell_command :: (command: string) -> bool {
    #if OS == .WINDOWS {
        COMMON_CMD_COMMANDS :: string.[
            "echo ", "call ", "copy", "cd ", "chdir ", "del ", "rd ", "rmdir ", "md ", "mkdir ", "path ", "xcopy ", "move ", "ren ", "rename ",
        ];
        for COMMON_CMD_COMMANDS {
            if begins_with_nocase(command, it) return true;
        }
        return false;
    } else {
        return false;
    }
}

check_working_dirs :: (using work: *Build_Thread_Work) {
    if build_working_dir {
        is_dir, success := is_directory(build_working_dir);
        if !is_dir || !success then add_user_warning("Build directory '%' doesn't seem to be a valid directory", build_working_dir);
    }
    if run_working_dir {
        is_dir, success := is_directory(run_working_dir);
        if !is_dir || !success then add_user_warning("Run directory '%' doesn't seem to be a valid directory", run_working_dir);
    }
}

parse_errors_in_failed_command_output :: (error_regex: string, command: Command_Result) {
    if !error_regex { last_command_result.error_regex_status = .missing; return; }

    assert(command.finished);
    assert(!last_command_result.build_errors);  // we should've cleared it by now

    push_allocator(get_pool_allocator());

    editor, buffer := get_build_editor_and_buffer();

    // Get the output range of the last command:
    // - first by checking the last header region,
    // - but if it's missing because it's shifted away by printing too much, fall back to 0
    // NOTE: we used to save output ranges of every command, but that wasn't very robust when the build output limit was reached
    output_range := Offset_Range.{ start = 0, end = buffer.bytes.count };
    for #v2 < buffer.regions {
        if it.kind == .header {
            output_range.start = it.range.end;
            break;
        }
    }
    build_output := cast(string) to_view(buffer.bytes, output_range.start, output_range.end - output_range.start);

    compiled_regex, valid := re.compile(error_regex, .LikePerl & ~.OneLine);
    if !valid {
        log_error("Unable to parse build errors because error_regex is invalid: %\n", error_regex);
        last_command_result.error_regex_status = .failed_to_compile;
        return;
    }

    last_command_result.error_regex_status = .ok;

    while true {
        matched, captures := re.match(build_output, compiled_regex);
        if !matched break;

        capture := captures[0];
        if !capture { log_error("Build error_regex matched an empty line. Skipping...\n"); break; }

        advance(*build_output, capture.data - build_output.data + capture.count);

        named_captures := re.map_named_captures(captures, compiled_regex);
        #if DEBUG_BUILD_ERRORS for value, name : named_captures { print("% = %\n", name, value); }

        msg, msg_found := table_find(*named_captures, "msg");
        if !msg_found continue;

        file, file_found := table_find(*named_captures, "file");
        if !file_found continue;

        build_error := Build_Error.{ file = copy_string(file), message = copy_string(msg) };
        path_overwrite_separators(build_error.file, #char "/");

        build_error.file_path_location = .{
            start = cast(s32)(file.data - buffer.bytes.data),
            end   = cast(s32)(file.data - buffer.bytes.data + file.count),
        };

        // Highlight file paths for easier recognition that an error has been detected
        manually_mark_range_as_token(buffer, build_error.file_path_location, xx Token_Type.highlight);

        type := table_find_or_default(*named_captures, "type");
        if type {
            if contains_nocase(type, "warning") {
                build_error.type = .warning;
            } else if contains_nocase(type, "info") {
                build_error.type = .info;
            }
        }

        line := table_find_or_default(*named_captures, "line");
        val, parsed := string_to_int(line, T = s32);
        if parsed then build_error.line = val;

        col := table_find_or_default(*named_captures, "col");
        val, parsed  = string_to_int(col, T = s32);
        if parsed then build_error.col = val;

        // Detect the error info range (for subsequent code highlighting).
        {
            starts := s64.[xx file.data, xx msg.data, xx line.data, xx col.data];
            ends   := s64.[xx (file.data + file.count), xx (msg.data + msg.count), xx (line.data + line.count), xx (col.data + col.count)];

            max_s64_in_array :: (array: [] s64) -> s64 {
                max := 0;  // can't go below that
                for array { if max < it then max = it; }
                return max;
            }

            min_s64_in_array :: (array: [] s64) -> s64 {
                min := S64_MAX;
                for array { if min > it then min = it; }
                return min;
            }

            build_error.error_info_start_offset = xx (min_s64_in_array(starts) - cast(s64) buffer.bytes.data);
            build_error.error_info_end_offset   = xx (max_s64_in_array(ends)   - cast(s64) buffer.bytes.data);
        }

        array_add(*last_command_result.build_errors, build_error);
    }

    // Maybe highlight code samples.
    for error : last_command_result.build_errors {
        lang := get_lang_from_path(error.file);

        // Assume that code samples might be somewhere in between the error data we've parsed
        start := error.error_info_end_offset;
        end   := buffer.bytes.count;
        if it_index < last_command_result.build_errors.count - 1 then end = last_command_result.build_errors[it_index + 1].error_info_start_offset;

        if end < start continue;  // TODO: investigate why this might be happening before we implement other languages. See https://github.com/focus-editor/focus/issues/379

        potential_code_block := cast(string) to_view(buffer.bytes, start, end - start);

        if lang == .Jai {
            // In the Jai compiler output, sample code blocks should be separated by double newlines + spaces
            last_double_newline := cast(s32) find_index_from_right(potential_code_block, "\n\n");
            if last_double_newline >= 0 then end = start + last_double_newline;

            first_double_newline := cast(s32) find_index_from_left(potential_code_block, "\n    ");
            if first_double_newline >= 0 then start += first_double_newline;
        } else {
            continue;  // don't attempt to highlight other languages until we figure out a robust way to parse out code samples
        }

        tokenize := get_tokenize_function(lang);
        if tokenize == null continue;
        tokenize(buffer, start, end - start);
    }

    #if DEBUG_BUILD_ERRORS for build_errors print("%\n", it);
}

get_pool_allocator :: inline () -> Allocator {
    return Allocator.{ proc = flat_pool_allocator_proc, data = *memory_pool };
}

can_go_to_build_error :: () -> bool {
    using last_command_result;

    if !finished { add_user_warning("No finished build command to parse errors from.", dismiss_in_seconds = 3, tag = .build); return false; }
    if error_regex_status == {
        case .failed_to_compile;
            add_user_warning("Error regex in the build command config failed to compile. Can't jump to errors. \nIf you change it, rerun the build command again.", dismiss_in_seconds = 5, tag = .build);
            return false;
        case .missing;
            add_user_warning("Error regex in the build command config is missing. Can't jump to errors.\nIf you add it, rerun the build command again.", dismiss_in_seconds = 5, tag = .build);
            return false;
    }
    if !build_errors { add_user_warning("No build errors found.", dismiss_in_seconds = 3, tag = .build); return false; }

    return true;
}

go_to_current_build_error :: (placement: Editor_Placement = .in_place, show_error := true) {
    using last_command_result;

    clear_user_messages(.build);

    current_build_error_id = clamp(current_build_error_id, 0, build_errors.count - 1);

    build_error := build_errors[current_build_error_id];

    // Select the error to see clearly what the current error is
    {
        editor, buffer := get_build_editor_and_buffer();
        cursor := leave_only_original_cursor(editor);
        cursor.sel = build_error.file_path_location.start;
        cursor.pos = build_error.file_path_location.end;
        if buffer.dirty then rescan_for_lines(buffer);
        select_line(cursor, buffer);
        editor.cursor_moved = true;
    }

    // Try to open the file, maybe by prepending the build dir and removing the "./" at the start
    tried_paths: [..] string;
    tried_paths.allocator = temp;
    path := copy_temporary_string(build_error.file);
    path_overwrite_separators(path, #char "/");
    if starts_with(path, "./") then advance(*path, 2);
    if !file_exists(path) && build_working_dir {
        array_add(*tried_paths, path);
        path = tprint("%/%", build_working_dir, path);
    }
    if !file_exists(path) {
        array_add(*tried_paths, path);
        message := tprint("Couldn't open %.", build_error.file);
        if tried_paths.count >= 2 then message = tprint("%\nTried the following paths:%", message, join(..tried_paths, separator = "\n- ", before_first = true));
        add_user_error(message, dismiss_in_seconds = 10);
        return;
    }

    success := editors_open_file(path, placement);
    if !success return;

    editor, buffer := get_active_editor_and_buffer();
    go_to_line(editor, buffer, build_error.line, build_error.col);

    if show_error {
        if #complete build_error.type == {
            case .error;    add_user_error(build_error.message, dismiss_in_seconds = 15, .build);
            case .warning;  #through;
            case .info;     add_user_warning(build_error.message, dismiss_in_seconds = 15, .build);
        }
    }
}

thread_group: Thread_Group;

build_buffer_id := -1;
build_editor_id := -1;

build_panel_is_expanded := false;

running_command := "";  // the name of the running command
running_process: Process;

last_command_result: struct {
    build: Command_Result;
    run:   Command_Result;
    finished := false;

    build_working_dir: string;  // for prepending to relative error paths
    build_errors: [..] Build_Error;  // allocated from pool
    output_range: Offset_Range;  // will contain the output range of the last command (either build or run), to be used in error parsing
    error_regex_status: enum { ok; failed_to_compile; missing; } = .ok;  // for better error messages
    current_build_error_id := -1;
};

memory_pool: Flat_Pool;

// To avoid potential crashes, the build thread will not write directly to the output buffer because it could be
// used by the main thread at the same time, and instead will use these string builders to buffer output,
// which the main thread will pick up at its convenience.
// We never write to buffers from threads, because if we did, a lot of code would have to be littered with locks.
stdout: String_Builder;
build_mutex: Mutex;

Build_Panel_Position :: enum { left; right; }

Build_Thread_Work :: struct {
    using command: Build_Command;
    // NOTE: there used to be more work data here which was later removed. Keeping it like this in case we need to add more data later
}

Command_Result :: struct {
    finished:        bool;
    timeout_reached: bool;
    process_result:  Process_Result;
    elapsed_seconds: float64;
}

Build_Error :: struct {
    file:     string;
    message:  string;
    line: s32 = -1;
    col:  s32 = -1;
    type: enum { error; warning; info; } = .error;
    file_path_location: Offset_Range;  // where in the build output the file path is (for double-click support)

    error_info_start_offset: s32;  // for code highlighting. We assume code might be in between the error info we've parsed
    error_info_end_offset:   s32;
}

MAX_BUILD_OUTPUT_BUFFER_SIZE :: 2 * 1024 * 1024;


DEBUG_BUILD_ERRORS :: false;


// Adapted the run_command function from the Process module to allow for monitoring output

run_command_while_monitoring_output :: (args: .. string, working_directory := "", timeout_ms := -1, arg_quoting := Process_Argument_Quoting.QUOTE_IF_NEEDED) -> (process_result: Process_Result, timeout_reached := false, elapsed_seconds: float64 = 0) {
    process  := *running_process;  // accessing a global! NOTE: this is assuming we only ever have one running command
    lock(*build_mutex);
    process.* = Process.{};
    unlock(*build_mutex);

    launched := create_process_with_single_output_pipe(process, .. args, working_directory, arg_quoting = arg_quoting);
    if !launched {
        executable := args[0];
        if is_absolute_path(executable) return .{type = .FAILED_TO_LAUNCH};
        // Retry with an absolute path if possible
        args[0] = tprint("%/%", working_directory, executable);
        launched := create_process_with_single_output_pipe(process, .. args, working_directory, arg_quoting = arg_quoting);
        if !launched return .{type = .FAILED_TO_LAUNCH};
    }
    defer {
        lock(*build_mutex);
        deinit(process);
        unlock(*build_mutex);
    }

    timeout_reached := false;

    start_time := current_time_monotonic();
    remaining_timeout_ms := timeout_ms;

    while true {
        output_buffer: [4 * 4096] u8;
        success, num_output_bytes := read_from_process(process, output_buffer, remaining_timeout_ms);

        if num_output_bytes {
            output_str := to_string(output_buffer.data, num_output_bytes);
            remove_crlf_in_place(*output_str);
            write_output_from_build_thread(*stdout, output_str);
            platform_wake_up_main_thread();
        }

        if !success {
            log_error("Could not read output of command \"%\"", get_quoted_command_string(args));
            kill_process(process);
            break;
        }

        if timeout_ms >= 0 {
            now := current_time_monotonic();
            remaining_timeout_ms = timeout_ms - to_milliseconds(now - start_time);

            if remaining_timeout_ms <= 0 {
                // We’ve hit a timeout! Time to kill the child. (will be reaped below)
                timeout_reached = true;
                success := kill_process(process);
                if !success {
                    error_code, error_string := get_error_value_and_string();
                    log_error("Could not kill child for command \"%\": % %", get_quoted_command_string(args), error_code, error_string);
                }
                break;
            }
        }

        if process.output.eof break;
    }

    elapsed_seconds := to_float64_seconds(current_time_monotonic() - start_time);

    success, process_result := get_process_result(process);
    if !success {
        error_code, error_string := get_error_value_and_string();
        log_error("Could not get process result for command \"%\": % %", get_quoted_command_string(args), error_code, error_string);
        kill_process(process);
        process_result = .{type = .EXITED, exit_code = 1};
    }

    return process_result, timeout_reached, elapsed_seconds;
}

write_output_from_build_thread :: (builder: *String_Builder, s: string) {
    if !s return;
    lock(*build_mutex);
    defer unlock(*build_mutex);
    append(builder, s);
}

#if OS == .WINDOWS {
    #load "build_system_windows.jai";
} else #if OS_IS_UNIX {
    #import,file "build_system_unix.jai";
}
