tokenize_odin :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_odin_tokenizer(buffer, start_offset, count);
    inside_attribute := false;

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        should_highlight_attribute :: (tokenizer: Odin_Tokenizer, token: Token) -> bool {
            // Highlight an attribute if we have specific last tokens
            if token.type != .identifier then return false;
            prev1, prev2, prev3 := tokenizer.last_tokens[0], tokenizer.last_tokens[1], tokenizer.last_tokens[2];

            if prev1.type != .punctuation then return false;
            if prev1.punctuation != .attribute {
                if prev2.type != .punctuation                                       then return false;
                if prev1.punctuation != .l_paren || prev2.punctuation != .attribute then return false;
            }

            return true;
        }

        // Maybe highlight an attribute
        if token.type == .identifier {
            if inside_attribute || should_highlight_attribute(tokenizer, token) {
               inside_attribute = true;
               maybe_parse_attribute(*tokenizer, *token);
            }
        } else if token.type == .punctuation && token.punctuation == .r_paren {
            if inside_attribute then inside_attribute = false;
        }

        // Maybe highlight a procedure
        should_highlight_last_token_as_proc :: (tokenizer: Odin_Tokenizer, token: Token) -> bool {
            if token.type != .punctuation    then return false;
            if token.punctuation != .l_paren then return false;

            prev1, prev2, prev3 := tokenizer.last_tokens[0], tokenizer.last_tokens[1], tokenizer.last_tokens[2];

            // Handle "Identifier(" ...
            if prev1.type != .identifier then return false;

            if prev2.type == .operation {
                // ... but not ":Identifier(" (likely a type) ...
                if prev2.operation == .colon then return false;
            } else if prev2.type == .punctuation {
                if prev2.punctuation == {
                    // ... nor "^Identifier(" / "$Identifier(" / "]Identifier(" (also likely types)
                    case .caret;      #through;
                    case .dollar;     #through;
                    case .r_bracket;  return false;

                    // ... nor "cast(Identifier(" (definitely a type)
                    case .l_paren;
                        if prev3.type == .keyword && prev3.keyword == .kw_cast then return false;
                }
            }

            return true;
        }

        should_highlight_second_last_token_as_proc :: (tokenizer: Odin_Tokenizer, token: Token) -> bool {
            if token.type != .keyword && token.type != .directive then return false;
            prev1, prev2 := tokenizer.last_tokens[0], tokenizer.last_tokens[1];

            if token.type == .keyword {
                if token.keyword != .kw_proc                                       then return false;
                if !(prev1.type == .operation && prev1.operation == .double_colon) then return false;
                if prev2.type != .identifier                                       then return false;
            } else if token.type == .directive {
                if !(token.directive == .directive_force_inline || token.directive == .directive_no_force_inline) then return false;
                if !(prev1.type == .operation && prev1.operation == .double_colon) then return false;
                if prev2.type != .identifier                                       then return false;
            }

            return true;
        }

        if should_highlight_last_token_as_proc(tokenizer, token) {
            memset(tokens.data + tokenizer.last_tokens[0].start, xx Token_Type.function, tokenizer.last_tokens[0].len);
        }
        if should_highlight_second_last_token_as_proc(tokenizer, token) {
            memset(tokens.data + tokenizer.last_tokens[1].start, xx Token_Type.function, tokenizer.last_tokens[1].len);
        }

        // Remember last 3 tokens
        tokenizer.last_tokens[2] = tokenizer.last_tokens[1];
        tokenizer.last_tokens[1] = tokenizer.last_tokens[0];
        tokenizer.last_tokens[0] = token;

        memset(tokens.data + token.start, xx token.type, token.len);
    }

    return .[];
}

tokenize_odin_for_indentation :: (buffer: Buffer) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_odin_tokenizer(buffer);

    while true {
        src := get_next_token(*tokenizer);

        tokenizer.last_tokens[0] = tokenizer.last_tokens[1];
        tokenizer.last_tokens[1] = src;

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
            case .raw_string;           token.type = .maybe_multiline;
            case .eof;                  token.type = .eof;  // to guarantee we always have indentation tokens
            case;                       token.type = .unimportant;
        }

        array_add(*tokens, token);

        if src.type == .eof break;
    }

    return tokens;
}

#scope_file

