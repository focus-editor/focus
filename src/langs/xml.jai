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
            case .cdata_start; {
                token.type = .open;
                token.kind = .brace;
            }

            case .processing_instruction_end; #through;
            case .dtd_parenthesis_close; #through;
            case .dtd_bracket_close; #through;
            case .comment_end; #through;
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

get_tokenizer :: (using buffer: Buffer) -> Xml_Tokenizer {
    tokenizer: Xml_Tokenizer;
    tokenizer.buf       = to_string(bytes);
    tokenizer.max_t     = bytes.data + bytes.count;
    tokenizer.t         = bytes.data;
    tokenizer.html_mode = buffer.lang == .Html;
    return tokenizer;
}

peek_next_token :: (using tokenizer: *Xml_Tokenizer, $skip_characters := 0) -> Xml_Token {
    tokenizer_copy := tokenizer.*;
    tokenizer_copy.t += skip_characters;
    token := get_next_token(*tokenizer_copy);
    return token;
}

get_next_token :: (using tokenizer: *Xml_Tokenizer) -> Xml_Token {
    eat_whitespace(tokenizer);

    last_token = current_token;
    last_state = state;

    token: Xml_Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;
    char := t.*;

    if tokenizer.state == .None {
        if char == #char "<" {
            if      at_string(tokenizer, "<?")         state = .Parsing_Processing_Instruction;
            else if at_string(tokenizer, "<!--")       state = .Parsing_Comment;
            else if at_string(tokenizer, "<![CDATA[")  state = .Parsing_Cdata;
            else if at_string(tokenizer, "<![")        state = .Parsing_Conditional_Section_Start;
            else                                       state = .Parsing_Tag;
        } else if char == #char "]" {
            if conditional_section_depth > 0 && at_string(tokenizer, "]]>") {
                conditional_section_depth -= 1;
                token.type = .dtd_conditional_section_end;
                t += 3;
            } else if in_dtd_internal_subset {
                in_dtd_internal_subset = false;
                state = .Parsing_Tag;
                token.type = .dtd_bracket_close;
                t += 1;
            }
        }
    }

    if #complete tokenizer.state == {
        case .Parsing_Tag; #through;
        case .Parsing_Closing_Tag;
            parse_tag(tokenizer, *token, char);
        
        case .Parsing_Processing_Instruction;
            parse_processing_instruction(tokenizer, *token);
        
        case .Parsing_Comment;
            parse_comment(tokenizer, *token);
            
        case .Parsing_Cdata;
            parse_cdata(tokenizer, *token);

        case .Parsing_Conditional_Section_Start;
            parse_conditional_section_start(tokenizer, *token);
        
        case .Parsing_Implicit_Cdata_Tag_Content; #through;
        case .None;
            parse_tag_content(tokenizer, *token);
    }

    if token.type == .eof {
        token.type = .error;
        t += 1;
    }
        
    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);

    current_token = token;

    return token;
}

parse_tag :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token, char: u8) {
    assert(state == .Parsing_Tag || state == .Parsing_Closing_Tag);

    if last_token.type == .attribute_equals {
        parse_attribute_value(tokenizer, token);
        return;
    }

    if char == {
        case #char "<";
            if last_state == .None {
                token.type = .tag_start;
                t += 1;
            } else return; // error

        case #char ">";
            is_void_element := active_tag_is_known_void_element || last_token.type == .tag_closing_slash;
            is_closing_tag := state == .Parsing_Closing_Tag || is_void_element;
            state = .None;
            if !is_closing_tag && html_mode && contains_nocase(HTML_RAW_TEXT_ELEMENTS, active_tag_name)  state = .Parsing_Implicit_Cdata_Tag_Content;
            token.type = .tag_end;
            t += 1;

        case #char "/";
            if state != .Parsing_Closing_Tag && (last_token.type == .tag_start || peek_next_token(tokenizer, 1).type == .tag_end) {
                state = .Parsing_Closing_Tag;
                token.type = .tag_closing_slash;
                t += 1;
            } else return; // error
        
        case #char "[";
            in_dtd_internal_subset = true;
            token.type = .dtd_bracket_open;
            t += 1;
        
        case #char "=";
            if last_token.type == .attribute_name {
                token.type = .attribute_equals;
                t += 1;
            } else return; // error

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
            parse_attribute_value(tokenizer, token);
        }
        
        case #char "!"; {
            if last_token.type == .tag_start {
                token.type = .tag_exclamation_point;
                t += 1;
            }
        }
        
        case #char "?"; {
            token.type = .dtd_postfix_operator;
            t += 1;
        }
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
                active_tag_is_known_void_element = contains_nocase(HTML_VOID_ELEMENTS, active_tag_name);
            }

        case;
            parse_attribute_name(tokenizer, token);
    }
}

