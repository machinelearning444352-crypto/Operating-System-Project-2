#import "FinderWindow.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface FinderWindow ()
@property(nonatomic, strong) NSWindow *finderWindow;
@property(nonatomic, strong) NSTableView *tableView;
@property(nonatomic, strong) NSMutableArray *fileList;
@property(nonatomic, strong) NSString *currentPath;
@property(nonatomic, strong) NSTextField *pathField;
@property(nonatomic, strong)
    NSMutableDictionary *uploadedFiles; // Dynamic file storage
@end

@implementation FinderWindow

+ (instancetype)sharedInstance {
  static FinderWindow *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[FinderWindow alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.fileList = [NSMutableArray array];
    self.currentPath = @"/Users/Guest";
    self.uploadedFiles = [NSMutableDictionary dictionary];
    [self loadUploadedFiles];
  }
  return self;
}

- (NSString *)uploadedFilesPath {
  NSString *appSupport = [NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
  NSString *dir =
      [appSupport stringByAppendingPathComponent:@"VirtualOS/VirtualFiles"];
  [[NSFileManager defaultManager] createDirectoryAtPath:dir
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  return dir;
}

- (void)loadUploadedFiles {
  NSString *metaPath = [[self uploadedFilesPath]
      stringByAppendingPathComponent:@"metadata.plist"];
  NSDictionary *saved = [NSDictionary dictionaryWithContentsOfFile:metaPath];
  if (saved) {
    self.uploadedFiles = [saved mutableCopy];
  }
}

- (void)saveUploadedFiles {
  NSString *metaPath = [[self uploadedFilesPath]
      stringByAppendingPathComponent:@"metadata.plist"];
  [self.uploadedFiles writeToFile:metaPath atomically:YES];
}

- (void)showWindow {
  if (self.finderWindow) {
    [self.finderWindow makeKeyAndOrderFront:nil];
    return;
  }

  NSRect frame = NSMakeRect(0, 0, 960, 620);
  self.finderWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable |
                          NSWindowStyleMaskFullSizeContentView
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.finderWindow setTitle:@"Finder"];
  [self.finderWindow center];
  self.finderWindow.titlebarAppearsTransparent = YES;
  self.finderWindow.titleVisibility = NSWindowTitleHidden;
  self.finderWindow.minSize = NSMakeSize(700, 400);

  // ─── CONTENT VIEW ───
  NSView *contentView = [[NSView alloc] initWithFrame:frame];
  contentView.wantsLayer = YES;
  contentView.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];
  [self.finderWindow setContentView:contentView];

  // ─── TOOLBAR (Liquid Glass) ───
  CGFloat toolbarH = 52;
  NSVisualEffectView *toolbar = [[NSVisualEffectView alloc]
      initWithFrame:NSMakeRect(0, frame.size.height - toolbarH,
                               frame.size.width, toolbarH)];
  toolbar.material = NSVisualEffectMaterialTitlebar;
  toolbar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  toolbar.state = NSVisualEffectStateFollowsWindowActiveState;
  toolbar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [contentView addSubview:toolbar];

  // Toolbar separator
  NSView *toolbarSep =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, 1)];
  toolbarSep.wantsLayer = YES;
  toolbarSep.layer.backgroundColor = [[NSColor separatorColor] CGColor];
  toolbarSep.autoresizingMask = NSViewWidthSizable;
  [toolbar addSubview:toolbarSep];

  // Navigation: Back / Forward
  NSButton *backBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(78, 12, 30, 28)];
  backBtn.image = [NSImage imageWithSystemSymbolName:@"chevron.left"
                            accessibilityDescription:@"Back"];
  if (!backBtn.image)
    backBtn.title = @"‹";
  backBtn.bezelStyle = NSBezelStyleTexturedRounded;
  backBtn.bordered = NO;
  backBtn.target = self;
  backBtn.action = @selector(goBack:);
  [toolbar addSubview:backBtn];

  NSButton *forwardBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(108, 12, 30, 28)];
  forwardBtn.image = [NSImage imageWithSystemSymbolName:@"chevron.right"
                               accessibilityDescription:@"Forward"];
  if (!forwardBtn.image)
    forwardBtn.title = @"›";
  forwardBtn.bezelStyle = NSBezelStyleTexturedRounded;
  forwardBtn.bordered = NO;
  [toolbar addSubview:forwardBtn];

  // Upload / Download buttons
  NSButton *uploadBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(148, 12, 30, 28)];
  uploadBtn.image = [NSImage imageWithSystemSymbolName:@"square.and.arrow.up"
                              accessibilityDescription:@"Upload"];
  if (!uploadBtn.image)
    uploadBtn.title = @"↑";
  uploadBtn.bezelStyle = NSBezelStyleTexturedRounded;
  uploadBtn.bordered = NO;
  uploadBtn.toolTip = @"Upload file to Virtual OS";
  uploadBtn.target = self;
  uploadBtn.action = @selector(uploadFile:);
  [toolbar addSubview:uploadBtn];

  NSButton *downloadBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(178, 12, 30, 28)];
  downloadBtn.image =
      [NSImage imageWithSystemSymbolName:@"square.and.arrow.down"
                accessibilityDescription:@"Download"];
  if (!downloadBtn.image)
    downloadBtn.title = @"↓";
  downloadBtn.bezelStyle = NSBezelStyleTexturedRounded;
  downloadBtn.bordered = NO;
  downloadBtn.toolTip = @"Download file from Virtual OS";
  downloadBtn.target = self;
  downloadBtn.action = @selector(downloadFile:);
  [toolbar addSubview:downloadBtn];

  // Path bar (breadcrumb)
  self.pathField = [[NSTextField alloc]
      initWithFrame:NSMakeRect(220, 14, frame.size.width - 350, 24)];
  self.pathField.stringValue = self.currentPath;
  self.pathField.font = [NSFont systemFontOfSize:12];
  self.pathField.bezeled = YES;
  self.pathField.bezelStyle = NSTextFieldRoundedBezel;
  self.pathField.target = self;
  self.pathField.action = @selector(pathFieldChanged:);
  self.pathField.autoresizingMask = NSViewWidthSizable;
  [toolbar addSubview:self.pathField];

  // Search
  NSSearchField *searchField = [[NSSearchField alloc]
      initWithFrame:NSMakeRect(frame.size.width - 130, 14, 120, 24)];
  searchField.placeholderString = @"Search";
  searchField.font = [NSFont systemFontOfSize:12];
  searchField.autoresizingMask = NSViewMinXMargin;
  [toolbar addSubview:searchField];

  // ─── SIDEBAR (NSVisualEffectView with source list material) ───
  CGFloat sideW = 200;
  NSVisualEffectView *sidebar = [[NSVisualEffectView alloc]
      initWithFrame:NSMakeRect(0, 0, sideW, frame.size.height - toolbarH)];
  sidebar.material = NSVisualEffectMaterialSidebar;
  sidebar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  sidebar.state = NSVisualEffectStateFollowsWindowActiveState;
  sidebar.autoresizingMask = NSViewHeightSizable;
  [contentView addSubview:sidebar];

  // Sidebar: Favorites
  NSArray *sidebarItems = @[
    @{
      @"icon" : @"🖥",
      @"name" : @"Desktop",
      @"path" : [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop"]
    },
    @{
      @"icon" : @"📄",
      @"name" : @"Documents",
      @"path" :
          [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"]
    },
    @{
      @"icon" : @"⬇️",
      @"name" : @"Downloads",
      @"path" :
          [NSHomeDirectory() stringByAppendingPathComponent:@"Downloads"]
    },
    @{@"icon" : @"🏠", @"name" : @"Home", @"path" : NSHomeDirectory()},
    @{@"icon" : @"📦", @"name" : @"Applications", @"path" : @"/Applications"},
    @{@"icon" : @"💻", @"name" : @"Macintosh HD", @"path" : @"/"}
  ];

  // "Favorites" section header
  NSTextField *favHeader = [[NSTextField alloc]
      initWithFrame:NSMakeRect(14, frame.size.height - toolbarH - 28,
                               sideW - 28, 14)];
  favHeader.stringValue = @"Favorites";
  favHeader.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
  favHeader.textColor = [NSColor secondaryLabelColor];
  favHeader.bezeled = NO;
  favHeader.editable = NO;
  favHeader.drawsBackground = NO;
  [sidebar addSubview:favHeader];

  CGFloat sideY = frame.size.height - toolbarH - 46;
  for (NSUInteger idx = 0; idx < sidebarItems.count; idx++) {
    NSDictionary *item = sidebarItems[idx];
    NSButton *sideBtn =
        [[NSButton alloc] initWithFrame:NSMakeRect(6, sideY, sideW - 12, 24)];
    sideBtn.title =
        [NSString stringWithFormat:@" %@  %@", item[@"icon"], item[@"name"]];
    sideBtn.alignment = NSTextAlignmentLeft;
    sideBtn.bezelStyle = NSBezelStyleInline;
    sideBtn.bordered = NO;
    sideBtn.font = [NSFont systemFontOfSize:13];
    sideBtn.contentTintColor = [NSColor labelColor];
    sideBtn.target = self;
    sideBtn.action = @selector(sidebarItemClicked:);
    sideBtn.tag = idx;
    [sidebar addSubview:sideBtn];
    sideY -= 24;
  }

  // "iCloud" section
  sideY -= 12;
  NSTextField *icloudHeader =
      [[NSTextField alloc] initWithFrame:NSMakeRect(14, sideY, sideW - 28, 14)];
  icloudHeader.stringValue = @"iCloud";
  icloudHeader.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
  icloudHeader.textColor = [NSColor secondaryLabelColor];
  icloudHeader.bezeled = NO;
  icloudHeader.editable = NO;
  icloudHeader.drawsBackground = NO;
  [sidebar addSubview:icloudHeader];

  sideY -= 24;
  NSButton *icloudBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(6, sideY, sideW - 12, 24)];
  icloudBtn.title = @" ☁️  iCloud Drive";
  icloudBtn.alignment = NSTextAlignmentLeft;
  icloudBtn.bezelStyle = NSBezelStyleInline;
  icloudBtn.bordered = NO;
  icloudBtn.font = [NSFont systemFontOfSize:13];
  icloudBtn.contentTintColor = [NSColor labelColor];
  [sidebar addSubview:icloudBtn];

  // "Tags" section
  sideY -= 20;
  NSTextField *tagsHeader =
      [[NSTextField alloc] initWithFrame:NSMakeRect(14, sideY, sideW - 28, 14)];
  tagsHeader.stringValue = @"Tags";
  tagsHeader.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
  tagsHeader.textColor = [NSColor secondaryLabelColor];
  tagsHeader.bezeled = NO;
  tagsHeader.editable = NO;
  tagsHeader.drawsBackground = NO;
  [sidebar addSubview:tagsHeader];

  NSArray *tags = @[
    @{@"color" : [NSColor systemRedColor], @"name" : @"Red"},
    @{@"color" : [NSColor systemOrangeColor], @"name" : @"Orange"},
    @{@"color" : [NSColor systemYellowColor], @"name" : @"Yellow"},
    @{@"color" : [NSColor systemGreenColor], @"name" : @"Green"},
    @{@"color" : [NSColor systemBlueColor], @"name" : @"Blue"},
    @{@"color" : [NSColor systemPurpleColor], @"name" : @"Purple"}
  ];
  sideY -= 20;
  for (NSDictionary *tag in tags) {
    NSTextField *tagLabel = [[NSTextField alloc]
        initWithFrame:NSMakeRect(14, sideY, sideW - 28, 16)];
    tagLabel.stringValue = [NSString stringWithFormat:@"●  %@", tag[@"name"]];
    tagLabel.font = [NSFont systemFontOfSize:12];
    tagLabel.textColor = tag[@"color"];
    tagLabel.bezeled = NO;
    tagLabel.editable = NO;
    tagLabel.drawsBackground = NO;
    [sidebar addSubview:tagLabel];
    sideY -= 18;
  }

  // ─── FILE TABLE ───
  CGFloat statusBarH = 22;
  NSScrollView *scrollView = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(sideW, statusBarH, frame.size.width - sideW,
                               frame.size.height - toolbarH - statusBarH)];
  scrollView.hasVerticalScroller = YES;
  scrollView.autohidesScrollers = YES;
  scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  self.tableView = [[NSTableView alloc] initWithFrame:scrollView.bounds];
  self.tableView.dataSource = self;
  self.tableView.delegate = self;
  self.tableView.rowHeight = 22;
  self.tableView.doubleAction = @selector(tableDoubleClick:);
  self.tableView.target = self;
  self.tableView.usesAlternatingRowBackgroundColors = YES;
  self.tableView.gridStyleMask = NSTableViewGridNone;
  self.tableView.intercellSpacing = NSMakeSize(8, 2);
  self.tableView.selectionHighlightStyle =
      NSTableViewSelectionHighlightStyleRegular;
  self.tableView.style = NSTableViewStyleFullWidth;

  // Right-click context menu
  NSMenu *tableMenu = [[NSMenu alloc] init];
  tableMenu.delegate = (id<NSMenuDelegate>)self;
  self.tableView.menu = tableMenu;

  // Columns
  NSTableColumn *iconCol = [[NSTableColumn alloc] initWithIdentifier:@"icon"];
  iconCol.title = @"";
  iconCol.width = 24;
  iconCol.minWidth = 24;
  iconCol.maxWidth = 24;
  [self.tableView addTableColumn:iconCol];

  NSTableColumn *nameCol = [[NSTableColumn alloc] initWithIdentifier:@"name"];
  nameCol.title = @"Name";
  nameCol.width = 320;
  nameCol.minWidth = 120;
  [self.tableView addTableColumn:nameCol];

  NSTableColumn *sizeCol = [[NSTableColumn alloc] initWithIdentifier:@"size"];
  sizeCol.title = @"Size";
  sizeCol.width = 80;
  sizeCol.minWidth = 60;
  [self.tableView addTableColumn:sizeCol];

  NSTableColumn *modifiedCol =
      [[NSTableColumn alloc] initWithIdentifier:@"modified"];
  modifiedCol.title = @"Date Modified";
  modifiedCol.width = 150;
  modifiedCol.minWidth = 100;
  [self.tableView addTableColumn:modifiedCol];

  scrollView.documentView = self.tableView;
  [contentView addSubview:scrollView];

  // ─── STATUS BAR ───
  NSView *statusBar = [[NSView alloc]
      initWithFrame:NSMakeRect(sideW, 0, frame.size.width - sideW, statusBarH)];
  statusBar.wantsLayer = YES;
  statusBar.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];
  statusBar.autoresizingMask = NSViewWidthSizable;
  [contentView addSubview:statusBar];

  // Status bar separator
  NSView *statusSep = [[NSView alloc]
      initWithFrame:NSMakeRect(0, statusBarH - 1, frame.size.width - sideW, 1)];
  statusSep.wantsLayer = YES;
  statusSep.layer.backgroundColor = [[NSColor separatorColor] CGColor];
  statusSep.autoresizingMask = NSViewWidthSizable;
  [statusBar addSubview:statusSep];

  NSTextField *statusLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(8, 2, 300, 16)];
  statusLabel.stringValue = @"0 items";
  statusLabel.font = [NSFont systemFontOfSize:11];
  statusLabel.textColor = [NSColor secondaryLabelColor];
  statusLabel.bezeled = NO;
  statusLabel.editable = NO;
  statusLabel.drawsBackground = NO;
  [statusBar addSubview:statusLabel];

  [self loadFilesAtPath:self.currentPath];
  [self.finderWindow makeKeyAndOrderFront:nil];
}

