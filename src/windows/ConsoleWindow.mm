#import "ConsoleWindow.h"
#import "../services/AdvancedKernel.h"

@interface ConsoleWindow () <NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSTableView *logTable;
@property(nonatomic, strong) NSMutableArray *logEntries;
@property(nonatomic, strong) NSTimer *refreshTimer;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSSearchField *filterField;
@property(nonatomic, strong) NSPopUpButton *levelFilter;
@property(nonatomic, strong) NSPopUpButton *facilityFilter;
@property(nonatomic, strong) NSOutlineView *sourceOutline;
@end

@implementation ConsoleWindow

+ (instancetype)sharedInstance {
  static ConsoleWindow *inst;
  static dispatch_once_t t;
  dispatch_once(&t, ^{
    inst = [[self alloc] init];
  });
  return inst;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _logEntries = [NSMutableArray array];
  }
  return self;
}

- (void)showWindow {
  if (self.window) {
    [self.window makeKeyAndOrderFront:nil];
    return;
  }

  self.window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(80, 80, 1000, 650)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.window.title = @"Console";
  self.window.backgroundColor = [NSColor colorWithRed:0.11
                                                green:0.11
                                                 blue:0.13
                                                alpha:1.0];
  self.window.minSize = NSMakeSize(700, 400);

  NSView *content = self.window.contentView;

  // ===== Toolbar =====
  NSView *toolbar = [[NSView alloc] initWithFrame:NSMakeRect(0, 610, 1000, 40)];
  toolbar.wantsLayer = YES;
  toolbar.layer.backgroundColor =
      [NSColor controlBackgroundColor].CGColor;
  toolbar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;

  NSButton *clearBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(10, 6, 60, 28)];
  clearBtn.title = @"Clear";
  clearBtn.bezelStyle = NSBezelStyleRounded;
  clearBtn.target = self;
  clearBtn.action = @selector(clearLogs:);
  [toolbar addSubview:clearBtn];

  NSButton *pauseBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(80, 6, 60, 28)];
  pauseBtn.title = @"Pause";
  pauseBtn.bezelStyle = NSBezelStyleRounded;
  [toolbar addSubview:pauseBtn];

  NSButton *saveBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(150, 6, 60, 28)];
  saveBtn.title = @"Save";
  saveBtn.bezelStyle = NSBezelStyleRounded;
  [toolbar addSubview:saveBtn];

  // Level filter
  self.levelFilter =
      [[NSPopUpButton alloc] initWithFrame:NSMakeRect(240, 6, 120, 28)];
  [self.levelFilter addItemsWithTitles:@[
    @"All Levels", @"Emergency", @"Alert", @"Critical", @"Error", @"Warning",
    @"Notice", @"Info", @"Debug"
  ]];
  [toolbar addSubview:self.levelFilter];

  // Facility filter
  self.facilityFilter =
      [[NSPopUpButton alloc] initWithFrame:NSMakeRect(370, 6, 120, 28)];
  [self.facilityFilter addItemsWithTitles:@[
    @"All Sources", @"Kernel", @"Process", @"Memory", @"VFS", @"Network",
    @"Security", @"Syscall"
  ]];
  [toolbar addSubview:self.facilityFilter];

  self.filterField =
      [[NSSearchField alloc] initWithFrame:NSMakeRect(700, 6, 290, 28)];
  self.filterField.placeholderString = @"Filter log messages...";
  self.filterField.autoresizingMask = NSViewMinXMargin;
  [toolbar addSubview:self.filterField];

  [content addSubview:toolbar];

  // ===== Source Sidebar =====
  NSScrollView *sideScroll =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 30, 200, 580)];
  sideScroll.hasVerticalScroller = YES;
  sideScroll.backgroundColor = [NSColor colorWithRed:0.14
                                               green:0.14
                                                blue:0.17
                                               alpha:1.0];
  sideScroll.autoresizingMask = NSViewHeightSizable;

  self.sourceOutline = [[NSOutlineView alloc] initWithFrame:sideScroll.bounds];
  self.sourceOutline.rowHeight = 22;
  self.sourceOutline.backgroundColor = [NSColor colorWithRed:0.14
                                                       green:0.14
                                                        blue:0.17
                                                       alpha:1.0];
  NSTableColumn *srcCol = [[NSTableColumn alloc] initWithIdentifier:@"source"];
  srcCol.title = @"Log Sources";
  srcCol.width = 180;
  [self.sourceOutline addTableColumn:srcCol];
  self.sourceOutline.outlineTableColumn = srcCol;
  sideScroll.documentView = self.sourceOutline;
  [content addSubview:sideScroll];

  // ===== Log Table =====
  NSScrollView *scrollView =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(200, 30, 800, 580)];
  scrollView.hasVerticalScroller = YES;
  scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  scrollView.backgroundColor = [NSColor colorWithRed:0.08
                                               green:0.08
                                                blue:0.10
                                               alpha:1.0];

  self.logTable = [[NSTableView alloc] initWithFrame:scrollView.bounds];
  self.logTable.dataSource = self;
  self.logTable.delegate = self;
  self.logTable.backgroundColor = [NSColor colorWithRed:0.08
                                                  green:0.08
                                                   blue:0.10
                                                  alpha:1.0];
  self.logTable.rowHeight = 20;
  self.logTable.usesAlternatingRowBackgroundColors = NO;

  NSArray *cols = @[
    @[ @"time", @"Time", @(120) ], @[ @"level", @"Level", @(70) ],
    @[ @"facility", @"Source", @(80) ], @[ @"pid", @"PID", @(50) ],
    @[ @"message", @"Message", @(480) ]
  ];
  for (NSArray *c in cols) {
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:c[0]];
    col.title = c[1];
    col.width = [c[2] floatValue];
    [self.logTable addTableColumn:col];
  }
  scrollView.documentView = self.logTable;
  [content addSubview:scrollView];

  // ===== Status Bar =====
  NSView *statusBar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 30)];
  statusBar.wantsLayer = YES;
  statusBar.layer.backgroundColor =
      [NSColor controlBackgroundColor].CGColor;
  statusBar.autoresizingMask = NSViewWidthSizable;
  self.statusLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(10, 5, 500, 18)];
  self.statusLabel.stringValue = @"0 messages";
  self.statusLabel.font = [NSFont systemFontOfSize:11];
  self.statusLabel.textColor = [NSColor grayColor];
  self.statusLabel.editable = NO;
  self.statusLabel.bordered = NO;
  self.statusLabel.drawsBackground = NO;
  [statusBar addSubview:self.statusLabel];
  [content addSubview:statusBar];

  // Generate sample log entries
  [self generateSampleLogs];

  self.refreshTimer =
      [NSTimer scheduledTimerWithTimeInterval:3.0
                                       target:self
                                     selector:@selector(addNewLog:)
                                     userInfo:nil
                                      repeats:YES];

  [self.window makeKeyAndOrderFront:nil];
}

