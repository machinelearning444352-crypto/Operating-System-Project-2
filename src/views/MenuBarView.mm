#import "MenuBarView.h"
#import <IOKit/ps/IOPSKeys.h>
#import <IOKit/ps/IOPowerSources.h>

// ============================================================================
// MenuBarView.mm — Pixel-Perfect macOS Sequoia Menu Bar
// SF Symbols, real dropdown menus, proper vibrancy, accurate spacing
// ============================================================================

// macOS Sequoia menu bar constants
static const CGFloat kMenuBarHeight = 24.0;
static const CGFloat kMenuBarPadding = 10.0;
static const CGFloat kMenuItemSpacing = 16.0;
static const CGFloat kStatusIconSpacing = 8.0;
static const CGFloat kStatusIconSize = 18.0;
static const CGFloat kAppleLogoWidth = 30.0;
static const CGFloat kMenuItemHoverRadius = 4.0;

@interface MenuBarView ()
@property(nonatomic, strong) NSMutableArray *menuItemRects;
@property(nonatomic, assign) NSInteger hoveredItem;
@property(nonatomic, assign) NSRect appleLogoRect;
@property(nonatomic, assign) NSRect wifiRect;
@property(nonatomic, assign) NSRect bluetoothRect;
@property(nonatomic, assign) NSRect controlCenterRect;
@property(nonatomic, assign) NSRect batteryRect;
@property(nonatomic, assign) NSRect spotlightRect;
@property(nonatomic, assign) NSRect soundRect;
@property(nonatomic, assign) NSRect focusRect;
@property(nonatomic, assign) NSRect clockRect;
@property(nonatomic, strong) NSVisualEffectView *vibrancyView;
@property(nonatomic, strong) NSFont *menuFont;
@property(nonatomic, strong) NSFont *menuBoldFont;
@property(nonatomic, strong) NSFont *clockFont;
@property(nonatomic, strong) NSFont *statusFont;
@property(nonatomic, assign) BOOL menuActive;
@property(nonatomic, assign) NSInteger activeMenuIndex;
@end

@implementation MenuBarView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    // ── Fonts (exact macOS system fonts) ──
    _menuFont = [NSFont systemFontOfSize:13.0 weight:NSFontWeightRegular];
    _menuBoldFont = [NSFont systemFontOfSize:13.0 weight:NSFontWeightSemibold];
    _clockFont = [NSFont monospacedDigitSystemFontOfSize:13.0
                                                  weight:NSFontWeightMedium];
    _statusFont = [NSFont systemFontOfSize:10.0 weight:NSFontWeightMedium];

    // ── Time formatter ──
    _timeFormatter = [[NSDateFormatter alloc] init];
    [_timeFormatter setDateFormat:@"EEE MMM d  h:mm a"];
    _currentTime = [_timeFormatter stringFromDate:[NSDate date]];
    _activeApp = @"Finder";
    _hoveredItem = -1;
    _menuItemRects = [NSMutableArray array];
    _menuActive = NO;
    _activeMenuIndex = -1;

    // ── State defaults ──
    _wifiEnabled = YES;
    _bluetoothEnabled = YES;
    _batteryLevel = [self queryBatteryLevel];
    _batteryCharging = NO;
    _focusModeActive = NO;
    _notificationCount = 0;

    // ── Vibrancy (real macOS translucency) ──
    _vibrancyView = [[NSVisualEffectView alloc] initWithFrame:self.bounds];
    _vibrancyView.material = NSVisualEffectMaterialMenu;
    _vibrancyView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    _vibrancyView.state = NSVisualEffectStateActive;
    _vibrancyView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    [self addSubview:_vibrancyView positioned:NSWindowBelow relativeTo:nil];

    // ── Clock timer ──
    _clockTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                   target:self
                                                 selector:@selector(updateClock)
                                                 userInfo:nil
                                                  repeats:YES];

    // ── Mouse tracking ──
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc]
        initWithRect:self.bounds
             options:(NSTrackingMouseMoved | NSTrackingActiveAlways |
                      NSTrackingMouseEnteredAndExited | NSTrackingInVisibleRect)
               owner:self
            userInfo:nil];
    [self addTrackingArea:trackingArea];
  }
  return self;
}

