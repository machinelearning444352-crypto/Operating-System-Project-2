#import <Cocoa/Cocoa.h>

#pragma mark - Platform Types

typedef NS_ENUM(NSInteger, CPCommandPlatform) {
    CPCommandPlatformUniversal = 0,
    CPCommandPlatformMacOS,
    CPCommandPlatformLinux,
    CPCommandPlatformWindows,
    CPCommandPlatformBSD,
    CPCommandPlatformPOSIX
};

typedef NS_ENUM(NSInteger, CPCommandCategory) {
    CPCommandCategoryFileSystem = 0,
    CPCommandCategoryProcess,
    CPCommandCategoryNetwork,
    CPCommandCategorySystem,
    CPCommandCategoryUser,
    CPCommandCategoryText,
    CPCommandCategoryArchive,
    CPCommandCategoryDisk,
    CPCommandCategoryPackage,
    CPCommandCategoryDevelopment,
    CPCommandCategoryShell,
    CPCommandCategoryMisc
};

typedef NS_ENUM(NSInteger, CPCommandOutputType) {
    CPCommandOutputTypeText = 0,
    CPCommandOutputTypeJSON,
    CPCommandOutputTypeTable,
    CPCommandOutputTypeBinary,
    CPCommandOutputTypeNone
};

#pragma mark - Command Result

@interface CPCommandResult : NSObject
@property (nonatomic, strong) NSString *output;
@property (nonatomic, strong) NSString *errorOutput;
@property (nonatomic, assign) int exitCode;
@property (nonatomic, assign) BOOL success;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) NSDate *endTime;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, strong) NSDictionary *metadata;
+ (instancetype)successWithOutput:(NSString *)output;
+ (instancetype)errorWithMessage:(NSString *)message code:(int)code;
@end

#pragma mark - Command Definition

@interface CPCommandDefinition : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSArray<NSString *> *aliases;
@property (nonatomic, strong) NSString *synopsis;
@property (nonatomic, strong) NSString *commandDescription;
@property (nonatomic, strong) NSArray<NSDictionary *> *options;
@property (nonatomic, strong) NSArray<NSDictionary *> *arguments;
@property (nonatomic, strong) NSArray<NSString *> *examples;
@property (nonatomic, assign) CPCommandPlatform platform;
@property (nonatomic, assign) CPCommandCategory category;
@property (nonatomic, assign) CPCommandOutputType outputType;
@property (nonatomic, assign) BOOL requiresRoot;
@property (nonatomic, assign) BOOL isBuiltin;
@property (nonatomic, strong) NSString *macOSEquivalent;
@property (nonatomic, strong) NSString *linuxEquivalent;
@property (nonatomic, strong) NSString *windowsEquivalent;
@end

#pragma mark - Command History Entry

@interface CPCommandHistoryEntry : NSObject
@property (nonatomic, strong) NSString *command;
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, strong) NSString *workingDirectory;
@property (nonatomic, assign) int exitCode;
@property (nonatomic, assign) NSTimeInterval duration;
@end

#pragma mark - Environment Variable

@interface CPEnvironmentVariable : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *value;
@property (nonatomic, assign) BOOL isExported;
@property (nonatomic, assign) BOOL isReadOnly;
@property (nonatomic, strong) NSString *variableDescription;
@end

#pragma mark - Shell Session

@interface CPShellSession : NSObject
@property (nonatomic, strong) NSString *sessionID;
@property (nonatomic, strong) NSString *shellType;
@property (nonatomic, strong) NSString *workingDirectory;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *environment;
@property (nonatomic, strong) NSMutableArray<CPCommandHistoryEntry *> *history;
@property (nonatomic, strong) NSMutableArray<NSString *> *aliases;
@property (nonatomic, assign) int lastExitCode;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) NSTask *backgroundTask;
@property (nonatomic, assign) BOOL isInteractive;
@end

#pragma mark - Cross Platform Command Engine

@interface CrossPlatformCommandEngine : NSObject

@property (nonatomic, strong, readonly) CPShellSession *currentSession;
@property (nonatomic, strong, readonly) NSDictionary<NSString *, CPCommandDefinition *> *commandRegistry;
@property (nonatomic, strong, readonly) NSArray<CPCommandHistoryEntry *> *globalHistory;

+ (instancetype)sharedInstance;

// Session Management
- (CPShellSession *)createNewSession;
- (void)switchToSession:(NSString *)sessionID;
- (void)closeSession:(NSString *)sessionID;
- (NSArray<CPShellSession *> *)allSessions;

// Command Execution
- (CPCommandResult *)executeCommand:(NSString *)command;
- (CPCommandResult *)executeCommand:(NSString *)command inSession:(CPShellSession *)session;
- (CPCommandResult *)executeCommand:(NSString *)command withEnvironment:(NSDictionary *)env;
- (void)executeCommandAsync:(NSString *)command completion:(void(^)(CPCommandResult *))completion;
- (void)cancelCurrentCommand;

// Command Translation
- (NSString *)translateCommand:(NSString *)command fromPlatform:(CPCommandPlatform)source toPlatform:(CPCommandPlatform)target;
- (NSString *)macOSEquivalentFor:(NSString *)command platform:(CPCommandPlatform)platform;
- (NSString *)linuxEquivalentFor:(NSString *)command;
- (NSString *)windowsEquivalentFor:(NSString *)command;
- (BOOL)isCommandAvailable:(NSString *)command;
- (CPCommandPlatform)detectCommandPlatform:(NSString *)command;

