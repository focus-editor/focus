// MATLAB language support (syntax highlighting only).
//
// NOTE: .m files use the existing .Cpp highlighting path for Objective-C by default.
// MATLAB users should opt in per project with a file association, e.g. `*.m : matlab`.

tokenize_matlab :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_matlab_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof then break;

        prev := tokenizer.last_token;

        if (token.type == .punctuation && token.punctuation == .l_paren) && prev.type == .identifier {
            memset(tokens.data + prev.start, xx Token_Type.function, prev.len);
        }

        is_decl_name := update_function_decl_state(*tokenizer, token);

        if is_decl_name {
            memset(tokens.data + token.start, xx Token_Type.function, token.len);
        } else {
            highlight_token(buffer, token);
        }

        tokenizer.last_token = token;
    }

    return .[];
}

#scope_file

// Tracks a minimal physical-line state from the `function` keyword to the end of that
// line, so that we can highlight the declared function name without mixing it up with
// output variables: `function foo`, `function y = foo`, `function [a, b] = foo`.
// Returns true when the token is the declared function name.
update_function_decl_state :: (using tokenizer: *Matlab_Tokenizer, token: Token) -> bool {
    // The declaration only spans the physical line it started on
    if function_decl_state != .none && token.start >= function_decl_line_end {
        function_decl_state = .none;
    }

    if function_decl_state == {
        case .none;
            if token.type == .keyword && token.keyword == .kw_function {
                function_decl_state = .expect_name_or_outputs;
                newline := find_index_from_left(buf, "\n", start_index = token.start);
                function_decl_line_end = ifx newline >= 0 then newline else buf.count;
            }

        case .expect_name_or_outputs;
            if token.type == .identifier {
                if is_function_output_variable(tokenizer) {
                    function_decl_state = .expect_name;
                } else {
                    function_decl_state = .none;  // `function foo` or `function foo(x)`
                    return true;
                }
            } else if token.type == .punctuation && token.punctuation == .l_bracket {
                function_decl_state = .in_outputs;
            } else if token.type == .comment || token.type == .multiline_comment {
                function_decl_state = .none;
            }

        case .in_outputs;
            if token.type == .punctuation && token.punctuation == .r_bracket {
                function_decl_state = .expect_name;
            }

        case .expect_name;
            if token.type == .identifier {
                function_decl_state = .none;
                return true;
            }
    }

    return false;
}

