// :AwfulCopyPasta

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

NSProcessInfo :: struct {
    using nsobject: NSObject;
    _environment: *NSDictionary;
    _arguments: *NSArray(*NSString);
    _hostName: *NSString;
    _name: *NSString;
    automaticTerminationOptOutCounter: NSInteger;

    operatingSystem :: (self: *NSProcessInfo) -> NSUInteger {
        _func: (obj: *void, selector: Selector) -> NSUInteger #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.operatingSystem);
    }

    operatingSystemName :: (self: *NSProcessInfo) -> *NSString {
        _func: (obj: *void, selector: Selector) -> *NSString #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.operatingSystemName);
    }

    isOperatingSystemAtLeastVersion :: (self: *NSProcessInfo, version: NSOperatingSystemVersion) -> BOOL {
        _func: (obj: *void, selector: Selector, version: NSOperatingSystemVersion) -> BOOL #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.isOperatingSystemAtLeastVersion_, version);
    }

    disableSuddenTermination :: (self: *NSProcessInfo) -> () {
        _func: (obj: *void, selector: Selector) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, selectors.disableSuddenTermination);
    }

    enableSuddenTermination :: (self: *NSProcessInfo) -> () {
        _func: (obj: *void, selector: Selector) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, selectors.enableSuddenTermination);
    }

    disableAutomaticTermination :: (self: *NSProcessInfo, reason: *NSString) -> () {
        _func: (obj: *void, selector: Selector, reason: *NSString) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, selectors.disableAutomaticTermination_, reason);
    }

    enableAutomaticTermination :: (self: *NSProcessInfo, reason: *NSString) -> () {
        _func: (obj: *void, selector: Selector, reason: *NSString) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, selectors.enableAutomaticTermination_, reason);
    }

    processInfo :: () -> *NSProcessInfo {
        _func: (obj: *void, selector: Selector) -> *NSProcessInfo #foreign;
        _func = xx objc_msgSend;
        return _func(objc_getClass("NSProcessInfo"), selectors.processInfo);
    }

    environment :: (self: *NSProcessInfo) -> *NSDictionary {
        _func: (obj: *void, selector: Selector) -> *NSDictionary #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.environment);
    }

    arguments :: (self: *NSProcessInfo) -> *NSArray(*NSString) {
        _func: (obj: *void, selector: Selector) -> *NSArray(*NSString) #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.arguments);
    }

    hostName :: (self: *NSProcessInfo) -> *NSString {
        _func: (obj: *void, selector: Selector) -> *NSString #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.hostName);
    }

    processName :: (self: *NSProcessInfo) -> *NSString {
        _func: (obj: *void, selector: Selector) -> *NSString #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.processName);
    }

    setProcessName :: (self: *NSProcessInfo, processName: *NSString) -> () {
        _func: (obj: *void, selector: Selector, processName: *NSString) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, selectors.setProcessName_, processName);
    }

    processIdentifier :: (self: *NSProcessInfo) -> s32 {
        _func: (obj: *void, selector: Selector) -> s32 #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.processIdentifier);
    }

    globallyUniqueString :: (self: *NSProcessInfo) -> *NSString {
        _func: (obj: *void, selector: Selector) -> *NSString #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.globallyUniqueString);
    }

    operatingSystemVersionString :: (self: *NSProcessInfo) -> *NSString {
        _func: (obj: *void, selector: Selector) -> *NSString #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.operatingSystemVersionString);
    }

    operatingSystemVersion :: (self: *NSProcessInfo) -> NSOperatingSystemVersion {
        _func: (obj: *void, selector: Selector) -> NSOperatingSystemVersion #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.operatingSystemVersion);
    }

    processorCount :: (self: *NSProcessInfo) -> NSUInteger {
        _func: (obj: *void, selector: Selector) -> NSUInteger #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.processorCount);
    }

    activeProcessorCount :: (self: *NSProcessInfo) -> NSUInteger {
        _func: (obj: *void, selector: Selector) -> NSUInteger #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.activeProcessorCount);
    }

    physicalMemory :: (self: *NSProcessInfo) -> u64 {
        _func: (obj: *void, selector: Selector) -> u64 #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.physicalMemory);
    }

    systemUptime :: (self: *NSProcessInfo) -> NSTimeInterval {
        _func: (obj: *void, selector: Selector) -> NSTimeInterval #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.systemUptime);
    }

    automaticTerminationSupportEnabled :: (self: *NSProcessInfo) -> BOOL {
        _func: (obj: *void, selector: Selector) -> BOOL #foreign;
        _func = xx objc_msgSend;
        return _func(self, selectors.automaticTerminationSupportEnabled);
    }

    setAutomaticTerminationSupportEnabled :: (self: *NSProcessInfo, automaticTerminationSupportEnabled: BOOL) -> () {
        _func: (obj: *void, selector: Selector, automaticTerminationSupportEnabled: BOOL) -> () #foreign;
        _func = xx objc_msgSend;
        _func(self, selectors.setAutomaticTerminationSupportEnabled_, automaticTerminationSupportEnabled);
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

// External data declarations
// NSProcessInfoThermalStateDidChangeNotification: NSNotificationName;
// NSProcessInfoPowerStateDidChangeNotification: NSNotificationName;

init_objective_c_foundation :: () {
    if selectors.operatingSystem return;
    init_objective_c_selector_struct(*selectors);
}

#scope_file

_Generated_Selectors :: struct {
    operatingSystem: Selector;
    operatingSystemName: Selector;
    isOperatingSystemAtLeastVersion_: Selector;
    disableSuddenTermination: Selector;
    enableSuddenTermination: Selector;
    disableAutomaticTermination_: Selector;
    enableAutomaticTermination_: Selector;
    processInfo: Selector;
    environment: Selector;
    arguments: Selector;
    hostName: Selector;
    processName: Selector;
    setProcessName_: Selector;
    processIdentifier: Selector;
    globallyUniqueString: Selector;
    operatingSystemVersionString: Selector;
    operatingSystemVersion: Selector;
    processorCount: Selector;
    activeProcessorCount: Selector;
    physicalMemory: Selector;
    systemUptime: Selector;
    automaticTerminationSupportEnabled: Selector;
    setAutomaticTerminationSupportEnabled_: Selector;
}

selectors: _Generated_Selectors = ---;
