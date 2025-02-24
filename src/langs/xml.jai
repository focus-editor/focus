tokenize_xml :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_xml_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;
        memset(tokens.data + token.start, xx TOKEN_MAP[token.type], token.len);
    }

    return tokenizer.regions;
}

tokenize_xml_for_indentation :: (buffer: Buffer) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_xml_tokenizer(buffer);

    while true {
        src := get_next_token(*tokenizer);

        token: Indentation_Token = ---;
        token.start = src.start;
        token.len   = src.len;

        if src.type == {
            case .tag_start; {
                is_end_tag := peek_next_token(*tokenizer).type == .tag_closing_slash;
                token.type = ifx is_end_tag then .close else .open;
                token.kind = .brace;
            }

            case .tag_end; {
                if tokenizer.last_token.type == .tag_closing_slash || tokenizer.active_tag_is_known_void_element {
                    token.type = .close;
                    token.kind = .brace;
                }
            }

            case .processing_instruction_start; #through;
            case .dtd_parenthesis_open; #through;
            case .dtd_bracket_open; #through;
            case .comment_start; #through;
            case .dtd_conditional_section_start; #through;
            case .cdata_start; {
                token.type = .open;
                token.kind = .brace;
            }

            case .processing_instruction_end; #through;
            case .dtd_parenthesis_close; #through;
            case .dtd_bracket_close; #through;
            case .comment_end; #through;
            case .dtd_conditional_section_end; #through;
            case .cdata_end; {
                token.type = .close;
                token.kind = .brace;
            }

            case .eof;  token.type = .eof;  // to guarantee we always have indentation tokens
            case;       token.type = .unimportant;
        }

        array_add(*tokens, token);

        if src.type == .eof break;
    }

    return tokens;
}

#scope_file

get_xml_tokenizer :: (using buffer: Buffer, start_offset := -1, count := -1) -> Xml_Tokenizer {
    tokenizer: Xml_Tokenizer;

    tokenizer.buf       = to_string(bytes);
    tokenizer.max_t     = bytes.data + bytes.count;
    tokenizer.t         = bytes.data;
    tokenizer.html_mode = buffer.lang == .Html;

    if start_offset >= 0 {
        start_offset = clamp(start_offset, 0, bytes.count - 1);
        count        = clamp(count,        0, bytes.count - 1);
        tokenizer.t += start_offset;
        tokenizer.max_t = tokenizer.t + count;
    }

    return tokenizer;
}

peek_next_token :: (using tokenizer: *Xml_Tokenizer, $skip_characters := 0) -> Xml_Token {
    tokenizer_copy := tokenizer.*;
    tokenizer_copy.t += skip_characters;
    token := get_next_token(*tokenizer_copy);
    return token;
}

get_next_token :: (using tokenizer: *Xml_Tokenizer) -> Xml_Token {
    eat_white_space(tokenizer);

    last_token = current_token;
    last_state = state;

    token: Xml_Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;

    if t >= max_t return token;
    start_t = t;

    parse_token(tokenizer, *token);

    if token.type == .eof {
        token.type = .error;
        t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);

    current_token = token;

    return token;
}

parse_token :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    if #complete state == {
        case .Parsing_Tag; #through;
        case .Parsing_Closing_Tag;
            parse_tag(tokenizer, token);

        case .Parsing_Processing_Instruction;
            parse_processing_instruction(tokenizer, token);

        case .Parsing_Comment;
            parse_comment(tokenizer, token);

        case .Parsing_Cdata;
            parse_cdata(tokenizer, token);

        case .Parsing_Implicit_Cdata_Tag_Content;
            parse_tag_content(tokenizer, token);

        case .None;
            if t.* == {
                case #char "<";  parse_less_than_sign(tokenizer, token);
                case #char "]";  parse_bracket_close(tokenizer, token);
                case;            parse_tag_content(tokenizer, token);
            }
    }
}

