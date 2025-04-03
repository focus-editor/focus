tokenize_cpp :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
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

        memset(tokens.data + token.start, xx token.type, token.len);
    }

    return .[];
}

get_next_cpp_token :: get_next_token;  // export for indent tokenization

#scope_file

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;

    // Look at the first char as if it's ASCII
    char := t.*;

    if is_alpha(char) || char == #char "_" {
        // Parse identifiers which start with an ASCII letter or _
        // We'll look at identifiers which start with UTF8 letters later when we've already checked for more probable possibilities
        parse_identifier(tokenizer, *token);
    } else if is_digit(char) {
        parse_number_c_like(tokenizer, *token);
    } else if char == {
        case #char ":";  parse_colon                 (tokenizer, *token);
        case #char "?";  parse_question              (tokenizer, *token);
        case #char "=";  parse_equal                 (tokenizer, *token);
        case #char "-";  parse_minus                 (tokenizer, *token);
        case #char "+";  parse_plus                  (tokenizer, *token);
        case #char "*";  parse_asterisk              (tokenizer, *token);
        case #char "<";  parse_less_than_or_include  (tokenizer, *token);
        case #char ">";  parse_greater_than          (tokenizer, *token);
        case #char "!";  parse_bang                  (tokenizer, *token);
        case #char "#";  parse_directive             (tokenizer, *token);
        case #char "\""; parse_string_literal        (tokenizer, *token);
        case #char "'";  parse_char_literal          (tokenizer, *token);
        case #char "/";  parse_slash_or_comment      (tokenizer, *token);
        case #char "&";  parse_ampersand             (tokenizer, *token);
        case #char "|";  parse_pipe                  (tokenizer, *token);
        case #char "%";  parse_percent               (tokenizer, *token);
        case #char "^";  parse_caret                 (tokenizer, *token);

        case #char ";";  token.type = .punctuation; token.punctuation = .semicolon; t += 1;
        case #char "\\"; token.type = .punctuation; token.punctuation = .backslash; t += 1;
        case #char ",";  token.type = .punctuation; token.punctuation = .comma;     t += 1;
        case #char ".";  token.type = .punctuation; token.punctuation = .period;    t += 1;
        case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;   t += 1;
        case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;   t += 1;
        case #char "(";  token.type = .punctuation; token.punctuation = .l_paren;   t += 1;
        case #char ")";  token.type = .punctuation; token.punctuation = .r_paren;   t += 1;
        case #char "[";  token.type = .punctuation; token.punctuation = .l_bracket; t += 1;
        case #char "]";  token.type = .punctuation; token.punctuation = .r_bracket; t += 1;

        case #char "~";  token.type = .operation;   token.operation   = .tilde;     t += 1;
        case #char "`";  token.type = .operation;   token.operation   = .backtick;  t += 1;

        case;
            // It could still be an identifier which starts with a UTF8 character
            utf32 := character_utf8_to_utf32(t, max_t - t);
            if is_utf32_letter(utf32) {
                parse_identifier(tokenizer, *token);
            } else {
                token.type = .invalid; t += 1;  // give up
            }
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);

    return token;
}

parse_identifier :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    identifier_str := read_utf8_identifier_string(tokenizer);

    // Maybe it's a keyword
    if identifier_str.count <= MAX_KEYWORD_LENGTH {
        kw_token, ok := table_find(*KEYWORD_MAP, identifier_str);
        if ok { token.type = kw_token.type; token.keyword = kw_token.keyword; return; }
    }
}

parse_colon :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .colon;
    t += 1;
}

parse_question :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .question;
    t += 1;
}

parse_equal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .equal;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";  token.operation = .equal_equal; t += 1;
    }
}

parse_minus :: (using tokenizer: *Tokenizer, token: *Token) {
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
            token.operation = .minus_minus;
            t += 1;
        case;
            if is_digit(t.*) parse_number_c_like(tokenizer, token);
    }
}

parse_plus :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .plus;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .plus_equal;
            t += 1;
        case #char "+";
            token.operation = .plus_plus;
            t += 1;
    }
}

parse_asterisk :: (using tokenizer: *Tokenizer, token: *Token) {
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

parse_less_than_or_include :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .less_than;

    t += 1;
    if t >= max_t return;

    prev_token := cast(*Token) prev_tokens[0];
    if prev_token.type == .directive && prev_token.directive == .di_include {
        // Parse an #include <...> statement
        token.type = .string_literal;
        while t < max_t && t.* != #char "\n" && t.* != #char ">"  t += 1;
        if t >= max_t return;
        t += 1;
        return;
    }

    if t.* == {
        case #char "=";
            token.operation = .less_than_equal;
            t += 1;
        case #char "<";
            token.operation = .double_less_than;
            t += 1;
    }
}

parse_greater_than :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .greater_than;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .greater_than_equal;
            t += 1;
    }
}

parse_bang :: (using tokenizer: *Tokenizer, token: *Token) {
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

parse_directive :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    t += 1;
    eat_white_space(tokenizer);  // there may be spaces between the # and the name
    if t < max_t && !is_alpha(<<t) return;

    directive_str := read_identifier_string(tokenizer);

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

parse_string_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .string_literal;

    escape_seen := false;

    t += 1;
    while t < max_t && t.* != #char "\n" {
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

    t += 1; //
    if t >= max_t || t.* == #char "\n" return;

    if t.* == #char "\\" {
      escape_seen = true;
      t += 1;
      if t >= max_t || t.* == #char "\n" return;
    }

    if t.* == #char "'" && !escape_seen {
      // not escaped single quote without a character
      token.type = .invalid;
      t += 1; // the invalid '
      return;
    }

    t += 1; // the char
    if t >= max_t || t.* == #char "\n" return;

    t += 1; // ending '
}

