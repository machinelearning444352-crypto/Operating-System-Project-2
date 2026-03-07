#import "DockView.h"
#import <QuartzCore/QuartzCore.h>

// ============================================================================
// DockView.mm — Pixel-Perfect macOS Sequoia Dock
// Real app icons from /Applications, parabolic magnification,
// glass pill shape, separator, running indicators, tooltips
// ============================================================================

static const CGFloat kDockBaseItemSize = 48.0;
static const CGFloat kDockItemSpacing = 2.0;
static const CGFloat kDockMaxScale = 1.6;
static const CGFloat kDockMagRange = 3.0; // items affected on each side
static const CGFloat kDockIconRadius = 10.0;
static const CGFloat kDockPillCornerRadius = 16.0;
static const CGFloat kDockPillPadding = 6.0;
static const CGFloat kDockRunningDotSize = 4.0;
static const CGFloat kDockSeparatorWidth = 1.0;

@interface DockView ()
@property(nonatomic, strong) NSMutableSet *runningApps;
@property(nonatomic, strong) NSMutableDictionary *bounceAnimations;
@property(nonatomic, strong)
    NSMutableDictionary<NSNumber *, NSNumber *> *itemScales;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, NSImage *> *iconCache;
@property(nonatomic, assign) CFTimeInterval lastUpdateTime;
@property(nonatomic, strong) NSVisualEffectView *vibrancyView;
@property(nonatomic, assign)
    NSInteger separatorIndex; // separator between apps and utils
@end

@implementation DockView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.wantsLayer = YES;
    self.hoveredItem = -1;
    self.selectedItem = -1;
    self.runningApps = [NSMutableSet setWithObjects:@"Finder", nil];
    self.bounceAnimations = [NSMutableDictionary dictionary];
    self.itemScales = [NSMutableDictionary dictionary];
    self.iconCache = [NSMutableDictionary dictionary];
    self.lastUpdateTime = CACurrentMediaTime();
    self.separatorIndex = -1;

    // ── macOS Sequoia dock items ──
    // Format: name, app path (for real icon), isSeparator flag
    self.dockItems = @[
      @{
        @"name" : @"Finder",
        @"path" : @"/System/Library/CoreServices/Finder.app"
      },
      @{
        @"name" : @"Google Chrome",
        @"path" : @"/Applications/Google Chrome.app",
        @"altPath" : @"/Applications/Chromium.app"
      },
      @{@"name" : @"Messages", @"path" : @"/System/Applications/Messages.app"},
      @{@"name" : @"Mail", @"path" : @"/System/Applications/Mail.app"},
      @{@"name" : @"Music", @"path" : @"/System/Applications/Music.app"},
      @{@"name" : @"Photos", @"path" : @"/System/Applications/Photos.app"},
      @{@"name" : @"Notes", @"path" : @"/System/Applications/Notes.app"},
      @{@"name" : @"Calendar", @"path" : @"/System/Applications/Calendar.app"},
      @{
        @"name" : @"Terminal",
        @"path" : @"/System/Applications/Utilities/Terminal.app"
      },
      @{
        @"name" : @"Activity Monitor",
        @"path" : @"/System/Applications/Utilities/Activity Monitor.app"
      },
      @{
        @"name" : @"Settings",
        @"path" : @"/System/Applications/System Preferences.app",
        @"altPath" : @"/System/Applications/System Settings.app"
      },
      @{@"name" : @"separator", @"path" : @""},
      @{
        @"name" : @"Downloads",
        @"path" : @"~/Downloads",
        @"sfSymbol" : @"arrow.down.circle.fill"
      },
      @{@"name" : @"Trash", @"path" : @"~/.Trash", @"sfSymbol" : @"trash.fill"},
    ];
    self.separatorIndex = 11;

    // ── Preload icons ──
    [self preloadIcons];

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

#pragma mark - Icon Loading (Real App Icons)

