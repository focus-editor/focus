refresh_open_buffers :: () {
    for *editor : open_editors {
        buffer := *open_buffers[editor.buffer_id];
        if !buffer.dirty continue;
        sync_internal_data(buffer);
        for *cursor : editor.cursors {
            put_cursor_in_valid_spot(cursor, buffer);
        }
    }
}

put_cursor_in_valid_spot :: (using cursor: *Cursor, buffer: Buffer) {
    pos = make_valid_pos(buffer, pos);
    sel = make_valid_pos(buffer, sel);
}

insert_string_at_pos :: (buffer: *Buffer, pos: Pos, str: string) {
    offset := get_offset(buffer, pos);
    insert_string_at_offset(buffer, offset, str);
}

insert_string_at_offset :: (buffer: *Buffer, offset: s64, str: string) {
    new_insert_edit(buffer, offset, str);
    insert_string_raw(buffer, offset, str);
}

insert_char_at_pos :: (buffer: *Buffer, pos: Pos, char: Utf8_Char) {
    offset := get_offset(buffer, pos);
    new_insert_char_edit(buffer, offset, char);
    str := to_string(*char);
    insert_string_raw(buffer, offset, str);
}

delete_range :: (buffer: *Buffer, range: Range) {
    start, end := range_to_byte_offsets(buffer, make_valid_range(buffer, range));
    if start == end return;
    old_str := to_string(array_view(buffer.bytes, start, end - start));
    new_delete_edit(buffer, start, end, old_str);
    delete_range_raw(buffer, start, end);
}

// A dedicated function to avoid having to recalculate lines between deleting range and inserting string
replace_range :: (buffer: *Buffer, range: Range, str: string) {
    start, end := range_to_byte_offsets(buffer, make_valid_range(buffer, range));

    old_str := to_string(array_view(buffer.bytes, start, end - start));
    if str == old_str return;

    new_replace_edit(buffer, start, end, old_str, str);

    replace_range_raw(buffer, start, end, str);
}

delete_range_raw :: (using buffer: *Buffer, start: s64, end: s64) {
    len := end - start;
    if len <= 0 return;
    assert(len <= bytes.count);

    // Copy in chunks of length len while possible
    while end + len <= bytes.count {
        memcpy(bytes.data + start, bytes.data + end, len);
        start += len;
        end   += len;
    }
    // If there's a leftover, copy it
    if end != bytes.count {
        memcpy(bytes.data + start, bytes.data + end, bytes.count - end);
    }

    bytes.count -= len;

    buffer.dirty = true;
}

insert_string_raw :: (buffer: *Buffer, offset: s64, str: string) {
    bytes: [] u8;
    bytes.data  = str.data;
    bytes.count = str.count;
    array_insert_bytes_at(*buffer.bytes, offset, bytes);

    buffer.dirty = true;
}

replace_range_raw :: (buffer: *Buffer, start: s32, end: s32, str: string) {
    delete_range_raw(buffer, start, end);
    insert_string_raw(buffer, start, str);
}

get_offset :: (using buffer: Buffer, pos: Pos) -> s64 {
    assert(!dirty);
    line := lines[pos.line];
    assert(0 <= pos.col && pos.col <= line.num_chars);
    offset := line.start;
    col := 0;
    while offset < line.end && col < pos.col {
        byte := bytes[offset];
        col += 1;
        offset += 1 + trailingBytesForUTF8[byte];
    }
    return offset;
}

offset_to_pos :: (using buffer: Buffer, offset: s64) -> Pos {
    assert(!dirty);
    assert(offset <= lines[lines.count - 1].end);

    pos: Pos = ---;

    left  := 0;
    right := lines.count - 1;

    if offset >= lines[right].start {
        pos.line = xx right;
    } else {
        while (right - left) > 1 {
            middle := left + (right - left) / 2;
            if offset < lines[middle].start {
                right = middle;
            } else {
                left = middle;
            }
        }
        pos.line = xx left;
    }

    // Find col by scanning the line
    pos.col = 0;
    i := lines[pos.line].start;
    while i < offset {
        pos.col += 1;
        i += 1 + trailingBytesForUTF8[bytes[i]];
    }

    return pos;
}

make_valid_range :: (buffer: Buffer, range: Range) -> Range {
    start := make_valid_pos(buffer, range.start, for_cursor = false);
    end   := make_valid_pos(buffer, range.end, for_cursor = false);
    if start.line > end.line || (start.line == end.line && start.col > end.col) {
        start, end = swap(start, end);
    }
    result: Range = ---;
    result.start = start;
    result.end   = end;
    return result;
}

