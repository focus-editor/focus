tokenize_csharp :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_csharp_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        // Maybe retroactively highlight a "method("
        last := tokenizer.last_token;
        if token.type == .punctuation && token.punctuation == .l_paren && last.type == .identifier {
            memset(tokens.data + last.start, xx Token_Type.function, last.len);
        }

        tokenizer.last_token = token;

        highlight_token(buffer, token);
    }

    return .[];
}

tokenize_csharp_for_indentation :: (buffer: Buffer) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_csharp_tokenizer(buffer);

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

get_csharp_tokenizer :: (using buffer: Buffer, start_offset := -1, count := -1) -> CSharp_Tokenizer {
    tokenizer := CSharp_Tokenizer.{
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

get_next_token :: (using tokenizer: *CSharp_Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;

    // Look at the first char as if it's ASCII (if it isn't, this is just a text line)
    char := t.*;

    if interpolated_string_is_verbatim.count > 0 && last_token.type == .punctuation && last_token.punctuation == .r_brace {
        is_verbatim := interpolated_string_is_verbatim[interpolated_string_is_verbatim.count - 1];
        parse_interpolated_string_literal(tokenizer, *token, is_verbatim , is_start = false);
        array_ordered_remove_by_index(*interpolated_string_is_verbatim, interpolated_string_is_verbatim.count - 1);
    } else if is_alpha(char) || char == #char "_" {
        parse_identifier(tokenizer, *token, true);
    } else if is_digit(char) {
        parse_number(tokenizer, *token);
    } else if char == {
        // https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/operators/
        case #char "=";  parse_equal                 (tokenizer, *token);
        case #char "-";  parse_minus                 (tokenizer, *token);
        case #char "+";  parse_plus                  (tokenizer, *token);
        case #char "*";  parse_asterisk              (tokenizer, *token);
        case #char "<";  parse_less_than             (tokenizer, *token);
        case #char ">";  parse_greater_than          (tokenizer, *token);
        case #char "!";  parse_bang                  (tokenizer, *token);
        case #char "#";  parse_compiler_directive    (tokenizer, *token);
        case #char "\""; parse_string_literal        (tokenizer, *token);
        case #char "'";  parse_char_literal          (tokenizer, *token);
        case #char "/";  parse_slash_or_comment      (tokenizer, *token);
        case #char "&";  parse_ampersand             (tokenizer, *token);
        case #char "|";  parse_pipe                  (tokenizer, *token);
        case #char "%";  parse_percent               (tokenizer, *token);
        case #char "@";  parse_at                    (tokenizer, *token);
        case #char "^";  parse_caret                 (tokenizer, *token);
        case #char "$";  parse_dollar                (tokenizer, *token);
        case #char ":";  token.type = .operation;   token.operation = .colon;       t += 1;
        case #char "?";  token.type = .operation;   token.operation = .question;    t += 1;
        case #char "~";  token.type = .operation;   token.operation = .tilde;       t += 1;

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

        case;            token.type = .invalid; t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);

    return token;
}

parse_identifier :: (using tokenizer: *Tokenizer, token: *Token, check_for_keyword: bool) {
    token.type = .identifier;

    identifier := read_identifier_string(tokenizer);

    if check_for_keyword && identifier.count <= MAX_KEYWORD_LENGTH {
        kw_token, ok := table_find(*KEYWORD_MAP, identifier);

        if ok { token.type = kw_token.type; token.keyword = kw_token.keyword; return; }
    }
}

// https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/integral-numeric-types
// https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/floating-point-numeric-types
parse_number :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .number;

    is_floating_point_suffix :: (c: u8) -> bool {
        return c == #char "f" || c == #char "F" || c == #char "d" || c == #char "D" || c == #char "m" || c == #char "M";
    }

    // Consecutive underscores are allowed in numbers but they can't end in one.
    is_valid_underscore :: (t: *u8, max_t: *u8, allowed: (u8) -> bool) -> bool {
        next := t + 1;
        return t.* == #char "_" && (next < max_t && (allowed(next.*) || next.* == #char "_"));
    }

    t += 1;
    if t >= max_t return;

    if t.* == #char "x" || t.* == #char "X" {
        // Hex
        t += 1;
        while t < max_t && (is_hex(t.*) || is_valid_underscore(t, max_t, is_hex)) t += 1;
        return;
    } else if t.* == #char "b" || t.* == #char "B" {
        // Binary
        t += 1;
        is_binary :: inline (c: u8) -> bool { return c == #char "1" || c == #char "0"; }
        while t < max_t && (is_binary(t.*) || is_valid_underscore(t, max_t, is_binary)) t += 1;
        return;
    }

    // Eat initial digits/underscores
    while t < max_t && (is_digit(t.*) || is_valid_underscore(t, max_t, is_digit)) {
        t += 1;
    }
    if t >= max_t return;

    if t.* == #char "." {
        // Float, double or decimal
        // First char after a decimal point must be a digit(cannot be an underscore).
        t += 1;
        if t >= max_t || !is_digit(t.*) { token.type = .invalid; return; }

        // Eat digits/underscores after the decimal point
        t += 1;
        while t < max_t && (is_digit(t.*) || is_valid_underscore(t, max_t, is_digit)) {
            t += 1;
        }

        if t >= max_t return;

        // Exponent
        if t.* == #char "e" || t.* == #char "E" {
            t += 1;
            if t >= max_t return;

            if t.* == #char "+" || t.* == #char "-" {
              t += 1;
              if t >= max_t return;
            }

            while t < max_t && (is_digit(t.*) || is_valid_underscore(t, max_t, is_digit)) {
                t += 1;
            }
            if t >= max_t return;
        }

        // Floating point suffixes
        if is_floating_point_suffix(t.*) t += 1;
    } else {
        if is_floating_point_suffix(t.*) {
            // Floating point suffixes (can occur without a decimal point)
            t += 1;
        } else {
            // Integer suffixes
            if t.* == #char "l" || t.* == #char "L" { // l, L
                t += 1;
                if t >= max_t return;

                if t.* == #char "u" || t.* == #char "U" {  // lu, lU, Lu, LU
                    t += 1;
                }
            } else if t.* == #char "u" || t.* == #char "U" { // u, U
                t += 1;
                if t >= max_t return;

                if t.* == #char "l" || t.* == #char "L" {  // ul, uL, Ul, UL
                    t += 1;
                }
            }
        }
    }
}

