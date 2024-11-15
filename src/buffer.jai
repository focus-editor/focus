refresh_open_buffers :: () {
    for * editor : open_editors {
        buffer := *open_buffers[editor.buffer_id];

        if editor.line_wrap == {
            case .to_disable;   reset_keeping_memory(*editor.wrapped_line_starts); editor.line_wrap = .off;
            case .to_enable;    rescan_for_wrapped_lines(editor, buffer);          editor.line_wrap = .on;
        }

        if !buffer.dirty && !buffer.was_dirty_during_frame continue;

        if buffer.dirty rescan_for_lines(buffer);

        buffer.was_dirty_during_frame = false;
        buffer.needs_tokenizing = true;
        buffer.last_edit_time = frame_time64;

        refresh_all_editors_for_buffer(editor.buffer_id);

        session_notify_modified_buffer(editor.buffer_id);

        // Maybe mark buffer as not modified if we've made it match the contents on disk
        if !buffer.readonly then buffer.modified = buffer.meow_hash != calculate_hash(to_view(buffer.bytes));
        if !buffer.modified then buffer.modified_on_disk = false;  // we've verified that the contents matches that on disk

        finder.need_to_refresh_results = true;
        open_file_dialog.should_refresh_entries = true;
    }
}

put_cursor_in_valid_spot :: (using cursor: *Cursor, buffer: Buffer) {
    pos = clamp(pos, 0, xx buffer.bytes.count);
    sel = clamp(sel, 0, xx buffer.bytes.count);
}

insert_string_at_offset :: (buffer: *Buffer, offset: s32, str: string) {
    new_insert_edit(buffer, offset, str);
    insert_string_raw(buffer, offset, str);
}

insert_char_at_offset :: (buffer: *Buffer, offset: s32, char: Utf8_Char) {
    str := to_string(*char);
    new_insert_char_edit(buffer, offset, char);
    insert_string_raw(buffer, offset, str);
}

delete_range :: (buffer: *Buffer, using range: Offset_Range) {
    if start == end return;
    old_str := cast(string) to_view(buffer.bytes, start, end - start);
    new_delete_edit(buffer, start, end, old_str);
    delete_range_raw(buffer, start, end);
}

replace_range :: (buffer: *Buffer, using range: Offset_Range, str: string) {
    old_str := cast(string) to_view(buffer.bytes, start, end - start);
    if str == old_str return;

    new_replace_edit(buffer, start, end, old_str, str);
    replace_range_raw(buffer, start, end, str);
}

delete_range_raw :: (using buffer: *Buffer, start: s32, end: s32, $notify := true) {
    len := end - start;
    if len <= 0 return;

    lock(*buffer.content_lock);
    delete_range(*bytes, start, len);
    unlock(*buffer.content_lock);

    #if notify add_edit_notification(buffer, start, end - start, 0);

    buffer.dirty = true;
}

