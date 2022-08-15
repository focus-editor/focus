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
    face: FT_Face;
    glyph_lookup: Table(int, *Glyph_Data);

    character_range_low:  int;
    character_range_high: int;

    character_height:       int;
    default_line_spacing:   int;
    max_ascender:           int;
    max_descender:          int;
    typical_ascender:       int;
    typical_descender:      int;
    em_width:               int;

    y_offset_for_centering: int;

    glyph_conversion_failed: bool;  // The most recent call to convert_to_temporary_glyphs() found a character it didn't know.
    glyph_index_for_unknown_character: u32;

    temporary_glyphs: [..] *Glyph_Data;
    temporary_glyphs.allocator = temp;

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
    data: [] u8;
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

is_latin :: (utf32: u32) -> bool {
    if utf32 > 0x24F {  // 0x24F is the end of Latin Extended-B
        if (utf32 >= 0x2000) && (utf32 <= 0x218F) {  // General punctuation, currency symbols, number forms, etc.
        } else {
            return false;
        }
    }

    return true;
}

ensure_fonts_are_initted :: () {
    if !fonts_initted init_fonts();
}

convert_to_temporary_glyphs :: (font: *Dynamic_Font, s: string) -> width_in_pixels: s64 {
    font.glyph_conversion_failed = false;
    temporary_array_reset(*font.temporary_glyphs);

    if !s return 0;

    width_in_pixels := 0;

    t := s.data;
    while t < s.data + s.count {
        utf32 := character_utf8_to_utf32(t, s.data + s.count - t);
        glyph := find_or_create_glyph(font, utf32);

        if glyph {
            array_add(*font.temporary_glyphs, glyph);

            width_in_pixels += glyph.advance;

            // FreeType returns glyph index 0 for undefined glyphs... just signal
            // the condition that this happened.
            if glyph.glyph_index_within_font == 0 font.glyph_conversion_failed = true;
        }

        t = unicode_next_character(t);
    }

    return width_in_pixels;
}

set_unknown_character :: (font: *Dynamic_Font, utf32: u32) -> bool {
    index := FT_Get_Char_Index(font.face, utf32);
    if !index return false;

    font.glyph_index_for_unknown_character = index;
    return true;
}

