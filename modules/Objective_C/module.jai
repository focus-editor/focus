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
on one version of macOS may make the code incompatible with future versions of macOS.
See: http://www.sealiesoftware.com/blog/archive/2009/01/27/objc_explain_Non-fragile_ivars.html
 */

// :AwfulCopyPasta

#scope_module
#import "macos";
#import "Basic";
// @Cleanup: We definitely shouldn’t pull in and link against Metal and GameController frameworks by default. :MacOsImportCleanup
#load "Foundation.jai";
#load "GameController.jai";
#load "LightweightRenderingView/LightweightRenderingView.jai";
#load "CoreGraphics.jai";
Metal :: #import "Metal";
#scope_export

to_string :: (str: *NSString) -> string {
    init_objective_c();
    return to_string(NSString.UTF8String(str));
}

NSApplicationMain :: (argc: s32, argv: **u8) -> s32 #foreign AppKit;

NSUInteger :: u64;
NSUIntegerMax :: 0xFFFFFFFFFFFFFFFF;
NSInteger :: s64;

// Objective-C runtime

MACOS_10_5  :: 10_05;
MACOS_10_6  :: 10_06;
MACOS_10_7  :: 10_07;
MACOS_10_11 :: 10_11;

MACOS_TARGET_VERSION :: MACOS_10_7;

AVAILABLE_MACOS :: (version_required: NSUInteger) -> bool {
    return MACOS_TARGET_VERSION >= version_required;
}

NSFullUserName :: () -> *NSString #foreign Foundation_Framework;
NSUserName :: () -> *NSString #foreign Foundation_Framework;

NSHomeDirectory :: () -> *NSString #foreign Foundation_Framework;
NSHomeDirectoryForUser :: (username: *NSString) -> *NSString #foreign Foundation_Framework;

NSApp: *NSApplication;

YES :: 1;
NO :: 0;

// Some well-written info on how ObjC blocks are constructed can be found in
// Clang's documentation at https://clang.llvm.org/docs/Block-ABI-Apple.html

