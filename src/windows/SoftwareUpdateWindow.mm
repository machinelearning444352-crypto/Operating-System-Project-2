#import "SoftwareUpdateWindow.h"
#import "../helpers/GlassmorphismHelper.h"

@interface SoftwareUpdateWindow ()
@property(nonatomic, strong) NSView *mainContentView;
@property(nonatomic, strong) NSTableView *updatesTable;
@property(nonatomic, strong) NSTableView *driversTable;
@property(nonatomic, strong) NSTextView *detailsTextView;
@property(nonatomic, strong) NSProgressIndicator *checkingSpinner;
@property(nonatomic, strong) NSProgressIndicator *downloadProgress;
@property(nonatomic, strong) NSButton *checkButton;
@property(nonatomic, strong) NSButton *updateAllButton;
@property(nonatomic, strong) NSButton *installButton;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSTextField *lastCheckLabel;
@property(nonatomic, strong) NSSegmentedControl *tabControl;
@property(nonatomic, strong) NSMutableArray *updatesList;
@property(nonatomic, strong) NSMutableArray *driversList;
@property(nonatomic, assign) NSInteger selectedTab;
@property(nonatomic, strong) NSBox *preferencesBox;
@property(nonatomic, strong) NSButton *autoCheckCheckbox;
@property(nonatomic, strong) NSButton *autoDownloadCheckbox;
@property(nonatomic, strong) NSButton *autoInstallCheckbox;
@end

@implementation SoftwareUpdateWindow

- (instancetype)init {
  NSRect frame = NSMakeRect(0, 0, 900, 700);
  self = [super
      initWithContentRect:frame
                styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                           NSWindowStyleMaskMiniaturizable |
                           NSWindowStyleMaskResizable)
                  backing:NSBackingStoreBuffered
                    defer:NO];

  if (self) {
    self.title = @"Software Update";
    self.minSize = NSMakeSize(800, 600);
    [self center];

    self.updateManager = [UpdateManager sharedManager];
    self.updateManager.delegate = self;

    self.driverManager = [DriverManager sharedManager];
    self.driverManager.delegate = self;

    self.updatesList = [NSMutableArray array];
    self.driversList = [NSMutableArray array];
    self.selectedTab = 0;

    [self setupUI];
    [self applyGlassmorphism];
  }
  return self;
}

