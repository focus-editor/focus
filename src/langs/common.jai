get_tokenizer :: (using buffer: Buffer) -> Tokenizer {
    tokenizer: Tokenizer;

    tokenizer.buf   = cast(string) bytes;
    tokenizer.max_t = bytes.data + bytes.count;
    tokenizer.t     = bytes.data;

    return tokenizer;
}

read_identifier_string :: (using tokenizer: *Tokenizer) -> string {
    identifier: string;
    identifier.data = t;

    while t < max_t && is_alnum(t.*) {
        t += 1;
    }
    if t >= max_t then t = max_t;
    identifier.count = t - identifier.data;

    return identifier;
}

eat_until_newline :: (using tokenizer: *Tokenizer) {
    while t < max_t && t.* != #char "\n" {
        t += 1;
    }
}

eat_white_space :: (using tokenizer: *Tokenizer) {
    while t < max_t && is_white_space(t.*) {
        t += 1;
    }
}

is_hex :: inline (c: u8) -> bool {
    return is_digit(c) || (c >= #char "a" && c <= #char "f") || (c >= #char "A" && c <= #char "F");
}

is_white_space :: inline (char : u8) -> bool #no_aoc {
    result : u32 = ---;

    // Should be in register, not immediate
    white_spaces : u64 = (#char " "  <<  0)  // space.
                       | (#char "\t" <<  8)  // horizontal tab.
                       | (#char "\n" << 16)  // line feed.
                       | (#char "\r" << 24)  // carriage return.
                       | (0x0C       << 32)  // form feed.    "\f" is not supported in jai at the time of writing
                       | (0x0B       << 40); // vertical tab. "\v" is not supported in jai at the time of writing

    #asm {
        chars  : vec === 0;
        mask   : vec === 1;
        spaces : vec === 2;
        result       === a;
        white_spaces === b;
        char         === c;

        movq spaces, white_spaces;

        pxor mask, mask;

        // Fill chars with c
        pinsrb chars, char, 0;
        pshufb chars, mask;

        pcmpeqb chars, spaces;

        pmovmskb result, chars;
    }

    return cast,no_check(bool) result;
}

tokenize_c_like_lang_for_indentation :: (using buffer: Buffer, $get_next_token: (*Tokenizer) -> $Token) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_tokenizer(buffer);

    while true {
        src := get_next_token(*tokenizer);

        token: Indentation_Token = ---;
        token.start = src.start;
        token.len   = src.len;

        if src.type == {
            case .punctuation;
                if src.punctuation == {
                    case .l_paren;      token.type = .open;  token.kind = .paren;
                    case .l_bracket;    token.type = .open;  token.kind = .bracket;
                    case .l_brace;      token.type = .open;  token.kind = .brace;

                    case .r_paren;      token.type = .close; token.kind = .paren;
                    case .r_bracket;    token.type = .close; token.kind = .bracket;
                    case .r_brace;      token.type = .close; token.kind = .brace;

                    case;               continue;
                }

            case .multiline_comment;    token.type = .maybe_multiline;
            case .eof;                  token.type = .eof;  // to guarantee we always have indentation tokens
            case;                       token.type = .unimportant;
        }

        array_add(*tokens, token);

        if src.type == .eof break;
    }

    return tokens;
}

Tokenizer :: struct {
    buf: string;
    max_t:   *u8;
    start_t: *u8;  // cursor when we're about to parse a new token
    t:       *u8;  // cursor
}

Code_Highlight :: struct {
    offset: s32;
    count: s32;
    color_num: u8;
}
