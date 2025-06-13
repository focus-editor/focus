tokenize_jai :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_jai_tokenizer(buffer, start_offset, count);

    start_scope(*tokenizer, tokenizer.t - tokenizer.buf.data, .scope_export);

    while true {
        using tokenizer;

        token := start_new_token(*tokenizer);

        if t >= max_t break;

        // Assume ASCII, unless we're in the middle of a string.
        // UTF-8 characters elsewhere are a syntax error.
        char := t.*;

        if ascii_is_alpha(char) || char == #char "_" {
            parse_identifier_keyword_or_function(*tokenizer, *token, buffer);
        } else if ascii_is_digit(char) {
            t += 1;
            parse_number(*tokenizer, *token, buffer);
            highlight(*tokenizer, *token, buffer);
        } else if char == #char "#" {
            t += 1;
            parse_directive(*tokenizer, *token, buffer);
            highlight(*tokenizer, *token, buffer);
        } else if char == #char "/" {
            t += 1;
            parse_slash_or_comment(*tokenizer, *token);
            highlight(*tokenizer, *token, buffer);
            if token.type == .comment || token.type == .multiline_comment {
                // Highlight words in comments
                comment_str  := cast(string) to_view(buffer.bytes, token.start, token.len);
                output_words := find_whole_words(*config.comment_words_automaton, comment_str);
                for output_words  memset(buffer.tokens.data + token.start + it.offset, cast(u8) it.token_type, it.len);
            }
        } else {
            t += 1;
            if char == {
                case #char ";";  token.type = .punctuation; token.punctuation = .semicolon;
                case #char ",";  token.type = .punctuation; token.punctuation = .comma;
                case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;
                case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;
                case #char "(";  token.type = .punctuation; token.punctuation = .l_paren;
                case #char ")";  token.type = .punctuation; token.punctuation = .r_paren;
                case #char "[";  token.type = .punctuation; token.punctuation = .l_bracket;
                case #char "]";  token.type = .punctuation; token.punctuation = .r_bracket;
                case #char "$";  token.type = .punctuation; token.punctuation = .dollar;

                case #char "?";  token.type = .operation;   token.operation   = .question;
                case #char "=";  token.type = .operation;   token.operation   = .equal;
                case #char "+";  token.type = .operation;   token.operation   = .plus;
                case #char "*";  token.type = .operation;   token.operation   = .asterisk;
                case #char "<";  token.type = .operation;   token.operation   = .less_than;
                case #char ">";  token.type = .operation;   token.operation   = .greater_than;
                case #char "!";  token.type = .operation;   token.operation   = .bang;
                case #char "&";  token.type = .operation;   token.operation   = .ampersand;
                case #char "|";  token.type = .operation;   token.operation   = .pipe;
                case #char "%";  token.type = .operation;   token.operation   = .percent;
                case #char "^";  token.type = .operation;   token.operation   = .caret;
                case #char "~";  token.type = .operation;   token.operation   = .tilde;
                case #char "`";  token.type = .operation;   token.operation   = .backtick;
                case #char "-";  token.type = .operation;   token.operation   = .minus;

                case #char ".";  parse_period_or_enum_variant(*tokenizer, *token);
                case #char "\""; parse_string_literal        (*tokenizer, *token);
                case #char ":";  parse_colon                 (*tokenizer, *token);
                case #char "@";  parse_note                  (*tokenizer, *token);

                case;            token.type = .invalid;
            }

            if t >= max_t then t = max_t;  // TODO: do we need this?
            set_token_len(*tokenizer, *token);
            highlight(*tokenizer, *token, buffer);
        }
    }

    end_scope(*tokenizer, tokenizer.t - tokenizer.buf.data);

    quick_sort(tokenizer.regions, (a, b) => (a.start - b.start));

    return tokenizer.regions;
}

