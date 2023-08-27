GL_BACKEND_CHOICE :: enum {
    AUTOSELECT;
    GLX;
    EGL;
}

GL_BACKEND :: enum {
    UNINITIALIZED;
    GLX;
    EGL;
}

GL_Display :: struct {
    type : GL_BACKEND = .UNINITIALIZED;
    union {
        ctx: *void;
        glx: struct {
            ctx: X11.GLXContext;
            cnf: X11.GLXFBConfig;
        }
        egl: struct {
            ctx: *void;
            cnf: *void;
            dpy: *void;
        }
    }
    ops: GL_Ops;
}

GL_Window :: struct {
    type : GL_BACKEND = .UNINITIALIZED;
    union {
        glx: struct {
            win: X11.GLXWindow;
        }
        egl: struct {
            native: *void;  /* wl_egl_window or X11.Window */
            surface: *void;
        }
    }
}

get_gl_context :: (display: *Display) -> *void {
    return display.base.gl.ctx;
}

get_gl_proc_address_function :: (display: *Display) -> GL.GetProcAddressFunction {
    return display.base.gl.ops.get_proc_address;
}

get_gl_proc_address_function :: (window: *Window) -> GL.GetProcAddressFunction {
    return window.base.display.base.gl.ops.get_proc_address;
}

create_gl_context :: inline (display: *Display, major_version := 0, minor_version := 0, compatibility := false, debug := false) {
    if gl_initialized(display) return;

    if display.base.type == {
        case X11_Display; {
            if display.base.desired_gl_backend == {
                case .AUTOSELECT; #through;
                case .GLX; X11_GLX_Ops.create_context(display, major_version, minor_version, compatibility, debug);
                case .EGL; X11_EGL_Ops.create_context(display, major_version, minor_version, compatibility, debug);
            }
        }
        case Wayland_Display; Wayland_EGL_Ops.create_context(display, major_version, minor_version, compatibility, debug);
    }
}

create_gl_surface :: inline (window: *Window) {
    if gl_initialized(window) return;

    window.base.display.base.gl.ops.create_surface(window);
}

make_current :: inline (window: *Window) {
    window.base.display.base.gl.ops.make_current(window);
}

swap_buffers :: inline (window: *Window) {
    window.base.display.base.gl.ops.swap_buffers(window);
}

gl_initialized :: (display: *Display) -> bool {
    return display.base.gl.type != .UNINITIALIZED;
}

gl_initialized :: (window: *Window) -> bool {
    return window.base.gl.type != .UNINITIALIZED;
}

#scope_file
#import "Basic";
#import "POSIX";

GL :: #import "GL";

GL_Ops :: struct {
    create_context: (display: *Display, major_version := 0, minor_version := 0, compatibility := false, debug := false);
    create_surface: (window: *Window);
    make_current: (window: *Window);
    swap_buffers: (window: *Window);

    get_proc_address: GL.GetProcAddressFunction;
}

X11_GLX_Ops :: GL_Ops.{
    create_context = (display: *Display, major_version := 0, minor_version := 0, compatibility := false, debug := false) {
        x11_check_usage(display);

        if gl_initialized(display) return;

        gl := *display.base.gl;
        gl.type = .GLX;
        gl.glx.ctx, gl.glx.cnf = GL.glx_create_context(xx major_version, xx minor_version, compatibility, debug);
        gl.ops = X11_GLX_Ops;
        gl.ops.get_proc_address = X11.glXGetProcAddress;

        GL.gl_load(*GL.gl, X11.glXGetProcAddress);
    },

    create_surface = (window: *Window) {
        x11_check_usage(null, window);

        dpy     := window.x11.display.handle;
        glx_cnf := window.base.display.base.gl.glx.cnf;

        gl := *window.base.gl;
        gl.type = .GLX;
        gl.glx.win = X11.glXCreateWindow(dpy, glx_cnf, window.x11.handle, null);
    },

    make_current = (window: *Window) {
        x11_check_usage(null, window);

        dpy     := window.x11.display.handle;
        glx_win := window.base.gl.glx.win;
        glx_ctx := window.x11.display.base.gl.glx.ctx;
        X11.XLockDisplay(dpy);
        X11.glXMakeCurrent(dpy, glx_win, glx_ctx);
        X11.XUnlockDisplay(dpy);
    },

    swap_buffers = (window: *Window) {
        x11_check_usage(null, window);

        dpy     := window.x11.display.handle;
        glx_win := window.base.gl.glx.win;
        X11.glXSwapBuffers(dpy, glx_win);
    }
};

