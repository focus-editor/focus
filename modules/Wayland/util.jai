wl_object :: struct {};

wl_message :: struct {
    name: *u8;
    signature: *u8;
    types: **wl_interface;
}

wl_interface :: struct {
    name: *u8;
    version: s32;
    method_count: s32;
    methods: *wl_message;
    event_count: s32;
    events: *wl_message;
}

#load "list.jai";
wl_list_init :: (list: *wl_list) #foreign libwayland_client;
wl_list_insert :: (list: *wl_list, elm: *wl_list) #foreign libwayland_client;
wl_list_remove :: (list: *wl_list) #foreign libwayland_client;
wl_list_length :: (list: *wl_list) -> s32 #foreign libwayland_client;
wl_list_empty :: (list: *wl_list) -> s32 #foreign libwayland_client;
wl_list_insert_list :: (list: *wl_list, other: *wl_list) #foreign libwayland_client;

#load "array.jai";
wl_array_init :: (array: *wl_array) #foreign libwayland_client;
wl_array_release :: (array: *wl_array) #foreign libwayland_client;
wl_array_add :: (array: *wl_array, size: size_t) -> *void #foreign libwayland_client;
wl_array_copy :: (array: *wl_array, source: *wl_array) -> s32 #foreign libwayland_client;

wl_fixed_t :: s32;

wl_fixed_to_double :: inline (f: wl_fixed_t) -> float64 #c_call {
    u: union {
        d: float64;
        i: s64;
    };
    u.i = (cast(s64)(1023 + 44) << 52) + (cast(s64)1 << 51) + f;
    return u.d - cast(float64)(cast(s64)3 << 43);
}

wl_fixed_from_double :: inline (d: float64) -> wl_fixed_t #c_call {
    u: union {
        d: float64;
        i: s64;
    };
    u.d = d + cast(float64)(cast(s64)3 << (51 - 8));
    return cast(wl_fixed_t)u.i;
}

wl_fixed_to_int :: inline (f: wl_fixed_t) -> s32 #c_call {
    return f / 256;
}

wl_fixed_from_int :: inline (i: s32) -> wl_fixed_t #c_call {
    return i * 256;
}

wl_argument :: union {
    i: s32;
    u: u32;
    f: wl_fixed_t;
    s: *u8;
    o: *wl_object;
    n: u32;
    a: *wl_array;
    h: s32;
}

wl_dispatcher_func_t :: #type (*void, *void, u32, *wl_message, *wl_argument) -> s32 #c_call;
/* TODO: wl_log_func_t uses va_list which cannot be ported at this time */
wl_log_func_t :: generic_c_call;

wl_iterator_result :: enum {
    WL_ITERATOR_STOP;
    WL_ITERATOR_CONTINUE;
}

/* made-up stuff */
wl_min :: (a: $T, b: T) -> T #c_call {
    if a < b return a;
    return b;
}

wl_max :: (a: $T, b: T) -> T #c_call {
    if a > b return a;
    return b;
}
