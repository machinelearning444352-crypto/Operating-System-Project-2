#import "ForceQuitWindow.h"

@interface ForceQuitWindow () <NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic, strong) NSWindow *forceQuitWindow;
@property(nonatomic, strong) NSTableView *appsTable;
@property(nonatomic, strong) NSMutableArray *runningApps;
@property(nonatomic, strong) NSButton *forceQuitButton;
@end

@implementation ForceQuitWindow

+ (instancetype)sharedInstance {
  static ForceQuitWindow *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[ForceQuitWindow alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.runningApps = [NSMutableArray arrayWithArray:@[
      @{@"name" : @"Finder", @"status" : @"Running", @"icon" : @"📁"},
      @{@"name" : @"Safari", @"status" : @"Running", @"icon" : @"🧭"},
      @{@"name" : @"Messages", @"status" : @"Running", @"icon" : @"💬"}
    ]];
  }
  return self;
}

- (void)addRunningApp:(NSString *)appName {
  for (NSDictionary *app in self.runningApps) {
    if ([app[@"name"] isEqualToString:appName])
      return;
  }

  NSString *icon = @"📱";
  if ([appName isEqualToString:@"Finder"])
    icon = @"📁";
  else if ([appName isEqualToString:@"Safari"])
    icon = @"🧭";
  else if ([appName isEqualToString:@"Messages"])
    icon = @"💬";
  else if ([appName isEqualToString:@"Notes"])
    icon = @"📝";
  else if ([appName isEqualToString:@"Calendar"])
    icon = @"📅";
  else if ([appName isEqualToString:@"Terminal"])
    icon = @"⬛";
  else if ([appName isEqualToString:@"Settings"])
    icon = @"⚙️";
  else if ([appName isEqualToString:@"Mail"])
    icon = @"✉️";
  else if ([appName isEqualToString:@"Photos"])
    icon = @"🖼️";
  else if ([appName isEqualToString:@"Music"])
    icon = @"🎵";

  [self.runningApps
      addObject:@{@"name" : appName, @"status" : @"Running", @"icon" : icon}];
  [self.appsTable reloadData];
}

- (void)removeRunningApp:(NSString *)appName {
  NSMutableArray *toRemove = [NSMutableArray array];
  for (NSDictionary *app in self.runningApps) {
    if ([app[@"name"] isEqualToString:appName]) {
      [toRemove addObject:app];
    }
  }
  [self.runningApps removeObjectsInArray:toRemove];
  [self.appsTable reloadData];
}

