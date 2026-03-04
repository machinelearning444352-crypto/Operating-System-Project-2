#import "WiFiDriver.h"

// ============================================================================
// WiFiDriver.mm — Main WiFi Driver Orchestrator
// Coordinates HAL, Scanner, 802.11 Protocol, and Connection Manager
// ============================================================================

@interface WiFiDriver ()
@property(nonatomic, readwrite, strong) WiFiHAL *hal;
@property(nonatomic, readwrite, strong) WiFiScanner *scanner;
@property(nonatomic, readwrite, strong) WiFiConnection *connection;
@property(nonatomic, readwrite) WiFiDriverState state;
@property(nonatomic, strong) NSTimer *signalMonitor;
@property(nonatomic, strong) NSTimer *throughputMonitor;
@property(nonatomic, assign) uint64_t prevTxBytes;
@property(nonatomic, assign) uint64_t prevRxBytes;
@end

@implementation WiFiDriver

+ (instancetype)sharedInstance {
  static WiFiDriver *inst;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    inst = [[WiFiDriver alloc] init];
  });
  return inst;
}

- (instancetype)init {
  if (self = [super init]) {
    _hal = [[WiFiHAL alloc] init];
    _hal.delegate = self;
    _state = WiFiDriverStateUninitialized;
  }
  return self;
}

#pragma mark - Lifecycle

- (BOOL)start {
  NSLog(@"[WiFiDriver] ═══════════════════════════════════════");
  NSLog(@"[WiFiDriver]  VirtualOS WiFi Driver v1.0");
  NSLog(@"[WiFiDriver]  Built from scratch — no CoreWLAN");
  NSLog(@"[WiFiDriver] ═══════════════════════════════════════");

  if (![self.hal initialize]) {
    self.state = WiFiDriverStateError;
    return NO;
  }

  self.scanner = [[WiFiScanner alloc] initWithHAL:self.hal];
  self.scanner.delegate = self;

  self.connection = [[WiFiConnection alloc] initWithHAL:self.hal];
  self.connection.delegate = self;

  self.state = WiFiDriverStateInitialized;

  NSLog(@"[WiFiDriver] Driver started successfully");
  NSLog(@"[WiFiDriver]   Interface: %@", self.hal.interfaceName);
  NSLog(@"[WiFiDriver]   Chipset:   %@", self.hal.chipsetName);
  NSLog(@"[WiFiDriver]   MAC:       %@", self.hal.hardwareAddress);
  NSLog(@"[WiFiDriver]   Powered:   %@", self.hal.isPowered ? @"YES" : @"NO");

  dispatch_async(dispatch_get_main_queue(), ^{
    [self.delegate wifiDriverReady:self.hal.interfaceName
                           chipset:self.hal.chipsetName];
  });

  return YES;
}

- (void)stop {
  [self.signalMonitor invalidate];
  [self.throughputMonitor invalidate];
  [self.scanner stopScan];
  [self.connection disconnect];
  [self.hal shutdown];
  self.state = WiFiDriverStateUninitialized;
  NSLog(@"[WiFiDriver] Driver stopped");
}

- (BOOL)isRunning {
  return self.state != WiFiDriverStateUninitialized &&
         self.state != WiFiDriverStateError;
}

#pragma mark - Power

- (BOOL)setPower:(BOOL)on {
  BOOL result = [self.hal setPower:on];
  if (result) {
    self.state = on ? WiFiDriverStateInitialized : WiFiDriverStatePoweredOff;
  }
  return result;
}

- (BOOL)isPowered {
  return self.hal.isPowered;
}

#pragma mark - Scanning

- (void)scanForNetworks {
  if (self.scanner.isScanning)
    return;
  self.state = WiFiDriverStateScanning;
  [self.scanner startFullScan];
}

