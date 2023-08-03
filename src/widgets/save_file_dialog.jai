save_file_dialog_handle_event :: (event: Input.Event) -> handled: bool {
    using save_file_dialog;

    if event.type == .KEYBOARD && event.key_pressed {
        if event.key_code ==  {
            case .ESCAPE; hide_save_file_dialog(); return true;
            case .ENTER; {
                file_path := copy_temporary_string(to_string(input.text));

                if save_new_file {
                    // Save the file BEFORE making a new buffer so find_or_create_buffer can find it
                    if config.settings.strip_trailing_whitespace_on_save then strip_trailing_whitespace(buffer, buffer_id);

                    success := write_entire_file(file_path, to_string(buffer.bytes));
                    if !success then return false;

                    new_id, created := find_or_create_buffer(file_path);
                    redraw_requested = true;

                    // Reroute all editors using the old id
                    for * editor : open_editors {
                        if editor.buffer_id == buffer_id {
                            editor.buffer_id = new_id;
                            editor.scroll_to_cursor = .yes;
                            for * cursor : editor.cursors { put_cursor_in_valid_spot(cursor, buffer); }
                            organise_cursors(editor);
                        }
                    }

                    if !file_is_watched(file_path) then start_watching_file(file_path);
                    update_window_title(open_editors[editors.active].buffer_id);
                    hide_save_file_dialog();
                    return true;
                } else {
                    using buffer;

                    if !has_file {
                        has_file = true;
                        file = get_file_info_from_full_path(file_path);
                        set_lang_from_path(buffer, file_path);
                        needs_coloring = true;
                        redraw_requested = true;

                        lock(*open_buffers_lock);
                        {
                            existing_buffer_id, found_existing := table_find(*buffers_table, file_path);
                            if found_existing {
                                if buffer_id != existing_buffer_id {
                                    // The user chose to save the new buffer into an existing file. OK.
                                    // Mark the old buffer as deleted and use the new one
                                    removed := table_remove(*buffers_table, file_path);
                                    assert(removed, "For some reason table_remove failed. This is a very unexpected bug.");
                                    existing_buffer := *open_buffers[existing_buffer_id];
                                    existing_buffer.deleted  = true;
                                    existing_buffer.modified = false;
                                    existing_buffer.modified_on_disk = false;

                                    // Reroute all editors which use it to the new buffer id
                                    for * editor : open_editors {
                                        if editor.buffer_id == existing_buffer_id {
                                            editor.buffer_id = buffer_id;
                                            editor.scroll_to_cursor = .yes;
                                            for * cursor : editor.cursors { put_cursor_in_valid_spot(cursor, buffer); }
                                            organise_cursors(editor);
                                        }
                                    }
                                } else {
                                    assert(false, "Buffer without a file somehow got into the buffers hash table. This is a bug.");
                                }
                            }

                            table_add(*buffers_table, copy_string(file_path), buffer_id);
                        }
                        unlock(*open_buffers_lock);

                        if !file_is_watched(file_path) then start_watching_file(file_path);
                    }

                    if config.settings.strip_trailing_whitespace_on_save then strip_trailing_whitespace(buffer, buffer_id);

                    success := write_entire_file(file.full_path, to_string(bytes));
                    if success {
                        modified = false;
                        modified_on_disk = false;
                        deleted = false;

                        meow_hash = calculate_meow_hash(bytes);

                        error_when_saving = false;
                        crlf = false;
                    } else {
                        error_when_saving = true;
                    }
                    remember_last_modtime_and_size(buffer);
                    update_window_title(open_editors[editors.active].buffer_id);

                    hide_save_file_dialog();
                    return !error_when_saving;
                }
            }
        }
        return text_input_handle_event(*input, event);
    } else if event.type == .TEXT_INPUT {
        char := event.utf32;
        if char == 127 return true;  // there seems to be a bug in the Input module
                                // which generates a TEXT_INPUT event for DEL
                                // when Ctrl+Backspace is pressed
        text_input_type_char(*save_file_dialog.input, char);
    }

    return false;
}

show_save_file_dialog :: (buffer: *Buffer, buffer_id: s64, save_new_file: bool) {
    active_global_widget = .save_file_dialog;
    save_file_dialog.buffer = buffer;
    save_file_dialog.buffer_id = buffer_id;
    save_file_dialog.save_new_file = save_new_file;
}

hide_save_file_dialog :: () {
    activate_editors();
}

save_file_dialog: Save_File_Dialog;

#scope_file

Save_File_Dialog :: struct {
    input: Text_Input;
    width_percentage := WIDTH_NORMAL;  // how much of the screen the popup occupies
    width_anim := #run Tween_Animation(float).{ start = WIDTH_NORMAL, target = WIDTH_NORMAL };
    WIDTH_NORMAL   :: 0.4;
    buffer: *Buffer;
    buffer_id: s64;
    save_new_file: bool;
}
