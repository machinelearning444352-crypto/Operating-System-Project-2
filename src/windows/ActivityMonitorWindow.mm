#import "ActivityMonitorWindow.h"
#import <QuartzCore/QuartzCore.h>
#include <mach/mach.h>
#include <mach/mach_host.h>
#include <sys/sysctl.h>

#define AM_BG [NSColor windowBackgroundColor]
#define AM_SIDEBAR_BG [NSColor controlBackgroundColor]
#define AM_TEXT_PRIMARY [NSColor labelColor]
#define AM_TEXT_SECONDARY [NSColor secondaryLabelColor]
#define AM_BORDER [NSColor separatorColor]

// ─── AM_GraphView ───────────────────────────────────────────────────────────
// A highly advanced, custom-drawn graph view for CPU/Network history
@interface AM_GraphView : NSView
@property(nonatomic, strong) NSMutableArray<NSNumber *> *dataPoints;
@property(nonatomic, strong) NSColor *lineColor;
@property(nonatomic, strong) NSColor *fillColor;
@property(nonatomic, assign) CGFloat maxValue;
- (void)addPoint:(CGFloat)val;
@end

@implementation AM_GraphView
- (instancetype)initWithFrame:(NSRect)frameRect {
  if (self = [super initWithFrame:frameRect]) {
    _dataPoints = [NSMutableArray array];
    for (int i = 0; i < 60; i++)
      [_dataPoints addObject:@(0)]; // 60 seconds history
    _lineColor = [NSColor systemBlueColor];
    _fillColor = [[NSColor systemBlueColor] colorWithAlphaComponent:0.2];
    _maxValue = 100.0;
  }
  return self;
}

- (void)addPoint:(CGFloat)val {
  [_dataPoints removeObjectAtIndex:0];
  [_dataPoints addObject:@(val)];
  self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];

  if (_dataPoints.count < 2)
    return;

  NSRect b = self.bounds;

  // Draw grid
  [[[NSColor separatorColor] colorWithAlphaComponent:0.3] setStroke];
  NSBezierPath *grid = [NSBezierPath bezierPath];
  [grid moveToPoint:NSMakePoint(0, b.size.height / 2)];
  [grid lineToPoint:NSMakePoint(b.size.width, b.size.height / 2)];
  for (int x = 0; x < b.size.width; x += 40) {
    [grid moveToPoint:NSMakePoint(x, 0)];
    [grid lineToPoint:NSMakePoint(x, b.size.height)];
  }
  grid.lineWidth = 1;
  [grid stroke];

  NSBezierPath *path = [NSBezierPath bezierPath];
  NSBezierPath *fillPath = [NSBezierPath bezierPath];

  CGFloat stepX = b.size.width / (CGFloat)(_dataPoints.count - 1);

  [fillPath moveToPoint:NSMakePoint(b.size.width, 0)];
  [fillPath lineToPoint:NSMakePoint(0, 0)];

  for (NSUInteger i = 0; i < _dataPoints.count; i++) {
    CGFloat val = [_dataPoints[i] floatValue];
    CGFloat pct = val / _maxValue;
    if (pct > 1.0)
      pct = 1.0;

    CGFloat x = i * stepX;
    CGFloat y = pct * b.size.height;

    if (i == 0) {
      [path moveToPoint:NSMakePoint(x, y)];
      [fillPath lineToPoint:NSMakePoint(x, y)];
    } else {
      [path lineToPoint:NSMakePoint(x, y)];
      [fillPath lineToPoint:NSMakePoint(x, y)];
    }
  }

  [fillPath lineToPoint:NSMakePoint(b.size.width, 0)];
  [fillPath closePath];

  [_fillColor setFill];
  [fillPath fill];

  [_lineColor setStroke];
  path.lineWidth = 2.0;
  path.lineJoinStyle = NSRoundLineJoinStyle;
  [path stroke];
}
@end

// ─── AM_PieChartView ────────────────────────────────────────────────────────
@interface AM_PieChartView : NSView
@property(nonatomic, assign) CGFloat val1;
@property(nonatomic, assign) CGFloat val2;
@property(nonatomic, assign) CGFloat val3;
@property(nonatomic, strong) NSColor *col1;
@property(nonatomic, strong) NSColor *col2;
@property(nonatomic, strong) NSColor *col3;
@end

