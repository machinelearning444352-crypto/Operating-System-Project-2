#import "SettingsWindow.h"
#import "../helpers/SystemInfoHelper.h"
#import <CoreWLAN/CoreWLAN.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/ps/IOPSKeys.h>
#import <IOKit/ps/IOPowerSources.h>

@interface SettingsWindow ()
@property(nonatomic, strong) NSWindow *settingsWindow;
@property(nonatomic, strong) NSTableView *categoriesTable;
@property(nonatomic, strong) NSView *detailView;
@property(nonatomic, strong) NSArray *categories;
@property(nonatomic, strong) NSSlider *fanSpeedSlider;
@property(nonatomic, strong) NSTextField *fanSpeedLabel;
@property(nonatomic, strong) NSTextField *batteryPercentLabel;
@property(nonatomic, strong) NSTextField *batteryHealthLabel;
@property(nonatomic, strong) NSProgressIndicator *batteryIndicator;
@property(nonatomic, strong) NSTimer *batteryTimer;
@property(nonatomic, assign) NSInteger currentFanSpeed;
@end

@implementation SettingsWindow

+ (instancetype)sharedInstance {
  static SettingsWindow *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[SettingsWindow alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.categories = @[
      @{@"icon" : @"📶", @"name" : @"Wi-Fi"},
      @{@"icon" : @"🔵", @"name" : @"Bluetooth"},
      @{@"icon" : @"🌐", @"name" : @"Network"},
      @{@"icon" : @"🔔", @"name" : @"Notifications"},
      @{@"icon" : @"🔊", @"name" : @"Sound"},
      @{@"icon" : @"🖥", @"name" : @"Displays"},
      @{@"icon" : @"🎨", @"name" : @"Appearance"},
      @{@"icon" : @"🌡️", @"name" : @"Fan Control"},
      @{@"icon" : @"🔋", @"name" : @"Battery"},
      @{@"icon" : @"🔒", @"name" : @"Privacy & Security"},
      @{@"icon" : @"🖱", @"name" : @"Trackpad"},
      @{@"icon" : @"⌨️", @"name" : @"Keyboard"},
      @{@"icon" : @"ℹ️", @"name" : @"About"}
    ];
    self.currentFanSpeed = 50; // Default 50%
  }
  return self;
}

- (void)showWindow {
  if (self.settingsWindow) {
    [self.settingsWindow makeKeyAndOrderFront:nil];
    return;
  }

  NSRect frame = NSMakeRect(0, 0, 820, 560);
  self.settingsWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.settingsWindow setTitle:@"System Settings"];
  [self.settingsWindow center];

  NSView *contentView = [[NSView alloc] initWithFrame:frame];
  contentView.wantsLayer = YES;
  contentView.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];
  [self.settingsWindow setContentView:contentView];

  // Native sidebar
  NSVisualEffectView *sidebar = [[NSVisualEffectView alloc]
      initWithFrame:NSMakeRect(0, 0, 250, frame.size.height)];
  sidebar.material = NSVisualEffectMaterialSidebar;
  sidebar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  sidebar.state = NSVisualEffectStateActive;
  [contentView addSubview:sidebar];

  // Sidebar divider
  NSView *sideDivider =
      [[NSView alloc] initWithFrame:NSMakeRect(249, 0, 1, frame.size.height)];
  sideDivider.wantsLayer = YES;
  sideDivider.layer.backgroundColor = [[NSColor separatorColor] CGColor];
  [contentView addSubview:sideDivider];

  // Search field
  NSSearchField *searchField = [[NSSearchField alloc]
      initWithFrame:NSMakeRect(12, frame.size.height - 45, 226, 28)];
  searchField.placeholderString = @"Search";
  [sidebar addSubview:searchField];

  // Categories scroll view
  NSScrollView *scrollView = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 0, 250, frame.size.height - 55)];
  scrollView.hasVerticalScroller = YES;
  scrollView.autohidesScrollers = YES;
  scrollView.drawsBackground = NO;

  self.categoriesTable = [[NSTableView alloc] initWithFrame:scrollView.bounds];
  self.categoriesTable.dataSource = self;
  self.categoriesTable.delegate = self;
  self.categoriesTable.rowHeight = 36;
  self.categoriesTable.headerView = nil;
  self.categoriesTable.backgroundColor = [NSColor clearColor];
  self.categoriesTable.selectionHighlightStyle =
      NSTableViewSelectionHighlightStyleNone;

  NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"category"];
  col.width = 250;
  [self.categoriesTable addTableColumn:col];

  scrollView.documentView = self.categoriesTable;
  [sidebar addSubview:scrollView];

  // Dark detail view
  self.detailView =
      [[NSView alloc] initWithFrame:NSMakeRect(250, 0, frame.size.width - 250,
                                               frame.size.height)];
  self.detailView.wantsLayer = YES;
  self.detailView.layer.backgroundColor = [[NSColor colorWithRed:0.11
                                                           green:0.11
                                                            blue:0.13
                                                           alpha:1.0] CGColor];
  [contentView addSubview:self.detailView];

  // Show default view (About)
  [self showAboutPanel];

  [self.settingsWindow makeKeyAndOrderFront:nil];
}

