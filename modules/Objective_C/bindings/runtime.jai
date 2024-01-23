//
// This file was auto-generated using the following command:
//
// jai modules/Objective_C/generate.jai
//



OBJC_BOOL_IS_BOOL :: 0;

OBJC_BOOL_IS_CHAR :: 1;

ARITH_SHIFT :: 32;

CLS_CLASS :: 0x1;

CLS_META :: 0x2;

CLS_INITIALIZED :: 0x4;

CLS_POSING :: 0x8;

CLS_MAPPED :: 0x10;

CLS_FLUSH_CACHE :: 0x20;

CLS_GROW_CACHE :: 0x40;

CLS_NEED_BIND :: 0x80;

CLS_METHOD_ARRAY :: 0x100;

CLS_JAVA_HYBRID :: 0x200;
CLS_JAVA_CLASS :: 0x400;

CLS_INITIALIZING :: 0x800;

CLS_FROM_BUNDLE :: 0x1000;

CLS_HAS_CXX_STRUCTORS :: 0x2000;

CLS_NO_METHOD_ARRAY :: 0x4000;

CLS_HAS_LOAD_METHOD :: 0x8000;

CLS_CONSTRUCTING :: 0x10000;

CLS_EXT :: 0x20000;

OBSOLETE_OBJC_GETCLASSES :: 1;

OBJC_NEXT_METHOD_LIST :: 1;

/// An opaque type that represents an Objective-C class.
Class :: *objc_class;

/// Represents an instance of a class.
NSObject :: struct {
    isa: Class;
}

/// A pointer to an instance of a class.
id :: *NSObject;

objc_selector :: struct {}
/// An opaque type that represents a method selector.
SEL :: *objc_selector;

IMP :: #type (unknown0: id, unknown1: SEL, __args: ..Any) -> id #c_call;

/**
* Returns the name of the method specified by a given selector.
*
* @param sel A pointer of type \c SEL. Pass the selector whose name you wish to determine.
*
* @return A C string indicating the name of the selector.
*/
sel_getName :: (sel: SEL) -> *u8 #foreign libobjc;

/**
* Registers a method with the Objective-C runtime system, maps the method
* name to a selector, and returns the selector value.
*
* @param str A pointer to a C string. Pass the name of the method you wish to register.
*
* @return A pointer of type SEL specifying the selector for the named method.
*
* @note You must register a method name with the Objective-C runtime system to obtain the
*  method’s selector before you can add the method to a class definition. If the method name
*  has already been registered, this function simply returns the selector.
*/
sel_registerName :: (str: *u8) -> SEL #foreign libobjc;

/**
* Returns the class name of a given object.
*
* @param obj An Objective-C object.
*
* @return The name of the class of which \e obj is an instance.
*/
object_getClassName :: (obj: id) -> *u8 #foreign libobjc;

/**
* Returns a pointer to any extra bytes allocated with an instance given object.
*
* @param obj An Objective-C object.
*
* @return A pointer to any extra bytes allocated with \e obj. If \e obj was
*   not allocated with any extra bytes, then dereferencing the returned pointer is undefined.
*
* @note This function returns a pointer to any extra bytes allocated with the instance
*  (as specified by \c class_createInstance with extraBytes>0). This memory follows the
*  object's ordinary ivars, but may not be adjacent to the last ivar.
* @note The returned pointer is guaranteed to be pointer-size aligned, even if the area following
*  the object's last ivar is less aligned than that. Alignment greater than pointer-size is never
*  guaranteed, even if the area following the object's last ivar is more aligned than that.
* @note In a garbage-collected environment, the memory is scanned conservatively.
*/
object_getIndexedIvars :: (obj: id) -> *void #foreign libobjc;

/**
* Identifies a selector as being valid or invalid.
*
* @param sel The selector you want to identify.
*
* @return YES if selector is valid and has a function implementation, NO otherwise.
*
* @warning On some platforms, an invalid reference (to invalid memory addresses) can cause
*  a crash.
*/
sel_isMapped :: (sel: SEL) -> BOOL #foreign libobjc;

/**
* Registers a method name with the Objective-C runtime system.
*
* @param str A pointer to a C string. Pass the name of the method you wish to register.
*
* @return A pointer of type SEL specifying the selector for the named method.
*
* @note The implementation of this method is identical to the implementation of \c sel_registerName.
* @note Prior to OS X version 10.0, this method tried to find the selector mapped to the given name
*  and returned \c NULL if the selector was not found. This was changed for safety, because it was
*  observed that many of the callers of this function did not check the return value for \c NULL.
*/
sel_getUid :: (str: *u8) -> SEL #foreign libobjc;

objc_objectptr_t :: *void;

// Obsolete ARC conversions.
objc_retainedObject :: (obj: objc_objectptr_t) -> id #foreign libobjc;

objc_unretainedObject :: (obj: objc_objectptr_t) -> id #foreign libobjc;

objc_unretainedPointer :: (obj: id) -> objc_objectptr_t #foreign libobjc;

arith_t :: s64;
uarith_t :: u64;

STR :: *u8;

/// An opaque type that represents a method in a class definition.
Method :: *objc_method;

/// An opaque type that represents an instance variable.
Ivar :: *objc_ivar;

/// An opaque type that represents a category.
Category :: *objc_category;

objc_property :: struct {}
/// An opaque type that represents an Objective-C declared property.
objc_property_t :: *objc_property;

objc_class :: struct {
    #as using super: NSObject;
    super_class:   Class;
    name:          *u8;
    version:       s64;
    info:          s64;
    instance_size: s64;
    ivars:         *objc_ivar_list;
    methodLists:   **objc_method_list;
    cache:         *objc_cache;
    protocols:     *objc_protocol_list;
}

Protocol :: NSObject;

/// Defines a method
objc_method_description :: struct {
    name:  SEL; /**< The name of the method */
    types: *u8; /**< The types of the method arguments */
}

/// Defines a property attribute
objc_property_attribute_t :: struct {
    name:  *u8; /**< The name of the attribute */
    value: *u8; /**< The value of the attribute (usually empty) */
}

/**
* Returns a copy of a given object.
*
* @param obj An Objective-C object.
* @param size The size of the object \e obj.
*
* @return A copy of \e obj.
*/
object_copy :: (obj: id, size: u64) -> id #foreign libobjc;

/**
* Frees the memory occupied by a given object.
*
* @param obj An Objective-C object.
*
* @return nil
*/
object_dispose :: (obj: id) -> id #foreign libobjc;

/**
* Returns the class of an object.
*
* @param obj The object you want to inspect.
*
* @return The class object of which \e object is an instance,
*  or \c Nil if \e object is \c nil.
*/
object_getClass :: (obj: id) -> Class #foreign libobjc;

