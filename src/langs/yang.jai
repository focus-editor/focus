tokenize_yang :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        using tokenizer;

        highlight_token(buffer, token);
    }

    return .[];
}

#scope_file

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token : Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;

    char := << t;

    if is_alpha(char) {
        parse_identifier(tokenizer, *token);
    } else if is_digit(char) {
        parse_number(tokenizer, *token);
    } else if char == {
        case #char "\"";        parse_string_literal(tokenizer, *token, char);
        case #char "'";         parse_string_literal(tokenizer,*token, char);
        case #char "/";         parse_slash_or_comment(tokenizer, *token);

        case #char ";";         token.type = .punctuation; token.punctuation = .semicolon; t += 1;
        case #char "{";         token.type = .punctuation; token.punctuation = .l_brace;   t += 1;
        case #char "}";         token.type = .punctuation; token.punctuation = .r_brace;   t += 1;
        case #char "(";         token.type = .punctuation; token.punctuation = .l_paren;   t += 1;
        case #char ")";         token.type = .punctuation; token.punctuation = .r_paren;   t += 1;
        case #char "[";         token.type = .punctuation; token.punctuation = .l_bracket; t += 1;
        case #char "]";         token.type = .punctuation; token.punctuation = .r_bracket; t += 1;

        case;                   token.type = .invalid; t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

parse_identifier :: (using tokenizer: *Tokenizer, token: *Token) {
    push_allocator(temp);
    token.type = .identifier;

    identifier_str := read_identifier_string(tokenizer);

    // need to do this if we want to use the same enum logic as in other parsers, not pretty but get's the job done.
    sanitized_string := replace(identifier_str, "-", "_");

    if sanitized_string.count <= MAX_KEYWORD_LENGTH {
        kw_token, ok := table_find(*KEYWORD_MAP, sanitized_string);
        if ok {
            token.type = kw_token.type;
            token.keyword = kw_token.keyword;
            return;
        }
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
    }
}

parse_slash_or_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    t += 1;
    if t >= max_t return;

    if << t == {
        case #char "/";
            token.type = .comment;
            t += 1;
            while t < max_t && << t != #char "\n" t += 1;
        case #char "*";
            token.type = .comment;
            t += 1;
            while t + 1 < max_t {
                if << t == #char "*" && << (t + 1) == #char "/" {
                  t += 2;
                  break;
                }
                t += 1;
            }
    }
}

parse_string_literal :: (using tokenizer: *Tokenizer, token: *Token, quote := #char "\"") {
     token.type = .string_literal;

     escape_seen := false;
     t += 1;

     while t < max_t {
        char := << t;
        if char == quote && !escape_seen break;
        escape_seen = !escape_seen && <<t == #char "\\";
        t += 1;
        if t >= max_t return;
     }
     t += 1;
}

read_identifier_string :: (using tokenizer: *Tokenizer) -> string {
    ret: string;
    ret.data = t;

    while t < max_t {
        c := <<t;
        if is_alnum(c) || c == #char "-"  { t += 1; continue; }
        break;
    }
    if t >= max_t then t = max_t;
    ret.count = xx (t - ret.data);

    return ret;
}

Token :: struct {
    using #as base: Base_Token;

    // Additional info to distinguish between keywords/punctuation
    union {
        keyword:            Keyword;
        punctuation:        Punctuation;
    }
}

// https://datatracker.ietf.org/doc/html/rfc7950
KEYWORDS :: string.[
    "module", "submodule", "anydata", "anyxml", "augment", "choice", "case", "contact", "container", "description",
    "deviation", "extension", "feature", "grouping", "identity", "import", "include", "leaf", "list", "namespace",
    "notification", "organization", "prefix", "reference", "revision", "rpc", "typedef", "uses", "default",
    "status", "type", "units", "base", "bit", "enum", "length", "path", "pattern", "range", "action", "must",
    "presence", "when", "mandatory", "unique", "refine", "input", "output", "value", "position", "key", "config",
    // These have '-' in the original language definition, but we cannot use those inside the enum,
    // so we define them with underscore here and replace with '-' in parse_identifier
    "leaf_list", "yang_version", "revision_date", "belongs_to", "fraction_digits", "require_instance", "if_feature",
    "error_app_tag", "error_message", "max_elements", "min_elements", "ordered_by", "yin_element",
];

TYPE_KEYWORDS :: string.[
    "int8", "int16", "int32", "int64", "uint8", "uint16", "uint32", "uint64", "decimal64", "string", "boolean",
    "enumeration", "bits", "binary", "leafref", "identityref", "empty", "union",
];

PUNCTUATION :: string.[
    "semicolon", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", "comma",
    "quotes" // not sure if quotes is correct here
];

// magic macro to define all the enums we just now defined :)
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
    define_enum(*b, "Keyword",     "kw_", .[KEYWORDS, TYPE_KEYWORDS]);

    return builder_to_string(*b);
}

Keyword_Token :: struct {
    type: Token_Type;
    keyword: Keyword;
}

KEYWORD_MAP :: #run -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    size := 10 * (KEYWORDS.count + TYPE_KEYWORDS.count);
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        for KEYWORDS       append(*b, sprint("table_add(*table, \"%\", Keyword_Token.{ type = .keyword, keyword = .kw_% });\n", it, it));
        for TYPE_KEYWORDS  append(*b, sprint("table_add(*table, \"%\", Keyword_Token.{ type = .type,    keyword = .kw_% });\n", it, it));
        return builder_to_string(*b);
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS       { if it.count > result then result = it.count; }
    for TYPE_KEYWORDS  { if it.count > result then result = it.count; }
    return xx result;
}

