main :: () {
    init_demo_app("Input Demo");

    held_keys: String_Builder;
    text_edit: [..] u8;

    window_width:  s32 = WINDOW_WIDTH;
    window_height: s32 = WINDOW_HEIGHT;

    quit := false;
    while !quit {
        Input.update_window_events();

        for Input.events_this_frame {
            if it.type == .QUIT then quit = true;

            if it.type == {
                case .KEYBOARD;
                    if it.key_pressed && it.key_code == .BACKSPACE {
                        // @FixMe this works fine for English characters since most of that character set
                        // is one-byte in UTF8, but will not work correctly for many other language characters. 
                        if text_edit.count then pop(*text_edit);
                    }
                case .TEXT_INPUT;
                    value := it.utf32;

                    str := character_utf32_to_utf8(value);
                    for 0..str.count-1 {
                        array_add(*text_edit, str[it]);
                    }
                    free(str);
                case .WINDOW; // @Incomplete: Event_Type.WINDOW events are not generated yet on any of the platforms.
                case .MOUSE_WHEEL;
            }
        }

        resizes := Input.get_window_resizes();  // We might want to collapse all resizes down to 1 for each window, but we don't currently do this, I think.
        for record: resizes {
            // @Bug: Calling update_window will make the render buffer stretch or shrink when resizing -Veeq7
            //Simp.update_window(the_window);

            if record.window == the_window {
                window_width = record.width;
                window_height = record.height;
            }
        }

        for Input.input_button_states {
            if it & .DOWN {
                if it_index >= 0x20 && it_index < 0x7F {
                    value: u8 = cast(u8) it_index;
                    str: string;
                    str.data = *value;
                    str.count = 1;
                    append(*held_keys, str);
                }
            }
        }

        held_keys_text := builder_to_string(*held_keys);
        defer free(held_keys_text);

        text_edit_text: string;
        text_edit_text.data = text_edit.data;
        text_edit_text.count = text_edit.count;

        color := Vector4.{1,1,1,1};
        start_frame();
        draw_text(the_font, color,    20, 20 + FONT_HEIGHT*5, "Window Size: %, %", window_width, window_height);
        draw_text(the_font, color,    20, 20 + FONT_HEIGHT*4, "Text Input: %",    text_edit_text);
        draw_text(the_font, color,    20, 20 + FONT_HEIGHT*3, "Held keys: %",     held_keys_text);
        draw_text(the_font, color,    20, 20 + FONT_HEIGHT*2, "mouse_delta_x: %", Input.mouse_delta_x);
        draw_text(the_font, color,    20, 20 + FONT_HEIGHT*1, "mouse_delta_y: %", Input.mouse_delta_y);
        draw_text(the_font, color,    20, 20 + FONT_HEIGHT*0, "mouse_delta_z: %", Input.mouse_delta_z);
        finish_frame();
    }
}


#scope_file

#import "Basic";
#import "Math";
#import "Window_Creation";
#import "String";
#import "System";

Simp    :: #import "Simp";
Input   :: #import "Input";
Unicode :: #import "Unicode";
System  :: #import "System";

character_utf32_to_utf8 :: Unicode.character_utf32_to_utf8;


init_demo_app :: (title: string) {
    set_working_directory(path_strip_filename(System.get_path_of_running_executable()));

    the_window = create_window(WINDOW_WIDTH, WINDOW_HEIGHT, title);
    Simp.set_render_target(the_window);

    the_font = Simp.get_font_at_size(".", "Skytree_by_MONTAGNA.ttf", FONT_HEIGHT);
    assert(the_font != null);
}

start_frame :: () {
    while true {
        if elapsed_time >= TICK_PERIOD {
            elapsed_time -= TICK_PERIOD;
            break;
        }

        now := seconds_since_init();
        if last_time dt = cast(float) (now - last_time);
        last_time = now;
        
        elapsed_time += dt;
        sleep_milliseconds(2);
    }

    reset_temporary_storage();

    Simp.clear_render_target(0, 0, 0, 1);
}

finish_frame :: () {
    Simp.swap_buffers(the_window);
}

WINDOW_WIDTH  :: 1280;
WINDOW_HEIGHT :: 720;
FONT_HEIGHT :: 32;
fps_time := 0.0;
last_time: float64;
elapsed_time: float64;
TICK_PERIOD : float64 : 1.0/60.0; // time between game updates
dt: float;
the_window: Window_Type;
the_font: *Simp.Dynamic_Font;

draw_text :: (font: *Simp.Dynamic_Font, color: Vector4, x: int, y: int, fmt: string, args: .. Any) {
    assert(font != null);
    builder: String_Builder;

    print_to_builder(*builder, fmt, ..args);
    text := builder_to_string(*builder);
    defer free(text);

    Simp.draw_text(font, x, y, text, color);
}
