tokenize_ini :: (buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_ini_tokenizer(buffer, start_offset, count);
    while tokenizer.s_it < tokenizer.s_end {
        range := eat_line_white_space(*tokenizer);
        if highlight_range(*tokenizer, *range, .default) continue;

        if tokenizer.s_it.* == {
            case C_SQB_OPEN; highlight_section_header(*tokenizer);
            case C_COMMENT;  highlight_comment(*tokenizer);
            case;            highlight_kv_pair(*tokenizer);
        }
    }

    regions: [..] Buffer_Region;
    return regions;
}

#scope_file

C_NL        :: #char "\n";
C_EQUAL     :: #char "=";
C_COMMENT   :: #char ";";
C_DQUOTE    :: #char "\"";
C_SQUOTE    :: #char "'";
C_SQB_OPEN  :: #char "[";
C_SQB_CLOSE :: #char "]";

Ini_Tokenizer :: struct {
    s_start: *u8;
    s_end: *u8;
    s_it: *u8;

    t_start: *Token_Type;
    t_end: *Token_Type;
    t_it: *Token_Type;
}

Ini_Range :: struct {
    text: []u8;
    type: []Token_Type;
}

get_ini_tokenizer :: (buffer: *Buffer, start_offset := -1, count := -1) -> Ini_Tokenizer {
    ret: Ini_Tokenizer;

    idx_start := 0;
    idx_count := xx buffer.bytes.count;
    if start_offset >= 0 {
        idx_start = xx clamp(start_offset, 0, buffer.bytes.count - 1);
        idx_count = xx clamp(count, 0, buffer.bytes.count - idx_start);
    }
    idx_end := idx_start + idx_count;

    ret.s_start = buffer.bytes.data + idx_start;
    ret.s_end   = buffer.bytes.data + idx_end;
    ret.s_it    = ret.s_start;

    ret.t_start = buffer.tokens.data + idx_start;
    ret.t_end   = buffer.tokens.data + idx_end;
    ret.t_it    = ret.t_start;

    return ret;
}

advance :: (tokenizer: *Ini_Tokenizer) #expand {
    tokenizer.s_it += 1;
    tokenizer.t_it += 1;
}

seek_to_end_of_range :: (tokenizer: *Ini_Tokenizer, range: *Ini_Range) #expand {
    if range.text.count {
        assert(range.text.count == range.type.count);
        tokenizer.s_it = range.text.data + range.text.count;
        tokenizer.t_it = range.type.data + range.type.count;
    }
}

get_range :: (tokenizer: *Ini_Tokenizer) -> Ini_Range #expand {
    ret: Ini_Range = .{
        text = .{data = tokenizer.s_it, count = 0},
        type = .{data = tokenizer.t_it, count = 0},
    };
    return ret;
}

extend :: (range: *Ini_Range, by := 1) #expand {
    range.text.count += by;
    range.type.count += by;
}

highlight_range :: inline (tokenizer: *Ini_Tokenizer, range: *Ini_Range, type: Token_Type) -> bool {
    if range.type.count {
        assert(range.text.count == range.type.count);
        assert(range.text.data - tokenizer.s_start == range.type.data - tokenizer.t_start);

        memset(range.type.data, xx type, range.type.count);
        return true;
    }
    return false;
}

highlight_comment :: (tokenizer: *Ini_Tokenizer) {
    range := eat_comment(tokenizer);
    highlight_range(tokenizer, *range, .comment);
}

highlight_section_header :: (tokenizer: *Ini_Tokenizer) {
    r_header, r_dangling, r_comment := eat_section_header(tokenizer);
    highlight_range(tokenizer, *r_header,   .keyword);
    highlight_range(tokenizer, *r_dangling, .error);
    highlight_range(tokenizer, *r_comment,  .comment);
}

highlight_kv_pair :: (tokenizer: *Ini_Tokenizer) {
    line := get_current_line(tokenizer);
    k_range, eq_range, ok := split_kv(*line);
    if ok {
        highlight_range(tokenizer, *k_range,  .function);
        highlight_range(tokenizer, *eq_range, .punctuation);
        seek_to_end_of_range(tokenizer, *eq_range);
        highlight_value(tokenizer);
    } else {
        highlight_range(tokenizer, *line, .error);
        seek_to_end_of_range(tokenizer, *line);
    }
}

