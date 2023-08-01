X11Display :: struct {
    handle: *Display;
    file_descriptor: s32;

    glx_ctx: GLXContext;
    glx_cnf: GLXFBConfig;

    im: XIM;

    fixed_scaling: bool;
    dpi_override: s32;
}

X11Window :: struct {
    // we would really like this to be LDWindow but we get a circular dependency if we declare it like that
    wrapper: *void;

    handle: Window;
    display: *X11Display;

    ic: XIC;

    glx_win: GLXWindow;
}

x_cursors: Table(string, Cursor);
preloaded_x_cursors :: string.[
    "default", "pointer", "not-allowed", "col-resize", "row-resize",
    "all-scroll", "nw-resize", "se-resize", "text",
];

x11_init_display :: (display: LDDisplay) -> bool {
    current_locale := setlocale(LC_ALL, null);
    current_xmods  := XSetLocaleModifiers(null);

    old_locale: string;
    if current_locale old_locale = copy_string(to_string(current_locale));

    old_xmods: string;
    if current_xmods old_xmods = copy_string(to_string(current_xmods));

    defer {
        if current_locale {
            setlocale(LC_ALL, old_locale.data);
            free(old_locale);
        }
        if current_xmods {
            XSetLocaleModifiers(old_xmods.data);
            free(old_xmods);
        }
    }

    setlocale(LC_ALL, "");

    init_global_display();

    XSetLocaleModifiers("");
    im := XOpenIM(x_global_display, null, null, null);
    if !im {
        XSetLocaleModifiers("@im=none");
        im = XOpenIM(x_global_display, null, null, null);
    }

    if !xcursor_initialized {
        lib := dlopen("libXcursor.so.1", RTLD_NOW);
        if lib != null {
            XcursorLibraryLoadCursor = xx dlsym(lib, "XcursorLibraryLoadCursor");
            xcursor_initialized = (XcursorLibraryLoadCursor != null);
            if xcursor_initialized {
                init(*x_cursors);
                for preloaded_x_cursors {
                    table_add(*x_cursors, it, XcursorLibraryLoadCursor(x_global_display, it.data));
                }
            }
        }
    }

    file_descriptor := XConnectionNumber(x_global_display);

    set(display, X11Display.{
        handle = x_global_display,
        im = im,
        file_descriptor = file_descriptor,
    });
    return ifx x_global_display then true else false;
}

#scope_file
x_net_wm_state_maximized_vert: Atom;
x_net_wm_state_maximized_horz: Atom;

#scope_export

x11_maximize_window :: (x11_win: *X11Window) {
    win := x11_win.handle;
    display := x11_win.display.handle;

    if !x_net_wm_state_maximized_horz {
        x_net_wm_state_maximized_horz = XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_HORZ", True);
    }
    if !x_net_wm_state_maximized_vert {
        x_net_wm_state_maximized_vert = XInternAtom(display, "_NET_WM_STATE_MAXIMIZED_VERT", True);
    }

    if !x_global_net_wm_state || !x_net_wm_state_maximized_horz || !x_net_wm_state_maximized_vert return;

    xev: XEvent;
    xev.type = ClientMessage;
    xev.xclient.window = win;
    xev.xclient.message_type = x_global_net_wm_state;
    xev.xclient.format = 32;
    xev.xclient.data.l[0] = _NET_WM_STATE_ADD;
    xev.xclient.data.l[1] = cast(s64) x_net_wm_state_maximized_horz;

    XSendEvent(display, DefaultRootWindow(display), False,
        SubstructureRedirectMask | SubstructureNotifyMask, *xev);

    xev.xclient.data.l[1] = cast(s64) x_net_wm_state_maximized_vert;

    XSendEvent(display, DefaultRootWindow(display), False,
        SubstructureRedirectMask | SubstructureNotifyMask, *xev);

    XSync(display, False);
}

