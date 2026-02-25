#import "FileSystemManager.h"

@interface FileSystemManager (PreviewPrivate)
- (NSString *)resolveStoragePathForVirtualPath:(NSString *)virtualPath;
@end

@implementation FileSystemManager (Preview)

- (NSImage *)thumbnailForFileAtPath:(NSString *)path size:(NSSize)size {
    NSString *storage = [self resolveStoragePathForVirtualPath:path];
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:storage];
    if (!image) return nil;
    NSImage *thumbnail = [[NSImage alloc] initWithSize:size];
    [thumbnail lockFocus];
    [image drawInRect:NSMakeRect(0, 0, size.width, size.height) fromRect:NSZeroRect operation:NSCompositingOperationCopy fraction:1.0];
    [thumbnail unlockFocus];
    return thumbnail;
}

- (NSData *)previewDataForFileAtPath:(NSString *)path {
    NSString *storage = [self resolveStoragePathForVirtualPath:path];
    return [NSData dataWithContentsOfFile:storage];
}

- (NSString *)textPreviewForFileAtPath:(NSString *)path maxLength:(NSUInteger)maxLength {
    NSString *storage = [self resolveStoragePathForVirtualPath:path];
    NSError *error;
    NSString *content = [NSString stringWithContentsOfFile:storage encoding:NSUTF8StringEncoding error:&error];
    if (!content) return nil;
    if (content.length <= maxLength) return content;
    return [content substringToIndex:maxLength];
}

@end
