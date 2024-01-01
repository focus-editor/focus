//
// This file was auto-generated using the following command:
//
// jai generate.jai
//



xcb_cursor_context_t :: struct {}

XCB_Cursor_Symbols :: struct #type_info_procedures_are_void_pointers {
    context_new:  #type (conn: *xcb_connection_t, screen: *xcb_screen_t, ctx: **xcb_cursor_context_t) -> s32 #c_call;
    load_cursor:  #type (ctx: *xcb_cursor_context_t, name: *u8) -> xcb_cursor_t #c_call;
    context_free: #type (ctx: *xcb_cursor_context_t) -> void #c_call;
}

#scope_file

