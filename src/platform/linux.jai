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

platform_setup :: () {
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

platform_get_fonts_dir :: () -> string {
    return "/usr/share/fonts";
}

platform_open_in_explorer :: (dir: string) {
}

#scope_file

Monitor :: struct {
    left   : int;
    top    : int;
    right  : int;
    bottom : int;
};

monitors : [..] Monitor;

LD :: #import "Linux_Display";
#import "Math";
