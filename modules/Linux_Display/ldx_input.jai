x11_translate_key_code :: (xkey: X11.KeySym) -> Input.Key_Code {
    using Input.Key_Code;
    using X11.Known_Keysyms;

    key := cast(X11.Known_Keysyms)xkey;

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
    if key == XK_Return
        return ENTER;
    if (key == XK_Control_L) || (key == XK_Control_R)
        return CTRL;
    if (key == XK_Alt_L) || (key == XK_Alt_R) || (key == XK_ISO_Level3_Shift)
        return .ALT;
    if (key == XK_Meta_L) || (key == XK_Meta_R)
        return .META;
    if key == XK_BackSpace
        return BACKSPACE;
    if key == XK_Delete || key == XK_KP_Delete
        return DELETE;
    if key == XK_Tab || key == XK_KP_Tab || key == XK_ISO_Left_Tab
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
    if key == XK_F17
        return F17;
    if key == XK_F18
        return F18;
    if key == XK_F19
        return F19;
    if key == XK_F20
        return F20;
    if key == XK_F21
        return F21;
    if key == XK_F22
        return F22;
    if key == XK_F23
        return F23;
    if key == XK_F24
        return F24;
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

    if key == XK_KP_Enter
        return NUMPAD_ENTER;
    if key == XK_KP_Multiply
        return NUMPAD_MULTIPLY;
    if key == XK_KP_Add
        return NUMPAD_ADD;
    if key == XK_KP_Subtract
        return NUMPAD_SUBTRACT;
    if key == XK_KP_Decimal
        return NUMPAD_DECIMAL;
    if key == XK_KP_Divide
        return NUMPAD_DIVIDE;
    if key == XK_KP_0
        return NUMPAD_0;
    if key == XK_KP_1
        return NUMPAD_1;
    if key == XK_KP_2
        return NUMPAD_2;
    if key == XK_KP_3
        return NUMPAD_3;
    if key == XK_KP_4
        return NUMPAD_4;
    if key == XK_KP_5
        return NUMPAD_5;
    if key == XK_KP_6
        return NUMPAD_6;
    if key == XK_KP_7
        return NUMPAD_7;
    if key == XK_KP_8
        return NUMPAD_8;
    if key == XK_KP_9
        return NUMPAD_9;

    key = key & 0xFF;
    if (key >= #char "a") && (key <= #char "z") return cast(Input.Key_Code) (key - 0x20);
    if key > 32 && key < 127 return cast(Input.Key_Code) key;

    return UNKNOWN;
}

x11_wait_for_events :: (display: *Display) {
    x11_check_usage(display);

    x11_display: *X11_Display = display;
    xev: X11.XEvent;
    needs_flush := true;
    while true {
        // If this returns non-zero, we already know for a fact that there are some
        // events that we need to handle, so just don't bother with a poll
        if X11.XQLength(x11_display.handle) {
            break;
        }

        if needs_flush X11.XFlush(x11_display.handle);

        pfd: [3]pollfd;
        pfd[0].fd = x11_display.file_descriptor;
        pfd[0].events = POLLIN;
        pfd[1].fd = timers_epfd;
        pfd[1].events = POLLIN;
        pfd[2].fd = display.base.loop_wakeup_event;
        pfd[2].events = POLLIN;
        result := poll(pfd.data, xx pfd.count, -1);

        if result < 0 {
            error := errno();
            if error == EINTR {
                // A signal occurred before any event, retry
                continue;
            }
            // Returning on other errors. If one of these happens the application
            // is most likely to crash anyway
            if error == EINVAL {
                log_error("Can't poll on X11 file descriptor. Max amount of opened file descriptors (RLIMIT_NOFILE) exceeded.\n");
            } else if error == ENOMEM {
                log_error("poll(2) failed with ENOMEM - it is unable to allocate memory for its internal use\n");
            } else if error == EFAULT {
                log_error("X11 poll is configured incorrectly - file descriptors are outside of the accessible address space\n");
            } else {
                log_error("Unknown error happened while waiting on X11 file descriptor. Error code: %\n", error);
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
            queue_length := X11.XPending(x11_display.handle);

            if queue_length == 0 {
                // We don't need to do XFlush at the start of the next wait iteration
                // because XPending does one if the queue is empty
                needs_flush = false;
                continue;
            }
            break;
        }
        needs_flush = true;
    }
}

// Catch all events
x11_event_predicate :: (display: *X11.Display, event: *X11.XEvent, *void) -> s32 #c_call {
    return 1;
}

x11_update_window_events :: (display: *Display) {
    x11_check_usage(display);

    x11_display: *X11_Display = display;

    xev: X11.XEvent;
    // Some things in X11 happen across multiple events, and it
    // doesn't make much sense to draw in-between. For example, clipboard handling.
    // Other programs can send (and expect) a sequence of events just to pass the clipboard around.
    // Chromium (and its children) is particularly notorious for initiating a  big series of clipboard
    // events, and if we draw on every event then pasting into other program from Focus becomes slow.
    // So instead event handler says that it expects more events to come, so we don't release the
    // event loop right away and instead wait for more events.
    // We don't want to wait forever though, so we'll release the loop either if some other event arrives
    // that doesn't expect other events, or at most after a second,
    // so some buggy program doesn't hang the editor while handling our clipboard response.
    expect_more_events := false;
    start_time := seconds_since_init();
    elapsed_time := start_time;

    while X11.XPending(x11_display.handle) || (expect_more_events && elapsed_time < 1.0) {
        result := X11.XCheckIfEvent(x11_display.handle, *xev, x11_event_predicate, null);
        if result {
            expect_more_events = x11_handle_event(x11_display, *xev);
            timers_tick();
        }
        elapsed_time = seconds_since_init() - start_time;
    }
}

x11_handle_event :: (x11_display: *X11_Display, xev: *X11.XEvent) -> expect_more_events: bool = false {
    using Input.Key_Code;

    display := x11_display.handle;
    // expect_more_events := false;

    if X11.XFilterEvent(xev, X11.None) return;

    ld_win := get_by_native_handle(xx x11_display, xx xev.xany.window);
    if ld_win == INVALID_WINDOW return;
    win: *X11_Window = ld_win;

    if xev.type == {
        case X11.ClientMessage;
            message_type := xev.xclient.message_type;
            if message_type == x11_display.global_atoms.XdndEnter {
                drop_handled := maybe_handle_xdnd_drop_events(x11_display, xev);
                if drop_handled  return;
            } else if message_type == x11_display.global_atoms.WM_PROTOCOLS {
                message0 := cast(X11.Atom) xev.xclient.data.l[0];

                // This can't be a switch, because the values are not constant!
                // Except come on guys, every single implementation of X11 in the universe
                // is going to agree on these values. Why are we pretending they are not constant?
                // How about if we just look them up once and then hardcode them into this program?
                // We'd save startup time...

                if message0 == x11_display.global_atoms.WM_DELETE_WINDOW {
                    event: Input.Event;
                    event.type = .QUIT;
                    array_add(*x11_display.base.events_this_frame, event);
                }
            }

        case X11.KeyPress;
            event: Input.Event;
            status: X11.Status;
            keysym: X11.KeySym;
            text: [16]u32;   // surely enough for everybody
            count := X11.XwcLookupString(win.ic, *xev.xkey, text.data, xx text.count, *keysym, *status);

            has_keysym := (status == X11.XLookupKeySym || status == X11.XLookupBoth);
            has_text := (status == X11.XLookupChars || status == X11.XLookupBoth);

            if has_keysym {
                assert(keysym != 0);

                if xev.xkey.state & X11.ShiftMask   event.shift_pressed = true;
                if xev.xkey.state & X11.ControlMask event.ctrl_pressed = true;
                if xev.xkey.state & X11.Mod1Mask    event.alt_pressed = true;
                if xev.xkey.state & X11.Mod4Mask    event.cmd_meta_pressed = true;

                event.type = .KEYBOARD;
                event.key_pressed = 1;
                event.key_code = x11_translate_key_code(keysym);
                for 0..count - 1 {
                    utf32 := text[it];
                    if utf32 >= 32 && utf32 != 127 event.text_input_count += 1;
                }

                if event.key_code == {
                    case .SHIFT; event.shift_pressed = true;
                    case .CTRL;  event.ctrl_pressed = true;
                    case .ALT;   event.alt_pressed = true;
                    case .META;  event.cmd_meta_pressed = true;
                }

                array_add(*x11_display.base.events_this_frame, event);

                x11_display.base.input_button_states[event.key_code] = (Input.Key_Current_State.START | Input.Key_Current_State.DOWN);
            }

            if has_text {
                assert(count > 0);

                for 0..count - 1 {
                    utf32 := text[it];
                    if utf32 < 32 || utf32 == 127 continue;

                    text_event: Input.Event;
                    text_event.type = .TEXT_INPUT;
                    text_event.key_pressed = 1;
                    text_event.key_code = x11_translate_key_code(keysym);
                    text_event.utf32 = utf32;
                    array_add(*x11_display.base.events_this_frame, text_event);
                }
            }

        case X11.KeyRelease;
            // For some odd reason X11 generates KeyRelease followed by a near identical KeyPress to simulate repeat events so we have to filter that out
            if X11.XEventsQueued(display, X11.QueuedAfterReading) {
                nev: X11.XEvent;
                X11.XPeekEvent(display, *nev);

                if nev.type == X11.KeyPress
                    && nev.xkey.time == xev.xkey.time
                    && nev.xkey.keycode == xev.xkey.keycode {

                    // This is a repeat, so we ignore the KeyRelease.
                    return;
                }
            }

            event: Input.Event;
            keysym := X11.XLookupKeysym(*xev.xkey, 0);
            if keysym != X11.NoSymbol {
                assert(keysym != 0);

                if xev.xkey.state & X11.ShiftMask   event.shift_pressed = true;
                if xev.xkey.state & X11.ControlMask event.ctrl_pressed = true;
                if xev.xkey.state & X11.Mod1Mask    event.alt_pressed = true;

                event.type = .KEYBOARD;
                event.key_pressed = 0;
                event.key_code = x11_translate_key_code(keysym);

                if event.key_code == {
                    case .SHIFT; event.shift_pressed = true;
                    case .CTRL;  event.ctrl_pressed = true;
                    case .ALT;   event.alt_pressed = true;
                    case .META;  event.cmd_meta_pressed = true;
                }

                array_add(*x11_display.base.events_this_frame, event);

                x11_display.base.input_button_states[event.key_code] = Input.Key_Current_State.END;
            }

        case X11.ButtonPress;
            event: Input.Event;
            button := xev.xbutton.button;

            if button == {
                case 4; #through;
                case 5;
                    event.type = .MOUSE_V_WHEEL;
                    event.typical_wheel_delta = WHEEL_DELTA;
                    event.wheel_delta = WHEEL_DELTA * (ifx (button & 0x01) then cast(s32) -1 else 1);
                    array_add(*x11_display.base.events_this_frame, event);
                    x11_display.base.mouse_wheel_delta.vertical += event.wheel_delta;
                    return;

                case 6; #through;
                case 7;
                    event.type = .MOUSE_H_WHEEL;
                    event.typical_wheel_delta = WHEEL_DELTA;
                    event.wheel_delta = WHEEL_DELTA * (ifx (button & 0x01) then cast(s32) -1 else 1);
                    array_add(*x11_display.base.events_this_frame, event);
                    x11_display.base.mouse_wheel_delta.horizontal += event.wheel_delta;
                    return;

                case 8; event.key_code = .MOUSE_BUTTON_X1;
                case 9; event.key_code = .MOUSE_BUTTON_X2;
            }

            event.type = .KEYBOARD;
            event.key_pressed = 1;
            if button == X11.Button1 {
                event.key_code = MOUSE_BUTTON_LEFT;
            } else if button == X11.Button2 {
                event.key_code = MOUSE_BUTTON_MIDDLE;
            } else if button == X11.Button3 {
                event.key_code = MOUSE_BUTTON_RIGHT;
            }

            x11_display.base.input_button_states[event.key_code] = (Input.Key_Current_State.START | Input.Key_Current_State.DOWN);

            array_add(*x11_display.base.events_this_frame, event);

        case X11.ButtonRelease;
            // it seems that mouse input doesnt generate repeat events so we dont have to peek the queue
            event: Input.Event;
            button := xev.xbutton.button;

            // Buttons above 4 are scroll wheel events, we don't care about release events for them
            if button >= 4 return;

            event.type = .KEYBOARD;
            event.key_pressed = 0;
            if button == X11.Button1 {
                event.key_code = MOUSE_BUTTON_LEFT;
            } else if button == X11.Button2 {
                event.key_code = MOUSE_BUTTON_MIDDLE;
            } else if button == X11.Button3 {
                event.key_code = MOUSE_BUTTON_RIGHT;
            }

            x11_display.base.input_button_states[event.key_code] = Input.Key_Current_State.END;

            array_add(*x11_display.base.events_this_frame, event);

        case X11.SelectionRequest;
            selreq := cast(*X11.XSelectionRequestEvent) xev;

            out: X11.XEvent;
            selnot := cast(*X11.XSelectionEvent) *out;
            selnot.type = X11.SelectionNotify;
            selnot.requestor = selreq.requestor;
            selnot.selection = selreq.selection;
            selnot.target = selreq.target;
            selnot.time = selreq.time;
            selnot.property = X11.None;

            if get_by_native_handle(xx x11_display, xx selreq.owner) != INVALID_WINDOW {
                if selreq.target == x11_display.global_atoms.UTF8_STRING {
                    selnot.property = selreq.property;

                    text_data := x11_display.clipboard_text;
                    X11.XChangeProperty(
                        selreq.display, selreq.requestor, selreq.property, selreq.target, 8, X11.PropModeReplace,
                        text_data.data, cast(s32) text_data.count);
                } else if selreq.target == x11_display.global_atoms.TARGETS {
                    selnot.property = selreq.property;

                    atoms: [..] X11.Atom;
                    array_add(*atoms, x11_display.global_atoms.UTF8_STRING);
                    array_add(*atoms, x11_display.global_atoms.TARGETS);
                    array_add(*atoms, x11_display.global_atoms.MULTIPLE);
                    X11.XChangeProperty(
                        selreq.display,
                        selreq.requestor,
                        selreq.property,
                        x11_display.global_atoms.ATOM, 32, X11.PropModeReplace,
                        xx atoms.data, cast(s32) atoms.count);

                    array_reset(*atoms);
                }
            }

            X11.XSendEvent(selreq.display, selreq.requestor, X11.True, 0, *out);
            return true;

        case X11.ConfigureNotify;
            config := cast(*X11.XConfigureEvent) xev;
            ld_win := get_by_native_handle(xx x11_display, xx config.window);
            if ld_win Input.add_resize_record(ld_win, config.width, config.height);
        // Adding a dummy event to the queue, forcing a redraw when window's focus
        // changes or it gets exposed (e.g. it's being asked to render itself but without
        // it getting focus)
        case X11.FocusIn;
            Input.input_application_has_focus = true;
            X11.XSetICFocus(win.ic);
            array_add(*x11_display.base.events_this_frame, .{type=.WINDOW});
        case X11.FocusOut;
            Input.input_application_has_focus = false;
            X11.XUnsetICFocus(win.ic);
            array_add(*x11_display.base.events_this_frame, .{type=.WINDOW});
        case X11.Expose;
            array_add(*x11_display.base.events_this_frame, .{type=.WINDOW});
    }
    return;
}

x11_clipboard_get_text :: (display: *Display) -> string {
    x11_check_usage(display);

    xd := *display.x11;

    dpy := xd.handle;
    if !dpy return "";
    win: X11.Window;
    revert: s32;
    X11.XGetInputFocus(dpy, *win, *revert);

    text: string;
    selection_owner := X11.XGetSelectionOwner(dpy, xd.global_atoms.CLIPBOARD);

    // if we created the window then we pull directly from our own locat clipbuffer
    if get_by_native_handle(display, xx selection_owner) != INVALID_WINDOW {
        return copy_string(xd.clipboard_text);
    } else if selection_owner != X11.None {
        property := X11.XInternAtom(dpy, "JAI_SELECTION", X11.False);
        X11.XConvertSelection(dpy,
            xd.global_atoms.CLIPBOARD,
            xd.global_atoms.UTF8_STRING,
            property,
            win,
            X11.CurrentTime);

        sleep_milliseconds(1);

        selection_notify_predicate :: (display: *X11.Display, event: *X11.XEvent, arg: X11.XPointer) -> X11.Bool #c_call {
            if event.type == X11.SelectionNotify {
                ev := cast(*X11.XSelectionEvent) event;
                if ev.requestor == (cast(*X11.Window)arg).*
                    return X11.True;
            }
            return X11.False;
        }

        // @Warning this will block until we recive a notification back from the selection owner
        xev: X11.XEvent;
        X11.XIfEvent(dpy, xx *xev, selection_notify_predicate, *win);

        if (cast(*X11.XSelectionEvent) *xev).property == X11.None then return text;

        nitems, rem: u64;
        format: s32;
        data: *u8;
        type: X11.Atom;
        if X11.XGetWindowProperty(dpy, win, property, 0, ~0, X11.True, X11.AnyPropertyType, *type, *format, *nitems, *rem, *data) == 0 {
            assert(rem == 0); // to be sure we get all the bytes and there are no remaining bytes
            if (type == xd.global_atoms.UTF8_STRING && format == 8) {
                temp: string;
                temp.data = data;
                temp.count = xx nitems;
                text = copy_string(temp);
                X11.XFree(data);
                return text;
            } else {
                // @Incomplete: megabytes of text are sent in a different format which is not supported yet
            }
        }
    }

    return text;
}

