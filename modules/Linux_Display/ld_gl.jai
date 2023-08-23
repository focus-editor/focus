GL_Backend_Type :: enum {
    Uninitialized;
    GLX;
    EGL;
}

GL_Display :: struct {
    type : GL_Backend_Type = .Uninitialized;
    union {
        glx: struct {
            ctx: X11.GLXContext;
            cnf: X11.GLXFBConfig;
        }
        egl: struct {
            dpy: EGLDisplay;
            ctx: EGLContext;
            cnf: EGLConfig;
        }
    }
}

GL_Window :: struct {
    type : GL_Backend_Type = .Uninitialized;
    union {
        glx: struct {
            win: X11.GLXWindow;
        }
        egl: struct {
            native: *wl_egl_window;
            surface: EGLSurface;
        }
    }
}

get_gl_context :: (display: *Display) -> *void {
    bd: *Base_Display = display;
    if bd.type == {
        case X11_Display; {
            if bd.gl.type == {
                case .GLX; return bd.gl.glx.ctx;
                case .EGL; return bd.gl.egl.ctx;
                case; return null;
            }
        }
        case Wayland_Display; {
            assert(bd.gl.type == .Uninitialized || bd.gl.type == .EGL);
            if bd.gl.type == .Uninitialized assert(!bd.gl.egl.ctx);
            return bd.gl.egl.ctx;
        }
        case; return null;
    }
}

get_gl_proc_address_function :: (display: *Display) -> GL.GetProcAddressFunction {
    bd: *Base_Display = display;
    if bd.gl.type == {
        case .GLX; return X11.glXGetProcAddress;
        case .EGL; return eglGetProcAddress;
        case; return null;
    }
}

get_gl_proc_address_function :: (window: *Window) -> GL.GetProcAddressFunction {
    bw: *Base_Window = window;
    if bw.gl.type == {
        case .GLX; return X11.glXGetProcAddress;
        case .EGL; return eglGetProcAddress;
        case; return null;
    }
}

