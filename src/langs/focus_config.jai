tokenize_focus_config :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    memset(tokens.data, xx Token_Type.comment, tokens.count);

    // Allocate some extra memory for metadata if not already
    assert(context.allocator.proc == focus_allocator.proc);
    if !extra {
        extra = New(Focus_Config_Extra);
    } else if extra.type != .focus_config {
        free_buffer_extra(extra);
        extra = New(Focus_Config_Extra);
    }

    push_allocator(temp);  // we don't care about anything else it might allocate

    name := get_buffer_name(buffer);
    file_path := ifx has_file then file.full_path else "";
    result := parse_config(name, file_path, to_string(bytes), for_highlighting = true, as_theme = lang == .Focus_Theme);

    for result.highlights {
        memset(tokens.data + it.offset, xx it.token_type, it.count);
    }

    // Remember things about this config
    config_extra := cast(*Focus_Config_Extra) extra;
    config_extra.colors_section_start = result.config.offsets.colors_section_start;
    config_extra.colors_section_end   = result.config.offsets.colors_section_end;
    array_resize(*config_extra.parsed_colors, result.config.colors.count,, allocator = focus_allocator);
    focus_memcpy(config_extra.parsed_colors.data, result.config.colors.data, result.config.colors.count * size_of(Parsed_Color));

    return .[];
}

