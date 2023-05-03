// create_texture_reader :: (format: Texture_Format, flags: Texture_Flags, w: int, h: int) -> *Pixel_Read;
// destroy_texture_reader/free :: (reader: *Pixel_Read);

// reader_start :: (reader: *Pixel_Read, map: *Texture);
// reader_start :: (reader: *Pixel_Read, map: *Texture, face: int/*, mipmap: int*/);

// reader_lock :: (reader: *Pixel_Read) -> data: *void, pitch:int;
// reader_unlock :: (reader: *Pixel_Read);

// is_read_available :: (reader: *Pixel_Read) -> bool;

// reader_end :: (reader: *Pixel_Read, bitmap: *Bitmap);
// reader_end :: (reader: *Pixel_Read) -> *Bitmap;

// Ignacio Castaño originally wrote this code, but it's been modified a bit, especially as regards the API.


Pixel_Read :: struct {
    dest_format: Texture_Format;
    dest_srgb:   bool;
    dest_width, dest_height: s32;

    flip := false;
    
    using platform_specific: Pixel_Read_Platform;
}

Pixel_Read_Platform :: struct {
    intermediate_texture: *Texture;  // Not currently used.
    pbo: GLuint;
    src\_fbo_handle: GLuint;
    dest_fbo_handle: GLuint;
}

/*
get_bitmap_from_texture :: (map: *Texture, format:=Texture_Format.Unknown, width:s32=0, height:s32=0, srgb:bool) -> *Bitmap {
    if format == Texture_Format.Unknown format = map.format;
    if width == 0 width = map.width;
    if height == 0 height = map.height;

    reader := create_texture_reader(format, width, height, srgb);
    defer destroy_texture_reader(reader);

    reader_start(reader, map);
    return reader_end(reader);    // This blocks until the read completes.
}
*/