- (void)updateClock {
  if (self.timeFormatter) {
    self.currentTime = [self.timeFormatter stringFromDate:[NSDate date]];
  }
  self.batteryLevel = [self queryBatteryLevel];
  [self setNeedsDisplay:YES];
}

- (void)setActiveApplication:(NSString *)appName {
  self.activeApp = appName;
  [self setNeedsDisplay:YES];
}

#pragma mark - Battery Query (IOKit — no sudo needed)

- (CGFloat)queryBatteryLevel {
  CFTypeRef info = IOPSCopyPowerSourcesInfo();
  if (!info)
    return 100.0;
  CFArrayRef sources = IOPSCopyPowerSourcesList(info);
  if (!sources) {
    CFRelease(info);
    return 100.0;
  }

  CGFloat level = 100.0;
  CFIndex count = CFArrayGetCount(sources);
  for (CFIndex i = 0; i < count; i++) {
    CFDictionaryRef desc =
        IOPSGetPowerSourceDescription(info, CFArrayGetValueAtIndex(sources, i));
    if (!desc)
      continue;

    CFNumberRef capacityRef =
        (CFNumberRef)CFDictionaryGetValue(desc, CFSTR(kIOPSCurrentCapacityKey));
    CFNumberRef maxRef =
        (CFNumberRef)CFDictionaryGetValue(desc, CFSTR(kIOPSMaxCapacityKey));
    if (capacityRef && maxRef) {
      int capacity, maxCapacity;
      CFNumberGetValue(capacityRef, kCFNumberIntType, &capacity);
      CFNumberGetValue(maxRef, kCFNumberIntType, &maxCapacity);
      if (maxCapacity > 0)
        level = (CGFloat)capacity / maxCapacity * 100.0;
    }

    CFStringRef chargingState = (CFStringRef)CFDictionaryGetValue(
        desc, CFSTR(kIOPSPowerSourceStateKey));
    if (chargingState) {
      self.batteryCharging =
          CFStringCompare(chargingState, CFSTR(kIOPSACPowerValue), 0) ==
          kCFCompareEqualTo;
    }
  }
  CFRelease(sources);
  CFRelease(info);
  return level;
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
  [self.menuItemRects removeAllObjects];

  CGFloat barH = self.bounds.size.height;
  CGFloat barW = self.bounds.size.width;

  // ── Bottom separator (1px, like real macOS) ──
  [[NSColor colorWithWhite:0.0 alpha:0.08] setFill];
  NSRectFill(NSMakeRect(0, 0, barW, 0.5));

  // ── LEFT SIDE ──
  CGFloat xLeft = kMenuBarPadding;

  // Apple logo (SF Symbol)
  self.appleLogoRect = NSMakeRect(xLeft - 4, 0, kAppleLogoWidth, barH);
  [self drawAppleLogo:xLeft barH:barH];
  xLeft += kAppleLogoWidth;

  // Active app name (semibold, like real macOS)
  NSDictionary *appAttrs = @{
    NSFontAttributeName : self.menuBoldFont,
    NSForegroundColorAttributeName : [NSColor colorWithWhite:0.0 alpha:0.88]
  };
  NSSize appSize = [self.activeApp sizeWithAttributes:appAttrs];
  NSRect appRect = NSMakeRect(xLeft - 4, 0, appSize.width + 12, barH);
  [self.menuItemRects addObject:@{
    @"rect" : [NSValue valueWithRect:appRect],
    @"name" : self.activeApp,
    @"index" : @(0)
  }];

  if (self.hoveredItem == 0) {
    [self drawMenuHighlight:NSMakeRect(xLeft - 4, 2, appSize.width + 8,
                                       barH - 4)];
  }
  [self.activeApp drawAtPoint:NSMakePoint(xLeft, (barH - appSize.height) / 2)
               withAttributes:appAttrs];
  xLeft += appSize.width + kMenuItemSpacing;

  // Standard menus
  NSArray *menus = @[ @"File", @"Edit", @"View", @"Go", @"Window", @"Help" ];
  NSDictionary *menuAttrs = @{
    NSFontAttributeName : self.menuFont,
    NSForegroundColorAttributeName : [NSColor colorWithWhite:0.0 alpha:0.85]
  };

  for (NSInteger i = 0; i < (NSInteger)menus.count; i++) {
    NSString *item = menus[i];
    NSSize sz = [item sizeWithAttributes:menuAttrs];
    NSRect itemRect = NSMakeRect(xLeft - 4, 0, sz.width + 8, barH);
    [self.menuItemRects addObject:@{
      @"rect" : [NSValue valueWithRect:itemRect],
      @"name" : item,
      @"index" : @(i + 1)
    }];

    if (self.hoveredItem == (i + 1)) {
      [self drawMenuHighlight:NSMakeRect(xLeft - 4, 2, sz.width + 8, barH - 4)];
    }
    [item drawAtPoint:NSMakePoint(xLeft, (barH - sz.height) / 2)
        withAttributes:menuAttrs];
    xLeft += sz.width + kMenuItemSpacing;
  }

  // ── RIGHT SIDE (status icons, right-to-left) ──
  CGFloat xRight = barW - kMenuBarPadding;

  // Clock
  xRight = [self drawClock:xRight barH:barH];

  // Spotlight (magnifying glass)
  xRight -= kStatusIconSpacing;
  xRight = [self drawSpotlightIcon:xRight barH:barH];

  // Control Center
  xRight -= kStatusIconSpacing;
  xRight = [self drawControlCenterIcon:xRight barH:barH];

  // Focus mode (moon)
  if (self.focusModeActive) {
    xRight -= kStatusIconSpacing;
    xRight = [self drawFocusIcon:xRight barH:barH];
  }

  // Sound
  xRight -= kStatusIconSpacing;
  xRight = [self drawSoundIcon:xRight barH:barH];

  // Battery
  xRight -= kStatusIconSpacing;
  xRight = [self drawBattery:xRight barH:barH];

  // WiFi
  xRight -= kStatusIconSpacing;
  xRight = [self drawWiFiIcon:xRight barH:barH];

  // Bluetooth
  xRight -= kStatusIconSpacing;
  xRight = [self drawBluetoothIcon:xRight barH:barH];
}

