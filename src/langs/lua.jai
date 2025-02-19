// Based on https://www.lua.org/manual/5.4/manual.html#3

tokenize_lua :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_lua_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof then break;

        prev := tokenizer.last_token;

        if (token.type == .punctuation && token.punctuation == .l_paren) && prev.type == .identifier {
            memset(tokens.data + prev.start, xx Token_Type.function, prev.len);
        }

        if token.type == .identifier && (prev.type == .keyword && prev.keyword == .kw_function) {
            memset(tokens.data + token.start, xx Token_Type.function, token.len);
        } else {
            memset(tokens.data + token.start, xx token.type, token.len);
        }

        tokenizer.last_token = token;
    }

    return .[];
}

tokenize_lua_for_indentation :: (buffer: Buffer) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_lua_tokenizer(buffer);

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
get_lua_tokenizer :: (using buffer: Buffer, start_offset := -1, count := -1) -> Lua_Tokenizer {
    tokenizer: Lua_Tokenizer;

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

get_next_token :: (using tokenizer: *Lua_Tokenizer) -> Token {
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

    if is_alpha(char) || char == #char "_" {
        parse_identifier(tokenizer, *token);
    } else if is_digit(char) {
        parse_number(tokenizer, *token);
    } else if char == {
        case #char "'";  #through;
        case #char "\""; parse_string_literal(tokenizer, *token);

        case #char ":";  parse_colon         (tokenizer, *token);
        case #char "=";  parse_equal         (tokenizer, *token);
        case #char ">";  parse_greater_than  (tokenizer, *token);
        case #char "<";  parse_less_than     (tokenizer, *token);
        case #char "[";  parse_l_bracket     (tokenizer, *token);
        case #char "-";  parse_minus         (tokenizer, *token);
        case #char ".";  parse_period        (tokenizer, *token);
        case #char "/";  parse_slash         (tokenizer, *token);
        case #char "~";  parse_tilde         (tokenizer, *token);

        case #char "*"; token.type = .operation;   token.operation   = .asterisk;  t += 1;
        case #char "&"; token.type = .operation;   token.operation   = .ampersand; t += 1;
        case #char "^"; token.type = .operation;   token.operation   = .caret;     t += 1;
        case #char "#"; token.type = .operation;   token.operation   = .hash;      t += 1;
        case #char "+"; token.type = .operation;   token.operation   = .plus;      t += 1;
        case #char "%"; token.type = .operation;   token.operation   = .percent;   t += 1;
        case #char "|"; token.type = .operation;   token.operation   = .pipe;      t += 1;

        case #char ","; token.type = .punctuation; token.punctuation = .comma;     t += 1;
        case #char ";"; token.type = .punctuation; token.punctuation = .semicolon; t += 1;
        case #char "("; token.type = .punctuation; token.punctuation = .l_paren;   t += 1;
        case #char ")"; token.type = .punctuation; token.punctuation = .r_paren;   t += 1;
        case #char "{"; token.type = .punctuation; token.punctuation = .l_brace;   t += 1;
        case #char "}"; token.type = .punctuation; token.punctuation = .r_brace;   t += 1;
        case #char "]"; token.type = .punctuation; token.punctuation = .r_bracket; t += 1;

        case;            token.type = .invalid; t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

parse_identifier :: (using tokenizer: *Lua_Tokenizer, token: *Token) {
    token.type = .identifier;
    ident := read_identifier_string(tokenizer);

    if ident.count <= MAX_KEYWORD_LENGTH {
        kw_token, ok := table_find(*KEYWORD_MAP, ident);
        if ok {
            token.type    = kw_token.type;
            token.keyword = kw_token.keyword;
            return;
        }
    }
}

parse_number :: (using tokenizer: *Lua_Tokenizer, token: *Token) {
    token.type = .number;
    t += 1;
    if t >= max_t then return;

    seen_decimal_point  := false;
    scientific_notation := false;
    float_exponent      := false;
    is_hex_number       := false;

    while t < max_t {
        if t.* == #char "." {
            if seen_decimal_point then break;
            seen_decimal_point = true;
        }
        else if t.* == #char "x" || t.* == #char "X" {
            if is_hex_number then break;
            is_hex_number = true;
        }
        else if t.* == #char "e" || t.* == #char "E" {
            if scientific_notation then break;
            scientific_notation = true;
        }
        else if is_hex_number && (t.* == #char "p" || t.* == #char "P") {
            if float_exponent then break;
            float_exponent = true;
        }

        else if t.* == #char "+" || t.* == #char "-" {
            // Handle scientific notation positive/negative exponent (1.0e-34)
            if !scientific_notation && !float_exponent then break;
            if (t - 1).* != #char "e" && (t - 1).* != #char "E" && (t - 1).* != #char "p" && (t - 1).* != #char "P" then break;
        }

        else if is_hex_number && !is_hex(t.*) {
            break;
        }
        else if !is_hex_number && !is_digit(t.*) {
            break;
        }

        t += 1;
    }
}

