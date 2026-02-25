#import "SafariWindow.h"

@interface SafariWindow ()
@property(nonatomic, strong) NSWindow *safariWindow;
@property(nonatomic, strong) NSScrollView *contentScrollView;
@property(nonatomic, strong) NSView *pageView;
@property(nonatomic, strong) NSTextField *urlField;
@property(nonatomic, strong) NSProgressIndicator *progressIndicator;
@property(nonatomic, strong) NSButton *backBtn;
@property(nonatomic, strong) NSButton *forwardBtn;
@property(nonatomic, strong) NSMutableArray *history;
@property(nonatomic, assign) NSInteger historyIndex;
@property(nonatomic, strong) NSString *currentURL;
@end

@implementation SafariWindow

+ (instancetype)sharedInstance {
  static SafariWindow *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[SafariWindow alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.history = [NSMutableArray array];
    self.historyIndex = -1;
  }
  return self;
}

- (void)showWindow {
  if (self.safariWindow) {
    [self.safariWindow makeKeyAndOrderFront:nil];
    return;
  }

  NSRect frame = NSMakeRect(0, 0, 1024, 700);
  self.safariWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.safariWindow setTitle:@"Safari"];
  [self.safariWindow center];

  NSView *contentView = [[NSView alloc] initWithFrame:frame];
  contentView.wantsLayer = YES;
  contentView.layer.backgroundColor = [[NSColor colorWithRed:0.11
                                                       green:0.11
                                                        blue:0.13
                                                       alpha:1.0] CGColor];
  [self.safariWindow setContentView:contentView];

  // Toolbar with visual effect
  NSVisualEffectView *toolbar = [[NSVisualEffectView alloc]
      initWithFrame:NSMakeRect(0, frame.size.height - 52, frame.size.width,
                               52)];
  toolbar.material = NSVisualEffectMaterialTitlebar;
  toolbar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  toolbar.state = NSVisualEffectStateActive;
  toolbar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [contentView addSubview:toolbar];

  // Bottom border
  NSView *toolbarBorder =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, 1)];
  toolbarBorder.wantsLayer = YES;
  toolbarBorder.layer.backgroundColor = [[NSColor separatorColor] CGColor];
  toolbarBorder.autoresizingMask = NSViewWidthSizable;
  [toolbar addSubview:toolbarBorder];

  // Navigation buttons
  self.backBtn = [[NSButton alloc] initWithFrame:NSMakeRect(12, 10, 32, 32)];
  self.backBtn.title = @"◀";
  self.backBtn.bezelStyle = NSBezelStyleTexturedRounded;
  self.backBtn.target = self;
  self.backBtn.action = @selector(goBack:);
  self.backBtn.enabled = NO;
  [toolbar addSubview:self.backBtn];

  self.forwardBtn = [[NSButton alloc] initWithFrame:NSMakeRect(48, 10, 32, 32)];
  self.forwardBtn.title = @"▶";
  self.forwardBtn.bezelStyle = NSBezelStyleTexturedRounded;
  self.forwardBtn.target = self;
  self.forwardBtn.action = @selector(goForward:);
  self.forwardBtn.enabled = NO;
  [toolbar addSubview:self.forwardBtn];

  NSButton *refreshBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(84, 10, 32, 32)];
  refreshBtn.title = @"↻";
  refreshBtn.bezelStyle = NSBezelStyleTexturedRounded;
  refreshBtn.target = self;
  refreshBtn.action = @selector(refresh:);
  [toolbar addSubview:refreshBtn];

  // URL field
  self.urlField = [[NSTextField alloc]
      initWithFrame:NSMakeRect(124, 12, frame.size.width - 180, 28)];
  self.urlField.placeholderString = @"Enter URL or search...";
  self.urlField.font = [NSFont systemFontOfSize:14];
  self.urlField.bezeled = YES;
  self.urlField.bezelStyle = NSTextFieldRoundedBezel;
  self.urlField.target = self;
  self.urlField.action = @selector(urlFieldSubmitted:);
  self.urlField.autoresizingMask = NSViewWidthSizable;
  [toolbar addSubview:self.urlField];

  // Progress indicator
  self.progressIndicator = [[NSProgressIndicator alloc]
      initWithFrame:NSMakeRect(0, 0, frame.size.width, 2)];
  self.progressIndicator.style = NSProgressIndicatorStyleBar;
  self.progressIndicator.indeterminate = YES;
  self.progressIndicator.hidden = YES;
  self.progressIndicator.autoresizingMask = NSViewWidthSizable;
  [toolbar addSubview:self.progressIndicator];

  // Content scroll view (simulated browser)
  self.contentScrollView = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height - 52)];
  self.contentScrollView.hasVerticalScroller = YES;
  self.contentScrollView.autoresizingMask =
      NSViewWidthSizable | NSViewHeightSizable;
  [contentView addSubview:self.contentScrollView];

  self.pageView =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, 800)];
  self.pageView.wantsLayer = YES;
  self.pageView.layer.backgroundColor = [[NSColor colorWithRed:0.14
                                                         green:0.14
                                                          blue:0.16
                                                         alpha:1.0] CGColor];
  self.contentScrollView.documentView = self.pageView;

  // Load default page
  [self loadURL:@"virtualos://home"];

  [self.safariWindow makeKeyAndOrderFront:nil];
}

