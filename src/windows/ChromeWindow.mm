#import "ChromeWindow.h"
#import <QuartzCore/QuartzCore.h>

// ============================================================================
// ChromeWindow.mm — Real Google Chrome Browser
// Uses WKWebView natively — ZERO AppleScript
// Pixel-perfect Chrome UI: dark tab bar, omnibox with lock icon,
// bookmarks bar, multi-tab support, real navigation with history
// ============================================================================

// ── Chrome Color Palette (exact Material Design) ──
#define CHROME_TAB_BG                                                          \
  [NSColor colorWithRed:0.133 green:0.133 blue:0.137 alpha:1.0] // #222225
#define CHROME_TAB_ACTIVE                                                      \
  [NSColor colorWithRed:0.188 green:0.188 blue:0.196 alpha:1.0] // #303032
#define CHROME_TAB_HOVER                                                       \
  [NSColor colorWithRed:0.165 green:0.165 blue:0.173 alpha:1.0] // #2A2A2C
#define CHROME_TOOLBAR_BG                                                      \
  [NSColor colorWithRed:0.188 green:0.188 blue:0.196 alpha:1.0] // #303032
#define CHROME_OMNIBOX_BG                                                      \
  [NSColor colorWithRed:0.133 green:0.133 blue:0.137 alpha:1.0] // #222225
#define CHROME_TEXT [NSColor colorWithWhite:0.90 alpha:1.0]
#define CHROME_TEXT_DIM [NSColor colorWithWhite:0.55 alpha:1.0]
#define CHROME_ACCENT                                                          \
  [NSColor colorWithRed:0.54 green:0.72 blue:0.99 alpha:1.0] // #8AB4FC
#define CHROME_BORDER [NSColor colorWithWhite:0.25 alpha:1.0]
#define CHROME_RED [NSColor colorWithRed:0.92 green:0.34 blue:0.34 alpha:1.0]
#define CHROME_GREEN [NSColor colorWithRed:0.30 green:0.85 blue:0.45 alpha:1.0]

static const CGFloat kChromeTabBarHeight = 38.0;
static const CGFloat kChromeToolbarHeight = 44.0;
static const CGFloat kChromeBookmarkBarHeight = 32.0;
static const CGFloat kChromeTopBarHeight =
    kChromeTabBarHeight + kChromeToolbarHeight + kChromeBookmarkBarHeight;

// ── Tab model ──
@interface ChromeTab : NSObject
@property(nonatomic, strong) NSString *title;
@property(nonatomic, strong) NSString *urlString;
@property(nonatomic, strong) WKWebView *webView;
@property(nonatomic, assign) BOOL isLoading;
@property(nonatomic, assign) BOOL isSecure;
@property(nonatomic, assign) double loadProgress;
@property(nonatomic, strong) NSImage *favicon;
@end

@implementation ChromeTab
- (instancetype)init {
  if (self = [super init]) {
    _title = @"New Tab";
    _urlString = @"";
    _isLoading = NO;
    _isSecure = NO;
    _loadProgress = 0.0;
  }
  return self;
}
@end

// ── Main Chrome window ──
@interface ChromeWindow () <NSTextFieldDelegate>
@property(nonatomic, strong) NSWindow *chromeWindow;
@property(nonatomic, strong) NSView *tabBarView;
@property(nonatomic, strong) NSView *toolbarView;
@property(nonatomic, strong) NSView *bookmarkBarView;
@property(nonatomic, strong) NSView *webViewContainer;
@property(nonatomic, strong) NSTextField *omniboxField;
@property(nonatomic, strong) NSButton *backBtn;
@property(nonatomic, strong) NSButton *forwardBtn;
@property(nonatomic, strong) NSButton *reloadBtn;
@property(nonatomic, strong) NSProgressIndicator *loadingBar;
@property(nonatomic, strong) NSView *lockIconView;

