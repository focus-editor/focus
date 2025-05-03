/*

Interact with macOS (e.g. NSEvent, NSTimer, etc.) with Objective-C wrappers.

Class Creation API
--------------------------------------------------------------
Used to register jai structs with the Objective-C runtime to be used as Objective-C objects.
```
objc_create_class        :: ($type: Type, $parent: Type) -> Class               - Creates a new Class with instance variables matching that of the struct members of the input type.
objc_add_instance_method :: (my_class: Class, proc: Any, selector_name: string) - Registers a jai function as an Objective-C instance method for the incomplete Class my_class.
objc_add_class_method    :: (my_class: Class, proc: Any, selector_name: string) - Registers a jai function as an Objective-C class method for the incomplete Class my_class.
objc_finalize_class      :: (my_class: Class)                                   - Registers an incomplete Class with the Objective-C runtime. The Class should be valid to be alloc after calling this.
```
Example:
~~~~~~~~~~~~~~~~~~~~~~~~~
MyWindowDelegate :: struct {
    super: NSObject;

    // .. variables

    windowWillClose :: (self: *WindowDelegate, _sel: Selector, notification: id) #c_call {
        // ...
    } @selector(windowWillClose:)
}

// Pass in the typename of the struct you wish to instantiate as an ObjC class to create_objc_class.
// The struct must have an "isa: Class" member or have its first member declaration be of a struct that does declare "isa".

clz := objc_create_class(MyWindowDelegate, NSObject);
objc_add_instance_method(clz, MyWindowDelegate.windowWillClose, "windowWillClose:");
// add additional methods, protocols, modifications, etc...
objc_finalize_class(clz);
~~~~~~~~~~~~~~~~~~~~~~~~~

Warning:
~~~~~~~~~~~~~~~~~~~~~~~~~
It is recommended that if an Objective-C class needs to be created with instance variables,
that such a class be implemented as an Objective-C library rather using these Objective-C
runtime routines. Creating Objective-C classes in jai via the Objective-C runtime causes
the class to suffer from fragile instance variables; that is to say, compiling the code
on one version of macOS may make the code incompatible with future versions of macOS. :ObjectiveCFragile:
See: http://www.sealiesoftware.com/blog/archive/2009/01/27/objc_explain_Non-fragile_ivars.html
 */

init_objective_c :: () {
    init_objective_c_foundation();

    if !_sel.alloc {
        init_objective_c_selector_struct(*_sel);
    }
}

init_objective_c_selector_struct :: (selectors: *$T) {
    data := cast(*u8) selectors;

    #insert -> string {
        struct_info := cast(*Type_Info_Struct) type_info(T);
        assert(struct_info.type == Type_Info_Tag.STRUCT);

        builder: String_Builder;
        for struct_info.members {
            selector_name := copy_temporary_string(it.name);

            for 0..it.name.count-1 {
                if selector_name[it] == #char "_" {
                    selector_name[it] = #char ":";
                }
            }
            print_to_builder(*builder, "    <<(cast(*Selector) (data + %)) = sel_registerName(\"%\");\n", it.offset_in_bytes, selector_name);
        }
        return builder_to_string(*builder);
    };
}

#if OS == .MACOS {
    BOOL :: s8;
} else { // iOS, tvOS, watchOS; not sure if there's any actual binary difference between these declarations even in C...
    BOOL :: bool;
}

YES: BOOL : 1;
NO:  BOOL : 0;

NSUInteger :: u64;
NSUIntegerMax :: 0xFFFFFFFFFFFFFFFF;
NSInteger :: s64;

Selector :: *void;

dispatch_queue_t :: *NSObject;
dispatch_data_t  :: *NSObject;

to_string :: (str: *NSString) -> string {
    init_objective_c();
    return to_string(NSString.UTF8String(str));
}

objc_alloc :: (class: Class) -> id #no_context {
    return objc_msgSend_typed(class, _sel.alloc);
}

objc_copy :: (self: *$instancetype) -> *instancetype #no_context {
    return xx objc_msgSend_typed(self, _sel.copy);
}

autorelease :: (self: *$instancetype) -> id #no_context {
    return objc_msgSend_typed(self, _sel.autorelease);
}

