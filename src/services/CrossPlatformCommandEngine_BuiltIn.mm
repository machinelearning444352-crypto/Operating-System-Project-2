#import "CrossPlatformCommandEngine.h"
#import <sys/stat.h>
#import <sys/resource.h>

@interface CrossPlatformCommandEngine ()
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *aliasMap;
@property (nonatomic, strong) NSMutableArray<NSString *> *directoryStack;
@end

@implementation CrossPlatformCommandEngine (BuiltIn)

#pragma mark - Basic Built-in Commands

- (CPCommandResult *)builtinCd:(NSArray *)args {
    NSString *targetDir;
    
    if (args.count == 0 || [args[0] isEqualToString:@"~"]) {
        targetDir = NSHomeDirectory();
    } else if ([args[0] isEqualToString:@"-"]) {
        targetDir = self.currentSession.environment[@"OLDPWD"] ?: NSHomeDirectory();
    } else {
        targetDir = args[0];
        if ([targetDir hasPrefix:@"~"]) {
            targetDir = [NSHomeDirectory() stringByAppendingPathComponent:[targetDir substringFromIndex:1]];
        }
        if (![targetDir hasPrefix:@"/"]) {
            targetDir = [self.currentSession.workingDirectory stringByAppendingPathComponent:targetDir];
        }
    }
    
    targetDir = [targetDir stringByStandardizingPath];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir;
    if (![fm fileExistsAtPath:targetDir isDirectory:&isDir] || !isDir) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"cd: %@: No such file or directory", args.count > 0 ? args[0] : @"~"] code:1];
    }
    
    self.currentSession.environment[@"OLDPWD"] = self.currentSession.workingDirectory;
    self.currentSession.workingDirectory = targetDir;
    self.currentSession.environment[@"PWD"] = targetDir;
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinPwd:(NSArray *)args {
    BOOL logical = YES;
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-P"]) logical = NO;
        else if ([arg isEqualToString:@"-L"]) logical = YES;
    }
    
    NSString *path = self.currentSession.workingDirectory;
    if (!logical) {
        path = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:path error:nil] ?: path;
    }
    
    return [CPCommandResult successWithOutput:[path stringByAppendingString:@"\n"]];
}

- (CPCommandResult *)builtinEcho:(NSArray *)args {
    BOOL noNewline = NO;
    BOOL interpretEscapes = NO;
    NSMutableArray *textArgs = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-n"]) noNewline = YES;
        else if ([arg isEqualToString:@"-e"]) interpretEscapes = YES;
        else if ([arg isEqualToString:@"-E"]) interpretEscapes = NO;
        else [textArgs addObject:arg];
    }
    
    NSString *output = [textArgs componentsJoinedByString:@" "];
    
    if (interpretEscapes) {
        output = [output stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
        output = [output stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"];
        output = [output stringByReplacingOccurrencesOfString:@"\\r" withString:@"\r"];
        output = [output stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
    }
    
    if (!noNewline) {
        output = [output stringByAppendingString:@"\n"];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)builtinExport:(NSArray *)args {
    if (args.count == 0) {
        NSMutableString *output = [NSMutableString string];
        for (NSString *key in self.currentSession.environment) {
            [output appendFormat:@"declare -x %@=\"%@\"\n", key, self.currentSession.environment[key]];
        }
        return [CPCommandResult successWithOutput:output];
    }
    
    for (NSString *arg in args) {
        NSRange eqRange = [arg rangeOfString:@"="];
        if (eqRange.location != NSNotFound) {
            NSString *name = [arg substringToIndex:eqRange.location];
            NSString *value = [arg substringFromIndex:eqRange.location + 1];
            value = [value stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\"'"]];
            self.currentSession.environment[name] = value;
        } else {
            [self exportVariable:arg];
        }
    }
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinUnset:(NSArray *)args {
    for (NSString *name in args) {
        [self.currentSession.environment removeObjectForKey:name];
    }
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinAlias:(NSArray *)args {
    if (args.count == 0) {
        NSMutableString *output = [NSMutableString string];
        for (NSString *name in self.aliasMap) {
            [output appendFormat:@"alias %@='%@'\n", name, self.aliasMap[name]];
        }
        return [CPCommandResult successWithOutput:output];
    }
    
    for (NSString *arg in args) {
        NSRange eqRange = [arg rangeOfString:@"="];
        if (eqRange.location != NSNotFound) {
            NSString *name = [arg substringToIndex:eqRange.location];
            NSString *value = [arg substringFromIndex:eqRange.location + 1];
            value = [value stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\"'"]];
            self.aliasMap[name] = value;
        } else {
            NSString *expansion = self.aliasMap[arg];
            if (expansion) {
                return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"alias %@='%@'\n", arg, expansion]];
            } else {
                return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"alias: %@: not found", arg] code:1];
            }
        }
    }
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinUnalias:(NSArray *)args {
    BOOL removeAll = NO;
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-a"]) {
            removeAll = YES;
        }
    }
    
    if (removeAll) {
        [self.aliasMap removeAllObjects];
    } else {
        for (NSString *name in args) {
            if (![name hasPrefix:@"-"]) {
                [self.aliasMap removeObjectForKey:name];
            }
        }
    }
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinHistory:(NSArray *)args {
    NSInteger count = self.currentSession.history.count;
    NSInteger start = 0;
    BOOL clear = NO;
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-c"]) {
            clear = YES;
        } else if ([arg integerValue] > 0) {
            NSInteger n = [arg integerValue];
            start = MAX(0, count - n);
        }
    }
    
    if (clear) {
        [self.currentSession.history removeAllObjects];
        return [CPCommandResult successWithOutput:@""];
    }
    
    NSMutableString *output = [NSMutableString string];
    for (NSInteger i = start; i < count; i++) {
        CPCommandHistoryEntry *entry = self.currentSession.history[i];
        [output appendFormat:@"%5ld  %@\n", (long)(i + 1), entry.command];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)builtinClear:(NSArray *)args {
    return [CPCommandResult successWithOutput:@"\033[2J\033[H"];
}

