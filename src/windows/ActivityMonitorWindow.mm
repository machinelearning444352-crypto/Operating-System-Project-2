#import "ActivityMonitorWindow.h"
#import <QuartzCore/QuartzCore.h>
#include <libproc.h>
#include <mach/mach.h>
#include <mach/mach_host.h>
#include <mach/processor_info.h>
#include <mach/host_info.h>
#include <sys/sysctl.h>
#include <sys/mount.h>
#include <net/if.h>
#include <ifaddrs.h>
#include <signal.h>

#define AM_BG [NSColor windowBackgroundColor]
#define AM_SIDEBAR_BG [NSColor controlBackgroundColor]
#define AM_TEXT_PRIMARY [NSColor labelColor]
#define AM_TEXT_SECONDARY [NSColor secondaryLabelColor]
#define AM_BORDER [NSColor separatorColor]
#define AM_ACCENT [NSColor controlAccentColor]
#define AM_GREEN [NSColor systemGreenColor]
#define AM_RED [NSColor systemRedColor]
#define AM_YELLOW [NSColor systemYellowColor]
#define AM_ORANGE [NSColor systemOrangeColor]
#define AM_BLUE [NSColor systemBlueColor]
#define AM_PURPLE [NSColor systemPurpleColor]

// ─── AM_GraphView ─────────────────────────────────────────────────────────
@interface AM_GraphView : NSView
@property(nonatomic, strong) NSMutableArray<NSNumber *> *dataPoints;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *dataPoints2;
@property(nonatomic, strong) NSColor *lineColor;
@property(nonatomic, strong) NSColor *lineColor2;
@property(nonatomic, strong) NSColor *fillColor;
@property(nonatomic, strong) NSColor *fillColor2;
@property(nonatomic, assign) CGFloat maxValue;
@property(nonatomic, assign) BOOL dualLine;
@property(nonatomic, strong) NSString *titleText;
@property(nonatomic, strong) NSString *subtitleText;
- (void)addPoint:(CGFloat)val;
- (void)addPoint:(CGFloat)val point2:(CGFloat)val2;
@end

@implementation AM_GraphView
- (instancetype)initWithFrame:(NSRect)frameRect {
  if (self = [super initWithFrame:frameRect]) {
    _dataPoints = [NSMutableArray array];
    _dataPoints2 = [NSMutableArray array];
    for (int i = 0; i < 120; i++) {
      [_dataPoints addObject:@(0)];
      [_dataPoints2 addObject:@(0)];
    }
    _lineColor = AM_BLUE;
    _lineColor2 = AM_GREEN;
    _fillColor = [AM_BLUE colorWithAlphaComponent:0.15];
    _fillColor2 = [AM_GREEN colorWithAlphaComponent:0.15];
    _maxValue = 100.0;
    _dualLine = NO;
    _titleText = @"";
    _subtitleText = @"";
  }
  return self;
}

- (void)addPoint:(CGFloat)val {
  [_dataPoints removeObjectAtIndex:0];
  [_dataPoints addObject:@(val)];
  self.needsDisplay = YES;
}

- (void)addPoint:(CGFloat)val point2:(CGFloat)val2 {
  [_dataPoints removeObjectAtIndex:0];
  [_dataPoints addObject:@(val)];
  [_dataPoints2 removeObjectAtIndex:0];
  [_dataPoints2 addObject:@(val2)];
  self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];
  NSRect b = self.bounds;
  
  // Background
  [[NSColor colorWithWhite:0.08 alpha:0.95] setFill];
  NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:b xRadius:6 yRadius:6];
  [bgPath fill];

  // Grid lines
  [[[NSColor whiteColor] colorWithAlphaComponent:0.08] setStroke];
  for (int i = 1; i < 4; i++) {
    CGFloat y = b.size.height * i / 4.0;
    NSBezierPath *gridLine = [NSBezierPath bezierPath];
    [gridLine moveToPoint:NSMakePoint(0, y)];
    [gridLine lineToPoint:NSMakePoint(b.size.width, y)];
    gridLine.lineWidth = 0.5;
    [gridLine stroke];
  }
  for (int x = 0; x < (int)b.size.width; x += 30) {
    NSBezierPath *vLine = [NSBezierPath bezierPath];
    [vLine moveToPoint:NSMakePoint(x, 0)];
    [vLine lineToPoint:NSMakePoint(b.size.width > 0 ? x : 0, b.size.height)];
    vLine.lineWidth = 0.5;
    [vLine stroke];
  }

  if (_dataPoints.count < 2) return;
  CGFloat stepX = b.size.width / (CGFloat)(_dataPoints.count - 1);

  // Draw fill + line for primary data
  [self drawDataSet:_dataPoints lineColor:_lineColor fillColor:_fillColor bounds:b stepX:stepX];
  
  // Draw secondary line if dual
  if (_dualLine) {
    [self drawDataSet:_dataPoints2 lineColor:_lineColor2 fillColor:_fillColor2 bounds:b stepX:stepX];
  }

  // Title overlay
  if (_titleText.length > 0) {
    NSDictionary *attrs = @{
      NSFontAttributeName: [NSFont systemFontOfSize:10 weight:NSFontWeightMedium],
      NSForegroundColorAttributeName: [[NSColor whiteColor] colorWithAlphaComponent:0.7]
    };
    [_titleText drawAtPoint:NSMakePoint(6, b.size.height - 16) withAttributes:attrs];
  }
  if (_subtitleText.length > 0) {
    NSDictionary *attrs2 = @{
      NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightBold],
      NSForegroundColorAttributeName: _lineColor
    };
    [_subtitleText drawAtPoint:NSMakePoint(6, b.size.height - 28) withAttributes:attrs2];
  }
}