// Built-in Commands
- (CPCommandResult *)builtinCd:(NSArray *)args;
- (CPCommandResult *)builtinPwd:(NSArray *)args;
- (CPCommandResult *)builtinEcho:(NSArray *)args;
- (CPCommandResult *)builtinExport:(NSArray *)args;
- (CPCommandResult *)builtinUnset:(NSArray *)args;
- (CPCommandResult *)builtinAlias:(NSArray *)args;
- (CPCommandResult *)builtinUnalias:(NSArray *)args;
- (CPCommandResult *)builtinHistory:(NSArray *)args;
- (CPCommandResult *)builtinClear:(NSArray *)args;
- (CPCommandResult *)builtinExit:(NSArray *)args;
- (CPCommandResult *)builtinSource:(NSArray *)args;
- (CPCommandResult *)builtinType:(NSArray *)args;
- (CPCommandResult *)builtinWhich:(NSArray *)args;
- (CPCommandResult *)builtinHelp:(NSArray *)args;
- (CPCommandResult *)builtinSet:(NSArray *)args;
- (CPCommandResult *)builtinEnv:(NSArray *)args;
- (CPCommandResult *)builtinPrintenv:(NSArray *)args;
- (CPCommandResult *)builtinRead:(NSArray *)args;
- (CPCommandResult *)builtinTest:(NSArray *)args;
- (CPCommandResult *)builtinTrue:(NSArray *)args;
- (CPCommandResult *)builtinFalse:(NSArray *)args;
- (CPCommandResult *)builtinJobs:(NSArray *)args;
- (CPCommandResult *)builtinFg:(NSArray *)args;
- (CPCommandResult *)builtinBg:(NSArray *)args;
- (CPCommandResult *)builtinWait:(NSArray *)args;
- (CPCommandResult *)builtinKill:(NSArray *)args;
- (CPCommandResult *)builtinTrap:(NSArray *)args;
- (CPCommandResult *)builtinUmask:(NSArray *)args;
- (CPCommandResult *)builtinUlimit:(NSArray *)args;
- (CPCommandResult *)builtinTimes:(NSArray *)args;
- (CPCommandResult *)builtinShift:(NSArray *)args;
- (CPCommandResult *)builtinGetopts:(NSArray *)args;
- (CPCommandResult *)builtinHash:(NSArray *)args;
- (CPCommandResult *)builtinCommand:(NSArray *)args;
- (CPCommandResult *)builtinBuiltin:(NSArray *)args;
- (CPCommandResult *)builtinEnable:(NSArray *)args;
- (CPCommandResult *)builtinDisable:(NSArray *)args;
- (CPCommandResult *)builtinDeclare:(NSArray *)args;
- (CPCommandResult *)builtinLocal:(NSArray *)args;
- (CPCommandResult *)builtinReadonly:(NSArray *)args;
- (CPCommandResult *)builtinTypeset:(NSArray *)args;
- (CPCommandResult *)builtinLet:(NSArray *)args;
- (CPCommandResult *)builtinEval:(NSArray *)args;
- (CPCommandResult *)builtinExec:(NSArray *)args;
- (CPCommandResult *)builtinDot:(NSArray *)args;
- (CPCommandResult *)builtinColon:(NSArray *)args;
- (CPCommandResult *)builtinBreak:(NSArray *)args;
- (CPCommandResult *)builtinContinue:(NSArray *)args;
- (CPCommandResult *)builtinReturn:(NSArray *)args;
- (CPCommandResult *)builtinPushd:(NSArray *)args;
- (CPCommandResult *)builtinPopd:(NSArray *)args;
- (CPCommandResult *)builtinDirs:(NSArray *)args;
- (CPCommandResult *)builtinSuspend:(NSArray *)args;
- (CPCommandResult *)builtinLogout:(NSArray *)args;
- (CPCommandResult *)builtinCompgen:(NSArray *)args;
- (CPCommandResult *)builtinComplete:(NSArray *)args;
- (CPCommandResult *)builtinCompopt:(NSArray *)args;
- (CPCommandResult *)builtinBind:(NSArray *)args;
- (CPCommandResult *)builtinShopt:(NSArray *)args;
- (CPCommandResult *)builtinMapfile:(NSArray *)args;
- (CPCommandResult *)builtinReadarray:(NSArray *)args;
- (CPCommandResult *)builtinCoproc:(NSArray *)args;

