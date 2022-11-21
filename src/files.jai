get_file_info_from_full_path :: (abs_path: string, _proj_path_prefix_len := -1) -> File_Info #must {
    assert(is_absolute_path(abs_path), "Trying to get file info from a non-absolute path. This is a bug.");

    full_path := copy_string(abs_path);  // one allocation, the rest are views into it
    path, basename, extension, name := path_decomp(full_path);

    info: File_Info = ---;
    info.full_path = full_path;
    info.name = name;
    if ends_with(path, "/") then path.count -= 1;  // strip the separator
    info.path = path;

    proj_prefix_len := _proj_path_prefix_len;
    if proj_prefix_len <= 0 {
        for project_dirs {
            if begins_with_nocase(path, it.path) {
                proj_prefix_len = it.path_prefix_len;
                break;
            }
        }
    }
    if proj_prefix_len > 0 then info.path = advance(info.path, proj_prefix_len);

    // Determine icon
    icon := File_Icon.unknown;
    if extension == {
        case "jai";
            icon = .jai;
        case "cpp";  #through;
        case "hpp";  #through;
        case "h";    #through;
        case "c";
            icon = .cpp;
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

    info.icon = icon;

    return info;
}

// @Cleanup: this logic needs some careful reviewing
// Also TODO: profile how long it takes to scan everything
file_collector_func :: (file: *File_Visit_Info, config: File_Visit_Config) {
    if file.is_directory {
        for config.ignore_folders {
            if equal_nocase(file.short_name, it) {  // TODO: do a wildcard match
                file.descend_into_directory = false;  // ignore
                return;
            }
        }
        return;
    }
    if file.is_symlink return;

    skip := true;
    for config.allowed_files {
        // TODO: do a wildcard match
        if ends_with_nocase(file.short_name, it) { skip = false; break; };
    }
    if skip return;  // unsupported type

    file_info := get_file_info_from_full_path(file.full_name, config.proj_path_prefix_len);
    array_add(config.files_dst, file_info);
}

File_Info :: struct {
    full_path: string;
    name: string;
    path: string;
    icon: File_Icon;
}

File_Icon :: enum u32 {
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
}

// @Cleanup: if we get rid of the generic file open dialog, then this will not
// need to be global any more
File_Visit_Config :: struct {
    ignore_folders: [] string;
    allowed_files:  [] string;
    proj_path_prefix_len: s64;
    files_dst: *[..] File_Info;
}
