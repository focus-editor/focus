#scope_module

XCB_Display :: struct {
    #as base: Base_Display;

    xlib_dpy: *X11.Display;
    handle: *xcb_connection_t;
    screen: *xcb_screen_t;
    xi_initialized: bool;
    xi_ext_opcode: u8;
    xkb_event_base: u8;
    file_descriptor: s32;
    max_request_length: int;

    cursors: Table(string, xcb_cursor_t);

    cliboard_blocking_tranfser_ongoing: bool;
    clipboard_window: xcb_window_t;
    clipboard_incoming_data: string;        // from the outside to us
    clipboard_large_incoming_tranfer: bool; // incoming data is slip over multiple PropertyNotify events
    clipboard_incoming_in_flight_data: String_Builder;  // buffer for incoming data from multiple PropertyNotify events

    clipboard_outgoing_data: string;   // from us to the outside

    fixed_scaling: bool;
    dpi_override: float;

    atom_names: Table(xcb_atom_t, string);
    global_atoms: struct {
        INCR: xcb_atom_t;
        CLIPBOARD: xcb_atom_t;
        FOCUS_EDITOR_SELECTION_DATA: xcb_atom_t;     @create
        TARGETS: xcb_atom_t;                         @create
        WM_PROTOCOLS: xcb_atom_t;
        WM_DELETE_WINDOW: xcb_atom_t;

        _NET_WM_ICON: xcb_atom_t;
        _NET_WM_STATE: xcb_atom_t;
        _NET_WM_STATE_MAXIMIZED_VERT: xcb_atom_t;
        _NET_WM_STATE_MAXIMIZED_HORZ: xcb_atom_t;
        _NET_WM_STATE_FULLSCREEN: xcb_atom_t;
        _NET_WM_NAME: xcb_atom_t;
        _NET_WM_ICON_NAME: xcb_atom_t;

        UTF8_STRING: xcb_atom_t;                     @create
    }

    devices: Table(xcb_input_device_id_t, *XCB_Device_Info);

    pending_event: *xcb_generic_event_t;

    currently_hovered_window: *XCB_Window;
}

XCB_Window :: struct {
    #as base: Base_Window;

    display: *XCB_Display;
    handle: u32;
}

xcb_init_display :: (display: *Display) -> bool {
    if !load_procs(*xcb,        .["libxcb.so.1",        "libxcb.so"       ], "xcb_",        *xcb_loaded)        return false;
    if !load_procs(*xcb_xkb,    .["libxcb-xkb.so.1",    "libxcb-xkb.so"   ], "xcb_xkb_",    *xcb_xkb_loaded)    return false;
    if !load_procs(*xcb_cursor, .["libxcb-cursor.so.0", "libxcb-cursor.so"], "xcb_cursor_", *xcb_cursor_loaded) return false;
    if !load_procs(*xcb_icccm,  .["libxcb-icccm.so.4",  "libxcb-icccm.so" ], "xcb_icccm_",  *xcb_icccm_loaded)  return false;

    if !xkbcommon_load(init_xcb_compat=true) return false;

    xd := XCB_Display.{ base = display.base };
    xd.base.type                       = XCB_Display;
    xd.base.create_window              = xcb_create_window;
    xd.base.set_fixed_scaling          = xcb_set_fixed_scaling;
    xd.base.translate_key_code         = x11_translate_key_code;
    xd.base.wait_for_events            = xcb_wait_for_events;
    xd.base.update_window_events       = xcb_update_window_events;
    xd.base.clipboard_set_text         = xcb_clipboard_set_text;
    xd.base.clipboard_get_text         = xcb_clipboard_get_text;
    xd.base.get_mouse_pointer_position = xcb_get_mouse_pointer_position;

    if display.base.init_flags & .XCB_Pure {
        log("XCB: initializing with pure xcb connection");
        xd.handle = xcb.connect(null, null);
    } else {
        log("XCB: initializing with Xlib connection");

        if !xlib_load(*X11, init_xcb_compat=true) return false;

        xd.xlib_dpy = X11.XOpenDisplay(null);
        if !xd.xlib_dpy {
            log_error("Failed to connect to X server");
            return false;
        }

        X11.XSetEventQueueOwner(xd.xlib_dpy, .XCB);

        xd.handle = X11.XGetXCBConnection(xd.xlib_dpy);
    }
    if !xd.handle {
        log_error("Cannot get xcb connection to X server");
        return false;
    }

    xd.screen = xcb.setup_roots_iterator(xcb.get_setup(xd.handle)).data;

    xd.file_descriptor = xcb.get_file_descriptor(xd.handle);

    xd.max_request_length = xcb.get_maximum_request_length(xd.handle);
    log("XCB: max_request_length=%", xd.max_request_length);

    if !(display.base.init_flags & .XCB_Force_Core_Events) && load_procs(*xcb_input, .["libxcb-xinput.so.0", "libxcb-xinput.so"], "xcb_input_", *xcb_xinput_loaded) {
        xi_ext := xcb.get_extension_data(xd.handle, xcb_input.id);
        if !xi_ext || (xi_ext && !xi_ext.present) {
            log_error("XCB: XInput extenstion not available");
            xd.xi_initialized = false;
        } else {
            xd.xi_initialized = true;
            xd.xi_ext_opcode = xi_ext.major_opcode;
        }
    } else {
        if display.base.init_flags & .XCB_Force_Core_Events {
            log("XCB: input handling via core events forced");
        } else {
            log("XCB: xcb-xinput failed to load, falling back to core events for input handling");
        }
        xd.xi_initialized = false;
    }

    xkb_ext := xcb.get_extension_data(xd.handle, xcb_xkb.id);
    if !xkb_ext || !xkb_ext.present {
        log_error("XKB extension not available");
        return false;
    }

    xkb_ver_major : u16 = 1;
    xkb_ver_minor : u16 = 0;
    xkb_event_base : u8;
    if !xkb_x11_setup_xkb_extension(xd.handle, xkb_ver_major, xkb_ver_minor, 0, *xkb_ver_major, *xkb_ver_minor, *xkb_event_base, null) {
        log_error("Failed to set up XKB extension");
        return false;
    }
    xd.xkb_event_base = xkb_event_base;
    log("XCB: xcb-xkb version %.%", xkb_ver_major, xkb_ver_minor);

    affect := xcb_xkb_event_type_t.NEW_KEYBOARD_NOTIFY | .MAP_NOTIFY | .STATE_NOTIFY;
    map_parts := xcb_xkb_map_part_t.KEY_TYPES | .KEY_SYMS | .MODIFIER_MAP | .EXPLICIT_COMPONENTS | .KEY_ACTIONS | .VIRTUAL_MODS | .VIRTUAL_MOD_MAP;
    state_parts := xcb_xkb_state_part_t.MODIFIER_BASE | .MODIFIER_LATCH | .MODIFIER_LOCK | .GROUP_BASE | .GROUP_LATCH | .GROUP_LOCK;
    details := xcb_xkb_select_events_details_t.{
        affectNewKeyboard = .KEYCODES,
        newKeyboardDetails = .KEYCODES,
        affectState = state_parts,
        stateDetails = state_parts,
    };
    core := xkb_x11_get_core_keyboard_device_id(xd.handle);
    xcb_xkb.select_events_aux(xd.handle, xx core, affect, 0, 0, map_parts, map_parts, *details);

    tis := cast(*Type_Info_Struct) type_of(xd.global_atoms);
    assert(tis.type == .STRUCT);

    init(*xd.atom_names);
    info: [..] struct {
        cookie: xcb_intern_atom_cookie_t;
        atom: *xcb_atom_t;
        name: string;
    };
    array_reserve(*info, tis.members.count);
    for m : tis.members {
        should_create, _ := array_find(m.notes, "create");
        if m.type != type_info(xcb_atom_t) continue;
        array_add(*info, .{
            cookie = xcb.intern_atom(xd.handle, xx !should_create, xx m.name.count, m.name.data),
            atom = cast(*xcb_atom_t)(cast(*u8) *xd.global_atoms + m.offset_in_bytes),
            name = m.name,
        });
    }
    for i : info {
        error: *xcb_generic_error_t;
        reply := xcb.intern_atom_reply(xd.handle, i.cookie, *error);
        if !reply {
            if error  log_error("intern_atom_reply(): %", error.*);
            continue;
        }

        /* NOTE: we may want to check for `reply.atom == 0` */
        i.atom.* = reply.atom;
        libc_free(reply);

        table_add(*xd.atom_names, i.atom.*, i.name);
    }

    xd.clipboard_window = xcb.generate_id(xd.handle);
    prop_mask := xcb_cw_t.EVENT_MASK;
    prop_list := u32.[xx (xcb_event_mask_t.PROPERTY_CHANGE)];
    xcb.create_window_checked(
        c=xd.handle,
        depth=XCB_COPY_FROM_PARENT,
        wid=xd.clipboard_window,
        parent=xd.screen.root,
        x=0, y=0, width=1, height=1, border_width=1,
        _class=.XCB_WINDOW_CLASS_INPUT_OUTPUT,
        visual=xd.screen.root_visual,
        value_mask=prop_mask,
        value_list=prop_list.data,
    );

    xd.clipboard_incoming_data = copy_string("");
    xd.clipboard_outgoing_data = copy_string("");

    init(*xd.devices);
    init(*xd.cursors);

    if !ld_xkb_state_init(*xd, xd.handle) return false;
    if !load_cursors(*xd) return false;

    create_gl_context(cast(*Display) *xd);

    display.xcb = xd;
    return true;
}

