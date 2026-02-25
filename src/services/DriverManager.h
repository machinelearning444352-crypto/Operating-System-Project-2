#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, DriverType) {
    DriverTypeGraphics,
    DriverTypeAudio,
    DriverTypeNetwork,
    DriverTypeBluetooth,
    DriverTypeUSB,
    DriverTypeStorage,
    DriverTypePrinter,
    DriverTypeCamera,
    DriverTypeInput,
    DriverTypeOther
};

typedef NS_ENUM(NSInteger, DriverStatus) {
    DriverStatusActive,
    DriverStatusInactive,
    DriverStatusOutdated,
    DriverStatusMissing,
    DriverStatusError
};

@interface DriverInfo : NSObject
@property (nonatomic, strong) NSString *driverID;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *version;
@property (nonatomic, strong) NSString *latestVersion;
@property (nonatomic, strong) NSString *manufacturer;
@property (nonatomic, strong) NSString *deviceName;
@property (nonatomic, strong) NSString *driverDescription;
@property (nonatomic, assign) DriverType type;
@property (nonatomic, assign) DriverStatus status;
@property (nonatomic, strong) NSDate *installDate;
@property (nonatomic, strong) NSDate *lastUpdateCheck;
@property (nonatomic, assign) BOOL updateAvailable;
@property (nonatomic, assign) BOOL isSystemDriver;
@property (nonatomic, assign) BOOL requiresRestart;
@property (nonatomic, strong) NSString *hardwareID;
@property (nonatomic, strong) NSArray<NSString *> *compatibleDevices;
@end

@protocol DriverManagerDelegate <NSObject>
@optional
- (void)driverManager:(id)manager didDetectNewDevice:(DriverInfo *)driver;
- (void)driverManager:(id)manager didUpdateDriver:(DriverInfo *)driver;
- (void)driverManager:(id)manager didRemoveDriver:(DriverInfo *)driver;
- (void)driverManager:(id)manager didFindDriverUpdate:(DriverInfo *)driver;
- (void)driverManager:(id)manager didFailWithError:(NSError *)error;
@end

@interface DriverManager : NSObject

@property (nonatomic, weak) id<DriverManagerDelegate> delegate;
@property (nonatomic, strong, readonly) NSArray<DriverInfo *> *installedDrivers;
@property (nonatomic, strong, readonly) NSArray<DriverInfo *> *availableUpdates;
@property (nonatomic, assign, readonly) BOOL isScanning;
@property (nonatomic, assign) BOOL automaticUpdateCheckEnabled;

+ (instancetype)sharedManager;

// Driver scanning
- (void)scanForDrivers;
- (void)scanForDriverUpdates;
- (void)scanForNewDevices;

// Driver management
- (void)installDriver:(DriverInfo *)driver;
- (void)updateDriver:(DriverInfo *)driver;
- (void)removeDriver:(DriverInfo *)driver;
- (void)enableDriver:(DriverInfo *)driver;
- (void)disableDriver:(DriverInfo *)driver;

// Driver information
- (NSArray<DriverInfo *> *)getDriversOfType:(DriverType)type;
- (NSArray<DriverInfo *> *)getOutdatedDrivers;
- (DriverInfo *)getDriverForDevice:(NSString *)deviceName;

// Hardware detection
- (NSArray<NSString *> *)getConnectedDevices;
- (NSDictionary *)getHardwareInfo;
- (BOOL)isDeviceSupported:(NSString *)deviceID;

@end
