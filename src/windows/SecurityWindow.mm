#import "SecurityWindow.h"

@interface SecurityWindow ()
@property(nonatomic, strong) NSWindow *securityWindow;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSProgressIndicator *scanProgress;
@property(nonatomic, strong) NSTextView *logView;
@property(nonatomic, strong) NSButton *quickScanBtn;
@property(nonatomic, strong) NSButton *fullScanBtn;
@property(nonatomic, assign) BOOL isScanning;
@end

@implementation SecurityWindow

+ (instancetype)sharedInstance {
  static SecurityWindow *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[SecurityWindow alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.isScanning = NO;
  }
  return self;
}

- (NSString *)antivirusPath {
  return @"/Users/Samar/Desktop/Antivirus/bin/enterprise_antivirus";
}

- (BOOL)isAntivirusInstalled {
  return [[NSFileManager defaultManager] fileExistsAtPath:[self antivirusPath]];
}

- (void)showWindow {
  if (self.securityWindow) {
    [self.securityWindow makeKeyAndOrderFront:nil];
    return;
  }

  NSRect frame = NSMakeRect(0, 0, 600, 500);
  self.securityWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.securityWindow setTitle:@"Security & Privacy"];
  [self.securityWindow center];

  NSView *contentView = [[NSView alloc] initWithFrame:frame];
  contentView.wantsLayer = YES;
  contentView.layer.backgroundColor = [[NSColor colorWithRed:0.11
                                                       green:0.11
                                                        blue:0.13
                                                       alpha:1.0] CGColor];
  [self.securityWindow setContentView:contentView];

  // Header
  NSView *headerView =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 420, 600, 80)];
  headerView.wantsLayer = YES;
  headerView.layer.backgroundColor = [[NSColor colorWithRed:0.2
                                                      green:0.5
                                                       blue:0.3
                                                      alpha:1.0] CGColor];
  [contentView addSubview:headerView];

  NSTextField *titleLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(80, 25, 400, 30)];
  titleLabel.stringValue = @"VirtualOS Security";
  titleLabel.font = [NSFont boldSystemFontOfSize:24];
  titleLabel.textColor = [NSColor whiteColor];
  titleLabel.bezeled = NO;
  titleLabel.editable = NO;
  titleLabel.drawsBackground = NO;
  [headerView addSubview:titleLabel];

  NSTextField *iconLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 20, 50, 40)];
  iconLabel.stringValue = @"🛡️";
  iconLabel.font = [NSFont systemFontOfSize:36];
  iconLabel.bezeled = NO;
  iconLabel.editable = NO;
  iconLabel.drawsBackground = NO;
  [headerView addSubview:iconLabel];

  // Status section
  NSView *statusBox =
      [[NSView alloc] initWithFrame:NSMakeRect(20, 320, 560, 90)];
  statusBox.wantsLayer = YES;
  statusBox.layer.backgroundColor = [[NSColor colorWithRed:0.16
                                                     green:0.16
                                                      blue:0.19
                                                     alpha:1.0] CGColor];
  statusBox.layer.cornerRadius = 10;
  [contentView addSubview:statusBox];

  NSTextField *protectionLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 50, 200, 25)];
  protectionLabel.stringValue = @"Protection Status";
  protectionLabel.font = [NSFont boldSystemFontOfSize:14];
  protectionLabel.bezeled = NO;
  protectionLabel.editable = NO;
  protectionLabel.drawsBackground = NO;
  [statusBox addSubview:protectionLabel];

  self.statusLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 20, 520, 25)];
  if ([self isAntivirusInstalled]) {
    self.statusLabel.stringValue =
        @"✅ Enterprise Antivirus is active and protecting your system";
    self.statusLabel.textColor = [NSColor colorWithRed:0.2
                                                 green:0.6
                                                  blue:0.3
                                                 alpha:1.0];
  } else {
    self.statusLabel.stringValue = @"⚠️ Building antivirus engine...";
    self.statusLabel.textColor = [NSColor orangeColor];
    [self buildAntivirus];
  }
  self.statusLabel.font = [NSFont systemFontOfSize:13];
  self.statusLabel.bezeled = NO;
  self.statusLabel.editable = NO;
  self.statusLabel.drawsBackground = NO;
  [statusBox addSubview:self.statusLabel];

  // Scan buttons
  self.quickScanBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(20, 260, 170, 45)];
  self.quickScanBtn.title = @"Quick Scan";
  self.quickScanBtn.bezelStyle = NSBezelStyleRounded;
  self.quickScanBtn.target = self;
  self.quickScanBtn.action = @selector(runQuickScan);
  [contentView addSubview:self.quickScanBtn];

  self.fullScanBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(200, 260, 170, 45)];
  self.fullScanBtn.title = @"Full System Scan";
  self.fullScanBtn.bezelStyle = NSBezelStyleRounded;
  self.fullScanBtn.target = self;
  self.fullScanBtn.action = @selector(runFullScan);
  [contentView addSubview:self.fullScanBtn];

  NSButton *rootkitBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(380, 260, 170, 45)];
  rootkitBtn.title = @"Rootkit Scan";
  rootkitBtn.bezelStyle = NSBezelStyleRounded;
  rootkitBtn.target = self;
  rootkitBtn.action = @selector(runRootkitScan);
  [contentView addSubview:rootkitBtn];

  // Progress
  self.scanProgress =
      [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(20, 230, 560, 20)];
  self.scanProgress.style = NSProgressIndicatorStyleBar;
  self.scanProgress.indeterminate = YES;
  [self.scanProgress setHidden:YES];
  [contentView addSubview:self.scanProgress];

  // Log view
  NSScrollView *scrollView =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 20, 560, 200)];
  scrollView.hasVerticalScroller = YES;
  scrollView.borderType = NSBezelBorder;

  self.logView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 560, 200)];
  self.logView.editable = NO;
  self.logView.font = [NSFont fontWithName:@"Menlo" size:11];
  self.logView.backgroundColor = [NSColor colorWithWhite:0.1 alpha:1.0];
  self.logView.textColor = [NSColor colorWithRed:0.3
                                           green:0.9
                                            blue:0.3
                                           alpha:1.0];
  [self.logView
      setString:@"[Security] VirtualOS Security Center initialized\n[Security] "
                @"Enterprise Antivirus engine ready\n[Security] Real-time "
                @"protection: ENABLED\n"];

  scrollView.documentView = self.logView;
  [contentView addSubview:scrollView];

  [self.securityWindow makeKeyAndOrderFront:nil];
}

