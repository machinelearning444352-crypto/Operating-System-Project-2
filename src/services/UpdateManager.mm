#import "UpdateManager.h"

@implementation UpdateInfo
@end

@interface UpdateManager ()
@property(nonatomic, strong)
    NSMutableArray<UpdateInfo *> *mutableAvailableUpdates;
@property(nonatomic, strong)
    NSMutableArray<UpdateInfo *> *mutableInstalledUpdates;
@property(nonatomic, strong) NSTimer *checkTimer;
@property(nonatomic, strong) NSMutableDictionary *downloadTasks;
@property(nonatomic, strong) NSMutableDictionary *installTasks;
@property(nonatomic, assign) BOOL checking;
@property(nonatomic, assign) BOOL downloading;
@property(nonatomic, assign) BOOL installing;
@end

@implementation UpdateManager

+ (instancetype)sharedManager {
  static UpdateManager *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _mutableAvailableUpdates = [NSMutableArray array];
    _mutableInstalledUpdates = [NSMutableArray array];
    _downloadTasks = [NSMutableDictionary dictionary];
    _installTasks = [NSMutableDictionary dictionary];
    _automaticCheckEnabled = YES;
    _automaticDownloadEnabled = NO;
    _automaticInstallEnabled = NO;
    _checkInterval = 86400; // 24 hours

    [self loadInstalledUpdates];
    [self scheduleAutomaticChecks];
  }
  return self;
}

- (void)dealloc {
  [self cancelAutomaticChecks];
}

#pragma mark - Properties

- (NSArray<UpdateInfo *> *)availableUpdates {
  return [self.mutableAvailableUpdates copy];
}

- (NSArray<UpdateInfo *> *)installedUpdates {
  return [self.mutableInstalledUpdates copy];
}

- (BOOL)isChecking {
  return self.checking;
}

- (BOOL)isDownloading {
  return self.downloading;
}

- (BOOL)isInstalling {
  return self.installing;
}

#pragma mark - Update Checking

- (void)checkForUpdates {
  if (self.checking) {
    NSLog(@"Update check already in progress");
    return;
  }

  self.checking = YES;
  [self.mutableAvailableUpdates removeAllObjects];

  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Simulate checking for updates
        NSArray *simulatedUpdates = [self generateSimulatedUpdates];

        dispatch_async(dispatch_get_main_queue(), ^{
          [self.mutableAvailableUpdates addObjectsFromArray:simulatedUpdates];
          self.checking = NO;

          if ([self.delegate respondsToSelector:@selector(updateManager:
                                                         didFindUpdates:)]) {
            [self.delegate updateManager:self
                          didFindUpdates:self.availableUpdates];
          }

          if (simulatedUpdates.count > 0) {
            [self showUpdateAvailableNotification:simulatedUpdates.count];

            if (self.automaticDownloadEnabled) {
              [self downloadAllUpdates];
            }
          }
        });
      });
}

- (void)checkForUpdatesInBackground {
  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        [self checkForUpdates];
      });
}

- (void)scheduleAutomaticChecks {
  [self cancelAutomaticChecks];

  if (self.automaticCheckEnabled && self.checkInterval > 0) {
    self.checkTimer = [NSTimer
        scheduledTimerWithTimeInterval:self.checkInterval
                                target:self
                              selector:@selector(checkForUpdatesInBackground)
                              userInfo:nil
                               repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.checkTimer
                              forMode:NSRunLoopCommonModes];
  }
}

- (void)cancelAutomaticChecks {
  if (self.checkTimer) {
    [self.checkTimer invalidate];
    self.checkTimer = nil;
  }
}

#pragma mark - Update Management

- (void)downloadUpdate:(UpdateInfo *)update {
  if (!update || update.status == UpdateStatusDownloading ||
      update.status == UpdateStatusDownloaded) {
    return;
  }

  update.status = UpdateStatusDownloading;
  update.downloadProgress = 0.0;
  self.downloading = YES;

  if ([self.delegate respondsToSelector:@selector(updateManager:
                                            didStartDownloadingUpdate:)]) {
    [self.delegate updateManager:self didStartDownloadingUpdate:update];
  }

  // Simulate download
  NSTimer *downloadTimer = [NSTimer
      scheduledTimerWithTimeInterval:0.1
                             repeats:YES
                               block:^(NSTimer *timer) {
                                 update.downloadProgress += 0.05;

                                 if ([self.delegate
                                         respondsToSelector:@selector
                                         (updateManager:
                                             didUpdateDownloadProgress:)]) {
                                   [self.delegate updateManager:self
                                       didUpdateDownloadProgress:update];
                                 }

                                 if (update.downloadProgress >= 1.0) {
                                   [timer invalidate];
                                   update.status = UpdateStatusDownloaded;
                                   update.downloadProgress = 1.0;
                                   self.downloading = NO;

                                   if ([self.delegate
                                           respondsToSelector:@selector
                                           (updateManager:
                                               didFinishDownloadingUpdate:)]) {
                                     [self.delegate updateManager:self
                                         didFinishDownloadingUpdate:update];
                                   }

                                   if (self.automaticInstallEnabled) {
                                     [self installUpdate:update];
                                   }
                                 }
                               }];

  self.downloadTasks[update.updateID] = downloadTimer;
}

