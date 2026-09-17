/* Compatibility stubs for macOS 13+ AppKit symbols used by Perplexity Comet. */
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <AppKit/NSView.h>
#import <AppKit/NSButton.h>
#import <AppKit/NSWindow.h>

NSString *NSAccessibilityRequiredAttribute = @"AXRequired";
NSString *NSTouchBarItemIdentifierCandidateList = @"NSTouchBarItemIdentifierCandidateList";

NSString *NSAccessibilityActionDescription(NSString *action)
{
	return action ?: @"";
}

void _NSInitializeKillRing(void) {}
void _NSAppendToKillRing(void) {}
void _NSNewKillRingSequence(void) {}
void _NSSetKillRingToYankedState(void) {}
void *_NSYankFromKillRing(void)
{
	return 0;
}

@interface NSPreviewRepresentingActivityItem : NSObject
@end
@implementation NSPreviewRepresentingActivityItem
@end

@interface NSColorSampler : NSObject
@end
@implementation NSColorSampler
@end

@interface NSGlassEffectView : NSView
@end
@implementation NSGlassEffectView
@end

@interface NSNextStepFrame : NSView
@end
@implementation NSNextStepFrame
@end

@interface NSStatusBarButton : NSButton
@end
@implementation NSStatusBarButton
@end

@interface NSAccessibilityCustomAction : NSObject
@end
@implementation NSAccessibilityCustomAction
@end

/*
 * AppKit-private Services types. Chromium's ChromeSwizzleServicesMenuUpdater
 * CHECKs that these classes exist and respond to the selectors below, then
 * swizzles populateMenu:withServiceEntries:forDisplay: to filter Services
 * items. No registered services on Darling: populate is a no-op, same as an
 * empty Services menu on macOS.
 */
@interface _NSServiceEntry : NSObject
- (NSString *)bundleIdentifier;
- (NSString *)message;
@end
@implementation _NSServiceEntry
- (NSString *)bundleIdentifier
{
	return nil;
}
- (NSString *)message
{
	return nil;
}
@end

@interface _NSServicesMenuUpdater : NSObject
- (void)populateMenu:(id)menu
    withServiceEntries:(id)entries
            forDisplay:(BOOL)display;
@end
@implementation _NSServicesMenuUpdater
- (void)populateMenu:(id)menu
    withServiceEntries:(id)entries
            forDisplay:(BOOL)display
{
}
@end

/*
 * Comet startup cluster: one rebuild covering AppKit selectors Chrome
 * hits before / while creating an NSWindow. Empty arrays, nil, NO, no-op.
 * Do not fake windows.
 */
#import <objc/runtime.h>
#import <AppKit/NSScreen.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSWorkspace.h>
#import <AppKit/NSStatusItem.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSColorSpace.h>
#import <AppKit/NSVisualEffectView.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSImageRep.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSGraphicsContext.h>

const char comet_startup_cluster_stubs_v1[] = "comet_startup_cluster_stubs_v1";
const char comet_nsimage_cluster_v1[] = "comet_nsimage_cluster_v1";
const char comet_nsbitmap_colorspace_v1[] = "comet_nsbitmap_colorspace_v1";
const char comet_nsimagerep_draw_v1[] = "comet_nsimagerep_draw_v1";
__attribute__((used)) const char comet_nswindow_space_v1[] =
        "comet_nswindow_space_v1";

typedef struct {
	CGFloat top;
	CGFloat left;
	CGFloat bottom;
	CGFloat right;
} CometEdgeInsets;

static CometEdgeInsets _cometZeroInsets(void)
{
	CometEdgeInsets insets = {0, 0, 0, 0};
	return insets;
}

@implementation NSScreen (CometStartupCluster)
+ (NSScreen *)deepestScreen
{
	return [self mainScreen];
}
- (CometEdgeInsets)safeAreaInsets
{
	return _cometZeroInsets();
}
- (NSRect)auxiliaryTopLeftArea
{
	return NSZeroRect;
}
- (NSRect)auxiliaryTopRightArea
{
	return NSZeroRect;
}
- (BOOL)canRepresentDisplayGamut:(NSInteger)gamut
{
	return YES;
}
@end

