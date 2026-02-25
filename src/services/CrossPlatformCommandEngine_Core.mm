#import "CrossPlatformCommandEngine.h"

#pragma mark - CPCommandResult Implementation

@implementation CPCommandResult
- (instancetype)init {
    if (self = [super init]) {
        _output = @"";
        _errorOutput = @"";
        _exitCode = 0;
        _success = YES;
        _startTime = [NSDate date];
        _metadata = @{};
    }
    return self;
}

+ (instancetype)successWithOutput:(NSString *)output {
    CPCommandResult *result = [[CPCommandResult alloc] init];
    result.output = output ?: @"";
    result.success = YES;
    result.exitCode = 0;
    result.endTime = [NSDate date];
    result.duration = [result.endTime timeIntervalSinceDate:result.startTime];
    return result;
}

+ (instancetype)errorWithMessage:(NSString *)message code:(int)code {
    CPCommandResult *result = [[CPCommandResult alloc] init];
    result.errorOutput = message ?: @"";
    result.success = NO;
    result.exitCode = code;
    result.endTime = [NSDate date];
    result.duration = [result.endTime timeIntervalSinceDate:result.startTime];
    return result;
}
@end

#pragma mark - CPCommandDefinition Implementation

@implementation CPCommandDefinition
- (instancetype)init {
    if (self = [super init]) {
        _name = @"";
        _aliases = @[];
        _synopsis = @"";
        _commandDescription = @"";
        _options = @[];
        _arguments = @[];
        _examples = @[];
        _platform = CPCommandPlatformUniversal;
        _category = CPCommandCategoryMisc;
        _outputType = CPCommandOutputTypeText;
        _requiresRoot = NO;
        _isBuiltin = NO;
    }
    return self;
}
@end

#pragma mark - CPCommandHistoryEntry Implementation

@implementation CPCommandHistoryEntry
- (instancetype)init {
    if (self = [super init]) {
        _command = @"";
        _timestamp = [NSDate date];
        _workingDirectory = @"";
        _exitCode = 0;
        _duration = 0;
    }
    return self;
}
@end

#pragma mark - CPEnvironmentVariable Implementation

@implementation CPEnvironmentVariable
- (instancetype)init {
    if (self = [super init]) {
        _name = @"";
        _value = @"";
        _isExported = YES;
        _isReadOnly = NO;
        _variableDescription = @"";
    }
    return self;
}
@end

#pragma mark - CPShellSession Implementation

@implementation CPShellSession
- (instancetype)init {
    if (self = [super init]) {
        _sessionID = [[NSUUID UUID] UUIDString];
        _shellType = @"bash";
        _workingDirectory = NSHomeDirectory();
        _environment = [NSMutableDictionary dictionary];
        _history = [NSMutableArray array];
        _aliases = [NSMutableArray array];
        _lastExitCode = 0;
        _startTime = [NSDate date];
        _isInteractive = YES;
    }
    return self;
}
@end

#pragma mark - CrossPlatformCommandEngine Implementation

@interface CrossPlatformCommandEngine ()
@property (nonatomic, strong, readwrite) CPShellSession *currentSession;
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString *, CPCommandDefinition *> *mutableCommandRegistry;
@property (nonatomic, strong, readwrite) NSMutableArray<CPCommandHistoryEntry *> *mutableGlobalHistory;
@property (nonatomic, strong) NSMutableArray<CPShellSession *> *sessions;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *aliasMap;
@property (nonatomic, strong) NSMutableArray<NSString *> *directoryStack;
@property (nonatomic, strong) NSTask *runningTask;
@property (nonatomic, strong) dispatch_queue_t commandQueue;
@end

@implementation CrossPlatformCommandEngine

+ (instancetype)sharedInstance {
    static CrossPlatformCommandEngine *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CrossPlatformCommandEngine alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        _mutableCommandRegistry = [NSMutableDictionary dictionary];
        _mutableGlobalHistory = [NSMutableArray array];
        _sessions = [NSMutableArray array];
        _aliasMap = [NSMutableDictionary dictionary];
        _directoryStack = [NSMutableArray array];
        _commandQueue = dispatch_queue_create("com.crossplatform.commandengine", DISPATCH_QUEUE_SERIAL);
        
        [self setupDefaultEnvironment];
        [self setupCommandRegistry];
        [self setupDefaultAliases];
        _currentSession = [self createNewSession];
    }
    return self;
}

- (NSDictionary<NSString *, CPCommandDefinition *> *)commandRegistry {
    return [_mutableCommandRegistry copy];
}

- (NSArray<CPCommandHistoryEntry *> *)globalHistory {
    return [_mutableGlobalHistory copy];
}

#pragma mark - Setup Methods

- (void)setupDefaultEnvironment {
    NSMutableDictionary *env = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    env[@"SHELL"] = @"/bin/bash";
    env[@"TERM"] = @"xterm-256color";
    env[@"LANG"] = @"en_US.UTF-8";
    env[@"HOME"] = NSHomeDirectory();
    env[@"USER"] = NSUserName();
    env[@"PWD"] = NSHomeDirectory();
    env[@"OLDPWD"] = NSHomeDirectory();
    env[@"PS1"] = @"\\u@\\h:\\w$ ";
    env[@"PS2"] = @"> ";
}