xcb_create_window :: (display: *Display, window: *Window, width: int, height: int, window_name: string,
    window_x: int, window_y: int, parent: *Window, background_color_rgb: [3]float) -> bool
{
    xd : *XCB_Display = display;

    xw := XCB_Window.{ base = window.base, display = xd };
    xw.base.type                       = XCB_Window;
    xw.base.display                    = display;
    xw.base.set_icon_from_raw_data     = xcb_set_icon_from_raw_data;
    xw.base.toggle_fullscreen          = xcb_toggle_fullscreen;
    xw.base.has_native_handle          = xcb_has_native_handle;
    xw.base.get_dimensions             = xcb_get_dimensions;
    xw.base.get_render_dimensions      = xcb_get_render_dimensions;
    xw.base.get_mouse_pointer_position = xcb_get_mouse_pointer_position;
    xw.base.enable_dnd                 = xcb_enable_dnd;
    xw.base.set_window_title           = xcb_set_window_title;
    xw.base.maximize_window            = xcb_maximize_window;
    xw.base.set_cursor_from_theme      = xcb_set_cursor_from_theme;
    xw.base.get_dpi_scaling_factor     = xcb_get_dpi_scaling_factor;

    event_mask := xcb_event_mask_t.EXPOSURE | .STRUCTURE_NOTIFY | .FOCUS_CHANGE | .ENTER_WINDOW | .LEAVE_WINDOW;
    if !xd.xi_initialized event_mask |= .KEY_PRESS | .KEY_RELEASE | .BUTTON_PRESS | .BUTTON_RELEASE;
    prop_mask := xcb_cw_t.BACK_PIXEL | .EVENT_MASK;
    prop_list := u32.[xd.screen.black_pixel, xx event_mask];

    xw.handle = xcb.generate_id(xd.handle);
    xcb.create_window_checked(
        c=xd.handle,
        depth=XCB_COPY_FROM_PARENT,
        wid=xw.handle,
        parent=xd.screen.root,
        x=0, y=0, width=xx width, height=xx height, border_width=1,
        _class=.XCB_WINDOW_CLASS_INPUT_OUTPUT,
        visual=xd.screen.root_visual,
        value_mask=prop_mask,
        value_list=prop_list.data,
    );

    xcb.change_property(
        xd.handle,
        .REPLACE,
        xw.handle,
        xd.global_atoms.WM_PROTOCOLS,
        xx xcb_atom_enum_t.ATOM,
        32, 1, *xd.global_atoms.WM_DELETE_WINDOW);

    class_sz := tprint("%\0%\0", ifx window_name then window_name else "jai-application", display.base.app_id);
    xcb.change_property(
        xd.handle,
        .REPLACE,
        xw.handle,
        xx xcb_atom_enum_t.WM_CLASS,
        xx xcb_atom_enum_t.STRING,
        8, xx class_sz.count, class_sz.data);
    xcb_set_window_title(xx *xw, window_name);

    if xd.xi_initialized {
        mask: struct {
            using #as hdr: xcb_input_event_mask_t;
            data: [8]xcb_input_xi_event_mask_t;
        }

        mask.deviceid = xx xcb_input_device_t.ALL_MASTER;
        mask.mask_len = 1;
        mask.data[0]  = .KEY_PRESS | .KEY_RELEASE | .BUTTON_PRESS | .BUTTON_RELEASE;
        xi_cookie := xcb_input.xi_select_events(xd.handle, xw.handle, 1, *mask);
        xcb_err := xcb.request_check(xd.handle, xi_cookie);
        if xcb_err  log_error("Failed to select input events on WID %: %", xw.handle, xcb_err.*);

        mask.deviceid = xx xcb_input_device_t.ALL;
        mask.mask_len = 1;
        mask.data[0]  = .DEVICE_CHANGED | .HIERARCHY;
        xi_cookie = xcb_input.xi_select_events(xd.handle, xw.handle, 1, *mask);
        xcb_err = xcb.request_check(xd.handle, xi_cookie);
        if xcb_err  log_error("Failed to select devoce events on WID %: %", xw.handle, xcb_err.*);

        mask.deviceid = xx xcb_input_device_t.ALL;
        mask.mask_len = 1;
        mask.data[0]  = .RAW_MOTION;
        xi_cookie = xcb_input.xi_select_events(xd.handle, xd.screen.root, 1, *mask);
        xcb_err = xcb.request_check(xd.handle, xi_cookie);
        if xcb_err  log_error("Failed to select input events on root WID %: %", xd.screen.root, xcb_err.*);
    }

    hints: xcb_size_hints_t;
    xcb_icccm.size_hints_set_min_size(*hints, 100, 100);
    xcb_icccm.set_wm_size_hints(xd.handle, xw.handle, xx xcb_atom_enum_t.WM_NORMAL_HINTS, *hints);

    xcb.map_window(xd.handle, xw.handle);
    xcb.flush(xd.handle);

    create_gl_surface(cast(*Window) *xw);

    window.xcb = xw;

    return true;
}

