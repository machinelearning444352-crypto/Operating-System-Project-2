#import "CrossPlatformCommandEngine.h"

@implementation CrossPlatformCommandEngine (FileCommands)

#pragma mark - Directory Listing Commands

- (CPCommandResult *)cmdLs:(NSArray *)args {
    BOOL showAll = NO, longFormat = NO, humanReadable = NO, recursive = NO, sortByTime = NO;
    NSMutableArray *paths = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"]) {
            if ([arg containsString:@"a"]) showAll = YES;
            if ([arg containsString:@"l"]) longFormat = YES;
            if ([arg containsString:@"h"]) humanReadable = YES;
            if ([arg containsString:@"R"]) recursive = YES;
            if ([arg containsString:@"t"]) sortByTime = YES;
        } else {
            [paths addObject:arg];
        }
    }
    
    if (paths.count == 0) {
        [paths addObject:self.currentSession.workingDirectory];
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *path in paths) {
        NSString *fullPath = [path hasPrefix:@"/"] ? path : [self.currentSession.workingDirectory stringByAppendingPathComponent:path];
        
        BOOL isDir;
        if (![fm fileExistsAtPath:fullPath isDirectory:&isDir]) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"ls: %@: No such file or directory", path] code:1];
        }
        
        if (!isDir) {
            [output appendFormat:@"%@\n", [path lastPathComponent]];
            continue;
        }
        
        if (paths.count > 1) {
            [output appendFormat:@"%@:\n", path];
        }
        
        NSError *error;
        NSArray *contents = [fm contentsOfDirectoryAtPath:fullPath error:&error];
        if (error) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"ls: %@: %@", path, error.localizedDescription] code:1];
        }
        
        NSMutableArray *items = [NSMutableArray array];
        for (NSString *item in contents) {
            if (!showAll && [item hasPrefix:@"."]) continue;
            [items addObject:item];
        }
        
        if (sortByTime) {
            [items sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
                NSString *pathA = [fullPath stringByAppendingPathComponent:a];
                NSString *pathB = [fullPath stringByAppendingPathComponent:b];
                NSDictionary *attrsA = [fm attributesOfItemAtPath:pathA error:nil];
                NSDictionary *attrsB = [fm attributesOfItemAtPath:pathB error:nil];
                return [attrsB[NSFileModificationDate] compare:attrsA[NSFileModificationDate]];
            }];
        } else {
            [items sortUsingSelector:@selector(caseInsensitiveCompare:)];
        }
        
        if (longFormat) {
            for (NSString *item in items) {
                NSString *itemPath = [fullPath stringByAppendingPathComponent:item];
                NSDictionary *attrs = [fm attributesOfItemAtPath:itemPath error:nil];
                
                NSString *type = [attrs[NSFileType] isEqualToString:NSFileTypeDirectory] ? @"d" : @"-";
                NSString *perms = @"rwxr-xr-x";
                unsigned long long size = [attrs[NSFileSize] unsignedLongLongValue];
                NSDate *modDate = attrs[NSFileModificationDate];
                
                NSDateFormatter *df = [[NSDateFormatter alloc] init];
                df.dateFormat = @"MMM dd HH:mm";
                NSString *dateStr = [df stringFromDate:modDate];
                
                NSString *sizeStr;
                if (humanReadable) {
                    if (size >= 1073741824) sizeStr = [NSString stringWithFormat:@"%.1fG", size / 1073741824.0];
                    else if (size >= 1048576) sizeStr = [NSString stringWithFormat:@"%.1fM", size / 1048576.0];
                    else if (size >= 1024) sizeStr = [NSString stringWithFormat:@"%.1fK", size / 1024.0];
                    else sizeStr = [NSString stringWithFormat:@"%llu", size];
                } else {
                    sizeStr = [NSString stringWithFormat:@"%8llu", size];
                }
                
                [output appendFormat:@"%@%@ 1 %@ %@ %@ %@ %@\n", type, perms, NSUserName(), @"staff", sizeStr, dateStr, item];
            }
        } else {
            for (NSString *item in items) {
                [output appendFormat:@"%@\n", item];
            }
        }
        
        if (recursive) {
            for (NSString *item in items) {
                NSString *subPath = [fullPath stringByAppendingPathComponent:item];
                BOOL subIsDir;
                if ([fm fileExistsAtPath:subPath isDirectory:&subIsDir] && subIsDir) {
                    [output appendFormat:@"\n%@/%@:\n", path, item];
                    CPCommandResult *subResult = [self cmdLs:@[[subPath stringByAppendingString:(showAll ? @" -a" : @"")]]];
                    [output appendString:subResult.output];
                }
            }
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdDir:(NSArray *)args {
    return [self cmdLs:args];
}

#pragma mark - File Content Commands

- (CPCommandResult *)cmdCat:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"cat: missing operand" code:1];
    }
    
    BOOL showNumbers = NO, showEnds = NO, showTabs = NO;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"]) {
            if ([arg containsString:@"n"]) showNumbers = YES;
            if ([arg containsString:@"E"]) showEnds = YES;
            if ([arg containsString:@"T"]) showTabs = YES;
        } else {
            [files addObject:arg];
        }
    }
    
    NSMutableString *output = [NSMutableString string];
    NSInteger lineNum = 1;
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (!content) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"cat: %@: No such file or directory", file] code:1];
        }
        
        if (showTabs) {
            content = [content stringByReplacingOccurrencesOfString:@"\t" withString:@"^I"];
        }
        
        if (showNumbers || showEnds) {
            NSArray *lines = [content componentsSeparatedByString:@"\n"];
            for (NSString *line in lines) {
                NSString *displayLine = line;
                if (showEnds) displayLine = [displayLine stringByAppendingString:@"$"];
                if (showNumbers) {
                    [output appendFormat:@"%6ld\t%@\n", (long)lineNum++, displayLine];
                } else {
                    [output appendFormat:@"%@\n", displayLine];
                }
            }
        } else {
            [output appendString:content];
            if (![content hasSuffix:@"\n"]) [output appendString:@"\n"];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdType:(NSArray *)args {
    return [self cmdCat:args];
}

- (CPCommandResult *)cmdMore:(NSArray *)args {
    return [self cmdCat:args];
}

- (CPCommandResult *)cmdLess:(NSArray *)args {
    return [self cmdCat:args];
}

- (CPCommandResult *)cmdHead:(NSArray *)args {
    NSInteger lines = 10;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-n"] && i + 1 < args.count) {
            lines = [args[++i] integerValue];
        } else if ([arg hasPrefix:@"-"] && arg.length > 1) {
            lines = [[arg substringFromIndex:1] integerValue];
        } else {
            [files addObject:arg];
        }
    }
    
    if (files.count == 0) {
        return [CPCommandResult errorWithMessage:@"head: missing file operand" code:1];
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (!content) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"head: %@: No such file or directory", file] code:1];
        }
        
        if (files.count > 1) {
            [output appendFormat:@"==> %@ <==\n", file];
        }
        
        NSArray *allLines = [content componentsSeparatedByString:@"\n"];
        NSInteger count = MIN(lines, (NSInteger)allLines.count);
        for (NSInteger i = 0; i < count; i++) {
            [output appendFormat:@"%@\n", allLines[i]];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdTail:(NSArray *)args {
    NSInteger lines = 10;
    BOOL follow = NO;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-n"] && i + 1 < args.count) {
            lines = [args[++i] integerValue];
        } else if ([arg isEqualToString:@"-f"]) {
            follow = YES;
        } else if ([arg hasPrefix:@"-"] && arg.length > 1) {
            lines = [[arg substringFromIndex:1] integerValue];
        } else {
            [files addObject:arg];
        }
    }
    
    if (files.count == 0) {
        return [CPCommandResult errorWithMessage:@"tail: missing file operand" code:1];
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (!content) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"tail: %@: No such file or directory", file] code:1];
        }
        
        if (files.count > 1) {
            [output appendFormat:@"==> %@ <==\n", file];
        }
        
        NSArray *allLines = [content componentsSeparatedByString:@"\n"];
        NSInteger start = MAX(0, (NSInteger)allLines.count - lines);
        for (NSInteger i = start; i < (NSInteger)allLines.count; i++) {
            [output appendFormat:@"%@\n", allLines[i]];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

#pragma mark - File Operations

- (CPCommandResult *)cmdCp:(NSArray *)args {
    BOOL recursive = NO, force = NO, interactive = NO, verbose = NO;
    NSMutableArray *sources = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"]) {
            if ([arg containsString:@"r"] || [arg containsString:@"R"]) recursive = YES;
            if ([arg containsString:@"f"]) force = YES;
            if ([arg containsString:@"i"]) interactive = YES;
            if ([arg containsString:@"v"]) verbose = YES;
        } else {
            [sources addObject:arg];
        }
    }
    
    if (sources.count < 2) {
        return [CPCommandResult errorWithMessage:@"cp: missing file operand" code:1];
    }
    
    NSString *dest = sources.lastObject;
    [sources removeLastObject];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *destPath = [dest hasPrefix:@"/"] ? dest : [self.currentSession.workingDirectory stringByAppendingPathComponent:dest];
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *source in sources) {
        NSString *srcPath = [source hasPrefix:@"/"] ? source : [self.currentSession.workingDirectory stringByAppendingPathComponent:source];
        
        BOOL srcIsDir;
        if (![fm fileExistsAtPath:srcPath isDirectory:&srcIsDir]) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"cp: %@: No such file or directory", source] code:1];
        }
        
        if (srcIsDir && !recursive) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"cp: %@ is a directory (not copied)", source] code:1];
        }
        
        NSString *finalDest = destPath;
        BOOL destIsDir;
        if ([fm fileExistsAtPath:destPath isDirectory:&destIsDir] && destIsDir) {
            finalDest = [destPath stringByAppendingPathComponent:[srcPath lastPathComponent]];
        }
        
        NSError *error;
        if ([fm fileExistsAtPath:finalDest]) {
            if (force) {
                [fm removeItemAtPath:finalDest error:nil];
            }
        }
        
        if (![fm copyItemAtPath:srcPath toPath:finalDest error:&error]) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"cp: %@", error.localizedDescription] code:1];
        }
        
        if (verbose) {
            [output appendFormat:@"'%@' -> '%@'\n", source, finalDest];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdCopy:(NSArray *)args {
    return [self cmdCp:args];
}

- (CPCommandResult *)cmdMv:(NSArray *)args {
    BOOL force = NO, interactive = NO, verbose = NO;
    NSMutableArray *sources = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"]) {
            if ([arg containsString:@"f"]) force = YES;
            if ([arg containsString:@"i"]) interactive = YES;
            if ([arg containsString:@"v"]) verbose = YES;
        } else {
            [sources addObject:arg];
        }
    }
    
    if (sources.count < 2) {
        return [CPCommandResult errorWithMessage:@"mv: missing file operand" code:1];
    }
    
    NSString *dest = sources.lastObject;
    [sources removeLastObject];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *destPath = [dest hasPrefix:@"/"] ? dest : [self.currentSession.workingDirectory stringByAppendingPathComponent:dest];
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *source in sources) {
        NSString *srcPath = [source hasPrefix:@"/"] ? source : [self.currentSession.workingDirectory stringByAppendingPathComponent:source];
        
        if (![fm fileExistsAtPath:srcPath]) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"mv: %@: No such file or directory", source] code:1];
        }
        
        NSString *finalDest = destPath;
        BOOL destIsDir;
        if ([fm fileExistsAtPath:destPath isDirectory:&destIsDir] && destIsDir) {
            finalDest = [destPath stringByAppendingPathComponent:[srcPath lastPathComponent]];
        }
        
        NSError *error;
        if ([fm fileExistsAtPath:finalDest]) {
            if (force) {
                [fm removeItemAtPath:finalDest error:nil];
            }
        }
        
        if (![fm moveItemAtPath:srcPath toPath:finalDest error:&error]) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"mv: %@", error.localizedDescription] code:1];
        }
        
        if (verbose) {
            [output appendFormat:@"'%@' -> '%@'\n", source, finalDest];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdMove:(NSArray *)args {
    return [self cmdMv:args];
}

- (CPCommandResult *)cmdRen:(NSArray *)args {
    return [self cmdMv:args];
}

- (CPCommandResult *)cmdRm:(NSArray *)args {
    BOOL recursive = NO, force = NO, verbose = NO;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"]) {
            if ([arg containsString:@"r"] || [arg containsString:@"R"]) recursive = YES;
            if ([arg containsString:@"f"]) force = YES;
            if ([arg containsString:@"v"]) verbose = YES;
        } else {
            [files addObject:arg];
        }
    }
    
    if (files.count == 0 && !force) {
        return [CPCommandResult errorWithMessage:@"rm: missing operand" code:1];
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        
        BOOL isDir;
        if (![fm fileExistsAtPath:path isDirectory:&isDir]) {
            if (!force) {
                return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"rm: %@: No such file or directory", file] code:1];
            }
            continue;
        }
        
        if (isDir && !recursive) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"rm: %@: is a directory", file] code:1];
        }
        
        NSError *error;
        if (![fm removeItemAtPath:path error:&error]) {
            if (!force) {
                return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"rm: %@", error.localizedDescription] code:1];
            }
        }
        
        if (verbose) {
            [output appendFormat:@"removed '%@'\n", file];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdDel:(NSArray *)args {
    return [self cmdRm:args];
}

- (CPCommandResult *)cmdRmdir:(NSArray *)args {
    BOOL verbose = NO, parents = NO;
    NSMutableArray *dirs = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"]) {
            if ([arg containsString:@"v"]) verbose = YES;
            if ([arg containsString:@"p"]) parents = YES;
        } else {
            [dirs addObject:arg];
        }
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *dir in dirs) {
        NSString *path = [dir hasPrefix:@"/"] ? dir : [self.currentSession.workingDirectory stringByAppendingPathComponent:dir];
        
        NSArray *contents = [fm contentsOfDirectoryAtPath:path error:nil];
        if (contents.count > 0) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"rmdir: %@: Directory not empty", dir] code:1];
        }
        
        NSError *error;
        if (![fm removeItemAtPath:path error:&error]) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"rmdir: %@", error.localizedDescription] code:1];
        }
        
        if (verbose) {
            [output appendFormat:@"rmdir: removing directory, '%@'\n", dir];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdMkdir:(NSArray *)args {
    BOOL parents = NO, verbose = NO;
    NSMutableArray *dirs = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"]) {
            if ([arg containsString:@"p"]) parents = YES;
            if ([arg containsString:@"v"]) verbose = YES;
        } else {
            [dirs addObject:arg];
        }
    }
    
    if (dirs.count == 0) {
        return [CPCommandResult errorWithMessage:@"mkdir: missing operand" code:1];
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *dir in dirs) {
        NSString *path = [dir hasPrefix:@"/"] ? dir : [self.currentSession.workingDirectory stringByAppendingPathComponent:dir];
        
        NSError *error;
        BOOL success;
        if (parents) {
            success = [fm createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        } else {
            success = [fm createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:&error];
        }
        
        if (!success) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"mkdir: %@", error.localizedDescription] code:1];
        }
        
        if (verbose) {
            [output appendFormat:@"mkdir: created directory '%@'\n", dir];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdMd:(NSArray *)args {
    NSMutableArray *newArgs = [args mutableCopy];
    if (![newArgs containsObject:@"-p"]) {
        [newArgs insertObject:@"-p" atIndex:0];
    }
    return [self cmdMkdir:newArgs];
}

- (CPCommandResult *)cmdTouch:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"touch: missing file operand" code:1];
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *file in args) {
        if ([file hasPrefix:@"-"]) continue;
        
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        
        if ([fm fileExistsAtPath:path]) {
            NSDictionary *attrs = @{NSFileModificationDate: [NSDate date]};
            [fm setAttributes:attrs ofItemAtPath:path error:nil];
        } else {
            [fm createFileAtPath:path contents:[NSData data] attributes:nil];
        }
    }
    
    return [CPCommandResult successWithOutput:@""];
}