/**
* Sets the class of an object.
*
* @param obj The object to modify.
* @param cls A class object.
*
* @return The previous value of \e object's class, or \c Nil if \e object is \c nil.
*/
object_setClass :: (obj: id, cls: Class) -> Class #foreign libobjc;

/**
* Returns whether an object is a class object.
*
* @param obj An Objective-C object.
*
* @return true if the object is a class or metaclass, false otherwise.
*/
object_isClass :: (obj: id) -> BOOL #foreign libobjc;

/**
* Reads the value of an instance variable in an object.
*
* @param obj The object containing the instance variable whose value you want to read.
* @param ivar The Ivar describing the instance variable whose value you want to read.
*
* @return The value of the instance variable specified by \e ivar, or \c nil if \e object is \c nil.
*
* @note \c object_getIvar is faster than \c object_getInstanceVariable if the Ivar
*  for the instance variable is already known.
*/
object_getIvar :: (obj: id, ivar: Ivar) -> id #foreign libobjc;

/**
* Sets the value of an instance variable in an object.
*
* @param obj The object containing the instance variable whose value you want to set.
* @param ivar The Ivar describing the instance variable whose value you want to set.
* @param value The new value for the instance variable.
*
* @note Instance variables with known memory management (such as ARC strong and weak)
*  use that memory management. Instance variables with unknown memory management
*  are assigned as if they were unsafe_unretained.
* @note \c object_setIvar is faster than \c object_setInstanceVariable if the Ivar
*  for the instance variable is already known.
*/
object_setIvar :: (obj: id, ivar: Ivar, value: id) -> void #foreign libobjc;

/**
* Sets the value of an instance variable in an object.
*
* @param obj The object containing the instance variable whose value you want to set.
* @param ivar The Ivar describing the instance variable whose value you want to set.
* @param value The new value for the instance variable.
*
* @note Instance variables with known memory management (such as ARC strong and weak)
*  use that memory management. Instance variables with unknown memory management
*  are assigned as if they were strong.
* @note \c object_setIvar is faster than \c object_setInstanceVariable if the Ivar
*  for the instance variable is already known.
*/
object_setIvarWithStrongDefault :: (obj: id, ivar: Ivar, value: id) -> void #foreign libobjc;

/**
* Changes the value of an instance variable of a class instance.
*
* @param obj A pointer to an instance of a class. Pass the object containing
*  the instance variable whose value you wish to modify.
* @param name A C string. Pass the name of the instance variable whose value you wish to modify.
* @param value The new value for the instance variable.
*
* @return A pointer to the \c Ivar data structure that defines the type and
*  name of the instance variable specified by \e name.
*
* @note Instance variables with known memory management (such as ARC strong and weak)
*  use that memory management. Instance variables with unknown memory management
*  are assigned as if they were unsafe_unretained.
*/
object_setInstanceVariable :: (obj: id, name: *u8, value: *void) -> Ivar #foreign libobjc;

/**
* Changes the value of an instance variable of a class instance.
*
* @param obj A pointer to an instance of a class. Pass the object containing
*  the instance variable whose value you wish to modify.
* @param name A C string. Pass the name of the instance variable whose value you wish to modify.
* @param value The new value for the instance variable.
*
* @return A pointer to the \c Ivar data structure that defines the type and
*  name of the instance variable specified by \e name.
*
* @note Instance variables with known memory management (such as ARC strong and weak)
*  use that memory management. Instance variables with unknown memory management
*  are assigned as if they were strong.
*/
object_setInstanceVariableWithStrongDefault :: (obj: id, name: *u8, value: *void) -> Ivar #foreign libobjc;

/**
* Obtains the value of an instance variable of a class instance.
*
* @param obj A pointer to an instance of a class. Pass the object containing
*  the instance variable whose value you wish to obtain.
* @param name A C string. Pass the name of the instance variable whose value you wish to obtain.
* @param outValue On return, contains a pointer to the value of the instance variable.
*
* @return A pointer to the \c Ivar data structure that defines the type and name of
*  the instance variable specified by \e name.
*/
object_getInstanceVariable :: (obj: id, name: *u8, outValue: **void) -> Ivar #foreign libobjc;

/**
* Returns the class definition of a specified class.
*
* @param name The name of the class to look up.
*
* @return The Class object for the named class, or \c nil
*  if the class is not registered with the Objective-C runtime.
*
* @note \c objc_getClass is different from \c objc_lookUpClass in that if the class
*  is not registered, \c objc_getClass calls the class handler callback and then checks
*  a second time to see whether the class is registered. \c objc_lookUpClass does
*  not call the class handler callback.
*
* @warning Earlier implementations of this function (prior to OS X v10.0)
*  terminate the program if the class does not exist.
*/
objc_getClass :: (name: *u8) -> Class #foreign libobjc;

/**
* Returns the metaclass definition of a specified class.
*
* @param name The name of the class to look up.
*
* @return The \c Class object for the metaclass of the named class, or \c nil if the class
*  is not registered with the Objective-C runtime.
*
* @note If the definition for the named class is not registered, this function calls the class handler
*  callback and then checks a second time to see if the class is registered. However, every class
*  definition must have a valid metaclass definition, and so the metaclass definition is always returned,
*  whether it’s valid or not.
*/
objc_getMetaClass :: (name: *u8) -> Class #foreign libobjc;

/**
* Returns the class definition of a specified class.
*
* @param name The name of the class to look up.
*
* @return The Class object for the named class, or \c nil if the class
*  is not registered with the Objective-C runtime.
*
* @note \c objc_getClass is different from this function in that if the class is not
*  registered, \c objc_getClass calls the class handler callback and then checks a second
*  time to see whether the class is registered. This function does not call the class handler callback.
*/
objc_lookUpClass :: (name: *u8) -> Class #foreign libobjc;

/**
* Returns the class definition of a specified class.
*
* @param name The name of the class to look up.
*
* @return The Class object for the named class.
*
* @note This function is the same as \c objc_getClass, but kills the process if the class is not found.
* @note This function is used by ZeroLink, where failing to find a class would be a compile-time link error without ZeroLink.
*/
objc_getRequiredClass :: (name: *u8) -> Class #foreign libobjc;

/**
* Obtains the list of registered class definitions.
*
* @param buffer An array of \c Class values. On output, each \c Class value points to
*  one class definition, up to either \e bufferCount or the total number of registered classes,
*  whichever is less. You can pass \c NULL to obtain the total number of registered class
*  definitions without actually retrieving any class definitions.
* @param bufferCount An integer value. Pass the number of pointers for which you have allocated space
*  in \e buffer. On return, this function fills in only this number of elements. If this number is less
*  than the number of registered classes, this function returns an arbitrary subset of the registered classes.
*
* @return An integer value indicating the total number of registered classes.
*
* @note The Objective-C runtime library automatically registers all the classes defined in your source code.
*  You can create class definitions at runtime and register them with the \c objc_addClass function.
*
* @warning You cannot assume that class objects you get from this function are classes that inherit from \c NSObject,
*  so you cannot safely call any methods on such classes without detecting that the method is implemented first.
*/
objc_getClassList :: (buffer: *Class, bufferCount: s32) -> s32 #foreign libobjc;