x11_clipboard_set_text :: (display: *Display, text: string) {
    x11_check_usage(display);

    dpy := display.x11.handle;
    if !dpy return;
    win: X11.Window;
    revert: s32;
    X11.XGetInputFocus(dpy, *win, *revert);

    X11.XSetSelectionOwner(dpy, display.x11.global_atoms.CLIPBOARD, win, X11.CurrentTime);
    owner := X11.XGetSelectionOwner(dpy, display.x11.global_atoms.CLIPBOARD);
    if owner != win return;

    X11.XLockDisplay(dpy);
    free(display.x11.clipboard_text);
    display.x11.clipboard_text.data = null;
    display.x11.clipboard_text.count = 0;
    display.x11.clipboard_text = copy_string(text);
    X11.XUnlockDisplay(dpy);
}

#scope_file
// Xdnd support by Jens Frederich. Send questions his way. Licensed under the MIT license; see copyright at the end
// of the file.

get_position_root_x :: inline (xevent: *X11.XEvent) -> s32 {
    return cast(s32) xevent.xclient.data.l[2] >> 16;
}

get_position_root_y :: inline (xevent: *X11.XEvent) -> s32 {
    return cast(s32) xevent.xclient.data.l[2] & 0xffff;
}

apply_position :: (x11_display: *X11_Display, widget: X11.Window, from: X11.Window, action: X11.Atom, x: s32, y: s32, time: X11.Time, typelist: [] X11.Atom, want_position: *bool, supported_action_return: *X11.Atom, desired_type: *X11.Atom, rectangle: *X11.XRectangle) -> bool {
    dnd := *x11_display.xdnd_context;
    supported_type: X11.Atom;
    supported_action: X11.Atom;

    dropper_typelist  := x11_display.drop_info.user_typelist;
    supported_actions := x11_display.drop_info.user_actions;

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
        if action == x11_display.global_atoms.XdndActionCopy  supported_action = action;
    }

    if !supported_action  return false;

    want_position.* = true;
    rectangle.x = 0;
    rectangle.y = 0;
    rectangle.width = 0;
    rectangle.height = 0;

    x11_display.drop_info.return_action = supported_action;
    x11_display.drop_info.return_type = supported_type;
    x11_display.drop_info.x = x;
    x11_display.drop_info.y = y;
    supported_action_return.* = supported_action;
    desired_type.* = supported_type;

    return true;
}

