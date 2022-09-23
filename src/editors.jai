editors_handle_keypress :: (key_code: Input.Key_Code, mods: Mods) {
    editor, buffer := get_active_editor_and_buffer();
    if !editor return;

    cursors := editor.cursors;

    cursor_moved   := false;
    keep_selection := false;

    // Handle general actions (which are not associated with any cursor)
    handled := false;

    // We want to remember where cursors were before we do any edits
    if buffer.edits.count == 0 {
        array_resize(*buffer.cursors, editor.cursors.count);
        for * cursor, i : buffer.cursors { <<cursor = editor.cursors[i].state; }
    }

    if frame_time - buffer.last_edit_time >= EDIT_GROUP_TIMEOUT then new_edit_group(buffer, editor);

    if key_code == {
        case #char "D";
            if only_ctrl_pressed(mods) {
                created := maybe_create_additional_cursor(editor, buffer);
                keep_selection = true;
                if created {
                    cursor_moved = true;
                    handled = true;
                }
            }

        case #char "Z";
            if only_ctrl_pressed(mods) {
                new_edit_group(buffer, editor);
                maybe_undo(buffer, editor);
                keep_selection = true;
                cursor_moved = true;
                handled = true;
            }
            if only_ctrl_shift_pressed(mods) {
                maybe_redo(buffer, editor);
                keep_selection = true;
                cursor_moved = true;
                handled = true;
            }

        case #char "C";
            if only_alt_pressed(mods) {
                move_cursor_to_viewport_center(editor, buffer);
                cursor_moved = true;
                handled = true;
            }

        case #char "A";
            if only_ctrl_pressed(mods) {
                cursor := leave_only_original_cursor(editor);
                select_all(cursor, buffer);
                keep_selection = true;
                handled = true;
            }

        case .ESCAPE;
            cursor := leave_only_original_cursor(editor);
            remove_selection(cursor);
            cursor_moved = true;
            handled = true;

        case .ARROW_LEFT;
            if only_alt_pressed(mods) {
                move_viewport(editor, .left);
                handled = true;
            } else if only_ctrl_alt_pressed(mods) {
                switch_to_pane(.left);
                handled = true;
            }

        case .ARROW_RIGHT;
            if only_alt_pressed(mods) {
                move_viewport(editor, .right);
                handled = true;
            } else if only_ctrl_alt_pressed(mods) {
                switch_to_pane(.right);
                handled = true;
            }

        case .ARROW_UP;
            if only_alt_pressed(mods) {
                move_viewport(editor, .up);
                handled = true;
            }

        case .ARROW_DOWN;
            if only_alt_pressed(mods) {
                move_viewport(editor, .down);
                handled = true;
            }
    }

    // Process individual cursors
    if !handled {
        cursor_delta := 0;
        buf_len := buffer.bytes.count;
        offsets := remember_cursor_offsets(editor, buffer);

        // We always want to put some actions in a separate edit group (e.g. block indent)
        new_group := false;
        for cursor : cursors { if new_edit_group_required_for_action(key_code, mods, cursor) { new_group = true; break; } }
        if new_group then new_edit_group(buffer, editor);  // do it before action

        for *cursor, i : cursors {
            // Adjust cursor if the previous cursor has changed the buffer
            new_len := buffer.bytes.count;
            if new_len != buf_len || buffer.dirty {
                recalculate_lines(buffer);
                cursor_delta += new_len - buf_len;
                cursor.pos = offset_to_pos(buffer, offsets[i].pos + cursor_delta);
                cursor.sel = offset_to_pos(buffer, offsets[i].sel + cursor_delta);
                buf_len = new_len;
            }

            // Handle keypress for cursor
            if key_code == {
                case .ARROW_LEFT;
                    move_cursor_left(cursor, buffer, mods);
                    cursor_moved = true;
                case .ARROW_RIGHT;
                    move_cursor_right(cursor, buffer, mods);
                    cursor_moved = true;

                case .ARROW_UP;
                    if only_alt_shift_pressed(mods) && cursors.count == 1 {
                        // TODO: support multiple cursors here someday too
                        move_lines_up(cursor, buffer);
                        keep_selection = true;
                    } else {
                        move_cursor_up(cursor, buffer, mods);
                    }
                    cursor_moved = true;
                case .ARROW_DOWN;
                    if only_alt_shift_pressed(mods) && cursors.count == 1 {
                        move_lines_down(cursor, buffer);
                        keep_selection = true;
                    } else {
                        move_cursor_down(cursor, buffer, mods);
                    }
                    cursor_moved = true;
                case .HOME;
                    move_cursor_home(cursor, buffer, mods);
                    cursor_moved = true;
                case .END;
                    move_cursor_end(cursor, buffer, mods);
                    cursor_moved = true;
                case .ENTER;
                    handle_enter(cursor, buffer, mods);
                    cursor_moved = true;
                case .BACKSPACE;
                    handle_backspace(cursor, buffer, mods);
                    cursor_moved = true;
                case .DELETE;
                    handle_delete(cursor, buffer, mods);
                    cursor_moved = true;
                case .PAGE_UP;
                    move_cursor_page(cursor, buffer, mods, .up);
                    cursor_moved = true;
                case .PAGE_DOWN;
                    move_cursor_page(cursor, buffer, mods, .down);
                    cursor_moved = true;
                case .TAB;
                    keep_selection = handle_tab(cursor, buffer, mods);
                    cursor_moved = true;

                case #char "D";
                    if only_ctrl_shift_pressed(mods) && cursors.count == 1 {
                        duplicate_lines(cursor, buffer);
                        keep_selection = true;
                        cursor_moved = true;
                    } else if only_ctrl_pressed(mods) {
                        select_word(cursor, buffer);
                        cursor_moved = true;
                    }

                case #char "C";
                    if only_ctrl_pressed(mods) {
                        copy_selection_to_clipboard(cursor, buffer, cursors.count == 1);
                    }

                case #char "X";
                    if only_ctrl_pressed(mods) {
                        copy_selection_to_clipboard(cursor, buffer, cursors.count == 1, cut = true);
                        cursor_moved = true;
                    }

                case #char "V";
                    if only_ctrl_pressed(mods) {
                        all_clipboards_empty := true;
                        for c : cursors { if c.clipboard { all_clipboards_empty = false; break; } }
                        range := paste_from_clipboard(cursor, buffer, cursors.count == 1 || all_clipboards_empty);
                        add_paste_animation(editor, range);
                        cursor_moved = true;
                    }

                case #char "L";
                    if only_ctrl_pressed(mods) {
                        select_lines(cursor, buffer);
                        keep_selection = true;
                        cursor_moved = true;
                    }

                case #char "/";
                    if only_ctrl_pressed(mods) {
                        if buffer.lang == .Jai {
                            comment_block(cursor, buffer);
                        }
                        keep_selection = true;
                        cursor_moved = true;
                    }
            }
        }

        if new_group then new_edit_group(buffer, editor);  // do it after action
    }

    if !mods.shift_pressed && cursor_moved && !keep_selection {
        for *cursor : cursors { remove_selection(cursor); }
    }

    if buffer.dirty {
        buffer.modified = true;
        buffer.last_edit_time = frame_time;
        recalculate_lines(buffer);

        // Make sure the cursors in all editors for this buffer are in valid places
        for *e : open_editors {
            if e.buffer_id != editor.buffer_id continue;
            for *cursor : e.cursors { put_cursor_in_valid_spot(cursor, buffer); }
            if e != editor && e.cursors.count > 1 then organise_cursors(e);
        }
    }
    if cursors.count > 1 then organise_cursors(editor);  // sort and maybe merge overlapping cursors

    editor.cursor_moved = cursor_moved;
}

