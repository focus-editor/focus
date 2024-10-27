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
    glyph_lookup: Table(u64, *Glyph_Data);

    character_height:       int;
    default_line_spacing:   int;
    max_ascender:           int;
    max_descender:          int;
    typical_ascender:       int;
    typical_descender:      int;
    em_width:               int;
    x_advance:              int;

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

Code_Line :: struct {
    line:   string;
    start_offset: s32;
    tab_spaces: s32;
    tokens: [] u8;
}

Offset_Range :: struct {
    start, end: s32;
}

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

    use_kerning := FT_HAS_KERNING(font.face);
    prev_glyph: u32 = 0;

    width_in_pixels := 0;

    t := s.data;
    while t < s.data + s.count {
        utf32 := character_utf8_to_utf32(t, s.data + s.count - t);
        glyph := find_or_create_glyph(font, utf32);

        if glyph {
            array_add(*font.temporary_glyphs, glyph);

            width_in_pixels += glyph.advance;

            if use_kerning && prev_glyph {
                delta: FT_Vector = ---;
                error := FT_Get_Kerning(font.face, prev_glyph, glyph.glyph_index_within_font, xx FT_Kerning_Mode.DEFAULT, *delta);
                if !error then width_in_pixels += (delta.x >> 6);
            }

            // FreeType returns glyph index 0 for undefined glyphs... just signal
            // the condition that this happened.
            if glyph.glyph_index_within_font == 0 font.glyph_conversion_failed = true;

            prev_glyph = glyph.glyph_index_within_font;
        }

        t = unicode_next_character(t);
    }

    return width_in_pixels;
}

draw_code :: (font: *Dynamic_Font, x: s64, y: s64, char_x_advance: float, line_height: float, visible_lines: [] Code_Line, selections: [] Offset_Range = .[], tab_size: s64 = 4, start_col := 0, $is_colored := true) {
    // Setup OpenGL stuff. We do it all in one place because it's easier and there will be only one backend - GL.
    // Otherwise we would have to create temporary glyphs and pass them on to the backend draw function.
    CheckInit();
    set_shader_for_text();
    glBlendFunc(GL_SRC1_COLOR, GL_ONE_MINUS_SRC1_COLOR);
    glEnable(GL_BLEND);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, 0);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    last_texture: GLuint = 0xFFFFFFFF;

    character_is_selected :: inline (offset: s32, selections: [] Offset_Range) -> bool {
        for selections {
            if offset >= it.start && offset <= it.end return true;
        }
        return false;
    }

    sy := cast(float) y;

    // Draw all lines
    for visible_lines {
        line   := it.line;
        tokens := it.tokens;
        start_offset := it.start_offset;

        sx  := cast(float) (x + it.tab_spaces * char_x_advance);
        col := start_col + it.tab_spaces;

        // Draw one line
        t := line.data;
        while t < line.data + line.count {
            // Convert current char to glyph
            utf32 := character_utf8_to_utf32(t, line.data + line.count - t);
            glyph := find_or_create_glyph(font, utf32);
            assert(glyph != null, "find_or_create_glyph returned null");
            assert(glyph.page != null, "glyph has no font page");

            texture := *glyph.page.texture;
            if glyph.page.dirty {
                glyph.page.dirty = false;
                texture_load_from_bitmap(texture, glyph.page.bitmap_data);
            }

            if texture.gl_handle != last_texture {
                immediate_flush();
                last_texture = texture.gl_handle;

                shader := state.current_shader;
                loc := get_uniform_location(shader.gl_handle, "text_sampler");
                if loc < 0  log_error("Unable to find text_sampler in shader_text!");
                glActiveTexture(GL_TEXTURE0);
                glBindTexture(GL_TEXTURE_2D, texture.gl_handle);  // Bind handle to slot 0.
                glUniform1i(loc, 0);
            }

            // Draw glyph
            {
                x1 := sx + cast(float) glyph.offset_x;
                x2 := x1 + cast(float) glyph.width / (ifx font_anti_aliasing == .lcd then 3.0 else 1.0);

                y2 := sy + cast(float) glyph.ascent;
                y1 := y2 - cast(float) glyph.height;

                // Create quad
                quad: Font_Quad = ---;
                quad.glyph = glyph;
                quad.p0.x  = x1;
                quad.p1.x  = x2;
                quad.p2.x  = x2;
                quad.p3.x  = x1;
                quad.p0.y  = y1;
                quad.p1.y  = y1;
                quad.p2.y  = y2;
                quad.p3.y  = y2;

                quad.u0 = glyph.x0 / cast(float) texture.width;
                quad.u1 = (cast(float) glyph.x0 + glyph.width) / texture.width;
                quad.v0 = glyph.y0 / cast(float) texture.height;
                quad.v1 = (cast(float) glyph.y0 + glyph.height) / texture.height;

                #if is_colored {
                    token := tokens[t - line.data];
                    color := COLOR_MAP[token];
                } else {
                    color := COLOR_MAP[0];  // default
                }
                if utf32 != #char "\t" {
                    sx  += char_x_advance;
                    col += 1;
                } else {
                    // Tabs are wide
                    chars_to_tabstop := tab_size - col % tab_size;
                    sx  += chars_to_tabstop * char_x_advance;
                    col += chars_to_tabstop;
                    color = COLOR_MAP[0];  // always use default color

                    // Only draw tabs if they are within a selection
                    if character_is_selected(start_offset + cast(s32)(t - line.data), selections) {
                        color.w = 0.2;
                    } else {
                        color.w = 0.0;
                    }
                }
                immediate_letter_quad(quad, color);
            }

            t = unicode_next_character(t);
        }

        sy -= line_height;
    }

    immediate_flush();

    glDisable(GL_BLEND);
}

