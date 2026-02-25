#import <Cocoa/Cocoa.h>

@protocol MenuBarViewDelegate <NSObject>
- (void)menuBarAppleMenuClicked;
- (void)menuBarItemClicked:(NSString *)itemName;
@optional
- (void)menuBarWiFiClicked;
@end

@interface MenuBarView : NSView

@property (nonatomic, strong) NSDateFormatter *timeFormatter;
@property (nonatomic, strong) NSTimer *clockTimer;
@property (nonatomic, strong) NSString *currentTime;
@property (nonatomic, weak) id<MenuBarViewDelegate> delegate;
@property (nonatomic, strong) NSString *activeApp;

- (void)updateClock;

@end
