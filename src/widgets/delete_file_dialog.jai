delete_file_dialog: Delete_File_Dialog;

Delete_File_Dialog :: struct {
    using #as generic_dialog: Generic_Confirm_Dialog(Delete_File_Details);

    global_widget_id = .delete_file_dialog;
    get_buttons = dialog_get_buttons;
}

#scope_file

Delete_File_Details :: struct { buffer_id: s64; }

dialog_get_buttons :: () -> [] Generic_Confirm_Dialog_Button {
    return .[
        .{ "Delete", .OK,     .[ #char "Y", #char "D" ], Color.UI_ERROR,   Color.UI_DEFAULT },
        .{ "Cancel", .CANCEL, .[ .ESCAPE, #char "N", #char "C" ], Color.UI_NEUTRAL, Color.UI_DEFAULT },
    ];
}
