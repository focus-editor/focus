platform_apply_config :: () {
    LD.set_fixed_scaling(config.linux.scaling_factor);
}

platform_setup :: inline () {
    app_id     :: "dev.focus-editor.focus";  // needs to be lower-case as (some?) Wayland compositors seem to lower-case app ids anyway and we need the desktop entry file name to match the app id
    app_ver_id :: 3;   // ID that we can increment if we need to change the desktop entry in any way
    ver_id     :: #run sprint("%-%", app_id, app_ver_id);
    ver_id_key :: #run sprint("X-Focus-Ver-Id=%", ver_id);

    data_dir := platform_data_dir();
    defer free(data_dir);

    make_directory_if_it_does_not_exist(data_dir);

    icon_path := sprint("%/%.png", data_dir, ver_id);
    defer free(icon_path);
    if !file_exists(icon_path) write_entire_file(icon_path, icon_data.png_data);

    // The name of the desktop entry file must match the app id
    desktop_entry_path := sprint("%/applications/%.desktop", XDG.get_path(.DATA_HOME), app_id);
    defer free(desktop_entry_path);

    needs_new_desktop_entry := false;
    data, success := read_entire_file(desktop_entry_path);
    if success {
        pos := find_index_from_left(data, ver_id_key);
        if pos < 0 {
            needs_new_desktop_entry = true;
        } else {
            while (pos > 0) && (data[pos - 1] != #char "\n") {
                pos = find_index_from_left(data, ver_id_key, pos + 1);
            }
            if pos >= 0 {
                pos += ver_id_key.count;
                s := slice(data, pos, data.count - pos);
                needs_new_desktop_entry = (s.count == 0) || ((s.count > 0) && (s[0] != #char "\n"));
            } else {
                needs_new_desktop_entry = true;
            }
        }
    } else {
        needs_new_desktop_entry = true;
    }

    if needs_new_desktop_entry {
        desktop_entry_fmt := #string DONE
[Desktop Entry]
Version=1.0
Type=Application
Name=Focus editor (application icon entry)
Terminal=false
NoDisplay=true
DBusActivatable=false
Exec=focus-linux
Icon=%
StartupWMClass=%
%
DONE;
        desktop_entry_data := sprint(desktop_entry_fmt, icon_path, app_id, ver_id_key);
        write_entire_file(desktop_entry_path, desktop_entry_data);
        free(desktop_entry_data);
    }

    backend := LD.BACKEND_CHOICE.PREFER_BEST_USER_EXPERIENCE;
    cstr := getenv("FOCUS_LD_BACKEND");
    backend_s := ifx cstr then to_string(cstr) else "";
    if equal_nocase(backend_s, "prefer-wayland") then backend = .PREFER_WAYLAND;
    if equal_nocase(backend_s, "prefer-x11") then backend = .PREFER_X11;
    if equal_nocase(backend_s, "wayland") then backend = .FORCE_WAYLAND;
    if equal_nocase(backend_s, "x11") then backend = .FORCE_X11;
    if equal_nocase(backend_s, "xcb") then backend = .FORCE_XCB;

    gl_backend := LD.GL_BACKEND_CHOICE.AUTOSELECT;
    cstr = getenv("FOCUS_LD_GL_BACKEND");
    backend_s = ifx cstr then to_string(cstr) else "";
    if equal_nocase(backend_s, "glx") then gl_backend = .GLX;
    if equal_nocase(backend_s, "egl") then gl_backend = .EGL;

    flags : LD.Init_Flags = 0;
    cstr = getenv("FOCUS_LD_FLAGS");
    flags_s := ifx cstr then to_lower_copy(to_string(cstr),, allocator = temp) else "";
    flags_a := split(flags_s, ",",, allocator = temp);
    for flag : flags_a {
        if flag == {
            case "xcb-pure"; flags |= .XCB_Pure;
            case "xcb-core-events"; flags |= .XCB_Force_Core_Events;
        }
    }

    LD.init_with_stdlib_interop(
        desired_backend=backend,
        desired_gl_backend=gl_backend,
        flags=flags,
        app_id=app_id);

    active_backend := LD.active_backend();
    assert(active_backend != .UNINITIALIZED);

    cursor_timer = LD.timer_create();
    refresh_timer = LD.timer_create();
    xdg_reap_timer = LD.timer_create(cb = (tid: LD.Timer, data: *void) {
        XDG.reap_child_processes();
    });
    LD.timer_start(xdg_reap_timer, 500, 500);

    system_info.ld_backend_choice = backend;
    system_info.ld_backend = LD.active_backend();
    system_info.ld_gl_backend_choice = gl_backend;
    system_info.ld_gl_backend = LD.active_gl_backend();
}

platform_data_dir :: () -> string {
    data_dir := sprint("%/focus-editor", XDG.get_path(.DATA_HOME));
    #if DEBUG {
        data_dir = sprint("%/debug", data_dir);
    }
    make_directory_if_it_does_not_exist(data_dir);

    return data_dir;
}

platform_config_dir :: () -> string {
    config_dir := sprint("%/focus-editor", XDG.get_path(.CONFIG_HOME));
    #if DEBUG {
        config_dir = sprint("%/debug", config_dir);
    }
    make_directory_if_it_does_not_exist(config_dir);

    return config_dir;
}

