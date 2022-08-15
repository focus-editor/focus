main :: () {
    #assert OS == .WINDOWS "Currently only supporting Windows";
    platform_setup();

    window_x, window_y := platform_get_biggest_monitor_pos();
    window = create_window(window_width, window_height, "Focus", window_x, window_y, background_color_rgb = color_as_3_floats(Colors.BACKGROUND));
    platform_maximize_window(window);

    window_width, window_height = Simp.get_render_dimensions(window);
    screen = make_rect(0, 0, window_width, window_height);
    Simp.set_render_target(window);

    path := path_strip_filename(get_path_of_running_executable());
    set_working_directory(path);

    dpi_scale = platform_get_dpi_scale(window);
    init_fonts();

    editors_open_file("src/layout.jai");

    should_quit := false;
    while !should_quit {
        platform_wait_message();
        Input.update_window_events();

        for Input.get_window_resizes() {
            Simp.update_window(it.window);
            if (it.window == window) {
                should_reinit := (it.width != window_width) || (it.height != window_height);
                window_width = it.width;
                window_height = it.height;
                if should_reinit {
                    screen    = make_rect(0, 0, window_width, window_height);
                    dpi_scale = platform_get_dpi_scale(window);
                    init_fonts();
                }
            }
        }

        refresh_open_buffers();

        for Input.events_this_frame {
            if it.type == {
                case .QUIT;
                    should_quit = true;
                case .KEYBOARD;
                    if it.key_pressed {
                        if it.key_code == {
                            case .F4;
                                if it.alt_pressed should_quit = true;
                                continue;
                            case #char "+";
                                if it.ctrl_pressed {
                                    font_size += 1;
                                    init_fonts();
                                }
                            case #char "-";
                                if it.ctrl_pressed {
                                    font_size -= 1;
                                    init_fonts();
                                }
                        }

                        editors_handle_keypress(it.key_code, it.modifier_flags);
                    }
                case .TEXT_INPUT;
                    editors_handle_text_input(it.utf32);
            }
        }

        draw_frame();

        reset_temporary_storage();
    }
}

init_fonts :: () {
    size := cast(int) (font_size * dpi_scale);
    font = Simp.get_font_at_size("fonts", "consola.ttf", size);
    // font = Simp.get_font_at_size("fonts", "FiraCode-Retina.ttf", size);
    assert(font != null, "Couldn't init font");
    char_size   = cast(float) font.em_width;
    line_height = cast(float) font.default_line_spacing * LINE_HEIGHT_SCALE;
}

panic :: (format_string: string, args: .. Any, exit_code : s32 = 1) {
    log_error(format_string, ..args);
    exit(exit_code);
} @PrintLike

unimplemented :: (loc := #caller_location) {
    panic("Unimplemented at %", loc);
}

window: Window_Type;
window_width  := 1920;
window_height := 1080;
window_x  := -1;
window_y  := -1;
dpi_scale := 1.0;

screen: Rect;

// Depend on font
char_size:   float;
line_height: float;

LINE_HEIGHT_SCALE :: 1.2;

font      :  *Simp.Dynamic_Font;
font_size := 17;

font_ui      :  *Simp.Dynamic_Font;
font_ui_size := 17;

Mods :: Input.Event.Modifier_Flags;

#load "style.jai";
#load "layout.jai";
#load "editors.jai";
#load "buffer.jai";
#load "edit_text.jai";
#load "windows.jai";
#load "unicode.jai";
#load "draw.jai";

#import "Basic";
#import "Math";
#import "File";
#import "Window_Creation";
#import "System";  // For get_path_of_running_executable.
#import "String";
#import "Unicode";

Simp :: #import "Simp";
Input :: #import "Input";