insert_string_raw :: (buffer: *Buffer, offset: s32, str: string, $notify := true) {
    bytes: [] u8;
    bytes.data  = str.data;
    bytes.count = str.count;

    lock(*buffer.content_lock);
    insert_at(*buffer.bytes, offset, bytes);
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

get_char_at_coords :: (editor: Editor, buffer: Buffer, coords: Coords) -> u32 {
    closest_offset := coords_to_offset(editor, buffer, coords);
    closest_coords := offset_to_coords(editor, buffer, closest_offset);

    if coords.line != closest_coords.line  || coords.col != closest_coords.col {
        return 0;
    }

    return get_char_at_offset(buffer, closest_offset);
}

get_char_at_offset_as_string :: (using buffer: Buffer, offset: s32) -> string {
    if offset >= bytes.count return "";
    char: string = ---;
    char.data  = *bytes[offset];
    char.count = clamp(cast(s64)(1 + trailingBytesForUTF8[bytes[offset]]), 0, bytes.count - offset);
    return char;
}

get_line_starts :: (editor: Editor, buffer: Buffer) -> [] s32 {
    if line_wrap_is_active(editor) {
        return to_view(editor.wrapped_line_starts);
    } else {
        return to_view(buffer.line_starts);
    }
}

offset_to_coords :: (editor: Editor, buffer: Buffer, offset: s32) -> Coords {
    line := offset_to_line(editor, buffer, offset);
    col  := _get_visual_col_by_scanning_line(buffer, line, offset, get_line_starts(editor, buffer));

    return Coords.{ line = line, col = col };
}

offset_to_real_coords :: (buffer: Buffer, offset: s32) -> Coords {
    line := offset_to_real_line(buffer, offset);
    col  := _get_visual_col_by_scanning_line(buffer, line, offset, to_view(buffer.line_starts));

    return Coords.{ line = line, col = col };
}

// This function counts visual indent, taking tab size into account
_get_visual_col_by_scanning_line :: (buffer: Buffer, line_num: s32, offset: s32, line_starts: [] s32) -> col: s32 {
    tab_size := get_buffer_tab_size(buffer);
    return num_cols_in_string(xx to_view(buffer.bytes, line_starts[line_num], offset - line_starts[line_num]), tab_size);
}

get_cursor_coords :: (editor: Editor, buffer: Buffer, using cursor: Cursor) -> Cursor_Coords {
    pos_coords := offset_to_coords(editor, buffer, pos);
    sel_coords := ifx pos != sel then offset_to_coords(editor, buffer, sel) else pos_coords;
    return Cursor_Coords.{ pos = pos_coords, sel = sel_coords };
}

get_real_cursor_coords :: (buffer: Buffer, using cursor: Cursor) -> Cursor_Coords {
    pos_coords := offset_to_real_coords(buffer, pos);
    sel_coords := ifx pos != sel then offset_to_real_coords(buffer, sel) else pos_coords;
    return Cursor_Coords.{ pos = pos_coords, sel = sel_coords };
}

offset_to_line :: (editor: Editor, buffer: Buffer, offset: s64) -> line_num: s32 {
    assert(!buffer.dirty, "buffer is dirty, can't calculate line from offset");
    assert(offset <= buffer.bytes.count, "offset exceeds buffer size, can't calculate line");

    line_starts := get_line_starts(editor, buffer);
    return search_line_num_by_offset(line_starts, offset);
}

offset_to_real_line :: (using buffer: Buffer, offset: s64) -> line_num: s32 {
    assert(!dirty, "buffer is dirty, can't calculate line from offset");
    assert(offset <= bytes.count, "offset exceeds buffer size, can't calculate line");

    return search_line_num_by_offset(to_view(line_starts), offset);
}

Editor_Cursor_Position :: struct { editor_id: s64; cursor_id: s64; coords: Cursor_Coords; }

remember_cursor_positions :: (buffer_id: s64, in: enum { all_editors; active_editor; }) -> [] Editor_Cursor_Position /* temp */ {
    buffer := *open_buffers[buffer_id];

    cursor_positions: [..] Editor_Cursor_Position;
    cursor_positions.allocator = temp;

    for * editor, editor_id : open_editors {
        if editor.buffer_id != buffer_id continue;
        if in == .active_editor && editor_id != editors.active continue;
        editor.refresh_selection = true;

        new_edit_group(buffer, editor);

        for cursor, cursor_id : editor.cursors {
            array_add(*cursor_positions, Editor_Cursor_Position.{ editor_id, cursor_id, get_real_cursor_coords(buffer, cursor) });
        }
    }

    // We also want to remember cursors in the buffer itself for the subsequent undos, preferably from the active editor
    editor_cursors: [] Cursor;
    active_editor, _ := get_active_editor_and_buffer();
    if active_editor && active_editor.buffer_id == buffer_id {
        editor_cursors = to_view(active_editor.cursors);
    } else {
        // Just take any editor
        for editor : open_editors {
            if editor.buffer_id == buffer_id {
                editor_cursors = to_view(editor.cursors);
                break;
            }
        }
    }
    if editor_cursors {
        resize(*buffer.cursors, editor_cursors.count);
        for * cursor, i : buffer.cursors { cursor.* = editor_cursors[i]; }
    }

    return cursor_positions;
}

restore_cursor_positions :: (buffer_id: s64, cursor_positions: [] Editor_Cursor_Position) {
    buffer := *open_buffers[buffer_id];
    if buffer.dirty then rescan_for_lines(buffer);

    tab_size := get_buffer_tab_size(buffer);

    max_line := cast(s32) buffer.line_starts.count - 2;
    for position : cursor_positions {
        using position;
        editor := *open_editors[editor_id];

        pos, sel := coords.pos, coords.sel;
        pos.line = clamp(pos.line, 0, max_line);
        pos.col  = clamp(pos.col,  0, num_cols_in_string(get_real_line_as_string(buffer, pos.line), tab_size));
        sel.line = clamp(sel.line, 0, max_line);
        sel.col  = clamp(sel.col,  0, num_cols_in_string(get_real_line_as_string(buffer, sel.line), tab_size));

        cursor := *editor.cursors[cursor_id];
        cursor.pos = real_coords_to_offset(buffer, pos);
        cursor.sel = real_coords_to_offset(buffer, sel);
    }
}

search_line_num_by_offset :: (line_starts: [] s32, offset: s64) -> line_num: s32 {
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

coords_to_offset :: (editor: Editor, buffer: Buffer, coords: Coords) -> s32 {
    assert(!buffer.dirty);

    return _get_offset_by_coords(buffer, get_line_starts(editor, buffer), coords);
}

real_coords_to_offset :: (using buffer: Buffer, coords: Coords) -> s32 {
    assert(!buffer.dirty);

    return _get_offset_by_coords(buffer, to_view(buffer.line_starts), coords);
}

_get_offset_by_coords :: (buffer: Buffer, line_starts: [] s32, coords: Coords) -> offset: s32 {
    tab_size := get_buffer_tab_size(buffer);

    line := clamp(coords.line, 0, cast(s32)line_starts.count - 2);
    offset := line_starts[line];
    if offset >= buffer.bytes.count return xx buffer.bytes.count;

    max_offset := line_starts[line+1];
    if max_offset > 0 && max_offset-1 < buffer.bytes.count && buffer.bytes[max_offset-1] == #char "\n" then max_offset -= 1;

    col := 0;
    while true {
        byte := buffer.bytes[offset];
        if byte != #char "\t" then col += 1; else col += tab_size - col % tab_size;
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

is_last_line :: (editor: Editor, buffer: Buffer, line: s32) -> bool {
    return line >= get_line_starts(editor, buffer).count - 2;
}

is_last_real_line :: (using buffer: Buffer, line: s32) -> bool {
    return line >= line_starts.count - 2;
}

get_real_line_range :: inline (buffer: Buffer, line: s32) -> Offset_Range {
    return .{ start = get_real_line_start_offset(buffer, line), end = get_real_line_end_offset(buffer, line) };
}

get_real_line_start_offset :: inline (using buffer: Buffer, line: s32) -> s32 {
    return line_starts[clamp(line, 0, cast(s32) line_starts.count - 1)];
}

get_real_line_end_offset :: (using buffer: Buffer, line: s32) -> s32 {
    offset := get_real_line_start_offset(buffer, line + 1);

    if !is_last_real_line(buffer, line) then offset -= 1;
    return offset;
}

get_line_start_offset :: inline (editor: Editor, buffer: Buffer, line: s32) -> s32 {
    line_starts := get_line_starts(editor, buffer);
    return line_starts[clamp(line, 0, cast(s32)line_starts.count - 1)];
}

get_line_end_offset :: (editor: Editor, buffer: Buffer, line: s32) -> s32 {
    offset := get_line_start_offset(editor, buffer, line + 1);
    if offset > 0 && offset-1 < buffer.bytes.count && buffer.bytes[offset-1] == #char "\n" then offset -= 1;

    return offset;
}

has_selection :: inline (using cursor: Cursor) -> bool {
    return pos != sel;
}

get_selection :: (using cursor: Cursor) -> Offset_Range {
    return .{ start = min(pos, sel), end = max(pos, sel) };
}

get_selected_string :: (cursor: Cursor, buffer: Buffer) -> string {
    if !has_selection(cursor) return "";
    return get_range_as_string(buffer, get_selection(cursor));
}

remove_crlf_in_place :: (bytes: *[] u8) -> bytes_removed: s64 {
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
            focus_memcpy(dst, src, count);
            dst += count;
            cursor += 1;
            src = cursor;
            continue;
        }
        cursor += 1;
    }
    // Copy the remaining bit
    count := cursor - src;
    focus_memcpy(dst, src, count);

    new_count := dst + count - bytes.data;
    bytes_removed := bytes.count - new_count;
    bytes.count = new_count;

    return bytes_removed;
}

remove_crlf_in_place :: inline (array: *Array(u8)) -> bytes_removed: s64 {
    bytes := to_view(array);
    bytes_removed := remove_crlf_in_place(*bytes);
    array.count = cast(s32) bytes.count;
    return bytes_removed;
}

remove_crlf_in_place :: inline (str: *string) -> bytes_removed: s64 {
    return remove_crlf_in_place(cast(*[] u8) str);
}

rescan_for_lines :: (using buffer: *Buffer) {
    lock(*buffer.content_lock);
    defer unlock(*buffer.content_lock);

    if dirty {
        was_dirty_during_frame = true;
        dirty = false;
    }

    reset_keeping_memory(*line_starts);
    add(*line_starts, 0);  // first line

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
                add(*line_starts, cast,no_check(s32)(data - bytes.data + shift));
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
            add(*line_starts, cast,no_check(s32) (processed_with_simd + start_index));
        } else {
            break;
        }
    }

    add(*line_starts, cast(s32) bytes.count);  // last line
}

rescan_for_wrapped_lines :: (editor: *Editor, buffer: Buffer) {
    // Not locking here because rescanning for wrapped lines should only happen in the main thread

    reset_keeping_memory(*editor.wrapped_line_starts);
    reserve(*editor.wrapped_line_starts, buffer.line_starts.count);  // can't be less than that

    tab_size := get_buffer_tab_size(buffer);

    add(*editor.wrapped_line_starts, 0);  // first line

    max_width_in_chars := ifx editor.last_width_in_chars > 0 then editor.last_width_in_chars else S32_MAX;
    current_line_width := 0;

    i: s32 = 0;

    // @Speed: This runs for each character. Ugh
    while i < buffer.bytes.count {
        byte := buffer.bytes[i];
        this_char_index := i;

        if byte == #char "\t" {  // I hate tabs
            current_line_width += tab_size - current_line_width % tab_size;
            i += 1;
        } else {
            if byte != #char "\n" current_line_width += 1;  // don't count newlines towards the width to avoid wrapping them
            i += 1 + trailingBytesForUTF8[byte];
        }

        if current_line_width > max_width_in_chars {
            add(*editor.wrapped_line_starts, this_char_index);
            current_line_width = 1;
        } else if byte == #char "\n" {
            add(*editor.wrapped_line_starts, i);
            current_line_width = 0;
        }
    }

    add(*editor.wrapped_line_starts, cast(s32) buffer.bytes.count);  // last line
}

