#add_context read := 0;
#add_context total_lines := 0;
#add_context reading_queue: *Queue(string);
#add_context dirs: [..]string;

main :: () {
    args := get_command_line_arguments();
    assert(args.count == 2, "This program takes one argument, the starting directory.");
    starting_dir := args[1];

    context.reading_queue = initialize_queue(string);

    dirs := *context.dirs;
    array_add(dirs, starting_dir);

    while dirs.count {
        elm := dirs.*[dirs.count-1];
        dirs.count -= 1;
        read_dir_entries(elm);
        reset_temporary_storage();
    }

    get_lines(context.read);
    print("The total number of lines is %\n", context.total_lines);
}

// There are some situations where we already know the file size from reading the directory entry. So it may be useful
// to add a way to use read_file rather than read_entire_file when that happens.
read_file :: (name: string) {
    // @ToDo This is where it might be nice if there was an option to have Catastrophic
    // errors assert automatically. We aren't checking for other errors like FileAccessFailed
    // but we should stop if something happens that wouldn't allow us to continue.
    result := read_entire_file(context.reading_queue, name, name);
    if result.code == .FullQueue {
        context.read -= get_lines(context.read, true);
        result := read_entire_file(context.reading_queue, name, name);
        while result.code == .FullQueue {
            context.read -= get_lines(1);
            result = read_entire_file(context.reading_queue, name, name);
        }
        if result.code != .Success {
            assert(false, "% %\n", name, result);
        }
    } else if result.code != .Success {
        assert(false, "% %\n", name, result);
    }
    context.read += 1;
}

get_lines :: (file_count: s64, check_only := false) -> files_read: s64 {
    for 1..file_count {
        file_name, data, success := wait_for_completion(context.reading_queue, check_only);
        if success.code == {
            case .DidNotWait;
                return it-1;
            case .FileAccessFailed;
                print("Failed to read % % %\n", file_name, success, get_error_string(xx,no_check success.platform_code));
            case .Incomplete;
                print("Failed to read all of % % % %\n", file_name, data.count, success, get_error_string(xx,no_check success.platform_code));
                #through;
            case .Success;
                lines := count_lines(data);
                array_free(data);
                context.total_lines += lines;
            case .Catastrophic;
                assert(false, "Catastrophic error: % % %", file_name, success, get_error_string(xx,no_check success.platform_code));
        }
        free(file_name);
    }
    return file_count;
}

count_lines :: (data: []u8) -> s64 {
    if data.count == 0 return 0;
    lines := 1;
    // Obviously this would be done far faster with SIMD but I didn't want to introduce more things that could go wrong
    for data if it == #char "\n" then lines += 1;
    return lines;
}

