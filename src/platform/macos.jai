PLATFORM_CONFIG_SECTION :: "[[macos]]";
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

platform_setup :: inline () {
    init_mac_app();
}

platform_data_dir :: () -> string {
    application_support := NSFileManager.URLForDirectory(NSFileManager.defaultManager(), NSApplicationSupportDirectory, NSUserDomainMask, null, YES, null);
    config_dir := sprint("%/dev.focus-editor", to_string(NSURL.path(application_support)));
    make_directory_if_it_does_not_exist(config_dir);
    return config_dir;
}

platform_config_dir :: inline () -> string {
    return platform_data_dir();
}

platform_get_centered_window_dimensions :: (open_on_biggest: bool) -> s32, s32, s32, s32 {
    // On macOS, we ignore open_on_biggest for now.

    screen_size := NSScreen.frame(NSScreen.mainScreen()).size;

    w := cast(s32) (screen_size.width  / 1.5);
    h := cast(s32) (screen_size.height / 1.5);
    x := cast(s32) (screen_size.width  / 2 - w / 2);
    y := cast(s32) (screen_size.height / 2 - h / 2);

    return x, y, w, h;
}

platform_create_window :: inline () {
    window = create_window(window_width, window_height, window_generic_title, window_x, window_y);
}

platform_maximize_window :: inline (window: Window_Type) {
    // On macOS, we do not do this.
    // Maximized (fullscreen) text editor windows on launch would feel jarring
    // and out of place. It also comes with a cumbersome fullscreening animation.
}

platform_enable_drag_and_drop :: inline (window: Window_Type) {
    types := NSArray(NSPasteboardType).arrayWithObject(NSPasteboardTypeFileURL);
    NSView.registerForDraggedTypes(window, types);
}

platform_get_dpi_scale :: (window: Window_Type) -> float {
    return xx NSView.convertPointToBacking(NSWindow.contentView(window), .{1, 0}).x;
}

platform_set_window_title :: inline (title: string) {
    NSWindow.setTitle(window, title);
}

platform_wait_message :: inline () {

}

platform_set_refresh_timer :: inline (window: Window_Type) {

}

platform_kill_refresh_timer :: inline (window: Window_Type) {

}

platform_enumerate_logical_drives :: inline () -> [] string {
    return .["/"];
}

platform_get_save_file_name :: inline (name := "") -> string, bool {
    return "", false;
}

platform_find_font_by_name :: (name: string, allocator := temp) -> bool, string {
    return false, "";
}

platform_get_fonts_dir :: inline () -> string {
    return "/Library/Fonts";
}

platform_open_in_explorer :: (path: string, reveal := false) {
    if reveal run_command("open", "-R", path);
    else      run_command("open", path);
}

platform_path_equals :: (path_a: string, path_b: string) -> bool {
    return path_a == path_b;
}

#scope_file

Monitor :: struct {
    left   : int;
    top    : int;
    right  : int;
    bottom : int;
};

monitors : [..] Monitor;

#import "Objective_C";
#import "Objective_C/AppKit";
#import "Process";
