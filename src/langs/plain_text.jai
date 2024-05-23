tokenize_plain_text :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    array_resize(*tokens, bytes.count);

    for * tokens { << it = .default; }

    return .[];
}