- (void)showAboutPanel {
  // Clear previous content
  for (NSView *subview in [self.detailView.subviews copy]) {
    [subview removeFromSuperview];
  }

  CGFloat y = self.detailView.bounds.size.height - 80;

  // Title
  NSTextField *title =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 400, 35)];
  title.stringValue = @"About";
  title.font = [NSFont systemFontOfSize:28 weight:NSFontWeightBold];
  title.bezeled = NO;
  title.editable = NO;
  title.drawsBackground = NO;
  [self.detailView addSubview:title];

  y -= 80;

  // Computer icon
  NSTextField *icon =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 80, 80)];
  icon.stringValue = @"🖥";
  icon.font = [NSFont systemFontOfSize:55];
  icon.bezeled = NO;
  icon.editable = NO;
  icon.drawsBackground = NO;
  [self.detailView addSubview:icon];

  // Computer name
  NSTextField *computerName =
      [[NSTextField alloc] initWithFrame:NSMakeRect(120, y + 50, 350, 25)];
  computerName.stringValue = [SystemInfoHelper computerName];
  computerName.font = [NSFont systemFontOfSize:18 weight:NSFontWeightSemibold];
  computerName.bezeled = NO;
  computerName.editable = NO;
  computerName.drawsBackground = NO;
  [self.detailView addSubview:computerName];

  // macOS version
  NSTextField *osVersion =
      [[NSTextField alloc] initWithFrame:NSMakeRect(120, y + 25, 350, 20)];
  osVersion.stringValue = [SystemInfoHelper osVersion];
  osVersion.font = [NSFont systemFontOfSize:13];
  osVersion.textColor = [NSColor grayColor];
  osVersion.bezeled = NO;
  osVersion.editable = NO;
  osVersion.drawsBackground = NO;
  [self.detailView addSubview:osVersion];

  y -= 50;

  // System info section
  NSArray *infoItems = @[
    @{@"label" : @"Chip", @"value" : [SystemInfoHelper cpuModel]},
    @{@"label" : @"Memory", @"value" : [SystemInfoHelper memorySize]},
    @{@"label" : @"Serial Number", @"value" : [SystemInfoHelper serialNumber]},
    @{@"label" : @"Uptime", @"value" : [SystemInfoHelper uptime]}
  ];

  for (NSDictionary *item in infoItems) {
    y -= 35;

    NSTextField *label =
        [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 130, 20)];
    label.stringValue = [NSString stringWithFormat:@"%@:", item[@"label"]];
    label.font = [NSFont systemFontOfSize:13];
    label.textColor = [NSColor grayColor];
    label.alignment = NSTextAlignmentRight;
    label.bezeled = NO;
    label.editable = NO;
    label.drawsBackground = NO;
    [self.detailView addSubview:label];

    NSTextField *value =
        [[NSTextField alloc] initWithFrame:NSMakeRect(170, y, 350, 20)];
    value.stringValue = item[@"value"];
    value.font = [NSFont systemFontOfSize:13];
    value.bezeled = NO;
    value.editable = NO;
    value.drawsBackground = NO;
    [self.detailView addSubview:value];
  }

  // Buttons
  y -= 50;

  NSButton *systemReportBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 150, 32)];
  systemReportBtn.title = @"System Report...";
  systemReportBtn.bezelStyle = NSBezelStyleRounded;
  [self.detailView addSubview:systemReportBtn];

  NSButton *softwareUpdateBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(190, y, 150, 32)];
  softwareUpdateBtn.title = @"Software Update...";
  softwareUpdateBtn.bezelStyle = NSBezelStyleRounded;
  [self.detailView addSubview:softwareUpdateBtn];
}

- (void)showWiFiPanel {
  for (NSView *subview in [self.detailView.subviews copy]) {
    [subview removeFromSuperview];
  }

  CGFloat y = self.detailView.bounds.size.height - 80;

  NSTextField *title =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 400, 35)];
  title.stringValue = @"Wi-Fi";
  title.font = [NSFont systemFontOfSize:28 weight:NSFontWeightBold];
  title.bezeled = NO;
  title.editable = NO;
  title.drawsBackground = NO;
  [self.detailView addSubview:title];

  y -= 60;

  // Wi-Fi toggle
  NSTextField *wifiLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 100, 25)];
  wifiLabel.stringValue = @"Wi-Fi";
  wifiLabel.font = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
  wifiLabel.bezeled = NO;
  wifiLabel.editable = NO;
  wifiLabel.drawsBackground = NO;
  [self.detailView addSubview:wifiLabel];

  NSButton *wifiToggle =
      [[NSButton alloc] initWithFrame:NSMakeRect(430, y, 60, 25)];
  [wifiToggle setButtonType:NSButtonTypeSwitch];
  wifiToggle.title = @"";
  wifiToggle.state = NSControlStateValueOn;
  [self.detailView addSubview:wifiToggle];

  y -= 50;

  // Networks list header
  NSTextField *networksLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 200, 20)];
  networksLabel.stringValue = @"Known Networks";
  networksLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
  networksLabel.textColor = [NSColor grayColor];
  networksLabel.bezeled = NO;
  networksLabel.editable = NO;
  networksLabel.drawsBackground = NO;
  [self.detailView addSubview:networksLabel];

  y -= 40;

  // Sample networks
  NSArray *networks = @[ @"Home Network", @"Office WiFi", @"Coffee Shop" ];
  for (NSString *network in networks) {
    NSTextField *networkName =
        [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 400, 25)];
    networkName.stringValue = [NSString stringWithFormat:@"📶  %@", network];
    networkName.font = [NSFont systemFontOfSize:14];
    networkName.bezeled = NO;
    networkName.editable = NO;
    networkName.drawsBackground = NO;
    [self.detailView addSubview:networkName];

    y -= 35;
  }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return self.categories.count;
}

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row {
  NSTableCellView *cell =
      [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 250, 36)];
  cell.wantsLayer = YES;

  NSDictionary *category = self.categories[row];

  NSTextField *label =
      [[NSTextField alloc] initWithFrame:NSMakeRect(12, 8, 220, 20)];
  label.stringValue = [NSString
      stringWithFormat:@"%@  %@", category[@"icon"], category[@"name"]];
  label.font = [NSFont systemFontOfSize:13];
  label.textColor = [NSColor labelColor];
  label.bezeled = NO;
  label.editable = NO;
  label.drawsBackground = NO;
  [cell addSubview:label];

  return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
  NSInteger row = self.categoriesTable.selectedRow;
  if (row < 0)
    return;

  NSDictionary *category = self.categories[row];
  NSString *name = category[@"name"];

  if ([name isEqualToString:@"About"]) {
    [self showAboutPanel];
  } else if ([name isEqualToString:@"Wi-Fi"]) {
    [self showWiFiPanel];
  } else if ([name isEqualToString:@"Bluetooth"]) {
    [self showBluetoothPanel];
  } else if ([name isEqualToString:@"Fan Control"]) {
    [self showFanControlPanel];
  } else if ([name isEqualToString:@"Battery"]) {
    [self showBatteryPanel];
  } else if ([name isEqualToString:@"Sound"]) {
    [self showSoundPanel];
  } else if ([name isEqualToString:@"Displays"]) {
    [self showDisplaysPanel];
  } else if ([name isEqualToString:@"Appearance"]) {
    [self showAppearancePanel];
  } else if ([name isEqualToString:@"Network"]) {
    [self showNetworkPanel];
  } else if ([name isEqualToString:@"Notifications"]) {
    [self showNotificationsPanel];
  } else if ([name isEqualToString:@"Keyboard"]) {
    [self showKeyboardPanel];
  } else if ([name isEqualToString:@"Trackpad"]) {
    [self showTrackpadPanel];
  } else if ([name isEqualToString:@"Privacy & Security"]) {
    [self showPrivacyPanel];
  }
}

#pragma mark - Fan Control Panel