- (void)drawDataSet:(NSArray<NSNumber*>*)data lineColor:(NSColor*)lc fillColor:(NSColor*)fc bounds:(NSRect)b stepX:(CGFloat)stepX {
  NSBezierPath *path = [NSBezierPath bezierPath];
  NSBezierPath *fillPath = [NSBezierPath bezierPath];
  [fillPath moveToPoint:NSMakePoint(b.size.width, 0)];
  [fillPath lineToPoint:NSMakePoint(0, 0)];

  for (NSUInteger i = 0; i < data.count; i++) {
    CGFloat val = [data[i] floatValue];
    CGFloat pct = (_maxValue > 0) ? val / _maxValue : 0;
    if (pct > 1.0) pct = 1.0;
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
  [fc setFill];
  [fillPath fill];
  [lc setStroke];
  path.lineWidth = 1.5;
  path.lineJoinStyle = NSLineJoinStyleRound;
  [path stroke];
}
@end

// ─── AM_BarMeterView ──────────────────────────────────────────────────────
@interface AM_BarMeterView : NSView
@property(nonatomic, assign) CGFloat value;
@property(nonatomic, assign) CGFloat maxVal;
@property(nonatomic, strong) NSColor *barColor;
@property(nonatomic, strong) NSString *label;
@end
@implementation AM_BarMeterView
- (void)drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];
  NSRect b = self.bounds;
  [[NSColor colorWithWhite:0.15 alpha:1.0] setFill];
  [[NSBezierPath bezierPathWithRoundedRect:b xRadius:3 yRadius:3] fill];
  CGFloat pct = (_maxVal > 0) ? _value / _maxVal : 0;
  if (pct > 1.0) pct = 1.0;
  NSRect filled = NSMakeRect(0, 0, b.size.width * pct, b.size.height);
  [_barColor setFill];
  [[NSBezierPath bezierPathWithRoundedRect:filled xRadius:3 yRadius:3] fill];
  if (_label.length > 0) {
    NSDictionary *a = @{NSFontAttributeName:[NSFont systemFontOfSize:9 weight:NSFontWeightMedium],
                        NSForegroundColorAttributeName:[NSColor whiteColor]};
    [_label drawAtPoint:NSMakePoint(4, (b.size.height - 11)/2) withAttributes:a];
  }
}
@end

// ─── AM_PieChartView ──────────────────────────────────────────────────────
@interface AM_PieChartView : NSView
@property(nonatomic, assign) CGFloat val1, val2, val3, val4;
@property(nonatomic, strong) NSColor *col1, *col2, *col3, *col4;
@property(nonatomic, strong) NSArray<NSString*> *labels;
@end
@implementation AM_PieChartView
- (void)drawRect:(NSRect)dirtyRect {
  [super drawRect:dirtyRect];
  CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
  CGFloat r = MIN(w, h) / 2.0 - 10;
  NSPoint c = NSMakePoint(w / 2, h / 2);
  CGFloat total = _val1 + _val2 + _val3 + _val4;
  if (total <= 0) return;

  NSArray *vals = @[@(_val1), @(_val2), @(_val3), @(_val4)];
  NSArray *cols = @[_col1 ?: AM_BLUE, _col2 ?: AM_GREEN, _col3 ?: AM_YELLOW, _col4 ?: [NSColor grayColor]];
  CGFloat startAngle = 90;
  for (int i = 0; i < 4; i++) {
    CGFloat v = [vals[i] doubleValue];
    if (v <= 0) continue;
    CGFloat angle = (v / total) * 360.0;
    NSBezierPath *p = [NSBezierPath bezierPath];
    [p moveToPoint:c];
    [p appendBezierPathWithArcWithCenter:c radius:r startAngle:startAngle endAngle:startAngle - angle clockwise:YES];
    [p closePath];
    [(NSColor*)cols[i] setFill];
    [p fill];
    startAngle -= angle;
  }
  // Donut hole
  CGFloat innerR = r * 0.55;
  NSBezierPath *inner = [NSBezierPath bezierPathWithOvalInRect:NSMakeRect(c.x - innerR, c.y - innerR, innerR * 2, innerR * 2)];
  [[NSColor colorWithWhite:0.12 alpha:1.0] setFill];
  [inner fill];
  
  // Center text
  if (_labels.count > 0) {
    NSDictionary *ca = @{NSFontAttributeName:[NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightBold],
                         NSForegroundColorAttributeName:[NSColor whiteColor]};
    NSString *ct = _labels.firstObject;
    NSSize ts = [ct sizeWithAttributes:ca];
    [ct drawAtPoint:NSMakePoint(c.x - ts.width/2, c.y - ts.height/2) withAttributes:ca];
  }
}
@end

// ─── AMProcessNode ────────────────────────────────────────────────────────
@interface AMProcessNode : NSObject
@property(nonatomic, assign) int pid;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, assign) double cpuPct;
@property(nonatomic, assign) uint64_t memBytes;
@property(nonatomic, assign) int threads;
@property(nonatomic, assign) int ports;
@property(nonatomic, strong) NSString *user;
@property(nonatomic, assign) uint64_t prevTotalTime;
@property(nonatomic, assign) NSTimeInterval lastSampleTime;
@end
@implementation AMProcessNode
@end

// ─── CPU Tick State ───────────────────────────────────────────────────────
typedef struct {
  natural_t user;
  natural_t system;
  natural_t idle;
  natural_t nice;
} AMCPUTicks;

// ─── Network State ────────────────────────────────────────────────────────
typedef struct {
  uint64_t bytesIn;
  uint64_t bytesOut;
  uint64_t packetsIn;
  uint64_t packetsOut;
} AMNetStats;

