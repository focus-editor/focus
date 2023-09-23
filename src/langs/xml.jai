highlight_xml_syntax :: (using buffer: *Buffer) {
    tokenizer := get_tokenizer(buffer);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;
        color := COLOR_MAP[token.type];
        memset(colors.data + token.start, xx color, token.len);
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
                is_end_tag := peek_next_token(*tokenizer).type == .tag_closing_slash;
                token.type = ifx is_end_tag then .close else .open;
                token.kind = .brace;
            }

            case .tag_delimiter_end; {
                is_void_element := tokenizer.last_token.type == .tag_closing_slash || tokenizer.current_scope_tag_is_known_void_element;

                if !is_void_element && tokenizer.html_mode && tokenizer.current_scope_tag_name {
                    for element: HTML_VOID_ELEMENTS {
                        if equal_nocase(tokenizer.current_scope_tag_name, element) {
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

            case .xml_declaration_start; #through;
            case .dtd_parenthesis_open; #through;
            case .dtd_bracket_open; #through;
            case .comment_start; #through;
            case .cdata_start; {
                token.type = .open;
                token.kind = .brace;
            }

            case .xml_declaration_end; #through;
            case .dtd_parenthesis_close; #through;
            case .dtd_bracket_close; #through;
            case .comment_end; #through;
            case .cdata_end; {
                token.type = .close;
                token.kind = .brace;
            }

            case .eof;      token.type = .eof;  // to guarantee we always have indentation tokens
            case;           token.type = .unimportant;
        }

        array_add(*tokens, token);

        if src.type == .eof break;
    }

    return tokens;
}

#scope_file

get_tokenizer :: (using buffer: Buffer) -> Xml_Tokenizer {
    tokenizer: Xml_Tokenizer;

    tokenizer.buf       = to_string(bytes);
    tokenizer.max_t     = bytes.data + bytes.count;
    tokenizer.t         = bytes.data;
    tokenizer.html_mode = buffer.lang == .Html;

    return tokenizer;
}

peek_next_token :: (using tokenizer: *Xml_Tokenizer) -> Xml_Token {
    tokenizer_copy := tokenizer.*;
    token := get_next_token(*tokenizer_copy);
    return token;
}

get_next_token :: (using tokenizer: *Xml_Tokenizer) -> Xml_Token {
    eat_white_space(tokenizer);

    last_token = current_token;

    token: Xml_Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;

    // Look at the first char as if it's ASCII (if it isn't, this is just a text line)
    char := t.*;

    if current_scope == .Tag {
        if char == {
            case #char "<"; token.type = .tag_delimiter_start;      t += 1;
            case #char ">"; token.type = .tag_delimiter_end;        t += 1;
            case #char "/"; token.type = .tag_closing_slash;        t += 1;
            case #char "="; token.type = .attribute_equals;         t += 1;
            case #char "["; token.type = .dtd_bracket_open;         t += 1;
            case #char "("; token.type = .dtd_parenthesis_open;     t += 1;
            case #char ")"; token.type = .dtd_parenthesis_close;    t += 1;
            case #char ","; token.type = .dtd_comma;                t += 1;
            case #char "|"; token.type = .dtd_infix_operator;       t += 1;

            case #char "*"; #through;
            case #char "+"; token.type = .dtd_postfix_operator;     t += 1;

            case #char "%"; {
                if t < max_t - 1 && is_whitespace_char(t[1]) {
                    token.type = .dtd_percent;
                    t += 1;
                }
            }

            case #char "'"; #through;
            case #char "\""; {
                parse_attribute_value(tokenizer, *token);
            }

            case #char "!"; {
                if last_token.type == .tag_delimiter_start {
                    token.type = .tag_exclamation_point;
                    t += 1;
                }
            }
            
            case #char "?"; {
                if last_token.type == .tag_delimiter_start {
                    token.type = .tag_question_mark;
                    t += 1;
                } else {
                    token.type = .dtd_postfix_operator;             t += 1;
                }
            }
        }
    } else if current_scope == .Xml_Declaration {
        if char == {
            case #char "="; token.type = .attribute_equals;         t += 1;

            case #char "?"; {
                if at_string(tokenizer, "?>") {
                    token.type = .xml_declaration_end;
                    t += 2;
                }
            }
        }
    } else if current_scope == .Comment {
        if last_token.type == .comment_start {
            parse_comment_content(tokenizer, *token);
        } else {
            assert(at_string(tokenizer, "-->"));
            token.type = .comment_end;
            t += 3;
        }
    } else if current_scope == .Cdata {
        if at_string(tokenizer, "]]>") {
            token.type = .cdata_end;
            t += 3;
        } else {
            parse_cdata_content(tokenizer, *token);
        }
    } else {
        current_scope_tag_name = "";
        current_scope_tag_is_known_void_element = false;

        if char == {
            case #char "<"; {
                if at_string(tokenizer, "<?xml", false) {
                    token.type = .xml_declaration_start;
                    t += 5;
                } else if at_string(tokenizer, "<!--") {
                    token.type = .comment_start;
                    t += 4;
                } else if at_string(tokenizer, "<![CDATA[") {
                    token.type = .cdata_start;
                    t += 9;
                } else {
                    token.type = .tag_delimiter_start;
                    t += 1;
                }
            }

            case #char "]"; token.type = .dtd_bracket_close;        t += 1;
        }
    }

    if token.type == .eof { // No token found yet.
        if last_token.type == {
            case .tag_delimiter_start; #through;
            case .tag_exclamation_point; #through;
            case .tag_question_mark; #through;
            case .tag_closing_slash;
                parse_tag_name(tokenizer, *token);

            case .xml_declaration_start; #through;
            case .tag_name; #through;
            case .attribute_name; #through;
            case .attribute_value; #through;
            case .attribute_string_value; #through;
            case .dtd_parenthesis_open; #through;
            case .dtd_parenthesis_close; #through;
            case .dtd_infix_operator; #through;
            case .dtd_comma; #through;
            case .dtd_percent; #through;
            case .dtd_parameter_entity;
                parse_attribute_name(tokenizer, *token);

            case .attribute_equals;
                parse_attribute_value(tokenizer, *token);

            case; {
                parse_tag_content(tokenizer, *token);
            }
        }
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);

    if token.type == {
        case .xml_declaration_start; current_scope = .Xml_Declaration;
        case .xml_declaration_end;   current_scope = .None;

        case .tag_delimiter_start;   current_scope = .Tag;
        case .tag_delimiter_end;     current_scope = .None;

        case .comment_start;         current_scope = .Comment;
        case .comment_end;           current_scope = .None;

        case .cdata_start;           current_scope = .Cdata;
        case .cdata_end;             current_scope = .None;

        case .dtd_bracket_open;      current_scope = .None;
        case .dtd_bracket_close;     current_scope = .Tag;

        case .tag_name;
            assert(current_scope == .Tag);
            current_scope_tag_name.data  = buf.data + token.start;
            current_scope_tag_name.count = token.len;
            last_parsed_tag_name = current_scope_tag_name;

        case .tag_exclamation_point;
            assert(current_scope == .Tag);
            current_scope_tag_is_known_void_element = true;
    }
    
    assert(token.type != .eof, "Failed to parse a token.");

    current_token = token;

    return token;
}

