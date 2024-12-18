tokenize_swift :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_tokenizer(buffer, start_offset, count);

    last_token: Token; // to retroactively highlight functions

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof  break;

        using tokenizer;
        // Maybe retroactively highlight a function
        if token.type == .punctuation && token.punctuation == .l_paren {
            // Handle "func("
            if last_token.type == .identifier {
                memset(tokens.data + last_token.start, xx Token_Type.function, last_token.len);
            }
        }

        last_token = token;

        memset(tokens.data + token.start, xx token.type, token.len);
    }

    return .[];
}

get_next_swift_token :: get_next_token;  // export for indent tokenization

#scope_file

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t  return token;

    start_t = t;

    // Look at the first char as if it's ASCII (if it isn't, this is just a text line)
    char := t.*;

    if is_alpha(char) || char == #char "_" {
        parse_identifier(tokenizer, *token);
    } else if is_digit(char) {
        parse_number(tokenizer, *token);
    } else if char == {
        case #char "?";  parse_question           (tokenizer, *token);
        case #char "=";  parse_equal              (tokenizer, *token);
        case #char "-";  parse_minus              (tokenizer, *token);
        case #char "+";  parse_plus               (tokenizer, *token);
        case #char "*";  parse_asterisk           (tokenizer, *token);
        case #char "<";  parse_less_than          (tokenizer, *token);
        case #char ">";  parse_greater_than       (tokenizer, *token);
        case #char "!";  parse_bang               (tokenizer, *token);
        case #char "\""; parse_string_literal     (tokenizer, *token);
        case #char "/";  parse_slash_or_comment   (tokenizer, *token);
        case #char "&";  parse_ampersand          (tokenizer, *token);
        case #char "|";  parse_pipe               (tokenizer, *token);
        case #char "%";  parse_percent            (tokenizer, *token);
        case #char "^";  parse_caret              (tokenizer, *token);
        case #char "#";  parse_freestanding_macro (tokenizer, *token);
        case #char "@";  parse_attached_macro     (tokenizer, *token);
        case #char "$";  parse_dollar             (tokenizer, *token);

        case #char ":";  token.type = .punctuation; token.punctuation = .colon;     t += 1;
        case #char ";";  token.type = .punctuation; token.punctuation = .semicolon; t += 1;
        case #char ",";  token.type = .punctuation; token.punctuation = .comma;     t += 1;
        case #char ".";  token.type = .punctuation; token.punctuation = .period;    t += 1;
        case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;   t += 1;
        case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;   t += 1;
        case #char "(";  token.type = .punctuation; token.punctuation = .l_paren;   t += 1;
        case #char ")";  token.type = .punctuation; token.punctuation = .r_paren;   t += 1;
        case #char "[";  token.type = .punctuation; token.punctuation = .l_bracket; t += 1;
        case #char "]";  token.type = .punctuation; token.punctuation = .r_bracket; t += 1;
        case #char "\\"; token.type = .punctuation; token.punctuation = .backslash; t += 1;

        case;           token.type = .invalid; t += 1;
    }

    if t >= max_t  t = max_t;
    token.len = cast(s32) (t - start_t);

    return token;
}

peek_next_token :: (using tokenizer: *Tokenizer, $skip_characters := 0) -> Token {
    tokenizer_copy := tokenizer.*;
    tokenizer_copy.t += skip_characters;
    token := get_next_token(*tokenizer_copy);
    return token;
}

parse_identifier :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    identifier_str := read_utf8_identifier_string(tokenizer);

    // Maybe it's a keyword
    if identifier_str.count <= MAX_KEYWORD_LENGTH {
        kw_token, ok := table_find(*KEYWORD_MAP, identifier_str);
        if ok {
            token.type    = kw_token.type;
            token.keyword = kw_token.keyword;
            return;
        }
    }
}

parse_number :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .number;

    start_char := t.*;

    t += 1;
    if t >=max_t return;

    // Binary
    if t.* == #char "b" {
        t += 1;
        if t >= max_t  return;

        while t < max_t && (t.* == #char "0" || t.* == #char "1") {
            t += 1;
        }

        return;
    }

    // Decimal
    seen_decimal_point := false;
    while t < max_t && (is_digit(t.*) || t.* == #char ".") {
        if t.* == #char "." {
            if seen_decimal_point  break;
            seen_decimal_point = true;
        }

        t += 1;
    }
    if t >= max_t  return;

    // Exponent
    if t.* == #char "e" || t.* == #char "E" {
        t += 1;
        if t >= max_t  return;

        if t.* == #char "+" || t.* == #char "-" {
            t += 1;
            if t >= max_t  return;
        }
    }

    while t < max_t && is_digit(t.*) {
        t += 1;
    }
}

parse_question :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .question;

    t += 1;
    if t >= max_t  return;

    if t.* == #char "?" {
        token.operation = .double_question;
        t += 1;
    }
}

parse_equal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .equal;

    t += 1;
    if t >= max_t  return;

    if t.* == #char "=" {
        token.operation = .double_equal;
        t += 1;
    }
}

parse_minus :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .minus;

    t += 1;
    if t >= max_t  return;

    if t.* == #char "=" {
        token.operation = .minus_equal;
        t += 1;
    }
}

parse_plus :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .plus;

    t += 1;
    if t >= max_t  return;

    if t.* == #char "=" {
        token.operation = .plus_equal;
        t += 1;
    }
}

parse_asterisk :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .asterisk;

    t += 1;
    if t >= max_t  return;

    if t.* == #char "=" {
        token.operation = .asterisk_equal;
        t += 1;
    }
}

