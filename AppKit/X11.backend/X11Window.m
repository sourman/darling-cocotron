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
#import <QuartzCore/CAWindowOpenGLContext.h>
#import <QuartzCore/CATransaction.h>

#import "X11Display.h"
#import "X11SubWindow.h"
#import "X11Window.h"
#import <X11/Xatom.h>
#import <X11/Xutil.h>
#import <math.h>
#import <stdio.h>
#import <stdlib.h>
#import <string.h>

/* X CreateWindow width/height are CARD16 and must be >= 1. NaN/<=0 would
   truncate to 0 and the server replies BadValue. */
static unsigned int x11ClampExtent(CGFloat n) {
    if (!(n >= 1.0))
        return 1;
    if (n > 65535.0)
        return 65535;
    unsigned int u = (unsigned int) n;
    return u < 1 ? 1 : u;
}

__attribute__((used)) const char x11_createwindow_min1_v1[] =
        "x11_createwindow_min1_v1";
__attribute__((used)) const char onyx2d_xputimage_default_visual_v1[] =
        "onyx2d_xputimage_default_visual_v1";

@implementation X11Window

+ (Visual *) visual {
    Display *dpy = [(X11Display *) [NSDisplay currentDisplay] display];
    return DefaultVisual(dpy, DefaultScreen(dpy));
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
    BOOL isPanel = [delegate isKindOfClass: [NSPanel class]];
    if (isPanel && _styleMask & NSDocModalWindowMask)
        _styleMask = NSBorderlessWindowMask;

    int screen = DefaultScreen(_display);
    Window root = RootWindow(_display, screen);
    /* Window and GLX must share the 24-bit DefaultVisual. glXChooseVisual
       RGBA+DOUBLEBUFFER returns a different visualid (0x1d5 here) which
       BadMatches a DefaultVisual window; a 32-bit GLX visual plus a private
       colormap is BadValue on DCV (max colormaps = 1). */
    Visual *visual = DefaultVisual(_display, screen);
    int depth = DefaultDepth(_display, screen);
    Colormap cmap = DefaultColormap(_display, screen);
    XVisualInfo visTemplate;
    memset(&visTemplate, 0, sizeof(visTemplate));
    visTemplate.visualid = XVisualIDFromVisual(visual);
    int nvis = 0;
    _visualInfo = XGetVisualInfo(_display, VisualIDMask, &visTemplate, &nvis);
    _gc = 0;

    XSetWindowAttributes xattr;
    unsigned long xattr_mask = CWOverrideRedirect | CWColormap | CWBorderPixel;
    xattr.override_redirect =
            _styleMask == NSBorderlessWindowMask ? True : False;
    xattr.colormap = cmap;
    xattr.border_pixel = BlackPixel(_display, screen);

    unsigned int width = x11ClampExtent(_frame.size.width);
    unsigned int height = x11ClampExtent(_frame.size.height);
    int x = (int) _frame.origin.x;
    int y = (int) _frame.origin.y;
    _frame.size.width = width;
    _frame.size.height = height;

    [x11disp clearLastXError];
    _window = XCreateWindow(_display, root, x, y, width, height, 0, depth,
                            InputOutput, visual, xattr_mask, &xattr);
    unsigned long createSerial = NextRequest(_display) - 1;
    XSync(_display, False);

    fprintf(stderr,
            "X11Window XCreateWindow id=0x%lx frame={{%d,%d},{%u,%u}} "
            "depth=%d vis=0x%lx cmap=0x%lx xerr=%d serial=%lu mapped=%d\n",
            (unsigned long) _window, x, y, width, height, depth,
            (unsigned long) XVisualIDFromVisual(visual),
            (unsigned long) cmap, [x11disp lastXErrorCode], createSerial,
            _mapped);
    fflush(stderr);

    if (!_window || ([x11disp lastXErrorCode] != 0 &&
                     [x11disp lastXErrorSerial] == createSerial)) {
        fprintf(stderr, "X11Window XCreateWindow FAILED id=0x%lx err=%d\n",
                (unsigned long) _window, [x11disp lastXErrorCode]);
        fflush(stderr);
        _window = 0;
        return self;
    }

    _gc = XCreateGC(_display, _window, 0, NULL);

    [self syncDelegateProperties];

    Atom atm = XInternAtom(_display, "WM_DELETE_WINDOW", False);
    XSetWMProtocols(_display, _window, &atm, 1);

    const char *name = [[[NSProcessInfo processInfo] processName] UTF8String];

    XClassHint classHint = {.res_name = (char *) name,
                            .res_class = (char *) name};
    XSetClassHint(_display, _window, &classHint);

    XSetWindowBackgroundPixmap(_display, _window, None);

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

    // Do not CGLGetWindow/ensureMapped here. Mapping every X11Window at
    // create (including NSCachedImageRep's 32x32 cache) hung recvmsg
    // after NSApp init. GL is attached lazily if Chrome requests it.

    [(X11Display *) [NSDisplay currentDisplay] setWindow: self forID: _window];

    // FIXME: Move this call into setStyleMaskInternal below!
    if (_styleMask == NSBorderlessWindowMask) {
        [[self class] removeDecorationForWindow: _window onDisplay: _display];
    }
    [self setStyleMaskInternal: _styleMask force: YES];

    [self setWindowIcon];

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

__attribute__((used)) const char x11_ensure_mapped_show_path_v1[] =
        "x11_ensure_mapped_show_path_v1";

- (void) ensureMapped {
    if (!_window)
        return;
    if (!_mapped) {
        XMapWindow(_display, _window);
        XFlush(_display);
        fprintf(stderr, "XMapWindow id=0x%lx\n", (unsigned long) _window);
        fflush(stderr);
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

    if (_gc) {
        XFreeGC(_display, _gc);
        _gc = 0;
    }
    if (_visualInfo) {
        XFree(_visualInfo);
        _visualInfo = NULL;
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
    if (_window) {
        XMoveResizeWindow(_display, _window, (int) frame.origin.x,
                          (int) frame.origin.y,
                          x11ClampExtent(frame.size.width),
                          x11ClampExtent(frame.size.height));
    }
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
    if (!_window)
        return;
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
    if (_cglWindow == NULL) {
        [self ensureMapped];
        _cglWindow = CGLGetWindow((void *) _window);
        fprintf(stderr, "X11Window CGLGetWindow id=0x%lx cgl=%p\n",
                (unsigned long) _window, _cglWindow);
        fflush(stderr);
    }
    if (_cglContext == NULL) {
        CGLError error;

        if ((error = CGLCreateContext(NULL, NULL, &_cglContext)) !=
            kCGLNoError) {
            NSLog(@"CGLCreateContext failed at %s %d with error %d", __FILE__,
                  __LINE__, error);
            _cglContext = NULL;
            return;
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

static void x11PutO2Surface(X11Window *self, O2Surface *surface) {
    if (!self->_window || !self->_gc || !surface)
        return;

    size_t width = O2ImageGetWidth(surface);
    size_t height = O2ImageGetHeight(surface);
    size_t srcBpr = O2ImageGetBytesPerRow(surface);
    unsigned char *src = [surface pixelBytes];
    if (!src || width < 1 || height < 1)
        return;

    int screen = DefaultScreen(self->_display);
    Visual *visual = DefaultVisual(self->_display, screen);
    int depth = DefaultDepth(self->_display, screen);
    size_t dstBpr = width * 4;
    char *dst = malloc(dstBpr * height);
    if (!dst)
        return;

    /* O2Surface is BGRA little-endian; DCV 24-bit TrueColor is BGR0 in
       32-bit padded pixels. Copy RGB, drop alpha. */
    size_t copy = width * 4;
    if (srcBpr < copy)
        copy = srcBpr;
    for (size_t y = 0; y < height; y++)
        memcpy(dst + y * dstBpr, src + y * srcBpr, copy);

    XImage *img = XCreateImage(self->_display, visual, (unsigned int) depth,
                               ZPixmap, 0, dst, (unsigned int) width,
                               (unsigned int) height, 32, (int) dstBpr);
    if (!img) {
        free(dst);
        return;
    }
    img->byte_order = LSBFirst;
    img->bitmap_bit_order = LSBFirst;
    img->bits_per_pixel = 32;
    XPutImage(self->_display, self->_window, self->_gc, img, 0, 0, 0, 0,
              (unsigned int) width, (unsigned int) height);
    XFlush(self->_display);
    fprintf(stderr,
            "X11Window Onyx2D XPutImage id=0x%lx %zux%zu depth=%d vis=0x%lx\n",
            (unsigned long) self->_window, width, height, depth,
            (unsigned long) XVisualIDFromVisual(visual));
    fflush(stderr);
    img->data = NULL;
    XDestroyImage(img);
    free(dst);
}

- (void) openGLFlushBuffer {
    CGLContextObj prevContext = CGLGetCurrentContext();

    [self createCGLContextObjIfNeeded];
    if (_caContext != nil) {
        O2Surface *glSurface = [_context surface];
        size_t width = O2ImageGetWidth(glSurface);
        size_t height = O2ImageGetHeight(glSurface);

        [_caContext prepareViewportWidth: width height: height];
        [_caContext renderSurface: glSurface];

        glFlush();
        CGLFlushDrawable(_cglContext);
    }

    /* Onyx2D CPU blit last so a failed/black GL clear cannot hide pixels. */
    if (_context)
        x11PutO2Surface(self, [_context surface]);

    CGLSetCurrentContext(prevContext);
}

- (void) flushBuffer {
    if (_context != nil) {
        O2ContextFlush(_context);
        [self openGLFlushBuffer];
    }
    /* CALayer-hosted Chrome windows often have no Onyx2D surface. Still
       present GLX/CA from Expose on CommonModes. */
    [CATransaction flush];
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
                      x11ClampExtent(frame.size.width),
                      x11ClampExtent(frame.size.height));
}

- (NSPoint) transformPoint: (NSPoint) pos; {
    return NSMakePoint(pos.x, _frame.size.height - pos.y);
}

- (X11SubWindow *) createSubWindowWithFrame: (CGRect) frame {
    return [[[X11SubWindow alloc] initWithParentWindow: self
                                                 frame: frame] autorelease];
}

@end
