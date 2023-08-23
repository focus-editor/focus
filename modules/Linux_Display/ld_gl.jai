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
            ctx: EGL.EGLContext;
            cnf: EGL.EGLConfig;
            dpy: EGL.EGLDisplay;
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
            surface: EGL.EGLSurface;
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
GL  :: #import "GL";
EGL :: #import "EGL";

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
    },

    get_proc_address = X11.glXGetProcAddress,
};

X11_EGL_Ops :: GL_Ops.{
    create_context = (display: *Display, major_version := 0, minor_version := 0, compatibility := false, debug := false) {
        x11_check_usage(display);

        if gl_initialized(display) return;

        gl := *display.base.gl;
        gl.type = .EGL;
        gl.egl.dpy, gl.egl.ctx, gl.egl.cnf = EGL.egl_create_context(
            display.x11.handle, major_version, minor_version, compatibility, debug);
        gl.ops = X11_EGL_Ops;

        // @TODO - do we need to MakeCurrent something before?
        GL.gl_load(*GL.gl, EGL.eglGetProcAddress);
    },

    create_surface = (window: *Window) {
        x11_check_usage(null, window);

        dgl := *window.base.display.base.gl;
        wgl := *window.base.gl;

        wgl.type = .EGL;
        wgl.egl.native = xx window.x11.handle;
        wgl.egl.surface = EGL.eglCreateWindowSurface(dgl.egl.dpy, dgl.egl.cnf, wgl.egl.native, null);
    },

    make_current = (window: *Window) {
        x11_check_usage(null, window);

        wgl := *window.base.gl.egl;
        dgl := *window.base.display.base.gl.egl;
        X11.XLockDisplay(window.x11.display.handle);
        EGL.eglMakeCurrent(dgl.dpy, wgl.surface, wgl.surface, dgl.ctx);
        X11.XLockDisplay(window.x11.display.handle);
    },

    swap_buffers = (window: *Window) {
        x11_check_usage(null, window);

        wgl := *window.base.gl.egl;
        dgl := *window.base.display.base.gl.egl;
        EGL.eglSwapBuffers(dgl.dpy, wgl.surface);
    },

    get_proc_address = EGL.eglGetProcAddress,
};

Wayland_EGL_Ops :: GL_Ops.{
    create_context = (display: *Display, major_version := 0, minor_version := 0, compatibility := false, debug := false) {
        wl_check_usage(display);

        if gl_initialized(display) return;

        bd: *Base_Display = display;
        wld := *display.wld;
        gl := *bd.gl;

        gl.type = .EGL;
        gl.egl.dpy, gl.egl.ctx, gl.egl.cnf = EGL.egl_create_context(
            display.wld.handle, major_version, minor_version, compatibility, debug);
        gl.ops = Wayland_EGL_Ops;

        wls := wl_compositor.create_surface(wld.compositor);
        wln := wl_egl_window.create(wls, 1, 1);
        egs := EGL.eglCreateWindowSurface(gl.egl.dpy, gl.egl.cnf, wln, null);
        EGL.eglMakeCurrent(gl.egl.dpy, egs, egs, gl.egl.ctx);
        GL.gl_load(*GL.gl, EGL.eglGetProcAddress);
        EGL.eglMakeCurrent(gl.egl.dpy, EGL.EGL_NO_SURFACE, EGL.EGL_NO_SURFACE, EGL.EGL_NO_CONTEXT);
        EGL.eglDestroySurface(gl.egl.dpy, egs);
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
        wgl.egl.surface = EGL.eglCreateWindowSurface(dgl.egl.dpy, dgl.egl.cnf, wgl.egl.native, null);
        EGL.eglMakeCurrent(dgl.egl.dpy, wgl.egl.surface, wgl.egl.surface, dgl.egl.ctx);
        wl_window_resize_viewport(ww);
        wl_surface.damage(ww.handle, 0, 0, ww.window_width, ww.window_height);
        wl_surface.commit(ww.handle);
    },

    make_current = (window: *Window) {
        wl_check_usage(null, window);

        wgl := *window.base.gl.egl;
        dgl := *window.base.display.base.gl.egl;
        EGL.eglMakeCurrent(dgl.dpy, wgl.surface, wgl.surface, dgl.ctx);
    },

    swap_buffers = (window: *Window) {
        wl_check_usage(null, window);

        wgl := *window.base.gl.egl;
        dgl := *window.base.display.base.gl.egl;
        EGL.eglSwapBuffers(dgl.dpy, wgl.surface);
    },

    get_proc_address = EGL.eglGetProcAddress,
};