tokenize_jai_for_indentation :: (buffer: *Buffer) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_jai_tokenizer(buffer);

    while true {
        using tokenizer;

        token := start_new_token(*tokenizer);

        // A simplified parsing loop which does no highlighting.
        // NOTE: This leads to code repetition but this is done so that the main highlighting code is faster
        if t < max_t {
            char := t.*;

            if ascii_is_alpha(char) || char == #char "_" {
                t += 1;
                read_jai_identifier_string(*tokenizer);
            } else if ascii_is_digit(char) {
                t += 1;
                parse_number(*tokenizer, *token, buffer, do_highlighting = false);
            } else if char == #char "#" {
                t += 1;
                parse_directive(*tokenizer, *token, buffer, do_highlighting = false);
            } else if char == #char "/" {
                t += 1;
                parse_slash_or_comment(*tokenizer, *token);
            } else {
                t += 1;
                if char == {
                    case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;
                    case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;
                    case #char "(";  token.type = .punctuation; token.punctuation = .l_paren;
                    case #char ")";  token.type = .punctuation; token.punctuation = .r_paren;
                    case #char "[";  token.type = .punctuation; token.punctuation = .l_bracket;
                    case #char "]";  token.type = .punctuation; token.punctuation = .r_bracket;

                    case #char ".";  parse_period_or_enum_variant(*tokenizer, *token);
                    case #char "\""; parse_string_literal        (*tokenizer, *token);
                    case #char ":";  parse_colon                 (*tokenizer, *token);
                    case #char "@";  parse_note                  (*tokenizer, *token);

                    case;            token.type = .invalid;  // we don't care about invalid tokens here
                }

            }

            if t >= max_t then t = max_t;  // TODO: do we need this?
            set_token_len(*tokenizer, *token);
        }

        src := token;

        {
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

                case .directive;
                    // In this version of the indentation tokenizer we don't detect .multiline_string and instead
                    // mark the whole multiline string as .directive_string
                    if src.directive == .directive_string then token.type = .maybe_multiline;

                case .multiline_comment;    token.type = .maybe_multiline;
                case .multiline_string;     token.type = .maybe_multiline;
                case;                       token.type = .unimportant;
            }

            array_add(*tokens, token);

        }

        if t >= max_t break;
    }

    return tokens;
}

#scope_file

// We're using a separate tokenizer here because we have to keep track of last 2 tokens in many places
// and we can't use a global variable for that because of threading
get_jai_tokenizer :: (using buffer: *Buffer, start_offset := -1, count := -1) -> Jai_Tokenizer {
    tokenizer: Jai_Tokenizer;

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

set_token_len :: (using tokenizer: *Jai_Tokenizer, token: *Token) #expand {
    token.len = cast(s32) (t - start_t);
}

highlight :: (tokenizer: *Jai_Tokenizer, token: *Token, buffer: *Buffer) #expand {
    tokenizer.last_token_type = token.type;
    memset(buffer.tokens.data + token.start, xx token.type, token.len);
}

start_new_token :: inline (using tokenizer: *Jai_Tokenizer) -> Token {
    eat_white_space(tokenizer);

    token: Token = ---;
    token.start = cast(s32) (t - buf.data);
    start_t = t;

    return token;
}

maybe_mark_as_keyword :: inline (token: *Token, identifier_str: string) -> is_keyword: bool {
    if identifier_str.count > MAX_KEYWORD_LENGTH return false;
    kw_token, ok := table_find(*KEYWORD_MAP, identifier_str);
    if ok {
        token.type = kw_token.type;
        token.keyword = kw_token.keyword;;
        return true;
    }
    return false;
}

parse_identifier_or_keyword :: (using tokenizer: *Jai_Tokenizer, token: *Token, buffer: *Buffer) {
    token.type = .identifier;

    identifier_str := read_jai_identifier_string(tokenizer);
    set_token_len(tokenizer, token);

    // Maybe it's a keyword
    is_keyword := maybe_mark_as_keyword(token, identifier_str);
    if !is_keyword return;

    // Check for modifiers
    while true {
        next_token := start_new_token(tokenizer);
        if t >= max_t return;
        if t.* != #char "," break;

        t += 1;
        next_token.type = .punctuation;
        next_token.punctuation = .comma;
        set_token_len(tokenizer, *next_token);
        highlight(tokenizer, *next_token, buffer);

        next_token = start_new_token(tokenizer);

        if t >= max_t return;
        if !ascii_is_alpha(t.*) return;

        is_modifier := false;
        modifier_str := read_jai_identifier_string(tokenizer);

        if token.keyword == {
            case .kw_using;         is_modifier = array_find(string.["only", "except", "map"], modifier_str);
            case .kw_cast;          is_modifier = array_find(string.["no_check", "trunc", "force"], modifier_str);
            case .kw_xx;            is_modifier = array_find(string.["no_check", "trunc", "force"], modifier_str);
            case .kw_push_context;  is_modifier = array_find(string.["defer_pop"], modifier_str);
        }

        if is_modifier {
            next_token.type = .directive_modifier;
        } else {
            next_token.type = .identifier;
            maybe_mark_as_keyword(*next_token, modifier_str);
        }
        set_token_len(tokenizer, *next_token);
        highlight(tokenizer, *next_token, buffer);
        if !is_modifier return;
    }
}

