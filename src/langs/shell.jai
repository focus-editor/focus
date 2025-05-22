tokenize_shell :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_tokenizer(buffer, start_offset, count);
    tokenizer.prev_tokens[0] = New(Token,, temp);
    tokenizer.prev_tokens[1] = New(Token,, temp);
    tokenizer.prev_tokens[2] = New(Token,, temp);

    // Reset subshell states
    for * subshell_states  it.* &= 0;
    subshell_index = 0;

    inside_backticks := false;

    while true {
        set_token_color :: (token: Token, type: Token_Type) #expand {
            memset(`buffer.tokens.data + token.start, xx type, token.len);
        }

        token := get_next_token(*tokenizer);
        if token.type == .eof then break;

        subshell_state := *subshell_states[subshell_index];

        if token.type == {
            case .operation;
                if token.operation == {
                    case .equal;           #through;
                    case .plus_equal;
                        // Retroactively rehighlight a variable definition (identifier) that got confused as a function
                        prev := previous_token(*tokenizer, 0);
                        if prev.type == .function then set_token_color(prev, .identifier);

                    case .dollar_paren;    #through;
                    case .less_than_paren;
                        if subshell_index < subshell_states.count-1 then subshell_index += 1;

                    case .dollar_double_paren;
                        subshell_state.* |= .INSIDE_PAREN_EXPRESSION;

                    case .dollar_brace;
                        subshell_state.* |= .INSIDE_BRACE_VARIABLE;

                    case .backtick;
                        prev := previous_token(*tokenizer, 0);
                        if !(prev.type == .operation && prev.operation == .backslash) {
                            if !inside_backticks {
                                inside_backticks = true;
                                if subshell_index < subshell_states.count-1 then subshell_index += 1;
                            }
                            else {
                                inside_backticks = false;
                                if subshell_index > 0 {
                                    subshell_index -= 1;
                                    subshell_state.* &= 0;
                                }
                            }
                        }
                }

            case .punctuation;
                if token.punctuation == {
                    case .double_quote;
                        prev := previous_token(*tokenizer, 0);
                        if !(prev.type == .operation && prev.operation == .backslash) {
                            // If the previous token was not a backslash...
                            if subshell_state.* & .INSIDE_QUOTED_STRING {
                                // ... and we ARE in quoted string mode, exit quoted string mode, and also highlight this quote as a string
                                subshell_state.* &= ~.INSIDE_QUOTED_STRING;
                                token.type = .string_literal;
                            }
                            else {
                                // ... and we are NOT in quoted string mode, enter quoted string mode
                                subshell_state.* |= .INSIDE_QUOTED_STRING;
                            }
                        }

                    case .r_paren;
                        if subshell_index > 0 {
                            subshell_index -= 1;
                            subshell_state.* &= 0;
                            token.type = .operation;
                            token.operation = .close_paren;
                        }

                    case .r_double_paren;
                        if subshell_state.* & .INSIDE_PAREN_EXPRESSION {
                            subshell_state.* &= ~.INSIDE_BRACE_VARIABLE;
                            token.type = .operation;
                            token.operation = .close_double_paren;
                        }

                    case .r_brace;
                        if subshell_state.* & .INSIDE_BRACE_VARIABLE {
                            subshell_state.* &= ~.INSIDE_BRACE_VARIABLE;
                            token.type = .operation;
                            token.operation = .close_brace;
                        }
                }
        }

        // Remember last 3 tokens
        previous_token(*tokenizer, 2).* = previous_token(*tokenizer, 1).*;
        previous_token(*tokenizer, 1).* = previous_token(*tokenizer, 0).*;
        previous_token(*tokenizer, 0).* = token;

        if subshell_state.* & .INSIDE_QUOTED_STRING {
            // When inside string literals, color operations and values normally, but highlight everything else as part of the string
            if token.type == .operation {
                // Always highlight these as operators when inside quoted strings
                if token.operation == {
                    case .dollar;              #through;
                    case .double_dollar;       #through;
                    case .dollar_at;           #through;
                    case .dollar_asterisk;     #through;
                    case .dollar_hash;         #through;
                    case .dollar_question;     #through;
                    case .dollar_minus;        #through;
                    case .dollar_underscore;   #through;
                    case .dollar_bang;         #through;
                    case .dollar_number;       #through;

                    case .dollar_paren;        #through;
                    case .dollar_double_paren; #through;
                    case .close_paren;         #through;
                    case .close_double_paren;  #through;
                    case .dollar_brace;        #through;
                    case .close_brace;         #through;

                    case .hash;                #through;
                    case .double_hash;         #through;
                    case .percent;             #through;
                    case .double_percent;      #through;

                    case .backtick;            #through;
                    case .backslash;
                        set_token_color(token, token.type);

                    case;
                        set_token_color(token, .string_literal);
                }

                if subshell_state.* & .INSIDE_BRACE_VARIABLE {
                    // Only override these as operators inside brace variables when inside quoted strings
                    // They should get set normally when not inside strings
                    if token.operation == {
                        case .colon;           #through;
                        case .plus;            #through;
                        case .minus;           #through;
                        case .equal;
                            set_token_color(token, token.type);
                    }
                }
            }
            else if token.type == .value {
                set_token_color(token, token.type);
            }
            else {
                set_token_color(token, .string_literal);
            }
        }
        else {
            set_token_color(token, token.type);
        }
    }

    return .[];
}

tokenize_shell_for_indentation :: (buffer: Buffer) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_tokenizer(buffer);
    tokenizer.prev_tokens[0] = New(Token,, temp);
    tokenizer.prev_tokens[1] = New(Token,, temp);
    tokenizer.prev_tokens[2] = New(Token,, temp);

    // Reset subshell states
    for * subshell_states  it.* &= 0;
    subshell_index = 0;

    inside_backticks := false;

    while true {
        subshell_state := *subshell_states[subshell_index];

        src := get_next_token(*tokenizer);
        if src.type == {
            case .operation;
                if src.operation == {
                    case .dollar_brace;
                        subshell_state.* |= .INSIDE_BRACE_VARIABLE;

                    case .dollar_paren;
                        if subshell_index < subshell_states.count-1 then subshell_index += 1;

                    case .backtick;
                        prev := previous_token(*tokenizer, 0);
                        if !(prev.type == .operation && prev.operation == .backslash) {
                            if !inside_backticks {
                                inside_backticks = true;
                                if subshell_index < subshell_states.count-1 then subshell_index += 1;
                            }
                            else {
                                inside_backticks = false;
                                if subshell_index > 0 {
                                    subshell_index -= 1;
                                    subshell_state.* &= 0;
                                }
                            }
                        }
                }

            case .punctuation;
                if src.punctuation == {
                    case .double_quote;
                        prev := previous_token(*tokenizer, 0);
                        if !(prev.type == .operation && prev.operation == .backslash) {
                            // If the previous token was not a backslash...
                            if subshell_state.* & .INSIDE_QUOTED_STRING {
                                // ... and we ARE in quoted string mode, exit quoted string mode, and also highlight this quote as a string
                                subshell_state.* &= ~.INSIDE_QUOTED_STRING;
                                src.type = .string_literal;
                            }
                            else {
                                // ... and we are NOT in quoted string mode, enter quoted string mode
                                subshell_state.* |= .INSIDE_QUOTED_STRING;
                            }
                        }

                    case .r_brace;
                        if subshell_state.* & .INSIDE_BRACE_VARIABLE {
                            subshell_state.* &= ~.INSIDE_BRACE_VARIABLE;
                            src.type = .operation;
                            src.operation = .close_brace;
                        }

                    case .r_paren;
                        if subshell_index > 0 {
                            subshell_index -= 1;
                            subshell_state.* &= 0;
                            src.type = .operation;
                            src.operation = .close_paren;
                        }

                    case .r_double_paren;
                        if subshell_state.* & .INSIDE_PAREN_EXPRESSION {
                            subshell_state.* &= ~.INSIDE_PAREN_EXPRESSION;
                            src.type = .operation;
                            src.operation = .close_double_paren;
                        }
                }
        }

        previous_token(*tokenizer, 2).* = previous_token(*tokenizer, 1).*;
        previous_token(*tokenizer, 1).* = previous_token(*tokenizer, 0).*;
        previous_token(*tokenizer, 0).* = src;

        token: Indentation_Token = ---;
        token.start = src.start;
        token.len   = src.len;

        if src.type == {
            case .keyword;
                if src.keyword == {
                    case .kw_then;     token.type = .open;  token.kind = .brace;
                    case .kw_fi;       token.type = .close; token.kind = .brace;
                    case .kw_else;
                        // Intentionally adding 2 tokens to get a `}{` effect when indenting
                        token.type = .close; token.kind = .brace;
                        array_add(*tokens, token);
                        token.type = .open; token.kind = .brace;

                    case .kw_do;       token.type = .open;  token.kind = .brace;
                    case .kw_done;     token.type = .close; token.kind = .brace;

                    case .kw_case;     token.type = .open;  token.kind = .bracket;
                    case .kw_esac;     token.type = .close; token.kind = .bracket;

                    case;               continue;
                }

            case .punctuation;
                if src.punctuation == {
                    case .l_brace;      token.type = .open;  token.kind = .brace;
                    case .r_brace;      token.type = .close; token.kind = .brace;

                    case;               continue;
                }

            case .eof;                  token.type = .eof;  // to guarantee we always have indentation tokens
            case;                       token.type = .unimportant;
        }

        array_add(*tokens, token);

        if src.type == .eof break;
    }

    return tokens;
}

#scope_file

Subshell_State :: enum_flags u8 {
    INSIDE_BRACE_VARIABLE;
    INSIDE_PAREN_EXPRESSION;
    INSIDE_QUOTED_STRING;
}

subshell_index := 0;
subshell_states: [4]Subshell_State;  // Only going to bother going 3 subshells deep, plus the top level shell. If you're doing more than this, program in a better language.

previous_token :: (tokenizer: *Tokenizer, index: int) -> *Token #expand {
    return cast(*Token) tokenizer.prev_tokens[index];
}

get_next_token :: (using tokenizer: *Tokenizer) -> Token {
    eat_white_space_no_newline(tokenizer);

    token: Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;
    if t >= max_t return token;

    start_t = t;

    char := t.*;
    if is_alpha(char) || char == #char "_" || char == #char "/" {
        parse_identifier(tokenizer, *token);
    }
    else if char == #char "." {
        // `.` by itself is equivalent to the `source` command, but some identifiers can also start with `.` (yay hidden files...)
        // So we check the next character to see whether the period is by itself or not.
        next_t := t + 1;
        if next_t < max_t {
            if is_white_space(next_t.*) {
                token.type = .operation;
                token.operation = .period;
                t += 1;
            }
            else {
                parse_identifier(tokenizer, *token);
            }
        }
    }
    else if is_digit(char) {
        parse_number_c_like(tokenizer, *token);
    }
    else if char == {
        case #char "~";  parse_tilde                  (tokenizer, *token);
        case #char ";";  parse_semicolon              (tokenizer, *token);
        case #char "%";  parse_percent                (tokenizer, *token);
        case #char "#";  parse_hash_comment_or_shebang(tokenizer, *token);
        case #char "'";  parse_single_quote           (tokenizer, *token);

        case #char "+";  parse_plus                   (tokenizer, *token);
        case #char "-";  parse_minus                  (tokenizer, *token);
        case #char "&";  parse_ampersand              (tokenizer, *token);
        case #char "|";  parse_pipe                   (tokenizer, *token);
        case #char "=";  parse_equal                  (tokenizer, *token);
        case #char "<";  parse_less_than              (tokenizer, *token);
        case #char ">";  parse_greater_than           (tokenizer, *token);
        case #char "!";  parse_bang                   (tokenizer, *token);
        case #char "$";  parse_dollar                 (tokenizer, *token);
        case #char "(";  parse_l_paren                (tokenizer, *token);
        case #char ")";  parse_r_paren                (tokenizer, *token);

        case #char ":";  token.type = .operation; token.operation = .colon;     t += 1;
        case #char "*";  token.type = .operation; token.operation = .asterisk;  t += 1;
        case #char "\\"; token.type = .operation; token.operation = .backslash; t += 1;
        case #char "`";  token.type = .operation; token.operation = .backtick;  t += 1;

        case #char "@";  token.type = .punctuation; token.punctuation = .at;           t += 1;
        case #char "^";  token.type = .punctuation; token.punctuation = .caret;        t += 1;
        case #char "\""; token.type = .punctuation; token.punctuation = .double_quote; t += 1;
        case #char "\n"; token.type = .punctuation; token.punctuation = .newline;      t += 1;
        case #char "{";  token.type = .punctuation; token.punctuation = .l_brace;      t += 1;
        case #char "}";  token.type = .punctuation; token.punctuation = .r_brace;      t += 1;
        case #char "[";  token.type = .punctuation; token.punctuation = .l_bracket;    t += 1;
        case #char "]";  token.type = .punctuation; token.punctuation = .r_bracket;    t += 1;

        case;            token.type = .invalid; t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);
    return token;
}

