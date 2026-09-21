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

#import <AppKit/NSColor_CGColor.h>
#import <AppKit/NSColor_catalog.h>
#import <AppKit/NSDisplay.h>
#import <AppKit/NSGraphics.h>
#import <CoreGraphics/CGColor.h>

@interface NSColor (NSAppKitPrivate)
- (CGColorRef) CGColorRef;
@end

void NSColorSetCatalogColor(NSColorListName catalogName, NSColorName colorName,
                            NSColor *color);
NSColor *NSColorGetCatalogColor(NSColorListName catalogName,
                                NSColorName colorName);

static NSColor *NSColorCatalogFallbackColor(void) {
    return [NSColor colorWithCalibratedRed: 0.93
                                     green: 0.93
                                      blue: 0.93
                                     alpha: 1.0];
}

static CGColorRef NSColorCatalogFallbackCGColor(void) {
    static CGColorRef cached = NULL;
    if (cached == NULL)
        cached = CGColorCreateGenericRGB(0.93, 0.93, 0.93, 1.0);
    return cached;
}

@implementation NSColor_catalog

- (NSColor *) _resolvedColor {
    if (_color != nil && _color != self)
        return _color;

    NSColor *looked = nil;
    if (_catalogName != nil && _colorName != nil)
        looked = NSColorGetCatalogColor(_catalogName, _colorName);
    if ((looked == nil || looked == self) && _colorName != nil)
        looked = [[NSDisplay currentDisplay] colorWithName: _colorName];
    if (looked == nil || looked == self)
        looked = NSColorCatalogFallbackColor();
    if (looked != nil && looked != self) {
        [_color release];
        _color = [looked retain];
    }
    return _color;
}

- initWithCatalogName: (NSColorListName) catalogName
            colorName: (NSColorName) colorName
                color: (NSColor *) color
{
    self = [super init];
    if (self == nil)
        return nil;

    /* Nil catalogName used to leave a NULL CF that dealloc released as an
       object. Always own a real string. */
    if (catalogName != nil)
        _catalogName = [catalogName copy];
    else
        _catalogName = [@"System" copy];
    _colorName = [colorName copy];

    NSColor *backing = color;
    if (backing == nil || backing == self) {
        if (_colorName != nil)
            backing = [[NSDisplay currentDisplay] colorWithName: _colorName];
    }
    if (backing == nil || backing == self)
        backing = NSColorCatalogFallbackColor();
    /* Retain, never copy: NSColor copyWithZone is retain, and a converted
       autoreleased color must not be stored without a +1. */
    _color = [backing retain];
    return self;
}

- (void) dealloc {
    /* Chrome ImmediateCrash during [_color release] of a dangling /
       over-released backing CF. Nil ivars first so a re-entrant release
       cannot double-free. Never NSDeallocateObject — associated objects
       on NSColor must run through NSObject. nscolor_catalog_dealloc_v1 */
    __attribute__((used)) static const char nscolor_catalog_dealloc_v1[] =
            "nscolor_catalog_dealloc_v1";
    (void) nscolor_catalog_dealloc_v1;

    NSColorListName catalogName = _catalogName;
    NSColorName colorName = _colorName;
    NSColor *color = _color;
    _catalogName = nil;
    _colorName = nil;
    _color = nil;
    if (catalogName != nil)
        [catalogName release];
    if (colorName != nil)
        [colorName release];
    if (color != nil && color != (NSColor *) self)
        [color release];
    [super dealloc];
}

- (BOOL) isEqual: otherObject {
    if (self == otherObject)
        return YES;

    if ([otherObject isKindOfClass: [self class]]) {
        NSColor_catalog *other = otherObject;

        return ([_catalogName isEqualToString: other->_catalogName] &&
                [_colorName isEqualToString: other->_colorName]);
    }

    return NO;
}

- (NSString *) description {
    return [NSString stringWithFormat: @"<%@ catalogName: %@ colorName: %@>",
                                       [[self class] description], _catalogName,
                                       _colorName];
}

