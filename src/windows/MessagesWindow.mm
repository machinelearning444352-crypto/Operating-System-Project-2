#import "MessagesWindow.h"
#import "../services/NativeSMSEngine.h"
#import "SMSConfigWindow.h"

// ============================================================================
// ENTERPRISE MESSAGES WINDOW — Premium Dark Theme
// ============================================================================

// Color palette — native macOS system colors
#define MSG_BG_DARK [NSColor windowBackgroundColor]
#define MSG_SIDEBAR_BG [NSColor controlBackgroundColor]
#define MSG_HEADER_BG [NSColor windowBackgroundColor]
#define MSG_INPUT_BG [NSColor textBackgroundColor]
#define MSG_CARD_BG [NSColor controlBackgroundColor]
#define MSG_ACCENT [NSColor systemBlueColor]
#define MSG_ACCENT2 [NSColor systemIndigoColor]
#define MSG_GREEN [NSColor systemGreenColor]
#define MSG_RED [NSColor systemRedColor]
#define MSG_ORANGE [NSColor systemOrangeColor]
#define MSG_TEXT_PRI [NSColor labelColor]
#define MSG_TEXT_SEC [NSColor secondaryLabelColor]
#define MSG_TEXT_TER [NSColor tertiaryLabelColor]
#define MSG_DIVIDER [NSColor separatorColor]
#define MSG_BUBBLE_ME [NSColor systemBlueColor]
#define MSG_BUBBLE_OTHER [NSColor controlBackgroundColor]
#define MSG_HOVER_BG [NSColor selectedContentBackgroundColor]

static NSArray *_carrierNames = nil;
static NSArray *_carrierEmojis = nil;

@interface MessagesWindow ()
@property(nonatomic, strong) NSWindow *messagesWindow;
@property(nonatomic, strong) NSWindow *addContactWindow;
@property(nonatomic, strong) NSWindow *contactDetailWindow;
@property(nonatomic, strong) NSTableView *contactsTable;
@property(nonatomic, strong) NSScrollView *chatScrollView;
@property(nonatomic, strong) NSView *chatContainer;
@property(nonatomic, strong) NSTextField *messageField;
@property(nonatomic, strong) NSTextField *chatTitleField;
@property(nonatomic, strong) NSTextField *chatSubtitleField;
@property(nonatomic, strong) NSTextField *addNameField;
@property(nonatomic, strong) NSTextField *addPhoneField;
@property(nonatomic, strong) NSPopUpButton *addCarrierPicker;
@property(nonatomic, strong) NSSearchField *searchField;
@property(nonatomic, strong) NSTextField *charCountLabel;
@property(nonatomic, strong) NSTextField *emptyStateLabel;
@property(nonatomic, strong) NSView *typingIndicator;
@property(nonatomic, strong) NSTextField *unreadBadge;
@property(nonatomic, strong) NSMutableArray *contacts;
@property(nonatomic, strong) NSMutableArray *filteredContacts;
@property(nonatomic, strong) NSMutableDictionary *conversations;
@property(nonatomic, strong) NSMutableArray *currentMessages;
@property(nonatomic, strong) NSMutableDictionary *unreadCounts;
@property(nonatomic, assign) NSInteger selectedContact;
@property(nonatomic, assign) BOOL isSearching;
@property(nonatomic, strong) NSView *sidebarView;
@property(nonatomic, strong) NSView *chatAreaView;
@property(nonatomic, strong) NSView *chatHeaderView;
@property(nonatomic, strong) NSView *inputAreaView;
@end

@implementation MessagesWindow

+ (void)initialize {
  if (self == [MessagesWindow class]) {
    _carrierNames = @[
      @"AT&T", @"Verizon", @"T-Mobile", @"Sprint", @"Boost Mobile", @"Cricket",
      @"US Cellular"
    ];
    _carrierEmojis = @[ @"📶", @"📡", @"🔗", @"⚡", @"🚀", @"🏏", @"🗼" ];
  }
}

+ (instancetype)sharedInstance {
  static MessagesWindow *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[MessagesWindow alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _selectedContact = -1;
    _contacts = [NSMutableArray array];
    _filteredContacts = [NSMutableArray array];
    _conversations = [NSMutableDictionary dictionary];
    _currentMessages = [NSMutableArray array];
    _unreadCounts = [NSMutableDictionary dictionary];
    _isSearching = NO;
    [self loadContacts];
  }
  return self;
}

#pragma mark - Persistence

