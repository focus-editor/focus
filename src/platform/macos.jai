platform_apply_config :: inline () {
}

platform_setup :: inline () {
    init_mac_app();
}

platform_data_dir :: () -> string {
    application_support := to_string(NSURL.path(NSFileManager.URLForDirectory(NSFileManager.defaultManager(), NSApplicationSupportDirectory, NSUserDomainMask, null, YES, null)));

    config_dir := sprint("%/dev.focus-editor", application_support);
    #if DEBUG {
        config_dir = sprint("%/dev.focus-editor/debug", application_support);
    }
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
    platform_set_border_color();
}

platform_maximize_window :: inline (window: Window_Type) {
    NSWindow.maximize(window);
}

platform_enable_drag_and_drop :: inline (window: Window_Type) {
    NSView.registerForDraggedTypes(window, NSArray(NSPasteboardType).arrayWithObject(NSPasteboardTypeFileURL));
}

platform_get_dpi_scale :: (window: Window_Type) -> float {
    return xx NSView.convertPointToBacking(NSWindow.contentView(window), .{1, 0}).x;
}

platform_set_window_title :: inline (title: string) {
    NSWindow.setTitle(window, title);
}

platform_wait_message :: inline () {
    Input.macos_wait_for_event();
}

platform_wake_up_main_thread :: () {
    nsev := NSEvent.otherEventWithType(
        type = NSEventTypeApplicationDefined,
        location = .{},
        modifierFlags = 0,
        timestamp = 0,
        windowNumber = 0,
        ctx = null,
        subtype = 0,
        data1 = 0,
        data2 = 0);
    NSApplication.postEvent(NSApp, nsev, YES);
}

platform_set_refresh_timer :: inline (window: Window_Type) {
    destroy_timer(refresh_timer);
    refresh_timer = create_timer(1000, true);
}

platform_set_cursor_timer :: inline (window: Window_Type) {
    destroy_timer(cursor_timer);
    cursor_timer = create_timer(50, true);
}

platform_kill_cursor_timer :: inline (window: Window_Type) {
    destroy_timer(cursor_timer);
    cursor_timer = null;
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

platform_path_begins_with :: inline (path: string, subpath: string) -> bool {
    return begins_with(path, subpath);
}

platform_path_contains :: inline (path: string, subpath: string) -> bool {
    return contains(path, subpath);
}

platform_set_border_color :: inline () {
    // NOTE: this gets called during compile-time parsing of the default config file which
    //       causes the meta-program to crash.
    if #compile_time return;

    bg := map_color_to_vec4(.BACKGROUND_0);

    // There is no way to set the color of the title bar directly. Instead we set the titlebar as
    // "transparent" and the window's color background to the active theme's background color.
    color := NSColor.colorWithRed(bg.x, bg.y, bg.z, 1.0);
    defer release(color);
    NSWindow.setTitlebarAppearsTransparent(window, YES);
    NSWindow.setBackgroundColor(window, color);

    // There is no way to change the color of the title bar text directly. As a result we do
    // the following:
    //   1. classify the active theme's background color as either "dark" or "light". We do this
    //      by applying the algorithm described on this page: http://alienryderflex.com/hsp.html
    //   2. we set the window appearance to be either the "dark" on "light" macOS theme based on
    //      the result of the classification from step 1, which indirectly set a (hopefully)
    //      appropriate titlebar text color.
    hsp := sqrt(bg.x * bg.x * .299 + bg.y * bg.y * .587 + bg.z * bg.z * .114) * 256.0;
    appearance_name := ifx hsp < 130 then "NSAppearanceNameDarkAqua" else "NSAppearanceNameAqua";
    NSWindow.setAppearance(window, NSAppearance.appearanceNamed(NSString.getTempString(appearance_name)));
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
#import "Hash_Table";
#import "Math";

// We need to store the association between `Focus_Timer` instances and `NSTimer` instances externally
// since currently we can't properly do instance variables for Cocoa classes (see the warning at the
// top of `modules/Objective_C/module.jai` for more details). Granted this platform layer only ever
// uses a single timer but I've implemented the "generic" way in case we ever want to move this
// implementation to some macOS support module (similar to how `Linux_Display` works).
//
//  - @ileonte 23.01.2024
//
native_timers: Table(*Focus_Timer, *NSTimer);
refresh_timer: *Focus_Timer;
cursor_timer:  *Focus_Timer;

timer_class_registered := false;
Focus_Timer :: struct {
    using #as base: NSObject;

    timerFired :: (using self: *Focus_Timer, _sel: Selector, notification: *NSNotification) #c_call {
        event := NSEvent.otherEventWithType(
            type = NSEventTypeApplicationDefined,
            location = .{},
            modifierFlags = 0,
            timestamp = 0,
            windowNumber = 0,
            ctx = null,
            subtype = 0,
            data1 = 0,
            data2 = 0);
        NSApplication.postEvent(NSApp, event, YES);
    } @selector(timerFired:)
}

create_timer :: (timeout_ms: u64, repeat := true) -> *Focus_Timer {
    if !timer_class_registered {
        timer_class_registered = true;
        init(*native_timers);

        cls := objc_create_class(Focus_Timer, NSObject);
        objc_add_instance_method(cls, Focus_Timer.timerFired, "timerFired:");
        objc_finalize_class(cls);
    }
    ret := objc_new(Focus_Timer);
    ns_timer := NSTimer.scheduledTimerWithTimeInterval(
        interval = cast(float64)timeout_ms * 0.01,
        target = ret,
        selector = selector("timerFired:"),
        userInfo = null,
        repeats = YES);
    table_add(*native_timers, ret, ns_timer);
    NSRunLoop.addTimer(NSRunLoop.currentRunLoop(), ns_timer, NSRunLoopCommonModes);
    return ret;
}

destroy_timer :: (timer: *Focus_Timer) {
    if (timer) {
        ns_timer, found := table_find(*native_timers, timer);
        if found {
            NSTimer.invalidate(ns_timer);
            table_remove(*native_timers, timer);
        }
        release(timer);
    }
}
