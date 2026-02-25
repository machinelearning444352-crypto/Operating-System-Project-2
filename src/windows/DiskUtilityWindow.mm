#import "DiskUtilityWindow.h"
#import "../helpers/GlassmorphismHelper.h"
#include <sys/mount.h>

@interface DiskUtilityWindow () <NSOutlineViewDataSource, NSOutlineViewDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSOutlineView *diskOutline;
@property(nonatomic, strong) NSMutableArray *diskList;
@property(nonatomic, strong) NSView *detailView;
@property(nonatomic, strong) NSTextField *diskNameLabel, *diskSizeLabel,
    *diskTypeLabel, *diskUsedLabel, *diskFreeLabel, *diskFormatLabel;
@property(nonatomic, strong) NSProgressIndicator *usageBar;
@property(nonatomic, strong) NSView *pieChartView;
@end

@implementation DiskUtilityWindow

+ (instancetype)sharedInstance {
  static DiskUtilityWindow *inst;
  static dispatch_once_t t;
  dispatch_once(&t, ^{
    inst = [[self alloc] init];
  });
  return inst;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _diskList = [NSMutableArray array];
    [self loadDiskInfo];
  }
  return self;
}

- (void)loadDiskInfo {
  struct statfs *mounts;
  int count = getmntinfo(&mounts, MNT_NOWAIT);
  [self.diskList removeAllObjects];

  for (int i = 0; i < count; i++) {
    NSString *mountPoint = @(mounts[i].f_mntonname);
    NSString *device = @(mounts[i].f_mntfromname);
    NSString *fsType = @(mounts[i].f_fstypename);

    uint64_t totalBytes = (uint64_t)mounts[i].f_blocks * mounts[i].f_bsize;
    uint64_t freeBytes = (uint64_t)mounts[i].f_bfree * mounts[i].f_bsize;
    uint64_t usedBytes = totalBytes - freeBytes;

    if (totalBytes == 0)
      continue;

    [self.diskList addObject:@{
      @"name" : mountPoint,
      @"device" : device,
      @"fsType" : fsType,
      @"total" : @(totalBytes),
      @"used" : @(usedBytes),
      @"free" : @(freeBytes),
      @"percent" : @((double)usedBytes / totalBytes * 100.0),
      @"icon" : [mountPoint isEqualToString:@"/"] ? @"💿" : @"📁",
      @"smart" : @"Verified",
      @"partitionMap" : @"GUID Partition Map"
    }];
  }
}