- (NSString *)appDataPath {
  NSString *appSupport = [NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
  NSString *folder =
      [appSupport stringByAppendingPathComponent:@"macOSDesktop"];
  [[NSFileManager defaultManager] createDirectoryAtPath:folder
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  return folder;
}

- (NSString *)contactsFilePath {
  return [[self appDataPath] stringByAppendingPathComponent:@"contacts.plist"];
}
- (NSString *)conversationsFilePath {
  return [[self appDataPath]
      stringByAppendingPathComponent:@"conversations.plist"];
}

- (void)loadContacts {
  NSArray *saved = [NSArray arrayWithContentsOfFile:[self contactsFilePath]];
  if (saved)
    [self.contacts addObjectsFromArray:saved];
  NSDictionary *savedConv =
      [NSDictionary dictionaryWithContentsOfFile:[self conversationsFilePath]];
  if (savedConv)
    [self.conversations addEntriesFromDictionary:savedConv];
  [self.filteredContacts setArray:self.contacts];
}

- (void)saveContacts {
  [self.contacts writeToFile:[self contactsFilePath] atomically:YES];
  [self.conversations writeToFile:[self conversationsFilePath] atomically:YES];
}

#pragma mark - Helpers

- (NSString *)carrierNameForType:(NSInteger)type {
  if (type >= 0 && type < (NSInteger)_carrierNames.count)
    return _carrierNames[type];
  return @"AT&T";
}

- (NSString *)carrierEmojiForType:(NSInteger)type {
  if (type >= 0 && type < (NSInteger)_carrierEmojis.count)
    return _carrierEmojis[type];
  return @"📶";
}

- (NSColor *)avatarColorForName:(NSString *)name {
  NSUInteger hash = [name hash];
  CGFloat hue = (hash % 360) / 360.0;
  return [NSColor colorWithHue:hue saturation:0.55 brightness:0.85 alpha:1.0];
}

- (NSString *)initialsForName:(NSString *)name {
  NSArray *parts = [name componentsSeparatedByString:@" "];
  if (parts.count >= 2)
    return [NSString stringWithFormat:@"%@%@", [parts[0] substringToIndex:1],
                                      [parts[1] substringToIndex:1]];
  return parts.count > 0
             ? [[parts[0]
                   substringToIndex:MIN(2, ((NSString *)parts[0]).length)]
                   uppercaseString]
             : @"?";
}

- (NSString *)relativeTimeForDate:(NSString *)timeStr {
  return timeStr ?: @"";
}

- (NSArray *)displayContacts {
  return self.isSearching ? self.filteredContacts : self.contacts;
}

#pragma mark - Main Window

- (void)showWindow {
  if (self.messagesWindow) {
    [self.messagesWindow makeKeyAndOrderFront:nil];
    return;
  }

  NSRect frame = NSMakeRect(0, 0, 960, 640);
  self.messagesWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.messagesWindow.title = @"Messages";
  self.messagesWindow.minSize = NSMakeSize(700, 450);
  [self.messagesWindow center];

  NSView *root = self.messagesWindow.contentView;
  root.wantsLayer = YES;
  root.layer.backgroundColor = [MSG_BG_DARK CGColor];

  [self buildSidebar:root frame:frame];
  [self buildChatArea:root frame:frame];
  [self.messagesWindow makeKeyAndOrderFront:nil];
}

#pragma mark - Sidebar

- (void)buildSidebar:(NSView *)root frame:(NSRect)frame {
  CGFloat sideW = 300;
  self.sidebarView =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, sideW, frame.size.height)];
  self.sidebarView.wantsLayer = YES;
  self.sidebarView.layer.backgroundColor = [MSG_SIDEBAR_BG CGColor];
  [root addSubview:self.sidebarView];

  // Divider line
  NSView *div = [[NSView alloc]
      initWithFrame:NSMakeRect(sideW - 1, 0, 1, frame.size.height)];
  div.wantsLayer = YES;
  div.layer.backgroundColor = [MSG_DIVIDER CGColor];
  [root addSubview:div];

  // Header
  NSView *sideHeader = [[NSView alloc]
      initWithFrame:NSMakeRect(0, frame.size.height - 60, sideW, 60)];
  sideHeader.wantsLayer = YES;
  sideHeader.layer.backgroundColor = [MSG_HEADER_BG CGColor];
  [self.sidebarView addSubview:sideHeader];

  NSTextField *title = [self labelWithFrame:NSMakeRect(18, 18, 160, 28)
                                       text:@"Messages"
                                       font:[NSFont boldSystemFontOfSize:22]
                                      color:MSG_TEXT_PRI];
  [sideHeader addSubview:title];

  NSButton *newBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(sideW - 80, 18, 30, 28)];
  newBtn.title = @"✏️";
  newBtn.bordered = NO;
  newBtn.font = [NSFont systemFontOfSize:18];
  newBtn.target = self;
  newBtn.action = @selector(newConversation:);
  [sideHeader addSubview:newBtn];

  NSButton *cfgBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(sideW - 45, 18, 30, 28)];
  cfgBtn.title = @"⚙️";
  cfgBtn.bordered = NO;
  cfgBtn.font = [NSFont systemFontOfSize:18];
  cfgBtn.target = self;
  cfgBtn.action = @selector(showSMSConfig:);
  [sideHeader addSubview:cfgBtn];

  // Search
  self.searchField = [[NSSearchField alloc]
      initWithFrame:NSMakeRect(12, frame.size.height - 98, sideW - 24, 28)];
  self.searchField.placeholderString = @"Search contacts...";
  self.searchField.font = [NSFont systemFontOfSize:13];
  self.searchField.target = self;
  self.searchField.action = @selector(searchChanged:);
  [self.sidebarView addSubview:self.searchField];

  // Contacts table
  NSScrollView *scroll = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 52, sideW, frame.size.height - 160)];
  scroll.hasVerticalScroller = YES;
  scroll.autohidesScrollers = YES;
  scroll.drawsBackground = NO;

  self.contactsTable = [[NSTableView alloc] initWithFrame:scroll.bounds];
  self.contactsTable.dataSource = self;
  self.contactsTable.delegate = self;
  self.contactsTable.rowHeight = 72;
  self.contactsTable.headerView = nil;
  self.contactsTable.backgroundColor = [NSColor clearColor];
  self.contactsTable.selectionHighlightStyle =
      NSTableViewSelectionHighlightStyleNone;

  NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:@"contact"];
  col.width = sideW;
  [self.contactsTable addTableColumn:col];
  scroll.documentView = self.contactsTable;
  [self.sidebarView addSubview:scroll];

  // Add contact button
  NSButton *addBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(12, 10, sideW - 24, 34)];
  addBtn.title = @"＋ Add Contact";
  addBtn.bezelStyle = NSBezelStyleRounded;
  addBtn.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
  addBtn.target = self;
  addBtn.action = @selector(addContact:);
  [self.sidebarView addSubview:addBtn];
}

