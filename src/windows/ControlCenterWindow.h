#import <Cocoa/Cocoa.h>
@interface ControlCenterWindow : NSObject
+ (instancetype)sharedInstance;
- (void)showWindow;
- (void)toggle;
@end
