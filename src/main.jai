main :: () {
    #assert OS == .WINDOWS "Currently only supporting Windows";
    windows_setup();

    // window_x, window_y := windows_get_biggest_monitor_pos();
    window = create_window(window_width, window_height, "Focus", window_x, window_y, background_color_rgb = color_as_3_floats(Colors.BACKGROUND), hidden = true);
    windows_maximize_window(window);

    window_width, window_height = Simp.get_render_dimensions(window);
    Simp.set_render_target(window);

    path := path_strip_filename(get_path_of_running_executable());
    set_working_directory(path);

    dpi_scale = windows_get_dpi_scale(window);
    init_fonts();

    should_quit := false;
    while !should_quit {
        windows_wait_message();
        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);
            if (it.window == window) {
                should_reinit := (it.width != window_width) || (it.height != window_height);
                window_width = it.width;
                window_height = it.height;
                if should_reinit {
                    dpi_scale = windows_get_dpi_scale(window);
                    init_fonts();
                }
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
                if it.key_pressed && it.key_code == #char "+" && it.ctrl_pressed {
                    base_font_size += 1;
                    init_fonts();
                }
                if it.key_pressed && it.key_code == #char "-" && it.ctrl_pressed {
                    base_font_size -= 1;
                    if base_font_size < 5 base_font_size = 5;
                    init_fonts();
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

    line_height := cast(int) (cast(float)font.default_line_spacing * 1.2);
    x := font.em_width;
    y := window_height - line_height - font.em_width;
    for line : split(TEXT_TO_DISPLAY, cast(u8) #char "\n") {
        Simp.draw_text(font, x, y, line);
        y -= line_height;
    }
    // Simp.draw_text(font, 0, window_height - 24, TEXT_TO_DISPLAY);

    Simp.swap_buffers(window);
}

init_fonts :: () {
    font_size := cast(int) (base_font_size * dpi_scale);
    font = Simp.get_font_at_size("fonts", "FiraCode-Retina.ttf", font_size);
    assert(font != null, "Couldn't init font");
}

TEXT_TO_DISPLAY :: #string END
draw_frame :: () {
    Simp.clear_render_target(WINDOW_COLOR[0], WINDOW_COLOR[1], WINDOW_COLOR[2], 1);
    Simp.set_shader_for_color();
    time := get_time();

    Simp.draw_text(font, 0, window_height - 24, TEXT_TO_DISPLAY);

    Simp.swap_buffers(window);
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
dpi_scale := 1.0;

font: *Simp.Dynamic_Font;
base_font_size := 14;

#load "style.jai";
#load "windows.jai";

#import "Basic";
#import "Math";
#import "Window_Creation";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.

Simp :: #import "Simp";
Input :: #import "Input";