#pragma mark - Chat Area

- (void)buildChatArea:(NSView *)root frame:(NSRect)frame {
  CGFloat sideW = 300;
  CGFloat chatW = frame.size.width - sideW;

  self.chatAreaView = [[NSView alloc]
      initWithFrame:NSMakeRect(sideW, 0, chatW, frame.size.height)];
  self.chatAreaView.wantsLayer = YES;
  self.chatAreaView.layer.backgroundColor = [MSG_BG_DARK CGColor];
  [root addSubview:self.chatAreaView];

  // Chat Header
  self.chatHeaderView = [[NSView alloc]
      initWithFrame:NSMakeRect(0, frame.size.height - 70, chatW, 70)];
  self.chatHeaderView.wantsLayer = YES;
  self.chatHeaderView.layer.backgroundColor = [MSG_HEADER_BG CGColor];
  [self.chatAreaView addSubview:self.chatHeaderView];

  // Bottom border on header
  NSView *hBorder = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, chatW, 1)];
  hBorder.wantsLayer = YES;
  hBorder.layer.backgroundColor = [MSG_DIVIDER CGColor];
  [self.chatHeaderView addSubview:hBorder];

  self.chatTitleField = [self labelWithFrame:NSMakeRect(18, 28, chatW - 200, 26)
                                        text:@"Select a conversation"
                                        font:[NSFont boldSystemFontOfSize:17]
                                       color:MSG_TEXT_PRI];
  [self.chatHeaderView addSubview:self.chatTitleField];

  self.chatSubtitleField =
      [self labelWithFrame:NSMakeRect(18, 8, chatW - 200, 18)
                      text:@""
                      font:[NSFont systemFontOfSize:12]
                     color:MSG_TEXT_SEC];
  [self.chatHeaderView addSubview:self.chatSubtitleField];

  // Chat scroll view
  self.chatScrollView = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 65, chatW, frame.size.height - 135)];
  self.chatScrollView.hasVerticalScroller = YES;
  self.chatScrollView.autohidesScrollers = YES;
  self.chatScrollView.drawsBackground = NO;

  self.chatContainer = [[NSView alloc]
      initWithFrame:NSMakeRect(0, 0, chatW, frame.size.height - 135)];
  self.chatContainer.wantsLayer = YES;
  self.chatContainer.layer.backgroundColor = [MSG_BG_DARK CGColor];
  self.chatScrollView.documentView = self.chatContainer;
  [self.chatAreaView addSubview:self.chatScrollView];

  // Empty state
  [self buildEmptyState:chatW height:frame.size.height - 135];

  // Input area
  [self buildInputArea:chatW];

  [self layoutMessages];
}

- (void)buildEmptyState:(CGFloat)width height:(CGFloat)height {
  self.emptyStateLabel =
      [self labelWithFrame:NSMakeRect(0, height / 2 - 40, width, 80)
                      text:@"💬\nSelect a conversation\nor add a new contact"
                      font:[NSFont systemFontOfSize:16]
                     color:MSG_TEXT_TER];
  self.emptyStateLabel.alignment = NSTextAlignmentCenter;
  self.emptyStateLabel.maximumNumberOfLines = 4;
  [self.chatContainer addSubview:self.emptyStateLabel];
}

- (void)buildInputArea:(CGFloat)chatW {
  self.inputAreaView =
      [[NSView alloc] initWithFrame:NSMakeRect(0, 0, chatW, 65)];
  self.inputAreaView.wantsLayer = YES;
  self.inputAreaView.layer.backgroundColor = [MSG_INPUT_BG CGColor];
  [self.chatAreaView addSubview:self.inputAreaView];

  // Top border
  NSView *border = [[NSView alloc] initWithFrame:NSMakeRect(0, 64, chatW, 1)];
  border.wantsLayer = YES;
  border.layer.backgroundColor = [MSG_DIVIDER CGColor];
  [self.inputAreaView addSubview:border];

  self.messageField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(18, 16, chatW - 110, 34)];
  self.messageField.placeholderString = @"Type a message...";
  self.messageField.bezeled = YES;
  self.messageField.bezelStyle = NSTextFieldRoundedBezel;
  self.messageField.editable = YES;
  self.messageField.font = [NSFont systemFontOfSize:14];
  self.messageField.target = self;
  self.messageField.action = @selector(sendButtonClicked:);
  [self.inputAreaView addSubview:self.messageField];

  // Character count
  self.charCountLabel = [self labelWithFrame:NSMakeRect(chatW - 170, 2, 60, 14)
                                        text:@""
                                        font:[NSFont systemFontOfSize:10]
                                       color:MSG_TEXT_TER];
  self.charCountLabel.alignment = NSTextAlignmentRight;
  [self.inputAreaView addSubview:self.charCountLabel];

  // Send button
  NSButton *sendBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(chatW - 82, 18, 65, 32)];
  sendBtn.title = @"Send ➤";
  sendBtn.bezelStyle = NSBezelStyleRounded;
  sendBtn.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
  sendBtn.target = self;
  sendBtn.action = @selector(sendButtonClicked:);
  sendBtn.keyEquivalent = @"\r";
  [self.inputAreaView addSubview:sendBtn];
}

