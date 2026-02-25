#import "CrossPlatformCommandEngine.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>
#import <ifaddrs.h>

@implementation CrossPlatformCommandEngine (NetworkCommands)

#pragma mark - Network Diagnostics

- (CPCommandResult *)cmdPing:(NSArray *)args {
    NSInteger count = 4;
    NSString *host = nil;
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-c"] && i + 1 < args.count) {
            count = [args[++i] integerValue];
        } else if (![arg hasPrefix:@"-"]) {
            host = arg;
        }
    }
    
    if (!host) {
        return [CPCommandResult errorWithMessage:@"ping: missing host operand" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/sbin/ping";
    task.arguments = @[@"-c", [NSString stringWithFormat:@"%ld", (long)count], host];
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        CPCommandResult *result = [CPCommandResult successWithOutput:output];
        result.exitCode = task.terminationStatus;
        result.success = (task.terminationStatus == 0);
        return result;
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"ping: failed to execute" code:1];
    }
}

- (CPCommandResult *)cmdTraceroute:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"traceroute: missing host operand" code:1];
    }
    
    NSString *host = nil;
    for (NSString *arg in args) {
        if (![arg hasPrefix:@"-"]) {
            host = arg;
            break;
        }
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/traceroute";
    task.arguments = @[host];
    
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
        return [CPCommandResult errorWithMessage:@"traceroute: failed" code:1];
    }
}

- (CPCommandResult *)cmdTracert:(NSArray *)args {
    return [self cmdTraceroute:args];
}

- (CPCommandResult *)cmdPathping:(NSArray *)args {
    return [self cmdTraceroute:args];
}

- (CPCommandResult *)cmdNetstat:(NSArray *)args {
    BOOL showAll = NO, numeric = NO, listening = NO, tcp = NO, udp = NO;
    
    for (NSString *arg in args) {
        if ([arg containsString:@"a"]) showAll = YES;
        if ([arg containsString:@"n"]) numeric = YES;
        if ([arg containsString:@"l"]) listening = YES;
        if ([arg containsString:@"t"]) tcp = YES;
        if ([arg containsString:@"u"]) udp = YES;
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/netstat";
    
    NSMutableArray *taskArgs = [NSMutableArray array];
    if (showAll) [taskArgs addObject:@"-a"];
    if (numeric) [taskArgs addObject:@"-n"];
    
    task.arguments = taskArgs.count > 0 ? taskArgs : @[@"-an"];
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"netstat: failed" code:1];
    }
}

- (CPCommandResult *)cmdSs:(NSArray *)args {
    return [self cmdNetstat:args];
}

#pragma mark - Interface Configuration

- (CPCommandResult *)cmdIfconfig:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/sbin/ifconfig";
    task.arguments = args.count > 0 ? args : @[];
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output];
    } @catch (NSException *e) {
        return [self getNetworkInterfaces];
    }
}

- (CPCommandResult *)getNetworkInterfaces {
    NSMutableString *output = [NSMutableString string];
    
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *addr = NULL;
    
    if (getifaddrs(&interfaces) == 0) {
        addr = interfaces;
        while (addr != NULL) {
            if (addr->ifa_addr->sa_family == AF_INET) {
                NSString *name = [NSString stringWithUTF8String:addr->ifa_name];
                char ipStr[INET_ADDRSTRLEN];
                inet_ntop(AF_INET, &((struct sockaddr_in *)addr->ifa_addr)->sin_addr, ipStr, INET_ADDRSTRLEN);
                
                [output appendFormat:@"%@: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST>\n", name];
                [output appendFormat:@"\tinet %s netmask 0xffffff00 broadcast\n", ipStr];
            }
            addr = addr->ifa_next;
        }
        freeifaddrs(interfaces);
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdIpconfig:(NSArray *)args {
    if (args.count > 0 && [[(NSString *)args[0] lowercaseString] isEqualToString:@"/all"]) {
        return [self cmdIfconfig:@[]];
    }
    return [self cmdIfconfig:args];
}

- (CPCommandResult *)cmdIp:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"ip: missing object" code:1];
    }
    
    NSString *object = args[0];
    
    if ([object isEqualToString:@"addr"] || [object isEqualToString:@"address"]) {
        return [self cmdIfconfig:@[]];
    }
    if ([object isEqualToString:@"route"]) {
        return [self cmdRoute:@[]];
    }
    if ([object isEqualToString:@"link"]) {
        return [self cmdIfconfig:@[]];
    }
    
    return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"ip: unknown object '%@'", object] code:1];
}

- (CPCommandResult *)cmdRoute:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/netstat";
    task.arguments = @[@"-rn"];
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"route: failed" code:1];
    }
}

- (CPCommandResult *)cmdArp:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/arp";
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
        return [CPCommandResult errorWithMessage:@"arp: failed" code:1];
    }
}

#pragma mark - DNS

