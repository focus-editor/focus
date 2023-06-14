refresh_open_buffers :: () {
    for *editor : open_editors {
        buffer := *open_buffers[editor.buffer_id];
        if !buffer.dirty && !buffer.was_dirty_during_frame continue;

        if buffer.dirty rescan_for_lines(buffer);

        buffer.was_dirty_during_frame = false;
        buffer.needs_coloring = true;
        buffer.last_edit_time = frame_time;

        refresh_all_editors_for_buffer(editor.buffer_id);

        session_notify_modified_buffer(editor.buffer_id);

        // Maybe mark buffer as not modified if we've made it match the contents on disk
        buffer.modified = buffer.meow_hash != calculate_meow_hash(buffer.bytes);
        if !buffer.modified then buffer.modified_on_disk = false;  // we've verified that the contents matches that on disk

        finder.need_to_refresh_results = true;
    }
}

put_cursor_in_valid_spot :: (using cursor: *Cursor, buffer: Buffer) {
    pos = clamp(pos, 0, xx buffer.bytes.count);
    sel = clamp(sel, 0, xx buffer.bytes.count);
}

insert_string_at_offset :: (buffer: *Buffer, offset: s64, str: string) {
    new_insert_edit(buffer, offset, str);
    insert_string_raw(buffer, offset, str);
}

insert_char_at_offset :: (buffer: *Buffer, offset: s32, char: Utf8_Char) {
    new_insert_char_edit(buffer, offset, char);
    str := to_string(*char);
    insert_string_raw(buffer, offset, str);
}

delete_range :: (buffer: *Buffer, using range: Offset_Range) {
    if start == end return;
    old_str := to_string(array_view(buffer.bytes, start, end - start));
    new_delete_edit(buffer, start, end, old_str);
    delete_range_raw(buffer, start, end);
}

replace_range :: (buffer: *Buffer, using range: Offset_Range, str: string) {
    old_str := to_string(array_view(buffer.bytes, start, end - start));
    if str == old_str return;

    new_replace_edit(buffer, start, end, old_str, str);

    replace_range_raw(buffer, start, end, str);
}

delete_range_raw :: (using buffer: *Buffer, start: s64, end: s64, $notify := true) {
    len := end - start;
    if len <= 0 return;

    lock(*buffer.content_lock);
    array_delete_bytes(*bytes, start, len);
    unlock(*buffer.content_lock);

    #if notify add_edit_notification(buffer, start, end - start, 0);

    buffer.dirty = true;
}

insert_string_raw :: (buffer: *Buffer, offset: s64, str: string, $notify := true) {
    bytes: [] u8;
    bytes.data  = str.data;
    bytes.count = str.count;

    lock(*buffer.content_lock);
    array_insert_bytes_at(*buffer.bytes, offset, bytes);
    unlock(*buffer.content_lock);

    #if notify add_edit_notification(buffer, offset, 0, str.count);

    buffer.dirty = true;
}

replace_range_raw :: (buffer: *Buffer, start: s32, end: s32, str: string) {
    delete_range_raw(buffer, start, end, notify = false);
    insert_string_raw(buffer, start, str, notify = false);
    add_edit_notification(buffer, start, end - start, str.count);
}

get_char_at_offset :: (using buffer: Buffer, offset: s32) -> u32 {
    str := get_char_at_offset_as_string(buffer, offset);
    if !str return 0;

    char := utf8_next_character(*str);
    return char;
}

get_char_at_offset_as_string :: (using buffer: Buffer, offset: s32) -> string {
    if offset >= bytes.count return "";
    char: string = ---;
    char.data  = *bytes[offset];
    char.count = 1 + trailingBytesForUTF8[bytes[offset]];
    return char;
}

offset_to_coords :: (using buffer: Buffer, offset: s64) -> Coords {
    coords := Coords.{ line = offset_to_line(buffer, offset), col = 0 };

    // Find col by scanning the line
    i := line_starts[coords.line];
    while i < offset {
        byte := bytes[i];
        if byte != #char "\t" {  // I hate tabs
            coords.col += 1;
            i += 1 + trailingBytesForUTF8[bytes[i]];
        } else {
            coords.col += TAB_SIZE - coords.col % TAB_SIZE;
            i += 1;
        }
    }

    return coords;
}

