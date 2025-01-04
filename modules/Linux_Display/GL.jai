#module_parameters(DUMP_GL_ERRORS := false, ENABLE_ALL_EXTENSIONS := false);

gl_procs: GL_Procs;

GetProcAddressFunction :: #type (proc: *u8) -> *void #c_call;

DumpGLErrors :: inline (tag: string, loc := #caller_location) -> bool {
    return false;
}

gl_load :: (procs: *GL_Procs, GetProcAddress: GetProcAddressFunction) {
    info_struct := type_info(GL_Procs);

    dest_bytes := cast(*u8) procs;
    table := get_type_table();

    procs.glGetIntegerv = xx GetProcAddress("glGetIntegerv");
    procs.glGetString   = xx GetProcAddress("glGetString");
    procs.glGetStringi  = xx GetProcAddress("glGetStringi");
    gl_version_major, gl_version_minor := gl_get_version(procs);
    if gl_version_major == 0 return;

    for * info_struct.members {
        if it.flags & .CONSTANT continue;

        is_intentional_void_pointer := cast(bool)(it.flags & .PROCEDURE_WITH_VOID_POINTER_TYPE_INFO);
        if (it.type.type == .PROCEDURE) || is_intentional_void_pointer {
            ptype := cast(*Type_Info_Procedure) it.type;

            if !is_intentional_void_pointer {
                assert ((ptype.procedure_flags & .IS_ELSEWHERE) != 0,
                        "Proc '%' is not elsewhere! (member_address %, type_address %, procedure_flags = %, % arguments, % returns, index = %)",
                        it.name, it, ptype, formatInt(ptype.procedure_flags, base=16), ptype.argument_types.count, ptype.return_types.count,
                        array_find(table, it.type));
            }

            c_string := it.name.data;

            address := cast(generic_c_call) GetProcAddress(c_string);
            dest := cast(*generic_c_call) (dest_bytes + it.offset_in_bytes);
            dest.* = address;
        } else if it.type.type == .BOOL {
            value := false;

            if begins_with(it.name, "GL_VERSION_") {
                major, minor := gl_parse_version(it.name);
                value = ((gl_version_major >= major) || (gl_version_major == major && gl_version_minor >= minor));
            } else if begins_with(it.name, "GL_") || begins_with(it.name, "WGL_") || begins_with(it.name, "GLX_") {
                value = gl_supports_extension(procs, it.name);
            } else {
                assert(false, "Unexpected variable '%' in GL struct.", it.name);
            }

            if value {
                dest := cast(*bool) (dest_bytes + it.offset_in_bytes);
                dest.* = value;
            }
        } else {
            if !begins_with(it.name, "gl_version_") {
                builder: String_Builder;
                print_type_to_builder(*builder, it.type);
                type_string := builder_to_string(*builder);
                defer free(type_string);

                assert(false, "Unexpected variable '%' in GL struct. (The type was: %).", it.name, type_string);
            }
        }
    }

    procs.gl_version_major = gl_version_major;
    procs.gl_version_minor = gl_version_minor;
}

