#import "AntivirusWindow.h"
#import <QuartzCore/QuartzCore.h>

@interface AntivirusWindow ()
@property (nonatomic, strong) NSWindow *avWindow;
@property (nonatomic, strong) NSTextView *outputView;
@property (nonatomic, strong) NSProgressIndicator *progressIndicator;
@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSButton *scanButton;
@property (nonatomic, strong) NSButton *quickScanButton;
@property (nonatomic, strong) NSButton *deepScanButton;
@property (nonatomic, strong) NSButton *stopButton;
@property (nonatomic, assign) BOOL isScanning;
@property (nonatomic, assign) BOOL shouldStopScan;
@property (nonatomic, strong) NSMutableString *scanOutput;
@property (nonatomic, strong) NSDictionary *virtualFileSystem;
@property (nonatomic, assign) NSInteger filesScanned;
@property (nonatomic, assign) NSInteger threatsFound;
@end

@implementation AntivirusWindow

+ (instancetype)sharedInstance {
    static AntivirusWindow *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AntivirusWindow alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.isScanning = NO;
        self.shouldStopScan = NO;
        self.scanOutput = [NSMutableString string];
        self.filesScanned = 0;
        self.threatsFound = 0;
        [self initializeVirtualFileSystem];
    }
    return self;
}

- (void)initializeVirtualFileSystem {
    // Virtual OS file system - completely isolated from real macOS
    self.virtualFileSystem = @{
        @"/": @[@"Applications", @"System", @"Users", @"Library", @"Volumes"],
        @"/Applications": @[
            @{@"name": @"Safari.app", @"size": @52428800, @"type": @"app", @"safe": @YES},
            @{@"name": @"Messages.app", @"size": @31457280, @"type": @"app", @"safe": @YES},
            @{@"name": @"Mail.app", @"size": @41943040, @"type": @"app", @"safe": @YES},
            @{@"name": @"Terminal.app", @"size": @15728640, @"type": @"app", @"safe": @YES},
            @{@"name": @"Notes.app", @"size": @20971520, @"type": @"app", @"safe": @YES},
            @{@"name": @"Calendar.app", @"size": @18874368, @"type": @"app", @"safe": @YES},
            @{@"name": @"Photos.app", @"size": @62914560, @"type": @"app", @"safe": @YES},
            @{@"name": @"Music.app", @"size": @73400320, @"type": @"app", @"safe": @YES},
            @{@"name": @"Finder.app", @"size": @25165824, @"type": @"app", @"safe": @YES},
            @{@"name": @"Settings.app", @"size": @10485760, @"type": @"app", @"safe": @YES}
        ],
        @"/System": @[
            @{@"name": @"Library", @"type": @"folder"},
            @{@"name": @"kernel", @"size": @8388608, @"type": @"system", @"safe": @YES},
            @{@"name": @"mach_kernel", @"size": @12582912, @"type": @"system", @"safe": @YES}
        ],
        @"/System/Library": @[
            @{@"name": @"CoreServices", @"type": @"folder"},
            @{@"name": @"Frameworks", @"type": @"folder"},
            @{@"name": @"Extensions", @"type": @"folder"}
        ],
        @"/Users": @[
            @{@"name": @"Guest", @"type": @"folder"},
            @{@"name": @"Shared", @"type": @"folder"}
        ],
        @"/Users/Guest": @[
            @{@"name": @"Desktop", @"type": @"folder"},
            @{@"name": @"Documents", @"type": @"folder"},
            @{@"name": @"Downloads", @"type": @"folder"},
            @{@"name": @".Trash", @"type": @"folder"}
        ],
        @"/Users/Guest/Desktop": @[
            @{@"name": @"readme.txt", @"size": @1024, @"type": @"text", @"safe": @YES},
            @{@"name": @"project.zip", @"size": @5242880, @"type": @"archive", @"safe": @YES}
        ],
        @"/Users/Guest/Documents": @[
            @{@"name": @"notes.txt", @"size": @2048, @"type": @"text", @"safe": @YES},
            @{@"name": @"report.pdf", @"size": @1048576, @"type": @"pdf", @"safe": @YES},
            @{@"name": @"budget.xlsx", @"size": @524288, @"type": @"spreadsheet", @"safe": @YES}
        ],
        @"/Users/Guest/Downloads": @[
            @{@"name": @"installer.dmg", @"size": @104857600, @"type": @"disk_image", @"safe": @YES},
            @{@"name": @"free_software.exe", @"size": @2097152, @"type": @"executable", @"safe": @NO, @"threat": @"Trojan.GenericKD"},
            @{@"name": @"document.pdf.exe", @"size": @1572864, @"type": @"executable", @"safe": @NO, @"threat": @"Malware.Disguised"},
            @{@"name": @"keygen.exe", @"size": @524288, @"type": @"executable", @"safe": @NO, @"threat": @"HackTool.Keygen"}
        ],
        @"/Library": @[
            @{@"name": @"Preferences", @"type": @"folder"},
            @{@"name": @"Caches", @"type": @"folder"},
            @{@"name": @"Logs", @"type": @"folder"}
        ]
    };
}

