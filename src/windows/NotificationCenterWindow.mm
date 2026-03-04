#import "NotificationCenterWindow.h"
#import <QuartzCore/QuartzCore.h>

@interface NCNotification : NSObject
@property(nonatomic, strong) NSString *title;
@property(nonatomic, strong) NSString *body;
@property(nonatomic, strong) NSString *icon;
@property(nonatomic, strong) NSString *appName;
@property(nonatomic, strong) NSDate *timestamp;
@end
@implementation NCNotification
@end

@interface NotificationCenterWindow ()
@property(nonatomic, strong) NSWindow *panel;
@property(nonatomic, strong) NSMutableArray<NCNotification *> *notifications;
@property(nonatomic, strong) NSScrollView *scrollView;
@property(nonatomic, strong) NSView *contentContainer;
@property(nonatomic, strong) NSTimer *clockTimer;
@property(nonatomic, strong) NSTextField *clockLabel;
@property(nonatomic, strong) NSTextField *dateLabel;
@end

@implementation NotificationCenterWindow

+ (instancetype)sharedInstance {
  static NotificationCenterWindow *inst;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    inst = [[NotificationCenterWindow alloc] init];
  });
  return inst;
}

- (instancetype)init {
  if (self = [super init]) {
    _notifications = [NSMutableArray array];
    [self generateNotifications];
  }
  return self;
}

- (void)toggle {
  if (self.panel && self.panel.isVisible) {
    [self.panel orderOut:nil];
    [self.clockTimer invalidate];
    self.clockTimer = nil;
  } else {
    [self showWindow];
  }
}

- (void)showWindow {
  if (self.panel) {
    [self refreshContent];
    [self.panel makeKeyAndOrderFront:nil];
    [self startClock];
    return;
  }

  NSScreen *screen = [NSScreen mainScreen];
  CGFloat panelW = 360, panelH = screen.frame.size.height - 50;
  CGFloat x = screen.frame.size.width - panelW - 8;
  CGFloat y = 30;

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

  // Clock
  self.clockLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(20, panelH - 60, panelW - 40, 40)];
  self.clockLabel.font =
      [NSFont monospacedDigitSystemFontOfSize:36 weight:NSFontWeightLight];
  self.clockLabel.textColor = [NSColor whiteColor];
  self.clockLabel.drawsBackground = NO;
  self.clockLabel.bezeled = NO;
  self.clockLabel.editable = NO;
  [blur addSubview:self.clockLabel];

  self.dateLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(20, panelH - 82, panelW - 40, 18)];
  self.dateLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  self.dateLabel.textColor = [[NSColor whiteColor] colorWithAlphaComponent:0.6];
  self.dateLabel.drawsBackground = NO;
  self.dateLabel.bezeled = NO;
  self.dateLabel.editable = NO;
  [blur addSubview:self.dateLabel];

  // Separator
  NSBox *sep =
      [[NSBox alloc] initWithFrame:NSMakeRect(16, panelH - 90, panelW - 32, 1)];
  sep.boxType = NSBoxSeparator;
  [blur addSubview:sep];

  // Calendar widget
  NSDatePicker *cal = [[NSDatePicker alloc]
      initWithFrame:NSMakeRect(16, panelH - 260, panelW - 32, 160)];
  cal.datePickerStyle = NSDatePickerStyleClockAndCalendar;
  cal.datePickerElements = NSDatePickerElementFlagYearMonthDay;
  cal.drawsBackground = NO;
  cal.bezeled = NO;
  cal.dateValue = [NSDate date];
  [blur addSubview:cal];

  // Separator 2
  NSBox *sep2 = [[NSBox alloc]
      initWithFrame:NSMakeRect(16, panelH - 270, panelW - 32, 1)];
  sep2.boxType = NSBoxSeparator;
  [blur addSubview:sep2];

  // Notifications header
  NSTextField *notifHeader =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, panelH - 295, 200, 18)];
  notifHeader.stringValue = @"Notifications";
  notifHeader.font = [NSFont systemFontOfSize:14 weight:NSFontWeightBold];
  notifHeader.textColor = [NSColor whiteColor];
  notifHeader.drawsBackground = NO;
  notifHeader.bezeled = NO;
  notifHeader.editable = NO;
  [blur addSubview:notifHeader];

  // Clear all button
  NSButton *clearBtn = [[NSButton alloc]
      initWithFrame:NSMakeRect(panelW - 90, panelH - 295, 70, 20)];
  clearBtn.title = @"Clear All";
  clearBtn.bezelStyle = NSBezelStyleInline;
  clearBtn.font = [NSFont systemFontOfSize:11];
  clearBtn.target = self;
  clearBtn.action = @selector(clearAll);
  [blur addSubview:clearBtn];

  // Scroll area for notifications
  self.scrollView = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 0, panelW, panelH - 305)];
  self.scrollView.hasVerticalScroller = YES;
  self.scrollView.drawsBackground = NO;
  [blur addSubview:self.scrollView];

  self.contentContainer =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, panelW, panelH - 305)];
  self.scrollView.documentView = self.contentContainer;

  [self refreshContent];
  [self.panel makeKeyAndOrderFront:nil];
  [self startClock];
}

- (void)startClock {
  [self updateClock];
  self.clockTimer =
      [NSTimer scheduledTimerWithTimeInterval:1.0
                                       target:self
                                     selector:@selector(updateClock)
                                     userInfo:nil
                                      repeats:YES];
}

