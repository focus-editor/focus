platform_setup :: () {

}

platform_get_biggest_monitor_pos :: () -> s32, s32 {
    return 0, 0;
}

platform_create_window :: () {
    window = create_window(window_width, window_height, window_generic_title, window_x, window_y, background_color_rgb = as_3_floats(Colors.BACKGROUND));
}

platform_maximize_window :: (window: Window_Type) {
    LD.maximize_window(window);
}

platform_enable_drag_and_drop :: (window: Window_Type) {
    typelist := string.["url/url", "text/uri-list", "text/plain", "application/octet-stream"];  // @Incomplete: test this on Linux
    LD.enable_dnd(window, typelist);
}

platform_get_dpi_scale :: (window: Window_Type) -> float {
    return 1.0;
}

platform_set_window_title :: (title: string) {
    LD.set_window_title(window, title);
}

platform_wait_message :: inline () {
}

platform_set_refresh_timer :: (window: Window_Type) {
}

platform_kill_refresh_timer :: (window: Window_Type) {
}

platform_enumerate_logical_drives :: () -> [] string {
    return .[];
}

platform_get_save_file_name :: (name := "") -> string, bool {
    print("name = '%'\n", name);
    return "", false;
    // return name;
}

platform_get_fonts_dir :: () -> string {
    return "/usr/share/fonts";
}

platform_open_in_explorer :: (dir: string) {
}

#scope_file

Monitor :: struct {
    left   : int;
    top    : int;
    right  : int;
    bottom : int;
};

monitors : [..] Monitor;

LD :: #import "Linux_Display";
