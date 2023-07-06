x11_translate_key_code :: (key: KeySym) -> Key_Code {
    using Key_Code;

    if key == 32 || key == XK_KP_Space return SPACEBAR;

    if key == XK_Left || key == XK_KP_Left
        return ARROW_LEFT;
    if key == XK_Right || key == XK_KP_Right
        return ARROW_RIGHT;
    if key == XK_Up || key == XK_KP_Up
        return ARROW_UP;
    if key == XK_Down || key == XK_KP_Down
        return ARROW_DOWN;
    if (key == XK_Shift_L) || (key == XK_Shift_R)
        return SHIFT;
    if key == XK_Escape
        return ESCAPE;
    if key == XK_Return || key == XK_KP_Enter
        return ENTER;
    if (key == XK_Control_L) || (key == XK_Control_R)
        return CTRL;
    if key == XK_BackSpace
        return BACKSPACE;
    if key == XK_Delete || key == XK_KP_Delete
        return DELETE;
    if key == XK_Tab || key == XK_KP_Tab
        return TAB;
    if key == XK_F1
        return F1;
    if key == XK_F2
        return F2;
    if key == XK_F3
        return F3;
    if key == XK_F4
        return F4;
    if key == XK_F5
        return F5;
    if key == XK_F6
        return F6;
    if key == XK_F7
        return F7;
    if key == XK_F8
        return F8;
    if key == XK_F9
        return F9;
    if key == XK_F10
        return F10;
    if key == XK_F11
        return F11;
    if key == XK_F12
        return F12;
    if key == XK_F13
        return F13;
    if key == XK_F14
        return F14;
    if key == XK_F15
        return F15;
    if key == XK_F16
        return F16;
    if key == XK_Home || key == XK_KP_Home
        return HOME;
    if key == XK_End || key == XK_KP_End
        return END;
    if key == XK_Insert || key == XK_KP_Insert
        return INSERT;
    if key == XK_Page_Up || key == XK_KP_Page_Up
        return PAGE_UP;
    if key == XK_Page_Down || key == XK_KP_Page_Down
        return PAGE_DOWN;

    key = key & 0xFF;
    if (key >= #char "a") && (key <= #char "z") return cast(Key_Code) (key - 0x20);
    if key > 32 && key < 127 return cast(Key_Code) key;

    return UNKNOWN;
}

x11_update_window_events :: (x11_display: *X11Display) {
    display := x11_display.handle;
    XLockDisplay(display);

    xev: XEvent;
    while XPending(display) {
        XNextEvent(display, *xev);
        x11_handle_event(display, *xev);
    }

    XUnlockDisplay(display);
}

x11_handle_event :: (display: *Display, xev: *XEvent) {
    using Key_Code;

    if XFilterEvent(xev, None) return;

    ld_win := get_by_native_handle(xx xev.xany.window);
    if ld_win == INVALID_WINDOW return;
    win := isa(ld_win, X11Window);

    if xev.type == {
        case ClientMessage;
            message_type := xev.xclient.message_type;
            if message_type == XdndEnter {
                drop_handled := maybe_handle_xdnd_drop_events(display, xev, *drop_info);
                if drop_handled  return;
            } else if message_type == x_global_wm_protocols {
                message0 := cast(Atom) xev.xclient.data.l[0];

                // This can't be a switch, because the values are not constant!
                // Except come on guys, every single implementation of X11 in the universe
                // is going to agree on these values. Why are we pretending they are not constant?
                // How about if we just look them up once and then hardcode them into this program?
                // We'd save startup time...

                if message0 == x_global_wm_delete_window {
                    event: Event;
                    event.type = .QUIT;
                    array_add(*events_this_frame, event);
                }
            }

        case KeyPress;
            event: Event;
            status: Status;
            keysym: KeySym;
            text: [16]u32;   // surely enough for everybody
            count := XwcLookupString(win.ic, *xev.xkey, text.data, xx text.count, *keysym, *status);

            has_keysym := (status == XLookupKeySym || status == XLookupBoth);
            has_text := (status == XLookupChars || status == XLookupBoth);

            if has_keysym {
                assert(keysym != 0);

                if xev.xkey.state & ShiftMask   event.shift_pressed = true;
                if xev.xkey.state & ControlMask event.ctrl_pressed = true;
                if xev.xkey.state & Mod1Mask    event.alt_pressed = true;
                if xev.xkey.state & Mod4Mask    event.cmd_meta_pressed = true;

                event.type = .KEYBOARD;
                event.key_pressed = 1;
                event.key_code = x11_translate_key_code(keysym);
                for 0..count - 1 {
                    utf32 := text[it];
                    if utf32 >= 32 && utf32 != 127 event.text_input_count += 1;
                }
                array_add(*events_this_frame, event);

                input_button_states[event.key_code] = (Key_Current_State.START | Key_Current_State.DOWN);
            }

            if has_text {
                assert(count > 0);

                for 0..count - 1 {
                    utf32 := text[it];
                    if utf32 < 32 || utf32 == 127 continue;

                    text_event: Event;
                    text_event.type = .TEXT_INPUT;
                    text_event.key_pressed = 1;
                    text_event.key_code = x11_translate_key_code(keysym);
                    text_event.utf32 = utf32;
                    array_add(*events_this_frame, text_event);
                }
            }

        case KeyRelease;
            // For some odd reason X11 generates KeyRelease followed by a near identical KeyPress to simulate repeat events so we have to filter that out
            if XEventsQueued(display, QueuedAfterReading) {
                nev: XEvent;
                XPeekEvent(display, *nev);

                if nev.type == KeyPress
                    && nev.xkey.time == xev.xkey.time
                    && nev.xkey.keycode == xev.xkey.keycode {

                    // This is a repeat, so we ignore the KeyRelease.
                    return;
                }
            }

            event: Event;
            keysym := XLookupKeysym(*xev.xkey, 0);
            if keysym != NoSymbol {
                assert(keysym != 0);

                if xev.xkey.state & ShiftMask   event.shift_pressed = true;
                if xev.xkey.state & ControlMask event.ctrl_pressed = true;
                if xev.xkey.state & Mod1Mask    event.alt_pressed = true;

                event.type = .KEYBOARD;
                event.key_pressed = 0;
                event.key_code = x11_translate_key_code(keysym);
                array_add(*events_this_frame, event);

                input_button_states[event.key_code] = Key_Current_State.END;
            }

        case ButtonPress;
            event: Event;
            button := xev.xbutton.button;

            if button >= 4 {
                // Buttons 4 and above are 'synthetic' events for scroll wheels:
                //  - 4/5 will be used for the forward/backward direction of the first scroll wheel
                //  - 6/7 will be used for the forward/backward direction of the second scroll wheel
                //  ... so on ...
                event.type = .MOUSE_WHEEL;
                event.typical_wheel_delta = WHEEL_DELTA;
                event.wheel_delta = WHEEL_DELTA * (ifx (button & 0x01) then cast(s32) -1 else 1);
                array_add(*events_this_frame, event);
                mouse_delta_z += event.wheel_delta;
                return;
            }

            event.type = .KEYBOARD;
            event.key_pressed = 1;
            if button == Button1 {
                event.key_code = MOUSE_BUTTON_LEFT;
            } else if button == Button2 {
                event.key_code = MOUSE_BUTTON_MIDDLE;
            } else if button == Button3 {
                event.key_code = MOUSE_BUTTON_RIGHT;
            }

            input_button_states[event.key_code] = (Key_Current_State.START | Key_Current_State.DOWN);

            array_add(*events_this_frame, event);

        case ButtonRelease;
            // it seems that mouse input doesnt generate repeat events so we dont have to peek the queue
            event: Event;
            button := xev.xbutton.button;

            // Buttons above 4 are scroll wheel events, we don't care about release events for them
            if button >= 4 return;

            event.type = .KEYBOARD;
            event.key_pressed = 0;
            if button == Button1 {
                event.key_code = MOUSE_BUTTON_LEFT;
            } else if button == Button2 {
                event.key_code = MOUSE_BUTTON_MIDDLE;
            } else if button == Button3 {
                event.key_code = MOUSE_BUTTON_RIGHT;
            }

            input_button_states[event.key_code] = Key_Current_State.END;

            array_add(*events_this_frame, event);

        case SelectionRequest;
            selreq := cast(*XSelectionRequestEvent) xev;

            out: XEvent;
            selnot := cast(*XSelectionEvent) *out;
            selnot.type = SelectionNotify;
            selnot.requestor = selreq.requestor;
            selnot.selection = selreq.selection;
            selnot.target = selreq.target;
            selnot.time = selreq.time;
            selnot.property = None;

            if x_window_is_ours(display, selreq.owner) {
                if selreq.target == x_global_xa_utf8 {
                    selnot.property = selreq.property;

                    text_data := x_global_clipboard_buffer.text_data;
                    XChangeProperty(
                        selreq.display, selreq.requestor, selreq.property, selreq.target, 8, PropModeReplace,
                        text_data.data, cast(s32) text_data.count);
                } else if selreq.target == x_global_xa_targets {
                    selnot.property = selreq.property;

                    atoms: [..] Atom;
                    array_add(*atoms, x_global_xa_utf8);
                    array_add(*atoms, x_global_xa_targets);
                    array_add(*atoms, x_global_xa_multiple);
                    if x_global_clipboard_buffer.rgb_data {
                        array_add(*atoms, x_global_image_bmp);
                    }
                    XChangeProperty(
                        selreq.display, selreq.requestor, selreq.property, x_global_xa_atom, 32, PropModeReplace,
                        xx atoms.data, cast(s32) atoms.count);

                    array_reset(*atoms);
                } else if selreq.target == x_global_image_bmp {
                    #import "stb_image_write";

                    Data :: struct {
                        _context: *Context;
                        data: [..] u8;
                    }

                    write_func :: (_context: *void, _data: *void, size: s32) #c_call {
                        data := cast(*Data) _context;
                        push_context <<data._context {
                            data8 := cast(*u8) _data;
                            for 0..size-1 {
                                array_add(*data.data, data8[it]);
                            }
                        }
                    }

                    data: Data;
                    data._context = *context;
                    w := x_global_clipboard_buffer.width;
                    h := x_global_clipboard_buffer.height;
                    comp: s32 = 3;
                    stride := x_global_clipboard_buffer.pitch;
                    stbi_write_bmp_to_func(write_func, *data, w, h, comp, x_global_clipboard_buffer.rgb_data);

                    selnot.property = selreq.property;
                    XChangeProperty(
                        selreq.display, selreq.requestor, selreq.property, selreq.target, 8, PropModeReplace,
                        xx data.data.data, cast(s32) data.data.count);

                    array_reset(*data.data);
                } else {
                    // print("GOT REQ: %\n", to_string(XGetAtomName(x_global_display, selreq.target)));
                }
            }

            XSendEvent(selreq.display, selreq.requestor, True, 0, *out);
        case ConfigureNotify;
            config := cast(*XConfigureEvent) xev;
            ld_win := get_by_native_handle(xx config.window);
            if ld_win add_resize_record(ld_win, config.width, config.height);
        // Adding a dummy event to the queue, forcing a redraw when window's focus
        // changes or it gets exposed (e.g. it's being asked to render itself but without
        // it getting focus)
        case FocusIn;
            input_application_has_focus = true;
            XSetICFocus(win.ic);
            array_add(*events_this_frame, .{type=.WINDOW});
        case FocusOut;
            input_application_has_focus = false;
            XUnsetICFocus(win.ic);
            array_add(*events_this_frame, .{type=.WINDOW});
        case Expose;
            array_add(*events_this_frame, .{type=.WINDOW});
    }
}