- (void)setupCommandRegistry {
    // Register built-in commands
    NSArray *builtins = @[@"cd", @"pwd", @"echo", @"export", @"unset", @"alias", @"unalias",
                          @"history", @"clear", @"exit", @"source", @"type", @"which", @"help",
                          @"set", @"env", @"printenv", @"read", @"test", @"true", @"false",
                          @"jobs", @"fg", @"bg", @"wait", @"kill", @"trap", @"umask", @"ulimit"];
    
    for (NSString *cmd in builtins) {
        CPCommandDefinition *def = [[CPCommandDefinition alloc] init];
        def.name = cmd;
        def.isBuiltin = YES;
        def.platform = CPCommandPlatformPOSIX;
        def.category = CPCommandCategoryShell;
        self.mutableCommandRegistry[cmd] = def;
    }
    
    // Register file commands
    NSArray *fileCommands = @[@"ls", @"dir", @"cat", @"more", @"less", @"head", @"tail",
                              @"cp", @"copy", @"mv", @"move", @"rm", @"del", @"mkdir", @"rmdir",
                              @"touch", @"chmod", @"chown", @"ln", @"find", @"locate", @"grep",
                              @"sed", @"awk", @"sort", @"uniq", @"wc", @"diff", @"tree"];
    
    for (NSString *cmd in fileCommands) {
        CPCommandDefinition *def = [[CPCommandDefinition alloc] init];
        def.name = cmd;
        def.isBuiltin = NO;
        def.category = CPCommandCategoryFileSystem;
        self.mutableCommandRegistry[cmd] = def;
    }
}

- (void)setupDefaultAliases {
    self.aliasMap[@"ll"] = @"ls -la";
    self.aliasMap[@"la"] = @"ls -A";
    self.aliasMap[@"l"] = @"ls -CF";
    self.aliasMap[@".."] = @"cd ..";
    self.aliasMap[@"..."] = @"cd ../..";
    self.aliasMap[@"cls"] = @"clear";
    self.aliasMap[@"md"] = @"mkdir -p";
    self.aliasMap[@"rd"] = @"rmdir";
    self.aliasMap[@"h"] = @"history";
    self.aliasMap[@"g"] = @"grep";
}

#pragma mark - Session Management

- (CPShellSession *)createNewSession {
    CPShellSession *session = [[CPShellSession alloc] init];
    session.environment = [NSMutableDictionary dictionaryWithDictionary:[[NSProcessInfo processInfo] environment]];
    session.environment[@"HOME"] = NSHomeDirectory();
    session.environment[@"USER"] = NSUserName();
    session.environment[@"PWD"] = NSHomeDirectory();
    session.workingDirectory = NSHomeDirectory();
    [self.sessions addObject:session];
    return session;
}

- (void)switchToSession:(NSString *)sessionID {
    for (CPShellSession *session in self.sessions) {
        if ([session.sessionID isEqualToString:sessionID]) {
            self.currentSession = session;
            return;
        }
    }
}

- (void)closeSession:(NSString *)sessionID {
    CPShellSession *toRemove = nil;
    for (CPShellSession *session in self.sessions) {
        if ([session.sessionID isEqualToString:sessionID]) {
            toRemove = session;
            break;
        }
    }
    if (toRemove) {
        if (toRemove.backgroundTask && toRemove.backgroundTask.isRunning) {
            [toRemove.backgroundTask terminate];
        }
        [self.sessions removeObject:toRemove];
        if (self.currentSession == toRemove) {
            self.currentSession = self.sessions.firstObject ?: [self createNewSession];
        }
    }
}

- (NSArray<CPShellSession *> *)allSessions {
    return [self.sessions copy];
}

#pragma mark - Command Execution

- (CPCommandResult *)executeCommand:(NSString *)command {
    return [self executeCommand:command inSession:self.currentSession];
}

- (CPCommandResult *)executeCommand:(NSString *)command inSession:(CPShellSession *)session {
    if (!command || command.length == 0) {
        return [CPCommandResult successWithOutput:@""];
    }
    
    // Expand aliases
    NSString *expandedCommand = [self expandAliases:command];
    
    // Parse command
    NSArray *tokens = [self tokenizeCommand:expandedCommand];
    if (tokens.count == 0) {
        return [CPCommandResult successWithOutput:@""];
    }
    
    NSString *cmdName = tokens[0];
    NSArray *args = tokens.count > 1 ? [tokens subarrayWithRange:NSMakeRange(1, tokens.count - 1)] : @[];
    
    // Record start time
    NSDate *startTime = [NSDate date];
    
    // Check for built-in command
    CPCommandResult *result = [self executeBuiltinCommand:cmdName withArgs:args];
    if (!result) {
        // Not a builtin, try external command
        result = [self executeExternalCommand:cmdName withArgs:args inSession:session];
    }
    
    // Record history
    CPCommandHistoryEntry *entry = [[CPCommandHistoryEntry alloc] init];
    entry.command = command;
    entry.timestamp = startTime;
    entry.workingDirectory = session.workingDirectory;
    entry.exitCode = result.exitCode;
    entry.duration = [[NSDate date] timeIntervalSinceDate:startTime];
    [session.history addObject:entry];
    [self.mutableGlobalHistory addObject:entry];
    
    session.lastExitCode = result.exitCode;
    
    return result;
}