EGL_Lib :: struct {
    _meta : struct {
        loaded: bool;
        major: s32;
        minor: s32;
    }

    create_context :: (using egl: *EGL_Lib, native_display: *void, platform: s32, attrib_list: *s32, major_version := 0, minor_version := 0, compatibility := false, debug := false) -> *void, *void, *void {
        assert(_meta.loaded);

        n: s32;

        egl_dpy: *void;
        if !platform && !attrib_list {
            egl_dpy = GetDisplay(native_display);
        } else {
            assert(GetPlatformDisplayEXT != null);
            egl_dpy = GetPlatformDisplayEXT(platform, native_display, attrib_list);
        }
        assert(egl_dpy != NO_DISPLAY, "egl_dpy=%, native_display=%", egl_dpy, native_display);

        if !Initialize(egl_dpy, *_meta.major, *_meta.minor)
            assert(false, "Initialize() failed: %", formatInt(GetError(), base=16));

        BindAPI(OPENGL_API);

        config_attribs : []s32 = .[
            SURFACE_TYPE, WINDOW_BIT,
            RED_SIZE, 8,
            GREEN_SIZE, 8,
            BLUE_SIZE, 8,
            // ALPHA_SIZE, 8,                   // this makes the entire window translucent
            RENDERABLE_TYPE, OPENGL_BIT,
            NONE
        ];
        egl_cnf: *void;
        ChooseConfig(egl_dpy, config_attribs.data, *egl_cnf, 1, *n);

        context_attribs: [9]s32;
        attr_count := 0;

        if major_version > 0 {
            context_attribs[attr_count + 0] = CONTEXT_MAJOR_VERSION;
            context_attribs[attr_count + 1] = xx major_version;
            context_attribs[attr_count + 2] = CONTEXT_MINOR_VERSION;
            context_attribs[attr_count + 3] = xx minor_version;
            attr_count += 4;
        }

        context_attribs[attr_count + 0] = CONTEXT_OPENGL_PROFILE_MASK;
        if compatibility  context_attribs[attr_count + 1] = CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT;
        else              context_attribs[attr_count + 1] = CONTEXT_OPENGL_CORE_PROFILE_BIT;
        attr_count += 2;

        if debug {
            context_attribs[attr_count + 0] = CONTEXT_OPENGL_DEBUG;
            context_attribs[attr_count + 1] = TRUE;
            attr_count += 2;
        }

        context_attribs[attr_count] = NONE;

        egl_ctx := CreateContext(egl_dpy, egl_cnf, NO_CONTEXT, context_attribs.data);

        return egl_dpy, egl_ctx, egl_cnf;
    }

    /*
     * Minimal EGL subset for editor use
     */
    TRUE                                        : s32 : 1;
    FALSE                                       : s32 : 0;
    NONE                                        : s32 : 0x3038;
    ALPHA_SIZE                                  : s32 : 0x3021;
    RED_SIZE                                    : s32 : 0x3024;
    GREEN_SIZE                                  : s32 : 0x3023;
    BLUE_SIZE                                   : s32 : 0x3022;
    SURFACE_TYPE                                : s32 : 0x3033;
    WINDOW_BIT                                  : s32 : 0x0004;
    OPENGL_API                                  : s32 : 0x30A2;
    OPENGL_BIT                                  : s32 : 0x0008;
    RENDERABLE_TYPE                             : s32 : 0x3040;
    CONTEXT_OPENGL_PROFILE_MASK                 : s32 : 0x30FD;
    CONTEXT_OPENGL_CORE_PROFILE_BIT             : s32 : 0x00000001;
    CONTEXT_OPENGL_COMPATIBILITY_PROFILE_BIT    : s32 : 0x00000002;
    CONTEXT_OPENGL_DEBUG                        : s32 : 0x31B0;
    CONTEXT_MAJOR_VERSION                       : s32 : 0x3098;
    CONTEXT_MINOR_VERSION                       : s32 : 0x30FB;
    PLATFORM_XCB_EXT                            : s32 : 0x31DC;
    PLATFORM_XCB_SCREEN_EXT                     : s32 : 0x31DE;

    NO_CONTEXT : *void : null;
    NO_DISPLAY : *void : null;
    NO_SURFACE : *void : null;

    Procs :: struct {
        GetDisplay          : (display_id: *void) -> *void #c_call;
        GetProcAddress      : (procname: *u8) -> *void #c_call;
        GetError            : () -> s32 #c_call;
        BindAPI             : (api: s32) -> s32 #c_call;
        Initialize          : (dpy: *void, major: *s32, minor: *s32) -> s32 #c_call;
        ChooseConfig        : (dpy: *void, attrib_list: *s32, configs: **void, config_size: s32, num_config: *s32) -> s32 #c_call;
        MakeCurrent         : (dpy: *void, draw: *void, read: *void, ctx: *void) -> s32 #c_call;
        SwapBuffers         : (dpy: *void, surface: *void) -> s32 #c_call;
        CreateWindowSurface : (dpy: *void, config: *void, win: *void, attrib_list: *s32) -> *void #c_call;
        CreateContext       : (dpy: *void, config: *void, share_context: *void, attrib_list: *s32) -> *void #c_call;
        DestroyContext      : (dpy: *void, ctx: *void) -> s32 #c_call;
        DestroySurface      : (dpy: *void, surface: *void) -> s32 #c_call;
        SwapInterval        : (dpy: *void, interval: s32) -> s32 #c_call;
    }
    using _procs: Procs;

    GetPlatformDisplayEXT : (platform: s32, native_display: *void, attrib_list: *s32) -> *void #c_call;
    CreatePlatformWindowSurfaceEXT: (egl_display: *void, config: *void, native_window: *void, attrib_list: *s32) -> *void #c_call;
};