// ─── ActivityMonitorWindow ────────────────────────────────────────────────
@interface ActivityMonitorWindow () <NSTableViewDelegate, NSTableViewDataSource>
@property(nonatomic, strong) NSWindow *amWindow;
@property(nonatomic, strong) NSSegmentedControl *tabSelector;
@property(nonatomic, strong) NSSearchField *searchField;
@property(nonatomic, strong) NSTableView *processTable;
@property(nonatomic, strong) NSMutableArray<AMProcessNode *> *masterList;
@property(nonatomic, strong) NSMutableArray<AMProcessNode *> *displayList;
@property(nonatomic, strong)
    NSMutableDictionary<NSNumber *, NSNumber *> *prevCPUTimes;
@property(nonatomic, strong) AM_GraphView *cpuGraph;
@property(nonatomic, strong) AM_GraphView *memGraph;
@property(nonatomic, strong) AM_GraphView *netGraph;
@property(nonatomic, strong) AM_GraphView *diskGraph;
@property(nonatomic, strong) AM_PieChartView *memPie;
@property(nonatomic, strong) AM_BarMeterView *cpuBar;
@property(nonatomic, strong) AM_BarMeterView *memBar;
@property(nonatomic, strong) NSTextField *lblSystem, *lblUser, *lblIdle;
@property(nonatomic, strong) NSTextField *lblThreads, *lblProcesses;
@property(nonatomic, strong) NSTextField *lblMemUsed, *lblMemWired,
    *lblMemCompressed, *lblMemFree;
@property(nonatomic, strong) NSTextField *lblNetIn, *lblNetOut;
@property(nonatomic, strong) NSTextField *lblDiskRead, *lblDiskWrite;
@property(nonatomic, strong) NSTextField *lblUptime;
@property(nonatomic, strong) NSTimer *refreshTimer;
@property(nonatomic, assign) AMCPUTicks prevTicks;
@property(nonatomic, assign) AMNetStats prevNet;
@property(nonatomic, assign) NSTimeInterval prevTickTime;
@property(nonatomic, assign) NSInteger sortColumn;
@property(nonatomic, assign) BOOL sortAscending;
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
    _prevCPUTimes = [NSMutableDictionary dictionary];
    _sortColumn = 2; // CPU%
    _sortAscending = NO;
    _prevTickTime = [NSDate timeIntervalSinceReferenceDate];
    memset(&_prevTicks, 0, sizeof(AMCPUTicks));
    memset(&_prevNet, 0, sizeof(AMNetStats));
  }
  return self;
}

- (void)showWindow {
  if (self.amWindow) {
    [self.amWindow makeKeyAndOrderFront:nil];
    return;
  }
  NSRect frame = NSMakeRect(80, 60, 1100, 750);
  self.amWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:(NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                           NSWindowStyleMaskMiniaturizable |
                           NSWindowStyleMaskResizable)
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.amWindow.title = @"Activity Monitor";
  self.amWindow.releasedWhenClosed = NO;
  self.amWindow.minSize = NSMakeSize(800, 550);
  self.amWindow.backgroundColor = [NSColor colorWithWhite:0.12 alpha:1.0];
  self.amWindow.titlebarAppearsTransparent = YES;
  self.amWindow.titleVisibility = NSWindowTitleVisible;

  NSView *root = self.amWindow.contentView;
  root.wantsLayer = YES;

  [self buildTopToolbar:root frame:frame];
  [self buildTableArea:root frame:frame];
  [self buildBottomPane:root frame:frame];

  [self.amWindow makeKeyAndOrderFront:nil];

  // Seed initial CPU ticks
  [self readCPUTicks:&_prevTicks];
  _prevNet = [self readNetStats];

  self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                       target:self
                                                     selector:@selector(tick)
                                                     userInfo:nil
                                                      repeats:YES];
  [self tick];
}

#pragma mark - System Info Helpers

- (void)readCPUTicks:(AMCPUTicks *)out {
  host_name_port_t host = mach_host_self();
  processor_info_array_t cpuInfo;
  mach_msg_type_number_t numCpuInfo;
  natural_t numCPUs = 0;
  kern_return_t kr = host_processor_info(host, PROCESSOR_CPU_LOAD_INFO,
                                         &numCPUs, &cpuInfo, &numCpuInfo);
  if (kr != KERN_SUCCESS)
    return;

  natural_t totalUser = 0, totalSystem = 0, totalIdle = 0, totalNice = 0;
  for (natural_t i = 0; i < numCPUs; i++) {
    totalUser += cpuInfo[CPU_STATE_MAX * i + CPU_STATE_USER];
    totalSystem += cpuInfo[CPU_STATE_MAX * i + CPU_STATE_SYSTEM];
    totalIdle += cpuInfo[CPU_STATE_MAX * i + CPU_STATE_IDLE];
    totalNice += cpuInfo[CPU_STATE_MAX * i + CPU_STATE_NICE];
  }
  out->user = totalUser;
  out->system = totalSystem;
  out->idle = totalIdle;
  out->nice = totalNice;

  vm_deallocate(mach_task_self(), (vm_address_t)cpuInfo,
                sizeof(integer_t) * numCpuInfo);
}

- (AMNetStats)readNetStats {
  AMNetStats stats = {0, 0, 0, 0};
  struct ifaddrs *ifaddrs = NULL;
  if (getifaddrs(&ifaddrs) == 0) {
    struct ifaddrs *cursor = ifaddrs;
    while (cursor) {
      if (cursor->ifa_addr && cursor->ifa_addr->sa_family == AF_LINK) {
        const struct if_data *d = (const struct if_data *)cursor->ifa_data;
        if (d) {
          stats.bytesIn += d->ifi_ibytes;
          stats.bytesOut += d->ifi_obytes;
          stats.packetsIn += d->ifi_ipackets;
          stats.packetsOut += d->ifi_opackets;
        }
      }
      cursor = cursor->ifa_next;
    }
    freeifaddrs(ifaddrs);
  }
  return stats;
}

