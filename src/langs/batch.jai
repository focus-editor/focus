tokenize_batch :: (using buffer: *Buffer, start_offset := -1, count := -1) -> [] Buffer_Region {
    tokenizer := get_batch_tokenizer(buffer, start_offset, count);

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;
        memset(tokens.data + token.start, xx TOKEN_MAP[token.type], token.len);
    }

    return .[];
}

tokenize_batch_for_indentation :: (buffer: Buffer) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_batch_tokenizer(buffer);

    while true {
        src := get_next_token(*tokenizer);

        token: Indentation_Token = ---;
        token.start = src.start;
        token.len   = src.len;

        if src.type == {
            case .parenthesis_open; {
                token.type = .open;
                token.kind = .brace;
            }

            case .parenthesis_close; {
                token.type = .close;
                token.kind = .brace;
            }

            case .eof;  token.type = .eof;  // to guarantee we always have indentation tokens
            case;       token.type = .unimportant;
        }

        array_add(*tokens, token);

        if src.type == .eof break;
    }

    return tokens;
}

#scope_file

get_batch_tokenizer :: (using buffer: Buffer, start_offset := -1, count := -1) -> Batch_Tokenizer {
    tokenizer: Batch_Tokenizer;

    tokenizer.buf       = to_string(bytes);
    tokenizer.max_t     = bytes.data + bytes.count;
    tokenizer.t         = bytes.data;

    if start_offset >= 0 {
        start_offset = clamp(start_offset, 0, bytes.count - 1);
        count        = clamp(count,        0, bytes.count - 1);
        tokenizer.t += start_offset;
        tokenizer.max_t = tokenizer.t + count;
    }

    return tokenizer;
}