parse_identifier_keyword_or_function :: (using tokenizer: *Jai_Tokenizer, token: *Token, buffer: *Buffer) {
    parse_identifier_or_keyword(tokenizer, token, buffer);
    defer highlight(tokenizer, token, buffer);

    if token.type == .keyword return;

    // Maybe it's a function call or a function definition
    next_token := start_new_token(tokenizer);
    if t >= max_t return;

    char := t.*;

    // Check for:
    // func (
    if char == #char "(" {
        t += 1;
        next_token.type = .punctuation;
        token.type = .function;

        set_token_len(tokenizer, *next_token);
        highlight(tokenizer, *next_token, buffer);
        return;
    }

    // Check for:
    // func :: (
    // func :: inline
    // func :: #bake_arguments
    if char == #char ":" {
        t += 1;
        parse_colon(tokenizer, *next_token);

        set_token_len(tokenizer, *next_token);
        highlight(tokenizer, *next_token, buffer);

        if next_token.operation != .double_colon return;  // not a function

        next_token = start_new_token(tokenizer);
        if t >= max_t return;

        char = t.*;

        if char == #char "(" {
            t += 1;
            next_token.type = .punctuation;
            token.type = .function;

            set_token_len(tokenizer, *next_token);
            highlight(tokenizer, *next_token, buffer);
        } else if char == #char "#" {
            t += 1;
            parse_directive(tokenizer, *next_token, buffer);
            highlight(tokenizer, *next_token, buffer);
            if next_token.type == .directive && next_token.directive == .directive_bake_arguments {
                token.type = .function;
            }
        } else if ascii_is_alpha(char) {
            parse_identifier_or_keyword(tokenizer, *next_token, buffer);
            highlight(tokenizer, *next_token, buffer);
            if next_token.type == .keyword && next_token.keyword == .kw_inline {
                token.type = .function;
            }
        }
    }
}

parse_number :: (using tokenizer: *Jai_Tokenizer, token: *Token, buffer: *Buffer, $do_highlighting := true) {
    token.type = .number;

    if t >= max_t {
        set_token_len(tokenizer, token);
        return;
    }

    is_decimal_variant :: inline (c: u8) -> bool {
        return ascii_is_digit(c) || c == #char "." || c == #char "-" || c == #char "e" || c == #char "E";
    }

    if is_decimal_variant(t.*) || t.* == #char "_" {
        // Decimal
        seen_decimal_point  := false;
        scientific_notation := false;
        while t < max_t && (is_decimal_variant(t.*) || t.* == #char "_") {
            if t.* == #char "." {
                // Handle 0..1 (gets interpreted as a float-period-int rather than int-rangeop-int)
                if (t + 1) < max_t && (t + 1).* == #char "."  break;

                // else handle float decimal
                if seen_decimal_point  break;
                seen_decimal_point = true;
            }
            else if t.* == #char "e" || t.* == #char "E" {
                // Scientific notation (3.5e2, 1.0e-34)
                // Only works if there is a decimal point
                if scientific_notation || !seen_decimal_point  break;
                scientific_notation = true;
            }
            else if t.* == #char "-" {
                // Handle negative exponent in scientific notation (1.0e-34)
                if !scientific_notation  break;
                if (t - 1).* != #char "e" && (t - 1).* != #char "E"  break;
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

        // Handle the case where a binary number is immediately followed by a decimal number:
        // e.g. 0b100101879 - we don't want to highlight everything as one number
        #if do_highlighting {
            if t < max_t && ascii_is_digit(t.*) {
                set_token_len(tokenizer, token);
                next_token := start_new_token(tokenizer);
                next_token.type = .invalid;
                while t < max_t && (ascii_is_digit(t.*) || t.* == #char "_")  t += 1;
                set_token_len(tokenizer, *next_token);
                highlight(tokenizer, *next_token, buffer);
                return;
            }
        }
    }

    set_token_len(tokenizer, token);
}

