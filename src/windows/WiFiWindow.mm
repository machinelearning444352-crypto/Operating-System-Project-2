#import "WiFiWindow.h"
#import "../services/NetworkEngine.h"
#import <QuartzCore/QuartzCore.h>

@interface WiFiWindow ()
@property(nonatomic, strong) NSWindow *wifiWindow;
@property(nonatomic, strong) NSTableView *networksTable;
@property(nonatomic, strong) NSMutableArray<WiFiNetworkEntry *> *networks;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSTextField *currentNetworkLabel;
@property(nonatomic, strong) NSProgressIndicator *scanningIndicator;
@property(nonatomic, strong) NSMutableDictionary *savedPasswords;

// Real connection details panel
@property(nonatomic, strong) NSTextField *ipLabel;
@property(nonatomic, strong) NSTextField *gatewayLabel;
@property(nonatomic, strong) NSTextField *dnsLabel;
@property(nonatomic, strong) NSTextField *bssidLabel;
@property(nonatomic, strong) NSTextField *channelLabel;
@property(nonatomic, strong) NSTextField *rssiLabel;
@property(nonatomic, strong) NSTextField *txRateLabel;
@property(nonatomic, strong) NSTextField *securityLabel;
@property(nonatomic, strong) NSTextField *macLabel;
@property(nonatomic, strong) NSTextField *throughputInLabel;
@property(nonatomic, strong) NSTextField *throughputOutLabel;
@property(nonatomic, strong) NSView *detailPanel;
@property(nonatomic, strong) NetworkEngine *engine;
@end

@implementation WiFiWindow

+ (instancetype)sharedInstance {
  static WiFiWindow *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[WiFiWindow alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.networks = [NSMutableArray array];
    self.savedPasswords = [NSMutableDictionary dictionary];
    self.engine = [NetworkEngine sharedInstance];
  }
  return self;
}

