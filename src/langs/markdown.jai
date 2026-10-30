// This has been contributed by a user,
// however it's still incomplete and should be simplified when we get to it

tokenize_markdown ::  (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_markdown_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        highlight_token(buffer, token);
    }

    return .[];
}

#scope_file
get_markdown_tokenizer :: (using buffer: *Buffer, start_offset := -1, count := -1) -> Markdown_Tokenizer {
    tokenizer: Markdown_Tokenizer;

    tokenizer.buf   = to_string(bytes);
    tokenizer.max_t = bytes.data + bytes.count;
    tokenizer.t     = bytes.data;
    tokenizer.found_new_line   = true;
    tokenizer.found_whitespace = true;

    if start_offset >= 0 {
        start_offset = clamp(start_offset, 0, bytes.count - 1);
        count        = clamp(count,        0, bytes.count - 1);
        tokenizer.t += start_offset;
        tokenizer.max_t = tokenizer.t + count;
    }

    return tokenizer;
}

get_next_token :: (using tokenizer: *Markdown_Tokenizer) -> Token {
    // Eat white space and look fo new line.
    while t < max_t && is_white_space(t.*) {
        found_whitespace = true;
        if t.* == #char "\n" found_new_line = true;
        t += 1;
    }

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type = .eof;
    if t >= max_t return token;

    start_t = t;
    char := t.*;
        
    is_alternate_heading := parse_for_alternate_heading(tokenizer, *token);
    
    if !is_alternate_heading && !found_new_line && maybe_do_task_list {
        parse_task_list(tokenizer, *token);
    } else if !is_alternate_heading {
        did_not_find_char := false; 
        if char == {
            case #char "`"; parse_backtick(tokenizer, *token);
            case #char "~"; parse_tilde(tokenizer, *token);
            case #char "*"; parse_for_horizontal_rule_and_more(tokenizer, *token, char);

            case #char "["; parse_square_bracket(tokenizer, *token);
            case #char "!"; parse_exclamation_mark(tokenizer, *token);
            case #char "<"; parse_less_than(tokenizer, *token);
            case #char "\\"; token.type = .default; t += 2;
            case;
                did_not_find_char = true;
                if !found_whitespace {
                    token.type = .default; 
                    t += 1;
                }
        }
        
        // Only after any whitespace.
        if did_not_find_char && found_whitespace {
            if char == {
                case #char "h"; parse_link(tokenizer, *token);
                case #char "@"; parse_at(tokenizer, *token);
                case #char "_"; parse_for_horizontal_rule_and_more(tokenizer, *token, char);
                case;
                    if !found_new_line {
                        token.type = .default; 
                        t += 1;
                    }
                
                // Only after a new line.
                if found_new_line {
                    if is_digit(char) {
                        parse_number(tokenizer, *token);
                    } else if char == {
                        case #char "#"; parse_hash(tokenizer, *token);
                        case #char ">"; parse_greater_than(tokenizer, *token);
                        case #char "-"; parse_for_horizontal_rule_and_more(tokenizer, *token, char);
                        case #char "+"; parse_bullet_point(tokenizer, *token);
                        case; token.type = .default; t += 1;
                    }
                }
            }
        }
    }

    found_new_line   = false;
    found_whitespace = false;

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

parse_for_alternate_heading :: (using tokenizer: *Markdown_Tokenizer, token: *Token) -> bool {
    old_t := t;
    
    while t < max_t {
        if t.* == #char "\n" {
            t += 1;
            break;
        }
        t += 1;
    }
    
    eat_white_space(tokenizer, only_until_newline = true);
    
    is_double := check_repeated_chars(#char "=" , 2, tokenizer) || check_repeated_chars(#char "-" , 2, tokenizer);
    
    if is_double {
        token.type = .type;
        while t < max_t {
            if t.* == #char "\n" {
                break;
            }
            
            t += 1;
        }
        
        return true;
    }
    
    t = old_t;
    return false; 
}

parse_at :: (using tokenizer: *Markdown_Tokenizer, token: *Token) {
    token.type = .string_literal;
    while t < max_t && !is_white_space(t.*) {
        t += 1;
    }

}

parse_number :: (using tokenizer: *Markdown_Tokenizer, token: *Token) {
    while is_digit(t.*) {
        t += 1;
        if t >= max_t return;
    }

    next_t := t + 1;
    if t.* == #char "." && next_t < max_t && is_white_space(next_t.*) {
        token.type = .keyword;
        t += 1;
        maybe_do_task_list = true;
    } else {
        token.type = .default;
    }
}

parse_hash :: (using tokenizer: *Markdown_Tokenizer, token: *Token) {
    token.type = .type;
    t += 1;

    while t < max_t && t.* != #char "\n" {
        // When encountering a link we highlight it because that is often done in README's on Github to reference a section in the README.
        if t.* == #char "[" return;
        next_t := t +1;
        if next_t < max_t && t.* == #char "!" && next_t.* == #char "[" return;

        t += 1;
    }
}

