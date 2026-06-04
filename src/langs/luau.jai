tokenize_luau :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    auto_release_temp();

    tokenizer := get_luau_tokenizer(buffer, start_offset, count);

    offset_from_buffer := tokenizer.buf.data - buffer.bytes.data;

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof then break;

        prev := tokenizer.last_token;

        if (token.type == .punctuation && token.punctuation == .l_paren) && prev.type == .identifier {
            memset(tokens.data + offset_from_buffer + prev.start, xx Token_Type.function, prev.len);
        }

        if token.type == .identifier && (prev.type == .keyword && prev.keyword == .kw_function) {
            memset(tokens.data + offset_from_buffer + token.start, xx Token_Type.function, token.len);
        } else {
            memset(tokens.data + offset_from_buffer + token.start, xx token.type, token.len);
        }

        tokenizer.last_token = token;
    }

    for tokenizer.interpolation_stack {
        log("interpolating: %", it);
        tokenize_luau(buffer, it.start_offset, it.count);
    }

    return .[];
}

tokenize_luau_for_indentation :: (buffer: Buffer) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_luau_tokenizer(*buffer);

    while true {
        src := get_next_token(*tokenizer);

        token: Indentation_Token;
        token.start = src.start;
        token.len   = src.len;

        if src.type == {
            case .keyword;
                if src.keyword == {
                    case .kw_do;        token.type = .open; token.kind  = .brace;
                    case .kw_then;      token.type = .open; token.kind  = .brace;
                    case .kw_end;       token.type = .close; token.kind = .brace;

                    case .kw_else;
                        // Intentionally adding 2 tokens to get a `}{` effect when indenting
                        token.type = .close; token.kind = .brace;
                        array_add(*tokens, token);
                        token.type = .open; token.kind = .brace;

                    case;               continue;
                }

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

#scope_file
get_luau_tokenizer :: (using buffer: *Buffer, start_offset := -1, count := -1) -> Luau_Tokenizer {
    tokenizer: Luau_Tokenizer;

    tokenizer.buf    = to_string(bytes);
    tokenizer.max_t  = bytes.data + bytes.count;
    tokenizer.t      = bytes.data;
    tokenizer.buffer = buffer;

    if start_offset >= 0 {
        start_offset = clamp(start_offset, 0, bytes.count - 1);
        count        = clamp(count,        0, bytes.count - 1);

        tokenizer.t      += start_offset;
        tokenizer.start_t = tokenizer.t;
        tokenizer.max_t   = tokenizer.t + count;
        tokenizer.buf     = string.{ data = tokenizer.start_t, count = count };
    }

    return tokenizer;
}

get_next_token :: (using tokenizer: *Luau_Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token := Token.{
        start = cast(s32) (t - buf.data),
        type = .eof
    };

    if t >= max_t then return token;
    start_t = t;

    // Assume ASCII, unless we're in the middle of a string.
    // UTF-8 characters elsewhere are a syntax error.
    char := t.*;

    if ascii_is_alpha(char) || char == "_" {
        parse_identifier(tokenizer, *token);
    } else if ascii_is_digit(char) {
        parse_number(tokenizer, *token);
    } else if char == {
        case "'";  #through;
        case "`";  #through;
        case "\""; parse_string_literal(tokenizer, *token);

        case ":";  parse_colon         (tokenizer, *token);
        case "=";  parse_equal         (tokenizer, *token);
        case ">";  parse_greater_than  (tokenizer, *token);
        case "<";  parse_less_than     (tokenizer, *token);
        case "[";  parse_l_bracket     (tokenizer, *token);
        case "-";  parse_minus         (tokenizer, *token);
        case ".";  parse_period        (tokenizer, *token);
        case "/";  parse_slash         (tokenizer, *token);
        case "~";  parse_tilde         (tokenizer, *token);

        case "*"; token.type = .operation;   token.operation   = .asterisk;  t += 1;
        case "&"; token.type = .operation;   token.operation   = .ampersand; t += 1;
        case "^"; token.type = .operation;   token.operation   = .caret;     t += 1;
        case "#"; token.type = .operation;   token.operation   = .hash;      t += 1;
        case "+"; token.type = .operation;   token.operation   = .plus;      t += 1;
        case "%"; token.type = .operation;   token.operation   = .percent;   t += 1;
        case "|"; token.type = .operation;   token.operation   = .pipe;      t += 1;

        case ","; token.type = .punctuation; token.punctuation = .comma;     t += 1;
        case ";"; token.type = .punctuation; token.punctuation = .semicolon; t += 1;
        case "("; token.type = .punctuation; token.punctuation = .l_paren;   t += 1;
        case ")"; token.type = .punctuation; token.punctuation = .r_paren;   t += 1;
        case "{"; token.type = .punctuation; token.punctuation = .l_brace;   t += 1;
        case "}"; token.type = .punctuation; token.punctuation = .r_brace;   t += 1;
        case "]"; token.type = .punctuation; token.punctuation = .r_bracket; t += 1;
        case "@"; token.type = .punctuation; token.punctuation = .attribute; t += 1;
        case "?"; token.type = .punctuation; token.punctuation = .optional;  t += 1;

        case;     token.type = .invalid; t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

parse_identifier :: (using tokenizer: *Luau_Tokenizer, token: *Token) {
    token.type = .identifier;
    ident := read_identifier_string(tokenizer);

    if ident.count > MAX_KEYWORD_LENGTH then return;
    ok, kw_token := table_find(*KEYWORD_MAP, ident);
    if !ok then return;

    if kw_token.type == .builtin_function {
        // builtin functions are always standalone
        if last_token.type == .punctuation && last_token.punctuation == .period then return;
    }

    token.type    = kw_token.type;
    token.keyword = kw_token.keyword;
}

parse_number :: (using tokenizer: *Luau_Tokenizer, token: *Token) {
    token.type = .number;
    t += 1;
    if t >= max_t then return;

    seen_decimal_point  := false;
    scientific_notation := false;
    float_exponent      := false;
    is_hex_number       := false;
    is_binary_number    := false;

    while t < max_t {
        if t.* == "." {
            if seen_decimal_point then break;
            seen_decimal_point = true;
        } else if t.* == "x" || t.* == "X" {
            if is_hex_number then break;
            is_hex_number = true;
        } else if !is_hex_number && (t.* == "e" || t.* == "E") {
            if scientific_notation then break;
            scientific_notation = true;
        } else if !is_hex_number && (t.* == "b" || t.* == "B") {
            if is_binary_number then break;
            is_binary_number = true;
        } else if is_hex_number && (t.* == "p" || t.* == "P") {
            if float_exponent then break;
            float_exponent = true;
        } else if t.* == "+" || t.* == "-" {
            // Handle scientific notation positive/negative exponent (1.0e-34)
            if !scientific_notation && !float_exponent then break;
            if (t - 1).* != "e" && (t - 1).* != "E" && (t - 1).* != "p" && (t - 1).* != "P" then break;
        } else if is_hex_number && !(is_hex(t.*) || t.* == "_") {
            break;
        } else if is_binary_number && !(t.* == "0" || t.* == "1" || t.* == "_") {
            break;
        } else if (!is_hex_number && !is_binary_number) && !(ascii_is_digit(t.*) || t.* == "_") {
            break;
        }

        t += 1;
    }
}

parse_string_literal :: (using tokenizer: *Luau_Tokenizer, token: *Token) {
    delimiter := t.*;   // Could be ' or " or `

    interpolated := delimiter == "`";

    // Handle normal strings
    token.type = .string_literal;
    escape_seen := false;

    t += 1;
    while t < max_t && t.* != "\n" {
        if t.* == delimiter && !escape_seen break;

        // Handle interpolation inside a string
        if interpolated && t.* == "{" && !escape_seen {
            t += 1;

            interpolation_start := t;

            open_count := 0;
            nested_escape_seen := false;

            while t < max_t && t.* != "\n" {
                if t.* == {
                    case "{";
                        open_count += 1;
                    case "}";
                        if !nested_escape_seen {
                            if open_count == 0 {
                                array_add(*interpolation_stack, {
                                    start_offset = interpolation_start - buf.data,
                                    count        = t - interpolation_start
                                });
                                break;
                            } else {
                                open_count -= 1;
                            }
                        }
                }

                nested_escape_seen = !nested_escape_seen && t.* == "\\";
                t += 1;
            }
        }

        escape_seen = !escape_seen && t.* == "\\";
        t += 1;
    }

    t += 1;  // Skip delimiter
}

parse_comment :: (using tokenizer: *Luau_Tokenizer, token: *Token) {
    token.type = .comment;

    t += 1;
    if t >= max_t return;

    if t.* == #char "[" {
        t += 1;
        if t < max_t && (t.* == #char "[" || t.* == #char "=") {
            parse_long_literal(tokenizer);
            return;
        }
    }

    eat_until_newline(tokenizer);
    t += 1;
}

parse_colon :: (using tokenizer: *Luau_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .colon;

    t += 1;
    if t >= max_t return;

    if t.* == #char ":" {
        token.operation = .double_colon;
        t += 1;
    }
}

parse_equal :: (using tokenizer: *Luau_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .equal;

    t += 1;
    if t >= max_t return;

    if t.* == #char "=" {
        token.operation = .double_equal;
        t += 1;
    }
}

parse_greater_than :: (using tokenizer: *Luau_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .greater_than;

    t += 1;
    if t >= max_t return;

    if t.* == #char ">" {
        token.operation = .double_greater_than;
        t += 1;
    }
    else if t.* == #char "=" {
        token.operation = .greater_than_equal;
        t += 1;
    }
}