/**
* Creates and returns a list of pointers to all registered class definitions.
*
* @param outCount An integer pointer used to store the number of classes returned by
*  this function in the list. It can be \c nil.
*
* @return A nil terminated array of classes. It must be freed with \c free().
*
* @see objc_getClassList
*/
objc_copyClassList :: (outCount: *u32) -> *Class #foreign libobjc;

/**
* Returns the name of a class.
*
* @param cls A class object.
*
* @return The name of the class, or the empty string if \e cls is \c Nil.
*/
class_getName :: (cls: Class) -> *u8 #foreign libobjc;

/**
* Returns a Boolean value that indicates whether a class object is a metaclass.
*
* @param cls A class object.
*
* @return \c YES if \e cls is a metaclass, \c NO if \e cls is a non-meta class,
*  \c NO if \e cls is \c Nil.
*/
class_isMetaClass :: (cls: Class) -> BOOL #foreign libobjc;

/**
* Returns the superclass of a class.
*
* @param cls A class object.
*
* @return The superclass of the class, or \c Nil if
*  \e cls is a root class, or \c Nil if \e cls is \c Nil.
*
* @note You should usually use \c NSObject's \c superclass method instead of this function.
*/
class_getSuperclass :: (cls: Class) -> Class #foreign libobjc;

/**
* Sets the superclass of a given class.
*
* @param cls The class whose superclass you want to set.
* @param newSuper The new superclass for cls.
*
* @return The old superclass for cls.
*
* @warning You should not use this function.
*/
class_setSuperclass :: (cls: Class, newSuper: Class) -> Class #foreign libobjc;

/**
* Returns the version number of a class definition.
*
* @param cls A pointer to a \c Class data structure. Pass
*  the class definition for which you wish to obtain the version.
*
* @return An integer indicating the version number of the class definition.
*
* @see class_setVersion
*/
class_getVersion :: (cls: Class) -> s32 #foreign libobjc;

/**
* Sets the version number of a class definition.
*
* @param cls A pointer to an Class data structure.
*  Pass the class definition for which you wish to set the version.
* @param version An integer. Pass the new version number of the class definition.
*
* @note You can use the version number of the class definition to provide versioning of the
*  interface that your class represents to other classes. This is especially useful for object
*  serialization (that is, archiving of the object in a flattened form), where it is important to
*  recognize changes to the layout of the instance variables in different class-definition versions.
* @note Classes derived from the Foundation framework \c NSObject class can set the class-definition
*  version number using the \c setVersion: class method, which is implemented using the \c class_setVersion function.
*/
class_setVersion :: (cls: Class, version: s32) -> void #foreign libobjc;

/**
* Returns the size of instances of a class.
*
* @param cls A class object.
*
* @return The size in bytes of instances of the class \e cls, or \c 0 if \e cls is \c Nil.
*/
class_getInstanceSize :: (cls: Class) -> u64 #foreign libobjc;

/**
* Returns the \c Ivar for a specified instance variable of a given class.
*
* @param cls The class whose instance variable you wish to obtain.
* @param name The name of the instance variable definition to obtain.
*
* @return A pointer to an \c Ivar data structure containing information about
*  the instance variable specified by \e name.
*/
class_getInstanceVariable :: (cls: Class, name: *u8) -> Ivar #foreign libobjc;

/**
* Returns the Ivar for a specified class variable of a given class.
*
* @param cls The class definition whose class variable you wish to obtain.
* @param name The name of the class variable definition to obtain.
*
* @return A pointer to an \c Ivar data structure containing information about the class variable specified by \e name.
*/
class_getClassVariable :: (cls: Class, name: *u8) -> Ivar #foreign libobjc;

/**
* Describes the instance variables declared by a class.
*
* @param cls The class to inspect.
* @param outCount On return, contains the length of the returned array.
*  If outCount is NULL, the length is not returned.
*
* @return An array of pointers of type Ivar describing the instance variables declared by the class.
*  Any instance variables declared by superclasses are not included. The array contains *outCount
*  pointers followed by a NULL terminator. You must free the array with free().
*
*  If the class declares no instance variables, or cls is Nil, NULL is returned and *outCount is 0.
*/
class_copyIvarList :: (cls: Class, outCount: *u32) -> *Ivar #foreign libobjc;

/**
* Returns a specified instance method for a given class.
*
* @param cls The class you want to inspect.
* @param name The selector of the method you want to retrieve.
*
* @return The method that corresponds to the implementation of the selector specified by
*  \e name for the class specified by \e cls, or \c NULL if the specified class or its
*  superclasses do not contain an instance method with the specified selector.
*
* @note This function searches superclasses for implementations, whereas \c class_copyMethodList does not.
*/
class_getInstanceMethod :: (cls: Class, name: SEL) -> Method #foreign libobjc;

/**
* Returns a pointer to the data structure describing a given class method for a given class.
*
* @param cls A pointer to a class definition. Pass the class that contains the method you want to retrieve.
* @param name A pointer of type \c SEL. Pass the selector of the method you want to retrieve.
*
* @return A pointer to the \c Method data structure that corresponds to the implementation of the
*  selector specified by aSelector for the class specified by aClass, or NULL if the specified
*  class or its superclasses do not contain an instance method with the specified selector.
*
* @note Note that this function searches superclasses for implementations,
*  whereas \c class_copyMethodList does not.
*/
class_getClassMethod :: (cls: Class, name: SEL) -> Method #foreign libobjc;

/**
* Returns the function pointer that would be called if a
* particular message were sent to an instance of a class.
*
* @param cls The class you want to inspect.
* @param name A selector.
*
* @return The function pointer that would be called if \c [object name] were called
*  with an instance of the class, or \c NULL if \e cls is \c Nil.
*
* @note \c class_getMethodImplementation may be faster than \c method_getImplementation(class_getInstanceMethod(cls, name)).
* @note The function pointer returned may be a function internal to the runtime instead of
*  an actual method implementation. For example, if instances of the class do not respond to
*  the selector, the function pointer returned will be part of the runtime's message forwarding machinery.
*/
class_getMethodImplementation :: (cls: Class, name: SEL) -> IMP #foreign libobjc;

/**
* Returns the function pointer that would be called if a particular
* message were sent to an instance of a class.
*
* @param cls The class you want to inspect.
* @param name A selector.
*
* @return The function pointer that would be called if \c [object name] were called
*  with an instance of the class, or \c NULL if \e cls is \c Nil.
*/
class_getMethodImplementation_stret :: (cls: Class, name: SEL) -> IMP #foreign libobjc;

