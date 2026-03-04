#import "ControlCenterWindow.h"
#import <QuartzCore/QuartzCore.h>

@interface ControlCenterWindow ()
@property(nonatomic, strong) NSWindow *panel;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, NSNumber *> *toggleStates;
@property(nonatomic, strong) NSSlider *brightnessSlider;
@property(nonatomic, strong) NSSlider *volumeSlider;
@property(nonatomic, strong) NSTextField *brightnessLabel;
@property(nonatomic, strong) NSTextField *volumeLabel;
@end

@implementation ControlCenterWindow

+ (instancetype)sharedInstance {
  static ControlCenterWindow *inst;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    inst = [[ControlCenterWindow alloc] init];
  });
  return inst;
}

- (instancetype)init {
  if (self = [super init]) {
    _toggleStates = [@{
      @"WiFi" : @YES,
      @"Bluetooth" : @YES,
      @"AirDrop" : @NO,
      @"Focus" : @NO,
      @"AirPlay" : @NO,
      @"Night Shift" : @NO,
      @"Screen Mirroring" : @NO,
      @"Dark Mode" : @YES
    } mutableCopy];
  }
  return self;
}

- (void)toggle {
  if (self.panel && self.panel.isVisible) {
    [self.panel orderOut:nil];
  } else {
    [self showWindow];
  }
}