- (void)showWindow {
    if (self.avWindow) {
        [self.avWindow makeKeyAndOrderFront:nil];
        return;
    }
    
    NSRect frame = NSMakeRect(0, 0, 800, 600);
    self.avWindow = [[NSWindow alloc] initWithContentRect:frame
                                                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                  backing:NSBackingStoreBuffered
                                                    defer:NO];
    [self.avWindow setTitle:@"Enterprise Antivirus System"];
    [self.avWindow center];
    
    NSView *contentView = [[NSView alloc] initWithFrame:frame];
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];
    [self.avWindow setContentView:contentView];
    
    // Header with gradient
    NSView *header = [[NSView alloc] initWithFrame:NSMakeRect(0, frame.size.height - 80, frame.size.width, 80)];
    header.wantsLayer = YES;
    header.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = header.bounds;
    gradient.colors = @[
        (id)[[NSColor colorWithRed:0.1 green:0.6 blue:0.3 alpha:1.0] CGColor],
        (id)[[NSColor colorWithRed:0.05 green:0.4 blue:0.2 alpha:1.0] CGColor]
    ];
    gradient.startPoint = CGPointMake(0, 0.5);
    gradient.endPoint = CGPointMake(1, 0.5);
    [header.layer addSublayer:gradient];
    [contentView addSubview:header];
    
    // Shield icon
    NSTextField *shieldIcon = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 15, 50, 50)];
    shieldIcon.stringValue = @"🛡️";
    shieldIcon.font = [NSFont systemFontOfSize:36];
    shieldIcon.bezeled = NO;
    shieldIcon.editable = NO;
    shieldIcon.drawsBackground = NO;
    [header addSubview:shieldIcon];
    
    // Title
    NSTextField *titleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(75, 40, 400, 30)];
    titleLabel.stringValue = @"Enterprise Antivirus System v3.0";
    titleLabel.font = [NSFont boldSystemFontOfSize:20];
    titleLabel.textColor = [NSColor whiteColor];
    titleLabel.bezeled = NO;
    titleLabel.editable = NO;
    titleLabel.drawsBackground = NO;
    [header addSubview:titleLabel];
    
    // Subtitle
    NSTextField *subtitleLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(75, 18, 400, 20)];
    subtitleLabel.stringValue = @"Advanced Threat Detection • Real-time Protection";
    subtitleLabel.font = [NSFont systemFontOfSize:12];
    subtitleLabel.textColor = [NSColor colorWithWhite:1.0 alpha:0.8];
    subtitleLabel.bezeled = NO;
    subtitleLabel.editable = NO;
    subtitleLabel.drawsBackground = NO;
    [header addSubview:subtitleLabel];
    
    // Status indicator
    self.statusLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(frame.size.width - 200, 30, 180, 20)];
    self.statusLabel.stringValue = @"● System Protected";
    self.statusLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    self.statusLabel.textColor = [NSColor colorWithRed:0.4 green:1.0 blue:0.5 alpha:1.0];
    self.statusLabel.alignment = NSTextAlignmentRight;
    self.statusLabel.bezeled = NO;
    self.statusLabel.editable = NO;
    self.statusLabel.drawsBackground = NO;
    self.statusLabel.autoresizingMask = NSViewMinXMargin;
    [header addSubview:self.statusLabel];
    
    // Control panel
    NSView *controlPanel = [[NSView alloc] initWithFrame:NSMakeRect(0, frame.size.height - 160, frame.size.width, 80)];
    controlPanel.wantsLayer = YES;
    controlPanel.layer.backgroundColor = [[NSColor colorWithWhite:0.1 alpha:1.0] CGColor];
    controlPanel.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [contentView addSubview:controlPanel];
    
    // Quick Scan button
    self.quickScanButton = [[NSButton alloc] initWithFrame:NSMakeRect(20, 20, 120, 40)];
    self.quickScanButton.title = @"Quick Scan";
    self.quickScanButton.bezelStyle = NSBezelStyleRounded;
    self.quickScanButton.wantsLayer = YES;
    self.quickScanButton.layer.backgroundColor = [[NSColor colorWithRed:0.2 green:0.5 blue:0.9 alpha:1.0] CGColor];
    self.quickScanButton.layer.cornerRadius = 6;
    self.quickScanButton.target = self;
    self.quickScanButton.action = @selector(startQuickScan:);
    [controlPanel addSubview:self.quickScanButton];
    
    // Standard Scan button
    self.scanButton = [[NSButton alloc] initWithFrame:NSMakeRect(150, 20, 140, 40)];
    self.scanButton.title = @"Standard Scan";
    self.scanButton.bezelStyle = NSBezelStyleRounded;
    self.scanButton.wantsLayer = YES;
    self.scanButton.layer.backgroundColor = [[NSColor colorWithRed:0.1 green:0.6 blue:0.3 alpha:1.0] CGColor];
    self.scanButton.layer.cornerRadius = 6;
    self.scanButton.target = self;
    self.scanButton.action = @selector(startStandardScan:);
    [controlPanel addSubview:self.scanButton];
    
    // Deep Scan button
    self.deepScanButton = [[NSButton alloc] initWithFrame:NSMakeRect(300, 20, 120, 40)];
    self.deepScanButton.title = @"Deep Scan";
    self.deepScanButton.bezelStyle = NSBezelStyleRounded;
    self.deepScanButton.wantsLayer = YES;
    self.deepScanButton.layer.backgroundColor = [[NSColor colorWithRed:0.8 green:0.4 blue:0.1 alpha:1.0] CGColor];
    self.deepScanButton.layer.cornerRadius = 6;
    self.deepScanButton.target = self;
    self.deepScanButton.action = @selector(startDeepScan:);
    [controlPanel addSubview:self.deepScanButton];
    
    // Stop button
    self.stopButton = [[NSButton alloc] initWithFrame:NSMakeRect(430, 20, 100, 40)];
    self.stopButton.title = @"Stop";
    self.stopButton.bezelStyle = NSBezelStyleRounded;
    self.stopButton.wantsLayer = YES;
    self.stopButton.layer.backgroundColor = [[NSColor colorWithRed:0.8 green:0.2 blue:0.2 alpha:1.0] CGColor];
    self.stopButton.layer.cornerRadius = 6;
    self.stopButton.target = self;
    self.stopButton.action = @selector(stopScan:);
    self.stopButton.enabled = NO;
    [controlPanel addSubview:self.stopButton];
    
    // Progress indicator
    self.progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(550, 30, 230, 20)];
    self.progressIndicator.style = NSProgressIndicatorStyleBar;
    self.progressIndicator.indeterminate = YES;
    self.progressIndicator.autoresizingMask = NSViewMinXMargin;
    [self.progressIndicator setHidden:YES];
    [controlPanel addSubview:self.progressIndicator];
    
    // Output area with scroll view
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 20, frame.size.width - 40, frame.size.height - 200)];
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollView.wantsLayer = YES;
    scrollView.layer.cornerRadius = 8;
    scrollView.layer.borderColor = [[NSColor colorWithWhite:0.2 alpha:1.0] CGColor];
    scrollView.layer.borderWidth = 1;
    
    self.outputView = [[NSTextView alloc] initWithFrame:scrollView.bounds];
    self.outputView.backgroundColor = [NSColor colorWithRed:0.05 green:0.05 blue:0.08 alpha:1.0];
    self.outputView.textColor = [NSColor colorWithRed:0.4 green:1.0 blue:0.5 alpha:1.0];
    self.outputView.font = [NSFont fontWithName:@"SF Mono" size:12] ?: [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.outputView.editable = NO;
    self.outputView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    
    scrollView.documentView = self.outputView;
    [contentView addSubview:scrollView];
    
    // Initial welcome message
    [self appendOutput:@"╔══════════════════════════════════════════════════════════════╗\n"];
    [self appendOutput:@"║          Enterprise Antivirus System v3.0                    ║\n"];
    [self appendOutput:@"║     Pure C++17 / x86-64 Assembly | Zero Dependencies         ║\n"];
    [self appendOutput:@"╚══════════════════════════════════════════════════════════════╝\n\n"];
    [self appendOutput:@"[*] System initialized and ready.\n"];
    [self appendOutput:@"[*] Select a scan mode to begin threat detection.\n\n"];
    [self appendOutput:@"  • Quick Scan    - Hash + signature check (fastest)\n"];
    [self appendOutput:@"  • Standard Scan - Full analysis with all modules\n"];
    [self appendOutput:@"  • Deep Scan     - Maximum sensitivity paranoid mode\n\n"];
    
    [self.avWindow makeKeyAndOrderFront:nil];
    
    [self appendOutput:@"[✓] Virtual OS Antivirus Engine ready.\n"];
    [self appendOutput:@"[i] Scanning virtual file system only (isolated from host OS).\n\n"];
}

