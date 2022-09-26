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

decode_utf8_string_to_temp_chars :: (str: string) -> [] u32 {
    chars: [..] u32;
    chars.allocator = temp;
    array_reserve(*chars, str.count);  // should be enough to store chars with some buffer

    s := str;
    while true {
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

// Slices the string using char indices, not byte indices
slice_chars :: (str: string, pos1: s32, pos2: s32) -> string {
    assert(pos1 >= 0 && pos2 >= 0, "Incorrect indices for string slicing");
    if pos2 <= pos1 || !str return "";

    offset1 := -1;
    offset2 := -1;
    byte_offset := 0;
    char_index  := 0;

    while byte_offset < str.count {
        byte := str.data[byte_offset];
        // @speed: could be done with one `if` per iteration
        if pos1 == char_index then offset1 = byte_offset;
        byte_offset += 1 + trailingBytesForUTF8[byte];
        char_index += 1;
        if pos2 == char_index {
            offset2 = byte_offset;
            break;  // found everything
        }
    }
    assert(offset1 >= 0 && offset2 >= 0, "Char indices are outside the string, can't slice");

    return slice(str, offset1, offset2 - offset1);
}
