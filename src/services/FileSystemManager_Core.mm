#import "FileSystemManager.h"

@interface FileSystemManager ()
@property (nonatomic, strong, readwrite) NSString *virtualRootPath;
@property (nonatomic, strong, readwrite) NSString *storagePath;
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString *, VFSFile *> *fileIndex;
@property (nonatomic, strong, readwrite) NSMutableArray<VFSTransferOperation *> *activeTransfers;
@property (nonatomic, strong, readwrite) NSMutableArray<VFSExecutionContext *> *runningProcesses;
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString *, NSArray *> *virtualFileSystem;
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString *, NSDictionary *> *fileTypeHandlers;
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString *, NSString *> *mimeTypeMap;
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString *, NSString *> *interpreterMap;
@end

@implementation FileSystemManager

+ (instancetype)sharedInstance {
    static FileSystemManager *manager;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[self alloc] init];
    });
    return manager;
}

- (instancetype)init {
    if (self = [super init]) {
        _virtualRootPath = @"/";
        _storagePath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"VFSStorage"];
        _fileIndex = [NSMutableDictionary dictionary];
        _activeTransfers = [NSMutableArray array];
        _runningProcesses = [NSMutableArray array];
        _virtualFileSystem = [NSMutableDictionary dictionary];
        _fileTypeHandlers = [NSMutableDictionary dictionary];
        _mimeTypeMap = [NSMutableDictionary dictionary];
        _interpreterMap = [NSMutableDictionary dictionary];
        [self createDirectoryAtPath:_storagePath error:nil];
    }
    return self;
}

#pragma mark - Helpers

- (NSString *)resolveStoragePathForVirtualPath:(NSString *)virtualPath {
    if (!virtualPath.length) return self.storagePath;
    NSString *clean = [virtualPath stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]];
    return [self.storagePath stringByAppendingPathComponent:clean];
}

#pragma mark - File System Operations (basic)

- (VFSFile *)fileAtPath:(NSString *)path {
    NSString *storage = [self resolveStoragePathForVirtualPath:path];
    return [VFSFile fileWithPath:storage];
}

- (NSArray<VFSFile *> *)filesInDirectory:(NSString *)path {
    NSString *storage = [self resolveStoragePathForVirtualPath:path];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray<NSString *> *contents = [fm contentsOfDirectoryAtPath:storage error:nil];
    NSMutableArray<VFSFile *> *result = [NSMutableArray array];
    for (NSString *name in contents) {
        NSString *childPath = [storage stringByAppendingPathComponent:name];
        VFSFile *file = [VFSFile fileWithPath:childPath];
        file.virtualPath = [[path stringByAppendingPathComponent:name] stringByStandardizingPath];
        [result addObject:file];
    }
    return result;
}

- (BOOL)fileExistsAtPath:(NSString *)path {
    NSString *storage = [self resolveStoragePathForVirtualPath:path];
    return [[NSFileManager defaultManager] fileExistsAtPath:storage];
}

- (BOOL)isDirectoryAtPath:(NSString *)path {
    NSString *storage = [self resolveStoragePathForVirtualPath:path];
    BOOL isDir = NO;
    [[NSFileManager defaultManager] fileExistsAtPath:storage isDirectory:&isDir];
    return isDir;
}

- (BOOL)createDirectoryAtPath:(NSString *)path error:(NSError **)error {
    return [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error];
}

- (BOOL)deleteFileAtPath:(NSString *)path error:(NSError **)error {
    NSString *storage = [self resolveStoragePathForVirtualPath:path];
    return [[NSFileManager defaultManager] removeItemAtPath:storage error:error];
}

- (BOOL)moveFileAtPath:(NSString *)sourcePath toPath:(NSString *)destPath error:(NSError **)error {
    NSString *src = [self resolveStoragePathForVirtualPath:sourcePath];
    NSString *dst = [self resolveStoragePathForVirtualPath:destPath];
    return [[NSFileManager defaultManager] moveItemAtPath:src toPath:dst error:error];
}

- (BOOL)copyFileAtPath:(NSString *)sourcePath toPath:(NSString *)destPath error:(NSError **)error {
    NSString *src = [self resolveStoragePathForVirtualPath:sourcePath];
    NSString *dst = [self resolveStoragePathForVirtualPath:destPath];
    return [[NSFileManager defaultManager] copyItemAtPath:src toPath:dst error:error];
}

- (BOOL)renameFileAtPath:(NSString *)path toName:(NSString *)newName error:(NSError **)error {
    NSString *parent = [path stringByDeletingLastPathComponent];
    NSString *destVirtual = [parent stringByAppendingPathComponent:newName];
    return [self moveFileAtPath:path toPath:destVirtual error:error];
}

- (NSString *)uniqueNameForFile:(NSString *)name inDirectory:(NSString *)directory {
    NSString *base = [name stringByDeletingPathExtension];
    NSString *ext = name.pathExtension.length ? [@"." stringByAppendingString:name.pathExtension] : @"";
    NSString *candidate = name;
    NSUInteger counter = 1;
    while ([self fileExistsAtPath:[directory stringByAppendingPathComponent:candidate]]) {
        candidate = [NSString stringWithFormat:@"%@ (%lu)%@", base, (unsigned long)counter, ext];
        counter++;
    }
    return candidate;
}

#pragma mark - Persistence (stubs)

- (void)saveFileSystem { /* TODO: implement persistence */ }
- (void)loadFileSystem { /* TODO: implement persistence */ }
- (void)rebuildIndex { /* TODO: implement indexing */ }
- (NSUInteger)totalStorageUsed { return 0; }
- (NSUInteger)fileCount { return self.fileIndex.count; }

@end
