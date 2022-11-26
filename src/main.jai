main :: () {
    #assert OS == .WINDOWS "Currently only supporting Windows";
    platform_setup();

    profiler_begin_session("focus", "focus-trace.json");
    defer profiler_end_session();

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
    old_line_height = line_height;

    // @Cleanup: remove and do properly
    initial_project_dirs := string.[ "W:/focus", "C:/jai" ];
    for path, i : initial_project_dirs {
        dir: Project_Dir = ---;
        dir.path = path;
        dir.path_prefix_len = find_index_of_any_from_right(path, ".\\/") + 1;
        // TODO: check whether project path exists - add to error log
        array_add(*project_dirs, dir);
    }

    init_open_file_dialog();
    init_finder();
    defer deinit_finder();

    // Init file watcher
    if !init(*project_file_watcher, file_change_callback) {
        log_error("Could not initialize project_file_watcher");
        // TODO: add the error to the error log when we have it
        return;
    }
    defer deinit(project_file_watcher);
    for dir : project_dirs add_directories(*project_file_watcher, dir.path);
    dirs_to_rescan.allocator = temp;

    file_change_callback :: (watcher: *File_Watcher(void), change: *File_Change, user_data: *void) {
        if change.events & (File_Change_Event.ADDED | .MOVED | .REMOVED | .SCAN_CHILDREN) {
            should_reinit_file_dialog = true;
        }

        dir: string = ---;
        if change.events & .SCAN_CHILDREN {
            dir = copy_temporary_string(change.full_path);
        } else {
            path := path_strip_filename(change.full_path);
            if path.count > 1 && path[path.count-1] == #char "/" then path.count -= 1;  // don't include trailing path separator
            dir = copy_temporary_string(path);
        }
        add_to_queue := true;
        for dirs_to_rescan {
            if begins_with_nocase(dir, it) {
                add_to_queue = false;  // parent already in the queue
                break;
            }
            if begins_with_nocase(it, dir) remove it;  // we're adding a parent of this dir
        }

        if add_to_queue array_add(*dirs_to_rescan, dir);

        // NOTE: Instead of processing individual events and using the flags we're simply
        // adding folders to the queue for scanning, because the original events seem to be
        // not very reliable. E.g. when a file W:/focus-zig/src/Editors.zig was changed using Sublime Text,
        // here's the list of events we've got:
        // {"W:/focus-zig/src/Editors.zig", MODIFIED, 51.72142}
        // {"W:/focus-zig/src/nPTuLLfc1yEADcLL", ADDED | MODIFIED | MOVED | MOVED_FROM, 52.296619}
        // {"W:/focus-zig/src/Editors.zig", MOVED | MOVED_TO | REMOVED, 52.296619}
        // {"W:/focus-zig/src", MODIFIED | SCAN_CHILDREN, 52.29665}
        // Not very useful, is it?
        // So instead of processing each event the easiest option here would be to add W:/focus-zig/src
        // to the scanning queue

        // if change.events & .MODIFIED      then buffer_maybe_changed_on_disk(change.full_path);
        // if change.events & .REMOVED       then buffer_maybe_deleted_on_disk(change.full_path);
        // if change.events & .SCAN_CHILDREN then refresh_buffers_in_directory(change.full_path);
        // print("%\n", <<change);
    }

    // editors_open_file("W:/focus-zig/src/Editors.zig");
    editors_open_file("src/editors.jai", true);

    should_quit := false;

    while !should_quit {
        if !redraw_requested platform_wait_message();
        redraw_requested = false;
        old_line_height = line_height;

        files_changed := process_changes(*project_file_watcher);
        if files_changed && should_reinit_file_dialog {
            init_open_file_dialog();
            should_reinit_file_dialog = false;
        }
        for dirs_to_rescan maybe_refresh_open_buffers_in_dir(it);
        array_reset(*dirs_to_rescan);

        Input.update_window_events();

        current_time := cast(Time) get_time();
        frame_dt   = min(current_time - frame_time, MAX_FRAME_DT);
        frame_time = current_time;

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

        // Don't do anything when window is resized to a size that's too small
        if window_width < MIN_WINDOW_WIDTH || window_height < MIN_WINDOW_HEIGHT continue;

        update_mouse_state();
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

                            // case #char "+";
                            //     if event.ctrl_pressed {
                            //         font_size += 1;
                            //         font_ui_size += 1;
                            //         font_icons_size += 1;
                            //         init_fonts();
                            //     }
                            // case #char "-";
                            //     if event.ctrl_pressed {
                            //         font_size -= 1;
                            //         font_ui_size -= 1;
                            //         font_icons_size -= 1;
                            //         init_fonts();
                            //     }
                        }
                    }
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

        reset_temporary_storage();
    }

    // report := make_leak_report();
    // log_leak_report(report);
}

