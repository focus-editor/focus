Buffer_Id :: #type,distinct s64;
Editor_Id :: #type,distinct s64;

get_buffer :: inline (id: Buffer_Id) -> *Buffer {  // guarantees the buffer exists
    found, buffer := find_buffer(id);
    assert(found, "Attempted to call get_buffer(%) but the buffer doesn't exist", id);
    return buffer;
}

find_buffer :: (id: Buffer_Id) -> found: bool, *Buffer {
    found, locator := table_find(*buffer_locators, id);
    if !found return false, null;

    return true, bucket_array_find_pointer(*open_buffers, locator);
}

exists :: inline (buffer_id: Buffer_Id) -> bool {
    return find_buffer(buffer_id);
}

next_unique_buffer_id :: () -> Buffer_Id {
    last_buffer_id += 1;
    return last_buffer_id;
}

register_new_buffer :: () -> Buffer_Id, buffer: *Buffer {
    buffer_id := next_unique_buffer_id();
    buffer, locator := find_and_occupy_empty_slot(*open_buffers);
    table_set(*buffer_locators, buffer_id, locator);

    init(*buffer.content_lock);
    init(*buffer.settings_lock);
    buffer.id = buffer_id;

    buffer_registry_revision += 1;

    return buffer_id, buffer;
}

remove_buffer :: (id: Buffer_Id) {
    assert(buffer_snapshot_users == 0);
    buffer := get_buffer(id);
    for mapped_id, path : buffers_table {
        if mapped_id != id continue;
        remove mapped_id;
        free(path);
        break;
    }
    _, locator := table_remove(*buffer_locators, id);
    free_buffer(buffer);
    bucket_array_remove(*open_buffers, locator);
    buffer_registry_revision += 1;
}

find_buffer_id_by_path :: (path: string) -> Buffer_Id {
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
    found, locator := table_find(*editor_locators, id);
    if !found return false, null;
    return true, bucket_array_find_pointer(*open_editors, locator);
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
    editor, locator := find_and_occupy_empty_slot(*open_editors);
    editor.id = editor_id;
    table_set(*editor_locators, editor_id, locator);
    return editor_id, editor;
}

remove_editor :: (id: Editor_Id) {
    editor := get_editor(id);
    _, locator := table_remove(*editor_locators, id);
    array_ordered_remove_by_value(*recently_closed_editors, id);
    free_editor(editor);
    bucket_array_remove(*open_editors, locator);
}

get_editor_and_buffer :: inline (editor_id: Editor_Id) -> *Editor, *Buffer {
    editor := get_editor(editor_id);
    buffer := get_buffer(editor.buffer_id);
    return editor, buffer;
}

do_registry_cleanup :: () {
    if buffer_snapshot_users > 0 return;

    // Reclaim unused buffer snapshots
    for buffer_ptr_snapshots {
        if it.revision != buffer_registry_revision {
            array_free(it.buffer_ptrs);
            remove it;
        }
    }
}

// Build an array of stable buffer pointers which threads can use
get_immutable_buffer_ptrs_snapshot :: () -> [] *Buffer {
    // First see if we have it in cache
    for buffer_ptr_snapshots {
        if it.revision == buffer_registry_revision return it.buffer_ptrs;
    }

    // Build a new snapshot
    buffer_ptrs := NewArray(open_buffers.count, *Buffer, initialized = false);
    for * open_buffers {
        buffer_ptrs[it_index] = it;
    }
    array_add(*buffer_ptr_snapshots, .{ buffer_registry_revision, buffer_ptrs });

    return buffer_ptrs;
}

begin_buffer_snapshot_use :: () {
    buffer_snapshot_users += 1;
}

end_buffer_snapshot_use :: () {
    assert(buffer_snapshot_users > 0);
    buffer_snapshot_users -= 1;
}

// TODO: make these private too
open_buffers: Bucket_Array(Buffer, items_per_bucket = 1024);
open_editors: Bucket_Array(Editor, items_per_bucket = 128);

// A map from full buffer path to buffer id (only for the open buffers, obviously)
buffers_table: Table(string, Buffer_Id,
                     given_hash_function = x => Hash.get_hash(to_lower_copy(x,, temp)),
                     given_compare_function = platform_path_equals);

#scope_file

last_buffer_id: Buffer_Id = -1;
last_editor_id: Editor_Id = -1;

buffer_locators: Table(Buffer_Id, Bucket_Locator);
editor_locators: Table(Editor_Id, Bucket_Locator);

buffer_registry_revision: u64;
buffer_ptr_snapshots: [..] Buffer_Ptr_Snapshot;
buffer_snapshot_users := 0;

Buffer_Ptr_Snapshot :: struct {
    revision: u64;
    buffer_ptrs: [] *Buffer;
}

