#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <unistd.h>
#include <CoreFoundation/CoreFoundation.h>

CFDictionaryRef CGSessionCopyCurrentDictionary(void)
{
    int32_t uid = (int32_t)getuid();
    int32_t sid = 1;
    CFStringRef kOnConsole = CFStringCreateWithCString(kCFAllocatorDefault,
            "kCGSSessionOnConsoleKey", kCFStringEncodingUTF8);
    CFStringRef kLoginDone = CFStringCreateWithCString(kCFAllocatorDefault,
            "kCGSessionLoginDoneKey", kCFStringEncodingUTF8);
    CFStringRef kUserName = CFStringCreateWithCString(kCFAllocatorDefault,
            "kCGSSessionUserNameKey", kCFStringEncodingUTF8);
    CFStringRef kUserID = CFStringCreateWithCString(kCFAllocatorDefault,
            "kCGSSessionUserIDKey", kCFStringEncodingUTF8);
    CFStringRef kSessionID = CFStringCreateWithCString(kCFAllocatorDefault,
            "kCGSSessionIDKey", kCFStringEncodingUTF8);
    CFNumberRef uidNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &uid);
    CFNumberRef sidNum = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &sid);
    CFStringRef user = CFStringCreateWithCString(kCFAllocatorDefault, "ec2-user",
            kCFStringEncodingUTF8);
    const void *keys[5] = { kOnConsole, kLoginDone, kUserName, kUserID, kSessionID };
    const void *vals[5] = { kCFBooleanTrue, kCFBooleanTrue, user, uidNum, sidNum };
    fprintf(stderr, "CGSessionCopyCurrentDictionary onConsole=1 loginDone=1 sid=1\n");
    fflush(stderr);
    CFDictionaryRef dict = CFDictionaryCreate(kCFAllocatorDefault, keys, vals, 5,
            &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    CFRelease(kOnConsole);
    CFRelease(kLoginDone);
    CFRelease(kUserName);
    CFRelease(kUserID);
    CFRelease(kSessionID);
    CFRelease(uidNum);
    CFRelease(sidNum);
    CFRelease(user);
    return dict;
}

/* Real implementation lives in CGColor.m (cgcolor_match_srgb_v1). */
void *CGColorGetTypeID(void) { return 0; }
void *CGColorSpaceCreateICCBased(void) { return 0; }
void *CGDirectDisplayCopyCurrentMetalDevice(void) { return 0; }
void *CGDisplayCreateImage(void) { return 0; }
void *CGDisplayIsBuiltin(void) { return 0; }
void *CGDisplayRotation(void) { return 0; }
void *CGDisplayStreamCreate(void) { return 0; }
void *CGDisplayStreamGetRunLoopSource(void) { return 0; }
void *CGDisplayStreamStart(void) { return 0; }
void *CGDisplayStreamStop(void) { return 0; }
void *CGDisplayStreamUpdateGetRects(void) { return 0; }
void *CGDisplayUsesForceToGray(void) { return 0; }
void *CGEventSourceKeyState(void) { return 0; }
void *CGEventSourceSecondsSinceLastEventType(void) { return 0; }
void *CGFontRenderingGetFontSmoothingDisabled(void) { return 0; }
void *CGPDFPageGetRotationAngle(void) { return 0; }
void *CGPreflightScreenCaptureAccess(void) { return 0; }
void *CGRegionCreateWithRect(void) { return 0; }
void *CGRequestScreenCaptureAccess(void) { return 0; }
void *CGSSetWindowAlpha(void) { return 0; }
void *CGSSetWindowCaptureExcludeShape(void) { return 0; }
void *CGSSetWindowTransform(void) { return 0; }
void *CGSSetWindowWarp(void) { return 0; }
void *CGWindowListCopyWindowInfo(void) { return 0; }
void *CGWindowListCreateDescriptionFromArray(void) { return 0; }
void *CGWindowListCreateImageFromArray(void) { return 0; }

const void *kCGColorSpaceExtendedLinearITUR_2020 = 0;
const void *kCGDisplayStreamColorSpace = 0;
const void *kCGDisplayStreamDestinationRect = 0;
const void *kCGDisplayStreamMinimumFrameTime = 0;
const void *kCGDisplayStreamPreserveAspectRatio = 0;