parse_slash_or_comment :: (using tokenizer: *Tokenizer, token: *Token) {
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
            while t < max_t && t.* != #char "\n" t += 1;
        case #char "*";
            token.type = .multiline_comment;
            t += 1;
            while t + 1 < max_t {
                if t.* == #char "*" && << (t + 1) == #char "/" {
                  t += 2;
                  break;
                }
                t += 1;
            }
    }
}

parse_ampersand :: (using tokenizer: *Tokenizer, token: *Token) {
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
    }
}

parse_pipe :: (using tokenizer: *Tokenizer, token: *Token) {
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
    }
}

parse_percent :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .percent;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .percent_equal;
            t += 1;
    }
}

parse_caret :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .caret;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .caret_equal;
            t += 1;
    }
}

Token :: struct {
    start, len: s32;
    type: Token_Type;

    union {
        keyword:        Keyword;
        punctuation:    Punctuation;
        operation:      Operation;
        directive:      Directive;
    }
}

PUNCTUATION :: string.[
    "semicolon", "backslash", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", "period", "comma",
];

OPERATIONS :: string.[
    "arrow", "bang", "backtick", "pipe", "double_pipe", "pipe_equal", "equal", "equal_equal", "bang_equal", "percent",
    "percent_equal", "less_than", "double_less_than", "less_than_equal", "greater_than", "greater_than_equal", "minus",
    "minus_equal", "minus_minus", "asterisk", "asterisk_equal", "colon", "slash", "plus", "plus_equal", "plus_plus",
    "slash_equal", "ampersand", "double_ampersand", "ampersand_equal", "tilde", "question", "unknown", "caret", "caret_equal",
];

KEYWORDS :: string.[
    "alignas", "alignof", "and", "and_eq", "asm", "auto", "bitand", "bitor", "break", "case", "catch", "class", "compl",
    "concept", "const_cast", "continue", "co_await", "co_return", "co_yield", "decltype", "default", "defined", "delete",
    "do", "dynamic_cast", "else", "enum", "explicit", "export", "for", "friend", "goto", "if", "namespace", "new", "not",
    "not_eq", "operator", "or", "or_eq", "private", "protected", "public", "reinterpret_cast", "requires", "return", "sizeof",
    "static_assert", "static_cast", "struct", "switch", "template", "throw", "try", "typedef", "typeid", "typename", "union",
    "using", "while", "xor", "xor_eq",
];

TYPE_KEYWORDS :: string.[
    // built-in types
    "bool", "char", "char8_t", "char16_t", "char32_t", "double", "float", "int", "long", "short", "void", "wchar_t", "_Bool",
    "_Complex", "_Imaginary",

    // stdint types
    "int8_t", "int16_t", "int32_t", "int64_t", "uint8_t", "uint16_t", "uint32_t", "uint64_t", "int_least8_t", "int_least16_t",
    "int_least32_t", "int_least64_t", "uint_least8_t", "uint_least16_t", "uint_least32_t", "uint_least64_t", "int_fast8_t",
    "int_fast16_t", "int_fast32_t", "int_fast64_t", "uint_fast8_t", "uint_fast16_t", "uint_fast32_t", "uint_fast64_t", "intptr_t",
    "uintptr_t", "intmax_t", "uintmax_t", "wint_t", "size_t", "ssize_t", "ptrdiff_t", "sig_atomic_t", "time_t", "clock_t",

    // some STL types
    "vector", "atomic", "atomic_flag", "array", "map", "unordered_map", "set", "unordered_set", "queue", "deque", "tree", "thread",
];

VALUE_KEYWORDS :: string.[
    "false", "nullptr", "this", "true",
];

MODIFIER_KEYWORDS :: string.[
    "const", "consteval", "constexpr", "constinit", "extern", "final", "inline", "mutable", "noexcept", "override", "register",
    "restrict", "signed", "static", "thread_local", "unsigned", "virtual", "volatile", "_Thread_local",
];

DIRECTIVES :: string.[
    "define", "elif", "elifdef", "elifndef", "else", "end", "endif", "error", "if", "ifdef", "ifndef",
    "include", "line", "pragma", "undef", "warning",
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

    define_enum(*b, "Punctuation",  "",    .[PUNCTUATION]);
    define_enum(*b, "Operation",    "",    .[OPERATIONS]);
    define_enum(*b, "Keyword",      "kw_", .[KEYWORDS, TYPE_KEYWORDS, VALUE_KEYWORDS, MODIFIER_KEYWORDS]);
    define_enum(*b, "Directive",    "di_", .[DIRECTIVES]);

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
        for KEYWORDS           append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .keyword,  keyword = .kw_%1 });\n", it));
        for TYPE_KEYWORDS      append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .type,     keyword = .kw_%1 });\n", it));
        for VALUE_KEYWORDS     append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .value,    keyword = .kw_%1 });\n", it));
        for MODIFIER_KEYWORDS  append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .modifier, keyword = .kw_%1 });\n", it));
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
            print_to_builder(*b, "table_add(*table, \"%1\", .di_%1);\n", it);
        }
        return builder_to_string(*b);
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS          { if it.count > result then result = it.count; }
    for TYPE_KEYWORDS     { if it.count > result then result = it.count; }
    for VALUE_KEYWORDS    { if it.count > result then result = it.count; }
    for MODIFIER_KEYWORDS { if it.count > result then result = it.count; }
    return xx result;
}

MAX_DIRECTIVE_LENGTH :: #run -> s32 {
    result: s64;
    for DIRECTIVES { if it.count > result then result = it.count; }
    return xx result;
}