is_function_output_variable :: (using tokenizer: *Matlab_Tokenizer) -> bool {
    // In `function y = foo` the y is an output variable, not the function name.
    // The tokenizer cursor is right after the candidate identifier.
    p := t;
    while p < max_t && (p.* == #char " " || p.* == #char "\t") p += 1;
    return p < max_t && p.* == #char "=";
}

get_matlab_tokenizer :: (using buffer: Buffer, start_offset := -1, count := -1) -> Matlab_Tokenizer {
    tokenizer: Matlab_Tokenizer;

    tokenizer.buf   = to_string(bytes);
    tokenizer.max_t = bytes.data + bytes.count;
    tokenizer.t     = bytes.data;

    if start_offset >= 0 {
        start_offset = clamp(start_offset, 0, bytes.count - 1);
        count        = clamp(count,        0, bytes.count - 1);
        tokenizer.t += start_offset;
        tokenizer.max_t = tokenizer.t + count;
    }

    return tokenizer;
}

get_next_token :: (using tokenizer: *Matlab_Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token := Token.{
        start = cast(s32) (t - buf.data),
        type = .eof
    };

    if t >= max_t then return token;
    start_t = t;

    // Assume ASCII, unless we're in the middle of a string.
    // UTF-8 characters elsewhere are a syntax error.
    // MATLAB identifiers must start with a letter (digits and _ may follow).
    char := t.*;

    if ascii_is_alpha(char) {
        parse_identifier(tokenizer, *token);
    } else if ascii_is_digit(char) {
        parse_number(tokenizer, *token);
    } else if char == {
        case #char "%";  parse_percent        (tokenizer, *token);
        case #char "\""; parse_string_literal (tokenizer, *token);
        case #char "'";  parse_quote          (tokenizer, *token);
        case #char ".";  parse_period         (tokenizer, *token);
        case #char "=";  parse_equal          (tokenizer, *token);
        case #char "~";  parse_tilde          (tokenizer, *token);
        case #char "<";  parse_less_than      (tokenizer, *token);
        case #char ">";  parse_greater_than   (tokenizer, *token);
        case #char "&";  parse_ampersand      (tokenizer, *token);
        case #char "|";  parse_pipe           (tokenizer, *token);

        case #char ":"; token.type = .operation;   token.operation   = .colon;     t += 1;
        case #char "@"; token.type = .operation;   token.operation   = .at;        t += 1;
        case #char "+"; token.type = .operation;   token.operation   = .plus;      t += 1;
        case #char "-"; token.type = .operation;   token.operation   = .minus;     t += 1;
        case #char "*"; token.type = .operation;   token.operation   = .asterisk;  t += 1;
        case #char "/"; token.type = .operation;   token.operation   = .slash;     t += 1;
        case #char "\\"; token.type = .operation;  token.operation   = .backslash; t += 1;
        case #char "^"; token.type = .operation;   token.operation   = .caret;     t += 1;

        case #char ","; token.type = .punctuation; token.punctuation = .comma;     t += 1;
        case #char ";"; token.type = .punctuation; token.punctuation = .semicolon; t += 1;
        case #char "("; token.type = .punctuation; token.punctuation = .l_paren;   t += 1;
        case #char ")"; token.type = .punctuation; token.punctuation = .r_paren;   t += 1;
        case #char "{"; token.type = .punctuation; token.punctuation = .l_brace;   t += 1;
        case #char "}"; token.type = .punctuation; token.punctuation = .r_brace;   t += 1;
        case #char "["; token.type = .punctuation; token.punctuation = .l_bracket; t += 1;
        case #char "]"; token.type = .punctuation; token.punctuation = .r_bracket; t += 1;

        case;            token.type = .invalid; t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

parse_identifier :: (using tokenizer: *Matlab_Tokenizer, token: *Token) {
    token.type = .identifier;
    ident := read_identifier_string(tokenizer);

    if ident.count > MAX_KEYWORD_LENGTH then return;
    ok, kw_token := table_find(*KEYWORD_MAP, ident);
    if !ok then return;

    token.type    = kw_token.type;
    token.keyword = kw_token.keyword;
}

parse_number :: (using tokenizer: *Matlab_Tokenizer, token: *Token) {
    token.type = .number;

    while t < max_t && ascii_is_digit(t.*) t += 1;

    // Fractional part. A '.' followed by another '.' starts an ellipsis, so don't consume it here
    if t < max_t && t.* == #char "." && (t + 1 >= max_t || (t + 1).* != #char ".") {
        t += 1;
        while t < max_t && ascii_is_digit(t.*) t += 1;
    }

    // Exponent, only when at least one digit follows
    if t < max_t && (t.* == #char "e" || t.* == #char "E") {
        p := t + 1;
        if p < max_t && (p.* == #char "+" || p.* == #char "-") p += 1;
        if p < max_t && ascii_is_digit(p.*) {
            t = p;
            while t < max_t && ascii_is_digit(t.*) t += 1;
        }
    }

    // Imaginary unit suffix: 1i, 2j, 3.2i
    if t < max_t && (t.* == #char "i" || t.* == #char "j") t += 1;
}

parse_percent :: (using tokenizer: *Matlab_Tokenizer, token: *Token) {
    token.type = .comment;

    // %{ ... %} block comments require the delimiters to be alone on their lines,
    // so a %{ appearing inside an expression is still just a line comment
    if at_string(tokenizer, "%{") && only_whitespace_before_on_line(tokenizer) && rest_of_line_is_whitespace(t + 2, max_t) {
        parse_block_comment(tokenizer, token);
        return;
    }

    // A %% section line is just a line comment for our purposes
    eat_until_newline(tokenizer);
    t += 1;
}

parse_block_comment :: (using tokenizer: *Matlab_Tokenizer, token: *Token) {
    token.type = .multiline_comment;

    t += 2;  // skip %{

    while t < max_t {
        // The closing delimiter is a line containing only whitespace and %}
        p := t;
        while p < max_t && (p.* == #char " " || p.* == #char "\t" || p.* == #char "\r") p += 1;
        if p + 1 < max_t && p.* == #char "%" && (p + 1).* == #char "}" && rest_of_line_is_whitespace(p + 2, max_t) {
            t = p + 2;
            eat_until_newline(tokenizer);
            if t < max_t then t += 1;  // eat the newline like other comment parsers do
            return;
        }
        eat_until_newline(tokenizer);
        if t < max_t then t += 1;
    }
}

parse_string_literal :: (using tokenizer: *Matlab_Tokenizer, token: *Token) {
    // Double-quoted string; a doubled "" is an escaped quote
    token.type = .string_literal;

    t += 1;
    while t < max_t && t.* != #char "\n" {
        if t.* == #char "\"" {
            if t + 1 < max_t && (t + 1).* == #char "\"" {
                t += 2;
                continue;
            }
            break;
        }
        t += 1;
    }

    t += 1;  // Skip closing quote
}

parse_quote :: (using tokenizer: *Matlab_Tokenizer, token: *Token) {
    // The transpose operator must directly follow the expression it applies to:
    // a quote preceded by whitespace always starts a char vector. Verified against
    // MATLAB R2025b - `B = A ';` is an invalid expression there, while the spaced
    // quotes in `[seq 'def']` and `{A 'text'}` start char vectors.
    if !had_white_space_to_skip && can_end_expression(last_token) {
        token.type      = .operation;
        token.operation = .transpose;
        t += 1;
        return;
    }

    // Char vector; a doubled '' is an escaped quote
    token.type = .char_literal;

    t += 1;
    while t < max_t && t.* != #char "\n" {
        if t.* == #char "'" {
            if t + 1 < max_t && (t + 1).* == #char "'" {
                t += 2;
                continue;
            }
            break;
        }
        t += 1;
    }

    t += 1;  // Skip closing quote
}

