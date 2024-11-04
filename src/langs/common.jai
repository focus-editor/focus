get_tokenizer :: (using buffer: Buffer, start_offset := -1, count := -1) -> Tokenizer {
    tokenizer: Tokenizer;

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

read_identifier_string :: (using tokenizer: *Tokenizer) -> string {
    identifier: string;
    identifier.data = t;

    while t < max_t && is_alnum(t.*) {
        t += 1;
    }
    if t >= max_t then t = max_t;
    identifier.count = t - identifier.data;

    return identifier;
}

read_utf8_identifier_string :: (using tokenizer: *Tokenizer) -> string {
    identifier: string;
    identifier.data = t;

    while t < max_t {
        c := t.*;
        if c == #char "_" || is_alpha(c) || (t > identifier.data && is_digit(c)) { t += 1; continue; }

        // Only check for unicode chars after the most common case is out of the way.
        // We don't do comprehensive checks because Unicode docs are cryptic and we might not need every possible character anyway
        utf32, length := character_utf8_to_utf32(t, max_t - t);

        if is_utf32_letter(utf32) {
            t += length;
            continue;
        }

        break;  // unknown char. NOTE: this could result in an empty string, that should be ok but parsers need to account for that
    }
    if t >= max_t then t = max_t;

    identifier.count = t - identifier.data;

    return identifier;
}

is_utf32_letter :: inline (utf32: u32) -> bool {
    return utf32 >= 0xC0  && utf32 <= 0xF6  ||  // Latin-1 Supplement for Western European languages (À-ö)
           utf32 >= 0xF8  && utf32 <= 0xFF  ||  // continuing Latin-1 Supplement (ø-ÿ), excluding the division sign (÷) and multiplication sign (×)
           utf32 >= 0x410 && utf32 <= 0x42F ||  // capital cyrillic
           utf32 >= 0x430 && utf32 <= 0x44F ||  // lowercase cyrillic
           utf32 >= 0x100 && utf32 <= 0x17F;    // Latin Extended-A for Central European languages (Ā-ſ)
}

eat_until_newline :: (using tokenizer: *Tokenizer) {
    while t < max_t && t.* != #char "\n" {
        t += 1;
    }
}

eat_white_space :: (using tokenizer: *Tokenizer) {
    t_old := t;
    while t < max_t && is_white_space(t.*) {
        t += 1;
    }
    had_white_space_to_skip = t != t_old;
}

peek_next_token :: (using tokenizer: Tokenizer, skip_white_space := true, $Token: Type, $get_next_token: (*Tokenizer) -> Token) -> Token {
    tokenizer_copy := tokenizer;
    if skip_white_space then eat_white_space(*tokenizer_copy);
    token := get_next_token(*tokenizer_copy);
    return token;
}