release :: (self: *$instancetype) -> id #no_context {
    return objc_msgSend_typed(self, _sel.release);
}

retain :: (self: *$instancetype) -> *instancetype #no_context {
    return xx objc_msgSend_typed(self, _sel.retain);
}

class :: (self: id) -> Class #no_context {
    // I'm pretty sure this is just id.isa
    // but this is the "correct" way to do this.
    return cast(Class) objc_msgSend_typed(self, _sel.class);
}

superclass :: (self: id) -> Class #no_context {
    return cast(Class) objc_msgSend_typed(self, _sel.superclass);
}

isEqual :: (self: id, object: id) -> bool #no_context {
    func :: #type (*void, Selector, id) -> BOOL #c_call;
    return (cast(func) objc_msgSend)(self, _sel.isEqual_, object) == YES;
}

// helper functions so we don't need to have messy
// user code

objc_init :: (self: *$type) -> *type #no_context {
    return cast(*type) objc_msgSend_typed(self, _sel.init);
}

objc_alloc :: ($type: Type) -> *type #no_context {
    struct_info := cast(*Type_Info_Struct) type;
    if struct_info.type != .STRUCT   return null;

    cls := objc_getClass(struct_info.name.data);
    if !cls     return null;

    return cast(*type) objc_alloc(cls);
}

objc_new :: ($type: Type) -> *type #no_context {
    return objc_init(objc_alloc(type));
}

class :: ($type: Type) -> Class #no_context {
    struct_info := cast(*Type_Info_Struct) type;
    if struct_info.type != .STRUCT   return null;
    return objc_getClass(struct_info.name.data);
}

objc_lookUpClass :: (name: string) -> Class {
    c_name := to_c_string(name);
    ret := objc_lookUpClass(c_name);
    free(c_name);
    return ret;
}

objc_getClass :: (name: string) -> Class {
    c_name := to_c_string(name);
    ret := objc_getClass(c_name);
    free(c_name);
    return ret;
}

objc_allocateClassPair :: (super: Class, name: string, extra_bytes: u64 = 0) -> Class {
    c_name := to_c_string(name);
    ret := objc_allocateClassPair(super, c_name, extra_bytes);
    free(c_name);
    return ret;
}

objc_getProtocol :: (name: string) -> *Protocol {
    c_name := to_c_string(name);
    ret := objc_getProtocol(c_name);
    free(c_name);
    return ret;

}

sel_registerName :: (name: string) -> Selector {
    c_name := to_c_string(name);
    ret := sel_registerName(c_name);
    free(c_name);
    return ret;
}


sel_getUid :: (name: string) -> Selector {
    c_name := to_c_string(name);
    ret := sel_getUid(c_name);
    free(c_name);
    return ret;
}


// short hand for sel_registerName
// @Speed: this is SLOW. Cache the Selector if you need it more than once.
selector :: (sel_str: string) -> Selector {
    // @Speed: This calls the sel_registerName wrapper which does to_c_string, which makes this even slower!
    return sel_registerName(sel_str);
}

// Use this to make sure that our struct declarations of Objective-C classes match the size of their current
// implementations on whatever macOS you run this.
// This is a lame workaround for the "fragile instance variables" problem. :ObjectiveCFragile:
create_objc_class_member_stub :: (class_name: string, framework_name: string) -> string {
    Basic :: #import "Basic";
    String :: #import "String";
    Posix :: #import "POSIX";

    init_objective_c();

    // The class is only known to Objective C after the library that contains it has been loaded!
    // If we’re cross-compiling then the libraries won’t be auto-loaded by the compiler, so we have to manually find & load them here, to be safe.
    // @Hack: We should probably look up the framework paths from somewhere and then we should be reading the framework’s Info.plist
    // to check what the framework's linking executable is.
    // But by convention all the standard frameworks just have FrameworkName.framework/FrameworkName
    // -rluba, 2024-01-25
    framework_path := tprint("/System/Library/Frameworks/%1.framework/%1\0", framework_name);
    handle := Posix.dlopen(framework_path.data, Posix.RTLD_LAZY | Posix.RTLD_LOCAL);
    defer {
        if handle Posix.dlclose(handle);
    }

    class := objc_getClass(class_name.data); // @Stability: This better be null-terminated
    Basic.assert(class != null, "Unknown Objective-C class \"%\"", class_name);
    instance_size := cast(s64) class_getInstanceSize(class);
    super := superclass(class);
    Basic.assert(super != null, "Couldn’t get Objective-C superclass of \"%\"", class_name);
    super_size := cast(s64) class_getInstanceSize(super);
    // log("%: % super: %", class_name, instance_size, super_size);
    return Basic.sprint("_%_data: [%] u8; // size of % minus size of parent class", String.to_lower_copy(class_name,, temp), instance_size - super_size, class_name);
}


