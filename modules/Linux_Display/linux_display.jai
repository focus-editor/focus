Saved_Window_Info :: struct {}

Init_Flags :: enum_flags {
    XCB_Pure;
    XCB_Force_Core_Events;
}

Display :: union {
    #as base: Base_Display;
    #as x11: X11_Display;
    #as xcb: XCB_Display;
    #as wld: Wayland_Display;
}

Window :: union {
    #as base: Base_Window;
    #as x11: X11_Window;
    #as xcb: XCB_Window;
    #as wld: Wayland_Window;
}

INVALID_WINDOW : *Window : null;

BACKEND_CHOICE :: enum {
    PREFER_BEST_USER_EXPERIENCE;
    PREFER_WAYLAND;
    PREFER_X11;
    FORCE_WAYLAND;
    FORCE_X11;
    FORCE_XCB;
}

ACTIVE_BACKEND :: enum {
    UNINITIALIZED;
    WAYLAND;
    X11;
    XCB;
}


init_display :: (display: *Display, desired_backend := BACKEND_CHOICE.PREFER_BEST_USER_EXPERIENCE, desired_gl_backend := GL_BACKEND_CHOICE.AUTOSELECT, flags: Init_Flags = 0, app_id := "com.jai.application") -> bool {
    timers_init();

    if display.base.type != Base_Display return true;

    display.* = .{};

    bd: *Base_Display = display;
    if bd.app_id free(bd.app_id);
    bd.app_id = copy_string(app_id);
    bd.init_flags = flags;
    bd.desired_gl_backend = desired_gl_backend;
    bd.loop_wakeup_event = eventfd(0, EFD_CLOEXEC);

    X11_init :: inline (display: *Display) -> bool {
        base := display.base;
        if !xcb_init_display(display) {
            display.* = .{};
            display.base = base;
            return x11_init_display(display);
        }
        return true;
    }

    WL_init :: inline (display: *Display) -> bool {
        base := display.base;
        if !wl_init_display(display) {
            display.* = .{};
            display.base = base;
            return false;
        }
        return true;
    }

    if #complete desired_backend == {
        case .PREFER_BEST_USER_EXPERIENCE; {
            /*
             * This is the same as PREFER_WAYLAND plus some checks to ensure
             * the best user experience possible. We do this by initializing
             * a Wayland display and checking that certain protocols are
             * supported. We fall back to X11 if we don't like the way the
             * Wayland display looks.
             */
            base := display.base;

            if wl_init_display(display) {
                wld := *display.wld;
                if !wld.decoration_manager {
                    wl_uninit_display(display);
                    display.* = .{};
                    display.base = base;
                    return X11_init(display);
                }
                return true;
            }

            display.* = .{};
            display.base = base;
            return X11_init(display);
        }
        case .PREFER_WAYLAND; {
            if WL_init(display) return true;
            return X11_init(display);
        }
        case .PREFER_X11; {
            if X11_init(display) return true;
            return WL_init(display);
        }
        case .FORCE_WAYLAND; return wl_init_display(display);
        case .FORCE_X11; return x11_init_display(display);
        case .FORCE_XCB; return xcb_init_display(display);
    }

    return false;
}

active_backend :: (display: *Display) -> ACTIVE_BACKEND {
    bd: *Base_Display = display;
    if bd.type == {
        case Wayland_Display; return .WAYLAND;
        case X11_Display; return .X11;
        case XCB_Display; return .XCB;
        case; return .UNINITIALIZED;
    }
}

active_gl_backend :: (display: *Display) -> GL_BACKEND {
    bd: *Base_Display = display;
    return bd.gl.type;
}

/*
 * Window functions
 */
create_window :: inline (display: *Display, width: int, height: int, window_name: string, window_x := 0, window_y := 0,
    parent: *Window = INVALID_WINDOW, background_color_rgb: [3]float) -> *Window
{
    bd: *Base_Display = display;
    ret := array_add(*bd.windows);
    ret.* = .{};
    if !bd.create_window(display, ret, width, height, window_name, window_x, window_y, parent, background_color_rgb) {
        pop(*bd.windows);
        return INVALID_WINDOW;
    }
    return ret;
}

// Assumes the buffer is in ARGB format
set_icon_from_raw_data :: inline (window: *Window, data: *void, w: s32, h: s32) {
    bw: *Base_Window = window;
    bw.set_icon_from_raw_data(window, data, xx w, xx h);
}

toggle_fullscreen :: inline (window: *Window, desire_fullscreen: bool, saved: *Saved_Window_Info) -> success: bool, width: s32, height: s32 {
    bw: *Base_Window = window;
    s, w, h := bw.toggle_fullscreen(window, desire_fullscreen, saved);
    return s, w, h;
}

get_by_native_handle :: inline (display: *Display, native_handle: *void) -> *Window {
    bd: *Base_Display = display;
    for * bd.windows {
        bw: *Base_Window = it;
        if bw.has_native_handle(it, native_handle) return it;
    }
    return INVALID_WINDOW;
}

has_native_handle :: inline (window: *Window, native_handle: *void) -> bool {
    bw: *Base_Window = window;
    return bw.has_native_handle(window, native_handle);
}

