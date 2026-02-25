#import "CrossPlatformCommandEngine.h"
#import <sys/utsname.h>
#import <sys/sysctl.h>
#import <sys/mount.h>

@implementation CrossPlatformCommandEngine (SystemCommands)

#pragma mark - System Information

- (CPCommandResult *)cmdUname:(NSArray *)args {
    struct utsname sysinfo;
    uname(&sysinfo);
    
    BOOL showAll = NO, showKernel = NO, showNode = NO, showRelease = NO;
    BOOL showVersion = NO, showMachine = NO, showProcessor = NO, showOS = NO;
    
    for (NSString *arg in args) {
        if ([arg containsString:@"a"]) showAll = YES;
        if ([arg containsString:@"s"]) showKernel = YES;
        if ([arg containsString:@"n"]) showNode = YES;
        if ([arg containsString:@"r"]) showRelease = YES;
        if ([arg containsString:@"v"]) showVersion = YES;
        if ([arg containsString:@"m"]) showMachine = YES;
        if ([arg containsString:@"p"]) showProcessor = YES;
        if ([arg containsString:@"o"]) showOS = YES;
    }
    
    if (args.count == 0) showKernel = YES;
    
    NSMutableArray *parts = [NSMutableArray array];
    
    if (showAll || showKernel) [parts addObject:[NSString stringWithUTF8String:sysinfo.sysname]];
    if (showAll || showNode) [parts addObject:[NSString stringWithUTF8String:sysinfo.nodename]];
    if (showAll || showRelease) [parts addObject:[NSString stringWithUTF8String:sysinfo.release]];
    if (showAll || showVersion) [parts addObject:[NSString stringWithUTF8String:sysinfo.version]];
    if (showAll || showMachine) [parts addObject:[NSString stringWithUTF8String:sysinfo.machine]];
    if (showProcessor) [parts addObject:[NSString stringWithUTF8String:sysinfo.machine]];
    if (showOS) [parts addObject:@"Darwin"];
    
    return [CPCommandResult successWithOutput:[[parts componentsJoinedByString:@" "] stringByAppendingString:@"\n"]];
}

- (CPCommandResult *)cmdVer:(NSArray *)args {
    return [CPCommandResult successWithOutput:@"Microsoft Windows [Version 10.0.19041.0] (simulated)\n"];
}

- (CPCommandResult *)cmdSysteminfo:(NSArray *)args {
    struct utsname sysinfo;
    uname(&sysinfo);
    
    NSMutableString *output = [NSMutableString string];
    [output appendFormat:@"Host Name:                 %s\n", sysinfo.nodename];
    [output appendFormat:@"OS Name:                   macOS (simulated as Windows)\n"];
    [output appendFormat:@"OS Version:                %s\n", sysinfo.release];
    [output appendFormat:@"System Type:               %s-based PC\n", sysinfo.machine];
    [output appendFormat:@"Processor(s):              1 Processor(s) Installed\n"];
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdSystem_profiler:(NSArray *)args {
    NSString *dataType = args.count > 0 ? args[0] : @"SPSoftwareDataType";
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/system_profiler";
    task.arguments = @[dataType];
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"system_profiler: failed" code:1];
    }
}

- (CPCommandResult *)cmdSw_vers:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/sw_vers";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"sw_vers: failed" code:1];
    }
}

- (CPCommandResult *)cmdLsb_release:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"lsb_release: Linux only, use sw_vers on macOS" code:1];
}

#pragma mark - Date/Time

