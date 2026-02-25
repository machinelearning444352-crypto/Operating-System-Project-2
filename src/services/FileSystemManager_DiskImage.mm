#import "FileSystemManager.h"

@interface FileSystemManager (DiskImagePrivate)
- (NSString *)resolveStoragePathForVirtualPath:(NSString *)virtualPath;
@end

@implementation FileSystemManager (DiskImage)

- (BOOL)mountDMGAtPath:(NSString *)dmgPath error:(NSError **)error {
    // Placeholder: use hdiutil NSTask
    return YES;
}

- (BOOL)unmountDMGAtPath:(NSString *)dmgPath error:(NSError **)error {
    // Placeholder: use hdiutil NSTask
    return YES;
}

- (BOOL)extractDMGAtPath:(NSString *)dmgPath toPath:(NSString *)destPath error:(NSError **)error {
    // Placeholder: mount then copy
    return YES;
}

@end