- (void)scanForNetworksOnBand:(WiFiBand)band {
  NSArray *channels;
  switch (band) {
  case WiFiBand_2_4GHz:
    channels = @[ @1, @2, @3, @4, @5, @6, @7, @8, @9, @10, @11 ];
    break;
  case WiFiBand_5GHz:
    channels = @[
      @36,  @40,  @44,  @48,  @52,  @56,  @60,  @64,  @100, @104, @108, @112,
      @116, @120, @124, @128, @132, @136, @140, @149, @153, @157, @161, @165
    ];
    break;
  case WiFiBand_6GHz:
    channels = @[ @1001, @1005, @1009, @1013, @1017, @1021, @1025 ];
    break;
  }
  self.state = WiFiDriverStateScanning;
  [self.scanner startActiveScan:channels dwellTimeMs:120];
}

- (NSArray<WiFiScanResult *> *)cachedScanResults {
  return self.scanner.lastResults;
}

#pragma mark - Connection

- (void)connectToNetwork:(NSString *)ssid password:(NSString *)password {
  WiFiScanResult *network = [self.scanner findNetwork:ssid];
  if (!network) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate
          wifiError:[NSString stringWithFormat:
                                  @"Network '%@' not found. Run a scan first.",
                                  ssid]];
    });
    return;
  }
  [self.connection connectToNetwork:network password:password];
}

- (void)connectToOpenNetwork:(NSString *)ssid {
  WiFiScanResult *network = [self.scanner findNetwork:ssid];
  if (!network) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate
          wifiError:[NSString
                        stringWithFormat:@"Network '%@' not found.", ssid]];
    });
    return;
  }
  [self.connection connectToOpenNetwork:network];
}

- (void)disconnect {
  [self stopMonitoring];
  [self.connection disconnect];
}

- (BOOL)isConnected {
  return self.connection.state == WiFiDriverStateConnected;
}

- (WiFiConnectionState *)connectionInfo {
  return [self.connection getConnectionInfo];
}

- (NSString *)currentSSID {
  return self.connection.targetNetwork.ssid;
}

#pragma mark - Network Info

- (WiFiInterfaceInfo *)interfaceInfo {
  return [self.hal queryInterfaceInfo];
}

- (NSString *)localIP {
  return [self.hal queryInterfaceInfo].ipv4;
}

- (NSString *)gateway {
  return [self.hal getDefaultGateway];
}

- (NSArray<NSString *> *)dns {
  return [self.hal getDNSServers];
}

- (NSDictionary *)statistics {
  return [self.hal getInterfaceCounters];
}

#pragma mark - Monitoring

- (void)startMonitoring {
  // Monitor signal strength every 5 seconds
  self.signalMonitor =
      [NSTimer scheduledTimerWithTimeInterval:5.0
                                       target:self
                                     selector:@selector(checkSignal)
                                     userInfo:nil
                                      repeats:YES];

  // Monitor throughput every 2 seconds
  NSDictionary *counters = [self.hal getInterfaceCounters];
  self.prevTxBytes = [counters[@"txBytes"] unsignedLongLongValue];
  self.prevRxBytes = [counters[@"rxBytes"] unsignedLongLongValue];

  self.throughputMonitor =
      [NSTimer scheduledTimerWithTimeInterval:2.0
                                       target:self
                                     selector:@selector(checkThroughput)
                                     userInfo:nil
                                      repeats:YES];
}

- (void)stopMonitoring {
  [self.signalMonitor invalidate];
  self.signalMonitor = nil;
  [self.throughputMonitor invalidate];
  self.throughputMonitor = nil;
}

- (void)checkSignal {
  int8_t rssi = (int8_t)[self.connection currentRSSI];
  [self.delegate wifiSignalChanged:rssi];
}

- (void)checkThroughput {
  NSDictionary *counters = [self.hal getInterfaceCounters];
  uint64_t txNow = [counters[@"txBytes"] unsignedLongLongValue];
  uint64_t rxNow = [counters[@"rxBytes"] unsignedLongLongValue];

  uint64_t txBps = (txNow - self.prevTxBytes) / 2; // per second
  uint64_t rxBps = (rxNow - self.prevRxBytes) / 2;
  self.prevTxBytes = txNow;
  self.prevRxBytes = rxNow;

  [self.delegate wifiThroughputUpdate:txBps rxBps:rxBps];
}

#pragma mark - Diagnostics