x11_clipboard_get_text :: (win: Window) -> string {  // Allocated via alloc; should be manually freed.
    text: string;
    display := x_global_display;
    selection_owner := XGetSelectionOwner(display, x_global_xa_clipboard);

    // if we created the window then we pull directly from our own locat clipbuffer
    if x_window_is_ours(display, selection_owner) {
        return copy_string(x_global_clipboard_buffer.text_data);
    } else if selection_owner != None {
        property := XInternAtom(display, "JAI_SELECTION", False);
        XConvertSelection(display, x_global_xa_clipboard, x_global_xa_utf8, property, win, CurrentTime);
        xev: XEvent;

        sleep_milliseconds(1);

        // @Warning this will block until we recive a notification back from the selection owner
        XIfEvent(display, xx *xev, x_selection_notify_predicate, *win);


        if (cast(*XSelectionEvent) *xev).property == None then return text;

        nitems, rem: u64;
        format: s32;
        data: *u8;
        type: Atom;
        if XGetWindowProperty(display, win, property, 0, ~0, True, AnyPropertyType, *type, *format, *nitems, *rem, *data) == 0 {
            assert(rem == 0); // to be sure we get all the bytes and there are no remaining bytes
            if (type == x_global_xa_utf8 && format == 8) {
                temp: string;
                temp.data = data;
                temp.count = xx nitems;
                text = copy_string(temp);
                XFree(data);
                return text;
            } else {
                // @Incomplete: megabytes of text are sent in a different format which is not supported yet
            }
        }
    }

    return text;
}

