// Windows version.

//
// @Cleanup @Speed: This file is getting loaded by Default_Metaprogram.jai,
// and this file imports modules/Windows, which is big, even though it needs
// very little. So we are including modules/Windows in *every* program unless
// they override Default_Metaprogram. Presumedly the same is true for modules/POSIX.
// So we should probably refactor this so that it declares its own stuff.
// If we want HANDLE here to be locally-defined but the same type as modules/Windows.HANDLE,
// that might get trickier; we could have a module parameter that determines whether
// we import Windows just for HANDLE.
//
// That said, this also imports modules/System, which also imports Windows, so we
// would have to do more work for that as well. Possibly we should factor
// get_error_value_and_string() out into its own small module.
//
File :: struct {
    handle: HANDLE;
}

file_open :: (name: string, for_writing := false, keep_existing_content := false, log_errors := false) -> File, bool {
    handle: HANDLE;
    if for_writing {
        mode: u32;
        if keep_existing_content mode = OPEN_ALWAYS;
        else mode = CREATE_ALWAYS;
        handle = CreateFileW(utf8_to_wide(name,, allocator=temp), FILE_GENERIC_READ | FILE_GENERIC_WRITE, FILE_SHARE_READ, creation = mode);
    } else {
        handle = CreateFileW(utf8_to_wide(name,, allocator=temp), FILE_GENERIC_READ);
    }

    if handle == INVALID_HANDLE_VALUE {
        if log_errors {
            error_code, error_string := System.get_error_value_and_string();
            log_error("Could not open file \"%\": code %, %", name, error_code, error_string);
        }

        return .{}, false;
    }

    file: File;
    file.handle = handle;

    return file, true;
}

file_close :: (file: *File) {
    CloseHandle(file.handle);
}

// Moves an existing file or a directory, including its children.
file_move :: (name_old: string, name_new: string) -> bool {
    // @Robustness Moving / renaming files is a fragile enterprise.
    //             We should provide error messages when something goes wrong.
    return MoveFileW(utf8_to_wide(name_old,, allocator=temp), utf8_to_wide(name_new,, allocator=temp)) != 0;
}

file_delete :: (filename: string) -> bool {
    c_name := utf8_to_wide(filename,, allocator=temp);
    return DeleteFileW(c_name) != 0; // @Robustness Provide error message if it fails.
}

file_link :: (link : string, filepath : string) -> bool {
    c_link := utf8_to_wide(link,, allocator=temp);
    DeleteFileW(c_link);
    return CreateHardLinkW(c_link, utf8_to_wide(filepath), null) != 0; // @Robustness Provide error message if it fails.
}

is_valid :: (file: File) -> bool {
    return file.handle != null;
}

// Reads at most `bytes_to_read` bytes from `f`.
// Returns success/failure and how many bytes were written in to vdata.
// If EOF is reached first, returns `(true, total_read)`
// If an error occurs, returns `(false, total_read)`.
// Otherwise, returns `(true, bytes_to_read)`.
// Limitations:
//  * `f.handle` must not have been opened with `FILE_FLAG_OVERLAPPED` (async mode)
//  * More advanced handling of pipes is not supported, we assume `f.handle` behaves roughly
//    like a normal file
file_read :: (f: File, vdata: *void, bytes_to_read: s64) -> (success: bool, total_read: s64) {
    data := cast(*u8) vdata;

    if bytes_to_read <= 0  return false, 0;
    if data == null {
        log_error("Attempt to file_read() into a null destination pointer.\n");
        return false, 0;
    }

    total_read: s64 = 0;

    // this loop is just to read more data than can be specified
    // in the DWORD param ReadFile takes.
    while total_read < bytes_to_read {
        remaining := bytes_to_read - total_read;
        to_read : DWORD;
        if remaining <= 0x7fffffff {
            to_read = cast(DWORD) remaining;
        } else {
            to_read = 0x7fffffff;
        }

        single_read_length: DWORD = 0;
        read_success := ReadFile(f.handle, data + total_read, to_read, *single_read_length);
        total_read += single_read_length;
        if !read_success {
            // we hit an error
            return false, total_read;
        }
        
        if single_read_length == 0 {
            // we hit EOF
            return true, total_read;
        }
    }

    return true, total_read;
}

file_length :: (file: File) -> s64, bool {
    size: LARGE_INTEGER;
    ret := GetFileSizeEx(file.handle, *size);
    return size.QuadPart, ret != 0;
}

