#import "MailWindow.h"

@interface MailWindow ()
@property(nonatomic, strong) NSWindow *mailWindow;
@property(nonatomic, strong) NSTableView *mailTable;
@property(nonatomic, strong) NSTextView *emailContentView;
@property(nonatomic, strong) NSMutableArray *emails;
@property(nonatomic, strong) NSMutableArray *folders;
@property(nonatomic, assign) NSInteger selectedEmail;
@end

@implementation MailWindow

+ (instancetype)sharedInstance {
  static MailWindow *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[MailWindow alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.selectedEmail = -1;
    self.folders = [NSMutableArray arrayWithArray:@[
      @{@"name" : @"Inbox", @"icon" : @"📥", @"count" : @3},
      @{@"name" : @"Sent", @"icon" : @"📤", @"count" : @0},
      @{@"name" : @"Drafts", @"icon" : @"📝", @"count" : @1},
      @{@"name" : @"Trash", @"icon" : @"🗑️", @"count" : @0},
    ]];
    self.emails = [NSMutableArray array];
  }
  return self;
}

- (void)showWindow {
  if (self.mailWindow) {
    [self.mailWindow makeKeyAndOrderFront:nil];
    return;
  }

  NSRect frame = NSMakeRect(0, 0, 900, 600);
  self.mailWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.mailWindow setTitle:@"Mail"];
  [self.mailWindow center];

  NSView *contentView = [[NSView alloc] initWithFrame:frame];
  contentView.wantsLayer = YES;
  contentView.layer.backgroundColor = [[NSColor colorWithRed:0.11
                                                       green:0.11
                                                        blue:0.13
                                                       alpha:1.0] CGColor];
  [self.mailWindow setContentView:contentView];

  // Sidebar
  NSView *sidebar =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, frame.size.height)];
  sidebar.wantsLayer = YES;
  sidebar.layer.backgroundColor = [[NSColor colorWithRed:0.08
                                                   green:0.08
                                                    blue:0.10
                                                   alpha:1.0] CGColor];
  [contentView addSubview:sidebar];

  // Sidebar title
  NSTextField *sidebarTitle = [[NSTextField alloc]
      initWithFrame:NSMakeRect(15, frame.size.height - 45, 170, 25)];
  sidebarTitle.stringValue = @"Mailboxes";
  sidebarTitle.font = [NSFont boldSystemFontOfSize:13];
  sidebarTitle.textColor = [NSColor grayColor];
  sidebarTitle.bezeled = NO;
  sidebarTitle.editable = NO;
  sidebarTitle.drawsBackground = NO;
  [sidebar addSubview:sidebarTitle];

  // Folder buttons
  CGFloat yPos = frame.size.height - 80;
  for (NSDictionary *folder in self.folders) {
    NSButton *folderBtn =
        [[NSButton alloc] initWithFrame:NSMakeRect(10, yPos, 180, 32)];
    folderBtn.title = [NSString
        stringWithFormat:@"  %@  %@", folder[@"icon"], folder[@"name"]];
    folderBtn.bezelStyle = NSBezelStyleRecessed;
    folderBtn.alignment = NSTextAlignmentLeft;
    folderBtn.font = [NSFont systemFontOfSize:13];
    folderBtn.target = self;
    folderBtn.action = @selector(folderSelected:);
    folderBtn.tag = [self.folders indexOfObject:folder];
    [sidebar addSubview:folderBtn];
    yPos -= 36;
  }

  // Compose button
  NSButton *composeBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(10, 20, 180, 36)];
  composeBtn.title = @"✉️  Compose";
  composeBtn.bezelStyle = NSBezelStyleRounded;
  composeBtn.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  composeBtn.target = self;
  composeBtn.action = @selector(composeEmail:);
  [sidebar addSubview:composeBtn];

  // Email list
  NSView *emailListView =
      [[NSView alloc] initWithFrame:NSMakeRect(200, 0, 280, frame.size.height)];
  emailListView.wantsLayer = YES;
  emailListView.layer.backgroundColor = [[NSColor colorWithRed:0.14
                                                         green:0.14
                                                          blue:0.16
                                                         alpha:1.0] CGColor];
  [contentView addSubview:emailListView];

  // Email list header
  NSTextField *inboxTitle = [[NSTextField alloc]
      initWithFrame:NSMakeRect(15, frame.size.height - 45, 250, 25)];
  inboxTitle.stringValue = @"Inbox";
  inboxTitle.font = [NSFont boldSystemFontOfSize:18];
  inboxTitle.bezeled = NO;
  inboxTitle.editable = NO;
  inboxTitle.drawsBackground = NO;
  [emailListView addSubview:inboxTitle];

  // Search
  NSSearchField *searchField = [[NSSearchField alloc]
      initWithFrame:NSMakeRect(10, frame.size.height - 80, 260, 28)];
  searchField.placeholderString = @"Search Mail";
  [emailListView addSubview:searchField];

  // Email table
  NSScrollView *emailScroll = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 0, 280, frame.size.height - 90)];
  emailScroll.hasVerticalScroller = YES;
  emailScroll.autohidesScrollers = YES;

  self.mailTable = [[NSTableView alloc] initWithFrame:emailScroll.bounds];
  self.mailTable.dataSource = self;
  self.mailTable.delegate = self;
  self.mailTable.rowHeight = 70;
  self.mailTable.headerView = nil;

  NSTableColumn *emailCol = [[NSTableColumn alloc] initWithIdentifier:@"email"];
  emailCol.width = 280;
  [self.mailTable addTableColumn:emailCol];

  emailScroll.documentView = self.mailTable;
  [emailListView addSubview:emailScroll];

  // Email content area
  NSView *emailContent =
      [[NSView alloc] initWithFrame:NSMakeRect(480, 0, frame.size.width - 480,
                                               frame.size.height)];
  emailContent.wantsLayer = YES;
  emailContent.layer.backgroundColor = [[NSColor colorWithRed:0.13
                                                        green:0.13
                                                         blue:0.15
                                                        alpha:1.0] CGColor];
  [contentView addSubview:emailContent];

  // Empty state
  NSTextField *emptyLabel = [[NSTextField alloc]
      initWithFrame:NSMakeRect(50, frame.size.height / 2 - 20,
                               emailContent.bounds.size.width - 100, 40)];
  emptyLabel.stringValue = @"Select an email to read\nor compose a new message";
  emptyLabel.font = [NSFont systemFontOfSize:14];
  emptyLabel.textColor = [NSColor grayColor];
  emptyLabel.alignment = NSTextAlignmentCenter;
  emptyLabel.bezeled = NO;
  emptyLabel.editable = NO;
  emptyLabel.drawsBackground = NO;
  [emailContent addSubview:emptyLabel];

  [self.mailWindow makeKeyAndOrderFront:nil];
}

