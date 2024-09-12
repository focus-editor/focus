tokenize_rust :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_rust_tokenizer(buffer, start_offset, count);

    start_scope(*tokenizer, tokenizer.t - tokenizer.buf.data, .scope_export);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        // Maybe retroactively highlight a function
        before_prev, prev := tokenizer.last_tokens[0], tokenizer.last_tokens[1];
        if token.type == .punctuation && token.punctuation == .l_paren {
            if prev.type == .identifier {
                // Handle "func("
                memset(tokens.data + prev.start, xx Token_Type.function, prev.len);
            }
        }

        // Remember last 2 tokens
        tokenizer.last_tokens[0] = tokenizer.last_tokens[1];
        tokenizer.last_tokens[1] = token;

        memset(tokens.data + token.start, xx token.type, token.len);
    }

    end_scope(*tokenizer, tokenizer.t - tokenizer.buf.data);

    return tokenizer.regions;
}

tokenize_rust_for_indentation :: (buffer: *Buffer) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_rust_tokenizer(buffer);

    while true {
        src := get_next_token(*tokenizer);

        tokenizer.last_tokens[0] = tokenizer.last_tokens[1];  // if we don't remember last 2 tokens, here strings won't be detected properly
        tokenizer.last_tokens[1] = src;

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
            case .multiline_string;     token.type = .maybe_multiline;
            case .eof;                  token.type = .eof;  // to guarantee we always have indentation tokens
            case;                       token.type = .unimportant;
        }

        array_add(*tokens, token);

        if src.type == .eof break;
    }

    return tokens;
}

#scope_file

// We're using a separate tokenizer here because we have to keep track of last 2 tokens in many places
// and we can't use a global variable for that because of threading
get_rust_tokenizer :: (using buffer: *Buffer, start_offset := -1, count := -1) -> Rust_Tokenizer {
    tokenizer: Rust_Tokenizer;

    tokenizer.buf    = to_string(bytes);
    tokenizer.max_t  = bytes.data + bytes.count;
    tokenizer.t      = bytes.data;

    if start_offset >= 0 {
        start_offset = clamp(start_offset, 0, bytes.count - 1);
        count        = clamp(count,        0, bytes.count - 1);
        tokenizer.t += start_offset;
        tokenizer.max_t = tokenizer.t + count;
    }

    return tokenizer;
}

eat_white_space :: (using tokenizer: *Rust_Tokenizer) {
    while t < max_t && is_white_space(t.*) {
        t += 1;
    }
}

