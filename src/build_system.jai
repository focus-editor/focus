init_build_system :: () {
    assert(build_buffer_id < 0 && build_editor_id < 0, "Build system already initialised");

    build_buffer_id = find_or_create_an_empty_buffer();
    build_editor_id = find_or_create_editor(build_buffer_id);
    editor, buffer := *open_editors[build_editor_id], *open_buffers[build_buffer_id];
    buffer.readonly = true;
    buffer.deleted  = true;  // so that it doesn't appear in the open file dialog
    insert_string_raw(buffer, 0, "vasia pupkin");

    build_system_thread_group = Thread_Group.{};  // in case we need to reinitialise it later

    init(*build_system_thread_group, num_threads = 1, group_proc = build_threadproc);
    start(*build_system_thread_group);
}

toggle_build_panel :: () {
    build_panel_is_shown = !build_panel_is_shown;
}

toggle_build_panel_height :: () {
    // TODO
}

build_panel_get_editor_id :: inline () -> s64 {
    assert(build_editor_id >= 0);
    return build_editor_id;
}

build_panel_is_shown := false;


#scope_file

build_threadproc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    return .CONTINUE;
}

build_system_thread_group: Thread_Group;

build_buffer_id := -1;
build_editor_id := -1;