send_finished :: (x11_display: *X11_Display, window: X11.Window, from: X11.Window) {
    display := x11_display.handle;
    xevent: X11.XEvent;
    xevent.xany.type = X11.ClientMessage;
    xevent.xany.display = display;
    xevent.xclient.window = window;
    xevent.xclient.message_type = x11_display.global_atoms.XdndFinished;
    xevent.xclient.format = 32;

    // target window
    xevent.xclient.data.l[0] = cast(s64) from;

    X11.XSendEvent(display, window, 0, 0, *xevent);
}

send_status :: (x11_display: *X11_Display, window: X11.Window, from: X11.Window, will_accept: bool, want_position: bool, x: int, y: int, w: int, h: int, action: X11.Atom) {
    display := x11_display.handle;
    xevent: X11.XEvent;
    xevent.xany.type = X11.ClientMessage;
    xevent.xany.display = display;
    xevent.xclient.window = window;
    xevent.xclient.message_type = x11_display.global_atoms.XdndStatus;
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

    X11.XSendEvent(display, window, 0, 0, *xevent);
}

paste_property :: (x11_display: *X11_Display, from: X11.Window, insert: X11.Window, prop: u64, delete_prop: s64) -> bool {
    display := x11_display.handle;
    nread: s64;
    data_count: s64;
    bytes_after: s64;
    error: bool;

    array_reset(*x11_display.drop_info.data);
    while true {
        actual_type: X11.Atom;
        actual_fmt: s32;
        data: *u8;

        x := nread / 4;

        if X11.XGetWindowProperty(display, insert, prop, xx x , 65536, xx delete_prop, X11.AnyPropertyType, *actual_type, *actual_fmt, xx *data_count, xx *bytes_after, *data) != X11.Success {
            X11.XFree(data);
            return false;
        }

        nread += data_count;

        if (x11_display.drop_info.data.count == 0) {
            array_reserve(*x11_display.drop_info.data, data_count + bytes_after);
        }
        memcpy(x11_display.drop_info.data.data + x11_display.drop_info.data.count, data, data_count);
        x11_display.drop_info.data.count += data_count;

        X11.XFree(data);

        if bytes_after == 0  break;
    }

    if !nread  return false;

    return true;
}