create_gl_context :: (display: *Display, major_version := 0, minor_version := 0, compatibility := false, debug := false) {
    if gl_initialized(display) {
        log_error("WARNING: OpenGL has already been initialized for display %!\n", display);
        return;
    }

    bd: *Base_Display = display;
    gl := *bd.gl;

    if display.base.type == {
        case X11_Display; {
            gl.glx.ctx, gl.glx.cnf = GL.glx_create_context(xx major_version, xx minor_version, compatibility, debug);
            gl.type = .GLX;
        }
        case Wayland_Display; {
            wld := *display.wld;
            gl.egl.dpy, gl.egl.ctx, gl.egl.cnf = egl_create_context(
                wld.handle, major_version, minor_version, compatibility, debug);
            gl.type = .EGL;

            wls := wl_compositor.create_surface(wld.compositor);
            wln := wl_egl_window.create(wls, 1, 1);
            egs := eglCreateWindowSurface(gl.egl.dpy, gl.egl.cnf, wln, null);
            eglMakeCurrent(gl.egl.dpy, egs, egs, gl.egl.ctx);
            gl_load(*GL.gl, eglGetProcAddress);
            eglMakeCurrent(gl.egl.dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
            eglDestroySurface(gl.egl.dpy, egs);
            wl_egl_window.destroy(wln);
            wl_surface.destroy(wls);
        }
    }
}

create_gl_surface :: (window: *Window) {
    if gl_initialized(window) {
        log_error("WARNING: window % already has an associated EGL surface!\n", window);
        return;
    }

    bw: *Base_Window = window;
    gl := *bw.gl;

    if window.base.type == {
        case X11_Window; {
            w := *window.x11;
            gl.glx.win = X11.glXCreateWindow(w.display.handle, w.display.base.gl.glx.cnf, w.handle, null);
            gl.type = .GLX;
        }
        case Wayland_Window; {
            w := *window.wld;
            gl.egl.native = wl_egl_window.create(w.handle, w.buffer_width, w.buffer_height);
            gl.egl.surface = eglCreateWindowSurface(
                w.display.base.gl.egl.dpy,
                w.display.base.gl.egl.cnf,
                gl.egl.native, null);
            gl.type = .EGL;
            eglMakeCurrent(
                w.display.base.gl.egl.dpy,
                gl.egl.surface, gl.egl.surface,
                w.display.base.gl.egl.ctx);
            wl_window_resize_viewport(w);
            wl_surface.damage(w.handle, 0, 0, w.window_width, w.window_height);
            wl_surface.commit(w.handle);
        }
    }
}

make_current :: (win: *Window) {
    if win.base.type == {
        case X11_Window; {
            w := *win.x11;
            X11.XLockDisplay(w.display.handle);
            X11.glXMakeCurrent(
                w.display.handle,
                w.base.gl.glx.win,
                w.display.base.gl.glx.ctx);
            X11.XUnlockDisplay(w.display.handle);
        }
        case Wayland_Window; {
            w := *win.wld;
            eglMakeCurrent(
                w.display.base.gl.egl.dpy,
                w.base.gl.egl.surface,
                w.base.gl.egl.surface,
                w.display.base.gl.egl.ctx);
        }
    }
}

swap_buffers :: (win: *Window) {
    if win.base.type == {
        case X11_Window; {
            w := *win.x11;
            X11.glXSwapBuffers(w.display.handle, w.base.gl.glx.win);
        }
        case Wayland_Window; {
            w := *win.wld;
            eglSwapBuffers(w.display.base.gl.egl.dpy, w.base.gl.egl.surface);
        }
    }
}

gl_initialized :: (display: *Display) -> bool {
    return display.base.gl.type != .Uninitialized;
}

gl_initialized :: (window: *Window) -> bool {
    return window.base.gl.type != .Uninitialized;
}

#scope_file
GL :: #import "GL";

egl_create_context :: (native_display: EGLNativeDisplayType, major_version := 0, minor_version := 0,
    compatibility := false, debug := false) -> EGLDisplay, EGLContext, EGLConfig
{
    n: s32;
    major: s32;
    minor: s32;

    egl_dpy := eglGetDisplay(native_display);
    eglInitialize(egl_dpy, *major, *minor);
    eglBindAPI(EGL_OPENGL_API);

    config_attribs : []s32 = .[
        EGL_SURFACE_TYPE, EGL_WINDOW_BIT,
        EGL_RED_SIZE, 8,
        EGL_GREEN_SIZE, 8,
        EGL_BLUE_SIZE, 8,
        // EGL_ALPHA_SIZE, 8,                   // this makes the entire window translucent
        EGL_RENDERABLE_TYPE, EGL_OPENGL_BIT,
        EGL_NONE
    ];
    egl_cnf: EGLConfig;
    eglChooseConfig(egl_dpy, config_attribs.data, *egl_cnf, 1, *n);

    context_attribs: [9]s32;
    attr_count := 0;

    if major_version > 0 {
        context_attribs[attr_count + 0] = EGL_CONTEXT_MAJOR_VERSION;
        context_attribs[attr_count + 1] = xx major_version;
        context_attribs[attr_count + 2] = EGL_CONTEXT_MINOR_VERSION;
        context_attribs[attr_count + 3] = xx minor_version;
        attr_count += 4;
    }

    context_attribs[attr_count + 0] = EGL_CONTEXT_OPENGL_PROFILE_MASK;
    if compatibility  context_attribs[attr_count + 1] = EGL_CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT;
    else              context_attribs[attr_count + 1] = EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT;
    attr_count += 2;

    if debug {
        context_attribs[attr_count + 0] = EGL_CONTEXT_OPENGL_DEBUG;
        context_attribs[attr_count + 1] = EGL_TRUE;
        attr_count += 2;
    }

    context_attribs[attr_count] = EGL_NONE;

    egl_ctx := eglCreateContext(egl_dpy, egl_cnf, EGL_NO_CONTEXT, context_attribs.data);

    return egl_dpy, egl_ctx, egl_cnf;
}
