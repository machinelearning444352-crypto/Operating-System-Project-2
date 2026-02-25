#import "CrossPlatformCommandEngine.h"
#import <sys/sysctl.h>
#import <libproc.h>
#import <mach/mach.h>

@implementation CrossPlatformCommandEngine (ProcessCommands)

#pragma mark - Process Listing

- (CPCommandResult *)cmdPs:(NSArray *)args {
    BOOL showAll = NO, fullFormat = NO, showUser = NO;
    
    for (NSString *arg in args) {
        if ([arg containsString:@"a"] || [arg containsString:@"A"]) showAll = YES;
        if ([arg containsString:@"f"]) fullFormat = YES;
        if ([arg containsString:@"u"]) showUser = YES;
    }
    
    NSMutableString *output = [NSMutableString string];
    
    if (fullFormat || showUser) {
        [output appendString:@"USER       PID  %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND\n"];
    } else {
        [output appendString:@"  PID TTY          TIME CMD\n"];
    }
    
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size;
    
    if (sysctl(mib, 4, NULL, &size, NULL, 0) < 0) {
        return [CPCommandResult errorWithMessage:@"ps: failed to get process list" code:1];
    }
    
    struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
    if (sysctl(mib, 4, procs, &size, NULL, 0) < 0) {
        free(procs);
        return [CPCommandResult errorWithMessage:@"ps: failed to get process list" code:1];
    }
    
    int count = (int)(size / sizeof(struct kinfo_proc));
    uid_t currentUid = getuid();
    
    for (int i = 0; i < count && i < 50; i++) {
        struct kinfo_proc *proc = &procs[i];
        pid_t pid = proc->kp_proc.p_pid;
        
        if (!showAll && proc->kp_eproc.e_ucred.cr_uid != currentUid) continue;
        
        char pathbuf[PROC_PIDPATHINFO_MAXSIZE];
        proc_pidpath(pid, pathbuf, sizeof(pathbuf));
        NSString *path = [NSString stringWithUTF8String:pathbuf];
        NSString *name = [path lastPathComponent] ?: [NSString stringWithUTF8String:proc->kp_proc.p_comm];
        
        if (fullFormat || showUser) {
            [output appendFormat:@"%-10s %5d  0.0  0.0      0     0 ??       S    00:00   0:00 %@\n",
             NSUserName().UTF8String, pid, name];
        } else {
            [output appendFormat:@"%5d ??       0:00 %@\n", pid, name];
        }
    }
    
    free(procs);
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdTasklist:(NSArray *)args {
    NSMutableString *output = [NSMutableString string];
    [output appendString:@"Image Name                     PID Session Name        Session#    Mem Usage\n"];
    [output appendString:@"========================= ======== ================ =========== ============\n"];
    
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size;
    
    if (sysctl(mib, 4, NULL, &size, NULL, 0) < 0) {
        return [CPCommandResult errorWithMessage:@"tasklist: failed" code:1];
    }
    
    struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
    if (sysctl(mib, 4, procs, &size, NULL, 0) < 0) {
        free(procs);
        return [CPCommandResult errorWithMessage:@"tasklist: failed" code:1];
    }
    
    int count = (int)(size / sizeof(struct kinfo_proc));
    
    for (int i = 0; i < count && i < 50; i++) {
        struct kinfo_proc *proc = &procs[i];
        pid_t pid = proc->kp_proc.p_pid;
        NSString *name = [NSString stringWithUTF8String:proc->kp_proc.p_comm];
        
        [output appendFormat:@"%-25s %8d Console                    1     4,096 K\n", 
         [name substringToIndex:MIN(25, name.length)].UTF8String, pid];
    }
    
    free(procs);
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdTop:(NSArray *)args {
    NSMutableString *output = [NSMutableString string];
    
    [output appendString:@"Processes: 200 total, 2 running, 198 sleeping\n"];
    [output appendString:@"Load Avg: 1.50, 1.25, 1.10\n"];
    [output appendString:@"CPU usage: 10.0% user, 5.0% sys, 85.0% idle\n"];
    
    mach_port_t host = mach_host_self();
    vm_size_t pageSize;
    host_page_size(host, &pageSize);
    
    vm_statistics64_data_t vmStats;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vmStats, &count);
    
    uint64_t usedMem = (vmStats.active_count + vmStats.wire_count) * pageSize;
    uint64_t freeMem = vmStats.free_count * pageSize;
    
    [output appendFormat:@"PhysMem: %.0fM used, %.0fM free\n\n", usedMem / 1048576.0, freeMem / 1048576.0];
    
    [output appendString:@"PID    COMMAND      %CPU  TIME     MEM\n"];
    
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size;
    sysctl(mib, 4, NULL, &size, NULL, 0);
    
    struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
    sysctl(mib, 4, procs, &size, NULL, 0);
    
    int procCount = (int)(size / sizeof(struct kinfo_proc));
    
    for (int i = 0; i < MIN(20, procCount); i++) {
        struct kinfo_proc *proc = &procs[i];
        [output appendFormat:@"%-6d %-12s  0.0  0:00.00  4M\n",
         proc->kp_proc.p_pid, proc->kp_proc.p_comm];
    }
    
    free(procs);
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdHtop:(NSArray *)args {
    return [self cmdTop:args];
}

#pragma mark - Process Control

- (CPCommandResult *)cmdKillall:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"killall: no process name specified" code:1];
    }
    
    int signal = SIGTERM;
    NSString *processName = nil;
    
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"]) {
            NSString *sigStr = [arg substringFromIndex:1];
            if ([sigStr isEqualToString:@"9"] || [sigStr.uppercaseString isEqualToString:@"KILL"]) {
                signal = SIGKILL;
            } else if ([sigStr isEqualToString:@"HUP"] || [sigStr isEqualToString:@"1"]) {
                signal = SIGHUP;
            }
        } else {
            processName = arg;
        }
    }
    
    if (!processName) {
        return [CPCommandResult errorWithMessage:@"killall: no process name specified" code:1];
    }
    
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size;
    sysctl(mib, 4, NULL, &size, NULL, 0);
    
    struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
    sysctl(mib, 4, procs, &size, NULL, 0);
    
    int count = (int)(size / sizeof(struct kinfo_proc));
    int killed = 0;
    
    for (int i = 0; i < count; i++) {
        NSString *name = [NSString stringWithUTF8String:procs[i].kp_proc.p_comm];
        if ([name isEqualToString:processName]) {
            if (kill(procs[i].kp_proc.p_pid, signal) == 0) {
                killed++;
            }
        }
    }
    
    free(procs);
    
    if (killed == 0) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"killall: no matching processes belonging to you were found"] code:1];
    }
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)cmdTaskkill:(NSArray *)args {
    BOOL force = NO;
    NSString *pid = nil;
    NSString *imageName = nil;
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg.uppercaseString isEqualToString:@"/F"]) force = YES;
        else if ([arg.uppercaseString isEqualToString:@"/PID"] && i + 1 < args.count) pid = args[++i];
        else if ([arg.uppercaseString isEqualToString:@"/IM"] && i + 1 < args.count) imageName = args[++i];
    }
    
    if (pid) {
        int signal = force ? SIGKILL : SIGTERM;
        if (kill([pid intValue], signal) == 0) {
            return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"SUCCESS: Sent termination signal to process with PID %@.\n", pid]];
        }
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"ERROR: The process \"%@\" not found.", pid] code:1];
    }
    
    if (imageName) {
        return [self cmdKillall:@[imageName]];
    }
    
    return [CPCommandResult errorWithMessage:@"ERROR: Invalid argument/option - specify /PID or /IM" code:1];
}