xcb_set_fixed_scaling :: (display: *Display, factor: float) {
    xcb_check_usage(display, null);

    xd : *XCB_Display = display;

    xd.fixed_scaling = (factor >= 0.1);
    xd.dpi_override = factor * 96.0;
    for * xd.base.windows {
        _, _, w, h, _ := xcb_get_dimensions(it, false);
        Input.add_resize_record(xx it, w, h);
    }
}

xcb_wait_for_events :: (display: *Display) {
    xcb_check_usage(display, null);

    xd : *XCB_Display = display;

    while true {
        pfd: [3]pollfd;
        pfd[0].fd = xd.file_descriptor;
        pfd[0].events = POLLIN;
        pfd[1].fd = timers_epfd;
        pfd[1].events = POLLIN;
        pfd[2].fd = display.base.loop_wakeup_event;
        pfd[2].events = POLLIN;
        result := poll(pfd.data, xx pfd.count, -1);

        if result < 0 {
            error := errno();
            if error == EINTR continue;
            if error == EINVAL {
                log_error("Can't poll on xcb file descriptor. Max amount of opened file descriptors (RLIMIT_NOFILE) exceeded.");
            } else if error == ENOMEM {
                log_error("poll(2) failed with ENOMEM - it is unable to allocate memory for its internal use");
            } else if error == EFAULT {
                log_error("xcb poll is configured incorrectly - file descriptors are outside of the accessible address space");
            } else {
                log_error("Unknown error happened while waiting on xcb file descriptor. Error code: %", error);
            }
            return;
        }

        if pfd[2].revents & POLLIN {
            consume_loop_wakeup_event(display);
            break;
        }

        if pfd[1].revents & POLLIN {
            timers_tick();
            break;
        }

        if pfd[0].revents & POLLIN {
            assert(xd.pending_event == null);
            xd.pending_event = xcb.poll_for_event(xd.handle);
            if !xd.pending_event {
                xcb.flush(xd.handle);
                continue;
            }
            break;
        }
    }
}

