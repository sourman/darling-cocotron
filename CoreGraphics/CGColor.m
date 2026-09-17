/* Copyright (c) 2007 Christopher J. W. Lloyd

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

#import <CoreGraphics/CGColor.h>
#import <Onyx2D/O2Color.h>
#import <Onyx2D/O2ColorSpace.h>

CGColorRef CGColorRetain(CGColorRef self) {
    return (CGColorRef)O2ColorRetain((O2ColorRef)self);
}

void CGColorRelease(CGColorRef self) {
    O2ColorRelease((O2ColorRef)self);
}

CGColorRef CGColorCreate(CGColorSpaceRef colorSpace, const CGFloat *components)
{
    return (CGColorRef)O2ColorCreate((O2ColorSpaceRef)colorSpace, components);
}

CGColorRef CGColorCreateGenericGray(CGFloat gray, CGFloat a) {
    return (CGColorRef)O2ColorCreateGenericGray(gray, a);
}

CGColorRef CGColorCreateGenericRGB(CGFloat r, CGFloat g, CGFloat b, CGFloat a) {
    return (CGColorRef)O2ColorCreateGenericRGB(r, g, b, a);
}

CGColorRef CGColorCreateGenericCMYK(CGFloat c, CGFloat m, CGFloat y, CGFloat k,
                                    CGFloat a)
{
    return (CGColorRef)O2ColorCreateGenericCMYK(c, m, y, k, a);
}

CGColorRef CGColorCreateWithPattern(CGColorSpaceRef colorSpace,
                                    CGPatternRef pattern,
                                    const CGFloat *components)
{
    return (CGColorRef)O2ColorCreateWithPattern((O2ColorSpaceRef)colorSpace, (O2PatternRef)pattern, components);
}

CGColorRef CGColorCreateCopy(CGColorRef self) {
    return (CGColorRef)O2ColorCreateCopy((O2ColorRef)self);
}

CGColorRef CGColorCreateCopyWithAlpha(CGColorRef self, CGFloat a) {
    return (CGColorRef)O2ColorCreateCopyWithAlpha((O2ColorRef)self, a);
}

CGColorRef CGColorCreateCopyByMatchingToColorSpace(
        CGColorSpaceRef space, CGColorRenderingIntent intent, CGColorRef color,
        CFDictionaryRef options)
{
    /* Apple converts `color` into `space`. Chrome's CGColorRefToSkColor
       always calls this; a void stub returning NULL made the previous
       O2Color NULL getters look like a 4-component clear and then
       NativeTheme serialized a garbage enum. cgcolor_match_srgb_v1 */
    __attribute__((used)) static const char cgcolor_match_srgb_v1[] =
            "cgcolor_match_srgb_v1";
    (void) cgcolor_match_srgb_v1;
    (void) intent;
    (void) options;
    if (color == NULL)
        return NULL;
    if (space == NULL)
        return CGColorCreateCopy(color);

    const CGFloat *c = CGColorGetComponents(color);
    size_t n = CGColorGetNumberOfComponents(color);
    CGColorSpaceModel srcModel = CGColorSpaceGetModel(CGColorGetColorSpace(color));
    CGFloat rgba[4] = {0, 0, 0, 1};
    if (srcModel == kCGColorSpaceModelMonochrome && n >= 1) {
        rgba[0] = rgba[1] = rgba[2] = c[0];
        rgba[3] = (n >= 2) ? c[1] : 1;
    } else if (n >= 4) {
        rgba[0] = c[0];
        rgba[1] = c[1];
        rgba[2] = c[2];
        rgba[3] = c[3];
    } else if (n >= 3) {
        rgba[0] = c[0];
        rgba[1] = c[1];
        rgba[2] = c[2];
    }
    if (CGColorSpaceGetModel(space) == kCGColorSpaceModelMonochrome) {
        CGFloat gray[2];
        gray[0] = (CGFloat) (0.299 * rgba[0] + 0.587 * rgba[1] + 0.114 * rgba[2]);
        gray[1] = rgba[3];
        return CGColorCreate(space, gray);
    }
    return CGColorCreate(space, rgba);
}

bool CGColorEqualToColor(CGColorRef self, CGColorRef other) {
    return O2ColorEqualToColor((O2ColorRef)self, (O2ColorRef)other);
}

CGColorSpaceRef CGColorGetColorSpace(CGColorRef self) {
    return (CGColorSpaceRef)O2ColorGetColorSpace((O2ColorRef)self);
}

size_t CGColorGetNumberOfComponents(CGColorRef self) {
    return O2ColorGetNumberOfComponents((O2ColorRef)self);
}

const CGFloat *CGColorGetComponents(CGColorRef self) {
    return O2ColorGetComponents((O2ColorRef)self);
}

CGFloat CGColorGetAlpha(CGColorRef self) {
    return O2ColorGetAlpha((O2ColorRef)self);
}

CGPatternRef CGColorGetPattern(CGColorRef self) {
    return (CGPatternRef)O2ColorGetPattern((O2ColorRef)self);
}

CGColorRef CGColorGetConstantColor(CFStringRef colorName) {
    CGColorRef res = NULL;
    if (CFStringCompare(colorName,kCGColorWhite,0) == kCFCompareEqualTo)
        res = CGColorCreateGenericGray(1.0, 1.0);
    if (CFStringCompare(colorName,kCGColorBlack,0) == kCFCompareEqualTo)
        res = CGColorCreateGenericGray(0.0, 1.0);
    if (CFStringCompare(colorName,kCGColorClear,0) == kCFCompareEqualTo)
        res = CGColorCreateGenericGray(0.0, 0.0);

    return CFAutorelease(res);
}

const CFStringRef kCGColorWhite = CFSTR("kCGColorWhite");
const CFStringRef kCGColorBlack = CFSTR("kCGColorBlack");
const CFStringRef kCGColorClear = CFSTR("kCGColorClear");
