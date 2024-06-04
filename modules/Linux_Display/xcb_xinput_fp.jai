//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



XCB_INPUT_MAJOR_VERSION :: 2;
XCB_INPUT_MINOR_VERSION :: 4;

XCB_INPUT_GET_EXTENSION_VERSION :: 1;

XCB_INPUT_LIST_INPUT_DEVICES :: 2;

XCB_INPUT_OPEN_DEVICE :: 3;

XCB_INPUT_CLOSE_DEVICE :: 4;

XCB_INPUT_SET_DEVICE_MODE :: 5;

XCB_INPUT_SELECT_EXTENSION_EVENT :: 6;

XCB_INPUT_GET_SELECTED_EXTENSION_EVENTS :: 7;

XCB_INPUT_CHANGE_DEVICE_DONT_PROPAGATE_LIST :: 8;

XCB_INPUT_GET_DEVICE_DONT_PROPAGATE_LIST :: 9;

XCB_INPUT_GET_DEVICE_MOTION_EVENTS :: 10;

XCB_INPUT_CHANGE_KEYBOARD_DEVICE :: 11;

XCB_INPUT_CHANGE_POINTER_DEVICE :: 12;

XCB_INPUT_GRAB_DEVICE :: 13;

XCB_INPUT_UNGRAB_DEVICE :: 14;

XCB_INPUT_GRAB_DEVICE_KEY :: 15;

XCB_INPUT_UNGRAB_DEVICE_KEY :: 16;

XCB_INPUT_GRAB_DEVICE_BUTTON :: 17;

XCB_INPUT_UNGRAB_DEVICE_BUTTON :: 18;

XCB_INPUT_ALLOW_DEVICE_EVENTS :: 19;

XCB_INPUT_GET_DEVICE_FOCUS :: 20;

XCB_INPUT_SET_DEVICE_FOCUS :: 21;

XCB_INPUT_GET_FEEDBACK_CONTROL :: 22;

XCB_INPUT_CHANGE_FEEDBACK_CONTROL :: 23;

XCB_INPUT_GET_DEVICE_KEY_MAPPING :: 24;

XCB_INPUT_CHANGE_DEVICE_KEY_MAPPING :: 25;

XCB_INPUT_GET_DEVICE_MODIFIER_MAPPING :: 26;

XCB_INPUT_SET_DEVICE_MODIFIER_MAPPING :: 27;

XCB_INPUT_GET_DEVICE_BUTTON_MAPPING :: 28;

XCB_INPUT_SET_DEVICE_BUTTON_MAPPING :: 29;

XCB_INPUT_QUERY_DEVICE_STATE :: 30;

XCB_INPUT_DEVICE_BELL :: 32;

XCB_INPUT_SET_DEVICE_VALUATORS :: 33;

XCB_INPUT_GET_DEVICE_CONTROL :: 34;

XCB_INPUT_CHANGE_DEVICE_CONTROL :: 35;

XCB_INPUT_LIST_DEVICE_PROPERTIES :: 36;

XCB_INPUT_CHANGE_DEVICE_PROPERTY :: 37;

XCB_INPUT_DELETE_DEVICE_PROPERTY :: 38;

XCB_INPUT_GET_DEVICE_PROPERTY :: 39;

XCB_INPUT_XI_QUERY_POINTER :: 40;

XCB_INPUT_XI_WARP_POINTER :: 41;

XCB_INPUT_XI_CHANGE_CURSOR :: 42;

XCB_INPUT_XI_CHANGE_HIERARCHY :: 43;

XCB_INPUT_XI_SET_CLIENT_POINTER :: 44;

XCB_INPUT_XI_GET_CLIENT_POINTER :: 45;

XCB_INPUT_XI_SELECT_EVENTS :: 46;

XCB_INPUT_XI_QUERY_VERSION :: 47;

XCB_INPUT_XI_QUERY_DEVICE :: 48;

XCB_INPUT_XI_SET_FOCUS :: 49;

XCB_INPUT_XI_GET_FOCUS :: 50;

XCB_INPUT_XI_GRAB_DEVICE :: 51;

XCB_INPUT_XI_UNGRAB_DEVICE :: 52;

XCB_INPUT_XI_ALLOW_EVENTS :: 53;

XCB_INPUT_XI_PASSIVE_GRAB_DEVICE :: 54;

XCB_INPUT_XI_PASSIVE_UNGRAB_DEVICE :: 55;

XCB_INPUT_XI_LIST_PROPERTIES :: 56;

XCB_INPUT_XI_CHANGE_PROPERTY :: 57;

XCB_INPUT_XI_DELETE_PROPERTY :: 58;

XCB_INPUT_XI_GET_PROPERTY :: 59;

XCB_INPUT_XI_GET_SELECTED_EVENTS :: 60;

XCB_INPUT_XI_BARRIER_RELEASE_POINTER :: 61;

XCB_INPUT_DEVICE_VALUATOR :: 0;

XCB_INPUT_DEVICE_KEY_PRESS :: 1;

XCB_INPUT_DEVICE_KEY_RELEASE :: 2;

XCB_INPUT_DEVICE_BUTTON_PRESS :: 3;

XCB_INPUT_DEVICE_BUTTON_RELEASE :: 4;

XCB_INPUT_DEVICE_MOTION_NOTIFY :: 5;

XCB_INPUT_DEVICE_FOCUS_IN :: 6;

XCB_INPUT_DEVICE_FOCUS_OUT :: 7;

XCB_INPUT_PROXIMITY_IN :: 8;

XCB_INPUT_PROXIMITY_OUT :: 9;

XCB_INPUT_DEVICE_STATE_NOTIFY :: 10;

XCB_INPUT_DEVICE_MAPPING_NOTIFY :: 11;

XCB_INPUT_CHANGE_DEVICE_NOTIFY :: 12;

XCB_INPUT_DEVICE_KEY_STATE_NOTIFY :: 13;

XCB_INPUT_DEVICE_BUTTON_STATE_NOTIFY :: 14;

XCB_INPUT_DEVICE_PRESENCE_NOTIFY :: 15;

XCB_INPUT_DEVICE_PROPERTY_NOTIFY :: 16;

XCB_INPUT_DEVICE_CHANGED :: 1;

XCB_INPUT_KEY_PRESS :: 2;

XCB_INPUT_KEY_RELEASE :: 3;

XCB_INPUT_BUTTON_PRESS :: 4;

XCB_INPUT_BUTTON_RELEASE :: 5;

XCB_INPUT_MOTION :: 6;

XCB_INPUT_ENTER :: 7;

XCB_INPUT_LEAVE :: 8;

XCB_INPUT_FOCUS_IN :: 9;

XCB_INPUT_FOCUS_OUT :: 10;

XCB_INPUT_HIERARCHY :: 11;

XCB_INPUT_PROPERTY :: 12;

XCB_INPUT_RAW_KEY_PRESS :: 13;

XCB_INPUT_RAW_KEY_RELEASE :: 14;

XCB_INPUT_RAW_BUTTON_PRESS :: 15;

XCB_INPUT_RAW_BUTTON_RELEASE :: 16;

XCB_INPUT_RAW_MOTION :: 17;

XCB_INPUT_TOUCH_BEGIN :: 18;

XCB_INPUT_TOUCH_UPDATE :: 19;

XCB_INPUT_TOUCH_END :: 20;

XCB_INPUT_TOUCH_OWNERSHIP :: 21;

XCB_INPUT_RAW_TOUCH_BEGIN :: 22;

XCB_INPUT_RAW_TOUCH_UPDATE :: 23;

XCB_INPUT_RAW_TOUCH_END :: 24;

XCB_INPUT_BARRIER_HIT :: 25;

XCB_INPUT_BARRIER_LEAVE :: 26;

XCB_INPUT_GESTURE_PINCH_BEGIN :: 27;

XCB_INPUT_GESTURE_PINCH_UPDATE :: 28;

XCB_INPUT_GESTURE_PINCH_END :: 29;

XCB_INPUT_GESTURE_SWIPE_BEGIN :: 30;

XCB_INPUT_GESTURE_SWIPE_UPDATE :: 31;

XCB_INPUT_GESTURE_SWIPE_END :: 32;

XCB_INPUT_SEND_EXTENSION_EVENT :: 31;

XCB_INPUT_DEVICE :: 0;

XCB_INPUT_EVENT :: 1;

XCB_INPUT_MODE :: 2;

XCB_INPUT_DEVICE_BUSY :: 3;

XCB_INPUT_CLASS :: 4;

xcb_xfixes_barrier_t :: u32;

xcb_input_event_class_t :: u32;

xcb_input_event_class_iterator_t :: struct {
    data:  *xcb_input_event_class_t;
    rem:   s32;
    index: s32;
}

xcb_input_key_code_t :: u8;

xcb_input_key_code_iterator_t :: struct {
    data:  *xcb_input_key_code_t;
    rem:   s32;
    index: s32;
}

xcb_input_device_id_t :: u16;

xcb_input_device_id_iterator_t :: struct {
    data:  *xcb_input_device_id_t;
    rem:   s32;
    index: s32;
}

xcb_input_fp1616_t :: s32;

xcb_input_fp1616_iterator_t :: struct {
    data:  *xcb_input_fp1616_t;
    rem:   s32;
    index: s32;
}

xcb_input_fp3232_t :: struct {
    integral: s32;
    frac:     u32;
}

xcb_input_fp3232_iterator_t :: struct {
    data:  *xcb_input_fp3232_t;
    rem:   s32;
    index: s32;
}

xcb_input_get_extension_version_cookie_t :: struct {
    sequence: u32;
}

xcb_input_get_extension_version_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    name_len:     u16;
    pad0:         [2] u8;
}

xcb_input_get_extension_version_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    server_major:  u16;
    server_minor:  u16;
    present:       u8;
    pad0:          [19] u8;
}

xcb_input_device_use_t :: enum u32 {
    POINTER            :: 0;
    KEYBOARD           :: 1;
    EXTENSION_DEVICE   :: 2;
    EXTENSION_KEYBOARD :: 3;
    EXTENSION_POINTER  :: 4;

    XCB_INPUT_DEVICE_USE_IS_X_POINTER            :: POINTER;
    XCB_INPUT_DEVICE_USE_IS_X_KEYBOARD           :: KEYBOARD;
    XCB_INPUT_DEVICE_USE_IS_X_EXTENSION_DEVICE   :: EXTENSION_DEVICE;
    XCB_INPUT_DEVICE_USE_IS_X_EXTENSION_KEYBOARD :: EXTENSION_KEYBOARD;
    XCB_INPUT_DEVICE_USE_IS_X_EXTENSION_POINTER  :: EXTENSION_POINTER;
}

xcb_input_input_class_t :: enum u32 {
    KEY       :: 0;
    BUTTON    :: 1;
    VALUATOR  :: 2;
    FEEDBACK  :: 3;
    PROXIMITY :: 4;
    FOCUS     :: 5;
    OTHER     :: 6;

    XCB_INPUT_INPUT_CLASS_KEY       :: KEY;
    XCB_INPUT_INPUT_CLASS_BUTTON    :: BUTTON;
    XCB_INPUT_INPUT_CLASS_VALUATOR  :: VALUATOR;
    XCB_INPUT_INPUT_CLASS_FEEDBACK  :: FEEDBACK;
    XCB_INPUT_INPUT_CLASS_PROXIMITY :: PROXIMITY;
    XCB_INPUT_INPUT_CLASS_FOCUS     :: FOCUS;
    XCB_INPUT_INPUT_CLASS_OTHER     :: OTHER;
}

xcb_input_valuator_mode_t :: enum u32 {
    RELATIVE :: 0;
    ABSOLUTE :: 1;

    XCB_INPUT_VALUATOR_MODE_RELATIVE :: RELATIVE;
    XCB_INPUT_VALUATOR_MODE_ABSOLUTE :: ABSOLUTE;
}

xcb_input_device_info_t :: struct {
    device_type:    xcb_atom_t;
    device_id:      u8;
    num_class_info: u8;
    device_use:     u8;
    pad0:           u8;
}

xcb_input_device_info_iterator_t :: struct {
    data:  *xcb_input_device_info_t;
    rem:   s32;
    index: s32;
}

xcb_input_key_info_t :: struct {
    class_id:    u8;
    len:         u8;
    min_keycode: xcb_input_key_code_t;
    max_keycode: xcb_input_key_code_t;
    num_keys:    u16;
    pad0:        [2] u8;
}

xcb_input_key_info_iterator_t :: struct {
    data:  *xcb_input_key_info_t;
    rem:   s32;
    index: s32;
}

xcb_input_button_info_t :: struct {
    class_id:    u8;
    len:         u8;
    num_buttons: u16;
}

xcb_input_button_info_iterator_t :: struct {
    data:  *xcb_input_button_info_t;
    rem:   s32;
    index: s32;
}

xcb_input_axis_info_t :: struct {
    resolution: u32;
    minimum:    s32;
    maximum:    s32;
}

xcb_input_axis_info_iterator_t :: struct {
    data:  *xcb_input_axis_info_t;
    rem:   s32;
    index: s32;
}

xcb_input_valuator_info_t :: struct {
    class_id:    u8;
    len:         u8;
    axes_len:    u8;
    mode:        u8;
    motion_size: u32;
}

xcb_input_valuator_info_iterator_t :: struct {
    data:  *xcb_input_valuator_info_t;
    rem:   s32;
    index: s32;
}

xcb_input_input_info_info_t :: struct {
    key:      struct {
        min_keycode: xcb_input_key_code_t;
        max_keycode: xcb_input_key_code_t;
        num_keys:    u16;
        pad0:        [2] u8;
    };

    button:   struct {
        num_buttons: u16;
    };

    valuator: struct {
        axes_len:    u8;
        mode:        u8;
        motion_size: u32;
        axes:        *xcb_input_axis_info_t;
    };
}

xcb_input_input_info_t :: struct {
    class_id: u8;
    len:      u8;
}

xcb_input_input_info_iterator_t :: struct {
    data:  *xcb_input_input_info_t;
    rem:   s32;
    index: s32;
}

xcb_input_device_name_t :: struct {
    len: u8;
}

xcb_input_device_name_iterator_t :: struct {
    data:  *xcb_input_device_name_t;
    rem:   s32;
    index: s32;
}

xcb_input_list_input_devices_cookie_t :: struct {
    sequence: u32;
}

xcb_input_list_input_devices_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
}

xcb_input_list_input_devices_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    devices_len:   u8;
    pad0:          [23] u8;
}

xcb_input_event_type_base_t :: u8;

xcb_input_event_type_base_iterator_t :: struct {
    data:  *xcb_input_event_type_base_t;
    rem:   s32;
    index: s32;
}

xcb_input_input_class_info_t :: struct {
    class_id:        u8;
    event_type_base: xcb_input_event_type_base_t;
}

xcb_input_input_class_info_iterator_t :: struct {
    data:  *xcb_input_input_class_info_t;
    rem:   s32;
    index: s32;
}

xcb_input_open_device_cookie_t :: struct {
    sequence: u32;
}

xcb_input_open_device_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    device_id:    u8;
    pad0:         [3] u8;
}

xcb_input_open_device_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    num_classes:   u8;
    pad0:          [23] u8;
}

xcb_input_close_device_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    device_id:    u8;
    pad0:         [3] u8;
}

xcb_input_set_device_mode_cookie_t :: struct {
    sequence: u32;
}

xcb_input_set_device_mode_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    device_id:    u8;
    mode:         u8;
    pad0:         [2] u8;
}

xcb_input_set_device_mode_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    status:        u8;
    pad0:          [23] u8;
}

xcb_input_select_extension_event_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    window:       xcb_window_t;
    num_classes:  u16;
    pad0:         [2] u8;
}

xcb_input_get_selected_extension_events_cookie_t :: struct {
    sequence: u32;
}

xcb_input_get_selected_extension_events_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_input_get_selected_extension_events_reply_t :: struct {
    response_type:    u8;
    xi_reply_type:    u8;
    sequence:         u16;
    length:           u32;
    num_this_classes: u16;
    num_all_classes:  u16;
    pad0:             [20] u8;
}

xcb_input_propagate_mode_t :: enum u32 {
    ADD_TO_LIST      :: 0;
    DELETE_FROM_LIST :: 1;

    XCB_INPUT_PROPAGATE_MODE_ADD_TO_LIST      :: ADD_TO_LIST;
    XCB_INPUT_PROPAGATE_MODE_DELETE_FROM_LIST :: DELETE_FROM_LIST;
}

xcb_input_change_device_dont_propagate_list_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    window:       xcb_window_t;
    num_classes:  u16;
    mode:         u8;
    pad0:         u8;
}

xcb_input_get_device_dont_propagate_list_cookie_t :: struct {
    sequence: u32;
}

xcb_input_get_device_dont_propagate_list_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_input_get_device_dont_propagate_list_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    num_classes:   u16;
    pad0:          [22] u8;
}

xcb_input_device_time_coord_t :: struct {
    time: xcb_timestamp_t;
}

xcb_input_device_time_coord_iterator_t :: struct {
    data:     *xcb_input_device_time_coord_t;
    rem:      s32;
    index:    s32;
    num_axes: u8;
}

xcb_input_get_device_motion_events_cookie_t :: struct {
    sequence: u32;
}

xcb_input_get_device_motion_events_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    start:        xcb_timestamp_t;
    stop:         xcb_timestamp_t;
    device_id:    u8;
    pad0:         [3] u8;
}

xcb_input_get_device_motion_events_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    num_events:    u32;
    num_axes:      u8;
    device_mode:   u8;
    pad0:          [18] u8;
}

xcb_input_change_keyboard_device_cookie_t :: struct {
    sequence: u32;
}

xcb_input_change_keyboard_device_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    device_id:    u8;
    pad0:         [3] u8;
}

xcb_input_change_keyboard_device_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    status:        u8;
    pad0:          [23] u8;
}

xcb_input_change_pointer_device_cookie_t :: struct {
    sequence: u32;
}

xcb_input_change_pointer_device_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    x_axis:       u8;
    y_axis:       u8;
    device_id:    u8;
    pad0:         u8;
}

xcb_input_change_pointer_device_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    status:        u8;
    pad0:          [23] u8;
}

xcb_input_grab_device_cookie_t :: struct {
    sequence: u32;
}

xcb_input_grab_device_request_t :: struct {
    major_opcode:      u8;
    minor_opcode:      u8;
    length:            u16;
    grab_window:       xcb_window_t;
    time:              xcb_timestamp_t;
    num_classes:       u16;
    this_device_mode:  u8;
    other_device_mode: u8;
    owner_events:      u8;
    device_id:         u8;
    pad0:              [2] u8;
}

xcb_input_grab_device_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    status:        u8;
    pad0:          [23] u8;
}

xcb_input_ungrab_device_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    time:         xcb_timestamp_t;
    device_id:    u8;
    pad0:         [3] u8;
}

xcb_input_modifier_device_t :: enum u32 {
    XCB_INPUT_MODIFIER_DEVICE_USE_X_KEYBOARD :: 255;
}

xcb_input_grab_device_key_request_t :: struct {
    major_opcode:      u8;
    minor_opcode:      u8;
    length:            u16;
    grab_window:       xcb_window_t;
    num_classes:       u16;
    modifiers:         u16;
    modifier_device:   u8;
    grabbed_device:    u8;
    key:               u8;
    this_device_mode:  u8;
    other_device_mode: u8;
    owner_events:      u8;
    pad0:              [2] u8;
}

xcb_input_ungrab_device_key_request_t :: struct {
    major_opcode:    u8;
    minor_opcode:    u8;
    length:          u16;
    grabWindow:      xcb_window_t;
    modifiers:       u16;
    modifier_device: u8;
    key:             u8;
    grabbed_device:  u8;
}

xcb_input_grab_device_button_request_t :: struct {
    major_opcode:      u8;
    minor_opcode:      u8;
    length:            u16;
    grab_window:       xcb_window_t;
    grabbed_device:    u8;
    modifier_device:   u8;
    num_classes:       u16;
    modifiers:         u16;
    this_device_mode:  u8;
    other_device_mode: u8;
    button:            u8;
    owner_events:      u8;
    pad0:              [2] u8;
}

xcb_input_ungrab_device_button_request_t :: struct {
    major_opcode:    u8;
    minor_opcode:    u8;
    length:          u16;
    grab_window:     xcb_window_t;
    modifiers:       u16;
    modifier_device: u8;
    button:          u8;
    grabbed_device:  u8;
    pad0:            [3] u8;
}

xcb_input_device_input_mode_t :: enum u32 {
    ASYNC_THIS_DEVICE   :: 0;
    SYNC_THIS_DEVICE    :: 1;
    REPLAY_THIS_DEVICE  :: 2;
    ASYNC_OTHER_DEVICES :: 3;
    ASYNC_ALL           :: 4;
    SYNC_ALL            :: 5;

    XCB_INPUT_DEVICE_INPUT_MODE_ASYNC_THIS_DEVICE   :: ASYNC_THIS_DEVICE;
    XCB_INPUT_DEVICE_INPUT_MODE_SYNC_THIS_DEVICE    :: SYNC_THIS_DEVICE;
    XCB_INPUT_DEVICE_INPUT_MODE_REPLAY_THIS_DEVICE  :: REPLAY_THIS_DEVICE;
    XCB_INPUT_DEVICE_INPUT_MODE_ASYNC_OTHER_DEVICES :: ASYNC_OTHER_DEVICES;
    XCB_INPUT_DEVICE_INPUT_MODE_ASYNC_ALL           :: ASYNC_ALL;
    XCB_INPUT_DEVICE_INPUT_MODE_SYNC_ALL            :: SYNC_ALL;
}

xcb_input_allow_device_events_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    time:         xcb_timestamp_t;
    mode:         u8;
    device_id:    u8;
    pad0:         [2] u8;
}

xcb_input_get_device_focus_cookie_t :: struct {
    sequence: u32;
}

xcb_input_get_device_focus_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    device_id:    u8;
    pad0:         [3] u8;
}

xcb_input_get_device_focus_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    focus:         xcb_window_t;
    time:          xcb_timestamp_t;
    revert_to:     u8;
    pad0:          [15] u8;
}

xcb_input_set_device_focus_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    focus:        xcb_window_t;
    time:         xcb_timestamp_t;
    revert_to:    u8;
    device_id:    u8;
    pad0:         [2] u8;
}

xcb_input_feedback_class_t :: enum u32 {
    KEYBOARD :: 0;
    POINTER  :: 1;
    STRING   :: 2;
    INTEGER  :: 3;
    LED      :: 4;
    BELL     :: 5;

    XCB_INPUT_FEEDBACK_CLASS_KEYBOARD :: KEYBOARD;
    XCB_INPUT_FEEDBACK_CLASS_POINTER  :: POINTER;
    XCB_INPUT_FEEDBACK_CLASS_STRING   :: STRING;
    XCB_INPUT_FEEDBACK_CLASS_INTEGER  :: INTEGER;
    XCB_INPUT_FEEDBACK_CLASS_LED      :: LED;
    XCB_INPUT_FEEDBACK_CLASS_BELL     :: BELL;
}

xcb_input_kbd_feedback_state_t :: struct {
    class_id:           u8;
    feedback_id:        u8;
    len:                u16;
    pitch:              u16;
    duration:           u16;
    led_mask:           u32;
    led_values:         u32;
    global_auto_repeat: u8;
    click:              u8;
    percent:            u8;
    pad0:               u8;
    auto_repeats:       [32] u8;
}