// Cross-Platform File Commands
- (CPCommandResult *)cmdLs:(NSArray *)args;
- (CPCommandResult *)cmdDir:(NSArray *)args;
- (CPCommandResult *)cmdCat:(NSArray *)args;
- (CPCommandResult *)cmdType:(NSArray *)args;
- (CPCommandResult *)cmdMore:(NSArray *)args;
- (CPCommandResult *)cmdLess:(NSArray *)args;
- (CPCommandResult *)cmdHead:(NSArray *)args;
- (CPCommandResult *)cmdTail:(NSArray *)args;
- (CPCommandResult *)cmdCp:(NSArray *)args;
- (CPCommandResult *)cmdCopy:(NSArray *)args;
- (CPCommandResult *)cmdMv:(NSArray *)args;
- (CPCommandResult *)cmdMove:(NSArray *)args;
- (CPCommandResult *)cmdRen:(NSArray *)args;
- (CPCommandResult *)cmdRm:(NSArray *)args;
- (CPCommandResult *)cmdDel:(NSArray *)args;
- (CPCommandResult *)cmdRmdir:(NSArray *)args;
- (CPCommandResult *)cmdMkdir:(NSArray *)args;
- (CPCommandResult *)cmdMd:(NSArray *)args;
- (CPCommandResult *)cmdTouch:(NSArray *)args;
- (CPCommandResult *)cmdChmod:(NSArray *)args;
- (CPCommandResult *)cmdChown:(NSArray *)args;
- (CPCommandResult *)cmdChgrp:(NSArray *)args;
- (CPCommandResult *)cmdLn:(NSArray *)args;
- (CPCommandResult *)cmdMklink:(NSArray *)args;
- (CPCommandResult *)cmdFind:(NSArray *)args;
- (CPCommandResult *)cmdLocate:(NSArray *)args;
- (CPCommandResult *)cmdWhere:(NSArray *)args;
- (CPCommandResult *)cmdWhereIs:(NSArray *)args;
- (CPCommandResult *)cmdFile:(NSArray *)args;
- (CPCommandResult *)cmdStat:(NSArray *)args;
- (CPCommandResult *)cmdDu:(NSArray *)args;
- (CPCommandResult *)cmdDf:(NSArray *)args;
- (CPCommandResult *)cmdTree:(NSArray *)args;
- (CPCommandResult *)cmdWc:(NSArray *)args;
- (CPCommandResult *)cmdDiff:(NSArray *)args;
- (CPCommandResult *)cmdFc:(NSArray *)args;
- (CPCommandResult *)cmdCmp:(NSArray *)args;
- (CPCommandResult *)cmdComm:(NSArray *)args;
- (CPCommandResult *)cmdPatch:(NSArray *)args;
- (CPCommandResult *)cmdSplit:(NSArray *)args;
- (CPCommandResult *)cmdCut:(NSArray *)args;
- (CPCommandResult *)cmdPaste:(NSArray *)args;
- (CPCommandResult *)cmdJoin:(NSArray *)args;
- (CPCommandResult *)cmdSort:(NSArray *)args;
- (CPCommandResult *)cmdUniq:(NSArray *)args;
- (CPCommandResult *)cmdTr:(NSArray *)args;
- (CPCommandResult *)cmdSed:(NSArray *)args;
- (CPCommandResult *)cmdAwk:(NSArray *)args;
- (CPCommandResult *)cmdGrep:(NSArray *)args;
- (CPCommandResult *)cmdEgrep:(NSArray *)args;
- (CPCommandResult *)cmdFgrep:(NSArray *)args;
- (CPCommandResult *)cmdFindstr:(NSArray *)args;
- (CPCommandResult *)cmdXargs:(NSArray *)args;
- (CPCommandResult *)cmdTee:(NSArray *)args;
- (CPCommandResult *)cmdMd5sum:(NSArray *)args;
- (CPCommandResult *)cmdSha1sum:(NSArray *)args;
- (CPCommandResult *)cmdSha256sum:(NSArray *)args;
- (CPCommandResult *)cmdShasum:(NSArray *)args;
- (CPCommandResult *)cmdCksum:(NSArray *)args;
- (CPCommandResult *)cmdSum:(NSArray *)args;
- (CPCommandResult *)cmdBase64:(NSArray *)args;
- (CPCommandResult *)cmdXxd:(NSArray *)args;
- (CPCommandResult *)cmdOd:(NSArray *)args;
- (CPCommandResult *)cmdHexdump:(NSArray *)args;
- (CPCommandResult *)cmdStrings:(NSArray *)args;
- (CPCommandResult *)cmdNl:(NSArray *)args;
- (CPCommandResult *)cmdFmt:(NSArray *)args;
- (CPCommandResult *)cmdFold:(NSArray *)args;
- (CPCommandResult *)cmdPr:(NSArray *)args;
- (CPCommandResult *)cmdColumn:(NSArray *)args;
- (CPCommandResult *)cmdExpand:(NSArray *)args;
- (CPCommandResult *)cmdUnexpand:(NSArray *)args;
- (CPCommandResult *)cmdRev:(NSArray *)args;
- (CPCommandResult *)cmdTac:(NSArray *)args;
- (CPCommandResult *)cmdShuf:(NSArray *)args;

// Process Commands
- (CPCommandResult *)cmdPs:(NSArray *)args;
- (CPCommandResult *)cmdTasklist:(NSArray *)args;
- (CPCommandResult *)cmdTop:(NSArray *)args;
- (CPCommandResult *)cmdHtop:(NSArray *)args;
- (CPCommandResult *)cmdKillall:(NSArray *)args;
- (CPCommandResult *)cmdTaskkill:(NSArray *)args;
- (CPCommandResult *)cmdPkill:(NSArray *)args;
- (CPCommandResult *)cmdPgrep:(NSArray *)args;
- (CPCommandResult *)cmdNice:(NSArray *)args;
- (CPCommandResult *)cmdRenice:(NSArray *)args;
- (CPCommandResult *)cmdNohup:(NSArray *)args;
- (CPCommandResult *)cmdTimeout:(NSArray *)args;
- (CPCommandResult *)cmdTime:(NSArray *)args;
- (CPCommandResult *)cmdWatch:(NSArray *)args;
- (CPCommandResult *)cmdAt:(NSArray *)args;
- (CPCommandResult *)cmdBatch:(NSArray *)args;
- (CPCommandResult *)cmdCrontab:(NSArray *)args;
- (CPCommandResult *)cmdSchtasks:(NSArray *)args;
- (CPCommandResult *)cmdService:(NSArray *)args;
- (CPCommandResult *)cmdSystemctl:(NSArray *)args;
- (CPCommandResult *)cmdLaunchctl:(NSArray *)args;
- (CPCommandResult *)cmdSc:(NSArray *)args;
- (CPCommandResult *)cmdNet:(NSArray *)args;
- (CPCommandResult *)cmdUptime:(NSArray *)args;
- (CPCommandResult *)cmdFree:(NSArray *)args;
- (CPCommandResult *)cmdVmstat:(NSArray *)args;
- (CPCommandResult *)cmdIostat:(NSArray *)args;
- (CPCommandResult *)cmdMpstat:(NSArray *)args;
- (CPCommandResult *)cmdSar:(NSArray *)args;
- (CPCommandResult *)cmdLsof:(NSArray *)args;
- (CPCommandResult *)cmdFuser:(NSArray *)args;
- (CPCommandResult *)cmdStrace:(NSArray *)args;
- (CPCommandResult *)cmdLtrace:(NSArray *)args;
- (CPCommandResult *)cmdDtrace:(NSArray *)args;
- (CPCommandResult *)cmdDtruss:(NSArray *)args;