/**
* Returns a Boolean value that indicates whether instances of a class respond to a particular selector.
*
* @param cls The class you want to inspect.
* @param sel A selector.
*
* @return \c YES if instances of the class respond to the selector, otherwise \c NO.
*
* @note You should usually use \c NSObject's \c respondsToSelector: or \c instancesRespondToSelector:
*  methods instead of this function.
*/
class_respondsToSelector :: (cls: Class, sel: SEL) -> BOOL #foreign libobjc;

/**
* Describes the instance methods implemented by a class.
*
* @param cls The class you want to inspect.
* @param outCount On return, contains the length of the returned array.
*  If outCount is NULL, the length is not returned.
*
* @return An array of pointers of type Method describing the instance methods
*  implemented by the class—any instance methods implemented by superclasses are not included.
*  The array contains *outCount pointers followed by a NULL terminator. You must free the array with free().
*
*  If cls implements no instance methods, or cls is Nil, returns NULL and *outCount is 0.
*
* @note To get the class methods of a class, use \c class_copyMethodList(object_getClass(cls), &count).
* @note To get the implementations of methods that may be implemented by superclasses,
*  use \c class_getInstanceMethod or \c class_getClassMethod.
*/
class_copyMethodList :: (cls: Class, outCount: *u32) -> *Method #foreign libobjc;

/**
* Returns a Boolean value that indicates whether a class conforms to a given protocol.
*
* @param cls The class you want to inspect.
* @param protocol A protocol.
*
* @return YES if cls conforms to protocol, otherwise NO.
*
* @note You should usually use NSObject's conformsToProtocol: method instead of this function.
*/
class_conformsToProtocol :: (cls: Class, protocol: *Protocol) -> BOOL #foreign libobjc;

/**
* Describes the protocols adopted by a class.
*
* @param cls The class you want to inspect.
* @param outCount On return, contains the length of the returned array.
*  If outCount is NULL, the length is not returned.
*
* @return An array of pointers of type Protocol* describing the protocols adopted
*  by the class. Any protocols adopted by superclasses or other protocols are not included.
*  The array contains *outCount pointers followed by a NULL terminator. You must free the array with free().
*
*  If cls adopts no protocols, or cls is Nil, returns NULL and *outCount is 0.
*/
class_copyProtocolList :: (cls: Class, outCount: *u32) -> **Protocol #foreign libobjc;

/**
* Returns a property with a given name of a given class.
*
* @param cls The class you want to inspect.
* @param name The name of the property you want to inspect.
*
* @return A pointer of type \c objc_property_t describing the property, or
*  \c NULL if the class does not declare a property with that name,
*  or \c NULL if \e cls is \c Nil.
*/
class_getProperty :: (cls: Class, name: *u8) -> objc_property_t #foreign libobjc;

/**
* Describes the properties declared by a class.
*
* @param cls The class you want to inspect.
* @param outCount On return, contains the length of the returned array.
*  If \e outCount is \c NULL, the length is not returned.
*
* @return An array of pointers of type \c objc_property_t describing the properties
*  declared by the class. Any properties declared by superclasses are not included.
*  The array contains \c *outCount pointers followed by a \c NULL terminator. You must free the array with \c free().
*
*  If \e cls declares no properties, or \e cls is \c Nil, returns \c NULL and \c *outCount is \c 0.
*/
class_copyPropertyList :: (cls: Class, outCount: *u32) -> *objc_property_t #foreign libobjc;

/**
* Returns a description of the \c Ivar layout for a given class.
*
* @param cls The class to inspect.
*
* @return A description of the \c Ivar layout for \e cls.
*/
class_getIvarLayout :: (cls: Class) -> *u8 #foreign libobjc;

/**
* Returns a description of the layout of weak Ivars for a given class.
*
* @param cls The class to inspect.
*
* @return A description of the layout of the weak \c Ivars for \e cls.
*/
class_getWeakIvarLayout :: (cls: Class) -> *u8 #foreign libobjc;

/**
* Adds a new method to a class with a given name and implementation.
*
* @param cls The class to which to add a method.
* @param name A selector that specifies the name of the method being added.
* @param imp A function which is the implementation of the new method. The function must take at least two arguments—self and _cmd.
* @param types An array of characters that describe the types of the arguments to the method.
*
* @return YES if the method was added successfully, otherwise NO
*  (for example, the class already contains a method implementation with that name).
*
* @note class_addMethod will add an override of a superclass's implementation,
*  but will not replace an existing implementation in this class.
*  To change an existing implementation, use method_setImplementation.
*/
class_addMethod :: (cls: Class, name: SEL, imp: IMP, types: *u8) -> BOOL #foreign libobjc;

/**
* Replaces the implementation of a method for a given class.
*
* @param cls The class you want to modify.
* @param name A selector that identifies the method whose implementation you want to replace.
* @param imp The new implementation for the method identified by name for the class identified by cls.
* @param types An array of characters that describe the types of the arguments to the method.
*  Since the function must take at least two arguments—self and _cmd, the second and third characters
*  must be “@:” (the first character is the return type).
*
* @return The previous implementation of the method identified by \e name for the class identified by \e cls.
*
* @note This function behaves in two different ways:
*  - If the method identified by \e name does not yet exist, it is added as if \c class_addMethod were called.
*    The type encoding specified by \e types is used as given.
*  - If the method identified by \e name does exist, its \c IMP is replaced as if \c method_setImplementation were called.
*    The type encoding specified by \e types is ignored.
*/
class_replaceMethod :: (cls: Class, name: SEL, imp: IMP, types: *u8) -> IMP #foreign libobjc;

/**
* Adds a new instance variable to a class.
*
* @return YES if the instance variable was added successfully, otherwise NO
*         (for example, the class already contains an instance variable with that name).
*
* @note This function may only be called after objc_allocateClassPair and before objc_registerClassPair.
*       Adding an instance variable to an existing class is not supported.
* @note The class must not be a metaclass. Adding an instance variable to a metaclass is not supported.
* @note The instance variable's minimum alignment in bytes is 1<<align. The minimum alignment of an instance
*       variable depends on the ivar's type and the machine architecture.
*       For variables of any pointer type, pass log2(sizeof(pointer_type)).
*/
class_addIvar :: (cls: Class, name: *u8, size: u64, alignment: u8, types: *u8) -> BOOL #foreign libobjc;

/**
* Adds a protocol to a class.
*
* @param cls The class to modify.
* @param protocol The protocol to add to \e cls.
*
* @return \c YES if the method was added successfully, otherwise \c NO
*  (for example, the class already conforms to that protocol).
*/
class_addProtocol :: (cls: Class, protocol: *Protocol) -> BOOL #foreign libobjc;