can_end_expression :: (token: Token) -> bool {
    if token.type == {
        case .identifier;  return true;
        case .number;      return true;
        case .value;       return true;  // true' and false' are valid transposes
        case .keyword;     return token.keyword == .kw_end;  // A(end)'

        case .string_literal;
            #through;
        case .char_literal;
            return true;

        case .punctuation;
            return token.punctuation == .r_paren || token.punctuation == .r_bracket || token.punctuation == .r_brace;

        case .operation;
            // A'' means (A')'
            return token.operation == .transpose || token.operation == .dot_transpose;
    }
    return false;
}

parse_period :: (using tokenizer: *Matlab_Tokenizer, token: *Token) {
    // Line continuation: 3 or more dots. MATLAB treats the rest of the physical
    // line as a comment, so we do the same
    if at_string(tokenizer, "...") {
        token.type = .comment;
        eat_until_newline(tokenizer);
        t += 1;
        return;
    }

    // A dot followed by a digit starts a number: .5
    if t + 1 < max_t && ascii_is_digit((t + 1).*) {
        parse_number(tokenizer, token);
        return;
    }

    // Element-wise and transpose dot operators: .* ./ .\ .^ .'
    if t + 1 < max_t {
        next := (t + 1).*;
        if next == {
            case #char "*";  token.type = .operation; token.operation = .dot_asterisk;  t += 2; return;
            case #char "/";  token.type = .operation; token.operation = .dot_slash;     t += 2; return;
            case #char "\\"; token.type = .operation; token.operation = .dot_backslash; t += 2; return;
            case #char "^";  token.type = .operation; token.operation = .dot_caret;     t += 2; return;
            case #char "'";  token.type = .operation; token.operation = .dot_transpose; t += 2; return;
        }
    }

    token.type        = .punctuation;
    token.punctuation = .period;
    t += 1;
}

parse_equal :: (using tokenizer: *Matlab_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .equal;

    t += 1;
    if t >= max_t return;

    if t.* == #char "=" {
        token.operation = .double_equal;
        t += 1;
    }
}

parse_tilde :: (using tokenizer: *Matlab_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .tilde;

    t += 1;
    if t >= max_t return;

    if t.* == #char "=" {
        token.operation = .tilde_equal;
        t += 1;
    }
}

