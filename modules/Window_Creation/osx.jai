
#import "Objective_C";
#import "Objective_C/AppKit";
#import "Objective_C/LightweightRenderingView";

#scope_export

application_initialized := false;


init_mac_app :: () {
    if application_initialized return;

    init_objective_c();
    init_app_kit();
    init_lightweight_rendering_view();

    NSApplication.sharedApplication();

    // pool := objc_init(objc_alloc(NSAutoreleasePool));
    // dg.application_autorelease_pool = pool;

    #if #run macos_create_app_delegate_exists() { // :DecoupleWindowCreationAndInput:
        dg := context._macos_create_app_delegate();
        NSApplication.setDelegate(NSApp, dg);
    }

    menu_bar := objc_init(objc_alloc(NSMenu));
    autorelease(menu_bar);
    NSApp.setMainMenu(NSApp, menu_bar);

    S :: NSString.getTempString;

    app_menu_item := menu_bar.addItemWithTitle(menu_bar, S(""), null, S(""));
    autorelease(app_menu_item);

    app_menu := objc_init(objc_alloc(NSMenu));
    autorelease(app_menu);

    // @TODO we should probably override toggleFullScreen: in NSApplication in order to also set presentation options
    // like we do in toggle_fullscreen
    fullscreen_item := app_menu.addItemWithTitle(app_menu, S("Enter Full Screen"), selector("toggleFullScreen:"), S("f"));

    // Change keyboard shortcut for fullscreen to the standard Ctrl-Cmd-F (instead of the default Cmd-F)
    new_mask := NSEventModifierFlagControl | NSEventModifierFlagCommand;
    NSMenuItem.setKeyEquivalentModifierMask(fullscreen_item, new_mask);

    app_menu.addItemWithTitle(app_menu, S(tprint("Quit")), selector("terminate:"), S("q"));

    app_menu_item.setSubmenu(app_menu_item, app_menu);

    NSApplication.setAppleMenu(NSApp, app_menu);
    NSApplication.finishLaunching(NSApp);

    application_initialized = true;
}

// parent and background_color_rgb are not used on macOS, they just exists for API compatibility with the Windows & Linux versions.
create_window :: (width: int, height: int, window_name: string, window_x := 0, window_y := 0, parent: Window_Type = null, background_color_rgb := DEFAULT_WINDOW_CREATION_COLOR) -> *NSWindow {
    if !application_initialized init_mac_app();

    window := NSWindow.initWithContentRect(objc_alloc(NSWindow), NSMakeRect(xx window_x, xx window_y, cast(CGFloat) width, cast(CGFloat) height),
                NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable, NSBackingStoreBuffered, NO);

    // hmm... maybe it would be better if this wasnt kept in the autoreleasepool ?
    autorelease(window);
    NSWindow.setReleasedWhenClosed(window, NO);

    NSWindow.setTitle(window, window_name);

    #if #run macos_create_window_delegate_exists() { // :DecoupleWindowCreationAndInput:
        wd := context._macos_create_window_delegate();
        NSWindow.setDelegate(window, wd);
    }

    NSWindow.setCollectionBehavior(window, NSWindowCollectionBehaviorFullScreenPrimary | NSWindowCollectionBehaviorManaged);
    NSWindow.makeKeyAndOrderFront(window, null);

    {
        view := objc_init(objc_alloc(LightweightOpenGLView));
        NSView.setWantsLayer(view, YES);
        NSView.setWantsBestResolutionOpenGLSurface(view, YES);
        autorelease(view);

        NSWindow.setContentView(window, view);
        NSWindow.makeFirstResponder(window, view);
    }

    return window;
}

swap_buffers :: (win: *NSWindow) {
    view := NSWindow.contentView(win);
    if !view return;

    // The view must at least respond to the swapBuffers selector, in order to be compatible.
    LightweightRenderingView.swapBuffers(view);
}

get_dimensions :: (window: *NSWindow, right_handed: bool) -> (x: s32, y: s32, width: s32, height: s32, success := true) {
    // @ToDo: Shall we return pixels or screen units? (the former is usually 2x the latter on high-res displays)
    // We’re currently returning pixels (courtesy of convertRectToBacking)
    // Needs to be consistent with get_mouse_pointer_position, Input events, resize events, … :MacHighResDisplays
    view := NSWindow.contentView(window);
    frame := NSView.frame(view);
    fb := NSView.convertRectToBacking(view, frame); // :MacHighResDisplays

    y := ifx right_handed then fb.origin.y+fb.size.height else fb.origin.y;
    return cast(s32) fb.origin.x, cast(s32) y, cast(s32) fb.size.width, cast(s32) fb.size.height;
}


