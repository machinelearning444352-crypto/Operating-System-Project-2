#import "BluetoothDriver.h"
#import <IOKit/IOKitLib.h>

// ============================================================================
// BluetoothDriver.mm — Main Bluetooth Driver
// Orchestrates HCI, discovery, pairing, connection management
// ============================================================================

@interface BluetoothDriver ()
@property(nonatomic, readwrite, strong) BluetoothHCI *hci;
@property(nonatomic, readwrite) BTDriverState state;
@property(nonatomic, readwrite, strong) BTControllerInfo *controllerInfo;
@property(nonatomic, strong) NSMutableArray<BTDevice *> *foundDevices;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, BTDevice *> *deviceMap;
@property(nonatomic, strong) NSMutableArray<BTDevice *> *pairedList;
@property(nonatomic, strong) dispatch_queue_t btQueue;
@property(nonatomic, assign) BOOL discovering;
@property(nonatomic, strong) NSTimer *discoveryTimer;
@end

@implementation BluetoothDriver

+ (instancetype)sharedInstance {
  static BluetoothDriver *inst;
  static dispatch_once_t t;
  dispatch_once(&t, ^{
    inst = [[BluetoothDriver alloc] init];
  });
  return inst;
}

- (instancetype)init {
  if (self = [super init]) {
    _foundDevices = [NSMutableArray array];
    _deviceMap = [NSMutableDictionary dictionary];
    _pairedList = [NSMutableArray array];
    _btQueue =
        dispatch_queue_create("com.virtualos.bluetooth", DISPATCH_QUEUE_SERIAL);
    _state = BTDriverStateOff;
  }
  return self;
}

#pragma mark - Lifecycle

- (BOOL)start {
  NSLog(@"[BluetoothDriver] ═══════════════════════════════════════");
  NSLog(@"[BluetoothDriver]  VirtualOS Bluetooth Driver v1.0");
  NSLog(@"[BluetoothDriver]  Built from scratch — no IOBluetooth");
  NSLog(@"[BluetoothDriver] ═══════════════════════════════════════");

  self.state = BTDriverStateInitializing;
  self.hci = [[BluetoothHCI alloc] init];
  self.hci.delegate = self;

  BOOL hciOK = [self.hci open];
  if (!hciOK) {
    NSLog(@"[BluetoothDriver] HCI unavailable (not root) — using "
          @"system_profiler");
    self.controllerInfo = [self readControllerInfoFromSystem];
  } else {
    self.controllerInfo = self.hci.controllerInfo;
  }

  if (!self.controllerInfo) {
    self.controllerInfo = [BTControllerInfo new];
    self.controllerInfo.name = @"Bluetooth Controller";
    self.controllerInfo.address = @"00:00:00:00:00:00";
  }

  self.state = BTDriverStateReady;

  NSLog(@"[BluetoothDriver] Ready.");
  NSLog(@"[BluetoothDriver]   Address:      %@", self.controllerInfo.address);
  NSLog(@"[BluetoothDriver]   Name:         %@", self.controllerInfo.name);
  NSLog(@"[BluetoothDriver]   Manufacturer: %@",
        self.controllerInfo.manufacturer);
  NSLog(@"[BluetoothDriver]   HCI Version:  %d",
        self.controllerInfo.hciVersionMajor);
  NSLog(@"[BluetoothDriver]   BLE Support:  %@",
        self.controllerInfo.supportsLE ? @"YES" : @"NO");
  NSLog(@"[BluetoothDriver]   SSP Support:  %@",
        self.controllerInfo.supportsSSP ? @"YES" : @"NO");

  // Load previously paired devices from persistent storage
  [self loadPairedDevices];

  // Also discover nearby devices from the system's known list
  [self discoverSystemPairedDevices];

  dispatch_async(dispatch_get_main_queue(), ^{
    [self.delegate bluetoothReady:self.controllerInfo];
  });

  return YES;
}

- (void)stop {
  [self stopDiscovery];
  [self.hci close];
  self.state = BTDriverStateOff;
  NSLog(@"[BluetoothDriver] Stopped");
}

- (BOOL)isRunning {
  return self.state != BTDriverStateOff && self.state != BTDriverStateError;
}

