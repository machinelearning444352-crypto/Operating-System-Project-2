#import "NotesWindow.h"

@interface NotesWindow ()
@property(nonatomic, strong) NSWindow *notesWindow;
@property(nonatomic, strong) NSTableView *notesTable;
@property(nonatomic, strong) NSTextView *noteTextView;
@property(nonatomic, strong) NSMutableArray *notes;
@property(nonatomic, assign) NSInteger selectedNote;
@end

@implementation NotesWindow

+ (instancetype)sharedInstance {
  static NotesWindow *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[NotesWindow alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.selectedNote = 0;
    self.notes = [NSMutableArray arrayWithArray:@[
      @{
        @"title" : @"Welcome to Notes",
        @"content" : @"This is a simple notes application.\n\nYou can create "
                     @"and edit notes here.",
        @"date" : [NSDate date]
      },
      @{
        @"title" : @"Shopping List",
        @"content" : @"- Milk\n- Bread\n- Eggs\n- Coffee",
        @"date" : [NSDate dateWithTimeIntervalSinceNow:-86400]
      },
      @{
        @"title" : @"Project Ideas",
        @"content" : @"1. Build a macOS-like UI\n2. Add more apps\n3. "
                     @"Implement file system",
        @"date" : [NSDate dateWithTimeIntervalSinceNow:-172800]
      }
    ]];
  }
  return self;
}

- (void)showWindow {
  if (self.notesWindow) {
    [self.notesWindow makeKeyAndOrderFront:nil];
    return;
  }

  NSRect frame = NSMakeRect(0, 0, 750, 500);
  self.notesWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.notesWindow setTitle:@"Notes"];
  [self.notesWindow center];

  NSView *contentView = [[NSView alloc] initWithFrame:frame];
  contentView.wantsLayer = YES;
  contentView.layer.backgroundColor = [[NSColor colorWithRed:0.11
                                                       green:0.11
                                                        blue:0.13
                                                       alpha:1.0] CGColor];
  [self.notesWindow setContentView:contentView];

  // Sidebar with visual effect
  NSVisualEffectView *sidebar = [[NSVisualEffectView alloc]
      initWithFrame:NSMakeRect(0, 0, 220, frame.size.height)];
  sidebar.material = NSVisualEffectMaterialSidebar;
  sidebar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  sidebar.state = NSVisualEffectStateActive;
  [contentView addSubview:sidebar];

  // Toolbar with visual effect
  NSVisualEffectView *toolbarView = [[NSVisualEffectView alloc]
      initWithFrame:NSMakeRect(0, frame.size.height - 45, 220, 45)];
  toolbarView.material = NSVisualEffectMaterialTitlebar;
  toolbarView.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  [sidebar addSubview:toolbarView];

  // New note button
  NSButton *newNoteBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(10, 8, 28, 28)];
  newNoteBtn.title = @"+";
  newNoteBtn.font = [NSFont systemFontOfSize:18];
  newNoteBtn.bezelStyle = NSBezelStyleTexturedRounded;
  newNoteBtn.target = self;
  newNoteBtn.action = @selector(createNewNote:);
  [toolbarView addSubview:newNoteBtn];

  // Search field
  NSSearchField *searchField =
      [[NSSearchField alloc] initWithFrame:NSMakeRect(45, 10, 165, 25)];
  searchField.placeholderString = @"Search";
  [toolbarView addSubview:searchField];

  // Notes list
  NSScrollView *notesScroll = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 0, 220, frame.size.height - 45)];
  notesScroll.hasVerticalScroller = YES;
  notesScroll.autohidesScrollers = YES;

  self.notesTable = [[NSTableView alloc] initWithFrame:notesScroll.bounds];
  self.notesTable.dataSource = self;
  self.notesTable.delegate = self;
  self.notesTable.rowHeight = 60;
  self.notesTable.headerView = nil;
  self.notesTable.backgroundColor = [NSColor clearColor];

  NSTableColumn *noteCol = [[NSTableColumn alloc] initWithIdentifier:@"note"];
  noteCol.width = 220;
  [self.notesTable addTableColumn:noteCol];

  notesScroll.documentView = self.notesTable;
  [sidebar addSubview:notesScroll];

  // Note editor area
  NSView *editorArea =
      [[NSView alloc] initWithFrame:NSMakeRect(220, 0, frame.size.width - 220,
                                               frame.size.height)];
  editorArea.wantsLayer = YES;
  editorArea.layer.backgroundColor = [[NSColor colorWithRed:0.14
                                                      green:0.14
                                                       blue:0.16
                                                      alpha:1.0] CGColor];
  [contentView addSubview:editorArea];

  // Note text view
  NSScrollView *textScroll = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(15, 15, editorArea.bounds.size.width - 30,
                               editorArea.bounds.size.height - 30)];
  textScroll.hasVerticalScroller = YES;
  textScroll.autohidesScrollers = YES;
  textScroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  self.noteTextView = [[NSTextView alloc] initWithFrame:textScroll.bounds];
  self.noteTextView.font = [NSFont systemFontOfSize:14];
  self.noteTextView.textContainerInset = NSMakeSize(10, 10);
  self.noteTextView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  textScroll.documentView = self.noteTextView;
  [editorArea addSubview:textScroll];

  // Load first note
  if (self.notes.count > 0) {
    NSDictionary *note = self.notes[0];
    self.noteTextView.string = note[@"content"];
  }

  [self.notesWindow makeKeyAndOrderFront:nil];
}