xcb_update_window_events :: (display: *Display) {
    xcb_check_usage(display, null);

    xd: *XCB_Display = display;

    event: *xcb_generic_event_t;
    if xd.pending_event {
        event = xd.pending_event;
        xd.pending_event = null;
    } else {
        event = xcb.poll_for_event(xd.handle);
    }

    while event != null {
        defer event = xcb.poll_for_event(xd.handle);

        response_type := event.response_type & ~0x80;
        if response_type == xd.xkb_event_base {
            geev := cast(*xcb_generic_event_t) event;
            if geev.pad0 == {
                case XCB_XKB_NEW_KEYBOARD_NOTIFY; #through;
                case XCB_XKB_MAP_NOTIFY;
                    log("Reloading keyboard map");
                    ld_xkb_state_init(xd, xd.handle);

                case XCB_XKB_STATE_NOTIFY;
                    neev := cast(*xcb_xkb_state_notify_event_t) event;
                    ld_xkb_state_set_mods(xd,
                        neev.baseMods, neev.latchedMods, neev.lockedMods,
                        xx neev.baseGroup, xx neev.latchedGroup, xx neev.lockedGroup);
            }
        } else if response_type == {
            case XCB_CLIENT_MESSAGE;
                clev := cast(*xcb_client_message_event_t) event;
                if clev.data.data32[0] == xx xd.global_atoms.WM_DELETE_WINDOW {
                    ev: Input.Event;
                    ev.type = .QUIT;
                    array_add(*display.base.events_this_frame, ev);
                }

            case XCB_EXPOSE;
                xcb.flush(xd.handle); // ??

            case XCB_CONFIGURE_NOTIFY;
                cfev := cast(*xcb_configure_notify_event_t) event;
                ld_win := get_by_native_handle(display, xx cfev.window);
                if ld_win Input.add_resize_record(ld_win, cfev.width, cfev.height);

            case XCB_FOCUS_IN;
                Input.input_application_has_focus = true;
                array_add(*display.base.events_this_frame, .{type=.WINDOW});

            case XCB_FOCUS_OUT;
                Input.input_application_has_focus = false;
                array_add(*display.base.events_this_frame, .{type=.WINDOW});

            case XCB_ENTER_NOTIFY;
                enev := cast(*xcb_enter_notify_event_t) event;
                xd.currently_hovered_window = get_by_native_handle(display, xx enev.event);

            case XCB_LEAVE_NOTIFY;
                xd.currently_hovered_window = null;

            case XCB_GE_GENERIC;
                geev := cast(*xcb_ge_generic_event_t) event;
                if geev.extension == xd.xi_ext_opcode  handle_xinput_event(xd, geev);

            case XCB_KEY_PRESS; #through;
            case XCB_KEY_RELEASE;
                kpev := cast(*xcb_key_press_event_t) event;
                event_type := ifx response_type == XCB_KEY_PRESS then LD_XKB_Key_Event_Type.Press else .Release;
                ld_xkb_handle_key_event(xd, kpev.detail, event_type, false);

            case XCB_BUTTON_PRESS; #through;
            case XCB_BUTTON_RELEASE;
                bpev := cast(*xcb_button_press_event_t) event;
                event_type := ifx response_type == XCB_BUTTON_PRESS then Button_Event_Type.Press else .Release;
                handle_button_event(xd, .Core, bpev.detail, event_type);

            case XCB_SELECTION_NOTIFY;
                snev := cast(*xcb_selection_notify_event_t) event;
                log("EV: selection_notify(requestor=% (%), selection=% (%), target=% (%), property=% (% - %))",
                    snev.requestor, xd.clipboard_window,
                    atom_name(xd, snev.selection), snev.selection,
                    atom_name(xd, snev.target), snev.target,
                    atom_name(xd, snev.property), snev.property, xd.global_atoms.FOCUS_EDITOR_SELECTION_DATA);

                xd.clipboard_large_incoming_tranfer = false;

                if !snev.property || snev.requestor != xd.clipboard_window {
                    xd.cliboard_blocking_tranfser_ongoing = false;
                    continue;
                }

                xcb_err: *xcb_generic_error_t;
                cookie := xcb.get_property(xd.handle,
                    1,
                    snev.requestor,
                    xd.global_atoms.FOCUS_EDITOR_SELECTION_DATA,
                    xx xcb_atom_enum_t.ANY,
                    0, ~cast(u32)0);
                reply := xcb.get_property_reply(xd.handle, cookie, *xcb_err);
                defer libc_free(reply);

                if !reply {
                    log("get_property(): %", xcb_err.*);
                    continue;
                }

                log("  reply.type=% format=%", atom_name(xd, reply.type), reply.format);

                if reply.type == xd.global_atoms.UTF8_STRING && reply.format == 8 {
                    text: string;
                    text.data = xcb.get_property_value(reply);
                    text.count = xcb.get_property_value_length(reply);
                    log("CLIPBOARD DATA: '%'", text);

                    free(xd.clipboard_incoming_data);
                    xd.clipboard_incoming_data = copy_string(text);
                    xd.cliboard_blocking_tranfser_ongoing = false;
                } else if reply.type == xd.global_atoms.INCR && reply.format == 32 {
                    log("  large clipboard transfer initiated");
                    xd.clipboard_large_incoming_tranfer = true;
                    reset(*xd.clipboard_incoming_in_flight_data);
                }

            case XCB_PROPERTY_NOTIFY;
                pnev := cast(*xcb_property_notify_event_t) event;
                state := cast(xcb_property_t) pnev.state;
                log("property_notify(window=% atom=% state=%)", pnev.window, atom_name(xd, pnev.atom), state);

                if pnev.window != xd.clipboard_window || state != .NEW_VALUE || !xd.clipboard_large_incoming_tranfer {
                    continue;
                }

                xcb_err: *xcb_generic_error_t;
                cookie := xcb.get_property(xd.handle,
                    1,
                    xd.clipboard_window,
                    xd.global_atoms.FOCUS_EDITOR_SELECTION_DATA,
                    xx xcb_atom_enum_t.ANY,
                    0, ~cast(u32)0);
                reply := xcb.get_property_reply(xd.handle, cookie, *xcb_err);
                defer libc_free(reply);

                if !reply {
                    log_error("get_property(): %", xcb_err.*);
                    log("Resetting large clipboard data transfer");
                    xd.clipboard_large_incoming_tranfer = false;
                    reset(*xd.clipboard_incoming_in_flight_data);
                    continue;
                }

                if reply.type == xd.global_atoms.UTF8_STRING && reply.format == 8 {
                    text: string;
                    text.data = xcb.get_property_value(reply);
                    text.count = xcb.get_property_value_length(reply);
                    if !text {
                        log("Finished large clipboard transfer!");
                        free(xd.clipboard_incoming_data);
                        xd.clipboard_incoming_data = builder_to_string(*xd.clipboard_incoming_in_flight_data);
                        xd.clipboard_large_incoming_tranfer = false;
                        xd.cliboard_blocking_tranfser_ongoing = false;
                    } else {
                        append(*xd.clipboard_incoming_in_flight_data, text);
                        log("Added % bytes of clipboard data", text.count);
                    }
                }

            case XCB_SELECTION_REQUEST;
                srev := cast(*xcb_selection_request_event_t) event;
                log("selection_request(self.clipboard_window=% owner=% requestor=% selection=% target=% property=%)",
                    xd.clipboard_window, srev.owner, srev.requestor,
                    atom_name(xd, srev.selection),
                    atom_name(xd, srev.target),
                    atom_name(xd, srev.property));

                if srev.target == xd.global_atoms.TARGETS {
                    atoms := xcb_atom_t.[xd.global_atoms.UTF8_STRING, xd.global_atoms.TARGETS];
                    cookie := xcb.change_property(xd.handle, .REPLACE, srev.requestor, srev.property,
                        xx xcb_atom_enum_t.ATOM, 32, xx atoms.count, atoms.data);
                    xcb_err := xcb.request_check(xd.handle, cookie);
                    if xcb_err {
                        log_error("Failed to set property % on SelectionRequest(%).requestor=%: %",
                            atom_name(xd, srev.property),
                            atom_name(xd, srev.target),
                            srev.requestor,
                            xcb_err.*);
                        continue;
                    }
                } else if srev.target == xd.global_atoms.UTF8_STRING {
                    max_length := min(xd.max_request_length * 4 - 1024, xd.clipboard_outgoing_data.count);
                    cookie := xcb.change_property(xd.handle, .REPLACE, srev.requestor, srev.property,
                        srev.target, 8, xx max_length, xd.clipboard_outgoing_data.data);
                    xcb_err := xcb.request_check(xd.handle, cookie);
                    if xcb_err {
                        log_error("Failed to set property % on SelectionRequest(%).requestor=%: %",
                            atom_name(xd, srev.property),
                            atom_name(xd, srev.target),
                            srev.requestor,
                            xcb_err.*);
                        continue;
                    }
                }

                sel_notify := xcb_selection_notify_event_t.{
                    response_type = XCB_SELECTION_NOTIFY,
                    requestor = srev.requestor,
                    selection = srev.selection,
                    target = srev.target,
                    time = srev.time,
                    property = srev.property,
                };
                cookie := xcb.send_event(xd.handle, 1, srev.requestor, 0, xx *sel_notify);
                xcb_err := xcb.request_check(xd.handle, cookie);
                if xcb_err {
                    log_error("Failed to send SelectionNotify to requestor %: %",
                        srev.requestor,
                        xcb_err.*);
                    continue;
                }

            case;
                log(">> unhandled event: % %", event.response_type & ~0x80, event.*);
        }
    }
}

