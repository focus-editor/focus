main :: () {
    g_window = create_window(WINDOW_WIDTH, WINDOW_HEIGHT, "Focus");

    should_quit := false;

    while !should_quit {
        update_window_events();

        for events_this_frame {
            if it.type == .QUIT then should_quit = true;

            if it.type == .KEYBOARD {
                if it.key_pressed == 0 continue;
                if it.key_code == .ESCAPE should_quit = true;
            }
        }
    }

}

#scope_file

#import "Window_Creation";
#import "Input";

WINDOW_WIDTH :: 1280;
WINDOW_HEIGHT :: 720;

g_window : Window_Type;
