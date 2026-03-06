#import "WindowChromeHelper.h"

// ============================================================================
// WindowChromeHelper.mm — macOS Sequoia Window Chrome
// Pixel-perfect traffic light circles, window factory, toolbar helpers
// ============================================================================

// macOS traffic light exact colors
static NSColor *kTrafficRed(void) {
  return [NSColor colorWithRed:0.996
                         green:0.373
                          blue:0.341
                         alpha:1.0]; // #FF5F57
}
static NSColor *kTrafficYellow(void) {
  return [NSColor colorWithRed:1.0 green:0.741 blue:0.180 alpha:1.0]; // #FFBD2E
}
static NSColor *kTrafficGreen(void) {
  return [NSColor colorWithRed:0.157
                         green:0.788
                          blue:0.251
                         alpha:1.0]; // #28C940
}
// Inactive (unfocused) gray
static NSColor *kTrafficInactive(void) {
  return [NSColor colorWithWhite:0.82 alpha:1.0];
}

static const CGFloat kTrafficSize = 12.0;
static const CGFloat kTrafficSpacing = 8.0;
static const CGFloat kTrafficLeftPad = 8.0;

// ============================================================================
#pragma mark - TrafficLightButton
// ============================================================================

@implementation TrafficLightButton

- (instancetype)initWithFrame:(NSRect)frame type:(NSInteger)type {
  self = [super initWithFrame:frame];
  if (self) {
    _buttonType = type;
    _isHovered = NO;
    _isGroupHovered = NO;
    switch (type) {
    case 0:
      _baseColor = kTrafficRed();
      break;
    case 1:
      _baseColor = kTrafficYellow();
      break;
    case 2:
      _baseColor = kTrafficGreen();
      break;
    default:
      _baseColor = kTrafficInactive();
      break;
    }
  }
  return self;
}

- (void)drawRect:(NSRect)dirtyRect {
  NSRect circleRect = NSInsetRect(self.bounds, 0.5, 0.5);
  NSBezierPath *circle = [NSBezierPath bezierPathWithOvalInRect:circleRect];

  // Draw the colored circle
  if (self.isGroupHovered || self.isHovered) {
    [self.baseColor setFill];
  } else {
    // When not hovered: subtle gray circles (macOS behavior when window
    // unfocused)
    [self.baseColor setFill];
  }
  [circle fill];

  // Subtle inner shadow / border
  [[NSColor colorWithWhite:0.0 alpha:0.12] setStroke];
  [circle setLineWidth:0.5];
  [circle stroke];

  // Draw glyph on hover
  if (self.isGroupHovered) {
    NSDictionary *glyphAttrs = @{
      NSFontAttributeName : [NSFont systemFontOfSize:8 weight:NSFontWeightBold],
      NSForegroundColorAttributeName : [NSColor colorWithWhite:0.0 alpha:0.55]
    };

    NSString *glyph = @"";
    switch (self.buttonType) {
    case 0:
      glyph = @"✕";
      break; // close
    case 1:
      glyph = @"−";
      break; // minimize
    case 2:
      glyph = @"⤢";
      break; // zoom/fullscreen
    }

    NSSize sz = [glyph sizeWithAttributes:glyphAttrs];
    CGFloat x = (self.bounds.size.width - sz.width) / 2;
    CGFloat y = (self.bounds.size.height - sz.height) / 2;

    // Adjust centering for specific glyphs
    if (self.buttonType == 0) {
      x -= 0.5;
      y += 0.5;
    }
    if (self.buttonType == 1) {
      y += 1.0;
    }
    if (self.buttonType == 2) {
      x -= 0.5;
    }

    [glyph drawAtPoint:NSMakePoint(x, y) withAttributes:glyphAttrs];
  }
}

- (void)mouseDown:(NSEvent *)event {
  if (self.action)
    self.action();
}

@end

// ============================================================================
#pragma mark - TrafficLightGroup
// ============================================================================

@implementation TrafficLightGroup

- (instancetype)initWithFrame:(NSRect)frame {
  // Group frame: holds 3 buttons horizontally
  CGFloat totalW = kTrafficSize * 3 + kTrafficSpacing * 2 + kTrafficLeftPad;
  NSRect groupFrame =
      NSMakeRect(frame.origin.x, frame.origin.y, totalW, kTrafficSize + 4);
  self = [super initWithFrame:groupFrame];
  if (self) {
    CGFloat y = 2;
    CGFloat x = kTrafficLeftPad;

    _closeButton = [[TrafficLightButton alloc]
        initWithFrame:NSMakeRect(x, y, kTrafficSize, kTrafficSize)
                 type:0];
    x += kTrafficSize + kTrafficSpacing;

    _minimizeButton = [[TrafficLightButton alloc]
        initWithFrame:NSMakeRect(x, y, kTrafficSize, kTrafficSize)
                 type:1];
    x += kTrafficSize + kTrafficSpacing;

    _zoomButton = [[TrafficLightButton alloc]
        initWithFrame:NSMakeRect(x, y, kTrafficSize, kTrafficSize)
                 type:2];

    [self addSubview:_closeButton];
    [self addSubview:_minimizeButton];
    [self addSubview:_zoomButton];

    // Mouse tracking for group hover
    NSTrackingArea *ta = [[NSTrackingArea alloc]
        initWithRect:self.bounds
             options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveAlways |
                      NSTrackingInVisibleRect)
               owner:self
            userInfo:nil];
    [self addTrackingArea:ta];
  }
  return self;
}

