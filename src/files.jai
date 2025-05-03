get_file_info_from_full_path :: (abs_path: string, proj_prefix_len := -1) -> File_Info #must {
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
        if is_known_text_file_extension  (extension) return false;
        if is_known_binary_file_extension(extension) return true;
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
    if found_zeroes return true;

    return false;
}

is_known_text_file_extension :: (extension: string) -> bool {
    if extension == {
        case "jai";     #through;
        case "c";       #through;
        case "cpp";     #through;
        case "h";       #through;
        case "hpp";     #through;
        case "cc";      #through;
        case "cs";      #through;
        case "d";       #through;
        case "txt";     #through;
        case "md";      #through;
        case "ini";     #through;
        case "csv";     #through;
        case "log";     #through;
        case "sql";     #through;
        case "py";      #through;
        case "m";       #through;
        case "html";    #through;
        case "xml";     #through;
        case "plist";   #through;
        case "js";      #through;
        case "jsx";     #through;
        case "ts";      #through;
        case "tsx";     #through;
        case "json";    #through;
        case "yml";     #through;
        case "yaml";    #through;
        case "toml";    #through;
        case "zig";     #through;
        case "odin";    #through;
        case "focus-config"; #through;
        case "focus-theme";
            return true;
    }
    return false;
}

is_known_binary_file_extension :: (extension: string) -> bool {
    if extension == {
        case "exe";      #through;
        case "pdb";      #through;
        case "ttf";      #through;
        case "otf";      #through;
        case "eot";      #through;
        case "woff";     #through;
        case "dll";      #through;
        case "lib";      #through;
        case "dylib";    #through;
        case "so";       #through;
        case "a";        #through;
        case "o";        #through;
        case "pdf";      #through;
        case "jpg";      #through;
        case "png";      #through;
        case "gif";      #through;
        case "jpeg";     #through;
        case "ico";      #through;
        case "tif";      #through;
        case "tiff";     #through;
        case "tga";      #through;
        case "bmp";      #through;
        case "webp";     #through;
        case "mp3";      #through;
        case "wav";      #through;
        case "ogg";      #through;
        case "wma";      #through;
        case "blend";    #through;
        case "blend1";   #through;
        case "obj";      #through;
        case "fbx";      #through;
        case "dae";      #through;
        case "3ds";      #through;
        case "dat";      #through;
        case "msh2";     #through;
        case "mpg";      #through;
        case "mpeg";     #through;
        case "psd";      #through;
        case "codex";    #through;
        case "webm";     #through;
        case "zip";      #through;
        case "rar";      #through;
        case "7z";       #through;
        case "bin";      #through;
        case "sys";      #through;
        case "iso";      #through;
        case "nib";      #through;
        case "exp";      #through;
        case "pyc";      #through;
        case "rpyc";     #through;
        case "DS_Store"; #through;
        case "dmg";
            return true;
    }
    return false;
}

should_ignore_path :: (path: string) -> ignore: bool, explicitly_allowed: bool = false {
    path_chunks := split(path, "/",, allocator = temp);

    // Allow list has priority
    if path_is_explicitly_allowed(path) return false, true;

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
    if path_is_explicitly_allowed(path) return true;

    // We want to look inside dirs even if they match some ignore wildcards,
    // so that the user can do a catch-all ignore wildcard like '*'
    // and then explicitly unignore some of the files inside.
    // If we don't descend into the dir we won't know what's inside!

    // But if there's a matching non-wildcard rule, then we want to skip the dir altogether
    path_chunks := split(path, "/",, allocator = temp);

    for config.workspace.ignore {
        if contains_any_character(it, "*?") continue;  // ignore wildcards

        if contains(it, cast(u8) #char "/") {
            if platform_path_begins_with(path, it) return false;
        } else {
            // Match partial path
            for chunk : path_chunks {
                if platform_path_equals(chunk, it) return false;
            }
        }
    }

    return true;
}

path_is_explicitly_allowed :: (path: string) -> bool {
    path_chunks := split(path, cast(u8) #char "/",, allocator = temp);

    for config.workspace.allow {
        if contains(it, cast(u8) #char "/") {
            // Match whole path
            if platform_path_begins_with(path, it) || path_wildcard_match(path, it) return true;
        } else {
            // Match partial path
            for chunk : path_chunks {
                if path_wildcard_match(chunk, it) return true;
            }
        }
    }

    return false;
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