parse_less_than :: (using tokenizer: *Luau_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .less_than;

    t += 1;
    if t >= max_t return;

    if t.* == #char "<" {
        token.operation = .double_less_than;
        t += 1;
    }
    else if t.* == #char "=" {
        token.operation = .less_than_equal;
        t += 1;
    }
}

parse_l_bracket :: (using tokenizer: *Luau_Tokenizer, token: *Token) {
    token.type        = .punctuation;
    token.punctuation = .l_bracket;

    t += 1;
    if t >= max_t return;

    if t.* == #char "[" || t.* == #char "=" {
        token.type = .string_literal;
        parse_long_literal(tokenizer);
    }
}

parse_minus :: (using tokenizer: *Luau_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .minus;

    t += 1;
    if t >= max_t return;

    if t.* == #char "-" {
        parse_comment(tokenizer, token);
    }
}

parse_period :: (using tokenizer: *Luau_Tokenizer, token: *Token) {
    token.type        = .punctuation;
    token.punctuation = .period;

    t += 1;
    if t >= max_t return;

    if t.* == #char "." {
        token.type      = .operation;
        token.operation = .double_period;

        t += 1;
        if t >= max_t return;

        if t.* == #char "." {
            token.operation = .triple_period;
            t += 1;
        }
    }
}

