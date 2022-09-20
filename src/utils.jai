array_insert_bytes_at :: (array: *[..] u8, offset: s64, bytes: [] u8) {
    assert(offset >= 0 && offset <= array.count);

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
