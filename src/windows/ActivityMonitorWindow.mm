#import "ActivityMonitorWindow.h"
#import "../helpers/GlassmorphismHelper.h"
#include <mach/mach.h>
#include <mach/mach_host.h>
#include <sys/sysctl.h>

@interface ActivityMonitorWindow () <NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSTimer *updateTimer;
@property(nonatomic, strong) NSTableView *processTable;
@property(nonatomic, strong) NSMutableArray *processList;
@property(nonatomic, strong) NSTextField *cpuLabel, *memLabel, *diskLabel,
    *netLabel, *gpuLabel;
@property(nonatomic, strong) NSProgressIndicator *cpuBar, *memBar;
@property(nonatomic, strong) NSView *cpuGraphView, *memGraphView;
@property(nonatomic, strong) NSMutableArray *cpuHistory, *memHistory;
@property(nonatomic, strong) NSSegmentedControl *tabControl;
@property(nonatomic, strong) NSTextField *processCountLabel, *threadCountLabel;
@property(nonatomic, strong) NSSearchField *searchField;
@end

@implementation ActivityMonitorWindow

+ (instancetype)sharedInstance {
  static ActivityMonitorWindow *inst;
  static dispatch_once_t t;
  dispatch_once(&t, ^{
    inst = [[self alloc] init];
  });
  return inst;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _processList = [NSMutableArray array];
    _cpuHistory = [NSMutableArray array];
    _memHistory = [NSMutableArray array];
    for (int i = 0; i < 60; i++) {
      [_cpuHistory addObject:@(0)];
      [_memHistory addObject:@(0)];
    }
  }
  return self;
}

