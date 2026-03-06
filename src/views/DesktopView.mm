#import "DesktopView.h"
#include <cmath>

// ============================================================================
// DesktopView.mm — Pixel-Perfect macOS Sequoia Desktop
// Real wallpaper, system icons via NSWorkspace, grid-aligned icons,
// rubber-band selection, right-click context menu
// ============================================================================

static const CGFloat kIconGridSpacing = 80.0;
static const CGFloat kIconSize = 64.0;
static const CGFloat kIconLabelMaxWidth = 80.0;
static const CGFloat kIconPaddingRight = 20.0;
static const CGFloat kIconPaddingTop = 50.0; // below menu bar
static const CGFloat kIconLabelFontSize = 11.0;
static const CGFloat kSelectionCornerRadius = 4.0;

@interface DesktopView ()
@property(nonatomic, strong) NSArray *desktopIcons;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, NSImage *> *iconCache;
@property(nonatomic, strong) NSImage *wallpaperImage;
@property(nonatomic, assign) BOOL isDraggingSelection;
@property(nonatomic, assign) NSPoint selectionStart;
@property(nonatomic, assign) NSPoint selectionEnd;
@end

@implementation DesktopView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.selectedIcon = -1;
    self.iconCache = [NSMutableDictionary dictionary];
    [self setupDesktopIcons];
    [self loadWallpaper];
    [self preloadIcons];
  }
  return self;
}

- (void)setupDesktopIcons {
  self.desktopIcons = @[
    @{@"name" : @"Macintosh HD", @"path" : @"/", @"type" : @"volume"},
    @{@"name" : @"Documents", @"path" : @"~/Documents", @"type" : @"folder"},
    @{@"name" : @"Downloads", @"path" : @"~/Downloads", @"type" : @"folder"}, @{
      @"name" : @"Applications",
      @"path" : @"/Applications",
      @"type" : @"folder"
    },
    @{@"name" : @"Trash", @"path" : @"~/.Trash", @"type" : @"trash"}
  ];
}

- (void)loadWallpaper {
  // Try to load a real macOS wallpaper
  NSArray *wallpaperPaths = @[
    @"/System/Library/Desktop Pictures/Sequoia.heic",
    @"/System/Library/Desktop Pictures/Ventura.heic",
    @"/System/Library/Desktop Pictures/Sonoma.heic",
    @"/System/Library/Desktop Pictures/Monterey.heic",
    @"/System/Library/Desktop Pictures/Big Sur.heic",
    @"/System/Library/Desktop Pictures/Catalina.heic",
    @"/Library/Desktop Pictures/Solid Colors/Teal.png",
  ];

  for (NSString *path in wallpaperPaths) {
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
      self.wallpaperImage = [[NSImage alloc] initWithContentsOfFile:path];
      if (self.wallpaperImage)
        return;
    }
  }

  // Try any .heic in Desktop Pictures
  NSArray *files = [[NSFileManager defaultManager]
      contentsOfDirectoryAtPath:@"/System/Library/Desktop Pictures"
                          error:nil];
  for (NSString *file in files) {
    if ([file hasSuffix:@".heic"] || [file hasSuffix:@".jpg"]) {
      NSString *fullPath = [@"/System/Library/Desktop Pictures"
          stringByAppendingPathComponent:file];
      self.wallpaperImage = [[NSImage alloc] initWithContentsOfFile:fullPath];
      if (self.wallpaperImage)
        return;
    }
  }
}

