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
    using data: union {
        ctx: *void;
        glx: struct {
            ctx: *void;
            cnf: *void;
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
            win: u64;
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
        case XCB_Display; {
            if display.base.init_flags & .XCB_Pure {
                XCB_EGL_Ops.create_context(display, major_version, minor_version, compatibility, debug);
            } else if display.base.desired_gl_backend == {
                case .AUTOSELECT; #through;
                case .GLX; XCB_GLX_Ops.create_context(display, major_version, minor_version, compatibility, debug);
                case .EGL; XCB_EGL_Ops.create_context(display, major_version, minor_version, compatibility, debug);
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
        GL.wsi_load(*GLX);

        gl := *display.base.gl;
        gl.type = .GLX;
        gl.ops = X11_GLX_Ops;
        gl.ops.get_proc_address = GLX.GetProcAddress;

        x11_display := *display.x11;
        dpy := x11_display.handle;
        X11.XLockDisplay(dpy); {
            gl.glx.ctx, gl.glx.cnf = GLX.create_context(
                *GLX,
                dpy, X11.DefaultScreen(dpy),
                xx major_version, xx minor_version,
                compatibility, debug);
            win := create_dummy_x11_window(x11_display);
            glx_win := GLX.CreateWindow(dpy, gl.glx.cnf, win, null);
            GLX.MakeContextCurrent(dpy, glx_win, glx_win, gl.glx.ctx);
            GL.gl_load(*GL.gl_procs, GLX.GetProcAddress);
            GLX.MakeContextCurrent(dpy, 0, 0, null);
            GLX.DestroyWindow(dpy, glx_win);
            X11.XDestroyWindow(dpy, win);
        } X11.XUnlockDisplay(dpy);
    },

    create_surface = (window: *Window) {
        x11_check_usage(null, window);

        dpy     := window.x11.display.handle;
        glx_cnf := window.base.display.base.gl.glx.cnf;
        glx_ctx := window.base.display.base.gl.ctx;

        gl := *window.base.gl;
        gl.type = .GLX;
        gl.glx.win = GLX.CreateWindow(dpy, glx_cnf, window.x11.handle, null);

        if GLX.SwapIntervalEXT {
            GLX.MakeCurrent(dpy, gl.glx.win, glx_ctx);
            GLX.SwapIntervalEXT(dpy, gl.glx.win, 0);
        }
    },

    make_current = (window: *Window) {
        x11_check_usage(null, window);

        dpy     := window.x11.display.handle;
        glx_win := window.base.gl.glx.win;
        glx_ctx := window.x11.display.base.gl.glx.ctx;
        X11.XLockDisplay(dpy);
        GLX.MakeCurrent(dpy, glx_win, glx_ctx);
        X11.XUnlockDisplay(dpy);
    },

    swap_buffers = (window: *Window) {
        x11_check_usage(null, window);

        dpy     := window.x11.display.handle;
        glx_win := window.base.gl.glx.win;
        GLX.SwapBuffers(dpy, glx_win);
    }
};

X11_EGL_Ops :: GL_Ops.{
    create_context = (display: *Display, major_version := 0, minor_version := 0, compatibility := false, debug := false) {
        x11_check_usage(display);

        if gl_initialized(display) return;
        GL.wsi_load(*EGL);

        gl := *display.base.gl;
        gl.type = .EGL;
        gl.egl.dpy, gl.egl.ctx, gl.egl.cnf = EGL.create_context(
            *EGL,
            display.x11.handle, 0, null,
            major_version, minor_version,
            compatibility, debug);
        gl.ops = X11_EGL_Ops;
        gl.ops.get_proc_address = EGL.GetProcAddress;

        x11_display := *display.x11;
        dpy := x11_display.handle;
        X11.XLockDisplay(dpy); {
            win := create_dummy_x11_window(x11_display);
            egs := EGL.CreateWindowSurface(gl.egl.dpy, gl.egl.cnf, xx win, null);
            EGL.MakeCurrent(gl.egl.dpy, egs, egs, gl.egl.ctx);
            GL.gl_load(*GL.gl_procs, EGL.GetProcAddress);
            EGL.MakeCurrent(gl.egl.dpy, EGL.NO_SURFACE, EGL.NO_SURFACE, EGL.NO_CONTEXT);
            EGL.DestroySurface(gl.egl.dpy, egs);
            X11.XDestroyWindow(dpy, win);
        } X11.XUnlockDisplay(dpy);
    },

    create_surface = (window: *Window) {
        x11_check_usage(null, window);

        dgl := *window.base.display.base.gl;
        wgl := *window.base.gl;

        wgl.type = .EGL;
        wgl.egl.native = xx window.x11.handle;
        wgl.egl.surface = EGL.CreateWindowSurface(dgl.egl.dpy, dgl.egl.cnf, wgl.egl.native, null);

        EGL.MakeCurrent(dgl.egl.dpy, wgl.egl.surface, wgl.egl.surface, dgl.egl.ctx);
        ok := EGL.SwapInterval(dgl.egl.dpy, 0);
        log("EGL.SwapInterval(%, 0): %", cast(*void) dgl.egl.dpy, ok);
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

XCB_GLX_Ops :: GL_Ops.{
    create_context = (display: *Display, major_version := 0, minor_version := 0, compatibility := false, debug := false) {
        xcb_check_usage(display);

        if gl_initialized(display) return;
        GL.wsi_load(*GLX);

        gl := *display.base.gl;
        gl.type = .GLX;
        gl.ops = XCB_GLX_Ops;
        gl.ops.get_proc_address = GLX.GetProcAddress;

        dpy := display.xcb.xlib_dpy;
        assert(dpy != null);

        gl.glx.ctx, gl.glx.cnf = GLX.create_context(
            *GLX,
            dpy, X11.DefaultScreen(dpy),
            xx major_version, xx minor_version,
            compatibility, debug);
        win := create_dummy_window_xcb(*display.xcb);
        glx_win := GLX.CreateWindow(dpy, gl.glx.cnf, win, null);
        GLX.MakeContextCurrent(dpy, glx_win, glx_win, gl.glx.ctx);
        GL.gl_load(*GL.gl_procs, GLX.GetProcAddress);
        GLX.MakeContextCurrent(dpy, 0, 0, null);
        GLX.DestroyWindow(dpy, glx_win);
        xcb.destroy_window(display.xcb.handle, win);
    },

    create_surface = (window: *Window) {
        xcb_check_usage(null, window);

        dpy     := window.xcb.display.xlib_dpy;
        glx_cnf := window.base.display.base.gl.glx.cnf;
        glx_ctx := window.base.display.base.gl.ctx;

        gl := *window.base.gl;
        gl.type = .GLX;
        gl.glx.win = GLX.CreateWindow(dpy, glx_cnf, window.xcb.handle, null);

        if GLX.SwapIntervalEXT {
            GLX.MakeCurrent(dpy, gl.glx.win, glx_ctx);
            GLX.SwapIntervalEXT(dpy, gl.glx.win, 0);
        }
    },

    make_current = (window: *Window) {
        xcb_check_usage(null, window);

        dpy     := window.xcb.display.xlib_dpy;
        glx_win := window.base.gl.glx.win;
        glx_ctx := window.xcb.display.base.gl.glx.ctx;
        GLX.MakeCurrent(dpy, glx_win, glx_ctx);
    },

    swap_buffers = (window: *Window) {
        xcb_check_usage(null, window);

        dpy     := window.xcb.display.xlib_dpy;
        glx_win := window.base.gl.glx.win;
        GLX.SwapBuffers(dpy, glx_win);
    }
};

XCB_EGL_Ops :: GL_Ops.{
    create_context = (display: *Display, major_version := 0, minor_version := 0, compatibility := false, debug := false) {
        xcb_check_usage(display);

        if gl_initialized(display) return;
        GL.wsi_load(*EGL);

        gl := *display.base.gl;
        gl.type = .EGL;
        if display.base.init_flags & .XCB_Pure {
            log("EGL: initializing from xcb connection");
            attrs := s32.[EGL.PLATFORM_XCB_SCREEN_EXT, 0, EGL.NONE];
            gl.egl.dpy, gl.egl.ctx, gl.egl.cnf = EGL.create_context(
                *EGL,
                display.xcb.handle, EGL.PLATFORM_XCB_EXT, attrs.data,
                major_version, minor_version,
                compatibility, debug);
        } else {
            log("EGL: initializing from Xlib display");
            assert(display.xcb.xlib_dpy != null);
            gl.egl.dpy, gl.egl.ctx, gl.egl.cnf = EGL.create_context(
                *EGL,
                display.xcb.xlib_dpy, 0, null,
                major_version, minor_version,
                compatibility, debug);
        }
        gl.ops = XCB_EGL_Ops;
        gl.ops.get_proc_address = EGL.GetProcAddress;

        win := create_dummy_window_xcb(*display.xcb);
        egs := EGL.CreateWindowSurface(gl.egl.dpy, gl.egl.cnf, xx win, null);
        EGL.MakeCurrent(gl.egl.dpy, egs, egs, gl.egl.ctx);
        GL.gl_load(*GL.gl_procs, EGL.GetProcAddress);
        EGL.MakeCurrent(gl.egl.dpy, EGL.NO_SURFACE, EGL.NO_SURFACE, EGL.NO_CONTEXT);
        EGL.DestroySurface(gl.egl.dpy, egs);
        xcb.destroy_window(display.xcb.handle, win);
    },

    create_surface = (window: *Window) {
        xcb_check_usage(null, window);

        dgl := *window.base.display.base.gl;
        wgl := *window.base.gl;

        wgl.type = .EGL;
        wgl.egl.native = xx window.xcb.handle;
        wgl.egl.surface = EGL.CreateWindowSurface(dgl.egl.dpy, dgl.egl.cnf, wgl.egl.native, null);
        assert(wgl.egl.surface != null);

        EGL.MakeCurrent(dgl.egl.dpy, wgl.egl.surface, wgl.egl.surface, dgl.egl.ctx);
        ok := EGL.SwapInterval(dgl.egl.dpy, 0);
        log("EGL.SwapInterval(%, 0): %", cast(*void) dgl.egl.dpy, ok);
    },

    make_current = (window: *Window) {
        xcb_check_usage(null, window);

        wgl := *window.base.gl.egl;
        dgl := *window.base.display.base.gl.egl;
        EGL.MakeCurrent(dgl.dpy, wgl.surface, wgl.surface, dgl.ctx);
    },

    swap_buffers = (window: *Window) {
        xcb_check_usage(null, window);

        wgl := *window.base.gl.egl;
        dgl := *window.base.display.base.gl.egl;
        EGL.SwapBuffers(dgl.dpy, wgl.surface);
    }
};

Wayland_EGL_Ops :: GL_Ops.{
    create_context = (display: *Display, major_version := 0, minor_version := 0, compatibility := false, debug := false) {
        wl_check_usage(display);

        if gl_initialized(display) return;
        GL.wsi_load(*EGL);

        bd: *Base_Display = display;
        wld := *display.wld;
        gl := *bd.gl;

        gl.type = .EGL;
        gl.egl.dpy, gl.egl.ctx, gl.egl.cnf = EGL.create_context(
            *EGL,
            display.wld.handle, 0, null,
            major_version, minor_version,
            compatibility, debug);
        gl.ops = Wayland_EGL_Ops;
        gl.ops.get_proc_address = EGL.GetProcAddress;

        wls := wl_compositor.create_surface(wld.compositor);
        wln := wl_egl_window_create(wls, 1, 1);
        egs := EGL.CreateWindowSurface(gl.egl.dpy, gl.egl.cnf, wln, null);
        EGL.MakeCurrent(gl.egl.dpy, egs, egs, gl.egl.ctx);
        GL.gl_load(*GL.gl_procs, EGL.GetProcAddress);
        EGL.MakeCurrent(gl.egl.dpy, EGL.NO_SURFACE, EGL.NO_SURFACE, EGL.NO_CONTEXT);
        EGL.DestroySurface(gl.egl.dpy, egs);
        wl_egl_window_destroy(wln);
        wl_surface.destroy(wls);
    },

    create_surface = (window: *Window) {
        wl_check_usage(null, window);

        ww  := *window.wld;
        wgl := *window.base.gl;
        dgl := *window.base.display.base.gl;

        wgl.type = .EGL;
        wgl.egl.native = wl_egl_window_create(ww.handle, ww.buffer_width, ww.buffer_height);
        wgl.egl.surface = EGL.CreateWindowSurface(dgl.egl.dpy, dgl.egl.cnf, wgl.egl.native, null);
        EGL.MakeCurrent(dgl.egl.dpy, wgl.egl.surface, wgl.egl.surface, dgl.egl.ctx);
        wl_window_resize_viewport(ww);
        wl_surface.damage(ww.handle, 0, 0, ww.window_width, ww.window_height);
        wl_surface.commit(ww.handle);

        ok := EGL.SwapInterval(dgl.egl.dpy, 0);
        log("EGL.SwapInterval(%, 0): %", cast(*void) dgl.egl.dpy, ok);
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

create_dummy_x11_window :: (x11_display: *X11_Display) -> X11.Window {
    swa: X11.XSetWindowAttributes;
    swa.colormap = x11_display.color_map;
    root := X11.DefaultRootWindow(x11_display.handle);
    win := X11.XCreateWindow(x11_display.handle, root,
        0, 0, 16, 16,
        0,
        x11_display.visual_info.depth,
        X11.InputOutput, x11_display.visual_info.visual,
        cast(u64) (X11.CWColormap | X11.CWEventMask),
        *swa);
    return win;
}

create_dummy_window_xcb :: (xd: *XCB_Display) -> u32 {
    wid := xcb.generate_id(xd.handle);
    xcb.create_window(
        c=xd.handle,
        depth=XCB_COPY_FROM_PARENT,
        wid=wid,
        parent=xd.screen.root,
        x=0, y=0, width=100, height=100, border_width=1,
        _class=.XCB_WINDOW_CLASS_INPUT_OUTPUT,
        visual=xd.screen.root_visual,
        value_mask=.XCB_CW_BACK_PIXEL | .XCB_CW_EVENT_MASK,
        value_list=u32.[xd.screen.white_pixel, xx (xcb_event_mask_t.EXPOSURE | xcb_event_mask_t.STRUCTURE_NOTIFY)].data,
    );
    xcb.flush(xd.handle);
    return wid;
}
