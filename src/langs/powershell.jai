tokenize_powershell :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_powershell_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

        if token.type == .punctuation && token.punctuation == .l_paren && tokenizer.last_token.type == .identifier {
            // Highlight previous token as function
            memset(tokens.data + tokenizer.last_token.start, xx Token_Type.function, tokenizer.last_token.len);
        }

        tokenizer.last_token = token;

        highlight_token(buffer, token);
    }
    return .[];
}


tokenize_powershell_for_indentation :: (buffer: Buffer) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_powershell_tokenizer(buffer);

    while true {
        src := get_next_token(*tokenizer);

        token: Indentation_Token = ---;
        token.start = src.start;
        token.len   = src.len;

        if src.type == {
            case .punctuation;
            if src.punctuation == {
                case .l_brace;    token.type = .open;  token.kind = .brace;
                case .r_brace;    token.type = .close; token.kind = .brace;
                case;             continue;
            }
            case .multiline_string;     token.type = .maybe_multiline;
            case .multiline_comment;    token.type = .maybe_multiline;
            case .eof;                  token.type = .eof;
            case;                       token.type = .unimportant;
        }

        array_add(*tokens, token);

        if src.type == .eof break;
    }
    return tokens;
}

#scope_file

get_powershell_tokenizer :: (using buffer: Buffer, start_offset := -1, count := -1) -> PowerShell_Tokenizer {
    tokenizer := PowerShell_Tokenizer.{
        buf   = to_string(bytes),
        max_t = bytes.data + bytes.count,
        t     = bytes.data
    };

    if start_offset >= 0 {
        start_offset    = clamp(start_offset, 0, bytes.count - 1);
        count           = clamp(count,        0, bytes.count - 1);
        tokenizer.t    += start_offset;
        tokenizer.max_t = tokenizer.t + count;
    }
    return tokenizer;
}

get_next_token :: (using tokenizer: *PowerShell_Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type = .eof;
    if t >= max_t return token;

    start_t = t;

    char := t.*;

    if char == #char "@" && t + 1 < max_t && ((t + 1).* == #char "\"" || (t + 1).* == #char "'") {
        parse_here_string(tokenizer, *token);
    } else if ascii_is_alpha(char) || char == #char "_" {
        // To correctly handle PowerShell's `Verb-Noun` cmdlets (e.g. `Write-Host`) as a single
        // token, we do a quick lookahead. If we find the hyphenated pattern, we treat
        // the whole thing as a function call. Otherwise, we parse it as a normal keyword or identifier.
        temp_t := t;
        while temp_t < max_t && (ascii_is_alnum(temp_t.*) || temp_t.* == #char "_") temp_t += 1;

        if temp_t < max_t && temp_t.* == #char "-" {
            token.type = .function;
            t = temp_t + 1;
            while t < max_t && (ascii_is_alnum(t.*) || t.* == #char "_") t += 1;
        } else {
            parse_identifier_or_keyword(tokenizer, *token);
        }

    } else if ascii_is_digit(char) {
        // PS can have other number formats for things like (1MB, 1GB, etc.), but for now we'll parse generics.
        parse_number_c_like(tokenizer, *token);

    } else if char == #char "<" && t + 1 < max_t && (t + 1).* == #char "#" {
        parse_multiline_comment(tokenizer, *token);

    } else if char == {
        case #char  "#"; parse_comment(tokenizer, *token);
        case #char  "$"; parse_dollar_variable(tokenizer, *token);
        case #char "\""; parse_string_literal(tokenizer, *token, end_char = #char "\"");
        case #char  "'"; parse_string_literal(tokenizer, *token, end_char = #char "'");
        case #char  "-"; parse_hyphenated(tokenizer, *token);
        case #char  "["; parse_type_accelerator(tokenizer, *token);

        // Punctuation
        case #char "{"; token.type = .punctuation; token.punctuation = .l_brace;    t += 1;
        case #char "}"; token.type = .punctuation; token.punctuation = .r_brace;    t += 1;
        case #char "("; token.type = .punctuation; token.punctuation = .l_paren;    t += 1;
        case #char ")"; token.type = .punctuation; token.punctuation = .r_paren;    t += 1;
        case #char ";"; token.type = .punctuation; token.punctuation = .semicolon;  t += 1;
        case #char ","; token.type = .punctuation; token.punctuation = .comma;      t += 1;
        case #char "."; token.type = .punctuation; token.punctuation = .period;     t += 1;

        // Other operators
        case #char "="; token.type = .operation; token.operation = .equal;          t += 1;
        case #char ":"; token.type = .operation; token.operation = .colon;          t += 1;
        case #char "&"; token.type = .operation; token.operation = .ampersand;      t += 1;
        case #char "@"; token.type = .operation; token.operation = .at;             t += 1;
        case #char "+"; token.type = .operation; token.operation = .plus;           t += 1;
        case #char "*"; token.type = .operation; token.operation = .asterisk;       t += 1;
        case #char "/"; token.type = .operation; token.operation = .slash;          t += 1;
        case #char "%"; token.type = .operation; token.operation = .percent;        t += 1;
        case #char "|"; token.type = .operation; token.operation = .pipe;           t += 1;
        case #char ">"; token.type = .operation; token.operation = .redirect;       t += 1;
        case #char "`"; token.type = .operation; token.operation = .backtick;       t += 1;

        case;           token.type = .invalid;  t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);

    return token;
}