xcb_clipboard_set_text :: (display: *Display, text: string) {
    xd : *XCB_Display = display;
    free(xd.clipboard_outgoing_data);
    xd.clipboard_outgoing_data = copy_string(text);
    cookie  := xcb.set_selection_owner(xd.handle, xd.clipboard_window, xd.global_atoms.CLIPBOARD, XCB_CURRENT_TIME);
    xcb_err := xcb.request_check(xd.handle, cookie);
    if xcb_err log_error("Failed to set selection owner: %", xcb_err.*);
}

xcb_clipboard_get_text :: (display: *Display) -> string {
    xd : *XCB_Display = display;

    cookie := xcb.get_selection_owner(xd.handle, xd.global_atoms.CLIPBOARD);
    reply := xcb.get_selection_owner_reply(xd.handle, cookie, null);
    defer libc_free(reply);

    if reply.owner == xd.clipboard_window {
        return copy_string(xd.clipboard_outgoing_data);
    }

    void_cookie := xcb.convert_selection(xd.handle,
        xd.clipboard_window,
        xd.global_atoms.CLIPBOARD,
        xd.global_atoms.UTF8_STRING,
        xd.global_atoms.FOCUS_EDITOR_SELECTION_DATA,
        XCB_CURRENT_TIME);
    xcb_err := xcb.request_check(xd.handle, void_cookie);
    if xcb_err {
        log_error("convert_selection(): %", xcb_err.*);
    }

    xd.cliboard_blocking_tranfser_ongoing = true;
    start_time := seconds_since_init();
    now := seconds_since_init();
    while (now - start_time) < 5.0 && xd.cliboard_blocking_tranfser_ongoing {
        if !xd.pending_event  xd.pending_event = xcb.wait_for_event(xd.handle);
        xcb_update_window_events(display);
        now = seconds_since_init();
    }

    return copy_string(xd.clipboard_incoming_data);
}

xcb_get_mouse_pointer_position :: (display: *Display, right_handed := false) -> x: int, y: int, success: bool {
    xcb_check_usage(display, null);
    xd: *XCB_Display = display;

    cookie := xcb.query_pointer(xd.handle, xd.screen.root);
    reply  := xcb.query_pointer_reply(xd.handle, cookie, null);
    defer libc_free(reply);

    return reply.root_x, reply.root_y, true;
}

xcb_set_icon_from_raw_data :: (window: *Window, data: *u8, width: u32, height: u32) {
    xcb_check_usage(null, window);

    xw: *XCB_Window = window;
    xd: *XCB_Display = xw.display;

    size_data := u32.[width, height];
    xcb.change_property(
        xd.handle,
        .REPLACE,
        xw.handle,
        xd.global_atoms._NET_WM_ICON,
        xx xcb_atom_enum_t.CARDINAL,
        32, xx size_data.count, size_data.data);
    xcb.change_property(
        xd.handle,
        .APPEND,
        xw.handle,
        xd.global_atoms._NET_WM_ICON,
        xx xcb_atom_enum_t.CARDINAL,
        32, width * height, data);
}

xcb_toggle_fullscreen :: (window: *Window, desire_fullscreen: bool, saved: *Saved_Window_Info) -> success: bool, width: s32, height: s32 {
    xcb_check_usage(null, window);

    op : WM_State_Op = ifx desire_fullscreen then .ADD else .REMOVE;
    set_wm_state(window, op, window.xcb.display.global_atoms._NET_WM_STATE_FULLSCREEN);

    _, _, w, h, ok := xcb_get_dimensions(window, false);
    return ok, w, h;
}

xcb_has_native_handle :: (window: *Window, native_handle: *void) -> bool {
    xcb_check_usage(null, window);
    return window.xcb.handle == xx native_handle;
}

xcb_get_dimensions :: (window: *Window, right_handed: bool) -> (x: s32, y: s32, width: s32, height: s32, success := true) {
    xcb_check_usage(null, window);
    xw : *XCB_Window = window;
    cookie := xcb.get_geometry(xw.display.handle, xw.handle);
    geometry := xcb.get_geometry_reply(xw.display.handle, cookie, null);
    return 0, 0, xx geometry.width, geometry.height, true;
}

xcb_get_render_dimensions :: (window: *Window) -> s32, s32 {
    xcb_check_usage(null, window);
    _, _, w, h, ok := xcb_get_dimensions(window, false);
    if ok return w, h;
    return 1, 1;
}

