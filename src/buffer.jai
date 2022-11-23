refresh_open_buffers :: () {
    for *editor : open_editors {
        buffer := *open_buffers[editor.buffer_id];
        if !buffer.dirty continue;
        recalculate_lines(buffer);
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

    array_delete_bytes(*bytes, start, len);

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
    assert(!dirty, "buffer is dirty, can't calculate pos from offset");
    assert(offset <= lines[lines.count - 1].end, "offset exceeds buffer size, can't calculate pos");

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

get_temp_unicode_chars_for_line :: (buffer: Buffer, line_num: s32, max_char: s32) -> [] u32 {
    assert(!buffer.dirty);

    if line_num < 0 || line_num >= buffer.lines.count return .[];

    line := buffer.lines[line_num];
    str: string = ---;
    str.data = buffer.bytes.data + line.start;
    str.count = line.end - line.start;
    if str.count <= 0 return .[];

    chars := decode_utf8_string_to_temp_chars(str, max_char);
    return chars;
}

remove_selection :: inline (using cursor: *Cursor) {
    sel = pos;
}

remove_crlf :: (using buffer: *Buffer) {
    dst := bytes.data;
    src := bytes.data;
    end := bytes.data + bytes.count;
    cursor := bytes.data;

    // Remove all CR's in one pass
    while cursor < end {
        byte := <<cursor;
        if byte == #char "\r" {
            count := cursor - src;
            memcpy(dst, src, count);
            dst += count;
            cursor += 1;
            src = cursor;
            continue;
        }
        cursor += 1 + trailingBytesForUTF8[byte];
    }
    // Copy the remaining bit
    count := cursor - src;
    memcpy(dst, src, count);

    bytes.count = dst + count - bytes.data;
}

last_line :: inline (using buffer: Buffer, line: s32) -> bool {
    return line == lines.count - 1;
}

recalculate_lines :: (buffer: *Buffer) {
    // We mainly use dirty for lines. We may want to recalculate lines
    // a few times within one frame, but we don't want to e.g. rehighlight code
    // more than once (before display)
    if buffer.dirty {
        buffer.was_dirty_during_frame = true;
        buffer.dirty = false;
    }

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

recalculate_colors :: (buffer: *Buffer) {
    assert(!buffer.dirty);
    buffer.needs_coloring = false;
    array_resize(*buffer.colors, buffer.bytes.count);  // this will reset colors to 0

    if buffer.lang == {
        case .Jai;      highlight_jai_syntax(buffer);
        case .Worklog;  // TODO
    }

    // // Test colorisation - each word in different color
    // using Simp.Code_Color;
    // color := DEFAULT;
    // left  := 0;
    // right := left;
    // while right < buffer.bytes.count {
    //     byte := buffer.bytes[right];
    //     if byte == #char "\n" || byte == #char " " {
    //         memset(buffer.colors.data + left, xx color, right - left);
    //         color = cast(Simp.Code_Color)((cast(u8) color + 1) % cast(u8) ERROR);
    //         left = right;
    //     }
    //     right += 1;
    // }
}

save_buffer_to_disk :: (using buffer: *Buffer) {
    success := write_entire_file(file.full_path, to_string(bytes));
    if success {
        modified = false;
        modified_on_disk = false;
        deleted = false;
    }
    remember_last_modtime_and_size(buffer);
}

remember_last_modtime_and_size :: (using buffer: *Buffer) {
    assert(has_file, "Trying to remember last modtime and size of a buffer with no file. This is a bug");

    modtime, size, success := file_modtime_and_size(file.full_path);
    if success {
        last_modtime = modtime;
        last_size    = size;
    } else {
        log_error("Couldn't get modtime and size of file %\n", file.full_path);
    }
}

buffer_file_has_changed_on_disk :: (using buffer: *Buffer) -> changed: bool {
    assert(has_file);
    modtime, size, success := file_modtime_and_size(file.full_path);
    if !success {
        log_error("Couldn't get modtime and size of %\n", file.full_path);
        return true;  // consider changed
    }
    return modtime != last_modtime || size != last_size;
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

find_open_buffer_by_path :: (full_path: string) -> *Buffer, buffer_id: s64 {
    for * open_buffers {
        if !it.has_file continue;
        if equal_nocase(it.file.full_path, full_path) return it, it_index;
    }
    return null, -1;
}

maybe_refresh_open_buffers_in_dir :: (dir_path: string) {
    // log("Refreshing buffers in %\n", dir_path);

    for * buffer, buffer_id : open_buffers {
        if !buffer.has_file || !begins_with_nocase(buffer.file.full_path, dir_path) continue;
        if !file_exists(buffer.file.full_path) {
            buffer.deleted = true;
            continue;
        }
        if !buffer_file_has_changed_on_disk(buffer) continue;

        // Buffer has changed on disk
        if buffer.modified {
            // Mark conflict
            // TODO: display a dialog prompting to reload
            buffer.modified_on_disk = true;
        } else {
            // Reload buffer from disk
            file_contents, success := read_entire_file(buffer.file.full_path);
            if !success {
                log_error("Couldn't read file '%'\n", buffer.file.full_path);
                return;
            }
            defer free(file_contents);  // @memory: could probably use temporary storage and reset mark after?

            remember_last_modtime_and_size(buffer);

            // Remember cursor state - if we have 2 editors then the last editor's state will be remembered
            for * editor : open_editors {
                if editor.buffer_id != buffer_id continue;

                new_edit_group(buffer, editor);
                array_resize(*buffer.cursors, editor.cursors.count);
                for * cursor, i : buffer.cursors { <<cursor = editor.cursors[i].state; }
            }

            // Reload its contents
            new_replace_edit(buffer, 0, xx buffer.bytes.count, to_string(buffer.bytes), file_contents);
            replace_range_raw(buffer, 0, xx buffer.bytes.count, file_contents);
            recalculate_lines(buffer);
            buffer.needs_coloring = true;

            // Save edits and put cursors in correct places
            for * editor : open_editors {
                if editor.buffer_id != buffer_id continue;
                new_edit_group(buffer, editor);
                for * cursor : editor.cursors { put_cursor_in_valid_spot(cursor, buffer); }
            }
        }
    }
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
    file: File_Info;
    has_file := false;  // false for freestanding buffers

    last_modtime: Apollo_Time;  // for detecting whether a file has changed
    last_size: s64;             // --

    bytes:  [..] u8;
    lines:  [..] Line;
    colors: [..] Simp.Code_Color;  // u8 - we color each byte (even for multi-byte chars)

    undos: [..] Edit_Group;
    redos: [..] Edit_Group;
    edits: [..] Edit;  // current edits, not in a group yet
    cursors: [..] Cursor.State;  // cursor state before any current edits were made

    dirty                  := false;
    was_dirty_during_frame := false;
    modified               := false;
    modified_on_disk       := false;
    deleted                := false;
    needs_coloring         := false;

    last_edit_time: Time;  // for creating new edit groups

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
