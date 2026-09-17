#import <Foundation/NSObject.h>

@class NSMutableDictionary;
@class NSMutableArray;

@interface CATransactionGroup : NSObject {
    NSMutableDictionary *_values;
    NSMutableArray *_commitHandlers;
}

- valueForKey: (NSString *) key;
- (void) setValue: value forKey: (NSString *) key;
- (void) addCommitHandler: (void (^)(void)) block;
- (void) runCommitHandlers;

@end
