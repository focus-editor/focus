/*

Note, 30 January 2018:
This Font code was pulled over from the C++ code from The Witness.
*However*, that was before I did a huge revamp of The Witness' code to use
the 'harfbuzz' library to do better handling of issues involving various
languages (especially right-to-left languages with lots of glyph rewrite
rules like Arabic), and to do better kerning+ligatures.

Sometime soon we want to pull the new version of the code from The Witness
and provide harfbuzz as a library in modules/.

                 -jblow, 30 January 2018.



Clean up load_font vs get_font_at_size.

Is FT_Face_Internal by value? If so, how big is it?? (Do we care?)

get_kerning is broken (it breaks font rendering for KarminaBold at least).

isLegalUTF8 does not work.


@Cleanup:
Note that Unicode.jai has a bunch of utf8 stuff in there so we should probably
deduplicate to that.
*/

// @Cleanup: Glyph_Index is just u32, probably clearer if we give it its own type.

glyph_id_to_hash_key :: (x: u32) -> int {
    print("calling glyph_id_to_hash_key: %", x);
    return -cast(int) x;
}

isdigit :: (utf32: u32) -> bool {
    return (utf32 >= #char "0") && (utf32 <= #char "9");
}


isLegalUTF8 :: (source: *u8, length: s64) -> bool {
    if length == 0 return false;
    if length >  4  return false;

	srcptr := source+length;

    if length >= 4 {
        a := <<srcptr;
        srcptr -= 1;
        if a < 0x80 return false;
        if a > 0xBF return false;
    }

    if length >= 3 {
        a := <<srcptr;
        srcptr -= 1;
        if a < 0x80 return false;
        if a > 0xBF return false;
    }

    if length >= 2 {
        a := << srcptr;
        srcptr -= 1;
        if a > 0xBF return false;

        if << source == 0xE0 {
            if a < 0xA0 return false;
        } else if << source == 0xF0 {
            if a < 0x90 return false;
        } else if << source == 0xF4 {
            if a > 0x8F return false;
        } else {
            if a < 0x80 return false;
        }
    }

    if (<< source >= 0x80) && (<< source <= 0xC2) return false;
    if << source > 0xF4 return false;

    return true;
}


Font_Effects :: enum_flags u32 {
    SMALLCAPS      :: 0x1;
    LINING_FIGURES :: 0x2;
    NO_KERNING     :: 0x4;
    LEFT_JUSTIFIED :: 0x8;
}

Glyph_Data :: struct {
    utf32: u32;
    glyph_index_within_font: u32;

    x0, y0: s16;
    width, height: u32;

    offset_x, offset_y: s16;

    ascent: s16;  // Mainly for descent, actually!
    advance: s16;

    page: *Font_Page;
}

Font_Quad :: struct {
    p0, p1, p2, p3: Vector2;
    u0, v0, u1, v1: float;

    glyph: *Glyph_Data;
}

Dynamic_Font :: struct {
    name: string;
    latin_font: *Dynamic_Font;

    glyph_lookup: Table(int, *Glyph_Data);

    private1: FT_Face;

    character_range_low:  int;
    character_range_high: int;

    character_height:       int;
    default_line_spacing:   int;
    max_ascender:           int;
    max_descender:          int;
    typical_ascender:       int;
    typical_descender:      int;
    em_width:               int;

    y_offset_for_my_latin_characters: float;
    y_offset_for_centering: int;

    use_other_font_for_latin_always: bool;
    reversed: bool;  // True if this font is byte-order-reversed from its file....
    glyph_conversion_failed: bool;  // The most recent call to convert_to_temporary_glyphs() found a character it didn't know.
    glyph_index_for_unknown_character: u32;
    utf32_for_unknown_character := 0xfffd;  // This is Unicode 'REPLACEMENT CHARACTER'.

    features: [..] Font_Feature;

    feature_smallcaps:      *Font_Feature;
    feature_ligatures:      *Font_Feature;
    feature_lining_numbers: *Font_Feature;

    temporary_glyphs: [..] *Glyph_Data;
    temporary_glyphs_byte_offsets: [..] int;
    temporary_glyphs_width_in_pixels: s64;

    temporary_glyphs.allocator              = __temporary_allocator;
    temporary_glyphs_byte_offsets.allocator = __temporary_allocator;

    // draw_quads_proc := default_draw_quads_proc;
    current_quads: [..] Font_Quad;
}


Font_Page :: struct {
    texture:       Texture;
    bitmap_data:   *Bitmap;  // @Cleanup: Not a pointer.

    line_cursor_y: s16;
    lines:         [..] *Font_Line;

    dirty := false;
};

Font_Line :: struct {
    page: *Font_Page;

    bitmap_cursor_x: s16;
    bitmap_cursor_y: s16;

    height: int;
};

Loaded_Font :: struct {
    name: string;
    face: FT_Face;
    data: [] u8;
};

Font_Range_Record :: struct {
    start, end: s32;
    start_coverage_index: s32;
};

Font_Coverage_Table :: struct {
    format: s64;

    glyphs: [] u16;   // If format 1.
    range_records: [] Font_Range_Record;  // If format 2.
};

Font_Lookup_Subtable :: struct {
    format: s64;
    coverage_table: *Font_Coverage_Table;

    delta_glyph_id: s64;     // If lookup type 1, table format 1
    glyphs: [] u16;          // If lookup type 1, table format 2
    sequence_table: [] Font_Sequence_Table_Entry;       // If lookup type 2, table format 1
};

Font_Sequence_Table_Entry :: struct {
    glyphs: [] u16;
};

Font_Lookup_Table :: struct {
    lookup_type:   s32;
    lookup_flags:  u32;

    subtables: [] Font_Lookup_Subtable;
};

Font_Feature :: struct {
    feature_tag: u32;
    feature_tables_pointer: *u8;
    expanded: bool;

    lookup_lists:  [] u16;
    lookup_tables: [] Font_Lookup_Table;
};



init_fonts :: (_page_size_x: s32 = -1, _page_size_y: s32 = -1) {
    assert(!fonts_initted);

    if (_page_size_x >= 0) || (_page_size_y >= 0) {
        assert(_page_size_x >= 64);
        assert(_page_size_y >= 64);
        page_size_x = _page_size_x;
        page_size_y = _page_size_y;
    }

    fonts_initted = true;

    error := FT_Init_FreeType(*ft_library);
    assert(!error);

    set_allocators(*glyph_and_line_pool);
    glyph_and_line_pool.memblock_size = 100 * size_of(Glyph_Data);
}

get_glyph_width_in_pixels :: (glyph: *Glyph_Data) -> s64 {
    if !glyph return 0;
    return glyph.advance;
}

destroy :: (font: *Loaded_Font) {
    // @Incomplete: Check features, current_quads, etc.
    free(font.name.data);
}


is_latin :: (utf32: u32) -> bool {
    if utf32 > 0x24F {  // 0x24F is the end of Latin Extended-B
        if (utf32 >= 0x2000) && (utf32 <= 0x218F) {  // General punctuation, currency symbols, number forms, etc.
        } else {
            return false;
        }
    }

    return true;
}

find_loaded_font :: (filename: string) -> *Loaded_Font {
    for loaded_file_fonts {
        if it.name == filename return it;
    }

    return null;
}

make_loaded_font :: (name: string, data: [] u8) -> *Loaded_Font {
    face: FT_Face;

    error := FT_New_Memory_Face(ft_library, data.data, cast(s32) data.count,
                                0, *face);
    assert(error != xx FT_Err.Unknown_File_Format);
    assert(!error);

    if error return null;

    loaded_font := New(Loaded_Font);
    loaded_font.name = copy_string(name);
    loaded_font.face = face;
    loaded_font.data = data;

    return loaded_font;
}

make_loaded_font :: (filename: string) -> (font: *Loaded_Font) {
    s, success := read_entire_file(filename);
    if !success return null;

    loaded := make_loaded_font(filename, cast([] u8) s);
    array_add(*loaded_file_fonts, loaded);

    return loaded;
}

ensure_fonts_are_initted :: () {
    if !fonts_initted init_fonts();
}

// @Refactor: Factor this together with add_glyph_to_temporaries?
get_character_width_in_pixels :: (using font: *Dynamic_Font, utf8: *u8, effect_flags: Font_Effects) -> u32 {
    mark := get_temporary_storage_mark();
    defer   set_temporary_storage_mark(mark);

    glyph := find_or_create_glyph_utf8(font, utf8);
    if !glyph return 0;

    temporary_array_reset(*font.temporary_glyphs);
    temporary_array_reset(*font.temporary_glyphs_byte_offsets);
    assert(font.temporary_glyphs.count == font.temporary_glyphs_byte_offsets.count);

    assert(glyph != null);

    array_add(*font.temporary_glyphs, glyph);
    array_add(*font.temporary_glyphs_byte_offsets, -1);
    assert(font.temporary_glyphs.count == font.temporary_glyphs_byte_offsets.count);

    if effect_flags do_glyph_substitutions(font, effect_flags);

    return cast(u32) font.temporary_glyphs[0].advance;
}


accumulate_glyphs_from_font :: (source: *Dynamic_Font, dest: *Dynamic_Font) {
    for source.temporary_glyphs {
        array_add(*dest.temporary_glyphs, it);
        array_add(*dest.temporary_glyphs_byte_offsets, -1);
    }
}

convert_to_temporary_glyphs :: (using font: *Dynamic_Font, s: string, effect_flags: Font_Effects) {  // XXX using
    glyph_conversion_failed = false;

    temporary_array_reset(*font.temporary_glyphs);
    temporary_array_reset(*font.temporary_glyphs_byte_offsets);

    if latin_font {
        temporary_array_reset(*latin_font.temporary_glyphs);
        temporary_array_reset(*latin_font.temporary_glyphs_byte_offsets);
    }

    temporary_glyphs_width_in_pixels = 0;

    if !s return;

    original_string := s;
    sum := 0;

    all_latin := true;
    if !original_string.data  all_latin = false;  // Don't bother xreffing to latin font if the string is empty.

    t := s.data;
    while t < s.data + s.count {
        t_str: string;
        t_str.data = t;
        t_str.count = 1;
        utf32 := one_utf32_char(t);

        latin := is_latin(utf32);

        use_latin_font_for_this_character := false;

        glyph: *Glyph_Data;

        /* Temporarily disabled; re-enable when we want international support.
           Update 4 August 2016: Acutally I did a heavy revamp of the C++ code for The Witness
           to use Harfbuzz etc for international support. When we want to beef this up, we should
           re-port that because it works pretty differently.  -jblow, 4 August 2016.

        if (latin && use_other_font_for_latin_always) {
            if (latin_font.num_temporary_glyphs) {
                if utf32 == 32 {
                    // If it's the space at the end of Latin characters, don't do it!
                    // Umm, we don't try to look through multiple trailing spaces right now.
                    char *t = (char *)unicode.next_character((UTF8s *)s);
                    unsigned long next = one_utf32_char(t);
                    if is_latin(next) use_latin_font_for_this_character = true;
                } else {
                    // We already have a run of Latin characters, so let's do it.
                    use_latin_font_for_this_character = true;
                }
            } else {
                // Can only start a run of Latin characters with alphanumerics or quotes, for now.
                // The reason is that e.g. Chinese wants to use ? and ! in its own formatting.
                if ((utf32 >= 'A') && (utf32 <= 'Z')) use_latin_font_for_this_character = 1;
                if ((utf32 >= 'a') && (utf32 <= 'z')) use_latin_font_for_this_character = 1;
                if ((utf32 >= '0') && (utf32 <= '9')) use_latin_font_for_this_character = 1;
                if (utf32 == '\'') use_latin_font_for_this_character = 1;
                if (utf32 == '\"') use_latin_font_for_this_character = 1;
            }
        }
        */

        if use_latin_font_for_this_character {
            glyph = find_or_create_glyph_utf8(latin_font, t);
            if glyph {
                add_glyph_to_temporaries(latin_font, glyph, t - s.data);
            }

            // We put the glyph into the latin_font, then null it out so that
            // we don't put it into our own buffer.  The reason is that we want
            // the Latin font to apply font effects / substitutions / etc by
            // its own means, and then copy the results of that into our buffer.
            // If we were to copy it now, it'd be too soon.

            glyph = null;
        } else {
            if latin_font flush_my_latin_font(font, effect_flags);
            glyph = find_or_create_glyph_utf8(font, t);
        }


        if glyph {
            add_glyph_to_temporaries(font, glyph, t - s.data);

            if !latin all_latin = false;
        }

        t = unicode_next_character(t);
    }

    if latin_font && all_latin && !use_other_font_for_latin_always {
        //
        // Whoops!  Instead, let's use the latin font's glyphs.
        //

        convert_to_temporary_glyphs(latin_font, original_string, effect_flags);
        temporary_glyphs.count = 0;
        temporary_glyphs_byte_offsets.count = 0;
        flush_my_latin_font(font, effect_flags);

        return;
    }

    if effect_flags do_glyph_substitutions(font, effect_flags);

    // If we had Latin characters at the end of e.g. Chinese, we need to flush.
    if (latin_font) flush_my_latin_font(font, effect_flags);
}


// @Refactor: Didn't our add_glyph_to_temporaries just compute this width anyway? Why are we doing it again?
get_string_width_in_pixels :: (using font: *Dynamic_Font, s: string, effect_flags: Font_Effects = 0) -> s64 #deprecated "Use prepare_text instead." {
	if !font return 0;
    convert_to_temporary_glyphs(font, s, effect_flags);  // XXX Overload

    sum : s64 = 0;
    for temporary_glyphs
        sum += get_glyph_width_in_pixels(it);

    return sum;
}

