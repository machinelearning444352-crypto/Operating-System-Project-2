#import <Cocoa/Cocoa.h>
#import "../services/UpdateManager.h"
#import "../services/DriverManager.h"

@interface SoftwareUpdateWindow : NSWindow <UpdateManagerDelegate, DriverManagerDelegate, NSTableViewDelegate, NSTableViewDataSource>

@property (nonatomic, strong) UpdateManager *updateManager;
@property (nonatomic, strong) DriverManager *driverManager;

- (void)showWindow;
- (void)checkForUpdates;

@end