xcb_get_mouse_pointer_position :: (window: *Window, right_handed: bool) -> x: int, y: int, success: bool {
    xcb_check_usage(null, window);
    xw : *XCB_Window = window;
    xd := xw.display;

    cookie := xcb.query_pointer(xd.handle, xw.handle);
    reply  := xcb.query_pointer_reply(xd.handle, cookie, null);

    return reply.win_x, reply.win_y, true;
}

xcb_enable_dnd :: (window: *Window, typelist: []string) {
    xcb_check_usage(null, window);
}

xcb_set_window_title :: (window: *Window, title: string) {
    xcb_check_usage(null, window);
    set_utf8_property(window, xx xcb_atom_enum_t.WM_NAME, title);
    set_utf8_property(window, xx xcb_atom_enum_t.WM_ICON_NAME, title);
    set_utf8_property(window, window.xcb.display.global_atoms._NET_WM_NAME, title);
    set_utf8_property(window, window.xcb.display.global_atoms._NET_WM_ICON_NAME, title);
}

xcb_maximize_window :: (window: *Window) {
    xcb_check_usage(null, window);
    set_wm_state(window, .ADD,
        window.xcb.display.global_atoms._NET_WM_STATE_MAXIMIZED_VERT,
        window.xcb.display.global_atoms._NET_WM_STATE_MAXIMIZED_HORZ);
}

xcb_set_cursor_from_theme :: (window: *Window, name: string) {
    xcb_check_usage(null, window);
    xw : *XCB_Window = window;
    xd := xw.display;
    cursor, found := table_find(*xd.cursors, name);
    if found {
        attrs: xcb_change_window_attributes_value_list_t;
        attrs.cursor = cursor;
        xcb.change_window_attributes_aux(xd.handle, xw.handle, .CURSOR, *attrs);
    }
}

xcb_get_dpi_scaling_factor :: (window: *Window) -> float {
    xcb_check_usage(null, window);

    xd := window.xcb.display;
    if xd.fixed_scaling return xd.dpi_override / 96.0;

    screen := xd.screen;
    return (cast(float) screen.width_in_pixels / (cast(float) screen.width_in_millimeters / 25.4)) / 96.0;
}

#scope_file
#import "Basic";
#import "Math";

#load "xcb_fp.jai";
#load "xcb_xinput_fp.jai";
#load "xcb_xkb_fp.jai";
#load "xcb_cursor_fp.jai";
#load "xcb_icccm_fp.jai";


/* we need this to free some stuff that the xcb libraries return */
libc :: #system_library "libc";
libc_free :: (ptr: *void) #foreign libc "free";

generic_c_call :: #type () #c_call;

xcb_loaded := false;
xcb_xinput_loaded := false;
xcb_xkb_loaded := false;
xcb_cursor_loaded := false;
xcb_icccm_loaded := false;

load_procs :: (procs: *$T, libnames: []string, prefix: $string, loaded: *bool) -> success := false {
    if loaded.* return true;

    loaded.* = false;
    for libname : libnames {
        dlerror();
        lib := dlopen(temp_c_string(libname), RTLD_NOW);
        if !lib {
            log_error("Failed to load %: %", libname, to_string(dlerror()));
            continue;
        }

        tis := cast(*Type_Info_Struct) type_info(T);
        for m : tis.members {
            dlerror();
            name := tprint("%1%2\0", prefix, m.name);
            if m.type.type == .PROCEDURE {
                if m.flags & .CONSTANT continue;

                pi := cast(*Type_Info_Procedure) m.type;
                if !(pi.procedure_flags & .IS_C_CALL) continue;

                ppfn := cast(*generic_c_call)((cast(*u8) procs) + m.offset_in_bytes);
                ppfn.* = cast(generic_c_call) dlsym(lib, name.data);
                if !ppfn.* {
                    log_error("Failed to resolve function '%' in '%': %", name, libname, to_string(dlerror()));
                    continue libname;
                }
            } else if m.type.type == .POINTER {
                ppv := cast(**void)((cast(*u8) procs) + m.offset_in_bytes);
                ppv.* = dlsym(lib, name.data);
            }
        }

        log("XCB: loaded %", libname);
        loaded.* = true;
        return true;
    }

    return false;
}

handle_xinput_event :: (xd: *XCB_Display, geev: *xcb_ge_generic_event_t) {
    if geev.event_type == {
        case XCB_INPUT_DEVICE_CHANGED;
            dcev := cast(*xcb_input_device_changed_event_t) geev;
            log("DEVICE CHANGED: %", dcev.*);

        case XCB_INPUT_HIERARCHY;
            hcev := cast(*xcb_input_hierarchy_event_t) geev;
            log("HIERARCHY: %", hcev.*);

        case XCB_INPUT_KEY_PRESS; #through;
        case XCB_INPUT_KEY_RELEASE;
            kpev := cast(*xcb_input_key_press_event_t) geev;
            event_type := ifx geev.event_type == XCB_INPUT_KEY_PRESS then LD_XKB_Key_Event_Type.Press else .Release;
            repeat := (kpev.flags & cast(u32) xcb_input_key_event_flags_t.XCB_INPUT_KEY_EVENT_FLAGS_KEY_REPEAT) != 0;
            ld_xkb_handle_key_event(xd, kpev.detail, event_type, repeat);

        case XCB_INPUT_BUTTON_PRESS; #through;
        case XCB_INPUT_BUTTON_RELEASE;
            bpev := cast(*xcb_input_device_button_press_event_t) geev;
            event_type := ifx geev.event_type == XCB_INPUT_BUTTON_PRESS then Button_Event_Type.Press else .Release;
            handle_button_event(xd, .XInput, bpev.child, event_type);

        case XCB_INPUT_RAW_MOTION;
            rmev := cast(*xcb_input_raw_motion_event_t) geev;
            if !xd.currently_hovered_window return;
            di := get_device_info(xd, rmev.deviceid);
            should_handle := (!di || (di && !di.master && di.type == .Device_With_Scroll));
            if should_handle return;

            axis: []xcb_input_fp3232_t;
            axis.data = xcb_input.raw_button_press_axisvalues_raw(rmev);
            axis.count = xcb_input.raw_button_press_axisvalues_raw_length(rmev);

            valuator_masks: []u32;
            valuator_masks.data = xcb_input.raw_button_press_valuator_mask(rmev);
            valuator_masks.count = xcb_input.raw_button_press_valuator_mask_length(rmev);

            has_vert_scroll, vert_val := get_valuator_value(di.scroll_vert.number, axis, valuator_masks);
            has_horz_scroll, horz_val := get_valuator_value(di.scroll_horz.number, axis, valuator_masks);

            if has_vert_scroll {
                vs := fp3232_to_float(vert_val) / fp3232_to_float(di.scroll_vert.increment);
                event: Input.Event;
                event.type = .MOUSE_V_WHEEL;
                event.typical_wheel_delta = WHEEL_DELTA;
                event.wheel_delta = -1 * cast(s32)(cast(float64) WHEEL_DELTA * vs);
                array_add(*xd.base.events_this_frame, event);
                xd.base.mouse_wheel_delta.vertical += event.wheel_delta;
            }
            if has_horz_scroll {
                vs := fp3232_to_float(horz_val) / fp3232_to_float(di.scroll_horz.increment);
                event: Input.Event;
                event.type = .MOUSE_H_WHEEL;
                event.typical_wheel_delta = WHEEL_DELTA;
                event.wheel_delta = -1 * cast(s32)(cast(float64) WHEEL_DELTA * vs);
                array_add(*xd.base.events_this_frame, event);
                xd.base.mouse_wheel_delta.horizontal += event.wheel_delta;
            }
    }
}

