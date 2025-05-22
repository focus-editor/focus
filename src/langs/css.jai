tokenize_css :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof  break;

        using tokenizer;

        highlight_token(buffer, token);
    }

    return .[];
}

get_next_css_token :: get_next_token;  // export for indent tokenization

#scope_file

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;

    // Look at the first char as if it's ASCII (if it isn't, this is just a text line)
    char := << t;

    if is_alpha(char) {
        parse_identifier(tokenizer, *token);
    } else if is_digit(char) {
        parse_number(tokenizer, *token);
    } else if char == {
        case #char ".";  parse_selector(tokenizer, *token);
        case #char "#";  parse_hash(tokenizer, *token);
        case #char "/";  parse_slash_or_comment(tokenizer, *token);
        case #char "@";  parse_at(tokenizer, *token);
        case #char "\""; parse_double_quote_string_literal(tokenizer, *token);
        case #char "'";  parse_single_quote_string_literal(tokenizer, *token);
        case #char "!";  parse_bang(tokenizer, *token);
        case #char "-";  parse_dash(tokenizer, *token);

        case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;      t += 1;
        case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;      t += 1;
        case #char ";";  token.type = .punctuation; token.punctuation = .semicolon;    t += 1;
        case #char ":";  token.type = .punctuation; token.punctuation = .colon;        t += 1;
        case #char ",";  token.type = .punctuation; token.punctuation = .comma;        t += 1;
        case #char "*";  token.type = .punctuation; token.punctuation = .star;         t += 1;
        case #char ">";  token.type = .punctuation; token.punctuation = .greater_than; t += 1;
        case #char "+";  token.type = .punctuation; token.punctuation = .plus;         t += 1;
        case #char "~";  token.type = .punctuation; token.punctuation = .tilde;        t += 1;
        case #char "[";  token.type = .punctuation; token.punctuation = .l_bracket;    t += 1;
        case #char "]";  token.type = .punctuation; token.punctuation = .r_bracket;    t += 1;
        case #char "=";  token.type = .punctuation; token.punctuation = .equal;        t += 1;
        case #char "(";  token.type = .punctuation; token.punctuation = .l_paren;      t += 1;
        case #char ")";  token.type = .punctuation; token.punctuation = .r_paren;      t += 1;
        case #char "&";  token.type = .punctuation; token.punctuation = .ampersand;    t += 1;

        case;           token.type = .invalid;                                         t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);

    return token;
}

peek_next_token :: (using tokenizer: Tokenizer) -> Token {
    tokenizer_copy := tokenizer;
    return get_next_token(*tokenizer_copy);
}

read_css_identifier_string :: (using tokenizer: *Tokenizer) -> string {
    identifier: string;
    identifier.data = t;

    if !is_alnum(<<t) && <<t != #char "@" && <<t != #char "!" return identifier;

    t += 1;
    if t >= max_t then t = max_t;

    while t < max_t && (is_alnum(<<t) || <<t == #char "-") {
        t += 1;
    }
    if t >= max_t then t = max_t;
    identifier.count = t - identifier.data;

    return identifier;
}

parse_identifier :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    identifier_str := read_css_identifier_string(tokenizer);

    next_token := peek_next_token(tokenizer);

    if !(next_token.type == .punctuation && next_token.punctuation == .l_paren) {
        // Maybe it's a tag
        if identifier_str.count <= MAX_TAG_LENGTH {
            token_type, ok := table_find(*TAG_MAP, identifier_str);
            if ok { token.type = token_type; return; }
        }
    }

    if next_token.type == .punctuation {
        if next_token.punctuation == {
            case .l_paren; #through;
            case .colon;
                token.type = .function;
        }
    }
}

parse_number :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .number;

    start_char := t.*;

    t += 1;
    if t >= max_t return;

    // Number
    seen_decimal_point := false;
    while t < max_t && (is_digit(t.*) || t.* == #char ".") {
        if t.* == #char "." {
            if seen_decimal_point break;
            seen_decimal_point = true;
        }
        t += 1;
    }

    if t >= max_t return;

    // Unit
    if <<t == #char "%" {
        t += 1;
        return;
    }

    read_identifier_string(tokenizer);
}

parse_selector :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .keyword;

    t += 1;
    if t >= max_t  return;

    identifier_str := read_css_identifier_string(tokenizer);
}