parse_identifier :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .identifier;
    identifier_str := read_identifier_string_with_extras(tokenizer);

    prev_0 := previous_token(tokenizer, 0);
    prev_1 := previous_token(tokenizer, 1);

    if prev_0.type == .operation {
        if prev_0.operation == {
            // If there's a `-`, `--`, or before the identifier, don't change it
            case .minus;        return;
            case .double_minus; return;

            // If there's a `<<`, `<<-`, or `<<<` before the identifier, it's a here-string
            case .double_less_than;       #through;
            case .double_less_than_minus; #through;
            case .triple_less_than;
                token.type = .multiline_string;
                start := cast(s32) (t - buf.data);
                end := find_index_from_left(buf, identifier_str, start_index = start);
                if end < 0 {
                    end = buf.count - 1;
                    t = max_t;
                }
                else {
                    t = buf.data + end + identifier_str.count;
                }
        }
    }

    token_can_precede_function_token :: (token: Token) -> bool {
        if token.type == {
            case .keyword;
                if token.keyword == .kw_function then return true;

            case .punctuation;
                // First identifier in a line (without anything before it) is usually a function
                if token.punctuation == .newline then return true;

            case .operation;
                if token.operation == {
                    case .dollar_paren;     #through;  // ... $( ident ...
                    case .less_than_paren;  #through;  // ... <( ident ...
                    case .backtick;         #through;  // ... `  ident ...
                    case .pipe;             #through;  // ... |  ident ...
                    case .double_pipe;      #through;  // ... || ident ...
                    case .ampersand;        #through;  // ... &  ident ...
                    case .double_ampersand;            // ... && ident ...
                        return true;
                }
        }

        return false;
    }

    if token_can_precede_function_token(prev_0) {
        token.type = .function;
    }
    else if (prev_0.type == .operation && prev_0.operation == .backslash) && token_can_precede_function_token(prev_1) {
        // Having a backslash to circumvent aliases usually has the same rules as not having the backslash
        token.type = .function;
    }

    // Check if it's a keyword, and highlight accordingly if so
    if identifier_str.count > MAX_KEYWORD_LENGTH then return;

    kw_token, ok := table_find(*KEYWORD_MAP, identifier_str);
    if !ok then return;

    token.type = kw_token.type;
    token.keyword = kw_token.keyword;
}

