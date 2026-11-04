Buffer_Id :: #type,distinct s64;
Editor_Id :: #type,distinct s64;

get_buffer :: inline (id: Buffer_Id) -> *Buffer {  // guarantees the buffer exists
    found, buffer := find_buffer(id);
    assert(found, "Attempted to call get_buffer(%) but the buffer doesn't exist", id);
    return buffer;
}

find_buffer :: (id: Buffer_Id) -> found: bool, *Buffer {
    lock(*open_buffers_lock);
    defer unlock(*open_buffers_lock);

    found, index := table_find(*buffer_indices, id);
    if !found return false, null;

    buffer := *open_buffers[index];
    return true, buffer;
}

exists :: inline (buffer_id: Buffer_Id) -> bool {
    return find_buffer(buffer_id);
}

next_unique_buffer_id :: () -> Buffer_Id {
    last_buffer_id += 1;
    return last_buffer_id;
}

get_buffer_by_index :: (index: s64) -> *Buffer {
    lock(*open_buffers_lock);
    defer unlock(*open_buffers_lock);

    if index < 0 || index >= open_buffers.count return null;
    return *open_buffers[index];
}

register_new_buffer_locked :: () -> Buffer_Id, buffer: *Buffer {
    buffer_id := next_unique_buffer_id();
    buffer, buffer_index := bucket_array_add(*open_buffers);
    table_set(*buffer_indices, buffer_id, buffer_index);

    init(*buffer.content_lock);
    init(*buffer.settings_lock);
    buffer.id = buffer_id;

    return buffer_id, buffer;
}

find_buffer_id_by_path :: (path: string) -> Buffer_Id {
    lock(*open_buffers_lock);
    defer unlock(*open_buffers_lock);

    found_buffer, buffer_id := table_find(*buffers_table, path);
    if found_buffer return buffer_id;

    return -1;
}

get_editor :: (id: Editor_Id) -> *Editor {  // guarantees the editor exists
    found, editor := find_editor(id);
    assert(found, "Attempted to call get_editor(%) but the editor doesn't exist", id);
    return editor;
}

find_editor :: (id: Editor_Id) -> found: bool, *Editor {
    found, index := table_find(*editor_indices, id);
    if !found return false, null;
    return true, *open_editors[index];
}

exists :: inline (editor_id: Editor_Id) -> bool {
    return find_editor(editor_id);
}

next_unique_editor_id :: () -> Editor_Id {
    last_editor_id += 1;
    return last_editor_id;
}

register_new_editor :: () -> Editor_Id, editor: *Editor {
    editor_id := next_unique_editor_id();
    array_index := open_editors.count;
    editor := array_add(*open_editors);
    editor.id = editor_id;
    table_set(*editor_indices, editor_id, array_index);
    return editor_id, editor;
}

get_editor_and_buffer :: inline (editor_id: Editor_Id) -> *Editor, *Buffer {
    editor := get_editor(editor_id);
    buffer := get_buffer(editor.buffer_id);
    return editor, buffer;
}

reset_registry :: () {
    for * open_editors free_editor(it);
    array_reset(*open_editors);
    for * open_buffers free_buffer(it);
    bucket_array_reset(*open_buffers);
    array_reset(*most_recent_buffers);
    array_reset(*recently_closed_editors);

    table_reset(*buffer_indices);
    table_reset(*editor_indices);
}

// TODO: get rid of this when only the main thread can register buffers
open_buffers_lock: Mutex;  // must hold while adding a new buffer

// TODO: make these private too
open_buffers: Simple_Bucket_Array(Buffer, items_per_bucket = 1024, max_buckets = 1024);  // 8 Kb for pointer array, ~1 million buffers is the maximum
open_editors: [..] Editor;

// A map from full buffer path to buffer id (only for the open buffers, obviously)
buffers_table: Table(string, Buffer_Id,
                     given_hash_function = x => Hash.get_hash(to_lower_copy(x,, temp)),
                     given_compare_function = platform_path_equals);

#scope_file

last_buffer_id: Buffer_Id = -1;
last_editor_id: Editor_Id = -1;

buffer_indices: Table(Buffer_Id, int);
editor_indices: Table(Editor_Id, int);