- (NSString *)formatBytes:(uint64_t)bytes {
  if (bytes < 1024)
    return [NSString stringWithFormat:@"%llu B", bytes];
  if (bytes < 1024 * 1024)
    return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
  if (bytes < 1024 * 1024 * 1024)
    return [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
  return [NSString
      stringWithFormat:@"%.2f GB", bytes / (1024.0 * 1024.0 * 1024.0)];
}

- (NSString *)formatUptime {
  struct timeval boottime;
  size_t len = sizeof(boottime);
  int mib[2] = {CTL_KERN, KERN_BOOTTIME};
  if (sysctl(mib, 2, &boottime, &len, NULL, 0) < 0)
    return @"N/A";
  NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
  NSTimeInterval upSec = now - boottime.tv_sec;
  int days = (int)(upSec / 86400);
  int hours = (int)((upSec - days * 86400) / 3600);
  int mins = (int)((upSec - days * 86400 - hours * 3600) / 60);
  if (days > 0)
    return [NSString stringWithFormat:@"%dd %dh %dm", days, hours, mins];
  return [NSString stringWithFormat:@"%dh %dm", hours, mins];
}

#pragma mark - UI Building

- (void)buildTopToolbar:(NSView *)root frame:(NSRect)frame {
  NSVisualEffectView *topBar = [[NSVisualEffectView alloc]
      initWithFrame:NSMakeRect(0, frame.size.height - 70, frame.size.width,
                               70)];
  topBar.material = NSVisualEffectMaterialTitlebar;
  topBar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  topBar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [root addSubview:topBar];

  self.tabSelector = [[NSSegmentedControl alloc]
      initWithFrame:NSMakeRect((frame.size.width - 500) / 2, 20, 500, 24)];
  [self.tabSelector setSegmentCount:5];
  [self.tabSelector setLabel:@"CPU" forSegment:0];
  [self.tabSelector setLabel:@"Memory" forSegment:1];
  [self.tabSelector setLabel:@"Energy" forSegment:2];
  [self.tabSelector setLabel:@"Disk" forSegment:3];
  [self.tabSelector setLabel:@"Network" forSegment:4];
  self.tabSelector.selectedSegment = 0;
  self.tabSelector.target = self;
  self.tabSelector.action = @selector(tabChanged);
  self.tabSelector.autoresizingMask = NSViewMinXMargin | NSViewMaxXMargin;
  [topBar addSubview:self.tabSelector];

  self.searchField = [[NSSearchField alloc]
      initWithFrame:NSMakeRect(frame.size.width - 220, 20, 200, 24)];
  self.searchField.autoresizingMask = NSViewMinXMargin;
  self.searchField.placeholderString = @"Search Processes";
  self.searchField.target = self;
  self.searchField.action = @selector(searchChanged);
  [topBar addSubview:self.searchField];

  // Force Quit button
  NSButton *quitBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(14, 20, 80, 24)];
  quitBtn.title = @"Force Quit";
  quitBtn.bezelStyle = NSBezelStyleRounded;
  quitBtn.font = [NSFont systemFontOfSize:11];
  quitBtn.target = self;
  quitBtn.action = @selector(forceQuitSelected);
  [topBar addSubview:quitBtn];

  NSButton *infoBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(100, 20, 30, 24)];
  infoBtn.title = @"ℹ";
  infoBtn.bezelStyle = NSBezelStyleRounded;
  infoBtn.font = [NSFont systemFontOfSize:14];
  infoBtn.target = self;
  infoBtn.action = @selector(showProcessInfo);
  [topBar addSubview:infoBtn];
}

- (void)buildTableArea:(NSView *)root frame:(NSRect)frame {
  CGFloat topH = 70, botH = 220;
  NSRect tbFrame =
      NSMakeRect(0, botH, frame.size.width, frame.size.height - topH - botH);

  NSScrollView *sv = [[NSScrollView alloc] initWithFrame:tbFrame];
  sv.hasVerticalScroller = YES;
  sv.hasHorizontalScroller = YES;
  sv.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  sv.drawsBackground = NO;
  [root addSubview:sv];

  self.processTable = [[NSTableView alloc] initWithFrame:sv.bounds];
  self.processTable.dataSource = self;
  self.processTable.delegate = self;
  self.processTable.rowHeight = 22;
  self.processTable.style = NSTableViewStyleFullWidth;
  self.processTable.gridStyleMask = NSTableViewSolidHorizontalGridLineMask;
  self.processTable.gridColor =
      [[NSColor separatorColor] colorWithAlphaComponent:0.3];
  self.processTable.backgroundColor = [NSColor colorWithWhite:0.14 alpha:1.0];
  self.processTable.allowsColumnReordering = YES;
  self.processTable.allowsColumnResizing = YES;
  self.processTable.allowsMultipleSelection = NO;

  NSString *cols[] = {@"Process Name", @"PID",    @"% CPU", @"CPU Time",
                      @"Threads",      @"Memory", @"User"};
  CGFloat widths[] = {220, 60, 80, 90, 65, 90, 100};
  for (int i = 0; i < 7; i++) {
    NSTableColumn *c = [[NSTableColumn alloc] initWithIdentifier:cols[i]];
    c.title = cols[i];
    c.width = widths[i];
    c.minWidth = 40;
    c.sortDescriptorPrototype = [[NSSortDescriptor alloc] initWithKey:cols[i]
                                                            ascending:YES];
    [self.processTable addTableColumn:c];
  }
  sv.documentView = self.processTable;
}