editors_handle_text_input :: (char: u32) {
    if char == 127 return;  // there seems to be a bug in the Input module
                            // which generates a TEXT_INPUT event for DEL
                            // when Ctrl+Backspace is pressed

    editor, buffer := get_active_editor_and_buffer();
    if !editor return;

    utf8_char := convert_utf32_to_utf8(char);
    str := to_string(*utf8_char);

    if buffer.edits.count == 0 {
        // We want to remember where cursors were before we do any edits
        array_resize(*buffer.cursors, editor.cursors.count);
        for * cursor, i : buffer.cursors { <<cursor = editor.cursors[i].state; }
    } else {
        // We always want to remember cursor state when a selection is replaced with anything
        new_group := false;
        for editor.cursors { if has_selection(it) { new_group = true; break; } }
        if new_group || frame_time - buffer.last_edit_time >= EDIT_GROUP_TIMEOUT {
            new_edit_group(buffer, editor);
        }
    }

    cursor_delta := 0;
    buf_len := buffer.bytes.count;
    offsets := remember_cursor_offsets(editor, buffer);

    for *cursor, i : editor.cursors {
        // Adjust cursor if the previous cursor has changed the buffer
        new_len := buffer.bytes.count;
        if new_len != buf_len || buffer.dirty {
            recalculate_lines(buffer);
            cursor_delta += new_len - buf_len;
            cursor.pos = offset_to_pos(buffer, offsets[i].pos + cursor_delta);
            cursor.sel = offset_to_pos(buffer, offsets[i].sel + cursor_delta);
            buf_len = new_len;
        }

        if has_selection(cursor) {
            selection := get_selection(cursor);
            replace_range(buffer, selection, str);
            cursor.pos = selection.start;
        } else {
            insert_string_at_pos(buffer, cursor.pos, str);
        }
        cursor.pos.col += 1;  // we know it's just one symbol
        cursor.col_wanted = cursor.pos.col;
        remove_selection(cursor);
    }

    if buffer.dirty then recalculate_lines(buffer);

    editor.cursor_moved = true;
    buffer.modified = true;
    buffer.last_edit_time = frame_time;
}

