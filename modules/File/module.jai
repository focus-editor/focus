#if OS == {
    case .WINDOWS;    #load "windows.jai";
    case .PS5;        #load "ps5.jai";
    case;             #load "unix.jai";
}


file_write :: inline (file: *File, data: string) -> bool {
    return file_write(file, data.data, data.count);
}

file_write :: (file: *File, builder: *String_Builder, do_reset := true) -> bool {
    defer if do_reset reset(builder);   // Don't leak the builder, even if we get an error in the middle.

    buffer := get_base_buffer(builder);
    while buffer {
        success := file_write(file, get_buffer_data(buffer), buffer.count);
        if !success return false;

        buffer = buffer.next;
    }

    return true;
}

write_entire_file :: inline (name: string, data: string) -> bool {
    return write_entire_file(name, data.data, data.count);
}

write_entire_file :: (name: string, data: *void, count: int) -> bool {
    file, success := file_open(name, for_writing=true, keep_existing_content=false);
    if !success return false;

    defer file_close(*file);

    return file_write(*file, data, count);
}

write_entire_file :: (name: string, builder: *String_Builder, do_reset := true) -> bool {
    file, success := file_open(name, for_writing=true, keep_existing_content=false);
    if !success {
        if do_reset reset(builder);
        return false;
    }

    defer file_close(*file);

    return file_write(*file, builder, do_reset);
}

read_entire_file :: (name: string, zero_terminated := false, log_errors := true) -> string, bool {
    s: string;
    f, success := file_open(name, log_errors = log_errors);
    if !success return s, false;

    defer file_close(*f);

    s, success = read_entire_file(f, zero_terminated);

    if log_errors && !success {
        System :: #import "System";

        // If we put this error report at a lower level, we could
        // indicate how far into the file the error occurred, etc.
        code, s := System.get_error_value_and_string();
        log("Read of '%' failed: code %, '%'.\n", name, code, s);
    }

    return s, success;
}

USE_MAP_FILE :: (OS == .WINDOWS);
STORE_MAPPED_FILENAMES :: false;

Map_File_Info :: struct {
    data: string;
    #if STORE_MAPPED_FILENAMES {
        filename: string;
    }
    #if USE_MAP_FILE {
        map_info: File_Map_Info;
    }
}

string_to_map_file_info :: (data: string) -> Map_File_Info {
    file_info: Map_File_Info;
    file_info.data = data;
    return file_info;
}

map_entire_file_start :: (name: string, log_errors := true) -> Map_File_Info, bool {
    file_info: Map_File_Info;

#if USE_MAP_FILE {
    map_info, ret := map_file(name, log_errors);
    if (ret) {
        file_info.data = map_info.data;
        #if STORE_MAPPED_FILENAMES {
            file_info.filename = copy_string(name);
        }
        file_info.map_info = map_info;
        return file_info, true;
    }
} else {
    data, ret := read_entire_file(name, false, log_errors);
    if (ret) {
        file_info.data = data;
        #if STORE_MAPPED_FILENAMES {
            file_info.filename = copy_string(name);
        }
        return file_info, true;
    }
}

    return .{}, false;
}

map_entire_file_end :: (file_info: *Map_File_Info) {
    free_data := true;

    #if USE_MAP_FILE {
        free_data = !munmap_file(*file_info.map_info);
    }

    if (free_data) {
        free(file_info.data);
    }
    file_info.data = "";

    #if STORE_MAPPED_FILENAMES {
        if (file_info.filename) {
            free(file_info.filename);
            file_info.filename = "";
        }
    }
}

// We could add here a read_entire_file_chunked that returns a String_Builder, with bucket
// size equal to some parameter. Maybe that parameter could even be a String_Builder if we
// make that be a

// read_entire_file_chunked :: (name: string, $chunk_size: s64) -> Chunk_List(chunk_size), bool { ... }


// NOTE: this function is the reason why we vendored this modules, it contains a fix for Windows by SirPinecone from the beta community.
// When this is fixed upstream we'll remove the vendored module

make_directory_if_it_does_not_exist :: (name: string, recursive := false) -> directory_now_exists: bool {
    if !name return false;

    if recursive {
        start_index := 0;

        #if OS == .WINDOWS {
            // Windows doesn't allow creating a root directory, e.g. "x:" or "x:\\".
            // To create subdirectories in an absolute path, we must skip the root
            // part to avoid returning early due to failure.
            if (name.count > 3) && (name[1] == #char ":") {
                start_index = 3;
            }
        }

        if name[0] == #char "/" start_index = 1;

        index := find_index_from_left(name, #char "/", start_index);
        #if OS == .WINDOWS {
            if index == -1 {
                index = find_index_from_left(name, #char "\\", start_index);
            }
        }

        while index != -1 {
            success := os_make_directory_if_it_does_not_exist(slice(name, 0, index));
            if !success return false;
            // Look for the next slash. If there are multiple slashes in a row then use the last one.
            while true {
                start_index = index + 1;
                index = find_index_from_left(name, #char "/", start_index);
                #if OS == .WINDOWS {
                    if index == -1 {
                        index = find_index_from_left(name, #char "\\", start_index);
                    }
                }
                if index != start_index then break;
            }
        }

        if name.count - start_index == 0 {
            // We already created the innermost directory.
            return true;
        }
    }

    return os_make_directory_if_it_does_not_exist(name);
}


// Converts a relative path to an absolute one.
// The return value is allocated using the temporary allocator.
//
// The unix version of this function fails if the path does not exist.
// The Windows version does not fail for non-existing files.
// I haven’t found a way around this.
// -rluba, 2023-01-09
get_absolute_path :: inline (relative_path: string) -> string, success: bool {
    #if OS == .WINDOWS {
        absolute_path, success := get_absolute_path_windows(relative_path);
    } else {
        absolute_path, success := get_absolute_path_unix(relative_path);
    }

    return absolute_path, success;
}

#scope_module

Seek_Type :: enum {
    START     :: 0;
    CURRENT   :: 1;
    END       :: 2;
}

#import "Basic";
#import "String";
