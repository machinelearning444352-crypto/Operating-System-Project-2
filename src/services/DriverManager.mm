#import "DriverManager.h"
#import <IOKit/IOKitLib.h>
#import <IOKit/network/IOEthernetInterface.h>
#import <IOKit/usb/IOUSBLib.h>
#include <sys/sysctl.h>

@implementation DriverInfo
@end

@interface DriverManager ()
@property(nonatomic, strong)
    NSMutableArray<DriverInfo *> *mutableInstalledDrivers;
@property(nonatomic, strong)
    NSMutableArray<DriverInfo *> *mutableAvailableUpdates;
@property(nonatomic, assign) BOOL scanning;
@property(nonatomic, strong) NSTimer *scanTimer;
@end

@implementation DriverManager

+ (instancetype)sharedManager {
  static DriverManager *sharedInstance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    sharedInstance = [[self alloc] init];
  });
  return sharedInstance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _mutableInstalledDrivers = [NSMutableArray array];
    _mutableAvailableUpdates = [NSMutableArray array];
    _automaticUpdateCheckEnabled = YES;

    [self loadDriverDatabase];
    [self scanForDrivers];
    [self schedulePeriodicScans];
  }
  return self;
}

#pragma mark - Properties

- (NSArray<DriverInfo *> *)installedDrivers {
  return [self.mutableInstalledDrivers copy];
}

- (NSArray<DriverInfo *> *)availableUpdates {
  return [self.mutableAvailableUpdates copy];
}

- (BOOL)isScanning {
  return self.scanning;
}

#pragma mark - Driver Scanning

- (void)scanForDrivers {
  if (self.scanning)
    return;

  self.scanning = YES;
  [self.mutableInstalledDrivers removeAllObjects];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),
                 ^{
                   NSArray *drivers = [self detectSystemDrivers];

                   dispatch_async(dispatch_get_main_queue(), ^{
                     [self.mutableInstalledDrivers addObjectsFromArray:drivers];
                     self.scanning = NO;
                     [self saveDriverDatabase];
                   });
                 });
}

- (void)scanForDriverUpdates {
  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self.mutableAvailableUpdates removeAllObjects];

        for (DriverInfo *driver in self.mutableInstalledDrivers) {
          if ([self checkForDriverUpdate:driver]) {
            [self.mutableAvailableUpdates addObject:driver];

            dispatch_async(dispatch_get_main_queue(), ^{
              if ([self.delegate respondsToSelector:@selector
                                 (driverManager:didFindDriverUpdate:)]) {
                [self.delegate driverManager:self didFindDriverUpdate:driver];
              }
            });
          }
        }
      });
}

- (void)scanForNewDevices {
  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray *connectedDevices = [self getConnectedDevices];

        for (NSString *deviceID in connectedDevices) {
          BOOL hasDriver = NO;
          for (DriverInfo *driver in self.mutableInstalledDrivers) {
            if ([driver.hardwareID isEqualToString:deviceID]) {
              hasDriver = YES;
              break;
            }
          }

          if (!hasDriver) {
            DriverInfo *newDriver = [self createDriverForDevice:deviceID];
            if (newDriver) {
              dispatch_async(dispatch_get_main_queue(), ^{
                if ([self.delegate respondsToSelector:@selector
                                   (driverManager:didDetectNewDevice:)]) {
                  [self.delegate driverManager:self
                            didDetectNewDevice:newDriver];
                }
              });
            }
          }
        }
      });
}

#pragma mark - Driver Management

- (void)installDriver:(DriverInfo *)driver {
  if (!driver)
    return;

  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Simulate driver installation
        [NSThread sleepForTimeInterval:2.0];

        driver.status = DriverStatusActive;
        driver.installDate = [NSDate date];

        dispatch_async(dispatch_get_main_queue(), ^{
          [self.mutableInstalledDrivers addObject:driver];
          [self saveDriverDatabase];

          if ([self.delegate respondsToSelector:@selector(driverManager:
                                                        didUpdateDriver:)]) {
            [self.delegate driverManager:self didUpdateDriver:driver];
          }
        });
      });
}

- (void)updateDriver:(DriverInfo *)driver {
  if (!driver || !driver.updateAvailable)
    return;

  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // Simulate driver update
        [NSThread sleepForTimeInterval:3.0];

        driver.version = driver.latestVersion;
        driver.updateAvailable = NO;
        driver.status = DriverStatusActive;

        dispatch_async(dispatch_get_main_queue(), ^{
          [self.mutableAvailableUpdates removeObject:driver];
          [self saveDriverDatabase];

          if ([self.delegate respondsToSelector:@selector(driverManager:
                                                        didUpdateDriver:)]) {
            [self.delegate driverManager:self didUpdateDriver:driver];
          }
        });
      });
}

