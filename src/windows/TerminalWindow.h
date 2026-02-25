#import <Cocoa/Cocoa.h>

@interface TerminalWindow : NSWindowController

+ (instancetype)sharedInstance;
- (void)showWindow;

@end