// This is an exerpt from the Gamepad module on how one might setup a block:
/*
game_controller_pause_handler_block_func :: (block: *Objective_C_Block_Basic, controller: *GCController) #c_call {
    ctx: Context;
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


NSObject :: struct {
    isa: Class;
}

objc_alloc :: (class: Class) -> id #no_context {
    return objc_msgSend(class, _sel.alloc);
}

objc_copy :: (self: *$instancetype) -> *instancetype #no_context {
    return xx objc_msgSend(self, _sel.copy);
}

autorelease :: (self: *$instancetype) -> id #no_context {
    return cast(id) objc_msgSend(self, _sel.autorelease);
}

release :: (self: *$instancetype) -> id #no_context {
    return cast(id) objc_msgSend(self, _sel.release);
}

retain :: (self: *$instancetype) -> *instancetype #no_context {
    return xx objc_msgSend(self, _sel.retain);
}

class :: (self: id) -> Class #no_context {
    // I'm pretty sure this is just id.isa
    // but this is the "correct" way to do this.
    return cast(Class) objc_msgSend(self, _sel.class);
}

superclass :: (self: id) -> Class #no_context {
    return cast(Class) objc_msgSend(self, _sel.superclass);
}

isEqual :: (self: id, object: id) -> bool #no_context {
    return objc_msgSend(self, _sel.isEqual_, object) != null;
}

// helper functions so we don't need to have messy
// user code

objc_init :: (self: *$type) -> *type #no_context {
    return cast(*type) objc_msgSend(self, _sel.init);
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

class :: (type: Type) -> Class #no_context {
    struct_info := cast(*Type_Info_Struct) type;
    if struct_info.type != .STRUCT   return null;
    return objc_getClass(struct_info.name.data);
}

NSApplicationDelegate :: struct {
    using nsobject: NSObject;
} @ObjCProtocol


NSAutoreleasePool :: struct {
    super: NSObject;

    drain :: (self: *NSAutoreleasePool) {
        objc_msgSend(self, _sel.drain);
    }
}

NSRange :: struct {
    location: NSUInteger;
    length: NSUInteger;
}

NSBundle :: struct {
    super: NSObject;

    resourcePath :: (self: *NSBundle) -> *NSString {
        return objc_msgSend(self, _sel.resourcePath);
    }

    mainBundle :: () -> *NSBundle {
        return objc_msgSend(class(NSBundle), _sel.mainBundle);
    }
}

CGColorSpaceRef :: *void;
IOSurfaceRef :: *void;

dispatch_queue_t :: *NSObject;
dispatch_data_t  :: *NSObject;

NSTimeInterval :: float64;

NSTimer :: struct {
    super: NSObject;

    scheduledTimerWithTimeInterval :: (interval: NSTimeInterval, target: id, selector: Selector, userInfo: id, repeats: BOOL) -> *NSTimer {
        return xx objc_msgSend(class(NSTimer), _sel.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_, interval, target, selector, userInfo, repeats);
    }
}

NSEvent :: struct {
    super: NSObject;

    mouseLocation :: () -> NSPoint {
        func: (*void, Selector) -> NSPoint #foreign;
        func = xx objc_msgSend;
        return func(class(NSEvent), _sel.mouseLocation);
    }

    type :: (self: *NSEvent) -> NSEventType {
        return xx objc_msgSend(self, _sel.type);
    }

    characters :: (self: *NSEvent) -> *NSString {
        return xx objc_msgSend(self, _sel.characters);
    }

    charactersIgnoringModifiers :: (self: *NSEvent) -> *NSString {
        return xx objc_msgSend(self, _sel.charactersIgnoringModifiers);
    }

    keyCode :: (self: *NSEvent) -> u16 {
        return xx objc_msgSend(self, _sel.keyCode);
    }

    modifierFlags :: (self: *NSEvent) -> NSEventModifierFlags {
        return xx objc_msgSend(self, _sel.modifierFlags);
    }

    isARepeat :: (self: *NSEvent) -> BOOL {
        return xx objc_msgSend(self, _sel.isARepeat);
    }

    keyRepeatDelay :: (self: *NSEvent) -> NSTimeInterval {
        func: (self: *NSEvent, op: Selector) -> NSTimeInterval #foreign;
        func = xx objc_msgSend;
        return func(self, _sel.keyRepeatDelay);
    }

    keyRepeatInterval :: (self: *NSEvent) -> NSTimeInterval {
        func: (self: *NSEvent, op: Selector) -> NSTimeInterval #foreign;
        func = xx objc_msgSend;
        return func(self, _sel.keyRepeatInterval);
    }

    pressedMouseButtons :: (self: *NSEvent) -> NSUInteger {
        return xx objc_msgSend(self, _sel.pressedMouseButtons);
    }

    buttonNumber :: (self: *NSEvent) -> NSInteger {
        return xx objc_msgSend(self, _sel.buttonNumber);
    }

    clickCount :: (self: *NSEvent) -> NSInteger {
        return xx objc_msgSend(self, _sel.clickCount);
    }

    associatedEventsMask :: (self: *NSEvent) -> NSEventMask {
        return xx objc_msgSend(self, _sel.associatedEventsMask);
    }

    deltaX :: (self: *NSEvent) -> CGFloat {
        func: (self: *void, op: Selector) -> CGFloat #foreign;
        func = xx objc_msgSend_fpret;
        return func(self, _sel.deltaX);
    }

    deltaY :: (self: *NSEvent) -> CGFloat {
        func: (self: *void, op: Selector) -> CGFloat #foreign;
        func = xx objc_msgSend_fpret;
        return func(self, _sel.deltaY);
    }

    deltaZ :: (self: *NSEvent) -> CGFloat {
        func: (self: *void, op: Selector) -> CGFloat #foreign;
        func = xx objc_msgSend_fpret;
        return func(self, _sel.deltaZ);
    }
}

using NSEventModifierFlags :: enum_flags NSUInteger {
    NSEventModifierFlagCapsLock           :: 1 << 16;
    NSEventModifierFlagShift              :: 1 << 17;
    NSEventModifierFlagControl            :: 1 << 18;
    NSEventModifierFlagOption             :: 1 << 19;
    NSEventModifierFlagCommand            :: 1 << 20;
    NSEventModifierFlagNumericPad         :: 1 << 21;
    NSEventModifierFlagHelp               :: 1 << 22;
    NSEventModifierFlagFunction           :: 1 << 23;

    NSEventModifierFlagDeviceIndependentFlagsMask    :: 0xffff0000;
}

using NSApplicationPresentationOptions :: enum NSUInteger {
    NSApplicationPresentationDefault                         :: 0;
    NSApplicationPresentationAutoHideDock                    :: (1 << 0);
    NSApplicationPresentationHideDock                        :: (1 <<  1);
    NSApplicationPresentationAutoHideMenuBar                 :: (1 <<  2);
    NSApplicationPresentationHideMenuBar                     :: (1 <<  3);
    NSApplicationPresentationDisableAppleMenu                :: (1 <<  4);
    NSApplicationPresentationDisableProcessSwitching         :: (1 <<  5);
    NSApplicationPresentationDisableForceQuit                :: (1 <<  6);
    NSApplicationPresentationDisableSessionTermination       :: (1 <<  7);
    NSApplicationPresentationDisableHideApplication          :: (1 <<  8);
    NSApplicationPresentationDisableMenuBarTransparency      :: (1 <<  9);
    NSApplicationPresentationFullScreen                      :: (1 << 10);
    NSApplicationPresentationAutoHideToolbar                 :: (1 << 11);
    NSApplicationPresentationDisableCursorLocationAssistance :: (1 << 12);
}

NSRunLoop :: struct {
    super: NSObject;

    currentRunLoop :: () -> *NSRunLoop {
        return objc_msgSend(objc_getClass("NSRunLoop"), _sel.currentRunLoop);
    }

    run :: (self: *NSRunLoop) {
        objc_msgSend(self, _sel.run);
    }
}

NSApplication :: struct {
    super: NSObject;

    sharedApplication :: () -> *NSApplication #no_context {
        ret := objc_msgSend(class(NSApplication), _sel.sharedApplication);
        NSApp = xx ret; // @Hack remove this once extern data declarations exist
        return xx ret;
    }

    run :: (self: *NSApplication) #no_context {
        objc_msgSend(self, _sel.run);
    }

    stop :: (self: *NSApplication, sender: id) #no_context {
        objc_msgSend(self, _sel.stop_, sender);
    }

    mainWindow :: (self: *NSApplication) -> *NSWindow #no_context {
        return xx objc_msgSend(self, _sel.mainWindow);
    }

    keyWindow :: (self: *NSApplication) -> *NSWindow #no_context {
        return xx objc_msgSend(self, _sel.keyWindow);
    }

    sendEvent :: (self: *NSApplication, event: *NSEvent) #no_context {
        objc_msgSend(self, _sel.sendEvent_, event);
    }

    updateWindows :: (self: *NSApplication) #no_context {
        objc_msgSend(self, _sel.updateWindows);
    }

    activateIgnoringOtherApps :: (self: *NSApplication, value: BOOL) #no_context {
        objc_msgSend(self, _sel.activateIgnoringOtherApps_, value);
    }

    setActivationPolicy :: (self: *NSApplication, policy: NSApplicationActivationPolicy) -> bool #no_context {
        return xx objc_msgSend(self, _sel.setActivationPolicy_, policy);
    }

    setDelegate :: (self: *NSApplication, del: *NSApplicationDelegate) -> id #no_context {
        return xx objc_msgSend(self, _sel.setDelegate_, del);
    }

    finishLaunching :: (self: *NSApplication) -> id #no_context {
        return xx objc_msgSend(self, _sel.finishLaunching);
    }

    setMainMenu :: (self: *NSApplication, menu: *NSMenu) -> id #no_context {
        return xx objc_msgSend(self, _sel.setMainMenu_, menu);
    }

    nextEventMatchingMask :: (self: *NSApplication, mask: NSEventMask, untilDate: *NSDate, inMode: NSRunLoopMode, dequeue: BOOL) -> *NSEvent #no_context {
        return xx objc_msgSend(self, _sel.nextEventMatchingMask_untilDate_inMode_dequeue_, mask, untilDate, inMode, dequeue);
    }

    presentationOptions :: (self: *NSApplication) -> NSApplicationPresentationOptions #no_context {
        return xx objc_msgSend(self, _sel.presentationOptions);
    }

    setPresentationOptions :: (self: *NSApplication, options: NSApplicationPresentationOptions) #no_context {
        objc_msgSend(self, _sel.setPresentationOptions_, options);
    }

    setAppleMenu :: (self: *NSApplication, menu: *NSMenu) #no_context {
        objc_msgSend(self, _sel.setAppleMenu_, menu);
    }

    terminate :: (self: *NSApplication, sender: id) #no_context {
        objc_msgSend(self, _sel.terminate_);
    }

    requestUserAttention :: (self: *NSApplication, requestType: NSRequestUserAttentionType) -> NSInteger #no_context {
        return xx objc_msgSend(self, _sel.requestUserAttention_, requestType);
    }
}

using NSRequestUserAttentionType ::  enum NSUInteger {
    NSCriticalRequest :: 0;
    NSInformationalRequest :: 10;
}

using NSApplicationTerminateReply :: enum NSUInteger {
    NSTerminateCancel :: 0;
    NSTerminateNow    :: 1;
    NSTerminateLater  :: 2;
}

using NSEventType :: enum NSUInteger {
    NSEventTypeLeftMouseDown             :: 1;
    NSEventTypeLeftMouseUp               :: 2;
    NSEventTypeRightMouseDown            :: 3;
    NSEventTypeRightMouseUp              :: 4;
    NSEventTypeMouseMoved                :: 5;
    NSEventTypeLeftMouseDragged          :: 6;
    NSEventTypeRightMouseDragged         :: 7;
    NSEventTypeMouseEntered              :: 8;
    NSEventTypeMouseExited               :: 9;
    NSEventTypeKeyDown                   :: 10;
    NSEventTypeKeyUp                     :: 11;
    NSEventTypeFlagsChanged              :: 12;
    NSEventTypeAppKitDefined             :: 13;
    NSEventTypeSystemDefined             :: 14;
    NSEventTypeApplicationDefined        :: 15;
    NSEventTypePeriodic                  :: 16;
    NSEventTypeCursorUpdate              :: 17;
    NSEventTypeScrollWheel               :: 22;
    NSEventTypeTabletPoint               :: 23;
    NSEventTypeTabletProximity           :: 24;
    NSEventTypeOtherMouseDown            :: 25;
    NSEventTypeOtherMouseUp              :: 26;
    NSEventTypeOtherMouseDragged         :: 27;

    // #if #run AVAILABLE_MACOS(10_5) {
        NSEventTypeGesture        :: 29;
        NSEventTypeMagnify        :: 30;
        NSEventTypeSwipe          :: 31;
        NSEventTypeRotate         :: 18;
        NSEventTypeBeginGesture   :: 19;
        NSEventTypeEndGesture     :: 20;
    // }
}

using NSEventMask :: enum u64 {
    NSEventMaskLeftMouseDown         :: 1 << NSEventTypeLeftMouseDown;
    NSEventMaskLeftMouseUp           :: 1 << NSEventTypeLeftMouseUp;
    NSEventMaskRightMouseDown        :: 1 << NSEventTypeRightMouseDown;
    NSEventMaskRightMouseUp          :: 1 << NSEventTypeRightMouseUp;
    NSEventMaskMouseMoved            :: 1 << NSEventTypeMouseMoved;
    NSEventMaskLeftMouseDragged      :: 1 << NSEventTypeLeftMouseDragged;
    NSEventMaskRightMouseDragged     :: 1 << NSEventTypeRightMouseDragged;
    NSEventMaskMouseEntered          :: 1 << NSEventTypeMouseEntered;
    NSEventMaskMouseExited           :: 1 << NSEventTypeMouseExited;
    NSEventMaskKeyDown               :: 1 << NSEventTypeKeyDown;
    NSEventMaskKeyUp                 :: 1 << NSEventTypeKeyUp;
    NSEventMaskFlagsChanged          :: 1 << NSEventTypeFlagsChanged;
    NSEventMaskAppKitDefined         :: 1 << NSEventTypeAppKitDefined;
    NSEventMaskSystemDefined         :: 1 << NSEventTypeSystemDefined;
    NSEventMaskApplicationDefined    :: 1 << NSEventTypeApplicationDefined;
    NSEventMaskPeriodic              :: 1 << NSEventTypePeriodic;
    NSEventMaskCursorUpdate          :: 1 << NSEventTypeCursorUpdate;
    NSEventMaskScrollWheel           :: 1 << NSEventTypeScrollWheel;
    NSEventMaskTabletPoint           :: 1 << NSEventTypeTabletPoint;
    NSEventMaskTabletProximity       :: 1 << NSEventTypeTabletProximity;
    NSEventMaskOtherMouseDown        :: 1 << NSEventTypeOtherMouseDown;
    NSEventMaskOtherMouseUp          :: 1 << NSEventTypeOtherMouseUp;
    NSEventMaskOtherMouseDragged     :: 1 << NSEventTypeOtherMouseDragged;

    // #if #run AVAILABLE_MACOS(10_5) {
        NSEventMaskGesture           :: 1 << NSEventTypeGesture;
        NSEventMaskMagnify           :: 1 << NSEventTypeMagnify;
        NSEventMaskSwipe             :: 1 << NSEventTypeSwipe;
        NSEventMaskRotate            :: 1 << NSEventTypeRotate;
        NSEventMaskBeginGesture      :: 1 << NSEventTypeBeginGesture;
        NSEventMaskEndGesture        :: 1 << NSEventTypeEndGesture;
    // }
    NSEventMaskAny :: NSUIntegerMax;
}

using NSApplicationActivationPolicy :: enum NSInteger {
    NSApplicationActivationPolicyRegular :: 0;
    NSApplicationActivationPolicyAccessory :: 1;
    NSApplicationActivationPolicyProhibited :: 2;
}

NSThread :: struct {
    _nsobject: NSObject;

    detachNewThreadSelector :: (sel: Selector, toTarget: id, withObject: id) {
        objc_msgSend(class(NSThread), _sel.detachNewThreadSelector_toTarget_withObject_, sel, toTarget, withObject);
    }

    isMultiThreaded :: () -> BOOL {
        return xx objc_msgSend(class(NSThread), _sel.isMultiThreaded);
    }
}

NSNotification :: struct {
    super: NSObject;

    object :: (self: *NSNotification) -> *NSObject {
        return xx objc_msgSend(self, _sel.object);
    }
}

NSNotificationCenter :: struct {
    super: NSObject;

    defaultCenter :: () -> *NSNotificationCenter {
        return xx objc_msgSend(objc_getClass("NSNotificationCenter"), _sel.defaultCenter);
    }


    addObserver :: (self: *NSNotificationCenter, observer: id, selector: Selector, name: NSNotificationName, object: id) {
        objc_msgSend(self, _sel.addObserver_selector_name_object_, observer, selector, name, object);
    }
}

NSNotificationName :: *NSString;

using NSWindowStyleMask :: enum_flags NSUInteger {
    NSWindowStyleMaskBorderless :: 0;
    NSWindowStyleMaskTitled :: 1 << 0;
    NSWindowStyleMaskClosable :: 1 << 1;
    NSWindowStyleMaskMiniaturizable :: 1 << 2;
    NSWindowStyleMaskResizable  :: 1 << 3;

    NSWindowStyleMaskTexturedBackground :: 1 << 8;

    NSWindowStyleMaskUnifiedTitleAndToolbar :: 1 << 12;

    // @FixMe enabling these causes a compiler assert
    // #if #run AVAILABLE_MACOS(10_7) {
        NSWindowStyleMaskFullScreen :: 1 << 14;
    // }

    // #if #run AVAILABLE_MACOS(10_10) {
        NSWindowStyleMaskFullSizeContentView :: 1 << 15;
    // }

    NSWindowStyleMaskUtilityWindow          :: 1 << 4;
    NSWindowStyleMaskDocModalWindow         :: 1 << 6;
    NSWindowStyleMaskNonactivatingPanel     :: 1 << 7;

    // #if #run AVAILABLE_MACOS(10_6) {
        NSWindowStyleMaskHUDWindow :: 1 << 13;
    // }
}

using NSWindowCollectionBehavior :: enum_flags NSUInteger {
    NSWindowCollectionBehaviorDefault :: 0;
    NSWindowCollectionBehaviorCanJoinAllSpaces :: 1 << 0;
    NSWindowCollectionBehaviorMoveToActiveSpace :: 1 << 1;
    // #if MACOS_TARGET_VERSION >= MACOS_10_6 {
        NSWindowCollectionBehaviorManaged :: 1 << 2;
        NSWindowCollectionBehaviorTransient :: 1 << 3;
        NSWindowCollectionBehaviorStationary :: 1 << 4;
        NSWindowCollectionBehaviorParticipatesInCycle :: 1 << 5;
        NSWindowCollectionBehaviorIgnoresCycle :: 1 << 6;
    // }
    // #if MACOS_TARGET_VERSION >= MACOS_10_7 {
        NSWindowCollectionBehaviorFullScreenPrimary :: 1 << 7;
        NSWindowCollectionBehaviorFullScreenAuxiliary :: 1 << 8;
        NSWindowCollectionBehaviorFullScreenNone :: 1 << 9;
    // }
    // #if MACOS_TARGET_VERSION >= MACOS_10_11 {
        NSWindowCollectionBehaviorFullScreenAllowsTiling :: 1 << 11;
        NSWindowCollectionBehaviorFullScreenDisallowsTiling :: 1 << 12;
    // }
}

NSBackingStoreType :: enum NSUInteger {
    NSBackingStoreRetained :: 0; @deprecated
    NSBackingStoreNonretained :: 1; @deprecated
    NSBackingStoreBuffered :: 2;
}

using NSBackingStoreType;

NSResponder :: struct {
    nsobject: NSObject;

    _responder_data: [8] u8;
}

NSWindowController :: struct {
    nsresponder: NSResponder;

    _nswindowcontroller_data: [80 - size_of(NSResponder)] u8;
}

NSColor :: struct {
    super: NSObject;

    blueColor :: () -> *NSColor {
        return xx objc_msgSend(class(NSColor), _sel.blueColor);
    }
}

NSDate :: struct {
    super: NSObject;

    distantPast :: () -> *NSDate {
        return xx objc_msgSend(class(NSDate), _sel.distantPast);
    }

    distantFuture :: () -> *NSDate {
        return xx objc_msgSend(class(NSDate), _sel.distantFuture);
    }
}

NSPasteboard :: struct {
    super: NSObject;

    generalPasteboard :: () -> *NSPasteboard {
        return xx objc_msgSend(class(NSPasteboard), _sel.generalPasteboard);
    }

    // instance
    clearContents :: (self: *NSPasteboard) -> NSInteger {
        return xx objc_msgSend(self, _sel.clearContents);
    }

    setString :: (self: *NSPasteboard, str: *NSString, forType: NSPasteboardType) -> BOOL {
        return xx objc_msgSend(self, _sel.setString_forType_, str, forType);
    }

    stringForType :: (self: *NSPasteboard, dataType: NSPasteboardType) -> *NSString {
        return xx objc_msgSend(self, _sel.stringForType_, dataType);
    }

    writeObjects :: (self: *NSPasteboard, objects: *NSArray(id)) -> BOOL {
        return xx objc_msgSend(self, _sel.writeObjects_, objects);
    }
}

NSWindow :: struct {
    using nsresponder: NSResponder;

    convertRectToBacking   :: NSView.convertRectToBacking;
    convertRectFromBacking :: NSView.convertRectFromBacking;

    frame :: NSView.frame;
    setFrame :: (self: *NSWindow, frame: NSRect, display: BOOL) {
        objc_msgSend(self, _sel.setFrame_display_, frame, display);
    }

    level :: (self: *NSWindow) -> NSWindowLevel {
        return xx objc_msgSend(self, _sel.level);
    }

    setLevel :: (self: *NSWindow, level: NSWindowLevel) {
        objc_msgSend(self, _sel.setLevel_, level);
    }

    makeKeyAndOrderFront :: (self: *NSWindow, sender: id) {
        objc_msgSend(self, _sel.makeKeyAndOrderFront_, sender);
    }

    setReleasedWhenClosed :: (self: *NSWindow, value: BOOL) {
        objc_msgSend(self, _sel.setReleasedWhenClosed_, value);
    }

    setBackgroundColor :: (self: *NSWindow, color: *NSColor) {
        objc_msgSend(self, _sel.setBackgroundColor_, color);
    }

    setStyleMask :: (self: *NSWindow, styleMask: NSWindowStyleMask) {
        objc_msgSend(self, _sel.setStyleMask_, styleMask);
    }

    styleMask :: (self: *NSWindow) -> NSWindowStyleMask {
        return xx objc_msgSend(self, _sel.styleMask);
    }

    setFrameOrigin :: (self: *NSWindow, pt: NSPoint) {
        objc_msgSend(self, _sel.setFrameOrigin_, pt);
    }

    setDelegate :: (self: *NSWindow, dg: id) {
        objc_msgSend(self, _sel.setDelegate_, dg);
    }

    update :: (self: *NSWindow) -> id {
        return xx objc_msgSend(self, _sel.update);
    }

    display :: (self: *NSWindow) -> id {
        return xx objc_msgSend(self, _sel.display);
    }

    setContentSize :: (self: *NSWindow, size: NSSize) {
        objc_msgSend(self, _sel.setContentSize_, size);
    }

    setCollectionBehavior :: (self: *NSWindow, behavior: NSWindowCollectionBehavior) {
        objc_msgSend(self, _sel.setCollectionBehavior_, behavior);
    }

    initWithContentRect :: (self: *NSWindow, rect: NSRect, styleMask: NSWindowStyleMask, backing: NSBackingStoreType, _defer: BOOL) -> *NSWindow {
        return xx objc_msgSend(self, _sel.initWithContentRect_styleMask_backing_defer_, rect, styleMask, backing, _defer);
    }

    setTitle :: (self: *NSWindow, title: *NSString) -> id {
        return xx objc_msgSend(self, _sel.setTitle_, title);
    }

    setContentView :: (self: *NSWindow, contentView: id) {
        objc_msgSend(self, _sel.setContentView_, contentView);
    }

    contentView :: (self: *NSWindow) -> *NSView {
        return xx objc_msgSend(self, _sel.contentView);
    }

    makeFirstResponder :: (self: *NSWindow, view: id) {
        objc_msgSend(self, _sel.makeFirstResponder_, view);
    }

    mouseLocationOutsideOfEventStream :: (self: *NSWindow) -> NSPoint {
        func: (*void, Selector) -> NSPoint #foreign;
        func = xx objc_msgSend;
        return func(self, _sel.mouseLocationOutsideOfEventStream);
    }

    performClose :: (self: *NSWindow, sender: id) {
        objc_msgSend(self, _sel.performClose_, sender);
    }

    close :: (self: *NSWindow) {
        objc_msgSend(self, _sel.close);
    }

    convertRectFromScreen :: (self: *NSWindow, rect: NSRect) -> NSRect {
        func: (*void, Selector, NSRect) -> NSRect #foreign;
        func = xx objc_msgSend_stret;
        return func(self, _sel.convertRectFromScreen_, rect);
    }

    convertPointFromScreen :: (self: *NSWindow, point: NSPoint) -> NSPoint {
        func: (*void, Selector, NSPoint) -> NSPoint #foreign;
        func = xx objc_msgSend;
        return func(class(NSEvent), _sel.convertPointFromScreen_, point);
    }

    orderOut :: (self: *NSWindow, sender: id) {
        func: (*NSWindow, Selector, id) #foreign;
        func = xx objc_msgSend;
        func(self, _sel.orderOut_, sender);
    }

    orderFront :: (self: *NSWindow, sender: id) {
        func: (*NSWindow, Selector, id) #foreign;
        func = xx objc_msgSend;
        func(self, _sel.orderFront_, sender);
    }

    #if MACOS_TARGET_VERSION >= MACOS_10_7 {
        toggleFullScreen :: (self: *NSWindow, sender: id) {
            objc_msgSend(self, _sel.toggleFullScreen_, sender);
        }
    }

    // helper functions
    setTitle :: (self: *NSWindow, title: string) -> id {
        nsstring := NSString.initWithString(objc_alloc(NSString), title);
        defer release(nsstring);

        return setTitle(self, nsstring);
    }
}

NSPanel :: struct {
    using super_NSWindow: NSWindow;
}

NSSavePanel :: struct {
    using super_NSPanel: NSPanel;

    // static

    savePanel :: () -> *NSSavePanel {
        return xx objc_msgSend(class(NSSavePanel), _sel.savePanel);
    }

    // instance
    runModal :: (self: *NSSavePanel) -> NSModalResponse {
        return xx objc_msgSend(self, _sel.runModal);
    }

    URL :: (self: *NSSavePanel) -> *NSURL {
        return xx objc_msgSend(self, _sel.URL);
    }

    showsTagField :: (self: *NSSavePanel) -> BOOL {
        return xx objc_msgSend(self, _sel.showsTagField);
    }

    setShowsTagField :: (self: *NSSavePanel, show: BOOL) {
        objc_msgSend(self, _sel.setShowsTagField_, show);
    }

    canSelectHiddenExtension :: (self: *NSSavePanel) -> BOOL {
        return xx objc_msgSend(self, _sel.canSelectHiddenExtension);
    }

    setCanSelectHiddenExtension :: (self: *NSSavePanel, can: BOOL) {
        objc_msgSend(self, _sel.setCanSelectHiddenExtension_, can);
    }

    directoryURL :: (self: *NSSavePanel) -> *NSURL {
        return xx objc_msgSend(self, _sel.directoryURL);
    }

    setDirectoryURL :: (self: *NSSavePanel, url: *NSURL) {
        objc_msgSend(self, _sel.setDirectoryURL_, url);
    }

    setNameFieldStringValue :: (self: *NSSavePanel, value: *NSString) {
        objc_msgSend(self, _sel.setNameFieldStringValue_, value);
    }

    nameFieldStringValue :: (self: *NSSavePanel) -> *NSString {
        return xx objc_msgSend(self, _sel.nameFieldStringValue);
    }

    setAllowedFileTypes :: (self: *NSSavePanel, types: *NSArray(*NSString)) {
        objc_msgSend(self, _sel.setAllowedFileTypes_, types);
    }

    allowedFileTypes :: (self: *NSSavePanel) -> *NSArray(*NSString) {
        return xx objc_msgSend(self, _sel.allowedFileTypes);
    }

    setAllowsOtherFileTypes :: (self: *NSSavePanel, value: BOOL) {
        objc_msgSend(self, _sel.setAllowsOtherFileTypes_, value);
    }

    allowsOtherFileTypes :: (self: *NSSavePanel) -> BOOL {
        return xx objc_msgSend(self, _sel.allowsOtherFileTypes);
    }
}

NSOpenPanel :: struct {
    using super_NSSavePanel: NSSavePanel;

    openPanel :: () -> *NSOpenPanel {
        return xx objc_msgSend(class(NSOpenPanel), _sel.openPanel);
    }


}

NSFileHandlingPanelCancelButton :: NSModalResponseCancel;
NSFileHandlingPanelOKButton     :: NSModalResponseOK;

NSAlertFirstButtonReturn  :NSModalResponse: 1000;
NSAlertSecondButtonReturn :NSModalResponse: 1001;
NSAlertThirdButtonReturn  :NSModalResponse: 1002;

NSModalResponseStop       :NSModalResponse: -1000;
NSModalResponseAbort      :NSModalResponse: -1001;
NSModalResponseContinue   :NSModalResponse: -1002;

NSModalResponseOK         :NSModalResponse: 1;
NSModalResponseCancel     :NSModalResponse: 0;

NSModalResponse :: NSInteger;

NSWindowLevel :: NSInteger;

NSMenu :: struct {
    _nsobject: NSObject;

    addItem :: (self: *NSMenu, item: *NSMenuItem) {
        objc_msgSend(self, _sel.addItem_, item);
    }

    addItemWithTitle :: (self: *NSMenu, title: *NSString, action: Selector, keyEquivalent: *NSString) -> *NSMenuItem {
        return xx objc_msgSend(self, _sel.addItemWithTitle_action_keyEquivalent_, title, action, keyEquivalent);
    }
}

NSMenuItem :: struct {
    _nsobject: NSObject;

    initWithTitle :: (self: *NSMenuItem, title: *NSString, action: Selector, keyEquivalent: *NSString) -> *NSMenuItem {
        return xx objc_msgSend(self, _sel.initWithTitle_action_keyEquivalent_, title, action, keyEquivalent);
    }

    setSubmenu :: (self: *NSMenuItem, sub: *NSMenu) {
        objc_msgSend(self, _sel.setSubmenu_, sub);
    }
}

CGFloat :: float64; // float32 on 32-bit CPUs

NSPoint :: struct {
    x: CGFloat;
    y: CGFloat;
}

CGSize :: struct {
    width : CGFloat;
    height: CGFloat;
}

NSMakePoint :: (x: CGFloat, y: CGFloat) -> NSPoint {
    p: NSPoint = ---;
    p.x = x;
    p.y = y;
    return p;
}

NSSize :: CGSize;

NSMakeSize :: (w: CGFloat, h: CGFloat) -> NSSize {
    s: NSSize = ---;
    s.width = w;
    s.height = h;
    return s;
}

NSRect :: struct {
    origin: NSPoint;
    size: NSSize;
}

NSMakeRect :: (x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat) -> NSRect {
    r: NSRect = ---;
    r.origin.x = x;
    r.origin.y = y;
    r.size.width = w;
    r.size.height = h;
    return r;
}

NSView :: struct {
    super: NSObject;

    pad: [152 - size_of(NSObject)] u8; // NSView must be 152 bytes

    addSubView :: (self: *NSView, view: *NSView) {
        objc_msgSend(self, _sel.addSubView_, view);
    }

    setWantsLayer :: (self: id, yesno: BOOL) {
        objc_msgSend(self, _sel.setWantsLayer_, yesno);
    }

    frame :: (self: id) -> NSRect {
        func: (*void, Selector) -> NSRect #foreign;
        func = xx objc_msgSend_stret;
        return func(self, _sel.frame);
    }

    bounds :: (self: id) -> NSRect {
        func: (*void, Selector) -> NSRect #foreign;
        func = xx objc_msgSend_stret;
        return func(self, _sel.bounds);
    }

    setFrame :: (self: id, frame: NSRect) {
        objc_msgSend(self, _sel.setFrame_, frame);
    }

    setWantsBestResolutionOpenGLSurface :: (self: id, val: BOOL) {
        objc_msgSend(self, _sel.setWantsBestResolutionOpenGLSurface_, val);
    }

    convertRectToBacking :: (self: id, rect: NSRect) -> NSRect {
        func: (*void, Selector, NSRect) -> NSRect #foreign;
        func = xx objc_msgSend_stret;
        return func(self, _sel.convertRectToBacking_, rect);
    }

    convertRectFromBacking :: (self: id, rect: NSRect) -> NSRect {
        func: (*void, Selector, NSRect) -> NSRect #foreign;
        func = xx objc_msgSend_stret;
        return func(self, _sel.convertRectFromBacking_, rect);
    }

    convertPointToBacking :: (self: id, point: NSPoint) -> NSPoint {
        func: (*void, Selector, NSPoint) -> NSPoint #foreign;
        func = xx objc_msgSend;
        return func(self, _sel.convertPointToBacking_, point);
    }

    convertPointFromBacking :: (self: id, point: NSPoint) -> NSPoint {
        func: (*void, Selector, NSPoint) -> NSPoint #foreign;
        func = xx objc_msgSend;
        return func(self, _sel.convertPointFromBacking_, point);
    }

    isInFullScreenMode :: (self: id) -> BOOL {
        return xx objc_msgSend(self, _sel.isInFullScreenMode);
    }

    enterFullScreenMode :: (self: id, screen: *NSScreen, withOptions: *NSDictionary) -> BOOL {
        return xx objc_msgSend(self, _sel.enterFullScreenMode_withOptions_, screen, withOptions);
    }

    exitFullScreenModeWithOptions :: (self: id, options: *NSDictionary) {
        objc_msgSend(self, _sel.exitFullScreenModeWithOptions_, options);
    }

    layer :: (self: id) -> *CALayer {
        return xx objc_msgSend(self, _sel.layer);
    }

    mouse_inRect :: (self: id, mouse: NSPoint, inRect: NSRect) -> BOOL {
        return xx objc_msgSend(self, _sel.mouse_inRect_, mouse, inRect);
    }

    convertPoint :: (self: id, point: NSPoint, fromView: *NSView) -> NSPoint {
        func: (*void, Selector, NSPoint, *NSView) -> NSPoint #foreign;
        func = xx objc_msgSend;
        return func(class(NSEvent), _sel.convertPoint_fromView_, point, fromView);
    }

    drawRect :: (self: id, dirtyRect: NSRect) {
        func: (*void, Selector, NSRect) #foreign;
        func = xx objc_msgSend;
        func(self, _sel.drawRect_, dirtyRect);
    }
}

NSViewController :: struct {
    super: NSResponder;

    _viewcontrollerdata: [104 - size_of(NSResponder)] u8;
}

NSStringEncoding :: NSUInteger;

NSUTF8StringEncoding  :: 4;
NSUTF32StringEncoding :: 0x8c000100;
NSUTF32LittleEndianStringEncoding :: 0x9c000100;

NSString :: struct {
    super: NSObject;

    initWithBytes :: (self: *NSString, bytes: *void, length: NSUInteger, encoding: NSStringEncoding) -> *NSString {
        return xx objc_msgSend(self, _sel.initWithBytes_length_encoding_, bytes, length, encoding);
    }

    UTF8String :: (self: *NSString) -> *u8 {
        return xx objc_msgSend(self, _sel.UTF8String);
    }

    dataUsingEncoding :: (self: *NSString, encoding: NSStringEncoding, allowLossyConversion := NO) -> *NSData {
        return xx objc_msgSend(self, _sel.dataUsingEncoding_allowLossyConversion_, encoding, allowLossyConversion);
    }

    stringByExpandingTildeInPath :: (self: *NSString) -> *NSString {
        return xx objc_msgSend(self, _sel.stringByExpandingTildeInPath);
    }

    // helper functions
    initWithString :: (self: *NSString, str: string) -> *NSString {
        return initWithBytes(self, str.data, cast(u64) str.count, NSUTF8StringEncoding);
    }

    // allocs, inits, and autoreleases an NSString
    getTempString :: (str: string) -> *NSString {
        nsstring := initWithString(objc_alloc(NSString), str);
        autorelease(nsstring);
        return nsstring;
    }
}

NSRunLoopMode    :: *NSString;
NSPasteboardType :: *NSString;
NSColorSpaceName :: *NSString;

NSURL :: struct {
    super: NSObject;

    URLWithString :: (str: *NSString) -> *NSURL {
        return xx objc_msgSend(class(NSURL), _sel.URLWithString_, str);
    }

    fileURLWithPath :: (path: *NSString) -> *NSURL {
        return objc_msgSend(class(NSURL), _sel.fileURLWithPath_, path);
    }

    fileURLWithPath :: (path: *NSString, isDirectory: BOOL) -> *NSURL {
        return objc_msgSend(class(NSURL), _sel.fileURLWithPath_isDirectory_, path, isDirectory);
    }

    // instance
    path :: (self: *NSURL) -> *NSString {
        return xx objc_msgSend(self, _sel.path);
    }

    URLByDeletingLastPathComponent :: (self: *NSURL) -> *NSURL {
        return xx objc_msgSend(self, _sel.URLByDeletingLastPathComponent);
    }

    hasDirectoryPath :: (self: *NSURL) -> BOOL {
        return xx objc_msgSend(self, _sel.hasDirectoryPath);
    }

    URLByAppendingPathComponent :: (self: *NSURL, comp: *NSString) -> *NSURL {
        return xx objc_msgSend(self, _sel.URLByAppendingPathComponent_, comp);
    }

    #if MACOS_TARGET_VERSION >= MACOS_10_6 {
        lastPathComponent :: (self: *NSURL) -> *NSString {
            return xx objc_msgSend(self, _sel.lastPathComponent);
        }
    }
}

NSData :: struct {
    super: NSObject;

    bytes :: (self: *NSData) -> *void {
        return xx objc_msgSend(self, _sel.bytes);
    }

    length :: (self: *NSData) -> NSUInteger {
        return xx objc_msgSend(self, _sel.length);
    }
}

NSOpenGLContext :: struct {
    super: NSObject;

    currentContext :: () -> *NSOpenGLContext {
        return objc_msgSend(class(NSOpenGLContext), _sel.currentContext);
    }

    flushBuffer :: (self: id) {
        objc_msgSend(self, _sel.flushBuffer);
    }

    update :: (self: id) -> id {
        return xx objc_msgSend(self, _sel.update);
    }

    setView :: (self: id, view: *NSView) {
        objc_msgSend(self, _sel.setView_, view);
    }

    view :: (self: id) -> *NSView {
        return xx objc_msgSend(self, _sel.view);
    }

    initWithFormat :: (self: id, format: *NSOpenGLPixelFormat, shareContext: *NSOpenGLContext) -> *NSOpenGLContext {
        return xx objc_msgSend(self, _sel.initWithFormat_shareContext_, format, shareContext);
    }

    makeCurrentContext :: (self: id) {
        objc_msgSend(self, _sel.makeCurrentContext);
    }

    setValues :: (self: id, values: *s32 /*GLint*/, forParameter: NSOpenGLContextParameter) {
        objc_msgSend(self, _sel.setValues_forParameter_, values, forParameter);
    }
}

