/*
 * @TODO @FIXME:
 *  - holding down a key on the keyboard doesn't repeat the character
 *  - make proper libxkbcommon bindings
 *  - add binding for memfd_create()
 */

MIME_TYPE_TEXT        :: "text/plain;charset=utf-8";
MIME_TYPE_TEXT_NOLOOP :: "text/x-plain-do-not-loop-on-self;charset=utf-8";
MIME_TYPE_FILE_LIST   :: "text/uri-list";

WLCursor :: struct {
    name: string;
    surfaces: [..]*wl_surface;
    native: *wl_cursor;
}

WLDisplay :: struct {
    handle: *wl_display;

    registry: *wl_registry;
    compositor: *wl_compositor;
    wm_base: *xdg_wm_base;
    shm: *wl_shm;

    decoration_manager: *zxdg_decoration_manager_v1;

    seat: *wl_seat;

    pointer: *wl_pointer;
    cursor_theme: *wl_cursor_theme;
    cursors: Table(string, WLCursor);
    input_serial: u32;
    key_repeat_delay: u32 = 100;
    key_repeat_rate: u32 = 20;
    key_repeat_timer: Timer;
    key_to_repeat: u32;

    pointer_axis_multiplier: [2]s32 = .[-1, -1];
    pointer_axis_accumulator: [2]s32 = .[0, 0];

    keyboard: *wl_keyboard;
    kb_context: *xkb_context;
    kb_keymap : *xkb_keymap;
    kb_state  : *xkb_state;
    kb_compose_table: *xkb_compose_table;
    kb_compose_state: *xkb_compose_state;
    mod_idx_shift     : u32;
    mod_idx_ctrl      : u32;
    mod_idx_alt       : u32;
    mod_idx_caps_lock : u32;
    mod_idx_super     : u32;
    mod_idx_alt_gr    : u32;

    data_device_manager: *wl_data_device_manager;
    data_device: *wl_data_device;

    data_offer: *wl_data_offer;
    data_offer_mime_types: [..] string;

    drop_target: *WLWindow;
    drop_serial: u32;

    current_text_selection: String_Builder;

    clipboard_source: *wl_data_source;
    clipboard_send_data: string;

    viewporter: *wp_viewporter;
    fractional_scale_manager: *wp_fractional_scale_manager_v1;

    egl_dpy: EGLDisplay;
    egl_ctx: EGLContext;
    egl_cnf: EGLConfig;

    fixed_scaling: bool;
    scale_factor_override: s32;
}

WLDesiredPreconfigureState :: enum {
    NONE;
    FULLSCREEN;
    MAXIMIZED;
}

WLWindow :: struct {
    // we would really like this to be LDWindow but we get a circular dependency if we declare it like that
    wrapper: *void;

    handle: *wl_surface;
    display: *WLDisplay;

    title: string;

    background_color_buffer: *wl_buffer;

    x_surface: *xdg_surface;
    x_toplevel: *xdg_toplevel;
    x_toplevel_configured: bool;
    decoration: *zxdg_toplevel_decoration_v1;

    creation_width: s32;
    creation_height: s32;

    window_width: s32;
    window_height: s32;

    buffer_width: s32;
    buffer_height: s32;

    cursor: WLCursor;
    mouse_x: s32;
    mouse_y: s32;

    dnd_x: s32;
    dnd_y: s32;

    // this is here to "drive" the main loop when OpenGL is initialized
    callback: *wl_callback;

    egl_native: *wl_egl_window;
    egl_surface: EGLSurface;

    enter_serial: u32;

    fractional_scale_proxy: *wp_fractional_scale_v1;
    fractional_scale: s32 = 120;
    viewport: *wp_viewport;

    // dumb stuff
    pre_configure_desired_state: WLDesiredPreconfigureState;
}

