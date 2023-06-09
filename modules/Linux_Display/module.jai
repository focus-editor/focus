Saved_Window_Info :: struct {}

LDDisplay :: *_Display;
global_display : LDDisplay : *_global_display;

LDWindow  :: *_Window;
INVALID_WINDOW : LDWindow : null;

Timer :: *_Timer;
Timer_Cb :: #type (timer: Timer);

BACKEND_CHOICE :: enum {
    PREFER_BEST_USER_EXPERIENCE;
    PREFER_WAYLAND;
    PREFER_X11;
    FORCE_WAYLAND;
    FORCE_X11;
}

ACTIVE_BACKEND :: enum {
    UNINITIALIZED;
    WAYLAND;
    X11;
}

init :: (backend: BACKEND_CHOICE, app_id := "com.jai.application") -> bool {
    if global_display.tag == X11Display || global_display.tag == WLDisplay return true;
    if global_app_id free(global_app_id);
    global_app_id = copy_string(app_id);
    if #complete backend == {
        case .PREFER_BEST_USER_EXPERIENCE; {
            /*
             * This is the same as PREFER_WAYLAND plus some checks to ensure
             * the best user experience possible. We do this by initializing
             * a Wayland display and checking that certain protocols are
             * supported. We fall back to X11 if we don't like the way the
             * Wayland display looks.
             */
            if wl_init_display(global_display) {
                wld := isa(global_display, WLDisplay);
                if !wld.decoration_manager {
                    wl_uninit_display(global_display);
                    <<global_display = .{};
                    return x11_init_display(global_display);
                }
                return true;
            }

            return x11_init_display(global_display);
        }
        case .PREFER_WAYLAND; {
            if wl_init_display(global_display) return true;
            return x11_init_display(global_display);
        }
        case .PREFER_X11; {
            if x11_init_display(global_display) return true;
            return wl_init_display(global_display);
        }
        case .FORCE_WAYLAND; return wl_init_display(global_display);
        case .FORCE_X11; return x11_init_display(global_display);
    }
    return false;
}

active_backend :: () -> ACTIVE_BACKEND {
    if global_display.tag == {
        case WLDisplay; return .WAYLAND;
        case X11Display; return .X11;
        case; return .UNINITIALIZED;
    }
}

/*
 * LDWindow functions
 */
create_window :: (width: int, height: int, window_name: string, window_x := 0, window_y := 0,
    parent: LDWindow = INVALID_WINDOW, background_color_rgb: [3]float) -> LDWindow
{
    if global_display.tag == {
        case X11Display; {
            if parent != INVALID_WINDOW assert(parent.tag == X11Window);
            ret := array_add(*global_windows);
            <<ret = .{};
            if !x11_create_window(isa(global_display, X11Display), ret, width, height, window_name,
                window_x, window_y, ifx parent then isa(parent, X11Window) else null, background_color_rgb)
            {
                pop(*global_windows);
                return INVALID_WINDOW;
            }
            return ret;
        }
        case WLDisplay; {
            if parent != INVALID_WINDOW assert(parent.tag == WLWindow);
            ret := array_add(*global_windows);
            <<ret = .{};
            if !wl_create_window(isa(global_display, WLDisplay), ret, width, height, window_name,
                window_x, window_y, ifx parent then isa(parent, WLWindow) else null, background_color_rgb)
            {
                pop(*global_windows);
                return INVALID_WINDOW;
            }
            return ret;
        }
        case; return INVALID_WINDOW;
    }
}

// Assumes the buffer is in ARGB format
set_icon_from_raw_data :: (win: LDWindow, data: *void, w: s32, h: s32) {
    if win.tag == {
        case X11Window; x11_set_icon_from_raw_data(isa(win, X11Window), data, xx w, xx h);
    }
}

toggle_fullscreen :: (win: LDWindow, desire_fullscreen: bool, saved: *Saved_Window_Info)
    -> success: bool, width: s32, height: s32
{
    w, h: s32;
    s := false;
    if global_display.tag == {
        case X11Display; s, w, h = x11_toggle_fullscreen(isa(win, X11Window), desire_fullscreen, saved);
        case WLDisplay; s, w, h = wl_toggle_fullscreen(isa(win, WLWindow), desire_fullscreen, saved);
    }
    return s, w, h;
}

get_by_native_handle :: (native_handle: *void) -> LDWindow {
    for * global_windows {
        if has_native_handle(it, native_handle) return it;
    }
    return INVALID_WINDOW;
}

