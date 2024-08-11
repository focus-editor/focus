tokenize_css :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof  break;

        using tokenizer;

        memset(tokens.data + token.start, xx token.type, token.len);
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
        case #char ".";  parse_simple_selector(tokenizer, *token);
        case #char "#";  parse_hash(tokenizer, *token);
        case #char "/";  parse_slash_or_comment(tokenizer, *token);
        case #char "@";  parse_at(tokenizer, *token);
        case #char "\""; parse_double_quote_string_literal(tokenizer, *token);
        case #char "'";  parse_single_quote_string_literal(tokenizer, *token);
        case #char "!";  parse_bang(tokenizer, *token);

        case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;      t += 1;
        case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;      t += 1;
        case #char ":";  token.type = .punctuation; token.punctuation = .colon;        t += 1;
        case #char ";";  token.type = .punctuation; token.punctuation = .semicolon;    t += 1;
        case #char "-";  token.type = .punctuation; token.punctuation = .minus;        t += 1;
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

        case;           token.type = .invalid;                                         t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);

    return token;
}

read_css_identifier_string :: (using tokenizer: *Tokenizer) -> string {
    identifier: string;
    identifier.data = t;

    if !is_alnum(<<t) && <<t != #char "@" && <<t != #char "!" return identifier;

    t += 1;
    if t >= max_t then t = max_t;

    while t < max_t && is_alnum(<<t) || <<t == #char "-" {
        t += 1;
    }
    if t >= max_t then t = max_t;
    identifier.count = t - identifier.data;

    return identifier;
}

parse_identifier :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    identifier_str := read_css_identifier_string(tokenizer);

    // Maybe it's a tag
    if identifier_str.count <= MAX_TAG_LENGTH {
        token_type, ok := table_find(*TAG_MAP, identifier_str);
        if ok { token.type = token_type; return; }
    }

    // Maybe it's a property
    if identifier_str.count <= MAX_PROPERTY_LENGTH {
        token_type, ok := table_find(*PROPERTY_MAP, identifier_str);
        if ok { token.type = token_type; return; }
    }

    // Maybe it's a keyword
    if identifier_str.count <= MAX_KEYWORD_LENGTH {
        token_type, ok := table_find(*KEYWORD_MAP, identifier_str);
        if ok { token.type = token_type; return; }
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

    temp_t := t;

    unit_str := read_identifier_string(tokenizer);

    if unit_str.count <= MAX_UNIT_LENGTH {
        _, ok := table_find(*UNIT_MAP, unit_str);
        if !ok { t = temp_t; }
    }
}

parse_simple_selector :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

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
            while t + 1 < max_t {
                if << t == #char "*" && << (t + 1) == #char "/" {
                  t += 2;
                  break;
                }
                t += 1;
            }
    }
}

parse_at :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .invalid;

    identifier_str := read_css_identifier_string(tokenizer);

    property_token, ok := table_find(*PROPERTY_MAP, identifier_str);
    if ok { token.type = property_token.type; return; }
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

    parse_simple_selector(tokenizer, token);
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
    token.type = .identifier;

    identifier_str := read_css_identifier_string(tokenizer);

    if identifier_str.count <= MAX_KEYWORD_LENGTH {
        token_type, ok := table_find(*KEYWORD_MAP, identifier_str);
        if ok { token.type = token_type; return; }
    }
}

Token :: struct {
    start, len: s32;
    type: Token_Type;

    union {
        punctuation: Punctuation;
    }
}

