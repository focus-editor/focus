tokenize_focus_config :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    memset(tokens.data, xx Token_Type.comment, tokens.count);

    push_allocator(temp);  // we don't care about anything it might allocate

    name := get_buffer_name(buffer);
    result := parse_config(name, name, cast(string) bytes, for_highlighting = true, as_theme = lang == .Focus_Theme);

    for result.highlights {
        memset(tokens.data + it.offset, xx it.token_type, it.count);
    }

    return .[];
}
