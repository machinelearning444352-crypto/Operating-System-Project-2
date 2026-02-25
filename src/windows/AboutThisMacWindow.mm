#import "AboutThisMacWindow.h"
#import "../helpers/SystemInfoHelper.h"

@interface AboutThisMacWindow ()
@property(nonatomic, strong) NSWindow *aboutWindow;
@end

@implementation AboutThisMacWindow

+ (instancetype)sharedInstance {
  static AboutThisMacWindow *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[AboutThisMacWindow alloc] init];
  });
  return instance;
}

- (void)showWindow {
  if (self.aboutWindow) {
    [self.aboutWindow makeKeyAndOrderFront:nil];
    return;
  }

  NSRect frame = NSMakeRect(0, 0, 540, 380);
  self.aboutWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.aboutWindow setTitle:@"About This Mac"];
  [self.aboutWindow center];

  NSView *contentView = [[NSView alloc] initWithFrame:frame];
  contentView.wantsLayer = YES;
  contentView.layer.backgroundColor = [[NSColor colorWithRed:0.11
                                                       green:0.11
                                                        blue:0.13
                                                       alpha:1.0] CGColor];
  [self.aboutWindow setContentView:contentView];

  // macOS Logo/Icon
  NSTextField *logoField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(0, 290, 540, 60)];
  logoField.stringValue = @"🍎";
  logoField.font = [NSFont systemFontOfSize:48];
  logoField.alignment = NSTextAlignmentCenter;
  logoField.bezeled = NO;
  logoField.editable = NO;
  logoField.drawsBackground = NO;
  [contentView addSubview:logoField];

  // OS Name
  NSTextField *osNameField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(0, 250, 540, 35)];
  osNameField.stringValue = [SystemInfoHelper osVersion];
  osNameField.font = [NSFont systemFontOfSize:26 weight:NSFontWeightLight];
  osNameField.alignment = NSTextAlignmentCenter;
  osNameField.textColor = [NSColor blackColor];
  osNameField.bezeled = NO;
  osNameField.editable = NO;
  osNameField.drawsBackground = NO;
  [contentView addSubview:osNameField];

  // System Info Section
  CGFloat yPos = 200;
  CGFloat labelX = 120;
  CGFloat valueX = 280;
  CGFloat rowHeight = 24;

  NSArray *infoItems = @[
    @{@"label" : @"Chip", @"value" : [SystemInfoHelper cpuModel]},
    @{@"label" : @"Memory", @"value" : [SystemInfoHelper memorySize]},
    @{@"label" : @"Graphics", @"value" : [SystemInfoHelper gpuModel]},
    @{@"label" : @"Serial Number", @"value" : [SystemInfoHelper serialNumber]},
    @{@"label" : @"Uptime", @"value" : [SystemInfoHelper uptime]}
  ];

  for (NSDictionary *item in infoItems) {
    // Label
    NSTextField *label =
        [[NSTextField alloc] initWithFrame:NSMakeRect(labelX, yPos, 150, 20)];
    label.stringValue = [NSString stringWithFormat:@"%@:", item[@"label"]];
    label.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    label.textColor = [NSColor grayColor];
    label.alignment = NSTextAlignmentRight;
    label.bezeled = NO;
    label.editable = NO;
    label.drawsBackground = NO;
    [contentView addSubview:label];

    // Value
    NSTextField *value =
        [[NSTextField alloc] initWithFrame:NSMakeRect(valueX, yPos, 220, 20)];
    value.stringValue = item[@"value"];
    value.font = [NSFont systemFontOfSize:12];
    value.textColor = [NSColor blackColor];
    value.bezeled = NO;
    value.editable = NO;
    value.drawsBackground = NO;
    [contentView addSubview:value];

    yPos -= rowHeight;
  }

  // Buttons at bottom
  NSButton *systemReportBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(120, 25, 140, 32)];
  systemReportBtn.title = @"System Report...";
  systemReportBtn.bezelStyle = NSBezelStyleRounded;
  [contentView addSubview:systemReportBtn];

  NSButton *softwareUpdateBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(280, 25, 140, 32)];
  softwareUpdateBtn.title = @"Software Update...";
  softwareUpdateBtn.bezelStyle = NSBezelStyleRounded;
  [contentView addSubview:softwareUpdateBtn];

  [self.aboutWindow makeKeyAndOrderFront:nil];
}

@end