- (void)preloadIcons {
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  for (NSDictionary *item in self.dockItems) {
    NSString *name = item[@"name"];
    if ([name isEqualToString:@"separator"])
      continue;

    NSImage *icon = nil;

    // Try SF Symbol first
    NSString *sfSymbol = item[@"sfSymbol"];
    if (sfSymbol) {
      icon = [self createSFSymbolIcon:sfSymbol];
    }

    // Try loading from app bundle path
    if (!icon) {
      NSString *path = item[@"path"];
      if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        icon = [ws iconForFile:path];
      }
      // Try alternate path
      if (!icon) {
        NSString *altPath = item[@"altPath"];
        if (altPath &&
            [[NSFileManager defaultManager] fileExistsAtPath:altPath]) {
          icon = [ws iconForFile:altPath];
        }
      }
    }

    // Try by app name in /Applications
    if (!icon) {
      NSString *appPath =
          [NSString stringWithFormat:@"/Applications/%@.app", name];
      if ([[NSFileManager defaultManager] fileExistsAtPath:appPath]) {
        icon = [ws iconForFile:appPath];
      }
    }

    // Try System Applications
    if (!icon) {
      NSString *sysPath =
          [NSString stringWithFormat:@"/System/Applications/%@.app", name];
      if ([[NSFileManager defaultManager] fileExistsAtPath:sysPath]) {
        icon = [ws iconForFile:sysPath];
      }
    }

    // Fallback: generic app icon
    if (!icon) {
      icon = [ws iconForFileType:@"app"];
    }

    // Set icon size for crisp rendering
    icon.size = NSMakeSize(kDockBaseItemSize * 2, kDockBaseItemSize * 2);
    self.iconCache[name] = icon;
  }
}