wsi_load :: (intf: *EGL_Lib) -> bool {
    if intf._meta.loaded return true;

    sonames :: string.["libEGL.so.1", "libEGL.so"];

    for soname : sonames {
        dlerror();
        lib := dlopen(soname.data, RTLD_NOW);
        if !lib {
            log_error("Failed to load %: %", soname, to_string(dlerror()));
            continue;
        }

        tis := cast(*Type_Info_Struct) type_info(type_of(intf._procs));
        for m : tis.members {
            if m.type.type != .PROCEDURE continue;
            if m.flags & .CONSTANT continue;

            pi := cast(*Type_Info_Procedure) m.type;
            if !(pi.procedure_flags & .IS_C_CALL) continue;

            dlerror();
            name := tprint("egl%\0", m.name);
            ppfn := cast(*generic_c_call)((cast(*u8) *intf._procs) + m.offset_in_bytes);
            ppfn.* = cast(generic_c_call) dlsym(lib, name.data);
            if !ppfn.* {
                log("Failed to resolve function '%' in '%': %", name, soname, to_string(dlerror()));
                continue soname;
            }
        }

        intf.GetPlatformDisplayEXT = xx intf.GetProcAddress("eglGetPlatformDisplayEXT");
        intf.CreatePlatformWindowSurfaceEXT = xx intf.GetProcAddress("eglCreatePlatformWindowSurfaceEXT");
        intf._meta.loaded = true;
        log("EGL: loaded %", soname);
        return true;
    }

    return false;
}

GLX_Lib :: struct {
    _meta: struct {
        loaded: bool;
    }

    create_context :: (using lib: *GLX_Lib, dpy: *void, screen: s32, major_version: s32 = 0, minor_version: s32 = 0, compatibility := false, debug := false) -> *void, *void {
        assert(_meta.loaded);

        config_attribs: [] s32 = .[
            DRAWABLE_TYPE,  WINDOW_BIT,
            RENDER_TYPE,    RGBA_BIT,
            X_VISUAL_TYPE,  TRUE_COLOR,
            RED_SIZE,       8,
            GREEN_SIZE,     8,
            BLUE_SIZE,      8,
            // ALPHA_SIZE,     8,
            STENCIL_SIZE,   8,
            DOUBLEBUFFER,   1,
            0
        ];

        fbcount: s32;
        fbc := ChooseFBConfig(dpy, screen, config_attribs.data, *fbcount);
        // @Incomplete: Pick the best matching FB config
        best_fbc := fbc[0];

        context_attribs : [9]s32;
        attr_count := 0;

        if major_version > 0 {
            context_attribs[attr_count + 0] = CONTEXT_MAJOR_VERSION_ARB;
            context_attribs[attr_count + 1] = xx major_version;
            context_attribs[attr_count + 2] = CONTEXT_MINOR_VERSION_ARB;
            context_attribs[attr_count + 3] = xx minor_version;
            attr_count += 4;
        }

        context_attribs[attr_count + 0] = CONTEXT_PROFILE_MASK_ARB;
        if compatibility    context_attribs[attr_count + 1] = CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB;
        else                context_attribs[attr_count + 1] = CONTEXT_CORE_PROFILE_BIT_ARB;
        attr_count += 2;

        if debug {
            context_attribs[attr_count + 0] = CONTEXT_FLAGS_ARB;
            context_attribs[attr_count + 1] = CONTEXT_DEBUG_BIT_ARB;
            attr_count += 2;
        }

        context_attribs[attr_count] = 0;

        glc := CreateContextAttribsARB(dpy, best_fbc, null, 1, context_attribs.data);

        return glc, best_fbc;
    }

    // minimal GLX interface
    RGBA            :: 4;
    DOUBLEBUFFER    :: 5;
    RED_SIZE        :: 8;
    GREEN_SIZE      :: 9;
    BLUE_SIZE       :: 10;
    ALPHA_SIZE      :: 11;
    DEPTH_SIZE      :: 12;
    STENCIL_SIZE    :: 13;

    X_VISUAL_TYPE               :: 0x0022;
    CONTEXT_MAJOR_VERSION_ARB   :: 0x2091;
    CONTEXT_MINOR_VERSION_ARB   :: 0x2092;
    CONTEXT_FLAGS_ARB           :: 0x2094;
    TRUE_COLOR                  :: 0x8002;
    DRAWABLE_TYPE               :: 0x8010;
    RENDER_TYPE                 :: 0x8011;
    X_RENDERABLE                :: 0x8012;
    CONTEXT_PROFILE_MASK_ARB    :: 0x9126;

    WINDOW_BIT      :: 0x01;
    RGBA_BIT        :: 0x01;

    CONTEXT_CORE_PROFILE_BIT_ARB            :: 0x01;
    CONTEXT_COMPATIBILITY_PROFILE_BIT_ARB   :: 0x02;
    CONTEXT_DEBUG_BIT_ARB                   :: 0x01;
    CONTEXT_FORWARD_COMPATIBLE_BIT_ARB      :: 0x02;

    Procs :: struct {
        ChooseVisual: (display: *void, screen: s32, attrib_list: *s32) -> *void #c_call;
        CreateContext: (display: *void, visual: *void, share_list: *void, direct: s32) -> *void #c_call;
        CreateContextAttribsARB: (dpy: *void, config: *void, share_context: *void, direct: s32, attrib_list: *s32) -> *void #c_call;   @GLX_EXT
        MakeCurrent: (display: *void, drawable: u64, ctx: *void) -> s32 #c_call;
        MakeContextCurrent: (display: *void, draw: u64, read: u64, ctx: *void) -> s32 #c_call;
        GetCurrentContext: () -> *void #c_call;
        SwapBuffers: (display: *void, drawable: u64) -> void #c_call;
        DestroyContext: (display: *void, ctx: *void) #c_call;
        GetProcAddress: (procName: *u8) -> *void #c_call;
        ChooseFBConfig: (display: *void, screen: s32, attrib_list: *s32, nelements: *s32) -> **void #c_call;
        CreateWindow: (display: *void, config: *void, window: u64, attrib_list: *s32 = null) -> u64 #c_call;
        DestroyWindow: (display: *void, win: u64) #c_call;
        SwapIntervalEXT: (display: *void, drawable: u64, interval: s32) #c_call;  @GLX_EXT
    }
    using _procs: Procs;
}

