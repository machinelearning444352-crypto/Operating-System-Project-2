#import "CrossPlatformCommandEngine.h"

@implementation CrossPlatformCommandEngine (ArchiveCommands)

#pragma mark - Tar

- (CPCommandResult *)cmdTar:(NSArray *)args {
    BOOL create = NO, extract = NO, list = NO, verbose = NO, gzip = NO, bzip2 = NO, xz = NO;
    NSString *archive = nil;
    NSString *directory = nil;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg hasPrefix:@"-"] || (arg.length > 0 && i == 0 && ![arg hasPrefix:@"/"])) {
            NSString *flags = [arg hasPrefix:@"-"] ? [arg substringFromIndex:1] : arg;
            if ([flags containsString:@"c"]) create = YES;
            if ([flags containsString:@"x"]) extract = YES;
            if ([flags containsString:@"t"]) list = YES;
            if ([flags containsString:@"v"]) verbose = YES;
            if ([flags containsString:@"z"]) gzip = YES;
            if ([flags containsString:@"j"]) bzip2 = YES;
            if ([flags containsString:@"J"]) xz = YES;
            if ([flags containsString:@"f"] && i + 1 < args.count) {
                archive = args[++i];
            }
        } else if ([arg isEqualToString:@"-C"] && i + 1 < args.count) {
            directory = args[++i];
        } else if (!archive) {
            archive = arg;
        } else {
            [files addObject:arg];
        }
    }
    
    if (!archive) {
        return [CPCommandResult errorWithMessage:@"tar: missing archive name" code:1];
    }
    
    NSString *archivePath = [archive hasPrefix:@"/"] ? archive : [self.currentSession.workingDirectory stringByAppendingPathComponent:archive];
    
    NSMutableArray *taskArgs = [NSMutableArray array];
    
    if (create) [taskArgs addObject:@"-c"];
    if (extract) [taskArgs addObject:@"-x"];
    if (list) [taskArgs addObject:@"-t"];
    if (verbose) [taskArgs addObject:@"-v"];
    if (gzip) [taskArgs addObject:@"-z"];
    if (bzip2) [taskArgs addObject:@"-j"];
    if (xz) [taskArgs addObject:@"-J"];
    
    [taskArgs addObject:@"-f"];
    [taskArgs addObject:archivePath];
    
    if (directory) {
        [taskArgs addObject:@"-C"];
        [taskArgs addObject:directory];
    }
    
    [taskArgs addObjectsFromArray:files];
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/tar";
    task.arguments = taskArgs;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        CPCommandResult *result = [CPCommandResult successWithOutput:output ?: @""];
        result.exitCode = task.terminationStatus;
        result.success = (task.terminationStatus == 0);
        return result;
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"tar: failed" code:1];
    }
}

#pragma mark - Gzip

- (CPCommandResult *)cmdGzip:(NSArray *)args {
    BOOL decompress = NO, keep = NO, verbose = NO;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-d"]) decompress = YES;
        else if ([arg isEqualToString:@"-k"]) keep = YES;
        else if ([arg isEqualToString:@"-v"]) verbose = YES;
        else if (![arg hasPrefix:@"-"]) [files addObject:arg];
    }
    
    NSMutableArray *taskArgs = [NSMutableArray array];
    if (decompress) [taskArgs addObject:@"-d"];
    if (keep) [taskArgs addObject:@"-k"];
    if (verbose) [taskArgs addObject:@"-v"];
    [taskArgs addObjectsFromArray:files];
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/gzip";
    task.arguments = taskArgs;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
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
        return [CPCommandResult errorWithMessage:@"gzip: failed" code:1];
    }
}

- (CPCommandResult *)cmdGunzip:(NSArray *)args {
    NSMutableArray *newArgs = [@[@"-d"] mutableCopy];
    [newArgs addObjectsFromArray:args];
    return [self cmdGzip:newArgs];
}

- (CPCommandResult *)cmdBzip2:(NSArray *)args {
    BOOL decompress = NO, keep = NO;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-d"]) decompress = YES;
        else if ([arg isEqualToString:@"-k"]) keep = YES;
        else if (![arg hasPrefix:@"-"]) [files addObject:arg];
    }
    
    NSMutableArray *taskArgs = [NSMutableArray array];
    if (decompress) [taskArgs addObject:@"-d"];
    if (keep) [taskArgs addObject:@"-k"];
    [taskArgs addObjectsFromArray:files];
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/bzip2";
    task.arguments = taskArgs;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
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
        return [CPCommandResult errorWithMessage:@"bzip2: failed" code:1];
    }
}

- (CPCommandResult *)cmdBunzip2:(NSArray *)args {
    NSMutableArray *newArgs = [@[@"-d"] mutableCopy];
    [newArgs addObjectsFromArray:args];
    return [self cmdBzip2:newArgs];
}