// To start asynchronously reading a screenshot, call pixel_read_begin().
// If 'source' is null, the read will come from the frame buffer.
// Currently, we don't vet whether the graphics API handles 'dest_format',
// so if you pick something weird, you may be on your own.
//
// Call pixel_read_end() to get back a resulting Bitmap (you have memory responsibility
// over the Bitmap's data and must free it in a long-running program).
//
// Call pixel_read_is_done() to know whether the read has finished, in which case,
// when you call pixel_read_end() it will return very quickly. Otherwise, pixel_read_end()
// will block until the screenshot is done.
pixel_read_begin :: (source: *Texture /* may be null */, dest_format: Texture_Format, width: s32 = -1, height: s32 = -1, srgb := false, flip := false) -> *Pixel_Read #must {
    assert((dest_format == .RGB8) || (dest_format == .RGBA8));
    
    reader := New(Pixel_Read);  // @Cleanup: Don't use the heap?
    
    // Allocate some shared resources. If we actually were able to thread this, there'd be one per reader.
    glGenFramebuffers(1, *reader.src\_fbo_handle);
    glGenFramebuffers(1, *reader.dest_fbo_handle);

    reader.dest_format = dest_format;
    reader.dest_srgb   = srgb;    
    reader.flip        = flip;
    
    if source {
        if width  == -1  width  = source.width;
        if height == -1  height = source.height;
    } else {
        if width  == -1  width  = context.simp.current_window_info.window_width;
        if height == -1  height = context.simp.current_window_info.window_height;

        reader.flip = !flip;   // Because GL is a poop, frame buffer reads come back in the opposite way from texture reads.
    }

    reader.dest_width  = width;
    reader.dest_height = height;
    
    // Compute size.
    size := get_image_size(dest_format, width, height);

    glGenBuffers(1, *reader.pbo);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, reader.pbo);
    glBufferData(GL_PIXEL_PACK_BUFFER, size, null, GL_DYNAMIC_READ);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);

    // @@ Not sure what's the best way to handle the sRGB flag. We probably don't care here.
    src_srgb := ifx source then cast(bool)(source.flags & .sRGB);

    // If the input is multisampled, or we need to do format conversion, or resizing, then use an intermediate buffer.
    if source && (source.flags & .Multisampled ||
                  source.format != dest_format || src_srgb   != srgb || 
                  source.width  != width       || source.height != height) {
        if reader.intermediate_texture == null {
            flags: Texture_Flags;
            if srgb flags |= .sRGB;
            reader.intermediate_texture = texture_create_render_target(width, height, dest_format, flags);
        }

        // Blit src into downsampled_surface.
        src_x, src_y: s32;
        src_width  := source.width;
        src_height := source.height;

        dest_width := width;
        dest_height := height;
            
        // Crop if aspect ratio of src and dst do not match.
        if dest_width*src_height != src_width*height {
            h := (height * src_width) / dest_width;
            crop := (src_height - h) / 2;
            src_y = crop;
            src_height = h;
        }

        dest_target := get_gl_target(reader.intermediate_texture);
        dest_handle := reader.intermediate_texture.gl_handle;

        source_target := get_gl_target(source);
        old_read := bind_read_fbo(source_target, source.gl_handle, reader.src\_fbo_handle);
        old_draw := bind_draw_fbo(dest_target,   dest_handle,      reader.dest_fbo_handle);

        // Note that destination rectangle is flipped, so we don't have to flip the output later.
        //glBlitFramebuffer(src_x, src_y, src_width, src_height, 0, dest_height, dest_width, 0, GL_COLOR_BUFFER_BIT, GL_LINEAR);

        glBlitFramebuffer(src_x, src_y, src_width, src_height, 0, 0, dest_width, dest_height, GL_COLOR_BUFFER_BIT, GL_LINEAR);

        unbind_draw_fbo(dest_target,   dest_handle,      old_draw);
        unbind_read_fbo(source_target, source.gl_handle, old_read);

        source = reader.intermediate_texture;
    }

    source_handle: GLuint;  // 0 means read from the frame buffer.
    source_target := get_gl_target(source);

    if source {
        source_handle = source.gl_handle;
    }
    
    old_read := bind_read_fbo(source_target, source_handle, reader.src_fbo_handle);
    defer unbind_read_fbo(source_target, source_handle, old_read);

    _, gl_format, gl_type := get_ogl_format(dest_format, srgb);

    // Kick off read to our PBO.
    glBindBuffer(GL_PIXEL_PACK_BUFFER, reader.pbo);
    glReadPixels(0, 0, xx reader.dest_width, xx reader.dest_height, gl_format, gl_type, null);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);

    return reader;
}

