#import "SafariWindow.h"
#import <QuartzCore/QuartzCore.h>

#define SAFARI_BG [NSColor windowBackgroundColor]
#define SAFARI_TOOLBAR_BG [NSColor controlBackgroundColor]
#define SAFARI_TAB_INACTIVE [NSColor underPageBackgroundColor]
#define SAFARI_TAB_ACTIVE [NSColor controlBackgroundColor]
#define SAFARI_TEXT_PRIMARY [NSColor labelColor]
#define SAFARI_TEXT_SECONDARY [NSColor secondaryLabelColor]
#define SAFARI_ACCENT [NSColor systemBlueColor]
#define SAFARI_BORDER [NSColor separatorColor]

@interface SafariVirtualTab : NSObject
@property(nonatomic, strong) NSString *title;
@property(nonatomic, strong) NSString *url;
@property(nonatomic, assign) BOOL isLoading;
@property(nonatomic, assign) BOOL isSecure;
@property(nonatomic, assign) double progress;
@property(nonatomic, strong) NSImage *favicon;
@property(nonatomic, strong) NSMutableArray<NSString *> *history;
@property(nonatomic, assign) NSInteger historyIndex;
@end

@implementation SafariVirtualTab
- (instancetype)init {
  if (self = [super init]) {
    _history = [NSMutableArray array];
    _historyIndex = -1;
    _isLoading = NO;
    _isSecure = YES;
    _progress = 0.0;
  }
  return self;
}
@end

@interface SafariWindow () <NSTextFieldDelegate>

@property(nonatomic, strong) NSWindow *safariWindow;
@property(nonatomic, strong) NSVisualEffectView *titlebarEffectView;
@property(nonatomic, strong) NSView *tabContainerView;
@property(nonatomic, strong) NSView *toolbarView;
@property(nonatomic, strong) NSView *bookmarkBarView;
@property(nonatomic, strong) NSScrollView *pageScrollView;
@property(nonatomic, strong) NSView *pageContainer;
@property(nonatomic, strong) WKWebView *realWebView;

@property(nonatomic, strong) NSTextField *urlField;
@property(nonatomic, strong) NSButton *backBtn;
@property(nonatomic, strong) NSButton *forwardBtn;
@property(nonatomic, strong) NSButton *refreshBtn;
@property(nonatomic, strong) NSButton *shareBtn;
@property(nonatomic, strong) NSButton *createTabBtn;
@property(nonatomic, strong) NSProgressIndicator *progressIndicator;

@property(nonatomic, strong) NSMutableArray<SafariVirtualTab *> *tabs;
@property(nonatomic, assign) NSInteger activeTabIndex;
@property(nonatomic, strong) NSMutableArray<NSView *> *tabViews;

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
    _tabs = [NSMutableArray array];
    _tabViews = [NSMutableArray array];

    SafariVirtualTab *initialTab = [[SafariVirtualTab alloc] init];
    initialTab.title = @"VirtualOS Start Page";
    initialTab.url = @"virtualos://home";
    [_tabs addObject:initialTab];
    _activeTabIndex = 0;
  }
  return self;
}

- (void)showWindow {
  if (self.safariWindow) {
    [self.safariWindow makeKeyAndOrderFront:nil];
    return;
  }

  NSRect screenRect = [[NSScreen mainScreen] visibleFrame];
  NSRect frame =
      NSMakeRect(NSMidX(screenRect) - 600, NSMidY(screenRect) - 400, 1200, 800);

  self.safariWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable |
                          NSWindowStyleMaskFullSizeContentView
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.safariWindow setTitle:@"Safari"];
  self.safariWindow.releasedWhenClosed = NO;
  self.safariWindow.titlebarAppearsTransparent = YES;
  self.safariWindow.titleVisibility = NSWindowTitleHidden;
  self.safariWindow.minSize = NSMakeSize(800, 500);

  NSView *root = [[NSView alloc] initWithFrame:frame];
  root.wantsLayer = YES;
  root.layer.backgroundColor = [SAFARI_BG CGColor];
  [self.safariWindow setContentView:root];

  [self buildupTopBar:root frame:frame];
  [self buildupPageArea:root frame:frame];

  [self renderTabs];
  [self loadURL:self.tabs[self.activeTabIndex].url];

  [self.safariWindow makeKeyAndOrderFront:nil];
}

#pragma mark - UI Building