- (void)updateClock {
  NSDateFormatter *timeFmt = [[NSDateFormatter alloc] init];
  timeFmt.dateFormat = @"h:mm:ss a";
  self.clockLabel.stringValue = [timeFmt stringFromDate:[NSDate date]];

  NSDateFormatter *dateFmt = [[NSDateFormatter alloc] init];
  dateFmt.dateFormat = @"EEEE, MMMM d";
  self.dateLabel.stringValue = [dateFmt stringFromDate:[NSDate date]];
}

- (void)generateNotifications {
  NSArray *samples = @[
    @[
      @"System Update", @"A new software update is available for your Mac.",
      @"⚙️", @"Software Update"
    ],
    @[ @"Mail", @"You have 3 new messages in your inbox.", @"✉️", @"Mail" ],
    @[
      @"Calendar", @"Team standup meeting in 15 minutes.", @"📅", @"Calendar"
    ],
    @[ @"Safari", @"Download complete: project-files.zip", @"🧭", @"Safari" ],
    @[
      @"Messages", @"New message from Alex: Hey, how's the project going?",
      @"💬", @"Messages"
    ],
    @[
      @"Security", @"Your firewall is active and protecting your Mac.", @"🔒",
      @"Security"
    ],
    @[ @"Finder", @"File copy to Desktop complete.", @"📁", @"Finder" ],
    @[
      @"Music", @"Now Playing: Blinding Lights — The Weeknd", @"🎵", @"Music"
    ],
    @[ @"Photos", @"3 new photos added to your library.", @"🖼", @"Photos" ],
    @[ @"Terminal", @"Build succeeded with 0 errors.", @"⬛", @"Terminal" ],
  ];

  [self.notifications removeAllObjects];
  for (NSArray *s in samples) {
    NCNotification *n = [NCNotification new];
    n.title = s[0];
    n.body = s[1];
    n.icon = s[2];
    n.appName = s[3];
    n.timestamp =
        [NSDate dateWithTimeIntervalSinceNow:-arc4random_uniform(7200)];
    [self.notifications addObject:n];
  }
}

- (void)refreshContent {
  for (NSView *v in [self.contentContainer.subviews copy])
    [v removeFromSuperview];

  CGFloat panelW = 360;
  CGFloat y = self.notifications.count * 85;
  self.contentContainer.frame =
      NSMakeRect(0, 0, panelW, MAX(y, self.scrollView.bounds.size.height));

  CGFloat cy = y - 80;
  NSDateFormatter *relFmt = [[NSDateFormatter alloc] init];
  relFmt.dateStyle = NSDateFormatterNoStyle;
  relFmt.timeStyle = NSDateFormatterShortStyle;

  for (NCNotification *n in self.notifications) {
    NSView *card =
        [[NSView alloc] initWithFrame:NSMakeRect(12, cy, panelW - 24, 75)];
    card.wantsLayer = YES;
    card.layer.cornerRadius = 10;
    card.layer.backgroundColor =
        [[NSColor whiteColor] colorWithAlphaComponent:0.08].CGColor;

    // Icon
    NSTextField *icon =
        [[NSTextField alloc] initWithFrame:NSMakeRect(10, 44, 28, 24)];
    icon.stringValue = n.icon;
    icon.font = [NSFont systemFontOfSize:20];
    icon.drawsBackground = NO;
    icon.bezeled = NO;
    icon.editable = NO;
    [card addSubview:icon];

    // App name + time
    NSTextField *appLbl =
        [[NSTextField alloc] initWithFrame:NSMakeRect(42, 50, 150, 16)];
    appLbl.stringValue =
        [NSString stringWithFormat:@"%@ · %@", n.appName,
                                   [relFmt stringFromDate:n.timestamp]];
    appLbl.font = [NSFont systemFontOfSize:10 weight:NSFontWeightMedium];
    appLbl.textColor = [[NSColor whiteColor] colorWithAlphaComponent:0.45];
    appLbl.drawsBackground = NO;
    appLbl.bezeled = NO;
    appLbl.editable = NO;
    [card addSubview:appLbl];

    // Title
    NSTextField *titleLbl =
        [[NSTextField alloc] initWithFrame:NSMakeRect(12, 32, panelW - 50, 16)];
    titleLbl.stringValue = n.title;
    titleLbl.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    titleLbl.textColor = [NSColor whiteColor];
    titleLbl.drawsBackground = NO;
    titleLbl.bezeled = NO;
    titleLbl.editable = NO;
    [card addSubview:titleLbl];

    // Body
    NSTextField *bodyLbl =
        [[NSTextField alloc] initWithFrame:NSMakeRect(12, 6, panelW - 50, 26)];
    bodyLbl.stringValue = n.body;
    bodyLbl.font = [NSFont systemFontOfSize:11];
    bodyLbl.textColor = [[NSColor whiteColor] colorWithAlphaComponent:0.7];
    bodyLbl.drawsBackground = NO;
    bodyLbl.bezeled = NO;
    bodyLbl.editable = NO;
    bodyLbl.lineBreakMode = NSLineBreakByTruncatingTail;
    bodyLbl.maximumNumberOfLines = 2;
    [card addSubview:bodyLbl];

    [self.contentContainer addSubview:card];
    cy -= 85;
  }
}

- (void)clearAll {
  [self.notifications removeAllObjects];
  [self refreshContent];
}

@end