get_selection :: (x11_display: *X11_Display, from: X11.Window, prop: X11.Atom, insert: X11.Window) -> bool {
    display := x11_display.handle;
    if prop == X11.None  return false;

    actual_type: X11.Atom;
    actual_fmt: s32;
    nitems: u64;
    bytes_after: u64;
    s: *u8;
    if (X11.XGetWindowProperty(display, insert, prop, 0, 8, X11.False, X11.AnyPropertyType, *actual_type, *actual_fmt, *nitems, *bytes_after, *s) != X11.Success) {
        X11.XFree(s);
        return false;
    }

    X11.XFree(s);
    if actual_type != X11.XInternAtom(display, "INCR", X11.False) {
        return paste_property(x11_display, from, insert, prop, X11.True);
    }

    X11.XDeleteProperty(display, insert, prop);

    /* @Cleanup: Get rid of fd_set stuff.
    time_start := seconds_since_init();
    while true {
        r: fd_set;
        xe: XEvent;
        if XCheckMaskEvent(display, PropertyChangeMask, *xe) {
            if xe.type == PropertyNotify && xe.xproperty.state == PropertyNewValue {
                // time between arrivals of data
                time_start = seconds_since_init();
                if paste_property(display, from, insert, prop, True)  break;
            }
        } else {
            FD_ZERO(*r);
            FD_SET(ConnectionNumber(display), *r);
            select(ConnectionNumber(display) + 1, *r, 0, 0, *tv);

            if FD_ISSET(ConnectionNumber(display), *r)  continue;
        }
        end := seconds_since_init();

        // no data for five seconds, so quit
        if end - start > 5000000  return false;
    }
    */
    return true;
}

