#scope_module

keyboard_listenter :: wl_keyboard_listener.{
    keymap = (data: *void, self: *wl_keyboard, format: u32, fd: s32, size: u32) -> void #c_call {
        ctx: #Context;
        push_context ctx {
            if format == wl_keyboard.keymap_format_xkb_v1 {
                keymap := mmap(null, size, PROT_READ, MAP_PRIVATE, fd, 0);
                defer munmap(keymap, size);

                d: *Wayland_Display = wl_proxy_get_user_data(self);
                if !ld_xkb_state_init(d, keymap)
                    log_error("Failed to initialize XKB state");
            } else {
                log_error("Received unsupported keymap from compositor!\n");
                assert(false);
            }
        }
    },

    enter = (data: *void, self: *wl_keyboard, serial: u32, surface: *wl_surface, keys: *wl_array) -> void #c_call {
        Input.input_application_has_focus = true;
    },

    leave = (data: *void, self: *wl_keyboard, serial: u32, surface: *wl_surface) -> void #c_call {
        d: *Wayland_Display = wl_proxy_get_user_data(self);
        Input.input_application_has_focus = false;
        ctx: #Context;
        push_context ctx {
            timer_stop(d.key_repeat_timer);
        }
    },

    key = (data: *void, self: *wl_keyboard, serial: u32, time: u32, key: u32, state: u32) -> void #c_call {
        ctx: #Context;
        push_context ctx {
            d: *Wayland_Display = wl_proxy_get_user_data(self);
            if !d.base.xkb_state.kb_state return;

            if state == wl_keyboard.key_state_pressed {
                d.key_to_repeat = key;
                if (d.key_repeat_rate) {
                    rate := 1000 / d.key_repeat_rate;
                    timer_start(d.key_repeat_timer, d.key_repeat_delay, rate);
                }
            } else {
                d.key_to_repeat = 0;
                timer_stop(d.key_repeat_timer);
            }

            handle_key_event(d, serial, key, state);
        }
    },

    modifiers = (data: *void, self: *wl_keyboard, serial: u32,
        mods_depressed: u32, mods_latched: u32, mods_locked: u32, group: u32) -> void #c_call
    {
        d: *Wayland_Display = wl_proxy_get_user_data(self);
        ld_xkb_state_set_mods(d, mods_depressed, mods_latched, mods_locked, group);
    },

    repeat_info = (data: *void, self: *wl_keyboard, rate: s32, delay: s32) -> void #c_call {
        d: *Wayland_Display = wl_proxy_get_user_data(self);
        d.key_repeat_delay = xx ifx delay > 0 then delay else 0;
        d.key_repeat_rate  = xx ifx rate > 0 then rate else 0;
    }
};

wl_key_repeat_cb :: (tid: Timer, user_data: *void) {
    d: *Wayland_Display = user_data;
    key := d.key_to_repeat;

    if !key {
        timer_stop(d.key_repeat_timer);
        return;
    }

    handle_key_event(d, d.input_serial, d.key_to_repeat, wl_keyboard.key_state_pressed, true);
}

handle_key_event :: (d: *Wayland_Display, serial: u32, key: u32, key_state: u32, repeat := false) {
    event_type : LD_XKB_Key_Event_Type = ifx key_state == wl_keyboard.key_state_pressed then .Press else .Release;
    event := ld_xkb_handle_key_event(d, key + 8, event_type, repeat);
    if event.ctrl_pressed d.input_serial = serial;
}

/* These are taken from <linux/input-event-codes.h> */
BTN_LEFT    : u32 : 0x110;
BTN_RIGHT   : u32 : 0x111;
BTN_MIDDLE  : u32 : 0x112;
BTN_SIDE    : u32 : 0x113;
BTN_EXTRA   : u32 : 0x114;
BTN_FORWARD : u32 : 0x115;
BTN_BACK    : u32 : 0x116;

refresh_cursor :: (w: *Wayland_Window) {
    if (w.display.pointer) {
        wl_pointer.set_cursor(
            w.display.pointer,
            w.enter_serial,
            w.cursor.surfaces[0],
            xx w.cursor.native.images[0].hotspot_x,
            xx w.cursor.native.images[0].hotspot_y);
    }
}

