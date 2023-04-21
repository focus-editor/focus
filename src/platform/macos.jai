platform_setup :: () {
    
}

platform_get_biggest_monitor_pos :: () -> s32, s32 {
    unimplemented();
}

platform_maximize_window :: (window: Window_Type) {
    
}

platform_enable_drag_and_drop :: (window: Window_Type) {
    unimplemented();
}

platform_get_dpi_scale :: (window: Window_Type) -> float {
    unimplemented();
}

platform_set_window_title :: (title: string) {
    NSWindow.setTitle(window, title);
}

platform_wait_message :: inline () {
    unimplemented();
}

platform_set_refresh_timer :: (window: Window_Type) {
    unimplemented();
}

platform_kill_refresh_timer :: (window: Window_Type) {
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

#import "Objective_C";
