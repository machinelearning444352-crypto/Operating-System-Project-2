#import <Cocoa/Cocoa.h>

@interface FinderWindow : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

+ (instancetype)sharedInstance;
- (void)showWindow;
- (void)navigateToPath:(NSString *)path;

@end