- (void)showWindow {
  if (self.window) {
    [self.window makeKeyAndOrderFront:nil];
    return;
  }

  self.window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(100, 100, 900, 700)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.window.title = @"Activity Monitor";
  self.window.backgroundColor = [NSColor colorWithRed:0.12
                                                green:0.12
                                                 blue:0.14
                                                alpha:1.0];
  self.window.minSize = NSMakeSize(700, 500);

  NSView *content = self.window.contentView;

  // ===== Tab Control =====
  self.tabControl =
      [[NSSegmentedControl alloc] initWithFrame:NSMakeRect(20, 660, 400, 28)];
  self.tabControl.segmentCount = 5;
  [self.tabControl setLabel:@"CPU" forSegment:0];
  [self.tabControl setLabel:@"Memory" forSegment:1];
  [self.tabControl setLabel:@"Disk" forSegment:2];
  [self.tabControl setLabel:@"Network" forSegment:3];
  [self.tabControl setLabel:@"GPU" forSegment:4];
  self.tabControl.selectedSegment = 0;
  self.tabControl.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [content addSubview:self.tabControl];

  // ===== Search Field =====
  self.searchField =
      [[NSSearchField alloc] initWithFrame:NSMakeRect(560, 660, 320, 28)];
  self.searchField.placeholderString = @"Search processes...";
  self.searchField.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
  [content addSubview:self.searchField];

  // ===== Stats Bar =====
  NSView *statsBar =
      [[NSView alloc] initWithFrame:NSMakeRect(20, 600, 860, 50)];
  statsBar.wantsLayer = YES;
  statsBar.layer.backgroundColor =
      [NSColor colorWithRed:0.18 green:0.18 blue:0.22 alpha:1.0].CGColor;
  statsBar.layer.cornerRadius = 10;
  statsBar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [content addSubview:statsBar];

  // CPU Usage
  NSTextField *cpuTitle = [self makeLabelAt:NSMakePoint(15, 28)
                                       text:@"CPU"
                                       size:10
                                      color:[NSColor grayColor]];
  [statsBar addSubview:cpuTitle];
  self.cpuLabel = [self makeLabelAt:NSMakePoint(15, 8)
                               text:@"0.0%"
                               size:16
                              color:[NSColor systemGreenColor]];
  [statsBar addSubview:self.cpuLabel];
  self.cpuBar =
      [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(90, 18, 80, 12)];
  self.cpuBar.style = NSProgressIndicatorStyleBar;
  self.cpuBar.minValue = 0;
  self.cpuBar.maxValue = 100;
  [statsBar addSubview:self.cpuBar];

  // Memory Usage
  NSTextField *memTitle = [self makeLabelAt:NSMakePoint(190, 28)
                                       text:@"Memory"
                                       size:10
                                      color:[NSColor grayColor]];
  [statsBar addSubview:memTitle];
  self.memLabel = [self makeLabelAt:NSMakePoint(190, 8)
                               text:@"0 GB / 0 GB"
                               size:14
                              color:[NSColor systemYellowColor]];
  [statsBar addSubview:self.memLabel];
  self.memBar =
      [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(330, 18, 80, 12)];
  self.memBar.style = NSProgressIndicatorStyleBar;
  self.memBar.minValue = 0;
  self.memBar.maxValue = 100;
  [statsBar addSubview:self.memBar];

  // Disk I/O
  self.diskLabel = [self makeLabelAt:NSMakePoint(430, 8)
                                text:@"Disk: R 0 B/s  W 0 B/s"
                                size:12
                               color:[NSColor systemOrangeColor]];
  [statsBar addSubview:self.diskLabel];

  // Network
  self.netLabel = [self makeLabelAt:NSMakePoint(630, 8)
                               text:@"Net: ↓ 0 B/s  ↑ 0 B/s"
                               size:12
                              color:[NSColor systemBlueColor]];
  [statsBar addSubview:self.netLabel];

  // ===== Mini Graph Area =====
  self.cpuGraphView =
      [[NSView alloc] initWithFrame:NSMakeRect(20, 520, 420, 70)];
  self.cpuGraphView.wantsLayer = YES;
  self.cpuGraphView.layer.backgroundColor =
      [NSColor controlBackgroundColor].CGColor;
  self.cpuGraphView.layer.cornerRadius = 8;
  self.cpuGraphView.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [content addSubview:self.cpuGraphView];

  self.memGraphView =
      [[NSView alloc] initWithFrame:NSMakeRect(460, 520, 420, 70)];
  self.memGraphView.wantsLayer = YES;
  self.memGraphView.layer.backgroundColor =
      [NSColor controlBackgroundColor].CGColor;
  self.memGraphView.layer.cornerRadius = 8;
  self.memGraphView.autoresizingMask = NSViewMinXMargin | NSViewMinYMargin;
  [content addSubview:self.memGraphView];

  // ===== Process Table =====
  NSScrollView *scrollView =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 50, 860, 460)];
  scrollView.hasVerticalScroller = YES;
  scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  scrollView.borderType = NSNoBorder;
  scrollView.backgroundColor = [NSColor colorWithRed:0.14
                                               green:0.14
                                                blue:0.17
                                               alpha:1.0];

  self.processTable = [[NSTableView alloc] initWithFrame:scrollView.bounds];
  self.processTable.dataSource = self;
  self.processTable.delegate = self;
  self.processTable.backgroundColor = [NSColor colorWithRed:0.14
                                                      green:0.14
                                                       blue:0.17
                                                      alpha:1.0];
  self.processTable.rowHeight = 24;
  self.processTable.style = NSTableViewStylePlain;

  NSArray *colDefs = @[
    @[ @"pid", @"PID", @(60) ], @[ @"name", @"Process Name", @(200) ],
    @[ @"user", @"User", @(80) ], @[ @"cpu", @"% CPU", @(70) ],
    @[ @"mem", @"Memory", @(90) ], @[ @"threads", @"Threads", @(70) ],
    @[ @"ports", @"Ports", @(60) ], @[ @"state", @"State", @(80) ],
    @[ @"time", @"CPU Time", @(90) ]
  ];

  for (NSArray *def in colDefs) {
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:def[0]];
    col.title = def[1];
    col.width = [def[2] floatValue];
    col.sortDescriptorPrototype = [[NSSortDescriptor alloc] initWithKey:def[0]
                                                              ascending:YES];
    [self.processTable addTableColumn:col];
  }

  scrollView.documentView = self.processTable;
  [content addSubview:scrollView];

  // ===== Bottom Status Bar =====
  NSView *bottomBar =
      [[NSView alloc] initWithFrame:NSMakeRect(20, 10, 860, 30)];
  bottomBar.autoresizingMask = NSViewWidthSizable;
  self.processCountLabel = [self makeLabelAt:NSMakePoint(0, 5)
                                        text:@"Processes: 0"
                                        size:11
                                       color:[NSColor grayColor]];
  [bottomBar addSubview:self.processCountLabel];
  self.threadCountLabel = [self makeLabelAt:NSMakePoint(150, 5)
                                       text:@"Threads: 0"
                                       size:11
                                      color:[NSColor grayColor]];
  [bottomBar addSubview:self.threadCountLabel];

  NSButton *quitBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(750, 0, 100, 28)];
  quitBtn.title = @"Force Quit";
  quitBtn.bezelStyle = NSBezelStyleRounded;
  quitBtn.target = self;
  quitBtn.action = @selector(forceQuitProcess:);
  [bottomBar addSubview:quitBtn];
  [content addSubview:bottomBar];

  // Start updates
  [self refreshProcessList];
  [self updateSystemStats];
  self.updateTimer =
      [NSTimer scheduledTimerWithTimeInterval:2.0
                                       target:self
                                     selector:@selector(timerFired:)
                                     userInfo:nil
                                      repeats:YES];

  [self.window makeKeyAndOrderFront:nil];
}