// A separate tokenizer for the same reasons as with Jai
get_odin_tokenizer :: (using buffer: Buffer, start_offset := -1, count := -1) -> Odin_Tokenizer {
    tokenizer: Odin_Tokenizer;

    tokenizer.buf   = to_string(bytes);
    tokenizer.max_t = bytes.data + bytes.count;
    tokenizer.t     = bytes.data;

    if start_offset >= 0 {
        start_offset = clamp(start_offset, 0, bytes.count - 1);
        count        = clamp(count,        0, bytes.count - 1);
        tokenizer.t += start_offset;
        tokenizer.max_t = tokenizer.t + count;
    }

    return tokenizer;
}

get_next_token :: (using tokenizer: *Odin_Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;

    // Assume ASCII, unless we're in the middle of a string.
    // UTF-8 characters elsewhere are a syntax error.
    char := t.*;

    if is_alpha(char) || char == #char "_" {
        parse_identifier(tokenizer, *token);
    } else if is_digit(char) {
        // Handle number literals that don't look like they are being finished properly
        // For example, 0b10002 will highlight 0b1000 as one number and 2 as another number,
        // but when highlit in editor it looks like one number literal rather than two
        // The solution here is to not highlight more numbers if there are many number tokens in a row
        last_char := (t - 1).*;
        if tokenizer.last_tokens[1].type != .number || (!is_digit(last_char) && last_char != #char "_") {
            parse_number(tokenizer, *token);
        }
        else {
            parse_identifier(tokenizer, *token);
        }
    } else if char == {
        case #char ":";  parse_colon         (tokenizer, *token);
        case #char "=";  parse_equal         (tokenizer, *token);
        case #char "-";  parse_minus         (tokenizer, *token);
        case #char "+";  parse_plus          (tokenizer, *token);
        case #char "*";  parse_asterisk      (tokenizer, *token);
        case #char "<";  parse_less_than     (tokenizer, *token);
        case #char ">";  parse_greater_than  (tokenizer, *token);
        case #char "!";  parse_bang          (tokenizer, *token);
        case #char "&";  parse_ampersand     (tokenizer, *token);
        case #char "|";  parse_pipe          (tokenizer, *token);
        case #char "%";  parse_percent       (tokenizer, *token);
        case #char "~";  parse_tilde         (tokenizer, *token);
        case #char "\t"; parse_tab           (tokenizer, *token);

        case #char "`";  #through;
        case #char "'";  #through;
        case #char "\""; parse_string_literal(tokenizer, *token);

        case #char ".";  parse_period                  (tokenizer, *token);
        case #char "#";  parse_directive               (tokenizer, *token);
        case #char "/";  parse_slash_comment_or_filetag(tokenizer, *token);

        case #char ";";  token.type = .punctuation; token.punctuation = .semicolon; t += 1;
        case #char ",";  token.type = .punctuation; token.punctuation = .comma;     t += 1;
        case #char "^";  token.type = .punctuation; token.punctuation = .caret;     t += 1;
        case #char "?";  token.type = .punctuation; token.punctuation = .question;  t += 1;
        case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;   t += 1;
        case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;   t += 1;
        case #char "(";  token.type = .punctuation; token.punctuation = .l_paren;   t += 1;
        case #char ")";  token.type = .punctuation; token.punctuation = .r_paren;   t += 1;
        case #char "[";  token.type = .punctuation; token.punctuation = .l_bracket; t += 1;
        case #char "]";  token.type = .punctuation; token.punctuation = .r_bracket; t += 1;
        case #char "$";  token.type = .punctuation; token.punctuation = .dollar;    t += 1;
        case #char "@";  token.type = .punctuation; token.punctuation = .attribute; t += 1;

        case #char "\n"; token.type = .punctuation; token.punctuation = .newline;   t += 1;

        case;            token.type = .invalid; t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

parse_identifier :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .identifier;

    auto_release_temp();

    identifier_str := read_identifier_string_tmp(tokenizer);

    // Maybe it's a keyword
    if identifier_str.count <= MAX_KEYWORD_LENGTH {
        kw_token, ok := table_find(*KEYWORD_MAP, identifier_str);
        if ok { token.type = kw_token.type; token.keyword = kw_token.keyword; return; }
    }
}

maybe_parse_attribute :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    attr_str: string;
    attr_str.data  = start_t;
    attr_str.count = token.len;

    if attr_str.count > MAX_ATTRIBUTE_LENGTH then return;
    attr, ok := table_find(*ATTRIBUTES_MAP, attr_str);
    if !ok then return;

    token.type = .attribute;
    token.attribute = attr;
}

