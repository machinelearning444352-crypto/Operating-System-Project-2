#import <Cocoa/Cocoa.h>

@interface SMSConfigWindow : NSObject

+ (instancetype)sharedInstance;
- (void)showWindow;

@end
