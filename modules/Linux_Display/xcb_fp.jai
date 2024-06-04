//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



X_PROTOCOL :: 11;

X_PROTOCOL_REVISION :: 0;

X_TCP_PORT :: 6000;

XCB_CONN_ERROR :: 1;

XCB_CONN_CLOSED_EXT_NOTSUPPORTED :: 2;

XCB_CONN_CLOSED_MEM_INSUFFICIENT :: 3;

XCB_CONN_CLOSED_REQ_LEN_EXCEED :: 4;

XCB_CONN_CLOSED_PARSE_ERR :: 5;

XCB_CONN_CLOSED_INVALID_SCREEN :: 6;

XCB_CONN_CLOSED_FDPASSING_FAILED :: 7;

XCB_KEY_PRESS :: 2;

XCB_KEY_RELEASE :: 3;

XCB_BUTTON_PRESS :: 4;

XCB_BUTTON_RELEASE :: 5;

XCB_MOTION_NOTIFY :: 6;

XCB_ENTER_NOTIFY :: 7;

XCB_LEAVE_NOTIFY :: 8;

XCB_FOCUS_IN :: 9;

XCB_FOCUS_OUT :: 10;

XCB_KEYMAP_NOTIFY :: 11;

XCB_EXPOSE :: 12;

XCB_GRAPHICS_EXPOSURE :: 13;

XCB_NO_EXPOSURE :: 14;

XCB_VISIBILITY_NOTIFY :: 15;

XCB_CREATE_NOTIFY :: 16;

XCB_DESTROY_NOTIFY :: 17;

XCB_UNMAP_NOTIFY :: 18;

XCB_MAP_NOTIFY :: 19;

XCB_MAP_REQUEST :: 20;

XCB_REPARENT_NOTIFY :: 21;

XCB_CONFIGURE_NOTIFY :: 22;

XCB_CONFIGURE_REQUEST :: 23;

XCB_GRAVITY_NOTIFY :: 24;

XCB_RESIZE_REQUEST :: 25;

XCB_CIRCULATE_NOTIFY :: 26;

XCB_CIRCULATE_REQUEST :: 27;

XCB_PROPERTY_NOTIFY :: 28;

XCB_SELECTION_CLEAR :: 29;

XCB_SELECTION_REQUEST :: 30;

XCB_SELECTION_NOTIFY :: 31;

XCB_COLORMAP_NOTIFY :: 32;

XCB_CLIENT_MESSAGE :: 33;

XCB_MAPPING_NOTIFY :: 34;

XCB_GE_GENERIC :: 35;

XCB_REQUEST :: 1;

XCB_VALUE :: 2;

XCB_WINDOW :: 3;

XCB_PIXMAP :: 4;

XCB_ATOM :: 5;

XCB_CURSOR :: 6;

XCB_FONT :: 7;

XCB_MATCH :: 8;

XCB_DRAWABLE :: 9;

XCB_ACCESS :: 10;

XCB_ALLOC :: 11;

XCB_COLORMAP :: 12;

XCB_G_CONTEXT :: 13;

XCB_ID_CHOICE :: 14;

XCB_NAME :: 15;

XCB_LENGTH :: 16;

XCB_IMPLEMENTATION :: 17;

XCB_CREATE_WINDOW :: 1;

XCB_CHANGE_WINDOW_ATTRIBUTES :: 2;

XCB_GET_WINDOW_ATTRIBUTES :: 3;

XCB_DESTROY_WINDOW :: 4;

XCB_DESTROY_SUBWINDOWS :: 5;

XCB_CHANGE_SAVE_SET :: 6;

XCB_REPARENT_WINDOW :: 7;

XCB_MAP_WINDOW :: 8;

XCB_MAP_SUBWINDOWS :: 9;

XCB_UNMAP_WINDOW :: 10;

XCB_UNMAP_SUBWINDOWS :: 11;

XCB_CONFIGURE_WINDOW :: 12;

XCB_CIRCULATE_WINDOW :: 13;

XCB_GET_GEOMETRY :: 14;

XCB_QUERY_TREE :: 15;

XCB_INTERN_ATOM :: 16;

XCB_GET_ATOM_NAME :: 17;

XCB_CHANGE_PROPERTY :: 18;

XCB_DELETE_PROPERTY :: 19;

XCB_GET_PROPERTY :: 20;

XCB_LIST_PROPERTIES :: 21;

XCB_SET_SELECTION_OWNER :: 22;

XCB_GET_SELECTION_OWNER :: 23;

XCB_CONVERT_SELECTION :: 24;

XCB_SEND_EVENT :: 25;

XCB_GRAB_POINTER :: 26;

XCB_UNGRAB_POINTER :: 27;

XCB_GRAB_BUTTON :: 28;

XCB_UNGRAB_BUTTON :: 29;

XCB_CHANGE_ACTIVE_POINTER_GRAB :: 30;

XCB_GRAB_KEYBOARD :: 31;

XCB_UNGRAB_KEYBOARD :: 32;

XCB_GRAB_KEY :: 33;

XCB_UNGRAB_KEY :: 34;

XCB_ALLOW_EVENTS :: 35;

XCB_GRAB_SERVER :: 36;

XCB_UNGRAB_SERVER :: 37;

XCB_QUERY_POINTER :: 38;

XCB_GET_MOTION_EVENTS :: 39;

XCB_TRANSLATE_COORDINATES :: 40;

XCB_WARP_POINTER :: 41;

XCB_SET_INPUT_FOCUS :: 42;

XCB_GET_INPUT_FOCUS :: 43;

XCB_QUERY_KEYMAP :: 44;

XCB_OPEN_FONT :: 45;

XCB_CLOSE_FONT :: 46;

XCB_QUERY_FONT :: 47;

XCB_QUERY_TEXT_EXTENTS :: 48;

XCB_LIST_FONTS :: 49;

XCB_LIST_FONTS_WITH_INFO :: 50;

XCB_SET_FONT_PATH :: 51;

XCB_GET_FONT_PATH :: 52;

XCB_CREATE_PIXMAP :: 53;

XCB_FREE_PIXMAP :: 54;

XCB_CREATE_GC :: 55;

XCB_CHANGE_GC :: 56;

XCB_COPY_GC :: 57;

XCB_SET_DASHES :: 58;

XCB_SET_CLIP_RECTANGLES :: 59;

XCB_FREE_GC :: 60;

XCB_CLEAR_AREA :: 61;

XCB_COPY_AREA :: 62;

XCB_COPY_PLANE :: 63;

XCB_POLY_POINT :: 64;

XCB_POLY_LINE :: 65;

XCB_POLY_SEGMENT :: 66;

XCB_POLY_RECTANGLE :: 67;

XCB_POLY_ARC :: 68;

XCB_FILL_POLY :: 69;

XCB_POLY_FILL_RECTANGLE :: 70;

XCB_POLY_FILL_ARC :: 71;

XCB_PUT_IMAGE :: 72;

XCB_GET_IMAGE :: 73;

XCB_POLY_TEXT_8 :: 74;

XCB_POLY_TEXT_16 :: 75;

XCB_IMAGE_TEXT_8 :: 76;

XCB_IMAGE_TEXT_16 :: 77;

XCB_CREATE_COLORMAP :: 78;

XCB_FREE_COLORMAP :: 79;

XCB_COPY_COLORMAP_AND_FREE :: 80;

XCB_INSTALL_COLORMAP :: 81;

XCB_UNINSTALL_COLORMAP :: 82;

XCB_LIST_INSTALLED_COLORMAPS :: 83;

XCB_ALLOC_COLOR :: 84;

XCB_ALLOC_NAMED_COLOR :: 85;

XCB_ALLOC_COLOR_CELLS :: 86;

XCB_ALLOC_COLOR_PLANES :: 87;

XCB_FREE_COLORS :: 88;

XCB_STORE_COLORS :: 89;

XCB_STORE_NAMED_COLOR :: 90;

XCB_QUERY_COLORS :: 91;

XCB_LOOKUP_COLOR :: 92;

XCB_CREATE_CURSOR :: 93;

XCB_CREATE_GLYPH_CURSOR :: 94;

XCB_FREE_CURSOR :: 95;

XCB_RECOLOR_CURSOR :: 96;

XCB_QUERY_BEST_SIZE :: 97;

XCB_QUERY_EXTENSION :: 98;

XCB_LIST_EXTENSIONS :: 99;

XCB_CHANGE_KEYBOARD_MAPPING :: 100;

XCB_GET_KEYBOARD_MAPPING :: 101;

XCB_CHANGE_KEYBOARD_CONTROL :: 102;

XCB_GET_KEYBOARD_CONTROL :: 103;

XCB_BELL :: 104;

XCB_CHANGE_POINTER_CONTROL :: 105;

XCB_GET_POINTER_CONTROL :: 106;

XCB_SET_SCREEN_SAVER :: 107;

XCB_GET_SCREEN_SAVER :: 108;

XCB_CHANGE_HOSTS :: 109;

XCB_LIST_HOSTS :: 110;

XCB_SET_ACCESS_CONTROL :: 111;

XCB_SET_CLOSE_DOWN_MODE :: 112;

XCB_KILL_CLIENT :: 113;

XCB_ROTATE_PROPERTIES :: 114;

XCB_FORCE_SCREEN_SAVER :: 115;

XCB_SET_POINTER_MAPPING :: 116;

XCB_GET_POINTER_MAPPING :: 117;

XCB_SET_MODIFIER_MAPPING :: 118;

XCB_GET_MODIFIER_MAPPING :: 119;

XCB_NO_OPERATION :: 127;

XCB_NONE :: 0;

XCB_COPY_FROM_PARENT :: 0;

XCB_CURRENT_TIME :: 0;

XCB_NO_SYMBOL :: 0;

xcb_connection_t :: struct {}

xcb_generic_iterator_t :: struct {
    data:  *void;
    rem:   s32;
    index: s32;
}

xcb_generic_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
}

xcb_generic_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    pad:           [7] u32;
    full_sequence: u32;
}

xcb_raw_generic_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    pad:           [7] u32;
}

xcb_ge_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    event_type:    u16;
    pad1:          u16;
    pad:           [5] u32;
    full_sequence: u32;
}

xcb_generic_error_t :: struct {
    response_type: u8;
    error_code:    u8;
    sequence:      u16;
    resource_id:   u32;
    minor_code:    u16;
    major_code:    u8;
    pad0:          u8;
    pad:           [5] u32;
    full_sequence: u32;
}

xcb_void_cookie_t :: struct {
    sequence: u32;
}

xcb_char2b_t :: struct {
    byte1: u8;
    byte2: u8;
}

xcb_char2b_iterator_t :: struct {
    data:  *xcb_char2b_t;
    rem:   s32;
    index: s32;
}

xcb_window_t :: u32;

xcb_window_iterator_t :: struct {
    data:  *xcb_window_t;
    rem:   s32;
    index: s32;
}

xcb_pixmap_t :: u32;

xcb_pixmap_iterator_t :: struct {
    data:  *xcb_pixmap_t;
    rem:   s32;
    index: s32;
}

xcb_cursor_t :: u32;

xcb_cursor_iterator_t :: struct {
    data:  *xcb_cursor_t;
    rem:   s32;
    index: s32;
}

xcb_font_t :: u32;

xcb_font_iterator_t :: struct {
    data:  *xcb_font_t;
    rem:   s32;
    index: s32;
}

xcb_gcontext_t :: u32;

xcb_gcontext_iterator_t :: struct {
    data:  *xcb_gcontext_t;
    rem:   s32;
    index: s32;
}

xcb_colormap_t :: u32;

xcb_colormap_iterator_t :: struct {
    data:  *xcb_colormap_t;
    rem:   s32;
    index: s32;
}

xcb_atom_t :: u32;

xcb_atom_iterator_t :: struct {
    data:  *xcb_atom_t;
    rem:   s32;
    index: s32;
}

xcb_drawable_t :: u32;

xcb_drawable_iterator_t :: struct {
    data:  *xcb_drawable_t;
    rem:   s32;
    index: s32;
}

xcb_fontable_t :: u32;

xcb_fontable_iterator_t :: struct {
    data:  *xcb_fontable_t;
    rem:   s32;
    index: s32;
}

xcb_bool32_t :: u32;

xcb_bool32_iterator_t :: struct {
    data:  *xcb_bool32_t;
    rem:   s32;
    index: s32;
}

xcb_visualid_t :: u32;

xcb_visualid_iterator_t :: struct {
    data:  *xcb_visualid_t;
    rem:   s32;
    index: s32;
}

xcb_timestamp_t :: u32;

xcb_timestamp_iterator_t :: struct {
    data:  *xcb_timestamp_t;
    rem:   s32;
    index: s32;
}

xcb_keysym_t :: u32;

xcb_keysym_iterator_t :: struct {
    data:  *xcb_keysym_t;
    rem:   s32;
    index: s32;
}

xcb_keycode_t :: u8;

xcb_keycode_iterator_t :: struct {
    data:  *xcb_keycode_t;
    rem:   s32;
    index: s32;
}

xcb_keycode32_t :: u32;

xcb_keycode32_iterator_t :: struct {
    data:  *xcb_keycode32_t;
    rem:   s32;
    index: s32;
}

xcb_button_t :: u8;

xcb_button_iterator_t :: struct {
    data:  *xcb_button_t;
    rem:   s32;
    index: s32;
}

xcb_point_t :: struct {
    x: s16;
    y: s16;
}

xcb_point_iterator_t :: struct {
    data:  *xcb_point_t;
    rem:   s32;
    index: s32;
}

xcb_rectangle_t :: struct {
    x:      s16;
    y:      s16;
    width:  u16;
    height: u16;
}

xcb_rectangle_iterator_t :: struct {
    data:  *xcb_rectangle_t;
    rem:   s32;
    index: s32;
}

xcb_arc_t :: struct {
    x:      s16;
    y:      s16;
    width:  u16;
    height: u16;
    angle1: s16;
    angle2: s16;
}

xcb_arc_iterator_t :: struct {
    data:  *xcb_arc_t;
    rem:   s32;
    index: s32;
}

xcb_format_t :: struct {
    depth:          u8;
    bits_per_pixel: u8;
    scanline_pad:   u8;
    pad0:           [5] u8;
}

xcb_format_iterator_t :: struct {
    data:  *xcb_format_t;
    rem:   s32;
    index: s32;
}

xcb_visual_class_t :: enum u32 {
    STATIC_GRAY  :: 0;
    GRAY_SCALE   :: 1;
    STATIC_COLOR :: 2;
    PSEUDO_COLOR :: 3;
    TRUE_COLOR   :: 4;
    DIRECT_COLOR :: 5;

    XCB_VISUAL_CLASS_STATIC_GRAY  :: STATIC_GRAY;
    XCB_VISUAL_CLASS_GRAY_SCALE   :: GRAY_SCALE;
    XCB_VISUAL_CLASS_STATIC_COLOR :: STATIC_COLOR;
    XCB_VISUAL_CLASS_PSEUDO_COLOR :: PSEUDO_COLOR;
    XCB_VISUAL_CLASS_TRUE_COLOR   :: TRUE_COLOR;
    XCB_VISUAL_CLASS_DIRECT_COLOR :: DIRECT_COLOR;
}

xcb_visualtype_t :: struct {
    visual_id:          xcb_visualid_t;
    _class:             u8;
    bits_per_rgb_value: u8;
    colormap_entries:   u16;
    red_mask:           u32;
    green_mask:         u32;
    blue_mask:          u32;
    pad0:               [4] u8;
}

xcb_visualtype_iterator_t :: struct {
    data:  *xcb_visualtype_t;
    rem:   s32;
    index: s32;
}

xcb_depth_t :: struct {
    depth:       u8;
    pad0:        u8;
    visuals_len: u16;
    pad1:        [4] u8;
}

xcb_depth_iterator_t :: struct {
    data:  *xcb_depth_t;
    rem:   s32;
    index: s32;
}

xcb_event_mask_t :: enum u32 {
    NO_EVENT              :: 0;
    KEY_PRESS             :: 1;
    KEY_RELEASE           :: 2;
    BUTTON_PRESS          :: 4;
    BUTTON_RELEASE        :: 8;
    ENTER_WINDOW          :: 16;
    LEAVE_WINDOW          :: 32;
    POINTER_MOTION        :: 64;
    POINTER_MOTION_HINT   :: 128;
    BUTTON_1_MOTION       :: 256;
    BUTTON_2_MOTION       :: 512;
    BUTTON_3_MOTION       :: 1024;
    BUTTON_4_MOTION       :: 2048;
    BUTTON_5_MOTION       :: 4096;
    BUTTON_MOTION         :: 8192;
    KEYMAP_STATE          :: 16384;
    EXPOSURE              :: 32768;
    VISIBILITY_CHANGE     :: 65536;
    STRUCTURE_NOTIFY      :: 131072;
    RESIZE_REDIRECT       :: 262144;
    SUBSTRUCTURE_NOTIFY   :: 524288;
    SUBSTRUCTURE_REDIRECT :: 1048576;
    FOCUS_CHANGE          :: 2097152;
    PROPERTY_CHANGE       :: 4194304;
    COLOR_MAP_CHANGE      :: 8388608;
    OWNER_GRAB_BUTTON     :: 16777216;

    XCB_EVENT_MASK_NO_EVENT              :: NO_EVENT;
    XCB_EVENT_MASK_KEY_PRESS             :: KEY_PRESS;
    XCB_EVENT_MASK_KEY_RELEASE           :: KEY_RELEASE;
    XCB_EVENT_MASK_BUTTON_PRESS          :: BUTTON_PRESS;
    XCB_EVENT_MASK_BUTTON_RELEASE        :: BUTTON_RELEASE;
    XCB_EVENT_MASK_ENTER_WINDOW          :: ENTER_WINDOW;
    XCB_EVENT_MASK_LEAVE_WINDOW          :: LEAVE_WINDOW;
    XCB_EVENT_MASK_POINTER_MOTION        :: POINTER_MOTION;
    XCB_EVENT_MASK_POINTER_MOTION_HINT   :: POINTER_MOTION_HINT;
    XCB_EVENT_MASK_BUTTON_1_MOTION       :: BUTTON_1_MOTION;
    XCB_EVENT_MASK_BUTTON_2_MOTION       :: BUTTON_2_MOTION;
    XCB_EVENT_MASK_BUTTON_3_MOTION       :: BUTTON_3_MOTION;
    XCB_EVENT_MASK_BUTTON_4_MOTION       :: BUTTON_4_MOTION;
    XCB_EVENT_MASK_BUTTON_5_MOTION       :: BUTTON_5_MOTION;
    XCB_EVENT_MASK_BUTTON_MOTION         :: BUTTON_MOTION;
    XCB_EVENT_MASK_KEYMAP_STATE          :: KEYMAP_STATE;
    XCB_EVENT_MASK_EXPOSURE              :: EXPOSURE;
    XCB_EVENT_MASK_VISIBILITY_CHANGE     :: VISIBILITY_CHANGE;
    XCB_EVENT_MASK_STRUCTURE_NOTIFY      :: STRUCTURE_NOTIFY;
    XCB_EVENT_MASK_RESIZE_REDIRECT       :: RESIZE_REDIRECT;
    XCB_EVENT_MASK_SUBSTRUCTURE_NOTIFY   :: SUBSTRUCTURE_NOTIFY;
    XCB_EVENT_MASK_SUBSTRUCTURE_REDIRECT :: SUBSTRUCTURE_REDIRECT;
    XCB_EVENT_MASK_FOCUS_CHANGE          :: FOCUS_CHANGE;
    XCB_EVENT_MASK_PROPERTY_CHANGE       :: PROPERTY_CHANGE;
    XCB_EVENT_MASK_COLOR_MAP_CHANGE      :: COLOR_MAP_CHANGE;
    XCB_EVENT_MASK_OWNER_GRAB_BUTTON     :: OWNER_GRAB_BUTTON;
}

xcb_backing_store_t :: enum u32 {
    NOT_USEFUL  :: 0;
    WHEN_MAPPED :: 1;
    ALWAYS      :: 2;

    XCB_BACKING_STORE_NOT_USEFUL  :: NOT_USEFUL;
    XCB_BACKING_STORE_WHEN_MAPPED :: WHEN_MAPPED;
    XCB_BACKING_STORE_ALWAYS      :: ALWAYS;
}

xcb_screen_t :: struct {
    root:                  xcb_window_t;
    default_colormap:      xcb_colormap_t;
    white_pixel:           u32;
    black_pixel:           u32;
    current_input_masks:   u32;
    width_in_pixels:       u16;
    height_in_pixels:      u16;
    width_in_millimeters:  u16;
    height_in_millimeters: u16;
    min_installed_maps:    u16;
    max_installed_maps:    u16;
    root_visual:           xcb_visualid_t;
    backing_stores:        u8;
    save_unders:           u8;
    root_depth:            u8;
    allowed_depths_len:    u8;
}

xcb_screen_iterator_t :: struct {
    data:  *xcb_screen_t;
    rem:   s32;
    index: s32;
}

xcb_setup_request_t :: struct {
    byte_order:                      u8;
    pad0:                            u8;
    protocol_major_version:          u16;
    protocol_minor_version:          u16;
    authorization_protocol_name_len: u16;
    authorization_protocol_data_len: u16;
    pad1:                            [2] u8;
}

xcb_setup_request_iterator_t :: struct {
    data:  *xcb_setup_request_t;
    rem:   s32;
    index: s32;
}

xcb_setup_failed_t :: struct {
    status:                 u8;
    reason_len:             u8;
    protocol_major_version: u16;
    protocol_minor_version: u16;
    length:                 u16;
}

xcb_setup_failed_iterator_t :: struct {
    data:  *xcb_setup_failed_t;
    rem:   s32;
    index: s32;
}

xcb_setup_authenticate_t :: struct {
    status: u8;
    pad0:   [5] u8;
    length: u16;
}

xcb_setup_authenticate_iterator_t :: struct {
    data:  *xcb_setup_authenticate_t;
    rem:   s32;
    index: s32;
}

xcb_image_order_t :: enum u8 {
    LSB_FIRST :: 0;
    MSB_FIRST :: 1;

    XCB_IMAGE_ORDER_LSB_FIRST :: LSB_FIRST;
    XCB_IMAGE_ORDER_MSB_FIRST :: MSB_FIRST;
}

xcb_setup_t :: struct {
    status:                      u8;
    pad0:                        u8;
    protocol_major_version:      u16;
    protocol_minor_version:      u16;
    length:                      u16;
    release_number:              u32;
    resource_id_base:            u32;
    resource_id_mask:            u32;
    motion_buffer_size:          u32;
    vendor_len:                  u16;
    maximum_request_length:      u16;
    roots_len:                   u8;
    pixmap_formats_len:          u8;
    image_byte_order:            xcb_image_order_t;
    bitmap_format_bit_order:     u8;
    bitmap_format_scanline_unit: u8;
    bitmap_format_scanline_pad:  u8;
    min_keycode:                 xcb_keycode_t;
    max_keycode:                 xcb_keycode_t;
    pad1:                        [4] u8;
}

xcb_setup_iterator_t :: struct {
    data:  *xcb_setup_t;
    rem:   s32;
    index: s32;
}

xcb_mod_mask_t :: enum u32 {
    SHIFT   :: 1;
    LOCK    :: 2;
    CONTROL :: 4;
    _1      :: 8;
    _2      :: 16;
    _3      :: 32;
    _4      :: 64;
    _5      :: 128;
    ANY     :: 32768;

    XCB_MOD_MASK_SHIFT   :: SHIFT;
    XCB_MOD_MASK_LOCK    :: LOCK;
    XCB_MOD_MASK_CONTROL :: CONTROL;
    XCB_MOD_MASK_1       :: _1;
    XCB_MOD_MASK_2       :: _2;
    XCB_MOD_MASK_3       :: _3;
    XCB_MOD_MASK_4       :: _4;
    XCB_MOD_MASK_5       :: _5;
    XCB_MOD_MASK_ANY     :: ANY;
}

xcb_key_but_mask_t :: enum u32 {
    SHIFT    :: 1;
    LOCK     :: 2;
    CONTROL  :: 4;
    MOD_1    :: 8;
    MOD_2    :: 16;
    MOD_3    :: 32;
    MOD_4    :: 64;
    MOD_5    :: 128;
    BUTTON_1 :: 256;
    BUTTON_2 :: 512;
    BUTTON_3 :: 1024;
    BUTTON_4 :: 2048;
    BUTTON_5 :: 4096;

    XCB_KEY_BUT_MASK_SHIFT    :: SHIFT;
    XCB_KEY_BUT_MASK_LOCK     :: LOCK;
    XCB_KEY_BUT_MASK_CONTROL  :: CONTROL;
    XCB_KEY_BUT_MASK_MOD_1    :: MOD_1;
    XCB_KEY_BUT_MASK_MOD_2    :: MOD_2;
    XCB_KEY_BUT_MASK_MOD_3    :: MOD_3;
    XCB_KEY_BUT_MASK_MOD_4    :: MOD_4;
    XCB_KEY_BUT_MASK_MOD_5    :: MOD_5;
    XCB_KEY_BUT_MASK_BUTTON_1 :: BUTTON_1;
    XCB_KEY_BUT_MASK_BUTTON_2 :: BUTTON_2;
    XCB_KEY_BUT_MASK_BUTTON_3 :: BUTTON_3;
    XCB_KEY_BUT_MASK_BUTTON_4 :: BUTTON_4;
    XCB_KEY_BUT_MASK_BUTTON_5 :: BUTTON_5;
}

