#import "FileSystemManager.h"
#import <CommonCrypto/CommonDigest.h>

@interface FileSystemManager (MetadataPrivate)
- (NSString *)resolveStoragePathForVirtualPath:(NSString *)virtualPath;
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString *, NSDictionary *> *fileTypeHandlers;
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString *, NSString *> *mimeTypeMap;
@end

@implementation FileSystemManager (Metadata)

- (NSDictionary *)metadataForFileAtPath:(NSString *)path {
    NSString *storage = [self resolveStoragePathForVirtualPath:path];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:storage error:nil];
    NSMutableDictionary *meta = [attrs mutableCopy];
    meta[@"virtualPath"] = path;
    meta[@"storagePath"] = storage;
    return meta;
}

- (BOOL)setMetadata:(NSDictionary *)metadata forFileAtPath:(NSString *)path error:(NSError **)error {
    // Placeholder: extended attributes not implemented
    return YES;
}

- (NSString *)checksumForFileAtPath:(NSString *)path algorithm:(NSString *)algorithm {
    NSString *storage = [self resolveStoragePathForVirtualPath:path];
    NSData *data = [NSData dataWithContentsOfFile:storage];
    if (!data) return nil;
    if ([algorithm.lowercaseString isEqualToString:@"md5"]) {
        unsigned char digest[CC_MD5_DIGEST_LENGTH];
        CC_MD5(data.bytes, (CC_LONG)data.length, digest);
        NSMutableString *hash = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
        for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
            [hash appendFormat:@"%02x", digest[i]];
        }
        return hash;
    }
    return nil;
}

- (NSDictionary *)extendedAttributesForFileAtPath:(NSString *)path {
    NSString *storage = [self resolveStoragePathForVirtualPath:path];
    return @{};
}

- (BOOL)setExtendedAttribute:(NSString *)name value:(NSData *)value forFileAtPath:(NSString *)path error:(NSError **)error {
    // Placeholder: setxattr not implemented
    return YES;
}

@end