#pragma mark - Apple Logo

- (void)drawAppleLogo:(CGFloat)x barH:(CGFloat)barH {
  if (self.hoveredItem == -2) {
    [self
        drawMenuHighlight:NSMakeRect(x - 2, 2, kAppleLogoWidth - 6, barH - 4)];
  }

  // Try SF Symbol first
  NSImage *appleImg = [NSImage imageWithSystemSymbolName:@"apple.logo"
                                accessibilityDescription:@"Apple"];
  if (appleImg) {
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration
        configurationWithPointSize:14.0
                            weight:NSFontWeightMedium
                             scale:NSImageSymbolScaleMedium];
    NSImage *configured = [appleImg imageWithSymbolConfiguration:config];

    [configured drawInRect:NSMakeRect(x + 4, (barH - 16) / 2, 16, 16)
                  fromRect:NSZeroRect
                 operation:NSCompositingOperationSourceOver
                  fraction:0.88];
  } else {
    // Fallback: draw Apple symbol as text
    NSDictionary *attrs = @{
      NSFontAttributeName : [NSFont systemFontOfSize:15
                                              weight:NSFontWeightMedium],
      NSForegroundColorAttributeName : [NSColor colorWithWhite:0.0 alpha:0.88]
    };
    NSSize sz = [@"" sizeWithAttributes:attrs];
    [@"" drawAtPoint:NSMakePoint(x + 4, (barH - sz.height) / 2)
        withAttributes:attrs];
  }
}

#pragma mark - Status Icons (SF Symbols)