- (void)setupUI {
  self.mainContentView = [[NSView alloc] initWithFrame:self.contentView.bounds];
  self.mainContentView.wantsLayer = YES;
  self.mainContentView.layer.backgroundColor =
      [[NSColor windowBackgroundColor] CGColor];
  [self setContentView:self.mainContentView];

  // Header section with gradient background
  NSView *headerView = [[NSView alloc]
      initWithFrame:NSMakeRect(0, self.mainContentView.bounds.size.height - 120,
                               self.mainContentView.bounds.size.width, 120)];
  headerView.wantsLayer = YES;
  headerView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;

  CAGradientLayer *headerGradient = [CAGradientLayer layer];
  headerGradient.frame = headerView.bounds;
  headerGradient.colors = @[
    (id)[NSColor colorWithRed:0.2 green:0.5 blue:0.95 alpha:1.0].CGColor,
    (id)[NSColor colorWithRed:0.3 green:0.6 blue:1.0 alpha:1.0].CGColor
  ];
  headerGradient.startPoint = CGPointMake(0, 0);
  headerGradient.endPoint = CGPointMake(1, 1);
  [headerView.layer addSublayer:headerGradient];
  [self.mainContentView addSubview:headerView];

  // Title
  NSTextField *titleLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, 70, 400, 36)];
  titleLabel.stringValue = @"Software Update";
  titleLabel.font = [NSFont systemFontOfSize:32 weight:NSFontWeightBold];
  titleLabel.textColor = [NSColor whiteColor];
  titleLabel.backgroundColor = [NSColor clearColor];
  titleLabel.bordered = NO;
  titleLabel.editable = NO;
  [headerView addSubview:titleLabel];

  // Subtitle
  NSTextField *subtitleLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, 45, 500, 20)];
  subtitleLabel.stringValue =
      @"Keep your Mac up to date with the latest software and drivers";
  subtitleLabel.font = [NSFont systemFontOfSize:14];
  subtitleLabel.textColor = [NSColor colorWithWhite:1.0 alpha:0.9];
  subtitleLabel.backgroundColor = [NSColor clearColor];
  subtitleLabel.bordered = NO;
  subtitleLabel.editable = NO;
  [headerView addSubview:subtitleLabel];

  // Last check label
  self.lastCheckLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, 15, 400, 20)];
  self.lastCheckLabel.stringValue = @"Last checked: Never";
  self.lastCheckLabel.font = [NSFont systemFontOfSize:12];
  self.lastCheckLabel.textColor = [NSColor colorWithWhite:1.0 alpha:0.8];
  self.lastCheckLabel.backgroundColor = [NSColor clearColor];
  self.lastCheckLabel.bordered = NO;
  self.lastCheckLabel.editable = NO;
  [headerView addSubview:self.lastCheckLabel];

  // Check for Updates button
  self.checkButton = [[NSButton alloc]
      initWithFrame:NSMakeRect(self.mainContentView.bounds.size.width - 200, 60,
                               170, 40)];
  self.checkButton.title = @"Check for Updates";
  self.checkButton.bezelStyle = NSBezelStyleRounded;
  self.checkButton.font = [NSFont systemFontOfSize:14
                                            weight:NSFontWeightMedium];
  self.checkButton.target = self;
  self.checkButton.action = @selector(checkForUpdates);
  self.checkButton.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
  [headerView addSubview:self.checkButton];

  // Checking spinner
  self.checkingSpinner = [[NSProgressIndicator alloc]
      initWithFrame:NSMakeRect(self.mainContentView.bounds.size.width - 230, 70,
                               20, 20)];
  self.checkingSpinner.style = NSProgressIndicatorStyleSpinning;
  self.checkingSpinner.displayedWhenStopped = NO;
  self.checkingSpinner.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
  [headerView addSubview:self.checkingSpinner];

  // Tab control
  self.tabControl = [[NSSegmentedControl alloc]
      initWithFrame:NSMakeRect(30,
                               self.mainContentView.bounds.size.height - 160,
                               300, 30)];
  self.tabControl.segmentCount = 3;
  [self.tabControl setLabel:@"Software Updates" forSegment:0];
  [self.tabControl setLabel:@"Drivers" forSegment:1];
  [self.tabControl setLabel:@"Preferences" forSegment:2];
  [self.tabControl setWidth:100 forSegment:0];
  [self.tabControl setWidth:100 forSegment:1];
  [self.tabControl setWidth:100 forSegment:2];
  self.tabControl.selectedSegment = 0;
  self.tabControl.target = self;
  self.tabControl.action = @selector(tabChanged:);
  self.tabControl.autoresizingMask = NSViewMaxXMargin | NSViewMinYMargin;
  [self.mainContentView addSubview:self.tabControl];

  // Main content area with shadow
  NSBox *contentBox = [[NSBox alloc]
      initWithFrame:NSMakeRect(20, 80,
                               self.mainContentView.bounds.size.width - 40,
                               self.mainContentView.bounds.size.height - 220)];
  contentBox.boxType = NSBoxCustom;
  contentBox.borderWidth = 0;
  contentBox.cornerRadius = 12;
  contentBox.fillColor = [NSColor whiteColor];
  contentBox.borderColor = [NSColor colorWithWhite:0.85 alpha:1.0];
  contentBox.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  // Add shadow
  contentBox.wantsLayer = YES;
  contentBox.shadow = [[NSShadow alloc] init];
  contentBox.shadow.shadowColor = [NSColor colorWithWhite:0.0 alpha:0.1];
  contentBox.shadow.shadowOffset = NSMakeSize(0, -2);
  contentBox.shadow.shadowBlurRadius = 10;
  [self.mainContentView addSubview:contentBox];

  // Updates table
  NSScrollView *updatesScrollView = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(10, 60, contentBox.bounds.size.width - 20,
                               contentBox.bounds.size.height - 70)];
  updatesScrollView.hasVerticalScroller = YES;
  updatesScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  updatesScrollView.borderType = NSNoBorder;

  self.updatesTable =
      [[NSTableView alloc] initWithFrame:updatesScrollView.bounds];
  self.updatesTable.delegate = self;
  self.updatesTable.dataSource = self;
  self.updatesTable.rowHeight = 60;
  self.updatesTable.intercellSpacing = NSMakeSize(0, 4);
  self.updatesTable.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
  self.updatesTable.gridColor = [NSColor colorWithWhite:0.95 alpha:1.0];
  self.updatesTable.backgroundColor = [NSColor whiteColor];

  NSTableColumn *nameColumn =
      [[NSTableColumn alloc] initWithIdentifier:@"name"];
  nameColumn.title = @"Update";
  nameColumn.width = 300;
  nameColumn.minWidth = 200;
  [self.updatesTable addTableColumn:nameColumn];

  NSTableColumn *versionColumn =
      [[NSTableColumn alloc] initWithIdentifier:@"version"];
  versionColumn.title = @"Version";
  versionColumn.width = 100;
  [self.updatesTable addTableColumn:versionColumn];

  NSTableColumn *sizeColumn =
      [[NSTableColumn alloc] initWithIdentifier:@"size"];
  sizeColumn.title = @"Size";
  sizeColumn.width = 80;
  [self.updatesTable addTableColumn:sizeColumn];

  NSTableColumn *statusColumn =
      [[NSTableColumn alloc] initWithIdentifier:@"status"];
  statusColumn.title = @"Status";
  statusColumn.width = 150;
  [self.updatesTable addTableColumn:statusColumn];

  updatesScrollView.documentView = self.updatesTable;
  [contentBox addSubview:updatesScrollView];

  // Drivers table (hidden initially)
  NSScrollView *driversScrollView =
      [[NSScrollView alloc] initWithFrame:updatesScrollView.frame];
  driversScrollView.hasVerticalScroller = YES;
  driversScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  driversScrollView.borderType = NSNoBorder;
  driversScrollView.hidden = YES;

  self.driversTable =
      [[NSTableView alloc] initWithFrame:driversScrollView.bounds];
  self.driversTable.delegate = self;
  self.driversTable.dataSource = self;
  self.driversTable.rowHeight = 60;
  self.driversTable.intercellSpacing = NSMakeSize(0, 4);
  self.driversTable.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
  self.driversTable.gridColor = [NSColor colorWithWhite:0.95 alpha:1.0];

  NSTableColumn *driverNameColumn =
      [[NSTableColumn alloc] initWithIdentifier:@"name"];
  driverNameColumn.title = @"Driver";
  driverNameColumn.width = 250;
  [self.driversTable addTableColumn:driverNameColumn];

  NSTableColumn *deviceColumn =
      [[NSTableColumn alloc] initWithIdentifier:@"device"];
  deviceColumn.title = @"Device";
  deviceColumn.width = 200;
  [self.driversTable addTableColumn:deviceColumn];

  NSTableColumn *driverVersionColumn =
      [[NSTableColumn alloc] initWithIdentifier:@"version"];
  driverVersionColumn.title = @"Version";
  driverVersionColumn.width = 100;
  [self.driversTable addTableColumn:driverVersionColumn];

  NSTableColumn *driverStatusColumn =
      [[NSTableColumn alloc] initWithIdentifier:@"status"];
  driverStatusColumn.title = @"Status";
  driverStatusColumn.width = 120;
  [self.driversTable addTableColumn:driverStatusColumn];

  driversScrollView.documentView = self.driversTable;
  [contentBox addSubview:driversScrollView];

  // Preferences view (hidden initially)
  self.preferencesBox = [[NSBox alloc]
      initWithFrame:NSMakeRect(10, 10, contentBox.bounds.size.width - 20,
                               contentBox.bounds.size.height - 20)];
  self.preferencesBox.boxType = NSBoxCustom;
  self.preferencesBox.fillColor = [NSColor clearColor];
  self.preferencesBox.transparent = YES;
  self.preferencesBox.hidden = YES;
  self.preferencesBox.autoresizingMask =
      NSViewWidthSizable | NSViewHeightSizable;
  [contentBox addSubview:self.preferencesBox];

  [self setupPreferencesView];

  // Status label
  self.statusLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, 50, 500, 20)];
  self.statusLabel.stringValue = @"Your software is up to date";
  self.statusLabel.font = [NSFont systemFontOfSize:13];
  self.statusLabel.textColor = [NSColor colorWithRed:0.3
                                               green:0.7
                                                blue:0.3
                                               alpha:1.0];
  self.statusLabel.backgroundColor = [NSColor clearColor];
  self.statusLabel.bordered = NO;
  self.statusLabel.editable = NO;
  self.statusLabel.autoresizingMask = NSViewMaxXMargin | NSViewMaxYMargin;
  [self.mainContentView addSubview:self.statusLabel];

  // Bottom action buttons
  self.updateAllButton = [[NSButton alloc]
      initWithFrame:NSMakeRect(self.mainContentView.bounds.size.width - 320, 15,
                               140, 32)];
  self.updateAllButton.title = @"Download All";
  self.updateAllButton.bezelStyle = NSBezelStyleRounded;
  self.updateAllButton.target = self;
  self.updateAllButton.action = @selector(downloadAll:);
  self.updateAllButton.enabled = NO;
  self.updateAllButton.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
  [self.mainContentView addSubview:self.updateAllButton];

  self.installButton = [[NSButton alloc]
      initWithFrame:NSMakeRect(self.mainContentView.bounds.size.width - 170, 15,
                               140, 32)];
  self.installButton.title = @"Install All";
  self.installButton.bezelStyle = NSBezelStyleRounded;
  self.installButton.keyEquivalent = @"\r";
  self.installButton.target = self;
  self.installButton.action = @selector(installAll:);
  self.installButton.enabled = NO;
  self.installButton.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
  [self.mainContentView addSubview:self.installButton];

  // Download progress
  self.downloadProgress = [[NSProgressIndicator alloc]
      initWithFrame:NSMakeRect(30, 25,
                               self.mainContentView.bounds.size.width - 380,
                               10)];
  self.downloadProgress.style = NSProgressIndicatorStyleBar;
  self.downloadProgress.indeterminate = NO;
  self.downloadProgress.minValue = 0.0;
  self.downloadProgress.maxValue = 100.0;
  self.downloadProgress.doubleValue = 0.0;
  self.downloadProgress.hidden = YES;
  self.downloadProgress.autoresizingMask =
      NSViewWidthSizable | NSViewMaxYMargin;
  [self.mainContentView addSubview:self.downloadProgress];
}

