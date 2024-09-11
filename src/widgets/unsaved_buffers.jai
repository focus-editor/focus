unsaved_buffers_dialog: Unsaved_Buffers_Dialog;

Unsaved_Buffers_Dialog :: struct {
    using #as generic_dialog: Generic_Confirm_Dialog(Dialog_Details);

    global_widget_id = .unsaved_buffers_dialog;
    get_buttons = dialog_get_buttons;
    on_show = dialog_on_show;

    unsaved_buffer_ids: [..] s64;
}


#scope_file

Dialog_Details :: struct { }

dialog_get_buttons :: () -> [] Generic_Confirm_Dialog_Button {
   // Doing some copypasta to return constants so that we don't have to allocate
   if unsaved_buffers_dialog.unsaved_buffer_ids.count > 1 {
        return .[
            .{ "  Save All  ", .OK_TO_ALL, .[ .ENTER,  #char "Y", #char "S", #char "A" ], Color.UI_WARNING, Color.UI_DEFAULT },
            .{ "Don't Save",   .NO_TO_ALL, .[ .ENTER,  #char "D", #char "N" ],            Color.UI_ERROR,   Color.UI_DEFAULT },
            .{ "Cancel",       .CANCEL,    .[ .ESCAPE, #char "C" ],                       Color.UI_NEUTRAL, Color.UI_DEFAULT },
        ];
    } else {
        return .[
            .{ "    Save    ", .OK_TO_ALL, .[ .ENTER,  #char "Y", #char "S", #char "A" ], Color.UI_WARNING, Color.UI_DEFAULT },
            .{ "Don't Save",   .NO_TO_ALL, .[ .ENTER,  #char "D", #char "N" ],            Color.UI_ERROR,   Color.UI_DEFAULT },
            .{ "Cancel",       .CANCEL,    .[ .ESCAPE, #char "C" ],                       Color.UI_NEUTRAL, Color.UI_DEFAULT },
        ];
    }
}

dialog_on_show :: () {
    array_reset_keeping_memory(*unsaved_buffers_dialog.unsaved_buffer_ids);

    for buffer, buffer_id : open_buffers {
        if is_unsaved(buffer) then array_add(*unsaved_buffers_dialog.unsaved_buffer_ids, buffer_id);
    }
}

