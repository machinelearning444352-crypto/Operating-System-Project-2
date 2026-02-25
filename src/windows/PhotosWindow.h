#import <Cocoa/Cocoa.h>

@interface PhotosWindow : NSWindowController

+ (instancetype)sharedInstance;
- (void)showWindow;

@end
