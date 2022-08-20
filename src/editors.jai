editors_handle_keypress :: (key_code: Input.Key_Code, mods: Mods) {
    editor, buffer := get_active_editor_and_buffer();
    if !editor return;

    cursor := *editor.cursor;
    cursor_moved := false;

    if key_code == {
        case .ARROW_LEFT;   move_cursor_left (cursor, buffer); cursor_moved = true;
        case .ARROW_RIGHT;  move_cursor_right(cursor, buffer); cursor_moved = true;
        case .ARROW_UP;     move_cursor_up   (cursor, buffer); cursor_moved = true;
        case .ARROW_DOWN;   move_cursor_down (cursor, buffer); cursor_moved = true;
        case .HOME;         move_cursor_home (cursor, buffer); cursor_moved = true;
        case .END;          move_cursor_end  (cursor, buffer); cursor_moved = true;

        case .ENTER;        handle_enter(cursor, buffer, mods);     cursor_moved = true;
        case .BACKSPACE;    handle_backspace(cursor, buffer, mods); cursor_moved = true;
        case .DELETE;       handle_delete(cursor, buffer, mods);    cursor_moved = true;
    }

    if !mods.shift_pressed && cursor_moved {
        // Remove selection
        cursor.sel = cursor.pos;
    }
    editor.cursor_moved = cursor_moved;
}

editors_handle_text_input :: (char: u32) {
    editor, buffer := get_active_editor_and_buffer();
    if !editor return;

    utf8_char := convert_utf32_to_utf8(char);
    insert_string_at_pos(buffer, editor.cursor.pos, to_string(*utf8_char));
    editor.cursor.pos.col += 1;  // we know it's just one symbol
    editor.cursor.col_wanted = editor.cursor.pos.col;
    editor.cursor_moved = true;
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

editor_mouse_scroll :: (editor: *Editor, delta_z: int, max_scroll: s32) {
    if delta_z == 0 return;

    WHEEL_SENSITIVITY :: 1.0;
    // Vertical scroll
    // Y-up, so a positive value of viewport.top means we've scrolled down
    using editor.viewport;
    using scroll_y;
    start = top;
    target -= xx (cast(float) delta_z * WHEEL_SENSITIVITY);
    target = clamp(target, 0, max(max_scroll, 0));
    started_at = frame_time;
}

animate_scrolling :: (editor: *Editor) -> scrolling: bool {
    using editor.viewport;

    // Vertical scroll
    if top != scroll_y.target {
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
        using scroll_x;
        t := (frame_time - started_at) / Scroll_Animation.SPEED;
        if t >= 1 || t < 0 {
            left = target;
        } else {
            left = start + xx (cast(float)(target - start) * t);
        }
    }

    return top != scroll_y.target || left != scroll_x.target;
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
    if !success file_data = sprint("Couldn't load file '%'", path);
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
