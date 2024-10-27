#load "gl_screenshot.jai";

//
// Init stuff:
//

backend_init :: (info: *Window_Info) {
    CheckInit();  // Set up context.simp.

    do_first_time_init := false;

    // @Threadsafety
    if the_gl_context {
        #if OS == .WINDOWS {
            hdc := GetDC(info.window);
            windows_change_pixel_format(hdc);
            info.specific.hdc = hdc;
        }
    } else {
        do_first_time_init = true;

        #if OS == .WINDOWS {
            hglrc, hdc := wgl_create_context(info.window, null, MINIMUM_GL_MAJOR_VERSION, MINIMUM_GL_MINOR_VERSION);
            the_gl_context = hglrc;
            the_hdc_for_pixel_format_cloning = hdc;
            info.specific.hdc = hdc;

            // NOTE: when I enabled vsync this way, the program started feeling terrible
            // _wglSwapIntervalEXT : (interval: s32) -> BOOL #foreign;
            // _wglSwapIntervalEXT = xx wglGetProcAddress("wglSwapIntervalEXT");
            // vsync := _wglSwapIntervalEXT(1); // enable vsync
            // if !vsync then log_error("Couldn't enable vsync\n");
        }
        #if OS == .LINUX {
            LD.create_gl_context(MINIMUM_GL_MAJOR_VERSION, MINIMUM_GL_MINOR_VERSION);
            the_gl_context = LD.get_gl_context();
        }
        #if OS == .MACOS {
            the_gl_context = nsgl_create_context(MINIMUM_GL_MAJOR_VERSION, MINIMUM_GL_MINOR_VERSION);
            autorelease(the_gl_context);
        }
    }

    #if OS == .MACOS {
        // Get the GL view from the window.
        // This relies on this window having a content view with OpenGL support (eg. as created by Window_Creation).
        view := NSWindow.contentView(info.window);
        assert(view != null);
        NSView.setWantsBestResolutionOpenGLSurface(view, YES);
        NSOpenGLContext.setView(the_gl_context, view);
        NSOpenGLContext.update(the_gl_context);
    }

    #if OS == .LINUX {
        LD.create_gl_surface(info.window);
    }

    if do_first_time_init {
        #if OS == .LINUX  LD.make_current(info.window);
        #if OS == .MACOS {
            NSOpenGLContext.makeCurrentContext(the_gl_context);
        }

        #if OS != .LINUX {
            // `gl_load` is part of `Linux_Display.create_context()`
            gl_load(*gl);
            gl_enable_debug_output(break_on_error = true);
        }

        glGenVertexArrays(1, *opengl_is_stupid_vao);
        glGenBuffers(1, *immediate_vbo);

        backend_init_shaders();

        DumpGLErrors("context");
    }

    state.current_window_info = << info;
}

#scope_module

opengl_is_stupid_vao: GLuint;
immediate_vbo:        GLuint;
main_fbo_handle:      GLuint;

#if OS == .WINDOWS {
    the_gl_context: HGLRC;
    the_hdc_for_pixel_format_cloning: HDC;
} else #if OS == .LINUX {
    the_gl_context: *void;
} else {
    the_gl_context: *NSOpenGLContext;
}

is_supported :: (tf: Texture_Format) -> bool {
    return get_ogl_format(tf) != GL_INVALID_ENUM;
}

#scope_file

MINIMUM_GL_MAJOR_VERSION :: 3;
MINIMUM_GL_MINOR_VERSION :: 3;


//
// Shader stuff:
//

#scope_export

Shader_Platform :: struct {
    gl_handle: GLuint;

    position_loc:      GLint = -1;
    color_scale_loc:   GLint = -1;
    uv_0_loc:          GLint = -1;
    rect_center_loc:   GLint = -1;
    rect_size_loc:     GLint = -1;
    rect_corner_radius_loc: GLint = -1;
    rect_edge_softness_loc: GLint = -1;

    alpha_blend := false;
}

set_parameter :: (shader: *Shader, name: string, m: Matrix4) {
    loc := get_uniform_location(shader.gl_handle, name);
    if loc < 0   log_error("Unknown parameter: '%'\n", name);
    if loc >= 0  glUniformMatrix4fv(loc, 1, GL_TRUE, *m._11);
}

