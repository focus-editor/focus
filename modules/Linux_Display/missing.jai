// A bunch of stuff that's missing from the standard modules

XK_Insert :: 0xff63;

XK_KP_Space     :: 0xff80;
XK_KP_Tab       :: 0xff89;
XK_KP_Enter     :: 0xff8d;
XK_KP_F1        :: 0xff91;
XK_KP_F2        :: 0xff92;
XK_KP_F3        :: 0xff93;
XK_KP_F4        :: 0xff94;
XK_KP_Home      :: 0xff95;
XK_KP_Left      :: 0xff96;
XK_KP_Up        :: 0xff97;
XK_KP_Right     :: 0xff98;
XK_KP_Down      :: 0xff99;
XK_KP_Prior     :: 0xff9a;
XK_KP_Page_Up   :: 0xff9a;
XK_KP_Next      :: 0xff9b;
XK_KP_Page_Down :: 0xff9b;
XK_KP_End       :: 0xff9c;
XK_KP_Begin     :: 0xff9d;
XK_KP_Insert    :: 0xff9e;
XK_KP_Delete    :: 0xff9f;
XK_KP_Equal     :: 0xffbd;
XK_KP_Multiply  :: 0xffaa;
XK_KP_Add       :: 0xffab;
XK_KP_Separator :: 0xffac;
XK_KP_Subtract  :: 0xffad;
XK_KP_Decimal   :: 0xffae;
XK_KP_Divide    :: 0xffaf;
XK_KP_0         :: 0xffb0;
XK_KP_1         :: 0xffb1;
XK_KP_2         :: 0xffb2;
XK_KP_3         :: 0xffb3;
XK_KP_4         :: 0xffb4;
XK_KP_5         :: 0xffb5;
XK_KP_6         :: 0xffb6;
XK_KP_7         :: 0xffb7;
XK_KP_8         :: 0xffb8;
XK_KP_9         :: 0xffb9;

XIMPreeditArea      : u64 : 0x0001;
XIMPreeditCallbacks : u64 : 0x0002;
XIMPreeditPosition  : u64 : 0x0004;
XIMPreeditNothing   : u64 : 0x0008;
XIMPreeditNone      : u64 : 0x0010;
XIMStatusArea       : u64 : 0x0100;
XIMStatusCallbacks  : u64 : 0x0200;
XIMStatusNothing    : u64 : 0x0400;
XIMStatusNone       : u64 : 0x0800;

XNClientWindow :: "clientWindow".data;
XNFocusWindow :: "focusWindow".data;
XNInputStyle :: "inputStyle".data;

XBufferOverflow : Status = -1;
XLookupNone     : Status =  1;
XLookupChars    : Status =  2;
XLookupKeySym   : Status =  3;
XLookupBoth     : Status =  4;

XwcLookupString :: (ic: XIC, event: *XKeyEvent, buffer: *u32, buffer_size: s32, keysym: *KeySym, status: *Status) -> s32 #foreign libX11;

LC_ALL : s32 : 6;
setlocale :: (what: s32, loc: *u8) -> *u8 #foreign libc;

SIGEV_SIGNAL    : s32 : 0;
SIGEV_NONE      : s32 : 1;
SIGEV_THREAD    : s32 : 2;
SIGEV_THREAD_ID : s32 : 4;

timer_t :: *void;
timer_create :: (clockid: clockid_t, sevp: *sigevent, timerid: *timer_t) -> s32 #foreign librt;
timer_gettime :: (timerid: timer_t, curr_value: *itimerspec) -> s32 #foreign librt;
timer_settime :: (timerid: timer_t, flags: s32, new_value: *itimerspec, curr_value: *itimerspec) -> s32 #foreign librt;
timer_delete :: (timer: timer_t) -> s32 #foreign librt;

glXQueryExtension :: (dpy: *Display, error_base: *s32, event_base: *s32) -> Bool #foreign libGLX;

#scope_file

libX11 :: #system_library "libX11";
libGLX :: #system_library "libGLX";
libc :: #system_library "libc";
librt :: #system_library "librt";