xcb_window_enum_t :: enum u32 {
    XCB_WINDOW_NONE :: 0;
}

xcb_key_press_event_t :: struct {
    response_type: u8;
    detail:        xcb_keycode_t;
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
    pad0:          u8;
}

xcb_key_release_event_t :: xcb_key_press_event_t;

xcb_button_mask_t :: enum u32 {
    _1  :: 256;
    _2  :: 512;
    _3  :: 1024;
    _4  :: 2048;
    _5  :: 4096;
    ANY :: 32768;

    XCB_BUTTON_MASK_1   :: _1;
    XCB_BUTTON_MASK_2   :: _2;
    XCB_BUTTON_MASK_3   :: _3;
    XCB_BUTTON_MASK_4   :: _4;
    XCB_BUTTON_MASK_5   :: _5;
    XCB_BUTTON_MASK_ANY :: ANY;
}

xcb_button_press_event_t :: struct {
    response_type: u8;
    detail:        xcb_button_t;
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
    pad0:          u8;
}

xcb_button_release_event_t :: xcb_button_press_event_t;

xcb_motion_t :: enum u32 {
    NORMAL :: 0;
    HINT   :: 1;

    XCB_MOTION_NORMAL :: NORMAL;
    XCB_MOTION_HINT   :: HINT;
}

xcb_motion_notify_event_t :: struct {
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
    pad0:          u8;
}

xcb_notify_detail_t :: enum u32 {
    ANCESTOR          :: 0;
    VIRTUAL           :: 1;
    INFERIOR          :: 2;
    NONLINEAR         :: 3;
    NONLINEAR_VIRTUAL :: 4;
    POINTER           :: 5;
    POINTER_ROOT      :: 6;
    NONE              :: 7;

    XCB_NOTIFY_DETAIL_ANCESTOR          :: ANCESTOR;
    XCB_NOTIFY_DETAIL_VIRTUAL           :: VIRTUAL;
    XCB_NOTIFY_DETAIL_INFERIOR          :: INFERIOR;
    XCB_NOTIFY_DETAIL_NONLINEAR         :: NONLINEAR;
    XCB_NOTIFY_DETAIL_NONLINEAR_VIRTUAL :: NONLINEAR_VIRTUAL;
    XCB_NOTIFY_DETAIL_POINTER           :: POINTER;
    XCB_NOTIFY_DETAIL_POINTER_ROOT      :: POINTER_ROOT;
    XCB_NOTIFY_DETAIL_NONE              :: NONE;
}

xcb_notify_mode_t :: enum u32 {
    NORMAL        :: 0;
    GRAB          :: 1;
    UNGRAB        :: 2;
    WHILE_GRABBED :: 3;

    XCB_NOTIFY_MODE_NORMAL        :: NORMAL;
    XCB_NOTIFY_MODE_GRAB          :: GRAB;
    XCB_NOTIFY_MODE_UNGRAB        :: UNGRAB;
    XCB_NOTIFY_MODE_WHILE_GRABBED :: WHILE_GRABBED;
}

xcb_enter_notify_event_t :: struct {
    response_type:     u8;
    detail:            u8;
    sequence:          u16;
    time:              xcb_timestamp_t;
    root:              xcb_window_t;
    event:             xcb_window_t;
    child:             xcb_window_t;
    root_x:            s16;
    root_y:            s16;
    event_x:           s16;
    event_y:           s16;
    state:             u16;
    mode:              u8;
    same_screen_focus: u8;
}

xcb_leave_notify_event_t :: xcb_enter_notify_event_t;

xcb_focus_in_event_t :: struct {
    response_type: u8;
    detail:        u8;
    sequence:      u16;
    event:         xcb_window_t;
    mode:          u8;
    pad0:          [3] u8;
}

xcb_focus_out_event_t :: xcb_focus_in_event_t;

xcb_keymap_notify_event_t :: struct {
    response_type: u8;
    keys:          [31] u8;
}

xcb_expose_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    window:        xcb_window_t;
    x:             u16;
    y:             u16;
    width:         u16;
    height:        u16;
    count:         u16;
    pad1:          [2] u8;
}

xcb_graphics_exposure_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    drawable:      xcb_drawable_t;
    x:             u16;
    y:             u16;
    width:         u16;
    height:        u16;
    minor_opcode:  u16;
    count:         u16;
    major_opcode:  u8;
    pad1:          [3] u8;
}

xcb_no_exposure_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    drawable:      xcb_drawable_t;
    minor_opcode:  u16;
    major_opcode:  u8;
    pad1:          u8;
}

xcb_visibility_t :: enum u32 {
    UNOBSCURED         :: 0;
    PARTIALLY_OBSCURED :: 1;
    FULLY_OBSCURED     :: 2;

    XCB_VISIBILITY_UNOBSCURED         :: UNOBSCURED;
    XCB_VISIBILITY_PARTIALLY_OBSCURED :: PARTIALLY_OBSCURED;
    XCB_VISIBILITY_FULLY_OBSCURED     :: FULLY_OBSCURED;
}

xcb_visibility_notify_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    window:        xcb_window_t;
    state:         u8;
    pad1:          [3] u8;
}

xcb_create_notify_event_t :: struct {
    response_type:     u8;
    pad0:              u8;
    sequence:          u16;
    parent:            xcb_window_t;
    window:            xcb_window_t;
    x:                 s16;
    y:                 s16;
    width:             u16;
    height:            u16;
    border_width:      u16;
    override_redirect: u8;
    pad1:              u8;
}

xcb_destroy_notify_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    event:         xcb_window_t;
    window:        xcb_window_t;
}

xcb_unmap_notify_event_t :: struct {
    response_type:  u8;
    pad0:           u8;
    sequence:       u16;
    event:          xcb_window_t;
    window:         xcb_window_t;
    from_configure: u8;
    pad1:           [3] u8;
}

xcb_map_notify_event_t :: struct {
    response_type:     u8;
    pad0:              u8;
    sequence:          u16;
    event:             xcb_window_t;
    window:            xcb_window_t;
    override_redirect: u8;
    pad1:              [3] u8;
}

xcb_map_request_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    parent:        xcb_window_t;
    window:        xcb_window_t;
}

xcb_reparent_notify_event_t :: struct {
    response_type:     u8;
    pad0:              u8;
    sequence:          u16;
    event:             xcb_window_t;
    window:            xcb_window_t;
    parent:            xcb_window_t;
    x:                 s16;
    y:                 s16;
    override_redirect: u8;
    pad1:              [3] u8;
}

xcb_configure_notify_event_t :: struct {
    response_type:     u8;
    pad0:              u8;
    sequence:          u16;
    event:             xcb_window_t;
    window:            xcb_window_t;
    above_sibling:     xcb_window_t;
    x:                 s16;
    y:                 s16;
    width:             u16;
    height:            u16;
    border_width:      u16;
    override_redirect: u8;
    pad1:              u8;
}

xcb_configure_request_event_t :: struct {
    response_type: u8;
    stack_mode:    u8;
    sequence:      u16;
    parent:        xcb_window_t;
    window:        xcb_window_t;
    sibling:       xcb_window_t;
    x:             s16;
    y:             s16;
    width:         u16;
    height:        u16;
    border_width:  u16;
    value_mask:    u16;
}

xcb_gravity_notify_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    event:         xcb_window_t;
    window:        xcb_window_t;
    x:             s16;
    y:             s16;
}

xcb_resize_request_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    window:        xcb_window_t;
    width:         u16;
    height:        u16;
}

xcb_place_t :: enum u32 {
    TOP    :: 0;
    BOTTOM :: 1;

    XCB_PLACE_ON_TOP    :: TOP;
    XCB_PLACE_ON_BOTTOM :: BOTTOM;
}

xcb_circulate_notify_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    event:         xcb_window_t;
    window:        xcb_window_t;
    pad1:          [4] u8;
    place:         u8;
    pad2:          [3] u8;
}

xcb_circulate_request_event_t :: xcb_circulate_notify_event_t;

xcb_property_t :: enum u32 {
    NEW_VALUE :: 0;
    DELETE    :: 1;

    XCB_PROPERTY_NEW_VALUE :: NEW_VALUE;
    XCB_PROPERTY_DELETE    :: DELETE;
}

xcb_property_notify_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    window:        xcb_window_t;
    atom:          xcb_atom_t;
    time:          xcb_timestamp_t;
    state:         u8;
    pad1:          [3] u8;
}

xcb_selection_clear_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    owner:         xcb_window_t;
    selection:     xcb_atom_t;
}

xcb_time_t :: enum u32 {
    XCB_TIME_CURRENT_TIME :: 0;
}

xcb_atom_enum_t :: enum u32 {
    NONE                :: 0;
    ANY                 :: 0;
    PRIMARY             :: 1;
    SECONDARY           :: 2;
    ARC                 :: 3;
    ATOM                :: 4;
    BITMAP              :: 5;
    CARDINAL            :: 6;
    COLORMAP            :: 7;
    CURSOR              :: 8;
    CUT_BUFFER0         :: 9;
    CUT_BUFFER1         :: 10;
    CUT_BUFFER2         :: 11;
    CUT_BUFFER3         :: 12;
    CUT_BUFFER4         :: 13;
    CUT_BUFFER5         :: 14;
    CUT_BUFFER6         :: 15;
    CUT_BUFFER7         :: 16;
    DRAWABLE            :: 17;
    FONT                :: 18;
    INTEGER             :: 19;
    PIXMAP              :: 20;
    POINT               :: 21;
    RECTANGLE           :: 22;
    RESOURCE_MANAGER    :: 23;
    RGB_COLOR_MAP       :: 24;
    RGB_BEST_MAP        :: 25;
    RGB_BLUE_MAP        :: 26;
    RGB_DEFAULT_MAP     :: 27;
    RGB_GRAY_MAP        :: 28;
    RGB_GREEN_MAP       :: 29;
    RGB_RED_MAP         :: 30;
    STRING              :: 31;
    VISUALID            :: 32;
    WINDOW              :: 33;
    WM_COMMAND          :: 34;
    WM_HINTS            :: 35;
    WM_CLIENT_MACHINE   :: 36;
    WM_ICON_NAME        :: 37;
    WM_ICON_SIZE        :: 38;
    WM_NAME             :: 39;
    WM_NORMAL_HINTS     :: 40;
    WM_SIZE_HINTS       :: 41;
    WM_ZOOM_HINTS       :: 42;
    MIN_SPACE           :: 43;
    NORM_SPACE          :: 44;
    MAX_SPACE           :: 45;
    END_SPACE           :: 46;
    SUPERSCRIPT_X       :: 47;
    SUPERSCRIPT_Y       :: 48;
    SUBSCRIPT_X         :: 49;
    SUBSCRIPT_Y         :: 50;
    UNDERLINE_POSITION  :: 51;
    UNDERLINE_THICKNESS :: 52;
    STRIKEOUT_ASCENT    :: 53;
    STRIKEOUT_DESCENT   :: 54;
    ITALIC_ANGLE        :: 55;
    X_HEIGHT            :: 56;
    QUAD_WIDTH          :: 57;
    WEIGHT              :: 58;
    POINT_SIZE          :: 59;
    RESOLUTION          :: 60;
    COPYRIGHT           :: 61;
    NOTICE              :: 62;
    FONT_NAME           :: 63;
    FAMILY_NAME         :: 64;
    FULL_NAME           :: 65;
    CAP_HEIGHT          :: 66;
    WM_CLASS            :: 67;
    WM_TRANSIENT_FOR    :: 68;

    XCB_ATOM_NONE                :: NONE;
    XCB_ATOM_ANY                 :: ANY;
    XCB_ATOM_PRIMARY             :: PRIMARY;
    XCB_ATOM_SECONDARY           :: SECONDARY;
    XCB_ATOM_ARC                 :: ARC;
    XCB_ATOM_ATOM                :: ATOM;
    XCB_ATOM_BITMAP              :: BITMAP;
    XCB_ATOM_CARDINAL            :: CARDINAL;
    XCB_ATOM_COLORMAP            :: COLORMAP;
    XCB_ATOM_CURSOR              :: CURSOR;
    XCB_ATOM_CUT_BUFFER0         :: CUT_BUFFER0;
    XCB_ATOM_CUT_BUFFER1         :: CUT_BUFFER1;
    XCB_ATOM_CUT_BUFFER2         :: CUT_BUFFER2;
    XCB_ATOM_CUT_BUFFER3         :: CUT_BUFFER3;
    XCB_ATOM_CUT_BUFFER4         :: CUT_BUFFER4;
    XCB_ATOM_CUT_BUFFER5         :: CUT_BUFFER5;
    XCB_ATOM_CUT_BUFFER6         :: CUT_BUFFER6;
    XCB_ATOM_CUT_BUFFER7         :: CUT_BUFFER7;
    XCB_ATOM_DRAWABLE            :: DRAWABLE;
    XCB_ATOM_FONT                :: FONT;
    XCB_ATOM_INTEGER             :: INTEGER;
    XCB_ATOM_PIXMAP              :: PIXMAP;
    XCB_ATOM_POINT               :: POINT;
    XCB_ATOM_RECTANGLE           :: RECTANGLE;
    XCB_ATOM_RESOURCE_MANAGER    :: RESOURCE_MANAGER;
    XCB_ATOM_RGB_COLOR_MAP       :: RGB_COLOR_MAP;
    XCB_ATOM_RGB_BEST_MAP        :: RGB_BEST_MAP;
    XCB_ATOM_RGB_BLUE_MAP        :: RGB_BLUE_MAP;
    XCB_ATOM_RGB_DEFAULT_MAP     :: RGB_DEFAULT_MAP;
    XCB_ATOM_RGB_GRAY_MAP        :: RGB_GRAY_MAP;
    XCB_ATOM_RGB_GREEN_MAP       :: RGB_GREEN_MAP;
    XCB_ATOM_RGB_RED_MAP         :: RGB_RED_MAP;
    XCB_ATOM_STRING              :: STRING;
    XCB_ATOM_VISUALID            :: VISUALID;
    XCB_ATOM_WINDOW              :: WINDOW;
    XCB_ATOM_WM_COMMAND          :: WM_COMMAND;
    XCB_ATOM_WM_HINTS            :: WM_HINTS;
    XCB_ATOM_WM_CLIENT_MACHINE   :: WM_CLIENT_MACHINE;
    XCB_ATOM_WM_ICON_NAME        :: WM_ICON_NAME;
    XCB_ATOM_WM_ICON_SIZE        :: WM_ICON_SIZE;
    XCB_ATOM_WM_NAME             :: WM_NAME;
    XCB_ATOM_WM_NORMAL_HINTS     :: WM_NORMAL_HINTS;
    XCB_ATOM_WM_SIZE_HINTS       :: WM_SIZE_HINTS;
    XCB_ATOM_WM_ZOOM_HINTS       :: WM_ZOOM_HINTS;
    XCB_ATOM_MIN_SPACE           :: MIN_SPACE;
    XCB_ATOM_NORM_SPACE          :: NORM_SPACE;
    XCB_ATOM_MAX_SPACE           :: MAX_SPACE;
    XCB_ATOM_END_SPACE           :: END_SPACE;
    XCB_ATOM_SUPERSCRIPT_X       :: SUPERSCRIPT_X;
    XCB_ATOM_SUPERSCRIPT_Y       :: SUPERSCRIPT_Y;
    XCB_ATOM_SUBSCRIPT_X         :: SUBSCRIPT_X;
    XCB_ATOM_SUBSCRIPT_Y         :: SUBSCRIPT_Y;
    XCB_ATOM_UNDERLINE_POSITION  :: UNDERLINE_POSITION;
    XCB_ATOM_UNDERLINE_THICKNESS :: UNDERLINE_THICKNESS;
    XCB_ATOM_STRIKEOUT_ASCENT    :: STRIKEOUT_ASCENT;
    XCB_ATOM_STRIKEOUT_DESCENT   :: STRIKEOUT_DESCENT;
    XCB_ATOM_ITALIC_ANGLE        :: ITALIC_ANGLE;
    XCB_ATOM_X_HEIGHT            :: X_HEIGHT;
    XCB_ATOM_QUAD_WIDTH          :: QUAD_WIDTH;
    XCB_ATOM_WEIGHT              :: WEIGHT;
    XCB_ATOM_POINT_SIZE          :: POINT_SIZE;
    XCB_ATOM_RESOLUTION          :: RESOLUTION;
    XCB_ATOM_COPYRIGHT           :: COPYRIGHT;
    XCB_ATOM_NOTICE              :: NOTICE;
    XCB_ATOM_FONT_NAME           :: FONT_NAME;
    XCB_ATOM_FAMILY_NAME         :: FAMILY_NAME;
    XCB_ATOM_FULL_NAME           :: FULL_NAME;
    XCB_ATOM_CAP_HEIGHT          :: CAP_HEIGHT;
    XCB_ATOM_WM_CLASS            :: WM_CLASS;
    XCB_ATOM_WM_TRANSIENT_FOR    :: WM_TRANSIENT_FOR;
}

xcb_selection_request_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    owner:         xcb_window_t;
    requestor:     xcb_window_t;
    selection:     xcb_atom_t;
    target:        xcb_atom_t;
    property:      xcb_atom_t;
}

xcb_selection_notify_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    requestor:     xcb_window_t;
    selection:     xcb_atom_t;
    target:        xcb_atom_t;
    property:      xcb_atom_t;
}

xcb_colormap_state_t :: enum u32 {
    UNINSTALLED :: 0;
    INSTALLED   :: 1;

    XCB_COLORMAP_STATE_UNINSTALLED :: UNINSTALLED;
    XCB_COLORMAP_STATE_INSTALLED   :: INSTALLED;
}

xcb_colormap_enum_t :: enum u32 {
    XCB_COLORMAP_NONE :: 0;
}

xcb_colormap_notify_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    window:        xcb_window_t;
    colormap:      xcb_colormap_t;
    _new:          u8;
    state:         u8;
    pad1:          [2] u8;
}

xcb_client_message_data_t :: union {
    data8:  [20] u8;
    data16: [10] u16;
    data32: [5] u32;
}

xcb_client_message_data_iterator_t :: struct {
    data:  *xcb_client_message_data_t;
    rem:   s32;
    index: s32;
}

xcb_client_message_event_t :: struct {
    response_type: u8;
    format:        u8;
    sequence:      u16;
    window:        xcb_window_t;
    type:          xcb_atom_t;
    data:          xcb_client_message_data_t;
}

xcb_mapping_t :: enum u32 {
    MODIFIER :: 0;
    KEYBOARD :: 1;
    POINTER  :: 2;

    XCB_MAPPING_MODIFIER :: MODIFIER;
    XCB_MAPPING_KEYBOARD :: KEYBOARD;
    XCB_MAPPING_POINTER  :: POINTER;
}

xcb_mapping_notify_event_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    request:       u8;
    first_keycode: xcb_keycode_t;
    count:         u8;
    pad1:          u8;
}

xcb_ge_generic_event_t :: struct {
    response_type: u8;
    extension:     u8;
    sequence:      u16;
    length:        u32;
    event_type:    u16;
    pad0:          [22] u8;
    full_sequence: u32;
}

xcb_request_error_t :: struct {
    response_type: u8;
    error_code:    u8;
    sequence:      u16;
    bad_value:     u32;
    minor_opcode:  u16;
    major_opcode:  u8;
    pad0:          u8;
}

xcb_value_error_t :: struct {
    response_type: u8;
    error_code:    u8;
    sequence:      u16;
    bad_value:     u32;
    minor_opcode:  u16;
    major_opcode:  u8;
    pad0:          u8;
}

xcb_window_error_t :: xcb_value_error_t;

xcb_pixmap_error_t :: xcb_value_error_t;

xcb_atom_error_t :: xcb_value_error_t;

xcb_cursor_error_t :: xcb_value_error_t;

xcb_font_error_t :: xcb_value_error_t;

xcb_match_error_t :: xcb_request_error_t;

xcb_drawable_error_t :: xcb_value_error_t;

xcb_access_error_t :: xcb_request_error_t;

xcb_alloc_error_t :: xcb_request_error_t;

xcb_colormap_error_t :: xcb_value_error_t;

xcb_g_context_error_t :: xcb_value_error_t;

xcb_id_choice_error_t :: xcb_value_error_t;

xcb_name_error_t :: xcb_request_error_t;

xcb_length_error_t :: xcb_request_error_t;

xcb_implementation_error_t :: xcb_request_error_t;

xcb_window_class_t :: enum_flags u16 {
    COPY_FROM_PARENT :: 0;
    INPUT_OUTPUT     :: 1;
    INPUT_ONLY       :: 2;

    XCB_WINDOW_CLASS_COPY_FROM_PARENT :: COPY_FROM_PARENT;
    XCB_WINDOW_CLASS_INPUT_OUTPUT     :: INPUT_OUTPUT;
    XCB_WINDOW_CLASS_INPUT_ONLY       :: INPUT_ONLY;
}

xcb_cw_t :: enum_flags u32 {
    BACK_PIXMAP       :: 1;
    BACK_PIXEL        :: 2;
    BORDER_PIXMAP     :: 4;
    BORDER_PIXEL      :: 8;
    BIT_GRAVITY       :: 16;
    WIN_GRAVITY       :: 32;
    BACKING_STORE     :: 64;
    BACKING_PLANES    :: 128;
    BACKING_PIXEL     :: 256;
    OVERRIDE_REDIRECT :: 512;
    SAVE_UNDER        :: 1024;
    EVENT_MASK        :: 2048;
    DONT_PROPAGATE    :: 4096;
    COLORMAP          :: 8192;
    CURSOR            :: 16384;

    XCB_CW_BACK_PIXMAP       :: BACK_PIXMAP;
    XCB_CW_BACK_PIXEL        :: BACK_PIXEL;
    XCB_CW_BORDER_PIXMAP     :: BORDER_PIXMAP;
    XCB_CW_BORDER_PIXEL      :: BORDER_PIXEL;
    XCB_CW_BIT_GRAVITY       :: BIT_GRAVITY;
    XCB_CW_WIN_GRAVITY       :: WIN_GRAVITY;
    XCB_CW_BACKING_STORE     :: BACKING_STORE;
    XCB_CW_BACKING_PLANES    :: BACKING_PLANES;
    XCB_CW_BACKING_PIXEL     :: BACKING_PIXEL;
    XCB_CW_OVERRIDE_REDIRECT :: OVERRIDE_REDIRECT;
    XCB_CW_SAVE_UNDER        :: SAVE_UNDER;
    XCB_CW_EVENT_MASK        :: EVENT_MASK;
    XCB_CW_DONT_PROPAGATE    :: DONT_PROPAGATE;
    XCB_CW_COLORMAP          :: COLORMAP;
    XCB_CW_CURSOR            :: CURSOR;
}

xcb_back_pixmap_t :: enum u32 {
    NONE            :: 0;
    PARENT_RELATIVE :: 1;

    XCB_BACK_PIXMAP_NONE            :: NONE;
    XCB_BACK_PIXMAP_PARENT_RELATIVE :: PARENT_RELATIVE;
}

xcb_gravity_t :: enum u32 {
    BIT_FORGET :: 0;
    WIN_UNMAP  :: 0;
    NORTH_WEST :: 1;
    NORTH      :: 2;
    NORTH_EAST :: 3;
    WEST       :: 4;
    CENTER     :: 5;
    EAST       :: 6;
    SOUTH_WEST :: 7;
    SOUTH      :: 8;
    SOUTH_EAST :: 9;
    STATIC     :: 10;

    XCB_GRAVITY_BIT_FORGET :: BIT_FORGET;
    XCB_GRAVITY_WIN_UNMAP  :: WIN_UNMAP;
    XCB_GRAVITY_NORTH_WEST :: NORTH_WEST;
    XCB_GRAVITY_NORTH      :: NORTH;
    XCB_GRAVITY_NORTH_EAST :: NORTH_EAST;
    XCB_GRAVITY_WEST       :: WEST;
    XCB_GRAVITY_CENTER     :: CENTER;
    XCB_GRAVITY_EAST       :: EAST;
    XCB_GRAVITY_SOUTH_WEST :: SOUTH_WEST;
    XCB_GRAVITY_SOUTH      :: SOUTH;
    XCB_GRAVITY_SOUTH_EAST :: SOUTH_EAST;
    XCB_GRAVITY_STATIC     :: STATIC;
}

