#import "TerminalWindow.h"

@interface TerminalWindow () <NSTextViewDelegate>
@property (nonatomic, strong) NSWindow *terminalWindow;
@property (nonatomic, strong) NSTextView *outputView;
@property (nonatomic, strong) NSString *currentDirectory;
@property (nonatomic, strong) NSMutableString *outputBuffer;
@end

@implementation TerminalWindow

+ (instancetype)sharedInstance {
    static TerminalWindow *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[TerminalWindow alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.currentDirectory = NSHomeDirectory();
        self.outputBuffer = [NSMutableString string];
    }
    return self;
}

- (void)showWindow {
    if (self.terminalWindow) {
        [self.terminalWindow makeKeyAndOrderFront:nil];
        return;
    }
    
    NSRect frame = NSMakeRect(0, 0, 820, 520);
    self.terminalWindow = [[NSWindow alloc] initWithContentRect:frame
                                                      styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                        backing:NSBackingStoreBuffered
                                                          defer:NO];
    [self.terminalWindow setTitle:@"Terminal — zsh"];
    [self.terminalWindow center];
    self.terminalWindow.titlebarAppearsTransparent = YES;
    self.terminalWindow.backgroundColor = [NSColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
    
    NSView *contentView = [[NSView alloc] initWithFrame:frame];
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = [[NSColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0] CGColor];
    [self.terminalWindow setContentView:contentView];
    
    // Tab bar area (decorative)
    NSView *tabBar = [[NSView alloc] initWithFrame:NSMakeRect(0, frame.size.height - 28, frame.size.width, 28)];
    tabBar.wantsLayer = YES;
    tabBar.layer.backgroundColor = [[NSColor colorWithRed:0.18 green:0.18 blue:0.20 alpha:1.0] CGColor];
    tabBar.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;
    [contentView addSubview:tabBar];
    
    // Tab indicator
    NSView *activeTab = [[NSView alloc] initWithFrame:NSMakeRect(10, 4, 150, 22)];
    activeTab.wantsLayer = YES;
    activeTab.layer.backgroundColor = [[NSColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0] CGColor];
    activeTab.layer.cornerRadius = 5;
    [tabBar addSubview:activeTab];
    
    NSTextField *tabLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(8, 2, 130, 18)];
    tabLabel.stringValue = @"⚫ zsh";
    tabLabel.font = [NSFont systemFontOfSize:11];
    tabLabel.textColor = [NSColor colorWithWhite:0.8 alpha:1.0];
    tabLabel.bezeled = NO;
    tabLabel.editable = NO;
    tabLabel.drawsBackground = NO;
    [activeTab addSubview:tabLabel];
    
    // Output scroll view
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height - 28)];
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = NO;
    scrollView.scrollerStyle = NSScrollerStyleOverlay;
    scrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    scrollView.drawsBackground = NO;
    
    self.outputView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height - 28)];
    self.outputView.backgroundColor = [NSColor colorWithRed:0.12 green:0.12 blue:0.14 alpha:1.0];
    self.outputView.textColor = [NSColor colorWithRed:0.85 green:0.85 blue:0.85 alpha:1.0];
    self.outputView.insertionPointColor = [NSColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0];
    self.outputView.font = [NSFont fontWithName:@"SF Mono" size:13] ?: [NSFont fontWithName:@"Menlo" size:13];
    self.outputView.editable = YES;
    self.outputView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.outputView.textContainerInset = NSMakeSize(12, 10);
    self.outputView.delegate = self;
    
    scrollView.documentView = self.outputView;
    [contentView addSubview:scrollView];
    
    // Welcome message with color
    NSString *welcomeMsg = [NSString stringWithFormat:
        @"\033[1;36m╭─────────────────────────────────────────────╮\033[0m\n"
        @"\033[1;36m│\033[0m  \033[1;32mVirtualOS Terminal\033[0m - Full Shell Access     \033[1;36m│\033[0m\n"
        @"\033[1;36m│\033[0m  Run any macOS, Linux, or Unix command       \033[1;36m│\033[0m\n"
        @"\033[1;36m╰─────────────────────────────────────────────╯\033[0m\n\n"
        @"\033[0;90mLast login: %@\033[0m\n\n"
        @"%@$ ",
        [[NSDate date] descriptionWithLocale:[NSLocale currentLocale]],
        [self shortPath]];
    
    [self appendOutput:welcomeMsg];
    
    [self.terminalWindow makeKeyAndOrderFront:nil];
    [self.terminalWindow makeFirstResponder:self.outputView];
}

- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)commandSelector {
    if (commandSelector == @selector(insertNewline:)) {
        // Get the last line as the command
        NSString *text = textView.string;
        NSArray *lines = [text componentsSeparatedByString:@"\n"];
        NSString *lastLine = lines.lastObject ?: @"";
        
        // Extract command after prompt
        NSRange promptRange = [lastLine rangeOfString:@"$ "];
        if (promptRange.location != NSNotFound) {
            NSString *command = [lastLine substringFromIndex:promptRange.location + 2];
            command = [command stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            [self appendOutput:@"\n"];
            
            if (command.length > 0) {
                NSArray *parts = [command componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                parts = [parts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]];
                NSString *cmd = parts.count > 0 ? parts[0] : @"";
                NSArray *args = parts.count > 1 ? [parts subarrayWithRange:NSMakeRange(1, parts.count - 1)] : @[];
                
                NSString *output = [self processCommand:cmd withArgs:args];
                [self appendOutput:output];
            }
            
            [self appendOutput:[NSString stringWithFormat:@"%@$ ", [self shortPath]]];
        }
        return YES;
    }
    return NO;
}

- (NSString *)shortPath {
    NSString *home = NSHomeDirectory();
    if ([self.currentDirectory hasPrefix:home]) {
        return [@"~" stringByAppendingString:[self.currentDirectory substringFromIndex:home.length]];
    }
    return self.currentDirectory;
}

- (void)appendOutput:(NSString *)text {
    [self.outputBuffer appendString:text];
    
    NSMutableAttributedString *attrStr = [[NSMutableAttributedString alloc] initWithString:self.outputBuffer];
    [attrStr addAttribute:NSForegroundColorAttributeName
                    value:[NSColor colorWithRed:0.0 green:0.9 blue:0.4 alpha:1.0]
                    range:NSMakeRange(0, attrStr.length)];
    [attrStr addAttribute:NSFontAttributeName
                    value:[NSFont fontWithName:@"Menlo" size:12]
                    range:NSMakeRange(0, attrStr.length)];
    
    [self.outputView.textStorage setAttributedString:attrStr];
    [self.outputView scrollToEndOfDocument:nil];
}

- (NSString *)processCommand:(NSString *)cmd withArgs:(NSArray *)args {
    // Built-in commands
    if ([cmd isEqualToString:@"cd"]) {
        NSString *path = args.count > 0 ? args[0] : NSHomeDirectory();
        
        if ([path isEqualToString:@"~"]) {
            path = NSHomeDirectory();
        } else if ([path hasPrefix:@"~/"]) {
            path = [NSHomeDirectory() stringByAppendingPathComponent:[path substringFromIndex:2]];
        } else if ([path isEqualToString:@"-"]) {
            path = NSHomeDirectory();
        } else if (![path hasPrefix:@"/"]) {
            path = [self.currentDirectory stringByAppendingPathComponent:path];
        }
        
        path = [path stringByStandardizingPath];
        
        BOOL isDir;
        if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] && isDir) {
            self.currentDirectory = path;
            return @"";
        } else {
            return [NSString stringWithFormat:@"cd: no such directory: %@\n", args.count > 0 ? args[0] : @""];
        }
    }
    else if ([cmd isEqualToString:@"clear"]) {
        self.outputBuffer = [NSMutableString string];
        [self.outputView setString:@""];
        return @"";
    }
    else if ([cmd isEqualToString:@"exit"]) {
        [self.terminalWindow close];
        self.terminalWindow = nil;
        return @"";
    }
    
    // Execute real shell command
    return [self executeShellCommand:cmd withArgs:args];
}

- (NSString *)executeShellCommand:(NSString *)cmd withArgs:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/bin/zsh"];
    
    // Build the full command
    NSMutableString *fullCommand = [NSMutableString stringWithString:cmd];
    for (NSString *arg in args) {
        [fullCommand appendFormat:@" %@", arg];
    }
    
    task.arguments = @[@"-c", fullCommand];
    task.currentDirectoryURL = [NSURL fileURLWithPath:self.currentDirectory];
    
    // Set up environment
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    env[@"HOME"] = NSHomeDirectory();
    env[@"USER"] = NSUserName();
    env[@"TERM"] = @"xterm-256color";
    env[@"PATH"] = @"/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin";
    task.environment = env;
    
    NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];
    task.standardOutput = outputPipe;
    task.standardError = errorPipe;
    
    @try {
        NSError *error = nil;
        [task launchAndReturnError:&error];
        if (error) {
            return [NSString stringWithFormat:@"Error: %@\n", error.localizedDescription];
        }
        [task waitUntilExit];
        
        NSData *outputData = [outputPipe.fileHandleForReading readDataToEndOfFile];
        NSData *errorData = [errorPipe.fileHandleForReading readDataToEndOfFile];
        
        NSString *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding];
        NSString *errorOutput = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding];
        
        NSMutableString *result = [NSMutableString string];
        if (output.length > 0) {
            [result appendString:output];
        }
        if (errorOutput.length > 0) {
            [result appendString:errorOutput];
        }
        
        // Ensure newline at end
        if (result.length > 0 && ![result hasSuffix:@"\n"]) {
            [result appendString:@"\n"];
        }
        
        return result;
    } @catch (NSException *e) {
        return [NSString stringWithFormat:@"command not found: %@\n", cmd];
    }
}

@end
