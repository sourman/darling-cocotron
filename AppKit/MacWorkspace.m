#import "MacWorkspace.h"
#import <AppKit/NSApplication.h>
#import <AppKit/NSBitmapImageRep.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSRaise.h>
#import <Foundation/NSDictionary.h>
#include <LaunchServices/LaunchServices.h>
#include <dispatch/dispatch.h>
#include <stdio.h>

__attribute__((used)) const char macworkspace_async_default_v1[] =
        "macworkspace_async_default_v1";

static NSMutableDictionary *g_schemeAppURLs;

static NSMutableDictionary *schemeAppURLs(void)
{
    if (!g_schemeAppURLs)
        g_schemeAppURLs = [[NSMutableDictionary alloc] init];
    return g_schemeAppURLs;
}

static NSString *bundleIdForAppURL(NSURL *applicationURL)
{
    NSString *path = [applicationURL path];
    if (!path)
        return @"ai.perplexity.comet";
    NSString *plistPath = [path stringByAppendingPathComponent: @"Contents/Info.plist"];
    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile: plistPath];
    NSString *bid = [info objectForKey: @"CFBundleIdentifier"];
    if ([bid length])
        return bid;
    return @"ai.perplexity.comet";
}

static void invokeDefaultAppHandlerAsync(void (^completionHandler)(NSError *error))
{
    if (!completionHandler)
        return;
    void (^handler)(NSError *) = [completionHandler copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        handler(nil);
        [handler release];
    });
}

@implementation NSWorkspace (macos)

+ allocWithZone: (NSZone *) zone {
    return NSAllocateObject([MacWorkspace class], 0, NULL);
}

@end

@implementation MacWorkspace

static NSImage *_macWorkspacePlaceholderIcon(void)
{
    static NSImage *icon;
    if (icon)
        return icon;
    icon = [[NSImage alloc] initWithSize: NSMakeSize(1.0, 1.0)];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
            initWithBitmapDataPlanes: NULL
                          pixelsWide: 1
                          pixelsHigh: 1
                       bitsPerSample: 8
                     samplesPerPixel: 4
                            hasAlpha: YES
                            isPlanar: NO
                      colorSpaceName: NSCalibratedRGBColorSpace
                         bytesPerRow: 4
                        bitsPerPixel: 32];
    unsigned char *px = [rep bitmapData];
    if (px) {
        px[0] = 0;
        px[1] = 0;
        px[2] = 0;
        px[3] = 255;
    }
    [icon addRepresentation: rep];
    [rep release];
    return icon;
}

- (NSImage *) iconForFile: (NSString *) path {
    return _macWorkspacePlaceholderIcon();
}

- (NSImage *) iconForFiles: (NSArray *) array {
    return _macWorkspacePlaceholderIcon();
}

- (NSImage *) iconForFileType: (NSString *) type {
    return _macWorkspacePlaceholderIcon();
}

- (NSString *) localizedDescriptionForType: (NSString *) type {
    // TODO: call UTTypeCopyDescription()
    NSUnimplementedMethod();
    return NULL;
}

- (BOOL) filenameExtension: (NSString *) extension
            isValidForType: (NSString *) type
{
    // TODO: call UTTypeCreateAllIdentifiersForTag
    NSUnimplementedMethod();
    return NO;
}

- (NSString *) preferredFilenameExtensionForType: (NSString *) type {
    // TODO: call UTTypeCopyPreferredTagWithClass(kUTTagClassFilenameExtension)
    NSUnimplementedMethod();
    return NULL;
}

- (BOOL) type: (NSString *) type conformsToType: (NSString *) conformsToType {
    // TODO: call UTTypeConformsTo()
    NSUnimplementedMethod();
    return NO;
}

- (NSString *) typeOfFile: (NSString *) path error: (NSError **) error {
    // TODO: call LSCopyItemAttribute(kLSItemContentType)
    NSUnimplementedMethod();
    return NULL;
}

- (BOOL) openFile: (NSString *) path {
    return [self openFile: path withApplication: nil];
}

- (BOOL) openFile: (NSString *) path withApplication: (NSString *) application {
    return [self openFile: path
            withApplication: application
              andDeactivate: YES];
}

- (BOOL) openTempFile: (NSString *) path {
    return [self openFile: path withApplication: nil andDeactivate: YES];
}

