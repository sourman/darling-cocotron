#import <Foundation/NSDictionary.h>
#import <Foundation/NSNumber.h>
#import <QuartzCore/CAAnimation.h>
#import <QuartzCore/CALayer.h>
#import <QuartzCore/CALayerContext.h>
#import <QuartzCore/CATransaction.h>
#import <objc/runtime.h>

NSString *const kCAFilterLinear = @"linear";
NSString *const kCAFilterNearest = @"nearest";
NSString *const kCAFilterTrilinear = @"trilinear";

NSString *const kCAGravityResizeAspect = @"resizeAspect";
NSString *const kCAGravityResizeAspectFill = @"resizeAspectFill";

NSString *const kCAGravityCenter = @"center";
NSString *const kCAGravityTop = @"top";
NSString *const kCAGravityBottom = @"bottom";
NSString *const kCAGravityLeft = @"left";
NSString *const kCAGravityRight = @"right";
NSString *const kCAGravityTopLeft = @"topLeft";
NSString *const kCAGravityTopRight = @"topRight";
NSString *const kCAGravityBottomLeft = @"bottomLeft";
NSString *const kCAGravityBottomRight = @"bottomRight";
NSString *const kCAGravityResize = @"resize";

NSString *const kCAOnOrderIn = @"onOrderIn";
NSString *const kCAOnOrderOut = @"onOrderOut";
NSString *const kCATransition = @"transition";

NSString *const kCAContentsFormatRGBA8Uint = @"RGBA8";
NSString *const kCAContentsFormatRGBA16Float = @"RGBAh";
NSString *const kCAContentsFormatGray8Uint = @"Gray8";

@implementation CALayer

+ layer {
    return [[[self alloc] init] autorelease];
}

- (CALayerContext *) _context {
    return _context;
}

- (void) _setContext: (CALayerContext *) context {
    if (_context != context) {
        [_context deleteTextureId: _textureId];
        [_textureId release];
        _textureId = nil;
    }

    _context = context;
    [_sublayers makeObjectsPerformSelector: @selector(_setContext:)
                                withObject: context];
}

- (CALayer *) superlayer {
    return _superlayer;
}

- (NSArray *) sublayers {
    return _sublayers;
}

- (void) setSublayers: (NSArray *) sublayers {
    sublayers = [sublayers copy];
    [_sublayers release];
    _sublayers = sublayers;
    [_sublayers makeObjectsPerformSelector: @selector(_setSuperLayer:)
                                withObject: self];
    [_sublayers makeObjectsPerformSelector: @selector(_setContext:)
                                withObject: _context];
}

- (id<CALayerDelegate>) delegate {
    return _delegate;
}

- (void) setDelegate: (id<CALayerDelegate>)value {
    _delegate = value;
}

- (CGPoint) anchorPoint {
    return _anchorPoint;
}

- (void) setAnchorPoint: (CGPoint) value {
    _anchorPoint = value;
}

- (CGPoint) position {
    return _position;
}

- (void) setPosition: (CGPoint) value {
    CAAnimation *animation = [self animationForKey: @"position"];

    if (animation == nil && ![CATransaction disableActions]) {
        id action = [self actionForKey: @"position"];

        if (action != nil)
            [self addAnimation: action forKey: @"position"];
    }

    _position = value;
}

- (CGRect) bounds {
    return _bounds;
}

- (void) setBounds: (CGRect) value {
    CAAnimation *animation = [self animationForKey: @"bounds"];

    if (animation == nil && ![CATransaction disableActions]) {
        id action = [self actionForKey: @"bounds"];

        if (action != nil)
            [self addAnimation: action forKey: @"bounds"];
    }

    _bounds = value;
}

- (CGRect) frame {
    CGRect result;

    result.size = _bounds.size;
    result.origin.x = _position.x - result.size.width * _anchorPoint.x;
    result.origin.y = _position.y - result.size.height * _anchorPoint.y;

    return result;
}

- (void) setFrame: (CGRect) value {

    CGPoint position;

    position.x = value.origin.x + value.size.width * _anchorPoint.x;
    position.y = value.origin.y + value.size.height * _anchorPoint.y;

    [self setPosition: position];

    CGRect bounds = _bounds;

    bounds.size = value.size;

    [self setBounds: bounds];
}

- (CGFloat) opacity {
    return _opacity;
}