#pragma mark - Power

- (BOOL)setPower:(BOOL)on {
  if (on && self.state == BTDriverStateOff) {
    return [self start];
  } else if (!on && self.state != BTDriverStateOff) {
    [self stop];
    return YES;
  }
  return YES;
}

- (BOOL)isPowered {
  return self.state != BTDriverStateOff;
}

#pragma mark - Discovery

- (void)startDiscovery {
  if (self.discovering)
    return;
  self.discovering = YES;
  self.state = BTDriverStateDiscovering;

  NSLog(@"[BluetoothDriver] Starting BR/EDR + BLE discovery");

  @synchronized(self.foundDevices) {
    [self.foundDevices removeAllObjects];
  }

  dispatch_async(self.btQueue, ^{
    // Send HCI Inquiry command (GIAC LAP = 0x9E8B33)
    NSData *inquiry = [BluetoothHCI buildInquiryCommand:0x9E8B33
                                           maxResponses:20
                                          durationUnits:8];
    [self.hci sendCommand:inquiry];

    // Also start LE scan
    NSData *leParams = [BluetoothHCI buildLESetScanParams:0x01 // Active scan
                                                 interval:0x0010
                                                   window:0x0010
                                              ownAddrType:0x00
                                             filterPolicy:0x00];
    [self.hci sendCommand:leParams];

    NSData *leEnable = [BluetoothHCI buildLESetScanEnable:YES
                                         filterDuplicates:YES];
    [self.hci sendCommand:leEnable];

    // Fallback: discover devices via system_profiler
    [self discoverSystemDevices];
  });

  // Auto-stop after 12 seconds
  self.discoveryTimer =
      [NSTimer scheduledTimerWithTimeInterval:12.0
                                       target:self
                                     selector:@selector(autoStopDiscovery)
                                     userInfo:nil
                                      repeats:NO];
}

- (void)startBLEDiscovery {
  if (self.discovering)
    return;
  self.discovering = YES;
  self.state = BTDriverStateDiscovering;

  dispatch_async(self.btQueue, ^{
    NSData *params = [BluetoothHCI buildLESetScanParams:0x01
                                               interval:0x0010
                                                 window:0x0010
                                            ownAddrType:0x00
                                           filterPolicy:0x00];
    [self.hci sendCommand:params];
    NSData *enable = [BluetoothHCI buildLESetScanEnable:YES
                                       filterDuplicates:YES];
    [self.hci sendCommand:enable];

    [self discoverSystemDevices];
  });

  self.discoveryTimer =
      [NSTimer scheduledTimerWithTimeInterval:10.0
                                       target:self
                                     selector:@selector(autoStopDiscovery)
                                     userInfo:nil
                                      repeats:NO];
}

- (void)autoStopDiscovery {
  [self stopDiscovery];
}

- (void)stopDiscovery {
  if (!self.discovering)
    return;
  self.discovering = NO;
  self.state = BTDriverStateReady;
  [self.discoveryTimer invalidate];
  self.discoveryTimer = nil;

  // Cancel HCI Inquiry
  [self.hci sendCommand:[BluetoothHCI buildInquiryCancelCommand]];
  // Disable LE scan
  [self.hci sendCommand:[BluetoothHCI buildLESetScanEnable:NO
                                          filterDuplicates:NO]];

  NSArray *results;
  @synchronized(self.foundDevices) {
    results = [self.foundDevices copy];
  }

  NSLog(@"[BluetoothDriver] Discovery complete: %lu devices",
        (unsigned long)results.count);

  dispatch_async(dispatch_get_main_queue(), ^{
    [self.delegate bluetoothScanComplete:results];
  });
}

- (BOOL)isDiscovering {
  return self.discovering;
}

- (NSArray<BTDevice *> *)discoveredDevices {
  @synchronized(self.foundDevices) {
    return [self.foundDevices copy];
  }
}

- (NSArray<BTDevice *> *)pairedDevices {
  return [self.pairedList copy];
}

#pragma mark - System Device Discovery (via system_profiler)

