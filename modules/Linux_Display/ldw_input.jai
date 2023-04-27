keyboard_listenter :: wl_keyboard_listener.{
    keymap = (data: *void, self: *wl_keyboard, format: u32, fd: s32, size: u32) -> void #c_call {
        ctx: Context;
        push_context ctx {
            if format == wl_keyboard.keymap_format_xkb_v1 {
                keymap := mmap(null, size, PROT_READ, MAP_PRIVATE, fd, 0);
                defer munmap(keymap, size);

                d : *WLDisplay = wl_proxy.get_user_data(self);
                d.kb_context = xkb_context_new(.XKB_CONTEXT_NO_FLAGS);
                d.kb_keymap = xkb_keymap_new_from_string(d.kb_context, keymap,
                    .XKB_KEYMAP_FORMAT_TEXT_V1, .XKB_KEYMAP_COMPILE_NO_FLAGS);
                d.kb_state = xkb_state_new(d.kb_keymap);

                d.mod_idx_shift     = xkb_keymap_mod_get_index(d.kb_keymap, XKB_MOD_NAME_SHIFT.data);
                d.mod_idx_ctrl      = xkb_keymap_mod_get_index(d.kb_keymap, XKB_MOD_NAME_CTRL.data);
                d.mod_idx_alt       = xkb_keymap_mod_get_index(d.kb_keymap, XKB_MOD_NAME_ALT.data);
                d.mod_idx_caps_lock = xkb_keymap_mod_get_index(d.kb_keymap, XKB_MOD_NAME_CAPS.data);
                d.mod_idx_super     = xkb_keymap_mod_get_index(d.kb_keymap, XKB_MOD_NAME_LOGO.data);
                d.mod_idx_alt_gr    = xkb_keymap_mod_get_index(d.kb_keymap, XKB_MOD_NAME_ALT_GR.data);
            } else {
                log_error("Received unsupported keymap from compositor!\n");
                assert(false);
            }
        }
    },

    enter = (data: *void, self: *wl_keyboard, serial: u32, surface: *wl_surface, keys: *wl_array) -> void #c_call {
    },

    leave = (data: *void, self: *wl_keyboard, serial: u32, surface: *wl_surface) -> void #c_call {
    },

    key = (data: *void, self: *wl_keyboard, serial: u32, time: u32, key: u32, state: u32) -> void #c_call {
        ctx: Context;
        push_context ctx {
            d : *WLDisplay = wl_proxy.get_user_data(self);
            if !d.kb_state return;

            buf: [16]u8;
            keycode: xkb_keycode_t = key + 8;
            keysym := xkb_state_key_get_one_sym(d.kb_state, keycode);
            utf32  := xkb_state_key_get_utf32(d.kb_state, keycode);

            event: Event;
            event.type = .KEYBOARD;
            event.key_code = x11_translate_key_code(keysym);
            event.shift_pressed = xkb_state_mod_index_is_active(d.kb_state, d.mod_idx_shift, .XKB_STATE_MODS_DEPRESSED) == 1;
            event.ctrl_pressed  = xkb_state_mod_index_is_active(d.kb_state, d.mod_idx_ctrl, .XKB_STATE_MODS_DEPRESSED) == 1;
            event.alt_pressed   = xkb_state_mod_index_is_active(d.kb_state, d.mod_idx_alt, .XKB_STATE_MODS_DEPRESSED) == 1;

            if state == wl_keyboard.key_state_pressed {
                event.key_pressed = 1;
                input_button_states[event.key_code] = (Key_Current_State.START | Key_Current_State.DOWN);
                if event.ctrl_pressed d.input_serial = serial;
            } else {
                event.key_pressed = 0;
                input_button_states[event.key_code] = Key_Current_State.END;
            }

            array_add(*events_this_frame, event);

            if event.key_pressed && (keysym < XK_BackSpace || keysym > XK_Hyper_R ) && !event.ctrl_pressed && utf32 {
                char_event: Event;
                char_event.type = .TEXT_INPUT;
                char_event.utf32 = utf32;
                array_add(*events_this_frame, char_event);
            }
        }
    },

    modifiers = (data: *void, self: *wl_keyboard, serial: u32,
        mods_depressed: u32, mods_latched: u32, mods_locked: u32, group: u32) -> void #c_call
    {
        d : *WLDisplay = wl_proxy.get_user_data(self);
        xkb_state_update_mask(
            d.kb_state,
            mods_depressed, mods_latched, mods_locked,
            group, group, group);
    },

    repeat_info = (data: *void, self: *wl_keyboard, rate: s32, delay: s32) -> void #c_call {
    }
};

