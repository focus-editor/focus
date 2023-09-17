highlight_xml_syntax :: (using buffer: *Buffer) {
    tokenizer := get_tokenizer(buffer);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;
        color := COLOR_MAP[token.type];
        memset(colors.data + token.start, xx color, token.len);
        tokenizer.last_token = token;
    }
}

tokenize_xml_for_indentation :: (using buffer: Buffer) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_tokenizer(buffer);

    while true {
        src := get_next_token(*tokenizer);

        token: Indentation_Token = ---;
        token.start = src.start;
        token.len   = src.len;

        if src.type == {
            case .tag_delimiter_start; {
                is_end_tag := peek_next_token(*tokenizer).type == .tag_delimiter_end_slash;
                token.type = ifx is_end_tag then .close else .open;
                token.kind = .brace;
            }

            case .tag_delimiter_end; {
                is_void_element := tokenizer.last_token.type == .tag_delimiter_end_slash;

                if !is_void_element && tokenizer.html_mode {
                    for element: HTML_VOID_ELEMENTS {
                        if equal_nocase(tokenizer.parent_tag_name, element) {
                            is_void_element = true;
                            break;
                        }
                    }
                }

                if is_void_element {
                    token.type = .close;
                    token.kind = .brace;
                }
            }

            case .text;  token.type = .unimportant;
            case .eof;   token.type = .eof;  // to guarantee we always have indentation tokens
            case;        token.type = .unimportant;
        }

        tokenizer.last_token = src;

        array_add(*tokens, token);

        if src.type == .eof break;
    }

    return tokens;
}

#scope_file

get_tokenizer :: (using buffer: Buffer) -> Tokenizer {
    tokenizer: Tokenizer;

    tokenizer.buf       = to_string(bytes);
    tokenizer.max_t     = bytes.data + bytes.count;
    tokenizer.t         = bytes.data;
    tokenizer.html_mode = buffer.lang == .Html;

    return tokenizer;
}

peek_next_token :: (using tokenizer: *Tokenizer) -> Token {
    tokenizer_copy := <<tokenizer;
    token := get_next_token(*tokenizer_copy);
    return token;
}

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
        case #char "<"; {
            if at_string(tokenizer, "<?") {
                parse_schema(tokenizer, *token);
            } else if at_string(tokenizer, "<!--") {
                parse_comment(tokenizer, *token);
            } else {
                token.type = .tag_delimiter_start;
                t += 1;
            }
        }

        case #char ">"; {
            token.type = .tag_delimiter_end;
            t += 1;
        }

        case #char "/"; {
            if inside_tag {
                token.type = .tag_delimiter_end_slash;
                t += 1;
            }
        }

        case #char "="; {
            if inside_tag {
                token.type = .attribute_equals;
                t += 1;
            }
        }

        // We could have a 'standalone' string value in an element like DOCTYPE.
        case #char "'"; #through;
        case #char "\""; {
            if inside_tag  parse_attribute_value(tokenizer, *token);
        }
    }

    if token.type == .eof { // No token found yet.
        if last_token.type == {
            case .tag_delimiter_start; #through;
            case .tag_delimiter_end_slash;  parse_tag_name(tokenizer, *token);

            case .tag_name; #through;
            case .attribute_name; #through;
            case .attribute_value; #through;
            case .attribute_string_value;   parse_attribute_name(tokenizer, *token);

            case .attribute_equals;         parse_attribute_value(tokenizer, *token);

            case; {
                if !inside_tag  parse_text(tokenizer, *token);
            }
        }
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);

    if token.type == {
        case .tag_delimiter_start;  inside_tag = true;
        case .tag_delimiter_end;    inside_tag = false;
        case .tag_name; {
            parent_tag_name.data  = buf.data + token.start;
            parent_tag_name.count = token.len;
        }
    }

    return token;
}

parse_schema :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .schema;
    t += 2;
    if eat_until(tokenizer, "?>")  t += 2;
}

parse_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .comment;
    t += 4;
    if eat_until(tokenizer, "-->")  t += 3;
}