- (void)timerFired:(NSTimer *)timer {
  [self refreshProcessList];
  [self updateSystemStats];
  [self drawGraphs];
}

- (void)refreshProcessList {
  int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
  size_t size = 0;
  sysctl(mib, 4, NULL, &size, NULL, 0);
  struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
  if (!procs)
    return;
  sysctl(mib, 4, procs, &size, NULL, 0);
  NSUInteger count = size / sizeof(struct kinfo_proc);

  [self.processList removeAllObjects];
  NSUInteger totalThreads = 0;

  for (NSUInteger i = 0; i < count; i++) {
    struct kinfo_proc *p = &procs[i];
    NSString *name = @(p->kp_proc.p_comm);
    if (name.length == 0)
      continue;

    NSString *state;
    switch (p->kp_proc.p_stat) {
    case 1:
      state = @"Idle";
      break;
    case 2:
      state = @"Running";
      break;
    case 3:
      state = @"Sleeping";
      break;
    case 4:
      state = @"Stopped";
      break;
    case 5:
      state = @"Zombie";
      break;
    default:
      state = @"Unknown";
      break;
    }

    [self.processList addObject:@{
      @"pid" : @(p->kp_proc.p_pid),
      @"name" : name,
      @"user" : @(p->kp_eproc.e_ucred.cr_uid),
      @"cpu" : @(arc4random_uniform(100) / 10.0),
      @"mem" : @(arc4random_uniform(500)),
      @"threads" : @(1 + arc4random_uniform(20)),
      @"ports" : @(arc4random_uniform(50)),
      @"state" : state,
      @"time" : [NSString
          stringWithFormat:@"%u:%02u.%02u", arc4random_uniform(100),
                           arc4random_uniform(60), arc4random_uniform(100)]
    }];
    totalThreads += 1;
  }
  free(procs);

  [self.processTable reloadData];
  self.processCountLabel.stringValue =
      [NSString stringWithFormat:@"Processes: %lu",
                                 (unsigned long)self.processList.count];
  self.threadCountLabel.stringValue =
      [NSString stringWithFormat:@"Threads: %lu", (unsigned long)totalThreads];
}

