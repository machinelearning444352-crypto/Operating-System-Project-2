#import <Cocoa/Cocoa.h>

@interface CalendarWindow : NSWindowController

+ (instancetype)sharedInstance;
- (void)showWindow;

@end