#pragma mark - Helper: Label Factory

- (NSTextField *)labelWithFrame:(NSRect)frame
                           text:(NSString *)text
                           font:(NSFont *)font
                          color:(NSColor *)color {
  NSTextField *label = [[NSTextField alloc] initWithFrame:frame];
  label.stringValue = text;
  label.font = font;
  label.textColor = color;
  label.bezeled = NO;
  label.editable = NO;
  label.drawsBackground = NO;
  return label;
}

#pragma mark - Search

- (void)searchChanged:(id)sender {
  NSString *query = self.searchField.stringValue;
  if (query.length == 0) {
    self.isSearching = NO;
    [self.filteredContacts setArray:self.contacts];
  } else {
    self.isSearching = YES;
    [self.filteredContacts removeAllObjects];
    for (NSDictionary *c in self.contacts) {
      NSString *name = c[@"name"] ?: @"";
      NSString *phone = c[@"phone"] ?: @"";
      if ([name localizedCaseInsensitiveContainsString:query] ||
          [phone localizedCaseInsensitiveContainsString:query]) {
        [self.filteredContacts addObject:c];
      }
    }
  }
  [self.contactsTable reloadData];
}

#pragma mark - Add Contact

- (void)addContact:(id)sender {
  self.addContactWindow = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(0, 0, 420, 340)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.addContactWindow.title = @"Add Contact";
  [self.addContactWindow center];

  NSView *content = self.addContactWindow.contentView;
  content.wantsLayer = YES;
  content.layer.backgroundColor = [MSG_BG_DARK CGColor];

  // Header
  NSView *hdr = [[NSView alloc] initWithFrame:NSMakeRect(0, 275, 420, 65)];
  hdr.wantsLayer = YES;
  hdr.layer.backgroundColor = [MSG_HEADER_BG CGColor];
  [content addSubview:hdr];

  [hdr addSubview:[self labelWithFrame:NSMakeRect(18, 25, 380, 28)
                                  text:@"👤 New Contact"
                                  font:[NSFont boldSystemFontOfSize:20]
                                 color:MSG_TEXT_PRI]];
  [hdr
      addSubview:
          [self labelWithFrame:NSMakeRect(18, 6, 380, 18)
                          text:@"Enter contact details and select their carrier"
                          font:[NSFont systemFontOfSize:12]
                         color:MSG_TEXT_SEC]];

  CGFloat y = 220;

  [content
      addSubview:[self
                     labelWithFrame:NSMakeRect(20, y, 80, 22)
                               text:@"Name:"
                               font:[NSFont systemFontOfSize:13
                                                      weight:NSFontWeightMedium]
                              color:MSG_TEXT_PRI]];
  self.addNameField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(110, y - 2, 290, 26)];
  self.addNameField.placeholderString = @"John Doe";
  [content addSubview:self.addNameField];

  y -= 45;

  [content
      addSubview:[self
                     labelWithFrame:NSMakeRect(20, y, 80, 22)
                               text:@"Phone:"
                               font:[NSFont systemFontOfSize:13
                                                      weight:NSFontWeightMedium]
                              color:MSG_TEXT_PRI]];
  self.addPhoneField =
      [[NSTextField alloc] initWithFrame:NSMakeRect(110, y - 2, 290, 26)];
  self.addPhoneField.placeholderString = @"+1 (555) 123-4567";
  [content addSubview:self.addPhoneField];

  y -= 45;

  [content
      addSubview:[self
                     labelWithFrame:NSMakeRect(20, y, 80, 22)
                               text:@"Carrier:"
                               font:[NSFont systemFontOfSize:13
                                                      weight:NSFontWeightMedium]
                              color:MSG_TEXT_PRI]];
  self.addCarrierPicker =
      [[NSPopUpButton alloc] initWithFrame:NSMakeRect(110, y - 2, 290, 26)
                                 pullsDown:NO];
  for (NSInteger i = 0; i < (NSInteger)_carrierNames.count; i++) {
    [self.addCarrierPicker
        addItemWithTitle:[NSString stringWithFormat:@"%@ %@", _carrierEmojis[i],
                                                    _carrierNames[i]]];
  }
  [content addSubview:self.addCarrierPicker];

  y -= 50;

  // Info box
  NSView *info = [[NSView alloc] initWithFrame:NSMakeRect(20, y - 20, 380, 45)];
  info.wantsLayer = YES;
  info.layer.backgroundColor = [[NSColor colorWithRed:0.12
                                                green:0.15
                                                 blue:0.22
                                                alpha:1.0] CGColor];
  info.layer.cornerRadius = 8;
  [content addSubview:info];
  [info addSubview:[self labelWithFrame:NSMakeRect(12, 5, 356, 35)
                                   text:@"💡 Select the correct carrier for "
                                        @"SMS delivery.\nMessages route "
                                        @"through carrier email gateways."
                                   font:[NSFont systemFontOfSize:11]
                                  color:MSG_TEXT_SEC]];

  // Buttons
  NSButton *cancelBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(200, 12, 100, 32)];
  cancelBtn.title = @"Cancel";
  cancelBtn.bezelStyle = NSBezelStyleRounded;
  cancelBtn.target = self;
  cancelBtn.action = @selector(cancelAddContact:);
  [content addSubview:cancelBtn];

  NSButton *saveBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(310, 12, 100, 32)];
  saveBtn.title = @"Add Contact";
  saveBtn.bezelStyle = NSBezelStyleRounded;
  saveBtn.keyEquivalent = @"\r";
  saveBtn.target = self;
  saveBtn.action = @selector(saveNewContact:);
  [content addSubview:saveBtn];

  [self.addContactWindow makeKeyAndOrderFront:nil];
}