window_scale_coords :: inline (w: *WLWindow, x: s32, y: s32) -> (s32, s32) {
    fractional_scale := ifx w.display.fixed_scaling then w.display.scale_factor_override else w.fractional_scale;

    scaled_x : s32 = x * fractional_scale;
    ret_x : s32 = scaled_x / 120 + ifx (scaled_x % 120) < 60 then cast(s32) 0 else 1;

    scaled_y : s32 = y * fractional_scale;
    ret_y : s32 = scaled_y / 120 + ifx (scaled_y % 120) < 60 then cast(s32) 0 else 1;

    return ret_x, ret_y;
}

window_calculate_buffer_size :: inline (w: *WLWindow) {
    w.buffer_width, w.buffer_height = window_scale_coords(w, w.window_width, w.window_height);
}

wl_window_resize_viewport :: (w: *WLWindow) {
    f0 :: #run wl_fixed_from_int(0);
    wp_viewport.set_source(w.viewport, f0, f0, wl_fixed_from_int(w.buffer_width), wl_fixed_from_int(w.buffer_height));
    wp_viewport.set_destination(w.viewport, w.window_width, w.window_height);
}

wm_base_listener :: xdg_wm_base_listener.{
    ping = (data: *void, shell: *xdg_wm_base, serial: u32) -> void #c_call {
        xdg_wm_base.pong(shell, serial);
    }
};

registry_listener :: wl_registry_listener.{
    global = (data: *void, registry: *wl_registry, id: u32, intf: *u8, version: u32) -> void #c_call {
        d: *WLDisplay = data;

        maybe_init_data_device :: (d: *WLDisplay) #c_call {
            if d.seat && d.data_device_manager && !d.data_device {
                d.data_device = d.data_device_manager.get_data_device(d.data_device_manager, d.seat);
                wl_data_device.add_listener(d.data_device, *data_device_listener, null);
                wl_proxy.set_user_data(d.data_device, d);
            }
        }

        if to_string(intf) == {
            case "wl_compositor"; {
                wl_jext_bind(*d.compositor, registry, id, version);
            }
            case "wl_shm"; {
                wl_jext_bind(*d.shm, registry, id, version);
            }
            case "xdg_wm_base"; {
                wl_jext_bind(*d.wm_base, registry, id, version);
                xdg_wm_base.add_listener(d.wm_base, *wm_base_listener, d);
            }
            case "wl_seat"; {
                wl_jext_bind(*d.seat, registry, id, version);

                d.pointer = wl_seat.get_pointer(d.seat);
                wl_proxy.set_user_data(d.pointer, d);
                wl_pointer.add_listener(d.pointer, *pointer_listener, d);

                d.keyboard = wl_seat.get_keyboard(d.seat);
                wl_proxy.set_user_data(d.keyboard, d);
                wl_keyboard.add_listener(d.keyboard, *keyboard_listenter, d);

                maybe_init_data_device(d);
            }
            case "zxdg_decoration_manager_v1"; {
                wl_jext_bind(*d.decoration_manager, registry, id, version);
            }
            case "wl_data_device_manager"; {
                wl_jext_bind(*d.data_device_manager, registry, id, version);
                maybe_init_data_device(d);
            }
            case "wp_viewporter"; {
                wl_jext_bind(*d.viewporter, registry, id, version);
            }
            case "wp_fractional_scale_manager_v1"; {
                wl_jext_bind(*d.fractional_scale_manager, registry, id, version);
            }
        }
    },

    global_remove = (data: *void, self: *wl_registry, name: u32) -> void #c_call {
        // @TODO - we should probably implement this
    }
};

data_offer_listener :: wl_data_offer_listener.{
    offer = (data: *void, self: *wl_data_offer, mime_type: *u8) -> void #c_call {
        ctx: Context;
        push_context ctx {
            d : *WLDisplay = wl_proxy.get_user_data(self);
            mime_s := to_string(mime_type);
            array_add(*d.data_offer_mime_types, copy_string(mime_s));
        }
    },
};