/**
* Adds a property to a class.
*
* @param cls The class to modify.
* @param name The name of the property.
* @param attributes An array of property attributes.
* @param attributeCount The number of attributes in \e attributes.
*
* @return \c YES if the property was added successfully, otherwise \c NO
*  (for example, the class already has that property).
*/
class_addProperty :: (cls: Class, name: *u8, attributes: *objc_property_attribute_t, attributeCount: u32) -> BOOL #foreign libobjc;

/**
* Replace a property of a class.
*
* @param cls The class to modify.
* @param name The name of the property.
* @param attributes An array of property attributes.
* @param attributeCount The number of attributes in \e attributes.
*/
class_replaceProperty :: (cls: Class, name: *u8, attributes: *objc_property_attribute_t, attributeCount: u32) -> void #foreign libobjc;

/**
* Sets the Ivar layout for a given class.
*
* @param cls The class to modify.
* @param layout The layout of the \c Ivars for \e cls.
*/
class_setIvarLayout :: (cls: Class, layout: *u8) -> void #foreign libobjc;

/**
* Sets the layout for weak Ivars for a given class.
*
* @param cls The class to modify.
* @param layout The layout of the weak Ivars for \e cls.
*/
class_setWeakIvarLayout :: (cls: Class, layout: *u8) -> void #foreign libobjc;

/**
* Used by CoreFoundation's toll-free bridging.
* Return the id of the named class.
*
* @return The id of the named class, or an uninitialized class
*  structure that will be used for the class when and if it does
*  get loaded.
*
* @warning Do not call this function yourself.
*/
objc_getFutureClass :: (name: *u8) -> Class #foreign libobjc;

/**
* Creates an instance of a class, allocating memory for the class in the
* default malloc memory zone.
*
* @param cls The class that you wish to allocate an instance of.
* @param extraBytes An integer indicating the number of extra bytes to allocate.
*  The additional bytes can be used to store additional instance variables beyond
*  those defined in the class definition.
*
* @return An instance of the class \e cls.
*/
class_createInstance :: (cls: Class, extraBytes: u64) -> id #foreign libobjc;

/**
* Creates an instance of a class at the specific location provided.
*
* @param cls The class that you wish to allocate an instance of.
* @param bytes The location at which to allocate an instance of \e cls.
*  Must point to at least \c class_getInstanceSize(cls) bytes of well-aligned,
*  zero-filled memory.
*
* @return \e bytes on success, \c nil otherwise. (For example, \e cls or \e bytes
*  might be \c nil)
*
* @see class_createInstance
*/
objc_constructInstance :: (cls: Class, bytes: *void) -> id #foreign libobjc;

/**
* Destroys an instance of a class without freeing memory and removes any
* associated references this instance might have had.
*
* @param obj The class instance to destroy.
*
* @return \e obj. Does nothing if \e obj is nil.
*
* @note CF and other clients do call this under GC.
*/
objc_destructInstance :: (obj: id) -> *void #foreign libobjc;

/**
* Creates a new class and metaclass.
*
* @param superclass The class to use as the new class's superclass, or \c Nil to create a new root class.
* @param name The string to use as the new class's name. The string will be copied.
* @param extraBytes The number of bytes to allocate for indexed ivars at the end of
*  the class and metaclass objects. This should usually be \c 0.
*
* @return The new class, or Nil if the class could not be created (for example, the desired name is already in use).
*
* @note You can get a pointer to the new metaclass by calling \c object_getClass(newClass).
* @note To create a new class, start by calling \c objc_allocateClassPair.
*  Then set the class's attributes with functions like \c class_addMethod and \c class_addIvar.
*  When you are done building the class, call \c objc_registerClassPair. The new class is now ready for use.
* @note Instance methods and instance variables should be added to the class itself.
*  Class methods should be added to the metaclass.
*/
objc_allocateClassPair :: (superclass: Class, name: *u8, extraBytes: u64) -> Class #foreign libobjc;

/**
* Registers a class that was allocated using \c objc_allocateClassPair.
*
* @param cls The class you want to register.
*/
objc_registerClassPair :: (cls: Class) -> void #foreign libobjc;

/**
* Used by Foundation's Key-Value Observing.
*
* @warning Do not call this function yourself.
*/
objc_duplicateClass :: (original: Class, name: *u8, extraBytes: u64) -> Class #foreign libobjc;

/**
* Destroy a class and its associated metaclass.
*
* @param cls The class to be destroyed. It must have been allocated with
*  \c objc_allocateClassPair
*
* @warning Do not call if instances of this class or a subclass exist.
*/
objc_disposeClassPair :: (cls: Class) -> void #foreign libobjc;

/**
* Returns the name of a method.
*
* @param m The method to inspect.
*
* @return A pointer of type SEL.
*
* @note To get the method name as a C string, call \c sel_getName(method_getName(method)).
*/
method_getName :: (m: Method) -> SEL #foreign libobjc;

/**
* Returns the implementation of a method.
*
* @param m The method to inspect.
*
* @return A function pointer of type IMP.
*/
method_getImplementation :: (m: Method) -> IMP #foreign libobjc;

/**
* Returns a string describing a method's parameter and return types.
*
* @param m The method to inspect.
*
* @return A C string. The string may be \c NULL.
*/
method_getTypeEncoding :: (m: Method) -> *u8 #foreign libobjc;

/**
* Returns the number of arguments accepted by a method.
*
* @param m A pointer to a \c Method data structure. Pass the method in question.
*
* @return An integer containing the number of arguments accepted by the given method.
*/
method_getNumberOfArguments :: (m: Method) -> u32 #foreign libobjc;

/**
* Returns a string describing a method's return type.
*
* @param m The method to inspect.
*
* @return A C string describing the return type. You must free the string with \c free().
*/
method_copyReturnType :: (m: Method) -> *u8 #foreign libobjc;

/**
* Returns a string describing a single parameter type of a method.
*
* @param m The method to inspect.
* @param index The index of the parameter to inspect.
*
* @return A C string describing the type of the parameter at index \e index, or \c NULL
*  if method has no parameter index \e index. You must free the string with \c free().
*/
method_copyArgumentType :: (m: Method, index: u32) -> *u8 #foreign libobjc;

/**
* Returns by reference a string describing a method's return type.
*
* @param m The method you want to inquire about.
* @param dst The reference string to store the description.
* @param dst_len The maximum number of characters that can be stored in \e dst.
*
* @note The method's return type string is copied to \e dst.
*  \e dst is filled as if \c strncpy(dst, parameter_type, dst_len) were called.
*/
method_getReturnType :: (m: Method, dst: *u8, dst_len: u64) -> void #foreign libobjc;