#pragma mark - File Permissions

- (CPCommandResult *)cmdChmod:(NSArray *)args {
    if (args.count < 2) {
        return [CPCommandResult errorWithMessage:@"chmod: missing operand" code:1];
    }
    
    BOOL recursive = NO;
    NSString *modeStr = nil;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-R"]) {
            recursive = YES;
        } else if (!modeStr && ![arg hasPrefix:@"-"]) {
            modeStr = arg;
        } else if (![arg hasPrefix:@"-"]) {
            [files addObject:arg];
        }
    }
    
    if (!modeStr || files.count == 0) {
        return [CPCommandResult errorWithMessage:@"chmod: missing operand" code:1];
    }
    
    mode_t mode = (mode_t)strtol([modeStr UTF8String], NULL, 8);
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        
        NSDictionary *attrs = @{NSFilePosixPermissions: @(mode)};
        NSError *error;
        if (![fm setAttributes:attrs ofItemAtPath:path error:&error]) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"chmod: %@", error.localizedDescription] code:1];
        }
    }
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)cmdChown:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"chown: Operation not permitted (simulated environment)" code:1];
}

- (CPCommandResult *)cmdChgrp:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"chgrp: Operation not permitted (simulated environment)" code:1];
}

#pragma mark - Links

- (CPCommandResult *)cmdLn:(NSArray *)args {
    BOOL symbolic = NO, force = NO;
    NSMutableArray *paths = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-s"]) symbolic = YES;
        else if ([arg isEqualToString:@"-f"]) force = YES;
        else if (![arg hasPrefix:@"-"]) [paths addObject:arg];
    }
    
    if (paths.count < 2) {
        return [CPCommandResult errorWithMessage:@"ln: missing file operand" code:1];
    }
    
    NSString *target = paths[0];
    NSString *link = paths[1];
    
    NSString *targetPath = [target hasPrefix:@"/"] ? target : [self.currentSession.workingDirectory stringByAppendingPathComponent:target];
    NSString *linkPath = [link hasPrefix:@"/"] ? link : [self.currentSession.workingDirectory stringByAppendingPathComponent:link];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (force && [fm fileExistsAtPath:linkPath]) {
        [fm removeItemAtPath:linkPath error:nil];
    }
    
    NSError *error;
    BOOL success;
    if (symbolic) {
        success = [fm createSymbolicLinkAtPath:linkPath withDestinationPath:targetPath error:&error];
    } else {
        success = [fm linkItemAtPath:targetPath toPath:linkPath error:&error];
    }
    
    if (!success) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"ln: %@", error.localizedDescription] code:1];
    }
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)cmdMklink:(NSArray *)args {
    NSMutableArray *newArgs = [@[@"-s"] mutableCopy];
    [newArgs addObjectsFromArray:args];
    return [self cmdLn:newArgs];
}