platform_get_centered_window_dimensions :: (open_on_biggest: bool) -> s32, s32, s32, s32 {
    return 0, 0, 1920, 1080;
}

platform_create_window :: () {
    window = LD.create_window(
        window_width, window_height,
        window_generic_title,
        window_x, window_y,
        background_color_rgb = color_as_3_floats(Color.BACKGROUND_0),
    );

    if LD.active_backend() != .WAYLAND {
        data := icon_data.png_data;

        width: s32;
        height: s32;
        n_chan: s32;
        raw_pixels := stbi_load_from_memory(data.data, xx data.count, *width, *height, *n_chan, 4);
        assert(raw_pixels != null, "Failed to parse PNG data!");
        assert(icon_data.width == width && icon_data.height == height && icon_data.n_chan == n_chan,
               "Missmatch between recorded icon data and PNG load result: (%, %, %) vs (%, %, %)",
               icon_data.width, icon_data.height, icon_data.n_chan,
               width, height, n_chan);

        size := width * height;
        pixels := cast(*u32) raw_pixels;
        for 0..size - 1 {
            v := pixels[it];
            pixels[it] = (v & 0xff000000) | ((v & 0x00ff0000) >> 16) | (v & 0x0000ff00) | ((v & 0x000000ff) << 16);
        }

        LD.set_icon_from_raw_data(window, raw_pixels, width, height);

        stbi_image_free(raw_pixels);
    }
}

platform_maximize_window :: (window: Window_Type) {
    LD.maximize_window(window);
}

platform_enable_drag_and_drop :: (window: Window_Type) {
    typelist := string.["url/url", "text/uri-list", "text/plain", "application/octet-stream"];
    LD.enable_dnd(window, typelist);
}

platform_get_dpi_scale :: (window: Window_Type) -> float {
    return LD.get_dpi_scaling_factor(window);
}

platform_set_window_title :: (title: string) {
    LD.set_window_title(window, title);
}

platform_wait_message :: inline () {
    LD.wait_for_events();
}

platform_wake_up_main_thread :: () {
    LD.wake_up_event_loop();
}

platform_set_refresh_timer :: (window: Window_Type) {
    LD.timer_start(refresh_timer, 0, 1000);
}

platform_set_cursor_timer :: (window: Window_Type) {
    LD.timer_start(cursor_timer, 0, 50);
}

platform_kill_cursor_timer :: (window: Window_Type) {
    LD.timer_stop(cursor_timer);
}

platform_enumerate_logical_drives :: () -> [] string {
    logical_drives: [..]string;

    pw := getpwuid(getuid());
    array_add(*logical_drives, "/");
    array_add(*logical_drives, to_string(pw.pw_dir));

    return logical_drives;
}

platform_get_save_file_name :: (name := "") -> string, bool {
    return "", false;
}

platform_find_font_by_name :: (name: string, allocator := temp) -> bool, string {
    found, path := LD.find_font(name, allocator);
    return found, path;
}

platform_get_fonts_dir :: () -> string {
    return "/usr/share/fonts";
}

platform_open_in_explorer :: (path: string, reveal := false) {
    local_run := (reveal && (config.linux.explorer_reveal_command.count > 0)) || (!reveal && (config.linux.explorer_command.count > 0));
    if local_run {
        args: [..]string;
        cmd_s: string;

        defer free(cmd_s);
        defer array_reset(*args);

        if !reveal && config.linux.explorer_command.count > 0 {
            cmd_s = replace(config.linux.explorer_command, "%s", path);
        }
        if reveal && config.linux.explorer_reveal_command.count > 0 {
            cmd_s = replace(config.linux.explorer_reveal_command, "%s", path);
        }

        if cmd_s.count > 0 {
            args = break_command_into_strings(cmd_s);
            process: Process;
            create_process(*process, ..args);
            return;
        }
    }
    XDG.open(path, reveal);
}

