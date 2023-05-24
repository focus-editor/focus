PLATFORM_CONFIG_SECTION :: "[[linux]]";
PLATFORM_SUBSECTION_ENUM :: enum {}
PLATFORM_SUBSECTION_NAMES :: string.[];

platform_config :: struct {
    scaling_factor: float = 0.0;
}

platform_parse_config_line :: (config: *platform_config, section: PLATFORM_SUBSECTION_ENUM, line: string) -> success: bool, error_msg: string {
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
        case; {
            error_msg := tprint("Unknown setting '%' in section '%'", setting, PLATFORM_CONFIG_SECTION);
            return false, error_msg;
        }
    }

    return true, "";
}

platform_apply_config :: (config: *platform_config) {
    LD.set_fixed_scaling(config.scaling_factor);
}

platform_setup :: inline () {
    backend := LD.BACKEND.PREFER_BEST_USER_EXPERIENCE;
    cstr := getenv("FOCUS_LD_BACKEND");
    backend_s := ifx cstr then to_string(cstr) else "";
    if equal_nocase(backend_s, "prefer-wayland") then backend = .PREFER_WAYLAND;
    if equal_nocase(backend_s, "prefer-x11") then backend = .PREFER_X11;
    if equal_nocase(backend_s, "wayland") then backend = .FORCE_WAYLAND;
    if equal_nocase(backend_s, "x11") then backend = .FORCE_X11;
    LD.init_display(backend);
}

platform_data_dir :: () -> string {
    data_dir := sprint("%/focus-editor", get_xdg_path(.DATA_HOME));
    make_directory_if_it_does_not_exist(data_dir);
    return data_dir;
}

platform_config_dir :: () -> string {
    config_dir := sprint("%/focus-editor", get_xdg_path(.CONFIG_HOME));
    make_directory_if_it_does_not_exist(config_dir);
    return config_dir;
}

platform_get_centered_window_dimensions :: (open_on_biggest: bool) -> s32, s32, s32, s32 {
    return 0, 0, 1920, 1080;
}

platform_create_window :: () {
    window = create_window(window_width, window_height, window_generic_title, window_x, window_y, background_color_rgb = as_3_floats(Colors.BACKGROUND));
}

platform_maximize_window :: (window: Window_Type) {
    LD.maximize_window(window);
}

platform_enable_drag_and_drop :: (window: Window_Type) {
    typelist := string.["url/url", "text/uri-list", "text/plain", "application/octet-stream"];  // @Incomplete: test this on Linux
    LD.enable_dnd(window, typelist);
}

platform_get_dpi_scale :: (window: Window_Type) -> float {
    return LD.get_dpi_scaling_factor(window);
}

platform_set_window_title :: (title: string) {
    LD.set_window_title(window, title);
}

platform_wait_message :: inline () {
}

platform_set_refresh_timer :: (window: Window_Type) {
}

platform_kill_refresh_timer :: (window: Window_Type) {
}

platform_enumerate_logical_drives :: () -> [] string {
    return .["/"];
}

platform_get_save_file_name :: (name := "") -> string, bool {
    print("name = '%'\n", name);
    return "", false;
    // return name;
}

platform_find_font_by_name :: (name: string, allocator := temp) -> bool, string {
    found, path := LD.find_font(name, allocator);
    return found, path;
}

platform_get_fonts_dir :: () -> string {
    return "/usr/share/fonts";
}

platform_open_in_explorer :: (path: string, reveal := false) {
}

#scope_file

XDG_Dir :: enum {
    DATA_HOME;
    CONFIG_HOME;
    STATE_HOME;
}

/*
 * @TODO: add a proper XDG path module
 * ref: https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
 */
get_xdg_path :: (dir: XDG_Dir) -> string {
    env_var: string;
    if #complete dir == {
        case .DATA_HOME;   env_var = "XDG_DATA_HOME";
        case .CONFIG_HOME; env_var = "XDG_CONFIG_HOME";
        case .STATE_HOME;  env_var = "XDG_STATE_HOME";
    }
    env_path := getenv(env_var.data);
    if env_path {
        ret := to_string(env_path);
        if starts_with(ret, "/") {
            if ends_with(ret, "/") && ret != "/" ret.count -= 1;
            return ret;
        }
    }

    pw := getpwuid(getuid());
    if pw {
        home := to_string(pw.pw_dir);
        if ends_with(home, "/") && home != "/" home.count -= 1;
        if #complete dir == {
            case .DATA_HOME;   return tprint("%/.local/share", home);
            case .CONFIG_HOME; return tprint("%/.config", home);
            case .STATE_HOME;  return tprint("%/.local/state", home);
        }
    }

    /* just fall back to executable directory */
    return path_strip_filename(get_path_of_running_executable());
}

Monitor :: struct {
    left   : int;
    top    : int;
    right  : int;
    bottom : int;
};

monitors : [..] Monitor;

LD :: #import "Linux_Display";
#import "Math";
#import "POSIX";