/* For now we don't bother with reading miplevels...
reader_start :: (using reader: *Pixel_Read, src: *Texture, face:int, level:int) {

    // @@ Not sure what's the best way to handle the sRGB flag. We probably don't care here.
    src_srgb := cast(bool)(src.flags & .sRGB);

    src_level  := level;
    src_width  := cast(s32)src.width  >> level;
    src_height := cast(s32)src.height >> level;

    // If the input is multisampled, or we need to do format conversion, or resizing, then use intermediate buffer.
    if  src.flags & .Multisampled ||
        src.format != dest_format || src_srgb != dest_srgb || 
        src_width != dest_width || src_height != dest_height
    {
        assert(src.gl_target != GL_TEXTURE_CUBE_MAP);

        if intermediate_texture == null {
            intermediate_texture = create_render_target_texture(dest_width, dest_height, dest_format, dest_srgb);
        }

        // Blit src into downsampled_surface.
        src_x :s32= 0;
        src_y :s32= 0;
        // Crop if aspect ratio of src and dst do not match.
        if dest_width*src_height != src_width*dest_height {
            h := (dest_height * src_width) / dest_width;
            crop := (src_height - h) / 2;
            src_y = crop;
            src_height = h;
        }

        dest_target := intermediate_texture.gl_target;
        dest_handle := intermediate_texture.gl_handle;

        bind_read_fbo(src.gl_target, src.gl_handle, xx level);
        bind_draw_fbo(dest_target, dest_handle);

        // Note that destination rectangle is flipped, so we don't have to flip the output later.
        //glBlitFramebuffer(src_x, src_y, src_width, src_height, 0, dest_height, dest_width, 0, GL_COLOR_BUFFER_BIT, GL_LINEAR);

        glBlitFramebuffer(src_x, src_y, src_width, src_height, 0, 0, dest_width, dest_height, GL_COLOR_BUFFER_BIT, GL_LINEAR);

        unbind_draw_fbo(dest_target, dest_handle);
        unbind_read_fbo(src.gl_target, src.gl_handle);

        src = intermediate_texture;
        src_level = 0;
    }

    src_handle := src.gl_handle;
    src_target := src.gl_target;
    
    if src_target == GL_TEXTURE_CUBE_MAP {
        assert(face != -1);
        src_target = cast(u32)(GL_TEXTURE_CUBE_MAP_POSITIVE_X + face);
    }
    else {
        assert(face == -1);
    }

    bind_read_fbo(src_target, src_handle, xx src_level);
    defer unbind_read_fbo(src_target, src_handle);

    _, gl_format, gl_type := get_ogl_format(dest_format, dest_srgb);

    // Kick off read to our PBO.
    glBindBuffer(GL_PIXEL_PACK_BUFFER, reader.pbo);
    glReadPixels(0, 0, xx reader.dest_width, xx reader.dest_height, gl_format, gl_type, null);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
}
*/

pixel_read_is_done :: (reader: *Pixel_Read) -> bool {
    // IC: As far as I can tell, in OpenGL there's no way to determine if the read has completed and we
    // can map the buffer without stalling.
    return true;
}

pixel_read_end :: (reader: *Pixel_Read, bitmap: *Bitmap) {
    src, src_pitch := reader_lock(reader);
    defer reader_unlock(reader);

    dst := bitmap.data.data;
    dest_height := bitmap.height;

    bpp := get_image_bytes_per_texel(bitmap.format);
    dest_pitch := bitmap.width * bpp;

    copy_pitch := min(src_pitch, dest_pitch);
    if reader.flip {
        for y: 0..dest_height-1 {
            memcpy(dst + (dest_height-1 - y) * dest_pitch, src + y * src_pitch, copy_pitch);
        }
    } else {
        if src_pitch == dest_pitch {
            memcpy(dst, src, bitmap.width*bitmap.height*bpp);
        } else {
            for y: 0..dest_height-1 {
                memcpy(dst + y * dest_pitch, src + y * src_pitch, copy_pitch);
            }
        }
    }

    glDeleteBuffers(1, *reader.pbo);
    reader.pbo = 0;
    free(reader);
}

pixel_read_end :: (reader: *Pixel_Read) -> Bitmap {
    bitmap: Bitmap;
    bitmap_alloc(*bitmap, reader.dest_width, reader.dest_height, reader.dest_format);
    pixel_read_end(reader, *bitmap);
    return bitmap;
}

#scope_file

bind_read_fbo :: (target: GLenum, handle: GLuint, src_fbo_handle: GLuint, level: GLint = 0) -> (old: GLuint) {
    prev_read_fbo: GLuint;
    glGetIntegerv(GL_READ_FRAMEBUFFER_BINDING, xx *prev_read_fbo);

    if handle {
        // Bind buffer to read.
        glBindFramebuffer(GL_READ_FRAMEBUFFER, src_fbo_handle);
        set_frame_buffer_attachment(GL_READ_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, target, handle, level);
    } else {
        // Read front buffer.
        glBindFramebuffer(GL_READ_FRAMEBUFFER, 0);
        glReadBuffer(GL_FRONT);
    }

    return prev_read_fbo;
//    check_framebuffer_status(GL_READ_FRAMEBUFFER);
}