get_uniform_location :: (gl_handle: GLuint, name: string) -> GLint {
    // Asking OpenGL for the location can be an incredibly expensive operation on some systems, so we cache it
    key := tprint("%,%", gl_handle, name);
    loc, found := table_find(*uniform_location_cache, key);
    if !found {
        loc = glGetUniformLocation(gl_handle, temp_c_string(name));
        table_set(*uniform_location_cache, copy_string(key), loc);
    }
    return loc;
}

#scope_file

uniform_location_cache: Table(string, GLint);

#scope_export

clear_render_target :: (r: float, g: float, b: float, a: float) {
    glClearColor(r, g, b, a);
    glClear(GL_COLOR_BUFFER_BIT);
}

swap_buffers :: (window: Window_Type, vsync := true) {  // @Incomplete: Have some more-sophisticated vsync flags.
    CheckInit();
    if state.current_shader immediate_flush();

    #if OS == .WINDOWS {
        dc := GetDC(window);
        SwapBuffers(dc);
    } else #if OS == .LINUX {
        info := find_window_info(window);
        if (!info) || !LD.gl_initialized(window) {
            log_error("Simp: Attempt to swap_buffers on a previously unseen window!\n");
            return;
        }
        LD.swap_buffers(info.window);
    } else #if OS == .MACOS {
        // On macOS, OpenGL buffer swapping is done on the context, not on the view.
        // So we can only swap for the active window. (And you need to swap before switching to another view).
        assert(window == state.current_window_info.window);
        NSOpenGLContext.flushBuffer(the_gl_context);
    } else {
        assert(false);
    }
}


#scope_module

backend_init_shaders :: () {
    s := *shader_color;
    {
        s.gl_handle       = get_shader_program(SHADER_COLOR);
        s.position_loc    = 0;
        s.color_scale_loc = 1;
        s.alpha_blend = false;
    }

    s = *shader_color_with_blend;
    {
        s.gl_handle   = shader_color.gl_handle;
        s.position_loc    = 0;
        s.color_scale_loc = 1;
        s.alpha_blend = true;
    }

    s = *shader_text_lcd;
    {
        s.gl_handle       = get_shader_program(SHADER_TEXT_LCD);
        s.position_loc    = 0;
        s.color_scale_loc = 1;
        s.uv_0_loc        = 2;
        s.alpha_blend = true;
    }

    s = *shader_text_normal;
    {
        s.gl_handle       = get_shader_program(SHADER_TEXT_NORMAL);
        s.position_loc    = 0;
        s.color_scale_loc = 1;
        s.uv_0_loc        = 2;
        s.alpha_blend = true;
    }

    s = *shader_sprite;
    {
        s.gl_handle   = get_shader_program(SHADER_SPRITE);
        s.position_loc    = 0;
        s.color_scale_loc = 1;
        s.uv_0_loc        = 2;
        s.alpha_blend = true;
    }

    s = *shader_rounded_rect;
    {
        s.gl_handle   = get_shader_program(SHADER_ROUNDED_RECT);
        s.position_loc           = 0;
        s.color_scale_loc        = 1;
        s.rect_center_loc        = 2;
        s.rect_size_loc          = 3;
        s.rect_corner_radius_loc = 4;
        s.rect_edge_softness_loc = 5;
        s.alpha_blend = true;
    }

    s = *shader_gradient;
    {
        s.gl_handle   = get_shader_program(SHADER_GRADIENT);
        s.position_loc           = 0;
        s.color_scale_loc        = 1;
        s.alpha_blend = true;
    }
}

#scope_file

// LCD (horizontal RGB/BGA subpixel anti-aliasing)
SHADER_TEXT_LCD :: #string GLSL

OUT_IN vec2 TextureCoords;
OUT_IN vec4 iterated_color;

#ifdef VERTEX_SHADER
layout(location = 0) in vec2 vert_position;
layout(location = 1) in vec4 vert_color;
layout(location = 2) in vec2 vert_uv0;

uniform mat4 projection;