// Network Commands
- (CPCommandResult *)cmdPing:(NSArray *)args;
- (CPCommandResult *)cmdTraceroute:(NSArray *)args;
- (CPCommandResult *)cmdTracert:(NSArray *)args;
- (CPCommandResult *)cmdPathping:(NSArray *)args;
- (CPCommandResult *)cmdNetstat:(NSArray *)args;
- (CPCommandResult *)cmdSs:(NSArray *)args;
- (CPCommandResult *)cmdIfconfig:(NSArray *)args;
- (CPCommandResult *)cmdIpconfig:(NSArray *)args;
- (CPCommandResult *)cmdIp:(NSArray *)args;
- (CPCommandResult *)cmdRoute:(NSArray *)args;
- (CPCommandResult *)cmdArp:(NSArray *)args;
- (CPCommandResult *)cmdNslookup:(NSArray *)args;
- (CPCommandResult *)cmdDig:(NSArray *)args;
- (CPCommandResult *)cmdHost:(NSArray *)args;
- (CPCommandResult *)cmdHostname:(NSArray *)args;
- (CPCommandResult *)cmdDomainname:(NSArray *)args;
- (CPCommandResult *)cmdCurl:(NSArray *)args;
- (CPCommandResult *)cmdWget:(NSArray *)args;
- (CPCommandResult *)cmdFtp:(NSArray *)args;
- (CPCommandResult *)cmdSftp:(NSArray *)args;
- (CPCommandResult *)cmdScp:(NSArray *)args;
- (CPCommandResult *)cmdRsync:(NSArray *)args;
- (CPCommandResult *)cmdSsh:(NSArray *)args;
- (CPCommandResult *)cmdTelnet:(NSArray *)args;
- (CPCommandResult *)cmdNc:(NSArray *)args;
- (CPCommandResult *)cmdNetcat:(NSArray *)args;
- (CPCommandResult *)cmdSocat:(NSArray *)args;
- (CPCommandResult *)cmdTcpdump:(NSArray *)args;
- (CPCommandResult *)cmdWireshark:(NSArray *)args;
- (CPCommandResult *)cmdNmap:(NSArray *)args;
- (CPCommandResult *)cmdIptables:(NSArray *)args;
- (CPCommandResult *)cmdFirewallCmd:(NSArray *)args;
- (CPCommandResult *)cmdUfw:(NSArray *)args;
- (CPCommandResult *)cmdPfctl:(NSArray *)args;
- (CPCommandResult *)cmdNetsh:(NSArray *)args;
- (CPCommandResult *)cmdIwconfig:(NSArray *)args;
- (CPCommandResult *)cmdWpa_supplicant:(NSArray *)args;
- (CPCommandResult *)cmdNmcli:(NSArray *)args;
- (CPCommandResult *)cmdAirport:(NSArray *)args;
- (CPCommandResult *)cmdNetworksetup:(NSArray *)args;