set_unknown_character :: (using font: *Dynamic_Font, utf32: u32) -> bool {
    index := FT_Get_Char_Index(font.private1, utf32);
    if !index return false;

    glyph_index_for_unknown_character = index;
    return true;
}

load_font :: (path: string, basename: string, pixel_height: int) -> font: *Dynamic_Font {
    inline ensure_fonts_are_initted();

    result := New(Dynamic_Font);
    result.name = copy_string(basename);  // A waste?

    font_name := tprint("%/%", path, basename);

    loaded_font := find_loaded_font(font_name);
    bytes_loaded: s64 = 0;

    if !loaded_font {
        loaded_font = make_loaded_font(font_name);
        if !loaded_font return null;
    }

    load_font_part_2(result, <<loaded_font, pixel_height);
    return result;
}

load_font_part_2 :: (result: *Dynamic_Font, loaded_font: Loaded_Font, pixel_height: int) {
    face := loaded_font.face;

    success := FT_Set_Pixel_Sizes(face, 0, xx pixel_height);

    result.private1 = face;
    result.character_height = pixel_height;

    y_scale_font_to_pixels := face.size.metrics.y_scale/(64.0*65536.0);
    result.default_line_spacing = cast(int) floor(y_scale_font_to_pixels * face.height + 0.5);
    result.max_ascender  = cast(int) floor(y_scale_font_to_pixels * face.bbox.yMax + 0.5);  // Is this stuff different from FT_ROUND?
    result.max_descender = cast(int) floor(y_scale_font_to_pixels * face.bbox.yMin + 0.5);

    // We intentionally don't use the max ascender, because
    // it doesn't tend to look right. So we use 'm'... but for
    // Chinese, for example, this is going to be wrong, so maybe
    // this is @Incomplete and we need to have multiple options.

    glyph_index := FT_Get_Char_Index(face, #char "m");
    if glyph_index {
        FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT);
        result.y_offset_for_centering = xx (0.5 * FT_ROUND(face.glyph.metrics.horiBearingY) + 0.5);
    }

    glyph_index  = FT_Get_Char_Index(face, #char "M");
    if glyph_index {
        FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT);
        result.em_width = FT_ROUND(face.glyph.metrics.width);
    }

    glyph_index  = FT_Get_Char_Index(face, #char "T");
    if glyph_index {
        FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT);
        result.typical_ascender = FT_ROUND(face.glyph.metrics.horiBearingY);
    }

    glyph_index  = FT_Get_Char_Index(face, #char "g");
    if glyph_index {
        FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT);
        result.typical_descender = FT_ROUND(face.glyph.metrics.horiBearingY - face.glyph.metrics.height);
    }

    e := FT_Select_Charmap(face, .UNICODE);

    {
        success := set_unknown_character(result, 0xfffd);  // REPLACEMENT_CHARACTER
        if !success  success = set_unknown_character(result, 0x2022);  // BULLET
        if !success  success = set_unknown_character(result, #char "?");
        if !success {
            log_error("Unable to set unknown character for font '%1'.\n", basename);
        }
    }

    font := result;

    while 1 {
        length : FT_ULong = 0;
        tag := TTAG_GSUB;

        error := FT_Load_Sfnt_Table(face, tag, 0, null, *length);
        if error break;  // Not reall an error since not having a GSUB table is okay actually.

        buffer := alloc(cast(s64) length);
        defer free(buffer);
        if !buffer break;

        error = FT_Load_Sfnt_Table(face, tag, 0, buffer, *length);
        if (error) break;

        reversed := false;
        value := read4_from_offset(buffer, 0, reversed);

        if value == 0x00000100 {
            reversed = true;
        } else if value != 0x00010000 {
            break;
        }

        result.reversed = reversed;

        script_offset  := read2_from_offset(buffer, 4, reversed);
        feature_offset := read2_from_offset(buffer, 6, reversed);
        lookup_offset  := read2_from_offset(buffer, 8, reversed);

        //
        // Feature tables...
        //

        feature_list_table := buffer + feature_offset;
        num_feature_tables := cast(s32) read2_from_offset(feature_list_table, 0, reversed); // This must be signed since we do a -1 that can go below 0!

        {
            for 0..num_feature_tables-1 {
                dest : Font_Feature;
                dest.feature_tag = read4_from_offset(feature_list_table, 2 + xx it * 6, reversed);
                offset := read2_from_offset(feature_list_table, 6 + xx it * 6, reversed);
                dest.feature_tables_pointer = feature_list_table + offset;

                array_add(*font.features, dest);
            }
        }


        lookup_list_table := buffer + lookup_offset;

        font.feature_smallcaps = find_feature(font, "smcp");
//        font.feature_ligatures = find_feature(font, "liga");
        font.feature_lining_numbers = find_feature(font, "lnum");

        // feature_gpos := find_feature(font, "gpos");

        expand_feature(font, font.feature_smallcaps, lookup_list_table);
        expand_feature(font, font.feature_lining_numbers, lookup_list_table);
//        font.expand_feature(font.feature_ligatures, lookup_list_table);

        break;
    }

    array_add(*dynamic_fonts, result);
}

get_font_at_size :: (path: string, name: string, pixel_height: int) -> *Dynamic_Font {
    inline ensure_fonts_are_initted();

    for dynamic_fonts {
        if (it.character_height != pixel_height) continue;
        if (it.name != name) continue;

        return it;
    }

    result := load_font(path, name, pixel_height);
    if !result {
        log_error("Unable to load font '%1' from '%2'. Returning null.\n", name, path);
    }

    return result;
}

get_font_at_size :: (memory: [] u8, pixel_height: int) -> *Dynamic_Font {
    result := New(Dynamic_Font);

    loaded: *Loaded_Font;
    for loaded_memory_fonts {  // @Speed: Could use a hash table here!
        if (it.data.count == memory.count) && (it.data.data == memory.data) {
            loaded = it;
            break;
        }
    }

    if !loaded {
        loaded = make_loaded_font("", memory);
        array_add(*loaded_memory_fonts, loaded);
    }

    load_font_part_2(result, << loaded, pixel_height);
    return result;
}

release_font :: (font: *Dynamic_Font) {
    // Currently we do nothing. Probably we will want to do something here.
}

get_baseline_height :: (font: *Dynamic_Font) -> s64 {
    return font.character_height / 4;
}

prepare_text :: (font: *Dynamic_Font, text: string, effect_flags: Font_Effects = 0) -> (width: s64) {
    convert_to_temporary_glyphs(font, text, effect_flags);
    return font.temporary_glyphs_width_in_pixels;
}

generate_quads_for_prepared_text :: (font: *Dynamic_Font,
                                     x: s64, y: s64,
                                     effect_flags: Font_Effects) {
    assert(font != null);

    array_reset_keeping_memory(*font.current_quads);
    array_reserve(*font.current_quads, font.temporary_glyphs.count);

    maybe_offset := false;
    if font.y_offset_for_my_latin_characters maybe_offset = true;

    sx := cast(float) x;
    sy := cast(float) y;

    // @Speed!
    for info: font.temporary_glyphs {
        if !info.page continue;
        map := *info.page.texture;

        sx1 := sx  + cast(float) info.offset_x;
        sx2 := sx1 + cast(float) info.width;

        sy2 := sy  + cast(float) info.ascent;
        sy1 := sy2 - cast(float) info.height;

        if maybe_offset && is_latin(info.utf32) {
            // e.g. our Chinese font did not seem to make characters
            // line up properly.
            sy1 += font.y_offset_for_my_latin_characters;
            sy2 += font.y_offset_for_my_latin_characters;
        }

        quad: Font_Quad = ---;
        quad.glyph = info;
        quad.p0.x  = sx1;
        quad.p1.x  = sx2;
        quad.p2.x  = sx2;
        quad.p3.x  = sx1;
        quad.p0.y  = sy1;
        quad.p1.y  = sy1;
        quad.p2.y  = sy2;
        quad.p3.y  = sy2;

        quad.u0 = info.x0 / cast(float) map.width;
        quad.u1 = (cast(float) info.x0 + info.width) / map.width;
        quad.v0 = info.y0 / cast(float) map.height;
        quad.v1 = (cast(float) info.y0 + info.height) / map.height;

        array_add(*font.current_quads, quad);
		sx += cast(float) info.advance;

    }
}

#scope_file

ft_library    : FT_Library;
fonts_initted := false;

// We probably should make different page sizes
// for different fonts.
page_size_x := 2048;
page_size_y := 1024;

// Wacky structures used in the font file format.

loaded_file_fonts   : [..] *Loaded_Font;
loaded_memory_fonts : [..] *Loaded_Font;
font_pages    : [..] *Font_Page;
dynamic_fonts : [..] *Dynamic_Font;

glyph_and_line_pool : Pool;

DUMMY_SOURCE_LENGTH :: 1000;  // This is stupid.

find_line_within_page :: (page: *Font_Page, width: int, height: int) -> *Font_Line {
    bitmap := page.bitmap_data;

    for page.lines {
        if it.height < height continue;  // Line too short!
        if ((it.height * 7) / 10) > height continue;  // Line too tall!

        if bitmap.width - it.bitmap_cursor_x < width continue;  // No room at end of line!

        return it;  // Found one!
    }

    // If there's not enough room to start a new line, bail.
    height_remaining := bitmap.height - page.line_cursor_y;
    if height_remaining < height return null;

    // Or if for some reason the page is too narrow for the character...
    // In this case, starting a new line would not help!
    if bitmap.width < width return null;

    // Start a new line... With some extra space for expansion if we have room.
    desired_height := (height * 11) / 10;

    if desired_height > height_remaining desired_height = height_remaining;

    line : *Font_Line = get(*glyph_and_line_pool, size_of(Font_Line));
    if !line return null;

    line.page = page;
    line.bitmap_cursor_x = 0;
    line.bitmap_cursor_y = page.line_cursor_y;
    line.height = desired_height;

    array_add(*page.lines, line);

    page.line_cursor_y += cast(s16) desired_height;

    return line;
}

// @Speed: Font Pages should probably be tightly packed, not a bunch of pointers.
make_font_page :: () -> *Font_Page {
    page := New(Font_Page);

    bitmap := New(Bitmap);
    // @Speed: Make the bitmap R8!
    bitmap_alloc(bitmap, xx page_size_x, xx page_size_y, .RGBA8);
    page.bitmap_data = bitmap;

    return page;
}

get_font_line :: (width: int, height: int) -> *Font_Line {
    for page : font_pages {
        line := find_line_within_page(page, width, height);
        if line return line;
    }

    page := make_font_page();
    if !page return null;

    array_add(*font_pages, page);

    return find_line_within_page(page, width, height);  // If we didn't find it somehow, we lose!
}

copy_glyph_to_bitmap :: (face: FT_Face, data: *Glyph_Data) {
    b := *face.glyph.bitmap;

/*
    print_offset(type_info(FT_GlyphSlotRec), "advance");
    print_offset(type_info(FT_GlyphSlotRec), "format");
    print_offset(type_info(FT_GlyphSlotRec), "bitmap");

    printf("b.width %d, b.rows %d\n", b.width, b.rows);
*/

    data.width  = b.width;
    data.height = b.rows;
    data.advance = cast,trunc(s16) (face.glyph.advance.x >> 6);   // @Cleanup: reduce the number of casts?
    data.offset_x = cast,trunc(s16) face.glyph.bitmap_left;
    data.offset_y = cast,trunc(s16) face.glyph.bitmap_top;

    metrics := *face.glyph.metrics;
    data.ascent = cast,trunc(s16) (metrics.horiBearingY >> 6);  // This trunc seemed necessary because at least one font gave us weird data here. Maybe it's a buggy font, or maybe we are doing something weird / dumb.

    font_line := get_font_line(b.width, b.rows);
    if !font_line {
        // Fail! ... They get kind-of garbage.
        data.x0 = 0;
        data.y0 = 0;
        log_error("font_line is null!\n");
        assert(false);
        data.page = null;
        return;
    }

    dest_x := font_line.bitmap_cursor_x;
    dest_y := font_line.bitmap_cursor_y;

    data.x0 = dest_x;
    data.y0 = dest_y;
    data.page = font_line.page;

    bitmap := font_line.page.bitmap_data;

    rows  := cast(s32) b.rows; // FreeType has changed the rows and width types to unsigned, and they may be zero
    width := cast(s32) b.width;
    for j : 0..rows-1 {
        for i : 0..width-1 {
            source_pixel := b.buffer[(rows - 1 - j) * b.pitch + i];

            dest_pixel := bitmap.data.data + ((dest_y + j) * bitmap.width + (dest_x + i)) * 4;
            dest_pixel[0] = 255;
            dest_pixel[1] = 255;
            dest_pixel[2] = 255;
            dest_pixel[3] = source_pixel;
        }
    }

    font_line.bitmap_cursor_x += cast(s16) b.width;
    font_line.page.dirty = true;
}

// @Hack XXXXXXXXXX Major Hack... we don't know how to convert glyph IDs to utf32, so for now we store some glyphs by negative-glyph-index in the hash table.  These may be dupes of entries we already have in there as utf32.  We ought to fix this!

find_or_create_glyph :: (using font: *Dynamic_Font,
                         utf32: u32, glyph_index: u32, hash_key: int) -> *Glyph_Data {

    data, success := table_find(*font.glyph_lookup, hash_key);
    if success  return data;

    face := font.private1;  // XXX Why not using?

    // @Move: Make this happen at font construction time.  @Speed.
    // However we can't right now, because we share this face among
    // multiple Dynamic_Fonts...

    error := FT_Set_Pixel_Sizes(face, 0, cast(u32) font.character_height);    // XXX WHy not using?
    assert(!error);


    if utf32 {
        glyph_index = FT_Get_Char_Index(face, utf32);
        if !glyph_index {
            log_error("Unable to find a glyph in font '%' for utf32 character %.\n", font.name, utf32);
            glyph_index = glyph_index_for_unknown_character;
            // print("assigning glyph_index %\n", glyph_index);
        }

        if glyph_index {
            error := FT_Load_Glyph(face, glyph_index, FT_LOAD_RENDER);
            assert(!error);
        }
    } else {
        assert(glyph_index >= 0);
        FT_Load_Glyph(face, glyph_index, FT_LOAD_RENDER);
        return null;
    }

    data = cast(*Glyph_Data) get(*glyph_and_line_pool, size_of(Glyph_Data));
    data.utf32 = utf32;
    data.glyph_index_within_font = glyph_index;

    copy_glyph_to_bitmap(face, data);

    table_add(*font.glyph_lookup, hash_key, data);

    return data;
}

find_or_create_glyph :: (font: *Dynamic_Font, utf32: u32) -> *Glyph_Data {
    return find_or_create_glyph(font, utf32, 0, utf32);
}

one_utf32_char :: inline (s: *u8) -> u32 {
    utf32 := character_utf8_to_utf32(s, DUMMY_SOURCE_LENGTH);  // @BufferLength @Robustness
    return utf32;
} @NoProfile

find_or_create_glyph_utf8 :: (font: *Dynamic_Font, utf8: *u8) -> *Glyph_Data {  // XXX Overloading
    utf32 := one_utf32_char(utf8);
    return find_or_create_glyph(font, utf32);
}

prepare_for_kerning :: (using font: *Dynamic_Font) {
    face := font.private1;   // XXX Why not using?

    // We have to set the size because a different-sized Dynamic_Font, using
    // the same FT_Face, might have changed the size to kern or render glyphs.
    // Instead of having a manually-called function like this, we could cache
    // which Dynamic_Font last called FT_Set_Pixel_Sizes, storing this on the
    // Loaded_Font, and then set it dynamically from places like get_kerning().

    error := FT_Set_Pixel_Sizes(face, 0, cast(u32) font.character_height);   // XXX Why not using?
    assert(!error);
}

get_kerning :: (using font: *Dynamic_Font, prior: *Glyph_Data, current: *Glyph_Data, kerning_offset: *Vector2) {  // XXX Out parameter should become a return value.
    if (!prior) {
        kerning_offset.x = 0;
        kerning_offset.y = 0;
        return;
    }

    face := font.private1;  // XXX Why not using?
    has_kerning := FT_HAS_KERNING(face);

    index_left  := prior.glyph_index_within_font;
    index_right := current.glyph_index_within_font;

    kerning_mode := cast(u32) FT_Kerning_Mode.DEFAULT;

    // @Speed: Is FT_Set_Pixel_Sizes slow?  Do we want to do something about this?
//    int error;
//    error = FT_Set_Pixel_Sizes(face, 0, character_height);
//    assert(!error);


    kerning: FT_Vector;
    error := FT_Get_Kerning(face, index_left, index_right,
                            kerning_mode, *kerning);

    if error {
        kerning_offset.x = 0;
        kerning_offset.y = 0;
    } else {
        kerning_offset.x = cast(float) (kerning.x >> 6);
        kerning_offset.y = cast(float) (kerning.y >> 6);
    }
}



get_index_within_format_1_coverage_table :: (table: *Font_Coverage_Table, glyph: *Glyph_Data) -> s64 {
    // @Cleanup: This whole proc can be replaced by a generic array find.

    for table.glyphs
        if it == glyph.glyph_index_within_font
            return it_index;

    return -1;
}

get_index_within_format_2_coverage_table :: (table: *Font_Coverage_Table, glyph: *Glyph_Data) -> s64 {
    glyph_id := cast(s32) glyph.glyph_index_within_font;  // Because record.* are s32... sigh.

    for table.range_records {
        if glyph_id < it.start continue;
        if glyph_id > it.end continue;

        delta := glyph_id - it.start;
        return it.start_coverage_index + delta;
    }

    return -1;
}

get_index_within_coverage_table :: (table: *Font_Coverage_Table, glyph: *Glyph_Data) -> s64 {
    if table.format == 1 return get_index_within_format_1_coverage_table(table, glyph);
    if table.format == 2 return get_index_within_format_2_coverage_table(table, glyph);

    assert(false);

    return -1;
}

single_substitute :: (using font: *Dynamic_Font, feature: *Font_Feature,
                      orig: *Glyph_Data) -> *Glyph_Data {

    if !feature return orig;

    orig_utf32 := orig.utf32;

    for * table : feature.lookup_tables {  // XXX Array simplify

        for * subtable : table.subtables {
            index := get_index_within_coverage_table(subtable.coverage_table, orig);
            if index == -1 return orig;

            if table.lookup_type == 1 {
                if subtable.format == 1 {  // SingleSubstFormat1
                    glyph_id := orig.glyph_index_within_font + cast(u32) subtable.delta_glyph_id;
                    new_glyph := find_or_create_glyph(font, 0, glyph_id, glyph_id_to_hash_key(glyph_id));
                    if !new_glyph return null;

                    new_glyph.utf32 = orig_utf32;
                    return new_glyph;
                } else if subtable.format == 2 {  // SingleSubstFormat2
                    assert(index < subtable.glyphs.count);

                    glyph_id := subtable.glyphs[index];
                    new_glyph := find_or_create_glyph(font, 0, glyph_id, glyph_id_to_hash_key(glyph_id));
                    if !new_glyph return null;

                    new_glyph.utf32 = orig_utf32;
                    return new_glyph;
                } else {
                    assert(false);
                }
            }

            if table.lookup_type == 2 {
                entry := *subtable.sequence_table[index];

                glyph_id := entry.glyphs[0];
                new_glyph := find_or_create_glyph(font, 0, glyph_id, glyph_id_to_hash_key(glyph_id));
                if !new_glyph return null;

                //
                // @Hack: If for some reason there was more than 1 glyph in this table,
                // we just use the first one... for now we are just using this for
                // SmallCaps so it should not be a big deal.
                //
                new_glyph.utf32 = orig_utf32;
                return new_glyph;
            }
        }
    }

    return orig;
}

// WRONG: It's not byte_offset, it's an index? Fix me!
// ACTUALLY, temporary_glyphs_byte_offsets seems to be completely unused. Delete it?
add_glyph_to_temporaries :: inline (font: *Dynamic_Font, glyph: *Glyph_Data, byte_offset: int) {
    assert(glyph != null);

    assert(font.temporary_glyphs.count == font.temporary_glyphs_byte_offsets.count);
    array_add(*font.temporary_glyphs, glyph);
    array_add(*font.temporary_glyphs_byte_offsets, byte_offset);
    assert(font.temporary_glyphs.count == font.temporary_glyphs_byte_offsets.count);

    font.temporary_glyphs_width_in_pixels += glyph.advance;

    //
    // FreeType returns glyph index 0 for undefined glyphs... just signal
    // the condition that this happened.
    //

    if glyph.glyph_index_within_font == 0 font.glyph_conversion_failed = true;
}

flush_my_latin_font :: (font: *Dynamic_Font, effect_flags: Font_Effects) {
    // Flush any latin characters in the Latin font back into the non-latin Font...

    latin_font := font.latin_font;
    assert(latin_font != null);

    if !latin_font.temporary_glyphs.count return;

    do_glyph_substitutions(latin_font, effect_flags);
    accumulate_glyphs_from_font(latin_font, font);
    latin_font.temporary_glyphs.count = 0;
    latin_font.temporary_glyphs_byte_offsets.count = 0;
}



do_glyph_substitutions :: (using font : *Dynamic_Font, effect_flags: Font_Effects) {
    if effect_flags & .LINING_FIGURES {
        // Substitute lining figures...
        for * ptr : temporary_glyphs {
            glyph := << ptr;
            << ptr = single_substitute(font, feature_lining_numbers, glyph);
        }
    }

    if effect_flags & .SMALLCAPS {
        // Substitute smallcaps...
        for * ptr : temporary_glyphs {
            // @Hack for Karmina; if we have LINING_FIGURES and SMALLCAPS selected,
            // then just do lining figures if it's a digit... otherwise we end
            // up converting digits to smallcaps and that doesn't look right.

            glyph := << ptr;
            if effect_flags & .LINING_FIGURES {
                utf32 := glyph.utf32;
                if ((utf32 < 127) && isdigit(utf32)) continue;
            }

            sub := single_substitute(font, feature_smallcaps, glyph);
            if sub { << ptr = sub; }
        }
    }
}

read4_from_offset :: /* inline */ (base: *u8, offset: s64, reversed: bool) -> u32 #expand {  // Would like to inline, but, can't due to #asm in byte_swap.
    ptr := cast(*u32) (base + offset);

    if reversed {
        return byte_swap(<< ptr);
    } else {
        return << ptr;
    }
}