- (CGFloat)drawWiFiIcon:(CGFloat)rightEdge barH:(CGFloat)barH {
  NSString *symbolName = self.wifiEnabled ? @"wifi" : @"wifi.slash";
  CGFloat w = [self drawSFSymbol:symbolName
                         atRight:rightEdge
                            barH:barH
                            size:14.0
                           alpha:0.85];
  self.wifiRect = NSMakeRect(rightEdge - w - 2, 0, w + 4, barH);
  return rightEdge - w;
}

- (CGFloat)drawBluetoothIcon:(CGFloat)rightEdge barH:(CGFloat)barH {
  NSString *symbolName = self.bluetoothEnabled ? @"bluetooth" : @"bluetooth";
  CGFloat w = [self drawSFSymbol:symbolName
                         atRight:rightEdge
                            barH:barH
                            size:13.0
                           alpha:0.80];
  self.bluetoothRect = NSMakeRect(rightEdge - w - 2, 0, w + 4, barH);
  return rightEdge - w;
}

- (CGFloat)drawControlCenterIcon:(CGFloat)rightEdge barH:(CGFloat)barH {
  CGFloat w = [self drawSFSymbol:@"switch.2"
                         atRight:rightEdge
                            barH:barH
                            size:14.0
                           alpha:0.85];
  self.controlCenterRect = NSMakeRect(rightEdge - w - 2, 0, w + 4, barH);
  return rightEdge - w;
}

- (CGFloat)drawSpotlightIcon:(CGFloat)rightEdge barH:(CGFloat)barH {
  CGFloat w = [self drawSFSymbol:@"magnifyingglass"
                         atRight:rightEdge
                            barH:barH
                            size:13.0
                           alpha:0.80];
  self.spotlightRect = NSMakeRect(rightEdge - w - 2, 0, w + 4, barH);
  return rightEdge - w;
}

- (CGFloat)drawSoundIcon:(CGFloat)rightEdge barH:(CGFloat)barH {
  CGFloat w = [self drawSFSymbol:@"speaker.wave.2.fill"
                         atRight:rightEdge
                            barH:barH
                            size:13.0
                           alpha:0.80];
  self.soundRect = NSMakeRect(rightEdge - w - 2, 0, w + 4, barH);
  return rightEdge - w;
}

- (CGFloat)drawFocusIcon:(CGFloat)rightEdge barH:(CGFloat)barH {
  CGFloat w = [self drawSFSymbol:@"moon.fill"
                         atRight:rightEdge
                            barH:barH
                            size:12.0
                           alpha:0.80];
  self.focusRect = NSMakeRect(rightEdge - w - 2, 0, w + 4, barH);
  return rightEdge - w;
}

- (CGFloat)drawSFSymbol:(NSString *)name
                atRight:(CGFloat)rightEdge
                   barH:(CGFloat)barH
                   size:(CGFloat)size
                  alpha:(CGFloat)alpha {
  NSImage *img = [NSImage imageWithSystemSymbolName:name
                           accessibilityDescription:name];
  CGFloat iconW = size;
  CGFloat iconH = size;

  if (img) {
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration
        configurationWithPointSize:size
                            weight:NSFontWeightMedium
                             scale:NSImageSymbolScaleSmall];
    NSImage *configured = [img imageWithSymbolConfiguration:config];
    NSSize imgSz = configured.size;
    iconW = imgSz.width;
    iconH = imgSz.height;
    if (iconW > 20)
      iconW = 20;
    if (iconH > 16)
      iconH = 16;

    CGFloat drawX = rightEdge - iconW;
    CGFloat drawY = (barH - iconH) / 2;
    [configured drawInRect:NSMakeRect(drawX, drawY, iconW, iconH)
                  fromRect:NSZeroRect
                 operation:NSCompositingOperationSourceOver
                  fraction:alpha];
  } else {
    // Fallback: draw text symbol
    NSDictionary *attrs = @{
      NSFontAttributeName : [NSFont systemFontOfSize:size - 1],
      NSForegroundColorAttributeName : [NSColor colorWithWhite:0.0 alpha:alpha]
    };
    NSString *fallback = @"●";
    if ([name containsString:@"wifi"])
      fallback = @"⟡";
    else if ([name containsString:@"bluetooth"])
      fallback = @"ᛒ";
    else if ([name containsString:@"magnifyingglass"])
      fallback = @"⌕";
    else if ([name containsString:@"switch"])
      fallback = @"⊞";
    else if ([name containsString:@"speaker"])
      fallback = @"♪";
    else if ([name containsString:@"moon"])
      fallback = @"☾";

    NSSize sz = [fallback sizeWithAttributes:attrs];
    iconW = sz.width;
    [fallback drawAtPoint:NSMakePoint(rightEdge - iconW, (barH - sz.height) / 2)
           withAttributes:attrs];
  }
  return iconW;
}