// System Commands
- (CPCommandResult *)cmdUname:(NSArray *)args;
- (CPCommandResult *)cmdVer:(NSArray *)args;
- (CPCommandResult *)cmdSysteminfo:(NSArray *)args;
- (CPCommandResult *)cmdSystem_profiler:(NSArray *)args;
- (CPCommandResult *)cmdSw_vers:(NSArray *)args;
- (CPCommandResult *)cmdLsb_release:(NSArray *)args;
- (CPCommandResult *)cmdDate:(NSArray *)args;
- (CPCommandResult *)cmdCal:(NSArray *)args;
- (CPCommandResult *)cmdWho:(NSArray *)args;
- (CPCommandResult *)cmdW:(NSArray *)args;
- (CPCommandResult *)cmdWhoami:(NSArray *)args;
- (CPCommandResult *)cmdId:(NSArray *)args;
- (CPCommandResult *)cmdGroups:(NSArray *)args;
- (CPCommandResult *)cmdUsers:(NSArray *)args;
- (CPCommandResult *)cmdLast:(NSArray *)args;
- (CPCommandResult *)cmdLastlog:(NSArray *)args;
- (CPCommandResult *)cmdDmesg:(NSArray *)args;
- (CPCommandResult *)cmdJournalctl:(NSArray *)args;
- (CPCommandResult *)cmdLog:(NSArray *)args;
- (CPCommandResult *)cmdLogger:(NSArray *)args;
- (CPCommandResult *)cmdShutdown:(NSArray *)args;
- (CPCommandResult *)cmdReboot:(NSArray *)args;
- (CPCommandResult *)cmdPoweroff:(NSArray *)args;
- (CPCommandResult *)cmdHalt:(NSArray *)args;
- (CPCommandResult *)cmdInit:(NSArray *)args;
- (CPCommandResult *)cmdTelinit:(NSArray *)args;
- (CPCommandResult *)cmdRunlevel:(NSArray *)args;
- (CPCommandResult *)cmdMount:(NSArray *)args;
- (CPCommandResult *)cmdUmount:(NSArray *)args;
- (CPCommandResult *)cmdDiskutil:(NSArray *)args;
- (CPCommandResult *)cmdFdisk:(NSArray *)args;
- (CPCommandResult *)cmdParted:(NSArray *)args;
- (CPCommandResult *)cmdMkfs:(NSArray *)args;
- (CPCommandResult *)cmdFsck:(NSArray *)args;
- (CPCommandResult *)cmdLsblk:(NSArray *)args;
- (CPCommandResult *)cmdBlkid:(NSArray *)args;
- (CPCommandResult *)cmdHdparm:(NSArray *)args;
- (CPCommandResult *)cmdSmartctl:(NSArray *)args;
- (CPCommandResult *)cmdDiskpart:(NSArray *)args;
- (CPCommandResult *)cmdFormat:(NSArray *)args;
- (CPCommandResult *)cmdChkdsk:(NSArray *)args;
- (CPCommandResult *)cmdDefrag:(NSArray *)args;
- (CPCommandResult *)cmdHdiutil:(NSArray *)args;
- (CPCommandResult *)cmdDitto:(NSArray *)args;
- (CPCommandResult *)cmdPmset:(NSArray *)args;
- (CPCommandResult *)cmdCaffeine:(NSArray *)args;
- (CPCommandResult *)cmdScreensaver:(NSArray *)args;
- (CPCommandResult *)cmdDefaults:(NSArray *)args;
- (CPCommandResult *)cmdPlutil:(NSArray *)args;
- (CPCommandResult *)cmdPlistbuddy:(NSArray *)args;
- (CPCommandResult *)cmdScutil:(NSArray *)args;
- (CPCommandResult *)cmdSysctl:(NSArray *)args;
- (CPCommandResult *)cmdKextstat:(NSArray *)args;
- (CPCommandResult *)cmdKextload:(NSArray *)args;
- (CPCommandResult *)cmdKextunload:(NSArray *)args;
- (CPCommandResult *)cmdLsmod:(NSArray *)args;
- (CPCommandResult *)cmdModprobe:(NSArray *)args;
- (CPCommandResult *)cmdInsmod:(NSArray *)args;
- (CPCommandResult *)cmdRmmod:(NSArray *)args;
- (CPCommandResult *)cmdDepmod:(NSArray *)args;

// User Management Commands
- (CPCommandResult *)cmdUseradd:(NSArray *)args;
- (CPCommandResult *)cmdAdduser:(NSArray *)args;
- (CPCommandResult *)cmdUserdel:(NSArray *)args;
- (CPCommandResult *)cmdDeluser:(NSArray *)args;
- (CPCommandResult *)cmdUsermod:(NSArray *)args;
- (CPCommandResult *)cmdPasswd:(NSArray *)args;
- (CPCommandResult *)cmdChage:(NSArray *)args;
- (CPCommandResult *)cmdGroupadd:(NSArray *)args;
- (CPCommandResult *)cmdGroupdel:(NSArray *)args;
- (CPCommandResult *)cmdGroupmod:(NSArray *)args;
- (CPCommandResult *)cmdGpasswd:(NSArray *)args;
- (CPCommandResult *)cmdNewgrp:(NSArray *)args;
- (CPCommandResult *)cmdSu:(NSArray *)args;
- (CPCommandResult *)cmdSudo:(NSArray *)args;
- (CPCommandResult *)cmdVisudo:(NSArray *)args;
- (CPCommandResult *)cmdChsh:(NSArray *)args;
- (CPCommandResult *)cmdChfn:(NSArray *)args;
- (CPCommandResult *)cmdFinger:(NSArray *)args;
- (CPCommandResult *)cmdPinky:(NSArray *)args;
- (CPCommandResult *)cmdDscl:(NSArray *)args;
- (CPCommandResult *)cmdDseditgroup:(NSArray *)args;
- (CPCommandResult *)cmdSysadminctl:(NSArray *)args;
- (CPCommandResult *)cmdNet_user:(NSArray *)args;
- (CPCommandResult *)cmdNet_localgroup:(NSArray *)args;
- (CPCommandResult *)cmdWmic:(NSArray *)args;
- (CPCommandResult *)cmdRunas:(NSArray *)args;

// Archive Commands
- (CPCommandResult *)cmdTar:(NSArray *)args;
- (CPCommandResult *)cmdGzip:(NSArray *)args;
- (CPCommandResult *)cmdGunzip:(NSArray *)args;
- (CPCommandResult *)cmdBzip2:(NSArray *)args;
- (CPCommandResult *)cmdBunzip2:(NSArray *)args;
- (CPCommandResult *)cmdXz:(NSArray *)args;
- (CPCommandResult *)cmdUnxz:(NSArray *)args;
- (CPCommandResult *)cmdZip:(NSArray *)args;
- (CPCommandResult *)cmdUnzip:(NSArray *)args;
- (CPCommandResult *)cmdRar:(NSArray *)args;
- (CPCommandResult *)cmdUnrar:(NSArray *)args;
- (CPCommandResult *)cmd7z:(NSArray *)args;
- (CPCommandResult *)cmd7za:(NSArray *)args;
- (CPCommandResult *)cmdCpio:(NSArray *)args;
- (CPCommandResult *)cmdAr:(NSArray *)args;
- (CPCommandResult *)cmdZcat:(NSArray *)args;
- (CPCommandResult *)cmdZgrep:(NSArray *)args;
- (CPCommandResult *)cmdZless:(NSArray *)args;
- (CPCommandResult *)cmdZmore:(NSArray *)args;
- (CPCommandResult *)cmdZdiff:(NSArray *)args;
- (CPCommandResult *)cmdLz4:(NSArray *)args;
- (CPCommandResult *)cmdZstd:(NSArray *)args;
- (CPCommandResult *)cmdCompress:(NSArray *)args;
- (CPCommandResult *)cmdUncompress:(NSArray *)args;
- (CPCommandResult *)cmdExpand_archive:(NSArray *)args;
- (CPCommandResult *)cmdCompress_archive:(NSArray *)args;

