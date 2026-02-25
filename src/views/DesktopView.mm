#import "DesktopView.h"
#include <cmath>

@interface DesktopView ()
@property(nonatomic, strong) NSArray *desktopIcons;
@end

@implementation DesktopView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.selectedIcon = -1;
    [self setupDesktopIcons];
  }
  return self;
}

- (void)setupDesktopIcons {
  self.desktopIcons = @[
    @{@"name" : @"Macintosh HD", @"path" : @"/"},
    @{@"name" : @"Documents", @"path" : @"/Users/Guest/Documents"},
    @{@"name" : @"Downloads", @"path" : @"/Users/Guest/Downloads"},
    @{@"name" : @"Applications", @"path" : @"/Applications"},
    @{@"name" : @"Trash", @"path" : @"/Users/Guest/.Trash"}
  ];
}

- (void)drawRect:(NSRect)dirtyRect {
  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;

  // ─── macOS TAHOE WALLPAPER ───
  // Soft, warm layered gradient with the Tahoe lake/mountain aesthetic
  // Base: deep teal to warm amber/gold
  NSGradient *baseGrad =
      [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithRed:0.04
                                                                     green:0.12
                                                                      blue:0.22
                                                                     alpha:1.0],
                                                     0.0,
                                                     [NSColor colorWithRed:0.06
                                                                     green:0.18
                                                                      blue:0.32
                                                                     alpha:1.0],
                                                     0.15,
                                                     [NSColor colorWithRed:0.12
                                                                     green:0.28
                                                                      blue:0.46
                                                                     alpha:1.0],
                                                     0.30,
                                                     [NSColor colorWithRed:0.25
                                                                     green:0.38
                                                                      blue:0.52
                                                                     alpha:1.0],
                                                     0.45,
                                                     [NSColor colorWithRed:0.45
                                                                     green:0.42
                                                                      blue:0.48
                                                                     alpha:1.0],
                                                     0.55,
                                                     [NSColor colorWithRed:0.70
                                                                     green:0.50
                                                                      blue:0.42
                                                                     alpha:1.0],
                                                     0.70,
                                                     [NSColor colorWithRed:0.88
                                                                     green:0.62
                                                                      blue:0.40
                                                                     alpha:1.0],
                                                     0.85,
                                                     [NSColor colorWithRed:0.97
                                                                     green:0.78
                                                                      blue:0.52
                                                                     alpha:1.0],
                                                     1.0, nil];
  [baseGrad drawInRect:self.bounds angle:160];

  // Mountain silhouette shape (subtle dark overlay)
  NSBezierPath *mountainPath = [NSBezierPath bezierPath];
  [mountainPath moveToPoint:NSMakePoint(0, h * 0.35)];
  [mountainPath lineToPoint:NSMakePoint(w * 0.08, h * 0.42)];
  [mountainPath lineToPoint:NSMakePoint(w * 0.15, h * 0.55)];
  [mountainPath lineToPoint:NSMakePoint(w * 0.22, h * 0.50)];
  [mountainPath lineToPoint:NSMakePoint(w * 0.30, h * 0.62)];
  [mountainPath lineToPoint:NSMakePoint(w * 0.38, h * 0.58)];
  [mountainPath lineToPoint:NSMakePoint(w * 0.45, h * 0.68)];
  [mountainPath lineToPoint:NSMakePoint(w * 0.50, h * 0.64)];
  [mountainPath lineToPoint:NSMakePoint(w * 0.55, h * 0.72)];
  [mountainPath lineToPoint:NSMakePoint(w * 0.62, h * 0.65)];
  [mountainPath lineToPoint:NSMakePoint(w * 0.70, h * 0.58)];
  [mountainPath lineToPoint:NSMakePoint(w * 0.78, h * 0.62)];
  [mountainPath lineToPoint:NSMakePoint(w * 0.85, h * 0.52)];
  [mountainPath lineToPoint:NSMakePoint(w * 0.92, h * 0.48)];
  [mountainPath lineToPoint:NSMakePoint(w, h * 0.40)];
  [mountainPath lineToPoint:NSMakePoint(w, 0)];
  [mountainPath lineToPoint:NSMakePoint(0, 0)];
  [mountainPath closePath];

  NSGradient *mountainGrad =
      [[NSGradient alloc] initWithStartingColor:[NSColor colorWithRed:0.05
                                                                green:0.10
                                                                 blue:0.18
                                                                alpha:0.6]
                                    endingColor:[NSColor colorWithRed:0.08
                                                                green:0.15
                                                                 blue:0.25
                                                                alpha:0.3]];
  [mountainGrad drawInBezierPath:mountainPath angle:90];

  // Lake reflection (horizontal band of lighter color)
  NSRect lakeRect = NSMakeRect(0, h * 0.15, w, h * 0.20);
  NSGradient *lakeGrad = [[NSGradient alloc]
      initWithColorsAndLocations:[NSColor colorWithRed:0.15
                                                 green:0.30
                                                  blue:0.50
                                                 alpha:0.0],
                                 0.0,
                                 [NSColor colorWithRed:0.18
                                                 green:0.35
                                                  blue:0.55
                                                 alpha:0.25],
                                 0.3,
                                 [NSColor colorWithRed:0.20
                                                 green:0.38
                                                  blue:0.58
                                                 alpha:0.35],
                                 0.5,
                                 [NSColor colorWithRed:0.18
                                                 green:0.35
                                                  blue:0.55
                                                 alpha:0.25],
                                 0.7,
                                 [NSColor colorWithRed:0.15
                                                 green:0.30
                                                  blue:0.50
                                                 alpha:0.0],
                                 1.0, nil];
  [lakeGrad drawInRect:lakeRect angle:0];

  // Subtle light flare in upper-right
  NSGradient *flareGrad = [[NSGradient alloc]
      initWithStartingColor:[NSColor colorWithWhite:1.0 alpha:0.12]
                endingColor:[NSColor colorWithWhite:1.0 alpha:0.0]];
  NSRect flareRect = NSMakeRect(w * 0.6, h * 0.6, w * 0.5, h * 0.45);
  NSBezierPath *flarePath = [NSBezierPath bezierPathWithOvalInRect:flareRect];
  [flareGrad drawInBezierPath:flarePath angle:45];

  // ─── DESKTOP ICONS ───
  CGFloat iconX = w - 90;
  CGFloat iconSize = 64;
  CGFloat iconSpacing = 90;

  NSArray *iconEmojis = @[ @"💻", @"📁", @"⬇️", @"📦", @"🗑️" ];

  for (NSInteger i = 0; i < (NSInteger)self.desktopIcons.count; i++) {
    NSDictionary *iconData = self.desktopIcons[i];
    CGFloat iconY;
    if (i == 4) {
      iconY = 30;
    } else {
      iconY = h - 100 - (i * iconSpacing);
    }

    NSRect iconRect = NSMakeRect(iconX, iconY, 76, 85);

    // Selection highlight
    if (i == self.selectedIcon) {
      [[NSColor colorWithRed:0.25 green:0.50 blue:0.90 alpha:0.35] setFill];
      NSBezierPath *selPath = [NSBezierPath bezierPathWithRoundedRect:iconRect
                                                              xRadius:8
                                                              yRadius:8];
      [selPath fill];
      [[NSColor colorWithRed:0.30 green:0.55 blue:0.95 alpha:0.5] setStroke];
      [selPath setLineWidth:1.0];
      [selPath stroke];
    }

    // Draw icon
    NSString *emoji = iconEmojis[i];
    NSDictionary *emojiAttrs =
        @{NSFontAttributeName : [NSFont systemFontOfSize:44]};
    NSSize emojiSize = [emoji sizeWithAttributes:emojiAttrs];
    [emoji drawAtPoint:NSMakePoint(iconX + (76 - emojiSize.width) / 2,
                                   iconY + 30)
        withAttributes:emojiAttrs];

    // Label with shadow
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;
    style.lineBreakMode = NSLineBreakByTruncatingTail;

    NSShadow *shadow = [[NSShadow alloc] init];
    shadow.shadowColor = [NSColor colorWithWhite:0 alpha:0.85];
    shadow.shadowOffset = NSMakeSize(0, -1);
    shadow.shadowBlurRadius = 3;

    NSDictionary *labelAttrs = @{
      NSFontAttributeName : [NSFont systemFontOfSize:11
                                              weight:NSFontWeightMedium],
      NSForegroundColorAttributeName : [NSColor whiteColor],
      NSParagraphStyleAttributeName : style,
      NSShadowAttributeName : shadow
    };

    NSRect labelRect = NSMakeRect(iconX - 10, iconY + 2, 96, 28);
    [iconData[@"name"] drawInRect:labelRect withAttributes:labelAttrs];
  }
}

