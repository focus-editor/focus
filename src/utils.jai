array_insert_bytes_at :: (array: *[..] u8, offset: s64, bytes: [] u8) {
    assert(offset >= 0 && offset <= array.count);
    if !bytes return;

    new_size := array.count + bytes.count;
    array_reserve(array, new_size);

    // NOTE: assuming memcpy works well with overlapping ranges!
    // (tested on Windows with all backends)
    src := array.data + offset;
    dst := src + bytes.count;
    memcpy(dst, src, array.count - offset);

    // Insert the string
    memcpy(array.data + offset, bytes.data, bytes.count);

    array.count = new_size;
}

array_add_bytes :: (array: *[..] u8, bytes: [] u8) {
    if bytes.count <= 0 return;

    new_size := array.count + bytes.count;
    array_reserve(array, new_size);

    memcpy(array.data + array.count, bytes.data, bytes.count);

    array.count = new_size;
}

array_delete_bytes :: (array: *[..] u8, offset: s64, count: s64) {
    assert(offset >= 0 && count >= 0 && offset + count <= array.count);
    memcpy(array.data + offset, array.data + offset + count, array.count - offset - count);
    array.count -= count;
}

array_copy_tmp :: (array: [] $T) -> [] T {
    dest := NewArray(array.count, T, initialized=false, allocator = temp);
    memcpy(dest.data, array.data, array.count * size_of(T));
    return dest;
}

to_bytes :: (src: string) -> [] u8 {
    result: [] u8;
    result.data = src.data;
    result.count = src.count;
    return result;
}

// Intended for compile-time
arrays_concat :: (array1: [] $T, array2: [] T) -> [] T {
    result: [..] T;
    array_extend(*result, array1);
    array_extend(*result, array2);
    return result;
}

decode_utf8_string_to_temp_char_substrings :: (str: string) -> [] string {
    substrings: [..] string;
    substrings.allocator = temp;

    if !str return substrings;

    array_reserve(*substrings, str.count);

    t := str.data;
    while t < str.data + str.count {
        substr: string = ---;
        substr.data = t;
        t = unicode_next_character(t);
        substr.count = t - substr.data;
        array_add(*substrings, substr);
    }

    return substrings;
}

maybe_free_and_clear :: (str: *string) {
    if !str.data || str.count == 0 return;
    free(<< str);
    str.data  = null;
    str.count = 0;
}

to_owned_array :: (array: *[..]$T, free_memory := false) -> []T {
    new_array := array_copy(<<array);
    if free_memory {
        array_reset(array);
    } else {
        array_reset_keeping_memory(array);
    }
    return new_array;
}

array_extend :: (array: *[..] $T, slice: [] T) {
    if slice.count <= 0 return;

    new_size := array.count + slice.count;
    array_reserve(array, new_size);

    memcpy(array.data + array.count, slice.data, slice.count * size_of(T));

    array.count = new_size;
}

pos_to_offset :: (str: string, pos: s64) -> s64 {
    assert(pos >= 0, "Negative char position\n");
    result := -1;
    char_index  := 0;
    offset := 0;

    while offset < str.count {
        if pos == char_index {
            result = offset;
            break;
        }
        byte := str.data[offset];
        offset += 1 + trailingBytesForUTF8[byte];
        char_index += 1;
    }
    if pos == char_index then result = offset;
    assert(result >= 0, "Char position outside string\n");

    return result;
}

// Slices the string using char indices, not byte indices
slice_chars :: (str: string, pos1: s32, pos2: s32) -> string {
    if pos2 <= pos1 || !str return "";

    offset1 := pos_to_offset(str, pos1);
    remaining_str := slice(str, offset1, str.count - offset1);
    offset2 := offset1 + pos_to_offset(remaining_str, pos2 - pos1);

    return slice(str, offset1, offset2 - offset1);
}

// @Speed: this is even slower than the standard find_index_from_left
// NOTE: this function assumes that the substring contains only word chars,
// otherwise it doesn't make sense to call it
find_index_from_left_whole_word :: (s: string, substring: string, start_index := 0) -> s64 {
    if !substring return -1;

    for i : start_index .. s.count - substring.count {
        t := slice(s, i, substring.count);
        if t == substring {
            // Check the char on the right
            right := slice(s, i + substring.count, 4);
            if right {
                next_char, success := utf8_next_character(*right);
                if success == .CONVERSION_OK && is_word_char(next_char) continue;  // not a whole word
            }

            // Check the char on the left
            for j : max(i-2, start_index) .. i-1  {
                // We check the last 2 bytes and try to get a valid utf8 character in 2 attempts.
                // @limitation: this will not match utf8 sequences longer than 2 bytes, but our current
                // word chars are maximum 2 bytes long.
                left := slice(s, j, i - j);
                char, byte_len, result := character_utf8_to_utf32(left.data, left.count);
                if result == .CONVERSION_OK && byte_len == left.count && is_word_char(char) continue i;  // not a whole word
            }

            return i;
        }
    }

    return -1;
}

