highlight_jai_syntax :: (using buffer: *Buffer) {
    tokenizer: Tokenizer = ---;
    tokenizer.buf   = to_string(bytes);
    tokenizer.max_t = bytes.data + bytes.count;
    tokenizer.t     = bytes.data;

    color: Simp.Code_Color;

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        using tokenizer;
        if token.type == .punctuation && token.punctuation == .l_paren {
            // Maybe retroactively highlight a function
            prev        := last_tokens[1];
            before_prev := last_tokens[0];
            if prev.type == .identifier {
                memset(colors.data + prev.start, xx Simp.Code_Color.FUNCTION, prev.len);
            } else if prev.type == .operation && prev.operation == .double_colon && before_prev.type == .identifier {
                memset(colors.data + before_prev.start, xx Simp.Code_Color.FUNCTION, before_prev.len);
            }
        }

        // Remember last 2 tokens
        last_tokens[0] = last_tokens[1];
        last_tokens[1] = token;

        color := COLOR_MAP[token.type];
        memset(colors.data + token.start, xx color, token.len);
    }
}

#scope_file

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    t = eat_white_space(t, max_t);

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
        case #char ":";  parse_colon             (tokenizer, *token);
        case #char "=";  parse_equal             (tokenizer, *token);
        case #char "-";  parse_minus             (tokenizer, *token);
        case #char "+";  parse_plus              (tokenizer, *token);
        case #char "*";  parse_asterisk          (tokenizer, *token);
        case #char "<";  parse_less_than         (tokenizer, *token);
        case #char ">";  parse_greater_than      (tokenizer, *token);
        case #char "!";  parse_bang              (tokenizer, *token);
        case #char "#";  parse_compiler_directive(tokenizer, *token);
        case #char "\""; parse_string_literal    (tokenizer, *token);
        case #char "/";  parse_slash_or_comment  (tokenizer, *token);
        case #char "&";  parse_ampersand         (tokenizer, *token);
        case #char "|";  parse_pipe              (tokenizer, *token);
        case #char "%";  parse_percent           (tokenizer, *token);
        case #char "@";  parse_note              (tokenizer, *token);

        case #char ";";  token.type = .punctuation; token.punctuation = .semicolon; t += 1;
        case #char ",";  token.type = .punctuation; token.punctuation = .comma;     t += 1;
        case #char ".";  token.type = .punctuation; token.punctuation = .period;    t += 1;
        case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;   t += 1;
        case #char "}";  token.type = .punctuation; token.punctuation = .l_brace;   t += 1;
        case #char "(";  token.type = .punctuation; token.punctuation = .l_paren;   t += 1;
        case #char ")";  token.type = .punctuation; token.punctuation = .r_paren;   t += 1;
        case #char "[";  token.type = .punctuation; token.punctuation = .l_bracket; t += 1;
        case #char "]";  token.type = .punctuation; token.punctuation = .r_bracket; t += 1;
        case #char "$";  token.type = .punctuation; token.punctuation = .dollar;    t += 1;
        
        case #char "~";  token.type = .operation;   token.operation   = .tilde;     t += 1;
        case #char "`";  token.type = .operation;   token.operation   = .backtick;  t += 1;

        case;            token.type = .invalid; t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

parse_identifier :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    t += 1;
    while t < max_t && is_alnum(<< t) t += 1;
    if t >= max_t return;

    // Maybe it's a keyword
    identifier_str := to_string(buf.data + token.start, t - start_t);
    if identifier_str.count > MAX_KEYWORD_LENGTH return;
    type, ok := table_find(*KEYWORD_MAP, identifier_str);
    if ok { token.type = type; return; }

    // Check for here-string
    if last_tokens[1].type == .compiler_directive && last_tokens[1].compiler_directive == .directive_string {
        token.type = .here_string;
        end := find_index_from_left(buf, identifier_str, start_index = t - buf.data);
        if end < 0 { t = max_t; return; }
        t = buf.data + end + identifier_str.count;
    }
}

parse_number :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .number;

    t += 1;
    if t >= max_t return;

    if is_digit(<< t) || << t == #char "_" {
        // Decimal
        t += 1;
        seen_decimal_point := false;
        while t < max_t && (is_digit(<< t) || << t == #char "_" || << t == #char ".") {
            if << t == #char "." {
                if seen_decimal_point break;
                seen_decimal_point = true;
            }
            t += 1;
        }
    } else if << t == #char "x" || << t == #char "h" {
        // Hex
        t += 1;
        while t < max_t && (is_hex(<< t) || << t == #char "_") t += 1;

        is_hex :: inline (c: u8) -> bool {
            return is_digit(c) || (c >= #char "a" && c <= #char "f") || (c >= #char "A" && c <= #char "F");
        }
    } else if << t == #char "b" {
        // Binary
        t += 1;
        while t < max_t && (<< t == #char "1" || << t == #char "0" || << t == #char "_") t += 1;
    }
}