get_active_editor_and_buffer :: () -> *Editor, *Buffer {
    if editors_layout == .None return null, null;
    editor := *open_editors[editor_active];
    buffer := *open_buffers[editor.buffer_id];
    return editor, buffer;
}

editors_open_file :: (path: string, where: enum { in_place; left; right; } = .in_place) {
    buffer_id := find_or_create_buffer(path);
    if #complete editors_layout == {
        case .None;
            editor_active = find_or_create_editor(buffer_id);
            editors_layout = .Single;
        case .Single;
            if #complete where == {
                case .in_place;
                    editor_active  = find_or_create_editor(buffer_id);
                    editors_layout = .Single;
                case .left;
                    editor_left    = find_or_create_editor(buffer_id, editor_active);
                    editor_right   = editor_active;
                    editor_active  = editor_left;
                    editors_layout = .Double;
                case .right;
                    editor_right   = find_or_create_editor(buffer_id, editor_active);
                    editor_left    = editor_active;
                    editor_active  = editor_right;
                    editors_layout = .Double;
            }
        case .Double;
            unimplemented();
    }
}

move_viewport :: (editor: *Editor, dir: enum { left; up; right; down; }) {
    using editor.viewport;
    if dir == {
        case .left; #through;
        case .right;
            horiz_delta := cast(s32) (10 * char_size);
            new_target := ifx dir == .left then scroll_x.target - horiz_delta else scroll_x.target + horiz_delta;
            set_scroll_target(*scroll_x, left, new_target, xx (1000 * char_size)); // TODO

        case .up; #through;
        case .down;
            vert_delta := cast(s32) (10 * line_height);
            new_target := ifx dir == .up then scroll_y.target - vert_delta else scroll_y.target + vert_delta;
            buffer := open_buffers[editor.buffer_id];
            max_y_scroll := get_max_y_scroll(buffer);
            set_scroll_target(*scroll_y, top, new_target, max_y_scroll);
    }
}

move_cursor_to_viewport_center :: (editor: *Editor, buffer: Buffer) {
    cursor := leave_only_original_cursor(editor);
    // We assume that editors always take up most of the screen vertically.
    // If that ever changes we'll need to change this code (and do it when we know the layout)
    cursor_px_pos := editor.viewport.top +  window_height / 2;
    cursor.pos.line = xx (cursor_px_pos / line_height);
    cursor.pos.col = 0;
    cursor.pos = make_valid_pos(buffer, cursor.pos);
    remove_selection(cursor);
}

leave_only_original_cursor :: (using editor: *Editor) -> *Cursor {
    // Remove all cursors except the original one
    for *cursor : cursors {
        maybe_free_and_clear(*cursor.clipboard);
    }
    cursor := cursors[original_cursor];
    cursors.count = 1;
    original_cursor = 0;
    main_cursor = 0;
    cursors[original_cursor] = cursor;
    return *cursors[original_cursor];
}