x11_clipboard_get_text :: () -> string {
    dpy := x_global_display;
    if !dpy return "";
    win: Window;
    revert: s32;
    XGetInputFocus(dpy, *win, *revert);
    return x11_clipboard_get_text(win);
}

x11_clipboard_set_text :: (win: Window, text: string) {
    XSetSelectionOwner(x_global_display, x_global_xa_clipboard, win, CurrentTime);
    owner := XGetSelectionOwner(x_global_display, x_global_xa_clipboard);
    if owner != win return;

    x_release_clipboard_data();
    x_global_clipboard_buffer.text_data = copy_string(text);
}

x11_clipboard_set_text :: (text: string) {
    dpy := x_global_display;
    if !dpy return;
    win: Window;
    revert: s32;
    XGetInputFocus(dpy, *win, *revert);
    x11_clipboard_set_text(win, text);
}

x11_clipboard_set_bitmap :: (win: Window, width: s32, height: s32, rgb: *u8) {
    XSetSelectionOwner(x_global_display, x_global_xa_clipboard, win, CurrentTime);
    owner := XGetSelectionOwner(x_global_display, x_global_xa_clipboard);
    if owner != win return;

    XLockDisplay(x_global_display);

    src := rgb;
    dst := cast(*u8) alloc(width * height * 3);
    memcpy(dst, src, width * height * 3);

    x_release_clipboard_data();
    x_global_clipboard_buffer.rgb_data = dst;
    x_global_clipboard_buffer.width    = width;
    x_global_clipboard_buffer.height   = height;
    x_global_clipboard_buffer.pitch    = width * 3;

    XUnlockDisplay(x_global_display);
}