- (BOOL) openFile: (NSString *) path
        fromImage: (NSImage *) image
               at: (NSPoint) point
           inView: (NSView *) view
{
    NSUnimplementedMethod();
    return NO;
}

- (BOOL) openFile: (NSString *) path
        withApplication: (NSString *) application
          andDeactivate: (BOOL) deactivate
{
    // TODO: call LSOpenFromURLSpec()
    NSUnimplementedMethod();
    return NO;
}

- (BOOL) openURL: (NSURL *) url {
    // TODO: Call LSOpenFromURLSpec()
    NSUnimplementedMethod();
    return NO;
}

- (BOOL) selectFile: (NSString *) path
        inFileViewerRootedAtPath: (NSString *) rootedAtPath
{
    // TODO: call activateFileViewerSelectingURLs
    NSUnimplementedMethod();
    return NO;
}

- (void) slideImage: (NSImage *) image from: (NSPoint) from to: (NSPoint) to {
}

- (BOOL) performFileOperation: (NSString *) operation
                       source: (NSString *) source
                  destination: (NSString *) destination
                        files: (NSArray *) files
                          tag: (NSInteger *) tag
{
    NSUnimplementedMethod();
}

- (BOOL) getFileSystemInfoForPath: (NSString *) path
                      isRemovable: (BOOL *) isRemovable
                       isWritable: (BOOL *) isWritable
                    isUnmountable: (BOOL *) isUnmountable
                      description: (NSString **) description
                             type: (NSString **) type
{
    if (!path)
        return NO;

    // TODO: call statfs() to get filesystem information
    // Use DiskArbitration for the rest.
    NSUnimplementedMethod();
    return NO;
}

- (BOOL) getInfoForFile: (NSString *) path
            application: (NSString **) application
                   type: (NSString **) type
{
    // TODO: call LSGetApplicationForURL()
    NSUnimplementedMethod();
    return NO;
}

- (void) checkForRemovableMedia {
}

- (NSArray *) mountNewRemovableMedia {
    return [self mountedRemovableMedia];
}

- (NSArray *) mountedRemovableMedia {
    // TODO: call [[NSFileManager defaultManager]
    // mountedVolumeURLsIncludingResourceValuesForKeys:@[NSURLVolumeIsRemovableKey]
    // options:NSVolumeEnumerationSkipHiddenVolumes]
    NSUnimplementedMethod();
    return @[];
}

- (NSArray *) mountedLocalVolumePaths {
    // TODO: call [[NSFileManager defaultManager]
    // mountedVolumeURLsIncludingResourceValuesForKeys:@[]
    // options:NSVolumeEnumerationSkipHiddenVolumes]
    NSUnimplementedMethod();
    return @[];
}

- (BOOL) unmountAndEjectDeviceAtPath: (NSString *) path {
    // TODO: call FSEjectVolumeSync()
    NSUnimplementedMethod();
    return NO;
}

- (BOOL) fileSystemChanged {
    return NO;
}

- (BOOL) userDefaultsChanged {
    return NO;
}

- (void) noteFileSystemChanged {
    [self noteFileSystemChanged: @"/"];
}

- (void) noteFileSystemChanged: (NSString *) path {
    // TODO: call FNNotifyByPath()
    NSUnimplementedMethod();
}

- (void) noteUserDefaultsChanged {
}

- (BOOL) isFilePackageAtPath: (NSString *) path {
    NSUnimplementedMethod();
}

- (NSString *) absolutePathForAppBundleWithIdentifier: (NSString *) identifier {
    // TODO: call LSFindApplicationForInfo() /
    // LSCopyApplicationURLsForBundleIdentifier()
    NSUnimplementedMethod();
    return NULL;
}

- (NSString *) pathForApplication: (NSString *) application {
    // This method doesn't exist on macOS?!
    return NULL;
}

- (NSArray *) launchedApplications {
    // TODO: call _LSCopyRunningApplicationArray()
    NSUnimplementedMethod();
    return @[];
}

- (NSArray *) runningApplications {
    NSUnimplementedMethod();
    return @[];
}

- (BOOL) launchApplication: (NSString *) application {
    return [self openFile: nil withApplication: application andDeactivate: YES];
}

- (BOOL) launchApplication: (NSString *) application
                  showIcon: (BOOL) showIcon
                autolaunch: (BOOL) autolaunch
{
    return [self openFile: nil withApplication: application andDeactivate: YES];
}

- (void) findApplications {
}

