//
// This file was auto-generated using the following command:
//
// jai modules/Objective_C/generate.jai
//



marg_prearg_size :: 0;

objc_super :: struct {
    receiver: id;

    class:    Class;
}
#run {
    instance: objc_super;
    assert(((cast(*void)(*instance.receiver)) - cast(*void)(*instance)) == 0, "objc_super.receiver has unexpected offset % instead of 0", ((cast(*void)(*instance.receiver)) - cast(*void)(*instance)));
    assert(size_of(type_of(objc_super.receiver)) == 8, "objc_super.receiver has unexpected size % instead of 8", size_of(type_of(objc_super.receiver)));
    assert(((cast(*void)(*instance.class)) - cast(*void)(*instance)) == 8, "objc_super.class has unexpected offset % instead of 8", ((cast(*void)(*instance.class)) - cast(*void)(*instance)));
    assert(size_of(type_of(objc_super.class)) == 8, "objc_super.class has unexpected size % instead of 8", size_of(type_of(objc_super.class)));
    assert(size_of(objc_super) == 16, "objc_super has size % instead of 16", size_of(objc_super));
}

objc_msgSend :: (self: id, op: SEL, __args: ..Any) -> id #foreign libobjc;

objc_msgSendSuper :: (super: *objc_super, op: SEL, __args: ..Any) -> id #foreign libobjc;

objc_msgSend_stret :: (self: id, op: SEL, __args: ..Any) -> void #foreign libobjc;

objc_msgSendSuper_stret :: (super: *objc_super, op: SEL, __args: ..Any) -> void #foreign libobjc;

method_invoke :: (receiver: id, m: Method, __args: ..Any) -> id #foreign libobjc;

method_invoke_stret :: (receiver: id, m: Method, __args: ..Any) -> void #foreign libobjc;

_objc_msgForward :: (receiver: id, sel: SEL, __args: ..Any) -> id #foreign libobjc;

_objc_msgForward_stret :: (receiver: id, sel: SEL, __args: ..Any) -> void #foreign libobjc;

marg_list :: *void;

#scope_file

#import "Basic"; // For assert

libobjc :: #system_library "libobjc";