#pragma mark - Battery

- (CGFloat)drawBattery:(CGFloat)rightEdge barH:(CGFloat)barH {
  CGFloat totalW = 38; // battery icon + percentage text
  CGFloat battX = rightEdge - totalW;

  // ── Battery body (22×10 rounded rect) ──
  CGFloat bodyW = 22, bodyH = 10;
  CGFloat bodyY = (barH - bodyH) / 2;
  CGFloat bodyX = battX;

  NSBezierPath *bodyPath = [NSBezierPath
      bezierPathWithRoundedRect:NSMakeRect(bodyX, bodyY, bodyW, bodyH)
                        xRadius:2.5
                        yRadius:2.5];
  [[NSColor colorWithWhite:0.0 alpha:0.70] setStroke];
  [bodyPath setLineWidth:1.0];
  [bodyPath stroke];

  // ── Battery terminal nub ──
  NSRect nubRect = NSMakeRect(bodyX + bodyW, bodyY + 3, 2, 4);
  [[NSColor colorWithWhite:0.0 alpha:0.45] setFill];
  [[NSBezierPath bezierPathWithRoundedRect:nubRect xRadius:0.5
                                   yRadius:0.5] fill];

  // ── Battery fill ──
  CGFloat fillW = (bodyW - 3) * (self.batteryLevel / 100.0);
  if (fillW < 1)
    fillW = 1;
  NSRect fillRect = NSMakeRect(bodyX + 1.5, bodyY + 1.5, fillW, bodyH - 3);

  NSColor *fillColor;
  if (self.batteryLevel > 20) {
    fillColor = [NSColor colorWithRed:0.25 green:0.78 blue:0.35 alpha:0.9];
  } else if (self.batteryLevel > 10) {
    fillColor = [NSColor colorWithRed:0.95 green:0.65 blue:0.10 alpha:0.9];
  } else {
    fillColor = [NSColor colorWithRed:0.95 green:0.25 blue:0.20 alpha:0.9];
  }
  [fillColor setFill];
  [[NSBezierPath bezierPathWithRoundedRect:fillRect xRadius:1.5
                                   yRadius:1.5] fill];

  // ── Charging bolt ──
  if (self.batteryCharging) {
    NSDictionary *boltAttrs = @{
      NSFontAttributeName : [NSFont systemFontOfSize:7 weight:NSFontWeightBold],
      NSForegroundColorAttributeName : [NSColor whiteColor]
    };
    [@"⚡" drawAtPoint:NSMakePoint(bodyX + 7, bodyY + 1)
        withAttributes:boltAttrs];
  }

  // ── Percentage text ──
  NSString *pctText =
      [NSString stringWithFormat:@"%d%%", (int)self.batteryLevel];
  NSDictionary *pctAttrs = @{
    NSFontAttributeName : self.statusFont,
    NSForegroundColorAttributeName : [NSColor colorWithWhite:0.0 alpha:0.70]
  };
  NSSize pctSz = [pctText sizeWithAttributes:pctAttrs];
  [pctText drawAtPoint:NSMakePoint(bodyX + bodyW + 4, (barH - pctSz.height) / 2)
        withAttributes:pctAttrs];

  self.batteryRect = NSMakeRect(battX - 2, 0, totalW + 4, barH);
  return battX;
}

