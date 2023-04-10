main :: () {
    cpu_info = get_cpu_info();
    platform_setup();
    
    window_x, window_y := platform_get_biggest_monitor_pos();
    window_generic_title = ifx DEBUG then "Focus (debug mode)" else "Focus";
    window = create_window(window_width, window_height, window_generic_title, window_x, window_y, background_color_rgb = as_3_floats(Colors.BACKGROUND));
    platform_maximize_window(window);
    
    platform_enable_drag_and_drop(window);

    window_width, window_height = Simp.get_render_dimensions(window);
    screen = make_rect(0, 0, window_width, window_height);
    Simp.set_render_target(window);

    init_buffers();
    
    // !!!!!!!
    // Setup temporary editor and buffer for testing new buffer representation 
    {
        // Create and load file
        // path := copy_string(get_absolute_path(".gitignore"));
        path := copy_string(get_absolute_path("sqlite3.c"));
        file_data, success := read_entire_file(path);
        if !success then file_data = sprint("Couldn't load file '%'", path);
        
        new_buffer.file = get_file_info_from_full_path(path);
        new_buffer.has_file = true;
        // remember_last_modtime_and_size(buffer);
        
        new_buffer.bytes = resizable(to_bytes(file_data));
        // remove_crlf(buffer);
        rescan_for_lines(*new_buffer);
        
        new_buffer.meow_hash = calculate_meow_hash(new_buffer.bytes);
        // new_buffer.lang = .Jai;
        
        array_add(*new_editor.cursors, Cursor.{});
        array_add(*new_editor.carets, Caret.{});
        
    }
    
    // Remember important directories
    exe_dir = copy_string(path_strip_filename(get_path_of_running_executable()));
    if ends_with(exe_dir, "/") exe_dir.count -= 1;
    temp_dir     = sprint("%/temp",     exe_dir);
    projects_dir = sprint("%/projects", exe_dir);
    
    assert(exe_dir.count > 0);
    load_global_config();
    
    if !make_directory_if_it_does_not_exist(projects_dir) then panic_messagebox("Couldn't create folder %. Is the directory writable?", projects_dir);
    if !make_directory_if_it_does_not_exist(temp_dir)     then panic_messagebox("Couldn't create folder % for temporary files. Is the directory writable?", temp_dir);
    
    init_session_with_no_guidance :: () #expand {
        session = maybe_load_previous_session();
        if session.project {
            success := load_project_config(session.project);
            if !success then log_error("Couldn't load project config '%'", session.project);
        }
    }
    
    args := get_command_line_arguments();
    
    if args.count == 2 {
        // Check if a directory or file was passed in the command line (or by drag/dropping a file/directory onto the executable)
        if is_directory(args[1]) {
            // Open directory passed in the command line
            session = start_fresh_session();
            dir_path := copy_string(get_absolute_path(args[1]));
            
            path_overwrite_separators(dir_path, #char "/");
            
            workspace_dirs := resizable(config.workspace.workspace_dirs);
            array_insert_at(*workspace_dirs, dir_path, 0);
            config.workspace.workspace_dirs = workspace_dirs;
        } else if file_exists(args[1]) {
            // Open file passed in the command line
            session = start_fresh_session();
            
            editors_open_file(args[1]);
        } else {
            init_session_with_no_guidance();
        }
    } else {
        init_session_with_no_guidance();
    }
    
    // Requires the session to be created and the configs to be loaded
    init_workspace();
    
    // Init logger after we know the session dir and the config
    init_logger();
    defer deinit_logger();  // closes log file handles
    
    dpi_scale = platform_get_dpi_scale(window);
    init_fonts_and_dependent_things();
    old_line_height = line_height;

    window_has_focus := true;
    window_resized   := false;
    should_quit := false;

    while !should_quit {
        if !redraw_requested platform_wait_message();
        
        Input.update_window_events();
        
        if frame_time > MAX_TIME_BEFORE_RESETTING then { init_time(); frame_time = cast(Time) get_time(); }
        current_time := cast(Time) get_time();
        frame_dt   = min(current_time - frame_time, MAX_FRAME_DT);
        frame_time = current_time;

        old_line_height = line_height;
        for Input.get_window_resizes() {
            Simp.update_window(it.window);
            if (it.window == window) {
                should_reinit := (it.width != window_width) || (it.height != window_height);
                window_width = it.width;
                window_height = it.height;
                if should_reinit {
                    screen    = make_rect(0, 0, window_width, window_height);
                    dpi_scale = platform_get_dpi_scale(window);
                    init_fonts_and_dependent_things();
                }
                window_resized = true;
            }
        }

        // Don't do anything when window is resized to a size that's too small
        if window_width < MIN_WINDOW_WIDTH || window_height < MIN_WINDOW_HEIGHT continue;
        
        update_mouse_state();
        
        screen_with_title_bar := screen;
        screen_with_title_bar.h += 200;  // should be enough to include the title bar
        
        // Don't redraw if we're mousing around outside the window
        if !redraw_requested 
            && !Input.events_this_frame 
            && !mouse_pointer_is_within(screen_with_title_bar) 
            && window_has_focus == Input.input_application_has_focus 
            && !window_resized 
        then 
            continue;
           
        redraw_requested = false;
        window_resized   = false;
        dont_scroll_this_frame = false;
        window_has_focus = Input.input_application_has_focus;  // so that we always redraw when the window first loses focus

        maybe_update_workspace_buffers();
        finder_update();

        for * editor : open_editors {
            using editor;
            cursor_moved = false;
            if old_line_height != line_height {
                // Adjust viewport position
                lines_scrolled := viewport.top / old_line_height;
                viewport.scroll_y.target = xx (lines_scrolled * line_height);
                viewport.top = viewport.scroll_y.target;
            }
        }

        for event : Input.events_this_frame {
            // General events
            if event.type == {
                case .QUIT;
                    should_quit = true;
                case .KEYBOARD;
                    if event.key_pressed {
                        if event.key_code == {
                            case .F4;
                                if event.alt_pressed should_quit = true;
                        }
                    }
                    action := map_event_to_action(event, Action_Common);
                    if action == {
                        case .increase_font_size;           increase_font_size();
                        case .decrease_font_size;           decrease_font_size();
                        case .reset_font_size_to_default;   reset_font_size_to_default();
                    }
                case .MOUSE_WHEEL;
                    if ctrl_pressed() {
                        if event.wheel_delta < 0  {
                            decrease_font_size();
                            dont_scroll_this_frame = true;
                        } else if event.wheel_delta > 0 {
                            increase_font_size();
                            dont_scroll_this_frame = true;
                        }
                    }
                case .DRAG_AND_DROP_FILES;
                    editors_handle_file_drop(event.files);
            }

            // Pass events to the active widget.
            // Note that the active widget may change during the frame, so the following events
            // will be sent to the new widget, that's why we check global widget for each event.
            if active_global_widget == {
                case .editors;           editors_handle_event(event);
                case .open_file_dialog;  open_file_dialog_handle_event(event);
                case .finder;            finder_handle_event(event);
            }
        }

        refresh_open_buffers();
        
        draw_frame();

        pointer_end_frame();
        
        maybe_save_editor_state_into_session();

        reset_temporary_storage();
        
        #if DEBUG FrameMark();
        
        if cast(Time) get_time() - frame_time <= QUICK_FRAME_DT {
            // It should be ok to sleep a bit after a quick frame to avoid pegging the core.
            // NOTE: I tried vsync but for some reason it felt super bad - didn't figure out exactly why
            sleep_milliseconds(2);
        }
    }

    // report := make_leak_report();
    // log_leak_report(report);
}