X11_EGL_Ops :: GL_Ops.{
    create_context = (display: *Display, major_version := 0, minor_version := 0, compatibility := false, debug := false) {
        x11_check_usage(display);

        if gl_initialized(display) return;

        EGL.init();

        gl := *display.base.gl;
        gl.type = .EGL;
        gl.egl.dpy, gl.egl.ctx, gl.egl.cnf = EGL.create_context(
            display.x11.handle, major_version, minor_version, compatibility, debug);
        gl.ops = X11_EGL_Ops;
        gl.ops.get_proc_address = EGL.GetProcAddress;

        // @TODO - do we need to MakeCurrent something before?
        GL.gl_load(*GL.gl, EGL.GetProcAddress);
    },

    create_surface = (window: *Window) {
        x11_check_usage(null, window);

        dgl := *window.base.display.base.gl;
        wgl := *window.base.gl;

        wgl.type = .EGL;
        wgl.egl.native = xx window.x11.handle;
        wgl.egl.surface = EGL.CreateWindowSurface(dgl.egl.dpy, dgl.egl.cnf, wgl.egl.native, null);
    },

    make_current = (window: *Window) {
        x11_check_usage(null, window);

        wgl := *window.base.gl.egl;
        dgl := *window.base.display.base.gl.egl;
        X11.XLockDisplay(window.x11.display.handle);
        EGL.MakeCurrent(dgl.dpy, wgl.surface, wgl.surface, dgl.ctx);
        X11.XLockDisplay(window.x11.display.handle);
    },

    swap_buffers = (window: *Window) {
        x11_check_usage(null, window);

        wgl := *window.base.gl.egl;
        dgl := *window.base.display.base.gl.egl;
        EGL.SwapBuffers(dgl.dpy, wgl.surface);
    }
};

Wayland_EGL_Ops :: GL_Ops.{
    create_context = (display: *Display, major_version := 0, minor_version := 0, compatibility := false, debug := false) {
        wl_check_usage(display);

        if gl_initialized(display) return;

        EGL.init();

        bd: *Base_Display = display;
        wld := *display.wld;
        gl := *bd.gl;

        gl.type = .EGL;
        gl.egl.dpy, gl.egl.ctx, gl.egl.cnf = EGL.create_context(
            display.wld.handle, major_version, minor_version, compatibility, debug);
        gl.ops = Wayland_EGL_Ops;
        gl.ops.get_proc_address = EGL.GetProcAddress;

        wls := wl_compositor.create_surface(wld.compositor);
        wln := wl_egl_window.create(wls, 1, 1);
        egs := EGL.CreateWindowSurface(gl.egl.dpy, gl.egl.cnf, wln, null);
        EGL.MakeCurrent(gl.egl.dpy, egs, egs, gl.egl.ctx);
        GL.gl_load(*GL.gl, EGL.GetProcAddress);
        EGL.MakeCurrent(gl.egl.dpy, EGL.NO_SURFACE, EGL.NO_SURFACE, EGL.NO_CONTEXT);
        EGL.DestroySurface(gl.egl.dpy, egs);
        wl_egl_window.destroy(wln);
        wl_surface.destroy(wls);
    },

    create_surface = (window: *Window) {
        wl_check_usage(null, window);

        ww  := *window.wld;
        wgl := *window.base.gl;
        dgl := *window.base.display.base.gl;

        wgl.type = .EGL;
        wgl.egl.native = wl_egl_window.create(ww.handle, ww.buffer_width, ww.buffer_height);
        wgl.egl.surface = EGL.CreateWindowSurface(dgl.egl.dpy, dgl.egl.cnf, wgl.egl.native, null);
        EGL.MakeCurrent(dgl.egl.dpy, wgl.egl.surface, wgl.egl.surface, dgl.egl.ctx);
        wl_window_resize_viewport(ww);
        wl_surface.damage(ww.handle, 0, 0, ww.window_width, ww.window_height);
        wl_surface.commit(ww.handle);
    },

    make_current = (window: *Window) {
        wl_check_usage(null, window);

        wgl := *window.base.gl.egl;
        dgl := *window.base.display.base.gl.egl;
        EGL.MakeCurrent(dgl.dpy, wgl.surface, wgl.surface, dgl.ctx);
    },

    swap_buffers = (window: *Window) {
        wl_check_usage(null, window);

        wgl := *window.base.gl.egl;
        dgl := *window.base.display.base.gl.egl;
        EGL.SwapBuffers(dgl.dpy, wgl.surface);
    }
};

