tokenize_todo :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        highlight_token(buffer, token);
    }

    return .[];
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
    token.type = .function;  // not great, but we want to avoid language-specific tokens here

    t += 1;
    eat_until_newline(tokenizer);
}

parse_todo_line :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .default;

    t += 1;
    eat_until_newline(tokenizer);
}

parse_current_task_line :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .value;

    t += 1;
    eat_until_newline(tokenizer);
}

parse_header :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .header1;

    t += 1;
    eat_until_newline(tokenizer);
}

parse_line :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .default;

    t += 1;
    eat_until_newline(tokenizer);
}

Token :: struct {
    using #as base: Base_Token;
}