- (NSImage *)createSFSymbolIcon:(NSString *)symbolName {
  NSImage *symbol = [NSImage imageWithSystemSymbolName:symbolName
                              accessibilityDescription:symbolName];
  if (!symbol)
    return nil;

  CGFloat imgSize = kDockBaseItemSize * 2;
  NSImage *rendered =
      [[NSImage alloc] initWithSize:NSMakeSize(imgSize, imgSize)];
  [rendered lockFocus];

  // Background gradient
  NSBezierPath *bg =
      [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(0, 0, imgSize, imgSize)
                                      xRadius:imgSize * 0.22
                                      yRadius:imgSize * 0.22];

  NSColor *bgColor;
  if ([symbolName containsString:@"arrow.down"]) {
    bgColor = [NSColor colorWithRed:0.35 green:0.55 blue:0.90 alpha:1.0];
  } else if ([symbolName containsString:@"trash"]) {
    bgColor = [NSColor colorWithRed:0.55 green:0.55 blue:0.58 alpha:1.0];
  } else {
    bgColor = [NSColor colorWithRed:0.45 green:0.45 blue:0.50 alpha:1.0];
  }

  NSGradient *grad = [[NSGradient alloc]
      initWithStartingColor:[bgColor colorWithAlphaComponent:0.95]
                endingColor:[bgColor colorWithAlphaComponent:0.75]];
  [grad drawInBezierPath:bg angle:90];

  // Draw SF Symbol centered
  NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration
      configurationWithPointSize:imgSize * 0.4
                          weight:NSFontWeightMedium
                           scale:NSImageSymbolScaleLarge];
  NSImage *configured = [symbol imageWithSymbolConfiguration:config];
  NSSize symSz = configured.size;
  CGFloat symX = (imgSize - symSz.width) / 2;
  CGFloat symY = (imgSize - symSz.height) / 2;

  [configured drawInRect:NSMakeRect(symX, symY, symSz.width, symSz.height)
                fromRect:NSZeroRect
               operation:NSCompositingOperationSourceOver
                fraction:0.95];

  [rendered unlockFocus];
  return rendered;
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
  CFTimeInterval currentTime = CACurrentMediaTime();
  CFTimeInterval deltaTime = currentTime - self.lastUpdateTime;
  self.lastUpdateTime = currentTime;
  [self updateAnimations:deltaTime];

  CGFloat dockW = self.bounds.size.width;
  CGFloat dockH = self.bounds.size.height;

  // ── DOCK PILL (Glass Background) ──
  NSRect pillRect =
      NSMakeRect(kDockPillPadding, 6, dockW - kDockPillPadding * 2, dockH - 12);
  NSBezierPath *pillPath =
      [NSBezierPath bezierPathWithRoundedRect:pillRect
                                      xRadius:kDockPillCornerRadius
                                      yRadius:kDockPillCornerRadius];

  // Layer 1: Glass fill
  [[NSColor colorWithWhite:0.92 alpha:0.30] setFill];
  [pillPath fill];

  // Layer 2: Inner gradient for depth
  NSGradient *innerGrad = [[NSGradient alloc]
      initWithColorsAndLocations:[NSColor colorWithWhite:1.0 alpha:0.20], 0.0,
                                 [NSColor colorWithWhite:1.0 alpha:0.06], 0.5,
                                 [NSColor colorWithWhite:1.0 alpha:0.14], 1.0,
                                 nil];
  [innerGrad drawInBezierPath:pillPath angle:90];

  // Layer 3: Top highlight
  NSRect hlRect =
      NSMakeRect(pillRect.origin.x + kDockPillCornerRadius,
                 pillRect.origin.y + pillRect.size.height - 4,
                 pillRect.size.width - kDockPillCornerRadius * 2, 3);
  NSGradient *hlGrad = [[NSGradient alloc]
      initWithStartingColor:[NSColor colorWithWhite:1.0 alpha:0.35]
                endingColor:[NSColor colorWithWhite:1.0 alpha:0.0]];
  [hlGrad drawInRect:hlRect angle:90];

  // Layer 4: Border
  [[NSColor colorWithWhite:1.0 alpha:0.35] setStroke];
  [pillPath setLineWidth:0.5];
  [pillPath stroke];

  // ── Calculate layout ──
  NSInteger itemCount = 0;
  for (NSDictionary *item in self.dockItems) {
    if (![item[@"name"] isEqualToString:@"separator"])
      itemCount++;
  }
  CGFloat totalWidth = itemCount * (kDockBaseItemSize + kDockItemSpacing) +
                       kDockSeparatorWidth + 10 - kDockItemSpacing;
  CGFloat startX = (dockW - totalWidth) / 2;
  CGFloat currentX = startX;

  // ── Draw each item ──
  NSInteger drawIndex = 0;
  for (NSInteger i = 0; i < (NSInteger)self.dockItems.count; i++) {
    NSDictionary *item = self.dockItems[i];
    NSString *name = item[@"name"];

    // ── Separator ──
    if ([name isEqualToString:@"separator"]) {
      CGFloat sepX = currentX + 4;
      CGFloat sepY = (dockH - 12) / 2 + 4;
      [[NSColor colorWithWhite:0.0 alpha:0.15] setFill];
      NSRectFill(
          NSMakeRect(sepX, sepY, kDockSeparatorWidth, dockH - sepY * 2 + 16));
      currentX += kDockSeparatorWidth + 10;
      continue;
    }

    // ── Parabolic magnification ──
    CGFloat targetScale = 1.0;
    if (self.hoveredItem >= 0) {
      CGFloat distance = fabs((CGFloat)(drawIndex - self.hoveredItem));
      if (distance < kDockMagRange) {
        CGFloat factor = 1.0 - (distance / kDockMagRange);
        targetScale =
            1.0 + (kDockMaxScale - 1.0) * factor * factor; // parabolic
      }
    }

    NSNumber *scaleKey = @(drawIndex);
    CGFloat currentScale = self.itemScales[scaleKey]
                               ? [self.itemScales[scaleKey] floatValue]
                               : 1.0;
    // Smooth interpolation
    CGFloat newScale = currentScale + (targetScale - currentScale) * 0.3;
    self.itemScales[scaleKey] = @(newScale);

    CGFloat size = kDockBaseItemSize * newScale;

    // Bounce offset
    CGFloat yOffset = 0;
    if (self.bounceAnimations[@(drawIndex)]) {
      CGFloat bp = [self.bounceAnimations[@(drawIndex)] floatValue];
      yOffset = sin(bp * M_PI) * 20;
    }

    CGFloat x = currentX + (kDockBaseItemSize - size) / 2;
    CGFloat y = 14 + yOffset + (kDockBaseItemSize - size) / 2;
    NSRect iconRect = NSMakeRect(x, y, size, size);

    // ── Draw the app icon ──
    NSImage *icon = self.iconCache[name];
    if (icon) {
      // Rounded corner clipping (macOS app icon shape)
      CGFloat radius = size * 0.22;
      NSBezierPath *clipPath = [NSBezierPath bezierPathWithRoundedRect:iconRect
                                                               xRadius:radius
                                                               yRadius:radius];

      [NSGraphicsContext saveGraphicsState];
      [clipPath setClip];
      [icon drawInRect:iconRect
              fromRect:NSZeroRect
             operation:NSCompositingOperationSourceOver
              fraction:1.0];
      [NSGraphicsContext restoreGraphicsState];

      // Subtle border around icon
      [[NSColor colorWithWhite:0.0 alpha:0.10] setStroke];
      [clipPath setLineWidth:0.5];
      [clipPath stroke];
    }

    // ── Running indicator dot ──
    if ([self.runningApps containsObject:name]) {
      CGFloat dotX = x + (size - kDockRunningDotSize) / 2;
      CGFloat dotY = 5;
      NSRect dotRect =
          NSMakeRect(dotX, dotY, kDockRunningDotSize, kDockRunningDotSize);
      [[NSColor colorWithWhite:0.90 alpha:0.90] setFill];
      [[NSBezierPath bezierPathWithOvalInRect:dotRect] fill];
    }

    currentX += kDockBaseItemSize + kDockItemSpacing;
    drawIndex++;
  }

  // ── Tooltip for hovered item ──
  if (self.hoveredItem >= 0) {
    // Find the actual name by skipping separators
    NSInteger realIndex = 0;
    NSString *hoveredName = nil;
    for (NSDictionary *item in self.dockItems) {
      if ([item[@"name"] isEqualToString:@"separator"])
        continue;
      if (realIndex == self.hoveredItem) {
        hoveredName = item[@"name"];
        break;
      }
      realIndex++;
    }

    if (hoveredName) {
      NSDictionary *tooltipAttrs = @{
        NSFontAttributeName : [NSFont systemFontOfSize:12
                                                weight:NSFontWeightMedium],
        NSForegroundColorAttributeName : [NSColor colorWithWhite:0.95 alpha:1.0]
      };
      NSSize nameSz = [hoveredName sizeWithAttributes:tooltipAttrs];

      CGFloat itemX = startX;
      NSInteger skip = 0;
      for (NSInteger i = 0; i < (NSInteger)self.dockItems.count; i++) {
        if ([self.dockItems[i][@"name"] isEqualToString:@"separator"]) {
          itemX += kDockSeparatorWidth + 10;
          continue;
        }
        if (skip == self.hoveredItem)
          break;
        itemX += kDockBaseItemSize + kDockItemSpacing;
        skip++;
      }

      CGFloat tooltipX = itemX + kDockBaseItemSize / 2 - nameSz.width / 2 - 8;
      CGFloat tooltipY = dockH - 2;
      NSRect tooltipRect =
          NSMakeRect(tooltipX, tooltipY, nameSz.width + 16, nameSz.height + 8);

      // Tooltip pill (dark, like real macOS)
      NSBezierPath *tooltipPath =
          [NSBezierPath bezierPathWithRoundedRect:tooltipRect
                                          xRadius:6
                                          yRadius:6];
      [[NSColor colorWithWhite:0.12 alpha:0.90] setFill];
      [tooltipPath fill];
      [[NSColor colorWithWhite:1.0 alpha:0.12] setStroke];
      [tooltipPath setLineWidth:0.5];
      [tooltipPath stroke];

      [hoveredName drawAtPoint:NSMakePoint(tooltipX + 8, tooltipY + 4)
                withAttributes:tooltipAttrs];
    }
  }

  // ── Continue animation loop ──
  BOOL needsAnimation = NO;
  for (NSNumber *key in self.bounceAnimations.allKeys) {
    if ([self.bounceAnimations[key] floatValue] < 1.0)
      needsAnimation = YES;
  }
  for (NSNumber *key in self.itemScales.allKeys) {
    CGFloat s = [self.itemScales[key] floatValue];
    if (fabs(s - 1.0) > 0.005)
      needsAnimation = YES;
  }
  if (self.hoveredItem >= 0)
    needsAnimation = YES;

  if (needsAnimation) {
    __weak DockView *weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
      [weakSelf setNeedsDisplay:YES];
    });
  }
}

