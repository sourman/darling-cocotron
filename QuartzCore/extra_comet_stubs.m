/* Auto-generated Comet compatibility stubs */
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <QuartzCore/CATransaction.h>

void *CATransform3DMakeTranslation(void) { return 0; }

@interface CAEDRMetadata : NSObject @end
@implementation CAEDRMetadata @end

@interface CAMetalDisplayLink : NSObject @end
@implementation CAMetalDisplayLink @end

/*
 * Comet CATransaction cluster. Chrome's CATransactionCoordinator calls
 * addCommitHandler:forPhase: after NativeWidgetMacNSWindow; missing it
 * is an unrecognized-selector terminate. begin/commit/flush and
 * setDisableActions already exist on CATransaction. Queue the handler
 * until +commit (implicit runloop commit included). Invoking it inside
 * addCommitHandler deadlocked NativeWidget init ("did not return").
 */
__attribute__((used)) const char comet_catransaction_cluster_v2[] =
        "comet_catransaction_cluster_v2";

