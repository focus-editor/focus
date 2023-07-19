highlight_c_syntax :: (using buffer: *Buffer) {
    tokenizer: Tokenizer = ---;
    tokenizer.buf   = to_string(bytes);
    tokenizer.max_t = bytes.data + bytes.count;
    tokenizer.t     = bytes.data;

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        using tokenizer;
        // Maybe retroactively highlight a function
        if token.type == .punctuation && token.punctuation == .l_paren {
            // Handle "func("
            prev := last_tokens[0];
            if prev.type == .identifier {
                memset(colors.data + prev.start, xx Code_Color.FUNCTION, prev.len);
            }
        }

        // Remember last tokens
        last_tokens[0] = token;


        color := COLOR_MAP[token.type];
        memset(colors.data + token.start, xx color, token.len);
    }
}

//~
#scope_file

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    t = eat_white_space(t, max_t);

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
        case #char "#";  parse_preprocessor_directive(tokenizer, *token);
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

    // mark := get_temporary_storage_mark();
    // defer   set_temporary_storage_mark(mark);

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
        // t += 1;
        // if t >= max_t return;

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
        is_hex :: inline (c: u8) -> bool {
            return is_digit(c) || (c >= #char "a" && c <= #char "f") || (c >= #char "A" && c <= #char "F");
        }

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

parse_preprocessor_directive :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    t += 1;
    t = eat_white_space(t, max_t);  // there may be spaces between the # and the name
    if !is_alpha(<<t) return;

    // mark := get_temporary_storage_mark();
    // defer   set_temporary_storage_mark(mark);

    directive_str := read_identifier_string(tokenizer);

    while t < max_t && is_alnum(<< t) t += 1;
    if t >= max_t return;

    // Check if it's one of the existing directives
    if directive_str.count > MAX_DIRECTIVE_LENGTH return;
    directive, ok := table_find(*PREPROCESSOR_DIRECTIVES_MAP, directive_str);
    if ok {
        token.type = .preprocessor_directive;
        token.preprocessor_directive = directive;
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

//~

Tokenizer :: struct {
    buf: string;
    max_t:   *u8;
    start_t: *u8;  // cursor when starting parsing new token
    t:       *u8;  // cursor

    last_tokens: [1] Token;  // to retroactively highlight functions
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
    .COMMENT,       // eof - obviously not used
    .DEFAULT,       // identifier
    .STRING,        // string_literal
    .STRING,        // char_literal
    .VALUE,         // number
    .COMMENT,       // comment
    .COMMENT,       // multiline_comment
    .OPERATION,     // operation
    .PUNCTUATION,   // punctuation
    .KEYWORD,       // keyword
    .KEYWORD,       // modifier_keyword
    .TYPE,          // type_keyword
    .VALUE_KEYWORD, // value_keyword
    .KEYWORD,       // preprocessor_directive
    .ERROR,         // invalid
];

Keyword :: enum u16 {
    kw_alignas;
    kw_alignof;
    kw_and;
    kw_and_eq;
    kw_asm;
    kw_auto;
    kw_bitand;
    kw_bitor;
    kw_break;
    kw_case;
    kw_catch;
    kw_class;
    kw_compl;
    kw_concept;
    kw_const_cast;
    kw_continue;
    kw_co_await;
    kw_co_return;
    kw_co_yield;
    kw_decltype;
    kw_default;
    kw_defined;
    kw_delete;
    kw_do;
    kw_dynamic_cast;
    kw_else;
    kw_enum;
    kw_explicit;
    kw_export;
    kw_for;
    kw_friend;
    kw_goto;
    kw_if;
    kw_namespace;
    kw_new;
    kw_not;
    kw_not_eq;
    kw_operator;
    kw_or;
    kw_or_eq;
    kw_private;
    kw_protected;
    kw_public;
    kw_reinterpret_cast;
    kw_requires;
    kw_return;
    kw_sizeof;
    kw_static_assert;
    kw_static_cast;
    kw_struct;
    kw_switch;
    kw_template;
    kw_throw;
    kw_try;
    kw_typedef;
    kw_typeid;
    kw_typename;
    kw_union;
    kw_using;
    kw_while;
    kw_xor;
    kw_xor_eq;
    kw__Alignas;
    kw__Alignof;
    kw__Atomic;
    kw__Generic;
    kw__Noreturn;
    kw__Static_assert;
    kw___asm;
    kw___asm__;
    kw___except;
    kw___finally;
    kw___leave;
    kw___try;

    kwv_false;
    kwv_nullptr;
    kwv_this;
    kwv_true;

    kwm_const;
    kwm_consteval;
    kwm_constexpr;
    kwm_constinit;
    kwm_extern;
    kwm_final;
    kwm_inline;
    kwm_mutable;
    kwm_noexcept;
    kwm_override;
    kwm_register;
    kwm_restrict;
    kwm_signed;
    kwm_static;
    kwm_thread_local;
    kwm_unsigned;
    kwm_virtual;
    kwm_volatile;
    kwm__Thread_local;

    // built-in types
    kwt_bool;
    kwt_char;
    kwt_char8_t;
    kwt_char16_t;
    kwt_char32_t;
    kwt_double;
    kwt_float;
    kwt_int;
    kwt_long;
    kwt_short;
    kwt_void;
    kwt_wchar_t;
    kwt__Bool;
    kwt__Complex;
    kwt__Imaginary;

    // stdint types
    kwt_int8_t;
    kwt_int16_t;
    kwt_int32_t;
    kwt_int64_t;
    kwt_uint8_t;
    kwt_uint16_t;
    kwt_uint32_t;
    kwt_uint64_t;
    kwt_int_least8_t;
    kwt_int_least16_t;
    kwt_int_least32_t;
    kwt_int_least64_t;
    kwt_uint_least8_t;
    kwt_uint_least16_t;
    kwt_uint_least32_t;
    kwt_uint_least64_t;
    kwt_int_fast8_t;
    kwt_int_fast16_t;
    kwt_int_fast32_t;
    kwt_int_fast64_t;
    kwt_uint_fast8_t;
    kwt_uint_fast16_t;
    kwt_uint_fast32_t;
    kwt_uint_fast64_t;
    kwt_intptr_t;
    kwt_uintptr_t;
    kwt_intmax_t;
    kwt_uintmax_t;
    kwt_wint_t;
    kwt_size_t;
    kwt_ptrdiff_t;
    kwt_sig_atomic_t;

    // some STL types
    kwt_vector;
    kwt_atomic;
    kwt_atomic_flag;
    kwt_array;
    kwt_map;
    kwt_unordered_map;
    kwt_set;
    kwt_unordered_set;
    kwt_queue;
    kwt_deque;
    kwt_tree;
    kwt_thread;
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

Directive :: enum u16 {
    di_define;
    di_elif;
    di_elifdef;
    di_elifndef;
    di_else;
    di_end;
    di_endif;
    di_error;
    di_if;
    di_ifdef;
    di_ifndef;
    di_include;
    di_line;
    di_pragma;
    di_undef;
    di_warning;
}

//- Keyword Specifics
Keyword_Token :: struct {
    type: Token.Type;
    keyword: Keyword;
}
KEYWORD_MAP :: #run -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    temp, keywords_count := enum_range(Keyword);
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

PREPROCESSOR_DIRECTIVES_MAP :: #run -> Table(string, Directive) {
    table: Table(string, Directive);
    temp, keywords_count := enum_range(Keyword);
    size := 2 * (keywords_count);
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        init_string_builder(*b);
        for enum_names(Directive) {
            print_to_builder(*b, "table_add(*table, \"%\", .%);\n",
                            slice(it, 3, it.count - 3), it);
        }
        return builder_to_string(*b);
    }

    return table;
}
MAX_DIRECTIVE_LENGTH :: #run -> s32 {
    max_len := 0;

    for enum_names(Directive) {
        actual := slice(it, 3, it.count - 3);
        if actual.count > max_len max_len = actual.count;
    }
    return xx max_len;
}


read_identifier_string :: (using tokenizer: *Tokenizer) -> string {
    ret: string;
    ret.data = t;

    while t < max_t {
        c := <<t;
        if is_alnum(c) { t += 1; continue; }
        break;
    }
    if t >= max_t then t = max_t;
    ret.count = xx (t - ret.data);

    return ret;
}

eat_white_space :: inline (start: *u8, max_t: *u8) -> *u8 {
    t := start;
    while t < max_t && is_white_space(<<t) {
        t += 1;
    }
    return t;
}

is_white_space :: inline (c: u8) -> bool {
    return c == #char " " || c == #char "\r" || c == #char "\n";
}

#run assert(enum_highest_value(Token.Type) == COLOR_MAP.count - 1);