- (void)buildupTopBar:(NSView *)root frame:(NSRect)frame {
  CGFloat topBarHeight = 110;

  self.titlebarEffectView = [[NSVisualEffectView alloc]
      initWithFrame:NSMakeRect(0, frame.size.height - topBarHeight,
                               frame.size.width, topBarHeight)];
  self.titlebarEffectView.material = NSVisualEffectMaterialTitlebar;
  self.titlebarEffectView.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  self.titlebarEffectView.state = NSVisualEffectStateFollowsWindowActiveState;
  self.titlebarEffectView.autoresizingMask =
      NSViewWidthSizable | NSViewMinYMargin;
  [root addSubview:self.titlebarEffectView];

  CGFloat y = topBarHeight - 1;
  NSView *titleDivider =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, 1)];
  titleDivider.wantsLayer = YES;
  titleDivider.layer.backgroundColor = [SAFARI_BORDER CGColor];
  titleDivider.autoresizingMask = NSViewWidthSizable;
  [self.titlebarEffectView addSubview:titleDivider];

  // Tab Container
  self.tabContainerView = [[NSView alloc]
      initWithFrame:NSMakeRect(70, y - 36, frame.size.width - 120, 36)];
  self.tabContainerView.autoresizingMask =
      NSViewWidthSizable | NSViewMinYMargin;
  [self.titlebarEffectView addSubview:self.tabContainerView];

  // New Tab Button
  self.createTabBtn = [[NSButton alloc]
      initWithFrame:NSMakeRect(frame.size.width - 45, y - 30, 24, 24)];
  self.createTabBtn.title = @"➕";
  self.createTabBtn.bezelStyle = NSBezelStyleInline;
  self.createTabBtn.bordered = NO;
  self.createTabBtn.target = self;
  self.createTabBtn.action = @selector(createNewTab);
  self.createTabBtn.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
  [self.titlebarEffectView addSubview:self.createTabBtn];

  y -= 36;
  NSView *tabSeparator =
      [[NSView alloc] initWithFrame:NSMakeRect(0, y, frame.size.width, 1)];
  tabSeparator.wantsLayer = YES;
  tabSeparator.layer.backgroundColor = [SAFARI_BORDER CGColor];
  tabSeparator.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [self.titlebarEffectView addSubview:tabSeparator];

  // Toolbar
  self.toolbarView = [[NSView alloc]
      initWithFrame:NSMakeRect(0, y - 44, frame.size.width, 44)];
  self.toolbarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [self.titlebarEffectView addSubview:self.toolbarView];

  self.backBtn = [self createToolbarButton:@"􀯶"
                                     frame:NSMakeRect(15, 10, 26, 26)
                                    action:@selector(goBack)];
  self.forwardBtn = [self createToolbarButton:@"􀯷"
                                        frame:NSMakeRect(45, 10, 26, 26)
                                       action:@selector(goForward)];
  [self.toolbarView addSubview:self.backBtn];
  [self.toolbarView addSubview:self.forwardBtn];

  // URL Field
  CGFloat urlW = frame.size.width - 200;
  self.urlField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(80, 8, urlW, 28)];
  self.urlField.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  self.urlField.textColor = SAFARI_TEXT_PRIMARY;
  self.urlField.bezeled = NO;
  self.urlField.drawsBackground = NO;
  self.urlField.delegate = self;
  self.urlField.placeholderString = @"Search or enter website name";
  self.urlField.autoresizingMask = NSViewWidthSizable;

  NSView *urlBg = [[NSView alloc] initWithFrame:NSMakeRect(80, 8, urlW, 28)];
  urlBg.wantsLayer = YES;
  urlBg.layer.backgroundColor = [[NSColor controlBackgroundColor] CGColor];
  urlBg.layer.cornerRadius = 6;
  urlBg.autoresizingMask = NSViewWidthSizable;
  [self.toolbarView addSubview:urlBg];
  [self.toolbarView addSubview:self.urlField];

  self.progressIndicator =
      [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(80, 8, urlW, 2)];
  self.progressIndicator.style = NSProgressIndicatorStyleBar;
  self.progressIndicator.controlSize = NSControlSizeSmall;
  self.progressIndicator.autoresizingMask = NSViewWidthSizable;
  self.progressIndicator.hidden = YES;
  [self.toolbarView addSubview:self.progressIndicator];

  self.refreshBtn =
      [self createToolbarButton:@"􀅈"
                          frame:NSMakeRect(80 + urlW + 10, 10, 26, 26)
                         action:@selector(reloadSelectedTab)];
  self.refreshBtn.autoresizingMask = NSViewMinXMargin;
  [self.toolbarView addSubview:self.refreshBtn];

  self.shareBtn =
      [self createToolbarButton:@"􀈂"
                          frame:NSMakeRect(80 + urlW + 45, 10, 26, 26)
                         action:nil];
  self.shareBtn.autoresizingMask = NSViewMinXMargin;
  [self.toolbarView addSubview:self.shareBtn];

  y -= 44;
  NSView *toolSeparator =
      [[NSView alloc] initWithFrame:NSMakeRect(0, y, frame.size.width, 1)];
  toolSeparator.wantsLayer = YES;
  toolSeparator.layer.backgroundColor = [SAFARI_BORDER CGColor];
  toolSeparator.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [self.titlebarEffectView addSubview:toolSeparator];

  // Bookmark bar
  self.bookmarkBarView = [[NSView alloc]
      initWithFrame:NSMakeRect(0, y - 28, frame.size.width, 28)];
  self.bookmarkBarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [self.titlebarEffectView addSubview:self.bookmarkBarView];

  [self populateBookmarks];
}

