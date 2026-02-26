#import "MessagesWindow.h"
#import "../services/NativeSMSEngine.h"

#define MSG_BG [NSColor windowBackgroundColor]
#define MSG_SIDEBAR_BG [NSColor controlBackgroundColor]
#define MSG_BUBBLE_ME [NSColor systemBlueColor]
#define MSG_BUBBLE_THEM [NSColor controlBackgroundColor]
#define MSG_TEXT_ME [NSColor whiteColor]
#define MSG_TEXT_THEM [NSColor labelColor]
#define MSG_BORDER [NSColor separatorColor]

// ─── ChatBubbleView ─────────────────────────────────────────────────────────

@interface ChatBubbleView : NSView
@property(nonatomic, assign) BOOL isMe;
@property(nonatomic, strong) NSString *text;
@property(nonatomic, strong) NSTextField *label;
@end

@implementation ChatBubbleView
- (instancetype)initWithFrame:(NSRect)frameRect
                         isMe:(BOOL)me
                         text:(NSString *)txt {
  if (self = [super initWithFrame:frameRect]) {
    _isMe = me;
    _text = txt;
    self.wantsLayer = YES;

    // Estimate height
    NSTextField *tmp =
        [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 400, 1000)];
    tmp.stringValue = txt;
    tmp.font = [NSFont systemFontOfSize:14];
    tmp.cell.wraps = YES;
    NSSize s = [tmp.cell cellSizeForBounds:NSMakeRect(0, 0, 400, 1000)];

    CGFloat w = s.width + 30;
    CGFloat h = s.height + 20;
    if (w < 50)
      w = 50;

    self.frame = NSMakeRect(me ? (frameRect.size.width - w - 20) : 20, 0, w, h);
    self.layer.cornerRadius = 16;
    self.layer.maskedCorners =
        me ? (kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner |
              kCALayerMaxXMaxYCorner)
           : (kCALayerMaxXMinYCorner | kCALayerMinXMaxYCorner |
              kCALayerMaxXMaxYCorner);
    self.layer.backgroundColor =
        me ? [MSG_BUBBLE_ME CGColor] : [MSG_BUBBLE_THEM CGColor];

    _label =
        [[NSTextField alloc] initWithFrame:NSMakeRect(15, 10, w - 30, h - 20)];
    _label.stringValue = txt;
    _label.font = [NSFont systemFontOfSize:14];
    _label.textColor = me ? MSG_TEXT_ME : MSG_TEXT_THEM;
    _label.drawsBackground = NO;
    _label.bezeled = NO;
    _label.editable = NO;
    _label.cell.wraps = YES;
    [self addSubview:_label];
  }
  return self;
}
@end

// ─── MessagesWindow ─────────────────────────────────────────────────────────

@interface ConversationNode : NSObject
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSString *lastMsg;
@property(nonatomic, strong) NSString *time;
@property(nonatomic, strong) NSImage *avatar;
@property(nonatomic, assign) BOOL unread;
@end
@implementation ConversationNode
@end

@interface MessagesWindow () <NSTableViewDataSource, NSTableViewDelegate,
                              NSTextFieldDelegate>

@property(nonatomic, strong) NSWindow *msgWindow;
@property(nonatomic, strong) NSTableView *sidebarTable;
@property(nonatomic, strong) NSMutableArray<ConversationNode *> *conversations;
@property(nonatomic, assign) NSInteger selectedConvoIndex;

@property(nonatomic, strong) NSScrollView *chatScroll;
@property(nonatomic, strong) NSView *chatDoc;
@property(nonatomic, strong) NSTextField *inputField;
@property(nonatomic, strong) NSTextField *chatTitle;

@property(nonatomic, strong) NSMutableArray<NSDictionary *> *currentMessages;

@end

@implementation MessagesWindow

+ (instancetype)sharedInstance {
  static MessagesWindow *inst;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    inst = [[MessagesWindow alloc] init];
  });
  return inst;
}

