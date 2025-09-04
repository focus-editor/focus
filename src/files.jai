get_file_info_from_full_path :: (abs_path: string, proj_prefix_len := -1) -> File_Info {
    assert(is_absolute_path(abs_path), "Trying to get file info from a non-absolute path. This is a bug.");

    full_path := copy_string(abs_path);  // one allocation, the rest are views into it
    path, basename, extension, name := path_decomp(full_path);

    info: File_Info;
    info.full_path = full_path;
    info.name = name;
    if ends_with(path, "/") then path.count -= 1;  // strip the separator
    info.path = path;

    if proj_prefix_len <= 0 {
        for project_dirs {
            if begins_with_nocase(path, it.path) && it.path_prefix_len > proj_prefix_len {
                proj_prefix_len = it.path_prefix_len;
                info.project_dir_id = xx (it_index + 1);
            }
        }
    }
    if proj_prefix_len > 0 then info.path = advance(info.path, proj_prefix_len);

    info.icon = get_file_icon(name, extension);

    return info;
}

find_focus_config_file_in_directory :: (dir_path: string) -> string /* temp */ {
    is_dir, success := is_directory(dir_path);
    if !is_dir || !success return "";

    config_files: [..] string;
    config_files.allocator = temp;

    visitor_func :: (file: *File_Visit_Info, config_files: *[..] string) {
        if ends_with_nocase(file.full_name, ".focus-config") {
            full_path := copy_temporary_string(file.full_name);
            path_overwrite_separators(full_path, #char "/");
            array_add_if_unique(config_files, full_path);
        }
    }

    visit_files(dir_path, recursive = false, *config_files, visitor_func, visit_directories = false);

    if !config_files return "";

    if config_files.count == 1 return config_files[0];  // found exactly one file, this is what we want

    result := "";

    if config_files.count > 1 {
        for config_files {
            path, basename, extension, name := path_decomp(it);
            if platform_path_equals(name, ".focus-config") {
                result = it;  // if the config file is named exactly `.focus-config`, it takes priority
                break;
            }
        }
        error_message := tprint("Found multiple .focus-config files:%", join(..config_files, separator = "\n- ", before_first = true));
        if result {
            error_message = tprint("%\nUsed '%' as config", error_message, result);
            add_user_warning(error_message);
        } else {
            error_message = tprint("%\nNo config was loaded.", error_message);
            add_user_error(error_message);
        }
    }

    return result;
}

get_file_icon :: (name: string, extension: string) -> Icon {
    icon := Icon.file_unknown;

    if extension == {
        case "jai";
            icon = .jai;
        case "c";   #through;
        case "h";   #through;
        case "inl"; #through;
        case "cpp"; #through;
        case "cxx"; #through;
        case "c++"; #through;
        case "hpp"; #through;
        case "ipp"; #through;
        case "cc";  #through;
        case "m";   #through;
        case "mm";
            icon = .cpp;
        case "cs";
            icon = .cs;
        case "ini";  #through;
        case "conf"; #through;
        case "focus-config";
            icon = .gear;
        case "jpg";  #through;
        case "jpeg"; #through;
        case "png";  #through;
        case "tif";  #through;
        case "tiff"; #through;
        case "gif";
            icon = .image;
        case "bat";   #through;
        case "sh";    #through;
        case "bash";  #through;
        case "zsh";
            icon = .shell;
        case "ogg";  #through;
        case "wav";  #through;
        case "mp3";
            icon = .audio;
        case "txt";  #through;
        case "md";
            icon = .text;
        case "ttf";  #through;
        case "otf";
            icon = .font;
        case "js";
            icon = .js;
    }

    // Special cases
    if icon == .text && equal_nocase(name, "log.md") then icon = .todo;
    if icon == .text || icon == .file_unknown {
        if contains_nocase(name, "license") || contains_nocase(name, "licence")  || contains_nocase(name, "key") {
            icon = .key;
        } else if contains_nocase(name, ".git") {
            icon = .git;
        }
    }

    return icon;
}

get_lowercase_extension :: (path: string, greedy := true) -> string /* temp */, found_extension: bool {
    // NOTE: not using path_extension because it won't handle filenames with multiple dots as expected (e.g. lib.so.1.1)
    just_path := path_strip_filename(path);
    basename_with_extension := advance(path, just_path.count);
    index := 0;
    if greedy {
        // file.1.jai -> 1.jai
        index = find_index_from_left(basename_with_extension, cast(u8) #char ".");
    } else {
        // file.1.jai -> jai
        index = find_index_from_right(basename_with_extension, cast(u8) #char ".");
    }
    if index < 0 return "", false;
    extension := advance(basename_with_extension, index + 1);
    if !extension return "", false;

    return to_lower_copy(extension,, allocator = temp), true;
}

is_file_binary :: (file_data: string) -> bool {
    // Check for zeroes in the file - if there are any, it's not a well-formed text file.
    // There's a small chance that a binary file will have no zeroes, but it's the easiest
    // thing to check, so that's what we're doing.
    has_zeroes := find_index_from_left(file_data, byte = 0) >= 0;
    return has_zeroes;
}

should_ignore_file :: (path: string, check_for_zeroes_if_needed := true) -> bool {
    should_ignore, explicitly_allowed := should_ignore_path(path);
    if should_ignore return true;
    if explicitly_allowed return false;

    // If we haven't decided yet whether to ignore or allow, do some extra checks
    extension, found_extension := get_lowercase_extension(path);
    if found_extension {
        known, file_type := is_known_file_extension(extension);
        if known {
            if file_type == .text   return false;
            if file_type == .binary return true;
        }
    }

    #if OS != .WINDOWS {
        /*
         * Even if a certain path is not ignored we still only really want to know about
         * **regular** files.
         *
         * The `File_Visit_Info` structs that `visit_files()` generates as parameters to
         * the visitor callback would idealy have all the info we need to filter things at
         * a higher level. However, this is not currently the case - they only have information
         * on wether a certain path is a directory or a symlink, with anything that is not one
         * of those things being assumed to be a file. This is not the case on non-Windows OSes
         * (the filesystem can contain pipes (FIFOs), sockets, device files, etc).
         *
         * We could fork the `File_Utilities` module and add the info we need there. That,
         * however, requires more effort than I'm willing to put in right now. Instead,
         * I'm going to do an extra `stat()` here and simply ignore anything that's not a
         * regular file.
         */

        POSIX :: #import "POSIX";

        stats: POSIX.stat_t;
        if POSIX.stat(temp_c_string(path), *stats) < 0 return true;
        if !POSIX.S_ISREG(stats.st_mode) return true;
    }

    if !check_for_zeroes_if_needed return false;

    // Ignore binary files - it's not a 100% guarantee but a good heuristic.
    // We're not using read_entire_file here because this function is used when scanning workspace
    // and obtaining file lists in the Navigate to File dialog, so large binary files could really trip us up here
    found_zeroes := read_a_chunk_of_file_and_scan_for_zeroes(path);

    return found_zeroes;
}

is_known_file_extension :: inline (extension: string) -> bool, Known_Extension_File_Type {
    ok, type := table_find_new(*known_extensions_table, extension);
    return ok, type;
}


#scope_file

Known_Extension_File_Type :: enum { text; binary; }

known_extensions_table :: #run -> Table(string, Known_Extension_File_Type) {
    table: Table(string, Known_Extension_File_Type);

    text_file_extensions :: string.[
        "jai", "c", "cpp", "h", "hpp", "cc", "cs", "d", "txt", "md", "ini", "csv", "go", "log",
        "sql", "py", "m", "html", "xml", "plist", "js", "jsx", "ts", "tsx", "json", "yml",
        "yaml", "toml", "zig", "odin", "focus-config", "focus-theme",
    ];
    for text_file_extensions  table_add(*table, it, .text);

    binary_extensions :: string.[
        "exe", "pdb", "ttf", "otf", "eot", "woff", "dll", "lib", "dylib", "so", "a", "o", "pdf",
        "jpg", "png", "gif", "jpeg", "ico", "tif", "tiff", "tga", "bmp", "webp", "mp3", "wav", "ogg",
        "wma", "blend", "blend1", "obj", "fbx", "dae", "3ds", "dat", "msh2", "mpg", "mpeg", "psd", "codex",
        "webm", "zip", "rar", "7z", "bin", "sys", "iso", "nib", "exp", "pyc", "rpyc", "DS_Store", "dmg",
    ];
    for binary_extensions  table_add(*table, it, .binary);

    return table;
}

#scope_export

should_ignore_path :: (path: string) -> ignore: bool, explicitly_allowed: bool = false {
    path_chunks := split(path, cast(u8) #char "/",, allocator = temp);

    // Allow list has priority - check if path is explicitly allowed
    for config.workspace.allow {
        if contains(it, cast(u8) #char "/") {
            // Match whole path
            if platform_path_begins_with(path, it) || path_wildcard_match(path, it) return false, true;
        } else {
            // Match partial path
            for chunk : path_chunks {
                if path_wildcard_match(chunk, it) return false, true;
            }
        }
    }

    // Then check the user-specified ignore list
    for config.workspace.ignore {
        if contains(it, cast(u8) #char "/") {
            // Match whole path
            if path_wildcard_match(path, it) return true;
        } else {
            // Match partial path
            for chunk : path_chunks {
                if path_wildcard_match(chunk, it) return true;
            }
        }
    }
    if begins_with_nocase(path, temp_dir) return true;  // ignore our own temp dir

    return false;
}

should_descend_into_dir :: (path: string) -> bool {
    // If we have ANY allow patterns in the config, we HAVE to descend into every dir,
    // because even though the dir might be ignored, some of its contents might be
    // explicitly allowed, so we have to check everything.
    if config.workspace.allow return true;

    return !should_ignore_path(path);
}

// Match simple wildcard patterns. Supports `*`, `**` and `?` only.
path_wildcard_match :: (path: string, pattern: string) -> bool {
    // Path wildcards are slightly different from usual wildcards, because:
    // 1. On Windows they are case-insensitive, while everywhere else they are case-sensitive
    // 2. For paths, * will match until the next path separator, while ** will match everything

    // NOTE: assuming all paths passed to this function will have their path separators normalised to '/'

    #if OS == .WINDOWS {
        // TODO: support case-insensitive Unicode paths
        return _wildcard_match(to_lower_copy(path,, temp), to_lower_copy(pattern,, temp));
    }
    return _wildcard_match(path, pattern);
}

#scope_file

_wildcard_match :: (s: string, pat: string) -> bool {
    while true {
        // If pattern is over, string must be over too.
        if !pat.count return !s.count;

        // If string is over and pattern not over, then it must be *
        if !s.count && pat[0] != #char "*" return false;

        // Handle wildcard.
        if pat[0] == #char "*" {
            advance(*pat);
            if pat && pat[0] == #char "*" {
                // Handle **
                while pat && pat[0] == #char "*" advance(*pat);  // skip all *****'s if present
                if !pat.count return true;
                while true {
                    if _wildcard_match(s, pat) return true;
                    if !s.count return false;
                    advance(*s);
                }
            } else {
                if !pat.count return !contains(s, "/");
                // Handle *
                while true {
                    if _wildcard_match(s, pat) return true;
                    if !s.count return false;
                    if s[0] != #char "/" then advance(*s); else return false;
                }
            }
        }

        // Skip one character.
        if pat[0] == #char "?" {
            advance(*pat);
            advance(*s);
            continue;
        }

        // Skip if match.
        if pat[0] != s[0] return false;
        advance(*pat);
        advance(*s);
    }

    return false; // To silence the warning.
}

