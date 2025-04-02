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

array_view_to_end :: inline (array: [] $T, offset: s64) -> [] T {
    return array_view(array, offset, array.count - offset);
}

to_bytes :: (src: string) -> [] u8 {
    result: [] u8;
    result.data = src.data;
    result.count = src.count;
    return result;
}

arrays_concat :: (array1: [] $T, array2: [] T) -> [] T {
    result: [..] T;
    array_add(*result, ..array1);
    array_add(*result, ..array2);
    return result;
}

visual_col_to_byte_offset :: (str: string, target_col: s64, line_indent: s64, tab_size: s32) -> offset: s64, new_col: s64 {
    s := str;
    col := 0;

    while s && col < target_col {
        byte := s[0];
        if byte != #char "\t" {
            safe_advance(*s, 1 + trailingBytesForUTF8[byte]);
            col += 1;
        } else {
            safe_advance(*s, 1);
            col += tab_size - (col + line_indent) % tab_size;
        }
    }

    return (s.data - str.data), col;
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

construct_fuzzy_filter :: (filter_str: string, multi_chunk_search := false) -> Fuzzy_Filter {
    str := copy_temporary_string(trim(filter_str));
    if !str return .{};

    chunks: [..] Fuzzy_Filter.Chunk;
    chunks.allocator = temp;

    // Maybe split into strings separated by spaces or slashes (useful for the open file dialog)
    strings: [] string;
    if multi_chunk_search {
        space := cast(u8) #char " ";
        replace_chars(str, "\\/", space);
        strings = split(str, space,, allocator = temp);
    } else {
        strings = .[str];  // treat the whole search string as one (useful for commands etc)
    }

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

contains_uppercase_ascii :: (s: string) -> bool {
    // TODO: support unicode too when we support case insensitive search for unicode strings
    for 0 .. s.count-1 {
        char := s[it];  // we don't care if it's part of a larger unicode char
        if (char >= #char "A" && char <= #char "Z") return true;
    }
    return false;
}

match_whole_word :: (s: string, offset: int, count: int) -> bool {
    word_ends_on_the_left  := offset <= 0               || !is_word_char(s[offset - 1])     || !is_word_char(s[offset]);
    word_ends_on_the_right := offset + count >= s.count || !is_word_char(s[offset + count]) || !is_word_char(s[offset + count - 1]);

    return word_ends_on_the_left && word_ends_on_the_right;
}

is_word_char :: inline (ch: u32) -> bool {
    return get_char_type(ch) & .word != 0;
}

is_non_word_char :: inline (ch: u32) -> bool {
    return get_char_type(ch) & .non_word != 0;
}

is_common_punctuation :: inline (ch: u32) -> bool {
    if ch == {
        case #char ","; #through;
        case #char "."; #through;
        case #char "("; #through;
        case #char ")"; #through;
        case #char "["; #through;
        case #char "]"; #through;
        case #char "{"; #through;
        case #char "}";
            return true;
    }
    return false;
}

is_whitespace_char :: inline (ch: u32) -> bool {
    return is_unicode_space(ch) || is_unicode_linebreak(ch);
}

is_lower :: inline (char: u8) -> bool {
    return char >= #char "a" && char <= #char "z";
}

is_upper :: inline (char: u8) -> bool {
    return char >= #char "A" && char <= #char "Z";
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

get_balancing_char :: (ch: u32, include_closing := false) -> u32 {
    if ch == {
        case #char "{";  return #char "}";
        case #char "(";  return #char ")";
        case #char "[";  return #char "]";
        case #char "\""; return #char "\"";
    }
    if include_closing {
        if ch == {
            case #char "}";  return #char "{";
            case #char ")";  return #char "(";
            case #char "]";  return #char "[";
        }
    }
    return 0;
}

get_char_type_raw :: inline (ch: u32) -> Char_Type {
    if #char "0" <= ch && ch <= #char "9"   return .word | .number;
    if ch == #char "."                      return .non_word | .number;
    if is_whitespace_char(ch)               return .space; // includes \n
    if !is_separator_char(ch)               return .word;
    return .non_word;
}

get_char_type :: inline (ch: u32) -> Char_Type {
    if ch <= 191  return char_type_table[ch];
    return get_char_type_raw(ch);
}

set_underscore_is_part_of_word :: (it_is: bool) {
    char_type_table[#char "_"] = ifx it_is then .word else .non_word;
}

set_newline_is_whitespace :: (it_is: bool) {
    char_type_table[#char "\n"] = ifx it_is then .space else .other;
}

#insert -> string {
    builder : String_Builder;
    append(*builder, "char_type_table := Char_Type.[");
    for 0 .. cast(u32)191  print_to_builder(*builder, "%,", cast(u8)get_char_type_raw(it));
    append(*builder, "];");
    return builder_to_string(*builder);
}

scan_through_similar_chars_on_the_left :: (bytes: [] u8, line_start_offset: s32, offset: s32, char_type := Char_Type.none, skip_one_space := true) -> offset: s32, moved_through: Char_Type  {
    if !bytes  return 0, .none;

    ptr := bytes.data + offset;
    char:, ptr = unicode_prev_character_and_position(ptr);
    if ptr <= bytes.data  return 0, .none;

    skippable_char_type := get_char_type(char);
    if char_type != .none && !(char_type & skippable_char_type)  return offset, .none;

    moved_through : Char_Type;
    result_ptr := ptr;
    line_start := bytes.data + line_start_offset;
    if skip_one_space && is_whitespace_char(char) && ptr > line_start {
        char, ptr = unicode_prev_character_and_position(ptr);
        skippable_char_type = get_char_type(char);
        moved_through = .space;
    }

    while skippable_char_type {
        if ptr <= bytes.data  return 0, moved_through;

        result_ptr = ptr;
        char, ptr = unicode_prev_character_and_position(ptr);
        moved_through = skippable_char_type;
        skippable_char_type &= get_char_type(char);
    }

    return cast(s32) (result_ptr - bytes.data), moved_through;
}

scan_through_similar_chars_on_the_right :: (bytes: [] u8, offset: s32, char_type := Char_Type.none, skip_one_space := true) -> offset: s32, moved_through: Char_Type {
    if !bytes  return 0, .none;
    if offset >= bytes.count  return cast(s32) bytes.count, .none;

    end_address := bytes.data + bytes.count;
    ptr := bytes.data + offset;
    char:, ptr = unicode_character_and_next_position(ptr);
    skippable_char_type := get_char_type(char);
    if char_type != .none && !(char_type & skippable_char_type)  return offset, .none;
    if ptr >= end_address  return cast(s32) bytes.count, 0;

    moved_through : Char_Type;
    result_ptr := ptr;
    if skip_one_space && is_whitespace_char(char) {
        char, ptr = unicode_character_and_next_position(ptr);
        skippable_char_type = get_char_type(char);
        moved_through = .space;
    }

    while skippable_char_type {
        if ptr >= end_address  return cast(s32) bytes.count, moved_through;

        result_ptr = ptr;
        char, ptr = unicode_character_and_next_position(ptr);
        moved_through = skippable_char_type;
        skippable_char_type &= get_char_type(char);
    }

    return cast(s32) (result_ptr - bytes.data), moved_through;
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

count_whitespace :: (bytes: Array(u8), start_offset: s32, max_offset: s32, spaces := " \t") -> count: s32 {
    subarray := to_view(bytes, start_offset, max_offset - start_offset);
    for subarray {
        if !is_any(it, spaces) return cast(s32) it_index;
    }
    return max_offset - start_offset;
}

count_bytes_knowing_number_of_chars :: (bytes: Array(u8), start_offset: s32, max_offset: s32, num_chars: s32) -> count: s32 {
    count: s32 = 0;
    s := cast(string) to_view(bytes, start_offset, max_offset - start_offset);
    while s && num_chars {
        byte := s[0];
        num_bytes := clamp(1 + cast(s32) trailingBytesForUTF8[byte], 1, cast(s32) s.count);
        advance(*s, num_bytes);
        count += num_bytes;
        num_chars -= 1;
    }
    return count;
}

get_visual_indent_in_spaces :: (line: string, tab_size: s32) -> indent: int, bytes: int {
    indent, bytes: int;
    for byte : to_bytes(trim_right(line)) {
        if byte == {
            case #char " ";     indent += 1;
            case #char "\t";    indent += tab_size - (indent % tab_size);
            case;               break;
        }
        bytes += 1;
    }
    return indent, bytes;
}

get_tmp_spaces :: (num: int) -> string {
    if num <= 0 return "";
    spaces := talloc_string(num);
    memset(spaces.data, cast(u8) #char " ", num);
    return spaces;
}

get_tmp_tabs :: (num: int) -> string {
    tabs := talloc_string(num);
    memset(tabs.data, cast(u8) #char "\t", num);
    return tabs;
}

start_animation :: (anim: *Tween_Animation(T), target: $T) {
    value := get_animation_value(anim);
    start_animation(anim, value, target);
}

start_animation :: (anim: *Tween_Animation(T), start: $T, target: T, duration: float = 0.0, delay: float64 = 0.0) {
    anim.start  = start;
    anim.target = target;
    if duration > 0 then anim.duration = duration;

    if delay {
        anim.delay = delay;
        anim.started_at = frame_time64;
    } else {
        // Pretend the animation started last frame so we start moving right away.
        // If the current frame was t=0, then the movement would simply be delayed one frame.
        anim.started_at = frame_time64 - frame_dt;
    }
}

maybe_wait_for_delay :: (using anim: *Tween_Animation($T)) -> bool {
    if delay <= 0 return false;  // nothing to wait on
    if frame_time64 < started_at + delay return true;

    // Start an animation again as the delay has just ended.
    // We have to do it this way because we want to sleep on the delay and we don't want a jerky animation
    // because of the sleep precision, so we're starting it from the beginning now
    started_at = frame_time64 - frame_dt;
    delay = 0;
    return false;
}

get_animation_value :: (using anim: Tween_Animation($T)) -> T, finished: bool {
    t := (frame_time64 - (started_at + delay)) / duration;

    finished := false;
    if t >= 1 { t = 1; finished = true; }
    if t <  0 { t = 0; }

    result: T;
    if #complete func == {
        case .lerp;       result = start + cast(T) (cast(float)(target - start) * t);
        case .smoothstep; result = start + cast(T) (cast(float)(target - start) * t * t * (3.0 - 2.0 * t));
    }

    return result, finished;
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

    for #v2 < left..s.count-1 {
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

table_find_or_default :: (table: *Table, key: table.Key_Type) -> table.Value_Type {
    pointer := inline table_find_pointer(table, key);
    if pointer  return << pointer;

    default: table.Value_Type;
    return default;
}

Tween_Animation :: struct(T: Type) {
    started_at: float64;
    delay: float64;
    duration: float = xx 0.1;  // how many seconds to finish
    start, target: T;
    func: enum { lerp; smoothstep; } = .smoothstep;
}

Char_Type :: enum_flags {
    none;
    word;
    number;
    non_word;
    space;
    other;
}

Movement_Type :: enum {
    by_character;            // goes through 1 character at a time
    by_character_type;       // goes through blocks of characters of the same type (see Char_Type)
    by_character_type_fast;  // like above, but treats underscores as part of word, and skips 1 space (unless multiple cursors are used)
    through_word;            // goes through anything to reach the end of the next word block
    through_word_throttled;  // like above, but goes through at most 2 blocks of characters at a time
}

Fuzzy_Filter :: struct {
    full_string: string;
    chunks: [] Chunk;

    Chunk :: struct {
        str: string;
        chars: [] string;
    }
}

rgb_from_hsl :: (hsl: Vector3) -> Vector3 {
    h := hsl.x;
    s := hsl.y;
    l := hsl.z;
    r, g, b: float;

    if s == 0 {
        r, g, b = l, l, l; // achromatic
    }
    else {
        rgb_from_hue :: (p: float, q: float, t: float) -> float {
            if t < 0  t += 1;
            if t > 1  t -= 1;
            if t < 1.0/6.0  return p + (q - p) * 6 * t;
            if t < 1.0/2.0  return q;
            if t < 2.0/3.0  return p + (q - p) * (2.0/3.0 - t) * 6;
            return p;
        }

        q := ifx l < 0.5 then l * (1 + s) else l + s - l * s;
        p := 2 * l - q;
        r = rgb_from_hue(p, q, h + 1.0/3.0);
        g = rgb_from_hue(p, q, h);
        b = rgb_from_hue(p, q, h - 1.0/3.0);
    }

    return .{r, g, b};
}

hsl_from_rgb :: (color: Vector3) -> hsl: Vector3 {
    r := color.x;
    g := color.y;
    b := color.z;
    h, s, l: float;

    _min := min(min(r, g), b);
    _max := max(max(r, g), b);

    c := _max - _min;
    l = (_min + _max) / 2;

    if c < 0.00001 || _max <= 0.0 return .{h, s, l};

    s = ifx l >= 0.5
        then c / (2 - _max - _min)
        else c / (_max + _min);

    if      _max == r  h = (g - b) / c + (ifx g < b then 6 else 0);
    else if _max == g  h = (b - r) / c + 2;
    else               h = (r - g) / c + 4;

    h /= 6.0;
    if h < 0.0  h += 1.0;

    return .{h, s, l};
}

color_to_hex :: (using color: Vector4, exclude_hash := false) -> string /* temp */ {
    r_u8 := cast(u8)(255 * x);
    g_u8 := cast(u8)(255 * y);
    b_u8 := cast(u8)(255 * z);
    a_u8 := cast(u8)(255 * w);

    h :: #bake_arguments formatInt(base=16, minimum_digits=2);
    format := "#%1%2%3%4";
    if exclude_hash advance(*format, 1);

    return tprint(format, h(r_u8), h(g_u8), h(b_u8), h(a_u8));
}

hex_to_color_vec4 :: (src_hex: string) -> Vector4, success: bool {
    hex := src_hex;
    if hex.count == 6 then hex = tprint("%FF", hex);
    if hex.count != 8 return Vector4.{}, false;

    r := slice(hex, 0, 2);
    g := slice(hex, 2, 2);
    b := slice(hex, 4, 2);
    a := slice(hex, 6, 2);

    to_float :: (byte_str: string) -> float {
        hex_digit_to_int :: (char: u8) -> int {
            char = to_upper(char);
            if #char "0" <= char && char <= #char "9" return char - #char "0";
            if #char "A" <= char && char <= #char "F" return 10 + char - #char "A";
            return -1;
        }

        d1, d0 := cast(float)hex_digit_to_int(byte_str[0]), cast(float) hex_digit_to_int(byte_str[1]);
        if d1 < 0 || d0 < 0 return -1;

        return (16 * d1 + d0) / 255;
    }

    c := Vector4.{ to_float(r), to_float(g), to_float(b), to_float(a) };

    return c, c.x >= 0 && c.y >= 0 && c.z >= 0 && c.w >= 0;
}

move_toward :: (a_pointer: *float, target: float, dt: float, rate_up: float, rate_down: float = -1.0) {  // lifted from GetRect
    a := a_pointer.*;

    if a > target {
        if rate_down == -1 rate_down = rate_up;
        a -= dt * rate_down;
        if a < target  a = target;
        a_pointer.* = a;
    } else if a < target {
        a += dt * rate_up;
        if a > target  a = target;
        a_pointer.* = a;
    }
}

Option :: struct($T: Type) {
    value:  T = ---;
    is_set: bool;
}

some :: (value: $T) -> Option(T) {
    return .{ value = value, is_set = true };
}
