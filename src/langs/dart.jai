tokenize_dart :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_dart_tokenizer(buffer, start_offset, count);

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

tokenize_dart_for_indentation :: (buffer: Buffer) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_dart_tokenizer(buffer);

    // Allocate temporary space for tracking one previous token
    tokenizer.prev_tokens[0] = New(Token,, temp);

    while true {
        src := get_next_token(*tokenizer);

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
            case .eof;                  token.type = .eof;  // to guarantee we always have indentation tokens
            case;                       token.type = .unimportant;
        }

        array_add(*tokens, token);

        if src.type == .eof break;
    }

    return tokens;
}

#scope_file

get_dart_tokenizer :: (using buffer: Buffer, start_offset := -1, count := -1) -> Dart_Tokenizer {
    tokenizer := Dart_Tokenizer.{
        buf = to_string(bytes),
        max_t = bytes.data + bytes.count,
        t = bytes.data,
    };

    if start_offset >= 0 {
        start_offset = clamp(start_offset, 0, bytes.count - 1);
        count        = clamp(count,        0, bytes.count - 1);
        tokenizer.t += start_offset;
        tokenizer.max_t = tokenizer.t + count;
    }

    return tokenizer;
}

get_next_token :: (using tokenizer: *Dart_Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;

    last_token := cast(*Token) prev_tokens[0];

    // Look at the first char as if it's ASCII
    char := t.*;

    got_token_from_interpolated_string := false;

    parsing_interpolated_string := interpolated_string_stack.count > 0;
    if parsing_interpolated_string {
        interpolated_string_data := interpolated_string_stack[interpolated_string_stack.count - 1];

        if last_token && last_token.type == .operation && last_token.operation == .dollar {
            if t < max_t {
                if t.* != #char "{" {
                    // Simple identifier case: $variable
                    got_token_from_interpolated_string = true;
                    parse_identifier(tokenizer, *token);

                    if t == start_t last_token.type = .invalid;
                }
            }
        } else if interpolated_string_data.scope_depth == scope_depth && char != #char "$" {
            // Just finished parsing an interpolated string expression. Parse the rest of the string.
            finished_parsing_string := continue_parsing_string_literal(tokenizer, *token, interpolated_string_data.quote_char, false, interpolated_string_data.multiline, true);
            if finished_parsing_string array_ordered_remove_by_index(*interpolated_string_stack, interpolated_string_stack.count - 1);

            got_token_from_interpolated_string = true;
        }
    }

    if got_token_from_interpolated_string {
        // Skip tokenization if we already got a token from the interpolated string being parsed.
    }
    else if ascii_is_alpha(char) || char == #char "_" {

        is_raw_string := char == #char "r";
        is_raw_string = is_raw_string && t < max_t;
        is_raw_string = is_raw_string && ((t + 1).* == #char "\"" || (t + 1).* == #char "'");

        if is_raw_string{
            parse_string_literal(tokenizer, *token, (t + 1).*);
        }
        else {
            // Parse identifiers which start with an ASCII letter or _
            // We'll look at identifiers which start with UTF8 letters later when we've already checked for more probable possibilities
            parse_identifier(tokenizer, *token);
        }

    } else if ascii_is_digit(char) {
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
        case #char "/";  parse_slash_or_comment      (tokenizer, *token);
        case #char "&";  parse_ampersand             (tokenizer, *token);
        case #char "|";  parse_pipe                  (tokenizer, *token);
        case #char "%";  parse_percent               (tokenizer, *token);
        case #char "^";  parse_caret                 (tokenizer, *token);
        case #char "\""; parse_string_literal        (tokenizer, *token, char);
        case #char "'";  parse_string_literal        (tokenizer, *token, char);

        case #char ";";  token.type = .punctuation; token.punctuation = .semicolon; t += 1;
        case #char "\\"; token.type = .punctuation; token.punctuation = .backslash; t += 1;
        case #char ",";  token.type = .punctuation; token.punctuation = .comma;     t += 1;
        case #char ".";  token.type = .punctuation; token.punctuation = .period;    t += 1;
        case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;   t += 1; scope_depth += 1;
        case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;   t += 1; scope_depth -= 1;
        case #char "(";  token.type = .punctuation; token.punctuation = .l_paren;   t += 1;
        case #char ")";  token.type = .punctuation; token.punctuation = .r_paren;   t += 1;
        case #char "[";  token.type = .punctuation; token.punctuation = .l_bracket; t += 1;
        case #char "]";  token.type = .punctuation; token.punctuation = .r_bracket; t += 1;

        case #char "~";  token.type = .operation;   token.operation   = .tilde;     t += 1;
        case #char "`";  token.type = .operation;   token.operation   = .backtick;  t += 1;
        case #char "$";  token.type = .operation;   token.operation   = .dollar;  t += 1;

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

parse_identifier :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
    token.type = .identifier;

    identifier_str := read_utf8_identifier_string(tokenizer);

    // Maybe it's a keyword
    if identifier_str.count <= MAX_KEYWORD_LENGTH {
        ok, kw_token := table_find(*KEYWORD_MAP, identifier_str);
        if ok { token.type = kw_token.type; token.keyword = kw_token.keyword; return; }
    }
}