- (void)loadURL:(NSString *)urlString {
  self.progressIndicator.hidden = NO;
  [self.progressIndicator startAnimation:nil];

  // Normalize URL
  NSString *normalizedURL = urlString;
  if (![urlString hasPrefix:@"virtualos://"] &&
      ![urlString hasPrefix:@"http://"] && ![urlString hasPrefix:@"https://"]) {
    if ([urlString containsString:@"."]) {
      normalizedURL = [@"https://" stringByAppendingString:urlString];
    } else {
      normalizedURL =
          [NSString stringWithFormat:@"virtualos://search?q=%@", urlString];
    }
  }

  self.currentURL = normalizedURL;
  self.urlField.stringValue = normalizedURL;

  // Add to history
  if (self.historyIndex < (NSInteger)self.history.count - 1) {
    [self.history removeObjectsInRange:NSMakeRange(self.historyIndex + 1,
                                                   self.history.count -
                                                       self.historyIndex - 1)];
  }
  [self.history addObject:normalizedURL];
  self.historyIndex = self.history.count - 1;

  // Simulate page load
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        [self renderPage:normalizedURL];
        self.progressIndicator.hidden = YES;
        [self.progressIndicator stopAnimation:nil];
        [self updateNavigationButtons];
      });
}

- (void)renderPage:(NSString *)url {
  // Clear existing content
  for (NSView *subview in [self.pageView.subviews copy]) {
    [subview removeFromSuperview];
  }

  CGFloat width = self.contentScrollView.bounds.size.width;
  CGFloat y = 750;

  if ([url isEqualToString:@"virtualos://home"] ||
      [url hasPrefix:@"https://www.apple.com"]) {
    [self renderHomePage:&y width:width];
    [self.safariWindow setTitle:@"Safari - VirtualOS Home"];
  } else if ([url hasPrefix:@"virtualos://search"] ||
             [url hasPrefix:@"https://www.google.com"]) {
    NSString *query = @"";
    if ([url containsString:@"q="]) {
      NSRange range = [url rangeOfString:@"q="];
      query = [[url substringFromIndex:range.location + 2]
          stringByRemovingPercentEncoding];
    }
    [self renderSearchPage:query y:&y width:width];
    [self.safariWindow
        setTitle:[NSString stringWithFormat:@"Safari - Search: %@", query]];
  } else if ([url containsString:@"wikipedia"]) {
    [self renderWikipediaPage:&y width:width];
    [self.safariWindow setTitle:@"Safari - Wikipedia"];
  } else if ([url containsString:@"news"]) {
    [self renderNewsPage:&y width:width];
    [self.safariWindow setTitle:@"Safari - Virtual News"];
  } else {
    [self renderGenericPage:url y:&y width:width];
    [self.safariWindow
        setTitle:[NSString stringWithFormat:@"Safari - %@", url]];
  }

  // Adjust page view height
  [self.pageView setFrameSize:NSMakeSize(width, 800 - y + 50)];
}

