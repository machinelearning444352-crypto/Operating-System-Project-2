#import <Cocoa/Cocoa.h>

@interface SecurityWindow : NSObject

+ (instancetype)sharedInstance;
- (void)showWindow;
- (void)runQuickScan;
- (void)runFullScan;

@end
