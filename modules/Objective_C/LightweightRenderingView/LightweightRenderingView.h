
#import <AppKit/AppKit.h>

@interface LightweightRenderingView : NSView
{
}

-(void)swapBuffers;

@end

@interface LightweightOpenGLView : LightweightRenderingView
{
    NSOpenGLContext *gl_context;
}

@property (nonatomic, retain) NSOpenGLContext *glContext;

@end

/*
@interface LightweightMetalView  : LightweightRenderingView
{

}

@end
*/