- (void)showFanControlPanel {
  [self clearDetailView];
  CGFloat y = self.detailView.bounds.size.height - 80;

  NSTextField *title = [self createTitleLabel:@"Fan Control" atY:y];
  [self.detailView addSubview:title];

  y -= 50;

  // Warning box
  NSView *warningBox =
      [[NSView alloc] initWithFrame:NSMakeRect(30, y - 60, 480, 60)];
  warningBox.wantsLayer = YES;
  warningBox.layer.backgroundColor = [[NSColor colorWithRed:1.0
                                                      green:0.95
                                                       blue:0.8
                                                      alpha:1.0] CGColor];
  warningBox.layer.cornerRadius = 8;
  warningBox.layer.borderColor = [[NSColor colorWithRed:0.9
                                                  green:0.8
                                                   blue:0.5
                                                  alpha:1.0] CGColor];
  warningBox.layer.borderWidth = 1;
  [self.detailView addSubview:warningBox];

  NSTextField *warningText =
      [[NSTextField alloc] initWithFrame:NSMakeRect(15, 10, 450, 40)];
  warningText.stringValue =
      @"⚠️ Adjusting fan speed may affect system temperature.\nLower speeds = "
      @"quieter but warmer. Higher speeds = cooler but louder.";
  warningText.font = [NSFont systemFontOfSize:11];
  warningText.textColor = [NSColor colorWithRed:0.6
                                          green:0.5
                                           blue:0.2
                                          alpha:1.0];
  warningText.bezeled = NO;
  warningText.editable = NO;
  warningText.drawsBackground = NO;
  [warningBox addSubview:warningText];

  y -= 100;

  // Current fan speed display
  NSTextField *fanIcon =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 60, 60)];
  fanIcon.stringValue = @"🌀";
  fanIcon.font = [NSFont systemFontOfSize:45];
  fanIcon.bezeled = NO;
  fanIcon.editable = NO;
  fanIcon.drawsBackground = NO;
  [self.detailView addSubview:fanIcon];

  self.fanSpeedLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(100, y + 20, 200, 30)];
  self.fanSpeedLabel.stringValue =
      [NSString stringWithFormat:@"%ld%% Speed", (long)self.currentFanSpeed];
  self.fanSpeedLabel.font = [NSFont systemFontOfSize:24
                                              weight:NSFontWeightSemibold];
  self.fanSpeedLabel.bezeled = NO;
  self.fanSpeedLabel.editable = NO;
  self.fanSpeedLabel.drawsBackground = NO;
  [self.detailView addSubview:self.fanSpeedLabel];

  NSTextField *fanStatus =
      [[NSTextField alloc] initWithFrame:NSMakeRect(100, y, 200, 20)];
  fanStatus.stringValue = [self fanStatusForSpeed:self.currentFanSpeed];
  fanStatus.font = [NSFont systemFontOfSize:12];
  fanStatus.textColor = [NSColor grayColor];
  fanStatus.bezeled = NO;
  fanStatus.editable = NO;
  fanStatus.drawsBackground = NO;
  fanStatus.tag = 100;
  [self.detailView addSubview:fanStatus];

  y -= 60;

  // Fan speed slider
  NSTextField *sliderLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 100, 20)];
  sliderLabel.stringValue = @"Fan Speed:";
  sliderLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  sliderLabel.bezeled = NO;
  sliderLabel.editable = NO;
  sliderLabel.drawsBackground = NO;
  [self.detailView addSubview:sliderLabel];

  y -= 30;

  self.fanSpeedSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(30, y, 450, 26)];
  self.fanSpeedSlider.minValue = 0;
  self.fanSpeedSlider.maxValue = 100;
  self.fanSpeedSlider.integerValue = self.currentFanSpeed;
  self.fanSpeedSlider.target = self;
  self.fanSpeedSlider.action = @selector(fanSpeedChanged:);
  self.fanSpeedSlider.continuous = YES;
  [self.detailView addSubview:self.fanSpeedSlider];

  // Min/Max labels
  NSTextField *minLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y - 20, 50, 15)];
  minLabel.stringValue = @"Silent";
  minLabel.font = [NSFont systemFontOfSize:10];
  minLabel.textColor = [NSColor grayColor];
  minLabel.bezeled = NO;
  minLabel.editable = NO;
  minLabel.drawsBackground = NO;
  [self.detailView addSubview:minLabel];

  NSTextField *maxLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(440, y - 20, 50, 15)];
  maxLabel.stringValue = @"Max";
  maxLabel.font = [NSFont systemFontOfSize:10];
  maxLabel.textColor = [NSColor grayColor];
  maxLabel.bezeled = NO;
  maxLabel.editable = NO;
  maxLabel.drawsBackground = NO;
  [self.detailView addSubview:maxLabel];

  y -= 60;

  // Preset buttons
  NSTextField *presetsLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 100, 20)];
  presetsLabel.stringValue = @"Presets:";
  presetsLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  presetsLabel.bezeled = NO;
  presetsLabel.editable = NO;
  presetsLabel.drawsBackground = NO;
  [self.detailView addSubview:presetsLabel];

  y -= 35;

  NSArray *presets = @[
    @{@"name" : @"Silent", @"value" : @20},
    @{@"name" : @"Balanced", @"value" : @50},
    @{@"name" : @"Performance", @"value" : @80},
    @{@"name" : @"Max Cooling", @"value" : @100}
  ];
  CGFloat btnX = 30;
  for (NSDictionary *preset in presets) {
    NSButton *btn =
        [[NSButton alloc] initWithFrame:NSMakeRect(btnX, y, 110, 32)];
    btn.title = preset[@"name"];
    btn.bezelStyle = NSBezelStyleRounded;
    btn.tag = [preset[@"value"] integerValue];
    btn.target = self;
    btn.action = @selector(fanPresetClicked:);
    [self.detailView addSubview:btn];
    btnX += 115;
  }
}

- (NSString *)fanStatusForSpeed:(NSInteger)speed {
  if (speed < 20)
    return @"Silent Mode - Minimal cooling";
  if (speed < 40)
    return @"Quiet - Light cooling";
  if (speed < 60)
    return @"Balanced - Normal cooling";
  if (speed < 80)
    return @"Performance - Active cooling";
  return @"Maximum - Full cooling power";
}

- (void)fanSpeedChanged:(NSSlider *)sender {
  self.currentFanSpeed = sender.integerValue;
  self.fanSpeedLabel.stringValue =
      [NSString stringWithFormat:@"%ld%% Speed", (long)self.currentFanSpeed];

  // Update status label
  for (NSView *subview in self.detailView.subviews) {
    if (subview.tag == 100 && [subview isKindOfClass:[NSTextField class]]) {
      ((NSTextField *)subview).stringValue =
          [self fanStatusForSpeed:self.currentFanSpeed];
    }
  }

  // Apply fan speed (simulated - real implementation would use SMC)
  [self applyFanSpeed:self.currentFanSpeed];
}

- (void)fanPresetClicked:(NSButton *)sender {
  self.currentFanSpeed = sender.tag;
  self.fanSpeedSlider.integerValue = self.currentFanSpeed;
  [self fanSpeedChanged:self.fanSpeedSlider];
}

- (void)applyFanSpeed:(NSInteger)speed {
  // Note: Real fan control requires SMC access which needs root privileges
  // This is a simulation - actual implementation would use SMCKit or similar
  NSLog(@"[Settings] Fan speed set to %ld%%", (long)speed);
}

#pragma mark - Battery Panel