parse_directive :: (using tokenizer: *Jai_Tokenizer, token: *Token, buffer: *Buffer, $do_highlighting := true) {
    token.type = .identifier;

    {
        defer set_token_len(tokenizer, token);

        eat_white_space(tokenizer, only_until_newline = true);  // there may be spaces between the # and the name
        if t >= max_t return;
        if !ascii_is_alpha(t.*) return;

        start_offset := cast(s32) (start_t - buf.data);

        directive_str := read_jai_identifier_string(tokenizer);

        // Check if it's one of the existing directives
        if directive_str.count > MAX_DIRECTIVE_LENGTH return;
        directive, ok := table_find(*DIRECTIVES_MAP, directive_str);
        if !ok return;

        token.type = .directive;
        token.directive = directive;

        if directive == {
            case .directive_scope_export;     start_scope(tokenizer, start_offset, .scope_export);
            case .directive_scope_module;     start_scope(tokenizer, start_offset, .scope_module);
            case .directive_scope_file;       start_scope(tokenizer, start_offset, .scope_file);
        }
    }

    // Check for modifiers
    while true {
        next_token := start_new_token(tokenizer);
        if t >= max_t return;
        if t.* != #char "," break;

        t += 1;
        next_token.type = .punctuation;
        next_token.punctuation = .comma;
        set_token_len(tokenizer, *next_token);
        #if do_highlighting then highlight(tokenizer, *next_token, buffer);

        next_token = start_new_token(tokenizer);

        is_modifier := false;
        modifier_str: string;

        if t >= max_t return;
        if ascii_is_alpha(t.*) {
            modifier_str = read_jai_identifier_string(tokenizer);
        } else if t.* == #char "\\" && (t + 1) < max_t && (t + 1).* == #char "%" {
            modifier_str = "\\%";
            t += modifier_str.count;
        }
        if !modifier_str return;

        if token.directive == {
            case .directive_type;           is_modifier = array_find(string.["isa", "distinct"], modifier_str);
            case .directive_import;         is_modifier = array_find(string.["file", "dir", "string"], modifier_str);
            case .directive_insert;         is_modifier = array_find(string.["scope"], modifier_str);
            case .directive_run;            is_modifier = array_find(string.["stallable"], modifier_str);
            case .directive_library;        is_modifier = array_find(string.["no_static_library", "no_dll", "system", "link_always"], modifier_str);
            case .directive_system_library; is_modifier = array_find(string.["no_static_library", "no_dll", "link_always"], modifier_str);
            case .directive_string;         is_modifier = array_find(string.["cr", "\\%"], modifier_str);
        }

        if is_modifier {
            next_token.type = .directive_modifier;
        } else {
            next_token.type = .identifier;
            maybe_mark_as_keyword(*next_token, modifier_str);
        }
        set_token_len(tokenizer, *next_token);
        #if do_highlighting then highlight(tokenizer, *next_token, buffer);
        if !is_modifier return;
    }

    // Maybe it's a here-string
    if token.directive == .directive_string {
        next_token := start_new_token(tokenizer);
        if t >= max_t return;
        if !ascii_is_alpha(t.*) return;

        next_token.type = .multiline_string;
        identifier_str := read_jai_identifier_string(tokenizer);

        set_token_len(tokenizer, *next_token);
        #if do_highlighting then highlight(tokenizer, *next_token, buffer);

        start := cast(s32) (t - buf.data);
        end   := find_index_from_left(buf, identifier_str, start_index = start);
        if end < 0 {
            end = buf.count - 1;
            t = max_t;
        } else {
            t = buf.data + end + identifier_str.count;
            #if do_highlighting then memset(buffer.tokens.data + end, xx Token_Type.multiline_string, identifier_str.count);  // highlight the end identifier
        }

        #if do_highlighting {
            // Maybe add a heredoc region for deferred highlighting
            potential_lang_name := identifier_str;
            {
                // Extract lang from heredoc names like BLAH_BLAH_lang
                found, _, lang := split_from_right(identifier_str, cast(u8) #char "_");
                if found then potential_lang_name = lang;
            }
            lang := get_lang_from_name(potential_lang_name);
            if lang != .Plain_Text {
                array_add(*regions, Buffer_Region.{ start = start + 1, end = xx end, kind = .heredoc, lang = lang });  // start + 1 to not include the newline
            } else {
                memset(buffer.tokens.data + start, xx Token_Type.multiline_string, end - start);  // highlight everything as string
            }
        }
    }
}

parse_colon :: (using tokenizer: *Jai_Tokenizer, token: *Token) {
    token.type      = .operation;
    token.operation = .colon;

    if t >= max_t return;

    if t.* == #char ":" {
        token.operation = .double_colon;
        t += 1;
    }
}