- (CPCommandResult *)executeCommand:(NSString *)command withEnvironment:(NSDictionary *)env {
    CPShellSession *tempSession = [self createNewSession];
    [tempSession.environment addEntriesFromDictionary:env];
    CPCommandResult *result = [self executeCommand:command inSession:tempSession];
    [self closeSession:tempSession.sessionID];
    return result;
}

- (void)executeCommandAsync:(NSString *)command completion:(void(^)(CPCommandResult *))completion {
    dispatch_async(self.commandQueue, ^{
        CPCommandResult *result = [self executeCommand:command];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) completion(result);
        });
    });
}

- (void)cancelCurrentCommand {
    if (self.runningTask && self.runningTask.isRunning) {
        [self.runningTask terminate];
    }
}

#pragma mark - Command Dispatching

- (CPCommandResult *)executeBuiltinCommand:(NSString *)command withArgs:(NSArray *)args {
    // Map command names to selectors
    NSDictionary *builtinMap = @{
        @"cd": @"builtinCd:",
        @"pwd": @"builtinPwd:",
        @"echo": @"builtinEcho:",
        @"export": @"builtinExport:",
        @"unset": @"builtinUnset:",
        @"alias": @"builtinAlias:",
        @"unalias": @"builtinUnalias:",
        @"history": @"builtinHistory:",
        @"clear": @"builtinClear:",
        @"exit": @"builtinExit:",
        @"source": @"builtinSource:",
        @".": @"builtinDot:",
        @"type": @"builtinType:",
        @"which": @"builtinWhich:",
        @"help": @"builtinHelp:",
        @"set": @"builtinSet:",
        @"env": @"builtinEnv:",
        @"printenv": @"builtinPrintenv:",
        @"read": @"builtinRead:",
        @"test": @"builtinTest:",
        @"[": @"builtinTest:",
        @"true": @"builtinTrue:",
        @"false": @"builtinFalse:",
        @"jobs": @"builtinJobs:",
        @"fg": @"builtinFg:",
        @"bg": @"builtinBg:",
        @"wait": @"builtinWait:",
        @"kill": @"builtinKill:",
        @"pushd": @"builtinPushd:",
        @"popd": @"builtinPopd:",
        @"dirs": @"builtinDirs:",
        @":": @"builtinColon:"
    };
    
    NSString *selectorName = builtinMap[command];
    if (selectorName) {
        SEL selector = NSSelectorFromString(selectorName);
        if ([self respondsToSelector:selector]) {
            #pragma clang diagnostic push
            #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            return [self performSelector:selector withObject:args];
            #pragma clang diagnostic pop
        }
    }
    
    return nil; // Not a builtin
}

- (CPCommandResult *)executeExternalCommand:(NSString *)command withArgs:(NSArray *)args inSession:(CPShellSession *)session {
    // Build full command
    NSMutableArray *fullArgs = [NSMutableArray arrayWithObject:command];
    [fullArgs addObjectsFromArray:args];
    NSString *fullCommand = [fullArgs componentsJoinedByString:@" "];
    
    // Use NSTask to execute
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/zsh";
    task.arguments = @[@"-c", fullCommand];
    task.currentDirectoryPath = session.workingDirectory;
    task.environment = session.environment;
    
    NSPipe *outputPipe = [NSPipe pipe];
    NSPipe *errorPipe = [NSPipe pipe];
    task.standardOutput = outputPipe;
    task.standardError = errorPipe;
    
    self.runningTask = task;
    
    @try {
        [task launch];
        [task waitUntilExit];
    } @catch (NSException *exception) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"%@: command not found", command] code:127];
    }
    
    self.runningTask = nil;
    
    NSData *outputData = [[outputPipe fileHandleForReading] readDataToEndOfFile];
    NSData *errorData = [[errorPipe fileHandleForReading] readDataToEndOfFile];
    
    NSString *output = [[NSString alloc] initWithData:outputData encoding:NSUTF8StringEncoding] ?: @"";
    NSString *error = [[NSString alloc] initWithData:errorData encoding:NSUTF8StringEncoding] ?: @"";
    
    CPCommandResult *result = [[CPCommandResult alloc] init];
    result.output = output;
    result.errorOutput = error;
    result.exitCode = task.terminationStatus;
    result.success = (task.terminationStatus == 0);
    result.endTime = [NSDate date];
    result.duration = [result.endTime timeIntervalSinceDate:result.startTime];
    
    return result;
}

@end
