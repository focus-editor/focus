go_to_line_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    using go_to_line_dialog;

    if event.type == .KEYBOARD && event.key_pressed {
        action, mapping := map_event_to_action(event, Action_Search_Dialog);
        if action == {
            case .close_dialog;             close_go_to_line_dialog(jump_to_original_cursor = config.settings.can_cancel_go_to_line);
                                            return true;
            case .open_entry_in_place;      close_go_to_line_dialog(); return true;
            case .open_entry_on_the_side;   close_go_to_line_dialog(); return true;
        }

        old_text := copy_temporary_string(to_string(input.text));

        handled := maybe_handle_text_input_event(*input, event);
        if handled {
            // Remove any non-digit bytes in case they were pasted
            new_text := to_bytes(copy_temporary_string(to_string(input.text)));
            i := 0;
            for byte : new_text {
                if #char "0" <= byte && byte <= #char "9" {
                    input.text[i] = byte;
                    i += 1;
                }
            }
            input.text.count = i;
            input.cursor.pos = clamp(input.cursor.pos, 0, xx i);
            input.cursor.sel = clamp(input.cursor.sel, 0, xx i);
        }

        if old_text != to_string(input.text) then jump_to_line();

        return handled;

    } else if event.type == .TEXT_INPUT {
        char := event.utf32;
        if char == 127 return true;  // there seems to be a bug in the Input module
                                // which generates a TEXT_INPUT event for DEL
                                // when Ctrl+Backspace is pressed

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
    original_cursor_position = editor.cursors[editor.main_cursor].state;
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
        cursor.state = original_cursor_position;
        editor.scroll_to_cursor = .yes;
    } else if jumped {
        // We should remove the selection that was only there for demonstration
        cursor := leave_only_original_cursor(editor);
        add_paste_animation(editor, get_selection(cursor));
        cursor.sel = cursor.pos;
        editor.cursor_moved = .jumped;
        editor.scroll_to_cursor = .yes;
    }
}

jump_to_line :: () {
    editor, buffer := get_active_editor_and_buffer();
    if !editor || !buffer return;

    using go_to_line_dialog;

    if !input.text return;

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

    line_num = clamp(line_num - 1, 0, get_max_real_line_num(buffer));
    line_start := get_real_line_start_offset(buffer, cast(s32)line_num);
    line_end   := get_real_line_end_offset  (buffer, cast(s32)line_num);

    cursor := leave_only_original_cursor(editor);
    cursor.pos = line_start + count_whitespace(buffer.bytes, line_start, line_end);
    cursor.sel = line_end;  // to make the line visible
    add_paste_animation(editor, get_selection(cursor));
    editor.cursor_moved = .jumped;
    editor.scroll_to_cursor = .yes;
}


#scope_file

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
    original_cursor_position: Cursor.State;
    jumped := false;

    input: Text_Input;
}
