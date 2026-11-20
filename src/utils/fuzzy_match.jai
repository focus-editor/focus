fuzzy_match :: (s: string, filter: Fuzzy_Filter, only_exact := false, $want_highlights := false) -> score: s32, exact_match := false, highlights: [] bool = .[] {
    highlights: [] bool;
    #if want_highlights {
        highlights = NewArray(s.count, bool, initialized = true);
    }

    auto_release_temp();
    str := to_lower_copy(s,, temp);

    if !filter.chunks || !str return 0, false, highlights;

    MAX_CHARS :: 400;

    index := kmp_find_index_from_left(str, filter.full_string, filter.full_string_prefix_table);
    if index >= 0 {
        #if want_highlights {
            memset(highlights.data + index, cast(u8) true, filter.full_string.count);
        }
        score := (400 + filter.full_string.count) * (MAX_CHARS - index);
        return cast(s32) score, true, highlights;
    }

    score := 0;
    for chunk : filter.chunks {
        if chunk.str.count == filter.full_string.count continue;

        index := kmp_find_index_from_left(str, chunk.str, chunk.prefix_table);
        if index < 0 continue;

        chunk_score := (200 + chunk.str.count) * (MAX_CHARS - index) - str.count;
        if chunk_score < 0 continue;

        score += chunk_score;
        #if want_highlights {
            memset(highlights.data + index, cast(u8) true, chunk.str.count);
        }
    }

    if score > 0 return xx score, true, highlights;
    if only_exact return xx score, false, highlights;

    chunk_highlights: [] bool;
    temp_mark: Temporary_Storage_State;
    #if want_highlights {
        // Take the mark after allocating the returned mask, which may also use temp
        temp_mark = get_temporary_storage_mark();
        chunk_highlights = NewArray(str.count, bool, initialized = false,, temp);
    }
    defer {
        #if want_highlights {
            set_temporary_storage_mark(temp_mark);
        }
    }

    for chunk : filter.chunks {
        pos := 0;
        chunk_score := 0;
        #if want_highlights {
            memset(chunk_highlights.data, 0, chunk_highlights.count);
        }

        for char : chunk.chars {
            index: int;
            if char.count == 1 {
                index = find_index_from_left(str, char[0], pos);  // more efficient
            } else {
                index = find_index_from_left(str, char, pos);
            }
            if index < 0 { chunk_score = -1; break; }

            #if want_highlights {
                chunk_highlights[index] = true;
            }
            chunk_score += 10 * (MAX_CHARS - index);
            pos = index + char.count;
        }

        if chunk_score < 0 continue;
        score += chunk_score;

        #if want_highlights {
            for i : 0 .. chunk_highlights.count - 1 {
                highlights[i] |= chunk_highlights[i];
            }
        }
    }

    return xx score, false, highlights;
}


// NOTE: assuming the context allocator is either temp or a pool
construct_fuzzy_filter :: (filter_str: string, multi_chunk_search := false) -> Fuzzy_Filter {
    str := to_lower_copy(trim(filter_str),, temp);
    if !str return .{};

    chunks: [..] Fuzzy_Filter.Chunk;
    chunks.allocator = temp;

    // Maybe split into strings separated by spaces or slashes (useful for the open file dialog)
    strings: [] string;
    if multi_chunk_search {
        space := cast(u8) #char " ";
        replace_chars(str, "\\/", space);
        strings = split(str, space,, temp);
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

        array_add(*chunks, Fuzzy_Filter.Chunk.{ str = s, prefix_table = kmp_build_prefix_table(s), chars = chars });
    }

    return Fuzzy_Filter.{ full_string = str, full_string_prefix_table = kmp_build_prefix_table(str), chunks = chunks };
}


Fuzzy_Filter :: struct {
    full_string: string;
    full_string_prefix_table: [] int;

    chunks: [] Chunk;

    Chunk :: struct {
        str: string;
        prefix_table: [] int;
        chars: [] string;
    }
}
