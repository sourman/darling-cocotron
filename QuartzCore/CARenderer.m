#import <CoreVideo/CoreVideo.h>
#import <Onyx2D/O2Surface.h>
#import <Onyx2D/O2Image.h>
#import <OpenGL/OpenGL.h>
#import <OpenGL/CGLInternal.h>
#import <QuartzCore/CAAnimation.h>
#import <QuartzCore/CAMediaTimingFunction.h>
#import <QuartzCore/CARenderer.h>
#import "CALayerInternal.h"
#import <dlfcn.h>
#import <stdio.h>
#import <objc/runtime.h>

NSString *const kCARendererColorSpace = @"kCARendererColorSpace";

@implementation CARenderer

- (CGRect) bounds {
    return _bounds;
}

- (void) setBounds: (CGRect) value {
    _bounds = value;
}

@synthesize layer = _rootLayer;

- initWithCGLContext: (void *) cglContext options: (NSDictionary *) options {
    _cglContext = cglContext;
    _bounds = CGRectZero;
    _rootLayer = nil;
    return self;
}

+ (CARenderer *) rendererWithCGLContext: (void *) cglContext
                                options: (NSDictionary *) options
{
    return [[[self alloc] initWithCGLContext: cglContext
                                     options: options] autorelease];
}

static void startAnimationsInLayer(CALayer *layer, CFTimeInterval currentTime) {
    NSArray *keys = [layer animationKeys];

    for (NSString *key in keys) {
        CAAnimation *check = [layer animationForKey: key];

        if ([check beginTime] == 0.0)
            [check setBeginTime: currentTime];
        if (currentTime > [check beginTime] + [check duration]) {
            [layer removeAnimationForKey: key];
        }
    }

    for (CALayer *child in layer.sublayers)
        startAnimationsInLayer(child, currentTime);
}

- (void) beginFrameAtTime: (CFTimeInterval) currentTime
                timeStamp: (CVTimeStamp *) timeStamp
{
    startAnimationsInLayer(_rootLayer, currentTime);
}

static inline CGFloat cubed(CGFloat value) {
    return value * value * value;
}

static inline CGFloat squared(CGFloat value) {
    return value * value;
}

static CGFloat applyMediaTimingFunction(CAMediaTimingFunction *function,
                                        CGFloat t)
{
    CGFloat result;
    CGFloat cp1[2];
    CGFloat cp2[2];

    [function getControlPointAtIndex: 1 values: cp1];
    [function getControlPointAtIndex: 2 values: cp2];

    double x = cubed(1.0 - t) * 0.0 + 3 * squared(1 - t) * t * cp1[0] +
               3 * (1 - t) * squared(t) * cp2[0] + cubed(t) * 1.0;
    double y = cubed(1.0 - t) * 0.0 + 3 * squared(1 - t) * t * cp1[1] +
               3 * (1 - t) * squared(t) * cp2[1] + cubed(t) * 1.0;

    // this is wrong
    return y;
}

static CGFloat mediaTimingScale(CAAnimation *animation,
                                CFTimeInterval currentTime)
{
    CFTimeInterval begin = [animation beginTime];
    CFTimeInterval duration = [animation duration];
    CFTimeInterval delta = currentTime - begin;
    double zeroToOne = delta / duration;
    CAMediaTimingFunction *function = [animation timingFunction];

    if (function == nil)
        function = [CAMediaTimingFunction
                functionWithName: kCAMediaTimingFunctionDefault];

    return applyMediaTimingFunction(function, zeroToOne);
}

static CGFloat interpolateFloatInLayerKey(CALayer *layer, NSString *key,
                                          CFTimeInterval currentTime)
{
    CAAnimation *animation = [layer animationForKey: key];

    if (animation == nil)
        return [[layer valueForKey: key] floatValue];

    if ([animation isKindOfClass: [CABasicAnimation class]]) {
        CABasicAnimation *basic = (CABasicAnimation *) animation;

        id fromValue = [basic fromValue];
        id toValue = [basic toValue];

        if (toValue == nil)
            toValue = [layer valueForKey: key];

        CGFloat fromFloat = [fromValue floatValue];
        CGFloat toFloat = [toValue floatValue];

        CGFloat resultFloat;
        double timingScale = mediaTimingScale(animation, currentTime);

        resultFloat = fromFloat + (toFloat - fromFloat) * timingScale;

        return resultFloat;
    }

    return 0;
}