- (NSDictionary *)virtualFileSystem {
  // Virtual file system - completely isolated from real system (empty folders)
  return @{
    @"/" : @[
      @{@"name" : @"Applications", @"isDirectory" : @YES},
      @{@"name" : @"System", @"isDirectory" : @YES},
      @{@"name" : @"Users", @"isDirectory" : @YES},
      @{@"name" : @"Library", @"isDirectory" : @YES}
    ],
    @"/Applications" : @[
      @{@"name" : @"Safari.app", @"isDirectory" : @YES, @"size" : @(52428800)},
      @{
        @"name" : @"Messages.app",
        @"isDirectory" : @YES,
        @"size" : @(31457280)
      },
      @{@"name" : @"Notes.app", @"isDirectory" : @YES, @"size" : @(15728640)},
      @{
        @"name" : @"Calendar.app",
        @"isDirectory" : @YES,
        @"size" : @(20971520)
      },
      @{@"name" : @"Terminal.app", @"isDirectory" : @YES, @"size" : @(8388608)},
      @{
        @"name" : @"Settings.app",
        @"isDirectory" : @YES,
        @"size" : @(10485760)
      },
      @{@"name" : @"Mail.app", @"isDirectory" : @YES, @"size" : @(41943040)},
      @{@"name" : @"Photos.app", @"isDirectory" : @YES, @"size" : @(62914560)},
      @{@"name" : @"Music.app", @"isDirectory" : @YES, @"size" : @(73400320)}
    ],
    @"/System" : @[
      @{@"name" : @"Library", @"isDirectory" : @YES},
      @{@"name" : @"Kernel", @"isDirectory" : @NO, @"size" : @(15728640)},
      @{@"name" : @"Drivers", @"isDirectory" : @YES}
    ],
    @"/System/Library" : @[
      @{@"name" : @"CoreServices", @"isDirectory" : @YES},
      @{@"name" : @"Frameworks", @"isDirectory" : @YES},
      @{@"name" : @"Extensions", @"isDirectory" : @YES}
    ],
    @"/Users" : @[
      @{@"name" : @"Guest", @"isDirectory" : @YES},
      @{@"name" : @"Shared", @"isDirectory" : @YES}
    ],
    @"/Users/Guest" : @[
      @{@"name" : @"Desktop", @"isDirectory" : @YES},
      @{@"name" : @"Documents", @"isDirectory" : @YES},
      @{@"name" : @"Downloads", @"isDirectory" : @YES},
      @{@"name" : @"Pictures", @"isDirectory" : @YES},
      @{@"name" : @"Music", @"isDirectory" : @YES}
    ],
    @"/Users/Guest/Desktop" : @[],
    @"/Users/Guest/Documents" : @[],
    @"/Users/Guest/Downloads" : @[],
    @"/Users/Guest/Pictures" : @[],
    @"/Users/Guest/Music" : @[],
    @"/Library" : @[
      @{@"name" : @"Preferences", @"isDirectory" : @YES},
      @{@"name" : @"Application Support", @"isDirectory" : @YES}
    ]
  };
}