- (void)createNewNote:(id)sender {
  NSDictionary *newNote =
      @{@"title" : @"New Note", @"content" : @"", @"date" : [NSDate date]};
  [self.notes insertObject:newNote atIndex:0];
  [self.notesTable reloadData];
  [self.notesTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
               byExtendingSelection:NO];
  self.noteTextView.string = @"";
  [self.notesWindow makeFirstResponder:self.noteTextView];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return self.notes.count;
}

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)tableColumn
                   row:(NSInteger)row {
  NSTableCellView *cell =
      [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 220, 60)];

  NSDictionary *note = self.notes[row];

  // Title
  NSTextField *title =
      [[NSTextField alloc] initWithFrame:NSMakeRect(12, 35, 196, 20)];
  title.stringValue = note[@"title"];
  title.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
  title.bezeled = NO;
  title.editable = NO;
  title.drawsBackground = NO;
  [cell addSubview:title];

  // Date
  NSDateFormatter *df = [[NSDateFormatter alloc] init];
  df.dateStyle = NSDateFormatterShortStyle;

  NSTextField *date =
      [[NSTextField alloc] initWithFrame:NSMakeRect(12, 18, 100, 16)];
  date.stringValue = [df stringFromDate:note[@"date"]];
  date.font = [NSFont systemFontOfSize:11];
  date.textColor = [NSColor grayColor];
  date.bezeled = NO;
  date.editable = NO;
  date.drawsBackground = NO;
  [cell addSubview:date];

  // Preview
  NSString *preview =
      [note[@"content"] stringByReplacingOccurrencesOfString:@"\n"
                                                  withString:@" "];
  if (preview.length > 30) {
    preview = [[preview substringToIndex:30] stringByAppendingString:@"..."];
  }

  NSTextField *previewField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(12, 3, 196, 16)];
  previewField.stringValue = preview;
  previewField.font = [NSFont systemFontOfSize:11];
  previewField.textColor = [NSColor darkGrayColor];
  previewField.bezeled = NO;
  previewField.editable = NO;
  previewField.drawsBackground = NO;
  [cell addSubview:previewField];

  return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
  NSInteger row = self.notesTable.selectedRow;
  if (row >= 0 && row < (NSInteger)self.notes.count) {
    self.selectedNote = row;
    NSDictionary *note = self.notes[row];
    self.noteTextView.string = note[@"content"];
  }
}

@end