get_cursor_coords :: (buffer: Buffer, using cursor: Cursor) -> Cursor_Coords {
    pos_coords := offset_to_coords(buffer, pos);
    sel_coords := ifx pos != sel then offset_to_coords(buffer, sel) else pos_coords;
    return Cursor_Coords.{ pos = pos_coords, sel = sel_coords };
}

offset_to_line :: (using buffer: Buffer, offset: s64) -> line_num: s32 {
    assert(!dirty, "buffer is dirty, can't calculate line from offset");
    assert(offset <= bytes.count, "offset exceeds buffer size, can't calculate line");

    if line_starts.count < 2 return 0;

    line_num := 0;

    left  := 0;
    right := line_starts.count - 2;

    if offset >= line_starts[right] {
        line_num = right;
    } else {
        while (right - left) > 1 {
            middle := left + (right - left) / 2;
            if offset < line_starts[middle] {
                right = middle;
            } else {
                left = middle;
            }
        }
        line_num = left;
    }

    return cast(s32) line_num;
}

coords_to_offset :: (using buffer: Buffer, coords: Coords) -> s32 {
    assert(!buffer.dirty);

    line := clamp(coords.line, 0, cast(s32)line_starts.count - 2);
    offset := line_starts[line];
    if offset >= bytes.count return xx bytes.count;

    max_offset := get_line_end_offset(buffer, line);

    col := 0;
    while true {
        byte := bytes[offset];
        if byte != #char "\t" then col += 1; else col += TAB_SIZE - col % TAB_SIZE;
        if col > coords.col break;
        next_offset := offset + 1 + trailingBytesForUTF8[byte];
        if next_offset >= max_offset {
            offset = max_offset;
            break;
        }
        offset = next_offset;
    }
    return offset;
}

is_last_line :: (using buffer: Buffer, line: s32) -> bool {
    return line >= line_starts.count - 2;
}

get_line_start_offset :: inline (using buffer: Buffer, line: s32) -> s32 {
    return line_starts[clamp(line, 0, cast(s32) line_starts.count - 1)];
}

get_line_end_offset :: (using buffer: Buffer, line: s32) -> s32 {
    offset := get_line_start_offset(buffer, line + 1);
    if !is_last_line(buffer, line) then offset -= 1;
    return offset;
}

has_selection :: inline (using cursor: Cursor) -> bool {
    return pos != sel;
}

get_selection :: (using cursor: Cursor) -> Offset_Range {
    return .{ start = min(pos, sel), end = max(pos, sel) };
}

get_selection_coords :: (buffer: Buffer, using cursor: Cursor) -> Coords_Range {
    selection := inline get_selection(cursor);
    return .{
        start = offset_to_coords(buffer, selection.start),
        end   = offset_to_coords(buffer, selection.end),
    };
}

get_selected_string :: (cursor: Cursor, buffer: Buffer) -> string {
    if !has_selection(cursor) return "";
    return get_range_as_string(buffer, get_selection(cursor));
}

remove_crlf_in_place :: (bytes: *[] u8) {
    dst := bytes.data;
    src := bytes.data;
    end := bytes.data + bytes.count;
    cursor := bytes.data;

    // @Speed TODO: should probably use SIMD
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
        cursor += 1;
    }
    // Copy the remaining bit
    count := cursor - src;
    memcpy(dst, src, count);

    bytes.count = dst + count - bytes.data;
}

rescan_for_lines :: (using buffer: *Buffer) {
    if dirty {
        was_dirty_during_frame = true;
        dirty = false;
    }

    array_reset_keeping_memory(*line_starts);
    array_add(*line_starts, 0);  // first line

    s := to_string(bytes);

    // NOTE: this implementation is slightly faster on my machine, but really not by much - need to test on other machines
    if check_feature(cpu_info.feature_leaves, x86_Feature_Flag.AVX2) {
        // Scan by 16 bytes at a time
        lf := 0xA; // '\n'
        #asm AVX2 {
            movq lf_source:, lf;
            pbroadcastb.x line_feeds:, lf_source;
        }
        data := s.data;
        count := s.count;
        while count >= 16 {
            mask:  u32 = ---;
            #asm {
                movdqu      batch:, [data];
                pcmpeqb.x   batch, line_feeds;
                pmovmskb.x  mask, batch;
            }
            shift := 0;
            bit_id: u32 = ---;
            while mask {
                #asm {
                    bsf.d bit_id, mask;
                }
                mask >>= (bit_id + 1);
                shift += bit_id + 1;
                array_add(*line_starts, cast,no_check(s32)(data - bytes.data + shift));
            }
            count -= 16;
            data  += 16;
        }
        s.data = data;
        s.count = count;
    }

    processed_with_simd := s.data - bytes.data;
    start_index := 0;
    while true {
        index := inline find_index_from_left(s, 0xA, start_index);
        if index >= 0 {
            start_index = index + 1;
            array_add(*line_starts, cast,no_check(s32) (processed_with_simd + start_index));
        } else {
            break;
        }
    }

    array_add(*line_starts, cast(s32) bytes.count);  // last line
}

