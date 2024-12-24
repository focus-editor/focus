#import "Windows";
#import "Windows_Utf8";
#import "Hash_Table";


//
// @Incomplete @Robustness: We should check whichever flags Windows gives us automatically
// in the event data (e.g. is control held, is shift held, etc)... rather than maintaining
// our own per-frame state... the "is ctrl held down" variables should just be informational
// to the outside user.
//

window_minimized := false; // @@ Hack.

set_custom_cursor_handling :: (is_custom: bool) {
    // Use this if you are doing immediate-mode API stuff that sets cursors and want to prevent cursors from flickering. Windows is annoying to interface with.
    windows_ignore_setcursor_messages = is_custom;
}

//#scope_export

get_key_code :: (wParam: WPARAM, extended := false) -> Key_Code {
    if (wParam >= 48) && (wParam <= 90) return cast(Key_Code) wParam;

    using Key_Code;

    if wParam == VK_LBUTTON
        return MOUSE_BUTTON_LEFT;
    if wParam == VK_MBUTTON
        return MOUSE_BUTTON_MIDDLE;
    if wParam == VK_RBUTTON
        return MOUSE_BUTTON_RIGHT;
    if wParam == VK_XBUTTON1
        return MOUSE_BUTTON_X1;
    if wParam == VK_XBUTTON2
        return MOUSE_BUTTON_X2;

    if wParam == VK_SPACE   return xx 32;

    // @Incomplete: Convert this to if wParam == { ... }. Or even a lookup table of some kind.
    if wParam == VK_HOME  return HOME;
    if wParam == VK_END   return END;

    if wParam == VK_PAUSE        return PAUSE;
    if wParam == VK_SCROLL       return SCROLL_LOCK;

    if wParam == VK_PRIOR
        return PAGE_UP;
    if wParam == VK_NEXT
        return PAGE_DOWN;
    if wParam == VK_LEFT
        return ARROW_LEFT;
    if wParam == VK_RIGHT
        return ARROW_RIGHT;
    if wParam == VK_UP
        return ARROW_UP;
    if wParam == VK_DOWN
        return ARROW_DOWN;
    if wParam == VK_MENU
        return ALT;
    if wParam == VK_SHIFT
        return SHIFT;
    if wParam == VK_CONTROL
        return CTRL;
    if wParam == VK_APPS
        return CMD;
    if wParam == VK_BACK
        return BACKSPACE;
    if wParam == VK_DELETE
        return DELETE;
    if wParam == VK_INSERT
        return INSERT;
    if wParam == VK_ESCAPE
        return ESCAPE;
    if wParam == VK_RETURN
        return ifx extended then NUMPAD_ENTER else ENTER;
    if wParam == VK_TAB
        return TAB;

    if wParam == VK_OEM_1  // Sigh.
        return xx #char ";";
    if wParam == VK_OEM_2  // Sigh.
        return xx #char "/";
    if wParam == VK_OEM_3
        return xx #char "`";
    if wParam == VK_OEM_4
        return xx #char "[";
    if wParam == VK_OEM_5
        return xx #char "\\";
    if wParam == VK_OEM_6
        return xx #char "]";
    if wParam == VK_OEM_7
        return xx #char "'";

    if wParam == VK_OEM_PLUS    return xx #char "+";
    if wParam == VK_OEM_MINUS   return xx #char "-";
    if wParam == VK_OEM_PERIOD  return xx #char ".";
    if wParam == VK_OEM_COMMA   return xx #char ",";

    if (wParam >= VK_F1) && (wParam <= VK_F24) {
        delta := wParam - VK_F1;
        return xx(F1 + xx delta);
    }
    if wParam == VK_SNAPSHOT
        return PRINT_SCREEN;

    // Numpad keys
    if wParam == VK_NUMPAD0  return NUMPAD_0;
    if wParam == VK_NUMPAD1  return NUMPAD_1;
    if wParam == VK_NUMPAD2  return NUMPAD_2;
    if wParam == VK_NUMPAD3  return NUMPAD_3;
    if wParam == VK_NUMPAD4  return NUMPAD_4;
    if wParam == VK_NUMPAD5  return NUMPAD_5;
    if wParam == VK_NUMPAD6  return NUMPAD_6;
    if wParam == VK_NUMPAD7  return NUMPAD_7;
    if wParam == VK_NUMPAD8  return NUMPAD_8;
    if wParam == VK_NUMPAD9  return NUMPAD_9;
    if wParam == VK_MULTIPLY return NUMPAD_MULTIPLY;
    if wParam == VK_ADD      return NUMPAD_ADD;
    if wParam == VK_SUBTRACT return NUMPAD_SUBTRACT;
    if wParam == VK_DECIMAL  return NUMPAD_DECIMAL;
    if wParam == VK_DIVIDE   return NUMPAD_DIVIDE;

    return UNKNOWN;
}

