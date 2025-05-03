start_fresh_session :: () -> Session {
    // Create a new folder to store session data
    now := current_time_consensus_backwards_compatible();
    current_session_name := tprint("session_%_%", formatInt(now.high, base=16), formatInt(now.low, base=16));
    current_session_dir  := tprint("%/%", temp_dir, current_session_name);

    if !make_directory_if_it_does_not_exist(current_session_dir) {
        panic_messagebox("Couldn't create a new session '%' - please check directory permissions", current_session_dir);
    }

    new_session := Session.{};
    new_session.name      = copy_string(current_session_name);
    new_session.last_edit = now;

    return new_session;
}

maybe_load_previous_session :: () -> Session {
    assert(!session.name, "If we need to recreate a session then the old one needs to be cleared");

    session_dirs := get_sorted_session_dirs_tmp();

    // Delete old sessions if we have too many
    {
        num_old_sessions := session_dirs.count - MAX_SESSIONS_TO_STORE;
        if num_old_sessions > 0 {
            for i : 1 .. num_old_sessions {
                session_dir := tprint("%/%", temp_dir, session_dirs[session_dirs.count - i].name);
                deleted := delete_dir_recursively(session_dir);
                if !deleted log_error("Couldn't delete old session '%'", session_dir);
            }
        }
    }

    // Create a new session dir after looking for the last one
    new_session := start_fresh_session();

    if session_dirs {
        last_session_name := session_dirs[0].name;
        copy_session_data(last_session_name, new_session.name);
    }

    return new_session;

    // // Set active project if it exists
    // {
    //     project_file_path := get_session_file_path_tmp("project");
    //     project_name, success := read_entire_file(project_file_path);
    //     if success then session_set_project(project_name);
    // }
    //
    // // Load editor state
    // {
    //     state_file_path := get_session_file_path_tmp("state");
    //     file_data, success := read_entire_file(state_file_path);
    //     if !success return;  // no need to load anything else from the session if no state present
    //
    //     State_File_Data :: struct {
    //         editor_state: Editor_State;
    //         meow_hash: u64;
    //     }
    //
    //     if file_data.count != size_of(State_File_Data) {
    //         log_error("Session state file '%' - unexpected size % bytes. Expected % bytes.", state_file_path, file_data.count, size_of(State_File_Data));
    //         return;
    //     }
    //
    //     state_data := cast(*State_File_Data) file_data.data;
    //     contents: [] u8 = --- ;
    //     contents.data  = cast(*u8) state_data;
    //     contents.count = size_of(Editor_State);
    //     hash := calculate_hash(contents);
    //     if hash != state_data.meow_hash {
    //         log_error("Session state file '%' possibly corrupted - hash doesn't match", state_file_path);
    //         return;
    //     }
    //
    //     // At this point the editor state is verifiably correct, but obviously we can't just replace the actual
    //     // editor state with the loaded one, because the opened editor ids are all different etc.
    //     // This is therefore just a temporary storage for the loaded data, it will be finalised when we process
    //     // all the buffer data stored in the session and know the actual ids.
    //     session.editors = state_data.editor_state;
    //     // editors.layout = session.editors.layout;
    //     // editors.active = 0;
    //     // editors.left   = 0;
    //     // editors.right  = 0;
    // }
    //
    // // Load previously open buffers
    // {
    //     last_session_dir := tprint("%/%", temp_dir, last_session_name);
    //
    //     visitor :: (info: *File_Visit_Info, _data: *void) {
    //         if !begins_with(info.short_name, "buffer") return;
    //
    //         file_data, success := read_entire_file(info.full_name);
    //         if !success {
    //             log_error("Couldn't read the buffer backup file '%'", info.full_name);
    //             return;
    //         }
    //
    //         min_file_size := size_of(Buffer_State) + size_of(u64);
    //         if file_data.count < min_file_size {
    //             log_error("File '%' is less than the minimum expected size '%'. Actual size: '%'. Skipping.", info.full_name, min_file_size, file_data.count);
    //             return;
    //         }
    //
    //         file_data.count -= size_of(u64);  // cut off the hash at the end
    //         stored_hash := << cast(*u64) (file_data.data + file_data.count);
    //         if stored_hash != calculate_hash(to_bytes(file_data)) {
    //             log_error("File '%' may be corrupt - hashes don't match", info.full_name);
    //             return;  // don't process this file
    //         }
    //
    //         buf := cast(*Buffer_State) file_data.data;
    //         if buf.version != Buffer_State.CURRENT_VERSION {
    //             log_error("File '%' has an old version - skipping", info.full_name);
    //             return;
    //         }
    //
    //         // assert(buf.has_file, "UNIMPLEMENTED: we don't support buffers without files yet");
    //         if !buf.has_file return;
    //
    //         // // Process the file
    //         // buffer_id := find_or_create_buffer(buf.file.full_path);
    //         //
    //         // // recover_editor :: (buffer_id: s64, )
    //         //
    //         // if !buf.unsaved {
    //         //     using session.editors;
    //         //     // Only create an editor for a buffer that wasn't modified if it was open in a visible editor
    //         //     if #complete layout == {
    //         //         case .None;
    //         //             return;  // not open anywhere
    //         //         case .Single;
    //         //             if active != buf.editor1.editor_id && (!buf.editor2_exists || active != buf.editor2.editor_id) return;
    //         //         case .Double;
    //         //             if (
    //         //                 left != buf.editor1.editor_id && right != buf.editor1.editor_id &&
    //         //                 (!buf.editor2_exists || (left != buf.editor2.editor_id && right != buf.editor2.editor_id))
    //         //             ) return;
    //         //     }
    //         //
    //         //     // // Create buffer and recover editor(s)
    //         //     // buffer_id := find_or_create_buffer(buf.file.full_path);
    //         //     // editor_id, created := find_or_create_editor(buffer_id);
    //         //     // editors.active = editor_id;
    //         //     // if created {
    //         //     //     // Recover cursor and viewport position
    //         //     //     editor := *open_editors[editor_id];
    //         //     //     editor.cursors[0] = editor_state.main_cursor;
    //         //     //     editor.viewport.top  = editor_state.viewport_top;
    //         //     //     editor.viewport.left = editor_state.viewport_left;
    //         //     // }
    //         // }
    //     }
    //
    //     visit_files(last_session_dir, recursive = false, null, visitor);
    // }
}

