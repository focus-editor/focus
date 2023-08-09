highlight_csharp_syntax :: (using buffer: *Buffer) {
    using tokenizer := get_tokenizer(buffer);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        // Maybe retroactively highlight a "method("
        if token.type == .punctuation && token.punctuation == .l_paren && last_token.type == .identifier {
            memset(colors.data + last_token.start, xx Code_Color.FUNCTION, last_token.len);
        }

        last_token = token;

        color := COLOR_MAP[token.type];
        memset(colors.data + token.start, xx color, token.len);
    }
}

tokenize_csharp_for_indentation :: (using buffer: Buffer) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_tokenizer(buffer);

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

get_tokenizer :: (using buffer: Buffer) -> Tokenizer {
    tokenizer: Tokenizer;

    tokenizer.buf   = to_string(bytes);
    tokenizer.max_t = bytes.data + bytes.count;
    tokenizer.t     = bytes.data;
    tokenizer.last_token = .{0, 0, .eof};

    return tokenizer;
}

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    t = eat_white_space(t, max_t);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;

    // Look at the first char as if it's ASCII (if it isn't, this is just a text line)
    char := <<t;

    if is_alpha(char) || char == #char "_" {
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
        case #char "#";  parse_preprocessor_directive(tokenizer, *token);
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

is_hex :: inline (c: u8) -> bool {
    return is_digit(c) || (c >= #char "a" && c <= #char "f") || (c >= #char "A" && c <= #char "F");
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
        return <<t == #char "_" && (next < max_t && (allowed(<<next) || <<next == #char "_"));
    }

    t += 1;
    if t >= max_t return;

    if <<t == #char "x" || <<t == #char "X" {
        // Hex
        t += 1;
        while t < max_t && (is_hex(<<t) || is_valid_underscore(t, max_t, is_hex)) t += 1;
        return;
    } else if <<t == #char "b" || <<t == #char "B" {
        // Binary
        t += 1;
        is_binary :: inline (c: u8) -> bool { return c == #char "1" || c == #char "0"; }
        while t < max_t && (is_binary(<<t) || is_valid_underscore(t, max_t, is_binary)) t += 1;
        return;
    }

    // Eat initial digits/underscores
    while t < max_t && (is_digit(<<t) || is_valid_underscore(t, max_t, is_digit)) {
        t += 1;
    }
    if t >= max_t return;

    if <<t == #char "." {
        // Float, double or decimal
        // First char after a decimal point must be a digit(cannot be an underscore).
        t += 1;
        if t >= max_t || !is_digit(<<t) { token.type = .invalid; return; }

        // Eat digits/underscores after the decimal point
        t += 1;
        while t < max_t && (is_digit(<<t) || is_valid_underscore(t, max_t, is_digit)) {
            t += 1;
        }

        if t >= max_t return;

        // Exponent
        if <<t == #char "e" || <<t == #char "E" {
            t += 1;
            if t >= max_t return;

            if <<t == #char "+" || <<t == #char "-" {
              t += 1;
              if t >= max_t return;
            }

            while t < max_t && (is_digit(<<t) || is_valid_underscore(t, max_t, is_digit)) {
                t += 1;
            }
            if t >= max_t return;
        }

        // Floating point suffixes
        if is_floating_point_suffix(<<t) t += 1;
    } else {
        if is_floating_point_suffix(<<t) {
            // Floating point suffixes (can occur without a decimal point)
            t += 1;
        } else {
            // Integer suffixes
            if <<t == #char "l" || <<t == #char "L" { // l, L
                t += 1;
                if t >= max_t return;

                if <<t == #char "u" || <<t == #char "U" {  // lu, lU, Lu, LU
                    t += 1;
                }
            } else if <<t == #char "u" || <<t == #char "U" { // u, U
                t += 1;
                if t >= max_t return;

                if <<t == #char "l" || <<t == #char "L" {  // ul, uL, Ul, UL
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

    if <<t == #char "=" {
        token.operation = .equal_equal;
        t += 1;
    }
}

parse_minus :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .minus;

    t += 1;
    if t >= max_t return;

    if <<t == {
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

    if <<t == {
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

    if <<t == #char "=" {
        token.operation = .asterisk_equal;
        t += 1;
    }
}