- (void)cancelAddContact:(id)sender {
  [self.addContactWindow close];
  self.addContactWindow = nil;
}

- (void)saveNewContact:(NSButton *)sender {
  if (!self.addNameField || !self.addPhoneField)
    return;
  NSString *name = [self.addNameField.stringValue copy];
  NSString *phone = [self.addPhoneField.stringValue copy];
  if (!name || name.length == 0 || !phone || phone.length == 0) {
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText = @"Missing Information";
    a.informativeText = @"Please enter both name and phone number.";
    [a runModal];
    return;
  }
  NSInteger carrierIdx =
      self.addCarrierPicker ? self.addCarrierPicker.indexOfSelectedItem : 0;
  NSDictionary *contact = @{
    @"name" : name,
    @"phone" : phone,
    @"avatar" : [self initialsForName:name],
    @"carrier" : @(carrierIdx),
    @"status" : @"available"
  };
  [self.contacts addObject:contact];
  [self.filteredContacts setArray:self.contacts];
  [self saveContacts];
  [self.contactsTable reloadData];

  if (self.addContactWindow) {
    NSWindow *win = self.addContactWindow;
    self.addContactWindow = nil;
    dispatch_async(dispatch_get_main_queue(), ^{
      [win close];
    });
  }
}

#pragma mark - Contact Detail Panel

- (void)showContactDetail:(NSDictionary *)contact {
  if (self.contactDetailWindow) {
    [self.contactDetailWindow close];
    self.contactDetailWindow = nil;
  }

  self.contactDetailWindow = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(0, 0, 320, 400)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.contactDetailWindow.title = @"Contact Info";
  [self.contactDetailWindow center];

  NSView *v = self.contactDetailWindow.contentView;
  v.wantsLayer = YES;
  v.layer.backgroundColor = [MSG_BG_DARK CGColor];

  NSString *name = contact[@"name"] ?: @"Unknown";
  NSString *phone = contact[@"phone"] ?: @"N/A";
  NSInteger carrier = [contact[@"carrier"] integerValue];
  NSString *initials = [self initialsForName:name];
  NSColor *avColor = [self avatarColorForName:name];

  // Avatar circle
  NSView *avCircle =
      [[NSView alloc] initWithFrame:NSMakeRect(110, 300, 100, 100)];
  avCircle.wantsLayer = YES;
  avCircle.layer.backgroundColor = [avColor CGColor];
  avCircle.layer.cornerRadius = 50;
  [v addSubview:avCircle];

  NSTextField *avLabel = [self labelWithFrame:NSMakeRect(0, 25, 100, 45)
                                         text:initials
                                         font:[NSFont boldSystemFontOfSize:36]
                                        color:MSG_TEXT_PRI];
  avLabel.alignment = NSTextAlignmentCenter;
  [avCircle addSubview:avLabel];

  [v addSubview:[self labelWithFrame:NSMakeRect(20, 265, 280, 28)
                                text:name
                                font:[NSFont boldSystemFontOfSize:22]
                               color:MSG_TEXT_PRI]];

  [v addSubview:[self labelWithFrame:NSMakeRect(20, 240, 280, 22)
                                text:phone
                                font:[NSFont systemFontOfSize:15]
                               color:MSG_TEXT_SEC]];

  [v addSubview:[self labelWithFrame:NSMakeRect(20, 215, 280, 22)
                                text:[NSString
                                         stringWithFormat:
                                             @"%@ %@",
                                             [self carrierEmojiForType:carrier],
                                             [self carrierNameForType:carrier]]
                                font:[NSFont systemFontOfSize:14]
                               color:MSG_ACCENT2]];

  // Stats
  NSString *contactId = contact[@"phone"];
  NSArray *msgs = self.conversations[contactId];
  NSInteger msgCount = msgs ? msgs.count : 0;

  NSView *statsCard =
      [[NSView alloc] initWithFrame:NSMakeRect(20, 130, 280, 70)];
  statsCard.wantsLayer = YES;
  statsCard.layer.backgroundColor = [MSG_CARD_BG CGColor];
  statsCard.layer.cornerRadius = 10;
  [v addSubview:statsCard];

  [statsCard addSubview:[self labelWithFrame:NSMakeRect(15, 38, 120, 22)
                                        text:@"Messages"
                                        font:[NSFont systemFontOfSize:12]
                                       color:MSG_TEXT_SEC]];
  [statsCard
      addSubview:[self labelWithFrame:NSMakeRect(15, 12, 120, 28)
                                 text:[NSString stringWithFormat:@"%ld",
                                                                 (long)msgCount]
                                 font:[NSFont boldSystemFontOfSize:24]
                                color:MSG_TEXT_PRI]];

  [statsCard addSubview:[self labelWithFrame:NSMakeRect(150, 38, 120, 22)
                                        text:@"Carrier"
                                        font:[NSFont systemFontOfSize:12]
                                       color:MSG_TEXT_SEC]];
  [statsCard addSubview:[self labelWithFrame:NSMakeRect(150, 12, 120, 28)
                                        text:[self carrierNameForType:carrier]
                                        font:[NSFont boldSystemFontOfSize:18]
                                       color:MSG_ACCENT]];

  // Delete button
  NSButton *delBtn =
      [[NSButton alloc] initWithFrame:NSMakeRect(60, 20, 200, 32)];
  delBtn.title = @"🗑 Delete Contact";
  delBtn.bezelStyle = NSBezelStyleRounded;
  delBtn.target = self;
  delBtn.action = @selector(deleteSelectedContact:);
  [v addSubview:delBtn];

  [self.contactDetailWindow makeKeyAndOrderFront:nil];
}