parse_slash :: (using tokenizer: *Luau_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .slash;

    t += 1;
    if t >= max_t return;

    if t.* == #char "/" {
        token.operation = .double_slash;
        t += 1;
    }
}

parse_tilde :: (using tokenizer: *Luau_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .tilde;

    t += 1;
    if t >= max_t return;

    if t.* == #char "=" {
        token.operation = .tilde_equal;
        t += 1;
    }
}

parse_long_literal :: (using tokenizer: *Luau_Tokenizer) {
    open_bracket_level  := 0;
    close_bracket_level := 0;

    while t.* == #char "=" {
        open_bracket_level += 1;
        t += 1;
    }

    while check_closing := t < max_t {
        if t.* == #char "]" {
            t += 1;

            while t < max_t && t.* == #char "=" {
                close_bracket_level += 1;
                t += 1;
            }

            if close_bracket_level == open_bracket_level && t.* == #char "]" {
                break check_closing;
            }
            else {
                close_bracket_level = 0;
            }
        }

        t += 1;
    }

    t += 1;  // Skip ending ]
}

Luau_Tokenizer :: struct {
    using #as base: Tokenizer;
    last_token: Token;
    buffer:     *Buffer;

    interpolation_stack: [..] struct { start_offset: s64; count: s64; };
    interpolation_stack.allocator = temp;
}

Token :: struct {
    using #as base: Base_Token;

    // Additional info to distinguish between keywords/punctuation
    union {
        keyword:     Keyword;
        punctuation: Punctuation;
        operation:   Operation;
    }
}

KEYWORDS :: string.[
    "and", "break", "do", "else", "elseif", "end", "for",
    "function", "if", "in", "local", "not", "or",
    "repeat", "return", "then", "until", "while",
    "require", "continue", "export", "typeof",
    "const", "read", "write",
];

VALUE_KEYWORDS :: string.[
    "nil", "true", "false",
];

BUILTIN_TYPES :: string.["any", "unknown", "never", "boolean", "number", "string", "thread", "buffer"];

OPERATIONS :: string.[
    "asterisk", "ampersand", "caret", "colon", "equal", "hash",
    "minus", "slash", "plus", "percent", "tilde", "pipe",
    "greater_than", "less_than", "double_less_than", "double_greater_than",
    "double_equal", "tilde_equal", "less_than_equal", "greater_than_equal",
    "double_slash", "double_period", "double_colon", "triple_period",
];

PUNCTUATION :: string.[
    "comma", "period", "semicolon",

    "l_paren", "r_paren",
    "l_brace", "r_brace",
    "l_bracket", "r_bracket",

    "attribute", "optional",
];

BUILTIN_FUNCTIONS :: string.[
    "assert", "collectgarbage", "dofile", "error", "getglobal", "getmetatable", "ipairs",
    "load", "loadfile", "next", "pcall", "pairs", "print", "rawequal", "rawget", "rawset",
    "select", "setfallback", "setglobal", "setmetatable", "tostring", "tonumber", "type",
    "warn", "xpcall",
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
    define_enum(*b, "Keyword",     "kw_",        .[KEYWORDS, VALUE_KEYWORDS, BUILTIN_FUNCTIONS, BUILTIN_TYPES]);

    return builder_to_string(*b);
}

Keyword_Token :: struct {
    type: Token_Type;
    keyword: Keyword;
}

KEYWORD_MAP :: #run -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    size := 10 * (KEYWORDS.count + VALUE_KEYWORDS.count);
    table_resize(*table, size);

    #insert -> string {
        b: String_Builder;
        for KEYWORDS          append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .keyword,          keyword = .kw_%1 });\n", it));
        for VALUE_KEYWORDS    append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .value,            keyword = .kw_%1 });\n", it));
        for BUILTIN_FUNCTIONS append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .builtin_function, keyword = .kw_%1 });\n", it));
        for BUILTIN_TYPES     append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .type            , keyword = .kw_%1 });\n", it));
        return builder_to_string(*b);
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS          { if result < it.count then result = it.count; }
    for VALUE_KEYWORDS    { if result < it.count then result = it.count; }
    for BUILTIN_FUNCTIONS { if result < it.count then result = it.count; }
    return xx result;
}
