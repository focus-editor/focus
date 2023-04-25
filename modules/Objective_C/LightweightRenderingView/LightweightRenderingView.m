
#include "LightweightRenderingView.h"

#import <QuartzCore/CAMetalLayer.h>

@implementation LightweightOpenGLView

-(void)swapBuffers {
    [super swapBuffers];

    if (gl_context) {
        [gl_context update];
        [gl_context flushBuffer];
    }
}

@synthesize glContext = gl_context;

-(void)drawRect: (NSRect)rect {
    if (gl_context) {
        [gl_context update];
    }
}

@end

@implementation LightweightRenderingView

-(void)swapBuffers {
}

-(CALayer *)makeBackingLayer {
    return [[CAMetalLayer alloc] init];
}

-(BOOL)isOpaque {
    return YES;
}

-(BOOL)canBecomeKeyView {
    return YES;
}

-(BOOL)acceptsFirstResponder {
    return YES;
}

-(BOOL)wantsLayer {
    return YES;
}

-(BOOL)wantsUpdateLayer {
    return YES;
}

-(void)keyDown: (NSEvent *)theEvent {
    // do nothing
}

@end