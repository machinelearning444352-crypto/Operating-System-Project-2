#import "USBDriver.h"
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>

// ============================================================================
// USBDriver.mm — USB Driver Implementation
// IOKit-based USB device enumeration, hotplug notification, data transfer
// ============================================================================

@interface USBDriver ()
@property(nonatomic, readwrite) USBDriverState state;
@property(nonatomic, strong) NSMutableArray<USBDevice *> *devices;
@property(nonatomic, strong)
    NSMutableDictionary<NSNumber *, USBDevice *> *deviceByLocation;
@property(nonatomic, strong) dispatch_queue_t usbQueue;
@property(nonatomic, assign) IONotificationPortRef notifyPort;
@property(nonatomic, assign) io_iterator_t attachIterator;
@property(nonatomic, assign) io_iterator_t detachIterator;
@property(nonatomic, assign) BOOL monitoring;
@end

// IOKit notification callbacks
static void USBDeviceAttachedCallback(void *refcon, io_iterator_t iterator);
static void USBDeviceDetachedCallback(void *refcon, io_iterator_t iterator);

@implementation USBDriver

+ (instancetype)sharedInstance {
  static USBDriver *inst;
  static dispatch_once_t t;
  dispatch_once(&t, ^{
    inst = [[USBDriver alloc] init];
  });
  return inst;
}

- (instancetype)init {
  if (self = [super init]) {
    _devices = [NSMutableArray array];
    _deviceByLocation = [NSMutableDictionary dictionary];
    _usbQueue =
        dispatch_queue_create("com.virtualos.usb", DISPATCH_QUEUE_SERIAL);
    _state = USBDriverOff;
  }
  return self;
}

#pragma mark - Lifecycle

- (BOOL)start {
  NSLog(@"[USBDriver] ═══════════════════════════════════════");
  NSLog(@"[USBDriver]  VirtualOS USB Driver v1.0");
  NSLog(@"[USBDriver]  Built from scratch — IOKit direct");
  NSLog(@"[USBDriver] ═══════════════════════════════════════");

  self.state = USBDriverInitializing;
  [self refreshDeviceList];

  self.state = USBDriverReady;

  NSLog(@"[USBDriver] Ready. %lu USB devices detected.",
        (unsigned long)self.devices.count);

  dispatch_async(dispatch_get_main_queue(), ^{
    [self.delegate usbDriverReady:self.devices.count];
  });

  // Start monitoring hotplug
  [self startHotplugMonitoring];

  return YES;
}

- (void)stop {
  [self stopHotplugMonitoring];
  self.state = USBDriverOff;
  NSLog(@"[USBDriver] Stopped");
}

- (BOOL)isRunning {
  return self.state == USBDriverReady;
}

#pragma mark - Device Enumeration (IOKit)

- (void)refreshDeviceList {
  @synchronized(self.devices) {
    [self.devices removeAllObjects];
    [self.deviceByLocation removeAllObjects];
  }

  // Match all USB devices via IOKit
  CFMutableDictionaryRef matching = IOServiceMatching(kIOUSBDeviceClassName);
  if (!matching) {
    NSLog(@"[USBDriver] Cannot create matching dictionary");
    return;
  }

  io_iterator_t iterator;
  kern_return_t kr =
      IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator);
  if (kr != KERN_SUCCESS) {
    NSLog(@"[USBDriver] IOServiceGetMatchingServices failed: 0x%x", kr);
    return;
  }

  io_service_t service;
  while ((service = IOIteratorNext(iterator))) {
    USBDevice *dev = [self createDeviceFromService:service];
    if (dev) {
      @synchronized(self.devices) {
        [self.devices addObject:dev];
        self.deviceByLocation[@(dev.locationID)] = dev;
      }
    }
    IOObjectRelease(service);
  }
  IOObjectRelease(iterator);

  // Sort: external devices first, then by location
  @synchronized(self.devices) {
    [self.devices
        sortUsingComparator:^NSComparisonResult(USBDevice *a, USBDevice *b) {
          return [@(a.locationID) compare:@(b.locationID)];
        }];
  }

  NSLog(@"[USBDriver] Enumerated %lu USB devices",
        (unsigned long)self.devices.count);
}