xcb_input_kbd_feedback_state_iterator_t :: struct {
    data:  *xcb_input_kbd_feedback_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_ptr_feedback_state_t :: struct {
    class_id:    u8;
    feedback_id: u8;
    len:         u16;
    pad0:        [2] u8;
    accel_num:   u16;
    accel_denom: u16;
    threshold:   u16;
}

xcb_input_ptr_feedback_state_iterator_t :: struct {
    data:  *xcb_input_ptr_feedback_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_integer_feedback_state_t :: struct {
    class_id:    u8;
    feedback_id: u8;
    len:         u16;
    resolution:  u32;
    min_value:   s32;
    max_value:   s32;
}

xcb_input_integer_feedback_state_iterator_t :: struct {
    data:  *xcb_input_integer_feedback_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_string_feedback_state_t :: struct {
    class_id:    u8;
    feedback_id: u8;
    len:         u16;
    max_symbols: u16;
    num_keysyms: u16;
}

xcb_input_string_feedback_state_iterator_t :: struct {
    data:  *xcb_input_string_feedback_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_bell_feedback_state_t :: struct {
    class_id:    u8;
    feedback_id: u8;
    len:         u16;
    percent:     u8;
    pad0:        [3] u8;
    pitch:       u16;
    duration:    u16;
}

xcb_input_bell_feedback_state_iterator_t :: struct {
    data:  *xcb_input_bell_feedback_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_led_feedback_state_t :: struct {
    class_id:    u8;
    feedback_id: u8;
    len:         u16;
    led_mask:    u32;
    led_values:  u32;
}

xcb_input_led_feedback_state_iterator_t :: struct {
    data:  *xcb_input_led_feedback_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_feedback_state_data_t :: struct {
    keyboard: struct {
        pitch:              u16;
        duration:           u16;
        led_mask:           u32;
        led_values:         u32;
        global_auto_repeat: u8;
        click:              u8;
        percent:            u8;
        pad0:               u8;
        auto_repeats:       [32] u8;
    };

    pointer:  struct {
        pad1:        [2] u8;
        accel_num:   u16;
        accel_denom: u16;
        threshold:   u16;
    };

    _string:  struct {
        max_symbols: u16;
        num_keysyms: u16;
        keysyms:     *xcb_keysym_t;
    };

    integer:  struct {
        resolution: u32;
        min_value:  s32;
        max_value:  s32;
    };

    led:      struct {
        led_mask:   u32;
        led_values: u32;
    };

    bell:     struct {
        percent:  u8;
        pad2:     [3] u8;
        pitch:    u16;
        duration: u16;
    };
}

xcb_input_feedback_state_t :: struct {
    class_id:    u8;
    feedback_id: u8;
    len:         u16;
}

xcb_input_feedback_state_iterator_t :: struct {
    data:  *xcb_input_feedback_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_get_feedback_control_cookie_t :: struct {
    sequence: u32;
}

xcb_input_get_feedback_control_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    device_id:    u8;
    pad0:         [3] u8;
}

xcb_input_get_feedback_control_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    num_feedbacks: u16;
    pad0:          [22] u8;
}

xcb_input_kbd_feedback_ctl_t :: struct {
    class_id:          u8;
    feedback_id:       u8;
    len:               u16;
    key:               xcb_input_key_code_t;
    auto_repeat_mode:  u8;
    key_click_percent: s8;
    bell_percent:      s8;
    bell_pitch:        s16;
    bell_duration:     s16;
    led_mask:          u32;
    led_values:        u32;
}

xcb_input_kbd_feedback_ctl_iterator_t :: struct {
    data:  *xcb_input_kbd_feedback_ctl_t;
    rem:   s32;
    index: s32;
}

xcb_input_ptr_feedback_ctl_t :: struct {
    class_id:    u8;
    feedback_id: u8;
    len:         u16;
    pad0:        [2] u8;
    num:         s16;
    denom:       s16;
    threshold:   s16;
}

xcb_input_ptr_feedback_ctl_iterator_t :: struct {
    data:  *xcb_input_ptr_feedback_ctl_t;
    rem:   s32;
    index: s32;
}

xcb_input_integer_feedback_ctl_t :: struct {
    class_id:       u8;
    feedback_id:    u8;
    len:            u16;
    int_to_display: s32;
}

xcb_input_integer_feedback_ctl_iterator_t :: struct {
    data:  *xcb_input_integer_feedback_ctl_t;
    rem:   s32;
    index: s32;
}

xcb_input_string_feedback_ctl_t :: struct {
    class_id:    u8;
    feedback_id: u8;
    len:         u16;
    pad0:        [2] u8;
    num_keysyms: u16;
}

xcb_input_string_feedback_ctl_iterator_t :: struct {
    data:  *xcb_input_string_feedback_ctl_t;
    rem:   s32;
    index: s32;
}

xcb_input_bell_feedback_ctl_t :: struct {
    class_id:    u8;
    feedback_id: u8;
    len:         u16;
    percent:     s8;
    pad0:        [3] u8;
    pitch:       s16;
    duration:    s16;
}

xcb_input_bell_feedback_ctl_iterator_t :: struct {
    data:  *xcb_input_bell_feedback_ctl_t;
    rem:   s32;
    index: s32;
}

xcb_input_led_feedback_ctl_t :: struct {
    class_id:    u8;
    feedback_id: u8;
    len:         u16;
    led_mask:    u32;
    led_values:  u32;
}

xcb_input_led_feedback_ctl_iterator_t :: struct {
    data:  *xcb_input_led_feedback_ctl_t;
    rem:   s32;
    index: s32;
}

xcb_input_feedback_ctl_data_t :: struct {
    keyboard: struct {
        key:               xcb_input_key_code_t;
        auto_repeat_mode:  u8;
        key_click_percent: s8;
        bell_percent:      s8;
        bell_pitch:        s16;
        bell_duration:     s16;
        led_mask:          u32;
        led_values:        u32;
    };

    pointer:  struct {
        pad0:      [2] u8;
        num:       s16;
        denom:     s16;
        threshold: s16;
    };

    _string:  struct {
        pad1:        [2] u8;
        num_keysyms: u16;
        keysyms:     *xcb_keysym_t;
    };

    integer:  struct {
        int_to_display: s32;
    };

    led:      struct {
        led_mask:   u32;
        led_values: u32;
    };

    bell:     struct {
        percent:  s8;
        pad2:     [3] u8;
        pitch:    s16;
        duration: s16;
    };
}

xcb_input_feedback_ctl_t :: struct {
    class_id:    u8;
    feedback_id: u8;
    len:         u16;
}

xcb_input_feedback_ctl_iterator_t :: struct {
    data:  *xcb_input_feedback_ctl_t;
    rem:   s32;
    index: s32;
}

xcb_input_change_feedback_control_mask_t :: enum u32 {
    KEY_CLICK_PERCENT :: 1;
    PERCENT           :: 2;
    PITCH             :: 4;
    DURATION          :: 8;
    LED               :: 16;
    LED_MODE          :: 32;
    KEY               :: 64;
    AUTO_REPEAT_MODE  :: 128;
    STRING            :: 1;
    INTEGER           :: 1;
    ACCEL_NUM         :: 1;
    ACCEL_DENOM       :: 2;
    THRESHOLD         :: 4;

    XCB_INPUT_CHANGE_FEEDBACK_CONTROL_MASK_KEY_CLICK_PERCENT :: KEY_CLICK_PERCENT;
    XCB_INPUT_CHANGE_FEEDBACK_CONTROL_MASK_PERCENT           :: PERCENT;
    XCB_INPUT_CHANGE_FEEDBACK_CONTROL_MASK_PITCH             :: PITCH;
    XCB_INPUT_CHANGE_FEEDBACK_CONTROL_MASK_DURATION          :: DURATION;
    XCB_INPUT_CHANGE_FEEDBACK_CONTROL_MASK_LED               :: LED;
    XCB_INPUT_CHANGE_FEEDBACK_CONTROL_MASK_LED_MODE          :: LED_MODE;
    XCB_INPUT_CHANGE_FEEDBACK_CONTROL_MASK_KEY               :: KEY;
    XCB_INPUT_CHANGE_FEEDBACK_CONTROL_MASK_AUTO_REPEAT_MODE  :: AUTO_REPEAT_MODE;
    XCB_INPUT_CHANGE_FEEDBACK_CONTROL_MASK_STRING            :: STRING;
    XCB_INPUT_CHANGE_FEEDBACK_CONTROL_MASK_INTEGER           :: INTEGER;
    XCB_INPUT_CHANGE_FEEDBACK_CONTROL_MASK_ACCEL_NUM         :: ACCEL_NUM;
    XCB_INPUT_CHANGE_FEEDBACK_CONTROL_MASK_ACCEL_DENOM       :: ACCEL_DENOM;
    XCB_INPUT_CHANGE_FEEDBACK_CONTROL_MASK_THRESHOLD         :: THRESHOLD;
}

xcb_input_change_feedback_control_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    mask:         u32;
    device_id:    u8;
    feedback_id:  u8;
    pad0:         [2] u8;
}

xcb_input_get_device_key_mapping_cookie_t :: struct {
    sequence: u32;
}

xcb_input_get_device_key_mapping_request_t :: struct {
    major_opcode:  u8;
    minor_opcode:  u8;
    length:        u16;
    device_id:     u8;
    first_keycode: xcb_input_key_code_t;
    count:         u8;
    pad0:          u8;
}

xcb_input_get_device_key_mapping_reply_t :: struct {
    response_type:       u8;
    xi_reply_type:       u8;
    sequence:            u16;
    length:              u32;
    keysyms_per_keycode: u8;
    pad0:                [23] u8;
}

xcb_input_change_device_key_mapping_request_t :: struct {
    major_opcode:        u8;
    minor_opcode:        u8;
    length:              u16;
    device_id:           u8;
    first_keycode:       xcb_input_key_code_t;
    keysyms_per_keycode: u8;
    keycode_count:       u8;
}

xcb_input_get_device_modifier_mapping_cookie_t :: struct {
    sequence: u32;
}

xcb_input_get_device_modifier_mapping_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    device_id:    u8;
    pad0:         [3] u8;
}

xcb_input_get_device_modifier_mapping_reply_t :: struct {
    response_type:         u8;
    xi_reply_type:         u8;
    sequence:              u16;
    length:                u32;
    keycodes_per_modifier: u8;
    pad0:                  [23] u8;
}

xcb_input_set_device_modifier_mapping_cookie_t :: struct {
    sequence: u32;
}

xcb_input_set_device_modifier_mapping_request_t :: struct {
    major_opcode:          u8;
    minor_opcode:          u8;
    length:                u16;
    device_id:             u8;
    keycodes_per_modifier: u8;
    pad0:                  [2] u8;
}

xcb_input_set_device_modifier_mapping_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    status:        u8;
    pad0:          [23] u8;
}

xcb_input_get_device_button_mapping_cookie_t :: struct {
    sequence: u32;
}

xcb_input_get_device_button_mapping_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    device_id:    u8;
    pad0:         [3] u8;
}

xcb_input_get_device_button_mapping_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    map_size:      u8;
    pad0:          [23] u8;
}

xcb_input_set_device_button_mapping_cookie_t :: struct {
    sequence: u32;
}

xcb_input_set_device_button_mapping_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    device_id:    u8;
    map_size:     u8;
    pad0:         [2] u8;
}

xcb_input_set_device_button_mapping_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    status:        u8;
    pad0:          [23] u8;
}

xcb_input_key_state_t :: struct {
    class_id: u8;
    len:      u8;
    num_keys: u8;
    pad0:     u8;
    keys:     [32] u8;
}

xcb_input_key_state_iterator_t :: struct {
    data:  *xcb_input_key_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_button_state_t :: struct {
    class_id:    u8;
    len:         u8;
    num_buttons: u8;
    pad0:        u8;
    buttons:     [32] u8;
}

xcb_input_button_state_iterator_t :: struct {
    data:  *xcb_input_button_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_valuator_state_mode_mask_t :: enum u32 {
    DEVICE_MODE_ABSOLUTE :: 1;
    OUT_OF_PROXIMITY     :: 2;

    XCB_INPUT_VALUATOR_STATE_MODE_MASK_DEVICE_MODE_ABSOLUTE :: DEVICE_MODE_ABSOLUTE;
    XCB_INPUT_VALUATOR_STATE_MODE_MASK_OUT_OF_PROXIMITY     :: OUT_OF_PROXIMITY;
}

xcb_input_valuator_state_t :: struct {
    class_id:      u8;
    len:           u8;
    num_valuators: u8;
    mode:          u8;
}

xcb_input_valuator_state_iterator_t :: struct {
    data:  *xcb_input_valuator_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_input_state_data_t :: struct {
    key:      struct {
        num_keys: u8;
        pad0:     u8;
        keys:     [32] u8;
    };

    button:   struct {
        num_buttons: u8;
        pad1:        u8;
        buttons:     [32] u8;
    };

    valuator: struct {
        num_valuators: u8;
        mode:          u8;
        valuators:     *s32;
    };
}

xcb_input_input_state_t :: struct {
    class_id: u8;
    len:      u8;
}

xcb_input_input_state_iterator_t :: struct {
    data:  *xcb_input_input_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_query_device_state_cookie_t :: struct {
    sequence: u32;
}

xcb_input_query_device_state_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    device_id:    u8;
    pad0:         [3] u8;
}

xcb_input_query_device_state_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    num_classes:   u8;
    pad0:          [23] u8;
}

xcb_input_device_bell_request_t :: struct {
    major_opcode:   u8;
    minor_opcode:   u8;
    length:         u16;
    device_id:      u8;
    feedback_id:    u8;
    feedback_class: u8;
    percent:        s8;
}

xcb_input_set_device_valuators_cookie_t :: struct {
    sequence: u32;
}

xcb_input_set_device_valuators_request_t :: struct {
    major_opcode:   u8;
    minor_opcode:   u8;
    length:         u16;
    device_id:      u8;
    first_valuator: u8;
    num_valuators:  u8;
    pad0:           u8;
}

xcb_input_set_device_valuators_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    status:        u8;
    pad0:          [23] u8;
}

xcb_input_device_control_t :: enum u32 {
    RESOLUTION :: 1;
    ABS_CALIB  :: 2;
    CORE       :: 3;
    ENABLE     :: 4;
    ABS_AREA   :: 5;

    XCB_INPUT_DEVICE_CONTROL_RESOLUTION :: RESOLUTION;
    XCB_INPUT_DEVICE_CONTROL_ABS_CALIB  :: ABS_CALIB;
    XCB_INPUT_DEVICE_CONTROL_CORE       :: CORE;
    XCB_INPUT_DEVICE_CONTROL_ENABLE     :: ENABLE;
    XCB_INPUT_DEVICE_CONTROL_ABS_AREA   :: ABS_AREA;
}

xcb_input_device_resolution_state_t :: struct {
    control_id:    u16;
    len:           u16;
    num_valuators: u32;
}

xcb_input_device_resolution_state_iterator_t :: struct {
    data:  *xcb_input_device_resolution_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_device_abs_calib_state_t :: struct {
    control_id:       u16;
    len:              u16;
    min_x:            s32;
    max_x:            s32;
    min_y:            s32;
    max_y:            s32;
    flip_x:           u32;
    flip_y:           u32;
    rotation:         u32;
    button_threshold: u32;
}

xcb_input_device_abs_calib_state_iterator_t :: struct {
    data:  *xcb_input_device_abs_calib_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_device_abs_area_state_t :: struct {
    control_id: u16;
    len:        u16;
    offset_x:   u32;
    offset_y:   u32;
    width:      u32;
    height:     u32;
    screen:     u32;
    following:  u32;
}

xcb_input_device_abs_area_state_iterator_t :: struct {
    data:  *xcb_input_device_abs_area_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_device_core_state_t :: struct {
    control_id: u16;
    len:        u16;
    status:     u8;
    iscore:     u8;
    pad0:       [2] u8;
}

xcb_input_device_core_state_iterator_t :: struct {
    data:  *xcb_input_device_core_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_device_enable_state_t :: struct {
    control_id: u16;
    len:        u16;
    enable:     u8;
    pad0:       [3] u8;
}

xcb_input_device_enable_state_iterator_t :: struct {
    data:  *xcb_input_device_enable_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_device_state_data_t :: struct {
    resolution: struct {
        num_valuators:     u32;
        resolution_values: *u32;
        resolution_min:    *u32;
        resolution_max:    *u32;
    };

    abs_calib:  struct {
        min_x:            s32;
        max_x:            s32;
        min_y:            s32;
        max_y:            s32;
        flip_x:           u32;
        flip_y:           u32;
        rotation:         u32;
        button_threshold: u32;
    };

    core:       struct {
        status: u8;
        iscore: u8;
        pad0:   [2] u8;
    };

    enable:     struct {
        enable: u8;
        pad1:   [3] u8;
    };

    abs_area:   struct {
        offset_x:  u32;
        offset_y:  u32;
        width:     u32;
        height:    u32;
        screen:    u32;
        following: u32;
    };
}

xcb_input_device_state_t :: struct {
    control_id: u16;
    len:        u16;
}

xcb_input_device_state_iterator_t :: struct {
    data:  *xcb_input_device_state_t;
    rem:   s32;
    index: s32;
}

xcb_input_get_device_control_cookie_t :: struct {
    sequence: u32;
}

xcb_input_get_device_control_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    control_id:   u16;
    device_id:    u8;
    pad0:         u8;
}

xcb_input_get_device_control_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    status:        u8;
    pad0:          [23] u8;
}

xcb_input_device_resolution_ctl_t :: struct {
    control_id:     u16;
    len:            u16;
    first_valuator: u8;
    num_valuators:  u8;
    pad0:           [2] u8;
}

xcb_input_device_resolution_ctl_iterator_t :: struct {
    data:  *xcb_input_device_resolution_ctl_t;
    rem:   s32;
    index: s32;
}

xcb_input_device_abs_calib_ctl_t :: struct {
    control_id:       u16;
    len:              u16;
    min_x:            s32;
    max_x:            s32;
    min_y:            s32;
    max_y:            s32;
    flip_x:           u32;
    flip_y:           u32;
    rotation:         u32;
    button_threshold: u32;
}

xcb_input_device_abs_calib_ctl_iterator_t :: struct {
    data:  *xcb_input_device_abs_calib_ctl_t;
    rem:   s32;
    index: s32;
}

xcb_input_device_abs_area_ctrl_t :: struct {
    control_id: u16;
    len:        u16;
    offset_x:   u32;
    offset_y:   u32;
    width:      s32;
    height:     s32;
    screen:     s32;
    following:  u32;
}

xcb_input_device_abs_area_ctrl_iterator_t :: struct {
    data:  *xcb_input_device_abs_area_ctrl_t;
    rem:   s32;
    index: s32;
}

xcb_input_device_core_ctrl_t :: struct {
    control_id: u16;
    len:        u16;
    status:     u8;
    pad0:       [3] u8;
}

xcb_input_device_core_ctrl_iterator_t :: struct {
    data:  *xcb_input_device_core_ctrl_t;
    rem:   s32;
    index: s32;
}

xcb_input_device_enable_ctrl_t :: struct {
    control_id: u16;
    len:        u16;
    enable:     u8;
    pad0:       [3] u8;
}

xcb_input_device_enable_ctrl_iterator_t :: struct {
    data:  *xcb_input_device_enable_ctrl_t;
    rem:   s32;
    index: s32;
}

xcb_input_device_ctl_data_t :: struct {
    resolution: struct {
        first_valuator:    u8;
        num_valuators:     u8;
        pad0:              [2] u8;
        resolution_values: *u32;
    };

    abs_calib:  struct {
        min_x:            s32;
        max_x:            s32;
        min_y:            s32;
        max_y:            s32;
        flip_x:           u32;
        flip_y:           u32;
        rotation:         u32;
        button_threshold: u32;
    };

    core:       struct {
        status: u8;
        pad1:   [3] u8;
    };

    enable:     struct {
        enable: u8;
        pad2:   [3] u8;
    };

    abs_area:   struct {
        offset_x:  u32;
        offset_y:  u32;
        width:     s32;
        height:    s32;
        screen:    s32;
        following: u32;
    };
}

xcb_input_device_ctl_t :: struct {
    control_id: u16;
    len:        u16;
}

xcb_input_device_ctl_iterator_t :: struct {
    data:  *xcb_input_device_ctl_t;
    rem:   s32;
    index: s32;
}

xcb_input_change_device_control_cookie_t :: struct {
    sequence: u32;
}

xcb_input_change_device_control_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    control_id:   u16;
    device_id:    u8;
    pad0:         u8;
}

xcb_input_change_device_control_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    status:        u8;
    pad0:          [23] u8;
}

xcb_input_list_device_properties_cookie_t :: struct {
    sequence: u32;
}

xcb_input_list_device_properties_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    device_id:    u8;
    pad0:         [3] u8;
}

xcb_input_list_device_properties_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    num_atoms:     u16;
    pad0:          [22] u8;
}

xcb_input_property_format_t :: enum u32 {
    _8_BITS  :: 8;
    _16_BITS :: 16;
    _32_BITS :: 32;

    XCB_INPUT_PROPERTY_FORMAT_8_BITS  :: _8_BITS;
    XCB_INPUT_PROPERTY_FORMAT_16_BITS :: _16_BITS;
    XCB_INPUT_PROPERTY_FORMAT_32_BITS :: _32_BITS;
}

xcb_input_change_device_property_items_t :: struct {
    data8:  *u8;
    data16: *u16;
    data32: *u32;
}

xcb_input_change_device_property_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    property:     xcb_atom_t;
    type:         xcb_atom_t;
    device_id:    u8;
    format:       u8;
    mode:         u8;
    pad0:         u8;
    num_items:    u32;
}

xcb_input_delete_device_property_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    property:     xcb_atom_t;
    device_id:    u8;
    pad0:         [3] u8;
}

xcb_input_get_device_property_cookie_t :: struct {
    sequence: u32;
}

xcb_input_get_device_property_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    property:     xcb_atom_t;
    type:         xcb_atom_t;
    offset:       u32;
    len:          u32;
    device_id:    u8;
    _delete:      u8;
    pad0:         [2] u8;
}

xcb_input_get_device_property_items_t :: struct {
    data8:  *u8;
    data16: *u16;
    data32: *u32;
}

xcb_input_get_device_property_reply_t :: struct {
    response_type: u8;
    xi_reply_type: u8;
    sequence:      u16;
    length:        u32;
    type:          xcb_atom_t;
    bytes_after:   u32;
    num_items:     u32;
    format:        u8;
    device_id:     u8;
    pad0:          [10] u8;
}

xcb_input_device_t :: enum u32 {
    ALL        :: 0;
    ALL_MASTER :: 1;

    XCB_INPUT_DEVICE_ALL        :: ALL;
    XCB_INPUT_DEVICE_ALL_MASTER :: ALL_MASTER;
}

xcb_input_group_info_t :: struct {
    base:      u8;
    latched:   u8;
    locked:    u8;
    effective: u8;
}

xcb_input_group_info_iterator_t :: struct {
    data:  *xcb_input_group_info_t;
    rem:   s32;
    index: s32;
}

xcb_input_modifier_info_t :: struct {
    base:      u32;
    latched:   u32;
    locked:    u32;
    effective: u32;
}

xcb_input_modifier_info_iterator_t :: struct {
    data:  *xcb_input_modifier_info_t;
    rem:   s32;
    index: s32;
}

xcb_input_xi_query_pointer_cookie_t :: struct {
    sequence: u32;
}

xcb_input_xi_query_pointer_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    window:       xcb_window_t;
    deviceid:     xcb_input_device_id_t;
    pad0:         [2] u8;
}

xcb_input_xi_query_pointer_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    root:          xcb_window_t;
    child:         xcb_window_t;
    root_x:        xcb_input_fp1616_t;
    root_y:        xcb_input_fp1616_t;
    win_x:         xcb_input_fp1616_t;
    win_y:         xcb_input_fp1616_t;
    same_screen:   u8;
    pad1:          u8;
    buttons_len:   u16;
    mods:          xcb_input_modifier_info_t;
    group:         xcb_input_group_info_t;
}

xcb_input_xi_warp_pointer_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    src_win:      xcb_window_t;
    dst_win:      xcb_window_t;
    src_x:        xcb_input_fp1616_t;
    src_y:        xcb_input_fp1616_t;
    src_width:    u16;
    src_height:   u16;
    dst_x:        xcb_input_fp1616_t;
    dst_y:        xcb_input_fp1616_t;
    deviceid:     xcb_input_device_id_t;
    pad0:         [2] u8;
}

xcb_input_xi_change_cursor_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    window:       xcb_window_t;
    cursor:       xcb_cursor_t;
    deviceid:     xcb_input_device_id_t;
    pad0:         [2] u8;
}

xcb_input_hierarchy_change_type_t :: enum u32 {
    ADD_MASTER    :: 1;
    REMOVE_MASTER :: 2;
    ATTACH_SLAVE  :: 3;
    DETACH_SLAVE  :: 4;

    XCB_INPUT_HIERARCHY_CHANGE_TYPE_ADD_MASTER    :: ADD_MASTER;
    XCB_INPUT_HIERARCHY_CHANGE_TYPE_REMOVE_MASTER :: REMOVE_MASTER;
    XCB_INPUT_HIERARCHY_CHANGE_TYPE_ATTACH_SLAVE  :: ATTACH_SLAVE;
    XCB_INPUT_HIERARCHY_CHANGE_TYPE_DETACH_SLAVE  :: DETACH_SLAVE;
}