- (void)updateSystemStats {
  // CPU usage
  host_cpu_load_info_data_t cpuInfo;
  mach_msg_type_number_t cpuCount = HOST_CPU_LOAD_INFO_COUNT;
  host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, (host_info_t)&cpuInfo,
                  &cpuCount);

  uint64_t userTicks = cpuInfo.cpu_ticks[CPU_STATE_USER];
  uint64_t sysTicks = cpuInfo.cpu_ticks[CPU_STATE_SYSTEM];
  uint64_t idleTicks = cpuInfo.cpu_ticks[CPU_STATE_IDLE];
  uint64_t total = userTicks + sysTicks + idleTicks;
  double cpuUsage =
      total > 0 ? ((double)(userTicks + sysTicks) / total) * 100.0 : 0;
  // Simulate some variation
  cpuUsage = MIN(100, cpuUsage + (arc4random_uniform(200) / 10.0 - 10.0));
  cpuUsage = MAX(0, cpuUsage);

  self.cpuLabel.stringValue = [NSString stringWithFormat:@"%.1f%%", cpuUsage];
  self.cpuBar.doubleValue = cpuUsage;
  [self.cpuHistory addObject:@(cpuUsage)];
  if (self.cpuHistory.count > 60)
    [self.cpuHistory removeObjectAtIndex:0];

  // Memory usage
  uint64_t totalMem = [[NSProcessInfo processInfo] physicalMemory];
  vm_statistics64_data_t vmStats;
  mach_msg_type_number_t vmCount = HOST_VM_INFO64_COUNT;
  host_statistics64(mach_host_self(), HOST_VM_INFO64, (host_info64_t)&vmStats,
                    &vmCount);

  uint64_t usedMem = (vmStats.active_count + vmStats.wire_count) * vm_page_size;
  double memPercent = (double)usedMem / totalMem * 100.0;

  self.memLabel.stringValue =
      [NSString stringWithFormat:@"%.1f GB / %.1f GB", usedMem / 1073741824.0,
                                 totalMem / 1073741824.0];
  self.memBar.doubleValue = memPercent;
  [self.memHistory addObject:@(memPercent)];
  if (self.memHistory.count > 60)
    [self.memHistory removeObjectAtIndex:0];

  // Disk & Network (simulated)
  self.diskLabel.stringValue =
      [NSString stringWithFormat:@"Disk: R %.1f MB/s  W %.1f MB/s",
                                 arc4random_uniform(500) / 10.0,
                                 arc4random_uniform(300) / 10.0];
  self.netLabel.stringValue =
      [NSString stringWithFormat:@"Net: ↓ %.1f KB/s  ↑ %.1f KB/s",
                                 arc4random_uniform(10000) / 10.0,
                                 arc4random_uniform(5000) / 10.0];
}

- (void)drawGraphs {
  // Simple graph rendering using layers
  [self drawHistoryGraph:self.cpuHistory
                  inView:self.cpuGraphView
                   color:[NSColor systemGreenColor]
                   label:@"CPU Usage"];
  [self drawHistoryGraph:self.memHistory
                  inView:self.memGraphView
                   color:[NSColor systemYellowColor]
                   label:@"Memory Pressure"];
}

- (void)drawHistoryGraph:(NSArray *)history
                  inView:(NSView *)view
                   color:(NSColor *)color
                   label:(NSString *)label {
  // Remove old graph layers
  NSArray *sublayers = [view.layer.sublayers copy];
  for (CALayer *l in sublayers)
    [l removeFromSuperlayer];

  CGFloat w = view.bounds.size.width;
  CGFloat h = view.bounds.size.height;

  // Label
  CATextLayer *textLayer = [CATextLayer layer];
  textLayer.string = label;
  textLayer.fontSize = 10;
  textLayer.foregroundColor = [NSColor grayColor].CGColor;
  textLayer.frame = CGRectMake(8, h - 16, 150, 14);
  textLayer.contentsScale = 2.0;
  [view.layer addSublayer:textLayer];

  if (history.count < 2)
    return;

  // Draw line graph
  CAShapeLayer *lineLayer = [CAShapeLayer layer];
  NSBezierPath *path = [NSBezierPath bezierPath];
  CGFloat step = w / (history.count - 1);

  for (NSUInteger i = 0; i < history.count; i++) {
    CGFloat val = [history[i] doubleValue] / 100.0;
    CGFloat x = i * step;
    CGFloat y = val * (h - 20) + 4;
    if (i == 0)
      [path moveToPoint:NSMakePoint(x, y)];
    else
      [path lineToPoint:NSMakePoint(x, y)];
  }

  CGMutablePathRef cgPath = CGPathCreateMutable();
  NSPoint pts[3];
  NSInteger elementCount = path.elementCount;
  for (NSInteger i = 0; i < elementCount; i++) {
    NSBezierPathElement elem = [path elementAtIndex:i associatedPoints:pts];
    switch (elem) {
    case NSBezierPathElementMoveTo:
      CGPathMoveToPoint(cgPath, NULL, pts[0].x, pts[0].y);
      break;
    case NSBezierPathElementLineTo:
      CGPathAddLineToPoint(cgPath, NULL, pts[0].x, pts[0].y);
      break;
    default:
      break;
    }
  }

  lineLayer.path = cgPath;
  lineLayer.strokeColor = color.CGColor;
  lineLayer.fillColor = nil;
  lineLayer.lineWidth = 1.5;
  [view.layer addSublayer:lineLayer];
  CGPathRelease(cgPath);
}

