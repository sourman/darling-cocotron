#import <Foundation/NSString.h>
#import <Foundation/NSTimer.h>
#import <Foundation/NSRunLoop.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSNumber.h>
#import <QuartzCore/CALayer.h>
#import <QuartzCore/CALayerContext.h>
#import <QuartzCore/CARenderer.h>
#import "CALayerInternal.h"
#import <OpenGL/CGLInternal.h>
#import <OpenGL/gl.h>
#import <stdio.h>

@class CAMetalLayerInternal;

__attribute__((used)) const char calayer_glx_swap_v2[] =
        "calayer_glx_swap_v2";

#define CALAYER_CTX_MAX 64
static CALayerContext *g_layerContexts[CALAYER_CTX_MAX];
static int g_layerContextCount;
static int g_presenting;

static void CALayerContextRegister(CALayerContext *ctx) {
    int i;
    for (i = 0; i < g_layerContextCount; i++)
        if (g_layerContexts[i] == ctx)
            return;
    if (g_layerContextCount < CALAYER_CTX_MAX)
        g_layerContexts[g_layerContextCount++] = ctx;
}

static void CALayerContextUnregister(CALayerContext *ctx) {
    int i;
    for (i = 0; i < g_layerContextCount; i++) {
        if (g_layerContexts[i] == ctx) {
            g_layerContexts[i] = g_layerContexts[--g_layerContextCount];
            return;
        }
    }
}

@implementation CALayerContext

@synthesize glContext = _glContext;

- initWithFrame: (CGRect) rect {
    CGLError error;

    CGLPixelFormatAttribute attributes[1] = {
            0,
    };
    GLint numberOfVirtualScreens;

    CGLChoosePixelFormat(attributes, &_pixelFormat, &numberOfVirtualScreens);

    if ((error = CGLCreateContext(_pixelFormat, NULL, &_glContext)) !=
        kCGLNoError)
        NSLog(@"CGLCreateContext failed with %d in %s %d", error, __FILE__,
              __LINE__);

    _frame = rect;
    _deleteTextureIds = [[NSMutableArray alloc] init];

    _renderer = [[CARenderer rendererWithCGLContext: _glContext
                                            options: nil] retain];
    CALayerContextRegister(self);

    return self;
}

- (void) dealloc {
    CALayerContextUnregister(self);
    [_timer invalidate];
    [_timer release];
    [_renderer release];
    [_deleteTextureIds release];
    CGLReleaseContext(_glContext);
    CGLDestroyWindow(_cglWindow);
    [_subwindow release];
    [_layer release];
    [super dealloc];
}

- (void) setFrame: (CGRect) rect {
    _frame = rect;
    [_subwindow setFrame: _frame];
}

- (void) setLayer: (CALayer *) layer {
    layer = [layer retain];
    [_layer release];
    _layer = layer;

    [_layer _setContext: self];
    [_renderer setLayer: layer];
}

- (void) setSubwindow: (CGSubWindow*) subwindow
{
    CGSubWindow* oldSubwindow = _subwindow;

    if (_cglWindow) {
        CGLDestroyWindow(_cglWindow);
    }

    _subwindow = [subwindow retain];
    _cglWindow = CGLGetWindow([_subwindow nativeWindow]);

    [_subwindow show];

    [oldSubwindow release];

    [_subwindow setFrame: _frame];
    [self startTimerIfNeeded];
}

- (void) invalidate {
}

- (void) assignTextureIdsToLayerTree: (CALayer *) layer {

    if ([layer _textureId] == nil) {
        GLuint texture;

        glGenTextures(1, &texture);
        [layer _setTextureId: [NSNumber numberWithUnsignedInt: texture]];
    }

    for (CALayer *child in layer.sublayers)
        [self assignTextureIdsToLayerTree: child];
}

- (void) renderLayer: (CALayer *) layer {
    if (!_glContext || !_cglWindow)
        return;

    CGLContextMakeCurrentAndAttachToWindow(_glContext, _cglWindow);

    GLint width = _frame.size.width;
    GLint height = _frame.size.height;
    GLint dw = 0, dh = 0;
    if (CGLGetDrawableSize(_glContext, &dw, &dh) == kCGLNoError) {
        if (dw > width)
            width = dw;
        if (dh > height)
            height = dh;
    }
    if (width < 1)
        width = 1;
    if (height < 1)
        height = 1;

    glEnable(GL_DEPTH_TEST);
    glShadeModel(GL_SMOOTH);

    glViewport(0, 0, width, height);
    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    glOrtho(0, width, 0, height, -1, 1);

    GLsizei i = 0;
    NSUInteger nDelete = [_deleteTextureIds count];
    GLuint deleteIds[nDelete > 0 ? nDelete : 1];

    for (NSNumber *number in _deleteTextureIds)
        deleteIds[i++] = [number unsignedIntValue];

    if (i > 0)
        glDeleteTextures(i, deleteIds);

    [_deleteTextureIds removeAllObjects];

    [self assignTextureIdsToLayerTree: layer];

    // this is where the Metal layer renders to an internal texture for us to use
    if ([[layer class] isSubclassOfClass: [CAMetalLayerInternal class]]) {
        CAMetalLayerInternal* mtl = (CAMetalLayerInternal*)layer;
        [mtl prepareRender];
    }

    [_renderer render];
    CGLFlushDrawable(_glContext);
    static int renders = 0;
    if (renders < 16) {
        fprintf(stderr, "CALayerContext render+swap frame=%dx%d n=%d\n",
                (int) width, (int) height, ++renders);
        fflush(stderr);
    }
}

- (void) render {
    [self renderLayer: _layer];
}

- (void) timer: (NSTimer *) timer {
    [_renderer beginFrameAtTime: CACurrentMediaTime() timeStamp: NULL];

    [self render];

    [_renderer endFrame];
}

- (void) startTimerIfNeeded {
    if (_timer == nil) {
        _timer = [[NSTimer timerWithTimeInterval: 1.0 / 60.0
                                          target: self
                                        selector: @selector(timer:)
                                        userInfo: nil
                                         repeats: YES] retain];
        /* Chrome's pump is not NSDefaultRunLoopMode; CommonModes fires. */
        [[NSRunLoop currentRunLoop] addTimer: _timer
                                     forMode: NSRunLoopCommonModes];
        fprintf(stderr, "CALayerContext startTimer CommonModes frame=%.0fx%.0f\n",
                _frame.size.width, _frame.size.height);
        fflush(stderr);
    }
}

- (void) deleteTextureId: (NSNumber *) textureId {
    [_deleteTextureIds addObject: textureId];
}

- (void) flush {
    CGLFlushDrawable(_glContext);
    static int flushes = 0;
    if (flushes < 8) {
        fprintf(stderr, "CALayerContext CGLFlushDrawable n=%d\n", ++flushes);
        fflush(stderr);
    }
}

+ (void) presentAll {
    int i, n;
    CALayerContext *copy[CALAYER_CTX_MAX];
    if (g_presenting)
        return;
    g_presenting = 1;
    n = g_layerContextCount;
    for (i = 0; i < n; i++)
        copy[i] = g_layerContexts[i];
    for (i = 0; i < n; i++)
        [copy[i] render];
    g_presenting = 0;
}

@end