- (void)loadFilesAtPath:(NSString *)path {
  if (!path || path.length == 0) {
    path = @"/";
  }

  // Normalize path
  if ([path isEqualToString:@"~"] || [path hasPrefix:@"~/"]) {
    path = [@"/Users/Guest"
        stringByAppendingPathComponent:[path substringFromIndex:1]];
  }

  // Handle home directory references
  if ([path containsString:NSHomeDirectory()]) {
    path = [path stringByReplacingOccurrencesOfString:NSHomeDirectory()
                                           withString:@"/Users/Guest"];
  }

  // Ensure path doesn't have trailing slash (except for root)
  if (path.length > 1 && [path hasSuffix:@"/"]) {
    path = [path substringToIndex:path.length - 1];
  }

  [self.fileList removeAllObjects];

  NSDictionary *vfs = [self virtualFileSystem];
  NSArray *contents = vfs[path];

  if (!contents) {
    // Path not in VFS - default to root
    contents = vfs[@"/"];
    if (!contents) {
      return;
    }
    path = @"/";
  }

  for (NSDictionary *item in contents) {
    NSString *fullPath = [path stringByAppendingPathComponent:item[@"name"]];

    [self.fileList addObject:@{
      @"name" : item[@"name"],
      @"path" : fullPath,
      @"isDirectory" : item[@"isDirectory"],
      @"size" : item[@"size"] ?: @0,
      @"modified" : [NSDate
          dateWithTimeIntervalSinceNow:-86400 * (arc4random_uniform(30) + 1)]
    }];
  }

  // Add uploaded files for this path
  NSArray *uploadedInPath = self.uploadedFiles[path];
  for (NSDictionary *uploaded in uploadedInPath) {
    [self.fileList addObject:@{
      @"name" : uploaded[@"name"],
      @"path" : uploaded[@"virtualPath"],
      @"isDirectory" : uploaded[@"isDirectory"] ?: @NO,
      @"size" : uploaded[@"size"] ?: @0,
      @"storagePath" : uploaded[@"storagePath"] ?: @"",
      @"modified" : uploaded[@"uploadDate"] ?: [NSDate date],
      @"isUploaded" : @YES
    }];
  }

  // Sort: folders first, then alphabetically
  [self.fileList sortUsingComparator:^NSComparisonResult(NSDictionary *a,
                                                         NSDictionary *b) {
    BOOL aDir = [a[@"isDirectory"] boolValue];
    BOOL bDir = [b[@"isDirectory"] boolValue];
    if (aDir != bDir)
      return bDir ? NSOrderedDescending : NSOrderedAscending;
    return [a[@"name"] caseInsensitiveCompare:b[@"name"]];
  }];

  self.currentPath = path;
  if (self.pathField) {
    self.pathField.stringValue = path;
  }
  if (self.finderWindow) {
    [self.finderWindow
        setTitle:[NSString stringWithFormat:@"Finder - %@",
                                            [path lastPathComponent]]];
  }
  if (self.tableView) {
    [self.tableView reloadData];
  }
}

- (void)navigateToPath:(NSString *)path {
  [self showWindow];
  [self loadFilesAtPath:path];
}

#pragma mark - Actions

- (void)goBack:(id)sender {
  NSString *parent = [self.currentPath stringByDeletingLastPathComponent];
  if (parent.length > 0) {
    [self loadFilesAtPath:parent];
  }
}

- (void)goHome:(id)sender {
  [self loadFilesAtPath:@"/Users/Guest"];
}

- (void)pathFieldChanged:(id)sender {
  NSString *path = self.pathField.stringValue;
  NSDictionary *vfs = [self virtualFileSystem];
  if (vfs[path]) {
    [self loadFilesAtPath:path];
  }
}

- (void)sidebarItemClicked:(NSButton *)sender {
  NSArray *paths = @[
    @"/Users/Guest/Desktop", @"/Users/Guest/Documents",
    @"/Users/Guest/Downloads", @"/Users/Guest", @"/Applications", @"/"
  ];

  NSInteger idx = sender.tag;
  if (idx >= 0 && idx < (NSInteger)paths.count) {
    [self loadFilesAtPath:paths[idx]];
  }
}

#pragma mark - Upload/Download

- (void)uploadFile:(id)sender {
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  panel.canChooseFiles = YES;
  panel.canChooseDirectories = NO;
  panel.allowsMultipleSelection = YES;
  panel.message = @"Select files to upload to Virtual OS";
  panel.prompt = @"Upload";

  [panel
      beginSheetModalForWindow:self.finderWindow
             completionHandler:^(NSModalResponse result) {
               if (result == NSModalResponseOK) {
                 for (NSURL *url in panel.URLs) {
                   [self importFileFromURL:url toVirtualPath:self.currentPath];
                 }
                 [self loadFilesAtPath:self.currentPath];

                 NSAlert *alert = [[NSAlert alloc] init];
                 alert.messageText = @"Upload Complete";
                 alert.informativeText =
                     [NSString stringWithFormat:@"%lu file(s) uploaded to %@",
                                                (unsigned long)panel.URLs.count,
                                                self.currentPath];
                 alert.alertStyle = NSAlertStyleInformational;
                 [alert runModal];
               }
             }];
}