- (void)showWindow {
  if (self.wifiWindow) {
    [self.wifiWindow makeKeyAndOrderFront:nil];
    [self refreshAll];
    return;
  }

  NSRect frame = NSMakeRect(0, 0, 480, 700);
  self.wifiWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.wifiWindow.title = @"Wi-Fi";
  self.wifiWindow.minSize = NSMakeSize(420, 600);
  [self.wifiWindow center];

  NSView *contentView = [[NSView alloc] initWithFrame:frame];
  contentView.wantsLayer = YES;
  contentView.layer.backgroundColor =
      [NSColor windowBackgroundColor].CGColor;
  self.wifiWindow.contentView = contentView;

  CGFloat y = frame.size.height;

  // ===== Header =====
  NSView *header = [[NSView alloc]
      initWithFrame:NSMakeRect(0, y - 80, frame.size.width, 80)];
  header.wantsLayer = YES;
  header.autoresizingMask = NSViewWidthSizable;

  CAGradientLayer *grad = [CAGradientLayer layer];
  grad.colors = @[
    (__bridge id)[NSColor colorWithRed:0.15 green:0.45 blue:0.95 alpha:1.0]
        .CGColor,
    (__bridge id)[NSColor colorWithRed:0.1 green:0.3 blue:0.75 alpha:1.0]
        .CGColor
  ];
  grad.frame = header.bounds;
  header.layer = grad;
  header.wantsLayer = YES;
  [contentView addSubview:header];
  y -= 80;

  NSTextField *titleLabel = [self makeLabelAt:NSMakeRect(20, 40, 250, 28)
                                         text:@"📶 Wi-Fi Networks"
                                         size:20
                                         bold:YES];
  titleLabel.textColor = [NSColor whiteColor];
  [header addSubview:titleLabel];

  NSTextField *subtitleLabel =
      [self makeLabelAt:NSMakeRect(20, 20, 300, 16)
                   text:@"Real scanning • Real connectivity"
                   size:11
                   bold:NO];
  subtitleLabel.textColor = [NSColor colorWithWhite:1.0 alpha:0.7];
  [header addSubview:subtitleLabel];

  // WiFi toggle
  NSButton *wifiToggle = [[NSButton alloc]
      initWithFrame:NSMakeRect(frame.size.width - 90, 35, 80, 30)];
  [wifiToggle setButtonType:NSButtonTypeSwitch];
  wifiToggle.title = @"Wi-Fi";
  wifiToggle.state = [self.engine isWiFiEnabled] ? NSControlStateValueOn
                                                 : NSControlStateValueOff;
  wifiToggle.target = self;
  wifiToggle.action = @selector(toggleWifi:);
  [header addSubview:wifiToggle];

  // ===== Connection Details Panel =====
  self.detailPanel = [[NSView alloc]
      initWithFrame:NSMakeRect(10, y - 165, frame.size.width - 20, 160)];
  self.detailPanel.wantsLayer = YES;
  self.detailPanel.layer.backgroundColor =
      [NSColor controlBackgroundColor].CGColor;
  self.detailPanel.layer.cornerRadius = 10;
  [contentView addSubview:self.detailPanel];
  y -= 170;

  [self setupDetailPanel];

  // ===== Current network label =====
  self.currentNetworkLabel =
      [self makeLabelAt:NSMakeRect(15, y - 22, frame.size.width - 30, 18)
                   text:@"Available Networks"
                   size:13
                   bold:YES];
  self.currentNetworkLabel.textColor = [NSColor colorWithWhite:0.7 alpha:1.0];
  [contentView addSubview:self.currentNetworkLabel];
  y -= 28;

  // ===== Networks Table =====
  NSScrollView *scrollView = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(10, 55, frame.size.width - 20, y - 60)];
  scrollView.hasVerticalScroller = YES;
  scrollView.autohidesScrollers = YES;
  scrollView.wantsLayer = YES;
  scrollView.layer.cornerRadius = 8;
  scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  self.networksTable = [[NSTableView alloc] initWithFrame:scrollView.bounds];
  self.networksTable.dataSource = self;
  self.networksTable.delegate = self;
  self.networksTable.rowHeight = 55;
  self.networksTable.headerView = nil;
  self.networksTable.backgroundColor = [NSColor colorWithRed:0.14
                                                       green:0.14
                                                        blue:0.17
                                                       alpha:1.0];
  self.networksTable.gridColor = [NSColor colorWithWhite:0.2 alpha:1.0];

  NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"network"];
  col.width = scrollView.bounds.size.width;
  [self.networksTable addTableColumn:col];

  scrollView.documentView = self.networksTable;
  [contentView addSubview:scrollView];

  // ===== Bottom bar =====
  self.statusLabel = [self makeLabelAt:NSMakeRect(15, 22, 280, 18)
                                  text:@""
                                  size:11
                                  bold:NO];
  self.statusLabel.textColor = [NSColor colorWithWhite:0.5 alpha:1.0];
  [contentView addSubview:self.statusLabel];

  self.scanningIndicator =
      [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(300, 25, 16, 16)];
  self.scanningIndicator.style = NSProgressIndicatorStyleSpinning;
  self.scanningIndicator.controlSize = NSControlSizeSmall;
  [self.scanningIndicator setHidden:YES];
  [contentView addSubview:self.scanningIndicator];

  NSButton *scanBtn = [[NSButton alloc]
      initWithFrame:NSMakeRect(frame.size.width - 100, 18, 85, 28)];
  scanBtn.title = @"↻ Scan";
  scanBtn.bezelStyle = NSBezelStyleRounded;
  scanBtn.target = self;
  scanBtn.action = @selector(scanForNetworks);
  [contentView addSubview:scanBtn];

  [self.wifiWindow makeKeyAndOrderFront:nil];
  [self refreshAll];

  // Start live throughput monitoring
  [self.engine
      startThroughputMonitoring:^(double bytesInPerSec, double bytesOutPerSec) {
        self.throughputInLabel.stringValue = [self formatBytes:bytesInPerSec];
        self.throughputOutLabel.stringValue = [self formatBytes:bytesOutPerSec];
      }
                       interval:2.0];
}