xcb_create_window_value_list_t :: struct {
    background_pixmap:     xcb_pixmap_t;
    background_pixel:      u32;
    border_pixmap:         xcb_pixmap_t;
    border_pixel:          u32;
    bit_gravity:           u32;
    win_gravity:           u32;
    backing_store:         u32;
    backing_planes:        u32;
    backing_pixel:         u32;
    override_redirect:     xcb_bool32_t;
    save_under:            xcb_bool32_t;
    event_mask:            u32;
    do_not_propogate_mask: u32;
    colormap:              xcb_colormap_t;
    cursor:                xcb_cursor_t;
}

xcb_create_window_request_t :: struct {
    major_opcode: u8;
    depth:        u8;
    length:       u16;
    wid:          xcb_window_t;
    parent:       xcb_window_t;
    x:            s16;
    y:            s16;
    width:        u16;
    height:       u16;
    border_width: u16;
    _class:       u16;
    visual:       xcb_visualid_t;
    value_mask:   u32;
}

xcb_change_window_attributes_value_list_t :: struct {
    background_pixmap:     xcb_pixmap_t;
    background_pixel:      u32;
    border_pixmap:         xcb_pixmap_t;
    border_pixel:          u32;
    bit_gravity:           u32;
    win_gravity:           u32;
    backing_store:         u32;
    backing_planes:        u32;
    backing_pixel:         u32;
    override_redirect:     xcb_bool32_t;
    save_under:            xcb_bool32_t;
    event_mask:            u32;
    do_not_propogate_mask: u32;
    colormap:              xcb_colormap_t;
    cursor:                xcb_cursor_t;
}

xcb_change_window_attributes_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
    value_mask:   xcb_cw_t;
}

xcb_map_state_t :: enum u32 {
    UNMAPPED   :: 0;
    UNVIEWABLE :: 1;
    VIEWABLE   :: 2;

    XCB_MAP_STATE_UNMAPPED   :: UNMAPPED;
    XCB_MAP_STATE_UNVIEWABLE :: UNVIEWABLE;
    XCB_MAP_STATE_VIEWABLE   :: VIEWABLE;
}

xcb_get_window_attributes_cookie_t :: struct {
    sequence: u32;
}

xcb_get_window_attributes_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_get_window_attributes_reply_t :: struct {
    response_type:         u8;
    backing_store:         u8;
    sequence:              u16;
    length:                u32;
    visual:                xcb_visualid_t;
    _class:                u16;
    bit_gravity:           u8;
    win_gravity:           u8;
    backing_planes:        u32;
    backing_pixel:         u32;
    save_under:            u8;
    map_is_installed:      u8;
    map_state:             u8;
    override_redirect:     u8;
    colormap:              xcb_colormap_t;
    all_event_masks:       u32;
    your_event_mask:       u32;
    do_not_propagate_mask: u16;
    pad0:                  [2] u8;
}

xcb_destroy_window_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_destroy_subwindows_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_set_mode_t :: enum u32 {
    INSERT :: 0;
    DELETE :: 1;

    XCB_SET_MODE_INSERT :: INSERT;
    XCB_SET_MODE_DELETE :: DELETE;
}

xcb_change_save_set_request_t :: struct {
    major_opcode: u8;
    mode:         u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_reparent_window_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
    parent:       xcb_window_t;
    x:            s16;
    y:            s16;
}

xcb_map_window_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_map_subwindows_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_unmap_window_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_unmap_subwindows_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_config_window_t :: enum u32 {
    X            :: 1;
    Y            :: 2;
    WIDTH        :: 4;
    HEIGHT       :: 8;
    BORDER_WIDTH :: 16;
    SIBLING      :: 32;
    STACK_MODE   :: 64;

    XCB_CONFIG_WINDOW_X            :: X;
    XCB_CONFIG_WINDOW_Y            :: Y;
    XCB_CONFIG_WINDOW_WIDTH        :: WIDTH;
    XCB_CONFIG_WINDOW_HEIGHT       :: HEIGHT;
    XCB_CONFIG_WINDOW_BORDER_WIDTH :: BORDER_WIDTH;
    XCB_CONFIG_WINDOW_SIBLING      :: SIBLING;
    XCB_CONFIG_WINDOW_STACK_MODE   :: STACK_MODE;
}

xcb_stack_mode_t :: enum u32 {
    ABOVE     :: 0;
    BELOW     :: 1;
    TOP_IF    :: 2;
    BOTTOM_IF :: 3;
    OPPOSITE  :: 4;

    XCB_STACK_MODE_ABOVE     :: ABOVE;
    XCB_STACK_MODE_BELOW     :: BELOW;
    XCB_STACK_MODE_TOP_IF    :: TOP_IF;
    XCB_STACK_MODE_BOTTOM_IF :: BOTTOM_IF;
    XCB_STACK_MODE_OPPOSITE  :: OPPOSITE;
}

xcb_configure_window_value_list_t :: struct {
    x:            s32;
    y:            s32;
    width:        u32;
    height:       u32;
    border_width: u32;
    sibling:      xcb_window_t;
    stack_mode:   u32;
}

xcb_configure_window_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
    value_mask:   u16;
    pad1:         [2] u8;
}

xcb_circulate_t :: enum u32 {
    RAISE_LOWEST  :: 0;
    LOWER_HIGHEST :: 1;

    XCB_CIRCULATE_RAISE_LOWEST  :: RAISE_LOWEST;
    XCB_CIRCULATE_LOWER_HIGHEST :: LOWER_HIGHEST;
}

xcb_circulate_window_request_t :: struct {
    major_opcode: u8;
    direction:    u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_get_geometry_cookie_t :: struct {
    sequence: u32;
}

xcb_get_geometry_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    drawable:     xcb_drawable_t;
}

xcb_get_geometry_reply_t :: struct {
    response_type: u8;
    depth:         u8;
    sequence:      u16;
    length:        u32;
    root:          xcb_window_t;
    x:             s16;
    y:             s16;
    width:         u16;
    height:        u16;
    border_width:  u16;
    pad0:          [2] u8;
}

xcb_query_tree_cookie_t :: struct {
    sequence: u32;
}

xcb_query_tree_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_query_tree_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    root:          xcb_window_t;
    parent:        xcb_window_t;
    children_len:  u16;
    pad1:          [14] u8;
}

xcb_intern_atom_cookie_t :: struct {
    sequence: u32;
}

xcb_intern_atom_request_t :: struct {
    major_opcode:   u8;
    only_if_exists: u8;
    length:         u16;
    name_len:       u16;
    pad0:           [2] u8;
}

xcb_intern_atom_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    atom:          xcb_atom_t;
}

xcb_get_atom_name_cookie_t :: struct {
    sequence: u32;
}

xcb_get_atom_name_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    atom:         xcb_atom_t;
}

xcb_get_atom_name_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    name_len:      u16;
    pad1:          [22] u8;
}

xcb_prop_mode_t :: enum u8 {
    REPLACE :: 0;
    PREPEND :: 1;
    APPEND  :: 2;

    XCB_PROP_MODE_REPLACE :: REPLACE;
    XCB_PROP_MODE_PREPEND :: PREPEND;
    XCB_PROP_MODE_APPEND  :: APPEND;
}

xcb_change_property_request_t :: struct {
    major_opcode: u8;
    mode:         xcb_prop_mode_t;
    length:       u16;
    window:       xcb_window_t;
    property:     xcb_atom_t;
    type:         xcb_atom_t;
    format:       u8;
    pad0:         [3] u8;
    data_len:     u32;
}

xcb_delete_property_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
    property:     xcb_atom_t;
}

xcb_get_property_type_t :: enum u32 {
    XCB_GET_PROPERTY_TYPE_ANY :: 0;
}

xcb_get_property_cookie_t :: struct {
    sequence: u32;
}

xcb_get_property_request_t :: struct {
    major_opcode: u8;
    _delete:      u8;
    length:       u16;
    window:       xcb_window_t;
    property:     xcb_atom_t;
    type:         xcb_atom_t;
    long_offset:  u32;
    long_length:  u32;
}

xcb_get_property_reply_t :: struct {
    response_type: u8;
    format:        u8;
    sequence:      u16;
    length:        u32;
    type:          xcb_atom_t;
    bytes_after:   u32;
    value_len:     u32;
    pad0:          [12] u8;
}

xcb_list_properties_cookie_t :: struct {
    sequence: u32;
}

xcb_list_properties_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_list_properties_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    atoms_len:     u16;
    pad1:          [22] u8;
}

xcb_set_selection_owner_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    owner:        xcb_window_t;
    selection:    xcb_atom_t;
    time:         xcb_timestamp_t;
}

xcb_get_selection_owner_cookie_t :: struct {
    sequence: u32;
}

xcb_get_selection_owner_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    selection:    xcb_atom_t;
}

xcb_get_selection_owner_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    owner:         xcb_window_t;
}

xcb_convert_selection_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    requestor:    xcb_window_t;
    selection:    xcb_atom_t;
    target:       xcb_atom_t;
    property:     xcb_atom_t;
    time:         xcb_timestamp_t;
}

xcb_send_event_dest_t :: enum u32 {
    POINTER_WINDOW :: 0;
    ITEM_FOCUS     :: 1;

    XCB_SEND_EVENT_DEST_POINTER_WINDOW :: POINTER_WINDOW;
    XCB_SEND_EVENT_DEST_ITEM_FOCUS     :: ITEM_FOCUS;
}

xcb_send_event_request_t :: struct {
    major_opcode: u8;
    propagate:    u8;
    length:       u16;
    destination:  xcb_window_t;
    event_mask:   u32;
    event:        [32] u8;
}

xcb_grab_mode_t :: enum u32 {
    SYNC  :: 0;
    ASYNC :: 1;

    XCB_GRAB_MODE_SYNC  :: SYNC;
    XCB_GRAB_MODE_ASYNC :: ASYNC;
}

xcb_grab_status_t :: enum u32 {
    SUCCESS         :: 0;
    ALREADY_GRABBED :: 1;
    INVALID_TIME    :: 2;
    NOT_VIEWABLE    :: 3;
    FROZEN          :: 4;

    XCB_GRAB_STATUS_SUCCESS         :: SUCCESS;
    XCB_GRAB_STATUS_ALREADY_GRABBED :: ALREADY_GRABBED;
    XCB_GRAB_STATUS_INVALID_TIME    :: INVALID_TIME;
    XCB_GRAB_STATUS_NOT_VIEWABLE    :: NOT_VIEWABLE;
    XCB_GRAB_STATUS_FROZEN          :: FROZEN;
}

xcb_cursor_enum_t :: enum u32 {
    XCB_CURSOR_NONE :: 0;
}

xcb_grab_pointer_cookie_t :: struct {
    sequence: u32;
}

xcb_grab_pointer_request_t :: struct {
    major_opcode:  u8;
    owner_events:  u8;
    length:        u16;
    grab_window:   xcb_window_t;
    event_mask:    u16;
    pointer_mode:  u8;
    keyboard_mode: u8;
    confine_to:    xcb_window_t;
    cursor:        xcb_cursor_t;
    time:          xcb_timestamp_t;
}

xcb_grab_pointer_reply_t :: struct {
    response_type: u8;
    status:        u8;
    sequence:      u16;
    length:        u32;
}

xcb_ungrab_pointer_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    time:         xcb_timestamp_t;
}

xcb_button_index_t :: enum u32 {
    ANY :: 0;
    _1  :: 1;
    _2  :: 2;
    _3  :: 3;
    _4  :: 4;
    _5  :: 5;

    XCB_BUTTON_INDEX_ANY :: ANY;
    XCB_BUTTON_INDEX_1   :: _1;
    XCB_BUTTON_INDEX_2   :: _2;
    XCB_BUTTON_INDEX_3   :: _3;
    XCB_BUTTON_INDEX_4   :: _4;
    XCB_BUTTON_INDEX_5   :: _5;
}

xcb_grab_button_request_t :: struct {
    major_opcode:  u8;
    owner_events:  u8;
    length:        u16;
    grab_window:   xcb_window_t;
    event_mask:    u16;
    pointer_mode:  u8;
    keyboard_mode: u8;
    confine_to:    xcb_window_t;
    cursor:        xcb_cursor_t;
    button:        u8;
    pad0:          u8;
    modifiers:     u16;
}

xcb_ungrab_button_request_t :: struct {
    major_opcode: u8;
    button:       u8;
    length:       u16;
    grab_window:  xcb_window_t;
    modifiers:    u16;
    pad0:         [2] u8;
}

xcb_change_active_pointer_grab_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cursor:       xcb_cursor_t;
    time:         xcb_timestamp_t;
    event_mask:   u16;
    pad1:         [2] u8;
}

xcb_grab_keyboard_cookie_t :: struct {
    sequence: u32;
}

xcb_grab_keyboard_request_t :: struct {
    major_opcode:  u8;
    owner_events:  u8;
    length:        u16;
    grab_window:   xcb_window_t;
    time:          xcb_timestamp_t;
    pointer_mode:  u8;
    keyboard_mode: u8;
    pad0:          [2] u8;
}

xcb_grab_keyboard_reply_t :: struct {
    response_type: u8;
    status:        u8;
    sequence:      u16;
    length:        u32;
}

xcb_ungrab_keyboard_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    time:         xcb_timestamp_t;
}

xcb_grab_t :: enum u32 {
    XCB_GRAB_ANY :: 0;
}

xcb_grab_key_request_t :: struct {
    major_opcode:  u8;
    owner_events:  u8;
    length:        u16;
    grab_window:   xcb_window_t;
    modifiers:     u16;
    key:           xcb_keycode_t;
    pointer_mode:  u8;
    keyboard_mode: u8;
    pad0:          [3] u8;
}

xcb_ungrab_key_request_t :: struct {
    major_opcode: u8;
    key:          xcb_keycode_t;
    length:       u16;
    grab_window:  xcb_window_t;
    modifiers:    u16;
    pad0:         [2] u8;
}

xcb_allow_t :: enum u32 {
    ASYNC_POINTER   :: 0;
    SYNC_POINTER    :: 1;
    REPLAY_POINTER  :: 2;
    ASYNC_KEYBOARD  :: 3;
    SYNC_KEYBOARD   :: 4;
    REPLAY_KEYBOARD :: 5;
    ASYNC_BOTH      :: 6;
    SYNC_BOTH       :: 7;

    XCB_ALLOW_ASYNC_POINTER   :: ASYNC_POINTER;
    XCB_ALLOW_SYNC_POINTER    :: SYNC_POINTER;
    XCB_ALLOW_REPLAY_POINTER  :: REPLAY_POINTER;
    XCB_ALLOW_ASYNC_KEYBOARD  :: ASYNC_KEYBOARD;
    XCB_ALLOW_SYNC_KEYBOARD   :: SYNC_KEYBOARD;
    XCB_ALLOW_REPLAY_KEYBOARD :: REPLAY_KEYBOARD;
    XCB_ALLOW_ASYNC_BOTH      :: ASYNC_BOTH;
    XCB_ALLOW_SYNC_BOTH       :: SYNC_BOTH;
}

xcb_allow_events_request_t :: struct {
    major_opcode: u8;
    mode:         u8;
    length:       u16;
    time:         xcb_timestamp_t;
}

xcb_grab_server_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
}

xcb_ungrab_server_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
}

xcb_query_pointer_cookie_t :: struct {
    sequence: u32;
}

xcb_query_pointer_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_query_pointer_reply_t :: struct {
    response_type: u8;
    same_screen:   u8;
    sequence:      u16;
    length:        u32;
    root:          xcb_window_t;
    child:         xcb_window_t;
    root_x:        s16;
    root_y:        s16;
    win_x:         s16;
    win_y:         s16;
    mask:          u16;
    pad0:          [2] u8;
}

xcb_timecoord_t :: struct {
    time: xcb_timestamp_t;
    x:    s16;
    y:    s16;
}

xcb_timecoord_iterator_t :: struct {
    data:  *xcb_timecoord_t;
    rem:   s32;
    index: s32;
}

xcb_get_motion_events_cookie_t :: struct {
    sequence: u32;
}

xcb_get_motion_events_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
    start:        xcb_timestamp_t;
    stop:         xcb_timestamp_t;
}

xcb_get_motion_events_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    events_len:    u32;
    pad1:          [20] u8;
}

xcb_translate_coordinates_cookie_t :: struct {
    sequence: u32;
}

xcb_translate_coordinates_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    src_window:   xcb_window_t;
    dst_window:   xcb_window_t;
    src_x:        s16;
    src_y:        s16;
}

xcb_translate_coordinates_reply_t :: struct {
    response_type: u8;
    same_screen:   u8;
    sequence:      u16;
    length:        u32;
    child:         xcb_window_t;
    dst_x:         s16;
    dst_y:         s16;
}

xcb_warp_pointer_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    src_window:   xcb_window_t;
    dst_window:   xcb_window_t;
    src_x:        s16;
    src_y:        s16;
    src_width:    u16;
    src_height:   u16;
    dst_x:        s16;
    dst_y:        s16;
}

xcb_input_focus_t :: enum u32 {
    NONE            :: 0;
    POINTER_ROOT    :: 1;
    PARENT          :: 2;
    FOLLOW_KEYBOARD :: 3;

    XCB_INPUT_FOCUS_NONE            :: NONE;
    XCB_INPUT_FOCUS_POINTER_ROOT    :: POINTER_ROOT;
    XCB_INPUT_FOCUS_PARENT          :: PARENT;
    XCB_INPUT_FOCUS_FOLLOW_KEYBOARD :: FOLLOW_KEYBOARD;
}

xcb_set_input_focus_request_t :: struct {
    major_opcode: u8;
    revert_to:    u8;
    length:       u16;
    focus:        xcb_window_t;
    time:         xcb_timestamp_t;
}

xcb_get_input_focus_cookie_t :: struct {
    sequence: u32;
}

xcb_get_input_focus_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
}

xcb_get_input_focus_reply_t :: struct {
    response_type: u8;
    revert_to:     u8;
    sequence:      u16;
    length:        u32;
    focus:         xcb_window_t;
}

xcb_query_keymap_cookie_t :: struct {
    sequence: u32;
}

xcb_query_keymap_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
}

xcb_query_keymap_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    keys:          [32] u8;
}

xcb_open_font_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    fid:          xcb_font_t;
    name_len:     u16;
    pad1:         [2] u8;
}

xcb_close_font_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    font:         xcb_font_t;
}

xcb_font_draw_t :: enum u32 {
    LEFT_TO_RIGHT :: 0;
    RIGHT_TO_LEFT :: 1;

    XCB_FONT_DRAW_LEFT_TO_RIGHT :: LEFT_TO_RIGHT;
    XCB_FONT_DRAW_RIGHT_TO_LEFT :: RIGHT_TO_LEFT;
}

xcb_fontprop_t :: struct {
    name:  xcb_atom_t;
    value: u32;
}

xcb_fontprop_iterator_t :: struct {
    data:  *xcb_fontprop_t;
    rem:   s32;
    index: s32;
}

xcb_charinfo_t :: struct {
    left_side_bearing:  s16;
    right_side_bearing: s16;
    character_width:    s16;
    ascent:             s16;
    descent:            s16;
    attributes:         u16;
}

xcb_charinfo_iterator_t :: struct {
    data:  *xcb_charinfo_t;
    rem:   s32;
    index: s32;
}

xcb_query_font_cookie_t :: struct {
    sequence: u32;
}

xcb_query_font_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    font:         xcb_fontable_t;
}

xcb_query_font_reply_t :: struct {
    response_type:     u8;
    pad0:              u8;
    sequence:          u16;
    length:            u32;
    min_bounds:        xcb_charinfo_t;
    pad1:              [4] u8;
    max_bounds:        xcb_charinfo_t;
    pad2:              [4] u8;
    min_char_or_byte2: u16;
    max_char_or_byte2: u16;
    default_char:      u16;
    properties_len:    u16;
    draw_direction:    u8;
    min_byte1:         u8;
    max_byte1:         u8;
    all_chars_exist:   u8;
    font_ascent:       s16;
    font_descent:      s16;
    char_infos_len:    u32;
}

xcb_query_text_extents_cookie_t :: struct {
    sequence: u32;
}

xcb_query_text_extents_request_t :: struct {
    major_opcode: u8;
    odd_length:   u8;
    length:       u16;
    font:         xcb_fontable_t;
}

xcb_query_text_extents_reply_t :: struct {
    response_type:   u8;
    draw_direction:  u8;
    sequence:        u16;
    length:          u32;
    font_ascent:     s16;
    font_descent:    s16;
    overall_ascent:  s16;
    overall_descent: s16;
    overall_width:   s32;
    overall_left:    s32;
    overall_right:   s32;
}

xcb_str_t :: struct {
    name_len: u8;
}

xcb_str_iterator_t :: struct {
    data:  *xcb_str_t;
    rem:   s32;
    index: s32;
}

xcb_list_fonts_cookie_t :: struct {
    sequence: u32;
}

xcb_list_fonts_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    max_names:    u16;
    pattern_len:  u16;
}

xcb_list_fonts_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    names_len:     u16;
    pad1:          [22] u8;
}

xcb_list_fonts_with_info_cookie_t :: struct {
    sequence: u32;
}

xcb_list_fonts_with_info_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    max_names:    u16;
    pattern_len:  u16;
}

xcb_list_fonts_with_info_reply_t :: struct {
    response_type:     u8;
    name_len:          u8;
    sequence:          u16;
    length:            u32;
    min_bounds:        xcb_charinfo_t;
    pad0:              [4] u8;
    max_bounds:        xcb_charinfo_t;
    pad1:              [4] u8;
    min_char_or_byte2: u16;
    max_char_or_byte2: u16;
    default_char:      u16;
    properties_len:    u16;
    draw_direction:    u8;
    min_byte1:         u8;
    max_byte1:         u8;
    all_chars_exist:   u8;
    font_ascent:       s16;
    font_descent:      s16;
    replies_hint:      u32;
}

xcb_set_font_path_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    font_qty:     u16;
    pad1:         [2] u8;
}

xcb_get_font_path_cookie_t :: struct {
    sequence: u32;
}

xcb_get_font_path_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
}

xcb_get_font_path_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    path_len:      u16;
    pad1:          [22] u8;
}

xcb_create_pixmap_request_t :: struct {
    major_opcode: u8;
    depth:        u8;
    length:       u16;
    pid:          xcb_pixmap_t;
    drawable:     xcb_drawable_t;
    width:        u16;
    height:       u16;
}

xcb_free_pixmap_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    pixmap:       xcb_pixmap_t;
}

xcb_gc_t :: enum_flags u32 {
    FUNCTION              :: 1;
    PLANE_MASK            :: 2;
    FOREGROUND            :: 4;
    BACKGROUND            :: 8;
    LINE_WIDTH            :: 16;
    LINE_STYLE            :: 32;
    CAP_STYLE             :: 64;
    JOIN_STYLE            :: 128;
    FILL_STYLE            :: 256;
    FILL_RULE             :: 512;
    TILE                  :: 1024;
    STIPPLE               :: 2048;
    TILE_STIPPLE_ORIGIN_X :: 4096;
    TILE_STIPPLE_ORIGIN_Y :: 8192;
    FONT                  :: 16384;
    SUBWINDOW_MODE        :: 32768;
    GRAPHICS_EXPOSURES    :: 65536;
    CLIP_ORIGIN_X         :: 131072;
    CLIP_ORIGIN_Y         :: 262144;
    CLIP_MASK             :: 524288;
    DASH_OFFSET           :: 1048576;
    DASH_LIST             :: 2097152;
    ARC_MODE              :: 4194304;

    XCB_GC_FUNCTION              :: FUNCTION;
    XCB_GC_PLANE_MASK            :: PLANE_MASK;
    XCB_GC_FOREGROUND            :: FOREGROUND;
    XCB_GC_BACKGROUND            :: BACKGROUND;
    XCB_GC_LINE_WIDTH            :: LINE_WIDTH;
    XCB_GC_LINE_STYLE            :: LINE_STYLE;
    XCB_GC_CAP_STYLE             :: CAP_STYLE;
    XCB_GC_JOIN_STYLE            :: JOIN_STYLE;
    XCB_GC_FILL_STYLE            :: FILL_STYLE;
    XCB_GC_FILL_RULE             :: FILL_RULE;
    XCB_GC_TILE                  :: TILE;
    XCB_GC_STIPPLE               :: STIPPLE;
    XCB_GC_TILE_STIPPLE_ORIGIN_X :: TILE_STIPPLE_ORIGIN_X;
    XCB_GC_TILE_STIPPLE_ORIGIN_Y :: TILE_STIPPLE_ORIGIN_Y;
    XCB_GC_FONT                  :: FONT;
    XCB_GC_SUBWINDOW_MODE        :: SUBWINDOW_MODE;
    XCB_GC_GRAPHICS_EXPOSURES    :: GRAPHICS_EXPOSURES;
    XCB_GC_CLIP_ORIGIN_X         :: CLIP_ORIGIN_X;
    XCB_GC_CLIP_ORIGIN_Y         :: CLIP_ORIGIN_Y;
    XCB_GC_CLIP_MASK             :: CLIP_MASK;
    XCB_GC_DASH_OFFSET           :: DASH_OFFSET;
    XCB_GC_DASH_LIST             :: DASH_LIST;
    XCB_GC_ARC_MODE              :: ARC_MODE;
}