x11_toggle_fullscreen :: (x11_win: *X11Window, desire_fullscreen: bool, saved: *Saved_Window_Info) ->
    success: bool, width: s32, height: s32
{
    win := x11_win.handle;
    display := x11_win.display.handle;

    if desire_fullscreen {
        if x_global_net_wm_state && x_global_net_wm_state_fullscreen {
            xev: XEvent;
            xev.type = ClientMessage;
            xev.xclient.window = win;
            xev.xclient.message_type = x_global_net_wm_state;
            xev.xclient.format = 32;
            xev.xclient.data.l[0] = _NET_WM_STATE_ADD;
            xev.xclient.data.l[1] = cast(s64) x_global_net_wm_state_fullscreen;

            XSendEvent(display, DefaultRootWindow(display), False,
                SubstructureRedirectMask | SubstructureNotifyMask, *xev);
            XSync(display, False);

            width: u32;
            height: u32;

            // for what ever stupid reason, XGetGeometry crashes if you pass null in for any of its return parameters
            root: Window;
            x, y: s32;
            border_width: u32;
            depth_return: u32;
            // this will return the window's current dimensions, but it seems the server will imediately send a
            // ConfigureNotify event with the new size of the fullscreen window
            XGetGeometry(display, win, *root, *x, *y, *width, *height, *border_width, *depth_return);
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
        if x_global_net_wm_state && x_global_net_wm_state_fullscreen {
            xev: XEvent;
            xev.type = ClientMessage;
            xev.xclient.window = win;
            xev.xclient.message_type = x_global_net_wm_state;
            xev.xclient.format = 32;
            xev.xclient.data.l[0] = _NET_WM_STATE_REMOVE;
            xev.xclient.data.l[1] = cast(s64) x_global_net_wm_state_fullscreen;

            XSendEvent(display, DefaultRootWindow(display), False,
                SubstructureRedirectMask | SubstructureNotifyMask, *xev);

            width: u32;
            height: u32;

            // for what ever stupid reason, XGetGeometry crashes if you pass null in for any of its return parameters
            root: Window;
            x, y: s32;
            border_width: u32;
            depth_return: u32;
            XGetGeometry(display, win, *root, *x, *y, *width, *height, *border_width, *depth_return);
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

    XLockDisplay(d);
    root := DefaultRootWindow(d);
    parent := ifx x11_parent then x11_parent.handle else root;

    // These attributes must match the attibutes we use to create the GL context. :GlContextAttributes
    //        -rluba, 2021-11-30
    attr := s32.[
        GLX_RGBA,
        GLX_DEPTH_SIZE, 24,
        GLX_DOUBLEBUFFER,
        GLX_RED_SIZE, 8,
        GLX_GREEN_SIZE, 8,
        GLX_BLUE_SIZE, 8,
        GLX_STENCIL_SIZE, 8,
        None
    ];
    vi := glXChooseVisual(d, 0, attr.data);
    cmap := XCreateColormap(d, parent, vi.visual, AllocNone);

    background_color: XColor;
    background_color.flags |= DoRed | DoGreen | DoBlue;
    background_color.red     = to_u16(background_color_rgb[0]);
    background_color.green   = to_u16(background_color_rgb[1]);
    background_color.blue    = to_u16(background_color_rgb[2]);
    XAllocColor(d, cmap, *background_color);

    swa: XSetWindowAttributes;
    swa.colormap = cmap;
    swa.event_mask =
        ExposureMask |
        KeyPressMask |
        KeyReleaseMask |
        ButtonPressMask |
        ButtonReleaseMask |
        StructureNotifyMask |
        FocusChangeMask |
        EnterWindowMask |
        LeaveWindowMask |
        PointerMotionHintMask |
        PointerMotionMask;
    swa.background_pixel = background_color.pixel;
    win := XCreateWindow(d, parent,
        xx window_x, xx window_y, xx width, xx height,
        0,
        vi.depth,
        InputOutput, vi.visual,
        cast(u64) (CWColormap | CWEventMask),
        *swa);

    win_name := temp_c_string(window_name);
    if window_name then XStoreName(d, win, win_name);

    class_hints := XAllocClassHint();
    if class_hints {
        if window_name {
            class_hints.res_name = win_name;
        } else {
            class_hints.res_name = "jai-application";
        }
        class_hints.res_class = temp_c_string(global_app_id);
        XSetClassHint(d, win, class_hints);
    }

    XMapWindow(d, win);

    XSetWMProtocols(d, win, *x_global_wm_delete_window, 1);

    ic := XCreateIC(x11_display.im,
        XNClientWindow, win,
        XNFocusWindow, win,
        XNInputStyle, XIMPreeditNothing | XIMStatusNothing,
        null);

    array_add(*x_global_windows, win);

    XUnlockDisplay(d);
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

    icon_pixmap := XCreatePixmap(dpy, w, width, height, 32);
    gc := XCreateGC(dpy, icon_pixmap, 0, null);
    icon_image := XCreateImage(dpy, XDefaultVisual(dpy, DefaultScreen(dpy)), 32, ZPixmap, 0, data, width, height, 32, 0);
    XPutImage(dpy, icon_pixmap, gc, icon_image, 0, 0, 0, 0, width, height);
    XFreeGC(dpy, gc);
    // XDestroyImage(icon_image);

    hints := XAllocWMHints();
    hints.flags = IconPixmapHint;
    hints.icon_pixmap = icon_pixmap;
    XSetWMHints(dpy, w, hints);
    XFree(hints);
}

x11_set_cursor_from_theme :: (win: *X11Window, name: string) {
    if xcursor_initialized {
        cursor, found := table_find(*x_cursors, name);
        if found {
            XDefineCursor(win.display.handle, win.handle, cursor);
        }
    }
}

x11_has_native_handle :: (win: *X11Window, native_handle: Window) -> bool {
    return win.handle == native_handle;
}

x11_get_dimensions :: (win: *X11Window, right_handed: bool)
    -> (x: s32, y: s32, width: s32, height: s32, success := true)
{
    xwa: XWindowAttributes;
    XGetWindowAttributes(win.display.handle, win.handle, *xwa);

    y := ifx right_handed then xwa.y+xwa.height else xwa.y;
    return xwa.x, y, xwa.width, xwa.height;
}

x11_get_mouse_pointer_position :: (dpy: *X11Display, win: *X11Window, right_handed: bool)
    -> x: int, y: int, success: bool
{
    root_x, root_y: s32;
    win_x, win_y: s32;
    root, child: Window;
    modifier_mask: u32;

    // @TODO XQueryPointer is a round trip to the X server, which means this could be very slow.
    // It may be more desirable to update a global mouse state by capturing mouse events in
    // X11_Input.jai:update_x11_window_events()
    ok := XQueryPointer(dpy.handle, win.handle, *root, *child, *root_x, *root_y, *win_x, *win_y, *modifier_mask);

    if right_handed {
        xwa: XWindowAttributes;
        XGetWindowAttributes(dpy.handle, win.handle, *xwa);
        win_y = xwa.height - win_y;
    }
    return win_x, win_y, ok == True;
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

    hwnd: Window;
    revert: s32;
    XGetInputFocus(dpy.handle, *hwnd, *revert);
    win := get_by_native_handle(xx hwnd);
    if !win || !isa(win, X11Window) return 0, 0, false;

    x, y, success := x11_get_mouse_pointer_position(dpy, isa(win, X11Window), right_handed);
    return x, y, success;
}

x11_enable_dnd :: (win: *X11Window, typelist: []string) {
    enable_drag_and_drop(win.handle, typelist);
}

x11_set_window_title :: (w: *X11Window, title: string) {
    prop := XTextProperty.{
        value = title.data,
        encoding = x_global_xa_utf8,
        format = 8,
        nitems = xx title.count,
    };
    XSetWMName(w.display.handle, w.handle, *prop);
}

x11_get_dpi_scaling_factor :: (w: *X11Window) -> float {
    if w.display.fixed_scaling return cast(float) w.display.dpi_override / 96.0;

    screen := XScreenOfDisplay(w.display.handle, 0);
    sw := XWidthOfScreen(screen);
    swmm := XWidthMMOfScreen(screen);
    return (cast(float) sw / (cast(float) swmm / 25.4)) / 96.0;
}

x11_generate_resize :: (w: *X11Window) {
    xwa: XWindowAttributes;
    XGetWindowAttributes(w.display.handle, w.handle, *xwa);
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
XcursorLibraryLoadCursor : #type (dpy: *Display, name: *u8) -> Cursor #c_call;
