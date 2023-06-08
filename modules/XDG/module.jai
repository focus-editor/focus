/*
 * ref: https://freedesktop.org/wiki/Specifications/
 */

#assert(OS == .LINUX);

/*
 * Base Directory Specification
 * https://specifications.freedesktop.org/basedir-spec/latest/
 */
KnownDirectory :: enum {
    DATA_HOME;
    CONFIG_HOME;
    STATE_HOME;
    CACHE_HOME;
}

get_path :: (dir: KnownDirectory, allocator := context.allocator) -> string {
    env_var: string;
    if #complete dir == {
        case .DATA_HOME;   env_var = "XDG_DATA_HOME";
        case .CONFIG_HOME; env_var = "XDG_CONFIG_HOME";
        case .STATE_HOME;  env_var = "XDG_STATE_HOME";
        case .CACHE_HOME;  env_var = "XDG_CACHE_HOME";
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
            case .CACHE_HOME;  return tprint("%/.cache", home);
        }
    }

    /* just fall back to executable directory */
    return path_strip_filename(get_path_of_running_executable());
}

/*
 * Utils
 */
open :: (path: string, reveal_in_explorer := false) {
    status, explorer_desktop_file := run_command(
        "xdg-mime", "query", "default", "inode/directory",
        capture_and_return_output = true);
    print("explorer_desktop_file=%\n", trim(explorer_desktop_file));

    // args : [2]string = .["xdg-open", path];
    run_command("xdg-open", path);
}

#scope_module
#import "Basic";
#import "String";
#import "System";
#import "POSIX";
#import "Process";