- (CPCommandResult *)cmdDate:(NSArray *)args {
    NSString *format = nil;
    
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"+"]) {
            format = [arg substringFromIndex:1];
        }
    }
    
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    
    if (format) {
        NSString *objcFormat = format;
        objcFormat = [objcFormat stringByReplacingOccurrencesOfString:@"%Y" withString:@"yyyy"];
        objcFormat = [objcFormat stringByReplacingOccurrencesOfString:@"%m" withString:@"MM"];
        objcFormat = [objcFormat stringByReplacingOccurrencesOfString:@"%d" withString:@"dd"];
        objcFormat = [objcFormat stringByReplacingOccurrencesOfString:@"%H" withString:@"HH"];
        objcFormat = [objcFormat stringByReplacingOccurrencesOfString:@"%M" withString:@"mm"];
        objcFormat = [objcFormat stringByReplacingOccurrencesOfString:@"%S" withString:@"ss"];
        objcFormat = [objcFormat stringByReplacingOccurrencesOfString:@"%A" withString:@"EEEE"];
        objcFormat = [objcFormat stringByReplacingOccurrencesOfString:@"%B" withString:@"MMMM"];
        objcFormat = [objcFormat stringByReplacingOccurrencesOfString:@"%Z" withString:@"zzz"];
        df.dateFormat = objcFormat;
    } else {
        df.dateFormat = @"EEE MMM dd HH:mm:ss zzz yyyy";
    }
    
    return [CPCommandResult successWithOutput:[[df stringFromDate:[NSDate date]] stringByAppendingString:@"\n"]];
}

- (CPCommandResult *)cmdCal:(NSArray *)args {
    NSInteger month = 0, year = 0;
    BOOL showYear = NO;
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-y"]) {
            showYear = YES;
        } else if ([arg integerValue] > 0) {
            if ([arg integerValue] <= 12 && month == 0) month = [arg integerValue];
            else year = [arg integerValue];
        }
    }
    
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDate *now = [NSDate date];
    NSDateComponents *comps = [cal components:NSCalendarUnitYear | NSCalendarUnitMonth fromDate:now];
    
    if (month == 0) month = comps.month;
    if (year == 0) year = comps.year;
    
    NSDateFormatter *mf = [[NSDateFormatter alloc] init];
    mf.dateFormat = @"MMMM yyyy";
    
    comps.month = month;
    comps.year = year;
    comps.day = 1;
    NSDate *firstDay = [cal dateFromComponents:comps];
    
    NSRange range = [cal rangeOfUnit:NSCalendarUnitDay inUnit:NSCalendarUnitMonth forDate:firstDay];
    NSInteger firstWeekday = [cal component:NSCalendarUnitWeekday fromDate:firstDay];
    
    NSMutableString *output = [NSMutableString string];
    [output appendFormat:@"    %@\n", [mf stringFromDate:firstDay]];
    [output appendString:@"Su Mo Tu We Th Fr Sa\n"];
    
    for (NSInteger i = 1; i < firstWeekday; i++) {
        [output appendString:@"   "];
    }
    
    NSInteger dayOfWeek = firstWeekday;
    for (NSInteger day = 1; day <= range.length; day++) {
        [output appendFormat:@"%2ld ", (long)day];
        if (dayOfWeek == 7) {
            [output appendString:@"\n"];
            dayOfWeek = 1;
        } else {
            dayOfWeek++;
        }
    }
    
    if (dayOfWeek != 1) [output appendString:@"\n"];
    
    return [CPCommandResult successWithOutput:output];
}

#pragma mark - User Information

- (CPCommandResult *)cmdWho:(NSArray *)args {
    NSString *user = NSUserName();
    NSDateFormatter *df = [[NSDateFormatter alloc] init];
    df.dateFormat = @"MMM dd HH:mm";
    NSString *dateStr = [df stringFromDate:[NSDate date]];
    
    return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"%@ console  %@ (:0)\n", user, dateStr]];
}

- (CPCommandResult *)cmdW:(NSArray *)args {
    CPCommandResult *uptimeResult = [self cmdUptime:@[]];
    NSMutableString *output = [NSMutableString stringWithString:uptimeResult.output];
    
    [output appendString:@"USER     TTY      FROM              LOGIN@   IDLE   JCPU   PCPU WHAT\n"];
    [output appendFormat:@"%-8s console  -                 00:00    -      -      -    -\n", NSUserName().UTF8String];
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdWhoami:(NSArray *)args {
    return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"%@\n", NSUserName()]];
}