- (void)preloadIcons {
  NSWorkspace *ws = [NSWorkspace sharedWorkspace];
  for (NSDictionary *item in self.desktopIcons) {
    NSString *name = item[@"name"];
    NSString *path = [item[@"path"] stringByExpandingTildeInPath];
    NSString *type = item[@"type"];
    NSImage *icon = nil;

    if ([type isEqualToString:@"volume"]) {
      // Hard drive icon
      icon = [ws iconForFile:@"/"];
    } else if ([type isEqualToString:@"trash"]) {
      // Trash icon
      icon = [ws iconForFile:[@"~/.Trash" stringByExpandingTildeInPath]];
      if (!icon) {
        icon = [NSImage imageWithSystemSymbolName:@"trash.fill"
                         accessibilityDescription:@"Trash"];
      }
    } else if ([type isEqualToString:@"folder"]) {
      if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        icon = [ws iconForFile:path];
      } else {
        icon = [ws iconForFileType:NSFileTypeForHFSTypeCode('fldr')];
      }
    }

    if (!icon) {
      icon = [ws iconForFileType:NSFileTypeForHFSTypeCode('fldr')];
    }
    icon.size = NSMakeSize(kIconSize * 2, kIconSize * 2);
    self.iconCache[name] = icon;
  }
}

#pragma mark - Drawing

- (void)drawRect:(NSRect)dirtyRect {
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;

  // ── WALLPAPER ──
  if (self.wallpaperImage) {
    [self.wallpaperImage drawInRect:self.bounds
                           fromRect:NSZeroRect
                          operation:NSCompositingOperationSourceOver
                           fraction:1.0];
  } else {
    [self drawGradientWallpaper:w h:h];
  }

  // ── DESKTOP ICONS (top-right grid, macOS standard) ──
  for (NSInteger i = 0; i < (NSInteger)self.desktopIcons.count; i++) {
    NSDictionary *item = self.desktopIcons[i];
    NSRect iconFrame = [self iconFrameAtIndex:i];
    NSRect imageRect =
        NSMakeRect(iconFrame.origin.x + (kIconGridSpacing - kIconSize) / 2,
                   iconFrame.origin.y + 18, kIconSize, kIconSize);

    // ── Selection highlight ──
    if (i == self.selectedIcon) {
      NSBezierPath *selPath =
          [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(iconFrame, -2, -2)
                                          xRadius:kSelectionCornerRadius
                                          yRadius:kSelectionCornerRadius];
      [[NSColor colorWithRed:0.25 green:0.55 blue:0.95 alpha:0.25] setFill];
      [selPath fill];
    }

    // ── Icon image ──
    NSImage *icon = self.iconCache[item[@"name"]];
    if (icon) {
      [icon drawInRect:imageRect
              fromRect:NSZeroRect
             operation:NSCompositingOperationSourceOver
              fraction:1.0];
    }

    // ── Label ──
    NSString *label = item[@"name"];
    NSMutableParagraphStyle *paraStyle = [[NSMutableParagraphStyle alloc] init];
    paraStyle.alignment = NSTextAlignmentCenter;
    paraStyle.lineBreakMode = NSLineBreakByTruncatingTail;

    NSDictionary *labelAttrs;
    if (i == self.selectedIcon) {
      // Selected: white text on blue background
      labelAttrs = @{
        NSFontAttributeName : [NSFont systemFontOfSize:kIconLabelFontSize
                                                weight:NSFontWeightRegular],
        NSForegroundColorAttributeName : [NSColor whiteColor],
        NSParagraphStyleAttributeName : paraStyle
      };
    } else {
      // Normal: white text with shadow
      NSShadow *shadow = [[NSShadow alloc] init];
      shadow.shadowColor = [NSColor colorWithWhite:0.0 alpha:0.70];
      shadow.shadowOffset = NSMakeSize(0, -1);
      shadow.shadowBlurRadius = 3.0;

      labelAttrs = @{
        NSFontAttributeName : [NSFont systemFontOfSize:kIconLabelFontSize
                                                weight:NSFontWeightRegular],
        NSForegroundColorAttributeName : [NSColor whiteColor],
        NSShadowAttributeName : shadow,
        NSParagraphStyleAttributeName : paraStyle
      };
    }

    NSSize labelSz = [label sizeWithAttributes:labelAttrs];
    CGFloat labelX =
        iconFrame.origin.x + (kIconGridSpacing - labelSz.width) / 2;
    CGFloat labelY = iconFrame.origin.y;
    NSRect labelRect = NSMakeRect(labelX - 4, labelY,
                                  fmin(labelSz.width + 8, kIconLabelMaxWidth),
                                  labelSz.height + 2);

    // Label background for selected
    if (i == self.selectedIcon) {
      NSBezierPath *labelBg = [NSBezierPath bezierPathWithRoundedRect:labelRect
                                                              xRadius:3
                                                              yRadius:3];
      [[NSColor colorWithRed:0.22 green:0.50 blue:0.92 alpha:0.90] setFill];
      [labelBg fill];
    }

    [label drawInRect:labelRect withAttributes:labelAttrs];
  }

  // ── Rubber-band selection rectangle ──
  if (self.isDraggingSelection) {
    NSRect selRect = [self selectionRectangle];
    NSBezierPath *selPath = [NSBezierPath bezierPathWithRect:selRect];
    [[NSColor colorWithRed:0.25 green:0.55 blue:0.95 alpha:0.15] setFill];
    [selPath fill];
    [[NSColor colorWithRed:0.25 green:0.55 blue:0.95 alpha:0.50] setStroke];
    [selPath setLineWidth:1.0];
    [selPath stroke];
  }
}