// Package Management Commands
- (CPCommandResult *)cmdBrew:(NSArray *)args;
- (CPCommandResult *)cmdPort:(NSArray *)args;
- (CPCommandResult *)cmdApt:(NSArray *)args;
- (CPCommandResult *)cmdAptGet:(NSArray *)args;
- (CPCommandResult *)cmdAptCache:(NSArray *)args;
- (CPCommandResult *)cmdDpkg:(NSArray *)args;
- (CPCommandResult *)cmdYum:(NSArray *)args;
- (CPCommandResult *)cmdDnf:(NSArray *)args;
- (CPCommandResult *)cmdRpm:(NSArray *)args;
- (CPCommandResult *)cmdPacman:(NSArray *)args;
- (CPCommandResult *)cmdYay:(NSArray *)args;
- (CPCommandResult *)cmdZypper:(NSArray *)args;
- (CPCommandResult *)cmdEmerge:(NSArray *)args;
- (CPCommandResult *)cmdPkg:(NSArray *)args;
- (CPCommandResult *)cmdPkgng:(NSArray *)args;
- (CPCommandResult *)cmdApk:(NSArray *)args;
- (CPCommandResult *)cmdSnap:(NSArray *)args;
- (CPCommandResult *)cmdFlatpak:(NSArray *)args;
- (CPCommandResult *)cmdAppimage:(NSArray *)args;
- (CPCommandResult *)cmdMas:(NSArray *)args;
- (CPCommandResult *)cmdSoftwareupdate:(NSArray *)args;
- (CPCommandResult *)cmdPip:(NSArray *)args;
- (CPCommandResult *)cmdPip3:(NSArray *)args;
- (CPCommandResult *)cmdNpm:(NSArray *)args;
- (CPCommandResult *)cmdYarn:(NSArray *)args;
- (CPCommandResult *)cmdPnpm:(NSArray *)args;
- (CPCommandResult *)cmdGem:(NSArray *)args;
- (CPCommandResult *)cmdCargo:(NSArray *)args;
- (CPCommandResult *)cmdGo:(NSArray *)args;
- (CPCommandResult *)cmdComposer:(NSArray *)args;
- (CPCommandResult *)cmdMaven:(NSArray *)args;
- (CPCommandResult *)cmdGradle:(NSArray *)args;
- (CPCommandResult *)cmdNuget:(NSArray *)args;
- (CPCommandResult *)cmdVcpkg:(NSArray *)args;
- (CPCommandResult *)cmdConan:(NSArray *)args;
- (CPCommandResult *)cmdConda:(NSArray *)args;
- (CPCommandResult *)cmdChoco:(NSArray *)args;
- (CPCommandResult *)cmdScoop:(NSArray *)args;
- (CPCommandResult *)cmdWinget:(NSArray *)args;

// Development Commands
- (CPCommandResult *)cmdGit:(NSArray *)args;
- (CPCommandResult *)cmdSvn:(NSArray *)args;
- (CPCommandResult *)cmdHg:(NSArray *)args;
- (CPCommandResult *)cmdMake:(NSArray *)args;
- (CPCommandResult *)cmdCmake:(NSArray *)args;
- (CPCommandResult *)cmdNinja:(NSArray *)args;
- (CPCommandResult *)cmdMeson:(NSArray *)args;
- (CPCommandResult *)cmdAutoconf:(NSArray *)args;
- (CPCommandResult *)cmdAutomake:(NSArray *)args;
- (CPCommandResult *)cmdConfigure:(NSArray *)args;
- (CPCommandResult *)cmdGcc:(NSArray *)args;
- (CPCommandResult *)cmdGpp:(NSArray *)args;
- (CPCommandResult *)cmdClang:(NSArray *)args;
- (CPCommandResult *)cmdClangpp:(NSArray *)args;
- (CPCommandResult *)cmdLd:(NSArray *)args;
- (CPCommandResult *)cmdAs:(NSArray *)args;
- (CPCommandResult *)cmdNasm:(NSArray *)args;
- (CPCommandResult *)cmdObjdump:(NSArray *)args;
- (CPCommandResult *)cmdNm:(NSArray *)args;
- (CPCommandResult *)cmdReadelf:(NSArray *)args;
- (CPCommandResult *)cmdOtool:(NSArray *)args;
- (CPCommandResult *)cmdLdd:(NSArray *)args;
- (CPCommandResult *)cmdPython:(NSArray *)args;
- (CPCommandResult *)cmdPython3:(NSArray *)args;
- (CPCommandResult *)cmdNode:(NSArray *)args;
- (CPCommandResult *)cmdDeno:(NSArray *)args;
- (CPCommandResult *)cmdBun:(NSArray *)args;
- (CPCommandResult *)cmdRuby:(NSArray *)args;
- (CPCommandResult *)cmdPerl:(NSArray *)args;
- (CPCommandResult *)cmdPhp:(NSArray *)args;
- (CPCommandResult *)cmdJava:(NSArray *)args;
- (CPCommandResult *)cmdJavac:(NSArray *)args;
- (CPCommandResult *)cmdSwift:(NSArray *)args;
- (CPCommandResult *)cmdSwiftc:(NSArray *)args;
- (CPCommandResult *)cmdRustc:(NSArray *)args;
- (CPCommandResult *)cmdGhc:(NSArray *)args;
- (CPCommandResult *)cmdGhci:(NSArray *)args;
- (CPCommandResult *)cmdErlang:(NSArray *)args;
- (CPCommandResult *)cmdElixir:(NSArray *)args;
- (CPCommandResult *)cmdScala:(NSArray *)args;
- (CPCommandResult *)cmdKotlin:(NSArray *)args;
- (CPCommandResult *)cmdGroovy:(NSArray *)args;
- (CPCommandResult *)cmdLua:(NSArray *)args;
- (CPCommandResult *)cmdJulia:(NSArray *)args;
- (CPCommandResult *)cmdR:(NSArray *)args;
- (CPCommandResult *)cmdOctave:(NSArray *)args;
- (CPCommandResult *)cmdGdb:(NSArray *)args;
- (CPCommandResult *)cmdLldb:(NSArray *)args;
- (CPCommandResult *)cmdValgrind:(NSArray *)args;
- (CPCommandResult *)cmdProf:(NSArray *)args;
- (CPCommandResult *)cmdGprof:(NSArray *)args;
- (CPCommandResult *)cmdPerfPerf:(NSArray *)args;
- (CPCommandResult *)cmdInstruments:(NSArray *)args;
- (CPCommandResult *)cmdXcodebuild:(NSArray *)args;
- (CPCommandResult *)cmdXcrun:(NSArray *)args;
- (CPCommandResult *)cmdCodesign:(NSArray *)args;
- (CPCommandResult *)cmdProductbuild:(NSArray *)args;
- (CPCommandResult *)cmdPkgbuild:(NSArray *)args;
- (CPCommandResult *)cmdInstallerTool:(NSArray *)args;
- (CPCommandResult *)cmdLipo:(NSArray *)args;
- (CPCommandResult *)cmdInstall_name_tool:(NSArray *)args;
- (CPCommandResult *)cmdDocker:(NSArray *)args;
- (CPCommandResult *)cmdDockerCompose:(NSArray *)args;
- (CPCommandResult *)cmdPodman:(NSArray *)args;
- (CPCommandResult *)cmdKubectl:(NSArray *)args;
- (CPCommandResult *)cmdHelm:(NSArray *)args;
- (CPCommandResult *)cmdTerraform:(NSArray *)args;
- (CPCommandResult *)cmdAnsible:(NSArray *)args;
- (CPCommandResult *)cmdVagrant:(NSArray *)args;
- (CPCommandResult *)cmdPacker:(NSArray *)args;