parse_compiler_directive :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    t += 1;
    while t < max_t && is_alnum(<< t) t += 1;
    if t >= max_t return;

    // Check if it's one of the existing directives
    identifier_str := to_string(buf.data + token.start + 1, t - start_t - 1);
    if identifier_str.count > MAX_DIRECTIVE_LENGTH return;
    directive, ok := table_find(*COMPILER_DIRECTIVES_MAP, identifier_str);
    if ok {
        token.type = .compiler_directive;
        token.compiler_directive = directive;
    }
}

parse_colon :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .colon;

    t += 1;
    if t >= max_t return;

    if << t == {
        case #char ":";  token.operation = .double_colon;  t += 1;
        case #char "=";  token.operation = .colon_equal;   t += 1;
    }
}

parse_equal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .equal;

    t += 1;
    if t >= max_t return;

    if << t == {
        case #char "=";  token.operation = .equal_equal; t += 1;
    }
}

parse_minus :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .minus;

    t += 1;
    if t >= max_t return;

    if << t == {
        case #char "=";
            token.operation = .minus_equal;
            t += 1;
        case #char ">";
            token.operation = .arrow;
            t += 1;
        case #char "-";
            t += 1;
            if t < max_t && << t == #char "-" {
                token.operation = .triple_dash;
                t += 1;
            } else {
                token.operation = .unknown;  // -- is not a valid token
            }
        case;
            if is_digit(<< t) parse_number(tokenizer, token);
    }
}

parse_plus :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .plus;

    t += 1;
    if t >= max_t return;

    if << t == {
        case #char "=";
            token.operation = .plus_equal;
            t += 1;
    }
}

parse_asterisk :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .asterisk;

    t += 1;
    if t >= max_t return;

    if << t == {
        case #char "=";
            token.operation = .asterisk_equal;
            t += 1;
    }
}

parse_bang :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .bang;

    t += 1;
    if t >= max_t return;

    if << t == {
        case #char "=";
            token.operation = .bang_equal;
            t += 1;
    }
}

parse_percent :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .percent;

    t += 1;
    if t >= max_t return;

    if << t == {
        case #char "=";
            token.operation = .percent_equal;
            t += 1;
    }
}

parse_note :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .punctuation;
    token.punctuation = .note;

    t += 1;
    while t < max_t && is_alnum(<< t) t += 1;
    if t >= max_t return;
}

parse_ampersand :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .ampersand;

    t += 1;
    if t >= max_t return;

    if << t == {
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

    if << t == {
        case #char "=";
            token.operation = .pipe_equal;
            t += 1;
        case #char "|";
            token.operation = .double_pipe;
            t += 1;
    }
}

parse_less_than :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .less_than;

    t += 1;
    if t >= max_t return;

    if << t == {
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

    if << t == {
        case #char "=";
            token.operation = .greater_than_equal;
            t += 1;
    }
}

parse_slash_or_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .slash;

    t += 1;
    if t >= max_t return;

    if << t == {
        case #char "=";
            token.operation = .slash_equal;
            t += 1;
        case #char "/";
            token.type = .comment;
            t += 1;
            while t < max_t && << t != #char "\n" t += 1;
        case #char "*";
            token.type = .multiline_comment;
            t += 1;
            num_open_comments := 0;
            while t + 1 < max_t {
                if << t == #char "*" && << (t + 1) == #char "/" {
                    if num_open_comments == 0 {
                        t += 2;
                        break;
                    } else {
                        num_open_comments -= 1;
                    }
                } else if << t == #char "/" && << (t + 1) == #char "*" {
                    num_open_comments += 1;
                    t += 1;
                }
                t += 1;
            }
    }
}

parse_string_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .string_literal;

    t += 1;
    while t < max_t && !(<< t == #char "\"" && << (t-1) != #char "\\") && << t != #char "\n" { t += 1; }
    if t >= max_t return;

    t += 1;
}

Tokenizer :: struct {
    buf: string;
    max_t:   *u8;
    start_t: *u8;  // cursor when starting parsing new token
    t:       *u8;  // cursor

    last_tokens: [2] Token;  // to retroactively highlight functions
}

Token :: struct {
    start, len: s32;
    type: Type;

    // Additional info to distinguish between keywords/punctuation
    union {
        keyword:            Keyword;
        punctuation:        Punctuation;
        operation:          Operation;
        compiler_directive: Compiler_Directive;
    }

    Type :: enum u16 {
        eof;

        identifier;
        string_literal;
        here_string;
        number;
        comment;
        multiline_comment;
        operation;
        punctuation;
        modifier_keyword;
        keyword;
        type_keyword;
        value_keyword;
        compiler_directive;
        invalid;
    }
}