#pragma mark - Search Commands

- (CPCommandResult *)cmdFind:(NSArray *)args {
    NSString *startPath = self.currentSession.workingDirectory;
    NSString *namePattern = nil;
    NSString *typeFilter = nil;
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-name"] && i + 1 < args.count) {
            namePattern = args[++i];
        } else if ([arg isEqualToString:@"-type"] && i + 1 < args.count) {
            typeFilter = args[++i];
        } else if (![arg hasPrefix:@"-"]) {
            startPath = [arg hasPrefix:@"/"] ? arg : [self.currentSession.workingDirectory stringByAppendingPathComponent:arg];
        }
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableString *output = [NSMutableString string];
    
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:startPath];
    NSString *file;
    while ((file = [enumerator nextObject])) {
        NSString *fullPath = [startPath stringByAppendingPathComponent:file];
        
        BOOL isDir;
        [fm fileExistsAtPath:fullPath isDirectory:&isDir];
        
        if (typeFilter) {
            if ([typeFilter isEqualToString:@"f"] && isDir) continue;
            if ([typeFilter isEqualToString:@"d"] && !isDir) continue;
        }
        
        if (namePattern) {
            NSString *name = [file lastPathComponent];
            NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF LIKE %@", namePattern];
            if (![pred evaluateWithObject:name]) continue;
        }
        
        [output appendFormat:@"%@\n", fullPath];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdLocate:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"locate: no pattern to search for specified" code:1];
    }
    return [self cmdFind:@[@"/", @"-name", [NSString stringWithFormat:@"*%@*", args[0]]]];
}

