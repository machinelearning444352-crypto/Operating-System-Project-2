#import "FileSystemManager.h"

#pragma mark - VFSFile Implementation

@implementation VFSFile

+ (instancetype)fileWithPath:(NSString *)path {
    VFSFile *file = [[VFSFile alloc] init];
    file.originalPath = path;
    file.storagePath = path;
    file.virtualPath = path.lastPathComponent;
    file.name = path.lastPathComponent;

    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL isDir = NO;
    if ([fm fileExistsAtPath:path isDirectory:&isDir]) {
        file.isDirectory = isDir;
        NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
        file.size = [attrs[NSFileSize] unsignedIntegerValue];
        file.createdDate = attrs[NSFileCreationDate];
        file.modifiedDate = attrs[NSFileModificationDate];
        file.permissions = VFSFilePermissionRead | VFSFilePermissionWrite;
        file.fileExtension = path.pathExtension.lowercaseString;
    }
    return file;
}

+ (instancetype)fileWithDictionary:(NSDictionary *)dict {
    VFSFile *file = [[VFSFile alloc] init];
    file.name = dict[@"name"];
    file.virtualPath = dict[@"virtualPath"];
    file.storagePath = dict[@"storagePath"];
    file.originalPath = dict[@"originalPath"];
    file.fileType = (VFSFileType)[dict[@"fileType"] integerValue];
    file.category = (VFSFileCategory)[dict[@"category"] integerValue];
    file.platform = (VFSPlatformType)[dict[@"platform"] integerValue];
    file.permissions = [dict[@"permissions"] unsignedIntegerValue];
    file.isDirectory = [dict[@"isDirectory"] boolValue];
    file.isSymlink = [dict[@"isSymlink"] boolValue];
    file.isHidden = [dict[@"isHidden"] boolValue];
    file.isReadOnly = [dict[@"isReadOnly"] boolValue];
    file.isExecutable = [dict[@"isExecutable"] boolValue];
    file.isSystem = [dict[@"isSystem"] boolValue];
    file.size = [dict[@"size"] unsignedIntegerValue];
    file.createdDate = dict[@"createdDate"];
    file.modifiedDate = dict[@"modifiedDate"];
    file.accessedDate = dict[@"accessedDate"];
    file.mimeType = dict[@"mimeType"];
    file.fileExtension = dict[@"fileExtension"];
    file.fileUTI = dict[@"fileUTI"];
    file.checksum = dict[@"checksum"];
    file.owner = dict[@"owner"];
    file.group = dict[@"group"];
    file.metadata = dict[@"metadata"];
    file.extendedAttributes = dict[@"extendedAttributes"];
    file.symlinkTarget = dict[@"symlinkTarget"];
    return file;
}

- (NSDictionary *)toDictionary {
    return @{ 
        @"name": self.name ?: @"", 
        @"virtualPath": self.virtualPath ?: @"", 
        @"storagePath": self.storagePath ?: @"", 
        @"originalPath": self.originalPath ?: @"", 
        @"fileType": @(self.fileType), 
        @"category": @(self.category), 
        @"platform": @(self.platform), 
        @"permissions": @(self.permissions), 
        @"isDirectory": @(self.isDirectory), 
        @"isSymlink": @(self.isSymlink), 
        @"isHidden": @(self.isHidden), 
        @"isReadOnly": @(self.isReadOnly), 
        @"isExecutable": @(self.isExecutable), 
        @"isSystem": @(self.isSystem), 
        @"size": @(self.size), 
        @"createdDate": self.createdDate ?: [NSNull null], 
        @"modifiedDate": self.modifiedDate ?: [NSNull null], 
        @"accessedDate": self.accessedDate ?: [NSNull null], 
        @"mimeType": self.mimeType ?: @"", 
        @"fileExtension": self.fileExtension ?: @"", 
        @"fileUTI": self.fileUTI ?: @"", 
        @"checksum": self.checksum ?: @"", 
        @"owner": self.owner ?: @"", 
        @"group": self.group ?: @"", 
        @"metadata": self.metadata ?: @{}, 
        @"extendedAttributes": self.extendedAttributes ?: @{}, 
        @"symlinkTarget": self.symlinkTarget ?: @"" 
    };
}

- (NSString *)formattedSize { return [NSString stringWithFormat:@"%lu bytes", (unsigned long)self.size]; }
- (NSString *)formattedDate { return self.modifiedDate.description ?: @""; }
- (NSString *)iconEmoji { return self.isDirectory ? @"📁" : @"📄"; }
- (BOOL)isRunnable { return self.isExecutable || self.category == VFSFileCategoryExecutable; }
- (BOOL)isViewable { return !self.isDirectory; }
- (BOOL)isEditable { return !self.isReadOnly; }

@end

#pragma mark - VFSTransferOperation Implementation

@implementation VFSTransferOperation

- (instancetype)init {
    if (self = [super init]) {
        _operationID = NSUUID.UUID.UUIDString;
        _status = VFSTransferStatusPending;
        _progress = 0.0;
        _bytesPerSecond = 0;
    }
    return self;
}

- (void)start { self.status = VFSTransferStatusTransferring; self.startTime = [NSDate date]; [self.delegate transferDidStart:self]; }
- (void)pause { self.isPaused = YES; self.status = VFSTransferStatusPaused; }
- (void)resume { self.isPaused = NO; self.status = VFSTransferStatusTransferring; }
- (void)cancel { self.isCancelled = YES; self.status = VFSTransferStatusCancelled; [self.delegate transferDidCancel:self]; }
- (NSTimeInterval)elapsedTime { return self.startTime ? [[NSDate date] timeIntervalSinceDate:self.startTime] : 0; }
- (NSTimeInterval)estimatedTimeRemaining { if (self.bytesPerSecond == 0) return 0; NSUInteger remaining = self.totalBytes - self.transferredBytes; return (NSTimeInterval)remaining / (double)self.bytesPerSecond; }
- (NSString *)formattedSpeed { if (self.bytesPerSecond == 0) return @"0 B/s"; return [NSString stringWithFormat:@"%lu B/s", (unsigned long)self.bytesPerSecond]; }
- (NSString *)formattedProgress { return [NSString stringWithFormat:@"%.2f%%", self.progress * 100.0]; }

@end

#pragma mark - VFSExecutionContext Implementation

@implementation VFSExecutionContext

- (instancetype)init {
    if (self = [super init]) {
        _contextID = NSUUID.UUID.UUIDString;
        _arguments = @[];
        _environment = @{};
        _standardOutput = [NSMutableString string];
        _standardError = [NSMutableString string];
    }
    return self;
}

- (void)execute {
    self.isRunning = YES;
    self.startTime = [NSDate date];
    [self.delegate executionDidStart:self];
    // Placeholder: real execution implemented in execution module
    self.isRunning = NO;
    self.result = VFSExecutionResultSuccess;
    self.endTime = [NSDate date];
    [self.delegate executionDidComplete:self withResult:self.result];
}

- (void)terminate {
    if (self.task && self.isRunning) {
        [self.task terminate];
    }
    self.isRunning = NO;
}

- (void)sendInput:(NSString *)input {
    if (self.inputPipe) {
        [[self.inputPipe fileHandleForWriting] writeData:[input dataUsingEncoding:NSUTF8StringEncoding]];
    }
}

- (NSTimeInterval)runningTime {
    if (!self.startTime) return 0;
    return self.endTime ? [self.endTime timeIntervalSinceDate:self.startTime] : [[NSDate date] timeIntervalSinceDate:self.startTime];
}

@end