init_fonts_and_dependent_things :: () {
    delta := font_size - DEFAULT_FONT_SIZE;
    font_ui_size          = clamp(DEFAULT_FONT_UI_SIZE       + delta,    MIN_FONT_SIZE, MAX_FONT_SIZE);
    font_ui_small_size    = clamp(DEFAULT_FONT_UI_SMALL_SIZE + delta,    MIN_FONT_SIZE, MAX_FONT_SIZE);
    font_icons_size       = clamp(DEFAULT_FONT_ICONS_SIZE    + delta,    MIN_FONT_SIZE, MAX_FONT_SIZE);
    font_icons_small_size = clamp(DEFAULT_FONT_ICONS_SMALL_SIZE + delta, MIN_FONT_SIZE, MAX_FONT_SIZE);
    
    font = Simp.get_font_at_size(FONT.name, FONT.data, cast(int) (font_size * dpi_scale));
    assert(font != null, "Couldn't init main text font\n");

    font_ui = Simp.get_font_at_size(FONT_UI.name, FONT_UI.data, cast(int) (font_ui_size * dpi_scale));
    assert(font_ui != null, "Couldn't init main ui font\n");
    font_ui_line_height = cast(float) font_ui.default_line_spacing;

    font_ui_bold = Simp.get_font_at_size(FONT_UI_BOLD.name, FONT_UI_BOLD.data, cast(int) (font_ui_size * dpi_scale));
    assert(font_ui_bold != null, "Couldn't init bold ui font\n");

    font_ui_small = Simp.get_font_at_size(FONT_UI.name, FONT_UI.data, cast(int) (font_ui_small_size * dpi_scale));
    assert(font_ui_small != null, "Couldn't init small ui font\n");

    font_icons = Simp.get_font_at_size(FONT_ICONS.name, FONT_ICONS.data, cast(int) (font_icons_size * dpi_scale));
    assert(font_icons != null, "Couldn't init main icon font\n");
    
    font_icons_small = Simp.get_font_at_size(FONT_ICONS.name, FONT_ICONS.data, cast(int) (font_icons_small_size * dpi_scale));
    assert(font_icons_small != null, "Couldn't init small icon font\n");

    // WORKAROUND:
    // Make a dummy call with most common chars for each font so that
    // we have all the font atlases loaded in the GPU memory once
    // (TODO: maybe there's an easy way for Simp to only update textures on flush?)
    COMMON_CHARS :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789… ~!@#$%^&*()-|\"':;_+={}[]\\/`,.<>?АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчщъыьэюя¶•";
    Simp.prepare_text(font,          COMMON_CHARS);
    Simp.prepare_text(font_ui,       COMMON_CHARS);
    Simp.prepare_text(font_ui_bold,  COMMON_CHARS);
    Simp.prepare_text(font_ui_small, COMMON_CHARS);
    
    common_icons: String_Builder;
    common_icons.allocator = temp;
    for enum_values_as_enum(File_Icon) {
        char := convert_utf32_to_utf8(xx it);
        append(*common_icons, to_string(*char));
    }
    append(*common_icons, PEN_CHAR);
    icons_string := builder_to_string(*common_icons);
    
    Simp.prepare_text(font_icons,       icons_string);
    Simp.prepare_text(font_icons_small, icons_string);
    
    // Things that depend on char size
    char_size       = cast(float) font.em_width;
    old_line_height = line_height;
    line_height     = floor(cast(float) font.default_line_spacing * LINE_HEIGHT_SCALE);
    scrollbar_size  = floor(1.5 * char_size);
    rounding_radius = floor(char_size / 2);
    rounding_radius_large = floor(char_size / 1.5);
    rounding_radius_small = floor(char_size / 3);
}

