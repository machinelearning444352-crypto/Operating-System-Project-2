#import "AutomatorWindow.h"

@interface AutomatorWindow () <NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSTableView *actionLibrary;
@property(nonatomic, strong) NSMutableArray *availableActions;
@property(nonatomic, strong) NSMutableArray *workflowSteps;
@property(nonatomic, strong) NSTableView *workflowTable;
@property(nonatomic, strong) NSSearchField *searchField;
@property(nonatomic, strong) NSPopUpButton *workflowType;
@property(nonatomic, strong) NSTextField *statusLabel, *descriptionLabel;
@end

@implementation AutomatorWindow

+ (instancetype)sharedInstance {
  static AutomatorWindow *inst;
  static dispatch_once_t t;
  dispatch_once(&t, ^{
    inst = [[self alloc] init];
  });
  return inst;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _workflowSteps = [NSMutableArray array];
    _availableActions = [NSMutableArray arrayWithArray:@[
      @{
        @"name" : @"Get Specified Finder Items",
        @"cat" : @"Files & Folders",
        @"icon" : @"📂",
        @"desc" : @"Select files or folders to pass to the next action"
      },
      @{
        @"name" : @"Copy Finder Items",
        @"cat" : @"Files & Folders",
        @"icon" : @"📋",
        @"desc" : @"Copy selected files to a destination folder"
      },
      @{
        @"name" : @"Move Finder Items",
        @"cat" : @"Files & Folders",
        @"icon" : @"📁",
        @"desc" : @"Move selected items to a new location"
      },
      @{
        @"name" : @"Rename Finder Items",
        @"cat" : @"Files & Folders",
        @"icon" : @"✏️",
        @"desc" : @"Rename files using patterns and text replacement"
      },
      @{
        @"name" : @"Create Archive",
        @"cat" : @"Files & Folders",
        @"icon" : @"📦",
        @"desc" : @"Compress files into a ZIP archive"
      },
      @{
        @"name" : @"Filter Finder Items",
        @"cat" : @"Files & Folders",
        @"icon" : @"🔍",
        @"desc" : @"Filter items by name, type, size, or date"
      },
      @{
        @"name" : @"Get Folder Contents",
        @"cat" : @"Files & Folders",
        @"icon" : @"📂",
        @"desc" : @"Get all items in a folder recursively"
      },
      @{
        @"name" : @"Run Shell Script",
        @"cat" : @"Utilities",
        @"icon" : @"🐚",
        @"desc" : @"Execute a shell script with input from previous action"
      },
      @{
        @"name" : @"Run AppleScript",
        @"cat" : @"Utilities",
        @"icon" : @"📜",
        @"desc" : @"Run an AppleScript with variables from workflow"
      },
      @{
        @"name" : @"Run Python Script",
        @"cat" : @"Utilities",
        @"icon" : @"🐍",
        @"desc" : @"Execute Python code on input data"
      },
      @{
        @"name" : @"Display Notification",
        @"cat" : @"Utilities",
        @"icon" : @"🔔",
        @"desc" : @"Show a notification with custom title and message"
      },
      @{
        @"name" : @"Ask for Confirmation",
        @"cat" : @"Utilities",
        @"icon" : @"❓",
        @"desc" : @"Present a dialog asking user to confirm or cancel"
      },
      @{
        @"name" : @"Set Variable",
        @"cat" : @"Utilities",
        @"icon" : @"📌",
        @"desc" : @"Store input in a named variable for later use"
      },
      @{
        @"name" : @"Get Variable",
        @"cat" : @"Utilities",
        @"icon" : @"📎",
        @"desc" : @"Retrieve a previously stored variable"
      },
      @{
        @"name" : @"Pause",
        @"cat" : @"Utilities",
        @"icon" : @"⏸️",
        @"desc" : @"Pause workflow for specified duration"
      },
      @{
        @"name" : @"Resize Images",
        @"cat" : @"Photos",
        @"icon" : @"🖼️",
        @"desc" : @"Resize images to specified dimensions"
      },
      @{
        @"name" : @"Convert Image Format",
        @"cat" : @"Photos",
        @"icon" : @"🔄",
        @"desc" : @"Convert images between PNG, JPEG, TIFF, etc."
      },
      @{
        @"name" : @"Apply Quartz Filter",
        @"cat" : @"Photos",
        @"icon" : @"🎨",
        @"desc" : @"Apply a Quartz Composer filter to images"
      },
      @{
        @"name" : @"Crop Images",
        @"cat" : @"Photos",
        @"icon" : @"✂️",
        @"desc" : @"Crop images to specified dimensions"
      },
      @{
        @"name" : @"Get Text from PDF",
        @"cat" : @"PDFs",
        @"icon" : @"📄",
        @"desc" : @"Extract text content from PDF documents"
      },
      @{
        @"name" : @"Combine PDFs",
        @"cat" : @"PDFs",
        @"icon" : @"📑",
        @"desc" : @"Merge multiple PDF documents into one"
      },
      @{
        @"name" : @"Watermark PDF",
        @"cat" : @"PDFs",
        @"icon" : @"💧",
        @"desc" : @"Add a watermark image/text to PDF pages"
      },
      @{
        @"name" : @"Extract PDF Pages",
        @"cat" : @"PDFs",
        @"icon" : @"📋",
        @"desc" : @"Extract specific pages from a PDF"
      },
      @{
        @"name" : @"Get Webpage Content",
        @"cat" : @"Internet",
        @"icon" : @"🌐",
        @"desc" : @"Download content from a URL"
      },
      @{
        @"name" : @"Download URLs",
        @"cat" : @"Internet",
        @"icon" : @"⬇️",
        @"desc" : @"Download files from specified URLs"
      },
      @{
        @"name" : @"Send Email",
        @"cat" : @"Mail",
        @"icon" : @"📧",
        @"desc" : @"Send an email with attachments from workflow"
      },
      @{
        @"name" : @"New Calendar Event",
        @"cat" : @"Calendar",
        @"icon" : @"📅",
        @"desc" : @"Create a new calendar event"
      },
      @{
        @"name" : @"Encode/Decode Text",
        @"cat" : @"Text",
        @"icon" : @"🔐",
        @"desc" : @"Encode or decode text (Base64, URL, HTML)"
      },
      @{
        @"name" : @"Find & Replace Text",
        @"cat" : @"Text",
        @"icon" : @"🔄",
        @"desc" : @"Search and replace text using regex or literal"
      },
      @{
        @"name" : @"Convert Text Case",
        @"cat" : @"Text",
        @"icon" : @"Aa",
        @"desc" : @"Convert text to upper/lower/title case"
      },
    ]];
  }
  return self;
}

