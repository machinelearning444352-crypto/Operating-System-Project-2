#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

@interface SafariWindow : NSWindowController <WKNavigationDelegate>

+ (instancetype)sharedInstance;
- (void)showWindow;
- (void)loadURL:(NSString *)urlString;

@end
