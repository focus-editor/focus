platform_apply_config :: inline () {
}

platform_setup :: () {
    if timeBeginPeriod(1) != TIMERR_NOERROR then log_error("Couldn't set minimum timer resolution");
}

platform_data_dir :: () -> string {
    dir := trim_right(path_strip_filename(get_path_of_running_executable()), "/");
    return copy_string(dir);
}

platform_config_dir :: inline () -> string {
    return platform_data_dir();
}

platform_get_centered_window_dimensions :: (open_on_biggest: bool) -> s32, s32, s32, s32 {
    if !EnumDisplayMonitors(null, null, monitor_enum_proc, 0) then panic("Couldn't enumerate monitors");
    assert(monitors.count > 0, "Unexpectedly no monitors found. This is a bug.");

    monitor := monitors[0];

    if open_on_biggest {
        max_area := 0;
        for monitors {
            width  := it.right  - it.left;
            height := it.bottom - it.top;
            area   := width * height;
            if max_area < area {
                monitor  = it;
                max_area = area;
            } else if max_area == area && it.primary {
                monitor = it;  // prefer primary if there's no biggest monitor
            }
        }
    } else {
        for monitors {
            if it.primary {
                monitor = it;
            }
        }
    }

    monitor_width  := monitor.right  - monitor.left;
    monitor_height := monitor.bottom - monitor.top;

    w := cast(s32) (monitor_width  / 1.5);
    h := cast(s32) (monitor_height / 1.5);
    x := cast(s32) (monitor.left + monitor_width  / 2 - w / 2);
    y := cast(s32) (monitor.top  + monitor_height / 2 - h / 2);

    return x, y, w, h;
}

platform_create_window :: () {
    window = create_window(window_width, window_height, window_generic_title, window_x, window_y, background_color_rgb = color_as_3_floats(Color.BACKGROUND_0));
    platform_set_border_color();
}

platform_maximize_window :: (window: Window_Type) {
    ShowWindow(window, SW_MAXIMIZE);
}

platform_enable_drag_and_drop :: (window: Window_Type) {
    Windows.DragAcceptFiles(window, cast(Windows.BOOL) true);
}

platform_get_dpi_scale :: (window: Window_Type) -> float {
    #if WINDOWS7 {
        return 1.0;  // poor Windows 7 users
    } else {
        dpi := cast(float) GetDpiForWindow(window);
        return dpi / 96.0;
    }
}

platform_set_window_title :: (title: string) {
    SetWindowTextW(window, utf8_to_wide(title,, allocator = temp));
}

platform_wait_message :: inline () {
    WaitMessage();
}

platform_wake_up_main_thread :: () {
    PostMessageW(window, WM_USER, 0, 0);
}

platform_set_refresh_timer :: (window: Window_Type) {
    SetTimer(window, REFRESH_TIMER_ID, 1000, cast(*void) 0);  // refresh every second
}

platform_set_cursor_timer :: (window: Window_Type) {
    SetTimer(window, CURSOR_TIMER_ID, 50, cast(*void) 0);  // refresh every 50ms
}

platform_kill_cursor_timer :: (window: Window_Type) {
    KillTimer(window, CURSOR_TIMER_ID);
}

platform_enumerate_logical_drives :: () -> [] string {
    drives: [..] string;

    drives_buf: [500] u16;
    GetLogicalDriveStringsW(500, drives_buf.data);

    drive_wstr := drives_buf.data;
    for drives_buf {
        if it == 0 {
            drive, success := wide_to_utf8(drive_wstr,, allocator = temp);
            if !drive || !success break;
            drive.count -= 1;  // cut off separator
            array_add(*drives, drive);
            drive_wstr = *drives_buf[it_index + 1];
        }
    }

    return drives;
}