RUN_WILDCARD_TESTS :: false;

#if RUN_WILDCARD_TESTS #run {
    Test_Pattern :: struct { pattern: string; path: string; should_match: bool; }

    TEST_PATTERNS :: Test_Pattern.[
        .{ "C:/bin/*.exe", "C:/bin/focus.exe", true },
        .{ "C:/bin/*.exe", "C:/bin/some.exe", true },
        .{ "C:/bin/*.exe", "C:/bin/some-long-exe-name.exe", true },
        .{ "C:/bin/*.exe", "C:/bin/subfolder/file.exe", false },
        .{ "C:/bin/*.exe", "C:/bin/focus.exe/file.exe", false },

        .{ "C:/bin/**/focus.exe", "C:/bin/some/long/path/focus.exe", true },
        .{ "C:/bin/**/focus.exe", "C:/bin/some/long/path/file.exe", false },

        .{ "C:/bin/**/*.exe", "C:/bin/some/long/path/file.exe", true },
        .{ "C:/bin/**/*.exe", "C:/nib/some/long/path/file.exe", false },
        .{ "C:/bin/**/*.exe", "C:/bin/some/long/path/file.bin", false },

        .{ "?:/bin/**/*.exe", "C:/bin/some/long/path/file.exe", true },
        .{ "?:/bin/**/*.exe", "D:/bin/some/long/path/file.exe", true },
        .{ "?:/bin/**/*.exe", "E:/bin/some/long/path/file.exe", true },

        .{ "?:/bin/*****/file.exe", "C:/bin/some/long/path/file.exe", true },
        .{ "?:/bin/*****/file.exe", "D:/bin/some/long/path/file.exe", true },
        .{ "?:/bin/*****/file.exe", "E:/bin/some/long/path/file.exe", true },

        .{ "/usr/bin/*", "/usr/bin/file.o", true },
        .{ "/usr/bin/*", "/usr/bin/file.txt", true },
        .{ "/usr/bin/*", "/usr/nib/file.txt", false },
        .{ "/usr/bin/*", "/usr/bin/subfolder/file.o", false },

        .{ "/usr/bin/*/*.o", "/usr/bin/subfolder/file.o", true },
        .{ "/usr/bin/*/*.o", "/usr/bin/subfolder/file.a", false },
        .{ "/usr/bin/*/*.o", "/usr/bin/sub/folder/file.o", false },

        .{ "/usr/bin/**", "/usr/bin/file.o", true },
        .{ "/usr/bin/**", "/usr/bin/file.txt", true },
        .{ "/usr/bin/**", "/usr/bin/subfolder/file.o", true },

        .{ "/usr/bin/**/*.a", "/usr/bin/subfolder/file.a", true },
        .{ "/usr/bin/**/*.a", "/usr/bin/sub/folder/file.a", true },
        .{ "/usr/bin/**/*.a", "/usr/bin/sub/folder/.a", true },
        .{ "/usr/bin/**/*.a", "/usr/bin/sub/sub/folder/.a", true },
        .{ "/usr/bin/**/*.a", "/usr/bin/sub/folder/file.o", false },

        .{ "/usr/???/**/*.a", "/usr/bin/sub/folder/file.a", true },
        .{ "/usr/???/**/*.a", "/usr/nib/sub/folder/file.a", true },
        .{ "/usr/???/**/*.a", "/usr/nib/sub/folder/file.o", false },

        .{ "/usr/???/**/*.?", "/usr/nib/sub/folder/file.o", true },
        .{ "/usr/???/**/*.?", "/usr/bin1/sub/folder/file.o", false },

        .{ "/usr/???*/**/*.?", "/usr/bin1/sub/folder/file.o", true },
        .{ "/usr/???*/**/*.?", "/usr/bi/subfolder/file.o", false },
        .{ "/usr/???*/**/*.?", "/usr/bin/sub/folder/file.o", true },
        .{ "/usr/???*/**/*.?", "/usr/bin/sub/folder/file", false },
    ];

    for TEST_PATTERNS {
        matches := path_wildcard_match(it.path, it.pattern);
        if matches && !it.should_match {
            assert(false, "WILDCARD TEST FAILED: `%` shouldn't match `%` but it does", it.path, it.pattern);
        } else if !matches && it.should_match {
            assert(false, "WILDCARD TEST FAILED: `%` should match `%` but it doesn't", it.path, it.pattern);
        }
    }
}

