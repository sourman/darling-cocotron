/* Copyright (c) 2008 Johannes Fortmann

 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 of the Software, and to permit persons to whom the Software is furnished to do
 so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE. */

#import <AppKit/NSMenuWindow.h>
#import <AppKit/NSPanel.h>
#import <AppKit/NSPopUpWindow.h>
#import <AppKit/NSRaise.h>
#import <AppKit/NSWindow.h>
#import <Foundation/NSBundle.h>
#import <Foundation/NSException.h>
#import <Foundation/NSMutableData.h>
#import <Foundation/NSProcessInfo.h>
#import <Onyx2D/O2BitmapContext.h>
#import <Onyx2D/O2Context_builtin_FT.h>
#import <Onyx2D/O2ImageSource.h>
#import <Onyx2D/O2Surface.h>
#import <QuartzCore/CALayer.h>
#import <QuartzCore/CAWindowOpenGLContext.h>
#import <CoreGraphics/CGImage.h>
#import <string.h>

#import "X11Display.h"
#import "X11SubWindow.h"
#import "X11Window.h"
#import <objc/runtime.h>
#import <stdio.h>
#import <unistd.h>

static int createError;

static int x11CreateWindowError(Display *display, XErrorEvent *event) {
    createError = event->error_code;
    dprintf(2, "X11Create BadValue probe req=%d err=%d\n",
            event->request_code, event->error_code);
    return 0;
}
#import <X11/Xatom.h>
#import <X11/Xutil.h>

@interface DarlingIOSurface : NSObject
- (void *) baseAddress;
- (NSInteger) width;
- (NSInteger) height;
- (NSInteger) bytesPerRow;
@end

@implementation X11Window

+ (Visual *) visual {
    static Visual *ret = NULL;

    if (!ret) {
        int visuals_matched, i;
        XVisualInfo match = {0};
        Display *dpy = [(X11Display *) [NSDisplay currentDisplay] display];

        XVisualInfo *info = XGetVisualInfo(dpy, 0, &match, &visuals_matched);

        for (i = 0; i < visuals_matched; i++) {
            if (info[i].depth == 32 && (info[i].red_mask == 0xff0000 &&
                                        info[i].green_mask == 0x00ff00 &&
                                        info[i].blue_mask == 0x0000ff)) {
                ret = info[i].visual;
            }
        }
        XFree(info);
        if (!ret)
            ret = DefaultVisual(dpy, DefaultScreen(dpy));
    }

    return ret;
}

static NSData *makeWindowIcon() {
    static NSMutableData *res;

    if (res != nil)
        return res;

    // Figure out the path.
    NSBundle *bundle = [NSBundle mainBundle];
    NSString *name = [bundle objectForInfoDictionaryKey: @"CFBundleIconFile"];
    if (name == nil || [name length] == 0)
        return nil;
    NSString *path = [bundle pathForImageResource: name];
    if (path == nil) {
        NSLog(@"Cannot find an icon file named %@", name);
        return nil;
    }
    NSURL *url = [NSURL fileURLWithPath: path];

    O2ImageSource *imageSource = [O2ImageSource newImageSourceWithURL: url
                                                              options: nil];
    if (imageSource == nil) {
        NSLog(@"Cannot parse the icon");
        return nil;
    }

    res = [[NSMutableData alloc] initWithCapacity: 32 * 32 * 4 + 2];
    O2ColorSpace *colorSpace = O2ColorSpaceCreateDeviceRGB();

    // Go over the images, turning them into the required format
    // and appending them to res.
    for (NSUInteger i = 0; i < [imageSource count]; i++) {

        O2Image *image = [imageSource createImageAtIndex: i options: nil];
        NSUInteger width = O2ImageGetWidth(image);
        NSUInteger height = O2ImageGetHeight(image);

        // Render the image in ARGB.
        O2BitmapContext *context = (O2BitmapContext *) O2BitmapContextCreate(
                NULL, width, height, 8, width * 4, colorSpace,
                kO2ImageAlphaPremultipliedFirst | kO2BitmapByteOrder32Host);

        [context drawImage: image inRect: O2RectMake(0, 0, width, height)];
        int *imageData = O2BitmapContextGetData(context);

        // Convert to the format accepted by Xlib.
        NSMutableData *data =
                [NSMutableData dataWithLength: width * height * sizeof(long)];
        long *dataPtr = (long *) [data mutableBytes];
        int count = width * height;
        for (int i = 0; i < count; i++) {
            dataPtr[i] = imageData[i];
        }

        struct {
            long w, h;
        } size = {width, height};
        [res appendBytes: &size length: sizeof(size)];
        [res appendData: data];

        [context release];
        [image release];
    }

    [colorSpace release];
    [imageSource release];

    return res;
}

