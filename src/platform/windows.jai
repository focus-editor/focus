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
        if max_area < area {
            biggest = it;
            max_area = area;
        }
    }
    return cast(s32) biggest.left, cast(s32) biggest.top;
}

platform_create_window :: () {
    window = create_window(window_width, window_height, window_generic_title, window_x, window_y, background_color_rgb = as_3_floats(Colors.BACKGROUND));
}

platform_maximize_window :: (window: Window_Type) {
    ShowWindow(window, SW_MAXIMIZE);
}

platform_enable_drag_and_drop :: (window: Window_Type) {
    Windows.DragAcceptFiles(window, cast(Windows.BOOL) true);
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

platform_set_refresh_timer :: (window: Window_Type) {
    SetTimer(window, REFRESH_TIMER_ID, 50, cast(*void) 0);  // refresh every 50ms
}

platform_kill_refresh_timer :: (window: Window_Type) {
    KillTimer(window, REFRESH_TIMER_ID);
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

platform_get_save_file_name :: (name := "") -> string /* temp */, success: bool {
    buffer: [512] u16;

    ofn: OPENFILENAMEW;
    ofn.lStructSize = size_of(OPENFILENAMEW);
    ofn.lpstrFile   = buffer.data;
    ofn.nMaxFile    = buffer.count;
    ofn.lpstrTitle  = utf8_to_wide(tprint("Choose where to save '%'", name));
    ofn.Flags       = OFN_NOCHANGEDIR;

    for dir : project_dirs {
        if dir.path {
            ofn.lpstrInitialDir = utf8_to_wide(dir.path);
            break;
        }
    }

    open_success := GetOpenFileNameW(*ofn);

    if open_success {
        file_path, success := wide_to_utf8(buffer.data);
        path_overwrite_separators(file_path, #char "/");

        if success {
            return file_path, success;
        }
    }
    return "", false;
}

platform_get_fonts_dir :: () -> string {
    return "C:/Windows/Fonts";
}

platform_open_in_explorer :: (dir: string) {
    ShellExecuteW(window, utf8_to_wide("explore"), utf8_to_wide(dir), xx 0, xx 0, SW_NORMAL);
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

REFRESH_TIMER_ID :: 0;

user32   :: #system_library "user32";
kernel32 :: #system_library "kernel32";
shell32  :: #system_library "shell32";

WaitMessage :: () -> s32 #foreign user32;
SetTimer  :: (hWnd: HWND, nIDEvent: u64, uElapse: u32, lpTimerFunc: *void) -> s32 #foreign user32;
KillTimer :: (hWnd: HWND, nIDEvent: u64) -> bool #foreign user32;
GetDpiForWindow :: (hWnd: HWND) -> u32 #foreign user32;
GetLogicalDriveStringsW :: (nBufferLength: DWORD, lpBuffer: *u16) -> DWORD #foreign kernel32;
ShellExecuteW :: (hwnd: HWND, lpOperation: *u16, lpFile: *u16, lpParameters: *u16, lpDirectory: *u16, nShowCmd: int) -> s32 #foreign shell32;

#import "Windows";