- (NSDictionary *) activeApplication {
    // TODO: call _LSCopyFrontApplication() and _LSCopyApplicationInformation()
    NSUnimplementedMethod();
    return NULL;
}

- (void) hideOtherApplications {
    [NSApp hideOtherApplications: self];
}

- (NSInteger) extendPowerOffBy: (NSInteger) milliseconds {
    return 0;
}

- (BOOL) setIcon: (NSImage *) image
         forFile: (NSString *) fullPath
         options: (NSWorkspaceIconCreationOptions) options
{
    // For directories, we would call the NSFileManager to create a file named
    // "Icon\r" with icon data. For files, we would call
    // FSCreateResFile/FSOpenResFile, FSSetCatalogInfo and other historical
    // functions. But none of these would have effect when viewed from Linux
    // desktop environments...
    NSUnimplementedMethod();
    return NO;
}

- (void) activateFileViewerSelectingURLs: (NSArray<NSURL *> *) fileURLs {
    // TODO: Get the current file viewer app by calling [[NSUserDefaults
    // standardUserDefaults] stringForKey: @"NSFileViewer"] Get its path via
    // [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier]
    // Call [self openFile:withApplication:]
    NSUnimplementedMethod();
}

/*
  Chrome registers as the default handler for https after NativeWidget
  present. Missing this selector was the uncaught NSException after
  iokit_lookup_v1 (GPU/network helpers then Z).
 */
- (void) setDefaultApplicationAtURL: (NSURL *) applicationURL
        toOpenURLsWithScheme: (NSString *) urlScheme
           completionHandler: (void (^)(NSError *error)) completionHandler
{
    NSString *bid = bundleIdForAppURL(applicationURL);
    fprintf(stderr,
            "macworkspace_async_default_v1 scheme=%s app=%s bid=%s\n",
            urlScheme ? [urlScheme UTF8String] : "(nil)",
            applicationURL ? [[applicationURL absoluteString] UTF8String]
                           : "(nil)",
            bid ? [bid UTF8String] : "(nil)");
    fflush(stderr);
    if (urlScheme && applicationURL)
        [schemeAppURLs() setObject: applicationURL forKey: urlScheme];
    if (urlScheme && bid)
        LSSetDefaultHandlerForURLScheme((CFStringRef) urlScheme,
                                        (CFStringRef) bid);
    invokeDefaultAppHandlerAsync(completionHandler);
}

- (void) setDefaultApplicationAtURL: (NSURL *) applicationURL
           toOpenContentType: (id) contentType
           completionHandler: (void (^)(NSError *error)) completionHandler
{
    fprintf(stderr,
            "macworkspace_async_default_v1 contentType=%s app=%s\n",
            contentType ? [[contentType description] UTF8String] : "(nil)",
            applicationURL ? [[applicationURL absoluteString] UTF8String]
                           : "(nil)");
    fflush(stderr);
    invokeDefaultAppHandlerAsync(completionHandler);
}

- (NSURL *) URLForApplicationToOpenURL: (NSURL *) url
{
    NSString *scheme = [url scheme];
    NSURL *app = scheme ? [schemeAppURLs() objectForKey: scheme] : nil;
    if (app)
        return app;
    if ([scheme isEqualToString: @"comet-external"])
        return [NSURL fileURLWithPath: @"/Applications/Comet.app"];
    return nil;
}

- (NSURL *) URLForApplicationWithBundleIdentifier: (NSString *) bundleIdentifier
{
    CFURLRef url;
    OSStatus status = LSFindApplicationForInfo(kLSUnknownCreator,
                                               (CFStringRef) bundleIdentifier,
                                               NULL, NULL, &url);

    if (status != noErr)
        return nil;

    return [(NSURL *) url autorelease];
}

- (NSString *) fullPathForApplication: (NSString *) appName {
    // If absolute, return as-is
    if ([appName isAbsolutePath])
        return appName;

    // If it doesn't have an suffix, add .app
    if ([[appName pathExtension] isEqualToString: @""])
        appName = [appName stringByAppendingPathExtension: @"app"];

    CFURLRef url;
    OSStatus status = LSFindApplicationForInfo(
            kLSUnknownCreator, NULL, (CFStringRef) appName, NULL, &url);

    if (status != noErr)
        return nil;

    NSString *path = [(NSURL *) url path];
    CFRelease(url);

    return path;
}

@end
