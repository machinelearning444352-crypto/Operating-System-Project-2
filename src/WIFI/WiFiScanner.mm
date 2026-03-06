#import "WiFiScanner.h"

// ============================================================================
// WiFiScanner.mm — WiFi Network Scanner
// Uses airport CLI as primary scan method (works without root)
// Falls back to BPF raw capture only when running as root
// ============================================================================

@interface WiFiScanner ()
@property(nonatomic, strong) WiFiHAL *hal;
@property(nonatomic, readwrite) BOOL isScanning;
@property(nonatomic, readwrite, strong)
    NSMutableArray<WiFiScanResult *> *results;
@property(nonatomic, strong)
    NSMutableDictionary<NSString *, WiFiScanResult *> *seenBSSIDs;
@property(nonatomic, strong) dispatch_queue_t scanQueue;
@property(nonatomic, assign) BOOL shouldStop;
@end

@implementation WiFiScanner

- (instancetype)initWithHAL:(WiFiHAL *)hal {
  if (self = [super init]) {
    _hal = hal;
    _results = [NSMutableArray array];
    _seenBSSIDs = [NSMutableDictionary dictionary];
    _scanQueue = dispatch_queue_create("com.virtualos.wifi.scanner",
                                       DISPATCH_QUEUE_SERIAL);
  }
  return self;
}

- (NSArray<WiFiScanResult *> *)lastResults {
  @synchronized(self.results) {
    return [self.results copy];
  }
}

#pragma mark - Scanning (Non-Root Primary Path)

- (void)startFullScan {
  NSArray *channels =
      @[ @1, @6, @11, @36, @40, @44, @48, @149, @153, @157, @161, @165 ];
  [self startActiveScan:channels dwellTimeMs:100];
}

- (void)startActiveScan:(NSArray<NSNumber *> *)channels
            dwellTimeMs:(uint32_t)dwell {
  if (self.isScanning)
    return;
  self.isScanning = YES;
  self.shouldStop = NO;

  @synchronized(self.results) {
    [self.results removeAllObjects];
    [self.seenBSSIDs removeAllObjects];
  }

  NSLog(@"[WiFiScanner] Starting scan (non-root primary path)");

  dispatch_async(self.scanQueue, ^{
    // ── PRIMARY: Use airport CLI (works without root) ──
    [self performSystemScan];

    // ── FALLBACK: If airport found nothing, try BPF (requires root) ──
    if (self.results.count == 0) {
      NSLog(@"[WiFiScanner] Airport scan found nothing, trying BPF...");
      [self performBPFScan:channels dwellTimeMs:dwell];
    }

    // ── SECOND FALLBACK: networksetup ──
    if (self.results.count == 0) {
      [self performNetworksetupScan];
    }

    self.isScanning = NO;

    NSArray *finalResults;
    @synchronized(self.results) {
      finalResults = [self.results copy];
    }

    NSLog(@"[WiFiScanner] Scan complete: %lu networks found",
          (unsigned long)finalResults.count);

    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate scannerDidFinish:finalResults];
    });
  });
}

- (void)startPassiveScan:(NSArray<NSNumber *> *)channels
             dwellTimeMs:(uint32_t)dwell {
  // Passive scan: same as active but without probe injection
  [self startActiveScan:channels dwellTimeMs:dwell];
}

- (void)stopScan {
  self.shouldStop = YES;
}

#pragma mark - Airport CLI Scan (No Root Required)

- (void)performSystemScan {
  NSLog(@"[WiFiScanner] Scanning via airport CLI (no root needed)");

  NSTask *task = [[NSTask alloc] init];
  task.executableURL = [NSURL
      fileURLWithPath:@"/System/Library/PrivateFrameworks/Apple80211.framework"
                       "/Versions/Current/Resources/airport"];
  task.arguments = @[ @"-s" ];
  NSPipe *pipe = [NSPipe pipe];
  task.standardOutput = pipe;
  task.standardError = [NSPipe pipe];

  @try {
    [task launchAndReturnError:nil];
    [task waitUntilExit];

    NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data
                                             encoding:NSUTF8StringEncoding];
    [self parseAirportOutput:output];
  } @catch (NSException *e) {
    NSLog(@"[WiFiScanner] airport scan failed: %@", e);
  }
}

