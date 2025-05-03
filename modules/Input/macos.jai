#import "Objective_C";
#import "Objective_C/AppKit";

window_minimized := false; // @@ Hack.

// this stuff is managed by the App_Delegate and Window_Delegate in Window_Creation.
// It is generally safe for this to not be protected by a mutex as long as the user doesnt call
// update_window_events outside the main thread or send events to Cocoa objects outside the main thread.
osx_externally_generated_events: [..] Event;

set_custom_cursor_handling :: (is_custom: bool) {
     // @Incomplete: Implement this.
     // Use this if you are doing immediate-mode API stuff that sets cursors and want to prevent cursors from flickering. Windows is annoying to interface with.
}

#scope_file

OSX_VK_ESCAPE        :: 53;
OSX_VK_F1            :: 122;
OSX_VK_F2            :: 120;
OSX_VK_F3            :: 99;
OSX_VK_F4            :: 118;
OSX_VK_F5            :: 96;
OSX_VK_F6            :: 97;
OSX_VK_F7            :: 98;
OSX_VK_F8            :: 100;
OSX_VK_F9            :: 101;
OSX_VK_F10           :: 109;
OSX_VK_F11           :: 103;
OSX_VK_F12           :: 111;
OSX_VK_F13           :: 105;
OSX_VK_F14           :: 107;
OSX_VK_F15           :: 113;
OSX_VK_BACK_TICK     :: 50;
OSX_VK_1             :: 18;
OSX_VK_2             :: 19;
OSX_VK_3             :: 20;
OSX_VK_4             :: 21;
OSX_VK_5             :: 23;
OSX_VK_6             :: 22;
OSX_VK_7             :: 26;
OSX_VK_8             :: 28;
OSX_VK_9             :: 25;
OSX_VK_0             :: 29;
OSX_VK_DASH          :: 27;
OSX_VK_EQUAL         :: 24;
OSX_VK_BACKSPACE     :: 51;
OSX_VK_TAB           :: 48;
OSX_VK_Q             :: 12;
OSX_VK_W             :: 13;
OSX_VK_E             :: 14;
OSX_VK_R             :: 15;
OSX_VK_T             :: 17;
OSX_VK_Y             :: 16;
OSX_VK_U             :: 32;
OSX_VK_I             :: 34;
OSX_VK_O             :: 31;
OSX_VK_P             :: 35;
OSX_VK_LBRACKET      :: 33;
OSX_VK_RBRACKET      :: 30;
OSX_VK_BACKSLASH     :: 42;
OSX_VK_CAPS_LOCK     :: 57;
OSX_VK_A             :: 0;
OSX_VK_S             :: 1;
OSX_VK_D             :: 2;
OSX_VK_F             :: 3;
OSX_VK_G             :: 5;
OSX_VK_H             :: 4;
OSX_VK_J             :: 38;
OSX_VK_K             :: 40;
OSX_VK_L             :: 37;
OSX_VK_COLON         :: 41;
OSX_VK_QUOTE         :: 39;
OSX_VK_RETURN        :: 36;
OSX_VK_SHIFT         :: 56;
OSX_VK_Z             :: 6;
OSX_VK_X             :: 7;
OSX_VK_C             :: 8;
OSX_VK_V             :: 9;
OSX_VK_B             :: 11;
OSX_VK_N             :: 45;
OSX_VK_M             :: 46;
OSX_VK_COMMA         :: 43;
OSX_VK_PERIOD        :: 47;
OSX_VK_FWD_SLASH     :: 44;
OSX_VK_CONTROL       :: 59;
OSX_VK_OPTION        :: 58;
OSX_VK_COMMAND       :: 55;
OSX_VK_RIGHT_SHIFT   :: 60;
OSX_VK_RIGHT_COMMAND :: 54;
OSX_VK_RIGHT_OPTION  :: 61;
OSX_VK_RIGHT_CONTROL :: 62;
OSX_VK_SPACEBAR      :: 49;
OSX_VK_INSERT        :: 114;
OSX_VK_HOME          :: 115;
OSX_VK_PAGE_UP       :: 116;
OSX_VK_DELETE        :: 117;
OSX_VK_END           :: 119;
OSX_VK_PAGE_DOWN     :: 121;
OSX_VK_UP            :: 126;
OSX_VK_DOWN          :: 125;
OSX_VK_RIGHT         :: 124;
OSX_VK_LEFT          :: 123;
OSX_VK_NUMLOCK       :: 71;
OSX_VK_NUMPAD_EQUALS :: 81;
OSX_VK_NUMPAD_DIVIDE :: 75;
OSX_VK_NUMPAD_MULT   :: 67;
OSX_VK_NUMPAD_7      :: 89;
OSX_VK_NUMPAD_8      :: 91;
OSX_VK_NUMPAD_9      :: 92;
OSX_VK_NUMPAD_MINUS  :: 78;
OSX_VK_NUMPAD_4      :: 86;
OSX_VK_NUMPAD_5      :: 87;
OSX_VK_NUMPAD_6      :: 88;
OSX_VK_NUMPAD_PLUS   :: 69;
OSX_VK_NUMPAD_1      :: 83;
OSX_VK_NUMPAD_2      :: 84;
OSX_VK_NUMPAD_3      :: 85;
OSX_VK_NUMPAD_ENTER  :: 76;
OSX_VK_NUMPAD_0      :: 82;
OSX_VK_NUMPAD_PERIOD :: 65;