parse_equal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .equal;

    t += 1;
    if t >= max_t return;

    if t.* == #char "=" {
        token.operation = .equal_equal;
        t += 1;
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
            // https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/unsafe-code?#pointer-types
            token.operation = .arrow;
            t += 1;
        case #char "-";
            token.operation = .minus_minus;
            t += 1;
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

    if t.* == #char "=" {
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

parse_compiler_directive :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    t += 1;
    eat_white_space(tokenizer);  // There may be spaces between the # and the name
    if !is_alpha(t.*) return;

    directive := read_identifier_string(tokenizer);

    while t < max_t && is_alnum(t.*) t += 1;
    if t >= max_t return;

    // Check if it's one of the existing directives
    if directive.count > MAX_DIRECTIVE_LENGTH return;
    token_directive, ok := table_find(*DIRECTIVES_MAP, directive);
    if ok {
        token.type = .directive;
        token.directive = token_directive;
    }
}

parse_string_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .string_literal;

    escape_seen := false;

    t += 1;
    while t < max_t && t.* != #char "\n" {
        //Escape for " in literal is \"
        if t.* == #char "\"" && !escape_seen break;
        escape_seen = !escape_seen && t.* == #char "\\";
        t += 1;
    }
    if t >= max_t return;

    t += 1;
}