- (void)importFileFromURL:(NSURL *)sourceURL
            toVirtualPath:(NSString *)virtualPath {
  NSString *fileName = [sourceURL lastPathComponent];
  NSString *virtualFilePath =
      [virtualPath stringByAppendingPathComponent:fileName];

  // Copy file to VirtualOS storage
  NSString *storagePath = [[self uploadedFilesPath]
      stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
  NSError *error = nil;
  [[NSFileManager defaultManager]
      copyItemAtURL:sourceURL
              toURL:[NSURL fileURLWithPath:storagePath]
              error:&error];

  if (!error) {
    // Get file attributes
    NSDictionary *attrs =
        [[NSFileManager defaultManager] attributesOfItemAtPath:sourceURL.path
                                                         error:nil];
    NSNumber *fileSize = attrs[NSFileSize] ?: @0;

    // Store metadata
    NSMutableArray *filesInPath =
        self.uploadedFiles[virtualPath] ?: [NSMutableArray array];
    [filesInPath addObject:@{
      @"name" : fileName,
      @"virtualPath" : virtualFilePath,
      @"storagePath" : storagePath,
      @"size" : fileSize,
      @"isDirectory" : @NO,
      @"uploadDate" : [NSDate date]
    }];
    self.uploadedFiles[virtualPath] = filesInPath;
    [self saveUploadedFiles];
  }
}

- (void)downloadFile:(id)sender {
  NSInteger row = self.tableView.selectedRow;
  if (row < 0 || row >= (NSInteger)self.fileList.count) {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"No File Selected";
    alert.informativeText = @"Please select a file to download.";
    alert.alertStyle = NSAlertStyleWarning;
    [alert runModal];
    return;
  }

  NSDictionary *item = self.fileList[row];
  if ([item[@"isDirectory"] boolValue]) {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Cannot Download Folder";
    alert.informativeText = @"Please select a file, not a folder.";
    alert.alertStyle = NSAlertStyleWarning;
    [alert runModal];
    return;
  }

  // Find storage path for this file
  NSString *storagePath = item[@"storagePath"];
  if (!storagePath ||
      ![[NSFileManager defaultManager] fileExistsAtPath:storagePath]) {
    // Virtual file - create a placeholder
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.nameFieldStringValue = item[@"name"];
    panel.message = @"Save virtual file to your Mac";

    [panel
        beginSheetModalForWindow:self.finderWindow
               completionHandler:^(NSModalResponse result) {
                 if (result == NSModalResponseOK) {
                   // Create placeholder content for virtual files
                   NSString *content = [NSString
                       stringWithFormat:
                           @"Virtual OS File\n\nName: %@\nPath: %@\nSize: %@ "
                           @"bytes\n\nThis is a virtual file from VirtualOS.",
                           item[@"name"], item[@"path"], item[@"size"]];
                   [content writeToURL:panel.URL
                            atomically:YES
                              encoding:NSUTF8StringEncoding
                                 error:nil];

                   NSAlert *alert = [[NSAlert alloc] init];
                   alert.messageText = @"Download Complete";
                   alert.informativeText = [NSString
                       stringWithFormat:@"File saved to %@", panel.URL.path];
                   [alert runModal];
                 }
               }];
    return;
  }

  // Real uploaded file - allow download
  NSSavePanel *panel = [NSSavePanel savePanel];
  panel.nameFieldStringValue = item[@"name"];
  panel.message = @"Save file to your Mac";

  [panel beginSheetModalForWindow:self.finderWindow
                completionHandler:^(NSModalResponse result) {
                  if (result == NSModalResponseOK) {
                    NSError *error = nil;
                    [[NSFileManager defaultManager]
                        copyItemAtPath:storagePath
                                toPath:panel.URL.path
                                 error:&error];

                    NSAlert *alert = [[NSAlert alloc] init];
                    if (error) {
                      alert.messageText = @"Download Failed";
                      alert.informativeText = error.localizedDescription;
                      alert.alertStyle = NSAlertStyleWarning;
                    } else {
                      alert.messageText = @"Download Complete";
                      alert.informativeText = [NSString
                          stringWithFormat:@"File saved to %@", panel.URL.path];
                      alert.alertStyle = NSAlertStyleInformational;
                    }
                    [alert runModal];
                  }
                }];
}

- (void)tableDoubleClick:(id)sender {
  @try {
    NSInteger row = self.tableView.clickedRow;
    if (row >= 0 && row < (NSInteger)self.fileList.count) {
      NSDictionary *item = self.fileList[row];
      if (!item)
        return;
      NSString *path = item[@"path"];
      if (!path)
        return;
      if ([item[@"isDirectory"] boolValue]) {
        [self loadFilesAtPath:path];
      } else {
        [self openFile:path];
      }
    }
  } @catch (NSException *e) {
    NSLog(@"FinderWindow tableDoubleClick error: %@", e);
  }
}

- (void)openFile:(NSString *)path {
  NSString *ext = [[path pathExtension] lowercaseString];
  NSString *fileName = [path lastPathComponent];

  // macOS Applications
  if ([ext isEqualToString:@"app"]) {
    NSString *appName = [fileName stringByDeletingPathExtension];
    [self launchVirtualApp:appName];
    return;
  }

  // Windows Executables
  if ([ext isEqualToString:@"exe"] || [ext isEqualToString:@"msi"]) {
    [self runWindowsExecutable:path];
    return;
  }

  // Linux/Ubuntu packages and executables
  if ([ext isEqualToString:@"deb"] || [ext isEqualToString:@"rpm"] ||
      [ext isEqualToString:@"appimage"] || [ext isEqualToString:@"snap"]) {
    [self runLinuxPackage:path];
    return;
  }

  // macOS disk images
  if ([ext isEqualToString:@"dmg"]) {
    [self mountDiskImage:path];
    return;
  }

  // macOS packages
  if ([ext isEqualToString:@"pkg"]) {
    [self runMacOSInstaller:path];
    return;
  }

  // Shell scripts
  if ([ext isEqualToString:@"sh"] || [ext isEqualToString:@"bash"] ||
      [ext isEqualToString:@"zsh"]) {
    [self runShellScript:path];
    return;
  }

  // Python scripts
  if ([ext isEqualToString:@"py"]) {
    [self runPythonScript:path];
    return;
  }

  // Java
  if ([ext isEqualToString:@"jar"]) {
    [self runJavaApplication:path];
    return;
  }

  // Archives
  if ([ext isEqualToString:@"zip"] || [ext isEqualToString:@"tar"] ||
      [ext isEqualToString:@"gz"] || [ext isEqualToString:@"7z"] ||
      [ext isEqualToString:@"rar"]) {
    [self extractArchive:path];
    return;
  }

  // Documents
  if ([ext isEqualToString:@"txt"] || [ext isEqualToString:@"md"] ||
      [ext isEqualToString:@"log"]) {
    [self openTextFile:path];
    return;
  }

  if ([ext isEqualToString:@"pdf"]) {
    [self openPDFFile:path];
    return;
  }

  // Images
  if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"] ||
      [ext isEqualToString:@"png"] || [ext isEqualToString:@"gif"] ||
      [ext isEqualToString:@"bmp"] || [ext isEqualToString:@"webp"]) {
    [self openImageFile:path];
    return;
  }

  // Audio
  if ([ext isEqualToString:@"mp3"] || [ext isEqualToString:@"wav"] ||
      [ext isEqualToString:@"m4a"] || [ext isEqualToString:@"flac"]) {
    [self openAudioFile:path];
    return;
  }

  // Video
  if ([ext isEqualToString:@"mp4"] || [ext isEqualToString:@"mov"] ||
      [ext isEqualToString:@"avi"] || [ext isEqualToString:@"mkv"]) {
    [self openVideoFile:path];
    return;
  }

  // Binary/ELF executables (Linux)
  if ([self isELFBinary:path]) {
    [self runLinuxBinary:path];
    return;
  }

  // Generic file - try to open with default app
  [self openGenericFile:path];
}

