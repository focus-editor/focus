//
// This is a simple framework for drawing graphics that you can use
// for most programs that are not too demanding. Or, you could copy this module
// and customize it to become what you want.
//
// Generally, doing graphics is super complicated and hairy and you have to
// think about a lot of annoying things. This framework is an experiment in asking,
// if you aren't trying to maximize performance, how simple can we make it?
// The answer is going to be, probably still not as simple as we'd like,
// because there is too much innate complication arbitrarily embedded in
// the systems we need to use in order to draw things. But, in graphics a great deal
// of complexity comes from trying to make things as fast as possible, so, we should
// be able to shave most of that off.
//
// One of the biggest problems of modern software is that people think the software
// should always be getting "better" in the sense that it tries to do every little
// thing that everyone wants. But this leads to increasing complexity, step by step.
// It's like playing Go, where, at first just putting a stone here or over there
// seemed like small, uncostly moves that provided big benefits, but now they
// have grown into a huge infrastructure that has to be maintained, and that
// maintenance itself adds more structure, and so much effort needs to be put into
// your understanding that structure that has been built up, and if your understanding
// is too incomplete then the structure will collapse.
//
// So we draw a certain very close boundary over what we are attempting to do here.
// For many simple applications, this module will be enough. Maybe someone can make
// another module called Simp+ that does more, and does introduce more constraints
// on the application, but they are not too bad, and upgrading from Simp to Simp+
// doesn't take much more than an afternoon, or whatnot. But for now we just say,
// there's a line, if your program is inside the line you can use this; once it grows
// outside the line, you probably want to switch to a bigger framework or engine
// that is much more complicated.
//
Render_API :: enum {
    NONE;
    SOFTWARE;
    OPENGL;
    METAL;
}

#module_parameters (render_api := Render_API.OPENGL);

#scope_module

#if OS == .WINDOWS {
    // Maybe we should clean this up and not pull all of Windows into the namespace.
    #import "Windows";
} else #if OS == .LINUX {
    #import "X11";
} else #if OS == .MACOS {
    #import "Objective_C";
}

#if render_api == .OPENGL {
    #import "GL";

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

// Document: New init API ... Window creation...

// @Functionality: Create texture render targets. Switch between texture render targets.
// Threadsafety and cross-threadness of Window_Info.
simp_init :: (window: Window_Type, window_width: s32 = -1, window_height: s32 = -1, render_width: s32 = -1, render_height: s32 = -1, windowed := true, vsync := true) #deprecated "Use set_render_target instead. Explicit init is no longer required." {
    info := find_or_add_window_info(window);

    if (window_width < 0) || (window_height < 0) {
        window_width, window_height = get_render_dimensions(window);
    }

    info.window        = window;
    info.window_width  = window_width;
    info.window_height = window_height;

    backend_init(info);
}

set_render_target :: (window: Window_Type) {
    CheckInit();

    immediate_flush();
    backend_flush();

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
    backend_flush();
    state.current_shader = null;

    state.texture_render_target = texture;
    backend_set_render_target(texture);
}

update_window :: (window: Window_Type) {
    CheckInit();

    info := find_or_add_window_info(window);
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
            if !context.simp.texture_render_target {
                if state.current_shader  immediate_set_2d_projection(window_width, window_height);
            }
        }

        state.current_window_info = << info;
    }
}

draw_text :: (font: *Dynamic_Font, x: s64, y: s64,
              text: string, color := Vector4.{1,1,1,1}, effects: Font_Effects = 0) {
    // @Cleanup: generate_quads should return quads in a threadsafe way?
    prepare_text(font, text);
    generate_quads_for_prepared_text(font, x, y, effects);
    draw_generated_quads(font, color);
}

draw_prepared_text :: (font: *Dynamic_Font, x: s64, y: s64, color := Vector4.{1, 1, 1, 1}, effects: Font_Effects = 0) {
    generate_quads_for_prepared_text(font, x, y, effects);
    draw_generated_quads(font, color);
}

Window_Info :: struct {
    window: Window_Type;
    window_width, window_height: s32;

    backend_initted_for_this_window := false;
    specific: Window_Info_Platform_Specific;
}

window_infos: [..] Window_Info;

#scope_export
set_scissor :: (x0: s32, y0: s32, x1: s32, y1: s32) {
    immediate_flush();
    glEnable(GL_SCISSOR_TEST);
    glScissor(x0, y0, cast(u32)(x1-x0), cast(u32)(y1-y0));
}

clear_scissor :: () {
    glDisable(GL_SCISSOR_TEST);
}

// @Cleanup: This has a lot of overlap with Window_Creation’s "get_dimensions"
get_render_dimensions :: (window: Window_Type) -> (width: s32, height: s32) {
    #if OS == .WINDOWS {
        c: RECT;
        success := GetClientRect(window, *c);
        if !success  return 0, 0;

        return cast(s32)(c.right - c.left), cast(s32)(c.bottom - c.top);
    } else #if OS == .LINUX {
        root: Window;
        x, y: s32;
        width, height: u32;
        border_width, depth_return: u32;

        status := XGetGeometry(x_global_display, window, *root, *x, *y, *width, *height, *border_width, *depth_return);
        return cast(s32) width, cast(s32) height;
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
#scope_file

find_or_add_window_info :: (window: Window_Type) -> *Window_Info, bool {
    for * window_infos  if it.window == window  return it, false;

    info := array_add(*window_infos);
    info.window = window;
    return info, true;
}