get_vk :: (key: Key_Code) -> VK: u64 {
    using Key_Code;

    if (key >= xx 48) && (key <= xx 90) return cast(u64) key;

    if key == xx 32            return  VK_SPACE;

    if key == PAGE_UP          return VK_PRIOR;
    if key == PAGE_DOWN        return VK_NEXT;

    if key == ARROW_LEFT       return VK_LEFT;

    if key == ARROW_RIGHT      return VK_RIGHT;

    if key == ARROW_UP         return VK_UP;

    if key == ARROW_DOWN       return VK_DOWN;

    if key == ALT              return VK_MENU;
    if key == SHIFT            return VK_SHIFT;

    if key == CTRL             return VK_CONTROL;

    if key == BACKSPACE        return VK_BACK;

    if key == DELETE           return VK_DELETE;
    if key == INSERT           return VK_INSERT;

    if key == ESCAPE           return VK_ESCAPE;

    if key == ENTER            return VK_RETURN;

    if key == TAB              return VK_TAB;

    if key == xx #char ";"     return VK_OEM_1;
    if key == xx #char "/"     return VK_OEM_2;
    if key == xx #char "`"     return VK_OEM_3;
    if key == xx #char "["     return VK_OEM_4;
    if key == xx #char "\\"    return VK_OEM_5;
    if key == xx #char "]"     return VK_OEM_6;
    if key == xx #char "'"     return VK_OEM_7;

    if key == xx #char "+"     return VK_OEM_PLUS;
    if key == xx #char "-"     return VK_OEM_MINUS;
    if key == xx #char "."     return VK_OEM_PERIOD;
    if key == xx #char ","     return VK_OEM_COMMA;

    if (key >= F1) && (key <= F16) {
        delta := key - F1;
        return xx(VK_F1 + xx delta);
    }

    if key == PRINT_SCREEN  return VK_SNAPSHOT;

    return 0;
}


#add_context _windows_windowproc :: MyWindowProc;

#scope_file

wm_char_high_surrogate : u32;

#scope_export