- (void) setWindowIcon {

    NSData *data = makeWindowIcon();

    if (data == nil)
        return;

    XChangeProperty(
            _display, _window, XInternAtom(_display, "_NET_WM_ICON", False),
            XInternAtom(_display, "CARDINAL", False), 32, PropModeReplace,
            [data bytes], [data length] / sizeof(long));
}

- (instancetype) initWithDelegate: (NSWindow *) delegate {
    _delegate = delegate;
    _level = [delegate level];
    _styleMask = [delegate styleMask];
    _backingType = (CGSBackingStoreType)[delegate backingType];
    _deviceDictionary = [NSMutableDictionary new];

    X11Display* x11disp = (X11Display *) [NSDisplay currentDisplay];
    _display = [x11disp display];

    _frame = [self transformFrame: [delegate frame]];
    fprintf(stderr,
            "X11Window content-in-frame %g,%g %gx%g delegate %s\n",
            _frame.origin.x, _frame.origin.y, _frame.size.width,
            _frame.size.height, class_getName([delegate class]));
    BOOL isPanel = [delegate isKindOfClass: [NSPanel class]];
    if (!isPanel &&
        (_frame.size.width < 800 || _frame.size.height < 600)) {
        _frame.size.width = 800;
        _frame.size.height = 600;
        if (_frame.origin.x < 0 || _frame.origin.x > 1600)
            _frame.origin.x = 80;
        if (_frame.origin.y < 0 || _frame.origin.y > 1000)
            _frame.origin.y = 80;
        fprintf(stderr, "X11Window expanded frame to %g,%g %gx%g\n",
                _frame.origin.x, _frame.origin.y, _frame.size.width,
                _frame.size.height);
    }
    if (isPanel && _styleMask & NSDocModalWindowMask)
        _styleMask = NSBorderlessWindowMask;
    // TODO: get rid of these glX calls
    GLint att[] = {GLX_RGBA,
                   GLX_DOUBLEBUFFER,
                   GLX_RED_SIZE,
                   4,
                   GLX_GREEN_SIZE,
                   4,
                   GLX_BLUE_SIZE,
                   4,
                   GLX_DEPTH_SIZE,
                   4,
                   None};

    int screen = DefaultScreen(_display);

    if ((_visualInfo = glXChooseVisual(_display, screen, att)) == NULL) {
        NSLog(@"glXChooseVisual failed at %s %d", __FILE__, __LINE__);
    }

    Colormap cmap =
            XCreateColormap(_display, RootWindow(_display, _visualInfo->screen),
                            _visualInfo->visual, AllocNone);

    if (cmap < 0) {
        NSLog(@"XCreateColormap failed");
        [self release];
        return nil;
    }

    XSetWindowAttributes xattr;
    unsigned long xattr_mask;
    xattr.override_redirect =
            _styleMask == NSBorderlessWindowMask ? True : False;
    xattr_mask = CWOverrideRedirect | CWColormap;
    xattr.colormap = cmap;

    // Isolate the BadValue. The server accepts the parent visual at the
    // screen depth; it rejects the GLX visual (same class and depth, so
    // the visual id itself is the bad argument).
    int (*previous)(Display *, XErrorEvent *) =
            XSetErrorHandler(x11CreateWindowError);
    unsigned width = (unsigned) _frame.size.width;
    unsigned height = (unsigned) _frame.size.height;
    if (width < 1)
        width = 1;
    if (height < 1)
        height = 1;
    Visual *defaultVisual = DefaultVisual(_display, screen);
    int defaultDepth = DefaultDepth(_display, screen);
    dprintf(2,
            "X11Window size %ux%u glx vis=%lu depth=%d class=%d default vis=%lu depth=%d\n",
            width, height,
            _visualInfo ? _visualInfo->visualid : 0,
            _visualInfo ? _visualInfo->depth : -1,
            _visualInfo ? _visualInfo->class : -1,
            defaultVisual->visualid, defaultDepth);

    createError = 0;
    if (_visualInfo != NULL) {
        _window = XCreateWindow(
                _display, DefaultRootWindow(_display), (int) _frame.origin.x,
                (int) _frame.origin.y, width, height, 0, _visualInfo->depth,
                InputOutput, _visualInfo->visual, xattr_mask, &xattr);
        XSync(_display, False);
        dprintf(2, "X11Window glx visual err=%d\n", createError);
    }
    if (_visualInfo == NULL || createError != 0) {
        createError = 0;
        XSetWindowAttributes parentAttr;
        parentAttr.override_redirect = xattr.override_redirect;
        parentAttr.colormap = DefaultColormap(_display, screen);
        _window = XCreateWindow(
                _display, DefaultRootWindow(_display), (int) _frame.origin.x,
                (int) _frame.origin.y, width, height, 0, defaultDepth,
                InputOutput, defaultVisual, CWOverrideRedirect | CWColormap,
                &parentAttr);
        XSync(_display, False);
        dprintf(2, "X11Window default visual err=%d\n", createError);
        _visualInfo = NULL;
    }
    XSetErrorHandler(previous);

    [self syncDelegateProperties];

    Atom atm = XInternAtom(_display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(_display, _window, &atm, 1);

    const char *name = [[[NSProcessInfo processInfo] processName] UTF8String];

    XClassHint classHint = {.res_name = (char *) name,
                            .res_class = (char *) name};
    XSetClassHint(_display, _window, &classHint);

    XSetWindowBackground(_display, _window, BlackPixel(_display, screen));

    _isModal = [delegate isSheet] || [NSApp modalWindow] == delegate;
    // FIXME: There should be no need for this.
    _isModal |= [delegate isKindOfClass: NSClassFromString(@"NSSavePanel")];

    const char *windowType;
    BOOL isTransient = YES;
    if (_isModal) {
        windowType = "_NET_WM_WINDOW_TYPE_DIALOG";
    } else if ([delegate isKindOfClass: [NSMenuWindow class]] ||
               [delegate isKindOfClass: [NSPopUpWindow class]]) {
        windowType = "_NET_WM_WINDOW_TYPE_MENU";
    } else if (isPanel) {
        windowType = "_NET_WM_WINDOW_TYPE_UTILITY";
    } else {
        windowType = "_NET_WM_WINDOW_TYPE_NORMAL";
        isTransient = NO;
    }
    long windowTypeAtom = (long) XInternAtom(_display, windowType, False);
    XChangeProperty(_display, _window,
                    XInternAtom(_display, "_NET_WM_WINDOW_TYPE", False),
                    XA_ATOM, 32, PropModeReplace,
                    (const unsigned char *) &windowTypeAtom, 1);

    if (isTransient && [NSApp mainWindow]) {
        X11Window *mainWindow =
                (X11Window *) [[NSApp mainWindow] platformWindow];
        XSetTransientForHint(_display, _window, [mainWindow windowHandle]);
    }

    _xic = XCreateIC(x11disp->_xim,
        XNInputStyle, XIMPreeditNothing | XIMStatusNothing,
        XNClientWindow, _window,
        XNFocusWindow, _window,
        NULL);

    _cglWindow = CGLGetWindow((void *) _window);

    [(X11Display *) [NSDisplay currentDisplay] setWindow: self forID: _window];

    // FIXME: Move this call into setStyleMaskInternal below!
    if (_styleMask == NSBorderlessWindowMask) {
        [[self class] removeDecorationForWindow: _window onDisplay: _display];
    }
    [self setStyleMaskInternal: _styleMask force: YES];

    [self setWindowIcon];

    if (!isPanel)
        [self ensureMapped];

    return self;
}

- (void) dealloc {
    [self invalidate];
    [_deviceDictionary release];
    [super dealloc];
}

- (NSUInteger) styleMask {
    return _styleMask;
}

- (void) setStyleMaskInternal: (NSUInteger) mask force: (BOOL) force {
    if (force || (mask & NSWindowStyleMaskResizable) !=
                         (_styleMask & NSWindowStyleMaskResizable)) {
        XSizeHints *sh = XAllocSizeHints();
        if (mask & NSWindowStyleMaskResizable) {
            // Make resizable
            sh->flags = 0;
        } else {
            // Make non-resizable
            sh->flags = PMinSize | PMaxSize;
            sh->min_width = sh->max_width = _frame.size.width;
            sh->min_height = sh->max_height = _frame.size.height;
        }

        XSetWMSizeHints(_display, _window, sh, XA_WM_NORMAL_HINTS);
        XFree(sh);
    }

    if (!_mapped) {
        long states[2];
        int states_cnt = 0;
        if (_isModal) {
            states[states_cnt++] =
                    (long) XInternAtom(_display, "_NET_WM_STATE_MODAL", False);
        }
        if (mask & NSWindowStyleMaskFullScreen) {
            states[states_cnt++] = (long) XInternAtom(
                    _display, "_NET_WM_STATE_FULLSCREEN", False);
        }
        XChangeProperty(_display, _window,
                        XInternAtom(_display, "_NET_WM_STATE", False), XA_ATOM,
                        32, PropModeReplace, (const unsigned char *) states,
                        states_cnt);
    } else if (force || ((mask & NSWindowStyleMaskFullScreen) !=
                         (_styleMask & NSWindowStyleMaskFullScreen))) {
        XClientMessageEvent event = {0};
        event.type = ClientMessage;
        event.window = _window;
        event.message_type = XInternAtom(_display, "_NET_WM_STATE", False);
        event.format = 32;
        event.data.l[0] = (mask & NSWindowStyleMaskFullScreen) ? 1 : 2;
        event.data.l[1] =
                (long) XInternAtom(_display, "_NET_WM_STATE_FULLSCREEN", False);
        event.data.l[3] = 1;
        XSendEvent(_display, DefaultRootWindow(_display), False,
                   SubstructureNotifyMask | SubstructureRedirectMask,
                   (XEvent *) &event);
    }
}

- (void) setStyleMask: (NSUInteger) mask {
    NSLog(@"X11Window setStyleMask: 0x%lx\n", (unsigned long) mask);

    [self setStyleMaskInternal: mask force: NO];

    _styleMask = mask;
}

+ (void) removeDecorationForWindow: (Window) w onDisplay: (Display *) dpy {
    return;
    struct {
        unsigned long flags;
        unsigned long functions;
        unsigned long decorations;
        long input_mode;
        unsigned long status;
    } hints = {
            2, 0, 0, 0, 0,
    };
    XChangeProperty(dpy, w, XInternAtom(dpy, "_MOTIF_WM_HINTS", False),
                    XInternAtom(dpy, "_MOTIF_WM_HINTS", False), 32,
                    PropModeReplace, (const unsigned char *) &hints,
                    sizeof(hints) / sizeof(long));
}

- (void) ensureMapped {
    if (!_mapped) {
        XMapWindow(_display, _window);
        _mapped = YES;
    }
}

- (void) showWindowWithoutActivation {
    [self ensureMapped];
}

- (void) setDelegate: delegate {
    _delegate = delegate;
    [self syncDelegateProperties];
}

- delegate {
    return _delegate;
}

- (void) syncDelegateProperties {
    long mask = KeyPressMask | KeyReleaseMask | ExposureMask |
                StructureNotifyMask | EnterWindowMask | LeaveWindowMask |
                ButtonPressMask | ButtonReleaseMask | ButtonMotionMask |
                VisibilityChangeMask | FocusChangeMask |
                SubstructureRedirectMask;

    if ([_delegate acceptsMouseMovedEvents]) {
        mask |= PointerMotionMask;
    }
    XSelectInput(_display, _window, mask);

    // TODO: background color
}

- (void) invalidate {
    // This is essentially dealloc; we release our contexts
    // and windows, but unlike dealloc, this method can be called
    // several times, so set everything to nil/NULL/0.
    [_context release];
    _context = nil;

    [_delegate platformWindowDidInvalidateCGContext: self];
    _delegate = nil;

    [_caContext release];
    _caContext = nil;

    if (_cglContext != NULL) {
        CGLReleaseContext(_cglContext);
        _cglContext = NULL;
    }
    if (_cglWindow != NULL) {
        CGLDestroyWindow(_cglWindow);
        _cglWindow = NULL;
    }

    if (_window) {
        XDestroyIC(_xic);

        [(X11Display *) [NSDisplay currentDisplay] setWindow: nil
                                                       forID: _window];
        XDestroyWindow(_display, _window);
        _window = 0;
    }
}

- (Window) windowHandle {
    return _window;
}

- (O2Context *) createCGContextIfNeeded {
    if (_context == nil) {
        O2ColorSpaceRef colorSpace = O2ColorSpaceCreateDeviceRGB();
        O2Surface *surface = [[O2Surface alloc]
                   initWithBytes: NULL
                           width: _frame.size.width
                          height: _frame.size.height
                bitsPerComponent: 8
                     bytesPerRow: 0
                      colorSpace: colorSpace
                      bitmapInfo: kO2ImageAlphaPremultipliedFirst |
                                  kO2BitmapByteOrder32Little];
        O2ColorSpaceRelease(colorSpace);
        _context = [[O2Context_builtin_FT alloc] initWithSurface: surface
                                                         flipped: NO];
        [surface release];
    }
    return _context;
}

- (O2Context *) cgContext {
    return [self createCGContextIfNeeded];
}

- (void) invalidateContextWithNewSize: (NSSize) size
                         forceRebuild: (BOOL) forceRebuild
{
    if (!NSEqualSizes(_frame.size, size) || forceRebuild) {
        _frame.size = size;
        if (![_context resizeWithNewSize: size]) {
            [_context release];
            _context = nil;
            [_delegate platformWindowDidInvalidateCGContext: self];
        }
    }
}

- (void) invalidateContextWithNewSize: (NSSize) size {
    [self invalidateContextWithNewSize: size forceRebuild: NO];
}

- (void) setTitle: (NSString *) title {
    XTextProperty prop;
    const char *text = [title cString];
    XStringListToTextProperty((char **) &text, 1, &prop);
    XSetWMName(_display, _window, &prop);
}

- (void) setFrame: (O2Rect) frame {
    frame = [self transformFrame: frame];
    XMoveResizeWindow(_display, _window, frame.origin.x, frame.origin.y,
                      frame.size.width, frame.size.height);
    [self invalidateContextWithNewSize: frame.size];
    _frame = frame;
}

- (void) setHasShadow: (BOOL) value {
    _hasShadow = value;
}

- (void) setLevel: (int) value {
    _level = value;
}

- (void) setOpaque: (BOOL) value {
    _isOpaque = value;
}

- (void) sheetOrderFrontFromFrame: (NSRect) frame
                      aboveWindow: (CGWindow *) aboveWindow
{
    [self setFrame: frame];
    [self placeAboveWindow: [aboveWindow windowNumber]];
}

- (void) sheetOrderOutToFrame: (NSRect) frame {
    [self hideWindow];
}

- (void) showWindowForAppActivation: (O2Rect) frame {
    [self showWindowWithoutActivation];
}

- (void) hideWindowForAppDeactivation: (O2Rect) frame {
    /* Ignored */
}

- (void) hideWindow {
    XUnmapWindow(_display, _window);
    _mapped = NO;
}

- (void) placeAboveWindow: (NSInteger) otherNumber {
    X11Window *other = [X11Window windowWithWindowNumber: otherNumber];
    [self ensureMapped];

    if (!other) {
        XRaiseWindow(_display, _window);
    } else {
        Window w[2] = {_window, other->_window};
        XRestackWindows(_display, w, 1);
    }
}

- (void) placeBelowWindow: (NSInteger) otherNumber {
    X11Window *other = [X11Window windowWithWindowNumber: otherNumber];
    [self ensureMapped];

    if (!other) {
        XLowerWindow(_display, _window);
    } else {
        Window w[2] = {other->_window, _window};
        XRestackWindows(_display, w, 1);
    }
}

- (void) makeKey {
    [self ensureMapped];
    XRaiseWindow(_display, _window);
}

- (void) makeMain {
}

- (void) captureEvents {
}

- (void) miniaturize {
    XIconifyWindow(_display, _window, DefaultScreen(_display));
}

- (void) deminiaturize {
    XRaiseWindow(_display, _window);
}

- (BOOL) isMiniaturized {
    Atom wmState = XInternAtom(_display, "_NET_WM_STATE", FALSE);
    Atom hiddenState = XInternAtom(_display, "_NET_WM_STATE_HIDDEN", FALSE);

    Atom type;
    int format;
    unsigned long nItem, bytesAfter;
    unsigned char *properties = NULL;
    BOOL rv = NO;

    if (XGetWindowProperty(_display, _window, wmState, 0, (~0L), FALSE, XA_ATOM,
                           &type, &format, &nItem, &bytesAfter,
                           &properties) == Success) {
        Atom *atoms = (Atom *) properties;
        for (int i = 0; i < nItem; i++) {
            if (atoms[i] == hiddenState) {
                rv = YES;
                break;
            }
        }
        XFree(properties);
    }

    return rv;
}

- (CGLContextObj) cglContext {
    return _cglContext;
}

- (void) createCGLContextObjIfNeeded {
    if (_cglContext == NULL) {
        CGLError error;

        if ((error = CGLCreateContext(NULL, NULL, &_cglContext)) !=
            kCGLNoError) {
            NSLog(@"CGLCreateContext failed at %s %d with error %d", __FILE__,
                  __LINE__, error);

            [NSException raise: NSGenericException
                        format: @"Failed to create GL context, CGL error %d",
                                error];
        }
        if ((error = CGLContextMakeCurrentAndAttachToWindow(
                     _cglContext, _cglWindow)) != kCGLNoError)
            NSLog(@"CGLContextMakeCurrentAndAttachToWindow failed with error "
                  @"%d",
                  error);
    }
    if (_cglContext != nil && _caContext == nil) {
        _caContext =
                [[CAWindowOpenGLContext alloc] initWithCGLContext: _cglContext];
    }
}

- (void) openGLFlushBuffer {
    CGLError error;

    CGLContextObj prevContext = CGLGetCurrentContext();

    [self createCGLContextObjIfNeeded];
    if (_caContext == nil)
        return;

    O2Surface *surface = [_context surface];
    size_t width = O2ImageGetWidth(surface);
    size_t height = O2ImageGetHeight(surface);

    [_caContext prepareViewportWidth: width height: height];
    [_caContext renderSurface: surface];

    glFlush();
    CGLFlushDrawable(_cglContext);

    CGLSetCurrentContext(prevContext);
}

- (void) blitBackingStore {
    if (_context == nil || _window == 0 || _display == NULL)
        return;
    O2Surface *surface = [_context surface];
    if (surface == nil)
        return;
    size_t width = O2ImageGetWidth(surface);
    size_t height = O2ImageGetHeight(surface);
    void *bytes = [surface pixelBytes];
    if (width < 1 || height < 1 || bytes == NULL)
        return;
    Visual *visual = (_visualInfo != NULL) ? _visualInfo->visual
                                           : DefaultVisual(_display, DefaultScreen(_display));
    int depth = (_visualInfo != NULL) ? _visualInfo->depth
                                      : DefaultDepth(_display, DefaultScreen(_display));
    XImage *image = XCreateImage(_display, visual, depth, ZPixmap, 0,
                                 (char *) bytes, width, height, 32, (int) width * 4);
    if (image == NULL)
        return;
    GC gc = XCreateGC(_display, _window, 0, NULL);
    XPutImage(_display, _window, gc, image, 0, 0, 0, 0, width, height);
    XFreeGC(_display, gc);
    image->data = NULL;
    XDestroyImage(image);
    XFlush(_display);
    size_t painted = 0;
    size_t pagePixels = 0;
    uint32_t firstPixel = 0;
    uint32_t firstPage = 0;
    const uint8_t *src = bytes;
    size_t pixels = width * height;
    for (size_t i = 0; i < pixels; i++) {
        uint8_t b = src[i * 4];
        uint8_t g = src[i * 4 + 1];
        uint8_t r = src[i * 4 + 2];
        BOOL black = r <= 12 && g <= 12 && b <= 12;
        BOOL gray = r == 0xed && g == 0xed && b == 0xed;
        if (!black) {
            if (painted == 0)
                firstPixel = (uint32_t) b | ((uint32_t) g << 8) |
                             ((uint32_t) r << 16) | ((uint32_t) src[i * 4 + 3] << 24);
            painted++;
        }
        if (!black && !gray) {
            if (pagePixels == 0)
                firstPage = (uint32_t) b | ((uint32_t) g << 8) |
                            ((uint32_t) r << 16) | ((uint32_t) src[i * 4 + 3] << 24);
            pagePixels++;
        }
    }
    fprintf(stderr, "X11Window blit %zux%zu painted %zu first %08x page %zu firstPage %08x\n",
            width, height, painted, firstPixel, pagePixels, firstPage);
    fflush(stderr);
}

static void X11LogRendererLayer(NSView *view) {
    if (view == nil)
        return;
    if (strcmp(class_getName([view class]), "RenderWidgetHostViewCocoa") == 0) {
        static int logged;
        CALayer *layer = [view layer];
        id contents = nil;
        size_t frameW = 0;
        size_t frameH = 0;
        if (layer != nil)
            [layer display];
        contents = [layer contents];
        frameW = 0;
        frameH = 0;
        if ([contents isKindOfClass: [O2Image class]]) {
            frameW = CGImageGetWidth((CGImageRef) contents);
            frameH = CGImageGetHeight((CGImageRef) contents);
        }
        if (!logged) {
            logged = 1;
            fprintf(stderr,
                    "RWHV blit contents %p frame %zux%zu\n",
                    contents, frameW, frameH);
            fflush(stderr);
        }
    }
    for (NSView *subview in [view subviews])
        X11LogRendererLayer(subview);
}

static BOOL X11CopyLayerImage(CALayer *layer, uint8_t *dst, size_t dstW, size_t dstH) {
    id contents = [layer contents];
    if (contents != nil &&
        strcmp(class_getName([contents class]), "IOSurface") == 0) {
        DarlingIOSurface *surface = contents;
        const uint8_t *src = [surface baseAddress];
        size_t width = (size_t) [surface width];
        size_t height = (size_t) [surface height];
        size_t bytesPerRow = (size_t) [surface bytesPerRow];
        size_t copyW = width < dstW ? width : dstW;
        size_t copyH = height < dstH ? height : dstH;
        if (src != NULL && bytesPerRow >= copyW * 4 && copyW > 0 && copyH > 0) {
            BOOL hasPagePixel = NO;
            for (size_t i = 0; i < copyW * copyH && !hasPagePixel; i++) {
                size_t y = i / copyW;
                size_t x = i % copyW;
                const uint8_t *p = src + y * bytesPerRow + x * 4;
                BOOL gray = p[0] == 0xed && p[1] == 0xed && p[2] == 0xed;
                BOOL black = p[0] <= 12 && p[1] <= 12 && p[2] <= 12;
                if (!gray && !black)
                    hasPagePixel = YES;
            }
            if (hasPagePixel) {
                size_t y0 = dstH - copyH;
                for (size_t y = 0; y < copyH; y++)
                    memcpy(dst + (y0 + y) * dstW * 4, src + y * bytesPerRow, copyW * 4);
                return YES;
            }
        }
    }
    if ([contents isKindOfClass: [O2Image class]]) {
        CGImageRef image = (CGImageRef) contents;
        size_t width = CGImageGetWidth(image);
        size_t height = CGImageGetHeight(image);
        size_t copyW = width < dstW ? width : dstW;
        size_t copyH = height < dstH ? height : dstH;
        if (copyW > 0 && copyH > 0) {
            CFDataRef data = CGDataProviderCopyData(CGImageGetDataProvider(image));
            if (data != NULL) {
                size_t row = width * 4;
                size_t bytesPerRow = CGImageGetBytesPerRow(image);
                const uint8_t *src = CFDataGetBytePtr(data);
                BOOL hasPagePixel = NO;
                if (src != NULL && bytesPerRow >= row) {
                    for (size_t i = 0; i < width * height && !hasPagePixel; i++) {
                        size_t y = i / width;
                        size_t x = i % width;
                        const uint8_t *p = src + y * bytesPerRow + x * 4;
                        BOOL gray = p[0] == 0xed && p[1] == 0xed && p[2] == 0xed;
                        BOOL black = p[0] <= 12 && p[1] <= 12 && p[2] <= 12;
                        if (!gray && !black)
                            hasPagePixel = YES;
                    }
                }
                if (hasPagePixel) {
                    size_t y0 = dstH - copyH;
                    size_t copyRow = copyW * 4;
                    for (size_t y = 0; y < copyH; y++)
                        memcpy(dst + (y0 + y) * dstW * 4, src + y * bytesPerRow, copyRow);
                    CFRelease(data);
                    return YES;
                }
                CFRelease(data);
            }
        }
    }
    for (CALayer *sublayer in [layer sublayers]) {
        if (X11CopyLayerImage(sublayer, dst, dstW, dstH))
            return YES;
    }
    return NO;
}

static void X11CopyViewTree(NSView *view, uint8_t *dst, size_t dstW, size_t dstH) {
    if (view == nil)
        return;
    CALayer *layer = [view layer];
    if (layer != nil && X11CopyLayerImage(layer, dst, dstW, dstH))
        return;
    for (NSView *subview in [view subviews]) {
        X11CopyViewTree(subview, dst, dstW, dstH);
    }
}

- (void) flushBuffer {
    if (_context == nil)
        return;
    NSView *content = [_delegate contentView];
    if (content != nil && [content layer] == nil)
        [content setWantsLayer: YES];
    CALayer *layer = [content layer];
    fprintf(stderr, "X11 flush content %s layer %p delegate %s\n",
            content == nil ? "nil" : class_getName([content class]),
            layer,
            layer == nil || [layer delegate] == nil ? "nil" : class_getName([[layer delegate] class]));
    fflush(stderr);
    id contents = nil;
    if (layer != nil) {
        [layer display];
        contents = [layer contents];
    }
    fprintf(stderr, "X11 flush contents %s\n",
            contents == nil ? "nil" : class_getName([contents class]));
    fflush(stderr);
    O2ContextFlush(_context);
    O2Surface *surface = [_context surface];
    if (layer != nil && surface != nil) {
        void *bytes = [surface pixelBytes];
        size_t width = O2ImageGetWidth(surface);
        size_t height = O2ImageGetHeight(surface);
        if (bytes != NULL && width > 0 && height > 0) {
            X11LogRendererLayer(content);
            X11CopyViewTree(content, bytes, width, height);
        }
    }
    [self blitBackingStore];
    [self openGLFlushBuffer];
}

- (void) setLastKnownCursorPosition: (CGPoint) point {
    _lastMotionPos = [self transformPoint: point];
}

- (NSPoint) mouseLocationOutsideOfEventStream {
    return [self transformPoint: _lastMotionPos];
}

- (O2Rect) frame {
    return [self transformFrame: _frame];
}

static int ignoreBadWindow(Display *display, XErrorEvent *errorEvent) {
    if (errorEvent->error_code == BadWindow)
        return 0;
    char buf[512];
    XGetErrorText(display, errorEvent->error_code, buf, 512);
    [NSException raise: NSInternalInconsistencyException
                format: @"X11 error: %s", buf];
    return 0;
}

- (void) frameChanged {
    XErrorHandler previousHandler = XSetErrorHandler(ignoreBadWindow);
    @try {
        Window root, parent;
        Window window = _window;
        int x, y;
        unsigned int w, h, d, b, nchild;
        Window *children;
        O2Rect rect = NSZeroRect;
        // recursively get geometry to get absolute position
        BOOL success = YES;
        while (window && success) {
            XGetGeometry(_display, window, &root, &x, &y, &w, &h, &b, &d);
            success = XQueryTree(_display, window, &root, &parent, &children,
                                 &nchild);
            if (children)
                XFree(children);

            // first iteration: save our own w, h
            if (window == _window)
                rect = NSMakeRect(0, 0, w, h);
            rect.origin.x += x;
            rect.origin.y += y;
            window = parent;
        };

        [self invalidateContextWithNewSize: rect.size];
        _frame = rect;
    } @finally {
        XSetErrorHandler(previousHandler);
    }
}

- (Visual *) visual {
    return DefaultVisual(_display, DefaultScreen(_display));
}

- (Drawable) drawable {
    return _window;
}

- (void) addEntriesToDeviceDictionary: (NSDictionary *) entries {
    [_deviceDictionary addEntriesFromDictionary: entries];
}

- (O2Rect) transformFrame: (O2Rect) frame {
    return NSMakeRect(frame.origin.x,
                      DisplayHeight(_display, DefaultScreen(_display)) -
                              frame.origin.y - frame.size.height,
                      fmax(frame.size.width, 1.0),
                      fmax(frame.size.height, 1.0));
}

- (NSPoint) transformPoint: (NSPoint) pos; {
    return NSMakePoint(pos.x, _frame.size.height - pos.y);
}

- (X11SubWindow *) createSubWindowWithFrame: (CGRect) frame {
    return [[[X11SubWindow alloc] initWithParentWindow: self
                                                 frame: frame] autorelease];
}

@end
