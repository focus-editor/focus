//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



XCB_XKB_MAJOR_VERSION :: 1;
XCB_XKB_MINOR_VERSION :: 0;

XCB_XKB_KEYBOARD :: 0;

XCB_XKB_USE_EXTENSION :: 0;

XCB_XKB_SELECT_EVENTS :: 1;

XCB_XKB_BELL :: 3;

XCB_XKB_GET_STATE :: 4;

XCB_XKB_LATCH_LOCK_STATE :: 5;

XCB_XKB_GET_CONTROLS :: 6;

XCB_XKB_SET_CONTROLS :: 7;

XCB_XKB_GET_MAP :: 8;

XCB_XKB_SET_MAP :: 9;

XCB_XKB_GET_COMPAT_MAP :: 10;

XCB_XKB_SET_COMPAT_MAP :: 11;

XCB_XKB_GET_INDICATOR_STATE :: 12;

XCB_XKB_GET_INDICATOR_MAP :: 13;

XCB_XKB_SET_INDICATOR_MAP :: 14;

XCB_XKB_GET_NAMED_INDICATOR :: 15;

XCB_XKB_SET_NAMED_INDICATOR :: 16;

XCB_XKB_GET_NAMES :: 17;

XCB_XKB_SET_NAMES :: 18;

XCB_XKB_PER_CLIENT_FLAGS :: 21;

XCB_XKB_LIST_COMPONENTS :: 22;

XCB_XKB_GET_KBD_BY_NAME :: 23;

XCB_XKB_GET_DEVICE_INFO :: 24;

XCB_XKB_SET_DEVICE_INFO :: 25;

XCB_XKB_SET_DEBUGGING_FLAGS :: 101;

XCB_XKB_NEW_KEYBOARD_NOTIFY :: 0;

XCB_XKB_MAP_NOTIFY :: 1;

XCB_XKB_STATE_NOTIFY :: 2;

XCB_XKB_CONTROLS_NOTIFY :: 3;

XCB_XKB_INDICATOR_STATE_NOTIFY :: 4;

XCB_XKB_INDICATOR_MAP_NOTIFY :: 5;

XCB_XKB_NAMES_NOTIFY :: 6;

XCB_XKB_COMPAT_MAP_NOTIFY :: 7;

XCB_XKB_BELL_NOTIFY :: 8;

XCB_XKB_ACTION_MESSAGE :: 9;

XCB_XKB_ACCESS_X_NOTIFY :: 10;

XCB_XKB_EXTENSION_DEVICE_NOTIFY :: 11;

xcb_xkb_const_t :: enum u32 {
    MAX_LEGAL_KEY_CODE     :: 255;
    PER_KEY_BIT_ARRAY_SIZE :: 32;
    KEY_NAME_LENGTH        :: 4;

    XCB_XKB_CONST_MAX_LEGAL_KEY_CODE     :: MAX_LEGAL_KEY_CODE;
    XCB_XKB_CONST_PER_KEY_BIT_ARRAY_SIZE :: PER_KEY_BIT_ARRAY_SIZE;
    XCB_XKB_CONST_KEY_NAME_LENGTH        :: KEY_NAME_LENGTH;
}

xcb_xkb_event_type_t :: enum u32 {
    NEW_KEYBOARD_NOTIFY     :: 1;
    MAP_NOTIFY              :: 2;
    STATE_NOTIFY            :: 4;
    CONTROLS_NOTIFY         :: 8;
    INDICATOR_STATE_NOTIFY  :: 16;
    INDICATOR_MAP_NOTIFY    :: 32;
    NAMES_NOTIFY            :: 64;
    COMPAT_MAP_NOTIFY       :: 128;
    BELL_NOTIFY             :: 256;
    ACTION_MESSAGE          :: 512;
    ACCESS_X_NOTIFY         :: 1024;
    EXTENSION_DEVICE_NOTIFY :: 2048;

    XCB_XKB_EVENT_TYPE_NEW_KEYBOARD_NOTIFY     :: NEW_KEYBOARD_NOTIFY;
    XCB_XKB_EVENT_TYPE_MAP_NOTIFY              :: MAP_NOTIFY;
    XCB_XKB_EVENT_TYPE_STATE_NOTIFY            :: STATE_NOTIFY;
    XCB_XKB_EVENT_TYPE_CONTROLS_NOTIFY         :: CONTROLS_NOTIFY;
    XCB_XKB_EVENT_TYPE_INDICATOR_STATE_NOTIFY  :: INDICATOR_STATE_NOTIFY;
    XCB_XKB_EVENT_TYPE_INDICATOR_MAP_NOTIFY    :: INDICATOR_MAP_NOTIFY;
    XCB_XKB_EVENT_TYPE_NAMES_NOTIFY            :: NAMES_NOTIFY;
    XCB_XKB_EVENT_TYPE_COMPAT_MAP_NOTIFY       :: COMPAT_MAP_NOTIFY;
    XCB_XKB_EVENT_TYPE_BELL_NOTIFY             :: BELL_NOTIFY;
    XCB_XKB_EVENT_TYPE_ACTION_MESSAGE          :: ACTION_MESSAGE;
    XCB_XKB_EVENT_TYPE_ACCESS_X_NOTIFY         :: ACCESS_X_NOTIFY;
    XCB_XKB_EVENT_TYPE_EXTENSION_DEVICE_NOTIFY :: EXTENSION_DEVICE_NOTIFY;
}

xcb_xkb_nkn_detail_t :: enum_flags u16 {
    KEYCODES  :: 1;
    GEOMETRY  :: 2;
    DEVICE_ID :: 4;

    XCB_XKB_NKN_DETAIL_KEYCODES  :: KEYCODES;
    XCB_XKB_NKN_DETAIL_GEOMETRY  :: GEOMETRY;
    XCB_XKB_NKN_DETAIL_DEVICE_ID :: DEVICE_ID;
}

xcb_xkb_axn_detail_t :: enum u32 {
    SK_PRESS    :: 1;
    SK_ACCEPT   :: 2;
    SK_REJECT   :: 4;
    SK_RELEASE  :: 8;
    BK_ACCEPT   :: 16;
    BK_REJECT   :: 32;
    AXK_WARNING :: 64;

    XCB_XKB_AXN_DETAIL_SK_PRESS    :: SK_PRESS;
    XCB_XKB_AXN_DETAIL_SK_ACCEPT   :: SK_ACCEPT;
    XCB_XKB_AXN_DETAIL_SK_REJECT   :: SK_REJECT;
    XCB_XKB_AXN_DETAIL_SK_RELEASE  :: SK_RELEASE;
    XCB_XKB_AXN_DETAIL_BK_ACCEPT   :: BK_ACCEPT;
    XCB_XKB_AXN_DETAIL_BK_REJECT   :: BK_REJECT;
    XCB_XKB_AXN_DETAIL_AXK_WARNING :: AXK_WARNING;
}

xcb_xkb_map_part_t :: enum u32 {
    KEY_TYPES           :: 1;
    KEY_SYMS            :: 2;
    MODIFIER_MAP        :: 4;
    EXPLICIT_COMPONENTS :: 8;
    KEY_ACTIONS         :: 16;
    KEY_BEHAVIORS       :: 32;
    VIRTUAL_MODS        :: 64;
    VIRTUAL_MOD_MAP     :: 128;

    XCB_XKB_MAP_PART_KEY_TYPES           :: KEY_TYPES;
    XCB_XKB_MAP_PART_KEY_SYMS            :: KEY_SYMS;
    XCB_XKB_MAP_PART_MODIFIER_MAP        :: MODIFIER_MAP;
    XCB_XKB_MAP_PART_EXPLICIT_COMPONENTS :: EXPLICIT_COMPONENTS;
    XCB_XKB_MAP_PART_KEY_ACTIONS         :: KEY_ACTIONS;
    XCB_XKB_MAP_PART_KEY_BEHAVIORS       :: KEY_BEHAVIORS;
    XCB_XKB_MAP_PART_VIRTUAL_MODS        :: VIRTUAL_MODS;
    XCB_XKB_MAP_PART_VIRTUAL_MOD_MAP     :: VIRTUAL_MOD_MAP;
}

xcb_xkb_set_map_flags_t :: enum u32 {
    RESIZE_TYPES      :: 1;
    RECOMPUTE_ACTIONS :: 2;

    XCB_XKB_SET_MAP_FLAGS_RESIZE_TYPES      :: RESIZE_TYPES;
    XCB_XKB_SET_MAP_FLAGS_RECOMPUTE_ACTIONS :: RECOMPUTE_ACTIONS;
}

xcb_xkb_state_part_t :: enum_flags u16 {
    MODIFIER_STATE     :: 1;
    MODIFIER_BASE      :: 2;
    MODIFIER_LATCH     :: 4;
    MODIFIER_LOCK      :: 8;
    GROUP_STATE        :: 16;
    GROUP_BASE         :: 32;
    GROUP_LATCH        :: 64;
    GROUP_LOCK         :: 128;
    COMPAT_STATE       :: 256;
    GRAB_MODS          :: 512;
    COMPAT_GRAB_MODS   :: 1024;
    LOOKUP_MODS        :: 2048;
    COMPAT_LOOKUP_MODS :: 4096;
    POINTER_BUTTONS    :: 8192;

    XCB_XKB_STATE_PART_MODIFIER_STATE     :: MODIFIER_STATE;
    XCB_XKB_STATE_PART_MODIFIER_BASE      :: MODIFIER_BASE;
    XCB_XKB_STATE_PART_MODIFIER_LATCH     :: MODIFIER_LATCH;
    XCB_XKB_STATE_PART_MODIFIER_LOCK      :: MODIFIER_LOCK;
    XCB_XKB_STATE_PART_GROUP_STATE        :: GROUP_STATE;
    XCB_XKB_STATE_PART_GROUP_BASE         :: GROUP_BASE;
    XCB_XKB_STATE_PART_GROUP_LATCH        :: GROUP_LATCH;
    XCB_XKB_STATE_PART_GROUP_LOCK         :: GROUP_LOCK;
    XCB_XKB_STATE_PART_COMPAT_STATE       :: COMPAT_STATE;
    XCB_XKB_STATE_PART_GRAB_MODS          :: GRAB_MODS;
    XCB_XKB_STATE_PART_COMPAT_GRAB_MODS   :: COMPAT_GRAB_MODS;
    XCB_XKB_STATE_PART_LOOKUP_MODS        :: LOOKUP_MODS;
    XCB_XKB_STATE_PART_COMPAT_LOOKUP_MODS :: COMPAT_LOOKUP_MODS;
    XCB_XKB_STATE_PART_POINTER_BUTTONS    :: POINTER_BUTTONS;
}

xcb_xkb_bool_ctrl_t :: enum u32 {
    REPEAT_KEYS            :: 1;
    SLOW_KEYS              :: 2;
    BOUNCE_KEYS            :: 4;
    STICKY_KEYS            :: 8;
    MOUSE_KEYS             :: 16;
    MOUSE_KEYS_ACCEL       :: 32;
    ACCESS_X_KEYS          :: 64;
    ACCESS_X_TIMEOUT_MASK  :: 128;
    ACCESS_X_FEEDBACK_MASK :: 256;
    AUDIBLE_BELL_MASK      :: 512;
    OVERLAY_1_MASK         :: 1024;
    OVERLAY_2_MASK         :: 2048;
    IGNORE_GROUP_LOCK_MASK :: 4096;

    XCB_XKB_BOOL_CTRL_REPEAT_KEYS            :: REPEAT_KEYS;
    XCB_XKB_BOOL_CTRL_SLOW_KEYS              :: SLOW_KEYS;
    XCB_XKB_BOOL_CTRL_BOUNCE_KEYS            :: BOUNCE_KEYS;
    XCB_XKB_BOOL_CTRL_STICKY_KEYS            :: STICKY_KEYS;
    XCB_XKB_BOOL_CTRL_MOUSE_KEYS             :: MOUSE_KEYS;
    XCB_XKB_BOOL_CTRL_MOUSE_KEYS_ACCEL       :: MOUSE_KEYS_ACCEL;
    XCB_XKB_BOOL_CTRL_ACCESS_X_KEYS          :: ACCESS_X_KEYS;
    XCB_XKB_BOOL_CTRL_ACCESS_X_TIMEOUT_MASK  :: ACCESS_X_TIMEOUT_MASK;
    XCB_XKB_BOOL_CTRL_ACCESS_X_FEEDBACK_MASK :: ACCESS_X_FEEDBACK_MASK;
    XCB_XKB_BOOL_CTRL_AUDIBLE_BELL_MASK      :: AUDIBLE_BELL_MASK;
    XCB_XKB_BOOL_CTRL_OVERLAY_1_MASK         :: OVERLAY_1_MASK;
    XCB_XKB_BOOL_CTRL_OVERLAY_2_MASK         :: OVERLAY_2_MASK;
    XCB_XKB_BOOL_CTRL_IGNORE_GROUP_LOCK_MASK :: IGNORE_GROUP_LOCK_MASK;
}

xcb_xkb_control_t :: enum_flags u32 {
    GROUPS_WRAP      :: 134217728;
    INTERNAL_MODS    :: 268435456;
    IGNORE_LOCK_MODS :: 536870912;
    PER_KEY_REPEAT   :: 1073741824;
    CONTROLS_ENABLED :: 2147483648;

    XCB_XKB_CONTROL_GROUPS_WRAP      :: GROUPS_WRAP;
    XCB_XKB_CONTROL_INTERNAL_MODS    :: INTERNAL_MODS;
    XCB_XKB_CONTROL_IGNORE_LOCK_MODS :: IGNORE_LOCK_MODS;
    XCB_XKB_CONTROL_PER_KEY_REPEAT   :: PER_KEY_REPEAT;
    XCB_XKB_CONTROL_CONTROLS_ENABLED :: CONTROLS_ENABLED;
}

xcb_xkb_ax_option_t :: enum u32 {
    SK_PRESS_FB    :: 1;
    SK_ACCEPT_FB   :: 2;
    FEATURE_FB     :: 4;
    SLOW_WARN_FB   :: 8;
    INDICATOR_FB   :: 16;
    STICKY_KEYS_FB :: 32;
    TWO_KEYS       :: 64;
    LATCH_TO_LOCK  :: 128;
    SK_RELEASE_FB  :: 256;
    SK_REJECT_FB   :: 512;
    BK_REJECT_FB   :: 1024;
    DUMB_BELL      :: 2048;

    XCB_XKB_AX_OPTION_SK_PRESS_FB    :: SK_PRESS_FB;
    XCB_XKB_AX_OPTION_SK_ACCEPT_FB   :: SK_ACCEPT_FB;
    XCB_XKB_AX_OPTION_FEATURE_FB     :: FEATURE_FB;
    XCB_XKB_AX_OPTION_SLOW_WARN_FB   :: SLOW_WARN_FB;
    XCB_XKB_AX_OPTION_INDICATOR_FB   :: INDICATOR_FB;
    XCB_XKB_AX_OPTION_STICKY_KEYS_FB :: STICKY_KEYS_FB;
    XCB_XKB_AX_OPTION_TWO_KEYS       :: TWO_KEYS;
    XCB_XKB_AX_OPTION_LATCH_TO_LOCK  :: LATCH_TO_LOCK;
    XCB_XKB_AX_OPTION_SK_RELEASE_FB  :: SK_RELEASE_FB;
    XCB_XKB_AX_OPTION_SK_REJECT_FB   :: SK_REJECT_FB;
    XCB_XKB_AX_OPTION_BK_REJECT_FB   :: BK_REJECT_FB;
    XCB_XKB_AX_OPTION_DUMB_BELL      :: DUMB_BELL;
}

xcb_xkb_device_spec_t :: u16;