parse_tilde :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .punctuation;
    token.punctuation = .tilde;

    t += 1;
    if t >= max_t return;

    if t.* == #char "=" {
        // Explicitly highlight `~=` as invalid because sh/bash/zsh is stupid and put these backwards????
        token.type = .invalid;
        t += 1;
    }

    if t > max_t then t = max_t;
}

parse_semicolon :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .punctuation;
    token.punctuation = .semicolon;

    t += 1;
    if t >= max_t return;

    if t.* == #char ";" {
        token.type = .operation;
        token.operation = .double_semicolon;
        t += 1;
    }

    if t > max_t then t = max_t;
}

parse_percent :: (using tokenizer: *Tokenizer, token: *Token) {
    if subshell_states[subshell_index] & .INSIDE_BRACE_VARIABLE {
        token.type = .operation;
        token.operation = .percent;

        t += 1;
        if t >= max_t return;

        if t.* == #char "%" {
            token.operation = .double_percent;
            t += 1;
        }

        return;
    }

    token.type = .punctuation;
    token.punctuation = .percent;
    t += 1;
}

parse_hash_comment_or_shebang :: (using tokenizer: *Tokenizer, token: *Token) {
    state := subshell_states[subshell_index];

    if state & .INSIDE_BRACE_VARIABLE {
        token.type = .operation;
        token.operation = .hash;
        t += 1;

        if t < max_t && t.* == #char "#" {
            token.operation = .double_hash;
            t += 1;
        }
    }
    else if state & .INSIDE_QUOTED_STRING {
        token.type = .punctuation;
        token.punctuation = .hash;
        t += 1;
    }
    else {
        token.type = .comment;
        t += 1;

        if t >= max_t then return;

        if t.* == #char "!" {
            token.type = .directive;  // shebang
            t += 1;
        }

        eat_until_newline(tokenizer);
    }

    if t > max_t then t = max_t;
}

