#import <Cocoa/Cocoa.h>

// ============================================================================
// WindowChromeHelper — Shared macOS Window Chrome System
// Pixel-perfect traffic lights, title bar, shadow, toolbar support
// ============================================================================

@interface TrafficLightButton : NSView
@property(nonatomic, assign)
    NSInteger buttonType; // 0=close, 1=minimize, 2=zoom
@property(nonatomic, assign) BOOL isHovered;
@property(nonatomic, assign) BOOL isGroupHovered;
@property(nonatomic, strong) NSColor *baseColor;
@property(nonatomic, copy) void (^action)(void);
@end

@interface TrafficLightGroup : NSView
@property(nonatomic, strong) TrafficLightButton *closeButton;
@property(nonatomic, strong) TrafficLightButton *minimizeButton;
@property(nonatomic, strong) TrafficLightButton *zoomButton;
- (void)setCloseAction:(void (^)(void))action;
- (void)setMinimizeAction:(void (^)(void))action;
- (void)setZoomAction:(void (^)(void))action;
@end

@interface WindowChromeHelper : NSObject

// Factory: create a standard macOS-style titled window
+ (NSWindow *)createWindowWithTitle:(NSString *)title
                              frame:(NSRect)frame
                          styleMask:(NSWindowStyleMask)mask;

// Apply macOS Sequoia window chrome styling
+ (void)applyMacOSChrome:(NSWindow *)window;

// Add traffic light group to a custom title bar view
+ (TrafficLightGroup *)addTrafficLightsToView:(NSView *)titleBar
                                  closeAction:(void (^)(void))closeAction
                               minimizeAction:(void (^)(void))minAction
                                   zoomAction:(void (^)(void))zoomAction;

// Create a standard toolbar separator line
+ (NSView *)createToolbarSeparator:(CGFloat)width y:(CGFloat)y;

// Standard macOS window colors
+ (NSColor *)windowBackgroundColor;
+ (NSColor *)sidebarBackgroundColor;
+ (NSColor *)toolbarBackgroundColor;
+ (NSColor *)separatorColor;
+ (NSColor *)titleTextColor;

@end