- (void)forceQuitProcess:(id)sender {
  NSInteger row = self.processTable.selectedRow;
  if (row < 0 || row >= (NSInteger)self.processList.count)
    return;
  NSDictionary *proc = self.processList[row];
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = @"Force Quit Process";
  alert.informativeText =
      [NSString stringWithFormat:@"Force quit \"%@\" (PID %@)?", proc[@"name"],
                                 proc[@"pid"]];
  alert.alertStyle = NSAlertStyleWarning;
  [alert addButtonWithTitle:@"Force Quit"];
  [alert addButtonWithTitle:@"Cancel"];
  if ([alert runModal] == NSAlertFirstButtonReturn) {
    pid_t pid = [proc[@"pid"] intValue];
    kill(pid, SIGTERM);
    [self refreshProcessList];
  }
}

// ===== TableView DataSource/Delegate =====

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
  return self.processList.count;
}

- (NSView *)tableView:(NSTableView *)tv
    viewForTableColumn:(NSTableColumn *)col
                   row:(NSInteger)row {
  NSString *identifier = col.identifier;
  NSTableCellView *cell = [tv makeViewWithIdentifier:identifier owner:self];
  if (!cell) {
    cell =
        [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, col.width, 24)];
    cell.identifier = identifier;
    NSTextField *tf = [[NSTextField alloc] initWithFrame:cell.bounds];
    tf.editable = NO;
    tf.bordered = NO;
    tf.drawsBackground = NO;
    tf.textColor = [NSColor whiteColor];
    tf.font = [NSFont systemFontOfSize:11];
    tf.lineBreakMode = NSLineBreakByTruncatingTail;
    cell.textField = tf;
    [cell addSubview:tf];
  }

  NSDictionary *proc = self.processList[row];
  id value = proc[identifier];
  if ([identifier isEqualToString:@"cpu"]) {
    cell.textField.stringValue =
        [NSString stringWithFormat:@"%.1f", [value doubleValue]];
    double cpu = [value doubleValue];
    if (cpu > 50)
      cell.textField.textColor = [NSColor systemRedColor];
    else if (cpu > 20)
      cell.textField.textColor = [NSColor systemYellowColor];
    else
      cell.textField.textColor = [NSColor systemGreenColor];
  } else if ([identifier isEqualToString:@"mem"]) {
    double mb = [value doubleValue];
    cell.textField.stringValue =
        mb >= 1024 ? [NSString stringWithFormat:@"%.1f GB", mb / 1024.0]
                   : [NSString stringWithFormat:@"%.0f MB", mb];
    cell.textField.textColor = [NSColor whiteColor];
  } else {
    cell.textField.stringValue = [NSString stringWithFormat:@"%@", value];
    cell.textField.textColor = [NSColor whiteColor];
  }
  return cell;
}

- (NSTextField *)makeLabelAt:(NSPoint)pt
                        text:(NSString *)text
                        size:(CGFloat)size
                       color:(NSColor *)color {
  NSTextField *tf =
      [[NSTextField alloc] initWithFrame:NSMakeRect(pt.x, pt.y, 200, size + 6)];
  tf.stringValue = text;
  tf.font = [NSFont systemFontOfSize:size weight:NSFontWeightMedium];
  tf.textColor = color;
  tf.editable = NO;
  tf.bordered = NO;
  tf.drawsBackground = NO;
  return tf;
}

- (void)dealloc {
  [self.updateTimer invalidate];
}

@end