// Gets the current file pointer offset.
file_current_position :: (f: File) -> s64, bool {
    off: LARGE_INTEGER_S64;
    ret := SetFilePointerEx(f.handle, 0, *off, FILE_CURRENT);
    return off, ret != 0;
}

file_set_position :: (f: File, pos: s64) -> bool {
    ret := SetFilePointerEx(f.handle, pos, null, FILE_BEGIN);
    return ret != 0;
}

read_entire_file :: (f: File, zero_terminated := false) -> string, bool {
    s: string;

    size_struct: LARGE_INTEGER; // Kind of pointless, just pass *s64?
    size_success := GetFileSizeEx(f.handle, *size_struct);
    if !size_success return s, false;

    length : s64 = size_struct.QuadPart;
    zero_termination_size := 0;
    if zero_terminated zero_termination_size = 1;

    data := alloc(length + zero_termination_size);
    if data == null return s, false;

    single_read_length: DWORD;
    total_read:  s64;

    // Move file pointer to the beginning of the file.
    previous_pos, tell_success := file_current_position(f);
    if !tell_success {
        return s, false;
    }

	set_success := file_set_position(f, 0);
    if !set_success {
        return s, false;
    }

    while total_read < length {
        remaining := length - total_read;
        to_read : DWORD;
        if remaining <= 0x7fffffff {
            to_read = cast(DWORD) remaining;
        } else {
            to_read = 0x7fffffff;
        }

        ReadFile(f.handle, data + total_read, to_read, *single_read_length);
        if single_read_length <= 0 {  // @Robustness: Probably we are supposed to check the return code. We should also check for ERROR_IO_PENDING specifically.
            free(data);
            return s, false;
        }

        total_read += single_read_length;
    }

    s.count = length;
    s.data = data;

    if zero_terminated s.data[length] = 0;

    // Restore position.
    if !file_set_position(f, previous_pos) {
        return s, false;
    }

    return s, true;
}

File_Map_Info :: struct {
    file: File = .{ INVALID_HANDLE_VALUE };
    mapping: HANDLE = null;
    data: string;
}

map_file :: (name: string, log_errors := true) -> File_Map_Info, bool {
    ret: bool;
    file_map: File_Map_Info;

    file_map.file, ret = file_open(name, false, false, log_errors);
    if (ret) {
        length, ret := file_length(file_map.file);
        if length == 0 return file_map, true;
        file_map.mapping = CreateFileMappingW(file_map.file.handle, null, PAGE_READONLY, 0, 0, null);

        if (file_map.mapping && ret) {
            pointer := MapViewOfFile(file_map.mapping, FILE_MAP_READ, 0, 0, xx length);
            if pointer {
                file_map.data.count = length;
                file_map.data.data = pointer;

                return file_map, true;
            }
        }
    }

    if (log_errors) {
        error_code, error_string := System.get_error_value_and_string();
        log_error("Could not map file \"%\": code %, %", name, error_code, error_string);
    }

    munmap_file(*file_map);
    return .{}, false;
}

munmap_file :: (file_map: *File_Map_Info) -> bool {
    if (file_map.file.handle != INVALID_HANDLE_VALUE) {
        if (file_map.mapping) {
            if (file_map.data.data) {
                Windows.UnmapViewOfFile(file_map.data.data);
                file_map.data.data = null;
                file_map.data.count = 0;
            }

            CloseHandle(file_map.mapping);
            file_map.mapping = null;
        }
        file_close(*file_map.file);
        file_map.file.handle = INVALID_HANDLE_VALUE;
        return true;
    }

    return false;
}


// @@ Move to Windows.jai ?
CSIDL_APPDATA :: 0x001a;

KF_FLAG_CREATE :: 0x00008000;
FOLDERID_SavedGames_uid_string :: "4C5C32FF-BB9D-43b0-B5B4-2D72E54EAAA4";


// Path to typical OS folder where programs store local data.
get_path_os_program_data :: () -> string /* Allocated using 'alloc' */ {
    // Shell32.dll is a GIANT PIG (it takes 32ms to load!)
    // So we avoid depending on it unless we have to.
    // Dead code elimination means we won't pull it in unless
    // you call this.

    shell32  :: #system_library "shell32";

    SHGetFolderPathA :: (hwndOwner: HWND, nFolder: s32, hToken: HANDLE, dwFlags: u32, pszPath: *u8)  -> HRESULT #foreign shell32 #deprecated "Use SHGetFolderPathW instead.";
    SHGetFolderPathW :: (hwndOwner: HWND, nFolder: s32, hToken: HANDLE, dwFlags: u32, pszPath: *u16) -> HRESULT #foreign shell32;

    path := cast(*u16) alloc((MAX_PATH + 1) * size_of(u16),, __temporary_allocator);
    result : HRESULT = SHGetFolderPathW(null, CSIDL_APPDATA, null, 0, path);
    assert(result == S_OK); // @Robustness Provide error message for user instead

    return wide_to_utf8(path);
}

