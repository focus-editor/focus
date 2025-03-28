kill_running_command_dialog: Kill_Running_Command_Dialog;

Kill_Running_Command_Dialog :: struct {
    using #as generic_dialog: Generic_Confirm_Dialog(Dialog_Details);

    global_widget_id = .kill_running_command_dialog;
    get_buttons = dialog_get_buttons;
}

#scope_file

Dialog_Details :: struct { }

dialog_get_buttons :: () -> [] Generic_Confirm_Dialog_Button {
    return .[
        .{ "Kill And Proceed", .OK,     .[ #char "Y", #char "K" ], Color.UI_ERROR,   Color.UI_DEFAULT },
        .{ "Cancel",           .CANCEL, .[ .ESCAPE, #char "N", #char "C" ], Color.UI_NEUTRAL, Color.UI_DEFAULT },
    ];
}
