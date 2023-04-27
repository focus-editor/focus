EGLDisplay :: *_EGLDisplay;
EGLConfig  :: *_EGLConfig;
EGLSurface :: *_EGLSurface;
EGLContext :: *_EGLContext;

EGLClientBuffer :: *_EGLClientBuffer;

EGLSync  :: *_EGLSync;
EGLImage :: *_EGLImage;

EGLNativePixmapType  :: *void;
EGLNativeDisplayType :: *void;
EGLNativeWindowType  :: *void;

/* EGL 1.0.1 */
EGL_ALPHA_SIZE              : s32 : 0x3021;
EGL_BAD_ACCESS              : s32 : 0x3002;
EGL_BAD_ALLOC               : s32 : 0x3003;
EGL_BAD_ATTRIBUTE           : s32 : 0x3004;
EGL_BAD_CONFIG              : s32 : 0x3005;
EGL_BAD_CONTEXT             : s32 : 0x3006;
EGL_BAD_CURRENT_SURFACE     : s32 : 0x3007;
EGL_BAD_DISPLAY             : s32 : 0x3008;
EGL_BAD_MATCH               : s32 : 0x3009;
EGL_BAD_NATIVE_PIXMAP       : s32 : 0x300A;
EGL_BAD_NATIVE_WINDOW       : s32 : 0x300B;
EGL_BAD_PARAMETER           : s32 : 0x300C;
EGL_BAD_SURFACE             : s32 : 0x300D;
EGL_BLUE_SIZE               : s32 : 0x3022;
EGL_BUFFER_SIZE             : s32 : 0x3020;
EGL_CONFIG_CAVEAT           : s32 : 0x3027;
EGL_CONFIG_ID               : s32 : 0x3028;
EGL_CORE_NATIVE_ENGINE      : s32 : 0x305B;
EGL_DEPTH_SIZE              : s32 : 0x3025;
EGL_DONT_CARE               : s32 : -1;
EGL_DRAW                    : s32 : 0x3059;
EGL_EXTENSIONS              : s32 : 0x3055;
EGL_FALSE                   : s32 : 0;
EGL_GREEN_SIZE              : s32 : 0x3023;
EGL_HEIGHT                  : s32 : 0x3056;
EGL_LARGEST_PBUFFER         : s32 : 0x3058;
EGL_LEVEL                   : s32 : 0x3029;
EGL_MAX_PBUFFER_HEIGHT      : s32 : 0x302A;
EGL_MAX_PBUFFER_PIXELS      : s32 : 0x302B;
EGL_MAX_PBUFFER_WIDTH       : s32 : 0x302C;
EGL_NATIVE_RENDERABLE       : s32 : 0x302D;
EGL_NATIVE_VISUAL_ID        : s32 : 0x302E;
EGL_NATIVE_VISUAL_TYPE      : s32 : 0x302F;
EGL_NONE                    : s32 : 0x3038;
EGL_NON_CONFORMANT_CONFIG   : s32 : 0x3051;
EGL_NOT_INITIALIZED         : s32 : 0x3001;
EGL_NO_CONTEXT              :: cast(EGLContext) null;
EGL_NO_DISPLAY              :: cast(EGLDisplay) null;
EGL_NO_SURFACE              :: cast(EGLSurface) null;
EGL_PBUFFER_BIT             : s32 : 0x0001;
EGL_PIXMAP_BIT              : s32 : 0x0002;
EGL_READ                    : s32 : 0x305A;
EGL_RED_SIZE                : s32 : 0x3024;
EGL_SAMPLES                 : s32 : 0x3031;
EGL_SAMPLE_BUFFERS          : s32 : 0x3032;
EGL_SLOW_CONFIG             : s32 : 0x3050;
EGL_STENCIL_SIZE            : s32 : 0x3026;
EGL_SUCCESS                 : s32 : 0x3000;
EGL_SURFACE_TYPE            : s32 : 0x3033;
EGL_TRANSPARENT_BLUE_VALUE  : s32 : 0x3035;
EGL_TRANSPARENT_GREEN_VALUE : s32 : 0x3036;
EGL_TRANSPARENT_RED_VALUE   : s32 : 0x3037;
EGL_TRANSPARENT_RGB         : s32 : 0x3052;
EGL_TRANSPARENT_TYPE        : s32 : 0x3034;
EGL_TRUE                    : s32 : 1;
EGL_VENDOR                  : s32 : 0x3053;
EGL_VERSION                 : s32 : 0x3054;
EGL_WIDTH                   : s32 : 0x3057;
EGL_WINDOW_BIT              : s32 : 0x0004;

