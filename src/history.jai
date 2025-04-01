maybe_save_editor_history :: () {
    // if editor_closing_id >= 0 return;

    // using editor_history;

    // // Set the initial size and then handle potential editor history size changes in case someone edits the config
    // if frames.count != config.settings.editor_history_size {
    //     array_resize(*frames, config.settings.editor_history_size);
    //     initted = false;
    // }

    // editor, buffer := get_active_editor_and_buffer();

    // frame := Editor_History_Frame.{
    //     editor_state = editors,
    //     pos = ifx editor then editor.cursors[editor.main_cursor].pos else 0,
    //     cursor_movement = ifx editor then editor.cursor_moved else .has_not_moved,
    // };

    // if !initted {
    //     initted = true;
    //     start, end, current = 0;
    //     frames[current] = frame;
    //     return;
    // }

    // if editor && editor.cursor_moved == .refresh_only || frames[current] == frame return;

    // previous_index := current;
    // current = next_history_index(current);
    // num_previous_frames := ifx start <= current then current - start else frames.count - start + current;

    // should_merge_frame := false;
    // previous_frame := frames[previous_index];
    // if frames_are_mergeable(frame, previous_frame) && num_previous_frames >= 2 {
    //     // We want to keep the first frame of a move type, and then keep overwriting the second frame
    //     // of that type. So, check if this is the third frame of that type.
    //     previous_previous_frame := frames[previous_history_index(previous_index)];
    //     if frames_are_mergeable(previous_previous_frame, previous_frame) then should_merge_frame = true;
    // }

    // // !!!!!!!
    // // // When a pane closes it may result in two updates: the cursor moving over to the
    // // // other pane and then the pane being closed.  In these cases we should overwrite the
    // // // former with the latter so it is stored as a single step.
    // // should_merge_frame |=
    // //        previous_frame.layout == .Double && frame.layout == .Single
    // //     && previous_frame.left   == frame.left
    // //     && previous_frame.right  == frame.right;

    // // !!!!!!!!
    // // // If all editors are closed, we remember this state, but later override it
    // // // (if we just didn't write anything to history when layout is None, we wouldn't be able
    // // // to reopen the previous editor by going back in history without additional handling)
    // // should_merge_frame |= previous_frame.layout == .None;

    // if should_merge_frame {
    //     current = previous_index;
    // } else {
    //     if end != previous_index && frame.editor_state == previous_frame.editor_state {
    //         // We don't want to destroy the last frame when we've only moved the cursor after going back in history,
    //         // so we'll keep the last frame unless the editor state has changed
    //         new_end := next_history_index(current);
    //         frames[new_end] = frames[end];
    //         end = new_end;
    //     } else {
    //         end = current;
    //     }
    // }

    // // Push the start point if we've looped around
    // if end == previous_history_index(start) then start = next_history_index(start);

    // // print("STORE: current: %, start: %, end: %. STATE: %\n", current, start, end, frame.editor_state);
    // frames[current] = frame;
}


cursor_history_per_editor: Table(s64, [..] Editor_History_Frame);
cursor_history_global: [..] Global_History_Frame;

Editor_History_Frame :: struct {
    cursor_pos: s32;
    cursor_sel: s32;
}

Global_History_Frame :: struct {
    editor_id:   s64;
    start_index: s64;  // index within the editor history
}




/// ==============================================


// move_to_editor_history_frame :: (frame: Editor_History_Frame, old_frame: Editor_History_Frame) {
    // TODO: !!!!! rewrite

    // editors = frame.editor_state;
    // if editors.active < 0 || editors.layout == .None {
    //     update_window_title();  // reset
    //     return;
    // }

    // make_editor_active(editors.active);
    // editor := *open_editors[editors.active];

    // // Animations
    // if old_frame.layout == .Single && frame.layout == .Double {
    //     // Opening another pane
    //     if old_frame.active == frame.left {
    //         editors_start_moving_splitter(0.5, start = 1.0);  // open from the right
    //         open_editors[frame.left ].scroll_to_cursor = .yes;
    //         open_editors[frame.right].scroll_to_cursor = .yes_new_editor;
    //     } else if old_frame.active == frame.right {
    //         editors_start_moving_splitter(0.5, start = 0.0);  // open from the left
    //         open_editors[frame.left ].scroll_to_cursor = .yes_new_editor;
    //         open_editors[frame.right].scroll_to_cursor = .yes;
    //     } else {
    //         editors_start_moving_splitter(0.5, start = 0.5);  // both editors are new - snap
    //         open_editors[frame.left ].scroll_to_cursor = .yes;
    //         open_editors[frame.right].scroll_to_cursor = .yes;
    //     }
    // } else if old_frame.layout == .Double && frame.layout == .Single {
    //     // Closing a pane
    //     if (frame.active == old_frame.left || frame.active == old_frame.right) {
    //         editor_closing_id = frame.active;
    //         editors.layout = .Double;  // will change when the animation finishes
    //         if frame.active == old_frame.left {
    //             editors.right = old_frame.right;  // make sure we're drawing the correct buffer while it closes
    //             editors.left  = editors.active;
    //             if !config.settings.disable_file_open_close_animations {
    //                 editors_start_moving_splitter(1.0);  // close right
    //             } else {
    //                 finish_closing_editor();
    //             }
    //         } else {
    //             editors.left  = old_frame.left;  // make sure we're drawing the correct buffer while it closes
    //             editors.right = editors.active;
    //             if !config.settings.disable_file_open_close_animations {
    //                 editors_start_moving_splitter(0.0);  // close left
    //             } else {
    //                 finish_closing_editor();
    //             }
    //         }
    //     }
    //     editor.scroll_to_cursor = .yes;
    // } else {
    //     editor.scroll_to_cursor = .yes;
    // }
    // if frame.expanded != old_frame.expanded && editor_closing_id < 0 then toggle_editor_expand(frame.expanded);  // do it last

    // cursor := leave_only_original_cursor(editor);
    // cursor.pos = frame.pos;
    // cursor.sel = cursor.pos;

    // put_cursor_in_valid_spot(cursor, open_buffers[editor.buffer_id]);
// }
