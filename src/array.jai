// An expandable array type with a small memory footprint - 16 bytes (vs 40 bytes for [..])
// It doesn't store an allocator and uses s32 for indices.
// We are not targeting the use case of files over 2Gb in size to keep things small.
// We use lots of arrays, so any memory saving here is valuable.

// IMPORTANT: All allocations use focus_allocator. If you need an array which uses another allocator, use [..]

Array :: struct(T: Type) {
    data: *T;
    count: s32;
    allocated: s32;
}

operator ! :: inline (array: Array) -> bool {
    return is_empty(array);
}

is_empty :: inline (array: Array($T)) -> bool {
    return array.count == 0 || array.data == null;
}

operator [] :: inline (array: Array($T), index: int) -> T {
    return to_array(array)[index];
}

operator *[] :: inline (array: Array($T), index: int) -> *T {
    return *to_array(array)[index];
}

operator []= :: inline (array: *Array($T), i: int, value: T) {
    a := to_array(array);
    a[i] = value;
}

for_expansion :: (array: *Array($T), body: Code, flags: For_Flags) #expand {
    DO_POINTER :: cast(bool)(flags & .POINTER);
    DO_REVERSE :: cast(bool)(flags & .REVERSE);

    for <=DO_REVERSE *=DO_POINTER `it, `it_index : to_array(array) {
        #insert (remove=#assert(false)) body;
        // TODO: implement remove. Example:
        // #insert (remove={entry.hash=REMOVED_HASH; table.count-=1;}) body;
    }
}

to_array :: inline (array: Array($T)) -> [] T {
    result: [] T = ---;
    result.count = array.count;
    result.data  = array.data;
    return result;
}

to_string :: inline (array: Array($T)) -> string {
    return string.{ count = array.count * size_of(T), data = array.data };
}

array_view :: inline (array: Array($T), offset: s32, count: s32) -> [] T {
    assert(offset >= 0, "offset = %", offset);
    assert(count  >= 0, "count = %",  count);
    if offset >= array.count return .[];
    if offset + count > array.count then count = array.count - offset;

    result: [] T = ---;
    result.data = array.data + offset;
    result.count = count;
    return result;
}

add :: (array: *Array($T), item: T) #no_abc {
    maybe_grow(array);
    array.data[array.count] = item;  // Note, we don't have an ABC here since we believe maybe_grow does the right thing.
    array.count += 1;
}

add :: (array: *Array($T)) -> *T #must {
    maybe_grow(array);
    result := *array.data[array.count];

    ini :: initializer_of(T);
    #if ini {
        ini(result);
    } else {
        memset(result, 0, size_of(T));
    }

    array.count += 1;
    return result;
}

insert_at :: (array: *Array($T), offset: s32, src_array: [] T) {
    assert(offset >= 0 && offset <= array.count);
    if !src_array return;

    new_count := array.count + cast(s32) src_array.count;
    reserve(array, new_count);

    src := array.data + offset;
    dst := src + src_array.count;
    focus_memcpy(dst, src, (array.count - offset) * size_of(T));

    focus_memcpy(array.data + offset, src_array.data, src_array.count * size_of(T));

    array.count = new_count;
}

pop :: (array: *Array($T)) -> T {
    result := to_array(array)[array.count-1];
    array.count -= 1;
    return result;
}

delete_range :: (array: *Array($T), offset: s32, count: s32) {
    assert(offset >= 0 && count >= 0 && offset + count <= array.count);
    focus_memcpy(array.data + offset, array.data + offset + count, (array.count - offset - count) * size_of(T));
    array.count -= count;
}

reset :: (array: *Array($T)) {
    free(array.data,, focus_allocator);

    array.data      = null;
    array.allocated = 0;
    array.count     = 0;
}

reset_keeping_memory :: inline (array: *Array($T)) {
    array.count = 0;
}

reserve :: inline (array: *Array($T), desired_items: s32) {
    reserve_(xx array, desired_items, size_of(T));
}

maybe_grow :: inline (array: *Array($T)) {
    if array.count >= array.allocated {
        reserve := 2 * array.allocated;
        if reserve < 8  reserve = 8;

        reserve_(xx array, reserve, size_of(T));
    }
}

to_owned_array :: (array: *Array($T), $free_memory := false) -> [] T {
    new_array := array_copy(to_array(array));
    #if free_memory {
        reset(array);
    } else {
        reset_keeping_memory(array);
    }
    return new_array;
}

#scope_file

reserve_ :: (array: *Array(void), desired_items: s32, element_size: s32) {
    if desired_items <= array.allocated return;

    array.data = realloc(array.data, desired_items * element_size, array.allocated * element_size,, focus_allocator);
    assert(array.data != null);

    array.allocated = desired_items;
}

