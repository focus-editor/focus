// Separate module that needs to be imported as #import "Objective_C/AppKit"
// :AwfulCopyPasta

init_app_kit :: () {
    if !_sel.characters {
        init_objective_c_selector_struct(*_sel);
    }
    init_core_graphics_runtime_constants();
}

NSApp: *NSApplication #elsewhere;

NSApplicationMain :: (argc: s32, argv: **u8) -> s32 #foreign AppKit;

NSDefaultRunLoopMode:                  NSRunLoopMode #elsewhere Cocoa;
NSRunLoopCommonModes:                  NSRunLoopMode #elsewhere Cocoa;
NSDeviceRGBColorSpace:                 NSColorSpaceName #elsewhere AppKit;

NSApplicationDelegate :: struct {
    using #as nsobject: NSObject;
} @ObjCProtocol

NSApplication :: struct {
    using #as super: NSObject;

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

    postEvent :: (self: *NSApplication, event: *NSEvent, atStart: BOOL) #no_context {
        objc_msgSend(self, _sel.postEvent_atStart_, event, atStart);
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

    replyToOpenOrPrint :: (self: *NSApplication, reply: NSUInteger) #no_context {
        objc_msgSend(self, _sel.replyToOpenOrPrint_, reply);
    }
}



NSEvent :: struct {
    using #as super: NSObject;

    otherEventWithType :: (type: NSEventType, location: NSPoint, modifierFlags: NSEventModifierFlags, timestamp: NSTimeInterval, windowNumber: u64, ctx: *void, subtype: u16, data1: u64, data2: u64) -> *NSEvent #c_call {
        func: (*void, Selector, NSEventType, NSPoint, NSEventModifierFlags, NSTimeInterval, u64, *void, u16, u64, u64) -> *NSEvent #c_call;
        func = xx objc_msgSend;
        return xx func(
            class(NSEvent),
            _sel.otherEventWithType_location_modifierFlags_timestamp_windowNumber_context_subtype_data1_data2_,
            type, location, modifierFlags, timestamp, windowNumber, ctx, subtype, data1, data2);
    }

    window :: (self: *NSEvent) -> *NSWindow {
        return xx objc_msgSend(self, _sel.window);
    }

    mouseLocation :: () -> NSPoint {
        func: (*void, Selector) -> NSPoint #c_call;
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
        func: (self: *NSEvent, op: Selector) -> NSTimeInterval #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.keyRepeatDelay);
    }

    keyRepeatInterval :: (self: *NSEvent) -> NSTimeInterval {
        func: (self: *NSEvent, op: Selector) -> NSTimeInterval #c_call;
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
        func: (self: *void, op: Selector) -> CGFloat #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.deltaX);
    }

    deltaY :: (self: *NSEvent) -> CGFloat {
        func: (self: *void, op: Selector) -> CGFloat #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.deltaY);
    }

    deltaZ :: (self: *NSEvent) -> CGFloat {
        func: (self: *void, op: Selector) -> CGFloat #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.deltaZ);
    }

    scrollingDeltaX :: (self: *NSEvent) -> CGFloat {
        func: (self: *void, op: Selector) -> CGFloat #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.scrollingDeltaX);
    }

    scrollingDeltaY :: (self: *NSEvent) -> CGFloat {
        func: (self: *void, op: Selector) -> CGFloat #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.scrollingDeltaY);
    }

    hasPreciseScrollingDeltas :: (self: *NSEvent) -> BOOL {
        func: (self: *void, op: Selector) -> BOOL #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.hasPreciseScrollingDeltas);
    }

    phase :: (self: *NSEvent) -> NSEventPhase {
        func: (self: *void, op: Selector) -> NSEventPhase #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.phase);
    }

    momentumPhase :: (self: *NSEvent) -> NSEventPhase {
        func: (self: *void, op: Selector) -> NSEventPhase #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.momentumPhase);
    }
}

using NSEventPhase :: enum NSUInteger {
    NSEventPhaseNone       ::  0;
    NSEventPhaseBegan      ::  1;
    NSEventPhaseStationary ::  2;
    NSEventPhaseChanged    ::  4;
    NSEventPhaseEnded      ::  8;
    NSEventPhaseCancelled  :: 16;
    NSEventPhaseMayBegin   :: 32;
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

using NSBackingStoreType :: enum NSUInteger {
    NSBackingStoreRetained :: 0; @deprecated
    NSBackingStoreNonretained :: 1; @deprecated
    NSBackingStoreBuffered :: 2;
}

NSResponder :: struct {
    using #as super: NSObject;

    #insert #run,stallable create_objc_class_member_stub("NSResponder");
}

NSWindowController :: struct {
    using #as responder: NSResponder;

    #insert #run,stallable create_objc_class_member_stub("NSWindowController");
}

NSColor :: struct {
    using #as super: NSObject;

    blueColor :: () -> *NSColor {
        return xx objc_msgSend(class(NSColor), _sel.blueColor);
    }

    colorWithRed :: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> *NSColor {
        return xx objc_msgSend(class(NSColor), _sel.colorWithRed_green_blue_alpha_, red, green, blue, alpha);
    }
}

NSPasteboardReadingOptionKey :: *NSString;

NSPasteboardTypeString:                NSPasteboardType #elsewhere AppKit;
NSPasteboardTypePDF:                   NSPasteboardType #elsewhere AppKit;
NSPasteboardTypeTIFF:                  NSPasteboardType #elsewhere AppKit;
NSPasteboardTypePNG:                   NSPasteboardType #elsewhere AppKit;
NSPasteboardTypeRTF:                   NSPasteboardType #elsewhere AppKit;
NSPasteboardTypeRTFD:                  NSPasteboardType #elsewhere AppKit;
NSPasteboardTypeHTML:                  NSPasteboardType #elsewhere AppKit;
NSPasteboardTypeTabularText:           NSPasteboardType #elsewhere AppKit;
NSPasteboardTypeFont:                  NSPasteboardType #elsewhere AppKit;
NSPasteboardTypeRuler:                 NSPasteboardType #elsewhere AppKit;
NSPasteboardTypeColor:                 NSPasteboardType #elsewhere AppKit;
NSPasteboardTypeSound:                 NSPasteboardType #elsewhere AppKit;
NSPasteboardTypeMultipleTextSelection: NSPasteboardType #elsewhere AppKit;
NSPasteboardTypeTextFinderOptions:     NSPasteboardType #elsewhere AppKit;
NSPasteboardTypeURL:                   NSPasteboardType #elsewhere AppKit;
NSPasteboardTypeFileURL:               NSPasteboardType #elsewhere AppKit;

NSPasteboard :: struct {
    using #as super: NSObject;

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

    pasteboardItems :: (self: *NSPasteboard) -> *NSArray(*NSPasteboardItem) {
        return xx objc_msgSend(self, _sel.pasteboardItems);
    }

    readObjectsForClasses :: (self: *NSPasteboard, classes: *NSArray(Class), options: *NSDictionary(NSPasteboardReadingOptionKey, id), $T: Type) -> *NSArray(T) {
        return xx objc_msgSend(self, _sel.readObjectsForClasses_options_, classes, options);
    }
}

NSPasteboardItem :: struct {
    using #as super: NSObject;

    types :: (self: *NSPasteboardItem) -> *NSArray(NSPasteboardType) {
        return xx objc_msgSend(self, _sel.types);
    }

    stringForType :: (self: *NSPasteboardItem, dataType: NSPasteboardType) -> *NSString {
        return xx objc_msgSend(self, _sel.stringForType_, dataType);
    }
}

NSWindow :: struct {
    using #as responder: NSResponder;

    convertRectToBacking    :: NSView.convertRectToBacking;
    convertRectFromBacking  :: NSView.convertRectFromBacking;
    backingScaleFactor      :: NSView.backingScaleFactor;
    registerForDraggedTypes :: NSView.registerForDraggedTypes;

    initWithContentRect :: (self: *NSWindow, rect: NSRect, styleMask: NSWindowStyleMask, backing: NSBackingStoreType, _defer: BOOL) -> *NSWindow {
        return xx objc_msgSend(self, _sel.initWithContentRect_styleMask_backing_defer_, rect, styleMask, backing, _defer);
    }

    initWithContentRect :: (self: id, rect: NSRect, styleMask: NSWindowStyleMask, backing: NSBackingStoreType, _defer: BOOL, screen: *NSScreen) -> *NSWindow {
        return xx objc_msgSend(self, _sel.initWithContentRect_styleMask_backing_defer_screen_, rect, styleMask, backing, _defer, screen);
    }

    center :: (self: *NSWindow) {
        objc_msgSend(self, _sel.center);
    }

    frame :: NSView.frame;
    setFrame :: (self: *NSWindow, frame: NSRect, display: BOOL) {
        objc_msgSend(self, _sel.setFrame_display_, frame, display);
    }
    setFrame :: (self: *NSWindow, frame: NSRect, display: BOOL, animate: BOOL) {
        objc_msgSend(self, _sel.setFrame_display_animate_, frame, display, animate);
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
        func: (*void, Selector) -> NSPoint #c_call;
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
        func: (*void, Selector, NSRect) -> NSRect #c_call;
        func = xx objc_msgSend_stret;
        return func(self, _sel.convertRectFromScreen_, rect);
    }

    convertPointFromScreen :: (self: *NSWindow, point: NSPoint) -> NSPoint {
        func: (*void, Selector, NSPoint) -> NSPoint #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.convertPointFromScreen_, point);
    }

    orderOut :: (self: *NSWindow, sender: id) {
        func: (*NSWindow, Selector, id) #c_call;
        func = xx objc_msgSend;
        func(self, _sel.orderOut_, sender);
    }

    orderFront :: (self: *NSWindow, sender: id) {
        func: (*NSWindow, Selector, id) #c_call;
        func = xx objc_msgSend;
        func(self, _sel.orderFront_, sender);
    }

    toggleFullScreen :: (self: *NSWindow, sender: id) {
        objc_msgSend(self, _sel.toggleFullScreen_, sender);
    }

    screen :: (self: *NSWindow) -> *NSScreen {
        return xx objc_msgSend(self, _sel.screen);
    }

    setTitlebarAppearsTransparent :: (self: *NSWindow, value: BOOL) {
        objc_msgSend(self, _sel.setTitlebarAppearsTransparent_, value);
    }

    setAppearance :: (self: *NSWindow, appearance: *NSAppearance) {
        objc_msgSend(self, _sel.setAppearance_, appearance);
    }

    // helper functions
    setTitle :: (self: *NSWindow, title: string) -> id {
        nsstring := NSString.initWithString(objc_alloc(NSString), title);
        defer release(nsstring);

        return setTitle(self, nsstring);
    }

    maximize :: (self: *NSWindow) {
        visibleFrame := NSScreen.visibleFrame(screen(self));
        setFrame(self, visibleFrame, display=YES);
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
    using #as super: NSObject;

    addItem :: (self: *NSMenu, item: *NSMenuItem) {
        objc_msgSend(self, _sel.addItem_, item);
    }

    addItemWithTitle :: (self: *NSMenu, title: *NSString, action: Selector, keyEquivalent: *NSString) -> *NSMenuItem {
        return xx objc_msgSend(self, _sel.addItemWithTitle_action_keyEquivalent_, title, action, keyEquivalent);
    }
}

NSMenuItem :: struct {
    using #as super: NSObject;

    initWithTitle :: (self: *NSMenuItem, title: *NSString, action: Selector, keyEquivalent: *NSString) -> *NSMenuItem {
        return xx objc_msgSend(self, _sel.initWithTitle_action_keyEquivalent_, title, action, keyEquivalent);
    }

    setSubmenu :: (self: *NSMenuItem, sub: *NSMenu) {
        objc_msgSend(self, _sel.setSubmenu_, sub);
    }

    setKeyEquivalentModifierMask :: (self: *NSMenuItem, value: NSEventModifierFlags) {
        objc_msgSend(self, _sel.setKeyEquivalentModifierMask_, value);
    }

    keyEquivalentModifierMask :: (self: *NSMenuItem) -> NSEventModifierFlags {
        return xx objc_msgSend(self, _sel.keyEquivalentModifierMask);
    }
}

NSView :: struct {
    using #as super: NSObject;

    pad: [152 - size_of(NSObject)] u8; // NSView must be 152 bytes

    addSubView :: (self: *NSView, view: *NSView) {
        objc_msgSend(self, _sel.addSubView_, view);
    }

    setWantsLayer :: (self: id, yesno: BOOL) {
        objc_msgSend(self, _sel.setWantsLayer_, yesno);
    }

    frame :: (self: id) -> NSRect {
        func: (*void, Selector) -> NSRect #c_call;
        func = xx objc_msgSend_stret;
        return func(self, _sel.frame);
    }

    bounds :: (self: id) -> NSRect {
        func: (*void, Selector) -> NSRect #c_call;
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
        func: (*void, Selector, NSRect) -> NSRect #c_call;
        func = xx objc_msgSend_stret;
        return func(self, _sel.convertRectToBacking_, rect);
    }

    convertRectFromBacking :: (self: id, rect: NSRect) -> NSRect {
        func: (*void, Selector, NSRect) -> NSRect #c_call;
        func = xx objc_msgSend_stret;
        return func(self, _sel.convertRectFromBacking_, rect);
    }

    convertPointToBacking :: (self: id, point: NSPoint) -> NSPoint {
        func: (*void, Selector, NSPoint) -> NSPoint #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.convertPointToBacking_, point);
    }

    convertPointFromBacking :: (self: id, point: NSPoint) -> NSPoint {
        func: (*void, Selector, NSPoint) -> NSPoint #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.convertPointFromBacking_, point);
    }

    backingScaleFactor :: (self: id) -> CGFloat {
        func: (*void, Selector) -> CGFloat #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.backingScaleFactor);
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
        func: (*void, Selector, NSPoint, *NSView) -> NSPoint #c_call;
        func = xx objc_msgSend;
        return func(class(NSEvent), _sel.convertPoint_fromView_, point, fromView);
    }

    drawRect :: (self: id, dirtyRect: NSRect) {
        func: (*void, Selector, NSRect) #c_call;
        func = xx objc_msgSend;
        func(self, _sel.drawRect_, dirtyRect);
    }

    registerForDraggedTypes :: (self: id, newTypes: *NSArray(NSPasteboardType)) {
        objc_msgSend(self, _sel.registerForDraggedTypes_, newTypes);
    }
}

NSViewController :: struct {
    using #as responder: NSResponder;

    #insert #run,stallable create_objc_class_member_stub("NSViewController");
}

NSOpenGLContext :: struct {
    using #as super: NSObject;

    currentContext :: () -> *NSOpenGLContext {
        return xx objc_msgSend(class(NSOpenGLContext), _sel.currentContext);
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
    using #as super: NSObject;

    initWithAttributes :: (self: id, attrs: *NSOpenGLPixelFormatAttribute) -> *NSOpenGLPixelFormat {
        return xx objc_msgSend(self, _sel.initWithAttributes_, attrs);
    }
}

NSScreen :: struct {
    using #as super: NSObject;

    mainScreen :: () -> *NSScreen {
        return xx objc_msgSend(class(NSScreen), _sel.mainScreen);
    }

    frame              :: NSView.frame;
    backingScaleFactor :: NSView.backingScaleFactor;

    visibleFrame :: (self: *NSScreen) -> NSRect #c_call {
        func: (*void, Selector) -> NSRect #c_call;
        func = xx objc_msgSend_stret;
        return func(self, _sel.visibleFrame);
    }
}

NSCursor :: struct {
    using #as super: NSObject;

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

NSAlert :: struct {
    using #as super: NSObject;

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
    using #as view: NSView;

    buttonWithTitle :: (title: *NSString, target: id, action: Selector) -> *NSButton {
        return xx objc_msgSend(class(NSButton), _sel.buttonWithTitle_target_action_, title, target, action);
    }
}


NSImageRep :: struct {
    using #as super: NSObject;

    size :: (self: *NSImageRep) -> NSSize {
        func: (*void, Selector) -> NSSize #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.size);
    }

    setSize :: (self: *NSImageRep, size: NSSize) {
        objc_msgSend(self, _sel.setSize_, size);
    }
}

NSBitmapImageRep :: struct {
    using #as image_rep: NSImageRep;

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
    using #as super: NSObject;

    initWithSize :: (self: *NSImage, size: NSSize) -> *NSImage {
        return xx objc_msgSend(self, _sel.initWithSize_, size);
    }

    addRepresentation :: (self: *NSImage, rep: *NSImageRep) {
        objc_msgSend(self, _sel.addRepresentation_, rep);
    }
}


using NSDragOperation :: enum_flags NSUInteger {
    NSDragOperationNone    :: 0;
    NSDragOperationCopy    :: 1;
    NSDragOperationLink    :: 2;
    NSDragOperationGeneric :: 4;
    NSDragOperationPrivate :: 8;
    NSDragOperationMove    :: 16;
    NSDragOperationDelete  :: 32;
    NSDragOperationEvery   :: NSUIntegerMax;
}

NSDraggingInfo :: struct {
    draggingSourceOperationMask :: (self: id) -> NSDragOperation #no_context {
        return xx objc_msgSend(self, _sel.draggingSourceOperationMask);
    }

    draggingPasteboard :: (self: id) -> *NSPasteboard #no_context {
        return xx objc_msgSend(self, _sel.draggingPasteboard);
    }
}

NSAppearance :: struct {
    using #as super: NSObject;

    appearanceNamed :: (named: *NSString) -> *NSAppearance {
        return xx objc_msgSend(class(NSAppearance), _sel.appearanceNamed_, named);
    }
}

#scope_module

_sel: struct #type_info_no_size_complaint {
    appearanceNamed_: Selector;
    colorWithRed_green_blue_alpha_: Selector;
    setTitlebarAppearsTransparent_: Selector;
    setAppearance_: Selector;
    replyToOpenOrPrint_: Selector;
    characters: Selector;
    run: Selector;
    keyCode: Selector;
    modifierFlags: Selector;
    isARepeat: Selector;
    sharedApplication: Selector;
    mainWindow: Selector;
    sendEvent_: Selector;
    postEvent_atStart_: Selector;
    updateWindows: Selector;
    activateIgnoringOtherApps_: Selector;
    setActivationPolicy_: Selector;
    finishLaunching: Selector;
    setMainMenu_: Selector;
    nextEventMatchingMask_untilDate_inMode_dequeue_: Selector;
    blueColor: Selector;
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
    initWithContentRect_styleMask_backing_defer_screen_: Selector;
    makeFirstResponder_: Selector;
    addSubView_: Selector;
    setWantsLayer_: Selector;
    flushBuffer: Selector;
    setView_: Selector;
    initWithFormat_shareContext_: Selector;
    makeCurrentContext: Selector;
    initWithAttributes_: Selector;
    window: Selector;
    type: Selector;
    mouseLocation: Selector;
    generalPasteboard: Selector;
    setString_forType_: Selector;
    types: Selector;
    stringForType_: Selector;
    clearContents: Selector;
    keyRepeatDelay: Selector;
    keyRepeatInterval: Selector;
    pressedMouseButtons: Selector;
    deltaX: Selector;
    deltaY: Selector;
    deltaZ: Selector;
    scrollingDeltaX: Selector;
    scrollingDeltaY: Selector;
    hasPreciseScrollingDeltas: Selector;
    phase: Selector;
    momentumPhase: Selector;
    otherEventWithType_location_modifierFlags_timestamp_windowNumber_context_subtype_data1_data2_: Selector;
    associatedEventsMask: Selector;
    buttonNumber: Selector;
    clickCount: Selector;
    charactersIgnoringModifiers: Selector;
    mouseLocationOutsideOfEventStream: Selector;
    keyWindow: Selector;
    frame: Selector;
    setFrame_: Selector;
    setFrame_display_: Selector;
    setFrame_display_animate_: Selector;
    center: Selector;
    convertRectToBacking_: Selector;
    convertRectFromBacking_: Selector;
    convertPointToBacking_: Selector;
    convertPointFromBacking_: Selector;
    backingScaleFactor: Selector;
    visibleFrame: Selector;
    setWantsBestResolutionOpenGLSurface_: Selector;
    mainScreen: Selector;
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
    screen: Selector;
    setCollectionBehavior_: Selector;
    setContentSize_: Selector;
    setFrameOrigin_: Selector;
    level: Selector;
    setLevel_: Selector;
    setValues_forParameter_: Selector;
    currentContext: Selector;
    view: Selector;
    URL: Selector;
    savePanel: Selector;
    openPanel: Selector;
    runModal: Selector;
    setShowsTagField_: Selector;
    showsTagField: Selector;
    setCanSelectHiddenExtension_: Selector;
    canSelectHiddenExtension: Selector;
    setDirectoryURL_: Selector;
    directoryURL: Selector;
    setNameFieldStringValue_: Selector;
    nameFieldStringValue: Selector;
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
    writeObjects_: Selector;
    pasteboardItems: Selector;
    readObjectsForClasses_options_: Selector;
    size: Selector;
    setSize_: Selector;
    initWithBitmapDataPlanes_pixelsWide_pixelsHigh_bitsPerSample_samplesPerPixel_hasAlpha_isPlanar_colorSpaceName_bytesPerRow_bitsPerPixel_: Selector;
    bitmapData: Selector;
    initWithSize_: Selector;
    addRepresentation_: Selector;
    presentationOptions: Selector;
    setPresentationOptions_: Selector;
    addItem_: Selector;
    initWithTitle_action_keyEquivalent_: Selector;
    setSubmenu_: Selector;
    keyEquivalentModifierMask: Selector;
    setKeyEquivalentModifierMask_: Selector;
    terminate_: Selector;
    addItemWithTitle_action_keyEquivalent_: Selector;
    setAppleMenu_: Selector;
    doNothing_: Selector;
    stop_: Selector;
    layer: Selector;
    performClose_: Selector;
    close: Selector;
    buttonWithTitle_target_action_: Selector;
    requestUserAttention_: Selector;
    mouse_inRect_: Selector;
    convertRectFromScreen_: Selector;
    convertPointFromScreen_: Selector;
    convertPoint_fromView_: Selector;
    bounds: Selector;
    orderOut_: Selector;
    orderFront_: Selector;
    drawRect_: Selector;
    registerForDraggedTypes_: Selector;
    draggingSourceOperationMask: Selector;
    draggingPasteboard: Selector;
}

#import "Objective_C";
Cocoa   :: #system_library "Cocoa";
AppKit :: #system_library "AppKit";

#load "CoreGraphics.jai";