using NSOpenGLContextParameter :: enum NSInteger {
    NSOpenGLContextParameterSwapInterval :: 222;
    NSOpenGLContextParameterSurfaceOrder :: 235;
    NSOpenGLContextParameterSurfaceOpacity :: 236;
    NSOpenGLContextParameterSurfaceBackingSize :: 304;
    NSOpenGLContextParameterReclaimResources :: 308;
    NSOpenGLContextParameterCurrentRendererID :: 309;
    NSOpenGLContextParameterGPUVertexProcessing :: 310;
    NSOpenGLContextParameterGPUFragmentProcessing :: 311;
    NSOpenGLContextParameterHasDrawable :: 314;
    NSOpenGLContextParameterMPSwapsInFlight :: 315;
    NSOpenGLContextParameterSwapRectangle :: 200;
    NSOpenGLContextParameterSwapRectangleEnable :: 201;
    NSOpenGLContextParameterRasterizationEnable :: 221;
    NSOpenGLContextParameterStateValidation :: 301;
    NSOpenGLContextParameterSurfaceSurfaceVolatile  :: 306;
}

NSOpenGLPixelFormatAttribute :: u32;

NSOpenGLPFAAllRenderers          :NSOpenGLPixelFormatAttribute:   1;
NSOpenGLPFATripleBuffer          :NSOpenGLPixelFormatAttribute:   3;
NSOpenGLPFADoubleBuffer          :NSOpenGLPixelFormatAttribute:   5;
NSOpenGLPFAAuxBuffers            :NSOpenGLPixelFormatAttribute:   7;
NSOpenGLPFAColorSize             :NSOpenGLPixelFormatAttribute:   8;
NSOpenGLPFAAlphaSize             :NSOpenGLPixelFormatAttribute:  11;
NSOpenGLPFADepthSize             :NSOpenGLPixelFormatAttribute:  12;
NSOpenGLPFAStencilSize           :NSOpenGLPixelFormatAttribute:  13;
NSOpenGLPFAAccumSize             :NSOpenGLPixelFormatAttribute:  14;
NSOpenGLPFAMinimumPolicy         :NSOpenGLPixelFormatAttribute:  51;
NSOpenGLPFAMaximumPolicy         :NSOpenGLPixelFormatAttribute:  52;
NSOpenGLPFASampleBuffers         :NSOpenGLPixelFormatAttribute:  55;
NSOpenGLPFASamples               :NSOpenGLPixelFormatAttribute:  56;
NSOpenGLPFAAuxDepthStencil       :NSOpenGLPixelFormatAttribute:  57;
NSOpenGLPFAColorFloat            :NSOpenGLPixelFormatAttribute:  58;
NSOpenGLPFAMultisample           :NSOpenGLPixelFormatAttribute:  59;
NSOpenGLPFASupersample           :NSOpenGLPixelFormatAttribute:  60;
NSOpenGLPFASampleAlpha           :NSOpenGLPixelFormatAttribute:  61;
NSOpenGLPFARendererID            :NSOpenGLPixelFormatAttribute:  70;
NSOpenGLPFANoRecovery            :NSOpenGLPixelFormatAttribute:  72;
NSOpenGLPFAAccelerated           :NSOpenGLPixelFormatAttribute:  73;
NSOpenGLPFAClosestPolicy         :NSOpenGLPixelFormatAttribute:  74;
NSOpenGLPFABackingStore          :NSOpenGLPixelFormatAttribute:  76;
NSOpenGLPFAScreenMask            :NSOpenGLPixelFormatAttribute:  84;
NSOpenGLPFAAllowOfflineRenderers :NSOpenGLPixelFormatAttribute:  96;
NSOpenGLPFAAcceleratedCompute    :NSOpenGLPixelFormatAttribute:  97;
NSOpenGLPFAOpenGLProfile         :NSOpenGLPixelFormatAttribute:  99;
NSOpenGLPFAVirtualScreenCount    :NSOpenGLPixelFormatAttribute: 128;
NSOpenGLPFAStereo                :NSOpenGLPixelFormatAttribute:   6;
NSOpenGLPFAOffScreen             :NSOpenGLPixelFormatAttribute:  53;
NSOpenGLPFAFullScreen            :NSOpenGLPixelFormatAttribute:  54;
NSOpenGLPFASingleRenderer        :NSOpenGLPixelFormatAttribute:  71;
NSOpenGLPFARobust                :NSOpenGLPixelFormatAttribute:  75;
NSOpenGLPFAMPSafe                :NSOpenGLPixelFormatAttribute:  78;
NSOpenGLPFAWindow                :NSOpenGLPixelFormatAttribute:  80;
NSOpenGLPFAMultiScreen           :NSOpenGLPixelFormatAttribute:  81;
NSOpenGLPFACompliant             :NSOpenGLPixelFormatAttribute:  83;
NSOpenGLPFAPixelBuffer           :NSOpenGLPixelFormatAttribute:  90;
NSOpenGLPFARemotePixelBuffer     :NSOpenGLPixelFormatAttribute:  91;