x11_clipboard_set_bitmap :: (width: s32, height: s32, rgb: *u8) {
    dpy := x_global_display;
    if !dpy return;
    win: Window;
    revert: s32;
    XGetInputFocus(dpy, *win, *revert);
    x11_clipboard_set_bitmap(win, width, height, rgb);
}

#scope_file
// Xdnd support by Jens Frederich. Send questions his way. Licensed under the MIT license; see copyright at the end
// of the file.

get_position_root_x :: inline (xevent: *XEvent) -> s32 {
    return cast(s32) xevent.xclient.data.l[2] >> 16;
}

get_position_root_y :: inline (xevent: *XEvent) -> s32 {
    return cast(s32) xevent.xclient.data.l[2] & 0xffff;
}

apply_position :: (dnd: *Xdnd_Context, widget: Window, from: Window, action: Atom, x: s32, y: s32, time: Time, typelist: [] Atom, want_position: *bool, supported_action_return: *Atom, desired_type: *Atom, rectangle: *XRectangle) -> bool {
    supported_type: Atom;
    supported_action: Atom;

    dropper_typelist  := drop_info.user_typelist;
    supported_actions := drop_info.user_actions;

    if dropper_typelist.count > 0 {
        // find a correlation:
        for j: dropper_typelist {
            for i: typelist {
                if i == j {
                    supported_type = i;
                    break;
                }
            }
        }
    } else {
        // user did not specify, so return first type
        supported_type = typelist[0];
    }

    // not supported, so return false
    if !supported_type  return false;

    if supported_actions.count > 0 {
        for supported_actions {
            if action == it {
                supported_action = action;
                break;
            }
        }
    } else {
        // user did not specify
        if action == XdndActionCopy  supported_action = action;
    }

    if !supported_action  return false;

    <<want_position = true;
    rectangle.x = 0;
    rectangle.y = 0;
    rectangle.width = 0;
    rectangle.height = 0;

    drop_info.return_action = supported_action;
    <<supported_action_return = supported_action;
    drop_info.return_type = supported_type;
    <<desired_type = supported_type;
    drop_info.x = x;
    drop_info.y = y;

    return true;
}

