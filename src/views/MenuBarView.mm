#import "MenuBarView.h"

@interface MenuBarView ()
@property(nonatomic, strong) NSMutableArray *menuItemRects;
@property(nonatomic, assign) NSInteger hoveredItem;
@property(nonatomic, assign) NSRect appleLogoRect;
@property(nonatomic, assign) NSRect wifiRect;
@property(nonatomic, assign) NSRect controlCenterRect;
@property(nonatomic, assign) NSRect batteryRect;
@end

@implementation MenuBarView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.timeFormatter = [[NSDateFormatter alloc] init];
    [self.timeFormatter setDateFormat:@"EEE MMM d  h:mm a"];
    self.currentTime = [self.timeFormatter stringFromDate:[NSDate date]];
    self.activeApp = @"Finder";
    self.hoveredItem = -1;
    self.menuItemRects = [NSMutableArray array];

    self.clockTimer =
        [NSTimer scheduledTimerWithTimeInterval:1.0
                                         target:self
                                       selector:@selector(updateClock)
                                       userInfo:nil
                                        repeats:YES];

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
  self.currentTime = [self.timeFormatter stringFromDate:[NSDate date]];
  [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
  [self.menuItemRects removeAllObjects];

  CGFloat barH = self.bounds.size.height;
  CGFloat barW = self.bounds.size.width;

  // ─── LIQUID GLASS MENU BAR ───
  // Layer 1: Ultra-thin transparent glass (macOS Tahoe style)
  // The menu bar is nearly invisible — just a subtle frosted overlay
  [[NSColor colorWithWhite:1.0 alpha:0.18] setFill];
  NSRectFillUsingOperation(self.bounds, NSCompositingOperationSourceOver);

  // Layer 2: Very subtle gaussian-like blur simulation at top
  NSGradient *glassEdge = [[NSGradient alloc]
      initWithStartingColor:[NSColor colorWithWhite:1.0 alpha:0.12]
                endingColor:[NSColor colorWithWhite:1.0 alpha:0.0]];
  [glassEdge drawInRect:NSMakeRect(0, 0, barW, barH) angle:90];

  // Layer 3: Ultra-thin bottom separator
  [[NSColor colorWithWhite:0.0 alpha:0.12] setFill];
  NSRectFill(NSMakeRect(0, 0, barW, 0.5));

  // ─── APPLE LOGO ───
  self.appleLogoRect = NSMakeRect(6, 0, 34, barH);

  if (self.hoveredItem == -2) {
    NSBezierPath *hlPath =
        [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(8, 3, 28, barH - 6)
                                        xRadius:5
                                        yRadius:5];
    [[NSColor colorWithWhite:0.0 alpha:0.10] setFill];
    [hlPath fill];
  }

  NSDictionary *appleAttrs = @{
    NSFontAttributeName : [NSFont systemFontOfSize:15
                                            weight:NSFontWeightMedium],
    NSForegroundColorAttributeName : [NSColor colorWithWhite:0.0 alpha:0.88]
  };
  NSSize appleSize = [@"" sizeWithAttributes:appleAttrs];
  [@"" drawAtPoint:NSMakePoint(14, (barH - appleSize.height) / 2)
      withAttributes:appleAttrs];

  // ─── LEFT SIDE: App name + Menus ───
  CGFloat xOffset = 44;

  // Active app name (bold, like real macOS Tahoe)
  NSDictionary *appNameAttrs = @{
    NSFontAttributeName : [NSFont systemFontOfSize:13 weight:NSFontWeightBold],
    NSForegroundColorAttributeName : [NSColor colorWithWhite:0.0 alpha:0.88]
  };
  NSSize appNameSize = [self.activeApp sizeWithAttributes:appNameAttrs];
  NSRect appNameRect = NSMakeRect(xOffset - 6, 0, appNameSize.width + 12, barH);
  [self.menuItemRects addObject:@{
    @"rect" : [NSValue valueWithRect:appNameRect],
    @"name" : self.activeApp
  }];

  if (self.hoveredItem == 0) {
    NSBezierPath *hlPath = [NSBezierPath
        bezierPathWithRoundedRect:NSMakeRect(xOffset - 6, 3,
                                             appNameSize.width + 12, barH - 6)
                          xRadius:5
                          yRadius:5];
    [[NSColor colorWithWhite:0.0 alpha:0.10] setFill];
    [hlPath fill];
  }
  [self.activeApp
         drawAtPoint:NSMakePoint(xOffset, (barH - appNameSize.height) / 2)
      withAttributes:appNameAttrs];
  xOffset += appNameSize.width + 18;

  // Menu items
  NSArray *menuItems =
      @[ @"File", @"Edit", @"View", @"Go", @"Window", @"Help" ];
  NSDictionary *menuAttrs = @{
    NSFontAttributeName : [NSFont systemFontOfSize:13
                                            weight:NSFontWeightRegular],
    NSForegroundColorAttributeName : [NSColor colorWithWhite:0.0 alpha:0.85]
  };

  for (NSInteger i = 0; i < (NSInteger)menuItems.count; i++) {
    NSString *item = menuItems[i];
    NSSize size = [item sizeWithAttributes:menuAttrs];
    NSRect itemRect = NSMakeRect(xOffset - 6, 0, size.width + 12, barH);
    [self.menuItemRects addObject:@{
      @"rect" : [NSValue valueWithRect:itemRect],
      @"name" : item
    }];

    if (self.hoveredItem == (i + 1)) {
      NSBezierPath *hlPath = [NSBezierPath
          bezierPathWithRoundedRect:NSMakeRect(xOffset - 6, 3, size.width + 12,
                                               barH - 6)
                            xRadius:5
                            yRadius:5];
      [[NSColor colorWithWhite:0.0 alpha:0.10] setFill];
      [hlPath fill];
    }

    [item drawAtPoint:NSMakePoint(xOffset, (barH - size.height) / 2)
        withAttributes:menuAttrs];
    xOffset += size.width + 16;
  }

  // ─── RIGHT SIDE: Status Icons ───
  NSDictionary *statusAttrs = @{
    NSFontAttributeName :
        [NSFont monospacedDigitSystemFontOfSize:12.5 weight:NSFontWeightMedium],
    NSForegroundColorAttributeName : [NSColor colorWithWhite:0.0 alpha:0.85]
  };
  NSDictionary *iconAttrs = @{
    NSFontAttributeName : [NSFont systemFontOfSize:13],
    NSForegroundColorAttributeName : [NSColor colorWithWhite:0.0 alpha:0.80]
  };

  CGFloat rightX = barW - 14;

  // Time & Date
  NSSize timeSize = [self.currentTime sizeWithAttributes:statusAttrs];
  rightX -= timeSize.width;
  [self.currentTime
         drawAtPoint:NSMakePoint(rightX, (barH - timeSize.height) / 2)
      withAttributes:statusAttrs];

  // Siri icon
  rightX -= 24;
  [@"●" drawAtPoint:NSMakePoint(rightX, (barH - 14) / 2)
      withAttributes:@{
        NSFontAttributeName : [NSFont systemFontOfSize:10],
        NSForegroundColorAttributeName : [NSColor colorWithRed:0.6
                                                         green:0.4
                                                          blue:0.9
                                                         alpha:0.8]
      }];

  // Control Center (dual toggle)
  rightX -= 24;
  self.controlCenterRect = NSMakeRect(rightX - 4, 0, 28, barH);
  [@"⊞" drawAtPoint:NSMakePoint(rightX, (barH - 14) / 2)
      withAttributes:iconAttrs];

  // WiFi icon
  rightX -= 24;
  self.wifiRect = NSMakeRect(rightX - 4, 0, 28, barH);
  // Draw a proper WiFi arc icon
  NSBezierPath *wifiPath = [NSBezierPath bezierPath];
  CGFloat wifiCenterX = rightX + 8;
  CGFloat wifiBaseY = (barH / 2) - 4;
  // Dot at bottom
  NSRect dotRect = NSMakeRect(wifiCenterX - 1.5, wifiBaseY, 3, 3);
  [[NSColor colorWithWhite:0.0 alpha:0.80] setFill];
  [[NSBezierPath bezierPathWithOvalInRect:dotRect] fill];
  // Three arcs
  [[NSColor colorWithWhite:0.0 alpha:0.80] setStroke];
  for (int arc = 0; arc < 3; arc++) {
    CGFloat radius = 4 + arc * 3.5;
    wifiPath = [NSBezierPath bezierPath];
    [wifiPath appendBezierPathWithArcWithCenter:NSMakePoint(wifiCenterX,
                                                            wifiBaseY + 1.5)
                                         radius:radius
                                     startAngle:45
                                       endAngle:135];
    [wifiPath setLineWidth:1.2];
    [wifiPath stroke];
  }

  // Battery
  rightX -= 44;
  self.batteryRect = NSMakeRect(rightX - 2, 0, 42, barH);
  // Draw battery outline
  CGFloat battY = (barH - 10) / 2;
  NSRect battBody = NSMakeRect(rightX, battY, 22, 10);
  NSBezierPath *battPath = [NSBezierPath bezierPathWithRoundedRect:battBody
                                                           xRadius:2.5
                                                           yRadius:2.5];
  [[NSColor colorWithWhite:0.0 alpha:0.75] setStroke];
  [battPath setLineWidth:1.0];
  [battPath stroke];
  // Battery tip
  NSRect battTip = NSMakeRect(rightX + 22, battY + 3, 2, 4);
  [[NSColor colorWithWhite:0.0 alpha:0.50] setFill];
  [[NSBezierPath bezierPathWithRoundedRect:battTip xRadius:0.5
                                   yRadius:0.5] fill];
  // Battery fill (green when > 20%)
  NSRect battFill = NSMakeRect(rightX + 1.5, battY + 1.5, 19, 7);
  [[NSColor colorWithRed:0.25 green:0.78 blue:0.35 alpha:0.9] setFill];
  [[NSBezierPath bezierPathWithRoundedRect:battFill xRadius:1.5
                                   yRadius:1.5] fill];
  // Percentage text
  NSString *battText = @"100%";
  NSDictionary *battAttrs = @{
    NSFontAttributeName : [NSFont systemFontOfSize:10
                                            weight:NSFontWeightMedium],
    NSForegroundColorAttributeName : [NSColor colorWithWhite:0.0 alpha:0.75]
  };
  NSSize battTextSize = [battText sizeWithAttributes:battAttrs];
  [battText
         drawAtPoint:NSMakePoint(rightX + 25, (barH - battTextSize.height) / 2)
      withAttributes:battAttrs];
}