- (void)downloadAllUpdates {
  for (UpdateInfo *update in self.availableUpdates) {
    if (update.status == UpdateStatusAvailable) {
      [self downloadUpdate:update];
    }
  }
}

- (void)cancelDownload:(UpdateInfo *)update {
  NSTimer *timer = self.downloadTasks[update.updateID];
  if (timer) {
    [timer invalidate];
    [self.downloadTasks removeObjectForKey:update.updateID];
    update.status = UpdateStatusCancelled;
    self.downloading = NO;
  }
}

- (void)installUpdate:(UpdateInfo *)update {
  if (!update || update.status != UpdateStatusDownloaded) {
    return;
  }

  update.status = UpdateStatusInstalling;
  update.installProgress = 0.0;
  self.installing = YES;

  if ([self.delegate respondsToSelector:@selector(updateManager:
                                            didStartInstallingUpdate:)]) {
    [self.delegate updateManager:self didStartInstallingUpdate:update];
  }

  // Simulate installation
  NSTimer *installTimer = [NSTimer
      scheduledTimerWithTimeInterval:0.15
                             repeats:YES
                               block:^(NSTimer *timer) {
                                 update.installProgress += 0.04;

                                 if ([self.delegate
                                         respondsToSelector:@selector
                                         (updateManager:
                                             didUpdateInstallProgress:)]) {
                                   [self.delegate updateManager:self
                                       didUpdateInstallProgress:update];
                                 }

                                 if (update.installProgress >= 1.0) {
                                   [timer invalidate];
                                   update.status = UpdateStatusInstalled;
                                   update.installProgress = 1.0;
                                   self.installing = NO;

                                   [self.mutableAvailableUpdates
                                       removeObject:update];
                                   [self.mutableInstalledUpdates
                                       addObject:update];
                                   [self saveInstalledUpdates];

                                   if ([self.delegate
                                           respondsToSelector:@selector
                                           (updateManager:
                                               didFinishInstallingUpdate:)]) {
                                     [self.delegate updateManager:self
                                         didFinishInstallingUpdate:update];
                                   }

                                   if (update.requiresRestart) {
                                     [self showRestartNotification:update];
                                   }
                                 }
                               }];

  self.installTasks[update.updateID] = installTimer;
}

- (void)installAllDownloadedUpdates {
  for (UpdateInfo *update in self.availableUpdates) {
    if (update.status == UpdateStatusDownloaded) {
      [self installUpdate:update];
    }
  }
}

- (void)cancelInstallation:(UpdateInfo *)update {
  NSTimer *timer = self.installTasks[update.updateID];
  if (timer) {
    [timer invalidate];
    [self.installTasks removeObjectForKey:update.updateID];
    update.status = UpdateStatusCancelled;
    self.installing = NO;
  }
}

#pragma mark - Update History

- (NSArray<UpdateInfo *> *)getUpdateHistory {
  return [self.mutableInstalledUpdates copy];
}

- (void)clearUpdateHistory {
  [self.mutableInstalledUpdates removeAllObjects];
  [self saveInstalledUpdates];
}

#pragma mark - Preferences

- (void)setCheckInterval:(NSTimeInterval)interval {
  _checkInterval = interval;
  [self scheduleAutomaticChecks];
}

- (void)setAutomaticUpdatesEnabled:(BOOL)enabled {
  _automaticCheckEnabled = enabled;
  [self scheduleAutomaticChecks];
}

- (void)setDownloadUpdatesAutomatically:(BOOL)enabled {
  _automaticDownloadEnabled = enabled;
}

- (void)setInstallUpdatesAutomatically:(BOOL)enabled {
  _automaticInstallEnabled = enabled;
}

#pragma mark - Notifications

- (void)showUpdateNotification:(UpdateInfo *)update {
  NSUserNotification *notification = [[NSUserNotification alloc] init];
  notification.title = @"Software Update";
  notification.informativeText = [NSString
      stringWithFormat:@"%@ %@ is available", update.name, update.version];
  notification.soundName = NSUserNotificationDefaultSoundName;

  [[NSUserNotificationCenter defaultUserNotificationCenter]
      deliverNotification:notification];
}

- (void)showUpdateAvailableNotification:(NSInteger)count {
  NSUserNotification *notification = [[NSUserNotification alloc] init];
  notification.title = @"Software Updates Available";
  notification.informativeText =
      [NSString stringWithFormat:@"%ld update%@ available for your Mac",
                                 (long)count, count == 1 ? @" is" : @"s are"];
  notification.soundName = NSUserNotificationDefaultSoundName;
  notification.hasActionButton = YES;
  notification.actionButtonTitle = @"View Updates";

  [[NSUserNotificationCenter defaultUserNotificationCenter]
      deliverNotification:notification];
}

