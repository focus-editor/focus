get_file_info_from_full_path :: (abs_path: string, proj_prefix_len := -1) -> File_Info #must {
    assert(is_absolute_path(abs_path), "Trying to get file info from a non-absolute path. This is a bug.");

    full_path := copy_string(abs_path);  // one allocation, the rest are views into it
    path, basename, extension, name := path_decomp(full_path);

    info: File_Info = ---;
    info.full_path = full_path;
    info.name = name;
    if ends_with(path, "/") then path.count -= 1;  // strip the separator
    info.path = path;

    if proj_prefix_len <= 0 {
        for project_dirs {
            if begins_with_nocase(path, it.path) {
                proj_prefix_len = it.path_prefix_len;
                info.project_dir_id = xx it_index;
                break;
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
        case "cpp";  #through;
        case "hpp";  #through;
        case "h";    #through;
        case "c";
            icon = .cpp;
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

should_ignore_file :: (path: string) -> bool {    
    // Allow known text file extensions since they are the most common
    for allowed_ext : config.workspace.allow_file_extensions {
        if ends_with_nocase(path, allowed_ext) return false;
    }
    
    // Then check for common known binary file extensions
    for config.workspace.ignore_file_extensions {
        if ends_with_nocase(path, it) return true;  // TODO: do a wildcard match
    }
    
    // Check for zeroes in the file - if there are any, it's not a well-formed text file.
    // There's a small chance that a binary file will have no zeroes, but it's the easiest
    // thing to check, so that's what we're doing.
    // Sorry non-binary files, there are only 2 digits, please don't cancel me.
    file_data, success := read_entire_file(path);
    if !success return true;
    has_zeroes := find_index_from_left(file_data, byte = 0) >= 0;
    free(file_data);
    if has_zeroes return true;  // ignore
    
    // In this case the file will be read again, but it's OK because:
    // 1. It should happen rarely
    // 2. The file will be in the filesystem cache
    return false;
}

should_ignore_dir :: (name: string) -> bool {
    for config.workspace.ignore_dirs {
        if equal_nocase(name, it) {  // TODO: do a wildcard match
            return true;
        }
    }
    return false;
}

File_Info :: struct {
    full_path: string;
    name: string;
    path: string;
    icon: File_Icon;
    project_dir_id: s8 = -1;  // to be used for sorting
}

File_Icon :: enum u16 {
    // These are character codes for the font-awesome font
    unknown :: 0xf15b;
    text    :: 0xf15c;
    jai     :: 0xf574;
    cpp     :: 0xf1c9;
    worklog :: 0xf46d;
    git     :: 0xf387;
    image   :: 0xf1c5;
    audio   :: 0xf1c7;
    font    :: 0xf031;
    key     :: 0xf084;
    gear    :: 0xf013;
    folder  :: 0xf07b;
    drive   :: 0xf0a0;
}
