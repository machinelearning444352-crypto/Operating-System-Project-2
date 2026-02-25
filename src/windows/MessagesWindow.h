#import <Cocoa/Cocoa.h>

@interface MessagesWindow : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

+ (instancetype)sharedInstance;
- (void)showWindow;

@end