- (CPCommandResult *)builtinExit:(NSArray *)args {
    int code = 0;
    if (args.count > 0) {
        code = [args[0] intValue];
    }
    
    CPCommandResult *result = [[CPCommandResult alloc] init];
    result.output = @"";
    result.exitCode = code;
    result.success = YES;
    result.metadata = @{@"action": @"exit"};
    return result;
}

- (CPCommandResult *)builtinSource:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"source: filename argument required" code:2];
    }
    
    NSString *filename = args[0];
    if (![filename hasPrefix:@"/"]) {
        filename = [self.currentSession.workingDirectory stringByAppendingPathComponent:filename];
    }
    
    NSString *content = [NSString stringWithContentsOfFile:filename encoding:NSUTF8StringEncoding error:nil];
    if (!content) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"source: %@: No such file or directory", args[0]] code:1];
    }
    
    NSMutableString *output = [NSMutableString string];
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    
    for (NSString *line in lines) {
        NSString *trimmed = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if (trimmed.length > 0 && ![trimmed hasPrefix:@"#"]) {
            CPCommandResult *result = [self executeCommand:trimmed];
            if (result.output.length > 0) {
                [output appendString:result.output];
            }
            if (!result.success) {
                return result;
            }
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)builtinDot:(NSArray *)args {
    return [self builtinSource:args];
}

- (CPCommandResult *)builtinType:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"type: usage: type name [name ...]" code:2];
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *name in args) {
        if (self.aliasMap[name]) {
            [output appendFormat:@"%@ is aliased to '%@'\n", name, self.aliasMap[name]];
        } else if ([self isBuiltinCommand:name]) {
            [output appendFormat:@"%@ is a shell builtin\n", name];
        } else {
            NSString *path = [self resolveExecutable:name];
            if (path) {
                [output appendFormat:@"%@ is %@\n", name, path];
            } else {
                [output appendFormat:@"-bash: type: %@: not found\n", name];
            }
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)builtinWhich:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"usage: which command ..." code:1];
    }
    
    NSMutableString *output = [NSMutableString string];
    BOOL allFound = YES;
    
    for (NSString *name in args) {
        NSString *path = [self resolveExecutable:name];
        if (path) {
            [output appendFormat:@"%@\n", path];
        } else {
            [output appendFormat:@"%@ not found\n", name];
            allFound = NO;
        }
    }
    
    CPCommandResult *result = [CPCommandResult successWithOutput:output];
    result.exitCode = allFound ? 0 : 1;
    result.success = allFound;
    return result;
}