#pragma mark - Gradient Wallpaper Fallback

- (void)drawGradientWallpaper:(CGFloat)w h:(CGFloat)h {
  // macOS Sequoia-inspired deep blue/purple gradient
  NSGradient *baseGrad =
      [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithRed:0.04
                                                                     green:0.06
                                                                      blue:0.16
                                                                     alpha:1.0],
                                                     0.0,
                                                     [NSColor colorWithRed:0.08
                                                                     green:0.12
                                                                      blue:0.28
                                                                     alpha:1.0],
                                                     0.20,
                                                     [NSColor colorWithRed:0.14
                                                                     green:0.20
                                                                      blue:0.40
                                                                     alpha:1.0],
                                                     0.40,
                                                     [NSColor colorWithRed:0.22
                                                                     green:0.28
                                                                      blue:0.50
                                                                     alpha:1.0],
                                                     0.55,
                                                     [NSColor colorWithRed:0.35
                                                                     green:0.38
                                                                      blue:0.55
                                                                     alpha:1.0],
                                                     0.70,
                                                     [NSColor colorWithRed:0.55
                                                                     green:0.48
                                                                      blue:0.58
                                                                     alpha:1.0],
                                                     0.82,
                                                     [NSColor colorWithRed:0.75
                                                                     green:0.58
                                                                      blue:0.55
                                                                     alpha:1.0],
                                                     0.92,
                                                     [NSColor colorWithRed:0.90
                                                                     green:0.70
                                                                      blue:0.55
                                                                     alpha:1.0],
                                                     1.0, nil];
  [baseGrad drawInRect:self.bounds angle:160];

  // Mountain silhouettes
  NSBezierPath *mtns = [NSBezierPath bezierPath];
  [mtns moveToPoint:NSMakePoint(0, h * 0.30)];
  [mtns lineToPoint:NSMakePoint(w * 0.10, h * 0.40)];
  [mtns lineToPoint:NSMakePoint(w * 0.18, h * 0.52)];
  [mtns lineToPoint:NSMakePoint(w * 0.25, h * 0.47)];
  [mtns lineToPoint:NSMakePoint(w * 0.32, h * 0.58)];
  [mtns lineToPoint:NSMakePoint(w * 0.40, h * 0.54)];
  [mtns lineToPoint:NSMakePoint(w * 0.48, h * 0.65)];
  [mtns lineToPoint:NSMakePoint(w * 0.52, h * 0.60)];
  [mtns lineToPoint:NSMakePoint(w * 0.58, h * 0.70)];
  [mtns lineToPoint:NSMakePoint(w * 0.65, h * 0.62)];
  [mtns lineToPoint:NSMakePoint(w * 0.72, h * 0.55)];
  [mtns lineToPoint:NSMakePoint(w * 0.80, h * 0.60)];
  [mtns lineToPoint:NSMakePoint(w * 0.88, h * 0.48)];
  [mtns lineToPoint:NSMakePoint(w * 0.94, h * 0.44)];
  [mtns lineToPoint:NSMakePoint(w, h * 0.38)];
  [mtns lineToPoint:NSMakePoint(w, 0)];
  [mtns lineToPoint:NSMakePoint(0, 0)];
  [mtns closePath];

  NSGradient *mtnGrad =
      [[NSGradient alloc] initWithStartingColor:[NSColor colorWithRed:0.04
                                                                green:0.06
                                                                 blue:0.14
                                                                alpha:0.55]
                                    endingColor:[NSColor colorWithRed:0.06
                                                                green:0.10
                                                                 blue:0.20
                                                                alpha:0.25]];
  [mtnGrad drawInBezierPath:mtns angle:90];

  // Subtle lake reflection
  NSRect lakeRect = NSMakeRect(0, h * 0.12, w, h * 0.18);
  NSGradient *lakeGrad = [[NSGradient alloc]
      initWithColorsAndLocations:[NSColor colorWithWhite:0.3 alpha:0.0], 0.0,
                                 [NSColor colorWithWhite:0.4 alpha:0.12], 0.3,
                                 [NSColor colorWithWhite:0.5 alpha:0.18], 0.5,
                                 [NSColor colorWithWhite:0.4 alpha:0.12], 0.7,
                                 [NSColor colorWithWhite:0.3 alpha:0.0], 1.0,
                                 nil];
  [lakeGrad drawInRect:lakeRect angle:0];

  // Atmospheric haze near mountains
  NSRect hazeRect = NSMakeRect(0, h * 0.25, w, h * 0.15);
  NSGradient *hazeGrad = [[NSGradient alloc]
      initWithStartingColor:[NSColor colorWithWhite:0.7 alpha:0.0]
                endingColor:[NSColor colorWithWhite:0.7 alpha:0.06]];
  [hazeGrad drawInRect:hazeRect angle:90];
}