- (CPCommandResult *)cmdWhere:(NSArray *)args {
    return [self builtinWhich:args];
}

- (CPCommandResult *)cmdWhereIs:(NSArray *)args {
    return [self builtinWhich:args];
}

#pragma mark - File Info

- (CPCommandResult *)cmdFile:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"file: missing file operand" code:1];
    }
    
    NSMutableString *output = [NSMutableString string];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *file in args) {
        if ([file hasPrefix:@"-"]) continue;
        
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        
        BOOL isDir;
        if (![fm fileExistsAtPath:path isDirectory:&isDir]) {
            [output appendFormat:@"%@: cannot open (No such file or directory)\n", file];
            continue;
        }
        
        if (isDir) {
            [output appendFormat:@"%@: directory\n", file];
        } else {
            NSString *ext = [[path pathExtension] lowercaseString];
            NSString *type = @"data";
            
            if ([@[@"txt", @"md", @"rtf"] containsObject:ext]) type = @"ASCII text";
            else if ([@[@"c", @"h", @"m", @"mm", @"cpp", @"hpp"] containsObject:ext]) type = @"C source, ASCII text";
            else if ([@[@"py"] containsObject:ext]) type = @"Python script, ASCII text executable";
            else if ([@[@"sh", @"bash", @"zsh"] containsObject:ext]) type = @"Bourne-Again shell script, ASCII text executable";
            else if ([@[@"js"] containsObject:ext]) type = @"JavaScript source, ASCII text";
            else if ([@[@"json"] containsObject:ext]) type = @"JSON data";
            else if ([@[@"xml", @"plist"] containsObject:ext]) type = @"XML document text";
            else if ([@[@"html", @"htm"] containsObject:ext]) type = @"HTML document, ASCII text";
            else if ([@[@"png"] containsObject:ext]) type = @"PNG image data";
            else if ([@[@"jpg", @"jpeg"] containsObject:ext]) type = @"JPEG image data";
            else if ([@[@"gif"] containsObject:ext]) type = @"GIF image data";
            else if ([@[@"pdf"] containsObject:ext]) type = @"PDF document";
            else if ([@[@"zip"] containsObject:ext]) type = @"Zip archive data";
            else if ([@[@"gz", @"gzip"] containsObject:ext]) type = @"gzip compressed data";
            else if ([@[@"tar"] containsObject:ext]) type = @"POSIX tar archive";
            else if ([@[@"dmg"] containsObject:ext]) type = @"Apple disk image";
            else if ([@[@"app"] containsObject:ext]) type = @"Mach-O universal binary";
            
            [output appendFormat:@"%@: %@\n", file, type];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdStat:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"stat: missing operand" code:1];
    }
    
    NSMutableString *output = [NSMutableString string];
    NSFileManager *fm = [NSFileManager defaultManager];
    
    for (NSString *file in args) {
        if ([file hasPrefix:@"-"]) continue;
        
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
        if (!attrs) {
            [output appendFormat:@"stat: %@: No such file or directory\n", file];
            continue;
        }
        
        [output appendFormat:@"  File: %@\n", file];
        [output appendFormat:@"  Size: %-15llu Blocks: %-10llu IO Block: 4096\n",
         [attrs[NSFileSize] unsignedLongLongValue], [attrs[NSFileSize] unsignedLongLongValue] / 512 + 1];
        [output appendFormat:@"Device: %-15s Inode: %-15llu Links: 1\n", "0,0",
         [attrs[NSFileSystemFileNumber] unsignedLongLongValue]];
        [output appendFormat:@"Access: %@\n", attrs[NSFileCreationDate]];
        [output appendFormat:@"Modify: %@\n", attrs[NSFileModificationDate]];
        [output appendFormat:@"Change: %@\n", attrs[NSFileModificationDate]];
    }
    
    return [CPCommandResult successWithOutput:output];
}

