editors_handle_keypress :: (key_code: Input.Key_Code, mods: Input.Event.Modifier_Flags) {
    if key_code == {
        case .ARROW_LEFT;  #through;
        case .ARROW_RIGHT; #through;
        case .ARROW_UP;    #through;
        case .ARROW_DOWN;  #through;
        case .HOME;        #through;
        case .END;
            move_cursor(key_code);
    }
}

editors_handle_text_input :: (char: u32) {
    editor, buffer := get_active_editor_and_buffer();
    if !editor return;

    utf8_char := convert_utf32_to_utf8(char);
    insert_string_at_cursor(buffer, editor.cursor, to_string(*utf8_char));
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

move_cursor :: (key_code: Input.Key_Code) {
    editor, buffer := get_active_editor_and_buffer();
    if !editor return;

    cursor := *editor.cursor;
    pos    := *editor.cursor.pos;

    if key_code == {
        case .ARROW_LEFT;
            pos.col -= 1;
            if pos.col < 0 {
                if pos.line > 0 { pos.line -= 1; pos.col = buffer.lines[pos.line].num_chars; }
                else pos.col = 0;
            }
            cursor.col_wanted = pos.col;
        case .ARROW_RIGHT;
            line_len := buffer.lines[pos.line].num_chars;
            if pos.col >= line_len && pos.line < buffer.lines.count - 1 {
                pos.line += 1;
                pos.col   = 0;
            } else if pos.col < line_len {
                pos.col += 1;
            }
            cursor.col_wanted = pos.col;
        case .ARROW_UP;
            pos.line -= 1;
            if pos.line < 0 then pos.line = 0;
            pos.col = cursor.col_wanted;
            line_len := buffer.lines[pos.line].num_chars;
            if pos.col > line_len {
                pos.col = line_len;
            }
        case .ARROW_DOWN;
            if pos.line < buffer.lines.count - 1 then pos.line += 1;
            pos.col = cursor.col_wanted;
            line_len := buffer.lines[pos.line].num_chars;
            if pos.col > line_len {
                pos.col = line_len;
            }
        case .HOME;
            text_start_col: s32= 0;
            line := buffer.lines[pos.line];
            i := line.start;
            while i < line.end {
                byte := buffer.bytes[i];
                if byte != #char " " break;
                text_start_col += 1;
                i += 1 + trailingBytesForUTF8[byte];
            }
            if pos.col > text_start_col || pos.col == 0 then pos.col = text_start_col;
            else pos.col = 0;
            cursor.col_wanted = pos.col;
        case .END;
            pos.col = buffer.lines[pos.line].num_chars;
            cursor.col_wanted = pos.col;
    }
}

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

Cursor :: struct {
    pos, sel: Pos;  // if pos != sel, then we have an active selection
    col_wanted: s32;
}

Editor :: struct {
    buffer_id: s64;

    cursor:   Cursor;
    viewport: Viewport;
}

Pos :: struct {
    line, col: s32;
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
