#import "CrossPlatformCommandEngine.h"

@implementation CrossPlatformCommandEngine (MiscCommands)

#pragma mark - Help/Documentation

- (CPCommandResult *)cmdMan:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"man: missing page argument" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/man";
    task.arguments = args;
    task.environment = @{@"PAGER": @"cat"};
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output ?: @""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"man: failed" code:1];
    }
}

- (CPCommandResult *)cmdInfo:(NSArray *)args {
    return [self cmdMan:args];
}

- (CPCommandResult *)cmdApropos:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"apropos: missing keyword" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/apropos";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output ?: @""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"apropos: failed" code:1];
    }
}

- (CPCommandResult *)cmdWhatis:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"whatis: missing argument" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/whatis";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output ?: @""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"whatis: failed" code:1];
    }
}

#pragma mark - Utilities

- (CPCommandResult *)cmdYes:(NSArray *)args {
    NSString *text = args.count > 0 ? [args componentsJoinedByString:@" "] : @"y";
    NSMutableString *output = [NSMutableString string];
    for (int i = 0; i < 10; i++) {
        [output appendFormat:@"%@\n", text];
    }
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdSeq:(NSArray *)args {
    NSInteger first = 1, increment = 1, last = 1;
    
    if (args.count == 1) {
        last = [args[0] integerValue];
    } else if (args.count == 2) {
        first = [args[0] integerValue];
        last = [args[1] integerValue];
    } else if (args.count >= 3) {
        first = [args[0] integerValue];
        increment = [args[1] integerValue];
        last = [args[2] integerValue];
    }
    
    NSMutableString *output = [NSMutableString string];
    if (increment > 0) {
        for (NSInteger i = first; i <= last; i += increment) {
            [output appendFormat:@"%ld\n", (long)i];
        }
    } else if (increment < 0) {
        for (NSInteger i = first; i >= last; i += increment) {
            [output appendFormat:@"%ld\n", (long)i];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdSleep:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"sleep: missing operand" code:1];
    }
    
    double seconds = [args[0] doubleValue];
    [NSThread sleepForTimeInterval:seconds];
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)cmdWait:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)cmdPrintf:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult successWithOutput:@""];
    }
    
    NSString *format = args[0];
    format = [format stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
    format = [format stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"];
    
    if (args.count == 1) {
        return [CPCommandResult successWithOutput:format];
    }
    
    return [CPCommandResult successWithOutput:format];
}

#pragma mark - Fun Commands

- (CPCommandResult *)cmdBanner:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"banner: missing text" code:1];
    }
    
    NSString *text = [[args componentsJoinedByString:@" "] uppercaseString];
    NSMutableString *output = [NSMutableString string];
    
    [output appendString:@"  ____   _   _   _   _   _____   ____  \n"];
    [output appendFormat:@" |%@|\n", text];
    [output appendString:@"  ‾‾‾‾   ‾   ‾   ‾   ‾   ‾‾‾‾‾   ‾‾‾‾  \n"];
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdFiglet:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"figlet: not installed, use 'brew install figlet'" code:1];
}

- (CPCommandResult *)cmdCowsay:(NSArray *)args {
    NSString *text = args.count > 0 ? [args componentsJoinedByString:@" "] : @"Moo!";
    
    NSMutableString *output = [NSMutableString string];
    NSString *border = [@"" stringByPaddingToLength:text.length + 2 withString:@"-" startingAtIndex:0];
    
    [output appendFormat:@" %@ \n", border];
    [output appendFormat:@"< %@ >\n", text];
    [output appendFormat:@" %@ \n", border];
    [output appendString:@"        \\   ^__^\n"];
    [output appendString:@"         \\  (oo)\\_______\n"];
    [output appendString:@"            (__)\\       )\\/\\\n"];
    [output appendString:@"                ||----w |\n"];
    [output appendString:@"                ||     ||\n"];
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdLolcat:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"lolcat: not installed" code:1];
}

- (CPCommandResult *)cmdFortune:(NSArray *)args {
    NSArray *fortunes = @[
        @"A journey of a thousand miles begins with a single step.",
        @"The best time to plant a tree was 20 years ago. The second best time is now.",
        @"In the middle of difficulty lies opportunity.",
        @"The only way to do great work is to love what you do.",
        @"Life is what happens when you're busy making other plans.",
        @"Unix is user-friendly. It's just selective about who its friends are."
    ];
    
    NSString *fortune = fortunes[arc4random_uniform((uint32_t)fortunes.count)];
    return [CPCommandResult successWithOutput:[fortune stringByAppendingString:@"\n"]];
}

