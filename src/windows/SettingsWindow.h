#import <Cocoa/Cocoa.h>

@interface SettingsWindow : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

+ (instancetype)sharedInstance;
- (void)showWindow;

@end
