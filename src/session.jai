start_fresh_session :: () -> string {
    // Create a new folder to store session data
    now := current_time_consensus();
    current_session_name := sprint("session_%_%", formatInt(now.high, base=16), formatInt(now.low, base=16));
    current_session_dir := tprint("%temp/%", exe_dir, current_session_name);
    if !make_directory_if_it_does_not_exist(current_session_dir) {
        panic_messagebox("Couldn't create a new session '%' - please check directory permissions", current_session_dir);
    }
    return current_session_name;
}

maybe_load_previous_session :: () {
    // + Find latest session:
        // + Get the list of all dirs starting with session_
        // + Find the most recent one
    // Parse the contents of the folder
    // Load the project config (may fail, that's ok)
    // Open all previously opened editors
        // If they are not modified and last modtime matches, load as is, together with the undo history
        // If a buffer was modified:
            // If the modtime matches the file, load as modified
            // If the modtime of the file is later, load as modified and modified_on_disk
            
    last_session_name, found := get_last_session_name();
    
    // Create a new session dir after looking for the last one
    current_session_name := start_fresh_session();
    
    if found {
        // Copy last session's data over to the new one
        copied := copy_session_data(last_session_name, current_session_name);
        if !copied log_error("Couldn't copy last session data '%' into the new session '%'", last_session_name, current_session_name);
    }
}

#scope_file

get_last_session_name :: () -> string, found: bool {
    temp_dir := tprint("%temp", exe_dir);
    
    session_dirs: [..] Session_Dir;
    session_dirs.allocator = temp;
    
    // Get all session dirs
    visitor :: (info: *File_Visit_Info, sessions: *[..] Session_Dir) {
        if !begins_with(info.short_name, "session_") return;
        
        array_add(sessions, Session_Dir.{ name = copy_temporary_string(info.short_name), modtime = info.modification_time });
    }
    visit_files(temp_dir, recursive = false, *session_dirs, visitor, visit_files = false, visit_directories = true);
    
    if !session_dirs return "", false;
    
    // Sort the dirs from newest to oldest
    cmp_dirs :: (dir1: Session_Dir, dir2: Session_Dir) -> s64 {
        if dir1.modtime > dir2.modtime return -1;
        if dir2.modtime > dir1.modtime return  1;
        return 0;
    }
    bubble_sort(session_dirs, cmp_dirs);
    
    // Delete old sessions
    num_old_sessions := session_dirs.count - MAX_SESSIONS_TO_STORE;
    if num_old_sessions > 0 {
        for i : 1 .. num_old_sessions {
            session_dir := tprint("%/%", temp_dir, session_dirs[session_dirs.count - i].name);
            log("Deleting old session '%'", session_dir);
            deleted := delete_directory(session_dir);
            if !deleted log_error("Couldn't delete old session '%'", session_dir);
        }
    }
    for session_dirs {
        log("session_dirs[%].name = %", it_index, it.name);
    }
    
    return session_dirs[0].name, true;
}

copy_session_data :: (source: string, dest: string) -> success: bool {
    src_session := tprint("%temp/%", exe_dir, source);
    dst_session := tprint("%temp/%", exe_dir, dest);
    
    success := true;
    
    if file_exists(tprint("%/project", src_session)) {
        success = copy_file(tprint("%/project", src_session), tprint("%/project", dst_session));
    }
    // TODO: copy other files when we have them
    
    return success;
}


#scope_export

session: Session;

#scope_file

Session :: struct {
    path: string;
    project: string;
    // last_edit: Apollo_Time;  // ??
}

Session_Dir :: struct {
    name: string;
    modtime: Apollo_Time;
}

MAX_SESSIONS_TO_STORE :: 20;