- (void)launchVirtualApp:(NSString *)appName {
  // Map virtual apps to real window classes
  if ([appName isEqualToString:@"Safari"]) {
    [[NSClassFromString(@"SafariWindow") sharedInstance] showWindow];
  } else if ([appName isEqualToString:@"Messages"]) {
    [[NSClassFromString(@"MessagesWindow") sharedInstance] showWindow];
  } else if ([appName isEqualToString:@"Notes"]) {
    [[NSClassFromString(@"NotesWindow") sharedInstance] showWindow];
  } else if ([appName isEqualToString:@"Calendar"]) {
    [[NSClassFromString(@"CalendarWindow") sharedInstance] showWindow];
  } else if ([appName isEqualToString:@"Terminal"]) {
    [[NSClassFromString(@"TerminalWindow") sharedInstance] showWindow];
  } else if ([appName isEqualToString:@"Settings"]) {
    [[NSClassFromString(@"SettingsWindow") sharedInstance] showWindow];
  } else if ([appName isEqualToString:@"Mail"]) {
    [[NSClassFromString(@"MailWindow") sharedInstance] showWindow];
  } else if ([appName isEqualToString:@"Photos"]) {
    [[NSClassFromString(@"PhotosWindow") sharedInstance] showWindow];
  } else if ([appName isEqualToString:@"Music"]) {
    [[NSClassFromString(@"MusicWindow") sharedInstance] showWindow];
  } else {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = appName;
    alert.informativeText = @"This virtual application is not yet implemented.";
    [alert runModal];
  }
}

- (void)showVirtualTextFile:(NSString *)fileName {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = fileName;

  NSString *content = @"This is a sample text file in the VirtualOS "
                      @"sandbox.\n\nNo real files are accessed.";
  if ([fileName containsString:@"Welcome"]) {
    content = @"Welcome to VirtualOS!\n\nThis is a sandboxed operating system "
              @"demonstration.\nAll files and data are simulated.";
  } else if ([fileName containsString:@"Project"]) {
    content = @"Project Notes\n\nThis virtual document contains simulated "
              @"project notes.";
  }

  alert.informativeText = content;
  [alert runModal];
}

- (void)showVirtualPDFFile:(NSString *)fileName {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = [NSString stringWithFormat:@"📄 %@", fileName];
  alert.informativeText = @"[Virtual PDF Document]\n\nThis is a simulated PDF "
                          @"file.\nNo real document viewer is opened.";
  [alert runModal];
}

- (void)showVirtualImageFile:(NSString *)fileName {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = [NSString stringWithFormat:@"🖼️ %@", fileName];
  alert.informativeText = @"[Virtual Image File]\n\nThis is a simulated image "
                          @"file.\nNo real image is displayed.";
  [alert runModal];
}

- (void)showVirtualAudioFile:(NSString *)fileName {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = [NSString stringWithFormat:@"🎵 %@", fileName];
  alert.informativeText = @"[Virtual Audio File]\n\nThis is a simulated audio "
                          @"file.\nNo real audio is played.";
  [alert runModal];
}

- (void)showVirtualArchiveFile:(NSString *)fileName {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = [NSString stringWithFormat:@"📦 %@", fileName];
  alert.informativeText = @"[Virtual Archive File]\n\nThis is a simulated "
                          @"archive file.\nNo real extraction is performed.";
  [alert runModal];
}

#pragma mark - Cross-Platform Execution

- (void)runWindowsExecutable:(NSString *)path {
  NSString *fileName = [path lastPathComponent];

  // Check if Wine is installed
  NSString *winePath = @"/usr/local/bin/wine";
  NSString *wine64Path = @"/usr/local/bin/wine64";
  NSString *crossoverPath = @"/Applications/CrossOver.app";

  BOOL hasWine = [[NSFileManager defaultManager] fileExistsAtPath:winePath] ||
                 [[NSFileManager defaultManager] fileExistsAtPath:wine64Path];
  BOOL hasCrossOver =
      [[NSFileManager defaultManager] fileExistsAtPath:crossoverPath];

  if (hasWine || hasCrossOver) {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText =
        [NSString stringWithFormat:@"Run Windows Application: %@", fileName];
    alert.informativeText =
        @"This will run the Windows executable using Wine/CrossOver.";
    [alert addButtonWithTitle:@"Run"];
    [alert addButtonWithTitle:@"Cancel"];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
      [self executeWindowsApp:path
                     withWine:hasWine ? (wine64Path ?: winePath) : nil];
    }
  } else {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText =
        [NSString stringWithFormat:@"🪟 Windows Application: %@", fileName];
    alert.informativeText =
        @"To run Windows .exe files, you need Wine or CrossOver "
        @"installed.\n\nInstall via Homebrew:\n  brew install --cask "
        @"wine-stable\n\nOr download CrossOver from codeweavers.com";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert addButtonWithTitle:@"Install Wine"];

    if ([alert runModal] == NSAlertSecondButtonReturn) {
      [[NSClassFromString(@"TerminalWindow") sharedInstance] showWindow];
    }
    [alert runModal];
  }
}

- (void)executeWindowsApp:(NSString *)path withWine:(NSString *)winePath {
  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        task.executableURL =
            [NSURL fileURLWithPath:winePath ?: @"/usr/local/bin/wine"];
        task.arguments = @[ path ];
        task.currentDirectoryURL =
            [[NSURL fileURLWithPath:path] URLByDeletingLastPathComponent];

        @try {
          [task launchAndReturnError:nil];
        } @catch (NSException *e) {
          dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Failed to launch";
            alert.informativeText = e.reason;
            [alert runModal];
          });
        }
      });
}

- (void)runLinuxPackage:(NSString *)path {
  NSString *fileName = [path lastPathComponent];
  NSString *ext = [[path pathExtension] lowercaseString];

  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText =
      [NSString stringWithFormat:@"🐧 Linux Package: %@", fileName];

  if ([ext isEqualToString:@"deb"]) {
    alert.informativeText =
        @"This is a Debian/Ubuntu package (.deb).\n\nTo install on Linux:\n  "
        @"sudo dpkg -i package.deb\n\nOn macOS, you can extract contents "
        @"with:\n  ar -x package.deb";
  } else if ([ext isEqualToString:@"rpm"]) {
    alert.informativeText =
        @"This is a Red Hat/Fedora package (.rpm).\n\nTo install on Linux:\n  "
        @"sudo rpm -i package.rpm\n\nOr use alien to convert:\n  alien "
        @"--to-deb package.rpm";
  } else if ([ext isEqualToString:@"appimage"]) {
    alert.informativeText =
        @"This is an AppImage (portable Linux app).\n\nTo run on Linux:\n  "
        @"chmod +x app.AppImage\n  ./app.AppImage\n\nAppImages can run in "
        @"Docker/VM on macOS.";
  } else if ([ext isEqualToString:@"snap"]) {
    alert.informativeText = @"This is a Snap package.\n\nTo install on "
                            @"Linux:\n  sudo snap install package.snap";
  }

  [alert addButtonWithTitle:@"OK"];
  [alert addButtonWithTitle:@"Extract/View Contents"];

  if ([alert runModal] == NSAlertSecondButtonReturn) {
    [self extractLinuxPackage:path];
  }
}