parse_single_quote :: (using tokenizer: *Tokenizer, token: *Token) {
    prev := previous_token(tokenizer, 0);

    // If we're inside a quoted string, `'` shouldn't do anything
    // If we see a backslash before `'`, it shouldn't do anything
    if (subshell_states[subshell_index] & .INSIDE_QUOTED_STRING) || (prev.type == .operation && prev.operation == .backslash) {
        token.type = .punctuation;
        token.punctuation = .single_quote;
        t += 1;
        return;
    }

    // Otherwise it should start a string literal
    token.type = .string_literal;
    t += 1;

    escape_seen := false;
    while t < max_t {
        if t.* == #char "'" && !escape_seen then break;
        escape_seen = (!escape_seen && t.* == #char "\\");
        t += 1;
    }

    if t >= max_t then return;
    t += 1;  // Eat the last delimiter
}

parse_plus :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .plus;

    t += 1;
    if t >= max_t return;

    if t.* == #char "=" {
        token.operation = .plus_equal;
        t += 1;
    }

    if t > max_t then t = max_t;
}

parse_minus :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .minus;

    t += 1;
    if t >= max_t return;

    if t.* == #char "-" {
        token.operation = .double_minus;
        t += 1;
    }

    if t > max_t then t = max_t;
}

parse_ampersand :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .ampersand;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "&"; token.operation = .double_ampersand;       t += 1;
        case #char "<"; token.operation = .ampersand_less_than;    t += 1;
        case #char ">"; token.operation = .ampersand_greater_than; t += 1;
    }

    if t > max_t then t = max_t;
}