parse_less_than_sign :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    t += 1;

    if t < max_t {
        char := t.*;
        if char == #char "?" {
            token.type = .processing_instruction_start;
            state = .Parsing_Processing_Instruction;
            t += 1;
            return;
        }

        if char == #char "!" {
            t += 1;

            // Comment start.
            if at_string(tokenizer, "--") {
                token.type = .comment_start;
                t += 2;
                state = .Parsing_Comment;
                return;
            }

            // CDATA start.
            if at_string(tokenizer, "[CDATA[") {
                token.type = .cdata_start;
                t += 7;
                state = .Parsing_Cdata;
                return;
            }

            // Conditional section start.
            if at_char(tokenizer, #char "[") {
                token.type = .dtd_conditional_section_start;
                conditional_section_depth += 1;
                t += 1;

                // Try to find a section start of the form '<![xxx[', with optional whitespace around 'xxx'.
                t_original := t;
                eat_white_space(tokenizer);
                eat_until_any(tokenizer, " []</!?\t\r\n");
                eat_white_space(tokenizer);
                if t.* == #char "[" {
                    t += 1;
                } else {
                    t = t_original;
                }

                state = .None;
                return;
            }

            t -= 1; // No match, step back.
        }
    }

    token.type = .tag_start;
    state = .Parsing_Tag;
}

parse_tag :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    if last_token.type == .attribute_equals {
        parse_attribute_value(tokenizer, token);
        return;
    }

    char := t.*;

    if char == {
        case #char "<";
            state = .Parsing_Tag;
            token.type = .tag_start;
            t += 1;

        case #char ">";
            is_void_element := active_tag_is_known_void_element || last_token.type == .tag_closing_slash;
            is_closing_tag := state == .Parsing_Closing_Tag || is_void_element;
            state = .None;
            if !is_closing_tag && html_mode && contains(HTML_RAW_TEXT_ELEMENTS, active_tag_name)  state = .Parsing_Implicit_Cdata_Tag_Content;
            token.type = .tag_end;
            t += 1;

        case #char "/";
            state = .Parsing_Closing_Tag;
            token.type = .tag_closing_slash;
            t += 1;

        case #char "[";
            state = .None;
            in_dtd_internal_subset = true;
            token.type = .dtd_bracket_open;
            t += 1;

        case #char "=";
            if last_token.type == .attribute_name {
                token.type = .attribute_equals;
                t += 1;
            } else return; // error

        case #char "'"; #through;
        case #char "\""; {
            parse_attribute_value(tokenizer, token);
        }

        case #char "!"; {
            if last_token.type == .tag_start {
                token.type = .tag_exclamation_point;
                t += 1;
            }
        }

        case #char "%"; {
            if t < max_t - 1 && is_whitespace_char(t[1]) {
                token.type = .dtd_percent;
                t += 1;
            }
        }

        case #char "("; token.type = .dtd_parenthesis_open;     t += 1;
        case #char ")"; token.type = .dtd_parenthesis_close;    t += 1;
        case #char ","; token.type = .dtd_comma;                t += 1;
        case #char "|"; token.type = .dtd_infix_operator;       t += 1;
        case #char "*"; token.type = .dtd_postfix_operator;     t += 1;
        case #char "+"; token.type = .dtd_postfix_operator;     t += 1;
        case #char "?"; token.type = .dtd_postfix_operator;     t += 1;
    }

    if token.type != .eof  return;

    if last_token.type == {
        case .tag_start; #through;
        case .tag_exclamation_point; #through;
        case .tag_closing_slash;
            active_tag_name = parse_tag_name(tokenizer, token);
            active_tag_is_known_void_element = false;
            if last_token.type == .tag_exclamation_point {
                active_tag_is_known_void_element = true;
            } else if html_mode {
                active_tag_is_known_void_element = contains(HTML_VOID_ELEMENTS, active_tag_name);
            }

        case;
            if html_mode  parse_html_attribute_name(tokenizer, token);
            else          parse_attribute_name(tokenizer, token);
    }
}

