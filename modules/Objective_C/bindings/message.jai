//
// This file was auto-generated using the following command:
//
// jai modules/Objective_C/generate.jai
//



marg_prearg_size :: 0;

/// Specifies the superclass of an instance.
objc_super :: struct {
    /// Specifies an instance of a class.
    receiver: id;

    /* For compatibility with old objc-runtime.h header */
    class:    Class;
}

/**
* Sends a message with a simple return value to an instance of a class.
*
* @param self A pointer to the instance of the class that is to receive the message.
* @param op The selector of the method that handles the message.
* @param ...
*   A variable argument list containing the arguments to the method.
*
* @return The return value of the method.
*
* @note When it encounters a method call, the compiler generates a call to one of the
*  functions \c objc_msgSend, \c objc_msgSend_stret, \c objc_msgSendSuper, or \c objc_msgSendSuper_stret.
*  Messages sent to an object’s superclass (using the \c super keyword) are sent using \c objc_msgSendSuper;
*  other messages are sent using \c objc_msgSend. Methods that have data structures as return values
*  are sent using \c objc_msgSendSuper_stret and \c objc_msgSend_stret.
*/
objc_msgSend :: (self: id, op: SEL, __args: ..Any) -> id #foreign libobjc;

/**
* Sends a message with a simple return value to the superclass of an instance of a class.
*
* @param super A pointer to an \c objc_super data structure. Pass values identifying the
*  context the message was sent to, including the instance of the class that is to receive the
*  message and the superclass at which to start searching for the method implementation.
* @param op A pointer of type SEL. Pass the selector of the method that will handle the message.
* @param ...
*   A variable argument list containing the arguments to the method.
*
* @return The return value of the method identified by \e op.
*
* @see objc_msgSend
*/
objc_msgSendSuper :: (super: *objc_super, op: SEL, __args: ..Any) -> id #foreign libobjc;

/**
* Sends a message with a data-structure return value to an instance of a class.
*
* @see objc_msgSend
*/
objc_msgSend_stret :: (self: id, op: SEL, __args: ..Any) -> void #foreign libobjc;

/**
* Sends a message with a data-structure return value to the superclass of an instance of a class.
*
* @see objc_msgSendSuper
*/
objc_msgSendSuper_stret :: (super: *objc_super, op: SEL, __args: ..Any) -> void #foreign libobjc;

method_invoke :: (receiver: id, m: Method, __args: ..Any) -> id #foreign libobjc;

method_invoke_stret :: (receiver: id, m: Method, __args: ..Any) -> void #foreign libobjc;

_objc_msgForward :: (receiver: id, sel: SEL, __args: ..Any) -> id #foreign libobjc;

_objc_msgForward_stret :: (receiver: id, sel: SEL, __args: ..Any) -> void #foreign libobjc;

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

libobjc :: #system_library "libobjc";
