#import <Cocoa/Cocoa.h>
@interface AccessibilityWindow : NSObject
+ (instancetype)sharedInstance;
- (void)showWindow;
@end
