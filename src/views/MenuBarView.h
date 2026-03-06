#import <Cocoa/Cocoa.h>

@protocol MenuBarViewDelegate <NSObject>
- (void)menuBarAppleMenuClicked;
- (void)menuBarItemClicked:(NSString *)itemName;
@optional
- (void)menuBarWiFiClicked;
- (void)menuBarBluetoothClicked;
- (void)menuBarControlCenterClicked;
- (void)menuBarSpotlightClicked;
- (void)menuBarNotificationCenterClicked;
@end

@interface MenuBarView : NSView

@property(nonatomic, strong) NSDateFormatter *timeFormatter;
@property(nonatomic, strong) NSTimer *clockTimer;
@property(nonatomic, strong) NSString *currentTime;
@property(nonatomic, weak) id<MenuBarViewDelegate> delegate;
@property(nonatomic, strong) NSString *activeApp;
@property(nonatomic, assign) BOOL wifiEnabled;
@property(nonatomic, assign) BOOL bluetoothEnabled;
@property(nonatomic, assign) BOOL focusModeActive;
@property(nonatomic, assign) CGFloat batteryLevel;
@property(nonatomic, assign) BOOL batteryCharging;
@property(nonatomic, assign) NSInteger notificationCount;

- (void)updateClock;
- (void)setActiveApplication:(NSString *)appName;

@end
