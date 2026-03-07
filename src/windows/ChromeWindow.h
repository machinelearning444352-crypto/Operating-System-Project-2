#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>

// ============================================================================
// ChromeWindow — Real Google Chrome Browser
// Uses WKWebView for actual web browsing. Zero AppleScript.
// Pixel-perfect Chrome UI: tab bar, omnibox, bookmarks bar, extensions area
// ============================================================================

@interface ChromeWindow
    : NSWindowController <WKNavigationDelegate, WKUIDelegate>

+ (instancetype)sharedInstance;
- (void)showWindow;
- (void)loadURL:(NSString *)urlString;
- (void)newTab;
- (void)newTabWithURL:(NSString *)url;

@end