xcb_input_change_mode_t :: enum u32 {
    ATTACH :: 1;
    FLOAT  :: 2;

    XCB_INPUT_CHANGE_MODE_ATTACH :: ATTACH;
    XCB_INPUT_CHANGE_MODE_FLOAT  :: FLOAT;
}

xcb_input_add_master_t :: struct {
    type:      u16;
    len:       u16;
    name_len:  u16;
    send_core: u8;
    enable:    u8;
}

xcb_input_add_master_iterator_t :: struct {
    data:  *xcb_input_add_master_t;
    rem:   s32;
    index: s32;
}

xcb_input_remove_master_t :: struct {
    type:            u16;
    len:             u16;
    deviceid:        xcb_input_device_id_t;
    return_mode:     u8;
    pad0:            u8;
    return_pointer:  xcb_input_device_id_t;
    return_keyboard: xcb_input_device_id_t;
}

xcb_input_remove_master_iterator_t :: struct {
    data:  *xcb_input_remove_master_t;
    rem:   s32;
    index: s32;
}

xcb_input_attach_slave_t :: struct {
    type:     u16;
    len:      u16;
    deviceid: xcb_input_device_id_t;
    master:   xcb_input_device_id_t;
}

xcb_input_attach_slave_iterator_t :: struct {
    data:  *xcb_input_attach_slave_t;
    rem:   s32;
    index: s32;
}

xcb_input_detach_slave_t :: struct {
    type:     u16;
    len:      u16;
    deviceid: xcb_input_device_id_t;
    pad0:     [2] u8;
}

xcb_input_detach_slave_iterator_t :: struct {
    data:  *xcb_input_detach_slave_t;
    rem:   s32;
    index: s32;
}

xcb_input_hierarchy_change_data_t :: struct {
    add_master:    struct {
        name_len:  u16;
        send_core: u8;
        enable:    u8;
        name:      *u8;
    };

    remove_master: struct {
        deviceid:        xcb_input_device_id_t;
        return_mode:     u8;
        pad1:            u8;
        return_pointer:  xcb_input_device_id_t;
        return_keyboard: xcb_input_device_id_t;
    };

    attach_slave:  struct {
        deviceid: xcb_input_device_id_t;
        master:   xcb_input_device_id_t;
    };

    detach_slave:  struct {
        deviceid: xcb_input_device_id_t;
        pad2:     [2] u8;
    };
}

xcb_input_hierarchy_change_t :: struct {
    type: u16;
    len:  u16;
}

xcb_input_hierarchy_change_iterator_t :: struct {
    data:  *xcb_input_hierarchy_change_t;
    rem:   s32;
    index: s32;
}

xcb_input_xi_change_hierarchy_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    num_changes:  u8;
    pad0:         [3] u8;
}

xcb_input_xi_set_client_pointer_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    window:       xcb_window_t;
    deviceid:     xcb_input_device_id_t;
    pad0:         [2] u8;
}

xcb_input_xi_get_client_pointer_cookie_t :: struct {
    sequence: u32;
}

xcb_input_xi_get_client_pointer_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_input_xi_get_client_pointer_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    set:           u8;
    pad1:          u8;
    deviceid:      xcb_input_device_id_t;
    pad2:          [20] u8;
}

xcb_input_xi_event_mask_t :: enum u32 {
    DEVICE_CHANGED     :: 2;
    KEY_PRESS          :: 4;
    KEY_RELEASE        :: 8;
    BUTTON_PRESS       :: 16;
    BUTTON_RELEASE     :: 32;
    MOTION             :: 64;
    ENTER              :: 128;
    LEAVE              :: 256;
    FOCUS_IN           :: 512;
    FOCUS_OUT          :: 1024;
    HIERARCHY          :: 2048;
    PROPERTY           :: 4096;
    RAW_KEY_PRESS      :: 8192;
    RAW_KEY_RELEASE    :: 16384;
    RAW_BUTTON_PRESS   :: 32768;
    RAW_BUTTON_RELEASE :: 65536;
    RAW_MOTION         :: 131072;
    TOUCH_BEGIN        :: 262144;
    TOUCH_UPDATE       :: 524288;
    TOUCH_END          :: 1048576;
    TOUCH_OWNERSHIP    :: 2097152;
    RAW_TOUCH_BEGIN    :: 4194304;
    RAW_TOUCH_UPDATE   :: 8388608;
    RAW_TOUCH_END      :: 16777216;
    BARRIER_HIT        :: 33554432;
    BARRIER_LEAVE      :: 67108864;

    XCB_INPUT_XI_EVENT_MASK_DEVICE_CHANGED     :: DEVICE_CHANGED;
    XCB_INPUT_XI_EVENT_MASK_KEY_PRESS          :: KEY_PRESS;
    XCB_INPUT_XI_EVENT_MASK_KEY_RELEASE        :: KEY_RELEASE;
    XCB_INPUT_XI_EVENT_MASK_BUTTON_PRESS       :: BUTTON_PRESS;
    XCB_INPUT_XI_EVENT_MASK_BUTTON_RELEASE     :: BUTTON_RELEASE;
    XCB_INPUT_XI_EVENT_MASK_MOTION             :: MOTION;
    XCB_INPUT_XI_EVENT_MASK_ENTER              :: ENTER;
    XCB_INPUT_XI_EVENT_MASK_LEAVE              :: LEAVE;
    XCB_INPUT_XI_EVENT_MASK_FOCUS_IN           :: FOCUS_IN;
    XCB_INPUT_XI_EVENT_MASK_FOCUS_OUT          :: FOCUS_OUT;
    XCB_INPUT_XI_EVENT_MASK_HIERARCHY          :: HIERARCHY;
    XCB_INPUT_XI_EVENT_MASK_PROPERTY           :: PROPERTY;
    XCB_INPUT_XI_EVENT_MASK_RAW_KEY_PRESS      :: RAW_KEY_PRESS;
    XCB_INPUT_XI_EVENT_MASK_RAW_KEY_RELEASE    :: RAW_KEY_RELEASE;
    XCB_INPUT_XI_EVENT_MASK_RAW_BUTTON_PRESS   :: RAW_BUTTON_PRESS;
    XCB_INPUT_XI_EVENT_MASK_RAW_BUTTON_RELEASE :: RAW_BUTTON_RELEASE;
    XCB_INPUT_XI_EVENT_MASK_RAW_MOTION         :: RAW_MOTION;
    XCB_INPUT_XI_EVENT_MASK_TOUCH_BEGIN        :: TOUCH_BEGIN;
    XCB_INPUT_XI_EVENT_MASK_TOUCH_UPDATE       :: TOUCH_UPDATE;
    XCB_INPUT_XI_EVENT_MASK_TOUCH_END          :: TOUCH_END;
    XCB_INPUT_XI_EVENT_MASK_TOUCH_OWNERSHIP    :: TOUCH_OWNERSHIP;
    XCB_INPUT_XI_EVENT_MASK_RAW_TOUCH_BEGIN    :: RAW_TOUCH_BEGIN;
    XCB_INPUT_XI_EVENT_MASK_RAW_TOUCH_UPDATE   :: RAW_TOUCH_UPDATE;
    XCB_INPUT_XI_EVENT_MASK_RAW_TOUCH_END      :: RAW_TOUCH_END;
    XCB_INPUT_XI_EVENT_MASK_BARRIER_HIT        :: BARRIER_HIT;
    XCB_INPUT_XI_EVENT_MASK_BARRIER_LEAVE      :: BARRIER_LEAVE;
}

xcb_input_event_mask_t :: struct {
    deviceid: xcb_input_device_id_t;
    mask_len: u16;
}

xcb_input_event_mask_iterator_t :: struct {
    data:  *xcb_input_event_mask_t;
    rem:   s32;
    index: s32;
}

xcb_input_xi_select_events_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    window:       xcb_window_t;
    num_mask:     u16;
    pad0:         [2] u8;
}

xcb_input_xi_query_version_cookie_t :: struct {
    sequence: u32;
}

xcb_input_xi_query_version_request_t :: struct {
    major_opcode:  u8;
    minor_opcode:  u8;
    length:        u16;
    major_version: u16;
    minor_version: u16;
}

xcb_input_xi_query_version_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    major_version: u16;
    minor_version: u16;
    pad1:          [20] u8;
}

xcb_input_device_class_type_t :: enum u32 {
    KEY      :: 0;
    BUTTON   :: 1;
    VALUATOR :: 2;
    SCROLL   :: 3;
    TOUCH    :: 8;
    GESTURE  :: 9;

    XCB_INPUT_DEVICE_CLASS_TYPE_KEY      :: KEY;
    XCB_INPUT_DEVICE_CLASS_TYPE_BUTTON   :: BUTTON;
    XCB_INPUT_DEVICE_CLASS_TYPE_VALUATOR :: VALUATOR;
    XCB_INPUT_DEVICE_CLASS_TYPE_SCROLL   :: SCROLL;
    XCB_INPUT_DEVICE_CLASS_TYPE_TOUCH    :: TOUCH;
    XCB_INPUT_DEVICE_CLASS_TYPE_GESTURE  :: GESTURE;
}

xcb_input_device_type_t :: enum u32 {
    MASTER_POINTER  :: 1;
    MASTER_KEYBOARD :: 2;
    SLAVE_POINTER   :: 3;
    SLAVE_KEYBOARD  :: 4;
    FLOATING_SLAVE  :: 5;

    XCB_INPUT_DEVICE_TYPE_MASTER_POINTER  :: MASTER_POINTER;
    XCB_INPUT_DEVICE_TYPE_MASTER_KEYBOARD :: MASTER_KEYBOARD;
    XCB_INPUT_DEVICE_TYPE_SLAVE_POINTER   :: SLAVE_POINTER;
    XCB_INPUT_DEVICE_TYPE_SLAVE_KEYBOARD  :: SLAVE_KEYBOARD;
    XCB_INPUT_DEVICE_TYPE_FLOATING_SLAVE  :: FLOATING_SLAVE;
}

xcb_input_scroll_flags_t :: enum u32 {
    NO_EMULATION :: 1;
    PREFERRED    :: 2;

    XCB_INPUT_SCROLL_FLAGS_NO_EMULATION :: NO_EMULATION;
    XCB_INPUT_SCROLL_FLAGS_PREFERRED    :: PREFERRED;
}

xcb_input_scroll_type_t :: enum u32 {
    VERTICAL   :: 1;
    HORIZONTAL :: 2;

    XCB_INPUT_SCROLL_TYPE_VERTICAL   :: VERTICAL;
    XCB_INPUT_SCROLL_TYPE_HORIZONTAL :: HORIZONTAL;
}

xcb_input_touch_mode_t :: enum u32 {
    DIRECT    :: 1;
    DEPENDENT :: 2;

    XCB_INPUT_TOUCH_MODE_DIRECT    :: DIRECT;
    XCB_INPUT_TOUCH_MODE_DEPENDENT :: DEPENDENT;
}

xcb_input_button_class_t :: struct {
    type:        u16;
    len:         u16;
    sourceid:    xcb_input_device_id_t;
    num_buttons: u16;
}

xcb_input_button_class_iterator_t :: struct {
    data:  *xcb_input_button_class_t;
    rem:   s32;
    index: s32;
}

xcb_input_key_class_t :: struct {
    type:     u16;
    len:      u16;
    sourceid: xcb_input_device_id_t;
    num_keys: u16;
}

xcb_input_key_class_iterator_t :: struct {
    data:  *xcb_input_key_class_t;
    rem:   s32;
    index: s32;
}

xcb_input_scroll_class_t :: struct {
    type:        u16;
    len:         u16;
    sourceid:    xcb_input_device_id_t;
    number:      u16;
    scroll_type: u16;
    pad0:        [2] u8;
    flags:       u32;
    increment:   xcb_input_fp3232_t;
}

xcb_input_scroll_class_iterator_t :: struct {
    data:  *xcb_input_scroll_class_t;
    rem:   s32;
    index: s32;
}

xcb_input_touch_class_t :: struct {
    type:        u16;
    len:         u16;
    sourceid:    xcb_input_device_id_t;
    mode:        u8;
    num_touches: u8;
}

xcb_input_touch_class_iterator_t :: struct {
    data:  *xcb_input_touch_class_t;
    rem:   s32;
    index: s32;
}

xcb_input_gesture_class_t :: struct {
    type:        u16;
    len:         u16;
    sourceid:    xcb_input_device_id_t;
    num_touches: u8;
    pad0:        u8;
}

xcb_input_gesture_class_iterator_t :: struct {
    data:  *xcb_input_gesture_class_t;
    rem:   s32;
    index: s32;
}

xcb_input_valuator_class_t :: struct {
    type:       u16;
    len:        u16;
    sourceid:   xcb_input_device_id_t;
    number:     u16;
    label:      xcb_atom_t;
    min:        xcb_input_fp3232_t;
    max:        xcb_input_fp3232_t;
    value:      xcb_input_fp3232_t;
    resolution: u32;
    mode:       u8;
    pad0:       [3] u8;
}

xcb_input_valuator_class_iterator_t :: struct {
    data:  *xcb_input_valuator_class_t;
    rem:   s32;
    index: s32;
}

xcb_input_device_class_data_t :: struct {
    key:      struct {
        num_keys: u16;
        keys:     *u32;
    };

    button:   struct {
        num_buttons: u16;
        state:       *u32;
        labels:      *xcb_atom_t;
    };

    valuator: struct {
        number:     u16;
        label:      xcb_atom_t;
        min:        xcb_input_fp3232_t;
        max:        xcb_input_fp3232_t;
        value:      xcb_input_fp3232_t;
        resolution: u32;
        mode:       u8;
        pad0:       [3] u8;
    };

    scroll:   struct {
        number:      u16;
        scroll_type: u16;
        pad1:        [2] u8;
        flags:       u32;
        increment:   xcb_input_fp3232_t;
    };

    touch:    struct {
        mode:        u8;
        num_touches: u8;
    };

    gesture:  struct {
        num_touches: u8;
        pad2:        u8;
    };
}

xcb_input_device_class_t :: struct {
    type:     u16;
    len:      u16;
    sourceid: xcb_input_device_id_t;
}

xcb_input_device_class_iterator_t :: struct {
    data:  *xcb_input_device_class_t;
    rem:   s32;
    index: s32;
}

xcb_input_xi_device_info_t :: struct {
    deviceid:    xcb_input_device_id_t;
    type:        u16;
    attachment:  xcb_input_device_id_t;
    num_classes: u16;
    name_len:    u16;
    enabled:     u8;
    pad0:        u8;
}

xcb_input_xi_device_info_iterator_t :: struct {
    data:  *xcb_input_xi_device_info_t;
    rem:   s32;
    index: s32;
}

xcb_input_xi_query_device_cookie_t :: struct {
    sequence: u32;
}

xcb_input_xi_query_device_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceid:     xcb_input_device_id_t;
    pad0:         [2] u8;
}

xcb_input_xi_query_device_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    num_infos:     u16;
    pad1:          [22] u8;
}

xcb_input_xi_set_focus_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    window:       xcb_window_t;
    time:         xcb_timestamp_t;
    deviceid:     xcb_input_device_id_t;
    pad0:         [2] u8;
}

xcb_input_xi_get_focus_cookie_t :: struct {
    sequence: u32;
}

xcb_input_xi_get_focus_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceid:     xcb_input_device_id_t;
    pad0:         [2] u8;
}

xcb_input_xi_get_focus_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    focus:         xcb_window_t;
    pad1:          [20] u8;
}

xcb_input_grab_owner_t :: enum u32 {
    NO_OWNER :: 0;
    OWNER    :: 1;

    XCB_INPUT_GRAB_OWNER_NO_OWNER :: NO_OWNER;
    XCB_INPUT_GRAB_OWNER_OWNER    :: OWNER;
}

xcb_input_xi_grab_device_cookie_t :: struct {
    sequence: u32;
}

xcb_input_xi_grab_device_request_t :: struct {
    major_opcode:       u8;
    minor_opcode:       u8;
    length:             u16;
    window:             xcb_window_t;
    time:               xcb_timestamp_t;
    cursor:             xcb_cursor_t;
    deviceid:           xcb_input_device_id_t;
    mode:               u8;
    paired_device_mode: u8;
    owner_events:       u8;
    pad0:               u8;
    mask_len:           u16;
}

xcb_input_xi_grab_device_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    status:        u8;
    pad1:          [23] u8;
}

xcb_input_xi_ungrab_device_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    time:         xcb_timestamp_t;
    deviceid:     xcb_input_device_id_t;
    pad0:         [2] u8;
}

xcb_input_event_mode_t :: enum u32 {
    ASYNC_DEVICE        :: 0;
    SYNC_DEVICE         :: 1;
    REPLAY_DEVICE       :: 2;
    ASYNC_PAIRED_DEVICE :: 3;
    ASYNC_PAIR          :: 4;
    SYNC_PAIR           :: 5;
    ACCEPT_TOUCH        :: 6;
    REJECT_TOUCH        :: 7;

    XCB_INPUT_EVENT_MODE_ASYNC_DEVICE        :: ASYNC_DEVICE;
    XCB_INPUT_EVENT_MODE_SYNC_DEVICE         :: SYNC_DEVICE;
    XCB_INPUT_EVENT_MODE_REPLAY_DEVICE       :: REPLAY_DEVICE;
    XCB_INPUT_EVENT_MODE_ASYNC_PAIRED_DEVICE :: ASYNC_PAIRED_DEVICE;
    XCB_INPUT_EVENT_MODE_ASYNC_PAIR          :: ASYNC_PAIR;
    XCB_INPUT_EVENT_MODE_SYNC_PAIR           :: SYNC_PAIR;
    XCB_INPUT_EVENT_MODE_ACCEPT_TOUCH        :: ACCEPT_TOUCH;
    XCB_INPUT_EVENT_MODE_REJECT_TOUCH        :: REJECT_TOUCH;
}

xcb_input_xi_allow_events_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    time:         xcb_timestamp_t;
    deviceid:     xcb_input_device_id_t;
    event_mode:   u8;
    pad0:         u8;
    touchid:      u32;
    grab_window:  xcb_window_t;
}

xcb_input_grab_mode_22_t :: enum u32 {
    SYNC  :: 0;
    ASYNC :: 1;
    TOUCH :: 2;

    XCB_INPUT_GRAB_MODE_22_SYNC  :: SYNC;
    XCB_INPUT_GRAB_MODE_22_ASYNC :: ASYNC;
    XCB_INPUT_GRAB_MODE_22_TOUCH :: TOUCH;
}

xcb_input_grab_type_t :: enum u32 {
    BUTTON              :: 0;
    KEYCODE             :: 1;
    ENTER               :: 2;
    FOCUS_IN            :: 3;
    TOUCH_BEGIN         :: 4;
    GESTURE_PINCH_BEGIN :: 5;
    GESTURE_SWIPE_BEGIN :: 6;

    XCB_INPUT_GRAB_TYPE_BUTTON              :: BUTTON;
    XCB_INPUT_GRAB_TYPE_KEYCODE             :: KEYCODE;
    XCB_INPUT_GRAB_TYPE_ENTER               :: ENTER;
    XCB_INPUT_GRAB_TYPE_FOCUS_IN            :: FOCUS_IN;
    XCB_INPUT_GRAB_TYPE_TOUCH_BEGIN         :: TOUCH_BEGIN;
    XCB_INPUT_GRAB_TYPE_GESTURE_PINCH_BEGIN :: GESTURE_PINCH_BEGIN;
    XCB_INPUT_GRAB_TYPE_GESTURE_SWIPE_BEGIN :: GESTURE_SWIPE_BEGIN;
}

xcb_input_modifier_mask_t :: enum u32 {
    XCB_INPUT_MODIFIER_MASK_ANY :: 2147483648;
}

xcb_input_grab_modifier_info_t :: struct {
    modifiers: u32;
    status:    u8;
    pad0:      [3] u8;
}

xcb_input_grab_modifier_info_iterator_t :: struct {
    data:  *xcb_input_grab_modifier_info_t;
    rem:   s32;
    index: s32;
}

xcb_input_xi_passive_grab_device_cookie_t :: struct {
    sequence: u32;
}

xcb_input_xi_passive_grab_device_request_t :: struct {
    major_opcode:       u8;
    minor_opcode:       u8;
    length:             u16;
    time:               xcb_timestamp_t;
    grab_window:        xcb_window_t;
    cursor:             xcb_cursor_t;
    detail:             u32;
    deviceid:           xcb_input_device_id_t;
    num_modifiers:      u16;
    mask_len:           u16;
    grab_type:          u8;
    grab_mode:          u8;
    paired_device_mode: u8;
    owner_events:       u8;
    pad0:               [2] u8;
}

xcb_input_xi_passive_grab_device_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    num_modifiers: u16;
    pad1:          [22] u8;
}

xcb_input_xi_passive_ungrab_device_request_t :: struct {
    major_opcode:  u8;
    minor_opcode:  u8;
    length:        u16;
    grab_window:   xcb_window_t;
    detail:        u32;
    deviceid:      xcb_input_device_id_t;
    num_modifiers: u16;
    grab_type:     u8;
    pad0:          [3] u8;
}

xcb_input_xi_list_properties_cookie_t :: struct {
    sequence: u32;
}

xcb_input_xi_list_properties_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceid:     xcb_input_device_id_t;
    pad0:         [2] u8;
}

xcb_input_xi_list_properties_reply_t :: struct {
    response_type:  u8;
    pad0:           u8;
    sequence:       u16;
    length:         u32;
    num_properties: u16;
    pad1:           [22] u8;
}

xcb_input_xi_change_property_items_t :: struct {
    data8:  *u8;
    data16: *u16;
    data32: *u32;
}

xcb_input_xi_change_property_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceid:     xcb_input_device_id_t;
    mode:         u8;
    format:       u8;
    property:     xcb_atom_t;
    type:         xcb_atom_t;
    num_items:    u32;
}

xcb_input_xi_delete_property_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceid:     xcb_input_device_id_t;
    pad0:         [2] u8;
    property:     xcb_atom_t;
}

xcb_input_xi_get_property_cookie_t :: struct {
    sequence: u32;
}

xcb_input_xi_get_property_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceid:     xcb_input_device_id_t;
    _delete:      u8;
    pad0:         u8;
    property:     xcb_atom_t;
    type:         xcb_atom_t;
    offset:       u32;
    len:          u32;
}

xcb_input_xi_get_property_items_t :: struct {
    data8:  *u8;
    data16: *u16;
    data32: *u32;
}

xcb_input_xi_get_property_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    type:          xcb_atom_t;
    bytes_after:   u32;
    num_items:     u32;
    format:        u8;
    pad1:          [11] u8;
}

xcb_input_xi_get_selected_events_cookie_t :: struct {
    sequence: u32;
}

xcb_input_xi_get_selected_events_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_input_xi_get_selected_events_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    num_masks:     u16;
    pad1:          [22] u8;
}

xcb_input_barrier_release_pointer_info_t :: struct {
    deviceid: xcb_input_device_id_t;
    pad0:     [2] u8;
    barrier:  xcb_xfixes_barrier_t;
    eventid:  u32;
}

xcb_input_barrier_release_pointer_info_iterator_t :: struct {
    data:  *xcb_input_barrier_release_pointer_info_t;
    rem:   s32;
    index: s32;
}

xcb_input_xi_barrier_release_pointer_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    num_barriers: u32;
}

xcb_input_device_valuator_event_t :: struct {
    response_type:  u8;
    device_id:      u8;
    sequence:       u16;
    device_state:   u16;
    num_valuators:  u8;
    first_valuator: u8;
    valuators:      [6] s32;
}

xcb_input_more_events_mask_t :: enum u32 {
    XCB_INPUT_MORE_EVENTS_MASK_MORE_EVENTS :: 128;
}

xcb_input_device_key_press_event_t :: struct {
    response_type: u8;
    detail:        u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    root:          xcb_window_t;
    event:         xcb_window_t;
    child:         xcb_window_t;
    root_x:        s16;
    root_y:        s16;
    event_x:       s16;
    event_y:       s16;
    state:         u16;
    same_screen:   u8;
    device_id:     u8;
}

xcb_input_device_key_release_event_t :: xcb_input_device_key_press_event_t;

xcb_input_device_button_press_event_t :: xcb_input_device_key_press_event_t;

xcb_input_device_button_release_event_t :: xcb_input_device_key_press_event_t;

xcb_input_device_motion_notify_event_t :: xcb_input_device_key_press_event_t;

