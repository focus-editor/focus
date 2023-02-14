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

platform_set_window_title :: (title: string) {
    SetWindowTextW(window, utf8_to_wide(title));
}

platform_wait_message :: inline () {
    WaitMessage();
}

platform_enumerate_logical_drives :: () -> [] string {
    drives: [..] string;
    
    drives_buf: [500] u16;
    GetLogicalDriveStringsW(500, drives_buf.data);
    
    drive_wstr := drives_buf.data;
    for drives_buf {
        if it == 0 {
            drive, success := wide_to_utf8(drive_wstr);
            if !drive || !success break;
            drive.count -= 1;  // cut off separator
            array_add(*drives, drive);
            drive_wstr = *drives_buf[it_index + 1];
        }
    }
    
    return drives;
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

user32   :: #system_library "user32";
kernel32 :: #system_library "kernel32";

WaitMessage :: () -> s32 #foreign user32;
GetDpiForWindow :: (hWnd: HWND) -> u32 #foreign user32;
GetLogicalDriveStringsW :: (nBufferLength: DWORD, lpBuffer: *u16) -> DWORD #foreign kernel32;

#import "Windows";
