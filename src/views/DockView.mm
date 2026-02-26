#import "DockView.h"
#import <QuartzCore/QuartzCore.h>

@interface DockView ()
@property(nonatomic, strong) NSMutableSet *runningApps;
@property(nonatomic, strong) NSMutableDictionary *bounceAnimations;
@property(nonatomic, strong) NSMutableDictionary *itemScales;
@property(nonatomic, assign) CFTimeInterval lastUpdateTime;
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
    self.lastUpdateTime = CACurrentMediaTime();

    // macOS Tahoe dock apps
    self.dockItems = @[
      @{
        @"name" : @"Finder",
        @"icon" : @"📁",
        @"color" : [NSColor colorWithRed:0.2 green:0.5 blue:0.95 alpha:1.0]
      },
      @{
        @"name" : @"Safari",
        @"icon" : @"🧭",
        @"color" : [NSColor colorWithRed:0.2 green:0.6 blue:0.95 alpha:1.0]
      },
      @{
        @"name" : @"Messages",
        @"icon" : @"💬",
        @"color" : [NSColor colorWithRed:0.2 green:0.78 blue:0.35 alpha:1.0]
      },
      @{
        @"name" : @"Mail",
        @"icon" : @"✉️",
        @"color" : [NSColor colorWithRed:0.2 green:0.55 blue:0.95 alpha:1.0]
      },
      @{
        @"name" : @"Music",
        @"icon" : @"🎵",
        @"color" : [NSColor colorWithRed:0.95 green:0.25 blue:0.35 alpha:1.0]
      },
      @{
        @"name" : @"Photos",
        @"icon" : @"🌈",
        @"color" : [NSColor colorWithRed:0.95 green:0.4 blue:0.3 alpha:1.0]
      },
      @{
        @"name" : @"Notes",
        @"icon" : @"📝",
        @"color" : [NSColor colorWithRed:0.95 green:0.82 blue:0.25 alpha:1.0]
      },
      @{
        @"name" : @"Calendar",
        @"icon" : @"📅",
        @"color" : [NSColor colorWithRed:0.95 green:0.3 blue:0.3 alpha:1.0]
      },
      @{
        @"name" : @"Terminal",
        @"icon" : @"⬛",
        @"color" : [NSColor colorWithRed:0.15 green:0.15 blue:0.15 alpha:1.0]
      },
      @{
        @"name" : @"Activity Monitor",
        @"icon" : @"📊",
        @"color" : [NSColor colorWithRed:0.2 green:0.8 blue:0.4 alpha:1.0]
      },
      @{
        @"name" : @"Settings",
        @"icon" : @"⚙️",
        @"color" : [NSColor colorWithRed:0.55 green:0.55 blue:0.58 alpha:1.0]
      },
      @{
        @"name" : @"Antivirus",
        @"icon" : @"🛡️",
        @"color" : [NSColor colorWithRed:0.1 green:0.6 blue:0.3 alpha:1.0]
      },
      @{
        @"name" : @"Downloads",
        @"icon" : @"⬇️",
        @"color" : [NSColor colorWithRed:0.4 green:0.4 blue:0.9 alpha:1.0]
      },
    ];

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