remember_cursor_offsets :: (using editor: *Editor, buffer: Buffer) -> []Cursor_Offsets /* temporary storage */ {
    // When editing with multiple cursors it's convenient to remember where cursors
    // are in the buffer before we start so we can then easily adjust their positions later
    offsets := NewArray(cursors.count, Cursor_Offsets, initialized = false, allocator = temp);
    for cursor, i : cursors {
        offsets[i].pos = pos_to_offset(buffer, cursor.pos);
        offsets[i].sel = pos_to_offset(buffer, cursor.sel);
    }
    return offsets;
}

organise_cursors :: (using editor: *Editor) {
    compare_cursors :: (c1: Cursor, c2: Cursor) -> s64 {
        s1 := get_selection(c1);
        s2 := get_selection(c2);
        if s1.start < s2.start return -1;
        if s2.start < s1.start return  1;
        return 0;
    }

    maybe_subsume :: (c1: *Cursor, c2: Cursor) -> bool {
        s1 := get_selection(c1);
        s2 := get_selection(c2);
        if s1.end < s2.start || s2.end < s1.start return false;  // cursors are disjoint

        new_start := ifx s1.start < s2.start then s1.start else s2.start;  // for some reason min() didn't work
        new_end   := ifx s1.end   < s2.end   then s2.end   else s1.end;    // max()

        if c1.pos == s1.end || c2.pos == s2.end {
            c1.sel = new_start;
            c1.pos = new_end;
        } else {
            c1.pos = new_start;
            c1.sel = new_end;
        }

        return true;
    }

    main_cursor_pos     := cursors[main_cursor].pos;
    original_cursor_pos := cursors[original_cursor].pos;

    quick_sort(cursors, compare_cursors);

    // Adjust main and original cursor indices because they could've moved
    for cursor, i : cursors {
        if cursor.pos == main_cursor_pos     then main_cursor = i;
        if cursor.pos == original_cursor_pos then original_cursor = i;
    }

    // Merge overlapping cursors
    i := 0;
    while (i < cursors.count - 1) {
        cursor := *cursors[i];
        if maybe_subsume(cursor, cursors[i+1]) {
            array_ordered_remove_by_index(*cursors, i+1);
            if main_cursor     > i then main_cursor -= 1;
            if original_cursor > i then original_cursor -= 1;
        } else {
            i += 1;
        }
    }
}

editor_mouse_scroll :: (editor: *Editor, delta_z: int, max_y_scroll: s32) {
    if delta_z == 0 return;

    // Vertical scroll
    // Y-up, so a positive value of viewport.top means we've scrolled down
    WHEEL_SENSITIVITY :: 1.0;
    scroll_delta := cast(s32) (cast(float) delta_z * WHEEL_SENSITIVITY);
    using editor.viewport;
    set_scroll_target(*scroll_y, top, scroll_y.target - scroll_delta, max_y_scroll);
}

animate_scrolling :: (editor: *Editor) -> scrolling: bool {
    using editor.viewport;
    scrolling := false;

    // Vertical scroll
    if top != scroll_y.target {
        scrolling = true;
        using scroll_y;
        t := (frame_time - started_at) / Scroll_Animation.SPEED;
        if t >= 1 || t < 0 {
            top = target;
        } else {
            top = start + xx (cast(float)(target - start) * t);
        }
    }

    // Horizontal scroll
    if left != scroll_x.target {
        scrolling = true;
        using scroll_x;
        t := (frame_time - started_at) / Scroll_Animation.SPEED;
        if t >= 1 || t < 0 {
            left = target;
        } else {
            left = start + xx (cast(float)(target - start) * t);
        }
    }

    return scrolling;
}

get_max_y_scroll :: (buffer: Buffer) -> s32 {
    assert(!buffer.dirty);
    return max(cast(s32) ((buffer.lines.count - 2)  * line_height), 0);
}

set_scroll_target :: (using scroll: *Scroll_Animation, current: s32, target_: s32, max_scroll: s32) {
    start = current;
    target = clamp(target_, 0, max_scroll);
    started_at = frame_time;
}

add_paste_animation :: (using editor: *Editor, range: Range) {
    anim := array_add(*paste_animations);
    anim.range = range;
    anim.started_at = frame_time;
}

#scope_file