eglChooseConfig :: (dpy: EGLDisplay, attrib_list: *s32, configs: *EGLConfig, config_size: s32, num_config: *s32) -> s32 #foreign libEGL;
eglCopyBuffers :: (dpy: EGLDisplay, surface: EGLSurface, target: EGLNativePixmapType) -> s32 #foreign libEGL;
eglCreateContext :: (dpy: EGLDisplay, config: EGLConfig, share_context: EGLContext, attrib_list: *s32) -> EGLContext #foreign libEGL;
eglCreatePbufferSurface :: (dpy: EGLDisplay, config: EGLConfig, attrib_list: *s32) -> EGLSurface #foreign libEGL;
eglCreatePixmapSurface :: (dpy: EGLDisplay, config: EGLConfig, pixmap: EGLNativePixmapType, attrib_list: *s32) -> EGLSurface #foreign libEGL;
eglCreateWindowSurface :: (dpy: EGLDisplay, config: EGLConfig, win: EGLNativeWindowType, attrib_list: *s32) -> EGLSurface #foreign libEGL;
eglDestroyContext :: (dpy: EGLDisplay, ctx: EGLContext) -> s32 #foreign libEGL;
eglDestroySurface :: (dpy: EGLDisplay, surface: EGLSurface) -> s32 #foreign libEGL;
eglGetConfigAttrib :: (dpy: EGLDisplay, config: EGLConfig, attribute: s32, value: *s32) -> s32 #foreign libEGL;
eglGetConfigs :: (dpy: EGLDisplay, configs: *EGLConfig, config_size: s32, num_config: *s32) -> s32 #foreign libEGL;
eglGetCurrentDisplay :: () -> EGLDisplay #foreign libEGL;
eglGetCurrentSurface :: (readdraw: s32) -> EGLSurface #foreign libEGL;
eglGetDisplay :: (display_id: EGLNativeDisplayType) -> EGLDisplay #foreign libEGL;
eglGetError :: () -> s32 #foreign libEGL;
eglGetProcAddress :: (procname: *u8) -> *void #foreign libEGL;
eglInitialize :: (dpy: EGLDisplay, major: *s32, minor: *s32) -> s32 #foreign libEGL;
eglMakeCurrent :: (dpy: EGLDisplay, draw: EGLSurface, read: EGLSurface, ctx: EGLContext) -> s32 #foreign libEGL;
eglQueryContext :: (dpy: EGLDisplay, ctx: EGLContext, attribute: s32, value: *s32) -> s32 #foreign libEGL;
eglQueryString :: (dpy: EGLDisplay, name: s32) -> *u8 #foreign libEGL;
eglQuerySurface :: (dpy: EGLDisplay, surface: EGLSurface, attribute: s32, value: *s32) -> s32 #foreign libEGL;
eglSwapBuffers :: (dpy: EGLDisplay, surface: EGLSurface) -> s32 #foreign libEGL;
eglTerminate :: (dpy: EGLDisplay) -> s32 #foreign libEGL;
eglWaitGL :: () -> s32 #foreign libEGL;
eglWaitNative :: (engine: s32) -> s32 #foreign libEGL;