- (void)deleteSelectedContact:(id)sender {
  if (self.selectedContact < 0 ||
      self.selectedContact >= (NSInteger)[self displayContacts].count)
    return;

  NSDictionary *contact = [self displayContacts][self.selectedContact];
  NSString *cId = contact[@"phone"];

  [self.contacts removeObject:contact];
  [self.filteredContacts setArray:self.contacts];
  if (cId)
    [self.conversations removeObjectForKey:cId];

  [self.currentMessages removeAllObjects];
  self.selectedContact = -1;
  self.chatTitleField.stringValue = @"Select a conversation";
  self.chatSubtitleField.stringValue = @"";

  [self saveContacts];
  [self.contactsTable reloadData];
  [self layoutMessages];

  if (self.contactDetailWindow) {
    [self.contactDetailWindow close];
    self.contactDetailWindow = nil;
  }
}

#pragma mark - New Conversation

- (void)newConversation:(id)sender {
  if (self.contacts.count == 0) {
    [self addContact:sender];
    return;
  }
  [self.contactsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:0]
                  byExtendingSelection:NO];
  [self.messagesWindow makeFirstResponder:self.messageField];
}

#pragma mark - Layout Messages

- (void)layoutMessages {
  if (!self.chatContainer || !self.chatScrollView)
    return;

  for (NSView *sub in [self.chatContainer.subviews copy])
    [sub removeFromSuperview];

  // Show empty state if no messages
  if (self.currentMessages.count == 0 || self.selectedContact < 0) {
    CGFloat w = self.chatContainer.bounds.size.width;
    CGFloat h = MAX(self.chatScrollView.bounds.size.height, 200);
    [self.chatContainer setFrameSize:NSMakeSize(w, h)];
    self.emptyStateLabel =
        [self labelWithFrame:NSMakeRect(0, h / 2 - 40, w, 80)
                        text:self.selectedContact < 0
                                 ? @"💬\nSelect a conversation"
                                 : @"📝\nNo messages yet\nSay hello!"
                        font:[NSFont systemFontOfSize:16]
                       color:MSG_TEXT_TER];
    self.emptyStateLabel.alignment = NSTextAlignmentCenter;
    self.emptyStateLabel.maximumNumberOfLines = 4;
    [self.chatContainer addSubview:self.emptyStateLabel];
    return;
  }

  CGFloat maxBubbleW = MAX(self.chatContainer.bounds.size.width * 0.65, 200);
  CGFloat minBubbleW = 80;
  CGFloat containerH = MAX(self.chatScrollView.bounds.size.height, 100);
  NSFont *msgFont = [NSFont systemFontOfSize:14];
  NSDictionary *attrs = @{NSFontAttributeName : msgFont};

  // Calculate total height
  CGFloat totalH = 25;
  NSMutableArray *heights = [NSMutableArray array];
  for (NSDictionary *msg in self.currentMessages) {
    NSString *text = msg[@"text"];
    if (!text) {
      [heights addObject:@0];
      continue;
    }
    NSRect r =
        [text boundingRectWithSize:NSMakeSize(maxBubbleW - 30, CGFLOAT_MAX)
                           options:NSStringDrawingUsesLineFragmentOrigin |
                                   NSStringDrawingUsesFontLeading
                        attributes:attrs];
    CGFloat bh = MAX(r.size.height + 24, 38);
    [heights addObject:@(bh)];
    totalH += bh + 30;
  }

  CGFloat newH = MAX(totalH, containerH);
  [self.chatContainer
      setFrameSize:NSMakeSize(self.chatContainer.bounds.size.width, newH)];
  CGFloat yPos = newH - 25;

  for (NSInteger i = 0; i < (NSInteger)self.currentMessages.count; i++) {
    NSDictionary *msg = self.currentMessages[i];
    BOOL isMe = [msg[@"sender"] isEqualToString:@"me"];
    NSString *text = msg[@"text"];
    if (!text)
      continue;
    CGFloat bh = [heights[i] floatValue];
    if (bh == 0)
      continue;

    NSRect r =
        [text boundingRectWithSize:NSMakeSize(maxBubbleW - 30, CGFLOAT_MAX)
                           options:NSStringDrawingUsesLineFragmentOrigin |
                                   NSStringDrawingUsesFontLeading
                        attributes:attrs];
    CGFloat bw = MAX(MIN(r.size.width + 34, maxBubbleW), minBubbleW);
    yPos -= bh;
    CGFloat xPos = isMe ? (self.chatContainer.bounds.size.width - bw - 20) : 20;

    // Bubble
    NSView *bubble =
        [[NSView alloc] initWithFrame:NSMakeRect(xPos, yPos, bw, bh)];
    bubble.wantsLayer = YES;
    bubble.layer.cornerRadius = 18;
    bubble.layer.backgroundColor =
        isMe ? [MSG_BUBBLE_ME CGColor] : [MSG_BUBBLE_OTHER CGColor];
    bubble.layer.shadowColor = [[NSColor blackColor] CGColor];
    bubble.layer.shadowOpacity = 0.15;
    bubble.layer.shadowOffset = CGSizeMake(0, -1);
    bubble.layer.shadowRadius = 4;
    [self.chatContainer addSubview:bubble];

    // Text
    NSTextField *label = [[NSTextField alloc]
        initWithFrame:NSMakeRect(15, 10, bw - 30, bh - 20)];
    label.stringValue = text;
    label.font = msgFont;
    label.textColor = isMe ? [NSColor whiteColor] : MSG_TEXT_PRI;
    label.bezeled = NO;
    label.editable = NO;
    label.selectable = YES;
    label.drawsBackground = NO;
    label.lineBreakMode = NSLineBreakByWordWrapping;
    label.maximumNumberOfLines = 0;
    label.cell.wraps = YES;
    label.cell.scrollable = NO;
    [bubble addSubview:label];

    // Time + status
    NSString *timeStr = msg[@"time"] ?: @"";
    if (isMe) {
      NSString *status = msg[@"deliveryStatus"] ?: @"";
      if ([status isEqualToString:@"sent"])
        timeStr = [timeStr stringByAppendingString:@" ✓"];
      else if ([status isEqualToString:@"delivered"])
        timeStr = [timeStr stringByAppendingString:@" ✓✓"];
      else if ([status isEqualToString:@"failed"])
        timeStr = [timeStr stringByAppendingString:@" ✗"];
    }
    NSTextField *timeLabel =
        [self labelWithFrame:NSMakeRect(xPos, yPos - 17, bw, 14)
                        text:timeStr
                        font:[NSFont systemFontOfSize:10]
                       color:MSG_TEXT_TER];
    timeLabel.alignment = isMe ? NSTextAlignmentRight : NSTextAlignmentLeft;
    [self.chatContainer addSubview:timeLabel];

    yPos -= 30;
  }

  if (self.currentMessages.count > 0) {
    [self.chatScrollView.documentView scrollPoint:NSMakePoint(0, 0)];
  }
}

