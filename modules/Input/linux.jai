set_custom_cursor_handling :: (is_custom: bool) {
    // @Incomplete: Implement this.
    // Use this if you are doing immediate-mode API stuff that sets cursors and want to prevent cursors from
    // flickering. Windows is annoying to interface with.
}

update_window_events :: () {
    input_per_frame_event_and_flag_update();
    LD.update_window_events();
}

add_resize_record :: (hwnd: Window_Type, width: s32, height: s32) {
    record: *Window_Resize_Record;

    for * pending_resizes {
        if it.window == hwnd {
            record = it;
            break;
        }
    }

    if !record {
        record = array_add(*pending_resizes);
    }

    record.window = hwnd;
    record.width = width;
    record.height = height;
}

#scope_file
LD :: #import "Linux_Display";
#assert(LD.JAI_STDLIB_INTEROP);