input_vk_table_initialized := false;
input_vk_translation_table: [128] Key_Code; // translates OSX system's virtual keys to jai's Input module's virtual keys

init_input_system :: () {
    using Key_Code;

    for * input_vk_translation_table {
        <<it = UNKNOWN;
    }

    input_vk_translation_table[OSX_VK_ESCAPE]        = ESCAPE;
    input_vk_translation_table[OSX_VK_F1]            = F1;
    input_vk_translation_table[OSX_VK_F2]            = F2;
    input_vk_translation_table[OSX_VK_F3]            = F3;
    input_vk_translation_table[OSX_VK_F4]            = F4;
    input_vk_translation_table[OSX_VK_F5]            = F5;
    input_vk_translation_table[OSX_VK_F6]            = F6;
    input_vk_translation_table[OSX_VK_F7]            = F7;
    input_vk_translation_table[OSX_VK_F8]            = F8;
    input_vk_translation_table[OSX_VK_F9]            = F9;
    input_vk_translation_table[OSX_VK_F10]           = F10;
    input_vk_translation_table[OSX_VK_F11]           = F11;
    input_vk_translation_table[OSX_VK_F12]           = F12;
    input_vk_translation_table[OSX_VK_F13]           = PRINT_SCREEN; // sigh, the print screen key is reported by the system as F13
    input_vk_translation_table[OSX_VK_F14]           = F14;
    input_vk_translation_table[OSX_VK_F15]           = F15;
    input_vk_translation_table[OSX_VK_BACK_TICK]     = xx #char "`";
    input_vk_translation_table[OSX_VK_1]             = xx #char "1";
    input_vk_translation_table[OSX_VK_2]             = xx #char "2";
    input_vk_translation_table[OSX_VK_3]             = xx #char "3";
    input_vk_translation_table[OSX_VK_4]             = xx #char "4";
    input_vk_translation_table[OSX_VK_5]             = xx #char "5";
    input_vk_translation_table[OSX_VK_6]             = xx #char "6";
    input_vk_translation_table[OSX_VK_7]             = xx #char "7";
    input_vk_translation_table[OSX_VK_8]             = xx #char "8";
    input_vk_translation_table[OSX_VK_9]             = xx #char "9";
    input_vk_translation_table[OSX_VK_0]             = xx #char "0";
    input_vk_translation_table[OSX_VK_DASH]          = xx #char "-";
    input_vk_translation_table[OSX_VK_EQUAL]         = xx #char "+";
    input_vk_translation_table[OSX_VK_BACKSPACE]     = BACKSPACE;
    input_vk_translation_table[OSX_VK_TAB]           = TAB;
    input_vk_translation_table[OSX_VK_Q]             = xx #char "Q";
    input_vk_translation_table[OSX_VK_W]             = xx #char "W";
    input_vk_translation_table[OSX_VK_E]             = xx #char "E";
    input_vk_translation_table[OSX_VK_R]             = xx #char "R";
    input_vk_translation_table[OSX_VK_T]             = xx #char "T";
    input_vk_translation_table[OSX_VK_Y]             = xx #char "Y";
    input_vk_translation_table[OSX_VK_U]             = xx #char "U";
    input_vk_translation_table[OSX_VK_I]             = xx #char "I";
    input_vk_translation_table[OSX_VK_O]             = xx #char "O";
    input_vk_translation_table[OSX_VK_P]             = xx #char "P";
    input_vk_translation_table[OSX_VK_LBRACKET]      = xx #char "[";
    input_vk_translation_table[OSX_VK_RBRACKET]      = xx #char "]";
    input_vk_translation_table[OSX_VK_BACKSLASH]     = xx #char "\\";
    // input_vk_translation_table[OSX_VK_CAPS_LOCK] = UNKNOWN;
    input_vk_translation_table[OSX_VK_A]             = xx #char "A";
    input_vk_translation_table[OSX_VK_S]             = xx #char "S";
    input_vk_translation_table[OSX_VK_D]             = xx #char "D";
    input_vk_translation_table[OSX_VK_F]             = xx #char "F";
    input_vk_translation_table[OSX_VK_G]             = xx #char "G";
    input_vk_translation_table[OSX_VK_H]             = xx #char "H";
    input_vk_translation_table[OSX_VK_J]             = xx #char "J";
    input_vk_translation_table[OSX_VK_K]             = xx #char "K";
    input_vk_translation_table[OSX_VK_L]             = xx #char "L";
    input_vk_translation_table[OSX_VK_COLON]         = xx #char ";";
    input_vk_translation_table[OSX_VK_QUOTE]         = xx #char "'";
    input_vk_translation_table[OSX_VK_RETURN]        = ENTER;
    input_vk_translation_table[OSX_VK_SHIFT]         = SHIFT;
    input_vk_translation_table[OSX_VK_Z]             = xx #char "Z";
    input_vk_translation_table[OSX_VK_X]             = xx #char "X";
    input_vk_translation_table[OSX_VK_C]             = xx #char "C";
    input_vk_translation_table[OSX_VK_V]             = xx #char "V";
    input_vk_translation_table[OSX_VK_B]             = xx #char "B";
    input_vk_translation_table[OSX_VK_N]             = xx #char "N";
    input_vk_translation_table[OSX_VK_M]             = xx #char "M";
    input_vk_translation_table[OSX_VK_COMMA]         = xx #char ",";
    input_vk_translation_table[OSX_VK_PERIOD]        = xx #char ".";
    input_vk_translation_table[OSX_VK_FWD_SLASH]     = xx #char "/";
    input_vk_translation_table[OSX_VK_CONTROL]       = CTRL;
    input_vk_translation_table[OSX_VK_OPTION]        = ALT;
    input_vk_translation_table[OSX_VK_COMMAND]       = CMD;
    input_vk_translation_table[OSX_VK_RIGHT_SHIFT]   = SHIFT;
    input_vk_translation_table[OSX_VK_RIGHT_CONTROL] = CTRL;
    input_vk_translation_table[OSX_VK_RIGHT_OPTION]  = ALT;
    input_vk_translation_table[OSX_VK_RIGHT_COMMAND] = CMD;
    input_vk_translation_table[OSX_VK_SPACEBAR]      = xx #char " ";
    input_vk_translation_table[OSX_VK_INSERT]        = INSERT;
    input_vk_translation_table[OSX_VK_HOME]          = HOME;
    input_vk_translation_table[OSX_VK_PAGE_UP]       = PAGE_UP;
    input_vk_translation_table[OSX_VK_DELETE]        = DELETE;
    input_vk_translation_table[OSX_VK_END]           = END;
    input_vk_translation_table[OSX_VK_PAGE_DOWN]     = PAGE_DOWN;
    input_vk_translation_table[OSX_VK_UP]            = ARROW_UP;
    input_vk_translation_table[OSX_VK_DOWN]          = ARROW_DOWN;
    input_vk_translation_table[OSX_VK_RIGHT]         = ARROW_RIGHT;
    input_vk_translation_table[OSX_VK_LEFT]          = ARROW_LEFT;

    // input_vk_translation_table[OSX_VK_NUMLOCK]   = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_EQUALS] = UNKNOWN;
    input_vk_translation_table[OSX_VK_NUMPAD_DIVIDE] = NUMPAD_DIVIDE;
    input_vk_translation_table[OSX_VK_NUMPAD_MULT]   = NUMPAD_MULTIPLY;
    input_vk_translation_table[OSX_VK_NUMPAD_7]      = NUMPAD_7;
    input_vk_translation_table[OSX_VK_NUMPAD_8]      = NUMPAD_8;
    input_vk_translation_table[OSX_VK_NUMPAD_9]      = NUMPAD_9;
    input_vk_translation_table[OSX_VK_NUMPAD_MINUS]  = NUMPAD_SUBTRACT;
    input_vk_translation_table[OSX_VK_NUMPAD_4]      = NUMPAD_4;
    input_vk_translation_table[OSX_VK_NUMPAD_5]      = NUMPAD_5;
    input_vk_translation_table[OSX_VK_NUMPAD_6]      = NUMPAD_6;
    input_vk_translation_table[OSX_VK_NUMPAD_PLUS]   = NUMPAD_ADD;
    input_vk_translation_table[OSX_VK_NUMPAD_1]      = NUMPAD_1;
    input_vk_translation_table[OSX_VK_NUMPAD_2]      = NUMPAD_2;
    input_vk_translation_table[OSX_VK_NUMPAD_3]      = NUMPAD_3;
    input_vk_translation_table[OSX_VK_NUMPAD_ENTER]  = NUMPAD_ENTER;
    input_vk_translation_table[OSX_VK_NUMPAD_0]      = NUMPAD_0;
    input_vk_translation_table[OSX_VK_NUMPAD_PERIOD] = NUMPAD_DECIMAL;
}