static CGPoint interpolatePointInLayerKey(CALayer *layer, NSString *key,
                                          CFTimeInterval currentTime)
{
    CAAnimation *animation = [layer animationForKey: key];

    if (animation == nil)
        return [[layer valueForKey: key] pointValue];

    if ([animation isKindOfClass: [CABasicAnimation class]]) {
        CABasicAnimation *basic = (CABasicAnimation *) animation;

        id fromValue = [basic fromValue];
        id toValue = [basic toValue];

        if (toValue == nil)
            toValue = [layer valueForKey: key];

        CGPoint fromPoint = [fromValue pointValue];
        CGPoint toPoint = [toValue pointValue];

        CGPoint resultPoint;
        double timingScale = mediaTimingScale(animation, currentTime);

        resultPoint.x = fromPoint.x + (toPoint.x - fromPoint.x) * timingScale;
        resultPoint.y = fromPoint.y + (toPoint.y - fromPoint.y) * timingScale;

        return resultPoint;
    }

    return CGPointMake(0, 0);
}

static CGRect interpolateRectInLayerKey(CALayer *layer, NSString *key,
                                        CFTimeInterval currentTime)
{
    CAAnimation *animation = [layer animationForKey: key];

    if (animation == nil) {
        return [[layer valueForKey: key] rectValue];
    }

    if ([animation isKindOfClass: [CABasicAnimation class]]) {
        CABasicAnimation *basic = (CABasicAnimation *) animation;

        id fromValue = [basic fromValue];
        id toValue = [basic toValue];

        if (toValue == nil)
            toValue = [layer valueForKey: key];

        CGRect fromRect = [fromValue rectValue];
        CGRect toRect = [toValue rectValue];

        double timingScale = mediaTimingScale(animation, currentTime);

        CGRect resultRect;

        resultRect.origin.x =
                fromRect.origin.x +
                (toRect.origin.x - fromRect.origin.x) * timingScale;
        resultRect.origin.y =
                fromRect.origin.y +
                (toRect.origin.y - fromRect.origin.y) * timingScale;
        resultRect.size.width =
                fromRect.size.width +
                (toRect.size.width - fromRect.size.width) * timingScale;
        resultRect.size.height =
                fromRect.size.height +
                (toRect.size.height - fromRect.size.height) * timingScale;

        return resultRect;
    }

    return CGRectMake(0, 0, 0, 0);
}

static GLint interpolationFromName(NSString *name) {
    if (name == kCAFilterLinear)
        return GL_LINEAR;
    else if (name == kCAFilterNearest)
        return GL_NEAREST;
    else if ([name isEqualToString: kCAFilterLinear])
        return GL_LINEAR;
    else if ([name isEqualToString: kCAFilterNearest])
        return GL_NEAREST;
    else
        return GL_LINEAR;
}