- (CPCommandResult *)builtinHelp:(NSArray *)args {
    if (args.count == 0) {
        NSString *helpText = @"CrossPlatform Command Engine - Built-in Commands:\n\n"
        @"  cd [dir]         Change the shell working directory\n"
        @"  pwd              Print the current working directory\n"
        @"  echo [args]      Display a line of text\n"
        @"  export [name=value]  Set export attribute for variables\n"
        @"  unset [name]     Unset values and attributes of variables\n"
        @"  alias [name=value]   Define or display aliases\n"
        @"  unalias [name]   Remove alias definitions\n"
        @"  history          Display command history\n"
        @"  clear            Clear the terminal screen\n"
        @"  exit [n]         Exit the shell\n"
        @"  source [file]    Execute commands from a file\n"
        @"  type [name]      Describe a command\n"
        @"  which [name]     Locate a command\n"
        @"  help [cmd]       Display help information\n"
        @"  set              Set or unset shell options\n"
        @"  env              Print environment variables\n"
        @"  printenv [name]  Print environment variables\n"
        @"  kill [pid]       Send signal to processes\n"
        @"  jobs             List active jobs\n"
        @"  fg [job]         Move job to foreground\n"
        @"  bg [job]         Move job to background\n"
        @"  pushd [dir]      Push directory onto stack\n"
        @"  popd             Pop directory from stack\n"
        @"  dirs             Display directory stack\n\n"
        @"For more information, type 'help <command>'\n";
        return [CPCommandResult successWithOutput:helpText];
    }
    
    NSString *cmd = args[0];
    NSDictionary *helpTexts = @{
        @"cd": @"cd: cd [-L|-P] [dir]\n    Change the shell working directory.\n\n    Options:\n      -L  Force symbolic links to be followed\n      -P  Use the physical directory structure\n",
        @"pwd": @"pwd: pwd [-LP]\n    Print the name of the current working directory.\n\n    Options:\n      -L  Print the value of $PWD if it names the current working directory\n      -P  Print the physical directory, without any symbolic links\n",
        @"echo": @"echo: echo [-neE] [arg ...]\n    Write arguments to the standard output.\n\n    Options:\n      -n  Do not output the trailing newline\n      -e  Enable interpretation of backslash escapes\n      -E  Disable interpretation of backslash escapes (default)\n",
        @"export": @"export: export [name[=value] ...]\n    Set export attribute for shell variables.\n",
        @"alias": @"alias: alias [name[=value] ...]\n    Define or display aliases.\n",
        @"history": @"history: history [-c] [n]\n    Display or manipulate the history list.\n\n    Options:\n      -c  Clear the history list\n      n   Display the last n entries\n"
    };
    
    NSString *help = helpTexts[cmd];
    if (help) {
        return [CPCommandResult successWithOutput:help];
    }
    
    return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"help: no help topics match '%@'", cmd] code:1];
}

