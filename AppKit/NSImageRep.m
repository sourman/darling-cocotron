/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSColorSpace.h>
#import <AppKit/NSGraphicsContext.h>
#import <AppKit/NSGraphicsContextFunctions.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSImageRep.h>
#import <AppKit/NSPDFImageRep.h>
#import <AppKit/NSPasteboard.h>
#import <AppKit/NSRaise.h>
#import <CoreGraphics/CGImage.h>

@implementation NSImageRep

static NSMutableArray *_registeredClasses = nil;

+ (void) initialize {
    if (self == [NSImageRep class]) {
        _registeredClasses = [NSMutableArray new];
        [_registeredClasses addObject: [NSBitmapImageRep class]];
        /*
         * // PDF is not ready for primetime
         * [_registeredClasses addObject:[NSPDFImageRep class]];
         */
    }
}

+ (NSArray *) registeredImageRepClasses {
    return _registeredClasses;
}

+ (void) registerImageRepClass: (Class) class {
    [_registeredClasses addObject: class];
}

+ (void) unregisterImageRepClass: (Class) class {
    [_registeredClasses removeObjectIdenticalTo: class];
}

+ (NSArray *) imageFileTypes {
    NSMutableSet *result = [NSMutableSet set];
    int i, count = [_registeredClasses count];

    for (i = 0; i < count; i++) {
        Class cls = [_registeredClasses objectAtIndex: i];

        [result addObjectsFromArray: [cls imageUnfilteredFileTypes]];
    }

    return [result allObjects];
}

+ (NSArray *) imageUnfilteredFileTypes {
    return [NSArray array];
}

+ (NSArray *) imagePasteboardTypes {
    NSMutableSet *result = [NSMutableSet set];
    int i, count = [_registeredClasses count];

    for (i = 0; i < count; i++) {
        Class cls = [_registeredClasses objectAtIndex: i];

        [result addObjectsFromArray: [cls imageUnfilteredPasteboardTypes]];
    }

    return [result allObjects];
}

+ (NSArray *) imageUnfilteredPasteboardTypes {
    return [NSArray array];
}

+ (BOOL) canInitWithData: (NSData *) data {
    return NO;
}

+ (BOOL) canInitWithPasteboard: (NSPasteboard *) pasteboard {
    NSString *available = [pasteboard
            availableTypeFromArray: [self imageUnfilteredPasteboardTypes]];

    return (available != nil) ? YES : NO;
}

+ (Class) imageRepClassForData: (NSData *) data {
    int count = [_registeredClasses count];

    while (--count >= 0) {
        Class check = [_registeredClasses objectAtIndex: count];

        if ([check canInitWithData: data])
            return check;
    }

    return nil;
}

+ (Class) imageRepClassForFileType: (NSString *) type {
    int count = [_registeredClasses count];

    while (--count >= 0) {
        Class checkClass = [_registeredClasses objectAtIndex: count];
        NSArray *types = [checkClass imageUnfilteredFileTypes];

        for (NSString *checkType in types)
            if ([checkType caseInsensitiveCompare: type] == NSOrderedSame)
                return checkClass;
    }

    return nil;
}

+ (Class) imageRepClassForPasteboardType: (NSString *) type {
    int count = [_registeredClasses count];

    while (--count >= 0) {
        Class checkClass = [_registeredClasses objectAtIndex: count];
        NSArray *types = [checkClass imageUnfilteredPasteboardTypes];

        if ([types containsObject: type])
            return checkClass;
    }

    return nil;
}

+ (NSArray *) imageRepsWithContentsOfFile: (NSString *) path {
    // Try to guess which class to use from the path extension
    NSString *type = [path pathExtension];
    Class class = [self imageRepClassForFileType: type];
    if (class == nil) {
        // Else use the content of the file to guess the class to use
        NSData *data = [NSData dataWithContentsOfFile: path];

        if (data == nil) {
            return nil;
        }

        if (self == [NSImageRep class]) {
            class = [self imageRepClassForData: data];
        }
        return [class imageRepsWithData: data];
    }
    return [class imageRepsWithContentsOfFile: path];
}

+ (NSArray *) imageRepsWithContentsOfURL: (NSURL *) url {
    Class class = self;
    NSData *data = [NSData dataWithContentsOfURL: url];

    if (data == nil)
        return nil;

    if (self == [NSImageRep class]) {
        if ((class = [self imageRepClassForData: data]) == nil)
            return nil;
    }

    return [class imageRepsWithData: data];
}