- (void)setupPreferencesView {
  CGFloat yPos = self.preferencesBox.bounds.size.height - 60;

  // Automatic updates section
  NSTextField *autoUpdateTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 400, 24)];
  autoUpdateTitle.stringValue = @"Automatic Updates";
  autoUpdateTitle.font = [NSFont systemFontOfSize:18
                                           weight:NSFontWeightSemibold];
  autoUpdateTitle.textColor = [NSColor labelColor];
  autoUpdateTitle.backgroundColor = [NSColor clearColor];
  autoUpdateTitle.bordered = NO;
  autoUpdateTitle.editable = NO;
  [self.preferencesBox addSubview:autoUpdateTitle];

  yPos -= 50;

  self.autoCheckCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, yPos, 500, 24)];
  [self.autoCheckCheckbox setButtonType:NSButtonTypeSwitch];
  self.autoCheckCheckbox.title = @"Automatically check for updates";
  self.autoCheckCheckbox.state = self.updateManager.automaticCheckEnabled
                                     ? NSControlStateValueOn
                                     : NSControlStateValueOff;
  self.autoCheckCheckbox.target = self;
  self.autoCheckCheckbox.action = @selector(preferencesChanged:);
  [self.preferencesBox addSubview:self.autoCheckCheckbox];

  yPos -= 40;

  self.autoDownloadCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, yPos, 500, 24)];
  [self.autoDownloadCheckbox setButtonType:NSButtonTypeSwitch];
  self.autoDownloadCheckbox.title =
      @"Automatically download updates when available";
  self.autoDownloadCheckbox.state = self.updateManager.automaticDownloadEnabled
                                        ? NSControlStateValueOn
                                        : NSControlStateValueOff;
  self.autoDownloadCheckbox.target = self;
  self.autoDownloadCheckbox.action = @selector(preferencesChanged:);
  [self.preferencesBox addSubview:self.autoDownloadCheckbox];

  yPos -= 40;

  self.autoInstallCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, yPos, 500, 24)];
  [self.autoInstallCheckbox setButtonType:NSButtonTypeSwitch];
  self.autoInstallCheckbox.title =
      @"Automatically install updates (requires restart)";
  self.autoInstallCheckbox.state = self.updateManager.automaticInstallEnabled
                                       ? NSControlStateValueOn
                                       : NSControlStateValueOff;
  self.autoInstallCheckbox.target = self;
  self.autoInstallCheckbox.action = @selector(preferencesChanged:);
  [self.preferencesBox addSubview:self.autoInstallCheckbox];

  yPos -= 60;

  // Update schedule section
  NSTextField *scheduleTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 400, 24)];
  scheduleTitle.stringValue = @"Update Schedule";
  scheduleTitle.font = [NSFont systemFontOfSize:18 weight:NSFontWeightSemibold];
  scheduleTitle.textColor = [NSColor labelColor];
  scheduleTitle.backgroundColor = [NSColor clearColor];
  scheduleTitle.bordered = NO;
  scheduleTitle.editable = NO;
  [self.preferencesBox addSubview:scheduleTitle];

  yPos -= 50;

  NSTextField *scheduleLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 200, 24)];
  scheduleLabel.stringValue = @"Check for updates every:";
  scheduleLabel.font = [NSFont systemFontOfSize:13];
  scheduleLabel.textColor = [NSColor labelColor];
  scheduleLabel.backgroundColor = [NSColor clearColor];
  scheduleLabel.bordered = NO;
  scheduleLabel.editable = NO;
  [self.preferencesBox addSubview:scheduleLabel];

  NSPopUpButton *schedulePopup =
      [[NSPopUpButton alloc] initWithFrame:NSMakeRect(220, yPos - 2, 150, 26)];
  [schedulePopup addItemWithTitle:@"Daily"];
  [schedulePopup addItemWithTitle:@"Weekly"];
  [schedulePopup addItemWithTitle:@"Monthly"];
  schedulePopup.target = self;
  schedulePopup.action = @selector(scheduleChanged:);
  [self.preferencesBox addSubview:schedulePopup];

  yPos -= 60;

  // Advanced section
  NSTextField *advancedTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, yPos, 400, 24)];
  advancedTitle.stringValue = @"Advanced";
  advancedTitle.font = [NSFont systemFontOfSize:18 weight:NSFontWeightSemibold];
  advancedTitle.textColor = [NSColor labelColor];
  advancedTitle.backgroundColor = [NSColor clearColor];
  advancedTitle.bordered = NO;
  advancedTitle.editable = NO;
  [self.preferencesBox addSubview:advancedTitle];

  yPos -= 50;

  NSButton *clearHistoryButton =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, yPos, 200, 32)];
  clearHistoryButton.title = @"Clear Update History";
  clearHistoryButton.bezelStyle = NSBezelStyleRounded;
  clearHistoryButton.target = self;
  clearHistoryButton.action = @selector(clearHistory:);
  [self.preferencesBox addSubview:clearHistoryButton];

  NSButton *resetButton =
      [[NSButton alloc] initWithFrame:NSMakeRect(230, yPos, 200, 32)];
  resetButton.title = @"Reset to Defaults";
  resetButton.bezelStyle = NSBezelStyleRounded;
  resetButton.target = self;
  resetButton.action = @selector(resetToDefaults:);
  [self.preferencesBox addSubview:resetButton];
}