- (instancetype)init {
  if (self = [super init]) {
    _conversations = [NSMutableArray array];
    // Mock data
    NSArray *mock = @[
      @{
        @"n" : @"Tim Cook",
        @"m" : @"Good morning! How is the new OS coming along?",
        @"t" : @"9:41 AM",
        @"u" : @YES
      },
      @{
        @"n" : @"Craig Federighi",
        @"m" : @"Hair force one checking in. 💇‍♂️",
        @"t" : @"Yesterday",
        @"u" : @NO
      },
      @{
        @"n" : @"Mom",
        @"m" : @"Please call me later.",
        @"t" : @"Tuesday",
        @"u" : @NO
      },
      @{
        @"n" : @"VirtualOS Team",
        @"m" : @"Build succeeded entirely.",
        @"t" : @"Monday",
        @"u" : @NO
      }
    ];
    for (NSDictionary *d in mock) {
      ConversationNode *node = [[ConversationNode alloc] init];
      node.name = d[@"n"];
      node.lastMsg = d[@"m"];
      node.time = d[@"t"];
      node.unread = [d[@"u"] boolValue];
      [_conversations addObject:node];
    }

    _currentMessages = [NSMutableArray array];
    _selectedConvoIndex = 0;
    [self loadMockMessagesForIndex:0];
  }
  return self;
}

- (void)loadMockMessagesForIndex:(NSInteger)idx {
  [_currentMessages removeAllObjects];
  if (idx == 0) { // Tim
    [_currentMessages addObject:@{
      @"me" : @NO,
      @"text" : @"Hey, checking on the VirtualOS project."
    }];
    [_currentMessages addObject:@{
      @"me" : @YES,
      @"text" :
          @"It's going great. NSVisualEffectViews are implemented everywhere."
    }];
    [_currentMessages
        addObject:@{@"me" : @NO, @"text" : @"Excellent. And the performance?"}];
    [_currentMessages addObject:@{
      @"me" : @YES,
      @"text" : @"Rock solid 60fps across the board."
    }];
    [_currentMessages addObject:@{
      @"me" : @NO,
      @"text" : @"Good morning! How is the new OS coming along?"
    }];
  } else if (idx == 1) { // Craig
    [_currentMessages addObject:@{
      @"me" : @NO,
      @"text" : @"Did you test the new animations?"
    }];
    [_currentMessages addObject:@{
      @"me" : @YES,
      @"text" : @"Yep, core animation pathways are flawless."
    }];
    [_currentMessages addObject:@{
      @"me" : @NO,
      @"text" : @"Hair force one checking in. 💇‍♂️"
    }];
  } else {
    [_currentMessages
        addObject:@{@"me" : @NO, @"text" : _conversations[idx].lastMsg}];
  }
}

- (void)showWindow {
  if (self.msgWindow) {
    [self.msgWindow makeKeyAndOrderFront:nil];
    return;
  }

  NSRect frame = NSMakeRect(200, 200, 900, 600);
  self.msgWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable |
                          NSWindowStyleMaskFullSizeContentView
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.msgWindow setTitle:@"Messages"];
  self.msgWindow.titlebarAppearsTransparent = YES;
  self.msgWindow.minSize = NSMakeSize(600, 400);

  NSView *root = [[NSView alloc] initWithFrame:frame];
  root.wantsLayer = YES;
  root.layer.backgroundColor = [MSG_BG CGColor];
  [self.msgWindow setContentView:root];

  [self buildSidebar:root frame:frame];
  [self buildChatArea:root frame:frame];

  [self.msgWindow makeKeyAndOrderFront:nil];
  [self renderChatHistory];
}