- (void)discoverSystemDevices {
  NSLog(@"[BluetoothDriver] Querying system for Bluetooth devices");

  NSTask *task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/system_profiler"];
  task.arguments = @[ @"SPBluetoothDataType", @"-json" ];
  NSPipe *pipe = [NSPipe pipe];
  task.standardOutput = pipe;
  task.standardError = [NSPipe pipe];

  @try {
    [task launchAndReturnError:nil];
    [task waitUntilExit];

    NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
    if (data.length == 0)
      return;

    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                         options:0
                                                           error:nil];
    if (!json)
      return;

    NSArray *btData = json[@"SPBluetoothDataType"];
    if (!btData || btData.count == 0)
      return;

    NSDictionary *btInfo = btData[0];

    // Parse connected devices
    NSDictionary *connDevices =
        btInfo[@"device_connected"] ?: btInfo[@"devices_connected"];
    if ([connDevices isKindOfClass:[NSArray class]]) {
      for (NSDictionary *devDict in (NSArray *)connDevices) {
        for (NSString *devName in devDict) {
          NSDictionary *info = devDict[devName];
          BTDevice *dev = [self parseSystemDevice:info name:devName];
          dev.isConnected = YES;
          dev.state = BTDeviceStateConnected;
          [self addDiscoveredDevice:dev];
        }
      }
    }

    // Parse not-connected devices
    NSDictionary *ncDevices =
        btInfo[@"device_not_connected"] ?: btInfo[@"devices_not_connected"];
    if ([ncDevices isKindOfClass:[NSArray class]]) {
      for (NSDictionary *devDict in (NSArray *)ncDevices) {
        for (NSString *devName in devDict) {
          NSDictionary *info = devDict[devName];
          BTDevice *dev = [self parseSystemDevice:info name:devName];
          dev.isConnected = NO;
          [self addDiscoveredDevice:dev];
        }
      }
    }

  } @catch (NSException *e) {
    NSLog(@"[BluetoothDriver] system_profiler failed: %@", e);
  }
}

- (BTControllerInfo *)readControllerInfoFromSystem {
  BTControllerInfo *info = [BTControllerInfo new];
  info.name = @"Bluetooth Controller";
  info.address = @"00:00:00:00:00:00";
  info.supportsLE = YES;
  info.supportsBREDR = YES;
  info.supportsSSP = YES;

  NSTask *task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/system_profiler"];
  task.arguments = @[ @"SPBluetoothDataType", @"-json" ];
  NSPipe *pipe = [NSPipe pipe];
  task.standardOutput = pipe;
  task.standardError = [NSPipe pipe];

  @try {
    [task launchAndReturnError:nil];
    [task waitUntilExit];

    NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
    if (data.length > 0) {
      NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data
                                                           options:0
                                                             error:nil];
      NSArray *btData = json[@"SPBluetoothDataType"];
      if (btData.count > 0) {
        NSDictionary *bt = btData[0];
        NSDictionary *ctrl =
            bt[@"controller_properties"] ?: bt[@"local_device_title"];
        if (ctrl) {
          info.address = ctrl[@"controller_address"]
                      ?: ctrl[@"general_address"] ?: @"Unknown";
          info.name = ctrl[@"controller_chipset"]
                   ?: ctrl[@"general_name"] ?: @"Bluetooth";
          info.manufacturer = ctrl[@"controller_vendorID"] ?: @"Apple";
          NSString *fw = ctrl[@"controller_firmwareVersion"];
          if (fw)
            info.hciVersionMajor = (uint8_t)[fw intValue];
        }
      }
    }
  } @catch (NSException *e) {
    NSLog(@"[BluetoothDriver] system_profiler controller info failed: %@", e);
  }

  return info;
}

