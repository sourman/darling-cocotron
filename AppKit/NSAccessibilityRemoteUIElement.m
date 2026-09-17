/*
 This file is part of Darling.

 Copyright (C) 2025 Darling Developers

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <https://www.gnu.org/licenses/>.
*/

#import <AppKit/NSAccessibilityRemoteUIElement.h>
#import <Foundation/NSData.h>
#import <Foundation/NSMethodSignature.h>
#import <Foundation/NSInvocation.h>
#import <Foundation/NSString.h>
#import <objc/runtime.h>
#import <unistd.h>

/*
 * AppKit SPI used by Chromium Views / NativeWidgetMac. Instance
 * forwardInvocation does not catch class methods; Comet died with
 * +[NSAccessibilityRemoteUIElement remoteTokenForLocalUIElement:].
 */
__attribute__((used)) const char nsaccessibility_remote_token_v1[] =
        "nsaccessibility_remote_token_v1";

@implementation NSAccessibilityRemoteUIElement

static BOOL _remoteUIApp;
static const void *kWindowUIElement;
static const void *kTopLevelUIElement;

+ (BOOL)isRemoteUIApp
{
	return _remoteUIApp;
}

+ (void)setRemoteUIApp:(BOOL)flag
{
	_remoteUIApp = flag;
}

+ (NSData *)remoteTokenForLocalUIElement:(id)localUIElement
{
	(void)localUIElement;
	return [NSData data];
}

+ (void)registerRemoteUIProcessIdentifier:(pid_t)pid
{
	(void)pid;
}

+ (void)unregisterRemoteUIProcessIdentifier:(pid_t)pid
{
	(void)pid;
}

- (id)initWithRemoteToken:(NSData *)remoteToken
{
	self = [super init];
	(void)remoteToken;
	return self;
}

- (pid_t)processIdentifier
{
	return getpid();
}

- (void)accessibilitySetPresenterProcessIdentifier:(pid_t)presenterPID
{
	(void)presenterPID;
}

- (id)windowUIElement
{
	return objc_getAssociatedObject(self, &kWindowUIElement);
}

- (void)setWindowUIElement:(id)element
{
	objc_setAssociatedObject(self, &kWindowUIElement, element,
	                         OBJC_ASSOCIATION_RETAIN);
}

- (id)topLevelUIElement
{
	return objc_getAssociatedObject(self, &kTopLevelUIElement);
}

- (void)setTopLevelUIElement:(id)element
{
	objc_setAssociatedObject(self, &kTopLevelUIElement, element,
	                         OBJC_ASSOCIATION_RETAIN);
}

+ (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	if (aSelector == @selector(remoteTokenForLocalUIElement:))
		return [NSMethodSignature signatureWithObjCTypes:"@@:@"];
	if (aSelector == @selector(isRemoteUIApp))
		return [NSMethodSignature signatureWithObjCTypes:"c@:"];
	if (aSelector == @selector(setRemoteUIApp:))
		return [NSMethodSignature signatureWithObjCTypes:"v@:c"];
	return [NSMethodSignature signatureWithObjCTypes:"v@:"];
}

+ (void)forwardInvocation:(NSInvocation *)anInvocation
{
	NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), self);
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	return [NSMethodSignature signatureWithObjCTypes:"v@:"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	NSLog(@"Stub called: %@ in %@", NSStringFromSelector([anInvocation selector]), [self class]);
}

@end
