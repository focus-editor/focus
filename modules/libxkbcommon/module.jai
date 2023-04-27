xkb_context :: struct {}
xkb_keymap  :: struct {}
xkb_state   :: struct {}
xkb_keycode_t :: u32;
xkb_keysym_t  :: u32;
xkb_mod_mask_t :: u32;
xkb_mod_index_t :: u32;
xkb_layout_index_t :: u32;
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

xkb_keysym_get_name :: (keysym: xkb_keysym_t, buffer: *u8, size: u64) -> s32 #foreign libxkb;
xkb_keysym_from_name :: (name: *u8, flags: xkb_keysym_flags) -> xkb_keysym_t #foreign libxkb;

xkb_keysym_to_utf8 :: (keysym: xkb_keysym_t, buffer: *u8, size: u64) -> s32 #foreign libxkb;
xkb_keysym_to_utf32 :: (keysym: xkb_keysym_t) -> u32 #foreign libxkb;

xkb_keysym_to_upper :: (keysym: xkb_keysym_t) -> xkb_keysym_t #foreign libxkb;
xkb_keysym_to_lower :: (keysym: xkb_keysym_t) -> xkb_keysym_t #foreign libxkb;

xkb_context_flags :: enum {
    XKB_CONTEXT_NO_FLAGS :: 0;
    XKB_CONTEXT_NO_DEFAULT_INCLUDES :: (1 << 0);
    XKB_CONTEXT_NO_ENVIRONMENT_NAMES :: (1 << 1);
    XKB_CONTEXT_NO_SECURE_GETENV :: (1 << 2);
}

xkb_context_new :: (flags: xkb_context_flags) -> *xkb_context #foreign libxkb;
xkb_context_ref :: (ctx: *xkb_context) -> *xkb_context #foreign libxkb;
xkb_context_unref :: (ctx: *xkb_context) #foreign libxkb;
xkb_context_set_user_data :: (ctx: *xkb_context, data: *void) #foreign libxkb;
xkb_context_get_user_data :: (ctx: *xkb_context) -> *void #foreign libxkb;

xkb_keymap_compile_flags :: enum {
    XKB_KEYMAP_COMPILE_NO_FLAGS :: 0;
}

xkb_keymap_format :: enum {
    XKB_KEYMAP_FORMAT_TEXT_V1 :: 1;
}

xkb_keymap_new_from_string :: (ctx: *xkb_context, string: *u8, format: xkb_keymap_format, flags: xkb_keymap_compile_flags) -> *xkb_keymap #foreign libxkb;
xkb_keymap_ref :: (keymap: *xkb_keymap) -> *xkb_keymap #foreign libxkb;
xkb_keymap_unref :: (keymap: *xkb_keymap) #foreign libxkb;
xkb_keymap_mod_get_index :: (keymap: *xkb_keymap, name: *u8) -> xkb_mod_index_t #foreign libxkb;

xkb_state_new :: (keymap: *xkb_keymap) -> *xkb_state #foreign libxkb;
xkb_state_ref :: (state: *xkb_state) -> *xkb_state #foreign libxkb;
xkb_state_unref :: (state: *xkb_state) #foreign libxkb;
xkb_state_key_get_one_sym :: (state: *xkb_state, key: xkb_keycode_t) -> xkb_keysym_t #foreign libxkb;
xkb_state_key_get_utf8 :: (state: *xkb_state, key: xkb_keycode_t, buffer: *u8, size: u64) -> s32 #foreign libxkb;
xkb_state_key_get_utf32 :: (state: *xkb_state, key: xkb_keycode_t) -> u32 #foreign libxkb;
xkb_state_update_mask :: (
    state: *xkb_state,
    depressed_mods: xkb_mod_mask_t,
    latched_mods: xkb_mod_mask_t,
    locked_mods: xkb_mod_mask_t,
    depressed_layout: xkb_layout_index_t,
    latched_layout: xkb_layout_index_t,
    locked_layout: xkb_layout_index_t) -> xkb_state_component #foreign libxkb;
xkb_state_mod_index_is_active :: (state: *xkb_state, idx: xkb_mod_index_t, type: xkb_state_component) -> s32 #foreign libxkb;

#scope_module

libxkb :: #system_library "libxkbcommon";
