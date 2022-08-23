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