- (CPCommandResult *)cmdXz:(NSArray *)args {
    BOOL decompress = NO;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-d"]) decompress = YES;
        else if (![arg hasPrefix:@"-"]) [files addObject:arg];
    }
    
    NSMutableArray *taskArgs = [NSMutableArray array];
    if (decompress) [taskArgs addObject:@"-d"];
    [taskArgs addObjectsFromArray:files];
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/xz";
    task.arguments = taskArgs;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
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
        return [CPCommandResult errorWithMessage:@"xz: not installed" code:1];
    }
}

- (CPCommandResult *)cmdUnxz:(NSArray *)args {
    NSMutableArray *newArgs = [@[@"-d"] mutableCopy];
    [newArgs addObjectsFromArray:args];
    return [self cmdXz:newArgs];
}

#pragma mark - Zip

- (CPCommandResult *)cmdZip:(NSArray *)args {
    if (args.count < 2) {
        return [CPCommandResult errorWithMessage:@"zip: missing archive or file operand" code:1];
    }
    
    BOOL recursive = NO;
    NSMutableArray *taskArgs = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-r"]) {
            recursive = YES;
            [taskArgs addObject:@"-r"];
        } else {
            [taskArgs addObject:arg];
        }
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/zip";
    task.arguments = taskArgs;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
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
        return [CPCommandResult errorWithMessage:@"zip: failed" code:1];
    }
}

- (CPCommandResult *)cmdUnzip:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"unzip: missing archive operand" code:1];
    }
    
    BOOL list = NO;
    NSString *destDir = nil;
    NSMutableArray *taskArgs = [NSMutableArray array];
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-l"]) {
            list = YES;
            [taskArgs addObject:@"-l"];
        } else if ([arg isEqualToString:@"-d"] && i + 1 < args.count) {
            destDir = args[++i];
            [taskArgs addObject:@"-d"];
            [taskArgs addObject:destDir];
        } else {
            [taskArgs addObject:arg];
        }
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/unzip";
    task.arguments = taskArgs;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
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
        return [CPCommandResult errorWithMessage:@"unzip: failed" code:1];
    }
}

- (CPCommandResult *)cmdRar:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"rar: not installed, use unrar or install via brew" code:1];
}

- (CPCommandResult *)cmdUnrar:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"unrar: not installed, install via 'brew install unrar'" code:1];
}

- (CPCommandResult *)cmd7z:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"7z: not installed, install via 'brew install p7zip'" code:1];
}

- (CPCommandResult *)cmd7za:(NSArray *)args {
    return [self cmd7z:args];
}

- (CPCommandResult *)cmdCpio:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/cpio";
    task.arguments = args;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
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
        return [CPCommandResult errorWithMessage:@"cpio: failed" code:1];
    }
}

- (CPCommandResult *)cmdAr:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/ar";
    task.arguments = args;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output ?: @""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"ar: failed" code:1];
    }
}

#pragma mark - Compressed File Tools

- (CPCommandResult *)cmdZcat:(NSArray *)args {
    NSMutableArray *taskArgs = [@[@"-c", @"-d"] mutableCopy];
    [taskArgs addObjectsFromArray:args];
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/gzip";
    task.arguments = taskArgs;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output ?: @""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"zcat: failed" code:1];
    }
}

- (CPCommandResult *)cmdZgrep:(NSArray *)args {
    if (args.count < 2) {
        return [CPCommandResult errorWithMessage:@"zgrep: missing pattern or file" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/zgrep";
    task.arguments = args;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output ?: @""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"zgrep: failed" code:1];
    }
}

- (CPCommandResult *)cmdZless:(NSArray *)args {
    return [self cmdZcat:args];
}

- (CPCommandResult *)cmdZmore:(NSArray *)args {
    return [self cmdZcat:args];
}

- (CPCommandResult *)cmdZdiff:(NSArray *)args {
    if (args.count < 2) {
        return [CPCommandResult errorWithMessage:@"zdiff: missing file operand" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/zdiff";
    task.arguments = args;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output ?: @""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"zdiff: failed" code:1];
    }
}

- (CPCommandResult *)cmdLz4:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"lz4: not installed" code:1];
}

- (CPCommandResult *)cmdZstd:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"zstd: not installed" code:1];
}

- (CPCommandResult *)cmdCompress:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/compress";
    task.arguments = args;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
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
        return [CPCommandResult errorWithMessage:@"compress: failed" code:1];
    }
}

- (CPCommandResult *)cmdUncompress:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/uncompress";
    task.arguments = args;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
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
        return [CPCommandResult errorWithMessage:@"uncompress: failed" code:1];
    }
}

- (CPCommandResult *)cmdExpand_archive:(NSArray *)args {
    return [self cmdUnzip:args];
}

- (CPCommandResult *)cmdCompress_archive:(NSArray *)args {
    return [self cmdZip:args];
}

@end
