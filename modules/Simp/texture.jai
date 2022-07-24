// @Speed: Why are we building mipmaps in software, when probably
// the user just wants the mipmaps in place in video memory?
        
Texture_Flags :: enum_flags u16 {
    sRGB;
    Cube;
    Array;
    Volume;
    Buffer;
    Render_Target;
    Multisampled;
    No_Skip_Mipmaps;
    Display_Target;
}

Texture :: struct {
    width, height, depth: s32 = 1;  // 'depth' is in case this is a 3D texture.
    mipmap_count: u16 = 1;
    array_length: u16 = 1;

    format: Texture_Format;
    flags:  Texture_Flags;

    // resource_size : u32;

    using specific: Texture_Platform_Specific;
}

texture_load_from_file :: (map: *Texture, filename: string, srgb:=false, build_mipmaps:=false) -> bool {
    bitmap: Bitmap;
    if !bitmap_load(*bitmap, filename) {
        return false;
    }
    
    defer deinit(*bitmap);

    if srgb           bitmap.flags |= .IS_SRGB;
    if build_mipmaps  bitmap_build_mipmaps(*bitmap);

    texture_load_from_bitmap(map, *bitmap);
    
    return true;
}

texture_load_from_memory :: (texture: *Texture, memory: [] u8, srgb:=false, build_mipmaps:=false) -> bool {
    bitmap: Bitmap;
    success := bitmap_load_from_memory(*bitmap, memory);

    if !success return false;

    defer deinit(*bitmap);
    if srgb           bitmap.flags |= .IS_SRGB;
    if build_mipmaps  bitmap_build_mipmaps(*bitmap);

    texture_load_from_bitmap(texture, *bitmap);
    return true;
}

texture_load_from_bitmap :: (using texture: *Texture, bitmap: *Bitmap) -> bool {
    if !bitmap return false;

    assert(is_supported(bitmap.format));
    assert(bitmap.mipmap_count > 0);

    // @Incomplete: Fill this out with rendering-backend-specific stuff!
    // @@ Since reloading a bitmap into the same texture seems to be fairly common, we have a fast path that does not reallocate storage.
    if texture.width != bitmap.width || texture.height != bitmap.height || texture.depth != 1 || texture.mipmap_count != bitmap.mipmap_count || texture.format != bitmap.format {
        backend_realloc_texture(texture, bitmap);

        width        = xx bitmap.width;
        height       = xx bitmap.height;
        depth        = 1;
        mipmap_count = xx bitmap.mipmap_count;
        format       = bitmap.format;
        
        if bitmap.flags & .IS_SRGB flags |= .sRGB;
        else                       flags &= ~.sRGB;
    }
    
    backend_update_texture(texture, bitmap);

    return true;
}

load_texture_from_file :: (using texture: *Texture, filename: string) -> bool #deprecated "Use texture_load_from_file instead." {
    return texture_load_from_file(texture, filename);
}

load_texture_from_bitmap :: (using texture: *Texture, bitmap: *Bitmap) -> bool #deprecated "Use texture_load_from_bitmap instead." {
    return texture_load_from_bitmap(texture, bitmap);
}


texture_create_render_target :: (width: s32, height: s32, format: Texture_Format, flags: Texture_Flags = 0) -> *Texture {
    CheckInit();  // Set up context.simp.

    texture := New(Texture);

    texture.width  = width;
    texture.height = height;
    texture.format = format;
    texture.flags  = flags | .Render_Target;

    backend_create_render_target(texture);
    
    return texture;
}
