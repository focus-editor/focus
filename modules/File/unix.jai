#import "POSIX";

File :: struct {
    handle: *FILE;
}

file_open :: (name: string, for_writing := false, keep_existing_content := false, log_errors := true) -> File, bool {
    c_name := temp_c_string(name);

    handle: *FILE;
    if for_writing && keep_existing_content {
        handle = fopen(c_name, "a+");
    } else if for_writing {
        handle = fopen(c_name, "wb+");
    } else {
        handle = fopen(c_name, "rb");
    }

    file: File;
    file.handle = handle;

    if !handle {
        if log_errors {
            error_code, error_string := System.get_error_value_and_string();
            log_error("Could not open file \"%\": code %, %", name, error_code, error_string);
        }

        return file, false;
    }

    return file, true;
}

// Moves an existing file or a directory, including its children.
file_move :: (name_old: string, name_new: string) -> bool {
    // @Robustness Moving / renaming files is a fragile enterprise.
    //             We should provide error messages when something goes wrong.
    return rename(temp_c_string(name_old), temp_c_string(name_new)) == 0;
}

file_delete :: (filename: string) -> bool {
    c_name := temp_c_string(filename);
    return _remove(c_name) == 0; // @Robustness Provide error message if it fails.
}

file_link :: (linkpath: string, filepath: string) -> bool {
    c_link := temp_c_string(linkpath);
    result := unlink(c_link);
    result = link(temp_c_string(filepath), c_link);
    return result == 0;
}

file_close :: (file: *File) {
    assert(file.handle != null);
    if file.handle  fclose(file.handle);
}

is_valid :: (file: File) -> bool {
    return file.handle != null;
}

// Reads at most `bytes_to_read` bytes from `f`.
// Returns success/failure and how many bytes were written in to vdata.
// If EOF is reached first, returns `(true, total_read)`.
// If an error occurs, returns `(false, total_read)`.
// Otherwise, returns `(true, bytes_to_read)`.
file_read :: (f: File, vdata: *void, bytes_to_read: s64) -> (success: bool, total_read: s64) {
    data := cast(*u8) vdata;
    if bytes_to_read <= 0  return false, 0;

    if data == null {
        log_error("Attempt to file_read() into a null destination pointer.\n");
        return false, 0;
    }

    single_read_length: s64 = xx fread(data, 1, xx bytes_to_read, f.handle);
    if single_read_length < bytes_to_read {
        if feof(f.handle) {
            return true, single_read_length;
        } else {
            return false, single_read_length;
        }
    }

    return true, bytes_to_read;
}

file_length :: (file: File) -> (length: s64, success: bool) {
    position_current := ftello64(file.handle);
    if (position_current == -1) || (position_current == DUMB_LINUX_FAILURE_NUMBER) return 0, false;

    fseek(file.handle, 0, SEEK_END);
    len := ftello64(file.handle);
    if (len == -1) || (len == DUMB_LINUX_FAILURE_NUMBER) return 0, false;

    fseek(file.handle, position_current, SEEK_SET);
    return len, true;
}

// gets the current file pointer offset.
file_current_position :: (f: File) -> s64, bool {
    res := ftello64(f.handle);
    return res, (res != -1) && (res != DUMB_LINUX_FAILURE_NUMBER);
}

file_set_position :: (f: File, pos: s64) -> bool {
    res := fseek(f.handle, pos, SEEK_SET);
    return res == 0;
}


read_entire_file :: (f: File, zero_terminated := false) -> string, bool {
    length, success := file_length(f);
    if !success  return "", false;

    zero_termination_size := cast(s32) zero_terminated;
    data := cast(*u8) alloc(length + zero_termination_size);
    if data == null return "", false;

    single_read_length := fread(data, 1, cast (u64) length, f.handle);
    // If "single_read_length" is shorter than "length" it might also be just EOF.
    // This is the case when reading from a Linux HID descriptor, for example.
    // fread doesn't distinguish between errors and EOF, so we need to test manually.
    if single_read_length != cast(u64) length && !feof(f.handle) {
        free(data);
        return "", false;
    }

    s: string;
    s.count = cast(s64) single_read_length;
    s.data  = data;

    if zero_terminated s.data[single_read_length] = 0;

    return s, true;
}