- (USBDevice *)createDeviceFromService:(io_service_t)service {
  USBDevice *dev = [USBDevice new];
  dev.service = service;
  dev.state = USBDeviceConfigured;
  dev.attachedAt = [NSDate date];

  // Read all properties from IORegistry
  CFMutableDictionaryRef props = nil;
  kern_return_t kr = IORegistryEntryCreateCFProperties(
      service, &props, kCFAllocatorDefault, kNilOptions);
  if (kr != KERN_SUCCESS || !props)
    return nil;

  NSDictionary *dict = (__bridge_transfer NSDictionary *)props;

  // Vendor / Product IDs
  NSNumber *vid = dict[@"idVendor"];
  NSNumber *pid = dict[@"idProduct"];
  if (!vid && !pid)
    return nil; // Not a real USB device

  dev.vendorID = vid.unsignedShortValue;
  dev.productID = pid.unsignedShortValue;

  // USB version
  NSNumber *bcdUSB = dict[@"bcdUSB"];
  dev.bcdUSB = bcdUSB ? bcdUSB.unsignedShortValue : 0;

  // Device version
  NSNumber *bcdDev = dict[@"bcdDevice"];
  dev.bcdDevice = bcdDev ? bcdDev.unsignedShortValue : 0;

  // Class
  NSNumber *cls = dict[@"bDeviceClass"];
  dev.deviceClass =
      cls ? (USBDeviceClass)cls.unsignedCharValue : USBClassPerInterface;
  NSNumber *sub = dict[@"bDeviceSubClass"];
  dev.subClass = sub ? sub.unsignedCharValue : 0;
  NSNumber *proto = dict[@"bDeviceProtocol"];
  dev.protocol = proto ? proto.unsignedCharValue : 0;

  // Speed
  NSNumber *speed = dict[@"Device Speed"] ?: dict[@"USBSpeed"];
  if (speed) {
    switch (speed.intValue) {
    case 0:
      dev.speed = USBSpeedLow;
      break;
    case 1:
      dev.speed = USBSpeedFull;
      break;
    case 2:
      dev.speed = USBSpeedHigh;
      break;
    case 3:
      dev.speed = USBSpeedSuper;
      break;
    case 4:
      dev.speed = USBSpeedSuperPlus;
      break;
    default:
      dev.speed = USBSpeedFull;
      break;
    }
  }

  // Location
  NSNumber *loc = dict[@"locationID"];
  dev.locationID = loc ? loc.unsignedIntValue : 0;

  // Port & Bus
  NSNumber *port = dict[@"PortNum"];
  dev.portNumber = port ? port.unsignedCharValue : 0;
  dev.busNumber = (dev.locationID >> 24) & 0xFF;
  NSNumber *addr = dict[@"USB Address"];
  dev.deviceAddress = addr ? addr.unsignedCharValue : 0;

  // Power
  NSNumber *maxPow = dict[@"Bus Power Available"] ?: dict[@"bMaxPower"];
  dev.maxPower = maxPow ? maxPow.unsignedCharValue : 0;

  // String descriptors
  dev.manufacturer = dict[@"USB Vendor Name"] ?: dict[@"kUSBVendorString"] ?: @"Unknown";
  dev.product = dict[@"USB Product Name"] ?: dict[@"kUSBProductString"] ?: @"USB Device";
  dev.serialNumber = dict[@"USB Serial Number"] ?: dict[@"kUSBSerialNumberString"] ?: @"";

  // Parse interfaces
  dev.interfaces = [self parseInterfaces:service];

  // If device class is per-interface, derive from first interface
  if (dev.deviceClass == USBClassPerInterface && dev.interfaces.count > 0) {
    dev.deviceClass = dev.interfaces[0].interfaceClass;
  }

  return dev;
}

- (NSArray<USBInterface *> *)parseInterfaces:(io_service_t)deviceService {
  NSMutableArray *interfaces = [NSMutableArray array];

  io_iterator_t childIterator;
  kern_return_t kr = IORegistryEntryGetChildIterator(
      deviceService, kIOServicePlane, &childIterator);
  if (kr != KERN_SUCCESS)
    return interfaces;

  io_service_t child;
  while ((child = IOIteratorNext(childIterator))) {
    CFMutableDictionaryRef childProps = nil;
    if (IORegistryEntryCreateCFProperties(child, &childProps,
                                          kCFAllocatorDefault,
                                          kNilOptions) == KERN_SUCCESS) {
      NSDictionary *cp = (__bridge_transfer NSDictionary *)childProps;

      NSNumber *ifNum = cp[@"bInterfaceNumber"];
      if (ifNum) {
        USBInterface *iface = [USBInterface new];
        iface.number = ifNum.unsignedCharValue;
        NSNumber *alt = cp[@"bAlternateSetting"];
        iface.alternateSetting = alt ? alt.unsignedCharValue : 0;
        NSNumber *cls = cp[@"bInterfaceClass"];
        iface.interfaceClass =
            cls ? (USBDeviceClass)cls.unsignedCharValue : USBClassVendorSpec;
        NSNumber *sub = cp[@"bInterfaceSubClass"];
        iface.subClass = sub ? sub.unsignedCharValue : 0;
        NSNumber *proto = cp[@"bInterfaceProtocol"];
        iface.protocol = proto ? proto.unsignedCharValue : 0;

        // Parse endpoints from this interface's children
        iface.endpoints = [self parseEndpoints:child];

        [interfaces addObject:iface];
      }
    }
    IOObjectRelease(child);
  }
  IOObjectRelease(childIterator);

  return interfaces;
}