// Using the class creation API: simply pass in the typename of the struct you wish to instantiate as an ObjC class to create_objc_class.
// The struct must have an "isa: Class" member or have its first member declaration be of a struct that does declare "isa".
// Example:
/*
MyWindowDelegate :: struct {
    super: NSObject;

    // .. variables

    windowWillClose :: (self: *WindowDelegate, _sel: Selector, notification: id) #c_call {

    } @selector(windowWillClose:)
}

clz := objc_create_class(MyWindowDelegate, NSObject);
objc_add_instance_method(clz, MyWindowDelegate.windowWillClose, "windowWillClose:");
// add additional methods, protocols, modifications, etc...
objc_finalize_class(clz);
*/
objc_create_class :: ($type: Type, $parent: Type) -> Class {
    tis := cast(*Type_Info_Struct) type_info(type);
    assert(tis.members.count > 0);
    parent_tis := cast(*Type_Info_Struct) type_info(parent);

    // print("%, %\n", tis.type, parent_tis.type);
    assert(tis.type == Type_Info_Tag.STRUCT && parent_tis.type == Type_Info_Tag.STRUCT);

    c_type_name := to_c_string(tis.name);
    c_parent_name := to_c_string(parent_tis.name);
    defer free(c_type_name);
    defer free(c_parent_name);

    parent_class := objc_getClass(c_parent_name);
    if !parent_class {
        log_error("Could not find parent Objective-C class \"%\"\n", parent_tis.name);
        return null;
    }

    parent_instance_size := cast(s64) class_getInstanceSize(parent_class);
    if parent_instance_size != parent_tis.runtime_size {
        log("Warning while creating \"%\": Objective-C instance size (%) of parent class \"%\" does not match the Jai struct’s size (%)!\n", tis.name, parent_instance_size, parent_tis.name, parent_tis.runtime_size);
        parent_ivar_count: u32;
        parent_ivars := class_copyIvarList(parent_class, *parent_ivar_count);
        defer c_free(parent_ivars);
        for 0..parent_ivar_count - 1 {
            ivar := parent_ivars[it];
            name := ivar_getName(ivar);
            offset := ivar_getOffset(ivar);
            type_encoding := ivar_getTypeEncoding(ivar);
            log("Parent instance variable: \"%\" of type \"%\" at offset %\n", to_string(name), to_string(type_encoding), offset);
        }
    }

    my_class := objc_allocateClassPair(parent_class, c_type_name, 0);
    if !my_class {
        log_error("Could not create Objective-C class \"%\"\n", tis.name);
        return null;
    }

    offset := 0;
    for 1..tis.members.count-1 {
        // skip the first decl, it should always be isa: Class, or the parent struct
        mem := tis.members[it];

        if mem.offset_in_bytes < offset continue;
        if mem.type.runtime_size == 0 continue;

        // @FixMe it seems the value that we look up in constant storage ends up being a pointer to some address in the compiler's address space at compile-time
        // rather than the .text runtime address of the function this member describes
        /*
        if (mem.flags & (mem.flags.CONSTANT)) && mem.type.type == Type_Info_Tag.PROCEDURE {
            selector_name: string;
            for mem.notes {
                if begins_with(it, "selector(") {
                    temp := it;
                    advance(*temp, 9);
                    selector_name = read_until_any_char(temp, ")");
                }
            }

            ptr := tis.constant_storage.data + mem.offset_into_constant_storage;
            print("STORAGE_SIZE: %\n", tis.constant_storage.count);
            print("ADDR: %\n", <<  cast(**void) (ptr));
            print("OFFSET: %\n", mem.offset_into_constant_storage);
            print("SELECTOR: '%'\n", selector_name);
            continue;
        }
        */

        if mem.flags & (mem.flags.CONSTANT | mem.flags.IMPORTED | mem.flags.USING) continue;


        offset += mem.type.runtime_size;
        // print("Member: %, size: %\n", mem.name, mem.type.runtime_size);
        c_name := to_c_string(mem.name);
        defer free(c_name);

        // @Hack because we currently cant get member alignment from type info
        alignment := 8;
        if mem.type.runtime_size < alignment then alignment = mem.type.runtime_size;

        type_encoding := objc_type_encode(mem.type);
        defer free(type_encoding);
        types_string := to_c_string(type_encoding);
        defer free(types_string);

        // print("type: %\n", type_encoding);
        alignment_shift: u8;
        if alignment == {
            case 1; alignment_shift = 1;
            case 2; alignment_shift = 2;
            case 4; alignment_shift = 3;
            case 8; alignment_shift = 4;
            case;   assert(false);
        }

        success := class_addIvar(my_class, c_name, cast(u64) mem.type.runtime_size, alignment_shift, types_string);
        if !success {
            log_error("Could not add instance variable \"%\" to Objective-C class \"%\"\n", mem.name, tis.name);
            return null;
        }
    }

    instance_size := cast(s64) class_getInstanceSize(my_class);
    if instance_size != tis.runtime_size {
        super_size := class_getInstanceSize(parent_class);
        print("Warning (%): instance size (%) does not match runtime_size (%)! Superclass instance size: %\n", tis.name, instance_size, tis.runtime_size, super_size);
    }
    return my_class;
}