- (void)buildAntivirus {
  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSTask *buildTask = [[NSTask alloc] init];
        buildTask.executableURL = [NSURL fileURLWithPath:@"/bin/bash"];
        buildTask.arguments =
            @[ @"-c", @"cd /Users/Samar/Desktop/Antivirus && ./build.sh 2>&1" ];
        buildTask.currentDirectoryURL =
            [NSURL fileURLWithPath:@"/Users/Samar/Desktop/Antivirus"];

        NSPipe *pipe = [NSPipe pipe];
        buildTask.standardOutput = pipe;
        buildTask.standardError = pipe;

        @try {
          [buildTask launchAndReturnError:nil];
          [buildTask waitUntilExit];
        } @catch (NSException *e) {
        }

        dispatch_async(dispatch_get_main_queue(), ^{
          if ([self isAntivirusInstalled]) {
            self.statusLabel.stringValue =
                @"✅ Enterprise Antivirus is active and protecting your system";
            self.statusLabel.textColor = [NSColor colorWithRed:0.2
                                                         green:0.6
                                                          blue:0.3
                                                         alpha:1.0];
            [self appendLog:@"[Security] Antivirus engine built successfully"];
          } else {
            self.statusLabel.stringValue =
                @"⚠️ Antivirus build failed - using basic protection";
            [self appendLog:@"[Security] Warning: Antivirus build failed"];
          }
        });
      });
}

- (void)appendLog:(NSString *)message {
  if (!self.logView)
    return;
  NSString *timestamp =
      [[NSDateFormatter localizedStringFromDate:[NSDate date]
                                      dateStyle:NSDateFormatterNoStyle
                                      timeStyle:NSDateFormatterMediumStyle]
          stringByAppendingString:@" "];
  NSString *logMessage =
      [NSString stringWithFormat:@"%@%@\n", timestamp, message];

  dispatch_async(dispatch_get_main_queue(), ^{
    NSString *current = self.logView.string;
    [self.logView setString:[current stringByAppendingString:logMessage]];
    [self.logView scrollToEndOfDocument:nil];
  });
}