- (void)showWindow {
  if (self.forceQuitWindow) {
    [self.forceQuitWindow makeKeyAndOrderFront:nil];
    [self.appsTable reloadData];
    return;
  }

  NSRect frame = NSMakeRect(0, 0, 400, 350);
  self.forceQuitWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.forceQuitWindow setTitle:@"Force Quit Applications"];
  [self.forceQuitWindow center];

  NSView *contentView = [[NSView alloc] initWithFrame:frame];
  contentView.wantsLayer = YES;
  contentView.layer.backgroundColor = [[NSColor colorWithRed:0.11
                                                       green:0.11
                                                        blue:0.13
                                                       alpha:1.0] CGColor];
  [self.forceQuitWindow setContentView:contentView];

  // Header text
  NSTextField *headerLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 300, 360, 30)];
  headerLabel.stringValue =
      @"If an app doesn't respond, select it and click Force Quit.";
  headerLabel.font = [NSFont systemFontOfSize:12];
  headerLabel.textColor = [NSColor darkGrayColor];
  headerLabel.bezeled = NO;
  headerLabel.editable = NO;
  headerLabel.drawsBackground = NO;
  [contentView addSubview:headerLabel];

  // Apps table
  NSScrollView *scrollView =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 70, 360, 220)];
  scrollView.hasVerticalScroller = YES;
  scrollView.borderType = NSBezelBorder;

  self.appsTable = [[NSTableView alloc] initWithFrame:scrollView.bounds];
  self.appsTable.dataSource = self;
  self.appsTable.delegate = self;
  self.appsTable.rowHeight = 36;
  self.appsTable.headerView = nil;

  NSTableColumn *iconCol = [[NSTableColumn alloc] initWithIdentifier:@"icon"];
  iconCol.width = 40;
  [self.appsTable addTableColumn:iconCol];

  NSTableColumn *nameCol = [[NSTableColumn alloc] initWithIdentifier:@"name"];
  nameCol.width = 200;
  [self.appsTable addTableColumn:nameCol];

  NSTableColumn *statusCol =
      [[NSTableColumn alloc] initWithIdentifier:@"status"];
  statusCol.width = 100;
  [self.appsTable addTableColumn:statusCol];

  scrollView.documentView = self.appsTable;
  [contentView addSubview:scrollView];

  // Force Quit button
  self.forceQuitButton =
      [[NSButton alloc] initWithFrame:NSMakeRect(260, 20, 120, 35)];
  self.forceQuitButton.title = @"Force Quit";
  self.forceQuitButton.bezelStyle = NSBezelStyleRounded;
  self.forceQuitButton.target = self;
  self.forceQuitButton.action = @selector(forceQuitClicked:);
  [contentView addSubview:self.forceQuitButton];

  // Relaunch button
  NSButton *relaunchBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(130, 20, 120, 35)];
  relaunchBtn.title = @"Relaunch";
  relaunchBtn.bezelStyle = NSBezelStyleRounded;
  relaunchBtn.target = self;
  relaunchBtn.action = @selector(relaunchClicked:);
  [contentView addSubview:relaunchBtn];

  [self.forceQuitWindow makeKeyAndOrderFront:nil];
}

- (void)forceQuitClicked:(id)sender {
  NSInteger row = self.appsTable.selectedRow;
  if (row >= 0 && row < (NSInteger)self.runningApps.count) {
    NSDictionary *app = self.runningApps[row];
    NSString *appName = app[@"name"];

    // Don't allow quitting Finder
    if ([appName isEqualToString:@"Finder"]) {
      NSAlert *alert = [[NSAlert alloc] init];
      alert.messageText = @"Cannot Quit Finder";
      alert.informativeText =
          @"Finder is required by the system and cannot be quit.";
      [alert runModal];
      return;
    }

    [self.runningApps removeObjectAtIndex:row];
    [self.appsTable reloadData];

    // Post notification for other parts of the app
    [[NSNotificationCenter defaultCenter]
        postNotificationName:@"AppForceQuit"
                      object:nil
                    userInfo:@{@"appName" : appName}];
  }
}

- (void)relaunchClicked:(id)sender {
  NSInteger row = self.appsTable.selectedRow;
  if (row >= 0 && row < (NSInteger)self.runningApps.count) {
    NSDictionary *app = self.runningApps[row];
    NSString *appName = app[@"name"];

    // Simulate relaunch
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = [NSString stringWithFormat:@"Relaunching %@", appName];
    alert.informativeText = @"The application will be relaunched.";
    [alert runModal];
  }
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return self.runningApps.count;
}

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row {
  if (row >= (NSInteger)self.runningApps.count)
    return nil;

  NSDictionary *app = self.runningApps[row];

  NSTextField *cell = [[NSTextField alloc] init];
  cell.bezeled = NO;
  cell.editable = NO;
  cell.drawsBackground = NO;

  if ([tableColumn.identifier isEqualToString:@"icon"]) {
    cell.stringValue = app[@"icon"] ?: @"📱";
    cell.font = [NSFont systemFontOfSize:20];
    cell.alignment = NSTextAlignmentCenter;
  } else if ([tableColumn.identifier isEqualToString:@"name"]) {
    cell.stringValue = app[@"name"] ?: @"";
    cell.font = [NSFont systemFontOfSize:13];
  } else if ([tableColumn.identifier isEqualToString:@"status"]) {
    cell.stringValue = app[@"status"] ?: @"Running";
    cell.font = [NSFont systemFontOfSize:11];
    cell.textColor = [NSColor grayColor];
  }

  return cell;
}

@end
