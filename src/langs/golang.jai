highlight_golang_syntax :: (using buffer: *Buffer) {
    tokenizer := get_tokenizer(buffer);

    last_token: Token;

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        using tokenizer;
        // Maybe retroactively highlight a function
        if token.type == .punctuation && token.punctuation == .l_paren {
            // Handle "func("
            if last_token.type == .identifier {
                memset(colors.data + last_token.start, xx Color.CODE_FUNCTION, last_token.len);
            }
        }

        last_token = token;

        color := COLOR_MAP[token.type];
        memset(colors.data + token.start, xx color, token.len);
    }
}

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

    if is_alpha(char) || char == #char "_" {
        parse_identifier(tokenizer, *token);
    } else if is_digit(char) {
        parse_number(tokenizer, *token);
    } else if char == {
        case #char ":";  parse_colon                 (tokenizer, *token);
        case #char "?";  parse_question              (tokenizer, *token);
        case #char "=";  parse_equal                 (tokenizer, *token);
        case #char "-";  parse_minus                 (tokenizer, *token);
        case #char "+";  parse_plus                  (tokenizer, *token);
        case #char "*";  parse_asterisk              (tokenizer, *token);
        case #char "<";  parse_less_than             (tokenizer, *token);
        case #char ">";  parse_greater_than          (tokenizer, *token);
        case #char "!";  parse_bang                  (tokenizer, *token);
        case #char "\""; parse_string_literal        (tokenizer, *token);
        case #char "'";  parse_char_literal          (tokenizer, *token);
        case #char "/";  parse_slash_or_comment      (tokenizer, *token);
        case #char "&";  parse_ampersand             (tokenizer, *token);
        case #char "|";  parse_pipe                  (tokenizer, *token);
        case #char "%";  parse_percent               (tokenizer, *token);
        case #char "^";  parse_caret                 (tokenizer, *token);

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

    if is_digit(<< t) {
        // Decimal
        t += 1;
        seen_decimal_point := false;
        while t < max_t && (is_digit(<< t) || << t == #char ".") {
            if << t == #char "." {
                if seen_decimal_point break;
                seen_decimal_point = true;
            }
            t += 1;
        }
        if t >= max_t return;

        // exponent
        if << t == #char "e" || << t == #char "E" {
            t += 1;
            if t >= max_t return;

            if << t == #char "+" || << t == #char "-" {
              t += 1;
              if t >= max_t return;
            }

            while t < max_t && is_digit(<< t) {
                t += 1;
            }
            if t >= max_t return;
        }

        // suffixes
        if seen_decimal_point {
            if << t == #char "f" || << t == #char "F" || << t == #char "d" || << t == #char "D" {
              t += 1;
            }
        } else {

          // This is getting kindof hard to follow...
          if << t == #char "l" || << t == #char "L" {             // l
              t += 1;
              if t >= max_t return;

              if << t == #char "l" || << t == #char "L" {         // ll
                  t += 1;
                  if t >= max_t return;

                  if << t == #char "u" || << t == #char "U" {     // llu
                    t += 1;
                  }
              } else if << t == #char "u" || << t == #char "U" {  // lu
                t += 1;
              }
          } else if  << t == #char "u" || << t == #char "U" {     // u
              t += 1;
          }

        }

    } else if << t == #char "x" || << t == #char "X" {
        // Hex
        t += 1;
        while t < max_t && (is_hex(<< t)) t += 1;

    } else if << t == #char "b" || << t == #char "B" {
        // Binary
        t += 1;
        while t < max_t && (<< t == #char "1" || << t == #char "0") t += 1;
    }
}

parse_colon :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .colon;
    t += 1;
}

parse_question :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .question;
    t += 1;
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
            token.operation = .minus_minus;
            t += 1;
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

    if << t == {
        case #char "=";
            token.operation = .asterisk_equal;
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

parse_string_literal :: (using tokenizer: *Tokenizer, token: *Token) {
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

parse_char_literal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .char_literal;

    escape_seen := false;

    t += 1; //
    if t >= max_t || << t == #char "\n" return;

    if << t == #char "\\" {
      escape_seen = true;
      t += 1;
      if t >= max_t || << t == #char "\n" return;
    }

    if << t == #char "'" && !escape_seen {
      // not escaped single quote without a character
      token.type = .invalid;
      t += 1; // the invalid '
      return;
    }

    t += 1; // the char
    if t >= max_t || << t == #char "\n" return;

    t += 1; // ending '
}