xcb_gx_t :: enum u32 {
    CLEAR         :: 0;
    AND           :: 1;
    AND_REVERSE   :: 2;
    COPY          :: 3;
    AND_INVERTED  :: 4;
    NOOP          :: 5;
    XOR           :: 6;
    OR            :: 7;
    NOR           :: 8;
    EQUIV         :: 9;
    INVERT        :: 10;
    OR_REVERSE    :: 11;
    COPY_INVERTED :: 12;
    OR_INVERTED   :: 13;
    NAND          :: 14;
    SET           :: 15;

    XCB_GX_CLEAR         :: CLEAR;
    XCB_GX_AND           :: AND;
    XCB_GX_AND_REVERSE   :: AND_REVERSE;
    XCB_GX_COPY          :: COPY;
    XCB_GX_AND_INVERTED  :: AND_INVERTED;
    XCB_GX_NOOP          :: NOOP;
    XCB_GX_XOR           :: XOR;
    XCB_GX_OR            :: OR;
    XCB_GX_NOR           :: NOR;
    XCB_GX_EQUIV         :: EQUIV;
    XCB_GX_INVERT        :: INVERT;
    XCB_GX_OR_REVERSE    :: OR_REVERSE;
    XCB_GX_COPY_INVERTED :: COPY_INVERTED;
    XCB_GX_OR_INVERTED   :: OR_INVERTED;
    XCB_GX_NAND          :: NAND;
    XCB_GX_SET           :: SET;
}

xcb_line_style_t :: enum u32 {
    SOLID       :: 0;
    ON_OFF_DASH :: 1;
    DOUBLE_DASH :: 2;

    XCB_LINE_STYLE_SOLID       :: SOLID;
    XCB_LINE_STYLE_ON_OFF_DASH :: ON_OFF_DASH;
    XCB_LINE_STYLE_DOUBLE_DASH :: DOUBLE_DASH;
}

xcb_cap_style_t :: enum u32 {
    NOT_LAST   :: 0;
    BUTT       :: 1;
    ROUND      :: 2;
    PROJECTING :: 3;

    XCB_CAP_STYLE_NOT_LAST   :: NOT_LAST;
    XCB_CAP_STYLE_BUTT       :: BUTT;
    XCB_CAP_STYLE_ROUND      :: ROUND;
    XCB_CAP_STYLE_PROJECTING :: PROJECTING;
}

xcb_join_style_t :: enum u32 {
    MITER :: 0;
    ROUND :: 1;
    BEVEL :: 2;

    XCB_JOIN_STYLE_MITER :: MITER;
    XCB_JOIN_STYLE_ROUND :: ROUND;
    XCB_JOIN_STYLE_BEVEL :: BEVEL;
}

xcb_fill_style_t :: enum u32 {
    SOLID           :: 0;
    TILED           :: 1;
    STIPPLED        :: 2;
    OPAQUE_STIPPLED :: 3;

    XCB_FILL_STYLE_SOLID           :: SOLID;
    XCB_FILL_STYLE_TILED           :: TILED;
    XCB_FILL_STYLE_STIPPLED        :: STIPPLED;
    XCB_FILL_STYLE_OPAQUE_STIPPLED :: OPAQUE_STIPPLED;
}

xcb_fill_rule_t :: enum u32 {
    EVEN_ODD :: 0;
    WINDING  :: 1;

    XCB_FILL_RULE_EVEN_ODD :: EVEN_ODD;
    XCB_FILL_RULE_WINDING  :: WINDING;
}

xcb_subwindow_mode_t :: enum u32 {
    CLIP_BY_CHILDREN  :: 0;
    INCLUDE_INFERIORS :: 1;

    XCB_SUBWINDOW_MODE_CLIP_BY_CHILDREN  :: CLIP_BY_CHILDREN;
    XCB_SUBWINDOW_MODE_INCLUDE_INFERIORS :: INCLUDE_INFERIORS;
}

xcb_arc_mode_t :: enum u32 {
    CHORD     :: 0;
    PIE_SLICE :: 1;

    XCB_ARC_MODE_CHORD     :: CHORD;
    XCB_ARC_MODE_PIE_SLICE :: PIE_SLICE;
}

xcb_create_gc_value_list_t :: struct {
    function:              u32;
    plane_mask:            u32;
    foreground:            u32;
    background:            u32;
    line_width:            u32;
    line_style:            u32;
    cap_style:             u32;
    join_style:            u32;
    fill_style:            u32;
    fill_rule:             u32;
    tile:                  xcb_pixmap_t;
    stipple:               xcb_pixmap_t;
    tile_stipple_x_origin: s32;
    tile_stipple_y_origin: s32;
    font:                  xcb_font_t;
    subwindow_mode:        u32;
    graphics_exposures:    xcb_bool32_t;
    clip_x_origin:         s32;
    clip_y_origin:         s32;
    clip_mask:             xcb_pixmap_t;
    dash_offset:           u32;
    dashes:                u32;
    arc_mode:              u32;
}

xcb_create_gc_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cid:          xcb_gcontext_t;
    drawable:     xcb_drawable_t;
    value_mask:   u32;
}

xcb_change_gc_value_list_t :: struct {
    function:              u32;
    plane_mask:            u32;
    foreground:            u32;
    background:            u32;
    line_width:            u32;
    line_style:            u32;
    cap_style:             u32;
    join_style:            u32;
    fill_style:            u32;
    fill_rule:             u32;
    tile:                  xcb_pixmap_t;
    stipple:               xcb_pixmap_t;
    tile_stipple_x_origin: s32;
    tile_stipple_y_origin: s32;
    font:                  xcb_font_t;
    subwindow_mode:        u32;
    graphics_exposures:    xcb_bool32_t;
    clip_x_origin:         s32;
    clip_y_origin:         s32;
    clip_mask:             xcb_pixmap_t;
    dash_offset:           u32;
    dashes:                u32;
    arc_mode:              u32;
}

xcb_change_gc_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    gc:           xcb_gcontext_t;
    value_mask:   u32;
}

xcb_copy_gc_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    src_gc:       xcb_gcontext_t;
    dst_gc:       xcb_gcontext_t;
    value_mask:   u32;
}

xcb_set_dashes_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    gc:           xcb_gcontext_t;
    dash_offset:  u16;
    dashes_len:   u16;
}

xcb_clip_ordering_t :: enum u32 {
    UNSORTED  :: 0;
    Y_SORTED  :: 1;
    YX_SORTED :: 2;
    YX_BANDED :: 3;

    XCB_CLIP_ORDERING_UNSORTED  :: UNSORTED;
    XCB_CLIP_ORDERING_Y_SORTED  :: Y_SORTED;
    XCB_CLIP_ORDERING_YX_SORTED :: YX_SORTED;
    XCB_CLIP_ORDERING_YX_BANDED :: YX_BANDED;
}

xcb_set_clip_rectangles_request_t :: struct {
    major_opcode:  u8;
    ordering:      u8;
    length:        u16;
    gc:            xcb_gcontext_t;
    clip_x_origin: s16;
    clip_y_origin: s16;
}

xcb_free_gc_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    gc:           xcb_gcontext_t;
}

xcb_clear_area_request_t :: struct {
    major_opcode: u8;
    exposures:    u8;
    length:       u16;
    window:       xcb_window_t;
    x:            s16;
    y:            s16;
    width:        u16;
    height:       u16;
}

xcb_copy_area_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    src_drawable: xcb_drawable_t;
    dst_drawable: xcb_drawable_t;
    gc:           xcb_gcontext_t;
    src_x:        s16;
    src_y:        s16;
    dst_x:        s16;
    dst_y:        s16;
    width:        u16;
    height:       u16;
}

xcb_copy_plane_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    src_drawable: xcb_drawable_t;
    dst_drawable: xcb_drawable_t;
    gc:           xcb_gcontext_t;
    src_x:        s16;
    src_y:        s16;
    dst_x:        s16;
    dst_y:        s16;
    width:        u16;
    height:       u16;
    bit_plane:    u32;
}

xcb_coord_mode_t :: enum u32 {
    ORIGIN   :: 0;
    PREVIOUS :: 1;

    XCB_COORD_MODE_ORIGIN   :: ORIGIN;
    XCB_COORD_MODE_PREVIOUS :: PREVIOUS;
}

xcb_poly_point_request_t :: struct {
    major_opcode:    u8;
    coordinate_mode: u8;
    length:          u16;
    drawable:        xcb_drawable_t;
    gc:              xcb_gcontext_t;
}

xcb_poly_line_request_t :: struct {
    major_opcode:    u8;
    coordinate_mode: u8;
    length:          u16;
    drawable:        xcb_drawable_t;
    gc:              xcb_gcontext_t;
}

xcb_segment_t :: struct {
    x1: s16;
    y1: s16;
    x2: s16;
    y2: s16;
}

xcb_segment_iterator_t :: struct {
    data:  *xcb_segment_t;
    rem:   s32;
    index: s32;
}

xcb_poly_segment_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    drawable:     xcb_drawable_t;
    gc:           xcb_gcontext_t;
}

xcb_poly_rectangle_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    drawable:     xcb_drawable_t;
    gc:           xcb_gcontext_t;
}

xcb_poly_arc_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    drawable:     xcb_drawable_t;
    gc:           xcb_gcontext_t;
}

xcb_poly_shape_t :: enum u32 {
    COMPLEX   :: 0;
    NONCONVEX :: 1;
    CONVEX    :: 2;

    XCB_POLY_SHAPE_COMPLEX   :: COMPLEX;
    XCB_POLY_SHAPE_NONCONVEX :: NONCONVEX;
    XCB_POLY_SHAPE_CONVEX    :: CONVEX;
}

xcb_fill_poly_request_t :: struct {
    major_opcode:    u8;
    pad0:            u8;
    length:          u16;
    drawable:        xcb_drawable_t;
    gc:              xcb_gcontext_t;
    shape:           u8;
    coordinate_mode: u8;
    pad1:            [2] u8;
}

xcb_poly_fill_rectangle_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    drawable:     xcb_drawable_t;
    gc:           xcb_gcontext_t;
}

xcb_poly_fill_arc_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    drawable:     xcb_drawable_t;
    gc:           xcb_gcontext_t;
}

xcb_image_format_t :: enum u32 {
    XY_BITMAP :: 0;
    XY_PIXMAP :: 1;
    Z_PIXMAP  :: 2;

    XCB_IMAGE_FORMAT_XY_BITMAP :: XY_BITMAP;
    XCB_IMAGE_FORMAT_XY_PIXMAP :: XY_PIXMAP;
    XCB_IMAGE_FORMAT_Z_PIXMAP  :: Z_PIXMAP;
}

xcb_put_image_request_t :: struct {
    major_opcode: u8;
    format:       u8;
    length:       u16;
    drawable:     xcb_drawable_t;
    gc:           xcb_gcontext_t;
    width:        u16;
    height:       u16;
    dst_x:        s16;
    dst_y:        s16;
    left_pad:     u8;
    depth:        u8;
    pad0:         [2] u8;
}

xcb_get_image_cookie_t :: struct {
    sequence: u32;
}

xcb_get_image_request_t :: struct {
    major_opcode: u8;
    format:       u8;
    length:       u16;
    drawable:     xcb_drawable_t;
    x:            s16;
    y:            s16;
    width:        u16;
    height:       u16;
    plane_mask:   u32;
}

xcb_get_image_reply_t :: struct {
    response_type: u8;
    depth:         u8;
    sequence:      u16;
    length:        u32;
    visual:        xcb_visualid_t;
    pad0:          [20] u8;
}

xcb_poly_text_8_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    drawable:     xcb_drawable_t;
    gc:           xcb_gcontext_t;
    x:            s16;
    y:            s16;
}

xcb_poly_text_16_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    drawable:     xcb_drawable_t;
    gc:           xcb_gcontext_t;
    x:            s16;
    y:            s16;
}

xcb_image_text_8_request_t :: struct {
    major_opcode: u8;
    string_len:   u8;
    length:       u16;
    drawable:     xcb_drawable_t;
    gc:           xcb_gcontext_t;
    x:            s16;
    y:            s16;
}

xcb_image_text_16_request_t :: struct {
    major_opcode: u8;
    string_len:   u8;
    length:       u16;
    drawable:     xcb_drawable_t;
    gc:           xcb_gcontext_t;
    x:            s16;
    y:            s16;
}

xcb_colormap_alloc_t :: enum u32 {
    NONE :: 0;
    ALL  :: 1;

    XCB_COLORMAP_ALLOC_NONE :: NONE;
    XCB_COLORMAP_ALLOC_ALL  :: ALL;
}

xcb_create_colormap_request_t :: struct {
    major_opcode: u8;
    alloc:        u8;
    length:       u16;
    mid:          xcb_colormap_t;
    window:       xcb_window_t;
    visual:       xcb_visualid_t;
}

xcb_free_colormap_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cmap:         xcb_colormap_t;
}

xcb_copy_colormap_and_free_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    mid:          xcb_colormap_t;
    src_cmap:     xcb_colormap_t;
}

xcb_install_colormap_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cmap:         xcb_colormap_t;
}

xcb_uninstall_colormap_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cmap:         xcb_colormap_t;
}

xcb_list_installed_colormaps_cookie_t :: struct {
    sequence: u32;
}

xcb_list_installed_colormaps_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
}

xcb_list_installed_colormaps_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    cmaps_len:     u16;
    pad1:          [22] u8;
}

xcb_alloc_color_cookie_t :: struct {
    sequence: u32;
}

xcb_alloc_color_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cmap:         xcb_colormap_t;
    red:          u16;
    green:        u16;
    blue:         u16;
    pad1:         [2] u8;
}

xcb_alloc_color_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    red:           u16;
    green:         u16;
    blue:          u16;
    pad1:          [2] u8;
    pixel:         u32;
}

xcb_alloc_named_color_cookie_t :: struct {
    sequence: u32;
}

xcb_alloc_named_color_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cmap:         xcb_colormap_t;
    name_len:     u16;
    pad1:         [2] u8;
}

xcb_alloc_named_color_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    pixel:         u32;
    exact_red:     u16;
    exact_green:   u16;
    exact_blue:    u16;
    visual_red:    u16;
    visual_green:  u16;
    visual_blue:   u16;
}

xcb_alloc_color_cells_cookie_t :: struct {
    sequence: u32;
}

xcb_alloc_color_cells_request_t :: struct {
    major_opcode: u8;
    contiguous:   u8;
    length:       u16;
    cmap:         xcb_colormap_t;
    colors:       u16;
    planes:       u16;
}

xcb_alloc_color_cells_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    pixels_len:    u16;
    masks_len:     u16;
    pad1:          [20] u8;
}

xcb_alloc_color_planes_cookie_t :: struct {
    sequence: u32;
}

xcb_alloc_color_planes_request_t :: struct {
    major_opcode: u8;
    contiguous:   u8;
    length:       u16;
    cmap:         xcb_colormap_t;
    colors:       u16;
    reds:         u16;
    greens:       u16;
    blues:        u16;
}

xcb_alloc_color_planes_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    pixels_len:    u16;
    pad1:          [2] u8;
    red_mask:      u32;
    green_mask:    u32;
    blue_mask:     u32;
    pad2:          [8] u8;
}

xcb_free_colors_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cmap:         xcb_colormap_t;
    plane_mask:   u32;
}

xcb_color_flag_t :: enum u32 {
    RED   :: 1;
    GREEN :: 2;
    BLUE  :: 4;

    XCB_COLOR_FLAG_RED   :: RED;
    XCB_COLOR_FLAG_GREEN :: GREEN;
    XCB_COLOR_FLAG_BLUE  :: BLUE;
}

xcb_coloritem_t :: struct {
    pixel: u32;
    red:   u16;
    green: u16;
    blue:  u16;
    flags: u8;
    pad0:  u8;
}

xcb_coloritem_iterator_t :: struct {
    data:  *xcb_coloritem_t;
    rem:   s32;
    index: s32;
}

xcb_store_colors_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cmap:         xcb_colormap_t;
}

xcb_store_named_color_request_t :: struct {
    major_opcode: u8;
    flags:        u8;
    length:       u16;
    cmap:         xcb_colormap_t;
    pixel:        u32;
    name_len:     u16;
    pad0:         [2] u8;
}

xcb_rgb_t :: struct {
    red:   u16;
    green: u16;
    blue:  u16;
    pad0:  [2] u8;
}

xcb_rgb_iterator_t :: struct {
    data:  *xcb_rgb_t;
    rem:   s32;
    index: s32;
}

xcb_query_colors_cookie_t :: struct {
    sequence: u32;
}

xcb_query_colors_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cmap:         xcb_colormap_t;
}

xcb_query_colors_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    colors_len:    u16;
    pad1:          [22] u8;
}

xcb_lookup_color_cookie_t :: struct {
    sequence: u32;
}

xcb_lookup_color_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cmap:         xcb_colormap_t;
    name_len:     u16;
    pad1:         [2] u8;
}

xcb_lookup_color_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    exact_red:     u16;
    exact_green:   u16;
    exact_blue:    u16;
    visual_red:    u16;
    visual_green:  u16;
    visual_blue:   u16;
}

xcb_pixmap_enum_t :: enum u32 {
    XCB_PIXMAP_NONE :: 0;
}

xcb_create_cursor_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cid:          xcb_cursor_t;
    source:       xcb_pixmap_t;
    mask:         xcb_pixmap_t;
    fore_red:     u16;
    fore_green:   u16;
    fore_blue:    u16;
    back_red:     u16;
    back_green:   u16;
    back_blue:    u16;
    x:            u16;
    y:            u16;
}

xcb_font_enum_t :: enum u32 {
    XCB_FONT_NONE :: 0;
}

xcb_create_glyph_cursor_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cid:          xcb_cursor_t;
    source_font:  xcb_font_t;
    mask_font:    xcb_font_t;
    source_char:  u16;
    mask_char:    u16;
    fore_red:     u16;
    fore_green:   u16;
    fore_blue:    u16;
    back_red:     u16;
    back_green:   u16;
    back_blue:    u16;
}

xcb_free_cursor_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cursor:       xcb_cursor_t;
}

xcb_recolor_cursor_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    cursor:       xcb_cursor_t;
    fore_red:     u16;
    fore_green:   u16;
    fore_blue:    u16;
    back_red:     u16;
    back_green:   u16;
    back_blue:    u16;
}

xcb_query_shape_of_t :: enum u8 {
    LARGEST_CURSOR  :: 0;
    FASTEST_TILE    :: 1;
    FASTEST_STIPPLE :: 2;

    XCB_QUERY_SHAPE_OF_LARGEST_CURSOR  :: LARGEST_CURSOR;
    XCB_QUERY_SHAPE_OF_FASTEST_TILE    :: FASTEST_TILE;
    XCB_QUERY_SHAPE_OF_FASTEST_STIPPLE :: FASTEST_STIPPLE;
}

xcb_query_best_size_cookie_t :: struct {
    sequence: u32;
}

xcb_query_best_size_request_t :: struct {
    major_opcode: u8;
    _class:       u8;
    length:       u16;
    drawable:     xcb_drawable_t;
    width:        u16;
    height:       u16;
}

xcb_query_best_size_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    width:         u16;
    height:        u16;
}

xcb_query_extension_cookie_t :: struct {
    sequence: u32;
}

xcb_query_extension_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    name_len:     u16;
    pad1:         [2] u8;
}

xcb_query_extension_reply_t :: struct {
    response_type: u8;
    pad0:          u8;
    sequence:      u16;
    length:        u32;
    present:       u8;
    major_opcode:  u8;
    first_event:   u8;
    first_error:   u8;
}

xcb_list_extensions_cookie_t :: struct {
    sequence: u32;
}

xcb_list_extensions_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
}

xcb_list_extensions_reply_t :: struct {
    response_type: u8;
    names_len:     u8;
    sequence:      u16;
    length:        u32;
    pad0:          [24] u8;
}

xcb_change_keyboard_mapping_request_t :: struct {
    major_opcode:        u8;
    keycode_count:       u8;
    length:              u16;
    first_keycode:       xcb_keycode_t;
    keysyms_per_keycode: u8;
    pad0:                [2] u8;
}

xcb_get_keyboard_mapping_cookie_t :: struct {
    sequence: u32;
}

xcb_get_keyboard_mapping_request_t :: struct {
    major_opcode:  u8;
    pad0:          u8;
    length:        u16;
    first_keycode: xcb_keycode_t;
    count:         u8;
}

xcb_get_keyboard_mapping_reply_t :: struct {
    response_type:       u8;
    keysyms_per_keycode: u8;
    sequence:            u16;
    length:              u32;
    pad0:                [24] u8;
}

xcb_kb_t :: enum u32 {
    KEY_CLICK_PERCENT :: 1;
    BELL_PERCENT      :: 2;
    BELL_PITCH        :: 4;
    BELL_DURATION     :: 8;
    LED               :: 16;
    LED_MODE          :: 32;
    KEY               :: 64;
    AUTO_REPEAT_MODE  :: 128;

    XCB_KB_KEY_CLICK_PERCENT :: KEY_CLICK_PERCENT;
    XCB_KB_BELL_PERCENT      :: BELL_PERCENT;
    XCB_KB_BELL_PITCH        :: BELL_PITCH;
    XCB_KB_BELL_DURATION     :: BELL_DURATION;
    XCB_KB_LED               :: LED;
    XCB_KB_LED_MODE          :: LED_MODE;
    XCB_KB_KEY               :: KEY;
    XCB_KB_AUTO_REPEAT_MODE  :: AUTO_REPEAT_MODE;
}

xcb_led_mode_t :: enum u32 {
    OFF :: 0;
    ON  :: 1;

    XCB_LED_MODE_OFF :: OFF;
    XCB_LED_MODE_ON  :: ON;
}

xcb_auto_repeat_mode_t :: enum u32 {
    OFF     :: 0;
    ON      :: 1;
    DEFAULT :: 2;

    XCB_AUTO_REPEAT_MODE_OFF     :: OFF;
    XCB_AUTO_REPEAT_MODE_ON      :: ON;
    XCB_AUTO_REPEAT_MODE_DEFAULT :: DEFAULT;
}

xcb_change_keyboard_control_value_list_t :: struct {
    key_click_percent: s32;
    bell_percent:      s32;
    bell_pitch:        s32;
    bell_duration:     s32;
    led:               u32;
    led_mode:          u32;
    key:               xcb_keycode32_t;
    auto_repeat_mode:  u32;
}

xcb_change_keyboard_control_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    value_mask:   u32;
}

xcb_get_keyboard_control_cookie_t :: struct {
    sequence: u32;
}

xcb_get_keyboard_control_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
}

xcb_get_keyboard_control_reply_t :: struct {
    response_type:      u8;
    global_auto_repeat: u8;
    sequence:           u16;
    length:             u32;
    led_mask:           u32;
    key_click_percent:  u8;
    bell_percent:       u8;
    bell_pitch:         u16;
    bell_duration:      u16;
    pad0:               [2] u8;
    auto_repeats:       [32] u8;
}

xcb_bell_request_t :: struct {
    major_opcode: u8;
    percent:      s8;
    length:       u16;
}

xcb_change_pointer_control_request_t :: struct {
    major_opcode:             u8;
    pad0:                     u8;
    length:                   u16;
    acceleration_numerator:   s16;
    acceleration_denominator: s16;
    threshold:                s16;
    do_acceleration:          u8;
    do_threshold:             u8;
}

xcb_get_pointer_control_cookie_t :: struct {
    sequence: u32;
}

xcb_get_pointer_control_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
}

xcb_get_pointer_control_reply_t :: struct {
    response_type:            u8;
    pad0:                     u8;
    sequence:                 u16;
    length:                   u32;
    acceleration_numerator:   u16;
    acceleration_denominator: u16;
    threshold:                u16;
    pad1:                     [18] u8;
}

xcb_blanking_t :: enum u32 {
    NOT_PREFERRED :: 0;
    PREFERRED     :: 1;
    DEFAULT       :: 2;

    XCB_BLANKING_NOT_PREFERRED :: NOT_PREFERRED;
    XCB_BLANKING_PREFERRED     :: PREFERRED;
    XCB_BLANKING_DEFAULT       :: DEFAULT;
}

xcb_exposures_t :: enum u32 {
    NOT_ALLOWED :: 0;
    ALLOWED     :: 1;
    DEFAULT     :: 2;

    XCB_EXPOSURES_NOT_ALLOWED :: NOT_ALLOWED;
    XCB_EXPOSURES_ALLOWED     :: ALLOWED;
    XCB_EXPOSURES_DEFAULT     :: DEFAULT;
}

xcb_set_screen_saver_request_t :: struct {
    major_opcode:    u8;
    pad0:            u8;
    length:          u16;
    timeout:         s16;
    interval:        s16;
    prefer_blanking: u8;
    allow_exposures: u8;
}

xcb_get_screen_saver_cookie_t :: struct {
    sequence: u32;
}

xcb_get_screen_saver_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
}