- (NSButton *)createToolbarButton:(NSString *)symbol
                            frame:(NSRect)fr
                           action:(SEL)act {
  NSButton *b = [[NSButton alloc] initWithFrame:fr];
  b.title = symbol;
  b.font = [NSFont systemFontOfSize:16];
  b.bezelStyle = NSBezelStyleInline;
  b.bordered = NO;
  b.target = self;
  b.action = act;
  return b;
}

- (void)populateBookmarks {
  NSArray *bmarks = @[
    @{@"icon" : @"􀀀", @"name" : @"Apple"},
    @{@"icon" : @"􀉣", @"name" : @"Developer"},
    @{@"icon" : @"􀎿", @"name" : @"VirtualOS Wiki"},
    @{@"icon" : @"􀌞", @"name" : @"News"},
    @{@"icon" : @"􀏀", @"name" : @"GitHub"}
  ];

  CGFloat bx = 20;
  for (NSDictionary *bm in bmarks) {
    NSButton *b = [[NSButton alloc] initWithFrame:NSMakeRect(bx, 4, 150, 20)];
    b.title = [NSString stringWithFormat:@"%@  %@", bm[@"icon"], bm[@"name"]];
    b.font = [NSFont systemFontOfSize:12];
    b.bezelStyle = NSBezelStyleInline;
    b.bordered = NO;
    b.alignment = NSTextAlignmentLeft;
    [b sizeToFit];
    NSRect bf = b.frame;
    bf.size.width += 15;
    b.frame = bf;
    [self.bookmarkBarView addSubview:b];
    bx += bf.size.width;
  }
}

- (void)buildupPageArea:(NSView *)root frame:(NSRect)frame {
  CGFloat topBarHeight = 110;
  NSRect pageFrame =
      NSMakeRect(0, 0, frame.size.width, frame.size.height - topBarHeight);

  self.pageScrollView = [[NSScrollView alloc] initWithFrame:pageFrame];
  self.pageScrollView.hasVerticalScroller = YES;
  self.pageScrollView.autohidesScrollers = YES;
  self.pageScrollView.drawsBackground = NO;
  self.pageScrollView.autoresizingMask =
      NSViewWidthSizable | NSViewHeightSizable;
  [root addSubview:self.pageScrollView];

  self.pageContainer = [[NSView alloc] initWithFrame:pageFrame];
  self.pageContainer.wantsLayer = YES;
  self.pageContainer.layer.backgroundColor = [SAFARI_BG CGColor];
  self.pageContainer.autoresizingMask = NSViewWidthSizable;
  self.pageScrollView.documentView = self.pageContainer;

  self.realWebView = [[WKWebView alloc] initWithFrame:pageFrame];
  self.realWebView.navigationDelegate = self;
  self.realWebView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.realWebView.hidden = YES;
  [root addSubview:self.realWebView];
}

#pragma mark - Tabs Logic

