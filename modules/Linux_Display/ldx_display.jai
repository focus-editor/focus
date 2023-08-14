X11Display :: struct {
    handle: *X11.Display;
    file_descriptor: s32;

    glx_ctx: X11.GLXContext;
    glx_cnf: X11.GLXFBConfig;

    im: X11.XIM;

    fixed_scaling: bool;
    dpi_override: s32;
}

X11Window :: struct {
    // we would really like this to be LDWindow but we get a circular dependency if we declare it like that
    wrapper: *void;

    handle: X11.Window;
    display: *X11Display;

    ic: X11.XIC;

    glx_win: X11.GLXWindow;
}

x_cursors: Table(string, X11.Cursor);
preloaded_x_cursors :: string.[
    "default", "pointer", "not-allowed", "col-resize", "row-resize",
    "all-scroll", "nw-resize", "se-resize", "text",
];

x11_init_display :: (display: LDDisplay) -> bool {
    old_locale := setlocale(LC_ALL, null);
    old_xmods  := X11.XSetLocaleModifiers(null);

    defer {
        if old_locale {
            setlocale(LC_ALL, old_locale);
        }
        if old_xmods {
            X11.XSetLocaleModifiers(old_xmods);
        }
    }

    // Default locale, which is "C", doesn't support multibyte characters,
    // so we do this to get system locale which is hopefully set up correctly

    // Result of setlocale will either be a correct locale from the environment,
    // or NULL if setlocale fails, or it will be "C" if somebody exported LC_ALL=""
    new_locale := to_string(setlocale(LC_ALL, ""));

    // We need to check whether current locale is supported by X server. It's not
    // guaranteed regardless of whether setlocale call is successful or not.
    // If setting locale didn't work, we try our best to get it from a few well-known
    // environment variables in case one of them is set up correctly. glibc's setlocale
    // tries $LC_ALL first, then a category you specify in the first argument to setlocale,
    // and then $LANG env variable. The issue here is that glibc bails out of this sequence
    // as soon as it sees that something is set, even if it's set incorrectly. So the call to
    // setlocale will fail. That's why we try this process manually.
    // This process vaguely resembles the way musl gets current locale and looks reasonable enough
    if !new_locale || new_locale == "C" || !X11.XSupportsLocale() {

        // getenv can have two "falsy" outcomes - env variable exists but is an empty string
        // and env variable doesn't exist. In first case we get a pointer to an empty string,
        // in the second case we get NULL as a result. Converting to jai string covers both cases
        lc_ctype := trim(to_string(getenv("LC_CTYPE")));
        if !lc_ctype {
            lang := trim(to_string(getenv("LANG")));

            if !lang {
                log_error("LANG environment variable is not found, trying to fall back to C.UTF-8\n");
                new_locale = to_string(setlocale(LC_ALL, "C.UTF-8"));
            } else {
                new_locale = to_string(setlocale(LC_ALL, temp_c_string(lang)));
            }
        } else {
            new_locale = to_string(setlocale(LC_ALL, temp_c_string(lc_ctype)));
        }

        if !new_locale || !X11.XSupportsLocale() {
            error :: #string __error
Couldn't set unicode-capable locale from environment, falling back to default one: %.
This is likely an indicator that your locale is set incorrectly.
Inspect available locales [$ locale -a] and the one you have set up: [$ locale]
            __error
            log_error(error, to_string(old_locale));
            setlocale(LC_ALL, old_locale);
        }

    }
    X11.init_global_display();

    // NOTE: Should we explicitly support XMODIFIERS and XIM_SERVERS such as dbus and fcitx?
    // Try the best we can to get the input method
    X11.XSetLocaleModifiers("");
    im := X11.XOpenIM(X11.x_global_display, null, null, null);
    if !im {
        // local seems like the same thing as none, but more examples use it!
        X11.XSetLocaleModifiers("@im=local");
        im = X11.XOpenIM(X11.x_global_display, null, null, null);
        if !im {
            X11.XSetLocaleModifiers("@im=");
            im = X11.XOpenIM(X11.x_global_display, null, null, null);
            // Nothing more we can do
            if !im {
                log_error("Could not get X11 Input Method");
            }
        }
    }

    if !xcursor_initialized {
        lib := dlopen("libXcursor.so.1", RTLD_NOW);
        if lib != null {
            XcursorLibraryLoadCursor = xx dlsym(lib, "XcursorLibraryLoadCursor");
            xcursor_initialized = (XcursorLibraryLoadCursor != null);
            if xcursor_initialized {
                init(*x_cursors);
                for preloaded_x_cursors {
                    table_add(*x_cursors, it, XcursorLibraryLoadCursor(X11.x_global_display, it.data));
                }
            }
        }
    }

    file_descriptor := X11.XConnectionNumber(X11.x_global_display);

    set(display, X11Display.{
        handle = X11.x_global_display,
        im = im,
        file_descriptor = file_descriptor,
    });
    return ifx X11.x_global_display then true else false;
}