- (void)mouseEntered:(NSEvent *)event {
  self.closeButton.isGroupHovered = YES;
  self.minimizeButton.isGroupHovered = YES;
  self.zoomButton.isGroupHovered = YES;
  [self.closeButton setNeedsDisplay:YES];
  [self.minimizeButton setNeedsDisplay:YES];
  [self.zoomButton setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event {
  self.closeButton.isGroupHovered = NO;
  self.minimizeButton.isGroupHovered = NO;
  self.zoomButton.isGroupHovered = NO;
  [self.closeButton setNeedsDisplay:YES];
  [self.minimizeButton setNeedsDisplay:YES];
  [self.zoomButton setNeedsDisplay:YES];
}

- (void)setCloseAction:(void (^)(void))action {
  self.closeButton.action = action;
}

- (void)setMinimizeAction:(void (^)(void))action {
  self.minimizeButton.action = action;
}

- (void)setZoomAction:(void (^)(void))action {
  self.zoomButton.action = action;
}

@end

// ============================================================================
#pragma mark - WindowChromeHelper
// ============================================================================

@implementation WindowChromeHelper

+ (NSWindow *)createWindowWithTitle:(NSString *)title
                              frame:(NSRect)frame
                          styleMask:(NSWindowStyleMask)mask {
  NSWindow *window =
      [[NSWindow alloc] initWithContentRect:frame
                                  styleMask:mask
                                    backing:NSBackingStoreBuffered
                                      defer:NO];
  window.title = title;
  [self applyMacOSChrome:window];
  return window;
}

+ (void)applyMacOSChrome:(NSWindow *)window {
  // ── Title bar appearance ──
  window.titlebarAppearsTransparent = NO;
  window.titleVisibility = NSWindowTitleVisible;

  // ── macOS shadow ──
  window.hasShadow = YES;
  window.backgroundColor = [self windowBackgroundColor];

  // ── Rounded corners (macOS 11+) ──
  if (@available(macOS 11.0, *)) {
    // NSWindow automatically gets rounded corners in Big Sur+
  }

  // ── Toolbar style ──
  if (@available(macOS 11.0, *)) {
    window.toolbarStyle = NSWindowToolbarStyleUnified;
  }
}

+ (TrafficLightGroup *)addTrafficLightsToView:(NSView *)titleBar
                                  closeAction:(void (^)(void))closeAction
                               minimizeAction:(void (^)(void))minAction
                                   zoomAction:(void (^)(void))zoomAction {
  CGFloat y = (titleBar.bounds.size.height - kTrafficSize) / 2;
  TrafficLightGroup *group =
      [[TrafficLightGroup alloc] initWithFrame:NSMakeRect(0, y, 0, 0)];
  [group setCloseAction:closeAction];
  [group setMinimizeAction:minAction];
  [group setZoomAction:zoomAction];
  [titleBar addSubview:group];
  return group;
}

+ (NSView *)createToolbarSeparator:(CGFloat)width y:(CGFloat)y {
  NSView *sep = [[NSView alloc] initWithFrame:NSMakeRect(0, y, width, 1)];
  sep.wantsLayer = YES;
  sep.layer.backgroundColor = [self separatorColor].CGColor;
  sep.autoresizingMask = NSViewWidthSizable;
  return sep;
}

#pragma mark - Standard Colors

+ (NSColor *)windowBackgroundColor {
  return [NSColor colorWithRed:0.96 green:0.96 blue:0.96 alpha:1.0];
}

+ (NSColor *)sidebarBackgroundColor {
  return [NSColor colorWithRed:0.94 green:0.94 blue:0.96 alpha:1.0];
}

+ (NSColor *)toolbarBackgroundColor {
  return [NSColor colorWithRed:0.97 green:0.97 blue:0.97 alpha:1.0];
}

+ (NSColor *)separatorColor {
  return [NSColor colorWithWhite:0.0 alpha:0.10];
}

+ (NSColor *)titleTextColor {
  return [NSColor colorWithWhite:0.20 alpha:1.0];
}

@end
