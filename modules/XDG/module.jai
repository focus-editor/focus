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
open :: (path: string, reveal_in_explorer := false) -> bool {
    started_ok :: (status: Process_Result) -> bool {
        if #complete status.type == {
            case .UNSTARTED; #through;
            case .FAILED_TO_LAUNCH; #through;
            case .SIGNALED; return false;
            case .STILL_RUNNING; return true;
            case .EXITED; return status.exit_code == 0;
        }
    }

    extract_name_of_explorer :: (desktop_file: string) -> success: bool, exec: string {
        exec_key :: "Exec=";

        full_path: string;
        if find_index_from_left(desktop_file, "/") >= 0 full_path = copy_string(desktop_file);
        else full_path = sprint("/usr/share/applications/%", desktop_file);
        defer free(full_path);

        data, loaded := read_entire_file(full_path);
        if !loaded return false, "";
        defer free(data);

        pos := find_index_from_left(data, exec_key);
        if pos < 0 return false, "";
        while (pos > 0) && (data[pos - 1] != #char "\n") {
            pos = find_index_from_left(data, exec_key, pos + 1);
        }
        if pos < 0 return false, "";

        pos += exec_key.count;
        s := slice(data, pos, data.count - pos);
        pos = find_index_from_left(s, "\n");
        if pos >= 0 s = slice(s, 0, pos);

        pieces := break_command_into_strings(s);
        defer array_reset(*pieces);
        assert(pieces.count > 0);

        return true, copy_string(pieces[0]);
    }

    get_file_name :: (path: string) -> string {
        pos := find_index_from_right(path, "/");
        return ifx pos < 0 then path else slice(path, pos + 1, path.count - (pos + 1));
    }

    // We expect children to be reaped externally since some of the things we run here
    // may be long-running (like file managers). Thus we need a version of `run_command()`
    // that does not kill/reap the child itself.
    //
    // @TODO: This version is extremely dumb/simple. We need a better way to track/reap
    //        children that doesn't depend on external help.
    run :: (arg: ..string) -> result: Process_Result, output: string {
        result: Process_Result;
        process: Process;
        if !create_process(*process, ..arg, capture_and_return_output = true) return result, "";

        result.type = .STILL_RUNNING;
        output: [512]u8;
        error: [512]u8;
        success, out_bytes, err_bytes := read_from_process(*process, output, error);
        if !success {
            result.type = .EXITED;
            result.exit_code = 126;
            return result, "";
        }

        return result, copy_string(to_string(output.data, out_bytes));
    }

    if !reveal_in_explorer {
        process: Process;
        return create_process(*process, "xdg-open", path);
    }

    status, output := run("xdg-mime", "query", "default", "inode/directory");
    if !started_ok(status) return false;
    defer free(output);
    explorer_desktop_file := trim(output);
    if !ends_with(explorer_desktop_file, ".desktop") return false;

    found, exec := extract_name_of_explorer(explorer_desktop_file);
    if !found return false;
    defer free(exec);

    file_name := get_file_name(exec);
    if file_name == {
        case "dolphin"; #through;
        case "nautilus"; {
            process: Process;
            return create_process(*process, exec, "--select", path);
        }
    }

    return false;
}

#scope_module
#import "Basic";
#import "String";
#import "System";
#import "POSIX";
#import "Process";
#import "File";