- (void)showBatteryPanel {
  [self clearDetailView];
  CGFloat y = self.detailView.bounds.size.height - 80;

  NSTextField *title = [self createTitleLabel:@"Battery" atY:y];
  [self.detailView addSubview:title];

  y -= 60;

  // Get battery info
  NSDictionary *batteryInfo = [self getBatteryInfo];
  BOOL hasBattery = [batteryInfo[@"hasBattery"] boolValue];

  if (!hasBattery) {
    NSTextField *noBattery =
        [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 400, 60)];
    noBattery.stringValue =
        @"🔌 No Battery Detected\n\nThis Mac is connected to power and doesn't "
        @"have a battery,\nor the battery information is not available.";
    noBattery.font = [NSFont systemFontOfSize:14];
    noBattery.textColor = [NSColor grayColor];
    noBattery.bezeled = NO;
    noBattery.editable = NO;
    noBattery.drawsBackground = NO;
    [self.detailView addSubview:noBattery];
    return;
  }

  NSInteger percentage = [batteryInfo[@"percentage"] integerValue];
  BOOL isCharging = [batteryInfo[@"isCharging"] boolValue];
  NSInteger health = [batteryInfo[@"health"] integerValue];
  NSString *condition = batteryInfo[@"condition"];

  // Battery icon and percentage
  NSTextField *batteryIcon =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y - 20, 70, 70)];
  batteryIcon.stringValue = isCharging ? @"🔋⚡" : @"🔋";
  batteryIcon.font = [NSFont systemFontOfSize:50];
  batteryIcon.bezeled = NO;
  batteryIcon.editable = NO;
  batteryIcon.drawsBackground = NO;
  [self.detailView addSubview:batteryIcon];

  self.batteryPercentLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(110, y, 150, 35)];
  self.batteryPercentLabel.stringValue =
      [NSString stringWithFormat:@"%ld%%", (long)percentage];
  self.batteryPercentLabel.font = [NSFont systemFontOfSize:32
                                                    weight:NSFontWeightBold];
  self.batteryPercentLabel.bezeled = NO;
  self.batteryPercentLabel.editable = NO;
  self.batteryPercentLabel.drawsBackground = NO;
  [self.detailView addSubview:self.batteryPercentLabel];

  NSTextField *chargingStatus =
      [[NSTextField alloc] initWithFrame:NSMakeRect(110, y - 25, 200, 20)];
  chargingStatus.stringValue = isCharging ? @"Charging" : @"On Battery";
  chargingStatus.font = [NSFont systemFontOfSize:13];
  chargingStatus.textColor = isCharging ? [NSColor colorWithRed:0.2
                                                          green:0.7
                                                           blue:0.3
                                                          alpha:1.0]
                                        : [NSColor grayColor];
  chargingStatus.bezeled = NO;
  chargingStatus.editable = NO;
  chargingStatus.drawsBackground = NO;
  [self.detailView addSubview:chargingStatus];

  y -= 80;

  // Battery progress bar
  self.batteryIndicator =
      [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(30, y, 450, 20)];
  self.batteryIndicator.style = NSProgressIndicatorStyleBar;
  self.batteryIndicator.indeterminate = NO;
  self.batteryIndicator.minValue = 0;
  self.batteryIndicator.maxValue = 100;
  self.batteryIndicator.doubleValue = percentage;
  [self.detailView addSubview:self.batteryIndicator];

  y -= 50;

  // Battery Health section
  NSTextField *healthTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 200, 20)];
  healthTitle.stringValue = @"Battery Health";
  healthTitle.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
  healthTitle.bezeled = NO;
  healthTitle.editable = NO;
  healthTitle.drawsBackground = NO;
  [self.detailView addSubview:healthTitle];

  y -= 35;

  // Health percentage
  NSTextField *healthLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 130, 20)];
  healthLabel.stringValue = @"Maximum Capacity:";
  healthLabel.font = [NSFont systemFontOfSize:13];
  healthLabel.textColor = [NSColor grayColor];
  healthLabel.bezeled = NO;
  healthLabel.editable = NO;
  healthLabel.drawsBackground = NO;
  [self.detailView addSubview:healthLabel];

  self.batteryHealthLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(170, y, 100, 20)];
  self.batteryHealthLabel.stringValue =
      [NSString stringWithFormat:@"%ld%%", (long)health];
  self.batteryHealthLabel.font = [NSFont systemFontOfSize:13
                                                   weight:NSFontWeightMedium];
  self.batteryHealthLabel.textColor =
      health > 80 ? [NSColor colorWithRed:0.2 green:0.7 blue:0.3 alpha:1.0]
                  : (health > 50 ? [NSColor orangeColor] : [NSColor redColor]);
  self.batteryHealthLabel.bezeled = NO;
  self.batteryHealthLabel.editable = NO;
  self.batteryHealthLabel.drawsBackground = NO;
  [self.detailView addSubview:self.batteryHealthLabel];

  y -= 30;

  // Condition
  NSTextField *conditionLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 130, 20)];
  conditionLabel.stringValue = @"Condition:";
  conditionLabel.font = [NSFont systemFontOfSize:13];
  conditionLabel.textColor = [NSColor grayColor];
  conditionLabel.bezeled = NO;
  conditionLabel.editable = NO;
  conditionLabel.drawsBackground = NO;
  [self.detailView addSubview:conditionLabel];

  NSTextField *conditionValue =
      [[NSTextField alloc] initWithFrame:NSMakeRect(170, y, 150, 20)];
  conditionValue.stringValue = condition;
  conditionValue.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  conditionValue.bezeled = NO;
  conditionValue.editable = NO;
  conditionValue.drawsBackground = NO;
  [self.detailView addSubview:conditionValue];

  y -= 50;

  // Battery settings
  NSTextField *settingsTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 200, 20)];
  settingsTitle.stringValue = @"Battery Settings";
  settingsTitle.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
  settingsTitle.bezeled = NO;
  settingsTitle.editable = NO;
  settingsTitle.drawsBackground = NO;
  [self.detailView addSubview:settingsTitle];

  y -= 35;

  NSButton *lowPowerMode =
      [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 300, 20)];
  [lowPowerMode setButtonType:NSButtonTypeSwitch];
  lowPowerMode.title = @"Low Power Mode";
  lowPowerMode.state = NSControlStateValueOff;
  [self.detailView addSubview:lowPowerMode];

  y -= 30;

  NSButton *optimizedCharging =
      [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 300, 20)];
  [optimizedCharging setButtonType:NSButtonTypeSwitch];
  optimizedCharging.title = @"Optimized Battery Charging";
  optimizedCharging.state = NSControlStateValueOn;
  [self.detailView addSubview:optimizedCharging];

  // Start battery monitoring
  [self startBatteryMonitoring];
}

