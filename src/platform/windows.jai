PLATFORM_CONFIG_SECTION :: "[[windows]]";
PLATFORM_SUBSECTION_ENUM :: enum {}
PLATFORM_SUBSECTION_NAMES :: string.[];
Platform_Config :: struct {}

platform_parse_config_line :: (config: *Platform_Config, section: PLATFORM_SUBSECTION_ENUM, line: string) -> success: bool, error_msg: string {
    return true, "";
}

platform_apply_config :: inline (config: *Platform_Config) {
}

platform_copy_config :: (src: *Platform_Config, dst: *Platform_Config) {
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

platform_get_save_file_name :: (file_name := "") -> string /* temp */, success: bool {
    buffer: [512] u16;

    // Clean the name from chars that Windows won't accept
    name := copy_temporary_string(file_name);
    replace_chars(name, "@$%&\\/:*?\"'<>|~`#^+={}[];!", cast(u8) #char "_");

    // Get the name to populate it in the filename box (convenient if we're resaving a deleted file)
    if name && name != "<new file>" {
        wide_name, success, length := utf8_to_wide(name);
        if success memcpy(buffer.data, wide_name, min(buffer.count, length));
    }

    ofn: OPENFILENAMEW;
    ofn.lStructSize = size_of(OPENFILENAMEW);
    ofn.hwndOwner   = window;
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

    open_success := GetSaveFileNameW(*ofn);

    if open_success {
        file_path, success := wide_to_utf8(buffer.data);
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
    // location (`%LocalAppData\Microsoft\Windows\Fonts`) by default.
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
                    return true, copy_string(full_path, allocator);
                }
                return true, copy_string(path, allocator);
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
            fonts_dir = copy_string(wide_to_utf8(path_utf16));
            path_overwrite_separators(fonts_dir, #char "/");
        } else {
            fonts_dir = "C:/Windows/Fonts";
        }
    }
    return fonts_dir;
}

platform_open_in_explorer :: (path: string, reveal := false) {
    path_backslashes := copy_string(path, allocator = temp);
    path_overwrite_separators(path_backslashes, #char "\\");

    if reveal run_command("explorer", "/select,", path_backslashes);
    else      run_command("explorer", path_backslashes);
}

platform_path_equals :: (path_a: string, path_b: string) -> bool {
    return equal_nocase(path_a, path_b);
}

#scope_file

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
    primary: bool;
};

monitors : [..] Monitor;

REFRESH_TIMER_ID :: 0;

user32   :: #system_library "user32";
kernel32 :: #system_library "kernel32";
shell32  :: #system_library "shell32";
ole32    :: #system_library "ole32";

KF_FLAG_CREATE :: 0x00008000;                                       // https://learn.microsoft.com/en-us/windows/win32/api/shlobj_core/ne-shlobj_core-known_folder_flag
FOLDERID_Fonts :: #run uid("FD228CB7-AE11-4AE3-864C-16F3910AB8FE"); // https://learn.microsoft.com/en-us/windows/win32/shell/knownfolderid

WaitMessage :: () -> s32 #foreign user32;
SetTimer  :: (hWnd: HWND, nIDEvent: u64, uElapse: u32, lpTimerFunc: *void) -> s32 #foreign user32;
KillTimer :: (hWnd: HWND, nIDEvent: u64) -> bool #foreign user32;
GetDpiForWindow :: (hWnd: HWND) -> u32 #foreign user32;
GetLogicalDriveStringsW :: (nBufferLength: DWORD, lpBuffer: *u16) -> DWORD #foreign kernel32;
ShellExecuteW :: (hwnd: HWND, lpOperation: *u16, lpFile: *u16, lpParameters: *u16, lpDirectory: *u16, nShowCmd: int) -> s32 #foreign shell32;
SHGetKnownFolderPath :: (nFolder: REFGUID, dwFlags: DWORD, hToken: HANDLE, pszPath: **u16) -> HRESULT #foreign shell32;
CoTaskMemFree :: (pv: *void) #foreign ole32;

#import "Windows";
#import "Windows_Registry";
#import "Process";
