xkb_context :: struct {}
xkb_keymap  :: struct {}
xkb_state   :: struct {}
xkb_keycode_t :: u32;
xkb_keysym_t  :: u32;
xkb_mod_mask_t :: u32;
xkb_mod_index_t :: u32;
xkb_layout_index_t :: u32;
xkb_level_index_t :: u32;
xkb_state_component :: enum {
    XKB_STATE_MODS_DEPRESSED :: (1 << 0);
    XKB_STATE_MODS_LATCHED :: (1 << 1);
    XKB_STATE_MODS_LOCKED :: (1 << 2);
    XKB_STATE_MODS_EFFECTIVE :: (1 << 3);
    XKB_STATE_LAYOUT_DEPRESSED :: (1 << 4);
    XKB_STATE_LAYOUT_LATCHED :: (1 << 5);
    XKB_STATE_LAYOUT_LOCKED :: (1 << 6);
    XKB_STATE_LAYOUT_EFFECTIVE :: (1 << 7);
    XKB_STATE_LEDS :: (1 << 8);
}

XKB_MOD_NAME_SHIFT   :: "Shift";
XKB_MOD_NAME_CAPS    :: "Lock";
XKB_MOD_NAME_CTRL    :: "Control";
XKB_MOD_NAME_ALT     :: "Mod1";
XKB_MOD_NAME_NUM     :: "Mod2";
XKB_MOD_NAME_LOGO    :: "Mod4";
XKB_MOD_NAME_ALT_GR  :: "Mod5";  // not part of XKB

xkb_keysym_flags :: enum {
    XKB_KEYSYM_NO_FLAGS :: 0;
    XKB_KEYSYM_CASE_INSINSITIVE :: 1;
}

xkb_context_flags :: enum {
    XKB_CONTEXT_NO_FLAGS :: 0;
    XKB_CONTEXT_NO_DEFAULT_INCLUDES :: (1 << 0);
    XKB_CONTEXT_NO_ENVIRONMENT_NAMES :: (1 << 1);
    XKB_CONTEXT_NO_SECURE_GETENV :: (1 << 2);
}

xkb_keymap_compile_flags :: enum {
    XKB_KEYMAP_COMPILE_NO_FLAGS :: 0;
}

xkb_keymap_format :: enum {
    XKB_KEYMAP_FORMAT_TEXT_V1 :: 1;
}

xkb_key_direction :: enum u32 {
    XKB_KEY_UP;
    XKB_KEY_DOWN;
}

xkb_consumed_mode :: enum {
    XKB_CONSUMED_MODE_XKB;
    XKB_CONSUMED_MODE_GTK;
}

xkb_compose_table :: struct {}
xkb_compose_state :: struct {}

xkb_compose_compile_flags :: enum {
    XKB_COMPOSE_COMPILE_NO_FLAGS :: 0;
}

xkb_compose_state_flags :: enum {
    XKB_COMPOSE_STATE_NO_FLAGS :: 0;
}

xkb_compose_status :: enum {
    XKB_COMPOSE_NOTHING;
    XKB_COMPOSE_COMPOSING;
    XKB_COMPOSE_COMPOSED;
    XKB_COMPOSE_CANCELLED;
}

xkb_compose_feed_result :: enum {
    XKB_COMPOSE_FEED_IGNORED;
    XKB_COMPOSE_FEED_ACCEPTED;
}

using libxkb_procs: XKB_Procs;