parse_processing_instruction :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    if last_token.type == {
        case .processing_instruction_start;
            parse_tag_name(tokenizer, token);
            token.type = .processing_instruction_target;

        case .processing_instruction_content;
            assert(at_string(tokenizer, "?>"));
            state = .None;
            token.type = .processing_instruction_end;
            t += 2;

        case;
            token.type = .processing_instruction_content;
            eat_until(tokenizer, "?>");
    }
}

parse_comment :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    if at_string(tokenizer, "-->") {
        state = .None;
        token.type = .comment_end;
        t += 3;
    } else if at_string(tokenizer, "--") { // The string '--' is not allowed within an xml comment.
        token.type = .error;
        t += 2;
    } else {
        token.type = .comment_content;
        eat_until(tokenizer, ifx html_mode then "-->" else "--"); // In html mode the string '--' is allowed in a comment so just find the end of the comment.
    }
}

parse_cdata :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    if last_token.type == {
        case .cdata_content;
            assert(at_string(tokenizer, "]]>"));
            state = .None;
            token.type = .cdata_end;
            t += 3;

        case;
            token.type = .cdata_content;
            eat_until(tokenizer, "]]>");
    }
}

parse_tag_name :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) -> string {
    tag_name: string = ---;
    tag_name.data = t;
    token.type = .tag_name;
    eat_until_any(tokenizer, " /<>!?\t\r\n");
    tag_name.count = t - tag_name.data;
    return tag_name;
}

parse_attribute_name :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    token.type = .attribute_name;

    if t.* == #char "%" { // Handle parameter entity reference.
        t += 1;
        token.type = .dtd_parameter_entity;
        if !eat_entity(tokenizer, token)  token.type = .error;
        return;
    }


    if !VALID_NAME_TABLE[t.*] {
        t += 1;
        token.type = .error;
        return;
    }

    t += 1;

    while t < max_t {
        if VALID_NAME_TABLE[t.*] {
            t += 1;
            continue;
        }
        break;
    }
}

// https://html.spec.whatwg.org/multipage/syntax.html#attributes-2
parse_html_attribute_name :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    token.type = .attribute_name;

    if INVALID_HTML_ATTRIBUTE_NAME_TABLE[t.*] {
        token.type = .error;
        t += 1;
        return;
    }

    t += 1;

    while t < max_t {
        if INVALID_HTML_ATTRIBUTE_NAME_TABLE[t.*] {
            break;
        }

        t += 1;
    }
}

parse_attribute_value :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    is_valid_attribute_character :: (char: u8) -> bool #expand {
        return char != #char " " && char != #char ">";
    }

    char := t.*;
    if char == #char "\"" || char == #char "'" {
        token.type = .attribute_string_value;
        t += 1;
        eat_until(tokenizer, char);
        t += 1;
    } else if html_mode && is_valid_attribute_character(char) {
        token.type = .attribute_value;
        while t < max_t {
            t += 1;
            if !is_valid_attribute_character(t.*)  break;
        }
    }
}

eat_entity :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) -> bool {
    initial_t := t;

    while t < max_t && VALID_NAME_TABLE[t.*]  t += 1;

    if t < max_t && t.* == #char ";" {
        t += 1;
        return true;
    }

    t = initial_t;
    return false;
}

parse_tag_content :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    token.type = .tag_content;

    if state == .Parsing_Implicit_Cdata_Tag_Content && active_tag_name {
        state = .None;

        end_tag := tprint("</%", active_tag_name);
        while t < max_t {
            eat_until(tokenizer, "</");
            if at_string(tokenizer, end_tag, false)  break;
            t += 1;
        }

        if html_mode && active_tag_name == "script" {
            start := last_token.start + 1;
            end   := cast(s32) (t - buf.data);

            if t >= max_t  end = cast(s32) (t - 1 - buf.data);

            t_start := buf.data + start;
            count   := ifx t >= max_t then t - t_start - 1 else t - t_start;
            script  := string.{ data = t_start, count = count };

            found, first_line := split_from_left(script, "\n");
            if found && is_all_whitespace(first_line)  start += xx (first_line.count + 1); // + 1 for the newline itself

            if t < max_t {
                found, _, last_line := split_from_right(script, "\n");
                if found && is_all_whitespace(last_line)  end -= xx last_line.count;
            }

            array_add(*regions, Buffer_Region.{ start = start, end = end, kind = .heredoc, lang = .Js });
        }

        return;
    }

    if in_dtd_internal_subset || conditional_section_depth > 0  eat_until_any(tokenizer, "<]");
    else                                                        eat_until(tokenizer, #char "<");
}