maybe_handle_xdnd_drop_events :: (x11_display: *X11_Display, xevent: *X11.XEvent) -> bool {
    display := x11_display.handle;
    assert(xevent.type == X11.ClientMessage);
    assert(xevent.xclient.message_type == x11_display.global_atoms.XdndEnter);

    dnd := *x11_display.xdnd_context;
    drop_info := *x11_display.drop_info;
    dnd.root_window = X11.DefaultRootWindow(display);

    while true {
        if xevent.type == X11.ClientMessage {
            if xevent.xclient.message_type == x11_display.global_atoms.XdndEnter {
                version := xevent.xclient.data.l[1] >> 24;
                if version < 3  return false;

                X11.xdnd_context_reset(dnd);
                dnd.dragger_window = cast(X11.Window) xevent.xclient.data.l[0];
                dnd.dropper_toplevel = xevent.xany.window;
                dnd.dropper_window = 0;  // Enter goes to the top level window only, so we don't really know what the sub window is yet.

                support_more_than_three_types := xevent.xclient.data.l[1] & 0x1;
                if !support_more_than_three_types {
                    for 0..2 {
                        atom := cast(X11.Atom) xevent.xclient.data.l[2 + it];
                        array_add(*dnd.dragger_typelist, atom);
                    }
                } else {
                    array_reset(*dnd.dragger_typelist);

                    type: X11.Atom;
                    format: s32;
                    count, remaining: u64;
                    data: *u8 = null;
                    X11.XGetWindowProperty(
                        display,
                        dnd.dragger_window,
                        x11_display.global_atoms.XdndTypeList,
                        0, 0x8000000,
                        X11.False,
                        X11.XA_ATOM,
                        *type, *format, *count, *remaining, *data);

                    if type != X11.XA_ATOM || format != 32 || count == 0 || data == null {
                        print("XGetWindowProperty failed in get type list\n");
                    }

                    atom_data: *X11.Atom = cast(*X11.Atom) data;
                    for 0..count {
                        array_add(*dnd.dragger_typelist, atom_data[it]);
                    }

                    X11.XFree(data);
                }

                if dnd.dragger_typelist {
                    dnd.stage = X11.Xdnd_Stage.DROP_ENTERED;
                } else {
                    print("      typelist returned as zero!\n");
                }
            } else if xevent.xclient.message_type == x11_display.global_atoms.XdndLeave {
                source_window := cast(u64) xevent.xclient.data.l[0];
                if dnd.dragger_window == source_window && dnd.stage == X11.Xdnd_Stage.DROP_ENTERED {
                    dnd.stage = X11.Xdnd_Stage.DROP_IDLE;
                    array_reset(*dnd.dragger_typelist);
                    dnd.dropper_toplevel = 0;
                    dnd.dropper_window = 0;
                } else {
                    print("    wrong stage or from wrong window\n");
                }
            } else if xevent.xclient.message_type == x11_display.global_atoms.XdndPosition {
                action: X11.Atom;
                rectangle: X11.XRectangle;
                want_position: bool;
                last_window: X11.Window;

                source_window := cast(u64) xevent.xclient.data.l[0];
                if dnd.dragger_window == source_window && dnd.stage == X11.Xdnd_Stage.DROP_ENTERED {
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
                            new_child: X11.Window;
                            if !X11.XTranslateCoordinates(display, parent, child, root_x, root_y, *xd, *yd, *new_child)  break;
                            if !new_child  break;

                            child = new_child;
                        }

                        dnd.dropper_window = child;
                        xevent.xany.window = child;
                    } else if xevent.xany.window == dnd.dropper_toplevel && dnd.dropper_window {
                        xevent.xany.window = dnd.dropper_window;
                    }

                    action := x11_display.global_atoms.XdndActionCopy;
                    dnd.supported_action = x11_display.global_atoms.XdndActionCopy;
                    dnd.x = get_position_root_x(xevent);
                    dnd.y = get_position_root_y(xevent);
                    dnd.time = X11.CurrentTime;

                    dnd.will_accept = apply_position(x11_display, xevent.xany.window, dnd.dragger_window, action, dnd.x, dnd.y, dnd.time, dnd.dragger_typelist, *want_position, *dnd.supported_action, *dnd.desired_type, *rectangle);
                    send_status(x11_display, dnd.dragger_window, dnd.dropper_toplevel, dnd.will_accept, want_position, rectangle.x, rectangle.y, rectangle.width, rectangle.height, dnd.supported_action);
                } else {
                    print("    wrong stage or from wrong window\n");
                }
            } else if xevent.xclient.message_type == x11_display.global_atoms.XdndDrop {
                if xevent.xany.window == dnd.dropper_toplevel && dnd.dropper_window {
                    xevent.xany.window = dnd.dropper_window;
                }

                source_window := cast(u64) xevent.xclient.data.l[0];
                if dnd.dragger_window == source_window && dnd.stage == X11.Xdnd_Stage.DROP_ENTERED {
                    dnd.time = X11.CurrentTime;
                    if dnd.will_accept {
                        // convert selection
                        {
                            dnd.dragger_window = X11.XGetSelectionOwner(display, x11_display.global_atoms.XdndSelection);
                            if !dnd.dragger_window {
                                print(" XGetSelectionOwner failed\n");
                            } else {
                                X11.XConvertSelection(
                                    display,
                                    x11_display.global_atoms.XdndSelection,
                                    dnd.desired_type,
                                    x11_display.global_atoms._DUMMY,
                                    dnd.dropper_window,
                                    X11.CurrentTime);
                            }
                        }

                        dnd.stage = X11.Xdnd_Stage.DROP_CONVERTING;
                    } else {
                        print("    will_accept is false - sending finished\n");
                        send_finished(x11_display, dnd.dragger_window, dnd.dropper_toplevel);

                        array_reset(*dnd.dragger_typelist);
                        X11.xdnd_context_reset(dnd);
                        dnd.stage = X11.Xdnd_Stage.DROP_IDLE;
                    }
                } else {
                    print("    wrong stage or from wrong window\n");
                }
            }
        } else if xevent.type == X11.SelectionNotify {
            if xevent.xselection.property == x11_display.global_atoms._DUMMY && dnd.stage == X11.Xdnd_Stage.DROP_CONVERTING {
                error := get_selection(x11_display, dnd.dragger_window, xevent.xselection.property, xevent.xany.window);
                // Error is not actually used, I think future versions of the protocol maybe should return an error status to the calling window with the XdndFinished client message.

                send_finished(x11_display, dnd.dragger_window, dnd.dropper_toplevel);

                array_reset(*dnd.dragger_typelist);
                X11.xdnd_context_reset(dnd);
                dnd.stage = X11.Xdnd_Stage.DROP_IDLE;
            } else {
                print("  property is not Xdnd_NON_PROTOCOL_ATOM - ignoring\n");
            }
        }

        if dnd.stage == X11.Xdnd_Stage.DROP_IDLE  break;

        X11.XNextEvent(display, xevent);
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
            file_name_bytes := cast(*u8) alloc(i,, allocator = temp);
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
        array_add(*x11_display.base.events_this_frame, event);

        array_reset(*drop_info.data);
        return true;
    }

    return false;
}

#scope_file
#import "POSIX";
#import "String";