- (void)renderTabs {
  [self.tabContainerView.subviews
      makeObjectsPerformSelector:@selector(removeFromSuperview)];
  [self.tabViews removeAllObjects];

  CGFloat totalW = self.tabContainerView.bounds.size.width;
  CGFloat maxTabW = 220;
  CGFloat tabW = totalW / self.tabs.count;
  if (tabW > maxTabW)
    tabW = maxTabW;

  CGFloat x = 0;
  for (NSUInteger i = 0; i < self.tabs.count; i++) {
    SafariVirtualTab *t = self.tabs[i];
    BOOL isActive = (i == self.activeTabIndex);

    NSView *tv = [[NSView alloc] initWithFrame:NSMakeRect(x, 0, tabW, 36)];
    tv.wantsLayer = YES;
    tv.layer.cornerRadius = 8;
    tv.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    tv.layer.backgroundColor =
        isActive ? [SAFARI_TAB_ACTIVE CGColor] : [[NSColor clearColor] CGColor];

    if (isActive) {
      tv.layer.borderWidth = 1;
      tv.layer.borderColor = [SAFARI_BORDER CGColor];
    } else {
      NSView *sep =
          [[NSView alloc] initWithFrame:NSMakeRect(tabW - 1, 8, 1, 20)];
      sep.wantsLayer = YES;
      sep.layer.backgroundColor = [SAFARI_BORDER CGColor];
      [tv addSubview:sep];
    }

    NSString *displayTitle = t.title ?: @"New Tab";
    NSTextField *label =
        [[NSTextField alloc] initWithFrame:NSMakeRect(15, 8, tabW - 40, 18)];
    label.stringValue = displayTitle;
    label.font = isActive
                     ? [NSFont systemFontOfSize:12 weight:NSFontWeightMedium]
                     : [NSFont systemFontOfSize:12];
    label.textColor = isActive ? SAFARI_TEXT_PRIMARY : SAFARI_TEXT_SECONDARY;
    label.bezeled = NO;
    label.drawsBackground = NO;
    label.editable = NO;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    [tv addSubview:label];

    // Close button
    NSButton *closeBtn =
        [[NSButton alloc] initWithFrame:NSMakeRect(tabW - 25, 10, 14, 14)];
    closeBtn.title = @"✕";
    closeBtn.font = [NSFont systemFontOfSize:10];
    closeBtn.bezelStyle = NSBezelStyleInline;
    closeBtn.bordered = NO;
    closeBtn.target = self;
    closeBtn.action = @selector(closeTabAction:);
    closeBtn.tag = i;
    [tv addSubview:closeBtn];

    // Invisible button for clicking tab
    NSButton *clickArea =
        [[NSButton alloc] initWithFrame:NSMakeRect(0, 0, tabW - 30, 36)];
    clickArea.transparent = YES;
    clickArea.target = self;
    clickArea.action = @selector(selectTabAction:);
    clickArea.tag = i;
    [tv addSubview:clickArea];

    [self.tabContainerView addSubview:tv];
    [self.tabViews addObject:tv];
    x += tabW;
  }
}

- (void)createNewTab {
  SafariVirtualTab *t = [[SafariVirtualTab alloc] init];
  t.title = @"New Tab";
  t.url = @"virtualos://start";
  [self.tabs addObject:t];
  self.activeTabIndex = self.tabs.count - 1;
  [self renderTabs];
  [self loadURL:t.url];
}

- (void)closeTabAction:(NSButton *)sender {
  NSInteger idx = sender.tag;
  if (self.tabs.count == 1) {
    [self.safariWindow close];
    return;
  }
  [self.tabs removeObjectAtIndex:idx];
  if (self.activeTabIndex >= self.tabs.count) {
    self.activeTabIndex = self.tabs.count - 1;
  } else if (self.activeTabIndex == idx) {
    self.activeTabIndex = MAX(0, idx - 1);
  } else if (self.activeTabIndex > idx) {
    self.activeTabIndex--;
  }
  [self renderTabs];
  [self loadURL:self.tabs[self.activeTabIndex].url];
}

- (void)selectTabAction:(NSButton *)sender {
  self.activeTabIndex = sender.tag;
  [self renderTabs];
  [self loadURL:self.tabs[self.activeTabIndex].url];
}

#pragma mark - Navigation

- (void)controlTextDidEndEditing:(NSNotification *)obj {
  if (obj.object == self.urlField) {
    [self loadURL:self.urlField.stringValue];
  }
}

