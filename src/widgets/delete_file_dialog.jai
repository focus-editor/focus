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

show_delete_file_dialog :: (editor: *Editor, buffer: *Buffer) {
    if !buffer.has_file then return;   // Nothing to do if in new buffer

    editor_to_update = editor;
    buffer_to_delete = buffer;
    active_global_widget = .delete_file_dialog;
}

close_delete_file_dialog :: () {
    editor_to_update = null;
    buffer_to_delete = null;
    activate_editors();
}

delete_buffer_file_and_update_editor :: () {
    deleted := delete_buffer_from_disk(buffer_to_delete);
    if !deleted return; // TODO: handle delete fail

    maybe_mark_buffer_as_deleted(editor_to_update.buffer_id);   // check in case we missed that it's deleted
    session_notify_modified_buffer(editor_to_update.buffer_id); // @Cleanup? This doesn't seem to do anything.
    close_delete_file_dialog();
}

get_buffer_to_delete :: () -> *Buffer {
    return buffer_to_delete;
}

#scope_file

editor_to_update: *Editor;
buffer_to_delete: *Buffer;