get_key_code :: (keycode: u16, char: u16 = 128) -> Key_Code {
    if char >= 127 {
        return ifx keycode < 128 then input_vk_translation_table[keycode] else .UNKNOWN;
    }
    if char == {
        case 25; return .TAB;   // Shift-Tab
        case; return cast(Key_Code) (char - (ifx char >= #char "a" && char <= #char "z" then 32 else 0));
    }
}

// Apple doesnt seem to document what the values returned by buttonNumber
// other than a non-mouse event returns 0 (and yet a left click mouse event also returns 0)
MLEFT    :: 0;
MRIGHT   :: 1;
MMIDDLE  :: 2;
MBACK    :: 3;
MFORWARD :: 4;

update_cocoa_window_events :: () {
    using Key_Current_State;

    input_per_frame_event_and_flag_update();

    while true {
        nsevent: *NSEvent;
        if queued_event {
            nsevent = queued_event;
            queued_event = null;
        } else {
            nsevent = NSApplication.nextEventMatchingMask(NSApp, NSEventMaskAny, NSDate.distantPast(), NSDefaultRunLoopMode, YES);
        }
        autorelease(nsevent);
        if !nsevent then break;

        NSApplication.sendEvent(NSApp, nsevent);

        type := NSEvent.type(nsevent);
        if type == {
            case NSEventTypeFlagsChanged;
                keycode := NSEvent.keyCode(nsevent);
                modifiers := NSEvent.modifierFlags(nsevent);

                shift_state := (modifiers & NSEventModifierFlagShift) != 0;
                ctrl_state  := (modifiers & NSEventModifierFlagControl) != 0;
                alt_state   := (modifiers & NSEventModifierFlagOption) != 0;
                cmd_state   := (modifiers & NSEventModifierFlagCommand) != 0;

                repeat := NO;

                event: Event;
                event.type = .KEYBOARD;
                event.key_code = get_key_code(keycode);

                button_state_flags := (DOWN | START);
                if event.key_code == {
                    case Key_Code.SHIFT;  if !shift_state then button_state_flags = Key_Current_State.END;
                    case Key_Code.ALT;    if !alt_state   then button_state_flags = Key_Current_State.END;
                    case Key_Code.CTRL;   if !ctrl_state  then button_state_flags = Key_Current_State.END;
                    case Key_Code.CMD;    if !cmd_state   then button_state_flags = Key_Current_State.END;
                }

                event.key_pressed = 0;
                if button_state_flags & DOWN then event.key_pressed = 1;

                event.packed = 0;
                event.shift_pressed    = shift_state;
                event.ctrl_pressed     = ctrl_state;
                event.alt_pressed      = alt_state;
                event.cmd_meta_pressed = cmd_state;
                event.repeat = (repeat != NO);

                input_button_states[event.key_code] |= button_state_flags;

                array_add(*events_this_frame, event);

            case NSEventTypeKeyDown;
                keycode := NSEvent.keyCode(nsevent);
                modifiers := NSEvent.modifierFlags(nsevent);
                characters := event_characters(keycode, modifiers);
                if !characters  characters = NSEvent.characters(nsevent);
                charslen := ifx characters then NSString.length(characters) else 0;
                charactersNoMods := NSEvent.charactersIgnoringModifiers(nsevent);
                charslenNoMods := ifx charactersNoMods then NSString.length(charactersNoMods) else 0;
                first := ifx charslenNoMods > 0 then NSString.characterAtIndex(charactersNoMods, 0) else 128;

                shift_state := (modifiers & NSEventModifierFlagShift) != 0;
                ctrl_state  := (modifiers & NSEventModifierFlagControl) != 0;
                alt_state   := (modifiers & NSEventModifierFlagOption) != 0;
                cmd_state   := (modifiers & NSEventModifierFlagCommand) != 0;

                repeat := NSEvent.isARepeat(nsevent);

                event: Event;
                event.type = .KEYBOARD;
                event.key_pressed = 1;
                event.key_code = get_key_code(keycode, first);
                event.packed = 0;
                event.shift_pressed    = shift_state;
                event.ctrl_pressed     = ctrl_state;
                event.alt_pressed      = alt_state;
                event.cmd_meta_pressed = cmd_state;
                event.repeat = (repeat != NO);

                input_button_states[event.key_code] |= (DOWN | START);

                if characters && charslen > 0 {
                    count := cast(u16) charslen;

                    event.text_input_count = count;
                    array_add(*events_this_frame, event);

                    for 0..count-1 {
                        event: Event;
                        event.type = .TEXT_INPUT;
                        event.utf32 = NSString.characterAtIndex(characters, it);

                        // filter out control characters
                        if event.utf32 <= 31   then continue;
                        if event.utf32 == 0x7F then continue; // DEL

                        // skip Private Use Area U+F700 (this contains values for NS function keys)
                        if (event.utf32 & 0xFF00) == 0xF700 then continue;

                        array_add(*events_this_frame, event);
                    }
                } else {
                    array_add(*events_this_frame, event);
                }

            case NSEventTypeKeyUp;
                keycode := NSEvent.keyCode(nsevent);
                modifiers := NSEvent.modifierFlags(nsevent);
                charactersNoMods := NSEvent.charactersIgnoringModifiers(nsevent);
                charslenNoMods := ifx charactersNoMods then NSString.length(charactersNoMods) else 0;
                first := ifx charslenNoMods > 0 then NSString.characterAtIndex(charactersNoMods, 0) else 128;

                shift_state := (modifiers & NSEventModifierFlagShift) != 0;
                ctrl_state  := (modifiers & NSEventModifierFlagControl) != 0;
                alt_state   := (modifiers & NSEventModifierFlagOption) != 0;
                cmd_state   := (modifiers & NSEventModifierFlagCommand) != 0;

                event: Event;
                event.type = .KEYBOARD;
                event.key_pressed = 0;
                event.key_code = get_key_code(keycode, first);
                event.packed = 0;  // @Temporary: Unions not currently initialized.
                event.shift_pressed    = shift_state;
                event.ctrl_pressed     = ctrl_state;
                event.alt_pressed      = alt_state;
                event.cmd_meta_pressed = cmd_state;

                input_button_states[event.key_code] = Key_Current_State.END;  // Because we shadowed that by Key_Code.END.

                array_add(*events_this_frame, event);

                // continue;

            // NOTE: no continues here because mouse events have to be sent to NSApp in order for the window's title-bar buttons to work (close, minimize, maximize)
            case NSEventTypeLeftMouseDown; #through;
            case NSEventTypeRightMouseDown; #through;
            case NSEventTypeOtherMouseDown;
                event: Event;
                event.type = .KEYBOARD;
                num := NSEvent.buttonNumber(nsevent);

                if num <= MFORWARD {
                    if num == {
                        case MLEFT;    event.key_code = Key_Code.MOUSE_BUTTON_LEFT;
                        case MRIGHT;   event.key_code = Key_Code.MOUSE_BUTTON_RIGHT;
                        case MMIDDLE;  event.key_code = Key_Code.MOUSE_BUTTON_MIDDLE;
                        case MBACK;    event.key_code = Key_Code.MOUSE_BUTTON_X1;
                        case MFORWARD; event.key_code = Key_Code.MOUSE_BUTTON_X2;
                    }

                    input_button_states[event.key_code] = (START | DOWN);
                    event.key_pressed = 1;

                    array_add(*events_this_frame, event);
                }

            case NSEventTypeLeftMouseUp; #through;
            case NSEventTypeRightMouseUp; #through;
            case NSEventTypeOtherMouseUp;
                event: Event;
                event.type = .KEYBOARD;
                num := NSEvent.buttonNumber(nsevent);

                // Apple doesnt seem to document what the values returned by buttonNumber
                // other than a non-mouse event returns 0 (and yet a left click mouse event also returns 0)
                MLEFT   :: 0;
                MRIGHT  :: 1;
                MMIDDLE :: 2;

                if num <= MFORWARD {
                    if num == {
                        case MLEFT;    event.key_code = Key_Code.MOUSE_BUTTON_LEFT;
                        case MRIGHT;   event.key_code = Key_Code.MOUSE_BUTTON_RIGHT;
                        case MMIDDLE;  event.key_code = Key_Code.MOUSE_BUTTON_MIDDLE;
                        case MBACK;    event.key_code = Key_Code.MOUSE_BUTTON_X1;
                        case MFORWARD; event.key_code = Key_Code.MOUSE_BUTTON_X2;
                    }

                    input_button_states[event.key_code] = END;
                    event.key_pressed = 0;

                    array_add(*events_this_frame, event);
                }

            case NSEventTypeMouseMoved;
                mouse_delta_x += cast(int) NSEvent.deltaX(nsevent);
                mouse_delta_y += cast(int) NSEvent.deltaY(nsevent);

            case NSEventTypeScrollWheel;
                /*
                 * A lot of the various factors we use to multiply/divide stuff here are basically
                 * determined by what felt good on my Macbook trackpad at the time this was written.
                 *
                 * The main goal here is to translate from the "scrolling units" that macOS uses
                 * for `scrollingDeltaX`/`scrollingDeltaY` to the "multiple-of-120" style of units
                 * that are used in Windows applications (which the whole `Input` module is built
                 * around). I couldn't find any official documentation on how exactly to correctly
                 * do this translation so I just experimented until things felt right (as far as I
                 * can tell there really is no official way to perform this conversion; we may want
                 * to make these configurable somehow).
                 *
                 *  - @ileonte 24.01.2024
                 */
                deltaX := NSEvent.scrollingDeltaX(nsevent);
                deltaY := NSEvent.scrollingDeltaY(nsevent);
                has_precise_scrolling := ifx NSEvent.hasPreciseScrollingDeltas(nsevent) == YES then true else false;

                if !has_precise_scrolling {
                    deltaX *= 10.0;
                    deltaY *= 20.0;
                }

                event: Event;
                if abs(deltaX) > abs(deltaY) {
                    event.type = .MOUSE_H_WHEEL;
                    event.typical_wheel_delta = WHEEL_DELTA;
                    event.wheel_delta = cast(s32) ((deltaX / 100.0) * WHEEL_DELTA * NSWindow.backingScaleFactor(NSEvent.window(nsevent)));
                    array_add(*events_this_frame, event);
                    mouse_wheel_delta.horizontal += event.wheel_delta;
                } else if deltaY != 0.0 {
                    event.type = .MOUSE_V_WHEEL;
                    event.typical_wheel_delta = WHEEL_DELTA;
                    event.wheel_delta = cast(s32) ((deltaY / 100.0) * WHEEL_DELTA * NSWindow.backingScaleFactor(NSEvent.window(nsevent)));
                    array_add(*events_this_frame, event);
                    mouse_wheel_delta.vertical += event.wheel_delta;
                }
        }
    }

    NSApplication.updateWindows(NSApp);

    array_add(*events_this_frame, ..osx_externally_generated_events);
    array_reset(*osx_externally_generated_events);
}



WHEEL_DELTA :: 120;

queued_event: *NSEvent;

#scope_export

macos_wait_for_event :: () {
    queued_event = NSApplication.nextEventMatchingMask(NSApp, NSEventMaskAny, NSDate.distantFuture(), NSDefaultRunLoopMode, YES);
}

update_window_events :: () {
    if !input_vk_table_initialized {
        init_input_system();
        input_vk_table_initialized = true;
    }

    update_cocoa_window_events();
}

// @Cutnpaste from Input/windows.jai
add_resize_record :: (hwnd: Window_Type, width: s32, height: s32) {
    record: *Window_Resize_Record;
    for * pending_resizes {
        if it.window == hwnd {
            record = it;
            break;
        }
    }

    if !record {
        record = array_add(*pending_resizes);
    }

    record.window = hwnd;
    record.width = width;
    record.height = height;
}

#scope_file

/*
 * After a whole bunch of googling this is the best I could come up with in order to handle
 * key composition/dead keys. As far as I can tell this seems to *technically* be deprecated,
 * however I couldn't find any equivalent way of doing this with "current" APIs.
 *
 * These should probably be part of the `macos` module however I don't really feel like
 * copying that into our local module directory as well.
 *
 * References:
 *   - https://github.com/TigerVNC/tigervnc/blob/master/vncviewer/cocoa.mm#L328-L344
 *   - https://github.com/TigerVNC/tigervnc/blob/master/vncviewer/cocoa.mm#L475-L485
 *   - https://chromium.googlesource.com/chromium/src/+/master/ui/events/keycodes/keyboard_code_conversion_mac.mm#224
 *   - https://gist.github.com/ArthurYidi/3af4ccd7edc87739530476fc80a22e12
 *   - `Events.h` and `UnicodeUtilities.h` in the `Carbon` framework
 *
 *  - @ileonte, 2024.06.11
 */
#import "macos";

kCmdKey     : u16 = 1 << 8;
kShiftKey   : u16 = 1 << 9;
kAlphaLock  : u16 = 1 << 10;
kOptionKey  : u16 = 1 << 11;
kControlKey : u16 = 1 << 12;

kUCKeyActionDown : u16 = 0;

kTISPropertyUnicodeKeyLayoutData : *NSString #elsewhere;

TISCopyCurrentKeyboardLayoutInputSource :: () -> *void #foreign;
TISGetInputSourceProperty :: (keyboard: *void, prop: *NSString) -> CFDataRef #foreign;
LMGetKbdType :: () -> u8 #foreign;
UCKeyTranslate :: (
    keyboardLayout: *u8,
    virtualKeyCode: u16,
    keyAction:      u16,
    modifierState:  u32,
    keyboardType:   u32,
    options:        u32,
    deadKeyState:   *u32,
    maxLength:      u64,
    actualLength:   *u64,
    unicodeString:  *u16) -> s32 #foreign;

dead_key_state : u32;   // this needs to persist across calls to `event_characters`

event_characters :: (keycode: u16, modifiers: NSEventModifierFlags) -> *NSString {
    characters: *NSString;
    layout: *u8;

    keyboard := TISCopyCurrentKeyboardLayoutInputSource();
    uchr := TISGetInputSourceProperty(keyboard, kTISPropertyUnicodeKeyLayoutData);
    if uchr  layout = CFDataGetBytePtr(uchr);
    if layout {
        str: [256]u16;
        len: u64;

        mods: u32;
        if (modifiers & NSEventModifierFlagCapsLock) != 0  mods |= kAlphaLock;
        if (modifiers & NSEventModifierFlagShift) != 0     mods |= kShiftKey;
        if (modifiers & NSEventModifierFlagControl) != 0   mods |= kControlKey;
        if (modifiers & NSEventModifierFlagOption) != 0    mods |= kOptionKey;
        if (modifiers & NSEventModifierFlagCommand) != 0   mods |= kCmdKey;
        mods = (mods >> 8) & 0xff;

        err := UCKeyTranslate(layout, keycode, kUCKeyActionDown, mods, LMGetKbdType(),
                              0, *dead_key_state, str.count, *len, str.data);

        if !err && len  characters = NSString.stringWithCharacters(str.data, len);
    }

    return characters;
}

Carbon :: #library,system,link_always "Carbon";
QuartzCore :: #library,system,link_always "QuartzCore";


#import "Math";

// :DecoupleWindowCreationAndInput:
#add_context _macos_create_app_delegate    :: create_app_delegate;
#add_context _macos_create_window_delegate :: create_window_delegate;

app_delegate_registered := false;
create_app_delegate :: () -> *App_Delegate {
    if !app_delegate_registered {
        app_delegate_registered = true;

        ad_class := objc_create_class(App_Delegate, NSObject);
        // DO NOT ADD NSApplicationDelegate AS A PROTOCOL HERE!!!!!
        // For whatever reason, on TouchBar macs and for whatever reason
        // only when the program is in a .app bundle, NSApplicationDelegate
        // doesn't exist and thus, this protocol is null.
        // prot := objc_getProtocol("NSApplicationDelegate");
        // class_addProtocol(ad_class, prot);
        objc_add_instance_method(ad_class, App_Delegate.applicationShouldTerminate, "applicationShouldTerminate:");
        objc_add_instance_method(ad_class, App_Delegate.applicationWillTerminate, "applicationWillTerminate:");
        objc_add_instance_method(ad_class, App_Delegate.applicationDidResignActive, "applicationDidResignActive:");
        objc_add_instance_method(ad_class, App_Delegate.applicationDidBecomeActive, "applicationDidBecomeActive:");
        objc_add_instance_method(ad_class, App_Delegate.applicationDidFinishLaunching, "applicationDidFinishLaunching:");
        objc_add_instance_method(ad_class, App_Delegate.applicationOpenFiles, "application:openFiles:");
        objc_finalize_class(ad_class);
    }

    delegate := objc_init(objc_alloc(App_Delegate));
    return delegate;
}

window_delegate_registered := false;
create_window_delegate :: () -> *Window_Delegate {
    if !window_delegate_registered {
        window_delegate_registered = true;
        wd_class := objc_create_class(Window_Delegate, NSObject);
        objc_add_instance_method(wd_class, Window_Delegate.windowShouldClose, "windowShouldClose:");
        objc_add_instance_method(wd_class, Window_Delegate.windowWillClose,   "windowWillClose:");
        // objc_add_instance_method(wd_class, Window_Delegate.windowWillResize, "windowWillResize:toSize:");
        objc_add_instance_method(wd_class, Window_Delegate.windowDidResize, "windowDidResize:");
        objc_add_instance_method(wd_class, Window_Delegate.windowDidChangeScreen, "windowDidChangeScreen:");
        objc_add_instance_method(wd_class, Window_Delegate.windowDidMiniaturize, "windowDidMiniaturize:");
        objc_add_instance_method(wd_class, Window_Delegate.windowDidDeminiaturize, "windowDidDeminiaturize:");

        drag_protocol := objc_getProtocol("NSDraggingDestination");
        assert(drag_protocol != null);
        success := class_addProtocol(wd_class, drag_protocol);
        assert(success != 0);
        objc_add_instance_method(wd_class, Window_Delegate.draggingEntered, "draggingEntered:");
        objc_add_instance_method(wd_class, Window_Delegate.draggingUpdated, "draggingUpdated:");
        objc_add_instance_method(wd_class, Window_Delegate.wantsPeriodicDraggingUpdates, "wantsPeriodicDraggingUpdates");
        objc_add_instance_method(wd_class, Window_Delegate.prepareForDragOperation, "prepareForDragOperation:");
        objc_add_instance_method(wd_class, Window_Delegate.performDragOperation, "performDragOperation:");

        objc_finalize_class(wd_class);
    }

    delegate := objc_init(objc_alloc(Window_Delegate));
    return delegate;
}

App_Delegate :: struct {
    #as using delegate: NSApplicationDelegate;

    applicationShouldTerminate :: (using self: *App_Delegate, _sel: Selector, sender: id) -> NSApplicationTerminateReply #c_call {
        jai_context: #Context;
        push_context jai_context {
            event: Event;
            event.type = .QUIT;
            array_add(*osx_externally_generated_events, event);
        }
        return NSTerminateCancel;
    } @selector(applicationShouldTerminate:)

    applicationWillTerminate :: (self: *App_Delegate, _sel: Selector, notification: *NSNotification) #c_call {
        // NSAutoreleasePool.drain(self.application_autorelease_pool);
        // release(self.application_autorelease_pool);
    } @selector(applicationWillTerminate:)

    applicationDidResignActive :: (using self: *App_Delegate, _sel: Selector, notification: *NSNotification) #c_call {
        input_application_has_focus = false;
    } @selector(applicationDidResignActive:)

    applicationDidBecomeActive :: (using self: *App_Delegate, _sel: Selector, notification: *NSNotification) #c_call {
        input_application_has_focus = true;
    } @selector(applicationDidBecomeActive:)

    applicationDidFinishLaunching :: (self: *App_Delegate, _sel: Selector, app: *NSApplication) #c_call {
        ctx: #Context;
        push_context ctx {
            NSApplication.setActivationPolicy(NSApp, NSApplicationActivationPolicyRegular);
            NSApplication.activateIgnoringOtherApps(NSApp, YES);
            NSApp.stop(NSApp, null);
        }
    }

    applicationOpenFiles :: (self: *App_Delegate, _sel: Selector, sender: *NSApplication, nsfiles: *NSArray(*NSString)) #c_call {
        ctx: #Context;
        push_context ctx {
            count := nsfiles.count(nsfiles);

            files: [..] string;
            array_reserve(*files, xx count);

            for i: 0..count -1 {
                nspath := nsfiles.objectAtIndex(nsfiles, xx i);
                path := to_string(nspath);
                array_add(*files, copy_string(path));
            }

            event: Event;
            event.type  = .DRAG_AND_DROP_FILES;
            event.files = files;
            array_add(*osx_externally_generated_events, event);

            nsev := NSEvent.otherEventWithType(
                type = NSEventTypeApplicationDefined,
                location = .{},
                modifierFlags = 0,
                timestamp = 0,
                windowNumber = 0,
                ctx = null,
                subtype = 0,
                data1 = 0,
                data2 = 0);
            NSApplication.postEvent(sender, nsev, YES);

            NSApplication.replyToOpenOrPrint(sender, 0);
        }
    }
}

