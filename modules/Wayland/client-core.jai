wl_event_queue :: struct {};

WL_MARSHAL_FLAG_DESTROY :: 1;

wl_proxy :: struct {}

using wayland_core_procs: Core_Procs;

wl_display_set_user_data :: inline (self: *wl_display, user_data: *void) #c_call {
    wl_proxy_set_user_data(self, user_data);
}

wl_display_get_user_data :: inline (self: *wl_display) -> *void #c_call {
    return wl_proxy_get_user_data(self);
}

wl_display_get_version :: inline (self: *wl_display) -> u32 #c_call {
    return wl_proxy_get_version(self);
}

wl_display_sync :: inline (self: *wl_display) -> *wl_callback #c_call {
    ret: *wl_proxy = wl_proxy_marshal_constructor_versioned(
        self, WL_DISPLAY_SYNC,
        *wl_callback_interface, wl_proxy_get_version(self),
        null);
    return cast(*wl_callback) ret;
}

wl_display_get_registry :: inline (self: *wl_display) -> *wl_registry #c_call {
    ret: *wl_proxy = wl_proxy_marshal_constructor_versioned(
        self, WL_DISPLAY_GET_REGISTRY,
        *wl_registry_interface, wl_proxy_get_version(self),
        null);
    return cast(*wl_registry) ret;
}

wl_display_add_listener :: inline (self: *wl_display, listener: *wl_display_listener, data: *void) -> s32 #c_call {
    return wl_proxy_add_listener(self, cast(*generic_c_call) listener, data);
}

#scope_module

Core_Procs :: struct {
    wl_proxy_marshal                             : (p: *wl_proxy, opcode: u32, args: ..Any) -> void #c_call;
    wl_proxy_marshal_array                       : (p: *wl_proxy, opcode: u32, args: *wl_argument) -> void #c_call;
    wl_proxy_create                              : (factory: *wl_proxy, intf: *wl_interface) -> *wl_proxy #c_call;
    wl_proxy_create_wrapper                      : (proxy: *void) -> *void #c_call;
    wl_proxy_wrapper_destroy                     : (proxy_wrapper: *void) -> void #c_call;
    wl_proxy_marshal_constructor                 : (proxy: *wl_proxy, opcode: u32, intf: *wl_interface, args: ..Any) -> *wl_proxy #c_call;
    wl_proxy_marshal_constructor_versioned       : (proxy: *wl_proxy, opcode: u32, intf: *wl_interface, version: u32, args: ..Any) -> *wl_proxy #c_call;
    wl_proxy_marshal_array_constructor           : (proxy: *wl_proxy, opcode: u32, args: *wl_argument, intf: *wl_interface) -> *wl_proxy #c_call;
    wl_proxy_marshal_array_constructor_versioned : (proxy: *wl_proxy, opcode: u32, args: *wl_argument, intf: *wl_interface, version: u32) -> *wl_proxy #c_call;
    wl_proxy_destroy                             : (proxy: *wl_proxy) -> void #c_call;
    wl_proxy_add_listener                        : (proxy: *wl_proxy, impl: *generic_c_call, data: *void) -> s32 #c_call;
    wl_proxy_get_listener                        : (proxy: *wl_proxy) -> *void #c_call;
    wl_proxy_add_dispatcher                      : (proxy: *wl_proxy, func: wl_dispatcher_func_t, dispatcher_data: *void, data: *void) -> s32 #c_call;
    wl_proxy_set_user_data                       : (proxy: *wl_proxy, user_data: *void) -> void #c_call;
    wl_proxy_get_user_data                       : (proxy: *wl_proxy) -> *void #c_call;
    wl_proxy_get_version                         : (proxy: *wl_proxy) -> u32 #c_call;
    wl_proxy_get_id                              : (proxy: *wl_proxy) -> u32 #c_call;
    wl_proxy_get_class                           : (proxy: *wl_proxy) -> *u8 #c_call;
    wl_proxy_set_queue                           : (proxy: *wl_proxy, queue: *wl_event_queue) -> void #c_call;

    wl_display_connect                : (name: *u8) -> *wl_display #c_call;
    wl_display_connect_to_fd          : (fd: s32) -> *wl_display #c_call;
    wl_display_disconnect             : (display: *wl_display) -> void #c_call;
    wl_display_get_fd                 : (display: *wl_display) -> s32 #c_call;
    wl_display_dispatch               : (display: *wl_display) -> s32 #c_call;
    wl_display_dispatch_queue         : (display: *wl_display, queue: wl_event_queue) -> s32 #c_call;
    wl_display_dispatch_queue_pending : (display: *wl_display, queue: wl_event_queue) -> s32 #c_call;
    wl_display_dispatch_pending       : (display: *wl_display) -> s32 #c_call;
    wl_display_get_error              : (display: *wl_display) -> s32 #c_call;
    wl_display_get_protocol_error     : (display: *wl_display, intf: **wl_interface, id: *u32) -> u32 #c_call;
    wl_display_flush                  : (display: *wl_display) -> s32 #c_call;
    wl_display_roundtrip_queue        : (display: *wl_display, queue: *wl_event_queue) -> s32 #c_call;
    wl_display_roundtrip              : (display: *wl_display) -> s32 #c_call;
    wl_display_create_queue           : (display: *wl_display) -> *wl_event_queue #c_call;
    wl_display_prepare_read_queue     : (display: *wl_display, queue: *wl_event_queue) -> s32 #c_call;
    wl_display_prepare_read           : (display: *wl_display) -> s32 #c_call;
    wl_display_cancel_read            : (display: *wl_display) -> void #c_call;
    wl_display_read_events            : (display: *wl_display) -> s32 #c_call;

    wl_log_set_handler_client : (handler: wl_log_func_t) #c_call;
    wl_event_queue_destroy    : (queue: *wl_event_queue) #c_call;

    wl_list_init        : (list: *wl_list) #c_call;
    wl_list_insert      : (list: *wl_list, elm: *wl_list) #c_call;
    wl_list_remove      : (list: *wl_list) #c_call;
    wl_list_length      : (list: *wl_list) -> s32 #c_call;
    wl_list_empty       : (list: *wl_list) -> s32 #c_call;
    wl_list_insert_list : (list: *wl_list, other: *wl_list) #c_call;

    wl_array_init    : (array: *wl_array) #c_call;
    wl_array_release : (array: *wl_array) #c_call;
    wl_array_add     : (array: *wl_array, size: size_t) -> *void #c_call;
    wl_array_copy    : (array: *wl_array, source: *wl_array) -> s32 #c_call;
}