Saved_Window_Info :: struct {
    mask: NSWindowStyleMask;
    window_frame: NSRect;
}


toggle_fullscreen :: (win: *NSWindow, desire_fullscreen: bool, saved: *Saved_Window_Info) -> success: bool, width: s32, height: s32 {
    // @Cleanup: Why does the new code not use "saved"?
    view := NSWindow.contentView(win);
    frame := NSView.frame(view);

    mask := NSWindow.styleMask(win);
    if ((mask & NSWindowStyleMaskFullScreen) == NSWindowStyleMaskFullScreen) && desire_fullscreen return true, cast(s32) frame.size.width, cast(s32) frame.size.height;

    NSWindow.toggleFullScreen(win, win);

    if desire_fullscreen {
        // maybe preserve the current presentation options ?
        // pres := NSApp.presentationOptions(NSApp);
        NSApp.setPresentationOptions(NSApp, NSApplicationPresentationHideDock | NSApplicationPresentationHideMenuBar);
    } else {
        NSApp.setPresentationOptions(NSApp, NSApplicationPresentationDefault);
    }

    mask2 := NSWindow.styleMask(win);
    frame = NSView.frame(view);
    return (mask2 & NSWindowStyleMaskFullScreen) != (mask & NSWindowStyleMaskFullScreen), cast(s32) frame.size.width, cast(s32) frame.size.height;

    // Old code for pre OS 10.7:
    // if desire_fullscreen {
    //     saved.mask = NSWindow.styleMask(win);
    //     saved.window_frame = NSWindow.frame(win);

    //     NSWindow.setStyleMask(win, NSWindowStyleMaskBorderless);

    //     pt: NSPoint;
    //     NSWindow.setFrameOrigin(win, pt);

    //     screen := NSScreen.mainScreen();
    //     frame := NSScreen.frame(screen);
    //     NSWindow.setContentSize(win, frame.size);
    //     NSWindow.setLevel(win, kCGMainMenuWindowLevel+1);

    //     frame = NSView.frame(NSWindow.contentView(win));
    //     return true, cast(s32) frame.size.width, cast(s32) frame.size.height;
    // } else {
    //     NSWindow.setStyleMask(win, saved.mask);
    //     NSWindow.setFrame(win, saved.window_frame, YES);
    //     NSWindow.setLevel(win, kCGNormalWindowLevel);

    //     frame := NSView.frame(NSWindow.contentView(win));
    //     return true, cast(s32) frame.size.width, cast(s32) frame.size.height;
    // }
}

get_mouse_pointer_position :: (window: *NSWindow, right_handed: bool) -> x: int, y: int, success: bool {
    pt := NSWindow.mouseLocationOutsideOfEventStream(window);

    view := NSWindow.contentView(window);
    backing_pt := NSView.convertPointToBacking(view, pt); // :MacHighResDisplays

    if !right_handed {
        frame := NSView.frame(view);
        fb := NSView.convertRectToBacking(view, frame); // :MacHighResDisplays

        backing_pt.y = fb.size.height - backing_pt.y;
    }

    return cast(int) backing_pt.x, cast(int) backing_pt.y, true;
}

get_mouse_pointer_position :: inline (right_handed := false) -> x: int, y: int, success: bool {
    if !NSApp return 0, 0, false;

    win := NSApplication.keyWindow(NSApp);
    if !win return 0, 0, false;

    x, y, success := get_mouse_pointer_position(win, right_handed);
    return x, y, success;
}

#scope_file

macos_create_app_delegate_exists :: () -> bool { // :DecoupleWindowCreationAndInput:
    info := type_info(type_of(context));
    for info.members {
        if it.name == "_macos_create_app_delegate" {
            return true;
        }
    }

    return false;
}

macos_create_window_delegate_exists :: () -> bool { // :DecoupleWindowCreationAndInput:
    info := type_info(type_of(context));
    for info.members {
        if it.name == "_macos_create_window_delegate" {
            return true;
        }
    }

    return false;
}
