convert_utf32_to_utf8 :: (ch: u32) -> Utf8_Char {
    UNI_MAX_LEGAL_UTF32 :: 0x0010FFFF;
    UNI_REPLACEMENT_CHAR :: 0x0000FFFD;

    count := 0;
    if ch < 0x80                        count = 1;
    else if ch < 0x800                  count = 2;
    else if ch < 0x10000                count = 3;
    else if ch <= UNI_MAX_LEGAL_UTF32   count = 4;
    else {
        count = 3;
        ch = UNI_REPLACEMENT_CHAR;
    }

    byteMask :: 0xBF;
    byteMark :: 0x80;

    bytes: [4] u8 = ---;

    if count == {
        case 4; bytes[3] = xx (ch | byteMark) & byteMask; ch = ch >> 6; #through;
        case 3; bytes[2] = xx (ch | byteMark) & byteMask; ch = ch >> 6; #through;
        case 2; bytes[1] = xx (ch | byteMark) & byteMask; ch = ch >> 6; #through;
        case 1; bytes[0] = xx (ch | firstByteMark[count]);
    }

    result: Utf8_Char = ---;
    result.bytes = bytes;
    result.count = xx count;
    return result;
}

to_string :: (utf8_char: *Utf8_Char) -> string {
    str: string = ---;
    str.data  = *utf8_char.bytes[0];
    str.count = utf8_char.count;
    return str;
}

Utf8_Char :: struct {
    bytes: [4] u8;
    count: s32;
}

advance_by_chars :: (s: string, num_chars: s64, tab_size: s32) -> string #must, remainder: s64 {
    result := s;
    col := 0;
    while result && col < num_chars {
        byte := result[0];
        if byte != #char "\t" {
            safe_advance(*result, 1 + trailingBytesForUTF8[byte]);
            col += 1;
        } else {
            safe_advance(*result, 1);
            col += tab_size - col % tab_size;
        }
    }
    return result, col - num_chars;
}

take_first_n_chars :: (s: string, num_chars: s64, tab_size: s32) -> string #must {
    result := s;
    result.count -= advance_by_chars(result, num_chars, tab_size).count;
    return result;
}

// Counts the number of chars, each tab is counted as the number of cols needed for the visual indent
num_cols_in_string :: (s: string, tab_size: s32) -> s32 {
    num_chars: s32 = 0;

    while s {
        byte := s[0];
        if byte != #char "\t" {
            safe_advance(*s, 1 + trailingBytesForUTF8[byte]);
            num_chars += 1;
        } else {
            safe_advance(*s, 1);
            num_chars += tab_size - num_chars % tab_size;
        }
    }

    return num_chars;
}

num_chars_in_string :: (s: string) -> s32 {
    num_chars: s32 = 0;

    while s {
        byte := s[0];
        safe_advance(*s, 1 + trailingBytesForUTF8[byte]);
        num_chars += 1;
    }

    return num_chars;
}

safe_advance :: inline (s: *string, amount: s64 = 1) {
    // Doesn't crash if amount is incorrect for any reason
    if amount < 0 return;
    if amount > s.count then amount = s.count;

    s.count -= amount;
    s.data  += amount;
}

next_char_offset :: inline (bytes: Array(u8), offset: s32) -> s32 {
    assert(offset <= bytes.count-1);
    return clamp(offset + 1 + trailingBytesForUTF8[bytes[offset]], 0, bytes.count);
}

prev_char_offset :: (bytes: Array(u8), offset: s32) -> s32, byte: u8 {
    new_offset := offset - 1;
    byte := bytes[new_offset];
    while (byte & 0b1100_0000) == 0b1000_0000 {
        new_offset -= 1;
        byte = bytes[new_offset];
    }
    return new_offset, byte;
}

unicode_character_and_next_position :: (ptr: *u8) -> char: u32, next_ptr: *u8 {
    next_ptr := unicode_next_character(ptr);
    char, _, error := character_utf8_to_utf32(ptr, next_ptr - ptr);
    if error  return 0, next_ptr;
    else      return char, next_ptr;
}

unicode_prev_character_and_position :: (s: *u8) -> char: u32, new_s: *u8 {  // NOTE: assuming the memory is valid utf-8, no checks are done!
    t := s - 1;
    while (<<t & 0b1100_0000) == 0b1000_0000 t -= 1;  // rewind to the first byte of a utf-8 sequence (all non-first bytes start with 10)

    char, _, result := character_utf8_to_utf32(t, s - t);
    return char, t;
}

/*
 * is_unicode_linebreak():
 *     returns `true` if the specified UTF32 codepoint is a whitespace line-break character.
 *     NOTE: '\r' (U+000D) is omitted since we lack support for the proper Unicode line-break
 *           algorithm (https://unicode.org/reports/tr14/#CR)
 *
 * is_unicode_space():
 *     returns `true` if the specified UTF32 codepoint is a whitespace character, not including
 *     line-breaking whitespace.
 *
 * References:
 *   - https://en.wikipedia.org/wiki/Whitespace_character#Unicode
 *   - https://www.unicode.org/reports/tr44/#White_Space
 *   - https://www.unicode.org/Public/UCD/latest/ucd/PropList.txt
 */
is_unicode_linebreak :: inline (ch: u32) -> bool {
    return
        ch == 0x000a || ch == 0x000b || ch == 0x000c ||
        ch == 0x0085 ||
        ch == 0x2028 ||
        ch == 0x2029;
}

is_unicode_space :: inline (ch: u32) -> bool {
    return
        ch == 0x0009 ||
        ch == 0x0020 ||
        ch == 0x00a0 ||
        ch == 0x1680 ||
        ch == 0x2000 || ch == 0x2001 || ch == 0x2002 || ch == 0x2003 || ch == 0x2004 ||
        ch == 0x2005 || ch == 0x2006 || ch == 0x2007 || ch == 0x2008 || ch == 0x2009 ||
        ch == 0x200a ||
        ch == 0x202f ||
        ch == 0x205f ||
        ch == 0x3000;
}
