#import <Cocoa/Cocoa.h>

@interface NotesWindow : NSWindowController <NSTableViewDataSource, NSTableViewDelegate>

+ (instancetype)sharedInstance;
- (void)showWindow;

@end
