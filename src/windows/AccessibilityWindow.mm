#import "AccessibilityWindow.h"

@interface AccessibilityWindow ()
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSTabView *tabView;
@property(nonatomic, strong) NSSlider *textSizeSlider, *contrastSlider,
    *cursorSizeSlider;
@property(nonatomic, strong) NSButton *voiceOverToggle, *zoomToggle,
    *invertColorsToggle;
@property(nonatomic, strong) NSButton *reduceMotionToggle,
    *reduceTransparencyToggle;
@property(nonatomic, strong) NSButton *stickyKeysToggle, *slowKeysToggle,
    *mouseKeysToggle;
@property(nonatomic, strong) NSButton *audioDescToggle, *monoAudioToggle,
    *flashScreenToggle;
@property(nonatomic, strong) NSColorWell *highlightColorWell;
@property(nonatomic, strong) NSTextField *previewText;
@end

@implementation AccessibilityWindow

+ (instancetype)sharedInstance {
  static AccessibilityWindow *inst;
  static dispatch_once_t t;
  dispatch_once(&t, ^{
    inst = [[self alloc] init];
  });
  return inst;
}

- (void)showWindow {
  if (self.window) {
    [self.window makeKeyAndOrderFront:nil];
    return;
  }

  self.window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(150, 100, 750, 580)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.window.title = @"Accessibility";
  self.window.backgroundColor = [NSColor colorWithRed:0.12
                                                green:0.12
                                                 blue:0.14
                                                alpha:1.0];

  NSView *content = self.window.contentView;

  // ===== Sidebar =====
  NSView *sidebar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, 580)];
  sidebar.wantsLayer = YES;
  sidebar.layer.backgroundColor =
      [NSColor controlBackgroundColor].CGColor;
  sidebar.autoresizingMask = NSViewHeightSizable;

  NSArray *categories = @[
    @[ @"👁️", @"Vision" ], @[ @"🔊", @"Hearing" ], @[ @"🖱️", @"Motor" ],
    @[ @"⌨️", @"Keyboard" ], @[ @"🗣️", @"Speech" ], @[ @"📖", @"Captions" ],
    @[ @"🎨", @"Display" ], @[ @"👆", @"Pointer" ],
    @[ @"🔗", @"Switch Control" ]
  ];

  CGFloat catY = 530;
  for (NSArray *cat in categories) {
    NSButton *btn =
        [[NSButton alloc] initWithFrame:NSMakeRect(10, catY, 180, 32)];
    btn.title = [NSString stringWithFormat:@" %@ %@", cat[0], cat[1]];
    btn.bezelStyle = NSBezelStyleRounded;
    btn.alignment = NSTextAlignmentLeft;
    btn.font = [NSFont systemFontOfSize:13];
    [sidebar addSubview:btn];
    catY -= 40;
  }
  [content addSubview:sidebar];

  // ===== Main Content Area =====
  self.tabView =
      [[NSTabView alloc] initWithFrame:NSMakeRect(200, 10, 540, 560)];
  self.tabView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.tabView.tabViewType = NSNoTabsNoBorder;

  NSTabViewItem *visionTab =
      [[NSTabViewItem alloc] initWithIdentifier:@"vision"];
  [self setupVisionTab:visionTab.view];
  [self.tabView addTabViewItem:visionTab];

  [content addSubview:self.tabView];
  [self.window makeKeyAndOrderFront:nil];
}