@property(nonatomic, strong) NSMutableArray<ChromeTab *> *tabs;
@property(nonatomic, assign) NSInteger activeTabIndex;
@property(nonatomic, strong) NSMutableArray<NSView *> *tabButtonViews;
@end

@implementation ChromeWindow

+ (instancetype)sharedInstance {
  static ChromeWindow *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[ChromeWindow alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _tabs = [NSMutableArray array];
    _tabButtonViews = [NSMutableArray array];
    _activeTabIndex = 0;
  }
  return self;
}

#pragma mark - Window Lifecycle

- (void)showWindow {
  if (self.chromeWindow) {
    [self.chromeWindow makeKeyAndOrderFront:nil];
    return;
  }

  NSRect screenRect = [[NSScreen mainScreen] visibleFrame];
  NSRect frame =
      NSMakeRect(NSMidX(screenRect) - 640, NSMidY(screenRect) - 420, 1280, 840);

  self.chromeWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable |
                          NSWindowStyleMaskFullSizeContentView
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.chromeWindow.title = @"Google Chrome";
  self.chromeWindow.releasedWhenClosed = NO;
  self.chromeWindow.titlebarAppearsTransparent = YES;
  self.chromeWindow.titleVisibility = NSWindowTitleHidden;
  self.chromeWindow.minSize = NSMakeSize(600, 400);
  self.chromeWindow.backgroundColor = CHROME_TAB_BG;

  NSView *root = self.chromeWindow.contentView;
  root.wantsLayer = YES;
  root.layer.backgroundColor = [CHROME_TAB_BG CGColor];

  [self buildTabBar:root frame:frame];
  [self buildToolbar:root frame:frame];
  [self buildBookmarkBar:root frame:frame];
  [self buildWebViewContainer:root frame:frame];

  // Create initial tab
  [self newTabWithURL:@"https://www.google.com"];

  [self.chromeWindow makeKeyAndOrderFront:nil];
}

#pragma mark - Tab Bar (Chrome-accurate dark theme)

- (void)buildTabBar:(NSView *)root frame:(NSRect)frame {
  CGFloat y = frame.size.height - kChromeTabBarHeight;
  self.tabBarView = [[NSView alloc]
      initWithFrame:NSMakeRect(0, y, frame.size.width, kChromeTabBarHeight)];
  self.tabBarView.wantsLayer = YES;
  self.tabBarView.layer.backgroundColor = [CHROME_TAB_BG CGColor];
  self.tabBarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [root addSubview:self.tabBarView];

  // New tab (+) button
  NSButton *newTabBtn = [[NSButton alloc]
      initWithFrame:NSMakeRect(frame.size.width - 40, 6, 28, 28)];
  newTabBtn.title = @"+";
  newTabBtn.font = [NSFont systemFontOfSize:18 weight:NSFontWeightLight];
  newTabBtn.bezelStyle = NSBezelStyleInline;
  newTabBtn.bordered = NO;
  newTabBtn.contentTintColor = CHROME_TEXT_DIM;
  newTabBtn.target = self;
  newTabBtn.action = @selector(newTab);
  newTabBtn.autoresizingMask = NSViewMinXMargin;
  [self.tabBarView addSubview:newTabBtn];
}