- (void)loadURL:(NSString *)urlString {
  SafariVirtualTab *t = self.tabs[self.activeTabIndex];

  NSString *normalizedURL = urlString;
  if (![urlString hasPrefix:@"virtualos://"] &&
      ![urlString hasPrefix:@"http://"] && ![urlString hasPrefix:@"https://"]) {
    if ([urlString containsString:@" "] || ![urlString containsString:@"."]) {
      normalizedURL = [NSString
          stringWithFormat:
              @"virtualos://search?q=%@",
              [urlString stringByAddingPercentEncodingWithAllowedCharacters:
                             [NSCharacterSet URLQueryAllowedCharacterSet]]];
    } else {
      normalizedURL = [NSString stringWithFormat:@"https://%@", urlString];
    }
  }

  t.url = normalizedURL;
  t.isLoading = YES;
  t.progress = 0.1;

  if (t.historyIndex == -1 ||
      ![t.history[t.historyIndex] isEqualToString:normalizedURL]) {
    if (t.historyIndex < (NSInteger)t.history.count - 1 &&
        t.historyIndex != -1) {
      NSRange r = NSMakeRange(t.historyIndex + 1,
                              t.history.count - (t.historyIndex + 1));
      [t.history removeObjectsInRange:r];
    }
    [t.history addObject:normalizedURL];
    t.historyIndex = t.history.count - 1;
  }

  self.urlField.stringValue = normalizedURL;
  self.progressIndicator.hidden = NO;
  self.progressIndicator.doubleValue = 10;

  [self updateNavButtonsState];

  if ([normalizedURL hasPrefix:@"http"]) {
    self.pageScrollView.hidden = YES;
    self.realWebView.hidden = NO;
    NSURLRequest *req =
        [NSURLRequest requestWithURL:[NSURL URLWithString:normalizedURL]];
    [self.realWebView loadRequest:req];
  } else {
    self.realWebView.hidden = YES;
    self.pageScrollView.hidden = NO;
    [self renderVirtualPage:normalizedURL];
  }
}

- (void)updateNavButtonsState {
  SafariVirtualTab *t = self.tabs[self.activeTabIndex];
  self.backBtn.enabled = (t.historyIndex > 0);
  self.forwardBtn.enabled = (t.historyIndex < (NSInteger)t.history.count - 1);
}

- (void)goBack {
  SafariVirtualTab *t = self.tabs[self.activeTabIndex];
  if (t.historyIndex > 0) {
    t.historyIndex--;
    [self loadURL:t.history[t.historyIndex]];
  }
}

- (void)goForward {
  SafariVirtualTab *t = self.tabs[self.activeTabIndex];
  if (t.historyIndex < (NSInteger)t.history.count - 1) {
    t.historyIndex++;
    [self loadURL:t.history[t.historyIndex]];
  }
}

- (void)reloadSelectedTab {
  SafariVirtualTab *t = self.tabs[self.activeTabIndex];
  [self loadURL:t.url];
}

#pragma mark - Virtual Page Rendering System

- (void)renderVirtualPage:(NSString *)url {
  SafariVirtualTab *t = self.tabs[self.activeTabIndex];
  for (NSView *v in [self.pageContainer.subviews copy]) {
    [v removeFromSuperview];
  }

  CGFloat w = self.pageScrollView.bounds.size.width;
  if (w < 800)
    w = 800;
  CGFloat currentY = 0; // We'll build top down and invert later, or just
                        // compute exact heights.
  // Actually MacOS coordinate system is 0,0 at bottom left.
  // Let's accumulate elements and lay them out at the end so we know total
  // height.

  NSMutableArray *elementsDesc = [NSMutableArray array];

  if ([url isEqualToString:@"virtualos://home"] ||
      [url isEqualToString:@"virtualos://start"]) {
    t.title = @"Start Page";
    [self buildStartPageInto:elementsDesc width:w];
  } else if ([url hasPrefix:@"virtualos://search"]) {
    t.title = @"Search Results";
    [self buildSearchPageInto:elementsDesc width:w query:url];
  } else if ([url hasPrefix:@"virtualos://news"]) {
    t.title = @"Apple News & Tech";
    [self buildNewsPageInto:elementsDesc width:w];
  } else {
    t.title = @"404 Not Found";
    [self build404PageInto:elementsDesc width:w];
  }

  // Layout engine
  CGFloat totalH = 50;
  for (NSDictionary *e in elementsDesc) {
    totalH += [e[@"height"] floatValue] + [e[@"margin"] floatValue];
  }
  if (totalH < self.pageScrollView.bounds.size.height) {
    totalH = self.pageScrollView.bounds.size.height;
  }

  [self.pageContainer setFrameSize:NSMakeSize(w, totalH)];

  CGFloat renderY = totalH - 20;
  for (NSDictionary *e in elementsDesc) {
    NSView *v = e[@"view"];
    CGFloat eWidth = [e[@"width"] floatValue];
    CGFloat eHeight = [e[@"height"] floatValue];
    CGFloat eMargin = [e[@"margin"] floatValue];
    BOOL center = [e[@"center"] boolValue];

    CGFloat rx = center ? (w - eWidth) / 2.0 : 40;
    renderY -= eHeight;
    [v setFrame:NSMakeRect(rx, renderY, eWidth, eHeight)];
    [self.pageContainer addSubview:v];
    renderY -= eMargin;
  }

  self.progressIndicator.hidden = YES;
  [self renderTabs]; // Update title
}