#pragma mark - Animations

- (void)updateAnimations:(CFTimeInterval)dt {
  NSMutableArray *done = [NSMutableArray array];
  for (NSNumber *key in self.bounceAnimations.allKeys) {
    CGFloat p = [self.bounceAnimations[key] floatValue];
    p += dt * 2.5;
    if (p >= 1.0)
      [done addObject:key];
    else
      self.bounceAnimations[key] = @(p);
  }
  for (NSNumber *key in done)
    [self.bounceAnimations removeObjectForKey:key];
}

#pragma mark - Mouse Events

- (void)mouseMoved:(NSEvent *)event {
  NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];

  // Calculate item positions (same logic as draw)
  CGFloat dockW = self.bounds.size.width;
  NSInteger itemCount = 0;
  for (NSDictionary *item in self.dockItems) {
    if (![item[@"name"] isEqualToString:@"separator"])
      itemCount++;
  }
  CGFloat totalWidth = itemCount * (kDockBaseItemSize + kDockItemSpacing) +
                       kDockSeparatorWidth + 10 - kDockItemSpacing;
  CGFloat startX = (dockW - totalWidth) / 2;
  CGFloat currentX = startX;

  NSInteger oldHovered = self.hoveredItem;
  self.hoveredItem = -1;

  NSInteger drawIndex = 0;
  for (NSInteger i = 0; i < (NSInteger)self.dockItems.count; i++) {
    if ([self.dockItems[i][@"name"] isEqualToString:@"separator"]) {
      currentX += kDockSeparatorWidth + 10;
      continue;
    }
    NSRect itemRect =
        NSMakeRect(currentX, 10, kDockBaseItemSize, kDockBaseItemSize + 10);
    if (NSPointInRect(loc, itemRect)) {
      self.hoveredItem = drawIndex;
      break;
    }
    currentX += kDockBaseItemSize + kDockItemSpacing;
    drawIndex++;
  }

  if (oldHovered != self.hoveredItem) {
    [self setNeedsDisplay:YES];
  }
}

