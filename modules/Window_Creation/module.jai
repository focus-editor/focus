// Platform-independent window creation routines.

#if OS == .WINDOWS {
    #load "windows.jai";
} else #if OS == .LINUX {
    #load "linux.jai";
} else #if OS == .MACOS {
    #load "osx.jai";
}

#scope_module

#import "Basic";

DEFAULT_WINDOW_CREATION_COLOR :: float.[.15,.15,.2];

#scope_export

// @CompilerBug: There is some kind of name importation problem that keeps happening,
// for example, Window_Type doesn't go through unless we do this weird WT thing.
// -jblow, 25 February 2021
WT :: #import "Window_Type";  // Define this for the people.
Window_Type :: WT.Window_Type;
INVALID_WINDOW :: WT.INVALID_WINDOW;
