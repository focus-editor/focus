unsaved_buffers_dialog_handle_event :: (event: Input.Event) {
    if event.type == .KEYBOARD && event.key_pressed {
        if event.key_code == {
            case .ESCAPE;       #through;
            case #char "C";     close_unsaved_buffers_dialog();     return;
            case #char "Y";     #through;
            case #char "S";     unsaved_buffers_save_all();         return;
            case #char "N";     unsaved_buffers_dialog_proceed();   return;
        }
    }
}

show_unsaved_buffers_dialog :: (requested_mode: Mode = .exit_program) {
    active_global_widget = .unsaved_buffers_dialog;
    mode = requested_mode;

    array_reset_keeping_memory(*modified_buffers);

    for buffer, buffer_id : open_buffers {
        if buffer.modified && !buffer.readonly array_add(*modified_buffers, buffer_id);
    }
}

close_unsaved_buffers_dialog :: () {
    array_reset_keeping_memory(*modified_buffers);

    activate_editors();
}

unsaved_buffers_save_all :: () {
    unsaved_buffers := get_unsaved_buffer_ids();
    errors_when_saving := false;
    for buffer_id : unsaved_buffers {
        buffer := *open_buffers[buffer_id];
        saved := save_buffer_to_disk(buffer, buffer_id);
        if buffer.error_when_saving || !saved then errors_when_saving = true;
    }
    if !errors_when_saving unsaved_buffers_dialog_proceed();
}

unsaved_buffers_dialog_proceed :: () {
    if mode == .exit_program {
        force_quit  = true;
        should_quit = true;
    } else {
        should_reload_workspace = true;
    }

    close_unsaved_buffers_dialog();
}

get_unsaved_buffer_ids :: () -> [] s64 {
    return modified_buffers;
}


#scope_file

modified_buffers: [..] s64;
mode: Mode;

Mode :: enum {
    exit_program;
    reload_workspace;
}