recalculate_colors :: (buffer: *Buffer) {
    assert(!buffer.dirty);
    buffer.needs_coloring = false;
    array_resize(*buffer.colors, buffer.bytes.count);  // this will reset colors to 0

    if buffer.lang == {
        case .Jai;          highlight_jai_syntax(buffer);
        case .C;            highlight_c_syntax(buffer);
        case .CSharp;       highlight_csharp_syntax(buffer);
        case .Focus_Config; highlight_focus_config_syntax(buffer);
        case .Worklog;      highlight_worklog(buffer);
    }
}

save_buffer_to_disk :: (using buffer: *Buffer, buffer_id: s64) -> saved: bool {
    if readonly return false;

    if !has_file {
        file_path, success := platform_get_save_file_name(get_buffer_name(buffer));
        if success && file_path {
            has_file = true;
            file = get_file_info_from_full_path(file_path);
            set_lang_from_path(buffer, file_path);
            needs_coloring = true;
            redraw_requested = true;

            lock(*open_buffers_lock);
            existing_buffer_id, found_existing := table_find(*buffers_table, file_path);
            if found_existing && buffer_id != existing_buffer_id {
                // The user chose to save the new buffer into an existing file. OK.
                // Mark the old buffer as deleted and use the new one
                removed := table_remove(*buffers_table, file_path);
                assert(removed, "For some reason table_remove failed. This is a very unexpected bug.");
                existing_buffer := *open_buffers[existing_buffer_id];
                existing_buffer.deleted  = true;
                existing_buffer.modified = false;
                existing_buffer.modified_on_disk = false;

                // Reroute all editors which use it to the new buffer id
                for * editor : open_editors {
                    if editor.buffer_id == existing_buffer_id {
                        editor.buffer_id = buffer_id;
                        editor.scroll_to_cursor = .yes;
                        for * cursor : editor.cursors { put_cursor_in_valid_spot(cursor, buffer); }
                        organise_cursors(editor);
                    }
                }
            } else if found_existing && buffer_id == existing_buffer_id {
                assert(false, "Buffer without a file somehow got into the buffers hash table. This is a bug.");
            }

            table_add(*buffers_table, copy_string(file_path), buffer_id);
            unlock(*open_buffers_lock);

            if !file_is_watched(file_path) start_watching_file(file_path);
        } else {
            return false;
        }
    }

    if config.settings.strip_trailing_whitespace_on_save then strip_trailing_whitespace(buffer, buffer_id);

    success := write_entire_file(file.full_path, to_string(bytes));
    if success {
        modified = false;
        modified_on_disk = false;
        deleted = false;

        meow_hash = calculate_meow_hash(bytes);

        error_when_saving = false;
        crlf = false;
    } else {
        error_when_saving = true;
    }
    remember_last_modtime_and_size(buffer);

    update_window_title(open_editors[editors.active].buffer_id);

    return !error_when_saving;
}