- (void)showWindow {
  if (self.window) {
    [self.window makeKeyAndOrderFront:nil];
    return;
  }

  self.window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(100, 80, 950, 650)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.window.title = @"Automator";
  self.window.backgroundColor = [NSColor colorWithRed:0.12
                                                green:0.12
                                                 blue:0.14
                                                alpha:1.0];

  NSView *content = self.window.contentView;

  // ===== Toolbar =====
  NSView *toolbar = [[NSView alloc] initWithFrame:NSMakeRect(0, 608, 950, 42)];
  toolbar.wantsLayer = YES;
  toolbar.layer.backgroundColor =
      [NSColor controlBackgroundColor].CGColor;
  toolbar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;

  self.workflowType =
      [[NSPopUpButton alloc] initWithFrame:NSMakeRect(15, 8, 160, 26)];
  [self.workflowType addItemsWithTitles:@[
    @"Workflow", @"Application", @"Quick Action", @"Folder Action",
    @"Calendar Alarm", @"Print Plugin"
  ]];
  [toolbar addSubview:self.workflowType];

  NSButton *runBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(200, 8, 70, 26)];
  runBtn.title = @"▶ Run";
  runBtn.bezelStyle = NSBezelStyleRounded;
  runBtn.target = self;
  runBtn.action = @selector(runWorkflow:);
  [toolbar addSubview:runBtn];

  NSButton *stopBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(280, 8, 70, 26)];
  stopBtn.title = @"⬛ Stop";
  stopBtn.bezelStyle = NSBezelStyleRounded;
  [toolbar addSubview:stopBtn];

  NSButton *saveBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(360, 8, 70, 26)];
  saveBtn.title = @"Save";
  saveBtn.bezelStyle = NSBezelStyleRounded;
  [toolbar addSubview:saveBtn];

  self.statusLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(600, 12, 340, 18)];
  self.statusLabel.stringValue = @"Drag actions to build workflow";
  self.statusLabel.font = [NSFont systemFontOfSize:11];
  self.statusLabel.textColor = [NSColor grayColor];
  self.statusLabel.editable = NO;
  self.statusLabel.bordered = NO;
  self.statusLabel.drawsBackground = NO;
  self.statusLabel.autoresizingMask = NSViewMinXMargin;
  [toolbar addSubview:self.statusLabel];
  [content addSubview:toolbar];

  // ===== Action Library (Left) =====
  NSView *libPanel = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 608)];
  libPanel.wantsLayer = YES;
  libPanel.layer.backgroundColor =
      [NSColor controlBackgroundColor].CGColor;
  libPanel.autoresizingMask = NSViewHeightSizable;

  self.searchField =
      [[NSSearchField alloc] initWithFrame:NSMakeRect(10, 570, 280, 28)];
  self.searchField.placeholderString = @"Search actions...";
  self.searchField.autoresizingMask = NSViewMinYMargin;
  [libPanel addSubview:self.searchField];

  NSScrollView *libScroll =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 300, 565)];
  libScroll.hasVerticalScroller = YES;
  libScroll.autoresizingMask = NSViewHeightSizable;

  self.actionLibrary = [[NSTableView alloc] initWithFrame:libScroll.bounds];
  self.actionLibrary.dataSource = self;
  self.actionLibrary.delegate = self;
  self.actionLibrary.rowHeight = 44;
  self.actionLibrary.backgroundColor = [NSColor colorWithRed:0.15
                                                       green:0.15
                                                        blue:0.18
                                                       alpha:1.0];
  self.actionLibrary.tag = 1;

  NSTableColumn *actionCol =
      [[NSTableColumn alloc] initWithIdentifier:@"action"];
  actionCol.title = @"Actions";
  actionCol.width = 280;
  [self.actionLibrary addTableColumn:actionCol];
  self.actionLibrary.headerView = nil;
  libScroll.documentView = self.actionLibrary;
  [libPanel addSubview:libScroll];
  [content addSubview:libPanel];

  // ===== Workflow Canvas (Right) =====
  NSScrollView *workScroll =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(300, 40, 650, 568)];
  workScroll.hasVerticalScroller = YES;
  workScroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  workScroll.backgroundColor = [NSColor colorWithRed:0.13
                                               green:0.13
                                                blue:0.16
                                               alpha:1.0];

  self.workflowTable = [[NSTableView alloc] initWithFrame:workScroll.bounds];
  self.workflowTable.dataSource = self;
  self.workflowTable.delegate = self;
  self.workflowTable.rowHeight = 80;
  self.workflowTable.backgroundColor = [NSColor colorWithRed:0.13
                                                       green:0.13
                                                        blue:0.16
                                                       alpha:1.0];
  self.workflowTable.tag = 2;

  NSTableColumn *stepCol = [[NSTableColumn alloc] initWithIdentifier:@"step"];
  stepCol.title = @"Workflow Steps";
  stepCol.width = 630;
  [self.workflowTable addTableColumn:stepCol];
  self.workflowTable.headerView = nil;
  workScroll.documentView = self.workflowTable;
  [content addSubview:workScroll];

  // ===== Description bar =====
  self.descriptionLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(300, 5, 640, 30)];
  self.descriptionLabel.stringValue =
      @"Select an action to see its description";
  self.descriptionLabel.font = [NSFont systemFontOfSize:11];
  self.descriptionLabel.textColor = [NSColor grayColor];
  self.descriptionLabel.editable = NO;
  self.descriptionLabel.bordered = NO;
  self.descriptionLabel.drawsBackground = NO;
  self.descriptionLabel.autoresizingMask = NSViewWidthSizable;
  [content addSubview:self.descriptionLabel];

  [self.actionLibrary reloadData];
  [self.window makeKeyAndOrderFront:nil];
}