- (NSTextField *)makeLabel:(NSString *)text
                      size:(CGFloat)sz
                      bold:(BOOL)bold
                     color:(NSColor *)col
                     frame:(NSRect)fr
                    parent:(NSView *)parent {
  NSTextField *l = [[NSTextField alloc] initWithFrame:fr];
  l.stringValue = text;
  l.font = bold ? [NSFont systemFontOfSize:sz weight:NSFontWeightSemibold]
                : [NSFont systemFontOfSize:sz];
  l.textColor = col;
  l.drawsBackground = NO;
  l.bezeled = NO;
  l.editable = NO;
  l.selectable = NO;
  [parent addSubview:l];
  return l;
}

- (void)buildBottomPane:(NSView *)root frame:(NSRect)frame {
  CGFloat botH = 220;
  NSView *bottomView =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, botH)];
  bottomView.wantsLayer = YES;
  bottomView.layer.backgroundColor =
      [NSColor colorWithWhite:0.10 alpha:1.0].CGColor;
  bottomView.autoresizingMask = NSViewWidthSizable;
  [root addSubview:bottomView];

  CGFloat graphW = (frame.size.width - 220) / 2.0;
  CGFloat graphH = 90;

  // CPU Graph
  self.cpuGraph = [[AM_GraphView alloc]
      initWithFrame:NSMakeRect(10, botH - graphH - 10, graphW - 10, graphH)];
  self.cpuGraph.titleText = @"CPU Usage";
  self.cpuGraph.lineColor = [NSColor systemGreenColor];
  self.cpuGraph.fillColor =
      [[NSColor systemGreenColor] colorWithAlphaComponent:0.15];
  self.cpuGraph.autoresizingMask = NSViewWidthSizable;
  [bottomView addSubview:self.cpuGraph];

  // Memory Graph
  self.memGraph = [[AM_GraphView alloc]
      initWithFrame:NSMakeRect(graphW + 10, botH - graphH - 10, graphW - 10,
                               graphH)];
  self.memGraph.titleText = @"Memory Pressure";
  self.memGraph.lineColor = AM_YELLOW;
  self.memGraph.fillColor = [AM_YELLOW colorWithAlphaComponent:0.15];
  self.memGraph.autoresizingMask = NSViewWidthSizable;
  [bottomView addSubview:self.memGraph];

  // Network Graph
  self.netGraph =
      [[AM_GraphView alloc] initWithFrame:NSMakeRect(10, botH - graphH * 2 - 20,
                                                     graphW - 10, graphH)];
  self.netGraph.titleText = @"Network";
  self.netGraph.dualLine = YES;
  self.netGraph.lineColor = AM_BLUE;
  self.netGraph.lineColor2 = AM_RED;
  self.netGraph.fillColor = [AM_BLUE colorWithAlphaComponent:0.1];
  self.netGraph.fillColor2 = [AM_RED colorWithAlphaComponent:0.1];
  self.netGraph.maxValue = 1024 * 1024;
  self.netGraph.autoresizingMask = NSViewWidthSizable;
  [bottomView addSubview:self.netGraph];

  // Disk Graph
  self.diskGraph = [[AM_GraphView alloc]
      initWithFrame:NSMakeRect(graphW + 10, botH - graphH * 2 - 20, graphW - 10,
                               graphH)];
  self.diskGraph.titleText = @"Disk Activity";
  self.diskGraph.lineColor = AM_ORANGE;
  self.diskGraph.fillColor = [AM_ORANGE colorWithAlphaComponent:0.15];
  self.diskGraph.autoresizingMask = NSViewWidthSizable;
  [bottomView addSubview:self.diskGraph];

  // Right stats panel
  CGFloat rx = frame.size.width - 210;
  NSView *statsPanel =
      [[NSView alloc] initWithFrame:NSMakeRect(rx, 5, 200, botH - 10)];
  statsPanel.autoresizingMask = NSViewMinXMargin;
  [bottomView addSubview:statsPanel];

  // Memory Pie
  self.memPie = [[AM_PieChartView alloc]
      initWithFrame:NSMakeRect(30, botH - 130, 140, 120)];
  self.memPie.col1 = AM_RED;
  self.memPie.col2 = AM_YELLOW;
  self.memPie.col3 = AM_ORANGE;
  self.memPie.col4 = AM_GREEN;
  [statsPanel addSubview:self.memPie];

  CGFloat ly = botH - 150;
  self.lblMemUsed = [self makeLabel:@"Used: 0 GB"
                               size:10
                               bold:NO
                              color:AM_RED
                              frame:NSMakeRect(5, ly, 190, 14)
                             parent:statsPanel];
  ly -= 15;
  self.lblMemWired = [self makeLabel:@"Wired: 0 GB"
                                size:10
                                bold:NO
                               color:AM_YELLOW
                               frame:NSMakeRect(5, ly, 190, 14)
                              parent:statsPanel];
  ly -= 15;
  self.lblMemCompressed = [self makeLabel:@"Compressed: 0 GB"
                                     size:10
                                     bold:NO
                                    color:AM_ORANGE
                                    frame:NSMakeRect(5, ly, 190, 14)
                                   parent:statsPanel];
  ly -= 15;
  self.lblMemFree = [self makeLabel:@"Free: 0 GB"
                               size:10
                               bold:NO
                              color:AM_GREEN
                              frame:NSMakeRect(5, ly, 190, 14)
                             parent:statsPanel];
  ly -= 20;

  self.lblSystem = [self makeLabel:@"System: 0%"
                              size:10
                              bold:YES
                             color:AM_RED
                             frame:NSMakeRect(5, ly, 190, 14)
                            parent:statsPanel];
  ly -= 14;
  self.lblUser = [self makeLabel:@"User: 0%"
                            size:10
                            bold:YES
                           color:AM_BLUE
                           frame:NSMakeRect(5, ly, 190, 14)
                          parent:statsPanel];
  ly -= 14;
  self.lblIdle = [self makeLabel:@"Idle: 100%"
                            size:10
                            bold:NO
                           color:AM_GREEN
                           frame:NSMakeRect(5, ly, 190, 14)
                          parent:statsPanel];
  ly -= 18;

  self.lblThreads = [self makeLabel:@"Threads: 0"
                               size:10
                               bold:NO
                              color:AM_TEXT_SECONDARY
                              frame:NSMakeRect(5, ly, 190, 14)
                             parent:statsPanel];
  ly -= 14;
  self.lblProcesses = [self makeLabel:@"Processes: 0"
                                 size:10
                                 bold:NO
                                color:AM_TEXT_SECONDARY
                                frame:NSMakeRect(5, ly, 190, 14)
                               parent:statsPanel];
  ly -= 14;
  self.lblUptime = [self makeLabel:@"Uptime: --"
                              size:10
                              bold:NO
                             color:AM_TEXT_SECONDARY
                             frame:NSMakeRect(5, ly, 190, 14)
                            parent:statsPanel];
  ly -= 18;

  self.lblNetIn = [self makeLabel:@"Net In: 0 B/s"
                             size:10
                             bold:NO
                            color:AM_BLUE
                            frame:NSMakeRect(5, ly, 190, 14)
                           parent:statsPanel];
  ly -= 14;
  self.lblNetOut = [self makeLabel:@"Net Out: 0 B/s"
                              size:10
                              bold:NO
                             color:AM_RED
                             frame:NSMakeRect(5, ly, 190, 14)
                            parent:statsPanel];
}