- (void)extractLinuxPackage:(NSString *)path {
  NSString *ext = [[path pathExtension] lowercaseString];
  NSString *destDir = [[path stringByDeletingPathExtension]
      stringByAppendingString:@"_extracted"];

  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSTask *task = [[NSTask alloc] init];

        if ([ext isEqualToString:@"deb"]) {
          // Extract .deb using ar
          [[NSFileManager defaultManager] createDirectoryAtPath:destDir
                                    withIntermediateDirectories:YES
                                                     attributes:nil
                                                          error:nil];
          task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/ar"];
          task.arguments = @[ @"-x", path ];
          task.currentDirectoryURL = [NSURL fileURLWithPath:destDir];
        } else {
          // For other formats, just show info
          return;
        }

        @try {
          [task launchAndReturnError:nil];
          [task waitUntilExit];

          dispatch_async(dispatch_get_main_queue(), ^{
            [self navigateToPath:destDir];
          });
        } @catch (NSException *e) {
        }
      });
}

- (void)runLinuxBinary:(NSString *)path {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = [NSString
      stringWithFormat:@"🐧 Linux Binary: %@", [path lastPathComponent]];
  alert.informativeText =
      @"This is a Linux ELF binary.\n\nTo run Linux binaries on macOS, you can "
      @"use:\n• Docker\n• Lima (Linux VM)\n• UTM (Virtual Machine)\n\nOr run "
      @"natively on a Linux system.";
  [alert addButtonWithTitle:@"OK"];
  [alert addButtonWithTitle:@"Run with Docker"];

  if ([alert runModal] == NSAlertSecondButtonReturn) {
    [self runWithDocker:path];
  }
}

- (void)runWithDocker:(NSString *)path {
  // Check if Docker is available
  NSTask *checkTask = [[NSTask alloc] init];
  checkTask.executableURL = [NSURL fileURLWithPath:@"/usr/bin/which"];
  checkTask.arguments = @[ @"docker" ];
  NSPipe *pipe = [NSPipe pipe];
  checkTask.standardOutput = pipe;

  @try {
    [checkTask launchAndReturnError:nil];
    [checkTask waitUntilExit];

    if (checkTask.terminationStatus == 0) {
      [[NSClassFromString(@"TerminalWindow") sharedInstance] showWindow];
    } else {
      NSAlert *alert = [[NSAlert alloc] init];
      alert.messageText = @"Docker not found";
      alert.informativeText = @"Please install Docker Desktop from docker.com";
      [alert runModal];
    }
  } @catch (NSException *e) {
  }
}

- (BOOL)isELFBinary:(NSString *)path {
  NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:path];
  if (!handle)
    return NO;

  NSData *magic = [handle readDataOfLength:4];
  [handle closeFile];

  if (magic.length >= 4) {
    const unsigned char *bytes = (const unsigned char *)magic.bytes;
    // ELF magic: 0x7F 'E' 'L' 'F'
    return bytes[0] == 0x7F && bytes[1] == 'E' && bytes[2] == 'L' &&
           bytes[3] == 'F';
  }
  return NO;
}

- (void)mountDiskImage:(NSString *)path {
  NSString *fileName = [path lastPathComponent];

  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText =
      [NSString stringWithFormat:@"💿 Disk Image: %@", fileName];
  alert.informativeText = @"Mount this disk image?";
  [alert addButtonWithTitle:@"Mount"];
  [alert addButtonWithTitle:@"Cancel"];

  if ([alert runModal] == NSAlertFirstButtonReturn) {
    dispatch_async(
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          NSTask *task = [[NSTask alloc] init];
          task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/hdiutil"];
          task.arguments = @[ @"attach", path ];

          @try {
            [task launchAndReturnError:nil];
            [task waitUntilExit];

            dispatch_async(dispatch_get_main_queue(), ^{
              [self navigateToPath:@"/Volumes"];
            });
          } @catch (NSException *e) {
          }
        });
  }
}

- (void)runMacOSInstaller:(NSString *)path {
  NSString *fileName = [path lastPathComponent];

  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText =
      [NSString stringWithFormat:@"📦 macOS Installer: %@", fileName];
  alert.informativeText = @"Run this installer package?";
  alert.alertStyle = NSAlertStyleWarning;
  [alert addButtonWithTitle:@"Install"];
  [alert addButtonWithTitle:@"Cancel"];

  if ([alert runModal] == NSAlertFirstButtonReturn) {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:path]];
  }
}

- (void)runShellScript:(NSString *)path {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = [NSString
      stringWithFormat:@"📜 Shell Script: %@", [path lastPathComponent]];
  alert.informativeText = @"Run this shell script in Terminal?";
  [alert addButtonWithTitle:@"Run"];
  [alert addButtonWithTitle:@"Edit"];
  [alert addButtonWithTitle:@"Cancel"];

  NSModalResponse response = [alert runModal];
  if (response == NSAlertFirstButtonReturn) {
    [[NSClassFromString(@"TerminalWindow") sharedInstance] showWindow];
  } else if (response == NSAlertSecondButtonReturn) {
    [self openTextFile:path];
  }
}

- (void)runPythonScript:(NSString *)path {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = [NSString
      stringWithFormat:@"🐍 Python Script: %@", [path lastPathComponent]];
  alert.informativeText = @"Run this Python script?";
  [alert addButtonWithTitle:@"Run"];
  [alert addButtonWithTitle:@"Edit"];
  [alert addButtonWithTitle:@"Cancel"];

  NSModalResponse response = [alert runModal];
  if (response == NSAlertFirstButtonReturn) {
    [[NSClassFromString(@"TerminalWindow") sharedInstance] showWindow];
  } else if (response == NSAlertSecondButtonReturn) {
    [self openTextFile:path];
  }
}

- (void)runJavaApplication:(NSString *)path {
  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = [NSString
      stringWithFormat:@"☕ Java Application: %@", [path lastPathComponent]];
  alert.informativeText =
      @"Run this Java application?\n\nRequires Java Runtime Environment (JRE).";
  [alert addButtonWithTitle:@"Run"];
  [alert addButtonWithTitle:@"Cancel"];

  if ([alert runModal] == NSAlertFirstButtonReturn) {
    dispatch_async(
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          NSTask *task = [[NSTask alloc] init];
          task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/java"];
          task.arguments = @[ @"-jar", path ];

          @try {
            [task launchAndReturnError:nil];
          } @catch (NSException *e) {
            dispatch_async(dispatch_get_main_queue(), ^{
              NSAlert *errAlert = [[NSAlert alloc] init];
              errAlert.messageText = @"Java not found";
              errAlert.informativeText = @"Please install Java from java.com "
                                         @"or use:\n  brew install openjdk";
              [errAlert runModal];
            });
          }
        });
  }
}

- (void)extractArchive:(NSString *)path {
  NSString *fileName = [path lastPathComponent];
  NSString *ext = [[path pathExtension] lowercaseString];
  NSString *destDir = [path stringByDeletingPathExtension];

  NSAlert *alert = [[NSAlert alloc] init];
  alert.messageText = [NSString stringWithFormat:@"📦 Archive: %@", fileName];
  alert.informativeText = [NSString
      stringWithFormat:@"Extract to: %@", [destDir lastPathComponent]];
  [alert addButtonWithTitle:@"Extract"];
  [alert addButtonWithTitle:@"Cancel"];

  if ([alert runModal] == NSAlertFirstButtonReturn) {
    dispatch_async(
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          NSTask *task = [[NSTask alloc] init];

          if ([ext isEqualToString:@"zip"]) {
            task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/unzip"];
            task.arguments = @[ @"-o", path, @"-d", destDir ];
          } else if ([ext isEqualToString:@"tar"] ||
                     [ext isEqualToString:@"gz"]) {
            [[NSFileManager defaultManager] createDirectoryAtPath:destDir
                                      withIntermediateDirectories:YES
                                                       attributes:nil
                                                            error:nil];
            task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/tar"];
            task.arguments = @[ @"-xf", path, @"-C", destDir ];
          } else if ([ext isEqualToString:@"7z"]) {
            task.executableURL = [NSURL fileURLWithPath:@"/usr/local/bin/7z"];
            task.arguments =
                @[ @"x", path, [NSString stringWithFormat:@"-o%@", destDir] ];
          } else {
            return;
          }

          @try {
            [task launchAndReturnError:nil];
            [task waitUntilExit];

            dispatch_async(dispatch_get_main_queue(), ^{
              [self navigateToPath:destDir];
            });
          } @catch (NSException *e) {
          }
        });
  }
}

