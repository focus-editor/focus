go_to_line_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    using go_to_line_dialog;

    if event.type == .KEYBOARD && event.key_pressed {
        action, mapping := map_event_to_action(event, Action_Search_Dialog);
        if action == {
            case .escape;                   #through;
            case .close_dialog;             close_go_to_line_dialog(jump_to_original_cursor = config.settings.can_cancel_go_to_line);
                                            return true;
            case .open_entry;               jump_to_line(); close_go_to_line_dialog(); return true;
            case .open_entry_in_side_pane;  jump_to_line(); close_go_to_line_dialog(); return true;
        }

        old_text := copy_temporary_string(to_string(input.text));

        handled := maybe_handle_text_input_event(*input, event);

        if old_text != to_string(input.text) then jump_to_line();

        return handled;

    } else if event.type == .TEXT_INPUT {
        char := event.utf32;
        if #char "0" <= char && char <= #char "9" {
            text_input_type_char(*input, char);
            jump_to_line();
        }
        return true;
    }
    return false;
}

show_go_to_line_dialog :: () {
    editor, buffer := get_active_editor_and_buffer();
    if !editor || !buffer return;

    active_global_widget = .go_to_line_dialog;

    using go_to_line_dialog;

    // Remember cursor position
    original_cursor_position = editor.cursors[editor.main_cursor];
    jumped = false;

    // Select text when opening
    input.cursor.sel = 0;
    input.cursor.pos = xx input.text.count;
}

close_go_to_line_dialog :: (jump_to_original_cursor := false) {
    using go_to_line_dialog;

    activate_editors();

    editor, buffer := get_active_editor_and_buffer();
    if !editor || !buffer return;

    if jump_to_original_cursor && jumped {
        cursor := leave_only_original_cursor(editor);
        cursor.* = original_cursor_position;
        editor.scroll_to_cursor = .yes;
    } else if jumped {
        // We should remove the selection that was only there for demonstration
        cursor := leave_only_original_cursor(editor);
        add_paste_animation(get_active_editor_id(), get_selection(cursor));
        cursor.sel = cursor.pos;
        editor.cursor_moved = true;
        editor.scroll_to_cursor = .yes;
    }
}


#scope_file

jump_to_line :: () {
    editor, buffer := get_visible_editor_and_buffer();
    if !editor || !buffer return;

    using go_to_line_dialog;

    if !input.text return;

    // Check for any non-digit characters
    for byte : input.text {
        if byte < #char "0" || #char "9" < byte {
            input_is_valid = false;
            return;
        }
    }

    input_is_valid = true;
    jumped = true;

    line_num := 0;

    // atoi
    n := 1;
    for < byte : input.text {
        digit := byte - #char "0";
        if digit > 9 || digit < 0 continue;
        line_num += digit * n;
        n *= 10;
    }

    go_to_line(editor, buffer, line_num);
}

maybe_handle_text_input_event :: (using input: *Text_Input, event: Input.Event) -> handled: bool {
    input_text := copy_temporary_string(to_string(text));
    handled := text_input_handle_event(input, event);
    if handled {
        if input_text != to_string(input.text) then jump_to_line();
        return true;
    }
    return false;
}

#scope_export

go_to_line_dialog: Go_To_Line_Dialog;

Go_To_Line_Dialog :: struct {
    scroll_to_cursor: Scroll_Mode = .no;
    original_cursor_position: Cursor;
    jumped := false;
    input_is_valid := true;

    input: Text_Input;
}