strip_trailing_whitespace :: (using buffer: *Buffer, buffer_id: s64) {
    mark := get_temporary_storage_mark();
    defer   set_temporary_storage_mark(mark);

    b: String_Builder;
    b.allocator = temp;
    init_string_builder(*b, buffer_size = bytes.count + size_of(String_Builder.Buffer));
    lines := split(to_string(bytes), cast(u8) #char "\n");
    for line, i : lines {
        append(*b, trim_right(line));
        if i < lines.count - 1 then append(*b, "\n");
    }
    stripped := builder_to_string(*b);

    if stripped.count == bytes.count return;  // nothing stripped

    // Remember all cursor positions in all editors for the buffer
    Editor_Cursor_State :: struct { editor_id: s64; cursor_id: s64; coords: Cursor_Coords; }
    cursor_states: [..] Editor_Cursor_State;
    cursor_states.allocator = temp;
    for * editor, editor_id : open_editors {
        if editor.buffer_id != buffer_id continue;
        editor.refresh_highlights = true;

        for cursor, cursor_id : editor.cursors {
            array_add(*cursor_states, Editor_Cursor_State.{ editor_id, cursor_id, get_cursor_coords(buffer, cursor) });
        }
    }

    // Replace buffer contents
    new_replace_edit(buffer, 0, xx bytes.count, to_string(bytes), stripped);

    lock(*content_lock);
    memcpy(bytes.data, stripped.data, stripped.count);
    bytes.count = stripped.count;
    unlock(*content_lock);

    rescan_for_lines(buffer);

    // Put cursors into valid places
    max_line := cast(s32) buffer.line_starts.count - 2;
    for state : cursor_states {
        using state;
        editor := *open_editors[editor_id];

        pos, sel := coords.pos, coords.sel;
        pos.line = clamp(pos.line, 0, max_line);
        pos.col  = clamp(pos.col,  0, num_chars_in_string(get_line_as_string(buffer, pos.line)));
        sel.line = clamp(sel.line, 0, max_line);
        sel.col  = clamp(sel.col,  0, num_chars_in_string(get_line_as_string(buffer, sel.line)));

        cursor := *editor.cursors[cursor_id];
        cursor.pos = coords_to_offset(buffer, pos);
        cursor.sel = coords_to_offset(buffer, sel);
    }
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

is_empty :: (using buffer: Buffer, line_num: s32) -> bool {
    s := get_line_as_string(buffer, line_num);
    return is_all_whitespace(s);
}

get_line_as_string :: (using buffer: Buffer, line_num: s32) -> string {
    assert(!buffer.dirty);
    if line_num < 0 || line_num >= buffer.line_starts.count - 1 return "";

    start := line_starts[line_num];
    end   := line_starts[line_num + 1];

    result: string = ---;
    result.data  = bytes.data + start;
    result.count = end - start;

    return result;
}

find_or_create_an_empty_buffer :: () -> buffer_id: s64, created: bool {
    if workspace_scan_complete {
        // Return the first empty standalone buffer to avoid creating a million new buffers.
        // We have to only do this if the workspace scan is complete, otherwise we'll be in for
        // many surprising thread-related bugs
        for * buffer, buffer_id : open_buffers {
            if !buffer.has_file && !trim(to_string(buffer.bytes)) return buffer_id, false;
        }
    }

    // Create a new buffer
    lock(*open_buffers_lock);
    defer unlock(*open_buffers_lock);

    buffer_id := open_buffers.count;
    buffer := bucket_array_add(*open_buffers);
    init_buffer(buffer);
    buffer.has_file = false;

    rescan_for_lines(buffer);
    recalculate_colors(buffer);

    return buffer_id, true;
}

find_or_create_buffer :: (path: string) -> buffer_id: s64, created: bool {
    #if OS == .WINDOWS {
        if path.count > 248 return -1, false;  // Windows bad
    }
    lock(*open_buffers_lock);

    buffer_id, found_buffer := table_find(*buffers_table, path);
    buffer: *Buffer = ---;

    if !found_buffer {
        buffer_id = open_buffers.count;
        buffer = bucket_array_add(*open_buffers);
        init_buffer(buffer);
        table_add(*buffers_table, copy_string(path), buffer_id);  // It should be ok to leak some memory here when we no longer need a buffer
    }

    unlock(*open_buffers_lock);  // only hold the lock when it's critical

    if found_buffer return buffer_id, false;

    // Create and load file
    file_data, success := read_entire_file(path);
    if !success then file_data = sprint("Couldn't load file '%'", path);
    if is_file_binary(file_data) {
        free(file_data);
        file_data = sprint("Couldn't display file '%' because it's either binary or non-UTF8.", path);
        buffer.readonly = true;
        buffer.binary   = true;
    }

    // Fill in buffer data
    buffer.file = get_file_info_from_full_path(path);
    buffer.has_file = true;
    remember_last_modtime_and_size(buffer);

    lock(*buffer.content_lock);
    buffer.bytes = resizable(to_bytes(file_data));
    old_size := buffer.bytes.count;
    remove_crlf_in_place(*buffer.bytes);
    unlock(*buffer.content_lock);

    buffer.crlf = buffer.bytes.count != old_size;

    buffer.meow_hash = calculate_meow_hash(buffer.bytes);

    set_lang_from_path(buffer, path);

    rescan_for_lines(buffer);
    recalculate_colors(buffer);

    return buffer_id, true;
}

get_buffer_name :: (buffer: Buffer) -> string {
    if buffer.has_file return buffer.file.name;

    for 0..buffer.line_starts.count-2 {
        line := trim(get_line_as_string(buffer, xx it), "\t \r\n");
        if line return take_first_n_chars(line, min(50, line.count));
    }

    return "<new file>";
}

refresh_buffer_from_disk :: (path: string) {
    if is_our_config_file(path) refresh_config(path);

    buffer_id, created := find_or_create_buffer(path);
    if created return;
    if buffer_id < 0 {
        #if DEBUG_FILE_REFRESH log("ERROR: can't open file - path too long");
        log_error("Couldn't open file because path is too long for Windows: %\n", path);
        return;
    }

    buffer := *open_buffers[buffer_id];

    if !file_exists(path) {
        buffer.deleted = true;
        finder.need_to_refresh_results = true;
        #if DEBUG_FILE_REFRESH log("File % doesn't exist", path);
        return;
    }

    if !buffer_file_has_changed_on_disk(buffer) {
        #if DEBUG_FILE_REFRESH log("File % supposedly hasn't changed on disk", path);
        return;
    }

    finder.need_to_refresh_results = true;

    // Buffer may have changed on disk - reload and compare hashes to be sure
    assert(path == buffer.file.full_path);

    // Reload buffer from disk
    file_contents_str, success := read_entire_file(path);
    if is_file_binary(file_contents_str) {
        free(file_contents_str);
        file_contents_str = sprint("Couldn't display file '%' because it's either binary or non-UTF8.", path);
        buffer.readonly = true;
    }

    if !success { log_error("Couldn't read file '%'\n", path); #if DEBUG_FILE_REFRESH log("Couldn't read file"); return; }
    defer free(file_contents_str);

    file_contents := cast([] u8) file_contents_str;
    lock(*buffer.content_lock);
    remove_crlf_in_place(*file_contents);
    unlock(*buffer.content_lock);
    file_contents_str = to_string(file_contents);

    file_hash := calculate_meow_hash(file_contents);
    if buffer.meow_hash == file_hash {
        #if DEBUG_FILE_REFRESH log("Meow hash hasn't changed for %", path);
        return;  // file hasn't actually changed
    }

    buffer.meow_hash = file_hash;
    buffer.deleted = false;

    if buffer.modified {
        // Mark conflict
        // TODO: display a dialog prompting to reload
        buffer.modified_on_disk = true;
    } else {
        remember_last_modtime_and_size(buffer);

        // Remember cursor state - if we have 2 editors then the last editor's state will be remembered
        for * editor : open_editors {
            if editor.buffer_id != buffer_id continue;

            new_edit_group(buffer, editor);
            array_resize(*buffer.cursors, editor.cursors.count);
            for * cursor, i : buffer.cursors { <<cursor = editor.cursors[i].state; }
        }

        // Reload its contents
        new_replace_edit(buffer, 0, xx buffer.bytes.count, to_string(buffer.bytes), file_contents_str);
        replace_range_raw(buffer, 0, xx buffer.bytes.count, file_contents_str);
        rescan_for_lines(buffer);

        // Save edits and put cursors in correct places
        for * editor : open_editors {
            if editor.buffer_id != buffer_id continue;
            new_edit_group(buffer, editor);
            for * cursor : editor.cursors { put_cursor_in_valid_spot(cursor, buffer); }
            organise_cursors(editor);
        }
    }

    refresh_all_editors_for_buffer(buffer_id);
    #if DEBUG_FILE_REFRESH log("Refreshed %", path);
}

maybe_mark_buffer_as_deleted :: (path: string) {
    lock(*open_buffers_lock);
    defer unlock(*open_buffers_lock);

    buffer_id, found_buffer := table_find(*buffers_table, path);
    if !found_buffer return;  // no buffer for this path
    maybe_mark_buffer_as_deleted(buffer_id);
}

maybe_mark_buffer_as_deleted :: (buffer_id: s64) {
    buffer := *open_buffers[buffer_id];
    if !buffer.has_file return;
    if file_exists(buffer.file.full_path) return;  // no need to mark as deleted

    buffer.deleted = true;
    finder.need_to_refresh_results = true;
}

free_buffer :: (using buffer: *Buffer) {
    // We don't do it often so it's ok to be slow here
    array_free(bytes);
    array_free(line_starts);
    array_free(real_line_starts);
    array_free(colors);

    for * undos deinit(it);
    for * redos deinit(it);
    array_free(undos);
    array_free(redos);
    array_free(edits);
    array_free(edit_notifications);

    array_free(cursors);

    if has_file && file.full_path then free(file.full_path);
}

// NOTE: this works with absolute columns only, with no regard to line wrapping!
find_col_by_scanning_left :: (using buffer: *Buffer, offset: s32) -> col: s32 {
    byte: u8;
    col: s32;

    while offset > 0 {
        offset, byte = prev_char_offset(bytes, offset);
        if byte == #char "\n" break;
        col += 1;
    }

    return col;
}

get_range_as_string :: (buffer: Buffer, range: Offset_Range) -> string {
    result: string = ---;

    assert(range.start >= 0, "Tried to get a buffer range as string before the buffer bytes begin");

    result.data  = buffer.bytes.data + range.start;
    result.count =  max(range.end - range.start, 0);

    return result;
}

init_buffer :: (buffer: *Buffer) {
    init(*buffer.content_lock);
}

unsaved_buffers_exist :: () -> bool {
    // Linear search, hmmmm, that sounds slow.
    // Perhaps I should write an unsaved buffers http service,
    // which would tell me if they exist in a O(1) time?
    for open_buffers {
        if it.modified return true;
    }
    return false;
}

remove_all_buffers :: () {
    deinit(*buffers_table);
    for * open_buffers free_buffer(it);
    bucket_array_reset(*open_buffers);
}

#scope_file

add_edit_notification :: (using buffer: *Buffer, offset: s64, old_count: s64, new_count: s64) {
    if num_editors_open < 2 return;
    array_add(*edit_notifications, Buffer.Edit_Notification.{
        editor_id = cast(s32) context.current_editor_id,
        offset    = cast(s32) (offset + min(old_count, new_count)),
        delta     = cast(s32) (new_count - old_count),
    });
}

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

deinit :: (using edit_group: *Buffer.Edit_Group) {
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

// TODO:
// - reorganise to reduce size
// - replace all [..] with a custom array type without an allocator (also probably using s32's)
Buffer :: struct {
    file: File_Info;
    num_times_opened: u8;
    num_editors_open: u8;

    meow_hash: u64;
    last_modtime: Apollo_Time;  // for detecting whether a file has changed
    last_size: s64;             // --

    bytes:  [..] u8;
    line_starts: [..] s32;       // may not correspond to actual line breaks in the buffer
    real_line_starts: [..] s32;  // for displaying the line/column numbers

    colors: [..] u8;             // we color each byte (even for multi-byte chars)
                                 // @Space: we could use a u4 instead

    // TODO: put into enum_flags
    has_file := false;  // false for freestanding buffers. TODO: make freestanding buffers separate?
    dirty                  := false;
    was_dirty_during_frame := false;
    modified               := false;
    modified_on_disk       := false;
    deleted                := false;
    needs_coloring         := false;
    readonly               := false;
    binary                 := false;
    error_when_saving      := false;
    crlf                   := false;

    content_lock: Mutex;  // must hold while modifying content (or reading in an off thread)

    last_edit_time: Time;  // for creating new edit groups

    undos: [..] Edit_Group;
    redos: [..] Edit_Group;
    edits: [..] Edit;  // current edits, not in a group yet
    cursors: [..] Cursor.State;  // cursor state before any current edits were made
    edit_notifications: [..] Edit_Notification;

    lang: enum u8 {
        Plain_Text :: 0;
        Jai;
        C;
        CSharp;
        Focus_Config;
        Worklog;
    } = .Plain_Text;

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

    // This is used to notify other editors for a buffer about edits.
    // This field set represents inserts, replaces and deletes in a uniform way
    Edit_Notification :: struct {
        editor_id: s32;
        offset:    s32;
        delta:     s32;
    }
}

Cursor :: struct {
    using state: State;

    State :: struct { pos, sel: s32; col_wanted: s32 = -1; }
}

#assert size_of(Cursor) == (2 + 1) * size_of(s32);  // make sure no padding accidentally gets added

Cursor_Coords :: struct {
    pos, sel: Coords;
}

Coords :: struct {
    line, col: s32;
}

Offset_Range :: struct {
    start, end: s32;  // we won't open large files anyway
}

Coords_Range :: struct {
    start, end: Coords;
}

