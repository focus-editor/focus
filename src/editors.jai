editors_handle_keypress :: (key_code: Input.Key_Code, mods: Mods) {
    editor, buffer := get_active_editor_and_buffer();
    if !editor return;

    cursor := *editor.cursor;

    if key_code == {
        case .ARROW_LEFT;   move_cursor_left (cursor, buffer);
        case .ARROW_RIGHT;  move_cursor_right(cursor, buffer);
        case .ARROW_UP;     move_cursor_up   (cursor, buffer);
        case .ARROW_DOWN;   move_cursor_down (cursor, buffer);
        case .HOME;         move_cursor_home (cursor, buffer);
        case .END;          move_cursor_end  (cursor, buffer);

        case .ENTER;        handle_enter(cursor, buffer, mods);
        case .BACKSPACE;    handle_backspace(cursor, buffer, mods);
        case .DELETE;       handle_delete(cursor, buffer, mods);
    }
}

editors_handle_text_input :: (char: u32) {
    editor, buffer := get_active_editor_and_buffer();
    if !editor return;

    utf8_char := convert_utf32_to_utf8(char);
    insert_string_at_pos(buffer, editor.cursor.pos, to_string(*utf8_char));
    editor.cursor.pos.col += 1;  // we know it's just one symbol
    editor.cursor.col_wanted = editor.cursor.pos.col;
}

get_active_editor_and_buffer :: () -> *Editor, *Buffer {
    editor: *Editor;
    buffer: *Buffer;
    if editors_layout == {
        case .Single;
            editor = *open_editors[editor_single];
            buffer = *open_buffers[editor.buffer_id];
        case .Double;
            unimplemented();
    }

    if editor != null assert(buffer != null);
    return editor, buffer;
}

editors_open_file :: (path: string, on_the_side := false) {
    buffer_id := find_or_create_buffer(path);
    if #complete editors_layout == {
        case .None;
            editor_single = find_or_create_editor(buffer_id);
            editors_layout = .Single;
        case .Single;
            unimplemented();
        case .Double;
            unimplemented();
    }
}

#scope_file

find_or_create_editor :: (buffer_id: s64) -> editor_id: s64 {
    assert(buffer_id >= 0 && buffer_id < open_buffers.count, "Attempt to create editor for nonexistent buffer");

    for open_editors {
        if it.buffer_id == buffer_id return it_index;
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
}

Viewport :: struct {
    left, top:   s32;
    lines, cols: s32;
}

open_buffers: [..] Buffer;
open_editors: [..] Editor;

editors_layout: enum {
    None;
    Single;
    Double;
} = .None;

editor_single: s64 = -1;
editor_left:   s64 = -1;
editor_right:  s64 = -1;
