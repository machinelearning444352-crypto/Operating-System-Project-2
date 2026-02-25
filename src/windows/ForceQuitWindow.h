#import <Cocoa/Cocoa.h>

@interface ForceQuitWindow : NSObject

+ (instancetype)sharedInstance;
- (void)showWindow;
- (void)addRunningApp:(NSString *)appName;
- (void)removeRunningApp:(NSString *)appName;

@end