// Misc Commands
- (CPCommandResult *)cmdMan:(NSArray *)args;
- (CPCommandResult *)cmdInfo:(NSArray *)args;
- (CPCommandResult *)cmdApropos:(NSArray *)args;
- (CPCommandResult *)cmdWhatis:(NSArray *)args;
- (CPCommandResult *)cmdYes:(NSArray *)args;
- (CPCommandResult *)cmdSeq:(NSArray *)args;
- (CPCommandResult *)cmdSleep:(NSArray *)args;
- (CPCommandResult *)cmdWait:(NSArray *)args;
- (CPCommandResult *)cmdPrintf:(NSArray *)args;
- (CPCommandResult *)cmdBanner:(NSArray *)args;
- (CPCommandResult *)cmdFiglet:(NSArray *)args;
- (CPCommandResult *)cmdCowsay:(NSArray *)args;
- (CPCommandResult *)cmdLolcat:(NSArray *)args;
- (CPCommandResult *)cmdFortune:(NSArray *)args;
- (CPCommandResult *)cmdCmatrix:(NSArray *)args;
- (CPCommandResult *)cmdSl:(NSArray *)args;
- (CPCommandResult *)cmdFactor:(NSArray *)args;
- (CPCommandResult *)cmdPrimes:(NSArray *)args;
- (CPCommandResult *)cmdBc:(NSArray *)args;
- (CPCommandResult *)cmdDc:(NSArray *)args;
- (CPCommandResult *)cmdExpr:(NSArray *)args;
- (CPCommandResult *)cmdBasename:(NSArray *)args;
- (CPCommandResult *)cmdDirname:(NSArray *)args;
- (CPCommandResult *)cmdRealpath:(NSArray *)args;
- (CPCommandResult *)cmdReadlink:(NSArray *)args;
- (CPCommandResult *)cmdMktemp:(NSArray *)args;
- (CPCommandResult *)cmdTruncate:(NSArray *)args;
- (CPCommandResult *)cmdFallocate:(NSArray *)args;
- (CPCommandResult *)cmdDd:(NSArray *)args;
- (CPCommandResult *)cmdSync:(NSArray *)args;
- (CPCommandResult *)cmdTty:(NSArray *)args;
- (CPCommandResult *)cmdStty:(NSArray *)args;
- (CPCommandResult *)cmdReset:(NSArray *)args;
- (CPCommandResult *)cmdTput:(NSArray *)args;
- (CPCommandResult *)cmdSetterm:(NSArray *)args;
- (CPCommandResult *)cmdScreen:(NSArray *)args;
- (CPCommandResult *)cmdTmux:(NSArray *)args;
- (CPCommandResult *)cmdByobu:(NSArray *)args;
- (CPCommandResult *)cmdVim:(NSArray *)args;
- (CPCommandResult *)cmdNvim:(NSArray *)args;
- (CPCommandResult *)cmdEmacs:(NSArray *)args;
- (CPCommandResult *)cmdNano:(NSArray *)args;
- (CPCommandResult *)cmdPico:(NSArray *)args;
- (CPCommandResult *)cmdEd:(NSArray *)args;
- (CPCommandResult *)cmdEx:(NSArray *)args;
- (CPCommandResult *)cmdVi:(NSArray *)args;
- (CPCommandResult *)cmdOpen:(NSArray *)args;
- (CPCommandResult *)cmdXdgOpen:(NSArray *)args;
- (CPCommandResult *)cmdStart:(NSArray *)args;
- (CPCommandResult *)cmdExplorer:(NSArray *)args;
- (CPCommandResult *)cmdPbcopy:(NSArray *)args;
- (CPCommandResult *)cmdPbpaste:(NSArray *)args;
- (CPCommandResult *)cmdXclip:(NSArray *)args;
- (CPCommandResult *)cmdXsel:(NSArray *)args;
- (CPCommandResult *)cmdClip:(NSArray *)args;
- (CPCommandResult *)cmdSay:(NSArray *)args;
- (CPCommandResult *)cmdEspeak:(NSArray *)args;
- (CPCommandResult *)cmdAfplay:(NSArray *)args;
- (CPCommandResult *)cmdAplay:(NSArray *)args;
- (CPCommandResult *)cmdOsascript:(NSArray *)args;
- (CPCommandResult *)cmdAutomator:(NSArray *)args;
- (CPCommandResult *)cmdSecurity:(NSArray *)args;
- (CPCommandResult *)cmdKeychain:(NSArray *)args;
- (CPCommandResult *)cmdOpenssl:(NSArray *)args;
- (CPCommandResult *)cmdSsh_keygen:(NSArray *)args;
- (CPCommandResult *)cmdSsh_add:(NSArray *)args;
- (CPCommandResult *)cmdSsh_agent:(NSArray *)args;
- (CPCommandResult *)cmdGpg:(NSArray *)args;
- (CPCommandResult *)cmdAge:(NSArray *)args;
- (CPCommandResult *)cmdPass:(NSArray *)args;
- (CPCommandResult *)cmdJq:(NSArray *)args;
- (CPCommandResult *)cmdYq:(NSArray *)args;
- (CPCommandResult *)cmdXq:(NSArray *)args;
- (CPCommandResult *)cmdCsvtool:(NSArray *)args;
- (CPCommandResult *)cmdMiller:(NSArray *)args;
- (CPCommandResult *)cmdSqlite3:(NSArray *)args;
- (CPCommandResult *)cmdMysql:(NSArray *)args;
- (CPCommandResult *)cmdPsql:(NSArray *)args;
- (CPCommandResult *)cmdMongo:(NSArray *)args;
- (CPCommandResult *)cmdRedis_cli:(NSArray *)args;
- (CPCommandResult *)cmdEtcdctl:(NSArray *)args;
- (CPCommandResult *)cmdConsul:(NSArray *)args;
- (CPCommandResult *)cmdVault:(NSArray *)args;
- (CPCommandResult *)cmdAws:(NSArray *)args;
- (CPCommandResult *)cmdGcloud:(NSArray *)args;
- (CPCommandResult *)cmdAz:(NSArray *)args;
- (CPCommandResult *)cmdDoctl:(NSArray *)args;
- (CPCommandResult *)cmdHeroku:(NSArray *)args;
- (CPCommandResult *)cmdVercel:(NSArray *)args;
- (CPCommandResult *)cmdNetlify:(NSArray *)args;
- (CPCommandResult *)cmdFly:(NSArray *)args;
- (CPCommandResult *)cmdGh:(NSArray *)args;
- (CPCommandResult *)cmdGlab:(NSArray *)args;
- (CPCommandResult *)cmdJira:(NSArray *)args;
- (CPCommandResult *)cmdSlack:(NSArray *)args;
- (CPCommandResult *)cmdDiscord:(NSArray *)args;

