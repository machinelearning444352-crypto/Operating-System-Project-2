#import <Cocoa/Cocoa.h>
@interface ConsoleWindow : NSObject
+ (instancetype)sharedInstance;
- (void)showWindow;
@end
