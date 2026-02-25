#import <AppKit/AppKit.h>

@interface DockItem : NSObject
@property(nonatomic, strong) NSString *appName;
@property(nonatomic, strong) NSImage *icon;
@property(nonatomic, assign) BOOL pinned;
@end

@interface MacOSLikeDock : NSView
@property(nonatomic, strong) NSMutableArray *items;
@property(nonatomic, strong) NSColor *backgroundColor;

- (instancetype)initWithFrame:(NSRect)frameRect;
- (void)addItem:(DockItem *)item;
- (void)removeItem:(DockItem *)item;
@end

@interface MacOSLikeMenuBar : NSView
@property(nonatomic, strong) NSMutableArray *menuItems;
- (instancetype)initWithFrame:(NSRect)frameRect;
@end

@interface SystemStatusBar : NSView
@property(nonatomic, strong) NSString *timeString;
@property(nonatomic, strong) NSString *batteryString;
- (void)updateStatus;
@end