/* EGL 1.1 */
EGL_BACK_BUFFER             : s32 : 0x3084;
EGL_BIND_TO_TEXTURE_RGB     : s32 : 0x3039;
EGL_BIND_TO_TEXTURE_RGBA    : s32 : 0x303A;
EGL_CONTEXT_LOST            : s32 : 0x300E;
EGL_MIN_SWAP_INTERVAL       : s32 : 0x303B;
EGL_MAX_SWAP_INTERVAL       : s32 : 0x303C;
EGL_MIPMAP_TEXTURE          : s32 : 0x3082;
EGL_MIPMAP_LEVEL            : s32 : 0x3083;
EGL_NO_TEXTURE              : s32 : 0x305C;
EGL_TEXTURE_2D              : s32 : 0x305F;
EGL_TEXTURE_FORMAT          : s32 : 0x3080;
EGL_TEXTURE_RGB             : s32 : 0x305D;
EGL_TEXTURE_RGBA            : s32 : 0x305E;
EGL_TEXTURE_TARGET          : s32 : 0x3081;

eglBindTexImage :: (dpy: EGLDisplay, surface: EGLSurface, buffer: s32) -> s32 #foreign libEGL;
eglReleaseTexImage :: (dpy: EGLDisplay, surface: EGLSurface, buffer: s32) -> s32 #foreign libEGL;
eglSurfaceAttrib :: (dpy: EGLDisplay, surface: EGLSurface, attribute: s32, value: s32) -> s32 #foreign libEGL;
eglSwapInterval :: (dpy: EGLDisplay, interval: s32) -> s32 #foreign libEGL;

/* EGL 1.2 */
EGL_ALPHA_FORMAT            : s32 : 0x3088;
EGL_ALPHA_FORMAT_NONPRE     : s32 : 0x308B;
EGL_ALPHA_FORMAT_PRE        : s32 : 0x308C;
EGL_ALPHA_MASK_SIZE         : s32 : 0x303E;
EGL_BUFFER_PRESERVED        : s32 : 0x3094;
EGL_BUFFER_DESTROYED        : s32 : 0x3095;
EGL_CLIENT_APIS             : s32 : 0x308D;
EGL_COLORSPACE              : s32 : 0x3087;
EGL_COLORSPACE_sRGB         : s32 : 0x3089;
EGL_COLORSPACE_LINEAR       : s32 : 0x308A;
EGL_COLOR_BUFFER_TYPE       : s32 : 0x303F;
EGL_CONTEXT_CLIENT_TYPE     : s32 : 0x3097;
EGL_DISPLAY_SCALING         : s32 : 10000;
EGL_HORIZONTAL_RESOLUTION   : s32 : 0x3090;
EGL_LUMINANCE_BUFFER        : s32 : 0x308F;
EGL_LUMINANCE_SIZE          : s32 : 0x303D;
EGL_OPENGL_ES_BIT           : s32 : 0x0001;
EGL_OPENVG_BIT              : s32 : 0x0002;
EGL_OPENGL_ES_API           : s32 : 0x30A0;
EGL_OPENVG_API              : s32 : 0x30A1;
EGL_OPENVG_IMAGE            : s32 : 0x3096;
EGL_PIXEL_ASPECT_RATIO      : s32 : 0x3092;
EGL_RENDERABLE_TYPE         : s32 : 0x3040;
EGL_RENDER_BUFFER           : s32 : 0x3086;
EGL_RGB_BUFFER              : s32 : 0x308E;
EGL_SINGLE_BUFFER           : s32 : 0x3085;
EGL_SWAP_BEHAVIOR           : s32 : 0x3093;
EGL_UNKNOWN                 : s32 : -1;
EGL_VERTICAL_RESOLUTION     : s32 : 0x3091;