// @Copypasta: some GL copypasta present
// We represent highlights as an array of bools, which is wasteful but we don't care
draw_text_with_highlights :: (font: *Dynamic_Font, x: s64, y: s64, text: string, highlights: [] bool, color: u8, highlight_color: u8) -> width: s64 {
    if !text return 0;

    assert(text.count == highlights.count, "In Simp.draw_text_with_highlights, the text length doesn't match the highlight length");

    CheckInit();
    set_shader_for_text();
    glBlendFunc(GL_SRC1_COLOR, GL_ONE_MINUS_SRC1_COLOR);
    glEnable(GL_BLEND);
    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, 0);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    use_kerning := FT_HAS_KERNING(font.face);
    prev_glyph: u32 = 0;
    width_in_pixels := 0;

    last_texture: GLuint = 0xFFFFFFFF;

    color_vec4           := COLOR_MAP[color];
    highlight_color_vec4 := COLOR_MAP[highlight_color];

    sx := cast(float) x;
    sy := cast(float) y;

    t := text.data;
    while t < text.data + text.count {
        // Convert current char to glyph
        utf32 := character_utf8_to_utf32(t, text.data + text.count - t);
        glyph := find_or_create_glyph(font, utf32);
        assert(glyph != null, "find_or_create_glyph returned null");
        assert(glyph.page != null, "glyph has no font page");

        texture := *glyph.page.texture;
        if glyph.page.dirty {
            glyph.page.dirty = false;
            texture_load_from_bitmap(texture, glyph.page.bitmap_data);
        }

        if texture.gl_handle != last_texture {
            immediate_flush();
            last_texture = texture.gl_handle;

            shader := state.current_shader;
            loc := get_uniform_location(shader.gl_handle, "text_sampler");
            if loc < 0  log_error("Unable to find text_sampler in shader_text!");
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, texture.gl_handle);  // Bind handle to slot 0.
            glUniform1i(loc, 0);
        }

        // Draw glyph
        {
            if use_kerning && prev_glyph {
                delta: FT_Vector = ---;
                error := FT_Get_Kerning(font.face, prev_glyph, glyph.glyph_index_within_font, xx FT_Kerning_Mode.DEFAULT, *delta);
                if !error {
                    sx += cast(float) (delta.x >> 6);
                    width_in_pixels += (delta.x >> 6);
                }
            }

            x1 := sx + cast(float) glyph.offset_x;
            x2 := x1 + cast(float) glyph.width / (ifx font_anti_aliasing == .lcd then 3.0 else 1.0);

            y2 := sy + cast(float) glyph.ascent;
            y1 := y2 - cast(float) glyph.height;

            sx += cast(float) glyph.advance;

            width_in_pixels += glyph.advance;

            // Create quad
            quad: Font_Quad = ---;
            quad.glyph = glyph;
            quad.p0.x  = x1;
            quad.p1.x  = x2;
            quad.p2.x  = x2;
            quad.p3.x  = x1;
            quad.p0.y  = y1;
            quad.p1.y  = y1;
            quad.p2.y  = y2;
            quad.p3.y  = y2;

            quad.u0 = glyph.x0 / cast(float) texture.width;
            quad.u1 = (cast(float) glyph.x0 + glyph.width) / texture.width;
            quad.v0 = glyph.y0 / cast(float) texture.height;
            quad.v1 = (cast(float) glyph.y0 + glyph.height) / texture.height;

            immediate_letter_quad(quad, ifx highlights[t - text.data] then highlight_color_vec4 else color_vec4);
        }

        t = unicode_next_character(t);
        prev_glyph = glyph.glyph_index_within_font;
    }

    immediate_flush();

    glDisable(GL_BLEND);

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
        result.em_width  = FT_ROUND(face.glyph.metrics.width);
        result.x_advance = FT_ROUND(face.glyph.metrics.horiAdvance);
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
            log_error("Unable to set unknown character for font '%'.\n", basename);
        }
    }

    array_add(*dynamic_fonts, result);
}