- (void)folderSelected:(NSButton *)sender {
  // Handle folder selection
}

- (void)composeEmail:(id)sender {
  NSWindow *composeWindow = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(0, 0, 550, 450)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [composeWindow setTitle:@"New Message"];
  [composeWindow center];

  NSView *content =
      [[NSView alloc] initWithFrame:composeWindow.contentView.bounds];
  content.wantsLayer = YES;
  content.layer.backgroundColor = [[NSColor colorWithRed:0.11
                                                   green:0.11
                                                    blue:0.13
                                                   alpha:1.0] CGColor];
  [composeWindow setContentView:content];

  // To field
  NSTextField *toLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(15, 400, 50, 22)];
  toLabel.stringValue = @"To:";
  toLabel.font = [NSFont systemFontOfSize:13];
  toLabel.bezeled = NO;
  toLabel.editable = NO;
  toLabel.drawsBackground = NO;
  [content addSubview:toLabel];

  NSTextField *toField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(70, 398, 460, 26)];
  toField.placeholderString = @"recipient@email.com";
  toField.bezeled = YES;
  toField.bezelStyle = NSTextFieldRoundedBezel;
  [content addSubview:toField];

  // Subject field
  NSTextField *subjectLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(15, 365, 50, 22)];
  subjectLabel.stringValue = @"Subject:";
  subjectLabel.font = [NSFont systemFontOfSize:13];
  subjectLabel.bezeled = NO;
  subjectLabel.editable = NO;
  subjectLabel.drawsBackground = NO;
  [content addSubview:subjectLabel];

  NSTextField *subjectField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(70, 363, 460, 26)];
  subjectField.placeholderString = @"Email subject";
  subjectField.bezeled = YES;
  subjectField.bezelStyle = NSTextFieldRoundedBezel;
  [content addSubview:subjectField];

  // Body
  NSScrollView *bodyScroll =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(15, 60, 520, 290)];
  bodyScroll.hasVerticalScroller = YES;
  bodyScroll.borderType = NSBezelBorder;

  NSTextView *bodyText =
      [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 520, 290)];
  bodyText.font = [NSFont systemFontOfSize:13];
  bodyText.textContainerInset = NSMakeSize(8, 8);
  bodyScroll.documentView = bodyText;
  [content addSubview:bodyScroll];

  // Send button
  NSButton *sendBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(435, 15, 100, 35)];
  sendBtn.title = @"Send";
  sendBtn.bezelStyle = NSBezelStyleRounded;
  sendBtn.keyEquivalent = @"\r";
  [content addSubview:sendBtn];

  // Cancel button
  NSButton *cancelBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(330, 15, 100, 35)];
  cancelBtn.title = @"Cancel";
  cancelBtn.bezelStyle = NSBezelStyleRounded;
  cancelBtn.target = composeWindow;
  cancelBtn.action = @selector(close);
  [content addSubview:cancelBtn];

  [composeWindow makeKeyAndOrderFront:nil];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return self.emails.count;
}

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row {
  NSTableCellView *cell =
      [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 280, 70)];

  if (row < (NSInteger)self.emails.count) {
    NSDictionary *email = self.emails[row];

    NSTextField *sender =
        [[NSTextField alloc] initWithFrame:NSMakeRect(12, 45, 256, 18)];
    sender.stringValue = email[@"from"] ?: @"";
    sender.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    sender.bezeled = NO;
    sender.editable = NO;
    sender.drawsBackground = NO;
    [cell addSubview:sender];

    NSTextField *subject =
        [[NSTextField alloc] initWithFrame:NSMakeRect(12, 26, 256, 16)];
    subject.stringValue = email[@"subject"] ?: @"";
    subject.font = [NSFont systemFontOfSize:12];
    subject.bezeled = NO;
    subject.editable = NO;
    subject.drawsBackground = NO;
    [cell addSubview:subject];

    NSTextField *preview =
        [[NSTextField alloc] initWithFrame:NSMakeRect(12, 8, 256, 14)];
    preview.stringValue = email[@"preview"] ?: @"";
    preview.font = [NSFont systemFontOfSize:11];
    preview.textColor = [NSColor grayColor];
    preview.bezeled = NO;
    preview.editable = NO;
    preview.drawsBackground = NO;
    [cell addSubview:preview];
  }

  return cell;
}

@end
