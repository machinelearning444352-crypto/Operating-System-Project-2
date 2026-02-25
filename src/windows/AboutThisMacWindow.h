#import <Cocoa/Cocoa.h>

@interface AboutThisMacWindow : NSWindowController

+ (instancetype)sharedInstance;
- (void)showWindow;

@end