is_hex :: inline (c: u8) -> bool {
    return is_digit(c) || (c >= #char "a" && c <= #char "f") || (c >= #char "A" && c <= #char "F");
}

is_white_space :: inline (char : u8) -> bool #no_aoc {
    result : u32 = ---;

    // Should be in register, not immediate
    white_spaces : u64 = (#char " "  <<  0)  // space.
                       | (#char "\t" <<  8)  // horizontal tab.
                       | (#char "\n" << 16)  // line feed.
                       | (#char "\r" << 24)  // carriage return.
                       | (0x0C       << 32)  // form feed.    "\f" is not supported in jai at the time of writing
                       | (0x0B       << 40); // vertical tab. "\v" is not supported in jai at the time of writing

    #asm {
        chars  : vec === 0;
        mask   : vec === 1;
        spaces : vec === 2;
        result       === a;
        white_spaces === b;
        char         === c;

        movq spaces, white_spaces;

        pxor mask, mask;

        // Fill chars with c
        pinsrb chars, char, 0;
        pshufb chars, mask;

        pcmpeqb chars, spaces;

        pmovmskb result, chars;
    }

    return cast,no_check(bool) result;
}

tokenize_c_like_lang_for_indentation :: (buffer: Buffer, $get_next_token: (*Tokenizer) -> $Token) -> [] Indentation_Token /* temp */ {
    tokens: [..] Indentation_Token;
    tokens.allocator = temp;

    tokenizer := get_tokenizer(buffer);

    // Allocate temporary space for tracking one previous token
    tokenizer.prev_tokens[0] = New(Token,, temp);

    while true {
        src := get_next_token(*tokenizer);

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

            case .multiline_comment;    token.type = .maybe_multiline;
            case .eof;                  token.type = .eof;  // to guarantee we always have indentation tokens
            case;                       token.type = .unimportant;
        }

        array_add(*tokens, token);

        if src.type == .eof break;
    }

    return tokens;
}

parse_number_c_like :: (using tokenizer: *Tokenizer, token: *$Token) {
    token.type = .number;

    start_char := t.*;

    t += 1;
    if t >= max_t return;

    if is_digit(t.*) || t.* == #char "." {
        // Decimal
        seen_decimal_point := false;
        while t < max_t && (is_digit(t.*) || t.* == #char ".") {
            if t.* == #char "." {
                if seen_decimal_point break;
                seen_decimal_point = true;
            }
            t += 1;
        }
        if t >= max_t return;

        // Exponent
        if t.* == #char "e" || t.* == #char "E" {
            t += 1;
            if t >= max_t return;

            if t.* == #char "+" || t.* == #char "-" {
              t += 1;
              if t >= max_t return;
            }

            while t < max_t && is_digit(t.*) {
                t += 1;
            }
            if t >= max_t return;
        }

        // Suffixes
        if seen_decimal_point {
            if t.* == #char "f" || t.* == #char "F" || t.* == #char "d" || t.* == #char "D" {
                t += 1;
            }
        } else {
            if t.* == #char "l" || t.* == #char "L" {             // l
                t += 1;
                if t >= max_t return;

                if t.* == #char "l" || t.* == #char "L" {         // ll
                    t += 1;
                    if t >= max_t return;

                    if t.* == #char "u" || t.* == #char "U" {     // llu
                    t += 1;
                }
            } else if t.* == #char "u" || t.* == #char "U" {      // lu
                t += 1;
            }
            } else if  t.* == #char "u" || t.* == #char "U" {     // u
                t += 1;
            }
        }
    } else if start_char == #char "0" {
        if t.* == #char "x" || t.* == #char "X" {
            // Hex
            t += 1;
            while t < max_t && (is_hex(t.*)) t += 1;

        } else if t.* == #char "b" || t.* == #char "B" {
            // Binary
            t += 1;
            while t < max_t && (t.* == #char "1" || t.* == #char "0") t += 1;
        }
    }
}

get_lang_from_name :: (lang_name: string) -> Buffer.Lang, found: bool {
    lowercase_name := to_lower_copy_new(lang_name,, temp);
    if lowercase_name == {
        case "jai";          return .Jai,        true;
        case "c";            return .C,          true;
        case "cpp";          return .Cpp,        true;
        case "csharp";       return .CSharp,     true;
        case "css";          return .Css,        true;
        case "d";            return .D,          true;
        case "glsl";         return .Glsl,       true;
        case "hlsl";         return .Hlsl,       true;
        case "go";           return .Golang,     true;
        case "golang";       return .Golang,     true;
        case "js";           return .Js,         true;
        case "jsx";          return .Js,         true;
        case "json";         return .Json,       true;
        case "ts";           return .Js,         true;
        case "tsx";          return .Js,         true;
        case "lua";          return .Lua,        true;
        case "odin";         return .Odin,       true;
        case "python";       return .Python,     true;
        case "renpy";        return .RenPy,      true;
        case "rust";         return .Rust,       true;
        case "html";         return .Html,       true;
        case "xml";          return .Xml,        true;
        case "todo";         return .Todo,       true;
        case "yang";         return .Yang,       true;
        case "zig";          return .Zig,        true;
        case "uxntal";       return .Uxntal,     true;
        case "plain_text";   return .Plain_Text, true;
        case "md";           return .Markdown,   true;
        case "markdown";     return .Markdown,   true;
        case "batch";        return .Batch,      true;

        // case "focus_config"; return .Focus_Config, true;  // disabled for now
        // case "focus_theme";  return .Focus_Theme,  true;
    }

    return .Plain_Text, false;
}

Tokenizer :: struct {
    buf: string;
    max_t:   *u8;
    start_t: *u8;  // cursor when we're about to parse a new token
    t:       *u8;  // cursor

    prev_tokens: [3] *void;
    had_white_space_to_skip := false;  // to indicate whether any white space was on the left of the current token
}

Code_Highlight :: struct {
    offset: s32;
    count: s32;
    token_type: Token_Type;
}

// This enum is supposed to list all possible code tokens we might have, for all languages
Token_Type :: enum u8 {
    default :: 0;   // must be first
    eof;
    invalid;

    string_literal;
    multiline_string;
    raw_string;
    char_literal;

    identifier;
    note;
    number;

    error;
    warning;
    highlight;

    comment;
    multiline_comment;

    operation;
    punctuation;

    keyword;
    type;
    value;
    modifier;
    attribute;
    enum_variant;
    macro;
    function;

    builtin_variable;
    builtin_function;
    builtin_exception;

    directive;
    directive_modifier;

    header;
    header2;
    header3;
    header4;
    header5;
    header6;
}