Button_Event_Type :: LD_XKB_Key_Event_Type;
Button_Event_Source :: enum {
    Core;
    XInput;
}

handle_button_event :: (xd: *XCB_Display, source: Button_Event_Source, button: u32, event_type: Button_Event_Type) {
    event: Input.Event;
    event.type = .KEYBOARD;
    event.key_pressed = xx (event_type == .Press);
    if button == {
        case 1; event.key_code = Input.Key_Code.MOUSE_BUTTON_LEFT;
        case 2; event.key_code = Input.Key_Code.MOUSE_BUTTON_MIDDLE;
        case 3; event.key_code = Input.Key_Code.MOUSE_BUTTON_RIGHT;

        case 4; #through;
        case 5;
            if source != .Core return;
            event.type = .MOUSE_V_WHEEL;
            event.typical_wheel_delta = WHEEL_DELTA;
            event.wheel_delta = WHEEL_DELTA * (ifx (button & 0x01) then cast(s32) -1 else 1);
            array_add(*xd.base.events_this_frame, event);
            xd.base.mouse_wheel_delta.vertical += event.wheel_delta;
            return;

        case 6; #through;
        case 7;
            if source != .Core return;
            event.type = .MOUSE_H_WHEEL;
            event.typical_wheel_delta = WHEEL_DELTA;
            event.wheel_delta = WHEEL_DELTA * (ifx (button & 0x01) then cast(s32) -1 else 1);
            array_add(*xd.base.events_this_frame, event);
            xd.base.mouse_wheel_delta.horizontal += event.wheel_delta;
            return;

        case 8; event.key_code = Input.Key_Code.MOUSE_BUTTON_X1;
        case 9; event.key_code = Input.Key_Code.MOUSE_BUTTON_X2;

        case; return;
    }

    xd.base.input_button_states[event.key_code] =
        ifx event.key_pressed then (Input.Key_Current_State.START | Input.Key_Current_State.DOWN)
        else Input.Key_Current_State.END;

    array_add(*xd.base.events_this_frame, event);
}

fp3232_to_float :: inline (fp: xcb_input_fp3232_t) -> float64 {
    vs := cast(float64) fp.integral;
    if fp.integral < 0 vs -= cast(float64) fp.frac / cast(float64) U32_MAX;
    else vs += cast(float64) fp.frac / cast(float64) U32_MAX;
    return vs;
}

get_valuator_value :: inline (number: u16, values: []xcb_input_fp3232_t, masks: []u32) -> bool, xcb_input_fp3232_t {
    id := cast(u16)1 << number;
    idx := (id & 0xffe0) >> 6;
    if idx >= xx masks.count {
        log_error("VALUATOR_ERR: number=% idx=% values=% masks=%", number, idx, values, masks);
        return false, .{};
    }
    if number == INVALID_VALUATOR || !(masks[(id & 0xffe0) >> 6] & (id & 0x001f)) return false, .{};

    pval := values.data;
    id = 1;
    for 0..cast(s32) number - 1 {
        if masks[(id & 0xffe0) >> 6] & (id & 0x001f) {
            pval += 1;
            assert(pval < values.data + values.count);
        }
        id = id << it;
    }
    return true, pval.*;
}

INVALID_VALUATOR :: U16_MAX;

XCB_Valuator_Class :: struct {
    label: string;
    number: u16;
}

XCB_Scroll_Axis_Info :: struct {
    number: u16 = INVALID_VALUATOR;
    valuator: *XCB_Valuator_Class;
    increment: xcb_input_fp3232_t;
}

XCB_Device_Info :: struct {
    id: xcb_input_device_id_t;
    name: string;
    type: enum {
        Device_With_Scroll;
        Other;
    }
    master: bool;
    valuators: [..]XCB_Valuator_Class;
    scroll_vert: XCB_Scroll_Axis_Info;
    scroll_horz: XCB_Scroll_Axis_Info;
}