objc_add_instance_method :: (my_class: Class, proc: Any, selector_name: string) {
    func_ty := cast(*Type_Info_Procedure) proc.type;
    assert(func_ty.type == Type_Info_Tag.PROCEDURE);
    type_check_objc_method_type(func_ty);

    type_encoding := objc_func_encode(func_ty);
    c_type_encoding := to_c_string(type_encoding);
    defer free(type_encoding);
    defer free(c_type_encoding);

    sel := sel_registerName(selector_name);
    success := class_addMethod(my_class, sel, xx << cast(**void) proc.value_pointer, c_type_encoding);
    assert(success != 0);
}

objc_add_class_method :: (my_class: Class, proc: Any, selector_name: string) {
    metaclass := object_getClass(xx my_class);
    objc_add_instance_method(metaclass, proc, selector_name);
}

objc_finalize_class :: (my_class: Class) {
    objc_registerClassPair(my_class);
}

// analogous to objc's @encode
// reference https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ObjCRuntimeGuide/Articles/ocrtTypeEncodings.html#//apple_ref/doc/uid/TP40008048-CH100
objc_type_encode :: (builder: *String_Builder, info: *Type_Info, pointer_depth := 0) {
    using Type_Info_Tag;

    if info == cast(*Type_Info) Class {
        append(builder, "#");
        return;
    }

    if info == cast(*Type_Info) id {
        append(builder, "@"); // @TODO the spec says this is used for object even if it statically typed or "id", but other parts of the spec say objects are encoded just like structs...
        return;
    }

    if info == cast(*Type_Info) Selector {
        append(builder, ":");
        return;
    }

    if info.type == {
        case VOID;
            append(builder, "v");
            return;
        case INTEGER;
            in := cast(*Type_Info_Integer) info;
            sign := in.signed;

            to_append := "";
            if in.runtime_size == {
                case 1;
                    if sign then to_append = "c";
                    else to_append = "C";
                case 2;
                    if sign then to_append = "s";
                    else to_append = "S";
                case 4;
                    // we could technically use "i" and "I" here, but I think long is more explicit
                    // since it's always 32-bit on both 32-bit and 64-bit objc systems
                    if sign then to_append = "l";
                    else to_append = "L";
                case 8;
                    if sign then to_append = "q";
                    else to_append = "Q";
            }

            if to_append == "" {
                print("INTEGER runtime_size: %\n", in.runtime_size);
            }
            assert(to_append != "");
            append(builder, to_append);
            return;
        case FLOAT;
            if info.runtime_size == 8 {
                append(builder, "d");
                return;
            } else {
                append(builder, "f");
                return;
            }
        case BOOL;
            append(builder, "B");
            return;
        case PROCEDURE;
            append(builder, "?");
            return; // doc mentions this as an unknown type, but it's also used for function pointers
        case POINTER;
            ptr := cast(*Type_Info_Pointer) info;
            element := ptr.pointer_to;

            if element.type == INTEGER {
                in := cast(*Type_Info_Integer) element;
                if in.runtime_size == 1 {
                    // @TODO are we supposed to emit this encoding if we have more levels of indirection ?
                    // i.e., what's the encoding for char** ?
                    append(builder, "*"); // char *
                    return;
                }
            }

            if element.type == STRUCT {
                // @TODO I'm not entirely sure where "@" fits in since the spec also mentions that objects are generated like structs too
                // we need a test file that explores the output from the objc @encode() directive
                // if has_isa_member(xx element) {
                //     append(builder, "@");
                //     return;
                // }
            }

            append(builder, "^");
            objc_type_encode(builder, element, pointer_depth+1);
            return;
        case STRUCT;
            str := cast(*Type_Info_Struct) info;
            if has_isa_member(str) {
                append(builder, "@");
                return;
            }

            append(builder, "{");
            append(builder, str.name); // @TODO what's the encoding if we have an unnamed struct ?
            // @Incomplete handle struct case
            if pointer_depth < 2 {
                append(builder, "=");
                offset := -1;
                for str.members {
                    if it.offset_in_bytes < offset continue;
                    if it.flags & (it.flags.CONSTANT | it.flags.IMPORTED | it.flags.USING) continue;

                    objc_type_encode(builder, it.type, pointer_depth);
                }
            }
            append(builder, "}");
            return;
        case ENUM;
            en := cast(*Type_Info_Enum) info;
            objc_type_encode(builder, en.internal_type, pointer_depth);
            return;
        case ARRAY;
            ar := cast(*Type_Info_Array) info;

            if ar.array_type == .FIXED {
                append(builder, "[");
                print_to_builder(builder, "%", ar.array_count);
                objc_type_encode(builder, ar.element_type);
                append(builder, "]");
            } else if ar.array_type == .VIEW {
                // maybe just generate the type info for Static_Array64 here?
                append(builder, "{_static=q^c}");
            } else if ar.array_type == .RESIZABLE {
                append(builder, "{_dynamic=qq^v?^v}");
            }
            return;
        case STRING ;
            st := cast(*Type_Info_String) info;
            append(builder, "{string=q^c}");
            return;
        case;
            print("Unhandled type: %\n", info.type);
    }

    assert(false);
}

