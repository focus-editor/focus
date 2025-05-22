// NOTE: lots of copypasta from Python

tokenize_renpy :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_tokenizer(buffer, start_offset, count);

    last_token: Token;

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        using tokenizer;

        // Maybe highlight a function
        if token.type == .punctuation && token.punctuation == .l_paren && last_token.type == .identifier {
            memset(tokens.data + last_token.start, xx Token_Type.function, last_token.len);
        }

        last_token = token;

        highlight_token(buffer, token);
    }

    return .[];
}

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
        case #char ":";  parse_colon             (tokenizer, *token);
        case #char "=";  parse_equal             (tokenizer, *token);
        case #char "-";  parse_minus             (tokenizer, *token);
        case #char "+";  parse_plus              (tokenizer, *token);
        case #char "*";  parse_asterisk          (tokenizer, *token);
        case #char "<";  parse_less_than         (tokenizer, *token);
        case #char ">";  parse_greater_than      (tokenizer, *token);
        case #char "!";  parse_bang              (tokenizer, *token);
        case #char "@";  parse_decorator         (tokenizer, *token);
        case #char "/";  parse_slash             (tokenizer, *token);
        case #char "\""; parse_string_literal    (tokenizer, *token);
        case #char "'";  parse_string_literal    (tokenizer, *token, #char "'");
        case #char "\t"; parse_tab               (tokenizer, *token);
        case #char "#";  parse_comment           (tokenizer, *token);
        case #char "&";  parse_ampersand         (tokenizer, *token);
        case #char "|";  parse_pipe              (tokenizer, *token);
        case #char "%";  parse_percent           (tokenizer, *token);
        case #char "^";  parse_caret             (tokenizer, *token);

        case #char ";";  token.type = .punctuation; token.punctuation = .semicolon; t += 1;
        case #char ",";  token.type = .punctuation; token.punctuation = .comma;     t += 1;
        case #char ".";  token.type = .punctuation; token.punctuation = .period;    t += 1;
        case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;   t += 1;
        case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;   t += 1;
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

    identifier_str := read_identifier_string(tokenizer);

    // Maybe it's a keyword
    if identifier_str.count <= MAX_KEYWORD_LENGTH {
        kw_token, ok := table_find(*KEYWORD_MAP, identifier_str);
        if ok { token.type = kw_token.type; token.keyword = kw_token.keyword; return; }
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
    } else if << t == #char "b" {
        // Binary
        t += 1;
        while t < max_t && (<< t == #char "1" || << t == #char "0" || << t == #char "_") t += 1;
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

parse_decorator :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .decorator;

    t += 1;
    eat_white_space(tokenizer);
    read_identifier_string(tokenizer);
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

parse_caret :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .caret;

    t += 1;
    if t >= max_t return;

    if << t == {
        case #char "=";
            token.operation = .caret_equal;
            t += 1;
    }
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

parse_slash :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .slash;

    t += 1;
    if t >= max_t return;

    if << t == {
        case #char "=";
            token.operation = .slash_equal;
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

parse_tab :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .comment;
    t += 1;
    while t < max_t && << t == #char "\t" t += 1;
}

parse_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .comment;
    t += 1;
    while t < max_t && << t != #char "\n" t += 1;
}

parse_string_literal :: (using tokenizer: *Tokenizer, token: *Token, quote := #char "\"") {
    if t + 2 <= max_t && (t+1).* == quote && (t+2).* == quote {
        token.type = .multiline_string;

        end_str := ifx quote == #char "'" then "'''" else "\"\"\"";
        end := find_index_from_left(buf, end_str, start_index = t - buf.data + 2);
        if end < 0 { t = max_t; return; }

        t = buf.data + end + end_str.count;
    } else {
        token.type = .string_literal;

        escape_seen := false;

        t += 1;
        while t < max_t {
            if <<t == quote && !escape_seen break;
            escape_seen = !escape_seen && <<t == #char "\\";
            t += 1;
        }
        if t >= max_t return;

        t += 1;
    }
}

Token :: struct {
    using #as base: Base_Token;

    // Additional info to distinguish between keywords/punctuation
    union {
        keyword:            Keyword;
        punctuation:        Punctuation;
        operation:          Operation;
    }
}

PUNCTUATION :: string.[
    "dollar", "semicolon", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", "period", "comma",
];

OPERATIONS :: string.[
    "arrow", "bang", "backtick", "pipe", "double_pipe", "pipe_equal", "equal", "equal_equal", "bang_equal",
    "percent", "percent_equal", "less_than", "double_less_than", "less_than_equal", "greater_than", "greater_than_equal",
    "minus", "minus_equal", "triple_dash", "asterisk", "asterisk_equal", "colon", "colon_equal", "double_colon", "slash",
    "plus", "plus_equal", "slash_equal", "ampersand", "double_ampersand", "ampersand_equal", "tilde", "unknown",
    "caret", "caret_equal", "decorator",
];

