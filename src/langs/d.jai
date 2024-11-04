tokenize_d :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
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

get_next_d_token :: get_next_token;  // export for indent tokenization

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
        case #char ":";  parse_colon                      (tokenizer, *token);
        case #char "?";  parse_question                   (tokenizer, *token);
        case #char "=";  parse_equal                      (tokenizer, *token);
        case #char "-";  parse_minus                      (tokenizer, *token);
        case #char "+";  parse_plus                       (tokenizer, *token);
        case #char "*";  parse_asterisk                   (tokenizer, *token);
        case #char "<";  parse_less_than                  (tokenizer, *token);
        case #char ">";  parse_greater_than               (tokenizer, *token);
        case #char "!";  parse_bang                       (tokenizer, *token);
        case #char "\""; parse_string_literal             (tokenizer, *token);
        case #char "`";  parse_backtick_string_literal    (tokenizer, *token);
        case #char "#";  parse_shebang                    (tokenizer, *token);
        case #char "'";  parse_char_literal               (tokenizer, *token);
        case #char "/";  parse_slash_or_comment           (tokenizer, *token);
        case #char "&";  parse_ampersand                  (tokenizer, *token);
        case #char "|";  parse_pipe                       (tokenizer, *token);
        case #char "%";  parse_percent                    (tokenizer, *token);
        case #char "^";  parse_caret                      (tokenizer, *token);
        case #char "~";  parse_tilde                      (tokenizer, *token);

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
        case #char "@";  token.type = .punctuation; token.punctuation = .at;        t += 1;


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

parse_less_than :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .less_than;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .less_than_equal;
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

parse_string_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .string_literal;

    escape_seen := false;

    t += 1;
    while t < max_t {
        if <<t == #char "\"" && !escape_seen break;
        escape_seen = !escape_seen && <<t == #char "\\";
        t += 1;
    }
    if t >= max_t return;

    t += 1;
}

parse_backtick_string_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .string_literal;

    escape_seen := false;

    t += 1;
    while t < max_t {
        if <<t == #char "`" && !escape_seen break;
        escape_seen = !escape_seen && <<t == #char "\\";
        t += 1;
    }
    if t >= max_t return;

    t += 1;
}

parse_shebang :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .string_literal;

    if token.start != 0 {
        // shebangs only occur at start of input
        token.type = .invalid;
    }

    t += 1;
    if t.* != #char "!" {
      // shebang expects a bang
      token.type = .invalid;
    }

    while t < max_t && t.* != #char "\n"  t += 1;
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
        case #char "+";
            token.type = .multiline_comment;
            t += 1;
            num_open_comments := 0;
            while t + 1 < max_t {
                if << t == #char "+" && << (t + 1) == #char "/" {
                    if num_open_comments == 0 {
                        t += 2;
                        break;
                    } else {
                        num_open_comments -= 1;
                    }
                } else if << t == #char "/" && << (t + 1) == #char "+" {
                    num_open_comments += 1;
                    t += 1;
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

parse_tilde :: (using tokenizer: *Tokenizer, token: *Token) {
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

Token :: struct {
    start, len: s32;
    type: Token_Type;

    union {
        keyword:        Keyword;
        punctuation:    Punctuation;
        operation:      Operation;
    }
}

PUNCTUATION :: string.[
    "semicolon", "backslash", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", "period", "comma", "at",
];

OPERATIONS :: string.[
    "arrow", "bang", "backtick", "pipe", "double_pipe", "pipe_equal", "equal", "equal_equal", "bang_equal", "percent",
    "percent_equal", "less_than", "double_less_than", "less_than_equal", "greater_than", "greater_than_equal", "minus",
    "minus_equal", "minus_minus", "asterisk", "asterisk_equal", "colon", "slash", "plus", "plus_equal", "plus_plus",
    "slash_equal", "ampersand", "double_ampersand", "ampersand_equal", "tilde", "tilde_equal", "question", "unknown", "caret", "caret_equal",
];

KEYWORDS :: string.[
    "alias", "align", "asm", "assert", "auto", "break", "case", "cast", "catch", "class",
    "continue", "debug", "default", "delegate", "do", "else", "enum",
    "finally", "for", "foreach", "foreach_reverse", "function", "goto", "if", "import",
    "in", "interface", "invariant", "is", "mixin", "module", "new", "out",
    "override", "pragma", "return", "struct", "super", "switch", "template",
    "this", "throw", "try", "typeid", "typeof", "union", "unittest", "version", "while", "with",
    "__traits", "__vector", "__parameters",
];

TYPE_KEYWORDS :: string.[
    // built-in types
    "bool", "byte", "char", "dchar", "double", "float", "int", "long", "real", "short", "ubyte", "uint", "ulong",
    "ushort", "void", "wchar",

    // some object.d types
    "dstring", "noreturn", "ptrdiff_t", "size_t", "string", "wstring",
];

VALUE_KEYWORDS :: string.[
    "false", "null", "true", "__FILE__", "__FILE_FULL_PATH__", "__MODULE__", "__LINE__", "__FUNCTION__", "__PRETTY_FUNCTION__",
];

MODIFIER_KEYWORDS :: string.[
    "abstract", "const", "deprecated", "export", "extern", "final", "immutable", "inout", "lazy", "nothrow",
    "package", "private", "protected", "public", "pure", "ref", "scope", "shared", "static", "synchronized", "__gshared",
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

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS          { if it.count > result then result = it.count; }
    for TYPE_KEYWORDS     { if it.count > result then result = it.count; }
    for VALUE_KEYWORDS    { if it.count > result then result = it.count; }
    for MODIFIER_KEYWORDS { if it.count > result then result = it.count; }
    return xx result;
}