get_font_at_size :: (name: string, font_data: string, pixel_height: int) -> *Dynamic_Font {
    inline ensure_fonts_are_initted();

    // Try to find a previously loaded font
    for dynamic_fonts {
        if (it.character_height != pixel_height) continue;
        if (it.name != name) continue;

        return it;
    }

    // Create a new font face for Dynamic_Font rather than sharing one between fonts.
    // The reason is because we don't want to keep changing the size every time we want to
    // do anything and worry whether another Dynamic_Font has changed the size
    face: FT_Face;
    error := FT_New_Memory_Face(ft_library, font_data.data, cast(s32) font_data.count, 0, *face);
    if error == xx FT_Err.Unknown_File_Format {
        print("Error: font file format not supported: '%'\n", name);
        return null;
    }
    if error {
        print("Error while loading font '%': %", name, error);
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

prepare_text :: (font: *Dynamic_Font, text: string) -> width: s64 {
    width := convert_to_temporary_glyphs(font, text);
    return width;
}

// Like prepare_text, but it doesn't create any temporary glyphs
// (useful for finding the cursor position within text)
get_text_width :: (font: *Dynamic_Font, s: string) -> width: s64 {
    if !s return 0;

    use_kerning := FT_HAS_KERNING(font.face);
    prev_glyph: u32 = 0;

    width_in_pixels := 0;

    t := s.data;
    while t < s.data + s.count {
        utf32 := character_utf8_to_utf32(t, s.data + s.count - t);
        glyph := find_or_create_glyph(font, utf32);

        if glyph {
            width_in_pixels += glyph.advance;

            if use_kerning && prev_glyph {
                delta: FT_Vector = ---;
                error := FT_Get_Kerning(font.face, prev_glyph, glyph.glyph_index_within_font, xx FT_Kerning_Mode.DEFAULT, *delta);
                if !error then width_in_pixels += (delta.x >> 6);
            }

            prev_glyph = glyph.glyph_index_within_font;
        }

        t = unicode_next_character(t);
    }

    return width_in_pixels;
}

get_cursor_pos_for_width :: (font: *Dynamic_Font, s: string, requested_width: s64) -> pos: s32 {
    if !s return 0;

    use_kerning := FT_HAS_KERNING(font.face);
    prev_glyph: u32 = 0;

    current_pos: s32 = 0;
    width_in_pixels := 0;

    t := s.data;
    while t < s.data + s.count {
        utf32 := character_utf8_to_utf32(t, s.data + s.count - t);
        glyph := find_or_create_glyph(font, utf32);

        glyph_width := 0;

        if glyph {
            glyph_width += glyph.advance;

            if use_kerning && prev_glyph {
                delta: FT_Vector = ---;
                error := FT_Get_Kerning(font.face, prev_glyph, glyph.glyph_index_within_font, xx FT_Kerning_Mode.DEFAULT, *delta);
                if !error then glyph_width += (delta.x >> 6);
            }
        }

        t = unicode_next_character(t);
        prev_glyph = glyph.glyph_index_within_font;

        width_in_pixels += glyph_width;
        if width_in_pixels >= requested_width {
            // If we're closer to the next glyph position, return the next position
            if (width_in_pixels - requested_width) <= (glyph_width / 2) then current_pos = xx (t - s.data);
            break;
        }

        current_pos = xx (t - s.data);
    }

    return current_pos;
}

generate_quads_for_prepared_text :: (font: *Dynamic_Font, x: s64, y: s64) {
    assert(font != null);

    array_reset_keeping_memory(*font.current_quads);
    array_reserve(*font.current_quads, font.temporary_glyphs.count);

    // @Speed: we don't need kerning for most of the text
    use_kerning := FT_HAS_KERNING(font.face);

    sx := cast(float) x;
    sy := cast(float) y;

    prev_glyph: u32 = 0;

    // @Speed!
    for info: font.temporary_glyphs {
        if !info.page continue;

        if use_kerning && prev_glyph {
            delta: FT_Vector = ---;
            error := FT_Get_Kerning(font.face, prev_glyph, info.glyph_index_within_font, xx FT_Kerning_Mode.DEFAULT, *delta);
            if !error {
                sx += cast(float) (delta.x >> 6);
            } else {
                log_error("Couldn't get kerning for glyphs %, %\n", prev_glyph, info.glyph_index_within_font);
            }
        }

        sx1 := sx  + cast(float) info.offset_x;
        sx2 := sx1 + cast(float) info.width / (ifx font_anti_aliasing == .lcd then 3.0 else 1.0);

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

        width  := info.page.bitmap_data.width;  // *Not* map.width, as map may be dirty.
        height := info.page.bitmap_data.height; // Ibid.

        quad.u0 = info.x0 / cast(float) width;
        quad.u1 = (cast(float) info.x0 + info.width) / width;
        quad.v0 = info.y0 / cast(float) height;
        quad.v1 = (cast(float) info.y0 + info.height) / height;

        array_add(*font.current_quads, quad);
        sx += cast(float) info.advance;

        prev_glyph = info.glyph_index_within_font;
    }
}

#scope_file

ft_library    : FT_Library;
fonts_initted := false;

// We probably should make different page sizes
// for different fonts.
page_size_x := 2048;
page_size_y := 1024;

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
    hash_key := (cast(u64) utf32) | ((cast(u64) font_anti_aliasing) << 32) | ((cast(u64) font_hinting) << 36);

    data, success := table_find(*font.glyph_lookup, hash_key);
    if success  return data;

    if utf32 == #char "\t" then utf32 = #char "→";  // draw tabs as arrows
    if utf32 == #char "\n" then utf32 = #char "¶";  // draw newlines as paragraph symbols

    glyph_index := FT_Get_Char_Index(face, utf32);
    if !glyph_index {
        log_error("Unable to find a glyph in font '%' for utf32 character %.\n", name, utf32);
        glyph_index = glyph_index_for_unknown_character;
    }

    load_mode := cast(s32) ifx font_hinting then FT_LOAD_DEFAULT else FT_LOAD_NO_HINTING;
    error := FT_Load_Glyph(face, glyph_index, load_mode);
    assert(!error);

    if #complete font_anti_aliasing == {
        case .lcd;      FT_Render_Glyph(face.glyph, .FT_RENDER_MODE_LCD);  // TODO: use LCD_V when monitor is rotated
        case .normal;   FT_Render_Glyph(face.glyph, .FT_RENDER_MODE_NORMAL);
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