- (void)mouseExited:(NSEvent *)event {
  self.hoveredItem = -1;
  [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)event {
  NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];

  CGFloat dockW = self.bounds.size.width;
  NSInteger itemCount = 0;
  for (NSDictionary *item in self.dockItems) {
    if (![item[@"name"] isEqualToString:@"separator"])
      itemCount++;
  }
  CGFloat totalWidth = itemCount * (kDockBaseItemSize + kDockItemSpacing) +
                       kDockSeparatorWidth + 10 - kDockItemSpacing;
  CGFloat startX = (dockW - totalWidth) / 2;
  CGFloat currentX = startX;

  NSInteger drawIndex = 0;
  for (NSInteger i = 0; i < (NSInteger)self.dockItems.count; i++) {
    if ([self.dockItems[i][@"name"] isEqualToString:@"separator"]) {
      currentX += kDockSeparatorWidth + 10;
      continue;
    }
    NSRect itemRect =
        NSMakeRect(currentX, 10, kDockBaseItemSize, kDockBaseItemSize + 10);
    if (NSPointInRect(loc, itemRect)) {
      self.selectedItem = drawIndex;
      NSString *name = self.dockItems[i][@"name"];
      [self.runningApps addObject:name];
      [self bounceItemAtIndex:drawIndex];
      if (self.delegate) {
        [self.delegate dockItemClicked:name];
      }
      [self setNeedsDisplay:YES];
      break;
    }
    currentX += kDockBaseItemSize + kDockItemSpacing;
    drawIndex++;
  }
}

