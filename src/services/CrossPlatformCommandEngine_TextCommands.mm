#import "CrossPlatformCommandEngine.h"
#import <CommonCrypto/CommonDigest.h>

@implementation CrossPlatformCommandEngine (TextCommands)

#pragma mark - Text Processing

- (CPCommandResult *)cmdWc:(NSArray *)args {
    BOOL countLines = YES, countWords = YES, countBytes = YES, countChars = NO;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"]) {
            countLines = countWords = countBytes = NO;
            if ([arg containsString:@"l"]) countLines = YES;
            if ([arg containsString:@"w"]) countWords = YES;
            if ([arg containsString:@"c"]) countBytes = YES;
            if ([arg containsString:@"m"]) countChars = YES;
        } else {
            [files addObject:arg];
        }
    }
    
    if (files.count == 0) {
        return [CPCommandResult errorWithMessage:@"wc: missing file operand" code:1];
    }
    
    NSMutableString *output = [NSMutableString string];
    NSUInteger totalLines = 0, totalWords = 0, totalBytes = 0;
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (!content) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"wc: %@: No such file or directory", file] code:1];
        }
        
        NSUInteger lines = [[content componentsSeparatedByString:@"\n"] count] - 1;
        NSUInteger words = [[content componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]].count;
        NSUInteger bytes = [content lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
        
        totalLines += lines;
        totalWords += words;
        totalBytes += bytes;
        
        NSMutableString *line = [NSMutableString string];
        if (countLines) [line appendFormat:@"%8lu ", (unsigned long)lines];
        if (countWords) [line appendFormat:@"%8lu ", (unsigned long)words];
        if (countBytes) [line appendFormat:@"%8lu ", (unsigned long)bytes];
        [line appendFormat:@"%@\n", file];
        [output appendString:line];
    }
    
    if (files.count > 1) {
        NSMutableString *line = [NSMutableString string];
        if (countLines) [line appendFormat:@"%8lu ", (unsigned long)totalLines];
        if (countWords) [line appendFormat:@"%8lu ", (unsigned long)totalWords];
        if (countBytes) [line appendFormat:@"%8lu ", (unsigned long)totalBytes];
        [line appendString:@"total\n"];
        [output appendString:line];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdDiff:(NSArray *)args {
    BOOL unified = NO, context = NO, sideBySide = NO;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-u"]) unified = YES;
        else if ([arg isEqualToString:@"-c"]) context = YES;
        else if ([arg isEqualToString:@"-y"]) sideBySide = YES;
        else if (![arg hasPrefix:@"-"]) [files addObject:arg];
    }
    
    if (files.count < 2) {
        return [CPCommandResult errorWithMessage:@"diff: missing operand" code:2];
    }
    
    NSString *path1 = [files[0] hasPrefix:@"/"] ? files[0] : [self.currentSession.workingDirectory stringByAppendingPathComponent:files[0]];
    NSString *path2 = [files[1] hasPrefix:@"/"] ? files[1] : [self.currentSession.workingDirectory stringByAppendingPathComponent:files[1]];
    
    NSString *content1 = [NSString stringWithContentsOfFile:path1 encoding:NSUTF8StringEncoding error:nil];
    NSString *content2 = [NSString stringWithContentsOfFile:path2 encoding:NSUTF8StringEncoding error:nil];
    
    if (!content1) return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"diff: %@: No such file or directory", files[0]] code:2];
    if (!content2) return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"diff: %@: No such file or directory", files[1]] code:2];
    
    NSArray *lines1 = [content1 componentsSeparatedByString:@"\n"];
    NSArray *lines2 = [content2 componentsSeparatedByString:@"\n"];
    
    if ([content1 isEqualToString:content2]) {
        return [CPCommandResult successWithOutput:@""];
    }
    
    NSMutableString *output = [NSMutableString string];
    
    if (unified) {
        [output appendFormat:@"--- %@\n", files[0]];
        [output appendFormat:@"+++ %@\n", files[1]];
    }
    
    NSInteger maxLines = MAX(lines1.count, lines2.count);
    for (NSInteger i = 0; i < maxLines; i++) {
        NSString *line1 = i < lines1.count ? lines1[i] : @"";
        NSString *line2 = i < lines2.count ? lines2[i] : @"";
        
        if (![line1 isEqualToString:line2]) {
            if (unified) {
                [output appendFormat:@"@@ -%ld,1 +%ld,1 @@\n", (long)(i + 1), (long)(i + 1)];
                if (i < lines1.count) [output appendFormat:@"-%@\n", line1];
                if (i < lines2.count) [output appendFormat:@"+%@\n", line2];
            } else {
                [output appendFormat:@"%ldc%ld\n", (long)(i + 1), (long)(i + 1)];
                [output appendFormat:@"< %@\n", line1];
                [output appendString:@"---\n"];
                [output appendFormat:@"> %@\n", line2];
            }
        }
    }
    
    CPCommandResult *result = [CPCommandResult successWithOutput:output];
    result.exitCode = 1;
    return result;
}