- (void) setOpacity: (CGFloat) value {
    CAAnimation *animation = [self animationForKey: @"opacity"];

    if (animation == nil && ![CATransaction disableActions]) {
        id action = [self actionForKey: @"opacity"];

        if (action != nil)
            [self addAnimation: action forKey: @"opacity"];
    }

    _opacity = value;
}

- (BOOL) opaque {
    return _opaque;
}

- (void) setOpaque: (BOOL) value {
    _opaque = value;
}

static const void *kCALayerGeometryFlipped;
static const void *kCALayerAutoresizingMask;
static const void *kCALayerContentsScale;
static const void *kCALayerMasksToBounds;
static const void *kCALayerHidden;
static const void *kCALayerNeedsDisplayOnBoundsChange;
static const void *kCALayerCornerRadius;
static const void *kCALayerBorderWidth;
static const void *kCALayerBackgroundColor;
static const void *kCALayerBorderColor;
static const void *kCALayerContentsGravity;
static const void *kCALayerEdgeAntialiasingMask;
static const void *kCALayerAllowsEdgeAntialiasing;
static const void *kCALayerAllowsGroupOpacity;
static const void *kCALayerDoubleSided;
static const void *kCALayerZPosition;
static const void *kCALayerName;
static const void *kCALayerLayoutManager;
static const void *kCALayerShouldRasterize;
static const void *kCALayerRasterizationScale;

#define CA_ASSOC_BOOL(key) \
    [objc_getAssociatedObject(self, key) boolValue]
#define CA_SET_BOOL(key, v) \
    objc_setAssociatedObject(self, key, [NSNumber numberWithBool: (v)], OBJC_ASSOCIATION_RETAIN)
#define CA_ASSOC_UINT(key) \
    [objc_getAssociatedObject(self, key) unsignedIntValue]
#define CA_SET_UINT(key, v) \
    objc_setAssociatedObject(self, key, [NSNumber numberWithUnsignedInt: (v)], OBJC_ASSOCIATION_RETAIN)
#define CA_ASSOC_FLOAT(key, dflt) \
    ({ NSNumber *_n = objc_getAssociatedObject(self, key); _n ? [_n doubleValue] : (dflt); })
#define CA_SET_FLOAT(key, v) \
    objc_setAssociatedObject(self, key, [NSNumber numberWithDouble: (v)], OBJC_ASSOCIATION_RETAIN)

- (BOOL) geometryFlipped {
    return CA_ASSOC_BOOL(&kCALayerGeometryFlipped);
}
- (void) setGeometryFlipped: (BOOL) value {
    CA_SET_BOOL(&kCALayerGeometryFlipped, value);
}

- (unsigned int) autoresizingMask {
    return CA_ASSOC_UINT(&kCALayerAutoresizingMask);
}
- (void) setAutoresizingMask: (unsigned int) value {
    CA_SET_UINT(&kCALayerAutoresizingMask, value);
}

- (CGFloat) contentsScale {
    return CA_ASSOC_FLOAT(&kCALayerContentsScale, 1.0);
}
- (void) setContentsScale: (CGFloat) value {
    CA_SET_FLOAT(&kCALayerContentsScale, value);
}

- (BOOL) masksToBounds {
    return CA_ASSOC_BOOL(&kCALayerMasksToBounds);
}
- (void) setMasksToBounds: (BOOL) value {
    CA_SET_BOOL(&kCALayerMasksToBounds, value);
}

- (BOOL) isHidden {
    return CA_ASSOC_BOOL(&kCALayerHidden);
}
- (void) setHidden: (BOOL) value {
    CA_SET_BOOL(&kCALayerHidden, value);
}

- (BOOL) needsDisplayOnBoundsChange {
    return CA_ASSOC_BOOL(&kCALayerNeedsDisplayOnBoundsChange);
}
- (void) setNeedsDisplayOnBoundsChange: (BOOL) value {
    CA_SET_BOOL(&kCALayerNeedsDisplayOnBoundsChange, value);
}

- (CGFloat) cornerRadius {
    return CA_ASSOC_FLOAT(&kCALayerCornerRadius, 0);
}
- (void) setCornerRadius: (CGFloat) value {
    CA_SET_FLOAT(&kCALayerCornerRadius, value);
}

- (CGFloat) borderWidth {
    return CA_ASSOC_FLOAT(&kCALayerBorderWidth, 0);
}
- (void) setBorderWidth: (CGFloat) value {
    CA_SET_FLOAT(&kCALayerBorderWidth, value);
}