parse_identifier_or_keyword :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;

    // PS identifiers pretty much always have hyphens in them (Write-Host, Get-ChildItem, etc.), but we parse
    // those separately in 'parse_hyphenated' to distinguish from operators.
    // Here we just read a simple word.
    identifier := read_identifier_string(tokenizer);

    if identifier.count <= MAX_KEYWORD_LENGTH {
        ok, kw_token := table_find_new(*KEYWORD_MAP, identifier);
        if ok {
            token.type = kw_token.type;
            token.keyword = kw_token.keyword;
            return;
        }
    }
}

parse_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .comment;
    while t < max_t && t.* != #char "\n" t += 1;
}

parse_multiline_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .multiline_comment;

    while t + 1 < max_t {
        if t.* == #char "#" && (t + 1).* == #char ">" {
            t += 2;
            break;
        }
        t += 1;
    }
}

parse_dollar_variable :: (using tokenizer: *Tokenizer, token: *Token) {
    t += 1; // Eat '$'

    // Here we handle the more complex variables like ${...}
    if t < max_t && t.* == #char "{" {
        token.type = .identifier;
        t += 1; // Eat '{'
        while t < max_t && t.* != #char "}" t += 1;
        t += 1; // Eat '}'
        return;
    }

    // This handles simple variables.
    variable_name := read_identifier_string(tokenizer);

    // Check whether to treat it like a special variable or a regular one.
    ok, kw_token := table_find_new(*SPECIAL_VARIABLES_MAP, variable_name);
    if ok {
        token.type = kw_token.type;
        token.special_variable = kw_token.special_variable;
    } else {
        token.type = .identifier;
    }
}

parse_string_literal :: (using tokenizer: *Tokenizer, token: *Token, end_char: u8) {
    token.type = .string_literal;
    t += 1; // Eat opening quotation

    while t < max_t && t.* != #char "\n" {
        // PS uses backtick ` for escapes
        if t.* == #char "`" {
            t += 2;   // We skip the backtick and the character following it.
            continue;
        }
        if t.* == end_char break;
        t += 1;
    }
    if t < max_t && t.* == end_char then t += 1; // We eat the closing quotation.
}

parse_here_string :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .multiline_string;
    start_char := (t + 1).*;
    t += 2; // Eat @" or @'

    while t + 2 < max_t {
        if t.* == #char "\n" && (t + 1).* == start_char && (t + 2).* == #char "@" {
            t += 3;
            break;
        }
        t += 1;
    }
}

parse_type_accelerator :: (using tokenizer: *Tokenizer, token: *Token) {
    // Accelerators are sort of like type casting an object or variable since PS vars can be inferred.
    // https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_type_accelerators?view=powershell-7.5

    token.type = .type;
    t += 1; // Eat '['
    open_brackets := 0;
    while t < max_t {
        defer t += 1;
        if t.* == #char "\n"  break;
        if t.* == #char "]" {
            if open_brackets <= 0  break;
            open_brackets -= 1;
        } else if t.* == #char "[" {
            open_brackets += 1;
        }
    }
}

