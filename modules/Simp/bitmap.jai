Bitmap :: struct {
    width:  s32;
    height: s32;
    
    mipmap_count: s32 = 1;

    data:   [] u8;
    stride: s32;

    flags: enum_flags u32 {
        FREE_DATA_ON_DEINIT :: 0x1;
        IS_SRGB             :: 0x2;
    }
    
    format := Texture_Format.BGRA8;
}

bitmap_alloc :: (using bitmap: *Bitmap, w: s32, h: s32, _format: Texture_Format) {
    width        = w;
    height       = h;
    mipmap_count = 1;

    bpp := get_image_bytes_per_texel(_format);
    size := w * h * bpp;
    
    data         = NewArray(size, u8, initialized=false);
    stride       = xx (w*bpp);

    format       = _format;
    flags       |= .FREE_DATA_ON_DEINIT;
}

deinit :: (bitmap: *Bitmap) {
    if bitmap.flags & .FREE_DATA_ON_DEINIT  free(bitmap.data.data);  // We are currently not tracking where this memory came from...!
}

bitmap_load :: (bitmap: *Bitmap, filepath: string) -> bool {
    w, h, channels: s32;
    data := stbi_load(temp_c_string(filepath), *w, *h, *channels, 0);

    if !data {
        log("Unable to load bitmap '%'.", filepath, flags=.ERROR);
        return false;
    }

    // @Speed:
    //
    // call stbi_image_free() on the data here and copy it into
    // memory alloc'd by the jai program. This is to work-around
    // an issue of calling a different implementation of free()
    // than the one stb_image is linked against, thus crashing.
    // :FreeingBitmapDataFromSTBI:
    //
    defer stbi_image_free(data);

    bitmap_load_part_2(bitmap, data, w, h, channels);
    return true;
}

bitmap_load_from_memory :: (bitmap: *Bitmap, memory: [] u8) -> bool {
    count32 := cast,trunc(s32) memory.count;
    if count32 != memory.count {
        // We max out at 2GB because stbi_load_from_memory takes an s32 parameter for length.
        log("Tried to load a bitmap from memory, but it's too big! (2GB max for now).\n", flags=.ERROR);
        return false;
    }
    
    w, h, channels: s32;
    data := stbi_load_from_memory(memory.data, count32, *w, *h, *channels, 0);

    if !data {
        log("Unable to load a bitmap from memory.", flags=.ERROR);
        return false;
    }

    bitmap_load_part_2(bitmap, data, w, h, channels);
    return true;
}

bitmap_save :: (bitmap: *Bitmap, filepath: string, save_alpha := false) -> bool {
    if bitmap.format != .RGB8 && bitmap.format != .RGBA8 {
        log("Attempt to save a bitmap, but the format % is unhandled.", bitmap.format, flags=.ERROR);
        return false;
    }

    components : s32 = 4;
    if bitmap.format == .RGB8 components = 3;
    
    stride := bitmap.stride;
    data   := bitmap.data.data;
    
    name      := temp_c_string(filepath);
    extension := path_extension(filepath);
    
    if extension == {
        case "png"; 
            return stbi_write_png(name, bitmap.width, bitmap.height, components, data, stride) != 0;
        case "tga";
            return stbi_write_tga(name, bitmap.width, bitmap.height, components, data, stride) != 0;
        case "bmp";
            return stbi_write_bmp(name, bitmap.width, bitmap.height, components, data, stride) != 0;
        case "hdr";
            return stbi_write_hdr(name, bitmap.width, bitmap.height, components, data, stride) != 0;
        case "jpg";
            return stbi_write_jpg(name, bitmap.width, bitmap.height, components, data, stride, quality=80) != 0;
        case;
            log("Bitmap extension '%' is not understood by this code.", extension, flags=.ERROR);
            return false;
    }
    
    // return false;
}

bitmap_build_mipmaps :: (bitmap: *Bitmap) {
    channels: s32;
    if bitmap.format == {
        case .R8;    channels = 1;
        case .RG8;   channels = 2;
        case .RGB8;  channels = 3;
        case .RGBA8; channels = 4;
    }
    
    assert(channels != 0, "Unsuported texture format in bitmap_build_mipmaps.");

    // Compute texture size with mipmaps.
    w := bitmap.width;
    h := bitmap.height;
    
    //size, p := get_image_size(bitmap.format, bitmap.width, bitmap.height, 1, mipmap_count);
    p := (w * channels + 3) & -4;
    size := p * h;
    m := 1;
    while w != 1 || h != 1 {
        w = max(w/2, 1);
        h = max(h/2, 1);
        p = (w * channels + 3) & -4; 
        size += p * h;
        m += 1;
    }

    // Allocate mipmap data.
    data_tmp := alloc(size);

    // Copy first mipmap.
    dest   := data_tmp;
    source := bitmap.data.data;
    for 0..h-1 {
        memcpy(dest, source, bitmap.width * channels);
        dest   += (bitmap.width * channels + 3) & -4;
        source += bitmap.stride;
    }

    // Generate mipmaps.
    w = bitmap.width;
    h = bitmap.height;
    input_w := w;
    input_h := h;
    input_ptr := data_tmp;
    input_stride := p;
    
    alpha :s32 = -1;
    if channels == 4 alpha = 3;

    while w != 1 || h != 1 {
        w = max(w/2, 1);
        h = max(h/2, 1);
        p = (w * channels + 3) & -4;
        ptr := input_ptr + input_stride * input_h;

        if bitmap.flags & .IS_SRGB stbir_resize_uint8_srgb(input_ptr, input_w, input_h, input_stride, ptr, w, h, p, channels, alpha, flags=0);
        else                       stbir_resize_uint8     (input_ptr, input_w, input_h, input_stride, ptr, w, h, p, channels);
        
        input_w      = w;
        input_h      = h;
        input_ptr    = ptr;
        input_stride = p;
    }
    
    assert(size == input_ptr - data_tmp + p * h * channels);

    // Update bitmap members.

    //
    // Do we really want the bitmap managing data? Really, the user should probably know
    // if they want the bitmap to be freed or not. I dunno, I do not like this FREE_DATA flag,
    // so we should consider removing it. I'll see how it feels when I use it.  -jblow, 22 February 2021
    //
    if bitmap.flags & .FREE_DATA_ON_DEINIT  free(bitmap.data.data);

    bitmap.data.data    = data_tmp;
    bitmap.data.count   = size;
    bitmap.stride       = bitmap.width * channels;
    bitmap.mipmap_count = cast(u16) m;

    bitmap.flags |= .FREE_DATA_ON_DEINIT;  // But, we are not setting the allocator. Is that bad?
}

#scope_file

bitmap_load_part_2 :: (bitmap: *Bitmap, data: *u8, w: s32, h: s32, channels: s32) {
    format: Texture_Format;
    if channels == {
        case 1; format = .R8;
        case 2; format = .RG8;
        case 3; format = .RGB8;
        case 4; format = .RGBA8;
    }

    bitmap_alloc(bitmap, w, h, format);

    memcpy(bitmap.data.data, data, bitmap.stride*bitmap.height);
}

