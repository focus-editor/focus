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

                d.kb_compose_table = xkb_compose_table_new_from_locale(d.kb_context, setlocale(LC_ALL, null), .XKB_COMPOSE_COMPILE_NO_FLAGS);
                d.kb_compose_state = xkb_compose_state_new(d.kb_compose_table, .XKB_COMPOSE_STATE_NO_FLAGS);
            } else {
                log_error("Received unsupported keymap from compositor!\n");
                assert(false);
            }
        }
    },

    enter = (data: *void, self: *wl_keyboard, serial: u32, surface: *wl_surface, keys: *wl_array) -> void #c_call {
        input_application_has_focus = true;
    },

    leave = (data: *void, self: *wl_keyboard, serial: u32, surface: *wl_surface) -> void #c_call {
        d : *WLDisplay = wl_proxy.get_user_data(self);
        input_application_has_focus = false;
        ctx: Context;
        push_context ctx {
            wl_timer_stop(d.key_repeat_timer);
        }
    },

    key = (data: *void, self: *wl_keyboard, serial: u32, time: u32, key: u32, state: u32) -> void #c_call {
        ctx: Context;
        push_context ctx {
            d : *WLDisplay = wl_proxy.get_user_data(self);
            if !d.kb_state return;

            if state == wl_keyboard.key_state_pressed {
                d.key_to_repeat = key;
                rate := 1000 / d.key_repeat_rate;
                wl_timer_start(d.key_repeat_timer, d.key_repeat_delay, rate);
            } else {
                d.key_to_repeat = 0;
                wl_timer_stop(d.key_repeat_timer);
            }

            handle_key_event(d, serial, key, state);
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
        d : *WLDisplay = wl_proxy.get_user_data(self);
        d.key_repeat_delay = xx delay;
        d.key_repeat_rate  = xx rate;
    }
};

wl_key_repeat_cb :: (timer: *WLTimer) {
    d := timer.display;
    key := d.key_to_repeat;

    if !key {
        wl_timer_stop(d.key_repeat_timer);
        return;
    }

    handle_key_event(d, d.input_serial, d.key_to_repeat, wl_keyboard.key_state_pressed);
}

handle_key_event :: (d: *WLDisplay, serial: u32, key: u32, state: u32) {
    utf32: u32;
    is_printable: bool;
    keycode: xkb_keycode_t = key + 8;
    keysym := xkb_state_key_get_one_sym(d.kb_state, keycode);

    event: Event;
    event.type = .KEYBOARD;
    event.shift_pressed    = xkb_state_mod_index_is_active(d.kb_state, d.mod_idx_shift, .XKB_STATE_MODS_EFFECTIVE) == 1;
    event.ctrl_pressed     = xkb_state_mod_index_is_active(d.kb_state, d.mod_idx_ctrl,  .XKB_STATE_MODS_EFFECTIVE) == 1;
    event.alt_pressed      = xkb_state_mod_index_is_active(d.kb_state, d.mod_idx_alt,   .XKB_STATE_MODS_EFFECTIVE) == 1;
    event.cmd_meta_pressed = xkb_state_mod_index_is_active(d.kb_state, d.mod_idx_super, .XKB_STATE_MODS_EFFECTIVE) == 1;

    if state == wl_keyboard.key_state_pressed {
        xkb_compose_state_feed(d.kb_compose_state, keysym);

        status := xkb_compose_state_get_status(d.kb_compose_state);
        if status == .XKB_COMPOSE_COMPOSED || status == .XKB_COMPOSE_CANCELLED {
            keysym = xkb_compose_state_get_one_sym(d.kb_compose_state);
            xkb_compose_state_reset(d.kb_compose_state);
        }

        utf32 = xkb_keysym_to_utf32(keysym);
        is_printable = ((utf32 >= 32) && (utf32 != 127));

        event.key_pressed = 1;
        event.key_code = x11_translate_key_code(keysym);
        event.text_input_count = xx is_printable;
        input_button_states[event.key_code] = (Key_Current_State.START | Key_Current_State.DOWN);
        if event.ctrl_pressed d.input_serial = serial;
    } else {
        event.key_pressed = 0;
        event.key_code = x11_translate_key_code(keysym);
        input_button_states[event.key_code] = Key_Current_State.END;
    }

    array_add(*events_this_frame, event);

    if event.key_pressed && is_printable {
        text_event: Event;
        text_event.type = .TEXT_INPUT;
        text_event.key_pressed = 1;
        text_event.key_code = x11_translate_key_code(keysym);
        text_event.utf32 = utf32;
        array_add(*events_this_frame, text_event);
    }
}

/* These are taken from <linux/input-event-codes.h> */
BTN_LEFT   : u32 : 0x110;
BTN_RIGHT  : u32 : 0x111;
BTN_MIDDLE : u32 : 0x112;

refresh_cursor :: (w: *WLWindow) {
    wl_pointer.set_cursor(
        w.display.pointer,
        w.enter_serial,
        w.cursor.surfaces[0],
        xx w.cursor.native.images[0].hotspot_x,
        xx w.cursor.native.images[0].hotspot_y);
}