pointer_listener :: wl_pointer_listener.{
    enter = (data: *void, self: *wl_pointer, serial: u32, surface: *wl_surface,
        surface_x: wl_fixed_t, surface_y: wl_fixed_t) -> void #c_call
    {
        ctx: #Context;
        push_context ctx {
            d: *Wayland_Display = wl_proxy_get_user_data(self);
            d.current_hovered_window = wl_surface.get_user_data(surface);
            d.current_hovered_window.enter_serial = serial;
            refresh_cursor(d.current_hovered_window);
        }
    },

    leave = (data: *void, self: *wl_pointer, serial: u32, surface: *wl_surface) -> void #c_call {
        d: *Wayland_Display = wl_proxy_get_user_data(self);
        d.current_hovered_window = null;
    },

    motion = (data: *void, self: *wl_pointer, time: u32, fx: wl_fixed_t, fy: wl_fixed_t) -> void #c_call {
        ctx: #Context;
        push_context ctx {
            d: *Wayland_Display = wl_proxy_get_user_data(self);
            if d.current_hovered_window != null {
                m_x := wl_fixed_to_int(fx);
                m_y := wl_fixed_to_int(fy);
                d.current_hovered_window.mouse_x, d.current_hovered_window.mouse_y = window_scale_coords(d.current_hovered_window, m_x, m_y);
            }
        }
    },

    button = (data: *void, self: *wl_pointer, serial: u32, time: u32, button: u32, state: u32) -> void #c_call {
        d: *Wayland_Display = wl_proxy_get_user_data(self);

        event: Input.Event;
        event.type = .KEYBOARD;
        if button == {
            case BTN_LEFT;    event.key_code = .MOUSE_BUTTON_LEFT;
            case BTN_MIDDLE;  event.key_code = .MOUSE_BUTTON_MIDDLE;
            case BTN_RIGHT;   event.key_code = .MOUSE_BUTTON_RIGHT;

            case BTN_SIDE;    #through;
            case BTN_BACK;    event.key_code = .MOUSE_BUTTON_X1;

            case BTN_EXTRA;   #through;
            case BTN_FORWARD; event.key_code = .MOUSE_BUTTON_X2;
        }
        if state == wl_pointer.button_state_pressed {
            event.key_pressed = 1;
            d.base.input_button_states[event.key_code] = (Input.Key_Current_State.START | Input.Key_Current_State.DOWN);
        } else {
            event.key_pressed = 0;
            d.base.input_button_states[event.key_code] = Input.Key_Current_State.END;
        }

        ctx: #Context;
        push_context ctx {
            array_add(*d.base.events_this_frame, event);
        }

        d.input_serial = serial;
    },

    axis = (data: *void, self: *wl_pointer, time: u32, axis: u32, value: wl_fixed_t) -> void #c_call {
        ctx: #Context;
        push_context ctx {
            d: *Wayland_Display = wl_proxy_get_user_data(self);
            delta := wl_fixed_to_double(value);
            delta_with_multiplier := -delta * 6;
            scroll_value := ifx delta_with_multiplier > 0 ceil(delta_with_multiplier) else floor(delta_with_multiplier);
            if !d.pointer_axis_accumulator[axis] {
                d.pointer_axis_accumulator[axis] = xx scroll_value;
            }
        }
    },

    frame = (data: *void, self: *wl_pointer) -> void #c_call {
        ctx: #Context;
        push_context ctx {
            d: *Wayland_Display = wl_proxy_get_user_data(self);
            event: Input.Event;
            if d.pointer_axis_accumulator[0] {
                event.type = .MOUSE_V_WHEEL;
                event.typical_wheel_delta = WHEEL_DELTA;
                event.wheel_delta = d.pointer_axis_accumulator[0];
                array_add(*d.base.events_this_frame, event);
                d.base.mouse_wheel_delta.vertical += event.wheel_delta;
                d.pointer_axis_accumulator[0] = 0;
            }
            if d.pointer_axis_accumulator[1] {
                event.type = .MOUSE_H_WHEEL;
                event.typical_wheel_delta = WHEEL_DELTA;
                event.wheel_delta = d.pointer_axis_accumulator[1];
                array_add(*d.base.events_this_frame, event);
                d.base.mouse_wheel_delta.horizontal += event.wheel_delta;
                d.pointer_axis_accumulator[1] = 0;
            }
        }
    },

    axis_source = (data: *void, self: *wl_pointer, axis_source: u32) -> void #c_call {},
    axis_stop = (data: *void, self: *wl_pointer, time: u32, axis: u32) -> void #c_call {},
    axis_discrete = (data: *void, self: *wl_pointer, axis: u32, discrete: s32) -> void #c_call {},

    axis_value120 = (data: *void, self: *wl_pointer, axis: u32, value120: s32) -> void #c_call {
        ctx: #Context;
        push_context ctx {
            d: *Wayland_Display = wl_proxy_get_user_data(self);
            if !d.pointer_axis_accumulator[axis] {
                d.pointer_axis_accumulator[axis] = d.pointer_axis_multiplier[axis] * value120;
            }
        }
    },

    axis_relative_direction = (data: *void, self: *wl_pointer, axis: u32, direction: u32) -> void #c_call {
        d: *Wayland_Display = wl_proxy_get_user_data(self);
        if direction == wl_pointer.axis_relative_direction_identical {
            d.pointer_axis_multiplier[axis] = -1;
        } else {
            d.pointer_axis_multiplier[axis] = 1;
        }
    },
};