- (void)showWindow {
  if (self.panel) {
    [self.panel makeKeyAndOrderFront:nil];
    return;
  }

  NSScreen *screen = [NSScreen mainScreen];
  CGFloat panelW = 320, panelH = 520;
  CGFloat x = screen.frame.size.width - panelW - 8;
  CGFloat y = screen.frame.size.height - panelH - 32;

  self.panel =
      [[NSWindow alloc] initWithContentRect:NSMakeRect(x, y, panelW, panelH)
                                  styleMask:NSWindowStyleMaskBorderless
                                    backing:NSBackingStoreBuffered
                                      defer:NO];
  self.panel.level = NSFloatingWindowLevel;
  self.panel.backgroundColor = [NSColor clearColor];
  self.panel.opaque = NO;
  self.panel.hasShadow = YES;
  self.panel.releasedWhenClosed = NO;

  NSView *root = self.panel.contentView;
  root.wantsLayer = YES;
  root.layer.cornerRadius = 14;
  root.layer.masksToBounds = YES;

  NSVisualEffectView *blur =
      [[NSVisualEffectView alloc] initWithFrame:root.bounds];
  blur.material = NSVisualEffectMaterialHUDWindow;
  blur.blendingMode = NSVisualEffectBlendingModeBehindWindow;
  blur.state = NSVisualEffectStateActive;
  blur.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [root addSubview:blur];

  CGFloat y0 = panelH - 20;
  CGFloat tileW = (panelW - 48) / 2.0;
  CGFloat tileH = 44;

  // Top row: WiFi + Bluetooth
  y0 -= tileH;
  [self addToggleTile:@"WiFi"
                 icon:@"📶"
                frame:NSMakeRect(16, y0, tileW, tileH)
               parent:blur];
  [self addToggleTile:@"Bluetooth"
                 icon:@"🔵"
                frame:NSMakeRect(16 + tileW + 16, y0, tileW, tileH)
               parent:blur];

  // Second row: AirDrop + Focus
  y0 -= tileH + 12;
  [self addToggleTile:@"AirDrop"
                 icon:@"📡"
                frame:NSMakeRect(16, y0, tileW, tileH)
               parent:blur];
  [self addToggleTile:@"Focus"
                 icon:@"🌙"
                frame:NSMakeRect(16 + tileW + 16, y0, tileW, tileH)
               parent:blur];

  // Third row: AirPlay + Screen Mirroring
  y0 -= tileH + 12;
  [self addToggleTile:@"AirPlay"
                 icon:@"📺"
                frame:NSMakeRect(16, y0, tileW, tileH)
               parent:blur];
  [self addToggleTile:@"Screen Mirroring"
                 icon:@"🖥"
                frame:NSMakeRect(16 + tileW + 16, y0, tileW, tileH)
               parent:blur];

  // Fourth row: Dark Mode + Night Shift
  y0 -= tileH + 12;
  [self addToggleTile:@"Dark Mode"
                 icon:@"🌑"
                frame:NSMakeRect(16, y0, tileW, tileH)
               parent:blur];
  [self addToggleTile:@"Night Shift"
                 icon:@"🔆"
                frame:NSMakeRect(16 + tileW + 16, y0, tileW, tileH)
               parent:blur];

  // ── Display ──
  y0 -= 50;
  NSTextField *dispHeader = [self makeLabel:@"Display"
                                         at:NSMakePoint(16, y0)
                                       size:12
                                       bold:YES
                                     parent:blur];
  (void)dispHeader;
  y0 -= 28;
  self.brightnessSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(42, y0, panelW - 80, 20)];
  self.brightnessSlider.minValue = 0;
  self.brightnessSlider.maxValue = 100;
  self.brightnessSlider.doubleValue = 75;
  self.brightnessSlider.target = self;
  self.brightnessSlider.action = @selector(brightnessChanged);
  [blur addSubview:self.brightnessSlider];

  NSTextField *sunIcon = [self makeLabel:@"☀️"
                                      at:NSMakePoint(16, y0)
                                    size:16
                                    bold:NO
                                  parent:blur];
  (void)sunIcon;
  self.brightnessLabel = [self makeLabel:@"75%"
                                      at:NSMakePoint(panelW - 40, y0)
                                    size:11
                                    bold:NO
                                  parent:blur];

  // ── Sound ──
  y0 -= 40;
  NSTextField *sndHeader = [self makeLabel:@"Sound"
                                        at:NSMakePoint(16, y0)
                                      size:12
                                      bold:YES
                                    parent:blur];
  (void)sndHeader;
  y0 -= 28;
  self.volumeSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(42, y0, panelW - 80, 20)];
  self.volumeSlider.minValue = 0;
  self.volumeSlider.maxValue = 100;
  self.volumeSlider.doubleValue = 50;
  self.volumeSlider.target = self;
  self.volumeSlider.action = @selector(volumeChanged);
  [blur addSubview:self.volumeSlider];

  NSTextField *spkIcon = [self makeLabel:@"🔊"
                                      at:NSMakePoint(16, y0)
                                    size:16
                                    bold:NO
                                  parent:blur];
  (void)spkIcon;
  self.volumeLabel = [self makeLabel:@"50%"
                                  at:NSMakePoint(panelW - 40, y0)
                                size:11
                                bold:NO
                              parent:blur];

  // ── Now Playing ──
  y0 -= 50;
  NSView *nowPlaying =
      [[NSView alloc] initWithFrame:NSMakeRect(16, y0 - 60, panelW - 32, 65)];
  nowPlaying.wantsLayer = YES;
  nowPlaying.layer.cornerRadius = 10;
  nowPlaying.layer.backgroundColor =
      [[NSColor whiteColor] colorWithAlphaComponent:0.06].CGColor;
  [blur addSubview:nowPlaying];

  [self makeLabel:@"🎵"
               at:NSMakePoint(10, 36)
             size:22
             bold:NO
           parent:nowPlaying];
  [self makeLabel:@"Not Playing"
               at:NSMakePoint(42, 38)
             size:13
             bold:YES
           parent:nowPlaying];
  [self makeLabel:@"Open Music to start listening"
               at:NSMakePoint(42, 20)
             size:11
             bold:NO
           parent:nowPlaying];

  // Play controls
  NSButton *prevBtn =
      [self makeControlBtn:@"⏮"
                     frame:NSMakeRect(panelW / 2 - 85, 2, 30, 18)
                    parent:nowPlaying];
  NSButton *playBtn =
      [self makeControlBtn:@"▶️"
                     frame:NSMakeRect(panelW / 2 - 45, 2, 30, 18)
                    parent:nowPlaying];
  NSButton *nextBtn = [self makeControlBtn:@"⏭"
                                     frame:NSMakeRect(panelW / 2 - 5, 2, 30, 18)
                                    parent:nowPlaying];
  (void)prevBtn;
  (void)playBtn;
  (void)nextBtn;

  [self.panel makeKeyAndOrderFront:nil];
}

