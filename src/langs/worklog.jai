highlight_worklog :: (using buffer: *Buffer) {
    tokenizer := get_tokenizer(buffer);

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
        case #char "+";  parse_done_line        (tokenizer, *token);
        case #char "-";  parse_todo_line        (tokenizer, *token);
        case #char "*";  parse_current_task_line(tokenizer, *token);
        case #char "#";  parse_header           (tokenizer, *token);
        case;            parse_line             (tokenizer, *token);
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

    t += 1;
    eat_until_newline(tokenizer);
}

parse_current_task_line :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .current_task;

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

Token :: struct {
    start, len: s32;
    type: Type;

    Type :: enum u16 {
        eof;

        line;
        done;
        todo;
        header;
        current_task;
    }
}

// Must match the order of the types in the enum above
COLOR_MAP :: Color.[
    .CODE_COMMENT,       // eof - obviously not used
    .CODE_DEFAULT,       // line
    .CODE_FUNCTION,      // done
    .CODE_DEFAULT,       // todo
    .CODE_KEYWORD,       // header
    .CODE_VALUE,         // current_task
];
