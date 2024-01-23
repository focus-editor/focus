/*

Very lightweight Cocoa views with support for tracking graphics contexts.

These are implemented in Objective-C in order to avoid the fragile-ivar problem.

Example Usage (OpenGL)
--------------------------------------------------------------
```
#import "Objective_C";


// OpenGL
#import "GL";

manually_setup_opengl_view_and_context :: (window: *NSWindow) -> *LightweightOpenGLView {
    gl_view := objc_init(objc_alloc(LightweightOpenGLView));
    autorelease(gl_view);

    gl_view.setWantsLayer(gl_view, YES);

    gl_context := nsgl_create_context(3, 2);
    autorelease(gl_context);

    // Set the glContext property to be tracked by the view.
    gl_view.setGlContext(gl_view, gl_context);

    gl_context.setView(gl_context, gl_view);

    window.setContentView(window, gl_view);

    return gl_view;
}

do_opengl_program :: () {
    window := create_window(...);

    view := manually_setup_opengl_view_and_context(window);

    while true {
        // ...

        glClear(GL_COLOR_BUFFER_BIT);
        // ...

        view.swapBuffers(view);
    }
}

```
The above code is for illustration purposes. The [GL](#gl) and [Window_Creation](#window_creation) modules
provide the same functionality via a simpler API, as shown below.
```
#import "GL";
#import "Window_Creation";

do_opengl_program :: () {
    window := create_window(...);
    gl_create_context(window, 3, 2);

    while true {
        // ...

        glClear(GL_COLOR_BUFFER_BIT);
        // ...

        swap_view_buffers(window);
    }
}

```
Example Usage (Metal)
--------------------------------------------------------------
```

```
 */

#import "Objective_C";
#import "Objective_C/AppKit";

LightweightRenderingView :: struct {
    #as using nsview: NSView;

    swapBuffers :: (self: *void) {
        objc_msgSend(self, _sel.swapBuffers);
    }
}

LightweightOpenGLView :: struct {
    #as using lightweightrenderingview: LightweightRenderingView;

    glContext :: (self: *LightweightOpenGLView) -> *NSOpenGLContext {
        return xx objc_msgSend(self, _sel.glContext);
    }

    setGlContext :: (self: *LightweightOpenGLView, glc: *NSOpenGLContext) {
        objc_msgSend(self, _sel.setGlContext_, glc);
    }
}

LightweightMetalView :: struct {
    using lightweightrenderingview: LightweightRenderingView;
}

init_lightweight_rendering_view :: () {
    if _sel.swapBuffers return;
    init_objective_c_selector_struct(*_sel);

    // @Hack use the class symbol for the OpenGL view so that the linker
    // allows this library to be statically linked correctly. :ObjectiveCClassSymbol:
    // Extra-@Hack: Make sure this symbol reference isn’t stripped in release builds!
    nothing := Basic.tprint("%", __view_class_object);
}

#scope_file

_sel: struct {
    swapBuffers:   Selector;
    setGlContext_: Selector;
    glContext:     Selector;
}

// Reference the symbol for the LightweightOpenGLView Objective-C class from the library.
// @Stability: This only works on DEBUG builds! The compiler will still strip this in release builds unless we use it for something.
// :ObjectiveCClassSymbol:
//  -rluba, 2023-04-24
__view_class_object: *void #elsewhere library "OBJC_CLASS_$_LightweightOpenGLView";

QuartzCore :: #system_library "QuartzCore"; // For CAMetalLayer

library :: #library "libLightweightRenderingView";

Basic :: #import "Basic"; // Only the :ObjectiveCClassSymbol: hack
