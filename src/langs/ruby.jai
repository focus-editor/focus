tokenize_ruby :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_tokenizer(buffer, start_offset, count);

    last_token: Token;

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        using tokenizer;

        // Maybe highlight a function
        if token.type == .punctuation && token.punctuation == .l_paren && last_token.type == .identifier {
            memset(tokens.data + last_token.start, xx Token_Type.function, last_token.len);
        }

        last_token = token;

        highlight_token(buffer, token);
    }

    return .[];
}

#scope_file

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;

    // Assume ASCII, unless we're in the middle of a string.
    // UTF-8 characters elsewhere are a syntax error.
    char := t.*;

    if ascii_is_alpha(char) || char == #char "_" || char == #char "@" || char == #char "$" {
        parse_identifier(tokenizer, *token);
    } else if ascii_is_digit(char) {
        parse_number(tokenizer, *token);
    } else if char == {
        case #char ":";  parse_colon             (tokenizer, *token);
        case #char "=";  parse_equal             (tokenizer, *token);
        case #char "-";  parse_minus             (tokenizer, *token);
        case #char "+";  parse_plus              (tokenizer, *token);
        case #char "*";  parse_asterisk          (tokenizer, *token);
        case #char "<";  parse_less_than         (tokenizer, *token);
        case #char ">";  parse_greater_than      (tokenizer, *token);
        case #char "!";  parse_bang              (tokenizer, *token);
        case #char "/";  parse_slash             (tokenizer, *token);
        case #char "\""; parse_double_quote      (tokenizer, *token);
        case #char "'";  parse_single_quote      (tokenizer, *token);
        case #char "\t"; parse_tab               (tokenizer, *token);
        case #char "#";  parse_comment           (tokenizer, *token);
        case #char "&";  parse_ampersand         (tokenizer, *token);
        case #char "|";  parse_pipe              (tokenizer, *token);
        case #char "%";  parse_percent           (tokenizer, *token);
        case #char "^";  parse_caret             (tokenizer, *token);
        case #char "\\"; parse_back_slash        (tokenizer, *token);        

        case #char ";";  token.type = .punctuation; token.punctuation = .semicolon;  t += 1;
        case #char ",";  token.type = .punctuation; token.punctuation = .comma;      t += 1;
        case #char ".";  token.type = .punctuation; token.punctuation = .period;     t += 1;
        case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;    t += 1;
        case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;    t += 1;
        case #char "(";  token.type = .punctuation; token.punctuation = .l_paren;    t += 1;
        case #char ")";  token.type = .punctuation; token.punctuation = .r_paren;    t += 1;
        case #char "[";  token.type = .punctuation; token.punctuation = .l_bracket;  t += 1;
        case #char "]";  token.type = .punctuation; token.punctuation = .r_bracket;  t += 1;
        case #char "\\"; token.type = .punctuation; token.punctuation = .back_slash; t += 1;

        case #char "~";  token.type = .operation;   token.operation   = .tilde;      t += 1;
        case #char "`";  token.type = .operation;   token.operation   = .backtick;   t += 1;

        case;            token.type = .invalid; t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

// NOTE: replaces read_identifier_string in common.jai
// WARNING: may miss out on updates to the original common function
read_ruby_identifier_string :: (using tokenizer: *Tokenizer) -> string {
    identifier: string;
    identifier.data = t;

    // prefixes (@, @@, $)
    if t < max_t && (t.* == #char "@" || t.* == #char "$") {
        t += 1;
        if t < max_t && t.* == #char "@" then t += 1;
    }

    // standard alphanumeric + underscore
    while t < max_t && (ascii_is_alnum(t.*) || t.* == #char "_") {
        t += 1;
    }

    // suffixes (!, ?)
    if t < max_t && (t.* == #char "!" || t.* == #char "?") {
        t += 1;
    }

    if t >= max_t then t = max_t;
    identifier.count = t - identifier.data;

    return identifier;
}

parse_identifier :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    identifier_str := read_ruby_identifier_string(tokenizer); // read_identifier_string

    // globals
    if t.* == #char "$" {
        t += 1;
        if t < max_t {
            // 1. Numeric Globals (Regex captures: $1, $2, etc)
            if ascii_is_digit(t.*) {
                t += 1; 
            } 
            // 2. Standard Globals ($LOAD_PATH, $global_var)
            else if ascii_is_alpha(t.*) || t.* == #char "_" {
                read_identifier_string(tokenizer); 
            } 
            // 3. Special Globals ($!, $?, $/, $~, $*)
            else {
                t += 1; 
            }
        }
        token.type = .string; // Globals are often colored like Symbols
        return;
    }

    // 1. Check for Labels (key:) 
    // Do this early so that "if:" is a symbol, not a keyword.
    if t < max_t && t.* == #char ":" {
        // Peek to ensure it's not the first part of a '::'
        if (t + 1) < max_t && (t + 1).* != #char ":" {
            t += 1; // Consume the ':'
            token.type = .string; // Highlight as a Ruby symbol
            return; 
        }
    }

    // 2. Check for Ruby Constants (Starts with A-Z)
    // In Ruby, capitalization is a semantic rule for Types/Classes.
    first_char := identifier_str[0];
    if ascii_is_upper(first_char) {
        token.type = .type;
        // Note: Don't return yet! Some constants might be in the keyword map 
        // (though rare in Ruby, like BEGIN/END).
    }

    // Maybe it's a keyword
    if identifier_str.count <= MAX_KEYWORD_LENGTH {
        ok, kw_token := table_find(*KEYWORD_MAP, identifier_str);
        if ok { token.type = kw_token.type; token.keyword = kw_token.keyword; return; }
    }
        
}