- (void)rightMouseDown:(NSEvent *)event {
  NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];

  CGFloat dockW = self.bounds.size.width;
  NSInteger itemCount = 0;
  for (NSDictionary *item in self.dockItems) {
    if (![item[@"name"] isEqualToString:@"separator"])
      itemCount++;
  }
  CGFloat totalWidth = itemCount * (kDockBaseItemSize + kDockItemSpacing) +
                       kDockSeparatorWidth + 10 - kDockItemSpacing;
  CGFloat startX = (dockW - totalWidth) / 2;
  CGFloat currentX = startX;

  for (NSInteger i = 0; i < (NSInteger)self.dockItems.count; i++) {
    if ([self.dockItems[i][@"name"] isEqualToString:@"separator"]) {
      currentX += kDockSeparatorWidth + 10;
      continue;
    }
    NSRect itemRect =
        NSMakeRect(currentX, 10, kDockBaseItemSize, kDockBaseItemSize + 10);
    if (NSPointInRect(loc, itemRect)) {
      NSDictionary *item = self.dockItems[i];
      NSString *name = item[@"name"];

      NSMenu *menu = [[NSMenu alloc] initWithTitle:@"DockMenu"];
      menu.font = [NSFont systemFontOfSize:13];

      BOOL isRunning = [self.runningApps containsObject:name];

      if (isRunning) {
        NSMenuItem *newWin =
            [[NSMenuItem alloc] initWithTitle:@"New Window"
                                       action:@selector(contextAction:)
                                keyEquivalent:@""];
        newWin.target = self;
        [menu addItem:newWin];
        [menu addItem:[NSMenuItem separatorItem]];
      }

      NSMenuItem *optItem = [[NSMenuItem alloc] initWithTitle:@"Options"
                                                       action:nil
                                                keyEquivalent:@""];
      NSMenu *optSubMenu = [[NSMenu alloc] initWithTitle:@"Options"];
      [optSubMenu addItemWithTitle:@"Keep in Dock"
                            action:@selector(contextAction:)
                     keyEquivalent:@""];
      [optSubMenu addItemWithTitle:@"Open at Login"
                            action:@selector(contextAction:)
                     keyEquivalent:@""];
      [optSubMenu addItem:[NSMenuItem separatorItem]];
      [optSubMenu addItemWithTitle:@"Show in Finder"
                            action:@selector(contextAction:)
                     keyEquivalent:@""];
      for (NSMenuItem *si in optSubMenu.itemArray)
        si.target = self;
      optItem.submenu = optSubMenu;
      [menu addItem:optItem];

      [menu addItem:[NSMenuItem separatorItem]];

      if (isRunning) {
        NSMenuItem *quitItem =
            [[NSMenuItem alloc] initWithTitle:@"Quit"
                                       action:@selector(quitAppFromMenu:)
                                keyEquivalent:@""];
        quitItem.representedObject = name;
        quitItem.target = self;
        [menu addItem:quitItem];
      } else {
        NSMenuItem *openItem =
            [[NSMenuItem alloc] initWithTitle:@"Open"
                                       action:@selector(contextAction:)
                                keyEquivalent:@""];
        openItem.target = self;
        [menu addItem:openItem];
      }

      [NSMenu popUpContextMenu:menu withEvent:event forView:self];
      break;
    }
    currentX += kDockBaseItemSize + kDockItemSpacing;
  }
}

#pragma mark - Context Menu Actions

- (void)contextAction:(NSMenuItem *)sender {
  // Placeholder for context menu actions
}

- (void)quitAppFromMenu:(NSMenuItem *)sender {
  NSString *appName = sender.representedObject;
  [self.runningApps removeObject:appName];
  [self setNeedsDisplay:YES];
}

#pragma mark - Public API

- (void)selectItemAtIndex:(NSInteger)index {
  self.selectedItem = index;
  [self setNeedsDisplay:YES];
}

- (void)deselectAllItems {
  self.selectedItem = -1;
  [self setNeedsDisplay:YES];
}

- (void)bounceItemAtIndex:(NSInteger)index {
  self.bounceAnimations[@(index)] = @(0.0);
  [self setNeedsDisplay:YES];
}

- (void)markAppRunning:(NSString *)appName {
  [self.runningApps addObject:appName];
  [self setNeedsDisplay:YES];
}

- (void)markAppStopped:(NSString *)appName {
  [self.runningApps removeObject:appName];
  [self setNeedsDisplay:YES];
}

@end
