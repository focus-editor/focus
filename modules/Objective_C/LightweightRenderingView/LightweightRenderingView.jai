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

        swap_buffers(window);
    }
}

```
Example Usage (Metal)
--------------------------------------------------------------
```

```
 */

#import "Objective_C";

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

init_objective_c_lightweight_rendering_view :: () {
    if _sel.swapBuffers return;
    init_objective_c_selector_struct(*_sel);

    // @Hack use the class symbol for the OpenGL view so that the linker
    // allows this library to be statically linked correctly.
    __ensure_static_archive_of_library_is_fully_linked := __view_class_object;
    nothing := tprint("%", __view_class_object); // @Hack <- This is the line that rluba figured out to stop LLVM+Release from optimizing this class out of existence. -Don
    #import "Basic";
}

#scope_file

Selector_Struct :: struct {
    swapBuffers: Selector   = ---;
    setGlContext_: Selector = ---;
    glContext    : Selector = ---;
}

_sel: Selector_Struct;

__view_class_object :: () #foreign library "OBJC_CLASS_$_LightweightOpenGLView";

QuartzCore :: #system_library "QuartzCore"; // For CAMetalLayer

library :: #library "libLightweightRenderingView";