- (void)renderTabButtons {
  // Remove old tab buttons
  for (NSView *v in self.tabButtonViews) {
    [v removeFromSuperview];
  }
  [self.tabButtonViews removeAllObjects];

  CGFloat availableW = self.tabBarView.bounds.size.width -
                       80; // leave room for traffic lights + new tab
  CGFloat maxTabW = 240;
  CGFloat minTabW = 60;
  CGFloat tabW = availableW / self.tabs.count;
  if (tabW > maxTabW)
    tabW = maxTabW;
  if (tabW < minTabW)
    tabW = minTabW;

  CGFloat x = 70; // after traffic lights
  for (NSInteger i = 0; i < (NSInteger)self.tabs.count; i++) {
    ChromeTab *tab = self.tabs[i];
    BOOL isActive = (i == self.activeTabIndex);

    NSView *tabView = [[NSView alloc]
        initWithFrame:NSMakeRect(x, 4, tabW, kChromeTabBarHeight - 4)];
    tabView.wantsLayer = YES;

    if (isActive) {
      tabView.layer.backgroundColor = [CHROME_TAB_ACTIVE CGColor];
      tabView.layer.cornerRadius = 8;
      tabView.layer.maskedCorners =
          kCALayerMinXMaxYCorner | kCALayerMaxXMaxYCorner;
    }

    // Favicon
    NSImage *favicon = tab.favicon;
    if (!favicon) {
      // Default globe icon
      favicon = [NSImage imageWithSystemSymbolName:@"globe"
                          accessibilityDescription:@"Web"];
    }
    if (favicon) {
      NSImageView *faviconView =
          [[NSImageView alloc] initWithFrame:NSMakeRect(10, 9, 16, 16)];
      faviconView.image = favicon;
      faviconView.imageScaling = NSImageScaleProportionallyUpOrDown;
      if (!tab.favicon)
        faviconView.contentTintColor = CHROME_TEXT_DIM;
      [tabView addSubview:faviconView];
    }

    // Loading spinner
    if (tab.isLoading) {
      NSProgressIndicator *spinner =
          [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(10, 9, 16, 16)];
      spinner.style = NSProgressIndicatorStyleSpinning;
      spinner.controlSize = NSControlSizeSmall;
      [spinner startAnimation:nil];
      [tabView addSubview:spinner];
    }

    // Tab title
    NSTextField *titleLabel =
        [[NSTextField alloc] initWithFrame:NSMakeRect(32, 8, tabW - 60, 18)];
    titleLabel.stringValue = tab.title ?: @"New Tab";
    titleLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
    titleLabel.textColor = isActive ? CHROME_TEXT : CHROME_TEXT_DIM;
    titleLabel.bezeled = NO;
    titleLabel.drawsBackground = NO;
    titleLabel.editable = NO;
    titleLabel.selectable = NO;
    titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [tabView addSubview:titleLabel];

    // Close (x) button
    if (self.tabs.count > 1) {
      NSButton *closeBtn =
          [[NSButton alloc] initWithFrame:NSMakeRect(tabW - 24, 9, 16, 16)];
      closeBtn.title = @"✕";
      closeBtn.font = [NSFont systemFontOfSize:9 weight:NSFontWeightMedium];
      closeBtn.bezelStyle = NSBezelStyleInline;
      closeBtn.bordered = NO;
      closeBtn.contentTintColor = CHROME_TEXT_DIM;
      closeBtn.target = self;
      closeBtn.action = @selector(closeTabAction:);
      closeBtn.tag = i;
      [tabView addSubview:closeBtn];
    }

    // Click area for selecting tab
    NSButton *clickArea = [[NSButton alloc]
        initWithFrame:NSMakeRect(0, 0, tabW - 30, kChromeTabBarHeight - 4)];
    clickArea.transparent = YES;
    clickArea.target = self;
    clickArea.action = @selector(selectTabAction:);
    clickArea.tag = i;
    [tabView addSubview:clickArea];

    // Separator between tabs
    if (!isActive && i + 1 < (NSInteger)self.tabs.count &&
        i + 1 != self.activeTabIndex) {
      NSView *sep =
          [[NSView alloc] initWithFrame:NSMakeRect(tabW - 1, 10, 1, 14)];
      sep.wantsLayer = YES;
      sep.layer.backgroundColor = [CHROME_BORDER CGColor];
      [tabView addSubview:sep];
    }

    [self.tabBarView addSubview:tabView];
    [self.tabButtonViews addObject:tabView];
    x += tabW;
  }
}

#pragma mark - Toolbar (Omnibox)