+ (NSArray *) imageRepsWithPasteboard: (NSPasteboard *) pasteboard {
    NSArray *imageTypes = [self imagePasteboardTypes];
    NSArray *pbTypes = [pasteboard types];

    for (NSString *check in pbTypes) {
        if ([imageTypes containsObject: check]) {
            NSData *data = [pasteboard dataForType: check];
            Class class;

            if ((class = [self imageRepClassForData: data]) != nil) {
                NSArray *result;

                if ((result = [class imageRepsWithData: data]) != nil)
                    return result;
            }
        }
    }

    return nil;
}

+ imageRepWithContentsOfFile: (NSString *) path {
    Class class = self;
    NSData *data = [NSData dataWithContentsOfFile: path];

    if (data == nil)
        return nil;

    if (self == [NSImageRep class]) {
        NSString *type = [path pathExtension];

        if ((class = [self imageRepClassForFileType: type]) == nil)
            return nil;
    }

    return [class imageRepWithData: data];
}

+ imageRepWithContentsOfURL: (NSURL *) url {
    Class class = self;
    NSData *data = [NSData dataWithContentsOfURL: url];

    if (data == nil)
        return nil;

    if (self == [NSImageRep class]) {
        if ((class = [self imageRepClassForData: data]) == nil)
            return nil;
    }

    return [class imageRepWithData: data];
}

+ imageRepWithPasteboard: (NSPasteboard *) pasteboard {
    NSArray *imageTypes = [self imagePasteboardTypes];
    NSArray *pbTypes = [pasteboard types];

    for (NSString *check in pbTypes) {
        if ([imageTypes containsObject: check]) {
            NSData *data = [pasteboard dataForType: check];
            Class class;

            if ((class = [self imageRepClassForData: data]) != nil) {
                NSArray *result;

                if ((result = [class imageRepWithData: data]) != nil)
                    return result;
            }
        }
    }

    return nil;
}

- (instancetype) initWithCoder:(NSCoder *) coder
{
    [NSException raise: NSInvalidArgumentException
                    format: @"-[%@ %s] is not implemented for coder %@",
                            [self class], sel_getName(_cmd), coder];
    return nil;
}

- copyWithZone: (NSZone *) zone {
    NSImageRep *result = NSCopyObject(self, 0, zone);
    result->_colorSpaceName = [_colorSpaceName copy];
    return result;
}

- (NSSize) size {
    return _size;
}

- (int) pixelsWide {
    return _pixelsWide;
}

- (int) pixelsHigh {
    return _pixelsHigh;
}

- (BOOL) isOpaque {
    return _isOpaque;
}

- (BOOL) hasAlpha {
    return _hasAlpha;
}

- (NSString *) colorSpaceName {
    return _colorSpaceName;
}

- (NSColorSpace *) colorSpace {
    return [NSColorSpace sRGBColorSpace];
}

- (NSInteger) bitsPerSample {
    return _bitsPerSample;
}

- (void) setSize: (NSSize) value {
    _size = value;
}

- (void) setPixelsWide: (int) value {
    _pixelsWide = value;
}

- (void) setPixelsHigh: (int) value {
    _pixelsHigh = value;
}

- (void) setOpaque: (BOOL) value {
    _isOpaque = value;
}

- (void) setAlpha: (BOOL) value {
    _hasAlpha = value;
}

- (void) setColorSpaceName: (NSString *) value {
    value = [value copy];
    [_colorSpaceName release];
    _colorSpaceName = value;
}

- (void) setBitsPerSample: (int) value {
    _bitsPerSample = value;
}

- (BOOL) draw {
    // do nothing
    return YES;
}

- (BOOL) drawAtPoint: (NSPoint) point {
    CGContextRef context = NSCurrentGraphicsPort();
    BOOL result;

    CGContextSaveGState(context);
    CGContextTranslateCTM(context, point.x, point.y);
    result = [self draw];
    CGContextRestoreGState(context);

    return result;
}

- (BOOL) drawInRect: (NSRect) rect {
    CGContextRef context = NSCurrentGraphicsPort();
    NSSize size = [self size];
    BOOL result;

    if (context == NULL)
        return NO;
    if (size.width <= 0 || size.height <= 0)
        size = NSMakeSize(_pixelsWide > 0 ? _pixelsWide : 1,
                          _pixelsHigh > 0 ? _pixelsHigh : 1);

    CGContextSaveGState(context);
    CGContextTranslateCTM(context, rect.origin.x, rect.origin.y);
    CGContextScaleCTM(context, rect.size.width / size.width,
                      rect.size.height / size.height);
    result = [self draw];
    CGContextRestoreGState(context);

    return result;
}