delete_dir_recursively :: (dir_path: string) -> deleted: bool {
    // NOTE: ideally we'd want to use the standard library's delete_directory function,
    //       but on Windows it uses the SHFileOperationW function, which can load
    //       a HELL OF A LOT of useless DLLs into the process and cause an unnecessary slowdown.
    //       So we're doing it ourselves here.

    success := true;

    directory_visitor_func :: (info: *File_Visit_Info, success_pointer: *bool) {
        if info.is_directory {
            visit_files(info.full_name, recursive=false, success_pointer, directory_visitor_func, visit_files=true, visit_directories=true);
            deleted := delete_empty_dir(info.full_name);
            if !deleted then success_pointer.* = false;
        } else {
            deleted := file_delete(info.full_name);
            if !deleted then success_pointer.* = false;
        }
    }

    visit_files(dir_path, recursive=false, *success, directory_visitor_func, visit_files=true, visit_directories=true);

    deleted := delete_empty_dir(dir_path);
    if !deleted then success = false;

    return success;
}

delete_empty_dir :: (dir_path: string) -> deleted: bool {
    #if OS == .WINDOWS {
        deleted := RemoveDirectoryW(utf8_to_wide(dir_path,, temp));
        return cast(bool) deleted;
    } else {
        POSIX :: #import "POSIX";
        result := POSIX._remove(temp_c_string(dir_path));
        return result == 0;
    }
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
}

