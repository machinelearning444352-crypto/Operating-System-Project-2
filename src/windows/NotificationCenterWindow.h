#import <Cocoa/Cocoa.h>
@interface NotificationCenterWindow : NSObject
+ (instancetype)sharedInstance;
- (void)showWindow;
- (void)toggle;
@end