retokenize :: (buffer: *Buffer) {
    lock(*buffer.content_lock);
    defer unlock(*buffer.content_lock);

    assert(!buffer.dirty);
    buffer.needs_tokenizing = false;

    if buffer.lang == .Plain_Text {
        // We don't store tokens for plain text buffers
        reset(*buffer.tokens);
        for buffer.regions free(it.note);
        reset(*buffer.regions);
        return;
    }

    tokenize_func := get_tokenize_function(buffer.lang);

    // Resize tokens if we ever changed the token array
    if !is_empty(buffer.tokens) || tokenize_func != null then resize(*buffer.tokens, buffer.bytes.count, initialize = true);
    if !tokenize_func return;  // this could be the case for e.g. the build panel

    new_regions := tokenize_func(buffer);

    // Clear buffer regions
    for buffer.regions free(it.note);
    reset_keeping_memory(*buffer.regions);

    for * region : new_regions {
        // Add regions into buffer
        if region.note then region.note = copy_string(region.note);
        add(*buffer.regions, region.*);

        // Maybe tokenize heredocs
        if region.kind == .heredoc {
            tokenize_func := get_tokenize_function(region.lang);
            if tokenize_func != null then tokenize_func(buffer, region.start, region.end - region.start);  // ignore subregions here
        }
    }
}

buffer_needs_tokenizing :: (buffer: Buffer) -> bool {
    return
        (buffer.needs_tokenizing || buffer.tokens.count != buffer.bytes.count) &&
        (get_tokenize_function(buffer.lang) != null || buffer.tokens.count > 0);
}

tokenize_for_indentation :: (buffer: *Buffer) -> [] Indentation_Token /* temp */ {
    // NOTE: all tokenizers here must return temporary storage!
    if buffer.lang == {
        case .Jai;          return tokenize_jai_for_indentation(buffer);
        case .CSharp;       return tokenize_csharp_for_indentation(buffer);
        case .C;            return tokenize_c_like_lang_for_indentation(buffer, get_next_c_token);
        case .Cpp;          return tokenize_c_like_lang_for_indentation(buffer, get_next_cpp_token);
        case .Css;          return tokenize_c_like_lang_for_indentation(buffer, get_next_css_token);
        case .D;            return tokenize_c_like_lang_for_indentation(buffer, get_next_d_token);
        case .Js;           return tokenize_c_like_lang_for_indentation(buffer, get_next_js_token);
        case .Json;         return tokenize_c_like_lang_for_indentation(buffer, get_next_json_token);
        case .Glsl;         return tokenize_c_like_lang_for_indentation(buffer, get_next_glsl_token);
        case .Hlsl;         return tokenize_c_like_lang_for_indentation(buffer, get_next_hlsl_token);
        case .Zig;          return tokenize_c_like_lang_for_indentation(buffer, get_next_zig_token);
        case .Html;         return tokenize_xml_for_indentation(buffer);
        case .Xml;          return tokenize_xml_for_indentation(buffer);
        case .Lua;          return tokenize_lua_for_indentation(buffer);
        case .Odin;         return tokenize_odin_for_indentation(buffer);
        case .Rust;         return tokenize_rust_for_indentation(buffer);
        case .Batch;        return tokenize_batch_for_indentation(buffer);
    }

    return .[];
}

get_base_indent_from_line :: (buffer: Buffer, line_num: s32, tokens: [] Indentation_Token, tab_size: s32) -> level: int, next_level: int {
    line := get_real_line_as_string(buffer, line_num);
    if !line return 0, 0;

    col := 0;

    for byte, i : to_bytes(line) {
        if byte == #char " " {
            col += 1;
        } else if byte == #char "\t" {
            col += tab_size - col % tab_size;  // tabs are evil
        } else {
            advance(*line, i);
            break;
        }
    }

    base_level := (col + tab_size - 1) / tab_size;

    // Get the next level
    start := get_real_line_start_offset(buffer, line_num);
    end   := get_real_line_end_offset(buffer, line_num);
    _, next_delta := get_indentation_changes_from_tokens_within_range(tokens, start, end);

    return base_level, max(0, base_level + next_delta);
}

get_indentation_changes_from_tokens_within_range :: (tokens: [] Indentation_Token, start: s32, end: s32) -> current_delta: int, next_delta: int {
    current_delta := 0;
    next_delta    := 0;

    NUM_KINDS :: #run enum_highest_value(type_of(Indentation_Token.kind)) + 1;
    unclosed: [NUM_KINDS] int;
    seen_unopened := false;

    first_token, first_token_id := find_next_indentation_token(tokens, start, end);
    if first_token_id >= 0 && first_token.type == .close {
        // The first token in this range is a closing token, so we should unindent
        current_delta = -1;
    }
    if first_token_id < 0 then first_token_id = 0;

    for token : array_view(tokens, first_token_id, tokens.count - first_token_id) {
        if token.start < start continue;
        if token.start > end break;
        if token.type != .open && token.type != .close continue;

        if token.type == .open {
            unclosed[token.kind] += 1;
        } else {
            unclosed[token.kind] -= 1;
            if unclosed[token.kind] < 0 then { unclosed[token.kind] = 0; seen_unopened = true; }
        }
    }

    // If we end up with an unclosed token, we should indent
    for kind : unclosed { if kind > 0 { next_delta = max(next_delta + 1, 1); break; } }

    // If we end up with an opened token, we should indent next line, unless already indented current line
    if seen_unopened && current_delta == 0 && next_delta == 0 then next_delta = -1;

    return current_delta, next_delta;
}

find_closest_indentation_token :: (tokens: [] Indentation_Token, offset: s32) -> token: Indentation_Token, token_id: s64 {
    assert(tokens.count > 0, "No indentation tokens found. This is an error.");

    left  := 0;
    right := tokens.count;

    while (right - left) > 1 {
        middle := left + (right - left) / 2;
        if offset > tokens[middle].start {
            left = middle;
        } else {
            right = middle;
        }
    }

    return tokens[left], left;
}

find_next_indentation_token :: (tokens: [] Indentation_Token, offset: s32, limit: s32) -> token: Indentation_Token, token_id: s64 {
    // Finds the token which starts immediately after or on the offset
    _, start_token_id := find_closest_indentation_token(tokens, offset);

    for token, i : array_view(tokens, start_token_id, tokens.count - start_token_id) {
        if token.start < offset continue;
        if token.start > limit break;
        return token, start_token_id + i;
    }

    return .{}, -1;
}

is_bracket :: (using buffer: Buffer, pos: s32) -> bool, direction: int = 0 {
    if pos < 0 || pos >= bytes.count return false;

    if !tokens || tokens[pos] != .punctuation return false;

    if bytes[pos] == {
        case #char "{";  return true,  1;
        case #char "[";  return true,  1;
        case #char "(";  return true,  1;
        case #char "}";  return true, -1;
        case #char "]";  return true, -1;
        case #char ")";  return true, -1;
    }

    return false;
}

find_matching_bracket :: (using buffer: Buffer, pos: s32) -> index: s32 {
    valid, direction := is_bracket(buffer, pos);
    if !valid return -1;

    bracket := bytes[pos];
    matching_bracket := get_balancing_char(bracket, include_closing = true);

    balance := 0;
    if direction < 0 {
        for < i : pos .. 0 {
            if tokens[i] != .punctuation continue;

            byte := bytes[i];
            if byte == bracket {
                balance += 1;
            } else if byte == matching_bracket {
                balance -= 1;
                if balance == 0 return xx i;
            }
        }
    } else if direction > 0 {
        for i : pos .. bytes.count - 1 {
            if tokens[i] != .punctuation continue;

            byte := bytes[i];
            if byte == bracket {
                balance += 1;
            } else if byte == matching_bracket {
                balance -= 1;
                if balance == 0 return xx i;
            }
        }
    }

    return -1;
}

