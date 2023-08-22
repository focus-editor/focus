// This module defines the Window_Type used by Windows/X11/etc.
// You only need to include it if you want to define Window_Type and
// you are not using one of the Windows-type modules directly.

#if OS == .WINDOWS {
    #scope_module;
    Windows :: #import "Windows";
    #scope_export;
    Window_Type :: Windows.HWND;
    INVALID_WINDOW : Window_Type : null;
} else #if OS == .LINUX {
    #scope_module;
    LD :: #import "Linux_Display";
    #scope_export;
    Window_Type :: *LD.Window;
    INVALID_WINDOW :: LD.INVALID_WINDOW;
} else #if OS == .MACOS {
    #scope_module;
    ObjC :: #import "Objective_C/AppKit";
    #scope_export;
    Window_Type :: *ObjC.NSWindow;
    INVALID_WINDOW : Window_Type : null;
}