- (BOOL) drawInRect: (NSRect) dstRect
           fromRect: (NSRect) srcRect
          operation: (NSCompositingOperation) op
           fraction: (CGFloat) fraction
{
    return [self drawInRect: dstRect
                    fromRect: srcRect
                   operation: op
                    fraction: fraction
              respectFlipped: YES
                       hints: nil];
}

- (CGImageRef) CGImageForProposedRect: (NSRect *) proposedDestRect
                            context: (id) context
                              hints: (NSDictionary *) hints
{
    (void) proposedDestRect;
    (void) context;
    (void) hints;
    if ([self isKindOfClass: [NSBitmapImageRep class]]) {
        NSBitmapImageRep *bitmap = (NSBitmapImageRep *) self;
        CGImageRef img = [bitmap CGImage];
        if (img != NULL)
            return img;
        (void) [bitmap bitmapData];
        return [bitmap CGImage];
    }
    return NULL;
}

- (BOOL) drawInRect: (NSRect) dstRect
           fromRect: (NSRect) srcRect
          operation: (NSCompositingOperation) op
           fraction: (CGFloat) fraction
     respectFlipped: (BOOL) respectFlipped
              hints: (NSDictionary *) hints
{
    NSGraphicsContext *gctx = [NSGraphicsContext currentContext];
    CGContextRef ctx = gctx ? [gctx graphicsPort] : NSCurrentGraphicsPort();
    NSSize size = [self size];
    NSRect src;
    CGImageRef image = NULL;
    CGImageRef owned = NULL;
    CGRect dest;
    id interp;

    if (ctx == NULL)
        return NO;
    if (NSIsEmptyRect(dstRect))
        return YES;
    if (size.width <= 0 || size.height <= 0)
        size = NSMakeSize(_pixelsWide > 0 ? _pixelsWide : 1,
                          _pixelsHigh > 0 ? _pixelsHigh : 1);

    src = srcRect;
    if (NSIsEmptyRect(src))
        src = NSMakeRect(0, 0, size.width, size.height);

    if ([self isKindOfClass: [NSBitmapImageRep class]]) {
        NSBitmapImageRep *bitmap = (NSBitmapImageRep *) self;
        image = [bitmap CGImage];
        if (image == NULL) {
            (void) [bitmap bitmapData];
            image = [bitmap CGImage];
        }
    }
    if (image == NULL)
        image = [self CGImageForProposedRect: &dstRect
                                  context: gctx
                                    hints: hints];

    CGContextSaveGState(ctx);
    if (gctx != nil) {
        [gctx setCompositingOperation: op];
        interp = [hints objectForKey: NSImageHintInterpolation];
        if (interp != nil)
            [gctx setImageInterpolation: [interp intValue]];
    }
    if (fraction < 1.0)
        CGContextSetAlpha(ctx, fraction < 0 ? 0 : fraction);

    if (image != NULL &&
        !(src.origin.x == 0 && src.origin.y == 0 &&
          src.size.width == size.width && src.size.height == size.height)) {
        CGFloat imgW = (CGFloat) CGImageGetWidth(image);
        CGFloat imgH = (CGFloat) CGImageGetHeight(image);
        CGFloat sx = size.width > 0 ? imgW / size.width : 1;
        CGFloat sy = size.height > 0 ? imgH / size.height : 1;
        CGRect crop = CGRectMake(src.origin.x * sx,
                                  imgH - (src.origin.y + src.size.height) * sy,
                                  src.size.width * sx, src.size.height * sy);
        owned = CGImageCreateWithImageInRect(image, crop);
        if (owned != NULL)
            image = owned;
    }

    dest = dstRect;
    if (respectFlipped && gctx != nil && [gctx isFlipped]) {
        CGContextTranslateCTM(ctx, dstRect.origin.x,
                              dstRect.origin.y + dstRect.size.height);
        CGContextScaleCTM(ctx, 1.0, -1.0);
        dest.origin = CGPointZero;
    }

    if (image != NULL)
        CGContextDrawImage(ctx, dest, image);
    else
        [self drawInRect: NSMakeRect(dest.origin.x, dest.origin.y,
                                     dest.size.width, dest.size.height)];

    CGContextRestoreGState(ctx);
    if (owned != NULL)
        CGImageRelease(owned);
    return YES;
}

- (NSString *) description {
    return [NSString
            stringWithFormat:
                    @"<%@[%p] size: { %f, %f } colorSpace: %@ (%dx%d @ "
                    @"%ld bps) alpha: %@ opaque: %@>",
                    [self class], self, _size.width, _size.height,
                    _colorSpaceName, _pixelsWide, _pixelsHigh, (long) _bitsPerSample,
                    _hasAlpha ? @"YES" : @"NO", _isOpaque ? @"YES" : @"NO"];
}

@end
