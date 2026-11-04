#import "X11SubWindow.h"
#import <unistd.h>
#import "X11Display.h"
#import "X11Window.h"

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

- (id) initWithParentWindow: (X11Window *) parent frame: (CGRect) frame {
    _parent = parent;
    frame = [self convertFrame: frame];

    _display = [(X11Display *) [NSDisplay currentDisplay] display];

    int x = (int) frame.origin.x;
    int y = (int) frame.origin.y;
    unsigned width = (unsigned) frame.size.width;
    unsigned height = (unsigned) frame.size.height;
    if (width < 1)
        width = 1;
    if (height < 1)
        height = 1;
    if (width > 65535)
        width = 65535;
    if (height > 65535)
        height = 65535;
    dprintf(2, "X11SubWindow parent=%lu %d,%d %ux%u\n",
            (unsigned long) [parent windowHandle], x, y, width, height);

    _window = XCreateSimpleWindow(_display, [parent windowHandle], x, y, width,
                                  height, 0, 0,
                                  0 /* border_width, border, background */
    );

    [self show];
    return self;
}

- (void) dealloc {
    XDestroyWindow(_display, _window);
    [super dealloc];
}

- (void *) nativeWindow {
    return (void *) _window;
}

- (void) show {
    XMapWindow(_display, _window);
}

- (void) hide {
    XUnmapWindow(_display, _window);
}

- (void) setFrame: (CGRect) frame {
    frame = [self convertFrame: frame];

    XMoveResizeWindow(_display, _window, frame.origin.x, frame.origin.y,
                      frame.size.width, frame.size.height);
}

@end