#pragma mark - Send Message

- (void)sendButtonClicked:(id)sender {
  [self doSendMessage];
}

- (void)doSendMessage {
  if (!self.messageField)
    return;
  [self.messagesWindow makeFirstResponder:nil];
  NSString *text = [[self.messageField.stringValue copy]
      stringByTrimmingCharactersInSet:[NSCharacterSet
                                          whitespaceAndNewlineCharacterSet]];
  if (!text || text.length == 0)
    return;

  NSArray *display = [self displayContacts];
  if (self.selectedContact < 0 ||
      self.selectedContact >= (NSInteger)display.count) {
    NSAlert *a = [[NSAlert alloc] init];
    a.messageText = @"No Conversation Selected";
    a.informativeText = @"Please select a contact from the list first.";
    [a runModal];
    return;
  }

  self.messageField.stringValue = @"";
  self.charCountLabel.stringValue = @"";

  NSDateFormatter *df = [[NSDateFormatter alloc] init];
  df.dateFormat = @"h:mm a";
  NSString *time = [df stringFromDate:[NSDate date]];

  NSDictionary *newMsg = @{
    @"sender" : @"me",
    @"text" : text,
    @"time" : time,
    @"deliveryStatus" : @"sending"
  };
  [self.currentMessages addObject:newMsg];

  NSDictionary *contact = display[self.selectedContact];
  NSString *contactId = contact[@"phone"];
  if (contactId) {
    self.conversations[contactId] = [self.currentMessages copy];
    [self saveContacts];
  }

  [self layoutMessages];
  [self.contactsTable reloadData]; // Update last message preview

  [self sendRealMessage:text
            toRecipient:contactId
                carrier:[contact[@"carrier"] integerValue]];
}

- (void)sendRealMessage:(NSString *)message
            toRecipient:(NSString *)recipient
                carrier:(NSInteger)carrier {
  if (!message || !recipient || message.length == 0 || recipient.length == 0)
    return;

  NativeSMSEngine *engine = [NativeSMSEngine sharedInstance];
  if (![engine isConfigured]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      NSAlert *a = [[NSAlert alloc] init];
      a.messageText = @"SMS Not Configured";
      a.informativeText = @"Set up your email and app password to send real "
                          @"SMS.\n\nWould you like to configure now?";
      [a addButtonWithTitle:@"Configure"];
      [a addButtonWithTitle:@"Cancel"];
      if ([a runModal] == NSAlertFirstButtonReturn)
        [[SMSConfigWindow sharedInstance] showWindow];
    });
    return;
  }

  [engine sendSMS:message
         toNumber:recipient
          carrier:(SMSCarrierType)carrier
       completion:^(BOOL success, NativeSMSMessage *msg, NSError *error) {
         dispatch_async(dispatch_get_main_queue(), ^{
           if (self.currentMessages.count > 0) {
             NSMutableDictionary *last =
                 [self.currentMessages.lastObject mutableCopy];
             last[@"deliveryStatus"] = success ? @"sent" : @"failed";
             [self.currentMessages
                 replaceObjectAtIndex:self.currentMessages.count - 1
                           withObject:last];

             NSDictionary *contact =
                 [self displayContacts].count > self.selectedContact &&
                         self.selectedContact >= 0
                     ? [self displayContacts][self.selectedContact] : nil;
             NSString *cId = contact[@"phone"];
             if (cId) {
               self.conversations[cId] = [self.currentMessages copy];
               [self saveContacts];
             }
             [self layoutMessages];
           }
           if (!success) {
             NSAlert *ea = [[NSAlert alloc] init];
             ea.messageText = @"SMS Failed";
             ea.informativeText =
                 error.localizedDescription ?: @"Unknown error";
             ea.alertStyle = NSAlertStyleWarning;
             [ea runModal];
           }
         });
       }];
}