#pragma mark - Icon Layout (Top-Right Grid)

- (NSRect)iconFrameAtIndex:(NSInteger)index {
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;

  // macOS places icons from top-right, going downward then leftward
  NSInteger col = index / 5; // 5 icons per column
  NSInteger row = index % 5;

  CGFloat x = w - kIconPaddingRight - kIconGridSpacing - col * kIconGridSpacing;
  CGFloat y = h - kIconPaddingTop - kIconGridSpacing - row * kIconGridSpacing;

  return NSMakeRect(x, y, kIconGridSpacing, kIconGridSpacing);
}

#pragma mark - Selection Rectangle

- (NSRect)selectionRectangle {
  CGFloat x = fmin(self.selectionStart.x, self.selectionEnd.x);
  CGFloat y = fmin(self.selectionStart.y, self.selectionEnd.y);
  CGFloat w = fabs(self.selectionEnd.x - self.selectionStart.x);
  CGFloat h = fabs(self.selectionEnd.y - self.selectionStart.y);
  return NSMakeRect(x, y, w, h);
}

#pragma mark - Mouse Events

- (void)mouseDown:(NSEvent *)event {
  NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];
  NSInteger oldSelected = self.selectedIcon;
  self.selectedIcon = -1;

  // Check icon clicks
  for (NSInteger i = 0; i < (NSInteger)self.desktopIcons.count; i++) {
    NSRect frame = [self iconFrameAtIndex:i];
    if (NSPointInRect(loc, frame)) {
      self.selectedIcon = i;

      // Double click
      if (event.clickCount == 2) {
        NSDictionary *item = self.desktopIcons[i];
        if (self.delegate) {
          [self.delegate desktopIconDoubleClicked:item[@"name"]
                                             path:item[@"path"]];
        }
      }
      [self setNeedsDisplay:YES];
      return;
    }
  }

  // Start rubber-band selection on desktop background
  self.isDraggingSelection = YES;
  self.selectionStart = loc;
  self.selectionEnd = loc;
  [self setNeedsDisplay:YES];
}