/**
* Returns by reference a string describing a single parameter type of a method.
*
* @param m The method you want to inquire about.
* @param index The index of the parameter you want to inquire about.
* @param dst The reference string to store the description.
* @param dst_len The maximum number of characters that can be stored in \e dst.
*
* @note The parameter type string is copied to \e dst. \e dst is filled as if \c strncpy(dst, parameter_type, dst_len)
*  were called. If the method contains no parameter with that index, \e dst is filled as
*  if \c strncpy(dst, "", dst_len) were called.
*/
method_getArgumentType :: (m: Method, index: u32, dst: *u8, dst_len: u64) -> void #foreign libobjc;

method_getDescription :: (m: Method) -> *objc_method_description #foreign libobjc;

/**
* Sets the implementation of a method.
*
* @param m The method for which to set an implementation.
* @param imp The implemention to set to this method.
*
* @return The previous implementation of the method.
*/
method_setImplementation :: (m: Method, imp: IMP) -> IMP #foreign libobjc;

/**
* Exchanges the implementations of two methods.
*
* @param m1 Method to exchange with second method.
* @param m2 Method to exchange with first method.
*
* @note This is an atomic version of the following:
*  \code
*  IMP imp1 = method_getImplementation(m1);
*  IMP imp2 = method_getImplementation(m2);
*  method_setImplementation(m1, imp2);
*  method_setImplementation(m2, imp1);
*  \endcode
*/
method_exchangeImplementations :: (m1: Method, m2: Method) -> void #foreign libobjc;

/**
* Returns the name of an instance variable.
*
* @param v The instance variable you want to enquire about.
*
* @return A C string containing the instance variable's name.
*/
ivar_getName :: (v: Ivar) -> *u8 #foreign libobjc;

/**
* Returns the type string of an instance variable.
*
* @param v The instance variable you want to enquire about.
*
* @return A C string containing the instance variable's type encoding.
*
* @note For possible values, see Objective-C Runtime Programming Guide > Type Encodings.
*/
ivar_getTypeEncoding :: (v: Ivar) -> *u8 #foreign libobjc;

/**
* Returns the offset of an instance variable.
*
* @param v The instance variable you want to enquire about.
*
* @return The offset of \e v.
*
* @note For instance variables of type \c id or other object types, call \c object_getIvar
*  and \c object_setIvar instead of using this offset to access the instance variable data directly.
*/
ivar_getOffset :: (v: Ivar) -> ptrdiff_t #foreign libobjc;

/**
* Returns the name of a property.
*
* @param property The property you want to inquire about.
*
* @return A C string containing the property's name.
*/
property_getName :: (property: objc_property_t) -> *u8 #foreign libobjc;

/**
* Returns the attribute string of a property.
*
* @param property A property.
*
* @return A C string containing the property's attributes.
*
* @note The format of the attribute string is described in Declared Properties in Objective-C Runtime Programming Guide.
*/
property_getAttributes :: (property: objc_property_t) -> *u8 #foreign libobjc;

/**
* Returns an array of property attributes for a property.
*
* @param property The property whose attributes you want copied.
* @param outCount The number of attributes returned in the array.
*
* @return An array of property attributes; must be free'd() by the caller.
*/
property_copyAttributeList :: (property: objc_property_t, outCount: *u32) -> *objc_property_attribute_t #foreign libobjc;

/**
* Returns the value of a property attribute given the attribute name.
*
* @param property The property whose attribute value you are interested in.
* @param attributeName C string representing the attribute name.
*
* @return The value string of the attribute \e attributeName if it exists in
*  \e property, \c nil otherwise.
*/
property_copyAttributeValue :: (property: objc_property_t, attributeName: *u8) -> *u8 #foreign libobjc;

/**
* Returns a specified protocol.
*
* @param name The name of a protocol.
*
* @return The protocol named \e name, or \c NULL if no protocol named \e name could be found.
*
* @note This function acquires the runtime lock.
*/
objc_getProtocol :: (name: *u8) -> *Protocol #foreign libobjc;

/**
* Returns an array of all the protocols known to the runtime.
*
* @param outCount Upon return, contains the number of protocols in the returned array.
*
* @return A C array of all the protocols known to the runtime. The array contains \c *outCount
*  pointers followed by a \c NULL terminator. You must free the list with \c free().
*
* @note This function acquires the runtime lock.
*/
objc_copyProtocolList :: (outCount: *u32) -> **Protocol #foreign libobjc;

/**
* Returns a Boolean value that indicates whether one protocol conforms to another protocol.
*
* @param proto A protocol.
* @param other A protocol.
*
* @return \c YES if \e proto conforms to \e other, otherwise \c NO.
*
* @note One protocol can incorporate other protocols using the same syntax
*  that classes use to adopt a protocol:
*  \code
*  @protocol ProtocolName < protocol list >
*  \endcode
*  All the protocols listed between angle brackets are considered part of the ProtocolName protocol.
*/
protocol_conformsToProtocol :: (proto: *Protocol, other: *Protocol) -> BOOL #foreign libobjc;

/**
* Returns a Boolean value that indicates whether two protocols are equal.
*
* @param proto A protocol.
* @param other A protocol.
*
* @return \c YES if \e proto is the same as \e other, otherwise \c NO.
*/
protocol_isEqual :: (proto: *Protocol, other: *Protocol) -> BOOL #foreign libobjc;

/**
* Returns the name of a protocol.
*
* @param p A protocol.
*
* @return The name of the protocol \e p as a C string.
*/
protocol_getName :: (proto: *Protocol) -> *u8 #foreign libobjc;

/**
* Returns a method description structure for a specified method of a given protocol.
*
* @param p A protocol.
* @param aSel A selector.
* @param isRequiredMethod A Boolean value that indicates whether aSel is a required method.
* @param isInstanceMethod A Boolean value that indicates whether aSel is an instance method.
*
* @return An \c objc_method_description structure that describes the method specified by \e aSel,
*  \e isRequiredMethod, and \e isInstanceMethod for the protocol \e p.
*  If the protocol does not contain the specified method, returns an \c objc_method_description structure
*  with the value \c {NULL, \c NULL}.
*
* @note This function recursively searches any protocols that this protocol conforms to.
*/
protocol_getMethodDescription :: (proto: *Protocol, aSel: SEL, isRequiredMethod: BOOL, isInstanceMethod: BOOL) -> objc_method_description #foreign libobjc;

