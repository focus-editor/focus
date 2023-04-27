#load "util.jai";
#load "client-core.jai";

#load "protocols/core/wayland.jai";
#load "protocols/core/stable/presentation-time.jai";
#load "protocols/core/stable/viewporter.jai";
#load "protocols/core/stable/xdg-shell.jai";
#load "protocols/core/staging/single-pixel-buffer-v1.jai";

#load "protocols/core/staging/tearing-control-v1.jai";
#load "protocols/core/unstable/fullscreen-shell-unstable-v1.jai";
#load "protocols/core/unstable/xdg-decoration-unstable-v1.jai";

#load "cursor.jai";
#load "egl.jai";

wl_global_init :: () {
    wayland_protocol_init();
    presentation_time_protocol_init();
    xdg_shell_protocol_init();
    viewporter_protocol_init();
    single_pixel_buffer_v1_protocol_init();

    tearing_control_v1_protocol_init();
    fullscreen_shell_unstable_v1_protocol_init();
    xdg_decoration_unstable_v1_protocol_init();
}

wl_jext_bind :: (object: **$T/wl_proxy, registry: *wl_registry, id: u32, version: u32) #c_call {
    intf := T._interface_;
    <<object = wl_registry.bind(registry, id, intf, wl_max(wl_min(version, xx intf.version), 1));
}

#scope_module

#import "Basic";
#import "POSIX";

libwayland_client :: #system_library "libwayland-client";
libwayland_cursor :: #system_library "libwayland-cursor";
libwayland_egl    :: #system_library "libwayland-egl";

generic_c_call :: #type () -> void #c_call;