wsi_load :: (intf: *GLX_Lib) -> bool {
    if intf._meta.loaded return true;

    sonames :: string.["libGLX.so.0", "libGLX.so"];

    for soname : sonames {
        dlerror();
        lib := dlopen(soname.data, RTLD_NOW);
        if !lib {
            log_error("Failed to load %: %", soname, to_string(dlerror()));
            continue;
        }

        ext_funcs: [..] struct {
            name: string;
            call: *generic_c_call;
            optional: bool;
        };

        tis := cast(*Type_Info_Struct) type_info(type_of(intf._procs));
        for m : tis.members {
            if m.type.type != .PROCEDURE continue;
            if m.flags & .CONSTANT continue;

            pi := cast(*Type_Info_Procedure) m.type;
            if !(pi.procedure_flags & .IS_C_CALL) continue;

            dlerror();
            name := tprint("glX%\0", m.name);
            ppfn := cast(*generic_c_call)((cast(*u8) *intf._procs) + m.offset_in_bytes);

            optional, _ := array_find(m.notes, "optional");
            is_extension_func, _ := array_find(m.notes, "GLX_EXT");

            if is_extension_func {
                info := array_add(*ext_funcs);
                info.name = name;
                info.call = ppfn;
                info.optional = optional;
            } else {
                ppfn.* = cast(generic_c_call) dlsym(lib, name.data);
                if !optional && !ppfn.* {
                    log("Failed to resolve function '%' in '%': %", name, soname, to_string(dlerror()));
                    continue soname;
                }
            }
        }

        for info: ext_funcs {
            info.call.* = cast(generic_c_call) intf.GetProcAddress(info.name.data);
            if !info.optional && !info.call.* {
                log("Failed to resolve extension function '%'", info.name);
                continue soname;
            }
            log("GLX EXT: % :: %", info.call.*, info.name);
        }

        intf._meta.loaded = true;
        log("GLX: loaded %", soname);
        return true;
    }

    return false;
}

#scope_file
#import "Basic";
#import "String";
#import "POSIX";
#import "Compiler";

#if ENABLE_ALL_EXTENSIONS {
    #load "GL_full.jai";  // Compatibility + All extensions
} else {
    #load "GL_core.jai"; // Core + Some extensions
}

generic_c_call :: #type () #c_call;

gl_parse_version :: (version: string) -> major:s32, minor:s32 {
    major, minor : s32;
    scan2(version, "GL_VERSION_%_%", *major, *minor);
    return major, minor;
}

gl_get_version :: (using procs: *GL_Procs) -> major:s32, minor:s32 {
    major, minor: s32;

    if GL_VERSION_3_0 {
        assert(glGetIntegerv != null);
        glGetIntegerv(GL_MAJOR_VERSION, *major);
        glGetIntegerv(GL_MINOR_VERSION, *minor);
    } else {
        assert(glGetString != null);
        version_string := glGetString(GL_VERSION);
        if !version_string return major, minor;
        scan2(to_string(version_string), "%.%", *major, *minor);
    }

    return major, minor;
}

gl_supports_extension :: (using procs: *GL_Procs, ext: string) -> bool {
    if GL_VERSION_3_0 {
        num: s32 = 0;
        assert(glGetIntegerv != null);
        glGetIntegerv(GL_NUM_EXTENSIONS, *num);
        for 0..num-1 {
            exti := to_string(glGetStringi(GL_EXTENSIONS, xx it));
            if ext == exti return true;
        }
        return false;
    } else {
        extn := to_string(glGetString(GL_EXTENSIONS));
        return contains(extn, ext);
    }
}