parse_less_than :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .less_than;

    t += 1;
    if t >= max_t return;

    if <<t == {
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

    if <<t == {
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

    if <<t == {
        case #char "=";
            token.operation = .bang_equal;
            t += 1;
    }
}

parse_preprocessor_directive :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    t += 1;
    t = eat_white_space(t, max_t);  // There may be spaces between the # and the name
    if !is_alpha(<<t) return;

    directive := read_identifier_string(tokenizer);

    while t < max_t && is_alnum(<<t) t += 1;
    if t >= max_t return;

    // Check if it's one of the existing directives
    if directive.count > MAX_DIRECTIVE_LENGTH return;
    token_directive, ok := table_find(*PREPROCESSOR_DIRECTIVES_MAP, directive);
    if ok {
        token.type = .preprocessor_directive;
        token.preprocessor_directive = token_directive;
    }
}

parse_string_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .string_literal;

    escape_seen := false;

    t += 1;
    while t < max_t && <<t != #char "\n" {
        if <<t == #char "\"" && !escape_seen break;
        escape_seen = !escape_seen && <<t == #char "\\";
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
    if t >= max_t || <<t == #char "\n" return;

    if <<t == #char "\\" {
        escape_seen = true;
        t += 1;
        if t >= max_t || <<t == #char "\n" return;
    } else if <<t == #char "'" {
        // Unescaped single quote without a character
        t += 1; // Invalid '
        return;
    }

    if escape_seen {
        if !is_valid_character_escape_character(<<t) {
            return;
        } else if <<t == #char "u" {
            // u must be followed by 4 hex characters
            t += 1; count := 0;
            while t < max_t && count < 4 {
                if !is_hex(<<t) { t += 1; return; }
                count += 1;
                t += 1;
            }
            if t >= max_t || <<t == #char "\n" return;
        } else if <<t ==#char "x" {
            t += 1;
            // x must be followed by at least one hex character
            if t >= max_t || !is_hex(<<t) return;
            while t < max_t && is_hex(<<t) t += 1;
        } else {
            // A single valid character after the escape like '\n'
            t += 1;
        }
    } else {
        t += 1; // Unescaped single character
    }

    if t >= max_t || <<t == #char "\n" || <<t != #char "'" return;

    token.type = .char_literal;
    t += 1; // Ending '
}

parse_slash_or_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .slash;

    t += 1;
    if t >= max_t return;

    if <<t == {
        case #char "=";
            token.operation = .slash_equal;
            t += 1;
        case #char "/";
            token.type = .comment;
            t += 1;
            while t < max_t && <<t != #char "\n" t += 1;
        case #char "*";
            token.type = .multiline_comment;
            t += 1;
            while t + 1 < max_t {
                if <<t == #char "*" && <<(t + 1) == #char "/" {
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

    if <<t == {
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

    if <<t == {
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

    if <<t == {
        case #char "=";
            token.operation = .percent_equal;
            t += 1;
    }
}

parse_verbatim_string_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .string_literal;

    escape_seen := false;

    t += 1;
    while t < max_t && <<t != #char "\n" {
        if escape_seen && <<t != #char "\"" { t -= 1; break; }
        escape_seen = !escape_seen && <<t == #char "\"";
        t += 1;
    }
    if t >= max_t return;

    t += 1;
}

// https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/tokens/verbatim
// https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/language-specification/attributes
parse_at :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .invalid;

    t += 1;
    if t >= max_t return;

    if <<t == #char "$" {
        // Verbatim interpolated string
        parse_dollar(tokenizer, token, true);
    } else if <<t == #char "\"" {
        // Verbatim string
        parse_verbatim_string_literal(tokenizer, token);
    } else if is_alpha(<<t) || <<t == #char "_" {
        // Identifier or disambiguate attribute
        parse_identifier(tokenizer, token, check_for_keyword = false);
    }
}

// Interpolated string
// The enclosed identifiers and braces are not parsed
parse_dollar :: (using tokenizer: *Tokenizer, token: *Token, verbatim := false) {
    token.type = .invalid;

    t += 1;
    if t >= max_t return;

    if <<t == #char "@" {
        // Interpolated verbatim string
        parse_at(tokenizer, token);
    } else if <<t == #char "\"" {
        if verbatim {
            // Verbatim interpolated string
            parse_verbatim_string_literal(tokenizer, token);
        } else {
            // Interpolated string
            parse_string_literal(tokenizer, token);
        }
    }
}