// Because these are all so similar, they could probably be written in a simpler way
#if OS == .MACOS {
    #import "POSIX";

    read_dir_entries :: (dir_name: string) {
        fd := open(temp_c_string(dir_name), O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        if fd == -1 {
            print("Could not open %, reason: %\n", dir_name, errno());
        }
        defer close(fd);

        attrs: attrlist;
        attrs.commonattr  = ATTR_CMN.RETURNED_ATTRS | ATTR_CMN.NAME | ATTR_CMN.OBJTYPE | ATTR_CMN.USERACCESS;
        buf: [4096] u8; // //This is the max supported size aparently
        entries_read := getattrlistbulk(fd, *attrs, buf.data, buf.count, 0);
        if entries_read == -1 then entries_read = 0;
        while entries_read {
            start := 0;
            for 1..entries_read {
                entry := cast(*struct {
                    next_offset: u32;
                    attributes:  attribute_set_t;
                    name_info:   attrreference_t;
                    obj_type:    vtype;
                    user_access: u32;
                })*buf[start];

                start += entry.next_offset;

                // ATTR_CMN_RETURNED_ATTRS
                if !my_bits_equal(*entry.attributes, xx *attrs.commonattr) then continue;

                // ATTR_CMN_NAME
                name: string = ---;
                name.data = (cast(*u8)*entry.name_info) + entry.name_info.attr_dataoffset;
                name.count = entry.name_info.attr_length - 1; // Null terminator
                name = sprint("%/%", dir_name, name);

                // ATTR_CMN_OBJTYPE
                type := entry.obj_type;

                // ATTR_CMN_USERACCESS
                access := entry.user_access;

                // @header sys/unistd.h
                R_OK :: 1 << 2;
                X_OK :: 1 << 0;

                if !((type == vtype.VREG && access & R_OK) || (type == vtype.VDIR && access & X_OK)) then continue;

                if type == vtype.VREG {
                    // Do file read
                    read_file(name);
                } else if type == vtype.VDIR {
                    // Open and add to search list
                    array_add(*context.dirs, name);
                }
            }

            entries_read = getattrlistbulk(fd, *attrs, buf.data, buf.count, 0);
            if entries_read == -1 then entries_read = 0;
        }
    }
} else #if OS == .LINUX {
    #import "POSIX";

    getdents64 :: inline (fd: s32, dirp: *linux_dirent, count: u32) -> s32 {
        return cast,no_check(s32)syscall(SYS_getdents64, fd, dirp, count);
    }

    linux_dirent :: struct {
        d_ino:    u64; // Inode number.
        d_off:    u64; // Offset to next linux_dirent.
        d_reclen: u16; // Length of this linux_dirent.
        d_type:   DT;  // File type.
        d_name:   u8;  // Start of filename (null-terminated).
    }

    read_dir_entries :: (dir_name: string) {
        fd := open(temp_c_string(dir_name), O_RDONLY | O_DIRECTORY | O_CLOEXEC);
        if fd == -1 {
            print("Could not open %, reason: %\n", dir_name, errno());
        }
        defer close(fd);

        buf: [4096] u8; // Not sure what a good size is
        bytes_read := getdents64(fd, xx buf.data, buf.count);
        if bytes_read == -1 then bytes_read = 0;
        while bytes_read {
            start := 0;
            while start < bytes_read {
                entry := cast(*linux_dirent)*buf[start];

                // @ToDo Given that this is null-terminated, we could probably do
                // something useful here to avoid temp_c_string in a few places
                name := to_string(*entry.d_name);
                if name == "." || name == ".." {
                   // It's interesting that macOS and Windows do not have this issue.
                   start += entry.d_reclen;
                   continue;
                }
                name = sprint("%/%", dir_name, name);

                type := entry.d_type;
                if entry.d_type == .UNKNOWN {
                    // @ToDo We have to open this to figure out what it is because we were not
                    // told! We shouldn't really need to do this temp_c_string if we are smarter.
                    info: stat_t;
                    stat(temp_c_string(name), *info);

                    if      S_ISREG(info.st_mode) then type = .REG;
                    else if S_ISDIR(info.st_mode) then type = .DIR;

                }

                // Linux doesn't tell us the access so we can't check it without doing more syscalls unlike on macOS.

                if type == .REG {
                    // Do file read
                    read_file(name);
                } else if type == .DIR {
                    // Open and add to search list
                    array_add(*context.dirs, name);
                }

                start += entry.d_reclen;
            }

            bytes_read = getdents64(fd, xx buf.data, buf.count);
            if bytes_read == -1 then bytes_read = 0;
        }
    }
} else #if OS == .WINDOWS {
    #import "Windows_Utf8";
    #import "Windows";
    // GetFileInformationByHandleEx with FileFullDirectoryInfo might be too new to expect people to
    // have. I think it's Windows 8? So you would probably want to use FindFirstFileEx in general but
    // this is cool because it works the same way that the macOS and Linux APIs do. This also might be
    // better if it used utf16 the entire time rather than swtiching between utf8 and utf16 constantly.

    read_dir_entries :: (dir_name: string) {
        utf16_name, encoding_success := utf8_to_wide(dir_name,, temp);
        if !encoding_success then return;

        // @ToDo It's unclear from the docs what permissions I need. FILE_FULL_DIR_INFO says "No specific access
        // rights are required to query this information." But I don't see why FILE_TRAVERSE or FILE_LIST_DIRECTORY
        // (which it's unclear the difference between for directories) wouldn't be needed. Also FILE_READ_DATA is the
        // same value as FILE_LIST_DIRECTORY but has a different description of what it does for directories. But
        // it's hard to test because users have BYPASS_TRAVERSE_CHECKING by default so I don't know... Might as well
        // ask for more than we need right now and later someone can figure it out. Also, FILE_FLAG_BACKUP_SEMANTICS
        // is required to open a directory which means that we need certain permissions that we may not have
        // so perhaps FindFirstFile really is what we should be using no matter how much nicer this is.
        fd := CreateFileW(utf16_name, FILE_LIST_DIRECTORY | FILE_TRAVERSE, FILE_SHARE_READ | FILE_SHARE_WRITE, flags_and_attributes = FILE_FLAG_BACKUP_SEMANTICS);
        if fd == INVALID_HANDLE_VALUE {
            // @ToDo: This should use the function in System that gets the name of the error, not just the error code.
            code, reason := get_error_value_and_string();
            print("Could not open %, reason: % %\n", dir_name, code, reason);
        }
        defer CloseHandle(fd);

        buf: [4096] u8; // Not sure what a good size is
        get_info_result := GetFileInformationByHandleEx(fd, FileFullDirectoryInfo, xx buf.data, xx buf.count);
        while get_info_result == .TRUE {
            start := 0;
            cont  := true;
            while cont {
                entry := cast(*FILE_FULL_DIR_INFO)*buf[start];
                start += entry.NextEntryOffset;
                cont = entry.NextEntryOffset != 0;

                // One Windows API gives out a u32, another takes an s32.
                // Of course! The file name length appears to be in bytes;
                name, conversion_success := wide_to_utf8(entry.FileName.data, cast(s32)(entry.FileNameLength >> 1),, temp);
                if !conversion_success || name == "." || name == ".." then continue;
                name = sprint("%/%", dir_name, name);

                type := entry.FileAttributes;

                // Windows doesn't tell us the access so we can't check it without doing more syscalls unlike on macOS.

                // There doesn't appear to be a way to find out if a file is special
                // like a device file. Maybe that just doesn't ever get listed here.
                if !(type & FILE_ATTRIBUTE_DIRECTORY) {
                    // Do file read
                    read_file(name);
                } else {
                    // Open and add to search list
                    array_add(*context.dirs, name);
                }
            }

            get_info_result = GetFileInformationByHandleEx(fd, FileFullDirectoryInfo, xx buf.data, xx buf.count);
        }
    }
}

#import "Basic"()(MEMORY_DEBUGGER = true);
#import "Bit_Operations";
#import "File_Async";
#import "System";

my_bits_equal :: inline (a: *$T, b: *T) -> bool {
    return !memcmp(a, b, size_of(T));
}