eglBindAPI :: (api: s32) -> s32 #foreign libEGL;
eglQueryAPI :: () -> u32 #foreign libEGL;
eglCreatePbufferFromClientBuffer :: (dpy: EGLDisplay, buftype: u32, buffer: EGLClientBuffer, config: EGLConfig, attrib_list: *s32) -> EGLSurface #foreign libEGL;
eglReleaseThread :: () -> s32 #foreign libEGL;
eglWaitClient :: () -> s32 #foreign libEGL;

/*  EGL 1.3 */
EGL_CONFORMANT               : s32 : 0x3042;
EGL_CONTEXT_CLIENT_VERSION   : s32 : 0x3098;
EGL_MATCH_NATIVE_PIXMAP      : s32 : 0x3041;
EGL_OPENGL_ES2_BIT           : s32 : 0x0004;
EGL_VG_ALPHA_FORMAT          : s32 : 0x3088;
EGL_VG_ALPHA_FORMAT_NONPRE   : s32 : 0x308B;
EGL_VG_ALPHA_FORMAT_PRE      : s32 : 0x308C;
EGL_VG_ALPHA_FORMAT_PRE_BIT  : s32 : 0x0040;
EGL_VG_COLORSPACE            : s32 : 0x3087;
EGL_VG_COLORSPACE_sRGB       : s32 : 0x3089;
EGL_VG_COLORSPACE_LINEAR     : s32 : 0x308A;
EGL_VG_COLORSPACE_LINEAR_BIT : s32 : 0x0020;

/* EGL 1.4 */
EGL_DEFAULT_DISPLAY               :: cast(EGLNativeDisplayType) null;
EGL_MULTISAMPLE_RESOLVE_BOX_BIT   : s32 : 0x0200;
EGL_MULTISAMPLE_RESOLVE           : s32 : 0x3099;
EGL_MULTISAMPLE_RESOLVE_DEFAULT   : s32 : 0x309A;
EGL_MULTISAMPLE_RESOLVE_BOX       : s32 : 0x309B;
EGL_OPENGL_API                    : s32 : 0x30A2;
EGL_OPENGL_BIT                    : s32 : 0x0008;
EGL_SWAP_BEHAVIOR_PRESERVED_BIT   : s32 : 0x0400;

