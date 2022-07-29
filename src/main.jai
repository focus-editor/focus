main :: () {
    #assert OS == .WINDOWS "Currently only supporting Windows";
    windows_setup();

    window_x, window_y := windows_get_biggest_monitor_pos();
    window = create_window(window_width, window_height, "Focus", window_x, window_y, background_color_rgb = color_as_3_floats(Colors.BACKGROUND), hidden = true);
    windows_maximize_window(window);

    window_width, window_height = Simp.get_render_dimensions(window);
    Simp.set_render_target(window);

    path := path_strip_filename(get_path_of_running_executable());
    set_working_directory(path);

    dpi_scale = windows_get_dpi_scale(window);
    init_fonts();

    editors_open_file("src/editors.jai");

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
                                    font_text_size += 1;
                                    init_fonts();
                                }
                            case #char "-";
                                if it.ctrl_pressed {
                                    font_text_size -= 1;
                                    init_fonts();
                                }
                        }

                        editors_handle_keypress(it.key_code, it.modifier_flags);
                    }
            }
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
    time := get_time();

    editor, buffer := get_active_editor_and_buffer();
    if editor {
        assert(buffer != null);

        line_height := cast(int) (cast(float)font_text.default_line_spacing * 1.3);
        left := font_text.em_width * 2;
        top  := window_height - font_text.em_width * 2;

        // Draw cursor
        {
            width  := font_text.em_width;
            height := line_height;
            x := left + editor.cursor.pos.col  * width;
            y := top  - editor.cursor.pos.line * height;
            p0 := make_vector2(xx x, xx y);
            p1 := p0 + make_vector2(xx width, xx -height);

            Simp.set_shader_for_color();
            Simp.immediate_quad(p0.x, p0.y, p1.x, p1.y, Colors.CURSOR_ACTIVE);
        }

        x := left;
        y := top - font_text.character_height;
        for line : split(to_string(buffer.bytes), cast(u8) #char "\n") {
            Simp.draw_text(font_text, x, y, line);
            y -= line_height;
        }
    }

    Simp.swap_buffers(window);
}

init_fonts :: () {
    font_text = Simp.get_font_at_size("fonts", "FiraCode-Retina.ttf", cast(int) (font_text_size * dpi_scale));
    assert(font_text != null, "Couldn't init font");
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

font_text      :  *Simp.Dynamic_Font;
font_text_size := 14;

font_ui      :  *Simp.Dynamic_Font;
font_ui_size := 14;

#load "style.jai";
#load "layout.jai";
#load "editors.jai";
#load "windows.jai";

#import "Basic";
#import "Math";
#import "File";
#import "Window_Creation";
#import "System";  // For get_path_of_running_executable.
#import "String";
#import "Unicode";

Simp :: #import "Simp";
Input :: #import "Input";