platform_path_equals :: inline (path_a: string, path_b: string) -> bool {
    return path_a == path_b;
}

platform_path_begins_with :: inline (path: string, subpath: string) -> bool {
    return begins_with(path, subpath);
}

platform_path_contains :: inline (path: string, subpath: string) -> bool {
    return contains(path, subpath);
}

platform_set_border_color :: inline () {
}

platform_show_cursor :: (show: bool) {
}

platform_get_troubleshooting_info :: () -> string /* temp */ {
    using LD.GL.gl_procs;

    system_info.ld_gl_backend = LD.active_gl_backend();

    push_allocator(temp);

    env_check :: (sb: *String_Builder, names: .. *u8) {
        for name : names {
            val := getenv(name);
            print_to_builder(sb, "  % : %\n", to_string(name), ifx val then to_string(val) else "<not set>");
        }
    }

    env_check_by_prefix :: (sb: *String_Builder, prefixes: .. *u8) {
        for prefix : prefixes {
            ptr := environ;
            while ptr.* {
                defer ptr += 1;
                parts := split(to_string(ptr.*), "=", 2,, allocator = temp);
                if parts.count != 2 continue;
                if !starts_with(parts[0], to_string(prefix)) continue;
                print_to_builder(sb, "  % : %\n", parts[0], parts[1]);
            }
        }
    }

    gl_string :: (id: GLenum) -> string {
        using LD.GL.gl_procs;
        str_raw := glGetString(id);
        return ifx str_raw then to_string(str_raw) else tprint("<GL error %>", glGetError());
    }

    gl_get_extensions :: (sb: *String_Builder) {
        using LD.GL.gl_procs;
        extension_count: u32;
        extension: u32;
        glGetIntegerv(GL_NUM_EXTENSIONS, xx *extension_count);

        print_to_builder(sb, "  extensions (%):\n", extension_count);
        width := 0;
        while extension < extension_count {
            ext_raw := glGetStringi(GL_EXTENSIONS, extension);
            if !ext_raw {
                print_to_builder(sb, "    >>> glGetStringi(GL_EXTENSIONS, %): %\n", extension, glGetError());
                break;
            }
            ext := to_string(ext_raw);
            if !width print_to_builder(sb, "    ");
            if extension && width {
                print_to_builder(sb, ", ");
                width += 2;
            }
            if width + ext.count < 100 {
                print_to_builder(sb, "%", ext);
                width += ext.count;
            } else {
                print_to_builder(sb, "\n");
                width = 0;
            }

            extension += 1;
            if extension >= extension_count print_to_builder(sb, "\n");
        }
    }

    get_loaded_libs :: (sb: *String_Builder) {
        #import "String";

        fd := open("/proc/self/maps", O_RDONLY);
        if fd < 0 {
            print_to_builder(sb, "Failed to open '/proc/self/maps': %\n", errno());
            return;
        }
        defer close(fd);

        data: [..] u8;
        buff: [4096] u8;
        while true {
            rs := read(fd, buff.data, buff.count);
            if rs < 0 {
                print_to_builder(sb, "Failed to read data from '/proc/self/maps': %\n", errno());
                return;
            }
            if !rs break;
            array_reserve(*data, data.count + rs);
            focus_memcpy(data.data + data.count, buff.data, rs);
            data.count += rs;
        }

        libs: [..] string;
        lines := split(to_string(data.data, data.count), "\n",, allocator = temp);
        for line : lines {
            parts := split(line, " ", 6,, allocator = temp);
            if parts.count != 6 continue;
            if parts[1].count != 4 continue;
            if parts[1][2] != #char "x" continue;

            lib := trim(parts[5]);
            if !starts_with(lib, "/") continue;

            found := false;
            for l : libs {
                if l == lib {
                    found = true;
                    break;
                }
            }
            if !found array_add(*libs, lib);
        }

        for libs  print_to_builder(sb, "  %\n", it);
    }

    sb: String_Builder;

    print_to_builder(*sb, "Kernel:\n");
    result, output := run_command("uname", "-a", capture_and_return_output = true);
    print_to_builder(*sb, "  %\n", ifx result.exit_code == 0 then trim(output) else tprint(">> failed to run `uname -a`: %", result));

    print_to_builder(*sb, "OS information:\n");
    os_data, ok := read_entire_file("/etc/os-release");
    if !ok {
        print_to_builder(*sb, "  >> failed to read '/etc/os-release'\n");
    } else {
        lines := split(os_data, "\n",, allocator = temp);
        for lines {
            line := trim(it);
            if line print_to_builder(*sb, "  %\n", line);
        }
    }
    print_to_builder(*sb, "\n");

    print_to_builder(*sb, "Interesting things in the environment:\n");
    env_check(*sb, "FOCUS_LD_BACKEND", "FOCUS_LD_GL_BACKEND", "FOCUS_LD_FLAGS");
    env_check(*sb, "DISPLAY", "WAYLAND_DISPLAY");
    env_check(*sb, "DESKTOP_SESSION", "XDG_SESSION_DESKTOP", "XDG_CURRENT_DESKTOP");
    env_check(*sb, "XCURSOR_THEME", "XCURSOR_SIZE");
    env_check(*sb, "LD_LIBRARY_PATH", "LD_PRELOAD");
    env_check(*sb, "PATH");
    env_check_by_prefix(*sb, "__GL_");  // NVIDIA stuff
    print_to_builder(*sb, "\n");

    print_to_builder(*sb, "Loaded libraries:\n");
    get_loaded_libs(*sb);
    print_to_builder(*sb, "\n");

    print_to_builder(*sb, "Linux_Display information:\n");
    print_to_builder(*sb, "  desired backend    : %\n", system_info.ld_backend_choice);
    print_to_builder(*sb, "  active backend     : %\n", system_info.ld_backend);
    print_to_builder(*sb, "  desired GL backend : %\n", system_info.ld_gl_backend_choice);
    print_to_builder(*sb, "  active GL backend  : %\n", system_info.ld_gl_backend);
    print_to_builder(*sb, "\n");

    LD.dump_debug_info(*sb);
    print_to_builder(*sb, "\n");

    print_to_builder(*sb, "OpenGL Information:\n");
    print_to_builder(*sb, "  vendor       : %\n", gl_string(GL_VENDOR));
    print_to_builder(*sb, "  renderer     : %\n", gl_string(GL_RENDERER));
    print_to_builder(*sb, "  version      : %\n", gl_string(GL_VERSION));
    print_to_builder(*sb, "  GLSL version : %\n", gl_string(GL_SHADING_LANGUAGE_VERSION));
    gl_get_extensions(*sb);
    print_to_builder(*sb, "\n");

    ret := builder_to_string(*sb);
    log("Troubleshooting data: % bytes", ret.count);
    return ret;
}