parse_pipe :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .pipe;

    t += 1;
    if t >= max_t return;

    if t.* == #char "|" {
        token.operation = .double_pipe;
        t += 1;
    }

    if t > max_t then t = max_t;
}

parse_equal :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .equal;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "=";  token.operation = .double_equal; t += 1;
        case #char "~";  token.operation = .equal_tilde;  t += 1;
    }

    if t > max_t then t = max_t;
}

parse_less_than :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .less_than;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "<";
            token.operation = .double_less_than;
            t += 1;

            if t < max_t {
                if t.* == {
                    case #char "<"; token.operation = .triple_less_than;       t += 1;
                    case #char "-"; token.operation = .double_less_than_minus; t += 1;
                }
            }

        case #char "&";
            token.operation = .less_than_ampersand;
            t += 1;

        case #char ">";
            token.operation = .less_greater_than;
            t += 1;

        case #char "(";
            token.operation = .less_than_paren;
            t += 1;
    }

    if t > max_t then t = max_t;
}

parse_greater_than :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .greater_than;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char ">";
            token.operation = .double_greater_than;
            t += 1;

            if t < max_t && t.* == #char ">" {
                token.operation = .triple_less_than;
                t += 1;
            }

        case #char "&";
            token.operation = .greater_than_ampersand;
            t += 1;

        case #char "|";
            token.operation = .greater_than_pipe;
            t += 1;
    }

    if t > max_t then t = max_t;
}

