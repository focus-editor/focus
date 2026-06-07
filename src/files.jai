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

get_extension :: (path: string, greedy := true) -> string /* temp */, found_extension: bool {
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

    return extension, true;
}

is_file_binary :: (file_data: string) -> bool {
    // Check for zeroes in the file - if there are any, it's not a well-formed text file.
    // There's a small chance that a binary file will have no zeroes, but it's the easiest
    // thing to check, so that's what we're doing.
    has_zeroes := find_index_from_left(file_data, byte = 0) >= 0;
    return has_zeroes;
}

should_ignore_file :: (file_path: string, check_for_zeroes_if_needed := true) -> bool {
    #if OS == .WINDOWS {
        // Ignore case on Windows.
        // NOTE: assuming all the patterns in the config are pre-lowercased at config load time!
        path := to_lower_copy(file_path,, temp);
    } else {
        path := file_path;
    }

    // Check if we've already ignored this file
    found, should_ignore_value := table_find_threadsafe(*ignore_table, path);
    if found return should_ignore_value;

    should_ignore, explicitly_allowed := should_ignore_path(path);

    if should_ignore || explicitly_allowed {
        table_set_threadsafe(*ignore_table, path, should_ignore);
    }

    if should_ignore return true;
    if explicitly_allowed return false;

    // If we haven't decided yet whether to ignore or allow, do some extra checks
    extension, found_extension := get_extension(path);
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

    // Check if we already checked this file for zeroes
    already_checked, is_binary := table_find_threadsafe(*binary_files_table, path);
    if already_checked return is_binary;

    // Ignore binary files - it's not a 100% guarantee but a good heuristic.
    // We're not using read_entire_file here because this function is used when scanning workspace
    // and obtaining file lists in the Navigate to File dialog, so large binary files could really trip us up here
    found_zeroes := read_a_chunk_of_file_and_scan_for_zeroes(path);

    // Remember this file so that we don't have to check again
    table_set_threadsafe(*binary_files_table, path, found_zeroes);

    return found_zeroes;
}

is_known_file_extension :: inline (extension: string) -> bool, Known_Extension_File_Type {
    ok, type := table_find(*known_extensions_table, extension);
    return ok, type;
}


#scope_file

Known_Extension_File_Type :: enum { text; binary; }

known_extensions_table :: #run -> Table(string, Known_Extension_File_Type) {
    table: Table(string, Known_Extension_File_Type);

    text_file_extensions :: string.[
        "jai", "c", "cpp", "h", "hpp", "cc", "cs", "d", "txt", "md", "ini", "csv", "go", "log",
        "sql", "py", "m", "html", "xml", "plist", "js", "jsx", "ts", "tsx", "json", "yml",
        "yaml", "toml", "zig", "odin", "focus-config", "focus-theme", "vhd", "vhdl", "vdhl",
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
    // NOTE: assuming path is pre-lowercased on Windows!

    // Allow list has priority - check if path is explicitly allowed
    for fp : config.workspace.allow {
        if fp.should_match_whole_path {
            if path_pattern_match(path, fp) return false, true;
        } else {
            // Match path chunks
            chunk_start := 0;
            for i : 0 .. path.count {
                if i == path.count || path[i] == #char "/" {
                    chunk := slice(path, chunk_start, i - chunk_start);
                    if path_pattern_match(chunk, fp) return false, true;
                    chunk_start = i + 1;
                }
            }
        }
    }

    // Then check the user-specified ignore list
    for fp : config.workspace.ignore {
        if fp.should_match_whole_path {
            if path_pattern_match(path, fp) return true;
        } else {
            // Match path chunks
            chunk_start := 0;
            for i : 0 .. path.count {
                if i == path.count || path[i] == #char "/" {
                    chunk := slice(path, chunk_start, i - chunk_start);
                    if path_pattern_match(chunk, fp) return true;
                    chunk_start = i + 1;
                }
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

    #if OS == .WINDOWS {
        return !should_ignore_path(to_lower_copy(path),, temp);
    } else {
        return !should_ignore_path(path);
    }
}

path_pattern_match :: (path: string, fp: File_Pattern) -> bool {
    if #complete fp.pattern_type == {
        case .LITERAL;
            // Pattern is a plain string with no wildcards.
            if fp.should_match_whole_path {
                return path == fp.pattern;
            }
            // Partial match: caller is responsible for iterating chunks and
            // calling us once per chunk, OR we treat this as "any chunk equals
            // pattern". Pick one convention — see note below. Here, equality
            // against a single chunk passed in as `path`.
            return path == fp.pattern;

        case .EXTENSION;
            // Pattern stored as just the extension, no leading dot.
            // e.g. pattern == "exe" matches "foo.exe", "a/b/c.exe", etc.
            // should_match_whole_path is irrelevant for extensions.
            return path_has_extension(path, fp.pattern);

        case .WILDCARD;
            return _wildcard_match(path, fp.pattern);
    }
}

path_has_extension :: inline (path: string, ext: string) -> bool {
    needed := ext.count + 1;  // +1 for the dot
    if path.count < needed return false;
    if path[path.count - needed] != #char "." return false;
    return slice(path, path.count - ext.count, ext.count) == ext;
}

// Match simple wildcard patterns. Supports `*`, `**` and `?` only.
path_wildcard_match :: (path: string, wildcard: string) -> bool {
    // Path wildcards are slightly different from usual wildcards, because:
    // 1. On Windows they are case-insensitive, while everywhere else they are case-sensitive
    // 2. For paths, * will match until the next path separator, while ** will match everything


    // NOTE: assuming all paths passed to this function will have their path separators normalised to '/'

    #if OS == .WINDOWS {
        // @Speed: this could be very slow if called in a loop on Windows!
        // TODO: support case-insensitive Unicode paths
        return _wildcard_match(to_lower_copy(path,, temp), to_lower_copy(wildcard,, temp));
    }
    return _wildcard_match(path, wildcard);
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
    auto_release_temp();
    push_allocator(temp);

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

init_file_tables :: () {
    init(*ignore_table,       3000,, focus_allocator);
    init(*binary_files_table, 3000,, focus_allocator);
}

forget_ignore_table :: () {
    table_reset_threadsafe(*ignore_table);
}

#scope_file

// Some tables to speed up scanning

Threadsafe_Table :: struct {
    table: Table(string, bool);
    lock: Mutex;
}

init :: (table: *Threadsafe_Table, size: int) {
    init(*table.lock);
    table_resize(*table.table, size);
}

table_find_threadsafe :: (table: *Threadsafe_Table, key: string) -> bool, bool {
    lock(*table.lock);
    defer unlock(*table.lock);

    found, value := table_find(*table.table, key);
    return found, value;
}

table_set_threadsafe :: (table: *Threadsafe_Table, key: string, value: bool) -> *bool {
    lock(*table.lock);
    defer unlock(*table.lock);

    return table_set(*table.table, copy_string(key,, focus_allocator), value);
}

table_reset_threadsafe :: (table: *Threadsafe_Table) {
    lock(*table.lock);
    defer unlock(*table.lock);

    table_reset_keeping_memory(*table.table);
}

ignore_table:       Threadsafe_Table;
binary_files_table: Threadsafe_Table;

