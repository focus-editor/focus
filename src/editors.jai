editors_handle_keypress :: (key_code: Input.Key_Code, mods: Mods) {
    editor, buffer := get_active_editor_and_buffer();
    if !editor return;
    if buffer.dirty then recalculate_lines(buffer);

    cursor := *editor.cursor;
    cursor_moved   := true;
    keep_selection := false;

    if key_code == {
        case .ARROW_LEFT;
            if only_alt_pressed(mods) {
                move_viewport(editor, .left);
                cursor_moved = false;
            } else {
                move_cursor_left(cursor, buffer, mods);
            }
        case .ARROW_RIGHT;
            if only_alt_pressed(mods) {
                move_viewport(editor, .right);
                cursor_moved = false;
            } else {
                move_cursor_right(cursor, buffer, mods);
            }
        case .ARROW_UP;
            if only_alt_pressed(mods) {
                move_viewport(editor, .up);
                cursor_moved = false;
            } else {
                move_cursor_up(cursor, buffer, mods);
            }
        case .ARROW_DOWN;
            if only_alt_pressed(mods) {
                move_viewport(editor, .down);
                cursor_moved = false;
            } else {
                move_cursor_down(cursor, buffer, mods);
            }
        case .TAB;       keep_selection = handle_tab(cursor, buffer, mods);
        case .HOME;      move_cursor_home(cursor, buffer, mods);
        case .END;       move_cursor_end (cursor, buffer, mods);
        case .ENTER;     handle_enter(cursor, buffer, mods);
        case .BACKSPACE; handle_backspace(cursor, buffer, mods);
        case .DELETE;    handle_delete(cursor, buffer, mods);
        case .PAGE_UP;   move_cursor_page(cursor, buffer, mods, .up);
        case .PAGE_DOWN; move_cursor_page(cursor, buffer, mods, .down);
        case .ESCAPE;    remove_selection(cursor); cursor_moved = false;

        case #char "D";
            if only_ctrl_pressed(mods) {
                if !has_selection(cursor) then select_word(cursor, buffer);
                keep_selection = true;
            } else if only_ctrl_shift_pressed(mods) {
                duplicate_lines(cursor, buffer);
                keep_selection = true;
            }

        case #char "C";
            if only_alt_pressed(mods) {
                center_cursor_on_viewport(editor, << buffer);
            } else if only_ctrl_pressed(mods) && has_selection(cursor) {
                copy_selection_to_clipboard(cursor, buffer);
                cursor_moved = false;
            }

        case #char "X";
            if only_ctrl_pressed(mods) {
                copy_selection_to_clipboard(cursor, buffer, cut = true);
            }

        case #char "V";
            if only_ctrl_pressed(mods) {
                range := paste_from_clipboard(cursor, buffer);
                add_paste_animation(editor, range);
            }

        case #char "A";
            if only_ctrl_pressed(mods) {
                select_all(cursor, << buffer);
                keep_selection = true;
                cursor_moved   = false;  // we don't want to move viewport
            }

        case #char "L";
            if only_ctrl_pressed(mods) {
                select_lines(cursor, << buffer);
                keep_selection = true;
            }

        case; cursor_moved = false;
    }

    if !mods.shift_pressed && cursor_moved && !keep_selection {
        remove_selection(cursor);
    }
    editor.cursor_moved = cursor_moved;
}

editors_handle_text_input :: (char: u32) {
    if char == 127 return;  // there seems to be a bug in the Input module
                            // which generates a TEXT_INPUT event for DEL
                            // when Ctrl+Backspace is pressed

    editor, buffer := get_active_editor_and_buffer();
    if !editor return;
    if buffer.dirty then recalculate_lines(buffer);
    using editor;

    utf8_char := convert_utf32_to_utf8(char);
    str := to_string(*utf8_char);
    if has_selection(cursor) {
        selection := get_selection(cursor);
        buffer_replace_range(buffer, selection, str);
        cursor.pos = selection.start;
    } else {
        buffer_insert_string_at_pos(buffer, cursor.pos, str);
    }
    cursor.pos.col += 1;  // we know it's just one symbol
    cursor.col_wanted = cursor.pos.col;
    remove_selection(*cursor);
    cursor_moved = true;
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

center_cursor_on_viewport :: (using editor: *Editor, buffer: Buffer) {
    // We assume that editors always take up most of the screen vertically.
    // If that ever changes we'll need to change this code (and do it when we know the layout)
    cursor_px_pos := viewport.top +  window_height / 2;
    cursor.pos.line = xx (cursor_px_pos / line_height);
    cursor.pos.col = 0;
    cursor.pos = make_valid_pos(buffer, cursor.pos);
    remove_selection(*cursor);
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

find_or_create_editor :: (buffer_id: s64, existing_editor: s64 = -1) -> editor_id: s64 {
    assert(buffer_id >= 0 && buffer_id < open_buffers.count, "Attempt to create editor for nonexistent buffer");
    for open_editors {
        if it.buffer_id == buffer_id && it_index != existing_editor return it_index;
    }
    editor_id := open_editors.count;
    editor := array_add(*open_editors);
    editor.buffer_id = buffer_id;
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

#scope_export

Editor :: struct {
    buffer_id: s64;

    cursor:   Cursor;
    viewport: Viewport;
    dragging_left := false;
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
