//
// This file was auto-generated using the following command:
//
// jai modules/Objective_C/generate.jai - -arm64
//



marg_prearg_size :: 0;

/// Specifies the superclass of an instance.
objc_super :: struct {
    /// Specifies an instance of a class.
    receiver: id;

    /* For compatibility with old objc-runtime.h header */
    class:    Class;
}

objc_msgSend :: () -> void #foreign libobjc;

objc_msgSendSuper :: () -> void #foreign libobjc;

method_invoke :: () -> void #foreign libobjc;

_objc_msgForward :: () -> void #foreign libobjc;

/* Variable-argument Messaging Primitives
*
* Use these functions to call methods with a list of arguments, such
* as the one passed to forward:: .
*
* The contents of the argument list are architecture-specific.
* Consult your local function call ABI documentation for details.
*
* These functions must be cast to an appropriate function pointer type
* before being called, except for objc_msgSendv_stret() which must not
* be cast to a struct-returning type.
*/
marg_list :: *void;

#scope_file

libobjc :: #library,system "libobjc";