- (void)drawRect:(NSRect)dirtyRect {
  CFTimeInterval currentTime = CACurrentMediaTime();
  CFTimeInterval deltaTime = currentTime - self.lastUpdateTime;
  self.lastUpdateTime = currentTime;
  [self updateAnimations:deltaTime];

  CGFloat dockW = self.bounds.size.width;
  CGFloat dockH = self.bounds.size.height;

  // ─── LIQUID GLASS DOCK ───
  // macOS Tahoe: translucent pill-shaped dock
  CGFloat pillPadding = 6;
  NSRect dockRect =
      NSMakeRect(pillPadding, 6, dockW - pillPadding * 2, dockH - 12);
  CGFloat cornerRadius = (dockH - 12) / 2.0;
  if (cornerRadius > 22)
    cornerRadius = 22;
  NSBezierPath *dockPath =
      [NSBezierPath bezierPathWithRoundedRect:dockRect
                                      xRadius:cornerRadius
                                      yRadius:cornerRadius];

  // Layer 1: Semi-transparent glass fill
  [[NSColor colorWithWhite:1.0 alpha:0.22] setFill];
  [dockPath fill];

  // Layer 2: Subtle inner gradient for depth
  NSGradient *innerGrad = [[NSGradient alloc]
      initWithColorsAndLocations:[NSColor colorWithWhite:1.0 alpha:0.18], 0.0,
                                 [NSColor colorWithWhite:1.0 alpha:0.06], 0.5,
                                 [NSColor colorWithWhite:1.0 alpha:0.12], 1.0,
                                 nil];
  [innerGrad drawInBezierPath:dockPath angle:90];

  // Layer 3: Top highlight (glass reflection)
  NSRect highlightRect =
      NSMakeRect(dockRect.origin.x + cornerRadius,
                 dockRect.origin.y + dockRect.size.height - 6,
                 dockRect.size.width - cornerRadius * 2, 4);
  NSGradient *hlGrad = [[NSGradient alloc]
      initWithStartingColor:[NSColor colorWithWhite:1.0 alpha:0.30]
                endingColor:[NSColor colorWithWhite:1.0 alpha:0.0]];
  [hlGrad drawInRect:highlightRect angle:90];

  // Layer 4: Border
  [[NSColor colorWithWhite:1.0 alpha:0.30] setStroke];
  [dockPath setLineWidth:0.5];
  [dockPath stroke];

  // ─── DOCK ITEMS ───
  CGFloat baseItemSize = 46;
  CGFloat spacing = 4;
  CGFloat totalWidth =
      self.dockItems.count * (baseItemSize + spacing) - spacing;
  CGFloat startX = (dockW - totalWidth) / 2;

  for (NSInteger i = 0; i < (NSInteger)self.dockItems.count; i++) {
    NSDictionary *item = self.dockItems[i];
    CGFloat size = baseItemSize;
    CGFloat yOffset = 0;

    // Bounce animation
    NSNumber *bounceKey = @(i);
    if (self.bounceAnimations[bounceKey]) {
      CGFloat bounceProgress = [self.bounceAnimations[bounceKey] floatValue];
      yOffset = sin(bounceProgress * M_PI) * 20;
    }

    // Magnification effect (macOS Tahoe style — subtle)
    CGFloat targetScale = 1.0;
    if (i == self.hoveredItem) {
      targetScale = 1.3;
    } else if (self.hoveredItem >= 0) {
      CGFloat distance = fabs((CGFloat)(i - self.hoveredItem));
      if (distance == 1)
        targetScale = 1.15;
      else if (distance == 2)
        targetScale = 1.05;
    }

    CGFloat currentScale = self.itemScales[bounceKey]
                               ? [self.itemScales[bounceKey] floatValue]
                               : 1.0;
    CGFloat newScale = currentScale + (targetScale - currentScale) * 0.25;
    self.itemScales[bounceKey] = @(newScale);

    size *= newScale;
    CGFloat x =
        startX + i * (baseItemSize + spacing) + (baseItemSize - size) / 2;
    CGFloat y = 14 + yOffset + (baseItemSize - size) / 2;

    // ─── ICON: Liquid Glass app icon ───
    NSRect iconRect = NSMakeRect(x, y, size, size);
    CGFloat iconRadius = size * 0.22;
    NSBezierPath *iconBg = [NSBezierPath bezierPathWithRoundedRect:iconRect
                                                           xRadius:iconRadius
                                                           yRadius:iconRadius];

    // Glass base with app color
    NSColor *appColor = item[@"color"];
    NSGradient *appGrad = [[NSGradient alloc]
        initWithStartingColor:[appColor colorWithAlphaComponent:0.85]
                  endingColor:[appColor colorWithAlphaComponent:0.65]];
    [appGrad drawInBezierPath:iconBg angle:90];

    // Glass reflection on top half
    NSRect reflectRect =
        NSMakeRect(x + 2, y + size * 0.5, size - 4, size * 0.45);
    NSBezierPath *reflectPath =
        [NSBezierPath bezierPathWithRoundedRect:reflectRect
                                        xRadius:iconRadius - 2
                                        yRadius:iconRadius - 2];
    NSGradient *reflectGrad = [[NSGradient alloc]
        initWithStartingColor:[NSColor colorWithWhite:1.0 alpha:0.35]
                  endingColor:[NSColor colorWithWhite:1.0 alpha:0.0]];
    [reflectGrad drawInBezierPath:reflectPath angle:90];

    // Subtle border
    [[NSColor colorWithWhite:1.0 alpha:0.25] setStroke];
    [iconBg setLineWidth:0.5];
    [iconBg stroke];

    // Icon emoji
    CGFloat emojiSize = size * 0.55;
    NSDictionary *emojiAttrs =
        @{NSFontAttributeName : [NSFont systemFontOfSize:emojiSize]};
    NSString *emoji = item[@"icon"];
    NSSize emSize = [emoji sizeWithAttributes:emojiAttrs];
    [emoji drawAtPoint:NSMakePoint(x + (size - emSize.width) / 2,
                                   y + (size - emSize.height) / 2)
        withAttributes:emojiAttrs];

    // Running indicator dot (macOS style)
    if ([self.runningApps containsObject:item[@"name"]]) {
      CGFloat dotSize = 4;
      NSRect dotRect =
          NSMakeRect(x + (size - dotSize) / 2, 6, dotSize, dotSize);
      [[NSColor colorWithWhite:0.95 alpha:0.85] setFill];
      [[NSBezierPath bezierPathWithOvalInRect:dotRect] fill];
    }
  }

  // Tooltip for hovered item
  if (self.hoveredItem >= 0 &&
      self.hoveredItem < (NSInteger)self.dockItems.count) {
    NSDictionary *item = self.dockItems[self.hoveredItem];
    NSString *name = item[@"name"];

    NSDictionary *tooltipAttrs = @{
      NSFontAttributeName : [NSFont systemFontOfSize:12
                                              weight:NSFontWeightMedium],
      NSForegroundColorAttributeName : [NSColor colorWithWhite:0.95 alpha:1.0]
    };
    NSSize nameSize = [name sizeWithAttributes:tooltipAttrs];

    CGFloat tooltipX = startX + self.hoveredItem * (baseItemSize + spacing) +
                       baseItemSize / 2 - nameSize.width / 2 - 8;
    CGFloat tooltipY = dockH - 4;
    NSRect tooltipRect = NSMakeRect(tooltipX, tooltipY, nameSize.width + 16,
                                    nameSize.height + 8);

    // Tooltip background (Liquid Glass pill)
    NSBezierPath *tooltipPath =
        [NSBezierPath bezierPathWithRoundedRect:tooltipRect
                                        xRadius:8
                                        yRadius:8];
    [[NSColor colorWithWhite:0.15 alpha:0.85] setFill];
    [tooltipPath fill];
    [[NSColor colorWithWhite:1.0 alpha:0.15] setStroke];
    [tooltipPath setLineWidth:0.5];
    [tooltipPath stroke];

    [name drawAtPoint:NSMakePoint(tooltipX + 8, tooltipY + 4)
        withAttributes:tooltipAttrs];
  }

  // Continue animating if needed
  BOOL needsAnimation = NO;
  for (NSNumber *key in self.bounceAnimations.allKeys) {
    if ([self.bounceAnimations[key] floatValue] < 1.0)
      needsAnimation = YES;
  }
  for (NSNumber *key in self.itemScales.allKeys) {
    CGFloat scale = [self.itemScales[key] floatValue];
    if (fabs(scale - 1.0) > 0.01)
      needsAnimation = YES;
  }
  if (self.hoveredItem >= 0)
    needsAnimation = YES;

  if (needsAnimation) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self setNeedsDisplay:YES];
    });
  }
}