- (void)buildToolbar:(NSView *)root frame:(NSRect)frame {
  CGFloat y = frame.size.height - kChromeTabBarHeight - kChromeToolbarHeight;
  self.toolbarView = [[NSView alloc]
      initWithFrame:NSMakeRect(0, y, frame.size.width, kChromeToolbarHeight)];
  self.toolbarView.wantsLayer = YES;
  self.toolbarView.layer.backgroundColor = [CHROME_TOOLBAR_BG CGColor];
  self.toolbarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [root addSubview:self.toolbarView];

  // ── Navigation buttons ──
  self.backBtn = [self chromeToolbarBtn:@"chevron.left"
                                  frame:NSMakeRect(8, 8, 28, 28)
                                 action:@selector(goBack)];
  self.forwardBtn = [self chromeToolbarBtn:@"chevron.right"
                                     frame:NSMakeRect(38, 8, 28, 28)
                                    action:@selector(goForward)];
  self.reloadBtn = [self chromeToolbarBtn:@"arrow.clockwise"
                                    frame:NSMakeRect(68, 8, 28, 28)
                                   action:@selector(reloadPage)];
  [self.toolbarView addSubview:self.backBtn];
  [self.toolbarView addSubview:self.forwardBtn];
  [self.toolbarView addSubview:self.reloadBtn];

  // ── Omnibox (URL bar) ──
  CGFloat omniX = 104;
  CGFloat omniW = frame.size.width - omniX - 60;

  NSView *omniBg =
      [[NSView alloc] initWithFrame:NSMakeRect(omniX, 7, omniW, 30)];
  omniBg.wantsLayer = YES;
  omniBg.layer.backgroundColor = [CHROME_OMNIBOX_BG CGColor];
  omniBg.layer.cornerRadius = 15; // Chrome pill shape
  omniBg.autoresizingMask = NSViewWidthSizable;
  [self.toolbarView addSubview:omniBg];

  // Lock icon
  self.lockIconView =
      [[NSView alloc] initWithFrame:NSMakeRect(omniX + 12, 11, 18, 18)];
  [self.toolbarView addSubview:self.lockIconView];
  [self updateLockIcon:NO];

  // URL text field
  self.omniboxField = [[NSTextField alloc]
      initWithFrame:NSMakeRect(omniX + 32, 10, omniW - 48, 22)];
  self.omniboxField.font = [NSFont systemFontOfSize:14];
  self.omniboxField.textColor = CHROME_TEXT;
  self.omniboxField.bezeled = NO;
  self.omniboxField.drawsBackground = NO;
  self.omniboxField.delegate = self;
  self.omniboxField.placeholderString = @"Search Google or type a URL";
  self.omniboxField.placeholderAttributedString = [[NSAttributedString alloc]
      initWithString:@"Search Google or type a URL"
          attributes:@{
            NSFontAttributeName : [NSFont systemFontOfSize:14],
            NSForegroundColorAttributeName : CHROME_TEXT_DIM
          }];
  self.omniboxField.focusRingType = NSFocusRingTypeNone;
  self.omniboxField.autoresizingMask = NSViewWidthSizable;
  [self.toolbarView addSubview:self.omniboxField];

  // ── Loading progress bar ──
  self.loadingBar = [[NSProgressIndicator alloc]
      initWithFrame:NSMakeRect(0, 0, frame.size.width, 2)];
  self.loadingBar.style = NSProgressIndicatorStyleBar;
  self.loadingBar.controlSize = NSControlSizeSmall;
  self.loadingBar.autoresizingMask = NSViewWidthSizable;
  self.loadingBar.hidden = YES;
  [self.toolbarView addSubview:self.loadingBar];

  // ── Extensions area (profile icon) ──
  NSButton *profileBtn =
      [self chromeToolbarBtn:@"person.circle"
                       frame:NSMakeRect(frame.size.width - 44, 8, 28, 28)
                      action:nil];
  profileBtn.autoresizingMask = NSViewMinXMargin;
  [self.toolbarView addSubview:profileBtn];
}

