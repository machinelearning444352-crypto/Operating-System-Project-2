#import "TerminalWindow.h"

// ─── Terminal ANSI Parser & Highlighting ────────────────────────────────────

#define TERM_BG                                                                \
  [NSColor colorWithCalibratedWhite:0.0 alpha:0.6] // Dark transparent
#define TERM_FG [NSColor colorWithCalibratedWhite:0.9 alpha:1.0]

@interface TerminalWindow () <NSTextViewDelegate>

@property(nonatomic, strong) NSWindow *termWindow;
@property(nonatomic, strong) NSVisualEffectView *vibrancy;
@property(nonatomic, strong) NSTextView *consoleView;
@property(nonatomic, strong) NSScrollView *scroll;
@property(nonatomic, strong) NSTextField *titleLbl;

@property(nonatomic, strong) NSString *workingDirectory;
@property(nonatomic, strong) NSMutableArray<NSString *> *cmdHistory;
@property(nonatomic, assign) NSInteger historyPtr;

// The length of the immutable prompt + past output
@property(nonatomic, assign) NSUInteger promptEndIndex;

@end

@implementation TerminalWindow

+ (instancetype)sharedInstance {
  static TerminalWindow *inst;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    inst = [[TerminalWindow alloc] init];
  });
  return inst;
}

- (instancetype)init {
  if (self = [super init]) {
    _workingDirectory = NSHomeDirectory();
    _cmdHistory = [NSMutableArray array];
    _historyPtr = -1;
  }
  return self;
}

- (void)showWindow {
  if (self.termWindow) {
    [self.termWindow makeKeyAndOrderFront:nil];
    return;
  }

  NSRect frame = NSMakeRect(300, 300, 800, 500);
  self.termWindow = [[NSWindow alloc]
      initWithContentRect:frame
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable |
                          NSWindowStyleMaskFullSizeContentView
                  backing:NSBackingStoreBuffered
                    defer:NO];
  [self.termWindow setTitle:@"Terminal"];
  self.termWindow.releasedWhenClosed = NO;
  self.termWindow.titlebarAppearsTransparent = YES;
  self.termWindow.minSize = NSMakeSize(400, 300);

  NSView *root = [[NSView alloc] initWithFrame:frame];
  root.wantsLayer = YES;
  root.layer.backgroundColor = [[NSColor clearColor] CGColor];
  [self.termWindow setContentView:root];

  // Vibrancy background
  self.vibrancy = [[NSVisualEffectView alloc] initWithFrame:frame];
  self.vibrancy.material = NSVisualEffectMaterialHUDWindow; // Dark blur
  self.vibrancy.state = NSVisualEffectStateFollowsWindowActiveState;
  self.vibrancy.blendingMode = NSVisualEffectBlendingModeBehindWindow;
  self.vibrancy.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  [root addSubview:self.vibrancy];

  // Custom Titlebar
  NSView *tb =
      [[NSView alloc] initWithFrame:NSMakeRect(0, frame.size.height - 30,
                                               frame.size.width, 30)];
  tb.wantsLayer = YES;
  tb.layer.backgroundColor =
      [[[NSColor blackColor] colorWithAlphaComponent:0.3] CGColor];
  tb.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
  [self.vibrancy addSubview:tb];

  self.titleLbl = [[NSTextField alloc]
      initWithFrame:NSMakeRect(100, 5, frame.size.width - 200, 20)];
  self.titleLbl.font = [NSFont fontWithName:@"Menlo" size:12];
  self.titleLbl.textColor = [NSColor lightGrayColor];
  self.titleLbl.alignment = NSTextAlignmentCenter;
  self.titleLbl.drawsBackground = NO;
  self.titleLbl.bezeled = NO;
  self.titleLbl.editable = NO;
  self.titleLbl.autoresizingMask = NSViewWidthSizable;
  self.titleLbl.stringValue =
      [NSString stringWithFormat:@"guest@virtualos: %@", [self shortPath]];
  [tb addSubview:self.titleLbl];

  // Scroll & text view
  self.scroll = [[NSScrollView alloc]
      initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height - 30)];
  self.scroll.hasVerticalScroller = YES;
  self.scroll.documentView = [[NSView alloc] init]; // stub
  self.scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
  self.scroll.drawsBackground = NO;
  [self.vibrancy addSubview:self.scroll];

  NSSize contSize = [self.scroll contentSize];
  self.consoleView = [[NSTextView alloc]
      initWithFrame:NSMakeRect(0, 0, contSize.width, contSize.height)];
  self.consoleView.minSize = NSMakeSize(0, contSize.height);
  self.consoleView.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
  self.consoleView.autoresizingMask = NSViewWidthSizable;
  self.consoleView.backgroundColor = [NSColor clearColor];
  self.consoleView.textColor = TERM_FG;
  self.consoleView.font = [NSFont fontWithName:@"Menlo" size:14];
  self.consoleView.insertionPointColor = [NSColor systemGreenColor];
  self.consoleView.richText = NO;
  self.consoleView.continuousSpellCheckingEnabled = NO;
  self.consoleView.delegate = self;
  [self.consoleView.textContainer
      setContainerSize:NSMakeSize(contSize.width, FLT_MAX)];
  [self.consoleView.textContainer setWidthTracksTextView:YES];

  self.scroll.documentView = self.consoleView;

  [self printWelcome];
  [self printPrompt];

  [self.termWindow makeKeyAndOrderFront:nil];
  [self.termWindow makeFirstResponder:self.consoleView];
}