- (void)buildSidebar:(NSView *)root frame:(NSRect)frame {
  CGFloat w = 280;

  NSVisualEffectView *sidebar = [[NSVisualEffectView alloc]
      initWithFrame:NSMakeRect(0, 0, w, frame.size.height)];
  sidebar.material = NSVisualEffectMaterialSidebar;
  sidebar.blendingMode = NSVisualEffectBlendingModeWithinWindow;
  sidebar.state = NSVisualEffectStateFollowsWindowActiveState;
  sidebar.autoresizingMask = NSViewHeightSizable;
  [root addSubview:sidebar];

  NSView *sep =
      [[NSView alloc] initWithFrame:NSMakeRect(w - 1, 0, 1, frame.size.height)];
  sep.wantsLayer = YES;
  sep.layer.backgroundColor = [MSG_BORDER CGColor];
  sep.autoresizingMask = NSViewHeightSizable;
  [sidebar addSubview:sep];

  // Header
  NSTextField *title = [[NSTextField alloc]
      initWithFrame:NSMakeRect(20, frame.size.height - 45, 150, 25)];
  title.stringValue = @"Messages";
  title.font = [NSFont systemFontOfSize:18 weight:NSFontWeightBold];
  title.textColor = [NSColor labelColor];
  title.drawsBackground = NO;
  title.bezeled = NO;
  title.editable = NO;
  title.autoresizingMask = NSViewMinYMargin;
  [sidebar addSubview:title];

  NSSearchField *sf = [[NSSearchField alloc]
      initWithFrame:NSMakeRect(15, frame.size.height - 85, w - 30, 28)];
  sf.placeholderString = @"Search";
  sf.autoresizingMask = NSViewMinYMargin | NSViewWidthSizable;
  [sidebar addSubview:sf];

  // Table
  NSScrollView *scroll = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 0, w - 1, frame.size.height - 95)];
  scroll.hasVerticalScroller = YES;
  scroll.drawsBackground = NO;
  scroll.autoresizingMask = NSViewHeightSizable | NSViewWidthSizable;
  self.sidebarTable = [[NSTableView alloc] initWithFrame:scroll.bounds];
  self.sidebarTable.dataSource = self;
  self.sidebarTable.delegate = self;
  self.sidebarTable.rowHeight = 76;
  self.sidebarTable.headerView = nil;
  self.sidebarTable.backgroundColor = [NSColor clearColor];
  self.sidebarTable.selectionHighlightStyle =
      NSTableViewSelectionHighlightStyleSourceList;
  NSTableColumn *c = [[NSTableColumn alloc] initWithIdentifier:@"c"];
  c.width = w - 1;
  [self.sidebarTable addTableColumn:c];
  scroll.documentView = self.sidebarTable;
  [sidebar addSubview:scroll];
}

