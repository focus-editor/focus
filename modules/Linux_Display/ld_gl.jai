get_gl_context :: (display: LDDisplay) -> *void {
    if display.tag == {
        case X11Display; return isa(display, X11Display).glx_ctx;
        case WLDisplay; return isa(display, WLDisplay).egl_ctx;
        case; return null;
    }
}

get_gl_context :: inline () -> *void {
    return get_gl_context(global_display);
}

get_gl_proc_address_function :: (display: LDDisplay) -> GL.GetProcAddressFunction {
    if display.tag == {
        case X11Display; return X11.glXGetProcAddress;
        case WLDisplay; return eglGetProcAddress;
        case; return null;
    }
}

get_gl_proc_address_function :: inline () -> GL.GetProcAddressFunction {
    return get_gl_proc_address_function(global_display);
}

get_gl_proc_address_function :: (win: LDWindow) -> GL.GetProcAddressFunction {
    if win.tag == {
        case X11Window; return X11.glXGetProcAddress;
        case WLWindow; return eglGetProcAddress;
        case; return null;
    }
}

create_gl_context :: (display: LDDisplay, major_version := 0, minor_version := 0, compatibility := false, debug := false) {
    if gl_initialized(display) {
        log_error("WARNING: OpenGL has already been initialized for display %!\n", display);
        return;
    }

    if display.tag == {
        case X11Display; {
            xd := isa(display, X11Display);
            xd.glx_ctx, xd.glx_cnf = GL.glx_create_context(xx major_version, xx minor_version, compatibility, debug);
        }
        case WLDisplay; {
            wld := isa(display, WLDisplay);
            wld.egl_dpy, wld.egl_ctx, wld.egl_cnf = egl_create_context(
                wld.handle, major_version, minor_version, compatibility, debug);

            wls := wl_compositor.create_surface(wld.compositor);
            wln := wl_egl_window.create(wls, 1, 1);
            egs := eglCreateWindowSurface(wld.egl_dpy, wld.egl_cnf, wln, null);
            eglMakeCurrent(wld.egl_dpy, egs, egs, wld.egl_ctx);
            gl_load(*gl, eglGetProcAddress);
            eglMakeCurrent(wld.egl_dpy, EGL_NO_SURFACE, EGL_NO_SURFACE, EGL_NO_CONTEXT);
            eglDestroySurface(wld.egl_dpy, egs);
            wl_egl_window.destroy(wln);
            wl_surface.destroy(wls);
        }
    }
}

create_gl_context :: inline (major_version := 0, minor_version := 0, compatibility := false, debug := false) {
    create_gl_context(global_display, major_version, minor_version, compatibility, debug);
}

create_gl_surface :: (win: LDWindow) {
    if gl_initialized(win) {
        log_error("WARNING: window % already has an associated EGL surface!\n", win);
        return;
    }

    if win.tag == {
        case X11Window; {
            w := isa(win, X11Window);
            w.glx_win = X11.glXCreateWindow(w.display.handle, w.display.glx_cnf, w.handle, null);
        }
        case WLWindow; {
            w := isa(win, WLWindow);
            w.egl_native = wl_egl_window.create(w.handle, w.buffer_width, w.buffer_height);
            w.egl_surface = eglCreateWindowSurface(w.display.egl_dpy, w.display.egl_cnf, w.egl_native, null);
            eglMakeCurrent(w.display.egl_dpy, w.egl_surface, w.egl_surface, w.display.egl_ctx);
            wl_window_resize_viewport(w);
            wl_surface.damage(w.handle, 0, 0, w.window_width, w.window_height);
            wl_surface.commit(w.handle);
        }
    }
}

make_current :: (win: LDWindow) {
    if win.tag == {
        case X11Window; {
            w := isa(win, X11Window);
            X11.XLockDisplay(w.display.handle);
            if !X11.glXMakeCurrent(w.display.handle, w.glx_win, w.display.glx_ctx)
                log_error("glxMakeCurrent failed! (glx_window %, context %)\n", w.glx_win, w.display.glx_ctx);
            X11.XUnlockDisplay(w.display.handle);
        }
        case WLWindow; {
            w := isa(win, WLWindow);
            eglMakeCurrent(w.display.egl_dpy, w.egl_surface, w.egl_surface, w.display.egl_ctx);
        }
    }
}

swap_buffers :: (win: LDWindow) {
    if win.tag == {
        case X11Window; {
            w := isa(win, X11Window);
            X11.glXSwapBuffers(w.display.handle, w.glx_win);
        }
        case WLWindow; {
            w := isa(win, WLWindow);
            eglSwapBuffers(w.display.egl_dpy, w.egl_surface);
        }
    }
}

gl_initialized :: (display: LDDisplay) -> bool {
    if display.tag == {
        case X11Display; return isa(display, X11Display).glx_ctx != null;
        case WLDisplay; return isa(display, WLDisplay).egl_ctx != null;
        case; return false;
    }
}

gl_initialized :: (win: LDWindow) -> bool {
    if win.tag == {
        case X11Window; return isa(win, X11Window).glx_win != X11.None;
        case WLWindow; return isa(win, WLWindow).egl_surface != null;
        case; return false;
    }
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
