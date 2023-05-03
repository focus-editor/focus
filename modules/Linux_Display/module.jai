Saved_Window_Info :: struct {}

LDDisplay :: *_Display;
global_display : LDDisplay : *_global_display;

LDWindow  :: *_Window;
INVALID_WINDOW : LDWindow : null;

init_display :: () -> bool {
    prefer_x11 := (getenv("LD_PREFER_X11") != null);
    if global_display.tag != X11Display && global_display.tag != WLDisplay {
        if prefer_x11 {
            if x11_init_display(global_display) return true;
            if wl_init_display(global_display) return true;
        } else {
            if wl_init_display(global_display) return true;
            if x11_init_display(global_display) return true;
        }
    }
    return true;
}

/*
 * LDWindow functions
 */
create_window :: (width: int, height: int, window_name: string, window_x := 0, window_y := 0,
    parent: LDWindow = INVALID_WINDOW, background_color_rgb: [3]float) -> LDWindow
{
    if (!init_display()) return INVALID_WINDOW;
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
        case X11Window;
        case WLWindow; wl_set_cursor_from_theme(isa(win, WLWindow), name);
    }
}

get_dpi_scaling_factor :: (win: LDWindow) -> float {
    if win.tag == {
        case X11Window; return x11_get_dpi_scaling_factor(isa(win, X11Window));
        case WLWindow; // DPI-based scaling is not a thing on Wayland, we (will) handle scaling via the 'fractional_scale' protocol
    }
    return 1.0;
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

#load "ldx_missing.jai";
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

WHEEL_DELTA : s32 : 120;