@implementation NSView (CometStartupCluster)
- (CometEdgeInsets)safeAreaInsets
{
	return _cometZeroInsets();
}
- (CometEdgeInsets)additionalSafeAreaInsets
{
	return _cometZeroInsets();
}
- (void)setAdditionalSafeAreaInsets:(CometEdgeInsets)insets
{
}
- (id)safeAreaLayoutGuide
{
	return nil;
}
- (id)layoutMarginsGuide
{
	return nil;
}
- (NSUInteger)allowedTouchTypes
{
	return 0;
}
- (void)setAllowedTouchTypes:(NSUInteger)types
{
	(void) types;
}
- (BOOL)clipsToBounds
{
	return NO;
}
- (void)setClipsToBounds:(BOOL)flag
{
	(void) flag;
}
@end

@implementation NSWindow (CometStartupCluster)
static const void *kTitlebarAppearsTransparent;
static const void *kTitleVisibility;
static const void *kToolbarStyle;
static const void *kTitlebarSeparatorStyle;
static const void *kAnimationBehavior;
static const void *kRestorable;
static const void *kTabbingMode;
static const void *kTabbingIdentifier;
static const void *kSubtitle;
static const void *kTitlebarAccessories;
static const void *kMovableByBackground;

- (BOOL)titlebarAppearsTransparent
{
	return [objc_getAssociatedObject(self, &kTitlebarAppearsTransparent) boolValue];
}
- (void)setTitlebarAppearsTransparent:(BOOL)flag
{
	objc_setAssociatedObject(self, &kTitlebarAppearsTransparent,
	                         [NSNumber numberWithBool:flag],
	                         OBJC_ASSOCIATION_RETAIN);
}
- (NSInteger)titleVisibility
{
	return [objc_getAssociatedObject(self, &kTitleVisibility) integerValue];
}
- (void)setTitleVisibility:(NSInteger)value
{
	objc_setAssociatedObject(self, &kTitleVisibility,
	                         [NSNumber numberWithInteger:value],
	                         OBJC_ASSOCIATION_RETAIN);
}
- (NSInteger)toolbarStyle
{
	return [objc_getAssociatedObject(self, &kToolbarStyle) integerValue];
}
- (void)setToolbarStyle:(NSInteger)value
{
	objc_setAssociatedObject(self, &kToolbarStyle,
	                         [NSNumber numberWithInteger:value],
	                         OBJC_ASSOCIATION_RETAIN);
}
- (NSInteger)titlebarSeparatorStyle
{
	return [objc_getAssociatedObject(self, &kTitlebarSeparatorStyle) integerValue];
}
- (void)setTitlebarSeparatorStyle:(NSInteger)value
{
	objc_setAssociatedObject(self, &kTitlebarSeparatorStyle,
	                         [NSNumber numberWithInteger:value],
	                         OBJC_ASSOCIATION_RETAIN);
}
- (NSInteger)animationBehavior
{
	return [objc_getAssociatedObject(self, &kAnimationBehavior) integerValue];
}
- (void)setAnimationBehavior:(NSInteger)value
{
	objc_setAssociatedObject(self, &kAnimationBehavior,
	                         [NSNumber numberWithInteger:value],
	                         OBJC_ASSOCIATION_RETAIN);
}
- (BOOL)isRestorable
{
	return [objc_getAssociatedObject(self, &kRestorable) boolValue];
}
- (void)setRestorable:(BOOL)flag
{
	objc_setAssociatedObject(self, &kRestorable,
	                         [NSNumber numberWithBool:flag],
	                         OBJC_ASSOCIATION_RETAIN);
}
- (NSInteger)tabbingMode
{
	return [objc_getAssociatedObject(self, &kTabbingMode) integerValue];
}
- (void)setTabbingMode:(NSInteger)value
{
	objc_setAssociatedObject(self, &kTabbingMode,
	                         [NSNumber numberWithInteger:value],
	                         OBJC_ASSOCIATION_RETAIN);
}
- (NSString *)tabbingIdentifier
{
	return objc_getAssociatedObject(self, &kTabbingIdentifier);
}
- (void)setTabbingIdentifier:(NSString *)identifier
{
	objc_setAssociatedObject(self, &kTabbingIdentifier, identifier,
	                         OBJC_ASSOCIATION_COPY);
}
- (NSString *)subtitle
{
	return objc_getAssociatedObject(self, &kSubtitle);
}
- (void)setSubtitle:(NSString *)subtitle
{
	objc_setAssociatedObject(self, &kSubtitle, subtitle,
	                         OBJC_ASSOCIATION_COPY);
}
- (NSArray *)titlebarAccessoryViewControllers
{
	NSArray *list = objc_getAssociatedObject(self, &kTitlebarAccessories);
	return list ? list : [NSArray array];
}
- (void)setTitlebarAccessoryViewControllers:(NSArray *)controllers
{
	objc_setAssociatedObject(self, &kTitlebarAccessories, controllers,
	                         OBJC_ASSOCIATION_COPY);
}
- (void)addTitlebarAccessoryViewController:(id)controller
{
}
- (void)insertTitlebarAccessoryViewController:(id)controller atIndex:(NSInteger)index
{
}
- (void)removeTitlebarAccessoryViewControllerAtIndex:(NSInteger)index
{
}
- (void)setWindowToolbarStyle:(NSInteger)style
{
	[self setToolbarStyle:style];
}
- (NSInteger)sharingType
{
	return 0;
}
- (void)setSharingType:(NSInteger)type
{
}
- (BOOL)titlebarAppearsTransparent_comet
{
	return [self titlebarAppearsTransparent];
}
- (NSPoint)convertPointFromScreen:(NSPoint)point
{
	NSRect frame = [self frame];
	return NSMakePoint(point.x - frame.origin.x, point.y - frame.origin.y);
}
- (NSPoint)convertPointToScreen:(NSPoint)point
{
	NSRect frame = [self frame];
	return NSMakePoint(point.x + frame.origin.x, point.y + frame.origin.y);
}
- (NSRect)convertRectFromScreen:(NSRect)rect
{
	NSPoint origin = [self convertPointFromScreen:rect.origin];
	return NSMakeRect(origin.x, origin.y, rect.size.width, rect.size.height);
}
- (NSRect)convertRectToScreen:(NSRect)rect
{
	NSPoint origin = [self convertPointToScreen:rect.origin];
	return NSMakeRect(origin.x, origin.y, rect.size.width, rect.size.height);
}
@end

