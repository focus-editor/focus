// Input handler routines, platform-independent.

/*
  KNOWN PROBLEM: On Windows, keys will be erroneously considered held-down if you press them, alt-tab, then release.
  They'll get un-stuck if you press them again. To be fixed.
 */

#if OS == .WINDOWS {
    #load "windows.jai";
} else #if OS == .LINUX {
    #load "linux.jai";
} else #if OS == .MACOS {
    #load "macos.jai";
}

Event_Type :: enum u32 {  // If we set this to u8, our packing will stop matching C's.
    UNINITIALIZED :: 0;
    KEYBOARD    :: 1;
    TEXT_INPUT  :: 2;
    WINDOW      :: 3;
    MOUSE_WHEEL :: 4;
    QUIT        :: 5;
    DRAG_AND_DROP_FILES :: 6;
}

Key_Current_State :: enum_flags u32 {
    NONE  :: 0x0;
    DOWN  :: 0x1;
    START :: 0x4;
    END   :: 0x8;
}

// We reserve 32 buttons for each gamepad.
GAMEPAD_BUTTON_COUNT :: 32;

Key_Code :: enum u32 {
    UNKNOWN :: 0;

    // Non-textual keys that have placements in the ASCII table
    // (and thus in Unicode):

    BACKSPACE   :: 8;
    TAB         :: 9;
    LINEFEED    :: 10;
    ENTER       :: 13;
    ESCAPE      :: 27;
    SPACEBAR    :: 32;

    // The letters A-Z live in here as well and may be returned
    // by keyboard events.

    DELETE      :: 127;

    ARROW_UP    :: 128;
    ARROW_DOWN  :: 129;
    ARROW_LEFT  :: 130;
    ARROW_RIGHT :: 131;

    PAGE_UP     :: 132;
    PAGE_DOWN   :: 133;

    HOME        :: 134;
    END         :: 135;

    INSERT      :: 136;

    PAUSE       :: 137;
    SCROLL_LOCK :: 138;

    ALT;
    CTRL;
    SHIFT;
    CMD;
    META :: CMD;

    F1;
    F2;
    F3;
    F4;
    F5;
    F6;
    F7;
    F8;
    F9;
    F10;
    F11;
    F12;
    F13;
    F14;
    F15;
    F16;
    F17;
    F18;
    F19;
    F20;
    F21;
    F22;
    F23;
    F24;

    PRINT_SCREEN;

    MOUSE_BUTTON_LEFT;
    MOUSE_BUTTON_MIDDLE;
    MOUSE_BUTTON_RIGHT;

    MOUSE_WHEEL_UP;
    MOUSE_WHEEL_DOWN;

    // We reserve button codes for up to 4 gamepads.
    GAMEPAD_0_BEGIN;
    GAMEPAD_0_END :: GAMEPAD_0_BEGIN + xx GAMEPAD_BUTTON_COUNT;
    GAMEPAD_1_BEGIN;
    GAMEPAD_1_END :: GAMEPAD_1_BEGIN + xx GAMEPAD_BUTTON_COUNT;
    GAMEPAD_2_BEGIN;
    GAMEPAD_2_END :: GAMEPAD_2_BEGIN + xx GAMEPAD_BUTTON_COUNT;
    GAMEPAD_3_BEGIN;
    GAMEPAD_3_END :: GAMEPAD_3_BEGIN + xx GAMEPAD_BUTTON_COUNT;

    // WARNING!
    //
    // We make an array whose size is controlled
    // by the last enum value in this array, so if you make
    // really big values to match Unicode code points, our
    // memory usage will become quite sorry.
    //
    //                               -jblow, 19 March 2017
    //
}

// Modifier_Flags used to use #place, but I rewrote it to use a union
// instead .... it is not necessarily clearer though! So I am switching
// it back for now...

Event :: struct {
    Modifier_Flags :: union {
        // Eventually we'd like the *_pressed modifiers to be 1 bit each,
        // but still be nameable as booleans. But for now they're 1 byte each.
        // You can compare them as a u32 using the 'packed' member.

        struct {
            // @@ This is confusing. Below key_pressed means the key was just pressed, here _pressed means the key is held down.
            shift_pressed    := false;
            ctrl_pressed     := false;
            alt_pressed      := false;
            cmd_meta_pressed := false; // Cmd on macOS, Meta on Linux
        }
        packed: u32 = 0;
    }

    type: Event_Type = Event_Type.UNINITIALIZED;

    // If keyboard event:
    key_pressed: u32;  // If not pressed, it's a key release.
    key_code: Key_Code = Key_Code.UNKNOWN;

    using modifier_flags: Modifier_Flags; // Only set for Event_Type.KEYBOARD.

    utf32: u32;  // If TEXT_INPUT.
    repeat := false;  // If KEYBOARD event.
    text_input_count: u16; // If KEYBOARD event that also generated TEXT_INPUT events, this will tell you how many TEXT_INPUT events after this KEYBOARD event were generated.

    typical_wheel_delta: s32;  // Used only for mouse events.
    wheel_delta: s32;          // Used only for mouse events.

    files: [] string;  // Used only for drag and drop events. Both the array and its contents are heap-allocated, lives until events are reset for the next frame.
}

// Per-frame mouse deltas:
mouse_delta_x: int;
mouse_delta_y: int;
mouse_delta_z: int;

events_this_frame:   [..] Event;
input_button_states: [NUM_BUTTON_STATES] Key_Current_State;

input_application_has_focus := false;

NUM_BUTTON_STATES :: #run enum_highest_value(Key_Code) + 1;

Window_Resize_Record :: struct {
    window: Window_Type;
    width:  s32;
    height: s32;
}

Window_Move_Record :: struct {
    window: Window_Type;
    x: s32;
    y: s32;
}

get_window_resizes :: () -> [] Window_Resize_Record {
    // The return value here will stick around in memory until the next call
    // to get_window_resizes (from any thread. Actually this whole module does
    // not deal with threading, so don't do that!)

    if resizes_to_free  array_reset(*resizes_to_free);

    if !pending_resizes return .[];

    array_copy(*resizes_to_free, pending_resizes);
    this_allocation_is_not_a_leak(resizes_to_free.data);

    pending_resizes.count = 0;
    return resizes_to_free;
}

get_window_moves :: () -> [] Window_Move_Record {
    // See notes on get_window_resizes. This works the same way.
    if moves_to_free  array_reset(*moves_to_free);

    if !pending_moves return .[];

    array_copy(*moves_to_free, pending_moves);
    pending_moves.count = 0;
    return moves_to_free;
}

input_per_frame_event_and_flag_update :: () {
    // Called once per frame, probably.

    for events_this_frame {
        #if OS != .WINDOWS {
            for file: it.files {
                free(file);
            }
        }
        array_free(it.files);
    }
    array_reset(*events_this_frame);

    mask     := ~Key_Current_State.START;
    end_mask := ~(Key_Current_State.END | .DOWN | .START);
    // @Speed: Could just keep a list of who is not currently set.
    for * input_button_states {
        if (<<it & .END) {
            <<it &= end_mask;
        } else {
            <<it &= mask;
        }
    }

    mouse_delta_x = 0;
    mouse_delta_y = 0;
    mouse_delta_z = 0;
}

#scope_module

pending_moves:   [..] Window_Move_Record;
moves_to_free:   [..] Window_Move_Record;

pending_resizes: [..] Window_Resize_Record;
resizes_to_free: [..] Window_Resize_Record;

#import "Basic";
#import "Window_Type";