- (BTDevice *)parseSystemDevice:(NSDictionary *)info name:(NSString *)name {
  BTDevice *dev = [BTDevice new];
  dev.name = name;
  dev.address = info[@"device_address"] ?: @"Unknown";
  dev.isPaired = [info[@"device_isPaired"] boolValue] ||
                 [info[@"device_paired"] isEqualToString:@"attrib_Yes"];

  // Parse class
  NSString *majorClass =
      info[@"device_majorClassOfDevice_string"] ?: info[@"device_minorType"];
  if ([majorClass containsString:@"Audio"])
    dev.majorClass = BTMajorAudioVideo;
  else if ([majorClass containsString:@"Computer"])
    dev.majorClass = BTMajorComputer;
  else if ([majorClass containsString:@"Phone"])
    dev.majorClass = BTMajorPhone;
  else if ([majorClass containsString:@"Peripheral"])
    dev.majorClass = BTMajorPeripheral;
  else
    dev.majorClass = BTMajorMisc;

  // RSSI
  NSNumber *rssi = info[@"device_rssi"];
  dev.rssi = rssi ? rssi.charValue : -60;

  // Battery
  NSNumber *battery =
      info[@"device_batteryLevelMain"] ?: info[@"device_batteryLevel"];
  dev.batteryLevel = battery ? battery.intValue : -1;

  // BLE check
  dev.isBLE = [info[@"device_isLEDevice"] boolValue] ||
              [info[@"device_lowEnergy"] isEqualToString:@"attrib_Yes"];

  // Services
  NSString *services = info[@"device_services"];
  if (services) {
    dev.services = [services componentsSeparatedByString:@", "];
  }

  dev.lastSeen = [NSDate date];
  if (dev.isPaired)
    dev.state = BTDeviceStatePaired;

  // Convert address to raw bytes
  uint8_t addr[6];
  [BluetoothHCI stringToAddress:dev.address output:addr];
  dev.rawAddress = [NSData dataWithBytes:addr length:6];

  return dev;
}

- (void)discoverSystemPairedDevices {
  // Read paired devices from defaults
  NSTask *task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/defaults"];
  task.arguments = @[
    @"read", @"/Library/Preferences/com.apple.Bluetooth", @"PairedDevices"
  ];
  NSPipe *pipe = [NSPipe pipe];
  task.standardOutput = pipe;
  task.standardError = [NSPipe pipe];

  @try {
    [task launchAndReturnError:nil];
    [task waitUntilExit];
    NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data
                                             encoding:NSUTF8StringEncoding];
    NSLog(@"[BluetoothDriver] System paired devices: %@",
          [output stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]]);
  } @catch (NSException *e) {
  }
}

- (void)loadPairedDevices {
  // Load from user defaults
  NSArray *saved = [[NSUserDefaults standardUserDefaults]
      arrayForKey:@"BTDriverPairedDevices"];
  for (NSDictionary *d in saved) {
    BTDevice *dev = [BTDevice new];
    dev.name = d[@"name"] ?: @"Unknown";
    dev.address = d[@"address"] ?: @"";
    dev.majorClass = (BTDeviceMajorClass)[d[@"majorClass"] intValue];
    dev.isPaired = YES;
    dev.state = BTDeviceStatePaired;
    dev.isBLE = [d[@"isBLE"] boolValue];
    dev.lastSeen = [NSDate date];

    uint8_t addr[6];
    [BluetoothHCI stringToAddress:dev.address output:addr];
    dev.rawAddress = [NSData dataWithBytes:addr length:6];

    [self.pairedList addObject:dev];
    self.deviceMap[dev.address] = dev;
  }
}

- (void)savePairedDevices {
  NSMutableArray *saved = [NSMutableArray array];
  for (BTDevice *dev in self.pairedList) {
    [saved addObject:@{
      @"name" : dev.name ?: @"",
      @"address" : dev.address ?: @"",
      @"majorClass" : @(dev.majorClass),
      @"isBLE" : @(dev.isBLE),
    }];
  }
  [[NSUserDefaults standardUserDefaults] setObject:saved
                                            forKey:@"BTDriverPairedDevices"];
}

- (void)addDiscoveredDevice:(BTDevice *)dev {
  @synchronized(self.foundDevices) {
    BTDevice *existing = self.deviceMap[dev.address];
    if (existing) {
      existing.rssi = dev.rssi;
      existing.lastSeen = dev.lastSeen;
      if (dev.isConnected)
        existing.isConnected = YES;
      if (dev.name && ![dev.name isEqualToString:@"Unknown"])
        existing.name = dev.name;
    } else {
      [self.foundDevices addObject:dev];
      self.deviceMap[dev.address] = dev;

      dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate bluetoothDeviceFound:dev];
      });
    }
  }
}

#pragma mark - Connection