- (NSDictionary *)getBatteryInfo {
  CFTypeRef powerSourceInfo = IOPSCopyPowerSourcesInfo();
  CFArrayRef powerSources = IOPSCopyPowerSourcesList(powerSourceInfo);

  if (!powerSources || CFArrayGetCount(powerSources) == 0) {
    if (powerSources)
      CFRelease(powerSources);
    if (powerSourceInfo)
      CFRelease(powerSourceInfo);
    return @{@"hasBattery" : @NO};
  }

  CFDictionaryRef powerSource = IOPSGetPowerSourceDescription(
      powerSourceInfo, CFArrayGetValueAtIndex(powerSources, 0));

  if (!powerSource) {
    CFRelease(powerSources);
    CFRelease(powerSourceInfo);
    return @{@"hasBattery" : @NO};
  }

  NSNumber *currentCapacity = (__bridge NSNumber *)CFDictionaryGetValue(
      powerSource, CFSTR(kIOPSCurrentCapacityKey));
  NSNumber *maxCapacity = (__bridge NSNumber *)CFDictionaryGetValue(
      powerSource, CFSTR(kIOPSMaxCapacityKey));
  NSString *powerState = (__bridge NSString *)CFDictionaryGetValue(
      powerSource, CFSTR(kIOPSPowerSourceStateKey));

  NSInteger percentage = currentCapacity ? currentCapacity.integerValue : 100;
  BOOL isCharging = [powerState isEqualToString:@"AC Power"];

  // Estimate health (real health requires SMC access)
  NSInteger health =
      maxCapacity ? MIN(100, (maxCapacity.integerValue * 100) / 100) : 95;
  NSString *condition =
      health > 80 ? @"Normal"
                  : (health > 50 ? @"Service Recommended" : @"Service Battery");

  CFRelease(powerSources);
  CFRelease(powerSourceInfo);

  return @{
    @"hasBattery" : @YES,
    @"percentage" : @(percentage),
    @"isCharging" : @(isCharging),
    @"health" : @(health),
    @"condition" : condition
  };
}

- (void)startBatteryMonitoring {
  [self.batteryTimer invalidate];
  self.batteryTimer =
      [NSTimer scheduledTimerWithTimeInterval:30.0
                                       target:self
                                     selector:@selector(updateBatteryInfo)
                                     userInfo:nil
                                      repeats:YES];
}

- (void)updateBatteryInfo {
  NSDictionary *info = [self getBatteryInfo];
  if ([info[@"hasBattery"] boolValue]) {
    self.batteryPercentLabel.stringValue =
        [NSString stringWithFormat:@"%@%%", info[@"percentage"]];
    self.batteryIndicator.doubleValue = [info[@"percentage"] doubleValue];
  }
}

#pragma mark - Bluetooth Panel

- (void)showBluetoothPanel {
  [self clearDetailView];
  CGFloat y = self.detailView.bounds.size.height - 80;

  NSTextField *title = [self createTitleLabel:@"Bluetooth" atY:y];
  [self.detailView addSubview:title];

  y -= 60;

  // Bluetooth toggle
  NSTextField *btLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 100, 25)];
  btLabel.stringValue = @"Bluetooth";
  btLabel.font = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
  btLabel.bezeled = NO;
  btLabel.editable = NO;
  btLabel.drawsBackground = NO;
  [self.detailView addSubview:btLabel];

  NSButton *btToggle =
      [[NSButton alloc] initWithFrame:NSMakeRect(430, y, 60, 25)];
  [btToggle setButtonType:NSButtonTypeSwitch];
  btToggle.title = @"";
  btToggle.state = NSControlStateValueOn;
  btToggle.target = self;
  btToggle.action = @selector(bluetoothToggled:);
  [self.detailView addSubview:btToggle];

  y -= 50;

  // Connected devices
  NSTextField *devicesLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 200, 20)];
  devicesLabel.stringValue = @"My Devices";
  devicesLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
  devicesLabel.textColor = [NSColor grayColor];
  devicesLabel.bezeled = NO;
  devicesLabel.editable = NO;
  devicesLabel.drawsBackground = NO;
  [self.detailView addSubview:devicesLabel];

  y -= 40;

  NSArray *devices = @[
    @{@"name" : @"AirPods Pro", @"icon" : @"🎧", @"status" : @"Connected"},
    @{@"name" : @"Magic Keyboard", @"icon" : @"⌨️", @"status" : @"Connected"},
    @{@"name" : @"Magic Mouse", @"icon" : @"🖱", @"status" : @"Not Connected"}
  ];

  for (NSDictionary *device in devices) {
    NSView *deviceRow =
        [[NSView alloc] initWithFrame:NSMakeRect(30, y - 10, 450, 40)];
    deviceRow.wantsLayer = YES;
    deviceRow.layer.backgroundColor = [[NSColor colorWithRed:0.16
                                                       green:0.16
                                                        blue:0.19
                                                       alpha:1.0] CGColor];
    deviceRow.layer.cornerRadius = 8;
    [self.detailView addSubview:deviceRow];

    NSTextField *icon =
        [[NSTextField alloc] initWithFrame:NSMakeRect(10, 8, 30, 25)];
    icon.stringValue = device[@"icon"];
    icon.font = [NSFont systemFontOfSize:20];
    icon.bezeled = NO;
    icon.editable = NO;
    icon.drawsBackground = NO;
    [deviceRow addSubview:icon];

    NSTextField *name =
        [[NSTextField alloc] initWithFrame:NSMakeRect(45, 12, 200, 18)];
    name.stringValue = device[@"name"];
    name.font = [NSFont systemFontOfSize:13];
    name.bezeled = NO;
    name.editable = NO;
    name.drawsBackground = NO;
    [deviceRow addSubview:name];

    NSTextField *status =
        [[NSTextField alloc] initWithFrame:NSMakeRect(300, 12, 140, 18)];
    status.stringValue = device[@"status"];
    status.font = [NSFont systemFontOfSize:12];
    status.textColor = [device[@"status"] isEqualToString:@"Connected"]
                           ? [NSColor colorWithRed:0.2
                                             green:0.7
                                              blue:0.3
                                             alpha:1.0]
                           : [NSColor grayColor];
    status.alignment = NSTextAlignmentRight;
    status.bezeled = NO;
    status.editable = NO;
    status.drawsBackground = NO;
    [deviceRow addSubview:status];

    y -= 50;
  }

  y -= 20;

  // Options
  NSButton *showInMenuBar =
      [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 300, 20)];
  [showInMenuBar setButtonType:NSButtonTypeSwitch];
  showInMenuBar.title = @"Show Bluetooth in menu bar";
  showInMenuBar.state = NSControlStateValueOn;
  [self.detailView addSubview:showInMenuBar];
}

- (void)bluetoothToggled:(NSButton *)sender {
  NSLog(@"[Settings] Bluetooth %@",
        sender.state == NSControlStateValueOn ? @"enabled" : @"disabled");
}

#pragma mark - Sound Panel

