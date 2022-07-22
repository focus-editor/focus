main :: () {
    assert(OS == .WINDOWS, "Currently only supporting Windows");

    SetProcessDPIAware();
    timeBeginPeriod(1);
    EnumDisplayMonitors(null, null, monitor_enum_proc_win32, 0);

    window_x, window_y := get_biggest_monitor_pos();
    window = create_window(window_width, window_height, "Focus", window_x, window_y, background_color_rgb = WINDOW_COLOR, hidden = true);
    ShowWindow(window, SW_MAXIMIZE);

    window_width, window_height = Simp.get_render_dimensions(window);
    Simp.set_render_target(window);

    path := path_strip_filename(get_path_of_running_executable());
    set_working_directory(path);

    init_fonts();

    should_quit := false;
    while !should_quit {
        Input.update_window_events(wait = true);

        for Input.get_window_resizes() {
            Simp.update_window(it.window);
            if (it.window == window) {
                should_reinit := (it.width != window_width) || (it.height != window_height);
                window_width = it.width;
                window_height = it.height;
                if should_reinit init_fonts();
            }
        }

        for Input.events_this_frame {
            if it.type == {
              case .QUIT;
                should_quit = true;
              case .KEYBOARD;
                if it.key_pressed && it.key_code == .ESCAPE {
                    should_quit = true;
                }
            };

        }

        draw_one_frame();

        reset_temporary_storage();
    }
}

draw_one_frame :: () {
    Simp.clear_render_target(WINDOW_COLOR[0], WINDOW_COLOR[1], WINDOW_COLOR[2], 1);
    Simp.set_shader_for_color();
    time := get_time();

    Simp.draw_text(font, 0, window_height - 24, TEXT_TO_DISPLAY);

    Simp.swap_buffers(window);
}

init_fonts :: () {
    font = Simp.get_font_at_size("fonts", "FiraCode-Retina.ttf", 20);
    assert(font != null);
}

#if OS == .WINDOWS {
    monitor_enum_proc_win32 :: (hMonitor: HMONITOR, hdc: HDC, rect: *RECT, data: LPARAM) -> BOOL #c_call {
        if monitor_count >= monitor_rects.count return xx false;

        monitor := *monitor_rects[monitor_count];
        monitor.left   = rect.left;
        monitor.top    = rect.top;
        monitor.right  = rect.right;
        monitor.bottom = rect.bottom;

        monitor_count += 1;

        return xx true;
    }
}

get_biggest_monitor_pos :: () -> s32, s32 {
    assert(monitor_count > 0, "Unexpectedly no monitors found. This is a bug.");
    biggest := monitor_rects[0];
    max_area := 0;
    for monitor_rects {
        width := it.right - it.left;
        height := it.bottom - it.top;
        area := width * height;
        if max_area < area then biggest = monitor_rects[it_index];
    }
    return cast(s32) biggest.left, cast(s32) biggest.top;
}

// // NOTE: disabled now so that we see errors in the console
// #run {
//     #if OS == .WINDOWS {
//         WR :: #import "Windows_Resources";
//         WR.disable_runtime_console();
//     }
// }

TEXT_TO_DISPLAY :: #string END
draw_one_frame :: () {
    Simp.clear_render_target(WINDOW_COLOR[0], WINDOW_COLOR[1], WINDOW_COLOR[2], 1);
    Simp.set_shader_for_color();
    time := get_time();

    Simp.draw_text(font, 0, window_height - 24, TEXT_TO_DISPLAY);

    Simp.swap_buffers(window);
}
END

WINDOW_COLOR :: float.[0.086, 0.133, 0.165];

window : Window_Type;
window_width := 1920;
window_height := 1080;
window_x := -1;
window_y := -1;

font: *Simp.Dynamic_Font;

Monitor_Rect :: struct {
    left   : int;
    top    : int;
    right  : int;
    bottom : int;
};

monitor_rects : [10] Monitor_Rect;
monitor_count := 0;

#import "Basic";
#import "Window_Creation";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.

#import "Windows";

Simp :: #import "Simp";
Input :: #import "Input";