read2_from_offset :: /* inline */ (base: *u8, offset: s64, reversed: bool) -> u16 {  // Would like to inline, but, can't due to #asm in byte_swap.
    ptr := cast(*u16) (base + offset);

    if reversed {
        return byte_swap(<< ptr);
    } else {
        return << ptr;
    }
}

find_feature :: (using font: *Dynamic_Font, feature_label: string) -> *Font_Feature {
    s0 : u32 = feature_label[0];
    s1 : u32 = feature_label[1];
    s2 : u32 = feature_label[2];
    s3 : u32 = feature_label[3];

    tag := s3 | (s2 << 8) | (s1 << 16) | (s0 << 24);

    for * features  if it.feature_tag == tag return it;

    return null;
}

read_coverage_table :: (coverage_table: *u8, reversed: bool) -> *Font_Coverage_Table {
    format := read2_from_offset(coverage_table, 0, reversed);

    result := New(Font_Coverage_Table);
    result.format = format;

    if format == 1 {
        num_glyphs := read2_from_offset(coverage_table, 2, reversed);

        glyphs := NewArray(num_glyphs, u16);
        if !glyphs.data return null;

        for 0..num_glyphs-1 {
            glyphs[it] = read2_from_offset(coverage_table + 4, xx it * 2, reversed);
        }

        result.glyphs = glyphs;
    } else if format == 2 {
        num_records := read2_from_offset(coverage_table, 2, reversed);
        result.range_records = NewArray(num_records, Font_Range_Record);

        for * result.range_records {
            i := it_index;

            it.start = read2_from_offset(coverage_table, 4 + i * 6, reversed);
            it.end = read2_from_offset(coverage_table, 6 + i * 6, reversed);
            it.start_coverage_index = read2_from_offset(coverage_table, 8 + i * 6, reversed);
        }
    }

    return result;
}

