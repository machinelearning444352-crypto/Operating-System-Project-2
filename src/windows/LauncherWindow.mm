#import "LauncherWindow.h"
#import <QuartzCore/QuartzCore.h>

// ─── Launcher Result Model ────────────────────────────────────────────────
@interface LauncherResult : NSObject
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSString *icon;
@property(nonatomic, strong) NSString *subtitle;
@property(nonatomic, strong) NSString *category;
@property(nonatomic, strong) NSString *path;
@property(nonatomic, assign) double score;
@end
@implementation LauncherResult
@end

// ─── LauncherWindow ───────────────────────────────────────────────────────
@interface LauncherWindow () <NSTextFieldDelegate, NSTableViewDelegate,
                              NSTableViewDataSource>
@property(nonatomic, strong) NSWindow *launcherPanel;
@property(nonatomic, strong) NSTextField *searchField;
@property(nonatomic, strong) NSTableView *resultsTable;
@property(nonatomic, strong) NSScrollView *resultsScroll;
@property(nonatomic, strong) NSMutableArray<LauncherResult *> *allApps;
@property(nonatomic, strong) NSMutableArray<LauncherResult *> *filteredResults;
@property(nonatomic, strong) NSVisualEffectView *blurView;
@end

@implementation LauncherWindow

+ (instancetype)sharedInstance {
  static LauncherWindow *inst;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    inst = [[LauncherWindow alloc] init];
  });
  return inst;
}

- (instancetype)init {
  if (self = [super init]) {
    _allApps = [NSMutableArray array];
    _filteredResults = [NSMutableArray array];
    [self indexApps];
  }
  return self;
}

- (void)toggle {
  if (self.launcherPanel && self.launcherPanel.isVisible) {
    [self.launcherPanel orderOut:nil];
  } else {
    [self showWindow];
  }
}

- (void)showWindow {
  if (self.launcherPanel) {
    self.searchField.stringValue = @"";
    [self updateResults:@""];
    [self.launcherPanel makeKeyAndOrderFront:nil];
    [self.launcherPanel makeFirstResponder:self.searchField];
    return;
  }

  NSScreen *screen = [NSScreen mainScreen];
  CGFloat panelW = 680, panelH = 440;
  CGFloat x = (screen.frame.size.width - panelW) / 2;
  CGFloat y = screen.frame.size.height * 0.6;

  self.launcherPanel = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(x, y, panelW, panelH)
                styleMask:(NSWindowStyleMaskBorderless |
                           NSWindowStyleMaskNonactivatingPanel)
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.launcherPanel.level = NSFloatingWindowLevel;
  self.launcherPanel.backgroundColor = [NSColor clearColor];
  self.launcherPanel.opaque = NO;
  self.launcherPanel.hasShadow = YES;
  self.launcherPanel.releasedWhenClosed = NO;
  self.launcherPanel.movableByWindowBackground = YES;

  NSView *content = self.launcherPanel.contentView;
  content.wantsLayer = YES;
  content.layer.cornerRadius = 16;
  content.layer.masksToBounds = YES;

  // Blur background
  self.blurView = [[NSVisualEffectView alloc] initWithFrame:content.bounds];
  self.blurView.material = NSVisualEffectMaterialHUDWindow;
  self.blurView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
  self.blurView.state = NSVisualEffectStateActive;
  self.blurView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [content addSubview:self.blurView];

  // Search icon
  NSTextField *searchIcon =
      [[NSTextField alloc] initWithFrame:NSMakeRect(16, panelH - 50, 30, 30)];
  searchIcon.stringValue = @"🔍";
  searchIcon.font = [NSFont systemFontOfSize:22];
  searchIcon.drawsBackground = NO;
  searchIcon.bezeled = NO;
  searchIcon.editable = NO;
  [self.blurView addSubview:searchIcon];

  // Search field
  self.searchField = [[NSTextField alloc]
      initWithFrame:NSMakeRect(50, panelH - 50, panelW - 70, 32)];
  self.searchField.font = [NSFont systemFontOfSize:22 weight:NSFontWeightLight];
  self.searchField.placeholderString = @"Spotlight Search";
  self.searchField.drawsBackground = NO;
  self.searchField.bezeled = NO;
  self.searchField.focusRingType = NSFocusRingTypeNone;
  self.searchField.textColor = [NSColor whiteColor];
  self.searchField.delegate = self;
  [self.blurView addSubview:self.searchField];

  // Separator
  NSBox *sep =
      [[NSBox alloc] initWithFrame:NSMakeRect(16, panelH - 60, panelW - 32, 1)];
  sep.boxType = NSBoxSeparator;
  [self.blurView addSubview:sep];

  // Results table
  self.resultsScroll = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 0, panelW, panelH - 65)];
  self.resultsScroll.hasVerticalScroller = YES;
  self.resultsScroll.drawsBackground = NO;
  self.resultsScroll.autoresizingMask =
      NSViewWidthSizable | NSViewHeightSizable;

  self.resultsTable =
      [[NSTableView alloc] initWithFrame:self.resultsScroll.bounds];
  self.resultsTable.dataSource = self;
  self.resultsTable.delegate = self;
  self.resultsTable.rowHeight = 40;
  self.resultsTable.headerView = nil;
  self.resultsTable.backgroundColor = [NSColor clearColor];
  self.resultsTable.selectionHighlightStyle =
      NSTableViewSelectionHighlightStyleRegular;
  self.resultsTable.doubleAction = @selector(launchSelected);
  self.resultsTable.target = self;

  NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"result"];
  col.width = panelW;
  [self.resultsTable addTableColumn:col];
  self.resultsScroll.documentView = self.resultsTable;
  [self.blurView addSubview:self.resultsScroll];

  [self updateResults:@""];
  [self.launcherPanel makeKeyAndOrderFront:nil];
  [self.launcherPanel makeFirstResponder:self.searchField];
}