fuzzy_match :: (str: string, chars: [] string) -> score: s32, highlights: [] bool {
    highlights := NewArray(str.count, bool, initialized = true);  // allocates from the pool
                                                                  // we "leak" if there's no match but that should be ok
    if !chars return 0, highlights;

    MAX_CHARS :: 200;

    score: s32;
    pos := 0;

    for char : chars {
        index := find_index_from_left_nocase(str, char, pos);
        if index < 0 { score = -1; break; }
        highlights[index] = true;
        score += cast(s32) (MAX_CHARS - index);  // the closer to the beginning, the better
        pos = index + char.count;
    }

    if score < 0 then memset(highlights.data, 0, highlights.count);  // no match -> no highlighting

    return score, highlights;
}

bmh_prepare_skip_table :: (needle: string, case_sensitive: bool) -> [256] s32 {
    skip_table: [256] s32 = ---;
    for * skip_table { << it = cast,no_check(s32) needle.count; }
    if case_sensitive {
        for i : 0 .. needle.count - 2 { skip_table[needle[i]]           = cast,no_check(s32) (needle.count - 1 - i); }
    } else {
        for i : 0 .. needle.count - 2 { skip_table[to_lower(needle[i])] = cast,no_check(s32) (needle.count - 1 - i); }
    }
    return skip_table;
}

bmh_find_index_from_left :: (s: string, needle: string, start_index := 0, skip_table: [] s32, $case_sensitive: bool) -> s64 {
    i := start_index;
    last_i := s.count - needle.count;
    while i <= last_i {
        current := to_string(s.data + i, needle.count);
        #if case_sensitive {
            if current == needle return i;
            i += skip_table[s[i + needle.count - 1]];
        } else {
            if equal_nocase(current, needle) return i;
            i += skip_table[to_lower(s[i + needle.count - 1])];
        }
    }
    return -1;
}

find_index_from_left_nocase :: (s: string, substring: string, start_index := 0) -> s64 {
    if !substring return -1;

    for i: start_index..s.count-substring.count {
        t := slice(s, i, substring.count);
        if equal_nocase(t, substring) return i;
    }

    return -1;
}

match_whole_word :: (s: string, offset: int, count: int) -> bool {
    before := <<cast(*u8) (s.data + offset - 1);
    after  := <<cast(*u8) (s.data + offset + count);
    first  := <<cast(*u8) (s.data + offset);
    last   := <<cast(*u8) (s.data + offset + count - 1);

    b := (inline is_whitespace_char(before)) || (inline is_separator_char(before)) || offset - 1 < 0;
    a := (inline is_whitespace_char(after))  || (inline is_separator_char(after))  || offset + count > s.count - 1;
    f := (inline is_whitespace_char(first))  || (inline is_separator_char(first));
    l := (inline is_whitespace_char(last))   || (inline is_separator_char(last));

    return (f && l) || (f && !l && a) || (!f && l && b) || (!f && !l && b && a);
}

#add_context underscore_is_part_of_word := true;

