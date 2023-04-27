wl_list :: struct {
    prev: *wl_list;
    next: *wl_list;
}

wl_list_each :: ($T: Type, head: *wl_list, $member: string = "link") -> wl_list_each_t(T, member) {
    return .{head};
}

/* This has the same functionality as the wl_list_for_each*() macros:
 *
 *    wl_list_for_each(...)         -> for wl_list_each(container_type, *head, "field_name") { ... }
 *    wl_list_for_each_reverse(...) -> for < wl_list_each(container_type, *head, "field_name") { ... }
 *
 * This always iterates in the "safe" way (ie. it is safe to free the current element).
 */
for_expansion :: (le: *wl_list_each_t($T, $o), body: Code, flags: For_Flags) #expand {
    current := ifx (flags & .REVERSE) le.head.prev else le.head.next;
    idx := 0;
    dummy: *le.parent_type;

    while current != le.head {
        next := ifx (flags & .REVERSE) current.prev else current.next;
        parent := container_of(current, dummy, le.offset);
        `it_index := idx;
        `it := parent;

        defer current = next;
        defer idx += 1;

        #insert body;
    }
}

#scope_file

wl_list_each_t :: struct (T: Type, name: string) {
    parent_type :: T;
    offset : s64 : #run offsetof(T, name, wl_list);
    head: *wl_list;
}

has_member :: (T: Type, offset: s64, MT: Type) -> bool #expand {
    if (cast(*Type_Info) T).type != .STRUCT return false;
    tis := cast(*Type_Info_Struct) T;
    for tis.members {
        if (it.offset_in_bytes == offset) && (it.type == cast(*Type_Info) MT) return true;
    }
    return false;
}

has_member :: (T: Type, name: string, MT: Type) -> bool #expand {
    if (cast(*Type_Info) T).type != .STRUCT return false;
    tis := cast(*Type_Info_Struct) T;
    for tis.members {
        if (it.name == name) && (it.type == cast(*Type_Info) MT) return true;
    }
    return false;
}

container_of :: (ptr: $P, sample: $S, offset: s64) -> S #expand {
    #assert (cast(*Type_Info) type_of(ptr)).type == .POINTER "`ptr` must be a pointer";
    #assert (cast(*Type_Info) type_of(sample)).type == .POINTER "`sample` must be a pointer";
    found :: #run has_member(type_of(<<sample), offset, type_of(<<ptr));
    #assert found "structure does not contain a member of the specified type at the specified offset";
    return cast(S) (cast(*u8)ptr - offset);
}

offsetof :: (T: Type, name: string, MT: Type) -> s64 #expand {
    #assert #run has_member(T, name, MT) "structure does not contain any member of the specified name and type";
    tis := cast(*Type_Info_Struct) T;
    for tis.members {
        if it.name == name return it.offset_in_bytes;
    }
}