KEYWORDS :: string.[
    "await", "else", "import", "pass", "break", "except", "in", "raise", "class", "finally", "is", "return", "and", "continue",
    "for", "lambda", "try", "as", "def", "from", "nonlocal", "while", "assert", "del", "global", "not", "with", "async",
    "elif", "if", "or", "yield",
];

TYPE_KEYWORDS :: string.[
    // These conflict with builtin functions. Leave for now
    // "list", "set", "tuple", "object", "frozenset", "dict",
];

BUILTIN_FUNCTIONS :: string.[
    "abs", "aiter", "all", "anext", "any", "ascii", "bin", "bool", "breakpoint", "bytearray", "bytes", "callable", "chr",
    "classmethod", "compile", "complex", "delattr", "dict", "dir", "divmod", "enumerate", "eval", "exec", "filter", "float",
    "format", "frozenset", "getattr", "globals", "hasattr", "hash", "help", "hex", "id", "input", "int", "isinstance", "issubclass",
    "iter", "len", "list", "locals", "map", "max", "memoryview", "min", "next", "object", "oct", "open", "ord", "pow", "print",
    "property", "range", "repr", "reversed", "round", "set", "setattr", "slice", "sorted", "staticmethod", "str", "sum",
    "super", "tuple", "type", "vars", "zip", "__import__",

    // RENPY
    "dissolve", "fade", "fadein", "fadeout", "crossfade", "wipe", "slide", "pixellate", "page_flip", "page_roll", "spin",
    "squeeze", "zoom", "matrix", "ripple", "iris", "circle_open", "circle_close",
    "label", "jump", "call", "menu", "python", "scene", "show", "hide", "image", "play", "stop", "pause",
    "transition", "transform", "translate", "screen", "textbutton", "style", "define", "init", "config", "character", "movie",
    "sound", "music", "audio", "key", "action", "size", "text", "kerning", "value", "bottom_bar", "vbox", "window",
    "vbar", "modal", "sensitive", "tag", "zorder", "variant", "style_prefix", "roll_forward", "layer", "alpha", "at",
    "style_group", "focus", "adjustment", "frame", "imagebutton", "grid", "add", "on", "hover", "ease", "rotate", "subpixel",
    "truecenter", "linear", "block", "choice", "repeat", "background", "viewport", "thumb", "top_bar", "hbox",
    "idle", "spacing", "hovered", "topleft", "parallel", "draggable", "mousewheel", "scrollbars", "xzoom", "yzoom",
    "xalign", "yalign", "width", "height",
];

BUILTIN_EXCEPTIONS :: string.[
    "ArithmeticError", "AssertionError", "AttributeError", "Exception", "EOFError", "FloatingPointError", "GeneratorExit",
    "ImportError", "IndentationError", "IndexError", "KeyError", "KeyboardInterrupt", "LookupError", "MemoryError", "NameError",
    "NotImplementedError", "OSError", "OverflowError", "ReferenceError", "RuntimeError", "StopIteration", "SyntaxError",
    "TabError", "SystemError", "SystemExit", "TypeError", "UnboundLocalError", "UnicodeError", "UnicodeEncodeError",
    "UnicodeDecodeError", "UnicodeTranslateError", "ValueError", "ZeroDivisionError",
];

VALUE_KEYWORDS :: string.[
    "True", "False", "None", "null",
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
    define_enum(*b, "Keyword",     "kw_", .[KEYWORDS, TYPE_KEYWORDS, VALUE_KEYWORDS, BUILTIN_FUNCTIONS, BUILTIN_EXCEPTIONS]);

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
        for KEYWORDS           append(*b, sprint("table_add(*table, \"%\", Keyword_Token.{ type = .keyword,           keyword = .kw_% });\n", it, it));
        for TYPE_KEYWORDS      append(*b, sprint("table_add(*table, \"%\", Keyword_Token.{ type = .type,              keyword = .kw_% });\n", it, it));
        for VALUE_KEYWORDS     append(*b, sprint("table_add(*table, \"%\", Keyword_Token.{ type = .value,             keyword = .kw_% });\n", it, it));
        for BUILTIN_FUNCTIONS  append(*b, sprint("table_add(*table, \"%\", Keyword_Token.{ type = .builtin_function,  keyword = .kw_% });\n", it, it));
        for BUILTIN_EXCEPTIONS append(*b, sprint("table_add(*table, \"%\", Keyword_Token.{ type = .builtin_exception, keyword = .kw_% });\n", it, it));
        return builder_to_string(*b);
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS           { if it.count > result then result = it.count; }
    for TYPE_KEYWORDS      { if it.count > result then result = it.count; }
    for VALUE_KEYWORDS     { if it.count > result then result = it.count; }
    for BUILTIN_FUNCTIONS  { if it.count > result then result = it.count; }
    for BUILTIN_EXCEPTIONS { if it.count > result then result = it.count; }
    return xx result;
}

