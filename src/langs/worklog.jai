highlight_worklog :: (using buffer: *NewBuffer) {
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
        case #char "+";  parse_done_line(tokenizer, *token);
        case #char "-";  parse_todo_line(tokenizer, *token);
        case #char "#";  parse_header   (tokenizer, *token);
        case;            parse_line     (tokenizer, *token);
    }
    
    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

parse_done_line :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .done;
    
    t += 1;
    eat_until_newline(tokenizer);
}

parse_todo_line :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .todo;
    
    // TODO: parse marks such as [bug], [tech-debt] etc.
    
    t += 1;
    eat_until_newline(tokenizer);
}

parse_header :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .header;
    
    t += 1;
    eat_until_newline(tokenizer);
}

parse_line :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .line;
    
    t += 1;
    eat_until_newline(tokenizer);
}

eat_until_newline :: (using tokenizer: *Tokenizer) {
    while t < max_t && <<t != #char "\n" {
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
}

Token :: struct {
    start, len: s32;
    type: Type;

    Type :: enum u16 {
        eof;

        line;
        done;
        todo;
        header;
    }
}

// Must match the order of the types in the enum above
COLOR_MAP :: Code_Color.[
    .COMMENT,       // eof - obviously not used
    
    .DEFAULT,       // line
    .FUNCTION,      // done
    .DEFAULT,       // todo
    .KEYWORD,       // header
];