PUNCTUATION :: string.[
    "semicolon", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", "comma",
    "colon", "minus", "star", "greater_than", "plus", "tilde", "equal", "slash",
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

PROPERTIES :: string.[
    "accent-color", "align-content", "align-items", "align-self", "all", "animation", "animation-delay",
    "animation-direction", "animation-duration", "animation-fill-mode", "animation-name", "animation-play-state",
    "animation-timing-function", "aspect-ratio",

    "backdrop-filter", "backface-visibility", "background", "background-attachment", "background-blend-mode",
    "background-clip", "background-color", "background-image", "background-origin", "background-position",
    "background-position-x", "background-position-y", "background-repeat", "background-size", "block-size",
    "border", "border-block", "border-block-color", "border-block-end", "border-block-end-color", "border-block-end-style",
    "border-block-end-width", "border-block-start", "border-block-start-color",
    "border-block-start-style", "border-block-start-width", "border-block-style", "border-block-width", "border-bottom",
    "border-bottom-color", "border-bottom-left-radius", "border-bottom-right-radius", "border-bottom-style",
    "border-bottom-width", "border-collapse", "border-color", "border-end-end-radius", "border-end-start-radius",
    "border-image", "border-image-outset", "border-image-repeat", "border-image-slice", "border-image-source",
    "border-image-width", "border-inline", "border-inline-color", "border-inline-end", "border-inline-end-color",
    "border-inline-end-style", "border-inline-end-width", "border-inline-start", "border-inline-start-color", "border-inline-start-width",
    "border-inline-style", "border-inline-width", "border-left", "border-left-color", "border-left-style", "border-left-width",
    "border-radius", "border-right", "border-right-color", "border-right-style", "border-right-width", "border-spacing",
    "border-start-end-radius", "border-start-start-radius", "border-style", "border-top", "border-top-color", "border-top-left-radius",
    "border-top-right-radius", "border-top-style", "border-top-width", "border-width", "bottom", "box-decoration-break", "box-reflect",
    "box-shadow", "box-sizing", "break-after", "break-before", "bread-inside",

    "caption-side", "caret-color", "clear", "clip", "clip-path", "color", "color-scheme", "column-count", "column-fill", "column-gap",
    "column-rule", "column-rule-color", "column-rule-style", "column-rule-width", "column-span", "column-width", "columns", "content",
    "counter-increment", "counter-set", "cursor",

    "direction", "display",

    "empty-cells",

    "filter", "flex", "flex-basis", "flex-direction", "flex-flow", "flex-grow", "flex-shrink", "flex-wrap", "float", "font", "font-family",
    "font-feature-settings", "font-kerning", "font-language-override", "font-size", "font-size-adjust", "font-stretch", "font-style",
    "font-synthesis", "font-variant", "font-variant-alternates", "font-variant-caps", "font-variant-east-asian", "font-variant-ligatures",
    "font-variant-numeric", "font-variant-position", "font-weight",

    "gap", "grid", "grid-area", "grid-auto-columns", "grid-auto-flow", "grid-auto-rows", "grid-column", "grid-column-end",
    "grid-column-gap", "grid-column-start", "grid-gap", "grid-row", "grid-row-end", "grid-row-gap", "grid-row-start", "grid-template",
    "grid-template-areas", "grid-template-columns", "grid-template-rows",

    "hanging-punctuation", "height", "hyphens", "hypenate-character",

    "image-rendering", "inline-size", "inset", "inset-block", "inset-block-end", "inset-block-start", "inset-inline", "inset-inline-end",
    "inset-inline-start", "isolation",

    "justify-content", "justify-items", "justify-self",

    "left", "letter-spacing", "line-break", "line-height", "list-style", "list-style-image", "list-style-position", "list-style-type",

    "margin", "margin-block", "margin-block-end", "margin-block-start", "margin-bottom", "margin-inline", "margin-inline-end",
    "margin-inline-start", "margin-left", "margin-right", "margin-top", "mask", "mask-clip", "mask-composite", "mask-image", "mask-mode",
    "mask-origin", "mask-position", "mask-repeat", "mask-size", "mask-type", "max-height", "max-width", "@media", "max-block-size",
    "max-inline-size", "min-block-size", "min-inline-size", "min-height", "min-width", "mix-blend-mode",

    "object-fit", "object-position", "offset", "offset-anchor", "offset-distance", "offset-path", "offset-rotate", "opacity", "order",
    "orphans", "outline", "outline-color", "outline-offset", "outline-style", "outline-width", "overflow", "overflow-anchor",
    "overflow-wrap", "overflow-x", "overflow-y", "overscroll-behaviour", "overscroll-behavious-block", "overscroll-behaviour-inline",
    "overscroll-behaviour-x", "overscroll-behaviour-y",

    "padding", "padding-block", "padding-block-end", "padding-block-start", "padding-bottom", "padding-inline", "padding-inline-end",
    "padding-inline-start", "padding-left", "padding-right", "padding-top", "page-break-after", "page-break-before", "page-break-inside",
    "paint-order", "perspective", "perspective-origin", "place-content", "place-items", "place-self", "pointer-events", "position",

    "quotes",

    "resize", "right", "rotate", "row-gap",

    "scale", "scroll-behaviour", "scroll-margin", "scroll-margin-block", "scroll-margin-block-end", "scroll-margin-block-start",
    "scroll-margin-bottom", "scroll-margin-inline", "scroll-margin-inline-end", "scroll-margin-inline-start", "scroll-margin-left",
    "scroll-margin-right", "scroll-margin-top", "scroll-padding", "scroll-padding-block", "scroll-padding-block-end",
    "scroll-padding-block-start", "scroll-padding-bottom", "scroll-padding-inline", "scroll-padding-inline-end",
    "scroll-padding-inline-start", "scroll-padding-left", "scroll-padding-right", "scroll-padding-top", "scroll-snap-align",
    "scroll-snap-stop", "scroll-snap-type", "scrollbar-color",

    "tab-size", "table-layout", "text-align", "text-align-last", "text-combine-upright", "text-decoration", "text-decoration-color",
    "text-decoration-line", "text-decoration-style", "text-decoration-thickness", "text-emphasis", "text-emphasis-color",
    "text-emphasis-style", "text-indent", "text-justify", "text-orientation", "text-overflow", "text-shadow", "text-transform",
    "text-underline-offset", "text-underline-position", "top", "transform", "transform-origin", "transform-style", "transition",
    "transition-delay", "transition-duration", "transition-property", "transition-timing-function", "translate",

    "unicode-bidi", "user-select",

    "vertical-align", "visibility",

    "white-space", "widows", "width", "word-break", "word-spacing", "word-wrap", "writing-mode",

    "z-index",
];

KEYWORDS :: string.[
    "!important", "initial", "inherit", "unset", "revert", "white", "black", "red", "green", "blue", "currentcolor", "transparent",
    "revert-layer", "underline", "bold", "italic", "square", "border-box", "solid", "none",
];

UNITS :: string.[
    // Local font-relative lenghts
    "cap", "ch", "em", "ex", "ic", "lh",

    // Root font-relative lengths
    "rcap", "rch", "rem", "rex", "ric", "rlh",

    // Viewport units
    "dvh", "dvw", "lvh", "lvw", "svh", "svw", "vb", "vh", "vi", "vmax", "vmin", "vw",

    // Container units
    "cqb", "cqh", "cqi", "cqmax", "cqmin", "cqw",

    // Absolute length units
    "cm", "in", "mm", "pc", "pt", "px", "Q",

    // Angle units
    "deg", "grad", "rad", "turn",

    // Time units
    "ms", "s",

    // Frequency units
    "Hz", "kHz",

    // Flex units
    "fr",

    // Resolution units
    "dpcm", "dpi", "dppx", "x",

    // Percentage
    "%",
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

PROPERTY_MAP :: #run -> Table(string, Token_Type) {
    table: Table(string, Token_Type);
    size := 10 * PROPERTIES.count;
    init(*table, size);

    #insert -> string {
        b: String_Builder;

        for PROPERTIES append(*b, sprint("table_add(*table, \"%1\", .function);\n", it));

        return builder_to_string(*b);
    }

    return table;
}

MAX_PROPERTY_LENGTH :: #run -> s32 {
    result: s64;
    for PROPERTIES { if it.count > result then result = it.count; }
    return xx result;
}

KEYWORD_MAP :: #run -> Table(string, Token_Type) {
    table: Table(string, Token_Type);
    size := 10 * KEYWORDS.count;
    init(*table, size);

    #insert -> string {
        b: String_Builder;

        for KEYWORDS append(*b, sprint("table_add(*table, \"%1\", .keyword);\n", it));

        return builder_to_string(*b);
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS { if it.count > result then result = it.count; }
    return xx result;
}

UNIT_MAP :: #run -> Table(string, Token_Type) {
    table: Table(string, Token_Type);
    size := 10 * UNITS.count;
    init(*table, size);

    #insert -> string {
        b: String_Builder;

        for UNITS append(*b, sprint("table_add(*table, \"%1\", .number);\n", it));

        return builder_to_string(*b);
    }

    return table;
}


MAX_UNIT_LENGTH :: #run -> s32 {
    result: s64;
    for UNITS { if it.count > result then result = it.count; }
    return xx result;
}