- (void)performNetworksetupScan {
  NSLog(@"[WiFiScanner] Trying networksetup fallback");

  NSString *ifName = self.hal.interfaceName ?: @"en0";
  NSTask *task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/networksetup"];
  task.arguments = @[ @"-listpreferredwirelessnetworks", ifName ];
  NSPipe *pipe = [NSPipe pipe];
  task.standardOutput = pipe;
  task.standardError = [NSPipe pipe];

  @try {
    [task launchAndReturnError:nil];
    [task waitUntilExit];

    NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data
                                             encoding:NSUTF8StringEncoding];
    NSArray *lines = [output componentsSeparatedByString:@"\n"];
    for (NSUInteger i = 1; i < lines.count; i++) {
      NSString *ssid =
          [lines[i] stringByTrimmingCharactersInSet:
                        [NSCharacterSet whitespaceAndNewlineCharacterSet]];
      if (ssid.length == 0)
        continue;

      WiFiScanResult *r = [WiFiScanResult new];
      r.ssid = ssid;
      r.bssidString = @"00:00:00:00:00:00";
      r.rssi = -65;
      r.channel = 6;
      r.security = WiFiSecurityWPA2;
      r.band = WiFiBand_2_4GHz;
      r.phyMode = WiFiPHYMode_n;
      r.lastSeen = [NSDate date];

      @synchronized(self.results) {
        if (!self.seenBSSIDs[r.ssid]) {
          [self.results addObject:r];
          self.seenBSSIDs[r.ssid] = r;
        }
      }
    }
  } @catch (NSException *e) {
    NSLog(@"[WiFiScanner] networksetup scan failed: %@", e);
  }
}

- (void)parseAirportOutput:(NSString *)output {
  NSArray *lines = [output componentsSeparatedByString:@"\n"];
  if (lines.count < 2)
    return;

  // airport -s output: SSID BSSID RSSI CHANNEL HT CC SECURITY
  for (NSUInteger i = 1; i < lines.count; i++) {
    NSString *line = lines[i];
    if (line.length < 30)
      continue;

    NSArray *parts =
        [line componentsSeparatedByCharactersInSet:[NSCharacterSet
                                                       whitespaceCharacterSet]];
    NSMutableArray *nonEmpty = [NSMutableArray array];
    for (NSString *p in parts) {
      if (p.length > 0)
        [nonEmpty addObject:p];
    }

    if (nonEmpty.count < 5)
      continue;

    WiFiScanResult *r = [WiFiScanResult new];

    // Find BSSID token (xx:xx:xx:xx:xx:xx)
    NSString *bssid = nil;
    for (NSString *token in nonEmpty) {
      if ([token containsString:@":"] && token.length == 17) {
        bssid = token;
        break;
      }
    }

    if (!bssid)
      continue;
    NSUInteger bssidIdx = [nonEmpty indexOfObject:bssid];
    if (bssidIdx == 0 || bssidIdx == NSNotFound)
      continue;

    // Everything before BSSID is the SSID
    NSArray *ssidParts = [nonEmpty subarrayWithRange:NSMakeRange(0, bssidIdx)];
    r.ssid = [ssidParts componentsJoinedByString:@" "];
    r.bssidString = [bssid uppercaseString];

    // Parse MAC bytes
    uint8_t mac[6];
    [WiFi80211 stringToMAC:r.bssidString output:mac];
    r.bssid = [NSData dataWithBytes:mac length:6];

    // After BSSID: RSSI, CHANNEL, HT, CC, SECURITY...
    if (bssidIdx + 1 < nonEmpty.count)
      r.rssi = (int8_t)[nonEmpty[bssidIdx + 1] intValue];
    if (bssidIdx + 2 < nonEmpty.count)
      r.channel = [nonEmpty[bssidIdx + 2] intValue];

    // Security
    NSString *secStr = @"";
    for (NSUInteger j = bssidIdx + 4; j < nonEmpty.count; j++) {
      secStr = [secStr stringByAppendingFormat:@"%@ ", nonEmpty[j]];
    }
    if ([secStr containsString:@"WPA3"])
      r.security = WiFiSecurityWPA3;
    else if ([secStr containsString:@"WPA2"])
      r.security = WiFiSecurityWPA2;
    else if ([secStr containsString:@"WPA"])
      r.security = WiFiSecurityWPA;
    else if ([secStr containsString:@"WEP"])
      r.security = WiFiSecurityWEP;
    else
      r.security = WiFiSecurityOpen;

    // Band
    if (r.channel <= 14)
      r.band = WiFiBand_2_4GHz;
    else if (r.channel <= 196)
      r.band = WiFiBand_5GHz;
    else
      r.band = WiFiBand_6GHz;

    // PHY mode estimate
    if (r.channel > 14)
      r.phyMode = WiFiPHYMode_ac;
    else
      r.phyMode = WiFiPHYMode_n;

    r.lastSeen = [NSDate date];

    @synchronized(self.results) {
      if (!self.seenBSSIDs[r.bssidString]) {
        [self.results addObject:r];
        self.seenBSSIDs[r.bssidString] = r;

        dispatch_async(dispatch_get_main_queue(), ^{
          [self.delegate scannerFoundNetwork:r];
        });
      }
    }
  }
}

#pragma mark - BPF Scan (Root Required — Fallback Only)

