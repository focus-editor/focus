highlight_focus_config_syntax :: (using buffer: *Buffer) {
    memset(colors.data, xx COLOR_MAP[Focus_Config_Token.comment], colors.count);

    push_allocator(temp);  // we don't care about anything it might allocate

    name := get_buffer_name(buffer);
    result := parse_config(name, name, cast(string) bytes, for_highlighting = true);

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
COLOR_MAP :: Code_Color.[
    .ERROR,          // error
    .WARNING,        // warning
    .DEFAULT,        // default
    .COMMENT,        // comment
    .OPERATION,      // header
    .KEYWORD,        // header_top_level

    .VALUE_KEYWORD,  // modifier_key
    .DEFAULT,        // key_string
    .DEFAULT,        // action

    .VALUE_KEYWORD,  // value
];

#run assert(enum_highest_value(Focus_Config_Token) == COLOR_MAP.count - 1);