data_device_listener :: wl_data_device_listener.{
    data_offer = (data: *void, self: *wl_data_device, id: *wl_data_offer) -> void #c_call {
        ctx: Context;
        push_context ctx {
            d : *WLDisplay = wl_proxy.get_user_data(self);

            for d.data_offer_mime_types free(it);
            array_reset_keeping_memory(*d.data_offer_mime_types);

            d.data_offer = id;

            wl_data_offer.add_listener(id, *data_offer_listener, null);
            wl_proxy.set_user_data(id, d);
        }
    },

    enter = (data: *void, self: *wl_data_device, serial: u32, surface: *wl_surface,
        x: wl_fixed_t, y: wl_fixed_t, id: *wl_data_offer) -> void #c_call
    {
        ctx: Context;
        push_context ctx {
            d: *WLDisplay = wl_proxy.get_user_data(self);
            has_file_list := data_offer_has_mime_type(d, MIME_TYPE_FILE_LIST);

            if !id return;

            d.data_offer = id;

            ld_win := get_by_native_handle(surface);
            assert(ld_win != null);

            d.drop_target = isa(ld_win, WLWindow);
            d.drop_serial = serial;

            d.drop_target.dnd_x = wl_fixed_to_int(x);
            d.drop_target.dnd_y = wl_fixed_to_int(y);

            wl_data_offer.accept(d.data_offer, serial,
                ifx has_file_list then MIME_TYPE_FILE_LIST.data else null);

            if wl_data_offer.get_version(d.data_offer) >= 3 {
                action := wl_data_device_manager.dnd_action_none;
                if has_file_list action = wl_data_device_manager.dnd_action_copy;
                wl_data_offer.set_actions(d.data_offer, action, action);
            }
        }
    },

    leave = (data: *void, self: *wl_data_device) -> void #c_call {
        ctx: Context;
        push_context ctx {
            d: *WLDisplay = wl_proxy.get_user_data(self);
            data_offer_reset(d);
        }
    },

    motion = (data: *void, self: *wl_data_device, time: u32, x: wl_fixed_t, y: wl_fixed_t) -> void #c_call {
        ctx: Context;
        push_context ctx {
            d: *WLDisplay = wl_proxy.get_user_data(self);

            if !d.data_offer return;

            d.drop_target.dnd_x = wl_fixed_to_int(x);
            d.drop_target.dnd_y = wl_fixed_to_int(y);
        }
    },

    drop = (data: *void, self: *wl_data_device) -> void #c_call {
        ctx: Context;
        push_context ctx {
            d: *WLDisplay = wl_proxy.get_user_data(self);

            if !d.data_offer return;

            data: [..]u8;
            data_offer_read_data(d, MIME_TYPE_FILE_LIST, *data);

            wl_data_offer.finish(d.data_offer);
            wl_display.flush(d.handle);

            data_offer_reset(d);

            {
                /*
                 * @TODO: This snippet is copy-pasted verbatim from the X11 code. Needs cleanup
                 */
                files: [..] string;
                p := "";
                p.data = data.data;
                p.count = data.count;
                while true {
                    i := find_index_from_left(p, "\r\n");
                    if i == -1  break;

                    file_name := "";
                    file_name_bytes := cast(*u8) alloc(i, __temporary_allocator);
                    memcpy(file_name_bytes, p.data, i);
                    p.data = p.data + i + 2;
                    p.count = p.count - i - 2;

                    file_name.data = file_name_bytes;
                    file_name.count = i;
                    if begins_with(file_name, "file://") {
                        file_name = advance(file_name, 7);
                    }
                    array_add(*files, file_name);
                }

                event: Input.Event;
                event.type = .DRAG_AND_DROP_FILES;
                event.files = files;
                array_add(*events_this_frame, event);

                array_reset(*data);
            }
        }
    },

    selection = (data: *void, self: *wl_data_device, id: *wl_data_offer) -> void #c_call {
        ctx: Context;
        push_context ctx {
            d : *WLDisplay = wl_proxy.get_user_data(self);

            if !d.data_offer return;

            reset(*d.current_text_selection);
            data_offer_read_data(d, MIME_TYPE_TEXT, *d.current_text_selection);
            data_offer_reset(d);
        }
    }
};