- (CGColorRef) backgroundColor {
    return (CGColorRef) objc_getAssociatedObject(self, &kCALayerBackgroundColor);
}
- (void) setBackgroundColor: (CGColorRef) value {
    objc_setAssociatedObject(self, &kCALayerBackgroundColor, (id) value, OBJC_ASSOCIATION_RETAIN);
}

- (CGColorRef) borderColor {
    return (CGColorRef) objc_getAssociatedObject(self, &kCALayerBorderColor);
}
- (void) setBorderColor: (CGColorRef) value {
    objc_setAssociatedObject(self, &kCALayerBorderColor, (id) value, OBJC_ASSOCIATION_RETAIN);
}

- (NSString *) contentsGravity {
    NSString *g = objc_getAssociatedObject(self, &kCALayerContentsGravity);
    return g ? g : kCAGravityResize;
}
- (void) setContentsGravity: (NSString *) value {
    objc_setAssociatedObject(self, &kCALayerContentsGravity, value, OBJC_ASSOCIATION_COPY);
}

- (unsigned int) edgeAntialiasingMask {
    NSNumber *n = objc_getAssociatedObject(self, &kCALayerEdgeAntialiasingMask);
    return n ? [n unsignedIntValue] : 0x0f;
}
- (void) setEdgeAntialiasingMask: (unsigned int) value {
    CA_SET_UINT(&kCALayerEdgeAntialiasingMask, value);
}

- (BOOL) allowsEdgeAntialiasing {
    NSNumber *n = objc_getAssociatedObject(self, &kCALayerAllowsEdgeAntialiasing);
    return n ? [n boolValue] : YES;
}
- (void) setAllowsEdgeAntialiasing: (BOOL) value {
    CA_SET_BOOL(&kCALayerAllowsEdgeAntialiasing, value);
}

- (BOOL) allowsGroupOpacity {
    NSNumber *n = objc_getAssociatedObject(self, &kCALayerAllowsGroupOpacity);
    return n ? [n boolValue] : YES;
}
- (void) setAllowsGroupOpacity: (BOOL) value {
    CA_SET_BOOL(&kCALayerAllowsGroupOpacity, value);
}

- (BOOL) isDoubleSided {
    NSNumber *n = objc_getAssociatedObject(self, &kCALayerDoubleSided);
    return n ? [n boolValue] : YES;
}
- (void) setDoubleSided: (BOOL) value {
    CA_SET_BOOL(&kCALayerDoubleSided, value);
}

- (CGFloat) zPosition {
    return CA_ASSOC_FLOAT(&kCALayerZPosition, 0);
}
- (void) setZPosition: (CGFloat) value {
    CA_SET_FLOAT(&kCALayerZPosition, value);
}

- (NSString *) name {
    return objc_getAssociatedObject(self, &kCALayerName);
}
- (void) setName: (NSString *) value {
    objc_setAssociatedObject(self, &kCALayerName, value, OBJC_ASSOCIATION_COPY);
}

- (id) layoutManager {
    return objc_getAssociatedObject(self, &kCALayerLayoutManager);
}
- (void) setLayoutManager: (id) value {
    objc_setAssociatedObject(self, &kCALayerLayoutManager, value, OBJC_ASSOCIATION_RETAIN);
}

- (BOOL) shouldRasterize {
    return CA_ASSOC_BOOL(&kCALayerShouldRasterize);
}
- (void) setShouldRasterize: (BOOL) value {
    CA_SET_BOOL(&kCALayerShouldRasterize, value);
}

- (CGFloat) rasterizationScale {
    return CA_ASSOC_FLOAT(&kCALayerRasterizationScale, 1.0);
}
- (void) setRasterizationScale: (CGFloat) value {
    CA_SET_FLOAT(&kCALayerRasterizationScale, value);
}

- (id) contents {
    return _contents;
}

- (void) setContents: (id) value {
    value = [value retain];
    [_contents release];
    _contents = value;
}

- (CATransform3D) transform {
    return _transform;
}

- (void) setTransform: (CATransform3D) value {
    _transform = value;
}

- (CATransform3D) sublayerTransform {
    return _sublayerTransform;
}

- (void) setSublayerTransform: (CATransform3D) value {
    _sublayerTransform = value;
}