- (void)generateSampleLogs {
  NSArray *messages = @[
    @[ @"0", @"INFO", @"Kernel", @"System boot completed successfully" ],
    @[
      @"0", @"INFO", @"Memory",
      @"Virtual memory subsystem initialized: 16384 pages"
    ],
    @[ @"0", @"INFO", @"Process", @"init (PID 1) started" ],
    @[ @"0", @"INFO", @"VFS", @"Root filesystem mounted: /dev/disk0s1 on /" ],
    @[ @"0", @"NOTICE", @"Network", @"en0: link speed 1000 Mbps, full-duplex" ],
    @[ @"0", @"DEBUG", @"Syscall", @"syscall fork (#1) -> 42" ],
    @[ @"0", @"INFO", @"Security", @"Sandbox profile 'default' loaded" ],
    @[ @"0", @"WARNING", @"Memory", @"Memory pressure elevated: 82% used" ],
    @[ @"0", @"INFO", @"Process", @"launchd started 27 system services" ],
    @[ @"0", @"DEBUG", @"VFS", @"File descriptor table expanded to 1024" ],
    @[
      @"0", @"INFO", @"Kernel", @"CPU topology: 8 cores (4P + 4E), 8 threads"
    ],
    @[
      @"0", @"NOTICE", @"Security",
      @"Gatekeeper check passed for /Applications/Safari.app"
    ],
    @[
      @"0", @"INFO", @"Network", @"DNS resolver configured: 8.8.8.8, 8.8.4.4"
    ],
    @[
      @"0", @"DEBUG", @"Memory",
      @"Slab cache 'kmalloc-256' created, 16 objects/slab"
    ],
    @[ @"0", @"INFO", @"Process", @"WindowServer started with PID 88" ],
    @[
      @"0", @"INFO", @"Kernel",
      @"Power management: battery at 92%, AC connected"
    ],
    @[ @"0", @"ERROR", @"Network", @"Connection timeout: api.weather.com:443" ],
    @[
      @"0", @"INFO", @"VFS", @"TimeMachine backup mounted at /Volumes/Backup"
    ],
    @[
      @"0", @"WARNING", @"Security",
      @"Failed login attempt for user 'admin' (3 of 5)"
    ],
    @[
      @"0", @"INFO", @"Process", @"Spotlight indexing completed: 142,837 files"
    ],
  ];

  NSDateFormatter *df = [[NSDateFormatter alloc] init];
  df.dateFormat = @"HH:mm:ss.SSS";
  NSDate *now = [NSDate date];

  for (NSUInteger i = 0; i < messages.count; i++) {
    NSDate *time = [now dateByAddingTimeInterval:-(double)(messages.count - i)];
    [self.logEntries addObject:@{
      @"time" : [df stringFromDate:time],
      @"level" : messages[i][1],
      @"facility" : messages[i][2],
      @"pid" : @(arc4random_uniform(500)),
      @"message" : messages[i][3]
    }];
  }
  [self.logTable reloadData];
  self.statusLabel.stringValue = [NSString
      stringWithFormat:@"%lu messages", (unsigned long)self.logEntries.count];
}

