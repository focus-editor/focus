highlight_focus_config_syntax :: (using buffer: *Buffer) {
    tokenizer: Tokenizer = ---;
    tokenizer.buf   = to_string(bytes);
    tokenizer.max_t = bytes.data + bytes.count;
    tokenizer.t     = bytes.data;

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        color := COLOR_MAP[token.type];
        memset(colors.data + token.start, xx color, token.len);
    }
}

#scope_file

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;

    // Look at the first char as if it's ASCII (if it isn't, this is just a text line)
    char := << t;
    
    if char == {
        case #char "["; parse_header (tokenizer, *token);
        case #char "#"; parse_comment(tokenizer, *token);
        case;           parse_line(tokenizer, *token);
    }
    
    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    
    if token.type == .header {
        // Detect top-level headers
        token_str: string = ---;
        token_str.data  = buf.data + token.start;
        token_str.count = token.len;
        if begins_with(token_str, "[[") && ends_with(token_str, "]]") {
            token.type = .header_top_level;
        }
    }
    
    return token;
}

parse_header :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .header;
    
    seen_brackets := 1;
    t += 1;
    while t < max_t && <<t != #char "\n" && seen_brackets > 0 {
        char := << t;
        if char == #char "[" then seen_brackets += 1;
        if char == #char "]" then seen_brackets -= 1;
        t += 1;
    }
}

parse_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .comment;
    
    t += 1;
    eat_until_newline(tokenizer);
}

parse_line :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .line;
    
    t += 1;
    eat_until_newline_or_comment(tokenizer);
}

eat_until_newline :: (using tokenizer: *Tokenizer) {
    while t < max_t && <<t != #char "\n" {
        t += 1;
    }
}

eat_until_newline_or_comment :: (using tokenizer: *Tokenizer) {
    while t < max_t && <<t != #char "#" && <<t != #char "\n" { 
        t += 1;
    }
}

eat_white_space :: (using tokenizer: *Tokenizer) {
    while t < max_t && is_space(<< t) {
        t += 1;
    }
}

Tokenizer :: struct {
    buf: string;
    max_t:   *u8;
    start_t: *u8;  // cursor when starting parsing new token
    t:       *u8;  // cursor
    
    section: enum {
        Project;
        Keymap;
        Colors;
    };
}

Token :: struct {
    start, len: s32;
    type: Type;

    Type :: enum u16 {
        eof;

        comment;
        line;
        header;
        header_top_level;
    }
}

// Must match the order of the types in the enum above
COLOR_MAP :: Simp.Code_Color.[
    .COMMENT,       // eof - obviously not used
    
    .COMMENT,       // comment
    .DEFAULT,       // line
    .FUNCTION,      // header
    .KEYWORD,       // header_top_level
];