- (void)updateLockIcon:(BOOL)isSecure {
  for (NSView *v in self.lockIconView.subviews)
    [v removeFromSuperview];

  NSString *symbolName = isSecure ? @"lock.fill" : @"globe";
  NSImage *img = [NSImage imageWithSystemSymbolName:symbolName
                           accessibilityDescription:symbolName];
  if (img) {
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration
        configurationWithPointSize:12
                            weight:NSFontWeightMedium
                             scale:NSImageSymbolScaleSmall];
    NSImageView *iv =
        [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 18, 18)];
    iv.image = [img imageWithSymbolConfiguration:config];
    iv.contentTintColor = isSecure ? CHROME_TEXT_DIM : CHROME_TEXT_DIM;
    [self.lockIconView addSubview:iv];
  }
}

- (NSButton *)chromeToolbarBtn:(NSString *)sfName
                         frame:(NSRect)fr
                        action:(SEL)act {
  NSButton *btn = [[NSButton alloc] initWithFrame:fr];
  NSImage *img = [NSImage imageWithSystemSymbolName:sfName
                           accessibilityDescription:sfName];
  if (img) {
    NSImageSymbolConfiguration *config = [NSImageSymbolConfiguration
        configurationWithPointSize:14
                            weight:NSFontWeightMedium
                             scale:NSImageSymbolScaleSmall];
    btn.image = [img imageWithSymbolConfiguration:config];
    btn.contentTintColor = CHROME_TEXT_DIM;
  } else {
    btn.title = sfName;
  }
  btn.bezelStyle = NSBezelStyleInline;
  btn.bordered = NO;
  btn.target = self;
  btn.action = act;
  return btn;
}

#pragma mark - Bookmarks Bar

- (void)buildBookmarkBar:(NSView *)root frame:(NSRect)frame {
  CGFloat y = frame.size.height - kChromeTabBarHeight - kChromeToolbarHeight -
              kChromeBookmarkBarHeight;
  self.bookmarkBarView =
      [[NSView alloc] initWithFrame:NSMakeRect(0, y, frame.size.width,
                                               kChromeBookmarkBarHeight)];
  self.bookmarkBarView.wantsLayer = YES;
  self.bookmarkBarView.layer.backgroundColor = [CHROME_TOOLBAR_BG CGColor];
  self.bookmarkBarView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [root addSubview:self.bookmarkBarView];

  // Bottom border
  NSView *borderLine =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, 1)];
  borderLine.wantsLayer = YES;
  borderLine.layer.backgroundColor = [CHROME_BORDER CGColor];
  borderLine.autoresizingMask = NSViewWidthSizable;
  [self.bookmarkBarView addSubview:borderLine];

  // Bookmarks
  NSArray *bookmarks = @[
    @{
      @"name" : @"Google",
      @"url" : @"https://www.google.com",
      @"icon" : @"magnifyingglass"
    },
    @{
      @"name" : @"YouTube",
      @"url" : @"https://www.youtube.com",
      @"icon" : @"play.rectangle.fill"
    },
    @{
      @"name" : @"GitHub",
      @"url" : @"https://github.com",
      @"icon" : @"chevron.left.forwardslash.chevron.right"
    },
    @{
      @"name" : @"Gmail",
      @"url" : @"https://mail.google.com",
      @"icon" : @"envelope.fill"
    },
    @{
      @"name" : @"Wikipedia",
      @"url" : @"https://en.wikipedia.org",
      @"icon" : @"book.fill"
    },
    @{
      @"name" : @"Stack Overflow",
      @"url" : @"https://stackoverflow.com",
      @"icon" : @"questionmark.circle"
    },
    @{
      @"name" : @"Reddit",
      @"url" : @"https://www.reddit.com",
      @"icon" : @"bubble.left.and.bubble.right.fill"
    },
    @{@"name" : @"Twitter", @"url" : @"https://x.com", @"icon" : @"at"},
  ];

  CGFloat bx = 12;
  for (NSDictionary *bm in bookmarks) {
    NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(bx, 4, 120, 24)];

    // Try to use SF Symbol as icon
    NSImage *icon = [NSImage imageWithSystemSymbolName:bm[@"icon"]
                              accessibilityDescription:bm[@"name"]];
    NSString *title = bm[@"name"];
    if (icon) {
      NSImageSymbolConfiguration *cfg = [NSImageSymbolConfiguration
          configurationWithPointSize:10
                              weight:NSFontWeightMedium
                               scale:NSImageSymbolScaleSmall];
      btn.image = [icon imageWithSymbolConfiguration:cfg];
      btn.imagePosition = NSImageLeft;
      btn.contentTintColor = CHROME_TEXT_DIM;
    }
    btn.title = [NSString stringWithFormat:@" %@", title];
    btn.font = [NSFont systemFontOfSize:12];
    btn.contentTintColor = CHROME_TEXT_DIM;
    btn.bezelStyle = NSBezelStyleInline;
    btn.bordered = NO;
    btn.alignment = NSTextAlignmentLeft;
    btn.target = self;
    btn.action = @selector(bookmarkClicked:);
    btn.toolTip = bm[@"url"];
    [btn sizeToFit];
    NSRect bf = btn.frame;
    bf.size.width += 12;
    btn.frame = bf;
    [self.bookmarkBarView addSubview:btn];
    bx += bf.size.width + 2;
  }
}