- (CPCommandResult *)cmdPkill:(NSArray *)args {
    return [self cmdKillall:args];
}

- (CPCommandResult *)cmdPgrep:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"pgrep: no matching criteria specified" code:1];
    }
    
    BOOL showName = NO;
    NSString *pattern = nil;
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-l"]) showName = YES;
        else if (![arg hasPrefix:@"-"]) pattern = arg;
    }
    
    if (!pattern) {
        return [CPCommandResult errorWithMessage:@"pgrep: no matching criteria specified" code:1];
    }
    
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size;
    sysctl(mib, 4, NULL, &size, NULL, 0);
    
    struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
    sysctl(mib, 4, procs, &size, NULL, 0);
    
    int count = (int)(size / sizeof(struct kinfo_proc));
    NSMutableString *output = [NSMutableString string];
    
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", [NSString stringWithFormat:@".*%@.*", pattern]];
    
    for (int i = 0; i < count; i++) {
        NSString *name = [NSString stringWithUTF8String:procs[i].kp_proc.p_comm];
        if ([pred evaluateWithObject:name]) {
            if (showName) {
                [output appendFormat:@"%d %@\n", procs[i].kp_proc.p_pid, name];
            } else {
                [output appendFormat:@"%d\n", procs[i].kp_proc.p_pid];
            }
        }
    }
    
    free(procs);
    return [CPCommandResult successWithOutput:output];
}