- (NSString *) minificationFilter {
    return _minificationFilter;
}

- (void) setMinificationFilter: (NSString *) value {
    value = [value copy];
    [_minificationFilter release];
    _minificationFilter = value;
}

- (NSString *) magnificationFilter {
    return _magnificationFilter;
}

- (void) setMagnificationFilter: (NSString *) value {
    value = [value copy];
    [_magnificationFilter release];
    _magnificationFilter = value;
}

- init {
    _superlayer = nil;
    _sublayers = [NSArray new];
    _delegate = nil;
    _anchorPoint = CGPointMake(0.5, 0.5);
    _position = CGPointZero;
    _bounds = CGRectZero;
    _opacity = 1.0;
    _opaque = YES;
    _contents = nil;
    _transform = CATransform3DIdentity;
    _sublayerTransform = CATransform3DIdentity;
    _minificationFilter = kCAFilterLinear;
    _magnificationFilter = kCAFilterLinear;
    _animations = [[NSMutableDictionary alloc] init];
    return self;
}

- (void) dealloc {
    [_sublayers release];
    [_animations release];
    [_minificationFilter release];
    [_magnificationFilter release];
    [super dealloc];
}

- (void) _setSuperLayer: (CALayer *) parent {
    _superlayer = parent;
}

- (void) _removeSublayer: (CALayer *) child {
    NSMutableArray *layers = [_sublayers mutableCopy];
    [layers removeObjectIdenticalTo: child];
    [self setSublayers: layers];
    [layers release];
}

- (void) addSublayer: (CALayer *) layer {
    [self setSublayers: [_sublayers arrayByAddingObject: layer]];
}

- (void) replaceSublayer: (CALayer *) layer with: (CALayer *) other {
    NSMutableArray *layers = [_sublayers mutableCopy];
    NSUInteger index = [_sublayers indexOfObjectIdenticalTo: layer];

    [layers replaceObjectAtIndex: index withObject: other];

    [self setSublayers: layers];
    [layers release];

    layer->_superlayer = nil;
}

- (void) display {
    if ([_delegate respondsToSelector: @selector(displayLayer:)])
        [_delegate displayLayer: self];
    else {
#if 0

#warning create bitmap context

    [self drawInContext:context];
    _contents=image;
    [self setContents:image];
#endif
    }
}

- (void) displayIfNeeded {
    if (_needsDisplay) {
        [self display];
        _needsDisplay = NO;
    }
}

- (void) drawInContext: (CGContextRef) context {
    if ([_delegate respondsToSelector: @selector(drawLayer:inContext:)])
        [_delegate drawLayer: self inContext: context];
}

- (BOOL) needsDisplay {
    return _needsDisplay;
}

- (void) removeFromSuperlayer {
    [_superlayer _removeSublayer: self];
    _superlayer = nil;
    [self _setContext: nil];
}

- (void) setNeedsDisplay {
    _needsDisplay = YES;
}

- (void) setNeedsDisplayInRect: (CGRect) rect {
    _needsDisplay = YES;
}

- (void) addAnimation: (CAAnimation *) animation forKey: (NSString *) key {
    if (_context == nil)
        return;

    [_animations setObject: animation forKey: key];
    [_context startTimerIfNeeded];
}

- (CAAnimation *) animationForKey: (NSString *) key {
    return [_animations objectForKey: key];
}

- (void) removeAllAnimations {
    [_animations removeAllObjects];
}

- (void) removeAnimationForKey: (NSString *) key {
    [_animations removeObjectForKey: key];
}

- (NSArray *) animationKeys {
    return [_animations allKeys];
}

- valueForKey: (NSString *) key {
    // FIXME: KVC appears broken for structs

    if ([key isEqualToString: @"bounds"])
        return [NSValue valueWithRect: _bounds];
    if ([key isEqualToString: @"frame"])
        return [NSValue valueWithRect: [self frame]];

    return [super valueForKey: key];
}

- (id<CAAction>) actionForKey: (NSString *) key {
    CABasicAnimation *basic = [CABasicAnimation animationWithKeyPath: key];

    [basic setFromValue: [self valueForKey: key]];

    return basic;
}

- (NSNumber *) _textureId {
    return _textureId;
}

- (void) _setTextureId: (NSNumber *) value {
    value = [value copy];
    [_textureId release];
    _textureId = value;
}

@end
