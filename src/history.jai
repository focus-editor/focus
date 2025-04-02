maybe_save_editor_history :: () {
    active_editor_id := get_visible_editor_id(editors.active_pane);

    if last_seen_editor_id != active_editor_id {
        save_history(last_seen_editor_id, force = true);
        save_history(active_editor_id,    force = true);
    } else {
        save_history(active_editor_id);
    }

    last_seen_editor_id = active_editor_id;
}


#scope_file

save_history :: (editor_id: s64, force := false) {
    if editor_id < 0 return;

    editor := *open_editors[editor_id];
    buffer := *open_buffers[editor.buffer_id];
    cursor := editor.cursors[editor.main_cursor];
    defer last_seen_cursor = cursor;

    editor_history := find_or_add(*editor_history_table, editor_id);

    last_frame   := ifx editor_history.count > 0 then *editor_history.*[editor_history.count - 1] else null;
    last_line    := ifx last_frame then offset_to_line(editor, buffer, last_frame.pos) else 0;
    current_line := offset_to_line(editor, buffer, cursor.pos);
    line_difference := abs(last_line - current_line);

    // Maybe skip recording because the cursor has moved recently
    if !force {
        now := seconds_since_init();
        if last_seen_cursor.pos != cursor.pos || last_seen_cursor.sel != cursor.sel then cursor_last_moved_at = now;
        if ((now - cursor_last_moved_at) < IDLE_THRESHOLD_IN_SECONDS &&
            (now - cursor_last_recorded) < TIME_THRESHOLD_IN_SECONDS &&
             line_difference < MAX_LINE_THRESHOLD)
            return;
    }

    if line_difference < MIN_LINE_THRESHOLD {
        // The cursor hasn't moved far enough to justify a new entry
        if !force return;

        // Replace the last frame data with the new cursor position
        if force && last_frame {
            last_frame.pos = cursor.pos;
            last_frame.sel = cursor.sel;
            return;
        }
    }

    // Clear any forward history because we're recording a new position
    array_reset_keeping_memory(*forward_history);

    // Record cursor position
    array_add(editor_history, Editor_History_Frame.{ pos = cursor.pos, sel = cursor.sel });

    last_global_frame := ifx global_history then *global_history[global_history.count - 1] else null;
    if !last_global_frame || last_global_frame.editor_id != editor_id {
        array_add(*global_history, Global_History_Frame.{ editor_id = editor_id, start_index = editor_history.count - 1 });
    }
}

editor_history_table: Table(s64, [..] Editor_History_Frame);
global_history:  [..] Global_History_Frame;
forward_history: [..] Forward_History_Frame;

last_seen_editor_id := -1;
last_seen_cursor: Cursor;
cursor_last_moved_at: float64;
cursor_last_recorded: float64;

IDLE_THRESHOLD_IN_SECONDS :: 1;     // for how long the cursor needs to stay in one place to be recorded
TIME_THRESHOLD_IN_SECONDS :: 10;    // if we haven't recorded anything for this long, we do so even if we aren't idle
MIN_LINE_THRESHOLD :: 5;            // how many lines the cursor needs to move by to qualify for recording
MAX_LINE_THRESHOLD :: 100;          // if line difference is so big, we record an entry even if it happens the next frame

Editor_History_Frame :: struct {
    pos: s32;
    sel: s32;
}

Global_History_Frame :: struct {
    editor_id:   s64;
    start_index: s64;  // index within the editor history
}

Forward_History_Frame :: struct {
    editor_id: s64;
    frame: Editor_History_Frame;
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