@implementation AM_PieChartView
- (void)drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];

  CGFloat w = self.bounds.size.width;
  CGFloat h = self.bounds.size.height;
  CGFloat r = MIN(w, h) / 2.0 - 10;
  NSPoint c = NSMakePoint(w / 2, h / 2);

  CGFloat total = _val1 + _val2 + _val3;
  if (total == 0)
    return;

  CGFloat a1 = (_val1 / total) * 360;
  CGFloat a2 = (_val2 / total) * 360;
  CGFloat a3 = (_val3 / total) * 360;

  CGFloat startIdx = 90;

  if (_val1 > 0) {
    NSBezierPath *p1 = [NSBezierPath bezierPath];
    [p1 moveToPoint:c];
    [p1 appendBezierPathWithArcWithCenter:c
                                   radius:r
                               startAngle:startIdx
                                 endAngle:startIdx - a1
                                clockwise:YES];
    [p1 closePath];
    [_col1 setFill];
    [p1 fill];
    startIdx -= a1;
  }
  if (_val2 > 0) {
    NSBezierPath *p2 = [NSBezierPath bezierPath];
    [p2 moveToPoint:c];
    [p2 appendBezierPathWithArcWithCenter:c
                                   radius:r
                               startAngle:startIdx
                                 endAngle:startIdx - a2
                                clockwise:YES];
    [p2 closePath];
    [_col2 setFill];
    [p2 fill];
    startIdx -= a2;
  }
  if (_val3 > 0) {
    NSBezierPath *p3 = [NSBezierPath bezierPath];
    [p3 moveToPoint:c];
    [p3 appendBezierPathWithArcWithCenter:c
                                   radius:r
                               startAngle:startIdx
                                 endAngle:startIdx - a3
                                clockwise:YES];
    [p3 closePath];
    [_col3 setFill];
    [p3 fill];
  }

  // Inner circle for donut look
  NSBezierPath *inner = [NSBezierPath
      bezierPathWithOvalInRect:NSMakeRect(c.x - r * 0.5, c.y - r * 0.5, r, r)];
  [[NSColor windowBackgroundColor] setFill];
  [inner fill];
}
@end

// ─── ActivityMonitorWindow ──────────────────────────────────────────────────

@interface AMProcessNode : NSObject
@property(nonatomic, assign) int pid;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, assign) double cpuPct;
@property(nonatomic, assign) uint64_t memBytes;
@property(nonatomic, assign) int threads;
@property(nonatomic, assign) int ports;
@property(nonatomic, strong) NSString *user;
@end
@implementation AMProcessNode
@end

@interface ActivityMonitorWindow () <NSTableViewDelegate, NSTableViewDataSource>

@property(nonatomic, strong) NSWindow *amWindow;
@property(nonatomic, strong) NSSegmentedControl *tabSelector;
@property(nonatomic, strong) NSSearchField *searchField;
@property(nonatomic, strong) NSTableView *processTable;

@property(nonatomic, strong) NSMutableArray<AMProcessNode *> *masterList;
@property(nonatomic, strong) NSMutableArray<AMProcessNode *> *displayList;

@property(nonatomic, strong) AM_GraphView *cpuGraph;
@property(nonatomic, strong) AM_PieChartView *memPie;
@property(nonatomic, strong) NSTimer *updateTimer;

// Detailed Text Labels
@property(nonatomic, strong) NSTextField *lblSystem;
@property(nonatomic, strong) NSTextField *lblUser;
@property(nonatomic, strong) NSTextField *lblIdle;
@property(nonatomic, strong) NSTextField *lblThreads;
@property(nonatomic, strong) NSTextField *lblProcesses;

@end

@implementation ActivityMonitorWindow

+ (instancetype)sharedInstance {
  static ActivityMonitorWindow *instance;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[ActivityMonitorWindow alloc] init];
  });
  return instance;
}