parse_greater_than :: (using tokenizer: *Markdown_Tokenizer, token: *Token) {
    identifier_str := read_identifier_string_tmp(tokenizer, stop_at_char = #char "\n", stop_at_white_space = false);

    found_alert := false;
    end_of_next_line := false;
    for alerts {
        if begins_with(identifier_str, it.opening_tag) {
            token.type = it.type;
            found_alert = true;

            while t < max_t && is_white_space(t.*) {
                if t.* == #char "\n" end_of_next_line = true;
                t += 1;
            }

            if t.* == #char ">" && !end_of_next_line {
                while t < max_t {
                    if t.* == #char "\n" {
                        break;
                    }

                    t += 1;
                }
            }
        }
    }

    if !found_alert {
        token.type = .operation;
        t = start_t + 1;
    }
}

parse_for_horizontal_rule_and_more :: (using tokenizer: *Markdown_Tokenizer, token: *Token, char: u8) {
    is_triple := check_repeated_chars(char, 3, tokenizer);
    
    parsed_horizontal_rule := false; 
    if found_new_line && is_triple {

        next_t := t + 3;
        while next_t < max_t {
            is_white_space_except_newline :=  (is_white_space(next_t.*) && next_t.* != #char "\n");
            if is_white_space_except_newline || next_t.* == char {
                next_t += 1;
                continue;
            } else if next_t.* == #char "\n" {
                t = next_t;
                parsed_horizontal_rule = true;
                break;
            } else {
                break;
            }
        }
    } 
    
    if parsed_horizontal_rule {
        token.type = .modifier;
    } else if char == #char "*" {
        is_bullet_point := parse_bullet_point(tokenizer, token);
        
        if !is_bullet_point {
            t -= 1;
            parse_for_style(tokenizer, token, char);
        }
    } else if char == #char "_" {
        parse_for_style(tokenizer, token, char);
    } else if char == #char "-" {
        parse_bullet_point(tokenizer, token);
    }
}

parse_bullet_point :: (using tokenizer: *Markdown_Tokenizer, token: *Token) -> bool {
    next_t := t + 1;
    if next_t < max_t && is_white_space(next_t.*) {
        token.type = .keyword;

        maybe_do_task_list = true;
        t += 1;
        return true;
    } 
    
    token.type = .default;
    t += 1;
    return false;
}

parse_for_style :: (using tokenizer: *Markdown_Tokenizer, token: *Token, char: u8) {
    // Bold, italic and bold+italic.
    token.type = .operation;

    is_triple := highlight_for_repeated_chars(char, 3, tokenizer, token);

    is_double := true;
    if !is_triple {
        is_double = highlight_for_repeated_chars(char, 2, tokenizer, token);
    }

    if !is_double {
        highlight_for_repeated_chars(char, 1, tokenizer, token);
    }
}

parse_tilde :: (using tokenizer: *Markdown_Tokenizer, token: *Token) {
    next_t := t + 1;
    if next_t < max_t && next_t.* == #char "~" {
        token.type = .operation;
        highlight_for_repeated_chars(#char "~", 2, tokenizer, token);
    } else {
        token.type = .default;
        t += 1;
    }
}

parse_backtick :: (using tokenizer: *Markdown_Tokenizer, token: *Token) {
    token.type = .function;

    // ```Code Block```
    is_triple := highlight_for_repeated_chars(#char "`", 3, tokenizer, token, stop_at_new_paragraph = false);

    // `Code line`
    if !is_triple highlight_for_repeated_chars(#char "`", 1, tokenizer, token);
}

parse_task_list :: (using tokenizer: *Markdown_Tokenizer, token: *Token) {
    auto_release_temp();

    token.type = .default;
    maybe_do_task_list = false;

    previous_t := t;
    identifier_str := read_identifier_string_tmp(tokenizer, stop_at_char = #char "\n", stop_at_white_space = false);

    if      begins_with(identifier_str, "[X]") || begins_with(identifier_str, "[x]") token.type = .type;
    else if begins_with(identifier_str, "[ ]") token.type = .keyword;
    else { t = start_t; return; }

    t = previous_t + 3;
}

parse_square_bracket :: (using tokenizer: *Markdown_Tokenizer, token: *Token) {
    token.type = .number;
    old_t := t;

    t += 1;
    number_of_opening_brackets_to_stop := 1;
    while t < max_t {
        if t.* == #char "\n" {
            t = old_t + 1;
            token.type = .default;
            return;
        } else if t.* == #char "]" {
            number_of_opening_brackets_to_stop -= 1;
        } else if t.* == #char "[" {
            number_of_opening_brackets_to_stop += 1;
        }

        if number_of_opening_brackets_to_stop == 0 {
            t += 1;
            break;
        }

        t += 1;
    }

    eat_white_space(tokenizer, only_until_newline = true);

    if t.* == #char "(" {
        t += 1;
        while t < max_t {
            if t.* == #char ")" {
                t += 1;
                break;
            } else if t.* == "\n" {
                break;
            }

            t += 1;
        }
    }
}

parse_exclamation_mark :: (using tokenizer: *Markdown_Tokenizer, token: *Token) {
    next_t := t + 1;
    if next_t < max_t && next_t.* == #char "[" {
        token.type = .number;
        t += 1;
        parse_square_bracket(tokenizer, token);
    } else {
        token.type = .default;
        t += 1;
    }

}