update_mouse_state :: () {
    x, y := get_mouse_pointer_position(window, false);
    mouse.pointer.x = xx x;
    mouse.pointer.y = xx (window_height - y);

    mouse.scroll_y_delta = cast(s32) (cast(float) Input.mouse_delta_z * WHEEL_SENSITIVITY);

    update_button(*mouse.left,   .MOUSE_BUTTON_LEFT);
    update_button(*mouse.right,  .MOUSE_BUTTON_RIGHT);
    update_button(*mouse.middle, .MOUSE_BUTTON_MIDDLE);

    update_button :: (button: *Mouse_Button_State, key: Input.Key_Code) {
        button.is_down       = key_state(key) & .DOWN  != 0;  // NOTE: this doesn't include just_pressed!
        button.just_pressed  = key_state(key) & .START != 0;
        button.just_released = key_state(key) & .END   != 0;

        if button.just_pressed {
            time_from_last_click := frame_time - button.last_down_time;
            time_from_last_double_click := frame_time - button.last_double_click_time;
            distance_from_last_click := mouse.pointer - button.last_down_pos;
            max_distance := max(abs(distance_from_last_click.x), abs(distance_from_last_click.y));
            button.last_down_pos  = mouse.pointer;
            button.last_down_time = frame_time;
            button.just_double_clicked = time_from_last_click < DOUBLE_CLICK_SPEED && max_distance < DOUBLE_CLICK_TOLERANCE;
            button.just_triple_clicked = time_from_last_double_click < DOUBLE_CLICK_SPEED && max_distance < DOUBLE_CLICK_TOLERANCE;
            if button.just_triple_clicked then button.just_double_clicked = false;  // exclusive
            if button.just_double_clicked {
                button.last_double_click_time = frame_time;
            }
        } else {
            button.just_double_clicked = false;
            button.just_triple_clicked = false;
        }

        button.is_dragging = button.is_down && mouse.pointer != button.last_down_pos && frame_time - button.last_double_click_time >= DRAG_AFTER_DOUBLE_CLICK_TIMEOUT;
    }
}