has_native_handle :: (win: LDWindow, native_handle: *void) -> bool {
    if !win return false;
    if win.tag == {
        case X11Window; return x11_has_native_handle(isa(win, X11Window), xx native_handle);
        case WLWindow; return wl_has_native_handle(isa(win, WLWindow), xx native_handle);
        case; return false;
    }
}

get_dimensions :: (win: LDWindow, right_handed: bool) -> (x: s32, y: s32, width: s32, height: s32, success := true) {
    x, y, w, h: s32;
    ok := false;
    if win.tag == {
        case X11Window; x, y, w, h, ok = x11_get_dimensions(isa(win, X11Window), right_handed);
        case WLWindow; x, y, w, h, ok = wl_get_dimensions(isa(win, WLWindow), right_handed);
    }
    return x, y, w, h, ok;
}

get_render_dimensions :: (win: LDWindow) -> (width: s32, height: s32) {
    if win.tag == {
        case X11Window; {
            x, y, w, h, ok := x11_get_dimensions(isa(win, X11Window), false);
            return w, h;
        }
        case WLWindow; {
            w, h := wl_get_render_dimensions(isa(win, WLWindow));
            return w, h;
        }
    }
    return 1, 1;
}

get_mouse_pointer_position :: (display: LDDisplay, win: LDWindow, right_handed: bool) -> x: int, y: int, success: bool {
    x, y: int;
    ok := false;
    if display.tag == {
        case X11Display; {
            assert(win.tag == X11Window);
            x, y, ok = x11_get_mouse_pointer_position(isa(display, X11Display), isa(win, X11Window), right_handed);
        }
        case WLDisplay; {
            assert(win.tag == WLWindow);
            x, y, ok = wl_get_mouse_pointer_position(isa(win, WLWindow), right_handed);
        }
    }
    return x, y, ok;
}

get_mouse_pointer_position :: (win: LDWindow, right_handed: bool) -> x: int, y: int, success: bool {
    x, y: int;
    ok := false;
    if global_display.tag == {
        case X11Display; {
            assert(win.tag == X11Window);
            x, y, ok = x11_get_mouse_pointer_position(isa(win, X11Window), right_handed);
        }
        case WLDisplay; {
            assert(win.tag == WLWindow);
            x, y, ok = wl_get_mouse_pointer_position(isa(win, WLWindow), right_handed);
        }
    }
    return x, y, ok;
}

get_mouse_pointer_position :: (right_handed := false) -> x: int, y: int, success: bool {
    x, y: int;
    ok := false;
    if global_display.tag == {
        case WLDisplay; x, y, ok = wl_get_mouse_pointer_position(right_handed);
        case X11Display; x, y, ok = x11_get_mouse_pointer_position(right_handed);
    }
    return x, y, ok;
}

enable_dnd :: (win: LDWindow, typelist: []string) {
    if win.tag == {
        case X11Window; x11_enable_dnd(isa(win, X11Window), typelist);
        case WLWindow; wl_enable_dnd(isa(win, WLWindow), typelist);
    }
}

set_window_title :: (win: LDWindow, title: string) {
    if win.tag == {
        case X11Window; x11_set_window_title(isa(win, X11Window), title);
        case WLWindow; wl_set_window_title(isa(win, WLWindow), title);
    }
}

maximize_window :: (win: LDWindow) {
    if win.tag == {
        case X11Window; x11_maximize_window(isa(win, X11Window));
        case WLWindow; wl_maximize_window(isa(win, WLWindow));
    }
}

set_cursor_from_theme :: (win: LDWindow, name: string) {
    if win.tag == {
        case X11Window; x11_set_cursor_from_theme(isa(win, X11Window), name);
        case WLWindow; wl_set_cursor_from_theme(isa(win, WLWindow), name);
    }
}

get_dpi_scaling_factor :: (win: LDWindow) -> float {
    if win.tag == {
        case X11Window; return x11_get_dpi_scaling_factor(isa(win, X11Window));
        case WLWindow; return wl_get_dpi_scaling_factor(isa(win, WLWindow));
    }
    return 1.0;
}

set_fixed_scaling :: (display: LDDisplay, factor: float) {
    if display.tag == {
        case X11Display; x11_set_fixed_scaling(isa(display, X11Display), factor);
        case WLDisplay; wl_set_fixed_scaling(isa(display, WLDisplay), factor);
    }
}

set_fixed_scaling :: (factor: float) {
    set_fixed_scaling(global_display, factor);
}

/*
 * Input functions
 */
translate_key_code :: (display: LDDisplay, key: u64) -> Key_Code {
    if display.tag == {
        case X11Display; return x11_translate_key_code(key);
        case WLDisplay;
    }
    return .UNKNOWN;
}