// https://learn.microsoft.com/en-us/dotnet/csharp/programming-guide/strings/
is_valid_character_escape_character :: (c: u8) -> bool {
    return (
        c == #char "'" ||
        c == #char "\"" ||
        c == #char "\\" ||
        c == #char "0" ||
        c == #char "a" ||
        c == #char "b" ||
        c == #char "f" ||
        c == #char "n" ||
        c == #char "r" ||
        c == #char "t" ||
        c == #char "v" ||
        c == #char "u" ||
        // c == #char "U" || // Only supported by strings not characters
        c == #char "x"
    );
}

// https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/char
parse_char_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .invalid;

    escape_seen := false;

    t += 1;
    if t >= max_t || t.* == #char "\n" return;

    if t.* == #char "\\" {
        escape_seen = true;
        t += 1;
        if t >= max_t || t.* == #char "\n" return;
    } else if t.* == #char "'" {
        // Unescaped single quote without a character
        t += 1; // Invalid '
        return;
    }

    if escape_seen {
        if !is_valid_character_escape_character(t.*) {
            return;
        } else if t.* == #char "u" {
            // u must be followed by 4 hex characters
            t += 1; count := 0;
            while t < max_t && count < 4 {
                if !is_hex(t.*) { t += 1; return; }
                count += 1;
                t += 1;
            }
            if t >= max_t || t.* == #char "\n" return;
        } else if t.* ==#char "x" {
            t += 1;
            // x must be followed by at least one hex character
            if t >= max_t || !is_hex(t.*) return;
            while t < max_t && is_hex(t.*) t += 1;
        } else {
            // A single valid character after the escape like '\n'
            t += 1;
        }
    } else {
        t += 1; // Unescaped single character
    }

    if t >= max_t || t.* == #char "\n" || t.* != #char "'" return;

    token.type = .char_literal;
    t += 1; // Ending '
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
                if t.* == #char "*" && (t + 1).* == #char "/" {
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

parse_verbatim_string_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .string_literal;

    escape_seen := false;

    t += 1;
    while t < max_t && t.* != #char "\n" {
        //Escape for " in verbatim is ""
        if escape_seen && t.* != #char "\"" { t -= 1; break; }
        escape_seen = !escape_seen && t.* == #char "\"";
        t += 1;
    }
    if t >= max_t return;

    t += 1;
}

// https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/tokens/interpolated
// Interpolated strings are parsed in sections.
// - From start to the first interpolated expression section in {} (or the end)
// - Between the interpolated expression sections in {}
// - From the end of an interpolated expression section to the end
// After the start of an interpolated expression section interpolated_string_is_verbatim
// will have data that tells get_next_token() to come back and start parsing the interpolated
// string again after a right brace is encountered.
parse_interpolated_string_literal :: (using tokenizer: *CSharp_Tokenizer, token: *Token, is_verbatim: bool, is_start: bool) {
    token.type = .string_literal;

    // Parse until an unescaped { (interpolated expression section start)
    // or unescaped " (end of interpolated string)
    quote_seen, left_slash_seen, left_brace_seen := false;

    // If it's not the start of the interpolated string we keep the " as it could be the end
    if is_start t += 1;

    if is_verbatim {
        while t < max_t && t.* != #char "\n" {
            // Escape for " in verbatim is ""
            // Escape for { in interpolated is {{
            if quote_seen && t.* != #char "\"" { t -= 1; break; }
            if left_brace_seen && t.* != #char "{" { t -= 2; break; }

            quote_seen = !quote_seen && t.* == #char "\"";
            left_brace_seen = !left_brace_seen && t.* == #char "{";
            t += 1;
        }
    } else {
        while t < max_t && t.* != #char "\n" {
            // Escape for " in literal is \"
            // Escape for { in interpolated is {{
            if !left_slash_seen && t.* == #char "\"" { quote_seen = true; break; }
            if left_brace_seen && t.* != #char "{" { t -= 2; break; }

            left_slash_seen = !left_slash_seen && t.* == #char "\\";
            left_brace_seen = !left_brace_seen && t.* == #char "{";
            t += 1;
        }
    }

    // Unescaped left brace
    if left_brace_seen then array_add(*interpolated_string_is_verbatim, is_verbatim,);

    if t >= max_t return;

    t += 1;
}

