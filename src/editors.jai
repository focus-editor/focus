editors_handle_keypress :: (key_code: Input.Key_Code, mods: Input.Event.Modifier_Flags) {

}

get_active_editor_and_buffer :: () -> *Editor, *Buffer {
    if #complete editors_layout == {
        case .None;
            return null, null;
        case .Single;
            editor := *open_editors[editor_single];
            buffer := *open_buffers[editor.buffer_id];
            return editor, buffer;
        case .Double;
            unimplemented();
            return null, null;
    }
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

refresh_open_buffers :: () {
    for *buffer: open_buffers {
        if !buffer.dirty continue;
        sync_internal_data(buffer);
    }
}

sync_internal_data :: (buffer: *Buffer) {
    buffer.dirty = false;
    assert(buffer.bytes.data != null);

    // Recalculate lines
    {
        array_reset_keeping_memory(*buffer.lines);
        byte_index: s32 = 0;
        line: Line;
        while byte_index < buffer.bytes.count {
            byte := buffer.bytes[byte_index];
            if line.text_start < 0 && byte != #char " " {
                line.text_start = byte_index;
            }
            if byte == #char "\n" {
                line.end = byte_index;
                array_add(*buffer.lines, line);
                line.start      = byte_index + 1;
                line.text_start = -1;
            }
            byte_index += 1 + trailingBytesForUTF8[byte];
        }
        // Final line
        if line.text_start < 0 then line.text_start = byte_index;
        line.end = byte_index;
        array_add(*buffer.lines, line);
    }
    print("Num lines: %\n", buffer.lines.count);

    // Highlight code
    {
        // @TODO
    }
}

#scope_file

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

    if ends_with_nocase(path, ".jai") {
        buffer.lang = .Jai;
    } else if ends_with(path, "LOG.md") {
        buffer.lang = .Worklog;
    }

    return buffer_id;
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

Editor :: struct {
    buffer_id: s64;

    cursor:   Cursor;
    viewport: Viewport;
}

Buffer :: struct {
    file:  string;  // an empty string means buffer has no file
    bytes: [..] u8;
    lines: [..] Line;

    lang: enum u8 {
        Unknown :: 0;
        Jai;
        Worklog;
    } = .Unknown;

    dirty            := true;
    modified         := false;
    modified_on_disk := false;
}

Line :: struct {
    start, end: s32;
    text_start: s32 = -1;
}

Pos :: struct {
    line, col: s32;
}

Viewport :: struct {
    left, top:   s32;
    lines, cols: s32;
}

Cursor :: struct {
    pos, sel: s32;  // if pos != sel, then we have an active selection
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
