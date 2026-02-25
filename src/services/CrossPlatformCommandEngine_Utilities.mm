#import "CrossPlatformCommandEngine.h"
#import <CommonCrypto/CommonDigest.h>

@interface CrossPlatformCommandEngine ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *aliasMap;
@end

@implementation CrossPlatformCommandEngine (Utilities)

#pragma mark - Command Completion

- (NSArray<NSString *> *)completionsForPartialCommand:(NSString *)partial {
    NSMutableArray *completions = [NSMutableArray array];
    
    // Check builtins
    NSArray *builtins = @[@"cd", @"pwd", @"echo", @"export", @"unset", @"alias", @"unalias",
                          @"history", @"clear", @"exit", @"source", @"type", @"which", @"help",
                          @"set", @"env", @"printenv", @"kill", @"jobs", @"fg", @"bg", @"pushd", @"popd"];
    
    for (NSString *cmd in builtins) {
        if ([cmd hasPrefix:partial]) {
            [completions addObject:cmd];
        }
    }
    
    // Check aliases
    for (NSString *alias in self.aliasMap) {
        if ([alias hasPrefix:partial]) {
            [completions addObject:alias];
        }
    }
    
    // Check command registry
    for (NSString *cmd in self.commandRegistry) {
        if ([cmd hasPrefix:partial]) {
            [completions addObject:cmd];
        }
    }
    
    // Check PATH for executables
    NSArray *pathDirs = [self pathDirectories];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *dir in pathDirs) {
        NSArray *contents = [fm contentsOfDirectoryAtPath:dir error:nil];
        for (NSString *file in contents) {
            if ([file hasPrefix:partial]) {
                NSString *path = [dir stringByAppendingPathComponent:file];
                if ([fm isExecutableFileAtPath:path]) {
                    [completions addObject:file];
                }
            }
        }
    }
    
    // Remove duplicates and sort
    NSOrderedSet *unique = [NSOrderedSet orderedSetWithArray:completions];
    return [[unique array] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray<NSString *> *)completionsForPath:(NSString *)partialPath {
    NSMutableArray *completions = [NSMutableArray array];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *basePath;
    NSString *prefix;
    
    if ([partialPath hasPrefix:@"/"]) {
        basePath = [partialPath stringByDeletingLastPathComponent];
        prefix = [partialPath lastPathComponent];
    } else if ([partialPath hasPrefix:@"~"]) {
        NSString *expanded = [partialPath stringByExpandingTildeInPath];
        basePath = [expanded stringByDeletingLastPathComponent];
        prefix = [expanded lastPathComponent];
    } else {
        basePath = self.currentSession.workingDirectory;
        if ([partialPath containsString:@"/"]) {
            basePath = [basePath stringByAppendingPathComponent:[partialPath stringByDeletingLastPathComponent]];
            prefix = [partialPath lastPathComponent];
        } else {
            prefix = partialPath;
        }
    }
    
    NSArray *contents = [fm contentsOfDirectoryAtPath:basePath error:nil];
    for (NSString *item in contents) {
        if ([item hasPrefix:prefix] || prefix.length == 0) {
            NSString *fullPath = [basePath stringByAppendingPathComponent:item];
            BOOL isDir;
            [fm fileExistsAtPath:fullPath isDirectory:&isDir];
            
            NSString *completion = item;
            if (isDir) {
                completion = [item stringByAppendingString:@"/"];
            }
            [completions addObject:completion];
        }
    }
    
    return [completions sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray<NSString *> *)completionsForOptions:(NSString *)command partial:(NSString *)partial {
    NSDictionary *commandOptions = @{
        @"ls": @[@"-l", @"-a", @"-la", @"-lh", @"-R", @"-t", @"-S", @"-r"],
        @"grep": @[@"-i", @"-v", @"-n", @"-c", @"-r", @"-R", @"-l", @"-o", @"-E"],
        @"find": @[@"-name", @"-type", @"-size", @"-mtime", @"-exec", @"-print"],
        @"tar": @[@"-c", @"-x", @"-t", @"-v", @"-f", @"-z", @"-j", @"-J"],
        @"git": @[@"status", @"add", @"commit", @"push", @"pull", @"clone", @"checkout", @"branch", @"merge", @"log", @"diff"],
        @"docker": @[@"ps", @"images", @"run", @"build", @"pull", @"push", @"exec", @"logs", @"stop", @"rm"],
        @"npm": @[@"install", @"start", @"test", @"run", @"build", @"init", @"publish", @"update"],
        @"brew": @[@"install", @"uninstall", @"update", @"upgrade", @"list", @"search", @"info", @"doctor"]
    };
    
    NSArray *options = commandOptions[command];
    if (!options) return @[];
    
    NSMutableArray *matches = [NSMutableArray array];
    for (NSString *opt in options) {
        if ([opt hasPrefix:partial] || partial.length == 0) {
            [matches addObject:opt];
        }
    }
    
    return matches;
}

#pragma mark - History

- (void)addToHistory:(NSString *)command {
    if (command.length == 0) return;
    
    CPCommandHistoryEntry *entry = [[CPCommandHistoryEntry alloc] init];
    entry.command = command;
    entry.timestamp = [NSDate date];
    entry.workingDirectory = self.currentSession.workingDirectory;
    
    [self.currentSession.history addObject:entry];
}

- (NSArray<NSString *> *)searchHistory:(NSString *)pattern {
    NSMutableArray *matches = [NSMutableArray array];
    
    for (CPCommandHistoryEntry *entry in self.currentSession.history) {
        if ([entry.command containsString:pattern]) {
            [matches addObject:entry.command];
        }
    }
    
    return matches;
}

- (void)clearHistory {
    [self.currentSession.history removeAllObjects];
}

- (void)loadHistory {
    NSString *historyPath = [NSHomeDirectory() stringByAppendingPathComponent:@".cpce_history"];
    NSString *content = [NSString stringWithContentsOfFile:historyPath encoding:NSUTF8StringEncoding error:nil];
    
    if (content) {
        NSArray *lines = [content componentsSeparatedByString:@"\n"];
        for (NSString *line in lines) {
            if (line.length > 0) {
                CPCommandHistoryEntry *entry = [[CPCommandHistoryEntry alloc] init];
                entry.command = line;
                entry.timestamp = [NSDate date];
                [self.currentSession.history addObject:entry];
            }
        }
    }
}

- (void)saveHistory {
    NSString *historyPath = [NSHomeDirectory() stringByAppendingPathComponent:@".cpce_history"];
    NSMutableString *content = [NSMutableString string];
    
    NSInteger start = MAX(0, (NSInteger)self.currentSession.history.count - 1000);
    for (NSInteger i = start; i < (NSInteger)self.currentSession.history.count; i++) {
        CPCommandHistoryEntry *entry = self.currentSession.history[i];
        [content appendFormat:@"%@\n", entry.command];
    }
    
    [content writeToFile:historyPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

#pragma mark - Aliases

- (void)defineAlias:(NSString *)name expansion:(NSString *)expansion {
    self.aliasMap[name] = expansion;
}

- (void)removeAlias:(NSString *)name {
    [self.aliasMap removeObjectForKey:name];
}

- (NSString *)expandAliases:(NSString *)command {
    NSArray *tokens = [self tokenizeCommand:command];
    if (tokens.count == 0) return command;
    
    NSString *first = tokens[0];
    NSString *expansion = self.aliasMap[first];
    
    if (expansion) {
        if (tokens.count > 1) {
            NSArray *rest = [tokens subarrayWithRange:NSMakeRange(1, tokens.count - 1)];
            return [NSString stringWithFormat:@"%@ %@", expansion, [rest componentsJoinedByString:@" "]];
        }
        return expansion;
    }
    
    return command;
}

- (NSDictionary<NSString *, NSString *> *)allAliases {
    return [self.aliasMap copy];
}

#pragma mark - Environment

- (void)setEnvironmentVariable:(NSString *)name value:(NSString *)value {
    self.currentSession.environment[name] = value;
}

- (NSString *)getEnvironmentVariable:(NSString *)name {
    return self.currentSession.environment[name];
}

- (void)unsetEnvironmentVariable:(NSString *)name {
    [self.currentSession.environment removeObjectForKey:name];
}

- (NSDictionary<NSString *, NSString *> *)allEnvironmentVariables {
    return [self.currentSession.environment copy];
}

- (void)exportVariable:(NSString *)name {
    // In our implementation, all variables in environment are exported
}

#pragma mark - Path Management

- (void)addToPath:(NSString *)directory {
    NSString *currentPath = self.currentSession.environment[@"PATH"] ?: @"";
    if (![currentPath containsString:directory]) {
        self.currentSession.environment[@"PATH"] = [NSString stringWithFormat:@"%@:%@", directory, currentPath];
    }
}

- (void)removeFromPath:(NSString *)directory {
    NSString *currentPath = self.currentSession.environment[@"PATH"] ?: @"";
    NSMutableArray *dirs = [[currentPath componentsSeparatedByString:@":"] mutableCopy];
    [dirs removeObject:directory];
    self.currentSession.environment[@"PATH"] = [dirs componentsJoinedByString:@":"];
}

- (NSArray<NSString *> *)pathDirectories {
    NSString *path = self.currentSession.environment[@"PATH"] ?: @"/usr/bin:/bin:/usr/sbin:/sbin";
    return [path componentsSeparatedByString:@":"];
}

- (NSString *)resolveExecutable:(NSString *)name {
    if ([name hasPrefix:@"/"] || [name hasPrefix:@"./"]) {
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:name]) {
            return name;
        }
        return nil;
    }
    
    NSArray *pathDirs = [self pathDirectories];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *dir in pathDirs) {
        NSString *fullPath = [dir stringByAppendingPathComponent:name];
        if ([fm isExecutableFileAtPath:fullPath]) {
            return fullPath;
        }
    }
    
    return nil;
}

