#import "X11SubWindow.h"
#import "X11Display.h"
#import "X11Window.h"
#import <stdio.h>

@implementation X11SubWindow

- (CGRect) convertFrame: (CGRect) frame {
    CGFloat top, left, bottom, right;
    CGNativeBorderFrameWidthsForStyle([_parent styleMask], &top, &left, &bottom,
                                      &right);
    frame.origin.y = [_parent frame].size.height - CGRectGetMaxY(frame);
    frame.origin.y -= top;
    frame.origin.x -= left;
    return frame;
}

static unsigned int x11SubClampExtent(CGFloat n) {
    if (!(n >= 1.0))
        return 1;
    if (n > 65535.0)
        return 65535;
    unsigned int u = (unsigned int) n;
    return u < 1 ? 1 : u;
}

- (id) initWithParentWindow: (X11Window *) parent frame: (CGRect) frame {
    _parent = parent;
    frame = [self convertFrame: frame];

    X11Display *x11disp = (X11Display *) [NSDisplay currentDisplay];
    _display = [x11disp display];

    Window parentHandle = [parent windowHandle];
    if (!parentHandle) {
        _window = 0;
        return self;
    }

    unsigned int width = x11SubClampExtent(frame.size.width);
    unsigned int height = x11SubClampExtent(frame.size.height);

    [x11disp clearLastXError];
    _window = XCreateSimpleWindow(_display, parentHandle, (int) frame.origin.x,
                                  (int) frame.origin.y, width, height, 0, 0, 0);
    unsigned long createSerial = NextRequest(_display) - 1;
    XSync(_display, False);
    if (!_window || ([x11disp lastXErrorCode] != 0 &&
                     [x11disp lastXErrorSerial] == createSerial)) {
        fprintf(stderr, "X11SubWindow XCreateSimpleWindow FAILED err=%d\n",
                [x11disp lastXErrorCode]);
        fflush(stderr);
        _window = 0;
        return self;
    }

    [self show];
    return self;
}

- (void) dealloc {
    if (_window)
        XDestroyWindow(_display, _window);
    [super dealloc];
}

- (void *) nativeWindow {
    return (void *) _window;
}

- (void) show {
    if (!_window)
        return;
    XMapWindow(_display, _window);
}

- (void) hide {
    if (!_window)
        return;
    XUnmapWindow(_display, _window);
}

- (void) setFrame: (CGRect) frame {
    frame = [self convertFrame: frame];
    if (!_window)
        return;
    XMoveResizeWindow(_display, _window, (int) frame.origin.x,
                      (int) frame.origin.y, x11SubClampExtent(frame.size.width),
                      x11SubClampExtent(frame.size.height));
}

@end