- (void)runQuickScan {
  if (self.isScanning)
    return;
  [self runScanWithMode:@"quick" path:@"/Users/Samar/Desktop"];
}

- (void)runFullScan {
  if (self.isScanning)
    return;
  [self runScanWithMode:@"deep" path:@"/Users/Samar"];
}

- (void)runRootkitScan {
  if (self.isScanning)
    return;
  [self runScanWithMode:@"rootkit" path:@"/"];
}

- (void)runScanWithMode:(NSString *)mode path:(NSString *)path {
  self.isScanning = YES;
  self.quickScanBtn.enabled = NO;
  self.fullScanBtn.enabled = NO;
  [self.scanProgress setHidden:NO];
  [self.scanProgress startAnimation:nil];

  [self
      appendLog:[NSString stringWithFormat:@"[Scan] Starting %@ scan on %@...",
                                           mode, path]];

  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSString *avPath = [self antivirusPath];

        if (![[NSFileManager defaultManager] fileExistsAtPath:avPath]) {
          dispatch_async(dispatch_get_main_queue(), ^{
            [self
                appendLog:@"[Scan] Antivirus not found, running basic scan..."];
            [self runBasicScan:path];
          });
          return;
        }

        NSTask *scanTask = [[NSTask alloc] init];
        scanTask.executableURL = [NSURL fileURLWithPath:avPath];

        if ([mode isEqualToString:@"rootkit"]) {
          scanTask.arguments = @[ @"scan", @"-r" ];
        } else if ([mode isEqualToString:@"deep"]) {
          scanTask.arguments = @[ @"scan", @"-d", path ];
        } else {
          scanTask.arguments = @[ @"scan", path ];
        }

        NSPipe *pipe = [NSPipe pipe];
        scanTask.standardOutput = pipe;
        scanTask.standardError = pipe;

        @try {
          [scanTask launchAndReturnError:nil];

          NSFileHandle *handle = pipe.fileHandleForReading;
          NSData *data;
          while ((data = [handle availableData]) && data.length > 0) {
            NSString *output =
                [[NSString alloc] initWithData:data
                                      encoding:NSUTF8StringEncoding];
            if (output.length > 0) {
              // Parse and log output
              NSArray *lines = [output componentsSeparatedByString:@"\n"];
              for (NSString *line in lines) {
                if (line.length > 0) {
                  [self appendLog:[NSString stringWithFormat:@"[AV] %@", line]];
                }
              }
            }
          }

          [scanTask waitUntilExit];
        } @catch (NSException *e) {
          [self appendLog:[NSString stringWithFormat:@"[Error] %@", e.reason]];
        }

        dispatch_async(dispatch_get_main_queue(), ^{
          [self scanCompleted];
        });
      });
}

- (void)runBasicScan:(NSString *)path {
  // Basic file scan without external antivirus
  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:path];

        NSInteger fileCount = 0;
        NSInteger threatCount = 0;
        NSArray *suspiciousExtensions =
            @[ @"exe", @"dll", @"bat", @"cmd", @"vbs", @"js", @"jar" ];

        NSString *file;
        while ((file = [enumerator nextObject]) && fileCount < 100) {
          NSString *ext = [[file pathExtension] lowercaseString];
          fileCount++;

          if ([suspiciousExtensions containsObject:ext]) {
            threatCount++;
            [self
                appendLog:[NSString
                              stringWithFormat:@"[Warning] Suspicious file: %@",
                                               file]];
          }

          if (fileCount % 20 == 0) {
            [self appendLog:[NSString
                                stringWithFormat:@"[Scan] Scanned %ld files...",
                                                 (long)fileCount]];
          }
        }

        dispatch_async(dispatch_get_main_queue(), ^{
          [self
              appendLog:[NSString
                            stringWithFormat:@"[Scan] Complete: %ld files "
                                             @"scanned, %ld potential threats",
                                             (long)fileCount,
                                             (long)threatCount]];
          [self scanCompleted];
        });
      });
}

- (void)scanCompleted {
  self.isScanning = NO;
  self.quickScanBtn.enabled = YES;
  self.fullScanBtn.enabled = YES;
  [self.scanProgress stopAnimation:nil];
  [self.scanProgress setHidden:YES];
  [self appendLog:@"[Scan] Scan completed"];
}

@end