- (void)buildChatArea:(NSView *)root frame:(NSRect)frame {
  CGFloat sideW = 280;
  CGFloat w = frame.size.width - sideW;

  NSView *chat =
      [[NSView alloc] initWithFrame:NSMakeRect(sideW, 0, w, frame.size.height)];
  chat.wantsLayer = YES;
  chat.layer.backgroundColor = [MSG_BG CGColor];
  chat.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [root addSubview:chat];

  // Header
  NSVisualEffectView *hdr = [[NSVisualEffectView alloc]
      initWithFrame:NSMakeRect(0, frame.size.height - 70, w, 70)];
  hdr.material = NSVisualEffectMaterialTitlebar;
  hdr.state = NSVisualEffectStateFollowsWindowActiveState;
  hdr.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [chat addSubview:hdr];

  NSView *hsep = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, w, 1)];
  hsep.wantsLayer = YES;
  hsep.layer.backgroundColor = [MSG_BORDER CGColor];
  hsep.autoresizingMask = NSViewWidthSizable;
  [hdr addSubview:hsep];

  self.chatTitle =
      [[NSTextField alloc] initWithFrame:NSMakeRect(30, 20, 300, 25)];
  self.chatTitle.stringValue = self.conversations[self.selectedConvoIndex].name;
  self.chatTitle.font = [NSFont systemFontOfSize:16 weight:NSFontWeightBold];
  self.chatTitle.textColor = [NSColor labelColor];
  self.chatTitle.drawsBackground = NO;
  self.chatTitle.bezeled = NO;
  self.chatTitle.editable = NO;
  [hdr addSubview:self.chatTitle];

  NSButton *facetime =
      [[NSButton alloc] initWithFrame:NSMakeRect(w - 110, 20, 30, 24)];
  facetime.title = @"􀌞";
  facetime.bezelStyle = NSBezelStyleRounded;
  facetime.autoresizingMask = NSViewMinXMargin;
  [hdr addSubview:facetime];
  NSButton *info =
      [[NSButton alloc] initWithFrame:NSMakeRect(w - 70, 20, 30, 24)];
  info.title = @"􀅴";
  info.bezelStyle = NSBezelStyleRounded;
  info.autoresizingMask = NSViewMinXMargin;
  [hdr addSubview:info];

  // Input area
  NSView *inp = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, w, 80)];
  inp.wantsLayer = YES;
  inp.layer.backgroundColor = [MSG_BG CGColor];
  inp.autoresizingMask = NSViewWidthSizable | NSViewMaxYMargin;
  [chat addSubview:inp];

  NSView *isep = [[NSView alloc] initWithFrame:NSMakeRect(0, 79, w, 1)];
  isep.wantsLayer = YES;
  isep.layer.backgroundColor = [MSG_BORDER CGColor];
  isep.autoresizingMask = NSViewWidthSizable;
  [inp addSubview:isep];

  self.inputField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 25, w - 80, 30)];
  self.inputField.placeholderString = @"iMessage";
  self.inputField.font = [NSFont systemFontOfSize:14];
  self.inputField.focusRingType = NSFocusRingTypeNone;
  self.inputField.bezeled = YES;
  self.inputField.bezelStyle = NSTextFieldRoundedBezel;
  self.inputField.delegate = self;
  self.inputField.autoresizingMask = NSViewWidthSizable;
  [inp addSubview:self.inputField];

  // Chat Scroll
  self.chatScroll = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 80, w, frame.size.height - 150)];
  self.chatScroll.hasVerticalScroller = YES;
  self.chatScroll.drawsBackground = NO;
  self.chatScroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [chat addSubview:self.chatScroll];

  self.chatDoc = [[NSView alloc]
      initWithFrame:NSMakeRect(0, 0, w, frame.size.height - 150)];
  self.chatDoc.wantsLayer = YES;
  self.chatDoc.layer.backgroundColor = [MSG_BG CGColor];
  self.chatDoc.autoresizingMask = NSViewWidthSizable;
  self.chatScroll.documentView = self.chatDoc;
}

- (void)renderChatHistory {
  [self.chatDoc.subviews
      makeObjectsPerformSelector:@selector(removeFromSuperview)];
  CGFloat w = self.chatScroll.bounds.size.width;
  CGFloat currentY = 20;

  NSMutableArray *bubbles = [NSMutableArray array];

  for (NSInteger i = self.currentMessages.count - 1; i >= 0; i--) {
    NSDictionary *m = self.currentMessages[i];
    ChatBubbleView *cb =
        [[ChatBubbleView alloc] initWithFrame:NSMakeRect(0, 0, w, 0)
                                         isMe:[m[@"me"] boolValue]
                                         text:m[@"text"]];
    [bubbles addObject:cb];
    currentY += cb.frame.size.height + 15;
  }

  if (currentY < self.chatScroll.bounds.size.height) {
    currentY = self.chatScroll.bounds.size.height;
  }

  [self.chatDoc setFrameSize:NSMakeSize(w, currentY)];

  CGFloat renderY = 20;
  for (ChatBubbleView *cb in bubbles) {
    NSRect f = cb.frame;
    f.origin.y = renderY;
    cb.frame = f;
    [self.chatDoc addSubview:cb];
    renderY += f.size.height + 15;
  }

  [[self.chatScroll documentView] scrollPoint:NSMakePoint(0, 0)];
}

- (void)controlTextDidEndEditing:(NSNotification *)obj {
  if (obj.object == self.inputField) {
    NSString *txt = self.inputField.stringValue;
    if (txt.length == 0)
      return;

    self.inputField.stringValue = @"";
    [self.currentMessages addObject:@{@"me" : @YES, @"text" : txt}];
    ConversationNode *n = self.conversations[self.selectedConvoIndex];
    n.lastMsg = txt;
    n.time = @"Just now";

    [self.sidebarTable reloadData];
    [self renderChatHistory];

    // Simulate reply
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          NSArray *resps = @[
            @"Haha exactly!", @"That sounds completely correct.",
            @"I'll look into it.", @"Sure thing!"
          ];
          [self.currentMessages addObject:@{
            @"me" : @NO,
            @"text" : resps[arc4random_uniform((uint32_t)resps.count)]
          }];
          n.lastMsg = self.currentMessages.lastObject[@"text"];
          [self.sidebarTable reloadData];
          [self renderChatHistory];
        });
  }
}