- (CPCommandResult *)cmdFc:(NSArray *)args {
    return [self cmdDiff:args];
}

- (CPCommandResult *)cmdCmp:(NSArray *)args {
    NSMutableArray *files = [NSMutableArray array];
    for (NSString *arg in args) {
        if (![arg hasPrefix:@"-"]) [files addObject:arg];
    }
    
    if (files.count < 2) {
        return [CPCommandResult errorWithMessage:@"cmp: missing operand" code:2];
    }
    
    NSString *path1 = [files[0] hasPrefix:@"/"] ? files[0] : [self.currentSession.workingDirectory stringByAppendingPathComponent:files[0]];
    NSString *path2 = [files[1] hasPrefix:@"/"] ? files[1] : [self.currentSession.workingDirectory stringByAppendingPathComponent:files[1]];
    
    NSData *data1 = [NSData dataWithContentsOfFile:path1];
    NSData *data2 = [NSData dataWithContentsOfFile:path2];
    
    if (!data1) return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"cmp: %@: No such file or directory", files[0]] code:2];
    if (!data2) return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"cmp: %@: No such file or directory", files[1]] code:2];
    
    if ([data1 isEqualToData:data2]) {
        return [CPCommandResult successWithOutput:@""];
    }
    
    const uint8_t *bytes1 = (const uint8_t *)data1.bytes;
    const uint8_t *bytes2 = (const uint8_t *)data2.bytes;
    NSUInteger minLen = MIN(data1.length, data2.length);
    
    for (NSUInteger i = 0; i < minLen; i++) {
        if (bytes1[i] != bytes2[i]) {
            NSString *output = [NSString stringWithFormat:@"%@ %@ differ: byte %lu, line 1\n", files[0], files[1], (unsigned long)(i + 1)];
            CPCommandResult *result = [CPCommandResult successWithOutput:output];
            result.exitCode = 1;
            return result;
        }
    }
    
    if (data1.length != data2.length) {
        NSString *output = [NSString stringWithFormat:@"cmp: EOF on %@\n", data1.length < data2.length ? files[0] : files[1]];
        CPCommandResult *result = [CPCommandResult successWithOutput:output];
        result.exitCode = 1;
        return result;
    }
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)cmdComm:(NSArray *)args {
    BOOL suppress1 = NO, suppress2 = NO, suppress3 = NO;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg containsString:@"1"]) suppress1 = YES;
        if ([arg containsString:@"2"]) suppress2 = YES;
        if ([arg containsString:@"3"]) suppress3 = YES;
        if (![arg hasPrefix:@"-"]) [files addObject:arg];
    }
    
    if (files.count < 2) {
        return [CPCommandResult errorWithMessage:@"comm: missing operand" code:1];
    }
    
    NSString *path1 = [files[0] hasPrefix:@"/"] ? files[0] : [self.currentSession.workingDirectory stringByAppendingPathComponent:files[0]];
    NSString *path2 = [files[1] hasPrefix:@"/"] ? files[1] : [self.currentSession.workingDirectory stringByAppendingPathComponent:files[1]];
    
    NSString *content1 = [NSString stringWithContentsOfFile:path1 encoding:NSUTF8StringEncoding error:nil];
    NSString *content2 = [NSString stringWithContentsOfFile:path2 encoding:NSUTF8StringEncoding error:nil];
    
    if (!content1 || !content2) {
        return [CPCommandResult errorWithMessage:@"comm: cannot read files" code:1];
    }
    
    NSSet *set1 = [NSSet setWithArray:[content1 componentsSeparatedByString:@"\n"]];
    NSSet *set2 = [NSSet setWithArray:[content2 componentsSeparatedByString:@"\n"]];
    
    NSMutableString *output = [NSMutableString string];
    
    NSMutableSet *only1 = [set1 mutableCopy];
    [only1 minusSet:set2];
    
    NSMutableSet *only2 = [set2 mutableCopy];
    [only2 minusSet:set1];
    
    NSMutableSet *common = [set1 mutableCopy];
    [common intersectSet:set2];
    
    if (!suppress1) for (NSString *line in only1) [output appendFormat:@"%@\n", line];
    if (!suppress2) for (NSString *line in only2) [output appendFormat:@"\t%@\n", line];
    if (!suppress3) for (NSString *line in common) [output appendFormat:@"\t\t%@\n", line];
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdPatch:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"patch: not implemented in simulated environment" code:1];
}

