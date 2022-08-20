main :: () {
    #assert OS == .WINDOWS "Currently only supporting Windows";
    platform_setup();

    window_x, window_y := platform_get_biggest_monitor_pos();
    window = create_window(window_width, window_height, "Focus", window_x, window_y, background_color_rgb = as_3_floats(Colors.BACKGROUND));
    platform_maximize_window(window);

    window_width, window_height = Simp.get_render_dimensions(window);
    screen = make_rect(0, 0, window_width, window_height);
    Simp.set_render_target(window);

    path := path_strip_filename(get_path_of_running_executable());
    set_working_directory(path);

    dpi_scale = platform_get_dpi_scale(window);
    init_fonts();

    editors_open_file("src/editors.jai");
    editors_open_file("src/main.jai", .right);

    should_quit := false;

    while !should_quit {
        if !redraw_requested platform_wait_message();
        redraw_requested = false;

        Input.update_window_events();

        frame_time = get_time();

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

        update_mouse_pointer();
        pointer_end_frame();

        for * editor: open_editors {
            editor.cursor_moved = false;
        }

        for event : Input.events_this_frame {
            if event.type == {
                case .QUIT;
                    should_quit = true;
                case .KEYBOARD;
                    if event.key_pressed {
                        if event.key_code == {
                            case .F4;
                                if event.alt_pressed should_quit = true;
                                continue;
                            case #char "+";
                                if event.ctrl_pressed {
                                    font_size += 1;
                                    init_fonts();
                                }
                            case #char "-";
                                if event.ctrl_pressed {
                                    font_size -= 1;
                                    init_fonts();
                                }
                        }
                        editors_handle_keypress(event.key_code, event.modifier_flags);
                    }

                case .TEXT_INPUT;
                    editors_handle_text_input(event.utf32);
            }
        }

        refresh_open_buffers();

        draw_frame();

        reset_temporary_storage();
    }
}

init_fonts :: () {
    size := cast(int) (font_size * dpi_scale);
    // font = Simp.get_font_at_size("fonts", "consola.ttf", 25);
    font = Simp.get_font_at_size("fonts", "FiraCode-Retina.ttf", size);
    assert(font != null, "Couldn't init font");
    char_size   = cast(float) font.em_width;
    line_height = cast(float) font.default_line_spacing * LINE_HEIGHT_SCALE;
}

update_mouse_pointer :: () {
    x, y := get_mouse_pointer_position(window, false);
    mouse_pointer.x = xx x;
    mouse_pointer.y = xx (window_height - y);
}

panic :: (format_string: string, args: .. Any, exit_code : s32 = 1) {
    log_error(format_string, ..args);
    exit(exit_code);
} @PrintLike

unimplemented :: (loc := #caller_location) {
    panic("Unimplemented at %", loc);
}

mods_none :: inline (mods: Mods) -> bool {
    return mods.packed == MODS_NONE;
}

mods_ctrl :: inline (mods: Mods) -> bool {
    return mods.packed == MODS_CTRL;
}

mods_ctrl_shift :: inline (mods: Mods) -> bool {
    return mods.packed == MODS_CTRL_SHIFT;
}

key_state :: inline (key: Input.Key_Code) -> Input.Key_Current_State {
    return Input.input_button_states[key];
}

mouse_left_just_pressed :: inline () -> bool {
    return key_state(.MOUSE_BUTTON_LEFT) & .START != 0;
}

mouse_left_just_released :: inline () -> bool {
    return key_state(.MOUSE_BUTTON_LEFT) & .END != 0;
}

mouse_left_is_down :: inline () -> bool {
    return key_state(.MOUSE_BUTTON_LEFT) & .DOWN != 0;
}

shift_pressed :: inline () -> bool {
    return key_state(.SHIFT) & .DOWN != 0;
}

window: Window_Type;
window_width  := 1920;
window_height := 1080;
window_x  := -1;
window_y  := -1;
dpi_scale := 1.0;

redraw_requested := true;  // set to true to render the first frame

frame_time: float64;  // ever-increasing time since start in seconds

screen: Rect;  // contains the current working area rect for convenience

mouse_pointer: Vector2;

// Depend on font
char_size:   float;
line_height: float;

LINE_HEIGHT_SCALE :: 1.2;

font      :  *Simp.Dynamic_Font;
font_size := 14;

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
#load "pointer_image.jai";

#import "Basic";
#import "Math";
#import "File";
#import "System";  // For get_path_of_running_executable.
#import "String";
#import "Unicode";
#import "Window_Creation";

Simp :: #import "Simp";
Input :: #import "Input";


#scope_file

MODS_NONE       :: #run Mods.{}.packed;
MODS_CTRL       :: #run Mods.{ ctrl_pressed = true }.packed;
MODS_CTRL_SHIFT :: #run Mods.{ ctrl_pressed = true, shift_pressed = true }.packed;