#pragma mark - Table
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
  return self.conversations.count;
}

- (NSView *)tableView:(NSTableView *)tv
    viewForTableColumn:(NSTableColumn *)tc
                   row:(NSInteger)row {
  ConversationNode *n = self.conversations[row];
  NSView *v = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, tc.width, 76)];

  // Avatar
  NSView *av = [[NSView alloc] initWithFrame:NSMakeRect(15, 13, 50, 50)];
  av.wantsLayer = YES;
  av.layer.cornerRadius = 25;
  av.layer.backgroundColor = [[NSColor systemGrayColor] CGColor];

  NSTextField *ini =
      [[NSTextField alloc] initWithFrame:NSMakeRect(0, 10, 50, 30)];
  ini.stringValue = [n.name substringToIndex:1];
  ini.font = [NSFont systemFontOfSize:22 weight:NSFontWeightMedium];
  ini.textColor = [NSColor whiteColor];
  ini.alignment = NSTextAlignmentCenter;
  ini.drawsBackground = NO;
  ini.bezeled = NO;
  ini.editable = NO;
  [av addSubview:ini];
  [v addSubview:av];

  // Unread dot
  if (n.unread) {
    NSView *dot = [[NSView alloc] initWithFrame:NSMakeRect(5, 33, 10, 10)];
    dot.wantsLayer = YES;
    dot.layer.cornerRadius = 5;
    dot.layer.backgroundColor = [[NSColor systemBlueColor] CGColor];
    [v addSubview:dot];
  }

  NSTextField *nm = [[NSTextField alloc]
      initWithFrame:NSMakeRect(75, 45, tc.width - 140, 20)];
  nm.stringValue = n.name;
  nm.font = [NSFont
      systemFontOfSize:14
                weight:n.unread ? NSFontWeightBold : NSFontWeightMedium];
  nm.textColor = [NSColor labelColor];
  nm.drawsBackground = NO;
  nm.bezeled = NO;
  nm.editable = NO;
  [v addSubview:nm];

  NSTextField *tm =
      [[NSTextField alloc] initWithFrame:NSMakeRect(tc.width - 65, 45, 50, 20)];
  tm.stringValue = n.time;
  tm.font = [NSFont systemFontOfSize:12];
  tm.textColor = [NSColor secondaryLabelColor];
  tm.alignment = NSTextAlignmentRight;
  tm.drawsBackground = NO;
  tm.bezeled = NO;
  tm.editable = NO;
  [v addSubview:tm];

  NSTextField *msg =
      [[NSTextField alloc] initWithFrame:NSMakeRect(75, 10, tc.width - 90, 35)];
  msg.stringValue = n.lastMsg;
  msg.font = [NSFont systemFontOfSize:13];
  msg.textColor =
      n.unread ? [NSColor labelColor] : [NSColor secondaryLabelColor];
  msg.drawsBackground = NO;
  msg.bezeled = NO;
  msg.editable = NO;
  msg.cell.wraps = YES;
  msg.lineBreakMode = NSLineBreakByTruncatingTail;
  [v addSubview:msg];

  // Separator
  NSView *s =
      [[NSView alloc] initWithFrame:NSMakeRect(75, 0, tc.width - 75, 1)];
  s.wantsLayer = YES;
  s.layer.backgroundColor = [MSG_BORDER CGColor];
  [v addSubview:s];

  return v;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
  NSInteger row = self.sidebarTable.selectedRow;
  if (row >= 0 && row < (NSInteger)self.conversations.count) {
    self.selectedConvoIndex = row;
    self.conversations[row].unread = NO;
    self.chatTitle.stringValue = self.conversations[row].name;
    [self loadMockMessagesForIndex:row];
    [self renderChatHistory];
    [self.sidebarTable
        reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                  columnIndexes:[NSIndexSet indexSetWithIndex:0]];
  }
}

@end
