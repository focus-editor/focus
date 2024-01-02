wl_cursor_image :: struct {
    width: u32;
    height: u32;
    hotspot_x: u32;
    hotspot_y: u32;
    delay: u32;
}

wl_cursor :: struct {
    image_count: u32;
    images: **wl_cursor_image;
    name: *u8;
}

wl_cursor_theme :: struct {
    cursor_count: u32;
    cursors: **wl_cursor;

    /*
     * The corresponding structure in the `libwayland-cursor` has more fields than
     * those above. Instantiating this structure is an error, it should only be used
     * via pointers returned by the library.
     */
};

using wayland_cursor_procs: Wayland_Cursor_Procs;

#scope_module

Wayland_Cursor_Procs :: struct {
    wl_cursor_theme_load : (name: *u8, size: s32, shm: *wl_shm) -> *wl_cursor_theme #c_call;
    wl_cursor_theme_destroy : (theme: *wl_cursor_theme) -> void #c_call;
    wl_cursor_theme_get_cursor : (theme: *wl_cursor_theme, name: *u8) -> *wl_cursor #c_call;

    wl_cursor_image_get_buffer : (image: *wl_cursor_image) -> *wl_buffer #c_call;

    wl_cursor_frame : (cursor: *wl_cursor, time: u32) -> s32 #c_call;
    wl_cursor_frame_and_duration : (cursor: *wl_cursor, time: u32, duration: *u32) -> s32 #c_call;
}