void main() {
    gl_Position     = projection * vec4(vert_position, 0.0, 1.0);
    iterated_color  = vert_color;
    TextureCoords   = vert_uv0;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER

layout(location = 0, index = 0) out vec4 color;
layout(location = 0, index = 1) out vec4 colorMask;

uniform sampler2D text_sampler;
uniform vec4 text_color;

void main () {
    float sample_left   = textureOffset(text_sampler, TextureCoords, ivec2(-1, 0)).r;
    float sample_center = texture(text_sampler, TextureCoords).r;
    float sample_right  = textureOffset(text_sampler, TextureCoords, ivec2( 1, 0)).r;
    color = iterated_color;
    colorMask = vec4(sample_left * color.a, sample_center * color.a, sample_right * color.a, 1.0);
}
#endif // FRAGMENT_SHADER
GLSL


// Normal anti-aliasing
SHADER_TEXT_NORMAL :: #string GLSL

OUT_IN vec2 TextureCoords;
OUT_IN vec4 iterated_color;

#ifdef VERTEX_SHADER
layout(location = 0) in vec2 vert_position;
layout(location = 1) in vec4 vert_color;
layout(location = 2) in vec2 vert_uv0;

uniform mat4 projection;

void main() {
    gl_Position     = projection * vec4(vert_position, 0.0, 1.0);
    iterated_color  = vert_color;
    TextureCoords   = vert_uv0;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
layout(location = 0, index = 0) out vec4 color;
layout(location = 0, index = 1) out vec4 colorMask;

uniform sampler2D text_sampler;
uniform vec4 text_color;

void main () {
    vec4 texture_sample = texture(text_sampler, TextureCoords);
    color = vec4(iterated_color.xyz, texture_sample.a * iterated_color.a); // text_color * texture_sample;
    colorMask = vec4(texture_sample.rrr * color.a, 1.0);
}
#endif // FRAGMENT_SHADER
GLSL


SHADER_COLOR :: #string GLSL
OUT_IN vec4 iterated_color;

#ifdef VERTEX_SHADER
layout(location = 0) in vec2 vert_position;
layout(location = 1) in vec4 vert_color;

uniform mat4 projection;

void main() {
    gl_Position = projection * vec4(vert_position, 0.0, 1.0);
    iterated_color = vert_color;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
out vec4 color;

void main () {
    color = iterated_color;
}
#endif // FRAGMENT_SHADER
GLSL


SHADER_GRADIENT :: #string GLSL
OUT_IN vec4 iterated_color;

#ifdef VERTEX_SHADER
in vec2 vert_position;
in vec4 vert_color;

uniform mat4 projection;

void main() {
    gl_Position = projection * vec4(vert_position, 0.0, 1.0);
    iterated_color = vert_color;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
uniform vec4 rect;
uniform int mode; // See Gradient_Mode enum.
uniform float value;

out vec4 color;

float random (in vec2 _st) {
    return fract(sin(dot(_st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

vec4 random4(vec2 co) {
    vec4 result;
    result.x = random(co); co *= 2;
    result.y = random(co); co *= 2;
    result.z = random(co); co *= 2;
    result.w = random(co);
    return result;
}

vec3 hsl2rgb( in vec3 c )
{
    vec3 rgb = clamp( abs(mod(c.x*6.0+vec3(0.0,4.0,2.0),6.0)-3.0)-1.0, 0.0, 1.0 );
    return c.z + c.y * (rgb-0.5)*(1.0-abs(2.0*c.z-1.0));
}

void main () {
    vec2 uv = vec2((gl_FragCoord.x - rect.x) / rect.z, (gl_FragCoord.y - rect.y) / rect.w);
    // This is line 44
    switch (mode) {
        case 0x00:  // 2d controlled by red
        color.r = value;
        color.gb = uv.xy;
        break;

        case 0x01: // 2d controlled by green
        color.g = value;
        color.rb = uv.xy;
        break;

        case 0x02: // 2d controlled by blue
        color.b = value;
        color.rg = uv.xy;
        break;

        case 0x03:  // 2d controlled by hue
        color.rgb = hsl2rgb(vec3(value, uv.x, uv.y));
        break;

        case 0x04:  // 2d controlled by saturation
        color.rgb = hsl2rgb(vec3(uv.x, value, uv.y));
        break;

        case 0x05:  // 2d controlled by lightness
        color.rgb = hsl2rgb(vec3(uv.x, uv.y, value));
        break;

        case 0x10: // 1d vertical displaying red
        color.r = uv.y;
        color.g = 0;
        color.b = 0;
        break;

        case 0x11: // 1d vertical displaying green
        color.r = 0;
        color.g = uv.y;
        color.b = 0;
        break;

        case 0x12: // 1d vertical displaying blue
        color.r = 0;
        color.g = 0;
        color.b = uv.y;
        break;

        case 0x13: // 1d vertical displaying hue
        color.rgb = hsl2rgb(vec3(uv.y, 1, 0.5));
        break;

        case 0x14: // 1d vertical displaying saturation
        color.rgb = hsl2rgb(vec3(value, uv.y, 0.5));
        break;

        case 0x15: // 1d vertical displaying lightness
        color.rgb = hsl2rgb(vec3(value, 1, uv.y));
        break;

        case 0x16: // 1d vertical displaying alpha
        color.rgb = vec3(uv.y);
        break;

        case 0x20: // 1d horizontal displaying red
        color.r = uv.x;
        color.g = 0;
        color.b = 0;
        break;

        case 0x21: // 1d horizontal displaying green
        color.r = 0;
        color.g = uv.x;
        color.b = 0;
        break;

        case 0x22: // 1d horizontal displaying blue
        color.r = 0;
        color.g = 0;
        color.b = uv.x;
        break;

        case 0x23: // 1d horizontal displaying hue
        color.rgb = hsl2rgb(vec3(uv.x, 1, 0.5));
        break;

        case 0x24: // 1d horizontal displaying saturation
        color.rgb = hsl2rgb(vec3(value, uv.x, 0.5));
        break;

        case 0x25: // 1d horizontal displaying lightness
        color.rgb = hsl2rgb(vec3(value, 1, uv.x));
        break;

        case 0x26: // 1d horizontal displaying alpha
        color.rgb = vec3(uv.x);
        break;
    }

    // When color is between two displayable values dither it to avoid banding; round it up or down randomly,
    // proportionate to which it is nearer to.
    vec4 remainder = fract(color * 255.0);
    color = color - (remainder / 255.0) + (1.0 / 255.0) - (step(remainder, random4(uv)) / 255.0);
    color.a = iterated_color.a;
}
#endif // FRAGMENT_SHADER
GLSL


// @Cleanup:
// shader_sprite is 1-v from shader_text. Do we pack the text texture upside down,
// or what?
SHADER_SPRITE :: #string GLSL
OUT_IN vec2 TexCoords;
OUT_IN vec4 iterated_color;

#ifdef VERTEX_SHADER
layout(location = 0) in vec2 vert_position;
layout(location = 1) in vec4 vert_color;
layout(location = 2) in vec2 vert_uv0;

uniform mat4 projection;

void main() {
    TexCoords = vec2(vert_uv0.x, 1-vert_uv0.y);  // @Cleanup: Figure out what to do to avoid this vertical flip... sigh!
    gl_Position = projection * vec4(vert_position, 0.0, 1.0);
    iterated_color = vert_color;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
out vec4 color;

uniform sampler2D diffuse_texture;

void main () {
    vec4 color_tex = iterated_color * texture(diffuse_texture, TexCoords);
    if (color_tex.a < 0.1) discard;

    color = color_tex;
}
#endif // FRAGMENT_SHADER
GLSL

SHADER_ROUNDED_RECT :: #string GLSL
OUT_IN vec4 iterated_color;
flat OUT_IN vec2 rect_center;
flat OUT_IN vec2 rect_size;
flat OUT_IN float rect_corner_radius;
flat OUT_IN float rect_edge_softness;

#ifdef VERTEX_SHADER
layout(location = 0) in vec2 vert_position;
layout(location = 1) in vec4 vert_color;

layout(location = 2) in vec2 vert_rect_center;
layout(location = 3) in vec2 vert_rect_size;
layout(location = 4) in float vert_rect_corner_radius;
layout(location = 5) in float vert_rect_edge_softness;

uniform mat4 projection;

void main() {
    gl_Position = projection * vec4(vert_position, 0.0, 1.0);
    iterated_color    = vert_color;

    rect_center = vert_rect_center;
    rect_size = vert_rect_size;
    rect_corner_radius = vert_rect_corner_radius;
    rect_edge_softness = vert_rect_edge_softness;
}
#endif // VERTEX_SHADER

#ifdef FRAGMENT_SHADER
out vec4 color;

float rounded_rect_sdf(vec2 frag_pos, vec2 rect_center, vec2 size, float radius) {
    return length(max(abs(frag_pos - rect_center) - size + radius, 0.0)) - radius;
}

void main () {
    float distance = rounded_rect_sdf(gl_FragCoord.xy, rect_center, rect_size, rect_corner_radius);
    float smoothed_alpha = 1.0f - smoothstep(0.0f, rect_edge_softness, distance);
    color = vec4(iterated_color.xyz, iterated_color.a * smoothed_alpha);
}

#endif // FRAGMENT_SHADER
GLSL

get_shader_program :: (shader_text: string) -> GLuint {
    LOG_BUFFER_SIZE :: 512;

    make_shader_object :: (shader: string, prefix: string, shader_type : GLenum) -> GLuint {
        shader_object := glCreateShader(shader_type);

        //shader_str := temp_c_string(shader);
        shaders: [2] *u8;
        lengths: [2] s32;

        shaders[0] = prefix.data;
        shaders[1] = shader.data;
        lengths[0] = xx prefix.count;
        lengths[1] = xx shader.count;

        glShaderSource(shader_object, 2, shaders.data, lengths.data);

        glCompileShader(shader_object);

        success : GLint;
        glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);

        if !success then {
            log_data: [LOG_BUFFER_SIZE] u8;
            glGetShaderInfoLog(shader_object, log_data.count, null, log_data.data);
            log("%", to_string(log_data.data), flags=.ERROR);
            return 0;
        }

        return shader_object;
    }

    PREFIX_V :: #string GLSL
    #version 330 core
    #define VERTEX_SHADER
    #define OUT_IN out
    GLSL

    PREFIX_F :: #string GLSL
    #version 330 core
    #define FRAGMENT_SHADER
    #define OUT_IN in
    GLSL

    shader_v := make_shader_object(shader_text, PREFIX_V, GL_VERTEX_SHADER);
    shader_f := make_shader_object(shader_text, PREFIX_F, GL_FRAGMENT_SHADER);
    shader_p := glCreateProgram();

    glAttachShader(shader_p, shader_v);
    glAttachShader(shader_p, shader_f);
    glLinkProgram(shader_p);

    success : GLint = 0;
    glGetProgramiv(shader_p, GL_LINK_STATUS, *success);

    if !success then {
        log_data: [LOG_BUFFER_SIZE] u8;
        glGetProgramInfoLog(shader_p, log_data.count, null, log_data.data);
        log("%", to_string(log_data.data), flags=.ERROR);
        return 0;
    }

    glDeleteShader(shader_v);
    glDeleteShader(shader_f);

    return shader_p;
}


#scope_export
draw_generated_quads :: (font: *Dynamic_Font, color: u8) {
    CheckInit();
    quads := font.current_quads;

    set_shader_for_text();

    glBlendFunc(GL_SRC1_COLOR, GL_ONE_MINUS_SRC1_COLOR);
    glEnable(GL_BLEND);

    glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY_EXT, 0);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);

    last_texture: GLuint = 0xFFFFFFFF;

    color_vec4 := COLOR_MAP[color];

    for quad, i: quads {
        page := quad.glyph.page;
        map  := *page.texture;

        if page.dirty {
            page.dirty = false;
            texture_load_from_bitmap(map, page.bitmap_data);
        }

        if map.gl_handle != last_texture {
            // @Speed
            // NOTE(ivan): this will cause a flush for every call to draw_text.
            // But if we don't do this then we won't set the texture.
            // Need to refactor the text rendering code so that we don't have to deal with this
            immediate_flush();
            last_texture = map.gl_handle;

            shader := state.current_shader;
            loc := get_uniform_location(shader.gl_handle, "text_sampler");
            if loc < 0  log_error("Unable to find text_sampler in shader_text!");
            glActiveTexture(GL_TEXTURE0);
            glBindTexture(GL_TEXTURE_2D, map.gl_handle);  // Bind handle to slot 0.
            glUniform1i(loc, 0);
        }

        immediate_letter_quad(quad, color_vec4);
    }

    // Same as above. This is not good
    immediate_flush();

    glDisable(GL_BLEND);
}

#scope_module

Texture_Platform_Specific :: struct {
    gl_handle: GLuint;
}

deinit :: (texture: *Texture) {
    handle := texture.gl_handle;
    if !handle  return;

    /* @Incomplete: Decide what to do here that is simple.

    gl_target := texture.gl_target;
    if gl_target == GL_RENDERBUFFER {
        glDeleteRenderbuffers(1, *handle);
    } else {
        assert(gl_target == GL_TEXTURE_2D || gl_target == GL_TEXTURE_3D || gl_target == GL_TEXTURE_CUBE_MAP || gl_target == GL_TEXTURE_2D_ARRAY || gl_target == GL_TEXTURE_CUBE_MAP_ARRAY || gl_target == GL_TEXTURE_BUFFER);
        glDeleteTextures(1, *handle);
    }
*/

    texture.gl_handle = 0;
//    texture.resource_size = 0;
}

get_ogl_format :: (tf: Texture_Format, srgb:=false) -> (format:GLenum, src_format:GLenum=GL_INVALID_ENUM, src_type:GLenum=GL_INVALID_ENUM, compressed:=false) {
    using Texture_Format;

    format : GLenum;

    if tf == {
        case R8;
            assert(srgb == false);
            return GL_R8, src_format = GL_RED, src_type = GL_UNSIGNED_BYTE;
        case RG8;
            assert(srgb == false);
            return GL_RG8, src_format = GL_RG, src_type = GL_UNSIGNED_BYTE;
        case RGB8;
            if srgb format = GL_SRGB8;
            else format = GL_RGB8;
            return format, src_format = GL_RGB, src_type = GL_UNSIGNED_BYTE;
        case RGBA8;
            if srgb format = GL_SRGB8_ALPHA8;
            else format = GL_RGBA8;
            return format, src_format = GL_RGBA, src_type = GL_UNSIGNED_BYTE;
        case BGRA8;
            if srgb format = GL_SRGB8_ALPHA8;
            else format = GL_RGBA8;
            return format, src_format = GL_BGRA, src_type = GL_UNSIGNED_BYTE;
        case B5G6R5;
            if srgb format = GL_SRGB;
            else format = GL_RGB;
            return format, src_format = GL_BGR, src_type = GL_UNSIGNED_SHORT_5_6_5;
        case RGB10A2;
            assert(srgb == false);
            return GL_RGB10_A2, src_format = GL_RGBA, src_type = GL_UNSIGNED_INT_10_10_10_2;
        case R16;
            assert(srgb == false);
            return GL_R16, src_format = GL_RED, src_type = GL_UNSIGNED_SHORT;

        case R16F;
            assert(srgb == false);
            return GL_R16F, src_format = GL_RED, src_type = GL_HALF_FLOAT;
        case RG16F;
            assert(srgb == false);
            return GL_RG16F, src_format = GL_RG, src_type = GL_HALF_FLOAT;
        case RGBA16F;
            assert(srgb == false);
            return GL_RGBA16F, src_format = GL_RGBA, src_type = GL_HALF_FLOAT;
        case R32F;
            assert(srgb == false);
            return GL_R32F, src_format = GL_RED, src_type = GL_FLOAT;
        case RG32F;
            assert(srgb == false);
            return GL_RG32F, src_format = GL_RG, src_type = GL_FLOAT;
        case RGBA32F;
            assert(srgb == false);
            return GL_RGBA32F, src_format = GL_RGBA, src_type = GL_FLOAT;
        case RG11B10F;
            assert(srgb == false);
            return GL_R11F_G11F_B10F, src_format = GL_RGB, src_type = GL_UNSIGNED_INT_10F_11F_11F_REV;  // @@ Not tested.
        case RGB9E5F;
            assert(srgb == false);
            return GL_RGB9_E5, src_format = GL_RGB, src_type = GL_UNSIGNED_INT_5_9_9_9_REV; // @@ Not tested.

        case R16I;
            assert(srgb == false);
            return GL_R16I, src_format = GL_RED, src_type = GL_SHORT;
        case RG16I;
            assert(srgb == false);
            return GL_RG16I, src_format = GL_RG, src_type = GL_SHORT;
        case RGBA16I;
            assert(srgb == false);
            return GL_RGBA16I, src_format = GL_RGBA, src_type = GL_SHORT;
        case R32I;
            assert(srgb == false);
            return GL_R32I, src_format = GL_RED, src_type = GL_INT;
        case RG32I;
            assert(srgb == false);
            return GL_RG32I, src_format = GL_RG, src_type = GL_INT;
        case RGBA32I;
            assert(srgb == false);
            return GL_RGBA32I, src_format = GL_RGBA, src_type = GL_INT;

        case BC1;
            if srgb format = GL_COMPRESSED_SRGB_S3TC_DXT1_EXT;
            else format = GL_COMPRESSED_RGB_S3TC_DXT1_EXT;
            return format, compressed = true;
        case BC3;
            if srgb format = GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT;
            else format = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
            return format, compressed = true;
        case BC4;
            assert(srgb == false);
            return GL_COMPRESSED_RED_RGTC1, compressed = true;
        case BC5;
            assert(srgb == false);
            return GL_COMPRESSED_RG_RGTC2, compressed = true;
        case BC6;
            assert(srgb == false);
            return GL_COMPRESSED_RGB_BPTC_UNSIGNED_FLOAT, compressed = true;
        case BC7;
            if srgb format = GL_COMPRESSED_SRGB_ALPHA_BPTC_UNORM;
            else format = GL_COMPRESSED_RGBA_BPTC_UNORM;
            return format, compressed = true;

        case D16;
            assert(srgb == false);
            return GL_DEPTH_COMPONENT16, src_format=GL_DEPTH_COMPONENT, src_type=GL_UNSIGNED_SHORT;
        case D24S8;
            assert(srgb == false);
            return GL_DEPTH24_STENCIL8, src_format=GL_DEPTH_STENCIL, src_type=GL_UNSIGNED_INT_24_8;
        case D32F;
            assert(srgb == false);
            //if NV_depth_buffer_float return GL_DEPTH_COMPONENT32F_NV, src_format=GL_DEPTH_COMPONENT, src_type=GL_FLOAT; // IC: This allows unclamped depth values.
            return GL_DEPTH_COMPONENT32F, src_format=GL_DEPTH_COMPONENT, src_type=GL_FLOAT;
        case D32FS8;
            assert(srgb == false);
            //if NV_depth_buffer_float return GL_DEPTH32F_STENCIL8_NV, src_format=GL_DEPTH_STENCIL, src_type=GL_FLOAT_32_UNSIGNED_INT_24_8_REV; // IC: This allows unclamped depth values.
            return GL_DEPTH32F_STENCIL8, src_format=GL_DEPTH_STENCIL, src_type=GL_FLOAT_32_UNSIGNED_INT_24_8_REV;

        case;
            assert(false, "Unsupported texture format %d.", tf);
    }


    return GL_INVALID_ENUM;
}

backend_realloc_texture :: (texture: *Texture, bitmap: *Bitmap) {
    // This routine needs to make sure we have enough space to store the bitmap.
    // But, that is handled invisibly by GL, so, we just make sure we have a handle.
    if !texture.gl_handle {
        glGenTextures(1, *texture.gl_handle);
        glBindTexture(GL_TEXTURE_2D, texture.gl_handle);

        // Clamp to edge due to alpha textures.
        // @Temporary. We'll want to provide more control over this.
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,     GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,     GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    }
}

backend_set_render_target :: (info: *Window_Info) {
    if info.backend_initted_for_this_window {
        #if OS == .WINDOWS {
            success := wglMakeCurrent(info.specific.hdc, the_gl_context);
            errno := GetLastError();
        } else #if OS == .LINUX {
            LD.make_current(info.window);
        } else #if OS == .MACOS {
            // Get the GL view from the window.
            // This relies on this window having a content view with OpenGL support (eg. as created by Window_Creation).
            view := NSWindow.contentView(info.window);
            assert(view != null);
            NSOpenGLContext.setView(the_gl_context, view);
        } else {
            assert(false);
        }
    } else {
        backend_init(info);
        info.backend_initted_for_this_window = true;
    }

    glViewport(0, 0, xx info.window_width, xx info.window_height);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glDrawBuffer(GL_BACK);
}

backend_create_render_target :: (texture: *Texture) {
    // Get the currently bound texture so we can restore it.
    old_map: GLuint;
    glActiveTexture(GL_TEXTURE0);
    glGetIntegerv(GL_TEXTURE_BINDING_2D, xx *old_map);
    defer glBindTexture(GL_TEXTURE_2D, old_map);

    glGenTextures(1, *texture.gl_handle);
    glBindTexture(GL_TEXTURE_2D, texture.gl_handle);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, xx texture.width, xx texture.height, 0, GL_RGBA, GL_UNSIGNED_BYTE, null);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);  // This has no mipmaps.
}

backend_set_render_target :: (texture: *Texture) {
    if !main_fbo_handle glGenFramebuffers(1, *main_fbo_handle);
    glBindFramebuffer(GL_DRAW_FRAMEBUFFER, main_fbo_handle);

    glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture.specific.gl_handle, 0);

    glViewport(0, 0, xx texture.width, xx texture.height);
}

