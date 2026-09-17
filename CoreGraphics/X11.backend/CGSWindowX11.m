/*
 This file is part of Darling.

 Copyright (C) 2020 Lubos Dolezel

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/
#import "CGSWindowX11.h"
#import "CGSSurfaceX11.h"
#import <CoreGraphics/CoreGraphicsPrivate.h>
#import <Foundation/NSNumber.h>
#import <X11/Xatom.h>
#import <X11/Xutil.h>
#import <stdio.h>
#import <stdint.h>

@implementation CGSWindowX11

- (instancetype) initWithRegion: (CGSRegionRef) region
                     connection: (CGSConnection *) connection
                       windowID: (CGSWindowID) windowID
                        display: (Display *) display
{
	self = [super initWithRegion: region
	                  connection: connection
	                    windowID: windowID];
	if (self == nil)
		return nil;

	_display = display;
	_mapped = NO;
	_rect = CGRectMake(0, 0, 800, 600);
	if (region)
		CGSRegionToRect(region, &_rect);
	if (_rect.size.width < 1)
		_rect.size.width = 1;
	if (_rect.size.height < 1)
		_rect.size.height = 1;

	int screen = DefaultScreen(_display);
	unsigned int w = (unsigned int) _rect.size.width;
	unsigned int h = (unsigned int) _rect.size.height;
	int x = (int) _rect.origin.x;
	int y = (int) _rect.origin.y;

	_window = XCreateWindow(_display, DefaultRootWindow(_display), x, y, w, h,
	    0, CopyFromParent, InputOutput, CopyFromParent, 0, NULL);

	char comet_name[] = "Comet";
	XClassHint classHint = { .res_name = comet_name, .res_class = comet_name };
	XSetClassHint(_display, _window, &classHint);

	fprintf(stderr, "CGSWindowX11 XCreateWindow id=0x%lx\n",
	    (unsigned long) _window);
	fflush(stderr);
	return self;
}

- (void) invalidate {
	if (_window) {
		XDestroyWindow(_display, _window);
		_window = 0;
	}
	[super invalidate];
}

- (CGError) orderWindow: (CGSWindowOrderingMode) place
             relativeTo: (CGSWindow *) window
{
	(void) window;
	if (place == kCGSOrderOut) {
		if (_mapped) {
			XUnmapWindow(_display, _window);
			_mapped = NO;
			XFlush(_display);
		}
		return kCGSErrorSuccess;
	}
	if (!_mapped) {
		XMapWindow(_display, _window);
		XFlush(_display);
		fprintf(stderr, "XMapWindow id=0x%lx\n", (unsigned long) _window);
		fflush(stderr);
		_mapped = YES;
	} else {
		XRaiseWindow(_display, _window);
		XFlush(_display);
	}
	return kCGSErrorSuccess;
}

- (CGError) moveTo: (const CGPoint *) point {
	if (point == NULL)
		return kCGErrorIllegalArgument;
	_rect.origin = *point;
	XMoveWindow(_display, _window, (int) point->x, (int) point->y);
	return kCGSErrorSuccess;
}

- (CGError) setRegion: (CGSRegionRef) region {
	if (region)
		CGSRegionToRect(region, &_rect);
	if (_rect.size.width < 1)
		_rect.size.width = 1;
	if (_rect.size.height < 1)
		_rect.size.height = 1;
	XMoveResizeWindow(_display, _window, (int) _rect.origin.x,
	    (int) _rect.origin.y, (unsigned int) _rect.size.width,
	    (unsigned int) _rect.size.height);
	return kCGSErrorSuccess;
}

- (CGError) getRect: (CGRect *) outRect {
	if (outRect == NULL)
		return kCGErrorIllegalArgument;
	*outRect = _rect;
	return kCGSErrorSuccess;
}

- (CGError) setProperty: (CFStringRef) key value: (CFTypeRef) value {
	(void) key;
	(void) value;
	return kCGSErrorSuccess;
}

- (CGError) getProperty: (CFStringRef) key value: (CFTypeRef *) value {
	(void) key;
	if (value)
		*value = NULL;
	return kCGSErrorSuccess;
}

- (void *) nativeWindow {
	return (void *) (uintptr_t) _window;
}

- (CGSSurface *) createSurface {
	CGSSurfaceID sid = _nextSurfaceId++;
	CGSSurfaceX11 *surface = [[CGSSurfaceX11 alloc] initWithWindow: self
	                                                    surfaceID: sid];
	@synchronized (_surfaces) {
		[_surfaces setObject: surface forKey: [NSNumber numberWithInt: sid]];
	}
	return [surface autorelease];
}

@end