- (void)renderHomePage:(CGFloat *)y width:(CGFloat)width {
  // Header
  NSTextField *header = [self createLabel:@"🌐 VirtualOS Browser"
                                 fontSize:32
                                     bold:YES];
  header.frame = NSMakeRect(50, *y - 50, width - 100, 40);
  header.alignment = NSTextAlignmentCenter;
  [self.pageView addSubview:header];
  *y -= 80;

  NSTextField *subtitle =
      [self createLabel:@"Welcome to the simulated browsing experience"
               fontSize:16
                   bold:NO];
  subtitle.textColor = [NSColor grayColor];
  subtitle.frame = NSMakeRect(50, *y - 25, width - 100, 25);
  subtitle.alignment = NSTextAlignmentCenter;
  [self.pageView addSubview:subtitle];
  *y -= 60;

  // Quick links
  NSArray *quickLinks = @[
    @{@"title" : @"📰 Virtual News", @"url" : @"virtualos://news"},
    @{@"title" : @"📖 Encyclopedia", @"url" : @"virtualos://wikipedia"},
    @{@"title" : @"🔍 Search", @"url" : @"virtualos://search"},
    @{@"title" : @"💻 About VirtualOS", @"url" : @"virtualos://about"}
  ];

  CGFloat linkWidth = 200;
  CGFloat startX = (width - (linkWidth * 2 + 40)) / 2;

  for (NSUInteger i = 0; i < quickLinks.count; i++) {
    NSDictionary *link = quickLinks[i];
    CGFloat x = startX + (i % 2) * (linkWidth + 20);
    CGFloat linkY = *y - (i / 2) * 80;

    NSButton *btn = [[NSButton alloc]
        initWithFrame:NSMakeRect(x, linkY - 60, linkWidth, 60)];
    btn.title = link[@"title"];
    btn.bezelStyle = NSBezelStyleTexturedSquare;
    btn.font = [NSFont systemFontOfSize:16];
    btn.target = self;
    btn.action = @selector(quickLinkClicked:);
    btn.tag = i;
    [self.pageView addSubview:btn];
  }
  *y -= 200;

  // Info text
  NSTextField *info =
      [self createLabel:@"This browser operates in a sandboxed "
                        @"environment.\nNo real network connections are made."
               fontSize:14
                   bold:NO];
  info.textColor = [NSColor grayColor];
  info.frame = NSMakeRect(50, *y - 50, width - 100, 50);
  info.alignment = NSTextAlignmentCenter;
  [self.pageView addSubview:info];
}

- (void)renderSearchPage:(NSString *)query y:(CGFloat *)y width:(CGFloat)width {
  // Search header
  NSTextField *header = [self createLabel:@"🔍 VirtualOS Search"
                                 fontSize:28
                                     bold:YES];
  header.frame = NSMakeRect(50, *y - 40, width - 100, 35);
  [self.pageView addSubview:header];
  *y -= 60;

  NSTextField *queryLabel = [self
      createLabel:[NSString stringWithFormat:@"Results for: \"%@\"", query]
         fontSize:14
             bold:NO];
  queryLabel.textColor = [NSColor grayColor];
  queryLabel.frame = NSMakeRect(50, *y - 20, width - 100, 20);
  [self.pageView addSubview:queryLabel];
  *y -= 50;

  // Simulated search results
  NSArray *results = @[
    @{
      @"title" :
          [NSString stringWithFormat:@"%@ - VirtualOS Encyclopedia", query],
      @"desc" : @"Learn about this topic in our virtual encyclopedia."
    },
    @{
      @"title" : [NSString stringWithFormat:@"Understanding %@", query],
      @"desc" : @"A comprehensive guide to this subject matter."
    },
    @{
      @"title" : [NSString stringWithFormat:@"%@ News and Updates", query],
      @"desc" : @"Latest simulated news about this topic."
    },
    @{
      @"title" : [NSString stringWithFormat:@"How to use %@", query],
      @"desc" : @"Tutorial and documentation for virtual users."
    }
  ];

  for (NSDictionary *result in results) {
    NSTextField *title = [self createLabel:result[@"title"]
                                  fontSize:18
                                      bold:NO];
    title.textColor = [NSColor systemBlueColor];
    title.frame = NSMakeRect(50, *y - 25, width - 100, 25);
    [self.pageView addSubview:title];
    *y -= 30;

    NSTextField *desc = [self createLabel:result[@"desc"] fontSize:13 bold:NO];
    desc.textColor = [NSColor darkGrayColor];
    desc.frame = NSMakeRect(50, *y - 20, width - 100, 20);
    [self.pageView addSubview:desc];
    *y -= 50;
  }
}

- (void)renderWikipediaPage:(CGFloat *)y width:(CGFloat)width {
  NSTextField *header = [self createLabel:@"📖 VirtualOS Encyclopedia"
                                 fontSize:28
                                     bold:YES];
  header.frame = NSMakeRect(50, *y - 40, width - 100, 35);
  [self.pageView addSubview:header];
  *y -= 70;

  NSString *content =
      @"Welcome to the VirtualOS Encyclopedia, your source for simulated "
      @"knowledge.\n\n"
      @"VirtualOS is a demonstration operating system environment that "
      @"showcases UI concepts "
      @"and system design principles. It runs in a sandboxed environment, "
      @"completely isolated "
      @"from the host system.\n\n"
      @"Features:\n• Simulated file system\n• Virtual networking\n• "
      @"Application windows\n• System utilities\n\n"
      @"This encyclopedia contains virtual articles for demonstration purposes "
      @"only.";

  NSTextField *body = [self createLabel:content fontSize:14 bold:NO];
  body.frame = NSMakeRect(50, *y - 250, width - 100, 250);
  [self.pageView addSubview:body];
}