xcb_input_device_focus_in_event_t :: struct {
    response_type: u8;
    detail:        u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    window:        xcb_window_t;
    mode:          u8;
    device_id:     u8;
    pad0:          [18] u8;
}

xcb_input_device_focus_out_event_t :: xcb_input_device_focus_in_event_t;

xcb_input_proximity_in_event_t :: xcb_input_device_key_press_event_t;

xcb_input_proximity_out_event_t :: xcb_input_device_key_press_event_t;

xcb_input_classes_reported_mask_t :: enum u32 {
    OUT_OF_PROXIMITY     :: 128;
    DEVICE_MODE_ABSOLUTE :: 64;
    REPORTING_VALUATORS  :: 4;
    REPORTING_BUTTONS    :: 2;
    REPORTING_KEYS       :: 1;

    XCB_INPUT_CLASSES_REPORTED_MASK_OUT_OF_PROXIMITY     :: OUT_OF_PROXIMITY;
    XCB_INPUT_CLASSES_REPORTED_MASK_DEVICE_MODE_ABSOLUTE :: DEVICE_MODE_ABSOLUTE;
    XCB_INPUT_CLASSES_REPORTED_MASK_REPORTING_VALUATORS  :: REPORTING_VALUATORS;
    XCB_INPUT_CLASSES_REPORTED_MASK_REPORTING_BUTTONS    :: REPORTING_BUTTONS;
    XCB_INPUT_CLASSES_REPORTED_MASK_REPORTING_KEYS       :: REPORTING_KEYS;
}

xcb_input_device_state_notify_event_t :: struct {
    response_type:    u8;
    device_id:        u8;
    sequence:         u16;
    time:             xcb_timestamp_t;
    num_keys:         u8;
    num_buttons:      u8;
    num_valuators:    u8;
    classes_reported: u8;
    buttons:          [4] u8;
    keys:             [4] u8;
    valuators:        [3] u32;
}

xcb_input_device_mapping_notify_event_t :: struct {
    response_type: u8;
    device_id:     u8;
    sequence:      u16;
    request:       u8;
    first_keycode: xcb_input_key_code_t;
    count:         u8;
    pad0:          u8;
    time:          xcb_timestamp_t;
    pad1:          [20] u8;
}

xcb_input_change_device_t :: enum u32 {
    POINTER  :: 0;
    KEYBOARD :: 1;

    XCB_INPUT_CHANGE_DEVICE_NEW_POINTER  :: POINTER;
    XCB_INPUT_CHANGE_DEVICE_NEW_KEYBOARD :: KEYBOARD;
}

xcb_input_change_device_notify_event_t :: struct {
    response_type: u8;
    device_id:     u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    request:       u8;
    pad0:          [23] u8;
}

xcb_input_device_key_state_notify_event_t :: struct {
    response_type: u8;
    device_id:     u8;
    sequence:      u16;
    keys:          [28] u8;
}

xcb_input_device_button_state_notify_event_t :: struct {
    response_type: u8;
    device_id:     u8;
    sequence:      u16;
    buttons:       [28] u8;
}

xcb_input_device_change_t :: enum u32 {
    ADDED           :: 0;
    REMOVED         :: 1;
    ENABLED         :: 2;
    DISABLED        :: 3;
    UNRECOVERABLE   :: 4;
    CONTROL_CHANGED :: 5;

    XCB_INPUT_DEVICE_CHANGE_ADDED           :: ADDED;
    XCB_INPUT_DEVICE_CHANGE_REMOVED         :: REMOVED;
    XCB_INPUT_DEVICE_CHANGE_ENABLED         :: ENABLED;
    XCB_INPUT_DEVICE_CHANGE_DISABLED        :: DISABLED;
    XCB_INPUT_DEVICE_CHANGE_UNRECOVERABLE   :: UNRECOVERABLE;
    XCB_INPUT_DEVICE_CHANGE_CONTROL_CHANGED :: CONTROL_CHANGED;
}

xcb_input_device_presence_notify_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    devchange:     u8;
    device_id:     u8;
    control:       u16;
    pad1:          [20] u8;
}

xcb_input_device_property_notify_event_t :: struct {
    response_type: u8;
    state:         u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    property:      xcb_atom_t;
    pad0:          [19] u8;
    device_id:     u8;
}

xcb_input_change_reason_t :: enum u32 {
    SLAVE_SWITCH  :: 1;
    DEVICE_CHANGE :: 2;

    XCB_INPUT_CHANGE_REASON_SLAVE_SWITCH  :: SLAVE_SWITCH;
    XCB_INPUT_CHANGE_REASON_DEVICE_CHANGE :: DEVICE_CHANGE;
}

xcb_input_device_changed_event_t :: struct {
    response_type: u8;
    extension:     u8;
    sequence:      u16;
    length:        u32;
    event_type:    u16;
    deviceid:      xcb_input_device_id_t;
    time:          xcb_timestamp_t;
    num_classes:   u16;
    sourceid:      xcb_input_device_id_t;
    reason:        u8;
    pad0:          [11] u8;
    full_sequence: u32;
}

xcb_input_key_event_flags_t :: enum u32 {
    XCB_INPUT_KEY_EVENT_FLAGS_KEY_REPEAT :: 65536;
}

xcb_input_key_press_event_t :: struct {
    response_type: u8;
    extension:     u8;
    sequence:      u16;
    length:        u32;
    event_type:    u16;
    deviceid:      xcb_input_device_id_t;
    time:          xcb_timestamp_t;
    detail:        u32;
    root:          xcb_window_t;
    event:         xcb_window_t;
    child:         xcb_window_t;
    full_sequence: u32;
    root_x:        xcb_input_fp1616_t;
    root_y:        xcb_input_fp1616_t;
    event_x:       xcb_input_fp1616_t;
    event_y:       xcb_input_fp1616_t;
    buttons_len:   u16;
    valuators_len: u16;
    sourceid:      xcb_input_device_id_t;
    pad0:          [2] u8;
    flags:         u32;
    mods:          xcb_input_modifier_info_t;
    group:         xcb_input_group_info_t;
}

xcb_input_key_release_event_t :: xcb_input_key_press_event_t;

xcb_input_pointer_event_flags_t :: enum u32 {
    XCB_INPUT_POINTER_EVENT_FLAGS_POINTER_EMULATED :: 65536;
}

xcb_input_button_press_event_t :: struct {
    response_type: u8;
    extension:     u8;
    sequence:      u16;
    length:        u32;
    event_type:    u16;
    deviceid:      xcb_input_device_id_t;
    time:          xcb_timestamp_t;
    detail:        u32;
    root:          xcb_window_t;
    event:         xcb_window_t;
    child:         xcb_window_t;
    full_sequence: u32;
    root_x:        xcb_input_fp1616_t;
    root_y:        xcb_input_fp1616_t;
    event_x:       xcb_input_fp1616_t;
    event_y:       xcb_input_fp1616_t;
    buttons_len:   u16;
    valuators_len: u16;
    sourceid:      xcb_input_device_id_t;
    pad0:          [2] u8;
    flags:         u32;
    mods:          xcb_input_modifier_info_t;
    group:         xcb_input_group_info_t;
}

xcb_input_button_release_event_t :: xcb_input_button_press_event_t;

xcb_input_motion_event_t :: xcb_input_button_press_event_t;

xcb_input_notify_mode_t :: enum u32 {
    NORMAL         :: 0;
    GRAB           :: 1;
    UNGRAB         :: 2;
    WHILE_GRABBED  :: 3;
    PASSIVE_GRAB   :: 4;
    PASSIVE_UNGRAB :: 5;

    XCB_INPUT_NOTIFY_MODE_NORMAL         :: NORMAL;
    XCB_INPUT_NOTIFY_MODE_GRAB           :: GRAB;
    XCB_INPUT_NOTIFY_MODE_UNGRAB         :: UNGRAB;
    XCB_INPUT_NOTIFY_MODE_WHILE_GRABBED  :: WHILE_GRABBED;
    XCB_INPUT_NOTIFY_MODE_PASSIVE_GRAB   :: PASSIVE_GRAB;
    XCB_INPUT_NOTIFY_MODE_PASSIVE_UNGRAB :: PASSIVE_UNGRAB;
}

xcb_input_notify_detail_t :: enum u32 {
    ANCESTOR          :: 0;
    VIRTUAL           :: 1;
    INFERIOR          :: 2;
    NONLINEAR         :: 3;
    NONLINEAR_VIRTUAL :: 4;
    POINTER           :: 5;
    POINTER_ROOT      :: 6;
    NONE              :: 7;

    XCB_INPUT_NOTIFY_DETAIL_ANCESTOR          :: ANCESTOR;
    XCB_INPUT_NOTIFY_DETAIL_VIRTUAL           :: VIRTUAL;
    XCB_INPUT_NOTIFY_DETAIL_INFERIOR          :: INFERIOR;
    XCB_INPUT_NOTIFY_DETAIL_NONLINEAR         :: NONLINEAR;
    XCB_INPUT_NOTIFY_DETAIL_NONLINEAR_VIRTUAL :: NONLINEAR_VIRTUAL;
    XCB_INPUT_NOTIFY_DETAIL_POINTER           :: POINTER;
    XCB_INPUT_NOTIFY_DETAIL_POINTER_ROOT      :: POINTER_ROOT;
    XCB_INPUT_NOTIFY_DETAIL_NONE              :: NONE;
}

xcb_input_enter_event_t :: struct {
    response_type: u8;
    extension:     u8;
    sequence:      u16;
    length:        u32;
    event_type:    u16;
    deviceid:      xcb_input_device_id_t;
    time:          xcb_timestamp_t;
    sourceid:      xcb_input_device_id_t;
    mode:          u8;
    detail:        u8;
    root:          xcb_window_t;
    event:         xcb_window_t;
    child:         xcb_window_t;
    full_sequence: u32;
    root_x:        xcb_input_fp1616_t;
    root_y:        xcb_input_fp1616_t;
    event_x:       xcb_input_fp1616_t;
    event_y:       xcb_input_fp1616_t;
    same_screen:   u8;
    focus:         u8;
    buttons_len:   u16;
    mods:          xcb_input_modifier_info_t;
    group:         xcb_input_group_info_t;
}

xcb_input_leave_event_t :: xcb_input_enter_event_t;

xcb_input_focus_in_event_t :: xcb_input_enter_event_t;

xcb_input_focus_out_event_t :: xcb_input_enter_event_t;

xcb_input_hierarchy_mask_t :: enum u32 {
    MASTER_ADDED    :: 1;
    MASTER_REMOVED  :: 2;
    SLAVE_ADDED     :: 4;
    SLAVE_REMOVED   :: 8;
    SLAVE_ATTACHED  :: 16;
    SLAVE_DETACHED  :: 32;
    DEVICE_ENABLED  :: 64;
    DEVICE_DISABLED :: 128;

    XCB_INPUT_HIERARCHY_MASK_MASTER_ADDED    :: MASTER_ADDED;
    XCB_INPUT_HIERARCHY_MASK_MASTER_REMOVED  :: MASTER_REMOVED;
    XCB_INPUT_HIERARCHY_MASK_SLAVE_ADDED     :: SLAVE_ADDED;
    XCB_INPUT_HIERARCHY_MASK_SLAVE_REMOVED   :: SLAVE_REMOVED;
    XCB_INPUT_HIERARCHY_MASK_SLAVE_ATTACHED  :: SLAVE_ATTACHED;
    XCB_INPUT_HIERARCHY_MASK_SLAVE_DETACHED  :: SLAVE_DETACHED;
    XCB_INPUT_HIERARCHY_MASK_DEVICE_ENABLED  :: DEVICE_ENABLED;
    XCB_INPUT_HIERARCHY_MASK_DEVICE_DISABLED :: DEVICE_DISABLED;
}

xcb_input_hierarchy_info_t :: struct {
    deviceid:   xcb_input_device_id_t;
    attachment: xcb_input_device_id_t;
    type:       u8;
    enabled:    u8;
    pad0:       [2] u8;
    flags:      u32;
}

xcb_input_hierarchy_info_iterator_t :: struct {
    data:  *xcb_input_hierarchy_info_t;
    rem:   s32;
    index: s32;
}

xcb_input_hierarchy_event_t :: struct {
    response_type: u8;
    extension:     u8;
    sequence:      u16;
    length:        u32;
    event_type:    u16;
    deviceid:      xcb_input_device_id_t;
    time:          xcb_timestamp_t;
    flags:         u32;
    num_infos:     u16;
    pad0:          [10] u8;
    full_sequence: u32;
}

xcb_input_property_flag_t :: enum u32 {
    DELETED  :: 0;
    CREATED  :: 1;
    MODIFIED :: 2;

    XCB_INPUT_PROPERTY_FLAG_DELETED  :: DELETED;
    XCB_INPUT_PROPERTY_FLAG_CREATED  :: CREATED;
    XCB_INPUT_PROPERTY_FLAG_MODIFIED :: MODIFIED;
}

xcb_input_property_event_t :: struct {
    response_type: u8;
    extension:     u8;
    sequence:      u16;
    length:        u32;
    event_type:    u16;
    deviceid:      xcb_input_device_id_t;
    time:          xcb_timestamp_t;
    property:      xcb_atom_t;
    what:          u8;
    pad0:          [11] u8;
    full_sequence: u32;
}

xcb_input_raw_key_press_event_t :: struct {
    response_type: u8;
    extension:     u8;
    sequence:      u16;
    length:        u32;
    event_type:    u16;
    deviceid:      xcb_input_device_id_t;
    time:          xcb_timestamp_t;
    detail:        u32;
    sourceid:      xcb_input_device_id_t;
    valuators_len: u16;
    flags:         u32;
    pad0:          [4] u8;
    full_sequence: u32;
}

xcb_input_raw_key_release_event_t :: xcb_input_raw_key_press_event_t;

xcb_input_raw_button_press_event_t :: struct {
    response_type: u8;
    extension:     u8;
    sequence:      u16;
    length:        u32;
    event_type:    u16;
    deviceid:      xcb_input_device_id_t;
    time:          xcb_timestamp_t;
    detail:        u32;
    sourceid:      xcb_input_device_id_t;
    valuators_len: u16;
    flags:         u32;
    pad0:          [4] u8;
    full_sequence: u32;
}

xcb_input_raw_button_release_event_t :: xcb_input_raw_button_press_event_t;

xcb_input_raw_motion_event_t :: xcb_input_raw_button_press_event_t;

xcb_input_touch_event_flags_t :: enum u32 {
    PENDING_END       :: 65536;
    EMULATING_POINTER :: 131072;

    XCB_INPUT_TOUCH_EVENT_FLAGS_TOUCH_PENDING_END       :: PENDING_END;
    XCB_INPUT_TOUCH_EVENT_FLAGS_TOUCH_EMULATING_POINTER :: EMULATING_POINTER;
}

xcb_input_touch_begin_event_t :: struct {
    response_type: u8;
    extension:     u8;
    sequence:      u16;
    length:        u32;
    event_type:    u16;
    deviceid:      xcb_input_device_id_t;
    time:          xcb_timestamp_t;
    detail:        u32;
    root:          xcb_window_t;
    event:         xcb_window_t;
    child:         xcb_window_t;
    full_sequence: u32;
    root_x:        xcb_input_fp1616_t;
    root_y:        xcb_input_fp1616_t;
    event_x:       xcb_input_fp1616_t;
    event_y:       xcb_input_fp1616_t;
    buttons_len:   u16;
    valuators_len: u16;
    sourceid:      xcb_input_device_id_t;
    pad0:          [2] u8;
    flags:         u32;
    mods:          xcb_input_modifier_info_t;
    group:         xcb_input_group_info_t;
}

xcb_input_touch_update_event_t :: xcb_input_touch_begin_event_t;

xcb_input_touch_end_event_t :: xcb_input_touch_begin_event_t;

xcb_input_touch_ownership_flags_t :: enum u32 {
    XCB_INPUT_TOUCH_OWNERSHIP_FLAGS_NONE :: 0;
}

xcb_input_touch_ownership_event_t :: struct {
    response_type: u8;
    extension:     u8;
    sequence:      u16;
    length:        u32;
    event_type:    u16;
    deviceid:      xcb_input_device_id_t;
    time:          xcb_timestamp_t;
    touchid:       u32;
    root:          xcb_window_t;
    event:         xcb_window_t;
    child:         xcb_window_t;
    full_sequence: u32;
    sourceid:      xcb_input_device_id_t;
    pad0:          [2] u8;
    flags:         u32;
    pad1:          [8] u8;
}

xcb_input_raw_touch_begin_event_t :: struct {
    response_type: u8;
    extension:     u8;
    sequence:      u16;
    length:        u32;
    event_type:    u16;
    deviceid:      xcb_input_device_id_t;
    time:          xcb_timestamp_t;
    detail:        u32;
    sourceid:      xcb_input_device_id_t;
    valuators_len: u16;
    flags:         u32;
    pad0:          [4] u8;
    full_sequence: u32;
}

xcb_input_raw_touch_update_event_t :: xcb_input_raw_touch_begin_event_t;

xcb_input_raw_touch_end_event_t :: xcb_input_raw_touch_begin_event_t;

xcb_input_barrier_flags_t :: enum u32 {
    POINTER_RELEASED  :: 1;
    DEVICE_IS_GRABBED :: 2;

    XCB_INPUT_BARRIER_FLAGS_POINTER_RELEASED  :: POINTER_RELEASED;
    XCB_INPUT_BARRIER_FLAGS_DEVICE_IS_GRABBED :: DEVICE_IS_GRABBED;
}

xcb_input_barrier_hit_event_t :: struct {
    response_type: u8;
    extension:     u8;
    sequence:      u16;
    length:        u32;
    event_type:    u16;
    deviceid:      xcb_input_device_id_t;
    time:          xcb_timestamp_t;
    eventid:       u32;
    root:          xcb_window_t;
    event:         xcb_window_t;
    barrier:       xcb_xfixes_barrier_t;
    full_sequence: u32;
    dtime:         u32;
    flags:         u32;
    sourceid:      xcb_input_device_id_t;
    pad0:          [2] u8;
    root_x:        xcb_input_fp1616_t;
    root_y:        xcb_input_fp1616_t;
    dx:            xcb_input_fp3232_t;
    dy:            xcb_input_fp3232_t;
}

xcb_input_barrier_leave_event_t :: xcb_input_barrier_hit_event_t;

xcb_input_gesture_pinch_event_flags_t :: enum u32 {
    XCB_INPUT_GESTURE_PINCH_EVENT_FLAGS_GESTURE_PINCH_CANCELLED :: 1;
}

xcb_input_gesture_pinch_begin_event_t :: struct {
    response_type:   u8;
    extension:       u8;
    sequence:        u16;
    length:          u32;
    event_type:      u16;
    deviceid:        xcb_input_device_id_t;
    time:            xcb_timestamp_t;
    detail:          u32;
    root:            xcb_window_t;
    event:           xcb_window_t;
    child:           xcb_window_t;
    full_sequence:   u32;
    root_x:          xcb_input_fp1616_t;
    root_y:          xcb_input_fp1616_t;
    event_x:         xcb_input_fp1616_t;
    event_y:         xcb_input_fp1616_t;
    delta_x:         xcb_input_fp1616_t;
    delta_y:         xcb_input_fp1616_t;
    delta_unaccel_x: xcb_input_fp1616_t;
    delta_unaccel_y: xcb_input_fp1616_t;
    scale:           xcb_input_fp1616_t;
    delta_angle:     xcb_input_fp1616_t;
    sourceid:        xcb_input_device_id_t;
    pad0:            [2] u8;
    mods:            xcb_input_modifier_info_t;
    group:           xcb_input_group_info_t;
    flags:           u32;
}

xcb_input_gesture_pinch_update_event_t :: xcb_input_gesture_pinch_begin_event_t;

xcb_input_gesture_pinch_end_event_t :: xcb_input_gesture_pinch_begin_event_t;

xcb_input_gesture_swipe_event_flags_t :: enum u32 {
    XCB_INPUT_GESTURE_SWIPE_EVENT_FLAGS_GESTURE_SWIPE_CANCELLED :: 1;
}

xcb_input_gesture_swipe_begin_event_t :: struct {
    response_type:   u8;
    extension:       u8;
    sequence:        u16;
    length:          u32;
    event_type:      u16;
    deviceid:        xcb_input_device_id_t;
    time:            xcb_timestamp_t;
    detail:          u32;
    root:            xcb_window_t;
    event:           xcb_window_t;
    child:           xcb_window_t;
    full_sequence:   u32;
    root_x:          xcb_input_fp1616_t;
    root_y:          xcb_input_fp1616_t;
    event_x:         xcb_input_fp1616_t;
    event_y:         xcb_input_fp1616_t;
    delta_x:         xcb_input_fp1616_t;
    delta_y:         xcb_input_fp1616_t;
    delta_unaccel_x: xcb_input_fp1616_t;
    delta_unaccel_y: xcb_input_fp1616_t;
    sourceid:        xcb_input_device_id_t;
    pad0:            [2] u8;
    mods:            xcb_input_modifier_info_t;
    group:           xcb_input_group_info_t;
    flags:           u32;
}

xcb_input_gesture_swipe_update_event_t :: xcb_input_gesture_swipe_begin_event_t;

xcb_input_gesture_swipe_end_event_t :: xcb_input_gesture_swipe_begin_event_t;

xcb_input_event_for_send_t :: union {
    device_valuator:            xcb_input_device_valuator_event_t;
    device_key_press:           xcb_input_device_key_press_event_t;
    device_key_release:         xcb_input_device_key_release_event_t;
    device_button_press:        xcb_input_device_button_press_event_t;
    device_button_release:      xcb_input_device_button_release_event_t;
    device_motion_notify:       xcb_input_device_motion_notify_event_t;
    device_focus_in:            xcb_input_device_focus_in_event_t;
    device_focus_out:           xcb_input_device_focus_out_event_t;
    proximity_in:               xcb_input_proximity_in_event_t;
    proximity_out:              xcb_input_proximity_out_event_t;
    device_state_notify:        xcb_input_device_state_notify_event_t;
    device_mapping_notify:      xcb_input_device_mapping_notify_event_t;
    change_device_notify:       xcb_input_change_device_notify_event_t;
    device_key_state_notify:    xcb_input_device_key_state_notify_event_t;
    device_button_state_notify: xcb_input_device_button_state_notify_event_t;
    device_presence_notify:     xcb_input_device_presence_notify_event_t;
    event_header:               xcb_raw_generic_event_t;
}

xcb_input_event_for_send_iterator_t :: struct {
    data:  *xcb_input_event_for_send_t;
    rem:   s32;
    index: s32;
}

xcb_input_send_extension_event_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    destination:  xcb_window_t;
    device_id:    u8;
    propagate:    u8;
    num_classes:  u16;
    num_events:   u8;
    pad0:         [3] u8;
}

xcb_input_device_error_t :: struct {
    response_type: u8;
    error_code:    u8;
    sequence:      u16;
    bad_value:     u32;
    minor_opcode:  u16;
    major_opcode:  u8;
}

xcb_input_event_error_t :: struct {
    response_type: u8;
    error_code:    u8;
    sequence:      u16;
    bad_value:     u32;
    minor_opcode:  u16;
    major_opcode:  u8;
}

xcb_input_mode_error_t :: struct {
    response_type: u8;
    error_code:    u8;
    sequence:      u16;
    bad_value:     u32;
    minor_opcode:  u16;
    major_opcode:  u8;
}

xcb_input_device_busy_error_t :: struct {
    response_type: u8;
    error_code:    u8;
    sequence:      u16;
    bad_value:     u32;
    minor_opcode:  u16;
    major_opcode:  u8;
}

xcb_input_class_error_t :: struct {
    response_type: u8;
    error_code:    u8;
    sequence:      u16;
    bad_value:     u32;
    minor_opcode:  u16;
    major_opcode:  u8;
}

