#module_parameters (render_api := Render_API.OPENGL) {
    Render_API :: enum {
        NONE;
        SOFTWARE;
        OPENGL;
        METAL;
    }
};

#scope_module

#if OS == .WINDOWS {
    // Maybe we should clean this up and not pull all of Windows into the namespace.
    #import "Windows";
} else #if OS == .LINUX {
    LD :: #import "Linux_Display";
    #assert(LD.JAI_STDLIB_INTEROP);
} else #if OS == .MACOS {
    #import "Objective_C";
    #import "Objective_C/AppKit";
}

#if render_api == .OPENGL {
    #if OS != .LINUX {
        #import "GL"(DEFAULT_MSAA = 0);
    } else {
        GL :: #import "Linux_Display/GL";
        using GL.gl_procs;
        DumpGLErrors :: GL.DumpGLErrors;
    }

    #load "backend/gl.jai";
}

#if render_api == .METAL {
    #import "Metal";
}

#import "Basic";
#import "Math";
#import "String";
#import "Bit_Operations";
#import "Thread";

// Bitmap loading and saving:
#import "stb_image";
#import "stb_image_write";
#import "stb_image_resize";

#scope_export

set_render_target :: (window: Window_Type) {
    CheckInit();

    immediate_flush();

    state.current_shader        = null;
    state.texture_render_target = null;

    info, added := find_or_add_window_info(window);
    if added {
        update_window(window);
    }

    backend_set_render_target(info);

    state.current_window_info = << info;
}

set_render_target :: (texture: *Texture) {
    // Check texture.flags for Render_Target?

    CheckInit();

    if !texture {
        log_error("Attempt to set_render_target on a null texture!\n");
        return;
    }

    immediate_flush();
    state.current_shader = null;

    state.texture_render_target = texture;
    backend_set_render_target(texture);
}

set_color_map :: (color_map: [] Vector4) {
    COLOR_MAP = color_map;
}

update_window :: (window: Window_Type) {
    CheckInit();

    info := find_window_info(window);
    if !info return;  // Ignore windows we don't understand.

    window_width, window_height := get_render_dimensions(window);
    info.window_width  = window_width;
    info.window_height = window_height;

    c := *state.current_window_info;
    if c.window == window {
        if (window_width != c.window_width) || (window_height != c.window_height) {
            backend_resize_render_target(<<info);

            // If the user changes the window after setting a shader,
            // the projection will be out-of-date, so, update it here.
            // We check state.current_shader because immediate_set_2d_projection will error
            // if it is not set.
            if !state.texture_render_target {
                if state.current_shader  immediate_set_2d_projection(window_width, window_height);
            }
        }

        state.current_window_info = << info;
    }
}

draw_text :: (font: *Dynamic_Font, x: s64, y: s64, text: string, color: u8) -> width: s64 {
    // @Cleanup: generate_quads should return quads in a threadsafe way?
    width := prepare_text(font, text);
    draw_prepared_text(font, x, y, color);
    return width;
}

draw_prepared_text :: (font: *Dynamic_Font, x: s64, y: s64, color: u8) {
    generate_quads_for_prepared_text(font, x, y);
    draw_generated_quads(font, color);
}

Window_Info :: struct {
    window: Window_Type;
    window_width, window_height: s32;

    backend_initted_for_this_window := false;
    specific: Window_Info_Platform_Specific;
}

window_infos: [..] Window_Info;

set_scissor :: (x0: s32, y0: s32, x1: s32, y1: s32) {
    immediate_flush();
    glEnable(GL_SCISSOR_TEST);
    glScissor(x0, y0, cast(u32)(x1-x0), cast(u32)(y1-y0));
}

clear_scissor :: () {
    glDisable(GL_SCISSOR_TEST);
}

set_anti_aliasing :: (value: Font_Anti_Aliasing) {
    font_anti_aliasing = value;
}

set_hinting :: (value: bool) {
    font_hinting = value;
}

// @Cleanup: This has a lot of overlap with Window_Creation’s "get_dimensions"
get_render_dimensions :: (window: Window_Type) -> (width: s32, height: s32) {
    #if OS == .WINDOWS {
        c: RECT;
        success := GetClientRect(window, *c);
        if !success  return 0, 0;

        return cast(s32)(c.right - c.left), cast(s32)(c.bottom - c.top);
    } else #if OS == .LINUX {
        w, h := LD.get_render_dimensions(window);
        return w, h;
    } else #if OS == .MACOS {
        view := NSWindow.contentView(window);
        frame := NSView.frame(view);
        fb := NSView.convertRectToBacking(view, frame); // :MacHighResDisplays
        return cast(s32) fb.size.width, cast(s32) fb.size.height;
    } else {
        assert(false);
    }
}

//
// Those are the preliminaries. Here are this module's own files:
//

#load "bitmap.jai";
#load "texture.jai";
#load "texture_format.jai";
#load "shader.jai";
#load "immediate.jai";
#load "font.jai";

#scope_module
find_window_info :: (window: Window_Type) -> *Window_Info {
    for * window_infos  if it.window == window  return it;
    return null;
}

COLOR_MAP: [] Vector4;
font_anti_aliasing: Font_Anti_Aliasing = .lcd;
font_hinting := true;

#scope_file

find_or_add_window_info :: (window: Window_Type) -> *Window_Info, bool {
    for * window_infos  if it.window == window  return it, false;

    info := array_add(*window_infos);
    info.window = window;
    return info, true;
}