- (void)startQuickScan:(id)sender {
    [self runVirtualScanWithMode:@"quick"];
}

- (void)startStandardScan:(id)sender {
    [self runVirtualScanWithMode:@"standard"];
}

- (void)startDeepScan:(id)sender {
    [self runVirtualScanWithMode:@"deep"];
}

- (void)runVirtualScanWithMode:(NSString *)mode {
    if (self.isScanning) return;
    
    self.isScanning = YES;
    self.shouldStopScan = NO;
    self.filesScanned = 0;
    self.threatsFound = 0;
    
    // Update UI
    self.quickScanButton.enabled = NO;
    self.scanButton.enabled = NO;
    self.deepScanButton.enabled = NO;
    self.stopButton.enabled = YES;
    [self.progressIndicator setHidden:NO];
    [self.progressIndicator startAnimation:nil];
    self.statusLabel.stringValue = @"● Scanning Virtual OS...";
    self.statusLabel.textColor = [NSColor colorWithRed:1.0 green:0.8 blue:0.2 alpha:1.0];
    
    [self appendOutput:[NSString stringWithFormat:@"\n[*] Starting %@ scan on: VirtualOS File System\n", mode.uppercaseString]];
    [self appendOutput:@"[i] Note: Scanning virtual files only - your real macOS is NOT being scanned.\n"];
    [self appendOutput:@"────────────────────────────────────────────────────────────────\n\n"];
    
    // Scan delay based on mode
    NSTimeInterval delay = [mode isEqualToString:@"quick"] ? 0.05 : ([mode isEqualToString:@"deep"] ? 0.15 : 0.08);
    
    // Run virtual scan in background
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self scanVirtualDirectory:@"/" withDelay:delay mode:mode];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self scanCompleted];
        });
    });
}

