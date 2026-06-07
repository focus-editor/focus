tokenize_vhdl :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
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

        highlight_token(buffer, token);
    }

    return .[];
}

get_next_vhdl_token :: get_next_token;  // export for indent tokenization

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

    if ascii_is_alpha(char) || char == #char "_" {
        // Parse identifiers which start with an ASCII letter or _
        // We'll look at identifiers which start with UTF8 letters later when we've already checked for more probable possibilities
        parse_identifier(tokenizer, *token);
    } else if ascii_is_digit(char) {
        parse_number_vhdl(tokenizer, *token);
    } else if char == {
        case #char ":";  parse_colon                 (tokenizer, *token);
        case #char "=";  parse_equal                 (tokenizer, *token);
        case #char "-";  parse_minus                 (tokenizer, *token);
        case #char "+";  parse_plus                  (tokenizer, *token);
        case #char "*";  parse_asterisk              (tokenizer, *token);
        case #char "<";  parse_less_than             (tokenizer, *token);
        case #char ">";  parse_greater_than          (tokenizer, *token);
        case #char "!";  parse_bang                  (tokenizer, *token);
        case #char "\""; parse_string_literal        (tokenizer, *token);
        case #char "'";  parse_tick_or_char_literal  (tokenizer, *token);
        case #char "/";  parse_slash_or_comment      (tokenizer, *token);
        case #char "&";  parse_ampersand             (tokenizer, *token);
        case #char "|";  parse_pipe                  (tokenizer, *token);
        case #char "%";  parse_percent               (tokenizer, *token);
        case #char "^";  parse_caret                 (tokenizer, *token);
        case #char "\\"; parse_extended_identifier   (tokenizer, *token);

        case #char ";";  token.type = .punctuation; token.punctuation = .semicolon; t += 1;
        case #char ",";  token.type = .punctuation; token.punctuation = .comma;     t += 1;
        case #char ".";  token.type = .punctuation; token.punctuation = .period;    t += 1;
        case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;   t += 1;
        case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;   t += 1;
        case #char "(";  token.type = .punctuation; token.punctuation = .l_paren;   t += 1;
        case #char ")";  token.type = .punctuation; token.punctuation = .r_paren;   t += 1;
        case #char "[";  token.type = .punctuation; token.punctuation = .l_bracket; t += 1;
        case #char "]";  token.type = .punctuation; token.punctuation = .r_bracket; t += 1;

        case #char "~";  token.type = .operation;   token.operation   = .tilde;     t += 1;
        case #char "`";  token.type = .operation;   token.operation   = .backtick;  t += 1;
        case #char "?";  token.type = .operation;   token.operation   = .question;  t += 1;

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

    // Maybe it's a keyword (VHDL is case-insensitive). We use equal_nocase to avoid
    // allocating a lowered copy via to_lower_copy on every identifier.
    if identifier_str.count <= MAX_KEYWORD_LENGTH {
        for entry : KEYWORD_ENTRIES {
            if entry.name.count != identifier_str.count continue;
            if equal_nocase(identifier_str, entry.name) {
                token.type = entry.type;
                token.keyword = entry.keyword;
                return;
            }
        }
    }
}

parse_extended_identifier :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    t += 1;  // skip opening backslash
    while t < max_t && t.* != #char "\\" && t.* != #char "\n" {
        t += 1;
    }
    if t < max_t && t.* == #char "\\" {
        t += 1;  // skip closing backslash
    }
}

parse_colon :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .colon;
    t += 1;

    if t >= max_t return;

    if t.* == #char "=" {
        token.operation = .variable_assignment;
        t += 1;
    }
}

parse_equal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .equal;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";  token.operation = .equal_equal; t += 1;
        case #char ">";  token.operation = .arrow;       t += 1;
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
        case #char "-";
            token.type = .comment;
            t += 1;
            while t < max_t && t.* != #char "\n" t += 1;
        case;
            if ascii_is_digit(t.*) parse_number_vhdl(tokenizer, token);
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
        case #char "*";
            token.operation = .exponent;
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
        case #char ">";
            token.operation = .double_greater_than;
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

    t += 1;
    while t < max_t && t.* != #char "\n" {
        if t.* == #char "\"" {
            t += 1;
            if t >= max_t || t.* != #char "\"" break;
            // "" is an escaped quote inside the string, continue
        }
        t += 1;
    }
    if t >= max_t return;

    // t is now after the closing "
}

