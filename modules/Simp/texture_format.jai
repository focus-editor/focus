Texture_Format :: enum u16 {
    Unknown :: 0;

    R8       :: 1;        // Fixed point formats.
    RG8      :: 2;
    RGB8     :: 3;
    RGBA8    :: 4;
    BGRA8;
    B5G6R5;
    RGB10A2;
    R16;

    R16F :: 0x10;   // Floating point formats.
    RG16F;
    RGBA16F;
    R32F;
    RG32F;
    RGBA32F;
    RG11B10F;
    RGB9E5F;

    R16I;           // Integer formats.
    RG16I;
    RGBA16I;
    R32I;
    RG32I;
    RGBA32I;

    BC1 :: 0x100;   // Block compression formats.
    BC3;
    BC4;
    BC5;
    BC6;
    BC7;

    ETC_RGB;
    ETC_RGBA;
    ETC_R;
    ETC_RG;
    ETC_RGB_A1;

    D16;        // Depth formats.
    D24S8;
    D32F;
    D32FS8;
}


get_image_size :: (tf: Texture_Format, w: int, h: int) -> int, stride:int {
    stride, rows : int;

    bpp := get_image_bytes_per_texel(tf);
    if bpp {
        stride = w * bpp;
        rows = h;
    } else {
        bpb := get_image_bytes_per_block(tf);
        assert(bpb != 0);
        stride = ((w + 3)/4) * bpb;
        rows  = ((h + 3)/4);
    }

    return rows * stride, stride;
}


// Dave Churchill suggests making a lookup table for these values instead,
// and that seems like a pretty reasonable idea, since the table is going
// to be a lot shorter than the code, probably:
get_image_bytes_per_texel :: (tf: Texture_Format) -> int {
    using Texture_Format;

    if tf == {
        case R8;
            return 1;
        case RG8;    #through;
        case R16;    #through;
        case B5G6R5; #through;
        case R16F;   #through;
        case R16I;   #through;
        case D16;
            return 2;
        case RGB8;
            return 3;
        case RG11B10F; #through;
        case RGB9E5F;  #through;
        case RGB10A2;  #through;
        case RGBA8;    #through;
        case BGRA8;    #through;
        case RG16F;    #through;
        case R32F;     #through;
        case RG16I;    #through;
        case R32I;     #through;
        case D24S8;    #through;
        case D32F;
            return 4;
        case RGBA16F;  #through;
        case RG32F;    #through;
        case RGBA16I;  #through;
        case RG32I;    #through;
        case D32FS8;
            return 8;
        case RGBA32F;  #through;
        case RGBA32I;
            return 16;
    }

    // :NoErrorOnZero
    // We don't log an error here, because get_image_size expects
    // to be able to call this with block formats, have it return 0,
    // and that's how it knows to go to the block format version of size
    // querying. Ehh, I don't think I like that design much, but for now
    // I will let it stand.
    
    // log("Error: Attempted to get bytes per texel for a block format or invalid format %.", tf);
    // assert(false);
    
    return 0;
}

get_image_bytes_per_block :: (tf: Texture_Format) -> int {
    using Texture_Format;

    if tf == {
        // PC:
        case BC1; #through;
        case BC4;
            return 8;
        case BC3; #through;
        case BC5; #through;
        case BC6; #through;
        case BC7;
            return 16;

        // Mobile:
        case ETC_R; #through;
        case ETC_RGB; #through;
        case ETC_RGB_A1;
            return 8;
        case ETC_RGBA; #through;
        case ETC_RG;
            return 16;
    }
    
    // :NoErrorOnZero
    // Commented out for consistency with the above.
    // log("Error: Attempted to get bytes per block for a non-block format or invalid format %.", tf);
    // assert(false);
    
    return 0;
}