- (void)showSoundPanel {
  [self clearDetailView];
  CGFloat y = self.detailView.bounds.size.height - 80;

  NSTextField *title = [self createTitleLabel:@"Sound" atY:y];
  [self.detailView addSubview:title];

  y -= 60;

  // Output volume
  NSTextField *outputLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 150, 20)];
  outputLabel.stringValue = @"Output Volume";
  outputLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  outputLabel.bezeled = NO;
  outputLabel.editable = NO;
  outputLabel.drawsBackground = NO;
  [self.detailView addSubview:outputLabel];

  y -= 30;

  NSTextField *speakerIcon =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 25, 20)];
  speakerIcon.stringValue = @"🔈";
  speakerIcon.bezeled = NO;
  speakerIcon.editable = NO;
  speakerIcon.drawsBackground = NO;
  [self.detailView addSubview:speakerIcon];

  NSSlider *volumeSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(60, y, 380, 26)];
  volumeSlider.minValue = 0;
  volumeSlider.maxValue = 100;
  volumeSlider.integerValue = 75;
  [self.detailView addSubview:volumeSlider];

  NSTextField *speakerIconMax =
      [[NSTextField alloc] initWithFrame:NSMakeRect(450, y, 25, 20)];
  speakerIconMax.stringValue = @"🔊";
  speakerIconMax.bezeled = NO;
  speakerIconMax.editable = NO;
  speakerIconMax.drawsBackground = NO;
  [self.detailView addSubview:speakerIconMax];

  y -= 40;

  NSButton *muteCheckbox =
      [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 100, 20)];
  [muteCheckbox setButtonType:NSButtonTypeSwitch];
  muteCheckbox.title = @"Mute";
  [self.detailView addSubview:muteCheckbox];

  y -= 50;

  // Output device
  NSTextField *outputDeviceLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 150, 20)];
  outputDeviceLabel.stringValue = @"Output Device";
  outputDeviceLabel.font = [NSFont systemFontOfSize:13
                                             weight:NSFontWeightMedium];
  outputDeviceLabel.bezeled = NO;
  outputDeviceLabel.editable = NO;
  outputDeviceLabel.drawsBackground = NO;
  [self.detailView addSubview:outputDeviceLabel];

  y -= 35;

  NSArray *outputDevices =
      @[ @"MacBook Pro Speakers", @"AirPods Pro", @"External Display" ];
  for (NSString *device in outputDevices) {
    NSButton *deviceBtn =
        [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 300, 20)];
    [deviceBtn setButtonType:NSButtonTypeRadio];
    deviceBtn.title = device;
    deviceBtn.state = [device isEqualToString:@"MacBook Pro Speakers"]
                          ? NSControlStateValueOn
                          : NSControlStateValueOff;
    [self.detailView addSubview:deviceBtn];
    y -= 25;
  }

  y -= 30;

  // Alert sounds
  NSTextField *alertLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 150, 20)];
  alertLabel.stringValue = @"Alert Sound";
  alertLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  alertLabel.bezeled = NO;
  alertLabel.editable = NO;
  alertLabel.drawsBackground = NO;
  [self.detailView addSubview:alertLabel];

  y -= 30;

  NSPopUpButton *alertPopup =
      [[NSPopUpButton alloc] initWithFrame:NSMakeRect(30, y, 200, 25)
                                 pullsDown:NO];
  [alertPopup addItemsWithTitles:@[
    @"Boop", @"Breeze", @"Bubble", @"Crystal", @"Funky", @"Heroine", @"Jump",
    @"Mezzo", @"Pebble", @"Pluck"
  ]];
  [self.detailView addSubview:alertPopup];
}

#pragma mark - Displays Panel

- (void)showDisplaysPanel {
  [self clearDetailView];
  CGFloat y = self.detailView.bounds.size.height - 80;

  NSTextField *title = [self createTitleLabel:@"Displays" atY:y];
  [self.detailView addSubview:title];

  y -= 60;

  // Display icon
  NSTextField *displayIcon =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y - 30, 80, 80)];
  displayIcon.stringValue = @"🖥";
  displayIcon.font = [NSFont systemFontOfSize:55];
  displayIcon.bezeled = NO;
  displayIcon.editable = NO;
  displayIcon.drawsBackground = NO;
  [self.detailView addSubview:displayIcon];

  NSTextField *displayName =
      [[NSTextField alloc] initWithFrame:NSMakeRect(120, y, 300, 25)];
  displayName.stringValue = @"Built-in Retina Display";
  displayName.font = [NSFont systemFontOfSize:16 weight:NSFontWeightSemibold];
  displayName.bezeled = NO;
  displayName.editable = NO;
  displayName.drawsBackground = NO;
  [self.detailView addSubview:displayName];

  NSTextField *displayRes =
      [[NSTextField alloc] initWithFrame:NSMakeRect(120, y - 25, 300, 20)];
  displayRes.stringValue = @"2560 x 1600 Retina";
  displayRes.font = [NSFont systemFontOfSize:12];
  displayRes.textColor = [NSColor grayColor];
  displayRes.bezeled = NO;
  displayRes.editable = NO;
  displayRes.drawsBackground = NO;
  [self.detailView addSubview:displayRes];

  y -= 80;

  // Brightness
  NSTextField *brightnessLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 100, 20)];
  brightnessLabel.stringValue = @"Brightness";
  brightnessLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  brightnessLabel.bezeled = NO;
  brightnessLabel.editable = NO;
  brightnessLabel.drawsBackground = NO;
  [self.detailView addSubview:brightnessLabel];

  y -= 30;

  NSTextField *sunMin =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 25, 20)];
  sunMin.stringValue = @"☀️";
  sunMin.font = [NSFont systemFontOfSize:12];
  sunMin.bezeled = NO;
  sunMin.editable = NO;
  sunMin.drawsBackground = NO;
  [self.detailView addSubview:sunMin];

  NSSlider *brightnessSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(55, y, 380, 26)];
  brightnessSlider.minValue = 0;
  brightnessSlider.maxValue = 100;
  brightnessSlider.integerValue = 80;
  [self.detailView addSubview:brightnessSlider];

  NSTextField *sunMax =
      [[NSTextField alloc] initWithFrame:NSMakeRect(445, y, 30, 20)];
  sunMax.stringValue = @"☀️";
  sunMax.font = [NSFont systemFontOfSize:18];
  sunMax.bezeled = NO;
  sunMax.editable = NO;
  sunMax.drawsBackground = NO;
  [self.detailView addSubview:sunMax];

  y -= 40;

  NSButton *autoBrightness =
      [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 250, 20)];
  [autoBrightness setButtonType:NSButtonTypeSwitch];
  autoBrightness.title = @"Automatically adjust brightness";
  autoBrightness.state = NSControlStateValueOn;
  [self.detailView addSubview:autoBrightness];

  y -= 40;

  // Night Shift
  NSTextField *nightShiftLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 100, 20)];
  nightShiftLabel.stringValue = @"Night Shift";
  nightShiftLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  nightShiftLabel.bezeled = NO;
  nightShiftLabel.editable = NO;
  nightShiftLabel.drawsBackground = NO;
  [self.detailView addSubview:nightShiftLabel];

  NSButton *nightShiftToggle =
      [[NSButton alloc] initWithFrame:NSMakeRect(430, y, 60, 25)];
  [nightShiftToggle setButtonType:NSButtonTypeSwitch];
  nightShiftToggle.title = @"";
  nightShiftToggle.state = NSControlStateValueOff;
  [self.detailView addSubview:nightShiftToggle];

  y -= 40;

  // True Tone
  NSButton *trueTone =
      [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 200, 20)];
  [trueTone setButtonType:NSButtonTypeSwitch];
  trueTone.title = @"True Tone";
  trueTone.state = NSControlStateValueOn;
  [self.detailView addSubview:trueTone];
}