/* These are taken from <linux/input-event-codes.h> */
BTN_LEFT   : u32 : 0x110;
BTN_RIGHT  : u32 : 0x111;
BTN_MIDDLE : u32 : 0x112;

pointer_listener :: wl_pointer_listener.{
    enter = (data: *void, self: *wl_pointer, serial: u32, surface: *wl_surface,
        surface_x: wl_fixed_t, surface_y: wl_fixed_t) -> void #c_call
    {
        current_hovered_window = wl_surface.get_user_data(surface);
    },

    leave = (data: *void, self: *wl_pointer, serial: u32, surface: *wl_surface) -> void #c_call {},

    motion = (data: *void, self: *wl_pointer, time: u32, fx: wl_fixed_t, fy: wl_fixed_t) -> void #c_call {
        if current_hovered_window != null {
            current_hovered_window.mouse_x = wl_fixed_to_int(fx);
            current_hovered_window.mouse_y = wl_fixed_to_int(fy);
        }
    },

    button = (data: *void, self: *wl_pointer, serial: u32, time: u32, button: u32, state: u32) -> void #c_call {
        d : *WLDisplay = wl_proxy.get_user_data(self);

        event: Event;
        event.type = .KEYBOARD;
        if button == {
            case BTN_LEFT;   event.key_code = .MOUSE_BUTTON_LEFT;
            case BTN_MIDDLE; event.key_code = .MOUSE_BUTTON_MIDDLE;
            case BTN_RIGHT;  event.key_code = .MOUSE_BUTTON_RIGHT;
        }
        if state == wl_pointer.button_state_pressed {
            event.key_pressed = 1;
            input_button_states[event.key_code] = (Key_Current_State.START | Key_Current_State.DOWN);
        } else {
            event.key_pressed = 0;
            input_button_states[event.key_code] = Key_Current_State.END;
        }

        ctx: Context;
        push_context ctx {
            array_add(*events_this_frame, event);
        }

        d.input_serial = serial;
    },

    axis = (data: *void, self: *wl_pointer, time: u32, axis: u32, value: wl_fixed_t) -> void #c_call {},
    frame = (data: *void, self: *wl_pointer) -> void #c_call {},
    axis_source = (data: *void, self: *wl_pointer, axis_source: u32) -> void #c_call {},
    axis_stop = (data: *void, self: *wl_pointer, time: u32, axis: u32) -> void #c_call {},
    axis_discrete = (data: *void, self: *wl_pointer, axis: u32, discrete: s32) -> void #c_call {},
    axis_value120 = (data: *void, self: *wl_pointer, axis: u32, value120: s32) -> void #c_call {},
    axis_relative_direction = (data: *void, self: *wl_pointer, axis: u32, direction: u32) -> void #c_call {},
};

wl_update_window_events :: (display: *WLDisplay) {
    wl_display.dispatch(display.handle);
}

wl_get_mouse_pointer_position :: (win: *WLWindow, right_handed: bool) -> x: int, y: int, success: bool {
    if right_handed {
        return win.mouse_x, win.height - win.mouse_y, true;
    }
    return win.mouse_x, win.mouse_y, true;
}

wl_get_mouse_pointer_position :: (right_handed: bool) -> x: int, y: int, success: bool {
    if current_hovered_window return wl_get_mouse_pointer_position(current_hovered_window, right_handed);
    return 0, 0, false;
}

#scope_file
#import "POSIX";
#import "libxkbcommon";

current_hovered_window: *WLWindow;
