unsaved_buffers_dialog_handle_event :: (event: Input.Event) {
    if event.type == .KEYBOARD && event.key_pressed {
        if event.key_code == .ESCAPE {
            close_unsaved_buffers_dialog();
            return;
        }
    }
}

show_unsaved_buffers_dialog :: () {
    active_global_widget = .unsaved_buffers_dialog;

    array_reset_keeping_memory(*modified_buffers);

    for buffer, buffer_id : open_buffers {
        if buffer.modified && !buffer.readonly array_add(*modified_buffers, buffer_id);
    }
}

close_unsaved_buffers_dialog :: () {
    array_reset_keeping_memory(*modified_buffers);

    activate_editors();
}

unsaved_buffers_dialog_proceed :: () {
    // TODO: other modes
    should_quit = true;

    close_unsaved_buffers_dialog();
}

get_unsaved_buffer_ids :: () -> [] s64 {
    return modified_buffers;
}


#scope_export

modified_buffers: [..] s64;