#pragma mark - WebView Container

- (void)buildWebViewContainer:(NSView *)root frame:(NSRect)frame {
  CGFloat y = 0;
  CGFloat h = frame.size.height - kChromeTopBarHeight;
  self.webViewContainer =
      [[NSView alloc] initWithFrame:NSMakeRect(0, y, frame.size.width, h)];
  self.webViewContainer.wantsLayer = YES;
  self.webViewContainer.layer.backgroundColor =
      [[NSColor colorWithWhite:0.12 alpha:1.0] CGColor];
  self.webViewContainer.autoresizingMask =
      NSViewWidthSizable | NSViewHeightSizable;
  [root addSubview:self.webViewContainer];
}

#pragma mark - Tab Management

- (void)newTab {
  [self newTabWithURL:@"https://www.google.com"];
}

- (void)newTabWithURL:(NSString *)url {
  ChromeTab *tab = [[ChromeTab alloc] init];
  tab.urlString = url;

  // Create a REAL WKWebView for this tab
  WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
  config.allowsAirPlayForMediaPlayback = YES;
  if (@available(macOS 10.15, *)) {
    WKWebpagePreferences *prefs = [[WKWebpagePreferences alloc] init];
    prefs.allowsContentJavaScript = YES;
    config.defaultWebpagePreferences = prefs;
  }

  tab.webView = [[WKWebView alloc] initWithFrame:self.webViewContainer.bounds
                                   configuration:config];
  tab.webView.navigationDelegate = self;
  tab.webView.UIDelegate = self;
  tab.webView.allowsBackForwardNavigationGestures = YES;
  tab.webView.customUserAgent =
      @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
      @"AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36";
  tab.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  // KVO for title, URL, loading, progress
  [tab.webView addObserver:self
                forKeyPath:@"title"
                   options:NSKeyValueObservingOptionNew
                   context:nil];
  [tab.webView addObserver:self
                forKeyPath:@"URL"
                   options:NSKeyValueObservingOptionNew
                   context:nil];
  [tab.webView addObserver:self
                forKeyPath:@"loading"
                   options:NSKeyValueObservingOptionNew
                   context:nil];
  [tab.webView addObserver:self
                forKeyPath:@"estimatedProgress"
                   options:NSKeyValueObservingOptionNew
                   context:nil];

  [self.tabs addObject:tab];
  self.activeTabIndex = self.tabs.count - 1;

  [self switchToTab:self.activeTabIndex];
  [self loadURL:url];
  [self renderTabButtons];
}