xkbcommon_load :: (intf: *XKB_Procs = *libxkb_procs, init_xcb_compat := false) -> bool {
    populate_procs :: inline (procs: *$T, sonames: []string) -> bool {
        generic_c_call :: #type () #c_call;

        for soname : sonames {
            dlerror();
            lib := dlopen(soname.data, RTLD_NOW);
            if !lib {
                log_error("Failed to load %: %", soname, to_string(dlerror()));
                continue;
            }

            tis := cast(*Type_Info_Struct) type_info(T);
            for m : tis.members {
                if m.type.type != .PROCEDURE continue;
                if m.flags & .CONSTANT continue;

                pi := cast(*Type_Info_Procedure) m.type;
                if !(pi.procedure_flags & .IS_C_CALL) continue;

                dlerror();
                ppfn := cast(*generic_c_call)((cast(*u8) procs) + m.offset_in_bytes);
                ppfn.* = cast(generic_c_call) dlsym(lib, m.name.data);
                if !ppfn.* {
                    log_error("Failed to resolve function '%' in '%': %", m.name, soname, to_string(dlerror()));
                    continue;
                }
            }

            log("xkbcommon: loaded %", soname);
            return true;
        }

        return false;
    }

    if init_xcb_compat {
        if !populate_procs(*intf.x11_compat, .["libxkbcommon-x11.so.0", "libxkbcommon-x11.so"]) return false;
        intf._x11_compat_meta.loaded = true;
    }

    if !populate_procs(intf, .["libxkbcommon.so.0", "libxkbcommon.so"]) return false;
    intf._xkb_procs_meta.loaded = true;

    return true;
}

#scope_module
#import "Basic";
#import "String";
#import "POSIX";