get_next_token :: (using tokenizer: *Rust_Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;

    // Assume ASCII, unless we're in the middle of a string.
    // UTF-8 characters elsewhere are a syntax error.
    char := t.*;

    if is_alpha(char) || char == #char "_" {
        parse_identifier_or_raw_string(tokenizer, *token);
    } else if is_digit(char) {
        // Handle number literals that don't look like they are being finished properly
        // For example, 0b10002 will highlight 0b1000 as one number and 2 as another number,
        // but when highlit in editor it looks like one number literal rather than two
        // The solution here is to not highlight more numbers if there are many number tokens in a row
        last_char := (t - 1).*;
        if tokenizer.last_tokens[1].type != .number || (!is_digit(last_char) && last_char != #char "_") {
            parse_number(tokenizer, *token);
        } else {
            parse_identifier_or_raw_string(tokenizer, *token);
        }
    } else if char == {
        case #char ":";  parse_colon             (tokenizer, *token);
        case #char "=";  parse_equal             (tokenizer, *token);
        case #char "-";  parse_minus             (tokenizer, *token);
        case #char "+";  parse_plus              (tokenizer, *token);
        case #char "*";  parse_asterisk          (tokenizer, *token);
        case #char "<";  parse_less_than         (tokenizer, *token);
        case #char ">";  parse_greater_than      (tokenizer, *token);
        case #char "!";  parse_bang              (tokenizer, *token);
        case #char "\""; parse_string_literal    (tokenizer, *token);
        case #char "\t"; parse_tab               (tokenizer, *token);
        case #char "/";  parse_slash_or_comment  (tokenizer, *token);
        case #char "&";  parse_ampersand         (tokenizer, *token);
        case #char "|";  parse_pipe              (tokenizer, *token);
        case #char "%";  parse_percent           (tokenizer, *token);
        case #char "^";  parse_caret             (tokenizer, *token);
        case #char ".";  parse_period            (tokenizer, *token);
        case #char "'";  parse_single_quote      (tokenizer, *token);

        case #char ";";  token.type = .punctuation; token.punctuation = .semicolon; t += 1;
        case #char ",";  token.type = .punctuation; token.punctuation = .comma;     t += 1;
        case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;   t += 1;
        case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;   t += 1;
        case #char "(";  token.type = .punctuation; token.punctuation = .l_paren;   t += 1;
        case #char ")";  token.type = .punctuation; token.punctuation = .r_paren;   t += 1;
        case #char "[";  token.type = .punctuation; token.punctuation = .l_bracket; t += 1;
        case #char "]";  token.type = .punctuation; token.punctuation = .r_bracket; t += 1;
        case #char "$";  token.type = .punctuation; token.punctuation = .dollar;    t += 1;
        case #char "#";  token.type = .punctuation; token.punctuation = .hash;      t += 1;

        case #char "~";  token.type = .operation;   token.operation   = .tilde;     t += 1;
        case #char "`";  token.type = .operation;   token.operation   = .backtick;  t += 1;
        case #char "?";  token.type = .operation;   token.operation   = .question_mark;  t += 1;

        case;            token.type = .invalid; t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

parse_identifier_or_raw_string :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
    token.type = .identifier;

    // Check for raw strings r#"..."# and br#"..."#
    if (t + 2 < max_t && t.* == #char "r" && (t+1).* == #char "#") ||
       (t + 3 < max_t && t.* == #char "b" && (t+1).* == #char "r" && (t+2).* == #char "#") {
        token.type = .raw_string;

        if t.* == #char "b" then t += 1;
        t += 2;  // skip the first r#
        num_hashes := 1;
        while t < max_t && t.* == #char "#" { t += 1; num_hashes += 1; }  // skip any number of hashes
        if t >= max_t || t.* != #char "\"" { token.type = .invalid; return; }  // expect a valid-formed raw string

        // Construct the expected end sequence
        end_sequence := talloc_string(num_hashes + 1);  // "####..###
        end_sequence[0] = cast(u8) #char "\"";
        memset(end_sequence.data+1, cast(u8) #char "#", num_hashes);

        remaining_buffer := string.{max_t - t, t};
        contents_length := find_index_from_left(remaining_buffer, end_sequence);
        if contents_length >= 0 {
            t += contents_length + end_sequence.count;
        } else {
            t = max_t;
        }

        return;
    }

    identifier_str := read_utf8_identifier_string(tokenizer);

    // Maybe it's a keyword
    if identifier_str.count <= MAX_KEYWORD_LENGTH {
        kw_token, ok := table_find(*KEYWORD_MAP, identifier_str);
        if ok { token.type = kw_token.type; token.keyword = kw_token.keyword; return; }
    }

    // Maybe it's a macro
    if t < max_t && t.* == #char "!" {
        token.type = .macro;
        t += 1;
        return;
    }
}

parse_number :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
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

parse_colon :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .colon;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char ":";  token.operation = .double_colon;  t += 1;
        case #char "=";  token.operation = .colon_equal;   t += 1;
    }
}

parse_equal :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .equal;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";  token.operation = .equal_equal; t += 1;
    }
}

parse_minus :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
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
            t += 1;
            if t < max_t && t.* == #char "-" {
                token.operation = .triple_dash;
                t += 1;
            } else {
                token.operation = .unknown;  // -- is not a valid token
            }
        case;
            if tokenizer.last_tokens[1].type != .number && is_digit(t.*) {
                parse_number(tokenizer, token);
            }
    }
}

parse_plus :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .plus;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .plus_equal;
            t += 1;
    }
}

parse_asterisk :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
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

parse_period :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
    token.type        = .punctuation;
    token.punctuation = .period;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char ".";
            token.type      = .operation;
            token.operation = .double_period;
            t += 1;

        case #char "*";
            token.type      = .operation;
            token.operation = .period_asterisk;
            t += 1;
    }
}

parse_bang :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
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

parse_percent :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
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

parse_caret :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
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

parse_single_quote :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
    token.type = .value;  // by default assuming it's a lifetime (using a generic token here)

    t += 1;
    if t >= max_t return;

    // Maybe it's a char literal like '\n' or '\u{...}'
    if t.* == #char "\\" {
        token.type = .char_literal;
        while t < max_t && t.* != #char "'" && t.* != #char "\n"  t += 1;  // just allow however many characters they want. We're not meant to check syntax.
        return;
    }

    // Maybe it's a char literal like '<some unicode char>'
    next_char := unicode_next_character(t);
    if next_char < max_t && next_char.* == #char "'" {
        token.type = .char_literal;
        t = next_char;
        t += 1;
        return;
    }

    // Treat it as a lifetime
    identifier_str := read_utf8_identifier_string(tokenizer);
    if identifier_str == "static" {
        token.type = .keyword;
        return;
    }
}