// ==========================================
// VIRTUAL PAGE BUILDERS
// ==========================================

- (void)buildStartPageInto:(NSMutableArray *)arr width:(CGFloat)w {
  [arr addObject:@{
    @"view" : [self createText:@"VirtualOS Browser"
                          font:[NSFont systemFontOfSize:42
                                                 weight:NSFontWeightBold]
                         color:SAFARI_TEXT_PRIMARY
                         align:NSTextAlignmentCenter],
    @"width" : @(w),
    @"height" : @50,
    @"margin" : @30,
    @"center" : @YES
  }];

  [arr addObject:@{
    @"view" : [self
        createText:
            @"A beautifully engineered web simulator built natively on macOS."
              font:[NSFont systemFontOfSize:18 weight:NSFontWeightRegular]
             color:SAFARI_TEXT_SECONDARY
             align:NSTextAlignmentCenter],
    @"width" : @(w),
    @"height" : @30,
    @"margin" : @60,
    @"center" : @YES
  }];

  // Quick Links Grid
  NSView *grid = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 800, 300)];
  NSArray *links = @[
    @{
      @"t" : @"VirtualOS Wiki",
      @"u" : @"virtualos://wiki",
      @"c" : [NSColor systemBlueColor]
    },
    @{
      @"t" : @"Apple News",
      @"u" : @"virtualos://news",
      @"c" : [NSColor systemRedColor]
    },
    @{
      @"t" : @"Terminal Docs",
      @"u" : @"virtualos://cli",
      @"c" : [NSColor systemGreenColor]
    },
    @{
      @"t" : @"Frameworks",
      @"u" : @"virtualos://dev",
      @"c" : [NSColor systemPurpleColor]
    },
    @{
      @"t" : @"Settings DB",
      @"u" : @"virtualos://settings",
      @"c" : [NSColor systemOrangeColor]
    },
    @{
      @"t" : @"GitHub Repo",
      @"u" : @"virtualos://git",
      @"c" : [NSColor darkGrayColor]
    }
  ];

  CGFloat gx = 100, gy = 200;
  for (int i = 0; i < links.count; i++) {
    NSDictionary *l = links[i];
    NSView *card = [[NSView alloc] initWithFrame:NSMakeRect(gx, gy, 180, 80)];
    card.wantsLayer = YES;
    card.layer.backgroundColor = [[NSColor controlBackgroundColor] CGColor];
    card.layer.cornerRadius = 12;
    card.layer.borderWidth = 1;
    card.layer.borderColor = [SAFARI_BORDER CGColor];

    // Tint strip
    NSView *tint = [[NSView alloc] initWithFrame:NSMakeRect(0, 76, 180, 4)];
    tint.wantsLayer = YES;
    tint.layer.backgroundColor = [(NSColor *)l[@"c"] CGColor];
    tint.layer.maskedCorners = kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    [card addSubview:tint];

    NSTextField *txt =
        [self createText:l[@"t"]
                    font:[NSFont systemFontOfSize:15 weight:NSFontWeightMedium]
                   color:SAFARI_TEXT_PRIMARY
                   align:NSTextAlignmentCenter];
    txt.frame = NSMakeRect(10, 20, 160, 40);
    [card addSubview:txt];

    [grid addSubview:card];

    gx += 200;
    if ((i + 1) % 3 == 0) {
      gx = 100;
      gy -= 100;
    }
  }

  [arr addObject:@{
    @"view" : grid,
    @"width" : @800,
    @"height" : @300,
    @"margin" : @40,
    @"center" : @YES
  }];

  // Footer
  [arr addObject:@{
    @"view" : [self
        createText:@"Privacy Report: 24 trackers prevented from profiling you."
              font:[NSFont systemFontOfSize:13]
             color:[NSColor systemGreenColor]
             align:NSTextAlignmentCenter],
    @"width" : @(w),
    @"height" : @20,
    @"margin" : @0,
    @"center" : @YES
  }];
}