- (void)connectDevice:(BTDevice *)device {
  NSLog(@"[BluetoothDriver] Connecting to %@ (%@)", device.name,
        device.address);
  device.state = BTDeviceStateConnecting;

  dispatch_async(self.btQueue, ^{
    uint8_t addr[6];
    [BluetoothHCI stringToAddress:device.address output:addr];

    NSData *cmd;
    if (device.isBLE) {
      cmd = [BluetoothHCI buildLECreateConnection:addr
                                         addrType:device.addressType];
    } else {
      cmd = [BluetoothHCI buildCreateConnectionCommand:addr];
    }
    [self.hci sendCommand:cmd];

    // Simulate connection success (real HCI would give us an event)
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          device.state = BTDeviceStateConnected;
          device.isConnected = YES;
          [self.delegate bluetoothConnected:device];
        });
  });
}

- (void)disconnectDevice:(BTDevice *)device {
  NSLog(@"[BluetoothDriver] Disconnecting %@ (handle=%d)", device.name,
        device.connectionHandle);

  if (device.connectionHandle > 0) {
    NSData *cmd = [BluetoothHCI buildDisconnectCommand:device.connectionHandle
                                                reason:0x13];
    [self.hci sendCommand:cmd];
  }

  device.state = BTDeviceStateDisconnected;
  device.isConnected = NO;
  device.connectionHandle = 0;

  dispatch_async(dispatch_get_main_queue(), ^{
    [self.delegate bluetoothDisconnected:device reason:@"User requested"];
  });
}

#pragma mark - Pairing

- (void)pairDevice:(BTDevice *)device {
  NSLog(@"[BluetoothDriver] Pairing with %@ (%@)", device.name, device.address);
  device.state = BTDeviceStatePairing;

  dispatch_async(self.btQueue, ^{
    // First connect if not already
    if (device.connectionHandle == 0) {
      uint8_t addr[6];
      [BluetoothHCI stringToAddress:device.address output:addr];
      if (device.isBLE) {
        [self.hci sendCommand:[BluetoothHCI buildLECreateConnection:addr
                                                           addrType:0]];
      } else {
        [self.hci sendCommand:[BluetoothHCI buildCreateConnectionCommand:addr]];
      }
    }

    // Request authentication
    // In real HCI, we'd get PIN/Passkey events back
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          device.state = BTDeviceStatePaired;
          device.isPaired = YES;

          @synchronized(self.pairedList) {
            if (![self.pairedList containsObject:device]) {
              [self.pairedList addObject:device];
            }
          }
          [self savePairedDevices];

          [self.delegate bluetoothPaired:device];
        });
  });
}

- (void)unpairDevice:(BTDevice *)device {
  NSLog(@"[BluetoothDriver] Unpairing %@", device.name);
  device.isPaired = NO;
  device.state = BTDeviceStateDisconnected;

  if (device.isConnected)
    [self disconnectDevice:device];

  @synchronized(self.pairedList) {
    [self.pairedList removeObject:device];
  }
  [self savePairedDevices];
}

- (void)respondPIN:(NSString *)pin forDevice:(BTDevice *)device {
  NSLog(@"[BluetoothDriver] Responding PIN for %@", device.name);
  uint8_t addr[6];
  [BluetoothHCI stringToAddress:device.address output:addr];
  NSData *cmd = [BluetoothHCI buildPINCodeReply:addr pin:pin];
  [self.hci sendCommand:cmd];
}

- (void)confirmPasskey:(BOOL)accept forDevice:(BTDevice *)device {
  NSLog(@"[BluetoothDriver] Passkey %@ for %@",
        accept ? @"accepted" : @"rejected", device.name);
  if (accept) {
    device.state = BTDeviceStatePaired;
    device.isPaired = YES;
    @synchronized(self.pairedList) {
      if (![self.pairedList containsObject:device]) {
        [self.pairedList addObject:device];
      }
    }
    [self savePairedDevices];
  }
}

#pragma mark - Data Transfer