- (void)runWorkflow:(id)sender {
  if (self.workflowSteps.count == 0) {
    self.statusLabel.stringValue = @"⚠️ No actions in workflow";
    return;
  }
  self.statusLabel.stringValue =
      [NSString stringWithFormat:@"▶ Running %lu action(s)...",
                                 (unsigned long)self.workflowSteps.count];
  dispatch_after(
      dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
      dispatch_get_main_queue(), ^{
        self.statusLabel.stringValue = @"✅ Workflow completed successfully";
      });
}

// ===== TableView =====
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
  return tv.tag == 1 ? self.availableActions.count : self.workflowSteps.count;
}

- (NSView *)tableView:(NSTableView *)tv
    viewForTableColumn:(NSTableColumn *)col
                   row:(NSInteger)row {
  if (tv.tag == 1) {
    // Action library
    NSDictionary *action = self.availableActions[row];
    NSTableCellView *cell =
        [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 280, 44)];

    NSTextField *icon =
        [[NSTextField alloc] initWithFrame:NSMakeRect(8, 12, 24, 20)];
    icon.stringValue = action[@"icon"];
    icon.font = [NSFont systemFontOfSize:16];
    icon.editable = NO;
    icon.bordered = NO;
    icon.drawsBackground = NO;
    [cell addSubview:icon];

    NSTextField *name =
        [[NSTextField alloc] initWithFrame:NSMakeRect(36, 22, 240, 18)];
    name.stringValue = action[@"name"];
    name.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    name.textColor = [NSColor whiteColor];
    name.editable = NO;
    name.bordered = NO;
    name.drawsBackground = NO;
    [cell addSubview:name];

    NSTextField *cat =
        [[NSTextField alloc] initWithFrame:NSMakeRect(36, 6, 240, 14)];
    cat.stringValue = action[@"cat"];
    cat.font = [NSFont systemFontOfSize:10];
    cat.textColor = [NSColor grayColor];
    cat.editable = NO;
    cat.bordered = NO;
    cat.drawsBackground = NO;
    [cell addSubview:cat];
    return cell;
  } else {
    // Workflow step
    NSDictionary *step = self.workflowSteps[row];
    NSTableCellView *cell =
        [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 630, 80)];
    cell.wantsLayer = YES;
    cell.layer.backgroundColor =
        [NSColor colorWithRed:0.18 green:0.18 blue:0.22 alpha:1.0].CGColor;
    cell.layer.cornerRadius = 8;

    NSTextField *stepNum =
        [[NSTextField alloc] initWithFrame:NSMakeRect(12, 30, 30, 20)];
    stepNum.stringValue = [NSString stringWithFormat:@"%ld", (long)row + 1];
    stepNum.font = [NSFont systemFontOfSize:18 weight:NSFontWeightBold];
    stepNum.textColor = [NSColor systemBlueColor];
    stepNum.editable = NO;
    stepNum.bordered = NO;
    stepNum.drawsBackground = NO;
    [cell addSubview:stepNum];

    NSTextField *icon =
        [[NSTextField alloc] initWithFrame:NSMakeRect(46, 30, 24, 24)];
    icon.stringValue = step[@"icon"];
    icon.font = [NSFont systemFontOfSize:18];
    icon.editable = NO;
    icon.bordered = NO;
    icon.drawsBackground = NO;
    [cell addSubview:icon];

    NSTextField *name =
        [[NSTextField alloc] initWithFrame:NSMakeRect(76, 44, 400, 20)];
    name.stringValue = step[@"name"];
    name.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    name.textColor = [NSColor whiteColor];
    name.editable = NO;
    name.bordered = NO;
    name.drawsBackground = NO;
    [cell addSubview:name];

    NSTextField *desc =
        [[NSTextField alloc] initWithFrame:NSMakeRect(76, 16, 500, 22)];
    desc.stringValue = step[@"desc"];
    desc.font = [NSFont systemFontOfSize:11];
    desc.textColor = [NSColor grayColor];
    desc.editable = NO;
    desc.bordered = NO;
    desc.drawsBackground = NO;
    [cell addSubview:desc];

    NSButton *removeBtn =
        [[NSButton alloc] initWithFrame:NSMakeRect(590, 28, 24, 24)];
    removeBtn.title = @"✕";
    removeBtn.bordered = NO;
    removeBtn.tag = row;
    removeBtn.target = self;
    removeBtn.action = @selector(removeStep:);
    [cell addSubview:removeBtn];
    return cell;
  }
}

- (BOOL)tableView:(NSTableView *)tv shouldSelectRow:(NSInteger)row {
  if (tv.tag == 1) {
    NSDictionary *action = self.availableActions[row];
    self.descriptionLabel.stringValue = action[@"desc"];
  }
  return YES;
}

- (void)tableViewSelectionDidChange:(NSNotification *)note {
  NSTableView *tv = note.object;
  if (tv.tag == 1 && tv.selectedRow >= 0) {
    // Double-click would add to workflow; for now, add on selection
    NSDictionary *action = self.availableActions[tv.selectedRow];
    [self.workflowSteps addObject:action];
    [self.workflowTable reloadData];
    self.statusLabel.stringValue =
        [NSString stringWithFormat:@"%lu action(s) in workflow",
                                   (unsigned long)self.workflowSteps.count];
  }
}

- (void)removeStep:(NSButton *)sender {
  if (sender.tag < (NSInteger)self.workflowSteps.count) {
    [self.workflowSteps removeObjectAtIndex:sender.tag];
    [self.workflowTable reloadData];
  }
}

@end
