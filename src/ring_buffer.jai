ringbuffer_add :: (using ring_buffer: *Ring_Buffer($T, $Size), item: T) {
    data[head] = item;
    head = (head + 1) % Size;
    if count < Size then count += 1;
    total += 1;
}

ringbuffer_pop :: (using ring_buffer: *Ring_Buffer($T, $Size)) -> success: bool, item: T {
    item: T;
    if total <= 0 || count <= 0 return false, item;

    pop_index := (head + Size - 1) % Size;  // points to one slot before head - the most recently pushed item
    item = data[pop_index];
    head = pop_index;
    count -= 1;
    total -= 1;

    return true, item;
}

ringbuffer_get_pointer :: (using ring_buffer: *Ring_Buffer($T, $Size), index: s64) -> *T {

}

ringbuffer_peek_pointer :: (using ring_buffer: *Ring_Buffer($T, $Size)) -> *T {
    if total <= 0 || count <= 0 return null;

    peek_index := (head + Size - 1) % Size;  // points to one slot before head - the most recently pushed item

    return *data[peek_index];
}

for_expansion :: (ring_buffer: *Ring_Buffer($T, $Size), body: Code, flags: For_Flags) #expand {
    #assert(!(flags & .REVERSE));  // implement reverse when it's actually needed
    DO_POINTER :: cast(bool)(flags & .POINTER);

    #if DO_POINTER { `it: *T; } else {`it: T; }
    `it_index := -1;

    for i : (ring_buffer.total - ring_buffer.count) .. (ring_buffer.total - 1) {
        it_index = i;
        #if DO_POINTER {
            it = *ring_buffer.data[it_index % ring_buffer.Size];
        } else {
            it = ring_buffer.data[it_index % ring_buffer.Size];
        }
        #insert (remove=#assert(false)) body;
    }
}


Ring_Buffer :: struct(T: Type, Size: s64) {
    head:  s64;
    count: s64;
    total: s64;
    data: [Size] T;
}