- (void)removeDriver:(DriverInfo *)driver {
  if (!driver || driver.isSystemDriver)
    return;

  [self.mutableInstalledDrivers removeObject:driver];
  [self saveDriverDatabase];

  if ([self.delegate respondsToSelector:@selector(driverManager:
                                                didRemoveDriver:)]) {
    [self.delegate driverManager:self didRemoveDriver:driver];
  }
}

- (void)enableDriver:(DriverInfo *)driver {
  if (!driver)
    return;
  driver.status = DriverStatusActive;
  [self saveDriverDatabase];
}

- (void)disableDriver:(DriverInfo *)driver {
  if (!driver || driver.isSystemDriver)
    return;
  driver.status = DriverStatusInactive;
  [self saveDriverDatabase];
}

#pragma mark - Driver Information

- (NSArray<DriverInfo *> *)getDriversOfType:(DriverType)type {
  NSMutableArray *result = [NSMutableArray array];
  for (DriverInfo *driver in self.mutableInstalledDrivers) {
    if (driver.type == type) {
      [result addObject:driver];
    }
  }
  return result;
}

- (NSArray<DriverInfo *> *)getOutdatedDrivers {
  NSMutableArray *result = [NSMutableArray array];
  for (DriverInfo *driver in self.mutableInstalledDrivers) {
    if (driver.updateAvailable || driver.status == DriverStatusOutdated) {
      [result addObject:driver];
    }
  }
  return result;
}

- (DriverInfo *)getDriverForDevice:(NSString *)deviceName {
  for (DriverInfo *driver in self.mutableInstalledDrivers) {
    if ([driver.deviceName isEqualToString:deviceName]) {
      return driver;
    }
  }
  return nil;
}

#pragma mark - Hardware Detection

- (NSArray<NSString *> *)getConnectedDevices {
  NSMutableArray *devices = [NSMutableArray array];

  // Get USB devices
  CFMutableDictionaryRef matchingDict =
      IOServiceMatching(kIOUSBDeviceClassName);
  io_iterator_t iter;
  kern_return_t kr =
      IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iter);

  if (kr == KERN_SUCCESS) {
    io_service_t device;
    while ((device = IOIteratorNext(iter))) {
      CFStringRef deviceName = (CFStringRef)IORegistryEntryCreateCFProperty(
          device, CFSTR("USB Product Name"), kCFAllocatorDefault, 0);
      if (deviceName) {
        [devices addObject:(__bridge NSString *)deviceName];
        CFRelease(deviceName);
      }
      IOObjectRelease(device);
    }
    IOObjectRelease(iter);
  }

  return devices;
}

- (NSDictionary *)getHardwareInfo {
  NSMutableDictionary *info = [NSMutableDictionary dictionary];

  // Get system info
  info[@"model"] = [self getSystemModel];
  info[@"processor"] = [self getProcessorInfo];
  info[@"memory"] = [self getMemoryInfo];
  info[@"graphics"] = [self getGraphicsInfo];
  info[@"storage"] = [self getStorageInfo];

  return info;
}

- (BOOL)isDeviceSupported:(NSString *)deviceID {
  // Check if device has compatible drivers
  return YES; // Simplified for simulation
}

#pragma mark - Helper Methods