parse_tag_name :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    token.type = .tag_name;
    t += 1;
    eat_until_any(tokenizer, " /<>!\t\r\n");
}

parse_attribute_name :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    first_character := t.*;

    token.type = .attribute_name;
    t += 1;
    eat_until_any(tokenizer, " ,+?|*=/<>!()\t\r\n");

    last_character := (t - 1).*;

    if first_character == #char "%" && last_character == #char ";" {
        token.type = .dtd_parameter_entity;
    }
}

parse_attribute_value :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    char := t.*;
    if char == #char "\"" || char == #char "'" {
        token.type = .attribute_string_value;
        t += 1;
        eat_until(tokenizer, char);
        t += 1;
    } else {
        token.type = .attribute_value;
        t += 1;
        eat_until_any(tokenizer, " /<>\t\r\n");
    }
}

parse_tag_content :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    token.type = .tag_content;
    t += 1;

    if html_mode {
        // Special case raw text elements ('script' and 'style').
        in_script := equal_nocase(last_parsed_tag_name, "script");
        in_style  := equal_nocase(last_parsed_tag_name, "style");

        if in_script || in_style {
            while t < max_t {
                eat_until(tokenizer, "</");
                if (in_script && at_string(tokenizer, "</script", false)) || (in_style && at_string(tokenizer, "</style", false))  break;
                t += 1;
            }

            return;
        }
    }

    eat_until(tokenizer, #char "<");
}

parse_comment_content :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    token.type = .comment_content;
    
    while true {
        if eat_until(tokenizer, "-->") {
            if (t - 1).* == #char "-" { // Comments are not allowed to end in '--->'.
                t += 1;
                continue;
            }
        }
        
        break;
    }
}