offset_is_within_multiline_token :: (tokens: [] Indentation_Token, offset: s32) -> bool {
    token := find_closest_indentation_token(tokens, offset);
    return token.type == .maybe_multiline && (token.start + token.len) >= offset;
}

save_buffer_to_file :: (buffer: *Buffer, buffer_id: s64, file_path: string) {
    // Two scenarios here:
    // 1. We're saving a new buffer to a file (in this case has_file=false)
    // 2. We're saving an existing buffer using "save as"

    if buffer.has_file && platform_path_equals(buffer.file.full_path, file_path) {
        log("Tried to 'save as' into the same file: %", file_path);
        save_buffer(buffer, buffer_id);
        return;
    }

    if !buffer.has_file && !buffer.readonly {
        // We're saving a new buffer into a file (and the path has been chosen already)
        buffer.has_file = true;
        buffer.file = get_file_info_from_full_path(file_path);
        buffer.lang = get_lang_from_path(file_path);
        buffer.needs_tokenizing = true;

        lock(*open_buffers_lock);
        {
            existing_buffer_id, found_existing := table_find(*buffers_table, file_path);
            if found_existing {
                assert(buffer_id != existing_buffer_id, "Buffer without a file was added to the buffer table. This is a bug.");
                // The user chose to save the buffer into an existing file. OK.
                // Mark the old buffer as deleted and use the new one
                removed := table_remove(*buffers_table, file_path);
                assert(removed, "For some reason table_remove failed. This is a very unexpected bug.");
                existing_buffer := *open_buffers[existing_buffer_id];
                existing_buffer.deleted  = true;
                existing_buffer.modified = false;
                existing_buffer.modified_on_disk = false;

                reroute_active_editor(existing_buffer_id, buffer_id);
            }

            table_add(*buffers_table, copy_string(file_path), buffer_id);
        }
        unlock(*open_buffers_lock);

        save_buffer(buffer, buffer_id);
    } else {
        // We're "saving as", in which case we want to create a new buffer and also keep the current buffer
        success := write_entire_file(file_path, to_string(buffer.bytes));
        if !success {
            buffer.error_when_saving = true;
            log_error("Couldn't write to file %", file_path);
            return;
        }
        refresh_buffer_from_disk_by_path(file_path);
        new_id, created := find_or_create_buffer(file_path);
        assert(!created, "Buffer is unexpectedly created when it was supposed to already exist");
        if new_id < 0 return;  // logged elsewhere

        reroute_active_editor(buffer_id, new_id);
        update_window_title(open_editors[editors.active].buffer_id);

        array_ordered_remove_by_value(*most_recent_buffers, new_id);
        array_insert_at(*most_recent_buffers, new_id, 0);
    }

    start_watching_file_if_not_already(file_path);
}

save_buffer :: (using buffer: *Buffer, buffer_id: s64) {
    if readonly return;

    assert(has_file, "Trying to save a buffer without an associated file. This is a bug.");

    if config.settings.strip_trailing_whitespace_on_save != .disabled {
        strip_trailing_whitespace(buffer, buffer_id, except_lines_with_cursor = config.settings.strip_trailing_whitespace_on_save == .except_lines_with_cursor);
    }
    if config.settings.insert_final_newline_on_save      then insert_final_newline(buffer);  // important to do it after stripping

    success := write_entire_file(file.full_path, to_string(bytes));
    if success {
        modified = false;
        modified_on_disk = false;
        deleted = false;

        meow_hash = calculate_hash(to_view(bytes));

        error_when_saving = false;
        crlf = false;
    } else {
        error_when_saving = true;
    }
    remember_last_mod_info(buffer);
    if editors.active >= 0 && editors.active < open_editors.count then update_window_title(open_editors[editors.active].buffer_id);

    // The config will attempt to refresh again on a file watcher message, but it should exit early because it will be unchanged.
    // We're doing it here because this way we always refresh right away, without waiting for a message to wake us up
    if is_our_config_file(buffer.file.full_path) refresh_config(buffer.file.full_path);
    if is_current_theme(buffer.file.full_path) refresh_current_theme();

    redraw_requested = true;
}

reroute_active_editor :: (old_buffer_id: s64, new_buffer_id: s64) {
    old_buffer := *open_buffers[old_buffer_id];
    new_buffer := *open_buffers[new_buffer_id];

    editor := *open_editors[editors.active];

    if editor.buffer_id == old_buffer_id {
        editor.buffer_id = new_buffer_id;
        editor.scroll_to_cursor = .yes;
        for * cursor : editor.cursors { put_cursor_in_valid_spot(cursor, new_buffer); }
        organise_cursors(editor);

        assert(old_buffer.num_editors_open >= 1, "Buffer doesn't have the right number of open editors. This is a bug");
        old_buffer.num_editors_open -= 1;
        new_buffer.num_editors_open += 1;
    }

}

delete_buffer_from_disk :: (using buffer: *Buffer) -> deleted: bool {
    if readonly  return false;
    if !has_file return false;

    file_path := buffer.file.full_path;

    success := file_delete(file_path);
    if !success then return false;

    deleted          = true;
    modified         = false;
    modified_on_disk = false;

    finder.need_to_refresh_results = true;
    open_file_dialog.should_refresh_entries = true;

    if file_is_watched(file_path) then stop_watching_file(file_path);
    return true;
}

strip_trailing_whitespace :: (using buffer: *Buffer, buffer_id: s64, except_lines_with_cursor := false) {
    auto_release_temp();

    tab_size := get_buffer_tab_size(buffer);

    // Get active cursor offsets if we're saving the active buffer
    // so that we can keep them where they are if the corresponding option is enabled
    active_cursors: [] s32;
    {
        editor, _ := get_active_editor_and_buffer();
        if editor && editor.buffer_id == buffer_id {
            active_cursors = NewArray(editor.cursors.count, s32,, allocator = temp);
            for * active_cursors  it.* = editor.cursors[it_index].pos;
        }
    }

    // Record a list of edits we need to make in order to strip the whitespace,
    // one edit per line. The reason for this is to leverage the edit notification system
    // to properly adjust cursors in other editors, including on undo/redo.
    delete_edits: [..] Offset_Range;
    delete_edits.allocator = temp;

    line_start := line_starts[0];
    for line_end : to_view(line_starts, 1, line_starts.count - 1) {
        line := string.{ count = line_end - line_start, data = bytes.data + line_start };
        if ends_with(line, cast(u8) #char "\n") then line.count -= 1;
        if line.count >= 1 {
            trim_after := trim_right(line).count;

            pos_of_rightmost_cursor_on_this_line := -1;
            if except_lines_with_cursor {
                // Keep cursors where they are
                c := active_cursors;
                for pos : c {
                    if pos < line_start {
                        // Don't check this cursor for subsequent lines
                        active_cursors.count -= 1;
                        active_cursors.data  += 1;
                    } else if pos < line_end {
                        pos_of_rightmost_cursor_on_this_line = pos - line_start;
                    } else {
                        break;  // no need to check any other cursors for this line
                    }
                }
                if pos_of_rightmost_cursor_on_this_line >= trim_after then trim_after = pos_of_rightmost_cursor_on_this_line;
            }
            if trim_after < line.count {
                array_add(*delete_edits, Offset_Range.{ xx (line_start + trim_after), xx (line_start + line.count) });
            }
        }

        line_start = line_end;
    }

    if !delete_edits return;  // nothing to do

    // Only remember and restore cursor positions in the active editor.
    // Any other editors will be handled by the edit notifications
    cursor_positions := remember_cursor_positions(buffer_id, in = .active_editor);

    // Apply the delete edits
    offset_difference: s32 = 0;
    for delete_edits {
        range := it;
        range.start -= offset_difference;
        range.end   -= offset_difference;
        delete_range(buffer, range);
        offset_difference += range.end - range.start;
    }

    restore_cursor_positions(buffer_id, cursor_positions);
    refresh_all_editors_for_buffer(buffer_id);
}

indentation_detect_from_buffer_contents :: (buffer: *Buffer) {
    result := detect_and_set_indentation(buffer);

    if #complete result == {
        case .success;
            if buffer.indentation.type == .tabs {
                add_success_message("Tabs detected for indentation\nTab size is set to % (based on config)", buffer.indentation.size, dismiss_in_seconds = 5);
            } else {
                add_success_message("Spaces detected for indentation\nIndentation width is set to %", buffer.indentation.size, dismiss_in_seconds = 5);
            }
            buffer.indentation.was_manually_set = true;

        case .not_enough_data;  add_user_warning("Not enough data to determine file indentation. Using defaults (%: %)", ifx buffer.indentation.type == .spaces then "Spaces" else "Tabs", buffer.indentation.size);
        case .error;            add_user_error("Could not determine file indentation");
    }
}

