windows_setup :: () {
    #assert OS == .WINDOWS "Currently only supporting Windows";

    if !SetProcessDPIAware()                                  then panic("Can't set process to be DPI aware");
    if timeBeginPeriod(1) != TIMERR_NOERROR                   then log_error("Couldn't set minimum timer resolution");
    if !EnumDisplayMonitors(null, null, monitor_enum_proc, 0) then panic("Couldn't enumerate monitors");
}

windows_get_biggest_monitor_pos :: () -> s32, s32 {
    assert(monitors.count > 0, "Unexpectedly no monitors found. This is a bug.");
    biggest := monitors[0];
    max_area := 0;
    for monitors {
        width := it.right - it.left;
        height := it.bottom - it.top;
        area := width * height;
        if max_area < area then biggest = it;
    }
    return cast(s32) biggest.left, cast(s32) biggest.top;
}

windows_maximize_window :: (window: Window_Type) {
    ShowWindow(window, SW_MAXIMIZE);
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

#import "Windows";
