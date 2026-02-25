#import "AppDelegate.h"
#import "windows/AboutThisMacWindow.h"
#import "windows/FinderWindow.h"
#import "windows/SafariWindow.h"
#import "windows/MessagesWindow.h"
#import "windows/TerminalWindow.h"
#import "windows/NotesWindow.h"
#import "windows/CalendarWindow.h"
#import "windows/SettingsWindow.h"
#import "windows/MailWindow.h"
#import "windows/PhotosWindow.h"
#import "windows/MusicWindow.h"
#import "windows/WiFiWindow.h"
#import "windows/SetupWizardWindow.h"
#import "windows/ForceQuitWindow.h"
#import "windows/SecurityWindow.h"
#import "windows/AntivirusWindow.h"
#include <iostream>

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    std::cout << "[macOS-Like OS] Starting up..." << std::endl;
    
    NSRect windowRect = NSMakeRect(0, 0, 1440, 900);
    
    self.mainWindow = [[NSWindow alloc] initWithContentRect:windowRect
                                                  styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    [self.mainWindow setTitle:@"macOS-Like Operating System"];
    [self.mainWindow center];
    
    NSView *contentView = [[NSView alloc] initWithFrame:windowRect];
    [self.mainWindow setContentView:contentView];
    
    // Desktop background
    self.desktopView = [[DesktopView alloc] initWithFrame:windowRect];
    self.desktopView.delegate = self;
    self.desktopView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [contentView addSubview:self.desktopView];
    
    // Menu bar at top
    NSRect menuBarRect = NSMakeRect(0, windowRect.size.height - 25, windowRect.size.width, 25);
    self.menuBarView = [[MenuBarView alloc] initWithFrame:menuBarRect];
    self.menuBarView.delegate = self;
    self.menuBarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [contentView addSubview:self.menuBarView];
    
    // Dock at bottom center
    CGFloat dockWidth = 620;
    CGFloat dockHeight = 75;
    NSRect dockRect = NSMakeRect((windowRect.size.width - dockWidth) / 2, 6, dockWidth, dockHeight);
    self.dockView = [[DockView alloc] initWithFrame:dockRect];
    self.dockView.delegate = self;
    self.dockView.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin;
    [contentView addSubview:self.dockView];
    
    [self.mainWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    
    std::cout << "[macOS-Like OS] Desktop ready!" << std::endl;
    
    // Show setup wizard if first launch
    if (![[SetupWizardWindow sharedInstance] isSetupComplete]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[SetupWizardWindow sharedInstance] showWizard];
        });
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

#pragma mark - DockViewDelegate

- (void)dockItemClicked:(NSString *)appName {
    [self openApp:appName];
}

#pragma mark - DesktopViewDelegate

- (void)desktopIconDoubleClicked:(NSString *)iconName path:(NSString *)path {
    std::cout << "[macOS-Like OS] Opening folder: " << [iconName UTF8String] << std::endl;
    [self openFinderAtPath:path];
}

#pragma mark - MenuBarViewDelegate

- (void)menuBarAppleMenuClicked {
    NSMenu *appleMenu = [[NSMenu alloc] initWithTitle:@"Apple"];
    
    [appleMenu addItemWithTitle:@"About This Mac" action:@selector(showAboutThisMac:) keyEquivalent:@""];
    [appleMenu addItem:[NSMenuItem separatorItem]];
    [appleMenu addItemWithTitle:@"System Settings..." action:@selector(showSystemSettings:) keyEquivalent:@","];
    [appleMenu addItemWithTitle:@"Security & Privacy..." action:@selector(showSecurity:) keyEquivalent:@""];
    [appleMenu addItem:[NSMenuItem separatorItem]];
    [appleMenu addItemWithTitle:@"Force Quit..." action:@selector(showForceQuit:) keyEquivalent:@""];
    [appleMenu addItem:[NSMenuItem separatorItem]];
    [appleMenu addItemWithTitle:@"Sleep" action:@selector(sleepSystem:) keyEquivalent:@""];
    [appleMenu addItemWithTitle:@"Restart..." action:@selector(restartSystem:) keyEquivalent:@""];
    [appleMenu addItemWithTitle:@"Shut Down..." action:@selector(shutdownSystem:) keyEquivalent:@""];
    [appleMenu addItem:[NSMenuItem separatorItem]];
    [appleMenu addItemWithTitle:@"Lock Screen" action:@selector(lockScreen:) keyEquivalent:@"q"];
    
    for (NSMenuItem *item in appleMenu.itemArray) {
        item.target = self;
    }
    
    [appleMenu popUpMenuPositioningItem:nil atLocation:NSMakePoint(10, 0) inView:self.menuBarView];
}