#pragma mark - Process Priority

- (CPCommandResult *)cmdNice:(NSArray *)args {
    NSInteger niceness = 10;
    NSMutableArray *cmd = [NSMutableArray array];
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-n"] && i + 1 < args.count) {
            niceness = [args[++i] integerValue];
        } else if (![arg hasPrefix:@"-"]) {
            [cmd addObject:arg];
        }
    }
    
    if (cmd.count == 0) {
        return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"%ld\n", (long)getpriority(PRIO_PROCESS, 0)]];
    }
    
    return [self executeCommand:[cmd componentsJoinedByString:@" "]];
}

- (CPCommandResult *)cmdRenice:(NSArray *)args {
    if (args.count < 2) {
        return [CPCommandResult errorWithMessage:@"renice: missing operand" code:1];
    }
    
    NSInteger priority = [args[0] integerValue];
    pid_t pid = (pid_t)[args[1] intValue];
    
    if (setpriority(PRIO_PROCESS, pid, (int)priority) == 0) {
        return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"%d: old priority 0, new priority %ld\n", pid, (long)priority]];
    }
    
    return [CPCommandResult errorWithMessage:@"renice: failed to set priority" code:1];
}

- (CPCommandResult *)cmdNohup:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"nohup: missing operand" code:125];
    }
    return [self executeCommand:[args componentsJoinedByString:@" "]];
}

- (CPCommandResult *)cmdTimeout:(NSArray *)args {
    if (args.count < 2) {
        return [CPCommandResult errorWithMessage:@"timeout: missing operand" code:125];
    }
    
    return [self executeCommand:[[args subarrayWithRange:NSMakeRange(1, args.count - 1)] componentsJoinedByString:@" "]];
}

- (CPCommandResult *)cmdTime:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"time: missing operand" code:1];
    }
    
    NSDate *start = [NSDate date];
    CPCommandResult *result = [self executeCommand:[args componentsJoinedByString:@" "]];
    NSTimeInterval elapsed = [[NSDate date] timeIntervalSinceDate:start];
    
    NSMutableString *output = [NSMutableString stringWithString:result.output];
    [output appendFormat:@"\nreal\t%.3fs\nuser\t0.000s\nsys\t0.000s\n", elapsed];
    
    result.output = output;
    return result;
}

- (CPCommandResult *)cmdWatch:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"watch: missing operand" code:1];
    }
    return [self executeCommand:[args componentsJoinedByString:@" "]];
}

#pragma mark - Scheduling

- (CPCommandResult *)cmdAt:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"at: requires daemon, use native shell" code:1];
}

- (CPCommandResult *)cmdBatch:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"batch: requires daemon, use native shell" code:1];
}

- (CPCommandResult *)cmdCrontab:(NSArray *)args {
    BOOL list = NO, edit = NO, remove = NO;
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-l"]) list = YES;
        else if ([arg isEqualToString:@"-e"]) edit = YES;
        else if ([arg isEqualToString:@"-r"]) remove = YES;
    }
    
    NSString *crontabPath = [NSHomeDirectory() stringByAppendingPathComponent:@".crontab"];
    
    if (list) {
        NSString *content = [NSString stringWithContentsOfFile:crontabPath encoding:NSUTF8StringEncoding error:nil];
        return [CPCommandResult successWithOutput:content ?: @"no crontab for user\n"];
    }
    
    if (remove) {
        [[NSFileManager defaultManager] removeItemAtPath:crontabPath error:nil];
        return [CPCommandResult successWithOutput:@""];
    }
    
    return [CPCommandResult errorWithMessage:@"crontab: editing requires native shell" code:1];
}