#pragma mark - Output Formatting

- (NSString *)formatOutput:(NSString *)output forTerminalWidth:(NSInteger)width {
    if (width <= 0) width = 80;
    
    NSMutableString *formatted = [NSMutableString string];
    NSArray *lines = [output componentsSeparatedByString:@"\n"];
    
    for (NSString *line in lines) {
        if (line.length <= width) {
            [formatted appendFormat:@"%@\n", line];
        } else {
            NSInteger pos = 0;
            while (pos < line.length) {
                NSInteger len = MIN(width, (NSInteger)line.length - pos);
                [formatted appendFormat:@"%@\n", [line substringWithRange:NSMakeRange(pos, len)]];
                pos += len;
            }
        }
    }
    
    return formatted;
}

- (NSString *)colorizeOutput:(NSString *)output {
    // Add basic syntax highlighting
    NSMutableString *colored = [output mutableCopy];
    
    // Colorize errors
    [colored replaceOccurrencesOfString:@"error:" 
                             withString:@"\033[31merror:\033[0m" 
                                options:NSCaseInsensitiveSearch 
                                  range:NSMakeRange(0, colored.length)];
    
    // Colorize warnings
    [colored replaceOccurrencesOfString:@"warning:" 
                             withString:@"\033[33mwarning:\033[0m" 
                                options:NSCaseInsensitiveSearch 
                                  range:NSMakeRange(0, colored.length)];
    
    return colored;
}