- (CPCommandResult *)builtinSet:(NSArray *)args {
    if (args.count == 0) {
        NSMutableString *output = [NSMutableString string];
        for (NSString *key in self.currentSession.environment) {
            [output appendFormat:@"%@=%@\n", key, self.currentSession.environment[key]];
        }
        return [CPCommandResult successWithOutput:output];
    }
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinEnv:(NSArray *)args {
    NSMutableString *output = [NSMutableString string];
    for (NSString *key in self.currentSession.environment) {
        [output appendFormat:@"%@=%@\n", key, self.currentSession.environment[key]];
    }
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)builtinPrintenv:(NSArray *)args {
    if (args.count == 0) {
        return [self builtinEnv:args];
    }
    
    NSMutableString *output = [NSMutableString string];
    for (NSString *name in args) {
        NSString *value = self.currentSession.environment[name];
        if (value) {
            [output appendFormat:@"%@\n", value];
        }
    }
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)builtinRead:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinTest:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"" code:1];
    }
    
    NSMutableArray *testArgs = [args mutableCopy];
    if ([testArgs.lastObject isEqualToString:@"]"]) {
        [testArgs removeLastObject];
    }
    
    if (testArgs.count == 0) {
        return [CPCommandResult errorWithMessage:@"" code:1];
    }
    
    if (testArgs.count == 1) {
        return [testArgs[0] length] > 0 ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
    }
    
    if (testArgs.count == 2) {
        NSString *op = testArgs[0];
        NSString *val = testArgs[1];
        
        if ([op isEqualToString:@"-n"]) {
            return val.length > 0 ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
        if ([op isEqualToString:@"-z"]) {
            return val.length == 0 ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
        if ([op isEqualToString:@"-e"] || [op isEqualToString:@"-a"]) {
            BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:val];
            return exists ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
        if ([op isEqualToString:@"-f"]) {
            BOOL isDir;
            BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:val isDirectory:&isDir];
            return (exists && !isDir) ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
        if ([op isEqualToString:@"-d"]) {
            BOOL isDir;
            BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:val isDirectory:&isDir];
            return (exists && isDir) ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
        if ([op isEqualToString:@"-r"]) {
            BOOL readable = [[NSFileManager defaultManager] isReadableFileAtPath:val];
            return readable ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
        if ([op isEqualToString:@"-w"]) {
            BOOL writable = [[NSFileManager defaultManager] isWritableFileAtPath:val];
            return writable ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
        if ([op isEqualToString:@"-x"]) {
            BOOL executable = [[NSFileManager defaultManager] isExecutableFileAtPath:val];
            return executable ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
    }
    
    if (testArgs.count == 3) {
        NSString *left = testArgs[0];
        NSString *op = testArgs[1];
        NSString *right = testArgs[2];
        
        if ([op isEqualToString:@"="] || [op isEqualToString:@"=="]) {
            return [left isEqualToString:right] ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
        if ([op isEqualToString:@"!="]) {
            return ![left isEqualToString:right] ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
        if ([op isEqualToString:@"-eq"]) {
            return [left integerValue] == [right integerValue] ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
        if ([op isEqualToString:@"-ne"]) {
            return [left integerValue] != [right integerValue] ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
        if ([op isEqualToString:@"-lt"]) {
            return [left integerValue] < [right integerValue] ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
        if ([op isEqualToString:@"-le"]) {
            return [left integerValue] <= [right integerValue] ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
        if ([op isEqualToString:@"-gt"]) {
            return [left integerValue] > [right integerValue] ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
        if ([op isEqualToString:@"-ge"]) {
            return [left integerValue] >= [right integerValue] ? [CPCommandResult successWithOutput:@""] : [CPCommandResult errorWithMessage:@"" code:1];
        }
    }
    
    return [CPCommandResult errorWithMessage:@"" code:1];
}

- (CPCommandResult *)builtinTrue:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinFalse:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"" code:1];
}

- (CPCommandResult *)builtinJobs:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinFg:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinBg:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinWait:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinKill:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"kill: usage: kill [-s sigspec | -signum | -sigspec] [pid | job]..." code:2];
    }
    
    int signal = SIGTERM;
    NSMutableArray *pids = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"]) {
            NSString *sigArg = [arg substringFromIndex:1];
            if ([sigArg isEqualToString:@"9"] || [sigArg.uppercaseString isEqualToString:@"KILL"]) {
                signal = SIGKILL;
            } else if ([sigArg isEqualToString:@"15"] || [sigArg.uppercaseString isEqualToString:@"TERM"]) {
                signal = SIGTERM;
            } else if ([sigArg isEqualToString:@"2"] || [sigArg.uppercaseString isEqualToString:@"INT"]) {
                signal = SIGINT;
            } else if ([sigArg isEqualToString:@"1"] || [sigArg.uppercaseString isEqualToString:@"HUP"]) {
                signal = SIGHUP;
            }
        } else {
            [pids addObject:arg];
        }
    }
    
    for (NSString *pidStr in pids) {
        pid_t pid = (pid_t)[pidStr intValue];
        if (kill(pid, signal) != 0) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"kill: (%@) - No such process", pidStr] code:1];
        }
    }
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinTrap:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinUmask:(NSArray *)args {
    mode_t currentMask = umask(0);
    umask(currentMask);
    
    if (args.count == 0) {
        return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"%04o\n", currentMask]];
    }
    
    NSString *maskStr = args[0];
    mode_t newMask = (mode_t)strtol([maskStr UTF8String], NULL, 8);
    umask(newMask);
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinUlimit:(NSArray *)args {
    struct rlimit rl;
    getrlimit(RLIMIT_NOFILE, &rl);
    return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"%llu\n", rl.rlim_cur]];
}

