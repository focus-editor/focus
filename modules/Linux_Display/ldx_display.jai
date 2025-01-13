#scope_module

X11_Display :: struct {
    #as base: Base_Display;

    handle: *X11.Display;
    file_descriptor: s32;

    im: X11.XIM;

    fixed_scaling: bool;
    dpi_override: float;

    global_atoms: X11.Global_Atoms;

    clipboard_text: string;
    drop_info: X11.Drop_Info;
    xdnd_context: X11.Xdnd_Context;

    color_depth :: 24;
    glx_visual_attrs :: s32.[
        GLX.RGBA,
        GLX.DEPTH_SIZE, 24,
        GLX.DOUBLEBUFFER, //, 1 ???
        GLX.RED_SIZE, 8,
        GLX.GREEN_SIZE, 8,
        GLX.BLUE_SIZE, 8,
        GLX.STENCIL_SIZE, 8,
        X11.None
    ];
    visual_info: *X11.XVisualInfo;
    color_map: X11.Colormap;

    x_cursors: Table(string, X11.Cursor);
}

X11_Window :: struct {
    #as base: Base_Window;

    handle: X11.Window;
    display: *X11_Display;

    ic: X11.XIC;
}

preloaded_x_cursors :: string.[
    "default", "pointer", "not-allowed", "col-resize", "row-resize",
    "all-scroll", "nw-resize", "se-resize", "text",
];

x11_init_display :: (display: *Display) -> bool {
    if !xlib_load(*X11) return false;
    if #complete display.base.desired_gl_backend == {
        case .AUTOSELECT; #through;
        case .GLX; if !GL.wsi_load(*GLX) return false;
        case .EGL; if !GL.wsi_load(*EGL) return false;
    }

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

    x11_display := X11_Display.{ base = display.base };
    x11_display.base.type                       = X11_Display;
    x11_display.base.create_window              = x11_create_window;
    x11_display.base.set_fixed_scaling          = x11_set_fixed_scaling;
    x11_display.base.translate_key_code         = x11_translate_key_code;
    x11_display.base.wait_for_events            = x11_wait_for_events;
    x11_display.base.update_window_events       = x11_update_window_events;
    x11_display.base.clipboard_set_text         = x11_clipboard_set_text;
    x11_display.base.clipboard_get_text         = x11_clipboard_get_text;
    x11_display.base.get_mouse_pointer_position = x11_get_mouse_pointer_position;

    x11_display.handle = X11.XOpenDisplay(null);
    X11.init_global_atoms(*X11, x11_display.handle, *x11_display.global_atoms);

    // NOTE: Should we explicitly support XMODIFIERS and XIM_SERVERS such as dbus and fcitx?
    // Try the best we can to get the input method
    X11.XSetLocaleModifiers("");
    x11_display.im = X11.XOpenIM(x11_display.handle, null, null, null);
    if !x11_display.im {
        // local seems like the same thing as none, but more examples use it!
        X11.XSetLocaleModifiers("@im=local");
        x11_display.im = X11.XOpenIM(x11_display.handle, null, null, null);
        if !x11_display.im {
            X11.XSetLocaleModifiers("@im=");
            x11_display.im = X11.XOpenIM(x11_display.handle, null, null, null);
            // Nothing more we can do
            if !x11_display.im {
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
                init(*x11_display.x_cursors);
                for preloaded_x_cursors {
                    table_add(*x11_display.x_cursors, it, XcursorLibraryLoadCursor(x11_display.handle, it.data));
                }
            }
        }
    }

    x11_display.file_descriptor = X11.XConnectionNumber(x11_display.handle);

    screen := X11.DefaultScreen(x11_display.handle);
    root   := X11.DefaultRootWindow(x11_display.handle);
    if #complete display.base.desired_gl_backend == {
        case .AUTOSELECT; #through;
        case .GLX; x11_display.visual_info = GLX.ChooseVisual(x11_display.handle, 0, x11_display.glx_visual_attrs.data);
        case .EGL; {
            vi: X11.XVisualInfo;
            X11.XMatchVisualInfo(x11_display.handle, screen, x11_display.color_depth, X11.TrueColor, *vi);
            x11_display.visual_info = New(X11.XVisualInfo);
            x11_display.visual_info.* = vi;
        }
    }
    x11_display.color_map = X11.XCreateColormap(x11_display.handle, root, x11_display.visual_info.visual, X11.AllocNone);

    display.x11 = x11_display;
    return true;
}