send_finished :: (display: *Display, window: Window, from: Window) {
    xevent: XEvent;
    xevent.xany.type = ClientMessage;
    xevent.xany.display = display;
    xevent.xclient.window = window;
    xevent.xclient.message_type = XdndFinished;
    xevent.xclient.format = 32;

    // target window
    xevent.xclient.data.l[0] = cast(s64) from;

    XSendEvent(display, window, 0, 0, *xevent);
}

send_status :: (display: *Display, window: Window, from: Window, will_accept: bool, want_position: bool, x: int, y: int, w: int, h: int, action: Atom) {
    xevent: XEvent;
    xevent.xany.type = ClientMessage;
    xevent.xany.display = display;
    xevent.xclient.window = window;
    xevent.xclient.message_type = XdndStatus;
    xevent.xclient.format = 32;

    // Our window
    xevent.xclient.data.l[0] = cast(s64) from;

    // will accept yes no
    xevent.xclient.data.l[1] = (xevent.xclient.data.l[1] & ~0x1) | ifx will_accept then 1 else 0;

    // want position?
    if will_accept  xevent.xclient.data.l[1] = (xevent.xclient.data.l[1] & ~0x2) | ifx want_position then 2 else 0;

    if want_position {
        xevent.xclient.data.l[2] = (x << 16) | (y & 0xffff);
        xevent.xclient.data.l[3] = (w << 16) | (h & 0xffff);
    }

    if will_accept  xevent.xclient.data.l[4] = cast(s64) action;

    XSendEvent(display, window, 0, 0, *xevent);
}

paste_property :: (display: *Display, from: Window, insert: Window, prop: u64, delete_prop: s64) -> bool {
    nread: s64;
    data_count: s64;
    bytes_after: s64;
    error: bool;

    array_reset(*drop_info.data);
    while true {
        actual_type: Atom;
        actual_fmt: s32;
        data: *u8;

        x := nread / 4;

        if XGetWindowProperty(display, insert, prop, xx x , 65536, xx delete_prop, AnyPropertyType, *actual_type, *actual_fmt, xx *data_count, xx *bytes_after, *data) != Success {
            XFree(data);
            return false;
        }

        nread += data_count;

        if (drop_info.data.count == 0) {
            array_reserve(*drop_info.data, data_count + bytes_after);
        }
        memcpy(drop_info.data.data + drop_info.data.count, data, data_count);
        drop_info.data.count += data_count;

        XFree(data);

        if bytes_after == 0  break;
    }

    if !nread  return false;

    return true;
}