- (void)setupVisionTab:(NSView *)view {
  CGFloat y = 500;

  // Section: VoiceOver
  [view addSubview:[self sectionHeader:@"VoiceOver" y:y]];
  y -= 10;
  self.voiceOverToggle = [self toggleAt:NSMakePoint(20, y -= 35)
                                  label:@"Enable VoiceOver screen reader"];
  [view addSubview:self.voiceOverToggle];
  NSTextField *voDesc = [self descLabelAt:NSMakePoint(20, y -= 20)
                                     text:@"VoiceOver reads aloud what's on "
                                          @"screen. Press ⌘F5 to toggle."];
  [view addSubview:voDesc];

  // Section: Zoom
  [view addSubview:[self sectionHeader:@"Zoom" y:y -= 30]];
  y -= 10;
  self.zoomToggle = [self toggleAt:NSMakePoint(20, y -= 35)
                             label:@"Use keyboard shortcuts to zoom"];
  [view addSubview:self.zoomToggle];

  // Section: Display
  [view addSubview:[self sectionHeader:@"Display" y:y -= 30]];
  y -= 10;

  self.invertColorsToggle = [self toggleAt:NSMakePoint(20, y -= 35)
                                     label:@"Invert colors"];
  [view addSubview:self.invertColorsToggle];

  self.reduceMotionToggle = [self toggleAt:NSMakePoint(20, y -= 30)
                                     label:@"Reduce motion"];
  [view addSubview:self.reduceMotionToggle];

  self.reduceTransparencyToggle = [self toggleAt:NSMakePoint(20, y -= 30)
                                           label:@"Reduce transparency"];
  [view addSubview:self.reduceTransparencyToggle];

  // Text size slider
  NSTextField *textLabel = [self descLabelAt:NSMakePoint(20, y -= 30)
                                        text:@"Text Size:"];
  [view addSubview:textLabel];
  self.textSizeSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(100, y + 2, 300, 22)];
  self.textSizeSlider.minValue = 10;
  self.textSizeSlider.maxValue = 32;
  self.textSizeSlider.intValue = 13;
  self.textSizeSlider.target = self;
  self.textSizeSlider.action = @selector(textSizeChanged:);
  [view addSubview:self.textSizeSlider];

  // Contrast slider
  NSTextField *contrastLabel = [self descLabelAt:NSMakePoint(20, y -= 30)
                                            text:@"Contrast:"];
  [view addSubview:contrastLabel];
  self.contrastSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(100, y + 2, 300, 22)];
  self.contrastSlider.minValue = 0;
  self.contrastSlider.maxValue = 100;
  self.contrastSlider.intValue = 50;
  [view addSubview:self.contrastSlider];

  // Cursor size
  NSTextField *cursorLabel = [self descLabelAt:NSMakePoint(20, y -= 30)
                                          text:@"Cursor Size:"];
  [view addSubview:cursorLabel];
  self.cursorSizeSlider =
      [[NSSlider alloc] initWithFrame:NSMakeRect(100, y + 2, 300, 22)];
  self.cursorSizeSlider.minValue = 1;
  self.cursorSizeSlider.maxValue = 4;
  self.cursorSizeSlider.intValue = 1;
  [view addSubview:self.cursorSizeSlider];

  // Highlight color
  NSTextField *colorLabel = [self descLabelAt:NSMakePoint(20, y -= 35)
                                         text:@"Highlight Color:"];
  [view addSubview:colorLabel];
  self.highlightColorWell =
      [[NSColorWell alloc] initWithFrame:NSMakeRect(130, y, 40, 24)];
  self.highlightColorWell.color = [NSColor systemBlueColor];
  [view addSubview:self.highlightColorWell];

  // Keyboard shortcuts section
  [view addSubview:[self sectionHeader:@"Keyboard" y:y -= 35]];
  y -= 10;

  self.stickyKeysToggle = [self toggleAt:NSMakePoint(20, y -= 35)
                                   label:@"Enable Sticky Keys"];
  [view addSubview:self.stickyKeysToggle];

  self.slowKeysToggle = [self toggleAt:NSMakePoint(20, y -= 30)
                                 label:@"Enable Slow Keys"];
  [view addSubview:self.slowKeysToggle];

  // Audio section
  [view addSubview:[self sectionHeader:@"Audio" y:y -= 35]];
  y -= 10;

  self.monoAudioToggle =
      [self toggleAt:NSMakePoint(20, y -= 35)
               label:@"Mono audio (combine stereo channels)"];
  [view addSubview:self.monoAudioToggle];

  self.flashScreenToggle =
      [self toggleAt:NSMakePoint(20, y -= 30)
               label:@"Flash screen when alert sounds play"];
  [view addSubview:self.flashScreenToggle];

  // Preview area
  self.previewText =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 20, 490, 50)];
  self.previewText.stringValue =
      @"Preview: The quick brown fox jumps over the lazy dog. 0123456789";
  self.previewText.font = [NSFont systemFontOfSize:13];
  self.previewText.textColor = [NSColor whiteColor];
  self.previewText.editable = NO;
  self.previewText.bordered = YES;
  self.previewText.backgroundColor = [NSColor colorWithRed:0.2
                                                     green:0.2
                                                      blue:0.24
                                                     alpha:1.0];
  [view addSubview:self.previewText];
}

- (void)textSizeChanged:(NSSlider *)sender {
  self.previewText.font = [NSFont systemFontOfSize:sender.intValue];
}

// ===== Helpers =====

- (NSView *)sectionHeader:(NSString *)title y:(CGFloat)y {
  NSTextField *header =
      [[NSTextField alloc] initWithFrame:NSMakeRect(15, y, 490, 22)];
  header.stringValue = title;
  header.font = [NSFont systemFontOfSize:15 weight:NSFontWeightBold];
  header.textColor = [NSColor whiteColor];
  header.editable = NO;
  header.bordered = NO;
  header.drawsBackground = NO;
  return header;
}

- (NSButton *)toggleAt:(NSPoint)pt label:(NSString *)label {
  NSButton *toggle =
      [[NSButton alloc] initWithFrame:NSMakeRect(pt.x, pt.y, 490, 22)];
  toggle.title = label;
  [toggle setButtonType:NSButtonTypeSwitch];
  toggle.font = [NSFont systemFontOfSize:13];
  return toggle;
}

- (NSTextField *)descLabelAt:(NSPoint)pt text:(NSString *)text {
  NSTextField *tf =
      [[NSTextField alloc] initWithFrame:NSMakeRect(pt.x, pt.y, 490, 16)];
  tf.stringValue = text;
  tf.font = [NSFont systemFontOfSize:11];
  tf.textColor = [NSColor grayColor];
  tf.editable = NO;
  tf.bordered = NO;
  tf.drawsBackground = NO;
  return tf;
}

@end