/*
 * `Linux_Display` is empty on platforms other than Linux, so importing it should be basically
 * free on Windows/MacOS.
 */
LD :: #import "Linux_Display"()(VALIDATE_USAGE = DEBUG);

#scope_file

XDG :: #import "XDG";

#import "POSIX";
#import "Process";
#import "File";
#import "File_Utilities";
#import "stb_image";

// Application icon
icon_data :: #run -> Linux_Icon {
    data, success := read_entire_file("images/focus.png");
    assert(success, "Failed to read Linux icon!");

    icon: Linux_Icon;
    raw_pixels := stbi_load_from_memory(data.data, xx data.count, *icon.width, *icon.height, *icon.n_chan, 4);
    assert(raw_pixels != null, "Failed to parse PNG data!");
    assert(icon.n_chan == 4, "Expected 4 channels per pixel, got %!", icon.n_chan);

    icon.png_data = data;

    stbi_image_free(raw_pixels);

    return icon;
};

Linux_Icon :: struct {
    width: s32;
    height: s32;
    n_chan: s32;
    png_data: string;
}

cursor_timer: LD.Timer;
refresh_timer: LD.Timer;
xdg_reap_timer: LD.Timer;

Linux_System_Info :: struct {
    ld_backend_choice: LD.BACKEND_CHOICE;
    ld_backend: LD.ACTIVE_BACKEND;
    ld_gl_backend_choice: LD.GL_BACKEND_CHOICE;
    ld_gl_backend: LD.GL_BACKEND;
}
system_info: Linux_System_Info;

environ: **u8 #elsewhere;  // provided by the C runtime