parse_period_or_enum_variant :: (using tokenizer: *Jai_Tokenizer, token: *Token) {
    token.type        = .punctuation;
    token.punctuation = .period;

    if t >= max_t return;

    // Maybe it's an enum variant
    if tokenizer.last_token_type != .identifier {
        eat_white_space(tokenizer, only_until_newline = true);
        if t < max_t && ascii_is_alpha(t.*) {
            read_jai_identifier_string(tokenizer);
            token.type = .enum_variant;
        }
    }
}

parse_note :: (using tokenizer: *Jai_Tokenizer, token: *Token) {
    token.type = .note;

    while t < max_t && ascii_is_alnum(<< t) t += 1;
}

parse_slash_or_comment :: (using tokenizer: *Jai_Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .slash;

    defer set_token_len(tokenizer, token);

    if t >= max_t return;

    if << t == {
        case #char "/";
            token.type = .comment;
            t += 1;
            while t < max_t && << t != #char "\n" t += 1;
        case #char "*";
            token.type = .multiline_comment;
            t += 1;
            num_open_comments := 0;
            while t + 1 < max_t {
                if << t == #char "*" && << (t + 1) == #char "/" {
                    if num_open_comments == 0 {
                        t += 2;
                        break;
                    } else {
                        num_open_comments -= 1;
                    }
                } else if << t == #char "/" && << (t + 1) == #char "*" {
                    num_open_comments += 1;
                    t += 1;
                }
                t += 1;
            }
    }
}

parse_string_literal :: (using tokenizer: *Jai_Tokenizer, token: *Token) {
    token.type = .string_literal;

    escape_seen := false;

    while t < max_t && << t != #char "\n" {
        if t.* == #char "\"" && !escape_seen break;
        escape_seen = !escape_seen && t.* == #char "\\";
        t += 1;
    }
    if t >= max_t return;

    t += 1;
}

read_jai_identifier_string :: (using tokenizer: *Jai_Tokenizer) -> string /* from scratch buffer */ {
    // Most identifiers don't have slashes in them, so assume no slashes first,
    // and fall back to a slower version if we encounter a slash
    ident: string = ---;
    ident.data = t;
    ident_max_t := min(max_t, t + MAX_IDENTIFIER_LENGTH);

    // @Speed: this is a good candidate for some SIMD - refer to the Jai_Lexer implementation for an example using intrinsics
    while t < ident_max_t && ascii_is_alnum(t.*)  t += 1;

    ident.count = t - ident.data;

    if t >= ident_max_t || t.* != #char "\\" return ident;  // we haven't seen a slash - early return

    // We have a slash - continue parsing using the slower option
    memcpy(scratch_buffer.data, ident.data, ident.count);
    scratch_pos := scratch_buffer.data + ident.count;

    // Skip initial whitespace after the slash
    t += 1;
    while t < ident_max_t && t.* == #char " "  t += 1;

    // Continue parsing
    while t < ident_max_t {
        c := t.*;
        if ascii_is_alnum(c) {
            scratch_pos.* = c;
            scratch_pos += 1;
            t += 1;
        } else if c == #char "\\" {
            t += 1;
            while t < ident_max_t && t.* == #char " "  t += 1;
        } else {
            break;
        }
    }

    return string.{ scratch_pos - scratch_buffer.data, scratch_buffer.data };
}

start_scope :: (using tokenizer: *Jai_Tokenizer, offset: s64, kind: Buffer_Region.Kind) {
    if current_scope_id >= 0 then end_scope(tokenizer, offset);
    current_scope_id = regions.count;

    region := Buffer_Region.{
        start = xx offset,
        end   = -1,
        kind  = kind,
    };
    array_add(*regions, region);
}

end_scope :: inline (using tokenizer: *Jai_Tokenizer, offset: s64) {
    regions[current_scope_id].end = xx offset;
}

Jai_Tokenizer :: struct {
    using #as base: Tokenizer;

    regions: [..] Buffer_Region;
    regions.allocator = temp;
    current_scope_id := -1;

    last_token_type: Token_Type;

    scratch_buffer: [MAX_IDENTIFIER_LENGTH] u8;
}

Token_Subtype :: union {
    keyword:        Keyword;
    punctuation:    Punctuation;
    operation:      Operation;
    directive:      Directive;
}