NSOpenGLProfileVersionLegacy     :NSOpenGLPixelFormatAttribute: 0x1000;
NSOpenGLProfileVersion3_2Core    :NSOpenGLPixelFormatAttribute: 0x3200;
NSOpenGLProfileVersion4_1Core    :NSOpenGLPixelFormatAttribute: 0x4100;


NSOpenGLPixelFormat :: struct {
    super: NSObject;

    initWithAttributes :: (self: id, attrs: *NSOpenGLPixelFormatAttribute) -> *NSOpenGLPixelFormat {
        return xx objc_msgSend(self, _sel.initWithAttributes_, attrs);
    }
}

NSScreen :: struct {
    super: NSObject;

    mainScreen :: () -> *NSScreen {
        return xx objc_msgSend(class(NSScreen), _sel.mainScreen);
    }
    
    screens :: () -> *NSArray(*NSScreen) {
        return xx objc_msgSend(class(NSScreen), _sel.screens);
    }

    frame :: NSView.frame;
}

NSCursor :: struct {

    hide :: () {
        objc_msgSend(class(NSCursor), _sel.hide);
    }

    unhide :: () {
        objc_msgSend(class(NSCursor), _sel.unhide);
    }

    set :: (cursor: *NSCursor) {
        objc_msgSend(cursor, _sel.set);
    }

    arrowCursor :: () -> *NSCursor {
        return xx objc_msgSend(class(NSCursor), _sel.arrowCursor);
    }
    IBeamCursor :: () -> *NSCursor {
        return xx objc_msgSend(class(NSCursor), _sel.IBeamCursor);
    }
    pointingHandCursor :: () -> *NSCursor {
        return xx objc_msgSend(class(NSCursor), _sel.pointingHandCursor);
    }
    openHandCursor :: () -> *NSCursor {
        return xx objc_msgSend(class(NSCursor), _sel.openHandCursor);
    }
    closedHandCursor :: () -> *NSCursor {
        return xx objc_msgSend(class(NSCursor), _sel.closedHandCursor);
    }
    operationNotAllowedCursor :: () -> *NSCursor {
        return xx objc_msgSend(class(NSCursor), _sel.operationNotAllowedCursor);
    }
    resizeLeftRightCursor :: () -> *NSCursor {
        return xx objc_msgSend(class(NSCursor), _sel.resizeLeftRightCursor);
    }
    resizeUpDownCursor :: () -> *NSCursor {
        return xx objc_msgSend(class(NSCursor), _sel.resizeUpDownCursor);
    }
}

