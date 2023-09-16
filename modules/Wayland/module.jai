#load "util.jai";
#load "client-core.jai";

#load "protocols/core/wayland.jai";
#load "protocols/core/stable/presentation-time.jai";
#load "protocols/core/stable/viewporter.jai";
#load "protocols/core/stable/xdg-shell.jai";
#load "protocols/core/staging/single-pixel-buffer-v1.jai";

#load "protocols/core/staging/tearing-control-v1.jai";
#load "protocols/core/staging/fractional-scale-v1.jai";
#load "protocols/core/unstable/fullscreen-shell-unstable-v1.jai";
#load "protocols/core/unstable/xdg-decoration-unstable-v1.jai";

#load "cursor.jai";
#load "egl.jai";

wl_global_init :: () -> bool {
    if !wayland_lib_load(*wayland_core_procs)   return false;
    if !wayland_lib_load(*wayland_egl_procs)    return false;
    if !wayland_lib_load(*wayland_cursor_procs) return false;

    wayland_protocol_init();
    presentation_time_protocol_init();
    xdg_shell_protocol_init();
    viewporter_protocol_init();
    single_pixel_buffer_v1_protocol_init();

    tearing_control_v1_protocol_init();
    fractional_scale_v1_protocol_init();
    fullscreen_shell_unstable_v1_protocol_init();
    xdg_decoration_unstable_v1_protocol_init();

    return true;
}

wl_jext_bind :: (object: **$T/wl_proxy, registry: *wl_registry, id: u32, version: u32) #c_call {
    intf := T._interface_;
    object.* = wl_registry.bind(registry, id, intf, wl_max(wl_min(version, xx intf.version), 1));
}

#scope_module

#import "Basic";
#import "POSIX";
#import "String";

generic_c_call :: #type () #c_call;

wayland_lib_load :: (intf: *$T, $lib_name: string = "") -> bool #modify {
    struct_info := cast(*Type_Info_Struct) T;
    assert(struct_info.type == .STRUCT);

    found := false;
    for n: struct_info.notes {
        if !starts_with(n, "lib(") continue;
        assert(ends_with(n, ")"));

        lib := n;
        advance(*lib, "lib(".count);
        lib.count -= 1;
        lib_name = tprint("%\0", lib);
        found = true;
        break;
    }
    assert(found, "Please tag your struct with `@lib(name-of-your.so)`");

    return true;
}
{
    dlerror();
    lib := dlopen(lib_name.data, RTLD_NOW | RTLD_NOLOAD);
    if lib {
        log_error("Library '%' already loaded!", lib_name);
    } else {
        lib = dlopen(lib_name.data, RTLD_NOW);
        if !lib {
            log_error("Failed to load '%s': %", lib_name, to_string(dlerror()));
            return false;
        }
    }

    tis := cast(*Type_Info_Struct) type_info(T);
    for m : tis.members {
        if m.type.type != .PROCEDURE continue;
        if m.flags & .CONSTANT continue;

        pi := cast(*Type_Info_Procedure) m.type;
        if !(pi.procedure_flags & .IS_C_CALL) continue;

        dlerror();
        ppfn := cast(*generic_c_call)((cast(*u8) intf) + m.offset_in_bytes);
        ppfn.* = cast(generic_c_call) dlsym(lib, m.name.data);
        assert(!!(ppfn.*), "Failed to resolve function '%': %", m.name, to_string(dlerror()));
    }

    return true;
}