deinit_logger :: () {
    if !context.logger_data return;
    logger_data := cast(*Session_Logger_Data) context.logger_data;
    if !logger_data.initted return;

    file_close(*logger_data.log_file);
    file_close(*logger_data.log_error_file);
}

session_notify_modified_buffer :: (buffer_id: s64) {
    // session.last_modified_time = current_time_monotonic();
    // array_add_if_unique(*session.modified_buffers, buffer_id);
}

// TODO:
maybe_save_editor_state_into_session :: () {
    // Remember editor state if changed
    if editor_state_changed() {
        session.editors = editors;
        save_editor_state_into_file();
        // !!!!!!!!!!! last_edit (also below!)
    }

    // Maybe remember buffer state
    TIMEOUT_MS :: 500;  // how long to wait after last edit before saving the buffer state
    if !session.modified_buffers return;
    if to_milliseconds(current_time_monotonic() - session.last_modified_time) < TIMEOUT_MS return;

    if !queue_initted {
        queue = File_Async.initialize_queue(s64);
        queue_initted = true;
    }

    // Check for any completed saves and free the data
    for 0 .. saves_in_flight.count - 1 {
        buffer_id, _, result := File_Async.wait_for_completion(*queue, check_only = true);
        if result.code == {
            case .Success;
                for saves_in_flight {
                    if it.buffer_id == buffer_id {
                        array_free(it.data);
                        remove it;
                        break;
                    }
                }
            case .DidNotWait;
                // Do nothing, we just checked
                break;
            case;
                log_error("Error when trying to wait for completion of an async buffer backup: %", result);
        }
    }

    for buffer_id : session.modified_buffers {
        // If the buffer save is already in flight, skip it for now (next time it will hopefully not be in flight)
        for saves_in_flight {
            if buffer_id == it.buffer_id continue buffer_id;
        }

        // Buffer is modified, save its state
        data := dump_buffer_state(buffer_id);

        // Start an async write to the file
        file_path := tprint("%/%/buffer%", temp_dir, session.name, buffer_id);
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

get_sorted_session_dirs_tmp :: () -> [] Session_Dir /* temporary storage */ {
    session_dirs: [..] Session_Dir;
    session_dirs.allocator = temp;

    // Get all session dirs
    visitor :: (info: *File_Visit_Info, sessions: *[..] Session_Dir) {
        if !begins_with(info.short_name, "session_") return;

        array_add(sessions, Session_Dir.{ name = copy_temporary_string(info.short_name), modtime = info.modification_time });
    }
    visit_files(temp_dir, recursive = false, *session_dirs, visitor, visit_files = false, visit_directories = true);

    if !session_dirs return Session_Dir.[];

    // Sort the dirs from newest to oldest
    cmp_dirs :: (dir1: Session_Dir, dir2: Session_Dir) -> s64 {
        if dir1.modtime > dir2.modtime return -1;
        if dir2.modtime > dir1.modtime return  1;
        return 0;
    }
    bubble_sort(session_dirs, cmp_dirs);

    return session_dirs;
}

copy_session_data :: (source: string, dest: string) {
    src_session := tprint("%/%", temp_dir, source);
    dst_session := tprint("%/%", temp_dir, dest);

    visitor :: (info: *File_Visit_Info, dst_dir: *string) {
        if info.short_name != "state" && info.short_name != "project" return;
        // NOTE: we don't copy any buffer backup files, because we'd have to delete them after loading anyway

        success := copy_file(info.full_name, tprint("%/%", <<dst_dir, info.short_name));
        if !success log_error("Couldn't copy session file '%' into '%'", info.full_name, <<dst_dir);
    }

    visit_files(src_session, recursive = false, *dst_session, visitor);
}

session_set_project :: (project: string) {
    session.project = project;
    // platform_set_window_title(tprint("% - Focus", project));
}

save_editor_state_into_file :: () {
    state_file_path := get_session_file_path_tmp("state");

    builder: String_Builder;
    init_string_builder(*builder);

    data: string = ---;
    data.data  = cast(*u8) *session.editors;
    data.count = size_of(type_of(session.editors));

    hash := calculate_hash(to_bytes(data));

    append(*builder, data);
    append(*builder, cast(*u8) *hash, size_of(type_of(hash)));

    success := write_entire_file(state_file_path, *builder, do_reset = true);
    if !success then log_error("Couldn't save editor state into file '%'", state_file_path);
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

    state.mod_info  = buffer.mod_info;

    // Find editors and remember their state
    editor_states: [2] Buffer_State.Editor = ---;
    num_editors := 0;
    for open_editors {
       if it.buffer_id != buffer_id continue;

       editor_state := *editor_states[num_editors];
       editor_state.editor_id     = it_index;
       editor_state.main_cursor   = it.cursors[it.main_cursor];
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

    // @Speed: this is done every frame for every buffer modified that frame, so it may be a lot of copying if the buffer is large
    if buffer.modified append(*builder, buffer.bytes.data, buffer.bytes.count);

    // Calculate and append a hash for verification
    hashable_str := builder_to_string(*builder, do_reset = false,, allocator = temp);
    meow_hash := calculate_hash(to_bytes(hashable_str));
    append(*builder, cast(*u8) *meow_hash, size_of(type_of(meow_hash)));

    str := builder_to_string(*builder);

    return cast([] u8) str;
}

session_logger :: (raw_msg: string, data: *void, info: Log_Info) {
    d := cast(*Session_Logger_Data) data;
    file := ifx (info.common_flags & .ERROR) != 0 then *d.log_error_file else *d.log_file;

    calendar_time := to_calendar(current_time_consensus_backwards_compatible(), .LOCAL);
    message := tprint("%: %", calendar_to_string(calendar_time), raw_msg);

    lock(*logger_mutex);
    file_write(file, message);
    if message[message.count-1] != #char "\n" then file_write(file, "\n");
    unlock(*logger_mutex);

    #if DEBUG {
        // Write to stdout/stderr
        if (info.common_flags & .TO_FILE_ONLY) == 0 {
            runtime_support_default_logger(message, data, info);
        }
    }
}

get_session_file_path_tmp :: (subpath: string, args: .. Any) -> string /* temp */ {
    assert(session.name.count > 0);
    file_path := tprint(subpath, ..args);
    return tprint("%/%/%", temp_dir, session.name, file_path);
}

editor_state_changed :: () -> bool {
    return false;
    // TODO:
    // return (
    //     editors.active   != session.editors.active   ||
    //     editors.left     != session.editors.left     ||
    //     editors.right    != session.editors.right    ||
    //     editors.layout   != session.editors.layout   ||
    //     editors.expanded != session.editors.expanded
    //     // NOTE: we ignore .closing because we don't care
    // );
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
    editors: Editor_State;
    last_edit: Apollo_Time;

    modified_buffers: [..] s64;
    last_modified_time: Apollo_Time;
}

Session_Dir :: struct {
    name: string;
    modtime: Apollo_Time;
}

Buffer_State :: struct {
    version: s64;

    buffer_id: s64;

    file: File_Info;
    has_file: bool;
    unsaved: bool;

    mod_info: Buffer.Mod_Info;

    // Every buffer may have up to 2 editors
    editor1: Editor;
    editor2: Editor;
    editor2_exists := false;

    bytes_size: s64;
    // bytes will go here in the file (if the file is unsaved)

    CURRENT_VERSION :: 1;

    Editor :: struct {
        editor_id: s64;  // for identifying whether this buffer is shown in the saved layout. No use for it otherwise
        main_cursor: Cursor;

        viewport_top:  s32;
        viewport_left: s32;
    }
}

Async_Buffer_Save :: struct {
    buffer_id: s64;
    data: [] u8;
}

queue: File_Async.Queue(s64);
queue_initted := false;

saves_in_flight: [..] Async_Buffer_Save;

logger_mutex: Mutex;

MAX_SESSIONS_TO_STORE :: 50;  // in case people open several files in several editors, hopefully should be enough