wl_display_poll :: (display: *Wayland_Display, timeout: s32) -> wayland_events := false, timer_events := false {
    wlfd := wl_display_get_fd(display.handle);

    pfd: [3]pollfd;
    pfd[0].fd = wlfd;
    pfd[0].events = POLLIN;
    pfd[1].fd = timers_epfd;
    pfd[1].events = POLLIN;
    pfd[2].fd = display.base.loop_wakeup_event;
    pfd[2].events = POLLIN;

    ret := poll(pfd.data, xx pfd.count, timeout);
    if ret <= 0 return;

    has_wayland_events    := (pfd[0].revents & POLLIN) == POLLIN;
    has_timer_events      := (pfd[1].revents & POLLIN) == POLLIN;
    has_loop_wakeup_event := (pfd[2].revents & POLLIN) == POLLIN;

    if has_loop_wakeup_event  consume_loop_wakeup_event(display);
    if has_timer_events       timers_tick();

    return has_wayland_events, has_timer_events;
}

wl_event_loop_step :: (display: *Wayland_Display, timeout: s32) -> bool {
    dpy := display.handle;
    dispatch_count : s32 = 0;

    while wl_display_prepare_read(dpy) != 0
        dispatch_count += wl_display_dispatch_pending(dpy);

    if wl_display_flush(dpy) < 0 && errno() != EAGAIN {
        wl_display_cancel_read(dpy);
        return true;
    }

    wlev, tev := wl_display_poll(display, timeout);
    if wlev {
        wl_display_read_events(dpy);
        dispatch_count += wl_display_dispatch_pending(dpy);
    } else {
        wl_display_cancel_read(dpy);
    }

    return (wlev && ((dispatch_count > 0) || (display.base.events_this_frame.count > 0))) || tev;
}

wl_wait_for_events :: (display: *Display) {
    wl_check_usage(display);
    while true {
        if wl_event_loop_step(display, -1) return;
    }
}

wl_update_window_events :: (display: *Display) {
    wl_check_usage(display);
    wl_event_loop_step(display, -1);
}

wl_get_mouse_pointer_position :: (window: *Window, right_handed: bool) -> x: int, y: int, success: bool {
    wl_check_usage(null, window);

    win: *Wayland_Window = window;
    if right_handed {
        return win.mouse_x, win.buffer_height - win.mouse_y, true;
    }
    return win.mouse_x, win.mouse_y, true;
}

wl_get_mouse_pointer_position :: (display: *Display, right_handed: bool) -> x: int, y: int, success: bool {
    wl_check_usage(display);

    d: *Wayland_Display = display;
    rx: int = 0;
    ry: int = 0;
    rs: bool = false;

    if d.current_hovered_window {
        rx, ry, rs = wl_get_mouse_pointer_position(cast(*Window) d.current_hovered_window, right_handed);
    }

    return rx, ry, rs;
}

#scope_file
#import "POSIX";
