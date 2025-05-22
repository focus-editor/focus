tokenize_zig :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_tokenizer(buffer, start_offset, count);

    // Allocate temporary space for tracking one previous token
    tokenizer.prev_tokens[0] = New(Token,, temp);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        using tokenizer;

        prev_token := cast(*Token) prev_tokens[0];

        // Maybe retroactively highlight a function
        if token.type == .punctuation && token.punctuation == .l_paren {
            // Handle "func("
            if prev_token.type == .identifier {
                memset(tokens.data + prev_token.start, xx Token_Type.function, prev_token.len);
            }
        }

        prev_token.* = token;

        highlight_token(buffer, token);
    }

    return .[];
}

get_next_zig_token :: get_next_token;  // export for indent tokenization

#scope_file

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;

    // Assume ASCII, unless we're in the middle of a string.
    // UTF-8 characters elsewhere are a syntax error.
    char := << t;

    if is_alpha(char) || char == #char "_" {
        parse_identifier(tokenizer, *token);
    } else if is_digit(char) {
        parse_number(tokenizer, *token);
    } else if char == {
        case #char "!";  token.type = .operation; token.operation = .bang;                t += 1;
        case #char "=";  token.type = .operation; token.operation = .equal;               t += 1;
        case #char "%";  token.type = .operation; token.operation = .percent;             t += 1;
        case #char "^";  token.type = .operation; token.operation = .caret;               t += 1;
        case #char "+";  token.type = .operation; token.operation = .plus;                t += 1;
        case #char "-";  token.type = .operation; token.operation = .minus;               t += 1;
        case #char "*";  token.type = .operation; token.operation = .asterisk;            t += 1;
        case #char "&";  token.type = .operation; token.operation = .ampersand;           t += 1;
        case #char "<";  token.type = .operation; token.operation = .angle_bracket_left;  t += 1;
        case #char ">";  token.type = .operation; token.operation = .angle_bracket_right; t += 1;
        case #char "~";  token.type = .operation; token.operation = .tilde;               t += 1;
        case #char "?";  token.type = .operation; token.operation = .question_mark;       t += 1;

        case #char ".";  parse_period             (tokenizer, *token);
        case #char "\""; parse_string_literal     (tokenizer, *token);
        case #char "\\"; parse_multiline_string   (tokenizer, *token);
        case #char "'";  parse_char_literal       (tokenizer, *token);
        case #char "@";  parse_directive (tokenizer, *token);
        case #char "/";  parse_slash_or_comment   (tokenizer, *token);

        case #char ":";  token.type = .punctuation; token.punctuation = .colon;     t += 1;
        case #char ";";  token.type = .punctuation; token.punctuation = .semicolon; t += 1;
        case #char ",";  token.type = .punctuation; token.punctuation = .comma;     t += 1;
        case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;   t += 1;
        case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;   t += 1;
        case #char "(";  token.type = .punctuation; token.punctuation = .l_paren;   t += 1;
        case #char ")";  token.type = .punctuation; token.punctuation = .r_paren;   t += 1;
        case #char "[";  token.type = .punctuation; token.punctuation = .l_bracket; t += 1;
        case #char "]";  token.type = .punctuation; token.punctuation = .r_bracket; t += 1;
        case #char "|";  token.type = .punctuation; token.punctuation = .pipe;      t += 1;

        case;            token.type = .invalid; t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

parse_identifier :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    identifier_str := read_identifier_string(tokenizer);

    // Maybe it's a keyword
    if identifier_str.count <= MAX_KEYWORD_LENGTH {
        kw_token, ok := table_find(*KEYWORD_MAP, identifier_str);
        if ok { token.type = kw_token.type; token.keyword = kw_token.keyword; return; }
    }

    // Any identifier starting with a capital letter is a type (not sure if that's still a thing)
    if identifier_str && identifier_str[0] >= #char "A" && identifier_str[0] <= #char "Z" then token.type = .type;
}