- (CPCommandResult *)cmdNslookup:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"nslookup: missing host argument" code:1];
    }
    
    NSString *host = args[0];
    
    struct hostent *he = gethostbyname([host UTF8String]);
    if (he == NULL) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"nslookup: can't resolve '%@'", host] code:1];
    }
    
    NSMutableString *output = [NSMutableString string];
    [output appendString:@"Server:\t\t8.8.8.8\n"];
    [output appendString:@"Address:\t8.8.8.8#53\n\n"];
    [output appendString:@"Non-authoritative answer:\n"];
    [output appendFormat:@"Name:\t%@\n", host];
    
    char **addr_list = he->h_addr_list;
    for (int i = 0; addr_list[i] != NULL; i++) {
        char ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, addr_list[i], ip, INET_ADDRSTRLEN);
        [output appendFormat:@"Address: %s\n", ip];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdDig:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"dig: missing host argument" code:1];
    }
    
    NSString *host = args[0];
    
    NSMutableString *output = [NSMutableString string];
    [output appendFormat:@"; <<>> DiG <<>> %@\n", host];
    [output appendString:@";; global options: +cmd\n"];
    [output appendString:@";; Got answer:\n"];
    [output appendString:@";; ->>HEADER<<- opcode: QUERY, status: NOERROR\n\n"];
    [output appendString:@";; QUESTION SECTION:\n"];
    [output appendFormat:@";%@.\t\t\tIN\tA\n\n", host];
    [output appendString:@";; ANSWER SECTION:\n"];
    
    struct hostent *he = gethostbyname([host UTF8String]);
    if (he) {
        char **addr_list = he->h_addr_list;
        for (int i = 0; addr_list[i] != NULL; i++) {
            char ip[INET_ADDRSTRLEN];
            inet_ntop(AF_INET, addr_list[i], ip, INET_ADDRSTRLEN);
            [output appendFormat:@"%@.\t\t300\tIN\tA\t%s\n", host, ip];
        }
    }
    
    [output appendString:@"\n;; Query time: 10 msec\n"];
    [output appendString:@";; SERVER: 8.8.8.8#53(8.8.8.8)\n"];
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdHost:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"host: missing host argument" code:1];
    }
    
    NSString *host = args[0];
    struct hostent *he = gethostbyname([host UTF8String]);
    
    if (!he) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"Host %@ not found", host] code:1];
    }
    
    NSMutableString *output = [NSMutableString string];
    char **addr_list = he->h_addr_list;
    for (int i = 0; addr_list[i] != NULL; i++) {
        char ip[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, addr_list[i], ip, INET_ADDRSTRLEN);
        [output appendFormat:@"%@ has address %s\n", host, ip];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdHostname:(NSArray *)args {
    if (args.count > 0) {
        return [CPCommandResult errorWithMessage:@"hostname: cannot set hostname" code:1];
    }
    
    char hostname[256];
    gethostname(hostname, sizeof(hostname));
    return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"%s\n", hostname]];
}

- (CPCommandResult *)cmdDomainname:(NSArray *)args {
    return [CPCommandResult successWithOutput:@"(none)\n"];
}

#pragma mark - HTTP/Transfer