maybe_create_additional_cursor :: (using editor: *Editor, buffer: Buffer) -> created: bool {
    selected_text := get_selected_text_all_cursors(editor, buffer);
    if selected_text.count == 0 return false;
    buffer_str := to_string(buffer.bytes);

    // Search from the main cursor downwards, possibly with a wraparound
    start_offset := pos_to_offset(buffer, get_selection(cursors[main_cursor]).end);
    found_offset := -1;
    if main_cursor == cursors.count - 1 {
        // Main cursor is last - search with a wraparound
        end_offset  := pos_to_offset(buffer, get_selection(cursors[0]).start);
        before_wrap := slice(buffer_str, start_offset, buffer_str.count - start_offset);
        after_wrap  := slice(buffer_str, 0, end_offset);

        index := find_index_from_left(before_wrap, selected_text);
        if index >= 0 then found_offset = start_offset + index;
        if found_offset < 0 then found_offset = find_index_from_left(after_wrap, selected_text);
    } else {
        // Main cursor is not last - search until the next cursor only
        end_offset := pos_to_offset(buffer, get_selection(cursors[main_cursor+1]).start);
        target_range := slice(buffer_str, start_offset, end_offset - start_offset);
        index := find_index_from_left(target_range, selected_text);
        if index >= 0 then found_offset = start_offset + index;
    }
    if found_offset < 0 {
        if main_cursor != original_cursor then main_cursor = original_cursor;  // go back to original and stop
        return false;  // found no matches
    }

    new_cursor := array_add(*cursors);
    new_cursor.sel = offset_to_pos(buffer, found_offset);
    new_cursor.pos = offset_to_pos(buffer, found_offset + selected_text.count);
    main_cursor = cursors.count - 1;

    return true;
}

get_selected_text_all_cursors :: (using editor: Editor, buffer: Buffer) -> string {
    // Returns a selected string only if all cursors have the same text selected.
    // Otherwise returns an empty string.
    empty: string;

    text := get_selected_string(cursors[main_cursor], buffer);
    if text.count == 0 return empty;

    for cursor : cursors {
        if text != get_selected_string(cursor, buffer) return empty;
    }

    return text;
}

switch_to_pane :: (side: enum { left; right; }) {
    if editors_layout != .Double return;
    editor_active = ifx side == .left then editor_left else editor_right;
}

find_or_create_editor :: (buffer_id: s64, existing_editor: s64 = -1) -> editor_id: s64 {
    assert(buffer_id >= 0 && buffer_id < open_buffers.count, "Attempt to create editor for nonexistent buffer");
    for open_editors {
        if it.buffer_id == buffer_id && it_index != existing_editor return it_index;
    }
    editor_id := open_editors.count;
    editor := array_add(*open_editors);
    editor.buffer_id = buffer_id;
    array_add(*editor.cursors, Cursor.{});
    return editor_id;
}

find_or_create_buffer :: (path: string) -> buffer_id: s64 {
    for open_buffers {
        if it.file == path return it_index;
    }

    // Create and load file
    buffer_id := open_buffers.count;
    buffer := array_add(*open_buffers);
    buffer.file = copy_string(path);

    file_data, success := read_entire_file(path);
    if !success then file_data = sprint("Couldn't load file '%'", path);
    defer free(file_data);
    array_copy(*buffer.bytes, cast([]u8) file_data);
    remove_crlf(buffer);

    if ends_with_nocase(path, ".jai") {
        buffer.lang = .Jai;
    } else if ends_with(path, "LOG.md") {
        buffer.lang = .Worklog;
    }

    return buffer_id;
}

new_edit_group :: (buffer: *Buffer, editor: *Editor) {
    if buffer.edits.count == 0 return;

    new_group := array_add(*buffer.undos);
    new_group.edits = to_owned_array(*buffer.edits);
    new_group.cursors = to_owned_array(*buffer.cursors);

    // Remember cursor state
    array_resize(*buffer.cursors, editor.cursors.count);
    for * cursor, i : buffer.cursors { <<cursor = editor.cursors[i].state; }

    // print("New edit group: %\n", <<new_group);
}

