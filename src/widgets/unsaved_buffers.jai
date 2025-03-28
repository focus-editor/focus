unsaved_buffers_dialog: Unsaved_Buffers_Dialog;

Unsaved_Buffers_Dialog :: struct {
    using #as generic_dialog: Generic_Confirm_Dialog(Dialog_Details);

    global_widget_id = .unsaved_buffers_dialog;
    get_buttons = dialog_get_buttons;
}


#scope_file

Dialog_Details :: struct { buffer_ids: [] s64; }

dialog_get_buttons :: () -> [] Generic_Confirm_Dialog_Button {
   // Doing some copypasta to return constants so that we don't have to allocate
   if unsaved_buffers_dialog.buffer_ids.count > 1 {
        return .[
            .{ "  Save All  ", .OK_TO_ALL, .[ #char "Y", #char "S", #char "A" ], Color.UI_WARNING, Color.UI_DEFAULT },
            .{ "Don't Save",   .NO_TO_ALL, .[ #char "D", #char "N" ],            Color.UI_ERROR,   Color.UI_DEFAULT },
            .{ "Cancel",       .CANCEL,    .[ .ESCAPE, #char "C" ],              Color.UI_NEUTRAL, Color.UI_DEFAULT },
        ];
    } else {
        return .[
            .{ "    Save    ", .OK_TO_ALL, .[ #char "Y", #char "S", #char "A" ], Color.UI_WARNING, Color.UI_DEFAULT },
            .{ "Don't Save",   .NO_TO_ALL, .[ #char "D", #char "N" ],            Color.UI_ERROR,   Color.UI_DEFAULT },
            .{ "Cancel",       .CANCEL,    .[ .ESCAPE, #char "C" ],              Color.UI_NEUTRAL, Color.UI_DEFAULT },
        ];
    }
}