- (CPCommandResult *)cmdCmatrix:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"cmatrix: not installed" code:1];
}

- (CPCommandResult *)cmdSl:(NSArray *)args {
    NSMutableString *output = [NSMutableString string];
    [output appendString:@"      ====        ________                ___________\n"];
    [output appendString:@"  _D _|  |_______/        \\__I_I_____===__|_________|_\n"];
    [output appendString:@"   |(_)---  |   H\\________/ |   |        =|___ ___|   \n"];
    [output appendString:@"   /     |  |   H  |  |     |   |         ||_| |_||   \n"];
    [output appendString:@"  |      |  |   H  |__--------------------| [___] |   \n"];
    [output appendString:@"  | ________|___H__/__|_____/[][]~\\_______|       |   \n"];
    [output appendString:@"  |/ |   |-----------I_____I [][] []  D   |=======|__ \n"];
    return [CPCommandResult successWithOutput:output];
}

#pragma mark - Math

- (CPCommandResult *)cmdFactor:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"factor: missing operand" code:1];
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *arg in args) {
        NSInteger n = [arg integerValue];
        if (n <= 1) continue;
        
        [output appendFormat:@"%ld:", (long)n];
        
        NSInteger num = n;
        for (NSInteger i = 2; i * i <= num; i++) {
            while (num % i == 0) {
                [output appendFormat:@" %ld", (long)i];
                num /= i;
            }
        }
        if (num > 1) {
            [output appendFormat:@" %ld", (long)num];
        }
        [output appendString:@"\n"];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdPrimes:(NSArray *)args {
    NSInteger start = 2, end = 100;
    
    if (args.count >= 1) start = [args[0] integerValue];
    if (args.count >= 2) end = [args[1] integerValue];
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSInteger n = start; n <= end; n++) {
        BOOL isPrime = YES;
        if (n < 2) isPrime = NO;
        else {
            for (NSInteger i = 2; i * i <= n; i++) {
                if (n % i == 0) {
                    isPrime = NO;
                    break;
                }
            }
        }
        if (isPrime) {
            [output appendFormat:@"%ld\n", (long)n];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdBc:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"bc: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdDc:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"dc: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdExpr:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"expr: missing operand" code:1];
    }
    
    NSString *expr = [args componentsJoinedByString:@" "];
    expr = [expr stringByReplacingOccurrencesOfString:@"+" withString:@" + "];
    expr = [expr stringByReplacingOccurrencesOfString:@"-" withString:@" - "];
    expr = [expr stringByReplacingOccurrencesOfString:@"*" withString:@" * "];
    expr = [expr stringByReplacingOccurrencesOfString:@"/" withString:@" / "];
    
    @try {
        NSExpression *expression = [NSExpression expressionWithFormat:expr];
        id result = [expression expressionValueWithObject:nil context:nil];
        return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"%@\n", result]];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"expr: syntax error" code:2];
    }
}

#pragma mark - Path Utilities

- (CPCommandResult *)cmdBasename:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"basename: missing operand" code:1];
    }
    
    NSString *path = args[0];
    NSString *suffix = args.count > 1 ? args[1] : nil;
    
    NSString *base = [path lastPathComponent];
    if (suffix && [base hasSuffix:suffix]) {
        base = [base substringToIndex:base.length - suffix.length];
    }
    
    return [CPCommandResult successWithOutput:[base stringByAppendingString:@"\n"]];
}

- (CPCommandResult *)cmdDirname:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"dirname: missing operand" code:1];
    }
    
    NSString *path = args[0];
    NSString *dir = [path stringByDeletingLastPathComponent];
    if (dir.length == 0) dir = @".";
    
    return [CPCommandResult successWithOutput:[dir stringByAppendingString:@"\n"]];
}

- (CPCommandResult *)cmdRealpath:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"realpath: missing operand" code:1];
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *path in args) {
        NSString *fullPath = [path hasPrefix:@"/"] ? path : [self.currentSession.workingDirectory stringByAppendingPathComponent:path];
        NSString *resolved = [fullPath stringByResolvingSymlinksInPath];
        [output appendFormat:@"%@\n", resolved];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdReadlink:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"readlink: missing operand" code:1];
    }
    
    NSString *path = args[0];
    NSString *fullPath = [path hasPrefix:@"/"] ? path : [self.currentSession.workingDirectory stringByAppendingPathComponent:path];
    
    NSString *dest = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath:fullPath error:nil];
    if (!dest) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"readlink: %@: Invalid argument", path] code:1];
    }
    
    return [CPCommandResult successWithOutput:[dest stringByAppendingString:@"\n"]];
}