- (void)showWindow {
  if (self.window) {
    [self.window makeKeyAndOrderFront:nil];
    return;
  }

  self.window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(120, 120, 850, 600)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.window.title = @"Disk Utility";
  self.window.backgroundColor = [NSColor colorWithRed:0.12
                                                green:0.12
                                                 blue:0.14
                                                alpha:1.0];
  self.window.minSize = NSMakeSize(700, 450);

  NSView *content = self.window.contentView;

  // ===== Toolbar =====
  NSView *toolbar = [[NSView alloc] initWithFrame:NSMakeRect(0, 555, 850, 45)];
  toolbar.wantsLayer = YES;
  toolbar.layer.backgroundColor =
      [NSColor controlBackgroundColor].CGColor;
  toolbar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [content addSubview:toolbar];

  NSArray *actions = @[
    @"First Aid", @"Partition", @"Erase", @"Restore", @"Unmount", @"Info"
  ];
  CGFloat btnX = 20;
  for (NSString *action in actions) {
    NSButton *btn =
        [[NSButton alloc] initWithFrame:NSMakeRect(btnX, 8, 85, 28)];
    btn.title = action;
    btn.bezelStyle = NSBezelStyleRounded;
    btn.target = self;
    btn.action = @selector(toolbarAction:);
    [toolbar addSubview:btn];
    btnX += 95;
  }

  // ===== Sidebar (Disk List) =====
  NSScrollView *sideScroll =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 250, 555)];
  sideScroll.hasVerticalScroller = YES;
  sideScroll.autoresizingMask = NSViewHeightSizable;
  sideScroll.backgroundColor = [NSColor colorWithRed:0.15
                                               green:0.15
                                                blue:0.18
                                               alpha:1.0];

  self.diskOutline = [[NSOutlineView alloc] initWithFrame:sideScroll.bounds];
  self.diskOutline.dataSource = self;
  self.diskOutline.delegate = self;
  self.diskOutline.rowHeight = 40;
  self.diskOutline.backgroundColor = [NSColor colorWithRed:0.15
                                                     green:0.15
                                                      blue:0.18
                                                     alpha:1.0];

  NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"disk"];
  col.title = @"Volumes";
  col.width = 230;
  [self.diskOutline addTableColumn:col];
  self.diskOutline.outlineTableColumn = col;

  sideScroll.documentView = self.diskOutline;
  [content addSubview:sideScroll];

  // ===== Detail Panel =====
  self.detailView = [[NSView alloc] initWithFrame:NSMakeRect(260, 0, 590, 555)];
  self.detailView.wantsLayer = YES;
  self.detailView.layer.backgroundColor =
      [NSColor colorWithRed:0.13 green:0.13 blue:0.16 alpha:1.0].CGColor;
  self.detailView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [content addSubview:self.detailView];

  // Detail labels
  self.diskNameLabel = [self makeLabelAt:NSMakePoint(30, 490)
                                    text:@"Select a disk"
                                    size:22
                                    bold:YES];
  [self.detailView addSubview:self.diskNameLabel];

  self.diskFormatLabel = [self makeLabelAt:NSMakePoint(30, 460)
                                      text:@""
                                      size:13
                                      bold:NO];
  self.diskFormatLabel.textColor = [NSColor grayColor];
  [self.detailView addSubview:self.diskFormatLabel];

  // Pie chart placeholder
  self.pieChartView =
      [[NSView alloc] initWithFrame:NSMakeRect(30, 250, 200, 200)];
  self.pieChartView.wantsLayer = YES;
  self.pieChartView.layer.cornerRadius = 100;
  self.pieChartView.layer.backgroundColor = [NSColor systemBlueColor].CGColor;
  [self.detailView addSubview:self.pieChartView];

  // Usage bar
  self.usageBar =
      [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(260, 370, 280, 20)];
  self.usageBar.style = NSProgressIndicatorStyleBar;
  self.usageBar.minValue = 0;
  self.usageBar.maxValue = 100;
  [self.detailView addSubview:self.usageBar];

  self.diskSizeLabel = [self makeLabelAt:NSMakePoint(260, 400)
                                    text:@"Total: —"
                                    size:14
                                    bold:NO];
  [self.detailView addSubview:self.diskSizeLabel];
  self.diskUsedLabel = [self makeLabelAt:NSMakePoint(260, 340)
                                    text:@"Used: —"
                                    size:13
                                    bold:NO];
  self.diskUsedLabel.textColor = [NSColor systemBlueColor];
  [self.detailView addSubview:self.diskUsedLabel];
  self.diskFreeLabel = [self makeLabelAt:NSMakePoint(260, 315)
                                    text:@"Available: —"
                                    size:13
                                    bold:NO];
  self.diskFreeLabel.textColor = [NSColor systemGreenColor];
  [self.detailView addSubview:self.diskFreeLabel];
  self.diskTypeLabel = [self makeLabelAt:NSMakePoint(260, 290)
                                    text:@""
                                    size:13
                                    bold:NO];
  self.diskTypeLabel.textColor = [NSColor grayColor];
  [self.detailView addSubview:self.diskTypeLabel];

  // Info boxes
  NSArray *infoItems = @[
    @"SMART Status: ✅ Verified", @"Partition Map: GUID",
    @"Connection: Internal"
  ];
  CGFloat infoY = 220;
  for (NSString *info in infoItems) {
    NSView *infoBox =
        [[NSView alloc] initWithFrame:NSMakeRect(30, infoY, 510, 35)];
    infoBox.wantsLayer = YES;
    infoBox.layer.backgroundColor =
        [NSColor colorWithRed:0.18 green:0.18 blue:0.22 alpha:1.0].CGColor;
    infoBox.layer.cornerRadius = 6;
    NSTextField *lbl = [self makeLabelAt:NSMakePoint(12, 8)
                                    text:info
                                    size:12
                                    bold:NO];
    [infoBox addSubview:lbl];
    [self.detailView addSubview:infoBox];
    infoY -= 42;
  }

  [self.diskOutline reloadData];
  [self.window makeKeyAndOrderFront:nil];
}