is_word_char :: (ch: u32) -> bool {
    return
        (#char "a" <= ch && ch <= #char "z") ||
        (#char "A" <= ch && ch <= #char "Z") ||
        (ch == #char "_" && context.underscore_is_part_of_word) ||
        (#char "0" <= ch && ch <= #char "9") ||
        (#char "а" <= ch && ch <= #char "я") ||
        (#char "А" <= ch && ch <= #char "Я") ||
        (ch == #char "ё" || ch == #char "Ё");  // TODO: include other common chars
}

is_non_word_char :: inline (ch: u32) -> bool {
    return !is_word_char(ch) && ch != #char " " && ch != #char "\n";
}

is_space_char :: inline (ch: u32) -> bool {
    return ch == #char " " || (!context.underscore_is_part_of_word && ch == #char "_");
}

is_whitespace_char :: inline (ch: u8) -> bool {
    return ch == #char " " || ch == #char "\t" || ch == #char "\n" || ch == #char "\r";
}

is_separator_char :: inline (ch: u8) -> bool {
    return
        ch == #char "`" || ch == #char "~" || ch == #char "!" || ch == #char "@" || ch == #char "#" ||
        ch == #char "%" || ch == #char "^" || ch == #char "&" || ch == #char "*" || ch == #char "(" ||
        ch == #char ")" || ch == #char "-" || ch == #char "=" || ch == #char "+" || ch == #char "[" ||
        ch == #char "{" || ch == #char "]" || ch == #char "}" || ch == #char "$" || ch == #char "|" ||
        ch == #char ";" || ch == #char ":" || ch == #char "'" || ch == #char "?" || ch == #char "," ||
        ch == #char "." || ch == #char "<" || ch == #char ">" || ch == #char "/" || ch == #char "\"" || ch == #char "\\";
}

get_char_type :: (ch: u32) -> Char_Type {
    if is_word_char(ch) {
        return .word;
    } else if is_space_char(ch) {
        return .space;
    } else if ch != #char "\n" {
        return .non_word;
    } else {
        return .other;
    }
}

is_all_whitespace :: (s: string) -> bool {
    for byte : to_bytes(s) {
        // Multi-byte whitespace is not included
        if byte != #char " " && byte != #char "\t" && byte != #char "\n" && byte != #char "\r" then return false;
    }
    return true;
}

count_whitespace :: (bytes: [] u8, start_offset: s64, max_offset: s64, spaces := " \t") -> count: s32 {
    subarray := array_view(bytes, start_offset, max_offset - start_offset);
    for subarray {
        if !is_any(it, spaces) return cast(s32) it_index;
    }
    return cast(s32) (max_offset - start_offset);
}

get_tmp_spaces :: (num: int) -> string {
    spaces := talloc_string(num);
    memset(spaces.data, cast(u8) #char " ", num);
    return spaces;
}

get_tmp_tabs :: (num: int) -> string {
    tabs := talloc_string(num);
    memset(tabs.data, cast(u8) #char "\t", num);
    return tabs;
}

start_animation :: (anim: *Tween_Animation(T), start: $T, target: T, speed: Time = xx 0.0, $snappy := false) {
    anim.start  = start;
    anim.target = target;
    if speed > 0 then anim.speed = speed;

    #if OS == .LINUX {
        // Don't restart the animation at the current frame if it's already started.
        // But still cap it's starting time at just a single frame delta to be conservative.
        // This lets us start animation smoothly, as in the "else" branch below, but
        // continue in a snappy way as we scroll.
        if anim.started_at {
            anim.started_at = frame_time - MAX_FRAME_DT;
            return;
        }
    }
    #if snappy {
        // Pretend the animation started last frame so we start moving right away
        anim.started_at = frame_time - MAX_FRAME_DT;
    } else {
        // Things will start moving next frame - but usually in a more smooth way
        anim.started_at = frame_time;
    }
}

get_animation_value :: (using anim: Tween_Animation($T)) -> T {
    t := cast(float) ((frame_time - started_at) / speed);
    t = clamp(t, 0, 1);
    if #complete func == {
        case .lerp;       return start + cast(T) (cast(float)(target - start) * t);
        case .smoothstep; return start + cast(T) (cast(float)(target - start) * t * t * (3.0 - 2.0 * t));
    }
}

get_identifier_name :: (name: Code) -> string {
    node := compiler_get_nodes(name);
    if node.kind != .IDENT {
        compiler_report("Not an identifier.", make_location(node));
        return "";
    }

    ident := cast(*Code_Ident) node;
    return ident.name;
}

trim_both_sides :: (s: string, chars := " \t") -> string, left: s64, right: s64 {
    left  := 0;
    right := 0;

    for 0..s.count-1 {
        if is_any(s[it], chars) left += 1;
        else break;
    }

    for < s.count-1..left {
        if is_any(s[it], chars) right += 1;
        else break;
    }

    return slice(s, left, s.count - left - right), left, right;
}

get_num_cpus :: () -> s32 {
    num_cpus := clamp(get_number_of_processors(), 2, 200);

    #if (OS == .WINDOWS) || (OS == .LINUX) {
        num_cpus /= 2; // this routine reports hyperthreads, so, divide by two, because of Intel marketing.
    }

    return num_cpus;
}

is_white_space :: inline (char : u8) -> bool #no_aoc {
    result : u32 = ---;

    // Should be in register, not immediate
    white_spaces : u64 = (#char " "  <<  0)  // space.
                       | (#char "\t" <<  8)  // horizontal tab.
                       | (#char "\n" << 16)  // line feed.
                       | (#char "\r" << 24)  // carriage return.
                       | (0x0C       << 32)  // form feed.    Warning: Unknown escape sequence '\f' in string constant!
                       | (0x0B       << 40); // vertical tab. Warning: Unknown escape sequence '\v' in string constant!

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

#scope_export

Tween_Animation :: struct(T: Type) {
    start, target: T;
    started_at: Time;
    speed: Time = xx 0.1;  // how many seconds to finish
    func: enum { lerp; smoothstep; } = .smoothstep;
}

Char_Type :: enum {
    none;
    word;
    non_word;
    space;
    other;
}
