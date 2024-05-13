get_tokenizer :: (using buffer: Buffer, start_offset := -1, count := -1) -> Tokenizer {
    tokenizer: Tokenizer;

    tokenizer.buf   = cast(string) bytes;
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

get_lang_from_name :: (lang_name: string) -> Buffer.Lang {
    if ends_with_nocase(lang_name, "jai")          return .Jai;
    if ends_with_nocase(lang_name, "c")            return .C;
    if ends_with_nocase(lang_name, "csharp")       return .CSharp;
    // if ends_with_nocase(lang_name, "focus_config") return .Focus_Config;  // disabled for now
    // if ends_with_nocase(lang_name, "focus_theme")  return .Focus_Theme;
    if ends_with_nocase(lang_name, "glsl")         return .Glsl;
    if ends_with_nocase(lang_name, "hlsl")         return .Hlsl;
    if ends_with_nocase(lang_name, "golang")       return .Golang;
    if ends_with_nocase(lang_name, "js")           return .Js;
    if ends_with_nocase(lang_name, "jsx")          return .Js;
    if ends_with_nocase(lang_name, "json")         return .Json;
    if ends_with_nocase(lang_name, "ts")           return .Js;
    if ends_with_nocase(lang_name, "tsx")          return .Js;
    if ends_with_nocase(lang_name, "lua")          return .Lua;
    if ends_with_nocase(lang_name, "odin")         return .Odin;
    if ends_with_nocase(lang_name, "python")       return .Python;
    if ends_with_nocase(lang_name, "renpy")        return .RenPy;
    if ends_with_nocase(lang_name, "rust")         return .Rust;
    if ends_with_nocase(lang_name, "html")         return .Html;
    if ends_with_nocase(lang_name, "xml")          return .Xml;
    if ends_with_nocase(lang_name, "worklog")      return .Worklog;
    if ends_with_nocase(lang_name, "yang")         return .Yang;
    if ends_with_nocase(lang_name, "zig")          return .Zig;
    if ends_with_nocase(lang_name, "uxntal")       return .Uxntal;

    return .Plain_Text;
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