- (void)showSMSConfig:(id)sender {
  [[SMSConfigWindow sharedInstance] showWindow];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
  return [self displayContacts].count;
}

- (NSView *)tableView:(NSTableView *)tableView
    viewForTableColumn:(NSTableColumn *)col
                   row:(NSInteger)row {
  NSArray *display = [self displayContacts];
  NSTableCellView *cell =
      [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, 300, 72)];
  if (row < 0 || row >= (NSInteger)display.count)
    return cell;

  NSDictionary *contact = display[row];
  if (!contact)
    return cell;

  cell.wantsLayer = YES;
  BOOL isSelected = (row == self.selectedContact);
  cell.layer.backgroundColor =
      isSelected ? [MSG_HOVER_BG CGColor] : [[NSColor clearColor] CGColor];
  cell.layer.cornerRadius = 6;

  NSString *name = contact[@"name"] ?: @"?";
  NSString *phone = contact[@"phone"] ?: @"";
  NSInteger carrier = [contact[@"carrier"] integerValue];
  NSString *initials = [self initialsForName:name];
  NSColor *avColor = [self avatarColorForName:name];

  // Avatar circle
  NSView *avCircle = [[NSView alloc] initWithFrame:NSMakeRect(12, 16, 44, 44)];
  avCircle.wantsLayer = YES;
  avCircle.layer.backgroundColor = [avColor CGColor];
  avCircle.layer.cornerRadius = 22;
  [cell addSubview:avCircle];

  NSTextField *avLabel = [self labelWithFrame:NSMakeRect(0, 8, 44, 28)
                                         text:initials
                                         font:[NSFont boldSystemFontOfSize:16]
                                        color:[NSColor whiteColor]];
  avLabel.alignment = NSTextAlignmentCenter;
  [avCircle addSubview:avLabel];

  // Name
  [cell addSubview:[self labelWithFrame:NSMakeRect(66, 40, 170, 20)
                                   text:name
                                   font:[NSFont
                                            systemFontOfSize:14
                                                      weight:NSFontWeightMedium]
                                  color:MSG_TEXT_PRI]];

  // Carrier badge + phone
  NSString *carrierBadge = [NSString
      stringWithFormat:@"%@ %@", [self carrierEmojiForType:carrier], phone];
  [cell addSubview:[self labelWithFrame:NSMakeRect(66, 22, 200, 16)
                                   text:carrierBadge
                                   font:[NSFont systemFontOfSize:11]
                                  color:MSG_TEXT_SEC]];

  // Last message preview
  NSString *contactId = contact[@"phone"];
  NSArray *msgs = self.conversations[contactId];
  NSString *lastMsg = @"Tap to start chatting";
  if (msgs.count > 0) {
    NSDictionary *last = msgs.lastObject;
    lastMsg = last[@"text"] ?: @"";
    if (lastMsg.length > 40)
      lastMsg = [[lastMsg substringToIndex:40] stringByAppendingString:@"..."];
  }
  [cell addSubview:[self labelWithFrame:NSMakeRect(66, 5, 210, 16)
                                   text:lastMsg
                                   font:[NSFont systemFontOfSize:11]
                                  color:MSG_TEXT_TER]];

  // Time badge (right side)
  if (msgs.count > 0) {
    NSString *lastTime = [msgs.lastObject objectForKey:@"time"] ?: @"";
    NSTextField *timeBadge = [self labelWithFrame:NSMakeRect(240, 42, 55, 14)
                                             text:lastTime
                                             font:[NSFont systemFontOfSize:10]
                                            color:MSG_TEXT_TER];
    timeBadge.alignment = NSTextAlignmentRight;
    [cell addSubview:timeBadge];
  }

  return cell;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
  NSArray *display = [self displayContacts];
  self.selectedContact = self.contactsTable.selectedRow;

  if (self.selectedContact >= 0 &&
      self.selectedContact < (NSInteger)display.count) {
    NSDictionary *contact = display[self.selectedContact];
    NSInteger carrier = [contact[@"carrier"] integerValue];

    self.chatTitleField.stringValue = contact[@"name"] ?: @"Unknown";
    self.chatSubtitleField.stringValue =
        [NSString stringWithFormat:@"%@ • %@ %@", contact[@"phone"] ?: @"",
                                   [self carrierEmojiForType:carrier],
                                   [self carrierNameForType:carrier]];

    NSString *contactId = contact[@"phone"];
    [self.currentMessages removeAllObjects];
    NSArray *saved = self.conversations[contactId];
    if (saved)
      [self.currentMessages addObjectsFromArray:saved];

    [self layoutMessages];
    [self.contactsTable reloadData]; // Refresh selection highlight
  }
}

@end