#scope_file
x_net_wm_state_maximized_vert: X11.Atom;
x_net_wm_state_maximized_horz: X11.Atom;

#scope_export

x11_maximize_window :: (x11_win: *X11Window) {
    win := x11_win.handle;
    display := x11_win.display.handle;

    if !x_net_wm_state_maximized_horz {
        x_net_wm_state_maximized_horz = X11.XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_HORZ", X11.True);
    }
    if !x_net_wm_state_maximized_vert {
        x_net_wm_state_maximized_vert = X11.XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_VERT", X11.True);
    }

    if !X11.x_global_net_wm_state || !x_net_wm_state_maximized_horz || !x_net_wm_state_maximized_vert return;

    xev: X11.XEvent;
    xev.type = X11.ClientMessage;
    xev.xclient.window = win;
    xev.xclient.message_type = X11.x_global_net_wm_state;
    xev.xclient.format = 32;
    xev.xclient.data.l[0] = X11._NET_WM_STATE_ADD;
    xev.xclient.data.l[1] = cast(s64) x_net_wm_state_maximized_horz;

    X11.XSendEvent(display, X11.DefaultRootWindow(display), X11.False,
        X11.SubstructureRedirectMask | X11.SubstructureNotifyMask, *xev);

    xev.xclient.data.l[1] = cast(s64) x_net_wm_state_maximized_vert;

    X11.XSendEvent(display, X11.DefaultRootWindow(display), X11.False,
        X11.SubstructureRedirectMask | X11.SubstructureNotifyMask, *xev);

    X11.XSync(display, X11.False);
}

x11_toggle_fullscreen :: (x11_win: *X11Window, desire_fullscreen: bool, saved: *Saved_Window_Info) ->
    success: bool, width: s32, height: s32
{
    win := x11_win.handle;
    display := x11_win.display.handle;

    if desire_fullscreen {
        if X11.x_global_net_wm_state && X11.x_global_net_wm_state_fullscreen {
            xev: X11.XEvent;
            xev.type = X11.ClientMessage;
            xev.xclient.window = win;
            xev.xclient.message_type = X11.x_global_net_wm_state;
            xev.xclient.format = 32;
            xev.xclient.data.l[0] = X11._NET_WM_STATE_ADD;
            xev.xclient.data.l[1] = cast(s64) X11.x_global_net_wm_state_fullscreen;

            X11.XSendEvent(display, X11.DefaultRootWindow(display), X11.False,
                X11.SubstructureRedirectMask | X11.SubstructureNotifyMask, *xev);
            X11.XSync(display, X11.False);

            width: u32;
            height: u32;

            // for what ever stupid reason, XGetGeometry crashes if you pass null in for any of its return parameters
            root: X11.Window;
            x, y: s32;
            border_width: u32;
            depth_return: u32;
            // this will return the window's current dimensions, but it seems the server will imediately send a
            // ConfigureNotify event with the new size of the fullscreen window
            X11.XGetGeometry(display, win, *root, *x, *y, *width, *height, *border_width, *depth_return);
            return true, cast(s32) width, cast(s32) height;
        } else {
            // :NoNET_WM_STATE_FULLSCREEN:
            // @TODO typically the window manager should support NET_WM_STATE and NET_WM_STATE_FULLSCREEN
            // however, in the event that it does not, we're supposed to change the window's attributes
            // to enable override_redirect. However, apparently in doing so, this causes the window manager
            // to ignore the window (the window, in essense, is considered as acting as a temporary window manager
            // accoring to the ICCM) requiring more work on our part. The ICCM strongly discourages doing this,
            // but this is the only other way to take control of the screen AFAICT. -josh
            return false, 0, 0;
        }
    } else {
        if X11.x_global_net_wm_state && X11.x_global_net_wm_state_fullscreen {
            xev: X11.XEvent;
            xev.type = X11.ClientMessage;
            xev.xclient.window = win;
            xev.xclient.message_type = X11.x_global_net_wm_state;
            xev.xclient.format = 32;
            xev.xclient.data.l[0] = X11._NET_WM_STATE_REMOVE;
            xev.xclient.data.l[1] = cast(s64) X11.x_global_net_wm_state_fullscreen;

            X11.XSendEvent(display, X11.DefaultRootWindow(display), X11.False,
                X11.SubstructureRedirectMask | X11.SubstructureNotifyMask, *xev);

            width: u32;
            height: u32;

            // for what ever stupid reason, XGetGeometry crashes if you pass null in for any of its return parameters
            root: X11.Window;
            x, y: s32;
            border_width: u32;
            depth_return: u32;
            X11.XGetGeometry(display, win, *root, *x, *y, *width, *height, *border_width, *depth_return);
            return true, cast(s32) width, cast(s32) height;
        } else {
            // :NoNET_WM_STATE_FULLSCREEN:
            return false, 0, 0;
        }
    }
}

