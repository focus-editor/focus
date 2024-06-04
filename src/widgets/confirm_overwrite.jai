confirm_overwrite_dialog_handle_event :: (event: Input.Event) -> bool {
    if event.type == .KEYBOARD && event.key_pressed {
        if event.key_code == {
            case .ESCAPE;       #through;
            case #char "N";     #through;
            case #char "C";     close_confirm_overwrite_dialog();   return true;

            case .ENTER;        #through;
            case #char "Y";     #through;
            case #char "O";     confirm_overwrite_dialog_proceed(); return true;
        }
    }
    return false;
}

show_confirm_overwrite_dialog :: (buffer_id: s64, path: string) {
    active_global_widget = .confirm_overwrite_dialog;

    confirm_overwrite_dialog.buffer_id = buffer_id;
    confirm_overwrite_dialog.path = path;
}

close_confirm_overwrite_dialog :: () {
    activate_editors();
}

confirm_overwrite_dialog_proceed :: () {
    using confirm_overwrite_dialog;

    buffer := *open_buffers[buffer_id];

    save_buffer_to_file(buffer, buffer_id, path);

    remove_buffer_from_save_queue(buffer_id);

    close_confirm_overwrite_dialog();
}

#scope_export

confirm_overwrite_dialog: struct {
    buffer_id: s64;
    path: string;
};