objc_type_encode :: (info: *Type_Info) -> string {
    builder: String_Builder;

    objc_type_encode(*builder, info);
    out := builder_to_string(*builder);
    return out;
}

objc_func_encode :: (ty: *Type_Info_Procedure) -> string {
    assert(ty.return_types.count < 2);

    builder: String_Builder;

    if ty.return_types.count {
        objc_type_encode(*builder, ty.return_types[0]);
    } else {
        append(*builder, "v");
    }

    for ty.argument_types {
        objc_type_encode(*builder, it);
    }

    out := builder_to_string(*builder);
    return out;
}

has_isa_member :: (ty: *Type_Info_Struct) -> bool {
    for ty.members {
        if it.name == "isa" {
            assert(it.type == cast(*Type_Info) Class);
            return true;
        }
    }

    return false;
}

type_check_objc_method_type :: (ty: *Type_Info_Procedure) {
    assert((ty.procedure_flags & .IS_C_CALL) != 0);
    assert(ty.return_types.count < 2);
    assert(ty.argument_types.count >= 2);

    // ARG1_NEEDS_TO_BE_OBJECT :: "Argument 1 of Objective-C method must be an object or a pointer to an object!";
    // ARG1_NEEDS_TO_BE_OBJECT_WITH_ISA :: "Type of argument 1 Objective-C method must have a member called 'isa' of type 'Class' (apply 'using' to a parent type that is, or imports, 'NSObject').";
    valid_arg0 := ty.argument_types[0] == cast(*Type_Info) id;
    if !valid_arg0 {
       a := ty.argument_types[0];
       if a.type == Type_Info_Tag.POINTER {
            ptr := cast(*Type_Info_Pointer) a;
            element := ptr.pointer_to;
            assert(element.type == Type_Info_Tag.STRUCT);
            // assert(has_isa_member(xx element));
       } else if a.type == Type_Info_Tag.STRUCT {
            assert(has_isa_member(xx a));
       } else {
            assert(false);
       }
    }

    assert(ty.argument_types[1] == cast(*Type_Info) Selector);
}