- (CPCommandResult *)cmdSplit:(NSArray *)args {
    NSInteger lines = 1000;
    NSString *prefix = @"x";
    NSString *file = nil;
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-l"] && i + 1 < args.count) {
            lines = [args[++i] integerValue];
        } else if (![arg hasPrefix:@"-"]) {
            if (!file) file = arg;
            else prefix = arg;
        }
    }
    
    if (!file) {
        return [CPCommandResult errorWithMessage:@"split: missing operand" code:1];
    }
    
    NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    
    if (!content) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"split: %@: No such file or directory", file] code:1];
    }
    
    NSArray *allLines = [content componentsSeparatedByString:@"\n"];
    NSInteger partNum = 0;
    
    for (NSInteger i = 0; i < allLines.count; i += lines) {
        NSInteger end = MIN(i + lines, (NSInteger)allLines.count);
        NSArray *partLines = [allLines subarrayWithRange:NSMakeRange(i, end - i)];
        NSString *partContent = [partLines componentsJoinedByString:@"\n"];
        
        NSString *suffix = [NSString stringWithFormat:@"%c%c", 'a' + (char)(partNum / 26), 'a' + (char)(partNum % 26)];
        NSString *partPath = [self.currentSession.workingDirectory stringByAppendingPathComponent:[prefix stringByAppendingString:suffix]];
        
        [partContent writeToFile:partPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        partNum++;
    }
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)cmdCut:(NSArray *)args {
    NSString *delimiter = @"\t";
    NSString *fields = nil;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-d"] && i + 1 < args.count) {
            delimiter = args[++i];
        } else if ([arg isEqualToString:@"-f"] && i + 1 < args.count) {
            fields = args[++i];
        } else if (![arg hasPrefix:@"-"]) {
            [files addObject:arg];
        }
    }
    
    if (!fields) {
        return [CPCommandResult errorWithMessage:@"cut: you must specify a list of bytes, characters, or fields" code:1];
    }
    
    NSMutableSet *fieldSet = [NSMutableSet set];
    for (NSString *part in [fields componentsSeparatedByString:@","]) {
        if ([part containsString:@"-"]) {
            NSArray *range = [part componentsSeparatedByString:@"-"];
            NSInteger start = [range[0] integerValue];
            NSInteger end = range.count > 1 ? [range[1] integerValue] : start;
            for (NSInteger i = start; i <= end; i++) {
                [fieldSet addObject:@(i)];
            }
        } else {
            [fieldSet addObject:@([part integerValue])];
        }
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (!content) continue;
        
        for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
            NSArray *parts = [line componentsSeparatedByString:delimiter];
            NSMutableArray *selected = [NSMutableArray array];
            
            for (NSNumber *fieldNum in fieldSet) {
                NSInteger idx = [fieldNum integerValue] - 1;
                if (idx >= 0 && idx < parts.count) {
                    [selected addObject:parts[idx]];
                }
            }
            
            [output appendFormat:@"%@\n", [selected componentsJoinedByString:delimiter]];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdPaste:(NSArray *)args {
    NSString *delimiter = @"\t";
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-d"] && i + 1 < args.count) {
            delimiter = args[++i];
        } else if (![arg hasPrefix:@"-"]) {
            [files addObject:arg];
        }
    }
    
    NSMutableArray *fileLines = [NSMutableArray array];
    NSInteger maxLines = 0;
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        NSArray *lines = content ? [content componentsSeparatedByString:@"\n"] : @[];
        [fileLines addObject:lines];
        maxLines = MAX(maxLines, (NSInteger)lines.count);
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSInteger i = 0; i < maxLines; i++) {
        NSMutableArray *parts = [NSMutableArray array];
        for (NSArray *lines in fileLines) {
            [parts addObject:(i < lines.count ? lines[i] : @"")];
        }
        [output appendFormat:@"%@\n", [parts componentsJoinedByString:delimiter]];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdJoin:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"join: not implemented" code:1];
}