wl_clipboard_get_text :: (d: *WLDisplay) -> string {
    return builder_to_string(*d.current_text_selection, do_reset = false);
}

data_source_listener :: wl_data_source_listener.{
    send = (data: *void, self: *wl_data_source, mime_type: *u8, fd: s32) -> void #c_call {
        ctx: Context;
        push_context ctx {
            defer close(fd);
            d: *WLDisplay = wl_proxy.get_user_data(self);
            if MIME_TYPE_TEXT != to_string(mime_type) return;
            write(fd, d.clipboard_send_data.data, xx d.clipboard_send_data.count);
        }
    }
};

wl_clipboard_set_text :: (d: *WLDisplay, text: string) {
    if d.clipboard_source {
        wl_data_source.destroy(d.clipboard_source);
        free(d.clipboard_send_data);
    }

    d.clipboard_send_data = copy_string(text);
    d.clipboard_source = wl_data_device_manager.create_data_source(d.data_device_manager);
    wl_data_source.add_listener(d.clipboard_source, *data_source_listener, null);
    wl_proxy.set_user_data(d.clipboard_source, d);

    wl_data_source.offer(d.clipboard_source, MIME_TYPE_TEXT.data);
    wl_data_source.offer(d.clipboard_source, MIME_TYPE_TEXT_NOLOOP.data);

    wl_data_device.set_selection(d.data_device, d.clipboard_source, d.input_serial);
}

wl_init_display :: (display: LDDisplay) -> bool {
    wl_global_init();

    set(display, WLDisplay.{});
    d := isa(display, WLDisplay);

    d.handle = wl_display.connect(null);
    if !d.handle return false;
    wl_proxy.set_user_data(d.handle, d);

    d.registry = wl_display.get_registry(d.handle);
    wl_registry.add_listener(d.registry, *registry_listener, d);

    wl_display.roundtrip(d.handle);
    wl_display.roundtrip(d.handle);

    init_string_builder(*d.current_text_selection);

    cursor_theme_name := getenv("XCURSOR_THEME");
    init(*d.cursors);
    d.cursor_theme = wl_cursor_theme.load(cursor_theme_name, 24, d.shm);
    for 0..d.cursor_theme.cursor_count - 1 {
        native := d.cursor_theme.cursors[it];
        cursor := WLCursor.{
            name = to_string(native.name),
            native = native,
        };
        array_reserve(*cursor.surfaces, native.image_count);
        for 0..native.image_count - 1 {
            surface := wl_compositor.create_surface(d.compositor);
            image := native.images[it];
            buffer := wl_cursor_image.get_buffer(image);
            wl_surface.attach(surface, buffer, 0, 0);
            wl_surface.damage(surface, 0, 0, xx image.width, xx image.height);
            wl_surface.commit(surface);
            array_add(*cursor.surfaces, surface);
        }
        table_add(*d.cursors, cursor.name, cursor);
    }

    d.key_repeat_timer = timer_create(cb = wl_key_repeat_cb, user_data = d);

    return true;
}

wl_uninit_display :: (display: LDDisplay) {
    d := isa(display, WLDisplay);
    if d.handle {
        // @TODO: more thorough cleanup here
        wl_display.disconnect(d.handle);
        <<d = .{};
    }
}

x_window_listener :: xdg_surface_listener.{
    configure = (data: *void, surface: *xdg_surface, serial: u32) -> void #c_call {
        w: *WLWindow = wl_proxy.get_user_data(surface);
        xdg_surface.ack_configure(surface, serial);
    }
};