make_valid_pos :: (using buffer: Buffer, _pos: Pos, for_cursor := true) -> Pos {
    assert(!dirty);
    pos := _pos;
    if pos.line < 0 then pos.line = 0;
    if pos.col  < 0 then pos.col  = 0;
    if pos.line >= lines.count then pos.line = xx (lines.count - 1);

    line_len := lines[pos.line].num_chars;
    if !last_line(buffer, pos.line) then line_len += 1;  // we have a trailing \n
    if for_cursor {
        if pos.col >= line_len {
            if !last_line(buffer, pos.line) {
                pos.col = max(line_len - 1, 0);  // cursor can't stand after the newline
            } else {
                pos.col = line_len;  // there's no newline anyway
            }
        }
    } else {
        if pos.col > line_len then pos.col = line_len;
    }
    return pos;
}

range_to_byte_offsets :: (buffer: Buffer, range: Range) -> start: s32, end: s32 {
    start := pos_to_offset(buffer, range.start);
    end   := pos_to_offset(buffer, range.end);
    return start, end;
}

range_length_in_bytes :: (buffer: Buffer, range: Range) -> s64 {
    start, end := range_to_byte_offsets(buffer, range);
    return end - start;
}

bytes_in_range :: (buffer: Buffer, range: Range) -> s64 {
    start, end := range_to_byte_offsets(buffer, range);
    assert(start <= end);
    return end - start;
}

pos_to_offset :: (buffer: Buffer, pos: Pos) -> s32 {
    assert(!buffer.dirty);
    line := buffer.lines[pos.line];
    offset := line.start;
    for col : 0..pos.col-1 {
        byte := buffer.bytes[offset];
        offset += 1 + trailingBytesForUTF8[byte];
    }
    return offset;
}

has_selection :: inline (using cursor: Cursor) -> bool {
    return pos != sel;
}

get_selection :: (using cursor: Cursor) -> Range {
    using range: Range = ---;
    if pos < sel { start = pos; end = sel; } else { start = sel; end = pos; }
    return range;
}

get_selection_whole_lines :: (cursor: Cursor, buffer: Buffer) -> Range {
    assert(!buffer.dirty);
    selection := get_selection(cursor);
    using range: Range = ---;
    start = selection.start;
    start.col = 0;
    end = selection.end;
    if start != end && end.col == 0 && cursor.pos != end {
        // Nothing is selected on the last line - don't include it
        end.line -= 1;
    }
    end.col = buffer.lines[end.line].num_chars;
    return range;
}

get_selected_string :: (cursor: Cursor, buffer: Buffer) -> string {
    result: string;
    if !has_selection(cursor) return result;
    selection  := get_selection(cursor);
    start, end := range_to_byte_offsets(buffer, selection);
    result.data  = buffer.bytes.data + start;
    result.count = end - start;
    return result;
}

get_string_from_range :: (range: Range, buffer: Buffer) -> string {
    result: string;
    start, end := range_to_byte_offsets(buffer, range);
    if start == end return result;

    result.data  = buffer.bytes.data + start;
    result.count = end - start;
    return result;
}

copy_lines_to_temp_string :: (buffer: Buffer, range: Range) -> string {
    // NOTE: copies whole lines, not just the range
    assert(!buffer.dirty);
    start := buffer.lines[range.start.line].start;
    end   := buffer.lines[range.end.line  ].end;
    str   := to_string(array_view(buffer.bytes, start, end - start));
    return copy_temporary_string(str);
}

remove_selection :: inline (using cursor: *Cursor) {
    sel = pos;
}

remove_crlf :: (using buffer: Buffer) {
    i := 0;
    while i < bytes.count {
        if bytes[i] == #char "\r" && i + 1 < bytes.count && bytes[i + 1] == #char "\n" {
            array_ordered_remove_by_index(*bytes, i);
        } else {
            i += 1;
        }
    }
}

last_line :: inline (using buffer: Buffer, line: s32) -> bool {
    return line == lines.count - 1;
}

recalculate_lines :: (buffer: *Buffer) {
    // We mainly use dirty for lines. We may want to recalculate lines
    // a few times within one frame, but we don't want to e.g. rehighlight code
    // more than once (before display)
    buffer.dirty = false;

    array_reset_keeping_memory(*buffer.lines);
    byte_index: s32 = 0;
    char_index: s32 = 0;
    line: Line;
    while byte_index < buffer.bytes.count {
        byte := buffer.bytes[byte_index];
        if line.text_start < 0 && byte != #char " " {
            line.text_start = byte_index;
        }
        if byte == #char "\n" {
            line.end = byte_index;
            line.num_chars = char_index;
            char_index = -1;  // will turn to 0
            array_add(*buffer.lines, line);
            line.start = byte_index + 1;
            line.text_start = -1;
        }
        byte_index += 1 + trailingBytesForUTF8[byte];
        char_index += 1;
    }
    // Final line
    if line.text_start < 0 then line.text_start = byte_index;
    line.end = byte_index;
    line.num_chars = char_index;
    array_add(*buffer.lines, line);
}