#scope_export

x11_maximize_window :: (window: *Window) {
    x11_check_usage(null, window);

    x11_win: *X11_Window = window;
    win := x11_win.handle;
    display := x11_win.display.handle;

    wm_state := x11_win.display.global_atoms._NET_WM_STATE;
    wm_max_horz := x11_win.display.global_atoms._NET_WM_STATE_MAXIMIZED_HORZ;
    wm_max_vert := x11_win.display.global_atoms._NET_WM_STATE_MAXIMIZED_VERT;
    if !wm_state || !wm_max_horz || !wm_max_vert return;

    xev: X11.XEvent;
    xev.type = X11.ClientMessage;
    xev.xclient.window = win;
    xev.xclient.message_type = wm_state;
    xev.xclient.format = 32;
    xev.xclient.data.l[0] = X11._NET_WM_STATE_ADD;
    xev.xclient.data.l[1] = cast(s64) wm_max_horz;

    X11.XSendEvent(display, X11.DefaultRootWindow(display), X11.False,
        X11.SubstructureRedirectMask | X11.SubstructureNotifyMask, *xev);

    xev.xclient.data.l[1] = cast(s64) wm_max_vert;

    X11.XSendEvent(display, X11.DefaultRootWindow(display), X11.False,
        X11.SubstructureRedirectMask | X11.SubstructureNotifyMask, *xev);

    X11.XSync(display, X11.False);
}

x11_toggle_fullscreen :: (window: *Window, desire_fullscreen: bool, saved: *Saved_Window_Info) -> success: bool, width: s32, height: s32 {
    x11_check_usage(null, window);

    x11_win: *X11_Window = window;
    win := x11_win.handle;
    display := x11_win.display.handle;

    wm_state := x11_win.display.global_atoms._NET_WM_STATE;
    wm_fullscreen := x11_win.display.global_atoms._NET_WM_STATE_FULLSCREEN;
    if !wm_state || !wm_fullscreen  return false, 0, 0;

    if desire_fullscreen {
        xev: X11.XEvent;
        xev.type = X11.ClientMessage;
        xev.xclient.window = win;
        xev.xclient.message_type = wm_state;
        xev.xclient.format = 32;
        xev.xclient.data.l[0] = X11._NET_WM_STATE_ADD;
        xev.xclient.data.l[1] = cast(s64) wm_fullscreen;

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
        xev: X11.XEvent;
        xev.type = X11.ClientMessage;
        xev.xclient.window = win;
        xev.xclient.message_type = wm_state;
        xev.xclient.format = 32;
        xev.xclient.data.l[0] = X11._NET_WM_STATE_REMOVE;
        xev.xclient.data.l[1] = cast(s64) wm_fullscreen;

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
    }
}