- (NSString *)stripAnsiCodes:(NSString *)text {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\033\\[[0-9;]*m" 
                                                                           options:0 
                                                                             error:nil];
    return [regex stringByReplacingMatchesInString:text 
                                           options:0 
                                             range:NSMakeRange(0, text.length) 
                                      withTemplate:@""];
}

#pragma mark - Command Parsing

- (NSDictionary *)parseCommandLine:(NSString *)commandLine {
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    NSArray *tokens = [self tokenizeCommand:commandLine];
    
    if (tokens.count == 0) {
        return @{@"command": @"", @"args": @[], @"options": @{}};
    }
    
    result[@"command"] = tokens[0];
    
    NSMutableArray *args = [NSMutableArray array];
    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    
    for (NSInteger i = 1; i < (NSInteger)tokens.count; i++) {
        NSString *token = tokens[i];
        
        if ([token hasPrefix:@"--"]) {
            NSString *opt = [token substringFromIndex:2];
            NSRange eqRange = [opt rangeOfString:@"="];
            if (eqRange.location != NSNotFound) {
                NSString *key = [opt substringToIndex:eqRange.location];
                NSString *value = [opt substringFromIndex:eqRange.location + 1];
                options[key] = value;
            } else {
                options[opt] = @YES;
            }
        } else if ([token hasPrefix:@"-"] && token.length > 1) {
            for (NSInteger j = 1; j < (NSInteger)token.length; j++) {
                NSString *flag = [token substringWithRange:NSMakeRange(j, 1)];
                options[flag] = @YES;
            }
        } else {
            [args addObject:token];
        }
    }
    
    result[@"args"] = args;
    result[@"options"] = options;
    
    return result;
}

