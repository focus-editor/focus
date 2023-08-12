
#import "Objective_C";
#import "Objective_C/AppKit";
#import "Objective_C/GameController";
#import "Basic";
#import "Input";

#import "Gamepad";

AppDelegate :: struct {
    using delegate: NSApplicationDelegate;

    applicationWillTerminate :: (self: *AppDelegate, _sel: Selector, notification: *NSNotification) #c_call {

    } @selector(applicationWillTerminate:)

    applicationDidFinishLaunching :: (self: *AppDelegate, _sel: Selector, app: *NSApplication) #c_call {
        NSApplication.sharedApplication();

        NSApplication.setActivationPolicy(NSApp, NSApplicationActivationPolicyRegular);
        NSApplication.activateIgnoringOtherApps(NSApp, YES);

        ctx: Context;
        push_context ctx {
            NSTimer.scheduledTimerWithTimeInterval(1.0 / 60.0, self, selector("doNothing:"), null, YES);
        }
    }

    doNothing :: (using self: *AppDelegate, sel: Selector, obj: id) #c_call {
        ctx: Context;
        push_context ctx {
            // calling input_per_frame_event_and_flag_update instead of update_window_events because
            // update_window_events may be unreliable in reporting all events that occur if the Cocoa
            // loop has consumed and passed on some of our events already, I think.
            input_per_frame_event_and_flag_update();
            update_gamepad();

            // print("Gamepad: %\n", gamepad);
            for gamepad.buttons {
                print("BUTTON: %, %\n", cast(Gamepad_Code) it_index, it);
            }
        }
    } @selector(doNothing:)
}

Window_Delegate :: struct {
    using #as nswindowcontroller: NSWindowController;

    windowWillClose :: (using self: *Window_Delegate, _sel: Selector, notification: *NSNotification) #c_call {
        NSApp.terminate(NSApp, self);
    } @selector(windowWillClose:)
}

ViewController :: struct {
    using nsviewcontroller: NSViewController;
}

main :: () {
    init_objective_c();
    init_app_kit();
    pool := objc_init(objc_alloc(NSAutoreleasePool));
    defer NSAutoreleasePool.drain(pool);

    init_objc_classes_and_cocoa_app();

    init_gamepad();

    NSApplicationMain(xx __command_line_arguments.count, __command_line_arguments.data);
}


init_objc_classes_and_cocoa_app :: () {
    {
        // objc_create_class will setup an Objective-C Class object describing our struct.
        // Here we pass in the jai type of our class and its superclass. Struct member
        // variables will automatically be registered with the Objective-C runtime.
        ad_class := objc_create_class(AppDelegate, NSObject);
        // prot := objc_getProtocol("NSApplicationDelegate");
        // class_addProtocol(ad_class, prot);

        // We now register the instance methods with the selectors we want them to respond to.
        // This step could be automated in objc_create_class, but due to a compiler bug, we
        // cannot retrieve the runtime address of the functions from jai's type table.
        objc_add_instance_method(ad_class, AppDelegate.applicationWillTerminate, "applicationWillTerminate:");
        objc_add_instance_method(ad_class, AppDelegate.applicationDidFinishLaunching, "applicationDidFinishLaunching:");
        objc_add_instance_method(ad_class, AppDelegate.doNothing, "doNothing:");

        // objc_finalize_class will register the class with the Objective-C runtime. This makes the Class
        // object immutable, but from here we will be able to send Objective-C messages to our objects.
        objc_finalize_class(ad_class);
    }

    {
        wd_class := objc_create_class(Window_Delegate, NSWindowController);
        objc_add_instance_method(wd_class, Window_Delegate.windowWillClose, "windowWillClose:");
        objc_finalize_class(wd_class);
    }

    {
        vc_class := objc_create_class(ViewController, NSViewController);
        objc_finalize_class(vc_class);
    }
}