- (instancetype)init {
  if (self = [super init]) {
    _masterList = [NSMutableArray array];
    _displayList = [NSMutableArray array];
  }
  return self;
}

- (void)showWindow {
  if (self.amWindow) {
    [self.amWindow makeKeyAndOrderFront:nil];
    return;
  }

  NSRect frame = NSMakeRect(100, 100, 1000, 700);
  self.amWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable |
                          NSWindowStyleMaskFullSizeContentView
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.amWindow setTitle:@"Activity Monitor"];
  self.amWindow.releasedWhenClosed = NO;
  self.amWindow.titlebarAppearsTransparent = YES;
  self.amWindow.minSize = NSMakeSize(800, 500);

  NSView *root = [[NSView alloc] initWithFrame:frame];
  root.wantsLayer = YES;
  root.layer.backgroundColor = [AM_BG CGColor];
  [self.amWindow setContentView:root];

  [self buildTopToolbar:root frame:frame];
  [self buildBottomPane:root frame:frame];
  [self buildTableArea:root frame:frame];

  [self.amWindow makeKeyAndOrderFront:nil];

  self.updateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                      target:self
                                                    selector:@selector(tick)
                                                    userInfo:nil
                                                     repeats:YES];
  [self tick];
}

- (void)buildTopToolbar:(NSView *)root frame:(NSRect)frame {
  NSVisualEffectView *topBar = [[NSVisualEffectView alloc]
      initWithFrame:NSMakeRect(0, frame.size.height - 70, frame.size.width,
                               70)];
  topBar.material = NSVisualEffectMaterialTitlebar;
  topBar.state = NSVisualEffectStateFollowsWindowActiveState;
  topBar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [root addSubview:topBar];

  NSView *sep =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, 1)];
  sep.wantsLayer = YES;
  sep.layer.backgroundColor = [AM_BORDER CGColor];
  sep.autoresizingMask = NSViewWidthSizable;
  [topBar addSubview:sep];

  // Tabs
  self.tabSelector = [NSSegmentedControl
      segmentedControlWithLabels:@[
        @"CPU", @"Memory", @"Energy", @"Disk", @"Network"
      ]
                    trackingMode:NSSegmentSwitchTrackingSelectOne
                          target:self
                          action:@selector(tabChanged)];
  self.tabSelector.frame =
      NSMakeRect((frame.size.width - 400) / 2, 16, 400, 30);
  self.tabSelector.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin;
  self.tabSelector.selectedSegment = 0;
  [topBar addSubview:self.tabSelector];

  // Search
  self.searchField = [[NSSearchField alloc]
      initWithFrame:NSMakeRect(frame.size.width - 220, 20, 200, 24)];
  self.searchField.autoresizingMask = NSViewMinXMargin;
  self.searchField.focusRingType = NSFocusRingTypeNone;
  self.searchField.placeholderString = @"Search";
  [topBar addSubview:self.searchField];

  // Left Icons
  NSButton *quitBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(80, 20, 30, 24)];
  quitBtn.title = @"✕";
  quitBtn.bezelStyle = NSBezelStyleRounded;
  quitBtn.font = [NSFont systemFontOfSize:12];
  [topBar addSubview:quitBtn];

  NSButton *infoBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(115, 20, 30, 24)];
  infoBtn.title = @"ℹ";
  infoBtn.bezelStyle = NSBezelStyleRounded;
  infoBtn.font = [NSFont systemFontOfSize:14];
  [topBar addSubview:infoBtn];
}

