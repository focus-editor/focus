execute_deferred_actions :: () {
    while true {
        result := execute_top_action();
        if #complete result == {
            case .WAIT;     break;      // continue the main editor loop
            case .NEXT;                 // proceed without removing top action
            case .DONE;     remove_top_action();
            case .CANCEL;   cancel_action_queue();
        }
    }
}

defer_action_switch_to_project :: (path: string) {
    push_action(.reload_workspace, .{ reload_workspace = .{ automatic = false } });
    push_action(.load_project_config, .{ load_project_config = .{ path = copy_string(path) } });
    push_action(.save_all_buffers);
    push_action(.kill_running_command);
}

defer_action_reload_workspace :: (automatic: bool) {
    push_action(.reload_workspace, .{ reload_workspace = .{ automatic = automatic } });
    push_action(.save_all_buffers);
    push_action(.kill_running_command);
}

defer_action_close_project :: () {
    push_action(.reload_workspace, .{ reload_workspace = .{ automatic = false } });
    push_action(.close_project);
    push_action(.save_all_buffers);
    push_action(.kill_running_command);
}

defer_action_quit :: () {
    push_action(.quit);
    push_action(.save_all_buffers);
    push_action(.kill_running_command);
    redraw_requested = true;
}

defer_action_save_as :: (buffer_id: s64) {
    push_action(.save_as, .{ save_as = .{ buffer_id = buffer_id } });
    redraw_requested = true;
}

defer_action_move :: (buffer_id: s64) {
    push_action(.save_as, .{ save_as = .{ buffer_id = buffer_id, is_move = true } });
    redraw_requested = true;
}


Deferred_Action_Id :: #type,distinct s64;


#scope_file

push_action :: (kind: Deferred_Action.Kind, details: Deferred_Action.Details = .{}) {
    last_action_id += 1;

    array_add(*actions, .{ id = last_action_id, kind = kind, details = details});
}

execute_top_action :: () -> Action_Result {
    if !actions return .WAIT;

    action := actions[actions.count-1];
    if #complete action.kind == {
        case .quit;                     return execute_quit(action);
        case .save_as;                  return execute_save_as(action);
        case .save_all_buffers;         return execute_save_all_buffers(action);
        case .confirm_overwrite;        return execute_confirm_overwrite(action);
        case .kill_running_command;     return execute_kill_running_command(action);
        case .load_project_config;      return execute_load_project_config(action);
        case .close_project;            return execute_close_project(action);
        case .reload_workspace;         return execute_reload_workspace(action);
    }
}

remove_top_action :: () {
    // actions.count = max(actions.count - 1, 0);
    action := pop(*actions);

    if #complete action.kind == {
        case .load_project_config;
            using action.details.load_project_config;
            if path { free(path); path = ""; }

        case .confirm_overwrite;
            using action.details.confirm_overwrite;
            if file_path { free(file_path); file_path = ""; }

        // Nothing to free
        case .quit;
        case .save_as;
        case .save_all_buffers;
        case .kill_running_command;
        case .reload_workspace;
        case .close_project;
    }
}

cancel_action_queue :: () {
    while actions  remove_top_action();
}

actions: [..] Deferred_Action;
last_action_id: Deferred_Action_Id = -1;

Deferred_Action :: struct {
    id: Deferred_Action_Id;
    kind: Kind;
    using details: Details;

    Details :: union {
        save_as:                struct { buffer_id: s64; is_move: bool; }
        confirm_overwrite:      struct { buffer_id: s64; is_move: bool; file_path: string; }
        load_project_config:    struct { path: string; }
        reload_workspace:       struct { automatic: bool; }
    }

    Kind :: enum {
        quit;
        save_as;
        save_all_buffers;
        confirm_overwrite;
        kill_running_command;
        load_project_config;
        close_project;
        reload_workspace;
    }
}

Action_Result :: enum {
    DONE;
    NEXT;
    CANCEL;
    WAIT;
}


//
// Actual commands that do something:
//

execute_quit :: (action: Deferred_Action) -> Action_Result {
    should_quit = true;
    return .DONE;
}