- (CPCommandResult *)cmdId:(NSArray *)args {
    uid_t uid = getuid();
    gid_t gid = getgid();
    NSString *user = NSUserName();
    
    NSMutableString *output = [NSMutableString string];
    [output appendFormat:@"uid=%d(%@) gid=%d(staff) groups=%d(staff)", uid, user, gid, gid];
    [output appendString:@"\n"];
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdGroups:(NSArray *)args {
    return [CPCommandResult successWithOutput:@"staff everyone localaccounts\n"];
}

- (CPCommandResult *)cmdUsers:(NSArray *)args {
    return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"%@\n", NSUserName()]];
}

- (CPCommandResult *)cmdLast:(NSArray *)args {
    NSInteger count = 10;
    for (NSInteger i = 0; i < args.count; i++) {
        if ([args[i] isEqualToString:@"-n"] && i + 1 < args.count) {
            count = [args[i + 1] integerValue];
        }
    }
    
    NSMutableString *output = [NSMutableString string];
    NSString *user = NSUserName();
    
    for (NSInteger i = 0; i < count; i++) {
        [output appendFormat:@"%-8s console                   Mon Jan  1 00:00   still logged in\n", user.UTF8String];
    }
    [output appendString:@"\nwtmp begins Mon Jan  1 00:00:00 2024\n"];
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdLastlog:(NSArray *)args {
    NSMutableString *output = [NSMutableString string];
    [output appendString:@"Username         Port     From             Latest\n"];
    [output appendFormat:@"%-16s console                   Mon Jan  1 00:00:00 +0000 2024\n", NSUserName().UTF8String];
    return [CPCommandResult successWithOutput:output];
}

#pragma mark - Logs

- (CPCommandResult *)cmdDmesg:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"dmesg: Linux only, use log on macOS" code:1];
}

- (CPCommandResult *)cmdJournalctl:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"journalctl: Linux only, use log on macOS" code:1];
}

- (CPCommandResult *)cmdLog:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"log: missing subcommand" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/log";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_global_queue(0, 0), ^{
            if (task.isRunning) [task terminate];
        });
        
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output ?: @""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"log: failed" code:1];
    }
}

- (CPCommandResult *)cmdLogger:(NSArray *)args {
    NSString *message = [args componentsJoinedByString:@" "];
    NSLog(@"[logger] %@", message);
    return [CPCommandResult successWithOutput:@""];
}

#pragma mark - Power

- (CPCommandResult *)cmdShutdown:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"shutdown: requires root privileges" code:1];
}

- (CPCommandResult *)cmdReboot:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"reboot: requires root privileges" code:1];
}

- (CPCommandResult *)cmdPoweroff:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"poweroff: requires root privileges" code:1];
}

- (CPCommandResult *)cmdHalt:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"halt: requires root privileges" code:1];
}

- (CPCommandResult *)cmdInit:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"init: not available on macOS" code:1];
}

- (CPCommandResult *)cmdTelinit:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"telinit: not available on macOS" code:1];
}

- (CPCommandResult *)cmdRunlevel:(NSArray *)args {
    return [CPCommandResult successWithOutput:@"N 3\n"];
}

#pragma mark - Disk/Mount

- (CPCommandResult *)cmdMount:(NSArray *)args {
    if (args.count == 0) {
        struct statfs *mounts;
        int count = getmntinfo(&mounts, MNT_NOWAIT);
        
        NSMutableString *output = [NSMutableString string];
        for (int i = 0; i < count; i++) {
            [output appendFormat:@"%s on %s (%s)\n", 
             mounts[i].f_mntfromname, mounts[i].f_mntonname, mounts[i].f_fstypename];
        }
        return [CPCommandResult successWithOutput:output];
    }
    return [CPCommandResult errorWithMessage:@"mount: requires root privileges" code:1];
}

- (CPCommandResult *)cmdUmount:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"umount: requires root privileges" code:1];
}

- (CPCommandResult *)cmdDiskutil:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"diskutil: missing command" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/diskutil";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"diskutil: failed" code:1];
    }
}