#pragma mark - Clock

- (CGFloat)drawClock:(CGFloat)rightEdge barH:(CGFloat)barH {
  NSDictionary *clockAttrs = @{
    NSFontAttributeName : self.clockFont,
    NSForegroundColorAttributeName : [NSColor colorWithWhite:0.0 alpha:0.85]
  };
  NSSize clockSz = [self.currentTime sizeWithAttributes:clockAttrs];
  CGFloat clockX = rightEdge - clockSz.width;

  self.clockRect = NSMakeRect(clockX - 4, 0, clockSz.width + 8, barH);

  [self.currentTime drawAtPoint:NSMakePoint(clockX, (barH - clockSz.height) / 2)
                 withAttributes:clockAttrs];
  return clockX;
}

#pragma mark - Menu Highlight

- (void)drawMenuHighlight:(NSRect)rect {
  NSBezierPath *hl =
      [NSBezierPath bezierPathWithRoundedRect:rect
                                      xRadius:kMenuItemHoverRadius
                                      yRadius:kMenuItemHoverRadius];
  [[NSColor colorWithWhite:0.0 alpha:0.08] setFill];
  [hl fill];
}

#pragma mark - Mouse Events

- (void)mouseMoved:(NSEvent *)event {
  NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
  NSInteger oldHovered = self.hoveredItem;
  self.hoveredItem = -1;

  if (NSPointInRect(loc, self.appleLogoRect)) {
    self.hoveredItem = -2;
  } else {
    for (NSInteger i = 0; i < (NSInteger)self.menuItemRects.count; i++) {
      NSDictionary *info = self.menuItemRects[i];
      NSRect rect = [info[@"rect"] rectValue];
      if (NSPointInRect(loc, rect)) {
        self.hoveredItem = [info[@"index"] integerValue];
        break;
      }
    }
  }

  if (oldHovered != self.hoveredItem) {
    [self setNeedsDisplay:YES];
  }
}

- (void)mouseExited:(NSEvent *)event {
  self.hoveredItem = -1;
  self.menuActive = NO;
  [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)event {
  NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];

  // ── Apple menu ──
  if (NSPointInRect(loc, self.appleLogoRect)) {
    [self showAppleMenu:loc];
    return;
  }

  // ── Standard menus ──
  for (NSDictionary *info in self.menuItemRects) {
    NSRect rect = [info[@"rect"] rectValue];
    if (NSPointInRect(loc, rect)) {
      NSString *name = info[@"name"];
      NSInteger idx = [info[@"index"] integerValue];

      if (idx == 0) {
        // App menu
        [self showAppMenu:name at:loc];
      } else {
        [self showStandardMenu:name at:loc];
      }
      return;
    }
  }

  // ── Status icon clicks ──
  if (NSPointInRect(loc, self.wifiRect)) {
    [self showWiFiMenu:loc];
  } else if (NSPointInRect(loc, self.bluetoothRect)) {
    if ([self.delegate respondsToSelector:@selector(menuBarBluetoothClicked)])
      [self.delegate menuBarBluetoothClicked];
  } else if (NSPointInRect(loc, self.controlCenterRect)) {
    if ([self.delegate
            respondsToSelector:@selector(menuBarControlCenterClicked)])
      [self.delegate menuBarControlCenterClicked];
  } else if (NSPointInRect(loc, self.spotlightRect)) {
    if ([self.delegate respondsToSelector:@selector(menuBarSpotlightClicked)])
      [self.delegate menuBarSpotlightClicked];
  }
}

#pragma mark - Dropdown Menus (real NSMenu)