- (NSDictionary *)driverDiagnostics {
  return @{
    @"state" : [self stateDescription],
    @"interface" : self.hal.interfaceName ?: @"none",
    @"chipset" : self.hal.chipsetName ?: @"unknown",
    @"firmware" : self.hal.firmwareVersion ?: @"N/A",
    @"mac" : self.hal.hardwareAddress ?: @"00:00:00:00:00:00",
    @"powered" : @(self.hal.isPowered),
    @"scanning" : @(self.scanner.isScanning),
    @"connected" : @([self isConnected]),
    @"ssid" : [self currentSSID] ?: @"none",
    @"ip" : [self localIP] ?: @"none",
    @"gateway" : [self gateway] ?: @"none",
    @"dns" : [self dns] ?: @[],
    @"cachedNetworks" : @(self.scanner.lastResults.count),
  };
}

- (NSString *)stateDescription {
  switch (self.state) {
  case WiFiDriverStateUninitialized:
    return @"Uninitialized";
  case WiFiDriverStateInitialized:
    return @"Initialized";
  case WiFiDriverStateScanning:
    return @"Scanning";
  case WiFiDriverStateAuthenticating:
    return @"Authenticating";
  case WiFiDriverStateAssociating:
    return @"Associating";
  case WiFiDriverStateConnected:
    return @"Connected";
  case WiFiDriverStateDisconnecting:
    return @"Disconnecting";
  case WiFiDriverStatePoweredOff:
    return @"Powered Off";
  case WiFiDriverStateError:
    return @"Error";
  }
  return @"Unknown";
}

#pragma mark - WiFiHALDelegate

- (void)halDidDetectHardware:(NSString *)chipset interface:(NSString *)ifName {
  NSLog(@"[WiFiDriver] HAL detected: %@ on %@", chipset, ifName);
}

- (void)halPowerStateChanged:(BOOL)powered {
  NSLog(@"[WiFiDriver] Power state: %@", powered ? @"ON" : @"OFF");
  if (!powered && [self isConnected]) {
    [self.connection disconnect];
  }
}

- (void)halError:(NSString *)message code:(int)code {
  NSLog(@"[WiFiDriver] HAL Error: %@ (code=%d)", message, code);
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.delegate wifiError:message];
  });
}

#pragma mark - WiFiScannerDelegate

- (void)scannerFoundNetwork:(WiFiScanResult *)result {
  NSLog(@"[WiFiDriver] Found: %-20s %@ Ch:%d %@", result.ssid.UTF8String,
        result.bssidString, (int)result.channel, [result securityString]);
}

- (void)scannerDidFinish:(NSArray<WiFiScanResult *> *)results {
  self.state = WiFiDriverStateInitialized;
  NSLog(@"[WiFiDriver] Scan complete: %lu networks",
        (unsigned long)results.count);
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.delegate wifiScanCompleted:results];
  });
}

- (void)scannerError:(NSString *)error {
  NSLog(@"[WiFiDriver] Scanner error: %@", error);
  self.state = WiFiDriverStateInitialized;
}

- (void)scannerProgress:(float)pct channel:(uint16_t)ch {
  // Can be used to update UI progress
}

#pragma mark - WiFiConnectionDelegate

- (void)connectionStateChanged:(WiFiDriverState)newState {
  self.state = newState;
  NSLog(@"[WiFiDriver] Connection state: %@", [self stateDescription]);
}

- (void)connectionEstablished:(WiFiConnectionState *)info {
  NSLog(@"[WiFiDriver] ✓ Connected to '%@' — IP: %@",
        info.associatedNetwork.ssid, info.ipAddress);
  [self startMonitoring];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.delegate wifiConnected:info];
  });
}

- (void)connectionLost:(NSString *)reason {
  [self stopMonitoring];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.delegate wifiDisconnected:reason];
  });
}

- (void)connectionFailed:(NSString *)error {
  self.state = WiFiDriverStateError;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.delegate wifiError:error];
  });
}

- (void)dhcpCompleted:(NSString *)ip gateway:(NSString *)gw dns:(NSArray *)dns {
  NSLog(@"[WiFiDriver] DHCP: IP=%@, GW=%@, DNS=%@", ip, gw, dns);
}

@end
