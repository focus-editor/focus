global_display :: *_global_display;

init_with_stdlib_interop :: inline (desired_backend := BACKEND_CHOICE.PREFER_BEST_USER_EXPERIENCE, desired_gl_backend := GL_BACKEND_CHOICE.AUTOSELECT, flags: Init_Flags = 0, app_id := "com.jai.application") -> bool {
    return init_display(
        display = global_display,
        desired_backend = desired_backend,
        desired_gl_backend = desired_gl_backend,
        flags = flags,
        app_id = app_id);
}

active_backend :: inline () -> ACTIVE_BACKEND {
    return active_backend(global_display);
}

active_gl_backend :: inline () -> GL_BACKEND {
    return active_gl_backend(global_display);
}

create_window :: inline (width: int, height: int, window_name: string, window_x := 0, window_y := 0,
    parent: *Window = INVALID_WINDOW, background_color_rgb: [3]float) -> *Window
{
    return create_window(
        global_display,
        width, height,
        window_name,
        window_x, window_y,
        parent,
        background_color_rgb);
}

get_by_native_handle :: inline (native_handle: *void) -> *Window {
    return get_by_native_handle(global_display, native_handle);
}

get_mouse_pointer_position :: inline (right_handed := false) -> x: int, y: int, success: bool {
    x, y, ok := get_mouse_pointer_position(global_display, right_handed);
    return x, y, ok;
}

set_fixed_scaling :: inline (factor: float) {
    set_fixed_scaling(global_display, factor);
}

translate_key_code :: inline (key: u64) -> Input.Key_Code {
    return translate_key_code(global_display, key);
}

wait_for_events :: inline () {
    wait_for_events(global_display);
}

update_window_events :: inline () {
    update_window_events(global_display);
}

wake_up_event_loop :: () {
    wake_up_event_loop(global_display);
}

clipboard_get_text :: inline () -> string {
    return clipboard_get_text(global_display);
}

clipboard_set_text :: inline (text: string) {
    clipboard_set_text(global_display, text);
}

get_gl_context :: inline () -> *void {
    return get_gl_context(global_display);
}

get_gl_proc_address_function :: inline () -> GL.GetProcAddressFunction {
    return get_gl_proc_address_function(global_display);
}

create_gl_context :: inline (major_version := 0, minor_version := 0, compatibility := false, debug := false) {
    create_gl_context(global_display, major_version, minor_version, compatibility, debug);
}

gl_initialized :: inline () -> bool {
    return gl_initialized(global_display);
}

dump_debug_info :: (sb: *String_Builder) {
    dump_debug_info(global_display, sb);
}

#scope_file
_global_display: Display;