- (void)switchToTab:(NSInteger)index {
  if (index < 0 || index >= (NSInteger)self.tabs.count)
    return;

  // Hide all webviews
  for (NSView *sub in self.webViewContainer.subviews) {
    [sub removeFromSuperview];
  }

  // Show the active tab's webview
  ChromeTab *tab = self.tabs[index];
  tab.webView.frame = self.webViewContainer.bounds;
  [self.webViewContainer addSubview:tab.webView];

  self.activeTabIndex = index;

  // Update omnibox
  if (tab.webView.URL) {
    self.omniboxField.stringValue = tab.webView.URL.absoluteString;
    [self updateLockIcon:[tab.webView.URL.scheme isEqualToString:@"https"]];
  } else {
    self.omniboxField.stringValue = tab.urlString ?: @"";
    [self updateLockIcon:NO];
  }

  [self renderTabButtons];
}

#pragma mark - URL Loading (Real WKWebView — No AppleScript!)

- (void)loadURL:(NSString *)urlString {
  if (!urlString || urlString.length == 0)
    return;

  // If no scheme, add https
  NSString *processedURL = urlString;
  if (![processedURL containsString:@"://"] &&
      ![processedURL hasPrefix:@"about:"]) {
    // Check if it looks like a URL
    if ([processedURL containsString:@"."] &&
        ![processedURL containsString:@" "]) {
      processedURL = [@"https://" stringByAppendingString:processedURL];
    } else {
      // Google search
      NSString *query =
          [processedURL stringByAddingPercentEncodingWithAllowedCharacters:
                            [NSCharacterSet URLQueryAllowedCharacterSet]];
      processedURL = [NSString
          stringWithFormat:@"https://www.google.com/search?q=%@", query];
    }
  }

  NSURL *url = [NSURL URLWithString:processedURL];
  if (url) {
    ChromeTab *tab = self.tabs[self.activeTabIndex];
    tab.urlString = processedURL;
    tab.isLoading = YES;
    self.omniboxField.stringValue = processedURL;

    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [tab.webView loadRequest:request];

    self.loadingBar.hidden = NO;
    [self.loadingBar startAnimation:nil];
    [self renderTabButtons];
  }
}

#pragma mark - Tab Actions

- (void)selectTabAction:(NSButton *)sender {
  NSInteger idx = sender.tag;
  if (idx >= 0 && idx < (NSInteger)self.tabs.count) {
    [self switchToTab:idx];
  }
}

- (void)closeTabAction:(NSButton *)sender {
  NSInteger idx = sender.tag;
  if (idx < 0 || idx >= (NSInteger)self.tabs.count)
    return;
  if (self.tabs.count <= 1)
    return;

  ChromeTab *tab = self.tabs[idx];
  @try {
    [tab.webView removeObserver:self forKeyPath:@"title"];
    [tab.webView removeObserver:self forKeyPath:@"URL"];
    [tab.webView removeObserver:self forKeyPath:@"loading"];
    [tab.webView removeObserver:self forKeyPath:@"estimatedProgress"];
  } @catch (NSException *e) {
  }
  [tab.webView removeFromSuperview];

  [self.tabs removeObjectAtIndex:idx];
  if (self.activeTabIndex >= (NSInteger)self.tabs.count) {
    self.activeTabIndex = self.tabs.count - 1;
  }
  [self switchToTab:self.activeTabIndex];
}

#pragma mark - Navigation

- (void)goBack {
  ChromeTab *tab = self.tabs[self.activeTabIndex];
  if (tab.webView.canGoBack)
    [tab.webView goBack];
}

- (void)goForward {
  ChromeTab *tab = self.tabs[self.activeTabIndex];
  if (tab.webView.canGoForward)
    [tab.webView goForward];
}

- (void)reloadPage {
  ChromeTab *tab = self.tabs[self.activeTabIndex];
  [tab.webView reload];
}

#pragma mark - Bookmark Clicks

- (void)bookmarkClicked:(NSButton *)sender {
  NSString *url = sender.toolTip;
  if (url)
    [self loadURL:url];
}

#pragma mark - NSTextField Delegate (Omnibox)