read_sequence_table_entry :: (result: *Font_Sequence_Table_Entry, sequence_table: *u8, reversed: bool) {
    num_glyphs := read2_from_offset(sequence_table, 0, reversed);

    result.glyphs = NewArray(num_glyphs, u16, false);
    if !result.glyphs.data return;

    for 0..num_glyphs-1
        result.glyphs[it] = read2_from_offset(sequence_table + 2, cast(s64) it * 2, reversed);
}

expand_feature :: (using font: *Dynamic_Font, feature: *Font_Feature, lookup_list_table: *u8) {
    if !feature return;
    if feature.expanded return;

    feature.expanded = true;

    table := feature.feature_tables_pointer;

    params_offset := read2_from_offset(table, 0, reversed);

    num_lookup_lists : s64 = read2_from_offset(table, 2, reversed);

    feature.lookup_lists = NewArray(num_lookup_lists, u16, false);

    for 0..num_lookup_lists-1 {
        index := 4 + it * 2;
        feature.lookup_lists[it] = read2_from_offset(table, index, reversed);
    }

    feature.lookup_tables = NewArray(num_lookup_lists, Font_Lookup_Table);

    //
    // Lookup tables...
    //

    num_lookups_max := read2_from_offset(lookup_list_table, 0, reversed);

    for 0..num_lookup_lists-1 {
        dest := *feature.lookup_tables[it];
        list_index := feature.lookup_lists[it];

        assert(list_index < num_lookups_max);

        offset := read2_from_offset(lookup_list_table + 2, 2 * list_index, reversed);

        table := lookup_list_table + offset;

        lookup_type    := read2_from_offset(table, 0, reversed);
        lookup_flags   := read2_from_offset(table, 2, reversed);
        subtable_count := read2_from_offset(table, 4, reversed);

        dest.lookup_type   = lookup_type;
        dest.lookup_flags  = lookup_flags;

        dest.subtables = NewArray(subtable_count, Font_Lookup_Subtable);
        for * sub_dest : dest.subtables {
            offset := 6 + it_index * 2;
            subtable_offset := read2_from_offset(table, offset, reversed);

            subtable   := table + subtable_offset;
            table_type := read2_from_offset(subtable, 0, reversed);
            sub_dest.format = table_type;

            if lookup_type == 1 {  // Single Substitution Table
                coverage_offset := read2_from_offset(subtable, 2, reversed);
                coverage_table := subtable + coverage_offset;
                sub_dest.coverage_table = read_coverage_table(coverage_table, reversed);

                if table_type == 1 {  // SingleSubstFormat1
                    sub_dest.delta_glyph_id = read2_from_offset(subtable, 4, reversed);
                } else if table_type == 2 { // SingleSubstFormat2

                    count : s64 = read2_from_offset(subtable, 4, reversed);
                    sub_dest.glyphs = NewArray(count, u16);

                    for * sub_dest.glyphs {
                         << it = read2_from_offset(subtable, 6 + 2 * it_index, reversed);
                    }
                } else {
                    assert(false);
                }
            } else if lookup_type == 2 {  // Multiple Substitution Table
                coverage_offset := read2_from_offset(subtable, 2, reversed);
                sequence_count := read2_from_offset(subtable, 4, reversed);
                coverage_table := subtable + coverage_offset;

                sub_dest.coverage_table = read_coverage_table(coverage_table, reversed);
                sub_dest.sequence_table = NewArray(sequence_count, Font_Sequence_Table_Entry);

                for j : 0..sequence_count-1 {
                    sequence_offset := read2_from_offset(subtable + 6, cast(s64) j * 2, reversed);
                    sequence_table := subtable + sequence_offset;
                    read_sequence_table_entry(*sub_dest.sequence_table[j], sequence_table, reversed);
                }
            }
        }

        break;
    }
}


FT_ROUND :: inline (x: int) -> int {
    if x >= 0 return (x + 0x1f) >> 6;
    return -(((-x) + 0x1f) >> 6);
}

temporary_array_reset :: (array: *[..] $T) {
    array.count     = 0;
    array.allocated = 0;
    array.data      = null;
}



#scope_file

#import "freetype-2.12.1";
#import "Hash_Table";
#import "Hash";
#import "Unicode";
#import "Pool";
#import "File";
#import "Basic";  // For free.
#import "Math";  // For Vector2, Vector3, Vector4.