parse_ampersand :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
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

parse_pipe :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
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

parse_less_than :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
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

parse_greater_than :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
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

parse_tab :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
    token.type = .comment;
    t += 1;
    while t < max_t && t.* == #char "\t" t += 1;
}

parse_slash_or_comment :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
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
            num_open_comments := 0;
            while t + 1 < max_t {
                if t.* == #char "*" && << (t + 1) == #char "/" {
                    if num_open_comments == 0 {
                        t += 2;
                        break;
                    } else {
                        num_open_comments -= 1;
                    }
                } else if t.* == #char "/" && << (t + 1) == #char "*" {
                    num_open_comments += 1;
                    t += 1;
                }
                t += 1;
            }
    }
}

parse_string_literal :: (using tokenizer: *Rust_Tokenizer, token: *Token) {
    token.type = .string_literal;

    escape_seen := false;

    t += 1;
    while t < max_t {
        if t.* == #char "\"" && !escape_seen break;
        escape_seen = !escape_seen && t.* == #char "\\";
        t += 1;
    }
    if t >= max_t return;

    t += 1;
}

read_identifier_string_tmp :: (using tokenizer: *Rust_Tokenizer) -> string /* temp */ {
    identifier: [..] u8;
    identifier.allocator = temp;

    array_add(*identifier, t.*);

    t += 1;
    slash_mode := false;

    while t < max_t {
        c := t.*;
        if is_alnum(c)      { t += 1; slash_mode = false; array_add(*identifier, c); continue; }
        if c == #char "\\"  { t += 1; slash_mode = true;  continue; }
        if slash_mode && is_white_space(c) { t += 1; continue; }
        break;
    }
    if t >= max_t then t = max_t;

    return cast(string) identifier;
}

start_scope :: (using tokenizer: *Rust_Tokenizer, offset: s64, kind: Buffer_Region.Kind) {
    if current_scope_id >= 0 then end_scope(tokenizer, offset);
    current_scope_id = regions.count;

    region := Buffer_Region.{
        start = xx offset,
        end   = -1,
        kind  = kind,
    };
    array_add(*regions, region);
}

end_scope :: inline (using tokenizer: *Rust_Tokenizer, offset: s64) {
    regions[current_scope_id].end = xx offset;
}

Rust_Tokenizer :: struct {
    using #as base: Tokenizer;

    regions: [..] Buffer_Region;
    regions.allocator = temp;
    current_scope_id := -1;

    last_tokens: [2] Token;
}

Token :: struct {
    start, len: s32;
    type: Token_Type = .invalid;

    // Additional info to distinguish between keywords/punctuation
    union {
        keyword:            Keyword;
        punctuation:        Punctuation;
        operation:          Operation;
    }
}

PUNCTUATION :: string.[
    "dollar", "semicolon", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket",
    "period", "comma", "hash",
];

OPERATIONS :: string.[
    "arrow", "bang", "backtick", "pipe", "double_pipe", "pipe_equal", "equal", "equal_equal", "bang_equal",
    "percent", "percent_equal", "less_than", "double_less_than", "less_than_equal", "greater_than", "greater_than_equal",
    "minus", "minus_equal", "triple_dash", "asterisk", "asterisk_equal", "colon", "colon_equal", "double_colon", "slash",
    "plus", "plus_equal", "slash_equal", "ampersand", "double_ampersand", "ampersand_equal", "tilde", "unknown",
    "caret", "caret_equal", "double_period", "period_asterisk", "question_mark",
];

KEYWORDS :: string.[
    "as", "break", "const", "continue", "crate", "else", "enum", "extern", "fn", "for", "if", "impl", "in", "let",
    "loop", "match", "mod", "move", "mut", "pub", "ref", "return", "static", "struct", "super", "trait",
    "type", "unsafe", "use", "where", "while",
    "async", "await", "dyn", "try",
    "abstract", "become", "box", "do", "final", "macro", "override", "priv", "typeof", "unsized", "virtual", "yield",
];

TYPE_KEYWORDS :: string.[
    "bool", "f32", "f64",
    "i8", "i16", "i32", "i64", "i128", "isize",
    "u8", "u16", "u32", "u64", "u128", "usize",
    "str", "char",
    "Self",
];

VALUE_KEYWORDS :: string.[
    "true", "false", "self",
    "Some", "None", "Ok", "Err",
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

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS       { if it.count > result then result = it.count; }
    for TYPE_KEYWORDS  { if it.count > result then result = it.count; }
    for VALUE_KEYWORDS { if it.count > result then result = it.count; }
    return xx result;
}