increase_font_size :: () {
    if (font_size + 1) <= MAX_FONT_SIZE {
        font_size += 1;
        init_fonts_and_dependent_things();
    }
}

decrease_font_size :: () {
    if (font_size - 1) >= MIN_FONT_SIZE {
        font_size -= 1;
        init_fonts_and_dependent_things();
    }
}

reset_font_size_to_default :: () {
    font_size = DEFAULT_FONT_SIZE;
    init_fonts_and_dependent_things();
}

panic :: (format_string: string, args: .. Any, exit_code : s32 = 1) {
    log_error(format_string, ..args);
    exit(exit_code);
} @PrintLike

panic_messagebox :: (format_string: string, args: .. Any) {
    #if OS == .WINDOWS {
        message := tprint(format_string, ..args);
        MessageBoxW(null, utf8_to_wide(message), utf8_to_wide("Fatal Error"), MB_OK);
        exit(1);
    } else {
        panic(format_string, ..args);
    }
} @PrintLike

unimplemented :: (loc := #caller_location) {
    panic("Unimplemented at %", loc);
}

nothing_pressed :: inline (mods: Mods) -> bool {
    return mods.packed == MODS_NONE;
}

only_ctrl_pressed :: inline (mods: Mods) -> bool {
    return mods.packed == MODS_CTRL;
}

only_alt_pressed :: inline (mods: Mods) -> bool {
    return mods.packed == MODS_ALT;
}

only_shift_pressed :: inline (mods: Mods) -> bool {
    return mods.packed == MODS_SHIFT;
}

only_alt_shift_pressed :: inline (mods: Mods) -> bool {
    return mods.packed == MODS_ALT_SHIFT;
}

only_ctrl_shift_pressed :: inline (mods: Mods) -> bool {
    return mods.packed == MODS_CTRL_SHIFT;
}

only_ctrl_alt_pressed :: inline (mods: Mods) -> bool {
    return mods.packed == MODS_CTRL_ALT;
}
only_ctrl_alt_shift_pressed :: inline (mods: Mods) -> bool {
    return mods.packed == MODS_CTRL_ALT_SHIFT;
}

key_state :: inline (key: Input.Key_Code) -> Input.Key_Current_State {
    return Input.input_button_states[key];
}