get_dimensions :: inline (window: *Window, right_handed: bool) -> (x: s32, y: s32, width: s32, height: s32, success := true) {
    bw: *Base_Window = window;
    x, y, w, h, ok := bw.get_dimensions(window, right_handed);
    return x, y, w, h, ok;
}

get_render_dimensions :: inline (window: *Window) -> (width: s32, height: s32) {
    bw: *Base_Window = window;
    w, h := bw.get_render_dimensions(window);
    return w, h;
}

get_mouse_pointer_position :: inline (window: *Window, right_handed: bool) -> x: int, y: int, success: bool {
    bw: *Base_Window = window;
    x, y, ok := bw.get_mouse_pointer_position(window, right_handed);
    return x, y, ok;
}

get_mouse_pointer_position :: inline (display: *Display, right_handed := false) -> x: int, y: int, success: bool {
    bd: *Base_Display = display;
    x, y, ok := bd.get_mouse_pointer_position(display, right_handed);
    return x, y, ok;
}

enable_dnd :: inline (window: *Window, typelist: []string) {
    bw: *Base_Window = window;
    bw.enable_dnd(window, typelist);
}

set_window_title :: inline (window: *Window, title: string) {
    bw: *Base_Window = window;
    bw.set_window_title(window, title);
}

maximize_window :: inline (window: *Window) {
    bw: *Base_Window = window;
    bw.maximize_window(window);
}

set_cursor_from_theme :: inline (window: *Window, name: string) {
    bw: *Base_Window = window;
    bw.set_cursor_from_theme(window, name);
}

get_dpi_scaling_factor :: (window: *Window) -> float {
    bw: *Base_Window = window;
    return bw.get_dpi_scaling_factor(window);
}

set_fixed_scaling :: (display: *Display, factor: float) {
    bd: *Base_Display = display;
    bd.set_fixed_scaling(display, factor);
}

/*
 * Input functions
 */
translate_key_code :: inline (display: *Display, key: u64) -> Input.Key_Code {
    bd: *Base_Display = display;
    return bd.translate_key_code(key);
}

wait_for_events :: inline (display: *Display) {
    bd: *Base_Display = display;
    bd.wait_for_events(display);
}

update_window_events :: (display: *Display) {
    bd: *Base_Display = display;
    bd.update_window_events(display);

    /*
     * On Wayland, the event loop can push events into `events_this_frame` during the
     * "wait for events" phase (`wl_display_dispatch_pending()` invokes event callbacks).
     * Because of this we need to "double buffer" here so that the `Input` module doesn't
     * discard said events during the "update" phase.
     */
    if bd.events_this_frame.count > 0 {
        array_resize(*Input.events_this_frame, bd.events_this_frame.count);
        memcpy(Input.events_this_frame.data, bd.events_this_frame.data, bd.events_this_frame.count * size_of(Input.Event));
        array_reset_keeping_memory(*bd.events_this_frame);

        memcpy(Input.input_button_states.data, bd.input_button_states.data, bd.input_button_states.count * size_of(Input.Key_Current_State));

        Input.mouse_delta_x     = bd.mouse_delta_x;
        Input.mouse_delta_y     = bd.mouse_delta_y;
        Input.mouse_wheel_delta = bd.mouse_wheel_delta;

        bd.mouse_delta_x     = 0;
        bd.mouse_delta_y     = 0;
        bd.mouse_wheel_delta = .{};

        // A little copypaste from `input_per_frame_event_and_flag_update`
        // Basically, we also need to reset "just clicked" and "just released"
        // flags so they don't get carried over multiple frames, messing up with
        // selection while scrolling and some other things
        mask     := ~Input.Key_Current_State.START;
        end_mask := ~(Input.Key_Current_State.END | .DOWN | .START);

        for * bd.input_button_states {
            if (it.* & .END || !Input.input_application_has_focus) {
                it.* &= end_mask;
            } else {
                it.* &= mask;
            }
        }
    }
}

wake_up_event_loop :: (display: *Display) {
    val : u64 = 1;
    write(display.base.loop_wakeup_event, *val, size_of(type_of(val)));
}

clipboard_get_text :: inline (display: *Display) -> string {
    bd: *Base_Display = display;
    return bd.clipboard_get_text(display);
}

clipboard_set_text :: inline (display: *Display, text: string) {
    bd: *Base_Display = display;
    bd.clipboard_set_text(display, text);
}

// Fonts
find_font :: (name: string, allocator := temp) -> bool, string {
    ok, path := fc_find_font(name, allocator);
    return ok, path;
}

#load "timers.jai";
#if JAI_STDLIB_INTEROP {
    #load "stdlib_interop.jai";
}

// Misc
dump_debug_info :: (display: *Display, sb: *String_Builder) {
    sfmt := context.print_style.default_format_struct;
    defer context.print_style.default_format_struct = sfmt;

    context.print_style.default_format_struct.use_long_form_if_more_than_this_many_members = -1;
    context.print_style.default_format_struct.use_newlines_if_long_form = true;
    if display.base.type == {
        case Wayland_Display; print_to_builder(sb, "%.%\n", display.base.type, display.wld);
        case X11_Display;     print_to_builder(sb, "%.%\n", display.base.type, display.x11);
        case XCB_Display;     print_to_builder(sb, "%.%\n", display.base.type, display.xcb);
        case;                 print_to_builder(sb, "%.%\n", display.base.type, display.base);
    }
}