get_path_os_saved_games :: () -> string /* Allocated using 'alloc' */ {
    // Windows is terrible. SHGetKnownFolderPath returns you something that you need to free with CoTaskMemFree,
    // which is in ole32.dll.
    // Note that THIS IS OUR ONLY DEPENDENCY ON OLE32.
    // We put it here so that you don't take the dependency unless you call this function
    // (unless dead code elimination is off!).
    ole32    :: #system_library "ole32";
    shell32  :: #system_library "shell32";

    SHGetKnownFolderPath :: (nFolder: REFGUID, dwFlags: DWORD, hToken: HANDLE, pszPath: **u16) -> HRESULT #foreign shell32;
    CoTaskMemFree :: (microsoft_is_not_good: *void) #foreign ole32;

    id := uid(FOLDERID_SavedGames_uid_string);

    path_data: *u16;
    hr := SHGetKnownFolderPath(*id, KF_FLAG_CREATE, null, *path_data);
    defer CoTaskMemFree(path_data);
    if !SUCCEEDED(hr) return "";

    return wide_to_utf8(path_data);
}

file_write :: (file: *File, data: *void, length: s64) -> bool {
    // Win32 version .. @Generalize
    // I *think* WriteFile will block until it writes everything, as long as the file is not set to nonblocking... ?

    // @Incomplete: Deal with inputs > 32 bits.

    length32 := cast(u32) length;
    assert(length32 == length);

    written: u32;
    status := WriteFile(file.handle, data, length32, *written, null);

    return cast(bool) status;
}


// This could be implemented manually with DeleteFile and RemoveDirectory, but that probably belongs to File_Utils?
/*
delete_directory :: (dirname: string) {
    proc :: (info: *File_Visit_Info, user_data: *void) {
        if info.is_directory {
            directory_delete(info.full_name);
        }
        else {
            DeleteFile(info.full_name);
        }
    }

    visit_files(dir_name, recursive=false, null, proc, visit_files=true, visit_directories=true);
}
*/

delete_directory :: (dirname: string) -> bool {
    // SHFileOperationW must be called with absolute paths, so we need to convert the path first
    wide, success, length := utf8_to_wide(dirname,, allocator=temp);

    full_path_size := GetFullPathNameW(wide, 0, null, null);
    if !full_path_size {
        error_code, error_string := System.get_error_value_and_string();
        log_error("In delete_directory(), GetFullPathNameW (without buffer) failed: % %", error_code, error_string);
        return false;
    }

    absolute_path_wide: *u16 = temporary_alloc((full_path_size + 1) * 2); // +1 for the extra null at the end that’s needed by SHFileOperationW
    final_length := GetFullPathNameW(wide, full_path_size, absolute_path_wide, null);
    if !final_length {
        error_code, error_string := System.get_error_value_and_string();
        log_error("In delete_directory(), GetFullPathNameW (with buffer) failed: % %", error_code, error_string);
        return false;
    }

    assert(final_length <= full_path_size - 1); // -1 because on success, it does NOT include the null character, but on failure it does. This used to be ==, but in some cases we get a shorter path... I guess the return value of GetFullPathNameW is inexact in some cases!
    // Add the extra null character after the string-terminating null character.
    absolute_path_wide[final_length + 1] = 0;

    file_op: SHFILEOPSTRUCTW;
    file_op.wFunc  = FO_DELETE;
    file_op.pFrom  = absolute_path_wide;
    file_op.fFlags = FOF_NO_UI;

    result := SHFileOperationW(*file_op);
    if result != 0 {
        log_error("In delete_directory(), SHFileOperationW returned error code %.\n", result);
        return false;
    } else if file_op.fAnyOperationsAborted {
        log_error("In delete_directory(), SHFileOperationW was not able to delete everything (fAnyOperationsAborted was true).\n");
        return false;
    } else {
        return true;
    }
}