parse_number :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .number;

    t += 1;
    if t >= max_t return;

    is_decimal_variant :: inline (c: u8) -> bool {
        return is_digit(c) || c == #char "." || c == #char "-" || c == #char "e" || c == #char "E";
    }

    if is_decimal_variant(t.*) || t.* == #char "_" {
        // Decimal
        seen_decimal_point  := false;
        scientific_notation := false;
        while t < max_t && (is_decimal_variant(t.*) || t.* == #char "_") {
            if t.* == #char "." {
                // Handle 0..1 (gets interpreted as a float-period-int rather than int-rangeop-int)
                if (t + 1) < max_t && (t + 1).* == #char "." {
                    break;
                }

                // else handle float decimal
                if seen_decimal_point then break;
                seen_decimal_point = true;
            }
            else if t.* == #char "e" || t.* == #char "E" {
                // Scientific notation (3.5e2, 1.0e-34)
                // Only works if there is a decimal point
                if scientific_notation || !seen_decimal_point then break;
                scientific_notation = true;
            }
            else if t.* == #char "-" {
                // Handle negative exponent in scientific notation (1.0e-34)
                if !scientific_notation then break;
                if (t - 1).* != #char "e" && (t - 1).* != #char "E" then break;
            }

            t += 1;
        }
    } else if t.* == #char "x" || t.* == #char "h" {
        // Hex
        t += 1;
        while t < max_t && (is_hex(t.*) || t.* == #char "_") t += 1;
    } else if t.* == #char "b" {
        // Binary
        t += 1;
        while t < max_t && (t.* == #char "1" || t.* == #char "0" || t.* == #char "_") t += 1;
    }
}

parse_directive :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    t += 1;
    if t >= max_t return;

    if t.* == #char "\"" {
        // Handle @"..."
        t += 1;
        while t < max_t && t.* != #char "\"" && t.* != #char "\n" {
            t += 1;
        }
        t += 1;
    } else {
        // Parse
        directive_str := read_identifier_string(tokenizer);

        if t >= max_t return;

        // Check if it's one of the existing directives
        if directive_str.count > MAX_DIRECTIVE_LENGTH return;
        directive, ok := table_find(*DIRECTIVES_MAP, directive_str);
        if ok {
            token.type = .directive;
            token.directive = directive;
        }
    }
}

parse_period :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type        = .punctuation;
    token.punctuation = .period;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char ".";
            token.type      = .operation;
            token.operation = .ellipsis2;
            t += 1;
            if t >= max_t return;
            if t.* == #char "." {
                token.operation = .ellipsis3;
                t += 1;
            }

        case #char "*";
            token.type      = .operation;
            token.operation = .period_asterisk;
            t += 1;

        case;
            // Maybe it's an enum variant
            prev_token := cast(*Token) prev_tokens[0];
            if prev_token.type != .identifier && tokenizer.had_white_space_to_skip {
                next_token := peek_next_token(tokenizer, skip_white_space = true, Token, get_next_token);
                if next_token.type == .identifier {
                    token.type = .enum_variant;
                    t = buf.data + next_token.start + next_token.len;  // fast-forward
                }
            }
    }
}

parse_slash_or_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .slash;

    t += 1;
    if t >= max_t return;

    if t.* == #char "/" {
        token.type = .comment;
        t += 1;
        while t < max_t && << t != #char "\n" t += 1;
    }
}

parse_multiline_string :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .invalid;

    t += 1;
    if t >= max_t return;

    if t.* == #char "\\" {
        token.type = .multiline_string;
        t += 1;
        while t < max_t && << t != #char "\n" t += 1;
    }
}

parse_string_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .string_literal;

    escape_seen := false;

    t += 1;
    while t < max_t && << t != #char "\n" {
        if <<t == #char "\"" && !escape_seen break;
        escape_seen = !escape_seen && <<t == #char "\\";
        t += 1;
    }
    if t >= max_t return;

    t += 1;
}

parse_char_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .char_literal;

    escape_seen := false;

    t += 1;
    while t < max_t && << t != #char "\n" {
        if <<t == #char "'" && !escape_seen break;
        escape_seen = !escape_seen && <<t == #char "\\";
        t += 1;
    }
    if t >= max_t return;

    t += 1;
}

Token :: struct {
    using #as base: Base_Token;

    // Additional info to distinguish between keywords/punctuation
    union {
        keyword:        Keyword;
        punctuation:    Punctuation;
        operation:      Operation;
        directive:      Directive;
    }
}

PUNCTUATION :: string.[
    "colon", "semicolon", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket",
    "period", "comma", "pipe",
];

OPERATIONS :: string.[
    "bang", "equal", "percent", "period_asterisk", "ellipsis2", "ellipsis3", "caret",
    "plus", "minus", "asterisk", "colon", "slash", "ampersand", "question_mark",
    "angle_bracket_left", "angle_bracket_right", "tilde",
];