x11_create_window :: (x11_display: *X11Display, ld_win: LDWindow, width: int, height: int, window_name: string,
    window_x: int, window_y: int, x11_parent: *X11Window, background_color_rgb: [3]float) -> bool
{
    to_u16 :: (f: float) -> u16 {
        u := cast(s32)(f * 65535);
        if u < 0      u = 0;
        if u > 65535  u = 65535;

        return cast(u16) u;
    }

    d := x11_display.handle;

    X11.XLockDisplay(d);
    root := X11.DefaultRootWindow(d);
    parent := ifx x11_parent then x11_parent.handle else root;

    // These attributes must match the attibutes we use to create the GL context. :GlContextAttributes
    //        -rluba, 2021-11-30
    attr := s32.[
        X11.GLX_RGBA,
        X11.GLX_DEPTH_SIZE, 24,
        X11.GLX_DOUBLEBUFFER,
        X11.GLX_RED_SIZE, 8,
        X11.GLX_GREEN_SIZE, 8,
        X11.GLX_BLUE_SIZE, 8,
        X11.GLX_STENCIL_SIZE, 8,
        X11.None
    ];
    vi := X11.glXChooseVisual(d, 0, attr.data);
    cmap := X11.XCreateColormap(d, parent, vi.visual, X11.AllocNone);

    background_color: X11.XColor;
    background_color.flags |= X11.DoRed | X11.DoGreen | X11.DoBlue;
    background_color.red     = to_u16(background_color_rgb[0]);
    background_color.green   = to_u16(background_color_rgb[1]);
    background_color.blue    = to_u16(background_color_rgb[2]);
    X11.XAllocColor(d, cmap, *background_color);

    swa: X11.XSetWindowAttributes;
    swa.colormap = cmap;
    swa.event_mask =
        X11.ExposureMask |
        X11.KeyPressMask |
        X11.KeyReleaseMask |
        X11.ButtonPressMask |
        X11.ButtonReleaseMask |
        X11.StructureNotifyMask |
        X11.FocusChangeMask |
        X11.EnterWindowMask |
        X11.LeaveWindowMask |
        X11.PointerMotionHintMask |
        X11.PointerMotionMask;
    swa.background_pixel = background_color.pixel;
    win := X11.XCreateWindow(d, parent,
        xx window_x, xx window_y, xx width, xx height,
        0,
        vi.depth,
        X11.InputOutput, vi.visual,
        cast(u64) (X11.CWColormap | X11.CWEventMask),
        *swa);

    win_name := temp_c_string(window_name);
    if window_name then X11.XStoreName(d, win, win_name);

    class_hints := X11.XAllocClassHint();
    if class_hints {
        if window_name {
            class_hints.res_name = win_name;
        } else {
            class_hints.res_name = "jai-application";
        }
        class_hints.res_class = temp_c_string(global_app_id);
        X11.XSetClassHint(d, win, class_hints);
    }

    X11.XMapWindow(d, win);

    X11.XSetWMProtocols(d, win, *X11.x_global_wm_delete_window, 1);

    ic := X11.XCreateIC(x11_display.im,
        XNClientWindow, win,
        XNFocusWindow, win,
        XNInputStyle, XIMPreeditNothing | XIMStatusNothing,
        null);

    if !ic {
        log_error("Could not create X11 input context\n");
    }

    array_add(*X11.x_global_windows, win);

    X11.XUnlockDisplay(d);
    set(ld_win, X11Window.{
        wrapper = ld_win,
        handle = win,
        display = x11_display,
        ic = ic,
    });
    return true;
}

x11_set_icon_from_raw_data :: (win: X11Window, data: *u8, width: u32, height: u32) {
    dpy := win.display.handle;
    w := win.handle;

    icon_pixmap := X11.XCreatePixmap(dpy, w, width, height, 32);
    gc := X11.XCreateGC(dpy, icon_pixmap, 0, null);
    icon_image := X11.XCreateImage(dpy, X11.XDefaultVisual(dpy, X11.DefaultScreen(dpy)), 32, X11.ZPixmap, 0, data, width, height, 32, 0);
    X11.XPutImage(dpy, icon_pixmap, gc, icon_image, 0, 0, 0, 0, width, height);
    X11.XFreeGC(dpy, gc);
    // XDestroyImage(icon_image);

    hints := X11.XAllocWMHints();
    hints.flags = X11.IconPixmapHint;
    hints.icon_pixmap = icon_pixmap;
    X11.XSetWMHints(dpy, w, hints);
    X11.XFree(hints);
}