- (NSArray<DriverInfo *> *)detectSystemDrivers {
  NSMutableArray *drivers = [NSMutableArray array];

  // Graphics driver
  DriverInfo *graphicsDriver = [[DriverInfo alloc] init];
  graphicsDriver.driverID = @"graphics-intel-uhd";
  graphicsDriver.name = @"Intel UHD Graphics Driver";
  graphicsDriver.version = @"31.0.101.4091";
  graphicsDriver.latestVersion = @"31.0.101.4255";
  graphicsDriver.manufacturer = @"Intel Corporation";
  graphicsDriver.deviceName = @"Intel UHD Graphics 630";
  graphicsDriver.driverDescription =
      @"Graphics driver for Intel integrated graphics";
  graphicsDriver.type = DriverTypeGraphics;
  graphicsDriver.status = DriverStatusActive;
  graphicsDriver.installDate =
      [NSDate dateWithTimeIntervalSinceNow:-86400 * 30];
  graphicsDriver.updateAvailable = YES;
  graphicsDriver.isSystemDriver = YES;
  graphicsDriver.requiresRestart = YES;
  graphicsDriver.hardwareID = @"PCI\\VEN_8086&DEV_3E9B";
  [drivers addObject:graphicsDriver];

  // Audio driver
  DriverInfo *audioDriver = [[DriverInfo alloc] init];
  audioDriver.driverID = @"audio-realtek";
  audioDriver.name = @"Realtek High Definition Audio";
  audioDriver.version = @"6.0.9279.1";
  audioDriver.latestVersion = @"6.0.9279.1";
  audioDriver.manufacturer = @"Realtek Semiconductor";
  audioDriver.deviceName = @"Realtek ALC892 Audio";
  audioDriver.driverDescription = @"High definition audio codec driver";
  audioDriver.type = DriverTypeAudio;
  audioDriver.status = DriverStatusActive;
  audioDriver.installDate = [NSDate dateWithTimeIntervalSinceNow:-86400 * 60];
  audioDriver.updateAvailable = NO;
  audioDriver.isSystemDriver = YES;
  audioDriver.requiresRestart = NO;
  audioDriver.hardwareID = @"PCI\\VEN_10EC&DEV_0892";
  [drivers addObject:audioDriver];

  // Network driver
  DriverInfo *networkDriver = [[DriverInfo alloc] init];
  networkDriver.driverID = @"network-intel-ethernet";
  networkDriver.name = @"Intel Ethernet Connection";
  networkDriver.version = @"12.19.2.45";
  networkDriver.latestVersion = @"12.19.3.2";
  networkDriver.manufacturer = @"Intel Corporation";
  networkDriver.deviceName = @"Intel I219-V Ethernet";
  networkDriver.driverDescription = @"Gigabit ethernet network adapter driver";
  networkDriver.type = DriverTypeNetwork;
  networkDriver.status = DriverStatusActive;
  networkDriver.installDate = [NSDate dateWithTimeIntervalSinceNow:-86400 * 45];
  networkDriver.updateAvailable = YES;
  networkDriver.isSystemDriver = YES;
  networkDriver.requiresRestart = YES;
  networkDriver.hardwareID = @"PCI\\VEN_8086&DEV_15BC";
  [drivers addObject:networkDriver];

  // Bluetooth driver
  DriverInfo *bluetoothDriver = [[DriverInfo alloc] init];
  bluetoothDriver.driverID = @"bluetooth-broadcom";
  bluetoothDriver.name = @"Broadcom Bluetooth";
  bluetoothDriver.version = @"12.0.1.1420";
  bluetoothDriver.latestVersion = @"12.0.1.1420";
  bluetoothDriver.manufacturer = @"Broadcom Corporation";
  bluetoothDriver.deviceName = @"Broadcom BCM20702 Bluetooth";
  bluetoothDriver.driverDescription = @"Bluetooth wireless adapter driver";
  bluetoothDriver.type = DriverTypeBluetooth;
  bluetoothDriver.status = DriverStatusActive;
  bluetoothDriver.installDate =
      [NSDate dateWithTimeIntervalSinceNow:-86400 * 90];
  bluetoothDriver.updateAvailable = NO;
  bluetoothDriver.isSystemDriver = YES;
  bluetoothDriver.requiresRestart = NO;
  bluetoothDriver.hardwareID = @"USB\\VID_0A5C&PID_21E8";
  [drivers addObject:bluetoothDriver];

  // USB controller driver
  DriverInfo *usbDriver = [[DriverInfo alloc] init];
  usbDriver.driverID = @"usb-xhci";
  usbDriver.name = @"USB xHCI Controller";
  usbDriver.version = @"10.0.19041.1";
  usbDriver.latestVersion = @"10.0.19041.1";
  usbDriver.manufacturer = @"Intel Corporation";
  usbDriver.deviceName = @"Intel USB 3.1 xHCI Host Controller";
  usbDriver.driverDescription =
      @"Extensible host controller interface driver for USB";
  usbDriver.type = DriverTypeUSB;
  usbDriver.status = DriverStatusActive;
  usbDriver.installDate = [NSDate dateWithTimeIntervalSinceNow:-86400 * 120];
  usbDriver.updateAvailable = NO;
  usbDriver.isSystemDriver = YES;
  usbDriver.requiresRestart = NO;
  usbDriver.hardwareID = @"PCI\\VEN_8086&DEV_A36D";
  [drivers addObject:usbDriver];

  // Storage driver
  DriverInfo *storageDriver = [[DriverInfo alloc] init];
  storageDriver.driverID = @"storage-nvme";
  storageDriver.name = @"NVMe Storage Controller";
  storageDriver.version = @"1.4.0.0";
  storageDriver.latestVersion = @"1.4.1.0";
  storageDriver.manufacturer = @"Samsung Electronics";
  storageDriver.deviceName = @"Samsung SSD 970 EVO Plus";
  storageDriver.driverDescription = @"NVMe solid state drive controller driver";
  storageDriver.type = DriverTypeStorage;
  storageDriver.status = DriverStatusActive;
  storageDriver.installDate =
      [NSDate dateWithTimeIntervalSinceNow:-86400 * 150];
  storageDriver.updateAvailable = YES;
  storageDriver.isSystemDriver = YES;
  storageDriver.requiresRestart = YES;
  storageDriver.hardwareID = @"PCI\\VEN_144D&DEV_A808";
  [drivers addObject:storageDriver];

  return drivers;
}

