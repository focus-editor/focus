execute_deferred_actions :: () {
    while true {
        result := execute_top_action();
        if #complete result == {
            case .WAIT;     break;      // continue the main editor loop
            case .NEXT;                 // proceed without removing top action
            case .DONE;     remove_top_action();
            case .CANCEL;   clear_action_queue();
        }
    }
}

defer_action_switch_to_project :: (path: string) {
    clear_action_queue();
    push_action(.reload_workspace, .{ reload_workspace = .{ automatic = false } });
    push_action(.load_project_config, .{ load_project_config = .{ path = copy_string(path) } });
    push_action(.kill_running_command);
    push_action(.save_all_buffers);
}

defer_action_reload_workspace :: (automatic: bool) {
    clear_action_queue();
    push_action(.reload_workspace, .{ reload_workspace = .{ automatic = automatic } });
    push_action(.kill_running_command);
    push_action(.save_all_buffers);
}

defer_action_close_project :: () {
    clear_action_queue();
    push_action(.reload_workspace, .{ reload_workspace = .{ automatic = false } });
    push_action(.close_project);
    push_action(.kill_running_command);
    push_action(.save_all_buffers);
}

defer_action_quit :: () {
    clear_action_queue();
    push_action(.quit);
    push_action(.kill_running_command);
    push_action(.save_all_buffers);
}

defer_action_build_command :: (command_id: s64) {
    clear_action_queue();
    push_action(.build_command, .{ build_command = .{ command_id = command_id } });
    push_action(.kill_running_command);
    push_action(.wait_for_workspace_scanning_to_finish);
}

defer_action_save_as :: (buffer_id: s64) {
    push_action(.save_as, .{ save_as = .{ buffer_id = buffer_id } });
}

defer_action_move :: (buffer_id: s64) {
    push_action(.save_as, .{ save_as = .{ buffer_id = buffer_id, is_move = true } });
}

defer_action_delete :: (buffer_id: s64) {
    push_action(.delete, .{ delete = .{ buffer_id = buffer_id } });
}


Deferred_Action_Id :: #type,distinct s64;


#scope_file

push_action :: (kind: Deferred_Action.Kind, details: Deferred_Action.Details = .{}) {
    last_action_id += 1;

    array_add(*actions, .{ id = last_action_id, kind = kind, details = details});

    redraw_requested = true;  // if we push an action during drawing we have to redraw
}

execute_top_action :: () -> Action_Result {
    if !actions return .WAIT;

    action := actions[actions.count-1];
    if #complete action.kind == {
        case .quit;                                     return execute_quit(action);
        case .save_as;                                  return execute_save_as(action);
        case .save_all_buffers;                         return execute_save_all_buffers(action);
        case .delete;                                   return execute_delete(action);
        case .confirm_overwrite;                        return execute_confirm_overwrite(action);
        case .kill_running_command;                     return execute_kill_running_command(action);
        case .load_project_config;                      return execute_load_project_config(action);
        case .close_project;                            return execute_close_project(action);
        case .reload_workspace;                         return execute_reload_workspace(action);
        case .build_command;                            return execute_build_command(action);
        case .wait_for_workspace_scanning_to_finish;    return execute_wait_for_scanning(action);
    }
}

remove_top_action :: () {
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
        case .delete;
        case .kill_running_command;
        case .reload_workspace;
        case .close_project;
        case .build_command;
        case .wait_for_workspace_scanning_to_finish;
    }
}

clear_action_queue :: () {
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
        delete:                 struct { buffer_id: s64; }
        load_project_config:    struct { path: string; }
        reload_workspace:       struct { automatic: bool; }
        build_command:          struct { command_id: s64; }
    }

    Kind :: enum {
        quit;
        save_as;
        save_all_buffers;
        delete;
        confirm_overwrite;
        kill_running_command;
        build_command;
        load_project_config;
        close_project;
        reload_workspace;
        wait_for_workspace_scanning_to_finish;
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
    result := dialog_get_result(*unsaved_buffers_dialog, action.id);
    if #complete result == {
        case .UNINITTED;
            if unsaved_buffers_exist() {
                show_dialog(*unsaved_buffers_dialog, action.id, .{});
                return .WAIT;
            }
            return .DONE;

        case .OK_TO_ALL; #through;
        case .OK;
            remove_top_action();
            save_all();
            return .NEXT;

        case .NO_TO_ALL; return .DONE;
        case .PENDING;   return .WAIT;
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

execute_delete :: (action: Deferred_Action) -> Action_Result {
    using action.details.delete;

    buffer := *open_buffers[buffer_id];
    if buffer.readonly  { add_user_warning("Can't delete a readonly buffer"); return .CANCEL; }
    if !buffer.has_file { close_editors_for_buffer(buffer_id); return .DONE; }  // no one cares it doesn't have a file, they just want it gone

    result := dialog_get_result(*delete_file_dialog, action.id);
    if #complete result == {
        case .UNINITTED;
            show_dialog(*delete_file_dialog, action.id, .{ buffer_id = buffer_id });
            return .WAIT;

        case .OK_TO_ALL; #through;
        case .OK;        #through;
        case .NO_TO_ALL;
            deleted := delete_buffer_from_disk(buffer);
            if !deleted {
                add_user_error("Couldn't delete file '%'", buffer.file.full_path);
                return .CANCEL;
            }
            add_success_message("File '%' has been deleted", buffer.file.full_path, dismiss_in_seconds = 3);
            close_editors_for_buffer(buffer_id);
            return .DONE;

        case .PENDING;   return .WAIT;
        case .CANCEL;    return .CANCEL;
    }
}

execute_confirm_overwrite :: (action: Deferred_Action) -> Action_Result {
    using action.details.confirm_overwrite;

    result := dialog_get_result(*confirm_overwrite_dialog, action.id);
    if #complete result == {
        case .UNINITTED;
            show_dialog(*confirm_overwrite_dialog, action.id, .{ path = file_path });
            return .WAIT;

        case .OK_TO_ALL; #through;
        case .OK;        #through;
        case .NO_TO_ALL;
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
        case .CANCEL;    return .CANCEL;
    }
}

execute_kill_running_command :: (action: Deferred_Action) -> Action_Result {
    if !build_get_running_command_name() return .DONE;

    result := dialog_get_result(*kill_running_command_dialog, action.id);
    if #complete result == {
        case .UNINITTED;
            show_dialog(*kill_running_command_dialog, action.id, .{ });
            return .WAIT;

        case .OK_TO_ALL; #through;
        case .OK;        #through;
        case .NO_TO_ALL;
            build_kill_running_command();
            kill_running_command_dialog.result = .PENDING;
            redraw_requested = true;
            return .WAIT;

        case .PENDING;   return .WAIT;
        case .CANCEL;    return .CANCEL;
    }
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
    return .CANCEL;  // final command
}

execute_build_command :: (action: Deferred_Action) -> Action_Result {
    command_id := action.details.build_command.command_id;
    command := ifx command_id > 0 then *config.build.commands[command_id-1] else *config.build.defaults;
    execute_build_command(command);
    return .CANCEL;  // final command
}

execute_wait_for_scanning :: (action: Deferred_Action) -> Action_Result {
    clear_user_messages(.build);
    if !workspace_scan_complete {
        add_user_warning("Waiting for the workspace scan to finish...", tag = .build);
        return .WAIT;
    }
    return .DONE;
}


