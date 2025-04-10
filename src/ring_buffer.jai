ringbuffer_add :: (using ring_buffer: *Ring_Buffer($T, $Size), item: T) {
    buffer[head] = item;
    head = (head + 1) % Size;
    if count < Size then count += 1;
    total += 1;
}

ringbuffer_pop :: (using ring_buffer: *Ring_Buffer($T, $Size)) -> success: bool, item: T {
    item: T;
    if total <= 0 || count <= 0 return false, item;

    pop_index := (head + Size - 1) % Size;  // points to one slot before head - the most recently pushed item
    item = buffer[pop_index];
    head = pop_index;
    count -= 1;
    total -= 1;

    return true, item;
}

ringbuffer_peek_pointer :: (using ring_buffer: *Ring_Buffer($T, $Size)) -> *T {
    if total <= 0 || count <= 0 return null;

    peek_index := (head + Size - 1) % Size;  // points to one slot before head - the most recently pushed item

    return *buffer[peek_index];
}


Ring_Buffer :: struct(T: Type, Size: s64) {
    head:  s64;
    count: s64;
    total: s64;
    buffer: [Size] T;
}