// https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/tokens/verbatim
// https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/attributes
parse_at :: (using tokenizer: *CSharp_Tokenizer, token: *Token, is_interpolated := false) {
    token.type = .invalid;

    t += 1;
    if t >= max_t return;

    if t.* == #char "$" {
        parse_dollar(tokenizer, token, is_verbatim = true);
    } else if t.* == #char "\"" {
        if is_interpolated {
            // Interpolated verbatim  string
            parse_interpolated_string_literal(tokenizer, token, is_verbatim = true, is_start = true);
        } else {
            // Verbatim string
            parse_verbatim_string_literal(tokenizer, token);
        }
    } else if is_alpha(t.*) || t.* == #char "_" {
        // Identifier or disambiguate attribute
        parse_identifier(tokenizer, token, check_for_keyword = false);
    }
}

// Interpolated string
parse_dollar :: (using tokenizer: *CSharp_Tokenizer, token: *Token, is_verbatim := false) {
    token.type = .invalid;

    t += 1;
    if t >= max_t return;

    if t.* == #char "@" {
        parse_at(tokenizer, token, is_interpolated = true);
    } else if t.* == #char "\"" {
        // Interpolated or verbatim interpolated string
        parse_interpolated_string_literal(tokenizer, token, is_verbatim, is_start = true);
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

CSharp_Tokenizer :: struct {
    using #as base: Tokenizer;
    last_token: Token;
    // Records if the interpolated string is also a verbatim string at
    // the current nested interpolated expression level(array index).
    interpolated_string_is_verbatim: [..] bool;
    interpolated_string_is_verbatim.allocator = temp;
}

Token :: struct {
    using #as base: Base_Token;

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
    "arrow", "bang", "pipe", "double_pipe", "pipe_equal", "equal", "equal_equal", "bang_equal", "percent", "percent_equal",
    "less_than", "double_less_than", "less_than_equal", "greater_than", "greater_than_equal", "minus", "minus_equal",
    "minus_minus", "asterisk", "asterisk_equal", "colon", "slash", "plus", "plus_equal", "plus_plus", "slash_equal",
    "ampersand", "double_ampersand", "ampersand_equal", "tilde", "question", "unknown", "caret", "caret_equal",
];

KEYWORDS :: string.[
    "token", "as", "base", "break", "case", "catch", "checked", "class", "continue", "delegate", "do", "else", "enum",
    "explicit", "finally", "fixed", "for", "foreach", "goto", "if", "implicit", "in", "interface", "is", "lock", "namespace",
    "new", "operator", "out", "params", "ref", "return", "sizeof", "stackalloc", "struct", "switch", "this", "throw", "try",
    "typeof", "unchecked", "using", "while", "add", "and", "alias", "ascending", "args", "await", "by", "descending",
    "dynamic", "equals", "file", "from", "get", "global", "group", "init", "into", "join", "let", "managed", "nameof", "not",
    "notnull", "on", "or", "orderby", "partial", "record", "remove", "required", "scoped", "select", "set", "unmanaged",
    "value", "var", "when", "where", "with", "yield",
];

TYPE_KEYWORDS :: string.[
    "bool", "byte", "char", "decimal", "double", "float", "int", "long", "object", "sbyte", "short", "string", "uint",
    "ulong", "ushort", "void", "Boolean", "Byte", "Char", "Decimal", "Double", "Single", "Int32", "Int64", "Object", "SByte",
    "Int16", "String", "Uint32", "UInt64", "UInt16", "Void", "nint", "nuint",
];

VALUE_KEYWORDS :: string.[
    "default", "false", "null", "true",
];

MODIFIER_KEYWORDS :: string.[
    "abstract", "const", "event", "extern", "internal", "override", "private", "protected", "public", "readonly",
    "sealed", "static", "unsafe", "virtual", "volatile", "async",
];

DIRECTIVES :: string.[
    "nullable", "if", "elif", "else", "endif",
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