parse_number :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .number;

    t += 1;
    if t >= max_t return;

    is_decimal_variant :: inline (c: u8) -> bool {
        return is_digit(c)    || c == #char "." || c == #char "-" ||
               c == #char "e" || c == #char "E" ||
               c == #char "i" || c == #char "j" || c == #char "k";
    }

    if is_decimal_variant(t.*) || t.* == #char "_" {
        seen_decimal_point  := false;
        scientific_notation := false;
        while t < max_t && (is_decimal_variant(t.*) || t.* == #char "_") {
            if t.* == #char "." {
                // Handle 0..<1 / 0..=1 (gets interpreted as a float-period-lessthan-int rather than int-rangeop-int)
                if (t + 1) < max_t && (t + 1).* == #char "." {
                    if (t + 2) < max_t && ((t + 2).* == #char "=" || (t + 2).* == #char "<") {
                        break;
                    }
                }

                // else handle float decimal
                if seen_decimal_point then break;
                seen_decimal_point = true;
            }
            else if t.* == #char "i" || t.* == #char "j" || t.* == #char "k" {
                // Imaginary/quaternion values (2i, 3j, 4k)
                t += 1;
                break;
            }
            else if t.* == #char "e" || t.* == #char "E" {
                // Scientific notation (10e9, 1.0e-34)
                if scientific_notation then break;
                scientific_notation = true;
            }
            else if t.* == #char "-" {
                // Handle scientific notation negative exponent (1.0e-34)
                if !scientific_notation then break;
                if (t - 1).* != #char "e" && (t - 1).* != #char "E" then break;
            }

            t += 1;
        }
    }
    else if t.* == #char "x" || t.* == #char "X" || t.* == #char "h" || t.* == #char "H" {
        // Hex
        t += 1;
        while t < max_t && (is_hex(t.*) || t.* == #char "_") t += 1;
    }
    else if t.* == #char "o" {
        // Octal
        is_octal :: inline (c: u8) -> bool {
            return is_digit(c) && c < #char "8";
        }

        t += 1;
        while t < max_t && (is_octal(t.*) || t.* == #char "_")   t += 1;
    }
    else if t.* == #char "b" {
        // Binary
        t += 1;
        while t < max_t && (t.* == #char "1" || t.* == #char "0" || t.* == #char "_")  t += 1;
    }

    if t > max_t then t = max_t;
}

parse_directive :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .identifier;

    t += 1;
    eat_white_space(tokenizer);  // there may be spaces between the # and the name
    if !is_alpha(t.*) then return;

    auto_release_temp();

    directive_str := read_identifier_string_tmp(tokenizer);

    while t < max_t && is_alnum(t.*) t += 1;
    if t >= max_t return;

    // Check if it's one of the existing directives
    if directive_str.count > MAX_DIRECTIVE_LENGTH return;
    directive, ok := table_find(*DIRECTIVES_MAP, directive_str);
    if ok {
        token.type = .directive;
        token.directive = directive;
    }
}

parse_colon :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .colon;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char ":";  token.operation = .double_colon;  t += 1;
        case #char "=";  token.operation = .colon_equal;   t += 1;
    }
}

parse_equal :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .equal;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";  token.operation = .equal_equal; t += 1;
    }
}

parse_minus :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .minus;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .minus_equal;
            t += 1;
        case #char ">";
            token.operation = .arrow;
            t += 1;
        case #char "-";
            t += 1;
            if t < max_t && t.* == #char "-" {
                token.operation = .triple_dash;
                t += 1;
            } else {
                token.operation = .unknown;  // -- is not a valid token
            }
        case;
            if tokenizer.last_tokens[1].type != .number && is_digit(t.*) {
                parse_number(tokenizer, token);
            }
    }
}

parse_plus :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .plus;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .plus_equal;
            t += 1;
    }
}

parse_asterisk :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .asterisk;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .asterisk_equal;
            t += 1;
    }
}

parse_bang :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .bang;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .bang_equal;
            t += 1;
    }
}