MyWindowProc :: (hwnd: HWND, message: u32,
                 wParam: WPARAM, lParam: LPARAM) -> s64 #c_call {
    new_context: #Context;

    push_context new_context {
        using Key_Code;

  	    if message == {
//          case WM_ERASEBKGND; return 1;
          case WM_SYSCOMMAND;
/*
            if (wParam & 0xfff0) == SC_KEYMENU {
                print("LPARAM %\n", lParam);
                // Ignore the cursed F10 key.
                // @Incomplete: Do we need to generate an event,
                // or do we also get a KEYDOWN for F10?
                return 0;
            }
*/
	        return DefWindowProcW(hwnd, message, wParam, lParam);

          case WM_ACTIVATEAPP;
            if wParam {  // We are being activated.

                // We do our best to provide the application with reliable key states without brute force sampling every key.
                // The intended rules are that a key down event will be sent when a key is depressed and will be followed
                // by zero or more key down events with the repeat flag set as long as the key remains down.  A key up event
                // will be sent when the key is released.
                // In practice:
                // 1. An application will always be notified when it has or gains focus if a key is up.
                // 2. An application will always be notified when it has focus if a key is down.
                // 3. An application will *usually* be notified when it gains focus if a key is down.
                // So the one thing you can't rely on is being notified if a key is pressed while the application is out of
                // focus and then the application gains focus.  In the rare cases where that doesn't happen, the key will
                // have to be released and re-pressed for the application to get a key down event.
                for key_down, vkey: key_down_table {
                    state := GetAsyncKeyState(cast,trunc(s32) vkey);
                    if !(state & 0x8000) {
                        send_key_event(get_key_code(vkey), false);
                        remove;
                    }
                }
            }
	        return DefWindowProcW(hwnd, message, wParam, lParam);

          case WM_SYSKEYDOWN; #through;
          case WM_KEYDOWN;

            extended := ((cast(u16)((cast(u32)lParam >> 16) & 0xffff)) & 0x0100 == 0x0100);  // (HIWORD(lParam) & KF_EXTENDED) == KF_EXTENDED
            repeat := ((cast (s32) lParam) & 0x40000000) != 0;
            maybe_send_vkey_event(wParam, true, repeat, extended = extended);

          case WM_SYSKEYUP; #through;
          case WM_KEYUP;

            extended := ((cast(u16)((cast(u32)lParam >> 16) & 0xffff)) & 0x0100 == 0x0100);  // (HIWORD(lParam) & KF_EXTENDED) == KF_EXTENDED
            maybe_send_vkey_event(wParam, false, extended = extended);

          case WM_SYSCHAR;
              // This is here to prevent beeps when a Alt key combo is pressed. If we don't return 0, windows helpfully emits a beep sound to
              // indicate the user that the key wasn't handled.

          case WM_CHAR;
            HIGH_SURROGATE_START  :: 0xd800;
            HIGH_SURROGATE_END    :: 0xdbff;
            LOW_SURROGATE_START   :: 0xdc00;
            LOW_SURROGATE_END     :: 0xdfff;

            if wParam >= HIGH_SURROGATE_START && wParam <= HIGH_SURROGATE_END {
                wm_char_high_surrogate = cast (u32) wParam;
            } else {
                codepoint := cast (u32) wParam;

                if codepoint >= LOW_SURROGATE_START && codepoint <= LOW_SURROGATE_END {
                    low_surrogate := cast (u32) wParam;
                    codepoint = (wm_char_high_surrogate - HIGH_SURROGATE_START) << 10;
                    codepoint += (low_surrogate - LOW_SURROGATE_START);
                    codepoint += 0x10000;
                }

                // Control characters generate key codes < 32, but these are redundant
                // with KEYDOWN events and are also ambiguous (ctrl-m generates 13, but
                // so does RETURN.)
                if codepoint > 31 && codepoint != 127 {
                    event: Event;
                    event.type = .TEXT_INPUT;
                    event.utf32 = codepoint;

                    array_add(*events_this_frame, event);
                }
            }

          case WM_SETFOCUS;
            input_application_has_focus = true;
          case WM_KILLFOCUS;
            input_application_has_focus = false;

          // case WM_PAINT;
          // NOTE: we don't handle WM_PAINT, see the discussion here https://github.com/focus-editor/focus/pull/228

          case WM_LBUTTONDOWN; #through;
          case WM_LBUTTONUP;
            maybe_send_vkey_event(VK_LBUTTON, message == WM_LBUTTONDOWN);
            if message == WM_LBUTTONDOWN SetCapture(hwnd); else ReleaseCapture();

          case WM_RBUTTONDOWN; #through;
          case WM_RBUTTONUP;
            maybe_send_vkey_event(VK_RBUTTON, message == WM_RBUTTONDOWN);
            if message == WM_RBUTTONDOWN SetCapture(hwnd); else ReleaseCapture();


         case WM_MBUTTONDOWN; #through;
         case WM_MBUTTONUP;
            maybe_send_vkey_event(VK_MBUTTON, message == WM_MBUTTONDOWN);
            if message == WM_MBUTTONDOWN SetCapture(hwnd); else ReleaseCapture();

         case WM_XBUTTONDOWN; #through;
         case WM_XBUTTONUP;
            maybe_send_vkey_event(cast(u64) ifx wParam < 1 << 17 then VK_XBUTTON1 else VK_XBUTTON2, message == WM_XBUTTONDOWN);
            if message == WM_XBUTTONDOWN SetCapture(hwnd); else ReleaseCapture();

          case WM_MOUSEMOVE;
            // We don't have mouse move events yet, but we'll record the delta.


            // We use Raw Input for mouse position stuff now.
/*
            x := (lParam & 0xffff);
            y := (lParam >> 16) & 0xffff;
            mouse_delta_x += x - last_mouse_event_x;
            mouse_delta_y += y - last_mouse_event_y;

            last_mouse_event_x = x;
            last_mouse_event_y = y;
*/
          case WM_MOUSEWHEEL;
            event: Event;
            event.type = .MOUSE_V_WHEEL;
            event.typical_wheel_delta = WHEEL_DELTA;
            event.wheel_delta = xx cast,trunc(s16)(wParam >> 16);
            array_add(*events_this_frame, event);
            mouse_wheel_delta.vertical += event.wheel_delta;

          case WM_MOUSEHWHEEL;
            event: Event;
            event.type = .MOUSE_H_WHEEL;
            event.typical_wheel_delta = WHEEL_DELTA;
            event.wheel_delta = xx -cast,trunc(s16)(wParam >> 16);
            array_add(*events_this_frame, event);
            mouse_wheel_delta.horizontal += event.wheel_delta;

          case WM_CLOSE; #through;
          case WM_QUIT;
            event: Event;
            event.type = .QUIT;
            array_add(*events_this_frame, event);

            // NOTE: we're not calling the default proc here because it would just close the window,
            // while we might want to show a confirmation dialog when there are unsaved files
            // return DefWindowProcW(hwnd, message, wParam, lParam);

          case WM_INPUT;
            extra := GetMessageExtraInfo();

            if (extra & 0x82) == 0x82 {
                // @Hack: Ignore touch input! There is no documentation of this
                // that I can see. This is just what I needed to do to filter
                // out fake mouse input generated by WM_TOUCH. I would regard
                // this as extremely fragile and could-break-at-any-time.
            } else {
                process_raw_input(cast(HRAWINPUT)lParam);
            }

            DefWindowProcW(hwnd, message, wParam, lParam);  // This is required for some reason.    // @@ Why?
          case WM_SIZE;
            if wParam == {
              case SIZE_MAXIMIZED;
                window_minimized = false;
                add_resize_record(hwnd);
              case SIZE_RESTORED;
                  if window_minimized window_minimized = false;
                  else add_resize_record(hwnd);
              case SIZE_MINIMIZED;
                  window_minimized = true;
            }
            return 0;
          case WM_MOVE;
            add_move_record(hwnd);
            return 0;
          case WM_EXITSIZEMOVE;
            add_resize_record(hwnd);
            return 0;
          case WM_DPICHANGED;
            y_dpi := (wParam >> 16) & 0xFFFF;
            x_dpi := (wParam)       & 0xFFFF;

            rect := cast(*RECT) lParam;

            w := rect.right - rect.left;
            h := rect.bottom - rect.top;

            SetWindowPos(hwnd, HWND_TOPMOST, rect.left, rect.top, w, h, SWP_NOACTIVATE|SWP_NOZORDER);
            return 0;
          case WM_DROPFILES;
 	  	    drop := cast(HDROP) wParam;
 	 	    // If "0xFFFFFFFF" as the second parameter: return the count of files dropped.
 	 	    file_paths_count := DragQueryFileW(drop, 0xFFFFFFFF, null, 0);
            assert(file_paths_count > 0);

            files: [..] string;
            array_reserve(*files, file_paths_count);

 	 	    for i: 0..file_paths_count-1 {
 	 	        // If null as the third parameter: return the length of the path, not counting the trailing '\0'.
 	 	        file_name_wide_count := DragQueryFileW(drop, i, null, 0) + 2;
 	 	        assert(file_name_wide_count > 0);

		        file_name_wide := cast(*u16) alloc(file_name_wide_count * size_of(u16));
 	 	        ok := DragQueryFileW(drop, i, file_name_wide, file_name_wide_count);
 	 	        assert(ok > 0); // means success

		        file_name := wide_to_utf8(file_name_wide,, allocator = temp);
 	 	        array_add(*files, file_name);
 	 	    }

 	 	    DragFinish(drop);

 	  	    event: Event;
 	 	    event.type  = .DRAG_AND_DROP_FILES;
            event.files = files;
 	 	    array_add(*events_this_frame, event);
            return 0;

          case WM_SETCURSOR;
            if windows_ignore_setcursor_messages return 0;
	        else return DefWindowProcW(hwnd, message, wParam, lParam);

          case;
	        return DefWindowProcW(hwnd, message, wParam, lParam);
	    }

        return 0;
    }
}

