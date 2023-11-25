platform_apply_config :: inline () {
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
    NSWindow.toggleFullScreen(window, window);
}

platform_enable_drag_and_drop :: inline (window: Window_Type) {
    // Currently crashes. Which is strange, because this same line seems to work fine in Codex Viewer.
    // NSView.registerForDraggedTypes(window, NSArray(NSPasteboardType).arrayWithObject(NSPasteboardTypeFileURL));
}

platform_get_dpi_scale :: (window: Window_Type) -> float {
    return xx NSView.convertPointToBacking(NSWindow.contentView(window), .{1, 0}).x;
}

platform_set_window_title :: inline (title: string) {
    NSWindow.setTitle(window, title);
}

platform_wait_message :: inline () {

}

platform_wake_up_main_thread :: () {
    // TODO
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

platform_path_equals :: inline (path_a: string, path_b: string) -> bool {
    return path_a == path_b;
}

platform_path_contains :: inline (path: string, subpath: string) -> bool {
    return contains(path, subpath);
}

platform_set_border_color :: inline () {
}

platform_show_cursor :: (show: bool) {
    if show
        NSCursor.unhide();
    else
        NSCursor.hide();
}

platform_get_troubleshooting_info :: () -> string {
    return "<not implemented>";
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