Token :: struct {
    using #as base: Base_Token;

    // Additional info to distinguish between keywords/punctuation
    using subtype: Token_Subtype;
}

PUNCTUATION :: string.[
    "dollar", "semicolon", "l_paren", "r_paren", "l_brace", "r_brace", "l_bracket", "r_bracket", "period", "comma",
];

OPERATIONS :: string.[
    "arrow", "bang", "backtick", "pipe", "equal", "percent", "less_than", "greater_than", "question",
    "minus", "asterisk", "colon", "double_colon", "slash", "plus", "ampersand", "tilde", "caret",
];

KEYWORDS :: string.[
    "break", "case", "cast", "code_of", "continue", "defer", "else", "enum", "enum_flags", "for", "initializer_of",
    "if", "ifx", "is_constant", "inline", "push_context", "return", "size_of", "struct", "then", "type_info", "type_of",
    "union", "using", "while", "xx", "operator", "remove", "interface", "no_inline",
];

TYPE_KEYWORDS :: string.[
    "__reg", "bool", "float", "float32", "float64", "int", "reg", "s16", "s32", "s64", "s8", "string",
    "u16", "u32", "u64", "u8", "void", "v128", "Any", "Code", "Type",
];

VALUE_KEYWORDS :: string.[
    "context", "it", "it_index", "null", "true", "false", "temp",
];

DIRECTIVES :: string.[
    "add_context", "align", "as", "asm", "assert", "bake_arguments", "bake_constants", "bytes", "c_call", "caller_code",
    "caller_location", "char", "code", "compiler", "complete", "cpp_method", "cpp_return_type_is_non_pod", "deprecated",
    "dump", "dynamic_specialize", "elsewhere", "expand", "file", "filepath", "foreign", "library", "system_library",
    "if", "ifx", "import", "insert", "insert_internal", "intrinsic", "line", "load",
    "location", "modify", "module_parameters", "must", "no_abc", "no_aoc", "no_alias", "no_context", "no_padding", "no_reset",
    "place", "placeholder", "poke_name", "procedure_of_call", "program_export", "run", "runtime_support",
    "scope_export", "scope_file", "scope_module", "specified", "string", "symmetric", "this", "through", "type",
    "type_info_no_size_complaint", "type_info_none", "type_info_procedures_are_void_pointers",
    "compile_time", "no_debug", "procedure_name", "discard", "entry_point", "Context",
    // temporary:
    "v2",
];

#insert -> string {
    b: String_Builder;
    init_string_builder(*b);

    define_enum :: (b: *String_Builder, enum_name: string, prefix: string, value_lists: [][] string) {
        print_to_builder(b, "% :: enum u8 {\n", enum_name);
        for values : value_lists {
            for v : values print_to_builder(b, "    %0%;\n", prefix, v);
        }
        print_to_builder(b, "}\n");
    }

    define_enum(*b, "Punctuation",  "",           .[PUNCTUATION]);
    define_enum(*b, "Operation",    "",           .[OPERATIONS]);
    define_enum(*b, "Keyword",      "kw_",        .[KEYWORDS, TYPE_KEYWORDS, VALUE_KEYWORDS]);
    define_enum(*b, "Directive",    "directive_", .[DIRECTIVES]);

    return builder_to_string(*b);
}

Keyword_Token :: struct {
    type: Token_Type;
    keyword: Keyword;
}

KEYWORD_MAP :: #run -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    size := 5 * (KEYWORDS.count + TYPE_KEYWORDS.count + VALUE_KEYWORDS.count);
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        for KEYWORDS        append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .keyword, keyword = .kw_%1 });\n", it));
        for TYPE_KEYWORDS   append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .type,    keyword = .kw_%1 });\n", it));
        for VALUE_KEYWORDS  append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .value,   keyword = .kw_%1 });\n", it));
        return builder_to_string(*b);
    }

    return table;
}

DIRECTIVES_MAP :: #run -> Table(string, Directive) {
    table: Table(string, Directive);
    size := 5 * DIRECTIVES.count;
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        init_string_builder(*b);
        for DIRECTIVES {
            print_to_builder(*b, "table_add(*table, \"%1\", .directive_%1);\n", it);
        }
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

MAX_DIRECTIVE_LENGTH :: #run -> s32 {
    result: s64;
    for DIRECTIVES { if it.count > result then result = it.count; }
    return xx result;
}

MAX_IDENTIFIER_LENGTH :: 512;
