X11_Lib :: struct #type_info_no_size_complaint {
    Display :: struct {}
    Visual :: struct {}
    XImage :: struct {}
    XGCValues :: struct {}
    GC :: *void;
    Depth :: struct {}

    XPointer :: *void;
    XID :: u64;
    Mask :: u64;
    Atom :: u64;
    VisualID :: u64;
    Time :: u64;
    Window :: XID;
    Drawable :: XID;
    Font :: XID;
    Pixmap :: XID;
    Cursor :: XID;
    Colormap :: XID;
    GContext :: XID;
    KeySym :: XID;
    KeyCode :: u8;
    XIM :: *void;
    XIC :: *void;

    XPoint :: struct {
        x: s16;
        y: s16;
    }

    XRectangle :: struct {
        x: s16;
        y: s16;
        width: u16;
        height: u16;
    }

    XColor :: struct {
        pixel: u64;
        red: u16;
        green: u16;
        blue: u16;
        flags: u8;
        pad: u8;
    }

    Screen :: struct {
        ext_data: *XExtData;
        display: *Display;
        root: Window;
        width: s32;
        height: s32;
        mwidth: s32;
        mheight: s32;
        ndepths: s32;
        depths: *Depth;
        root_depth: s32;
        root_visual: *Visual;
        default_gc: GC;
        cmap: Colormap;
        white_pixel: u64;
        black_pixel: u64;
        max_maps: s32;
        min_maps: s32;
        backing_store: s32;
        save_unders: s32;
        root_input_mask: s64;
    }

    Bool :: s32;
    Status :: s32;

    True :: 1;
    False :: 0;

    None :: 0;

    Success :: 0;
    BadRequest :: 1;
    BadValue :: 2;
    BadWindow :: 3;
    BadPixmap :: 4;
    BadAtom :: 5;
    BadCursor :: 6;
    BadFont :: 7;
    BadMatch :: 8;
    BadDrawable :: 9;
    BadAccess :: 10;
    BadAlloc :: 11;
    BadColor :: 12;
    BadGC :: 13;
    BadIDChoice :: 14;
    BadName :: 15;
    BadLength :: 16;
    BadImplementation :: 17;
    FirstExtensionError :: 128;
    LastExtensionError :: 255;

    InputHint        :: (1 << 0);
    StateHint        :: (1 << 1);
    IconPixmapHint   :: (1 << 2);
    IconWindowHint   :: (1 << 3);
    IconPositionHint :: (1 << 4);
    IconMaskHint     :: (1 << 5);
    WindowGroupHint  :: (1 << 6);
    AllHints         :: (InputHint|StateHint|IconPixmapHint|IconWindowHint|IconPositionHint|IconMaskHint|WindowGroupHint);
    XUrgencyHint     :: (1 << 8);

    PAllHints :: PPosition | PSize | PMinSize | PMaxSize | PResizeInc | PAspect;

    USPosition  :: (1 << 0);
    USSize      :: (1 << 1);
    PPosition   :: (1 << 2);
    PSize       :: (1 << 3);
    PMinSize    :: (1 << 4);
    PMaxSize    :: (1 << 5);
    PResizeInc  :: (1 << 6);
    PAspect     :: (1 << 7);
    PBaseSize   :: (1 << 8);
    PWinGravity :: (1 << 9);

    DoRed          :: (1 << 0);
    DoGreen        :: (1 << 1);
    DoBlue         :: (1 << 2);

    XYBitmap       :: 0;
    XYPixmap       :: 1;
    ZPixmap        :: 2;

    GCFunction          :: (1 << 0);
    GCPlaneMask         :: (1 << 1);
    GCForeground        :: (1 << 2);
    GCBackground        :: (1 << 3);
    GCLineWidth         :: (1 << 4);
    GCLineStyle         :: (1 << 5);
    GCCapStyle          :: (1 << 6);
    GCJoinStyle         :: (1 << 7);
    GCFillStyle         :: (1 << 8);
    GCFillRule          :: (1 << 9);
    GCTile              :: (1 << 10);
    GCStipple           :: (1 << 11);
    GCTileStipXOrigin   :: (1 << 12);
    GCTileStipYOrigin   :: (1 << 13);
    GCFont              :: (1 << 14);
    GCSubwindowMode     :: (1 << 15);
    GCGraphicsExposures :: (1 << 16);
    GCClipXOrigin       :: (1 << 17);
    GCClipYOrigin       :: (1 << 18);
    GCClipMask          :: (1 << 19);
    GCDashOffset        :: (1 << 20);
    GCDashList          :: (1 << 21);
    GCArcMode           :: (1 << 22);

    GCLastBit           :: 22;

    ParentRelative :: 1;
    CopyFromParent :: 0;
    PointerWindow :: 0;
    InputFocus :: 1;
    PointerRoot :: 1;
    AnyPropertyType :: 0;
    AnyKey :: 0;
    AnyButton :: 0;
    AllTemporary :: 0;
    CurrentTime :: 0;
    NoSymbol :: 0;

    GrabModeSync     :: 0;
    GrabModeAsync    :: 1;

    GrabSuccess      :: 0;
    AlreadyGrabbed   :: 1;
    GrabInvalidTime  :: 2;
    GrabNotViewable  :: 3;
    GrabFrozen       :: 4;

    PropModeReplace  :: 0;
    PropModePrepend  :: 1;
    PropModeAppend   :: 2;

    AllocNone :: 0;
    AllocAll  :: 1;

    // standard Atoms from Xatom
    XA_PRIMARY ::  1;
    XA_SECONDARY ::  2;
    XA_ARC ::  3;
    XA_ATOM ::  4;
    XA_BITMAP ::  5;
    XA_CARDINAL ::  6;
    XA_COLORMAP ::  7;
    XA_CURSOR ::  8;
    XA_CUT_BUFFER0 ::  9;
    XA_CUT_BUFFER1 ::  10;
    XA_CUT_BUFFER2 ::  11;
    XA_CUT_BUFFER3 ::  12;
    XA_CUT_BUFFER4 ::  13;
    XA_CUT_BUFFER5 ::  14;
    XA_CUT_BUFFER6 ::  15;
    XA_CUT_BUFFER7 ::  16;
    XA_DRAWABLE ::  17;
    XA_FONT ::  18;
    XA_INTEGER ::  19;
    XA_PIXMAP ::  20;
    XA_POINT ::  21;
    XA_RECTANGLE ::  22;
    XA_RESOURCE_MANAGER ::  23;
    XA_RGB_COLOR_MAP ::  24;
    XA_RGB_BEST_MAP ::  25;
    XA_RGB_BLUE_MAP ::  26;
    XA_RGB_DEFAULT_MAP ::  27;
    XA_RGB_GRAY_MAP ::  28;
    XA_RGB_GREEN_MAP ::  29;
    XA_RGB_RED_MAP ::  30;
    XA_STRING ::  31;
    XA_VISUALID ::  32;
    XA_WINDOW ::  33;
    XA_WM_COMMAND ::  34;
    XA_WM_HINTS ::  35;
    XA_WM_CLIENT_MACHINE ::  36;
    XA_WM_ICON_NAME ::  37;
    XA_WM_ICON_SIZE ::  38;
    XA_WM_NAME ::  39;
    XA_WM_NORMAL_HINTS ::  40;
    XA_WM_SIZE_HINTS ::  41;
    XA_WM_ZOOM_HINTS ::  42;
    XA_MIN_SPACE ::  43;
    XA_NORM_SPACE ::  44;
    XA_MAX_SPACE ::  45;
    XA_END_SPACE ::  46;
    XA_SUPERSCRIPT_X ::  47;
    XA_SUPERSCRIPT_Y ::  48;
    XA_SUBSCRIPT_X ::  49;
    XA_SUBSCRIPT_Y ::  50;
    XA_UNDERLINE_POSITION ::  51;
    XA_UNDERLINE_THICKNESS ::  52;
    XA_STRIKEOUT_ASCENT ::  53;
    XA_STRIKEOUT_DESCENT ::  54;
    XA_ITALIC_ANGLE ::  55;
    XA_X_HEIGHT ::  56;
    XA_QUAD_WIDTH ::  57;
    XA_WEIGHT ::  58;
    XA_POINT_SIZE ::  59;
    XA_RESOLUTION ::  60;
    XA_COPYRIGHT ::  61;
    XA_NOTICE ::  62;
    XA_FONT_NAME ::  63;
    XA_FAMILY_NAME ::  64;
    XA_FULL_NAME ::  65;
    XA_CAP_HEIGHT ::  66;
    XA_WM_CLASS ::  67;
    XA_WM_TRANSIENT_FOR ::  68;

    QueuedAlready      :: 0;
    QueuedAfterReading :: 1;
    QueuedAfterFlush   :: 2;

    NoEventMask              :: 0;
    KeyPressMask             :: (1 << 0);
    KeyReleaseMask           :: (1 << 1);
    ButtonPressMask          :: (1 << 2);
    ButtonReleaseMask        :: (1 << 3);
    EnterWindowMask          :: (1 << 4);
    LeaveWindowMask          :: (1 << 5);
    PointerMotionMask        :: (1 << 6);
    PointerMotionHintMask    :: (1 << 7);
    Button1MotionMask        :: (1 << 8);
    Button2MotionMask        :: (1 << 9);
    Button3MotionMask        :: (1 << 10);
    Button4MotionMask        :: (1 << 11);
    Button5MotionMask        :: (1 << 12);
    ButtonMotionMask         :: (1 << 13);
    KeymapStateMask          :: (1 << 14);
    ExposureMask             :: (1 << 15);
    VisibilityChangeMask     :: (1 << 16);
    StructureNotifyMask      :: (1 << 17);
    ResizeRedirectMask       :: (1 << 18);
    SubstructureNotifyMask   :: (1 << 19);
    SubstructureRedirectMask :: (1 << 20);
    FocusChangeMask          :: (1 << 21);
    PropertyChangeMask       :: (1 << 22);
    ColormapChangeMask       :: (1 << 23);
    OwnerGrabButtonMask      :: (1 << 24);

    KeyPress            :: 2;
    KeyRelease          :: 3;
    ButtonPress         :: 4;
    ButtonRelease       :: 5;
    MotionNotify        :: 6;
    EnterNotify         :: 7;
    LeaveNotify         :: 8;
    FocusIn             :: 9;
    FocusOut            :: 10;
    KeymapNotify        :: 11;
    Expose              :: 12;
    GraphicsExpose      :: 13;
    NoExpose            :: 14;
    VisibilityNotify    :: 15;
    CreateNotify        :: 16;
    DestroyNotify       :: 17;
    UnmapNotify         :: 18;
    MapNotify           :: 19;
    MapRequest          :: 20;
    ReparentNotify      :: 21;
    ConfigureNotify     :: 22;
    ConfigureRequest    :: 23;
    GravityNotify       :: 24;
    ResizeRequest       :: 25;
    CirculateNotify     :: 26;
    CirculateRequest    :: 27;
    PropertyNotify      :: 28;
    SelectionClear      :: 29;
    SelectionRequest    :: 30;
    SelectionNotify     :: 31;
    ColormapNotify      :: 32;
    ClientMessage       :: 33;
    MappingNotify       :: 34;
    GenericEvent        :: 35;

    Button1       :: 1;
    Button2       :: 2;
    Button3       :: 3;
    Button4       :: 4;
    Button5       :: 5;

    InputOutput :: 1;
    InputOnly   :: 2;

    CWEventMask :: (1 << 11);
    CWColormap  :: (1 << 13);

    ShiftMask      :: (1 << 0);
    LockMask       :: (1 << 1);
    ControlMask    :: (1 << 2);
    Mod1Mask       :: (1 << 3);
    Mod2Mask       :: (1 << 4);
    Mod3Mask       :: (1 << 5);
    Mod4Mask       :: (1 << 6);
    Mod5Mask       :: (1 << 7);

    Button1Mask    :: (1 << 8);
    Button2Mask    :: (1 << 9);
    Button3Mask    :: (1 << 10);
    Button4Mask    :: (1 << 11);
    Button5Mask    :: (1 << 12);

    _NET_WM_STATE_REMOVE :: 0;
    _NET_WM_STATE_ADD    :: 1;
    _NET_WM_STATE_TOGGLE :: 2;

    XIMPreeditArea      :: 0x0001;
    XIMPreeditCallbacks :: 0x0002;
    XIMPreeditPosition  :: 0x0004;
    XIMPreeditNothing   :: 0x0008;
    XIMPreeditNone      :: 0x0010;
    XIMStatusArea       :: 0x0100;
    XIMStatusCallbacks  :: 0x0200;
    XIMStatusNothing    :: 0x0400;
    XIMStatusNone       :: 0x0800;

    XNClientWindow :: "clientWindow".data;
    XNFocusWindow :: "focusWindow".data;
    XNInputStyle :: "inputStyle".data;

    XBufferOverflow :: -1;
    XLookupNone     ::  1;
    XLookupChars    ::  2;
    XLookupKeySym   ::  3;
    XLookupBoth     ::  4;

    StaticGray  :: 0;
    GrayScale   :: 1;
    StaticColor :: 2;
    PseudoColor :: 3;
    TrueColor   :: 4;
    DirectColor :: 5;

    using Known_Keysyms :: enum KeySym {
        XK_ISO_Left_Tab            ::  0xfe20;

        XK_BackSpace               ::  0xff08;
        XK_Tab                     ::  0xff09;
        XK_Linefeed                ::  0xff0a;
        XK_Clear                   ::  0xff0b;
        XK_Return                  ::  0xff0d;
        XK_Pause                   ::  0xff13;
        XK_Scroll_Lock             ::  0xff14;
        XK_Sys_Req                 ::  0xff15;
        XK_Escape                  ::  0xff1b;
        XK_Delete                  ::  0xffff;

        XK_Home                    ::  0xff50;
        XK_Left                    ::  0xff51;
        XK_Up                      ::  0xff52;
        XK_Right                   ::  0xff53;
        XK_Down                    ::  0xff54;
        XK_Prior                   ::  0xff55;
        XK_Page_Up                 ::  0xff55;
        XK_Next                    ::  0xff56;
        XK_Page_Down               ::  0xff56;
        XK_End                     ::  0xff57;
        XK_Begin                   ::  0xff58;

        XK_F1                      ::  0xffbe;
        XK_F2                      ::  0xffbf;
        XK_F3                      ::  0xffc0;
        XK_F4                      ::  0xffc1;
        XK_F5                      ::  0xffc2;
        XK_F6                      ::  0xffc3;
        XK_F7                      ::  0xffc4;
        XK_F8                      ::  0xffc5;
        XK_F9                      ::  0xffc6;
        XK_F10                     ::  0xffc7;
        XK_F11                     ::  0xffc8;
        XK_L1                      ::  0xffc8;
        XK_F12                     ::  0xffc9;
        XK_L2                      ::  0xffc9;
        XK_F13                     ::  0xffca;
        XK_L3                      ::  0xffca;
        XK_F14                     ::  0xffcb;
        XK_L4                      ::  0xffcb;
        XK_F15                     ::  0xffcc;
        XK_L5                      ::  0xffcc;
        XK_F16                     ::  0xffcd;
        XK_L6                      ::  0xffcd;
        XK_F17                     ::  0xffce;
        XK_L7                      ::  0xffce;
        XK_F18                     ::  0xffcf;
        XK_L8                      ::  0xffcf;
        XK_F19                     ::  0xffd0;
        XK_L9                      ::  0xffd0;
        XK_F20                     ::  0xffd1;
        XK_L10                     ::  0xffd1;
        XK_F21                     ::  0xffd2;
        XK_R1                      ::  0xffd2;
        XK_F22                     ::  0xffd3;
        XK_R2                      ::  0xffd3;
        XK_F23                     ::  0xffd4;
        XK_R3                      ::  0xffd4;
        XK_F24                     ::  0xffd5;
        XK_R4                      ::  0xffd5;
        XK_F25                     ::  0xffd6;
        XK_R5                      ::  0xffd6;
        XK_F26                     ::  0xffd7;
        XK_R6                      ::  0xffd7;
        XK_F27                     ::  0xffd8;
        XK_R7                      ::  0xffd8;
        XK_F28                     ::  0xffd9;
        XK_R8                      ::  0xffd9;
        XK_F29                     ::  0xffda;
        XK_R9                      ::  0xffda;
        XK_F30                     ::  0xffdb;
        XK_R10                     ::  0xffdb;
        XK_F31                     ::  0xffdc;
        XK_R11                     ::  0xffdc;
        XK_F32                     ::  0xffdd;
        XK_R12                     ::  0xffdd;
        XK_F33                     ::  0xffde;
        XK_R13                     ::  0xffde;
        XK_F34                     ::  0xffdf;
        XK_R14                     ::  0xffdf;
        XK_F35                     ::  0xffe0;
        XK_R15                     ::  0xffe0;


        XK_Shift_L                 ::  0xffe1;
        XK_Shift_R                 ::  0xffe2;
        XK_Control_L               ::  0xffe3;
        XK_Control_R               ::  0xffe4;
        XK_Caps_Lock               ::  0xffe5;
        XK_Shift_Lock              ::  0xffe6;

        XK_Meta_L                  ::  0xffe7;
        XK_Meta_R                  ::  0xffe8;
        XK_Alt_L                   ::  0xffe9;
        XK_Alt_R                   ::  0xffea;
        XK_Super_L                 ::  0xffeb;
        XK_Super_R                 ::  0xffec;
        XK_Hyper_L                 ::  0xffed;
        XK_Hyper_R                 ::  0xffee;

        XK_space                   ::  0x0020;
        XK_exclam                  ::  0x0021;
        XK_quotedbl                ::  0x0022;
        XK_numbersign              ::  0x0023;
        XK_dollar                  ::  0x0024;
        XK_percent                 ::  0x0025;
        XK_ampersand               ::  0x0026;
        XK_apostrophe              ::  0x0027;
        XK_quoteright              ::  0x0027;
        XK_parenleft               ::  0x0028;
        XK_parenright              ::  0x0029;
        XK_asterisk                ::  0x002a;
        XK_plus                    ::  0x002b;
        XK_comma                   ::  0x002c;
        XK_minus                   ::  0x002d;
        XK_period                  ::  0x002e;
        XK_slash                   ::  0x002f;
        XK_0                       ::  0x0030;
        XK_1                       ::  0x0031;
        XK_2                       ::  0x0032;
        XK_3                       ::  0x0033;
        XK_4                       ::  0x0034;
        XK_5                       ::  0x0035;
        XK_6                       ::  0x0036;
        XK_7                       ::  0x0037;
        XK_8                       ::  0x0038;
        XK_9                       ::  0x0039;
        XK_colon                   ::  0x003a;
        XK_semicolon               ::  0x003b;
        XK_less                    ::  0x003c;
        XK_equal                   ::  0x003d;
        XK_greater                 ::  0x003e;
        XK_question                ::  0x003f;
        XK_at                      ::  0x0040;
        XK_A                       ::  0x0041;
        XK_B                       ::  0x0042;
        XK_C                       ::  0x0043;
        XK_D                       ::  0x0044;
        XK_E                       ::  0x0045;
        XK_F                       ::  0x0046;
        XK_G                       ::  0x0047;
        XK_H                       ::  0x0048;
        XK_I                       ::  0x0049;
        XK_J                       ::  0x004a;
        XK_K                       ::  0x004b;
        XK_L                       ::  0x004c;
        XK_M                       ::  0x004d;
        XK_N                       ::  0x004e;
        XK_O                       ::  0x004f;
        XK_P                       ::  0x0050;
        XK_Q                       ::  0x0051;
        XK_R                       ::  0x0052;
        XK_S                       ::  0x0053;
        XK_T                       ::  0x0054;
        XK_U                       ::  0x0055;
        XK_V                       ::  0x0056;
        XK_W                       ::  0x0057;
        XK_X                       ::  0x0058;
        XK_Y                       ::  0x0059;
        XK_Z                       ::  0x005a;
        XK_bracketleft             ::  0x005b;
        XK_backslash               ::  0x005c;
        XK_bracketright            ::  0x005d;
        XK_asciicircum             ::  0x005e;
        XK_underscore              ::  0x005f;
        XK_grave                   ::  0x0060;
        XK_quoteleft               ::  0x0060;
        XK_a                       ::  0x0061;
        XK_b                       ::  0x0062;
        XK_c                       ::  0x0063;
        XK_d                       ::  0x0064;
        XK_e                       ::  0x0065;
        XK_f                       ::  0x0066;
        XK_g                       ::  0x0067;
        XK_h                       ::  0x0068;
        XK_i                       ::  0x0069;
        XK_j                       ::  0x006a;
        XK_k                       ::  0x006b;
        XK_l                       ::  0x006c;
        XK_m                       ::  0x006d;
        XK_n                       ::  0x006e;
        XK_o                       ::  0x006f;
        XK_p                       ::  0x0070;
        XK_q                       ::  0x0071;
        XK_r                       ::  0x0072;
        XK_s                       ::  0x0073;
        XK_t                       ::  0x0074;
        XK_u                       ::  0x0075;
        XK_v                       ::  0x0076;
        XK_w                       ::  0x0077;
        XK_x                       ::  0x0078;
        XK_y                       ::  0x0079;
        XK_z                       ::  0x007a;
        XK_braceleft               ::  0x007b;
        XK_bar                     ::  0x007c;
        XK_braceright              ::  0x007d;
        XK_asciitilde              ::  0x007e;

        XK_Insert                  ::  0xff63;

        XK_KP_Space                ::  0xff80;
        XK_KP_Tab                  ::  0xff89;
        XK_KP_Enter                ::  0xff8d;
        XK_KP_F1                   ::  0xff91;
        XK_KP_F2                   ::  0xff92;
        XK_KP_F3                   ::  0xff93;
        XK_KP_F4                   ::  0xff94;
        XK_KP_Home                 ::  0xff95;
        XK_KP_Left                 ::  0xff96;
        XK_KP_Up                   ::  0xff97;
        XK_KP_Right                ::  0xff98;
        XK_KP_Down                 ::  0xff99;
        XK_KP_Prior                ::  0xff9a;
        XK_KP_Page_Up              ::  0xff9a;
        XK_KP_Next                 ::  0xff9b;
        XK_KP_Page_Down            ::  0xff9b;
        XK_KP_End                  ::  0xff9c;
        XK_KP_Begin                ::  0xff9d;
        XK_KP_Insert               ::  0xff9e;
        XK_KP_Delete               ::  0xff9f;
        XK_KP_Equal                ::  0xffbd;
        XK_KP_Multiply             ::  0xffaa;
        XK_KP_Add                  ::  0xffab;
        XK_KP_Separator            ::  0xffac;
        XK_KP_Subtract             ::  0xffad;
        XK_KP_Decimal              ::  0xffae;
        XK_KP_Divide               ::  0xffaf;
        XK_KP_0                    ::  0xffb0;
        XK_KP_1                    ::  0xffb1;
        XK_KP_2                    ::  0xffb2;
        XK_KP_3                    ::  0xffb3;
        XK_KP_4                    ::  0xffb4;
        XK_KP_5                    ::  0xffb5;
        XK_KP_6                    ::  0xffb6;
        XK_KP_7                    ::  0xffb7;
        XK_KP_8                    ::  0xffb8;
        XK_KP_9                    ::  0xffb9;

        XK_ISO_Level3_Shift        ::  0xfe03;
    }

    XTextProperty :: struct {
        value: *u8;
        encoding: Atom;
        format: s32;
        nitems: u64;
    }

    XWMHints :: struct {
        flags: s64;
        input: s32;
        initial_state: s32;
        icon_pixmap: Pixmap;
        icon_window: Window;
        icon_x: s32;
        icon_y: s32;
        icon_mask: Pixmap;
        window_group: XID;
    }

    XClassHint :: struct {
        res_name: *u8;
        res_class: *u8;
    }
    _XrmHashBucketRec :: struct {}

    _XPrivate :: struct {}
    XExtData :: struct {};
    ScreenFormat :: struct {};

    _XPrivDisplay :: struct {
        ext_data: *XExtData;
        private1: *_XPrivate;
        fd: s32;
        private2: s32;
        proto_major_version: s32;
        proto_minor_version: s32;
        vendor: *u8;
        private3: XID;
        private4: XID;
        private5: XID;
        private6: s32;
        resource_alloc: #type (a0: *Display) -> XID #c_call;
        byte_order: s32;
        bitmap_unit: s32;
        bitmap_pad: s32;
        bitmap_bit_order: s32;
        nformats: s32;
        pixmap_format: *ScreenFormat;
        private8: s32;
        release: s32;
        private9: *_XPrivate;
        private10: *_XPrivate;
        qlen: s32;
        last_request_read: u64;
        request: u64;
        private11: XPointer;
        private12: XPointer;
        private13: XPointer;
        private14: XPointer;
        max_request_size: u32;
        db: *_XrmHashBucketRec;
        private15: #type (a0: *Display) -> s32 #c_call;
        display_name: *u8;
        default_screen: s32;
        nscreens: s32;
        screens: *Screen;
        motion_buffer: u64;
        private16: u64;
        min_keycode: s32;
        max_keycode: s32;
        private17: XPointer;
        private18: XPointer;
        private19: s32;
        xdefaults: *u8;
    }

    XSetWindowAttributes :: struct {
        background_pixmap: Pixmap;
        background_pixel: u64;
        border_pixmap: Pixmap;
        border_pixel: u64;
        bit_gravity: s32;
        win_gravity: s32;
        backing_store: s32;
        backing_planes: u64;
        backing_pixel: u64;
        save_under: s32;
        event_mask: s64;
        do_not_propagate_mask: s64;
        override_redirect: s32;
        colormap: Colormap;
        cursor: Cursor;
    }

    XWindowAttributes :: struct {
        x: s32;
        y: s32;
        width: s32;
        height: s32;
        border_width: s32;
        depth: s32;
        visual: *Visual;
        root: Window;
        class: s32;
        bit_gravity: s32;
        win_gravity: s32;
        backing_store: s32;
        backing_planes: u64;
        backing_pixel: u64;
        save_under: s32;
        colormap: Colormap;
        map_installed: s32;
        map_state: s32;
        all_event_masks: s64;
        your_event_mask: s64;
        do_not_propagate_mask: s64;
        override_redirect: s32;
        screen: *Screen;
    }

    XVisualInfo :: struct {
        visual: *Visual;
        visualid: VisualID;
        screen: s32;
        depth: s32;
        class: s32;
        red_mask: u64;
        green_mask: u64;
        blue_mask: u64;
        colormap_size: s32;
        bits_per_rgb: s32;
    }

    XStandardColormap :: struct {
        colormap: Colormap;
        red_max: u64;
        red_mult: u64;
        green_max: u64;
        green_mult: u64;
        blue_max: u64;
        blue_mult: u64;
        base_pixel: u64;
        visualid: VisualID;
        killid: XID;
    }

    XKeyEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
        root: Window;
        subwindow: Window;
        time: Time;
        x: s32;
        y: s32;
        x_root: s32;
        y_root: s32;
        state: u32;
        keycode: u32;
        same_screen: s32;
    }

    XKeyPressedEvent :: XKeyEvent;

    XKeyReleasedEvent :: XKeyEvent;

    XButtonEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
        root: Window;
        subwindow: Window;
        time: Time;
        x: s32;
        y: s32;
        x_root: s32;
        y_root: s32;
        state: u32;
        button: u32;
        same_screen: s32;
    }

    XButtonPressedEvent :: XButtonEvent;

    XButtonReleasedEvent :: XButtonEvent;

    XMotionEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
        root: Window;
        subwindow: Window;
        time: Time;
        x: s32;
        y: s32;
        x_root: s32;
        y_root: s32;
        state: u32;
        is_hint: u8;
        same_screen: s32;
    }

    XPointerMovedEvent :: XMotionEvent;

    XCrossingEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
        root: Window;
        subwindow: Window;
        time: Time;
        x: s32;
        y: s32;
        x_root: s32;
        y_root: s32;
        mode: s32;
        detail: s32;
        same_screen: s32;
        focus: s32;
        state: u32;
    }

    XEnterWindowEvent :: XCrossingEvent;

    XLeaveWindowEvent :: XCrossingEvent;

    XFocusChangeEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
        mode: s32;
        detail: s32;
    }

    XFocusInEvent :: XFocusChangeEvent;

    XFocusOutEvent :: XFocusChangeEvent;

    XKeymapEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
        key_vector: [32] u8;
    }

    XExposeEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
        x: s32;
        y: s32;
        width: s32;
        height: s32;
        count: s32;
    }

    XGraphicsExposeEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        drawable: Drawable;
        x: s32;
        y: s32;
        width: s32;
        height: s32;
        count: s32;
        major_code: s32;
        minor_code: s32;
    }

    XNoExposeEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        drawable: Drawable;
        major_code: s32;
        minor_code: s32;
    }

    XVisibilityEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
        state: s32;
    }

    XCreateWindowEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        parent: Window;
        window: Window;
        x: s32;
        y: s32;
        width: s32;
        height: s32;
        border_width: s32;
        override_redirect: s32;
    }

    XDestroyWindowEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        event: Window;
        window: Window;
    }

    XUnmapEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        event: Window;
        window: Window;
        from_configure: s32;
    }

    XMapEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        event: Window;
        window: Window;
        override_redirect: s32;
    }

    XMapRequestEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        parent: Window;
        window: Window;
    }

    XReparentEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        event: Window;
        window: Window;
        parent: Window;
        x: s32;
        y: s32;
        override_redirect: s32;
    }

    XConfigureEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        event: Window;
        window: Window;
        x: s32;
        y: s32;
        width: s32;
        height: s32;
        border_width: s32;
        above: Window;
        override_redirect: s32;
    }

    XGravityEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        event: Window;
        window: Window;
        x: s32;
        y: s32;
    }

    XResizeRequestEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
        width: s32;
        height: s32;
    }

    XConfigureRequestEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        parent: Window;
        window: Window;
        x: s32;
        y: s32;
        width: s32;
        height: s32;
        border_width: s32;
        above: Window;
        detail: s32;
        value_mask: u64;
    }

    XCirculateEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        event: Window;
        window: Window;
        place: s32;
    }

    XCirculateRequestEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        parent: Window;
        window: Window;
        place: s32;
    }

    XPropertyEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
        atom: Atom;
        time: Time;
        state: s32;
    }

    XSelectionClearEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
        selection: Atom;
        time: Time;
    }

    XSelectionRequestEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        owner: Window;
        requestor: Window;
        selection: Atom;
        target: Atom;
        property: Atom;
        time: Time;
    }

    XSelectionEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        requestor: Window;
        selection: Atom;
        target: Atom;
        property: Atom;
        time: Time;
    }

    XColormapEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
        colormap: Colormap;
        new: s32;
        state: s32;
    }

    XClientMessageEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
        message_type: Atom;
        format: s32;
        data: union {
            b: [20] u8;
            s: [10] s16;
            l: [5] s64;
        };
    }

    XMappingEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
        request: s32;
        first_keycode: s32;
        count: s32;
    }

    XErrorEvent :: struct {
        type: s32;
        display: *Display;
        resourceid: XID;
        serial: u64;
        error_code: u8;
        request_code: u8;
        minor_code: u8;
    }

    XAnyEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        window: Window;
    }

    XGenericEvent :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        extension: s32;
        evtype: s32;
    }

    XGenericEventCookie :: struct {
        type: s32;
        serial: u64;
        send_event: s32;
        display: *Display;
        extension: s32;
        evtype: s32;
        cookie: u32;
        data: *void;
    }

    _XEvent :: union {
        type: s32;
        xany: XAnyEvent;
        xkey: XKeyEvent;
        xbutton: XButtonEvent;
        xmotion: XMotionEvent;
        xcrossing: XCrossingEvent;
        xfocus: XFocusChangeEvent;
        xexpose: XExposeEvent;
        xgraphicsexpose: XGraphicsExposeEvent;
        xnoexpose: XNoExposeEvent;
        xvisibility: XVisibilityEvent;
        xcreatewindow: XCreateWindowEvent;
        xdestroywindow: XDestroyWindowEvent;
        xunmap: XUnmapEvent;
        xmap: XMapEvent;
        xmaprequest: XMapRequestEvent;
        xreparent: XReparentEvent;
        xconfigure: XConfigureEvent;
        xgravity: XGravityEvent;
        xresizerequest: XResizeRequestEvent;
        xconfigurerequest: XConfigureRequestEvent;
        xcirculate: XCirculateEvent;
        xcirculaterequest: XCirculateRequestEvent;
        xproperty: XPropertyEvent;
        xselectionclear: XSelectionClearEvent;
        xselectionrequest: XSelectionRequestEvent;
        xselection: XSelectionEvent;
        xcolormap: XColormapEvent;
        xclient: XClientMessageEvent;
        xmapping: XMappingEvent;
        xerror: XErrorEvent;
        xkeymap: XKeymapEvent;
        xgeneric: XGenericEvent;
        xcookie: XGenericEventCookie;
        pad: [24] s64;
    }

    XEvent :: _XEvent;

    XSizeHints :: struct {
        flags: s64;     /* marks which fields in this structure are defined */
        x, y: s32;               /* obsolete for new window mgrs, but clients */
        width, height: s32;      /* should set so old wm's don't mess up */
        min_width, min_height: s32;
        max_width, max_height: s32;
        width_inc, height_inc: s32;
        min_aspect, max_aspect: struct {
            x: s32;  /* numerator */
            y: s32;  /* denominator */
        };
        base_width, base_height: s32;            /* added by ICCCM version 1 */
        win_gravity: s32;                        /* added by ICCCM version 1 */
    }

    XEventQueueOwner :: enum {
        Xlib :: 0;
        XCB  :: 1;
    }

    Global_Atoms :: struct {
        XdndEnter                       : Atom; @opts(must_exist=false)
        XdndPosition                    : Atom; @opts(must_exist=false)
        XdndStatus                      : Atom; @opts(must_exist=false)
        XdndTypeList                    : Atom; @opts(must_exist=false)
        XdndAware                       : Atom; @opts(must_exist=false)
        XdndActionMove                  : Atom; @opts(must_exist=false)
        XdndActionLink                  : Atom; @opts(must_exist=false)
        XdndActionCopy                  : Atom; @opts(must_exist=false)
        XdndDrop                        : Atom; @opts(must_exist=false)
        XdndLeave                       : Atom; @opts(must_exist=false)
        XdndFinished                    : Atom; @opts(must_exist=false)
        XdndSelection                   : Atom; @opts(must_exist=false)
        XdndProxy                       : Atom; @opts(must_exist=false)

        ATOM                            : Atom;
        CLIPBOARD                       : Atom;
        UTF8_STRING                     : Atom;
        XSEL_DATA                       : Atom;
        TARGETS                         : Atom;
        MULTIPLE                        : Atom;
        TEXT_PLAIN                      : Atom;
        WM_DELETE_WINDOW                : Atom;
        WM_PROTOCOLS                    : Atom;
        MOTIF_WM_HINTS                  : Atom;
        NET_WM_NAME                     : Atom;
        NET_WM_ICON_NAME                : Atom;
        NET_WM_STATE                    : Atom;
        NET_WM_STATE_FULLSCREEN         : Atom;
        WM_NAME                         : Atom;
        WM_ICON_NAME                    : Atom;

        _NET_WM_STATE                   : Atom;
        _NET_WM_STATE_DEMANDS_ATTENTION : Atom;
        _NET_WM_STATE_FULLSCREEN        : Atom;
        _NET_WM_STATE_MAXIMIZED_HORZ    : Atom;
        _NET_WM_STATE_MAXIMIZED_VERT    : Atom;
        _NET_WM_ICON                    : Atom;
        _NET_WM_NAME                    : Atom;
        _NET_WM_ICON_NAME               : Atom;

        _DUMMY : Atom; @opts(actual_name=JXSelectionWindowProperty)
    }

    Xdnd_Stage :: enum {
        DROP_IDLE       :: 0;
        DROP_CONVERTING :: 1;
        DROP_ENTERED    :: 2;
    }

    XDND_VERSION :: 5;   // I dunno, some version.

    Xdnd_Context :: struct {
        stage := Xdnd_Stage.DROP_IDLE;

        dragging_version := 0;
        dragger_typelist: [..] Atom;
        dragger_window: Window;

        want_position := false;
        will_accept := false;

        rectangle: XRectangle;
        dropper_window: Window;
        dropper_toplevel: Window;
        root_window: Window;
        supported_action: Atom;
        desired_type: Atom;
        x: s32;
        y: s32;
        time: Time;
    }

    Drop_Info :: struct {
        data: [..] u8;
        x: int;
        y: int;

        return_type: Atom;
        return_action: Atom;

        user_typelist: [..] Atom;
        user_actions:  [..] Atom;
    }

    xdnd_context_reset :: (dnd: *Xdnd_Context) {
        dnd.stage = Xdnd_Stage.DROP_IDLE;
        dnd.dragging_version = 0;
        dnd.want_position = false;
        dnd.will_accept = false;
        dnd.rectangle.x = 0;
        dnd.rectangle.y = 0;
        dnd.rectangle.width = 0;
        dnd.rectangle.height = 0;
        dnd.dropper_window = 0;
        dnd.dragger_window = 0;
        dnd.desired_type = 0;
        array_reset(*dnd.dragger_typelist);
    }

    Procs :: struct {
        XAllocClassHint: () -> *XClassHint #c_call;
        XAllocColor: (unk0: *Display, unk1: Colormap, unk2: *XColor) -> s32 #c_call;
        XAllocWMHints: () -> *XWMHints #c_call;
        XChangeProperty: (unk0: *Display, unk1: Window, unk2: Atom, unk3: Atom, unk4: s32, unk5: s32, unk6: *u8, unk7: s32) -> s32 #c_call;
        XCheckIfEvent: (unk0: *Display, unk1: *XEvent, unk2: #type (a0: *Display, a1: *XEvent, a2: XPointer) -> s32 #c_call, unk3: XPointer) -> s32 #c_call;
        XCheckMaskEvent: (unk0: *Display, unk1: s64, unk2: *XEvent) -> s32 #c_call;
        XConnectionNumber: (unk0: *Display) -> s32 #c_call;
        XConvertSelection: (unk0: *Display, unk1: Atom, unk2: Atom, unk3: Atom, unk4: Window, unk5: Time) -> s32 #c_call;
        XCreateColormap: (unk0: *Display, unk1: Window, unk2: *Visual, unk3: s32) -> Colormap #c_call;
        XCreateGC: (unk0: *Display, unk1: Drawable, unk2: u64, unk3: *XGCValues) -> GC #c_call;
        XCreateIC: (unk0: XIM, __args: ..Any) -> XIC #c_call;
        XCreateImage: (unk0: *Display, unk1: *Visual, unk2: u32, unk3: s32, unk4: s32, unk5: *u8, unk6: u32, unk7: u32, unk8: s32, unk9: s32) -> *XImage #c_call;
        XCreatePixmap: (unk0: *Display, unk1: Drawable, unk2: u32, unk3: u32, unk4: u32) -> Pixmap #c_call;
        XCreateWindow: (unk0: *Display, unk1: Window, unk2: s32, unk3: s32, unk4: u32, unk5: u32, unk6: u32, unk7: s32, unk8: u32, unk9: *Visual, unk10: u64, unk11: *XSetWindowAttributes) -> Window #c_call;
        XDefaultVisual: (unk0: *Display, unk1: s32) -> *Visual #c_call;
        XDefineCursor: (unk0: *Display, unk1: Window, unk2: Cursor) -> s32 #c_call;
        XDeleteProperty: (unk0: *Display, unk1: Window, unk2: Atom) -> s32 #c_call;
        XDestroyImage: (img: *XImage) #c_call;
        XDestroyWindow: (dpy: *Display, win: Window) #c_call;
        XEventsQueued: (unk0: *Display, unk1: s32) -> s32 #c_call;
        XFilterEvent: (unk0: *XEvent, unk1: Window) -> s32 #c_call;
        XFlush: (unk0: *Display) -> s32 #c_call;
        XFree: (unk0: *void) -> s32 #c_call;
        XFreeGC: (unk0: *Display, gc: GC) -> s32 #c_call;
        XGetAtomName: (unk0: *Display, unk1: Atom) -> *u8 #c_call;
        XGetGeometry: (unk0: *Display, unk1: Drawable, unk2: *Window, unk3: *s32, unk4: *s32, unk5: *u32, unk6: *u32, unk7: *u32, unk8: *u32) -> s32 #c_call;
        XGetInputFocus: (unk0: *Display, unk1: *Window, unk2: *s32) -> s32 #c_call;
        XGetSelectionOwner: (unk0: *Display, unk1: Atom) -> Window #c_call;
        XGetWindowAttributes: (unk0: *Display, unk1: Window, unk2: *XWindowAttributes) -> s32 #c_call;
        XGetWindowProperty: (unk0: *Display, unk1: Window, unk2: Atom, unk3: s64, unk4: s64, unk5: s32, unk6: Atom, unk7: *Atom, unk8: *s32, unk9: *u64, unk10: *u64, unk11: **u8) -> s32 #c_call;
        XIfEvent: (unk0: *Display, unk1: *XEvent, unk2: #type (a0: *Display, a1: *XEvent, a2: XPointer) -> s32 #c_call, unk3: XPointer) -> s32 #c_call;
        XInternAtom: (unk0: *Display, unk1: *u8, unk2: s32) -> Atom #c_call;
        XInternAtoms: (unk0: *Display, unk1: **u8, unk2: s32, unk3: s32, unk4: *Atom) -> s32 #c_call;
        XLockDisplay: (unk0: *Display) -> void #c_call;
        XLookupKeysym: (unk0: *XKeyEvent, unk1: s32) -> KeySym #c_call;
        XMapWindow: (unk0: *Display, unk1: Window) -> s32 #c_call;
        XMatchVisualInfo: (dpy: *Display, screen: s32, depth: s32, class: s32, ret: *XVisualInfo) -> Status #c_call;
        XNextEvent: (unk0: *Display, unk1: *XEvent) -> s32 #c_call;
        XOpenDisplay: (unk0: *u8) -> *Display #c_call;
        XOpenIM: (unk0: *Display, unk1: *_XrmHashBucketRec, unk2: *u8, unk3: *u8) -> XIM #c_call;
        XPeekEvent: (unk0: *Display, unk1: *XEvent) -> s32 #c_call;
        XPending: (unk0: *Display) -> s32 #c_call;
        XPutImage: (unk0: *Display, unk1: Drawable, unk2: GC, unk3: *XImage, unk4: s32, unk5: s32, unk6: s32, unk7: s32, unk8: u32, unk9: u32) -> s32 #c_call;
        XQLength: (unk0: *Display) -> s32 #c_call;
        XQueryPointer: (unk0: *Display, unk1: Window, unk2: *Window, unk3: *Window, unk4: *s32, unk5: *s32, unk6: *s32, unk7: *s32, unk8: *u32) -> s32 #c_call;
        XQueryTree: (unk0: *Display, unk1: Window, unk2: *Window, unk3: *Window, unk4: **Window, unk5: *u32) -> s32 #c_call;
        XScreenOfDisplay: (unk0: *Display, unk1: s32) -> *Screen #c_call;
        XSendEvent: (unk0: *Display, unk1: Window, unk2: s32, unk3: s64, unk4: *XEvent) -> s32 #c_call;
        XSetClassHint: (unk0: *Display, unk1: Window, unk2: *XClassHint) -> s32 #c_call;
        XSetICFocus: (unk0: XIC) -> void #c_call;
        XSetLocaleModifiers: (unk0: *u8) -> *u8 #c_call;
        XSetSelectionOwner: (unk0: *Display, unk1: Atom, unk2: Window, unk3: Time) -> s32 #c_call;
        XSetTextProperty: (dpy: *Display, w: Window, prop_text: *XTextProperty, prop: Atom) #c_call;
        XSetWMHints: (unk0: *Display, unk1: Window, unk2: *XWMHints) -> s32 #c_call;
        XSetWMIconName: (unk0: *Display, unk1: Window, unk2: *XTextProperty) -> void #c_call;
        XSetWMName: (unk0: *Display, unk1: Window, unk2: *XTextProperty) -> void #c_call;
        XSetWMProtocols: (unk0: *Display, unk1: Window, unk2: *Atom, unk3: s32) -> s32 #c_call;
        XStoreName: (unk0: *Display, unk1: Window, unk2: *u8) -> s32 #c_call;
        XSupportsLocale: () -> s32 #c_call;
        XSync: (unk0: *Display, unk1: s32) -> s32 #c_call;
        XTranslateCoordinates: (unk0: *Display, unk1: Window, unk2: Window, unk3: s32, unk4: s32, unk5: *s32, unk6: *s32, unk7: *Window) -> s32 #c_call;
        XUnlockDisplay: (unk0: *Display) -> void #c_call;
        XUnsetICFocus: (unk0: XIC) -> void #c_call;
        XwcLookupString: (unk0: XIC, unk1: *XKeyPressedEvent, unk2: *u32, unk3: s32, unk4: *KeySym, unk5: *s32) -> s32 #c_call;
        XWidthMMOfScreen: (unk0: *Screen) -> s32 #c_call;
        XWidthOfScreen: (unk0: *Screen) -> s32 #c_call;
        XSetWMNormalHints: (dpy: *Display, w: Window, hints: *XSizeHints) #c_call;
    }
    using _procs: Procs;

    XCB_Compat_Procs :: struct {
        XGetXCBConnection: (dpy: *Display) -> *void #c_call;
        XSetEventQueueOwner: (dpy: *Display, owner: XEventQueueOwner) #c_call;
    }
    using _xcb_compat: XCB_Compat_Procs;

    DefaultRootWindow :: inline (display: *Display) -> Window {
        return ScreenOfDisplay(display, DefaultScreen(display)).root;
    }

    DefaultScreen :: inline (display: *Display) -> s32 {
        return (cast(*_XPrivDisplay) display).default_screen;
    }

    ScreenOfDisplay :: inline (display: *Display, scr: s32) -> *Screen {
        return *(cast(*_XPrivDisplay) display).screens[scr];
    }

    DefaultScreenOfDisplay :: inline (display: *Display) -> *Screen {
        return ScreenOfDisplay(display, DefaultScreen(display));
    }

    DefaultGC :: inline (display: *Display, scr: s32) -> GC {
        return ScreenOfDisplay(display, scr).default_gc;
    }

    init_global_atoms :: (using lib: *X11_Lib, dpy: *Display, global_atoms: *Global_Atoms) {
        Atom_Info :: struct {
            pval: *Atom;              // points to a member of a `Global_Atoms` instance
            name: string;             // 0-terminated; overwritten by `actual_name`, temp-alloced
            must_exist: Bool = True;  // overwritten by `must_exist`
        }

        parse_atom_info :: (global_atoms: *Global_Atoms, m: Type_Info_Struct_Member) -> Atom_Info {
            ret := Atom_Info.{
                pval = cast(*Atom) ((cast(*u8) global_atoms) + m.offset_in_bytes),
                name = m.name,
            };

            for m.notes {
                note := it;
                if !starts_with(note, "opts(") continue;
                assert(ends_with(note, ")"), "Missing closing paren: '%'", note);

                advance(*note, 5);
                assert(note.count >= 1);
                note.count -= 1;

                pieces := split(note, ",",, allocator = temp);
                for piece : pieces {
                    if starts_with(piece, "must_exist=") {
                        advance(*piece, "must_exist=".count);
                        if !compare_nocase(piece, "true")       ret.must_exist = True;
                        else if !compare_nocase(piece, "false") ret.must_exist = False;
                        else assert(false, "Invalid `must_exist` value: '%'", piece);
                    } else if starts_with(piece, "actual_name=") {
                        advance(*piece, "actual_name=".count);
                        assert(piece.count >= 1, "`actual_name` with empty value for Atom '%'", m.name);
                        ret.name = to_string(temp_c_string(piece));
                    } else assert(false, "Unknown Atom option: '%'", piece);
                }
            }

            return ret;
        }

        bulk_intern_atoms :: (using lib: *X11_Lib, dpy: *Display, infos: []Atom_Info) {
            if !infos.count return;

            results: [..]Atom;
            results.allocator = temp;
            array_resize(*results, infos.count);

            names: [..]*u8;
            names.allocator = temp;
            array_resize(*names, infos.count);

            for info, n : infos  names[n] = info.name.data;
            XInternAtoms(dpy, names.data, xx names.count, infos[0].must_exist, results.data);
            for atom, n : results  infos[n].pval.* = atom;
        }

        req_atoms: [..]Atom_Info;
        req_atoms.allocator = temp;

        opt_atoms: [..]Atom_Info;
        opt_atoms.allocator = temp;

        tis := cast(*Type_Info_Struct) type_info(Global_Atoms);

        array_reserve(*req_atoms, tis.members.count);
        array_reserve(*opt_atoms, tis.members.count);

        for m : tis.members {
            if m.type != type_info(Atom) continue;
            info := parse_atom_info(global_atoms, m);
            array_add(ifx info.must_exist then *req_atoms else *opt_atoms, info);
        }

        bulk_intern_atoms(lib, dpy, req_atoms);
        bulk_intern_atoms(lib, dpy, opt_atoms);
    }

    // @NOCHECKIN : move to GLX
    GLXWindow :: *void;
    GLXFBConfig :: *void;
    GLXContext :: *void;
}

xlib_load :: (intf: *X11_Lib, init_xcb_compat := false) -> success := false {
    generic_c_call :: #type () #c_call;

    populate_procs :: inline (procs: *$T, sonames: []string) -> bool {
        for soname : sonames {
            dlerror();
            lib := dlopen(temp_c_string(soname), RTLD_NOW);
            if !lib {
                log_error("Failed to load %: %", soname, to_string(dlerror()));
                continue;
            }

            tis := cast(*Type_Info_Struct) type_info(T);
            for m : tis.members {
                if m.type.type != .PROCEDURE continue;
                if m.flags & .CONSTANT continue;

                pi := cast(*Type_Info_Procedure) m.type;
                if !(pi.procedure_flags & .IS_C_CALL) continue;

                dlerror();
                ppfn := cast(*generic_c_call)((cast(*u8) procs) + m.offset_in_bytes);
                ppfn.* = cast(generic_c_call) dlsym(lib, m.name.data);
                if !ppfn.* {
                    log("Failed to resolve function '%' in '%': %", m.name, soname, to_string(dlerror()));
                    continue soname;
                }
            }

            log("X11: loaded %", soname);
            return true;
        }
        return false;
    }

    if !populate_procs(*intf._procs, .["libX11.so.6", "libX11.so"]) return false;
    if init_xcb_compat && !populate_procs(*intf._xcb_compat, .["libX11-xcb.so.1", "libX11-xcb.so"]) return false;

    return true;
}

#scope_file
#import "Basic";
#import "POSIX";
#import "String";