parse_number :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .number;

    t += 1;
    if t >= max_t return;

    if ascii_is_digit(t.*) || t.* == #char "_" {
        // Decimal
        t += 1;
        seen_decimal_point := false;
        while t < max_t && (ascii_is_digit(t.*) || t.* == #char "_" || t.* == #char ".") {
            if t.* == #char "." {
                if seen_decimal_point break;
                seen_decimal_point = true;
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

parse_colon :: (using tokenizer: *Tokenizer, token: *Token) {
    t += 1; // Consume the first ':'

    // If we hit the end of the file right after the colon
    if t >= max_t {
        token.type = .operation;
        token.operation = .colon;
        return;
    }

    char := t.*;



    // CASE 1: Double Colon (::)
    if char == #char ":" {
        t += 1; // Consume the second ':'
        token.type = .operation;
        token.operation = .double_colon; 
        return;
    }


    // CASE 2: Standard Symbol (:symbol)
    if ascii_is_alpha(char) || char == #char "_" {
        // Use the original reader to grab the alphanumeric part
        read_identifier_string(tokenizer); 
        
        // Ruby symbols can end in ! or ? (e.g. :valid?)
        if t < max_t && (t.* == #char "!" || t.* == #char "?") {
            t += 1;
        }

        token.type = .string; // Color it as a symbol/string
        return;
    }

    // CASE 3: Quoted Symbol (:"symbol")
    if char == #char "\"" || char == #char "'" {
        // This re-uses the existing string literal logic
        parse_string_literal(tokenizer, token, char);
        token.type = .string; 
        return;
    }

    // Default: Just a plain colon (used in ternary a ? b : c)
    token.type = .operation;
    token.operation = .colon;
}

parse_equals :: (using tokenizer: *Tokenizer, token: *Token) {
    // handle =begin/=end
    // Check if we are at the start of a line (t == line_start)
    // and if the next characters are "begin"
    if is_at_start_of_line(tokenizer) && peek_string(tokenizer, "begin") {
        token.type = .comment;
        
        // Skip "=begin"
        t += 6; 
        
        // Loop until we find "=end" at the start of a line
        while t < max_t {
            if is_at_start_of_line(tokenizer) && peek_string(tokenizer, "=end") {
                t += 4; // consume "=end"
                break;
            }
            t += 1;
        }
        return;
    }

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            token.operation = .equal_equal;
            t += 1;
            
            // Ruby specific: Check for ===
            if t < max_t && t.* == #char "=" {
                token.operation = .triple_equal;
                t += 1;
            }

        case #char ">";
            token.operation = .hash_rocket; // For { :a => 1 }
            t += 1;

        case #char "~";
            token.operation = .equal_tilde; // The =~ operator
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
            if ascii_is_digit(t.*) parse_number(tokenizer, token);
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

        case #char "~";
            token.operation = .bang_tilde; // The !~ operator
            t += 1;
    }
}