@implementation NSApplication (CometStartupCluster)
- (NSUInteger)occlusionState
{
	return 2; /* NSApplicationOcclusionStateVisible */
}
- (BOOL)isFullKeyboardAccessEnabled
{
	return NO;
}
- (id)appearanceNamed:(NSString *)name
{
	return nil;
}
@end

static NSBitmapImageRep *_cometMake1x1Rep(void)
{
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
	        initWithBitmapDataPlanes:NULL
	                      pixelsWide:1
	                      pixelsHigh:1
	                   bitsPerSample:8
	                 samplesPerPixel:4
	                        hasAlpha:YES
	                        isPlanar:NO
	                  colorSpaceName:NSCalibratedRGBColorSpace
	                     bytesPerRow:4
	                    bitsPerPixel:32];
	unsigned char *px = [rep bitmapData];
	if (px) {
		px[0] = 0;
		px[1] = 0;
		px[2] = 0;
		px[3] = 255;
	}
	return [rep autorelease];
}

static NSImage *_cometPlaceholderIcon(void)
{
	static NSImage *icon;
	static int state;

	if (icon)
		return icon;
	if (state == 1) {
		NSImage *tmp = [[NSImage alloc] initWithSize:NSMakeSize(1.0, 1.0)];
		[tmp addRepresentation:_cometMake1x1Rep()];
		return [tmp autorelease];
	}
	state = 1;
	NSImage *named = [NSImage imageNamed:NSImageNameApplicationIcon];
	if (named != nil && [[named representations] count] > 0) {
		icon = [named retain];
	} else {
		icon = [[NSImage alloc] initWithSize:NSMakeSize(1.0, 1.0)];
		[icon addRepresentation:_cometMake1x1Rep()];
	}
	state = 2;
	return icon;
}

static NSImageRep *_cometEnsureRepresentation(NSImage *image)
{
	NSArray *reps = [image representations];
	if ([reps count] > 0) {
		NSImageRep *best = [image bestRepresentationForDevice:nil];
		if (best)
			return best;
		return [reps lastObject];
	}
	NSBitmapImageRep *rep = _cometMake1x1Rep();
	[image addRepresentation:rep];
	NSSize sz = [image size];
	if (sz.width <= 0 || sz.height <= 0)
		[image setSize:NSMakeSize(1.0, 1.0)];
	return rep;
}

@implementation NSImage (CometStartupCluster)
- (NSImageRep *)bestRepresentationForRect:(NSRect)rect
                                  context:(id)context
                                    hints:(NSDictionary *)hints
{
	return _cometEnsureRepresentation(self);
}