- (void)setupDetailPanel {
  CGFloat w = self.detailPanel.bounds.size.width;
  CGFloat midX = w / 2;
  CGFloat y = 135;
  CGFloat rowH = 18;

  // Title
  NSTextField *detTitle = [self makeLabelAt:NSMakeRect(12, y, w - 24, 18)
                                       text:@"Connection Details"
                                       size:12
                                       bold:YES];
  detTitle.textColor = [NSColor colorWithWhite:0.8 alpha:1.0];
  [self.detailPanel addSubview:detTitle];
  y -= rowH + 4;

  // Left column
  [self.detailPanel addSubview:[self makeInfoLabel:@"IP Address:"
                                                at:NSMakeRect(12, y, 90, 15)]];
  self.ipLabel = [self makeValueLabel:@"—"
                                   at:NSMakeRect(105, y, midX - 115, 15)];
  [self.detailPanel addSubview:self.ipLabel];

  [self.detailPanel
      addSubview:[self makeInfoLabel:@"Router:"
                                  at:NSMakeRect(midX, y, 70, 15)]];
  self.gatewayLabel =
      [self makeValueLabel:@"—" at:NSMakeRect(midX + 72, y, midX - 85, 15)];
  [self.detailPanel addSubview:self.gatewayLabel];
  y -= rowH;

  [self.detailPanel addSubview:[self makeInfoLabel:@"DNS:"
                                                at:NSMakeRect(12, y, 90, 15)]];
  self.dnsLabel = [self makeValueLabel:@"—"
                                    at:NSMakeRect(105, y, midX - 115, 15)];
  [self.detailPanel addSubview:self.dnsLabel];

  [self.detailPanel
      addSubview:[self makeInfoLabel:@"BSSID:" at:NSMakeRect(midX, y, 70, 15)]];
  self.bssidLabel =
      [self makeValueLabel:@"—" at:NSMakeRect(midX + 72, y, midX - 85, 15)];
  [self.detailPanel addSubview:self.bssidLabel];
  y -= rowH;

  [self.detailPanel addSubview:[self makeInfoLabel:@"Channel:"
                                                at:NSMakeRect(12, y, 90, 15)]];
  self.channelLabel = [self makeValueLabel:@"—"
                                        at:NSMakeRect(105, y, midX - 115, 15)];
  [self.detailPanel addSubview:self.channelLabel];

  [self.detailPanel
      addSubview:[self makeInfoLabel:@"Signal:"
                                  at:NSMakeRect(midX, y, 70, 15)]];
  self.rssiLabel =
      [self makeValueLabel:@"—" at:NSMakeRect(midX + 72, y, midX - 85, 15)];
  [self.detailPanel addSubview:self.rssiLabel];
  y -= rowH;

  [self.detailPanel addSubview:[self makeInfoLabel:@"Tx Rate:"
                                                at:NSMakeRect(12, y, 90, 15)]];
  self.txRateLabel = [self makeValueLabel:@"—"
                                       at:NSMakeRect(105, y, midX - 115, 15)];
  [self.detailPanel addSubview:self.txRateLabel];

  [self.detailPanel
      addSubview:[self makeInfoLabel:@"Security:"
                                  at:NSMakeRect(midX, y, 70, 15)]];
  self.securityLabel =
      [self makeValueLabel:@"—" at:NSMakeRect(midX + 72, y, midX - 85, 15)];
  [self.detailPanel addSubview:self.securityLabel];
  y -= rowH;

  [self.detailPanel addSubview:[self makeInfoLabel:@"MAC:"
                                                at:NSMakeRect(12, y, 90, 15)]];
  self.macLabel = [self makeValueLabel:@"—"
                                    at:NSMakeRect(105, y, midX - 115, 15)];
  [self.detailPanel addSubview:self.macLabel];
  y -= rowH;

  // Throughput
  [self.detailPanel addSubview:[self makeInfoLabel:@"↓ In:"
                                                at:NSMakeRect(12, y, 50, 15)]];
  self.throughputInLabel = [self makeValueLabel:@"0 B/s"
                                             at:NSMakeRect(65, y, 100, 15)];
  self.throughputInLabel.textColor = [NSColor colorWithRed:0.3
                                                     green:0.8
                                                      blue:0.4
                                                     alpha:1.0];
  [self.detailPanel addSubview:self.throughputInLabel];

  [self.detailPanel
      addSubview:[self makeInfoLabel:@"↑ Out:" at:NSMakeRect(midX, y, 50, 15)]];
  self.throughputOutLabel =
      [self makeValueLabel:@"0 B/s" at:NSMakeRect(midX + 55, y, 100, 15)];
  self.throughputOutLabel.textColor = [NSColor colorWithRed:0.4
                                                      green:0.6
                                                       blue:0.95
                                                      alpha:1.0];
  [self.detailPanel addSubview:self.throughputOutLabel];
}