parse_slash_or_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .slash;

    t += 1;
    if t >= max_t return;

    if << t == {
        case #char "=";
            token.operation = .slash_equal;
            t += 1;
        case #char "/";
            token.type = .comment;
            t += 1;
            while t < max_t && << t != #char "\n" t += 1;
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

Token :: struct {
    start, len: s32;
    type: Type;

    union {
        keyword:                Keyword;
        punctuation:            Punctuation;
        operation:              Operation;
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
        invalid;
    }
}

// Must match the order of the types in the enum above
COLOR_MAP :: Color.[
    .CODE_COMMENT,       // eof - obviously not used
    .CODE_DEFAULT,       // identifier
    .CODE_STRING,        // string_literal
    .CODE_STRING,        // char_literal
    .CODE_VALUE,         // number
    .CODE_COMMENT,       // comment
    .CODE_COMMENT,       // multiline_comment
    .CODE_OPERATION,     // operation
    .CODE_PUNCTUATION,   // punctuation
    .CODE_KEYWORD,       // keyword
    .CODE_KEYWORD,       // modifier_keyword
    .CODE_TYPE,          // type_keyword
    .CODE_VALUE,         // value_keyword
    .CODE_ERROR,         // invalid
];

Keyword :: enum u16 {
    kw_break;
    kw_case;
    kw_chan;
    kw_continue;
    kw_default;
    kw_defer;
    kw_else;
    kw_fallthrough;
    kw_for;
    kw_func;
    kw_go;
    kw_goto;
    kw_if;
    kw_import;
    kw_interface;
    kw_map;
    kw_package;
    kw_range;
    kw_return;
    kw_select;
    kw_struct;
    kw_switch;
    kw_type;
    kw_var;

    kwv_false;
    kwv_true;
    kwv_nil;

    kwm_const;

    // built-in types
    kwt_bool;
    kwt_string;
    kwt_int8;
    kwt_uint8;
    kwt_byte;
    kwt_int16;
    kwt_uint16;
    kwt_int32;
    kwt_rune;
    kwt_uint32;
    kwt_int64;
    kwt_uint64;
    kwt_int;
    kwt_uint;
    kwt_uintptr;
    kwt_float32;
    kwt_float64;
    kwt_complex64;
    kwt_complex128;
    kwt_error;
}

Operation :: enum u16 {
    arrow;
    bang;
    backtick;
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

//- Keyword Specifics
Keyword_Token :: struct {
    type: Token.Type;
    keyword: Keyword;
}
// KEYWORD_MAP: Table(string, Keyword_Token);
KEYWORD_MAP :: #run -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    // _, keywords_count := enum_range(Keyword);
    keywords_count := 100;
    size := 2 * (keywords_count);
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        init_string_builder(*b);
        curr_type := "keyword";
        curr_slice_count := 3;
        for enum_names(Keyword) {
            if starts_with(it, "kwt") {
                curr_type = "type_keyword";
                curr_slice_count = 4;
            } else if starts_with(it, "kwm") {
                curr_type = "modifier_keyword";
                curr_slice_count = 4;
            } else if starts_with(it, "kwv") {
                curr_type = "value_keyword";
                curr_slice_count = 4;
            } else {
                curr_type = "keyword";
                curr_slice_count = 3;
            }

            print_to_builder(*b, "table_add(*table, \"%\", Keyword_Token.{type = .%, keyword = .%});\n",
                            slice(it, curr_slice_count, it.count - curr_slice_count), curr_type, it);
        }
        return builder_to_string(*b);
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    max_len := 0;

    curr_slice_count := 3;

    for enum_names(Keyword) {
        if starts_with(it, "kwt") curr_slice_count = 4;
        else if starts_with(it, "kwm") curr_slice_count = 4;
        else if starts_with(it, "kwv") curr_slice_count = 4;
        else curr_slice_count = 3;

        actual := slice(it, curr_slice_count, it.count - curr_slice_count);
        if actual.count > max_len max_len = actual.count;
    }
    return xx max_len;
}

#run assert(enum_highest_value(Token.Type) == COLOR_MAP.count - 1);