- (void)showAppleMenu:(NSPoint)loc {
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Apple"];
  menu.font = self.menuFont;

  [menu addItemWithTitle:@"About This Mac"
                  action:@selector(appleMenuAction:)
           keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"System Preferences..."
                  action:@selector(appleMenuAction:)
           keyEquivalent:@","];
  [menu addItemWithTitle:@"App Store..."
                  action:@selector(appleMenuAction:)
           keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Recent Items" action:nil keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Force Quit..."
                  action:@selector(appleMenuAction:)
           keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Sleep"
                  action:@selector(appleMenuAction:)
           keyEquivalent:@""];
  [menu addItemWithTitle:@"Restart..."
                  action:@selector(appleMenuAction:)
           keyEquivalent:@""];
  [menu addItemWithTitle:@"Shut Down..."
                  action:@selector(appleMenuAction:)
           keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Lock Screen"
                  action:@selector(appleMenuAction:)
           keyEquivalent:@"q"];
  [menu addItemWithTitle:@"Log Out..."
                  action:@selector(appleMenuAction:)
           keyEquivalent:@""];

  for (NSMenuItem *item in menu.itemArray) {
    item.target = self;
  }

  NSPoint menuPt = NSMakePoint(self.appleLogoRect.origin.x, 0);
  [menu popUpMenuPositioningItem:nil atLocation:menuPt inView:self];
}

- (void)showAppMenu:(NSString *)appName at:(NSPoint)loc {
  NSMenu *menu = [[NSMenu alloc] initWithTitle:appName];
  menu.font = self.menuFont;

  [menu addItemWithTitle:[NSString stringWithFormat:@"About %@", appName]
                  action:@selector(stdMenuAction:)
           keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Preferences..."
                  action:@selector(stdMenuAction:)
           keyEquivalent:@","];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Services" action:nil keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:[NSString stringWithFormat:@"Hide %@", appName]
                  action:@selector(stdMenuAction:)
           keyEquivalent:@"h"];
  [menu addItemWithTitle:@"Hide Others"
                  action:@selector(stdMenuAction:)
           keyEquivalent:@""];
  [menu addItemWithTitle:@"Show All"
                  action:@selector(stdMenuAction:)
           keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:[NSString stringWithFormat:@"Quit %@", appName]
                  action:@selector(stdMenuAction:)
           keyEquivalent:@"q"];

  for (NSMenuItem *item in menu.itemArray)
    item.target = self;

  NSRect appRect = [self.menuItemRects[0][@"rect"] rectValue];
  [menu popUpMenuPositioningItem:nil
                      atLocation:NSMakePoint(appRect.origin.x, 0)
                          inView:self];
}

