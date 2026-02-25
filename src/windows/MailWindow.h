#import <Cocoa/Cocoa.h>

@interface MailWindow : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

+ (instancetype)sharedInstance;
- (void)showWindow;

@end