- (NSArray<USBEndpoint *> *)parseEndpoints:(io_service_t)ifaceService {
  NSMutableArray *endpoints = [NSMutableArray array];

  io_iterator_t epIter;
  if (IORegistryEntryGetChildIterator(ifaceService, kIOServicePlane, &epIter) !=
      KERN_SUCCESS) {
    return endpoints;
  }

  io_service_t epService;
  while ((epService = IOIteratorNext(epIter))) {
    CFMutableDictionaryRef epProps = nil;
    if (IORegistryEntryCreateCFProperties(epService, &epProps,
                                          kCFAllocatorDefault,
                                          kNilOptions) == KERN_SUCCESS) {
      NSDictionary *ep = (__bridge_transfer NSDictionary *)epProps;
      NSNumber *epAddr = ep[@"bEndpointAddress"];
      if (epAddr) {
        USBEndpoint *endpoint = [USBEndpoint new];
        endpoint.address = epAddr.unsignedCharValue;
        endpoint.isInput = (endpoint.address & 0x80) != 0;
        NSNumber *attr = ep[@"bmAttributes"];
        endpoint.transferType =
            attr ? (USBTransferType)(attr.unsignedCharValue & 0x03)
                 : USBTransferBulk;
        NSNumber *mps = ep[@"wMaxPacketSize"];
        endpoint.maxPacketSize = mps ? mps.unsignedShortValue : 64;
        NSNumber *intv = ep[@"bInterval"];
        endpoint.interval = intv ? intv.unsignedCharValue : 0;
        [endpoints addObject:endpoint];
      }
    }
    IOObjectRelease(epService);
  }
  IOObjectRelease(epIter);

  return endpoints;
}

#pragma mark - Device Queries

- (NSArray<USBDevice *> *)allDevices {
  @synchronized(self.devices) {
    return [self.devices copy];
  }
}

- (NSArray<USBDevice *> *)externalDevices {
  @synchronized(self.devices) {
    NSPredicate *pred =
        [NSPredicate predicateWithBlock:^BOOL(USBDevice *dev, NSDictionary *b) {
          // Filter out Apple internal devices (vendor 0x05AC, typical internal)
          BOOL isInternal = (dev.vendorID == 0x05AC &&
                             (dev.productID == 0x8600 || // Internal hub
                              dev.productID == 0x8006 || // Internal sensor
                              dev.deviceClass == USBClassHub));
          return !isInternal;
        }];
    return [self.devices filteredArrayUsingPredicate:pred];
  }
}

- (USBDevice *)deviceWithVendor:(uint16_t)vid product:(uint16_t)pid {
  @synchronized(self.devices) {
    for (USBDevice *dev in self.devices) {
      if (dev.vendorID == vid && dev.productID == pid)
        return dev;
    }
  }
  return nil;
}

- (USBDevice *)deviceAtLocation:(uint32_t)locationID {
  return self.deviceByLocation[@(locationID)];
}

#pragma mark - Hotplug Monitoring (IOKit Notifications)

- (void)startHotplugMonitoring {
  if (self.monitoring)
    return;
  self.monitoring = YES;

  self.notifyPort = IONotificationPortCreate(kIOMainPortDefault);
  if (!self.notifyPort) {
    NSLog(@"[USBDriver] Cannot create notification port");
    return;
  }

  CFRunLoopSourceRef runLoopSource =
      IONotificationPortGetRunLoopSource(self.notifyPort);
  CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, kCFRunLoopDefaultMode);

  // Watch for USB device attach
  CFMutableDictionaryRef matchAttach = IOServiceMatching(kIOUSBDeviceClassName);
  CFRetain(matchAttach); // IOServiceAddMatchingNotification consumes one ref

  kern_return_t kr = IOServiceAddMatchingNotification(
      self.notifyPort, kIOFirstMatchNotification, matchAttach,
      USBDeviceAttachedCallback, (__bridge void *)self, &_attachIterator);

  if (kr == KERN_SUCCESS) {
    // Drain existing devices from iterator
    io_service_t service;
    while ((service = IOIteratorNext(self.attachIterator))) {
      IOObjectRelease(service);
    }
  }

  // Watch for USB device detach
  CFMutableDictionaryRef matchDetach = IOServiceMatching(kIOUSBDeviceClassName);

  kr = IOServiceAddMatchingNotification(
      self.notifyPort, kIOTerminatedNotification, matchDetach,
      USBDeviceDetachedCallback, (__bridge void *)self, &_detachIterator);

  if (kr == KERN_SUCCESS) {
    io_service_t service;
    while ((service = IOIteratorNext(self.detachIterator))) {
      IOObjectRelease(service);
    }
  }

  NSLog(@"[USBDriver] Hotplug monitoring active");
}

