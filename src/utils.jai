array_insert_bytes_at :: (array: *[..] u8, offset: s64, bytes: [] u8) {
    assert(offset >= 0 && offset <= array.count);
    if !bytes return;

    new_size := array.count + bytes.count;
    array_reserve(array, new_size);

    src := array.data + offset;
    dst := src + bytes.count;
    focus_memcpy(dst, src, array.count - offset);

    // Insert the string
    focus_memcpy(array.data + offset, bytes.data, bytes.count);

    array.count = new_size;
}

array_add_bytes :: (array: *[..] u8, bytes: [] u8) {
    if bytes.count <= 0 return;

    new_size := array.count + bytes.count;
    array_reserve(array, new_size);

    focus_memcpy(array.data + array.count, bytes.data, bytes.count);

    array.count = new_size;
}

array_delete_bytes :: (array: *[..] u8, offset: s64, count: s64) {
    assert(offset >= 0 && count >= 0 && offset + count <= array.count);
    focus_memcpy(array.data + offset, array.data + offset + count, array.count - offset - count);
    array.count -= count;
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
    array_add(*result, ..array1);
    array_add(*result, ..array2);
    return result;
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

advance_to_next_line :: inline (s: *string) {
    while s.* {
        saw_newline := s.*[0] == #char "\n";
        s.count -= 1;
        s.data  += 1;
        if saw_newline break;  // only break after the newline, not before
    }
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

fuzzy_match :: (str: string, filter: Fuzzy_Filter, only_exact := false) -> score: s32, highlights: [] bool, exact_match := false {
    highlights := NewArray(str.count, bool, initialized = true);
    if !filter.chunks return 0, highlights;

    MAX_CHARS :: 400;

    // Try matching the full string first and rank it the highest
    {
        index := find_index_from_left_nocase(str, filter.full_string, 0);
        if index >= 0 {
            memset(highlights.data + index, cast(u8) true, filter.full_string.count);
            score := (400 + filter.full_string.count) * (MAX_CHARS - index);
            return cast(s32) score, highlights, true;
        }
    }

    score := 0;

    auto_release_temp();
    chunk_highlights := NewArray(str.count, bool, initialized = false,, allocator = temp);  // to store temporary highlights we might later reject

    // Try matching each chunk exactly and accept the match if at least one matches
    for chunk : filter.chunks {
        chunk_score := 0;
        memset(chunk_highlights.data, 0, chunk_highlights.count);

        index := find_index_from_left_nocase(str, chunk.str, 0);
        if index >= 0 {
            memset(chunk_highlights.data + index, cast(u8) true, chunk.str.count);
            chunk_score += (200 + chunk.str.count) * (MAX_CHARS - index) - str.count;
        }

        if chunk_score >= 0 {
            score += chunk_score;
            for i : 0 .. chunk_highlights.count - 1 { highlights[i] |= chunk_highlights[i]; }  // apply chunk highlights
        }
    }

    if score > 0 return xx score, highlights, true;  // if we had at least one exact match, don't proceed
    if score <= 0 && only_exact return xx score, highlights;

    // Then match individual chars
    for chunk : filter.chunks {
        pos := 0;
        chunk_score := 0;
        memset(chunk_highlights.data, 0, chunk_highlights.count);

        // Try matching the full chunk first
        for char : chunk.chars {
            index := find_index_from_left_nocase(str, char, pos);
            if index < 0 { chunk_score = -1; break; }
            chunk_highlights[index] = true;
            chunk_score += 10 * (MAX_CHARS - index);  // the closer to the beginning, the better
            pos = index + char.count;
        }

        if chunk_score >= 0 {
            score += chunk_score;
            for i : 0 .. chunk_highlights.count - 1 { highlights[i] |= chunk_highlights[i]; }  // apply chunk highlights
        }
    }

    // if score <= 0 then memset(highlights.data, 0, highlights.count);  // no match -> no highlighting

    return xx score, highlights;
}

construct_fuzzy_filter :: (filter_str: string, treat_slashes_as_spaces := false) -> Fuzzy_Filter {
    str := copy_temporary_string(trim(filter_str));
    if !str return .{};

    chunks: [..] Fuzzy_Filter.Chunk;
    chunks.allocator = temp;

    // Split into strings separated by spaces or slashes
    space := cast(u8) #char " ";
    if treat_slashes_as_spaces then replace_chars(str, "\\/", space);
    strings := split(str, space,, allocator = temp);

    for s : strings {
        if !s continue;

        // Split the strings into individual chars
        chars: [..] string;
        chars.allocator = temp;
        array_reserve(*chars, strings.count);

        t := s.data;
        while t < s.data + s.count {
            substr: string = ---;
            substr.data = t;
            t = unicode_next_character(t);
            substr.count = t - substr.data;
            array_add(*chars, substr);
        }

        array_add(*chunks, Fuzzy_Filter.Chunk.{ str = s, chars = chars });
    }

    return Fuzzy_Filter.{ full_string = str, chunks = chunks };
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
    word_ends_on_the_left  := offset <= 0               || !is_word_char(s[offset - 1])     || !is_word_char(s[offset]);
    word_ends_on_the_right := offset + count >= s.count || !is_word_char(s[offset + count]) || !is_word_char(s[offset + count - 1]);

    return word_ends_on_the_left && word_ends_on_the_right;
}

#add_context underscore_is_part_of_word := true;

is_word_char :: inline (ch: u32) -> bool {
    return ifx ch == #char "_" then context.underscore_is_part_of_word else (!is_whitespace_char(ch) && !is_separator_char(ch));
}

is_non_word_char :: inline (ch: u32) -> bool {
    return !is_word_char(ch) && ch != #char " " && ch != #char "\n";
}

is_space_or_underscore :: inline (ch: u32) -> bool {
    return is_unicode_space(ch) || (!context.underscore_is_part_of_word && ch == #char "_");
}

is_whitespace_char :: inline (ch: u32) -> bool {
    return is_unicode_space(ch) || is_unicode_linebreak(ch);
}

/*
 * TODO: is_separator_char(), is_balanceable_char(), is_auto_closeable_char(), get_balancing_char()
 *       should be part of the syntax highlighters to allow for language-specific behavior
 */
is_separator_char :: inline (ch: u32) -> bool {
    return
        ch == #char "`" || ch == #char "~" || ch == #char "!" || ch == #char "@" || ch == #char "#" ||
        ch == #char "%" || ch == #char "^" || ch == #char "&" || ch == #char "*" || ch == #char "(" ||
        ch == #char ")" || ch == #char "-" || ch == #char "=" || ch == #char "+" || ch == #char "[" ||
        ch == #char "{" || ch == #char "]" || ch == #char "}" || ch == #char "$" || ch == #char "|" ||
        ch == #char ";" || ch == #char ":" || ch == #char "'" || ch == #char "?" || ch == #char "," ||
        ch == #char "." || ch == #char "<" || ch == #char ">" || ch == #char "/" || ch == #char "\"" ||
        ch == #char "\\";
}

is_balanceable_char :: (ch: u32) -> bool {
    return ch == #char "{" || ch == #char "(" || ch == #char "[" || ch == #char "\"";
}

is_auto_closeable_char :: (ch: u32) -> bool {
    return ch == #char "{" || ch == #char "(" || ch == #char "[";
}

get_balancing_char :: (ch: u32) -> u32 {
    if ch == {
        case #char "{";  return #char "}";
        case #char "(";  return #char ")";
        case #char "[";  return #char "]";
        case #char "\""; return #char "\"";
        case; return 0;
    }
}

get_char_type :: (ch: u32) -> Char_Type {
    if is_word_char(ch) {
        return .word;
    } else if is_space_or_underscore(ch) {
        return .space;
    } else if !is_unicode_linebreak(ch) {
        return .non_word;
    } else {
        return .other;
    }
}

is_all_word_chars :: (s: string) -> bool {
    for byte : to_bytes(s) {
        if !is_word_char(byte) then return false;
    }
    return true;
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

get_visual_indent_in_spaces :: (line: string, spaces := " \t") -> indent: int {
    indent := 0;
    for byte : to_bytes(trim_right(line)) {
        if byte == {
            case #char " ";     indent += 1;
            case #char "\t";    indent += TAB_SIZE - (indent % TAB_SIZE);
            case;               break;
        }
    }
    return indent;
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

start_animation :: (anim: *Tween_Animation(T), start: $T, target: T, speed: Time = xx 0.0) {
    anim.start  = start;
    anim.target = target;
    if speed > 0 then anim.speed = speed;

    // Pretend the animation started last frame so we start moving right away.
    // If the current frame was t=0, then the movement would simply be delayed one frame.
    anim.started_at = frame_time - to_apollo(frame_dt);
}

get_animation_value :: (using anim: Tween_Animation($T)) -> T {
    t := (to_float64_seconds(frame_time - started_at) / speed);
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

starts_with :: inline (s: string, ch: u8) -> bool {
    return (s.count >= 1) && (s[0] == ch);
}

ends_with :: inline (s: string, ch: u8) -> bool {
    return (s.count >= 1) && (s[s.count - 1] == ch);
}

// a version of `split()` from the `String` module that returns an array with a maximum
// number of elements
split :: (s: string, separator: $T, max_splits: int) -> [] string {
    #assert (T == u8) || (T == string);

    results: [..] string;

    if max_splits < 1 return results;

    remainder := s;
    while remainder {
        if results.count >= max_splits - 1 {
            array_add(*results, remainder);
            break;
        }

        found, left, right := split_from_left(remainder, separator);
        if found {
            array_add(*results, left);
        } else {
            array_add(*results, remainder);
            break;
        }

        remainder = right;
    }

    if !remainder && results.count < max_splits array_add(*results, "");

    return results;
}

Tween_Animation :: struct(T: Type) {
    start, target: T;
    started_at: Apollo_Time;
    speed : Time = xx 0.1;  // how many seconds to finish
    func: enum { lerp; smoothstep; } = .smoothstep;
}

Char_Type :: enum {
    none;
    word;
    non_word;
    space;
    other;
}

Fuzzy_Filter :: struct {
    full_string: string;
    chunks: [] Chunk;

    Chunk :: struct {
        str: string;
        chars: [] string;
    }
}