- (CPCommandResult *)cmdSchtasks:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"schtasks: Windows command not available" code:1];
}

#pragma mark - Services

- (CPCommandResult *)cmdService:(NSArray *)args {
    if (args.count < 2) {
        return [CPCommandResult errorWithMessage:@"service: missing arguments" code:1];
    }
    
    NSString *serviceName = args[0];
    NSString *action = args[1];
    
    return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"%@ %@ [simulated]\n", action, serviceName]];
}

- (CPCommandResult *)cmdSystemctl:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"systemctl: missing command" code:1];
    }
    
    NSString *action = args[0];
    NSString *unit = args.count > 1 ? args[1] : @"";
    
    if ([action isEqualToString:@"list-units"]) {
        return [CPCommandResult successWithOutput:@"UNIT                   LOAD   ACTIVE SUB     DESCRIPTION\n"];
    }
    
    return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"[simulated] %@ %@\n", action, unit]];
}

- (CPCommandResult *)cmdLaunchctl:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"launchctl: missing subcommand" code:1];
    }
    
    NSString *subcommand = args[0];
    
    if ([subcommand isEqualToString:@"list"]) {
        NSTask *task = [[NSTask alloc] init];
        task.launchPath = @"/bin/launchctl";
        task.arguments = @[@"list"];
        
        NSPipe *pipe = [NSPipe pipe];
        task.standardOutput = pipe;
        
        @try {
            [task launch];
            [task waitUntilExit];
            
            NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
            NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            return [CPCommandResult successWithOutput:output];
        } @catch (NSException *e) {
            return [CPCommandResult errorWithMessage:@"launchctl: failed" code:1];
        }
    }
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)cmdSc:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"sc: Windows command not available" code:1];
}

- (CPCommandResult *)cmdNet:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"net: Windows command not available" code:1];
}

#pragma mark - System Stats

- (CPCommandResult *)cmdUptime:(NSArray *)args {
    struct timeval boottime;
    size_t size = sizeof(boottime);
    int mib[2] = {CTL_KERN, KERN_BOOTTIME};
    
    if (sysctl(mib, 2, &boottime, &size, NULL, 0) != -1) {
        time_t now = time(NULL);
        time_t uptime = now - boottime.tv_sec;
        
        int days = (int)(uptime / 86400);
        int hours = (int)((uptime % 86400) / 3600);
        int mins = (int)((uptime % 3600) / 60);
        
        NSDateFormatter *df = [[NSDateFormatter alloc] init];
        df.dateFormat = @"HH:mm:ss";
        NSString *timeStr = [df stringFromDate:[NSDate date]];
        
        NSMutableString *output = [NSMutableString string];
        [output appendFormat:@" %@ up ", timeStr];
        
        if (days > 0) [output appendFormat:@"%d day%s, ", days, days == 1 ? "" : "s"];
        [output appendFormat:@"%d:%02d,  1 user,  load average: 1.50, 1.25, 1.10\n", hours, mins];
        
        return [CPCommandResult successWithOutput:output];
    }
    
    return [CPCommandResult errorWithMessage:@"uptime: failed to get boot time" code:1];
}