get_next_token :: (using tokenizer: *Batch_Tokenizer) -> Batch_Token {
    // A caret preceding a newline escapes the newline.
    if last_token.type == .caret_op && t < max_t {
        if at_char(tokenizer, #char "\n")     t += 1;
        else if at_string(tokenizer, "\r\n")  t += 2;
    }

    _, ate_newlines := eat_white_space(tokenizer);
    if ate_newlines || last_token.type == .redirection_op || last_token.type == .keyword_do {
        unset_active_command(tokenizer);
    }

    newline_since_last_token = ate_newlines || t == buf.data;

    token: Batch_Token;
    token.start = cast(s32) (t - buf.data);
    token.type  = .eof;

    if t >= max_t return token;
    start_t = t;

    parse_token(tokenizer, *token);

    if token.type == .eof {
        token.type = .error;
        t += 1;
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);

    assert(token.len > 0, "Produced an empty token (type is %).", token.type);

    last_token = token;

    return token;
}

peek_next_token :: (using tokenizer: *Batch_Tokenizer, $skip_characters := 0) -> Batch_Token {
    tokenizer_copy := tokenizer.*;
    tokenizer_copy.t += skip_characters;
    token := get_next_token(*tokenizer_copy);
    return token;
}

parse_token :: (using tokenizer: *Batch_Tokenizer, token: *Batch_Token) {
    if parse_parenthesis(tokenizer, token) {
        dont_interpret := last_token.type == .caret_op;
        dont_interpret |= parsing_set_value && parenthesis_depth == 0;
        dont_interpret |= active_command == .command_echo && parenthesis_depth == 0;

        if dont_interpret {
            token.type = .default;
            return;
        }

        if token.type == .parenthesis_open  parenthesis_depth += 1;
        else if parenthesis_depth > 0       parenthesis_depth -= 1;

        if active_command == .command_for && last_token.type == .keyword_in {
            parsing_for_set = true;
        } else {
            unset_active_command(tokenizer);
        }

        return;
    }

    if parse_redirection_operator(tokenizer, token)  return;

    if last_token.type == .variable && parse_bracket(tokenizer, token)  return;

    if parsing_pseudo_array_access {
        if parse_bracket(tokenizer, token)   return;
        if parse_variable(tokenizer, token)  return;
    }

    if active_command == .invalid && last_token.type != .file_redirection_op {
        if parse_string(tokenizer, token) {
            set_active_command(tokenizer, .other);
            return;
        }

        if at_char(tokenizer, #char ":") {
            if newline_since_last_token {
                if parse_label_declaration(tokenizer, token)  return;

                next := next_char(tokenizer);

                // Handle both the double-colon comment style, and the more obscure single-colon style.
                if next == #char ":" || is_whitespace_char(next) {
                    parse_rest_of_line_as_comment(tokenizer, token);
                    return;
                }
            }
        }

        // Everything after a label declaration is also treated as a comment.
        if last_token.type == .label_declaration && !newline_since_last_token {
            parse_rest_of_line_as_comment(tokenizer, token);
            return;
        }

        if t + 1 < max_t && at_char(tokenizer, #char "@") {
            tokenizer_copy := tokenizer.*;
            tokenizer_copy.t += 1;
            tokenizer_copy.start_t += 1;
            next_token: Batch_Token;
            parse_token(*tokenizer_copy, *next_token);

            if next_token.type == .command || next_token.type == .command_path || next_token.type == .command_rem {
                token.type = .at_op;
            } else {
                token.type = .default;
            }

            t += 1;
            return;
        }

        // The command can be represented by a variable.
        if parse_variable(tokenizer, token) {
            active_command = .other;
            return;
        }

        // Check for keywords.
        name := eat_simple_name(tokenizer);
        if name {
            if equal_nocase(name, "else") { token.type = .keyword_else; return; }
            if equal_nocase(name, "in")   { token.type = .keyword_in;   return; }
            if equal_nocase(name, "do")   { token.type = .keyword_do;   return; }
            t = start_t;
        }

        if starts_command(t.*) {
            command_name := parse_command(tokenizer, token);
            command := check_for_internal_command_name(command_name);

            if command == .command_rem {
                token.type = .command_rem;
                eat_until_any(tokenizer, "\r\n");
                return;
            }

            // Not an internal command, but we know this is some kind of command.
            if command == .invalid  command = .other;

            set_active_command(tokenizer, command);
            return;
        }

        if parse_path(tokenizer, token) {
            set_active_command(tokenizer, .other);
            return;
        }
    } else {
        if parse_caret(tokenizer, token)  return;

        if parse_flag(tokenizer, token) {
            if active_command == .command_set {
                flag_letter := (start_t + 1).*;
                if t - start_t == 2 && flag_letter == #char "a" || flag_letter == #char "A" {
                    parsing_arithmetic_set = true;
                }
            }

            return;
        }

        if active_command == {
            case .command_set; {
                if parse_string(tokenizer, token)  return;

                if parsing_arithmetic_set {
                    if at_any(tokenizer, "+-*/") {
                        t += 1;
                        token.type = .op;
                        return;
                    }
                }

                if parsing_set_value {
                    if eat_until_any(tokenizer, ")><|&^\r\n") {
                        token.type = .default;
                        return;
                    }
                }

                if at_char(tokenizer, #char "=") {
                    token.type = .op;
                    t += 1;
                    parsing_set_value = true;
                    return;
                }

                if active_command_argument_count == 0 {
                    if eat_simple_name(tokenizer, parenthesis_depth == 0) {
                        active_command_argument_count += 1;
                        token.type = .variable;
                        return;
                    }
                }
            }

            case .command_if; {
                token_is_if_conditional_operand: bool;

                defer {
                    if token_is_if_conditional_operand {
                        if last_token.type == .if_op || last_token.type == .op ||
                            last_token.type == .keyword_exist || last_token.type == .keyword_defined ||
                            last_token.type == .builtin_variable {
                            unset_active_command(tokenizer);
                        }
                    }
                }

                if parse_bracket(tokenizer, token) {
                    if token.type == .bracket_close && parsed_if_conditional_operator  unset_active_command(tokenizer);
                    return;
                }

                if parse_string(tokenizer, token) || parse_variable(tokenizer, token) {
                    token_is_if_conditional_operand = true;
                    return;
                }

                name := eat_simple_name(tokenizer);

                if name {
                    if equal_nocase(name, "not")           { token.type = .keyword_not;      return; }
                    if equal_nocase(name, "exist")         { token.type = .keyword_exist;    return; }
                    if equal_nocase(name, "defined")       { token.type = .keyword_defined;  return; }
                    if equal_nocase(name, "errorlevel")    { token.type = .builtin_variable; return; }
                    if equal_nocase(name, "cmdextversion") { token.type = .builtin_variable; return; }

                    if equal_nocase(name, "equ") || equal_nocase(name, "neq") || equal_nocase(name, "lss") ||
                       equal_nocase(name, "leq") || equal_nocase(name, "gtr") || equal_nocase(name, "geq") {
                        parsed_if_conditional_operator = true;
                        token.type = .if_op;
                        return;
                    }

                    token.type = .default;
                    token_is_if_conditional_operand = true;
                    return;
                }

                if at_string(tokenizer, "==") {
                    t += 2;
                    token.type = .op;
                    return;
                }
            }

            case .command_for; {
                if parsing_for_set {
                    if parse_string(tokenizer, token)             return;
                    if parse_string(tokenizer, token, #char "'")  return;
                    if parse_string(tokenizer, token, #char "`")  return;
                    if parse_variable(tokenizer, token)           return;

                    if at_char(tokenizer, #char ",") {
                        t += 1;
                        token.type = .op;
                        return;
                    }

                    if eat_until_any(tokenizer, " )\t'`,") {
                        token.type = .default;
                        return;
                    }
                }

                if parse_string(tokenizer, token) || parse_variable(tokenizer, token)  return;

                name := eat_simple_name(tokenizer);
                if name {
                    if equal_nocase(name, "in") { token.type = .keyword_in; return; }
                    token.type = .default;
                    return;
                }
            }

            case .command_echo; {
                if parse_variable(tokenizer, token)  return;
            }

            case; {
                if parse_string(tokenizer, token)  return;
                if parse_label_reference(tokenizer, token)  return;
                if parse_variable(tokenizer, token)  return;
            }
        }
    }

    // Try to parse other special values.
    {
        name := eat_simple_name(tokenizer, parenthesis_depth == 0);
        if name {
            if equal_nocase(name, "nul") { token.type = .nul; return; }
            if equal_nocase(name, "errorlevel") { token.type = .builtin_variable; return; }
            if equal_nocase(name, "cmdextversion") { token.type = .builtin_variable; return; }

            token.type = .default;
            return;
        }
    }

    if last_token.type == .flag && at_any(tokenizer, ":=") {
        t += 1;
        token.type = .flag_separator;
        return;
    }

    token.type = .default;
    t += 1;
}

parse_flag :: (using tokenizer: *Batch_Tokenizer, token: *Batch_Token) -> bool {
    if active_command == .command_echo  return false;

    prev := prev_char(tokenizer);
    if at_any(tokenizer, "-/") && is_whitespace_char(prev) {
        token.type = .flag;
        eat_until_any(tokenizer, "=:^ \r\n\t");
        return true;
    }

    return false;
}

parse_command :: (using tokenizer: *Batch_Tokenizer, token: *Batch_Token) -> string {
    command := eat_command_name(tokenizer, parenthesis_depth == 0);

    if command {
        if command.count > 4 {
            tmp := command;
            tmp.count = 5;

            // Fix some special cases.
            if equal_nocase(tmp, "goto:") {
                t -= command.count - 4;
                command.count = 4;
            }

            tmp.count = 4;
            if equal_nocase(tmp, "echo") {
                if command[4] == #char ":" || command[4] == #char ";" || command[4] == #char "(" || command[4] == #char "/" ||
                   command[4] == #char "+" || command[4] == #char "=" || command[4] == #char "." {
                    t -= command.count - 4;
                    command.count = 4;
                }
            }
        }

        if command.count > 0 {
            if contains_any_character(command, ".\\/") { // Looks like a file path.
                token.type = .default;
            } else {
                token.type = .command;
            }
        }
    }

    return command;
}