parse_caret :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .caret;

    t += 1;
    if t >= max_t return;

    if <<t == {
        case #char "=";
            token.operation = .caret_equal;
            t += 1;
    }
}

read_identifier_string :: (using tokenizer: *Tokenizer) -> string {
    identifier: string;
    identifier.data = t;

    while t < max_t && is_alnum(<<t) {
        t += 1;
    }
    if t >= max_t then t = max_t;
    identifier.count = t - identifier.data;

    return identifier;
}

eat_white_space :: inline (start: *u8, max_t: *u8) -> *u8 {
    t := start;
    while t < max_t && is_white_space(<<t) {
        t += 1;
    }
    return t;
}

Tokenizer :: struct {
    buf: string;
    max_t:   *u8;
    start_t: *u8;  // Cursor when starting parsing new token
    t:       *u8;  // Cursor

    last_token: Token;  // To retroactively highlight methods
}

Token :: struct {
    start, len: s32;
    type: Type;

    union {
        keyword:            Keyword;
        punctuation:        Punctuation;
        operation:          Operation;
        preprocessor_directive: Directive;
    }

    Type :: enum u16 {
        eof;

        identifier;
        string_literal;
        char_literal;
        number;
        comment;
        multiline_comment;
        operation;
        punctuation;
        modifier_keyword;
        keyword;
        type_keyword;
        value_keyword;
        preprocessor_directive;
        invalid;
    }
}

// Must match the order of the types in the enum above
COLOR_MAP :: Code_Color.[
    .COMMENT,       // eof - color unused

    .DEFAULT,       // identifier
    .STRING,        // string_literal
    .STRING,        // char_literal
    .VALUE,         // number
    .COMMENT,       // comment
    .COMMENT,       // multiline_comment
    .OPERATION,     // operation
    .PUNCTUATION,   // punctuation
    .KEYWORD,       // keyword
    .KEYWORD,       // modifier_keyword (currently no specific color available for modifiers)
    .TYPE,          // type_keyword
    .VALUE_KEYWORD, // value_keyword
    .KEYWORD,       // preprocessor_directive
    .ERROR,         // invalid
];

// https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/keywords
Keyword :: enum u16 {
    // Reserved identifiers
    kw_as;
    kw_base;
    kw_break;
    kw_case;
    kw_catch;
    kw_checked;
    kw_class;
    kw_continue;
    kw_delegate;
    kw_do;
    kw_else;
    kw_enum;
    kw_explicit;
    kw_finally;
    kw_fixed;
    kw_for;
    kw_foreach;
    kw_goto;
    kw_if;
    kw_implicit;
    kw_in; // Used in other contexts besides modifier
    kw_interface;
    kw_is;
    kw_lock;
    kw_namespace;
    kw_new; // Used in other contexts besides modifier
    kw_operator;
    kw_out; // Used in other contexts besides modifier
    kw_params;
    kw_ref;
    kw_return;
    kw_sizeof;
    kw_stackalloc;
    kw_struct;
    kw_switch;
    kw_this;
    kw_throw;
    kw_try;
    kw_typeof;
    kw_unchecked;
    kw_using;
    kw_while;

    kwv_default;
    kwv_false;
    kwv_null;
    kwv_true;

    kwm_abstract;
    kwm_const;
    kwm_event;
    kwm_extern;
    kwm_file;
    kwm_internal;
    kwm_override;
    kwm_private;
    kwm_protected;
    kwm_public;
    kwm_readonly;
    kwm_sealed;
    kwm_static;
    kwm_unsafe;
    kwm_virtual;
    kwm_volatile;

    kwt_bool;
    kwt_byte;
    kwt_char;
    kwt_decimal;
    kwt_double;
    kwt_float;
    kwt_int;
    kwt_long;
    kwt_object;
    kwt_sbyte;
    kwt_short;
    kwt_string;
    kwt_uint;
    kwt_ulong;
    kwt_ushort;
    kwt_void;
    // Type aliases
    // https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/builtin-types/built-in-types
    kwt_Boolean;
    kwt_Byte;
    kwt_Char;
    kwt_Decimal;
    kwt_Double;
    kwt_Single;
    kwt_Int32;
    kwt_Int64;
    kwt_Object;
    kwt_SByte;
    kwt_Int16;
    kwt_String;
    kwt_Uint32;
    kwt_UInt64;
    kwt_UInt16;
    kwt_Void;

    // Contextual keywords
    kw_add;
    kw_and;
    kw_alias;
    kw_ascending;
    kw_args;
    kw_await;
    kw_by;
    kw_descending;
    kw_dynamic;
    kw_equals;
    kw_file;
    kw_from;
    kw_get;
    kw_global;
    kw_group;
    kw_init;
    kw_into;
    kw_join;
    kw_let;
    kw_managed;
    kw_nameof;
    kw_not;
    kw_notnull;
    kw_on;
    kw_or;
    kw_orderby;
    kw_partial;
    kw_record;
    kw_remove;
    kw_required;
    kw_scoped;
    kw_select;
    kw_set;
    kw_unmanaged;
    kw_value;
    kw_var;
    kw_when;
    kw_where;
    kw_with;
    kw_yield;

    kwm_async;

    kwt_nint;
    kwt_nuint;
}