x11_set_cursor_from_theme :: (win: *X11Window, name: string) {
    if xcursor_initialized {
        cursor, found := table_find(*x_cursors, name);
        if found {
            X11.XDefineCursor(win.display.handle, win.handle, cursor);
        }
    }
}

x11_has_native_handle :: (win: *X11Window, native_handle: X11.Window) -> bool {
    return win.handle == native_handle;
}

x11_get_dimensions :: (win: *X11Window, right_handed: bool)
    -> (x: s32, y: s32, width: s32, height: s32, success := true)
{
    xwa: X11.XWindowAttributes;
    X11.XGetWindowAttributes(win.display.handle, win.handle, *xwa);

    y := ifx right_handed then xwa.y+xwa.height else xwa.y;
    return xwa.x, y, xwa.width, xwa.height;
}

x11_get_mouse_pointer_position :: (dpy: *X11Display, win: *X11Window, right_handed: bool)
    -> x: int, y: int, success: bool
{
    root_x, root_y: s32;
    win_x, win_y: s32;
    root, child: X11.Window;
    modifier_mask: u32;

    // @TODO XQueryPointer is a round trip to the X server, which means this could be very slow.
    // It may be more desirable to update a global mouse state by capturing mouse events in
    // X11_Input.jai:update_x11_window_events()
    ok := X11.XQueryPointer(dpy.handle, win.handle, *root, *child, *root_x, *root_y, *win_x, *win_y, *modifier_mask);

    if right_handed {
        xwa: X11.XWindowAttributes;
        X11.XGetWindowAttributes(dpy.handle, win.handle, *xwa);
        win_y = xwa.height - win_y;
    }
    return win_x, win_y, ok == X11.True;
}

x11_get_mouse_pointer_position :: (win: *X11Window, right_handed: bool) -> x: int, y: int, success: bool {
    dpy := isa(global_display, X11Display);
    assert(dpy != null);
    x, y, success := x11_get_mouse_pointer_position(dpy, win, right_handed);
    return x, y, success;
}

x11_get_mouse_pointer_position :: (right_handed := false) -> x: int, y: int, success: bool {
    dpy := isa(global_display, X11Display);
    assert(dpy != null);

    hwnd: X11.Window;
    revert: s32;
    X11.XGetInputFocus(dpy.handle, *hwnd, *revert);
    win := get_by_native_handle(xx hwnd);
    if !win || !isa(win, X11Window) return 0, 0, false;

    x, y, success := x11_get_mouse_pointer_position(dpy, isa(win, X11Window), right_handed);
    return x, y, success;
}

x11_enable_dnd :: (win: *X11Window, typelist: []string) {
    X11.enable_drag_and_drop(win.handle, typelist);
}

x11_set_window_title :: (w: *X11Window, title: string) {
    prop := X11.XTextProperty.{
        value = title.data,
        encoding = X11.x_global_xa_utf8,
        format = 8,
        nitems = xx title.count,
    };
    X11.XSetWMName(w.display.handle, w.handle, *prop);
}

x11_get_dpi_scaling_factor :: (w: *X11Window) -> float {
    if w.display.fixed_scaling return cast(float) w.display.dpi_override / 96.0;

    screen := X11.XScreenOfDisplay(w.display.handle, 0);
    sw := X11.XWidthOfScreen(screen);
    swmm := X11.XWidthMMOfScreen(screen);
    return (cast(float) sw / (cast(float) swmm / 25.4)) / 96.0;
}

x11_generate_resize :: (w: *X11Window) {
    xwa: X11.XWindowAttributes;
    X11.XGetWindowAttributes(w.display.handle, w.handle, *xwa);
    Input.add_resize_record(w.wrapper, xwa.width, xwa.height);
}

x11_set_fixed_scaling :: (d: *X11Display, factor: float) {
    fixed_scaling := (factor != 0.0);
    new_dpi: s32 = xx (factor * 96.0);
    if ((fixed_scaling != d.fixed_scaling) || (fixed_scaling && (new_dpi != d.dpi_override))) && (factor >= 0.0) {
        d.fixed_scaling = fixed_scaling;
        if fixed_scaling d.dpi_override = new_dpi;
        for global_windows {
            x11_generate_resize(isa(it, X11Window));
        }
    }
}

#scope_file

xcursor_initialized := false;
XcursorLibraryLoadCursor : #type (dpy: *X11.Display, name: *u8) -> X11.Cursor #c_call;