/**
* Returns an array of method descriptions of methods meeting a given specification for a given protocol.
*
* @param p A protocol.
* @param isRequiredMethod A Boolean value that indicates whether returned methods should
*  be required methods (pass YES to specify required methods).
* @param isInstanceMethod A Boolean value that indicates whether returned methods should
*  be instance methods (pass YES to specify instance methods).
* @param outCount Upon return, contains the number of method description structures in the returned array.
*
* @return A C array of \c objc_method_description structures containing the names and types of \e p's methods
*  specified by \e isRequiredMethod and \e isInstanceMethod. The array contains \c *outCount pointers followed
*  by a \c NULL terminator. You must free the list with \c free().
*  If the protocol declares no methods that meet the specification, \c NULL is returned and \c *outCount is 0.
*
* @note Methods in other protocols adopted by this protocol are not included.
*/
protocol_copyMethodDescriptionList :: (proto: *Protocol, isRequiredMethod: BOOL, isInstanceMethod: BOOL, outCount: *u32) -> *objc_method_description #foreign libobjc;

/**
* Returns the specified property of a given protocol.
*
* @param proto A protocol.
* @param name The name of a property.
* @param isRequiredProperty \c YES searches for a required property, \c NO searches for an optional property.
* @param isInstanceProperty \c YES searches for an instance property, \c NO searches for a class property.
*
* @return The property specified by \e name, \e isRequiredProperty, and \e isInstanceProperty for \e proto,
*  or \c NULL if none of \e proto's properties meets the specification.
*/
protocol_getProperty :: (proto: *Protocol, name: *u8, isRequiredProperty: BOOL, isInstanceProperty: BOOL) -> objc_property_t #foreign libobjc;

/**
* Returns an array of the required instance properties declared by a protocol.
*
* @note Identical to
* \code
* protocol_copyPropertyList2(proto, outCount, YES, YES);
* \endcode
*/
protocol_copyPropertyList :: (proto: *Protocol, outCount: *u32) -> *objc_property_t #foreign libobjc;

/**
* Returns an array of properties declared by a protocol.
*
* @param proto A protocol.
* @param outCount Upon return, contains the number of elements in the returned array.
* @param isRequiredProperty \c YES returns required properties, \c NO returns optional properties.
* @param isInstanceProperty \c YES returns instance properties, \c NO returns class properties.
*
* @return A C array of pointers of type \c objc_property_t describing the properties declared by \e proto.
*  Any properties declared by other protocols adopted by this protocol are not included. The array contains
*  \c *outCount pointers followed by a \c NULL terminator. You must free the array with \c free().
*  If the protocol declares no matching properties, \c NULL is returned and \c *outCount is \c 0.
*/
protocol_copyPropertyList2 :: (proto: *Protocol, outCount: *u32, isRequiredProperty: BOOL, isInstanceProperty: BOOL) -> *objc_property_t #foreign libobjc;

/**
* Returns an array of the protocols adopted by a protocol.
*
* @param proto A protocol.
* @param outCount Upon return, contains the number of elements in the returned array.
*
* @return A C array of protocols adopted by \e proto. The array contains \e *outCount pointers
*  followed by a \c NULL terminator. You must free the array with \c free().
*  If the protocol declares no properties, \c NULL is returned and \c *outCount is \c 0.
*/
protocol_copyProtocolList :: (proto: *Protocol, outCount: *u32) -> **Protocol #foreign libobjc;

/**
* Creates a new protocol instance that cannot be used until registered with
* \c objc_registerProtocol()
*
* @param name The name of the protocol to create.
*
* @return The Protocol instance on success, \c nil if a protocol
*  with the same name already exists.
* @note There is no dispose method for this.
*/
objc_allocateProtocol :: (name: *u8) -> *Protocol #foreign libobjc;

/**
* Registers a newly constructed protocol with the runtime. The protocol
* will be ready for use and is immutable after this.
*
* @param proto The protocol you want to register.
*/
objc_registerProtocol :: (proto: *Protocol) -> void #foreign libobjc;

/**
* Adds a method to a protocol. The protocol must be under construction.
*
* @param proto The protocol to add a method to.
* @param name The name of the method to add.
* @param types A C string that represents the method signature.
* @param isRequiredMethod YES if the method is not an optional method.
* @param isInstanceMethod YES if the method is an instance method.
*/
protocol_addMethodDescription :: (proto: *Protocol, name: SEL, types: *u8, isRequiredMethod: BOOL, isInstanceMethod: BOOL) -> void #foreign libobjc;

/**
* Adds an incorporated protocol to another protocol. The protocol being
* added to must still be under construction, while the additional protocol
* must be already constructed.
*
* @param proto The protocol you want to add to, it must be under construction.
* @param addition The protocol you want to incorporate into \e proto, it must be registered.
*/
protocol_addProtocol :: (proto: *Protocol, addition: *Protocol) -> void #foreign libobjc;

/**
* Adds a property to a protocol. The protocol must be under construction.
*
* @param proto The protocol to add a property to.
* @param name The name of the property.
* @param attributes An array of property attributes.
* @param attributeCount The number of attributes in \e attributes.
* @param isRequiredProperty YES if the property (accessor methods) is not optional.
* @param isInstanceProperty YES if the property (accessor methods) are instance methods.
*  This is the only case allowed fo a property, as a result, setting this to NO will
*  not add the property to the protocol at all.
*/
protocol_addProperty :: (proto: *Protocol, name: *u8, attributes: *objc_property_attribute_t, attributeCount: u32, isRequiredProperty: BOOL, isInstanceProperty: BOOL) -> void #foreign libobjc;

/**
* Returns the names of all the loaded Objective-C frameworks and dynamic
* libraries.
*
* @param outCount The number of names returned.
*
* @return An array of C strings of names. Must be free()'d by caller.
*/
objc_copyImageNames :: (outCount: *u32) -> **u8 #foreign libobjc;

/**
* Returns the dynamic library name a class originated from.
*
* @param cls The class you are inquiring about.
*
* @return The name of the library containing this class.
*/
class_getImageName :: (cls: Class) -> *u8 #foreign libobjc;

/**
* Returns the names of all the classes within a library.
*
* @param image The library or framework you are inquiring about.
* @param outCount The number of class names returned.
*
* @return An array of C strings representing the class names.
*/
objc_copyClassNamesForImage :: (image: *u8, outCount: *u32) -> **u8 #foreign libobjc;

/**
* Returns a Boolean value that indicates whether two selectors are equal.
*
* @param lhs The selector to compare with rhs.
* @param rhs The selector to compare with lhs.
*
* @return \c YES if \e lhs and \e rhs are equal, otherwise \c NO.
*
* @note sel_isEqual is equivalent to ==.
*/
sel_isEqual :: (lhs: SEL, rhs: SEL) -> BOOL #foreign libobjc;

/**
* This function is inserted by the compiler when a mutation
* is detected during a foreach iteration. It gets called
* when a mutation occurs, and the enumerationMutationHandler
* is enacted if it is set up. A fatal error occurs if a handler is not set up.
*
* @param obj The object being mutated.
*
*/
objc_enumerationMutation :: (obj: id) -> void #foreign libobjc;

