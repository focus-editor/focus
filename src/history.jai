deinit_cursor_history :: () {
    array_reset(*forward_history);
    array_reset(*global_history);
    array_reset(*edit_notifications);
    table_reset(*editor_history_table);

    last_seen_cursor.editor_id = -1;
    last_seen_cursor.cursor = .{};
    last_seen_cursor.moved_at = 0;
}

maybe_save_cursor_history :: () {
    defer apply_edit_notifications();

    editor_id := get_visible_editor_id(editors.active_pane);
    editor := ifx editor_id >= 0 then *open_editors[editor_id] else null;
    cursor := ifx editor then get_main_cursor(editor) else NO_CURSOR;

    editor_changed := editor_id  != last_seen_cursor.editor_id;
    cursor_moved   := cursor.pos != last_seen_cursor.pos;
    now := seconds_since_init();

    if !editor_changed && !cursor_moved return;

    defer last_seen_cursor = .{ editor_id = editor_id, cursor = cursor, moved_at = now };

    saved := false;

    if editor_changed {
        last_global_frame := ifx global_history then peek_pointer(global_history) else null;
        if !last_global_frame {
            // Always save the first valid editor we see when there's no history
            // (e.g. when we just started or went all the way back in history)
            editor_id_to_save := last_seen_cursor.editor_id;
            cursor_to_save    := last_seen_cursor.cursor;
            if last_seen_cursor.editor_id < 0 {
                editor_id_to_save = editor_id;
                cursor_to_save    = cursor;
            }
            saved = maybe_save_cursor_position(editor_id_to_save, cursor_to_save);
        } else if last_global_frame.editor_id == last_seen_cursor.editor_id {
            saved = maybe_save_cursor_position(last_seen_cursor.editor_id, last_seen_cursor.cursor, force = true);
        }
    } else if cursor_moved {
        if (now - last_seen_cursor.moved_at) < IDLE_THRESHOLD_IN_SECONDS return;  // cursor is actively moving, wait
        saved = maybe_save_cursor_position(editor_id, last_seen_cursor.cursor);
    }

    if saved then array_reset_keeping_memory(*forward_history);
}

move_back_in_cursor_history :: () -> moved: bool, editor_id: s64 = -1, cursor := Cursor.{} {
    if !global_history return false;

    // Save current cursor position in the forward history
    current_line: s32;
    editor: *Editor;
    buffer: *Buffer;
    editor_id := get_visible_editor_id(editors.active_pane);
    if editor_id >= 0 {
        editor, buffer = get_editor_and_buffer(editor_id);
        cursor := get_main_cursor(editor);
        array_add(*forward_history, .{ editor_id = editor_id, pos = cursor.pos, sel = cursor.sel });
        current_line = offset_to_line(editor, buffer, cursor.pos);
    }

    // Find the previous cursor position
    // If there are similar positions in the history, skip them all
    last_global_frame: *Global_History_Frame;
    last_editor_frame: Editor_History_Frame;
    while global_history {
        last_global_frame = peek_pointer(global_history);
        editor_history := table_find_pointer(*editor_history_table, last_global_frame.editor_id);
        assert(editor_history != null);

        has_editor_history:, last_editor_frame = ringbuffer_pop(editor_history);
        history_debug_print("<<<< EDITOR %, FRAME %, pos = %\n", last_global_frame.editor_id, editor_history.total, last_editor_frame.pos);

        if last_global_frame.start_index >= editor_history.total || !has_editor_history {
            popped := pop(*global_history);
            history_debug_print("<<<< GLOBAL FRAME %, EDITOR %, start_index = %\n", global_history.count, popped.editor_id, popped.start_index);
        }
        if last_global_frame.editor_id != editor_id break;
        if !editor break;
        if has_editor_history && editor && abs(current_line - offset_to_line(editor, buffer, last_editor_frame.pos)) >= MIN_LINE_THRESHOLD break;
    }

    prev_cursor := Cursor.{ pos = last_editor_frame.pos, sel = last_editor_frame.sel };
    return true, last_global_frame.editor_id, prev_cursor;
}

move_forward_in_cursor_history :: () -> moved: bool, editor_id: s64 = -1, cursor := Cursor.{} {
    if !forward_history return false;

    // Save current cursor position in the history
    editor_id := get_visible_editor_id(editors.active_pane);
    if editor_id {
        editor := *open_editors[editor_id];
        cursor := get_main_cursor(editor);
        maybe_save_cursor_position(editor_id, cursor);
    }

    frame := pop(*forward_history);
    next_cursor := Cursor.{ pos = frame.pos, sel = frame.sel };

    return true, frame.editor_id, next_cursor;
}