x_toplevel_listener :: xdg_toplevel_listener.{
    configure = (data: *void, toplevel: *xdg_toplevel, width: s32, height: s32, states: *wl_array) -> void #c_call {
        ctx: Context;
        push_context ctx {
            w: *WLWindow = wl_proxy.get_user_data(toplevel);

            if !w.x_toplevel_configured {
                w.x_toplevel_configured = true;

                if w.pre_configure_desired_state == {
                    case .FULLSCREEN; wl_toggle_fullscreen(w, true, null);
                    case .MAXIMIZED; wl_maximize_window(w);
                }
                w.pre_configure_desired_state = .NONE;

                return;
            }

            wl_window_handle_resize(w, width, height);

        }
    },
    close = (data: *void, toplevel: *xdg_toplevel) -> void #c_call {
        ctx: Context;
        push_context ctx {
            event: Input.Event;
            event.type = .QUIT;
            array_add(*events_this_frame, event);
        }
    },
};

wl_window_handle_resize :: (w: *WLWindow, width: s32, height: s32) {
    w.window_width  = ifx !width then w.creation_width else width;
    w.window_height = ifx !height then w.creation_height else height;

    window_calculate_buffer_size(w);
    wl_window_resize_viewport(w);

    if w.egl_native  wl_egl_window.resize(w.egl_native, w.buffer_width, w.buffer_height, 0, 0);

    wl_surface.damage(w.handle, 0, 0, w.window_width, w.window_height);
    wl_surface.commit(w.handle);

    Input.add_resize_record(xx w.wrapper, xx w.buffer_width, xx w.buffer_height);
}

wl_get_dpi_scaling_factor :: (w: *WLWindow) -> float {
    fractional_scale := ifx w.display.fixed_scaling then w.display.scale_factor_override else w.fractional_scale;
    ret := cast(float) fractional_scale / 120.0;
    return ret;
}

fractional_scale_listener :: wp_fractional_scale_v1_listener.{
    preferred_scale = (data: *void, self: *wp_fractional_scale_v1, scale: u32) -> void #c_call {
        ctx: Context;
        push_context ctx {
            w : *WLWindow = data;
            w.fractional_scale = xx scale;
            wl_window_handle_resize(w, w.window_width, w.window_height);
        }
    }
};

wl_create_window :: (d: *WLDisplay, ld_win: LDWindow, width: int, height: int, window_name: string,
    window_x: int, window_y: int, x11_parent: *WLWindow, background_color_rgb: [3]float) -> bool
{
    set(ld_win, WLWindow.{});
    w := isa(ld_win, WLWindow);

    w.wrapper = ld_win;
    w.display = d;

    w.title = copy_string(window_name);

    w.creation_width = xx width;
    w.creation_height = xx height;

    w.window_width = xx width;
    w.window_height = xx height;
    window_calculate_buffer_size(w);

    cursor, found := table_find(*d.cursors, "default");
    if !found {
        for d.cursors {
            cursor = it;
            break;
        }
    }
    w.cursor = cursor;

    w.handle = wl_compositor.create_surface(d.compositor);
    wl_proxy.set_user_data(w.handle, w);

    w.x_surface = xdg_wm_base.get_xdg_surface(d.wm_base, w.handle);
    xdg_surface.add_listener(w.x_surface, *x_window_listener, w);
    wl_proxy.set_user_data(w.x_surface, w);

    w.x_toplevel = xdg_surface.get_toplevel(w.x_surface);
    xdg_toplevel.add_listener(w.x_toplevel, *x_toplevel_listener, w);
    xdg_toplevel.set_title(w.x_toplevel, window_name.data);
    xdg_toplevel.set_app_id(w.x_toplevel, temp_c_string(global_app_id));
    wl_proxy.set_user_data(w.x_toplevel, w);

    if d.decoration_manager {
        w.decoration = zxdg_decoration_manager_v1.get_toplevel_decoration(d.decoration_manager, w.x_toplevel);
        zxdg_toplevel_decoration_v1.set_mode(w.decoration, zxdg_toplevel_decoration_v1.mode_server_side);
    }

    w.viewport = wp_viewporter.get_viewport(d.viewporter, w.handle);
    if d.fractional_scale_manager {
        w.fractional_scale_proxy = wp_fractional_scale_manager_v1.get_fractional_scale(
            d.fractional_scale_manager, w.handle);
        wp_fractional_scale_v1.add_listener(w.fractional_scale_proxy, *fractional_scale_listener, w);
    }

    wl_window_resize_viewport(w);

    wl_surface.damage(w.handle, 0, 0, w.window_width, w.window_height);
    wl_surface.commit(w.handle);

    return true;
}