update_window_events :: () {
    if !initted {
        init_input_system();
        initted = true;
    }

    input_per_frame_event_and_flag_update();

    // @Robustness: Maybe do this for all keystrokes that are down? Sigh...
    if alt_state || (input_button_states[Key_Code.ALT] & .DOWN) { // Checking both just to be paranoid about desync between them.
        state := GetAsyncKeyState(VK_MENU);  // GetAsyncKeyState actually checks the key, not to be confused with GetKeyState, which does nothing.
        if !(state & 0x8000) {
            alt_state = false;
            input_button_states[Key_Code.ALT] |= .END;
        }
    }

    if ctrl_state || (input_button_states[Key_Code.CTRL] & .DOWN) { // Checking both just to be paranoid about desync between them.
        state := GetAsyncKeyState(VK_CONTROL);  // GetAsyncKeyState actually checks the key, not to be confused with GetKeyState, which does nothing.
        if !(state & 0x8000) {
            ctrl_state = false;
            input_button_states[Key_Code.CTRL] |= .END;
        }
    }

    if shift_state || (input_button_states[Key_Code.SHIFT] & .DOWN) { // Checking both just to be paranoid about desync between them.
        state := GetAsyncKeyState(VK_SHIFT);  // GetAsyncKeyState actually checks the key, not to be confused with GetKeyState, which does nothing.
        if !(state & 0x8000) {
            shift_state = false;
            input_button_states[Key_Code.SHIFT] |= .END;
        }
    }

    if cmd_state || (input_button_states[Key_Code.CMD] & .DOWN) { // Checking both just to be paranoid about desync between them.
        state := GetAsyncKeyState(VK_APPS);  // GetAsyncKeyState actually checks the key, not to be confused with GetKeyState, which does nothing.
        if !(state & 0x8000) {
            cmd_state = false;
            input_button_states[Key_Code.CMD] |= .END;
        }
    }

    while true {
        msg: MSG;

        result := PeekMessageW(*msg, null, 0, 0, PM_REMOVE);
        if !result break;

        // This is how we used to handle Alt+Enter on The Witness:
        // Alt+Enter is not delivered through WM_INPUT, so the combination was handled through WM_(SYS)KEYDOWN messages.
        /*if msg.message == WM_SYSKEYDOWN {
            if msg.wParam == VK_RETURN {

                // Toggle full screen upon alt-enter
                dwMask :: (1 << 29);
                if (msg.lParam & dwMask) != 0 { // Alt is down also
                    //display->toggle_fullscreen();

                    event: Event;
                    event.type = .KEYBOARD;
                    event.key_pressed = 1;
                    event.key_code = get_key_code(msg.wParam);
                    event.packed = 0;  // @Temporary: Unions not currently initialized.
                    event.shift_pressed = shift_state;
                    event.ctrl_pressed = ctrl_state;
                    event.alt_pressed = true;

                    array_add(*events_this_frame, event);

                    // Do not send this message to the window proc, because that produces beep sound.
                    continue;
                }
            }
        }*/

        // Doing that was also useful to avoid the beeping sound when pressing Alt+key combinations. However, to avoid that
        // we only need to avoid TranslateMessage. Turns out TranslateMessage enqueues a WM_SYSCHAR message which is the actual
        // culprit of the beeping sound. Handling WM_SYSCHAR in the message handler and returning 0 prevents the default handling
        // of the message and avoids the beep.

        TranslateMessage(*msg);
        DispatchMessageW(*msg);
    }
}

