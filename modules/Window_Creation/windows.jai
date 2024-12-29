create_window :: (width: int, height: int, window_name: string, window_x := -1, window_y := -1, parent: HWND = null, background_color_rgb := DEFAULT_WINDOW_CREATION_COLOR) -> HWND {
    if !window_class_initted {
        init_window_class(background_color_rgb);
    }

    style := WINDOWED_STYLE;
    if parent != null
        style = SECONDARY_WINDOW_STYLE;

    SPI_GETWORKAREA :: 0x30;
    user32 :: #system_library "user32";
    SystemParametersInfoW :: (uiAction: u32, uiParam: u32, pvParam: *void, fWinIni: u32) -> BOOL #foreign user32;

    if window_x == -1 {
        work_area: RECT;
        work_area_success := SystemParametersInfoW(SPI_GETWORKAREA, 0, *work_area, 0);
        if work_area_success {
            window_x = work_area.left;
            window_y = work_area.top;
        }
    }

    rect : RECT;
    rect.right  = xx width;
    rect.bottom = xx height;

    AdjustWindowRect(*rect, style, .FALSE); // @Robustness: Could this reasonably fail these days?

    client_width  := rect.right-rect.left;
    client_height := rect.bottom-rect.top;

    // CW_USEDEFAULT :: 0x8000_0000;

    hwnd := CreateWindowExW(0,
                            utf8_to_wide(WINDOW_CLASS_NAME,, allocator = temp),
                            utf8_to_wide(window_name,, allocator = temp),
                            style,
                            xx window_x, xx window_y,
                            xx client_width,
                            xx client_height,
                            parent,
                            null,
                            cast (HINSTANCE) 0, // @Robustness: If we want to run on win98 we need the app hinstance here...
                            null);

    if hwnd == null {
        log_error("CreateWindowExW returned 0.\n");
        return null;
    }

    // Display the window
    UpdateWindow(hwnd);
    ShowWindow(hwnd, SW_SHOW);

    return hwnd;
}

// When toggling fullscreen and back, we want to remember
// the size of our old window... so we use Saved_Window_Info.
Saved_Window_Info :: struct {
    rect: RECT;
    style: s32;
    ex_style: s32;
}

toggle_fullscreen :: (hwnd: HWND, desire_fullscreen: bool, saved: *Saved_Window_Info) -> (succcess: bool, width: s32, height: s32) {
    log("desire_fullscreen=%\n", desire_fullscreen);
    assert(saved != null);

    if desire_fullscreen {
        // SetWindowPos(hwnd, HWND_TOP, 0, 0, GetSystemMetrics(SM_CXSCREEN), GetSystemMetrics(SM_CYSCREEN), SWP_FRAMECHANGED);
        old_style    := GetWindowLongW(hwnd, GWL_STYLE);
        old_ex_style := GetWindowLongW(hwnd, GWL_EXSTYLE);

        SetWindowLongW(hwnd, GWL_STYLE, old_style & ~cast(s32)(WS_CAPTION | WS_THICKFRAME));
        SetWindowLongW(hwnd, GWL_EXSTYLE, old_ex_style & ~cast(s32)(WS_EX_DLGMODALFRAME | WS_EX_WINDOWEDGE | WS_EX_CLIENTEDGE | WS_EX_STATICEDGE));

        monitor := MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
        info: MONITORINFO;
        info.cbSize = size_of(type_of(info));
        success := GetMonitorInfoW(monitor, *info);
        if success {
            GetWindowRect(hwnd, *saved.rect);
            saved.style    = old_style;
            saved.ex_style = old_ex_style;

            x := info.rcMonitor.left;
            y := info.rcMonitor.top;
            width  := info.rcMonitor.right  - x;
            height := info.rcMonitor.bottom - y;
            SetWindowPos(hwnd, HWND_TOPMOST, x, y, width, height,
                         SWP_NOZORDER | SWP_NOACTIVATE | SWP_FRAMECHANGED);
            return true, width, height;
        } else {
            return false, 0, 0;
        }
    } else {
        x := saved.rect.left;
        y := saved.rect.top;
        width  := saved.rect.right  - x;
        height := saved.rect.bottom - y;

        SetWindowLongW(hwnd, GWL_STYLE, saved.style);
        SetWindowLongW(hwnd, GWL_EXSTYLE, saved.ex_style);

        SetWindowPos(hwnd, HWND_TOP, x, y, width, height,
                     SWP_FRAMECHANGED);

        return true, width, height;
    }
}

// WINDOWED_STYLE   : s32 : WS_VISIBLE | WS_CAPTION | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_SYSMENU | WS_SIZEBOX;
WINDOWED_STYLE         : u32 : WS_OVERLAPPEDWINDOW;
FULLSCREEN_STYLE       : u32 : WS_VISIBLE | WS_POPUP;
SECONDARY_WINDOW_STYLE : u32 : WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_THICKFRAME;

#scope_file
window_class_initted := false;
WINDOW_CLASS_NAME :: "Default Window Class";

// @@ Move these to Windows.jai?
MAKEINTRESOURCEA :: (i: u32) -> *u8 { return cast(*u8)i; }
MAKEINTRESOURCEW :: (i: u32) -> *u16 { return cast(*u16)i; }