- (void)addToggleTile:(NSString *)name
                 icon:(NSString *)icon
                frame:(NSRect)frame
               parent:(NSView *)parent {
  BOOL isOn = [self.toggleStates[name] boolValue];

  NSView *tile = [[NSView alloc] initWithFrame:frame];
  tile.wantsLayer = YES;
  tile.layer.cornerRadius = 10;
  tile.layer.backgroundColor =
      isOn ? [[NSColor controlAccentColor] colorWithAlphaComponent:0.7].CGColor
           : [[NSColor whiteColor] colorWithAlphaComponent:0.08].CGColor;

  NSTextField *iconLbl =
      [[NSTextField alloc] initWithFrame:NSMakeRect(8, 20, 24, 20)];
  iconLbl.stringValue = icon;
  iconLbl.font = [NSFont systemFontOfSize:16];
  iconLbl.drawsBackground = NO;
  iconLbl.bezeled = NO;
  iconLbl.editable = NO;
  [tile addSubview:iconLbl];

  NSTextField *nameLbl = [[NSTextField alloc]
      initWithFrame:NSMakeRect(32, 22, frame.size.width - 40, 16)];
  nameLbl.stringValue = name;
  nameLbl.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
  nameLbl.textColor = [NSColor whiteColor];
  nameLbl.drawsBackground = NO;
  nameLbl.bezeled = NO;
  nameLbl.editable = NO;
  nameLbl.lineBreakMode = NSLineBreakByTruncatingTail;
  [tile addSubview:nameLbl];

  NSTextField *statusLbl = [[NSTextField alloc]
      initWithFrame:NSMakeRect(32, 6, frame.size.width - 40, 14)];
  statusLbl.stringValue = isOn ? @"On" : @"Off";
  statusLbl.font = [NSFont systemFontOfSize:10];
  statusLbl.textColor = [[NSColor whiteColor] colorWithAlphaComponent:0.6];
  statusLbl.drawsBackground = NO;
  statusLbl.bezeled = NO;
  statusLbl.editable = NO;
  [tile addSubview:statusLbl];

  // Click handler via button overlay
  NSButton *btn = [[NSButton alloc]
      initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
  btn.transparent = YES;
  btn.title = @"";
  btn.tag = [name hash];
  btn.target = self;
  btn.action = @selector(toggleClicked:);
  [tile addSubview:btn];

  [parent addSubview:tile];
}

- (void)toggleClicked:(NSButton *)sender {
  // Toggle state and rebuild
  for (NSString *key in self.toggleStates) {
    if ((NSInteger)[key hash] == sender.tag) {
      BOOL cur = [self.toggleStates[key] boolValue];
      self.toggleStates[key] = @(!cur);
      break;
    }
  }
  // Rebuild panel
  CGRect fr = self.panel.frame;
  [self.panel close];
  self.panel = nil;
  [self showWindow];
  [self.panel setFrame:fr display:YES];
}

- (void)brightnessChanged {
  self.brightnessLabel.stringValue =
      [NSString stringWithFormat:@"%.0f%%", self.brightnessSlider.doubleValue];
}
- (void)volumeChanged {
  self.volumeLabel.stringValue =
      [NSString stringWithFormat:@"%.0f%%", self.volumeSlider.doubleValue];
}

- (NSTextField *)makeLabel:(NSString *)text
                        at:(NSPoint)pt
                      size:(CGFloat)sz
                      bold:(BOOL)bold
                    parent:(NSView *)parent {
  NSTextField *l =
      [[NSTextField alloc] initWithFrame:NSMakeRect(pt.x, pt.y, 200, sz + 6)];
  l.stringValue = text;
  l.font = bold ? [NSFont systemFontOfSize:sz weight:NSFontWeightSemibold]
                : [NSFont systemFontOfSize:sz];
  l.textColor = [NSColor whiteColor];
  l.drawsBackground = NO;
  l.bezeled = NO;
  l.editable = NO;
  [parent addSubview:l];
  return l;
}

- (NSButton *)makeControlBtn:(NSString *)title
                       frame:(NSRect)fr
                      parent:(NSView *)parent {
  NSButton *b = [[NSButton alloc] initWithFrame:fr];
  b.title = title;
  b.bezelStyle = NSBezelStyleInline;
  b.font = [NSFont systemFontOfSize:12];
  [parent addSubview:b];
  return b;
}

@end
