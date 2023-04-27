wl_array :: struct {
    size: s64;
    alloc: s64;
    data: *void;
}

wl_array_each :: ($T: Type, array: *wl_array) -> wl_array_each_t(T) {
    return .{array};
}

for_expansion :: (ae: *wl_array_each_t($T),  body: Code, flags: For_Flags) #expand {
    head := cast(*ae.type) ae.array.data;
    tail := cast(*ae.type) (cast(*u8) ae.array.data + ae.array.size);
    idx := 0;
    while head < tail {
        `it := head;
        `it_index := idx;

        defer head += 1;
        defer idx += 1;

        #insert body;
    }
}

#scope_file
wl_array_each_t :: struct(item_type: Type) {
    type :: item_type;
    array: *wl_array;
}
