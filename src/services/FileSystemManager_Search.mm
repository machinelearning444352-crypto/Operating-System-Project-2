#import "FileSystemManager.h"

@interface FileSystemManager (SearchPrivate)
- (NSString *)resolveStoragePathForVirtualPath:(NSString *)virtualPath;
@end

@implementation FileSystemManager (Search)

- (NSArray<VFSFile *> *)searchFilesWithQuery:(NSString *)query inPath:(NSString *)path {
    NSString *storage = [self resolveStoragePathForVirtualPath:path];
    NSMutableArray<VFSFile *> *results = [NSMutableArray array];
    NSArray<VFSFile *> *files = [self filesInDirectory:path];
    for (VFSFile *file in files) {
        if (file.name && [file.name.lowercaseString containsString:query.lowercaseString]) {
            [results addObject:file];
        }
    }
    return results;
}

- (NSArray<VFSFile *> *)searchFilesWithPredicate:(NSPredicate *)predicate inPath:(NSString *)path {
    NSArray<VFSFile *> *files = [self filesInDirectory:path];
    return [files filteredArrayUsingPredicate:predicate];
}

- (NSArray<VFSFile *> *)recentFiles:(NSUInteger)count {
    // Placeholder: return empty array
    return @[];
}

- (NSArray<VFSFile *> *)filesWithExtension:(NSString *)extension inPath:(NSString *)path {
    NSArray<VFSFile *> *files = [self filesInDirectory:path];
    NSString *ext = extension.lowercaseString;
    return [files filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(VFSFile *file, NSDictionary *bindings) {
        return [file.fileExtension.lowercaseString isEqualToString:ext];
    }]];
}

- (NSArray<VFSFile *> *)filesOfCategory:(VFSFileCategory)category inPath:(NSString *)path {
    NSArray<VFSFile *> *files = [self filesInDirectory:path];
    return [files filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(VFSFile *file, NSDictionary *bindings) {
        return file.category == category;
    }]];
}

@end