void CATexImage2DCGImage(CGImageRef image) {
    if (!image || ![(id) image isKindOfClass: [O2Image class]])
        return;

    size_t imageWidth = CGImageGetWidth(image);
    size_t imageHeight = CGImageGetHeight(image);
    if (imageWidth < 1 || imageHeight < 1)
        return;

    CGBitmapInfo bitmapInfo = CGImageGetBitmapInfo(image);

    CGDataProviderRef provider = CGImageGetDataProvider(image);
    if (!provider)
        return;
    CFDataRef data = CGDataProviderCopyData(provider);
    if (!data)
        return;
    const uint8_t *pixelBytes = CFDataGetBytePtr(data);
    if (!pixelBytes) {
        CFRelease(data);
        return;
    }

    GLenum glFormat = GL_BGRA;
    GLenum glType = GL_UNSIGNED_INT_8_8_8_8_REV;

    CGImageAlphaInfo alphaInfo = bitmapInfo & kCGBitmapAlphaInfoMask;
    CGBitmapInfo byteOrder = bitmapInfo & kCGBitmapByteOrderMask;

    switch (alphaInfo) {

    case kCGImageAlphaNone:
        break;

    case kCGImageAlphaPremultipliedLast:
        if (byteOrder == kO2BitmapByteOrder32Big) {
            glFormat = GL_RGBA;
            glType = GL_UNSIGNED_INT_8_8_8_8_REV;
        }
        break;

    case kCGImageAlphaPremultipliedFirst: // ARGB
        if (byteOrder == kCGBitmapByteOrder32Little) {
            glFormat = GL_BGRA;
            glType = GL_UNSIGNED_INT_8_8_8_8_REV;
        }
        break;

    case kCGImageAlphaLast:
        break;

    case kCGImageAlphaFirst:
        break;

    case kCGImageAlphaNoneSkipLast:
        break;

    case kCGImageAlphaNoneSkipFirst:
        break;

    case kCGImageAlphaOnly:
        break;
    }

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, imageWidth, imageHeight, 0,
                 glFormat, glType, pixelBytes);
    CGLPutBGRAOnDrawable(CGLGetCurrentContext(), pixelBytes, (int) imageWidth,
                         (int) imageHeight, (int) (imageWidth * 4));
    CFRelease(data);
}

static int CATexImageIOSurface(id contents) {
    typedef CFTypeID (*GetTypeIDFn)(void);
    typedef size_t (*GetSizeFn)(void *);
    typedef void *(*GetBaseFn)(void *);
    typedef int (*LockFn)(void *, uint32_t, uint32_t *);
    static GetTypeIDFn pTypeID;
    static GetSizeFn pWidth, pHeight, pBpr;
    static GetBaseFn pBase;
    static LockFn pLock, pUnlock;
    static int tried;
    if (!tried) {
        tried = 1;
        pTypeID = (GetTypeIDFn) dlsym(RTLD_DEFAULT, "IOSurfaceGetTypeID");
        pWidth = (GetSizeFn) dlsym(RTLD_DEFAULT, "IOSurfaceGetWidth");
        pHeight = (GetSizeFn) dlsym(RTLD_DEFAULT, "IOSurfaceGetHeight");
        pBpr = (GetSizeFn) dlsym(RTLD_DEFAULT, "IOSurfaceGetBytesPerRow");
        pBase = (GetBaseFn) dlsym(RTLD_DEFAULT, "IOSurfaceGetBaseAddress");
        pLock = (LockFn) dlsym(RTLD_DEFAULT, "IOSurfaceLock");
        pUnlock = (LockFn) dlsym(RTLD_DEFAULT, "IOSurfaceUnlock");
    }
    if (!contents || !pTypeID || CFGetTypeID(contents) != pTypeID())
        return 0;
    if (pLock)
        pLock(contents, 1 /* read-only */, NULL);
    size_t w = pWidth ? pWidth(contents) : 0;
    size_t h = pHeight ? pHeight(contents) : 0;
    size_t bpr = pBpr ? pBpr(contents) : 0;
    void *base = pBase ? pBase(contents) : NULL;
    if (base && w > 0 && h > 0) {
        glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, (GLsizei) w, (GLsizei) h, 0,
                     GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, base);
        CGLPutBGRAOnDrawable(CGLGetCurrentContext(), base, (int) w, (int) h,
                             (int) bpr);
    }
    if (pUnlock)
        pUnlock(contents, 1, NULL);
    static int nios = 0;
    if (nios < 8) {
        fprintf(stderr, "CARenderer IOSurface %zux%zu bpr=%zu n=%d\n", w, h,
                bpr, ++nios);
        fflush(stderr);
    }
    return 1;
}