- (NSString *)shortPath {
  NSString *home = NSHomeDirectory();
  if ([self.workingDirectory hasPrefix:home]) {
    return [@"~" stringByAppendingString:[self.workingDirectory
                                             substringFromIndex:home.length]];
  }
  return self.workingDirectory;
}

- (void)printWelcome {
  NSDateFormatter *df = [[NSDateFormatter alloc] init];
  [df setDateFormat:@"EEE MMM d HH:mm:ss"];
  NSString *now = [df stringFromDate:[NSDate date]];

  NSMutableAttributedString *mas = [[NSMutableAttributedString alloc]
      initWithString:[NSString
                         stringWithFormat:@"Last login: %@ on ttys000\n", now]];
  [mas addAttribute:NSForegroundColorAttributeName
              value:[NSColor lightGrayColor]
              range:NSMakeRange(0, mas.length)];

  NSAttributedString *logo = [[NSAttributedString alloc]
      initWithString:@"   _    ___      __             __  ____  ___\n"
                     @"  | |  / (_)____/ /___  ______ / / / __ \\/ __|\n"
                     @"  | | / / / ___/ __/ / / / __ `/ / / / / \\__ \\\n"
                     @"  | |/ / / /  / /_/ /_/ / /_/ / / / /_/ /___/ /\n"
                     @"  |___/_/_/   \\__/\\__,_/\\__,_/_/  \\____//____/\n\n"
          attributes:@{
            NSForegroundColorAttributeName : [NSColor systemBlueColor]
          }];

  [mas appendAttributedString:logo];

  [self.consoleView.textStorage appendAttributedString:mas];
}

- (void)printPrompt {
  NSString *pStr =
      [NSString stringWithFormat:@"guest@virtualos %@ %% ", [self shortPath]];
  NSMutableAttributedString *pMas =
      [[NSMutableAttributedString alloc] initWithString:pStr];

  // Highlight guest@virtualos in green
  [pMas addAttribute:NSForegroundColorAttributeName
               value:[NSColor systemGreenColor]
               range:NSMakeRange(0, 15)];
  // Highlight path in cyan
  NSRange pathRange = NSMakeRange(16, [self shortPath].length);
  [pMas addAttribute:NSForegroundColorAttributeName
               value:[NSColor systemCyanColor]
               range:pathRange];

  [pMas addAttribute:NSFontAttributeName
               value:[NSFont fontWithName:@"Menlo-Bold" size:14]
               range:NSMakeRange(0, pMas.length)];

  [self.consoleView.textStorage appendAttributedString:pMas];
  self.promptEndIndex = self.consoleView.textStorage.length;
  [self.consoleView
      scrollRangeToVisible:NSMakeRange(self.consoleView.string.length, 0)];

  self.titleLbl.stringValue =
      [NSString stringWithFormat:@"guest@virtualos: %@", [self shortPath]];
}

