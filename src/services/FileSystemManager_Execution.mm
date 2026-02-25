#import "FileSystemManager.h"

@interface FileSystemManager (ExecutionPrivate)
- (NSString *)resolveStoragePathForVirtualPath:(NSString *)virtualPath;
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString *, NSString *> *interpreterMap;
@end

@implementation FileSystemManager (Execution)

- (NSString *)interpreterForFileType:(VFSFileType)fileType {
    switch (fileType) {
        case VFSFileTypeShellScript: return @"/bin/bash";
        case VFSFileTypePython: return @"python3";
        case VFSFileTypeRuby: return @"ruby";
        case VFSFileTypePerl: return @"perl";
        case VFSFileTypePHP: return @"php";
        default: return nil;
    }
}

- (VFSPlatformType)platformForFileAtPath:(NSString *)path {
    NSString *ext = path.pathExtension.lowercaseString;
    if ([ext isEqualToString:@"exe"] || [ext isEqualToString:@"msi"]) return VFSPlatformWindows;
    if ([ext isEqualToString:@"deb"] || [ext isEqualToString:@"rpm"]) return VFSPlatformLinux;
    if ([ext isEqualToString:@"app"] || [ext isEqualToString:@"pkg"]) return VFSPlatformMacOS;
    return VFSPlatformUniversal;
}

- (BOOL)canExecuteFileAtPath:(NSString *)path {
    NSString *storage = [self resolveStoragePathForVirtualPath:path];
    return [[NSFileManager defaultManager] isExecutableFileAtPath:storage];
}

- (VFSExecutionContext *)executeFileAtPath:(NSString *)path withArguments:(NSArray<NSString *> *)arguments delegate:(id<VFSExecutionDelegate>)delegate {
    VFSExecutionContext *ctx = [[VFSExecutionContext alloc] init];
    ctx.file = [self fileAtPath:path];
    ctx.command = [self resolveStoragePathForVirtualPath:path];
    ctx.arguments = arguments ?: @[];
    ctx.delegate = delegate;
    [ctx execute];
    return ctx;
}

- (VFSExecutionContext *)executeScript:(NSString *)script withLanguage:(NSString *)language delegate:(id<VFSExecutionDelegate>)delegate {
    NSString *tempDir = NSTemporaryDirectory();
    NSString *ext = language.lowercaseString;
    NSString *fileName = [NSString stringWithFormat:@"vfs_script_%@.%@", NSUUID.UUID.UUIDString, ext];
    NSString *tempPath = [tempDir stringByAppendingPathComponent:fileName];
    [script writeToFile:tempPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    VFSExecutionContext *ctx = [[VFSExecutionContext alloc] init];
    ctx.command = tempPath;
    ctx.arguments = @[];
    ctx.delegate = delegate;
    [ctx execute];
    return ctx;
}

@end