- (CGImageRef)CGImageForProposedRect:(NSRect *)proposedDestRect
                             context:(id)context
                               hints:(NSDictionary *)hints
{
	NSSize size = [self size];
	NSRect rect;
	if (proposedDestRect && !NSIsEmptyRect(*proposedDestRect))
		rect = *proposedDestRect;
	else {
		CGFloat w = size.width > 0 ? size.width : 1.0;
		CGFloat h = size.height > 0 ? size.height : 1.0;
		rect = NSMakeRect(0, 0, w, h);
		if (proposedDestRect)
			*proposedDestRect = rect;
	}
	NSImageRep *rep = [self bestRepresentationForRect:rect
	                                          context:context
	                                            hints:hints];
	CGImageRef img = [rep CGImageForProposedRect:proposedDestRect
	                                   context:context
	                                     hints:hints];
	if (img != NULL)
		return img;
	return [_cometMake1x1Rep() CGImage];
}

- (void)drawInRect:(NSRect)rect
{
	[self drawInRect:rect
	        fromRect:NSZeroRect
	       operation:NSCompositeSourceOver
	        fraction:1.0];
}

+ (NSImage *)imageWithSize:(NSSize)size
                   flipped:(BOOL)flipped
            drawingHandler:(BOOL (^)(NSRect dstRect))drawingHandler
{
	if (size.width < 1)
		size.width = 1;
	if (size.height < 1)
		size.height = 1;
	NSImage *image = [[[NSImage alloc] initWithSize:size] autorelease];
	[image setFlipped:flipped];
	int w = (int)size.width;
	int h = (int)size.height;
	if (w < 1)
		w = 1;
	if (h < 1)
		h = 1;
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
	        initWithBitmapDataPlanes:NULL
	                      pixelsWide:w
	                      pixelsHigh:h
	                   bitsPerSample:8
	                 samplesPerPixel:4
	                        hasAlpha:YES
	                        isPlanar:NO
	                  colorSpaceName:NSCalibratedRGBColorSpace
	                     bytesPerRow:w * 4
	                    bitsPerPixel:32];
	[image addRepresentation:rep];
	if (drawingHandler) {
		NSGraphicsContext *ctx =
		        [NSGraphicsContext graphicsContextWithBitmapImageRep:rep];
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:ctx];
		drawingHandler(NSMakeRect(0, 0, size.width, size.height));
		[NSGraphicsContext restoreGraphicsState];
	}
	[rep release];
	return image;
}
@end

@implementation NSWorkspace (CometStartupCluster)
- (NSImage *)iconForContentType:(id)contentType
{
	return _cometPlaceholderIcon();
}
- (NSImage *)iconForFile:(NSString *)path
{
	return _cometPlaceholderIcon();
}
- (NSImage *)iconForFiles:(NSArray *)array
{
	return _cometPlaceholderIcon();
}
- (NSImage *)iconForFileType:(NSString *)type
{
	return _cometPlaceholderIcon();
}
- (NSArray *)fileLabels
{
	return [NSArray array];
}
- (NSArray *)fileLabelColors
{
	return [NSArray array];
}
@end

@implementation NSStatusItem (CometStartupCluster)
static const void *kStatusButton;
static const void *kStatusVisible;
static const void *kStatusBehavior;
static const void *kStatusAutosave;

- (NSStatusBarButton *)button
{
	NSStatusBarButton *button = objc_getAssociatedObject(self, &kStatusButton);
	if (button == nil) {
		button = [[NSStatusBarButton alloc] init];
		objc_setAssociatedObject(self, &kStatusButton, button,
		                         OBJC_ASSOCIATION_RETAIN);
		[button release];
	}
	return button;
}
- (BOOL)isVisible
{
	NSNumber *value = objc_getAssociatedObject(self, &kStatusVisible);
	return value ? [value boolValue] : YES;
}
- (void)setVisible:(BOOL)flag
{
	objc_setAssociatedObject(self, &kStatusVisible,
	                         [NSNumber numberWithBool:flag],
	                         OBJC_ASSOCIATION_RETAIN);
}
- (NSInteger)behavior
{
	return [objc_getAssociatedObject(self, &kStatusBehavior) integerValue];
}
- (void)setBehavior:(NSInteger)behavior
{
	objc_setAssociatedObject(self, &kStatusBehavior,
	                         [NSNumber numberWithInteger:behavior],
	                         OBJC_ASSOCIATION_RETAIN);
}
- (NSString *)autosaveName
{
	return objc_getAssociatedObject(self, &kStatusAutosave);
}
- (void)setAutosaveName:(NSString *)name
{
	objc_setAssociatedObject(self, &kStatusAutosave, name,
	                         OBJC_ASSOCIATION_COPY);
}
@end

