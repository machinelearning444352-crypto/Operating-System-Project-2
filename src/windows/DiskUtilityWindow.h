#import <Cocoa/Cocoa.h>
@interface DiskUtilityWindow : NSObject
+ (instancetype)sharedInstance;
- (void)showWindow;
@end