XCB_XInput_Symbols :: struct #type_info_procedures_are_void_pointers #type_info_no_size_complaint {
    id:                                                    *xcb_extension_t;
    input_info_info:                                       #type (R: *xcb_input_input_info_t) -> *void #c_call;
    feedback_state_data:                                   #type (R: *xcb_input_feedback_state_t) -> *void #c_call;
    feedback_ctl_data:                                     #type (R: *xcb_input_feedback_ctl_t) -> *void #c_call;
    input_state_data:                                      #type (R: *xcb_input_input_state_t) -> *void #c_call;
    device_state_data:                                     #type (R: *xcb_input_device_state_t) -> *void #c_call;
    device_ctl_data:                                       #type (R: *xcb_input_device_ctl_t) -> *void #c_call;
    hierarchy_change_data:                                 #type (R: *xcb_input_hierarchy_change_t) -> *void #c_call;
    device_class_data:                                     #type (R: *xcb_input_device_class_t) -> *void #c_call;
    event_class_next:                                      #type (i: *xcb_input_event_class_iterator_t) -> void #c_call;
    event_class_end:                                       #type (i: xcb_input_event_class_iterator_t) -> xcb_generic_iterator_t #c_call;
    key_code_next:                                         #type (i: *xcb_input_key_code_iterator_t) -> void #c_call;
    key_code_end:                                          #type (i: xcb_input_key_code_iterator_t) -> xcb_generic_iterator_t #c_call;
    device_id_next:                                        #type (i: *xcb_input_device_id_iterator_t) -> void #c_call;
    device_id_end:                                         #type (i: xcb_input_device_id_iterator_t) -> xcb_generic_iterator_t #c_call;
    fp1616_next:                                           #type (i: *xcb_input_fp1616_iterator_t) -> void #c_call;
    fp1616_end:                                            #type (i: xcb_input_fp1616_iterator_t) -> xcb_generic_iterator_t #c_call;
    fp3232_next:                                           #type (i: *xcb_input_fp3232_iterator_t) -> void #c_call;
    fp3232_end:                                            #type (i: xcb_input_fp3232_iterator_t) -> xcb_generic_iterator_t #c_call;
    get_extension_version_sizeof:                          #type (_buffer: *void) -> s32 #c_call;
    get_extension_version:                                 #type (c: *xcb_connection_t, name_len: u16, name: *u8) -> xcb_input_get_extension_version_cookie_t #c_call;
    get_extension_version_unchecked:                       #type (c: *xcb_connection_t, name_len: u16, name: *u8) -> xcb_input_get_extension_version_cookie_t #c_call;
    get_extension_version_reply:                           #type (c: *xcb_connection_t, cookie: xcb_input_get_extension_version_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_get_extension_version_reply_t #c_call;
    device_info_next:                                      #type (i: *xcb_input_device_info_iterator_t) -> void #c_call;
    device_info_end:                                       #type (i: xcb_input_device_info_iterator_t) -> xcb_generic_iterator_t #c_call;
    key_info_next:                                         #type (i: *xcb_input_key_info_iterator_t) -> void #c_call;
    key_info_end:                                          #type (i: xcb_input_key_info_iterator_t) -> xcb_generic_iterator_t #c_call;
    button_info_next:                                      #type (i: *xcb_input_button_info_iterator_t) -> void #c_call;
    button_info_end:                                       #type (i: xcb_input_button_info_iterator_t) -> xcb_generic_iterator_t #c_call;
    axis_info_next:                                        #type (i: *xcb_input_axis_info_iterator_t) -> void #c_call;
    axis_info_end:                                         #type (i: xcb_input_axis_info_iterator_t) -> xcb_generic_iterator_t #c_call;
    valuator_info_sizeof:                                  #type (_buffer: *void) -> s32 #c_call;
    valuator_info_axes:                                    #type (R: *xcb_input_valuator_info_t) -> *xcb_input_axis_info_t #c_call;
    valuator_info_axes_length:                             #type (R: *xcb_input_valuator_info_t) -> s32 #c_call;
    valuator_info_axes_iterator:                           #type (R: *xcb_input_valuator_info_t) -> xcb_input_axis_info_iterator_t #c_call;
    valuator_info_next:                                    #type (i: *xcb_input_valuator_info_iterator_t) -> void #c_call;
    valuator_info_end:                                     #type (i: xcb_input_valuator_info_iterator_t) -> xcb_generic_iterator_t #c_call;
    input_info_info_valuator_axes:                         #type (S: *xcb_input_input_info_info_t) -> *xcb_input_axis_info_t #c_call;
    input_info_info_valuator_axes_length:                  #type (R: *xcb_input_input_info_t, S: *xcb_input_input_info_info_t) -> s32 #c_call;
    input_info_info_valuator_axes_iterator:                #type (R: *xcb_input_input_info_t, S: *xcb_input_input_info_info_t) -> xcb_input_axis_info_iterator_t #c_call;
    input_info_info_serialize:                             #type (_buffer: **void, class_id: u8, _aux: *xcb_input_input_info_info_t) -> s32 #c_call;
    input_info_info_unpack:                                #type (_buffer: *void, class_id: u8, _aux: *xcb_input_input_info_info_t) -> s32 #c_call;
    input_info_info_sizeof:                                #type (_buffer: *void, class_id: u8) -> s32 #c_call;
    input_info_sizeof:                                     #type (_buffer: *void) -> s32 #c_call;
    input_info_next:                                       #type (i: *xcb_input_input_info_iterator_t) -> void #c_call;
    input_info_end:                                        #type (i: xcb_input_input_info_iterator_t) -> xcb_generic_iterator_t #c_call;
    device_name_sizeof:                                    #type (_buffer: *void) -> s32 #c_call;
    device_name_string:                                    #type (R: *xcb_input_device_name_t) -> *u8 #c_call;
    device_name_string_length:                             #type (R: *xcb_input_device_name_t) -> s32 #c_call;
    device_name_string_end:                                #type (R: *xcb_input_device_name_t) -> xcb_generic_iterator_t #c_call;
    device_name_next:                                      #type (i: *xcb_input_device_name_iterator_t) -> void #c_call;
    device_name_end:                                       #type (i: xcb_input_device_name_iterator_t) -> xcb_generic_iterator_t #c_call;
    list_input_devices_sizeof:                             #type (_buffer: *void) -> s32 #c_call;
    list_input_devices:                                    #type (c: *xcb_connection_t) -> xcb_input_list_input_devices_cookie_t #c_call;
    list_input_devices_unchecked:                          #type (c: *xcb_connection_t) -> xcb_input_list_input_devices_cookie_t #c_call;
    list_input_devices_devices:                            #type (R: *xcb_input_list_input_devices_reply_t) -> *xcb_input_device_info_t #c_call;
    list_input_devices_devices_length:                     #type (R: *xcb_input_list_input_devices_reply_t) -> s32 #c_call;
    list_input_devices_devices_iterator:                   #type (R: *xcb_input_list_input_devices_reply_t) -> xcb_input_device_info_iterator_t #c_call;
    list_input_devices_infos_length:                       #type (R: *xcb_input_list_input_devices_reply_t) -> s32 #c_call;
    list_input_devices_infos_iterator:                     #type (R: *xcb_input_list_input_devices_reply_t) -> xcb_input_input_info_iterator_t #c_call;
    list_input_devices_names_length:                       #type (R: *xcb_input_list_input_devices_reply_t) -> s32 #c_call;
    list_input_devices_names_iterator:                     #type (R: *xcb_input_list_input_devices_reply_t) -> xcb_str_iterator_t #c_call;
    list_input_devices_reply:                              #type (c: *xcb_connection_t, cookie: xcb_input_list_input_devices_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_list_input_devices_reply_t #c_call;
    event_type_base_next:                                  #type (i: *xcb_input_event_type_base_iterator_t) -> void #c_call;
    event_type_base_end:                                   #type (i: xcb_input_event_type_base_iterator_t) -> xcb_generic_iterator_t #c_call;
    input_class_info_next:                                 #type (i: *xcb_input_input_class_info_iterator_t) -> void #c_call;
    input_class_info_end:                                  #type (i: xcb_input_input_class_info_iterator_t) -> xcb_generic_iterator_t #c_call;
    open_device_sizeof:                                    #type (_buffer: *void) -> s32 #c_call;
    open_device:                                           #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_open_device_cookie_t #c_call;
    open_device_unchecked:                                 #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_open_device_cookie_t #c_call;
    open_device_class_info:                                #type (R: *xcb_input_open_device_reply_t) -> *xcb_input_input_class_info_t #c_call;
    open_device_class_info_length:                         #type (R: *xcb_input_open_device_reply_t) -> s32 #c_call;
    open_device_class_info_iterator:                       #type (R: *xcb_input_open_device_reply_t) -> xcb_input_input_class_info_iterator_t #c_call;
    open_device_reply:                                     #type (c: *xcb_connection_t, cookie: xcb_input_open_device_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_open_device_reply_t #c_call;
    close_device_checked:                                  #type (c: *xcb_connection_t, device_id: u8) -> xcb_void_cookie_t #c_call;
    close_device:                                          #type (c: *xcb_connection_t, device_id: u8) -> xcb_void_cookie_t #c_call;
    set_device_mode:                                       #type (c: *xcb_connection_t, device_id: u8, mode: u8) -> xcb_input_set_device_mode_cookie_t #c_call;
    set_device_mode_unchecked:                             #type (c: *xcb_connection_t, device_id: u8, mode: u8) -> xcb_input_set_device_mode_cookie_t #c_call;
    set_device_mode_reply:                                 #type (c: *xcb_connection_t, cookie: xcb_input_set_device_mode_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_set_device_mode_reply_t #c_call;
    select_extension_event_sizeof:                         #type (_buffer: *void) -> s32 #c_call;
    select_extension_event_checked:                        #type (c: *xcb_connection_t, window: xcb_window_t, num_classes: u16, classes: *xcb_input_event_class_t) -> xcb_void_cookie_t #c_call;
    select_extension_event:                                #type (c: *xcb_connection_t, window: xcb_window_t, num_classes: u16, classes: *xcb_input_event_class_t) -> xcb_void_cookie_t #c_call;
    select_extension_event_classes:                        #type (R: *xcb_input_select_extension_event_request_t) -> *xcb_input_event_class_t #c_call;
    select_extension_event_classes_length:                 #type (R: *xcb_input_select_extension_event_request_t) -> s32 #c_call;
    select_extension_event_classes_end:                    #type (R: *xcb_input_select_extension_event_request_t) -> xcb_generic_iterator_t #c_call;
    get_selected_extension_events_sizeof:                  #type (_buffer: *void) -> s32 #c_call;
    get_selected_extension_events:                         #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_input_get_selected_extension_events_cookie_t #c_call;
    get_selected_extension_events_unchecked:               #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_input_get_selected_extension_events_cookie_t #c_call;
    get_selected_extension_events_this_classes:            #type (R: *xcb_input_get_selected_extension_events_reply_t) -> *xcb_input_event_class_t #c_call;
    get_selected_extension_events_this_classes_length:     #type (R: *xcb_input_get_selected_extension_events_reply_t) -> s32 #c_call;
    get_selected_extension_events_this_classes_end:        #type (R: *xcb_input_get_selected_extension_events_reply_t) -> xcb_generic_iterator_t #c_call;
    get_selected_extension_events_all_classes:             #type (R: *xcb_input_get_selected_extension_events_reply_t) -> *xcb_input_event_class_t #c_call;
    get_selected_extension_events_all_classes_length:      #type (R: *xcb_input_get_selected_extension_events_reply_t) -> s32 #c_call;
    get_selected_extension_events_all_classes_end:         #type (R: *xcb_input_get_selected_extension_events_reply_t) -> xcb_generic_iterator_t #c_call;
    get_selected_extension_events_reply:                   #type (c: *xcb_connection_t, cookie: xcb_input_get_selected_extension_events_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_get_selected_extension_events_reply_t #c_call;
    change_device_dont_propagate_list_sizeof:              #type (_buffer: *void) -> s32 #c_call;
    change_device_dont_propagate_list_checked:             #type (c: *xcb_connection_t, window: xcb_window_t, num_classes: u16, mode: u8, classes: *xcb_input_event_class_t) -> xcb_void_cookie_t #c_call;
    change_device_dont_propagate_list:                     #type (c: *xcb_connection_t, window: xcb_window_t, num_classes: u16, mode: u8, classes: *xcb_input_event_class_t) -> xcb_void_cookie_t #c_call;
    change_device_dont_propagate_list_classes:             #type (R: *xcb_input_change_device_dont_propagate_list_request_t) -> *xcb_input_event_class_t #c_call;
    change_device_dont_propagate_list_classes_length:      #type (R: *xcb_input_change_device_dont_propagate_list_request_t) -> s32 #c_call;
    change_device_dont_propagate_list_classes_end:         #type (R: *xcb_input_change_device_dont_propagate_list_request_t) -> xcb_generic_iterator_t #c_call;
    get_device_dont_propagate_list_sizeof:                 #type (_buffer: *void) -> s32 #c_call;
    get_device_dont_propagate_list:                        #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_input_get_device_dont_propagate_list_cookie_t #c_call;
    get_device_dont_propagate_list_unchecked:              #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_input_get_device_dont_propagate_list_cookie_t #c_call;
    get_device_dont_propagate_list_classes:                #type (R: *xcb_input_get_device_dont_propagate_list_reply_t) -> *xcb_input_event_class_t #c_call;
    get_device_dont_propagate_list_classes_length:         #type (R: *xcb_input_get_device_dont_propagate_list_reply_t) -> s32 #c_call;
    get_device_dont_propagate_list_classes_end:            #type (R: *xcb_input_get_device_dont_propagate_list_reply_t) -> xcb_generic_iterator_t #c_call;
    get_device_dont_propagate_list_reply:                  #type (c: *xcb_connection_t, cookie: xcb_input_get_device_dont_propagate_list_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_get_device_dont_propagate_list_reply_t #c_call;
    device_time_coord_sizeof:                              #type (_buffer: *void, num_axes: u8) -> s32 #c_call;
    device_time_coord_axisvalues:                          #type (R: *xcb_input_device_time_coord_t) -> *s32 #c_call;
    device_time_coord_axisvalues_length:                   #type (R: *xcb_input_device_time_coord_t, num_axes: u8) -> s32 #c_call;
    device_time_coord_axisvalues_end:                      #type (R: *xcb_input_device_time_coord_t, num_axes: u8) -> xcb_generic_iterator_t #c_call;
    device_time_coord_next:                                #type (i: *xcb_input_device_time_coord_iterator_t) -> void #c_call;
    device_time_coord_end:                                 #type (i: xcb_input_device_time_coord_iterator_t) -> xcb_generic_iterator_t #c_call;
    get_device_motion_events_sizeof:                       #type (_buffer: *void) -> s32 #c_call;
    get_device_motion_events:                              #type (c: *xcb_connection_t, start: xcb_timestamp_t, stop: xcb_timestamp_t, device_id: u8) -> xcb_input_get_device_motion_events_cookie_t #c_call;
    get_device_motion_events_unchecked:                    #type (c: *xcb_connection_t, start: xcb_timestamp_t, stop: xcb_timestamp_t, device_id: u8) -> xcb_input_get_device_motion_events_cookie_t #c_call;
    get_device_motion_events_events_length:                #type (R: *xcb_input_get_device_motion_events_reply_t) -> s32 #c_call;
    get_device_motion_events_events_iterator:              #type (R: *xcb_input_get_device_motion_events_reply_t) -> xcb_input_device_time_coord_iterator_t #c_call;
    get_device_motion_events_reply:                        #type (c: *xcb_connection_t, cookie: xcb_input_get_device_motion_events_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_get_device_motion_events_reply_t #c_call;
    change_keyboard_device:                                #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_change_keyboard_device_cookie_t #c_call;
    change_keyboard_device_unchecked:                      #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_change_keyboard_device_cookie_t #c_call;
    change_keyboard_device_reply:                          #type (c: *xcb_connection_t, cookie: xcb_input_change_keyboard_device_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_change_keyboard_device_reply_t #c_call;
    change_pointer_device:                                 #type (c: *xcb_connection_t, x_axis: u8, y_axis: u8, device_id: u8) -> xcb_input_change_pointer_device_cookie_t #c_call;
    change_pointer_device_unchecked:                       #type (c: *xcb_connection_t, x_axis: u8, y_axis: u8, device_id: u8) -> xcb_input_change_pointer_device_cookie_t #c_call;
    change_pointer_device_reply:                           #type (c: *xcb_connection_t, cookie: xcb_input_change_pointer_device_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_change_pointer_device_reply_t #c_call;
    grab_device_sizeof:                                    #type (_buffer: *void) -> s32 #c_call;
    grab_device:                                           #type (c: *xcb_connection_t, grab_window: xcb_window_t, time: xcb_timestamp_t, num_classes: u16, this_device_mode: u8, other_device_mode: u8, owner_events: u8, device_id: u8, classes: *xcb_input_event_class_t) -> xcb_input_grab_device_cookie_t #c_call;
    grab_device_unchecked:                                 #type (c: *xcb_connection_t, grab_window: xcb_window_t, time: xcb_timestamp_t, num_classes: u16, this_device_mode: u8, other_device_mode: u8, owner_events: u8, device_id: u8, classes: *xcb_input_event_class_t) -> xcb_input_grab_device_cookie_t #c_call;
    grab_device_reply:                                     #type (c: *xcb_connection_t, cookie: xcb_input_grab_device_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_grab_device_reply_t #c_call;
    ungrab_device_checked:                                 #type (c: *xcb_connection_t, time: xcb_timestamp_t, device_id: u8) -> xcb_void_cookie_t #c_call;
    ungrab_device:                                         #type (c: *xcb_connection_t, time: xcb_timestamp_t, device_id: u8) -> xcb_void_cookie_t #c_call;
    grab_device_key_sizeof:                                #type (_buffer: *void) -> s32 #c_call;
    grab_device_key_checked:                               #type (c: *xcb_connection_t, grab_window: xcb_window_t, num_classes: u16, modifiers: u16, modifier_device: u8, grabbed_device: u8, key: u8, this_device_mode: u8, other_device_mode: u8, owner_events: u8, classes: *xcb_input_event_class_t) -> xcb_void_cookie_t #c_call;
    grab_device_key:                                       #type (c: *xcb_connection_t, grab_window: xcb_window_t, num_classes: u16, modifiers: u16, modifier_device: u8, grabbed_device: u8, key: u8, this_device_mode: u8, other_device_mode: u8, owner_events: u8, classes: *xcb_input_event_class_t) -> xcb_void_cookie_t #c_call;
    grab_device_key_classes:                               #type (R: *xcb_input_grab_device_key_request_t) -> *xcb_input_event_class_t #c_call;
    grab_device_key_classes_length:                        #type (R: *xcb_input_grab_device_key_request_t) -> s32 #c_call;
    grab_device_key_classes_end:                           #type (R: *xcb_input_grab_device_key_request_t) -> xcb_generic_iterator_t #c_call;
    ungrab_device_key_checked:                             #type (c: *xcb_connection_t, grabWindow: xcb_window_t, modifiers: u16, modifier_device: u8, key: u8, grabbed_device: u8) -> xcb_void_cookie_t #c_call;
    ungrab_device_key:                                     #type (c: *xcb_connection_t, grabWindow: xcb_window_t, modifiers: u16, modifier_device: u8, key: u8, grabbed_device: u8) -> xcb_void_cookie_t #c_call;
    grab_device_button_sizeof:                             #type (_buffer: *void) -> s32 #c_call;
    grab_device_button_checked:                            #type (c: *xcb_connection_t, grab_window: xcb_window_t, grabbed_device: u8, modifier_device: u8, num_classes: u16, modifiers: u16, this_device_mode: u8, other_device_mode: u8, button: u8, owner_events: u8, classes: *xcb_input_event_class_t) -> xcb_void_cookie_t #c_call;
    grab_device_button:                                    #type (c: *xcb_connection_t, grab_window: xcb_window_t, grabbed_device: u8, modifier_device: u8, num_classes: u16, modifiers: u16, this_device_mode: u8, other_device_mode: u8, button: u8, owner_events: u8, classes: *xcb_input_event_class_t) -> xcb_void_cookie_t #c_call;
    grab_device_button_classes:                            #type (R: *xcb_input_grab_device_button_request_t) -> *xcb_input_event_class_t #c_call;
    grab_device_button_classes_length:                     #type (R: *xcb_input_grab_device_button_request_t) -> s32 #c_call;
    grab_device_button_classes_end:                        #type (R: *xcb_input_grab_device_button_request_t) -> xcb_generic_iterator_t #c_call;
    ungrab_device_button_checked:                          #type (c: *xcb_connection_t, grab_window: xcb_window_t, modifiers: u16, modifier_device: u8, button: u8, grabbed_device: u8) -> xcb_void_cookie_t #c_call;
    ungrab_device_button:                                  #type (c: *xcb_connection_t, grab_window: xcb_window_t, modifiers: u16, modifier_device: u8, button: u8, grabbed_device: u8) -> xcb_void_cookie_t #c_call;
    allow_device_events_checked:                           #type (c: *xcb_connection_t, time: xcb_timestamp_t, mode: u8, device_id: u8) -> xcb_void_cookie_t #c_call;
    allow_device_events:                                   #type (c: *xcb_connection_t, time: xcb_timestamp_t, mode: u8, device_id: u8) -> xcb_void_cookie_t #c_call;
    get_device_focus:                                      #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_get_device_focus_cookie_t #c_call;
    get_device_focus_unchecked:                            #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_get_device_focus_cookie_t #c_call;
    get_device_focus_reply:                                #type (c: *xcb_connection_t, cookie: xcb_input_get_device_focus_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_get_device_focus_reply_t #c_call;
    set_device_focus_checked:                              #type (c: *xcb_connection_t, focus: xcb_window_t, time: xcb_timestamp_t, revert_to: u8, device_id: u8) -> xcb_void_cookie_t #c_call;
    set_device_focus:                                      #type (c: *xcb_connection_t, focus: xcb_window_t, time: xcb_timestamp_t, revert_to: u8, device_id: u8) -> xcb_void_cookie_t #c_call;
    kbd_feedback_state_next:                               #type (i: *xcb_input_kbd_feedback_state_iterator_t) -> void #c_call;
    kbd_feedback_state_end:                                #type (i: xcb_input_kbd_feedback_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    ptr_feedback_state_next:                               #type (i: *xcb_input_ptr_feedback_state_iterator_t) -> void #c_call;
    ptr_feedback_state_end:                                #type (i: xcb_input_ptr_feedback_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    integer_feedback_state_next:                           #type (i: *xcb_input_integer_feedback_state_iterator_t) -> void #c_call;
    integer_feedback_state_end:                            #type (i: xcb_input_integer_feedback_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    string_feedback_state_sizeof:                          #type (_buffer: *void) -> s32 #c_call;
    string_feedback_state_keysyms:                         #type (R: *xcb_input_string_feedback_state_t) -> *xcb_keysym_t #c_call;
    string_feedback_state_keysyms_length:                  #type (R: *xcb_input_string_feedback_state_t) -> s32 #c_call;
    string_feedback_state_keysyms_end:                     #type (R: *xcb_input_string_feedback_state_t) -> xcb_generic_iterator_t #c_call;
    string_feedback_state_next:                            #type (i: *xcb_input_string_feedback_state_iterator_t) -> void #c_call;
    string_feedback_state_end:                             #type (i: xcb_input_string_feedback_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    bell_feedback_state_next:                              #type (i: *xcb_input_bell_feedback_state_iterator_t) -> void #c_call;
    bell_feedback_state_end:                               #type (i: xcb_input_bell_feedback_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    led_feedback_state_next:                               #type (i: *xcb_input_led_feedback_state_iterator_t) -> void #c_call;
    led_feedback_state_end:                                #type (i: xcb_input_led_feedback_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    feedback_state_data_string_keysyms:                    #type (S: *xcb_input_feedback_state_data_t) -> *xcb_keysym_t #c_call;
    feedback_state_data_string_keysyms_length:             #type (R: *xcb_input_feedback_state_t, S: *xcb_input_feedback_state_data_t) -> s32 #c_call;
    feedback_state_data_string_keysyms_end:                #type (R: *xcb_input_feedback_state_t, S: *xcb_input_feedback_state_data_t) -> xcb_generic_iterator_t #c_call;
    feedback_state_data_serialize:                         #type (_buffer: **void, class_id: u8, _aux: *xcb_input_feedback_state_data_t) -> s32 #c_call;
    feedback_state_data_unpack:                            #type (_buffer: *void, class_id: u8, _aux: *xcb_input_feedback_state_data_t) -> s32 #c_call;
    feedback_state_data_sizeof:                            #type (_buffer: *void, class_id: u8) -> s32 #c_call;
    feedback_state_sizeof:                                 #type (_buffer: *void) -> s32 #c_call;
    feedback_state_next:                                   #type (i: *xcb_input_feedback_state_iterator_t) -> void #c_call;
    feedback_state_end:                                    #type (i: xcb_input_feedback_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    get_feedback_control_sizeof:                           #type (_buffer: *void) -> s32 #c_call;
    get_feedback_control:                                  #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_get_feedback_control_cookie_t #c_call;
    get_feedback_control_unchecked:                        #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_get_feedback_control_cookie_t #c_call;
    get_feedback_control_feedbacks_length:                 #type (R: *xcb_input_get_feedback_control_reply_t) -> s32 #c_call;
    get_feedback_control_feedbacks_iterator:               #type (R: *xcb_input_get_feedback_control_reply_t) -> xcb_input_feedback_state_iterator_t #c_call;
    get_feedback_control_reply:                            #type (c: *xcb_connection_t, cookie: xcb_input_get_feedback_control_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_get_feedback_control_reply_t #c_call;
    kbd_feedback_ctl_next:                                 #type (i: *xcb_input_kbd_feedback_ctl_iterator_t) -> void #c_call;
    kbd_feedback_ctl_end:                                  #type (i: xcb_input_kbd_feedback_ctl_iterator_t) -> xcb_generic_iterator_t #c_call;
    ptr_feedback_ctl_next:                                 #type (i: *xcb_input_ptr_feedback_ctl_iterator_t) -> void #c_call;
    ptr_feedback_ctl_end:                                  #type (i: xcb_input_ptr_feedback_ctl_iterator_t) -> xcb_generic_iterator_t #c_call;
    integer_feedback_ctl_next:                             #type (i: *xcb_input_integer_feedback_ctl_iterator_t) -> void #c_call;
    integer_feedback_ctl_end:                              #type (i: xcb_input_integer_feedback_ctl_iterator_t) -> xcb_generic_iterator_t #c_call;
    string_feedback_ctl_sizeof:                            #type (_buffer: *void) -> s32 #c_call;
    string_feedback_ctl_keysyms:                           #type (R: *xcb_input_string_feedback_ctl_t) -> *xcb_keysym_t #c_call;
    string_feedback_ctl_keysyms_length:                    #type (R: *xcb_input_string_feedback_ctl_t) -> s32 #c_call;
    string_feedback_ctl_keysyms_end:                       #type (R: *xcb_input_string_feedback_ctl_t) -> xcb_generic_iterator_t #c_call;
    string_feedback_ctl_next:                              #type (i: *xcb_input_string_feedback_ctl_iterator_t) -> void #c_call;
    string_feedback_ctl_end:                               #type (i: xcb_input_string_feedback_ctl_iterator_t) -> xcb_generic_iterator_t #c_call;
    bell_feedback_ctl_next:                                #type (i: *xcb_input_bell_feedback_ctl_iterator_t) -> void #c_call;
    bell_feedback_ctl_end:                                 #type (i: xcb_input_bell_feedback_ctl_iterator_t) -> xcb_generic_iterator_t #c_call;
    led_feedback_ctl_next:                                 #type (i: *xcb_input_led_feedback_ctl_iterator_t) -> void #c_call;
    led_feedback_ctl_end:                                  #type (i: xcb_input_led_feedback_ctl_iterator_t) -> xcb_generic_iterator_t #c_call;
    feedback_ctl_data_string_keysyms:                      #type (S: *xcb_input_feedback_ctl_data_t) -> *xcb_keysym_t #c_call;
    feedback_ctl_data_string_keysyms_length:               #type (R: *xcb_input_feedback_ctl_t, S: *xcb_input_feedback_ctl_data_t) -> s32 #c_call;
    feedback_ctl_data_string_keysyms_end:                  #type (R: *xcb_input_feedback_ctl_t, S: *xcb_input_feedback_ctl_data_t) -> xcb_generic_iterator_t #c_call;
    feedback_ctl_data_serialize:                           #type (_buffer: **void, class_id: u8, _aux: *xcb_input_feedback_ctl_data_t) -> s32 #c_call;
    feedback_ctl_data_unpack:                              #type (_buffer: *void, class_id: u8, _aux: *xcb_input_feedback_ctl_data_t) -> s32 #c_call;
    feedback_ctl_data_sizeof:                              #type (_buffer: *void, class_id: u8) -> s32 #c_call;
    feedback_ctl_sizeof:                                   #type (_buffer: *void) -> s32 #c_call;
    feedback_ctl_next:                                     #type (i: *xcb_input_feedback_ctl_iterator_t) -> void #c_call;
    feedback_ctl_end:                                      #type (i: xcb_input_feedback_ctl_iterator_t) -> xcb_generic_iterator_t #c_call;
    change_feedback_control_sizeof:                        #type (_buffer: *void) -> s32 #c_call;
    change_feedback_control_checked:                       #type (c: *xcb_connection_t, mask: u32, device_id: u8, feedback_id: u8, feedback: *xcb_input_feedback_ctl_t) -> xcb_void_cookie_t #c_call;
    change_feedback_control:                               #type (c: *xcb_connection_t, mask: u32, device_id: u8, feedback_id: u8, feedback: *xcb_input_feedback_ctl_t) -> xcb_void_cookie_t #c_call;
    change_feedback_control_feedback:                      #type (R: *xcb_input_change_feedback_control_request_t) -> *xcb_input_feedback_ctl_t #c_call;
    get_device_key_mapping_sizeof:                         #type (_buffer: *void) -> s32 #c_call;
    get_device_key_mapping:                                #type (c: *xcb_connection_t, device_id: u8, first_keycode: xcb_input_key_code_t, count: u8) -> xcb_input_get_device_key_mapping_cookie_t #c_call;
    get_device_key_mapping_unchecked:                      #type (c: *xcb_connection_t, device_id: u8, first_keycode: xcb_input_key_code_t, count: u8) -> xcb_input_get_device_key_mapping_cookie_t #c_call;
    get_device_key_mapping_keysyms:                        #type (R: *xcb_input_get_device_key_mapping_reply_t) -> *xcb_keysym_t #c_call;
    get_device_key_mapping_keysyms_length:                 #type (R: *xcb_input_get_device_key_mapping_reply_t) -> s32 #c_call;
    get_device_key_mapping_keysyms_end:                    #type (R: *xcb_input_get_device_key_mapping_reply_t) -> xcb_generic_iterator_t #c_call;
    get_device_key_mapping_reply:                          #type (c: *xcb_connection_t, cookie: xcb_input_get_device_key_mapping_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_get_device_key_mapping_reply_t #c_call;
    change_device_key_mapping_sizeof:                      #type (_buffer: *void) -> s32 #c_call;
    change_device_key_mapping_checked:                     #type (c: *xcb_connection_t, device_id: u8, first_keycode: xcb_input_key_code_t, keysyms_per_keycode: u8, keycode_count: u8, keysyms: *xcb_keysym_t) -> xcb_void_cookie_t #c_call;
    change_device_key_mapping:                             #type (c: *xcb_connection_t, device_id: u8, first_keycode: xcb_input_key_code_t, keysyms_per_keycode: u8, keycode_count: u8, keysyms: *xcb_keysym_t) -> xcb_void_cookie_t #c_call;
    change_device_key_mapping_keysyms:                     #type (R: *xcb_input_change_device_key_mapping_request_t) -> *xcb_keysym_t #c_call;
    change_device_key_mapping_keysyms_length:              #type (R: *xcb_input_change_device_key_mapping_request_t) -> s32 #c_call;
    change_device_key_mapping_keysyms_end:                 #type (R: *xcb_input_change_device_key_mapping_request_t) -> xcb_generic_iterator_t #c_call;
    get_device_modifier_mapping_sizeof:                    #type (_buffer: *void) -> s32 #c_call;
    get_device_modifier_mapping:                           #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_get_device_modifier_mapping_cookie_t #c_call;
    get_device_modifier_mapping_unchecked:                 #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_get_device_modifier_mapping_cookie_t #c_call;
    get_device_modifier_mapping_keymaps:                   #type (R: *xcb_input_get_device_modifier_mapping_reply_t) -> *u8 #c_call;
    get_device_modifier_mapping_keymaps_length:            #type (R: *xcb_input_get_device_modifier_mapping_reply_t) -> s32 #c_call;
    get_device_modifier_mapping_keymaps_end:               #type (R: *xcb_input_get_device_modifier_mapping_reply_t) -> xcb_generic_iterator_t #c_call;
    get_device_modifier_mapping_reply:                     #type (c: *xcb_connection_t, cookie: xcb_input_get_device_modifier_mapping_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_get_device_modifier_mapping_reply_t #c_call;
    set_device_modifier_mapping_sizeof:                    #type (_buffer: *void) -> s32 #c_call;
    set_device_modifier_mapping:                           #type (c: *xcb_connection_t, device_id: u8, keycodes_per_modifier: u8, keymaps: *u8) -> xcb_input_set_device_modifier_mapping_cookie_t #c_call;
    set_device_modifier_mapping_unchecked:                 #type (c: *xcb_connection_t, device_id: u8, keycodes_per_modifier: u8, keymaps: *u8) -> xcb_input_set_device_modifier_mapping_cookie_t #c_call;
    set_device_modifier_mapping_reply:                     #type (c: *xcb_connection_t, cookie: xcb_input_set_device_modifier_mapping_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_set_device_modifier_mapping_reply_t #c_call;
    get_device_button_mapping_sizeof:                      #type (_buffer: *void) -> s32 #c_call;
    get_device_button_mapping:                             #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_get_device_button_mapping_cookie_t #c_call;
    get_device_button_mapping_unchecked:                   #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_get_device_button_mapping_cookie_t #c_call;
    get_device_button_mapping_map:                         #type (R: *xcb_input_get_device_button_mapping_reply_t) -> *u8 #c_call;
    get_device_button_mapping_map_length:                  #type (R: *xcb_input_get_device_button_mapping_reply_t) -> s32 #c_call;
    get_device_button_mapping_map_end:                     #type (R: *xcb_input_get_device_button_mapping_reply_t) -> xcb_generic_iterator_t #c_call;
    get_device_button_mapping_reply:                       #type (c: *xcb_connection_t, cookie: xcb_input_get_device_button_mapping_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_get_device_button_mapping_reply_t #c_call;
    set_device_button_mapping_sizeof:                      #type (_buffer: *void) -> s32 #c_call;
    set_device_button_mapping:                             #type (c: *xcb_connection_t, device_id: u8, map_size: u8, map: *u8) -> xcb_input_set_device_button_mapping_cookie_t #c_call;
    set_device_button_mapping_unchecked:                   #type (c: *xcb_connection_t, device_id: u8, map_size: u8, map: *u8) -> xcb_input_set_device_button_mapping_cookie_t #c_call;
    set_device_button_mapping_reply:                       #type (c: *xcb_connection_t, cookie: xcb_input_set_device_button_mapping_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_set_device_button_mapping_reply_t #c_call;
    key_state_next:                                        #type (i: *xcb_input_key_state_iterator_t) -> void #c_call;
    key_state_end:                                         #type (i: xcb_input_key_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    button_state_next:                                     #type (i: *xcb_input_button_state_iterator_t) -> void #c_call;
    button_state_end:                                      #type (i: xcb_input_button_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    valuator_state_sizeof:                                 #type (_buffer: *void) -> s32 #c_call;
    valuator_state_valuators:                              #type (R: *xcb_input_valuator_state_t) -> *s32 #c_call;
    valuator_state_valuators_length:                       #type (R: *xcb_input_valuator_state_t) -> s32 #c_call;
    valuator_state_valuators_end:                          #type (R: *xcb_input_valuator_state_t) -> xcb_generic_iterator_t #c_call;
    valuator_state_next:                                   #type (i: *xcb_input_valuator_state_iterator_t) -> void #c_call;
    valuator_state_end:                                    #type (i: xcb_input_valuator_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    input_state_data_valuator_valuators:                   #type (S: *xcb_input_input_state_data_t) -> *s32 #c_call;
    input_state_data_valuator_valuators_length:            #type (R: *xcb_input_input_state_t, S: *xcb_input_input_state_data_t) -> s32 #c_call;
    input_state_data_valuator_valuators_end:               #type (R: *xcb_input_input_state_t, S: *xcb_input_input_state_data_t) -> xcb_generic_iterator_t #c_call;
    input_state_data_serialize:                            #type (_buffer: **void, class_id: u8, _aux: *xcb_input_input_state_data_t) -> s32 #c_call;
    input_state_data_unpack:                               #type (_buffer: *void, class_id: u8, _aux: *xcb_input_input_state_data_t) -> s32 #c_call;
    input_state_data_sizeof:                               #type (_buffer: *void, class_id: u8) -> s32 #c_call;
    input_state_sizeof:                                    #type (_buffer: *void) -> s32 #c_call;
    input_state_next:                                      #type (i: *xcb_input_input_state_iterator_t) -> void #c_call;
    input_state_end:                                       #type (i: xcb_input_input_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    query_device_state_sizeof:                             #type (_buffer: *void) -> s32 #c_call;
    query_device_state:                                    #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_query_device_state_cookie_t #c_call;
    query_device_state_unchecked:                          #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_query_device_state_cookie_t #c_call;
    query_device_state_classes_length:                     #type (R: *xcb_input_query_device_state_reply_t) -> s32 #c_call;
    query_device_state_classes_iterator:                   #type (R: *xcb_input_query_device_state_reply_t) -> xcb_input_input_state_iterator_t #c_call;
    query_device_state_reply:                              #type (c: *xcb_connection_t, cookie: xcb_input_query_device_state_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_query_device_state_reply_t #c_call;
    device_bell_checked:                                   #type (c: *xcb_connection_t, device_id: u8, feedback_id: u8, feedback_class: u8, percent: s8) -> xcb_void_cookie_t #c_call;
    device_bell:                                           #type (c: *xcb_connection_t, device_id: u8, feedback_id: u8, feedback_class: u8, percent: s8) -> xcb_void_cookie_t #c_call;
    set_device_valuators_sizeof:                           #type (_buffer: *void) -> s32 #c_call;
    set_device_valuators:                                  #type (c: *xcb_connection_t, device_id: u8, first_valuator: u8, num_valuators: u8, valuators: *s32) -> xcb_input_set_device_valuators_cookie_t #c_call;
    set_device_valuators_unchecked:                        #type (c: *xcb_connection_t, device_id: u8, first_valuator: u8, num_valuators: u8, valuators: *s32) -> xcb_input_set_device_valuators_cookie_t #c_call;
    set_device_valuators_reply:                            #type (c: *xcb_connection_t, cookie: xcb_input_set_device_valuators_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_set_device_valuators_reply_t #c_call;
    device_resolution_state_sizeof:                        #type (_buffer: *void) -> s32 #c_call;
    device_resolution_state_resolution_values:             #type (R: *xcb_input_device_resolution_state_t) -> *u32 #c_call;
    device_resolution_state_resolution_values_length:      #type (R: *xcb_input_device_resolution_state_t) -> s32 #c_call;
    device_resolution_state_resolution_values_end:         #type (R: *xcb_input_device_resolution_state_t) -> xcb_generic_iterator_t #c_call;
    device_resolution_state_resolution_min:                #type (R: *xcb_input_device_resolution_state_t) -> *u32 #c_call;
    device_resolution_state_resolution_min_length:         #type (R: *xcb_input_device_resolution_state_t) -> s32 #c_call;
    device_resolution_state_resolution_min_end:            #type (R: *xcb_input_device_resolution_state_t) -> xcb_generic_iterator_t #c_call;
    device_resolution_state_resolution_max:                #type (R: *xcb_input_device_resolution_state_t) -> *u32 #c_call;
    device_resolution_state_resolution_max_length:         #type (R: *xcb_input_device_resolution_state_t) -> s32 #c_call;
    device_resolution_state_resolution_max_end:            #type (R: *xcb_input_device_resolution_state_t) -> xcb_generic_iterator_t #c_call;
    device_resolution_state_next:                          #type (i: *xcb_input_device_resolution_state_iterator_t) -> void #c_call;
    device_resolution_state_end:                           #type (i: xcb_input_device_resolution_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    device_abs_calib_state_next:                           #type (i: *xcb_input_device_abs_calib_state_iterator_t) -> void #c_call;
    device_abs_calib_state_end:                            #type (i: xcb_input_device_abs_calib_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    device_abs_area_state_next:                            #type (i: *xcb_input_device_abs_area_state_iterator_t) -> void #c_call;
    device_abs_area_state_end:                             #type (i: xcb_input_device_abs_area_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    device_core_state_next:                                #type (i: *xcb_input_device_core_state_iterator_t) -> void #c_call;
    device_core_state_end:                                 #type (i: xcb_input_device_core_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    device_enable_state_next:                              #type (i: *xcb_input_device_enable_state_iterator_t) -> void #c_call;
    device_enable_state_end:                               #type (i: xcb_input_device_enable_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    device_state_data_resolution_resolution_values:        #type (S: *xcb_input_device_state_data_t) -> *u32 #c_call;
    device_state_data_resolution_resolution_values_length: #type (R: *xcb_input_device_state_t, S: *xcb_input_device_state_data_t) -> s32 #c_call;
    device_state_data_resolution_resolution_values_end:    #type (R: *xcb_input_device_state_t, S: *xcb_input_device_state_data_t) -> xcb_generic_iterator_t #c_call;
    device_state_data_resolution_resolution_min:           #type (S: *xcb_input_device_state_data_t) -> *u32 #c_call;
    device_state_data_resolution_resolution_min_length:    #type (R: *xcb_input_device_state_t, S: *xcb_input_device_state_data_t) -> s32 #c_call;
    device_state_data_resolution_resolution_min_end:       #type (R: *xcb_input_device_state_t, S: *xcb_input_device_state_data_t) -> xcb_generic_iterator_t #c_call;
    device_state_data_resolution_resolution_max:           #type (S: *xcb_input_device_state_data_t) -> *u32 #c_call;
    device_state_data_resolution_resolution_max_length:    #type (R: *xcb_input_device_state_t, S: *xcb_input_device_state_data_t) -> s32 #c_call;
    device_state_data_resolution_resolution_max_end:       #type (R: *xcb_input_device_state_t, S: *xcb_input_device_state_data_t) -> xcb_generic_iterator_t #c_call;
    device_state_data_serialize:                           #type (_buffer: **void, control_id: u16, _aux: *xcb_input_device_state_data_t) -> s32 #c_call;
    device_state_data_unpack:                              #type (_buffer: *void, control_id: u16, _aux: *xcb_input_device_state_data_t) -> s32 #c_call;
    device_state_data_sizeof:                              #type (_buffer: *void, control_id: u16) -> s32 #c_call;
    device_state_sizeof:                                   #type (_buffer: *void) -> s32 #c_call;
    device_state_next:                                     #type (i: *xcb_input_device_state_iterator_t) -> void #c_call;
    device_state_end:                                      #type (i: xcb_input_device_state_iterator_t) -> xcb_generic_iterator_t #c_call;
    get_device_control_sizeof:                             #type (_buffer: *void) -> s32 #c_call;
    get_device_control:                                    #type (c: *xcb_connection_t, control_id: u16, device_id: u8) -> xcb_input_get_device_control_cookie_t #c_call;
    get_device_control_unchecked:                          #type (c: *xcb_connection_t, control_id: u16, device_id: u8) -> xcb_input_get_device_control_cookie_t #c_call;
    get_device_control_control:                            #type (R: *xcb_input_get_device_control_reply_t) -> *xcb_input_device_state_t #c_call;
    get_device_control_reply:                              #type (c: *xcb_connection_t, cookie: xcb_input_get_device_control_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_get_device_control_reply_t #c_call;
    device_resolution_ctl_sizeof:                          #type (_buffer: *void) -> s32 #c_call;
    device_resolution_ctl_resolution_values:               #type (R: *xcb_input_device_resolution_ctl_t) -> *u32 #c_call;
    device_resolution_ctl_resolution_values_length:        #type (R: *xcb_input_device_resolution_ctl_t) -> s32 #c_call;
    device_resolution_ctl_resolution_values_end:           #type (R: *xcb_input_device_resolution_ctl_t) -> xcb_generic_iterator_t #c_call;
    device_resolution_ctl_next:                            #type (i: *xcb_input_device_resolution_ctl_iterator_t) -> void #c_call;
    device_resolution_ctl_end:                             #type (i: xcb_input_device_resolution_ctl_iterator_t) -> xcb_generic_iterator_t #c_call;
    device_abs_calib_ctl_next:                             #type (i: *xcb_input_device_abs_calib_ctl_iterator_t) -> void #c_call;
    device_abs_calib_ctl_end:                              #type (i: xcb_input_device_abs_calib_ctl_iterator_t) -> xcb_generic_iterator_t #c_call;
    device_abs_area_ctrl_next:                             #type (i: *xcb_input_device_abs_area_ctrl_iterator_t) -> void #c_call;
    device_abs_area_ctrl_end:                              #type (i: xcb_input_device_abs_area_ctrl_iterator_t) -> xcb_generic_iterator_t #c_call;
    device_core_ctrl_next:                                 #type (i: *xcb_input_device_core_ctrl_iterator_t) -> void #c_call;
    device_core_ctrl_end:                                  #type (i: xcb_input_device_core_ctrl_iterator_t) -> xcb_generic_iterator_t #c_call;
    device_enable_ctrl_next:                               #type (i: *xcb_input_device_enable_ctrl_iterator_t) -> void #c_call;
    device_enable_ctrl_end:                                #type (i: xcb_input_device_enable_ctrl_iterator_t) -> xcb_generic_iterator_t #c_call;
    device_ctl_data_resolution_resolution_values:          #type (S: *xcb_input_device_ctl_data_t) -> *u32 #c_call;
    device_ctl_data_resolution_resolution_values_length:   #type (R: *xcb_input_device_ctl_t, S: *xcb_input_device_ctl_data_t) -> s32 #c_call;
    device_ctl_data_resolution_resolution_values_end:      #type (R: *xcb_input_device_ctl_t, S: *xcb_input_device_ctl_data_t) -> xcb_generic_iterator_t #c_call;
    device_ctl_data_serialize:                             #type (_buffer: **void, control_id: u16, _aux: *xcb_input_device_ctl_data_t) -> s32 #c_call;
    device_ctl_data_unpack:                                #type (_buffer: *void, control_id: u16, _aux: *xcb_input_device_ctl_data_t) -> s32 #c_call;
    device_ctl_data_sizeof:                                #type (_buffer: *void, control_id: u16) -> s32 #c_call;
    device_ctl_sizeof:                                     #type (_buffer: *void) -> s32 #c_call;
    device_ctl_next:                                       #type (i: *xcb_input_device_ctl_iterator_t) -> void #c_call;
    device_ctl_end:                                        #type (i: xcb_input_device_ctl_iterator_t) -> xcb_generic_iterator_t #c_call;
    change_device_control_sizeof:                          #type (_buffer: *void) -> s32 #c_call;
    change_device_control:                                 #type (c: *xcb_connection_t, control_id: u16, device_id: u8, control: *xcb_input_device_ctl_t) -> xcb_input_change_device_control_cookie_t #c_call;
    change_device_control_unchecked:                       #type (c: *xcb_connection_t, control_id: u16, device_id: u8, control: *xcb_input_device_ctl_t) -> xcb_input_change_device_control_cookie_t #c_call;
    change_device_control_reply:                           #type (c: *xcb_connection_t, cookie: xcb_input_change_device_control_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_change_device_control_reply_t #c_call;
    list_device_properties_sizeof:                         #type (_buffer: *void) -> s32 #c_call;
    list_device_properties:                                #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_list_device_properties_cookie_t #c_call;
    list_device_properties_unchecked:                      #type (c: *xcb_connection_t, device_id: u8) -> xcb_input_list_device_properties_cookie_t #c_call;
    list_device_properties_atoms:                          #type (R: *xcb_input_list_device_properties_reply_t) -> *xcb_atom_t #c_call;
    list_device_properties_atoms_length:                   #type (R: *xcb_input_list_device_properties_reply_t) -> s32 #c_call;
    list_device_properties_atoms_end:                      #type (R: *xcb_input_list_device_properties_reply_t) -> xcb_generic_iterator_t #c_call;
    list_device_properties_reply:                          #type (c: *xcb_connection_t, cookie: xcb_input_list_device_properties_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_list_device_properties_reply_t #c_call;
    change_device_property_items_data_8:                   #type (S: *xcb_input_change_device_property_items_t) -> *u8 #c_call;
    change_device_property_items_data_8_length:            #type (R: *xcb_input_change_device_property_request_t, S: *xcb_input_change_device_property_items_t) -> s32 #c_call;
    change_device_property_items_data_8_end:               #type (R: *xcb_input_change_device_property_request_t, S: *xcb_input_change_device_property_items_t) -> xcb_generic_iterator_t #c_call;
    change_device_property_items_data_16:                  #type (S: *xcb_input_change_device_property_items_t) -> *u16 #c_call;
    change_device_property_items_data_16_length:           #type (R: *xcb_input_change_device_property_request_t, S: *xcb_input_change_device_property_items_t) -> s32 #c_call;
    change_device_property_items_data_16_end:              #type (R: *xcb_input_change_device_property_request_t, S: *xcb_input_change_device_property_items_t) -> xcb_generic_iterator_t #c_call;
    change_device_property_items_data_32:                  #type (S: *xcb_input_change_device_property_items_t) -> *u32 #c_call;
    change_device_property_items_data_32_length:           #type (R: *xcb_input_change_device_property_request_t, S: *xcb_input_change_device_property_items_t) -> s32 #c_call;
    change_device_property_items_data_32_end:              #type (R: *xcb_input_change_device_property_request_t, S: *xcb_input_change_device_property_items_t) -> xcb_generic_iterator_t #c_call;
    change_device_property_items_serialize:                #type (_buffer: **void, num_items: u32, format: u8, _aux: *xcb_input_change_device_property_items_t) -> s32 #c_call;
    change_device_property_items_unpack:                   #type (_buffer: *void, num_items: u32, format: u8, _aux: *xcb_input_change_device_property_items_t) -> s32 #c_call;
    change_device_property_items_sizeof:                   #type (_buffer: *void, num_items: u32, format: u8) -> s32 #c_call;
    change_device_property_sizeof:                         #type (_buffer: *void) -> s32 #c_call;
    change_device_property_checked:                        #type (c: *xcb_connection_t, property: xcb_atom_t, type: xcb_atom_t, device_id: u8, format: u8, mode: u8, num_items: u32, items: *void) -> xcb_void_cookie_t #c_call;
    change_device_property:                                #type (c: *xcb_connection_t, property: xcb_atom_t, type: xcb_atom_t, device_id: u8, format: u8, mode: u8, num_items: u32, items: *void) -> xcb_void_cookie_t #c_call;
    change_device_property_aux_checked:                    #type (c: *xcb_connection_t, property: xcb_atom_t, type: xcb_atom_t, device_id: u8, format: u8, mode: u8, num_items: u32, items: *xcb_input_change_device_property_items_t) -> xcb_void_cookie_t #c_call;
    change_device_property_aux:                            #type (c: *xcb_connection_t, property: xcb_atom_t, type: xcb_atom_t, device_id: u8, format: u8, mode: u8, num_items: u32, items: *xcb_input_change_device_property_items_t) -> xcb_void_cookie_t #c_call;
    change_device_property_items:                          #type (R: *xcb_input_change_device_property_request_t) -> *void #c_call;
    delete_device_property_checked:                        #type (c: *xcb_connection_t, property: xcb_atom_t, device_id: u8) -> xcb_void_cookie_t #c_call;
    delete_device_property:                                #type (c: *xcb_connection_t, property: xcb_atom_t, device_id: u8) -> xcb_void_cookie_t #c_call;
    get_device_property_items_data_8:                      #type (S: *xcb_input_get_device_property_items_t) -> *u8 #c_call;
    get_device_property_items_data_8_length:               #type (R: *xcb_input_get_device_property_reply_t, S: *xcb_input_get_device_property_items_t) -> s32 #c_call;
    get_device_property_items_data_8_end:                  #type (R: *xcb_input_get_device_property_reply_t, S: *xcb_input_get_device_property_items_t) -> xcb_generic_iterator_t #c_call;
    get_device_property_items_data_16:                     #type (S: *xcb_input_get_device_property_items_t) -> *u16 #c_call;
    get_device_property_items_data_16_length:              #type (R: *xcb_input_get_device_property_reply_t, S: *xcb_input_get_device_property_items_t) -> s32 #c_call;
    get_device_property_items_data_16_end:                 #type (R: *xcb_input_get_device_property_reply_t, S: *xcb_input_get_device_property_items_t) -> xcb_generic_iterator_t #c_call;
    get_device_property_items_data_32:                     #type (S: *xcb_input_get_device_property_items_t) -> *u32 #c_call;
    get_device_property_items_data_32_length:              #type (R: *xcb_input_get_device_property_reply_t, S: *xcb_input_get_device_property_items_t) -> s32 #c_call;
    get_device_property_items_data_32_end:                 #type (R: *xcb_input_get_device_property_reply_t, S: *xcb_input_get_device_property_items_t) -> xcb_generic_iterator_t #c_call;
    get_device_property_items_serialize:                   #type (_buffer: **void, num_items: u32, format: u8, _aux: *xcb_input_get_device_property_items_t) -> s32 #c_call;
    get_device_property_items_unpack:                      #type (_buffer: *void, num_items: u32, format: u8, _aux: *xcb_input_get_device_property_items_t) -> s32 #c_call;
    get_device_property_items_sizeof:                      #type (_buffer: *void, num_items: u32, format: u8) -> s32 #c_call;
    get_device_property_sizeof:                            #type (_buffer: *void) -> s32 #c_call;
    get_device_property:                                   #type (c: *xcb_connection_t, property: xcb_atom_t, type: xcb_atom_t, offset: u32, len: u32, device_id: u8, _delete: u8) -> xcb_input_get_device_property_cookie_t #c_call;
    get_device_property_unchecked:                         #type (c: *xcb_connection_t, property: xcb_atom_t, type: xcb_atom_t, offset: u32, len: u32, device_id: u8, _delete: u8) -> xcb_input_get_device_property_cookie_t #c_call;
    get_device_property_items:                             #type (R: *xcb_input_get_device_property_reply_t) -> *void #c_call;
    get_device_property_reply:                             #type (c: *xcb_connection_t, cookie: xcb_input_get_device_property_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_get_device_property_reply_t #c_call;
    group_info_next:                                       #type (i: *xcb_input_group_info_iterator_t) -> void #c_call;
    group_info_end:                                        #type (i: xcb_input_group_info_iterator_t) -> xcb_generic_iterator_t #c_call;
    modifier_info_next:                                    #type (i: *xcb_input_modifier_info_iterator_t) -> void #c_call;
    modifier_info_end:                                     #type (i: xcb_input_modifier_info_iterator_t) -> xcb_generic_iterator_t #c_call;
    xi_query_pointer_sizeof:                               #type (_buffer: *void) -> s32 #c_call;
    xi_query_pointer:                                      #type (c: *xcb_connection_t, window: xcb_window_t, deviceid: xcb_input_device_id_t) -> xcb_input_xi_query_pointer_cookie_t #c_call;
    xi_query_pointer_unchecked:                            #type (c: *xcb_connection_t, window: xcb_window_t, deviceid: xcb_input_device_id_t) -> xcb_input_xi_query_pointer_cookie_t #c_call;
    xi_query_pointer_buttons:                              #type (R: *xcb_input_xi_query_pointer_reply_t) -> *u32 #c_call;
    xi_query_pointer_buttons_length:                       #type (R: *xcb_input_xi_query_pointer_reply_t) -> s32 #c_call;
    xi_query_pointer_buttons_end:                          #type (R: *xcb_input_xi_query_pointer_reply_t) -> xcb_generic_iterator_t #c_call;
    xi_query_pointer_reply:                                #type (c: *xcb_connection_t, cookie: xcb_input_xi_query_pointer_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_xi_query_pointer_reply_t #c_call;
    xi_warp_pointer_checked:                               #type (c: *xcb_connection_t, src_win: xcb_window_t, dst_win: xcb_window_t, src_x: xcb_input_fp1616_t, src_y: xcb_input_fp1616_t, src_width: u16, src_height: u16, dst_x: xcb_input_fp1616_t, dst_y: xcb_input_fp1616_t, deviceid: xcb_input_device_id_t) -> xcb_void_cookie_t #c_call;
    xi_warp_pointer:                                       #type (c: *xcb_connection_t, src_win: xcb_window_t, dst_win: xcb_window_t, src_x: xcb_input_fp1616_t, src_y: xcb_input_fp1616_t, src_width: u16, src_height: u16, dst_x: xcb_input_fp1616_t, dst_y: xcb_input_fp1616_t, deviceid: xcb_input_device_id_t) -> xcb_void_cookie_t #c_call;
    xi_change_cursor_checked:                              #type (c: *xcb_connection_t, window: xcb_window_t, cursor: xcb_cursor_t, deviceid: xcb_input_device_id_t) -> xcb_void_cookie_t #c_call;
    xi_change_cursor:                                      #type (c: *xcb_connection_t, window: xcb_window_t, cursor: xcb_cursor_t, deviceid: xcb_input_device_id_t) -> xcb_void_cookie_t #c_call;
    add_master_sizeof:                                     #type (_buffer: *void) -> s32 #c_call;
    add_master_name:                                       #type (R: *xcb_input_add_master_t) -> *u8 #c_call;
    add_master_name_length:                                #type (R: *xcb_input_add_master_t) -> s32 #c_call;
    add_master_name_end:                                   #type (R: *xcb_input_add_master_t) -> xcb_generic_iterator_t #c_call;
    add_master_next:                                       #type (i: *xcb_input_add_master_iterator_t) -> void #c_call;
    add_master_end:                                        #type (i: xcb_input_add_master_iterator_t) -> xcb_generic_iterator_t #c_call;
    remove_master_next:                                    #type (i: *xcb_input_remove_master_iterator_t) -> void #c_call;
    remove_master_end:                                     #type (i: xcb_input_remove_master_iterator_t) -> xcb_generic_iterator_t #c_call;
    attach_slave_next:                                     #type (i: *xcb_input_attach_slave_iterator_t) -> void #c_call;
    attach_slave_end:                                      #type (i: xcb_input_attach_slave_iterator_t) -> xcb_generic_iterator_t #c_call;
    detach_slave_next:                                     #type (i: *xcb_input_detach_slave_iterator_t) -> void #c_call;
    detach_slave_end:                                      #type (i: xcb_input_detach_slave_iterator_t) -> xcb_generic_iterator_t #c_call;
    hierarchy_change_data_add_master_name:                 #type (S: *xcb_input_hierarchy_change_data_t) -> *u8 #c_call;
    hierarchy_change_data_add_master_name_length:          #type (R: *xcb_input_hierarchy_change_t, S: *xcb_input_hierarchy_change_data_t) -> s32 #c_call;
    hierarchy_change_data_add_master_name_end:             #type (R: *xcb_input_hierarchy_change_t, S: *xcb_input_hierarchy_change_data_t) -> xcb_generic_iterator_t #c_call;
    hierarchy_change_data_serialize:                       #type (_buffer: **void, type: u16, _aux: *xcb_input_hierarchy_change_data_t) -> s32 #c_call;
    hierarchy_change_data_unpack:                          #type (_buffer: *void, type: u16, _aux: *xcb_input_hierarchy_change_data_t) -> s32 #c_call;
    hierarchy_change_data_sizeof:                          #type (_buffer: *void, type: u16) -> s32 #c_call;
    hierarchy_change_sizeof:                               #type (_buffer: *void) -> s32 #c_call;
    hierarchy_change_next:                                 #type (i: *xcb_input_hierarchy_change_iterator_t) -> void #c_call;
    hierarchy_change_end:                                  #type (i: xcb_input_hierarchy_change_iterator_t) -> xcb_generic_iterator_t #c_call;
    xi_change_hierarchy_sizeof:                            #type (_buffer: *void) -> s32 #c_call;
    xi_change_hierarchy_checked:                           #type (c: *xcb_connection_t, num_changes: u8, changes: *xcb_input_hierarchy_change_t) -> xcb_void_cookie_t #c_call;
    xi_change_hierarchy:                                   #type (c: *xcb_connection_t, num_changes: u8, changes: *xcb_input_hierarchy_change_t) -> xcb_void_cookie_t #c_call;
    xi_change_hierarchy_changes_length:                    #type (R: *xcb_input_xi_change_hierarchy_request_t) -> s32 #c_call;
    xi_change_hierarchy_changes_iterator:                  #type (R: *xcb_input_xi_change_hierarchy_request_t) -> xcb_input_hierarchy_change_iterator_t #c_call;
    xi_set_client_pointer_checked:                         #type (c: *xcb_connection_t, window: xcb_window_t, deviceid: xcb_input_device_id_t) -> xcb_void_cookie_t #c_call;
    xi_set_client_pointer:                                 #type (c: *xcb_connection_t, window: xcb_window_t, deviceid: xcb_input_device_id_t) -> xcb_void_cookie_t #c_call;
    xi_get_client_pointer:                                 #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_input_xi_get_client_pointer_cookie_t #c_call;
    xi_get_client_pointer_unchecked:                       #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_input_xi_get_client_pointer_cookie_t #c_call;
    xi_get_client_pointer_reply:                           #type (c: *xcb_connection_t, cookie: xcb_input_xi_get_client_pointer_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_xi_get_client_pointer_reply_t #c_call;
    event_mask_sizeof:                                     #type (_buffer: *void) -> s32 #c_call;
    event_mask_mask:                                       #type (R: *xcb_input_event_mask_t) -> *u32 #c_call;
    event_mask_mask_length:                                #type (R: *xcb_input_event_mask_t) -> s32 #c_call;
    event_mask_mask_end:                                   #type (R: *xcb_input_event_mask_t) -> xcb_generic_iterator_t #c_call;
    event_mask_next:                                       #type (i: *xcb_input_event_mask_iterator_t) -> void #c_call;
    event_mask_end:                                        #type (i: xcb_input_event_mask_iterator_t) -> xcb_generic_iterator_t #c_call;
    xi_select_events_sizeof:                               #type (_buffer: *void) -> s32 #c_call;
    xi_select_events_checked:                              #type (c: *xcb_connection_t, window: xcb_window_t, num_mask: u16, masks: *xcb_input_event_mask_t) -> xcb_void_cookie_t #c_call;
    xi_select_events:                                      #type (c: *xcb_connection_t, window: xcb_window_t, num_mask: u16, masks: *xcb_input_event_mask_t) -> xcb_void_cookie_t #c_call;
    xi_select_events_masks_length:                         #type (R: *xcb_input_xi_select_events_request_t) -> s32 #c_call;
    xi_select_events_masks_iterator:                       #type (R: *xcb_input_xi_select_events_request_t) -> xcb_input_event_mask_iterator_t #c_call;
    xi_query_version:                                      #type (c: *xcb_connection_t, major_version: u16, minor_version: u16) -> xcb_input_xi_query_version_cookie_t #c_call;
    xi_query_version_unchecked:                            #type (c: *xcb_connection_t, major_version: u16, minor_version: u16) -> xcb_input_xi_query_version_cookie_t #c_call;
    xi_query_version_reply:                                #type (c: *xcb_connection_t, cookie: xcb_input_xi_query_version_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_xi_query_version_reply_t #c_call;
    button_class_sizeof:                                   #type (_buffer: *void) -> s32 #c_call;
    button_class_state:                                    #type (R: *xcb_input_button_class_t) -> *u32 #c_call;
    button_class_state_length:                             #type (R: *xcb_input_button_class_t) -> s32 #c_call;
    button_class_state_end:                                #type (R: *xcb_input_button_class_t) -> xcb_generic_iterator_t #c_call;
    button_class_labels:                                   #type (R: *xcb_input_button_class_t) -> *xcb_atom_t #c_call;
    button_class_labels_length:                            #type (R: *xcb_input_button_class_t) -> s32 #c_call;
    button_class_labels_end:                               #type (R: *xcb_input_button_class_t) -> xcb_generic_iterator_t #c_call;
    button_class_next:                                     #type (i: *xcb_input_button_class_iterator_t) -> void #c_call;
    button_class_end:                                      #type (i: xcb_input_button_class_iterator_t) -> xcb_generic_iterator_t #c_call;
    key_class_sizeof:                                      #type (_buffer: *void) -> s32 #c_call;
    key_class_keys:                                        #type (R: *xcb_input_key_class_t) -> *u32 #c_call;
    key_class_keys_length:                                 #type (R: *xcb_input_key_class_t) -> s32 #c_call;
    key_class_keys_end:                                    #type (R: *xcb_input_key_class_t) -> xcb_generic_iterator_t #c_call;
    key_class_next:                                        #type (i: *xcb_input_key_class_iterator_t) -> void #c_call;
    key_class_end:                                         #type (i: xcb_input_key_class_iterator_t) -> xcb_generic_iterator_t #c_call;
    scroll_class_next:                                     #type (i: *xcb_input_scroll_class_iterator_t) -> void #c_call;
    scroll_class_end:                                      #type (i: xcb_input_scroll_class_iterator_t) -> xcb_generic_iterator_t #c_call;
    touch_class_next:                                      #type (i: *xcb_input_touch_class_iterator_t) -> void #c_call;
    touch_class_end:                                       #type (i: xcb_input_touch_class_iterator_t) -> xcb_generic_iterator_t #c_call;
    gesture_class_next:                                    #type (i: *xcb_input_gesture_class_iterator_t) -> void #c_call;
    gesture_class_end:                                     #type (i: xcb_input_gesture_class_iterator_t) -> xcb_generic_iterator_t #c_call;
    valuator_class_next:                                   #type (i: *xcb_input_valuator_class_iterator_t) -> void #c_call;
    valuator_class_end:                                    #type (i: xcb_input_valuator_class_iterator_t) -> xcb_generic_iterator_t #c_call;
    device_class_data_key_keys:                            #type (S: *xcb_input_device_class_data_t) -> *u32 #c_call;
    device_class_data_key_keys_length:                     #type (R: *xcb_input_device_class_t, S: *xcb_input_device_class_data_t) -> s32 #c_call;
    device_class_data_key_keys_end:                        #type (R: *xcb_input_device_class_t, S: *xcb_input_device_class_data_t) -> xcb_generic_iterator_t #c_call;
    device_class_data_button_state:                        #type (S: *xcb_input_device_class_data_t) -> *u32 #c_call;
    device_class_data_button_state_length:                 #type (R: *xcb_input_device_class_t, S: *xcb_input_device_class_data_t) -> s32 #c_call;
    device_class_data_button_state_end:                    #type (R: *xcb_input_device_class_t, S: *xcb_input_device_class_data_t) -> xcb_generic_iterator_t #c_call;
    device_class_data_button_labels:                       #type (S: *xcb_input_device_class_data_t) -> *xcb_atom_t #c_call;
    device_class_data_button_labels_length:                #type (R: *xcb_input_device_class_t, S: *xcb_input_device_class_data_t) -> s32 #c_call;
    device_class_data_button_labels_end:                   #type (R: *xcb_input_device_class_t, S: *xcb_input_device_class_data_t) -> xcb_generic_iterator_t #c_call;
    device_class_data_serialize:                           #type (_buffer: **void, type: u16, _aux: *xcb_input_device_class_data_t) -> s32 #c_call;
    device_class_data_unpack:                              #type (_buffer: *void, type: u16, _aux: *xcb_input_device_class_data_t) -> s32 #c_call;
    device_class_data_sizeof:                              #type (_buffer: *void, type: u16) -> s32 #c_call;
    device_class_sizeof:                                   #type (_buffer: *void) -> s32 #c_call;
    device_class_next:                                     #type (i: *xcb_input_device_class_iterator_t) -> void #c_call;
    device_class_end:                                      #type (i: xcb_input_device_class_iterator_t) -> xcb_generic_iterator_t #c_call;
    xi_device_info_sizeof:                                 #type (_buffer: *void) -> s32 #c_call;
    xi_device_info_name:                                   #type (R: *xcb_input_xi_device_info_t) -> *u8 #c_call;
    xi_device_info_name_length:                            #type (R: *xcb_input_xi_device_info_t) -> s32 #c_call;
    xi_device_info_name_end:                               #type (R: *xcb_input_xi_device_info_t) -> xcb_generic_iterator_t #c_call;
    xi_device_info_classes_length:                         #type (R: *xcb_input_xi_device_info_t) -> s32 #c_call;
    xi_device_info_classes_iterator:                       #type (R: *xcb_input_xi_device_info_t) -> xcb_input_device_class_iterator_t #c_call;
    xi_device_info_next:                                   #type (i: *xcb_input_xi_device_info_iterator_t) -> void #c_call;
    xi_device_info_end:                                    #type (i: xcb_input_xi_device_info_iterator_t) -> xcb_generic_iterator_t #c_call;
    xi_query_device_sizeof:                                #type (_buffer: *void) -> s32 #c_call;
    xi_query_device:                                       #type (c: *xcb_connection_t, deviceid: xcb_input_device_id_t) -> xcb_input_xi_query_device_cookie_t #c_call;
    xi_query_device_unchecked:                             #type (c: *xcb_connection_t, deviceid: xcb_input_device_id_t) -> xcb_input_xi_query_device_cookie_t #c_call;
    xi_query_device_infos_length:                          #type (R: *xcb_input_xi_query_device_reply_t) -> s32 #c_call;
    xi_query_device_infos_iterator:                        #type (R: *xcb_input_xi_query_device_reply_t) -> xcb_input_xi_device_info_iterator_t #c_call;
    xi_query_device_reply:                                 #type (c: *xcb_connection_t, cookie: xcb_input_xi_query_device_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_xi_query_device_reply_t #c_call;
    xi_set_focus_checked:                                  #type (c: *xcb_connection_t, window: xcb_window_t, time: xcb_timestamp_t, deviceid: xcb_input_device_id_t) -> xcb_void_cookie_t #c_call;
    xi_set_focus:                                          #type (c: *xcb_connection_t, window: xcb_window_t, time: xcb_timestamp_t, deviceid: xcb_input_device_id_t) -> xcb_void_cookie_t #c_call;
    xi_get_focus:                                          #type (c: *xcb_connection_t, deviceid: xcb_input_device_id_t) -> xcb_input_xi_get_focus_cookie_t #c_call;
    xi_get_focus_unchecked:                                #type (c: *xcb_connection_t, deviceid: xcb_input_device_id_t) -> xcb_input_xi_get_focus_cookie_t #c_call;
    xi_get_focus_reply:                                    #type (c: *xcb_connection_t, cookie: xcb_input_xi_get_focus_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_xi_get_focus_reply_t #c_call;
    xi_grab_device_sizeof:                                 #type (_buffer: *void) -> s32 #c_call;
    xi_grab_device:                                        #type (c: *xcb_connection_t, window: xcb_window_t, time: xcb_timestamp_t, cursor: xcb_cursor_t, deviceid: xcb_input_device_id_t, mode: u8, paired_device_mode: u8, owner_events: u8, mask_len: u16, mask: *u32) -> xcb_input_xi_grab_device_cookie_t #c_call;
    xi_grab_device_unchecked:                              #type (c: *xcb_connection_t, window: xcb_window_t, time: xcb_timestamp_t, cursor: xcb_cursor_t, deviceid: xcb_input_device_id_t, mode: u8, paired_device_mode: u8, owner_events: u8, mask_len: u16, mask: *u32) -> xcb_input_xi_grab_device_cookie_t #c_call;
    xi_grab_device_reply:                                  #type (c: *xcb_connection_t, cookie: xcb_input_xi_grab_device_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_xi_grab_device_reply_t #c_call;
    xi_ungrab_device_checked:                              #type (c: *xcb_connection_t, time: xcb_timestamp_t, deviceid: xcb_input_device_id_t) -> xcb_void_cookie_t #c_call;
    xi_ungrab_device:                                      #type (c: *xcb_connection_t, time: xcb_timestamp_t, deviceid: xcb_input_device_id_t) -> xcb_void_cookie_t #c_call;
    xi_allow_events_checked:                               #type (c: *xcb_connection_t, time: xcb_timestamp_t, deviceid: xcb_input_device_id_t, event_mode: u8, touchid: u32, grab_window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    xi_allow_events:                                       #type (c: *xcb_connection_t, time: xcb_timestamp_t, deviceid: xcb_input_device_id_t, event_mode: u8, touchid: u32, grab_window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    grab_modifier_info_next:                               #type (i: *xcb_input_grab_modifier_info_iterator_t) -> void #c_call;
    grab_modifier_info_end:                                #type (i: xcb_input_grab_modifier_info_iterator_t) -> xcb_generic_iterator_t #c_call;
    xi_passive_grab_device_sizeof:                         #type (_buffer: *void) -> s32 #c_call;
    xi_passive_grab_device:                                #type (c: *xcb_connection_t, time: xcb_timestamp_t, grab_window: xcb_window_t, cursor: xcb_cursor_t, detail: u32, deviceid: xcb_input_device_id_t, num_modifiers: u16, mask_len: u16, grab_type: u8, grab_mode: u8, paired_device_mode: u8, owner_events: u8, mask: *u32, modifiers: *u32) -> xcb_input_xi_passive_grab_device_cookie_t #c_call;
    xi_passive_grab_device_unchecked:                      #type (c: *xcb_connection_t, time: xcb_timestamp_t, grab_window: xcb_window_t, cursor: xcb_cursor_t, detail: u32, deviceid: xcb_input_device_id_t, num_modifiers: u16, mask_len: u16, grab_type: u8, grab_mode: u8, paired_device_mode: u8, owner_events: u8, mask: *u32, modifiers: *u32) -> xcb_input_xi_passive_grab_device_cookie_t #c_call;
    xi_passive_grab_device_modifiers:                      #type (R: *xcb_input_xi_passive_grab_device_reply_t) -> *xcb_input_grab_modifier_info_t #c_call;
    xi_passive_grab_device_modifiers_length:               #type (R: *xcb_input_xi_passive_grab_device_reply_t) -> s32 #c_call;
    xi_passive_grab_device_modifiers_iterator:             #type (R: *xcb_input_xi_passive_grab_device_reply_t) -> xcb_input_grab_modifier_info_iterator_t #c_call;
    xi_passive_grab_device_reply:                          #type (c: *xcb_connection_t, cookie: xcb_input_xi_passive_grab_device_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_xi_passive_grab_device_reply_t #c_call;
    xi_passive_ungrab_device_sizeof:                       #type (_buffer: *void) -> s32 #c_call;
    xi_passive_ungrab_device_checked:                      #type (c: *xcb_connection_t, grab_window: xcb_window_t, detail: u32, deviceid: xcb_input_device_id_t, num_modifiers: u16, grab_type: u8, modifiers: *u32) -> xcb_void_cookie_t #c_call;
    xi_passive_ungrab_device:                              #type (c: *xcb_connection_t, grab_window: xcb_window_t, detail: u32, deviceid: xcb_input_device_id_t, num_modifiers: u16, grab_type: u8, modifiers: *u32) -> xcb_void_cookie_t #c_call;
    xi_passive_ungrab_device_modifiers:                    #type (R: *xcb_input_xi_passive_ungrab_device_request_t) -> *u32 #c_call;
    xi_passive_ungrab_device_modifiers_length:             #type (R: *xcb_input_xi_passive_ungrab_device_request_t) -> s32 #c_call;
    xi_passive_ungrab_device_modifiers_end:                #type (R: *xcb_input_xi_passive_ungrab_device_request_t) -> xcb_generic_iterator_t #c_call;
    xi_list_properties_sizeof:                             #type (_buffer: *void) -> s32 #c_call;
    xi_list_properties:                                    #type (c: *xcb_connection_t, deviceid: xcb_input_device_id_t) -> xcb_input_xi_list_properties_cookie_t #c_call;
    xi_list_properties_unchecked:                          #type (c: *xcb_connection_t, deviceid: xcb_input_device_id_t) -> xcb_input_xi_list_properties_cookie_t #c_call;
    xi_list_properties_properties:                         #type (R: *xcb_input_xi_list_properties_reply_t) -> *xcb_atom_t #c_call;
    xi_list_properties_properties_length:                  #type (R: *xcb_input_xi_list_properties_reply_t) -> s32 #c_call;
    xi_list_properties_properties_end:                     #type (R: *xcb_input_xi_list_properties_reply_t) -> xcb_generic_iterator_t #c_call;
    xi_list_properties_reply:                              #type (c: *xcb_connection_t, cookie: xcb_input_xi_list_properties_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_xi_list_properties_reply_t #c_call;
    xi_change_property_items_data_8:                       #type (S: *xcb_input_xi_change_property_items_t) -> *u8 #c_call;
    xi_change_property_items_data_8_length:                #type (R: *xcb_input_xi_change_property_request_t, S: *xcb_input_xi_change_property_items_t) -> s32 #c_call;
    xi_change_property_items_data_8_end:                   #type (R: *xcb_input_xi_change_property_request_t, S: *xcb_input_xi_change_property_items_t) -> xcb_generic_iterator_t #c_call;
    xi_change_property_items_data_16:                      #type (S: *xcb_input_xi_change_property_items_t) -> *u16 #c_call;
    xi_change_property_items_data_16_length:               #type (R: *xcb_input_xi_change_property_request_t, S: *xcb_input_xi_change_property_items_t) -> s32 #c_call;
    xi_change_property_items_data_16_end:                  #type (R: *xcb_input_xi_change_property_request_t, S: *xcb_input_xi_change_property_items_t) -> xcb_generic_iterator_t #c_call;
    xi_change_property_items_data_32:                      #type (S: *xcb_input_xi_change_property_items_t) -> *u32 #c_call;
    xi_change_property_items_data_32_length:               #type (R: *xcb_input_xi_change_property_request_t, S: *xcb_input_xi_change_property_items_t) -> s32 #c_call;
    xi_change_property_items_data_32_end:                  #type (R: *xcb_input_xi_change_property_request_t, S: *xcb_input_xi_change_property_items_t) -> xcb_generic_iterator_t #c_call;
    xi_change_property_items_serialize:                    #type (_buffer: **void, num_items: u32, format: u8, _aux: *xcb_input_xi_change_property_items_t) -> s32 #c_call;
    xi_change_property_items_unpack:                       #type (_buffer: *void, num_items: u32, format: u8, _aux: *xcb_input_xi_change_property_items_t) -> s32 #c_call;
    xi_change_property_items_sizeof:                       #type (_buffer: *void, num_items: u32, format: u8) -> s32 #c_call;
    xi_change_property_sizeof:                             #type (_buffer: *void) -> s32 #c_call;
    xi_change_property_checked:                            #type (c: *xcb_connection_t, deviceid: xcb_input_device_id_t, mode: u8, format: u8, property: xcb_atom_t, type: xcb_atom_t, num_items: u32, items: *void) -> xcb_void_cookie_t #c_call;
    xi_change_property:                                    #type (c: *xcb_connection_t, deviceid: xcb_input_device_id_t, mode: u8, format: u8, property: xcb_atom_t, type: xcb_atom_t, num_items: u32, items: *void) -> xcb_void_cookie_t #c_call;
    xi_change_property_aux_checked:                        #type (c: *xcb_connection_t, deviceid: xcb_input_device_id_t, mode: u8, format: u8, property: xcb_atom_t, type: xcb_atom_t, num_items: u32, items: *xcb_input_xi_change_property_items_t) -> xcb_void_cookie_t #c_call;
    xi_change_property_aux:                                #type (c: *xcb_connection_t, deviceid: xcb_input_device_id_t, mode: u8, format: u8, property: xcb_atom_t, type: xcb_atom_t, num_items: u32, items: *xcb_input_xi_change_property_items_t) -> xcb_void_cookie_t #c_call;
    xi_change_property_items:                              #type (R: *xcb_input_xi_change_property_request_t) -> *void #c_call;
    xi_delete_property_checked:                            #type (c: *xcb_connection_t, deviceid: xcb_input_device_id_t, property: xcb_atom_t) -> xcb_void_cookie_t #c_call;
    xi_delete_property:                                    #type (c: *xcb_connection_t, deviceid: xcb_input_device_id_t, property: xcb_atom_t) -> xcb_void_cookie_t #c_call;
    xi_get_property_items_data_8:                          #type (S: *xcb_input_xi_get_property_items_t) -> *u8 #c_call;
    xi_get_property_items_data_8_length:                   #type (R: *xcb_input_xi_get_property_reply_t, S: *xcb_input_xi_get_property_items_t) -> s32 #c_call;
    xi_get_property_items_data_8_end:                      #type (R: *xcb_input_xi_get_property_reply_t, S: *xcb_input_xi_get_property_items_t) -> xcb_generic_iterator_t #c_call;
    xi_get_property_items_data_16:                         #type (S: *xcb_input_xi_get_property_items_t) -> *u16 #c_call;
    xi_get_property_items_data_16_length:                  #type (R: *xcb_input_xi_get_property_reply_t, S: *xcb_input_xi_get_property_items_t) -> s32 #c_call;
    xi_get_property_items_data_16_end:                     #type (R: *xcb_input_xi_get_property_reply_t, S: *xcb_input_xi_get_property_items_t) -> xcb_generic_iterator_t #c_call;
    xi_get_property_items_data_32:                         #type (S: *xcb_input_xi_get_property_items_t) -> *u32 #c_call;
    xi_get_property_items_data_32_length:                  #type (R: *xcb_input_xi_get_property_reply_t, S: *xcb_input_xi_get_property_items_t) -> s32 #c_call;
    xi_get_property_items_data_32_end:                     #type (R: *xcb_input_xi_get_property_reply_t, S: *xcb_input_xi_get_property_items_t) -> xcb_generic_iterator_t #c_call;
    xi_get_property_items_serialize:                       #type (_buffer: **void, num_items: u32, format: u8, _aux: *xcb_input_xi_get_property_items_t) -> s32 #c_call;
    xi_get_property_items_unpack:                          #type (_buffer: *void, num_items: u32, format: u8, _aux: *xcb_input_xi_get_property_items_t) -> s32 #c_call;
    xi_get_property_items_sizeof:                          #type (_buffer: *void, num_items: u32, format: u8) -> s32 #c_call;
    xi_get_property_sizeof:                                #type (_buffer: *void) -> s32 #c_call;
    xi_get_property:                                       #type (c: *xcb_connection_t, deviceid: xcb_input_device_id_t, _delete: u8, property: xcb_atom_t, type: xcb_atom_t, offset: u32, len: u32) -> xcb_input_xi_get_property_cookie_t #c_call;
    xi_get_property_unchecked:                             #type (c: *xcb_connection_t, deviceid: xcb_input_device_id_t, _delete: u8, property: xcb_atom_t, type: xcb_atom_t, offset: u32, len: u32) -> xcb_input_xi_get_property_cookie_t #c_call;
    xi_get_property_items:                                 #type (R: *xcb_input_xi_get_property_reply_t) -> *void #c_call;
    xi_get_property_reply:                                 #type (c: *xcb_connection_t, cookie: xcb_input_xi_get_property_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_xi_get_property_reply_t #c_call;
    xi_get_selected_events_sizeof:                         #type (_buffer: *void) -> s32 #c_call;
    xi_get_selected_events:                                #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_input_xi_get_selected_events_cookie_t #c_call;
    xi_get_selected_events_unchecked:                      #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_input_xi_get_selected_events_cookie_t #c_call;
    xi_get_selected_events_masks_length:                   #type (R: *xcb_input_xi_get_selected_events_reply_t) -> s32 #c_call;
    xi_get_selected_events_masks_iterator:                 #type (R: *xcb_input_xi_get_selected_events_reply_t) -> xcb_input_event_mask_iterator_t #c_call;
    xi_get_selected_events_reply:                          #type (c: *xcb_connection_t, cookie: xcb_input_xi_get_selected_events_cookie_t, e: **xcb_generic_error_t) -> *xcb_input_xi_get_selected_events_reply_t #c_call;
    barrier_release_pointer_info_next:                     #type (i: *xcb_input_barrier_release_pointer_info_iterator_t) -> void #c_call;
    barrier_release_pointer_info_end:                      #type (i: xcb_input_barrier_release_pointer_info_iterator_t) -> xcb_generic_iterator_t #c_call;
    xi_barrier_release_pointer_sizeof:                     #type (_buffer: *void) -> s32 #c_call;
    xi_barrier_release_pointer_checked:                    #type (c: *xcb_connection_t, num_barriers: u32, barriers: *xcb_input_barrier_release_pointer_info_t) -> xcb_void_cookie_t #c_call;
    xi_barrier_release_pointer:                            #type (c: *xcb_connection_t, num_barriers: u32, barriers: *xcb_input_barrier_release_pointer_info_t) -> xcb_void_cookie_t #c_call;
    xi_barrier_release_pointer_barriers:                   #type (R: *xcb_input_xi_barrier_release_pointer_request_t) -> *xcb_input_barrier_release_pointer_info_t #c_call;
    xi_barrier_release_pointer_barriers_length:            #type (R: *xcb_input_xi_barrier_release_pointer_request_t) -> s32 #c_call;
    xi_barrier_release_pointer_barriers_iterator:          #type (R: *xcb_input_xi_barrier_release_pointer_request_t) -> xcb_input_barrier_release_pointer_info_iterator_t #c_call;
    device_changed_sizeof:                                 #type (_buffer: *void) -> s32 #c_call;
    device_changed_classes_length:                         #type (R: *xcb_input_device_changed_event_t) -> s32 #c_call;
    device_changed_classes_iterator:                       #type (R: *xcb_input_device_changed_event_t) -> xcb_input_device_class_iterator_t #c_call;
    key_press_sizeof:                                      #type (_buffer: *void) -> s32 #c_call;
    key_press_button_mask:                                 #type (R: *xcb_input_key_press_event_t) -> *u32 #c_call;
    key_press_button_mask_length:                          #type (R: *xcb_input_key_press_event_t) -> s32 #c_call;
    key_press_button_mask_end:                             #type (R: *xcb_input_key_press_event_t) -> xcb_generic_iterator_t #c_call;
    key_press_valuator_mask:                               #type (R: *xcb_input_key_press_event_t) -> *u32 #c_call;
    key_press_valuator_mask_length:                        #type (R: *xcb_input_key_press_event_t) -> s32 #c_call;
    key_press_valuator_mask_end:                           #type (R: *xcb_input_key_press_event_t) -> xcb_generic_iterator_t #c_call;
    key_press_axisvalues:                                  #type (R: *xcb_input_key_press_event_t) -> *xcb_input_fp3232_t #c_call;
    key_press_axisvalues_length:                           #type (R: *xcb_input_key_press_event_t) -> s32 #c_call;
    key_press_axisvalues_iterator:                         #type (R: *xcb_input_key_press_event_t) -> xcb_input_fp3232_iterator_t #c_call;
    key_release_sizeof:                                    #type (_buffer: *void) -> s32 #c_call;
    button_press_sizeof:                                   #type (_buffer: *void) -> s32 #c_call;
    button_press_button_mask:                              #type (R: *xcb_input_button_press_event_t) -> *u32 #c_call;
    button_press_button_mask_length:                       #type (R: *xcb_input_button_press_event_t) -> s32 #c_call;
    button_press_button_mask_end:                          #type (R: *xcb_input_button_press_event_t) -> xcb_generic_iterator_t #c_call;
    button_press_valuator_mask:                            #type (R: *xcb_input_button_press_event_t) -> *u32 #c_call;
    button_press_valuator_mask_length:                     #type (R: *xcb_input_button_press_event_t) -> s32 #c_call;
    button_press_valuator_mask_end:                        #type (R: *xcb_input_button_press_event_t) -> xcb_generic_iterator_t #c_call;
    button_press_axisvalues:                               #type (R: *xcb_input_button_press_event_t) -> *xcb_input_fp3232_t #c_call;
    button_press_axisvalues_length:                        #type (R: *xcb_input_button_press_event_t) -> s32 #c_call;
    button_press_axisvalues_iterator:                      #type (R: *xcb_input_button_press_event_t) -> xcb_input_fp3232_iterator_t #c_call;
    button_release_sizeof:                                 #type (_buffer: *void) -> s32 #c_call;
    motion_sizeof:                                         #type (_buffer: *void) -> s32 #c_call;
    enter_sizeof:                                          #type (_buffer: *void) -> s32 #c_call;
    enter_buttons:                                         #type (R: *xcb_input_enter_event_t) -> *u32 #c_call;
    enter_buttons_length:                                  #type (R: *xcb_input_enter_event_t) -> s32 #c_call;
    enter_buttons_end:                                     #type (R: *xcb_input_enter_event_t) -> xcb_generic_iterator_t #c_call;
    leave_sizeof:                                          #type (_buffer: *void) -> s32 #c_call;
    focus_in_sizeof:                                       #type (_buffer: *void) -> s32 #c_call;
    focus_out_sizeof:                                      #type (_buffer: *void) -> s32 #c_call;
    hierarchy_info_next:                                   #type (i: *xcb_input_hierarchy_info_iterator_t) -> void #c_call;
    hierarchy_info_end:                                    #type (i: xcb_input_hierarchy_info_iterator_t) -> xcb_generic_iterator_t #c_call;
    hierarchy_sizeof:                                      #type (_buffer: *void) -> s32 #c_call;
    hierarchy_infos:                                       #type (R: *xcb_input_hierarchy_event_t) -> *xcb_input_hierarchy_info_t #c_call;
    hierarchy_infos_length:                                #type (R: *xcb_input_hierarchy_event_t) -> s32 #c_call;
    hierarchy_infos_iterator:                              #type (R: *xcb_input_hierarchy_event_t) -> xcb_input_hierarchy_info_iterator_t #c_call;
    raw_key_press_sizeof:                                  #type (_buffer: *void) -> s32 #c_call;
    raw_key_press_valuator_mask:                           #type (R: *xcb_input_raw_key_press_event_t) -> *u32 #c_call;
    raw_key_press_valuator_mask_length:                    #type (R: *xcb_input_raw_key_press_event_t) -> s32 #c_call;
    raw_key_press_valuator_mask_end:                       #type (R: *xcb_input_raw_key_press_event_t) -> xcb_generic_iterator_t #c_call;
    raw_key_press_axisvalues:                              #type (R: *xcb_input_raw_key_press_event_t) -> *xcb_input_fp3232_t #c_call;
    raw_key_press_axisvalues_length:                       #type (R: *xcb_input_raw_key_press_event_t) -> s32 #c_call;
    raw_key_press_axisvalues_iterator:                     #type (R: *xcb_input_raw_key_press_event_t) -> xcb_input_fp3232_iterator_t #c_call;
    raw_key_press_axisvalues_raw:                          #type (R: *xcb_input_raw_key_press_event_t) -> *xcb_input_fp3232_t #c_call;
    raw_key_press_axisvalues_raw_length:                   #type (R: *xcb_input_raw_key_press_event_t) -> s32 #c_call;
    raw_key_press_axisvalues_raw_iterator:                 #type (R: *xcb_input_raw_key_press_event_t) -> xcb_input_fp3232_iterator_t #c_call;
    raw_key_release_sizeof:                                #type (_buffer: *void) -> s32 #c_call;
    raw_button_press_sizeof:                               #type (_buffer: *void) -> s32 #c_call;
    raw_button_press_valuator_mask:                        #type (R: *xcb_input_raw_button_press_event_t) -> *u32 #c_call;
    raw_button_press_valuator_mask_length:                 #type (R: *xcb_input_raw_button_press_event_t) -> s32 #c_call;
    raw_button_press_valuator_mask_end:                    #type (R: *xcb_input_raw_button_press_event_t) -> xcb_generic_iterator_t #c_call;
    raw_button_press_axisvalues:                           #type (R: *xcb_input_raw_button_press_event_t) -> *xcb_input_fp3232_t #c_call;
    raw_button_press_axisvalues_length:                    #type (R: *xcb_input_raw_button_press_event_t) -> s32 #c_call;
    raw_button_press_axisvalues_iterator:                  #type (R: *xcb_input_raw_button_press_event_t) -> xcb_input_fp3232_iterator_t #c_call;
    raw_button_press_axisvalues_raw:                       #type (R: *xcb_input_raw_button_press_event_t) -> *xcb_input_fp3232_t #c_call;
    raw_button_press_axisvalues_raw_length:                #type (R: *xcb_input_raw_button_press_event_t) -> s32 #c_call;
    raw_button_press_axisvalues_raw_iterator:              #type (R: *xcb_input_raw_button_press_event_t) -> xcb_input_fp3232_iterator_t #c_call;
    raw_button_release_sizeof:                             #type (_buffer: *void) -> s32 #c_call;
    raw_motion_sizeof:                                     #type (_buffer: *void) -> s32 #c_call;
    touch_begin_sizeof:                                    #type (_buffer: *void) -> s32 #c_call;
    touch_begin_button_mask:                               #type (R: *xcb_input_touch_begin_event_t) -> *u32 #c_call;
    touch_begin_button_mask_length:                        #type (R: *xcb_input_touch_begin_event_t) -> s32 #c_call;
    touch_begin_button_mask_end:                           #type (R: *xcb_input_touch_begin_event_t) -> xcb_generic_iterator_t #c_call;
    touch_begin_valuator_mask:                             #type (R: *xcb_input_touch_begin_event_t) -> *u32 #c_call;
    touch_begin_valuator_mask_length:                      #type (R: *xcb_input_touch_begin_event_t) -> s32 #c_call;
    touch_begin_valuator_mask_end:                         #type (R: *xcb_input_touch_begin_event_t) -> xcb_generic_iterator_t #c_call;
    touch_begin_axisvalues:                                #type (R: *xcb_input_touch_begin_event_t) -> *xcb_input_fp3232_t #c_call;
    touch_begin_axisvalues_length:                         #type (R: *xcb_input_touch_begin_event_t) -> s32 #c_call;
    touch_begin_axisvalues_iterator:                       #type (R: *xcb_input_touch_begin_event_t) -> xcb_input_fp3232_iterator_t #c_call;
    touch_update_sizeof:                                   #type (_buffer: *void) -> s32 #c_call;
    touch_end_sizeof:                                      #type (_buffer: *void) -> s32 #c_call;
    raw_touch_begin_sizeof:                                #type (_buffer: *void) -> s32 #c_call;
    raw_touch_begin_valuator_mask:                         #type (R: *xcb_input_raw_touch_begin_event_t) -> *u32 #c_call;
    raw_touch_begin_valuator_mask_length:                  #type (R: *xcb_input_raw_touch_begin_event_t) -> s32 #c_call;
    raw_touch_begin_valuator_mask_end:                     #type (R: *xcb_input_raw_touch_begin_event_t) -> xcb_generic_iterator_t #c_call;
    raw_touch_begin_axisvalues:                            #type (R: *xcb_input_raw_touch_begin_event_t) -> *xcb_input_fp3232_t #c_call;
    raw_touch_begin_axisvalues_length:                     #type (R: *xcb_input_raw_touch_begin_event_t) -> s32 #c_call;
    raw_touch_begin_axisvalues_iterator:                   #type (R: *xcb_input_raw_touch_begin_event_t) -> xcb_input_fp3232_iterator_t #c_call;
    raw_touch_begin_axisvalues_raw:                        #type (R: *xcb_input_raw_touch_begin_event_t) -> *xcb_input_fp3232_t #c_call;
    raw_touch_begin_axisvalues_raw_length:                 #type (R: *xcb_input_raw_touch_begin_event_t) -> s32 #c_call;
    raw_touch_begin_axisvalues_raw_iterator:               #type (R: *xcb_input_raw_touch_begin_event_t) -> xcb_input_fp3232_iterator_t #c_call;
    raw_touch_update_sizeof:                               #type (_buffer: *void) -> s32 #c_call;
    raw_touch_end_sizeof:                                  #type (_buffer: *void) -> s32 #c_call;
    event_for_send_next:                                   #type (i: *xcb_input_event_for_send_iterator_t) -> void #c_call;
    event_for_send_end:                                    #type (i: xcb_input_event_for_send_iterator_t) -> xcb_generic_iterator_t #c_call;
    send_extension_event_sizeof:                           #type (_buffer: *void) -> s32 #c_call;
    send_extension_event_checked:                          #type (c: *xcb_connection_t, destination: xcb_window_t, device_id: u8, propagate: u8, num_classes: u16, num_events: u8, events: *xcb_input_event_for_send_t, classes: *xcb_input_event_class_t) -> xcb_void_cookie_t #c_call;
    send_extension_event:                                  #type (c: *xcb_connection_t, destination: xcb_window_t, device_id: u8, propagate: u8, num_classes: u16, num_events: u8, events: *xcb_input_event_for_send_t, classes: *xcb_input_event_class_t) -> xcb_void_cookie_t #c_call;
    send_extension_event_events:                           #type (R: *xcb_input_send_extension_event_request_t) -> *xcb_input_event_for_send_t #c_call;
    send_extension_event_events_length:                    #type (R: *xcb_input_send_extension_event_request_t) -> s32 #c_call;
    send_extension_event_events_iterator:                  #type (R: *xcb_input_send_extension_event_request_t) -> xcb_input_event_for_send_iterator_t #c_call;
    send_extension_event_classes:                          #type (R: *xcb_input_send_extension_event_request_t) -> *xcb_input_event_class_t #c_call;
    send_extension_event_classes_length:                   #type (R: *xcb_input_send_extension_event_request_t) -> s32 #c_call;
    send_extension_event_classes_end:                      #type (R: *xcb_input_send_extension_event_request_t) -> xcb_generic_iterator_t #c_call;
}

#scope_file