@implementation NSVisualEffectView (CometStartupCluster)
static const void *kMaterial;
static const void *kBlending;
static const void *kVEState;
static const void *kEmphasized;

- (NSInteger)material
{
	return [objc_getAssociatedObject(self, &kMaterial) integerValue];
}
- (void)setMaterial:(NSInteger)material
{
	objc_setAssociatedObject(self, &kMaterial,
	                         [NSNumber numberWithInteger:material],
	                         OBJC_ASSOCIATION_RETAIN);
}
- (NSInteger)blendingMode
{
	return [objc_getAssociatedObject(self, &kBlending) integerValue];
}
- (void)setBlendingMode:(NSInteger)mode
{
	objc_setAssociatedObject(self, &kBlending,
	                         [NSNumber numberWithInteger:mode],
	                         OBJC_ASSOCIATION_RETAIN);
}
- (NSInteger)state
{
	return [objc_getAssociatedObject(self, &kVEState) integerValue];
}
- (void)setState:(NSInteger)state
{
	objc_setAssociatedObject(self, &kVEState,
	                         [NSNumber numberWithInteger:state],
	                         OBJC_ASSOCIATION_RETAIN);
}
- (BOOL)isEmphasized
{
	return [objc_getAssociatedObject(self, &kEmphasized) boolValue];
}
- (void)setEmphasized:(BOOL)flag
{
	objc_setAssociatedObject(self, &kEmphasized,
	                         [NSNumber numberWithBool:flag],
	                         OBJC_ASSOCIATION_RETAIN);
}
- (void)setMaskImage:(NSImage *)image
{
}
- (NSImage *)maskImage
{
	return nil;
}
- (NSInteger)interiorBackgroundStyle
{
	return 0;
}
@end

@implementation NSColor (CometStartupCluster)
+ (NSColor *)tertiaryLabelColor
{
	return [self secondaryLabelColor];
}
+ (NSColor *)quaternaryLabelColor
{
	return [self secondaryLabelColor];
}
+ (NSColor *)placeholderTextColor
{
	return [self secondaryLabelColor];
}
+ (NSColor *)separatorColor
{
	return [self gridColor];
}
+ (NSColor *)findHighlightColor
{
	return [self yellowColor];
}
+ (NSColor *)underPageBackgroundColor
{
	return [self windowBackgroundColor];
}
+ (NSColor *)systemBlueColor
{
	return [self blueColor];
}
+ (NSColor *)systemRedColor
{
	return [self redColor];
}
+ (NSColor *)systemGreenColor
{
	return [self greenColor];
}
+ (NSColor *)systemOrangeColor
{
	return [self orangeColor];
}
+ (NSColor *)systemYellowColor
{
	return [self yellowColor];
}
+ (NSColor *)systemPinkColor
{
	return [self magentaColor];
}
+ (NSColor *)systemPurpleColor
{
	return [self purpleColor];
}
+ (NSColor *)systemTealColor
{
	return [self cyanColor];
}
+ (NSColor *)systemIndigoColor
{
	return [self blueColor];
}
+ (NSColor *)systemGrayColor
{
	return [self grayColor];
}
+ (NSColor *)systemBrownColor
{
	return [self brownColor];
}
+ (NSColor *)systemMintColor
{
	return [self greenColor];
}
+ (NSColor *)systemCyanColor
{
	return [self cyanColor];
}
+ (NSColor *)colorNamed:(NSString *)name
{
	return [self labelColor];
}
+ (NSColor *)colorNamed:(NSString *)name bundle:(NSBundle *)bundle
{
	return [self labelColor];
}
+ (NSColor *)colorWithName:(NSString *)name
{
	return [self labelColor];
}
+ (NSColor *)colorWithName:(NSString *)name
                    bundle:(NSBundle *)bundle
{
	return [self labelColor];
}
+ (NSColor *)colorWithColorSpace:(NSColorSpace *)space
                      components:(const CGFloat *)components
                           count:(NSInteger)count
{
	CGFloat r = 0, g = 0, b = 0, a = 1;
	if (count == 2) {
		r = g = b = components[0];
		a = components[1];
	} else {
		if (count >= 1)
			r = components[0];
		if (count >= 2)
			g = components[1];
		if (count >= 3)
			b = components[2];
		if (count >= 4)
			a = components[3];
	}
	return [self colorWithSRGBRed:r green:g blue:b alpha:a];
}
@end