- (CPCommandResult *)cmdFree:(NSArray *)args {
    BOOL humanReadable = NO;
    for (NSString *arg in args) {
        if ([arg containsString:@"h"]) humanReadable = YES;
    }
    
    mach_port_t host = mach_host_self();
    vm_size_t pageSize;
    host_page_size(host, &pageSize);
    
    vm_statistics64_data_t vmStats;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vmStats, &count);
    
    uint64_t totalMem = (vmStats.free_count + vmStats.active_count + vmStats.inactive_count + vmStats.wire_count) * pageSize;
    uint64_t usedMem = (vmStats.active_count + vmStats.wire_count) * pageSize;
    uint64_t freeMem = vmStats.free_count * pageSize;
    
    NSMutableString *output = [NSMutableString string];
    
    if (humanReadable) {
        [output appendString:@"              total        used        free      shared  buff/cache   available\n"];
        [output appendFormat:@"Mem:          %.1fG        %.1fG        %.1fG         0B         0B        %.1fG\n",
         totalMem / 1073741824.0, usedMem / 1073741824.0, freeMem / 1073741824.0, freeMem / 1073741824.0];
        [output appendString:@"Swap:           0B           0B           0B\n"];
    } else {
        [output appendString:@"              total        used        free      shared  buff/cache   available\n"];
        [output appendFormat:@"Mem:    %10llu  %10llu  %10llu           0           0  %10llu\n",
         totalMem / 1024, usedMem / 1024, freeMem / 1024, freeMem / 1024];
        [output appendString:@"Swap:            0           0           0\n"];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdVmstat:(NSArray *)args {
    mach_port_t host = mach_host_self();
    vm_size_t pageSize;
    host_page_size(host, &pageSize);
    
    vm_statistics64_data_t vmStats;
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    host_statistics64(host, HOST_VM_INFO64, (host_info64_t)&vmStats, &count);
    
    NSMutableString *output = [NSMutableString string];
    [output appendString:@"procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----\n"];
    [output appendString:@" r  b   swpd   free   buff  cache   si   so    bi    bo   in   cs us sy id wa st\n"];
    [output appendFormat:@" 1  0      0 %6llu      0 %6llu    0    0     0     0    0    0  5  2 93  0  0\n",
     vmStats.free_count * pageSize / 1024,
     vmStats.inactive_count * pageSize / 1024];
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdIostat:(NSArray *)args {
    NSMutableString *output = [NSMutableString string];
    [output appendString:@"              disk0\n"];
    [output appendString:@"    KB/t  tps  MB/s\n"];
    [output appendString:@"   64.00   10  0.62\n"];
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdMpstat:(NSArray *)args {
    NSMutableString *output = [NSMutableString string];
    [output appendString:@"CPU    %usr   %nice    %sys %iowait    %irq   %soft  %steal  %guest  %gnice   %idle\n"];
    [output appendString:@"all    5.00    0.00    2.00    0.00    0.00    0.00    0.00    0.00    0.00   93.00\n"];
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdSar:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"sar: not available on macOS, use vm_stat" code:1];
}

- (CPCommandResult *)cmdLsof:(NSArray *)args {
    NSMutableString *output = [NSMutableString string];
    [output appendString:@"COMMAND     PID   USER   FD   TYPE DEVICE SIZE/OFF    NODE NAME\n"];
    
    NSString *targetPid = nil;
    for (NSInteger i = 0; i < args.count; i++) {
        if ([args[i] isEqualToString:@"-p"] && i + 1 < args.count) {
            targetPid = args[i + 1];
        }
    }
    
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0};
    size_t size;
    sysctl(mib, 4, NULL, &size, NULL, 0);
    
    struct kinfo_proc *procs = (struct kinfo_proc *)malloc(size);
    sysctl(mib, 4, procs, &size, NULL, 0);
    
    int count = (int)(size / sizeof(struct kinfo_proc));
    
    for (int i = 0; i < MIN(20, count); i++) {
        struct kinfo_proc *proc = &procs[i];
        
        if (targetPid && [targetPid intValue] != proc->kp_proc.p_pid) continue;
        
        [output appendFormat:@"%-10s %5d %6s  cwd    DIR              /\n",
         proc->kp_proc.p_comm, proc->kp_proc.p_pid, NSUserName().UTF8String];
    }
    
    free(procs);
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdFuser:(NSArray *)args {
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)cmdStrace:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"strace: Linux only, use dtruss on macOS" code:1];
}

- (CPCommandResult *)cmdLtrace:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"ltrace: Linux only" code:1];
}

- (CPCommandResult *)cmdDtrace:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"dtrace: requires root privileges" code:1];
}

- (CPCommandResult *)cmdDtruss:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"dtruss: requires root privileges" code:1];
}

@end