parse_less_than :: (using tokenizer: *Matlab_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .less_than;

    t += 1;
    if t >= max_t return;

    if t.* == #char "=" {
        token.operation = .less_than_equal;
        t += 1;
    }
}

parse_greater_than :: (using tokenizer: *Matlab_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .greater_than;

    t += 1;
    if t >= max_t return;

    if t.* == #char "=" {
        token.operation = .greater_than_equal;
        t += 1;
    }
}

parse_ampersand :: (using tokenizer: *Matlab_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .ampersand;

    t += 1;
    if t >= max_t return;

    if t.* == #char "&" {
        token.operation = .double_ampersand;
        t += 1;
    }
}

parse_pipe :: (using tokenizer: *Matlab_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .pipe;

    t += 1;
    if t >= max_t return;

    if t.* == #char "|" {
        token.operation = .double_pipe;
        t += 1;
    }
}

only_whitespace_before_on_line :: (using tokenizer: *Matlab_Tokenizer) -> bool {
    p := t;
    while p > buf.data {
        c := (p - 1).*;
        if c == #char "\n" return true;
        if c != #char " " && c != #char "\t" && c != #char "\r" return false;
        p -= 1;
    }
    return true;
}

rest_of_line_is_whitespace :: (p: *u8, max_t: *u8) -> bool {
    while p < max_t {
        c := p.*;
        if c == #char "\n" return true;
        if c != #char " " && c != #char "\t" && c != #char "\r" return false;
        p += 1;
    }
    return true;
}

Matlab_Tokenizer :: struct {
    using #as base: Tokenizer;
    last_token: Token;

    // Minimal physical-line state to find the name in a function declaration
    function_decl_state:    Function_Decl_State;
    function_decl_line_end: s64;
}

Function_Decl_State :: enum {
    none;
    expect_name_or_outputs;
    in_outputs;
    expect_name;
}

Token :: struct {
    using #as base: Base_Token;

    // Additional info to distinguish between keywords/punctuation
    union {
        keyword:     Keyword;
        punctuation: Punctuation;
        operation:   Operation;
    }
}

KEYWORDS :: string.[
    // The MATLAB reserved keywords
    "break", "case", "catch", "classdef", "continue", "else", "elseif", "end",
    "for", "function", "global", "if", "otherwise", "parfor", "persistent",
    "return", "spmd", "switch", "try", "while",
];

VALUE_KEYWORDS :: string.[
    "true", "false",
];

OPERATIONS :: string.[
    "plus", "minus", "asterisk", "slash", "backslash", "caret",
    "dot_asterisk", "dot_slash", "dot_backslash", "dot_caret",
    "transpose", "dot_transpose",
    "equal", "double_equal", "tilde", "tilde_equal",
    "less_than", "less_than_equal", "greater_than", "greater_than_equal",
    "ampersand", "double_ampersand", "pipe", "double_pipe",
    "colon", "at",
];

PUNCTUATION :: string.[
    "comma", "period", "semicolon",

    "l_paren", "r_paren",
    "l_brace", "r_brace",
    "l_bracket", "r_bracket",
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

    define_enum(*b, "Punctuation", "",           .[PUNCTUATION]);
    define_enum(*b, "Operation",   "",           .[OPERATIONS]);
    define_enum(*b, "Keyword",     "kw_",        .[KEYWORDS, VALUE_KEYWORDS]);

    return builder_to_string(*b);
}

Keyword_Token :: struct {
    type: Token_Type;
    keyword: Keyword;
}

KEYWORD_MAP :: #run -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    size := 10 * (KEYWORDS.count + VALUE_KEYWORDS.count);
    table_resize(*table, size);

    #insert -> string {
        b: String_Builder;
        for KEYWORDS          append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .keyword, keyword = .kw_%1 });\n", it));
        for VALUE_KEYWORDS    append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .value,   keyword = .kw_%1 });\n", it));
        return builder_to_string(*b);
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS          { if result < it.count then result = it.count; }
    for VALUE_KEYWORDS    { if result < it.count then result = it.count; }
    return xx result;
}