parse_slash_or_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .punctuation;
    token.punctuation = .slash;

    t += 1;
    if t >= max_t return;

    if << t == {
        case #char "*";
            token.type = .multiline_comment;
            t += 1;

            while t < max_t {
              if <<t == #char "*" {
                if t + 1 < max_t && <<(t + 1) == #char "/" {
                  t += 2; // Both the * and /
                  break;
                }
              }

              t += 1;
            }

        case #char "/";
            token.type = .comment;
            t += 1;

            while t < max_t && <<t != #char "\n"  t += 1;
    }
}

parse_at :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .keyword;

    identifier_str := read_css_identifier_string(tokenizer);
}

parse_double_quote_string_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .string_literal;

    escape_seen := false;

    t += 1;
    while t < max_t && << t != #char "\n" {
        if <<t == #char "\"" && !escape_seen break;
        escape_seen = !escape_seen && <<t == #char "\\";
        t += 1;
    }
    if t >= max_t return;

    t += 1;
}

parse_single_quote_string_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .string_literal;

    escape_seen := false;

    t += 1;
    while t < max_t && << t != #char "\n" {
        if <<t == #char "'" && !escape_seen break;
        escape_seen = !escape_seen && <<t == #char "\\";
        t += 1;
    }
    if t >= max_t return;

    t += 1;
}

parse_hash :: (using tokenizer: *Tokenizer, token: *Token) {
    if parse_hex_color(tokenizer, token) {
        return;
    }

    parse_selector(tokenizer, token);
}

parse_hex_color :: (using tokenizer: *Tokenizer, token: *Token) -> bool {
    temp_t := t + 1;

    if temp_t >= max_t  return false;

    while is_hex(<<temp_t) {
        temp_t += 1;
        if temp_t >= max_t  return false;
    }

    diff := temp_t - t - 1; // Account for the #

    if diff == 3 || diff == 6 {
        t = temp_t;
        token.type = .number;

        return true;
    }

    return false;
}

parse_bang :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .keyword;

    identifier_str := read_css_identifier_string(tokenizer);
}

parse_dash :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .punctuation;
    token.punctuation = .minus;

    t += 1;
    if t >= max_t  return;

    // CSS variable
    if <<t == #char "-" {
        token.type = .identifier;

        t += 1;
        if t >= max_t  return;

        read_css_identifier_string(tokenizer);
    }
}

Token :: struct {
    using #as base: Base_Token;

    union {
        punctuation: Punctuation;
    }
}

PUNCTUATION :: string.[
    "semicolon", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", "comma",
    "colon", "minus", "star", "greater_than", "plus", "tilde", "equal", "slash", "ampersand",
];

TAGS :: string.[
    "a", "abbr", "address", "area", "article", "aside", "audio", "b", "base", "bdi", "bdo", "blockquote", "body", "br",
    "button", "canvas", "caption", "cite", "code", "col", "colgroup", "data", "datalist", "dd", "del", "details", "dfn",
    "dialog", "div", "dl", "dt", "em", "embed", "fieldset", "figcaption", "figure", "footer", "form", "h1", "h2", "h3",
    "h4", "h5", "h6", "head", "header", "hgroup", "hr", "html", "i", "iframe", "img", "input", "ins", "kbd", "label",
    "legend", "li", "link", "main", "map", "mark", "menu", "meta", "meter", "nav", "noscript", "object", "ol", "optgroup",
    "option", "output", "p", "param", "picture", "pre", "progress", "q", "rp", "rt", "ruby", "s", "samp", "script", "search",
    "section", "select", "small", "source", "span", "strong", "style", "sub", "summary", "sup", "svg", "table", "tbody",
    "td", "template", "textarea", "tfoot", "th", "thead", "time", "title", "tr", "track", "u", "ul", "var", "video", "wbr",
];

#insert -> string {
    b: String_Builder;
    init_string_builder(*b);

    define_enum :: (b: *String_Builder, enum_name: string, prefix: string, value_list: [][] string) {
        print_to_builder(b, "% :: enum u16 {\n", enum_name);

        for values: value_list {
            for v: values {
                print_to_builder(b, "    %0%;\n", prefix, v);
            }
        }

        print_to_builder(b, "}\n");
    }

    define_enum(*b, "Punctuation", "", .[PUNCTUATION]);

    return builder_to_string(*b);
}

TAG_MAP :: #run -> Table(string, Token_Type) {
    table: Table(string, Token_Type);
    size := 10 * TAGS.count;
    init(*table, size);

    #insert -> string {
        b: String_Builder;

        for TAGS append(*b, sprint("table_add(*table, \"%1\", .keyword);\n", it));

        return builder_to_string(*b);
    }

    return table;
}

MAX_TAG_LENGTH :: #run -> s32 {
    result: s64;
    for TAGS { if it.count > result then result = it.count; }
    return xx result;
}