- (void)performBPFScan:(NSArray<NSNumber *> *)channels
           dwellTimeMs:(uint32_t)dwell {
  int bpfFD = [self.hal openRawSocket];
  if (bpfFD < 0) {
    NSLog(@"[WiFiScanner] BPF unavailable (not root) — skipping raw scan");
    return;
  }

  uint8_t ourMAC[6];
  [WiFi80211 stringToMAC:self.hal.hardwareAddress output:ourMAC];

  float totalChannels = (float)channels.count;
  float completed = 0;

  for (NSNumber *chNum in channels) {
    if (self.shouldStop)
      break;

    uint16_t channel = [chNum unsignedShortValue];

    NSData *probeReq = [WiFi80211 buildProbeRequest:nil
                                          sourceMAC:ourMAC
                                            channel:channel];
    [self.hal writeFrame:bpfFD data:probeReq];

    NSTimeInterval dwellSec = (double)dwell / 1000.0;
    NSDate *dwellEnd = [NSDate dateWithTimeIntervalSinceNow:dwellSec];

    while ([[NSDate date] compare:dwellEnd] == NSOrderedAscending &&
           !self.shouldStop) {
      NSData *frame = [self.hal readFrame:bpfFD timeout:0.05];
      if (frame) {
        [self processFrame:frame defaultChannel:channel];
      }
    }

    completed++;
    dispatch_async(dispatch_get_main_queue(), ^{
      [self.delegate scannerProgress:(completed / totalChannels)
                             channel:channel];
    });
  }

  [self.hal closeRawSocket:bpfFD];
}

#pragma mark - Frame Processing (for BPF path)

- (void)processFrame:(NSData *)frame defaultChannel:(uint16_t)ch {
  NSData *body = frame;
  if (frame.length >= 4) {
    const uint8_t *p = (const uint8_t *)frame.bytes;
    if (p[0] == 0x00) {
      const WiFiRadiotapHeader *rt = (const WiFiRadiotapHeader *)p;
      if (rt->length < frame.length) {
        body = [frame subdataWithRange:NSMakeRange(rt->length,
                                                   frame.length - rt->length)];
      }
    }
  }

  if (![WiFi80211 isManagementFrame:body])
    return;

  WiFiScanResult *result = nil;
  if ([WiFi80211 isBeacon:body]) {
    result = [WiFi80211 parseBeacon:body];
  } else if ([WiFi80211 isProbeResponse:body]) {
    result = [WiFi80211 parseProbeResponse:body];
  }

  if (!result || !result.bssidString)
    return;
  if (result.channel == 0)
    result.channel = ch;

  @synchronized(self.results) {
    WiFiScanResult *existing = self.seenBSSIDs[result.bssidString];
    if (existing) {
      existing.rssi = (int8_t)((existing.rssi + result.rssi) / 2);
      existing.lastSeen = [NSDate date];
    } else {
      [self.results addObject:result];
      self.seenBSSIDs[result.bssidString] = result;

      dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate scannerFoundNetwork:result];
      });
    }
  }
}

#pragma mark - Result Queries

- (NSArray<WiFiScanResult *> *)sortedBySignal {
  @synchronized(self.results) {
    return [self.results sortedArrayUsingComparator:^NSComparisonResult(
                             WiFiScanResult *a, WiFiScanResult *b) {
      return (a.rssi > b.rssi) ? NSOrderedAscending : NSOrderedDescending;
    }];
  }
}

- (WiFiScanResult *)findNetwork:(NSString *)ssid {
  @synchronized(self.results) {
    for (WiFiScanResult *r in self.results) {
      if ([r.ssid isEqualToString:ssid])
        return r;
    }
  }
  return nil;
}

- (NSArray<WiFiScanResult *> *)networksOnBand:(WiFiBand)band {
  @synchronized(self.results) {
    NSPredicate *pred = [NSPredicate
        predicateWithBlock:^BOOL(WiFiScanResult *r, NSDictionary *b) {
          return r.band == band;
        }];
    return [self.results filteredArrayUsingPredicate:pred];
  }
}

- (NSArray<WiFiScanResult *> *)secureNetworks {
  @synchronized(self.results) {
    NSPredicate *pred = [NSPredicate
        predicateWithBlock:^BOOL(WiFiScanResult *r, NSDictionary *b) {
          return r.security != WiFiSecurityOpen;
        }];
    return [self.results filteredArrayUsingPredicate:pred];
  }
}

- (NSArray<WiFiScanResult *> *)openNetworks {
  @synchronized(self.results) {
    NSPredicate *pred = [NSPredicate
        predicateWithBlock:^BOOL(WiFiScanResult *r, NSDictionary *b) {
          return r.security == WiFiSecurityOpen;
        }];
    return [self.results filteredArrayUsingPredicate:pred];
  }
}

@end