xcb_get_screen_saver_reply_t :: struct {
    response_type:   u8;
    pad0:            u8;
    sequence:        u16;
    length:          u32;
    timeout:         u16;
    interval:        u16;
    prefer_blanking: u8;
    allow_exposures: u8;
    pad1:            [18] u8;
}

xcb_host_mode_t :: enum u32 {
    INSERT :: 0;
    DELETE :: 1;

    XCB_HOST_MODE_INSERT :: INSERT;
    XCB_HOST_MODE_DELETE :: DELETE;
}

xcb_family_t :: enum u32 {
    INTERNET           :: 0;
    DECNET             :: 1;
    CHAOS              :: 2;
    SERVER_INTERPRETED :: 5;
    INTERNET_6         :: 6;

    XCB_FAMILY_INTERNET           :: INTERNET;
    XCB_FAMILY_DECNET             :: DECNET;
    XCB_FAMILY_CHAOS              :: CHAOS;
    XCB_FAMILY_SERVER_INTERPRETED :: SERVER_INTERPRETED;
    XCB_FAMILY_INTERNET_6         :: INTERNET_6;
}

xcb_change_hosts_request_t :: struct {
    major_opcode: u8;
    mode:         u8;
    length:       u16;
    family:       u8;
    pad0:         u8;
    address_len:  u16;
}

xcb_host_t :: struct {
    family:      u8;
    pad0:        u8;
    address_len: u16;
}

xcb_host_iterator_t :: struct {
    data:  *xcb_host_t;
    rem:   s32;
    index: s32;
}

xcb_list_hosts_cookie_t :: struct {
    sequence: u32;
}

xcb_list_hosts_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
}

xcb_list_hosts_reply_t :: struct {
    response_type: u8;
    mode:          u8;
    sequence:      u16;
    length:        u32;
    hosts_len:     u16;
    pad0:          [22] u8;
}

xcb_access_control_t :: enum u32 {
    DISABLE :: 0;
    ENABLE  :: 1;

    XCB_ACCESS_CONTROL_DISABLE :: DISABLE;
    XCB_ACCESS_CONTROL_ENABLE  :: ENABLE;
}

xcb_set_access_control_request_t :: struct {
    major_opcode: u8;
    mode:         u8;
    length:       u16;
}

xcb_close_down_t :: enum u32 {
    DESTROY_ALL      :: 0;
    RETAIN_PERMANENT :: 1;
    RETAIN_TEMPORARY :: 2;

    XCB_CLOSE_DOWN_DESTROY_ALL      :: DESTROY_ALL;
    XCB_CLOSE_DOWN_RETAIN_PERMANENT :: RETAIN_PERMANENT;
    XCB_CLOSE_DOWN_RETAIN_TEMPORARY :: RETAIN_TEMPORARY;
}

xcb_set_close_down_mode_request_t :: struct {
    major_opcode: u8;
    mode:         u8;
    length:       u16;
}

xcb_kill_t :: enum u32 {
    XCB_KILL_ALL_TEMPORARY :: 0;
}

xcb_kill_client_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    resource:     u32;
}

xcb_rotate_properties_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
    window:       xcb_window_t;
    atoms_len:    u16;
    delta:        s16;
}

xcb_screen_saver_t :: enum u32 {
    RESET  :: 0;
    ACTIVE :: 1;

    XCB_SCREEN_SAVER_RESET  :: RESET;
    XCB_SCREEN_SAVER_ACTIVE :: ACTIVE;
}

xcb_force_screen_saver_request_t :: struct {
    major_opcode: u8;
    mode:         u8;
    length:       u16;
}

xcb_mapping_status_t :: enum u32 {
    SUCCESS :: 0;
    BUSY    :: 1;
    FAILURE :: 2;

    XCB_MAPPING_STATUS_SUCCESS :: SUCCESS;
    XCB_MAPPING_STATUS_BUSY    :: BUSY;
    XCB_MAPPING_STATUS_FAILURE :: FAILURE;
}

xcb_set_pointer_mapping_cookie_t :: struct {
    sequence: u32;
}

xcb_set_pointer_mapping_request_t :: struct {
    major_opcode: u8;
    map_len:      u8;
    length:       u16;
}

xcb_set_pointer_mapping_reply_t :: struct {
    response_type: u8;
    status:        u8;
    sequence:      u16;
    length:        u32;
}

xcb_get_pointer_mapping_cookie_t :: struct {
    sequence: u32;
}

xcb_get_pointer_mapping_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
}

xcb_get_pointer_mapping_reply_t :: struct {
    response_type: u8;
    map_len:       u8;
    sequence:      u16;
    length:        u32;
    pad0:          [24] u8;
}

xcb_map_index_t :: enum u32 {
    SHIFT   :: 0;
    LOCK    :: 1;
    CONTROL :: 2;
    _1      :: 3;
    _2      :: 4;
    _3      :: 5;
    _4      :: 6;
    _5      :: 7;

    XCB_MAP_INDEX_SHIFT   :: SHIFT;
    XCB_MAP_INDEX_LOCK    :: LOCK;
    XCB_MAP_INDEX_CONTROL :: CONTROL;
    XCB_MAP_INDEX_1       :: _1;
    XCB_MAP_INDEX_2       :: _2;
    XCB_MAP_INDEX_3       :: _3;
    XCB_MAP_INDEX_4       :: _4;
    XCB_MAP_INDEX_5       :: _5;
}

xcb_set_modifier_mapping_cookie_t :: struct {
    sequence: u32;
}

xcb_set_modifier_mapping_request_t :: struct {
    major_opcode:          u8;
    keycodes_per_modifier: u8;
    length:                u16;
}

xcb_set_modifier_mapping_reply_t :: struct {
    response_type: u8;
    status:        u8;
    sequence:      u16;
    length:        u32;
}

xcb_get_modifier_mapping_cookie_t :: struct {
    sequence: u32;
}

xcb_get_modifier_mapping_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
}

xcb_get_modifier_mapping_reply_t :: struct {
    response_type:         u8;
    keycodes_per_modifier: u8;
    sequence:              u16;
    length:                u32;
    pad0:                  [24] u8;
}

xcb_no_operation_request_t :: struct {
    major_opcode: u8;
    pad0:         u8;
    length:       u16;
}

xcb_auth_info_t :: struct {
    namelen: s32;
    name:    *u8;
    datalen: s32;
    data:    *u8;
}

xcb_special_event :: struct {}
xcb_special_event_t :: xcb_special_event;

xcb_extension_t :: struct {}