indentation_use_defaults_for_buffer :: (using buffer: *Buffer) {
    indentation.type = config.settings.indent_using;
    indentation.size = cast(u8) config.settings.tab_size;
    add_success_message("Using defaults (%: %) for this file", ifx indentation.type == .spaces then "Spaces" else "Tabs", indentation.size, dismiss_in_seconds = 5);
}

Replace_Edit :: struct { range: Offset_Range; new_string: string; }

indentation_convert_to_tabs_for_buffer :: (buffer: *Buffer, buffer_id: s64) {
    auto_release_temp();

    tab_size := get_buffer_tab_size(buffer);

    // Add an edit for each replaced line, to make sure cursors are adjusted properly everywhere
    replace_edits: [..] Replace_Edit;
    replace_edits.allocator = temp;

    for line : split(to_string(buffer.bytes), cast(u8) #char "\n") {
        indent, num_bytes := get_visual_indent_in_spaces(line, tab_size);
        if !indent continue;

        num_tabs_to_indent  := indent / tab_size;
        num_spaces_to_align := indent % tab_size;  // it's not always possible to get the same indentation without using spaces

        line_start := cast(s32) (line.data - buffer.bytes.data);
        array_add(*replace_edits, Replace_Edit.{
            range = .{ line_start , line_start + cast(s32) num_bytes },
            new_string = tprint("%1%2", get_tmp_tabs(num_tabs_to_indent), get_tmp_spaces(num_spaces_to_align)),
        });
    }

    // Apply the edits
    cursor_positions := remember_cursor_positions(buffer_id, in = .active_editor);

    offset_difference: s32 = 0;
    for edit : replace_edits {
        range := edit.range;
        range.start += offset_difference;
        range.end   += offset_difference;
        replace_range(buffer, range, edit.new_string);
        offset_difference += cast(s32) edit.new_string.count - (range.end - range.start);
    }

    restore_cursor_positions(buffer_id, cursor_positions);
    refresh_all_editors_for_buffer(buffer_id);

    buffer.indentation.type = .tabs;
    // Not setting the size because tabs use defaults unless explicitly set
}

indentation_convert_to_spaces_for_buffer :: (buffer: *Buffer, buffer_id: s64) {
    auto_release_temp();

    tab_size := get_buffer_tab_size(buffer);

    // Add an edit for each replaced line, to make sure cursors are adjusted properly everywhere
    replace_edits: [..] Replace_Edit;
    replace_edits.allocator = temp;

    for line : split(to_string(buffer.bytes), cast(u8) #char "\n") {
        indent, num_bytes := get_visual_indent_in_spaces(line, tab_size);
        if !indent continue;

        line_start := cast(s32) (line.data - buffer.bytes.data);
        array_add(*replace_edits, Replace_Edit.{
            range = .{ line_start , line_start + cast(s32) num_bytes },
            new_string = get_tmp_spaces(indent),
        });
    }

    // Apply the edits
    cursor_positions := remember_cursor_positions(buffer_id, in = .active_editor);

    offset_difference: s32 = 0;
    for edit : replace_edits {
        range := edit.range;
        range.start += offset_difference;
        range.end   += offset_difference;
        replace_range(buffer, range, edit.new_string);
        offset_difference += cast(s32) edit.new_string.count - (range.end - range.start);
    }

    restore_cursor_positions(buffer_id, cursor_positions);
    refresh_all_editors_for_buffer(buffer_id);

    buffer.indentation.type = .spaces;
    buffer.indentation.size = cast(u8) config.settings.tab_size;
}

insert_final_newline :: (using buffer: *Buffer) {
    if !bytes return;
    if bytes[bytes.count - 1] == #char "\n" return;  // already there

    new_insert_edit(buffer, bytes.count, "\n");

    lock(*content_lock);
    resize(*bytes, bytes.count + 1);
    bytes[bytes.count - 1] = cast(u8) #char "\n";
    unlock(*content_lock);

    rescan_for_lines(buffer);
}

remember_last_mod_info :: (using buffer: *Buffer) {
    assert(has_file, "Trying to remember last modtime and size of a buffer with no file. This is a bug");

    modtime_apollo, size, success := file_modtime_and_size(file.full_path);
    if success {
        // We don't care too much about precision here. We only care about last_modtime being different from the previous one if it changes
        mod_info.last_modtime = cast,trunc(s32) to_milliseconds(modtime_apollo);
        mod_info.last_size    = cast(s32) size;
    } else {
        log_error("Couldn't get modtime and size of file %\n", file.full_path);
    }
}

buffer_file_has_changed_on_disk :: (using buffer: *Buffer) -> changed: bool {
    assert(has_file);
    modtime_apollo, size, success := file_modtime_and_size(file.full_path);
    if !success {
        log_error("Couldn't get modtime and size of %\n", file.full_path);
        return true;  // consider changed
    }
    modtime := cast,trunc(s32) to_milliseconds(modtime_apollo);
    return modtime != mod_info.last_modtime || size != mod_info.last_size;
}

is_empty :: (using buffer: Buffer, line_num: s32) -> bool {
    s := get_real_line_as_string(buffer, line_num);
    return is_all_whitespace(s);
}

get_real_line_as_string :: (using buffer: Buffer, line_num: s32) -> string {
    assert(!buffer.dirty);
    return _get_line_as_string(buffer, to_view(buffer.line_starts), line_num);
}

get_line_as_string :: (editor: Editor, buffer: Buffer, line_num: s32) -> string {
    assert(!buffer.dirty);
    return _get_line_as_string(buffer, get_line_starts(editor, buffer), line_num);
}

_get_line_as_string :: (buffer: Buffer, line_starts: [] s32, line_num: s32) -> string {
    if line_num < 0 || line_num >= line_starts.count - 1 return "";

    start := line_starts[line_num];
    end   := line_starts[line_num + 1];

    result: string = ---;
    result.data  = buffer.bytes.data + start;
    result.count = end - start;

    return result;
}