#pragma mark - Appearance Panel

- (void)showAppearancePanel {
  [self clearDetailView];
  CGFloat y = self.detailView.bounds.size.height - 80;

  NSTextField *title = [self createTitleLabel:@"Appearance" atY:y];
  [self.detailView addSubview:title];

  y -= 60;

  // Appearance mode
  NSTextField *modeLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 150, 20)];
  modeLabel.stringValue = @"Appearance";
  modeLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  modeLabel.bezeled = NO;
  modeLabel.editable = NO;
  modeLabel.drawsBackground = NO;
  [self.detailView addSubview:modeLabel];

  y -= 80;

  // Mode buttons
  NSArray *modes = @[
    @{@"icon" : @"☀️", @"name" : @"Light"},
    @{@"icon" : @"🌙", @"name" : @"Dark"}, @{@"icon" : @"🔄", @"name" : @"Auto"}
  ];
  CGFloat modeX = 30;
  for (NSDictionary *mode in modes) {
    NSButton *modeBtn =
        [[NSButton alloc] initWithFrame:NSMakeRect(modeX, y, 120, 70)];
    modeBtn.title =
        [NSString stringWithFormat:@"%@\n%@", mode[@"icon"], mode[@"name"]];
    modeBtn.bezelStyle = NSBezelStyleRounded;
    [modeBtn setButtonType:NSButtonTypeOnOff];
    modeBtn.state = [mode[@"name"] isEqualToString:@"Light"]
                        ? NSControlStateValueOn
                        : NSControlStateValueOff;
    [self.detailView addSubview:modeBtn];
    modeX += 130;
  }

  y -= 50;

  // Accent color
  NSTextField *accentLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 150, 20)];
  accentLabel.stringValue = @"Accent Color";
  accentLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  accentLabel.bezeled = NO;
  accentLabel.editable = NO;
  accentLabel.drawsBackground = NO;
  [self.detailView addSubview:accentLabel];

  y -= 35;

  NSArray *colors = @[
    [NSColor blueColor], [NSColor purpleColor], [NSColor systemPinkColor],
    [NSColor redColor], [NSColor orangeColor], [NSColor yellowColor],
    [NSColor greenColor], [NSColor grayColor]
  ];
  CGFloat colorX = 30;
  for (NSColor *color in colors) {
    NSView *colorDot =
        [[NSView alloc] initWithFrame:NSMakeRect(colorX, y, 24, 24)];
    colorDot.wantsLayer = YES;
    colorDot.layer.backgroundColor = color.CGColor;
    colorDot.layer.cornerRadius = 12;
    colorDot.layer.borderWidth = color == [NSColor blueColor] ? 2 : 0;
    colorDot.layer.borderColor = [NSColor whiteColor].CGColor;
    [self.detailView addSubview:colorDot];
    colorX += 32;
  }
}

#pragma mark - Other Panels

- (void)showNetworkPanel {
  [self clearDetailView];
  [self.detailView
      addSubview:[self
                     createTitleLabel:@"Network"
                                  atY:self.detailView.bounds.size.height - 80]];

  CGFloat y = self.detailView.bounds.size.height - 140;

  NSArray *connections = @[
    @{
      @"icon" : @"📶",
      @"name" : @"Wi-Fi",
      @"status" : @"Connected",
      @"detail" : @"Home Network"
    },
    @{
      @"icon" : @"🔌",
      @"name" : @"Ethernet",
      @"status" : @"Not Connected",
      @"detail" : @""
    },
    @{
      @"icon" : @"🔥",
      @"name" : @"Firewall",
      @"status" : @"On",
      @"detail" : @""
    }
  ];

  for (NSDictionary *conn in connections) {
    NSView *row = [[NSView alloc] initWithFrame:NSMakeRect(30, y, 450, 50)];
    row.wantsLayer = YES;
    row.layer.backgroundColor = [[NSColor colorWithWhite:0.97
                                                   alpha:1.0] CGColor];
    row.layer.cornerRadius = 8;
    [self.detailView addSubview:row];

    NSTextField *icon =
        [[NSTextField alloc] initWithFrame:NSMakeRect(15, 12, 30, 25)];
    icon.stringValue = conn[@"icon"];
    icon.font = [NSFont systemFontOfSize:22];
    icon.bezeled = NO;
    icon.editable = NO;
    icon.drawsBackground = NO;
    [row addSubview:icon];

    NSTextField *name =
        [[NSTextField alloc] initWithFrame:NSMakeRect(55, 15, 150, 20)];
    name.stringValue = conn[@"name"];
    name.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    name.bezeled = NO;
    name.editable = NO;
    name.drawsBackground = NO;
    [row addSubview:name];

    NSTextField *status =
        [[NSTextField alloc] initWithFrame:NSMakeRect(300, 15, 140, 20)];
    NSString *statusText =
        [conn[@"detail"] length] > 0
            ? [NSString
                  stringWithFormat:@"%@ - %@", conn[@"status"], conn[@"detail"]]
            : conn[@"status"];
    status.stringValue = statusText;
    status.font = [NSFont systemFontOfSize:12];
    status.textColor = [conn[@"status"] isEqualToString:@"Connected"] ||
                               [conn[@"status"] isEqualToString:@"On"]
                           ? [NSColor colorWithRed:0.2
                                             green:0.7
                                              blue:0.3
                                             alpha:1.0]
                           : [NSColor grayColor];
    status.alignment = NSTextAlignmentRight;
    status.bezeled = NO;
    status.editable = NO;
    status.drawsBackground = NO;
    [row addSubview:status];

    y -= 60;
  }
}