wl_set_cursor_from_theme :: (w: *WLWindow, name: string) {
    cursor, found := table_find(*w.display.cursors, name);
    if found {
        w.cursor = cursor;
        refresh_cursor(w);
    }
}

frame_listener :: wl_callback_listener.{
    done = (data: *void, callback: *wl_callback, time: u32) -> void #c_call {
        w: *WLWindow = data;
        if callback wl_callback.destroy(callback);
        w.callback = wl_surface.frame(w.handle);
        wl_callback.add_listener(w.callback, *frame_listener, w);
        wl_surface.commit(w.handle);
    }
};

wl_setup_frame_updates :: (w: *WLWindow) {
    if w.callback wl_callback.destroy(w.callback);
    w.callback = wl_surface.frame(w.handle);
    wl_callback.add_listener(w.callback, *frame_listener, w);
    wl_surface.commit(w.handle);
}

wl_has_native_handle :: (w: *WLWindow, native_handle: *wl_surface) -> bool {
    return w.handle == native_handle;
}

wl_get_dimensions :: (w: *WLWindow, right_handed: bool) -> (x: s32, y: s32, width: s32, height: s32, success := true) {
    return 0, 0, w.window_width, w.window_height, true;
}

wl_get_render_dimensions :: (w: *WLWindow) -> s32, s32 {
    return w.buffer_width, w.buffer_height;
}

wl_toggle_fullscreen :: (w: *WLWindow, desire_fullscreen: bool, _unused: *void) -> bool, s32, s32 {
    if !w.x_toplevel_configured {
        w.pre_configure_desired_state = .FULLSCREEN;
        return false, w.window_width, w.window_height;
    }
    if desire_fullscreen xdg_toplevel.set_fullscreen(w.x_toplevel, null);
    else xdg_toplevel.unset_fullscreen(w.x_toplevel);
    wl_display.roundtrip(w.display.handle);
    return true, w.window_width, w.window_height;
}

wl_maximize_window :: (w: *WLWindow) {
    if !w.x_toplevel_configured {
        w.pre_configure_desired_state = .MAXIMIZED;
        return;
    }
    xdg_toplevel.set_maximized(w.x_toplevel);
}

wl_enable_dnd :: (w: *WLWindow, typelist: []string) {
}

wl_set_window_title :: (w: *WLWindow, title: string) {
    win_title := to_c_string(title);
    xdg_toplevel.set_title(w.x_toplevel, win_title);
    free(win_title);
}

wl_set_fixed_scaling :: (d: *WLDisplay, factor: float) {
    fixed_scaling := (factor != 0.0);
    new_value: s32 = xx (factor * 120.0);

    if ((fixed_scaling != d.fixed_scaling) || (fixed_scaling && (new_value != d.scale_factor_override))) && (factor >= 0.0) {
        d.fixed_scaling = fixed_scaling;
        if fixed_scaling d.scale_factor_override = new_value;
        for global_windows {
            w := isa(it, WLWindow);
            wl_window_handle_resize(w, w.window_width, w.window_height);
        }
    }
}

#scope_file

DATA_OFFER_READ_SIZE :: 2048;

data_offer_reset :: (d: *WLDisplay) {
    if d.data_offer {
        wl_data_offer.destroy(d.data_offer);
        d.data_offer = null;
    }

    d.drop_target = null;
    d.drop_serial = 0;
}