parse_link :: (using tokenizer: *Markdown_Tokenizer, token: *Token) {
    auto_release_temp();

    identifier_str := read_identifier_string_tmp(tokenizer);

    if begins_with(identifier_str, "https://") || begins_with(identifier_str, "http://") {
        token.type = .number;
    } else {
        token.type = .default;
    }
}

parse_less_than :: (using tokenizer: *Markdown_Tokenizer, token: *Token) {
    auto_release_temp();

    found_tag := false;
    identifier_str := read_identifier_string_tmp(tokenizer);
    closing_tag: string;

    for tags {
       if begins_with(identifier_str, it.opening_tag) {
            token.type = it.type;
            t = start_t + it.opening_tag.count;
            closing_tag = it.closing_tag;
            found_tag = true;
            break;
        }
    }

    if found_tag {
        while t < max_t {
            identifier_str = read_identifier_string_tmp(tokenizer, stop_at_char = #char ">");
            if ends_with(identifier_str, closing_tag) return;
        }
    } else token.type = .default;

}

check_repeated_chars :: (char: u8, repeats: s64, using tokenizer: *Markdown_Tokenizer) -> bool {
    if t + repeats > max_t return false;

    next_t: *u8;
    for i:0..repeats-1 {
        next_t = t+i;
        if next_t < max_t && next_t.* != char return false;
    }
    
    return true;
}

parse_for_repeated_chars_on_new_line :: (char: u8, repeats: s64, using tokenizer: *Markdown_Tokenizer) -> bool {
    found_chars := check_repeated_chars(char, repeats, tokenizer);
    
    next_t := t + repeats;
    if found_chars {
        while next_t < max_t {
            if is_white_space(next_t.*) && next_t.* != #char "\n" {
                next_t += 1;
                continue;
            } else if next_t.* == #char "\n" {
                t = next_t;
                return true;
            } else {
                return false;
            }
        }
    }
    
    return false;
}

highlight_for_repeated_chars :: (char: u8, repeats: s64, using tokenizer: *Markdown_Tokenizer, token: *Token, stop_at_new_paragraph := true) -> bool {
    is_repeated := check_repeated_chars(char, repeats, tokenizer);
    if !is_repeated return false;

    t += repeats;
    old_t := t;

    while t < max_t {
        if t.* == #char "\\" {
            t += 2;
            continue;
        }

        if check_repeated_chars(char, repeats, tokenizer) {
            t += repeats;
            return true;
        }

        if stop_at_new_paragraph {
            is_new_paragraph := skip_white_space_and_look_for_next_paragraph(tokenizer);

            if is_new_paragraph {
                break;
            }
        }

        t += 1;
    }
    
    t = old_t;
    token.type = .default;

    return false;
}

read_identifier_string_tmp :: (using tokenizer: *Markdown_Tokenizer, stop_at_char := #char " ", stop_at_white_space := true) -> string /* temp */ {
    identifier: [..] u8;
    identifier.allocator = temp;

    array_add(*identifier, t.*);
    t += 1;
    while t < max_t {
        c := t.*;
        if c == stop_at_char                          { t += 1; array_add(*identifier, c); break; }
        if !stop_at_white_space || !is_white_space(c) { t += 1; array_add(*identifier, c); continue; }
        break;
    }

    if t >= max_t then t = max_t;
    return cast(string) identifier;
}

skip_white_space_and_look_for_next_paragraph :: (using tokenizer: *Markdown_Tokenizer) -> found_new_para: bool {
    original_t := t;
    number_of_new_lines := 0;
    while t < max_t {
        if !is_white_space(t.*) break;
        if t.* == #char "\n" number_of_new_lines += 1;
        if number_of_new_lines >= 2 return true;
        t += 1;
    }
    
    t = original_t;
    return false;
}

Markdown_Tokenizer :: struct {
    using #as base: Tokenizer;
    found_new_line: bool;
    found_whitespace:    bool;
    maybe_do_task_list:  bool;
}

Token :: struct {
    using #as base: Base_Token;
}

Tag :: struct {
    opening_tag: string;
    closing_tag: string;
    type: Token_Type;
}

tags, alerts :: #run,stallable -> [] Tag, [] Tag {
    tags: [..] Tag;
    array_add(*tags, .{"<sub>", "</sub>", .number});
    array_add(*tags, .{"<sup>", "</sup>", .number});
    array_add(*tags, .{"<ins>", "</ins>", .number});
    array_add(*tags, .{"<!--",  "-->",    .comment});

    alerts: [..] Tag;
    array_add(*alerts, .{"> [!NOTE]", "\n", .highlight});
    array_add(*alerts, .{"> [!TIP]", "\n", .type});
    array_add(*alerts, .{"> [!IMPORTANT]", "\n", .number});
    array_add(*alerts, .{"> [!WARNING]", "\n", .operation});
    array_add(*alerts, .{"> [!CAUTION]", "\n", .modifier});
    return tags, alerts;
};