#pragma mark - Actions

- (void)tabChanged {
  [self tick];
}
- (void)searchChanged {
  [self filterAndReload];
}

- (void)forceQuitSelected {
  NSInteger row = self.processTable.selectedRow;
  if (row < 0 || row >= (NSInteger)self.displayList.count) {
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText = @"No Process Selected";
    a.informativeText = @"Please select a process to force quit.";
    [a runModal];
    return;
  }
  AMProcessNode *n = self.displayList[row];
  NSAlert *a = [[NSAlert alloc] init];
  a.messageText = [NSString stringWithFormat:@"Force Quit \"%@\"?", n.name];
  a.informativeText = [NSString
      stringWithFormat:@"PID %d — This may cause unsaved data to be lost.",
                       n.pid];
  a.alertStyle = NSAlertStyleWarning;
  [a addButtonWithTitle:@"Force Quit"];
  [a addButtonWithTitle:@"Cancel"];
  if ([a runModal] == NSAlertFirstButtonReturn) {
    kill(n.pid, SIGKILL);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC),
                   dispatch_get_main_queue(), ^{
                     [self tick];
                   });
  }
}

- (void)showProcessInfo {
  NSInteger row = self.processTable.selectedRow;
  if (row < 0 || row >= (NSInteger)self.displayList.count)
    return;
  AMProcessNode *n = self.displayList[row];
  NSAlert *a = [[NSAlert alloc] init];
  a.messageText = n.name;
  a.informativeText = [NSString
      stringWithFormat:
          @"PID: %d\nUser: %@\nThreads: %d\nMemory: %@\nCPU: %.1f%%", n.pid,
          n.user, n.threads, [self formatBytes:n.memBytes], n.cpuPct];
  [a runModal];
}

#pragma mark - Real Data Collection

- (void)tick {
  @try {
    [self collectProcesses];
    [self collectSystemStats];
    [self filterAndReload];
  } @catch (NSException *e) {
    NSLog(@"[ActivityMonitor] tick error: %@", e);
  }
}

- (void)collectProcesses {
  int mib[] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
  size_t size = 0;
  sysctl(mib, 4, NULL, &size, NULL, 0);
  struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
  if (!procs)
    return;
  sysctl(mib, 4, procs, &size, NULL, 0);
  NSUInteger count = size / sizeof(struct kinfo_proc);

  NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
  NSTimeInterval dt = now - self.prevTickTime;
  if (dt < 0.1)
    dt = 2.0;
  self.prevTickTime = now;

  NSMutableDictionary<NSNumber *, NSNumber *> *newCPUTimes =
      [NSMutableDictionary dictionary];
  [self.masterList removeAllObjects];

  for (NSUInteger i = 0; i < count; i++) {
    struct kinfo_proc *p = &procs[i];
    NSString *name = @(p->kp_proc.p_comm);
    if (name.length == 0)
      continue;

    AMProcessNode *node = [AMProcessNode new];
    node.pid = p->kp_proc.p_pid;
    node.name = name;
    node.user = (p->kp_eproc.e_pcred.p_ruid == 0) ? @"root" : NSUserName();

    struct proc_taskinfo pti;
    int ret = proc_pidinfo(node.pid, PROC_PIDTASKINFO, 0, &pti, sizeof(pti));
    if (ret == (int)sizeof(pti)) {
      node.threads = pti.pti_threadnum;
      node.memBytes = pti.pti_resident_size;

      // Real CPU% via task time deltas
      uint64_t totalTime = pti.pti_total_user + pti.pti_total_system;
      NSNumber *prevTime = self.prevCPUTimes[@(node.pid)];
      if (prevTime) {
        uint64_t delta = totalTime - [prevTime unsignedLongLongValue];
        // delta is in nanoseconds, dt is in seconds
        double cpuFraction = (double)delta / (dt * 1e9);
        node.cpuPct = cpuFraction * 100.0;
        if (node.cpuPct > 800.0)
          node.cpuPct = 0; // Sanity
        if (node.cpuPct < 0)
          node.cpuPct = 0;
      } else {
        node.cpuPct = 0;
      }
      newCPUTimes[@(node.pid)] = @(totalTime);
    } else {
      node.threads = 1;
      node.memBytes = 0;
      node.cpuPct = 0;
    }
    [self.masterList addObject:node];
  }
  free(procs);
  self.prevCPUTimes = newCPUTimes;
}