// Command Completion
- (NSArray<NSString *> *)completionsForPartialCommand:(NSString *)partial;
- (NSArray<NSString *> *)completionsForPath:(NSString *)partialPath;
- (NSArray<NSString *> *)completionsForOptions:(NSString *)command partial:(NSString *)partial;

// History
- (void)addToHistory:(NSString *)command;
- (NSArray<NSString *> *)searchHistory:(NSString *)pattern;
- (void)clearHistory;
- (void)loadHistory;
- (void)saveHistory;

// Aliases
- (void)defineAlias:(NSString *)name expansion:(NSString *)expansion;
- (void)removeAlias:(NSString *)name;
- (NSString *)expandAliases:(NSString *)command;
- (NSDictionary<NSString *, NSString *> *)allAliases;

// Environment
- (void)setEnvironmentVariable:(NSString *)name value:(NSString *)value;
- (NSString *)getEnvironmentVariable:(NSString *)name;
- (void)unsetEnvironmentVariable:(NSString *)name;
- (NSDictionary<NSString *, NSString *> *)allEnvironmentVariables;
- (void)exportVariable:(NSString *)name;

// Path Management
- (void)addToPath:(NSString *)directory;
- (void)removeFromPath:(NSString *)directory;
- (NSArray<NSString *> *)pathDirectories;
- (NSString *)resolveExecutable:(NSString *)name;

// Utilities
- (NSString *)formatOutput:(NSString *)output forTerminalWidth:(NSInteger)width;
- (NSString *)colorizeOutput:(NSString *)output;
- (NSString *)stripAnsiCodes:(NSString *)text;
- (NSDictionary *)parseCommandLine:(NSString *)commandLine;
- (NSArray *)tokenizeCommand:(NSString *)command;
- (NSString *)expandVariables:(NSString *)text;
- (NSString *)expandGlobs:(NSString *)pattern inDirectory:(NSString *)directory;
- (BOOL)matchesGlob:(NSString *)string pattern:(NSString *)pattern;

@end