- (void) _renderLayer: (CALayer *) layer
                    z: (CGFloat) z
          currentTime: (CFTimeInterval) currentTime
{
    if (!layer)
        return;

    [layer displayIfNeeded];

    NSNumber *textureId = [layer _textureId];
    GLuint texture = [textureId unsignedIntValue];
    GLboolean loadPixelData = GL_FALSE;

    if (texture == 0)
        loadPixelData = GL_TRUE;
    else {

        if (glIsTexture(texture) == GL_FALSE) {
            loadPixelData = GL_TRUE;
        }
        glBindTexture(GL_TEXTURE_2D, texture);
    }

    id contents = layer.contents;
    if (loadPixelData) {
        if ([contents isKindOfClass: [O2Image class]])
            CATexImage2DCGImage((CGImageRef) contents);
        else if (contents && !CATexImageIOSurface(contents)) {
            static int nskip = 0;
            if (nskip < 8) {
                fprintf(stderr, "CARenderer skip contents class=%s\n",
                        class_getName([contents class]));
                fflush(stderr);
                nskip++;
            }
        }

        GLint minFilter = interpolationFromName(layer.minificationFilter);
        GLint magFilter = interpolationFromName(layer.magnificationFilter);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, minFilter);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, magFilter);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    } else if ([contents isKindOfClass: [O2Image class]]) {
        /* Keep presenting CPU pixels even after the GL texture exists. */
        CGImageRef image = (CGImageRef) contents;
        CGDataProviderRef provider = CGImageGetDataProvider(image);
        CFDataRef data = provider ? CGDataProviderCopyData(provider) : NULL;
        if (data) {
            const uint8_t *pixelBytes = CFDataGetBytePtr(data);
            if (pixelBytes)
                CGLPutBGRAOnDrawable(CGLGetCurrentContext(), pixelBytes,
                                     (int) CGImageGetWidth(image),
                                     (int) CGImageGetHeight(image),
                                     (int) (CGImageGetWidth(image) * 4));
            CFRelease(data);
        }
    } else if (contents) {
        CATexImageIOSurface(contents);
    }

    CGPoint anchorPoint =
            interpolatePointInLayerKey(layer, @"anchorPoint", currentTime);
    CGPoint position =
            interpolatePointInLayerKey(layer, @"position", currentTime);
    CGRect bounds = interpolateRectInLayerKey(layer, @"bounds", currentTime);
    CGFloat opacity =
            interpolateFloatInLayerKey(layer, @"opacity", currentTime);

    GLfloat textureVertices[4 * 2];
    GLfloat vertices[4 * 3];

    textureVertices[0] = 0;
    textureVertices[1] = 1;
    textureVertices[2] = 1;
    textureVertices[3] = 1;
    textureVertices[4] = 0;
    textureVertices[5] = 0;
    textureVertices[6] = 1;
    textureVertices[7] = 0;

    vertices[0] = 0;
    vertices[1] = 0;
    vertices[2] = z;

    vertices[3] = bounds.size.width;
    vertices[4] = 0;
    vertices[5] = z;

    vertices[6] = 0;
    vertices[7] = bounds.size.height;
    vertices[8] = z;

    vertices[9] = bounds.size.width;
    vertices[10] = bounds.size.height;
    vertices[11] = z;

    glPushMatrix();
    //  glTranslatef(width/2,height/2,0);
    glTexCoordPointer(2, GL_FLOAT, 0, textureVertices);
    glVertexPointer(3, GL_FLOAT, 0, vertices);

    glTranslatef(position.x - (bounds.size.width * anchorPoint.x),
                 position.y - (bounds.size.height * anchorPoint.y), 0);
    // glTranslatef(position.x,position.y,0);
    // glScalef(bounds.size.width,bounds.size.height,1);

    //  glRotatef(1,0,0,1);
    glColor4f(opacity, opacity, opacity, opacity);

    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

    for (CALayer *child in layer.sublayers)
        [self _renderLayer: child z: z + 1 currentTime: currentTime];

    glPopMatrix();
}

- (void) render {
    glMatrixMode(GL_MODELVIEW);
    glLoadIdentity();

    glClearColor(0, 0, 0, 1);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LEQUAL);

    glEnable(GL_TEXTURE_2D);
    glEnableClientState(GL_VERTEX_ARRAY);
    glEnableClientState(GL_TEXTURE_COORD_ARRAY);

    glEnable(GL_BLEND);
    glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);

    glAlphaFunc(GL_GREATER, 0);
    glEnable(GL_ALPHA_TEST);

    [self _renderLayer: _rootLayer z: 0 currentTime: CACurrentMediaTime()];

    glFlush();
}

- (void) endFrame {
}

@end
