array_insert_bytes_at :: (array: *[..] u8, offset: s64, bytes: [] u8) {
    assert(offset >= 0 && offset <= array.count);
    if !bytes return;

    new_size := array.count + bytes.count;
    array_reserve(array, new_size);

    // Copy in chunks of str.count while possible
    source := array.count - bytes.count;
    dest   := array.count;
    while source >= offset {
        memcpy(array.data + dest, array.data + source, bytes.count);
        source -= bytes.count;
        dest   -= bytes.count;
    }
    // If there's a leftover, copy it as well
    if source != offset {
        memcpy(array.data + offset + bytes.count, array.data + offset, bytes.count - (offset - source));
    }
    // Insert the string
    memcpy(array.data + offset, bytes.data, bytes.count);

    array.count = new_size;
}

array_add_bytes :: (array: *[..] u8, bytes: [] u8) {
    if bytes.count <= 0 return;

    new_size := array.count + bytes.count;
    array_reserve(array, new_size);

    memcpy(array.data + array.count, bytes.data, bytes.count);

    array.count = new_size;
}

array_delete_bytes :: (array: *[..] u8, offset: s64, count: s64) {
    assert(offset >= 0 && count >= 0 && offset + count <= array.count);
    memcpy(array.data + offset, array.data + offset + count, array.count - offset - count);
    array.count -= count;
}

to_bytes :: (src: string) -> [] u8 {
    result: [] u8;
    result.data = src.data;
    result.count = src.count;
    return result;
}

decode_utf8_string_to_temp_chars :: (str: string, max_char: s64) -> [] u32 {
    chars: [..] u32;
    chars.allocator = temp;
    array_reserve(*chars, str.count);  // should be enough to store chars with some buffer

    s := str;
    for 0 .. max_char {
        char, result := utf8_next_character(*s);
        assert(result != .SOURCE_ILLEGAL);
        array_add(*chars, char);
        if result == .SOURCE_EXHAUSTED break;
    }

    return chars;
}

maybe_free_and_clear :: (str: *string) {
    if !str.data || str.count == 0 return;
    free(<< str);
    str.data  = null;
    str.count = 0;
}

to_owned_array :: (array: *[..]$T, free_memory := false) -> []T {
    new_array := array_copy(<<array);
    if free_memory {
        array_reset(array);
    } else {
        array_reset_keeping_memory(array);
    }
    return new_array;
}

array_extend :: (array: *[..] $T, slice: [] T) {
    if slice.count <= 0 return;

    new_size := array.count + slice.count;
    array_reserve(array, new_size);

    memcpy(array.data + array.count, slice.data, slice.count * size_of(T));

    array.count = new_size;
}

pos_to_offset :: (str: string, pos: s64) -> s64 {
    assert(pos >= 0, "Negative char position\n");
    result := -1;
    char_index  := 0;
    offset := 0;

    while offset < str.count {
        if pos == char_index {
            result = offset;
            break;
        }
        byte := str.data[offset];
        offset += 1 + trailingBytesForUTF8[byte];
        char_index += 1;
    }
    if pos == char_index then result = offset;
    assert(result >= 0, "Char position outside string\n");

    return result;
}

// Slices the string using char indices, not byte indices
slice_chars :: (str: string, pos1: s32, pos2: s32) -> string {
    if pos2 <= pos1 || !str return "";

    offset1 := pos_to_offset(str, pos1);
    remaining_str := slice(str, offset1, str.count - offset1);
    offset2 := offset1 + pos_to_offset(remaining_str, pos2 - pos1);

    return slice(str, offset1, offset2 - offset1);
}

get_absolute_path :: (path: string) -> string {  // returns a temporary string
    full_path: string = ---;
    if is_absolute_path(path) {
        full_path = copy_temporary_string(path);
    } else {
        full_path = join(get_working_directory(), path, separator = "/");
    }
    path_overwrite_separators(full_path, #char "/");
    return full_path;
}

// @Speed: this is even slower than the standard find_index_from_left
// NOTE: this function assumes that the substring contains only word chars,
// otherwise it doesn't make sense to call it
find_index_from_left_whole_word :: (s: string, substring: string, start_index := 0) -> s64 {
    if !substring return -1;

    for i : start_index .. s.count - substring.count {
        t := slice(s, i, substring.count);
        if t == substring {
            // Check the char on the right
            right := slice(s, i + substring.count, 4);
            next_char, success := utf8_next_character(*right);
            if success == .CONVERSION_OK && is_word_char(next_char) continue;  // not a whole word

            // Check the char on the left
            for j : max(i-2, start_index) .. i-1  {
                // We check the last 2 bytes and try to get a valid utf8 character in 2 attempts.
                // @limitation: this will not match utf8 sequences longer than 2 bytes, but our current
                // word chars are maximum 2 bytes long.
                left := slice(s, j, i - j);
                char, byte_len, result := character_utf8_to_utf32(left.data, left.count);
                if result == .CONVERSION_OK && byte_len == left.count && is_word_char(char) continue i;  // not a whole word
            }

            return i;
        }
    }

    return -1;
}

is_word_char :: (ch: u32) -> bool {
    return
        (#char "a" <= ch && ch <= #char "z") ||
        (#char "A" <= ch && ch <= #char "Z") ||
        (#char "0" <= ch && ch <= #char "9") ||
        (#char "а" <= ch && ch <= #char "я") ||
        (#char "А" <= ch && ch <= #char "Я") ||
        (ch == #char "_");
}

is_all_whitespace :: (s: string) -> bool {
    for byte : to_bytes(s) {
        // Multi-byte whitespace is not included
        if byte != #char " " && byte != #char "\t" && byte != #char "\n" then return false;
    }
    return true;
}

start_animation :: (anim: *Tween_Animation(T), start: $T, target: T, speed: Time = xx 0.1) {
    anim.start  = start;
    anim.target = target;
    anim.speed  = speed;
    anim.started_at = frame_time;
}

get_animation_value :: (using anim: Tween_Animation($T)) -> T {
    t := (frame_time - started_at) / speed;
    if t >= 1 || t < 0 {
        return target;
    } else {
        return start + cast(T) (cast(float)(target - start) * cast(float)t);
    }
}


#scope_export

Tween_Animation :: struct(T: Type) {
    start, target: T;
    started_at: Time;
    speed: Time;  // how many seconds to finish
    // NOTE: currently only uses lerp, but should be easy to add other functions later if needed
}