parse_cdata_content :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    token.type = .cdata_content;
    eat_until(tokenizer, "]]>");
}

at_string :: (using tokenizer: *Xml_Tokenizer, a: string, case_sensitive := true) -> bool {
    if t + a.count - 1 >= max_t  return false;
    b: string = ---;
    b.data = t;
    b.count = a.count;
    if case_sensitive  return equal(a, b);
    return equal_nocase(a, b);
}

eat_until :: (using tokenizer: *Xml_Tokenizer, c: u8) {
    while t < max_t && t.* != c {
        t += 1;
    }
}

eat_until :: (using tokenizer: *Xml_Tokenizer, s: string) -> bool {
    our_max_t := max_t - s.count + 1;

    while t < our_max_t {
        found := true;
        for c: 0..s.count-1 {
            found &= t[c] == s[c];
        }

        if found  return true;
        t += 1;
    }

    t = max_t;
    return false;
}

eat_until_any :: (using tokenizer: *Xml_Tokenizer, s: string) {
    while t < max_t {
        for c: 0..s.count-1  if t.* == s[c]  return;
        t += 1;
    }
}

eat_white_space :: (using tokenizer: *Xml_Tokenizer) {
    while t < max_t && is_space(t.*) {
        t += 1;
    }
}

Xml_Tokenizer :: struct {
    buf:     string;
    max_t:   *u8;
    start_t: *u8;  // cursor when starting parsing new token
    t:       *u8;  // cursor

    current_token: Xml_Token;
    last_token: Xml_Token;

    current_scope: Xml_Tokenizer_Scope;
    current_scope_tag_name: string;                // Only valid when current_scope == .Tag.
    current_scope_tag_is_known_void_element: bool; // Only valid when current_scope == .Tag.
    last_parsed_tag_name: string;

    html_mode: bool; // If true, we enable some heuristics to improve HTML parsing.
}

Xml_Tokenizer_Scope :: enum {
    None;
    Tag;
    Xml_Declaration;
    Comment;
    Cdata;
}

Xml_Token :: struct {
    start, len: s32;
    type: Type;

    Type :: enum u16 {
        eof;

        error;
        default;

        xml_declaration_start;
        xml_declaration_end;
        tag_delimiter_start;
        tag_delimiter_end;
        tag_closing_slash;
        tag_exclamation_point;
        tag_question_mark;
        tag_name;
        tag_content;
        attribute_name;
        attribute_value;
        attribute_string_value;
        attribute_equals;
        
        comment_start;
        comment_end;
        comment_content;
        
        cdata_start;
        cdata_end;
        cdata_content;

        dtd_parenthesis_open;
        dtd_parenthesis_close;
        dtd_bracket_open;
        dtd_bracket_close;
        dtd_infix_operator;
        dtd_postfix_operator;
        dtd_percent;
        dtd_comma;
        dtd_parameter_entity;
    }
}

// Must match the order of the types in the enum above
COLOR_MAP :: Code_Color.[
    .COMMENT,       // eof - obviously not used

    .ERROR,         // error
    .DEFAULT,       // default

    .COMMENT,       // xml_declaration_start
    .COMMENT,       // xml_declaration_end
    .FUNCTION,      // tag_delimiter_start
    .FUNCTION,      // tag_delimiter_end
    .FUNCTION,      // tag_closing_slash
    .FUNCTION,      // tag_exclamation_point
    .FUNCTION,      // tag_question_mark
    .KEYWORD,       // tag_name
    .DEFAULT,       // tag_content
    .TYPE,          // attribute_name
    .VALUE,         // attribute_value
    .STRING,        // attribute_string_value
    .DEFAULT,       // attribute_equals

    .COMMENT,       // comment_start
    .COMMENT,       // comment_end
    .COMMENT,       // comment_content

    .COMMENT,       // cdata_start
    .COMMENT,       // cdata_end
    .VALUE,         // cdata_content

    .PUNCTUATION,   // dtd_parenthesis_open
    .PUNCTUATION,   // dtd_parenthesis_close
    .PUNCTUATION,   // dtd_bracket_open
    .PUNCTUATION,   // dtd_bracket_close
    .OPERATION,     // dtd_infix_operator
    .OPERATION,     // dtd_postfix_operator
    .OPERATION,     // dtd_percent
    .PUNCTUATION,   // dtd_comma
    .VALUE_KEYWORD, // dtd_parameter_entity
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
];