- (CPCommandResult *)cmdMktemp:(NSArray *)args {
    BOOL isDirectory = NO;
    NSString *templateStr = @"tmp.XXXXXX";
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-d"]) isDirectory = YES;
        else if (![arg hasPrefix:@"-"]) templateStr = arg;
    }
    
    NSString *tempDir = NSTemporaryDirectory();
    NSString *name = [templateStr stringByReplacingOccurrencesOfString:@"XXXXXX" 
                                                         withString:[NSString stringWithFormat:@"%06u", arc4random_uniform(1000000)]];
    NSString *path = [tempDir stringByAppendingPathComponent:name];
    
    if (isDirectory) {
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
    } else {
        [[NSFileManager defaultManager] createFileAtPath:path contents:[NSData data] attributes:nil];
    }
    
    return [CPCommandResult successWithOutput:[path stringByAppendingString:@"\n"]];
}

- (CPCommandResult *)cmdTruncate:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"truncate: not implemented" code:1];
}

- (CPCommandResult *)cmdFallocate:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"fallocate: Linux only" code:1];
}

- (CPCommandResult *)cmdDd:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"dd: complex operation, use native shell" code:1];
}

- (CPCommandResult *)cmdSync:(NSArray *)args {
    sync();
    return [CPCommandResult successWithOutput:@""];
}

#pragma mark - Terminal

- (CPCommandResult *)cmdTty:(NSArray *)args {
    return [CPCommandResult successWithOutput:@"/dev/ttys000\n"];
}

- (CPCommandResult *)cmdStty:(NSArray *)args {
    return [CPCommandResult successWithOutput:@"speed 9600 baud;\n"];
}

- (CPCommandResult *)cmdReset:(NSArray *)args {
    return [CPCommandResult successWithOutput:@"\033c"];
}

- (CPCommandResult *)cmdTput:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"tput: missing operand" code:1];
    }
    
    NSString *cap = args[0];
    
    if ([cap isEqualToString:@"cols"]) return [CPCommandResult successWithOutput:@"80\n"];
    if ([cap isEqualToString:@"lines"]) return [CPCommandResult successWithOutput:@"24\n"];
    if ([cap isEqualToString:@"clear"]) return [CPCommandResult successWithOutput:@"\033[2J\033[H"];
    if ([cap isEqualToString:@"bold"]) return [CPCommandResult successWithOutput:@"\033[1m"];
    if ([cap isEqualToString:@"sgr0"]) return [CPCommandResult successWithOutput:@"\033[0m"];
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)cmdSetterm:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"setterm: Linux only" code:1];
}

- (CPCommandResult *)cmdScreen:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"screen: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdTmux:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"tmux: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdByobu:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"byobu: interactive mode not supported" code:1];
}

#pragma mark - Editors

- (CPCommandResult *)cmdVim:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"vim: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdNvim:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"nvim: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdEmacs:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"emacs: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdNano:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"nano: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdPico:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"pico: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdEd:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"ed: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdEx:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"ex: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdVi:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"vi: interactive mode not supported" code:1];
}

#pragma mark - Open/Launch

- (CPCommandResult *)cmdOpen:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"open: missing argument" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/open";
    task.arguments = args;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
    @try {
        [task launch];
        [task waitUntilExit];
        return [CPCommandResult successWithOutput:@""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"open: failed" code:1];
    }
}

- (CPCommandResult *)cmdXdgOpen:(NSArray *)args {
    return [self cmdOpen:args];
}

- (CPCommandResult *)cmdStart:(NSArray *)args {
    return [self cmdOpen:args];
}

- (CPCommandResult *)cmdExplorer:(NSArray *)args {
    return [self cmdOpen:args];
}

#pragma mark - Clipboard

- (CPCommandResult *)cmdPbcopy:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"pbcopy: requires stdin" code:1];
}

- (CPCommandResult *)cmdPbpaste:(NSArray *)args {
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    NSString *content = [pb stringForType:NSPasteboardTypeString];
    return [CPCommandResult successWithOutput:content ?: @""];
}

- (CPCommandResult *)cmdXclip:(NSArray *)args {
    return [self cmdPbcopy:args];
}

- (CPCommandResult *)cmdXsel:(NSArray *)args {
    return [self cmdPbcopy:args];
}

- (CPCommandResult *)cmdClip:(NSArray *)args {
    return [self cmdPbcopy:args];
}