- (NSArray *)tokenizeCommand:(NSString *)command {
    NSMutableArray *tokens = [NSMutableArray array];
    NSMutableString *current = [NSMutableString string];
    
    BOOL inSingleQuote = NO;
    BOOL inDoubleQuote = NO;
    BOOL escaped = NO;
    
    for (NSInteger i = 0; i < (NSInteger)command.length; i++) {
        unichar c = [command characterAtIndex:i];
        
        if (escaped) {
            [current appendFormat:@"%C", c];
            escaped = NO;
            continue;
        }
        
        if (c == '\\') {
            escaped = YES;
            continue;
        }
        
        if (c == '\'' && !inDoubleQuote) {
            inSingleQuote = !inSingleQuote;
            continue;
        }
        
        if (c == '"' && !inSingleQuote) {
            inDoubleQuote = !inDoubleQuote;
            continue;
        }
        
        if ((c == ' ' || c == '\t') && !inSingleQuote && !inDoubleQuote) {
            if (current.length > 0) {
                [tokens addObject:[current copy]];
                current = [NSMutableString string];
            }
            continue;
        }
        
        [current appendFormat:@"%C", c];
    }
    
    if (current.length > 0) {
        [tokens addObject:current];
    }
    
    return tokens;
}

- (NSString *)expandVariables:(NSString *)text {
    NSMutableString *result = [text mutableCopy];
    
    // Expand $VAR style
    NSRegularExpression *varRegex = [NSRegularExpression regularExpressionWithPattern:@"\\$([A-Za-z_][A-Za-z0-9_]*)" 
                                                                              options:0 
                                                                                error:nil];
    
    NSArray *matches = [varRegex matchesInString:text options:0 range:NSMakeRange(0, text.length)];
    
    for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
        NSRange varNameRange = [match rangeAtIndex:1];
        NSString *varName = [text substringWithRange:varNameRange];
        NSString *value = self.currentSession.environment[varName] ?: @"";
        [result replaceCharactersInRange:match.range withString:value];
    }
    
    // Expand ${VAR} style
    NSRegularExpression *bracedVarRegex = [NSRegularExpression regularExpressionWithPattern:@"\\$\\{([A-Za-z_][A-Za-z0-9_]*)\\}" 
                                                                                    options:0 
                                                                                      error:nil];
    
    matches = [bracedVarRegex matchesInString:result options:0 range:NSMakeRange(0, result.length)];
    
    for (NSTextCheckingResult *match in [matches reverseObjectEnumerator]) {
        NSRange varNameRange = [match rangeAtIndex:1];
        NSString *varName = [result substringWithRange:varNameRange];
        NSString *value = self.currentSession.environment[varName] ?: @"";
        [result replaceCharactersInRange:match.range withString:value];
    }
    
    // Expand special variables
    [result replaceOccurrencesOfString:@"$?" withString:[NSString stringWithFormat:@"%d", self.currentSession.lastExitCode] options:0 range:NSMakeRange(0, result.length)];
    [result replaceOccurrencesOfString:@"$$" withString:[NSString stringWithFormat:@"%d", getpid()] options:0 range:NSMakeRange(0, result.length)];
    [result replaceOccurrencesOfString:@"$!" withString:@"0" options:0 range:NSMakeRange(0, result.length)];
    
    return result;
}

- (NSString *)expandGlobs:(NSString *)pattern inDirectory:(NSString *)directory {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableArray *matches = [NSMutableArray array];
    
    NSArray *contents = [fm contentsOfDirectoryAtPath:directory error:nil];
    
    for (NSString *item in contents) {
        if ([self matchesGlob:item pattern:pattern]) {
            [matches addObject:item];
        }
    }
    
    if (matches.count == 0) {
        return pattern;
    }
    
    return [matches componentsJoinedByString:@" "];
}

- (BOOL)matchesGlob:(NSString *)string pattern:(NSString *)pattern {
    // Convert glob pattern to regex
    NSMutableString *regex = [NSMutableString stringWithString:@"^"];
    
    for (NSInteger i = 0; i < (NSInteger)pattern.length; i++) {
        unichar c = [pattern characterAtIndex:i];
        
        switch (c) {
            case '*':
                [regex appendString:@".*"];
                break;
            case '?':
                [regex appendString:@"."];
                break;
            case '[':
            case ']':
            case '.':
            case '+':
            case '^':
            case '$':
            case '(':
            case ')':
            case '{':
            case '}':
            case '|':
            case '\\':
                [regex appendFormat:@"\\%C", c];
                break;
            default:
                [regex appendFormat:@"%C", c];
                break;
        }
    }
    
    [regex appendString:@"$"];
    
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    return [pred evaluateWithObject:string];
}

#pragma mark - Command Translation