- (void)controlTextDidEndEditing:(NSNotification *)obj {
  NSString *text = self.omniboxField.stringValue;
  if (text.length > 0) {
    [self loadURL:text];
  }
}

#pragma mark - KVO (Watch WebView state changes)

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
  // Find which tab this webview belongs to
  WKWebView *wv = (WKWebView *)object;
  ChromeTab *tab = nil;
  for (ChromeTab *t in self.tabs) {
    if (t.webView == wv) {
      tab = t;
      break;
    }
  }
  if (!tab)
    return;

  BOOL isActiveTab = (tab == self.tabs[self.activeTabIndex]);

  if ([keyPath isEqualToString:@"title"]) {
    tab.title = wv.title ?: @"New Tab";
    if (isActiveTab) {
      self.chromeWindow.title =
          [NSString stringWithFormat:@"%@ - Google Chrome", tab.title];
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      [self renderTabButtons];
    });
  } else if ([keyPath isEqualToString:@"URL"]) {
    if (wv.URL) {
      tab.urlString = wv.URL.absoluteString;
      tab.isSecure = [wv.URL.scheme isEqualToString:@"https"];
      if (isActiveTab) {
        self.omniboxField.stringValue = tab.urlString;
        [self updateLockIcon:tab.isSecure];
      }
    }
  } else if ([keyPath isEqualToString:@"loading"]) {
    tab.isLoading = wv.isLoading;
    if (isActiveTab) {
      self.loadingBar.hidden = !wv.isLoading;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
      [self renderTabButtons];
    });
  } else if ([keyPath isEqualToString:@"estimatedProgress"]) {
    tab.loadProgress = wv.estimatedProgress;
    if (isActiveTab) {
      self.loadingBar.doubleValue = wv.estimatedProgress * 100;
    }
  }
}

#pragma mark - WKNavigationDelegate

- (void)webView:(WKWebView *)webView
    didFinishNavigation:(WKNavigation *)navigation {
  ChromeTab *tab = nil;
  for (ChromeTab *t in self.tabs) {
    if (t.webView == webView) {
      tab = t;
      break;
    }
  }
  if (tab) {
    tab.isLoading = NO;
    tab.title = webView.title ?: tab.urlString;
    dispatch_async(dispatch_get_main_queue(), ^{
      [self renderTabButtons];
      self.loadingBar.hidden = YES;
    });
  }
}

- (void)webView:(WKWebView *)webView
    didFailNavigation:(WKNavigation *)navigation
            withError:(NSError *)error {
  ChromeTab *tab = nil;
  for (ChromeTab *t in self.tabs) {
    if (t.webView == webView) {
      tab = t;
      break;
    }
  }
  if (tab) {
    tab.isLoading = NO;
    dispatch_async(dispatch_get_main_queue(), ^{
      [self renderTabButtons];
      self.loadingBar.hidden = YES;
    });
  }
}

- (void)webView:(WKWebView *)webView
    didFailProvisionalNavigation:(WKNavigation *)navigation
                       withError:(NSError *)error {
  // Handle failed navigation (e.g., no internet)
  ChromeTab *tab = nil;
  for (ChromeTab *t in self.tabs) {
    if (t.webView == webView) {
      tab = t;
      break;
    }
  }
  if (tab) {
    tab.isLoading = NO;
    tab.title = @"Error";
    dispatch_async(dispatch_get_main_queue(), ^{
      [self renderTabButtons];
      self.loadingBar.hidden = YES;
    });
  }
}

#pragma mark - WKUIDelegate (Handle new window requests → open in new tab)

- (WKWebView *)webView:(WKWebView *)webView
    createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration
               forNavigationAction:(WKNavigationAction *)navigationAction
                    windowFeatures:(WKWindowFeatures *)windowFeatures {
  // When a page requests a new window (target="_blank"), open in new tab
  NSURL *url = navigationAction.request.URL;
  if (url) {
    [self newTabWithURL:url.absoluteString];
  }
  return nil;
}

@end