- (void)showNotificationsPanel {
  [self clearDetailView];
  [self.detailView
      addSubview:[self
                     createTitleLabel:@"Notifications"
                                  atY:self.detailView.bounds.size.height - 80]];

  CGFloat y = self.detailView.bounds.size.height - 140;

  NSButton *allowNotifications =
      [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 300, 20)];
  [allowNotifications setButtonType:NSButtonTypeSwitch];
  allowNotifications.title = @"Allow Notifications";
  allowNotifications.state = NSControlStateValueOn;
  [self.detailView addSubview:allowNotifications];

  y -= 40;

  NSButton *showPreviews =
      [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 300, 20)];
  [showPreviews setButtonType:NSButtonTypeSwitch];
  showPreviews.title = @"Show previews";
  showPreviews.state = NSControlStateValueOn;
  [self.detailView addSubview:showPreviews];

  y -= 40;

  NSButton *playSound =
      [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 300, 20)];
  [playSound setButtonType:NSButtonTypeSwitch];
  playSound.title = @"Play sound for notifications";
  playSound.state = NSControlStateValueOn;
  [self.detailView addSubview:playSound];
}

- (void)showKeyboardPanel {
  [self clearDetailView];
  [self.detailView
      addSubview:[self
                     createTitleLabel:@"Keyboard"
                                  atY:self.detailView.bounds.size.height - 80]];

  CGFloat y = self.detailView.bounds.size.height - 140;

  NSTextField *repeatLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 100, 20)];
  repeatLabel.stringValue = @"Key Repeat";
  repeatLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  repeatLabel.bezeled = NO;
  repeatLabel.editable = NO;
  repeatLabel.drawsBackground = NO;
  [self.detailView addSubview:repeatLabel];

  y -= 30;

  NSSlider *repeatSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(30, y, 400, 26)];
  repeatSlider.minValue = 0;
  repeatSlider.maxValue = 100;
  repeatSlider.integerValue = 70;
  [self.detailView addSubview:repeatSlider];

  y -= 50;

  NSTextField *delayLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 150, 20)];
  delayLabel.stringValue = @"Delay Until Repeat";
  delayLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  delayLabel.bezeled = NO;
  delayLabel.editable = NO;
  delayLabel.drawsBackground = NO;
  [self.detailView addSubview:delayLabel];

  y -= 30;

  NSSlider *delaySlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(30, y, 400, 26)];
  delaySlider.minValue = 0;
  delaySlider.maxValue = 100;
  delaySlider.integerValue = 40;
  [self.detailView addSubview:delaySlider];

  y -= 50;

  NSButton *capsLock =
      [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 350, 20)];
  [capsLock setButtonType:NSButtonTypeSwitch];
  capsLock.title = @"Use Caps Lock to switch input sources";
  [self.detailView addSubview:capsLock];
}

- (void)showTrackpadPanel {
  [self clearDetailView];
  [self.detailView
      addSubview:[self
                     createTitleLabel:@"Trackpad"
                                  atY:self.detailView.bounds.size.height - 80]];

  CGFloat y = self.detailView.bounds.size.height - 140;

  NSTextField *speedLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 150, 20)];
  speedLabel.stringValue = @"Tracking Speed";
  speedLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  speedLabel.bezeled = NO;
  speedLabel.editable = NO;
  speedLabel.drawsBackground = NO;
  [self.detailView addSubview:speedLabel];

  y -= 30;

  NSSlider *speedSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(30, y, 400, 26)];
  speedSlider.minValue = 0;
  speedSlider.maxValue = 100;
  speedSlider.integerValue = 60;
  [self.detailView addSubview:speedSlider];

  y -= 50;

  NSButton *tapToClick =
      [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 200, 20)];
  [tapToClick setButtonType:NSButtonTypeSwitch];
  tapToClick.title = @"Tap to click";
  tapToClick.state = NSControlStateValueOn;
  [self.detailView addSubview:tapToClick];

  y -= 30;

  NSButton *naturalScroll =
      [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 200, 20)];
  [naturalScroll setButtonType:NSButtonTypeSwitch];
  naturalScroll.title = @"Natural scrolling";
  naturalScroll.state = NSControlStateValueOn;
  [self.detailView addSubview:naturalScroll];

  y -= 30;

  NSButton *forceClick =
      [[NSButton alloc] initWithFrame:NSMakeRect(30, y, 250, 20)];
  [forceClick setButtonType:NSButtonTypeSwitch];
  forceClick.title = @"Force Click and haptic feedback";
  forceClick.state = NSControlStateValueOn;
  [self.detailView addSubview:forceClick];
}

- (void)showPrivacyPanel {
  [self clearDetailView];
  [self.detailView
      addSubview:[self
                     createTitleLabel:@"Privacy & Security"
                                  atY:self.detailView.bounds.size.height - 80]];

  CGFloat y = self.detailView.bounds.size.height - 140;

  NSArray *privacyItems = @[
    @{@"icon" : @"📍", @"name" : @"Location Services", @"status" : @"On"},
    @{@"icon" : @"📷", @"name" : @"Camera", @"status" : @"3 apps"},
    @{@"icon" : @"🎤", @"name" : @"Microphone", @"status" : @"2 apps"},
    @{@"icon" : @"📁", @"name" : @"Files and Folders", @"status" : @"5 apps"},
    @{@"icon" : @"🔐", @"name" : @"Full Disk Access", @"status" : @"1 app"}
  ];

  for (NSDictionary *item in privacyItems) {
    NSView *row = [[NSView alloc] initWithFrame:NSMakeRect(30, y, 450, 40)];
    row.wantsLayer = YES;
    row.layer.backgroundColor = [[NSColor colorWithWhite:0.97
                                                   alpha:1.0] CGColor];
    row.layer.cornerRadius = 6;
    [self.detailView addSubview:row];

    NSTextField *icon =
        [[NSTextField alloc] initWithFrame:NSMakeRect(10, 8, 25, 25)];
    icon.stringValue = item[@"icon"];
    icon.bezeled = NO;
    icon.editable = NO;
    icon.drawsBackground = NO;
    [row addSubview:icon];

    NSTextField *name =
        [[NSTextField alloc] initWithFrame:NSMakeRect(40, 10, 200, 20)];
    name.stringValue = item[@"name"];
    name.font = [NSFont systemFontOfSize:13];
    name.bezeled = NO;
    name.editable = NO;
    name.drawsBackground = NO;
    [row addSubview:name];

    NSTextField *status =
        [[NSTextField alloc] initWithFrame:NSMakeRect(350, 10, 90, 20)];
    status.stringValue = item[@"status"];
    status.font = [NSFont systemFontOfSize:12];
    status.textColor = [NSColor grayColor];
    status.alignment = NSTextAlignmentRight;
    status.bezeled = NO;
    status.editable = NO;
    status.drawsBackground = NO;
    [row addSubview:status];

    y -= 50;
  }
}

#pragma mark - Helpers

- (void)clearDetailView {
  for (NSView *subview in [self.detailView.subviews copy]) {
    [subview removeFromSuperview];
  }
}

- (NSTextField *)createTitleLabel:(NSString *)text atY:(CGFloat)y {
  NSTextField *title =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, y, 400, 35)];
  title.stringValue = text;
  title.font = [NSFont systemFontOfSize:28 weight:NSFontWeightBold];
  title.bezeled = NO;
  title.editable = NO;
  title.drawsBackground = NO;
  return title;
}

@end