#pragma mark - App Indexing

- (void)indexApps {
  [self.allApps removeAllObjects];

  // Built-in OS apps
  NSDictionary *builtIns = @{
    @"Finder" : @[ @"📁", @"File Manager" ],
    @"Safari" : @[ @"🧭", @"Web Browser" ],
    @"Mail" : @[ @"✉️", @"Email Client" ],
    @"Messages" : @[ @"💬", @"Messaging" ],
    @"Photos" : @[ @"🖼", @"Photo Library" ],
    @"Music" : @[ @"🎵", @"Music Player" ],
    @"Terminal" : @[ @"⬛", @"Command Line" ],
    @"Notes" : @[ @"📝", @"Note Taking" ],
    @"Calendar" : @[ @"📅", @"Calendar & Events" ],
    @"Settings" : @[ @"⚙️", @"System Preferences" ],
    @"Activity Monitor" : @[ @"📊", @"System Monitor" ],
    @"WiFi" : @[ @"📶", @"Network Settings" ],
    @"Antivirus" : @[ @"🛡", @"Security Scanner" ],
    @"Disk Utility" : @[ @"💽", @"Disk Management" ],
    @"Console" : @[ @"📋", @"System Logs" ],
    @"Network Utility" : @[ @"🌐", @"Network Tools" ],
    @"Automator" : @[ @"🤖", @"Automation" ],
    @"Accessibility" : @[ @"♿", @"Accessibility Settings" ],
    @"Security" : @[ @"🔒", @"Security & Privacy" ],
    @"Software Update" : @[ @"⬆️", @"System Updates" ],
    @"About This Mac" : @[ @"🖥", @"System Information" ],
    @"Force Quit" : @[ @"✕", @"Force Quit Applications" ],
  };

  for (NSString *name in builtIns) {
    LauncherResult *r = [LauncherResult new];
    r.name = name;
    r.icon = builtIns[name][0];
    r.subtitle = builtIns[name][1];
    r.category = @"VirtualOS Apps";
    r.path = @"builtin";
    [self.allApps addObject:r];
  }

  // Scan /Applications
  NSFileManager *fm = [NSFileManager defaultManager];
  NSArray *appDirs = @[
    @"/Applications", @"/System/Applications", @"/System/Applications/Utilities"
  ];
  for (NSString *dir in appDirs) {
    NSArray *contents = [fm contentsOfDirectoryAtPath:dir error:nil];
    for (NSString *item in contents) {
      if (![item hasSuffix:@".app"])
        continue;
      LauncherResult *r = [LauncherResult new];
      r.name = [item stringByDeletingPathExtension];
      r.icon = @"📦";
      r.subtitle = [dir stringByAppendingPathComponent:item];
      r.category = @"Applications";
      r.path = [dir stringByAppendingPathComponent:item];
      [self.allApps addObject:r];
    }
  }

  // Calculator & system actions
  LauncherResult *calc = [LauncherResult new];
  calc.name = @"Calculator";
  calc.icon = @"🧮";
  calc.subtitle = @"Math expressions";
  calc.category = @"System";
  calc.path = @"calc";
  [self.allApps addObject:calc];
}

- (void)updateResults:(NSString *)query {
  [self.filteredResults removeAllObjects];

  if (query.length == 0) {
    // Show top apps
    for (LauncherResult *r in self.allApps) {
      if ([r.path isEqualToString:@"builtin"]) {
        r.score = 100;
        [self.filteredResults addObject:r];
      }
    }
  } else {
    NSString *q = query.lowercaseString;

    // Check if it's a math expression
    @try {
      NSExpression *expr = [NSExpression expressionWithFormat:query];
      id result = [expr expressionValueWithObject:nil context:nil];
      if (result) {
        LauncherResult *calcR = [LauncherResult new];
        calcR.name = [NSString stringWithFormat:@"%@ = %@", query, result];
        calcR.icon = @"🧮";
        calcR.subtitle = @"Calculator Result";
        calcR.category = @"Calculator";
        calcR.path = @"none";
        calcR.score = 1000;
        [self.filteredResults addObject:calcR];
      }
    } @catch (NSException *e) { /* not a math expression */
    }

    for (LauncherResult *r in self.allApps) {
      NSString *lower = r.name.lowercaseString;
      if ([lower containsString:q]) {
        r.score = [lower hasPrefix:q] ? 200 : 100;
        if ([lower isEqualToString:q])
          r.score = 300;
        [self.filteredResults addObject:r];
      }
    }

    [self.filteredResults sortUsingComparator:^NSComparisonResult(
                              LauncherResult *a, LauncherResult *b) {
      return (a.score > b.score) ? NSOrderedAscending : NSOrderedDescending;
    }];
  }
  [self.resultsTable reloadData];
  if (self.filteredResults.count > 0) {
    [self.resultsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
                   byExtendingSelection:NO];
  }
}