- (void)applyGlassmorphism {
  // Apply visual effects
  self.backgroundColor = [NSColor colorWithWhite:0.98 alpha:0.95];
}

- (void)showWindow {
  [self makeKeyAndOrderFront:nil];
  [self checkForUpdates];
}

#pragma mark - Actions

- (void)checkForUpdates {
  [self.checkingSpinner startAnimation:nil];
  self.checkButton.enabled = NO;
  self.statusLabel.stringValue = @"Checking for updates...";
  self.statusLabel.textColor = [NSColor secondaryLabelColor];

  [self.updateManager checkForUpdates];
  [self.driverManager scanForDriverUpdates];

  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  formatter.dateStyle = NSDateFormatterMediumStyle;
  formatter.timeStyle = NSDateFormatterShortStyle;
  self.lastCheckLabel.stringValue =
      [NSString stringWithFormat:@"Last checked: %@",
                                 [formatter stringFromDate:[NSDate date]]];
}

- (void)downloadAll:(id)sender {
  [self.updateManager downloadAllUpdates];
  self.downloadProgress.hidden = NO;
}

- (void)installAll:(id)sender {
  [self.updateManager installAllDownloadedUpdates];
}

- (void)tabChanged:(NSSegmentedControl *)sender {
  self.selectedTab = sender.selectedSegment;

  // Hide all views
  for (NSView *subview in self.mainContentView.subviews) {
    if ([subview isKindOfClass:[NSScrollView class]] ||
        [subview isKindOfClass:[NSBox class]]) {
      if (subview != self.mainContentView.subviews[0]) { // Don't hide header
        for (NSView *contentSubview in (
                 (NSBox *)self.mainContentView.subviews[2])
                 .subviews) {
          contentSubview.hidden = YES;
        }
      }
    }
  }

  // Show selected view
  NSBox *contentBox = self.mainContentView.subviews[2];
  if (self.selectedTab == 0) {
    contentBox.subviews[0].hidden = NO; // Updates table
    self.updateAllButton.title = @"Download All";
    self.installButton.title = @"Install All";
  } else if (self.selectedTab == 1) {
    contentBox.subviews[1].hidden = NO; // Drivers table
    self.updateAllButton.title = @"Update All Drivers";
    self.installButton.hidden = YES;
  } else if (self.selectedTab == 2) {
    self.preferencesBox.hidden = NO;
    self.updateAllButton.hidden = YES;
    self.installButton.hidden = YES;
  }
}