pointer_listener :: wl_pointer_listener.{
    enter = (data: *void, self: *wl_pointer, serial: u32, surface: *wl_surface,
        surface_x: wl_fixed_t, surface_y: wl_fixed_t) -> void #c_call
    {
        ctx: Context;
        push_context ctx {
            w := isa(get_by_native_handle(surface), WLWindow);
            current_hovered_window = wl_surface.get_user_data(surface);
            w.enter_serial = serial;
            refresh_cursor(w);
        }
    },

    leave = (data: *void, self: *wl_pointer, serial: u32, surface: *wl_surface) -> void #c_call {},

    motion = (data: *void, self: *wl_pointer, time: u32, fx: wl_fixed_t, fy: wl_fixed_t) -> void #c_call {
        ctx: Context;
        push_context ctx {
            if current_hovered_window != null {
                m_x := wl_fixed_to_int(fx);
                m_y := wl_fixed_to_int(fy);
                current_hovered_window.mouse_x, current_hovered_window.mouse_y = window_scale_coords(current_hovered_window, m_x, m_y);
            }
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

    axis = (data: *void, self: *wl_pointer, time: u32, axis: u32, value: wl_fixed_t) -> void #c_call {
        ctx: Context;
        push_context ctx {
            d: *WLDisplay = wl_proxy.get_user_data(self);
            sign := ifx (wl_fixed_to_int(value) < 0) then cast(s32)-1 else 1;
            delta := (WHEEL_DELTA / 2); // @TODO: this is set on a "feels good on my machine" basis, should be calculated some other way (perhaps based on the height of a line?)
            d.pointer_axis_accumulator[axis] += d.pointer_axis_multiplier[axis] * sign * delta;
        }
    },

    frame = (data: *void, self: *wl_pointer) -> void #c_call {
        ctx: Context;
        push_context ctx {
            d: *WLDisplay = wl_proxy.get_user_data(self);
            if d.pointer_axis_accumulator[0] {
                event: Event;
                event.type = .MOUSE_WHEEL;
                event.typical_wheel_delta = WHEEL_DELTA;
                event.wheel_delta = d.pointer_axis_accumulator[0];
                array_add(*events_this_frame, event);
                mouse_delta_z += event.wheel_delta;

                d.pointer_axis_accumulator[0] = 0;
            }
        }
    },

    axis_source = (data: *void, self: *wl_pointer, axis_source: u32) -> void #c_call {},
    axis_stop = (data: *void, self: *wl_pointer, time: u32, axis: u32) -> void #c_call {},
    axis_discrete = (data: *void, self: *wl_pointer, axis: u32, discrete: s32) -> void #c_call {},

    axis_value120 = (data: *void, self: *wl_pointer, axis: u32, value120: s32) -> void #c_call {
        ctx: Context;
        push_context ctx {
            d: *WLDisplay = wl_proxy.get_user_data(self);
            d.pointer_axis_accumulator[axis] += d.pointer_axis_multiplier[axis] * value120;
        }
    },

    axis_relative_direction = (data: *void, self: *wl_pointer, axis: u32, direction: u32) -> void #c_call {
        d: *WLDisplay = wl_proxy.get_user_data(self);
        if direction == wl_pointer.axis_relative_direction_identical {
            d.pointer_axis_multiplier[axis] = 1;
        } else {
            d.pointer_axis_multiplier[axis] = -1;
        }
    },
};

wl_update_window_events :: (display: *WLDisplay) {
    display_poll :: (display: *WLDisplay) -> s32 {
        wlfd := wl_display.get_fd(display.handle);

        pfd: [2]pollfd;
        pfd[0].fd = wlfd;
        pfd[0].events = POLLIN;
        pfd[1].fd = display.epfd;
        pfd[1].events = POLLIN;

        ret := poll(pfd.data, 2, 5);
        if ret <= 0 return ret;

        has_wayland_events := false;
        for 0..1 {
            if !pfd[it].revents {
                continue;
            }
            if pfd[it].fd == wlfd {
                has_wayland_events = true;
                continue;
            }

            assert(pfd[it].fd == display.epfd);
            ev: epoll_event;
            count := epoll_wait(display.epfd, *ev, 1, -1);
            assert(count == 1);

            if wl_tick_timers(display, ev.data.fd) continue;
        }

        return ifx has_wayland_events then cast(s32) 1 else 0;
    }

    wl_display.flush(display.handle);
    if wl_display.prepare_read(display.handle) == 0 {
        err := display_poll(display);
        if err > 0 {
            wl_display.read_events(display.handle);
            wl_display.dispatch_pending(display.handle);
        } else {
            wl_display.cancel_read(display.handle);
        }
    } else {
        wl_display.dispatch_pending(display.handle);
    }
}

wl_get_mouse_pointer_position :: (win: *WLWindow, right_handed: bool) -> x: int, y: int, success: bool {
    if right_handed {
        return win.mouse_x, win.buffer_height - win.mouse_y, true;
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
