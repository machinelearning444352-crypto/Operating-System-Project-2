#import <Cocoa/Cocoa.h>

@interface WiFiWindow : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

+ (instancetype)sharedInstance;
- (void)showWindow;
- (void)scanForNetworks;

@end