NSDictionary :: struct {
    super: NSObject;
}

NSArray :: struct (Object_Type: Type) {
    super: NSObject;

    // static
    arrayWithObjects :: (objs: *Object_Type, count: NSUInteger) -> *NSArray(Object_Type) {
        return xx objc_msgSend(objc_getClass("NSArray"), _sel.arrayWithObjects_count_, objs, count);
        // BUG using class(NSArray) here causes us to assert, it seems NSArray as a polymorphic type does not get emitted to the runtime-type-table!!!!
        // return xx objc_msgSend(class(NSArray), _sel.arrayWithObjects_count_, objs, count);
    }

    // instance

    // @Cleanup it would be nice if we had light generics so that only one version of these functions is generated
    // when NSArray is instantiated with several different types
    containsObject :: (self: *NSArray(Object_Type), anObject: Object_Type) -> BOOL {
        return xx objc_msgSend(self, _sel.containsObject_, anObject);
    }

    objectAtIndex :: (self: *NSArray(Object_Type), index: NSUInteger) -> Object_Type {
        return xx objc_msgSend(self, _sel.objectAtIndex_, index);
    }

    count :: (self: *NSArray(Object_Type)) -> NSUInteger {
        return xx objc_msgSend(self, _sel.count);
    }
}

NSAlert :: struct {
    super: NSObject;

    // instance

    layout :: (self: *NSAlert) {
        objc_msgSend(self, _sel.layout);
    }

    alertStyle :: (self: *NSAlert) -> NSAlertStyle {
        return xx objc_msgSend(self, _sel.alertStyle);
    }

    setAlertStyle :: (self: *NSAlert, style: NSAlertStyle) {
        objc_msgSend(self, _sel.setAlertStyle_, style);
    }

    accessoryView :: (self: *NSAlert) -> *NSView {
        return xx objc_msgSend(self, _sel.accessoryView);
    }

    setAccessoryView :: (self: *NSAlert, value: *NSView) {
        objc_msgSend(self, _sel.setAccessoryView_, value);
    }

    showsHelp :: (self: *NSAlert) -> BOOL {
        return xx objc_msgSend(self, _sel.showsHelp);
    }

    setShowsHelp :: (self: *NSAlert, value: BOOL) {
        objc_msgSend(self, _sel.setShowsHelp_, value);
    }

    runModal :: (self: *NSAlert) -> NSModalResponse {
        return xx objc_msgSend(self, _sel.runModal);
    }

    addButtonWithTitle :: (self: *NSAlert, title: *NSString) -> *NSButton {
        return xx objc_msgSend(self, _sel.addButtonWithTitle_, title);
    }

    messageText :: (self: *NSAlert) -> *NSString {
        return xx objc_msgSend(self, _sel.messageText);
    }

    setMessageText :: (self: *NSAlert, value: *NSString) {
        objc_msgSend(self, _sel.setMessageText_, value);
    }

    informativeText :: (self: *NSAlert) -> *NSString {
        return xx objc_msgSend(self, _sel.informativeText);
    }

    setInformativeText :: (self: *NSAlert, value: *NSString) {
        objc_msgSend(self, _sel.setInformativeText_, value);
    }

    // helper

    addButtonWithTitle :: (self: *NSAlert, title: string) {
        nsstring := NSString.initWithString(objc_alloc(NSString), title);
        defer release(nsstring);

        addButtonWithTitle(self, nsstring);
    }

    setMessageText :: (self: *NSAlert, title: string) {
        nsstring := NSString.initWithString(objc_alloc(NSString), title);
        defer release(nsstring);

        setMessageText(self, nsstring);
    }

    setInformativeText :: (self: *NSAlert, title: string) {
        nsstring := NSString.initWithString(objc_alloc(NSString), title);
        defer release(nsstring);

        setInformativeText(self, nsstring);
    }

}

