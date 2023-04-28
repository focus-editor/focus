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
    if key == XK_Insert
        return INSERT;
    if key == XK_Page_Up
        return PAGE_UP;
    if key == XK_Page_Down
        return PAGE_DOWN;

    key = key & 0xFF;
    if (key >= #char "a") && (key <= #char "z") return cast(Key_Code) (key - 0x20);
    if key > 32 && key < 127 return cast(Key_Code) key;

    return UNKNOWN;
}

x11_update_window_events :: (x11_display: *X11Display) {
    using Key_Code;

    display := x11_display.handle;
    XLockDisplay(display);

    while XPending(display) {
        xev: XEvent;
        XNextEvent(display, *xev);

        if xev.type == {
        case ClientMessage;
            message_type := xev.xclient.message_type;
            if message_type == XdndEnter {
                drop_handled := maybe_handle_xdnd_drop_events(display, *xev, *drop_info);
                if drop_handled  continue;
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

            shift: u32;
            if xev.xkey.state & ShiftMask
                shift = 1;
            if xev.xkey.state & ControlMask
                event.ctrl_pressed = true;
            if xev.xkey.state & Mod1Mask
                event.alt_pressed = true;

            shift_level: u32 = 0;
            if (xev.xkey.state & (ShiftMask | Mod5Mask)) == (ShiftMask | Mod5Mask) shift_level = 3;
            else if xev.xkey.state & Mod5Mask shift_level = 2;
            else if xev.xkey.state & ShiftMask shift_level = 1;

            keysym := XkbKeycodeToKeysym(display, xx xev.xkey.keycode, 0, shift_level);
            translated := x11_translate_key_code(keysym);

            event.type = .KEYBOARD;
            event.key_pressed = 1;
            event.key_code = translated;
            event.shift_pressed = cast(bool) shift;
            array_add(*events_this_frame, event);

            input_button_states[event.key_code] = (Key_Current_State.START | Key_Current_State.DOWN);

            utf32 := is_char(xx keysym);
            if (utf32 != 0) && !event.ctrl_pressed && !event.alt_pressed {
                char_event: Event;
                char_event.type = .TEXT_INPUT;
                char_event.utf32 = utf32;
                array_add(*events_this_frame, char_event);
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
                    continue;
                }
            }

            event: Event;

            shift: u32;
            if xev.xkey.state & ShiftMask
                shift = 1;
            if xev.xkey.state & ControlMask
                event.ctrl_pressed = true;
            if xev.xkey.state & Mod1Mask
                event.alt_pressed = true;

            keysym := XkbKeycodeToKeysym(display, xx xev.xkey.keycode, 0, 0 /* English lowercase group*/);
            translated := x11_translate_key_code(keysym);

            event.type = .KEYBOARD;
            event.key_pressed = 0;
            event.shift_pressed = cast(bool) shift;
            event.key_code = translated;

            input_button_states[event.key_code] = Key_Current_State.END;

            array_add(*events_this_frame, event);
        case ButtonPress;
            event: Event;
            event.type = .KEYBOARD;

            event.key_pressed = 1;
            button := xev.xbutton.button;
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
            event.type = .KEYBOARD;

            event.key_pressed = 0;
            button := xev.xbutton.button;
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
            selreq := cast(*XSelectionRequestEvent) *xev;

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
            config := cast(*XConfigureEvent) *xev;
            ld_win := get_by_native_handle(xx config.window);
            if ld_win add_resize_record(ld_win, config.width, config.height);
        case FocusIn;
            input_application_has_focus = true;
        case FocusOut;
            input_application_has_focus = false;
        }
    }
    XUnlockDisplay(display);
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
        if XGetWindowProperty(display, win, property, 0, 32, True, AnyPropertyType, *type, *format, *nitems, *rem, *data) == 0 {
            temp: string;
            temp.data = data;
            temp.count = xx nitems;
            text = copy_string(temp);
            XFree(data);
            return text;
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

#import "String";

is_char :: inline (keysym: u32) -> u32 {
    /* ref: https://www.x.org/releases/current/doc/xproto/x11protocol.html#keysym_encoding */
    if (keysym >= 0x20 && keysym <= 0x7e) || (keysym >= 0xa0 && keysym <= 0xff) {
        return keysym;
    }
    if keysym >= 0x01000100 && keysym <= 0x0110FFFF {
        return keysym & 0x10ffff;
    }
    if !(keysym & 0x_ffff_c0_00) {
        if keysym == {
            case 0x01A1; return 0x0104;
            case 0x01A2; return 0x02D8;
            case 0x01A3; return 0x0141;
            case 0x01A5; return 0x013D;
            case 0x01A6; return 0x015A;
            case 0x01A9; return 0x0160;
            case 0x01AA; return 0x015E;
            case 0x01AB; return 0x0164;
            case 0x01AC; return 0x0179;
            case 0x01AE; return 0x017D;
            case 0x01AF; return 0x017B;
            case 0x01B1; return 0x0105;
            case 0x01B2; return 0x02DB;
            case 0x01B3; return 0x0142;
            case 0x01B5; return 0x013E;
            case 0x01B6; return 0x015B;
            case 0x01B7; return 0x02C7;
            case 0x01B9; return 0x0161;
            case 0x01BA; return 0x015F;
            case 0x01BB; return 0x0165;
            case 0x01BC; return 0x017A;
            case 0x01BD; return 0x02DD;
            case 0x01BE; return 0x017E;
            case 0x01BF; return 0x017C;
            case 0x01C0; return 0x0154;
            case 0x01C3; return 0x0102;
            case 0x01C5; return 0x0139;
            case 0x01C6; return 0x0106;
            case 0x01C8; return 0x010C;
            case 0x01CA; return 0x0118;
            case 0x01CC; return 0x011A;
            case 0x01CF; return 0x010E;
            case 0x01D0; return 0x0110;
            case 0x01D1; return 0x0143;
            case 0x01D2; return 0x0147;
            case 0x01D5; return 0x0150;
            case 0x01D8; return 0x0158;
            case 0x01D9; return 0x016E;
            case 0x01DB; return 0x0170;
            case 0x01DE; return 0x0162;
            case 0x01E0; return 0x0155;
            case 0x01E3; return 0x0103;
            case 0x01E5; return 0x013A;
            case 0x01E6; return 0x0107;
            case 0x01E8; return 0x010D;
            case 0x01EA; return 0x0119;
            case 0x01EC; return 0x011B;
            case 0x01EF; return 0x010F;
            case 0x01F0; return 0x0111;
            case 0x01F1; return 0x0144;
            case 0x01F2; return 0x0148;
            case 0x01F5; return 0x0151;
            case 0x01F8; return 0x0159;
            case 0x01F9; return 0x016F;
            case 0x01FB; return 0x0171;
            case 0x01FE; return 0x0163;
            case 0x01FF; return 0x02D9;
            case 0x02A1; return 0x0126;
            case 0x02A6; return 0x0124;
            case 0x02A9; return 0x0130;
            case 0x02AB; return 0x011E;
            case 0x02AC; return 0x0134;
            case 0x02B1; return 0x0127;
            case 0x02B6; return 0x0125;
            case 0x02B9; return 0x0131;
            case 0x02BB; return 0x011F;
            case 0x02BC; return 0x0135;
            case 0x02C5; return 0x010A;
            case 0x02C6; return 0x0108;
            case 0x02D5; return 0x0120;
            case 0x02D8; return 0x011C;
            case 0x02DD; return 0x016C;
            case 0x02DE; return 0x015C;
            case 0x02E5; return 0x010B;
            case 0x02E6; return 0x0109;
            case 0x02F5; return 0x0121;
            case 0x02F8; return 0x011D;
            case 0x02FD; return 0x016D;
            case 0x02FE; return 0x015D;
            case 0x03A2; return 0x0138;
            case 0x03A3; return 0x0156;
            case 0x03A5; return 0x0128;
            case 0x03A6; return 0x013B;
            case 0x03AA; return 0x0112;
            case 0x03AB; return 0x0122;
            case 0x03AC; return 0x0166;
            case 0x03B3; return 0x0157;
            case 0x03B5; return 0x0129;
            case 0x03B6; return 0x013C;
            case 0x03BA; return 0x0113;
            case 0x03BB; return 0x0123;
            case 0x03BC; return 0x0167;
            case 0x03BD; return 0x014A;
            case 0x03BF; return 0x014B;
            case 0x03C0; return 0x0100;
            case 0x03C7; return 0x012E;
            case 0x03CC; return 0x0116;
            case 0x03CF; return 0x012A;
            case 0x03D1; return 0x0145;
            case 0x03D2; return 0x014C;
            case 0x03D3; return 0x0136;
            case 0x03D9; return 0x0172;
            case 0x03DD; return 0x0168;
            case 0x03DE; return 0x016A;
            case 0x03E0; return 0x0101;
            case 0x03E7; return 0x012F;
            case 0x03EC; return 0x0117;
            case 0x03EF; return 0x012B;
            case 0x03F1; return 0x0146;
            case 0x03F2; return 0x014D;
            case 0x03F3; return 0x0137;
            case 0x03F9; return 0x0173;
            case 0x03FD; return 0x0169;
            case 0x03FE; return 0x016B;
            case 0x047E; return 0x203E;
            case 0x04A1; return 0x3002;
            case 0x04A2; return 0x300C;
            case 0x04A3; return 0x300D;
            case 0x04A4; return 0x3001;
            case 0x04A5; return 0x30FB;
            case 0x04A6; return 0x30F2;
            case 0x04A7; return 0x30A1;
            case 0x04A8; return 0x30A3;
            case 0x04A9; return 0x30A5;
            case 0x04AA; return 0x30A7;
            case 0x04AB; return 0x30A9;
            case 0x04AC; return 0x30E3;
            case 0x04AD; return 0x30E5;
            case 0x04AE; return 0x30E7;
            case 0x04AF; return 0x30C3;
            case 0x04B0; return 0x30FC;
            case 0x04B1; return 0x30A2;
            case 0x04B2; return 0x30A4;
            case 0x04B3; return 0x30A6;
            case 0x04B4; return 0x30A8;
            case 0x04B5; return 0x30AA;
            case 0x04B6; return 0x30AB;
            case 0x04B7; return 0x30AD;
            case 0x04B8; return 0x30AF;
            case 0x04B9; return 0x30B1;
            case 0x04BA; return 0x30B3;
            case 0x04BB; return 0x30B5;
            case 0x04BC; return 0x30B7;
            case 0x04BD; return 0x30B9;
            case 0x04BE; return 0x30BB;
            case 0x04BF; return 0x30BD;
            case 0x04C0; return 0x30BF;
            case 0x04C1; return 0x30C1;
            case 0x04C2; return 0x30C4;
            case 0x04C3; return 0x30C6;
            case 0x04C4; return 0x30C8;
            case 0x04C5; return 0x30CA;
            case 0x04C6; return 0x30CB;
            case 0x04C7; return 0x30CC;
            case 0x04C8; return 0x30CD;
            case 0x04C9; return 0x30CE;
            case 0x04CA; return 0x30CF;
            case 0x04CB; return 0x30D2;
            case 0x04CC; return 0x30D5;
            case 0x04CD; return 0x30D8;
            case 0x04CE; return 0x30DB;
            case 0x04CF; return 0x30DE;
            case 0x04D0; return 0x30DF;
            case 0x04D1; return 0x30E0;
            case 0x04D2; return 0x30E1;
            case 0x04D3; return 0x30E2;
            case 0x04D4; return 0x30E4;
            case 0x04D5; return 0x30E6;
            case 0x04D6; return 0x30E8;
            case 0x04D7; return 0x30E9;
            case 0x04D8; return 0x30EA;
            case 0x04D9; return 0x30EB;
            case 0x04DA; return 0x30EC;
            case 0x04DB; return 0x30ED;
            case 0x04DC; return 0x30EF;
            case 0x04DD; return 0x30F3;
            case 0x04DE; return 0x309B;
            case 0x04DF; return 0x309C;
            case 0x05AC; return 0x060C;
            case 0x05BB; return 0x061B;
            case 0x05BF; return 0x061F;
            case 0x05C1; return 0x0621;
            case 0x05C2; return 0x0622;
            case 0x05C3; return 0x0623;
            case 0x05C4; return 0x0624;
            case 0x05C5; return 0x0625;
            case 0x05C6; return 0x0626;
            case 0x05C7; return 0x0627;
            case 0x05C8; return 0x0628;
            case 0x05C9; return 0x0629;
            case 0x05CA; return 0x062A;
            case 0x05CB; return 0x062B;
            case 0x05CC; return 0x062C;
            case 0x05CD; return 0x062D;
            case 0x05CE; return 0x062E;
            case 0x05CF; return 0x062F;
            case 0x05D0; return 0x0630;
            case 0x05D1; return 0x0631;
            case 0x05D2; return 0x0632;
            case 0x05D3; return 0x0633;
            case 0x05D4; return 0x0634;
            case 0x05D5; return 0x0635;
            case 0x05D6; return 0x0636;
            case 0x05D7; return 0x0637;
            case 0x05D8; return 0x0638;
            case 0x05D9; return 0x0639;
            case 0x05DA; return 0x063A;
            case 0x05E0; return 0x0640;
            case 0x05E1; return 0x0641;
            case 0x05E2; return 0x0642;
            case 0x05E3; return 0x0643;
            case 0x05E4; return 0x0644;
            case 0x05E5; return 0x0645;
            case 0x05E6; return 0x0646;
            case 0x05E7; return 0x0647;
            case 0x05E8; return 0x0648;
            case 0x05E9; return 0x0649;
            case 0x05EA; return 0x064A;
            case 0x05EB; return 0x064B;
            case 0x05EC; return 0x064C;
            case 0x05ED; return 0x064D;
            case 0x05EE; return 0x064E;
            case 0x05EF; return 0x064F;
            case 0x05F0; return 0x0650;
            case 0x05F1; return 0x0651;
            case 0x05F2; return 0x0652;
            case 0x06A1; return 0x0452;
            case 0x06A2; return 0x0453;
            case 0x06A3; return 0x0451;
            case 0x06A4; return 0x0454;
            case 0x06A5; return 0x0455;
            case 0x06A6; return 0x0456;
            case 0x06A7; return 0x0457;
            case 0x06A8; return 0x0458;
            case 0x06A9; return 0x0459;
            case 0x06AA; return 0x045A;
            case 0x06AB; return 0x045B;
            case 0x06AC; return 0x045C;
            case 0x06AD; return 0x0491;
            case 0x06AE; return 0x045E;
            case 0x06AF; return 0x045F;
            case 0x06B0; return 0x2116;
            case 0x06B1; return 0x0402;
            case 0x06B2; return 0x0403;
            case 0x06B3; return 0x0401;
            case 0x06B4; return 0x0404;
            case 0x06B5; return 0x0405;
            case 0x06B6; return 0x0406;
            case 0x06B7; return 0x0407;
            case 0x06B8; return 0x0408;
            case 0x06B9; return 0x0409;
            case 0x06BA; return 0x040A;
            case 0x06BB; return 0x040B;
            case 0x06BC; return 0x040C;
            case 0x06BD; return 0x0490;
            case 0x06BE; return 0x040E;
            case 0x06BF; return 0x040F;
            case 0x06C0; return 0x044E;
            case 0x06C1; return 0x0430;
            case 0x06C2; return 0x0431;
            case 0x06C3; return 0x0446;
            case 0x06C4; return 0x0434;
            case 0x06C5; return 0x0435;
            case 0x06C6; return 0x0444;
            case 0x06C7; return 0x0433;
            case 0x06C8; return 0x0445;
            case 0x06C9; return 0x0438;
            case 0x06CA; return 0x0439;
            case 0x06CB; return 0x043A;
            case 0x06CC; return 0x043B;
            case 0x06CD; return 0x043C;
            case 0x06CE; return 0x043D;
            case 0x06CF; return 0x043E;
            case 0x06D0; return 0x043F;
            case 0x06D1; return 0x044F;
            case 0x06D2; return 0x0440;
            case 0x06D3; return 0x0441;
            case 0x06D4; return 0x0442;
            case 0x06D5; return 0x0443;
            case 0x06D6; return 0x0436;
            case 0x06D7; return 0x0432;
            case 0x06D8; return 0x044C;
            case 0x06D9; return 0x044B;
            case 0x06DA; return 0x0437;
            case 0x06DB; return 0x0448;
            case 0x06DC; return 0x044D;
            case 0x06DD; return 0x0449;
            case 0x06DE; return 0x0447;
            case 0x06DF; return 0x044A;
            case 0x06E0; return 0x042E;
            case 0x06E1; return 0x0410;
            case 0x06E2; return 0x0411;
            case 0x06E3; return 0x0426;
            case 0x06E4; return 0x0414;
            case 0x06E5; return 0x0415;
            case 0x06E6; return 0x0424;
            case 0x06E7; return 0x0413;
            case 0x06E8; return 0x0425;
            case 0x06E9; return 0x0418;
            case 0x06EA; return 0x0419;
            case 0x06EB; return 0x041A;
            case 0x06EC; return 0x041B;
            case 0x06ED; return 0x041C;
            case 0x06EE; return 0x041D;
            case 0x06EF; return 0x041E;
            case 0x06F0; return 0x041F;
            case 0x06F1; return 0x042F;
            case 0x06F2; return 0x0420;
            case 0x06F3; return 0x0421;
            case 0x06F4; return 0x0422;
            case 0x06F5; return 0x0423;
            case 0x06F6; return 0x0416;
            case 0x06F7; return 0x0412;
            case 0x06F8; return 0x042C;
            case 0x06F9; return 0x042B;
            case 0x06FA; return 0x0417;
            case 0x06FB; return 0x0428;
            case 0x06FC; return 0x042D;
            case 0x06FD; return 0x0429;
            case 0x06FE; return 0x0427;
            case 0x06FF; return 0x042A;
            case 0x07A1; return 0x0386;
            case 0x07A2; return 0x0388;
            case 0x07A3; return 0x0389;
            case 0x07A4; return 0x038A;
            case 0x07A5; return 0x03AA;
            case 0x07A7; return 0x038C;
            case 0x07A8; return 0x038E;
            case 0x07A9; return 0x03AB;
            case 0x07AB; return 0x038F;
            case 0x07AE; return 0x0385;
            case 0x07AF; return 0x2015;
            case 0x07B1; return 0x03AC;
            case 0x07B2; return 0x03AD;
            case 0x07B3; return 0x03AE;
            case 0x07B4; return 0x03AF;
            case 0x07B5; return 0x03CA;
            case 0x07B6; return 0x0390;
            case 0x07B7; return 0x03CC;
            case 0x07B8; return 0x03CD;
            case 0x07B9; return 0x03CB;
            case 0x07BA; return 0x03B0;
            case 0x07BB; return 0x03CE;
            case 0x07C1; return 0x0391;
            case 0x07C2; return 0x0392;
            case 0x07C3; return 0x0393;
            case 0x07C4; return 0x0394;
            case 0x07C5; return 0x0395;
            case 0x07C6; return 0x0396;
            case 0x07C7; return 0x0397;
            case 0x07C8; return 0x0398;
            case 0x07C9; return 0x0399;
            case 0x07CA; return 0x039A;
            case 0x07CB; return 0x039B;
            case 0x07CC; return 0x039C;
            case 0x07CD; return 0x039D;
            case 0x07CE; return 0x039E;
            case 0x07CF; return 0x039F;
            case 0x07D0; return 0x03A0;
            case 0x07D1; return 0x03A1;
            case 0x07D2; return 0x03A3;
            case 0x07D4; return 0x03A4;
            case 0x07D5; return 0x03A5;
            case 0x07D6; return 0x03A6;
            case 0x07D7; return 0x03A7;
            case 0x07D8; return 0x03A8;
            case 0x07D9; return 0x03A9;
            case 0x07E1; return 0x03B1;
            case 0x07E2; return 0x03B2;
            case 0x07E3; return 0x03B3;
            case 0x07E4; return 0x03B4;
            case 0x07E5; return 0x03B5;
            case 0x07E6; return 0x03B6;
            case 0x07E7; return 0x03B7;
            case 0x07E8; return 0x03B8;
            case 0x07E9; return 0x03B9;
            case 0x07EA; return 0x03BA;
            case 0x07EB; return 0x03BB;
            case 0x07EC; return 0x03BC;
            case 0x07ED; return 0x03BD;
            case 0x07EE; return 0x03BE;
            case 0x07EF; return 0x03BF;
            case 0x07F0; return 0x03C0;
            case 0x07F1; return 0x03C1;
            case 0x07F2; return 0x03C3;
            case 0x07F3; return 0x03C2;
            case 0x07F4; return 0x03C4;
            case 0x07F5; return 0x03C5;
            case 0x07F6; return 0x03C6;
            case 0x07F7; return 0x03C7;
            case 0x07F8; return 0x03C8;
            case 0x07F9; return 0x03C9;
            case 0x08A1; return 0x23B7;
            case 0x08A4; return 0x2320;
            case 0x08A5; return 0x2321;
            case 0x08A7; return 0x23A1;
            case 0x08A8; return 0x23A3;
            case 0x08A9; return 0x23A4;
            case 0x08AA; return 0x23A6;
            case 0x08AB; return 0x239B;
            case 0x08AC; return 0x239D;
            case 0x08AD; return 0x239E;
            case 0x08AE; return 0x23A0;
            case 0x08AF; return 0x23A8;
            case 0x08B0; return 0x23AC;
            case 0x08BC; return 0x2264;
            case 0x08BD; return 0x2260;
            case 0x08BE; return 0x2265;
            case 0x08BF; return 0x222B;
            case 0x08C0; return 0x2234;
            case 0x08C1; return 0x221D;
            case 0x08C2; return 0x221E;
            case 0x08C5; return 0x2207;
            case 0x08C8; return 0x223C;
            case 0x08C9; return 0x2243;
            case 0x08CD; return 0x21D4;
            case 0x08CE; return 0x21D2;
            case 0x08CF; return 0x2261;
            case 0x08D6; return 0x221A;
            case 0x08DA; return 0x2282;
            case 0x08DB; return 0x2283;
            case 0x08DC; return 0x2229;
            case 0x08DD; return 0x222A;
            case 0x08DE; return 0x2227;
            case 0x08DF; return 0x2228;
            case 0x08EF; return 0x2202;
            case 0x08F6; return 0x0192;
            case 0x08FB; return 0x2190;
            case 0x08FC; return 0x2191;
            case 0x08FD; return 0x2192;
            case 0x08FE; return 0x2193;
            case 0x09E0; return 0x25C6;
            case 0x09E1; return 0x2592;
            case 0x09E2; return 0x2409;
            case 0x09E3; return 0x240C;
            case 0x09E4; return 0x240D;
            case 0x09E5; return 0x240A;
            case 0x09E8; return 0x2424;
            case 0x09E9; return 0x240B;
            case 0x09EA; return 0x2518;
            case 0x09EB; return 0x2510;
            case 0x09EC; return 0x250C;
            case 0x09ED; return 0x2514;
            case 0x09EE; return 0x253C;
            case 0x09EF; return 0x23BA;
            case 0x09F0; return 0x23BB;
            case 0x09F1; return 0x2500;
            case 0x09F2; return 0x23BC;
            case 0x09F3; return 0x23BD;
            case 0x09F4; return 0x251C;
            case 0x09F5; return 0x2524;
            case 0x09F6; return 0x2534;
            case 0x09F7; return 0x252C;
            case 0x09F8; return 0x2502;
            case 0x0AA1; return 0x2003;
            case 0x0AA2; return 0x2002;
            case 0x0AA3; return 0x2004;
            case 0x0AA4; return 0x2005;
            case 0x0AA5; return 0x2007;
            case 0x0AA6; return 0x2008;
            case 0x0AA7; return 0x2009;
            case 0x0AA8; return 0x200A;
            case 0x0AA9; return 0x2014;
            case 0x0AAA; return 0x2013;
            case 0x0AAE; return 0x2026;
            case 0x0AAF; return 0x2025;
            case 0x0AB0; return 0x2153;
            case 0x0AB1; return 0x2154;
            case 0x0AB2; return 0x2155;
            case 0x0AB3; return 0x2156;
            case 0x0AB4; return 0x2157;
            case 0x0AB5; return 0x2158;
            case 0x0AB6; return 0x2159;
            case 0x0AB7; return 0x215A;
            case 0x0AB8; return 0x2105;
            case 0x0ABB; return 0x2012;
            case 0x0AC3; return 0x215B;
            case 0x0AC4; return 0x215C;
            case 0x0AC5; return 0x215D;
            case 0x0AC6; return 0x215E;
            case 0x0AC9; return 0x2122;
            case 0x0AD0; return 0x2018;
            case 0x0AD1; return 0x2019;
            case 0x0AD2; return 0x201C;
            case 0x0AD3; return 0x201D;
            case 0x0AD4; return 0x211E;
            case 0x0AD5; return 0x2030;
            case 0x0AD6; return 0x2032;
            case 0x0AD7; return 0x2033;
            case 0x0AD9; return 0x271D;
            case 0x0AEC; return 0x2663;
            case 0x0AED; return 0x2666;
            case 0x0AEE; return 0x2665;
            case 0x0AF0; return 0x2720;
            case 0x0AF1; return 0x2020;
            case 0x0AF2; return 0x2021;
            case 0x0AF3; return 0x2713;
            case 0x0AF4; return 0x2717;
            case 0x0AF5; return 0x266F;
            case 0x0AF6; return 0x266D;
            case 0x0AF7; return 0x2642;
            case 0x0AF8; return 0x2640;
            case 0x0AF9; return 0x260E;
            case 0x0AFA; return 0x2315;
            case 0x0AFB; return 0x2117;
            case 0x0AFC; return 0x2038;
            case 0x0AFD; return 0x201A;
            case 0x0AFE; return 0x201E;
            case 0x0BC2; return 0x22A5;
            case 0x0BC4; return 0x230A;
            case 0x0BCA; return 0x2218;
            case 0x0BCC; return 0x2395;
            case 0x0BCE; return 0x22A4;
            case 0x0BCF; return 0x25CB;
            case 0x0BD3; return 0x2308;
            case 0x0BDC; return 0x22A2;
            case 0x0BFC; return 0x22A3;
            case 0x0CDF; return 0x2017;
            case 0x0CE0; return 0x05D0;
            case 0x0CE1; return 0x05D1;
            case 0x0CE2; return 0x05D2;
            case 0x0CE3; return 0x05D3;
            case 0x0CE4; return 0x05D4;
            case 0x0CE5; return 0x05D5;
            case 0x0CE6; return 0x05D6;
            case 0x0CE7; return 0x05D7;
            case 0x0CE8; return 0x05D8;
            case 0x0CE9; return 0x05D9;
            case 0x0CEA; return 0x05DA;
            case 0x0CEB; return 0x05DB;
            case 0x0CEC; return 0x05DC;
            case 0x0CED; return 0x05DD;
            case 0x0CEE; return 0x05DE;
            case 0x0CEF; return 0x05DF;
            case 0x0CF0; return 0x05E0;
            case 0x0CF1; return 0x05E1;
            case 0x0CF2; return 0x05E2;
            case 0x0CF3; return 0x05E3;
            case 0x0CF4; return 0x05E4;
            case 0x0CF5; return 0x05E5;
            case 0x0CF6; return 0x05E6;
            case 0x0CF7; return 0x05E7;
            case 0x0CF8; return 0x05E8;
            case 0x0CF9; return 0x05E9;
            case 0x0CFA; return 0x05EA;
            case 0x0DA1; return 0x0E01;
            case 0x0DA2; return 0x0E02;
            case 0x0DA3; return 0x0E03;
            case 0x0DA4; return 0x0E04;
            case 0x0DA5; return 0x0E05;
            case 0x0DA6; return 0x0E06;
            case 0x0DA7; return 0x0E07;
            case 0x0DA8; return 0x0E08;
            case 0x0DA9; return 0x0E09;
            case 0x0DAA; return 0x0E0A;
            case 0x0DAB; return 0x0E0B;
            case 0x0DAC; return 0x0E0C;
            case 0x0DAD; return 0x0E0D;
            case 0x0DAE; return 0x0E0E;
            case 0x0DAF; return 0x0E0F;
            case 0x0DB0; return 0x0E10;
            case 0x0DB1; return 0x0E11;
            case 0x0DB2; return 0x0E12;
            case 0x0DB3; return 0x0E13;
            case 0x0DB4; return 0x0E14;
            case 0x0DB5; return 0x0E15;
            case 0x0DB6; return 0x0E16;
            case 0x0DB7; return 0x0E17;
            case 0x0DB8; return 0x0E18;
            case 0x0DB9; return 0x0E19;
            case 0x0DBA; return 0x0E1A;
            case 0x0DBB; return 0x0E1B;
            case 0x0DBC; return 0x0E1C;
            case 0x0DBD; return 0x0E1D;
            case 0x0DBE; return 0x0E1E;
            case 0x0DBF; return 0x0E1F;
            case 0x0DC0; return 0x0E20;
            case 0x0DC1; return 0x0E21;
            case 0x0DC2; return 0x0E22;
            case 0x0DC3; return 0x0E23;
            case 0x0DC4; return 0x0E24;
            case 0x0DC5; return 0x0E25;
            case 0x0DC6; return 0x0E26;
            case 0x0DC7; return 0x0E27;
            case 0x0DC8; return 0x0E28;
            case 0x0DC9; return 0x0E29;
            case 0x0DCA; return 0x0E2A;
            case 0x0DCB; return 0x0E2B;
            case 0x0DCC; return 0x0E2C;
            case 0x0DCD; return 0x0E2D;
            case 0x0DCE; return 0x0E2E;
            case 0x0DCF; return 0x0E2F;
            case 0x0DD0; return 0x0E30;
            case 0x0DD1; return 0x0E31;
            case 0x0DD2; return 0x0E32;
            case 0x0DD3; return 0x0E33;
            case 0x0DD4; return 0x0E34;
            case 0x0DD5; return 0x0E35;
            case 0x0DD6; return 0x0E36;
            case 0x0DD7; return 0x0E37;
            case 0x0DD8; return 0x0E38;
            case 0x0DD9; return 0x0E39;
            case 0x0DDA; return 0x0E3A;
            case 0x0DDF; return 0x0E3F;
            case 0x0DE0; return 0x0E40;
            case 0x0DE1; return 0x0E41;
            case 0x0DE2; return 0x0E42;
            case 0x0DE3; return 0x0E43;
            case 0x0DE4; return 0x0E44;
            case 0x0DE5; return 0x0E45;
            case 0x0DE6; return 0x0E46;
            case 0x0DE7; return 0x0E47;
            case 0x0DE8; return 0x0E48;
            case 0x0DE9; return 0x0E49;
            case 0x0DEA; return 0x0E4A;
            case 0x0DEB; return 0x0E4B;
            case 0x0DEC; return 0x0E4C;
            case 0x0DED; return 0x0E4D;
            case 0x0DF0; return 0x0E50;
            case 0x0DF1; return 0x0E51;
            case 0x0DF2; return 0x0E52;
            case 0x0DF3; return 0x0E53;
            case 0x0DF4; return 0x0E54;
            case 0x0DF5; return 0x0E55;
            case 0x0DF6; return 0x0E56;
            case 0x0DF7; return 0x0E57;
            case 0x0DF8; return 0x0E58;
            case 0x0DF9; return 0x0E59;
            case 0x13BC; return 0x0152;
            case 0x13BD; return 0x0153;
            case 0x13BE; return 0x0178;
            case 0x20AC; return 0x20AC;
            case; return 0;
        }
    }

    if keysym == {
        case XK_KP_Equal;     return xx #char "=";
        case XK_KP_Enter;     return 0x10;
        case XK_KP_Multiply;  return xx #char "*";
        case XK_KP_Add;       return xx #char "+";
        case XK_KP_Separator; return xx #char ",";  // ??
        case XK_KP_Subtract;  return xx #char "-";
        case XK_KP_Decimal;   return xx #char ".";  // ??
        case XK_KP_Divide;    return xx #char "/";
        case XK_KP_0;         return xx #char "0";
        case XK_KP_1;         return xx #char "1";
        case XK_KP_2;         return xx #char "2";
        case XK_KP_3;         return xx #char "3";
        case XK_KP_4;         return xx #char "4";
        case XK_KP_5;         return xx #char "5";
        case XK_KP_6;         return xx #char "6";
        case XK_KP_7;         return xx #char "7";
        case XK_KP_8;         return xx #char "8";
        case XK_KP_9;         return xx #char "9";
    }

    return 0;
}

/*
 * Copyright 2021, Thekla, Inc (portions of this code, dealing with Xdnd, are copyright Jens Frederich).
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
 * documentation files (the "Software"), to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software,
 * and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 *
 *     The above copyright notice and this permission notice shall be included in all copies or substantial portions
 *     of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO
 * THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */
