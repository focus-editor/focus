// :AwfulCopyPasta

init_objective_c_foundation :: () {
    if _sel.operatingSystem return;
    init_objective_c_selector_struct(*_sel);
}

NSTimeInterval :: float64;


NSFullUserName :: () -> *NSString #foreign Foundation_Framework;
NSUserName :: () -> *NSString #foreign Foundation_Framework;

NSHomeDirectory :: () -> *NSString #foreign Foundation_Framework;
NSHomeDirectoryForUser :: (username: *NSString) -> *NSString #foreign Foundation_Framework;

NSAutoreleasePool :: struct {
    using #as super: NSObject;

    drain :: (self: *NSAutoreleasePool) {
        objc_msgSend_typed(self, _sel.drain);
    }

    showPools :: () {
        objc_msgSend_typed(class(NSAutoreleasePool), _sel.showPools);
    }
}

NSRange :: struct {
    location: NSUInteger;
    length: NSUInteger;
}

NSBundle :: struct {
    using #as super: NSObject;

    resourcePath :: (self: *NSBundle) -> *NSString {
        return xx objc_msgSend_typed(self, _sel.resourcePath);
    }

    mainBundle :: () -> *NSBundle {
        return xx objc_msgSend_typed(class(NSBundle), _sel.mainBundle);
    }
}

NSDate :: struct {
    using #as super: NSObject;

    distantPast :: () -> *NSDate {
        return xx objc_msgSend_typed(class(NSDate), _sel.distantPast);
    }

    distantFuture :: () -> *NSDate {
        return xx objc_msgSend_typed(class(NSDate), _sel.distantFuture);
    }
}

NSPoint :: struct {
    x: CGFloat;
    y: CGFloat;
}

CGFloat :: float64; // float32 on 32-bit CPUs

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

NSStringEncoding :: NSUInteger;

NSUTF8StringEncoding  :: 4;
NSUTF32StringEncoding :: 0x8c000100;
NSUTF32LittleEndianStringEncoding :: 0x9c000100;

NSString :: struct {
    using #as super: NSObject;

    initWithBytes :: (self: *NSString, bytes: *void, length: NSUInteger, encoding: NSStringEncoding) -> *NSString {
        func :: #type (*void, Selector, *void, NSUInteger, NSStringEncoding) -> *NSString #c_call;
        return (cast(func) objc_msgSend)(self, _sel.initWithBytes_length_encoding_, bytes, length, encoding);
    }

    UTF8String :: (self: *NSString) -> *u8 {
        return xx objc_msgSend_typed(self, _sel.UTF8String);
    }

    dataUsingEncoding :: (self: *NSString, encoding: NSStringEncoding, allowLossyConversion := NO) -> *NSData {
        func: (*void, Selector, NSStringEncoding, BOOL) -> *NSData #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.dataUsingEncoding_allowLossyConversion_, encoding, allowLossyConversion);
    }

    stringByExpandingTildeInPath :: (self: *NSString) -> *NSString {
        return xx objc_msgSend_typed(self, _sel.stringByExpandingTildeInPath);
    }

    length :: (self: *NSString) -> NSUInteger {
        return xx objc_msgSend_typed(self, _sel.length);
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

    // Added for Focus
    characterAtIndex :: (self: *NSString, at: int) -> u16 {
        func :: #type (*void, Selector, int) -> u16 #c_call;
        return (cast(func) objc_msgSend)(self, _sel.characterAtIndex_, at);
    }
}

NSRunLoopMode    :: *NSString;
NSPasteboardType :: *NSString;
NSColorSpaceName :: *NSString;



NSWindowsNTOperatingSystem :: 1;
NSWindows95OperatingSystem :: 2;
NSSolarisOperatingSystem :: 3;
NSHPUXOperatingSystem :: 4;
NSMACHOperatingSystem :: 5;
NSSunOSOperatingSystem :: 6;
NSOSF1OperatingSystem :: 7;

NSOperatingSystemVersion :: struct {
    majorVersion: NSInteger;
    minorVersion: NSInteger;
    patchVersion: NSInteger;
}

NSTimer :: struct {
    using #as super: NSObject;

    scheduledTimerWithTimeInterval :: (interval: NSTimeInterval, target: id, selector: Selector, userInfo: id, repeats: BOOL) -> *NSTimer {
        func :: #type (*void, Selector, NSTimeInterval, id, Selector, id, BOOL) -> *NSTimer #c_call;
        return (cast(func) objc_msgSend)(class(NSTimer), _sel.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_, interval, target, selector, userInfo, repeats);
    }

    // Added for Focus
    invalidate :: (self: *NSTimer) {
        objc_msgSend_typed(self, _sel.invalidate);
    }
}

NSRunLoop :: struct {
    using #as super: NSObject;

    currentRunLoop :: () -> *NSRunLoop {
        return xx objc_msgSend_typed(objc_getClass("NSRunLoop"), _sel.currentRunLoop);
    }

    run :: (self: *NSRunLoop) {
        objc_msgSend_typed(self, _sel.run);
    }

    // Added for Focus
    addTimer :: (self: *NSRunLoop, timer: *NSTimer, run_mode: NSRunLoopMode) {
        func :: #type (*void, Selector, *NSTimer, NSRunLoopMode) #c_call;
        (cast(func) objc_msgSend)(self, _sel.addTimer_forMode_, timer, run_mode);
    }
}



NSProcessInfo :: struct {
    using nsobject: NSObject;
    _environment: *NSDictionary(*NSString, *NSString);
    _arguments: *NSArray(*NSString);
    _hostName: *NSString;
    _name: *NSString;
    automaticTerminationOptOutCounter: NSInteger;

    operatingSystem :: (self: *NSProcessInfo) -> NSUInteger {
        return xx objc_msgSend_typed(self, _sel.operatingSystem);
    }

    operatingSystemName :: (self: *NSProcessInfo) -> *NSString {
        return xx objc_msgSend_typed(self, _sel.operatingSystemName);
    }

    isOperatingSystemAtLeastVersion :: (self: *NSProcessInfo, version: NSOperatingSystemVersion) -> BOOL {
        func :: #type (*void, Selector, NSOperatingSystemVersion) -> BOOL #c_call;
        return (cast(func) objc_msgSend)(self, _sel.isOperatingSystemAtLeastVersion_, version);
    }

    disableSuddenTermination :: (self: *NSProcessInfo) -> () {
        _func: (obj: *void, selector: Selector) -> () #c_call;
        _func = xx objc_msgSend_typed;
        _func(self, _sel.disableSuddenTermination);
    }

    enableSuddenTermination :: (self: *NSProcessInfo) -> () {
        _func: (obj: *void, selector: Selector) -> () #c_call;
        _func = xx objc_msgSend_typed;
        _func(self, _sel.enableSuddenTermination);
    }

    disableAutomaticTermination :: (self: *NSProcessInfo, reason: *NSString) -> () {
        _func: (obj: *void, selector: Selector, reason: *NSString) -> () #c_call;
        _func = xx objc_msgSend_typed;
        _func(self, _sel.disableAutomaticTermination_, reason);
    }

    enableAutomaticTermination :: (self: *NSProcessInfo, reason: *NSString) -> () {
        _func: (obj: *void, selector: Selector, reason: *NSString) -> () #c_call;
        _func = xx objc_msgSend_typed;
        _func(self, _sel.enableAutomaticTermination_, reason);
    }

    processInfo :: () -> *NSProcessInfo {
        _func: (obj: *void, selector: Selector) -> *NSProcessInfo #c_call;
        _func = xx objc_msgSend_typed;
        return _func(objc_getClass("NSProcessInfo"), _sel.processInfo);
    }

    environment :: (self: *NSProcessInfo) -> *NSDictionary {
        _func: (obj: *void, selector: Selector) -> *NSDictionary #c_call;
        _func = xx objc_msgSend_typed;
        return _func(self, _sel.environment);
    }

    arguments :: (self: *NSProcessInfo) -> *NSArray(*NSString) {
        _func: (obj: *void, selector: Selector) -> *NSArray(*NSString) #c_call;
        _func = xx objc_msgSend_typed;
        return _func(self, _sel.arguments);
    }

    hostName :: (self: *NSProcessInfo) -> *NSString {
        _func: (obj: *void, selector: Selector) -> *NSString #c_call;
        _func = xx objc_msgSend_typed;
        return _func(self, _sel.hostName);
    }

    processName :: (self: *NSProcessInfo) -> *NSString {
        _func: (obj: *void, selector: Selector) -> *NSString #c_call;
        _func = xx objc_msgSend_typed;
        return _func(self, _sel.processName);
    }

    setProcessName :: (self: *NSProcessInfo, processName: *NSString) -> () {
        _func: (obj: *void, selector: Selector, processName: *NSString) -> () #c_call;
        _func = xx objc_msgSend_typed;
        _func(self, _sel.setProcessName_, processName);
    }

    processIdentifier :: (self: *NSProcessInfo) -> s32 {
        _func: (obj: *void, selector: Selector) -> s32 #c_call;
        _func = xx objc_msgSend_typed;
        return _func(self, _sel.processIdentifier);
    }

    globallyUniqueString :: (self: *NSProcessInfo) -> *NSString {
        _func: (obj: *void, selector: Selector) -> *NSString #c_call;
        _func = xx objc_msgSend_typed;
        return _func(self, _sel.globallyUniqueString);
    }

    operatingSystemVersionString :: (self: *NSProcessInfo) -> *NSString {
        _func: (obj: *void, selector: Selector) -> *NSString #c_call;
        _func = xx objc_msgSend_typed;
        return _func(self, _sel.operatingSystemVersionString);
    }

    operatingSystemVersion :: (self: *NSProcessInfo) -> NSOperatingSystemVersion {
        _func: (obj: *void, selector: Selector) -> NSOperatingSystemVersion #c_call;
        _func = xx objc_msgSend_typed;
        return _func(self, _sel.operatingSystemVersion);
    }

    processorCount :: (self: *NSProcessInfo) -> NSUInteger {
        _func: (obj: *void, selector: Selector) -> NSUInteger #c_call;
        _func = xx objc_msgSend_typed;
        return _func(self, _sel.processorCount);
    }

    activeProcessorCount :: (self: *NSProcessInfo) -> NSUInteger {
        _func: (obj: *void, selector: Selector) -> NSUInteger #c_call;
        _func = xx objc_msgSend_typed;
        return _func(self, _sel.activeProcessorCount);
    }

    physicalMemory :: (self: *NSProcessInfo) -> u64 {
        _func: (obj: *void, selector: Selector) -> u64 #c_call;
        _func = xx objc_msgSend_typed;
        return _func(self, _sel.physicalMemory);
    }

    systemUptime :: (self: *NSProcessInfo) -> NSTimeInterval {
        _func: (obj: *void, selector: Selector) -> NSTimeInterval #c_call;
        _func = xx objc_msgSend_typed;
        return _func(self, _sel.systemUptime);
    }

    automaticTerminationSupportEnabled :: (self: *NSProcessInfo) -> BOOL {
        _func: (obj: *void, selector: Selector) -> BOOL #c_call;
        _func = xx objc_msgSend_typed;
        return _func(self, _sel.automaticTerminationSupportEnabled);
    }

    setAutomaticTerminationSupportEnabled :: (self: *NSProcessInfo, automaticTerminationSupportEnabled: BOOL) -> () {
        _func: (obj: *void, selector: Selector, automaticTerminationSupportEnabled: BOOL) -> () #c_call;
        _func = xx objc_msgSend_typed;
        _func(self, _sel.setAutomaticTerminationSupportEnabled_, automaticTerminationSupportEnabled);
    }

}

using NSActivityOptions :: enum u64 {
    NSActivityIdleDisplaySleepDisabled :: 1099511627776;
    NSActivityIdleSystemSleepDisabled :: 1048576;
    NSActivitySuddenTerminationDisabled :: 16384;
    NSActivityAutomaticTerminationDisabled :: 32768;
    NSActivityUserInitiated :: 16777215;
    NSActivityUserInitiatedAllowingIdleSystemSleep :: 15728639;
    NSActivityBackground :: 255;
    NSActivityLatencyCritical :: 1095216660480;
}



using NSProcessInfoThermalState :: enum NSInteger {
    NSProcessInfoThermalStateNominal :: 0;
    NSProcessInfoThermalStateFair :: 1;
    NSProcessInfoThermalStateSerious :: 2;
    NSProcessInfoThermalStateCritical :: 3;
}

NSThread :: struct {
    _nsobject: NSObject;

    detachNewThreadSelectorToTargetWithObject :: (sel: Selector, toTarget: id, withObject: id) {
        func :: #type (*void, Selector, Selector, id, id) -> void #c_call;
        (cast(func) objc_msgSend)(class(NSThread), _sel.detachNewThreadSelector_toTarget_withObject_, sel, toTarget, withObject);
    }

    isMultiThreaded :: () -> BOOL {
        return xx objc_msgSend_typed(class(NSThread), _sel.isMultiThreaded);
    }
}

NSNotification :: struct {
    using #as super: NSObject;

    object :: (self: *NSNotification) -> *NSObject {
        return xx objc_msgSend_typed(self, _sel.object);
    }
}

NSNotificationCenter :: struct {
    using #as super: NSObject;

    defaultCenter :: () -> *NSNotificationCenter {
        return xx objc_msgSend_typed(objc_getClass("NSNotificationCenter"), _sel.defaultCenter);
    }


    addObserver :: (self: *NSNotificationCenter, observer: id, selector: Selector, name: NSNotificationName, object: id) {
        func :: #type (*void, Selector, id, Selector, NSNotificationName, id) -> void #c_call;
        (cast(func) objc_msgSend)(self, _sel.addObserver_selector_name_object_, observer, selector, name, object);
    }
}

NSNotificationName :: *NSString;

NSURL :: struct {
    using #as super: NSObject;

    URLWithString :: (str: *NSString) -> *NSURL {
        func :: #type (*void, Selector, *NSString) -> *NSURL #c_call;
        return (cast(func) objc_msgSend)(class(NSURL), _sel.URLWithString_, str);
    }

    fileURLWithPath :: (path: *NSString) -> *NSURL {
        func :: #type (*void, Selector, *NSString) -> *NSURL #c_call;
        return (cast(func) objc_msgSend)(class(NSURL), _sel.fileURLWithPath_, path);
    }

    fileURLWithPath :: (path: *NSString, isDirectory: BOOL) -> *NSURL {
        func :: #type (*void, Selector, *NSString, BOOL) -> *NSURL #c_call;
        return (cast(func) objc_msgSend)(class(NSURL), _sel.fileURLWithPath_isDirectory_, path, isDirectory);
    }

    // instance
    path :: (self: *NSURL) -> *NSString {
        return xx objc_msgSend_typed(self, _sel.path);
    }

    URLByDeletingLastPathComponent :: (self: *NSURL) -> *NSURL {
        return xx objc_msgSend_typed(self, _sel.URLByDeletingLastPathComponent);
    }

    hasDirectoryPath :: (self: *NSURL) -> BOOL {
        return xx objc_msgSend_typed(self, _sel.hasDirectoryPath);
    }

    URLByAppendingPathComponent :: (self: *NSURL, comp: *NSString) -> *NSURL {
        func: (*void, Selector, *NSString) -> *NSURL #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.URLByAppendingPathComponent_, comp);
    }

    lastPathComponent :: (self: *NSURL) -> *NSString {
        return xx objc_msgSend_typed(self, _sel.lastPathComponent);
    }
}

NSData :: struct {
    using #as super: NSObject;

    bytes :: (self: *NSData) -> *void {
        return xx objc_msgSend_typed(self, _sel.bytes);
    }

    length :: (self: *NSData) -> NSUInteger {
        return xx objc_msgSend_typed(self, _sel.length);
    }
}

NSDictionary :: struct (key: Type, value: Type) {
    using #as super: NSObject;
}

NSArray :: struct (Object_Type: Type) {
    using #as super: NSObject;

    // static
    arrayWithObject :: (obj: Object_Type) -> *NSArray(Object_Type) {
        func :: #type (*void, Selector, Object_Type) -> *NSArray(Object_Type) #c_call;
        return (cast(func) objc_msgSend)(objc_getClass("NSArray"), _sel.arrayWithObject_, obj);
    }
    arrayWithObjects :: (objs: *Object_Type, count: NSUInteger) -> *NSArray(Object_Type) {
        func :: #type (*void, Selector, *Object_Type, NSUInteger) -> *NSArray(Object_Type) #c_call;
        return (cast(func) objc_msgSend)(objc_getClass("NSArray"), _sel.arrayWithObjects_count_, objs, count);
    }

    // instance

    // @Cleanup it would be nice if we had light generics so that only one version of these functions is generated
    // when NSArray is instantiated with several different types
    containsObject :: (self: *NSArray(Object_Type), anObject: Object_Type) -> BOOL {
        func :: #type (*void, Selector, Object_Type) -> BOOL #c_call;
        return (cast(func) objc_msgSend)(self, _sel.containsObject_, anObject);
    }

    objectAtIndex :: (self: *NSArray(Object_Type), index: NSUInteger) -> Object_Type {
        func :: #type (*void, Selector, NSUInteger) -> Object_Type #c_call;
        return (cast(func) objc_msgSend)(self, _sel.objectAtIndex_, index);
    }

    count :: (self: *NSArray(Object_Type)) -> NSUInteger {
        return xx objc_msgSend_typed(self, _sel.count);
    }
}

NSFileManager :: struct {
    using #as super: NSObject;

    defaultManager :: () -> *NSFileManager {
        return xx objc_msgSend_typed(class(NSFileManager), _sel.defaultManager);
    }

    // instance
    // MACOS 10.6+
    URLForDirectory :: (self: *NSFileManager, dir: NSSearchPathDirectory, inDomain: NSSearchPathDomainMask, appropriateForURL: *NSURL, create: BOOL, error: **NSError) -> *NSURL {
        func: (*void, Selector, NSSearchPathDirectory, NSSearchPathDomainMask, *NSURL, BOOL, **NSError) -> *NSURL #c_call;
        func = xx objc_msgSend;
        return func(self, _sel.URLForDirectory_inDomain_appropriateForURL_create_error_, dir, inDomain, appropriateForURL, create, error);
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
    NSAutosavedInformationDirectory :: 11;
    NSDesktopDirectory :: 12;
    NSCachesDirectory :: 13;
    NSApplicationSupportDirectory :: 14;
    NSDownloadsDirectory :: 15;
    NSInputMethodsDirectory :: 16;
    NSMoviesDirectory :: 17;
    NSMusicDirectory :: 18;
    NSPicturesDirectory :: 19;
    NSPrinterDescriptionDirectory :: 20;
    NSSharedPublicDirectory :: 21;
    NSPreferencePanesDirectory :: 22;
    NSApplicationScriptsDirectory :: 23;
    NSItemReplacementDirectory :: 99;
    NSAllApplicationsDirectory :: 100;
    NSAllLibrariesDirectory :: 101;
    NSTrashDirectory :: 102;
}

using NSSearchPathDomainMask :: enum_flags NSUInteger {
    NSUserDomainMask :: 1;
    NSLocalDomainMask :: 2;
    NSNetworkDomainMask :: 4;
    NSSystemDomainMask :: 8;
    NSAllDomainsMask :: 0x0ffff;
}

NSError :: struct {
    using #as super: NSObject;

    localizedDescription :: (self: *NSError) -> *NSString {
        return xx objc_msgSend_typed(self, _sel.localizedDescription);
    }
}

NSHost :: struct {
    using #as super: NSObject;

    currentHost :: () -> *NSHost {
        return xx objc_msgSend_typed(objc_getClass("NSHost"), _sel.currentHost);
    }

    localizedName :: (self: *NSHost) -> *NSString {
        return xx objc_msgSend_typed(self, _sel.localizedName);
    }
}


CALayer :: struct {
    using nsobject: NSObject;
}




// External data declarations
// NSProcessInfoThermalStateDidChangeNotification: NSNotificationName;
// NSProcessInfoPowerStateDidChangeNotification: NSNotificationName;

#scope_module

Foundation_Framework :: #system_library "Foundation";

#scope_file

_sel: struct {
    drain:                                                            Selector;
    showPools:                                                        Selector;
    resourcePath:                                                     Selector;
    mainBundle:                                                       Selector;
    distantPast:                                                      Selector;
    distantFuture:                                                    Selector;
    initWithBytes_length_encoding_:                                   Selector;
    UTF8String:                                                       Selector;
    dataUsingEncoding_allowLossyConversion_:                          Selector;
    stringByExpandingTildeInPath:                                     Selector;
    scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_: Selector;
    currentRunLoop:                                                   Selector;
    run:                                                              Selector;
    operatingSystem:                                                  Selector;
    operatingSystemName:                                              Selector;
    isOperatingSystemAtLeastVersion_:                                 Selector;
    disableSuddenTermination:                                         Selector;
    enableSuddenTermination:                                          Selector;
    disableAutomaticTermination_:                                     Selector;
    enableAutomaticTermination_:                                      Selector;
    processInfo:                                                      Selector;
    environment:                                                      Selector;
    arguments:                                                        Selector;
    hostName:                                                         Selector;
    processName:                                                      Selector;
    setProcessName_:                                                  Selector;
    processIdentifier:                                                Selector;
    globallyUniqueString:                                             Selector;
    operatingSystemVersionString:                                     Selector;
    operatingSystemVersion:                                           Selector;
    processorCount:                                                   Selector;
    activeProcessorCount:                                             Selector;
    physicalMemory:                                                   Selector;
    systemUptime:                                                     Selector;
    automaticTerminationSupportEnabled:                               Selector;
    setAutomaticTerminationSupportEnabled_:                           Selector;
    detachNewThreadSelector_toTarget_withObject_:                     Selector;
    isMultiThreaded:                                                  Selector;
    object:                                                           Selector;
    defaultCenter:                                                    Selector;
    addObserver_selector_name_object_:                                Selector;
    URLWithString_:                                                   Selector;
    fileURLWithPath_:                                                 Selector;
    fileURLWithPath_isDirectory_:                                     Selector;
    path:                                                             Selector;
    URLByDeletingLastPathComponent:                                   Selector;
    hasDirectoryPath:                                                 Selector;
    URLByAppendingPathComponent_:                                     Selector;
    lastPathComponent:                                                Selector;
    bytes:                                                            Selector;
    length:                                                           Selector;
    arrayWithObject_:                                                 Selector;
    arrayWithObjects_count_:                                          Selector;
    containsObject_:                                                  Selector;
    objectAtIndex_:                                                   Selector;
    count:                                                            Selector;
    defaultManager:                                                   Selector;
    URLForDirectory_inDomain_appropriateForURL_create_error_:         Selector;
    currentHost:                                                      Selector;
    localizedName:                                                    Selector;
    localizedDescription:                                             Selector;

    // Added for Focus
    characterAtIndex_:                                                Selector;
    invalidate:                                                       Selector;
    addTimer_forMode_:                                                Selector;
}
