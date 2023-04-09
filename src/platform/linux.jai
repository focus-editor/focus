platform_setup :: () {
    
}

platform_get_biggest_monitor_pos :: () -> s32, s32 {
    unimplemented();
}

platform_maximize_window :: (window: Window_Type) {
    
}

platform_enable_drag_and_drop :: (window: Window_Type) {
    typelist := string.["url/url", "text/uri-list", "text/plain", "application/octet-stream"];  // @Incomplete: test this on Linux
    X11.enable_drag_and_drop(window, typelist);
}

platform_get_dpi_scale :: (window: Window_Type) -> float {
    unimplemented();
}

platform_set_window_title :: (title: string) {
    d := X11.x_global_display;
    win_name := temp_c_string(title);
    X11.XStoreName(d, window, win_name);
}

platform_wait_message :: inline () {
    unimplemented();
}

platform_enumerate_logical_drives :: () -> [] string {
    unimplemented();
}

#scope_file

Monitor :: struct {
    left   : int;
    top    : int;
    right  : int;
    bottom : int;
};

monitors : [..] Monitor;

X11 :: #import "X11";