#pragma mark - Input Handling

- (BOOL)textView:(NSTextView *)tv
    shouldChangeTextInRange:(NSRange)affectedCharRange
          replacementString:(NSString *)replacementString {
  // Prevent editing above the prompt
  if (affectedCharRange.location < self.promptEndIndex) {
    return NO;
  }
  return YES;
}

- (BOOL)textView:(NSTextView *)textView
    doCommandBySelector:(SEL)commandSelector {
  if (commandSelector == @selector(insertNewline:)) {
    NSRange cmdRange = NSMakeRange(
        self.promptEndIndex, textView.string.length - self.promptEndIndex);
    NSString *cmd = [[textView.string substringWithRange:cmdRange]
        stringByTrimmingCharactersInSet:[NSCharacterSet
                                            whitespaceAndNewlineCharacterSet]];

    // Add plain newline so it looks like we hit enter
    NSAttributedString *nl = [[NSAttributedString alloc]
        initWithString:@"\n"
            attributes:@{
              NSFontAttributeName : [NSFont fontWithName:@"Menlo" size:14]
            }];
    [self.consoleView.textStorage appendAttributedString:nl];

    if (cmd.length > 0) {
      if (self.cmdHistory.count == 0 ||
          ![self.cmdHistory.lastObject isEqualToString:cmd]) {
        [self.cmdHistory addObject:cmd];
      }
      self.historyPtr = self.cmdHistory.count;
      [self executeCommand:cmd];
    } else {
      [self printPrompt];
    }
    return YES;
  } else if (commandSelector == @selector(moveUp:)) {
    if (self.cmdHistory.count > 0 && self.historyPtr > 0) {
      self.historyPtr--;
      [self replaceCurrentInput:self.cmdHistory[self.historyPtr]];
    }
    return YES;
  } else if (commandSelector == @selector(moveDown:)) {
    if (self.historyPtr < (NSInteger)self.cmdHistory.count - 1) {
      self.historyPtr++;
      [self replaceCurrentInput:self.cmdHistory[self.historyPtr]];
    } else {
      self.historyPtr = self.cmdHistory.count;
      [self replaceCurrentInput:@""];
    }
    return YES;
  } else if (commandSelector == @selector(deleteBackward:)) {
    if (textView.selectedRange.location <= self.promptEndIndex &&
        textView.selectedRange.length == 0) {
      return YES; // block backspace over prompt
    }
    return NO; // allow normal backspace
  }

  return NO;
}

- (void)replaceCurrentInput:(NSString *)str {
  NSRange inputR =
      NSMakeRange(self.promptEndIndex,
                  self.consoleView.string.length - self.promptEndIndex);
  [self.consoleView.textStorage replaceCharactersInRange:inputR withString:str];
  [self.consoleView
      setSelectedRange:NSMakeRange(self.consoleView.string.length, 0)];
}

