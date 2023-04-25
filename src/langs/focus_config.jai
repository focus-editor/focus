highlight_focus_config_syntax :: (using buffer: *Buffer) {
    tokenizer: Tokenizer = ---;
    tokenizer.buf   = to_string(bytes);
    tokenizer.max_t = bytes.data + bytes.count;
    tokenizer.t     = bytes.data;

    while true {
        token := get_next_token(*tokenizer);
        if token.type == .eof break;

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

    if char == {
        case #char "["; try_parsing_header(tokenizer, *token);
        case #char "#"; parse_comment(tokenizer, *token);
        case;
            if section == {
                case .keymap;       parse_keymap_line(tokenizer, *token);
                case .workspace;    parse_line(tokenizer, *token);
                case .settings;     parse_line(tokenizer, *token);
                // case .ui;           parse_ui_line(tokenizer, *token);
                // case .colors;       parse_color_line(tokenizer, *token);
                case;
                    parse_line(tokenizer, *token);
            }
    }

    if t >= max_t then t = max_t;
    token.len = cast(s32) (t - start_t);

    return token;
}

try_parsing_header :: (using tokenizer: *Tokenizer, token: *Token) {
    old_t := t;

    eat_until_newline_or_comment(tokenizer);

    str: string = ---;
    str.data  = old_t;
    str.count = t - old_t;

    str = trim_right(str);

    if str == {
        case "[[workspace]]";   section = .workspace; token.type = .header_top_level;
        case "[[settings]]";    section = .settings;  token.type = .header_top_level;
        case "[[keymap]]";      section = .keymap;    token.type = .header_top_level;
        case "[[style]]";       section = .style;     token.type = .header_top_level;

        case "[workspace dirs]";            token.type = .header;
        case "[ignore dirs]";               token.type = .header;
        case "[allow file extensions]";     token.type = .header;
        case "[ignore file extensions]";    token.type = .header;
        case "[common]";                    token.type = .header;
        case "[editors]";                   token.type = .header;
        case "[open file dialog]";          token.type = .header;
        case "[search dialog]";             token.type = .header;

        // case "[user interface]";            token.type = .header; section = .ui;
        // case "[colors]";                    token.type = .header; section = .colors;

        case; token.type = .default; t = old_t + 1;
    }
}

parse_comment :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .comment;

    t += 1;
    eat_until_newline(tokenizer);
}

parse_line :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .default;

    t += 1;
    eat_until_newline_or_comment(tokenizer);
}

parse_keymap_line :: (using tokenizer: *Tokenizer, token: *Token) {
    token.type = .default;

    if !is_alnum(<<t) {
        t += 1;
        return;
    }

    old_t := t;
    t += 1;
    while t < max_t && is_alnum(<<t) {
        t += 1;
    }

    str: string = ---;
    str.data  = old_t;
    str.count = t - old_t;

    if equal_nocase(str, "Shift") || equal_nocase(str, "Alt") || equal_nocase(str, "Ctrl") {
        token.type = .modifier_key;
    } else {
        _, found_action := table_find(*Keymap_Action_Strings, str);
        if found_action {
            token.type = .action;
        } else if keymap_map_key_string(str) {
            token.type = .key_string;
        } else if str.count > 1 {
            token.type = .error;
        }
    }
}

eat_until_newline :: (using tokenizer: *Tokenizer) {
    while t < max_t && <<t != #char "\n" {
        t += 1;
    }
}

eat_until_newline_or_comment :: (using tokenizer: *Tokenizer) {
    while t < max_t && <<t != #char "#" && <<t != #char "\n" {
        t += 1;
    }
}

eat_white_space :: (using tokenizer: *Tokenizer) {
    while t < max_t && is_space(<< t) {
        t += 1;
    }
}

Tokenizer :: struct {
    buf: string;
    max_t:   *u8;
    start_t: *u8;  // cursor when starting parsing new token
    t:       *u8;  // cursor

    section: enum {
        none;
        workspace;
        keymap;
        settings;
        style;  // unused
        ui;
        colors;
    } = .none;
}

Token :: struct {
    start, len: s32;
    type: Type;

    Type :: enum u16 {
        eof;

        error;
        default;
        comment;
        header;
        header_top_level;

        // Keymap
        modifier_key;
        key_string;
        action;
    }
}

// Must match the order of the types in the enum above
COLOR_MAP :: Code_Color.[
    .COMMENT,       // eof - obviously not used

    .ERROR,         // error
    .DEFAULT,       // default
    .COMMENT,       // comment
    .OPERATION,     // header
    .KEYWORD,       // header_top_level

    .FUNCTION,      // modifier_key
    .DEFAULT,       // key_string
    .DEFAULT,       // action
];

#run assert(enum_highest_value(Token.Type) == COLOR_MAP.count - 1);