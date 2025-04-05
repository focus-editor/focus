maybe_save_cursor_history :: () {
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
            saved = _maybe_save_cursor_position(editor_id_to_save, cursor_to_save);
        } else if last_global_frame.editor_id == last_seen_cursor.editor_id {
            saved = _maybe_save_cursor_position(last_seen_cursor.editor_id, last_seen_cursor.cursor, force = true);
        }
    } else if cursor_moved {
        if (now - last_seen_cursor.moved_at) < IDLE_THRESHOLD_IN_SECONDS return;  // cursor is actively moving, wait
        saved = _maybe_save_cursor_position(editor_id, last_seen_cursor.cursor);
    }

    if saved then array_reset_keeping_memory(*forward_history);
}

move_back_in_cursor_history :: () -> moved: bool, editor_id: s64 = -1, cursor := Cursor.{} {
    if !global_history return false;

    // Save current cursor position in the forward history
    editor_id := get_visible_editor_id(editors.active_pane);
    if editor_id >= 0 {
        editor, buffer := get_editor_and_buffer(editor_id);
        cursor := get_main_cursor(editor);
        array_add(*forward_history, .{ editor_id = editor_id, pos = cursor.pos, sel = cursor.sel });
    }

    // Find the previous cursor position
    last_global_frame := peek(global_history);
    editor_history := table_find_pointer(*editor_history_table, last_global_frame.editor_id);
    assert(editor_history != null);
    last_editor_frame := pop(editor_history);
    if last_global_frame.start_index >= editor_history.count {
        popped := pop(*global_history);
        print("<<<< GLOBAL FRAME %, EDITOR %, start_index = %\n", global_history.count, popped.editor_id, popped.start_index);
    }
    prev_cursor := Cursor.{ pos = last_editor_frame.pos, sel = last_editor_frame.sel };
    print("<<<< EDITOR %, FRAME %, pos = %\n", last_global_frame.editor_id, editor_history.count, prev_cursor.pos);

    return true, last_global_frame.editor_id, prev_cursor;
}

move_forward_in_cursor_history :: () -> moved: bool, editor_id: s64 = -1, cursor := Cursor.{} {
    if !forward_history return false;

    // Save current cursor position in the history
    editor_id := get_visible_editor_id(editors.active_pane);
    if editor_id {
        editor := *open_editors[editor_id];
        cursor := get_main_cursor(editor);
        _maybe_save_cursor_position(editor_id, cursor);
    }

    frame := pop(*forward_history);
    next_cursor := Cursor.{ pos = frame.pos, sel = frame.sel };

    return true, frame.editor_id, next_cursor;
}


history_reopen_editor_and_set_cursor :: (editor_id: s64, new_cursor: Cursor) {
    editor, buffer := get_editor_and_buffer(editor_id);

    pane, editor_index := editors_find_pane_with_editor(editor_id);
    if !pane {
        // Editor is not in the tree any more, check if there's an editor for the same buffer in the current pane first
        found_in_active_pane := false;
        for editors.active_pane.editor_ids {
            if open_editors[it].buffer_id == editor.buffer_id {
                found_in_active_pane = true;
                editor_id = it;
                break;
            }
        }

        if !found_in_active_pane {
            // Reopen the editor in the active pane
            editors.active_pane.editor_index = editors.active_pane.editor_ids.count;
            array_add(*editors.active_pane.editor_ids, editor_id);
        }
    }

    make_editor_active(editor_id);

    cursor := leave_only_main_cursor(editor);
    cursor.* = new_cursor;
    put_cursor_in_valid_spot(cursor, buffer);

    last_seen_cursor = .{ editor_id = editor_id, pos = cursor.pos, sel = cursor.sel };

    editor.scroll_to_cursor = .yes;
}


#scope_file

_maybe_save_cursor_position :: (editor_id: s64, cursor: Cursor, force := false) -> saved: bool {
    if editor_id < 0 return false;

    editor, buffer := get_editor_and_buffer(editor_id);
    editor_history := find_or_add(*editor_history_table, editor_id);

    last_frame := ifx editor_history.count > 0 then peek_pointer(editor_history.*) else null;
    last_global_frame := ifx global_history then peek_pointer(global_history) else null;
    need_new_global_frame := !last_global_frame || last_global_frame.editor_id != editor_id;
    overwrite := false;

    if last_frame {
        last_line    := offset_to_line(editor, buffer, last_frame.pos);
        current_line := offset_to_line(editor, buffer, cursor.pos);
        if abs(last_line - current_line) < MIN_LINE_THRESHOLD && !need_new_global_frame {
            if !force return false;
            overwrite = true;
        }
    }

    // Add a new global frame if we're recording a frame for a new editor
    if need_new_global_frame {
        array_add(*global_history, .{ editor_id = editor_id, start_index = editor_history.count });
        print(">> GLOBAL FRAME %, EDITOR %, start_index = %\n", global_history.count - 1, editor_id, editor_history.count);
    }

    // Add new or overwrite the top editor frame
    if overwrite && last_frame {
        last_frame.pos = cursor.pos;
        last_frame.sel = cursor.sel;
        print("==== EDITOR %, FRAME %, pos = %\n", editor_id, editor_history.count - 1, cursor.pos);
    } else {
        print(">> EDITOR %, FRAME %, pos = %\n", editor_id, editor_history.count, cursor.pos);
        array_add(editor_history, .{ pos = cursor.pos, sel = cursor.sel });
    }

    return true;
}


IDLE_THRESHOLD_IN_SECONDS :: 1;     // for how long the cursor needs to stay in one place to be recorded
MIN_LINE_THRESHOLD :: 10;           // how many lines the cursor needs to move by to qualify for recording

NO_CURSOR :: Cursor.{ pos = -1, sel = -1 };

editor_history_table: Table(s64, [..] Editor_History_Frame);
global_history:  [..] Global_History_Frame;
forward_history: [..] Forward_History_Frame;

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