highlight_value :: (tokenizer: *Ini_Tokenizer) {
    v_range := get_range(tokenizer);

    while tokenizer.s_it < tokenizer.s_end {
        if tokenizer.s_it.* == {
            case C_COMMENT; {
                highlight_range(tokenizer, *v_range, .value);
                highlight_comment(tokenizer);
                return;
            }

            case C_SQUOTE; #through;
            case C_DQUOTE; {
                highlight_range(tokenizer, *v_range, .value);
                s_range, s_type := eat_string_literal(tokenizer);
                highlight_range(tokenizer, *s_range, s_type);
                v_range = get_range(tokenizer);
            }

            case; {
                prev := tokenizer.s_it;
                extend(*v_range);
                advance(tokenizer);
                if prev.* == C_NL break;
            }
        }
    }

    highlight_range(tokenizer, *v_range, .value);
}

get_current_line :: (tokenizer: *Ini_Tokenizer) -> Ini_Range {
    ret := get_range(tokenizer);

    while tokenizer.s_it < tokenizer.s_end {
        prev := tokenizer.s_it;

        extend(*ret);
        advance(tokenizer);

        if prev.* == C_NL break;
    }

    return ret;
}

eat_line_white_space :: (tokenizer: *Ini_Tokenizer) -> Ini_Range {
    ret := get_range(tokenizer);

    old_s_it := tokenizer.s_it;
    while (tokenizer.s_it < tokenizer.s_end) && is_white_space(tokenizer.s_it.*) {
        prev := tokenizer.s_it;
        advance(tokenizer);
        if prev.* == C_NL break;
    }

    extend(*ret, tokenizer.s_it - ret.text.data);
    return ret;
}

eat_comment :: (tokenizer: *Ini_Tokenizer) -> Ini_Range {
    ret := get_range(tokenizer);

    assert(tokenizer.s_it.* == C_COMMENT);

    while (tokenizer.s_it < tokenizer.s_end) && (tokenizer.s_it.* != C_NL) {
        advance(tokenizer);
    }

    extend(*ret, tokenizer.s_it - ret.text.data);
    return ret;
}

eat_section_header :: (tokenizer: *Ini_Tokenizer) -> header: Ini_Range, dangling: Ini_Range, comment: Ini_Range {
    header := get_range(tokenizer);

    assert(tokenizer.s_it.* == C_SQB_OPEN);

    found := false;
    while tokenizer.s_it < tokenizer.s_end {
        prev := tokenizer.s_it;

        advance(tokenizer);

        if prev.* == {
            case C_NL; break;
            case C_SQB_CLOSE; {
                found = true;
                break;
            }
        }
    }
    extend(*header, tokenizer.s_it - header.text.data);

    if !found return .{}, header, .{};

    dangling := get_range(tokenizer);
    while tokenizer.s_it < tokenizer.s_end {
        if tokenizer.s_it.* == {
            case C_NL; {
                advance(tokenizer);
                break;
            }

            case C_COMMENT; {
                comment := eat_comment(tokenizer);
                return header, dangling, comment;
            }

            case; {
                prev := tokenizer.s_it;
                advance(tokenizer);
                extend(*dangling);
            }
        }
    }

    return header, dangling, .{};
}

eat_string_literal :: (tokenizer: *Ini_Tokenizer) -> s_range: Ini_Range, type: Token_Type {
    s_range := get_range(tokenizer);
    q_char := tokenizer.s_it.*;

    assert(q_char == C_SQUOTE || q_char == C_DQUOTE);

    advance(tokenizer);
    extend(*s_range);
    while tokenizer.s_it < tokenizer.s_end {
        prev := tokenizer.s_it;
        extend(*s_range);
        advance(tokenizer);
        if prev.* == q_char return s_range, .string_literal;
    }

    return s_range, .error;
}

split_kv :: (line: *Ini_Range) -> k_range: Ini_Range, eq_range: Ini_Range, success: bool {
    s_start := line.text.data;
    s_end   := line.text.data + line.text.count;
    s_it    := line.text.data;

    found := false;
    while s_it < s_end {
        if s_it.* == C_EQUAL {
            found = true;
            break;
        }
        s_it += 1;
    }
    if !found return .{}, .{}, false;

    s_count := s_it - s_start;

    k_range := Ini_Range.{
        text = .{data = line.text.data, count = s_count},
        type = .{data = line.type.data, count = s_count},
    };
    eq_range := Ini_Range.{
        text = .{data = k_range.text.data + k_range.text.count, count = 1},
        type = .{data = k_range.type.data + k_range.type.count, count = 1},
    };

    return k_range, eq_range, true;
}