Window_Delegate :: struct {
    using #as nsobject: NSObject;

    windowShouldClose :: (using self: *Window_Delegate, _sel: Selector, notification: *NSNotification) -> BOOL #c_call {
        jai_context: #Context;
        push_context jai_context {
            event: Event;
            event.type = .QUIT;
            array_add(*osx_externally_generated_events, event);
        }
        return NO;  // prevent the window from closing
    } @selector(windowShouldClose:)

    windowWillClose :: (using self: *Window_Delegate, _sel: Selector, notification: *NSNotification) #c_call {
        jai_context: #Context;
        push_context jai_context {
            // win := NSNotification.object(notification);

            event: Event;
            event.type = .QUIT;
            array_add(*osx_externally_generated_events, event);
        }
    } @selector(windowWillClose:)

    windowDidMiniaturize :: (using self: *Window_Delegate, _sel: Selector, notification: *NSNotification) #c_call {
        // win := cast(*NSWindow) NSNotification.object(notification);
        // window_minimized = true;
    } @selector(windowDidMiniaturize:)

    windowDidDeminiaturize :: (using self: *Window_Delegate, _sel: Selector, notification: *NSNotification) #c_call {
        // win := cast(*NSWindow) NSNotification.object(notification);
        // window_minimized = false;
    } @selector(windowDidDeminiaturize:)

    /*
    windowWillResize :: (using self: *Window_Delegate, _sel: Selector, sender: *NSWindow, toSize: NSSize) -> NSSize #c_call {
        push_context jai_context {
            add_resize_record(sender, cast(s32) toSize.width, cast(s32) toSize.height);
            return toSize;
        }
    } @selector(windowDidResize:toSize:)
    */

    windowDidResize :: (using self: *Window_Delegate, _sel: Selector, notification: *NSNotification) #c_call {
        jai_context: #Context;
        push_context jai_context {
            my_window := cast(*NSWindow) notification.object(notification);
            view := NSWindow.contentView(my_window);
            frame := NSView.frame(view);
            fb := NSView.convertRectToBacking(view, frame); // :MacHighResDisplays
            add_resize_record(my_window, cast(s32) fb.size.width, cast(s32) fb.size.height);

            view.drawRect(view, frame);
        }
    } @selector(windowDidResize:)

    windowDidChangeScreen :: (self: *Window_Delegate, _sel: Selector, notification: *NSNotification) #c_call {
        // The backing scale factor might change when the window changes screen so we need to re-compute the width and height of the window. :MacHighResDisplays
        jai_context: #Context;
        push_context jai_context {
            objc_msgSend(self, selector("windowDidResize:"), notification);
        }
    } @selector(windowDidChangeScreen:)

    draggingEntered :: (using self: *Window_Delegate, _sel: Selector, sender: id /*id<NSDraggingInfo>*/) -> NSDragOperation #c_call {
        mask := NSDraggingInfo.draggingSourceOperationMask(sender);
        return mask & NSDragOperationGeneric; // @Incomplete: Supporting other modes would require us to handle that information in the Input events.
    } @selector(draggingEntered:)

    draggingUpdated :: (using self: *Window_Delegate, _sel: Selector, sender: id /*id<NSDraggingInfo>*/) -> NSDragOperation #c_call {
        mask := NSDraggingInfo.draggingSourceOperationMask(sender);
        return mask & NSDragOperationGeneric; // @Incomplete: Supporting other modes would require us to handle that information in the Input events.
    } @selector(draggingUpdated:)

    wantsPeriodicDraggingUpdates :: (using self: *Window_Delegate, _sel: Selector) -> BOOL #c_call {
        return NO;
    } @selector(wantsPeriodicDraggingUpdates)

    prepareForDragOperation :: (using self: *Window_Delegate, _sel: Selector, sender: id /*id<NSDraggingInfo>*/) -> BOOL #c_call {
        return YES;
    } @selector(prepareForDragOperation:)

    performDragOperation :: (using self: *Window_Delegate, _sel: Selector, sender: id /*id<NSDraggingInfo>*/) -> BOOL #c_call {
        ctx: #Context;
        push_context ctx {
            pasteboard := NSDraggingInfo.draggingPasteboard(sender);
            classes := NSArray(Class).arrayWithObject(class(NSURL));
            file_urls := NSPasteboard.readObjectsForClasses(pasteboard, classes, null, *NSURL);

            num_urls := cast(s64) file_urls.count(file_urls);
            if !num_urls return NO;

            files: [..] string;
            array_reserve(*files, num_urls);

            for i: 0..num_urls-1 {
                url := file_urls.objectAtIndex(file_urls, xx i);
                objc_file_path := NSURL.path(url);
                file_path := to_string(objc_file_path);
                if file_path {
                    array_add(*files, copy_string(file_path));
                }
            }

 	  	    event: Event;
 	 	    event.type  = .DRAG_AND_DROP_FILES;
            event.files = files;
 	 	    array_add(*osx_externally_generated_events, event);
            return YES;
        }
    } @selector(performDragOperation:)
}