parse_bracket_close :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    assert(state == .None && t.* == #char "]");

    t += 1;

    if conditional_section_depth > 0 && at_string(tokenizer, "]>") {
        conditional_section_depth -= 1;
        token.type = .dtd_conditional_section_end;
        t += 2;
    } else if in_dtd_internal_subset {
        in_dtd_internal_subset = false;
        state = .Parsing_Tag;
        token.type = .dtd_bracket_close;
    } else {
        token.type = .tag_content;
    }
}

at_string :: (using tokenizer: *Xml_Tokenizer, a: string, $case_sensitive := true) -> bool {
    if t + a.count > max_t  return false;
    b: string = ---;
    b.data = t;
    b.count = a.count;
    #if case_sensitive  return equal(a, b);
    else                return equal_nocase(a, b);
}

at_char :: inline (using tokenizer: *Xml_Tokenizer, c: u8) -> bool {
    return t < max_t && t.* == c;
}

eat_until :: inline (using tokenizer: *Xml_Tokenizer, c: u8) {
    while t < max_t && t.* != c {
        t += 1;
    }
}

eat_until :: (using tokenizer: *Xml_Tokenizer, s: string) {
    our_max_t := max_t - s.count + 1;

    while outer := t < our_max_t {
        for c: 0..s.count-1 {
            if t[c] != s[c] {
                t += 1;
                continue outer;
            }
        }
        return;
    }

    t = max_t;
}

eat_until_any :: inline (using tokenizer: *Xml_Tokenizer, s: string) {
    while t < max_t {
        for c: 0..s.count-1  if t.* == s[c]  return;
        t += 1;
    }
}

eat_white_space :: inline (using tokenizer: *Xml_Tokenizer) {
    while t < max_t && WHITE_SPACE_TABLE[t.*] {
        t += 1;
    }
}

contains :: (arr: [] string, s: string) -> bool {
    if !s  return false;
    for arr  if s == it  return true;
    return false;
}

Xml_Tokenizer :: struct {
    buf:     string;
    max_t:   *u8;
    start_t: *u8;  // cursor when starting parsing new token
    t:       *u8;  // cursor

    regions: [..] Buffer_Region;
    regions.allocator = temp;

    state: Xml_Tokenizer_State;
    current_token: Xml_Token;
    last_token: Xml_Token;
    last_state: Xml_Tokenizer_State;

    active_tag_name: string;
    active_tag_is_known_void_element: bool;
    conditional_section_depth := 0;
    in_dtd_internal_subset: bool;

    html_mode: bool; // If true, we enable some heuristics to improve HTML parsing.
}

Xml_Tokenizer_State :: enum u8 {
    None;
    Parsing_Tag;
    Parsing_Closing_Tag;
    Parsing_Comment;
    Parsing_Cdata;
    Parsing_Processing_Instruction;
    Parsing_Implicit_Cdata_Tag_Content;
}

Xml_Token :: struct {
    start, len: s32;
    type: Type;

    Type :: enum u16 {
        eof;

        error;
        default;

        tag_start;
        tag_end;
        tag_closing_slash;
        tag_exclamation_point;
        tag_name;
        tag_content;

        attribute_name;
        attribute_value;
        attribute_string_value;
        attribute_equals;

        comment_start;
        comment_end;
        comment_content;

        processing_instruction_start;
        processing_instruction_end;
        processing_instruction_target;
        processing_instruction_content;

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
        dtd_conditional_section_start;
        dtd_conditional_section_end;
    }
}