XKB_Procs :: struct {
    _xkb_procs_meta : struct {
        loaded: bool;
    }

    xkb_keysym_get_name : (keysym: xkb_keysym_t, buffer: *u8, size: u64) -> s32 #c_call;
    xkb_keysym_from_name : (name: *u8, flags: xkb_keysym_flags) -> xkb_keysym_t #c_call;
    xkb_keysym_to_utf8 : (keysym: xkb_keysym_t, buffer: *u8, size: u64) -> s32 #c_call;
    xkb_keysym_to_utf32 : (keysym: xkb_keysym_t) -> u32 #c_call;
    xkb_keysym_to_upper : (keysym: xkb_keysym_t) -> xkb_keysym_t #c_call;
    xkb_keysym_to_lower : (keysym: xkb_keysym_t) -> xkb_keysym_t #c_call;

    xkb_context_new : (flags: xkb_context_flags) -> *xkb_context #c_call;
    xkb_context_ref : (ctx: *xkb_context) -> *xkb_context #c_call;
    xkb_context_unref : (ctx: *xkb_context) #c_call;
    xkb_context_set_user_data : (ctx: *xkb_context, data: *void) #c_call;
    xkb_context_get_user_data : (ctx: *xkb_context) -> *void #c_call;

    xkb_keymap_new_from_string : (ctx: *xkb_context, str: *u8, format: xkb_keymap_format, flags: xkb_keymap_compile_flags) -> *xkb_keymap #c_call;
    xkb_keymap_ref : (keymap: *xkb_keymap) -> *xkb_keymap #c_call;
    xkb_keymap_unref : (keymap: *xkb_keymap) #c_call;
    xkb_keymap_mod_get_index : (keymap: *xkb_keymap, name: *u8) -> xkb_mod_index_t #c_call;
    xkb_keymap_min_keycode : (keymap: *xkb_keymap) -> xkb_keycode_t #c_call;
    xkb_keymap_max_keycode : (keymap: *xkb_keymap) -> xkb_keycode_t #c_call;
    xkb_keymap_num_layouts : (keymap: *xkb_keymap) -> xkb_layout_index_t #c_call;
    xkb_keymap_num_levels_for_key : (keymap: *xkb_keymap, key: xkb_keycode_t, layout: xkb_layout_index_t) -> xkb_level_index_t #c_call;
    xkb_keymap_layout_get_name : (keymap: *xkb_keymap, idx: xkb_layout_index_t) -> *u8 #c_call;
    xkb_keymap_key_get_syms_by_level : (keymap: *xkb_keymap, key: xkb_keycode_t, layout: xkb_layout_index_t, level: xkb_level_index_t, syms_out: **xkb_keysym_t) -> s32 #c_call;

    xkb_state_new : (keymap: *xkb_keymap) -> *xkb_state #c_call;
    xkb_state_ref : (state: *xkb_state) -> *xkb_state #c_call;
    xkb_state_unref : (state: *xkb_state) #c_call;
    xkb_state_update_key : (state: *xkb_state, key: xkb_keycode_t, direction: xkb_key_direction) -> xkb_state_component #c_call;
    xkb_state_key_get_one_sym : (state: *xkb_state, key: xkb_keycode_t) -> xkb_keysym_t #c_call;
    xkb_state_key_get_syms : (state: *xkb_state, key: xkb_keycode_t, syms_out: **xkb_keysym_t) -> s32 #c_call;
    xkb_state_key_get_utf8 : (state: *xkb_state, key: xkb_keycode_t, buffer: *u8, size: u64) -> s32 #c_call;
    xkb_state_key_get_utf32 : (state: *xkb_state, key: xkb_keycode_t) -> u32 #c_call;
    xkb_state_update_mask : (
        state: *xkb_state,
        depressed_mods: xkb_mod_mask_t,
        latched_mods: xkb_mod_mask_t,
        locked_mods: xkb_mod_mask_t,
        depressed_layout: xkb_layout_index_t,
        latched_layout: xkb_layout_index_t,
        locked_layout: xkb_layout_index_t) -> xkb_state_component #c_call;
    xkb_state_mod_index_is_active : (state: *xkb_state, idx: xkb_mod_index_t, type: xkb_state_component) -> s32 #c_call;
    xkb_state_key_get_consumed_mods2 : (state: *xkb_state, key: xkb_keycode_t, mode: xkb_consumed_mode) -> xkb_mod_mask_t #c_call;
    xkb_state_mod_index_is_consumed : (state: *xkb_state, key: xkb_keycode_t, idx: xkb_mod_index_t) -> s32 #c_call;
    xkb_state_key_get_layout: (state: *xkb_state, key: xkb_keycode_t) -> xkb_layout_index_t #c_call;
    xkb_state_key_get_level: (state: *xkb_state, key: xkb_keycode_t, layout: xkb_layout_index_t) -> xkb_level_index_t #c_call;

    xkb_compose_table_new_from_locale : (ctx: *xkb_context, locale: *u8, flags: xkb_compose_compile_flags) -> *xkb_compose_table #c_call;
    xkb_compose_table_ref : (table: *xkb_compose_table) -> *xkb_compose_table #c_call;
    xkb_compose_table_unref : (table: *xkb_compose_table) #c_call;

    xkb_compose_state_new : (table: *xkb_compose_table, flags: xkb_compose_state_flags) -> *xkb_compose_state #c_call;
    xkb_compose_state_ref : (state: xkb_compose_state) -> *xkb_compose_state #c_call;
    xkb_compose_state_unref : (state: *xkb_compose_state) #c_call;
    xkb_compose_state_feed : (state: *xkb_compose_state, keysym: xkb_keysym_t) -> xkb_compose_feed_result #c_call;
    xkb_compose_state_reset : (state: *xkb_compose_state) #c_call;
    xkb_compose_state_get_status : (state: *xkb_compose_state) -> xkb_compose_status #c_call;
    xkb_compose_state_get_one_sym : (state: *xkb_compose_state) -> xkb_keysym_t #c_call;

    using x11_compat: struct {
        _x11_compat_meta: struct {
            loaded: bool;
        }
        xkb_x11_setup_xkb_extension: (xcb_connection: *void, xkb_major_version: u16, xkb_minor_version: u16, flags: u32, xkb_major_version_out: *u16, xkb_minor_version_out: *u16, base_event_out: *u8, base_error_out: *u8) -> s32 #c_call;
        xkb_x11_get_core_keyboard_device_id: (xcb_connection: *void) -> s32 #c_call;
        xkb_x11_keymap_new_from_device: (ctx: *xkb_context, xkb_connection: *void, device_id: s32, flags: xkb_keymap_compile_flags) -> *xkb_keymap #c_call;
        xkb_x11_state_new_from_device: (keymap: *xkb_keymap, xcb_connection: *void, device_id: s32) -> *xkb_state #c_call;
    }
}