file_seek :: (file: File, pos: s64, type: Seek_Type) -> (success: bool) {
    method: SetFilePointer_MoveMethod;

    if type == .START          method = .FILE_BEGIN;
    else if type == .CURRENT   method = .FILE_CURRENT;
    else if type == .END       method = .FILE_END;
    else return false;

    result := SetFilePointerEx(file.handle, pos, null, method);
    if result return true;

    return false;
}

file_tell :: (file: File) -> (success: bool, position: s64) {
    position: s64;

    result := SetFilePointerEx(file.handle, 0, *position, FILE_CURRENT);
    if !result return false, 0;

    return true, position;
}

#scope_module

os_make_directory_if_it_does_not_exist :: (name: string) -> directory_now_exists: bool {
    // @Cleanup: Re-inline this.
    return make_directory_helper(name, null);
}

make_directory_helper :: (dir_name: string, attribs: *SECURITY_ATTRIBUTES) -> directory_now_exists: bool {
    // -12 comes from it also needing to include 8.3 for file names
    MAX_DIRECTORY_PATH :: MAX_PATH - 12;

    LONG_PATH_PREFIX :: "\\\\?\\";

    path_wide := utf8_to_wide(dir_name,, allocator=temp);

    // CreateDirectory does not support paths larger than MAX_DIRECTORY_PATH unless they start with LONG_PATH_PREFIX
    if !begins_with(dir_name, LONG_PATH_PREFIX) {
        full_path_size := GetFullPathNameW(path_wide, 0, null, null); // returns the size in WCHARs _including_ the terminating 0.
        if !full_path_size {
            error_code, error_string := System.get_error_value_and_string();
            log_error("In make_directory_helper(), GetFullPathNameW (without buffer) failed: % %", error_code, error_string);
            return false;
        }

        if full_path_size > MAX_DIRECTORY_PATH {
            prefixed_full_path_size := full_path_size + LONG_PATH_PREFIX.count; // Size in WCHARs with the prefix
            full_path_wide: *u16 = temporary_alloc(prefixed_full_path_size * 2);
            memcpy(full_path_wide, utf8_to_wide(LONG_PATH_PREFIX,, allocator=temp), LONG_PATH_PREFIX.count * 2); // @Speed: do this utf8_to_wide() only once, at compile time?
            real_full_path_size := GetFullPathNameW(path_wide, full_path_size, full_path_wide + LONG_PATH_PREFIX.count, null); // returns the size in WCHARs _not including_ the terminating 0.

            if !real_full_path_size {
                error_code, error_string := System.get_error_value_and_string();
                log_error("In make_directory_helper(), GetFullPathNameW (with buffer) failed: % %", error_code, error_string);
                return false;
            }
            assert(real_full_path_size <= full_path_size - 1); // -1 because on success, it does NOT include the null character, but on failure it does. This used to be ==, but in some cases we get a shorter path... I guess the return value of GetFullPathNameW is inexact in some cases!

            path_wide = full_path_wide;
        }
    }

    success := CreateDirectoryW(path_wide, attribs);

    if success return true;

    err := GetLastError();
    if err == ERROR_ALREADY_EXISTS return true;

	return false;

/*
    For now we are only using this for stuff that is one folder deep.
    If we want recursive creation we can make the below stuff work.

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
}

get_absolute_path_windows :: (relative_path: string) -> string, success: bool {
    relative_path_wide, success, length := utf8_to_wide(relative_path,, allocator=temp);
    if !success return "", false;

    full_path_size := GetFullPathNameW(relative_path_wide, 0, null, null);
    if !full_path_size {
        error_code, error_string := System.get_error_value_and_string();
        log_error("In get_absolute_path(), GetFullPathNameW (without buffer) failed: % %", error_code, error_string);
        return "", false;
    }

    absolute_path_wide: *u16 = temporary_alloc(full_path_size * 2);
    final_length := GetFullPathNameW(relative_path_wide, full_path_size, absolute_path_wide, null);
    if !final_length {
        error_code, error_string := System.get_error_value_and_string();
        log_error("In get_absolute_path(), GetFullPathNameW (with buffer) failed: % %", error_code, error_string);
        return "", false;
    }

    assert(final_length <= full_path_size - 1); // -1 because on success, it does NOT include the null character, but on failure it does. This used to be ==, but in some cases we get a shorter path... I guess the return value of GetFullPathNameW is inexact in some cases!

    return wide_to_utf8(absolute_path_wide, length = cast(s32) final_length,, temp), true;
}


#scope_file


Windows      :: #import "Windows";
Windows_Utf8 :: #import "Windows_Utf8";
System       :: #import "System";

using Windows;
using Windows_Utf8;
