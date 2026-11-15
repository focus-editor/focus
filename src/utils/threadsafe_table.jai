Threadsafe_Table :: struct {
    table: Table(string, bool);
    lock: Mutex;
}

init :: (table: *Threadsafe_Table, size: int) {
    init(*table.lock);
    table_resize(*table.table, size);
}

table_find_threadsafe :: (table: *Threadsafe_Table, key: string) -> bool, bool {
    lock(*table.lock);
    defer unlock(*table.lock);

    found, value := table_find(*table.table, key);
    return found, value;
}

table_set_threadsafe :: (table: *Threadsafe_Table, key: string, value: bool) -> *bool {
    lock(*table.lock);
    defer unlock(*table.lock);

    value_ptr := table_find_pointer(*table.table, key);
    if value_ptr {
        value_ptr.* = value;
        return value_ptr;
    } else {
        return table_add(*table.table, copy_string(key,, focus_allocator), value);
    }
}

table_reset_threadsafe :: (table: *Threadsafe_Table) {
    lock(*table.lock);
    defer unlock(*table.lock);

    for value, key : table.table {
        free(key,, focus_allocator);
    }
    table_reset_keeping_memory(*table.table);
}