- (void)mouseMoved:(NSEvent *)event {
  NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
  NSInteger oldHovered = self.hoveredItem;
  self.hoveredItem = -1;

  if (NSPointInRect(location, self.appleLogoRect)) {
    self.hoveredItem = -2;
  } else {
    for (NSInteger i = 0; i < (NSInteger)self.menuItemRects.count; i++) {
      NSDictionary *itemInfo = self.menuItemRects[i];
      NSRect rect = [itemInfo[@"rect"] rectValue];
      if (NSPointInRect(location, rect)) {
        self.hoveredItem = i;
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
  [self setNeedsDisplay:YES];
}

- (void)mouseDown:(NSEvent *)event {
  NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];

  if (NSPointInRect(location, self.appleLogoRect)) {
    if (self.delegate &&
        [self.delegate respondsToSelector:@selector(menuBarAppleMenuClicked)]) {
      [self.delegate menuBarAppleMenuClicked];
    }
    return;
  }

  if (NSPointInRect(location, self.wifiRect)) {
    if (self.delegate &&
        [self.delegate respondsToSelector:@selector(menuBarItemClicked:)]) {
      [self.delegate menuBarItemClicked:@"WiFi"];
    }
    return;
  }

  for (NSDictionary *itemInfo in self.menuItemRects) {
    NSRect rect = [itemInfo[@"rect"] rectValue];
    if (NSPointInRect(location, rect)) {
      NSString *itemName = itemInfo[@"name"];
      if (self.delegate &&
          [self.delegate respondsToSelector:@selector(menuBarItemClicked:)]) {
        [self.delegate menuBarItemClicked:itemName];
      }
      break;
    }
  }
}

@end