Operation :: enum u16 {
    arrow;
    bang;
    pipe;
    double_pipe;
    pipe_equal;
    equal;
    equal_equal;
    bang_equal;
    percent;
    percent_equal;
    less_than;
    double_less_than;
    less_than_equal;
    greater_than;
    greater_than_equal;
    minus;
    minus_equal;
    minus_minus;
    asterisk;
    asterisk_equal;
    colon;
    slash;
    plus;
    plus_equal;
    plus_plus;
    slash_equal;
    ampersand;
    double_ampersand;
    ampersand_equal;
    tilde;
    question;
    unknown;
    caret;
    caret_equal;
}

Punctuation :: enum u16 {
    semicolon;
    backslash;
    l_paren;
    r_paren;
    l_brace;
    r_brace;
    l_bracket;
    r_bracket;
    period;
    comma;
}

// https://learn.microsoft.com/en-us/dotnet/csharp/language-reference/preprocessor-directives
Directive :: enum u16 {
    di_nullable;
    di_if;
    di_elif;
    di_else;
    di_endif;
}

Keyword_Token :: struct {
    type: Token.Type;
    keyword: Keyword;
}

enum_value_to_name :: (value: $Enum) -> string
#modify { return (cast(*Type_Info) Enum).type == .ENUM; }
{
    info := type_info(Enum);
    for info.names {
        if info.values[it_index] == cast(s64) value return it;
    }

    assert(false, "Unknown enum value of '%'\n", value);
    return "";
}

KEYWORD_MAP :: #run -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    init(*table, type_info(Keyword).values.count * size_of(Keyword));

    for enum_values_as_enum(Keyword) {
        name := enum_value_to_name(it);
        if starts_with(name, "kwt") {
            table_add(*table, slice(name, 4, name.count - 4), .{.type_keyword, it});
        } else if starts_with(name, "kwm") {
            table_add(*table, slice(name, 4, name.count - 4), .{.modifier_keyword, it});
        } else if starts_with(name, "kwv") {
            table_add(*table, slice(name, 4, name.count - 4), .{.value_keyword, it});
        } else {
            table_add(*table, slice(name, 3, name.count - 3), .{.keyword, it});
        }
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    max: s64;
    prefix_count: s64;

    for enum_names(Keyword) {
        if starts_with(it, "kwt") prefix_count = 4;
        else if starts_with(it, "kwm") prefix_count = 4;
        else if starts_with(it, "kwv") prefix_count = 4;
        else prefix_count = 3;

        length := it.count - prefix_count;
        if length > max max = length;
    }

    return xx max;
}

PREPROCESSOR_DIRECTIVES_MAP :: #run -> Table(string, Directive) {
    table: Table(string, Directive);
    init(*table, type_info(Directive).values.count * size_of(Directive));

    for enum_values_as_enum(Directive) {
        name := enum_value_to_name(it);
        table_add(*table, slice(name, 3, name.count - 3), it);
    }

    return table;
}

MAX_DIRECTIVE_LENGTH :: #run -> s32 {
    max: s64;

    for enum_names(Directive) {
        length := it.count - 3;
        if length > max max = length;
    }

    return xx max;
}

#run assert(type_info(Token.Type).values.count == COLOR_MAP.count);