translate_key_code :: (key: u64) -> Key_Code {
    return translate_key_code(global_display, key);
}

update_window_events :: () {
    if global_display.tag == {
        case X11Display; x11_update_window_events(isa(global_display, X11Display));
        case WLDisplay; wl_update_window_events(isa(global_display, WLDisplay));
    }
}

clipboard_get_text :: () -> string {
    if global_display.tag == {
        case X11Display; return x11_clipboard_get_text();
        case WLDisplay; return wl_clipboard_get_text(isa(global_display, WLDisplay));
        case; return copy_string("");
    }
}

clipboard_set_text :: (text: string) {
    if global_display.tag == {
        case X11Display; x11_clipboard_set_text(text);
        case WLDisplay; wl_clipboard_set_text(isa(global_display, WLDisplay), text);
        case;
    }
}

// Fonts
find_font :: (name: string, allocator := temp) -> bool, string {
    ok, path := fc_find_font(name, allocator);
    return ok, path;
}

// Timers
timer_create :: (cb: Timer_Cb, user_data: *void = null, initial_tick: u32 = 0, repeat: u32 = 0) -> Timer {
    pthread_mutex_lock(*timers_mutex);
    defer pthread_mutex_unlock(*timers_mutex);

    ret: Timer;
    ret_id: s32;
    for * t : global_timers {
        if t.id == null {
            ret = t;
            ret_id = xx it_index;
            break;
        }
    }

    if !ret {
        ret = array_add(*global_timers);
        ret_id = xx (global_timers.count - 1);
    }

    sev: sigevent;
    sev.sigev_notify = SIGEV_THREAD;
    sev.sigev_value.sival_int = ret_id;
    sev.sigev_notify_function = timer_callback;

    timer_create(.CLOCK_MONOTONIC, *sev, *ret.id);
    if !ret.id {
        timer_destroy(ret);
        return null;
    }

    ret.cb = cb;
    ret.user_data = user_data;

    if initial_tick || repeat timer_start(ret, initial_tick, repeat);

    return ret;
}

timer_start :: (timer: Timer, initial_tick: u32, repeat: u32 = 0) {
    assert(initial_tick != 0 || repeat != 0);

    spec: itimerspec;
    spec.it_value.tv_nsec = initial_tick * 1_000_000;
    spec.it_value.tv_sec  = spec.it_value.tv_nsec / 1_000_000_000;
    spec.it_value.tv_nsec = spec.it_value.tv_nsec % 1_000_000_000;
    if repeat {
        spec.it_interval.tv_nsec = repeat * 1_000_000;
        spec.it_interval.tv_sec  = spec.it_interval.tv_nsec / 1_000_000_000;
        spec.it_interval.tv_nsec = spec.it_interval.tv_nsec % 1_000_000_000;
    }
    timer_settime(timer.id, 0, *spec, null);
}

timer_stop :: (timer: Timer) {
    spec: itimerspec;
    timer_settime(timer.id, 0, *spec, null);
}

timer_destroy :: (timer: Timer) {
    pthread_mutex_lock(*timers_mutex);
    defer pthread_mutex_unlock(*timers_mutex);

    assert(timer >= global_timers.data && timer < global_timers.data + global_timers.count);
    if timer.id timer_delete(timer.id);
    <<timer = .{};
}

#scope_module;

#import "String";
#import "Hash_Table";

#import "X11";
#import "EGL";
#import "GL";
#import "Wayland";
#import "Input";
#import "Tagged_Union";
#import "Basic";

#load "missing.jai";
#load "fontconfig.jai";
#load "ldx_display.jai";
#load "ldx_input.jai";
#load "ldw_display.jai";
#load "ldw_input.jai";
#load "ld_gl.jai";

_Display        :: Tagged_Union(X11Display, WLDisplay);
_Window         :: Tagged_Union(X11Window, WLWindow);
_INVALID_WINDOW : LDWindow;

_global_display: _Display;
global_windows: [..] _Window;

timers_mutex: pthread_mutex_t;
_Timer :: struct {
    id: timer_t;
    user_data: *void;
    cb: Timer_Cb;
}
global_timers : [..] _Timer;

timer_callback :: (val: sigval_t) #c_call {
    timer : Timer = *global_timers[val.sival_int];
    if timer.cb {
        ctx: Context;
        push_context ctx {
            timer.cb(timer);
        }
    }
}

WHEEL_DELTA : s32 : 120;

global_app_id: string;