x11_create_window :: (display: *Display, window: *Window, width: int, height: int, window_name: string,
    window_x: int, window_y: int, parent: *Window, background_color_rgb: [3]float) -> bool
{
    to_u16 :: (f: float) -> u16 {
        u := cast(s32)(f * 65535);
        if u < 0      u = 0;
        if u > 65535  u = 65535;

        return cast(u16) u;
    }

    x11_check_usage(display, parent);

    x11_display: *X11_Display = display;
    x11_parent: *X11_Window = parent;

    x11_win := X11_Window.{
        base = .{
            type = X11_Window,
            display = display,

            set_icon_from_raw_data     = x11_set_icon_from_raw_data,
            toggle_fullscreen          = x11_toggle_fullscreen,
            has_native_handle          = x11_has_native_handle,
            get_dimensions             = x11_get_dimensions,
            get_render_dimensions      = x11_get_render_dimensions,
            get_mouse_pointer_position = x11_get_mouse_pointer_position,
            enable_dnd                 = x11_enable_dnd,
            set_window_title           = x11_set_window_title,
            maximize_window            = x11_maximize_window,
            set_cursor_from_theme      = x11_set_cursor_from_theme,
            get_dpi_scaling_factor     = x11_get_dpi_scaling_factor,
        },

        display = display,
    };

    d := x11_display.handle;

    X11.XLockDisplay(d);
    defer X11.XUnlockDisplay(d);

    root_handle := X11.DefaultRootWindow(d);
    parent_handle := ifx x11_parent then x11_parent.handle else root_handle;

    background_color: X11.XColor;
    background_color.flags |= X11.DoRed | X11.DoGreen | X11.DoBlue;
    background_color.red     = to_u16(background_color_rgb[0]);
    background_color.green   = to_u16(background_color_rgb[1]);
    background_color.blue    = to_u16(background_color_rgb[2]);
    X11.XAllocColor(d, x11_display.color_map, *background_color);

    swa: X11.XSetWindowAttributes;
    swa.colormap = x11_display.color_map;
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
        X11.PointerMotionMask;
    swa.background_pixel = background_color.pixel;
    x11_win.handle = X11.XCreateWindow(d, parent_handle,
        xx window_x, xx window_y, xx width, xx height,
        0,
        x11_display.visual_info.depth,
        X11.InputOutput, x11_display.visual_info.visual,
        cast(u64) (X11.CWColormap | X11.CWEventMask),
        *swa);

    win_name := temp_c_string(window_name);
    if window_name then x11_set_window_title(xx *x11_win, window_name);

    class_hints := X11.XAllocClassHint();
    if class_hints {
        if window_name {
            class_hints.res_name = win_name;
        } else {
            class_hints.res_name = "jai-application";
        }
        class_hints.res_class = temp_c_string(display.base.app_id);
        X11.XSetClassHint(d, x11_win.handle, class_hints);
    }

    X11.XMapWindow(d, x11_win.handle);

    X11.XSetWMProtocols(d, x11_win.handle, *x11_display.global_atoms.WM_DELETE_WINDOW, 1);

    hints: X11.XSizeHints = .{
        flags = X11.PMinSize,
        min_width = 100,
        min_height = 100,
    };
    X11.XSetWMNormalHints(d, x11_win.handle, *hints);

    x11_win.ic = X11.XCreateIC(x11_display.im,
        X11.XNClientWindow, x11_win.handle,
        X11.XNFocusWindow, x11_win.handle,
        X11.XNInputStyle, X11.XIMPreeditNothing | X11.XIMStatusNothing,
        null);

    if !x11_win.ic {
        log_error("Could not create X11 input context\n");
    }

    window.x11 = x11_win;
    return true;
}

x11_set_icon_from_raw_data :: (window: *Window, data: *u8, width: u32, height: u32) {
    x11_check_usage(null, window);

    win: *X11_Window = window;
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

    {
        /*
         * Some components of certain desktop environments (such as the task manager widgets in
         * XFCE panels) do not work with the icon set via `WM_HINTS`, they require `_NET_WM_ICON`
         * to be set to display the correct icon.
         */
        push_allocator(temp);
        cardinal_data : [..]u64;  // CARDINAL is defined as `long` even though it works with 32bit values...
        array_resize(*cardinal_data, 2 + width * height, initialize=false);
        cardinal_data[0] = width;
        cardinal_data[1] = height;
        pixels := cast(*u32)data;
        for 0..width * height - 1 {
            cardinal_data[2 + it] = pixels[it];
        }

        X11.XChangeProperty(
            dpy, w,
            win.display.global_atoms._NET_WM_ICON,
            X11.XA_CARDINAL, 32,
            X11.PropModeReplace,
            xx cardinal_data.data, xx cardinal_data.count);
    }
}

x11_set_cursor_from_theme :: (window: *Window, name: string) {
    win: *X11_Window = window;
    if xcursor_initialized {
        cursor, found := table_find(*win.display.x_cursors, name);
        if found {
            X11.XDefineCursor(win.display.handle, win.handle, cursor);
        }
    }
}

x11_has_native_handle :: (window: *Window, native_handle: *void) -> bool {
    x11_check_usage(null, window);

    win: *X11_Window = window;
    return win.handle == xx native_handle;
}

x11_get_dimensions :: (window: *Window, right_handed: bool) -> (x: s32, y: s32, width: s32, height: s32, success := true) {
    x11_check_usage(null, window);

    win: *X11_Window = window;
    xwa: X11.XWindowAttributes;
    X11.XGetWindowAttributes(win.display.handle, win.handle, *xwa);

    y := ifx right_handed then xwa.y+xwa.height else xwa.y;
    return xwa.x, y, xwa.width, xwa.height;
}

x11_get_render_dimensions :: (window: *Window) -> s32, s32 {
    x11_check_usage(null, window);

    _, _, w, h, ok := x11_get_dimensions(window, false);
    if ok return w, h;
    return 1, 1;
}