#scope_module;

#import "String";
#import "Hash_Table";

#import "libxkbcommon";
GL :: #import "Linux_Display/GL";   // apparently different from `#import,file "GL.jai"`
#import,file "X11.jai";
#import "Wayland";
Input :: #import "Input";
#import "Basic";

#load "missing.jai";
#load "fontconfig.jai";
#load "ld_xcb.jai";
#load "ldx_display.jai";
#load "ldx_input.jai";
#load "ldw_display.jai";
#load "ldw_input.jai";
#load "ld_gl.jai";

X11: X11_Lib;
EGL: GL.EGL_Lib;
GLX: GL.GLX_Lib;

Base_Display :: struct {
    type: Type = Base_Display;
    app_id: string;

    init_flags: Init_Flags;

    desired_gl_backend := GL_BACKEND_CHOICE.AUTOSELECT;

    windows: [..] Window;

    mouse_delta_x: int;
    mouse_delta_y: int;
    mouse_wheel_delta: Input.Wheel_Delta;

    events_this_frame: [..]Input.Event;
    input_button_states: [Input.NUM_BUTTON_STATES] Input.Key_Current_State;

    loop_wakeup_event : s32;

    gl: GL_Display;

    create_window: (
        display: *Display,
        window_ret: *Window,
        width: int, height: int,
        window_name: string,
        window_x := 0, window_y := 0,
        parent: *Window = null,
        background_color_rgb: [3]float) -> bool;

    set_fixed_scaling: (display: *Display, factor: float);

    translate_key_code: (key: u64) -> Input.Key_Code;

    wait_for_events: (display: *Display);
    update_window_events: (display: *Display);

    clipboard_get_text: (display: *Display) -> string;
    clipboard_set_text: (display: *Display, text: string);

    get_mouse_pointer_position: (display: *Display, right_handed: bool) -> x: int, y: int, success: bool;
}

Base_Window :: struct {
    type: Type = Base_Window;
    display: *Display;

    gl: GL_Window;

    set_icon_from_raw_data: (window: *Window, data: *u8, w: u32, h: u32);
    toggle_fullscreen: (window: *Window, desire_fullscreen: bool, saved: *Saved_Window_Info) -> success: bool, width: s32, height: s32;
    has_native_handle: (window: *Window, native_handle: *void) -> bool;
    get_dimensions: (window: *Window, right_handed: bool) -> x: s32, y: s32, w: s32, h: s32, ok: bool;
    get_render_dimensions: (window: *Window) -> w: s32, h: s32;
    get_mouse_pointer_position: (window: *Window, right_handed: bool) -> x: int, y: int, success: bool;
    enable_dnd: (window: *Window, typelist: []string);
    set_window_title: (window: *Window, title: string);
    maximize_window: (window: *Window);
    set_cursor_from_theme: (window: *Window, name: string);
    get_dpi_scaling_factor: (window: *Window) -> float;
}

#if VALIDATE_USAGE {
    check_usage :: ($type: Type = Base_Display, display: *Display, windows: ..*Window, loc := #caller_location) #expand #no_debug {
        #assert(type == Wayland_Display || type == X11_Display || type == XCB_Display);

        bd: *Base_Display = display;

        window_type: Type = Base_Window;
        if type == {
            case Wayland_Display; window_type = Wayland_Window;
            case X11_Display;     window_type = X11_Window;
            case XCB_Display;     window_type = XCB_Window;
        }

        if bd then assert(bd.type == type, "Expected display type %, got % (%)", type, bd.type, bd, loc=loc);

        for w : windows {
            if !w continue;
            bw: *Base_Window = w;
            assert(bw.type == window_type, "% window (%) on % display (%)", bw.type, bw, type, bd, loc=loc);

            if !bd continue;

            assert(bw.display == display, "%(%).display=%, expected %", bw.type, bw, bw.display, display);
            assert(bd.windows.count > 0, "%(%).windows.count=%", bd.type, bd, bd.windows.count);

            first := bd.windows.data;
            last := first + bd.windows.count - 1;
            assert(w >= first && w <= last, "%(%) outside of range %..% for %(%)", bw.type, bw, first, last, bd.type, bd);
        }
    }
} else {
    check_usage :: ($type: Type = Base_Display, display: *Display, windows: ..*Window, loc := #caller_location) #expand #no_debug {
        /* NOOP */
    }
}

wl_check_usage :: #bake_arguments check_usage(type=Wayland_Display);
x11_check_usage :: #bake_arguments check_usage(type=X11_Display);
xcb_check_usage :: #bake_arguments check_usage(type=XCB_Display);

WHEEL_DELTA : s32 : 120;

consume_loop_wakeup_event :: (bd: *Base_Display) {
    val: u64;
    read(bd.loop_wakeup_event, *val, size_of(type_of(val)));
}