parse_percent :: (using tokenizer: *Tokenizer, token: *Token) {

    t += 1; // Consume '%'

    if t < max_t && ascii_is_alpha(t.*) {
        // It's a literal like %w, %q, %i, %r
        t += 1; // Consume the letter
        
        if t < max_t {
            open_delim := t.*;
            close_delim: uint8;
            
            // Set the matching pair
            if      open_delim == #char "("  close_delim = #char ")";
            else if open_delim == #char "["  close_delim = #char "]";
            else if open_delim == #char "{"  close_delim = #char "}";
            else if open_delim == #char "<"  close_delim = #char ">";
            else                             close_delim = open_delim;

            t += 1; // Consume opening delimiter
            while t < max_t {
                if t.* == #char "\\" { t += 2; continue; }
                if t.* == close_delim { t += 1; break; }
                t += 1;
            }
            token.type = .string;
            token.count = t - start_pos;
            return;
        }
    }

    // Default: Modulo (%) or Modulo Assignment (%=)
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

parse_slash :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .slash; 

    t += 1; // Consume the first '/'
    if t >= max_t return;

    // CASE 1: Division Assignment (/=)
    if t.* == #char "=" {
        token.operation = .slash_equal;
        t += 1;
        return;
    }

    // CASE 2: Regular Expression (/regex/)
    // Logic: If the slash is NOT followed by a space, it's likely a Regex.
    // In Ruby, division / usually has spaces around it: x / y.
    if t.* != #char " " && t.* != #char "\t" && t.* != #char "\n" {
        token.type = .string; // Color regex as a string literal
        
        while t < max_t {
            if t.* == #char "\\" {
                t += 2; // Skip escaped characters like \/
                continue;
            }
            
            if t.* == #char "/" {
                t += 1; // Consume closing '/'
                
                // Consume optional regex modifiers: /abc/ix
                while t < max_t && (t.* == #char "i" || t.* == #char "m" || 
                                   t.* == #char "x" || t.* == #char "o") {
                    t += 1;
                }
                break;
            }
            
            if t.* == #char "\n" break; // Safety: stop at end of line
            t += 1;
        }
    }
}

parse_less_than :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .less_than;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";
            // Check if it's <= or <=>
            if (t + 1) < max_t && (t + 1).* == #char ">" {
                token.operation = .spaceship; // <=>
                t += 2;
            } else {
                token.operation = .less_than_equal; // <=
                t += 1;
            }
        case #char "<";
            token.operation = .double_less_than; // << (Also used for appending to arrays)
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

parse_tab :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .comment;
    t += 1;
    while t < max_t && t.* == #char "\t" t += 1;
}

parse_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .comment;
    t += 1;
    while t < max_t && t.* != #char "\n" t += 1;
}

parse_double_quote :: (using tokenizer: *Tokenizer, token: *Token) {
    parse_string_literal(tokenizer, token, #char "\"");
}

parse_single_quote :: (using tokenizer: *Tokenizer, token: *Token) {
    parse_string_literal(tokenizer, token, #char "'");
}

parse_string_literal :: (using tokenizer: *Tokenizer, token: *Token, quote_type: uint8) {
    token.type = .string;
    t += 1; // Consume the opening quote (' or ")

    while t < max_t {
        // Handle escaped characters (like \" or \\)
        if t.* == #char "\\" {
            t += 2; 
            continue;
        }

        // If we hit the matching closing quote, we are done
        if t.* == quote_type {
            t += 1; 
            break;
        }

        // Ruby specific: Peek for interpolation start #{
        // We stay in the string for now to avoid breaking the lexer
        if quote_type == #char "\"" && t.* == #char "#" {
            if (t + 1) < max_t && (t + 1).* == #char "{" {
                // For a basic lexer, we just continue. 
                // Advanced lexers would break here to color the code inside.
            }
        }

        t += 1;
    }
}

parse_back_slash :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .punctuation;
    token.punctuation = .back_slash;
    t += 1; // Consume the '\'

    // Ruby logic: If a backslash is followed immediately by a newline, 
    // it's a line continuation. We consume the newline so the lexer 
    // treats the next line as part of the current expression.
    if t < max_t && t.* == #char "\n" {
        t += 1;
        // Optional: If you want to skip highlighting line continuations entirely:
        // token.type = .none; 
    }
}

Token :: struct {
    using #as base: Base_Token;

    // Additional info to distinguish between keywords/punctuation
    union {
        keyword:            Keyword;
        punctuation:        Punctuation;
        operation:          Operation;
    }
}

