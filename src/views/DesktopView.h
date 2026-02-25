#import <Cocoa/Cocoa.h>

@protocol DesktopViewDelegate <NSObject>
- (void)desktopIconDoubleClicked:(NSString *)iconName path:(NSString *)path;
@end

@interface DesktopView : NSView

@property (nonatomic, assign) NSInteger selectedIcon;
@property (nonatomic, weak) id<DesktopViewDelegate> delegate;

@end