get_selection :: (display: *Display, from: Window, prop: Atom, insert: Window) -> bool {
    if prop == None  return false;

    actual_type: Atom;
    actual_fmt: s32;
    nitems: u64;
    bytes_after: u64;
    s: *u8;
    if (XGetWindowProperty(display, insert, prop, 0, 8, False, AnyPropertyType, *actual_type, *actual_fmt, *nitems, *bytes_after, *s) != Success) {
        XFree(s);
        return false;
    }

    XFree(s);
    if actual_type != XInternAtom(display, "INCR", False) {
        return paste_property(display, from, insert, prop, True);
    }

    XDeleteProperty(display, insert, prop);

    /* @Cleanup: Get rid of fd_set stuff.
    time_start := get_time();
    while true {
        r: fd_set;
        xe: XEvent;
        if XCheckMaskEvent(display, PropertyChangeMask, *xe) {
            if xe.type == PropertyNotify && xe.xproperty.state == PropertyNewValue {
                // time between arrivals of data
                time_start = get_time();
                if paste_property(display, from, insert, prop, True)  break;
            }
        } else {
            FD_ZERO(*r);
            FD_SET(ConnectionNumber(display), *r);
            select(ConnectionNumber(display) + 1, *r, 0, 0, *tv);

            if FD_ISSET(ConnectionNumber(display), *r)  continue;
        }
        end := get_time();

        // no data for five seconds, so quit
        if end - start > 5000000  return false;
    }
    */
    return true;
}

