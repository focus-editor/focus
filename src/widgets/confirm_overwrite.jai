confirm_overwrite_dialog_handle_event :: (event: Input.Event) -> bool {
    if event.type == .KEYBOARD && event.key_pressed {
        if event.key_code == {
            case .ESCAPE;       #through;
            case #char "N";     #through;
            case #char "C";     close_confirm_overwrite_dialog(.NO);   return true;

            case .ENTER;        #through;
            case #char "Y";     #through;
            case #char "O";     close_confirm_overwrite_dialog(.YES); return true;
        }
    }
    return false;
}

confirm_overwrite_dialog_get_result :: (action_id: Deferred_Action_Id) -> Confirm_Overwrite_Dialog.Result {
    if action_id != dialog.triggered_by_action  return .UNINITTED;
    return dialog.result;
}

show_confirm_overwrite_dialog :: (path: string, action_id: Deferred_Action_Id) {
    dialog.result = .PENDING;
    dialog.triggered_by_action = action_id;

    if dialog.path then free(dialog.path);
    dialog.path = copy_string(path);

    active_global_widget = .confirm_overwrite_dialog;
}

close_confirm_overwrite_dialog :: (result: Confirm_Overwrite_Dialog.Result) {
    dialog.result = result;
    activate_editors();
    redraw_requested = true;
}

confirm_overwrite_dialog_get_path :: () -> string {
    return dialog.path;
}

#scope_file

dialog: Confirm_Overwrite_Dialog;

Confirm_Overwrite_Dialog :: struct {
    buffer_id: s64;
    path: string;

    triggered_by_action: Deferred_Action_Id = -1;
    result: Result = .UNINITTED;

    Result :: enum {
        UNINITTED;
        PENDING;
        YES;
        NO;
    }
}