- (NSString *)translateCommand:(NSString *)command fromPlatform:(CPCommandPlatform)source toPlatform:(CPCommandPlatform)target {
    if (source == target) return command;
    
    NSDictionary *translations = @{
        // Windows to Unix
        @"dir": @"ls",
        @"copy": @"cp",
        @"move": @"mv",
        @"del": @"rm",
        @"ren": @"mv",
        @"md": @"mkdir",
        @"rd": @"rmdir",
        @"type": @"cat",
        @"cls": @"clear",
        @"findstr": @"grep",
        @"tasklist": @"ps",
        @"taskkill": @"kill",
        @"ipconfig": @"ifconfig",
        @"tracert": @"traceroute",
        @"systeminfo": @"uname -a",
        
        // Unix to Windows
        @"ls": @"dir",
        @"cp": @"copy",
        @"mv": @"move",
        @"rm": @"del",
        @"mkdir": @"md",
        @"rmdir": @"rd",
        @"cat": @"type",
        @"clear": @"cls",
        @"grep": @"findstr",
        @"ps": @"tasklist",
        @"kill": @"taskkill",
        @"ifconfig": @"ipconfig",
        @"traceroute": @"tracert"
    };
    
    NSArray *tokens = [self tokenizeCommand:command];
    if (tokens.count == 0) return command;
    
    NSString *cmd = tokens[0];
    NSString *translated = translations[cmd];
    
    if (translated) {
        if (tokens.count > 1) {
            NSArray *args = [tokens subarrayWithRange:NSMakeRange(1, tokens.count - 1)];
            return [NSString stringWithFormat:@"%@ %@", translated, [args componentsJoinedByString:@" "]];
        }
        return translated;
    }
    
    return command;
}

- (NSString *)macOSEquivalentFor:(NSString *)command platform:(CPCommandPlatform)platform {
    return [self translateCommand:command fromPlatform:platform toPlatform:CPCommandPlatformMacOS];
}

- (NSString *)linuxEquivalentFor:(NSString *)command {
    return [self translateCommand:command fromPlatform:CPCommandPlatformMacOS toPlatform:CPCommandPlatformLinux];
}

- (NSString *)windowsEquivalentFor:(NSString *)command {
    return [self translateCommand:command fromPlatform:CPCommandPlatformMacOS toPlatform:CPCommandPlatformWindows];
}

- (BOOL)isCommandAvailable:(NSString *)command {
    // Check builtins
    if ([self isBuiltinCommand:command]) return YES;
    
    // Check aliases
    if (self.aliasMap[command]) return YES;
    
    // Check PATH
    return [self resolveExecutable:command] != nil;
}

- (CPCommandPlatform)detectCommandPlatform:(NSString *)command {
    NSSet *windowsOnly = [NSSet setWithArray:@[@"dir", @"copy", @"move", @"del", @"ren", @"md", @"rd", 
                                               @"type", @"cls", @"findstr", @"tasklist", @"taskkill",
                                               @"ipconfig", @"tracert", @"systeminfo", @"netsh",
                                               @"chkdsk", @"diskpart", @"format", @"schtasks"]];
    
    NSSet *unixOnly = [NSSet setWithArray:@[@"grep", @"sed", @"awk", @"chmod", @"chown", @"ln",
                                            @"tar", @"gzip", @"bzip2", @"ifconfig", @"traceroute",
                                            @"crontab", @"sudo", @"apt", @"yum", @"pacman"]];
    
    NSSet *macOSOnly = [NSSet setWithArray:@[@"brew", @"defaults", @"plutil", @"hdiutil", @"diskutil",
                                             @"launchctl", @"pmset", @"say", @"afplay", @"osascript",
                                             @"pbcopy", @"pbpaste", @"open", @"dscl", @"sw_vers",
                                             @"system_profiler", @"airport", @"networksetup"]];
    
    if ([windowsOnly containsObject:command]) return CPCommandPlatformWindows;
    if ([macOSOnly containsObject:command]) return CPCommandPlatformMacOS;
    if ([unixOnly containsObject:command]) return CPCommandPlatformPOSIX;
    
    return CPCommandPlatformUniversal;
}

- (BOOL)isBuiltinCommand:(NSString *)command {
    NSSet *builtins = [NSSet setWithArray:@[@"cd", @"pwd", @"echo", @"export", @"unset", @"alias",
                                            @"unalias", @"history", @"clear", @"exit", @"source",
                                            @"type", @"which", @"help", @"set", @"env", @"printenv",
                                            @"read", @"test", @"true", @"false", @"jobs", @"fg",
                                            @"bg", @"wait", @"kill", @"trap", @"umask", @"ulimit",
                                            @"pushd", @"popd", @"dirs", @".", @":", @"["]];
    return [builtins containsObject:command];
}

@end