parse_period :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type        = .punctuation;
    token.punctuation = .period;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "?";
            token.type      = .operation;
            token.operation = .period_question;
            t += 1;

        case #char ".";
            token.type      = .operation;
            token.operation = .double_period;

            t += 1;
            if t >= max_t return;

            if t.* == {
                case #char "=";
                    token.operation = .double_period_equal;
                    t += 1;
                case #char "<";
                    token.operation = .double_period_less_than;
                    t += 1;
            }

        case;
            // Maybe it's an enum variant
            if last_tokens[0].type != .identifier && tokenizer.had_white_space_to_skip {
                next_token := peek_next_token(tokenizer);
                if next_token.type == .identifier {
                    token.type = .enum_variant;
                    t = buf.data + next_token.start + next_token.len;  // fast-forward
                }
            }
    }
}

parse_percent :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .percent;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .percent_equal;
            t += 1;

        case #char "%";
            token.operation = .double_percent;
            t += 1;
            if t >= max_t return;

            if t.* == #char "=" {
                token.operation = .double_percent_equal;
                t += 1;
            }
    }
}

parse_tilde :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .tilde;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .tilde_equal;
            t += 1;
    }
}

parse_ampersand :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .ampersand;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .ampersand_equal;
            t += 1;
        case #char "&";
            token.operation = .double_ampersand;
            t += 1;
        case #char "~";
            token.operation = .ampersand_tilde;
            t += 1;
            if t.* == #char "=" {
                token.operation = .ampersand_tilde_equal;
                t += 1;
            }
    }
}

parse_pipe :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .pipe;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .pipe_equal;
            t += 1;
        case #char "|";
            token.operation = .double_pipe;
            t += 1;
            if t.* == #char "=" {
                token.operation = .double_pipe_equal;
                t += 1;
            }
    }
}

parse_less_than :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .less_than;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .less_than_equal;
            t += 1;
        case #char "<";
            token.operation = .double_less_than;
            t += 1;
            if t.* == #char "=" {
                token.operation = .double_less_than_equal;
                t += 1;
            }
    }
}

parse_greater_than :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .greater_than;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .greater_than_equal;
            t += 1;
            if t.* == #char "=" {
                token.operation = .double_greater_than_equal;
                t += 1;
            }
    }
}

parse_tab :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .comment;
    t += 1;
    while t < max_t && t.* == #char "\t"   t += 1;
}

parse_slash_comment_or_filetag :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .slash;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .slash_equal;
            t += 1;
        case #char "/";
            token.type = .comment;
            t += 1;

            if t.* == #char "+" {
                token.type = .string_literal;  // file tag (not worth a separate token type)
                t += 1;
            }

            while t < max_t && t.* != #char "\n" t += 1;
        case #char "*";
            token.type = .multiline_comment;
            t += 1;
            num_open_comments := 0;
            while t + 1 < max_t {
                if t.* == #char "*" && (t + 1).* == #char "/" {
                    if num_open_comments == 0 {
                        t += 2;
                        break;
                    } else {
                        num_open_comments -= 1;
                    }
                } else if t.* == #char "/" && (t + 1).* == #char "*" {
                    num_open_comments += 1;
                    t += 1;
                }
                t += 1;
            }
    }
}

parse_string_literal :: (using tokenizer: *Odin_Tokenizer, token: *Token) {
    delimiter := t.*;   // Could be ' or "

    if delimiter == #char "`" {
        // Handle raw_strings
        token.type = .raw_string;
        t += 1;
        while t < max_t && t.* != delimiter {
            t += 1;
        }
    }
    else {
        // Handle normal strings
        token.type = .string_literal;
        escape_seen := false;

        t += 1;
        while t < max_t && t.* != #char "\n" {
            if t.* == delimiter && !escape_seen break;
            escape_seen = !escape_seen && t.* == #char "\\";
            t += 1;
        }
    }

    if t >= max_t then return;
    t += 1;
}

read_identifier_string_tmp :: (using tokenizer: *Odin_Tokenizer) -> string /* temp */ {
    identifier: [..] u8;
    identifier.allocator = temp;

    array_add(*identifier, t.*);
    t += 1;

    while t < max_t && is_alnum(t.*) {
        array_add(*identifier, t.*);
        t += 1;
    }

    if t >= max_t then t = max_t;
    return cast(string) identifier;
}

Odin_Tokenizer :: struct {
    buf: string;
    max_t:   *u8;
    start_t: *u8;  // cursor when starting parsing new token
    t:       *u8;  // cursor

    last_tokens: [3] Token;  // to retroactively highlight procedures
    had_white_space_to_skip := false;
}