- (void)refreshAll {
  [self updateConnectionDetails];
  [self scanForNetworks];
}

- (void)updateConnectionDetails {
  WiFiConnectionDetails *details = [self.engine currentConnectionDetails];

  if (details.ssid && ![details.ssid isEqualToString:@"Not connected"]) {
    self.ipLabel.stringValue = details.ipAddress ?: @"—";
    self.gatewayLabel.stringValue = details.routerIP ?: @"—";
    self.dnsLabel.stringValue =
        (details.dnsServers.count > 0) ? details.dnsServers[0] : @"—";
    self.bssidLabel.stringValue = details.bssid ?: @"—";
    self.channelLabel.stringValue =
        [NSString stringWithFormat:@"%ld (%@)", (long)details.channel,
                                   details.band ?: @"—"];
    self.rssiLabel.stringValue =
        [NSString stringWithFormat:@"%ld dBm", (long)details.rssi];
    self.txRateLabel.stringValue =
        [NSString stringWithFormat:@"%.0f Mbps", details.txRate];
    self.securityLabel.stringValue = details.securityType ?: @"—";
    self.macLabel.stringValue = details.macAddress ?: @"—";
    self.detailPanel.hidden = NO;
  } else {
    self.ipLabel.stringValue = @"—";
    self.gatewayLabel.stringValue = @"—";
    self.dnsLabel.stringValue = @"—";
    self.bssidLabel.stringValue = @"—";
    self.channelLabel.stringValue = @"—";
    self.rssiLabel.stringValue = @"—";
    self.txRateLabel.stringValue = @"—";
    self.securityLabel.stringValue = @"—";
    self.macLabel.stringValue = @"—";
  }
}

#pragma mark - WiFi Control

- (void)toggleWifi:(NSButton *)sender {
  BOOL enable = (sender.state == NSControlStateValueOn);
  [self.engine setWiFiEnabled:enable];

  if (!enable) {
    [self.networks removeAllObjects];
    [self.networksTable reloadData];
    self.statusLabel.stringValue = @"Wi-Fi is off";
    self.currentNetworkLabel.stringValue = @"Wi-Fi is disabled";
  } else {
    self.currentNetworkLabel.stringValue = @"Available Networks";
    [self refreshAll];
  }
}

- (void)scanForNetworks {
  if (![self.engine isWiFiEnabled]) {
    self.statusLabel.stringValue = @"Wi-Fi is off";
    return;
  }

  [self.scanningIndicator setHidden:NO];
  [self.scanningIndicator startAnimation:nil];
  self.statusLabel.stringValue = @"Scanning...";

  [self.engine
      scanForNetworks:^(NSArray<WiFiNetworkEntry *> *networks, NSError *error) {
        [self.scanningIndicator stopAnimation:nil];
        [self.scanningIndicator setHidden:YES];

        [self.networks removeAllObjects];

        // Put currently connected network first
        NSString *currentSSID = [self.engine currentSSID];
        for (WiFiNetworkEntry *net in networks) {
          if ([net.ssid isEqualToString:currentSSID]) {
            net.isCurrentNetwork = YES;
            [self.networks insertObject:net atIndex:0];
          } else {
            [self.networks addObject:net];
          }
        }

        self.statusLabel.stringValue =
            [NSString stringWithFormat:@"%lu real networks found",
                                       (unsigned long)self.networks.count];
        [self.networksTable reloadData];
        [self updateConnectionDetails];
      }];
}

- (void)connectToNetwork:(NSButton *)sender {
  NSInteger row = sender.tag;
  if (row < 0 || row >= (NSInteger)self.networks.count)
    return;

  WiFiNetworkEntry *entry = self.networks[row];

  if (entry.isSecured) {
    NSString *saved = self.savedPasswords[entry.ssid];
    [self showPasswordDialog:entry.ssid savedPassword:saved];
  } else {
    self.statusLabel.stringValue =
        [NSString stringWithFormat:@"Connecting to %@...", entry.ssid];
    [self.engine
        connectToOpenNetwork:entry.ssid
                  completion:^(BOOL success, NSString *errorMsg) {
                    if (success) {
                      self.statusLabel.stringValue = [NSString
                          stringWithFormat:@"✓ Connected to %@", entry.ssid];
                      [self refreshAll];
                    } else {
                      self.statusLabel.stringValue = [NSString
                          stringWithFormat:@"✗ Failed: %@",
                                           errorMsg ?: @"Unknown error"];
                    }
                  }];
  }
}