EGL : struct {
    major: s32;
    minor: s32;

    init :: () -> bool {
        dlerror();
        lib := dlopen("libEGL.so", RTLD_NOW);
        if !lib {
            log_error("Failed to load libEGL.so: %\n", to_string(dlerror()));
            return false;
        }

        #insert #run -> string {
            tis := cast(*Type_Info_Struct) type_info(type_of(EGL));
            b: String_Builder;
            tpl :: #string __end
                dlerror();
                EGL.%1 = dlsym(lib, "egl%1");
                assert(!!EGL.%1, "Failed to resolve function 'egl%1': %%\n", to_string(dlerror()));
            __end

            for m : tis.members {
                if m.type.type != .PROCEDURE continue;
                if m.flags & .CONSTANT continue;

                pi := cast(*Type_Info_Procedure) m.type;
                if !(pi.procedure_flags & .IS_C_CALL) continue;

                print_to_builder(*b, tpl, m.name);
            }

            return builder_to_string(*b);
        };

        return true;
    }

    create_context :: (native_display: *void, major_version := 0, minor_version := 0, compatibility := false, debug := false) -> *void, *void, *void {
        using EGL;

        n: s32;

        egl_dpy := GetDisplay(native_display);
        assert(egl_dpy != NO_DISPLAY, "egl_dpy=%, native_display=%", egl_dpy, native_display);

        if !Initialize(egl_dpy, *major, *minor)
            assert(false, "Initialize() failed: %", formatInt(GetError(), base=16));

        BindAPI(OPENGL_API);

        config_attribs : []s32 = .[
            SURFACE_TYPE, WINDOW_BIT,
            RED_SIZE, 8,
            GREEN_SIZE, 8,
            BLUE_SIZE, 8,
            // ALPHA_SIZE, 8,                   // this makes the entire window translucent
            RENDERABLE_TYPE, OPENGL_BIT,
            NONE
        ];
        egl_cnf: *void;
        ChooseConfig(egl_dpy, config_attribs.data, *egl_cnf, 1, *n);

        context_attribs: [9]s32;
        attr_count := 0;

        if major_version > 0 {
            context_attribs[attr_count + 0] = CONTEXT_MAJOR_VERSION;
            context_attribs[attr_count + 1] = xx major_version;
            context_attribs[attr_count + 2] = CONTEXT_MINOR_VERSION;
            context_attribs[attr_count + 3] = xx minor_version;
            attr_count += 4;
        }

        context_attribs[attr_count + 0] = CONTEXT_OPENGL_PROFILE_MASK;
        if compatibility  context_attribs[attr_count + 1] = CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT;
        else              context_attribs[attr_count + 1] = CONTEXT_OPENGL_CORE_PROFILE_BIT;
        attr_count += 2;

        if debug {
            context_attribs[attr_count + 0] = CONTEXT_OPENGL_DEBUG;
            context_attribs[attr_count + 1] = TRUE;
            attr_count += 2;
        }

        context_attribs[attr_count] = NONE;

        egl_ctx := CreateContext(egl_dpy, egl_cnf, NO_CONTEXT, context_attribs.data);

        return egl_dpy, egl_ctx, egl_cnf;
    }

    /*
     * Minimal EGL subset for editor use
     */
    TRUE                                        : s32 : 1;
    FALSE                                       : s32 : 0;
    NONE                                        : s32 : 0x3038;
    ALPHA_SIZE                                  : s32 : 0x3021;
    RED_SIZE                                    : s32 : 0x3024;
    GREEN_SIZE                                  : s32 : 0x3023;
    BLUE_SIZE                                   : s32 : 0x3022;
    SURFACE_TYPE                                : s32 : 0x3033;
    WINDOW_BIT                                  : s32 : 0x0004;
    OPENGL_API                                  : s32 : 0x30A2;
    OPENGL_BIT                                  : s32 : 0x0008;
    RENDERABLE_TYPE                             : s32 : 0x3040;
    CONTEXT_OPENGL_PROFILE_MASK                 : s32 : 0x30FD;
    CONTEXT_OPENGL_CORE_PROFILE_BIT             : s32 : 0x00000001;
    CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT    : s32 : 0x00000002;
    CONTEXT_OPENGL_DEBUG                        : s32 : 0x31B0;
    CONTEXT_MAJOR_VERSION                       : s32 : 0x3098;
    CONTEXT_MINOR_VERSION                       : s32 : 0x30FB;

    NO_CONTEXT : *void : null;
    NO_DISPLAY : *void : null;
    NO_SURFACE : *void : null;

    GetDisplay          : (display_id: *void) -> *void #c_call;
    GetProcAddress      : (procname: *u8) -> *void #c_call;
    GetError            : () -> s32 #c_call;
    BindAPI             : (api: s32) -> s32 #c_call;
    Initialize          : (dpy: *void, major: *s32, minor: *s32) -> s32 #c_call;
    ChooseConfig        : (dpy: *void, attrib_list: *s32, configs: **void, config_size: s32, num_config: *s32) -> s32 #c_call;
    MakeCurrent         : (dpy: *void, draw: *void, read: *void, ctx: *void) -> s32 #c_call;
    SwapBuffers         : (dpy: *void, surface: *void) -> s32 #c_call;
    CreateWindowSurface : (dpy: *void, config: *void, win: *void, attrib_list: *s32) -> *void #c_call;
    CreateContext       : (dpy: *void, config: *void, share_context: *void, attrib_list: *s32) -> *void #c_call;
    DestroyContext      : (dpy: *void, ctx: *void) -> s32 #c_call;
    DestroySurface      : (dpy: *void, surface: *void) -> s32 #c_call;
};