parse_hyphenated :: (using tokenizer: *Tokenizer, token: *Token) {
    // Check if we're dealin with a negative number, a parameter like '-Path', or an operator like '-eq'.
    t += 1;   // Eat '-'
    word := read_identifier_string(tokenizer);

    // Check if it's a known operator.
    ok, op := table_find_new(*OPERATOR_MAP, word);
    if ok {
        token.type = .operation;
        token.operation = op;
        return;
    }
    // Getting here, it's most likely a parameter name, so color it as a keyword/type.
    token.type = .type;
}




// Data Definitions

PowerShell_Tokenizer :: struct {
    using #as base: Tokenizer;
    last_token:     Token;
}

Token :: struct {
    using #as base: Base_Token;
    union {
        keyword:            Keyword;
        special_variable:   Special_Variable;
        punctuation:        Punctuation;
        operation:          Operation;
    }
}


// PS Keywords per https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_language_keywords?view=powershell-7.5
KEYWORDS :: string.[
    "function", "if", "else", "elseif", "switch", "case", "default", "for", "foreach", "in", "while", "do", "until", "try", "catch", "finally", "throw", "begin", "process", "end", "filter", "param", "return", "break", "continue",
    "dynamicparam", "trap", "data", "class", "define", "from", "using", "public", "private", "static", "interface", "enum"
];

PUNCTUATION :: string.["l_paren", "r_paren", "l_brace", "r_brace", "semicolon", "comma", "period"];

OPERATIONS :: string.[
    "equal", "plus", "asterisk", "slash", "percent", "pipe", "redirect", "redirect_append", "colon", "ampersand", "at",
    "eq", "ne", "gt", "ge", "lt", "le", "like", "notlike", "match", "notmatch", "contains", "notcontains", "replace",
    "and", "or", "xor", "not", "bnot", "band", "bor", "bxor", "is", "isnot", "as", "c", "i", "split", "join", "f", "backtick",
];

SPECIAL_VARIABLES :: string.[
    "_", "Args", "ConsoleFileName", "Error", "Event", "EventArgs", "EventSubscriber", "ExecutionContext", "false", "foreach",
    "HOME", "Host", "input", "LASTEXITCODE", "Matches", "MyInvocation", "NestedPromptLevel", "null", "PID", "PROFILE",
    "PSBoundParameters", "PSCmdlet", "PSCommandPath", "PSCulture", "PSDebugContext", "PSEdition", "PSHOME", "PSItem",
    "PSScriptRoot", "PSSenderInfo", "PSUICulture", "PSVersionTable", "PWD", "Sender", "ShellId", "StackTrace", "switch",
    "this", "true"
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
    define_enum(*b, "Punctuation",      "",     .[PUNCTUATION]);
    define_enum(*b, "Operation",        "",     .[OPERATIONS]);
    define_enum(*b, "Keyword",          "kw_",  .[KEYWORDS]);
    define_enum(*b, "Special_Variable", "sv_",  .[SPECIAL_VARIABLES]);
    return builder_to_string(*b);
}

Keyword_Token :: struct {
    type: Token_Type;
    keyword: Keyword;
}

Special_Variable_Token :: struct {
    type: Token_Type;
    special_variable: Special_Variable;
}

KEYWORD_MAP :: #run -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    size := 2 * KEYWORDS.count;
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        init_string_builder(*b);
        for KEYWORDS            append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .keyword, keyword = .kw_%1 });\n", it));
        return builder_to_string(*b);
    }
    return table;
}

SPECIAL_VARIABLES_MAP :: #run -> Table(string, Special_Variable_Token) {
    table: Table(string, Special_Variable_Token);
    size := 2 * (KEYWORDS.count + SPECIAL_VARIABLES.count);
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        init_string_builder(*b);
        for SPECIAL_VARIABLES   append(*b, sprint("table_add(*table, \"%1\", Special_Variable_Token.{ type = .value,  special_variable = .sv_%1 });\n", it));
        return builder_to_string(*b);
    }
    return table;
}

OPERATOR_MAP :: #run -> Table(string, Operation) {
    table: Table(string, Operation);
    init(*table, 2 * OPERATIONS.count);
    #insert -> string {
        b: String_Builder;
        init_string_builder(*b);

        for i: 8..OPERATIONS.count-1 {
            op_name := OPERATIONS[i];
            print_to_builder(*b, "table_add(*table, \"%1\", .%1);\n", op_name);
        }
        return builder_to_string(*b);
    }
    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS          { if it.count > result then result = it.count; }
    for SPECIAL_VARIABLES { if it.count > result then result = it.count; }
    return xx result;
}
