#import <Cocoa/Cocoa.h>
@interface ActivityMonitorWindow : NSObject
+ (instancetype)sharedInstance;
- (void)showWindow;
@end