// Must match the order of the types in the enum
COLOR_MAP :: Simp.Code_Color.[
    .COMMENT,       // eof - obviously not used
    .DEFAULT,       // identifier
    .STRING,        // string_literal
    .STRING,        // here_string
    .VALUE,         // number
    .COMMENT,       // comment
    .COMMENT,       // multiline_comment
    .OPERATION,     // operation
    .PUNCTUATION,   // punctuation
    .KEYWORD,       // keyword
    .KEYWORD,       // modifier_keyword
    .TYPE,          // type_keyword
    .VALUE_KEYWORD, // value_keyword
    .KEYWORD,       // compiler_directive
    .ERROR,         // invalid
];

PUNCTUATION :: string.[
    "dollar", "semicolon", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", 
    "period", "comma", "note",
];

OPERATIONS :: string.[
    "arrow", "bang", "backtick", "pipe", "double_pipe", "pipe_equal", "equal", "equal_equal", "bang_equal", 
    "percent", "percent_equal", "less_than", "double_less_than", "less_than_equal", "greater_than", "greater_than_equal", 
    "minus", "minus_equal", "triple_dash", "asterisk", "asterisk_equal", "colon", "colon_equal", "double_colon", "slash",
    "plus", "plus_equal", "slash_equal", "ampersand", "double_ampersand", "ampersand_equal", "tilde", "unknown",
];

KEYWORDS :: string.[
    "align_of", "break", "case", "cast", "code_of", "continue", "defer", "else", "enum", "enum_flags", "for",
    "if", "ifx", "is_constant", "inline", "push_context", "return", "size_of", "struct", "then", "type_info", "type_of",
    "union", "using", "while", "xx", "operator",
];

TYPE_KEYWORDS :: string.[
    "__reg", "bool", "float", "float32", "float64", "int", "reg", "s16", "s32", "s64", "s8", "string",
    "u16", "u32", "u64", "u8", "void",
];

VALUE_KEYWORDS :: string.[
    "context", "it", "it_index", "null", "true", "false",
];

COMPILER_DIRECTIVES :: string.[
    "add_context", "align", "as", "asm", "assert", "bake_arguments", "bake_constants", "bytes", "c_call", "caller_code",
    "caller_location", "char", "code", "compiler", "complete", "cpp_method", "cpp_return_type_is_non_pod", "deprecated",
    "dump", "dynamic_specialize", "elsewhere", "expand", "file", "filepath", "foreign", "foreign_library",
    "foreign_system_library", "if", "ifx", "import", "insert", "insert_internal", "intrinsic", "line", "load",
    "location", "modify", "module_parameters", "must", "no_abc", "no_alias", "no_context", "no_padding", "no_reset",
    "place", "placeholder", "poke_name", "procedure_of_call", "program_export", "run", "runtime_support",
    "scope_export", "scope_file", "scope_module", "specified", "string", "symmetric", "this", "through", "type",
    "type_info_no_size_complaint", "type_info_none", "type_info_procedures_are_void_pointers",
];

// TODO: implement
MODIFIERS :: string.[
    "isa", "distinct",  // type
    "only", "except", "map",  // using
    "no_check", "truncate",  // cast
    "no_dll",  // foreign_library
    "file", "dir", "string",  // import
    "scope",  // insert
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

    define_enum(*b, "Punctuation",        "",           .[PUNCTUATION]);
    define_enum(*b, "Operation",          "",           .[OPERATIONS]);
    define_enum(*b, "Keyword",            "kw_",        .[KEYWORDS, TYPE_KEYWORDS, VALUE_KEYWORDS]);
    define_enum(*b, "Compiler_Directive", "directive_", .[COMPILER_DIRECTIVES]);

    return builder_to_string(*b);
}

KEYWORD_MAP :: #run -> Table(string, Token.Type) {
    table: Table(string, Token.Type);
    size := 2 * (KEYWORDS.count + TYPE_KEYWORDS.count + VALUE_KEYWORDS.count);
    init(*table, size);

    for KEYWORDS        table_add(*table, it, .keyword);
    for TYPE_KEYWORDS   table_add(*table, it, .type_keyword);
    for VALUE_KEYWORDS  table_add(*table, it, .value_keyword);

    return table;
}

COMPILER_DIRECTIVES_MAP :: #run -> Table(string, Compiler_Directive) {
    table: Table(string, Compiler_Directive);
    size := 2 * COMPILER_DIRECTIVES.count;
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        init_string_builder(*b);
        for COMPILER_DIRECTIVES {
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
    for COMPILER_DIRECTIVES { if it.count > result then result = it.count; }
    return xx result;
}


eat_white_space :: inline (start: *u8, max_t: *u8) -> *u8 {
    t := start;
    while t < max_t {
        is_whitespace := inline is_space(<< t);
        if !is_whitespace break;
        t += 1;
    }
    return t;
}


#import "Hash_Table";