#pragma mark - Actions

- (void)launchSelected {
  NSInteger row = self.resultsTable.selectedRow;
  if (row < 0 || row >= (NSInteger)self.filteredResults.count)
    return;

  LauncherResult *r = self.filteredResults[row];
  [self.launcherPanel orderOut:nil];

  if ([r.path isEqualToString:@"builtin"]) {
    // Dispatch to AppDelegate
    [[NSApp delegate] performSelector:@selector(openApp:) withObject:r.name];
  } else if ([r.path isEqualToString:@"none"] ||
             [r.path isEqualToString:@"calc"]) {
    // Calculator result or no action
  } else {
    // Launch real app
    [[NSWorkspace sharedWorkspace]
        openApplicationAtURL:[NSURL fileURLWithPath:r.path]
               configuration:[NSWorkspaceOpenConfiguration configuration]
           completionHandler:nil];
  }
}

#pragma mark - NSTextFieldDelegate

- (void)controlTextDidChange:(NSNotification *)obj {
  [self updateResults:self.searchField.stringValue];
}

- (BOOL)control:(NSControl *)control
               textView:(NSTextView *)textView
    doCommandBySelector:(SEL)commandSelector {
  if (commandSelector == @selector(moveDown:)) {
    NSInteger row = self.resultsTable.selectedRow + 1;
    if (row < (NSInteger)self.filteredResults.count) {
      [self.resultsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                     byExtendingSelection:NO];
      [self.resultsTable scrollRowToVisible:row];
    }
    return YES;
  } else if (commandSelector == @selector(moveUp:)) {
    NSInteger row = self.resultsTable.selectedRow - 1;
    if (row >= 0) {
      [self.resultsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                     byExtendingSelection:NO];
      [self.resultsTable scrollRowToVisible:row];
    }
    return YES;
  } else if (commandSelector == @selector(insertNewline:)) {
    [self launchSelected];
    return YES;
  } else if (commandSelector == @selector(cancelOperation:)) {
    [self.launcherPanel orderOut:nil];
    return YES;
  }
  return NO;
}

#pragma mark - Table DataSource / Delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
  return self.filteredResults.count;
}

- (NSView *)tableView:(NSTableView *)tv
    viewForTableColumn:(NSTableColumn *)col
                   row:(NSInteger)row {
  if (row < 0 || row >= (NSInteger)self.filteredResults.count)
    return nil;
  LauncherResult *r = self.filteredResults[row];

  NSView *cell = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, col.width, 40)];

  // Icon
  NSTextField *icon =
      [[NSTextField alloc] initWithFrame:NSMakeRect(16, 6, 30, 28)];
  icon.stringValue = r.icon;
  icon.font = [NSFont systemFontOfSize:22];
  icon.drawsBackground = NO;
  icon.bezeled = NO;
  icon.editable = NO;
  [cell addSubview:icon];

  // Name
  NSTextField *nameLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(52, 18, col.width - 170, 18)];
  nameLabel.stringValue = r.name;
  nameLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
  nameLabel.textColor = [NSColor whiteColor];
  nameLabel.drawsBackground = NO;
  nameLabel.bezeled = NO;
  nameLabel.editable = NO;
  [cell addSubview:nameLabel];

  // Subtitle
  NSTextField *subLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(52, 3, col.width - 170, 15)];
  subLabel.stringValue = r.subtitle ?: @"";
  subLabel.font = [NSFont systemFontOfSize:11];
  subLabel.textColor = [[NSColor whiteColor] colorWithAlphaComponent:0.5];
  subLabel.drawsBackground = NO;
  subLabel.bezeled = NO;
  subLabel.editable = NO;
  [cell addSubview:subLabel];

  // Category badge
  NSTextField *badge = [[NSTextField alloc]
      initWithFrame:NSMakeRect(col.width - 140, 12, 120, 16)];
  badge.stringValue = r.category ?: @"";
  badge.font = [NSFont systemFontOfSize:10];
  badge.textColor = [[NSColor whiteColor] colorWithAlphaComponent:0.35];
  badge.alignment = NSTextAlignmentRight;
  badge.drawsBackground = NO;
  badge.bezeled = NO;
  badge.editable = NO;
  [cell addSubview:badge];

  return cell;
}

@end
