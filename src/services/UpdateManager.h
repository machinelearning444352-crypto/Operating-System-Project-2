#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, UpdateType) {
    UpdateTypeSystem,
    UpdateTypeApplication,
    UpdateTypeDriver,
    UpdateTypeSecurity,
    UpdateTypeFirmware
};

typedef NS_ENUM(NSInteger, UpdateStatus) {
    UpdateStatusAvailable,
    UpdateStatusDownloading,
    UpdateStatusDownloaded,
    UpdateStatusInstalling,
    UpdateStatusInstalled,
    UpdateStatusFailed,
    UpdateStatusCancelled
};

typedef NS_ENUM(NSInteger, UpdatePriority) {
    UpdatePriorityCritical,
    UpdatePriorityRecommended,
    UpdatePriorityOptional
};

@interface UpdateInfo : NSObject
@property (nonatomic, strong) NSString *updateID;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *currentVersion;
@property (nonatomic, strong) NSString *updateDescription;
@property (nonatomic, strong) NSString *releaseNotes;
@property (nonatomic, assign) UpdateType type;
@property (nonatomic, assign) UpdatePriority priority;
@property (nonatomic, assign) UpdateStatus status;
@property (nonatomic, assign) NSUInteger size; // in bytes
@property (nonatomic, strong) NSDate *releaseDate;
@property (nonatomic, assign) BOOL requiresRestart;
@property (nonatomic, assign) CGFloat downloadProgress;
@property (nonatomic, assign) CGFloat installProgress;
@property (nonatomic, strong) NSURL *downloadURL;
@property (nonatomic, strong) NSString *publisher;
@property (nonatomic, strong) NSArray<NSString *> *dependencies;
@end

@protocol UpdateManagerDelegate <NSObject>
@optional
- (void)updateManager:(id)manager didFindUpdates:(NSArray<UpdateInfo *> *)updates;
- (void)updateManager:(id)manager didStartDownloadingUpdate:(UpdateInfo *)update;
- (void)updateManager:(id)manager didUpdateDownloadProgress:(UpdateInfo *)update;
- (void)updateManager:(id)manager didFinishDownloadingUpdate:(UpdateInfo *)update;
- (void)updateManager:(id)manager didStartInstallingUpdate:(UpdateInfo *)update;
- (void)updateManager:(id)manager didUpdateInstallProgress:(UpdateInfo *)update;
- (void)updateManager:(id)manager didFinishInstallingUpdate:(UpdateInfo *)update;
- (void)updateManager:(id)manager didFailWithError:(NSError *)error forUpdate:(UpdateInfo *)update;
@end

@interface UpdateManager : NSObject

@property (nonatomic, weak) id<UpdateManagerDelegate> delegate;
@property (nonatomic, strong, readonly) NSArray<UpdateInfo *> *availableUpdates;
@property (nonatomic, strong, readonly) NSArray<UpdateInfo *> *installedUpdates;
@property (nonatomic, assign, readonly) BOOL isChecking;
@property (nonatomic, assign, readonly) BOOL isDownloading;
@property (nonatomic, assign, readonly) BOOL isInstalling;
@property (nonatomic, assign) BOOL automaticCheckEnabled;
@property (nonatomic, assign) BOOL automaticDownloadEnabled;
@property (nonatomic, assign) BOOL automaticInstallEnabled;
@property (nonatomic, assign) NSTimeInterval checkInterval; // in seconds

+ (instancetype)sharedManager;

// Update checking
- (void)checkForUpdates;
- (void)checkForUpdatesInBackground;
- (void)scheduleAutomaticChecks;
- (void)cancelAutomaticChecks;

// Update management
- (void)downloadUpdate:(UpdateInfo *)update;
- (void)downloadAllUpdates;
- (void)cancelDownload:(UpdateInfo *)update;
- (void)installUpdate:(UpdateInfo *)update;
- (void)installAllDownloadedUpdates;
- (void)cancelInstallation:(UpdateInfo *)update;

// Update history
- (NSArray<UpdateInfo *> *)getUpdateHistory;
- (void)clearUpdateHistory;

// Preferences
- (void)setCheckInterval:(NSTimeInterval)interval;
- (void)setAutomaticUpdatesEnabled:(BOOL)enabled;
- (void)setDownloadUpdatesAutomatically:(BOOL)enabled;
- (void)setInstallUpdatesAutomatically:(BOOL)enabled;

// Notifications
- (void)showUpdateNotification:(UpdateInfo *)update;
- (void)showUpdateAvailableNotification:(NSInteger)count;

@end
