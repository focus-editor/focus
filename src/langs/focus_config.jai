highlight_focus_config_syntax :: (using buffer: *Buffer) {
    memset(colors.data, xx COLOR_MAP[Focus_Config_Token.comment], colors.count);

    push_allocator(temp);  // we don't care about anything it might allocate

    name := get_buffer_name(buffer);
    result := parse_config(name, name, cast(string) bytes, for_highlighting = true, as_theme = lang == .Focus_Theme);

    for result.highlights {
        memset(colors.data + it.offset, xx COLOR_MAP[it.color_num], it.count);
    }
}

Focus_Config_Token :: enum u16 {
    error;
    warning;
    default;
    comment;
    header;
    header_top_level;

    // Keymap
    modifier_key;
    key_string;
    action;

    // Settings
    value;
}

#scope_file

// Must match the order of the types in the token enum
COLOR_MAP :: Color.[
    .CODE_ERROR,          // error
    .CODE_WARNING,        // warning
    .CODE_DEFAULT,        // default
    .CODE_COMMENT,        // comment
    .CODE_OPERATION,      // header
    .CODE_KEYWORD,        // header_top_level

    .CODE_VALUE,          // modifier_key
    .CODE_DEFAULT,        // key_string
    .CODE_DEFAULT,        // action

    .CODE_VALUE,          // value
];

#run assert(enum_highest_value(Focus_Config_Token) == COLOR_MAP.count - 1);