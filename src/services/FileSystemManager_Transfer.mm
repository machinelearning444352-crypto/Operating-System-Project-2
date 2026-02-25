#import "FileSystemManager.h"

@interface FileSystemManager (TransferPrivate)
- (NSString *)resolveStoragePathForVirtualPath:(NSString *)virtualPath;
@end

@implementation FileSystemManager (Transfer)

- (VFSTransferOperation *)uploadFileFromURL:(NSURL *)sourceURL toVirtualPath:(NSString *)destPath delegate:(id<VFSTransferDelegate>)delegate {
    NSData *data = [NSData dataWithContentsOfURL:sourceURL];
    if (!data) return nil;
    return [self uploadData:data withName:sourceURL.lastPathComponent toVirtualPath:destPath delegate:delegate];
}

- (VFSTransferOperation *)uploadFilesFromURLs:(NSArray<NSURL *> *)sourceURLs toVirtualPath:(NSString *)destPath delegate:(id<VFSTransferDelegate>)delegate {
    VFSTransferOperation *op = [[VFSTransferOperation alloc] init];
    op.isUpload = YES; op.delegate = delegate; op.status = VFSTransferStatusPreparing;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSUInteger total = 0; for (NSURL *url in sourceURLs) total += [[[NSFileManager defaultManager] attributesOfItemAtPath:url.path error:nil][NSFileSize] unsignedIntegerValue];
        op.totalBytes = total; op.status = VFSTransferStatusTransferring; [delegate transferDidStart:op];
        for (NSURL *url in sourceURLs) {
            NSData *data = [NSData dataWithContentsOfURL:url];
            if (!data) { op.status = VFSTransferStatusFailed; op.error = [NSError errorWithDomain:@"VFSUpload" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"Read failed"}]; [delegate transfer:op didFailWithError:op.error]; return; }
            [self uploadData:data withName:url.lastPathComponent toVirtualPath:destPath delegate:nil];
            op.transferredBytes += data.length;
            op.progress = (double)op.transferredBytes / (double)op.totalBytes;
            [delegate transfer:op didUpdateProgress:op.progress];
        }
        op.status = VFSTransferStatusCompleted; op.endTime = [NSDate date]; [delegate transferDidComplete:op];
    });
    [self.activeTransfers addObject:op];
    return op;
}

- (VFSTransferOperation *)uploadData:(NSData *)data withName:(NSString *)name toVirtualPath:(NSString *)destPath delegate:(id<VFSTransferDelegate>)delegate {
    VFSTransferOperation *op = [[VFSTransferOperation alloc] init];
    op.isUpload = YES; op.delegate = delegate; op.totalBytes = data.length;
    NSString *directory = [self resolveStoragePathForVirtualPath:destPath];
    [[NSFileManager defaultManager] createDirectoryAtPath:directory withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *dest = [directory stringByAppendingPathComponent:name];
    op.status = VFSTransferStatusTransferring; [delegate transferDidStart:op];
    BOOL ok = [data writeToFile:dest atomically:YES];
    if (!ok) {
        op.status = VFSTransferStatusFailed;
        op.error = [NSError errorWithDomain:@"VFSUpload" code:-2 userInfo:@{NSLocalizedDescriptionKey:@"Write failed"}];
        [delegate transfer:op didFailWithError:op.error];
    } else {
        op.transferredBytes = data.length; op.progress = 1.0; op.status = VFSTransferStatusCompleted; op.endTime = [NSDate date];
        [delegate transferDidComplete:op];
    }
    [self.activeTransfers addObject:op];
    return op;
}

- (VFSTransferOperation *)downloadFileAtPath:(NSString *)virtualPath toURL:(NSURL *)destURL delegate:(id<VFSTransferDelegate>)delegate {
    NSString *src = [self resolveStoragePathForVirtualPath:virtualPath];
    NSData *data = [NSData dataWithContentsOfFile:src];
    if (!data) return nil;
    VFSTransferOperation *op = [[VFSTransferOperation alloc] init];
    op.isUpload = NO; op.delegate = delegate; op.totalBytes = data.length;
    op.status = VFSTransferStatusTransferring; [delegate transferDidStart:op];
    BOOL ok = [data writeToURL:destURL atomically:YES];
    if (!ok) {
        op.status = VFSTransferStatusFailed;
        op.error = [NSError errorWithDomain:@"VFSDownload" code:-1 userInfo:@{NSLocalizedDescriptionKey:@"Write failed"}];
        [delegate transfer:op didFailWithError:op.error];
    } else {
        op.transferredBytes = data.length; op.progress = 1.0; op.status = VFSTransferStatusCompleted; op.endTime = [NSDate date];
        [delegate transferDidComplete:op];
    }
    [self.activeTransfers addObject:op];
    return op;
}

- (VFSTransferOperation *)downloadFilesAtPaths:(NSArray<NSString *> *)virtualPaths toURL:(NSURL *)destURL delegate:(id<VFSTransferDelegate>)delegate {
    VFSTransferOperation *op = [[VFSTransferOperation alloc] init];
    op.isUpload = NO; op.delegate = delegate; op.status = VFSTransferStatusPreparing;
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSFileManager *fm = [NSFileManager defaultManager];
        [fm createDirectoryAtPath:destURL.path withIntermediateDirectories:YES attributes:nil error:nil];
        op.status = VFSTransferStatusTransferring; [delegate transferDidStart:op];
        for (NSString *virt in virtualPaths) {
            NSString *src = [self resolveStoragePathForVirtualPath:virt];
            NSData *data = [NSData dataWithContentsOfFile:src];
            if (!data) { op.status = VFSTransferStatusFailed; op.error = [NSError errorWithDomain:@"VFSDownload" code:-2 userInfo:@{NSLocalizedDescriptionKey:@"Read failed"}]; [delegate transfer:op didFailWithError:op.error]; return; }
            NSURL *target = [destURL URLByAppendingPathComponent:virt.lastPathComponent];
            [data writeToURL:target atomically:YES];
            op.transferredBytes += data.length; op.totalBytes += data.length; op.progress = (double)op.transferredBytes / (double)MAX(op.totalBytes, 1);
            [delegate transfer:op didUpdateProgress:op.progress];
        }
        op.status = VFSTransferStatusCompleted; op.endTime = [NSDate date]; [delegate transferDidComplete:op];
    });
    [self.activeTransfers addObject:op];
    return op;
}

- (NSData *)readDataFromFileAtPath:(NSString *)path error:(NSError **)error {
    NSString *storage = [self resolveStoragePathForVirtualPath:path];
    return [NSData dataWithContentsOfFile:storage options:0 error:error];
}

@end
