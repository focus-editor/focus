start_fresh_session :: () {
    // Create a new folder to store session data
    now := current_time_consensus();
    print("Now: %\n", now);
}

maybe_load_previous_session :: () {
    now := current_time_consensus();
    session_dir_name := sprint("session_%_%", formatInt(now.high, base=16), formatInt(now.low, base=16));
    
    last_session_name, found := get_last_session_name();
    print("last: %\n", last_session_name);
    
    // Find latest session:
        // Get the list of all dirs starting with session_
        // Find the most recent one
        // Parse the contents of the folder
        // Load the project config (may fail, that's ok)
        // Open all previously opened editors
            // If they are not modified and last modtime matches, load as is, together with the undo history
            // If a buffer was modified:
                // If the modtime matches the file, load as modified
                // If the modtime of the file is later, load as modified and modified_on_disk
}

#scope_file

get_last_session_name :: () -> string, found: bool {
    temp_folder := tprint("%temp", exe_dir);
    print("%\n", temp_folder);
    
    session_dirs: [..] Session_Dir;
    session_dirs.allocator = temp;
    
    visitor :: (info: *File_Visit_Info, sessions: *[..] Session_Dir) {
        if !begins_with(info.short_name, "session_") return;
        
        array_add(sessions, Session_Dir.{ name = info.short_name, modtime = info.modification_time });
    }

    visit_files(temp_folder, recursive = false, *session_dirs, visitor, visit_files = false, visit_directories = true);
    
    if !session_dirs return "", false;
    
    cmp_dirs :: (dir1: Session_Dir, dir2: Session_Dir) -> s64 { 
        if dir1.modtime > dir2.modtime return -1;
        if dir2.modtime > dir1.modtime return  1;
        return 0;
    }
    bubble_sort(session_dirs, cmp_dirs);
    
    return copy_string(session_dirs[0].name), true;
    
}

#scope_export

session: Session;

#scope_file

Session :: struct {
    path: string;
    last_edit: Apollo_Time;  // ??
}

Session_Dir :: struct {
    name: string;
    modtime: Apollo_Time;
}
