#import <Cocoa/Cocoa.h>
@interface NetworkUtilityWindow : NSObject
+ (instancetype)sharedInstance;
- (void)showWindow;
@end