get_device_info :: (xd: *XCB_Display, device_id: xcb_input_device_id_t) -> *XCB_Device_Info {
    ret, found := table_find(*xd.devices, device_id);
    if found return ret;

    ret = null;

    xcb_err: *xcb_generic_error_t;
    cookie := xcb_input.xi_query_device(xd.handle, device_id);
    reply := xcb_input.xi_query_device_reply(xd.handle, cookie, *xcb_err);
    defer libc_free(reply);

    if xcb_err {
        log_error("XCB: failed to list XInput devices: %", xcb_err.*);
        return null;
    }

    infos_len := xcb_input.xi_query_device_infos_length(reply);
    infos_it  := xcb_input.xi_query_device_infos_iterator(reply);
    for 1..infos_len {
        defer xcb_input.xi_device_info_next(*infos_it);

        device_info: XCB_Device_Info;

        info := infos_it.data;
        old_dev:, found = table_find(*xd.devices, info.deviceid);
        if found {
            ret = old_dev;
            continue;
        }

        sz_name := xcb_input.xi_device_info_name(info);
        name_len := xcb_input.xi_device_info_name_length(info);
        device_name := to_string(sz_name, name_len);

        valuators: [..]XCB_Valuator_Class;
        scroll_vert: XCB_Scroll_Axis_Info;
        scroll_horz: XCB_Scroll_Axis_Info;

        classes: [..]string;
        classes_count := xcb_input.xi_device_info_classes_length(info);
        classes_it := xcb_input.xi_device_info_classes_iterator(info);
        for 1..classes_count {
            defer xcb_input.device_class_next(*classes_it);

            class := classes_it.data;
            class_type := cast(xcb_input_device_class_type_t) class.type;
            if class_type == {
                case .VALUATOR; {
                    val_class := cast(*xcb_input_valuator_class_t) class;
                    array_add(*valuators, .{
                        label  = atom_name(xd, val_class.label),
                        number = val_class.number,
                    });
                }
                case .SCROLL; {
                    scroll_class := cast(*xcb_input_scroll_class_t) class;
                    if scroll_class.scroll_type == xx xcb_input_scroll_type_t.VERTICAL {
                        scroll_vert.number = scroll_class.number;
                        scroll_vert.increment = scroll_class.increment;
                    } else {
                        assert(scroll_class.scroll_type == xx xcb_input_scroll_type_t.HORIZONTAL);
                        scroll_horz.number = scroll_class.number;
                        scroll_horz.increment = scroll_class.increment;
                    }
                }
            }
        }

        device_type := cast(xcb_input_device_type_t) info.type;

        device_info.id = info.deviceid;
        device_info.type = .Other;
        device_info.name = copy_string(device_name);
        device_info.valuators = valuators;
        device_info.master = (device_type == .MASTER_KEYBOARD || device_type == .MASTER_POINTER);

        if scroll_vert.number != INVALID_VALUATOR || scroll_horz.number != INVALID_VALUATOR {
            scroll_vert.valuator = ifx scroll_vert.number != INVALID_VALUATOR && scroll_vert.number < valuators.count then *valuators[scroll_vert.number] else null;
            scroll_horz.valuator = ifx scroll_horz.number != INVALID_VALUATOR && scroll_horz.number < valuators.count then *valuators[scroll_horz.number] else null;
            if !scroll_vert.valuator || scroll_horz.valuator {
                device_info.type = .Device_With_Scroll;
                device_info.scroll_vert = scroll_vert;
                device_info.scroll_horz = scroll_horz;
            }
        }

        new_dev := New(XCB_Device_Info, initialized=false);
        new_dev.* = device_info;
        table_add(*xd.devices, info.deviceid, new_dev);
        if !ret then ret = new_dev;
    }

    return ret;
}

set_utf8_property :: (xw: *XCB_Window, property: xcb_atom_t, value: string) {
    xd := xw.display;
    xcb.change_property(
        xd.handle,
        .REPLACE,
        xw.handle,
        property,
        xd.global_atoms.UTF8_STRING,
        8, xx value.count, value.data);
}

WM_State_Op :: enum u32 {
    REMOVE :: 0;
    ADD    :: 1;
    TOGGLE :: 2;
}

set_wm_state :: (xw: *XCB_Window, op: WM_State_Op, v1: xcb_atom_t, v2: xcb_atom_t = 0) {
    xd := xw.display;

    // https://specifications.freedesktop.org/wm-spec/latest/ar01s05.html
    event: xcb_client_message_event_t;
    event.response_type = XCB_CLIENT_MESSAGE;
    event.format = 32;
    event.type = xd.global_atoms._NET_WM_STATE;
    event.window = xw.handle;
    event.data.data32[0] = xx op;
    event.data.data32[1] = v1;
    event.data.data32[2] = v2;
    event.data.data32[3] = 1;     // https://specifications.freedesktop.org/wm-spec/latest/ar01s09.html#sourceindication
    xcb.send_event(
        xd.handle, 0, xd.screen.root,
        xx (xcb_event_mask_t.SUBSTRUCTURE_NOTIFY | .SUBSTRUCTURE_REDIRECT),
        xx *event);
    xcb.flush(xd.handle);
}

load_cursors :: (xd: *XCB_Display) -> bool {
    ctx: *xcb_cursor_context_t;
    if xcb_cursor.context_new(xd.handle, xd.screen, *ctx) < 0 return false;
    defer xcb_cursor.context_free(ctx);

    preloaded_x_cursors :: string.[
        "default", "pointer", "not-allowed", "col-resize", "row-resize",
        "all-scroll", "nw-resize", "se-resize", "text",
    ];

    for preloaded_x_cursors {
        name := temp_c_string(it);
        table_set(*xd.cursors, it, xcb_cursor.load_cursor(ctx, name));
    }

    return true;
}

atom_name :: (xd: *XCB_Display, atom: xcb_atom_t) -> string {
    name, found := table_find(*xd.atom_names, atom);
    if found return name;

    xcb_err: *xcb_generic_error_t;
    cookie := xcb.get_atom_name(xd.handle, atom);
    reply  := xcb.get_atom_name_reply(xd.handle, cookie, *xcb_err);
    defer libc_free(reply);

    if !reply || xcb_err return "";

    n: string;
    n.data  = xcb.get_atom_name_name(reply);
    n.count = xcb.get_atom_name_name_length(reply);
    name = copy_string(n);
    table_add(*xd.atom_names, atom, name);
    return name;
}

#scope_module
xcb: XCB_Symbols;
xcb_input: XCB_XInput_Symbols;
xcb_xkb: XCB_XKB_Symbols;
xcb_cursor: XCB_Cursor_Symbols;
xcb_icccm: XCB_ICCCM_Symbols;