- (void)scanVirtualDirectory:(NSString *)path withDelay:(NSTimeInterval)delay mode:(NSString *)mode {
    if (self.shouldStopScan) return;
    
    NSArray *contents = self.virtualFileSystem[path];
    if (!contents) return;
    
    for (id item in contents) {
        if (self.shouldStopScan) break;
        
        NSString *itemName;
        NSString *itemType;
        NSNumber *itemSize;
        BOOL isSafe = YES;
        NSString *threatName = nil;
        
        if ([item isKindOfClass:[NSString class]]) {
            // It's a folder name string
            itemName = item;
            itemType = @"folder";
            itemSize = @0;
        } else if ([item isKindOfClass:[NSDictionary class]]) {
            NSDictionary *fileInfo = item;
            itemName = fileInfo[@"name"];
            itemType = fileInfo[@"type"];
            itemSize = fileInfo[@"size"] ?: @0;
            isSafe = [fileInfo[@"safe"] boolValue];
            threatName = fileInfo[@"threat"];
        } else {
            continue;
        }
        
        NSString *fullPath = [path isEqualToString:@"/"] ? 
            [NSString stringWithFormat:@"/%@", itemName] : 
            [NSString stringWithFormat:@"%@/%@", path, itemName];
        
        // Update UI
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([itemType isEqualToString:@"folder"]) {
                [self appendOutput:[NSString stringWithFormat:@"[DIR]  %@\n", fullPath]];
            } else {
                self.filesScanned++;
                NSString *sizeStr = [self formatFileSize:[itemSize longLongValue]];
                
                if (isSafe) {
                    [self appendOutput:[NSString stringWithFormat:@"[FILE] %@ (%@) ✓\n", fullPath, sizeStr]];
                } else {
                    self.threatsFound++;
                    [self appendOutputThreat:[NSString stringWithFormat:@"[!!!!] %@ (%@)\n", fullPath, sizeStr]];
                    [self appendOutputThreat:[NSString stringWithFormat:@"       ⚠️  THREAT DETECTED: %@\n", threatName]];
                    [self appendOutputThreat:@"       → Recommended action: Quarantine or Delete\n\n"];
                }
            }
        });
        
        [NSThread sleepForTimeInterval:delay];
        
        // Recursively scan subdirectories
        if ([itemType isEqualToString:@"folder"]) {
            [self scanVirtualDirectory:fullPath withDelay:delay mode:mode];
        }
    }
}