backend_update_texture :: (texture: *Texture, bitmap: *Bitmap) {
    internal_format, gl_format, gl_type, compressed := get_ogl_format(texture.format, (texture.flags & .sRGB) != 0);

    texture_target :: GL_TEXTURE_2D;
    glBindTexture(texture_target, texture.gl_handle);

    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(texture_target, 0, xx internal_format, xx bitmap.width, xx bitmap.height, 0, gl_format, gl_type, bitmap.data.data);
    // print("Updating texture %. Size: % x %, format: % \n", texture.gl_handle, bitmap.width, bitmap.height, gl_format);
    // glFlush();

    //    resource_size := update_texture_2d(map, compressed, gl_format, gl_type, bittexture.data);
    //    assert (texture.resource_size == xx resource_size);
}

backend_use_shader :: (s: *Shader) {
    if s.alpha_blend {
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glEnable(GL_BLEND);
    } else {
        glDisable(GL_BLEND);
    }

    glUseProgram(s.gl_handle);
}

backend_set_texture :: (shader: *Shader, texture: *Texture) {
    loc := get_uniform_location(shader.gl_handle, "diffuse_texture");

    if loc < 0 {
        log_error("Unable to find 'diffuse_texture' in the current shader.");
        return;
    }

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, texture.gl_handle);  // Bind handle to slot 0.
    glUniform1i(loc, 0);
}