xcb_xkb_device_spec_iterator_t :: struct {
    data:  *xcb_xkb_device_spec_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_led_class_result_t :: enum u32 {
    KBD_FEEDBACK_CLASS :: 0;
    LED_FEEDBACK_CLASS :: 4;

    XCB_XKB_LED_CLASS_RESULT_KBD_FEEDBACK_CLASS :: KBD_FEEDBACK_CLASS;
    XCB_XKB_LED_CLASS_RESULT_LED_FEEDBACK_CLASS :: LED_FEEDBACK_CLASS;
}

xcb_xkb_led_class_t :: enum u32 {
    KBD_FEEDBACK_CLASS :: 0;
    LED_FEEDBACK_CLASS :: 4;
    DFLT_XI_CLASS      :: 768;
    ALL_XI_CLASSES     :: 1280;

    XCB_XKB_LED_CLASS_KBD_FEEDBACK_CLASS :: KBD_FEEDBACK_CLASS;
    XCB_XKB_LED_CLASS_LED_FEEDBACK_CLASS :: LED_FEEDBACK_CLASS;
    XCB_XKB_LED_CLASS_DFLT_XI_CLASS      :: DFLT_XI_CLASS;
    XCB_XKB_LED_CLASS_ALL_XI_CLASSES     :: ALL_XI_CLASSES;
}

xcb_xkb_led_class_spec_t :: u16;

xcb_xkb_led_class_spec_iterator_t :: struct {
    data:  *xcb_xkb_led_class_spec_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_bell_class_result_t :: enum u32 {
    KBD_FEEDBACK_CLASS  :: 0;
    BELL_FEEDBACK_CLASS :: 5;

    XCB_XKB_BELL_CLASS_RESULT_KBD_FEEDBACK_CLASS  :: KBD_FEEDBACK_CLASS;
    XCB_XKB_BELL_CLASS_RESULT_BELL_FEEDBACK_CLASS :: BELL_FEEDBACK_CLASS;
}

xcb_xkb_bell_class_t :: enum u32 {
    KBD_FEEDBACK_CLASS  :: 0;
    BELL_FEEDBACK_CLASS :: 5;
    DFLT_XI_CLASS       :: 768;

    XCB_XKB_BELL_CLASS_KBD_FEEDBACK_CLASS  :: KBD_FEEDBACK_CLASS;
    XCB_XKB_BELL_CLASS_BELL_FEEDBACK_CLASS :: BELL_FEEDBACK_CLASS;
    XCB_XKB_BELL_CLASS_DFLT_XI_CLASS       :: DFLT_XI_CLASS;
}

xcb_xkb_bell_class_spec_t :: u16;

xcb_xkb_bell_class_spec_iterator_t :: struct {
    data:  *xcb_xkb_bell_class_spec_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_id_t :: enum u32 {
    USE_CORE_KBD  :: 256;
    USE_CORE_PTR  :: 512;
    DFLT_XI_CLASS :: 768;
    DFLT_XI_ID    :: 1024;
    ALL_XI_CLASS  :: 1280;
    ALL_XI_ID     :: 1536;
    XI_NONE       :: 65280;

    XCB_XKB_ID_USE_CORE_KBD  :: USE_CORE_KBD;
    XCB_XKB_ID_USE_CORE_PTR  :: USE_CORE_PTR;
    XCB_XKB_ID_DFLT_XI_CLASS :: DFLT_XI_CLASS;
    XCB_XKB_ID_DFLT_XI_ID    :: DFLT_XI_ID;
    XCB_XKB_ID_ALL_XI_CLASS  :: ALL_XI_CLASS;
    XCB_XKB_ID_ALL_XI_ID     :: ALL_XI_ID;
    XCB_XKB_ID_XI_NONE       :: XI_NONE;
}

xcb_xkb_id_spec_t :: u16;

xcb_xkb_id_spec_iterator_t :: struct {
    data:  *xcb_xkb_id_spec_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_group_t :: enum u32 {
    _1 :: 0;
    _2 :: 1;
    _3 :: 2;
    _4 :: 3;

    XCB_XKB_GROUP_1 :: _1;
    XCB_XKB_GROUP_2 :: _2;
    XCB_XKB_GROUP_3 :: _3;
    XCB_XKB_GROUP_4 :: _4;
}

xcb_xkb_groups_t :: enum u32 {
    ANY :: 254;
    ALL :: 255;

    XCB_XKB_GROUPS_ANY :: ANY;
    XCB_XKB_GROUPS_ALL :: ALL;
}

xcb_xkb_set_of_group_t :: enum u32 {
    _1 :: 1;
    _2 :: 2;
    _3 :: 4;
    _4 :: 8;

    XCB_XKB_SET_OF_GROUP_GROUP_1 :: _1;
    XCB_XKB_SET_OF_GROUP_GROUP_2 :: _2;
    XCB_XKB_SET_OF_GROUP_GROUP_3 :: _3;
    XCB_XKB_SET_OF_GROUP_GROUP_4 :: _4;
}

xcb_xkb_set_of_groups_t :: enum u32 {
    XCB_XKB_SET_OF_GROUPS_ANY :: 128;
}

xcb_xkb_groups_wrap_t :: enum u32 {
    WRAP_INTO_RANGE     :: 0;
    CLAMP_INTO_RANGE    :: 64;
    REDIRECT_INTO_RANGE :: 128;

    XCB_XKB_GROUPS_WRAP_WRAP_INTO_RANGE     :: WRAP_INTO_RANGE;
    XCB_XKB_GROUPS_WRAP_CLAMP_INTO_RANGE    :: CLAMP_INTO_RANGE;
    XCB_XKB_GROUPS_WRAP_REDIRECT_INTO_RANGE :: REDIRECT_INTO_RANGE;
}

xcb_xkb_v_mods_high_t :: enum u32 {
    _15 :: 128;
    _14 :: 64;
    _13 :: 32;
    _12 :: 16;
    _11 :: 8;
    _10 :: 4;
    _9  :: 2;
    _8  :: 1;

    XCB_XKB_V_MODS_HIGH_15 :: _15;
    XCB_XKB_V_MODS_HIGH_14 :: _14;
    XCB_XKB_V_MODS_HIGH_13 :: _13;
    XCB_XKB_V_MODS_HIGH_12 :: _12;
    XCB_XKB_V_MODS_HIGH_11 :: _11;
    XCB_XKB_V_MODS_HIGH_10 :: _10;
    XCB_XKB_V_MODS_HIGH_9  :: _9;
    XCB_XKB_V_MODS_HIGH_8  :: _8;
}

xcb_xkb_v_mods_low_t :: enum u32 {
    _7 :: 128;
    _6 :: 64;
    _5 :: 32;
    _4 :: 16;
    _3 :: 8;
    _2 :: 4;
    _1 :: 2;
    _0 :: 1;

    XCB_XKB_V_MODS_LOW_7 :: _7;
    XCB_XKB_V_MODS_LOW_6 :: _6;
    XCB_XKB_V_MODS_LOW_5 :: _5;
    XCB_XKB_V_MODS_LOW_4 :: _4;
    XCB_XKB_V_MODS_LOW_3 :: _3;
    XCB_XKB_V_MODS_LOW_2 :: _2;
    XCB_XKB_V_MODS_LOW_1 :: _1;
    XCB_XKB_V_MODS_LOW_0 :: _0;
}

xcb_xkb_v_mod_t :: enum u32 {
    _15 :: 32768;
    _14 :: 16384;
    _13 :: 8192;
    _12 :: 4096;
    _11 :: 2048;
    _10 :: 1024;
    _9  :: 512;
    _8  :: 256;
    _7  :: 128;
    _6  :: 64;
    _5  :: 32;
    _4  :: 16;
    _3  :: 8;
    _2  :: 4;
    _1  :: 2;
    _0  :: 1;

    XCB_XKB_V_MOD_15 :: _15;
    XCB_XKB_V_MOD_14 :: _14;
    XCB_XKB_V_MOD_13 :: _13;
    XCB_XKB_V_MOD_12 :: _12;
    XCB_XKB_V_MOD_11 :: _11;
    XCB_XKB_V_MOD_10 :: _10;
    XCB_XKB_V_MOD_9  :: _9;
    XCB_XKB_V_MOD_8  :: _8;
    XCB_XKB_V_MOD_7  :: _7;
    XCB_XKB_V_MOD_6  :: _6;
    XCB_XKB_V_MOD_5  :: _5;
    XCB_XKB_V_MOD_4  :: _4;
    XCB_XKB_V_MOD_3  :: _3;
    XCB_XKB_V_MOD_2  :: _2;
    XCB_XKB_V_MOD_1  :: _1;
    XCB_XKB_V_MOD_0  :: _0;
}

xcb_xkb_explicit_t :: enum u32 {
    V_MOD_MAP   :: 128;
    BEHAVIOR    :: 64;
    AUTO_REPEAT :: 32;
    INTERPRET   :: 16;
    KEY_TYPE_4  :: 8;
    KEY_TYPE_3  :: 4;
    KEY_TYPE_2  :: 2;
    KEY_TYPE_1  :: 1;

    XCB_XKB_EXPLICIT_V_MOD_MAP   :: V_MOD_MAP;
    XCB_XKB_EXPLICIT_BEHAVIOR    :: BEHAVIOR;
    XCB_XKB_EXPLICIT_AUTO_REPEAT :: AUTO_REPEAT;
    XCB_XKB_EXPLICIT_INTERPRET   :: INTERPRET;
    XCB_XKB_EXPLICIT_KEY_TYPE_4  :: KEY_TYPE_4;
    XCB_XKB_EXPLICIT_KEY_TYPE_3  :: KEY_TYPE_3;
    XCB_XKB_EXPLICIT_KEY_TYPE_2  :: KEY_TYPE_2;
    XCB_XKB_EXPLICIT_KEY_TYPE_1  :: KEY_TYPE_1;
}

xcb_xkb_sym_interpret_match_t :: enum u32 {
    NONE_OF        :: 0;
    ANY_OF_OR_NONE :: 1;
    ANY_OF         :: 2;
    ALL_OF         :: 3;
    EXACTLY        :: 4;

    XCB_XKB_SYM_INTERPRET_MATCH_NONE_OF        :: NONE_OF;
    XCB_XKB_SYM_INTERPRET_MATCH_ANY_OF_OR_NONE :: ANY_OF_OR_NONE;
    XCB_XKB_SYM_INTERPRET_MATCH_ANY_OF         :: ANY_OF;
    XCB_XKB_SYM_INTERPRET_MATCH_ALL_OF         :: ALL_OF;
    XCB_XKB_SYM_INTERPRET_MATCH_EXACTLY        :: EXACTLY;
}

xcb_xkb_sym_interp_match_t :: enum u32 {
    LEVEL_ONE_ONLY :: 128;
    OP_MASK        :: 127;

    XCB_XKB_SYM_INTERP_MATCH_LEVEL_ONE_ONLY :: LEVEL_ONE_ONLY;
    XCB_XKB_SYM_INTERP_MATCH_OP_MASK        :: OP_MASK;
}

xcb_xkb_im_flag_t :: enum u32 {
    NO_EXPLICIT   :: 128;
    NO_AUTOMATIC  :: 64;
    LED_DRIVES_KB :: 32;

    XCB_XKB_IM_FLAG_NO_EXPLICIT   :: NO_EXPLICIT;
    XCB_XKB_IM_FLAG_NO_AUTOMATIC  :: NO_AUTOMATIC;
    XCB_XKB_IM_FLAG_LED_DRIVES_KB :: LED_DRIVES_KB;
}

xcb_xkb_im_mods_which_t :: enum u32 {
    COMPAT    :: 16;
    EFFECTIVE :: 8;
    LOCKED    :: 4;
    LATCHED   :: 2;
    BASE      :: 1;

    XCB_XKB_IM_MODS_WHICH_USE_COMPAT    :: COMPAT;
    XCB_XKB_IM_MODS_WHICH_USE_EFFECTIVE :: EFFECTIVE;
    XCB_XKB_IM_MODS_WHICH_USE_LOCKED    :: LOCKED;
    XCB_XKB_IM_MODS_WHICH_USE_LATCHED   :: LATCHED;
    XCB_XKB_IM_MODS_WHICH_USE_BASE      :: BASE;
}

xcb_xkb_im_groups_which_t :: enum u32 {
    COMPAT    :: 16;
    EFFECTIVE :: 8;
    LOCKED    :: 4;
    LATCHED   :: 2;
    BASE      :: 1;

    XCB_XKB_IM_GROUPS_WHICH_USE_COMPAT    :: COMPAT;
    XCB_XKB_IM_GROUPS_WHICH_USE_EFFECTIVE :: EFFECTIVE;
    XCB_XKB_IM_GROUPS_WHICH_USE_LOCKED    :: LOCKED;
    XCB_XKB_IM_GROUPS_WHICH_USE_LATCHED   :: LATCHED;
    XCB_XKB_IM_GROUPS_WHICH_USE_BASE      :: BASE;
}

xcb_xkb_indicator_map_t :: struct {
    flags:       u8;
    whichGroups: u8;
    groups:      u8;
    whichMods:   u8;
    mods:        u8;
    realMods:    u8;
    vmods:       u16;
    ctrls:       u32;
}

xcb_xkb_indicator_map_iterator_t :: struct {
    data:  *xcb_xkb_indicator_map_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_cm_detail_t :: enum u32 {
    SYM_INTERP   :: 1;
    GROUP_COMPAT :: 2;

    XCB_XKB_CM_DETAIL_SYM_INTERP   :: SYM_INTERP;
    XCB_XKB_CM_DETAIL_GROUP_COMPAT :: GROUP_COMPAT;
}

xcb_xkb_name_detail_t :: enum u32 {
    KEYCODES          :: 1;
    GEOMETRY          :: 2;
    SYMBOLS           :: 4;
    PHYS_SYMBOLS      :: 8;
    TYPES             :: 16;
    COMPAT            :: 32;
    KEY_TYPE_NAMES    :: 64;
    KT_LEVEL_NAMES    :: 128;
    INDICATOR_NAMES   :: 256;
    KEY_NAMES         :: 512;
    KEY_ALIASES       :: 1024;
    VIRTUAL_MOD_NAMES :: 2048;
    GROUP_NAMES       :: 4096;
    RG_NAMES          :: 8192;

    XCB_XKB_NAME_DETAIL_KEYCODES          :: KEYCODES;
    XCB_XKB_NAME_DETAIL_GEOMETRY          :: GEOMETRY;
    XCB_XKB_NAME_DETAIL_SYMBOLS           :: SYMBOLS;
    XCB_XKB_NAME_DETAIL_PHYS_SYMBOLS      :: PHYS_SYMBOLS;
    XCB_XKB_NAME_DETAIL_TYPES             :: TYPES;
    XCB_XKB_NAME_DETAIL_COMPAT            :: COMPAT;
    XCB_XKB_NAME_DETAIL_KEY_TYPE_NAMES    :: KEY_TYPE_NAMES;
    XCB_XKB_NAME_DETAIL_KT_LEVEL_NAMES    :: KT_LEVEL_NAMES;
    XCB_XKB_NAME_DETAIL_INDICATOR_NAMES   :: INDICATOR_NAMES;
    XCB_XKB_NAME_DETAIL_KEY_NAMES         :: KEY_NAMES;
    XCB_XKB_NAME_DETAIL_KEY_ALIASES       :: KEY_ALIASES;
    XCB_XKB_NAME_DETAIL_VIRTUAL_MOD_NAMES :: VIRTUAL_MOD_NAMES;
    XCB_XKB_NAME_DETAIL_GROUP_NAMES       :: GROUP_NAMES;
    XCB_XKB_NAME_DETAIL_RG_NAMES          :: RG_NAMES;
}

xcb_xkb_gbn_detail_t :: enum u32 {
    TYPES          :: 1;
    COMPAT_MAP     :: 2;
    CLIENT_SYMBOLS :: 4;
    SERVER_SYMBOLS :: 8;
    INDICATOR_MAPS :: 16;
    KEY_NAMES      :: 32;
    GEOMETRY       :: 64;
    OTHER_NAMES    :: 128;

    XCB_XKB_GBN_DETAIL_TYPES          :: TYPES;
    XCB_XKB_GBN_DETAIL_COMPAT_MAP     :: COMPAT_MAP;
    XCB_XKB_GBN_DETAIL_CLIENT_SYMBOLS :: CLIENT_SYMBOLS;
    XCB_XKB_GBN_DETAIL_SERVER_SYMBOLS :: SERVER_SYMBOLS;
    XCB_XKB_GBN_DETAIL_INDICATOR_MAPS :: INDICATOR_MAPS;
    XCB_XKB_GBN_DETAIL_KEY_NAMES      :: KEY_NAMES;
    XCB_XKB_GBN_DETAIL_GEOMETRY       :: GEOMETRY;
    XCB_XKB_GBN_DETAIL_OTHER_NAMES    :: OTHER_NAMES;
}

xcb_xkb_xi_feature_t :: enum u32 {
    KEYBOARDS       :: 1;
    BUTTON_ACTIONS  :: 2;
    INDICATOR_NAMES :: 4;
    INDICATOR_MAPS  :: 8;
    INDICATOR_STATE :: 16;

    XCB_XKB_XI_FEATURE_KEYBOARDS       :: KEYBOARDS;
    XCB_XKB_XI_FEATURE_BUTTON_ACTIONS  :: BUTTON_ACTIONS;
    XCB_XKB_XI_FEATURE_INDICATOR_NAMES :: INDICATOR_NAMES;
    XCB_XKB_XI_FEATURE_INDICATOR_MAPS  :: INDICATOR_MAPS;
    XCB_XKB_XI_FEATURE_INDICATOR_STATE :: INDICATOR_STATE;
}

xcb_xkb_per_client_flag_t :: enum u32 {
    DETECTABLE_AUTO_REPEAT    :: 1;
    GRABS_USE_XKB_STATE       :: 2;
    AUTO_RESET_CONTROLS       :: 4;
    LOOKUP_STATE_WHEN_GRABBED :: 8;
    SEND_EVENT_USES_XKB_STATE :: 16;

    XCB_XKB_PER_CLIENT_FLAG_DETECTABLE_AUTO_REPEAT    :: DETECTABLE_AUTO_REPEAT;
    XCB_XKB_PER_CLIENT_FLAG_GRABS_USE_XKB_STATE       :: GRABS_USE_XKB_STATE;
    XCB_XKB_PER_CLIENT_FLAG_AUTO_RESET_CONTROLS       :: AUTO_RESET_CONTROLS;
    XCB_XKB_PER_CLIENT_FLAG_LOOKUP_STATE_WHEN_GRABBED :: LOOKUP_STATE_WHEN_GRABBED;
    XCB_XKB_PER_CLIENT_FLAG_SEND_EVENT_USES_XKB_STATE :: SEND_EVENT_USES_XKB_STATE;
}

xcb_xkb_mod_def_t :: struct {
    mask:     u8;
    realMods: u8;
    vmods:    u16;
}

xcb_xkb_mod_def_iterator_t :: struct {
    data:  *xcb_xkb_mod_def_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_key_name_t :: struct {
    name: [4] u8;
}

xcb_xkb_key_name_iterator_t :: struct {
    data:  *xcb_xkb_key_name_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_key_alias_t :: struct {
    real:  [4] u8;
    alias: [4] u8;
}

xcb_xkb_key_alias_iterator_t :: struct {
    data:  *xcb_xkb_key_alias_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_counted_string_16_t :: struct {
    length: u16;
}

xcb_xkb_counted_string_16_iterator_t :: struct {
    data:  *xcb_xkb_counted_string_16_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_kt_map_entry_t :: struct {
    active:     u8;
    mods_mask:  u8;
    level:      u8;
    mods_mods:  u8;
    mods_vmods: u16;
    pad0:       [2] u8;
}

xcb_xkb_kt_map_entry_iterator_t :: struct {
    data:  *xcb_xkb_kt_map_entry_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_key_type_t :: struct {
    mods_mask:   u8;
    mods_mods:   u8;
    mods_vmods:  u16;
    numLevels:   u8;
    nMapEntries: u8;
    hasPreserve: u8;
    pad0:        u8;
}

xcb_xkb_key_type_iterator_t :: struct {
    data:  *xcb_xkb_key_type_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_key_sym_map_t :: struct {
    kt_index:  [4] u8;
    groupInfo: u8;
    width:     u8;
    nSyms:     u16;
}

xcb_xkb_key_sym_map_iterator_t :: struct {
    data:  *xcb_xkb_key_sym_map_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_common_behavior_t :: struct {
    type: u8;
    data: u8;
}

xcb_xkb_common_behavior_iterator_t :: struct {
    data:  *xcb_xkb_common_behavior_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_default_behavior_t :: struct {
    type: u8;
    pad0: u8;
}

xcb_xkb_default_behavior_iterator_t :: struct {
    data:  *xcb_xkb_default_behavior_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_lock_behavior_t :: struct {
    type: u8;
    pad0: u8;
}

xcb_xkb_lock_behavior_iterator_t :: struct {
    data:  *xcb_xkb_lock_behavior_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_radio_group_behavior_t :: struct {
    type:  u8;
    group: u8;
}

xcb_xkb_radio_group_behavior_iterator_t :: struct {
    data:  *xcb_xkb_radio_group_behavior_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_overlay_behavior_t :: struct {
    type: u8;
    key:  xcb_keycode_t;
}

xcb_xkb_overlay_behavior_iterator_t :: struct {
    data:  *xcb_xkb_overlay_behavior_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_permament_lock_behavior_t :: struct {
    type: u8;
    pad0: u8;
}

xcb_xkb_permament_lock_behavior_iterator_t :: struct {
    data:  *xcb_xkb_permament_lock_behavior_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_permament_radio_group_behavior_t :: struct {
    type:  u8;
    group: u8;
}

xcb_xkb_permament_radio_group_behavior_iterator_t :: struct {
    data:  *xcb_xkb_permament_radio_group_behavior_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_permament_overlay_behavior_t :: struct {
    type: u8;
    key:  xcb_keycode_t;
}

xcb_xkb_permament_overlay_behavior_iterator_t :: struct {
    data:  *xcb_xkb_permament_overlay_behavior_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_behavior_t :: union {
    common:              xcb_xkb_common_behavior_t;
    _default:            xcb_xkb_default_behavior_t;
    lock:                xcb_xkb_lock_behavior_t;
    radioGroup:          xcb_xkb_radio_group_behavior_t;
    overlay1:            xcb_xkb_overlay_behavior_t;
    overlay2:            xcb_xkb_overlay_behavior_t;
    permamentLock:       xcb_xkb_permament_lock_behavior_t;
    permamentRadioGroup: xcb_xkb_permament_radio_group_behavior_t;
    permamentOverlay1:   xcb_xkb_permament_overlay_behavior_t;
    permamentOverlay2:   xcb_xkb_permament_overlay_behavior_t;
    type:                u8;
}

xcb_xkb_behavior_iterator_t :: struct {
    data:  *xcb_xkb_behavior_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_behavior_type_t :: enum u32 {
    DEFAULT               :: 0;
    LOCK                  :: 1;
    RADIO_GROUP           :: 2;
    OVERLAY_1             :: 3;
    OVERLAY_2             :: 4;
    PERMAMENT_LOCK        :: 129;
    PERMAMENT_RADIO_GROUP :: 130;
    PERMAMENT_OVERLAY_1   :: 131;
    PERMAMENT_OVERLAY_2   :: 132;

    XCB_XKB_BEHAVIOR_TYPE_DEFAULT               :: DEFAULT;
    XCB_XKB_BEHAVIOR_TYPE_LOCK                  :: LOCK;
    XCB_XKB_BEHAVIOR_TYPE_RADIO_GROUP           :: RADIO_GROUP;
    XCB_XKB_BEHAVIOR_TYPE_OVERLAY_1             :: OVERLAY_1;
    XCB_XKB_BEHAVIOR_TYPE_OVERLAY_2             :: OVERLAY_2;
    XCB_XKB_BEHAVIOR_TYPE_PERMAMENT_LOCK        :: PERMAMENT_LOCK;
    XCB_XKB_BEHAVIOR_TYPE_PERMAMENT_RADIO_GROUP :: PERMAMENT_RADIO_GROUP;
    XCB_XKB_BEHAVIOR_TYPE_PERMAMENT_OVERLAY_1   :: PERMAMENT_OVERLAY_1;
    XCB_XKB_BEHAVIOR_TYPE_PERMAMENT_OVERLAY_2   :: PERMAMENT_OVERLAY_2;
}

xcb_xkb_set_behavior_t :: struct {
    keycode:  xcb_keycode_t;
    behavior: xcb_xkb_behavior_t;
    pad0:     u8;
}

xcb_xkb_set_behavior_iterator_t :: struct {
    data:  *xcb_xkb_set_behavior_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_set_explicit_t :: struct {
    keycode:  xcb_keycode_t;
    explicit: u8;
}

xcb_xkb_set_explicit_iterator_t :: struct {
    data:  *xcb_xkb_set_explicit_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_key_mod_map_t :: struct {
    keycode: xcb_keycode_t;
    mods:    u8;
}

xcb_xkb_key_mod_map_iterator_t :: struct {
    data:  *xcb_xkb_key_mod_map_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_key_v_mod_map_t :: struct {
    keycode: xcb_keycode_t;
    pad0:    u8;
    vmods:   u16;
}

xcb_xkb_key_v_mod_map_iterator_t :: struct {
    data:  *xcb_xkb_key_v_mod_map_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_kt_set_map_entry_t :: struct {
    level:       u8;
    realMods:    u8;
    virtualMods: u16;
}

xcb_xkb_kt_set_map_entry_iterator_t :: struct {
    data:  *xcb_xkb_kt_set_map_entry_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_set_key_type_t :: struct {
    mask:        u8;
    realMods:    u8;
    virtualMods: u16;
    numLevels:   u8;
    nMapEntries: u8;
    preserve:    u8;
    pad0:        u8;
}

xcb_xkb_set_key_type_iterator_t :: struct {
    data:  *xcb_xkb_set_key_type_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_string8_t :: u8;

xcb_xkb_string8_iterator_t :: struct {
    data:  *xcb_xkb_string8_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_outline_t :: struct {
    nPoints:      u8;
    cornerRadius: u8;
    pad0:         [2] u8;
}

xcb_xkb_outline_iterator_t :: struct {
    data:  *xcb_xkb_outline_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_shape_t :: struct {
    name:       xcb_atom_t;
    nOutlines:  u8;
    primaryNdx: u8;
    approxNdx:  u8;
    pad0:       u8;
}

xcb_xkb_shape_iterator_t :: struct {
    data:  *xcb_xkb_shape_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_key_t :: struct {
    name:     [4] xcb_xkb_string8_t;
    gap:      s16;
    shapeNdx: u8;
    colorNdx: u8;
}

xcb_xkb_key_iterator_t :: struct {
    data:  *xcb_xkb_key_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_overlay_key_t :: struct {
    over:  [4] xcb_xkb_string8_t;
    under: [4] xcb_xkb_string8_t;
}

xcb_xkb_overlay_key_iterator_t :: struct {
    data:  *xcb_xkb_overlay_key_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_overlay_row_t :: struct {
    rowUnder: u8;
    nKeys:    u8;
    pad0:     [2] u8;
}

xcb_xkb_overlay_row_iterator_t :: struct {
    data:  *xcb_xkb_overlay_row_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_overlay_t :: struct {
    name:  xcb_atom_t;
    nRows: u8;
    pad0:  [3] u8;
}

xcb_xkb_overlay_iterator_t :: struct {
    data:  *xcb_xkb_overlay_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_row_t :: struct {
    top:      s16;
    left:     s16;
    nKeys:    u8;
    vertical: u8;
    pad0:     [2] u8;
}

xcb_xkb_row_iterator_t :: struct {
    data:  *xcb_xkb_row_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_doodad_type_t :: enum u32 {
    OUTLINE   :: 1;
    SOLID     :: 2;
    TEXT      :: 3;
    INDICATOR :: 4;
    LOGO      :: 5;

    XCB_XKB_DOODAD_TYPE_OUTLINE   :: OUTLINE;
    XCB_XKB_DOODAD_TYPE_SOLID     :: SOLID;
    XCB_XKB_DOODAD_TYPE_TEXT      :: TEXT;
    XCB_XKB_DOODAD_TYPE_INDICATOR :: INDICATOR;
    XCB_XKB_DOODAD_TYPE_LOGO      :: LOGO;
}

xcb_xkb_listing_t :: struct {
    flags:  u16;
    length: u16;
}

xcb_xkb_listing_iterator_t :: struct {
    data:  *xcb_xkb_listing_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_device_led_info_t :: struct {
    ledClass:       xcb_xkb_led_class_spec_t;
    ledID:          xcb_xkb_id_spec_t;
    namesPresent:   u32;
    mapsPresent:    u32;
    physIndicators: u32;
    state:          u32;
}

xcb_xkb_device_led_info_iterator_t :: struct {
    data:  *xcb_xkb_device_led_info_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_error_t :: enum u32 {
    DEVICE :: 255;
    CLASS  :: 254;
    ID     :: 253;

    XCB_XKB_ERROR_BAD_DEVICE :: DEVICE;
    XCB_XKB_ERROR_BAD_CLASS  :: CLASS;
    XCB_XKB_ERROR_BAD_ID     :: ID;
}

xcb_xkb_keyboard_error_t :: struct {
    response_type: u8;
    error_code:    u8;
    sequence:      u16;
    value:         u32;
    minorOpcode:   u16;
    majorOpcode:   u8;
    pad0:          [21] u8;
}

xcb_xkb_sa_t :: enum u32 {
    CLEAR_LOCKS      :: 1;
    LATCH_TO_LOCK    :: 2;
    USE_MOD_MAP_MODS :: 4;
    GROUP_ABSOLUTE   :: 4;

    XCB_XKB_SA_CLEAR_LOCKS      :: CLEAR_LOCKS;
    XCB_XKB_SA_LATCH_TO_LOCK    :: LATCH_TO_LOCK;
    XCB_XKB_SA_USE_MOD_MAP_MODS :: USE_MOD_MAP_MODS;
    XCB_XKB_SA_GROUP_ABSOLUTE   :: GROUP_ABSOLUTE;
}

xcb_xkb_sa_type_t :: enum u32 {
    NO_ACTION       :: 0;
    SET_MODS        :: 1;
    LATCH_MODS      :: 2;
    LOCK_MODS       :: 3;
    SET_GROUP       :: 4;
    LATCH_GROUP     :: 5;
    LOCK_GROUP      :: 6;
    MOVE_PTR        :: 7;
    PTR_BTN         :: 8;
    LOCK_PTR_BTN    :: 9;
    SET_PTR_DFLT    :: 10;
    ISO_LOCK        :: 11;
    TERMINATE       :: 12;
    SWITCH_SCREEN   :: 13;
    SET_CONTROLS    :: 14;
    LOCK_CONTROLS   :: 15;
    ACTION_MESSAGE  :: 16;
    REDIRECT_KEY    :: 17;
    DEVICE_BTN      :: 18;
    LOCK_DEVICE_BTN :: 19;
    DEVICE_VALUATOR :: 20;

    XCB_XKB_SA_TYPE_NO_ACTION       :: NO_ACTION;
    XCB_XKB_SA_TYPE_SET_MODS        :: SET_MODS;
    XCB_XKB_SA_TYPE_LATCH_MODS      :: LATCH_MODS;
    XCB_XKB_SA_TYPE_LOCK_MODS       :: LOCK_MODS;
    XCB_XKB_SA_TYPE_SET_GROUP       :: SET_GROUP;
    XCB_XKB_SA_TYPE_LATCH_GROUP     :: LATCH_GROUP;
    XCB_XKB_SA_TYPE_LOCK_GROUP      :: LOCK_GROUP;
    XCB_XKB_SA_TYPE_MOVE_PTR        :: MOVE_PTR;
    XCB_XKB_SA_TYPE_PTR_BTN         :: PTR_BTN;
    XCB_XKB_SA_TYPE_LOCK_PTR_BTN    :: LOCK_PTR_BTN;
    XCB_XKB_SA_TYPE_SET_PTR_DFLT    :: SET_PTR_DFLT;
    XCB_XKB_SA_TYPE_ISO_LOCK        :: ISO_LOCK;
    XCB_XKB_SA_TYPE_TERMINATE       :: TERMINATE;
    XCB_XKB_SA_TYPE_SWITCH_SCREEN   :: SWITCH_SCREEN;
    XCB_XKB_SA_TYPE_SET_CONTROLS    :: SET_CONTROLS;
    XCB_XKB_SA_TYPE_LOCK_CONTROLS   :: LOCK_CONTROLS;
    XCB_XKB_SA_TYPE_ACTION_MESSAGE  :: ACTION_MESSAGE;
    XCB_XKB_SA_TYPE_REDIRECT_KEY    :: REDIRECT_KEY;
    XCB_XKB_SA_TYPE_DEVICE_BTN      :: DEVICE_BTN;
    XCB_XKB_SA_TYPE_LOCK_DEVICE_BTN :: LOCK_DEVICE_BTN;
    XCB_XKB_SA_TYPE_DEVICE_VALUATOR :: DEVICE_VALUATOR;
}

xcb_xkb_sa_no_action_t :: struct {
    type: u8;
    pad0: [7] u8;
}

xcb_xkb_sa_no_action_iterator_t :: struct {
    data:  *xcb_xkb_sa_no_action_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_set_mods_t :: struct {
    type:      u8;
    flags:     u8;
    mask:      u8;
    realMods:  u8;
    vmodsHigh: u8;
    vmodsLow:  u8;
    pad0:      [2] u8;
}

xcb_xkb_sa_set_mods_iterator_t :: struct {
    data:  *xcb_xkb_sa_set_mods_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_latch_mods_t :: struct {
    type:      u8;
    flags:     u8;
    mask:      u8;
    realMods:  u8;
    vmodsHigh: u8;
    vmodsLow:  u8;
    pad0:      [2] u8;
}

xcb_xkb_sa_latch_mods_iterator_t :: struct {
    data:  *xcb_xkb_sa_latch_mods_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_lock_mods_t :: struct {
    type:      u8;
    flags:     u8;
    mask:      u8;
    realMods:  u8;
    vmodsHigh: u8;
    vmodsLow:  u8;
    pad0:      [2] u8;
}

xcb_xkb_sa_lock_mods_iterator_t :: struct {
    data:  *xcb_xkb_sa_lock_mods_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_set_group_t :: struct {
    type:  u8;
    flags: u8;
    group: s8;
    pad0:  [5] u8;
}

xcb_xkb_sa_set_group_iterator_t :: struct {
    data:  *xcb_xkb_sa_set_group_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_latch_group_t :: struct {
    type:  u8;
    flags: u8;
    group: s8;
    pad0:  [5] u8;
}

xcb_xkb_sa_latch_group_iterator_t :: struct {
    data:  *xcb_xkb_sa_latch_group_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_lock_group_t :: struct {
    type:  u8;
    flags: u8;
    group: s8;
    pad0:  [5] u8;
}

xcb_xkb_sa_lock_group_iterator_t :: struct {
    data:  *xcb_xkb_sa_lock_group_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_move_ptr_flag_t :: enum u32 {
    NO_ACCELERATION :: 1;
    MOVE_ABSOLUTE_X :: 2;
    MOVE_ABSOLUTE_Y :: 4;

    XCB_XKB_SA_MOVE_PTR_FLAG_NO_ACCELERATION :: NO_ACCELERATION;
    XCB_XKB_SA_MOVE_PTR_FLAG_MOVE_ABSOLUTE_X :: MOVE_ABSOLUTE_X;
    XCB_XKB_SA_MOVE_PTR_FLAG_MOVE_ABSOLUTE_Y :: MOVE_ABSOLUTE_Y;
}

xcb_xkb_sa_move_ptr_t :: struct {
    type:  u8;
    flags: u8;
    xHigh: s8;
    xLow:  u8;
    yHigh: s8;
    yLow:  u8;
    pad0:  [2] u8;
}

xcb_xkb_sa_move_ptr_iterator_t :: struct {
    data:  *xcb_xkb_sa_move_ptr_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_ptr_btn_t :: struct {
    type:   u8;
    flags:  u8;
    count:  u8;
    button: u8;
    pad0:   [4] u8;
}

xcb_xkb_sa_ptr_btn_iterator_t :: struct {
    data:  *xcb_xkb_sa_ptr_btn_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_lock_ptr_btn_t :: struct {
    type:   u8;
    flags:  u8;
    pad0:   u8;
    button: u8;
    pad1:   [4] u8;
}

xcb_xkb_sa_lock_ptr_btn_iterator_t :: struct {
    data:  *xcb_xkb_sa_lock_ptr_btn_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_set_ptr_dflt_flag_t :: enum u32 {
    DFLT_BTN_ABSOLUTE  :: 4;
    AFFECT_DFLT_BUTTON :: 1;

    XCB_XKB_SA_SET_PTR_DFLT_FLAG_DFLT_BTN_ABSOLUTE  :: DFLT_BTN_ABSOLUTE;
    XCB_XKB_SA_SET_PTR_DFLT_FLAG_AFFECT_DFLT_BUTTON :: AFFECT_DFLT_BUTTON;
}

xcb_xkb_sa_set_ptr_dflt_t :: struct {
    type:   u8;
    flags:  u8;
    affect: u8;
    value:  s8;
    pad0:   [4] u8;
}

xcb_xkb_sa_set_ptr_dflt_iterator_t :: struct {
    data:  *xcb_xkb_sa_set_ptr_dflt_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_iso_lock_flag_t :: enum u32 {
    NO_LOCK           :: 1;
    NO_UNLOCK         :: 2;
    USE_MOD_MAP_MODS  :: 4;
    GROUP_ABSOLUTE    :: 4;
    ISO_DFLT_IS_GROUP :: 8;

    XCB_XKB_SA_ISO_LOCK_FLAG_NO_LOCK           :: NO_LOCK;
    XCB_XKB_SA_ISO_LOCK_FLAG_NO_UNLOCK         :: NO_UNLOCK;
    XCB_XKB_SA_ISO_LOCK_FLAG_USE_MOD_MAP_MODS  :: USE_MOD_MAP_MODS;
    XCB_XKB_SA_ISO_LOCK_FLAG_GROUP_ABSOLUTE    :: GROUP_ABSOLUTE;
    XCB_XKB_SA_ISO_LOCK_FLAG_ISO_DFLT_IS_GROUP :: ISO_DFLT_IS_GROUP;
}

xcb_xkb_sa_iso_lock_no_affect_t :: enum u32 {
    CTRLS :: 8;
    PTR   :: 16;
    GROUP :: 32;
    MODS  :: 64;

    XCB_XKB_SA_ISO_LOCK_NO_AFFECT_CTRLS :: CTRLS;
    XCB_XKB_SA_ISO_LOCK_NO_AFFECT_PTR   :: PTR;
    XCB_XKB_SA_ISO_LOCK_NO_AFFECT_GROUP :: GROUP;
    XCB_XKB_SA_ISO_LOCK_NO_AFFECT_MODS  :: MODS;
}

xcb_xkb_sa_iso_lock_t :: struct {
    type:      u8;
    flags:     u8;
    mask:      u8;
    realMods:  u8;
    group:     s8;
    affect:    u8;
    vmodsHigh: u8;
    vmodsLow:  u8;
}

xcb_xkb_sa_iso_lock_iterator_t :: struct {
    data:  *xcb_xkb_sa_iso_lock_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_terminate_t :: struct {
    type: u8;
    pad0: [7] u8;
}

xcb_xkb_sa_terminate_iterator_t :: struct {
    data:  *xcb_xkb_sa_terminate_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_switch_screen_flag_t :: enum u32 {
    APPLICATION :: 1;
    ABSOLUTE    :: 4;

    XCB_XKB_SWITCH_SCREEN_FLAG_APPLICATION :: APPLICATION;
    XCB_XKB_SWITCH_SCREEN_FLAG_ABSOLUTE    :: ABSOLUTE;
}

xcb_xkb_sa_switch_screen_t :: struct {
    type:      u8;
    flags:     u8;
    newScreen: s8;
    pad0:      [5] u8;
}

xcb_xkb_sa_switch_screen_iterator_t :: struct {
    data:  *xcb_xkb_sa_switch_screen_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_bool_ctrls_high_t :: enum u32 {
    ACCESS_X_FEEDBACK :: 1;
    AUDIBLE_BELL      :: 2;
    OVERLAY_1         :: 4;
    OVERLAY_2         :: 8;
    IGNORE_GROUP_LOCK :: 16;

    XCB_XKB_BOOL_CTRLS_HIGH_ACCESS_X_FEEDBACK :: ACCESS_X_FEEDBACK;
    XCB_XKB_BOOL_CTRLS_HIGH_AUDIBLE_BELL      :: AUDIBLE_BELL;
    XCB_XKB_BOOL_CTRLS_HIGH_OVERLAY_1         :: OVERLAY_1;
    XCB_XKB_BOOL_CTRLS_HIGH_OVERLAY_2         :: OVERLAY_2;
    XCB_XKB_BOOL_CTRLS_HIGH_IGNORE_GROUP_LOCK :: IGNORE_GROUP_LOCK;
}

xcb_xkb_bool_ctrls_low_t :: enum u32 {
    REPEAT_KEYS      :: 1;
    SLOW_KEYS        :: 2;
    BOUNCE_KEYS      :: 4;
    STICKY_KEYS      :: 8;
    MOUSE_KEYS       :: 16;
    MOUSE_KEYS_ACCEL :: 32;
    ACCESS_X_KEYS    :: 64;
    ACCESS_X_TIMEOUT :: 128;

    XCB_XKB_BOOL_CTRLS_LOW_REPEAT_KEYS      :: REPEAT_KEYS;
    XCB_XKB_BOOL_CTRLS_LOW_SLOW_KEYS        :: SLOW_KEYS;
    XCB_XKB_BOOL_CTRLS_LOW_BOUNCE_KEYS      :: BOUNCE_KEYS;
    XCB_XKB_BOOL_CTRLS_LOW_STICKY_KEYS      :: STICKY_KEYS;
    XCB_XKB_BOOL_CTRLS_LOW_MOUSE_KEYS       :: MOUSE_KEYS;
    XCB_XKB_BOOL_CTRLS_LOW_MOUSE_KEYS_ACCEL :: MOUSE_KEYS_ACCEL;
    XCB_XKB_BOOL_CTRLS_LOW_ACCESS_X_KEYS    :: ACCESS_X_KEYS;
    XCB_XKB_BOOL_CTRLS_LOW_ACCESS_X_TIMEOUT :: ACCESS_X_TIMEOUT;
}

xcb_xkb_sa_set_controls_t :: struct {
    type:          u8;
    pad0:          [3] u8;
    boolCtrlsHigh: u8;
    boolCtrlsLow:  u8;
    pad1:          [2] u8;
}

xcb_xkb_sa_set_controls_iterator_t :: struct {
    data:  *xcb_xkb_sa_set_controls_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_lock_controls_t :: struct {
    type:          u8;
    pad0:          [3] u8;
    boolCtrlsHigh: u8;
    boolCtrlsLow:  u8;
    pad1:          [2] u8;
}

xcb_xkb_sa_lock_controls_iterator_t :: struct {
    data:  *xcb_xkb_sa_lock_controls_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_action_message_flag_t :: enum u32 {
    ON_PRESS      :: 1;
    ON_RELEASE    :: 2;
    GEN_KEY_EVENT :: 4;

    XCB_XKB_ACTION_MESSAGE_FLAG_ON_PRESS      :: ON_PRESS;
    XCB_XKB_ACTION_MESSAGE_FLAG_ON_RELEASE    :: ON_RELEASE;
    XCB_XKB_ACTION_MESSAGE_FLAG_GEN_KEY_EVENT :: GEN_KEY_EVENT;
}

xcb_xkb_sa_action_message_t :: struct {
    type:    u8;
    flags:   u8;
    message: [6] u8;
}

xcb_xkb_sa_action_message_iterator_t :: struct {
    data:  *xcb_xkb_sa_action_message_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_redirect_key_t :: struct {
    type:          u8;
    newkey:        xcb_keycode_t;
    mask:          u8;
    realModifiers: u8;
    vmodsMaskHigh: u8;
    vmodsMaskLow:  u8;
    vmodsHigh:     u8;
    vmodsLow:      u8;
}

xcb_xkb_sa_redirect_key_iterator_t :: struct {
    data:  *xcb_xkb_sa_redirect_key_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_device_btn_t :: struct {
    type:   u8;
    flags:  u8;
    count:  u8;
    button: u8;
    device: u8;
    pad0:   [3] u8;
}

xcb_xkb_sa_device_btn_iterator_t :: struct {
    data:  *xcb_xkb_sa_device_btn_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_lock_device_flags_t :: enum u32 {
    LOCK   :: 1;
    UNLOCK :: 2;

    XCB_XKB_LOCK_DEVICE_FLAGS_NO_LOCK   :: LOCK;
    XCB_XKB_LOCK_DEVICE_FLAGS_NO_UNLOCK :: UNLOCK;
}

xcb_xkb_sa_lock_device_btn_t :: struct {
    type:   u8;
    flags:  u8;
    pad0:   u8;
    button: u8;
    device: u8;
    pad1:   [3] u8;
}

xcb_xkb_sa_lock_device_btn_iterator_t :: struct {
    data:  *xcb_xkb_sa_lock_device_btn_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sa_val_what_t :: enum u32 {
    IGNORE_VAL       :: 0;
    SET_VAL_MIN      :: 1;
    SET_VAL_CENTER   :: 2;
    SET_VAL_MAX      :: 3;
    SET_VAL_RELATIVE :: 4;
    SET_VAL_ABSOLUTE :: 5;

    XCB_XKB_SA_VAL_WHAT_IGNORE_VAL       :: IGNORE_VAL;
    XCB_XKB_SA_VAL_WHAT_SET_VAL_MIN      :: SET_VAL_MIN;
    XCB_XKB_SA_VAL_WHAT_SET_VAL_CENTER   :: SET_VAL_CENTER;
    XCB_XKB_SA_VAL_WHAT_SET_VAL_MAX      :: SET_VAL_MAX;
    XCB_XKB_SA_VAL_WHAT_SET_VAL_RELATIVE :: SET_VAL_RELATIVE;
    XCB_XKB_SA_VAL_WHAT_SET_VAL_ABSOLUTE :: SET_VAL_ABSOLUTE;
}

xcb_xkb_sa_device_valuator_t :: struct {
    type:      u8;
    device:    u8;
    val1what:  u8;
    val1index: u8;
    val1value: u8;
    val2what:  u8;
    val2index: u8;
    val2value: u8;
}

xcb_xkb_sa_device_valuator_iterator_t :: struct {
    data:  *xcb_xkb_sa_device_valuator_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_si_action_t :: struct {
    type: u8;
    data: [7] u8;
}

xcb_xkb_si_action_iterator_t :: struct {
    data:  *xcb_xkb_si_action_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_sym_interpret_t :: struct {
    sym:        xcb_keysym_t;
    mods:       u8;
    match:      u8;
    virtualMod: u8;
    flags:      u8;
    action:     xcb_xkb_si_action_t;
}

xcb_xkb_sym_interpret_iterator_t :: struct {
    data:  *xcb_xkb_sym_interpret_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_action_t :: union {
    noaction:     xcb_xkb_sa_no_action_t;
    setmods:      xcb_xkb_sa_set_mods_t;
    latchmods:    xcb_xkb_sa_latch_mods_t;
    lockmods:     xcb_xkb_sa_lock_mods_t;
    setgroup:     xcb_xkb_sa_set_group_t;
    latchgroup:   xcb_xkb_sa_latch_group_t;
    lockgroup:    xcb_xkb_sa_lock_group_t;
    moveptr:      xcb_xkb_sa_move_ptr_t;
    ptrbtn:       xcb_xkb_sa_ptr_btn_t;
    lockptrbtn:   xcb_xkb_sa_lock_ptr_btn_t;
    setptrdflt:   xcb_xkb_sa_set_ptr_dflt_t;
    isolock:      xcb_xkb_sa_iso_lock_t;
    terminate:    xcb_xkb_sa_terminate_t;
    switchscreen: xcb_xkb_sa_switch_screen_t;
    setcontrols:  xcb_xkb_sa_set_controls_t;
    lockcontrols: xcb_xkb_sa_lock_controls_t;
    message:      xcb_xkb_sa_action_message_t;
    redirect:     xcb_xkb_sa_redirect_key_t;
    devbtn:       xcb_xkb_sa_device_btn_t;
    lockdevbtn:   xcb_xkb_sa_lock_device_btn_t;
    devval:       xcb_xkb_sa_device_valuator_t;
    type:         u8;
}

xcb_xkb_action_iterator_t :: struct {
    data:  *xcb_xkb_action_t;
    rem:   s32;
    index: s32;
}

xcb_xkb_use_extension_cookie_t :: struct {
    sequence: u32;
}

xcb_xkb_use_extension_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    wantedMajor:  u16;
    wantedMinor:  u16;
}

xcb_xkb_use_extension_reply_t :: struct {
    response_type: u8;
    supported:     u8;
    sequence:      u16;
    length:        u32;
    serverMajor:   u16;
    serverMinor:   u16;
    pad0:          [20] u8;
}

xcb_xkb_select_events_details_t :: struct {
    affectNewKeyboard:     xcb_xkb_nkn_detail_t;
    newKeyboardDetails:    xcb_xkb_nkn_detail_t;
    affectState:           xcb_xkb_state_part_t;
    stateDetails:          xcb_xkb_state_part_t;
    affectCtrls:           xcb_xkb_control_t;
    ctrlDetails:           xcb_xkb_control_t;
    affectIndicatorState:  u32;
    indicatorStateDetails: u32;
    affectIndicatorMap:    u32;
    indicatorMapDetails:   u32;
    affectNames:           u16;
    namesDetails:          u16;
    affectCompat:          u8;
    compatDetails:         u8;
    affectBell:            u8;
    bellDetails:           u8;
    affectMsgDetails:      u8;
    msgDetails:            u8;
    affectAccessX:         u16;
    accessXDetails:        u16;
    affectExtDev:          u16;
    extdevDetails:         u16;
}

xcb_xkb_select_events_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceSpec:   xcb_xkb_device_spec_t;
    affectWhich:  xcb_xkb_event_type_t;
    clear:        xcb_xkb_event_type_t;
    selectAll:    xcb_xkb_event_type_t;
    affectMap:    xcb_xkb_map_part_t;
    map:          xcb_xkb_map_part_t;
}

xcb_xkb_bell_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceSpec:   xcb_xkb_device_spec_t;
    bellClass:    xcb_xkb_bell_class_spec_t;
    bellID:       xcb_xkb_id_spec_t;
    percent:      s8;
    forceSound:   u8;
    eventOnly:    u8;
    pad0:         u8;
    pitch:        s16;
    duration:     s16;
    pad1:         [2] u8;
    name:         xcb_atom_t;
    window:       xcb_window_t;
}

xcb_xkb_get_state_cookie_t :: struct {
    sequence: u32;
}

xcb_xkb_get_state_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceSpec:   xcb_xkb_device_spec_t;
    pad0:         [2] u8;
}

xcb_xkb_get_state_reply_t :: struct {
    response_type:    u8;
    deviceID:         u8;
    sequence:         u16;
    length:           u32;
    mods:             u8;
    baseMods:         u8;
    latchedMods:      u8;
    lockedMods:       u8;
    group:            u8;
    lockedGroup:      u8;
    baseGroup:        s16;
    latchedGroup:     s16;
    compatState:      u8;
    grabMods:         u8;
    compatGrabMods:   u8;
    lookupMods:       u8;
    compatLookupMods: u8;
    pad0:             u8;
    ptrBtnState:      u16;
    pad1:             [6] u8;
}

xcb_xkb_latch_lock_state_request_t :: struct {
    major_opcode:     u8;
    minor_opcode:     u8;
    length:           u16;
    deviceSpec:       xcb_xkb_device_spec_t;
    affectModLocks:   u8;
    modLocks:         u8;
    lockGroup:        u8;
    groupLock:        u8;
    affectModLatches: u8;
    pad0:             u8;
    pad1:             u8;
    latchGroup:       u8;
    groupLatch:       u16;
}

xcb_xkb_get_controls_cookie_t :: struct {
    sequence: u32;
}

xcb_xkb_get_controls_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceSpec:   xcb_xkb_device_spec_t;
    pad0:         [2] u8;
}

xcb_xkb_get_controls_reply_t :: struct {
    response_type:               u8;
    deviceID:                    u8;
    sequence:                    u16;
    length:                      u32;
    mouseKeysDfltBtn:            u8;
    numGroups:                   u8;
    groupsWrap:                  u8;
    internalModsMask:            u8;
    ignoreLockModsMask:          u8;
    internalModsRealMods:        u8;
    ignoreLockModsRealMods:      u8;
    pad0:                        u8;
    internalModsVmods:           u16;
    ignoreLockModsVmods:         u16;
    repeatDelay:                 u16;
    repeatInterval:              u16;
    slowKeysDelay:               u16;
    debounceDelay:               u16;
    mouseKeysDelay:              u16;
    mouseKeysInterval:           u16;
    mouseKeysTimeToMax:          u16;
    mouseKeysMaxSpeed:           u16;
    mouseKeysCurve:              s16;
    accessXOption:               u16;
    accessXTimeout:              u16;
    accessXTimeoutOptionsMask:   u16;
    accessXTimeoutOptionsValues: u16;
    pad1:                        [2] u8;
    accessXTimeoutMask:          u32;
    accessXTimeoutValues:        u32;
    enabledControls:             u32;
    perKeyRepeat:                [32] u8;
}

xcb_xkb_set_controls_request_t :: struct {
    major_opcode:                u8;
    minor_opcode:                u8;
    length:                      u16;
    deviceSpec:                  xcb_xkb_device_spec_t;
    affectInternalRealMods:      u8;
    internalRealMods:            u8;
    affectIgnoreLockRealMods:    u8;
    ignoreLockRealMods:          u8;
    affectInternalVirtualMods:   u16;
    internalVirtualMods:         u16;
    affectIgnoreLockVirtualMods: u16;
    ignoreLockVirtualMods:       u16;
    mouseKeysDfltBtn:            u8;
    groupsWrap:                  u8;
    accessXOptions:              u16;
    pad0:                        [2] u8;
    affectEnabledControls:       u32;
    enabledControls:             u32;
    changeControls:              u32;
    repeatDelay:                 u16;
    repeatInterval:              u16;
    slowKeysDelay:               u16;
    debounceDelay:               u16;
    mouseKeysDelay:              u16;
    mouseKeysInterval:           u16;
    mouseKeysTimeToMax:          u16;
    mouseKeysMaxSpeed:           u16;
    mouseKeysCurve:              s16;
    accessXTimeout:              u16;
    accessXTimeoutMask:          u32;
    accessXTimeoutValues:        u32;
    accessXTimeoutOptionsMask:   u16;
    accessXTimeoutOptionsValues: u16;
    perKeyRepeat:                [32] u8;
}

xcb_xkb_get_map_cookie_t :: struct {
    sequence: u32;
}

xcb_xkb_get_map_request_t :: struct {
    major_opcode:     u8;
    minor_opcode:     u8;
    length:           u16;
    deviceSpec:       xcb_xkb_device_spec_t;
    full:             u16;
    partial:          u16;
    firstType:        u8;
    nTypes:           u8;
    firstKeySym:      xcb_keycode_t;
    nKeySyms:         u8;
    firstKeyAction:   xcb_keycode_t;
    nKeyActions:      u8;
    firstKeyBehavior: xcb_keycode_t;
    nKeyBehaviors:    u8;
    virtualMods:      u16;
    firstKeyExplicit: xcb_keycode_t;
    nKeyExplicit:     u8;
    firstModMapKey:   xcb_keycode_t;
    nModMapKeys:      u8;
    firstVModMapKey:  xcb_keycode_t;
    nVModMapKeys:     u8;
    pad0:             [2] u8;
}

xcb_xkb_get_map_map_t :: struct {
    types_rtrn:      *xcb_xkb_key_type_t;
    syms_rtrn:       *xcb_xkb_key_sym_map_t;
    acts_rtrn_count: *u8;
    pad2:            *u8;
    acts_rtrn_acts:  *xcb_xkb_action_t;
    behaviors_rtrn:  *xcb_xkb_set_behavior_t;
    vmods_rtrn:      *u8;
    pad3:            *u8;
    explicit_rtrn:   *xcb_xkb_set_explicit_t;
    pad4:            *u8;
    modmap_rtrn:     *xcb_xkb_key_mod_map_t;
    pad5:            *u8;
    vmodmap_rtrn:    *xcb_xkb_key_v_mod_map_t;
}

xcb_xkb_get_map_reply_t :: struct {
    response_type:     u8;
    deviceID:          u8;
    sequence:          u16;
    length:            u32;
    pad0:              [2] u8;
    minKeyCode:        xcb_keycode_t;
    maxKeyCode:        xcb_keycode_t;
    present:           u16;
    firstType:         u8;
    nTypes:            u8;
    totalTypes:        u8;
    firstKeySym:       xcb_keycode_t;
    totalSyms:         u16;
    nKeySyms:          u8;
    firstKeyAction:    xcb_keycode_t;
    totalActions:      u16;
    nKeyActions:       u8;
    firstKeyBehavior:  xcb_keycode_t;
    nKeyBehaviors:     u8;
    totalKeyBehaviors: u8;
    firstKeyExplicit:  xcb_keycode_t;
    nKeyExplicit:      u8;
    totalKeyExplicit:  u8;
    firstModMapKey:    xcb_keycode_t;
    nModMapKeys:       u8;
    totalModMapKeys:   u8;
    firstVModMapKey:   xcb_keycode_t;
    nVModMapKeys:      u8;
    totalVModMapKeys:  u8;
    pad1:              u8;
    virtualMods:       u16;
}

xcb_xkb_set_map_values_t :: struct {
    types:        *xcb_xkb_set_key_type_t;
    syms:         *xcb_xkb_key_sym_map_t;
    actionsCount: *u8;
    actions:      *xcb_xkb_action_t;
    behaviors:    *xcb_xkb_set_behavior_t;
    vmods:        *u8;
    explicit:     *xcb_xkb_set_explicit_t;
    modmap:       *xcb_xkb_key_mod_map_t;
    vmodmap:      *xcb_xkb_key_v_mod_map_t;
}

xcb_xkb_set_map_request_t :: struct {
    major_opcode:      u8;
    minor_opcode:      u8;
    length:            u16;
    deviceSpec:        xcb_xkb_device_spec_t;
    present:           u16;
    flags:             u16;
    minKeyCode:        xcb_keycode_t;
    maxKeyCode:        xcb_keycode_t;
    firstType:         u8;
    nTypes:            u8;
    firstKeySym:       xcb_keycode_t;
    nKeySyms:          u8;
    totalSyms:         u16;
    firstKeyAction:    xcb_keycode_t;
    nKeyActions:       u8;
    totalActions:      u16;
    firstKeyBehavior:  xcb_keycode_t;
    nKeyBehaviors:     u8;
    totalKeyBehaviors: u8;
    firstKeyExplicit:  xcb_keycode_t;
    nKeyExplicit:      u8;
    totalKeyExplicit:  u8;
    firstModMapKey:    xcb_keycode_t;
    nModMapKeys:       u8;
    totalModMapKeys:   u8;
    firstVModMapKey:   xcb_keycode_t;
    nVModMapKeys:      u8;
    totalVModMapKeys:  u8;
    virtualMods:       u16;
}

xcb_xkb_get_compat_map_cookie_t :: struct {
    sequence: u32;
}

xcb_xkb_get_compat_map_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceSpec:   xcb_xkb_device_spec_t;
    groups:       u8;
    getAllSI:     u8;
    firstSI:      u16;
    nSI:          u16;
}

xcb_xkb_get_compat_map_reply_t :: struct {
    response_type: u8;
    deviceID:      u8;
    sequence:      u16;
    length:        u32;
    groupsRtrn:    u8;
    pad0:          u8;
    firstSIRtrn:   u16;
    nSIRtrn:       u16;
    nTotalSI:      u16;
    pad1:          [16] u8;
}

xcb_xkb_set_compat_map_request_t :: struct {
    major_opcode:     u8;
    minor_opcode:     u8;
    length:           u16;
    deviceSpec:       xcb_xkb_device_spec_t;
    pad0:             u8;
    recomputeActions: u8;
    truncateSI:       u8;
    groups:           u8;
    firstSI:          u16;
    nSI:              u16;
    pad1:             [2] u8;
}

xcb_xkb_get_indicator_state_cookie_t :: struct {
    sequence: u32;
}

xcb_xkb_get_indicator_state_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceSpec:   xcb_xkb_device_spec_t;
    pad0:         [2] u8;
}

xcb_xkb_get_indicator_state_reply_t :: struct {
    response_type: u8;
    deviceID:      u8;
    sequence:      u16;
    length:        u32;
    state:         u32;
    pad0:          [20] u8;
}

xcb_xkb_get_indicator_map_cookie_t :: struct {
    sequence: u32;
}

xcb_xkb_get_indicator_map_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceSpec:   xcb_xkb_device_spec_t;
    pad0:         [2] u8;
    which:        u32;
}

xcb_xkb_get_indicator_map_reply_t :: struct {
    response_type:  u8;
    deviceID:       u8;
    sequence:       u16;
    length:         u32;
    which:          u32;
    realIndicators: u32;
    nIndicators:    u8;
    pad0:           [15] u8;
}

xcb_xkb_set_indicator_map_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceSpec:   xcb_xkb_device_spec_t;
    pad0:         [2] u8;
    which:        u32;
}

xcb_xkb_get_named_indicator_cookie_t :: struct {
    sequence: u32;
}

xcb_xkb_get_named_indicator_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceSpec:   xcb_xkb_device_spec_t;
    ledClass:     xcb_xkb_led_class_spec_t;
    ledID:        xcb_xkb_id_spec_t;
    pad0:         [2] u8;
    indicator:    xcb_atom_t;
}

xcb_xkb_get_named_indicator_reply_t :: struct {
    response_type:   u8;
    deviceID:        u8;
    sequence:        u16;
    length:          u32;
    indicator:       xcb_atom_t;
    found:           u8;
    on:              u8;
    realIndicator:   u8;
    ndx:             u8;
    map_flags:       u8;
    map_whichGroups: u8;
    map_groups:      u8;
    map_whichMods:   u8;
    map_mods:        u8;
    map_realMods:    u8;
    map_vmod:        u16;
    map_ctrls:       u32;
    supported:       u8;
    pad0:            [3] u8;
}

xcb_xkb_set_named_indicator_request_t :: struct {
    major_opcode:    u8;
    minor_opcode:    u8;
    length:          u16;
    deviceSpec:      xcb_xkb_device_spec_t;
    ledClass:        xcb_xkb_led_class_spec_t;
    ledID:           xcb_xkb_id_spec_t;
    pad0:            [2] u8;
    indicator:       xcb_atom_t;
    setState:        u8;
    on:              u8;
    setMap:          u8;
    createMap:       u8;
    pad1:            u8;
    map_flags:       u8;
    map_whichGroups: u8;
    map_groups:      u8;
    map_whichMods:   u8;
    map_realMods:    u8;
    map_vmods:       u16;
    map_ctrls:       u32;
}

xcb_xkb_get_names_cookie_t :: struct {
    sequence: u32;
}

xcb_xkb_get_names_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceSpec:   xcb_xkb_device_spec_t;
    pad0:         [2] u8;
    which:        u32;
}

xcb_xkb_get_names_value_list_t :: struct {
    keycodesName:    xcb_atom_t;
    geometryName:    xcb_atom_t;
    symbolsName:     xcb_atom_t;
    physSymbolsName: xcb_atom_t;
    typesName:       xcb_atom_t;
    compatName:      xcb_atom_t;
    typeNames:       *xcb_atom_t;
    nLevelsPerType:  *u8;
    pad1:            *u8;
    ktLevelNames:    *xcb_atom_t;
    indicatorNames:  *xcb_atom_t;
    virtualModNames: *xcb_atom_t;
    groups:          *xcb_atom_t;
    keyNames:        *xcb_xkb_key_name_t;
    keyAliases:      *xcb_xkb_key_alias_t;
    radioGroupNames: *xcb_atom_t;
}

xcb_xkb_get_names_reply_t :: struct {
    response_type: u8;
    deviceID:      u8;
    sequence:      u16;
    length:        u32;
    which:         u32;
    minKeyCode:    xcb_keycode_t;
    maxKeyCode:    xcb_keycode_t;
    nTypes:        u8;
    groupNames:    u8;
    virtualMods:   u16;
    firstKey:      xcb_keycode_t;
    nKeys:         u8;
    indicators:    u32;
    nRadioGroups:  u8;
    nKeyAliases:   u8;
    nKTLevels:     u16;
    pad0:          [4] u8;
}

xcb_xkb_set_names_values_t :: struct {
    keycodesName:    xcb_atom_t;
    geometryName:    xcb_atom_t;
    symbolsName:     xcb_atom_t;
    physSymbolsName: xcb_atom_t;
    typesName:       xcb_atom_t;
    compatName:      xcb_atom_t;
    typeNames:       *xcb_atom_t;
    nLevelsPerType:  *u8;
    ktLevelNames:    *xcb_atom_t;
    indicatorNames:  *xcb_atom_t;
    virtualModNames: *xcb_atom_t;
    groups:          *xcb_atom_t;
    keyNames:        *xcb_xkb_key_name_t;
    keyAliases:      *xcb_xkb_key_alias_t;
    radioGroupNames: *xcb_atom_t;
}

xcb_xkb_set_names_request_t :: struct {
    major_opcode:      u8;
    minor_opcode:      u8;
    length:            u16;
    deviceSpec:        xcb_xkb_device_spec_t;
    virtualMods:       u16;
    which:             u32;
    firstType:         u8;
    nTypes:            u8;
    firstKTLevelt:     u8;
    nKTLevels:         u8;
    indicators:        u32;
    groupNames:        u8;
    nRadioGroups:      u8;
    firstKey:          xcb_keycode_t;
    nKeys:             u8;
    nKeyAliases:       u8;
    pad0:              u8;
    totalKTLevelNames: u16;
}

xcb_xkb_per_client_flags_cookie_t :: struct {
    sequence: u32;
}

xcb_xkb_per_client_flags_request_t :: struct {
    major_opcode:    u8;
    minor_opcode:    u8;
    length:          u16;
    deviceSpec:      xcb_xkb_device_spec_t;
    pad0:            [2] u8;
    change:          u32;
    value:           u32;
    ctrlsToChange:   u32;
    autoCtrls:       u32;
    autoCtrlsValues: u32;
}

xcb_xkb_per_client_flags_reply_t :: struct {
    response_type:   u8;
    deviceID:        u8;
    sequence:        u16;
    length:          u32;
    supported:       u32;
    value:           u32;
    autoCtrls:       u32;
    autoCtrlsValues: u32;
    pad0:            [8] u8;
}

xcb_xkb_list_components_cookie_t :: struct {
    sequence: u32;
}

xcb_xkb_list_components_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceSpec:   xcb_xkb_device_spec_t;
    maxNames:     u16;
}

xcb_xkb_list_components_reply_t :: struct {
    response_type: u8;
    deviceID:      u8;
    sequence:      u16;
    length:        u32;
    nKeymaps:      u16;
    nKeycodes:     u16;
    nTypes:        u16;
    nCompatMaps:   u16;
    nSymbols:      u16;
    nGeometries:   u16;
    extra:         u16;
    pad0:          [10] u8;
}

xcb_xkb_get_kbd_by_name_cookie_t :: struct {
    sequence: u32;
}

xcb_xkb_get_kbd_by_name_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceSpec:   xcb_xkb_device_spec_t;
    need:         u16;
    want:         u16;
    load:         u8;
    pad0:         u8;
}

xcb_xkb_get_kbd_by_name_replies_types_map_t :: struct {
    types_rtrn:      *xcb_xkb_key_type_t;
    syms_rtrn:       *xcb_xkb_key_sym_map_t;
    acts_rtrn_count: *u8;
    acts_rtrn_acts:  *xcb_xkb_action_t;
    behaviors_rtrn:  *xcb_xkb_set_behavior_t;
    vmods_rtrn:      *u8;
    explicit_rtrn:   *xcb_xkb_set_explicit_t;
    modmap_rtrn:     *xcb_xkb_key_mod_map_t;
    vmodmap_rtrn:    *xcb_xkb_key_v_mod_map_t;
}

xcb_xkb_get_kbd_by_name_replies_key_names_value_list_t :: struct {
    keycodesName:    xcb_atom_t;
    geometryName:    xcb_atom_t;
    symbolsName:     xcb_atom_t;
    physSymbolsName: xcb_atom_t;
    typesName:       xcb_atom_t;
    compatName:      xcb_atom_t;
    typeNames:       *xcb_atom_t;
    nLevelsPerType:  *u8;
    ktLevelNames:    *xcb_atom_t;
    indicatorNames:  *xcb_atom_t;
    virtualModNames: *xcb_atom_t;
    groups:          *xcb_atom_t;
    keyNames:        *xcb_xkb_key_name_t;
    keyAliases:      *xcb_xkb_key_alias_t;
    radioGroupNames: *xcb_atom_t;
}

xcb_xkb_get_kbd_by_name_replies_t :: struct {
    types:          struct {
        getmap_type:       u8;
        typeDeviceID:      u8;
        getmap_sequence:   u16;
        getmap_length:     u32;
        pad1:              [2] u8;
        typeMinKeyCode:    xcb_keycode_t;
        typeMaxKeyCode:    xcb_keycode_t;
        present:           u16;
        firstType:         u8;
        nTypes:            u8;
        totalTypes:        u8;
        firstKeySym:       xcb_keycode_t;
        totalSyms:         u16;
        nKeySyms:          u8;
        firstKeyAction:    xcb_keycode_t;
        totalActions:      u16;
        nKeyActions:       u8;
        firstKeyBehavior:  xcb_keycode_t;
        nKeyBehaviors:     u8;
        totalKeyBehaviors: u8;
        firstKeyExplicit:  xcb_keycode_t;
        nKeyExplicit:      u8;
        totalKeyExplicit:  u8;
        firstModMapKey:    xcb_keycode_t;
        nModMapKeys:       u8;
        totalModMapKeys:   u8;
        firstVModMapKey:   xcb_keycode_t;
        nVModMapKeys:      u8;
        totalVModMapKeys:  u8;
        pad2:              u8;
        virtualMods:       u16;
        map:               xcb_xkb_get_kbd_by_name_replies_types_map_t;
    };

    compat_map:     struct {
        compatmap_type:     u8;
        compatDeviceID:     u8;
        compatmap_sequence: u16;
        compatmap_length:   u32;
        groupsRtrn:         u8;
        pad7:               u8;
        firstSIRtrn:        u16;
        nSIRtrn:            u16;
        nTotalSI:           u16;
        pad8:               [16] u8;
        si_rtrn:            *xcb_xkb_sym_interpret_t;
        group_rtrn:         *xcb_xkb_mod_def_t;
    };

    indicator_maps: struct {
        indicatormap_type:     u8;
        indicatorDeviceID:     u8;
        indicatormap_sequence: u16;
        indicatormap_length:   u32;
        which:                 u32;
        realIndicators:        u32;
        nIndicators:           u8;
        pad9:                  [15] u8;
        maps:                  *xcb_xkb_indicator_map_t;
    };

    key_names:      struct {
        keyname_type:     u8;
        keyDeviceID:      u8;
        keyname_sequence: u16;
        keyname_length:   u32;
        which:            u32;
        keyMinKeyCode:    xcb_keycode_t;
        keyMaxKeyCode:    xcb_keycode_t;
        nTypes:           u8;
        groupNames:       u8;
        virtualMods:      u16;
        firstKey:         xcb_keycode_t;
        nKeys:            u8;
        indicators:       u32;
        nRadioGroups:     u8;
        nKeyAliases:      u8;
        nKTLevels:        u16;
        pad10:            [4] u8;
        valueList:        xcb_xkb_get_kbd_by_name_replies_key_names_value_list_t;
    };

    geometry:       struct {
        geometry_type:     u8;
        geometryDeviceID:  u8;
        geometry_sequence: u16;
        geometry_length:   u32;
        name:              xcb_atom_t;
        geometryFound:     u8;
        pad12:             u8;
        widthMM:           u16;
        heightMM:          u16;
        nProperties:       u16;
        nColors:           u16;
        nShapes:           u16;
        nSections:         u16;
        nDoodads:          u16;
        nKeyAliases:       u16;
        baseColorNdx:      u8;
        labelColorNdx:     u8;
        labelFont:         *xcb_xkb_counted_string_16_t;
    };
}

xcb_xkb_get_kbd_by_name_reply_t :: struct {
    response_type: u8;
    deviceID:      u8;
    sequence:      u16;
    length:        u32;
    minKeyCode:    xcb_keycode_t;
    maxKeyCode:    xcb_keycode_t;
    loaded:        u8;
    newKeyboard:   u8;
    found:         u16;
    reported:      u16;
    pad0:          [16] u8;
}

xcb_xkb_get_device_info_cookie_t :: struct {
    sequence: u32;
}

xcb_xkb_get_device_info_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    deviceSpec:   xcb_xkb_device_spec_t;
    wanted:       u16;
    allButtons:   u8;
    firstButton:  u8;
    nButtons:     u8;
    pad0:         u8;
    ledClass:     xcb_xkb_led_class_spec_t;
    ledID:        xcb_xkb_id_spec_t;
}

xcb_xkb_get_device_info_reply_t :: struct {
    response_type:  u8;
    deviceID:       u8;
    sequence:       u16;
    length:         u32;
    present:        u16;
    supported:      u16;
    unsupported:    u16;
    nDeviceLedFBs:  u16;
    firstBtnWanted: u8;
    nBtnsWanted:    u8;
    firstBtnRtrn:   u8;
    nBtnsRtrn:      u8;
    totalBtns:      u8;
    hasOwnState:    u8;
    dfltKbdFB:      u16;
    dfltLedFB:      u16;
    pad0:           [2] u8;
    devType:        xcb_atom_t;
    nameLen:        u16;
}

xcb_xkb_set_device_info_request_t :: struct {
    major_opcode:  u8;
    minor_opcode:  u8;
    length:        u16;
    deviceSpec:    xcb_xkb_device_spec_t;
    firstBtn:      u8;
    nBtns:         u8;
    change:        u16;
    nDeviceLedFBs: u16;
}

xcb_xkb_set_debugging_flags_cookie_t :: struct {
    sequence: u32;
}

xcb_xkb_set_debugging_flags_request_t :: struct {
    major_opcode: u8;
    minor_opcode: u8;
    length:       u16;
    msgLength:    u16;
    pad0:         [2] u8;
    affectFlags:  u32;
    flags:        u32;
    affectCtrls:  u32;
    ctrls:        u32;
}

xcb_xkb_set_debugging_flags_reply_t :: struct {
    response_type:  u8;
    pad0:           u8;
    sequence:       u16;
    length:         u32;
    currentFlags:   u32;
    currentCtrls:   u32;
    supportedFlags: u32;
    supportedCtrls: u32;
    pad1:           [8] u8;
}

xcb_xkb_new_keyboard_notify_event_t :: struct {
    response_type: u8;
    xkbType:       u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    deviceID:      u8;
    oldDeviceID:   u8;
    minKeyCode:    xcb_keycode_t;
    maxKeyCode:    xcb_keycode_t;
    oldMinKeyCode: xcb_keycode_t;
    oldMaxKeyCode: xcb_keycode_t;
    requestMajor:  u8;
    requestMinor:  u8;
    changed:       u16;
    pad0:          [14] u8;
}

xcb_xkb_map_notify_event_t :: struct {
    response_type:    u8;
    xkbType:          u8;
    sequence:         u16;
    time:             xcb_timestamp_t;
    deviceID:         u8;
    ptrBtnActions:    u8;
    changed:          u16;
    minKeyCode:       xcb_keycode_t;
    maxKeyCode:       xcb_keycode_t;
    firstType:        u8;
    nTypes:           u8;
    firstKeySym:      xcb_keycode_t;
    nKeySyms:         u8;
    firstKeyAct:      xcb_keycode_t;
    nKeyActs:         u8;
    firstKeyBehavior: xcb_keycode_t;
    nKeyBehavior:     u8;
    firstKeyExplicit: xcb_keycode_t;
    nKeyExplicit:     u8;
    firstModMapKey:   xcb_keycode_t;
    nModMapKeys:      u8;
    firstVModMapKey:  xcb_keycode_t;
    nVModMapKeys:     u8;
    virtualMods:      u16;
    pad0:             [2] u8;
}

xcb_xkb_state_notify_event_t :: struct {
    response_type:     u8;
    xkbType:           u8;
    sequence:          u16;
    time:              xcb_timestamp_t;
    deviceID:          u8;
    mods:              u8;
    baseMods:          u8;
    latchedMods:       u8;
    lockedMods:        u8;
    group:             u8;
    baseGroup:         s16;
    latchedGroup:      s16;
    lockedGroup:       u8;
    compatState:       u8;
    grabMods:          u8;
    compatGrabMods:    u8;
    lookupMods:        u8;
    compatLoockupMods: u8;
    ptrBtnState:       u16;
    changed:           u16;
    keycode:           xcb_keycode_t;
    eventType:         u8;
    requestMajor:      u8;
    requestMinor:      u8;
}

xcb_xkb_controls_notify_event_t :: struct {
    response_type:         u8;
    xkbType:               u8;
    sequence:              u16;
    time:                  xcb_timestamp_t;
    deviceID:              u8;
    numGroups:             u8;
    pad0:                  [2] u8;
    changedControls:       u32;
    enabledControls:       u32;
    enabledControlChanges: u32;
    keycode:               xcb_keycode_t;
    eventType:             u8;
    requestMajor:          u8;
    requestMinor:          u8;
    pad1:                  [4] u8;
}

xcb_xkb_indicator_state_notify_event_t :: struct {
    response_type: u8;
    xkbType:       u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    deviceID:      u8;
    pad0:          [3] u8;
    state:         u32;
    stateChanged:  u32;
    pad1:          [12] u8;
}

xcb_xkb_indicator_map_notify_event_t :: struct {
    response_type: u8;
    xkbType:       u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    deviceID:      u8;
    pad0:          [3] u8;
    state:         u32;
    mapChanged:    u32;
    pad1:          [12] u8;
}

xcb_xkb_names_notify_event_t :: struct {
    response_type:      u8;
    xkbType:            u8;
    sequence:           u16;
    time:               xcb_timestamp_t;
    deviceID:           u8;
    pad0:               u8;
    changed:            u16;
    firstType:          u8;
    nTypes:             u8;
    firstLevelName:     u8;
    nLevelNames:        u8;
    pad1:               u8;
    nRadioGroups:       u8;
    nKeyAliases:        u8;
    changedGroupNames:  u8;
    changedVirtualMods: u16;
    firstKey:           xcb_keycode_t;
    nKeys:              u8;
    changedIndicators:  u32;
    pad2:               [4] u8;
}

xcb_xkb_compat_map_notify_event_t :: struct {
    response_type: u8;
    xkbType:       u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    deviceID:      u8;
    changedGroups: u8;
    firstSI:       u16;
    nSI:           u16;
    nTotalSI:      u16;
    pad0:          [16] u8;
}

xcb_xkb_bell_notify_event_t :: struct {
    response_type: u8;
    xkbType:       u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    deviceID:      u8;
    bellClass:     u8;
    bellID:        u8;
    percent:       u8;
    pitch:         u16;
    duration:      u16;
    name:          xcb_atom_t;
    window:        xcb_window_t;
    eventOnly:     u8;
    pad0:          [7] u8;
}

xcb_xkb_action_message_event_t :: struct {
    response_type:   u8;
    xkbType:         u8;
    sequence:        u16;
    time:            xcb_timestamp_t;
    deviceID:        u8;
    keycode:         xcb_keycode_t;
    press:           u8;
    keyEventFollows: u8;
    mods:            u8;
    group:           u8;
    message:         [8] xcb_xkb_string8_t;
    pad0:            [10] u8;
}

xcb_xkb_access_x_notify_event_t :: struct {
    response_type: u8;
    xkbType:       u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    deviceID:      u8;
    keycode:       xcb_keycode_t;
    detailt:       u16;
    slowKeysDelay: u16;
    debounceDelay: u16;
    pad0:          [16] u8;
}

xcb_xkb_extension_device_notify_event_t :: struct {
    response_type: u8;
    xkbType:       u8;
    sequence:      u16;
    time:          xcb_timestamp_t;
    deviceID:      u8;
    pad0:          u8;
    reason:        u16;
    ledClass:      u16;
    ledID:         u16;
    ledsDefined:   u32;
    ledState:      u32;
    firstButton:   u8;
    nButtons:      u8;
    supported:     u16;
    unsupported:   u16;
    pad1:          [2] u8;
}

XCB_XKB_Symbols :: struct #type_info_procedures_are_void_pointers #type_info_no_size_complaint {
    id:                                                                    *xcb_extension_t;
    get_kbd_by_name_replies_types_map:                                     #type (R: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_xkb_get_kbd_by_name_replies_types_map_t #c_call;
    device_spec_next:                                                      #type (i: *xcb_xkb_device_spec_iterator_t) -> void #c_call;
    device_spec_end:                                                       #type (i: xcb_xkb_device_spec_iterator_t) -> xcb_generic_iterator_t #c_call;
    led_class_spec_next:                                                   #type (i: *xcb_xkb_led_class_spec_iterator_t) -> void #c_call;
    led_class_spec_end:                                                    #type (i: xcb_xkb_led_class_spec_iterator_t) -> xcb_generic_iterator_t #c_call;
    bell_class_spec_next:                                                  #type (i: *xcb_xkb_bell_class_spec_iterator_t) -> void #c_call;
    bell_class_spec_end:                                                   #type (i: xcb_xkb_bell_class_spec_iterator_t) -> xcb_generic_iterator_t #c_call;
    id_spec_next:                                                          #type (i: *xcb_xkb_id_spec_iterator_t) -> void #c_call;
    id_spec_end:                                                           #type (i: xcb_xkb_id_spec_iterator_t) -> xcb_generic_iterator_t #c_call;
    indicator_map_next:                                                    #type (i: *xcb_xkb_indicator_map_iterator_t) -> void #c_call;
    indicator_map_end:                                                     #type (i: xcb_xkb_indicator_map_iterator_t) -> xcb_generic_iterator_t #c_call;
    mod_def_next:                                                          #type (i: *xcb_xkb_mod_def_iterator_t) -> void #c_call;
    mod_def_end:                                                           #type (i: xcb_xkb_mod_def_iterator_t) -> xcb_generic_iterator_t #c_call;
    key_name_next:                                                         #type (i: *xcb_xkb_key_name_iterator_t) -> void #c_call;
    key_name_end:                                                          #type (i: xcb_xkb_key_name_iterator_t) -> xcb_generic_iterator_t #c_call;
    key_alias_next:                                                        #type (i: *xcb_xkb_key_alias_iterator_t) -> void #c_call;
    key_alias_end:                                                         #type (i: xcb_xkb_key_alias_iterator_t) -> xcb_generic_iterator_t #c_call;
    counted_string_16_sizeof:                                              #type (_buffer: *void) -> s32 #c_call;
    counted_string_16_string:                                              #type (R: *xcb_xkb_counted_string_16_t) -> *u8 #c_call;
    counted_string_16_string_length:                                       #type (R: *xcb_xkb_counted_string_16_t) -> s32 #c_call;
    counted_string_16_string_end:                                          #type (R: *xcb_xkb_counted_string_16_t) -> xcb_generic_iterator_t #c_call;
    counted_string_16_alignment_pad:                                       #type (R: *xcb_xkb_counted_string_16_t) -> *void #c_call;
    counted_string_16_alignment_pad_length:                                #type (R: *xcb_xkb_counted_string_16_t) -> s32 #c_call;
    counted_string_16_alignment_pad_end:                                   #type (R: *xcb_xkb_counted_string_16_t) -> xcb_generic_iterator_t #c_call;
    counted_string_16_next:                                                #type (i: *xcb_xkb_counted_string_16_iterator_t) -> void #c_call;
    counted_string_16_end:                                                 #type (i: xcb_xkb_counted_string_16_iterator_t) -> xcb_generic_iterator_t #c_call;
    kt_map_entry_next:                                                     #type (i: *xcb_xkb_kt_map_entry_iterator_t) -> void #c_call;
    kt_map_entry_end:                                                      #type (i: xcb_xkb_kt_map_entry_iterator_t) -> xcb_generic_iterator_t #c_call;
    key_type_sizeof:                                                       #type (_buffer: *void) -> s32 #c_call;
    key_type_map:                                                          #type (R: *xcb_xkb_key_type_t) -> *xcb_xkb_kt_map_entry_t #c_call;
    key_type_map_length:                                                   #type (R: *xcb_xkb_key_type_t) -> s32 #c_call;
    key_type_map_iterator:                                                 #type (R: *xcb_xkb_key_type_t) -> xcb_xkb_kt_map_entry_iterator_t #c_call;
    key_type_preserve:                                                     #type (R: *xcb_xkb_key_type_t) -> *xcb_xkb_mod_def_t #c_call;
    key_type_preserve_length:                                              #type (R: *xcb_xkb_key_type_t) -> s32 #c_call;
    key_type_preserve_iterator:                                            #type (R: *xcb_xkb_key_type_t) -> xcb_xkb_mod_def_iterator_t #c_call;
    key_type_next:                                                         #type (i: *xcb_xkb_key_type_iterator_t) -> void #c_call;
    key_type_end:                                                          #type (i: xcb_xkb_key_type_iterator_t) -> xcb_generic_iterator_t #c_call;
    key_sym_map_sizeof:                                                    #type (_buffer: *void) -> s32 #c_call;
    key_sym_map_syms:                                                      #type (R: *xcb_xkb_key_sym_map_t) -> *xcb_keysym_t #c_call;
    key_sym_map_syms_length:                                               #type (R: *xcb_xkb_key_sym_map_t) -> s32 #c_call;
    key_sym_map_syms_end:                                                  #type (R: *xcb_xkb_key_sym_map_t) -> xcb_generic_iterator_t #c_call;
    key_sym_map_next:                                                      #type (i: *xcb_xkb_key_sym_map_iterator_t) -> void #c_call;
    key_sym_map_end:                                                       #type (i: xcb_xkb_key_sym_map_iterator_t) -> xcb_generic_iterator_t #c_call;
    common_behavior_next:                                                  #type (i: *xcb_xkb_common_behavior_iterator_t) -> void #c_call;
    common_behavior_end:                                                   #type (i: xcb_xkb_common_behavior_iterator_t) -> xcb_generic_iterator_t #c_call;
    default_behavior_next:                                                 #type (i: *xcb_xkb_default_behavior_iterator_t) -> void #c_call;
    default_behavior_end:                                                  #type (i: xcb_xkb_default_behavior_iterator_t) -> xcb_generic_iterator_t #c_call;
    lock_behavior_next:                                                    #type (i: *xcb_xkb_lock_behavior_iterator_t) -> void #c_call;
    lock_behavior_end:                                                     #type (i: xcb_xkb_lock_behavior_iterator_t) -> xcb_generic_iterator_t #c_call;
    radio_group_behavior_next:                                             #type (i: *xcb_xkb_radio_group_behavior_iterator_t) -> void #c_call;
    radio_group_behavior_end:                                              #type (i: xcb_xkb_radio_group_behavior_iterator_t) -> xcb_generic_iterator_t #c_call;
    overlay_behavior_next:                                                 #type (i: *xcb_xkb_overlay_behavior_iterator_t) -> void #c_call;
    overlay_behavior_end:                                                  #type (i: xcb_xkb_overlay_behavior_iterator_t) -> xcb_generic_iterator_t #c_call;
    permament_lock_behavior_next:                                          #type (i: *xcb_xkb_permament_lock_behavior_iterator_t) -> void #c_call;
    permament_lock_behavior_end:                                           #type (i: xcb_xkb_permament_lock_behavior_iterator_t) -> xcb_generic_iterator_t #c_call;
    permament_radio_group_behavior_next:                                   #type (i: *xcb_xkb_permament_radio_group_behavior_iterator_t) -> void #c_call;
    permament_radio_group_behavior_end:                                    #type (i: xcb_xkb_permament_radio_group_behavior_iterator_t) -> xcb_generic_iterator_t #c_call;
    permament_overlay_behavior_next:                                       #type (i: *xcb_xkb_permament_overlay_behavior_iterator_t) -> void #c_call;
    permament_overlay_behavior_end:                                        #type (i: xcb_xkb_permament_overlay_behavior_iterator_t) -> xcb_generic_iterator_t #c_call;
    behavior_next:                                                         #type (i: *xcb_xkb_behavior_iterator_t) -> void #c_call;
    behavior_end:                                                          #type (i: xcb_xkb_behavior_iterator_t) -> xcb_generic_iterator_t #c_call;
    set_behavior_next:                                                     #type (i: *xcb_xkb_set_behavior_iterator_t) -> void #c_call;
    set_behavior_end:                                                      #type (i: xcb_xkb_set_behavior_iterator_t) -> xcb_generic_iterator_t #c_call;
    set_explicit_next:                                                     #type (i: *xcb_xkb_set_explicit_iterator_t) -> void #c_call;
    set_explicit_end:                                                      #type (i: xcb_xkb_set_explicit_iterator_t) -> xcb_generic_iterator_t #c_call;
    key_mod_map_next:                                                      #type (i: *xcb_xkb_key_mod_map_iterator_t) -> void #c_call;
    key_mod_map_end:                                                       #type (i: xcb_xkb_key_mod_map_iterator_t) -> xcb_generic_iterator_t #c_call;
    key_v_mod_map_next:                                                    #type (i: *xcb_xkb_key_v_mod_map_iterator_t) -> void #c_call;
    key_v_mod_map_end:                                                     #type (i: xcb_xkb_key_v_mod_map_iterator_t) -> xcb_generic_iterator_t #c_call;
    kt_set_map_entry_next:                                                 #type (i: *xcb_xkb_kt_set_map_entry_iterator_t) -> void #c_call;
    kt_set_map_entry_end:                                                  #type (i: xcb_xkb_kt_set_map_entry_iterator_t) -> xcb_generic_iterator_t #c_call;
    set_key_type_sizeof:                                                   #type (_buffer: *void) -> s32 #c_call;
    set_key_type_entries:                                                  #type (R: *xcb_xkb_set_key_type_t) -> *xcb_xkb_kt_set_map_entry_t #c_call;
    set_key_type_entries_length:                                           #type (R: *xcb_xkb_set_key_type_t) -> s32 #c_call;
    set_key_type_entries_iterator:                                         #type (R: *xcb_xkb_set_key_type_t) -> xcb_xkb_kt_set_map_entry_iterator_t #c_call;
    set_key_type_preserve_entries:                                         #type (R: *xcb_xkb_set_key_type_t) -> *xcb_xkb_kt_set_map_entry_t #c_call;
    set_key_type_preserve_entries_length:                                  #type (R: *xcb_xkb_set_key_type_t) -> s32 #c_call;
    set_key_type_preserve_entries_iterator:                                #type (R: *xcb_xkb_set_key_type_t) -> xcb_xkb_kt_set_map_entry_iterator_t #c_call;
    set_key_type_next:                                                     #type (i: *xcb_xkb_set_key_type_iterator_t) -> void #c_call;
    set_key_type_end:                                                      #type (i: xcb_xkb_set_key_type_iterator_t) -> xcb_generic_iterator_t #c_call;
    string8_next:                                                          #type (i: *xcb_xkb_string8_iterator_t) -> void #c_call;
    string8_end:                                                           #type (i: xcb_xkb_string8_iterator_t) -> xcb_generic_iterator_t #c_call;
    outline_sizeof:                                                        #type (_buffer: *void) -> s32 #c_call;
    outline_points:                                                        #type (R: *xcb_xkb_outline_t) -> *xcb_point_t #c_call;
    outline_points_length:                                                 #type (R: *xcb_xkb_outline_t) -> s32 #c_call;
    outline_points_iterator:                                               #type (R: *xcb_xkb_outline_t) -> xcb_point_iterator_t #c_call;
    outline_next:                                                          #type (i: *xcb_xkb_outline_iterator_t) -> void #c_call;
    outline_end:                                                           #type (i: xcb_xkb_outline_iterator_t) -> xcb_generic_iterator_t #c_call;
    shape_sizeof:                                                          #type (_buffer: *void) -> s32 #c_call;
    shape_outlines_length:                                                 #type (R: *xcb_xkb_shape_t) -> s32 #c_call;
    shape_outlines_iterator:                                               #type (R: *xcb_xkb_shape_t) -> xcb_xkb_outline_iterator_t #c_call;
    shape_next:                                                            #type (i: *xcb_xkb_shape_iterator_t) -> void #c_call;
    shape_end:                                                             #type (i: xcb_xkb_shape_iterator_t) -> xcb_generic_iterator_t #c_call;
    key_next:                                                              #type (i: *xcb_xkb_key_iterator_t) -> void #c_call;
    key_end:                                                               #type (i: xcb_xkb_key_iterator_t) -> xcb_generic_iterator_t #c_call;
    overlay_key_next:                                                      #type (i: *xcb_xkb_overlay_key_iterator_t) -> void #c_call;
    overlay_key_end:                                                       #type (i: xcb_xkb_overlay_key_iterator_t) -> xcb_generic_iterator_t #c_call;
    overlay_row_sizeof:                                                    #type (_buffer: *void) -> s32 #c_call;
    overlay_row_keys:                                                      #type (R: *xcb_xkb_overlay_row_t) -> *xcb_xkb_overlay_key_t #c_call;
    overlay_row_keys_length:                                               #type (R: *xcb_xkb_overlay_row_t) -> s32 #c_call;
    overlay_row_keys_iterator:                                             #type (R: *xcb_xkb_overlay_row_t) -> xcb_xkb_overlay_key_iterator_t #c_call;
    overlay_row_next:                                                      #type (i: *xcb_xkb_overlay_row_iterator_t) -> void #c_call;
    overlay_row_end:                                                       #type (i: xcb_xkb_overlay_row_iterator_t) -> xcb_generic_iterator_t #c_call;
    overlay_sizeof:                                                        #type (_buffer: *void) -> s32 #c_call;
    overlay_rows_length:                                                   #type (R: *xcb_xkb_overlay_t) -> s32 #c_call;
    overlay_rows_iterator:                                                 #type (R: *xcb_xkb_overlay_t) -> xcb_xkb_overlay_row_iterator_t #c_call;
    overlay_next:                                                          #type (i: *xcb_xkb_overlay_iterator_t) -> void #c_call;
    overlay_end:                                                           #type (i: xcb_xkb_overlay_iterator_t) -> xcb_generic_iterator_t #c_call;
    row_sizeof:                                                            #type (_buffer: *void) -> s32 #c_call;
    row_keys:                                                              #type (R: *xcb_xkb_row_t) -> *xcb_xkb_key_t #c_call;
    row_keys_length:                                                       #type (R: *xcb_xkb_row_t) -> s32 #c_call;
    row_keys_iterator:                                                     #type (R: *xcb_xkb_row_t) -> xcb_xkb_key_iterator_t #c_call;
    row_next:                                                              #type (i: *xcb_xkb_row_iterator_t) -> void #c_call;
    row_end:                                                               #type (i: xcb_xkb_row_iterator_t) -> xcb_generic_iterator_t #c_call;
    listing_sizeof:                                                        #type (_buffer: *void) -> s32 #c_call;
    listing_string:                                                        #type (R: *xcb_xkb_listing_t) -> *xcb_xkb_string8_t #c_call;
    listing_string_length:                                                 #type (R: *xcb_xkb_listing_t) -> s32 #c_call;
    listing_string_end:                                                    #type (R: *xcb_xkb_listing_t) -> xcb_generic_iterator_t #c_call;
    listing_next:                                                          #type (i: *xcb_xkb_listing_iterator_t) -> void #c_call;
    listing_end:                                                           #type (i: xcb_xkb_listing_iterator_t) -> xcb_generic_iterator_t #c_call;
    device_led_info_sizeof:                                                #type (_buffer: *void) -> s32 #c_call;
    device_led_info_names:                                                 #type (R: *xcb_xkb_device_led_info_t) -> *xcb_atom_t #c_call;
    device_led_info_names_length:                                          #type (R: *xcb_xkb_device_led_info_t) -> s32 #c_call;
    device_led_info_names_end:                                             #type (R: *xcb_xkb_device_led_info_t) -> xcb_generic_iterator_t #c_call;
    device_led_info_maps:                                                  #type (R: *xcb_xkb_device_led_info_t) -> *xcb_xkb_indicator_map_t #c_call;
    device_led_info_maps_length:                                           #type (R: *xcb_xkb_device_led_info_t) -> s32 #c_call;
    device_led_info_maps_iterator:                                         #type (R: *xcb_xkb_device_led_info_t) -> xcb_xkb_indicator_map_iterator_t #c_call;
    device_led_info_next:                                                  #type (i: *xcb_xkb_device_led_info_iterator_t) -> void #c_call;
    device_led_info_end:                                                   #type (i: xcb_xkb_device_led_info_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_no_action_next:                                                     #type (i: *xcb_xkb_sa_no_action_iterator_t) -> void #c_call;
    sa_no_action_end:                                                      #type (i: xcb_xkb_sa_no_action_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_set_mods_next:                                                      #type (i: *xcb_xkb_sa_set_mods_iterator_t) -> void #c_call;
    sa_set_mods_end:                                                       #type (i: xcb_xkb_sa_set_mods_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_latch_mods_next:                                                    #type (i: *xcb_xkb_sa_latch_mods_iterator_t) -> void #c_call;
    sa_latch_mods_end:                                                     #type (i: xcb_xkb_sa_latch_mods_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_lock_mods_next:                                                     #type (i: *xcb_xkb_sa_lock_mods_iterator_t) -> void #c_call;
    sa_lock_mods_end:                                                      #type (i: xcb_xkb_sa_lock_mods_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_set_group_next:                                                     #type (i: *xcb_xkb_sa_set_group_iterator_t) -> void #c_call;
    sa_set_group_end:                                                      #type (i: xcb_xkb_sa_set_group_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_latch_group_next:                                                   #type (i: *xcb_xkb_sa_latch_group_iterator_t) -> void #c_call;
    sa_latch_group_end:                                                    #type (i: xcb_xkb_sa_latch_group_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_lock_group_next:                                                    #type (i: *xcb_xkb_sa_lock_group_iterator_t) -> void #c_call;
    sa_lock_group_end:                                                     #type (i: xcb_xkb_sa_lock_group_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_move_ptr_next:                                                      #type (i: *xcb_xkb_sa_move_ptr_iterator_t) -> void #c_call;
    sa_move_ptr_end:                                                       #type (i: xcb_xkb_sa_move_ptr_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_ptr_btn_next:                                                       #type (i: *xcb_xkb_sa_ptr_btn_iterator_t) -> void #c_call;
    sa_ptr_btn_end:                                                        #type (i: xcb_xkb_sa_ptr_btn_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_lock_ptr_btn_next:                                                  #type (i: *xcb_xkb_sa_lock_ptr_btn_iterator_t) -> void #c_call;
    sa_lock_ptr_btn_end:                                                   #type (i: xcb_xkb_sa_lock_ptr_btn_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_set_ptr_dflt_next:                                                  #type (i: *xcb_xkb_sa_set_ptr_dflt_iterator_t) -> void #c_call;
    sa_set_ptr_dflt_end:                                                   #type (i: xcb_xkb_sa_set_ptr_dflt_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_iso_lock_next:                                                      #type (i: *xcb_xkb_sa_iso_lock_iterator_t) -> void #c_call;
    sa_iso_lock_end:                                                       #type (i: xcb_xkb_sa_iso_lock_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_terminate_next:                                                     #type (i: *xcb_xkb_sa_terminate_iterator_t) -> void #c_call;
    sa_terminate_end:                                                      #type (i: xcb_xkb_sa_terminate_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_switch_screen_next:                                                 #type (i: *xcb_xkb_sa_switch_screen_iterator_t) -> void #c_call;
    sa_switch_screen_end:                                                  #type (i: xcb_xkb_sa_switch_screen_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_set_controls_next:                                                  #type (i: *xcb_xkb_sa_set_controls_iterator_t) -> void #c_call;
    sa_set_controls_end:                                                   #type (i: xcb_xkb_sa_set_controls_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_lock_controls_next:                                                 #type (i: *xcb_xkb_sa_lock_controls_iterator_t) -> void #c_call;
    sa_lock_controls_end:                                                  #type (i: xcb_xkb_sa_lock_controls_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_action_message_next:                                                #type (i: *xcb_xkb_sa_action_message_iterator_t) -> void #c_call;
    sa_action_message_end:                                                 #type (i: xcb_xkb_sa_action_message_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_redirect_key_next:                                                  #type (i: *xcb_xkb_sa_redirect_key_iterator_t) -> void #c_call;
    sa_redirect_key_end:                                                   #type (i: xcb_xkb_sa_redirect_key_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_device_btn_next:                                                    #type (i: *xcb_xkb_sa_device_btn_iterator_t) -> void #c_call;
    sa_device_btn_end:                                                     #type (i: xcb_xkb_sa_device_btn_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_lock_device_btn_next:                                               #type (i: *xcb_xkb_sa_lock_device_btn_iterator_t) -> void #c_call;
    sa_lock_device_btn_end:                                                #type (i: xcb_xkb_sa_lock_device_btn_iterator_t) -> xcb_generic_iterator_t #c_call;
    sa_device_valuator_next:                                               #type (i: *xcb_xkb_sa_device_valuator_iterator_t) -> void #c_call;
    sa_device_valuator_end:                                                #type (i: xcb_xkb_sa_device_valuator_iterator_t) -> xcb_generic_iterator_t #c_call;
    si_action_next:                                                        #type (i: *xcb_xkb_si_action_iterator_t) -> void #c_call;
    si_action_end:                                                         #type (i: xcb_xkb_si_action_iterator_t) -> xcb_generic_iterator_t #c_call;
    sym_interpret_next:                                                    #type (i: *xcb_xkb_sym_interpret_iterator_t) -> void #c_call;
    sym_interpret_end:                                                     #type (i: xcb_xkb_sym_interpret_iterator_t) -> xcb_generic_iterator_t #c_call;
    action_next:                                                           #type (i: *xcb_xkb_action_iterator_t) -> void #c_call;
    action_end:                                                            #type (i: xcb_xkb_action_iterator_t) -> xcb_generic_iterator_t #c_call;
    use_extension:                                                         #type (c: *xcb_connection_t, wantedMajor: u16, wantedMinor: u16) -> xcb_xkb_use_extension_cookie_t #c_call;
    use_extension_unchecked:                                               #type (c: *xcb_connection_t, wantedMajor: u16, wantedMinor: u16) -> xcb_xkb_use_extension_cookie_t #c_call;
    use_extension_reply:                                                   #type (c: *xcb_connection_t, cookie: xcb_xkb_use_extension_cookie_t, e: **xcb_generic_error_t) -> *xcb_xkb_use_extension_reply_t #c_call;
    select_events_details_serialize:                                       #type (_buffer: **void, affectWhich: u16, clear: u16, selectAll: u16, _aux: *xcb_xkb_select_events_details_t) -> s32 #c_call;
    select_events_details_unpack:                                          #type (_buffer: *void, affectWhich: u16, clear: u16, selectAll: u16, _aux: *xcb_xkb_select_events_details_t) -> s32 #c_call;
    select_events_details_sizeof:                                          #type (_buffer: *void, affectWhich: u16, clear: u16, selectAll: u16) -> s32 #c_call;
    select_events_sizeof:                                                  #type (_buffer: *void) -> s32 #c_call;
    select_events_checked:                                                 #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, affectWhich: xcb_xkb_event_type_t, clear: xcb_xkb_event_type_t, selectAll: xcb_xkb_event_type_t, affectMap: xcb_xkb_map_part_t, map: xcb_xkb_map_part_t, details: *void) -> xcb_void_cookie_t #c_call;
    select_events:                                                         #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, affectWhich: xcb_xkb_event_type_t, clear: xcb_xkb_event_type_t, selectAll: xcb_xkb_event_type_t, affectMap: xcb_xkb_map_part_t, map: xcb_xkb_map_part_t, details: *void) -> xcb_void_cookie_t #c_call;
    select_events_aux_checked:                                             #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, affectWhich: xcb_xkb_event_type_t, clear: xcb_xkb_event_type_t, selectAll: xcb_xkb_event_type_t, affectMap: xcb_xkb_map_part_t, map: xcb_xkb_map_part_t, details: *xcb_xkb_select_events_details_t) -> xcb_void_cookie_t #c_call;
    select_events_aux:                                                     #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, affectWhich: xcb_xkb_event_type_t, clear: xcb_xkb_event_type_t, selectAll: xcb_xkb_event_type_t, affectMap: xcb_xkb_map_part_t, map: xcb_xkb_map_part_t, details: *xcb_xkb_select_events_details_t) -> xcb_void_cookie_t #c_call;
    select_events_details:                                                 #type (R: *xcb_xkb_select_events_request_t) -> *void #c_call;
    bell_checked:                                                          #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, bellClass: xcb_xkb_bell_class_spec_t, bellID: xcb_xkb_id_spec_t, percent: s8, forceSound: u8, eventOnly: u8, pitch: s16, duration: s16, name: xcb_atom_t, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    bell:                                                                  #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, bellClass: xcb_xkb_bell_class_spec_t, bellID: xcb_xkb_id_spec_t, percent: s8, forceSound: u8, eventOnly: u8, pitch: s16, duration: s16, name: xcb_atom_t, window: xcb_window_t) -> xcb_void_cookie_t #c_call;
    get_state:                                                             #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t) -> xcb_xkb_get_state_cookie_t #c_call;
    get_state_unchecked:                                                   #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t) -> xcb_xkb_get_state_cookie_t #c_call;
    get_state_reply:                                                       #type (c: *xcb_connection_t, cookie: xcb_xkb_get_state_cookie_t, e: **xcb_generic_error_t) -> *xcb_xkb_get_state_reply_t #c_call;
    latch_lock_state_checked:                                              #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, affectModLocks: u8, modLocks: u8, lockGroup: u8, groupLock: u8, affectModLatches: u8, latchGroup: u8, groupLatch: u16) -> xcb_void_cookie_t #c_call;
    latch_lock_state:                                                      #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, affectModLocks: u8, modLocks: u8, lockGroup: u8, groupLock: u8, affectModLatches: u8, latchGroup: u8, groupLatch: u16) -> xcb_void_cookie_t #c_call;
    get_controls:                                                          #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t) -> xcb_xkb_get_controls_cookie_t #c_call;
    get_controls_unchecked:                                                #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t) -> xcb_xkb_get_controls_cookie_t #c_call;
    get_controls_reply:                                                    #type (c: *xcb_connection_t, cookie: xcb_xkb_get_controls_cookie_t, e: **xcb_generic_error_t) -> *xcb_xkb_get_controls_reply_t #c_call;
    set_controls_checked:                                                  #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, affectInternalRealMods: u8, internalRealMods: u8, affectIgnoreLockRealMods: u8, ignoreLockRealMods: u8, affectInternalVirtualMods: u16, internalVirtualMods: u16, affectIgnoreLockVirtualMods: u16, ignoreLockVirtualMods: u16, mouseKeysDfltBtn: u8, groupsWrap: u8, accessXOptions: u16, affectEnabledControls: u32, enabledControls: u32, changeControls: u32, repeatDelay: u16, repeatInterval: u16, slowKeysDelay: u16, debounceDelay: u16, mouseKeysDelay: u16, mouseKeysInterval: u16, mouseKeysTimeToMax: u16, mouseKeysMaxSpeed: u16, mouseKeysCurve: s16, accessXTimeout: u16, accessXTimeoutMask: u32, accessXTimeoutValues: u32, accessXTimeoutOptionsMask: u16, accessXTimeoutOptionsValues: u16, perKeyRepeat: *u8) -> xcb_void_cookie_t #c_call;
    set_controls:                                                          #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, affectInternalRealMods: u8, internalRealMods: u8, affectIgnoreLockRealMods: u8, ignoreLockRealMods: u8, affectInternalVirtualMods: u16, internalVirtualMods: u16, affectIgnoreLockVirtualMods: u16, ignoreLockVirtualMods: u16, mouseKeysDfltBtn: u8, groupsWrap: u8, accessXOptions: u16, affectEnabledControls: u32, enabledControls: u32, changeControls: u32, repeatDelay: u16, repeatInterval: u16, slowKeysDelay: u16, debounceDelay: u16, mouseKeysDelay: u16, mouseKeysInterval: u16, mouseKeysTimeToMax: u16, mouseKeysMaxSpeed: u16, mouseKeysCurve: s16, accessXTimeout: u16, accessXTimeoutMask: u32, accessXTimeoutValues: u32, accessXTimeoutOptionsMask: u16, accessXTimeoutOptionsValues: u16, perKeyRepeat: *u8) -> xcb_void_cookie_t #c_call;
    get_map_map_types_rtrn_length:                                         #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> s32 #c_call;
    get_map_map_types_rtrn_iterator:                                       #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> xcb_xkb_key_type_iterator_t #c_call;
    get_map_map_syms_rtrn_length:                                          #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> s32 #c_call;
    get_map_map_syms_rtrn_iterator:                                        #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> xcb_xkb_key_sym_map_iterator_t #c_call;
    get_map_map_acts_rtrn_count:                                           #type (S: *xcb_xkb_get_map_map_t) -> *u8 #c_call;
    get_map_map_acts_rtrn_count_length:                                    #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> s32 #c_call;
    get_map_map_acts_rtrn_count_end:                                       #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> xcb_generic_iterator_t #c_call;
    get_map_map_acts_rtrn_acts:                                            #type (S: *xcb_xkb_get_map_map_t) -> *xcb_xkb_action_t #c_call;
    get_map_map_acts_rtrn_acts_length:                                     #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> s32 #c_call;
    get_map_map_acts_rtrn_acts_iterator:                                   #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> xcb_xkb_action_iterator_t #c_call;
    get_map_map_behaviors_rtrn:                                            #type (S: *xcb_xkb_get_map_map_t) -> *xcb_xkb_set_behavior_t #c_call;
    get_map_map_behaviors_rtrn_length:                                     #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> s32 #c_call;
    get_map_map_behaviors_rtrn_iterator:                                   #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> xcb_xkb_set_behavior_iterator_t #c_call;
    get_map_map_vmods_rtrn:                                                #type (S: *xcb_xkb_get_map_map_t) -> *u8 #c_call;
    get_map_map_vmods_rtrn_length:                                         #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> s32 #c_call;
    get_map_map_vmods_rtrn_end:                                            #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> xcb_generic_iterator_t #c_call;
    get_map_map_explicit_rtrn:                                             #type (S: *xcb_xkb_get_map_map_t) -> *xcb_xkb_set_explicit_t #c_call;
    get_map_map_explicit_rtrn_length:                                      #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> s32 #c_call;
    get_map_map_explicit_rtrn_iterator:                                    #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> xcb_xkb_set_explicit_iterator_t #c_call;
    get_map_map_modmap_rtrn:                                               #type (S: *xcb_xkb_get_map_map_t) -> *xcb_xkb_key_mod_map_t #c_call;
    get_map_map_modmap_rtrn_length:                                        #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> s32 #c_call;
    get_map_map_modmap_rtrn_iterator:                                      #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> xcb_xkb_key_mod_map_iterator_t #c_call;
    get_map_map_vmodmap_rtrn:                                              #type (S: *xcb_xkb_get_map_map_t) -> *xcb_xkb_key_v_mod_map_t #c_call;
    get_map_map_vmodmap_rtrn_length:                                       #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> s32 #c_call;
    get_map_map_vmodmap_rtrn_iterator:                                     #type (R: *xcb_xkb_get_map_reply_t, S: *xcb_xkb_get_map_map_t) -> xcb_xkb_key_v_mod_map_iterator_t #c_call;
    get_map_map_serialize:                                                 #type (_buffer: **void, nTypes: u8, nKeySyms: u8, nKeyActions: u8, totalActions: u16, totalKeyBehaviors: u8, virtualMods: u16, totalKeyExplicit: u8, totalModMapKeys: u8, totalVModMapKeys: u8, present: u16, _aux: *xcb_xkb_get_map_map_t) -> s32 #c_call;
    get_map_map_unpack:                                                    #type (_buffer: *void, nTypes: u8, nKeySyms: u8, nKeyActions: u8, totalActions: u16, totalKeyBehaviors: u8, virtualMods: u16, totalKeyExplicit: u8, totalModMapKeys: u8, totalVModMapKeys: u8, present: u16, _aux: *xcb_xkb_get_map_map_t) -> s32 #c_call;
    get_map_map_sizeof:                                                    #type (_buffer: *void, nTypes: u8, nKeySyms: u8, nKeyActions: u8, totalActions: u16, totalKeyBehaviors: u8, virtualMods: u16, totalKeyExplicit: u8, totalModMapKeys: u8, totalVModMapKeys: u8, present: u16) -> s32 #c_call;
    get_map_sizeof:                                                        #type (_buffer: *void) -> s32 #c_call;
    get_map:                                                               #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, full: u16, partial: u16, firstType: u8, nTypes: u8, firstKeySym: xcb_keycode_t, nKeySyms: u8, firstKeyAction: xcb_keycode_t, nKeyActions: u8, firstKeyBehavior: xcb_keycode_t, nKeyBehaviors: u8, virtualMods: u16, firstKeyExplicit: xcb_keycode_t, nKeyExplicit: u8, firstModMapKey: xcb_keycode_t, nModMapKeys: u8, firstVModMapKey: xcb_keycode_t, nVModMapKeys: u8) -> xcb_xkb_get_map_cookie_t #c_call;
    get_map_unchecked:                                                     #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, full: u16, partial: u16, firstType: u8, nTypes: u8, firstKeySym: xcb_keycode_t, nKeySyms: u8, firstKeyAction: xcb_keycode_t, nKeyActions: u8, firstKeyBehavior: xcb_keycode_t, nKeyBehaviors: u8, virtualMods: u16, firstKeyExplicit: xcb_keycode_t, nKeyExplicit: u8, firstModMapKey: xcb_keycode_t, nModMapKeys: u8, firstVModMapKey: xcb_keycode_t, nVModMapKeys: u8) -> xcb_xkb_get_map_cookie_t #c_call;
    get_map_map:                                                           #type (R: *xcb_xkb_get_map_reply_t) -> *void #c_call;
    get_map_reply:                                                         #type (c: *xcb_connection_t, cookie: xcb_xkb_get_map_cookie_t, e: **xcb_generic_error_t) -> *xcb_xkb_get_map_reply_t #c_call;
    set_map_values_types_length:                                           #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> s32 #c_call;
    set_map_values_types_iterator:                                         #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> xcb_xkb_set_key_type_iterator_t #c_call;
    set_map_values_syms_length:                                            #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> s32 #c_call;
    set_map_values_syms_iterator:                                          #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> xcb_xkb_key_sym_map_iterator_t #c_call;
    set_map_values_actions_count:                                          #type (S: *xcb_xkb_set_map_values_t) -> *u8 #c_call;
    set_map_values_actions_count_length:                                   #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> s32 #c_call;
    set_map_values_actions_count_end:                                      #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> xcb_generic_iterator_t #c_call;
    set_map_values_actions:                                                #type (S: *xcb_xkb_set_map_values_t) -> *xcb_xkb_action_t #c_call;
    set_map_values_actions_length:                                         #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> s32 #c_call;
    set_map_values_actions_iterator:                                       #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> xcb_xkb_action_iterator_t #c_call;
    set_map_values_behaviors:                                              #type (S: *xcb_xkb_set_map_values_t) -> *xcb_xkb_set_behavior_t #c_call;
    set_map_values_behaviors_length:                                       #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> s32 #c_call;
    set_map_values_behaviors_iterator:                                     #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> xcb_xkb_set_behavior_iterator_t #c_call;
    set_map_values_vmods:                                                  #type (S: *xcb_xkb_set_map_values_t) -> *u8 #c_call;
    set_map_values_vmods_length:                                           #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> s32 #c_call;
    set_map_values_vmods_end:                                              #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> xcb_generic_iterator_t #c_call;
    set_map_values_explicit:                                               #type (S: *xcb_xkb_set_map_values_t) -> *xcb_xkb_set_explicit_t #c_call;
    set_map_values_explicit_length:                                        #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> s32 #c_call;
    set_map_values_explicit_iterator:                                      #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> xcb_xkb_set_explicit_iterator_t #c_call;
    set_map_values_modmap:                                                 #type (S: *xcb_xkb_set_map_values_t) -> *xcb_xkb_key_mod_map_t #c_call;
    set_map_values_modmap_length:                                          #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> s32 #c_call;
    set_map_values_modmap_iterator:                                        #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> xcb_xkb_key_mod_map_iterator_t #c_call;
    set_map_values_vmodmap:                                                #type (S: *xcb_xkb_set_map_values_t) -> *xcb_xkb_key_v_mod_map_t #c_call;
    set_map_values_vmodmap_length:                                         #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> s32 #c_call;
    set_map_values_vmodmap_iterator:                                       #type (R: *xcb_xkb_set_map_request_t, S: *xcb_xkb_set_map_values_t) -> xcb_xkb_key_v_mod_map_iterator_t #c_call;
    set_map_values_serialize:                                              #type (_buffer: **void, nTypes: u8, nKeySyms: u8, nKeyActions: u8, totalActions: u16, totalKeyBehaviors: u8, virtualMods: u16, totalKeyExplicit: u8, totalModMapKeys: u8, totalVModMapKeys: u8, present: u16, _aux: *xcb_xkb_set_map_values_t) -> s32 #c_call;
    set_map_values_unpack:                                                 #type (_buffer: *void, nTypes: u8, nKeySyms: u8, nKeyActions: u8, totalActions: u16, totalKeyBehaviors: u8, virtualMods: u16, totalKeyExplicit: u8, totalModMapKeys: u8, totalVModMapKeys: u8, present: u16, _aux: *xcb_xkb_set_map_values_t) -> s32 #c_call;
    set_map_values_sizeof:                                                 #type (_buffer: *void, nTypes: u8, nKeySyms: u8, nKeyActions: u8, totalActions: u16, totalKeyBehaviors: u8, virtualMods: u16, totalKeyExplicit: u8, totalModMapKeys: u8, totalVModMapKeys: u8, present: u16) -> s32 #c_call;
    set_map_sizeof:                                                        #type (_buffer: *void) -> s32 #c_call;
    set_map_checked:                                                       #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, present: u16, flags: u16, minKeyCode: xcb_keycode_t, maxKeyCode: xcb_keycode_t, firstType: u8, nTypes: u8, firstKeySym: xcb_keycode_t, nKeySyms: u8, totalSyms: u16, firstKeyAction: xcb_keycode_t, nKeyActions: u8, totalActions: u16, firstKeyBehavior: xcb_keycode_t, nKeyBehaviors: u8, totalKeyBehaviors: u8, firstKeyExplicit: xcb_keycode_t, nKeyExplicit: u8, totalKeyExplicit: u8, firstModMapKey: xcb_keycode_t, nModMapKeys: u8, totalModMapKeys: u8, firstVModMapKey: xcb_keycode_t, nVModMapKeys: u8, totalVModMapKeys: u8, virtualMods: u16, values: *void) -> xcb_void_cookie_t #c_call;
    set_map:                                                               #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, present: u16, flags: u16, minKeyCode: xcb_keycode_t, maxKeyCode: xcb_keycode_t, firstType: u8, nTypes: u8, firstKeySym: xcb_keycode_t, nKeySyms: u8, totalSyms: u16, firstKeyAction: xcb_keycode_t, nKeyActions: u8, totalActions: u16, firstKeyBehavior: xcb_keycode_t, nKeyBehaviors: u8, totalKeyBehaviors: u8, firstKeyExplicit: xcb_keycode_t, nKeyExplicit: u8, totalKeyExplicit: u8, firstModMapKey: xcb_keycode_t, nModMapKeys: u8, totalModMapKeys: u8, firstVModMapKey: xcb_keycode_t, nVModMapKeys: u8, totalVModMapKeys: u8, virtualMods: u16, values: *void) -> xcb_void_cookie_t #c_call;
    set_map_aux_checked:                                                   #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, present: u16, flags: u16, minKeyCode: xcb_keycode_t, maxKeyCode: xcb_keycode_t, firstType: u8, nTypes: u8, firstKeySym: xcb_keycode_t, nKeySyms: u8, totalSyms: u16, firstKeyAction: xcb_keycode_t, nKeyActions: u8, totalActions: u16, firstKeyBehavior: xcb_keycode_t, nKeyBehaviors: u8, totalKeyBehaviors: u8, firstKeyExplicit: xcb_keycode_t, nKeyExplicit: u8, totalKeyExplicit: u8, firstModMapKey: xcb_keycode_t, nModMapKeys: u8, totalModMapKeys: u8, firstVModMapKey: xcb_keycode_t, nVModMapKeys: u8, totalVModMapKeys: u8, virtualMods: u16, values: *xcb_xkb_set_map_values_t) -> xcb_void_cookie_t #c_call;
    set_map_aux:                                                           #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, present: u16, flags: u16, minKeyCode: xcb_keycode_t, maxKeyCode: xcb_keycode_t, firstType: u8, nTypes: u8, firstKeySym: xcb_keycode_t, nKeySyms: u8, totalSyms: u16, firstKeyAction: xcb_keycode_t, nKeyActions: u8, totalActions: u16, firstKeyBehavior: xcb_keycode_t, nKeyBehaviors: u8, totalKeyBehaviors: u8, firstKeyExplicit: xcb_keycode_t, nKeyExplicit: u8, totalKeyExplicit: u8, firstModMapKey: xcb_keycode_t, nModMapKeys: u8, totalModMapKeys: u8, firstVModMapKey: xcb_keycode_t, nVModMapKeys: u8, totalVModMapKeys: u8, virtualMods: u16, values: *xcb_xkb_set_map_values_t) -> xcb_void_cookie_t #c_call;
    set_map_values:                                                        #type (R: *xcb_xkb_set_map_request_t) -> *void #c_call;
    get_compat_map_sizeof:                                                 #type (_buffer: *void) -> s32 #c_call;
    get_compat_map:                                                        #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, groups: u8, getAllSI: u8, firstSI: u16, nSI: u16) -> xcb_xkb_get_compat_map_cookie_t #c_call;
    get_compat_map_unchecked:                                              #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, groups: u8, getAllSI: u8, firstSI: u16, nSI: u16) -> xcb_xkb_get_compat_map_cookie_t #c_call;
    get_compat_map_si_rtrn:                                                #type (R: *xcb_xkb_get_compat_map_reply_t) -> *xcb_xkb_sym_interpret_t #c_call;
    get_compat_map_si_rtrn_length:                                         #type (R: *xcb_xkb_get_compat_map_reply_t) -> s32 #c_call;
    get_compat_map_si_rtrn_iterator:                                       #type (R: *xcb_xkb_get_compat_map_reply_t) -> xcb_xkb_sym_interpret_iterator_t #c_call;
    get_compat_map_group_rtrn:                                             #type (R: *xcb_xkb_get_compat_map_reply_t) -> *xcb_xkb_mod_def_t #c_call;
    get_compat_map_group_rtrn_length:                                      #type (R: *xcb_xkb_get_compat_map_reply_t) -> s32 #c_call;
    get_compat_map_group_rtrn_iterator:                                    #type (R: *xcb_xkb_get_compat_map_reply_t) -> xcb_xkb_mod_def_iterator_t #c_call;
    get_compat_map_reply:                                                  #type (c: *xcb_connection_t, cookie: xcb_xkb_get_compat_map_cookie_t, e: **xcb_generic_error_t) -> *xcb_xkb_get_compat_map_reply_t #c_call;
    set_compat_map_sizeof:                                                 #type (_buffer: *void) -> s32 #c_call;
    set_compat_map_checked:                                                #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, recomputeActions: u8, truncateSI: u8, groups: u8, firstSI: u16, nSI: u16, si: *xcb_xkb_sym_interpret_t, groupMaps: *xcb_xkb_mod_def_t) -> xcb_void_cookie_t #c_call;
    set_compat_map:                                                        #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, recomputeActions: u8, truncateSI: u8, groups: u8, firstSI: u16, nSI: u16, si: *xcb_xkb_sym_interpret_t, groupMaps: *xcb_xkb_mod_def_t) -> xcb_void_cookie_t #c_call;
    set_compat_map_si:                                                     #type (R: *xcb_xkb_set_compat_map_request_t) -> *xcb_xkb_sym_interpret_t #c_call;
    set_compat_map_si_length:                                              #type (R: *xcb_xkb_set_compat_map_request_t) -> s32 #c_call;
    set_compat_map_si_iterator:                                            #type (R: *xcb_xkb_set_compat_map_request_t) -> xcb_xkb_sym_interpret_iterator_t #c_call;
    set_compat_map_group_maps:                                             #type (R: *xcb_xkb_set_compat_map_request_t) -> *xcb_xkb_mod_def_t #c_call;
    set_compat_map_group_maps_length:                                      #type (R: *xcb_xkb_set_compat_map_request_t) -> s32 #c_call;
    set_compat_map_group_maps_iterator:                                    #type (R: *xcb_xkb_set_compat_map_request_t) -> xcb_xkb_mod_def_iterator_t #c_call;
    get_indicator_state:                                                   #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t) -> xcb_xkb_get_indicator_state_cookie_t #c_call;
    get_indicator_state_unchecked:                                         #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t) -> xcb_xkb_get_indicator_state_cookie_t #c_call;
    get_indicator_state_reply:                                             #type (c: *xcb_connection_t, cookie: xcb_xkb_get_indicator_state_cookie_t, e: **xcb_generic_error_t) -> *xcb_xkb_get_indicator_state_reply_t #c_call;
    get_indicator_map_sizeof:                                              #type (_buffer: *void) -> s32 #c_call;
    get_indicator_map:                                                     #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, which: u32) -> xcb_xkb_get_indicator_map_cookie_t #c_call;
    get_indicator_map_unchecked:                                           #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, which: u32) -> xcb_xkb_get_indicator_map_cookie_t #c_call;
    get_indicator_map_maps:                                                #type (R: *xcb_xkb_get_indicator_map_reply_t) -> *xcb_xkb_indicator_map_t #c_call;
    get_indicator_map_maps_length:                                         #type (R: *xcb_xkb_get_indicator_map_reply_t) -> s32 #c_call;
    get_indicator_map_maps_iterator:                                       #type (R: *xcb_xkb_get_indicator_map_reply_t) -> xcb_xkb_indicator_map_iterator_t #c_call;
    get_indicator_map_reply:                                               #type (c: *xcb_connection_t, cookie: xcb_xkb_get_indicator_map_cookie_t, e: **xcb_generic_error_t) -> *xcb_xkb_get_indicator_map_reply_t #c_call;
    set_indicator_map_sizeof:                                              #type (_buffer: *void) -> s32 #c_call;
    set_indicator_map_checked:                                             #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, which: u32, maps: *xcb_xkb_indicator_map_t) -> xcb_void_cookie_t #c_call;
    set_indicator_map:                                                     #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, which: u32, maps: *xcb_xkb_indicator_map_t) -> xcb_void_cookie_t #c_call;
    set_indicator_map_maps:                                                #type (R: *xcb_xkb_set_indicator_map_request_t) -> *xcb_xkb_indicator_map_t #c_call;
    set_indicator_map_maps_length:                                         #type (R: *xcb_xkb_set_indicator_map_request_t) -> s32 #c_call;
    set_indicator_map_maps_iterator:                                       #type (R: *xcb_xkb_set_indicator_map_request_t) -> xcb_xkb_indicator_map_iterator_t #c_call;
    get_named_indicator:                                                   #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, ledClass: xcb_xkb_led_class_spec_t, ledID: xcb_xkb_id_spec_t, indicator: xcb_atom_t) -> xcb_xkb_get_named_indicator_cookie_t #c_call;
    get_named_indicator_unchecked:                                         #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, ledClass: xcb_xkb_led_class_spec_t, ledID: xcb_xkb_id_spec_t, indicator: xcb_atom_t) -> xcb_xkb_get_named_indicator_cookie_t #c_call;
    get_named_indicator_reply:                                             #type (c: *xcb_connection_t, cookie: xcb_xkb_get_named_indicator_cookie_t, e: **xcb_generic_error_t) -> *xcb_xkb_get_named_indicator_reply_t #c_call;
    set_named_indicator_checked:                                           #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, ledClass: xcb_xkb_led_class_spec_t, ledID: xcb_xkb_id_spec_t, indicator: xcb_atom_t, setState: u8, on: u8, setMap: u8, createMap: u8, map_flags: u8, map_whichGroups: u8, map_groups: u8, map_whichMods: u8, map_realMods: u8, map_vmods: u16, map_ctrls: u32) -> xcb_void_cookie_t #c_call;
    set_named_indicator:                                                   #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, ledClass: xcb_xkb_led_class_spec_t, ledID: xcb_xkb_id_spec_t, indicator: xcb_atom_t, setState: u8, on: u8, setMap: u8, createMap: u8, map_flags: u8, map_whichGroups: u8, map_groups: u8, map_whichMods: u8, map_realMods: u8, map_vmods: u16, map_ctrls: u32) -> xcb_void_cookie_t #c_call;
    get_names_value_list_type_names:                                       #type (S: *xcb_xkb_get_names_value_list_t) -> *xcb_atom_t #c_call;
    get_names_value_list_type_names_length:                                #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> s32 #c_call;
    get_names_value_list_type_names_end:                                   #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> xcb_generic_iterator_t #c_call;
    get_names_value_list_n_levels_per_type:                                #type (S: *xcb_xkb_get_names_value_list_t) -> *u8 #c_call;
    get_names_value_list_n_levels_per_type_length:                         #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> s32 #c_call;
    get_names_value_list_n_levels_per_type_end:                            #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> xcb_generic_iterator_t #c_call;
    get_names_value_list_kt_level_names:                                   #type (S: *xcb_xkb_get_names_value_list_t) -> *xcb_atom_t #c_call;
    get_names_value_list_kt_level_names_length:                            #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> s32 #c_call;
    get_names_value_list_kt_level_names_end:                               #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> xcb_generic_iterator_t #c_call;
    get_names_value_list_indicator_names:                                  #type (S: *xcb_xkb_get_names_value_list_t) -> *xcb_atom_t #c_call;
    get_names_value_list_indicator_names_length:                           #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> s32 #c_call;
    get_names_value_list_indicator_names_end:                              #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> xcb_generic_iterator_t #c_call;
    get_names_value_list_virtual_mod_names:                                #type (S: *xcb_xkb_get_names_value_list_t) -> *xcb_atom_t #c_call;
    get_names_value_list_virtual_mod_names_length:                         #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> s32 #c_call;
    get_names_value_list_virtual_mod_names_end:                            #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> xcb_generic_iterator_t #c_call;
    get_names_value_list_groups:                                           #type (S: *xcb_xkb_get_names_value_list_t) -> *xcb_atom_t #c_call;
    get_names_value_list_groups_length:                                    #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> s32 #c_call;
    get_names_value_list_groups_end:                                       #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> xcb_generic_iterator_t #c_call;
    get_names_value_list_key_names:                                        #type (S: *xcb_xkb_get_names_value_list_t) -> *xcb_xkb_key_name_t #c_call;
    get_names_value_list_key_names_length:                                 #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> s32 #c_call;
    get_names_value_list_key_names_iterator:                               #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> xcb_xkb_key_name_iterator_t #c_call;
    get_names_value_list_key_aliases:                                      #type (S: *xcb_xkb_get_names_value_list_t) -> *xcb_xkb_key_alias_t #c_call;
    get_names_value_list_key_aliases_length:                               #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> s32 #c_call;
    get_names_value_list_key_aliases_iterator:                             #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> xcb_xkb_key_alias_iterator_t #c_call;
    get_names_value_list_radio_group_names:                                #type (S: *xcb_xkb_get_names_value_list_t) -> *xcb_atom_t #c_call;
    get_names_value_list_radio_group_names_length:                         #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> s32 #c_call;
    get_names_value_list_radio_group_names_end:                            #type (R: *xcb_xkb_get_names_reply_t, S: *xcb_xkb_get_names_value_list_t) -> xcb_generic_iterator_t #c_call;
    get_names_value_list_serialize:                                        #type (_buffer: **void, nTypes: u8, indicators: u32, virtualMods: u16, groupNames: u8, nKeys: u8, nKeyAliases: u8, nRadioGroups: u8, which: u32, _aux: *xcb_xkb_get_names_value_list_t) -> s32 #c_call;
    get_names_value_list_unpack:                                           #type (_buffer: *void, nTypes: u8, indicators: u32, virtualMods: u16, groupNames: u8, nKeys: u8, nKeyAliases: u8, nRadioGroups: u8, which: u32, _aux: *xcb_xkb_get_names_value_list_t) -> s32 #c_call;
    get_names_value_list_sizeof:                                           #type (_buffer: *void, nTypes: u8, indicators: u32, virtualMods: u16, groupNames: u8, nKeys: u8, nKeyAliases: u8, nRadioGroups: u8, which: u32) -> s32 #c_call;
    get_names_sizeof:                                                      #type (_buffer: *void) -> s32 #c_call;
    get_names:                                                             #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, which: u32) -> xcb_xkb_get_names_cookie_t #c_call;
    get_names_unchecked:                                                   #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, which: u32) -> xcb_xkb_get_names_cookie_t #c_call;
    get_names_value_list:                                                  #type (R: *xcb_xkb_get_names_reply_t) -> *void #c_call;
    get_names_reply:                                                       #type (c: *xcb_connection_t, cookie: xcb_xkb_get_names_cookie_t, e: **xcb_generic_error_t) -> *xcb_xkb_get_names_reply_t #c_call;
    set_names_values_type_names:                                           #type (S: *xcb_xkb_set_names_values_t) -> *xcb_atom_t #c_call;
    set_names_values_type_names_length:                                    #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> s32 #c_call;
    set_names_values_type_names_end:                                       #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> xcb_generic_iterator_t #c_call;
    set_names_values_n_levels_per_type:                                    #type (S: *xcb_xkb_set_names_values_t) -> *u8 #c_call;
    set_names_values_n_levels_per_type_length:                             #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> s32 #c_call;
    set_names_values_n_levels_per_type_end:                                #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> xcb_generic_iterator_t #c_call;
    set_names_values_kt_level_names:                                       #type (S: *xcb_xkb_set_names_values_t) -> *xcb_atom_t #c_call;
    set_names_values_kt_level_names_length:                                #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> s32 #c_call;
    set_names_values_kt_level_names_end:                                   #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> xcb_generic_iterator_t #c_call;
    set_names_values_indicator_names:                                      #type (S: *xcb_xkb_set_names_values_t) -> *xcb_atom_t #c_call;
    set_names_values_indicator_names_length:                               #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> s32 #c_call;
    set_names_values_indicator_names_end:                                  #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> xcb_generic_iterator_t #c_call;
    set_names_values_virtual_mod_names:                                    #type (S: *xcb_xkb_set_names_values_t) -> *xcb_atom_t #c_call;
    set_names_values_virtual_mod_names_length:                             #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> s32 #c_call;
    set_names_values_virtual_mod_names_end:                                #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> xcb_generic_iterator_t #c_call;
    set_names_values_groups:                                               #type (S: *xcb_xkb_set_names_values_t) -> *xcb_atom_t #c_call;
    set_names_values_groups_length:                                        #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> s32 #c_call;
    set_names_values_groups_end:                                           #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> xcb_generic_iterator_t #c_call;
    set_names_values_key_names:                                            #type (S: *xcb_xkb_set_names_values_t) -> *xcb_xkb_key_name_t #c_call;
    set_names_values_key_names_length:                                     #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> s32 #c_call;
    set_names_values_key_names_iterator:                                   #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> xcb_xkb_key_name_iterator_t #c_call;
    set_names_values_key_aliases:                                          #type (S: *xcb_xkb_set_names_values_t) -> *xcb_xkb_key_alias_t #c_call;
    set_names_values_key_aliases_length:                                   #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> s32 #c_call;
    set_names_values_key_aliases_iterator:                                 #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> xcb_xkb_key_alias_iterator_t #c_call;
    set_names_values_radio_group_names:                                    #type (S: *xcb_xkb_set_names_values_t) -> *xcb_atom_t #c_call;
    set_names_values_radio_group_names_length:                             #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> s32 #c_call;
    set_names_values_radio_group_names_end:                                #type (R: *xcb_xkb_set_names_request_t, S: *xcb_xkb_set_names_values_t) -> xcb_generic_iterator_t #c_call;
    set_names_values_serialize:                                            #type (_buffer: **void, nTypes: u8, indicators: u32, virtualMods: u16, groupNames: u8, nKeys: u8, nKeyAliases: u8, nRadioGroups: u8, which: u32, _aux: *xcb_xkb_set_names_values_t) -> s32 #c_call;
    set_names_values_unpack:                                               #type (_buffer: *void, nTypes: u8, indicators: u32, virtualMods: u16, groupNames: u8, nKeys: u8, nKeyAliases: u8, nRadioGroups: u8, which: u32, _aux: *xcb_xkb_set_names_values_t) -> s32 #c_call;
    set_names_values_sizeof:                                               #type (_buffer: *void, nTypes: u8, indicators: u32, virtualMods: u16, groupNames: u8, nKeys: u8, nKeyAliases: u8, nRadioGroups: u8, which: u32) -> s32 #c_call;
    set_names_sizeof:                                                      #type (_buffer: *void) -> s32 #c_call;
    set_names_checked:                                                     #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, virtualMods: u16, which: u32, firstType: u8, nTypes: u8, firstKTLevelt: u8, nKTLevels: u8, indicators: u32, groupNames: u8, nRadioGroups: u8, firstKey: xcb_keycode_t, nKeys: u8, nKeyAliases: u8, totalKTLevelNames: u16, values: *void) -> xcb_void_cookie_t #c_call;
    set_names:                                                             #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, virtualMods: u16, which: u32, firstType: u8, nTypes: u8, firstKTLevelt: u8, nKTLevels: u8, indicators: u32, groupNames: u8, nRadioGroups: u8, firstKey: xcb_keycode_t, nKeys: u8, nKeyAliases: u8, totalKTLevelNames: u16, values: *void) -> xcb_void_cookie_t #c_call;
    set_names_aux_checked:                                                 #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, virtualMods: u16, which: u32, firstType: u8, nTypes: u8, firstKTLevelt: u8, nKTLevels: u8, indicators: u32, groupNames: u8, nRadioGroups: u8, firstKey: xcb_keycode_t, nKeys: u8, nKeyAliases: u8, totalKTLevelNames: u16, values: *xcb_xkb_set_names_values_t) -> xcb_void_cookie_t #c_call;
    set_names_aux:                                                         #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, virtualMods: u16, which: u32, firstType: u8, nTypes: u8, firstKTLevelt: u8, nKTLevels: u8, indicators: u32, groupNames: u8, nRadioGroups: u8, firstKey: xcb_keycode_t, nKeys: u8, nKeyAliases: u8, totalKTLevelNames: u16, values: *xcb_xkb_set_names_values_t) -> xcb_void_cookie_t #c_call;
    set_names_values:                                                      #type (R: *xcb_xkb_set_names_request_t) -> *void #c_call;
    per_client_flags:                                                      #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, change: u32, value: u32, ctrlsToChange: u32, autoCtrls: u32, autoCtrlsValues: u32) -> xcb_xkb_per_client_flags_cookie_t #c_call;
    per_client_flags_unchecked:                                            #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, change: u32, value: u32, ctrlsToChange: u32, autoCtrls: u32, autoCtrlsValues: u32) -> xcb_xkb_per_client_flags_cookie_t #c_call;
    per_client_flags_reply:                                                #type (c: *xcb_connection_t, cookie: xcb_xkb_per_client_flags_cookie_t, e: **xcb_generic_error_t) -> *xcb_xkb_per_client_flags_reply_t #c_call;
    list_components_sizeof:                                                #type (_buffer: *void) -> s32 #c_call;
    list_components:                                                       #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, maxNames: u16) -> xcb_xkb_list_components_cookie_t #c_call;
    list_components_unchecked:                                             #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, maxNames: u16) -> xcb_xkb_list_components_cookie_t #c_call;
    list_components_keymaps_length:                                        #type (R: *xcb_xkb_list_components_reply_t) -> s32 #c_call;
    list_components_keymaps_iterator:                                      #type (R: *xcb_xkb_list_components_reply_t) -> xcb_xkb_listing_iterator_t #c_call;
    list_components_keycodes_length:                                       #type (R: *xcb_xkb_list_components_reply_t) -> s32 #c_call;
    list_components_keycodes_iterator:                                     #type (R: *xcb_xkb_list_components_reply_t) -> xcb_xkb_listing_iterator_t #c_call;
    list_components_types_length:                                          #type (R: *xcb_xkb_list_components_reply_t) -> s32 #c_call;
    list_components_types_iterator:                                        #type (R: *xcb_xkb_list_components_reply_t) -> xcb_xkb_listing_iterator_t #c_call;
    list_components_compat_maps_length:                                    #type (R: *xcb_xkb_list_components_reply_t) -> s32 #c_call;
    list_components_compat_maps_iterator:                                  #type (R: *xcb_xkb_list_components_reply_t) -> xcb_xkb_listing_iterator_t #c_call;
    list_components_symbols_length:                                        #type (R: *xcb_xkb_list_components_reply_t) -> s32 #c_call;
    list_components_symbols_iterator:                                      #type (R: *xcb_xkb_list_components_reply_t) -> xcb_xkb_listing_iterator_t #c_call;
    list_components_geometries_length:                                     #type (R: *xcb_xkb_list_components_reply_t) -> s32 #c_call;
    list_components_geometries_iterator:                                   #type (R: *xcb_xkb_list_components_reply_t) -> xcb_xkb_listing_iterator_t #c_call;
    list_components_reply:                                                 #type (c: *xcb_connection_t, cookie: xcb_xkb_list_components_cookie_t, e: **xcb_generic_error_t) -> *xcb_xkb_list_components_reply_t #c_call;
    get_kbd_by_name_replies_types_map_types_rtrn_length:                   #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_types_map_types_rtrn_iterator:                 #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_xkb_key_type_iterator_t #c_call;
    get_kbd_by_name_replies_types_map_syms_rtrn_length:                    #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_types_map_syms_rtrn_iterator:                  #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_xkb_key_sym_map_iterator_t #c_call;
    get_kbd_by_name_replies_types_map_acts_rtrn_count:                     #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *u8 #c_call;
    get_kbd_by_name_replies_types_map_acts_rtrn_count_length:              #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_types_map_acts_rtrn_count_end:                 #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_generic_iterator_t #c_call;
    get_kbd_by_name_replies_types_map_acts_rtrn_acts:                      #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_xkb_action_t #c_call;
    get_kbd_by_name_replies_types_map_acts_rtrn_acts_length:               #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_types_map_acts_rtrn_acts_iterator:             #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_xkb_action_iterator_t #c_call;
    get_kbd_by_name_replies_types_map_behaviors_rtrn:                      #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_xkb_set_behavior_t #c_call;
    get_kbd_by_name_replies_types_map_behaviors_rtrn_length:               #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_types_map_behaviors_rtrn_iterator:             #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_xkb_set_behavior_iterator_t #c_call;
    get_kbd_by_name_replies_types_map_vmods_rtrn:                          #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *u8 #c_call;
    get_kbd_by_name_replies_types_map_vmods_rtrn_length:                   #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_types_map_vmods_rtrn_end:                      #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_generic_iterator_t #c_call;
    get_kbd_by_name_replies_types_map_explicit_rtrn:                       #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_xkb_set_explicit_t #c_call;
    get_kbd_by_name_replies_types_map_explicit_rtrn_length:                #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_types_map_explicit_rtrn_iterator:              #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_xkb_set_explicit_iterator_t #c_call;
    get_kbd_by_name_replies_types_map_modmap_rtrn:                         #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_xkb_key_mod_map_t #c_call;
    get_kbd_by_name_replies_types_map_modmap_rtrn_length:                  #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_types_map_modmap_rtrn_iterator:                #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_xkb_key_mod_map_iterator_t #c_call;
    get_kbd_by_name_replies_types_map_vmodmap_rtrn:                        #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_xkb_key_v_mod_map_t #c_call;
    get_kbd_by_name_replies_types_map_vmodmap_rtrn_length:                 #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_types_map_vmodmap_rtrn_iterator:               #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_xkb_key_v_mod_map_iterator_t #c_call;
    get_kbd_by_name_replies_types_map_serialize:                           #type (_buffer: **void, nTypes: u8, nKeySyms: u8, nKeyActions: u8, totalActions: u16, totalKeyBehaviors: u8, virtualMods: u16, totalKeyExplicit: u8, totalModMapKeys: u8, totalVModMapKeys: u8, present: u16, _aux: *xcb_xkb_get_kbd_by_name_replies_types_map_t) -> s32 #c_call;
    get_kbd_by_name_replies_types_map_unpack:                              #type (_buffer: *void, nTypes: u8, nKeySyms: u8, nKeyActions: u8, totalActions: u16, totalKeyBehaviors: u8, virtualMods: u16, totalKeyExplicit: u8, totalModMapKeys: u8, totalVModMapKeys: u8, present: u16, _aux: *xcb_xkb_get_kbd_by_name_replies_types_map_t) -> s32 #c_call;
    get_kbd_by_name_replies_types_map_sizeof:                              #type (_buffer: *void, nTypes: u8, nKeySyms: u8, nKeyActions: u8, totalActions: u16, totalKeyBehaviors: u8, virtualMods: u16, totalKeyExplicit: u8, totalModMapKeys: u8, totalVModMapKeys: u8, present: u16) -> s32 #c_call;
    get_kbd_by_name_replies_key_names_value_list_type_names:               #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_atom_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_type_names_length:        #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_key_names_value_list_type_names_end:           #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_generic_iterator_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_n_levels_per_type:        #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *u8 #c_call;
    get_kbd_by_name_replies_key_names_value_list_n_levels_per_type_length: #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_key_names_value_list_n_levels_per_type_end:    #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_generic_iterator_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_kt_level_names:           #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_atom_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_kt_level_names_length:    #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_key_names_value_list_kt_level_names_end:       #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_generic_iterator_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_indicator_names:          #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_atom_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_indicator_names_length:   #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_key_names_value_list_indicator_names_end:      #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_generic_iterator_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_virtual_mod_names:        #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_atom_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_virtual_mod_names_length: #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_key_names_value_list_virtual_mod_names_end:    #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_generic_iterator_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_groups:                   #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_atom_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_groups_length:            #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_key_names_value_list_groups_end:               #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_generic_iterator_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_key_names:                #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_xkb_key_name_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_key_names_length:         #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_key_names_value_list_key_names_iterator:       #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_xkb_key_name_iterator_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_key_aliases:              #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_xkb_key_alias_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_key_aliases_length:       #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_key_names_value_list_key_aliases_iterator:     #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_xkb_key_alias_iterator_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_radio_group_names:        #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_atom_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_radio_group_names_length: #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_key_names_value_list_radio_group_names_end:    #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_generic_iterator_t #c_call;
    get_kbd_by_name_replies_key_names_value_list_serialize:                #type (_buffer: **void, nTypes: u8, indicators: u32, virtualMods: u16, groupNames: u8, nKeys: u8, nKeyAliases: u8, nRadioGroups: u8, which: u32, _aux: *xcb_xkb_get_kbd_by_name_replies_key_names_value_list_t) -> s32 #c_call;
    get_kbd_by_name_replies_key_names_value_list_unpack:                   #type (_buffer: *void, nTypes: u8, indicators: u32, virtualMods: u16, groupNames: u8, nKeys: u8, nKeyAliases: u8, nRadioGroups: u8, which: u32, _aux: *xcb_xkb_get_kbd_by_name_replies_key_names_value_list_t) -> s32 #c_call;
    get_kbd_by_name_replies_key_names_value_list_sizeof:                   #type (_buffer: *void, nTypes: u8, indicators: u32, virtualMods: u16, groupNames: u8, nKeys: u8, nKeyAliases: u8, nRadioGroups: u8, which: u32) -> s32 #c_call;
    get_kbd_by_name_replies_compat_map_si_rtrn:                            #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_xkb_sym_interpret_t #c_call;
    get_kbd_by_name_replies_compat_map_si_rtrn_length:                     #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_compat_map_si_rtrn_iterator:                   #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_xkb_sym_interpret_iterator_t #c_call;
    get_kbd_by_name_replies_compat_map_group_rtrn:                         #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_xkb_mod_def_t #c_call;
    get_kbd_by_name_replies_compat_map_group_rtrn_length:                  #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_compat_map_group_rtrn_iterator:                #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_xkb_mod_def_iterator_t #c_call;
    get_kbd_by_name_replies_indicator_maps_maps:                           #type (S: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_xkb_indicator_map_t #c_call;
    get_kbd_by_name_replies_indicator_maps_maps_length:                    #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_indicator_maps_maps_iterator:                  #type (R: *xcb_xkb_get_kbd_by_name_reply_t, S: *xcb_xkb_get_kbd_by_name_replies_t) -> xcb_xkb_indicator_map_iterator_t #c_call;
    get_kbd_by_name_replies_key_names_value_list:                          #type (R: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_xkb_get_kbd_by_name_replies_key_names_value_list_t #c_call;
    get_kbd_by_name_replies_geometry_label_font:                           #type (R: *xcb_xkb_get_kbd_by_name_replies_t) -> *xcb_xkb_counted_string_16_t #c_call;
    get_kbd_by_name_replies_serialize:                                     #type (_buffer: **void, reported: u16, _aux: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_unpack:                                        #type (_buffer: *void, reported: u16, _aux: *xcb_xkb_get_kbd_by_name_replies_t) -> s32 #c_call;
    get_kbd_by_name_replies_sizeof:                                        #type (_buffer: *void, reported: u16) -> s32 #c_call;
    get_kbd_by_name_sizeof:                                                #type (_buffer: *void) -> s32 #c_call;
    get_kbd_by_name:                                                       #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, need: u16, want: u16, load: u8) -> xcb_xkb_get_kbd_by_name_cookie_t #c_call;
    get_kbd_by_name_unchecked:                                             #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, need: u16, want: u16, load: u8) -> xcb_xkb_get_kbd_by_name_cookie_t #c_call;
    get_kbd_by_name_replies:                                               #type (R: *xcb_xkb_get_kbd_by_name_reply_t) -> *void #c_call;
    get_kbd_by_name_reply:                                                 #type (c: *xcb_connection_t, cookie: xcb_xkb_get_kbd_by_name_cookie_t, e: **xcb_generic_error_t) -> *xcb_xkb_get_kbd_by_name_reply_t #c_call;
    get_device_info_sizeof:                                                #type (_buffer: *void) -> s32 #c_call;
    get_device_info:                                                       #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, wanted: u16, allButtons: u8, firstButton: u8, nButtons: u8, ledClass: xcb_xkb_led_class_spec_t, ledID: xcb_xkb_id_spec_t) -> xcb_xkb_get_device_info_cookie_t #c_call;
    get_device_info_unchecked:                                             #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, wanted: u16, allButtons: u8, firstButton: u8, nButtons: u8, ledClass: xcb_xkb_led_class_spec_t, ledID: xcb_xkb_id_spec_t) -> xcb_xkb_get_device_info_cookie_t #c_call;
    get_device_info_name:                                                  #type (R: *xcb_xkb_get_device_info_reply_t) -> *xcb_xkb_string8_t #c_call;
    get_device_info_name_length:                                           #type (R: *xcb_xkb_get_device_info_reply_t) -> s32 #c_call;
    get_device_info_name_end:                                              #type (R: *xcb_xkb_get_device_info_reply_t) -> xcb_generic_iterator_t #c_call;
    get_device_info_btn_actions:                                           #type (R: *xcb_xkb_get_device_info_reply_t) -> *xcb_xkb_action_t #c_call;
    get_device_info_btn_actions_length:                                    #type (R: *xcb_xkb_get_device_info_reply_t) -> s32 #c_call;
    get_device_info_btn_actions_iterator:                                  #type (R: *xcb_xkb_get_device_info_reply_t) -> xcb_xkb_action_iterator_t #c_call;
    get_device_info_leds_length:                                           #type (R: *xcb_xkb_get_device_info_reply_t) -> s32 #c_call;
    get_device_info_leds_iterator:                                         #type (R: *xcb_xkb_get_device_info_reply_t) -> xcb_xkb_device_led_info_iterator_t #c_call;
    get_device_info_reply:                                                 #type (c: *xcb_connection_t, cookie: xcb_xkb_get_device_info_cookie_t, e: **xcb_generic_error_t) -> *xcb_xkb_get_device_info_reply_t #c_call;
    set_device_info_sizeof:                                                #type (_buffer: *void) -> s32 #c_call;
    set_device_info_checked:                                               #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, firstBtn: u8, nBtns: u8, change: u16, nDeviceLedFBs: u16, btnActions: *xcb_xkb_action_t, leds: *xcb_xkb_device_led_info_t) -> xcb_void_cookie_t #c_call;
    set_device_info:                                                       #type (c: *xcb_connection_t, deviceSpec: xcb_xkb_device_spec_t, firstBtn: u8, nBtns: u8, change: u16, nDeviceLedFBs: u16, btnActions: *xcb_xkb_action_t, leds: *xcb_xkb_device_led_info_t) -> xcb_void_cookie_t #c_call;
    set_device_info_btn_actions:                                           #type (R: *xcb_xkb_set_device_info_request_t) -> *xcb_xkb_action_t #c_call;
    set_device_info_btn_actions_length:                                    #type (R: *xcb_xkb_set_device_info_request_t) -> s32 #c_call;
    set_device_info_btn_actions_iterator:                                  #type (R: *xcb_xkb_set_device_info_request_t) -> xcb_xkb_action_iterator_t #c_call;
    set_device_info_leds_length:                                           #type (R: *xcb_xkb_set_device_info_request_t) -> s32 #c_call;
    set_device_info_leds_iterator:                                         #type (R: *xcb_xkb_set_device_info_request_t) -> xcb_xkb_device_led_info_iterator_t #c_call;
    set_debugging_flags_sizeof:                                            #type (_buffer: *void) -> s32 #c_call;
    set_debugging_flags:                                                   #type (c: *xcb_connection_t, msgLength: u16, affectFlags: u32, flags: u32, affectCtrls: u32, ctrls: u32, message: *xcb_xkb_string8_t) -> xcb_xkb_set_debugging_flags_cookie_t #c_call;
    set_debugging_flags_unchecked:                                         #type (c: *xcb_connection_t, msgLength: u16, affectFlags: u32, flags: u32, affectCtrls: u32, ctrls: u32, message: *xcb_xkb_string8_t) -> xcb_xkb_set_debugging_flags_cookie_t #c_call;
    set_debugging_flags_reply:                                             #type (c: *xcb_connection_t, cookie: xcb_xkb_set_debugging_flags_cookie_t, e: **xcb_generic_error_t) -> *xcb_xkb_set_debugging_flags_reply_t #c_call;
}

#scope_file