- (void)buildBottomPane:(NSView *)root frame:(NSRect)frame {
  CGFloat bottomH = 200;
  NSView *bp = [[NSView alloc]
      initWithFrame:NSMakeRect(0, 0, frame.size.width, bottomH)];
  bp.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
  bp.wantsLayer = YES;
  bp.layer.backgroundColor = [AM_SIDEBAR_BG CGColor];
  [root addSubview:bp];

  NSView *sep = [[NSView alloc]
      initWithFrame:NSMakeRect(0, bottomH - 1, frame.size.width, 1)];
  sep.wantsLayer = YES;
  sep.layer.backgroundColor = [AM_BORDER CGColor];
  sep.autoresizingMask = NSViewWidthSizable;
  [bp addSubview:sep];

  // Section 1: Detailed Text Numbers
  NSView *s1 = [[NSView alloc] initWithFrame:NSMakeRect(20, 20, 250, 160)];
  [bp addSubview:s1];

  NSTextField *tSys, *tUsr, *tIdl, *tThr, *tPrc;
  [self makeKVLabel:@"System"
           valLabel:&tSys
                  y:140
             inView:s1
              color:[NSColor systemRedColor]];
  self.lblSystem = tSys;

  [self makeKVLabel:@"User"
           valLabel:&tUsr
                  y:115
             inView:s1
              color:[NSColor systemBlueColor]];
  self.lblUser = tUsr;

  [self makeKVLabel:@"Idle"
           valLabel:&tIdl
                  y:90
             inView:s1
              color:AM_TEXT_SECONDARY];
  self.lblIdle = tIdl;

  NSView *d = [[NSView alloc] initWithFrame:NSMakeRect(0, 75, 200, 1)];
  d.wantsLayer = YES;
  d.layer.backgroundColor = [AM_BORDER CGColor];
  [s1 addSubview:d];

  [self makeKVLabel:@"Threads"
           valLabel:&tThr
                  y:50
             inView:s1
              color:AM_TEXT_PRIMARY];
  self.lblThreads = tThr;

  [self makeKVLabel:@"Processes"
           valLabel:&tPrc
                  y:25
             inView:s1
              color:AM_TEXT_PRIMARY];
  self.lblProcesses = tPrc;

  // Section 2: Huge Line Graph
  self.cpuGraph =
      [[AM_GraphView alloc] initWithFrame:NSMakeRect(300, 25, 450, 140)];
  self.cpuGraph.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.cpuGraph.maxValue = 100.0;
  self.cpuGraph.lineColor = [NSColor systemBlueColor];
  self.cpuGraph.fillColor =
      [[NSColor systemBlueColor] colorWithAlphaComponent:0.15];
  [bp addSubview:self.cpuGraph];

  NSTextField *gt =
      [[NSTextField alloc] initWithFrame:NSMakeRect(300, 170, 200, 20)];
  gt.stringValue = @"CPU History";
  gt.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
  gt.textColor = AM_TEXT_SECONDARY;
  gt.drawsBackground = NO;
  gt.bezeled = NO;
  gt.editable = NO;
  [bp addSubview:gt];

  // Section 3: Mem Pie Chart
  self.memPie = [[AM_PieChartView alloc]
      initWithFrame:NSMakeRect(frame.size.width - 200, 25, 140, 140)];
  self.memPie.autoresizingMask = NSViewMinXMargin | NSViewHeightSizable;
  self.memPie.col1 = [NSColor systemBlueColor];   // App Mem
  self.memPie.col2 = [NSColor systemRedColor];    // Wired
  self.memPie.col3 = [NSColor systemYellowColor]; // Compressed
  [bp addSubview:self.memPie];
}

- (void)makeKVLabel:(NSString *)key
           valLabel:(NSTextField **)vLbl
                  y:(CGFloat)y
             inView:(NSView *)inView
              color:(NSColor *)tc {
  NSTextField *k =
      [[NSTextField alloc] initWithFrame:NSMakeRect(0, y, 100, 20)];
  k.stringValue = key;
  k.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  k.textColor = AM_TEXT_PRIMARY;
  k.alignment = NSTextAlignmentRight;
  k.drawsBackground = NO;
  k.bezeled = NO;
  k.editable = NO;
  [inView addSubview:k];

  *vLbl = [[NSTextField alloc] initWithFrame:NSMakeRect(110, y, 100, 20)];
  (*vLbl).stringValue = @"0.00 %";
  (*vLbl).font = [NSFont systemFontOfSize:13 weight:NSFontWeightBold];
  (*vLbl).textColor = tc;
  (*vLbl).drawsBackground = NO;
  (*vLbl).bezeled = NO;
  (*vLbl).editable = NO;
  [inView addSubview:*vLbl];
}

