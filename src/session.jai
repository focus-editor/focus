start_fresh_session :: () -> Session {
    // Create a new folder to store session data
    now := current_time_consensus();
    current_session_name := tprint("session_%_%", formatInt(now.high, base=16), formatInt(now.low, base=16));
    current_session_dir := tprint("%/temp/%", exe_dir, current_session_name);
    
    if !make_directory_if_it_does_not_exist(current_session_dir) {
        panic_messagebox("Couldn't create a new session '%' - please check directory permissions", current_session_dir);
    }
    
    new_session := Session.{};
    new_session.name      = copy_string(current_session_name);
    new_session.last_edit = current_time_consensus();
    
    return new_session;
}

maybe_load_previous_session :: () {            
    last_session_name, found := get_last_session_name();
    
    // Create a new session dir after looking for the last one
    assert(!session.name, "If we need to recreate a session then the old one needs to be cleared");
    session = start_fresh_session();
    
    if found {
        // Copy last session's data over to the new one
        copied := copy_session_data(last_session_name, session.name);
        if !copied log_error("Couldn't copy last session data '%' into the new session '%'", last_session_name, session.name);
    }
    
    // Check if we have a project
    project_file_path := tprint("%/temp/%/project", exe_dir, session.name);
    project_name, success := read_entire_file(project_file_path);
    if success then session_set_project(project_name);
}

session_notify_modified_buffer :: (buffer_id: s64) {
    if !session.modified_buffers then session.modified_time = current_time_monotonic();
    array_add_if_unique(*session.modified_buffers, buffer_id);
}

maybe_save_editor_state_into_session :: () -> saved: bool {
    saved := false;
    
    for buffer_id : session.modified_buffers {
        save_buffer_state(buffer_id);
        saved = true;
    }
    
    array_reset_keeping_memory(*session.modified_buffers);
    
    return saved;
}

overdue_for_editor_state_save :: () -> bool {
    return session.modified_buffers && to_seconds(current_time_monotonic() - session.modified_time) > 10;
}

#scope_file

get_last_session_name :: () -> string, found: bool {
    temp_dir := tprint("%/temp", exe_dir);
    
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
            deleted := delete_directory(session_dir);
            if !deleted log_error("Couldn't delete old session '%'", session_dir);
        }
    }
    
    return session_dirs[0].name, true;
}

copy_session_data :: (source: string, dest: string) -> success: bool {
    src_session := tprint("%/temp/%", exe_dir, source);
    dst_session := tprint("%/temp/%", exe_dir, dest);
    
    success := true;
    
    if file_exists(tprint("%/project", src_session)) {
        success = copy_file(tprint("%/project", src_session), tprint("%/project", dst_session));
    }
    // TODO: copy other files when we have them
    
    return success;
}

session_set_project :: (project: string) {
    session.project = project;
    platform_set_window_title(tprint("% - Focus", project));
}

save_buffer_state :: (buffer_id: s64) {
    buffer := *open_buffers[buffer_id];
    
    // Build buffer state for saving into file
    state: Buffer_State;
    state.version   = Buffer_State.CURRENT_VERSION;
    
    state.buffer_id = buffer_id;
    state.file      = buffer.file;
    state.has_file  = buffer.has_file;
    state.unsaved   = buffer.modified;
    
    state.last_modtime = buffer.last_modtime;
    state.last_size    = buffer.last_size;
    
    // Find editors and remember their state
    editor_states: [2] Editor_State = ---;
    num_editors := 0;
    for open_editors {
       if it.buffer_id != buffer_id continue;
       
       editor_state := *editor_states[num_editors];
       editor_state.editor_id     = it_index;
       editor_state.main_cursor   = it.cursors[it.main_cursor].state;
       editor_state.viewport_top  = it.viewport.top;
       editor_state.viewport_left = it.viewport.left;
       
       num_editors += 1;
       if num_editors >= 2 break;
    }
    
    assert(num_editors >= 1, "Trying to save the state of a buffer without an open editor");
    
    state.editor1 = editor_states[0];
    if num_editors > 1 then state.editor2 = editor_states[1];
    state.editor2_exists = num_editors > 1;
    
    state.bytes_size = ifx buffer.modified then buffer.bytes.count else 0;  // no need to save an unmodified buffer
    
    // Write to file
    file_path := tprint("%/temp/%/buffer%", exe_dir, session.name, buffer_id);
    
    builder: String_Builder;
    init_string_builder(*builder);
    
    append(*builder, cast(*u8) *state, size_of(Buffer_State));
    
    if buffer.modified append(*builder, buffer.bytes.data, buffer.bytes.count);
    
    success := write_entire_file(file_path, *builder, do_reset = true);
    if !success log_error("Couldn't save buffer state into file '%'", file_path);
}

#scope_export

session: Session;

#scope_file

Session :: struct {
    name: string;
    project: string;
    // layout
    last_edit: Apollo_Time;
    
    modified_buffers: [..] s64;
    modified_time: Apollo_Time;  // to detect if we're taking too long to save buffers
}

Session_Dir :: struct {
    name: string;
    modtime: Apollo_Time;
}

MAX_SESSIONS_TO_STORE :: 20;

Buffer_State :: struct {
    version: s64;
    
    buffer_id: s64;
    
    file: File_Info;
    has_file: bool;
    unsaved: bool;
    
    last_modtime: Apollo_Time;
    last_size: s64;
    
    // Every buffer may have up to 2 editors
    editor1: Editor_State;
    editor2: Editor_State;
    editor2_exists := false;
    
    bytes_size: s64;
    // bytes will go here in the file (if the file is unsaved)
    
    CURRENT_VERSION :: 1;
}

Editor_State :: struct {
    editor_id: s64;  // for identifying whether this buffer is shown in the saved layout. No use for it otherwise
    main_cursor: Cursor.State;
    
    viewport_top:  s32;
    viewport_left: s32;
}