- (void)preferencesChanged:(NSButton *)sender {
  if (sender == self.autoCheckCheckbox) {
    self.updateManager.automaticCheckEnabled =
        (sender.state == NSControlStateValueOn);
  } else if (sender == self.autoDownloadCheckbox) {
    self.updateManager.automaticDownloadEnabled =
        (sender.state == NSControlStateValueOn);
  } else if (sender == self.autoInstallCheckbox) {
    self.updateManager.automaticInstallEnabled =
        (sender.state == NSControlStateValueOn);
  }
}

- (void)scheduleChanged:(NSPopUpButton *)sender {
  NSInteger selectedIndex = sender.indexOfSelectedItem;
  if (selectedIndex == 0) {
    self.updateManager.checkInterval = 86400; // Daily
  } else if (selectedIndex == 1) {
    self.updateManager.checkInterval = 604800; // Weekly
  } else if (selectedIndex == 2) {
    self.updateManager.checkInterval = 2592000; // Monthly
  }
}

- (void)clearHistory:(id)sender {
  [self.updateManager clearUpdateHistory];
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = @"Update History Cleared";
  alert.informativeText = @"The update history has been cleared successfully.";
  [alert addButtonWithTitle:@"OK"];
  [alert runModal];
}

- (void)resetToDefaults:(id)sender {
  self.updateManager.automaticCheckEnabled = YES;
  self.updateManager.automaticDownloadEnabled = NO;
  self.updateManager.automaticInstallEnabled = NO;
  self.updateManager.checkInterval = 86400;

  self.autoCheckCheckbox.state = NSControlStateValueOn;
  self.autoDownloadCheckbox.state = NSControlStateValueOff;
  self.autoInstallCheckbox.state = NSControlStateValueOff;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  if (tableView == self.updatesTable) {
    return self.updatesList.count;
  } else if (tableView == self.driversTable) {
    return self.driversList.count;
  }
  return 0;
}

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row {
  NSTableCellView *cellView =
      [tableView makeViewWithIdentifier:tableColumn.identifier owner:self];

  if (!cellView) {
    cellView = [[NSTableCellView alloc]
        initWithFrame:NSMakeRect(0, 0, tableColumn.width, 60)];
    cellView.identifier = tableColumn.identifier;

    NSTextField *textField = [[NSTextField alloc]
        initWithFrame:NSMakeRect(10, 20, tableColumn.width - 20, 20)];
    textField.bordered = NO;
    textField.backgroundColor = [NSColor clearColor];
    textField.editable = NO;
    cellView.textField = textField;
    [cellView addSubview:textField];
  }

  if (tableView == self.updatesTable &&
      row < (NSInteger)self.updatesList.count) {
    UpdateInfo *update = self.updatesList[row];

    if ([tableColumn.identifier isEqualToString:@"name"]) {
      cellView.textField.stringValue = update.name;
      cellView.textField.font = [NSFont systemFontOfSize:14
                                                  weight:NSFontWeightMedium];
    } else if ([tableColumn.identifier isEqualToString:@"version"]) {
      cellView.textField.stringValue = update.version;
    } else if ([tableColumn.identifier isEqualToString:@"size"]) {
      cellView.textField.stringValue = [self formatBytes:update.size];
    } else if ([tableColumn.identifier isEqualToString:@"status"]) {
      cellView.textField.stringValue = [self statusStringForUpdate:update];
    }
  } else if (tableView == self.driversTable &&
             row < (NSInteger)self.driversList.count) {
    DriverInfo *driver = self.driversList[row];

    if ([tableColumn.identifier isEqualToString:@"name"]) {
      cellView.textField.stringValue = driver.name;
      cellView.textField.font = [NSFont systemFontOfSize:14
                                                  weight:NSFontWeightMedium];
    } else if ([tableColumn.identifier isEqualToString:@"device"]) {
      cellView.textField.stringValue = driver.deviceName;
    } else if ([tableColumn.identifier isEqualToString:@"version"]) {
      cellView.textField.stringValue = driver.version;
    } else if ([tableColumn.identifier isEqualToString:@"status"]) {
      cellView.textField.stringValue =
          driver.updateAvailable ? @"Update Available" : @"Up to date";
    }
  }

  return cellView;
}