- (void)buildTableArea:(NSView *)root frame:(NSRect)frame {
  CGFloat topH = 70;
  CGFloat botH = 200;
  NSRect tbFrame =
      NSMakeRect(0, botH, frame.size.width, frame.size.height - topH - botH);

  NSScrollView *sv = [[NSScrollView alloc] initWithFrame:tbFrame];
  sv.hasVerticalScroller = YES;
  sv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  sv.drawsBackground = NO;
  [root addSubview:sv];

  self.processTable = [[NSTableView alloc] initWithFrame:sv.bounds];
  self.processTable.dataSource = self;
  self.processTable.delegate = self;
  self.processTable.rowHeight = 24;
  self.processTable.style = NSTableViewStyleFullWidth;
  self.processTable.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
  self.processTable.gridColor = [AM_BORDER colorWithAlphaComponent:0.4];
  self.processTable.backgroundColor = [NSColor clearColor];

  [self addCol:@"Name" width:250];
  [self addCol:@"% CPU" width:80];
  [self addCol:@"CPU Time" width:100];
  [self addCol:@"Threads" width:80];
  [self addCol:@"Idle Wake Ups" width:100];
  [self addCol:@"PID" width:80];
  [self addCol:@"User" width:120];

  sv.documentView = self.processTable;
}

- (void)addCol:(NSString *)title width:(CGFloat)w {
  NSTableColumn *c = [[NSTableColumn alloc] initWithIdentifier:title];
  c.title = title;
  c.width = w;
  [self.processTable addTableColumn:c];
}

- (void)tabChanged {
  // Normally swaps columns and bottom details, but left as a UI stub
  NSString *labels[] = {@"CPU History", @"Memory History", @"Energy Impact",
                        @"Disk Read/Write", @"Network Data"};

  NSView *bp = [self.amWindow.contentView.subviews objectAtIndex:1];
  for (NSView *v in bp.subviews) {
    if ([v isKindOfClass:[NSTextField class]] &&
        [((NSTextField *)v).stringValue containsString:@"History"]) {
      ((NSTextField *)v).stringValue = labels[self.tabSelector.selectedSegment];
    }
  }
}