- (void)addNewLog:(NSTimer *)timer {
  NSArray *newMsgs = @[
    @[ @"INFO", @"Kernel", @"Heartbeat: system uptime 3h 42m, load avg 1.2" ],
    @[ @"DEBUG", @"Syscall", @"syscall read (#2) -> 4096 bytes" ],
    @[ @"INFO", @"Process", @"Process kworker/0:0 scheduled on CPU 0" ],
    @[ @"WARNING", @"Memory", @"Page cache pressure: evicting cached pages" ],
    @[ @"DEBUG", @"VFS", @"inode_lookup: /usr/lib/libSystem.B.dylib" ],
  ];
  NSArray *msg = newMsgs[arc4random_uniform((uint32_t)newMsgs.count)];

  NSDateFormatter *df = [[NSDateFormatter alloc] init];
  df.dateFormat = @"HH:mm:ss.SSS";

  [self.logEntries addObject:@{
    @"time" : [df stringFromDate:[NSDate date]],
    @"level" : msg[0],
    @"facility" : msg[1],
    @"pid" : @(arc4random_uniform(500)),
    @"message" : msg[2]
  }];

  [self.logTable reloadData];
  [self.logTable scrollRowToVisible:self.logEntries.count - 1];
  self.statusLabel.stringValue = [NSString
      stringWithFormat:@"%lu messages", (unsigned long)self.logEntries.count];
}

- (void)clearLogs:(id)sender {
  [self.logEntries removeAllObjects];
  [self.logTable reloadData];
  self.statusLabel.stringValue = @"0 messages";
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
  return self.logEntries.count;
}

- (NSView *)tableView:(NSTableView *)tv
    viewForTableColumn:(NSTableColumn *)col
                   row:(NSInteger)row {
  NSTableCellView *cell = [tv makeViewWithIdentifier:col.identifier owner:self];
  if (!cell) {
    cell =
        [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, col.width, 20)];
    cell.identifier = col.identifier;
    NSTextField *tf = [[NSTextField alloc] initWithFrame:cell.bounds];
    tf.editable = NO;
    tf.bordered = NO;
    tf.drawsBackground = NO;
    tf.font = [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightRegular];
    tf.lineBreakMode = NSLineBreakByTruncatingTail;
    cell.textField = tf;
    [cell addSubview:tf];
  }

  NSDictionary *entry = self.logEntries[row];
  cell.textField.stringValue =
      [NSString stringWithFormat:@"%@", entry[col.identifier]];

  // Color by level
  NSString *level = entry[@"level"];
  if ([level isEqualToString:@"ERROR"])
    cell.textField.textColor = [NSColor systemRedColor];
  else if ([level isEqualToString:@"WARNING"])
    cell.textField.textColor = [NSColor systemYellowColor];
  else if ([level isEqualToString:@"DEBUG"])
    cell.textField.textColor = [NSColor systemGrayColor];
  else if ([level isEqualToString:@"NOTICE"])
    cell.textField.textColor = [NSColor systemCyanColor];
  else
    cell.textField.textColor = [NSColor colorWithWhite:0.85 alpha:1.0];

  return cell;
}

- (void)dealloc {
  [self.refreshTimer invalidate];
}

@end