- (void)showPasswordDialog:(NSString *)ssid savedPassword:(NSString *)saved {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText =
      [NSString stringWithFormat:@"Enter password for \"%@\"", ssid];
  alert.informativeText = @"This network requires a WPA/WPA2/WPA3 password.";

  NSSecureTextField *pwField =
      [[NSSecureTextField alloc] initWithFrame:NSMakeRect(0, 0, 260, 24)];
  pwField.placeholderString = @"Password";
  if (saved)
    pwField.stringValue = saved;
  alert.accessoryView = pwField;

  [alert addButtonWithTitle:@"Join"];
  [alert addButtonWithTitle:@"Cancel"];

  [alert
      beginSheetModalForWindow:self.wifiWindow
             completionHandler:^(NSModalResponse rc) {
               if (rc == NSAlertFirstButtonReturn) {
                 NSString *password = pwField.stringValue;
                 if (password.length < 8) {
                   self.statusLabel.stringValue =
                       @"Password must be at least 8 characters";
                   return;
                 }

                 self.statusLabel.stringValue =
                     [NSString stringWithFormat:@"Connecting to %@...", ssid];
                 [self.engine
                     connectToNetwork:ssid
                             password:password
                           completion:^(BOOL success, NSString *errorMsg) {
                             if (success) {
                               self.savedPasswords[ssid] = password;
                               self.statusLabel.stringValue = [NSString
                                   stringWithFormat:@"✓ Connected to %@", ssid];
                               [self refreshAll];
                             } else {
                               NSString *msg = errorMsg
                                                   ?: @"Incorrect password or "
                                                      @"connection failed";
                               self.statusLabel.stringValue =
                                   [NSString stringWithFormat:@"✗ %@", msg];

                               NSAlert *errAlert = [[NSAlert alloc] init];
                               errAlert.messageText = @"Connection Failed";
                               errAlert.informativeText = msg;
                               errAlert.alertStyle = NSAlertStyleWarning;
                               [errAlert addButtonWithTitle:@"Try Again"];
                               [errAlert addButtonWithTitle:@"Cancel"];
                               [errAlert
                                   beginSheetModalForWindow:self.wifiWindow
                                          completionHandler:^(
                                              NSModalResponse rc2) {
                                            if (rc2 ==
                                                NSAlertFirstButtonReturn) {
                                              [self showPasswordDialog:ssid
                                                         savedPassword:nil];
                                            }
                                          }];
                             }
                           }];
               }
             }];
}

- (void)disconnectFromNetwork:(NSButton *)sender {
  NSString *ssid = [self.engine currentSSID];
  [self.engine disconnectFromCurrentNetwork];
  self.statusLabel.stringValue =
      [NSString stringWithFormat:@"Disconnected from %@", ssid ?: @"network"];
  [self refreshAll];
}