- (void)updateAnimations:(CFTimeInterval)deltaTime {
  NSMutableArray *keysToRemove = [NSMutableArray array];
  for (NSNumber *key in self.bounceAnimations.allKeys) {
    CGFloat progress = [self.bounceAnimations[key] floatValue];
    progress += deltaTime * 2.0;
    if (progress >= 1.0) {
      [keysToRemove addObject:key];
    } else {
      self.bounceAnimations[key] = @(progress);
    }
  }
  for (NSNumber *key in keysToRemove) {
    [self.bounceAnimations removeObjectForKey:key];
  }
}

- (void)mouseMoved:(NSEvent *)event {
  NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
  CGFloat baseItemSize = 46;
  CGFloat spacing = 4;
  CGFloat totalWidth =
      self.dockItems.count * (baseItemSize + spacing) - spacing;
  CGFloat startX = (self.bounds.size.width - totalWidth) / 2;

  NSInteger oldHovered = self.hoveredItem;
  self.hoveredItem = -1;

  for (NSInteger i = 0; i < (NSInteger)self.dockItems.count; i++) {
    CGFloat x = startX + i * (baseItemSize + spacing);
    NSRect itemRect = NSMakeRect(x, 10, baseItemSize, baseItemSize);
    if (NSPointInRect(location, itemRect)) {
      self.hoveredItem = i;
      break;
    }
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
  NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
  CGFloat baseItemSize = 46;
  CGFloat spacing = 4;
  CGFloat totalWidth =
      self.dockItems.count * (baseItemSize + spacing) - spacing;
  CGFloat startX = (self.bounds.size.width - totalWidth) / 2;

  for (NSInteger i = 0; i < (NSInteger)self.dockItems.count; i++) {
    CGFloat x = startX + i * (baseItemSize + spacing);
    NSRect itemRect = NSMakeRect(x, 10, baseItemSize, baseItemSize);
    if (NSPointInRect(location, itemRect)) {
      self.selectedItem = i;
      NSDictionary *item = self.dockItems[i];
      [self.runningApps addObject:item[@"name"]];
      [self bounceItemAtIndex:i];

      if (self.delegate) {
        [self.delegate dockItemClicked:item[@"name"]];
      }
      [self setNeedsDisplay:YES];
      break;
    }
  }
}

- (void)rightMouseDown:(NSEvent *)event {
  NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
  CGFloat baseItemSize = 46;
  CGFloat spacing = 4;
  CGFloat totalWidth =
      self.dockItems.count * (baseItemSize + spacing) - spacing;
  CGFloat startX = (self.bounds.size.width - totalWidth) / 2;

  for (NSInteger i = 0; i < (NSInteger)self.dockItems.count; i++) {
    CGFloat x = startX + i * (baseItemSize + spacing);
    NSRect itemRect = NSMakeRect(x, 10, baseItemSize, baseItemSize);
    if (NSPointInRect(location, itemRect)) {
      NSDictionary *item = self.dockItems[i];
      NSMenu *menu = [[NSMenu alloc] initWithTitle:@"DockMenu"];

      NSMenuItem *quitItem =
          [[NSMenuItem alloc] initWithTitle:@"Quit"
                                     action:@selector(quitAppFromMenu:)
                              keyEquivalent:@""];
      quitItem.representedObject = item[@"name"];
      quitItem.target = self;
      [menu addItem:quitItem];

      NSMenuItem *forceQuitItem =
          [[NSMenuItem alloc] initWithTitle:@"Force Quit"
                                     action:@selector(quitAppFromMenu:)
                              keyEquivalent:@""];
      forceQuitItem.representedObject = item[@"name"];
      forceQuitItem.target = self;
      [menu addItem:forceQuitItem];

      [NSMenu popUpContextMenu:menu withEvent:event forView:self];
      break;
    }
  }
}

- (void)quitAppFromMenu:(NSMenuItem *)sender {
  NSString *appName = sender.representedObject;
  [self.runningApps removeObject:appName];
  [self setNeedsDisplay:YES];
}

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

@end