#scope_file

shift_state := false;
ctrl_state  := false;
alt_state   := false;
cmd_state   := false;


// Nice tutorial about using raw input for games:
// http://www.toymaker.info/Games/html/raw_input.html

// About Raw Input:
// http://msdn.microsoft.com/en-us/library/ms645543(v=vs.85).aspx#_win32_Registration_for_Raw_Input

// Taking Advantage of High-Definition Mouse Movement:
// http://msdn.microsoft.com/en-us/library/ee418864(v=vs.85).aspx

// Using Raw Input Examples:
// http://msdn.microsoft.com/en-us/library/ms645546(v=vs.85).aspx#standard_read

raw_input_buffer: [..] *u8;
process_raw_input :: (handle: HRAWINPUT) {
    //
    // We currently use Raw Input for mouse events, so that we can get deltas
    // while doing things like tightly constraining the mouse pointer.
    //
    // In The Witness we also used Raw Input for keyboard events, but I am
    // not sure what benefit we got from this. Maybe it's better, I don't know!
    // But for now I am leaving keyboard out of this code.
    //
    //          -jblow, 31 March 2017.

    // IC: We are using raw input, because there are no WM events for some special keys such as PrintScreen.

    dwSize: u32;
    GetRawInputData(handle, RID_INPUT, null, *dwSize, size_of(RAWINPUTHEADER));

    if raw_input_buffer.count < dwSize {
        array_resize(*raw_input_buffer, dwSize);
        this_allocation_is_not_a_leak(raw_input_buffer.data); // :ScanGlobalData
    }

	written_bytes := GetRawInputData(handle, RID_INPUT, raw_input_buffer.data, *dwSize, size_of(RAWINPUTHEADER));
    assert(written_bytes <= dwSize);        // note that GetRawInputData() is allowed to request a buffer size and then write less bytes than the size

    raw := cast(*RAWINPUT) raw_input_buffer.data;

    handled := false;
    if raw.header.dwType == RIM_TYPEMOUSE {
        mouse := *raw.data.mouse;

        // The docs say to check this flag, but MOUSE_MOVE_RELATIVE
        // is defined as 0? wtf?
        if (mouse.usFlags & MOUSE_MOVE_ABSOLUTE) {
            // @@ What to do if we only receive absolute coordinates? To do proper motions we need to know when the pen touches the tablet and when is it lifted.
            //mouse_delta_x += cast(int)((mouse.lLastX - mouse_abs_x) * 0.01);
            //mouse_delta_y += cast(int)((mouse.lLastY - mouse_abs_y) * 0.01);
            //mouse_abs_x = mouse.lLastX;
            //mouse_abs_y = mouse.lLastY;
        } else {
            mouse_delta_x += mouse.lLastX;
            mouse_delta_y += mouse.lLastY;
        }
    } else if raw.header.dwType == RIM_TYPEKEYBOARD {
        is_left  := (raw.data.keyboard.Flags & RI_KEY_E0)    != 0;
        is_right := (raw.data.keyboard.Flags & RI_KEY_E1)    != 0;
        is_down  := (raw.data.keyboard.Flags & RI_KEY_BREAK) == 0;

        vkey    := raw.data.keyboard.VKey;
        raw_key := raw.data.keyboard.MakeCode;

        handle_keyboard_event(is_left, is_right, is_down, vkey, raw_key);
    }
}