#pragma mark - Audio/Speech

- (CPCommandResult *)cmdSay:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"say: missing text" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/say";
    task.arguments = args;
    
    @try {
        [task launch];
        [task waitUntilExit];
        return [CPCommandResult successWithOutput:@""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"say: failed" code:1];
    }
}

- (CPCommandResult *)cmdEspeak:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"espeak: not installed, use 'say' on macOS" code:1];
}

- (CPCommandResult *)cmdAfplay:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"afplay: missing file" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/afplay";
    task.arguments = args;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
    @try {
        [task launch];
        [task waitUntilExit];
        return [CPCommandResult successWithOutput:@""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"afplay: failed" code:1];
    }
}

- (CPCommandResult *)cmdAplay:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"aplay: Linux only, use afplay on macOS" code:1];
}

#pragma mark - macOS Scripting

- (CPCommandResult *)cmdOsascript:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"osascript: missing script" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/osascript";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output ?: @""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"osascript: failed" code:1];
    }
}

- (CPCommandResult *)cmdAutomator:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"automator: GUI application" code:1];
}

#pragma mark - Security

- (CPCommandResult *)cmdSecurity:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/security";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output ?: @""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"security: failed" code:1];
    }
}

- (CPCommandResult *)cmdKeychain:(NSArray *)args {
    return [self cmdSecurity:args];
}

- (CPCommandResult *)cmdOpenssl:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/openssl";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output ?: @""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"openssl: failed" code:1];
    }
}

- (CPCommandResult *)cmdSsh_keygen:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"ssh-keygen: interactive mode required for passphrase" code:1];
}

- (CPCommandResult *)cmdSsh_add:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"ssh-add: may require passphrase" code:1];
}

- (CPCommandResult *)cmdSsh_agent:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"ssh-agent: use native shell" code:1];
}

- (CPCommandResult *)cmdGpg:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"gpg: not installed" code:1];
}

- (CPCommandResult *)cmdAge:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"age: not installed" code:1];
}

- (CPCommandResult *)cmdPass:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"pass: not installed" code:1];
}

#pragma mark - Data Processing

- (CPCommandResult *)cmdJq:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"jq: not installed, use 'brew install jq'" code:1];
}

- (CPCommandResult *)cmdYq:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"yq: not installed" code:1];
}

- (CPCommandResult *)cmdXq:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"xq: not installed" code:1];
}

- (CPCommandResult *)cmdCsvtool:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"csvtool: not installed" code:1];
}

- (CPCommandResult *)cmdMiller:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"mlr: not installed" code:1];
}

#pragma mark - Databases

- (CPCommandResult *)cmdSqlite3:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"sqlite3: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdMysql:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"mysql: not installed" code:1];
}

- (CPCommandResult *)cmdPsql:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"psql: not installed" code:1];
}

- (CPCommandResult *)cmdMongo:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"mongo: not installed" code:1];
}

- (CPCommandResult *)cmdRedis_cli:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"redis-cli: not installed" code:1];
}

- (CPCommandResult *)cmdEtcdctl:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"etcdctl: not installed" code:1];
}

- (CPCommandResult *)cmdConsul:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"consul: not installed" code:1];
}

- (CPCommandResult *)cmdVault:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"vault: not installed" code:1];
}

#pragma mark - Cloud CLIs

- (CPCommandResult *)cmdAws:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"aws: not installed" code:1];
}

- (CPCommandResult *)cmdGcloud:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"gcloud: not installed" code:1];
}

- (CPCommandResult *)cmdAz:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"az: not installed" code:1];
}

- (CPCommandResult *)cmdDoctl:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"doctl: not installed" code:1];
}

- (CPCommandResult *)cmdHeroku:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"heroku: not installed" code:1];
}

- (CPCommandResult *)cmdVercel:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"vercel: not installed" code:1];
}

- (CPCommandResult *)cmdNetlify:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"netlify: not installed" code:1];
}

- (CPCommandResult *)cmdFly:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"fly: not installed" code:1];
}

- (CPCommandResult *)cmdGh:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"gh: not installed, use 'brew install gh'" code:1];
}

- (CPCommandResult *)cmdGlab:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"glab: not installed" code:1];
}

- (CPCommandResult *)cmdJira:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"jira: not installed" code:1];
}

- (CPCommandResult *)cmdSlack:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"slack: not available as CLI" code:1];
}

- (CPCommandResult *)cmdDiscord:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"discord: not available as CLI" code:1];
}

@end
