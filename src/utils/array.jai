// An expandable array type with a small memory footprint - 16 bytes (vs 40 bytes for [..])
// It doesn't store an allocator and uses s32 for indices.
// We are not targeting the use case of files over 2Gb in size to keep things small.
// We use lots of arrays, so any memory saving here is valuable.

// IMPORTANT: All allocations use focus_allocator. If you need an array which uses another allocator, use [..]

Array :: struct(T: Type) {
    count: s32;
    allocated: s32;
    data: *T;
}

operator ! :: inline (array: Array) -> bool {
    return is_empty(array);
}

is_empty :: inline (array: Array($T)) -> bool {
    return array.count == 0 || array.data == null;
}

operator [] :: inline (array: Array($T), index: int) -> T {
    assert(index >= 0);
    assert(index < array.count);
    return array.data[index];
}

operator *[] :: inline (array: Array($T), index: int) -> *T {
    assert(index >= 0);
    assert(index < array.count);
    return array.data + index;
}

operator []= :: inline (array: *Array($T), index: int, value: T) {
    assert(index >= 0);
    assert(index < array.count);
    array.data[index] = value;
}

for_expansion :: (array: *Array($T), body: Code, flags: For_Flags) #expand {
    DO_POINTER :: cast(bool)(flags & .POINTER);
    DO_REVERSE :: cast(bool)(flags & .REVERSE);

    `it_index: s32;
    #if DO_POINTER { `it: *T; } else {`it: T; }

    #if DO_REVERSE {
        it_index = array.count;
        while it_index > 0 {
            it_index -= 1;
            #if DO_POINTER { it = *array.data[it_index]; } else { it = array.data[it_index]; }
            #insert (remove={unordered_remove_by_index(array, it_index); }) body;
        }
    } else {
        it_index = -1;
        while it_index < array.count - 1 {
            it_index += 1;
            #if DO_POINTER { it = *array.data[it_index]; } else { it = array.data[it_index]; }
            #insert (remove={unordered_remove_by_index(array, it_index); it_index -= 1;}) body;
        }
    }
}

from_view :: inline (array: [] $T) -> Array(T) {
    result: Array(T) = ---;
    result.count = cast(s32) array.count;
    result.allocated = result.count;
    result.data  = array.data;
    return result;
}

to_string :: inline (array: Array($T)) -> string {
    return string.{ count = array.count * size_of(T), data = array.data };
}

to_view :: inline (array: Array($T)) -> [] T {
    result: [] T = ---;
    result.count = array.count;
    result.data  = array.data;
    return result;
}

to_view :: inline (array: Array($T), offset: s64, count: s64) -> [] T {
    assert(offset >= 0, "offset = %", offset);
    assert(count  >= 0, "count = %",  count);
    if offset >= array.count return .[];
    if offset + count > array.count then count = array.count - offset;

    result: [] T = ---;
    result.data = array.data + offset;
    result.count = count;
    return result;
}

add :: (array: *Array($T), item: T) {
    maybe_grow(array);
    array.data[array.count] = item;
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
    result := to_view(array)[array.count-1];
    array.count -= 1;
    return result;
}

peek :: inline (array: Array($T)) -> T {
    return array[array.count-1];
}

peek_pointer :: inline (array: Array($T)) -> *T {
    return *array[array.count-1];
}

free :: inline (array: Array($T)) {
    free(array.data);
}

delete_range :: (array: *Array($T), offset: s32, count: s32) {
    assert(offset >= 0 && count >= 0 && offset + count <= array.count);
    focus_memcpy(array.data + offset, array.data + offset + count, (array.count - offset - count) * size_of(T));
    array.count -= count;
}

unordered_remove_by_index :: inline (array: *Array($T), index: s32) {
    assert(index >= 0);
    assert(index < array.count);

    last_index := array.count - 1;
    if index != last_index  array.data[index] = array.data[last_index];

    array.count -= 1;
}

ordered_remove_by_index :: inline (array: *Array($T), index: s32) {
    assert(index >= 0);
    assert(index < array.count);

    for i : index..array.count-2  array.data[i] = array.data[i+1];

    array.count -= 1;
}

copy :: (array: Array($T)) -> Array(T) {
    dest := NewArray(array.count, T, initialized=false);
    memcpy(dest.data, array.data, array.count * size_of(T));
    return from_view(dest);
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

resize :: (array: *Array($T), new_count: s64, $initialize:=true) {
    old_count := array.count;
    reserve_(xx array, cast(s32) new_count, size_of(T));
    array.count = cast(s32) new_count;

    #if initialize  init_range(array.data, old_count, new_count);
}

maybe_grow :: inline (array: *Array($T)) {
    if array.count >= array.allocated {
        reserve := 2 * array.allocated;
        if reserve < 8  reserve = 8;

        reserve_(xx array, reserve, size_of(T));
    }
}

to_owned_array :: (array: *Array($T), $free_memory := false) -> [] T {
    new_array := copy(array);
    #if free_memory {
        reset(array);
    } else {
        reset_keeping_memory(array);
    }
    return to_view(new_array);
}

#scope_file

init_range :: (ptr: *$T, begin: s64, end: s64) {
    ini :: initializer_of(T);
    #if ini {
        for begin..end-1  inline ini(ptr + it);  // Really this can be one ini followed by a bunch of memcpy. For long arrays we could power-of-two double the copy out, etc.
    } else {
        count := end - begin;
        if count <= 0  return;

        // Fast path for init to zero.
        // In the case that we are shrinking an array, count will be negative.
        memset(ptr + begin, 0, count * size_of(T));
    }
}

reserve_ :: (array: *Array(void), desired_items: s32, element_size: s32) {
    if desired_items <= array.allocated return;

    array.data = realloc(array.data, desired_items * element_size, array.allocated * element_size,, focus_allocator);
    assert(array.data != null);

    array.allocated = desired_items;
}