load_font_part_2 :: (result: *Dynamic_Font, pixel_height: int) {
    face := result.face;

    success := FT_Set_Pixel_Sizes(face, 0, xx pixel_height);

    result.face = face;
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

    error := FT_Select_Charmap(face, .UNICODE);
    assert(!error, "Couldn't select unicode charmap for font %\n", result.name);

    {
        success := set_unknown_character(result, 0xfffd);  // REPLACEMENT_CHARACTER
        if !success  success = set_unknown_character(result, 0x2022);  // BULLET
        if !success  success = set_unknown_character(result, #char "?");
        if !success {
            log_error("Unable to set unknown character for font '%1'.\n", basename);
        }
    }

    array_add(*dynamic_fonts, result);
}

get_font_at_size :: (path: string, name: string, pixel_height: int) -> *Dynamic_Font {
    inline ensure_fonts_are_initted();

    // Try to find a previously loaded font
    for dynamic_fonts {
        if (it.character_height != pixel_height) continue;
        if (it.name != name) continue;

        return it;
    }

    // Load new font
    font_name := tprint("%/%", path, name);
    loaded: *Loaded_Font;
    for loaded_fonts {
        if it.name == font_name {
            loaded = it;
            break;
        }
    }
    if !loaded {
        // Load from file
        s, success := read_entire_file(font_name);
        if !success {
            print("Error: couldn't load font '%'\n", font_name);
            return null;
        }
        loaded = New(Loaded_Font);
        loaded.name = copy_string(name);
        loaded.data = cast([] u8) s;

        array_add(*loaded_fonts, loaded);
    }

    // Create a new font face for Dynamic_Font rather than sharing one between fonts.
    // The reason is because we don't want to keep changing the size every time we want to
    // do anything and worry whether another Dynamic_Font has changed the size
    face: FT_Face;
    error := FT_New_Memory_Face(ft_library, loaded.data.data, cast(s32) loaded.data.count, 0, *face);
    if error == xx FT_Err.Unknown_File_Format {
        print("Error: font file format not supported: '%'\n", font_name);
        return null;
    }
    if error {
        print("Error while loading font '%': %", font_name, error);
        return null;
    }

    result := New(Dynamic_Font);
    result.name = copy_string(name);
    result.face = face;
    load_font_part_2(result, pixel_height);
    return result;
    // TODO(ivan): finish this loading part, use float metrics if possible

    // face := loaded.face;

    // // Finish loading dynamic font for the requested size
    // font := New(Dynamic_Font);
    // font.name = copy_string(name);
    // font.face = face;
    // font.character_height = pixel_height;

    // y_scale_font_to_pixels := face.size.metrics.y_scale / (64.0 * 65536.0);
    // font.default_line_spacing = y_scale_font_to_pixels * face.height;
    // font.max_ascender         = y_scale_font_to_pixels * face.bbox.yMax;
    // font.max_descender        = y_scale_font_to_pixels * face.bbox.yMin;

    // // NOTE(Ivan): not sure how this offset was supposed to be used so don't fill it for now
    // // // We intentionally don't use the max ascender, because
    // // // it doesn't tend to look right. So we use 'm'... but for
    // // // Chinese, for example, this is going to be wrong, so maybe
    // // // this is @Incomplete and we need to have multiple options.

    // // glyph_index := FT_Get_Char_Index(face, #char "m");
    // // if glyph_index {
    // //     FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT);
    // //     result.y_offset_for_centering = xx (0.5 * FT_ROUND(face.glyph.metrics.horiBearingY) + 0.5);
    // // }

    // glyph_index := FT_Get_Char_Index(face, #char "M");
    // if glyph_index {
    //     FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT);
    //     result.em_width = FT_ROUND(face.glyph.metrics.width);
    // }

    // success := FT_Set_Pixel_Sizes(face, 0, xx pixel_height);

    // return font;
}

prepare_text :: (font: *Dynamic_Font, text: string) -> (width: s64) {
    width := convert_to_temporary_glyphs(font, text);
    return width;
}

generate_quads_for_prepared_text :: (font: *Dynamic_Font, x: s64, y: s64) {
    assert(font != null);

    array_reset_keeping_memory(*font.current_quads);
    array_reserve(*font.current_quads, font.temporary_glyphs.count);

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

loaded_fonts:  [..] *Loaded_Font;
dynamic_fonts: [..] *Dynamic_Font;
font_pages:    [..] Font_Page;

glyph_and_line_pool: Pool;

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

make_font_page :: () -> *Font_Page {
    page := array_add(*font_pages);

    bitmap := New(Bitmap);
    bitmap_alloc(bitmap, xx page_size_x, xx page_size_y, .R8);
    page.bitmap_data = bitmap;

    return page;
}

get_font_line :: (width: int, height: int) -> *Font_Line {
    for *page : font_pages {
        line := find_line_within_page(page, width, height);
        if line return line;
    }

    page := make_font_page();
    line := find_line_within_page(page, width, height);  // If we didn't find it somehow, we lose!
    assert(line != null, "Couldn't find a line for a character in a fresh font page. This is a bug.");

    return line;
}

copy_glyph_to_bitmap :: (face: FT_Face, data: *Glyph_Data) {
    b := *face.glyph.bitmap;

    data.width    = b.width;
    data.height   = b.rows;
    data.advance  = cast,trunc(s16) (face.glyph.advance.x >> 6);   // @Cleanup: reduce the number of casts?
    data.offset_x = cast,trunc(s16) face.glyph.bitmap_left;
    data.offset_y = cast,trunc(s16) face.glyph.bitmap_top;

    metrics := *face.glyph.metrics;
    data.ascent = cast,trunc(s16) (metrics.horiBearingY >> 6);  // This trunc seemed necessary because at least one font gave us weird data here. Maybe it's a buggy font, or maybe we are doing something weird / dumb.

    font_line := get_font_line(b.width, b.rows);

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
            dest_pixel := bitmap.data.data + ((dest_y + j) * bitmap.width + (dest_x + i));
            << dest_pixel = b.buffer[(rows - 1 - j) * b.pitch + i];
        }
    }

    font_line.bitmap_cursor_x += cast(s16) b.width;
    font_line.page.dirty = true;
}

find_or_create_glyph :: (using font: *Dynamic_Font, utf32: u32) -> *Glyph_Data {
    hash_key := utf32;

    data, success := table_find(*font.glyph_lookup, hash_key);
    if success  return data;

    glyph_index := FT_Get_Char_Index(face, utf32);
    if glyph_index {
        // error := FT_Load_Glyph(face, glyph_index, FT_LOAD_RENDER);
        error := FT_Load_Glyph(face, glyph_index, FT_LOAD_DEFAULT);
        assert(!error);
        FT_Render_Glyph(face.glyph, .FT_RENDER_MODE_LCD);
    } else {
        log_error("Unable to find a glyph in font '%' for utf32 character %.\n", name, utf32);
        glyph_index = glyph_index_for_unknown_character;
    }

    data = cast(*Glyph_Data) get(*glyph_and_line_pool, size_of(Glyph_Data));
    data.utf32 = utf32;
    data.glyph_index_within_font = glyph_index;

    copy_glyph_to_bitmap(face, data);

    table_add(*glyph_lookup, hash_key, data);

    return data;
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

#import "freetype-2.12.1";
#import "Hash_Table";
#import "Hash";
#import "Unicode";
#import "Pool";
#import "File";
#import "Math";   // For Vector2, Vector3, Vector4.