- (void)openTextFile:(NSString *)path {
  NSError *error;
  NSString *content = [NSString stringWithContentsOfFile:path
                                                encoding:NSUTF8StringEncoding
                                                   error:&error];

  if (error) {
    content = @"Unable to read file contents.";
  }

  // Create a simple text viewer window
  NSRect frame = NSMakeRect(0, 0, 600, 450);
  NSWindow *window = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  window.title = [path lastPathComponent];
  [window center];

  NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:frame];
  scrollView.hasVerticalScroller = YES;
  scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  NSTextView *textView = [[NSTextView alloc] initWithFrame:frame];
  textView.string = content ?: @"";
  textView.font = [NSFont fontWithName:@"Menlo" size:12];
  textView.editable = YES;
  textView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  scrollView.documentView = textView;
  window.contentView = scrollView;

  [window makeKeyAndOrderFront:nil];
}

- (void)openPDFFile:(NSString *)path {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:path]];
}

- (void)openImageFile:(NSString *)path {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:path]];
}

- (void)openAudioFile:(NSString *)path {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:path]];
}

- (void)openVideoFile:(NSString *)path {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:path]];
}

- (void)openGenericFile:(NSString *)path {
  [[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:path]];
}

- (void)tableRightClick:(NSEvent *)event {
  NSPoint point = [self.tableView convertPoint:[event locationInWindow]
                                      fromView:nil];
  NSInteger row = [self.tableView rowAtPoint:point];

  if (row >= 0) {
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                byExtendingSelection:NO];
  }

  NSMenu *contextMenu = [[NSMenu alloc] initWithTitle:@"Context"];

  if (row >= 0 && row < (NSInteger)self.fileList.count) {
    NSDictionary *item = self.fileList[row];

    NSMenuItem *openItem =
        [[NSMenuItem alloc] initWithTitle:@"Open"
                                   action:@selector(contextOpen:)
                            keyEquivalent:@""];
    openItem.tag = row;
    openItem.target = self;
    [contextMenu addItem:openItem];

    if (![item[@"isDirectory"] boolValue]) {
      NSMenuItem *openWithItem =
          [[NSMenuItem alloc] initWithTitle:@"Open With..."
                                     action:@selector(contextOpenWith:)
                              keyEquivalent:@""];
      openWithItem.tag = row;
      openWithItem.target = self;
      [contextMenu addItem:openWithItem];

      // Check if executable
      NSString *path = item[@"path"];
      NSString *ext = [[path pathExtension] lowercaseString];
      if ([ext isEqualToString:@"exe"] || [ext isEqualToString:@"sh"] ||
          [ext isEqualToString:@"app"] ||
          [[NSFileManager defaultManager] isExecutableFileAtPath:path]) {
        NSMenuItem *runItem =
            [[NSMenuItem alloc] initWithTitle:@"Run"
                                       action:@selector(contextRun:)
                                keyEquivalent:@""];
        runItem.tag = row;
        runItem.target = self;
        [contextMenu addItem:runItem];
      }
    }

    [contextMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *infoItem =
        [[NSMenuItem alloc] initWithTitle:@"Get Info"
                                   action:@selector(contextGetInfo:)
                            keyEquivalent:@""];
    infoItem.tag = row;
    infoItem.target = self;
    [contextMenu addItem:infoItem];

    [contextMenu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *copyItem =
        [[NSMenuItem alloc] initWithTitle:@"Copy"
                                   action:@selector(contextCopy:)
                            keyEquivalent:@""];
    copyItem.tag = row;
    copyItem.target = self;
    [contextMenu addItem:copyItem];

    NSMenuItem *deleteItem =
        [[NSMenuItem alloc] initWithTitle:@"Move to Trash"
                                   action:@selector(contextDelete:)
                            keyEquivalent:@""];
    deleteItem.tag = row;
    deleteItem.target = self;
    [contextMenu addItem:deleteItem];

    NSMenuItem *renameItem =
        [[NSMenuItem alloc] initWithTitle:@"Rename"
                                   action:@selector(contextRename:)
                            keyEquivalent:@""];
    renameItem.tag = row;
    renameItem.target = self;
    [contextMenu addItem:renameItem];
  } else {
    // Empty space context menu
    [contextMenu addItemWithTitle:@"New Folder"
                           action:@selector(contextNewFolder:)
                    keyEquivalent:@""];
    [contextMenu addItem:[NSMenuItem separatorItem]];
    [contextMenu addItemWithTitle:@"Paste"
                           action:@selector(contextPaste:)
                    keyEquivalent:@""];

    for (NSMenuItem *item in contextMenu.itemArray) {
      item.target = self;
    }
  }

  [NSMenu popUpContextMenu:contextMenu withEvent:event forView:self.tableView];
}

- (void)contextOpen:(NSMenuItem *)sender {
  NSInteger row = sender.tag;
  if (row >= 0 && row < (NSInteger)self.fileList.count) {
    NSDictionary *item = self.fileList[row];
    if ([item[@"isDirectory"] boolValue]) {
      [self loadFilesAtPath:item[@"path"]];
    } else {
      [self openFile:item[@"path"]];
    }
  }
}

- (void)contextOpenWith:(NSMenuItem *)sender {
  NSInteger row = sender.tag;
  if (row >= 0 && row < (NSInteger)self.fileList.count) {
    NSDictionary *item = self.fileList[row];
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedContentTypes =
        @[ [UTType typeWithIdentifier:@"com.apple.application-bundle"] ];
    panel.directoryURL = [NSURL fileURLWithPath:@"/Applications"];

    [panel
        beginSheetModalForWindow:self.finderWindow
               completionHandler:^(NSModalResponse result) {
                 if (result == NSModalResponseOK) {
                   [[NSWorkspace sharedWorkspace]
                                   openURLs:@[ [NSURL
                                                fileURLWithPath:item[@"path"]] ]
                       withApplicationAtURL:panel.URL
                                    options:NSWorkspaceLaunchDefault
                              configuration:@{}
                                      error:nil];
                 }
               }];
  }
}

- (void)contextRun:(NSMenuItem *)sender {
  NSInteger row = sender.tag;
  if (row >= 0 && row < (NSInteger)self.fileList.count) {
    NSDictionary *item = self.fileList[row];
    [self openFile:item[@"path"]];
  }
}

- (void)contextGetInfo:(NSMenuItem *)sender {
  NSInteger row = sender.tag;
  if (row >= 0 && row < (NSInteger)self.fileList.count) {
    NSDictionary *item = self.fileList[row];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = item[@"name"];
    alert.informativeText = [NSString
        stringWithFormat:@"Path: %@\nSize: %@\nModified: %@\nIs Directory: %@",
                         item[@"path"], item[@"size"], item[@"modified"],
                         [item[@"isDirectory"] boolValue] ? @"Yes" : @"No"];
    [alert runModal];
  }
}

- (void)contextCopy:(NSMenuItem *)sender {
  NSInteger row = sender.tag;
  if (row >= 0 && row < (NSInteger)self.fileList.count) {
    NSDictionary *item = self.fileList[row];
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    [pasteboard clearContents];
    [pasteboard writeObjects:@[ [NSURL fileURLWithPath:item[@"path"]] ]];
  }
}

- (void)contextDelete:(NSMenuItem *)sender {
  NSInteger row = sender.tag;
  if (row >= 0 && row < (NSInteger)self.fileList.count) {
    NSDictionary *item = self.fileList[row];
    [[NSFileManager defaultManager]
          trashItemAtURL:[NSURL fileURLWithPath:item[@"path"]]
        resultingItemURL:nil
                   error:nil];
    [self loadFilesAtPath:self.currentPath];
  }
}

- (void)contextRename:(NSMenuItem *)sender {
  NSInteger row = sender.tag;
  if (row >= 0 && row < (NSInteger)self.fileList.count) {
    NSDictionary *item = self.fileList[row];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"Rename";
    alert.informativeText = @"Enter new name:";

    NSTextField *input =
        [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 250, 24)];
    input.stringValue = item[@"name"];
    alert.accessoryView = input;

    [alert addButtonWithTitle:@"Rename"];
    [alert addButtonWithTitle:@"Cancel"];

    if ([alert runModal] == NSAlertFirstButtonReturn) {
      NSString *newName = input.stringValue;
      if (newName.length > 0) {
        NSString *newPath = [[item[@"path"] stringByDeletingLastPathComponent]
            stringByAppendingPathComponent:newName];
        [[NSFileManager defaultManager] moveItemAtPath:item[@"path"]
                                                toPath:newPath
                                                 error:nil];
        [self loadFilesAtPath:self.currentPath];
      }
    }
  }
}