NSAlertStyle :: enum NSUInteger {
    NSAlertStyleWarning       :: 0;
    NSAlertStyleInformational :: 1;
    NSAlertStyleCritical      :: 2;
}

NSButton :: struct {
    using nsobject: NSView;

    buttonWithTitle :: (title: *NSString, target: id, action: Selector) -> *NSButton {
        return objc_msgSend(class(NSButton), _sel.buttonWithTitle_target_action_, title, target, action);
    }
}

NSFileManager :: struct {
    super: NSObject;

    defaultManager :: () -> *NSFileManager {
        return xx objc_msgSend(class(NSFileManager), _sel.defaultManager);
    }

    // instance
    // MACOS 10.6+
    URLForDirectory :: (self: *NSFileManager, dir: NSSearchPathDirectory, inDomain: NSSearchPathDomainMask, appropriateForURL: *NSURL, create: BOOL, error: **NSError) -> *NSURL {
        return xx objc_msgSend(self, _sel.URLForDirectory_inDomain_appropriateForURL_create_error_, dir, inDomain, appropriateForURL, create, error);
    }
}

using NSSearchPathDirectory :: enum NSUInteger {
    NSApplicationDirectory :: 1;
    NSDemoApplicationDirectory;
    NSDeveloperApplicationDirectory;
    NSAdminApplicationDirectory;
    NSLibraryDirectory;
    NSDeveloperDirectory;
    NSUserDirectory;
    NSDocumentationDirectory;
    NSDocumentDirectory;
    NSCoreServiceDirectory;
    // #if MACOS_TARGET_VERSION >= MACOS_10_6 {
        NSAutosavedInformationDirectory :: 11;
    // }
    NSDesktopDirectory :: 12;
    NSCachesDirectory :: 13;
    NSApplicationSupportDirectory :: 14;
    // #if MACOS_TARGET_VERSION >= MACOS_10_5 {
        NSDownloadsDirectory :: 15;
    // }
    // #if MACOS_TARGET_VERSION >= MACOS_10_6 {
        NSInputMethodsDirectory :: 16;
        NSMoviesDirectory :: 17;
        NSMusicDirectory :: 18;
        NSPicturesDirectory :: 19;
        NSPrinterDescriptionDirectory :: 20;
        NSSharedPublicDirectory :: 21;
        NSPreferencePanesDirectory :: 22;
    // }
    // #if MACOS_TARGET_VERSION >= MACOS_10_8 {
        NSApplicationScriptsDirectory :: 23;
    // }
    // #if MACOS_TARGET_VERSION >= MACOS_10_6 {
        NSItemReplacementDirectory :: 99;
    // }
    NSAllApplicationsDirectory :: 100;
    NSAllLibrariesDirectory :: 101;
    // #if MACOS_TARGET_VERSION >= MACOS_10_8 {
        NSTrashDirectory :: 102;
    // }
}

using NSSearchPathDomainMask :: enum_flags NSUInteger {
    NSUserDomainMask :: 1;
    NSLocalDomainMask :: 2;
    NSNetworkDomainMask :: 4;
    NSSystemDomainMask :: 8;
    NSAllDomainsMask :: 0x0ffff;
}

NSError :: struct {
    super: NSObject;
}

NSImageRep :: struct {
    using _nsobject: NSObject;

    size :: (self: *NSImageRep) -> NSSize {
        func: (*void, Selector) -> NSSize #foreign;
        func = xx objc_msgSend;
        return func(self, _sel.size);
    }

    setSize :: (self: *NSImageRep, size: NSSize) {
        objc_msgSend(self, _sel.setSize_, size);
    }
}

