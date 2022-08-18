refresh_open_buffers :: () {
    for *buffer: open_buffers {
        if !buffer.dirty continue;
        sync_internal_data(buffer);
    }
}

insert_string_at_pos :: (using buffer: *Buffer, pos: Pos, str: string) {
    new_size := bytes.count + str.count;
    array_reserve(*bytes, new_size);

    offset := get_offset(<< buffer, pos);

    // Copy in chunks of str.count while possible
    source := bytes.count - str.count;
    dest   := bytes.count;
    while source >= offset {
        memcpy(bytes.data + dest, bytes.data + source, str.count);
        source -= str.count;
        dest   -= str.count;
    }
    // If there's a leftover, copy it as well
    if source != offset {
        memcpy(bytes.data + offset + str.count, bytes.data + offset, str.count - (offset - source));
    }
    // Insert the string
    memcpy(bytes.data + offset, str.data, str.count);

    bytes.count = new_size;
    dirty = true;
}

buffer_delete_range :: (using buffer: *Buffer, _range: Range) {
    range := make_valid_range(<< buffer, _range);
    start, end := range_to_byte_offsets(<< buffer, range);

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
    dirty = true;
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
    pos := _pos;
    if pos.line < 0 then pos.line = 0;
    if pos.col  < 0 then pos.col  = 0;
    if pos.line >= lines.count then pos.line = xx (lines.count - 1);
    line_len := lines[pos.line].num_chars;
    if pos.line < lines.count - 1 then line_len += 1; // we have a trailing \n
    if for_cursor {
        // Cursor can't stand after the newline
        if pos.col >= line_len then pos.col = line_len - 1;
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

pos_to_offset :: (buffer: Buffer, pos: Pos) -> s32 {
    line := buffer.lines[pos.line];
    offset := line.start;
    for col : 0..pos.col-1 {
        byte := buffer.bytes[offset];
        offset += 1 + trailingBytesForUTF8[byte];
    }
    return offset;
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

#scope_file

get_offset :: (using buffer: Buffer, pos: Pos) -> s64 {
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

sync_internal_data :: (buffer: *Buffer) {
    buffer.dirty = false;

    // Recalculate lines
    {
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

    // Highlight code
    {
        // @TODO
    }
}

#scope_export

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
    num_chars:  s32;
}

Cursor :: struct {
    pos, sel: Pos;  // if pos != sel, then we have an active selection
    col_wanted: s32;
}

Pos :: struct {
    line, col: s32;
}

Range :: struct {
    start, end: Pos;
}