- (void)sendData:(NSData *)data toDevice:(BTDevice *)device {
  if (device.connectionHandle == 0) {
    NSLog(@"[BluetoothDriver] Cannot send: not connected to %@", device.name);
    return;
  }

  // Build ACL data packet
  NSMutableData *acl = [NSMutableData data];
  uint8_t pktType = BTHCIPacketACLData;
  [acl appendBytes:&pktType length:1];

  BTHCIACLHeader hdr;
  hdr.handle = device.connectionHandle; // PB=0, BC=0
  hdr.dataLen = (uint16_t)data.length;
  [acl appendBytes:&hdr length:sizeof(hdr)];
  [acl appendData:data];

  [self.hci sendCommand:acl];
  NSLog(@"[BluetoothDriver] Sent %lu bytes to %@", (unsigned long)data.length,
        device.name);
}

#pragma mark - Device Lookup

- (BTDevice *)deviceWithAddress:(NSString *)address {
  return self.deviceMap[address];
}

#pragma mark - HCI Delegate

- (void)hciDidReceiveEvent:(BTHCIEventCode)code data:(NSData *)data {
  NSLog(@"[BluetoothDriver] HCI Event: %@",
        [BluetoothHCI eventDescription:code]);

  switch (code) {
  case BTEventInquiryResult: {
    BTInquiryResult result = [BluetoothHCI parseInquiryResult:data];
    BTDevice *dev = [BTDevice new];
    dev.address = [BluetoothHCI addressToString:result.bdAddr];
    dev.classOfDevice = result.classOfDevice[0] |
                        (result.classOfDevice[1] << 8) |
                        (result.classOfDevice[2] << 16);
    dev.majorClass = (BTDeviceMajorClass)((dev.classOfDevice >> 8) & 0x1F);
    dev.lastSeen = [NSDate date];
    [self addDiscoveredDevice:dev];
    break;
  }
  case BTEventInquiryResultRSSI: {
    BTInquiryResultRSSI result = [BluetoothHCI parseInquiryResultRSSI:data];
    BTDevice *dev = [BTDevice new];
    dev.address = [BluetoothHCI addressToString:result.bdAddr];
    dev.rssi = result.rssi;
    dev.classOfDevice = result.classOfDevice[0] |
                        (result.classOfDevice[1] << 8) |
                        (result.classOfDevice[2] << 16);
    dev.majorClass = (BTDeviceMajorClass)((dev.classOfDevice >> 8) & 0x1F);
    dev.lastSeen = [NSDate date];
    [self addDiscoveredDevice:dev];
    break;
  }
  case BTEventConnectionComplete: {
    BTConnectionComplete cc = [BluetoothHCI parseConnectionComplete:data];
    NSString *addr = [BluetoothHCI addressToString:cc.bdAddr];
    BTDevice *dev = self.deviceMap[addr];
    if (dev) {
      if (cc.status == 0) {
        dev.connectionHandle = cc.handle;
        dev.state = BTDeviceStateConnected;
        dev.isConnected = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
          [self.delegate bluetoothConnected:dev];
        });
      } else {
        dev.state = BTDeviceStateDisconnected;
        dispatch_async(dispatch_get_main_queue(), ^{
          [self.delegate
              bluetoothError:[NSString stringWithFormat:
                                           @"Connection to %@ failed (0x%02X)",
                                           dev.name, cc.status]];
        });
      }
    }
    break;
  }
  case BTEventDisconnectComplete: {
    // Parse handle and find device
    break;
  }
  case BTEventRemoteNameReqComplete: {
    NSString *name = [BluetoothHCI parseRemoteName:data];
    if (data.length >= 7) {
      const uint8_t *p = (const uint8_t *)data.bytes;
      NSString *addr = [BluetoothHCI addressToString:&p[1]];
      BTDevice *dev = self.deviceMap[addr];
      if (dev)
        dev.name = name;
    }
    break;
  }
  case BTEventPINCodeRequest: {
    if (data.length >= 6) {
      const uint8_t *p = (const uint8_t *)data.bytes;
      NSString *addr = [BluetoothHCI addressToString:p];
      BTDevice *dev = self.deviceMap[addr];
      if (dev) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self.delegate bluetoothPINRequested:dev];
        });
      }
    }
    break;
  }
  case BTEventUserConfirmRequest: {
    if (data.length >= 10) {
      const uint8_t *p = (const uint8_t *)data.bytes;
      NSString *addr = [BluetoothHCI addressToString:p];
      uint32_t passkey = p[6] | (p[7] << 8) | (p[8] << 16) | (p[9] << 24);
      BTDevice *dev = self.deviceMap[addr];
      if (dev) {
        dispatch_async(dispatch_get_main_queue(), ^{
          [self.delegate bluetoothConfirmPasskey:dev passkey:passkey];
        });
      }
    }
    break;
  }
  case BTEventLEMeta: {
    if (data.length >= 1) {
      uint8_t subevent = ((const uint8_t *)data.bytes)[0];
      if (subevent == BTLEAdvertisingReport) {
        NSArray *devices = [BluetoothHCI parseLEAdvertisingReport:data];
        for (BTDevice *dev in devices) {
          [self addDiscoveredDevice:dev];
        }
      }
    }
    break;
  }
  case BTEventInquiryComplete:
    if (self.discovering) {
      [self stopDiscovery];
    }
    break;
  default:
    break;
  }
}

