tokenize_plain_text :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        memset(tokens.data + token.start, xx token.type, token.len);
    }

    return .[];
}

#scope_file

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type = .eof;
    if t >= max_t return token;

    start_t = t;

    t += 1;
    eat_until_newline(tokenizer);

    token.type = .default;
    token.len = cast(s32) (t - start_t);

    return token;
}

Token :: struct {
    start, len: s32;
    type: Token_Type;
}