unbind_read_fbo :: (target: GLenum, handle: GLuint, prev_read_fbo: GLuint) {
    if handle {
        // Unbind draw framebuffer attachments
        set_frame_buffer_attachment(GL_READ_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, target, 0);
    } else {
        glReadBuffer(GL_NONE);
    }

    // Restore read FBO.
    glBindFramebuffer(GL_READ_FRAMEBUFFER, prev_read_fbo);

//    check_framebuffer_status(GL_READ_FRAMEBUFFER);
}

bind_draw_fbo :: (target: GLenum, handle: GLuint, dest_fbo_handle: GLuint) -> (old: GLuint) {
    prev_draw_fbo: GLuint;
    
    glGetIntegerv(GL_DRAW_FRAMEBUFFER_BINDING, xx *prev_draw_fbo);

    if handle {
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, dest_fbo_handle);
        set_frame_buffer_attachment(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, target, handle);
    } else {
        glBindFramebuffer(GL_DRAW_FRAMEBUFFER, 0);
        glDrawBuffer(GL_BACK);
    }

//    check_framebuffer_status(GL_DRAW_FRAMEBUFFER);
    return prev_draw_fbo;
}

unbind_draw_fbo :: (target: GLenum, handle: GLuint, prev_draw_fbo: GLuint) {
    if handle {
        // Unbind draw framebuffer attachments
        set_frame_buffer_attachment(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, target, 0);
    } else {
        glDrawBuffer(GL_NONE);
    }

    // Restore draw FBO.
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, prev_draw_fbo);

//    check_framebuffer_status(GL_DRAW_FRAMEBUFFER);
}

set_frame_buffer_attachment :: (target: GLenum, attachment: GLenum, textarget: GLenum, handle: GLuint, level:GLint=0, index: GLint=-1) {
    if textarget == GL_RENDERBUFFER {
        assert(level == 0);
        glFramebufferRenderbuffer(target, attachment, GL_RENDERBUFFER, handle);
    } else if textarget == GL_TEXTURE_CUBE_MAP || textarget == GL_TEXTURE_CUBE_MAP_ARRAY {
        // array and non-array cubemaps
        assert(index == -1);
        glFramebufferTexture(target, attachment, handle, level);
    } else if index >= 0 {
        glFramebufferTextureLayer(target, attachment, handle, level, index);
    } else {
        // 2D Textures (includes specific cube map faces)
        glFramebufferTexture2D(target, attachment, textarget, handle, level);
    }

    // @@ Is this saved in the framebuffer object configuration?
    if attachment == GL_COLOR_ATTACHMENT0 {
        if target == GL_DRAW_FRAMEBUFFER {
            if handle == 0  glDrawBuffer(GL_NONE);
            else            glDrawBuffer(GL_COLOR_ATTACHMENT0);
        } else {
            assert(target == GL_READ_FRAMEBUFFER);
            if handle == 0  glReadBuffer(GL_NONE);
            else            glReadBuffer(GL_COLOR_ATTACHMENT0);
        }
    }
}

// These were part of the original screenshot implementation. We should probably inline this though.
// @Robustness: wtf with the pitch alignment, do we really want to do that?
reader_lock :: (reader: *Pixel_Read) -> (data: *void, pitch:int) {
    bpp := get_image_bytes_per_texel(reader.dest_format);
    pitch := bpp * reader.dest_width;
    pitch = (pitch + 3) & -4;       // IC: Align to 4 bytes?

    glBindBuffer(GL_PIXEL_PACK_BUFFER, reader.pbo);

    return glMapBuffer(GL_PIXEL_PACK_BUFFER, GL_READ_ONLY), pitch;
}

reader_unlock :: (reader: *Pixel_Read) {
    glUnmapBuffer(GL_PIXEL_PACK_BUFFER);
    glBindBuffer(GL_PIXEL_PACK_BUFFER, 0);
}

get_gl_target :: (t: *Texture) -> u32 {
    return GL_TEXTURE_2D; // This seems to be the thing that works for just about anything we care about (including render targets).
}
    