#pragma mark - Disk Usage

- (CPCommandResult *)cmdDu:(NSArray *)args {
    BOOL humanReadable = NO, summary = NO;
    NSMutableArray *paths = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg containsString:@"h"]) humanReadable = YES;
        if ([arg containsString:@"s"]) summary = YES;
        if (![arg hasPrefix:@"-"]) [paths addObject:arg];
    }
    
    if (paths.count == 0) [paths addObject:@"."];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *path in paths) {
        NSString *fullPath = [path hasPrefix:@"/"] ? path : [self.currentSession.workingDirectory stringByAppendingPathComponent:path];
        
        unsigned long long totalSize = 0;
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:fullPath];
        NSString *file;
        while ((file = [enumerator nextObject])) {
            NSString *filePath = [fullPath stringByAppendingPathComponent:file];
            NSDictionary *attrs = [fm attributesOfItemAtPath:filePath error:nil];
            totalSize += [attrs[NSFileSize] unsignedLongLongValue];
        }
        
        NSString *sizeStr;
        if (humanReadable) {
            if (totalSize >= 1073741824) sizeStr = [NSString stringWithFormat:@"%.1fG", totalSize / 1073741824.0];
            else if (totalSize >= 1048576) sizeStr = [NSString stringWithFormat:@"%.1fM", totalSize / 1048576.0];
            else if (totalSize >= 1024) sizeStr = [NSString stringWithFormat:@"%.1fK", totalSize / 1024.0];
            else sizeStr = [NSString stringWithFormat:@"%llu", totalSize];
        } else {
            sizeStr = [NSString stringWithFormat:@"%llu", totalSize / 1024];
        }
        
        [output appendFormat:@"%@\t%@\n", sizeStr, path];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdDf:(NSArray *)args {
    BOOL humanReadable = NO;
    for (NSString *arg in args) {
        if ([arg containsString:@"h"]) humanReadable = YES;
    }
    
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:@"/" error:nil];
    unsigned long long total = [attrs[NSFileSystemSize] unsignedLongLongValue];
    unsigned long long free = [attrs[NSFileSystemFreeSize] unsignedLongLongValue];
    unsigned long long used = total - free;
    
    NSMutableString *output = [NSMutableString string];
    [output appendString:@"Filesystem      Size  Used Avail Use% Mounted on\n"];
    
    if (humanReadable) {
        [output appendFormat:@"%-15s %4.1fG %4.1fG %4.1fG %3llu%% /\n",
         "/dev/disk1s1",
         total / 1073741824.0, used / 1073741824.0, free / 1073741824.0,
         (used * 100) / total];
    } else {
        [output appendFormat:@"%-15s %12llu %12llu %12llu %3llu%% /\n",
         "/dev/disk1s1", total / 1024, used / 1024, free / 1024, (used * 100) / total];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdTree:(NSArray *)args {
    NSInteger maxDepth = INT_MAX;
    BOOL showAll = NO;
    NSString *path = self.currentSession.workingDirectory;
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-L"] && i + 1 < args.count) {
            maxDepth = [args[++i] integerValue];
        } else if ([arg isEqualToString:@"-a"]) {
            showAll = YES;
        } else if (![arg hasPrefix:@"-"]) {
            path = [arg hasPrefix:@"/"] ? arg : [self.currentSession.workingDirectory stringByAppendingPathComponent:arg];
        }
    }
    
    NSMutableString *output = [NSMutableString string];
    [output appendFormat:@"%@\n", [path lastPathComponent]];
    [self treeHelper:path prefix:@"" output:output depth:0 maxDepth:maxDepth showAll:showAll];
    
    return [CPCommandResult successWithOutput:output];
}