- (void)renderNewsPage:(CGFloat *)y width:(CGFloat)width {
  NSTextField *header = [self createLabel:@"📰 Virtual News Network"
                                 fontSize:28
                                     bold:YES];
  header.frame = NSMakeRect(50, *y - 40, width - 100, 35);
  [self.pageView addSubview:header];
  *y -= 70;

  NSArray *news = @[
    @{
      @"headline" : @"VirtualOS 2.0 Released with New Features",
      @"time" : @"2 hours ago"
    },
    @{
      @"headline" : @"Simulated Weather: Sunny with Virtual Clouds",
      @"time" : @"4 hours ago"
    },
    @{
      @"headline" : @"Virtual Stock Market Reaches New Highs",
      @"time" : @"6 hours ago"
    },
    @{
      @"headline" : @"Scientists Discover New Virtual Planet",
      @"time" : @"Yesterday"
    }
  ];

  for (NSDictionary *article in news) {
    NSTextField *headline = [self createLabel:article[@"headline"]
                                     fontSize:18
                                         bold:YES];
    headline.frame = NSMakeRect(50, *y - 25, width - 100, 25);
    [self.pageView addSubview:headline];
    *y -= 30;

    NSTextField *time = [self createLabel:article[@"time"] fontSize:12 bold:NO];
    time.textColor = [NSColor grayColor];
    time.frame = NSMakeRect(50, *y - 18, width - 100, 18);
    [self.pageView addSubview:time];
    *y -= 45;
  }
}

- (void)renderGenericPage:(NSString *)url y:(CGFloat *)y width:(CGFloat)width {
  NSTextField *header = [self createLabel:@"🌐 Virtual Page"
                                 fontSize:28
                                     bold:YES];
  header.frame = NSMakeRect(50, *y - 40, width - 100, 35);
  [self.pageView addSubview:header];
  *y -= 70;

  NSString *message = [NSString
      stringWithFormat:@"You are viewing a simulated page for:\n%@\n\n"
                       @"This browser operates in sandbox mode and does not "
                       @"make real network connections.\n\n"
                       @"Try visiting:\n• virtualos://home\n• "
                       @"virtualos://news\n• virtualos://wikipedia",
                       url];

  NSTextField *body = [self createLabel:message fontSize:14 bold:NO];
  body.frame = NSMakeRect(50, *y - 150, width - 100, 150);
  [self.pageView addSubview:body];
}

- (NSTextField *)createLabel:(NSString *)text
                    fontSize:(CGFloat)size
                        bold:(BOOL)bold {
  NSTextField *label = [[NSTextField alloc] init];
  label.stringValue = text;
  label.font = bold ? [NSFont boldSystemFontOfSize:size]
                    : [NSFont systemFontOfSize:size];
  label.bezeled = NO;
  label.editable = NO;
  label.drawsBackground = NO;
  label.selectable = NO;
  return label;
}

- (void)quickLinkClicked:(NSButton *)sender {
  NSArray *urls = @[
    @"virtualos://news", @"virtualos://wikipedia",
    @"virtualos://search?q=VirtualOS", @"virtualos://about"
  ];
  if (sender.tag < (NSInteger)urls.count) {
    [self loadURL:urls[sender.tag]];
  }
}

- (void)updateNavigationButtons {
  self.backBtn.enabled = self.historyIndex > 0;
  self.forwardBtn.enabled =
      self.historyIndex < (NSInteger)self.history.count - 1;
}

#pragma mark - Actions

- (void)goBack:(id)sender {
  if (self.historyIndex > 0) {
    self.historyIndex--;
    NSString *url = self.history[self.historyIndex];
    self.currentURL = url;
    self.urlField.stringValue = url;
    [self renderPage:url];
    [self updateNavigationButtons];
  }
}

- (void)goForward:(id)sender {
  if (self.historyIndex < (NSInteger)self.history.count - 1) {
    self.historyIndex++;
    NSString *url = self.history[self.historyIndex];
    self.currentURL = url;
    self.urlField.stringValue = url;
    [self renderPage:url];
    [self updateNavigationButtons];
  }
}

- (void)refresh:(id)sender {
  if (self.currentURL) {
    [self renderPage:self.currentURL];
  }
}

- (void)urlFieldSubmitted:(id)sender {
  [self loadURL:self.urlField.stringValue];
}

@end
