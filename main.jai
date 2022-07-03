#import "Basic";
#import "Window_Creation";
#import "System";  // For get_path_of_running_executable. @Cleanup.
#import "String";  // For path_strip_filename. @Cleanup.

Simp :: #import "Simp";
Input :: #import "Input";

window : Window_Type;
window_width := 1920;
window_height := 1080;

font: *Simp.Dynamic_Font;

main :: () {
    #if OS == .WINDOWS {
        Windows :: #import "Windows";
        Windows.SetProcessDPIAware();
        Windows.timeBeginPeriod(1);
    }

    window = create_window(window_width, window_height, "Focus");

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
    Simp.clear_render_target(0, 0, 0, 1);
    Simp.set_shader_for_color();
    time := get_time();

    Simp.draw_text(font, 0, 0, TEXT_TO_DISPLAY);

    Simp.swap_buffers(window);
}

init_fonts :: () {
    font = Simp.get_font_at_size("fonts", "FiraCode-Retina.ttf", 24);
    assert(font != null);
}

#run {
    #if OS == .WINDOWS {
        WR :: #import "Windows_Resources";
        WR.disable_runtime_console();
    }
}

TEXT_TO_DISPLAY :: #string END
Водка водка борис ельцин
Водка водка борис ельцин
END
