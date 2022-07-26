main :: () {
    windows_setup();

    // window_x, window_y := windows_get_biggest_monitor_pos();
    window = create_window(window_width, window_height, "Focus", window_x, window_y, background_color_rgb = color_as_3_floats(Colors.BACKGROUND), hidden = true);
    windows_maximize_window(window);

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

        draw_frame();

        reset_temporary_storage();
    }
}

draw_frame :: () {
    {
        using Colors.BACKGROUND;
        Simp.clear_render_target(r, g, b, a);
    }
    Simp.set_shader_for_text();
    time := get_time();

    Simp.draw_text(font, 0, window_height - 24, TEXT_TO_DISPLAY);

    Simp.swap_buffers(window);
}

init_fonts :: () {
    font = Simp.get_font_at_size("fonts", "FiraCode-Retina.ttf", 16);
    assert(font != null, "Couldn't init font");
}

// // NOTE: disabled now so that we see errors in the console
// #run {
//     #if OS == .WINDOWS {
//         WR :: #import "Windows_Resources";
//         WR.disable_runtime_console();
//     }
// }

TEXT_TO_DISPLAY :: #string END
draw_frame :: () {
    // Simp.clear_render_target(WINDOW_COLOR[0], WINDOW_COLOR[1], WINDOW_COLOR[2], 1);
    // Simp.set_shader_for_color();
    // time := get_time();

    // Simp.draw_text(font, 0, window_height - 24, TEXT_TO_DISPLAY);

    // Simp.swap_buffers(window);
}
END

panic :: (format_string: string, args: .. Any, exit_code : s32 = 1) {
    log_error(format_string, ..args);
    exit(exit_code);
} @PrintLike



window : Window_Type;
window_width := 1920;
window_height := 1080;
window_x := -1;
window_y := -1;

font: *Simp.Dynamic_Font;

#load "style.jai";
#load "windows.jai";

#import "Basic";
#import "Math";
#import "Window_Creation";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.

Simp :: #import "Simp";
Input :: #import "Input";
