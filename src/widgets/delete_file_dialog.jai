delete_file_dialog_handle_event :: (event: Input.Event) -> bool {
    if event.type == .KEYBOARD && event.key_pressed {
        if event.key_code == {
            case .ESCAPE;   #through;
            case #char "N"; #through;
            case #char "C"; close_delete_file_dialog();             return true;

            case .ENTER; #through;
            case #char "Y"; delete_buffer_file_and_update_editor(); return true;
        }
    }
    return false;
}

show_delete_file_dialog :: (editor: *Editor) {
    // Not locking here because we're not modifying the buffer
    buffer := *open_buffers[editor.buffer_id];
    if !buffer.has_file then return;   // Nothing to do if in new buffer

    buffer_id_to_delete = editor.buffer_id;
    active_global_widget = .delete_file_dialog;
}

close_delete_file_dialog :: () {
    activate_editors();
}

delete_buffer_file_and_update_editor :: () {
    buffer_to_delete := *open_buffers[buffer_id_to_delete];
    deleted := delete_buffer_from_disk(buffer_to_delete);
    if !deleted return; // TODO: handle delete fail

    for e : open_editors {
        if e.buffer_id != buffer_id_to_delete then continue;

        maybe_mark_buffer_as_deleted(e.buffer_id);   // check in case we missed that it's deleted
        session_notify_modified_buffer(e.buffer_id);
        close_delete_file_dialog();
    }
}

get_buffer_id_to_delete :: () -> s64 {
    return buffer_id_to_delete;
}

#scope_file

buffer_id_to_delete: s64;