NSBitmapImageRep :: struct {
    #as using _nsimagerep: NSImageRep;

    initWithBitmapDataPlanes :: (self: *NSBitmapImageRep, planes: **u8, pixelsWide: NSInteger, pixelsHigh: NSInteger,
                                    bitsPerSample: NSInteger, samplesPerPixel: NSInteger, hasAlpha: BOOL, isPlanar: BOOL,
                                    colorSpaceName: NSColorSpaceName, bytesPerRow: NSInteger, bitsPerPixel: NSInteger) -> *NSBitmapImageRep {
        return xx objc_msgSend(self, _sel.initWithBitmapDataPlanes_pixelsWide_pixelsHigh_bitsPerSample_samplesPerPixel_hasAlpha_isPlanar_colorSpaceName_bytesPerRow_bitsPerPixel_,
                                planes, pixelsWide, pixelsHigh, bitsPerSample, samplesPerPixel, hasAlpha, isPlanar, colorSpaceName, bytesPerRow, bitsPerPixel);
    }

    bitmapData :: (self: *NSBitmapImageRep) -> *u8 {
        return xx objc_msgSend(self, _sel.bitmapData);
    }
}

NSImage :: struct {
    using _nsobject: NSObject;

    initWithSize :: (self: *NSImage, size: NSSize) -> *NSImage {
        return xx objc_msgSend(self, _sel.initWithSize_, size);
    }

    addRepresentation :: (self: *NSImage, rep: *NSImageRep) {
        objc_msgSend(self, _sel.addRepresentation_, rep);
    }
}

NSHost :: struct {
    using _nsobject: NSObject;

    currentHost :: () -> *NSHost {
        return xx objc_msgSend(objc_getClass("NSHost"), _sel.currentHost);
    }

    localizedName :: (self: *NSHost) -> *NSString {
        return xx objc_msgSend(self, _sel.localizedName);
    }
}

CALayer :: struct {
    using nsobject: NSObject;
}


Class :: #type *AnyClass;
AnyClass :: struct {
    isa: Class;
    super_class: Class;
}

#if OS == .MACOS {
    BOOL :: s8;
} else { // iOS, tvOS, watchOS; not sure if there's any actual binary difference between these declarations even in C...
    BOOL :: bool;
}

Ivar :: *void;
Selector :: *void;
id :: *void;
IMP :: #type (self: id, cmd: Selector, args: .. Any) -> id #c_call;
Protocol :: struct { }

class_getName :: (cls: *AnyClass) -> *u8 #foreign libobjc;
class_getSuperclass :: (cls: *AnyClass) -> *AnyClass #foreign libobjc;
class_isMetaClass :: (cls: *AnyClass) -> bool #foreign libobjc;
class_getInstanceSize :: (cls: *AnyClass) -> s64 #foreign libobjc;
class_getInstanceVariable :: (cls: *AnyClass, name: *u8) -> *Ivar #foreign libobjc;
class_getClassVariable :: (cls: *AnyClass, name: *u8) -> *Ivar #foreign libobjc;
class_addIvar :: (cls: *AnyClass, name: *u8, size: s64, alignment: u8, types: *u8) -> bool #foreign libobjc;
class_copyIvarList :: (cls: *AnyClass, out_count: *u32) -> *Ivar #foreign libobjc;
class_createInstance :: (cls: *AnyClass, extra_bytes: s64 = 0) -> *void #foreign libobjc;
class_addMethod :: (cls: *AnyClass, name: Selector, imp: IMP, types: *u8) -> bool #foreign libobjc;
class_addProtocol :: (cls: *AnyClass, protcol: *Protocol) -> bool #foreign libobjc;

objc_lookUpClass :: (name: *u8) -> *AnyClass #foreign libobjc;
objc_lookUpClass :: (name: string) -> *AnyClass {
    c_name := to_c_string(name);
    ret := objc_lookUpClass(c_name);
    free(c_name);
    return ret;
}

objc_getClass :: (name: *u8) -> *AnyClass #foreign libobjc;
objc_getClass :: (name: string) -> *AnyClass {
    c_name := to_c_string(name);
    ret := objc_getClass(c_name);
    free(c_name);
    return ret;
}

objc_allocateClassPair :: (super: *AnyClass, name: *u8, extra_bytes: s64 = 0) -> *AnyClass #foreign libobjc;
objc_allocateClassPair :: (super: *AnyClass, name: string, extra_bytes: s64 = 0) -> *AnyClass {
    c_name := to_c_string(name);
    ret := objc_allocateClassPair(super, c_name, extra_bytes);
    free(c_name);
    return ret;
}

objc_getProtocol :: (name: *u8) -> *Protocol #foreign libobjc;
objc_getProtocol :: (name: string) -> *Protocol {
    c_name := to_c_string(name);
    ret := objc_getProtocol(c_name);
    free(c_name);
    return ret;

}

objc_registerClassPair :: (cls: Class) #foreign libobjc;
objc_msgSend :: (self: *void /* supposed to be "id" */, op: Selector, args: .. Any) -> id #foreign libobjc;
objc_msgSend_fpret :: (self: *void, op: Selector, args: .. Any) -> float64 #foreign libobjc;
objc_msgSendSuper :: (super: *objc_super, op: Selector, args: .. Any) -> id #foreign libobjc;

// must be cast to the correct function type with the correct return type
// example:
// frame :: (self: id) -> NSRect {
//     func: (*void, Selector) -> NSRect #foreign;
//     func = xx objc_msgSend_stret;
//     return func(self, _sel.frame);
// }
// The apple docs describe this as having a first argument stretAddr containing a pointer
// to the address of the data being used to write the return value to. I suppose we
// could get away with redefining this to (stret: *void, self: *void, op: Selector, args: .. Any)
// which would reduce the usage of function pointers and casting.
// Note: even though there's a distinction between objc_msgSend and objc_msgSend_stret, the rules
// for which one can be used are not specified in Apple's documentation. On x86, if a struct fits
// in 1 register, then use objc_msgSend, otherwise use objc_msgSend_stret. On x86_64, if a struct
// fits in 2 registers, use objc_msgSend, otherwise use objc_msgSend_stret; this is due to the SysV
// ABI having 2 return structs on x64.
objc_msgSend_stret :: (self: *void, op: Selector, args: .. Any) -> () #foreign libobjc;

objc_super :: struct {
    receiver: id;
    super_class: Class;
}

temp_objc_super :: (receiver: id, super_class: Class) -> *objc_super {
    super := cast(*objc_super) temporary_alloc(size_of(objc_super));
    super.receiver = receiver;
    super.super_class = super_class;
    return super;
}

ivar_getName :: (v: Ivar) -> *u8 #foreign libobjc;
ivar_getOffset :: (v: Ivar) -> s32 #foreign libobjc;
ivar_getTypeEncoding :: (v: Ivar) -> *u8 #foreign libobjc;

sel_getName :: (sel: Selector) -> *u8 #foreign libobjc;
sel_registerName :: (name: *u8) -> Selector #foreign libobjc;
sel_registerName :: (name: string) -> Selector {
    c_name := to_c_string(name);
    ret := sel_registerName(c_name);
    free(c_name);
    return ret;
}


sel_getUid :: (name: *u8) -> Selector #foreign libobjc;
sel_getUid :: (name: string) -> Selector {
    c_name := to_c_string(name);
    ret := sel_getUid(c_name);
    free(c_name);
    return ret;
}

sel_isEqual :: (lhs: Selector, rhs: Selector) -> bool #foreign libobjc;

object_getClass :: (obj: id) -> Class #foreign libobjc;

// short hand for sel_registerName
selector :: (sel_str: string) -> Selector {
    return sel_registerName(sel_str);
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

    parent_instance_size := class_getInstanceSize(parent_class);
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

        if mem.offset_in_bytes < offset then continue;
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
        alignment_shift := cast(u8) log2(cast(float64) alignment);
        success := class_addIvar(my_class, c_name, mem.type.runtime_size, alignment_shift, types_string);
        if !success {
            log_error("Could not add instance variable \"%\" to Objective-C class \"%\"\n", mem.name, tis.name);
            return null;
        }
    }

    instance_size := class_getInstanceSize(my_class);
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
    assert(success);
}

objc_add_class_method :: (my_class: Class, proc: Any, selector_name: string) {
    metaclass :=  object_getClass(my_class);
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

NSDefaultRunLoopMode:   NSRunLoopMode #elsewhere Cocoa;
NSPasteboardTypeString: NSPasteboardType #elsewhere AppKit;
NSDeviceRGBColorSpace:  NSColorSpaceName #elsewhere AppKit;

//
// This is the thing we need to call at some point before
// doing anything in this file!
//
init_objective_c :: () {
    init_objective_c_foundation();
    init_objective_c_gamecontroller();
    init_objective_c_lightweight_rendering_view();
    Metal.init_objective_c_metal();

    init_objective_c_runtime_constants();

    if !_sel.alloc {
        init_objective_c_selector_struct(*_sel);
    }
}

init_objective_c_selector_struct :: (selectors: *$T) {

    struct_info := cast(*Type_Info_Struct) type_info(T);
    assert(struct_info.type == Type_Info_Tag.STRUCT);

    data := cast(*u8) selectors;

    for struct_info.members {
        c_selector_name := to_c_string(it.name);

        for 0..it.name.count-1 {
            if c_selector_name[it] == #char "_" {
                c_selector_name[it] = #char ":";
            }
        }

        <<(cast(*Selector) (data + it.offset_in_bytes)) = sel_registerName(c_selector_name);
    }

}

#scope_file

