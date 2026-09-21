#import "CATransactionGroup.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSString.h>
#import <Foundation/NSRunLoop.h>
#import <QuartzCore/CALayerContext.h>
#import <QuartzCore/CATransaction.h>
#import <objc/runtime.h>
#import <stdio.h>

NSString *const kCATransactionAnimationDuration =
        @"kCATransactionAnimationDuration";
NSString *const kCATransactionDisableActions = @"kCATransactionDisableActions";
NSString *const kCATransactionAnimationTimingFunction =
        @"kCATransactionAnimationTimingFunction";
NSString *const kCATransactionCompletionBlock =
        @"kCATransactionCompletionBlock";

@implementation CATransaction

static NSMutableArray *transactionStack() {
    NSMutableDictionary *shared = [NSCurrentThread() sharedDictionary];
    id stack = [shared objectForKey: @"CATransactionStack"];

    if (stack == nil) {
        stack = [NSMutableArray array];
        [shared setObject: stack forKey: @"CATransactionStack"];
    }

    return stack;
}

static CATransactionGroup *currentTransactionGroup() {
    id stack = transactionStack();

    CATransactionGroup *result = [stack lastObject];

    return result;
}

static CATransactionGroup *createImplicitTransactionGroupIfNeeded() {
    CATransactionGroup *check = currentTransactionGroup();

    if (check == nil) {
        check = [[CATransactionGroup alloc] init];

        [transactionStack() addObject: check];
        [[NSRunLoop currentRunLoop]
                performSelector: @selector(commit)
                         target: [CATransaction class]
                       argument: nil
                          order: 0
                          modes: [NSArray arrayWithObject:
                                                  NSRunLoopCommonModes]];
    }

    return check;
}

+ (BOOL) disableActions {
    return [[self valueForKey: kCATransactionDisableActions] boolValue];
}

+ (CFTimeInterval) animationDuration {
    return [[self valueForKey: kCATransactionAnimationDuration] doubleValue];
}

+ (CAMediaTimingFunction *) animationTimingFunction {
    return [self valueForKey: kCATransactionAnimationTimingFunction];
}

//+(void (^)(void))completionBlock;

+ valueForKey: (NSString *) key {
    CATransactionGroup *group = createImplicitTransactionGroupIfNeeded();

    return [group valueForKey: key];
}

+ (void) setAnimationDuration: (CFTimeInterval) value {
    [self setValue: [NSNumber numberWithDouble: value]
            forKey: kCATransactionAnimationDuration];
}

+ (void) setAnimationTimingFunction: (CAMediaTimingFunction *) value {
    [self setValue: value forKey: kCATransactionAnimationDuration];
}

//+(void)setCompletionBlock:(void (^)(void))value;
+ (void) setDisableActions: (BOOL) value {
    [self setValue: [NSNumber numberWithBool: value]
            forKey: kCATransactionDisableActions];
}

+ (void) setValue: value forKey: (NSString *) key {
    CATransactionGroup *group = createImplicitTransactionGroupIfNeeded();

    [group setValue: value forKey: key];
}

+ (void) begin {
    CATransactionGroup *group = [[CATransactionGroup alloc] init];

    [transactionStack() addObject: group];
}

+ (void) commit {
    CATransactionGroup *group = currentTransactionGroup();
    @try {
        [group runCommitHandlers];
    } @catch (id e) {
        const char *r = "";
        if ([e respondsToSelector: @selector(reason)]) {
            NSString *rs = [e reason];
            r = rs ? [rs UTF8String] : "(nil)";
        }
        fprintf(stderr, "nsexc_v1 CATransaction commit class=%s reason=%s\n",
                object_getClassName(e), r);
        fflush(stderr);
    }
    [transactionStack() removeLastObject];
}

+ (void) flush {
    fprintf(stderr, "CATransaction flush presentAll\n");
    fflush(stderr);
    @try {
        [CALayerContext presentAll];
    } @catch (id e) {
        const char *r = "";
        if ([e respondsToSelector: @selector(reason)]) {
            NSString *rs = [e reason];
            r = rs ? [rs UTF8String] : "(nil)";
        }
        fprintf(stderr, "nsexc_v1 CATransaction flush class=%s reason=%s\n",
                object_getClassName(e), r);
        fflush(stderr);
    }
}

+ (void) addCommitHandler: (void (^)(void)) block forPhase: (NSInteger) phase {
    (void) phase;
    if (!block)
        return;
    fprintf(stderr, "catransaction_commit_handler_v2 queue phase=%ld\n",
            (long) phase);
    fflush(stderr);
    CATransactionGroup *group = createImplicitTransactionGroupIfNeeded();
    [group addCommitHandler: block];
}

+ (void) lock {
}

+ (void) unlock {
}

@end
