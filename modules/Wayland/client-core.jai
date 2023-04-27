wl_event_queue :: struct {};

WL_MARSHAL_FLAG_DESTROY :: 1;

wl_event_queue_destroy :: (queue: *wl_event_queue) #foreign libwayland_client;

wl_proxy :: struct {
    marshal_flags :: wl_proxy_marshal_flags;
    marshal_array_flags :: wl_proxy_marshal_array_flags;
    marshal :: wl_proxy_marshal;
    marshal_array :: wl_proxy_marshal_array;
    create :: wl_proxy_create;
    create_wrapper :: wl_proxy_create_wrapper;
    wrapper_destroy :: wl_proxy_wrapper_destroy;
    marshal_constructor :: wl_proxy_marshal_constructor;
    marshal_constructor_versioned :: wl_proxy_marshal_constructor_versioned;
    marshal_array_constructor :: wl_proxy_marshal_array_constructor;
    marshal_array_constructor_versioned :: wl_proxy_marshal_array_constructor_versioned;
    destroy :: wl_proxy_destroy;
    add_listener :: wl_proxy_add_listener;
    get_listener :: wl_proxy_get_listener;
    add_dispatcher :: wl_proxy_add_dispatcher;
    set_user_data :: wl_proxy_set_user_data;
    get_user_data :: wl_proxy_get_user_data;
    get_version :: wl_proxy_get_version;
    get_id :: wl_proxy_get_id;
    set_tag :: wl_proxy_set_tag;
    get_tag :: wl_proxy_get_tag;
    get_class :: wl_proxy_get_class;
    set_queue :: wl_proxy_set_queue;
}

wl_log_set_handler_client :: (handler: wl_log_func_t) #foreign libwayland_client;

#scope_module

wl_proxy_marshal_flags :: (proxy: *wl_proxy, opcode: u32, intf: *wl_interface, version: u32, flags: u32, args: ..Any) -> *wl_proxy #foreign libwayland_client;
wl_proxy_marshal_array_flags :: (proxy: *wl_proxy, opcode: u32, intf: *wl_interface, version: u32, flags: u32, args: *wl_argument) -> *wl_proxy #foreign libwayland_client;
wl_proxy_marshal :: (p: *wl_proxy, opcode: u32, args: ..Any) -> void #foreign libwayland_client;
wl_proxy_marshal_array :: (p: *wl_proxy, opcode: u32, args: *wl_argument) -> void #foreign libwayland_client;
wl_proxy_create :: (factory: *wl_proxy, intf: *wl_interface) -> *wl_proxy #foreign libwayland_client;
wl_proxy_create_wrapper :: (proxy: *void) -> *void #foreign libwayland_client;
wl_proxy_wrapper_destroy :: (proxy_wrapper: *void) -> void #foreign libwayland_client;
wl_proxy_marshal_constructor :: (proxy: *wl_proxy, opcode: u32, intf: *wl_interface, args: ..Any) -> *wl_proxy #foreign libwayland_client;
wl_proxy_marshal_constructor_versioned :: (proxy: *wl_proxy, opcode: u32, intf: *wl_interface, version: u32, args: ..Any) -> *wl_proxy #foreign libwayland_client;
wl_proxy_marshal_array_constructor :: (proxy: *wl_proxy, opcode: u32, args: *wl_argument, intf: *wl_interface) -> *wl_proxy #foreign libwayland_client;
wl_proxy_marshal_array_constructor_versioned :: (proxy: *wl_proxy, opcode: u32, args: *wl_argument, intf: *wl_interface, version: u32) -> *wl_proxy #foreign libwayland_client;
wl_proxy_destroy :: (proxy: *wl_proxy) -> void #foreign libwayland_client;
wl_proxy_add_listener :: (proxy: *wl_proxy, impl: *generic_c_call, data: *void) -> s32 #foreign libwayland_client;
wl_proxy_get_listener :: (proxy: *wl_proxy) -> *void #foreign libwayland_client;
wl_proxy_add_dispatcher :: (proxy: *wl_proxy, func: wl_dispatcher_func_t, dispatcher_data: *void, data: *void) -> s32 #foreign libwayland_client;
wl_proxy_set_user_data :: (proxy: *wl_proxy, user_data: *void) -> void #foreign libwayland_client;
wl_proxy_get_user_data :: (proxy: *wl_proxy) -> *void #foreign libwayland_client;
wl_proxy_get_version :: (proxy: *wl_proxy) -> u32 #foreign libwayland_client;
wl_proxy_get_id :: (proxy: *wl_proxy) -> u32 #foreign libwayland_client;
wl_proxy_set_tag :: (proxy: *wl_proxy, tag: *u8) -> void #foreign libwayland_client;
wl_proxy_get_tag :: (proxy: *wl_proxy) -> *u8 #foreign libwayland_client;
wl_proxy_get_class :: (proxy: *wl_proxy) -> *u8 #foreign libwayland_client;
wl_proxy_set_queue :: (proxy: *wl_proxy, queue: *wl_event_queue) -> void #foreign libwayland_client;
