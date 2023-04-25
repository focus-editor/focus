CoreGraphics :: #system_library "CoreGraphics";

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

// initialized in init_mac_app()
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