parse_variable :: (using tokenizer: *Batch_Tokenizer, token: *Batch_Token) -> bool {
    if at_char(tokenizer, #char "%") {
        t += 1;

        if parsing_variable {
            parsing_variable = false;
            token.type = .variable;
            return true;
        }

        if at_char(tokenizer, #char "*") {
            token.type = .variable;
            t += 1;
            return true;
        }

        expect_end_delimiter := true;
        if at_char(tokenizer, #char "%") { t += 1; expect_end_delimiter = false; }
        if at_char(tokenizer, #char "~") { t += 1; expect_end_delimiter = false; }
        if at_any(tokenizer, "0123456789")  expect_end_delimiter = false;

        if !expect_end_delimiter {
            if eat_simple_name(tokenizer, parenthesis_depth == 0) {
                token.type = .variable;
                return true;
            }

            t = start_t;
            return false;
        } else {
            if eat_simple_name(tokenizer, parenthesis_depth == 0) {
                parsing_variable = true;
                token.type = .variable;

                if at_char(tokenizer, #char "%") {
                    t += 1;
                    parsing_variable = false;
                }

                return true;
            }

            t = start_t;
        }
    } else if parsing_variable {
        if eat_simple_name(tokenizer, parenthesis_depth == 0) {
            token.type = .variable;
            return true;
        }
    }

    if at_char(tokenizer, #char "!") {
        t += 1;

        if parsing_delayed_expansion {
            parsing_delayed_expansion = false;
            token.type = .variable;
            return true;
        }

        if eat_simple_name(tokenizer, parenthesis_depth == 0) {
            parsing_delayed_expansion = true;
            token.type = .variable;
            return true;
        }

        t = start_t;
    }

    if parsing_delayed_expansion {
        if eat_simple_name(tokenizer, parenthesis_depth == 0) {
            token.type = .variable;
            return true;
        }
    }

    if eat_simple_name(tokenizer, parenthesis_depth == 0) {
        if at_char(tokenizer, #char "[") {
            token.type = .variable;
            return true;
        }

        t = start_t;
    }

    return false;
}

parse_redirection_operator :: (using tokenizer: *Batch_Tokenizer, token: *Batch_Token) -> bool {
    if !at_any(tokenizer, "><|&")  return false;

    // Operator is escaped.
    if last_token.type == .caret_op && last_token.start == token.start - 1 {
        token.type = .default;
        t += 1;
        return true;
    }

    if at_any(tokenizer, "><") {
        t += 1;
        token.type = .file_redirection_op;
        if      at_char(tokenizer, #char "&")  t += 1;
        else if at_char(tokenizer, (t - 1).*)  t += 1;
        return true;
    }

    if at_any(tokenizer, "|&") {
        t += 1;
        token.type = .redirection_op;
        if at_char(tokenizer, (t - 1).*)  t += 1;
        return true;
    }

    return false;
}

parse_label_declaration :: (using tokenizer: *Batch_Tokenizer, token: *Batch_Token) -> bool {
    if last_token.type != .eof && !newline_since_last_token  return false;

    if at_char(tokenizer, #char ":") {
        t += 1;
        name := eat_until_any(tokenizer, " :\r\n\t()");
        if name {
            if at_char(tokenizer, #char ":")  t += 1;
            token.type = .label_declaration;
            return true;
        }
    }

    t = start_t;
    return false;
}

parse_label_reference :: (using tokenizer: *Batch_Tokenizer, token: *Batch_Token) -> bool {
    if active_command_argument_count > 0  return false;

    if active_command == .command_goto || (active_command == .command_call && at_char(tokenizer, #char ":")) {
        token.type = .label_reference;
        if at_char(tokenizer, #char ":")  t += 1;
        eat_until_any(tokenizer, " :\r\n\t()");
        return t > start_t;
    }

    t = start_t;
    return false;
}

parse_string :: (using tokenizer: *Batch_Tokenizer, token: *Batch_Token, delimiting_char: u8 = #char "\"") -> bool {
    if at_char(tokenizer, delimiting_char) {
        t += 1;

        while t < max_t {
            if at_char(tokenizer, delimiting_char) {
                t += 1;
                break;
            }

            if at_char(tokenizer, #char "\n") break;
            t += 1;
        }
    }

    if t > start_t {
        token.type = .string_value;
        return true;
    }

    return false;
}

parse_parenthesis :: (using tokenizer: *Batch_Tokenizer, token: *Batch_Token) -> bool {
    if at_char(tokenizer, #char "(") {
        token.type = .parenthesis_open;
        t += 1;
        return true;
    }

    if at_char(tokenizer, #char ")") {
        token.type = .parenthesis_close;
        t += 1;
        return true;
    }

    return false;
}

parse_bracket :: (using tokenizer: *Batch_Tokenizer, token: *Batch_Token) -> bool {
    if at_char(tokenizer, #char "[") {
        parsing_pseudo_array_access = VALID_NAME_TABLE[prev_char(tokenizer)];
        is_operator := parsing_pseudo_array_access || active_command == .command_if;
        token.type = ifx is_operator then .bracket_open else .default;
        t += 1;
        return true;
    }

    if at_char(tokenizer, #char "]") {
        is_operator := parsing_pseudo_array_access || active_command == .command_if;
        token.type = ifx is_operator then .bracket_close else .default;
        parsing_pseudo_array_access = false;
        t += 1;
        return true;
    }

    return false;
}

parse_caret :: (using tokenizer: *Batch_Tokenizer, token: *Batch_Token) -> bool {
    if !at_char(tokenizer, #char "^")  return false;
    token.type = .caret_op;
    t += 1;
    if active_command == .command_echo && last_token.type == .caret_op  token.type = .default;
    return true;
}

parse_path :: (using tokenizer: *Batch_Tokenizer, token: *Batch_Token) -> bool {
    while t < max_t {
        if !VALID_COMMAND_CHARACTER_TABLE[t.*]  break;
        t += 1;
    }

    if t > start_t {
        token.type = .command_path;
        return true;
    }

    return false;
}

parse_rest_of_line_as_comment :: (using tokenizer: *Batch_Tokenizer, token: *Batch_Token) {
    eat_until_any(tokenizer, "\r\n");
    token.type = .comment;
}

at_string :: (using tokenizer: *Batch_Tokenizer, a: string, $case_sensitive := true) -> bool {
    if t + a.count > max_t  return false;
    b: string = ---;
    b.data = t;
    b.count = a.count;
    #if case_sensitive  return equal(a, b);
    else                return equal_nocase(a, b);
}

at_char :: inline (using tokenizer: *Batch_Tokenizer, c: u8) -> bool {
    return t < max_t && t.* == c;
}

at_any :: inline (using tokenizer: *Batch_Tokenizer, s: string) -> bool {
    for c: 0..s.count-1 {
        if at_char(tokenizer, s[c])  return true;
    }

    return false;
}

prev_char :: inline (using tokenizer: *Batch_Tokenizer) -> u8 {
    if t == buf.data  return 0;
    return (t - 1).*;
}

next_char :: inline (using tokenizer: *Batch_Tokenizer) -> u8 {
    if t + 1 >= max_t  return 0;
    return (t + 1).*;
}

eat_until :: inline (using tokenizer: *Batch_Tokenizer, c: u8) {
    while t < max_t && t.* != c {
        t += 1;
    }
}

eat_until_any :: inline (using tokenizer: *Batch_Tokenizer, s: string) -> bool {
    t_initial := t;
    while outer := t < max_t {
        for c: 0..s.count-1 {
            if t.* == s[c] {
                break outer;
            }
        }
        t += 1;
    }
    return t > t_initial;
}

eat_white_space :: inline (using tokenizer: *Batch_Tokenizer) -> bool, bool {
    t_initial := t;
    ate_newline := false;
    while t < max_t && WHITE_SPACE_TABLE[t.*] {
        ate_newline |= t.* == #char "\n";
        t += 1;
    }
    return t > t_initial, ate_newline;
}

eat_simple_name :: (using tokenizer: *Batch_Tokenizer, allow_parentheses := true) -> string {
    result: string = ---;
    result.data = t;

    while t < max_t {
        if !VALID_NAME_TABLE[t.*] && (!allow_parentheses || (t.* != #char "(" && t.* != #char ")"))  break;
        if parsing_arithmetic_set && at_any(tokenizer, "-*+/")  break;
        t += 1;
    }

    result.count = t - result.data;
    return result;
}

eat_command_name :: (using tokenizer: *Batch_Tokenizer, allow_parentheses := true) -> string {
    result: string = ---;
    result.data = t;

    if VALID_COMMAND_STARTING_CHARACTER_TABLE[t.*] {
        t += 1;

        while t < max_t {
            if !VALID_COMMAND_CHARACTER_TABLE[t.*] && (!allow_parentheses || (t.* != #char "(" && t.* != #char ")"))  break;
            t += 1;
        }
    }

    result.count = t - result.data;
    return result;
}

set_active_command :: inline (using tokenizer: *Batch_Tokenizer, command: Batch_Command) {
    active_command = command;
    active_command_argument_count = 0;
}

unset_active_command :: inline (using tokenizer: *Batch_Tokenizer) {
    command_parsing_state = .{};
}

Batch_Tokenizer :: struct {
    using #as base: Tokenizer;

    last_token: Batch_Token;
    newline_since_last_token: bool;
    parenthesis_depth: int;

    using command_parsing_state: struct {
        active_command: Batch_Command;
        active_command_argument_count: int;
        parsing_set_value: bool;
        parsing_arithmetic_set: bool;
        parsing_for_set: bool;
        parsing_delayed_expansion: bool;
        parsed_if_conditional_operator: bool;
        parsing_variable: bool;
        parsing_pseudo_array_access: bool;
    }
}

Batch_Command :: enum {
    invalid :: 0;
    other :: 1;

    command_cd;
    command_if;
    command_md;
    command_rd;
    command_cls;
    command_del;
    command_dir;
    command_for;
    command_rem;
    command_ren;
    command_set;
    command_ver;
    command_vol;
    command_call;
    command_copy;
    command_date;
    command_echo;
    command_exit;
    command_goto;
    command_keys;
    command_move;
    command_path;
    command_popd;
    command_time;
    command_type;
    command_assoc;
    command_break;
    command_chdir;
    command_color;
    command_dpath;
    command_erase;
    command_ftype;
    command_mkdir;
    command_pause;
    command_pushd;
    command_rmdir;
    command_shift;
    command_start;
    command_title;
    command_mklink;
    command_prompt;
    command_rename;
    command_verify;
    command_endlocal;
    command_setlocal;
}

starts_command :: (c: u8) -> bool {
    return VALID_COMMAND_STARTING_CHARACTER_TABLE[c];
}

Batch_Token :: struct {
    start, len: s32;
    type: Type;

    Type :: enum u16 {
        eof;

        error;
        default;

        command;
        command_path;
        string_value;
        variable;
        builtin_variable;
        label_declaration;
        label_reference;
        op;
        at_op;
        caret_op;
        redirection_op;
        file_redirection_op;
        if_op;
        keyword_not;
        keyword_exist;
        keyword_defined;
        keyword_in;
        keyword_else;
        keyword_do;
        nul;
        flag;
        flag_separator;
        comment;
        command_rem;
        parenthesis_open;
        parenthesis_close;
        bracket_open;
        bracket_close;
    }
}

// Must match the order of the types in the enum above.
// We're translating very specific token types into the generic token types
// to avoid adding too many tokens to the default token list, where we
// don't really need this granularity
TOKEN_MAP :: Token_Type.[
    .eof,               // eof - obviously not used

    .error,             // error
    .default,           // default

    .keyword,           // command
    .default,           // command_path
    .string_literal,    // string_value
    .value,             // variable
    .value,             // builtin_variable
    .highlight,         // label_declaration
    .highlight,         // label_reference
    .operation,         // op
    .operation,         // at_op
    .operation,         // caret_op
    .operation,         // redirection_op
    .operation,         // file_redirection_op
    .keyword,           // if_op
    .keyword,           // keyword_not
    .keyword,           // keyword_exist
    .keyword,           // keyword_defined
    .keyword,           // keyword_in
    .keyword,           // keyword_else
    .keyword,           // keyword_do
    .keyword,           // nul
    .type,              // flag
    .operation,         // flag_separator
    .comment,           // comment
    .comment,           // command_rem
    .punctuation,       // parenthesis_open
    .punctuation,       // parenthesis_close
    .punctuation,       // bracket_open
    .punctuation,       // bracket_close
];

WHITE_SPACE_TABLE :: #run generate_lookup_table(Character_Range.[
    make_range(#char " "),
    make_range(#char "\t"),
    make_range(#char "\n"),
    make_range(#char "\r"),
    make_range(0x0c), // form feed
], strict = true);

VALID_NAME_TABLE :: #run generate_lookup_table(Character_Range.[
    make_range(#char "A", #char "Z"),
    make_range(#char "_"),
    make_range(#char "a", #char "z"),
    make_range(#char "-"),
    make_range(#char "."),
    make_range(#char "0", #char "9"),
    make_range(#char "?"),
    make_range(#char "$"),
]);

VALID_COMMAND_STARTING_CHARACTER_TABLE :: #run generate_lookup_table(Character_Range.[
    make_range(#char "A", #char "Z"),
    make_range(#char "_"),
    make_range(#char "a", #char "z"),
], strict = true);

VALID_COMMAND_CHARACTER_TABLE :: #run generate_lookup_table(Character_Range.[
    make_range(#char "A", #char "Z"),
    make_range(#char "_"),
    make_range(#char "a", #char "z"),
    make_range(#char "-"),
    make_range(#char "0", #char "9"),
    make_range(#char "?"),
    make_range(#char "\\"),
    make_range(#char "/"),
    make_range(#char ":"),
    make_range(#char "."),
    make_range(#char "~"),
], strict = true);

Character_Range :: struct { start: u8; end: u8; }

make_range :: (start: u8, end: u8) -> Character_Range { return .{start, end}; }
make_range :: (start: u8)          -> Character_Range { return .{start, start}; }

generate_lookup_table :: (ranges: [] Character_Range, strict := false) -> [256] bool {
    lut: [256] bool;
    for range: ranges {
        for c: range.start..range.end  lut[c] = true;
    }

    if !strict {
        // Accept values that are outside the ASCII range.
        for c: 0x80..0xff  lut[c] = true;
    }

    return lut;
}

check_for_internal_command_name :: (name: string) -> Batch_Command {
    if name.count == {
        case 2; {
            if equal_nocase(name, "cd")  return .command_cd;
            if equal_nocase(name, "if")  return .command_if;
            if equal_nocase(name, "md")  return .command_md;
            if equal_nocase(name, "rd")  return .command_rd;
        }

        case 3; {
            if equal_nocase(name, "cls")  return .command_cls;
            if equal_nocase(name, "del")  return .command_del;
            if equal_nocase(name, "dir")  return .command_dir;
            if equal_nocase(name, "for")  return .command_for;
            if equal_nocase(name, "rem")  return .command_rem;
            if equal_nocase(name, "ren")  return .command_ren;
            if equal_nocase(name, "set")  return .command_set;
            if equal_nocase(name, "ver")  return .command_ver;
            if equal_nocase(name, "vol")  return .command_vol;
        }

        case 4; {
            if equal_nocase(name, "call")  return .command_call;
            if equal_nocase(name, "copy")  return .command_copy;
            if equal_nocase(name, "date")  return .command_date;
            if equal_nocase(name, "echo")  return .command_echo;
            if equal_nocase(name, "exit")  return .command_exit;
            if equal_nocase(name, "goto")  return .command_goto;
            if equal_nocase(name, "keys")  return .command_keys;
            if equal_nocase(name, "move")  return .command_move;
            if equal_nocase(name, "path")  return .command_path;
            if equal_nocase(name, "popd")  return .command_popd;
            if equal_nocase(name, "time")  return .command_time;
            if equal_nocase(name, "type")  return .command_type;
        }

        case 5; {
            if equal_nocase(name, "assoc")  return .command_assoc;
            if equal_nocase(name, "break")  return .command_break;
            if equal_nocase(name, "chdir")  return .command_chdir;
            if equal_nocase(name, "color")  return .command_color;
            if equal_nocase(name, "dpath")  return .command_dpath;
            if equal_nocase(name, "erase")  return .command_erase;
            if equal_nocase(name, "ftype")  return .command_ftype;
            if equal_nocase(name, "mkdir")  return .command_mkdir;
            if equal_nocase(name, "pause")  return .command_pause;
            if equal_nocase(name, "pushd")  return .command_pushd;
            if equal_nocase(name, "rmdir")  return .command_rmdir;
            if equal_nocase(name, "shift")  return .command_shift;
            if equal_nocase(name, "start")  return .command_start;
            if equal_nocase(name, "title")  return .command_title;
        }

        case 6; {
            if equal_nocase(name, "mklink")  return .command_mklink;
            if equal_nocase(name, "prompt")  return .command_prompt;
            if equal_nocase(name, "rename")  return .command_rename;
            if equal_nocase(name, "verify")  return .command_verify;
        }

        case 8; {
            if equal_nocase(name, "endlocal")  return .command_endlocal;
            if equal_nocase(name, "setlocal")  return .command_setlocal;
        }
    }

    return .invalid;
}
