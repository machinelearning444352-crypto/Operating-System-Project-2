#import <Cocoa/Cocoa.h>

@interface SetupWizardWindow : NSObject

+ (instancetype)sharedInstance;
- (void)showWizard;
- (BOOL)isSetupComplete;
- (NSString *)currentUsername;
- (BOOL)isAdmin;

@end
