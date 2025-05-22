Fifo_Queue :: struct(T: Type) {
    array: [] T;
    head: s64;  // pointing to where the next enqueued element will go
    tail: s64;  // pointing to the next element to dequeue
    size: s64;
}

enqueue :: (using queue: *Fifo_Queue($T), item: T) {
    maybe_grow(queue);
    array[head] = item;
    head = (head + 1) % array.count;
    size += 1;
}

dequeue :: (using queue: *Fifo_Queue($T)) -> success: bool, item: T {
    result: T;
    if size <= 0 return false, result;

    item := array[tail];
    tail = (tail + 1) % array.count;
    size -= 1;

    return true, item;
}


#scope_file

INITIAL_SIZE :: 8;

maybe_grow :: inline (using queue: *Fifo_Queue($T)) {
    if size < array.count return;

    new_capacity := max(array.count * 2, INITIAL_SIZE);
    new_array := NewArray(new_capacity, T, initialized = false);

    if head > tail {
        assert(size == head - tail);
        memcpy(new_array.data, array.data + tail, size * size_of(T));
    } else if size > 0 {
        part1, part2 := (array.count - tail), head;
        assert(size == part1 + part2);
        memcpy(new_array.data,         array.data + tail,  part1 * size_of(T));
        memcpy(new_array.data + part1, array.data,         part2 * size_of(T));
    }

    tail = 0;
    head = size;
    array_free(array);
    array = new_array;
}