- (CPCommandResult *)cmdSort:(NSArray *)args {
    BOOL reverse = NO, numeric = NO, unique = NO, ignoreCase = NO;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg containsString:@"r"]) reverse = YES;
        if ([arg containsString:@"n"]) numeric = YES;
        if ([arg containsString:@"u"]) unique = YES;
        if ([arg containsString:@"f"]) ignoreCase = YES;
        if (![arg hasPrefix:@"-"]) [files addObject:arg];
    }
    
    NSMutableArray *allLines = [NSMutableArray array];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (content) {
            [allLines addObjectsFromArray:[content componentsSeparatedByString:@"\n"]];
        }
    }
    
    if (numeric) {
        [allLines sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            NSComparisonResult result = [@([a doubleValue]) compare:@([b doubleValue])];
            return reverse ? (NSComparisonResult)(-result) : result;
        }];
    } else if (ignoreCase) {
        [allLines sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            NSComparisonResult result = [a caseInsensitiveCompare:b];
            return reverse ? (NSComparisonResult)(-result) : result;
        }];
    } else {
        [allLines sortUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
            NSComparisonResult result = [a compare:b];
            return reverse ? (NSComparisonResult)(-result) : result;
        }];
    }
    
    if (unique) {
        NSOrderedSet *uniqueSet = [NSOrderedSet orderedSetWithArray:allLines];
        allLines = [[uniqueSet array] mutableCopy];
    }
    
    return [CPCommandResult successWithOutput:[[allLines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"]];
}

- (CPCommandResult *)cmdUniq:(NSArray *)args {
    BOOL count = NO, repeated = NO, unique = NO;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg containsString:@"c"]) count = YES;
        if ([arg containsString:@"d"]) repeated = YES;
        if ([arg containsString:@"u"]) unique = YES;
        if (![arg hasPrefix:@"-"]) [files addObject:arg];
    }
    
    NSString *content = @"";
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] ?: @"";
    }
    
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    NSMutableString *output = [NSMutableString string];
    NSMutableDictionary *counts = [NSMutableDictionary dictionary];
    NSMutableArray *order = [NSMutableArray array];
    
    NSString *prev = nil;
    for (NSString *line in lines) {
        if (![line isEqualToString:prev]) {
            [order addObject:line];
            counts[line] = @1;
        } else {
            counts[line] = @([counts[line] integerValue] + 1);
        }
        prev = line;
    }
    
    for (NSString *line in order) {
        NSInteger cnt = [counts[line] integerValue];
        if (repeated && cnt == 1) continue;
        if (unique && cnt > 1) continue;
        
        if (count) {
            [output appendFormat:@"%7ld %@\n", (long)cnt, line];
        } else {
            [output appendFormat:@"%@\n", line];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdTr:(NSArray *)args {
    if (args.count < 2) {
        return [CPCommandResult errorWithMessage:@"tr: missing operand" code:1];
    }
    
    BOOL deleteChars = NO, squeezeChars = NO;
    NSString *set1 = nil, *set2 = nil;
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-d"]) deleteChars = YES;
        else if ([arg isEqualToString:@"-s"]) squeezeChars = YES;
        else if (!set1) set1 = arg;
        else if (!set2) set2 = arg;
    }
    
    return [CPCommandResult successWithOutput:@""];
}

- (CPCommandResult *)cmdSed:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"sed: missing script" code:1];
    }
    
    NSString *script = nil;
    NSMutableArray *files = [NSMutableArray array];
    BOOL inPlace = NO;
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-e"] && i + 1 < args.count) {
            script = args[++i];
        } else if ([arg isEqualToString:@"-i"]) {
            inPlace = YES;
        } else if (![arg hasPrefix:@"-"]) {
            if (!script) script = arg;
            else [files addObject:arg];
        }
    }
    
    if (!script) {
        return [CPCommandResult errorWithMessage:@"sed: missing script" code:1];
    }
    
    NSString *pattern = nil, *replacement = nil;
    BOOL global = NO;
    
    if ([script hasPrefix:@"s"]) {
        NSString *delim = [script substringWithRange:NSMakeRange(1, 1)];
        NSArray *parts = [script componentsSeparatedByString:delim];
        if (parts.count >= 3) {
            pattern = parts[1];
            replacement = parts[2];
            if (parts.count > 3 && [parts[3] containsString:@"g"]) global = YES;
        }
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (!content) continue;
        
        if (pattern && replacement) {
            NSRegularExpressionOptions opts = 0;
            NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:opts error:nil];
            if (regex) {
                NSRange range = NSMakeRange(0, content.length);
                if (global) {
                    content = [regex stringByReplacingMatchesInString:content options:0 range:range withTemplate:replacement];
                } else {
                    NSTextCheckingResult *match = [regex firstMatchInString:content options:0 range:range];
                    if (match) {
                        content = [content stringByReplacingCharactersInRange:match.range withString:replacement];
                    }
                }
            }
        }
        
        [output appendString:content];
        if (![content hasSuffix:@"\n"]) [output appendString:@"\n"];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdAwk:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"awk: complex scripting not implemented, use native shell" code:1];
}