x11_get_mouse_pointer_position :: (display: *Display, window: *Window, right_handed: bool) -> x: int, y: int, success: bool {
    x11_check_usage(display, window);

    dpy: *X11_Display = display;
    win: *X11_Window = window;
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

x11_get_mouse_pointer_position :: (window: *Window, right_handed: bool) -> x: int, y: int, success: bool {
    x11_check_usage(null, window);

    win: *X11_Window = window;
    x, y, success := x11_get_mouse_pointer_position(win.base.display, window, right_handed);
    return x, y, success;
}

x11_get_mouse_pointer_position :: (display: *Display, right_handed := false) -> x: int, y: int, success: bool {
    x11_check_usage(display);

    hwnd: X11.Window;
    revert: s32;
    X11.XGetInputFocus(display.x11.handle, *hwnd, *revert);
    window := get_by_native_handle(display, xx hwnd);
    if !window return 0, 0, false;
    x, y, success := x11_get_mouse_pointer_position(display, window, right_handed);
    return x, y, success;
}

x11_enable_dnd :: (window: *Window, typelist: []string) {
    x11_check_usage(null, window);

    enable_dnd :: (x11_display: *X11_Display, win: X11.Window, typelist: []string) {
        version : s32 = X11.XDND_VERSION;

        dpy := x11_display.handle;
        drop_info := *x11_display.drop_info;

        X11.XChangeProperty(
            dpy, win,
            x11_display.global_atoms.XdndAware,
            X11.XA_ATOM, 32, X11.PropModeReplace,
            cast(*u8) *version, 1);

        root_return: X11.Window;
        parent: X11.Window;
        child_return: *X11.Window;
        child_return_count: u32;
        X11.XQueryTree(dpy, win, *root_return, *parent, *child_return, *child_return_count);

        if child_return  X11.XFree(child_return);

        if parent != root_return  enable_dnd(x11_display, parent, typelist);

        typelist_atoms: [..] X11.Atom;
        array_reset(*drop_info.user_typelist);

        for typelist {
            atom := X11.XInternAtom(dpy, it.data, X11.False);
            array_add(*typelist_atoms, atom);
            array_add(*drop_info.user_typelist, atom);
        }

        X11.XChangeProperty(
            dpy, win,
            x11_display.global_atoms.XdndTypeList,
            X11.XA_ATOM, 32, X11.PropModeReplace,
            cast(*u8) typelist_atoms.data, cast(s32) typelist_atoms.count);
    }

    x11_window : *X11_Window = window;
    enable_dnd(x11_window.display, x11_window.handle, typelist);
}

x11_set_window_title :: (window: *Window, title: string) {
    x11_check_usage(null, window);

    w: *X11_Window = window;
    prop := X11.XTextProperty.{
        value = title.data,
        encoding = w.display.global_atoms.UTF8_STRING,
        format = 8,
        nitems = xx title.count,
    };
    X11.XSetTextProperty(w.display.handle, w.handle, *prop, w.display.global_atoms.WM_NAME);
    X11.XSetTextProperty(w.display.handle, w.handle, *prop, w.display.global_atoms.WM_ICON_NAME);
    X11.XSetTextProperty(w.display.handle, w.handle, *prop, w.display.global_atoms._NET_WM_NAME);
    X11.XSetTextProperty(w.display.handle, w.handle, *prop, w.display.global_atoms._NET_WM_ICON_NAME);
}

x11_get_dpi_scaling_factor :: (window: *Window) -> float {
    x11_check_usage(null, window);

    w: *X11_Window = window;
    if w.display.fixed_scaling return w.display.dpi_override / 96.0;

    screen := X11.XScreenOfDisplay(w.display.handle, 0);
    sw := X11.XWidthOfScreen(screen);
    swmm := X11.XWidthMMOfScreen(screen);
    return (cast(float) sw / (cast(float) swmm / 25.4)) / 96.0;
}

x11_set_fixed_scaling :: (display: *Display, factor: float) {
    x11_check_usage(display);

    d: *X11_Display = display;
    d.fixed_scaling = (factor >= 0.1);
    d.dpi_override = factor * 96.0;
    for * d.base.windows {
        x11_generate_resize(it);
    }
}

#scope_file

x11_generate_resize :: (w: *X11_Window) {
    xwa: X11.XWindowAttributes;
    X11.XGetWindowAttributes(w.display.handle, w.handle, *xwa);
    Input.add_resize_record(xx w, xwa.width, xwa.height);
}

xcursor_initialized := false;
XcursorLibraryLoadCursor : #type (dpy: *X11.Display, name: *u8) -> X11.Cursor #c_call;