handle_keyboard_event :: (is_left: bool, is_right: bool, is_down: bool, vkey: u16, raw_key: u16) -> handled:bool {
    // @@ IC: Here we only care about the PRINT SCREEN key, because there's no WM message for it.
    if vkey != VK_SNAPSHOT return false;

    key_code := get_key_code(vkey);
    repeat := is_down && (input_button_states[key_code] & .DOWN) != 0;
    maybe_send_vkey_event(vkey, is_down, repeat);

    return true;
}


init_input_system :: () {
    rid: [2]RAWINPUTDEVICE;

    rid[0].usUsagePage = 0x01;
    rid[0].usUsage = 0x02;            // HID mouse
    rid[0].dwFlags = 0;
    // rid[0].hwndTarget = null;

    // IC: We are not using the RIDEV_NOHOTKEYS flag anymore, because it interferes with the Alt-Tab dialog.
    // This means that we are not blocking the windows logo key and that pressing it will cause the app to loose the focus.
    rid[1].usUsagePage = 0x01;
    rid[1].usUsage = 0x06;            // HID keyboard
    rid[1].dwFlags = 0; //RIDEV_NOHOTKEYS;
    rid[1].hwndTarget = null;


    if RegisterRawInputDevices(rid.data, 2, size_of(RAWINPUTDEVICE)) == 1 {
        // Do nothing.
    } else {
        log_error("Failed to initialize Raw Input.\n");
    }

    // @@ Enable/Disable shortcut keys?

    // Disable StickyKeys/etc shortcuts but if the accessibility feature is on,
    // then leave the settings alone as its probably being usefully used

    sk: STICKYKEYS;
    SystemParametersInfoW(SPI_GETSTICKYKEYS, size_of(STICKYKEYS), *sk, 0);

    tk: TOGGLEKEYS;
    SystemParametersInfoW(SPI_GETTOGGLEKEYS, size_of(TOGGLEKEYS), *tk, 0);

    fk: FILTERKEYS;
    SystemParametersInfoW(SPI_GETFILTERKEYS, size_of(FILTERKEYS), *fk, 0);

    // Disable shortcuts:
    {
        skOff := sk;
        if (skOff.dwFlags & SKF_STICKYKEYSON) == 0 {
            // Disable the hotkey and the confirmation
            skOff.dwFlags &= ~SKF_HOTKEYACTIVE;
            skOff.dwFlags &= ~SKF_CONFIRMHOTKEY;
            skOff.dwFlags &= ~SKF_HOTKEYSOUND;

            result := SystemParametersInfoW(SPI_SETSTICKYKEYS, size_of(STICKYKEYS), *skOff, 0);
            k := result;
        }

        tkOff := tk;
        if (tkOff.dwFlags & TKF_TOGGLEKEYSON) == 0 {
            // Disable the hotkey and the confirmation
            tkOff.dwFlags &= ~TKF_HOTKEYACTIVE;
            tkOff.dwFlags &= ~TKF_CONFIRMHOTKEY;
            tkOff.dwFlags &= ~TKF_HOTKEYSOUND;

            result := SystemParametersInfoW(SPI_SETTOGGLEKEYS, size_of(TOGGLEKEYS), *tkOff, 0);
            k := result;
        }

        fkOff := fk;
        if (fkOff.dwFlags & FKF_FILTERKEYSON) == 0 {
            // Disable the hotkey and the confirmation
            fkOff.dwFlags &= ~FKF_HOTKEYACTIVE;
            fkOff.dwFlags &= ~FKF_CONFIRMHOTKEY;
            fkOff.dwFlags &= ~FKF_HOTKEYSOUND;

            result := SystemParametersInfoW(SPI_SETFILTERKEYS, size_of(FILTERKEYS), *fkOff, 0);
            k := result;
        }
    }
}