- (CPCommandResult *)cmdGrep:(NSArray *)args {
    BOOL ignoreCase = NO, invertMatch = NO, countOnly = NO, lineNumbers = NO, recursive = NO, onlyMatching = NO;
    NSString *pattern = nil;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSString *arg in args) {
        if ([arg hasPrefix:@"-"]) {
            if ([arg containsString:@"i"]) ignoreCase = YES;
            if ([arg containsString:@"v"]) invertMatch = YES;
            if ([arg containsString:@"c"]) countOnly = YES;
            if ([arg containsString:@"n"]) lineNumbers = YES;
            if ([arg containsString:@"r"] || [arg containsString:@"R"]) recursive = YES;
            if ([arg containsString:@"o"]) onlyMatching = YES;
        } else if (!pattern) {
            pattern = arg;
        } else {
            [files addObject:arg];
        }
    }
    
    if (!pattern) {
        return [CPCommandResult errorWithMessage:@"grep: missing pattern" code:2];
    }
    
    if (files.count == 0) {
        return [CPCommandResult errorWithMessage:@"grep: missing file operand" code:2];
    }
    
    NSRegularExpressionOptions opts = ignoreCase ? NSRegularExpressionCaseInsensitive : 0;
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:opts error:nil];
    
    NSMutableString *output = [NSMutableString string];
    NSInteger matchCount = 0;
    BOOL multiFile = files.count > 1;
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (!content) continue;
        
        NSArray *lines = [content componentsSeparatedByString:@"\n"];
        NSInteger lineNum = 0;
        
        for (NSString *line in lines) {
            lineNum++;
            BOOL hasMatch = [regex numberOfMatchesInString:line options:0 range:NSMakeRange(0, line.length)] > 0;
            
            if (invertMatch) hasMatch = !hasMatch;
            
            if (hasMatch) {
                matchCount++;
                if (!countOnly) {
                    NSMutableString *resultLine = [NSMutableString string];
                    if (multiFile) [resultLine appendFormat:@"%@:", file];
                    if (lineNumbers) [resultLine appendFormat:@"%ld:", (long)lineNum];
                    [resultLine appendFormat:@"%@\n", line];
                    [output appendString:resultLine];
                }
            }
        }
    }
    
    if (countOnly) {
        return [CPCommandResult successWithOutput:[NSString stringWithFormat:@"%ld\n", (long)matchCount]];
    }
    
    CPCommandResult *result = [CPCommandResult successWithOutput:output];
    result.exitCode = matchCount > 0 ? 0 : 1;
    result.success = matchCount > 0;
    return result;
}