PUNCTUATION :: string.[
    "semicolon", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", "period", "comma", "back_slash"
];

OPERATIONS :: string.[
    "arrow", "bang", "backtick", "pipe", "double_pipe", "pipe_equal", "equal", "equal_equal", "bang_equal",
    "percent", "percent_equal", "less_than", "double_less_than", "less_than_equal", "greater_than", "greater_than_equal",
    "minus", "minus_equal", "asterisk", "asterisk_equal", "colon", "double_colon", "slash",
    "plus", "plus_equal", "slash_equal", "ampersand", "double_ampersand", "ampersand_equal", "tilde",
    "caret", "caret_equal",
    // NOTE: added: hash_rocket (=>), spaceship (<=>), equal_tilde (=~), bang_tilde (!~), and triple_equal (===)
    "hash_rocket", "spaceship", "equal_tilde", "bang_tilde", "triple_equal"
    // TODO: unimpl: "double_asterisk" (exponent), "asterisk_equal" (exponent equal?), "double_dot", "triple_dot"
];


KEYWORDS :: string.[
    "alias", "and", "begin", "break", "case", "class", "def", "defined?", 
    "do", "else", "elsif", "end", "ensure", "false", "for", "if", "in", 
    "module", "next", "nil", "not", "or", "redo", "rescue", "retry", 
    "return", "self", "super", "then", "true", "undef", "unless", "until", 
    "when", "while", "yield", "it",
    "__FILE__", "__LINE__", "__ENCODING__", "BEGIN", "END"
];

TYPE_KEYWORDS :: string.[
    // alt: could just leave this blank and treat them as classes..
    "Array", "Hash", "String", "Integer", "Float", "Numeric", 
    "Symbol", "Range", "Regexp", "TrueClass", "FalseClass", "NilClass",
    "Object", "Module", "Class", "Struct", "Enumerable"
];

BUILTIN_FUNCTIONS :: string.[
    // Kernal methods as global functions
    "puts", "print", "p", "gets", "chomp", "require", "require_relative", 
    "include", "extend", "attr_accessor", "attr_reader", "attr_writer",
    "raise", "fail", "catch", "throw", "loop", "proc", "lambda"
];

BUILTIN_EXCEPTIONS :: string.[
    "Exception", "StandardError", "RuntimeError", "ArgumentError", 
    "NoMethodError", "NameError", "TypeError", "ZeroDivisionError", 
    "SystemExit", "StopIteration", "IOError", "LoadError", "SecurityError"
];

VALUE_KEYWORDS :: string.[
    "true", "false", "nil", "self"    
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

    define_enum(*b, "Punctuation", "",    .[PUNCTUATION]);
    define_enum(*b, "Operation",   "",    .[OPERATIONS]);
    define_enum(*b, "Keyword",     "kw_", .[KEYWORDS, TYPE_KEYWORDS, VALUE_KEYWORDS, BUILTIN_FUNCTIONS, BUILTIN_EXCEPTIONS]);

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
        for KEYWORDS           append(*b, sprint("table_add(*table, \"%\", Keyword_Token.{ type = .keyword,           keyword = .kw_% });\n", it, it));
        for TYPE_KEYWORDS      append(*b, sprint("table_add(*table, \"%\", Keyword_Token.{ type = .type,              keyword = .kw_% });\n", it, it));
        for VALUE_KEYWORDS     append(*b, sprint("table_add(*table, \"%\", Keyword_Token.{ type = .value,             keyword = .kw_% });\n", it, it));
        for BUILTIN_FUNCTIONS  append(*b, sprint("table_add(*table, \"%\", Keyword_Token.{ type = .builtin_function,  keyword = .kw_% });\n", it, it));
        for BUILTIN_EXCEPTIONS append(*b, sprint("table_add(*table, \"%\", Keyword_Token.{ type = .builtin_exception, keyword = .kw_% });\n", it, it));
        return builder_to_string(*b);
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS           { if it.count > result then result = it.count; }
    for TYPE_KEYWORDS      { if it.count > result then result = it.count; }
    for VALUE_KEYWORDS     { if it.count > result then result = it.count; }
    for BUILTIN_FUNCTIONS  { if it.count > result then result = it.count; }
    for BUILTIN_EXCEPTIONS { if it.count > result then result = it.count; }
    return xx result;
}