parse_colon :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .colon;
    t += 1;
}

parse_question :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .question;
    t += 1;
}

parse_equal :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .equal;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";  token.operation = .equal_equal; t += 1;
    }
}

parse_minus :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
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
            if ascii_is_digit(t.*) parse_number_c_like(tokenizer, token);
    }
}

parse_plus :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
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

parse_asterisk :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
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

parse_less_than_or_include :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
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
    }
}

parse_greater_than :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
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

parse_bang :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
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

parse_string_literal :: (using tokenizer: *Dart_Tokenizer, token: *Token, quote_char: u8) {
    is_raw_string := false;
    if t.* == #char "r" {
        is_raw_string = true;
        t += 1;
    }

    enclosing_quote_char := t.*;
    is_multiline_string := next_chars_are_multiline_string_delimeter(tokenizer, enclosing_quote_char);

    t += ifx is_multiline_string then 3 else 1;

    continue_parsing_string_literal(tokenizer, token, quote_char, is_raw_string, is_multiline_string, false);
}

continue_parsing_string_literal :: (using tokenizer: *Dart_Tokenizer, token: *Token, initial_quote_char: u8, is_raw_string: bool, is_multiline_string: bool, is_interpolated: bool) -> finished: bool {
    escape_seen := false;

    if is_raw_string token.type = .raw_string;
    else if is_multiline_string token.type = .multiline_string;
    else token.type = .string_literal;

    while t < max_t && (t.* != #char "\n" || is_multiline_string) {
        if (t.* == initial_quote_char) && !escape_seen {
            if !is_multiline_string || next_chars_are_multiline_string_delimeter(tokenizer, initial_quote_char) {
                break;
            }
        }

        if t.* == #char "$" && !escape_seen && !is_raw_string {
            if !is_interpolated {
                array_add(*interpolated_string_stack, .{scope_depth, is_multiline_string, initial_quote_char});
            }
            return false;
        }

        escape_seen = !escape_seen && t.* == #char "\\";
        t += 1;
    }

    t += ifx is_multiline_string then 3 else 1;
    if t > max_t {
        t = max_t;
    }

    return true;
}

next_chars_are_multiline_string_delimeter :: (using tokenizer: *Dart_Tokenizer, quote_char : u8) -> bool
{
    if t <= max_t - 3 {
        if (t + 0).* == quote_char && (t + 1).* == quote_char && (t + 2).* == quote_char {
            return true;
        }
    }

    return false;
}

parse_slash_or_comment :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
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

parse_ampersand :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
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

parse_pipe :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
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

parse_percent :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
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

parse_caret :: (using tokenizer: *Dart_Tokenizer, token: *Token) {
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
    using #as base: Base_Token;

    union {
        keyword:        Keyword;
        punctuation:    Punctuation;
        operation:      Operation;
    }
}

Dart_Tokenizer :: struct {
    using #as base: Tokenizer;

    // Records if the interpolated string is also a multi-line string at
    // the current nested interpolated expression level(array index).
    interpolated_string_stack: [..] Interpolated_String_Data;
    interpolated_string_stack.allocator = temp;

    scope_depth : int;

    Interpolated_String_Data :: struct {
        scope_depth: int;
        multiline: bool;
        quote_char: u8;
    }
}

PUNCTUATION :: string.[
    "semicolon", "backslash", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", "period", "comma", "dollar"
];

OPERATIONS :: string.[
    "arrow", "bang", "backtick", "dollar", "pipe", "double_pipe", "pipe_equal", "equal", "equal_equal", "bang_equal", "percent",
    "percent_equal", "less_than", "double_less_than", "less_than_equal", "greater_than", "greater_than_equal", "minus",
    "minus_equal", "minus_minus", "asterisk", "asterisk_equal", "colon", "slash", "plus", "plus_equal", "plus_plus",
    "slash_equal", "ampersand", "double_ampersand", "ampersand_equal", "tilde", "question", "unknown", "caret", "caret_equal",
];

KEYWORDS :: string.[
     "abstract", "as", "assert", "async", "await", "base", "break", "case", "catch", "class", "continue", "covariant",
     "default", "deferred", "do", "else", "enum", "export", "extends", "extension", "external", "factory",
     "finally", "for", "get", "hide", "if", "implements", "import", "in", "interface", "is", "late", "library", "mixin",
     "new", "of", "on", "operator", "part", "required", "rethrow", "return", "sealed", "set", "show", "super",
     "switch", "sync", "throw", "try", "type", "typedef", "when", "with", "while", "yield",
];

TYPE_KEYWORDS :: string.[
    // built-in types
    "bool", "double", "dynamic", "Enum", "Function", "Future", "int", "Iterable", "List", "Map", "Never", "Null", "Object",
    "Runes", "Set", "Stream", "String", "Symbol", "var", "void"
];

VALUE_KEYWORDS :: string.[
    "false", "null", "this", "true",
];

MODIFIER_KEYWORDS :: string.[
    "const", "final", "static"
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