parse_tick_or_char_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    // Could be a character literal 'x' or an attribute tick '
    t += 1;  // consume opening '
    if t >= max_t {
        token.type = .operation;
        token.operation = .tick;
        return;
    }

    // Check for character literal: 'X' where X is a single graphic char (not ')
    if t.* != #char "'" && t.* != #char "\n" {
        next := t + 1;
        if next < max_t && next.* == #char "'" {
            // It's a character literal 'X'
            token.type = .char_literal;
            t += 2;  // consume char and closing '
            return;
        }
    }

    // Otherwise it's a tick (attribute) operator
    token.type = .operation;
    token.operation = .tick;
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
            // VHDL has no // comments, only -- handled in parse_minus
            // But /= is not-equal, already handled above via colon/equal logic? No, /= starts with /
            // Actually in VHDL /= is not-equal. We already have bang_equal for !=.
            // For /= we'll treat / as slash and = as equal? No, we need to handle it.
            // Let's handle /= here.
            token.operation = .not_equal;
            t += 1;
        case #char "*";
            // Some VHDL tools support /* */ block comments (non-standard but common)
            token.type = .multiline_comment;
            t += 1;
            while t < max_t {
                if t.* == #char "*" && (t + 1) < max_t && (t + 1).* == #char "/" {
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

parse_number_vhdl :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .number;

    start_char := t.*;

    t += 1;
    if t >= max_t return;

    // Handle based literals: 2#...#, 8#...#, 16#...#, etc.
    if start_char == #char "0" || ascii_is_digit(start_char) {
        // Check for base prefix like 2# 16# etc.
        // A based literal looks like: 16#FF# or 2#1010_1010#
        // First, we may have digits before # for the base
        base_end := t;
        while base_end < max_t && (ascii_is_alnum(base_end.*) || base_end.* == #char "_") {
            base_end += 1;
        }
        if base_end < max_t && base_end.* == #char "#" {
            // This looks like a based literal: <base>#<value>#
            t = base_end + 1;  // skip to after first #
            // Now read until closing #
            while t < max_t && t.* != #char "#" && t.* != #char "\n" {
                t += 1;
            }
            if t < max_t && t.* == #char "#" {
                t += 1;
            }
            return;
        }
    }

    // Decimal or real number with possible underscores and exponent
    if is_digit(start_char) || start_char == #char "." {
        seen_decimal := start_char == #char ".";

        while t < max_t && (is_digit(t.*) || t.* == #char "_" || t.* == #char ".") {
            if t.* == #char "." {
                if seen_decimal break;
                seen_decimal = true;
            }
            t += 1;
        }

        // Exponent e/E or just a letter for based literal suffix? VHDL uses e/E for exponent
        if t < max_t && (t.* == #char "e" || t.* == #char "E") {
            t += 1;
            if t < max_t && (t.* == #char "+" || t.* == #char "-") {
                t += 1;
            }
            while t < max_t && (is_digit(t.*) || t.* == #char "_") {
                t += 1;
            }
        }
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

PUNCTUATION :: string.[
    "semicolon", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", "period", "comma",
];

OPERATIONS :: string.[
    "arrow", "bang", "backtick", "pipe", "double_pipe", "pipe_equal", "equal", "equal_equal", "bang_equal",
    "percent", "percent_equal", "less_than", "double_less_than", "less_than_equal", "greater_than",
    "greater_than_equal", "double_greater_than", "minus", "minus_equal", "minus_minus", "asterisk",
    "asterisk_equal", "colon", "slash", "plus", "plus_equal", "plus_plus", "slash_equal", "ampersand",
    "ampersand_equal", "tilde", "question", "unknown", "caret", "caret_equal", "tick", "not_equal",
    "variable_assignment", "exponent",
];

KEYWORDS :: string.[
    "abs", "access", "after", "alias", "all", "and", "architecture", "array", "assert", "assume",
    "assume_guarantee", "attribute", "begin", "block", "body", "buffer", "bus", "case", "component",
    "configuration", "constant", "context", "cover", "default", "disconnect", "downto", "else", "elsif",
    "end", "entity", "exit", "fairness", "file", "for", "force", "function", "generate", "generic",
    "group", "guarded", "if", "impure", "in", "inertial", "inout", "is", "label", "library", "linkage",
    "literal", "loop", "map", "mod", "nand", "new", "next", "nor", "not", "null", "of", "on", "open",
    "or", "others", "out", "package", "parameter", "port", "postponed", "procedure", "process",
    "property", "protected", "pure", "range", "record", "register", "reject", "release", "rem", "report",
    "restrict", "restrict_guarantee", "return", "rol", "ror", "select", "sequence", "severity", "shared",
    "signal", "sla", "sll", "sra", "srl", "strong", "subtype", "then", "to", "transport", "type",
    "unaffected", "units", "until", "use", "variable", "vmode", "vprop", "vunit", "wait", "when",
    "while", "with", "xnor", "xor",
];

TYPE_KEYWORDS :: string.[
    "bit", "bit_vector", "boolean", "character", "integer", "natural", "positive", "real", "severity_level",
    "std_logic", "std_logic_vector", "std_ulogic", "std_ulogic_vector", "string", "time", "signed", "unsigned",
    "sfixed", "ufixed", "float", "real_vector", "integer_vector", "boolean_vector",
];

VALUE_KEYWORDS :: string.[
    "true", "false",
];

MODIFIER_KEYWORDS :: string.[
    // Note: many declaration-kind words like constant/signal/variable are reserved words
    // and are listed in KEYWORDS to avoid duplication. They will be highlighted as .keyword.
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

Keyword_Entry :: struct {
    name: string;
    type: Token_Type;
    keyword: Keyword;
}

KEYWORD_ENTRIES :: #run -> [] Keyword_Entry {
    entries: [..] Keyword_Entry;
    #insert -> string {
        b: String_Builder;
        init_string_builder(*b);
        for KEYWORDS          append(*b, sprint("array_add(*entries, Keyword_Entry.{ name = \"%1\", type = .keyword,  keyword = .kw_%1 });\n", it));
        for TYPE_KEYWORDS     append(*b, sprint("array_add(*entries, Keyword_Entry.{ name = \"%1\", type = .type,     keyword = .kw_%1 });\n", it));
        for VALUE_KEYWORDS    append(*b, sprint("array_add(*entries, Keyword_Entry.{ name = \"%1\", type = .value,    keyword = .kw_%1 });\n", it));
        for MODIFIER_KEYWORDS append(*b, sprint("array_add(*entries, Keyword_Entry.{ name = \"%1\", type = .modifier, keyword = .kw_%1 });\n", it));
        return builder_to_string(*b);
    }
    return entries;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS          { if it.count > result then result = it.count; }
    for TYPE_KEYWORDS     { if it.count > result then result = it.count; }
    for VALUE_KEYWORDS    { if it.count > result then result = it.count; }
    for MODIFIER_KEYWORDS { if it.count > result then result = it.count; }
    return xx result;
}
