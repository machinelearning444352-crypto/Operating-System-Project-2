#import <Cocoa/Cocoa.h>
@interface AutomatorWindow : NSObject
+ (instancetype)sharedInstance;
- (void)showWindow;
@end