history_reopen_editor_and_set_cursor :: (editor_id: s64, new_cursor: Cursor) {
    editor, buffer := reopen_editor_by_id(editor_id);

    make_editor_active(editor_id);

    cursor := leave_only_main_cursor(editor);
    cursor.* = new_cursor;
    put_cursor_in_valid_spot(cursor, buffer);

    last_seen_cursor = .{ editor_id = editor_id, pos = cursor.pos, sel = cursor.sel };

    editor.scroll_to_cursor = .yes;
}

history_add_edit_notification_to_batch :: (notification: Buffer.Edit_Notification) {
    array_add(*edit_notifications, notification);
}

history_reset_last_seen_cursor :: () {
    // Occasionally we manually adjust cursor positions, e.g. after converting indentation to another type
    // or stripping whitespace. In this case the cursor position might change, but we don't want to
    // remember the previous one in that case because the perceived cursor position hasn't changed
    editor_id := get_visible_editor_id(editors.active_pane);
    if editor_id < 0 return;

    editor := *open_editors[editor_id];
    cursor := get_main_cursor(editor);

    last_seen_cursor.editor_id = editor_id;
    last_seen_cursor.cursor = cursor;
}


#scope_file

maybe_save_cursor_position :: (editor_id: s64, cursor: Cursor, force := false) -> saved: bool {
    if editor_id < 0 return false;

    editor, buffer := get_editor_and_buffer(editor_id);
    editor_history := find_or_add(*editor_history_table, editor_id);

    last_frame := ringbuffer_peek_pointer(editor_history);
    last_global_frame := ifx global_history then peek_pointer(global_history) else null;
    need_new_global_frame := !last_global_frame || last_global_frame.editor_id != editor_id;

    if !force && last_frame && !need_new_global_frame {
        last_line    := offset_to_line(editor, buffer, last_frame.pos, safe = true);
        current_line := offset_to_line(editor, buffer, cursor.pos, safe = true);
        if abs(last_line - current_line) < MIN_LINE_THRESHOLD return false;  // cursor hasn't moved far enough
    }

    // Add a new global frame if we're recording a frame for a new editor
    if need_new_global_frame {
        array_add(*global_history, .{ editor_id = editor_id, start_index = editor_history.total });
        history_debug_print(">> GLOBAL FRAME %, EDITOR %, start_index = %\n", global_history.count - 1, editor_id, editor_history.total);
    }

    history_debug_print(">> EDITOR %, FRAME %, pos = %\n", editor_id, editor_history.total, cursor.pos);
    ringbuffer_add(editor_history, .{ pos = cursor.pos, sel = cursor.sel });

    return true;
}

apply_edit_notifications :: () {
    // @speed: measure speed and maybe optimise later, if large edit groups end up being a problem
    while edit_notifications {
        buffer_id := edit_notifications[0].buffer_id;

        for * editor, editor_id : open_editors {
            if editor.buffer_id != buffer_id continue;
            editor_history := table_find_pointer(*editor_history_table, editor_id);
            if !editor_history continue;

            for edit_notifications {
                if buffer_id != it.buffer_id continue;
                apply_edit_to_history(editor_history, it);
            }
        }

        for edit_notifications { if buffer_id == it.buffer_id remove it; }
    }
}

apply_edit_to_history :: (history: *Editor_History, edit: Buffer.Edit_Notification) {
    for * frame : history {
        if frame.pos >= edit.offset then frame.pos = max(frame.pos + edit.delta, edit.offset);
        if frame.sel >= edit.offset then frame.sel = max(frame.sel + edit.delta, edit.offset);
    }
}


IDLE_THRESHOLD_IN_SECONDS :: 1;     // for how long the cursor needs to stay in one place to be recorded
MIN_LINE_THRESHOLD :: 10;           // how many lines the cursor needs to move by to qualify for recording

NO_CURSOR :: Cursor.{ pos = -1, sel = -1 };

EDITOR_HISTORY_SIZE :: 64;  // per editor

Editor_History :: Ring_Buffer(Editor_History_Frame, EDITOR_HISTORY_SIZE);

editor_history_table: Table(s64, Editor_History);
global_history:  [..] Global_History_Frame;
forward_history: [..] Forward_History_Frame;

edit_notifications: [..] Buffer.Edit_Notification;

last_seen_cursor: struct {
    editor_id: s64 = -1;
    using cursor: Cursor;
    moved_at: float64;
};


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
    using frame: Editor_History_Frame;
}

DEBUG_HISTORY :: false;

history_debug_print :: (format_string: string, args: .. Any) {
    #if DEBUG_HISTORY {
        history_debug_print(format_string, ..args);
    }
} @PrintLike
