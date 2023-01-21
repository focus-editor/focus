start_fresh_session :: () -> Session {
    // Create a new folder to store session data
    now := current_time_consensus();
    current_session_name := tprint("session_%_%", formatInt(now.high, base=16), formatInt(now.low, base=16));
    current_session_dir  := tprint("%/temp/%", exe_dir, current_session_name);
    
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
    // !!!!!!!!!!!!!!!!!!!!!!!!!!! replace with state.ini !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    project_file_path := get_session_file_path_tmp("project");
    project_name, success := read_entire_file(project_file_path);
    if success then session_set_project(project_name);
}

init_logger :: () {
    log_path       := get_session_file_path_tmp("log.txt");
    log_error_path := get_session_file_path_tmp("log_error.txt");
    
    init(*logger_mutex, "Session Logger Mutex");
    
    success: bool;
    logger_data := New(Session_Logger_Data);
    logger_data.log_file, success = file_open(log_path, for_writing = true, keep_existing_content = true, log_errors = false);
    if !success {
        log_error("Couldn't open file '%' for writing. Logger is not initialized.", log_path);
        return;
    }
    logger_data.log_error_file, success = file_open(log_error_path, for_writing = true, keep_existing_content = true, log_errors = false);
    if !success {
        log_error("Couldn't open file '%' for writing. Logger is not initialized.", log_path);
        return;
    }
    
    logger_data.initted = true;
    
    context.logger      = session_logger;
    context.logger_data = logger_data;
    
    // Check default logger, how it handles log levels
}

deinit_logger :: () {
    if !context.logger_data return;
    logger_data := cast(*Session_Logger_Data) context.logger_data;
    if !logger_data.initted return;
    
    file_close(*logger_data.log_file);
    file_close(*logger_data.log_error_file);
}

session_notify_modified_buffer :: (buffer_id: s64) {
    session.last_modified_time = current_time_monotonic();
    array_add_if_unique(*session.modified_buffers, buffer_id);
}

maybe_save_buffer_state_into_session :: () {
    TIMEOUT_MS :: 500;  // how long to wait after last edit before saving the state
    if !session.modified_buffers return;
    if to_milliseconds(current_time_monotonic() - session.last_modified_time) < TIMEOUT_MS return;
    
    if !queue_initted {
        queue = File_Async.initialize_queue(s64);
        queue_initted = true;
    }
    
    // Check for any completed saves and free the data
    for saves_in_flight {
        buffer_id, _, result := File_Async.wait_for_completion(*queue, check_only = true);
        if result.code == {
            case .Success;
                array_free(it.data);
                remove it;
            case .DidNotWait;
                // Do nothing, we just checked
            case;
                log_error("Error when trying to wait for completion of an async buffer backup: %", result);
        }
    }
    
    for buffer_id : session.modified_buffers {
        // If the buffer is already in flight, skip it for now (next time it will hopefully not be in flight)
        for saves_in_flight {
            if buffer_id == it.buffer_id continue buffer_id;
        }
        
        // Buffer is modified, save its state
        data := dump_buffer_state(buffer_id);
        
        // Start an async write to the file
        file_path := tprint("%/temp/%/buffer%", exe_dir, session.name, buffer_id);
        result := File_Async.write_entire_file(*queue, file_path, data, buffer_id);
        if result.code == {
            case .Success;
                // Remember the data so we can free it when it's done
                save_in_flight := array_add(*saves_in_flight);
                save_in_flight.buffer_id = buffer_id;
                save_in_flight.data      = data;
                
                remove buffer_id;
                
            case .FullQueue;
                // Should never happen, but just in case.
                // Retry again at a later time.
                session.last_modified_time = current_time_monotonic();
        
            case;
                log_error("Error when trying to queue an async buffer backup: %", result);
                remove buffer_id;  // do not retry
        }
    }
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
    
    if file_exists(tprint("%/state.ini", src_session)) {
        success = copy_file(tprint("%/state.ini", src_session), tprint("%/state.ini", dst_session));
    }
    
    // TODO: copy other files when we have them
    
    return success;
}

session_set_project :: (project: string) {
    session.project = project;
    platform_set_window_title(tprint("% - Focus", project));
}

dump_buffer_state :: (buffer_id: s64) -> [] u8 #must {
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
    
    // Prepare a string with everything
    builder: String_Builder;
    init_string_builder(*builder);
    
    append(*builder, cast(*u8) *state, size_of(Buffer_State));
    
    if buffer.modified append(*builder, buffer.bytes.data, buffer.bytes.count);
    
    str := builder_to_string(*builder);
    
    return cast([] u8) str;
}

session_logger :: (message: string, data: *void, info: Log_Info) {    
    {
        lock(*logger_mutex);
        defer unlock(*logger_mutex);
        
        d := cast(*Session_Logger_Data) data;
    
        file := ifx (info.common_flags & .ERROR) != 0 then *d.log_error_file else *d.log_file;
        file_write(file, message);
        if message[message.count-1] != #char "\n" then file_write(file, "\n");
    }
    
    #if DEBUG {
        // Write to stdout/stderr
        context.default_logger(message, data, info);
    }    
}

get_session_file_path_tmp :: (subpath: string, args: .. Any) -> string /* temp */ {
    assert(exe_dir.count > 0);
    assert(session.name.count > 0);
    file_path := tprint(subpath, ..args);
    return tprint("%/temp/%/%", exe_dir, session.name, file_path);
}

#scope_export

session: Session;

#scope_file

Session_Logger_Data :: struct {
    log_file: File;
    log_error_file: File;
    initted := false;
}

Session :: struct {
    name: string;
    project: string;
    last_edit: Apollo_Time;
    
    modified_buffers: [..] s64;
    last_modified_time: Apollo_Time;
}

Session_Dir :: struct {
    name: string;
    modtime: Apollo_Time;
}

Buffer_State :: struct {
    version: s64;   // TODO
    checksum: s64;  // TODO
    
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

Async_Buffer_Save :: struct {
    buffer_id: s64;
    data: [] u8;
}

queue: File_Async.Queue(s64);
queue_initted := false;

saves_in_flight: [..] Async_Buffer_Save;

logger_mutex: Mutex;

MAX_SESSIONS_TO_STORE :: 10;