- (CPCommandResult *)cmdEgrep:(NSArray *)args {
    return [self cmdGrep:args];
}

- (CPCommandResult *)cmdFgrep:(NSArray *)args {
    return [self cmdGrep:args];
}

- (CPCommandResult *)cmdFindstr:(NSArray *)args {
    return [self cmdGrep:args];
}

- (CPCommandResult *)cmdXargs:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"xargs: requires stdin, use native shell" code:1];
}

- (CPCommandResult *)cmdTee:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"tee: requires stdin, use native shell" code:1];
}

#pragma mark - Checksums

- (CPCommandResult *)cmdMd5sum:(NSArray *)args {
    return [self checksumWithAlgorithm:@"md5" args:args];
}

- (CPCommandResult *)cmdSha1sum:(NSArray *)args {
    return [self checksumWithAlgorithm:@"sha1" args:args];
}

- (CPCommandResult *)cmdSha256sum:(NSArray *)args {
    return [self checksumWithAlgorithm:@"sha256" args:args];
}

- (CPCommandResult *)cmdShasum:(NSArray *)args {
    return [self cmdSha1sum:args];
}

- (CPCommandResult *)cmdCksum:(NSArray *)args {
    return [self cmdMd5sum:args];
}

- (CPCommandResult *)cmdSum:(NSArray *)args {
    return [self cmdMd5sum:args];
}

- (CPCommandResult *)checksumWithAlgorithm:(NSString *)algorithm args:(NSArray *)args {
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *file in args) {
        if ([file hasPrefix:@"-"]) continue;
        
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSData *data = [NSData dataWithContentsOfFile:path];
        
        if (!data) {
            return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"%@sum: %@: No such file or directory", algorithm, file] code:1];
        }
        
        NSString *hash = [self computeHash:data algorithm:algorithm];
        [output appendFormat:@"%@  %@\n", hash, file];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (NSString *)computeHash:(NSData *)data algorithm:(NSString *)algorithm {
    unsigned char digest[64];
    NSUInteger length = 0;
    
    if ([algorithm isEqualToString:@"md5"]) {
        CC_MD5(data.bytes, (CC_LONG)data.length, digest);
        length = CC_MD5_DIGEST_LENGTH;
    } else if ([algorithm isEqualToString:@"sha1"]) {
        CC_SHA1(data.bytes, (CC_LONG)data.length, digest);
        length = CC_SHA1_DIGEST_LENGTH;
    } else if ([algorithm isEqualToString:@"sha256"]) {
        CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
        length = CC_SHA256_DIGEST_LENGTH;
    }
    
    NSMutableString *hash = [NSMutableString stringWithCapacity:length * 2];
    for (NSUInteger i = 0; i < length; i++) {
        [hash appendFormat:@"%02x", digest[i]];
    }
    return hash;
}