#pragma mark - Table View

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return self.networks.count;
}

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row {
  NSTableCellView *cell = [[NSTableCellView alloc]
      initWithFrame:NSMakeRect(0, 0, tableView.bounds.size.width, 55)];
  cell.wantsLayer = YES;

  if (row >= (NSInteger)self.networks.count)
    return cell;

  WiFiNetworkEntry *entry = self.networks[row];

  // Signal strength bar
  NSView *signalBar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 4, 55)];
  signalBar.wantsLayer = YES;
  if (entry.rssi >= -50)
    signalBar.layer.backgroundColor =
        [NSColor colorWithRed:0.2 green:0.8 blue:0.35 alpha:1.0].CGColor;
  else if (entry.rssi >= -65)
    signalBar.layer.backgroundColor =
        [NSColor colorWithRed:0.4 green:0.7 blue:0.3 alpha:1.0].CGColor;
  else if (entry.rssi >= -75)
    signalBar.layer.backgroundColor = [NSColor systemOrangeColor].CGColor;
  else
    signalBar.layer.backgroundColor = [NSColor systemRedColor].CGColor;
  [cell addSubview:signalBar];

  // Signal icon
  NSTextField *signalIcon = [self makeLabelAt:NSMakeRect(12, 18, 30, 22)
                                         text:[self signalIcon:entry.rssi]
                                         size:18
                                         bold:NO];
  [cell addSubview:signalIcon];

  // SSID
  NSTextField *ssidLabel = [self makeLabelAt:NSMakeRect(44, 28, 200, 20)
                                        text:entry.ssid
                                        size:14
                                        bold:entry.isCurrentNetwork];
  ssidLabel.textColor = entry.isCurrentNetwork ? [NSColor colorWithRed:0.3
                                                                 green:0.85
                                                                  blue:0.45
                                                                 alpha:1.0]
                                               : [NSColor whiteColor];
  [cell addSubview:ssidLabel];

  // Info line: security, channel, band, RSSI
  NSString *info = [NSString
      stringWithFormat:@"%@ %@  •  Ch %ld %@  •  %ld dBm",
                       entry.isSecured ? @"🔒" : @"🔓", entry.securityType,
                       (long)entry.channel, entry.band, (long)entry.rssi];
  NSTextField *infoLabel = [self makeLabelAt:NSMakeRect(44, 10, 280, 15)
                                        text:info
                                        size:10
                                        bold:NO];
  infoLabel.textColor = [NSColor colorWithWhite:0.5 alpha:1.0];
  [cell addSubview:infoLabel];

  // Connect / Disconnect button
  NSButton *btn = [[NSButton alloc]
      initWithFrame:NSMakeRect(tableView.bounds.size.width - 100, 14, 85, 26)];
  if (entry.isCurrentNetwork) {
    btn.title = @"Disconnect";
    btn.action = @selector(disconnectFromNetwork:);
  } else {
    btn.title = @"Connect";
    btn.action = @selector(connectToNetwork:);
  }
  btn.bezelStyle = NSBezelStyleRounded;
  btn.font = [NSFont systemFontOfSize:11];
  btn.tag = row;
  btn.target = self;
  [cell addSubview:btn];

  return cell;
}

#pragma mark - Helpers

- (NSString *)signalIcon:(NSInteger)rssi {
  if (rssi >= -50)
    return @"📶";
  if (rssi >= -65)
    return @"📶";
  if (rssi >= -75)
    return @"📡";
  return @"📡";
}

- (NSString *)formatBytes:(double)bytesPerSec {
  if (bytesPerSec < 1024)
    return [NSString stringWithFormat:@"%.0f B/s", bytesPerSec];
  if (bytesPerSec < 1024 * 1024)
    return [NSString stringWithFormat:@"%.1f KB/s", bytesPerSec / 1024.0];
  return
      [NSString stringWithFormat:@"%.2f MB/s", bytesPerSec / (1024.0 * 1024.0)];
}

- (NSTextField *)makeLabelAt:(NSRect)frame
                        text:(NSString *)text
                        size:(CGFloat)size
                        bold:(BOOL)bold {
  NSTextField *tf = [[NSTextField alloc] initWithFrame:frame];
  tf.stringValue = text;
  tf.font = bold ? [NSFont boldSystemFontOfSize:size]
                 : [NSFont systemFontOfSize:size];
  tf.textColor = [NSColor whiteColor];
  tf.editable = NO;
  tf.bordered = NO;
  tf.drawsBackground = NO;
  return tf;
}

- (NSTextField *)makeInfoLabel:(NSString *)text at:(NSRect)frame {
  NSTextField *tf = [[NSTextField alloc] initWithFrame:frame];
  tf.stringValue = text;
  tf.font = [NSFont systemFontOfSize:10];
  tf.textColor = [NSColor colorWithWhite:0.5 alpha:1.0];
  tf.editable = NO;
  tf.bordered = NO;
  tf.drawsBackground = NO;
  return tf;
}

- (NSTextField *)makeValueLabel:(NSString *)text at:(NSRect)frame {
  NSTextField *tf = [[NSTextField alloc] initWithFrame:frame];
  tf.stringValue = text;
  tf.font = [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightRegular];
  tf.textColor = [NSColor colorWithWhite:0.85 alpha:1.0];
  tf.editable = NO;
  tf.bordered = NO;
  tf.drawsBackground = NO;
  return tf;
}

- (void)dealloc {
  [self.engine stopThroughputMonitoring];
}

@end
