platform_setup :: () {
    if timeBeginPeriod(1) != TIMERR_NOERROR then log_error("Couldn't set minimum timer resolution");
}

platform_get_biggest_monitor_pos :: () -> s32, s32 {
    if !EnumDisplayMonitors(null, null, monitor_enum_proc, 0) then panic("Couldn't enumerate monitors");
    assert(monitors.count > 0, "Unexpectedly no monitors found. This is a bug.");

    biggest := monitors[0];
    max_area := 0;
    for monitors {
        width  := it.right  - it.left;
        height := it.bottom - it.top;
        area   := width * height;
        if max_area < area then biggest = it;
    }
    return cast(s32) biggest.left, cast(s32) biggest.top;
}

platform_maximize_window :: (window: Window_Type) {
    ShowWindow(window, SW_MAXIMIZE);
}

platform_get_dpi_scale :: (window: Window_Type) -> float {
    #assert OS == .WINDOWS;
    dpi := cast(float) GetDpiForWindow(window);
    return dpi / 96.0;
}

platform_wait_message :: inline () {
    WaitMessage();
}

#scope_file

monitor_enum_proc :: (hMonitor: HMONITOR, hdc: HDC, rect: *RECT, data: LPARAM) -> BOOL #c_call {
    monitor : Monitor = ---;
    monitor.left   = rect.left;
    monitor.top    = rect.top;
    monitor.right  = rect.right;
    monitor.bottom = rect.bottom;

    new_context : Context;
    push_context new_context {
        array_add(*monitors, monitor);
    }

    return xx true;
}

Monitor :: struct {
    left   : int;
    top    : int;
    right  : int;
    bottom : int;
};

monitors : [..] Monitor;

user32 :: #foreign_system_library "user32";

WaitMessage :: () -> s32 #foreign user32;
GetDpiForWindow :: (hWnd: HWND) -> u32 #foreign user32;

#import "Windows";