file_write :: (file: *File, data: *void, length: s64) -> bool {
	assert(length >= 0);
    written := fwrite(data, 1, cast(u64) length, file.handle);
    return written == cast(u64) length;
}

delete_directory :: (dirname: string) -> bool {
    // Sorry, this is bad. File_Utilities is supposed to be a higher-level library than File.
    // You can't import File_Utilities just to do File stuff. @Cleanup.
    Util :: #import "File_Utilities";

    success := true;
    directory_visitor_func :: (info: *Util.File_Visit_Info, success_pointer: *bool) {
        if info.is_directory && !info.is_symlink {
            // visit all children of this directory first so that they get deleted and this directory becomes empty.
            Util.visit_files(info.full_name, recursive=false, success_pointer, directory_visitor_func, visit_files=true, visit_directories=true);
        }

        result := _remove(temp_c_string(info.full_name));
        if result != 0 {
            error_code, error_string := System.get_error_value_and_string();
            log_error("Error while trying to delete \"%\": % %", info.full_name, error_code, error_string);
            <<success_pointer = false;
        }
    }

    Util.visit_files(dirname, recursive=false, *success, directory_visitor_func, visit_files=true, visit_directories=true);
    result := _remove(temp_c_string(dirname));
    if result != 0 {
        error_code, error_string := System.get_error_value_and_string();
        log_error("Error while trying to delete \"%\": % %", dirname, error_code, error_string);
        success = false;
    }

    return success;
}

file_seek :: (file: File, pos: s64, type: Seek_Type) -> (success: bool) {
    whence: s32;

    if type == .START          whence = SEEK_SET;
    else if type == .CURRENT   whence = SEEK_CUR;
    else if type == .END       whence = SEEK_END;
    else return false;

    result := fseek(file.handle, pos, whence);
    return result == 0;
}

file_tell :: (file: File) -> (success: bool, position: s64) {
    position := ftello64(file.handle);
    success := (position != -1) && (position != DUMB_LINUX_FAILURE_NUMBER);
    return success, position;
}

// ftell on Linux sometimes returns this number, for example,
// when doing ftell on a directory. Why? I don't fricking know.
DUMB_LINUX_FAILURE_NUMBER :: 0x7fff_ffff_ffff_ffff;

#scope_module

os_make_directory_if_it_does_not_exist :: (name: string) -> directory_now_exists: bool {
    RWX_ALL :: 0x1FF; // 0x177 == 0777octal
    return make_directory_helper(name, RWX_ALL);
}

make_directory_helper :: (dir_name: string, attribs: mode_t) -> directory_now_exists: bool {
    success := mkdir(temp_c_string(dir_name), attribs);

    if success == 0 return true;
    if errno() == EEXIST return true;

/*
    For now we are only using this for stuff that is one folder deep.
    If we want recursive creation we can make the below stuff work.
    if err == ERROR_PATH_NOT_FOUND {
        s := strrchr(c_name, '\\');
        if (!s) s = strrchr(c_name, '/');

        if (!s) return false;  // We seem to have failed!


        // Stop the last slash, so we travel upward one directory, and try again, recursively.
        int len = s - dir_name;
        char *t = new char[len + 1];
        memcpy(t, dir_name, len);
        t[len] = '\0';
        Delete_Array_On_Return(t, char);
        bool worked_now = make_directory_helper(t, attribs);
		if (worked_now) success = CreateDirectory(dir_name, attribs);
		if (success) return true;
    }
*/
	return false;
}

get_absolute_path_unix :: (relative_path: string) -> string, success: bool {
    relative_path_c := to_c_string(relative_path);
    defer free(relative_path_c);  // Could use a temporary allocator here.

    PATH_MAX :: 4096;  // @Stability: this constant could be different on different UNIXes.
    buf: [PATH_MAX] u8;
    result := realpath(relative_path_c, buf.data);
    if result == null {
        error_code, error_string := System.get_error_value_and_string();
        log_error("Could not convert relative path to absolute path: % %", error_code, error_string);
        return "", false;
    }

    return copy_temporary_string(to_string(buf.data)), true;
}




#scope_file
System :: #import "System";