parse_string_literal :: (using tokenizer: *Lua_Tokenizer, token: *Token) {
    delimiter := t.*;   // Could be ' or "

    // Handle normal strings
    token.type = .string_literal;
    escape_seen := false;

    t += 1;
    while t < max_t && t.* != #char "\n" {
        if t.* == delimiter && !escape_seen break;
        escape_seen = !escape_seen && t.* == #char "\\";
        t += 1;
    }

    t += 1;  // Skip delimiter
}

parse_comment :: (using tokenizer: *Lua_Tokenizer, token: *Token) {
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

parse_colon :: (using tokenizer: *Lua_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .colon;

    t += 1;
    if t >= max_t return;

    if t.* == #char ":" {
        token.operation = .double_colon;
        t += 1;
    }
}

parse_equal :: (using tokenizer: *Lua_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .equal;

    t += 1;
    if t >= max_t return;

    if t.* == #char "=" {
        token.operation = .double_equal;
        t += 1;
    }
}

parse_greater_than :: (using tokenizer: *Lua_Tokenizer, token: *Token) {
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

parse_less_than :: (using tokenizer: *Lua_Tokenizer, token: *Token) {
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

parse_l_bracket :: (using tokenizer: *Lua_Tokenizer, token: *Token) {
    token.type        = .punctuation;
    token.punctuation = .l_bracket;

    t += 1;
    if t >= max_t return;

    if t.* == #char "[" || t.* == #char "=" {
        token.type = .string_literal;
        parse_long_literal(tokenizer);
    }
}

parse_minus :: (using tokenizer: *Lua_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .minus;

    t += 1;
    if t >= max_t return;

    if t.* == #char "-" {
        parse_comment(tokenizer, token);
    }
}

parse_period :: (using tokenizer: *Lua_Tokenizer, token: *Token) {
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

parse_slash :: (using tokenizer: *Lua_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .slash;

    t += 1;
    if t >= max_t return;

    if t.* == #char "/" {
        token.operation = .double_slash;
        t += 1;
    }
}

parse_tilde :: (using tokenizer: *Lua_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .tilde;

    t += 1;
    if t >= max_t return;

    if t.* == #char "=" {
        token.operation = .tilde_equal;
        t += 1;
    }
}

parse_long_literal :: (using tokenizer: *Lua_Tokenizer) {
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

Lua_Tokenizer :: struct {
    using #as base: Tokenizer;
    last_token: Token;
}

Token :: struct {
    start, len: s32;
    type: Token_Type;

    // Additional info to distinguish between keywords/punctuation
    union {
        keyword:     Keyword;
        punctuation: Punctuation;
        operation:   Operation;
    }
}

KEYWORDS :: string.[
    "and", "break", "do", "else", "elseif", "end", "for",
    "function", "goto", "if", "in", "local", "not", "or",
    "repeat", "return", "then", "until", "while",
    "require",
];

VALUE_KEYWORDS :: string.[
    "nil", "true", "false",
];

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
];

// https://www.lua.org/manual/5.4/manual.html#6.1
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
    define_enum(*b, "Keyword",     "kw_",        .[KEYWORDS, VALUE_KEYWORDS, BUILTIN_FUNCTIONS]);

    return builder_to_string(*b);
}

Keyword_Token :: struct {
    type: Token_Type;
    keyword: Keyword;
}

KEYWORD_MAP :: #run -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    size := 10 * (KEYWORDS.count + VALUE_KEYWORDS.count);
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        for KEYWORDS          append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .keyword,          keyword = .kw_%1 });\n", it));
        for VALUE_KEYWORDS    append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .value,            keyword = .kw_%1 });\n", it));
        for BUILTIN_FUNCTIONS append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .builtin_function, keyword = .kw_%1 });\n", it));
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