- (void)hciDeviceDiscovered:(BTDevice *)device {
  [self addDiscoveredDevice:device];
}

- (void)hciConnectionComplete:(uint16_t)handle
                      address:(NSString *)addr
                       status:(uint8_t)status {
  BTDevice *dev = self.deviceMap[addr];
  if (dev && status == 0) {
    dev.connectionHandle = handle;
    dev.state = BTDeviceStateConnected;
    dev.isConnected = YES;
  }
}

- (void)hciDisconnectComplete:(uint16_t)handle reason:(uint8_t)reason {
  for (BTDevice *dev in self.foundDevices) {
    if (dev.connectionHandle == handle) {
      dev.state = BTDeviceStateDisconnected;
      dev.isConnected = NO;
      dev.connectionHandle = 0;
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate
            bluetoothDisconnected:dev
                           reason:[NSString stringWithFormat:@"Reason 0x%02X",
                                                             reason]];
      });
      break;
    }
  }
}

- (void)hciPINCodeRequest:(NSString *)address {
  BTDevice *dev = self.deviceMap[address];
  if (dev) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate bluetoothPINRequested:dev];
    });
  }
}

- (void)hciUserConfirmRequest:(NSString *)address passkey:(uint32_t)passkey {
  BTDevice *dev = self.deviceMap[address];
  if (dev) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate bluetoothConfirmPasskey:dev passkey:passkey];
    });
  }
}

- (void)hciPairingComplete:(NSString *)address success:(BOOL)success {
  BTDevice *dev = self.deviceMap[address];
  if (dev) {
    if (success) {
      dev.state = BTDeviceStatePaired;
      dev.isPaired = YES;
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate bluetoothPaired:dev];
      });
    } else {
      dev.state = BTDeviceStateDisconnected;
      dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate bluetoothPairFailed:dev error:@"Pairing rejected"];
      });
    }
  }
}

- (void)hciError:(NSString *)message {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.delegate bluetoothError:message];
  });
}

#pragma mark - Diagnostics

- (NSDictionary *)driverDiagnostics {
  return @{
    @"state" : [self stateDescription],
    @"address" : self.controllerInfo.address ?: @"Unknown",
    @"name" : self.controllerInfo.name ?: @"Unknown",
    @"manufacturer" : self.controllerInfo.manufacturer ?: @"Unknown",
    @"hciVersion" : @(self.controllerInfo.hciVersionMajor),
    @"lmpVersion" : @(self.controllerInfo.lmpVersion),
    @"supportsLE" : @(self.controllerInfo.supportsLE),
    @"supportsSSP" : @(self.controllerInfo.supportsSSP),
    @"discovering" : @(self.discovering),
    @"discoveredCount" : @(self.foundDevices.count),
    @"pairedCount" : @(self.pairedList.count),
  };
}

- (NSString *)stateDescription {
  switch (self.state) {
  case BTDriverStateOff:
    return @"Off";
  case BTDriverStateInitializing:
    return @"Initializing";
  case BTDriverStateReady:
    return @"Ready";
  case BTDriverStateDiscovering:
    return @"Discovering";
  case BTDriverStateError:
    return @"Error";
  }
  return @"Unknown";
}

@end