// Must match the order of the types in the enum above.
// We're translating very specific token types into the generic token types
// to avoid adding too many tokens to the default token list, where we
// don't really need this granularity
TOKEN_MAP :: Token_Type.[
    .eof,       // eof - obviously not used

    .error,             // error
    .default,           // default

    .function,          // tag_start
    .function,          // tag_end
    .function,          // tag_closing_slash
    .function,          // tag_exclamation_point
    .keyword,           // tag_name
    .default,           // tag_content

    .type,              // attribute_name
    .value,             // attribute_value
    .string_literal,    // attribute_string_value
    .default,           // attribute_equals

    .comment,           // comment_start
    .comment,           // comment_end
    .comment,           // comment_content

    .comment,           // processing_instruction_start
    .comment,           // processing_instruction_end
    .comment,           // processing_instruction_target
    .comment,           // processing_instruction_content

    .comment,           // cdata_start
    .comment,           // cdata_end
    .value,             // cdata_content

    .punctuation,       // dtd_parenthesis_open
    .punctuation,       // dtd_parenthesis_close
    .punctuation,       // dtd_bracket_open
    .punctuation,       // dtd_bracket_close
    .operation,         // dtd_infix_operator
    .operation,         // dtd_postfix_operator
    .operation,         // dtd_percent
    .punctuation,       // dtd_comma
    .value,             // dtd_parameter_entity
    .comment,           // dtd_conditional_section_start
    .comment,           // dtd_conditional_section_end
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

// Actually, 'script' and 'style' are 'raw text elements', whereas 'title' and 'textarea' are 'escapable raw text elements'.
// This means that character references (e.g., '&amp;') have meaning inside 'title' and 'textarea' elements. However, we do not
// currently parse character references separately, so we treat the contents of all these tags as regular character data.
HTML_RAW_TEXT_ELEMENTS :: string.[
    "script",
    "style",
    "title",
    "textarea",
];

// Lookup table stuff below. These are used for performance reasons.

WHITE_SPACE_TABLE :: #run generate_lookup_table(Character_Range.[
    make_range(#char " "),
    make_range(#char "\t"),
    make_range(#char "\n"),
    make_range(#char "\r"),
    make_range(0x0c), // form feed
], strict = true);

VALID_NAME_TABLE :: #run generate_lookup_table(Character_Range.[
    make_range(#char ":"),
    make_range(#char "A", #char "Z"),
    make_range(#char "_"),
    make_range(#char "a", #char "z"),
    make_range(#char "-"),

    // '.' and '0' through '9' are not allowed as the initial character for names, but we don't check for that.
    // This allows us to parse certain values that can occur in DTDs.
    make_range(#char "."),
    make_range(#char "0", #char "9"),

    // '#' is not allowed for regular names, but this makes us parse DTD keywords like #PCDATA, #IMPLIED, etcetera.
    make_range(#char "#"),
]);

INVALID_HTML_ATTRIBUTE_NAME_TABLE :: #run generate_lookup_table(Character_Range.[
    make_range(#char " "),
    make_range(#char "\t"),
    make_range(#char "\n"),
    make_range(#char "\r"),
    make_range(0x0c),

    make_range(0,    0x1f),
    make_range(0x7f, 0x9f),
    make_range(#char "\""),
    make_range(#char "'"),
    make_range(#char ">"),
    make_range(#char "/"),
    make_range(#char "="),

    // There are some multi byte characters that are omitted here (see https://html.spec.whatwg.org/multipage/syntax.html#attributes-2).
]);

Character_Range :: struct { start: u8; end: u8; }

make_range :: (start: u8, end: u8) -> Character_Range { return .{start, end}; }
make_range :: (start: u8)          -> Character_Range { return .{start, start}; }

generate_lookup_table :: (ranges: [] Character_Range, strict := false) -> [256] bool {
    lut: [256] bool;
    for range: ranges {
        for c: range.start..range.end  lut[c] = true;
    }

    if !strict {
        // Accept values that are outside the ASCII range.
        for c: 0x80..0xff  lut[c] = true;
    }

    return lut;
}