- (BOOL)checkForDriverUpdate:(DriverInfo *)driver {
  // Simulate checking for updates
  if (driver.updateAvailable) {
    driver.status = DriverStatusOutdated;
    driver.lastUpdateCheck = [NSDate date];
    return YES;
  }
  return NO;
}

- (DriverInfo *)createDriverForDevice:(NSString *)deviceID {
  DriverInfo *driver = [[DriverInfo alloc] init];
  driver.driverID = [NSString stringWithFormat:@"device-%@", deviceID];
  driver.deviceName = deviceID;
  driver.status = DriverStatusMissing;
  driver.hardwareID = deviceID;
  return driver;
}

- (NSString *)getSystemModel {
  size_t size;
  sysctlbyname("hw.model", NULL, &size, NULL, 0);
  char *model = (char *)malloc(size);
  sysctlbyname("hw.model", model, &size, NULL, 0);
  NSString *modelString = [NSString stringWithUTF8String:model];
  free(model);
  return modelString;
}

- (NSString *)getProcessorInfo {
  size_t size;
  sysctlbyname("machdep.cpu.brand_string", NULL, &size, NULL, 0);
  char *cpu = (char *)malloc(size);
  sysctlbyname("machdep.cpu.brand_string", cpu, &size, NULL, 0);
  NSString *cpuString = [NSString stringWithUTF8String:cpu];
  free(cpu);
  return cpuString;
}

- (NSString *)getMemoryInfo {
  int mib[2] = {CTL_HW, HW_MEMSIZE};
  uint64_t memsize;
  size_t len = sizeof(memsize);
  sysctl(mib, 2, &memsize, &len, NULL, 0);
  return [NSString stringWithFormat:@"%llu GB", memsize / 1073741824];
}

- (NSString *)getGraphicsInfo {
  return @"Intel UHD Graphics 630";
}

- (NSString *)getStorageInfo {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSDictionary *attrs = [fm attributesOfFileSystemForPath:@"/" error:nil];
  unsigned long long totalSpace =
      [[attrs objectForKey:NSFileSystemSize] unsignedLongLongValue];
  return [NSString stringWithFormat:@"%llu GB", totalSpace / 1073741824];
}

#pragma mark - Persistence

- (void)saveDriverDatabase {
  NSString *path = [self driverDatabasePath];
  NSMutableArray *driverDicts = [NSMutableArray array];

  for (DriverInfo *driver in self.mutableInstalledDrivers) {
    NSDictionary *dict = @{
      @"driverID" : driver.driverID ?: @"",
      @"name" : driver.name ?: @"",
      @"version" : driver.version ?: @"",
      @"type" : @(driver.type),
      @"status" : @(driver.status)
    };
    [driverDicts addObject:dict];
  }

  [driverDicts writeToFile:path atomically:YES];
}

- (void)loadDriverDatabase {
  NSString *path = [self driverDatabasePath];
  NSArray *driverDicts = [NSArray arrayWithContentsOfFile:path];

  if (driverDicts) {
    for (NSDictionary *dict in driverDicts) {
      DriverInfo *driver = [[DriverInfo alloc] init];
      driver.driverID = dict[@"driverID"];
      driver.name = dict[@"name"];
      driver.version = dict[@"version"];
      driver.type = (DriverType)[dict[@"type"] integerValue];
      driver.status = (DriverStatus)[dict[@"status"] integerValue];
      [self.mutableInstalledDrivers addObject:driver];
    }
  }
}

- (NSString *)driverDatabasePath {
  NSString *appSupport = [NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
  NSString *appFolder =
      [appSupport stringByAppendingPathComponent:@"macOSDesktop"];
  [[NSFileManager defaultManager] createDirectoryAtPath:appFolder
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  return [appFolder stringByAppendingPathComponent:@"driver_database.plist"];
}

- (void)schedulePeriodicScans {
  self.scanTimer =
      [NSTimer scheduledTimerWithTimeInterval:3600.0 // 1 hour
                                       target:self
                                     selector:@selector(scanForNewDevices)
                                     userInfo:nil
                                      repeats:YES];
}

@end
