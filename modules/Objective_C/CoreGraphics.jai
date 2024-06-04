init_core_graphics_runtime_constants :: () {
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


using CGWindowLevelKey :: enum s32 {
    kCGBaseWindowLevelKey :: 0;
    kCGMinimumWindowLevelKey;
    kCGDesktopWindowLevelKey;
    kCGBackstopMenuLevelKey;
    kCGNormalWindowLevelKey;
    kCGFloatingWindowLevelKey;
    kCGTornOffMenuWindowLevelKey;
    kCGDockWindowLevelKey;
    kCGMainMenuWindowLevelKey;
    kCGStatusWindowLevelKey;
    kCGModalPanelWindowLevelKey;
    kCGPopUpMenuWindowLevelKey;
    kCGDraggingWindowLevelKey;
    kCGScreenSaverWindowLevelKey;
    kCGMaximumWindowLevelKey;
    kCGOverlayWindowLevelKey;
    kCGHelpWindowLevelKey;
    kCGUtilityWindowLevelKey;
    kCGDesktopIconWindowLevelKey;
    kCGCursorWindowLevelKey;
    kCGAssistiveTechHighWindowLevelKey;
    kCGNumberOfWindowLevelKeys;
}

CGWindowLevelForKey :: (key: CGWindowLevelKey) -> CGWindowLevel #foreign CoreGraphics;

CGWindowLevel :: s32;


kCGBaseWindowLevel: CGWindowLevel;
kCGMinimumWindowLevel: CGWindowLevel;
kCGDesktopWindowLevel: CGWindowLevel;
kCGDesktopIconWindowLevel: CGWindowLevel;
kCGBackstopMenuLevel: CGWindowLevel;
kCGNormalWindowLevel: CGWindowLevel;
kCGFloatingWindowLevel: CGWindowLevel;
kCGTornOffMenuWindowLevel: CGWindowLevel;
kCGDockWindowLevel: CGWindowLevel;
kCGMainMenuWindowLevel: CGWindowLevel;
kCGStatusWindowLevel: CGWindowLevel;
kCGModalPanelWindowLevel: CGWindowLevel;
kCGPopUpMenuWindowLevel: CGWindowLevel;
kCGDraggingWindowLevel: CGWindowLevel;
kCGScreenSaverWindowLevel: CGWindowLevel;
kCGCursorWindowLevel: CGWindowLevel;
kCGOverlayWindowLevel: CGWindowLevel;
kCGHelpWindowLevel: CGWindowLevel;
kCGUtilityWindowLevel: CGWindowLevel;
kCGAssistiveTechHighWindowLevel: CGWindowLevel;
kCGMaximumWindowLevel: CGWindowLevel;

#scope_module

CoreGraphics :: #system_library "CoreGraphics";