XCB_Symbols :: struct #type_info_procedures_are_void_pointers #type_info_no_size_complaint {
    char2b_next:                                      #type (i: *xcb_char2b_iterator_t) -> void #c_call;
    char2b_end:                                       #type (i: xcb_char2b_iterator_t) -> xcb_generic_iterator_t #c_call;
    window_next:                                      #type (i: *xcb_window_iterator_t) -> void #c_call;
    window_end:                                       #type (i: xcb_window_iterator_t) -> xcb_generic_iterator_t #c_call;
    pixmap_next:                                      #type (i: *xcb_pixmap_iterator_t) -> void #c_call;
    pixmap_end:                                       #type (i: xcb_pixmap_iterator_t) -> xcb_generic_iterator_t #c_call;
    cursor_next:                                      #type (i: *xcb_cursor_iterator_t) -> void #c_call;
    cursor_end:                                       #type (i: xcb_cursor_iterator_t) -> xcb_generic_iterator_t #c_call;
    font_next:                                        #type (i: *xcb_font_iterator_t) -> void #c_call;
    font_end:                                         #type (i: xcb_font_iterator_t) -> xcb_generic_iterator_t #c_call;
    gcontext_next:                                    #type (i: *xcb_gcontext_iterator_t) -> void #c_call;
    gcontext_end:                                     #type (i: xcb_gcontext_iterator_t) -> xcb_generic_iterator_t #c_call;
    colormap_next:                                    #type (i: *xcb_colormap_iterator_t) -> void #c_call;
    colormap_end:                                     #type (i: xcb_colormap_iterator_t) -> xcb_generic_iterator_t #c_call;
    atom_next:                                        #type (i: *xcb_atom_iterator_t) -> void #c_call;
    atom_end:                                         #type (i: xcb_atom_iterator_t) -> xcb_generic_iterator_t #c_call;
    drawable_next:                                    #type (i: *xcb_drawable_iterator_t) -> void #c_call;
    drawable_end:                                     #type (i: xcb_drawable_iterator_t) -> xcb_generic_iterator_t #c_call;
    fontable_next:                                    #type (i: *xcb_fontable_iterator_t) -> void #c_call;
    fontable_end:                                     #type (i: xcb_fontable_iterator_t) -> xcb_generic_iterator_t #c_call;
    bool32_next:                                      #type (i: *xcb_bool32_iterator_t) -> void #c_call;
    bool32_end:                                       #type (i: xcb_bool32_iterator_t) -> xcb_generic_iterator_t #c_call;
    visualid_next:                                    #type (i: *xcb_visualid_iterator_t) -> void #c_call;
    visualid_end:                                     #type (i: xcb_visualid_iterator_t) -> xcb_generic_iterator_t #c_call;
    timestamp_next:                                   #type (i: *xcb_timestamp_iterator_t) -> void #c_call;
    timestamp_end:                                    #type (i: xcb_timestamp_iterator_t) -> xcb_generic_iterator_t #c_call;
    keysym_next:                                      #type (i: *xcb_keysym_iterator_t) -> void #c_call;
    keysym_end:                                       #type (i: xcb_keysym_iterator_t) -> xcb_generic_iterator_t #c_call;
    keycode_next:                                     #type (i: *xcb_keycode_iterator_t) -> void #c_call;
    keycode_end:                                      #type (i: xcb_keycode_iterator_t) -> xcb_generic_iterator_t #c_call;
    keycode32_next:                                   #type (i: *xcb_keycode32_iterator_t) -> void #c_call;
    keycode32_end:                                    #type (i: xcb_keycode32_iterator_t) -> xcb_generic_iterator_t #c_call;
    button_next:                                      #type (i: *xcb_button_iterator_t) -> void #c_call;
    button_end:                                       #type (i: xcb_button_iterator_t) -> xcb_generic_iterator_t #c_call;
    point_next:                                       #type (i: *xcb_point_iterator_t) -> void #c_call;
    point_end:                                        #type (i: xcb_point_iterator_t) -> xcb_generic_iterator_t #c_call;
    rectangle_next:                                   #type (i: *xcb_rectangle_iterator_t) -> void #c_call;
    rectangle_end:                                    #type (i: xcb_rectangle_iterator_t) -> xcb_generic_iterator_t #c_call;
    arc_next:                                         #type (i: *xcb_arc_iterator_t) -> void #c_call;
    arc_end:                                          #type (i: xcb_arc_iterator_t) -> xcb_generic_iterator_t #c_call;
    format_next:                                      #type (i: *xcb_format_iterator_t) -> void #c_call;
    format_end:                                       #type (i: xcb_format_iterator_t) -> xcb_generic_iterator_t #c_call;
    visualtype_next:                                  #type (i: *xcb_visualtype_iterator_t) -> void #c_call;
    visualtype_end:                                   #type (i: xcb_visualtype_iterator_t) -> xcb_generic_iterator_t #c_call;
    depth_sizeof:                                     #type (_buffer: *void) -> s32 #c_call;
    depth_visuals:                                    #type (R: *xcb_depth_t) -> *xcb_visualtype_t #c_call;
    depth_visuals_length:                             #type (R: *xcb_depth_t) -> s32 #c_call;
    depth_visuals_iterator:                           #type (R: *xcb_depth_t) -> xcb_visualtype_iterator_t #c_call;
    depth_next:                                       #type (i: *xcb_depth_iterator_t) -> void #c_call;
    depth_end:                                        #type (i: xcb_depth_iterator_t) -> xcb_generic_iterator_t #c_call;
    screen_sizeof:                                    #type (_buffer: *void) -> s32 #c_call;
    screen_allowed_depths_length:                     #type (R: *xcb_screen_t) -> s32 #c_call;
    screen_allowed_depths_iterator:                   #type (R: *xcb_screen_t) -> xcb_depth_iterator_t #c_call;
    screen_next:                                      #type (i: *xcb_screen_iterator_t) -> void #c_call;
    screen_end:                                       #type (i: xcb_screen_iterator_t) -> xcb_generic_iterator_t #c_call;
    setup_request_sizeof:                             #type (_buffer: *void) -> s32 #c_call;
    setup_request_authorization_protocol_name:        #type (R: *xcb_setup_request_t) -> *u8 #c_call;
    setup_request_authorization_protocol_name_length: #type (R: *xcb_setup_request_t) -> s32 #c_call;
    setup_request_authorization_protocol_name_end:    #type (R: *xcb_setup_request_t) -> xcb_generic_iterator_t #c_call;
    setup_request_authorization_protocol_data:        #type (R: *xcb_setup_request_t) -> *u8 #c_call;
    setup_request_authorization_protocol_data_length: #type (R: *xcb_setup_request_t) -> s32 #c_call;
    setup_request_authorization_protocol_data_end:    #type (R: *xcb_setup_request_t) -> xcb_generic_iterator_t #c_call;
    setup_request_next:                               #type (i: *xcb_setup_request_iterator_t) -> void #c_call;
    setup_request_end:                                #type (i: xcb_setup_request_iterator_t) -> xcb_generic_iterator_t #c_call;
    setup_failed_sizeof:                              #type (_buffer: *void) -> s32 #c_call;
    setup_failed_reason:                              #type (R: *xcb_setup_failed_t) -> *u8 #c_call;
    setup_failed_reason_length:                       #type (R: *xcb_setup_failed_t) -> s32 #c_call;
    setup_failed_reason_end:                          #type (R: *xcb_setup_failed_t) -> xcb_generic_iterator_t #c_call;
    setup_failed_next:                                #type (i: *xcb_setup_failed_iterator_t) -> void #c_call;
    setup_failed_end:                                 #type (i: xcb_setup_failed_iterator_t) -> xcb_generic_iterator_t #c_call;
    setup_authenticate_sizeof:                        #type (_buffer: *void) -> s32 #c_call;
    setup_authenticate_reason:                        #type (R: *xcb_setup_authenticate_t) -> *u8 #c_call;
    setup_authenticate_reason_length:                 #type (R: *xcb_setup_authenticate_t) -> s32 #c_call;
    setup_authenticate_reason_end:                    #type (R: *xcb_setup_authenticate_t) -> xcb_generic_iterator_t #c_call;
    setup_authenticate_next:                          #type (i: *xcb_setup_authenticate_iterator_t) -> void #c_call;
    setup_authenticate_end:                           #type (i: xcb_setup_authenticate_iterator_t) -> xcb_generic_iterator_t #c_call;
    setup_sizeof:                                     #type (_buffer: *void) -> s32 #c_call;
    setup_vendor:                                     #type (R: *xcb_setup_t) -> *u8 #c_call;
    setup_vendor_length:                              #type (R: *xcb_setup_t) -> s32 #c_call;
    setup_vendor_end:                                 #type (R: *xcb_setup_t) -> xcb_generic_iterator_t #c_call;
    setup_pixmap_formats:                             #type (R: *xcb_setup_t) -> *xcb_format_t #c_call;
    setup_pixmap_formats_length:                      #type (R: *xcb_setup_t) -> s32 #c_call;
    setup_pixmap_formats_iterator:                    #type (R: *xcb_setup_t) -> xcb_format_iterator_t #c_call;
    setup_roots_length:                               #type (R: *xcb_setup_t) -> s32 #c_call;
    setup_roots_iterator:                             #type (R: *xcb_setup_t) -> xcb_screen_iterator_t #c_call;
    setup_next:                                       #type (i: *xcb_setup_iterator_t) -> void #c_call;
    setup_end:                                        #type (i: xcb_setup_iterator_t) -> xcb_generic_iterator_t #c_call;
    client_message_data_next:                         #type (i: *xcb_client_message_data_iterator_t) -> void #c_call;
    client_message_data_end:                          #type (i: xcb_client_message_data_iterator_t) -> xcb_generic_iterator_t #c_call;
    create_window_value_list_serialize:               #type (_buffer: **void, value_mask: u32, _aux: *xcb_create_window_value_list_t) -> s32 #c_call;
    create_window_value_list_unpack:                  #type (_buffer: *void, value_mask: u32, _aux: *xcb_create_window_value_list_t) -> s32 #c_call;
    create_window_value_list_sizeof:                  #type (_buffer: *void, value_mask: u32) -> s32 #c_call;
    create_window_sizeof:                             #type (_buffer: *void) -> s32 #c_call;
    create_window_checked:                            #type (c: *xcb_connection_t, depth: u8, wid: xcb_window_t, parent: xcb_window_t, x: s16, y: s16, width: u16, height: u16, border_width: u16, _class: xcb_window_class_t, visual: xcb_visualid_t, value_mask: xcb_cw_t, value_list: *void) -> xcb_void_cookie_t #c_call;
    create_window:                                    #type (c: *xcb_connection_t, depth: u8, wid: xcb_window_t, parent: xcb_window_t, x: s16, y: s16, width: u16, height: u16, border_width: u16, _class: xcb_window_class_t, visual: xcb_visualid_t, value_mask: xcb_cw_t, value_list: *void) -> xcb_void_cookie_t #c_call;
    create_window_aux_checked:                        #type (c: *xcb_connection_t, depth: u8, wid: xcb_window_t, parent: xcb_window_t, x: s16, y: s16, width: u16, height: u16, border_width: u16, _class: xcb_window_class_t, visual: xcb_visualid_t, value_mask: xcb_cw_t, value_list: *xcb_create_window_value_list_t) -> xcb_void_cookie_t #c_call;
    create_window_aux:                                #type (c: *xcb_connection_t, depth: u8, wid: xcb_window_t, parent: xcb_window_t, x: s16, y: s16, width: u16, height: u16, border_width: u16, _class: xcb_window_class_t, visual: xcb_visualid_t, value_mask: xcb_cw_t, value_list: *xcb_create_window_value_list_t) -> xcb_void_cookie_t #c_call;
    create_window_value_list:                         #type (R: *xcb_create_window_request_t) -> *void #c_call;
    change_window_attributes_value_list_serialize:    #type (_buffer: **void, value_mask: u32, _aux: *xcb_change_window_attributes_value_list_t) -> s32 #c_call;
    change_window_attributes_value_list_unpack:       #type (_buffer: *void, value_mask: u32, _aux: *xcb_change_window_attributes_value_list_t) -> s32 #c_call;
    change_window_attributes_value_list_sizeof:       #type (_buffer: *void, value_mask: u32) -> s32 #c_call;
    change_window_attributes_sizeof:                  #type (_buffer: *void) -> s32 #c_call;
    change_window_attributes_checked:                 #type (c: *xcb_connection_t, window: xcb_window_t, value_mask: xcb_cw_t, value_list: *void) -> xcb_void_cookie_t #c_call;
    change_window_attributes:                         #type (c: *xcb_connection_t, window: xcb_window_t, value_mask: xcb_cw_t, value_list: *void) -> xcb_void_cookie_t #c_call;
    change_window_attributes_aux_checked:             #type (c: *xcb_connection_t, window: xcb_window_t, value_mask: xcb_cw_t, value_list: *xcb_change_window_attributes_value_list_t) -> xcb_void_cookie_t #c_call;
    change_window_attributes_aux:                     #type (c: *xcb_connection_t, window: xcb_window_t, value_mask: xcb_cw_t, value_list: *xcb_change_window_attributes_value_list_t) -> xcb_void_cookie_t #c_call;
    change_window_attributes_value_list:              #type (R: *xcb_change_window_attributes_request_t) -> *void #c_call;
    get_window_attributes:                            #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_get_window_attributes_cookie_t #c_call;
    get_window_attributes_unchecked:                  #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_get_window_attributes_cookie_t #c_call;
    get_window_attributes_reply:                      #type (c: *xcb_connection_t, cookie: xcb_get_window_attributes_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_window_attributes_reply_t #c_call;
    destroy_window_checked:                           #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    destroy_window:                                   #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    destroy_subwindows_checked:                       #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    destroy_subwindows:                               #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    change_save_set_checked:                          #type (c: *xcb_connection_t, mode: u8, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    change_save_set:                                  #type (c: *xcb_connection_t, mode: u8, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    reparent_window_checked:                          #type (c: *xcb_connection_t, window: xcb_window_t, parent: xcb_window_t, x: s16, y: s16) -> xcb_void_cookie_t #c_call;
    reparent_window:                                  #type (c: *xcb_connection_t, window: xcb_window_t, parent: xcb_window_t, x: s16, y: s16) -> xcb_void_cookie_t #c_call;
    map_window_checked:                               #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    map_window:                                       #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    map_subwindows_checked:                           #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    map_subwindows:                                   #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    unmap_window_checked:                             #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    unmap_window:                                     #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    unmap_subwindows_checked:                         #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    unmap_subwindows:                                 #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    configure_window_value_list_serialize:            #type (_buffer: **void, value_mask: u16, _aux: *xcb_configure_window_value_list_t) -> s32 #c_call;
    configure_window_value_list_unpack:               #type (_buffer: *void, value_mask: u16, _aux: *xcb_configure_window_value_list_t) -> s32 #c_call;
    configure_window_value_list_sizeof:               #type (_buffer: *void, value_mask: u16) -> s32 #c_call;
    configure_window_sizeof:                          #type (_buffer: *void) -> s32 #c_call;
    configure_window_checked:                         #type (c: *xcb_connection_t, window: xcb_window_t, value_mask: u16, value_list: *void) -> xcb_void_cookie_t #c_call;
    configure_window:                                 #type (c: *xcb_connection_t, window: xcb_window_t, value_mask: u16, value_list: *void) -> xcb_void_cookie_t #c_call;
    configure_window_aux_checked:                     #type (c: *xcb_connection_t, window: xcb_window_t, value_mask: u16, value_list: *xcb_configure_window_value_list_t) -> xcb_void_cookie_t #c_call;
    configure_window_aux:                             #type (c: *xcb_connection_t, window: xcb_window_t, value_mask: u16, value_list: *xcb_configure_window_value_list_t) -> xcb_void_cookie_t #c_call;
    configure_window_value_list:                      #type (R: *xcb_configure_window_request_t) -> *void #c_call;
    circulate_window_checked:                         #type (c: *xcb_connection_t, direction: u8, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    circulate_window:                                 #type (c: *xcb_connection_t, direction: u8, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    get_geometry:                                     #type (c: *xcb_connection_t, drawable: xcb_drawable_t) -> xcb_get_geometry_cookie_t #c_call;
    get_geometry_unchecked:                           #type (c: *xcb_connection_t, drawable: xcb_drawable_t) -> xcb_get_geometry_cookie_t #c_call;
    get_geometry_reply:                               #type (c: *xcb_connection_t, cookie: xcb_get_geometry_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_geometry_reply_t #c_call;
    query_tree_sizeof:                                #type (_buffer: *void) -> s32 #c_call;
    query_tree:                                       #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_query_tree_cookie_t #c_call;
    query_tree_unchecked:                             #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_query_tree_cookie_t #c_call;
    query_tree_children:                              #type (R: *xcb_query_tree_reply_t) -> *xcb_window_t #c_call;
    query_tree_children_length:                       #type (R: *xcb_query_tree_reply_t) -> s32 #c_call;
    query_tree_children_end:                          #type (R: *xcb_query_tree_reply_t) -> xcb_generic_iterator_t #c_call;
    query_tree_reply:                                 #type (c: *xcb_connection_t, cookie: xcb_query_tree_cookie_t, e: **xcb_generic_error_t) -> *xcb_query_tree_reply_t #c_call;
    intern_atom_sizeof:                               #type (_buffer: *void) -> s32 #c_call;
    intern_atom:                                      #type (c: *xcb_connection_t, only_if_exists: u8, name_len: u16, name: *u8) -> xcb_intern_atom_cookie_t #c_call;
    intern_atom_unchecked:                            #type (c: *xcb_connection_t, only_if_exists: u8, name_len: u16, name: *u8) -> xcb_intern_atom_cookie_t #c_call;
    intern_atom_reply:                                #type (c: *xcb_connection_t, cookie: xcb_intern_atom_cookie_t, e: **xcb_generic_error_t) -> *xcb_intern_atom_reply_t #c_call;
    get_atom_name_sizeof:                             #type (_buffer: *void) -> s32 #c_call;
    get_atom_name:                                    #type (c: *xcb_connection_t, atom: xcb_atom_t) -> xcb_get_atom_name_cookie_t #c_call;
    get_atom_name_unchecked:                          #type (c: *xcb_connection_t, atom: xcb_atom_t) -> xcb_get_atom_name_cookie_t #c_call;
    get_atom_name_name:                               #type (R: *xcb_get_atom_name_reply_t) -> *u8 #c_call;
    get_atom_name_name_length:                        #type (R: *xcb_get_atom_name_reply_t) -> s32 #c_call;
    get_atom_name_name_end:                           #type (R: *xcb_get_atom_name_reply_t) -> xcb_generic_iterator_t #c_call;
    get_atom_name_reply:                              #type (c: *xcb_connection_t, cookie: xcb_get_atom_name_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_atom_name_reply_t #c_call;
    change_property_sizeof:                           #type (_buffer: *void) -> s32 #c_call;
    change_property_checked:                          #type (c: *xcb_connection_t, mode: xcb_prop_mode_t, window: xcb_window_t, property: xcb_atom_t, type: xcb_atom_t, format: u8, data_len: u32, data: *void) -> xcb_void_cookie_t #c_call;
    change_property:                                  #type (c: *xcb_connection_t, mode: xcb_prop_mode_t, window: xcb_window_t, property: xcb_atom_t, type: xcb_atom_t, format: u8, data_len: u32, data: *void) -> xcb_void_cookie_t #c_call;
    change_property_data:                             #type (R: *xcb_change_property_request_t) -> *void #c_call;
    change_property_data_length:                      #type (R: *xcb_change_property_request_t) -> s32 #c_call;
    change_property_data_end:                         #type (R: *xcb_change_property_request_t) -> xcb_generic_iterator_t #c_call;
    delete_property_checked:                          #type (c: *xcb_connection_t, window: xcb_window_t, property: xcb_atom_t) -> xcb_void_cookie_t #c_call;
    delete_property:                                  #type (c: *xcb_connection_t, window: xcb_window_t, property: xcb_atom_t) -> xcb_void_cookie_t #c_call;
    get_property_sizeof:                              #type (_buffer: *void) -> s32 #c_call;
    get_property:                                     #type (c: *xcb_connection_t, _delete: u8, window: xcb_window_t, property: xcb_atom_t, type: xcb_atom_t, long_offset: u32, long_length: u32) -> xcb_get_property_cookie_t #c_call;
    get_property_unchecked:                           #type (c: *xcb_connection_t, _delete: u8, window: xcb_window_t, property: xcb_atom_t, type: xcb_atom_t, long_offset: u32, long_length: u32) -> xcb_get_property_cookie_t #c_call;
    get_property_value:                               #type (R: *xcb_get_property_reply_t) -> *void #c_call;
    get_property_value_length:                        #type (R: *xcb_get_property_reply_t) -> s32 #c_call;
    get_property_value_end:                           #type (R: *xcb_get_property_reply_t) -> xcb_generic_iterator_t #c_call;
    get_property_reply:                               #type (c: *xcb_connection_t, cookie: xcb_get_property_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_property_reply_t #c_call;
    list_properties_sizeof:                           #type (_buffer: *void) -> s32 #c_call;
    list_properties:                                  #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_list_properties_cookie_t #c_call;
    list_properties_unchecked:                        #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_list_properties_cookie_t #c_call;
    list_properties_atoms:                            #type (R: *xcb_list_properties_reply_t) -> *xcb_atom_t #c_call;
    list_properties_atoms_length:                     #type (R: *xcb_list_properties_reply_t) -> s32 #c_call;
    list_properties_atoms_end:                        #type (R: *xcb_list_properties_reply_t) -> xcb_generic_iterator_t #c_call;
    list_properties_reply:                            #type (c: *xcb_connection_t, cookie: xcb_list_properties_cookie_t, e: **xcb_generic_error_t) -> *xcb_list_properties_reply_t #c_call;
    set_selection_owner_checked:                      #type (c: *xcb_connection_t, owner: xcb_window_t, selection: xcb_atom_t, time: xcb_timestamp_t) -> xcb_void_cookie_t #c_call;
    set_selection_owner:                              #type (c: *xcb_connection_t, owner: xcb_window_t, selection: xcb_atom_t, time: xcb_timestamp_t) -> xcb_void_cookie_t #c_call;
    get_selection_owner:                              #type (c: *xcb_connection_t, selection: xcb_atom_t) -> xcb_get_selection_owner_cookie_t #c_call;
    get_selection_owner_unchecked:                    #type (c: *xcb_connection_t, selection: xcb_atom_t) -> xcb_get_selection_owner_cookie_t #c_call;
    get_selection_owner_reply:                        #type (c: *xcb_connection_t, cookie: xcb_get_selection_owner_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_selection_owner_reply_t #c_call;
    convert_selection_checked:                        #type (c: *xcb_connection_t, requestor: xcb_window_t, selection: xcb_atom_t, target: xcb_atom_t, property: xcb_atom_t, time: xcb_timestamp_t) -> xcb_void_cookie_t #c_call;
    convert_selection:                                #type (c: *xcb_connection_t, requestor: xcb_window_t, selection: xcb_atom_t, target: xcb_atom_t, property: xcb_atom_t, time: xcb_timestamp_t) -> xcb_void_cookie_t #c_call;
    send_event_checked:                               #type (c: *xcb_connection_t, propagate: u8, destination: xcb_window_t, event_mask: u32, event: *u8) -> xcb_void_cookie_t #c_call;
    send_event:                                       #type (c: *xcb_connection_t, propagate: u8, destination: xcb_window_t, event_mask: u32, event: *u8) -> xcb_void_cookie_t #c_call;
    grab_pointer:                                     #type (c: *xcb_connection_t, owner_events: u8, grab_window: xcb_window_t, event_mask: u16, pointer_mode: u8, keyboard_mode: u8, confine_to: xcb_window_t, cursor: xcb_cursor_t, time: xcb_timestamp_t) -> xcb_grab_pointer_cookie_t #c_call;
    grab_pointer_unchecked:                           #type (c: *xcb_connection_t, owner_events: u8, grab_window: xcb_window_t, event_mask: u16, pointer_mode: u8, keyboard_mode: u8, confine_to: xcb_window_t, cursor: xcb_cursor_t, time: xcb_timestamp_t) -> xcb_grab_pointer_cookie_t #c_call;
    grab_pointer_reply:                               #type (c: *xcb_connection_t, cookie: xcb_grab_pointer_cookie_t, e: **xcb_generic_error_t) -> *xcb_grab_pointer_reply_t #c_call;
    ungrab_pointer_checked:                           #type (c: *xcb_connection_t, time: xcb_timestamp_t) -> xcb_void_cookie_t #c_call;
    ungrab_pointer:                                   #type (c: *xcb_connection_t, time: xcb_timestamp_t) -> xcb_void_cookie_t #c_call;
    grab_button_checked:                              #type (c: *xcb_connection_t, owner_events: u8, grab_window: xcb_window_t, event_mask: u16, pointer_mode: u8, keyboard_mode: u8, confine_to: xcb_window_t, cursor: xcb_cursor_t, button: u8, modifiers: u16) -> xcb_void_cookie_t #c_call;
    grab_button:                                      #type (c: *xcb_connection_t, owner_events: u8, grab_window: xcb_window_t, event_mask: u16, pointer_mode: u8, keyboard_mode: u8, confine_to: xcb_window_t, cursor: xcb_cursor_t, button: u8, modifiers: u16) -> xcb_void_cookie_t #c_call;
    ungrab_button_checked:                            #type (c: *xcb_connection_t, button: u8, grab_window: xcb_window_t, modifiers: u16) -> xcb_void_cookie_t #c_call;
    ungrab_button:                                    #type (c: *xcb_connection_t, button: u8, grab_window: xcb_window_t, modifiers: u16) -> xcb_void_cookie_t #c_call;
    change_active_pointer_grab_checked:               #type (c: *xcb_connection_t, cursor: xcb_cursor_t, time: xcb_timestamp_t, event_mask: u16) -> xcb_void_cookie_t #c_call;
    change_active_pointer_grab:                       #type (c: *xcb_connection_t, cursor: xcb_cursor_t, time: xcb_timestamp_t, event_mask: u16) -> xcb_void_cookie_t #c_call;
    grab_keyboard:                                    #type (c: *xcb_connection_t, owner_events: u8, grab_window: xcb_window_t, time: xcb_timestamp_t, pointer_mode: u8, keyboard_mode: u8) -> xcb_grab_keyboard_cookie_t #c_call;
    grab_keyboard_unchecked:                          #type (c: *xcb_connection_t, owner_events: u8, grab_window: xcb_window_t, time: xcb_timestamp_t, pointer_mode: u8, keyboard_mode: u8) -> xcb_grab_keyboard_cookie_t #c_call;
    grab_keyboard_reply:                              #type (c: *xcb_connection_t, cookie: xcb_grab_keyboard_cookie_t, e: **xcb_generic_error_t) -> *xcb_grab_keyboard_reply_t #c_call;
    ungrab_keyboard_checked:                          #type (c: *xcb_connection_t, time: xcb_timestamp_t) -> xcb_void_cookie_t #c_call;
    ungrab_keyboard:                                  #type (c: *xcb_connection_t, time: xcb_timestamp_t) -> xcb_void_cookie_t #c_call;
    grab_key_checked:                                 #type (c: *xcb_connection_t, owner_events: u8, grab_window: xcb_window_t, modifiers: u16, key: xcb_keycode_t, pointer_mode: u8, keyboard_mode: u8) -> xcb_void_cookie_t #c_call;
    grab_key:                                         #type (c: *xcb_connection_t, owner_events: u8, grab_window: xcb_window_t, modifiers: u16, key: xcb_keycode_t, pointer_mode: u8, keyboard_mode: u8) -> xcb_void_cookie_t #c_call;
    ungrab_key_checked:                               #type (c: *xcb_connection_t, key: xcb_keycode_t, grab_window: xcb_window_t, modifiers: u16) -> xcb_void_cookie_t #c_call;
    ungrab_key:                                       #type (c: *xcb_connection_t, key: xcb_keycode_t, grab_window: xcb_window_t, modifiers: u16) -> xcb_void_cookie_t #c_call;
    allow_events_checked:                             #type (c: *xcb_connection_t, mode: u8, time: xcb_timestamp_t) -> xcb_void_cookie_t #c_call;
    allow_events:                                     #type (c: *xcb_connection_t, mode: u8, time: xcb_timestamp_t) -> xcb_void_cookie_t #c_call;
    grab_server_checked:                              #type (c: *xcb_connection_t) -> xcb_void_cookie_t #c_call;
    grab_server:                                      #type (c: *xcb_connection_t) -> xcb_void_cookie_t #c_call;
    ungrab_server_checked:                            #type (c: *xcb_connection_t) -> xcb_void_cookie_t #c_call;
    ungrab_server:                                    #type (c: *xcb_connection_t) -> xcb_void_cookie_t #c_call;
    query_pointer:                                    #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_query_pointer_cookie_t #c_call;
    query_pointer_unchecked:                          #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_query_pointer_cookie_t #c_call;
    query_pointer_reply:                              #type (c: *xcb_connection_t, cookie: xcb_query_pointer_cookie_t, e: **xcb_generic_error_t) -> *xcb_query_pointer_reply_t #c_call;
    timecoord_next:                                   #type (i: *xcb_timecoord_iterator_t) -> void #c_call;
    timecoord_end:                                    #type (i: xcb_timecoord_iterator_t) -> xcb_generic_iterator_t #c_call;
    get_motion_events_sizeof:                         #type (_buffer: *void) -> s32 #c_call;
    get_motion_events:                                #type (c: *xcb_connection_t, window: xcb_window_t, start: xcb_timestamp_t, stop: xcb_timestamp_t) -> xcb_get_motion_events_cookie_t #c_call;
    get_motion_events_unchecked:                      #type (c: *xcb_connection_t, window: xcb_window_t, start: xcb_timestamp_t, stop: xcb_timestamp_t) -> xcb_get_motion_events_cookie_t #c_call;
    get_motion_events_events:                         #type (R: *xcb_get_motion_events_reply_t) -> *xcb_timecoord_t #c_call;
    get_motion_events_events_length:                  #type (R: *xcb_get_motion_events_reply_t) -> s32 #c_call;
    get_motion_events_events_iterator:                #type (R: *xcb_get_motion_events_reply_t) -> xcb_timecoord_iterator_t #c_call;
    get_motion_events_reply:                          #type (c: *xcb_connection_t, cookie: xcb_get_motion_events_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_motion_events_reply_t #c_call;
    translate_coordinates:                            #type (c: *xcb_connection_t, src_window: xcb_window_t, dst_window: xcb_window_t, src_x: s16, src_y: s16) -> xcb_translate_coordinates_cookie_t #c_call;
    translate_coordinates_unchecked:                  #type (c: *xcb_connection_t, src_window: xcb_window_t, dst_window: xcb_window_t, src_x: s16, src_y: s16) -> xcb_translate_coordinates_cookie_t #c_call;
    translate_coordinates_reply:                      #type (c: *xcb_connection_t, cookie: xcb_translate_coordinates_cookie_t, e: **xcb_generic_error_t) -> *xcb_translate_coordinates_reply_t #c_call;
    warp_pointer_checked:                             #type (c: *xcb_connection_t, src_window: xcb_window_t, dst_window: xcb_window_t, src_x: s16, src_y: s16, src_width: u16, src_height: u16, dst_x: s16, dst_y: s16) -> xcb_void_cookie_t #c_call;
    warp_pointer:                                     #type (c: *xcb_connection_t, src_window: xcb_window_t, dst_window: xcb_window_t, src_x: s16, src_y: s16, src_width: u16, src_height: u16, dst_x: s16, dst_y: s16) -> xcb_void_cookie_t #c_call;
    set_input_focus_checked:                          #type (c: *xcb_connection_t, revert_to: u8, focus: xcb_window_t, time: xcb_timestamp_t) -> xcb_void_cookie_t #c_call;
    set_input_focus:                                  #type (c: *xcb_connection_t, revert_to: u8, focus: xcb_window_t, time: xcb_timestamp_t) -> xcb_void_cookie_t #c_call;
    get_input_focus:                                  #type (c: *xcb_connection_t) -> xcb_get_input_focus_cookie_t #c_call;
    get_input_focus_unchecked:                        #type (c: *xcb_connection_t) -> xcb_get_input_focus_cookie_t #c_call;
    get_input_focus_reply:                            #type (c: *xcb_connection_t, cookie: xcb_get_input_focus_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_input_focus_reply_t #c_call;
    query_keymap:                                     #type (c: *xcb_connection_t) -> xcb_query_keymap_cookie_t #c_call;
    query_keymap_unchecked:                           #type (c: *xcb_connection_t) -> xcb_query_keymap_cookie_t #c_call;
    query_keymap_reply:                               #type (c: *xcb_connection_t, cookie: xcb_query_keymap_cookie_t, e: **xcb_generic_error_t) -> *xcb_query_keymap_reply_t #c_call;
    open_font_sizeof:                                 #type (_buffer: *void) -> s32 #c_call;
    open_font_checked:                                #type (c: *xcb_connection_t, fid: xcb_font_t, name_len: u16, name: *u8) -> xcb_void_cookie_t #c_call;
    open_font:                                        #type (c: *xcb_connection_t, fid: xcb_font_t, name_len: u16, name: *u8) -> xcb_void_cookie_t #c_call;
    open_font_name:                                   #type (R: *xcb_open_font_request_t) -> *u8 #c_call;
    open_font_name_length:                            #type (R: *xcb_open_font_request_t) -> s32 #c_call;
    open_font_name_end:                               #type (R: *xcb_open_font_request_t) -> xcb_generic_iterator_t #c_call;
    close_font_checked:                               #type (c: *xcb_connection_t, font: xcb_font_t) -> xcb_void_cookie_t #c_call;
    close_font:                                       #type (c: *xcb_connection_t, font: xcb_font_t) -> xcb_void_cookie_t #c_call;
    fontprop_next:                                    #type (i: *xcb_fontprop_iterator_t) -> void #c_call;
    fontprop_end:                                     #type (i: xcb_fontprop_iterator_t) -> xcb_generic_iterator_t #c_call;
    charinfo_next:                                    #type (i: *xcb_charinfo_iterator_t) -> void #c_call;
    charinfo_end:                                     #type (i: xcb_charinfo_iterator_t) -> xcb_generic_iterator_t #c_call;
    query_font_sizeof:                                #type (_buffer: *void) -> s32 #c_call;
    query_font:                                       #type (c: *xcb_connection_t, font: xcb_fontable_t) -> xcb_query_font_cookie_t #c_call;
    query_font_unchecked:                             #type (c: *xcb_connection_t, font: xcb_fontable_t) -> xcb_query_font_cookie_t #c_call;
    query_font_properties:                            #type (R: *xcb_query_font_reply_t) -> *xcb_fontprop_t #c_call;
    query_font_properties_length:                     #type (R: *xcb_query_font_reply_t) -> s32 #c_call;
    query_font_properties_iterator:                   #type (R: *xcb_query_font_reply_t) -> xcb_fontprop_iterator_t #c_call;
    query_font_char_infos:                            #type (R: *xcb_query_font_reply_t) -> *xcb_charinfo_t #c_call;
    query_font_char_infos_length:                     #type (R: *xcb_query_font_reply_t) -> s32 #c_call;
    query_font_char_infos_iterator:                   #type (R: *xcb_query_font_reply_t) -> xcb_charinfo_iterator_t #c_call;
    query_font_reply:                                 #type (c: *xcb_connection_t, cookie: xcb_query_font_cookie_t, e: **xcb_generic_error_t) -> *xcb_query_font_reply_t #c_call;
    query_text_extents_sizeof:                        #type (_buffer: *void, string_len: u32) -> s32 #c_call;
    query_text_extents:                               #type (c: *xcb_connection_t, font: xcb_fontable_t, string_len: u32, _string: *xcb_char2b_t) -> xcb_query_text_extents_cookie_t #c_call;
    query_text_extents_unchecked:                     #type (c: *xcb_connection_t, font: xcb_fontable_t, string_len: u32, _string: *xcb_char2b_t) -> xcb_query_text_extents_cookie_t #c_call;
    query_text_extents_reply:                         #type (c: *xcb_connection_t, cookie: xcb_query_text_extents_cookie_t, e: **xcb_generic_error_t) -> *xcb_query_text_extents_reply_t #c_call;
    str_sizeof:                                       #type (_buffer: *void) -> s32 #c_call;
    str_name:                                         #type (R: *xcb_str_t) -> *u8 #c_call;
    str_name_length:                                  #type (R: *xcb_str_t) -> s32 #c_call;
    str_name_end:                                     #type (R: *xcb_str_t) -> xcb_generic_iterator_t #c_call;
    str_next:                                         #type (i: *xcb_str_iterator_t) -> void #c_call;
    str_end:                                          #type (i: xcb_str_iterator_t) -> xcb_generic_iterator_t #c_call;
    list_fonts_sizeof:                                #type (_buffer: *void) -> s32 #c_call;
    list_fonts:                                       #type (c: *xcb_connection_t, max_names: u16, pattern_len: u16, pattern: *u8) -> xcb_list_fonts_cookie_t #c_call;
    list_fonts_unchecked:                             #type (c: *xcb_connection_t, max_names: u16, pattern_len: u16, pattern: *u8) -> xcb_list_fonts_cookie_t #c_call;
    list_fonts_names_length:                          #type (R: *xcb_list_fonts_reply_t) -> s32 #c_call;
    list_fonts_names_iterator:                        #type (R: *xcb_list_fonts_reply_t) -> xcb_str_iterator_t #c_call;
    list_fonts_reply:                                 #type (c: *xcb_connection_t, cookie: xcb_list_fonts_cookie_t, e: **xcb_generic_error_t) -> *xcb_list_fonts_reply_t #c_call;
    list_fonts_with_info_sizeof:                      #type (_buffer: *void) -> s32 #c_call;
    list_fonts_with_info:                             #type (c: *xcb_connection_t, max_names: u16, pattern_len: u16, pattern: *u8) -> xcb_list_fonts_with_info_cookie_t #c_call;
    list_fonts_with_info_unchecked:                   #type (c: *xcb_connection_t, max_names: u16, pattern_len: u16, pattern: *u8) -> xcb_list_fonts_with_info_cookie_t #c_call;
    list_fonts_with_info_properties:                  #type (R: *xcb_list_fonts_with_info_reply_t) -> *xcb_fontprop_t #c_call;
    list_fonts_with_info_properties_length:           #type (R: *xcb_list_fonts_with_info_reply_t) -> s32 #c_call;
    list_fonts_with_info_properties_iterator:         #type (R: *xcb_list_fonts_with_info_reply_t) -> xcb_fontprop_iterator_t #c_call;
    list_fonts_with_info_name:                        #type (R: *xcb_list_fonts_with_info_reply_t) -> *u8 #c_call;
    list_fonts_with_info_name_length:                 #type (R: *xcb_list_fonts_with_info_reply_t) -> s32 #c_call;
    list_fonts_with_info_name_end:                    #type (R: *xcb_list_fonts_with_info_reply_t) -> xcb_generic_iterator_t #c_call;
    list_fonts_with_info_reply:                       #type (c: *xcb_connection_t, cookie: xcb_list_fonts_with_info_cookie_t, e: **xcb_generic_error_t) -> *xcb_list_fonts_with_info_reply_t #c_call;
    set_font_path_sizeof:                             #type (_buffer: *void) -> s32 #c_call;
    set_font_path_checked:                            #type (c: *xcb_connection_t, font_qty: u16, font: *xcb_str_t) -> xcb_void_cookie_t #c_call;
    set_font_path:                                    #type (c: *xcb_connection_t, font_qty: u16, font: *xcb_str_t) -> xcb_void_cookie_t #c_call;
    set_font_path_font_length:                        #type (R: *xcb_set_font_path_request_t) -> s32 #c_call;
    set_font_path_font_iterator:                      #type (R: *xcb_set_font_path_request_t) -> xcb_str_iterator_t #c_call;
    get_font_path_sizeof:                             #type (_buffer: *void) -> s32 #c_call;
    get_font_path:                                    #type (c: *xcb_connection_t) -> xcb_get_font_path_cookie_t #c_call;
    get_font_path_unchecked:                          #type (c: *xcb_connection_t) -> xcb_get_font_path_cookie_t #c_call;
    get_font_path_path_length:                        #type (R: *xcb_get_font_path_reply_t) -> s32 #c_call;
    get_font_path_path_iterator:                      #type (R: *xcb_get_font_path_reply_t) -> xcb_str_iterator_t #c_call;
    get_font_path_reply:                              #type (c: *xcb_connection_t, cookie: xcb_get_font_path_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_font_path_reply_t #c_call;
    create_pixmap_checked:                            #type (c: *xcb_connection_t, depth: u8, pid: xcb_pixmap_t, drawable: xcb_drawable_t, width: u16, height: u16) -> xcb_void_cookie_t #c_call;
    create_pixmap:                                    #type (c: *xcb_connection_t, depth: u8, pid: xcb_pixmap_t, drawable: xcb_drawable_t, width: u16, height: u16) -> xcb_void_cookie_t #c_call;
    free_pixmap_checked:                              #type (c: *xcb_connection_t, pixmap: xcb_pixmap_t) -> xcb_void_cookie_t #c_call;
    free_pixmap:                                      #type (c: *xcb_connection_t, pixmap: xcb_pixmap_t) -> xcb_void_cookie_t #c_call;
    create_gc_value_list_serialize:                   #type (_buffer: **void, value_mask: xcb_gc_t, _aux: *xcb_create_gc_value_list_t) -> s32 #c_call;
    create_gc_value_list_unpack:                      #type (_buffer: *void, value_mask: xcb_gc_t, _aux: *xcb_create_gc_value_list_t) -> s32 #c_call;
    create_gc_value_list_sizeof:                      #type (_buffer: *void, value_mask: xcb_gc_t) -> s32 #c_call;
    create_gc_sizeof:                                 #type (_buffer: *void) -> s32 #c_call;
    create_gc_checked:                                #type (c: *xcb_connection_t, cid: xcb_gcontext_t, drawable: xcb_drawable_t, value_mask: xcb_gc_t, value_list: *void) -> xcb_void_cookie_t #c_call;
    create_gc:                                        #type (c: *xcb_connection_t, cid: xcb_gcontext_t, drawable: xcb_drawable_t, value_mask: xcb_gc_t, value_list: *void) -> xcb_void_cookie_t #c_call;
    create_gc_aux_checked:                            #type (c: *xcb_connection_t, cid: xcb_gcontext_t, drawable: xcb_drawable_t, value_mask: xcb_gc_t, value_list: *xcb_create_gc_value_list_t) -> xcb_void_cookie_t #c_call;
    create_gc_aux:                                    #type (c: *xcb_connection_t, cid: xcb_gcontext_t, drawable: xcb_drawable_t, value_mask: xcb_gc_t, value_list: *xcb_create_gc_value_list_t) -> xcb_void_cookie_t #c_call;
    create_gc_value_list:                             #type (R: *xcb_create_gc_request_t) -> *void #c_call;
    change_gc_value_list_serialize:                   #type (_buffer: **void, value_mask: xcb_gc_t, _aux: *xcb_change_gc_value_list_t) -> s32 #c_call;
    change_gc_value_list_unpack:                      #type (_buffer: *void, value_mask: xcb_gc_t, _aux: *xcb_change_gc_value_list_t) -> s32 #c_call;
    change_gc_value_list_sizeof:                      #type (_buffer: *void, value_mask: xcb_gc_t) -> s32 #c_call;
    change_gc_sizeof:                                 #type (_buffer: *void) -> s32 #c_call;
    change_gc_checked:                                #type (c: *xcb_connection_t, gc: xcb_gcontext_t, value_mask: xcb_gc_t, value_list: *void) -> xcb_void_cookie_t #c_call;
    change_gc:                                        #type (c: *xcb_connection_t, gc: xcb_gcontext_t, value_mask: xcb_gc_t, value_list: *void) -> xcb_void_cookie_t #c_call;
    change_gc_aux_checked:                            #type (c: *xcb_connection_t, gc: xcb_gcontext_t, value_mask: xcb_gc_t, value_list: *xcb_change_gc_value_list_t) -> xcb_void_cookie_t #c_call;
    change_gc_aux:                                    #type (c: *xcb_connection_t, gc: xcb_gcontext_t, value_mask: xcb_gc_t, value_list: *xcb_change_gc_value_list_t) -> xcb_void_cookie_t #c_call;
    change_gc_value_list:                             #type (R: *xcb_change_gc_request_t) -> *void #c_call;
    copy_gc_checked:                                  #type (c: *xcb_connection_t, src_gc: xcb_gcontext_t, dst_gc: xcb_gcontext_t, value_mask: u32) -> xcb_void_cookie_t #c_call;
    copy_gc:                                          #type (c: *xcb_connection_t, src_gc: xcb_gcontext_t, dst_gc: xcb_gcontext_t, value_mask: u32) -> xcb_void_cookie_t #c_call;
    set_dashes_sizeof:                                #type (_buffer: *void) -> s32 #c_call;
    set_dashes_checked:                               #type (c: *xcb_connection_t, gc: xcb_gcontext_t, dash_offset: u16, dashes_len: u16, dashes: *u8) -> xcb_void_cookie_t #c_call;
    set_dashes:                                       #type (c: *xcb_connection_t, gc: xcb_gcontext_t, dash_offset: u16, dashes_len: u16, dashes: *u8) -> xcb_void_cookie_t #c_call;
    set_dashes_dashes:                                #type (R: *xcb_set_dashes_request_t) -> *u8 #c_call;
    set_dashes_dashes_length:                         #type (R: *xcb_set_dashes_request_t) -> s32 #c_call;
    set_dashes_dashes_end:                            #type (R: *xcb_set_dashes_request_t) -> xcb_generic_iterator_t #c_call;
    set_clip_rectangles_sizeof:                       #type (_buffer: *void, rectangles_len: u32) -> s32 #c_call;
    set_clip_rectangles_checked:                      #type (c: *xcb_connection_t, ordering: u8, gc: xcb_gcontext_t, clip_x_origin: s16, clip_y_origin: s16, rectangles_len: u32, rectangles: *xcb_rectangle_t) -> xcb_void_cookie_t #c_call;
    set_clip_rectangles:                              #type (c: *xcb_connection_t, ordering: u8, gc: xcb_gcontext_t, clip_x_origin: s16, clip_y_origin: s16, rectangles_len: u32, rectangles: *xcb_rectangle_t) -> xcb_void_cookie_t #c_call;
    set_clip_rectangles_rectangles:                   #type (R: *xcb_set_clip_rectangles_request_t) -> *xcb_rectangle_t #c_call;
    set_clip_rectangles_rectangles_length:            #type (R: *xcb_set_clip_rectangles_request_t) -> s32 #c_call;
    set_clip_rectangles_rectangles_iterator:          #type (R: *xcb_set_clip_rectangles_request_t) -> xcb_rectangle_iterator_t #c_call;
    free_gc_checked:                                  #type (c: *xcb_connection_t, gc: xcb_gcontext_t) -> xcb_void_cookie_t #c_call;
    free_gc:                                          #type (c: *xcb_connection_t, gc: xcb_gcontext_t) -> xcb_void_cookie_t #c_call;
    clear_area_checked:                               #type (c: *xcb_connection_t, exposures: u8, window: xcb_window_t, x: s16, y: s16, width: u16, height: u16) -> xcb_void_cookie_t #c_call;
    clear_area:                                       #type (c: *xcb_connection_t, exposures: u8, window: xcb_window_t, x: s16, y: s16, width: u16, height: u16) -> xcb_void_cookie_t #c_call;
    copy_area_checked:                                #type (c: *xcb_connection_t, src_drawable: xcb_drawable_t, dst_drawable: xcb_drawable_t, gc: xcb_gcontext_t, src_x: s16, src_y: s16, dst_x: s16, dst_y: s16, width: u16, height: u16) -> xcb_void_cookie_t #c_call;
    copy_area:                                        #type (c: *xcb_connection_t, src_drawable: xcb_drawable_t, dst_drawable: xcb_drawable_t, gc: xcb_gcontext_t, src_x: s16, src_y: s16, dst_x: s16, dst_y: s16, width: u16, height: u16) -> xcb_void_cookie_t #c_call;
    copy_plane_checked:                               #type (c: *xcb_connection_t, src_drawable: xcb_drawable_t, dst_drawable: xcb_drawable_t, gc: xcb_gcontext_t, src_x: s16, src_y: s16, dst_x: s16, dst_y: s16, width: u16, height: u16, bit_plane: u32) -> xcb_void_cookie_t #c_call;
    copy_plane:                                       #type (c: *xcb_connection_t, src_drawable: xcb_drawable_t, dst_drawable: xcb_drawable_t, gc: xcb_gcontext_t, src_x: s16, src_y: s16, dst_x: s16, dst_y: s16, width: u16, height: u16, bit_plane: u32) -> xcb_void_cookie_t #c_call;
    poly_point_sizeof:                                #type (_buffer: *void, points_len: u32) -> s32 #c_call;
    poly_point_checked:                               #type (c: *xcb_connection_t, coordinate_mode: u8, drawable: xcb_drawable_t, gc: xcb_gcontext_t, points_len: u32, points: *xcb_point_t) -> xcb_void_cookie_t #c_call;
    poly_point:                                       #type (c: *xcb_connection_t, coordinate_mode: u8, drawable: xcb_drawable_t, gc: xcb_gcontext_t, points_len: u32, points: *xcb_point_t) -> xcb_void_cookie_t #c_call;
    poly_point_points:                                #type (R: *xcb_poly_point_request_t) -> *xcb_point_t #c_call;
    poly_point_points_length:                         #type (R: *xcb_poly_point_request_t) -> s32 #c_call;
    poly_point_points_iterator:                       #type (R: *xcb_poly_point_request_t) -> xcb_point_iterator_t #c_call;
    poly_line_sizeof:                                 #type (_buffer: *void, points_len: u32) -> s32 #c_call;
    poly_line_checked:                                #type (c: *xcb_connection_t, coordinate_mode: u8, drawable: xcb_drawable_t, gc: xcb_gcontext_t, points_len: u32, points: *xcb_point_t) -> xcb_void_cookie_t #c_call;
    poly_line:                                        #type (c: *xcb_connection_t, coordinate_mode: u8, drawable: xcb_drawable_t, gc: xcb_gcontext_t, points_len: u32, points: *xcb_point_t) -> xcb_void_cookie_t #c_call;
    poly_line_points:                                 #type (R: *xcb_poly_line_request_t) -> *xcb_point_t #c_call;
    poly_line_points_length:                          #type (R: *xcb_poly_line_request_t) -> s32 #c_call;
    poly_line_points_iterator:                        #type (R: *xcb_poly_line_request_t) -> xcb_point_iterator_t #c_call;
    segment_next:                                     #type (i: *xcb_segment_iterator_t) -> void #c_call;
    segment_end:                                      #type (i: xcb_segment_iterator_t) -> xcb_generic_iterator_t #c_call;
    poly_segment_sizeof:                              #type (_buffer: *void, segments_len: u32) -> s32 #c_call;
    poly_segment_checked:                             #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, segments_len: u32, segments: *xcb_segment_t) -> xcb_void_cookie_t #c_call;
    poly_segment:                                     #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, segments_len: u32, segments: *xcb_segment_t) -> xcb_void_cookie_t #c_call;
    poly_segment_segments:                            #type (R: *xcb_poly_segment_request_t) -> *xcb_segment_t #c_call;
    poly_segment_segments_length:                     #type (R: *xcb_poly_segment_request_t) -> s32 #c_call;
    poly_segment_segments_iterator:                   #type (R: *xcb_poly_segment_request_t) -> xcb_segment_iterator_t #c_call;
    poly_rectangle_sizeof:                            #type (_buffer: *void, rectangles_len: u32) -> s32 #c_call;
    poly_rectangle_checked:                           #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, rectangles_len: u32, rectangles: *xcb_rectangle_t) -> xcb_void_cookie_t #c_call;
    poly_rectangle:                                   #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, rectangles_len: u32, rectangles: *xcb_rectangle_t) -> xcb_void_cookie_t #c_call;
    poly_rectangle_rectangles:                        #type (R: *xcb_poly_rectangle_request_t) -> *xcb_rectangle_t #c_call;
    poly_rectangle_rectangles_length:                 #type (R: *xcb_poly_rectangle_request_t) -> s32 #c_call;
    poly_rectangle_rectangles_iterator:               #type (R: *xcb_poly_rectangle_request_t) -> xcb_rectangle_iterator_t #c_call;
    poly_arc_sizeof:                                  #type (_buffer: *void, arcs_len: u32) -> s32 #c_call;
    poly_arc_checked:                                 #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, arcs_len: u32, arcs: *xcb_arc_t) -> xcb_void_cookie_t #c_call;
    poly_arc:                                         #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, arcs_len: u32, arcs: *xcb_arc_t) -> xcb_void_cookie_t #c_call;
    poly_arc_arcs:                                    #type (R: *xcb_poly_arc_request_t) -> *xcb_arc_t #c_call;
    poly_arc_arcs_length:                             #type (R: *xcb_poly_arc_request_t) -> s32 #c_call;
    poly_arc_arcs_iterator:                           #type (R: *xcb_poly_arc_request_t) -> xcb_arc_iterator_t #c_call;
    fill_poly_sizeof:                                 #type (_buffer: *void, points_len: u32) -> s32 #c_call;
    fill_poly_checked:                                #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, shape: u8, coordinate_mode: u8, points_len: u32, points: *xcb_point_t) -> xcb_void_cookie_t #c_call;
    fill_poly:                                        #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, shape: u8, coordinate_mode: u8, points_len: u32, points: *xcb_point_t) -> xcb_void_cookie_t #c_call;
    fill_poly_points:                                 #type (R: *xcb_fill_poly_request_t) -> *xcb_point_t #c_call;
    fill_poly_points_length:                          #type (R: *xcb_fill_poly_request_t) -> s32 #c_call;
    fill_poly_points_iterator:                        #type (R: *xcb_fill_poly_request_t) -> xcb_point_iterator_t #c_call;
    poly_fill_rectangle_sizeof:                       #type (_buffer: *void, rectangles_len: u32) -> s32 #c_call;
    poly_fill_rectangle_checked:                      #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, rectangles_len: u32, rectangles: *xcb_rectangle_t) -> xcb_void_cookie_t #c_call;
    poly_fill_rectangle:                              #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, rectangles_len: u32, rectangles: *xcb_rectangle_t) -> xcb_void_cookie_t #c_call;
    poly_fill_rectangle_rectangles:                   #type (R: *xcb_poly_fill_rectangle_request_t) -> *xcb_rectangle_t #c_call;
    poly_fill_rectangle_rectangles_length:            #type (R: *xcb_poly_fill_rectangle_request_t) -> s32 #c_call;
    poly_fill_rectangle_rectangles_iterator:          #type (R: *xcb_poly_fill_rectangle_request_t) -> xcb_rectangle_iterator_t #c_call;
    poly_fill_arc_sizeof:                             #type (_buffer: *void, arcs_len: u32) -> s32 #c_call;
    poly_fill_arc_checked:                            #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, arcs_len: u32, arcs: *xcb_arc_t) -> xcb_void_cookie_t #c_call;
    poly_fill_arc:                                    #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, arcs_len: u32, arcs: *xcb_arc_t) -> xcb_void_cookie_t #c_call;
    poly_fill_arc_arcs:                               #type (R: *xcb_poly_fill_arc_request_t) -> *xcb_arc_t #c_call;
    poly_fill_arc_arcs_length:                        #type (R: *xcb_poly_fill_arc_request_t) -> s32 #c_call;
    poly_fill_arc_arcs_iterator:                      #type (R: *xcb_poly_fill_arc_request_t) -> xcb_arc_iterator_t #c_call;
    put_image_sizeof:                                 #type (_buffer: *void, data_len: u32) -> s32 #c_call;
    put_image_checked:                                #type (c: *xcb_connection_t, format: u8, drawable: xcb_drawable_t, gc: xcb_gcontext_t, width: u16, height: u16, dst_x: s16, dst_y: s16, left_pad: u8, depth: u8, data_len: u32, data: *u8) -> xcb_void_cookie_t #c_call;
    put_image:                                        #type (c: *xcb_connection_t, format: u8, drawable: xcb_drawable_t, gc: xcb_gcontext_t, width: u16, height: u16, dst_x: s16, dst_y: s16, left_pad: u8, depth: u8, data_len: u32, data: *u8) -> xcb_void_cookie_t #c_call;
    put_image_data:                                   #type (R: *xcb_put_image_request_t) -> *u8 #c_call;
    put_image_data_length:                            #type (R: *xcb_put_image_request_t) -> s32 #c_call;
    put_image_data_end:                               #type (R: *xcb_put_image_request_t) -> xcb_generic_iterator_t #c_call;
    get_image_sizeof:                                 #type (_buffer: *void) -> s32 #c_call;
    get_image:                                        #type (c: *xcb_connection_t, format: u8, drawable: xcb_drawable_t, x: s16, y: s16, width: u16, height: u16, plane_mask: u32) -> xcb_get_image_cookie_t #c_call;
    get_image_unchecked:                              #type (c: *xcb_connection_t, format: u8, drawable: xcb_drawable_t, x: s16, y: s16, width: u16, height: u16, plane_mask: u32) -> xcb_get_image_cookie_t #c_call;
    get_image_data:                                   #type (R: *xcb_get_image_reply_t) -> *u8 #c_call;
    get_image_data_length:                            #type (R: *xcb_get_image_reply_t) -> s32 #c_call;
    get_image_data_end:                               #type (R: *xcb_get_image_reply_t) -> xcb_generic_iterator_t #c_call;
    get_image_reply:                                  #type (c: *xcb_connection_t, cookie: xcb_get_image_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_image_reply_t #c_call;
    poly_text_8_sizeof:                               #type (_buffer: *void, items_len: u32) -> s32 #c_call;
    poly_text_8_checked:                              #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, x: s16, y: s16, items_len: u32, items: *u8) -> xcb_void_cookie_t #c_call;
    poly_text_8:                                      #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, x: s16, y: s16, items_len: u32, items: *u8) -> xcb_void_cookie_t #c_call;
    poly_text_8_items:                                #type (R: *xcb_poly_text_8_request_t) -> *u8 #c_call;
    poly_text_8_items_length:                         #type (R: *xcb_poly_text_8_request_t) -> s32 #c_call;
    poly_text_8_items_end:                            #type (R: *xcb_poly_text_8_request_t) -> xcb_generic_iterator_t #c_call;
    poly_text_16_sizeof:                              #type (_buffer: *void, items_len: u32) -> s32 #c_call;
    poly_text_16_checked:                             #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, x: s16, y: s16, items_len: u32, items: *u8) -> xcb_void_cookie_t #c_call;
    poly_text_16:                                     #type (c: *xcb_connection_t, drawable: xcb_drawable_t, gc: xcb_gcontext_t, x: s16, y: s16, items_len: u32, items: *u8) -> xcb_void_cookie_t #c_call;
    poly_text_16_items:                               #type (R: *xcb_poly_text_16_request_t) -> *u8 #c_call;
    poly_text_16_items_length:                        #type (R: *xcb_poly_text_16_request_t) -> s32 #c_call;
    poly_text_16_items_end:                           #type (R: *xcb_poly_text_16_request_t) -> xcb_generic_iterator_t #c_call;
    image_text_8_sizeof:                              #type (_buffer: *void) -> s32 #c_call;
    image_text_8_checked:                             #type (c: *xcb_connection_t, string_len: u8, drawable: xcb_drawable_t, gc: xcb_gcontext_t, x: s16, y: s16, _string: *u8) -> xcb_void_cookie_t #c_call;
    image_text_8:                                     #type (c: *xcb_connection_t, string_len: u8, drawable: xcb_drawable_t, gc: xcb_gcontext_t, x: s16, y: s16, _string: *u8) -> xcb_void_cookie_t #c_call;
    image_text_8_string:                              #type (R: *xcb_image_text_8_request_t) -> *u8 #c_call;
    image_text_8_string_length:                       #type (R: *xcb_image_text_8_request_t) -> s32 #c_call;
    image_text_8_string_end:                          #type (R: *xcb_image_text_8_request_t) -> xcb_generic_iterator_t #c_call;
    image_text_16_sizeof:                             #type (_buffer: *void) -> s32 #c_call;
    image_text_16_checked:                            #type (c: *xcb_connection_t, string_len: u8, drawable: xcb_drawable_t, gc: xcb_gcontext_t, x: s16, y: s16, _string: *xcb_char2b_t) -> xcb_void_cookie_t #c_call;
    image_text_16:                                    #type (c: *xcb_connection_t, string_len: u8, drawable: xcb_drawable_t, gc: xcb_gcontext_t, x: s16, y: s16, _string: *xcb_char2b_t) -> xcb_void_cookie_t #c_call;
    image_text_16_string:                             #type (R: *xcb_image_text_16_request_t) -> *xcb_char2b_t #c_call;
    image_text_16_string_length:                      #type (R: *xcb_image_text_16_request_t) -> s32 #c_call;
    image_text_16_string_iterator:                    #type (R: *xcb_image_text_16_request_t) -> xcb_char2b_iterator_t #c_call;
    create_colormap_checked:                          #type (c: *xcb_connection_t, alloc: u8, mid: xcb_colormap_t, window: xcb_window_t, visual: xcb_visualid_t) -> xcb_void_cookie_t #c_call;
    create_colormap:                                  #type (c: *xcb_connection_t, alloc: u8, mid: xcb_colormap_t, window: xcb_window_t, visual: xcb_visualid_t) -> xcb_void_cookie_t #c_call;
    free_colormap_checked:                            #type (c: *xcb_connection_t, cmap: xcb_colormap_t) -> xcb_void_cookie_t #c_call;
    free_colormap:                                    #type (c: *xcb_connection_t, cmap: xcb_colormap_t) -> xcb_void_cookie_t #c_call;
    copy_colormap_and_free_checked:                   #type (c: *xcb_connection_t, mid: xcb_colormap_t, src_cmap: xcb_colormap_t) -> xcb_void_cookie_t #c_call;
    copy_colormap_and_free:                           #type (c: *xcb_connection_t, mid: xcb_colormap_t, src_cmap: xcb_colormap_t) -> xcb_void_cookie_t #c_call;
    install_colormap_checked:                         #type (c: *xcb_connection_t, cmap: xcb_colormap_t) -> xcb_void_cookie_t #c_call;
    install_colormap:                                 #type (c: *xcb_connection_t, cmap: xcb_colormap_t) -> xcb_void_cookie_t #c_call;
    uninstall_colormap_checked:                       #type (c: *xcb_connection_t, cmap: xcb_colormap_t) -> xcb_void_cookie_t #c_call;
    uninstall_colormap:                               #type (c: *xcb_connection_t, cmap: xcb_colormap_t) -> xcb_void_cookie_t #c_call;
    list_installed_colormaps_sizeof:                  #type (_buffer: *void) -> s32 #c_call;
    list_installed_colormaps:                         #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_list_installed_colormaps_cookie_t #c_call;
    list_installed_colormaps_unchecked:               #type (c: *xcb_connection_t, window: xcb_window_t) -> xcb_list_installed_colormaps_cookie_t #c_call;
    list_installed_colormaps_cmaps:                   #type (R: *xcb_list_installed_colormaps_reply_t) -> *xcb_colormap_t #c_call;
    list_installed_colormaps_cmaps_length:            #type (R: *xcb_list_installed_colormaps_reply_t) -> s32 #c_call;
    list_installed_colormaps_cmaps_end:               #type (R: *xcb_list_installed_colormaps_reply_t) -> xcb_generic_iterator_t #c_call;
    list_installed_colormaps_reply:                   #type (c: *xcb_connection_t, cookie: xcb_list_installed_colormaps_cookie_t, e: **xcb_generic_error_t) -> *xcb_list_installed_colormaps_reply_t #c_call;
    alloc_color:                                      #type (c: *xcb_connection_t, cmap: xcb_colormap_t, red: u16, green: u16, blue: u16) -> xcb_alloc_color_cookie_t #c_call;
    alloc_color_unchecked:                            #type (c: *xcb_connection_t, cmap: xcb_colormap_t, red: u16, green: u16, blue: u16) -> xcb_alloc_color_cookie_t #c_call;
    alloc_color_reply:                                #type (c: *xcb_connection_t, cookie: xcb_alloc_color_cookie_t, e: **xcb_generic_error_t) -> *xcb_alloc_color_reply_t #c_call;
    alloc_named_color_sizeof:                         #type (_buffer: *void) -> s32 #c_call;
    alloc_named_color:                                #type (c: *xcb_connection_t, cmap: xcb_colormap_t, name_len: u16, name: *u8) -> xcb_alloc_named_color_cookie_t #c_call;
    alloc_named_color_unchecked:                      #type (c: *xcb_connection_t, cmap: xcb_colormap_t, name_len: u16, name: *u8) -> xcb_alloc_named_color_cookie_t #c_call;
    alloc_named_color_reply:                          #type (c: *xcb_connection_t, cookie: xcb_alloc_named_color_cookie_t, e: **xcb_generic_error_t) -> *xcb_alloc_named_color_reply_t #c_call;
    alloc_color_cells_sizeof:                         #type (_buffer: *void) -> s32 #c_call;
    alloc_color_cells:                                #type (c: *xcb_connection_t, contiguous: u8, cmap: xcb_colormap_t, colors: u16, planes: u16) -> xcb_alloc_color_cells_cookie_t #c_call;
    alloc_color_cells_unchecked:                      #type (c: *xcb_connection_t, contiguous: u8, cmap: xcb_colormap_t, colors: u16, planes: u16) -> xcb_alloc_color_cells_cookie_t #c_call;
    alloc_color_cells_pixels:                         #type (R: *xcb_alloc_color_cells_reply_t) -> *u32 #c_call;
    alloc_color_cells_pixels_length:                  #type (R: *xcb_alloc_color_cells_reply_t) -> s32 #c_call;
    alloc_color_cells_pixels_end:                     #type (R: *xcb_alloc_color_cells_reply_t) -> xcb_generic_iterator_t #c_call;
    alloc_color_cells_masks:                          #type (R: *xcb_alloc_color_cells_reply_t) -> *u32 #c_call;
    alloc_color_cells_masks_length:                   #type (R: *xcb_alloc_color_cells_reply_t) -> s32 #c_call;
    alloc_color_cells_masks_end:                      #type (R: *xcb_alloc_color_cells_reply_t) -> xcb_generic_iterator_t #c_call;
    alloc_color_cells_reply:                          #type (c: *xcb_connection_t, cookie: xcb_alloc_color_cells_cookie_t, e: **xcb_generic_error_t) -> *xcb_alloc_color_cells_reply_t #c_call;
    alloc_color_planes_sizeof:                        #type (_buffer: *void) -> s32 #c_call;
    alloc_color_planes:                               #type (c: *xcb_connection_t, contiguous: u8, cmap: xcb_colormap_t, colors: u16, reds: u16, greens: u16, blues: u16) -> xcb_alloc_color_planes_cookie_t #c_call;
    alloc_color_planes_unchecked:                     #type (c: *xcb_connection_t, contiguous: u8, cmap: xcb_colormap_t, colors: u16, reds: u16, greens: u16, blues: u16) -> xcb_alloc_color_planes_cookie_t #c_call;
    alloc_color_planes_pixels:                        #type (R: *xcb_alloc_color_planes_reply_t) -> *u32 #c_call;
    alloc_color_planes_pixels_length:                 #type (R: *xcb_alloc_color_planes_reply_t) -> s32 #c_call;
    alloc_color_planes_pixels_end:                    #type (R: *xcb_alloc_color_planes_reply_t) -> xcb_generic_iterator_t #c_call;
    alloc_color_planes_reply:                         #type (c: *xcb_connection_t, cookie: xcb_alloc_color_planes_cookie_t, e: **xcb_generic_error_t) -> *xcb_alloc_color_planes_reply_t #c_call;
    free_colors_sizeof:                               #type (_buffer: *void, pixels_len: u32) -> s32 #c_call;
    free_colors_checked:                              #type (c: *xcb_connection_t, cmap: xcb_colormap_t, plane_mask: u32, pixels_len: u32, pixels: *u32) -> xcb_void_cookie_t #c_call;
    free_colors:                                      #type (c: *xcb_connection_t, cmap: xcb_colormap_t, plane_mask: u32, pixels_len: u32, pixels: *u32) -> xcb_void_cookie_t #c_call;
    free_colors_pixels:                               #type (R: *xcb_free_colors_request_t) -> *u32 #c_call;
    free_colors_pixels_length:                        #type (R: *xcb_free_colors_request_t) -> s32 #c_call;
    free_colors_pixels_end:                           #type (R: *xcb_free_colors_request_t) -> xcb_generic_iterator_t #c_call;
    coloritem_next:                                   #type (i: *xcb_coloritem_iterator_t) -> void #c_call;
    coloritem_end:                                    #type (i: xcb_coloritem_iterator_t) -> xcb_generic_iterator_t #c_call;
    store_colors_sizeof:                              #type (_buffer: *void, items_len: u32) -> s32 #c_call;
    store_colors_checked:                             #type (c: *xcb_connection_t, cmap: xcb_colormap_t, items_len: u32, items: *xcb_coloritem_t) -> xcb_void_cookie_t #c_call;
    store_colors:                                     #type (c: *xcb_connection_t, cmap: xcb_colormap_t, items_len: u32, items: *xcb_coloritem_t) -> xcb_void_cookie_t #c_call;
    store_colors_items:                               #type (R: *xcb_store_colors_request_t) -> *xcb_coloritem_t #c_call;
    store_colors_items_length:                        #type (R: *xcb_store_colors_request_t) -> s32 #c_call;
    store_colors_items_iterator:                      #type (R: *xcb_store_colors_request_t) -> xcb_coloritem_iterator_t #c_call;
    store_named_color_sizeof:                         #type (_buffer: *void) -> s32 #c_call;
    store_named_color_checked:                        #type (c: *xcb_connection_t, flags: u8, cmap: xcb_colormap_t, pixel: u32, name_len: u16, name: *u8) -> xcb_void_cookie_t #c_call;
    store_named_color:                                #type (c: *xcb_connection_t, flags: u8, cmap: xcb_colormap_t, pixel: u32, name_len: u16, name: *u8) -> xcb_void_cookie_t #c_call;
    store_named_color_name:                           #type (R: *xcb_store_named_color_request_t) -> *u8 #c_call;
    store_named_color_name_length:                    #type (R: *xcb_store_named_color_request_t) -> s32 #c_call;
    store_named_color_name_end:                       #type (R: *xcb_store_named_color_request_t) -> xcb_generic_iterator_t #c_call;
    rgb_next:                                         #type (i: *xcb_rgb_iterator_t) -> void #c_call;
    rgb_end:                                          #type (i: xcb_rgb_iterator_t) -> xcb_generic_iterator_t #c_call;
    query_colors_sizeof:                              #type (_buffer: *void, pixels_len: u32) -> s32 #c_call;
    query_colors:                                     #type (c: *xcb_connection_t, cmap: xcb_colormap_t, pixels_len: u32, pixels: *u32) -> xcb_query_colors_cookie_t #c_call;
    query_colors_unchecked:                           #type (c: *xcb_connection_t, cmap: xcb_colormap_t, pixels_len: u32, pixels: *u32) -> xcb_query_colors_cookie_t #c_call;
    query_colors_colors:                              #type (R: *xcb_query_colors_reply_t) -> *xcb_rgb_t #c_call;
    query_colors_colors_length:                       #type (R: *xcb_query_colors_reply_t) -> s32 #c_call;
    query_colors_colors_iterator:                     #type (R: *xcb_query_colors_reply_t) -> xcb_rgb_iterator_t #c_call;
    query_colors_reply:                               #type (c: *xcb_connection_t, cookie: xcb_query_colors_cookie_t, e: **xcb_generic_error_t) -> *xcb_query_colors_reply_t #c_call;
    lookup_color_sizeof:                              #type (_buffer: *void) -> s32 #c_call;
    lookup_color:                                     #type (c: *xcb_connection_t, cmap: xcb_colormap_t, name_len: u16, name: *u8) -> xcb_lookup_color_cookie_t #c_call;
    lookup_color_unchecked:                           #type (c: *xcb_connection_t, cmap: xcb_colormap_t, name_len: u16, name: *u8) -> xcb_lookup_color_cookie_t #c_call;
    lookup_color_reply:                               #type (c: *xcb_connection_t, cookie: xcb_lookup_color_cookie_t, e: **xcb_generic_error_t) -> *xcb_lookup_color_reply_t #c_call;
    create_cursor_checked:                            #type (c: *xcb_connection_t, cid: xcb_cursor_t, source: xcb_pixmap_t, mask: xcb_pixmap_t, fore_red: u16, fore_green: u16, fore_blue: u16, back_red: u16, back_green: u16, back_blue: u16, x: u16, y: u16) -> xcb_void_cookie_t #c_call;
    create_cursor:                                    #type (c: *xcb_connection_t, cid: xcb_cursor_t, source: xcb_pixmap_t, mask: xcb_pixmap_t, fore_red: u16, fore_green: u16, fore_blue: u16, back_red: u16, back_green: u16, back_blue: u16, x: u16, y: u16) -> xcb_void_cookie_t #c_call;
    create_glyph_cursor_checked:                      #type (c: *xcb_connection_t, cid: xcb_cursor_t, source_font: xcb_font_t, mask_font: xcb_font_t, source_char: u16, mask_char: u16, fore_red: u16, fore_green: u16, fore_blue: u16, back_red: u16, back_green: u16, back_blue: u16) -> xcb_void_cookie_t #c_call;
    create_glyph_cursor:                              #type (c: *xcb_connection_t, cid: xcb_cursor_t, source_font: xcb_font_t, mask_font: xcb_font_t, source_char: u16, mask_char: u16, fore_red: u16, fore_green: u16, fore_blue: u16, back_red: u16, back_green: u16, back_blue: u16) -> xcb_void_cookie_t #c_call;
    free_cursor_checked:                              #type (c: *xcb_connection_t, cursor: xcb_cursor_t) -> xcb_void_cookie_t #c_call;
    free_cursor:                                      #type (c: *xcb_connection_t, cursor: xcb_cursor_t) -> xcb_void_cookie_t #c_call;
    recolor_cursor_checked:                           #type (c: *xcb_connection_t, cursor: xcb_cursor_t, fore_red: u16, fore_green: u16, fore_blue: u16, back_red: u16, back_green: u16, back_blue: u16) -> xcb_void_cookie_t #c_call;
    recolor_cursor:                                   #type (c: *xcb_connection_t, cursor: xcb_cursor_t, fore_red: u16, fore_green: u16, fore_blue: u16, back_red: u16, back_green: u16, back_blue: u16) -> xcb_void_cookie_t #c_call;
    query_best_size:                                  #type (c: *xcb_connection_t, _class: xcb_query_shape_of_t, drawable: xcb_drawable_t, width: u16, height: u16) -> xcb_query_best_size_cookie_t #c_call;
    query_best_size_unchecked:                        #type (c: *xcb_connection_t, _class: xcb_query_shape_of_t, drawable: xcb_drawable_t, width: u16, height: u16) -> xcb_query_best_size_cookie_t #c_call;
    query_best_size_reply:                            #type (c: *xcb_connection_t, cookie: xcb_query_best_size_cookie_t, e: **xcb_generic_error_t) -> *xcb_query_best_size_reply_t #c_call;
    query_extension_sizeof:                           #type (_buffer: *void) -> s32 #c_call;
    query_extension:                                  #type (c: *xcb_connection_t, name_len: u16, name: *u8) -> xcb_query_extension_cookie_t #c_call;
    query_extension_unchecked:                        #type (c: *xcb_connection_t, name_len: u16, name: *u8) -> xcb_query_extension_cookie_t #c_call;
    query_extension_reply:                            #type (c: *xcb_connection_t, cookie: xcb_query_extension_cookie_t, e: **xcb_generic_error_t) -> *xcb_query_extension_reply_t #c_call;
    list_extensions_sizeof:                           #type (_buffer: *void) -> s32 #c_call;
    list_extensions:                                  #type (c: *xcb_connection_t) -> xcb_list_extensions_cookie_t #c_call;
    list_extensions_unchecked:                        #type (c: *xcb_connection_t) -> xcb_list_extensions_cookie_t #c_call;
    list_extensions_names_length:                     #type (R: *xcb_list_extensions_reply_t) -> s32 #c_call;
    list_extensions_names_iterator:                   #type (R: *xcb_list_extensions_reply_t) -> xcb_str_iterator_t #c_call;
    list_extensions_reply:                            #type (c: *xcb_connection_t, cookie: xcb_list_extensions_cookie_t, e: **xcb_generic_error_t) -> *xcb_list_extensions_reply_t #c_call;
    change_keyboard_mapping_sizeof:                   #type (_buffer: *void) -> s32 #c_call;
    change_keyboard_mapping_checked:                  #type (c: *xcb_connection_t, keycode_count: u8, first_keycode: xcb_keycode_t, keysyms_per_keycode: u8, keysyms: *xcb_keysym_t) -> xcb_void_cookie_t #c_call;
    change_keyboard_mapping:                          #type (c: *xcb_connection_t, keycode_count: u8, first_keycode: xcb_keycode_t, keysyms_per_keycode: u8, keysyms: *xcb_keysym_t) -> xcb_void_cookie_t #c_call;
    change_keyboard_mapping_keysyms:                  #type (R: *xcb_change_keyboard_mapping_request_t) -> *xcb_keysym_t #c_call;
    change_keyboard_mapping_keysyms_length:           #type (R: *xcb_change_keyboard_mapping_request_t) -> s32 #c_call;
    change_keyboard_mapping_keysyms_end:              #type (R: *xcb_change_keyboard_mapping_request_t) -> xcb_generic_iterator_t #c_call;
    get_keyboard_mapping_sizeof:                      #type (_buffer: *void) -> s32 #c_call;
    get_keyboard_mapping:                             #type (c: *xcb_connection_t, first_keycode: xcb_keycode_t, count: u8) -> xcb_get_keyboard_mapping_cookie_t #c_call;
    get_keyboard_mapping_unchecked:                   #type (c: *xcb_connection_t, first_keycode: xcb_keycode_t, count: u8) -> xcb_get_keyboard_mapping_cookie_t #c_call;
    get_keyboard_mapping_keysyms:                     #type (R: *xcb_get_keyboard_mapping_reply_t) -> *xcb_keysym_t #c_call;
    get_keyboard_mapping_keysyms_length:              #type (R: *xcb_get_keyboard_mapping_reply_t) -> s32 #c_call;
    get_keyboard_mapping_keysyms_end:                 #type (R: *xcb_get_keyboard_mapping_reply_t) -> xcb_generic_iterator_t #c_call;
    get_keyboard_mapping_reply:                       #type (c: *xcb_connection_t, cookie: xcb_get_keyboard_mapping_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_keyboard_mapping_reply_t #c_call;
    change_keyboard_control_value_list_serialize:     #type (_buffer: **void, value_mask: u32, _aux: *xcb_change_keyboard_control_value_list_t) -> s32 #c_call;
    change_keyboard_control_value_list_unpack:        #type (_buffer: *void, value_mask: u32, _aux: *xcb_change_keyboard_control_value_list_t) -> s32 #c_call;
    change_keyboard_control_value_list_sizeof:        #type (_buffer: *void, value_mask: u32) -> s32 #c_call;
    change_keyboard_control_sizeof:                   #type (_buffer: *void) -> s32 #c_call;
    change_keyboard_control_checked:                  #type (c: *xcb_connection_t, value_mask: u32, value_list: *void) -> xcb_void_cookie_t #c_call;
    change_keyboard_control:                          #type (c: *xcb_connection_t, value_mask: u32, value_list: *void) -> xcb_void_cookie_t #c_call;
    change_keyboard_control_aux_checked:              #type (c: *xcb_connection_t, value_mask: u32, value_list: *xcb_change_keyboard_control_value_list_t) -> xcb_void_cookie_t #c_call;
    change_keyboard_control_aux:                      #type (c: *xcb_connection_t, value_mask: u32, value_list: *xcb_change_keyboard_control_value_list_t) -> xcb_void_cookie_t #c_call;
    change_keyboard_control_value_list:               #type (R: *xcb_change_keyboard_control_request_t) -> *void #c_call;
    get_keyboard_control:                             #type (c: *xcb_connection_t) -> xcb_get_keyboard_control_cookie_t #c_call;
    get_keyboard_control_unchecked:                   #type (c: *xcb_connection_t) -> xcb_get_keyboard_control_cookie_t #c_call;
    get_keyboard_control_reply:                       #type (c: *xcb_connection_t, cookie: xcb_get_keyboard_control_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_keyboard_control_reply_t #c_call;
    bell_checked:                                     #type (c: *xcb_connection_t, percent: s8) -> xcb_void_cookie_t #c_call;
    bell:                                             #type (c: *xcb_connection_t, percent: s8) -> xcb_void_cookie_t #c_call;
    change_pointer_control_checked:                   #type (c: *xcb_connection_t, acceleration_numerator: s16, acceleration_denominator: s16, threshold: s16, do_acceleration: u8, do_threshold: u8) -> xcb_void_cookie_t #c_call;
    change_pointer_control:                           #type (c: *xcb_connection_t, acceleration_numerator: s16, acceleration_denominator: s16, threshold: s16, do_acceleration: u8, do_threshold: u8) -> xcb_void_cookie_t #c_call;
    get_pointer_control:                              #type (c: *xcb_connection_t) -> xcb_get_pointer_control_cookie_t #c_call;
    get_pointer_control_unchecked:                    #type (c: *xcb_connection_t) -> xcb_get_pointer_control_cookie_t #c_call;
    get_pointer_control_reply:                        #type (c: *xcb_connection_t, cookie: xcb_get_pointer_control_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_pointer_control_reply_t #c_call;
    set_screen_saver_checked:                         #type (c: *xcb_connection_t, timeout: s16, interval: s16, prefer_blanking: u8, allow_exposures: u8) -> xcb_void_cookie_t #c_call;
    set_screen_saver:                                 #type (c: *xcb_connection_t, timeout: s16, interval: s16, prefer_blanking: u8, allow_exposures: u8) -> xcb_void_cookie_t #c_call;
    get_screen_saver:                                 #type (c: *xcb_connection_t) -> xcb_get_screen_saver_cookie_t #c_call;
    get_screen_saver_unchecked:                       #type (c: *xcb_connection_t) -> xcb_get_screen_saver_cookie_t #c_call;
    get_screen_saver_reply:                           #type (c: *xcb_connection_t, cookie: xcb_get_screen_saver_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_screen_saver_reply_t #c_call;
    change_hosts_sizeof:                              #type (_buffer: *void) -> s32 #c_call;
    change_hosts_checked:                             #type (c: *xcb_connection_t, mode: u8, family: u8, address_len: u16, address: *u8) -> xcb_void_cookie_t #c_call;
    change_hosts:                                     #type (c: *xcb_connection_t, mode: u8, family: u8, address_len: u16, address: *u8) -> xcb_void_cookie_t #c_call;
    change_hosts_address:                             #type (R: *xcb_change_hosts_request_t) -> *u8 #c_call;
    change_hosts_address_length:                      #type (R: *xcb_change_hosts_request_t) -> s32 #c_call;
    change_hosts_address_end:                         #type (R: *xcb_change_hosts_request_t) -> xcb_generic_iterator_t #c_call;
    host_sizeof:                                      #type (_buffer: *void) -> s32 #c_call;
    host_address:                                     #type (R: *xcb_host_t) -> *u8 #c_call;
    host_address_length:                              #type (R: *xcb_host_t) -> s32 #c_call;
    host_address_end:                                 #type (R: *xcb_host_t) -> xcb_generic_iterator_t #c_call;
    host_next:                                        #type (i: *xcb_host_iterator_t) -> void #c_call;
    host_end:                                         #type (i: xcb_host_iterator_t) -> xcb_generic_iterator_t #c_call;
    list_hosts_sizeof:                                #type (_buffer: *void) -> s32 #c_call;
    list_hosts:                                       #type (c: *xcb_connection_t) -> xcb_list_hosts_cookie_t #c_call;
    list_hosts_unchecked:                             #type (c: *xcb_connection_t) -> xcb_list_hosts_cookie_t #c_call;
    list_hosts_hosts_length:                          #type (R: *xcb_list_hosts_reply_t) -> s32 #c_call;
    list_hosts_hosts_iterator:                        #type (R: *xcb_list_hosts_reply_t) -> xcb_host_iterator_t #c_call;
    list_hosts_reply:                                 #type (c: *xcb_connection_t, cookie: xcb_list_hosts_cookie_t, e: **xcb_generic_error_t) -> *xcb_list_hosts_reply_t #c_call;
    set_access_control_checked:                       #type (c: *xcb_connection_t, mode: u8) -> xcb_void_cookie_t #c_call;
    set_access_control:                               #type (c: *xcb_connection_t, mode: u8) -> xcb_void_cookie_t #c_call;
    set_close_down_mode_checked:                      #type (c: *xcb_connection_t, mode: u8) -> xcb_void_cookie_t #c_call;
    set_close_down_mode:                              #type (c: *xcb_connection_t, mode: u8) -> xcb_void_cookie_t #c_call;
    kill_client_checked:                              #type (c: *xcb_connection_t, resource: u32) -> xcb_void_cookie_t #c_call;
    kill_client:                                      #type (c: *xcb_connection_t, resource: u32) -> xcb_void_cookie_t #c_call;
    rotate_properties_sizeof:                         #type (_buffer: *void) -> s32 #c_call;
    rotate_properties_checked:                        #type (c: *xcb_connection_t, window: xcb_window_t, atoms_len: u16, delta: s16, atoms: *xcb_atom_t) -> xcb_void_cookie_t #c_call;
    rotate_properties:                                #type (c: *xcb_connection_t, window: xcb_window_t, atoms_len: u16, delta: s16, atoms: *xcb_atom_t) -> xcb_void_cookie_t #c_call;
    rotate_properties_atoms:                          #type (R: *xcb_rotate_properties_request_t) -> *xcb_atom_t #c_call;
    rotate_properties_atoms_length:                   #type (R: *xcb_rotate_properties_request_t) -> s32 #c_call;
    rotate_properties_atoms_end:                      #type (R: *xcb_rotate_properties_request_t) -> xcb_generic_iterator_t #c_call;
    force_screen_saver_checked:                       #type (c: *xcb_connection_t, mode: u8) -> xcb_void_cookie_t #c_call;
    force_screen_saver:                               #type (c: *xcb_connection_t, mode: u8) -> xcb_void_cookie_t #c_call;
    set_pointer_mapping_sizeof:                       #type (_buffer: *void) -> s32 #c_call;
    set_pointer_mapping:                              #type (c: *xcb_connection_t, map_len: u8, map: *u8) -> xcb_set_pointer_mapping_cookie_t #c_call;
    set_pointer_mapping_unchecked:                    #type (c: *xcb_connection_t, map_len: u8, map: *u8) -> xcb_set_pointer_mapping_cookie_t #c_call;
    set_pointer_mapping_reply:                        #type (c: *xcb_connection_t, cookie: xcb_set_pointer_mapping_cookie_t, e: **xcb_generic_error_t) -> *xcb_set_pointer_mapping_reply_t #c_call;
    get_pointer_mapping_sizeof:                       #type (_buffer: *void) -> s32 #c_call;
    get_pointer_mapping:                              #type (c: *xcb_connection_t) -> xcb_get_pointer_mapping_cookie_t #c_call;
    get_pointer_mapping_unchecked:                    #type (c: *xcb_connection_t) -> xcb_get_pointer_mapping_cookie_t #c_call;
    get_pointer_mapping_map:                          #type (R: *xcb_get_pointer_mapping_reply_t) -> *u8 #c_call;
    get_pointer_mapping_map_length:                   #type (R: *xcb_get_pointer_mapping_reply_t) -> s32 #c_call;
    get_pointer_mapping_map_end:                      #type (R: *xcb_get_pointer_mapping_reply_t) -> xcb_generic_iterator_t #c_call;
    get_pointer_mapping_reply:                        #type (c: *xcb_connection_t, cookie: xcb_get_pointer_mapping_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_pointer_mapping_reply_t #c_call;
    set_modifier_mapping_sizeof:                      #type (_buffer: *void) -> s32 #c_call;
    set_modifier_mapping:                             #type (c: *xcb_connection_t, keycodes_per_modifier: u8, keycodes: *xcb_keycode_t) -> xcb_set_modifier_mapping_cookie_t #c_call;
    set_modifier_mapping_unchecked:                   #type (c: *xcb_connection_t, keycodes_per_modifier: u8, keycodes: *xcb_keycode_t) -> xcb_set_modifier_mapping_cookie_t #c_call;
    set_modifier_mapping_reply:                       #type (c: *xcb_connection_t, cookie: xcb_set_modifier_mapping_cookie_t, e: **xcb_generic_error_t) -> *xcb_set_modifier_mapping_reply_t #c_call;
    get_modifier_mapping_sizeof:                      #type (_buffer: *void) -> s32 #c_call;
    get_modifier_mapping:                             #type (c: *xcb_connection_t) -> xcb_get_modifier_mapping_cookie_t #c_call;
    get_modifier_mapping_unchecked:                   #type (c: *xcb_connection_t) -> xcb_get_modifier_mapping_cookie_t #c_call;
    get_modifier_mapping_keycodes:                    #type (R: *xcb_get_modifier_mapping_reply_t) -> *xcb_keycode_t #c_call;
    get_modifier_mapping_keycodes_length:             #type (R: *xcb_get_modifier_mapping_reply_t) -> s32 #c_call;
    get_modifier_mapping_keycodes_end:                #type (R: *xcb_get_modifier_mapping_reply_t) -> xcb_generic_iterator_t #c_call;
    get_modifier_mapping_reply:                       #type (c: *xcb_connection_t, cookie: xcb_get_modifier_mapping_cookie_t, e: **xcb_generic_error_t) -> *xcb_get_modifier_mapping_reply_t #c_call;
    no_operation_checked:                             #type (c: *xcb_connection_t) -> xcb_void_cookie_t #c_call;
    no_operation:                                     #type (c: *xcb_connection_t) -> xcb_void_cookie_t #c_call;
    flush:                                            #type (c: *xcb_connection_t) -> s32 #c_call;
    get_maximum_request_length:                       #type (c: *xcb_connection_t) -> u32 #c_call;
    prefetch_maximum_request_length:                  #type (c: *xcb_connection_t) -> void #c_call;
    wait_for_event:                                   #type (c: *xcb_connection_t) -> *xcb_generic_event_t #c_call;
    poll_for_event:                                   #type (c: *xcb_connection_t) -> *xcb_generic_event_t #c_call;
    poll_for_queued_event:                            #type (c: *xcb_connection_t) -> *xcb_generic_event_t #c_call;
    poll_for_special_event:                           #type (c: *xcb_connection_t, se: *xcb_special_event_t) -> *xcb_generic_event_t #c_call;
    wait_for_special_event:                           #type (c: *xcb_connection_t, se: *xcb_special_event_t) -> *xcb_generic_event_t #c_call;
    register_for_special_xge:                         #type (c: *xcb_connection_t, ext: *xcb_extension_t, eid: u32, stamp: *u32) -> *xcb_special_event_t #c_call;
    unregister_for_special_event:                     #type (c: *xcb_connection_t, se: *xcb_special_event_t) -> void #c_call;
    request_check:                                    #type (c: *xcb_connection_t, cookie: xcb_void_cookie_t) -> *xcb_generic_error_t #c_call;
    discard_reply:                                    #type (c: *xcb_connection_t, sequence: u32) -> void #c_call;
    discard_reply64:                                  #type (c: *xcb_connection_t, sequence: u64) -> void #c_call;
    get_extension_data:                               #type (c: *xcb_connection_t, ext: *xcb_extension_t) -> *xcb_query_extension_reply_t #c_call;
    prefetch_extension_data:                          #type (c: *xcb_connection_t, ext: *xcb_extension_t) -> void #c_call;
    get_setup:                                        #type (c: *xcb_connection_t) -> *xcb_setup_t #c_call;
    get_file_descriptor:                              #type (c: *xcb_connection_t) -> s32 #c_call;
    connection_has_error:                             #type (c: *xcb_connection_t) -> s32 #c_call;
    connect_to_fd:                                    #type (fd: s32, auth_info: *xcb_auth_info_t) -> *xcb_connection_t #c_call;
    disconnect:                                       #type (c: *xcb_connection_t) -> void #c_call;
    parse_display:                                    #type (name: *u8, host: **u8, display: *s32, screen: *s32) -> s32 #c_call;
    connect:                                          #type (displayname: *u8, screenp: *s32) -> *xcb_connection_t #c_call;
    connect_to_display_with_auth_info:                #type (display: *u8, auth: *xcb_auth_info_t, screen: *s32) -> *xcb_connection_t #c_call;
    generate_id:                                      #type (c: *xcb_connection_t) -> u32 #c_call;
    total_read:                                       #type (c: *xcb_connection_t) -> u64 #c_call;
    total_written:                                    #type (c: *xcb_connection_t) -> u64 #c_call;
}

#scope_file