shift_pressed :: inline () -> bool {
    return key_state(.SHIFT) & .DOWN != 0;
}

ctrl_pressed :: inline () -> bool {
    return key_state(.CTRL) & .DOWN != 0;
}

// Important directories
exe_dir:      string;
temp_dir:     string;
projects_dir: string;

window: Window_Type;
window_generic_title: string = ---;
window_width  := 1920;
window_height := 1080;
window_x  := -1;
window_y  := -1;
dpi_scale := 1.0;

redraw_requested := true;  // set to true to render the first frame

frame_time: Time;                 // ever-increasing time since start in seconds
frame_dt:   Time = MAX_FRAME_DT;  // time delta since the last frame
MAX_FRAME_DT:   Time : xx (1.0 / 60);
QUICK_FRAME_DT: Time : xx (1.0 / 300);  // sorry 300Hz monitor users
MAX_TIME_BEFORE_RESETTING: Time : xx (60 * 60 * 24 * 7);  // reset timer after a week to avoid losing timer precision

EDIT_GROUP_TIMEOUT :: 0.3;  // for undo/redo

screen: Rect;  // contains the current working area rect for convenience

mouse: Mouse_State;

Mouse_State :: struct {
    pointer: Vector2;
    scroll_y_delta: s32;

    left:   Mouse_Button_State;
    right:  Mouse_Button_State;
    middle: Mouse_Button_State;
}

Mouse_Button_State :: struct {
    is_down:             bool;
    is_dragging:         bool;
    just_pressed:        bool;
    just_released:       bool;
    just_double_clicked: bool;
    just_triple_clicked: bool;

    last_down_pos:  Vector2;
    last_down_time: Time;
    last_double_click_time: Time;
}

LINE_HEIGHT_SCALE :: 1.2;

WHEEL_SENSITIVITY :: 1.0;

PEN_CHAR    :: #run to_string(*convert_utf32_to_utf8(0xf304));
BULLET_CHAR :: #run to_string(*convert_utf32_to_utf8(0x2022));

font:               *Simp.Dynamic_Font;
font_ui:            *Simp.Dynamic_Font;
font_ui_bold:       *Simp.Dynamic_Font;
font_ui_small:      *Simp.Dynamic_Font;
font_icons:         *Simp.Dynamic_Font;
font_icons_small:   *Simp.Dynamic_Font;

DEFAULT_FONT_SIZE               :: 14;
DEFAULT_FONT_UI_SIZE            :: 16;
DEFAULT_FONT_UI_SMALL_SIZE      :: 15;
DEFAULT_FONT_ICONS_SIZE         :: 16;
DEFAULT_FONT_ICONS_SMALL_SIZE   :: 8;

font_size               := DEFAULT_FONT_SIZE;  // when changing font size, we change just this one and then derive the other ones from it
font_ui_size            := DEFAULT_FONT_UI_SIZE;
font_ui_small_size      := DEFAULT_FONT_UI_SMALL_SIZE;
font_icons_size         := DEFAULT_FONT_ICONS_SIZE;
font_icons_small_size   := DEFAULT_FONT_ICONS_SMALL_SIZE;

// Depend on font size
char_size:              float;
line_height:            float;
old_line_height:        float;  // to track font changes
font_ui_line_height:    float;
rounding_radius:        float;
rounding_radius_large:  float;
rounding_radius_small:  float;
scrollbar_size:         float;

dont_scroll_this_frame := false;  // because e.g. a mouse wheel event has been handled

Mods :: Input.Event.Modifier_Flags;

Time :: #type,isa float64;

project_dirs: [..] Project_Dir;

active_global_widget: enum {
    editors;
    open_file_dialog;
    finder;
} = .editors;

Project_Dir :: struct {
    path: string;          // e.g. "C:/projects/focus"
    path_prefix_len: s64;  // in this case the length of "C:/projects/"
}

// A string which contains the path to a file which was just drag-and-dropped into the editor (for the draw code to use)
just_dropped_file := "";

cpu_info: Cpu_X86;