- (void)showStandardMenu:(NSString *)menuName at:(NSPoint)loc {
  NSMenu *menu = [[NSMenu alloc] initWithTitle:menuName];
  menu.font = self.menuFont;

  if ([menuName isEqualToString:@"File"]) {
    [menu addItemWithTitle:@"New Window"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"n"];
    [menu addItemWithTitle:@"New Tab"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"t"];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Open..."
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"o"];
    [menu addItemWithTitle:@"Open Recent" action:nil keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Close Window"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"w"];
    [menu addItemWithTitle:@"Save..."
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"s"];
    [menu addItemWithTitle:@"Save As..."
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"S"];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Print..."
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"p"];
  } else if ([menuName isEqualToString:@"Edit"]) {
    [menu addItemWithTitle:@"Undo"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"z"];
    [menu addItemWithTitle:@"Redo"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"Z"];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Cut"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"x"];
    [menu addItemWithTitle:@"Copy"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"c"];
    [menu addItemWithTitle:@"Paste"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"v"];
    [menu addItemWithTitle:@"Select All"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"a"];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Find..."
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"f"];
  } else if ([menuName isEqualToString:@"View"]) {
    [menu addItemWithTitle:@"as Icons"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"1"];
    [menu addItemWithTitle:@"as List"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"2"];
    [menu addItemWithTitle:@"as Columns"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"3"];
    [menu addItemWithTitle:@"as Gallery"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"4"];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Show Toolbar"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@""];
    [menu addItemWithTitle:@"Show Path Bar"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@""];
    [menu addItemWithTitle:@"Show Status Bar"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Enter Full Screen"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"f"];
  } else if ([menuName isEqualToString:@"Go"]) {
    [menu addItemWithTitle:@"Back"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"["];
    [menu addItemWithTitle:@"Forward"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"]"];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Computer"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@""];
    [menu addItemWithTitle:@"Home"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"H"];
    [menu addItemWithTitle:@"Desktop"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"D"];
    [menu addItemWithTitle:@"Downloads"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"L"];
    [menu addItemWithTitle:@"Applications"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"A"];
    [menu addItemWithTitle:@"Utilities"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"U"];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Go to Folder..."
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"G"];
    [menu addItemWithTitle:@"Connect to Server..."
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"K"];
  } else if ([menuName isEqualToString:@"Window"]) {
    [menu addItemWithTitle:@"Minimize"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"m"];
    [menu addItemWithTitle:@"Zoom"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Bring All to Front"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@""];
  } else if ([menuName isEqualToString:@"Help"]) {
    [menu addItemWithTitle:@"Search" action:nil keyEquivalent:@""];
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"VirtualOS Help"
                    action:@selector(stdMenuAction:)
             keyEquivalent:@"?"];
  }

  for (NSMenuItem *item in menu.itemArray)
    item.target = self;

  // Position below the menu item
  for (NSDictionary *info in self.menuItemRects) {
    if ([info[@"name"] isEqualToString:menuName]) {
      NSRect r = [info[@"rect"] rectValue];
      [menu popUpMenuPositioningItem:nil
                          atLocation:NSMakePoint(r.origin.x, 0)
                              inView:self];
      break;
    }
  }
}

- (void)showWiFiMenu:(NSPoint)loc {
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Wi-Fi"];
  menu.font = self.menuFont;

  NSMenuItem *header = [[NSMenuItem alloc]
      initWithTitle:self.wifiEnabled ? @"Wi-Fi: On" : @"Wi-Fi: Off"
             action:nil
      keyEquivalent:@""];
  header.enabled = NO;
  [menu addItem:header];
  [menu addItem:[NSMenuItem separatorItem]];

  NSMenuItem *toggle = [[NSMenuItem alloc]
      initWithTitle:self.wifiEnabled ? @"Turn Wi-Fi Off" : @"Turn Wi-Fi On"
             action:@selector(toggleWiFi:)
      keyEquivalent:@""];
  toggle.target = self;
  [menu addItem:toggle];

  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Network Preferences..."
                  action:@selector(wifiMenuAction:)
           keyEquivalent:@""];
  ((NSMenuItem *)menu.itemArray.lastObject).target = self;

  [menu popUpMenuPositioningItem:nil
                      atLocation:NSMakePoint(self.wifiRect.origin.x, 0)
                          inView:self];
}

#pragma mark - Menu Actions

- (void)appleMenuAction:(NSMenuItem *)sender {
  NSString *title = sender.title;
  if ([title isEqualToString:@"About This Mac"]) {
    [self.delegate menuBarItemClicked:@"About This Mac"];
  } else if ([title containsString:@"System Preferences"]) {
    [self.delegate menuBarItemClicked:@"Settings"];
  } else if ([title containsString:@"Force Quit"]) {
    [self.delegate menuBarItemClicked:@"Force Quit"];
  } else if ([title isEqualToString:@"Lock Screen"]) {
    [self.delegate menuBarItemClicked:@"Lock Screen"];
  } else if ([title containsString:@"Log Out"]) {
    [self.delegate menuBarItemClicked:@"Log Out"];
  }
}

- (void)stdMenuAction:(NSMenuItem *)sender {
  [self.delegate menuBarItemClicked:sender.title];
}

- (void)toggleWiFi:(NSMenuItem *)sender {
  self.wifiEnabled = !self.wifiEnabled;
  [self setNeedsDisplay:YES];
}

- (void)wifiMenuAction:(NSMenuItem *)sender {
  [self.delegate menuBarItemClicked:@"WiFi"];
}

@end