#pragma mark - UpdateManagerDelegate

- (void)updateManager:(UpdateManager *)manager
       didFindUpdates:(NSArray<UpdateInfo *> *)updates {
  [self.checkingSpinner stopAnimation:nil];
  self.checkButton.enabled = YES;

  self.updatesList = [updates mutableCopy];
  [self.updatesTable reloadData];

  if (updates.count > 0) {
    self.statusLabel.stringValue = [NSString
        stringWithFormat:@"%ld update%@ available", (long)updates.count,
                         updates.count == 1 ? @"" : @"s"];
    self.statusLabel.textColor = [NSColor colorWithRed:0.9
                                                 green:0.6
                                                  blue:0.2
                                                 alpha:1.0];
    self.updateAllButton.enabled = YES;
  } else {
    self.statusLabel.stringValue = @"Your software is up to date";
    self.statusLabel.textColor = [NSColor colorWithRed:0.3
                                                 green:0.7
                                                  blue:0.3
                                                 alpha:1.0];
    self.updateAllButton.enabled = NO;
  }
}

- (void)updateManager:(UpdateManager *)manager
    didUpdateDownloadProgress:(UpdateInfo *)update {
  self.downloadProgress.doubleValue = update.downloadProgress * 100.0;
  [self.updatesTable reloadData];
}

