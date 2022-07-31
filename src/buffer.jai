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

remove_crlf :: (using buffer: Buffer) {
    i := 0;
    while i < bytes.count {
        if bytes[i] == #char "\r" && i + 1 < bytes.count && bytes[i + 1] == #char "\n" {
            array_ordered_remove_by_index(*bytes, i);
            i -= 1;
        }
        i += 1;
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
