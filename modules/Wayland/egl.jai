wl_egl_window :: struct {}

using wayland_egl_procs: Wayland_Egl_Procs;

#scope_module

Wayland_Egl_Procs :: struct {
    wl_egl_window_create : (surface: *wl_surface, width: s32, height: s32) -> *wl_egl_window #c_call;
    wl_egl_window_destroy : (window: *wl_egl_window) -> void #c_call;
    wl_egl_window_resize : (window: *wl_egl_window, width: s32, height: s32, dx: s32, dy: s32) -> void #c_call;
    wl_egl_window_get_attached_size : (window: *wl_egl_window, width: *s32, height: *s32) -> void #c_call;
}