initted := false;

WHEEL_DELTA :: 120;

using Key_Current_State;

add_resize_record :: (hwnd: HWND) {
    record: *Window_Resize_Record;
    for * pending_resizes {
        if it.window == hwnd {
            record = it;
            break;
        }
    }

    if !record {
        record = array_add(*pending_resizes);
        this_allocation_is_not_a_leak(pending_resizes.data); // :ScanGlobalData
    }

    client_rect: RECT;
    GetClientRect(hwnd, *client_rect);

    record.window = hwnd;
    record.width  = client_rect.right;
    record.height = client_rect.bottom;
}

add_move_record :: (hwnd: HWND) {
    client_rect: RECT;
    GetWindowRect(hwnd, *client_rect);

    record: *Window_Move_Record;
    for * pending_moves {
        if it.window == hwnd {
            record = it;
            break;
        }
    }

    if !record {
        record = array_add(*pending_moves);
        this_allocation_is_not_a_leak(pending_moves.data); // :ScanGlobalData:  We could just scan the global data of the program and automatically consider anything there as not a leak. (Do we do this recursively though?)
    }

    record.window = hwnd;
    record.x = client_rect.left;
    record.y = client_rect.top;
}




#scope_file
windows_ignore_setcursor_messages := false;

key_down_table : Table(u32, bool);

set_key_down_state :: (vkey : u32, is_down: bool) -> was_down:bool {
    was_down := table_find_pointer(*key_down_table, vkey) != null;
    if is_down && !was_down {
        table_add(*key_down_table, vkey, true);
    } else if was_down && !is_down {
        table_remove(*key_down_table, vkey);
    }

    return was_down;
}

maybe_send_vkey_event :: (vkey: u64, key_down: bool, repeat := false, extended := false) {
    was_down := set_key_down_state(cast,trunc(u32) vkey, key_down);
    if !key_down && !was_down {
        // redundant key_up event
        return;
    }

    if key_down && repeat && !was_down {
        // key was pressed while we didn't have focus so the first
        // event we see is incorrectly labeled as a repeat.
        repeat = false;
    }

    send_key_event(get_key_code(vkey, extended), key_down, repeat);
}

send_key_event :: (key_code: Key_Code, key_down: bool, repeat := false) {
    if key_code == .ALT     alt_state   = key_down;
    if key_code == .SHIFT   shift_state = key_down;
    if key_code == .CTRL    ctrl_state  = key_down;  // @Cleanup: Look at what I do in the Braid code because this is bananas.
    if key_code == .CMD     cmd_state   = key_down;

    event: Event;
    event.type = .KEYBOARD;
    event.key_pressed = xx key_down;
    event.key_code = key_code;
    event.packed = 0;
    event.shift_pressed    = shift_state;
    event.ctrl_pressed     = ctrl_state;
    event.alt_pressed      = alt_state;
    event.cmd_meta_pressed = cmd_state;
    event.repeat = repeat;

    utf32 := cast(u32) key_code;
    is_printable := ((utf32 >= 32) && (utf32 != 127));
    event.text_input_count = xx is_printable;

    array_add(*events_this_frame, event);

    input_button_states[key_code] |= ifx key_down then (Key_Current_State.DOWN | .START) else .END;
}