data_offer_has_mime_type :: (d: *WLDisplay, mime: string) -> bool {
    for d.data_offer_mime_types {
        if it == mime return true;
    }
    return false;
}

data_offer_read_data :: (d: *WLDisplay, mime_type: string, sb: *String_Builder) {
    if data_offer_has_mime_type(d, MIME_TYPE_TEXT_NOLOOP) {
        /* Do not block on read when we're the source of clipboard data */
        if mime_type == MIME_TYPE_TEXT append(sb, d.clipboard_send_data);
        return;
    }

    pipe: [2]s32;
    pipe2(*pipe, O_CLOEXEC);

    /*
     * EXTREMELY important:
     *    we want to `wl_display.flush()` after `wl_data_offer.receive()` NOT `wl_display.roundtrip()`.
     *    `wl_display.roundtrip()` invokes callbacks in the middle of other callbacks which totally messes
     *    with the expected order of events.
     */
    wl_data_offer.receive(d.data_offer, mime_type.data, pipe[1]);
    wl_display.flush(d.handle);
    close(pipe[1]);

    ptr := ensure_contiguous_space(sb, DATA_OFFER_READ_SIZE);
    count := read(pipe[0], ptr, DATA_OFFER_READ_SIZE);
    while count > 0 {
        advance_through_ensured_space(sb, count);
        ptr = ensure_contiguous_space(sb, DATA_OFFER_READ_SIZE);
        count = read(pipe[0], ptr, DATA_OFFER_READ_SIZE);
    }

    close(pipe[0]);
}

data_offer_read_data :: (d: *WLDisplay, mime_type: string, dst: *[..]u8) {
    if data_offer_has_mime_type(d, MIME_TYPE_TEXT_NOLOOP) {
        /* Do not block on read when we're the source of clipboard data */
        if mime_type == MIME_TYPE_TEXT {
            old_count := dst.count;
            array_resize(dst, old_count + d.clipboard_send_data.count, false);
            memcpy(dst.data + old_count, d.clipboard_send_data.data, d.clipboard_send_data.count);
        }
        return;
    }

    pipe: [2]s32;
    pipe2(*pipe, O_CLOEXEC);

    /*
     * EXTREMELY important:
     *    we want to `wl_display.flush()` after `wl_data_offer.receive()` NOT `wl_display.roundtrip()`.
     *    `wl_display.roundtrip()` invokes callbacks in the middle of other callbacks which totally messes
     *    with the expected order of events.
     */
    wl_data_offer.receive(d.data_offer, mime_type.data, pipe[1]);
    wl_display.flush(d.handle);
    close(pipe[1]);

    buff: [4096]u8;
    count := read(pipe[0], buff.data, buff.count);
    while count > 0 {
        old_count := dst.count;
        array_resize(dst, old_count + count, false);
        memcpy(dst.data + old_count, buff.data, count);
        count = read(pipe[0], buff.data, buff.count);
    }

    close(pipe[0]);
}

states_to_string :: (arr: *wl_array) -> string {
    sb: String_Builder;
    init_string_builder(*sb);

    append(*sb, "[");
    for wl_array_each(u32, arr) {
        if it_index append(*sb, ", ");
        if <<it == {
            case xdg_toplevel.state_maximized; append(*sb, "maximized");
            case xdg_toplevel.state_fullscreen; append(*sb, "fullscreen");
            case xdg_toplevel.state_resizing; append(*sb, "resizing");
            case xdg_toplevel.state_activated; append(*sb, "activated");
            case xdg_toplevel.state_tiled_left; append(*sb, "tiled_left");
            case xdg_toplevel.state_tiled_right; append(*sb, "tiled_right");
            case xdg_toplevel.state_tiled_top; append(*sb, "tiled_top");
            case xdg_toplevel.state_tiled_bottom; append(*sb, "tiled_bottom");
            case; print_to_builder(*sb, "unknown(%)", <<it);
        }
    }
    append(*sb, "]");

    return builder_to_string(*sb);
}
