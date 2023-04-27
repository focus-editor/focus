wl_egl_window :: struct {
    create :: wl_egl_window_create;
    destroy :: wl_egl_window_destroy;
    resize :: wl_egl_window_resize;
    get_attached_size :: wl_egl_window_get_attached_size;
}

#scope_module

wl_egl_window_create :: (surface: *wl_surface, width: s32, height: s32) -> *wl_egl_window #foreign libwayland_egl;
wl_egl_window_destroy :: (window: *wl_egl_window) -> void #foreign libwayland_egl;
wl_egl_window_resize :: (window: *wl_egl_window, width: s32, height: s32, dx: s32, dy: s32) -> void #foreign libwayland_egl;
wl_egl_window_get_attached_size :: (window: *wl_egl_window, width: *s32, height: *s32) -> void #foreign libwayland_egl;