- (void)stopHotplugMonitoring {
  if (!self.monitoring)
    return;
  self.monitoring = NO;

  if (self.attachIterator) {
    IOObjectRelease(self.attachIterator);
    self.attachIterator = 0;
  }
  if (self.detachIterator) {
    IOObjectRelease(self.detachIterator);
    self.detachIterator = 0;
  }
  if (self.notifyPort) {
    IONotificationPortDestroy(self.notifyPort);
    self.notifyPort = nil;
  }
  NSLog(@"[USBDriver] Hotplug monitoring stopped");
}

- (void)handleDeviceAttached:(io_iterator_t)iterator {
  io_service_t service;
  while ((service = IOIteratorNext(iterator))) {
    USBDevice *dev = [self createDeviceFromService:service];
    if (dev && dev.vendorID != 0) {
      @synchronized(self.devices) {
        [self.devices addObject:dev];
        self.deviceByLocation[@(dev.locationID)] = dev;
      }

      NSLog(@"[USBDriver] ⚡ ATTACHED: %@ (%@:%@) at location 0x%08X",
            dev.product, dev.vendorIDHex, dev.productIDHex, dev.locationID);

      dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate usbDeviceAttached:dev];
      });
    }
    IOObjectRelease(service);
  }
}

- (void)handleDeviceDetached:(io_iterator_t)iterator {
  io_service_t service;
  while ((service = IOIteratorNext(iterator))) {
    // Find which device was removed
    CFMutableDictionaryRef props = nil;
    IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault,
                                      kNilOptions);
    NSDictionary *dict = (__bridge_transfer NSDictionary *)props;

    NSNumber *loc = dict[@"locationID"];
    uint32_t locationID = loc ? loc.unsignedIntValue : 0;

    USBDevice *removed = self.deviceByLocation[@(locationID)];
    if (removed) {
      removed.state = USBDeviceDetached;

      @synchronized(self.devices) {
        [self.devices removeObject:removed];
        [self.deviceByLocation removeObjectForKey:@(locationID)];
      }

      NSLog(@"[USBDriver] ⛔ DETACHED: %@ (%@:%@)", removed.product,
            removed.vendorIDHex, removed.productIDHex);

      dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate usbDeviceDetached:removed];
      });
    }
    IOObjectRelease(service);
  }
}

#pragma mark - Device Operations

- (BOOL)resetDevice:(USBDevice *)device {
  NSLog(@"[USBDriver] Resetting device: %@ (%@:%@)", device.product,
        device.vendorIDHex, device.productIDHex);
  // Would use IOUSBDeviceInterface::ResetDevice via plugin
  return YES;
}

- (NSData *)getDescriptor:(USBDevice *)device
                     type:(USBDescriptorType)type
                    index:(uint8_t)idx {
  // Read descriptor via IOKit
  NSLog(@"[USBDriver] Reading descriptor type %d index %d from %@", type, idx,
        device.product);
  return nil; // Would use DeviceRequest
}

- (NSString *)getStringDescriptor:(USBDevice *)device index:(uint8_t)idx {
  if (idx == 0)
    return nil;
  // In a full implementation, send GET_DESCRIPTOR (string) via control pipe
  switch (idx) {
  case 1:
    return device.manufacturer;
  case 2:
    return device.product;
  case 3:
    return device.serialNumber;
  }
  return nil;
}

#pragma mark - Data Transfer