- (void)mouseDragged:(NSEvent *)event {
  if (self.isDraggingSelection) {
    self.selectionEnd = [self convertPoint:[event locationInWindow]
                                  fromView:nil];
    [self setNeedsDisplay:YES];
  }
}

- (void)mouseUp:(NSEvent *)event {
  self.isDraggingSelection = NO;
  [self setNeedsDisplay:YES];
}

- (void)rightMouseDown:(NSEvent *)event {
  NSPoint loc = [self convertPoint:[event locationInWindow] fromView:nil];

  // Check if right-clicking on an icon
  for (NSInteger i = 0; i < (NSInteger)self.desktopIcons.count; i++) {
    NSRect frame = [self iconFrameAtIndex:i];
    if (NSPointInRect(loc, frame)) {
      self.selectedIcon = i;
      [self showIconContextMenu:self.desktopIcons[i] event:event];
      [self setNeedsDisplay:YES];
      return;
    }
  }

  // Right-click on desktop background
  [self showDesktopContextMenu:event];
}

#pragma mark - Context Menus

- (void)showDesktopContextMenu:(NSEvent *)event {
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Desktop"];
  menu.font = [NSFont systemFontOfSize:13];

  [menu addItemWithTitle:@"New Folder"
                  action:@selector(desktopAction:)
           keyEquivalent:@"N"];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Get Info"
                  action:@selector(desktopAction:)
           keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Change Desktop Background..."
                  action:@selector(desktopAction:)
           keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Use Stacks"
                  action:@selector(desktopAction:)
           keyEquivalent:@""];
  [menu addItemWithTitle:@"Sort By" action:nil keyEquivalent:@""];
  [menu addItemWithTitle:@"Clean Up"
                  action:@selector(desktopAction:)
           keyEquivalent:@""];
  [menu addItemWithTitle:@"Clean Up By" action:nil keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Show View Options"
                  action:@selector(desktopAction:)
           keyEquivalent:@""];

  for (NSMenuItem *item in menu.itemArray)
    item.target = self;
  [NSMenu popUpContextMenu:menu withEvent:event forView:self];
}

- (void)showIconContextMenu:(NSDictionary *)iconInfo event:(NSEvent *)event {
  NSString *name = iconInfo[@"name"];
  NSMenu *menu = [[NSMenu alloc] initWithTitle:name];
  menu.font = [NSFont systemFontOfSize:13];

  [menu addItemWithTitle:@"Open"
                  action:@selector(iconAction:)
           keyEquivalent:@""];
  [menu addItem:[NSMenuItem separatorItem]];
  [menu addItemWithTitle:@"Get Info"
                  action:@selector(iconAction:)
           keyEquivalent:@"i"];
  [menu addItemWithTitle:@"Rename"
                  action:@selector(iconAction:)
           keyEquivalent:@""];

  if ([name isEqualToString:@"Trash"]) {
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Empty Trash"
                    action:@selector(iconAction:)
             keyEquivalent:@""];
  } else {
    [menu addItem:[NSMenuItem separatorItem]];
    [menu addItemWithTitle:@"Duplicate"
                    action:@selector(iconAction:)
             keyEquivalent:@""];
    [menu addItemWithTitle:@"Move to Trash"
                    action:@selector(iconAction:)
             keyEquivalent:@""];
  }

  for (NSMenuItem *item in menu.itemArray)
    item.target = self;
  [NSMenu popUpContextMenu:menu withEvent:event forView:self];
}

- (void)desktopAction:(NSMenuItem *)sender {
  if ([self.delegate respondsToSelector:@selector(menuBarItemClicked:)]) {
    // Forward to delegate if possible
  }
}

- (void)iconAction:(NSMenuItem *)sender {
  if (self.selectedIcon >= 0 && [sender.title isEqualToString:@"Open"]) {
    NSDictionary *item = self.desktopIcons[self.selectedIcon];
    if (self.delegate) {
      [self.delegate desktopIconDoubleClicked:item[@"name"] path:item[@"path"]];
    }
  }
}

@end
