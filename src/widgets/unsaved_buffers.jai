unsaved_buffers_dialog_handle_event :: (event: Input.Event) -> bool {
    if event.type == .KEYBOARD && event.key_pressed {
        if event.key_code == {
            case .ESCAPE;       #through;
            case #char "C";     close_unsaved_buffers_dialog();     return true;
            case #char "Y";     #through;
            case #char "S";     unsaved_buffers_save_all();         return true;
            case #char "N";     unsaved_buffers_dialog_proceed();   return true;
        }
    }
    return false;
}

show_unsaved_buffers_dialog :: (requested_mode: Mode = .exit_program) {
    using unsaved_buffers_dialog;

    active_global_widget = .unsaved_buffers_dialog;
    mode = requested_mode;

    array_reset_keeping_memory(*modified_buffers);

    for buffer, buffer_id : open_buffers {
        if buffer.modified && !buffer.readonly && !buffer.internal array_add(*modified_buffers, buffer_id);
    }
}

close_unsaved_buffers_dialog :: () {
    array_reset_keeping_memory(*unsaved_buffers_dialog.modified_buffers);

    activate_editors();
}

unsaved_buffers_save_all :: () {
    should_proceed := true;

    for buffer_id : unsaved_buffers_dialog.modified_buffers {
        buffer := *open_buffers[buffer_id];

        if buffer.has_file {
            save_buffer(buffer, buffer_id);
            if buffer.error_when_saving then should_proceed = false;
        } else {
            if #complete unsaved_buffers_dialog.mode == {
                case .exit_program;         add_buffer_to_save_queue(buffer_id, after_save = .exit_program);
                case .reload_workspace;     add_buffer_to_save_queue(buffer_id, after_save = .reload_workspace);
            }
            should_proceed = false;
        }
    }

    if should_proceed unsaved_buffers_dialog_proceed();
}

unsaved_buffers_dialog_proceed :: () {
    if #complete unsaved_buffers_dialog.mode == {
        case .exit_program;
            force_quit  = true;
            should_quit = true;
        case .reload_workspace;
            should_reload_workspace = true;
    }

    close_unsaved_buffers_dialog();
}

#scope_export

unsaved_buffers_dialog: struct {
    modified_buffers: [..] s64;
    mode: Mode;
};

#scope_file

Mode :: enum {
    exit_program;
    reload_workspace;
}