- (CPCommandResult *)cmdBase64:(NSArray *)args {
    BOOL decode = NO;
    NSString *file = nil;
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-d"] || [arg isEqualToString:@"--decode"]) decode = YES;
        else if (![arg hasPrefix:@"-"]) file = arg;
    }
    
    if (!file) {
        return [CPCommandResult errorWithMessage:@"base64: missing file operand" code:1];
    }
    
    NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
    
    if (decode) {
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        NSData *decoded = [[NSData alloc] initWithBase64EncodedString:content options:NSDataBase64DecodingIgnoreUnknownCharacters];
        NSString *output = [[NSString alloc] initWithData:decoded encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output ?: @""];
    } else {
        NSData *data = [NSData dataWithContentsOfFile:path];
        NSString *encoded = [data base64EncodedStringWithOptions:NSDataBase64Encoding76CharacterLineLength];
        return [CPCommandResult successWithOutput:[encoded stringByAppendingString:@"\n"]];
    }
}

- (CPCommandResult *)cmdXxd:(NSArray *)args {
    BOOL reverse = NO;
    NSString *file = nil;
    
    for (NSString *arg in args) {
        if ([arg isEqualToString:@"-r"]) reverse = YES;
        else if (![arg hasPrefix:@"-"]) file = arg;
    }
    
    if (!file) {
        return [CPCommandResult errorWithMessage:@"xxd: missing file operand" code:1];
    }
    
    NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
    NSData *data = [NSData dataWithContentsOfFile:path];
    
    if (!data) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"xxd: %@: No such file or directory", file] code:1];
    }
    
    NSMutableString *output = [NSMutableString string];
    const uint8_t *bytes = (const uint8_t *)data.bytes;
    
    for (NSUInteger i = 0; i < data.length; i += 16) {
        [output appendFormat:@"%08lx: ", (unsigned long)i];
        
        for (NSUInteger j = 0; j < 16; j++) {
            if (i + j < data.length) {
                [output appendFormat:@"%02x", bytes[i + j]];
            } else {
                [output appendString:@"  "];
            }
            if (j % 2 == 1) [output appendString:@" "];
        }
        
        [output appendString:@" "];
        for (NSUInteger j = 0; j < 16 && i + j < data.length; j++) {
            uint8_t c = bytes[i + j];
            [output appendFormat:@"%c", (c >= 32 && c < 127) ? c : '.'];
        }
        [output appendString:@"\n"];
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdOd:(NSArray *)args {
    return [self cmdXxd:args];
}

- (CPCommandResult *)cmdHexdump:(NSArray *)args {
    return [self cmdXxd:args];
}

- (CPCommandResult *)cmdStrings:(NSArray *)args {
    NSInteger minLength = 4;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-n"] && i + 1 < args.count) {
            minLength = [args[++i] integerValue];
        } else if (![arg hasPrefix:@"-"]) {
            [files addObject:arg];
        }
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSData *data = [NSData dataWithContentsOfFile:path];
        
        if (!data) continue;
        
        const uint8_t *bytes = (const uint8_t *)data.bytes;
        NSMutableString *current = [NSMutableString string];
        
        for (NSUInteger i = 0; i < data.length; i++) {
            uint8_t c = bytes[i];
            if (c >= 32 && c < 127) {
                [current appendFormat:@"%c", c];
            } else {
                if (current.length >= minLength) {
                    [output appendFormat:@"%@\n", current];
                }
                current = [NSMutableString string];
            }
        }
        
        if (current.length >= minLength) {
            [output appendFormat:@"%@\n", current];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

#pragma mark - Text Formatting

- (CPCommandResult *)cmdNl:(NSArray *)args {
    NSMutableArray *files = [NSMutableArray array];
    for (NSString *arg in args) {
        if (![arg hasPrefix:@"-"]) [files addObject:arg];
    }
    
    NSMutableString *output = [NSMutableString string];
    NSInteger lineNum = 1;
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (!content) continue;
        
        for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
            [output appendFormat:@"%6ld\t%@\n", (long)lineNum++, line];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdFmt:(NSArray *)args {
    NSInteger width = 75;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-w"] && i + 1 < args.count) {
            width = [args[++i] integerValue];
        } else if (![arg hasPrefix:@"-"]) {
            [files addObject:arg];
        }
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (!content) continue;
        
        NSArray *words = [content componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSMutableString *line = [NSMutableString string];
        
        for (NSString *word in words) {
            if (word.length == 0) continue;
            
            if (line.length + word.length + 1 > width) {
                [output appendFormat:@"%@\n", line];
                line = [NSMutableString stringWithString:word];
            } else {
                if (line.length > 0) [line appendString:@" "];
                [line appendString:word];
            }
        }
        
        if (line.length > 0) {
            [output appendFormat:@"%@\n", line];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdFold:(NSArray *)args {
    NSInteger width = 80;
    NSMutableArray *files = [NSMutableArray array];
    
    for (NSInteger i = 0; i < args.count; i++) {
        NSString *arg = args[i];
        if ([arg isEqualToString:@"-w"] && i + 1 < args.count) {
            width = [args[++i] integerValue];
        } else if (![arg hasPrefix:@"-"]) {
            [files addObject:arg];
        }
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (!content) continue;
        
        for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
            for (NSInteger i = 0; i < line.length; i += width) {
                NSInteger len = MIN(width, (NSInteger)line.length - i);
                [output appendFormat:@"%@\n", [line substringWithRange:NSMakeRange(i, len)]];
            }
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdPr:(NSArray *)args {
    return [self cmdCat:args];
}

- (CPCommandResult *)cmdColumn:(NSArray *)args {
    return [self cmdCat:args];
}

- (CPCommandResult *)cmdExpand:(NSArray *)args {
    NSMutableArray *files = [NSMutableArray array];
    for (NSString *arg in args) {
        if (![arg hasPrefix:@"-"]) [files addObject:arg];
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (content) {
            [output appendString:[content stringByReplacingOccurrencesOfString:@"\t" withString:@"        "]];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdUnexpand:(NSArray *)args {
    NSMutableArray *files = [NSMutableArray array];
    for (NSString *arg in args) {
        if (![arg hasPrefix:@"-"]) [files addObject:arg];
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (content) {
            [output appendString:[content stringByReplacingOccurrencesOfString:@"        " withString:@"\t"]];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdRev:(NSArray *)args {
    NSMutableArray *files = [NSMutableArray array];
    for (NSString *arg in args) {
        if (![arg hasPrefix:@"-"]) [files addObject:arg];
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (!content) continue;
        
        for (NSString *line in [content componentsSeparatedByString:@"\n"]) {
            NSMutableString *reversed = [NSMutableString string];
            for (NSInteger i = line.length - 1; i >= 0; i--) {
                [reversed appendFormat:@"%C", [line characterAtIndex:i]];
            }
            [output appendFormat:@"%@\n", reversed];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdTac:(NSArray *)args {
    NSMutableArray *files = [NSMutableArray array];
    for (NSString *arg in args) {
        if (![arg hasPrefix:@"-"]) [files addObject:arg];
    }
    
    NSMutableString *output = [NSMutableString string];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (!content) continue;
        
        NSArray *lines = [content componentsSeparatedByString:@"\n"];
        for (NSInteger i = lines.count - 1; i >= 0; i--) {
            [output appendFormat:@"%@\n", lines[i]];
        }
    }
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdShuf:(NSArray *)args {
    NSMutableArray *files = [NSMutableArray array];
    for (NSString *arg in args) {
        if (![arg hasPrefix:@"-"]) [files addObject:arg];
    }
    
    NSMutableArray *allLines = [NSMutableArray array];
    
    for (NSString *file in files) {
        NSString *path = [file hasPrefix:@"/"] ? file : [self.currentSession.workingDirectory stringByAppendingPathComponent:file];
        NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        
        if (content) {
            [allLines addObjectsFromArray:[content componentsSeparatedByString:@"\n"]];
        }
    }
    
    for (NSInteger i = allLines.count - 1; i > 0; i--) {
        NSInteger j = arc4random_uniform((uint32_t)(i + 1));
        [allLines exchangeObjectAtIndex:i withObjectAtIndex:j];
    }
    
    return [CPCommandResult successWithOutput:[[allLines componentsJoinedByString:@"\n"] stringByAppendingString:@"\n"]];
}

@end