- (CPCommandResult *)cmdFdisk:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"fdisk: use diskutil on macOS" code:1];
}

- (CPCommandResult *)cmdParted:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"parted: use diskutil on macOS" code:1];
}

- (CPCommandResult *)cmdMkfs:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"mkfs: use diskutil on macOS" code:1];
}

- (CPCommandResult *)cmdFsck:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"fsck: requires root privileges" code:1];
}

- (CPCommandResult *)cmdLsblk:(NSArray *)args {
    return [self cmdDiskutil:@[@"list"]];
}

- (CPCommandResult *)cmdBlkid:(NSArray *)args {
    return [self cmdDiskutil:@[@"info", @"/"]];
}

- (CPCommandResult *)cmdHdparm:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"hdparm: Linux only" code:1];
}

- (CPCommandResult *)cmdSmartctl:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"smartctl: not installed" code:1];
}

- (CPCommandResult *)cmdDiskpart:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"diskpart: Windows only" code:1];
}

- (CPCommandResult *)cmdFormat:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"format: Windows only, use diskutil on macOS" code:1];
}

- (CPCommandResult *)cmdChkdsk:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"chkdsk: Windows only, use fsck on macOS" code:1];
}

- (CPCommandResult *)cmdDefrag:(NSArray *)args {
    return [CPCommandResult successWithOutput:@"macOS uses APFS which does not require defragmentation.\n"];
}

- (CPCommandResult *)cmdHdiutil:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"hdiutil: missing verb" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/hdiutil";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"hdiutil: failed" code:1];
    }
}

- (CPCommandResult *)cmdDitto:(NSArray *)args {
    if (args.count < 2) {
        return [CPCommandResult errorWithMessage:@"ditto: missing source and destination" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/ditto";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        if (task.terminationStatus == 0) {
            return [CPCommandResult successWithOutput:@""];
        }
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *error = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult errorWithMessage:error code:task.terminationStatus];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"ditto: failed" code:1];
    }
}

#pragma mark - Power Management

- (CPCommandResult *)cmdPmset:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/pmset";
    task.arguments = args.count > 0 ? args : @[@"-g"];
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"pmset: failed" code:1];
    }
}

- (CPCommandResult *)cmdCaffeine:(NSArray *)args {
    return [CPCommandResult successWithOutput:@"caffeinate: use 'caffeinate' command\n"];
}

- (CPCommandResult *)cmdScreensaver:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

#pragma mark - System Configuration

- (CPCommandResult *)cmdDefaults:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"defaults: missing command" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/defaults";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"defaults: failed" code:1];
    }
}

- (CPCommandResult *)cmdPlutil:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"plutil: missing arguments" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/plutil";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"plutil: failed" code:1];
    }
}

- (CPCommandResult *)cmdPlistbuddy:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"PlistBuddy: use /usr/libexec/PlistBuddy directly" code:1];
}

- (CPCommandResult *)cmdScutil:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/scutil";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"scutil: failed" code:1];
    }
}

- (CPCommandResult *)cmdSysctl:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/sysctl";
    task.arguments = args.count > 0 ? args : @[@"-a"];
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"sysctl: failed" code:1];
    }
}

#pragma mark - Kernel Extensions

- (CPCommandResult *)cmdKextstat:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/kextstat";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"kextstat: failed" code:1];
    }
}

- (CPCommandResult *)cmdKextload:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"kextload: requires root privileges" code:1];
}

- (CPCommandResult *)cmdKextunload:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"kextunload: requires root privileges" code:1];
}

- (CPCommandResult *)cmdLsmod:(NSArray *)args {
    return [self cmdKextstat:args];
}

- (CPCommandResult *)cmdModprobe:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"modprobe: Linux only" code:1];
}

- (CPCommandResult *)cmdInsmod:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"insmod: Linux only" code:1];
}

- (CPCommandResult *)cmdRmmod:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"rmmod: Linux only" code:1];
}

- (CPCommandResult *)cmdDepmod:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"depmod: Linux only" code:1];
}

@end