sync_internal_data :: (buffer: *Buffer) {
    recalculate_lines(buffer);

    // Highlight code
    {
        // @TODO
    }
}

is_empty :: inline (line: Line) -> bool {
    return line.num_chars == 0;
}

operator == :: (a: Pos, b: Pos) -> bool {
    return a.line == b.line && a.col == b.col;
}

operator < :: (a: Pos, b: Pos) -> bool {
    return a.line < b.line || (a.line == b.line && a.col < b.col);
}

operator - :: (a: Pos, b: Pos) -> Pos {
    r: Pos = ---;
    r.line = a.line - b.line;
    r.col  = a.col  - b.col;
    return r;
}

#scope_file

new_replace_edit :: (buffer: *Buffer, start: s32, end: s32, old_str: string, new_str: string) {
    edit := array_add(*buffer.edits);
    edit.type = .replace;
    using edit.replace;
    offset_range.start = start;
    offset_range.end   = end;
    new_bytes = copy_string(new_str);
    old_bytes = copy_string(old_str);

    clear_redos(buffer);
}

new_insert_edit :: (buffer: *Buffer, offset: s64, str: string) {
    edit := array_add(*buffer.edits);
    edit.type = .insert;
    edit.insert.offset = offset;
    edit.insert.new_bytes = copy_string(str);

    clear_redos(buffer);
}

new_insert_char_edit :: (buffer: *Buffer, offset: s64, char: Utf8_Char) {
    edit := array_add(*buffer.edits);
    edit.type = .insert_char;
    edit.insert_char.offset = offset;
    edit.insert_char.char = char;

    clear_redos(buffer);
}

new_delete_edit :: (buffer: *Buffer, start: s32, end: s32, old_str: string) {
    edit := array_add(*buffer.edits);
    edit.type = .delete;
    using edit.delete;
    offset_range.start = start;
    offset_range.end   = end;
    old_bytes = copy_string(old_str);

    clear_redos(buffer);
}

clear_redos :: (using buffer: *Buffer) {
    for * redos  deinit(it);
    array_reset_keeping_memory(*redos);
}

deinit :: (using edit_group: *Edit_Group) {
    for edit : edits {
        using edit;
        if #complete type == {
            case .insert;  free(insert.new_bytes);
            case .delete;  free(delete.old_bytes);
            case .replace; free(replace.new_bytes);
                           free(replace.old_bytes);
            case .insert_char;  // nothing to free
        }
    }
    array_free(edits);
    array_free(cursors);
}

#scope_export

Buffer :: struct {
    file:  string;  // an empty string means buffer has no file
    bytes: [..] u8;
    lines: [..] Line;

    undos: [..] Edit_Group;
    redos: [..] Edit_Group;
    edits: [..] Edit;  // current edits, not in a group yet
    cursors: [..] Cursor.State;  // cursor state before any current edits were made

    dirty            := true;
    modified         := false;
    modified_on_disk := false;

    last_edit_time: Time;

    lang: enum u8 {
        Plain_Text :: 0;
        Jai;
        Worklog;
    } = .Plain_Text;
}

Line :: struct {
    start, end: s32;
    text_start: s32 = -1;
    num_chars:  s32;
}

Cursor :: struct {
    using state: State;
    col_wanted: s32;
    clipboard: string;

    State :: struct {
        pos, sel: Pos;  // if pos != sel, then we have an active selection
    }
}

Cursor_Offsets :: struct {
    pos, sel: s32;
}

Pos :: struct {
    line, col: s32;
}

Range :: struct {
    start, end: Pos;
}

Offset_Range :: struct {
    start, end: s32;  // we won't open large files anyway
}

Edit_Group :: struct {
    edits: [] Edit;
    cursors: [] Cursor.State;
}

// All strings in this struct are owned
Edit :: struct {
    type: enum { insert; insert_char; replace; delete; };
    union {
        insert: struct {
            offset: s64;
            new_bytes: string;
        };
        insert_char: struct {
            offset: s64;
            char: Utf8_Char;  // same as `insert`, but no need to allocate strings on the heap
                              // it's probably the most common edit so it's worth it
        };
        replace: struct {
            offset_range: Offset_Range;
            new_bytes: string;
            old_bytes: string;
        };
        delete: struct {
            offset_range: Offset_Range;
            old_bytes: string;
        };
    }
}