- (void)contextNewFolder:(id)sender {
  NSString *newPath =
      [self.currentPath stringByAppendingPathComponent:@"New Folder"];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSInteger counter = 1;
  while ([fm fileExistsAtPath:newPath]) {
    newPath = [self.currentPath
        stringByAppendingPathComponent:[NSString
                                           stringWithFormat:@"New Folder %ld",
                                                            (long)counter++]];
  }
  [fm createDirectoryAtPath:newPath
      withIntermediateDirectories:NO
                       attributes:nil
                            error:nil];
  [self loadFilesAtPath:self.currentPath];
}

- (void)contextPaste:(id)sender {
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  NSArray *urls = [pasteboard
      readObjectsForClasses:@[ [NSURL class] ]
                    options:@{NSPasteboardURLReadingFileURLsOnlyKey : @YES}];

  for (NSURL *url in urls) {
    NSString *destPath = [self.currentPath
        stringByAppendingPathComponent:[url lastPathComponent]];
    [[NSFileManager defaultManager]
        copyItemAtURL:url
                toURL:[NSURL fileURLWithPath:destPath]
                error:nil];
  }
  [self loadFilesAtPath:self.currentPath];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return self.fileList.count;
}

- (id)tableView:(NSTableView *)tableView
    objectValueForTableColumn:(NSTableColumn *)tableColumn
                          row:(NSInteger)row {
  if (row < 0 || row >= (NSInteger)self.fileList.count)
    return @"";

  NSDictionary *item = self.fileList[row];
  if (!item)
    return @"";

  NSString *identifier = tableColumn.identifier;
  if (!identifier)
    return @"";

  @try {
    if ([identifier isEqualToString:@"icon"]) {
      return [item[@"isDirectory"] boolValue] ? @"📁" : @"📄";
    } else if ([identifier isEqualToString:@"name"]) {
      return item[@"name"] ?: @"Unknown";
    } else if ([identifier isEqualToString:@"size"]) {
      if ([item[@"isDirectory"] boolValue])
        return @"--";
      long long bytes = [item[@"size"] longLongValue];
      if (bytes < 1024)
        return [NSString stringWithFormat:@"%lld B", bytes];
      if (bytes < 1024 * 1024)
        return [NSString stringWithFormat:@"%.1f KB", bytes / 1024.0];
      if (bytes < 1024 * 1024 * 1024)
        return
            [NSString stringWithFormat:@"%.1f MB", bytes / (1024.0 * 1024.0)];
      return [NSString
          stringWithFormat:@"%.1f GB", bytes / (1024.0 * 1024.0 * 1024.0)];
    } else if ([identifier isEqualToString:@"modified"]) {
      NSDate *date = item[@"modified"];
      if (!date || ![date isKindOfClass:[NSDate class]])
        return @"--";
      NSDateFormatter *df = [[NSDateFormatter alloc] init];
      df.dateStyle = NSDateFormatterMediumStyle;
      df.timeStyle = NSDateFormatterShortStyle;
      return [df stringFromDate:date] ?: @"--";
    }
  } @catch (NSException *e) {
    NSLog(@"FinderWindow tableView error: %@", e);
    return @"--";
  }

  return @"";
}

#pragma mark - NSMenuDelegate

- (void)menuNeedsUpdate:(NSMenu *)menu {
  [menu removeAllItems];

  NSInteger row = self.tableView.clickedRow;

  if (row >= 0 && row < (NSInteger)self.fileList.count) {
    NSDictionary *item = self.fileList[row];
    [self.tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:row]
                byExtendingSelection:NO];

    NSMenuItem *openItem =
        [[NSMenuItem alloc] initWithTitle:@"Open"
                                   action:@selector(contextOpen:)
                            keyEquivalent:@""];
    openItem.tag = row;
    openItem.target = self;
    [menu addItem:openItem];

    if (![item[@"isDirectory"] boolValue]) {
      NSMenuItem *openWithItem =
          [[NSMenuItem alloc] initWithTitle:@"Open With..."
                                     action:@selector(contextOpenWith:)
                              keyEquivalent:@""];
      openWithItem.tag = row;
      openWithItem.target = self;
      [menu addItem:openWithItem];

      NSString *path = item[@"path"];
      NSString *ext = [[path pathExtension] lowercaseString];
      if ([ext isEqualToString:@"exe"] || [ext isEqualToString:@"sh"] ||
          [ext isEqualToString:@"app"] ||
          [[NSFileManager defaultManager] isExecutableFileAtPath:path]) {
        NSMenuItem *runItem =
            [[NSMenuItem alloc] initWithTitle:@"Run"
                                       action:@selector(contextRun:)
                                keyEquivalent:@""];
        runItem.tag = row;
        runItem.target = self;
        [menu addItem:runItem];
      }
    }

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *infoItem =
        [[NSMenuItem alloc] initWithTitle:@"Get Info"
                                   action:@selector(contextGetInfo:)
                            keyEquivalent:@""];
    infoItem.tag = row;
    infoItem.target = self;
    [menu addItem:infoItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *copyItem =
        [[NSMenuItem alloc] initWithTitle:@"Copy"
                                   action:@selector(contextCopy:)
                            keyEquivalent:@""];
    copyItem.tag = row;
    copyItem.target = self;
    [menu addItem:copyItem];

    NSMenuItem *deleteItem =
        [[NSMenuItem alloc] initWithTitle:@"Move to Trash"
                                   action:@selector(contextDelete:)
                            keyEquivalent:@""];
    deleteItem.tag = row;
    deleteItem.target = self;
    [menu addItem:deleteItem];

    NSMenuItem *renameItem =
        [[NSMenuItem alloc] initWithTitle:@"Rename"
                                   action:@selector(contextRename:)
                            keyEquivalent:@""];
    renameItem.tag = row;
    renameItem.target = self;
    [menu addItem:renameItem];
  } else {
    NSMenuItem *newFolderItem =
        [[NSMenuItem alloc] initWithTitle:@"New Folder"
                                   action:@selector(contextNewFolder:)
                            keyEquivalent:@""];
    newFolderItem.target = self;
    [menu addItem:newFolderItem];

    [menu addItem:[NSMenuItem separatorItem]];

    NSMenuItem *pasteItem =
        [[NSMenuItem alloc] initWithTitle:@"Paste"
                                   action:@selector(contextPaste:)
                            keyEquivalent:@""];
    pasteItem.target = self;
    [menu addItem:pasteItem];
  }
}

@end
