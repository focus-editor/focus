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

get_file_icon :: (name: string, extension: string) -> File_Icon {
    icon := File_Icon.unknown;

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
    if icon == .text && equal_nocase(name, "log.md") then icon = .worklog;
    if icon == .text || icon == .unknown {
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

    return to_lower_copy(extension), true;
}

is_file_binary :: (file_data: string) -> bool {
    // Check for zeroes in the file - if there are any, it's not a well-formed text file.
    // There's a small chance that a binary file will have no zeroes, but it's the easiest
    // thing to check, so that's what we're doing.
    has_zeroes := find_index_from_left(file_data, byte = 0) >= 0;
    return has_zeroes;
}

should_ignore_file :: (path: string) -> bool {
    extension, found_extension := get_lowercase_extension(path);

    if found_extension {
        // Allow known text file extensions since they are the most common
        for config.workspace.allow_file_extensions {
            if ends_with_nocase(path, it) return false;
        }
        for config.workspace.allow_file_extension_wildcards {
            if wildcard_match(extension, it) return false;
        }

        // Then check for common known binary file extensions
        for config.workspace.ignore_file_extensions {
            if ends_with_nocase(path, it) return true;
        }
        for config.workspace.ignore_file_extension_wildcards {
            if wildcard_match(extension, it) return true;
        }
    }
    if begins_with_nocase(path, temp_dir) return true;  // explicitly ignore our own temp dir

    return false;
}

should_ignore_dir :: (path: string) -> bool {
    path_chunks := split(path, "/");
    for config.workspace.ignore_dirs {
        if contains(it, cast(u8) #char "/") {
            // Match whole path
            if wildcard_match(path, it) return true;
        } else {
            // Match partial path
            for chunk : path_chunks {
                if wildcard_match(chunk, it) return true;
            }
        }
    }
    if begins_with_nocase(path, temp_dir) return true;  // explicitly ignore our own temp dir
    return false;
}

dir_is_within_project :: (dir_path: string) -> bool, Project_Dir {
    for project_dirs {
        if equal_nocase(dir_path, it.path) || contains_nocase(dir_path, tprint("%/", it.path)) return true, it;
    }
    return false, Project_Dir.{};
}

get_parent_dir_path :: (file_path: string) -> string {
    path := path_strip_filename(file_path);
    if path.count > 1 && path[path.count-1] == #char "/" then path.count -= 1;  // don't include trailing path separator
    return path;
}

File_Info :: struct {
    full_path: string;
    name: string;
    path: string;
    icon: File_Icon;
    project_dir_id: s8 = 0;  // to be used for sorting
}

File_Icon :: enum u16 {
    // These are character codes for the font-awesome font
    unknown :: 0xf15b;
    text    :: 0xf15c;
    jai     :: 0xf574;
    cpp     :: 0xf1c9;
    cs      :: 0xf1c9;
    worklog :: 0xf46d;
    git     :: 0xf387;
    image   :: 0xf1c5;
    audio   :: 0xf1c7;
    font    :: 0xf031;
    key     :: 0xf084;
    gear    :: 0xf013;
    folder  :: 0xe185;
    drive   :: 0xf0a0;
    js      :: 0xf15c;
    shell   :: 0xf2d0;

    dots    :: 0xf141;
}
