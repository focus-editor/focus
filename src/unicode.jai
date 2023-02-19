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

move_offset_by_chars :: (offset: s32, num_chars: s32, bytes: [] u8, max_offset: s32) -> new_offset: s32 {
    max_t := bytes.data + min(max_offset, cast(s32)bytes.count);
    t := bytes.data + offset;
    for i : 0..num_chars-1 {
        if t >= max_t break;
        t = unicode_next_character(t);
    }
    return cast(s32) (t - bytes.data);
}

unicode_prev_character :: (s: *u8) -> new_s: *u8, char: u32 {  // NOTE: assuming the memory is valid utf-8, no checks are done!
    t := s - 1;
    while (<<t & 0b1100_0000) == 0b1000_0000 t -= 1;  // rewind to the first byte of a utf-8 sequence (all non-first bytes start with 10)
    
    char, _, result := character_utf8_to_utf32(t, s - t);
    return t, char;
}