maybe_undo :: (buffer: *Buffer, editor: *Editor) {
    if buffer.undos.count == 0 return;
    edit_group := pop(*buffer.undos);
    // Revert edits in the backwards order
    for < e : edit_group.edits {
        if #complete e.type == {
            case .insert;  using e.insert;  delete_range_raw (buffer, offset, offset + new_bytes.count);
            case .delete;  using e.delete;  insert_string_raw(buffer, offset_range.start, old_bytes);
            case .replace; using e.replace; replace_range_raw(buffer, offset_range.start, offset_range.start + xx new_bytes.count, old_bytes);
        }
    }
    // Add a new redo group
    redo := array_add(*buffer.redos);
    redo.edits = edit_group.edits;
    redo.cursors = to_owned_array(*buffer.cursors);

    array_extend(*buffer.cursors, edit_group.cursors);
    restore_cursor_state(editor, edit_group.cursors);
    array_free(edit_group.cursors);
}

maybe_redo :: (buffer: *Buffer, editor: *Editor) {
    if buffer.redos.count == 0 return;
    edit_group := pop(*buffer.redos);
    // Replay edits in the normal order
    for e : edit_group.edits {
        if #complete e.type == {
            case .insert;  using e.insert;  insert_string_raw(buffer, offset, new_bytes);
            case .delete;  using e.delete;  delete_range_raw (buffer, offset_range.start, offset_range.end);
            case .replace; using e.replace; replace_range_raw(buffer, offset_range.start, offset_range.end, new_bytes);
        }
    }
    // Add a new undo group
    undo := array_add(*buffer.undos);
    undo.edits = edit_group.edits;
    undo.cursors = to_owned_array(*buffer.cursors);

    array_extend(*buffer.cursors, edit_group.cursors);
    restore_cursor_state(editor, edit_group.cursors);
    array_free(edit_group.cursors);
}

restore_cursor_state :: (using editor: *Editor, cursor_state: []Cursor.State) {
    if cursor_state.count == 0 return;  // the first undo doesn't have any remembered cursors

    for * cursors maybe_free_and_clear(*it.clipboard);
    array_resize(*cursors, cursor_state.count);
    for * cursor, i : cursors {
        cursor.state = cursor_state[i];
        cursor.col_wanted = cursor.pos.col;
        cursor.clipboard.count = 0;
        cursor.clipboard.data = null;
    }
    if main_cursor >= cursors.count then main_cursor = cursors.count - 1;  // maybe we should remember it too
}

new_edit_group_required_for_action :: (key_code: Input.Key_Code, mods: Mods, cursor: Cursor) -> bool {
    // NOTE: we could abstract away actions instead of checking keys here directly, but
    // I won't do it for now because I want to avoid needless refactoring

    if key_code == {
        case .BACKSPACE; #through;
        case .DELETE;  // delete range
        case .ENTER;   // replace range with newline
            if has_selection(cursor) return true;

        case .ARROW_UP; #through;
        case .ARROW_DOWN;
            if only_ctrl_alt_pressed(mods) return true;  // move lines up or down

        case .TAB;  // any indentation
            return true;

        case #char "D";
            if only_ctrl_shift_pressed(mods) return true;  // duplicate lines

        case #char "V";
            if only_ctrl_pressed(mods) return true;  // paste

        case #char "X";
            if only_ctrl_pressed(mods) return true;  // cut
    }

    return false;
}

#scope_export

Editor :: struct {
    buffer_id: s64;

    cursors: [..] Cursor;
    main_cursor: s64;      // newly added cursors become main so that we jump to them
    original_cursor: s64;  // we remember the original cursor when first creating multiple cursors (and go back to it on escape)
    viewport: Viewport;
    dragging_lmb := false;
    cursor_moved  := false;

    paste_animations: [..] Paste_Animation;
}

Viewport :: struct {
    top:  s32;
    left: s32;
    scroll_y: Scroll_Animation;
    scroll_x: Scroll_Animation;
}

Scroll_Animation :: struct {
    start, target: s32;
    started_at: float64;
    SPEED :: 0.1;  // how many seconds to finish any scroll animation
}

Paste_Animation :: struct {
    range: Range;
    started_at: float64;
    SPEED :: 0.5;
}

open_buffers: [..] Buffer;
open_editors: [..] Editor;

editors_layout: enum {
    None;
    Single;
    Double;
} = .None;

editor_active: s64 = -1;
editor_left:   s64 = -1;
editor_right:  s64 = -1;

dragging_splitter := false;
splitter_pos: float = 0;  // zero means it's in the middle


#scope_file

EDIT_GROUP_TIMEOUT :: 0.3;