/* EGL 1.5 */
EGL_CONTEXT_MAJOR_VERSION                       : s32 : 0x3098;
EGL_CONTEXT_MINOR_VERSION                       : s32 : 0x30FB;
EGL_CONTEXT_OPENGL_PROFILE_MASK                 : s32 : 0x30FD;
EGL_CONTEXT_OPENGL_RESET_NOTIFICATION_STRATEGY  : s32 : 0x31BD;
EGL_NO_RESET_NOTIFICATION                       : s32 : 0x31BE;
EGL_LOSE_CONTEXT_ON_RESET                       : s32 : 0x31BF;
EGL_CONTEXT_OPENGL_CORE_PROFILE_BIT             : s32 : 0x00000001;
EGL_CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT    : s32 : 0x00000002;
EGL_CONTEXT_OPENGL_DEBUG                        : s32 : 0x31B0;
EGL_CONTEXT_OPENGL_FORWARD_COMPATIBLE           : s32 : 0x31B1;
EGL_CONTEXT_OPENGL_ROBUST_ACCESS                : s32 : 0x31B2;
EGL_OPENGL_ES3_BIT                              : s32 : 0x00000040;
EGL_CL_EVENT_HANDLE                             : s32 : 0x309C;
EGL_SYNC_CL_EVENT                               : s32 : 0x30FE;
EGL_SYNC_CL_EVENT_COMPLETE                      : s32 : 0x30FF;
EGL_SYNC_PRIOR_COMMANDS_COMPLETE                : s32 : 0x30F0;
EGL_SYNC_TYPE                                   : s32 : 0x30F7;
EGL_SYNC_STATUS                                 : s32 : 0x30F1;
EGL_SYNC_CONDITION                              : s32 : 0x30F8;
EGL_SIGNALED                                    : s32 : 0x30F2;
EGL_UNSIGNALED                                  : s32 : 0x30F3;
EGL_SYNC_FLUSH_COMMANDS_BIT                     : s32 : 0x0001;
EGL_FOREVER                                     :: cast(u64) 0xFFFFFFFFFFFFFFFF;
EGL_TIMEOUT_EXPIRED                             : s32 : 0x30F5;
EGL_CONDITION_SATISFIED                         : s32 : 0x30F6;
EGL_NO_SYNC                                     :: cast(EGLSync) null;
EGL_SYNC_FENCE                                  : s32 : 0x30F9;
EGL_GL_COLORSPACE                               : s32 : 0x309D;
EGL_GL_COLORSPACE_SRGB                          : s32 : 0x3089;
EGL_GL_COLORSPACE_LINEAR                        : s32 : 0x308A;
EGL_GL_RENDERBUFFER                             : s32 : 0x30B9;
EGL_GL_TEXTURE_2D                               : s32 : 0x30B1;
EGL_GL_TEXTURE_LEVEL                            : s32 : 0x30BC;
EGL_GL_TEXTURE_3D                               : s32 : 0x30B2;
EGL_GL_TEXTURE_ZOFFSET                          : s32 : 0x30BD;
EGL_GL_TEXTURE_CUBE_MAP_POSITIVE_X              : s32 : 0x30B3;
EGL_GL_TEXTURE_CUBE_MAP_NEGATIVE_X              : s32 : 0x30B4;
EGL_GL_TEXTURE_CUBE_MAP_POSITIVE_Y              : s32 : 0x30B5;
EGL_GL_TEXTURE_CUBE_MAP_NEGATIVE_Y              : s32 : 0x30B6;
EGL_GL_TEXTURE_CUBE_MAP_POSITIVE_Z              : s32 : 0x30B7;
EGL_GL_TEXTURE_CUBE_MAP_NEGATIVE_Z              : s32 : 0x30B8;
EGL_IMAGE_PRESERVED                             : s32 : 0x30D2;
EGL_NO_IMAGE                                    :: cast(EGLImage) null;

eglCreateSync :: (dpy: EGLDisplay, type: u32, attrib_list: *s64) -> EGLSync #foreign libEGL;
eglDestroySync :: (dpy: EGLDisplay, sync: EGLSync) -> s32 #foreign libEGL;
eglClientWaitSync :: (dpy: EGLDisplay, sync: EGLSync, flags: s32, timeout: u64) -> s32 #foreign libEGL;
eglGetSyncAttrib :: (dpy: EGLDisplay, sync: EGLSync, attribute: s32, value: s64) -> s32 #foreign libEGL;
eglCreateImage :: (dpy: EGLDisplay, ctx: EGLContext, target: u32, buffer: EGLClientBuffer, attrib_list: *s64) -> EGLImage #foreign libEGL;
eglDestroyImage :: (dpy: EGLDisplay, image: EGLImage) -> s32 #foreign libEGL;
eglGetPlatformDisplay :: (platform: u32, native_display: *void, attrib_list: *s64) -> EGLDisplay #foreign libEGL;
eglCreatePlatformWindowSurface :: (dpy: EGLDisplay, config: EGLConfig, native_window: *void, attrib_list: *s64) -> EGLSurface #foreign libEGL;
eglCreatePlatformPixmapSurface :: (dpy: EGLDisplay, config: EGLConfig, native_pixmap: *void, attrib_list: *s64) -> EGLSurface #foreign libEGL;
eglWaitSync :: (dpy: EGLDisplay, sync: EGLSync, flags: s32) -> s32 #foreign libEGL;

#scope_file
_EGLDisplay :: struct {}
_EGLConfig  :: struct {}
_EGLSurface :: struct {}
_EGLContext :: struct {}

_EGLClientBuffer :: struct {}

_EGLSync  :: struct {}
_EGLImage :: struct {}

libEGL :: #system_library "libEGL";