/**
* Sets the current mutation handler.
*
* @param handler Function pointer to the new mutation handler.
*/
objc_setEnumerationMutationHandler :: (handler: #type (unknown0: id) -> void #c_call) -> void #foreign libobjc;

/**
* Set the function to be called by objc_msgForward.
*
* @param fwd Function to be jumped to by objc_msgForward.
* @param fwd_stret Function to be jumped to by objc_msgForward_stret.
*
* @see message.h::_objc_msgForward
*/
objc_setForwardHandler :: (fwd: *void, fwd_stret: *void) -> void #foreign libobjc;

/**
* Creates a pointer to a function that will call the block
* when the method is called.
*
* @param block The block that implements this method. Its signature should
*  be: method_return_type ^(id self, method_args...).
*  The selector is not available as a parameter to this block.
*  The block is copied with \c Block_copy().
*
* @return The IMP that calls this block. Must be disposed of with
*  \c imp_removeBlock.
*/
imp_implementationWithBlock :: (block: id) -> IMP #foreign libobjc;

/**
* Return the block associated with an IMP that was created using
* \c imp_implementationWithBlock.
*
* @param anImp The IMP that calls this block.
*
* @return The block called by \e anImp.
*/
imp_getBlock :: (anImp: IMP) -> id #foreign libobjc;

/**
* Disassociates a block from an IMP that was created using
* \c imp_implementationWithBlock and releases the copy of the
* block that was created.
*
* @param anImp An IMP that was created using \c imp_implementationWithBlock.
*
* @return YES if the block was released successfully, NO otherwise.
*  (For example, the block might not have been used to create an IMP previously).
*/
imp_removeBlock :: (anImp: IMP) -> BOOL #foreign libobjc;

/**
* This loads the object referenced by a weak pointer and returns it, after
* retaining and autoreleasing the object to ensure that it stays alive
* long enough for the caller to use it. This function would be used
* anywhere a __weak variable is used in an expression.
*
* @param location The weak pointer address
*
* @return The object pointed to by \e location, or \c nil if \e *location is \c nil.
*/
objc_loadWeak :: (location: *id) -> id #foreign libobjc;

/**
* This function stores a new value into a __weak variable. It would
* be used anywhere a __weak variable is the target of an assignment.
*
* @param location The address of the weak pointer itself
* @param obj The new object this weak ptr should now point to
*
* @return The value stored into \e location, i.e. \e obj
*/
objc_storeWeak :: (location: *id, obj: id) -> id #foreign libobjc;

/**
* Policies related to associative references.
* These are options to objc_setAssociatedObject()
*/
objc_AssociationPolicy :: u64;
OBJC_ASSOCIATION :: enum u32 {
    ASSIGN           :: 0;
    RETAIN_NONATOMIC :: 1;

    COPY_NONATOMIC   :: 3;

    RETAIN           :: 769;

    COPY             :: 771;

    OBJC_ASSOCIATION_ASSIGN           :: ASSIGN;
    OBJC_ASSOCIATION_RETAIN_NONATOMIC :: RETAIN_NONATOMIC;

    OBJC_ASSOCIATION_COPY_NONATOMIC   :: COPY_NONATOMIC;

    OBJC_ASSOCIATION_RETAIN           :: RETAIN;

    OBJC_ASSOCIATION_COPY             :: COPY;
}

/**
* Sets an associated value for a given object using a given key and association policy.
*
* @param object The source object for the association.
* @param key The key for the association.
* @param value The value to associate with the key key for object. Pass nil to clear an existing association.
* @param policy The policy for the association. For possible values, see “Associative Object Behaviors.”
*
* @see objc_setAssociatedObject
* @see objc_removeAssociatedObjects
*/
objc_setAssociatedObject :: (object: id, key: *void, value: id, policy: objc_AssociationPolicy) -> void #foreign libobjc;

/**
* Returns the value associated with a given object for a given key.
*
* @param object The source object for the association.
* @param key The key for the association.
*
* @return The value associated with the key \e key for \e object.
*
* @see objc_setAssociatedObject
*/
objc_getAssociatedObject :: (object: id, key: *void) -> id #foreign libobjc;

/**
* Removes all associations for a given object.
*
* @param object An object that maintains associated objects.
*
* @note The main purpose of this function is to make it easy to return an object
*  to a "pristine state”. You should not use this function for general removal of
*  associations from objects, since it also removes associations that other clients
*  may have added to the object. Typically you should use \c objc_setAssociatedObject
*  with a nil value to clear an association.
*
* @see objc_setAssociatedObject
* @see objc_getAssociatedObject
*/
objc_removeAssociatedObjects :: (object: id) -> void #foreign libobjc;

objc_method_description_list :: struct {
    count: s32;
    list:  [1] objc_method_description;
}

objc_protocol_list :: struct {
    next:  *objc_protocol_list;
    count: s64;
    list:  [1] *Protocol;
}

objc_category :: struct {
    category_name:    *u8;
    class_name:       *u8;
    instance_methods: *objc_method_list;
    class_methods:    *objc_method_list;
    protocols:        *objc_protocol_list;
}

objc_ivar :: struct {
    ivar_name:   *u8;
    ivar_type:   *u8;
    ivar_offset: s32;

    space:       s32;
}

objc_ivar_list :: struct {
    ivar_count: s32;

    space:      s32;

    /* variable length structure */
    ivar_list:  [1] objc_ivar;
}

objc_method :: struct {
    method_name:  SEL;
    method_types: *u8;
    method_imp:   IMP;
}

objc_method_list :: struct {
    obsolete:     *objc_method_list;

    method_count: s32;

    space:        s32;

    /* variable length structure */
    method_list:  [1] objc_method;
}

Symtab :: *objc_symtab;

objc_symtab :: struct {
    sel_ref_cnt: u64;
    refs:        *SEL;
    cls_def_cnt: u16;
    cat_def_cnt: u16;
    defs:        [1] *void; /* variable size */
}

Cache :: *objc_cache;

objc_cache :: struct {
    mask:     u32; /* total = mask + 1 */
    occupied: u32;
    buckets:  [1] Method;
}

Module :: *objc_module;

objc_module :: struct {
    version: u64;
    size:    u64;
    name:    *u8;
    symtab:  Symtab;
}

/* Obsolete functions */
class_lookupMethod :: (cls: Class, sel: SEL) -> IMP #foreign libobjc;

class_respondsToMethod :: (cls: Class, sel: SEL) -> BOOL #foreign libobjc;

_objc_flush_caches :: (cls: Class) -> void #foreign libobjc;

object_copyFromZone :: (anObject: id, nBytes: u64, z: *void) -> id #foreign libobjc;

class_createInstanceFromZone :: (unknown0: Class, idxIvars: u64, z: *void) -> id #foreign libobjc;

#scope_file

libobjc :: #system_library "libobjc";
