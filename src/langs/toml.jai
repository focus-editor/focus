tokenize_toml :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_toml_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        highlight_token(buffer, token);
    }

    return .[];
}

#scope_file

Token :: Base_Token;

Toml_Tokenizer :: struct {
    using #as base: Tokenizer;

    seen_equals   := false;
    bracket_count := 0;
    brace_count   := 0;
}

get_toml_tokenizer :: (buffer: *Buffer, start_offset := -1, count := -1) -> Toml_Tokenizer {
    tokenizer: Toml_Tokenizer;
    tokenizer.base = get_tokenizer(buffer, start_offset, count);
    return tokenizer;
}

eat_white_space_and_seen_new_line :: (using tokenizer: *Toml_Tokenizer) -> bool {
    seen := false;
    while t < max_t && ascii_is_space(t.*) {
        if t.* == "\n"
            seen = true;
        t += 1;
    }

    return seen;
}

get_next_token :: (using tokenizer: *Toml_Tokenizer) -> Token {
    if eat_white_space_and_seen_new_line(tokenizer)
        seen_equals = false;

    token := Token.{ start = cast(s32, t - buf.data), type = .eof };

    if t >= max_t return token;

    start_t = t;

    char := t.*;

    if ascii_is_alpha(char) {
        parse_value_keyword(tokenizer, *token);
    } else if ascii_is_digit(char) {
        parse_number(tokenizer, *token);
    } else if char == {
        case "[";
            if !seen_equals && bracket_count == 0 && brace_count == 0 {
                parse_table(tokenizer, *token);
            } else {
                token.type = .punctuation; t += 1;
                bracket_count += 1;
            }

        case "{"; brace_count   += 1; token.type = .punctuation; t += 1;
        case "}"; brace_count   -= 1; token.type = .punctuation; t += 1;
        case "]"; bracket_count -= 1; token.type = .punctuation; t += 1;
        case ",";                     token.type = .punctuation; t += 1;

        case "+"; #through;
        case "-"; #through;
        case ":"; #through;
        case ".";
            token.type = .number; t += 1;

        case "=";
            token.type = .operation; t += 1; seen_equals = true;

        case "'"; #through;
        case "\"";
            parse_string_literal(tokenizer, *token, char);

        case "#";
            parse_comment(tokenizer, *token);

        case;
            token.type = .invalid; t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);

    return token;
}

parse_table :: (using tokenizer: *Toml_Tokenizer, token: *Token) {
    token.type = .header1;
    t += 1;

    open_bracket_count := 1;

    while t < max_t {
        if ascii_is_alnum(t.*) {
            t += 1;
        } else if t.* == {
            case "-"; #through;
            case ".";
                t += 1;
            case "[";
                t += 1;
                open_bracket_count += 1;
            case "]";
                open_bracket_count -= 1;

                t += 1;
                if open_bracket_count <= 0
                    return;

            case;
                return;
        }
    }
}

parse_comment :: (using tokenizer: *Toml_Tokenizer, token: *Token) {
    token.type = .comment;

    t += 1;

    while t < max_t && t.* != "\n"
        t += 1;
}

parse_string_literal :: (using tokenizer: *Toml_Tokenizer, token: *Token, quote: u8) {
    if t + 2 <= max_t && (t+1).* == quote && (t+2).* == quote {
        token.type = .multiline_string;

        end_str := ifx quote == #char "'" then "'''" else "\"\"\"";
        end := find_index_from_left(buf, end_str, start_index = t - buf.data + 2);
        if end < 0 { t = max_t; return; }

        t = buf.data + end + end_str.count;
    } else {
        token.type = .string_literal;

        escape_seen := false;

        t += 1;
        while t < max_t && t.* != #char "\n" {
            if t.* == quote && !escape_seen break;
            escape_seen = !escape_seen && t.* == #char "\\";
            t += 1;
        }
        if t >= max_t return;

        t += 1;
    }
}
parse_number :: (using tokenizer: *Toml_Tokenizer, token: *Token) {
    token.type = .number;

    t += 1;

    if t >= max_t return;

    if t.* == {
        case "x"; #through;
        case "X";
            t += 1;
            while t < max_t && (is_hex(t.*) || t.* == "_") t += 1;

            return;
        case "b"; #through;
        case "B";
            t += 1;
            while t < max_t && (t.* == "0" || t.* == "1" || t.* == "_") t += 1;

            return;
        case "o"; #through;
        case "O";

            is_octal :: inline (c: u8) -> bool {
               return ascii_is_digit(c) && c < "8";
            }

            t += 1;
            while t < max_t && (is_octal(t.*) || t.* == "_") t += 1;

            return;

        case "e"; #through;
        case "_"; #through;
        case "E";
            t += 1;
            while t < max_t && (ascii_is_digit(t.*) || t.* == "_") t += 1;

            return;
    }

    if ascii_is_digit(t.*) {
        while t < max_t && (ascii_is_digit(t.*) || t.* == "_" || t.* == "e" || t.* == "E" || t.* == "T" || t.* == "t" || t.* == "Z" || t.* == "z")
                t += 1;
    }
}

parse_value_keyword :: (using tokenizer: *Toml_Tokenizer, token: *Token) {
    string_start := t;

    t += 1;

    while t < max_t && ascii_is_alnum(t.*)
        t += 1;

    token.type = .identifier;

    // if t >= max_t return;

    view := string.{ data = start_t, count = t - string_start };

    if view == {
        case "false"; #through;
        case "true";
            token.type = .value;
        case "nan"; #through;
        case "inf";
            token.type = .number;
    }
}