backend_resize_render_target :: (info: Window_Info) {
    if context.simp.current_window_info.window == info.window {
        glViewport(0, 0, xx info.window_width, xx info.window_height);
        #if OS == .MACOS {
            NSOpenGLContext.update(the_gl_context);
        }
    }
}

backend_tweak_projection_matrix :: (m: *Matrix4) {
    if context.simp.texture_render_target {
        m._21 *= -1;
        m._22 *= -1;
        m._23 *= -1;
        m._24 *= -1;
    }
}

#if OS == .WINDOWS {
    Backend_Platform_Specific :: struct { }

    Window_Info_Platform_Specific :: struct {
        hdc:   HDC;
    }

    windows_change_pixel_format :: (hdc: HDC) {
        assert(the_hdc_for_pixel_format_cloning != null);

        pfd: PIXELFORMATDESCRIPTOR;
        format := GetPixelFormat(the_hdc_for_pixel_format_cloning);
        result := DescribePixelFormat(the_hdc_for_pixel_format_cloning, format, size_of(type_of(pfd)), *pfd);
        assert(result != 0);

        SetPixelFormat(hdc, format, *pfd);
    }
}

#if OS == .LINUX {
    Backend_Platform_Specific :: struct {
    }

    Window_Info_Platform_Specific :: struct {
    }
}

#if OS == .MACOS {
    Backend_Platform_Specific :: struct {
        // @Incomplete
    }

    Window_Info_Platform_Specific :: struct {
        // @Incomplete
    }
}