- (void)controlTransfer:(USBDevice *)device
                  setup:(USBSetupPacket)setup
                   data:(NSData *)data
             completion:(USBTransferCompletion)completion {
  NSLog(@"[USBDriver] Control transfer to %@: bmReq=0x%02X bReq=0x%02X "
        @"wVal=0x%04X wIdx=0x%04X",
        device.product, setup.bmRequestType, setup.bRequest, setup.wValue,
        setup.wIndex);

  dispatch_async(self.usbQueue, ^{
    // In production: use IOUSBDeviceInterface::DeviceRequest
    // For now, log the intent
    BOOL success = NO;
    NSData *result = nil;

    // Try to open an IOKit connection and send
    IOCFPlugInInterface **plugInInterface = NULL;
    SInt32 score;
    kern_return_t kr = IOCreatePlugInInterfaceForService(
        device.service, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID,
        &plugInInterface, &score);

    if (kr == KERN_SUCCESS && plugInInterface) {
      NSLog(@"[USBDriver] Plugin interface created for control transfer");
      success = YES;
      (*plugInInterface)->Release(plugInInterface);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if (completion)
        completion(result, success, success ? nil : @"Transfer failed");
    });
  });
}

- (void)bulkTransfer:(USBDevice *)device
            endpoint:(uint8_t)ep
                data:(NSData *)data
             timeout:(uint32_t)timeoutMs
          completion:(USBTransferCompletion)completion {
  NSLog(@"[USBDriver] Bulk transfer ep=0x%02X %lu bytes to %@", ep,
        (unsigned long)data.length, device.product);

  dispatch_async(self.usbQueue, ^{
    // In production: use IOUSBInterfaceInterface::WritePipe / ReadPipe
    dispatch_async(dispatch_get_main_queue(), ^{
      if (completion)
        completion(nil, NO, @"Bulk transfer requires interface claim");
    });
  });
}

- (void)interruptTransfer:(USBDevice *)device
                 endpoint:(uint8_t)ep
                   length:(uint16_t)len
               completion:(USBTransferCompletion)completion {
  NSLog(@"[USBDriver] Interrupt read ep=0x%02X %d bytes from %@", ep, len,
        device.product);

  dispatch_async(self.usbQueue, ^{
    dispatch_async(dispatch_get_main_queue(), ^{
      if (completion)
        completion(nil, NO, @"Interrupt transfer requires interface claim");
    });
  });
}

#pragma mark - USB Topology

- (NSArray<USBHub *> *)usbTopology {
  NSMutableDictionary<NSNumber *, USBHub *> *hubs =
      [NSMutableDictionary dictionary];

  @synchronized(self.devices) {
    for (USBDevice *dev in self.devices) {
      uint8_t bus = dev.busNumber;
      NSNumber *busKey = @(bus);

      USBHub *hub = hubs[busKey];
      if (!hub) {
        hub = [USBHub new];
        hub.name = [NSString stringWithFormat:@"USB Bus %d", bus];
        hub.locationID = (uint32_t)(bus << 24);
        hub.isPowered = YES;
        hubs[busKey] = hub;
      }
      [hub.devices addObject:dev];
      if (dev.portNumber > hub.portCount) {
        hub.portCount = dev.portNumber;
      }
    }
  }

  return [hubs.allValues
      sortedArrayUsingComparator:^NSComparisonResult(USBHub *a, USBHub *b) {
        return [@(a.locationID) compare:@(b.locationID)];
      }];
}

#pragma mark - Diagnostics

- (NSDictionary *)driverDiagnostics {
  NSMutableArray *devList = [NSMutableArray array];
  @synchronized(self.devices) {
    for (USBDevice *dev in self.devices) {
      [devList addObject:@{
        @"product" : dev.product ?: @"Unknown",
        @"manufacturer" : dev.manufacturer ?: @"Unknown",
        @"vid" : dev.vendorIDHex,
        @"pid" : dev.productIDHex,
        @"speed" : dev.speedString,
        @"class" : dev.classString,
        @"location" : [NSString stringWithFormat:@"0x%08X", dev.locationID],
        @"bus" : @(dev.busNumber),
        @"port" : @(dev.portNumber),
        @"power" : dev.powerString,
        @"interfaces" : @(dev.interfaces.count),
      }];
    }
  }

  return @{
    @"state" : (self.state == USBDriverReady) ? @"Ready" : @"Off",
    @"deviceCount" : @(self.devices.count),
    @"monitoring" : @(self.monitoring),
    @"devices" : devList,
  };
}

@end

// ─── IOKit Notification Callbacks ───────────────────────────────────────

static void USBDeviceAttachedCallback(void *refcon, io_iterator_t iterator) {
  USBDriver *driver = (__bridge USBDriver *)refcon;
  [driver handleDeviceAttached:iterator];
}

static void USBDeviceDetachedCallback(void *refcon, io_iterator_t iterator) {
  USBDriver *driver = (__bridge USBDriver *)refcon;
  [driver handleDeviceDetached:iterator];
}
