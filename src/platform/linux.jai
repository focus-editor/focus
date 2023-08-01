PLATFORM_CONFIG_SECTION :: "[[linux]]";
PLATFORM_SUBSECTION_ENUM :: enum {}
PLATFORM_SUBSECTION_NAMES :: string.[];

Platform_Config :: struct {
    scaling_factor: float = 0.0;
    explorer_command: string;
    explorer_reveal_command: string;
}

platform_parse_config_line :: (config: *Platform_Config, section: PLATFORM_SUBSECTION_ENUM, line: string) -> success: bool, error_msg: string {
    if trim(line) == "" return true, "";  // ???

    setting, value := break_by_spaces(line);
    setting = trim_right(setting, ":");

    config.scaling_factor = 0.0;

    if setting == {
        case "scaling_factor"; {
            f_val, success := parse_float(*value);
            if !success {
                error_msg := tprint("Couldn't parse '%' - expected a valid float, got '%'", setting, value);
                return false, error_msg;
            }
            // @TODO: scaling factors under 1.0 break the editor widget on Wayland,
            //        investigate why this happens
            lower_limit := ifx DEBUG then 0.5 else 1.0;
            if (f_val != 0.0) && (f_val < lower_limit || f_val > 5.0) {
                error_msg := tprint("Couldn't parse '%' - value out of the expected range ([% ... 5.0])", lower_limit, setting);
                return false, error_msg;
            }
            config.scaling_factor = f_val;
        }
        case "explorer_command"; {
            config.explorer_command = copy_string(trim(value));
        }
        case "explorer_reveal_command"; {
            config.explorer_reveal_command = copy_string(trim(value));
        }
        case; {
            error_msg := tprint("Unknown setting '%' in section '%'", setting, PLATFORM_CONFIG_SECTION);
            return false, error_msg;
        }
    }

    return true, "";
}

platform_apply_config :: (config: *Platform_Config) {
    LD.set_fixed_scaling(config.scaling_factor);
}

platform_copy_config :: (src: *Platform_Config, dst: *Platform_Config) {
    free(dst.explorer_command);
    free(dst.explorer_reveal_command);
    dst.* = src.*;
    src.* = .{};
}

platform_setup :: inline () {
    app_id     :: "dev.focus-editor.focus";  // needs to be lower-case as (some?) Wayland compositors seem to lower-case app ids anyway and we need the desktop entry file name to match the app id
    app_ver_id :: 1;   // ID that we can increment if we need to change the desktop entry in any way
    ver_id     :: #run sprint("%-%", app_id, app_ver_id);
    ver_id_key :: #run sprint("X-Focus-Ver-Id=%", ver_id);

    sa := sigaction_t.{
        sa_sigaction = (sig: s32, info: *siginfo_t, ctx: *void) #c_call {
            if sig != SIGCHLD return;
            waitpid(info._kill.si_pid, null, 0);
        },
        sa_flags = SA_SIGINFO,
    };
    sigaction(SIGCHLD, *sa, null);

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
%
DONE;
        desktop_entry_data := sprint(desktop_entry_fmt, icon_path, ver_id_key);
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
    LD.init(backend, app_id);

    active_backend := LD.active_backend();
    assert(active_backend != .UNINITIALIZED);

    timer = LD.timer_create();
}

platform_data_dir :: () -> string {
    data_dir := sprint("%/focus-editor", XDG.get_path(.DATA_HOME));
    make_directory_if_it_does_not_exist(data_dir);
    return data_dir;
}

platform_config_dir :: () -> string {
    config_dir := sprint("%/focus-editor", XDG.get_path(.CONFIG_HOME));
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
        background_color_rgb = as_3_floats(Colors.BACKGROUND));

    LD.set_icon_from_raw_data(window, icon_data.raw_pixels.data, icon_data.width, icon_data.height);
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

platform_set_refresh_timer :: (window: Window_Type) {
    LD.timer_start(timer, 0, 50);
}

platform_kill_refresh_timer :: (window: Window_Type) {
    LD.timer_stop(timer);
}

platform_enumerate_logical_drives :: () -> [] string {
    return .["/"];
}

platform_get_save_file_name :: (name := "") -> string, bool {
    print("name = '%'\n", name);
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
    local_run := (reveal && (config.platform.explorer_reveal_command.count > 0)) || (!reveal && (config.platform.explorer_command.count > 0));
    if local_run {
        args: [..]string;
        cmd_s: string;

        defer free(cmd_s);
        defer array_reset(*args);

        if !reveal && config.platform.explorer_command.count > 0 {
            cmd_s = replace(config.platform.explorer_command, "%s", path);
        }
        if reveal && config.platform.explorer_reveal_command.count > 0 {
            cmd_s = replace(config.platform.explorer_reveal_command, "%s", path);
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

platform_path_equals :: (path_a: string, path_b: string) -> bool {
    return path_a == path_b;
}

#scope_file

LD  :: #import "Linux_Display";
XDG :: #import "XDG";

#import "POSIX";
#import "Process";
#import "File";
#import "File_Utilities";

// Application icon
icon_data :: #run -> Linux_Icon {
    #import "stb_image";

    data, success := read_entire_file("images/linux-icon.png");
    assert(success, "Failed to read Linux icon!");

    icon: Linux_Icon;
    raw_pixels := stbi_load_from_memory(data.data, xx data.count, *icon.width, *icon.height, *icon.n_chan, 4);
    assert(raw_pixels != null, "Failed to parse PNG data!");
    assert(icon.n_chan == 4, "Expected 4 channels per pixel, got %!", icon.n_chan);

    size := icon.width * icon.height;
    pixels: [..]u32;
    array_resize(*pixels, size);
    memcpy(pixels.data, raw_pixels, xx (size * 4));

    for * pixels {
        v := <<it;
        <<it = (v & 0xff000000) | ((v & 0x00ff0000) >> 16) | (v & 0x0000ff00) | ((v & 0x000000ff) << 16);
    }

    icon.png_data = data;
    icon.raw_pixels = pixels;

    stbi_image_free(raw_pixels);

    return icon;
};

Linux_Icon :: struct {
    width: s32;
    height: s32;
    n_chan: s32;
    png_data: string;
    raw_pixels: []u32;
}

timer: LD.Timer;
