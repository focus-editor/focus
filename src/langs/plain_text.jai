tokenize_plain_text :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    array_reset_keeping_memory(*tokens);

    return .[];
}