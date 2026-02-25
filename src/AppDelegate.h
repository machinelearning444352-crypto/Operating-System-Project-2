#import <Cocoa/Cocoa.h>
#import "views/DockView.h"
#import "views/DesktopView.h"
#import "views/MenuBarView.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, DockViewDelegate, DesktopViewDelegate, MenuBarViewDelegate>

@property (nonatomic, strong) NSWindow *mainWindow;
@property (nonatomic, strong) DesktopView *desktopView;
@property (nonatomic, strong) MenuBarView *menuBarView;
@property (nonatomic, strong) DockView *dockView;

- (void)openApp:(NSString *)appName;
- (void)openFinderAtPath:(NSString *)path;

@end
