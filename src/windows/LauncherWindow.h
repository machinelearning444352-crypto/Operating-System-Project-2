#import <Cocoa/Cocoa.h>
@interface LauncherWindow : NSObject
+ (instancetype)sharedInstance;
- (void)showWindow;
- (void)toggle;
@end