#scope_export

dir_is_within_project :: (dir_path: string) -> bool, Project_Dir {
    for project_dirs {
        if platform_path_equals(dir_path, it.path) || platform_path_contains(dir_path, tprint("%/", it.path)) return true, it;
    }
    return false, Project_Dir.{};
}

get_parent_dir_path :: (file_path: string) -> string {
    path := path_strip_filename(file_path);
    if path.count > 1 && path[path.count-1] == #char "/" then path.count -= 1;  // don't include trailing path separator
    return path;
}

read_a_chunk_of_file_and_scan_for_zeroes :: (path: string) -> found_zeroes: bool {
    push_allocator(temp);
    auto_release_temp();

    file, success := file_open(path);
    if !success return true;  // assuming a file we can't open here is something we should not worry about
    defer file_close(*file);

    CHUNK_SIZE :: 4 * 1024;
    buf: [CHUNK_SIZE] u8;

    _, bytes_read := file_read(file, buf.data, buf.count);
    if bytes_read <= 0 return false;  // success could be false but that could indicate a successful read near the end of the file
    chunk := cast(string) array_view(buf, 0, bytes_read);
    if find_index_from_left(chunk, byte = 0) >= 0 return true;

    return false;
}

File_Info :: struct {
    full_path: string;
    name: string;
    path: string;
    icon: Icon;
    project_dir_id: s8 = 0;  // to be used for sorting
}