// Some well-written info on how ObjC blocks are constructed can be found in
// Clang's documentation at https://clang.llvm.org/docs/Block-ABI-Apple.html

// This is an exerpt from the Gamepad module on how one might setup a block:
/*
game_controller_pause_handler_block_func :: (block: *Objective_C_Block_Basic, controller: *GCController) #c_call {
    ctx: #Context;
    push_context ctx {
        if controller == game_controller {
            _game_controller_paused_pressed = true;
        }
    }
}

_game_controller_block_desc: Objective_C_Block_Basic_Descriptor;
_game_controller_block: Objective_C_Block_Basic;


// setup block for handling GCController pause button
_game_controller_block.isa = xx _NSConcreteGlobalBlock;
_game_controller_block.invoke = xx game_controller_pause_handler_block_func;
_game_controller_block.descriptor = *_game_controller_block_desc;

_game_controller_block_desc.size = size_of(Objective_C_Block_Basic);

// ....
game_controller.setControllerPausedHandler(game_controller, *_game_controller_block);
*/
Objective_C_Block_Basic_Descriptor :: struct {
    reserved: u64;
    size: u64;

    copy_helper: (dst: *void, src: *void) #c_call;
    dispose_helper: (src: *void) #c_call;

    signature: *u8;
}

Objective_C_Block_Basic :: struct {
    isa: *void;
    flags: s32;
    reserved: s32;
    invoke: (*void, args: .. Any) -> () #c_call;
    descriptor: *Objective_C_Block_Basic_Descriptor; // Should be a pointer to a specific block descriptor struct, but we're using a generic one

    // Imported variables should be stored here, but we'd need some sort of macro-system or meta-programming to manage these in ways that dont suck, I think.
}

_NSConcreteStackBlock  :: () #foreign libSystem;
_NSConcreteGlobalBlock :: () #foreign libSystem;

#if CPU == .X64 {
    #load "bindings/x64/runtime.jai";
    #load "bindings/x64/message.jai";

} else {
    #load "bindings/arm64/runtime.jai";
    #load "bindings/arm64/message.jai";

    // Arm64 does not have separate *_stret variants because its ABI does not need them.
    objc_msgSend_stret                  :: objc_msgSend;
    objc_msgSendSuper_stret             :: objc_msgSendSuper;
    method_invoke_stret                 :: method_invoke;
    _objc_msgForward_stret              :: _objc_msgForward;
    class_getMethodImplementation_stret :: class_getMethodImplementation;
}

// The SDK we use for the x64 bindings still has typed objc_msgSend declarations.
// But in newer SDKs Apple dropped the type arguments from objc_msgSend and its cousins,
// so we re-define a basic version here to avoid painful casting everywhere.
// But we can’t add the old x64 varargs argument because that changes the ABI rules on ARM64 (and we can’t forward varargs to #c_call even on x64 for now anyways).
// :ObjectiveCMsgSendTypes:
//  -rluba, 2024-04-23
objc_msgSend_typed :: inline (target: *void, selector: Selector) -> *void #no_context {
    func :: #type (*void, Selector) -> *void #c_call;
    return (cast(func) objc_msgSend)(target, selector);
}


#load "Foundation.jai";

#scope_module

ptrdiff_t :: s64;


#import "macos";
#import "Basic";

libobjc :: #system_library "libobjc";
libSystem :: #system_library "libSystem";

#scope_file

_sel: struct #type_info_no_size_complaint {
    alloc:       Selector;
    objc_copy:   Selector;
    autorelease: Selector;
    release:     Selector;
    retain:      Selector;
    class:       Selector;
    superclass:  Selector;
    isEqual_:    Selector;
    init:        Selector;
    addItem_:    Selector;
}

libc :: #system_library "libc";
c_free :: (memory: *void) #foreign libc "free";
libobjc :: #library,system "libobjc";