- (void)treeHelper:(NSString *)path prefix:(NSString *)prefix output:(NSMutableString *)output depth:(NSInteger)depth maxDepth:(NSInteger)maxDepth showAll:(BOOL)showAll {
    if (depth >= maxDepth) return;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:path error:nil];
    
    NSMutableArray *items = [NSMutableArray array];
    for (NSString *item in contents) {
        if (!showAll && [item hasPrefix:@"."]) continue;
        [items addObject:item];
    }
    [items sortUsingSelector:@selector(caseInsensitiveCompare:)];
    
    for (NSInteger i = 0; i < items.count; i++) {
        NSString *item = items[i];
        BOOL isLast = (i == items.count - 1);
        NSString *connector = isLast ? @"└── " : @"├── ";
        NSString *newPrefix = isLast ? @"    " : @"│   ";
        
        NSString *fullPath = [path stringByAppendingPathComponent:item];
        BOOL isDir;
        [fm fileExistsAtPath:fullPath isDirectory:&isDir];
        
        [output appendFormat:@"%@%@%@\n", prefix, connector, item];
        
        if (isDir) {
            [self treeHelper:fullPath prefix:[prefix stringByAppendingString:newPrefix] output:output depth:depth + 1 maxDepth:maxDepth showAll:showAll];
        }
    }
}

@end