- (void)mouseDown:(NSEvent *)event {
  NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
  CGFloat iconX = self.bounds.size.width - 90;
  CGFloat iconSpacing = 90;

  NSInteger previousSelection = self.selectedIcon;
  self.selectedIcon = -1;

  for (NSInteger i = 0; i < (NSInteger)self.desktopIcons.count; i++) {
    CGFloat iconY;
    if (i == 4) {
      iconY = 30;
    } else {
      iconY = self.bounds.size.height - 100 - (i * iconSpacing);
    }

    NSRect iconRect = NSMakeRect(iconX, iconY, 76, 85);
    if (NSPointInRect(location, iconRect)) {
      self.selectedIcon = i;

      if (event.clickCount == 2 && self.delegate) {
        NSDictionary *iconData = self.desktopIcons[i];
        [self.delegate desktopIconDoubleClicked:iconData[@"name"]
                                           path:iconData[@"path"]];
      }
      break;
    }
  }

  if (self.selectedIcon != previousSelection) {
    [self setNeedsDisplay:YES];
  }
}

- (void)rightMouseDown:(NSEvent *)event {
  NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
  CGFloat iconX = self.bounds.size.width - 90;
  CGFloat iconSpacing = 90;

  NSInteger clickedIcon = -1;
  for (NSInteger i = 0; i < (NSInteger)self.desktopIcons.count; i++) {
    CGFloat iconY;
    if (i == 4) {
      iconY = 30;
    } else {
      iconY = self.bounds.size.height - 100 - (i * iconSpacing);
    }

    NSRect iconRect = NSMakeRect(iconX, iconY, 76, 85);
    if (NSPointInRect(location, iconRect)) {
      clickedIcon = i;
      break;
    }
  }

  NSMenu *contextMenu = [[NSMenu alloc] initWithTitle:@"Context Menu"];

  if (clickedIcon >= 0) {
    NSDictionary *iconData = self.desktopIcons[clickedIcon];
    self.selectedIcon = clickedIcon;
    [self setNeedsDisplay:YES];

    NSMenuItem *openItem =
        [[NSMenuItem alloc] initWithTitle:@"Open"
                                   action:@selector(contextMenuOpen:)
                            keyEquivalent:@""];
    openItem.representedObject = iconData;
    openItem.target = self;
    [contextMenu addItem:openItem];

    NSMenuItem *infoItem =
        [[NSMenuItem alloc] initWithTitle:@"Get Info"
                                   action:@selector(contextMenuGetInfo:)
                            keyEquivalent:@""];
    infoItem.representedObject = iconData;
    infoItem.target = self;
    [contextMenu addItem:infoItem];

    [contextMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *copyItem =
        [[NSMenuItem alloc] initWithTitle:@"Copy"
                                   action:@selector(contextMenuCopy:)
                            keyEquivalent:@""];
    copyItem.representedObject = iconData;
    copyItem.target = self;
    [contextMenu addItem:copyItem];
  } else {
    [contextMenu addItemWithTitle:@"New Folder"
                           action:@selector(contextMenuNewFolder:)
                    keyEquivalent:@""];
    [contextMenu addItem:[NSMenuItem separatorItem]];
    [contextMenu addItemWithTitle:@"Change Desktop Background..."
                           action:nil
                    keyEquivalent:@""];
    [contextMenu addItem:[NSMenuItem separatorItem]];
    [contextMenu addItemWithTitle:@"Sort By" action:nil keyEquivalent:@""];
    [contextMenu addItemWithTitle:@"Clean Up" action:nil keyEquivalent:@""];
    [contextMenu addItemWithTitle:@"Show View Options"
                           action:nil
                    keyEquivalent:@""];

    for (NSMenuItem *item in contextMenu.itemArray) {
      item.target = self;
    }
  }

  [NSMenu popUpContextMenu:contextMenu withEvent:event forView:self];
}

- (void)contextMenuOpen:(NSMenuItem *)sender {
  NSDictionary *iconData = sender.representedObject;
  if (self.delegate) {
    [self.delegate desktopIconDoubleClicked:iconData[@"name"]
                                       path:iconData[@"path"]];
  }
}

- (void)contextMenuGetInfo:(NSMenuItem *)sender {
  NSDictionary *iconData = sender.representedObject;
  NSString *path = iconData[@"path"];

  NSFileManager *fm = [NSFileManager defaultManager];
  NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];

  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = iconData[@"name"];
  alert.informativeText =
      [NSString stringWithFormat:@"Path: %@\nSize: %@ bytes\nModified: %@",
                                 path, attrs[NSFileSize] ?: @"--",
                                 attrs[NSFileModificationDate] ?: @"--"];
  [alert runModal];
}

- (void)contextMenuCopy:(NSMenuItem *)sender {
  NSDictionary *iconData = sender.representedObject;
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  [pasteboard clearContents];
  [pasteboard writeObjects:@[ [NSURL fileURLWithPath:iconData[@"path"]] ]];
}

- (void)contextMenuNewFolder:(id)sender {
  NSString *desktopPath =
      [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"];
  NSString *newFolderPath =
      [desktopPath stringByAppendingPathComponent:@"New Folder"];

  NSFileManager *fm = [NSFileManager defaultManager];
  NSInteger counter = 1;
  while ([fm fileExistsAtPath:newFolderPath]) {
    newFolderPath = [desktopPath
        stringByAppendingPathComponent:[NSString
                                           stringWithFormat:@"New Folder %ld",
                                                            (long)counter++]];
  }

  [fm createDirectoryAtPath:newFolderPath
      withIntermediateDirectories:NO
                       attributes:nil
                            error:nil];
}

- (BOOL)acceptsFirstResponder {
  return YES;
}

@end