Token :: struct {
    start, len: s32;
    type: Token_Type;

    // Additional info to distinguish between keywords/punctuation
    union {
        keyword:     Keyword;
        punctuation: Punctuation;
        operation:   Operation;
        attribute:   Attribute;
        directive:   Directive;
    }
}

PUNCTUATION :: string.[
    "attribute", "caret", "comma", "dollar", "period", "question", "semicolon",

    "l_paren", "r_paren",
    "l_brace", "r_brace",
    "l_bracket", "r_bracket",

    "newline",  // Odin has optional semicolons, which can confuse the parser
];

// https://github.com/odin-lang/Odin/wiki/Keywords-and-Operators
OPERATIONS :: string.[
    "unknown",
    "equal", "bang", "colon", "colon_equal", "double_colon",
    "plus", "minus", "asterisk", "slash", "percent", "double_percent",
    "ampersand", "pipe", "tilde", "ampersand_tilde", "double_less_than", "double_greater_than",
    "double_ampersand", "double_pipe",
    "plus_equal", "minus_equal", "asterisk_equal", "slash_equal", "percent_equal", "double_percent_equal",
    "ampersand_equal", "pipe_equal", "tilde_equal", "ampersand_tilde_equal", "double_less_than_equal", "double_greater_than_equal",
    "double_ampersand_equal", "double_pipe_equal",
    "arrow", "triple_dash",
    "equal_equal", "bang_equal", "less_than", "greater_than", "less_than_equal", "greater_than_equal",
    "period_question", "double_period", "double_period_equal", "double_period_less_than",
];

KEYWORDS :: string.[
    "align_of", "asm", "auto_cast", "break", "case", "cast", "container_of", "continue", "defer", "distinct", "do", "dynamic",
    "else", "enum", "fallthrough", "for", "foreign", "if", "in", "import", "not_in", "offset_of", "or_else", "or_return",
    "or_break", "or_continue", "package", "proc", "return", "size_of", "struct", "switch", "transmute", "typeid_of",
    "type_info_of", "type_of", "union", "using", "when", "where",
];

// https://odin-lang.org/docs/overview/#basic-types
// https://odin-lang.org/docs/overview/#matrix-type
// https://odin-lang.org/docs/overview/#bit-sets
// https://odin-lang.org/docs/overview/#maps
// https://odin-lang.org/docs/overview/#maybet
TYPE_KEYWORDS :: string.[
    // booleans
    "bool", "b8", "b16", "b32", "b64",

    // integers
    "int",  "i8", "i16", "i32", "i64", "i128",
    "uint", "u8", "u16", "u32", "u64", "u128", "uintptr",
    "byte",  // u8 alias

    // endian specific integers
    "i16le", "i32le", "i64le", "i128le", "u16le", "u32le", "u64le", "u128le", // little endian
    "i16be", "i32be", "i64be", "i128be", "u16be", "u32be", "u64be", "u128be", // big endian

    // floating point numbers
    "f16", "f32", "f64",

    // endian specific floating point numbers
    "f16le", "f32le", "f64le", // little endian
    "f16be", "f32be", "f64be", // big endian

    // complex numbers
    "complex32", "complex64", "complex128",

    // quaternion numbers
    "quaternion64", "quaternion128", "quaternion256",

    // signed 32 bit integer that represents a Unicode code point
    // distinct type to `i32`
    "rune",

    // strings
    "string", "cstring",

    // raw pointer type
    "rawptr",

    // runtime type information specific type
    "typeid", "any",

    // matrix type
    "matrix",

    // map type
    "map",

    // bit set type
    "bit_set",

    // builtin maybe type (similar to Option/Result or std::optional)
    "Maybe",
];

VALUE_KEYWORDS :: string.[
    "context", "nil", "true", "false",
];

// https://odin-lang.org/docs/overview/#attributes
ATTRIBUTES :: string.[
    "private", "builtin", "test",
    "require_results",
    "export", "require", "entry_point_only",
    "link_name", "link_prefix", "link_suffix", "link_section", "linkage",
    "extra_linker_flags", "default_calling_convention", "priority_index",
    "deferred_none", "deferred_in", "deferred_out", "deferred_in_out", "deferred_in_by_ptr", "deferred_out_by_ptr", "deferred_in_out_by_ptr",
    "deprecated", "warning", "disabled", "cold",
    "init", "fini",
    "optimization_mode",
    "static", "thread_local", "rodata",
    "objc_name", "objc_class", "objc_type", "objc_is_class_method",
    "enable_target_feature", "require_target_feature",
    "instrumentation_enter", "instrumentation_exit", "no_instrumentation",
];