+ (NSColor *) colorWithCatalogName: (NSColorListName) catalogName
                         colorName: (NSColorName) colorName
{
    NSColor *backing = nil;
    if (colorName != nil)
        backing = [[NSDisplay currentDisplay] colorWithName: colorName];
    return [[[self alloc] initWithCatalogName: catalogName
                                    colorName: colorName
                                        color: backing] autorelease];
}

+ (NSColor *) colorWithCatalogName: (NSColorListName) catalogName
                         colorName: (NSColorName) colorName
                             color: (NSColor *) color
{
    if (NSColorGetCatalogColor(catalogName, colorName) == nil && color != nil)
        NSColorSetCatalogColor(catalogName, colorName, color);

    return [[[self alloc] initWithCatalogName: catalogName
                                    colorName: colorName
                                        color: color] autorelease];
}

- (NSColorSpaceName) colorSpaceName {
    return NSNamedColorSpace;
}

- (NSColorListName) catalogNameComponent {
    return _catalogName;
}

- (NSColorName) colorNameComponent {
    return _colorName;
}

- (NSImage *) patternImage {
    return [[self _resolvedColor] patternImage];
}

- (NSInteger) numberOfComponents {
    NSColor *resolved = [self _resolvedColor];
    if (resolved == nil || resolved == self)
        return 4;
    return [resolved numberOfComponents];
}

- (void) getRed: (CGFloat *) red
          green: (CGFloat *) green
           blue: (CGFloat *) blue
          alpha: (CGFloat *) alpha
{
    NSColor *resolved = [self _resolvedColor];
    if (resolved == nil || resolved == self) {
        if (red)
            *red = 0.93;
        if (green)
            *green = 0.93;
        if (blue)
            *blue = 0.93;
        if (alpha)
            *alpha = 1.0;
        return;
    }
    [resolved getRed: red green: green blue: blue alpha: alpha];
}

- (CGColorRef) CGColor {
    NSColor *resolved = [self _resolvedColor];
    if (resolved != nil && resolved != self) {
        CGColorRef ref = [resolved CGColor];
        if (ref != nil)
            return ref;
    }
    /* Catalog color with a nil display backing. Chrome NativeTheme
       treats nil CGColor as ImmediateCrash after component CHECKs. */
    return NSColorCatalogFallbackCGColor();
}

- (NSColor *) colorUsingColorSpaceName: (NSColorSpaceName) colorSpace {
    return [self colorUsingColorSpaceName: colorSpace device: nil];
}

- (NSColor *) colorUsingColorSpaceName: (NSColorSpaceName) colorSpace
                                device: (NSDictionary *) device
{
    if (colorSpace != nil &&
        [colorSpace isEqualToString: [self colorSpaceName]])
        return self;

    NSColor *resolved = [self _resolvedColor];
    if (resolved == nil || resolved == self)
        resolved = NSColorCatalogFallbackColor();

    /* Do not overwrite _color with an autoreleased conversion. That left a
       dangling CF; dealloc's [_color release] then ImmediateCrashed in
       Chrome. */
    NSColor *converted =
            [resolved colorUsingColorSpaceName: colorSpace device: device];
    if (converted == nil || converted == self)
        return resolved;
    return converted;
}

- (NSColor *) colorUsingColorSpace: (NSColorSpace *) space {
    NSColor *resolved = [self _resolvedColor];
    if (resolved == nil || resolved == self)
        resolved = NSColorCatalogFallbackColor();
    if (space == nil)
        return resolved;
    NSColor *converted = [resolved colorUsingColorSpace: space];
    if (converted == nil || converted == self)
        return resolved;
    return converted;
}

- (CGColorRef) CGColorRef {
    return [self CGColor];
}

- (void) setFill {
    [[self _resolvedColor] setFill];
}

- (void) setStroke {
    [[self _resolvedColor] setStroke];
}

- (NSColor *) highlightWithLevel: (CGFloat) level {
    printf("STUB %s\n", __PRETTY_FUNCTION__);

    level = MIN(1.0, MAX(0.0, level));

    // TODO: verify if it is a use of blendedColorWithFraction:ofColor:
    // that use highlightColor
    // NSLog(@"Level %f", level);

    return self;
}

@end