- (CPCommandResult *)builtinTimes:(NSArray *)args {
    struct rusage usage;
    getrusage(RUSAGE_SELF, &usage);
    
    NSString *output = [NSString stringWithFormat:@"%ldm%ld.%03lds %ldm%ld.%03lds\n%ldm%ld.%03lds %ldm%ld.%03lds\n",
                        usage.ru_utime.tv_sec / 60, usage.ru_utime.tv_sec % 60, usage.ru_utime.tv_usec / 1000,
                        usage.ru_stime.tv_sec / 60, usage.ru_stime.tv_sec % 60, usage.ru_stime.tv_usec / 1000,
                        0L, 0L, 0L, 0L, 0L, 0L];
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)builtinShift:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinGetopts:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinHash:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinCommand:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult successWithOutput:@""];
    }
    return [self executeCommand:[args componentsJoinedByString:@" "]];
}

- (CPCommandResult *)builtinBuiltin:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult successWithOutput:@""];
    }
    
    NSString *cmd = args[0];
    NSArray *cmdArgs = args.count > 1 ? [args subarrayWithRange:NSMakeRange(1, args.count - 1)] : @[];
    
    SEL selector = NSSelectorFromString([NSString stringWithFormat:@"builtin%@:", [cmd capitalizedString]]);
    if ([self respondsToSelector:selector]) {
        #pragma clang diagnostic push
        #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        return [self performSelector:selector withObject:cmdArgs];
        #pragma clang diagnostic pop
    }
    
    return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"builtin: %@: not a shell builtin", cmd] code:1];
}

- (CPCommandResult *)builtinEnable:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinDisable:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinDeclare:(NSArray *)args {
    return [self builtinExport:args];
}

- (CPCommandResult *)builtinLocal:(NSArray *)args {
    return [self builtinExport:args];
}

- (CPCommandResult *)builtinReadonly:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinTypeset:(NSArray *)args {
    return [self builtinDeclare:args];
}

- (CPCommandResult *)builtinLet:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"let: usage: let arg [arg ...]" code:2];
    }
    
    for (NSString *expr in args) {
        NSExpression *expression = [NSExpression expressionWithFormat:expr];
        @try {
            [expression expressionValueWithObject:nil context:nil];
        } @catch (NSException *e) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"let: %@: syntax error", expr] code:1];
        }
    }
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinEval:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult successWithOutput:@""];
    }
    return [self executeCommand:[args componentsJoinedByString:@" "]];
}

- (CPCommandResult *)builtinExec:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult successWithOutput:@""];
    }
    return [self executeCommand:[args componentsJoinedByString:@" "]];
}

- (CPCommandResult *)builtinColon:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinBreak:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinContinue:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinReturn:(NSArray *)args {
    int code = args.count > 0 ? [args[0] intValue] : 0;
    CPCommandResult *result = [CPCommandResult successWithOutput:@""];
    result.exitCode = code;
    return result;
}

- (CPCommandResult *)builtinPushd:(NSArray *)args {
    NSString *dir = args.count > 0 ? args[0] : nil;
    
    [self.directoryStack addObject:self.currentSession.workingDirectory];
    
    if (dir) {
        CPCommandResult *result = [self builtinCd:@[dir]];
        if (!result.success) {
            [self.directoryStack removeLastObject];
            return result;
        }
    }
    
    return [self builtinDirs:@[]];
}

- (CPCommandResult *)builtinPopd:(NSArray *)args {
    if (self.directoryStack.count == 0) {
        return [CPCommandResult errorWithMessage:@"popd: directory stack empty" code:1];
    }
    
    NSString *dir = self.directoryStack.lastObject;
    [self.directoryStack removeLastObject];
    
    return [self builtinCd:@[dir]];
}

- (CPCommandResult *)builtinDirs:(NSArray *)args {
    NSMutableString *output = [NSMutableString stringWithString:self.currentSession.workingDirectory];
    
    for (NSInteger i = self.directoryStack.count - 1; i >= 0; i--) {
        [output appendFormat:@" %@", self.directoryStack[i]];
    }
    [output appendString:@"\n"];
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)builtinSuspend:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinLogout:(NSArray *)args {
    return [self builtinExit:args];
}

- (CPCommandResult *)builtinCompgen:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinComplete:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinCompopt:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinBind:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinShopt:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinMapfile:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)builtinReadarray:(NSArray *)args {
    return [self builtinMapfile:args];
}

- (CPCommandResult *)builtinCoproc:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

#pragma mark - Helper Methods

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