// https://odin-lang.org/docs/overview/#directives
DIRECTIVES :: string.[
    "packed", "sparse", "raw_union", "align",
    "shared_nil", "no_nil",
    "type", "subtype",
    "partial", "unroll", "reverse",
    "no_alias", "any_int", "c_vararg", "by_ptr", "const",
    "optional_ok", "optional_allocator_error",
    "bounds_check", "no_bounds_check",
    "force_inline", "no_force_inline",
    "assert", "panic",
    "config", "defined", "exists",
    "location", "caller_location",
    "file", "line", "procedure", "directory", "hash",
    "load", "load_or", "load_directory", "load_hash",
    "soa", "relative", "simd",
];

#insert -> string {
    b: String_Builder;
    init_string_builder(*b);

    define_enum :: (b: *String_Builder, enum_name: string, prefix: string, value_lists: [][] string) {
        print_to_builder(b, "% :: enum u16 {\n", enum_name);
        for values : value_lists {
            for v : values print_to_builder(b, "    %0%;\n", prefix, v);
        }
        print_to_builder(b, "}\n");
    }

    define_enum(*b, "Punctuation", "",           .[PUNCTUATION]);
    define_enum(*b, "Operation",   "",           .[OPERATIONS]);
    define_enum(*b, "Keyword",     "kw_",        .[KEYWORDS, TYPE_KEYWORDS, VALUE_KEYWORDS]);
    define_enum(*b, "Directive",   "directive_", .[DIRECTIVES]);
    define_enum(*b, "Attribute",   "attr_",      .[ATTRIBUTES]);

    return builder_to_string(*b);
}

Keyword_Token :: struct {
    type: Token_Type;
    keyword: Keyword;
}

KEYWORD_MAP :: #run -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    size := 10 * (KEYWORDS.count + TYPE_KEYWORDS.count + VALUE_KEYWORDS.count);
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        for KEYWORDS        append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .keyword, keyword = .kw_%1 });\n", it));
        for TYPE_KEYWORDS   append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .type,    keyword = .kw_%1 });\n", it));
        for VALUE_KEYWORDS  append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .value,   keyword = .kw_%1 });\n", it));
        return builder_to_string(*b);
    }

    return table;
}

ATTRIBUTES_MAP :: #run -> Table(string, Attribute) {
    table: Table(string, Attribute);
    size := 10 * ATTRIBUTES.count;
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        init_string_builder(*b);
        for ATTRIBUTES  print_to_builder(*b, "table_add(*table, \"%1\", .attr_%1);\n", it);
        return builder_to_string(*b);
    }

    return table;
}

DIRECTIVES_MAP :: #run -> Table(string, Directive) {
    table: Table(string, Directive);
    size := 10 * DIRECTIVES.count;
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        init_string_builder(*b);
        for DIRECTIVES  print_to_builder(*b, "table_add(*table, \"%1\", .directive_%1);\n", it);
        return builder_to_string(*b);
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS        { if it.count > result then result = it.count; }
    for TYPE_KEYWORDS   { if it.count > result then result = it.count; }
    for VALUE_KEYWORDS  { if it.count > result then result = it.count; }
    return xx result;
}

MAX_ATTRIBUTE_LENGTH :: #run -> s16 {
    result: s64;
    for ATTRIBUTES { if it.count > result then result = it.count; }
    return xx result;
}

MAX_DIRECTIVE_LENGTH :: #run -> s32 {
    result: s64;
    for DIRECTIVES { if it.count > result then result = it.count; }
    return xx result;
}

eat_white_space :: (using tokenizer: *Odin_Tokenizer) {
    old_t := t;
    while t < max_t {
        if t.* == #char "\n"    then break;  // Make newlines a token
        if !is_white_space(t.*) then break;
        t += 1;
    }
    had_white_space_to_skip = t != old_t;
}

peek_next_token :: (using tokenizer: Odin_Tokenizer, skip_white_space := true) -> Token {
    tokenizer_copy := tokenizer;
    if skip_white_space then eat_white_space(*tokenizer_copy);
    token := get_next_token(*tokenizer_copy);
    return token;
}