- (void)showAboutThisMac:(id)sender {
    [[AboutThisMacWindow sharedInstance] showWindow];
}

- (void)showSystemSettings:(id)sender {
    [[SettingsWindow sharedInstance] showWindow];
}

- (void)showForceQuit:(id)sender {
    [[ForceQuitWindow sharedInstance] showWindow];
}

- (void)showSecurity:(id)sender {
    [[SecurityWindow sharedInstance] showWindow];
}

- (void)sleepSystem:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Sleep";
    alert.informativeText = @"The system would now sleep.";
    [alert runModal];
}

- (void)restartSystem:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Restart";
    alert.informativeText = @"The system would now restart.";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Restart"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert runModal];
}

- (void)shutdownSystem:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Shut Down";
    alert.informativeText = @"Are you sure you want to shut down?";
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"Shut Down"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        [NSApp terminate:nil];
    }
}

- (void)lockScreen:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Screen Locked";
    alert.informativeText = @"The screen is now locked.";
    [alert runModal];
}

- (void)menuBarItemClicked:(NSString *)itemName {
    std::cout << "[macOS-Like OS] Menu clicked: " << [itemName UTF8String] << std::endl;
    
    if ([itemName isEqualToString:@"Finder"]) {
        [[FinderWindow sharedInstance] showWindow];
        self.menuBarView.activeApp = @"Finder";
        [self.menuBarView setNeedsDisplay:YES];
    }
    else if ([itemName isEqualToString:@"File"]) {
        // Show a simple File menu
        NSMenu *fileMenu = [[NSMenu alloc] initWithTitle:@"File"];
        [fileMenu addItemWithTitle:@"New Finder Window" action:@selector(newFinderWindow:) keyEquivalent:@"n"];
        [fileMenu addItemWithTitle:@"New Folder" action:@selector(newFolder:) keyEquivalent:@"N"];
        [fileMenu addItem:[NSMenuItem separatorItem]];
        [fileMenu addItemWithTitle:@"Close Window" action:@selector(closeWindow:) keyEquivalent:@"w"];
        
        for (NSMenuItem *item in fileMenu.itemArray) {
            item.target = self;
        }
        
        [fileMenu popUpMenuPositioningItem:nil atLocation:NSMakePoint(80, 0) inView:self.menuBarView];
    }
    else if ([itemName isEqualToString:@"Go"]) {
        NSMenu *goMenu = [[NSMenu alloc] initWithTitle:@"Go"];
        [goMenu addItemWithTitle:@"Home" action:@selector(goHome:) keyEquivalent:@"H"];
        [goMenu addItemWithTitle:@"Documents" action:@selector(goDocuments:) keyEquivalent:@"O"];
        [goMenu addItemWithTitle:@"Downloads" action:@selector(goDownloads:) keyEquivalent:@"L"];
        [goMenu addItemWithTitle:@"Applications" action:@selector(goApplications:) keyEquivalent:@"A"];
        [goMenu addItem:[NSMenuItem separatorItem]];
        [goMenu addItemWithTitle:@"Computer" action:@selector(goComputer:) keyEquivalent:@"C"];
        
        for (NSMenuItem *item in goMenu.itemArray) {
            item.target = self;
        }
        
        [goMenu popUpMenuPositioningItem:nil atLocation:NSMakePoint(200, 0) inView:self.menuBarView];
    }
    else if ([itemName isEqualToString:@"Edit"]) {
        NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
        [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
        [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
        [editMenu addItem:[NSMenuItem separatorItem]];
        [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
        [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
        [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
        [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
        [editMenu addItem:[NSMenuItem separatorItem]];
        [editMenu addItemWithTitle:@"Find..." action:@selector(showFind:) keyEquivalent:@"f"];
        
        for (NSMenuItem *item in editMenu.itemArray) {
            item.target = nil; // First responder
        }
        
        [editMenu popUpMenuPositioningItem:nil atLocation:NSMakePoint(120, 0) inView:self.menuBarView];
    }
    else if ([itemName isEqualToString:@"View"]) {
        NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
        [viewMenu addItemWithTitle:@"as Icons" action:@selector(viewAsIcons:) keyEquivalent:@"1"];
        [viewMenu addItemWithTitle:@"as List" action:@selector(viewAsList:) keyEquivalent:@"2"];
        [viewMenu addItemWithTitle:@"as Columns" action:@selector(viewAsColumns:) keyEquivalent:@"3"];
        [viewMenu addItem:[NSMenuItem separatorItem]];
        [viewMenu addItemWithTitle:@"Show Path Bar" action:@selector(togglePathBar:) keyEquivalent:@"P"];
        [viewMenu addItemWithTitle:@"Show Status Bar" action:@selector(toggleStatusBar:) keyEquivalent:@"/"];
        [viewMenu addItem:[NSMenuItem separatorItem]];
        [viewMenu addItemWithTitle:@"Enter Full Screen" action:@selector(toggleFullScreen:) keyEquivalent:@"f"];
        
        for (NSMenuItem *item in viewMenu.itemArray) {
            item.target = self;
        }
        
        [viewMenu popUpMenuPositioningItem:nil atLocation:NSMakePoint(160, 0) inView:self.menuBarView];
    }
    else if ([itemName isEqualToString:@"Window"]) {
        NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
        [windowMenu addItemWithTitle:@"Minimize" action:@selector(miniaturize:) keyEquivalent:@"m"];
        [windowMenu addItemWithTitle:@"Zoom" action:@selector(zoom:) keyEquivalent:@""];
        [windowMenu addItem:[NSMenuItem separatorItem]];
        [windowMenu addItemWithTitle:@"Bring All to Front" action:@selector(arrangeInFront:) keyEquivalent:@""];
        [windowMenu addItem:[NSMenuItem separatorItem]];
        [windowMenu addItemWithTitle:@"Close Window" action:@selector(closeWindow:) keyEquivalent:@"w"];
        
        for (NSMenuItem *item in windowMenu.itemArray) {
            item.target = nil; // First responder
        }
        
        [windowMenu popUpMenuPositioningItem:nil atLocation:NSMakePoint(240, 0) inView:self.menuBarView];
    }
    else if ([itemName isEqualToString:@"Help"]) {
        NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
        [helpMenu addItemWithTitle:@"VirtualOS Help" action:@selector(showHelp:) keyEquivalent:@"?"];
        [helpMenu addItem:[NSMenuItem separatorItem]];
        [helpMenu addItemWithTitle:@"About VirtualOS" action:@selector(showAboutThisMac:) keyEquivalent:@""];
        [helpMenu addItemWithTitle:@"Report an Issue..." action:@selector(reportIssue:) keyEquivalent:@""];
        
        for (NSMenuItem *item in helpMenu.itemArray) {
            item.target = self;
        }
        
        [helpMenu popUpMenuPositioningItem:nil atLocation:NSMakePoint(290, 0) inView:self.menuBarView];
    }
    else if ([itemName isEqualToString:@"WiFi"]) {
        [[WiFiWindow sharedInstance] showWindow];
    }
}

#pragma mark - Menu Actions

- (void)newFinderWindow:(id)sender {
    [[FinderWindow sharedInstance] showWindow];
}

- (void)newFolder:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"New Folder";
    alert.informativeText = @"Enter a name for the new folder:";
    
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
    input.stringValue = @"untitled folder";
    alert.accessoryView = input;
    
    [alert addButtonWithTitle:@"Create"];
    [alert addButtonWithTitle:@"Cancel"];
    
    if ([alert runModal] == NSAlertFirstButtonReturn) {
        NSString *folderName = input.stringValue;
        if (folderName.length > 0) {
            // Get current path from Finder or use Desktop
            NSString *basePath = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
            NSString *newPath = [basePath stringByAppendingPathComponent:folderName];
            
            NSError *error = nil;
            BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:newPath
                                                     withIntermediateDirectories:YES
                                                                      attributes:nil
                                                                           error:&error];
            if (success) {
                // Refresh Finder if open
                [[FinderWindow sharedInstance] navigateToPath:basePath];
            } else {
                NSAlert *errorAlert = [[NSAlert alloc] init];
                errorAlert.messageText = @"Error";
                errorAlert.informativeText = [NSString stringWithFormat:@"Could not create folder: %@", error.localizedDescription];
                [errorAlert runModal];
            }
        }
    }
}

- (void)closeWindow:(id)sender {
    [[NSApp keyWindow] close];
}

- (void)goHome:(id)sender {
    [self openFinderAtPath:NSHomeDirectory()];
}

- (void)goDocuments:(id)sender {
    [self openFinderAtPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]];
}

- (void)goDownloads:(id)sender {
    [self openFinderAtPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Downloads"]];
}

- (void)goApplications:(id)sender {
    [self openFinderAtPath:@"/Applications"];
}

- (void)goComputer:(id)sender {
    [self openFinderAtPath:@"/"];
}

#pragma mark - View Menu Actions

- (void)viewAsIcons:(id)sender {
    // View mode - placeholder
}

- (void)viewAsList:(id)sender {
    // View mode - placeholder
}

- (void)viewAsColumns:(id)sender {
    // View mode - placeholder
}

- (void)togglePathBar:(id)sender {
    // Toggle path bar - placeholder
}

- (void)toggleStatusBar:(id)sender {
    // Toggle status bar - placeholder
}

- (void)toggleFullScreen:(id)sender {
    [[NSApp keyWindow] toggleFullScreen:nil];
}

#pragma mark - Help Menu Actions

- (void)showHelp:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"VirtualOS Help";
    alert.informativeText = @"Welcome to VirtualOS!\n\n• Click the Apple menu () for system options\n• Use the Dock to launch applications\n• Double-click desktop icons to open folders\n• Use File > New Finder Window to browse files\n\nThis is a virtual operating system environment.";
    alert.alertStyle = NSAlertStyleInformational;
    [alert runModal];
}

- (void)reportIssue:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Report an Issue";
    alert.informativeText = @"To report an issue, please visit:\n\ngithub.com/issues\n\nThank you for helping improve VirtualOS!";
    [alert runModal];
}

#pragma mark - App Opening

- (void)openFinderAtPath:(NSString *)path {
    FinderWindow *finder = [FinderWindow sharedInstance];
    [finder showWindow];
    [finder navigateToPath:path];
}

- (void)openApp:(NSString *)appName {
    std::cout << "[macOS-Like OS] Opening " << [appName UTF8String] << "..." << std::endl;
    
    if ([appName isEqualToString:@"Finder"]) {
        [[FinderWindow sharedInstance] showWindow];
    }
    else if ([appName isEqualToString:@"Safari"]) {
        [[SafariWindow sharedInstance] showWindow];
    }
    else if ([appName isEqualToString:@"Mail"]) {
        [[MailWindow sharedInstance] showWindow];
    }
    else if ([appName isEqualToString:@"Messages"]) {
        [[MessagesWindow sharedInstance] showWindow];
    }
    else if ([appName isEqualToString:@"Photos"]) {
        [[PhotosWindow sharedInstance] showWindow];
    }
    else if ([appName isEqualToString:@"Music"]) {
        [[MusicWindow sharedInstance] showWindow];
    }
    else if ([appName isEqualToString:@"Terminal"]) {
        [[TerminalWindow sharedInstance] showWindow];
    }
    else if ([appName isEqualToString:@"Notes"]) {
        [[NotesWindow sharedInstance] showWindow];
    }
    else if ([appName isEqualToString:@"Calendar"]) {
        [[CalendarWindow sharedInstance] showWindow];
    }
    else if ([appName isEqualToString:@"Settings"]) {
        [[SettingsWindow sharedInstance] showWindow];
    }
    else if ([appName isEqualToString:@"About"]) {
        [[AboutThisMacWindow sharedInstance] showWindow];
    }
    else if ([appName isEqualToString:@"Downloads"]) {
        [self openFinderAtPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Downloads"]];
    }
    else if ([appName isEqualToString:@"WiFi"]) {
        [[WiFiWindow sharedInstance] showWindow];
    }
    else if ([appName isEqualToString:@"Antivirus"]) {
        [[AntivirusWindow sharedInstance] showWindow];
    }
    else {
        NSAlert *alert = [[NSAlert alloc] init];
        alert.messageText = appName;
        alert.informativeText = [NSString stringWithFormat:@"%@ is not implemented yet.", appName];
        alert.alertStyle = NSAlertStyleInformational;
        [alert runModal];
    }
}

@end