maybe_handle_xdnd_drop_events :: (display: *Display, xevent: *XEvent, drop_info: *Drop_Info) -> bool {
    assert(xevent.type == ClientMessage);
    assert(xevent.xclient.message_type == XdndEnter);

    dnd := x_global_xdnd_context;
    dnd.root_window = DefaultRootWindow(display);

    while true {
        if xevent.type == ClientMessage {
            if xevent.xclient.message_type == XdndEnter {
                version := xevent.xclient.data.l[1] >> 24;
                if version < 3  return false;

                xdnd_context_reset(*dnd);
                dnd.dragger_window = cast(Window) xevent.xclient.data.l[0];
                dnd.dropper_toplevel = xevent.xany.window;
                dnd.dropper_window = 0;  // Enter goes to the top level window only, so we don't really know what the sub window is yet.

                support_more_than_three_types := xevent.xclient.data.l[1] & 0x1;
                if !support_more_than_three_types {
                    for 0..2 {
                        atom := cast(Atom) xevent.xclient.data.l[2 + it];
                        array_add(*dnd.dragger_typelist, atom);
                    }
                } else {
                    array_reset(*dnd.dragger_typelist);

                    type: Atom;
                    format: s32;
                    count, remaining: u64;
                    data: *u8 = null;
                    XGetWindowProperty(display, dnd.dragger_window, XdndTypeList, 0, 0x8000000, False, XA_ATOM, *type, *format, *count, *remaining, *data);

                    if type != XA_ATOM || format != 32 || count == 0 || data == null {
                        print("XGetWindowProperty failed in get type list\n");
                    }

                    atom_data: *Atom = cast(*Atom) data;
                    for 0..count {
                        array_add(*dnd.dragger_typelist, atom_data[it]);
                    }

                    XFree(data);
                }

                if dnd.dragger_typelist {
                    dnd.stage = Xdnd_Stage.DROP_ENTERED;
                } else {
                    print("      typelist returned as zero!\n");
                }
            } else if xevent.xclient.message_type == XdndLeave {
                source_window := cast(u64) xevent.xclient.data.l[0];
                if dnd.dragger_window == source_window && dnd.stage == Xdnd_Stage.DROP_ENTERED {
                    dnd.stage = Xdnd_Stage.DROP_IDLE;
                    array_reset(*dnd.dragger_typelist);
                    dnd.dropper_toplevel = 0;
                    dnd.dropper_window = 0;
                } else {
                    print("    wrong stage or from wrong window\n");
                }
            } else if xevent.xclient.message_type == XdndPosition {
                action: Atom;
                rectangle: XRectangle;
                want_position: bool;
                last_window: Window;

                source_window := cast(u64) xevent.xclient.data.l[0];
                if dnd.dragger_window == source_window && dnd.stage == Xdnd_Stage.DROP_ENTERED {
                    last_window = dnd.dropper_window;

                    if xevent.xany.window != dnd.dropper_toplevel || !dnd.dropper_window {
                        dnd.dropper_toplevel = xevent.xany.window;
                        parent := dnd.root_window;
                        child := dnd.dropper_toplevel;
                        root_x := get_position_root_x(xevent);
                        root_y := get_position_root_y(xevent);

                        while true {
                            xd: s32;
                            yd: s32;
                            new_child: Window;
                            if !XTranslateCoordinates(display, parent, child, root_x, root_y, *xd, *yd, *new_child)  break;
                            if !new_child  break;

                            child = new_child;
                        }

                        dnd.dropper_window = child;
                        xevent.xany.window = child;
                    } else if xevent.xany.window == dnd.dropper_toplevel && dnd.dropper_window {
                        xevent.xany.window = dnd.dropper_window;
                    }

                    action := XdndActionCopy;
                    dnd.supported_action = XdndActionCopy;
                    dnd.x = get_position_root_x(xevent);
                    dnd.y = get_position_root_y(xevent);
                    dnd.time = CurrentTime;

                    dnd.will_accept = apply_position(*dnd, xevent.xany.window, dnd.dragger_window, action, dnd.x, dnd.y, dnd.time, dnd.dragger_typelist, *want_position, *dnd.supported_action, *dnd.desired_type, *rectangle);
                    send_status(display, dnd.dragger_window, dnd.dropper_toplevel, dnd.will_accept, want_position, rectangle.x, rectangle.y, rectangle.width, rectangle.height, dnd.supported_action);
                } else {
                    print("    wrong stage or from wrong window\n");
                }
            } else if xevent.xclient.message_type == XdndDrop {
                if xevent.xany.window == dnd.dropper_toplevel && dnd.dropper_window {
                    xevent.xany.window = dnd.dropper_window;
                }

                source_window := cast(u64) xevent.xclient.data.l[0];
                if dnd.dragger_window == source_window && dnd.stage == Xdnd_Stage.DROP_ENTERED {
                    dnd.time = CurrentTime;
                    if dnd.will_accept {
                        // convert selection
                        {
                            dnd.dragger_window = XGetSelectionOwner(display, XdndSelection);
                            if !dnd.dragger_window {
                                print(" XGetSelectionOwner failed\n");
                            } else {
                                XConvertSelection(display, XdndSelection, dnd.desired_type, x_global_non_protocol_atom, dnd.dropper_window, CurrentTime);
                            }
                        }

                        dnd.stage = Xdnd_Stage.DROP_CONVERTING;
                    } else {
                        print("    will_accept is false - sending finished\n");
                        send_finished(display, dnd.dragger_window, dnd.dropper_toplevel);

                        array_reset(*dnd.dragger_typelist);
                        xdnd_context_reset(*dnd);
                        dnd.stage = Xdnd_Stage.DROP_IDLE;
                    }
                } else {
                    print("    wrong stage or from wrong window\n");
                }
            }
        } else if xevent.type == SelectionNotify {
            if xevent.xselection.property == x_global_non_protocol_atom && dnd.stage == Xdnd_Stage.DROP_CONVERTING {
                error := get_selection(display, dnd.dragger_window, xevent.xselection.property, xevent.xany.window);
                // Error is not actually used, I think future versions of the protocol maybe should return an error status to the calling window with the XdndFinished client message.

                send_finished(display, dnd.dragger_window, dnd.dropper_toplevel);

                array_reset(*dnd.dragger_typelist);
                xdnd_context_reset(*dnd);
                dnd.stage = Xdnd_Stage.DROP_IDLE;
            } else {
                print("  property is not Xdnd_NON_PROTOCOL_ATOM - ignoring\n");
            }
        }

        if dnd.stage == Xdnd_Stage.DROP_IDLE  break;

        XNextEvent(display, xevent);
    }

    if drop_info.data.count > 0 {
        files: [..] string;

        p := "";
        p.data = drop_info.data.data;
        p.count = drop_info.data.count;
        while true {
            i := find_index_from_left(p, "\r\n");
            if i == -1  break;

            file_name := "";
            // Heap allocated like on Windows.
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


        event: Event;
        event.type = .DRAG_AND_DROP_FILES;
        event.files = files;
        array_add(*events_this_frame, event);

        array_reset(*drop_info.data);
        return true;
    }

    return false;
}

#scope_file
#import "String";