- (void)buildNewsPageInto:(NSMutableArray *)arr width:(CGFloat)w {
  [arr addObject:@{
    @"view" : [self createText:@"Latest Tech & OS News"
                          font:[NSFont systemFontOfSize:36
                                                 weight:NSFontWeightHeavy]
                         color:SAFARI_TEXT_PRIMARY
                         align:NSTextAlignmentLeft],
    @"width" : @(w - 100),
    @"height" : @45,
    @"margin" : @10,
    @"center" : @YES
  }];
  [arr addObject:@{
    @"view" : [self createText:@"Updated just now."
                          font:[NSFont systemFontOfSize:14]
                         color:SAFARI_TEXT_SECONDARY
                         align:NSTextAlignmentLeft],
    @"width" : @(w - 100),
    @"height" : @20,
    @"margin" : @40,
    @"center" : @YES
  }];

  NSArray *articles = @[
    @{
      @"title" : @"VirtualOS introduces massive 'Liquid Glass' UI rewrite",
      @"cat" : @"Software",
      @"desc" :
          @"The completely rewritten interface brings NSVisualEffectViews and "
          @"advanced compositing to all system apps spanning thousands of "
          @"lines. Performance remains stellar at 60fps."
    },
    @{
      @"title" : @"How Foundation classes bridge Objective-C and modern macOS",
      @"cat" : @"Developer",
      @"desc" : @"A deep dive into the robust NSWindowController sublcassing "
                @"methodologies and event handling in pure Objective-C app "
                @"environments."
    },
    @{
      @"title" : @"Apple's secret to battery life: Memory Compression",
      @"cat" : @"Hardware",
      @"desc" :
          @"Understanding the WKWebView and WebKit layer integrations that "
          @"allow for energy efficient rendering on the latest M4 chips."
    },
    @{
      @"title" : @"New Terminal App gains native ZSH environment",
      @"cat" : @"CLI",
      @"desc" : @"Developers rejoice as the VirtualOS Terminal receives "
                @"interactive shell support and robust syntax rendering."
    }
  ];

  for (NSDictionary *art in articles) {
    NSView *aView =
        [[NSView alloc] initWithFrame:NSMakeRect(0, 0, w - 200, 140)];
    aView.wantsLayer = YES;
    aView.layer.backgroundColor = [[NSColor controlBackgroundColor] CGColor];
    aView.layer.cornerRadius = 16;
    aView.layer.borderWidth = 1;
    aView.layer.borderColor = [SAFARI_BORDER CGColor];

    NSTextField *cat =
        [self createText:art[@"cat"]
                    font:[NSFont systemFontOfSize:12 weight:NSFontWeightBold]
                   color:SAFARI_ACCENT
                   align:NSTextAlignmentLeft];
    cat.frame = NSMakeRect(20, 105, 500, 20);
    [aView addSubview:cat];

    NSTextField *tit =
        [self createText:art[@"title"]
                    font:[NSFont systemFontOfSize:22 weight:NSFontWeightBold]
                   color:SAFARI_TEXT_PRIMARY
                   align:NSTextAlignmentLeft];
    tit.frame = NSMakeRect(20, 75, w - 240, 30);
    [aView addSubview:tit];

    NSTextField *des = [self createText:art[@"desc"]
                                   font:[NSFont systemFontOfSize:15]
                                  color:SAFARI_TEXT_SECONDARY
                                  align:NSTextAlignmentLeft];
    des.frame = NSMakeRect(20, 15, w - 280, 50);
    // des.lineBreakMode = NSLineBreakByWordWrapping;
    [aView addSubview:des];

    [arr addObject:@{
      @"view" : aView,
      @"width" : @(w - 100),
      @"height" : @140,
      @"margin" : @20,
      @"center" : @YES
    }];
  }
}

