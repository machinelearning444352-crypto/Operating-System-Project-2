#import <Cocoa/Cocoa.h>

@interface AntivirusWindow : NSObject

+ (instancetype)sharedInstance;
- (void)showWindow;

@end