execute_save_all_buffers :: (action: Deferred_Action) -> Action_Result {
    result := unsaved_buffers_dialog_get_result(action.id);
    if #complete result == {
        case .UNINITTED;
            if unsaved_buffers_exist() {
                show_unsaved_buffers_dialog(action.id);
                return .WAIT;
            }
            return .DONE;
        case .SAVE_ALL;
            remove_top_action();
            save_all();
            return .NEXT;

        case .PENDING;   return .WAIT;
        case .DONT_SAVE; return .DONE;
        case .CANCEL;    return .CANCEL;
    }
}

execute_save_as :: (action: Deferred_Action) -> Action_Result {
    using action.details.save_as;

    buffer := *open_buffers[buffer_id];
    if is_move && !buffer.has_file then is_move = false;  // if we attempt to move a buffer without a file, save as instead

    _save_to_file_path :: (buffer: *Buffer, buffer_id: s64, file_path: string, is_move: bool) -> Action_Result {
        if file_exists(file_path) {
            remove_top_action();
            push_action(.confirm_overwrite, .{ confirm_overwrite = .{ buffer_id = buffer_id, is_move = is_move, file_path = copy_string(file_path) } });
            return .NEXT;
        } else {
            save_buffer_to_file(buffer, buffer_id, file_path);
            if buffer.error_when_saving {
                add_user_error("Unable to save file into '%'", file_path);
                return .CANCEL;
            }
            if is_move {
                deleted := delete_buffer_from_disk(buffer);
                if !deleted then add_user_error("Couldn't delete the original file '%'", buffer.file.full_path);
            }
            return .DONE;
        }
    }

    if OS == .WINDOWS && config.settings.prefer_system_file_dialogs {
        file_path, success := platform_get_save_file_name(get_buffer_name(buffer));
        if !success return .CANCEL;  // the user did not select a file
        return _save_to_file_path(buffer, buffer_id, file_path, is_move);
    }

    result, file_path := open_file_dialog_get_result(action.id);
    if #complete result == {
        case .UNINITTED;
            show_open_file_dialog(ifx is_move then .move else .save, buffer_id, triggered_by = action.id);
            return .WAIT;

        case .SELECTED_PATH;
            return _save_to_file_path(buffer, buffer_id, file_path, is_move);

        case .PENDING;   return .WAIT;
        case .CANCEL;    return .CANCEL;
    }

    return .DONE;
}

execute_confirm_overwrite :: (action: Deferred_Action) -> Action_Result {
    using action.details.confirm_overwrite;

    result := confirm_overwrite_dialog_get_result(action.id);
    if #complete result == {
        case .UNINITTED;
            show_confirm_overwrite_dialog(file_path, action.id);
            return .WAIT;

        case .YES;
            buffer := *open_buffers[buffer_id];

            if buffer.has_file && platform_path_equals(buffer.file.full_path, file_path) {
                // The user selected the same file as a target. Just save.
                save_buffer(buffer, buffer_id);
            } else {
                save_buffer_to_file(buffer, buffer_id, file_path);
                if buffer.error_when_saving {
                    add_user_error("Unable to save file into '%'", file_path);
                    return .CANCEL;
                }
                if is_move {
                    deleted := delete_buffer_from_disk(buffer);
                    if !deleted then add_user_error("Couldn't delete the original file '%'", buffer.file.full_path);
                }
            }
            return .DONE;

        case .PENDING;   return .WAIT;
        case .NO;        return .CANCEL;
    }
}

execute_kill_running_command :: (action: Deferred_Action) -> Action_Result {
    if build_command_is_running() {
        // TODO: add an option to auto-kill commands without showing a dialog
        add_user_warning("A build command is currently running. Please kill it or let it finish before proceeding.");
        return .CANCEL;
    }
    return .DONE;
}

execute_load_project_config :: (action: Deferred_Action) -> Action_Result {
    path := action.details.load_project_config.path;
    success := load_project_config(path, force = true);
    if !success {
        add_user_error("Couldn't load project config from '%'", path, dismiss_in_seconds = 10, tag = .config);
        return .CANCEL;
    }
    return .DONE;
}

execute_close_project :: (action: Deferred_Action) -> Action_Result {
    success := load_global_config(force = true);
    if !success {
        add_user_error("Couldn't close project because the global config failed to load", dismiss_in_seconds = 10, tag = .config);
        return .CANCEL;
    }
    project_config.loaded = false;
    return .DONE;
}

execute_reload_workspace :: (action: Deferred_Action) -> Action_Result {
    reload_workspace(action.details.reload_workspace.automatic);
    return .CANCEL;
}