parse_bang :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .bang;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "!";
            token.operation = .double_bang;
            t += 1;

            if t < max_t && t.* == #char ":" {
                token.operation = .double_bang_colon;
                t += 1;
            }

        case #char "=";
            token.operation = .bang_equal;
            t += 1;

        case #char "$";
            token.operation = .bang_dollar;
            t += 1;

        case #char "*";
            token.operation = .bang_asterisk;
            t += 1;

        case #char "-";
            token.operation = .bang_minus;
            t += 1;

        case #char "^";
            token.operation = .bang_caret;
            t += 1;

        case; if is_digit(t.*) {
            token.operation = .bang_number;
            t += 1;
        }
    }

    if t > max_t then t = max_t;
}

parse_dollar :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .operation;
    token.operation = .dollar;

    t += 1;
    if t >= max_t return;

    if t.* == {
        case #char "$";
            token.operation = .double_dollar;
            t += 1;

        case #char "@";
            token.operation = .dollar_at;
            t += 1;

        case #char "*";
            token.operation = .dollar_asterisk;
            t += 1;

        case #char "#";
            token.operation = .dollar_hash;
            t += 1;

        case #char "?";
            token.operation = .dollar_question;
            t += 1;

        case #char "-";
            token.operation = .dollar_minus;
            t += 1;

        case #char "_";
            token.operation = .dollar_underscore;
            t += 1;

        case #char "!";
            token.operation = .dollar_bang;
            t += 1;

        case #char "{";
            token.operation = .dollar_brace;
            t += 1;

            if t < max_t {
                next_t := t + 1;
                if next_t < max_t && next_t.* == #char "}" {
                    if t.* == {
                        case #char "@";
                            token.operation = .dollar_at;
                            t += 2;  // Eat the `@` and the `}`
                        case #char "*";
                            token.operation = .dollar_asterisk;
                            t += 2;  // Eat the `*` and the `}`
                        case #char "#";
                            token.operation = .dollar_hash;
                            t += 2;  // Eat the `#` and the `}`
                        case #char "?";
                            token.operation = .dollar_question;
                            t += 2;  // Eat the `?` and the `}`
                        case #char "-";
                            token.operation = .dollar_minus;
                            t += 2;  // Eat the `-` and the `}`
                        case #char "!";
                            token.operation = .dollar_bang;
                            t += 2;  // Eat the `!` and the `}`
                        case;
                            if is_digit(t.*) {
                                token.operation = .dollar_number;
                                t += 2;  // Eat the digit and the `}`
                            }
                    }
                }
            }

        case #char "(";
            token.operation = .dollar_paren;
            t += 1;

            if t < max_t && t.* == #char "(" {
                token.operation = .dollar_double_paren;
                t += 1;
            }

        case;
            if is_digit(t.*) {
                token.operation = .dollar_number;
                t += 1;
            }
    }

    if t > max_t then t = max_t;
}

parse_l_paren :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .punctuation;
    token.punctuation = .l_paren;

    t += 1;
    if t >= max_t return;

    if t.* == #char "(" {
        token.punctuation = .l_double_paren;
        t += 1;
    }

    if t > max_t then t = max_t;
}

parse_r_paren :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .punctuation;
    token.punctuation = .r_paren;

    t += 1;
    if t >= max_t return;

    if t.* == #char ")" {
        token.punctuation = .r_double_paren;
        t += 1;
    }

    if t > max_t then t = max_t;
}

read_identifier_string_with_extras :: (using tokenizer: *Tokenizer) -> string {
    identifier: string;
    identifier.data = t;

    while t < max_t && (is_alnum(t.*) || t.* == #char "/" || t.* == #char "-" || t.* == #char ".") {
        t += 1;
    }

    if t >= max_t then t = max_t;
    identifier.count = t - identifier.data;

    return identifier;
}

eat_white_space_no_newline :: (using tokenizer: *Tokenizer) {
    old_t := t;
    while t < max_t {
        if t.* == #char "\n"    then break;  // Make newlines a token
        if !is_white_space(t.*) then break;
        t += 1;
    }
    had_white_space_to_skip = t != old_t;
}