parse_processing_instruction :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    assert(state == .Parsing_Processing_Instruction);

    if last_token.type == {
        case .processing_instruction_start;
            parse_tag_name(tokenizer, token);
            token.type = .processing_instruction_target;
            
        case .processing_instruction_target;
            token.type = .processing_instruction_content;
            eat_until(tokenizer, "?>");
    
        case .processing_instruction_content;
            assert(at_string(tokenizer, "?>"));
            state = .None;
            token.type = .processing_instruction_end;
            t += 2;
            
        case;
            token.type = .processing_instruction_start;
            t += 2;
    }
}

parse_comment :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    assert(state == .Parsing_Comment);

    if last_token.type == {
        case .comment_start;
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
        
        case .comment_content;
            assert(at_string(tokenizer, "-->"));
            state = .None;
            token.type = .comment_end;
            t += 3;
            
        case;
            token.type = .comment_start;
            t += 4;
    }
}

parse_cdata :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    assert(state == .Parsing_Cdata);

    if last_token.type == {
        case .cdata_start;
            token.type = .cdata_content;
            eat_until(tokenizer, "]]>");
        
        case .cdata_content;
            assert(at_string(tokenizer, "]]>"));
            state = .None;
            token.type = .cdata_end;
            t += 3;
        
        case;
            token.type = .cdata_start;
            t += 9;
    }
}

parse_conditional_section_start :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    assert(state == .Parsing_Conditional_Section_Start);

    token.type = .dtd_conditional_section_start;
    conditional_section_depth += 1;
    t += 3;
    
    // Try to find a section start of the form '<![xxx[', with optional whitespace around 'xxx'.
    tokenizer_copy := tokenizer.*;
    eat_whitespace(*tokenizer_copy);
    eat_until_any(*tokenizer_copy, " []</!?\t\r\n");
    eat_whitespace(*tokenizer_copy);
    if tokenizer_copy.t.* == #char "[" {
        tokenizer_copy.t += 1;
        tokenizer.t = tokenizer_copy.t;
    }
    
    state = .None;
}

parse_tag_name :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) -> string {
    tag_name: string = ---;
    tag_name.data = t;
    token.type = .tag_name;
    t += 1;
    eat_until_any(tokenizer, " /<>!?\t\r\n");
    tag_name.count = t - tag_name.data;
    return tag_name;
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
    } else if html_mode {
        token.type = .attribute_value;
        eat_until_any(tokenizer, " \t\r\n\"'=<>`");
    }
}

parse_tag_content :: (using tokenizer: *Xml_Tokenizer, token: *Xml_Token) {
    token.type = .tag_content;

    if state == .Parsing_Implicit_Cdata_Tag_Content && active_tag_name {
        state = .None;
        
        mark := get_temporary_storage_mark();
        defer   set_temporary_storage_mark(mark);
        
        end_tag := tprint("</%", active_tag_name);
        while t < max_t {
            eat_until(tokenizer, "</");
            if at_string(tokenizer, end_tag, false)  break;
            t += 1;
        }
        return;
    }
    
    if in_dtd_internal_subset || conditional_section_depth > 0  eat_until_any(tokenizer, "<]");
    else                                                        eat_until(tokenizer, #char "<");
}

at_string :: (using tokenizer: *Xml_Tokenizer, a: string, $case_sensitive := true) -> bool {
    if t + a.count > max_t  return false;
    b: string = ---;
    b.data = t;
    b.count = a.count;
    #if case_sensitive  return equal(a, b);
    else                return equal_nocase(a, b);
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

eat_whitespace :: (using tokenizer: *Xml_Tokenizer) {
    while t < max_t && is_whitespace_char(t.*) {
        t += 1;
    }
}

contains_nocase :: (arr: [] string, s: string) -> bool {
    if !s  return false;
    for arr  if equal_nocase(s, it)  return true;
    return false;
}

Xml_Tokenizer :: struct {
    buf:     string;
    max_t:   *u8;
    start_t: *u8;  // cursor when starting parsing new token
    t:       *u8;  // cursor

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
    Parsing_Conditional_Section_Start;
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

// Must match the order of the types in the enum above
COLOR_MAP :: Code_Color.[
    .COMMENT,       // eof - obviously not used

    .ERROR,         // error
    .DEFAULT,       // default

    .FUNCTION,      // tag_start
    .FUNCTION,      // tag_end
    .FUNCTION,      // tag_closing_slash
    .FUNCTION,      // tag_exclamation_point
    .KEYWORD,       // tag_name
    .DEFAULT,       // tag_content

    .TYPE,          // attribute_name
    .VALUE,         // attribute_value
    .STRING,        // attribute_string_value
    .DEFAULT,       // attribute_equals

    .COMMENT,       // comment_start
    .COMMENT,       // comment_end
    .COMMENT,       // comment_content

    .COMMENT,       // processing_instruction_start
    .COMMENT,       // processing_instruction_end
    .COMMENT,       // processing_instruction_target
    .COMMENT,       // processing_instruction_content
    
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
    .COMMENT,       // dtd_conditional_section_start
    .COMMENT,       // dtd_conditional_section_end
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
// currently parse character references separately, so we treat all these tags as regular character data.
HTML_RAW_TEXT_ELEMENTS :: string.[
    "script",
    "style",
    "title",
    "textarea",
];