platform_get_save_file_name :: (file_name := "") -> string /* temp */, success: bool {
    buffer: [512] u16;

    // Clean the name from chars that Windows won't accept
    name := copy_temporary_string(file_name);
    replace_chars(name, "@$%&\\/:*?\"'<>|~`#^+={}[];!", cast(u8) #char "_");

    // Get the name to populate it in the filename box (convenient if we're resaving a deleted file)
    if name && name != "<new file>" {
        wide_name, success, length := utf8_to_wide(name,, allocator = temp);
        if success focus_memcpy(buffer.data, wide_name, min(buffer.count, length));
    }

    ofn: OPENFILENAMEW;
    ofn.lStructSize = size_of(OPENFILENAMEW);
    ofn.hwndOwner   = window;
    ofn.lpstrFile   = buffer.data;
    ofn.nMaxFile    = buffer.count;
    ofn.lpstrTitle  = utf8_to_wide(tprint("Choose where to save '%'", name),, allocator = temp);
    ofn.Flags       = OFN_NOCHANGEDIR;

    for dir : project_dirs {
        if dir.path {
            ofn.lpstrInitialDir = utf8_to_wide(dir.path,, allocator = temp);
            break;
        }
    }

    // Since the filename box is blocking, the cursor will not update its visibility whilst it is open. Ensure it is visible first.
    platform_show_cursor(true);
    open_success := GetSaveFileNameW(*ofn);

    if open_success {
        file_path, success := wide_to_utf8(buffer.data,, allocator = temp);
        path_overwrite_separators(file_path, #char "/");

        if success {
            return file_path, success;
        }
    }
    return "", false;
}

platform_find_font_by_name :: (name: string, allocator := temp) -> bool, string {
    // We would like to use `EnumFontFamiliesExA()` so we can filter out fonts that are
    // not monospace. However it only enumerates fonts that have been loaded in GDI via
    // `AddFontResourceEx()` which doesn't include fonts installed in the user specific
    // location (`%LocalAppData%\Microsoft\Windows\Fonts`) by default.
    //
    // Instead of spamming `AddFontResourceEx()` calls we just take file names straight
    // from he registry.

    hkeys  : []HKEY   = .[HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE];
    styles : []string = .[" Regular", ""];
    types  : []string = .[" (TrueType)", ""];
    key    : string   = "Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts\0";  // Needs '\0' at the end so we can pass it to RegGetValueA()
    for hkey : hkeys {
        for style : styles {
            for type : types {
                buff: [1024]u8;
                size: DWORD = buff.count - 1;

                value := sprint("%1%2%3\0", name, style, type);  // Needs '\0' at the end so we can pass it to RegGetValueA()
                defer free(value);

                ret := RegGetValueA(hkey, key.data, value.data, RRF_RT_REG_SZ, null, buff.data, *size);
                if ret != 0 continue;

                path := to_string(buff.data, size);
                if !is_absolute_path(path) {
                    full_path := tprint("%/%", platform_get_fonts_dir(), path);
                    return true, copy_string(full_path,, allocator = allocator);
                }
                return true, copy_string(path,, allocator = allocator);
            }
        }
    }

    return false, "";
}

platform_get_fonts_dir :: () -> string {
    if !fonts_dir {
        path_utf16: *u16;
        ret := SHGetKnownFolderPath(*FOLDERID_Fonts, KF_FLAG_CREATE, null, *path_utf16);
        defer CoTaskMemFree(path_utf16);
        if SUCCEEDED(ret) {
            fonts_dir = wide_to_utf8(path_utf16);
            path_overwrite_separators(fonts_dir, #char "/");
        } else {
            fonts_dir = "C:/Windows/Fonts";
        }
    }
    return fonts_dir;
}

platform_open_in_explorer :: (path: string, reveal := false) {
    path_backslashes := copy_string(path,, allocator = temp);
    path_overwrite_separators(path_backslashes, #char "\\");

    if reveal run_command("explorer", "/select,", path_backslashes);
    else      run_command("explorer", path_backslashes);
}

platform_path_equals :: inline (path_a: string, path_b: string) -> bool {
    return equal_nocase(path_a, path_b);
}

platform_path_begins_with :: inline (path: string, subpath: string) -> bool {
    return begins_with_nocase(path, subpath);
}

platform_path_contains :: inline (path: string, subpath: string) -> bool {
    return contains_nocase(path, subpath);
}

platform_set_border_color :: () {
    using DwmAttribute;
    col : u32 = 0xFFFFFFFF;
    if config.settings.colored_titlebar {
        background := map_color_to_vec4(Color.BACKGROUND_0);
        r : u32 = cast(u32)(background.x * 255.0);
        g : u32 = cast(u32)(background.y * 255.0);
        b : u32 = cast(u32)(background.z * 255.0);
        // COLORREF format is 0x00bbggrr
        col = 0x00000000;
        col |= b << 16;
        col |= g << 8;
        col |= r;
    }
    DwmSetWindowAttribute(window, CAPTION_COLOR, *col, size_of(u32));

    darkmode := ifx config.settings.dark_titlebar then 1 else 0;
    DwmSetWindowAttribute(window, USE_IMMERSIVE_DARK_MODE, *darkmode, size_of(type_of(darkmode)));
}

platform_show_cursor :: (show: bool) {
    if show {
        if cursor_shown <= 0
            cursor_shown = ShowCursor(1);
    } else {
        while cursor_shown >= 0 {
            cursor_shown = ShowCursor(0);
        }
    }
}

platform_get_troubleshooting_info :: () -> string {
    return "<not implemented>";
}

#scope_file

cursor_shown : s32 = 1;
fonts_dir: string;

monitor_enum_proc :: (hMonitor: HMONITOR, hdc: HDC, rect: *RECT, data: LPARAM) -> BOOL #c_call {
    monitor : Monitor = ---;
    monitor.left   = rect.left;
    monitor.top    = rect.top;
    monitor.right  = rect.right;
    monitor.bottom = rect.bottom;

    monitorInfo: MONITORINFO;
    monitorInfo.cbSize = size_of(MONITORINFO);

    GetMonitorInfoW(hMonitor, *monitorInfo);
    monitor.primary = !!(monitorInfo.dwFlags & 0x1);

    new_context : #Context;
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
    primary: bool;
};

monitors : [..] Monitor;

REFRESH_TIMER_ID :: 0;
CURSOR_TIMER_ID  :: 1;

WM_USER :: 0x0400;

user32   :: #system_library "user32";
kernel32 :: #system_library "kernel32";
shell32  :: #system_library "shell32";
ole32    :: #system_library "ole32";

KF_FLAG_CREATE :: 0x00008000;                                       // https://learn.microsoft.com/en-us/windows/win32/api/shlobj_core/ne-shlobj_core-known_folder_flag
FOLDERID_Fonts :: #run uid("FD228CB7-AE11-4AE3-864C-16F3910AB8FE"); // https://learn.microsoft.com/en-us/windows/win32/shell/knownfolderid

WaitMessage :: () -> s32 #foreign user32;
PostMessageW :: (hWnd: HWND, Msg: u32, wParam: WPARAM, lParam: LPARAM) -> BOOL #foreign user32;
SetTimer  :: (hWnd: HWND, nIDEvent: u64, uElapse: u32, lpTimerFunc: *void) -> s32 #foreign user32;
KillTimer :: (hWnd: HWND, nIDEvent: u64) -> bool #foreign user32;
GetDpiForWindow :: (hWnd: HWND) -> u32 #foreign user32;
GetLogicalDriveStringsW :: (nBufferLength: DWORD, lpBuffer: *u16) -> DWORD #foreign kernel32;
ShellExecuteW :: (hwnd: HWND, lpOperation: *u16, lpFile: *u16, lpParameters: *u16, lpDirectory: *u16, nShowCmd: int) -> s32 #foreign shell32;
SHGetKnownFolderPath :: (nFolder: REFGUID, dwFlags: DWORD, hToken: HANDLE, pszPath: **u16) -> HRESULT #foreign shell32;
CoTaskMemFree :: (pv: *void) #foreign ole32;
SendMessageW :: (hwnd: HWND, Msg: u32, wParam: WPARAM, lParam: LPARAM) -> LRESULT #foreign user32;
RedrawWindow :: (hwnd: HWND, lprcUpdate: *RECT, hrgnUpdate: HANDLE, flags: u32) -> BOOL #foreign user32;

RDW_INVALIDATE :: 0x0001;
RDW_UPDATENOW  :: 0x0100;
RDW_FRAME      :: 0x0400;

#import "Windows";
#import "Windows_Registry";
#import "Process";

Dwmapi :: #system_library "Dwmapi";
DwmSetWindowAttribute :: (handle: HANDLE, dwAttribute: DwmAttribute, pvAttributde :*void, cbAttribute :DWORD) -> HRESULT #foreign Dwmapi;

DwmAttribute :: enum u32 {
    NCRENDERING_ENABLED;
    NCRENDERING_POLICY;
    TRANSITIONS_FORCEDISABLED;
    ALLOW_NCPAINT;
    CAPTION_BUTTON_BOUNDS;
    NONCLIENT_RTL_LAYOUT;
    FORCE_ICONIC_REPRESENTATION;
    FLIP3D_POLICY;
    EXTENDED_FRAME_BOUNDS;
    HAS_ICONIC_BITMAP;
    DISALLOW_PEEK;
    EXCLUDED_FROM_PEEK;
    CLOAK;
    CLOAKED;
    FREEZE_REPRESENTATION;
    PASSIVE_UPDATE_MODE;
    USE_HOSTBACKDROPBRUSH;
    USE_IMMERSIVE_DARK_MODE :: 20;
    WINDOW_CORNER_PREFERENCE :: 33;
    BORDER_COLOR;
    CAPTION_COLOR;
    TEXT_COLOR;
    VISIBLE_FRAME_BORDER_THICKNESS;
    SYSTEMBACKDROP_TYPE;
    LAST;
}
