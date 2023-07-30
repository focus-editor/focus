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
    // input_vk_translation_table[OSX_VK_NUMPAD_DIVIDE] = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_MULT]   = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_7]      = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_8]      = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_9]      = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_MINUS]  = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_4]      = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_5]      = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_6]      = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_PLUS]   = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_1]      = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_2]      = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_3]      = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_ENTER]  = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_0]      = UNKNOWN;
    // input_vk_translation_table[OSX_VK_NUMPAD_PERIOD] = UNKNOWN;
}

get_key_code :: (param: u16) -> Key_Code {
    if param < 128 return input_vk_translation_table[param];

    return .UNKNOWN;
}


update_cocoa_window_events :: () {
    using Key_Current_State;

    input_per_frame_event_and_flag_update();

    past := NSDate.distantPast();

    while true {
        nsevent := NSApplication.nextEventMatchingMask(NSApp, NSEventMaskAny, past, NSDefaultRunLoopMode, YES);
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
                characters := NSEvent.characters(nsevent);
                modifiers := NSEvent.modifierFlags(nsevent);

                shift_state := (modifiers & NSEventModifierFlagShift) != 0;
                ctrl_state  := (modifiers & NSEventModifierFlagControl) != 0;
                alt_state   := (modifiers & NSEventModifierFlagOption) != 0;
                cmd_state   := (modifiers & NSEventModifierFlagCommand) != 0;

                repeat := NSEvent.isARepeat(nsevent);

                event: Event;
                event.type = .KEYBOARD;
                event.key_pressed = 1;
                event.key_code = get_key_code(keycode);
                event.packed = 0;
                event.shift_pressed    = shift_state;
                event.ctrl_pressed     = ctrl_state;
                event.alt_pressed      = alt_state;
                event.cmd_meta_pressed = cmd_state;
                event.repeat = (repeat != NO);

                input_button_states[event.key_code] |= (DOWN | START);

                // Length will be 0 if this was a dead key.
                // @Incomplete: How do we handle diacritics entered via dead keys?
                // For example for "¨ + a => ä", if we ignore the dead key for ¨ here and then only handle the "a", people won’t be able to assemble the "ä".
                if characters && NSString.length(characters) {
                    utf32_data := NSString.dataUsingEncoding(characters, NSUTF32LittleEndianStringEncoding);
                    // defer release(utf32_data);
                    utf32 := cast(*u32) NSData.bytes(utf32_data);
                    count := NSData.length(utf32_data) / size_of(u32);

                    event.text_input_count = xx count;
                    array_add(*events_this_frame, event);

                    for 0..count-1 {
                        event: Event;
                        event.type = .TEXT_INPUT;
                        event.utf32 = utf32[it];

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

                // continue;
            case NSEventTypeKeyUp;
                keycode := NSEvent.keyCode(nsevent);
                characters := NSEvent.characters(nsevent);
                modifiers := NSEvent.modifierFlags(nsevent);

                shift_state := (modifiers & NSEventModifierFlagShift) != 0;
                ctrl_state  := (modifiers & NSEventModifierFlagControl) != 0;
                alt_state   := (modifiers & NSEventModifierFlagOption) != 0;
                cmd_state   := (modifiers & NSEventModifierFlagCommand) != 0;

                event: Event;
                event.type = .KEYBOARD;
                event.key_pressed = 0;
                event.key_code = get_key_code(keycode);
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

                // Apple doesnt seem to document what the values returned by buttonNumber
                // other than a non-mouse event returns 0 (and yet a left click mouse event also returns 0)
                MLEFT   :: 0;
                MRIGHT  :: 1;
                MMIDDLE :: 2;

                if num > MMIDDLE {
                    // we dont yet handle mouse buttons other than Left, Right, Middle
                } else {
                    if      num == MLEFT   then event.key_code = Key_Code.MOUSE_BUTTON_LEFT;
                    else if num == MRIGHT  then event.key_code = Key_Code.MOUSE_BUTTON_RIGHT;
                    else if num == MMIDDLE then event.key_code = Key_Code.MOUSE_BUTTON_MIDDLE;

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

                if num > MMIDDLE {
                    // we dont yet handle mouse buttons other than Left, Right, Middle
                } else {
                    if      num == MLEFT   then event.key_code = Key_Code.MOUSE_BUTTON_LEFT;
                    else if num == MRIGHT  then event.key_code = Key_Code.MOUSE_BUTTON_RIGHT;
                    else if num == MMIDDLE then event.key_code = Key_Code.MOUSE_BUTTON_MIDDLE;

                    input_button_states[event.key_code] = END;
                    event.key_pressed = 0;

                    array_add(*events_this_frame, event);
                }

            case NSEventTypeMouseMoved;
                mouse_delta_x += cast(int) NSEvent.deltaX(nsevent);
                mouse_delta_y += cast(int) NSEvent.deltaY(nsevent);

            case NSEventTypeScrollWheel;
                // delx := NSEvent.deltaX(nsevent);
                dely := NSEvent.deltaY(nsevent);
                // delz := NSEvent.deltaZ(nsevent);
                // print("del: %, %, %\n", delx, dely, delz);

                // it seems that OSX does scroll wheel acceleration.
                // the smallest step I'm seeing with a Razer mouse is 0.1 for 1 bump
                // but just quickly going past about 3 bumps yeilds ~0.6. Spinning
                // the wheel a bit more quickly starts hitting above 15.0, sigh.
                // In any case for now we're just multiplying by 10 since we probably
                // as least want to register a single scroll bump. We'll likely need to
                // tune WHEEL_DELTA at some point. -josh 6 November 2018

                event: Event;
                event.type = .MOUSE_WHEEL;
                event.typical_wheel_delta = WHEEL_DELTA;
                event.wheel_delta = cast(s32) (dely * 10.0);
                array_add(*events_this_frame, event);

                mouse_delta_z += event.wheel_delta;
        }
    }

    NSApplication.updateWindows(NSApp);

    array_add(*events_this_frame, ..osx_externally_generated_events);
    array_reset(*osx_externally_generated_events);
}

WHEEL_DELTA :: 120;

#scope_export

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
        objc_add_instance_method(wd_class, Window_Delegate.windowWillClose, "windowWillClose:");
        // objc_add_instance_method(wd_class, Window_Delegate.windowWillResize, "windowWillResize:toSize:");
        objc_add_instance_method(wd_class, Window_Delegate.windowDidResize, "windowDidResize:");
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
        jai_context: Context;
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
        ctx: Context;
        push_context ctx {
            NSApplication.setActivationPolicy(NSApp, NSApplicationActivationPolicyRegular);
            NSApplication.activateIgnoringOtherApps(NSApp, YES);
            NSApp.stop(NSApp, null);
        }
    }
}

Window_Delegate :: struct {
    using #as nsobject: NSObject;

    windowWillClose :: (using self: *Window_Delegate, _sel: Selector, notification: *NSNotification) #c_call {
        jai_context: Context;
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
        jai_context: Context;
        push_context jai_context {
            my_window := cast(*NSWindow) notification.object(notification);
            view := NSWindow.contentView(my_window);
            frame := NSView.frame(view);
            fb := NSView.convertRectToBacking(view, frame); // :MacHighResDisplays
            add_resize_record(my_window, cast(s32) fb.size.width, cast(s32) fb.size.height);

            view.drawRect(view, frame);
        }
    } @selector(windowDidResize:)

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
        ctx: Context;
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