- (void)buildSearchPageInto:(NSMutableArray *)arr
                      width:(CGFloat)w
                      query:(NSString *)query {
  NSString *actualQuery = @"";
  if ([query containsString:@"q="]) {
    actualQuery = [[query componentsSeparatedByString:@"q="]
                       .lastObject stringByRemovingPercentEncoding];
  }

  [arr addObject:@{
    @"view" : [self createText:@"Virtual Search"
                          font:[NSFont systemFontOfSize:30
                                                 weight:NSFontWeightHeavy]
                         color:[NSColor systemBlueColor]
                         align:NSTextAlignmentLeft],
    @"width" : @(w - 200),
    @"height" : @40,
    @"margin" : @10,
    @"center" : @YES
  }];

  [arr addObject:@{
    @"view" :
        [self createText:[NSString stringWithFormat:@"Showing results for '%@'",
                                                    actualQuery]
                    font:[NSFont systemFontOfSize:14]
                   color:SAFARI_TEXT_SECONDARY
                   align:NSTextAlignmentLeft],
    @"width" : @(w - 200),
    @"height" : @20,
    @"margin" : @40,
    @"center" : @YES
  }];

  for (int i = 1; i <= 6; i++) {
    NSView *res = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, w - 200, 100)];

    NSTextField *u =
        [self createText:[NSString stringWithFormat:@"virtualos://wiki/%@/%d",
                                                    actualQuery, i]
                    font:[NSFont systemFontOfSize:12]
                   color:SAFARI_TEXT_SECONDARY
                   align:NSTextAlignmentLeft];
    u.frame = NSMakeRect(0, 80, 600, 20);
    [res addSubview:u];

    NSTextField *t = [self
        createText:[NSString
                       stringWithFormat:@"Everything you need to know about %@",
                                        actualQuery]
              font:[NSFont systemFontOfSize:20 weight:NSFontWeightMedium]
             color:[NSColor systemBlueColor]
             align:NSTextAlignmentLeft];
    t.frame = NSMakeRect(0, 55, 600, 25);
    [res addSubview:t];

    NSTextField *d = [self
        createText:[NSString
                       stringWithFormat:
                           @"This article explores the fundamental "
                           @"architecture and usage patterns of %@ inside the "
                           @"advanced macOS Tahoe environment.",
                           actualQuery]
              font:[NSFont systemFontOfSize:14]
             color:SAFARI_TEXT_PRIMARY
             align:NSTextAlignmentLeft];
    d.frame = NSMakeRect(0, 10, w - 300, 40);
    [res addSubview:d];

    [arr addObject:@{
      @"view" : res,
      @"width" : @(w - 200),
      @"height" : @100,
      @"margin" : @30,
      @"center" : @YES
    }];
  }
}

- (void)build404PageInto:(NSMutableArray *)arr width:(CGFloat)w {
  [arr addObject:@{
    @"view" : [self createText:@"404"
                          font:[NSFont systemFontOfSize:120
                                                 weight:NSFontWeightHeavy]
                         color:[NSColor systemGrayColor]
                         align:NSTextAlignmentCenter],
    @"width" : @(w),
    @"height" : @140,
    @"margin" : @20,
    @"center" : @YES
  }];

  [arr addObject:@{
    @"view" : [self createText:@"Page Not Found"
                          font:[NSFont systemFontOfSize:24]
                         color:SAFARI_TEXT_PRIMARY
                         align:NSTextAlignmentCenter],
    @"width" : @(w),
    @"height" : @30,
    @"margin" : @60,
    @"center" : @YES
  }];
}

- (NSTextField *)createText:(NSString *)t
                       font:(NSFont *)f
                      color:(NSColor *)c
                      align:(NSTextAlignment)a {
  NSTextField *txt = [[NSTextField alloc] init];
  txt.stringValue = t;
  txt.font = f;
  txt.textColor = c;
  txt.alignment = a;
  txt.bezeled = NO;
  txt.drawsBackground = NO;
  txt.editable = NO;
  return txt;
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView
    didStartProvisionalNavigation:(WKNavigation *)navigation {
  self.progressIndicator.hidden = NO;
  self.progressIndicator.doubleValue = 25;
}

- (void)webView:(WKWebView *)webView
    didFinishNavigation:(WKNavigation *)navigation {
  self.progressIndicator.hidden = YES;
  SafariVirtualTab *t = self.tabs[self.activeTabIndex];
  t.title = webView.title;
  [self renderTabs];
}

@end
