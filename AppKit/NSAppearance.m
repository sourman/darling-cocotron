/*
 This file is part of Darling.

 Copyright (C) 2019 Lubos Dolezel

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

#import <AppKit/NSAppearance.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSCoder.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSThread.h>

NSString *const NSAppearanceNameAqua = @"NSAppearanceNameAqua";
NSString *const NSAppearanceNameDarkAqua = @"NSAppearanceNameDarkAqua";
NSString *const NSAppearanceNameSystem = @"NSAppearanceNameSystem";
NSString *const NSAppearanceNameTouchBar = @"NSAppearanceNameTouchBar";
NSString *const NSAppearanceNameLightContent = @"NSAppearanceNameLightContent";
NSString *const NSAppearanceNameVibrantDark = @"NSAppearanceNameVibrantDark";
NSString *const NSAppearanceNameVibrantLight = @"NSAppearanceNameVibrantLight";
NSString *const NSAppearanceNameAccessibilityHighContrastAqua =
        @"NSAppearanceNameAccessibilityAqua";
NSString *const NSAppearanceNameAccessibilityHighContrastDarkAqua =
        @"NSAppearanceNameAccessibilityDarkAqua";
NSString *const NSAppearanceNameAccessibilityHighContrastSystem =
        @"NSAppearanceNameAccessibilityHighContrastSystem";
NSString *const NSAppearanceNameAccessibilityHighContrastVibrantLight =
        @"NSAppearanceNameAccessibilityVibrantLight";
NSString *const NSAppearanceNameAccessibilityHighContrastVibrantDark =
        @"NSAppearanceNameAccessibilityVibrantDark";

NSString *const NSAppearanceNameControlStrip =
        @"NSAppearanceNameControlStrip"; // Undocumented

static NSString *const NSCurrentDrawingAppearanceKey =
        @"NSCurrentDrawingAppearance";

@interface NSAppearance () {
    NSAppearanceName _name;
    BOOL _allowsVibrancy;
}
- (BOOL) _isDarkAppearance;
- (BOOL) _isHighContrastAppearance;
@end

@implementation NSAppearance

+ (NSMutableDictionary *) _namedAppearances {
    static NSMutableDictionary *named = nil;
    if (named == nil)
        named = [[NSMutableDictionary alloc] init];
    return named;
}

- (instancetype) init {
    return [self initWithAppearanceNamed: NSAppearanceNameAqua bundle: nil];
}

- (instancetype) initWithAppearanceNamed: (NSAppearanceName) name
                                  bundle: (NSBundle *) bundle
{
    self = [super init];
    if (self) {
        if (name == nil)
            name = NSAppearanceNameAqua;
        _name = [name copy];
        _allowsVibrancy =
                [_name isEqualToString: NSAppearanceNameVibrantLight] ||
                [_name isEqualToString: NSAppearanceNameVibrantDark] ||
                [_name isEqualToString:
                               NSAppearanceNameAccessibilityHighContrastVibrantLight] ||
                [_name isEqualToString:
                               NSAppearanceNameAccessibilityHighContrastVibrantDark];
    }
    return self;
}

- (void) dealloc {
    [_name release];
    [super dealloc];
}

+ (NSAppearance *) appearanceNamed: (NSAppearanceName) name {
    if (name == nil)
        name = NSAppearanceNameAqua;

    @synchronized(self) {
        NSMutableDictionary *named = [self _namedAppearances];
        NSAppearance *appearance = [named objectForKey: name];
        if (appearance == nil) {
            appearance = [[NSAppearance alloc] initWithAppearanceNamed: name
                                                                bundle: nil];
            [named setObject: appearance forKey: name];
            [appearance release];
            appearance = [named objectForKey: name];
        }
        return appearance;
    }
}

+ (NSAppearance *) currentAppearance {
    NSMutableDictionary *threadDictionary =
            [[NSThread currentThread] threadDictionary];
    NSAppearance *current =
            [threadDictionary objectForKey: NSCurrentDrawingAppearanceKey];
    if (current == nil)
        current = [self appearanceNamed: NSAppearanceNameAqua];
    return current;
}

+ (void) setCurrentAppearance: (NSAppearance *) appearance {
    NSMutableDictionary *threadDictionary =
            [[NSThread currentThread] threadDictionary];
    if (appearance == nil)
        [threadDictionary removeObjectForKey: NSCurrentDrawingAppearanceKey];
    else
        [threadDictionary setObject: appearance
                             forKey: NSCurrentDrawingAppearanceKey];
}

+ (NSAppearance *) currentDrawingAppearance {
    return [self currentAppearance];
}

- (NSAppearanceName) name {
    return _name;
}

- (BOOL) allowsVibrancy {
    return _allowsVibrancy;
}

- (BOOL) _isDarkAppearance {
    return [_name isEqualToString: NSAppearanceNameDarkAqua] ||
           [_name isEqualToString: NSAppearanceNameVibrantDark] ||
           [_name isEqualToString:
                          NSAppearanceNameAccessibilityHighContrastDarkAqua] ||
           [_name isEqualToString:
                          NSAppearanceNameAccessibilityHighContrastVibrantDark];
}

- (BOOL) _isHighContrastAppearance {
    return [_name isEqualToString:
                          NSAppearanceNameAccessibilityHighContrastAqua] ||
           [_name isEqualToString:
                          NSAppearanceNameAccessibilityHighContrastDarkAqua] ||
           [_name isEqualToString:
                          NSAppearanceNameAccessibilityHighContrastSystem] ||
           [_name isEqualToString:
                          NSAppearanceNameAccessibilityHighContrastVibrantLight] ||
           [_name isEqualToString:
                          NSAppearanceNameAccessibilityHighContrastVibrantDark];
}

- (BOOL) _isDefaultAppearance {
    return _name == nil || [_name isEqualToString: NSAppearanceNameAqua] ||
           [_name isEqualToString: NSAppearanceNameSystem];
}

- (BOOL) _usesMetricsAppearance {
    return NO;
}

- (NSAppearanceName) bestMatchFromAppearancesWithNames: (NSArray *) appearances
{
    if ([appearances count] == 0)
        return nil;

    if ([appearances containsObject: _name])
        return _name;

    BOOL dark = [self _isDarkAppearance];
    BOOL highContrast = [self _isHighContrastAppearance];
    NSMutableArray *fallbacks = [NSMutableArray array];

    if (highContrast && dark) {
        [fallbacks addObject: NSAppearanceNameAccessibilityHighContrastDarkAqua];
        [fallbacks addObject:
                           NSAppearanceNameAccessibilityHighContrastVibrantDark];
        [fallbacks addObject: NSAppearanceNameDarkAqua];
        [fallbacks addObject: NSAppearanceNameVibrantDark];
    } else if (highContrast) {
        [fallbacks addObject: NSAppearanceNameAccessibilityHighContrastAqua];
        [fallbacks addObject:
                           NSAppearanceNameAccessibilityHighContrastVibrantLight];
        [fallbacks addObject: NSAppearanceNameAqua];
        [fallbacks addObject: NSAppearanceNameVibrantLight];
    } else if (dark) {
        [fallbacks addObject: NSAppearanceNameDarkAqua];
        [fallbacks addObject: NSAppearanceNameVibrantDark];
        [fallbacks addObject:
                           NSAppearanceNameAccessibilityHighContrastDarkAqua];
        [fallbacks addObject: NSAppearanceNameAqua];
    } else {
        [fallbacks addObject: NSAppearanceNameAqua];
        [fallbacks addObject: NSAppearanceNameVibrantLight];
        [fallbacks addObject: NSAppearanceNameLightContent];
        [fallbacks addObject: NSAppearanceNameAccessibilityHighContrastAqua];
        [fallbacks addObject: NSAppearanceNameDarkAqua];
    }

    NSUInteger i, count = [fallbacks count];
    for (i = 0; i < count; i++) {
        NSAppearanceName candidate = [fallbacks objectAtIndex: i];
        if ([appearances containsObject: candidate])
            return candidate;
    }

    return [appearances objectAtIndex: 0];
}

- (void) performAsCurrentDrawingAppearance: (void (^)(void)) block {
    NSAppearance *previous = [NSAppearance currentAppearance];
    [NSAppearance setCurrentAppearance: self];
    @try {
        if (block != NULL)
            block();
    } @finally {
        [NSAppearance setCurrentAppearance: previous];
    }
}

- (id) copyWithZone: (NSZone *) zone {
    return [self retain];
}

- (BOOL) isEqual: (id) other {
    if (self == other)
        return YES;
    if (![other isKindOfClass: [NSAppearance class]])
        return NO;
    return [_name isEqualToString: [(NSAppearance *) other name]];
}

- (NSUInteger) hash {
    return [_name hash];
}

- (NSString *) description {
    return [NSString stringWithFormat: @"<%@: %@>", [self class], _name];
}

- (void) encodeWithCoder: (NSCoder *) aCoder {
    if ([aCoder allowsKeyedCoding])
        [aCoder encodeObject: _name forKey: @"NS.name"];
    else
        [aCoder encodeObject: _name];
}

- (id) initWithCoder: (NSCoder *) aDecoder {
    NSAppearanceName name;
    if ([aDecoder allowsKeyedCoding])
        name = [aDecoder decodeObjectForKey: @"NS.name"];
    else
        name = [aDecoder decodeObject];
    return [self initWithAppearanceNamed: name bundle: nil];
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

@end