Token :: struct {
    using #as base: Base_Token;

    // Additional info to distinguish between keywords/punctuation
    union {
        punctuation: Punctuation;
        operation:   Operation;
        keyword:     Keyword;
    }
}

// https://devhints.io/bash
// https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html
// https://pubs.opengroup.org/onlinepubs/9799919799/ > XCU > 2. Shell Command Language
PUNCTUATION :: string.[
    "unknown",

    "tilde", "semicolon", "percent", "hash", "at", "caret", "single_quote", "double_quote",

    "l_paren", "r_paren", "l_double_paren", "r_double_paren",
    "l_bracket", "r_bracket", "l_double_bracket", "r_double_bracket",
    "l_brace", "r_brace",

    "newline",  // Optional semicolons
];

OPERATIONS :: string.[
    "unknown",

    "period",
    "colon", "asterisk", "plus", "backslash", "backtick",

    "minus", "double_minus",
    "ampersand", "double_ampersand", "ampersand_less_than", "ampersand_greater_than",
    "pipe", "double_pipe",
    "equal", "double_equal", "bang_equal", "equal_tilde", "plus_equal",
    "less_than", "less_than_ampersand", "less_than_paren", "double_less_than", "double_less_than_minus", "triple_less_than",
    "greater_than", "greater_than_ampersand", "greater_than_pipe", "double_greater_than", "triple_greater_than",
    "less_greater_than",

    "bang", "double_bang", "double_bang_colon", "bang_dollar", "bang_asterisk", "bang_minus", "bang_caret", "bang_number",

    "dollar", "dollar_at", "dollar_asterisk", "dollar_hash", "dollar_question",
    "dollar_minus", "dollar_underscore", "double_dollar", "dollar_bang", "dollar_number",
    "dollar_brace", "close_brace", "dollar_paren", "close_paren", "dollar_double_paren", "close_double_paren",

    "double_semicolon",
    "percent", "double_percent",
    "hash", "double_hash",
];

KEYWORDS :: string.[
    "if", "elif", "else", "fi",
    "for", "while", "until",
    "case", "esac",
    "function", "select",
    "then", "in", "do", "done",
    "break", "continue",
    "exit", "return",

    "local", "readonly", "declare", "set", "unset",
    "shopt", "getopts", "setopt",
    "alias", "command", "complete", "disown", "emulate", "eval", "exec", "export", "shift", "source", "times", "trap", "type", "typeset", "umask",
];

VALUE_KEYWORDS :: string.[
    "HOME", "PATH", "LANG", "PWD", "OLDPWD", "USER",
    "SHELL", "TERM", "COLORTERM", "ENV", "IFS",
    "DISPLAY", "EDITOR", "VISUAL",
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

    define_enum(*b, "Punctuation", "",     .[PUNCTUATION]);
    define_enum(*b, "Operation",   "",     .[OPERATIONS]);
    define_enum(*b, "Keyword",     "kw_" , .[KEYWORDS, VALUE_KEYWORDS]);

    return builder_to_string(*b);
}

Keyword_Token :: struct {
    type: Token_Type;
    keyword: Keyword;
}

KEYWORD_MAP :: #run -> Table(string, Keyword_Token) {
    table: Table(string, Keyword_Token);
    size := 10 * (KEYWORDS.count + VALUE_KEYWORDS.count);
    init(*table, size);

    #insert -> string {
        b: String_Builder;
        for KEYWORDS        append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .keyword, keyword = .kw_%1 });\n", it));
        for VALUE_KEYWORDS  append(*b, sprint("table_add(*table, \"%1\", Keyword_Token.{ type = .value,   keyword = .kw_%1 });\n", it));
        return builder_to_string(*b);
    }

    return table;
}

MAX_KEYWORD_LENGTH :: #run -> s32 {
    result: s64;
    for KEYWORDS        { if it.count > result then result = it.count; }
    for VALUE_KEYWORDS  { if it.count > result then result = it.count; }
    return xx result;
}