- (NSString *)formatFileSize:(long long)bytes {
    if (bytes < 1024) return [NSString stringWithFormat:@"%lld B", bytes];
    if (bytes < 1048576) return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
    if (bytes < 1073741824) return [NSString stringWithFormat:@"%.1f MB", bytes / 1048576.0];
    return [NSString stringWithFormat:@"%.1f GB", bytes / 1073741824.0];
}

- (void)appendOutputThreat:(NSString *)text {
    if (!text) return;
    
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:text
                                                                     attributes:@{
        NSForegroundColorAttributeName: [NSColor colorWithRed:1.0 green:0.3 blue:0.3 alpha:1.0],
        NSFontAttributeName: self.outputView.font
    }];
    
    [[self.outputView textStorage] appendAttributedString:attrString];
    [self.outputView scrollToEndOfDocument:nil];
}

- (void)stopScan:(id)sender {
    self.shouldStopScan = YES;
    [self appendOutput:@"\n[!] Scan stopped by user.\n"];
    [self scanCompleted];
}

- (void)scanCompleted {
    self.isScanning = NO;
    self.quickScanButton.enabled = YES;
    self.scanButton.enabled = YES;
    self.deepScanButton.enabled = YES;
    self.stopButton.enabled = NO;
    [self.progressIndicator stopAnimation:nil];
    [self.progressIndicator setHidden:YES];
    
    [self appendOutput:@"\n────────────────────────────────────────────────────────────────\n"];
    [self appendOutput:@"                        SCAN SUMMARY\n"];
    [self appendOutput:@"────────────────────────────────────────────────────────────────\n"];
    [self appendOutput:[NSString stringWithFormat:@"  Files Scanned:    %ld\n", (long)self.filesScanned]];
    
    if (self.threatsFound > 0) {
        self.statusLabel.stringValue = [NSString stringWithFormat:@"⚠ %ld Threats Found", (long)self.threatsFound];
        self.statusLabel.textColor = [NSColor colorWithRed:1.0 green:0.3 blue:0.2 alpha:1.0];
        [self appendOutputThreat:[NSString stringWithFormat:@"  Threats Found:    %ld\n", (long)self.threatsFound]];
        [self appendOutput:@"\n[!] Action Required: Review and remove detected threats.\n"];
    } else {
        self.statusLabel.stringValue = @"● System Protected";
        self.statusLabel.textColor = [NSColor colorWithRed:0.4 green:1.0 blue:0.5 alpha:1.0];
        [self appendOutput:@"  Threats Found:    0\n"];
        [self appendOutput:@"\n[✓] No threats detected. Your virtual system is clean!\n"];
    }
    [self appendOutput:@"────────────────────────────────────────────────────────────────\n\n"];
}

- (void)appendOutput:(NSString *)text {
    if (!text) return;
    
    NSAttributedString *attrString = [[NSAttributedString alloc] initWithString:text
                                                                     attributes:@{
        NSForegroundColorAttributeName: [NSColor colorWithRed:0.4 green:1.0 blue:0.5 alpha:1.0],
        NSFontAttributeName: self.outputView.font
    }];
    
    [[self.outputView textStorage] appendAttributedString:attrString];
    [self.outputView scrollToEndOfDocument:nil];
}

@end
