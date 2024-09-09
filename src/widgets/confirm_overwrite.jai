confirm_overwrite_dialog: Confirm_Overwrite_Dialog;

Confirm_Overwrite_Dialog :: struct {
    using #as generic_dialog: Generic_Confirm_Dialog(Confirm_Overwrite_Details);

    global_widget_id = .confirm_overwrite_dialog;
    set_details = dialog_set_details;
    get_buttons = dialog_get_buttons;
}

#scope_file

Confirm_Overwrite_Details :: struct { path: string; }

dialog_set_details :: (details: Confirm_Overwrite_Details) {
    if confirm_overwrite_dialog.path then free(confirm_overwrite_dialog.path);
    confirm_overwrite_dialog.path = copy_string(details.path);
}

dialog_get_buttons :: () -> [] Generic_Confirm_Dialog_Button {
    return .[
        .{ "Overwrite", .OK,     .[ .ENTER,  #char "Y", #char "O" ], Color.UI_WARNING, Color.UI_DEFAULT },
        .{ "Cancel",    .CANCEL, .[ .ESCAPE, #char "N", #char "C" ], Color.UI_NEUTRAL, Color.UI_DEFAULT },
    ];
}