init_fonts :: () {
    font = Simp.get_font_at_size("fonts", "FiraCode-Retina.ttf", cast(int) (font_size * dpi_scale));
    assert(font != null, "Couldn't init main text font\n");
    char_size   = cast(float) font.em_width;
    old_line_height = line_height;
    line_height = cast(float) font.default_line_spacing * LINE_HEIGHT_SCALE;

    font_ui = Simp.get_font_at_size("fonts", "SEGOEUI.TTF", cast(int) (font_ui_size * dpi_scale));
    assert(font_ui != null, "Couldn't init main ui font\n");
    font_ui_line_height = cast(float) font_ui.default_line_spacing;

    font_ui_bold = Simp.get_font_at_size("fonts", "SEGUISB.TTF", cast(int) (font_ui_size * dpi_scale));
    assert(font_ui_bold != null, "Couldn't init bold ui font\n");

    font_ui_small = Simp.get_font_at_size("fonts", "SEGOEUI.TTF", cast(int) (font_ui_small_size * dpi_scale));
    // font_ui_small = Simp.get_font_at_size("fonts", "SEGUISB.TTF", cast(int) (font_ui_small_size * dpi_scale));
    assert(font_ui_small != null, "Couldn't init main ui font\n");
    font_ui_small_line_height = cast(float) font_ui.default_line_spacing;

    font_icons = Simp.get_font_at_size("fonts/font-awesome", "Font Awesome 6 Free-Solid-900.otf", cast(int) (font_icons_size * dpi_scale));
    assert(font_icons != null, "Couldn't init main icon font\n");

    // WORKAROUND:
    // Make a dummy call with most common chars for each font so that
    // we have all the font atlases loaded in the GPU memory once
    // (TODO: maybe there's an easy way for Simp to only update textures on flush?)
    COMMON_CHARS :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789… ~!@#$%^&*()-|\"':;_+={}[]\\/`,.<>?АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчщъыьэюя";
    Simp.prepare_text(font,          COMMON_CHARS);
    Simp.prepare_text(font_ui,       COMMON_CHARS);
    Simp.prepare_text(font_ui_bold,  COMMON_CHARS);
    Simp.prepare_text(font_ui_small, COMMON_CHARS);
    // TODO: prepare icons as well
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
            distance_from_last_click := mouse.pointer - button.last_down_pos;
            max_distance := max(abs(distance_from_last_click.x), abs(distance_from_last_click.y));
            button.just_double_clicked = time_from_last_click < DOUBLE_CLICK_SPEED && max_distance < DOUBLE_CLICK_TOLERANCE;
            button.last_down_pos  = mouse.pointer;
            button.last_down_time = frame_time;
        } else {
            button.just_double_clicked = false;
        }

        button.is_dragging   = button.is_down && mouse.pointer != button.last_down_pos;
    }
}

panic :: (format_string: string, args: .. Any, exit_code : s32 = 1) {
    log_error(format_string, ..args);
    exit(exit_code);
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

window: Window_Type;
window_width  := 1920;
window_height := 1080;
window_x  := -1;
window_y  := -1;
dpi_scale := 1.0;

redraw_requested := true;  // set to true to render the first frame

open_file_dialog: Open_File_Dialog;

frame_time: Time;                 // ever-increasing time since start in seconds
frame_dt:   Time = MAX_FRAME_DT;  // time delta since the last frame
MAX_FRAME_DT: Time : xx (1.0 / 60);

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

    last_down_pos:  Vector2;
    last_down_time: Time;
}

// Depend on font
char_size:   float;
line_height: float;
old_line_height: float;  // to track font changes

LINE_HEIGHT_SCALE :: 1.2;

WHEEL_SENSITIVITY :: 1.0;

font      :  *Simp.Dynamic_Font;
font_size := 14;

font_ui      :  *Simp.Dynamic_Font;
font_ui_bold :  *Simp.Dynamic_Font;
font_ui_size := 16;
font_ui_line_height: float;

font_ui_small      :  *Simp.Dynamic_Font;
font_ui_small_size := 15;
font_ui_small_line_height: float;

font_icons      : *Simp.Dynamic_Font;
font_icons_size := 16;

Mods :: Input.Event.Modifier_Flags;

Time :: #type,isa float64;

project_file_watcher: File_Watcher(void);
project_dirs: [..] Project_Dir;  // TODO: load them from a config file or something
dirs_to_rescan: [..] string;  // will use temporary storage
should_reinit_file_dialog: bool;

active_global_widget: enum {
    editors;
    open_file_dialog;
    finder;
} = .editors;

Project_Dir :: struct {
    path: string;          // e.g. "C:/projects/focus"
    path_prefix_len: s64;  // in this case the length of "C:/projects/"
}

#load "style.jai";
#load "layout.jai";
#load "editors.jai";
#load "buffer.jai";
#load "windows.jai";
#load "unicode.jai";
#load "draw.jai";
#load "pointer_image.jai";
#load "utils.jai";
#load "files.jai";
#load "widgets/text_input.jai";
#load "widgets/open_file_dialog.jai";
#load "widgets/finder.jai";
#load "langs/jai.jai";
#load "langs/worklog.jai";

// #import "Basic"()(MEMORY_DEBUGGER = true);
#import "Basic";
#import "Math";
#import "Sloppy_Math";
#import "File";
#import "File_Utilities";
#import "File_Watcher";
#import "Flat_Pool";
#import "System";  // For get_path_of_running_executable.
#import "String";
#import "Sort";
#import "Unicode";
#import "Window_Creation";
#import "Profiler"(ENABLE_PROFILER = false);
#import "Thread";

Simp :: #import "Simp_Ext";
Input :: #import "Input";


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
