#import <Cocoa/Cocoa.h>

@interface MusicWindow : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

+ (instancetype)sharedInstance;
- (void)showWindow;

@end
