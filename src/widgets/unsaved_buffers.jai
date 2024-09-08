unsaved_buffers_dialog_handle_event :: (event: Input.Event) -> bool {
    if event.type == .KEYBOARD && event.key_pressed {
        if event.key_code == {
            case .ESCAPE;       #through;
            case #char "C";     close_unsaved_buffers_dialog(.CANCEL);      return true;
            case #char "Y";     #through;
            case #char "S";     close_unsaved_buffers_dialog(.SAVE_ALL);    return true;
            case #char "N";     close_unsaved_buffers_dialog(.DONT_SAVE);   return true;
        }
    }
    return false;
}

unsaved_buffers_dialog_get_result :: (action_id: Deferred_Action_Id) -> Unsaved_Buffers_Dialog.Result {
    if action_id != dialog.triggered_by_action  return .UNINITTED;
    return dialog.result;
}

unsaved_buffers_dialog_get_buffer_ids :: () -> [] s64 {
    return dialog.modified_buffers;
}

show_unsaved_buffers_dialog :: (action_id: Deferred_Action_Id) {
    dialog.result = .PENDING;
    dialog.triggered_by_action = action_id;

    active_global_widget = .unsaved_buffers_dialog;

    array_reset_keeping_memory(*dialog.modified_buffers);

    for buffer, buffer_id : open_buffers {
        if buffer.modified && !buffer.readonly && !buffer.internal then array_add(*dialog.modified_buffers, buffer_id);
    }
}

close_unsaved_buffers_dialog :: (result: Unsaved_Buffers_Dialog.Result) {
    dialog.result = result;
    activate_editors();
    redraw_requested = true;
}


#scope_file

dialog: Unsaved_Buffers_Dialog;

Unsaved_Buffers_Dialog :: struct {
    modified_buffers: [..] s64;

    triggered_by_action: Deferred_Action_Id = -1;
    result: Result = .UNINITTED;

    Result :: enum {
        UNINITTED;
        PENDING;
        SAVE_ALL;
        DONT_SAVE;
        CANCEL;
    }
}