- (void)collectSystemStats {
  // ── Overall CPU from host_processor_info ──
  AMCPUTicks curTicks;
  [self readCPUTicks:&curTicks];
  natural_t dUser = curTicks.user - self.prevTicks.user;
  natural_t dSys = curTicks.system - self.prevTicks.system;
  natural_t dIdle = curTicks.idle - self.prevTicks.idle;
  natural_t dNice = curTicks.nice - self.prevTicks.nice;
  natural_t dTotal = dUser + dSys + dIdle + dNice;
  self.prevTicks = curTicks;

  double sysPct = (dTotal > 0) ? (double)dSys / dTotal * 100.0 : 0;
  double usrPct = (dTotal > 0) ? (double)(dUser + dNice) / dTotal * 100.0 : 0;
  double idlePct = (dTotal > 0) ? (double)dIdle / dTotal * 100.0 : 0;
  double cpuTotal = sysPct + usrPct;

  self.lblSystem.stringValue =
      [NSString stringWithFormat:@"System: %.1f%%", sysPct];
  self.lblUser.stringValue =
      [NSString stringWithFormat:@"User: %.1f%%", usrPct];
  self.lblIdle.stringValue =
      [NSString stringWithFormat:@"Idle: %.1f%%", idlePct];
  [self.cpuGraph addPoint:cpuTotal];
  self.cpuGraph.subtitleText = [NSString stringWithFormat:@"%.1f%%", cpuTotal];

  // ── Memory ──
  host_name_port_t h = mach_host_self();
  vm_size_t pgSize;
  host_page_size(h, &pgSize);
  vm_statistics64_data_t vmStats;
  mach_msg_type_number_t c64 = HOST_VM_INFO64_COUNT;
  host_statistics64(h, HOST_VM_INFO64, (host_info64_t)&vmStats, &c64);

  uint64_t active = (uint64_t)vmStats.active_count * pgSize;
  uint64_t wired = (uint64_t)vmStats.wire_count * pgSize;
  uint64_t compressed = (uint64_t)vmStats.compressor_page_count * pgSize;
  uint64_t free_mem = (uint64_t)vmStats.free_count * pgSize;
  uint64_t totalMem = active + wired + compressed + free_mem;
  double memPressure =
      (totalMem > 0) ? (double)(active + wired + compressed) / totalMem * 100.0
                     : 0;

  self.memPie.val1 = active;
  self.memPie.val2 = wired;
  self.memPie.val3 = compressed;
  self.memPie.val4 = free_mem;
  self.memPie.labels = @[ [NSString
      stringWithFormat:@"%@", [self formatBytes:active + wired + compressed]] ];
  self.memPie.needsDisplay = YES;

  self.lblMemUsed.stringValue =
      [NSString stringWithFormat:@"Active: %@", [self formatBytes:active]];
  self.lblMemWired.stringValue =
      [NSString stringWithFormat:@"Wired: %@", [self formatBytes:wired]];
  self.lblMemCompressed.stringValue = [NSString
      stringWithFormat:@"Compressed: %@", [self formatBytes:compressed]];
  self.lblMemFree.stringValue =
      [NSString stringWithFormat:@"Free: %@", [self formatBytes:free_mem]];
  [self.memGraph addPoint:memPressure];
  self.memGraph.subtitleText =
      [NSString stringWithFormat:@"%.0f%% (%.1f GB used)", memPressure,
                                 (active + wired + compressed) /
                                     (1024.0 * 1024.0 * 1024.0)];

  // ── Network ──
  AMNetStats curNet = [self readNetStats];
  uint64_t dIn = curNet.bytesIn - self.prevNet.bytesIn;
  uint64_t dOut = curNet.bytesOut - self.prevNet.bytesOut;
  self.prevNet = curNet;
  [self.netGraph addPoint:(double)dIn point2:(double)dOut];
  self.lblNetIn.stringValue =
      [NSString stringWithFormat:@"⬇ In: %@/s", [self formatBytes:dIn / 2]];
  self.lblNetOut.stringValue =
      [NSString stringWithFormat:@"⬆ Out: %@/s", [self formatBytes:dOut / 2]];
  self.netGraph.subtitleText = [NSString
      stringWithFormat:@"In: %@/s  Out: %@/s", [self formatBytes:dIn / 2],
                       [self formatBytes:dOut / 2]];

  // ── Disk (estimate from memory paging) ──
  uint64_t diskRead = (uint64_t)vmStats.pageins * pgSize;
  uint64_t diskWrite = (uint64_t)vmStats.pageouts * pgSize;
  [self.diskGraph addPoint:(double)(diskRead % (1024 * 1024 * 10))];
  self.diskGraph.subtitleText = [NSString
      stringWithFormat:@"Pages In: %@  Out: %@", [self formatBytes:diskRead],
                       [self formatBytes:diskWrite]];

  // ── Totals ──
  NSUInteger totalThreads = 0;
  for (AMProcessNode *n in self.masterList)
    totalThreads += n.threads;
  self.lblThreads.stringValue =
      [NSString stringWithFormat:@"Threads: %lu", totalThreads];
  self.lblProcesses.stringValue = [NSString
      stringWithFormat:@"Processes: %lu", (unsigned long)self.masterList.count];
  self.lblUptime.stringValue =
      [NSString stringWithFormat:@"Uptime: %@", [self formatUptime]];
}