_Generated_Selectors :: struct #type_info_no_size_complaint {
    alloc: Selector;
    objc_copy: Selector;
    autorelease: Selector;
    release: Selector;
    retain: Selector;
    class: Selector;
    superclass: Selector;
    isEqual_: Selector;
    init: Selector;
    drain: Selector;
    characters: Selector;
    keyCode: Selector;
    modifierFlags: Selector;
    isARepeat: Selector;
    sharedApplication: Selector;
    run: Selector;
    mainWindow: Selector;
    sendEvent_: Selector;
    updateWindows: Selector;
    activateIgnoringOtherApps_: Selector;
    setActivationPolicy_: Selector;
    finishLaunching: Selector;
    setMainMenu_: Selector;
    nextEventMatchingMask_untilDate_inMode_dequeue_: Selector;
    blueColor: Selector;
    distantPast: Selector;
    distantFuture: Selector;
    update: Selector;
    display: Selector;
    contentView: Selector;
    makeKeyAndOrderFront_: Selector;
    setReleasedWhenClosed_: Selector;
    setBackgroundColor_: Selector;
    setStyleMask_: Selector;
    styleMask: Selector;
    setDelegate_: Selector;
    setTitle_: Selector;
    setContentView_: Selector;
    initWithContentRect_styleMask_backing_defer_: Selector;
    makeFirstResponder_: Selector;
    addSubView_: Selector;
    setWantsLayer_: Selector;
    initWithBytes_length_encoding_: Selector;
    UTF8String: Selector;
    dataUsingEncoding_allowLossyConversion_: Selector;
    bytes: Selector;
    length: Selector;
    flushBuffer: Selector;
    setView_: Selector;
    initWithFormat_shareContext_: Selector;
    makeCurrentContext: Selector;
    initWithAttributes_: Selector;
    type: Selector;
    mouseLocation: Selector;
    generalPasteboard: Selector;
    setString_forType_: Selector;
    stringForType_: Selector;
    clearContents: Selector;
    keyRepeatDelay: Selector;
    keyRepeatInterval: Selector;
    pressedMouseButtons: Selector;
    deltaX: Selector;
    deltaY: Selector;
    deltaZ: Selector;
    associatedEventsMask: Selector;
    buttonNumber: Selector;
    clickCount: Selector;
    charactersIgnoringModifiers: Selector;
    object: Selector;
    mouseLocationOutsideOfEventStream: Selector;
    keyWindow: Selector;
    frame: Selector;
    setFrame_: Selector;
    setFrame_display_: Selector;
    URLWithString_: Selector;
    fileURLWithPath_: Selector;
    fileURLWithPath_isDirectory_: Selector;
    stringByExpandingTildeInPath: Selector;
    convertRectToBacking_: Selector;
    convertRectFromBacking_: Selector;
    convertPointToBacking_: Selector;
    convertPointFromBacking_: Selector;
    setWantsBestResolutionOpenGLSurface_: Selector;
    mainScreen: Selector;
    screens: Selector;
    hide: Selector;
    unhide: Selector;
    set: Selector;
    arrowCursor: Selector;
    IBeamCursor: Selector;
    pointingHandCursor: Selector;
    openHandCursor: Selector;
    closedHandCursor: Selector;
    operationNotAllowedCursor: Selector;
    resizeLeftRightCursor: Selector;
    resizeUpDownCursor: Selector;
    _windowResizeNorthEastSouthWestCursor: Selector;
    // resizeAngle135Cursor: Selector;
    isInFullScreenMode: Selector;
    enterFullScreenMode_withOptions_: Selector;
    exitFullScreenModeWithOptions_: Selector;
    toggleFullScreen_: Selector;
    setCollectionBehavior_: Selector;
    setContentSize_: Selector;
    setFrameOrigin_: Selector;
    level: Selector;
    setLevel_: Selector;
    setValues_forParameter_: Selector;
    currentContext: Selector;
    view: Selector;
    arrayWithObjects_count_: Selector;
    URL: Selector;
    path: Selector;
    savePanel: Selector;
    openPanel: Selector;
    runModal: Selector;
    setShowsTagField_: Selector;
    showsTagField: Selector;
    setCanSelectHiddenExtension_: Selector;
    canSelectHiddenExtension: Selector;
    URLByDeletingLastPathComponent: Selector;
    hasDirectoryPath: Selector;
    setDirectoryURL_: Selector;
    directoryURL: Selector;
    setNameFieldStringValue_: Selector;
    nameFieldStringValue: Selector;
    lastPathComponent: Selector;
    allowedFileTypes: Selector;
    setAllowedFileTypes_: Selector;
    allowsOtherFileTypes: Selector;
    setAllowsOtherFileTypes_: Selector;
    alertStyle: Selector;
    setAlertStyle_: Selector;
    informativeText: Selector;
    setInformativeText_: Selector;
    messageText: Selector;
    setMessageText_: Selector;
    layout: Selector;
    accessoryView: Selector;
    setAccessoryView_: Selector;
    showsHelp: Selector;
    setShowsHelp_: Selector;
    addButtonWithTitle_: Selector;
    URLForDirectory_inDomain_appropriateForURL_create_error_: Selector;
    URLByAppendingPathComponent_: Selector;
    defaultManager: Selector;
    writeObjects_: Selector;
    size: Selector;
    setSize_: Selector;
    initWithBitmapDataPlanes_pixelsWide_pixelsHigh_bitsPerSample_samplesPerPixel_hasAlpha_isPlanar_colorSpaceName_bytesPerRow_bitsPerPixel_: Selector;
    bitmapData: Selector;
    initWithSize_: Selector;
    addRepresentation_: Selector;
    presentationOptions: Selector;
    setPresentationOptions_: Selector;
    containsObject_: Selector;
    objectAtIndex_: Selector;
    addItem_: Selector;
    initWithTitle_action_keyEquivalent_: Selector;
    setSubmenu_: Selector;
    terminate_: Selector;
    addItemWithTitle_action_keyEquivalent_: Selector;
    setAppleMenu_: Selector;
    detachNewThreadSelector_toTarget_withObject_: Selector;
    doNothing_: Selector;
    stop_: Selector;
    isMultiThreaded: Selector;
    layer: Selector;
    performClose_: Selector;
    close: Selector;
    buttonWithTitle_target_action_: Selector;
    mainBundle: Selector;
    resourcePath: Selector;
    requestUserAttention_: Selector;
    count: Selector;
    addObserver_selector_name_object_: Selector;
    defaultCenter: Selector;
    currentRunLoop: Selector;
    scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_: Selector;
    mouse_inRect_: Selector;
    convertRectFromScreen_: Selector;
    convertPointFromScreen_: Selector;
    convertPoint_fromView_: Selector;
    bounds: Selector;
    orderOut_: Selector;
    orderFront_: Selector;
    drawRect_: Selector;
    currentHost: Selector;
    localizedName: Selector;
}

_sel: _Generated_Selectors;

init_objective_c_runtime_constants :: () {
    if kCGBaseWindowLevel     return;

    {
        kCGBaseWindowLevel              = CGWindowLevelForKey(kCGBaseWindowLevelKey);
        kCGMinimumWindowLevel           = CGWindowLevelForKey(kCGMinimumWindowLevelKey);
        kCGDesktopWindowLevel           = CGWindowLevelForKey(kCGDesktopWindowLevelKey);
        kCGDesktopIconWindowLevel       = CGWindowLevelForKey(kCGDesktopIconWindowLevelKey);
        kCGBackstopMenuLevel            = CGWindowLevelForKey(kCGBackstopMenuLevelKey);
        kCGNormalWindowLevel            = CGWindowLevelForKey(kCGNormalWindowLevelKey);
        kCGFloatingWindowLevel          = CGWindowLevelForKey(kCGFloatingWindowLevelKey);
        kCGTornOffMenuWindowLevel       = CGWindowLevelForKey(kCGTornOffMenuWindowLevelKey);
        kCGDockWindowLevel              = CGWindowLevelForKey(kCGDockWindowLevelKey);
        kCGMainMenuWindowLevel          = CGWindowLevelForKey(kCGMainMenuWindowLevelKey);
        kCGStatusWindowLevel            = CGWindowLevelForKey(kCGStatusWindowLevelKey);
        kCGModalPanelWindowLevel        = CGWindowLevelForKey(kCGModalPanelWindowLevelKey);
        kCGPopUpMenuWindowLevel         = CGWindowLevelForKey(kCGPopUpMenuWindowLevelKey);
        kCGDraggingWindowLevel          = CGWindowLevelForKey(kCGDraggingWindowLevelKey);
        kCGScreenSaverWindowLevel       = CGWindowLevelForKey(kCGScreenSaverWindowLevelKey);
        kCGCursorWindowLevel            = CGWindowLevelForKey(kCGCursorWindowLevelKey);
        kCGOverlayWindowLevel           = CGWindowLevelForKey(kCGOverlayWindowLevelKey);
        kCGHelpWindowLevel              = CGWindowLevelForKey(kCGHelpWindowLevelKey);
        kCGUtilityWindowLevel           = CGWindowLevelForKey(kCGUtilityWindowLevelKey);
        kCGAssistiveTechHighWindowLevel = CGWindowLevelForKey(kCGAssistiveTechHighWindowLevelKey);
        kCGMaximumWindowLevel           = CGWindowLevelForKey(kCGMaximumWindowLevelKey);
    }
}

Cocoa   :: #system_library "Cocoa";
AppKit :: #system_library "AppKit";

// CoreFoundation :: #system_library "CoreFoundation";
// CoreGraphics :: #system_library "CoreGraphics";
Foundation_Framework :: #system_library "Foundation";

libobjc :: #system_library "libobjc";

libSystem :: #system_library "libSystem";

log2 :: (x: float64) -> float64 #foreign libc;
libc :: #system_library "libc";
c_free :: (memory: *void) #foreign libc "free";