- (void)executeCommand:(NSString *)fullCmd {
  NSArray *parts = [fullCmd
      componentsSeparatedByCharactersInSet:[NSCharacterSet
                                               whitespaceCharacterSet]];
  NSMutableArray *args = [NSMutableArray array];
  for (NSString *p in parts) {
    if (p.length > 0)
      [args addObject:p];
  }
  NSString *cmd = args[0];
  [args removeObjectAtIndex:0];

  if ([cmd isEqualToString:@"cd"]) {
    NSString *targ = args.count > 0 ? args[0] : NSHomeDirectory();
    if ([targ hasPrefix:@"~"])
      targ = [targ stringByReplacingOccurrencesOfString:@"~"
                                             withString:NSHomeDirectory()];

    BOOL isDir = NO;
    if ([[NSFileManager defaultManager] fileExistsAtPath:targ
                                             isDirectory:&isDir] &&
        isDir) {
      self.workingDirectory = targ;
    } else {
      [self printLine:[NSString
                          stringWithFormat:@"cd: no such file or directory: %@",
                                           targ]
                color:[NSColor systemRedColor]];
    }
    [self printPrompt];
  } else if ([cmd isEqualToString:@"clear"]) {
    [self.consoleView.textStorage
        setAttributedString:[[NSAttributedString alloc] initWithString:@""]];
    [self printPrompt];
  } else if ([cmd isEqualToString:@"exit"]) {
    [self.termWindow close];
  } else if ([cmd isEqualToString:@"help"]) {
    [self printLine:@"VirtualOS ZSH Emulator v2.0"
              color:[NSColor systemYellowColor]];
    [self printLine:@"Built-in commands: cd, clear, exit, help, history"
              color:TERM_FG];
    [self printLine:@"All other commands are forwarded to the underlying macOS "
                    @"shell dynamically."
              color:TERM_FG];
    [self printPrompt];
  } else if ([cmd isEqualToString:@"history"]) {
    for (NSUInteger i = 0; i < self.cmdHistory.count; i++) {
      [self printLine:[NSString stringWithFormat:@"%4lu  %@",
                                                 (unsigned long)(i + 1),
                                                 self.cmdHistory[i]]
                color:[NSColor systemCyanColor]];
    }
    [self printPrompt];
  } else {
    // Real EXEC - Asynchronous to prevent UI freezing
    dispatch_async(
        dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
          NSTask *task = [[NSTask alloc] init];
          task.executableURL = [NSURL fileURLWithPath:@"/bin/sh"];
          task.arguments = @[ @"-c", fullCmd ];
          task.currentDirectoryURL =
              [NSURL fileURLWithPath:self.workingDirectory];

          NSPipe *outP = [NSPipe pipe];
          NSPipe *errP = [NSPipe pipe];
          task.standardOutput = outP;
          task.standardError = errP;

          @try {
            [task launch];
            NSData *dat = [outP.fileHandleForReading readDataToEndOfFile];
            NSData *errDat = [errP.fileHandleForReading readDataToEndOfFile];
            [task waitUntilExit];

            dispatch_async(dispatch_get_main_queue(), ^{
              if (dat.length > 0) {
                NSString *s =
                    [[NSString alloc] initWithData:dat
                                          encoding:NSUTF8StringEncoding];
                if (s)
                  [self printLine:s color:TERM_FG];
              }
              if (errDat.length > 0) {
                NSString *s =
                    [[NSString alloc] initWithData:errDat
                                          encoding:NSUTF8StringEncoding];
                if (s)
                  [self printLine:s color:[NSColor systemRedColor]];
              }
              [self printPrompt];
            });
          } @catch (NSException *e) {
            dispatch_async(dispatch_get_main_queue(), ^{
              [self
                  printLine:[NSString
                                stringWithFormat:@"zsh: command not found: %@",
                                                 cmd]
                      color:[NSColor systemRedColor]];
              [self printPrompt];
            });
          }
        });
  }
}

- (void)printLine:(NSString *)l color:(NSColor *)col {
  if (![l hasSuffix:@"\n"])
    l = [l stringByAppendingString:@"\n"];
  NSAttributedString *as = [[NSAttributedString alloc]
      initWithString:l
          attributes:@{
            NSFontAttributeName : [NSFont fontWithName:@"Menlo" size:14],
            NSForegroundColorAttributeName : col
          }];
  [self.consoleView.textStorage appendAttributedString:as];
}

@end