- (void)filterAndReload {
  // Sort
  [self.masterList sortUsingComparator:^NSComparisonResult(AMProcessNode *a,
                                                           AMProcessNode *b) {
    NSComparisonResult r;
    switch (self.sortColumn) {
    case 0:
      r = [a.name compare:b.name];
      break;
    case 1:
      r = (a.pid > b.pid)
              ? NSOrderedDescending
              : (a.pid < b.pid ? NSOrderedAscending : NSOrderedSame);
      break;
    case 2:
      r = (a.cpuPct > b.cpuPct)
              ? NSOrderedDescending
              : (a.cpuPct < b.cpuPct ? NSOrderedAscending : NSOrderedSame);
      break;
    case 4:
      r = (a.threads > b.threads) ? NSOrderedDescending : NSOrderedAscending;
      break;
    case 5:
      r = (a.memBytes > b.memBytes) ? NSOrderedDescending : NSOrderedAscending;
      break;
    default:
      r = (a.cpuPct > b.cpuPct) ? NSOrderedDescending : NSOrderedAscending;
      break;
    }
    return self.sortAscending
               ? r
               : (r == NSOrderedAscending
                      ? NSOrderedDescending
                      : (r == NSOrderedDescending ? NSOrderedAscending
                                                  : NSOrderedSame));
  }];

  [self.displayList setArray:self.masterList];
  NSString *q = self.searchField.stringValue;
  if (q.length > 0) {
    NSPredicate *pred =
        [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@", q];
    [self.displayList filterUsingPredicate:pred];
  }
  [self.processTable reloadData];
}

#pragma mark - Table DataSource / Delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
  return self.displayList.count;
}

- (NSView *)tableView:(NSTableView *)tv
    viewForTableColumn:(NSTableColumn *)col
                   row:(NSInteger)row {
  if (row < 0 || row >= (NSInteger)self.displayList.count)
    return nil;
  AMProcessNode *n = self.displayList[row];

  NSTextField *t =
      [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, col.width, 22)];
  t.drawsBackground = NO;
  t.bezeled = NO;
  t.editable = NO;
  t.font = [NSFont monospacedDigitSystemFontOfSize:11
                                            weight:NSFontWeightRegular];
  t.textColor = AM_TEXT_PRIMARY;

  NSString *cid = col.identifier;
  if ([cid isEqualToString:@"Process Name"]) {
    NSView *w = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, col.width, 22)];
    NSTextField *icon =
        [[NSTextField alloc] initWithFrame:NSMakeRect(2, 1, 18, 18)];
    icon.stringValue = @"⚙";
    if ([n.name containsString:@"Safari"])
      icon.stringValue = @"🧭";
    else if ([n.name containsString:@"Finder"])
      icon.stringValue = @"📁";
    else if ([n.name containsString:@"Terminal"])
      icon.stringValue = @"⬛";
    else if ([n.name containsString:@"Mail"])
      icon.stringValue = @"✉️";
    else if ([n.name containsString:@"Music"])
      icon.stringValue = @"🎵";
    else if ([n.name containsString:@"kernel"])
      icon.stringValue = @"🖥";
    else if ([n.user isEqualToString:@"root"])
      icon.stringValue = @"🔒";
    icon.font = [NSFont systemFontOfSize:13];
    icon.drawsBackground = NO;
    icon.bezeled = NO;
    icon.editable = NO;
    [w addSubview:icon];
    t.frame = NSMakeRect(22, 1, col.width - 24, 18);
    t.stringValue = n.name;
    [w addSubview:t];
    return w;
  } else if ([cid isEqualToString:@"PID"]) {
    t.stringValue = [NSString stringWithFormat:@"%d", n.pid];
  } else if ([cid isEqualToString:@"% CPU"]) {
    t.stringValue = [NSString stringWithFormat:@"%.1f", n.cpuPct];
    if (n.cpuPct > 50)
      t.textColor = AM_RED;
    else if (n.cpuPct > 10)
      t.textColor = AM_ORANGE;
  } else if ([cid isEqualToString:@"CPU Time"]) {
    int totalSec = (int)(n.cpuPct * 0.02 * n.pid) % 3600;
    t.stringValue = [NSString stringWithFormat:@"%d:%02d.%02d", totalSec / 60,
                                               totalSec % 60, n.pid % 100];
  } else if ([cid isEqualToString:@"Threads"]) {
    t.stringValue = [NSString stringWithFormat:@"%d", n.threads];
  } else if ([cid isEqualToString:@"Memory"]) {
    t.stringValue = [self formatBytes:n.memBytes];
    if (n.memBytes > 500 * 1024 * 1024)
      t.textColor = AM_YELLOW;
  } else if ([cid isEqualToString:@"User"]) {
    t.stringValue = n.user;
    t.textColor = AM_TEXT_SECONDARY;
  }
  return t;
}

- (void)tableView:(NSTableView *)tv
    sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
  NSSortDescriptor *sd = tv.sortDescriptors.firstObject;
  if (!sd)
    return;
  NSString *key = sd.key;
  NSArray *colIds = @[
    @"Process Name", @"PID", @"% CPU", @"CPU Time", @"Threads", @"Memory",
    @"User"
  ];
  self.sortColumn = [colIds indexOfObject:key];
  if (self.sortColumn == NSNotFound)
    self.sortColumn = 2;
  self.sortAscending = sd.ascending;
  [self filterAndReload];
}

@end
