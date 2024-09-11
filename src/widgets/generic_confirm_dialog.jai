dialog_handle_event :: (dialog: *Generic_Confirm_Dialog, event: Input.Event) -> bool {
    assert(dialog.get_buttons != null, "Dialog struct is missing the get_buttons function");

    if event.type == .KEYBOARD && event.key_pressed {
        for button : dialog.get_buttons() {
            for key_code : button.key_codes {
                if event.key_code == key_code {
                    close_dialog(dialog, button.result);
                    return true;
                }
            }
        }
    }

    return false;
}

dialog_get_result :: (dialog: *Generic_Confirm_Dialog($Details), action_id: Deferred_Action_Id) -> Generic_Confirm_Dialog_Result {
    if action_id != dialog.triggered_by_action  return .UNINITTED;
    return dialog.result;
}

show_dialog :: (dialog: *Generic_Confirm_Dialog($Details), action_id: Deferred_Action_Id, details: Details) {
    dialog.result = .PENDING;
    dialog.triggered_by_action = action_id;
    if dialog.set_details {
        dialog.set_details(details);
    } else {
        dialog.details = details;
    }
    active_global_widget = dialog.global_widget_id;
    if dialog.on_show then dialog.on_show();
}

close_dialog :: (dialog: *Generic_Confirm_Dialog($Details), result: Generic_Confirm_Dialog_Result) {
    dialog.result = result;
    activate_editors();
    redraw_requested = true;
}

dialog_get_details :: (dialog: *Generic_Confirm_Dialog) -> Generic_Confirm_Dialog.Details {
    return dialog.details;
}

Generic_Confirm_Dialog :: struct(Details: Type) {
    triggered_by_action: Deferred_Action_Id = -1;
    result: Generic_Confirm_Dialog_Result = .UNINITTED;
    global_widget_id: Active_Global_Widget;

    using details: Details;

    set_details: (details: Details) -> ();
    get_buttons: () -> [] Generic_Confirm_Dialog_Button;  // this could've been a constant on the struct itself, but the compiler won't allow setting it for some reason, looks like a bug
    on_show:     () -> ();
}

Generic_Confirm_Dialog_Button :: struct {
    label: string;
    result: Generic_Confirm_Dialog_Result;
    key_codes: [] Input.Key_Code;
    color: Color;
    text_color: Color;
}

Generic_Confirm_Dialog_Result :: enum { UNINITTED; PENDING; OK; OK_TO_ALL; NO_TO_ALL; CANCEL; }
