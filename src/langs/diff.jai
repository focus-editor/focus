tokenize_diff :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer: Diff_Tokenizer;
    tokenizer.base = get_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        memset(tokens.data + token.start, xx token.type, token.len);
    }

    if tokenizer.current_region_id >= 0 then end_region(*tokenizer, tokenizer.t - tokenizer.buf.data);
    quick_sort(tokenizer.regions, (a, b) => (a.start - b.start));
    return tokenizer.regions;
}

#scope_file

get_next_token :: (using tokenizer: *Diff_Tokenizer) -> Token {
    token := Token.{
        start = cast(s32) (t - buf.data),
        type  = .eof,
    };

    if t >= max_t return token;

    start_t = t;
    char := t.*;

    if char == {
        case #char "+"; parse_plus     (tokenizer, *token);
        case #char "-"; parse_minus    (tokenizer, *token);
        case #char "@"; parse_range    (tokenizer, *token);
        case #char " "; parse_unchanged(tokenizer, *token);
        case;           parse_metadata (tokenizer, *token);
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

parse_plus :: (using tokenizer: *Diff_Tokenizer, token: *Token) {
    token.type = .addition;

    t += 1;
    if t >= max_t then return;

    current := t.*;
    next    := (t + 1).*;
    if current == #char "+" && next == #char "+" {
        eat_until_newline(tokenizer);
        t += 1;
    }
    else {
        if current_region_id == -1 || regions[current_region_id].kind != .addition {
            start_region(tokenizer, token.start, .addition);
        }
        eat_until_newline(tokenizer);
        t += 1;
    }

    if t > max_t then t = max_t;
}

parse_minus :: (using tokenizer: *Diff_Tokenizer, token: *Token) {
    token.type = .deletion;

    t += 1;
    if t >= max_t then return;

    current := t.*;
    next    := (t + 1).*;
    if current == #char "-" && next == #char "-" {
        eat_until_newline(tokenizer);
        t += 1;
    }
    else {
        if current_region_id == -1 || regions[current_region_id].kind != .deletion {
            start_region(tokenizer, token.start, .deletion);
        }
        eat_until_newline(tokenizer);
        t += 1;
    }

    if t > max_t then t = max_t;
}

parse_range :: (using tokenizer: *Diff_Tokenizer, token: *Token) {
    t += 1;
    if t >= max_t || t.* != #char "@" {
        parse_metadata(tokenizer, token);
        return;
    }

    token.type = .number;
    if current_region_id != -1 then end_region(tokenizer, token.start);
    eat_until_newline(tokenizer);
    t += 1;
}

parse_unchanged :: (using tokenizer: *Diff_Tokenizer, token: *Token) {
    token.type = .identifier;
    if current_region_id != -1 then end_region(tokenizer, token.start);
    eat_until_newline(tokenizer);
    t += 1;
}

parse_metadata :: (using tokenizer: *Diff_Tokenizer, token: *Token) {
    token.type = .string_literal;
    if current_region_id != -1 then end_region(tokenizer, token.start);
    eat_until_newline(tokenizer);
    t += 1;
}

start_region :: (using tokenizer: *Diff_Tokenizer, offset: s64, kind: Buffer_Region.Kind) {
    if current_region_id >= 0 then end_region(tokenizer, offset);
    current_region_id = regions.count;

    region := Buffer_Region.{
        start = xx offset,
        end   = -1,
        kind  = kind,
    };
    array_add(*regions, region);
}

end_region :: inline (using tokenizer: *Diff_Tokenizer, offset: s64) {
    regions[current_region_id].end = xx offset;
    current_region_id = -1;
}

Diff_Tokenizer :: struct {
    using #as base: Tokenizer;

    regions: [..] Buffer_Region;
    regions.allocator = temp;
    current_region_id := -1;
}

Token :: struct {
    start, len: s32;
    type: Token_Type;
}