- (CPCommandResult *)cmdCurl:(NSArray *)args {
    BOOL silent = NO, outputToFile = NO, showHeaders = NO, followRedirects = NO;
    NSString *url = nil;
    NSString *outputFile = nil;
    NSString *method = @"GET";
    NSString *data = nil;
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-s"] || [arg isEqualToString:@"--silent"]) {
            silent = YES;
        } else if ([arg isEqualToString:@"-o"] && i + 1 < args.count) {
            outputFile = args[++i];
            outputToFile = YES;
        } else if ([arg isEqualToString:@"-O"]) {
            outputToFile = YES;
        } else if ([arg isEqualToString:@"-I"] || [arg isEqualToString:@"--head"]) {
            showHeaders = YES;
        } else if ([arg isEqualToString:@"-L"] || [arg isEqualToString:@"--location"]) {
            followRedirects = YES;
        } else if ([arg isEqualToString:@"-X"] && i + 1 < args.count) {
            method = args[++i];
        } else if ([arg isEqualToString:@"-d"] && i + 1 < args.count) {
            data = args[++i];
            method = @"POST";
        } else if ([arg isEqualToString:@"-H"] && i + 1 < args.count) {
            NSString *header = args[++i];
            NSRange colonRange = [header rangeOfString:@":"];
            if (colonRange.location != NSNotFound) {
                NSString *key = [[header substringToIndex:colonRange.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                NSString *value = [[header substringFromIndex:colonRange.location + 1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
                headers[key] = value;
            }
        } else if (![arg hasPrefix:@"-"]) {
            url = arg;
        }
    }
    
    if (!url) {
        return [CPCommandResult errorWithMessage:@"curl: no URL specified" code:3];
    }
    
    NSURL *nsurl = [NSURL URLWithString:url];
    if (!nsurl) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"curl: (3) URL using bad/illegal format or missing URL"] code:3];
    }
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:nsurl];
    request.HTTPMethod = method;
    
    for (NSString *key in headers) {
        [request setValue:headers[key] forHTTPHeaderField:key];
    }
    
    if (data) {
        request.HTTPBody = [data dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSData *responseData = nil;
    __block NSHTTPURLResponse *httpResponse = nil;
    __block NSError *error = nil;
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        responseData = d;
        httpResponse = (NSHTTPURLResponse *)r;
        error = e;
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];
    
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    
    if (error) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"curl: (7) %@", error.localizedDescription] code:7];
    }
    
    NSMutableString *output = [NSMutableString string];
    
    if (showHeaders) {
        [output appendFormat:@"HTTP/1.1 %ld\n", (long)httpResponse.statusCode];
        for (NSString *key in httpResponse.allHeaderFields) {
            [output appendFormat:@"%@: %@\n", key, httpResponse.allHeaderFields[key]];
        }
    } else {
        NSString *body = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
        if (body) {
            [output appendString:body];
        }
    }
    
    if (outputToFile && outputFile) {
        NSString *path = [outputFile hasPrefix:@"/"] ? outputFile : [self.currentSession.workingDirectory stringByAppendingPathComponent:outputFile];
        [responseData writeToFile:path atomically:YES];
        return [CPCommandResult successWithOutput:@""];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdWget:(NSArray *)args {
    NSString *url = nil;
    NSString *outputFile = nil;
    BOOL quiet = NO;
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-O"] && i + 1 < args.count) {
            outputFile = args[++i];
        } else if ([arg isEqualToString:@"-q"]) {
            quiet = YES;
        } else if (![arg hasPrefix:@"-"]) {
            url = arg;
        }
    }
    
    if (!url) {
        return [CPCommandResult errorWithMessage:@"wget: missing URL" code:1];
    }
    
    NSMutableArray *curlArgs = [NSMutableArray array];
    if (outputFile) {
        [curlArgs addObject:@"-o"];
        [curlArgs addObject:outputFile];
    } else {
        [curlArgs addObject:@"-O"];
    }
    if (quiet) [curlArgs addObject:@"-s"];
    [curlArgs addObject:@"-L"];
    [curlArgs addObject:url];
    
    CPCommandResult *result = [self cmdCurl:curlArgs];
    
    if (!quiet && result.success) {
        return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"--2024-01-01 00:00:00--  %@\nSaved\n", url]];
    }
    
    return result;
}

- (CPCommandResult *)cmdFtp:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"ftp: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdSftp:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"sftp: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdScp:(NSArray *)args {
    if (args.count < 2) {
        return [CPCommandResult errorWithMessage:@"scp: missing file operand" code:1];
    }
    return [CPCommandResult errorWithMessage:@"scp: requires SSH authentication" code:1];
}

- (CPCommandResult *)cmdRsync:(NSArray *)args {
    if (args.count < 2) {
        return [CPCommandResult errorWithMessage:@"rsync: missing source and destination" code:1];
    }
    return [CPCommandResult errorWithMessage:@"rsync: complex operation, use native shell" code:1];
}

- (CPCommandResult *)cmdSsh:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"ssh: missing host" code:255];
    }
    return [CPCommandResult errorWithMessage:@"ssh: interactive sessions not supported" code:255];
}

- (CPCommandResult *)cmdTelnet:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"telnet: interactive mode not supported" code:1];
}

#pragma mark - Low-level Network

- (CPCommandResult *)cmdNc:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"nc: requires interactive I/O" code:1];
}

- (CPCommandResult *)cmdNetcat:(NSArray *)args {
    return [self cmdNc:args];
}

- (CPCommandResult *)cmdSocat:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"socat: not available" code:1];
}

- (CPCommandResult *)cmdTcpdump:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"tcpdump: requires root privileges" code:1];
}

- (CPCommandResult *)cmdWireshark:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"wireshark: GUI application" code:1];
}

- (CPCommandResult *)cmdNmap:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"nmap: not installed" code:1];
}

#pragma mark - Firewall

- (CPCommandResult *)cmdIptables:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"iptables: Linux only, use pfctl on macOS" code:1];
}

- (CPCommandResult *)cmdFirewallCmd:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"firewall-cmd: Linux only" code:1];
}

- (CPCommandResult *)cmdUfw:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"ufw: Linux only" code:1];
}

- (CPCommandResult *)cmdPfctl:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"pfctl: requires root privileges" code:1];
}

- (CPCommandResult *)cmdNetsh:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"netsh: Windows only" code:1];
}

#pragma mark - Wireless

- (CPCommandResult *)cmdIwconfig:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"iwconfig: Linux only, use airport on macOS" code:1];
}

- (CPCommandResult *)cmdWpa_supplicant:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"wpa_supplicant: Linux only" code:1];
}

- (CPCommandResult *)cmdNmcli:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"nmcli: Linux only" code:1];
}

- (CPCommandResult *)cmdAirport:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport";
    task.arguments = args.count > 0 ? args : @[@"-I"];
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"airport: failed" code:1];
    }
}

- (CPCommandResult *)cmdNetworksetup:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"networksetup: missing command" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/networksetup";
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
        return [CPCommandResult errorWithMessage:@"networksetup: failed" code:1];
    }
}

@end