- (void)showRestartNotification:(UpdateInfo *)update {
  NSUserNotification *notification = [[NSUserNotification alloc] init];
  notification.title = @"Restart Required";
  notification.informativeText =
      [NSString stringWithFormat:@"%@ has been installed. Restart your Mac to "
                                 @"complete the installation.",
                                 update.name];
  notification.soundName = NSUserNotificationDefaultSoundName;
  notification.hasActionButton = YES;
  notification.actionButtonTitle = @"Restart";

  [[NSUserNotificationCenter defaultUserNotificationCenter]
      deliverNotification:notification];
}

#pragma mark - Persistence

- (void)saveInstalledUpdates {
  NSString *path = [self installedUpdatesPath];
  NSMutableArray *updateDicts = [NSMutableArray array];

  for (UpdateInfo *update in self.mutableInstalledUpdates) {
    NSDictionary *dict = @{
      @"updateID" : update.updateID ?: @"",
      @"name" : update.name ?: @"",
      @"version" : update.version ?: @"",
      @"type" : @(update.type),
      @"installDate" : [NSDate date]
    };
    [updateDicts addObject:dict];
  }

  [updateDicts writeToFile:path atomically:YES];
}

- (void)loadInstalledUpdates {
  NSString *path = [self installedUpdatesPath];
  NSArray *updateDicts = [NSArray arrayWithContentsOfFile:path];

  if (updateDicts) {
    for (NSDictionary *dict in updateDicts) {
      UpdateInfo *update = [[UpdateInfo alloc] init];
      update.updateID = dict[@"updateID"];
      update.name = dict[@"name"];
      update.version = dict[@"version"];
      update.type = (UpdateType)[dict[@"type"] integerValue];
      update.status = UpdateStatusInstalled;
      [self.mutableInstalledUpdates addObject:update];
    }
  }
}

- (NSString *)installedUpdatesPath {
  NSString *appSupport = [NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
  NSString *appFolder =
      [appSupport stringByAppendingPathComponent:@"macOSDesktop"];
  [[NSFileManager defaultManager] createDirectoryAtPath:appFolder
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  return [appFolder stringByAppendingPathComponent:@"installed_updates.plist"];
}

#pragma mark - Simulated Updates

- (NSArray<UpdateInfo *> *)generateSimulatedUpdates {
  NSMutableArray *updates = [NSMutableArray array];

  // System update
  UpdateInfo *systemUpdate = [[UpdateInfo alloc] init];
  systemUpdate.updateID = @"system-14.3.1";
  systemUpdate.name = @"macOS Sonoma";
  systemUpdate.version = @"14.3.1";
  systemUpdate.currentVersion = @"14.3.0";
  systemUpdate.updateDescription =
      @"macOS Sonoma 14.3.1 includes important security updates and bug fixes.";
  systemUpdate.releaseNotes =
      @"• Improved system stability\n• Security enhancements\n• Bug fixes for "
      @"Safari\n• Performance improvements";
  systemUpdate.type = UpdateTypeSystem;
  systemUpdate.priority = UpdatePriorityRecommended;
  systemUpdate.status = UpdateStatusAvailable;
  systemUpdate.size = 3221225472; // 3 GB
  systemUpdate.releaseDate = [NSDate date];
  systemUpdate.requiresRestart = YES;
  systemUpdate.publisher = @"Apple Inc.";
  [updates addObject:systemUpdate];

  // Security update
  UpdateInfo *securityUpdate = [[UpdateInfo alloc] init];
  securityUpdate.updateID = @"security-2024-001";
  securityUpdate.name = @"Security Update 2024-001";
  securityUpdate.version = @"1.0";
  securityUpdate.currentVersion = @"";
  securityUpdate.updateDescription = @"Critical security patches for macOS.";
  securityUpdate.releaseNotes = @"• Fixes CVE-2024-12345\n• Patches kernel "
                                @"vulnerability\n• Updates system libraries";
  securityUpdate.type = UpdateTypeSecurity;
  securityUpdate.priority = UpdatePriorityCritical;
  securityUpdate.status = UpdateStatusAvailable;
  securityUpdate.size = 524288000; // 500 MB
  securityUpdate.releaseDate = [NSDate date];
  securityUpdate.requiresRestart = YES;
  securityUpdate.publisher = @"Apple Inc.";
  [updates addObject:securityUpdate];

  // Safari update
  UpdateInfo *safariUpdate = [[UpdateInfo alloc] init];
  safariUpdate.updateID = @"safari-17.3";
  safariUpdate.name = @"Safari";
  safariUpdate.version = @"17.3";
  safariUpdate.currentVersion = @"17.2";
  safariUpdate.updateDescription =
      @"Safari 17.3 includes performance improvements and new features.";
  safariUpdate.releaseNotes =
      @"• Faster page loading\n• Improved privacy features\n• Bug fixes";
  safariUpdate.type = UpdateTypeApplication;
  safariUpdate.priority = UpdatePriorityRecommended;
  safariUpdate.status = UpdateStatusAvailable;
  safariUpdate.size = 209715200; // 200 MB
  safariUpdate.releaseDate = [NSDate date];
  safariUpdate.requiresRestart = NO;
  safariUpdate.publisher = @"Apple Inc.";
  [updates addObject:safariUpdate];

  return updates;
}

@end