- (void)tick {
  // Read real sysctl metrics just to give realistic data dynamically
  int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
  size_t size = 0;
  sysctl(mib, 4, NULL, &size, NULL, 0);
  struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
  if (!procs)
    return;
  sysctl(mib, 4, procs, &size, NULL, 0);
  NSUInteger count = size / sizeof(struct kinfo_proc);

  [self.masterList removeAllObjects];

  NSUInteger totalThreads = 0;
  for (NSUInteger i = 0; i < count; i++) {
    struct kinfo_proc *p = &procs[i];
    NSString *name = @(p->kp_proc.p_comm);
    if (name.length == 0)
      continue;

    AMProcessNode *node = [AMProcessNode new];
    node.pid = p->kp_proc.p_pid;
    node.name = name;
    node.user = (p->kp_eproc.e_pcred.p_ruid == 0) ? @"root" : NSUserName();
    // Simulate cpu usage based on pid hashing for dynamic feel without heavy
    // host queries
    node.cpuPct = (double)(((node.pid * 17) % 100) / 10.0);
    if ([name isEqualToString:@"WindowServer"])
      node.cpuPct += 15.0;
    if ([name isEqualToString:@"macOSDesktop"])
      node.cpuPct += 20.0;

    node.threads = 1 + ((node.pid * 7) % 30);
    totalThreads += node.threads;

    [self.masterList addObject:node];
  }
  free(procs);

  // Sort by CPU
  [self.masterList sortUsingComparator:^NSComparisonResult(
                       AMProcessNode *obj1, AMProcessNode *obj2) {
    if (obj1.cpuPct > obj2.cpuPct)
      return NSOrderedAscending;
    if (obj1.cpuPct < obj2.cpuPct)
      return NSOrderedDescending;
    return NSOrderedSame;
  }];

  // Filter
  [self.displayList setArray:self.masterList];
  NSString *q = self.searchField.stringValue.lowercaseString;
  if (q.length > 0) {
    NSPredicate *pred =
        [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", q];
    [self.displayList filterUsingPredicate:pred];
  }

  [self.processTable reloadData];

  // Update numbers
  double sys = 0, usr = 0;
  for (AMProcessNode *n in self.masterList) {
    if ([n.user isEqualToString:@"root"])
      sys += n.cpuPct;
    else
      usr += n.cpuPct;
  }

  self.lblSystem.stringValue = [NSString stringWithFormat:@"%.2f %%", sys];
  self.lblUser.stringValue = [NSString stringWithFormat:@"%.2f %%", usr];
  double totalC = sys + usr;
  if (totalC > 100)
    totalC = 100;
  self.lblIdle.stringValue =
      [NSString stringWithFormat:@"%.2f %%", 100.0 - totalC];

  self.lblThreads.stringValue =
      [NSString stringWithFormat:@"%lu", totalThreads];
  self.lblProcesses.stringValue =
      [NSString stringWithFormat:@"%lu", self.masterList.count];

  [self.cpuGraph addPoint:totalC];

  // Mem Pie simulation
  host_name_port_t h = mach_host_self();
  vm_size_t pgSize;
  host_page_size(h, &pgSize);
  vm_statistics64_data_t vmStats;
  mach_msg_type_number_t count64 = HOST_VM_INFO64_COUNT;
  host_statistics64(h, HOST_VM_INFO64, (host_info64_t)&vmStats, &count64);

  self.memPie.val1 = vmStats.active_count * pgSize;
  self.memPie.val2 = vmStats.wire_count * pgSize;
  self.memPie.val3 = vmStats.compressor_page_count * pgSize;
  self.memPie.needsDisplay = YES;
}

#pragma mark - Table
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return self.displayList.count;
}

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row {
  AMProcessNode *n = self.displayList[row];

  NSTextField *t = [[NSTextField alloc]
      initWithFrame:NSMakeRect(0, 0, tableColumn.width, 24)];
  t.drawsBackground = NO;
  t.bezeled = NO;
  t.editable = NO;
  t.font = [NSFont systemFontOfSize:12];
  t.textColor = AM_TEXT_PRIMARY;

  NSString *colId = tableColumn.identifier;
  if ([colId isEqualToString:@"Name"]) {
    // Inject mock app icons dynamically
    NSView *wrapper =
        [[NSView alloc] initWithFrame:NSMakeRect(0, 0, tableColumn.width, 24)];
    NSTextField *icon =
        [[NSTextField alloc] initWithFrame:NSMakeRect(2, 2, 20, 20)];
    icon.stringValue = @"􀊖"; // default exact symbol
    if ([n.name containsString:@"Safari"])
      icon.stringValue = @"􀎿";
    if ([n.name containsString:@"WindowServer"])
      icon.stringValue = @"􀏁";
    if ([n.user isEqualToString:@"root"])
      icon.stringValue = @"􀢄";
    icon.font = [NSFont systemFontOfSize:14];
    icon.drawsBackground = NO;
    icon.bezeled = NO;
    icon.editable = NO;
    [wrapper addSubview:icon];

    t.frame = NSMakeRect(25, 3, tableColumn.width - 25, 20);
    t.stringValue = n.name;
    [wrapper addSubview:t];
    return wrapper;
  } else if ([colId isEqualToString:@"% CPU"])
    t.stringValue = [NSString stringWithFormat:@"%.1f", n.cpuPct];
  else if ([colId isEqualToString:@"CPU Time"])
    t.stringValue = [NSString stringWithFormat:@"%d:%02d.%02d", n.threads,
                                               (n.pid % 60), (n.pid % 100)];
  else if ([colId isEqualToString:@"Threads"])
    t.stringValue = [NSString stringWithFormat:@"%d", n.threads];
  else if ([colId isEqualToString:@"Idle Wake Ups"])
    t.stringValue = [NSString stringWithFormat:@"%d", n.pid * 3 % 500];
  else if ([colId isEqualToString:@"PID"])
    t.stringValue = [NSString stringWithFormat:@"%d", n.pid];
  else if ([colId isEqualToString:@"User"]) {
    t.stringValue = n.user;
    t.textColor = AM_TEXT_SECONDARY;
  }

  return t;
}

@end
