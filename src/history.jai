move_back_in_cursor_history :: () -> moved: bool, editor_id: Editor_Id = -1, cursor := Cursor.{} {
    moved, editor_id, cursor := move_in_cursor_history(*back_history, *forward_history);
    return moved, editor_id, cursor;
}

move_forward_in_cursor_history :: () -> moved: bool, editor_id: Editor_Id = -1, cursor := Cursor.{} {
    moved, editor_id, cursor := move_in_cursor_history(*forward_history, *back_history);
    return moved, editor_id, cursor;
}

move_in_cursor_history :: (from: *[..] History_Frame, to: *[..] History_Frame) -> moved: bool, editor_id: Editor_Id = -1, cursor := Cursor.{} {
    apply_edit_notifications();

    current_editor := get_visible_editor_and_buffer();
    current_cursor: Cursor;

    if current_editor then current_cursor = get_main_cursor(current_editor);

    for < frame, index : from.* {
        found, editor := find_editor(frame.editor_id);
        if !found continue;

        target := Cursor.{ pos = frame.pos, sel = frame.sel };
        put_cursor_in_valid_spot(*target, get_buffer(editor.buffer_id));

        existing_editor := find_editor_to_reuse(editor);
        target_id := ifx existing_editor then existing_editor.id else editor.id;
        if current_editor && target_id == current_editor.id && target.pos == current_cursor.pos && target.sel == current_cursor.sel  continue;

        from.count = index;
        if current_editor {
            push_history_frame(to, .{
                editor_id = current_editor.id,
                pos = current_cursor.pos,
                sel = current_cursor.sel,
            });
        }

        return true, target_id, target;
    }

    return false;
}

push_history_frame :: (history: *[..] History_Frame, frame: History_Frame) {
    if history.count == MAX_HISTORY_FRAMES then array_ordered_remove_by_index(history, 0);
    array_add(history, frame);
}

deinit_cursor_history :: () {
    array_reset(*forward_history);
    array_reset(*back_history);
    array_reset(*edit_notifications);

    last_seen_cursor.editor_id = -1;
    last_seen_cursor.cursor = .{};
    last_seen_cursor.moved_at = 0;
}

maybe_save_cursor_history :: () {
    apply_edit_notifications();
    if active_global_widget == .go_to_line_dialog  return;

    editor_id := get_visible_editor_id(editors.active_pane);
    _, editor := find_editor(editor_id);
    cursor := ifx editor then get_main_cursor(editor) else NO_CURSOR;

    editor_changed := editor_id  != last_seen_cursor.editor_id;
    cursor_moved   := cursor.pos != last_seen_cursor.pos;
    now := seconds_since_init();

    if !editor_changed && !cursor_moved return;

    defer last_seen_cursor = .{ editor_id = editor_id, cursor = cursor, moved_at = now };

    if editor_changed {
        if last_seen_cursor.editor_id >= 0 {
            maybe_save_cursor_position(last_seen_cursor.editor_id, last_seen_cursor.cursor, force = true);
            array_reset_keeping_memory(*forward_history);
        } else if !back_history && !forward_history {
            maybe_save_cursor_position(editor_id, cursor);
        }
        return;
    }

    if now - last_seen_cursor.moved_at < IDLE_THRESHOLD_IN_SECONDS return;
    if maybe_save_cursor_position(editor_id, last_seen_cursor.cursor) {
        array_reset_keeping_memory(*forward_history);
    }
}

history_reopen_editor_and_set_cursor :: (editor_id: Editor_Id, new_cursor: Cursor) {
    editor, buffer := reopen_editor_by_id(editor_id);

    make_editor_active(editor.id);

    cursor := leave_only_main_cursor(editor);
    cursor.* = new_cursor;
    put_cursor_in_valid_spot(cursor, buffer);

    last_seen_cursor = .{ editor_id = editor.id, pos = cursor.pos, sel = cursor.sel };

    editor.scroll_to_cursor = .yes;
}

history_add_edit_notification_to_batch :: (notification: Buffer.Edit_Notification) {
    array_add(*edit_notifications, notification);
}

history_reset_last_seen_cursor :: (buffer_id: Buffer_Id) {
    // Occasionally we manually adjust cursor positions, e.g. after converting indentation to another type
    // or stripping whitespace. In this case the cursor position might change, but we don't want to
    // remember the previous one in that case because the perceived cursor position hasn't changed
    editor_id := get_visible_editor_id(editors.active_pane);
    if editor_id != last_seen_cursor.editor_id return;

    found, editor := find_editor(editor_id);
    if !found || editor.buffer_id != buffer_id return;

    apply_edit_notifications();

    last_seen_cursor.cursor = get_main_cursor(editor);
}


#scope_file

maybe_save_cursor_position :: (editor_id: Editor_Id, cursor: Cursor, force := false) -> saved: bool {
    found, editor := find_editor(editor_id);
    if !found return false;

    buffer := get_buffer(editor.buffer_id);
    put_cursor_in_valid_spot(*cursor, buffer);

    if back_history {
        last := peek_pointer(back_history);
        if last.editor_id == editor_id {
            if last.pos == cursor.pos {
                last.sel = cursor.sel;
                return false;
            }
            if !force {
                last_pos  := clamp(last.pos, 0, buffer.bytes.count);
                last_line := offset_to_real_line(buffer, last_pos);
                line      := offset_to_real_line(buffer, cursor.pos);
                if abs(last_line - line) < MIN_LINE_THRESHOLD return false;
            }
        }
    }

    push_history_frame(*back_history, .{ editor_id = editor_id, pos = cursor.pos, sel = cursor.sel });

    return true;
}

apply_edit_notifications :: () {
    if !edit_notifications return;

    for * frame : back_history    adjust_history_offsets(frame.editor_id, *frame.pos, *frame.sel);
    for * frame : forward_history adjust_history_offsets(frame.editor_id, *frame.pos, *frame.sel);
    adjust_history_offsets(last_seen_cursor.editor_id, *last_seen_cursor.pos, *last_seen_cursor.sel);

    array_reset_keeping_memory(*edit_notifications);
}

adjust_history_offsets :: (editor_id: Editor_Id, pos: *s32, sel: *s32) {
    found, editor := find_editor(editor_id);
    if !found return;

    for edit : edit_notifications {
        if edit.buffer_id != editor.buffer_id continue;
        if pos.* >= edit.offset then pos.* = max(pos.* + edit.delta, edit.offset);
        if sel.* >= edit.offset then sel.* = max(sel.* + edit.delta, edit.offset);
    }
}


MAX_HISTORY_FRAMES :: 256;

History_Frame :: struct {
    editor_id: Editor_Id;
    pos: s32;
    sel: s32;
}

back_history:    [..] History_Frame;
forward_history: [..] History_Frame;

IDLE_THRESHOLD_IN_SECONDS :: 1;     // for how long the cursor needs to stay in one place to be recorded
MIN_LINE_THRESHOLD :: 10;           // how many lines the cursor needs to move by to qualify for recording

NO_CURSOR :: Cursor.{ pos = -1, sel = -1 };

edit_notifications: [..] Buffer.Edit_Notification;

last_seen_cursor: struct {
    editor_id: Editor_Id = -1;
    using cursor: Cursor;
    moved_at: float64;
};

