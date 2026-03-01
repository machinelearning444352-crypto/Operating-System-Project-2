#import <Cocoa/Cocoa.h>

@interface LoginWindow : NSObject

+ (instancetype)sharedInstance;

- (void)showWindow;
- (void)loginSuccessCallback:(void (^)(void))callback;

@end