// !!!!!!!!!!!!!!!
new_editor: Editor;
new_buffer: NewBuffer;
// !!!!!!!!!!!!!!!


#load "layout.jai";
#load "editors.jai";
#load "buffer.jai";
#load "unicode.jai";
#load "draw.jai";
#load "pointer_image.jai";
#load "utils.jai";
#load "files.jai";
#load "workspace.jai";
#load "config.jai";
#load "keymap.jai";
#load "session.jai";
#load "meow_hash.jai";
#load "widgets/text_input.jai";
#load "widgets/open_file_dialog.jai";
#load "widgets/finder.jai";
#load "langs/jai.jai";
#load "langs/focus_config.jai";
#load "langs/worklog.jai";

#if OS == .WINDOWS {
    #load "platform/windows.jai";
    #import "Windows_Utf8";
} else #if OS == .LINUX {
    #load "platform/linux.jai";
} else #if OS == .MACOS {
    #load "platform/macos.jai";
} else {
    #assert false, "Unsupported OS";
}

// #import "Basic"()(MEMORY_DEBUGGER = true);
#import "Basic";
#import "Math";
#import "Sloppy_Math";
#import "File";
#import "File_Utilities";
#import "File_Watcher";
#import "Flat_Pool";
#import "System";
#import "String";
#import "Sort";
#import "Unicode";
#import "Window_Creation";
#import "Thread";
#import "Compiler";
#import "Machine_X64";

// #if DEBUG {
    #import "Tracy";
// }

File_Async :: #import "File_Async";

Simp :: #import "Simp_Ext";
Input :: #import "Input";

DEBUG :: #run get_build_options().optimization_level != .RELEASE;

#scope_file

MODS_NONE           :: #run Mods.{}.packed;
MODS_CTRL           :: #run Mods.{ ctrl_pressed  = true }.packed;
MODS_ALT            :: #run Mods.{ alt_pressed   = true }.packed;
MODS_SHIFT          :: #run Mods.{ shift_pressed = true }.packed;
MODS_ALT_SHIFT      :: #run Mods.{ alt_pressed  = true, shift_pressed = true }.packed;
MODS_CTRL_SHIFT     :: #run Mods.{ ctrl_pressed = true, shift_pressed = true }.packed;
MODS_CTRL_ALT       :: #run Mods.{ ctrl_pressed = true, alt_pressed   = true }.packed;
MODS_CTRL_ALT_SHIFT :: #run Mods.{ ctrl_pressed = true, alt_pressed   = true, shift_pressed = true }.packed;

MIN_WINDOW_WIDTH  :: 50;
MIN_WINDOW_HEIGHT :: 50;

DOUBLE_CLICK_SPEED     :: 0.3;  // how many seconds between clicks to consider it a double click
DOUBLE_CLICK_TOLERANCE :: 2;    // how many pixels between the click locations are allowed
DRAG_AFTER_DOUBLE_CLICK_TIMEOUT :: 0.3;  // when we double-click to select a word, it's very easy to accidentally drag the mouse and unselect the word

// Embed default fonts
FONT         :: #run load_font("FiraCode-Retina.ttf");
FONT_UI      :: #run load_font("SEGOEUI.TTF");
FONT_UI_BOLD :: #run load_font("SEGUISB.TTF");
FONT_ICONS   :: #run load_font("font-awesome/Font Awesome 6 Free-Solid-900.otf");

MIN_FONT_SIZE :: 4;
MAX_FONT_SIZE :: 30;  // setting a larger size has caused freetype to crash - not sure yet why. 
                      // Probably we don't give it enough memory for a glyph bitmap when rendering it?

load_font :: (name: string) -> Embedded_Font {
    path := tprint("fonts/%", name);
    data, success := read_entire_file(path);
    assert(success, "Couldn't load font '%'", path);
    
    return Embedded_Font.{ name = name, data = data};
}

Embedded_Font :: struct {
    name: string;
    data: string;
}