parse_tag_name :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .tag_name;
    t += 1;
    eat_until_any(tokenizer, " />\t\r\n");
}

parse_attribute_name :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .attribute_name;
    t += 1;
    eat_until_any(tokenizer, " =/>\t\r\n");
}

parse_attribute_value :: (using tokenizer: *Tokenizer, token: *Token) {
    if <<t == #char "\"" {
        token.type = .attribute_string_value;
        t += 1;
        eat_until(tokenizer, #char "\"");
        t += 1;
    } else if <<t == #char "'" {
        token.type = .attribute_string_value;
        t += 1;
        eat_until(tokenizer, #char "'");
        t += 1;
    } else {
        token.type = .attribute_value;
        t += 1;
        eat_until_any(tokenizer, " />\t\r\n");
    }
}

parse_text :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .text;
    t += 1;

    if html_mode {
        // Special case raw text elements ('script' and 'style').
        in_script := parent_tag_name == "script";
        in_style  := parent_tag_name == "style";

        if in_script || in_style {
            while t < max_t {
                eat_until(tokenizer, "</");
                if (in_script && at_string(tokenizer, "</script")) || (in_style && at_string(tokenizer, "</style"))  break;
                t += 1;
            }

            return;
        }
    }

    eat_until(tokenizer, #char "<");
}

at_string :: (using tokenizer: *Tokenizer, s: string) -> bool {
    if t < max_t - s.count + 1 {
        for 0..s.count-1 {
            if t[it] != s[it]  return false;
        }
        return true;
    }
    return false;
}

eat_until :: (using tokenizer: *Tokenizer, c: u8) {
    while t < max_t && <<t != c {
        t += 1;
    }
}

eat_until :: (using tokenizer: *Tokenizer, s: string) -> bool {
    our_max_t := max_t - s.count + 1;

    while t < our_max_t {
        found := true;
        for c: 0..s.count-1 {
            found &= t[c] == s[c];
        }

        if found  return true;
        t += 1;
    }

    return false;
}

eat_until_any :: (using tokenizer: *Tokenizer, s: string) {
    while t < max_t {
        for c: 0..s.count-1  if <<t == s[c]  return;
        t += 1;
    }
}

eat_white_space :: (using tokenizer: *Tokenizer) {
    while t < max_t && is_space(<< t) {
        t += 1;
    }
}

Tokenizer :: struct {
    buf:     string;
    max_t:   *u8;
    start_t: *u8;  // cursor when starting parsing new token
    t:       *u8;  // cursor

    inside_tag: bool;
    parent_tag_name: string;
    last_token: Token;

    html_mode: bool; // If true, we enable some heuristics to improve HTML parsing.
}

Token :: struct {
    start, len: s32;
    type: Type;

    Type :: enum u16 {
        eof;

        error;
        default;
        comment;

        schema;
        tag_delimiter_start;
        tag_delimiter_end;
        tag_delimiter_end_slash;
        tag_name;
        attribute_name;
        attribute_value;
        attribute_string_value;
        attribute_equals;
        text;
    }
}

// Must match the order of the types in the enum above
COLOR_MAP :: Code_Color.[
    .COMMENT,  // eof - obviously not used

    .ERROR,    // error
    .DEFAULT,  // default
    .COMMENT,  // comment

    .COMMENT,  // schema
    .DEFAULT,  // tag_delimiter_start
    .DEFAULT,  // tag_delimiter_end
    .DEFAULT,  // tag_delimiter_end_slash
    .FUNCTION, // tag_name
    .TYPE,  // attribute_name
    .VALUE,    // attribute_value
    .STRING,   // attribute_string_value
    .DEFAULT,  // attribute_equals
    .DEFAULT   // text
];

// HTML elements that should not have a closing tag, and have an *optional* forward slash at the end of the tag.
HTML_VOID_ELEMENTS :: string.[
    "area",
    "base",
    "br",
    "col",
    "command",
    "embed",
    "hr",
    "img",
    "input",
    "keygen",
    "link",
    "meta",
    "param",
    "source",
    "track",
    "wbr",
    "!doctype" // Not officially a void element, but we can treat it as such.
];