find_or_create_an_empty_buffer :: () -> buffer_id: s64, created: bool {
    if workspace_scan_complete {
        // Return the first empty standalone buffer to avoid creating a million new buffers.
        // We have to only do this if the workspace scan is complete, otherwise we'll be in for
        // many surprising thread-related bugs
        for * buffer, buffer_id : open_buffers {
            if !buffer.has_file && !buffer.deleted && !buffer.readonly && !trim(to_string(buffer.bytes)) return buffer_id, false;
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
    retokenize(buffer);

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
    load_error := "";
    if !success {
        load_error = sprint("Couldn't load file '%'", path);
    } else if file_data.count > MAX_BUFFER_SIZE {
        load_error = sprint("Couldn't load file '%' because it exceeds the maximum buffer size of 2,147,483,647 bytes", path);
    } else if is_file_binary(file_data) {
        load_error = sprint("Couldn't display file '%' because it's either binary or contains non-UTF8 characters.", path);
        buffer.binary = true;
    }

    if load_error {
        free(file_data);
        file_data = load_error;
        buffer.readonly = true;
        buffer.lang = .Plain_Text;
    } else {
        buffer.lang = get_lang_from_path(path);
    }

    // Fill in buffer data
    buffer.file = get_file_info_from_full_path(path);
    buffer.has_file = true;
    remember_last_mod_info(buffer);

    lock(*buffer.content_lock);
    buffer.bytes = from_view(to_bytes(file_data));
    bytes_removed := remove_crlf_in_place(*buffer.bytes);
    unlock(*buffer.content_lock);

    buffer.crlf = bytes_removed > 0;
    buffer.meow_hash = calculate_hash(to_view(buffer.bytes));

    rescan_for_lines(buffer);
    retokenize(buffer);

    return buffer_id, true;
}

find_buffer_id_by_path :: (path: string) -> buffer_id: s64 {
    lock(*open_buffers_lock);
    defer unlock(*open_buffers_lock);

    buffer_id, found_buffer := table_find(*buffers_table, path);
    if found_buffer return buffer_id;

    return -1;
}

get_buffer_name :: (buffer: Buffer) -> string {
    // NOTE: After deleting using "Delete Current File", `has_file` could be false while buffer.file still exists (because we don't override it).
    //       So if we fail the `has_file` check, check the `file.full_path` as well to see if there is still a valid name that the buffer can draw.
    if buffer.has_file || buffer.file.full_path || buffer.readonly return buffer.file.name;

    tab_size := get_buffer_tab_size(buffer);

    for 0..buffer.line_starts.count-2 {
        line := trim(get_real_line_as_string(buffer, xx it), "\t \r\n");
        name := copy_temporary_string(line);
        replace_chars(name, "\t", xx #char " ");  // remove tabs from the middle
        if name return take_first_n_chars(name, min(50, name.count), tab_size);
    }

    return "<new file>";
}

get_buffer_indentation_and_tab_size :: inline (using buffer: Buffer) -> Indentation, tab_size: s32 {
    if indentation.size > 0 {
        return indentation.type, ifx indentation.type == .spaces then indentation.size else cast(s32) config.settings.tab_size;
    } else {
        return config.settings.indent_using, cast(s32) config.settings.tab_size;
    }
}

get_buffer_tab_size :: inline (using buffer: Buffer) -> s32 {
    if indentation.size > 0 {
        return ifx indentation.type == .spaces then indentation.size else cast(s32) config.settings.tab_size;
    } else {
        return cast(s32) config.settings.tab_size;
    }
}

maybe_detect_and_set_indentation :: (buffer_id: s64) {
    buffer := *open_buffers[buffer_id];
    if buffer.readonly || buffer.deleted || buffer.internal return;

    if config.settings.detect_indentation {
        // With this setting on all buffers need to attempt to detect indentation unless already set
        if buffer.indentation.size <= 0 && !buffer.indentation.was_manually_set then detect_and_set_indentation(buffer);
    } else {
        // With this setting off all buffers need to forget their indentation and use defaults, unless previously set manually
        if !buffer.indentation.was_manually_set then buffer.indentation.size = 0;
    }
}

detect_and_set_indentation :: (using buffer: *Buffer) -> enum { success; error; not_enough_data; } {
    if is_empty(bytes) {
        // Empty files get default indentation
        indentation.type = config.settings.indent_using;
        indentation.size = cast(u8) config.settings.tab_size;
        return .not_enough_data;
    }

    // Collect stats on line indentaion
    num_lines_with_spaces := 0;
    num_lines_with_tabs   := 0;

    MAX_INDENT :: 140;  // for the purpose of detecting indentation we don't look at lines indented more than this. Who would even do it?
    line_differences:          [MAX_INDENT] s32;  // the numbers of differences between lines with different indents

    last_indent     := 0;
    last_difference := 0;

    b    := bytes.data;
    last := bytes.data + bytes.count - 1;
    while b <= last {
        num_spaces := 0;
        num_tabs   := 0;
        while b <= last {
            if b.* == {
                case #char " ";     num_spaces += 1;
                case #char "\t";    num_tabs   += 1;
                case;               break;  // end of indentation
            }
            b += 1;
        }

        if num_spaces > 0 && num_tabs > 0 {
            // Mixed spaces and tabs on the same line, ignore
        } else if num_tabs {
            num_lines_with_tabs += 1;
        } else if num_spaces > 0 && num_spaces < MAX_INDENT {
            num_lines_with_spaces += 1;

            difference_from_prev_line := abs(last_indent - num_spaces);
            if difference_from_prev_line > 0 && difference_from_prev_line < MAX_INDENT {
                line_differences[difference_from_prev_line] += 1;
                last_difference = difference_from_prev_line;
            } else if difference_from_prev_line == 0 && last_difference > 0 {
                line_differences[last_difference] += 1;
                // This is to count lines like this:
                // int foo() {
                //     foobar();  // <- diff = 4, remember
                //     bazfoo();  // <- diff = 0, but count it towards the 4 still!
                //     ...
                //
            }
            last_indent = num_spaces;
        }

        // Skip the rest of the line
        while b <= last && b.* != #char "\n"  b += 1;
        b += 1;
    }

    if num_lines_with_tabs < 2 && num_lines_with_spaces < 2 {
        // Not enough information, use defaults
        indentation.type = config.settings.indent_using;
        indentation.size = cast(u8) config.settings.tab_size;
        return .not_enough_data;
    }

    if num_lines_with_tabs > num_lines_with_spaces {
        // Assuming tabs
        indentation.type = .tabs;
        indentation.size = cast(u8) config.settings.tab_size;
        return .success;
    }

    // Assuming spaces
    indentation.type = .spaces;
    indentation.size = cast(u8) config.settings.tab_size;  // fallback

    // Find the most common line difference
    max_lines := 0;
    for num_lines, difference : line_differences {
        if num_lines > max_lines {
            indentation.size = cast(u8) difference;
            max_lines = num_lines;
        }
    }

    if indentation.size > 0 && indentation.size < MAX_INDENT {
        return .success;
    } else {
        return .error;  // shouldn't happen
    }
}

refresh_buffer_from_disk_by_path :: (path: string) {
    is_dir, is_dir_success := is_directory(path);
    if is_dir || !is_dir_success || !file_exists(path) {
        // Either this is a dir, or a deleted dir, or a deleted file.
        // So many checks are needed because if a dir gets deleted then
        // it will get to this point and could get itself a buffer
        // if we didn't do it.

        // Find if there's an existing buffer already and mark it as deleted
        lock(*open_buffers_lock);
        buffer_id, found_buffer := table_find(*buffers_table, path);
        if found_buffer {
            open_buffers[buffer_id].deleted = true;
            finder.need_to_refresh_results = true;
            open_file_dialog.should_refresh_entries = true;
        }
        unlock(*open_buffers_lock);

        return;
    }

    if is_our_config_file(path) refresh_config(path);
    if is_current_theme(path)   refresh_current_theme();

    buffer_id, created := find_or_create_buffer(path);
    if created return;
    if buffer_id < 0 {
        log_error("Couldn't open file because path is too long for Windows: %\n", path);
        return;
    }

    buffer := *open_buffers[buffer_id];

    // If we got to this point, the file definitely exists. Mark it as not deleted.
    // This will "undelete" previously deleted files, which is helpful when e.g. a user
    // switches branches in version control
    buffer.deleted = false;
    open_file_dialog.should_refresh_entries = true;

    if !buffer_file_has_changed_on_disk(buffer) return;

    finder.need_to_refresh_results = true;

    // Buffer may have changed on disk - reload and compare hashes to be sure
    assert(platform_path_equals(path, buffer.file.full_path));

    // Reload buffer from disk
    file_contents_str, success := read_entire_file(path);
    if is_file_binary(file_contents_str) {
        free(file_contents_str);
        file_contents_str = sprint("Couldn't display file '%' because it's either binary or contains non-UTF8 characters.", path);
        buffer.readonly = true;
    }

    if !success { log_error("Couldn't read file '%'\n", path); return; }
    defer free(file_contents_str);

    lock(*buffer.content_lock);
    bytes_removed := remove_crlf_in_place(*file_contents_str);
    unlock(*buffer.content_lock);

    file_hash := calculate_hash(cast([] u8) file_contents_str);
    if buffer.meow_hash == file_hash  return;  // file hasn't actually changed

    buffer.crlf = bytes_removed > 0;
    buffer.meow_hash = file_hash;
    buffer.deleted = false;

    if buffer.modified {
        // Mark conflict
        // TODO: display a dialog prompting to reload
        buffer.modified_on_disk = true;
    } else {
        remember_last_mod_info(buffer);

        cursor_positions := remember_cursor_positions(buffer_id, in = .all_editors);

        replace_range(buffer, .{ 0, buffer.bytes.count }, file_contents_str);

        restore_cursor_positions(buffer_id, cursor_positions);
    }

    refresh_all_editors_for_buffer(buffer_id);
}

reload_from_disk :: (buffer_id: s64) {
    // The difference between this function and `refresh_buffer_from_disk_by_path` is that
    // this function is invoked by user and it will force reload and will produce user messages,
    // whereas the other one is automatic and is silent

    buffer := *open_buffers[buffer_id];
    if !buffer.has_file || !buffer.file.full_path {
        add_user_warning("Buffer has no associated file", dismiss_in_seconds = 5);
        return;
    }
    path := buffer.file.full_path;

    // Force reload buffer from disk, even if unchanged, and clear the flags
    file_contents_str, success := read_entire_file(path);
    if is_file_binary(file_contents_str) {
        free(file_contents_str);
        file_contents_str = sprint("Couldn't display file '%' because it's either binary or contains non-UTF8 characters.", path);
        buffer.readonly = true;
    }

    if !success { add_user_error("Couldn't read file:\n%", path); return; }
    defer free(file_contents_str);

    bytes_removed := remove_crlf_in_place(*file_contents_str);

    buffer.crlf = bytes_removed > 0;
    buffer.meow_hash = calculate_hash(cast([] u8) file_contents_str);
    buffer.deleted = false;
    buffer.modified = false;  // if the user had unsaved changes and needs them again, undo should help

    remember_last_mod_info(buffer);

    cursor_positions := remember_cursor_positions(buffer_id, in = .all_editors);

    replace_range(buffer, .{ 0, buffer.bytes.count }, file_contents_str);

    restore_cursor_positions(buffer_id, cursor_positions);

    refresh_all_editors_for_buffer(buffer_id);

    add_success_message("File contents has been reloaded from\n%", path);

    finder.need_to_refresh_results = true;
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
    open_file_dialog.should_refresh_entries = true;
}

free_buffer :: (using buffer: *Buffer) {
    // We don't do it often so it's ok to be slow here
    free(bytes);
    free(line_starts);
    free(tokens);

    for * undos deinit(it);
    for * redos deinit(it);
    free(undos);
    free(redos);
    free(edits);
    free(cursors);

    if has_file && file.full_path then free(file.full_path);

    free_buffer_extra(extra);
    extra = null;
}

free_buffer_extra :: (extra: *Buffer.Extra) {
    if !extra return;
    if #complete extra.type == {
        case .focus_config;
            config_extra := cast(*Focus_Config_Extra) extra;
            array_free(config_extra.parsed_colors);
    }
    free(extra);
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

init_buffer :: (using buffer: *Buffer) {
    init(*content_lock);

    // These values will be overwritten later if `detect_intentation` is true
    indentation.type = config.settings.indent_using;
    indentation.size = 0;
}

get_unsaved_buffer_ids :: () -> [] s64 /* temp */ {
    result: [..] s64;
    result.allocator = temp;

    for buffer, buffer_id : open_buffers {
        if is_unsaved(buffer) array_add(*result, buffer_id);
    }

    return result;
}

unsaved_buffers_exist :: () -> bool {
    // Linear search, hmmmm, that sounds slow.
    // Perhaps we should create an unsaved buffers microservice,
    // which would tell us if they exist in a O(1) time?
    for open_buffers {
        if is_unsaved(it) return true;
    }
    return false;
}

is_unsaved :: (buffer: Buffer) -> bool {
    return buffer.modified && !buffer.readonly && !buffer.internal;
}

remove_all_buffers :: () {
    array_reset_keeping_memory(*most_recent_buffers);
    deinit(*buffers_table);
    for * open_buffers free_buffer(it);
    bucket_array_reset(*open_buffers);
}

manually_mark_range_as_token :: (buffer: *Buffer, range: Offset_Range, color: Color) {
    assert(range.start >= 0 && range.end <= buffer.bytes.count);
    resize(*buffer.tokens, buffer.bytes.count);
    memset(buffer.tokens.data + range.start, xx color, range.end - range.start);
}

get_tokenize_function :: (lang: Buffer.Lang) -> Tokenize_Function {
    if #complete lang == {
        case .Jai;                  return tokenize_jai;
        case .C;                    return tokenize_c;
        case .Cpp;                  return tokenize_cpp;
        case .Css;                  return tokenize_css;
        case .CSharp;               return tokenize_csharp;
        case .D;                    return tokenize_d;
        case .Glsl;                 return tokenize_glsl;
        case .Hlsl;                 return tokenize_hlsl;
        case .Golang;               return tokenize_golang;
        case .Js;                   return tokenize_js;
        case .Json;                 return tokenize_json;
        case .Lua;                  return tokenize_lua;
        case .Odin;                 return tokenize_odin;
        case .Python;               return tokenize_python;
        case .RenPy;                return tokenize_renpy;
        case .Rust;                 return tokenize_rust;
        case .Html;                 return tokenize_xml;
        case .Xml;                  return tokenize_xml;
        case .Todo;                 return tokenize_todo;
        case .Yang;                 return tokenize_yang;
        case .Zig;                  return tokenize_zig;
        case .Uxntal;               return tokenize_uxntal;
        case .Markdown;             return tokenize_markdown;
        case .Batch;                return tokenize_batch;
        case .Focus_Config;         return tokenize_focus_config;
        case .Focus_Theme;          return tokenize_focus_config;
        case .Focus_Build_Panel;    return null;
        case .Plain_Text;           return null;
    }
}

get_supported_buffer_langs_lowercase :: () -> [] string /* intended to be run at compile time */ {
    lang_names: [..] string;
    for enum_names(Buffer.Lang) {
        if equal_nocase(it, "focus_build_panel") continue;  // filter out "internal" languages
        array_add(*lang_names, to_lower_copy_new(it));
    }
    quick_sort(lang_names, compare_strings);
    return lang_names;
}

#scope_file

Tokenize_Function :: #type (buffer: *Buffer, start_offset: s64 = -1, count: s64 = -1) -> [] Buffer_Region /* temp */;

add_edit_notification :: (using buffer: *Buffer, offset: s64, old_count: s64, new_count: s64) {
    if num_editors_open < 2 return;
    editor_id := context.current_editor_id;
    if editor_id < 0 return;
    editor := *open_editors[editor_id];
    if buffer != *open_buffers[editor.buffer_id] {
        log_error("Attempting to send an edit notification from a mismatching editor. Editor id: %, buffer id: %\n", editor_id, editor.buffer_id);
        return;
    }

    add(*buffer_edit_notifications, Buffer.Edit_Notification.{
        buffer_id = cast(s32) editor.buffer_id,
        editor_id = cast(s32) editor_id,
        offset    = cast(s32) (offset + min(old_count, new_count)),
        delta     = cast(s32) (new_count - old_count),
    });
}

new_replace_edit :: (buffer: *Buffer, start: s32, end: s32, old_str: string, new_str: string) {
    edit := add(*buffer.edits);
    edit.type = .replace;
    using edit.replace;
    offset_range.start = start;
    offset_range.end   = end;
    new_bytes = copy_string(new_str);
    old_bytes = copy_string(old_str);

    clear_redos(buffer);
}

new_insert_edit :: (buffer: *Buffer, offset: s32, str: string) {
    edit := add(*buffer.edits);
    edit.type = .insert;
    edit.insert.offset = offset;
    edit.insert.new_bytes = copy_string(str);

    clear_redos(buffer);
}

new_insert_char_edit :: (buffer: *Buffer, offset: s32, char: Utf8_Char) {
    edit := add(*buffer.edits);
    edit.type = .insert_char;
    edit.insert_char.offset = offset;
    edit.insert_char.char = char;

    clear_redos(buffer);
}

new_delete_edit :: (buffer: *Buffer, start: s32, end: s32, old_str: string) {
    edit := add(*buffer.edits);
    edit.type = .delete;
    using edit.delete;
    offset_range.start = start;
    offset_range.end   = end;
    old_bytes = copy_string(old_str);

    clear_redos(buffer);
}

clear_redos :: (using buffer: *Buffer) {
    for * redos  deinit(it);
    reset_keeping_memory(*redos);
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
    array_free(cursors_before);
    array_free(cursors_after);
}

#scope_export

buffer_edit_notifications: Array(Buffer.Edit_Notification);


Buffer :: struct {
    bytes:       Array(u8);
    line_starts: Array(s32);       // real offsets of newlines in the bytes array
    tokens:      Array(Token_Type);     // we assign a token to each byte (even for multi-byte chars).
    regions:     Array(Buffer_Region); // for highlighting parts of buffer

    // @Memory: all of these are allocated on the heap, which is not great, but it works fine right now.
    // Eventually we'll want to revisit all this and make it not allocate as much.
    undos: Array(Edit_Group);
    redos: Array(Edit_Group);
    edits: Array(Edit);  // current edits, not in a group yet

    cursors: Array(Cursor);  // cursor state before any current edits were made

    content_lock: Mutex;  // must hold while modifying content (or reading in a non-main thread)

    file: File_Info;

    meow_hash: u64;
    last_edit_time: float64;  // for creating new edit groups

    mod_info: Mod_Info;  // for detecting whether a file has changed

    // TODO: put into enum_flags
    has_file               := false;  // a buffer might not have a corresponding file
    dirty                  := false;
    was_dirty_during_frame := false;
    modified               := false;
    modified_on_disk       := false;
    deleted                := false;
    internal               := false;  // e.g. build panel, default config etc.
    needs_tokenizing       := false;
    readonly               := false;
    binary                 := false;
    error_when_saving      := false;
    crlf                   := false;

    lang: Lang = .Plain_Text;

    indentation: struct {
        type: Indentation = .spaces;
        size: u8 = 0;  // 0 means not initted, use global config values
        was_manually_set := false;
    }

    num_times_opened: u8;
    num_editors_open: u8;

    // A pointer to arbitrary buffer information.
    // Would be nice to be able to avoid using it if another way of attaching info to buffers is better. We'll see what the use patterns are.
    extra: *Extra = null;

    Extra :: struct {
        type: Extra_Type;
        // ...
    }
    Extra_Type :: enum { focus_config; }

    Mod_Info :: struct {
        last_modtime: s32;  // Apollo_Time converted to milliseconds
        last_size:    s32;
    }

    Edit_Group :: struct {
        edits: [] Edit;
        cursors_before: [] Cursor;  // have to remember where the cursors were both before and after
        cursors_after:  [] Cursor;  // because otherwise the redo behaviour can't be properly implemented
    }

    // All strings in this struct are owned
    Edit :: struct {
        type: enum { insert; insert_char; replace; delete; };
        union {
            insert: struct {
                offset: s32;
                new_bytes: string;
            };
            insert_char: struct {
                offset: s32;
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
        buffer_id: s32;
        editor_id: s32;
        offset:    s32;
        delta:     s32;
    }

    Lang :: enum u8 {
        Plain_Text :: 0;
        Jai;
        C;
        Cpp;
        Css;
        CSharp;
        D;
        Glsl;
        Hlsl;
        Golang;
        Js;
        Json;
        Lua;
        Odin;
        Python;
        RenPy;
        Rust;
        Xml;
        Html;
        Todo;
        Yang;
        Zig;
        Uxntal;
        Markdown;
        Batch;
        Focus_Config;
        Focus_Theme;
        Focus_Build_Panel;  // a fake lang to be assigned to the build panel instead of Plain_Text so that its tokens are preserved
    };
}

Focus_Config_Extra :: struct {
    using #as base: Buffer.Extra;
    base.type = .focus_config;

    parsed_colors: [] Parsed_Color;
    colors_section_start := -1;
    colors_section_end   := -1;
}

Cursor :: struct {
    pos: s32;
    sel: s32;
    col_wanted: s32 = -1;
}

#assert size_of(Cursor) == (2 + 1) * size_of(s32);  // make sure no padding accidentally gets added

Cursor_Coords :: struct {
    pos, sel: Coords;
}

Coords :: struct {
    line, col: s32;
}

Offset_Range :: struct {
    start, end: s32;
}

Buffer_Region :: struct {
    using range: Offset_Range;
    note: string;
    kind: Kind;
    lang: Buffer.Lang;

    Kind :: enum u8 {
        none :: 0;
        error;
        warning;
        success;
        header;

        scope_export;
        scope_file;
        scope_module;

        heredoc;
    }
}

Coords_Range :: struct {
    start, end: Coords;
}

Indentation_Token :: struct {
    start: s32;
    len:   s32;

    type: enum u16 {
        // non-indentation
        unimportant;
        maybe_multiline;
        eof;

        // indentation
        open;
        close;
    };

    kind: enum u16 {
        // only makes sense for indentation types
        paren;
        bracket;
        brace;
    };
}

MAX_BUFFER_SIZE :: S32_MAX;