KEYWORDS :: string.[
    "addrspace", "align", "allowzero", "and", "anyframe", "anytype", "asm", "async", "await", "break", "callconv", "catch",
    "comptime", "const", "continue", "defer", "else", "enum", "errdefer", "error", "export", "extern", "fn", "for", "if",
    "inline", "noalias", "noinline", "nosuspend", "opaque", "or", "orelse", "packed", "pub", "resume", "return", "linksection",
    "struct", "suspend", "switch", "test", "threadlocal", "try", "union", "unreachable", "usingnamespace", "var", "volatile", "while",
];

TYPE_KEYWORDS :: string.[
    "i8", "u8", "i16", "u16", "i32", "u32", "i64", "u64", "i128", "u128", "isize", "usize",
    "c_char", "c_short", "c_ushort", "c_int", "c_uint", "c_long", "c_ulong", "c_longlong", "c_ulonglong",
    "f16", "f32", "f64", "f80", "f128",
    "bool", "anyopaque", "void", "noreturn", "type", "anyerror", "comptime_int", "comptime_float",
];

VALUE_KEYWORDS :: string.[
    "null", "true", "false", "undefined",
];

DIRECTIVES :: string.[
    "addrSpaceCast", "addWithOverflow", "alignCast", "alignOf", "as", "atomicLoad", "atomicRmw", "atomicStore",
    "bitCast", "bitOffsetOf", "bitSizeOf", "breakpoint", "mulAdd", "byteSwap", "bitReverse", "offsetOf", "call",
    "cDefine", "cImport", "cInclude", "clz", "cmpxchgStrong", "cmpxchgWeak", "compileError", "compileLog",
    "constCast", "ctz", "cUndef", "cVaArg", "cVaCopy", "cVaEnd", "cVaStart", "divExact", "divFloor", "divTrunc",
    "embedFile", "enumFromInt", "errorFromInt", "errorName", "errorReturnTrace", "errorCast", "export", "extern",
    "fence", "field", "fieldParentPtr", "floatCast", "floatFromInt", "frameAddress", "hasDecl", "hasField", "import",
    "inComptime", "intCast", "intFromBool", "intFromEnum", "intFromError", "intFromFloat", "intFromPtr", "max",
    "memcpy", "memset", "min", "wasmMemorySize", "wasmMemoryGrow", "mod", "mulWithOverflow", "panic", "popCount",
    "prefetch", "ptrCast", "ptrFromInt", "rem", "returnAddress", "select", "setAlignStack", "setCold",
    "setEvalBranchQuota", "setFloatMode", "setRuntimeSafety", "shlExact", "shlWithOverflow", "shrExact", "shuffle",
    "sizeOf", "splat", "reduce", "src", "sqrt", "sin", "cos", "tan", "exp", "exp2", "log", "log2", "log10", "abs",
    "floor", "ceil", "trunc", "round", "subWithOverflow", "tagName", "This", "trap", "truncate", "Type", "typeInfo",
    "typeName", "TypeOf", "unionInit", "Vector", "volatileCast", "workGroupId", "workGroupSize", "workItemId",
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

    define_enum(*b, "Punctuation",  "",           .[PUNCTUATION]);
    define_enum(*b, "Operation",    "",           .[OPERATIONS]);
    define_enum(*b, "Keyword",      "kw_",        .[KEYWORDS, TYPE_KEYWORDS, VALUE_KEYWORDS]);
    define_enum(*b, "Directive",    "directive_", .[DIRECTIVES]);

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
        for KEYWORDS        append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .keyword,       keyword = .kw_%1 });\n", it));
        for TYPE_KEYWORDS   append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .type,  keyword = .kw_%1 });\n", it));
        for VALUE_KEYWORDS  append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .value, keyword = .kw_%1 });\n", it));
        return builder_to_string(*b);
    }

    return table;
}

DIRECTIVES_MAP :: #run -> Table(string, Directive) {
    table: Table(string, Directive);
    size := 2 * DIRECTIVES.count;
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        init_string_builder(*b);
        for DIRECTIVES {
            print_to_builder(*b, "table_add(*table, \"%1\", .directive_%1);\n", it);
        }
        return builder_to_string(*b);
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS       { if it.count > result then result = it.count; }
    for TYPE_KEYWORDS  { if it.count > result then result = it.count; }
    for VALUE_KEYWORDS { if it.count > result then result = it.count; }
    return xx result;
}

MAX_DIRECTIVE_LENGTH :: #run -> s32 {
    result: s64;
    for DIRECTIVES { if it.count > result then result = it.count; }
    return xx result;
}