parse_less_than :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .less_than;

    t += 1;
    if t >= max_t  return;

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
    if t >= max_t  return;

    if t.* == {
        case #char "=";
            token.operation = .greater_than_equal;
            t += 1;
        case #char ">";
            token.operation = .double_greater_than;
            t += 1;
    }
}

parse_bang :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .bang;

    t += 1;
    if t >= max_t  return;

    if t.* == #char "=" {
        token.operation = .bang_equal;
        t += 1;
    }
}

parse_string_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .string_literal;

    t += 1;
    if t >= max_t  return;

    if t + 1 < max_t {
        // Multiline string
        if t.* == #char "\"" && (t + 1).* == #char "\"" {
            t += 2;
            if t >= max_t  return;

            escape_seen := false;
            while t < max_t {
                if t + 2 < max_t && t.* == #char "\"" && (t + 1).* == #char "\"" && (t + 2).* == #char "\"" && !escape_seen {
                    t += 3;
                    if t >= max_t  return;
                    break;
                }

                escape_seen = !escape_seen && t.* == #char "\\";

                t += 1;
            }

            return;
        }
    }

    escape_seen := false;
    while t < max_t && t.* != #char "\n" {
        if t.* == #char "\"" && !escape_seen  break;
        escape_seen = !escape_seen && t.* == #char "\\";
        t += 1;
    }

    t += 1;
}

parse_slash_or_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .slash;

    t += 1;
    if t >= max_t  return;

    if t.* == {
        case #char "=";
            token.operation = .slash_equal;
            t += 1;
        case #char "/";
            token.operation = .comment;
            t += 1;
            while t < max_t && t.* != #char "\n"  t += 1;
        case #char "*";
            token.type = .multiline_comment;
            t += 1;
            if t >= max_t  return;

            while t + 1 < max_t {
                if t.* == #char "*" && (t + 1).* == #char "/" {
                    t += 2;
                    break;
                }
                t += 1;
            }

            t += 1;
    }
}

parse_ampersand :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .ampersand;

    t += 1;
    if t >= max_t  return;

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
    if t >= max_t  return;

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
    if t >= max_t  return;

    if t.* == #char "=" {
        token.operation = .percent_equal;
        t += 1;
    }
}

parse_caret :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .caret;

    t += 1;
    if t >= max_t  return;

    if t.* == #char "=" {
        token.operation = .caret_equal;
        t += 1;
    }
}

parse_freestanding_macro :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .macro;

    t += 1;
    if t >= max_t  return;

    next_token := peek_next_token(tokenizer);
    if next_token.type == .identifier || next_token.type == .keyword {
        t = buf.data + next_token.start + next_token.len;
    }
}

parse_attached_macro :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .macro;

    t += 1;
    if t >= max_t  return;

    next_token := peek_next_token(tokenizer);
    if next_token.type == .identifier || next_token.type == .keyword {
        t = buf.data + next_token.start + next_token.len;
    }
}

parse_dollar :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .dollar;

    t += 1;
    if t >= max_t  return;

    while t < max_t && is_digit(t.*)  t += 1;
}

Token :: struct {
    start, len: s32;
    type: Token_Type;

    union {
        keyword:     Keyword;
        punctuation: Punctuation;
        operation:   Operation;
    }
}

PUNCTUATION :: string.[
    "semicolon", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", "period", "comma", "colon",
    "backslash",
];

OPERATIONS :: string.[
    "bang",
    "pipe", "double_pipe", "pipe_equal",
    "equal", "double_equal", "bang_equal",
    "percent", "percent_equal",
    "less_than", "double_less_than", "less_than_equal",
    "greater_than", "double_greater_than", "greater_than_equal",
    "minus", "minus_equal", "double_minus",
    "asterisk", "asterisk_equal",
    "slash", "slash_equal",
    "plus", "plus_equal", "double_plus",
    "ampersand", "double_ampersand", "ampersand_equal",
    "question", "double_question",
    "caret", "caret_equal",
    "comment",
    "dollar",
];

KEYWORDS :: string.[
    "associatedtype", "borrowing", "class", "consuming", "deinit", "enum", "extension", "fileprivate", "func", "import",
    "init", "inout", "internal", "let", "nonisolated", "open", "operator", "private", "precedencegroup", "protocol",
    "public", "rethrows", "static", "struct", "subscript", "typealias", "var", "break", "case", "catch", "continue",
    "default", "defer", "do", "else", "fallthrough", "for", "guard", "if", "in", "repeat", "return", "throw", "switch",
    "where", "while", "as", "await", "is", "throws", "try", "associativity", "convenience", "did",
    "dynamic", "final", "get", "indirect", "infix", "lazy", "left", "mutating", "none", "nonmutating", "optional", "override",
    "package", "postfix", "precedence", "prefix", "Protocol", "required", "right", "set", "some", "Type", "unowned", "weak",
    "willSet", "any", "async",
];

TYPE_KEYWORDS :: string.[
    "Any", "Self", "String", "Int", "Int8", "Int16", "Int32", "Int64", "Int128", "Float", "Float16", "Float32", "Float64",
    "Double", "Bool", "Error", "Task", "Void", "Never", "Set", "Dictionary",
];

VALUE_KEYWORDS :: string.[
    "false", "nil", "self", "super", "true",
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

    define_enum(*b, "Punctuation", "",    .[PUNCTUATION]);
    define_enum(*b, "Operation",   "",    .[OPERATIONS]);
    define_enum(*b, "Keyword",     "kw_", .[KEYWORDS, TYPE_KEYWORDS, VALUE_KEYWORDS]);

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

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS       { if it.count > result then result = it.count; }
    for TYPE_KEYWORDS  { if it.count > result then result = it.count; }
    for VALUE_KEYWORDS { if it.count > result then result = it.count; }
    return xx result;
}