init_window_class :: (background_color_rgb: [3] float) {
    if window_class_initted return;

    hInstance := GetModuleHandleW(null);

    // Load the first icon resource (RESOURCE_ID_FIRST_ICON).
    icon := LoadIconW(hInstance, MAKEINTRESOURCEW(2));
    err := GetLastError();

    // If the icon is null, then use the first one found in the exe.
    if icon == null {
        exe_path : [MAX_PATH]u16;
        GetModuleFileNameW(null, exe_path.data, MAX_PATH);

        icon = ExtractIconW(hInstance, exe_path.data, 0); // 0 means first icon.
    }

    to_u8_inside_u32 :: (f: float) -> u32 {
        u := cast(s16)(f * 255);
        if u < 0    u = 0;
        if u > 255  u = 255;

        return cast(u32) u;
    }

    // CreateSolidBrush takes a BGR color, I guess.
    r := to_u8_inside_u32(background_color_rgb[0]);
    g := to_u8_inside_u32(background_color_rgb[1]);
    b := to_u8_inside_u32(background_color_rgb[2]);

    // @LanguageSemantics: Maybe we want to change the relative precedence of << and | so that this does not happen:
    brush := CreateSolidBrush((b << 16) | (g << 8) | r);

    //
    // windows_windowproc_exists is only called at compile-time.
    // (We could use a compiler feature to mark procedures as being compile-time-only!)
    // It looks through Context for a member called _windows_windowproc. If that member
    // exists, it means some other module provides a WindowProc for us to register
    // in the window class. If not, we put an empty proc there. Why? Well, in Windows
    // you can't just ask for events on a window, they have to dispatch through
    // a WindowProc that is registered at creation time. But we want our input handler
    // to be in a different module, and we want that module and this module to be
    // interchangeable with other things. We didn't want this dumb constraint imposed
    // by Windows to control how our code can be factored. The line must be drawn here!!!!
    //
    // So this was our solution for now. We'll see how this evolves.
    //        -jblow, 14 November 2021.
    //
    #if #run windows_windowproc_exists() {
        WindowProc :: #Context._windows_windowproc;
    } else {
        WindowProc :: DefWindowProcW;
    }

    wc: WNDCLASSEXW;
    wc.cbSize = size_of(WNDCLASSEXW);
    wc.style                = CS_HREDRAW | CS_VREDRAW | CS_OWNDC;
    wc.lpfnWndProc          = xx WindowProc;
    wc.cbClsExtra           = 0;
    wc.cbWndExtra           = 0;
    wc.hInstance            = hInstance;
    wc.hIcon                = icon;
    wc.hCursor              = LoadCursorW(null, IDC_ARROW);
    wc.hbrBackground        = brush;  // cast(HBRUSH) GetStockObject(WHITE_BRUSH);

    wc.lpszMenuName         = null;
    wc.lpszClassName        = utf8_to_wide(WINDOW_CLASS_NAME,, allocator = temp);

    // Register the window class.
    if RegisterClassExW(*wc) == 0 {
        log_error("RegisterClassExW returned 0.\n");
        return;
    }

    window_class_initted = true;
}

windows_windowproc_exists :: () -> bool {
    info := type_info(#Context);
    for info.members {
        if it.name == "_windows_windowproc" {
            return true;
        }
    }

    return false;
}

#scope_export

get_dimensions :: (hwnd: HWND, right_handed: bool) -> (x: s32, y: s32, width: s32, height: s32, success := true) {
    rect: RECT;
    success := GetClientRect(hwnd, *rect);
    if !success  return 0, 0, 0, 0, false;

    y := ifx right_handed then rect.bottom else rect.top;
    return rect.left, y, rect.right - rect.left, rect.bottom - rect.top;
}

// Mouse pointer

get_mouse_pointer_position :: (hwnd: HWND, right_handed: bool) -> (x: int, y: int, success: bool) {
    p: POINT;
    win_success := GetCursorPos(*p);
    if !win_success return 0, 0, false;

    ClientToScreen :: (hwnd: HWND, lpPoint: *POINT) -> s32 #foreign user32;
    ScreenToClient :: (hwnd: HWND, p: *POINT) -> s32 #foreign user32;
    GetClientRect  :: (hwnd: HWND, rect: *RECT) -> s32 #foreign user32;

    win_success = ScreenToClient(hwnd, *p);
    if win_success && right_handed {
        rect: RECT;
        win_success = GetClientRect(hwnd, *rect);
        if !win_success return p.x, p.y, false;
        h := (rect.bottom - rect.top);
        orig := p.y;
        p.y = h - p.y;
    }

    return p.x, p.y, (win_success != 0);
}

get_mouse_pointer_position :: inline (right_handed := false) -> x: int, y: int, success: bool {
    GetActiveWindow  :: () -> HWND #foreign user32;
    hwnd := GetActiveWindow();  // @Robustness: We probably want something better than this.
    x, y, success := get_mouse_pointer_position(hwnd, right_handed);
    return x, y, success;
}


#scope_module

#import "Basic";

#import "Windows";
#import "Windows_Utf8";


#scope_file

user32   :: #system_library "user32";