- (void)toolbarAction:(NSButton *)sender {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = sender.title;
  alert.informativeText = [NSString
      stringWithFormat:@"%@ operation would be performed on the selected disk.",
                       sender.title];
  [alert runModal];
}

// ===== OutlineView =====

- (NSInteger)outlineView:(NSOutlineView *)ov numberOfChildrenOfItem:(id)item {
  return item == nil ? self.diskList.count : 0;
}
- (id)outlineView:(NSOutlineView *)ov child:(NSInteger)idx ofItem:(id)item {
  return self.diskList[idx];
}
- (BOOL)outlineView:(NSOutlineView *)ov isItemExpandable:(id)item {
  return NO;
}

- (NSView *)outlineView:(NSOutlineView *)ov
     viewForTableColumn:(NSTableColumn *)col
                   item:(id)item {
  NSDictionary *disk = (NSDictionary *)item;
  NSTableCellView *cell =
      [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 230, 38)];
  NSTextField *name =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, 18, 190, 18)];
  name.stringValue =
      [NSString stringWithFormat:@"%@ %@", disk[@"icon"], disk[@"name"]];
  name.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
  name.textColor = [NSColor whiteColor];
  name.editable = NO;
  name.bordered = NO;
  name.drawsBackground = NO;
  [cell addSubview:name];

  NSTextField *size =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, 2, 190, 14)];
  uint64_t total = [disk[@"total"] unsignedLongLongValue];
  size.stringValue = [NSString
      stringWithFormat:@"%.1f GB — %@", total / 1073741824.0, disk[@"fsType"]];
  size.font = [NSFont systemFontOfSize:10];
  size.textColor = [NSColor grayColor];
  size.editable = NO;
  size.bordered = NO;
  size.drawsBackground = NO;
  [cell addSubview:size];
  return cell;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)note {
  NSInteger row = self.diskOutline.selectedRow;
  if (row < 0 || row >= (NSInteger)self.diskList.count)
    return;
  NSDictionary *disk = self.diskList[row];

  uint64_t total = [disk[@"total"] unsignedLongLongValue];
  uint64_t used = [disk[@"used"] unsignedLongLongValue];
  uint64_t free = [disk[@"free"] unsignedLongLongValue];

  self.diskNameLabel.stringValue =
      [NSString stringWithFormat:@"%@ %@", disk[@"icon"], disk[@"name"]];
  self.diskFormatLabel.stringValue =
      [NSString stringWithFormat:@"%@ — %@", disk[@"fsType"], disk[@"device"]];
  self.diskSizeLabel.stringValue =
      [NSString stringWithFormat:@"Total: %.2f GB", total / 1073741824.0];
  self.diskUsedLabel.stringValue =
      [NSString stringWithFormat:@"Used: %.2f GB (%.1f%%)", used / 1073741824.0,
                                 [disk[@"percent"] doubleValue]];
  self.diskFreeLabel.stringValue =
      [NSString stringWithFormat:@"Available: %.2f GB", free / 1073741824.0];
  self.diskTypeLabel.stringValue =
      [NSString stringWithFormat:@"Device: %@  |  SMART: %@", disk[@"device"],
                                 disk[@"smart"]];
  self.usageBar.doubleValue = [disk[@"percent"] doubleValue];
}

- (NSTextField *)makeLabelAt:(NSPoint)pt
                        text:(NSString *)text
                        size:(CGFloat)size
                        bold:(BOOL)bold {
  NSTextField *tf =
      [[NSTextField alloc] initWithFrame:NSMakeRect(pt.x, pt.y, 350, size + 8)];
  tf.stringValue = text;
  tf.font =
      [NSFont systemFontOfSize:size
                        weight:bold ? NSFontWeightBold : NSFontWeightRegular];
  tf.textColor = [NSColor whiteColor];
  tf.editable = NO;
  tf.bordered = NO;
  tf.drawsBackground = NO;
  return tf;
}

@end