- (void)updateManager:(UpdateManager *)manager
    didFinishDownloadingUpdate:(UpdateInfo *)update {
  [self.updatesTable reloadData];
  self.installButton.enabled = YES;
}

- (void)updateManager:(UpdateManager *)manager
    didFinishInstallingUpdate:(UpdateInfo *)update {
  [self.updatesList removeObject:update];
  [self.updatesTable reloadData];

  if (self.updatesList.count == 0) {
    self.statusLabel.stringValue = @"All updates installed successfully";
    self.statusLabel.textColor = [NSColor colorWithRed:0.3
                                                 green:0.7
                                                  blue:0.3
                                                 alpha:1.0];
    self.updateAllButton.enabled = NO;
    self.installButton.enabled = NO;
  }
}

#pragma mark - DriverManagerDelegate

- (void)driverManager:(DriverManager *)manager
    didFindDriverUpdate:(DriverInfo *)driver {
  if (![self.driversList containsObject:driver]) {
    [self.driversList addObject:driver];
    [self.driversTable reloadData];
  }
}

#pragma mark - Helper Methods

- (NSString *)formatBytes:(NSUInteger)bytes {
  if (bytes < 1024) {
    return [NSString stringWithFormat:@"%lu B", (unsigned long)bytes];
  } else if (bytes < 1024 * 1024) {
    return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
  } else if (bytes < 1024 * 1024 * 1024) {
    return [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
  } else {
    return [NSString
        stringWithFormat:@"%.2f GB", bytes / (1024.0 * 1024.0 * 1024.0)];
  }
}

- (NSString *)statusStringForUpdate:(UpdateInfo *)update {
  switch (update.status) {
  case UpdateStatusAvailable:
    return @"Available";
  case UpdateStatusDownloading:
    return [NSString
        stringWithFormat:@"Downloading %.0f%%", update.downloadProgress * 100];
  case UpdateStatusDownloaded:
    return @"Ready to Install";
  case UpdateStatusInstalling:
    return [NSString
        stringWithFormat:@"Installing %.0f%%", update.installProgress * 100];
  case UpdateStatusInstalled:
    return @"Installed";
  case UpdateStatusFailed:
    return @"Failed";
  case UpdateStatusCancelled:
    return @"Cancelled";
  default:
    return @"Unknown";
  }
}

@end
