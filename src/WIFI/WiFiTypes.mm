#import "WiFiTypes.h"

// ============================================================================
// WiFiTypes.mm — WiFiScanResult implementation
// ============================================================================

@implementation WiFiScanResult

- (NSString *)securityString {
  switch (self.security) {
  case WiFiSecurityOpen:
    return @"Open";
  case WiFiSecurityWEP:
    return @"WEP";
  case WiFiSecurityWPA:
    return @"WPA";
  case WiFiSecurityWPA2:
    return @"WPA2 Personal";
  case WiFiSecurityWPA3:
    return @"WPA3 Personal";
  case WiFiSecurityWPA2Enterprise:
    return @"WPA2 Enterprise";
  case WiFiSecurityWPA3Enterprise:
    return @"WPA3 Enterprise";
  }
  return @"Unknown";
}

- (NSString *)phyModeString {
  switch (self.phyMode) {
  case WiFiPHYMode_a:
    return @"802.11a";
  case WiFiPHYMode_b:
    return @"802.11b";
  case WiFiPHYMode_g:
    return @"802.11g";
  case WiFiPHYMode_n:
    return @"802.11n (Wi-Fi 4)";
  case WiFiPHYMode_ac:
    return @"802.11ac (Wi-Fi 5)";
  case WiFiPHYMode_ax:
    return @"802.11ax (Wi-Fi 6)";
  case WiFiPHYMode_be:
    return @"802.11be (Wi-Fi 7)";
  }
  return @"Unknown";
}

- (NSString *)bandString {
  switch (self.band) {
  case WiFiBand_2_4GHz:
    return @"2.4 GHz";
  case WiFiBand_5GHz:
    return @"5 GHz";
  case WiFiBand_6GHz:
    return @"6 GHz";
  }
  return @"Unknown";
}

- (NSString *)channelWidthString {
  switch (self.channelWidth) {
  case WiFiChannelWidth_20MHz:
    return @"20 MHz";
  case WiFiChannelWidth_40MHz:
    return @"40 MHz";
  case WiFiChannelWidth_80MHz:
    return @"80 MHz";
  case WiFiChannelWidth_160MHz:
    return @"160 MHz";
  case WiFiChannelWidth_320MHz:
    return @"320 MHz";
  }
  return @"Unknown";
}

- (NSInteger)signalQuality {
  // Convert RSSI dBm to quality percentage
  // -30 dBm = 100%, -90 dBm = 0%
  if (self.rssi >= -30)
    return 100;
  if (self.rssi <= -90)
    return 0;
  return (NSInteger)(((double)(self.rssi + 90) / 60.0) * 100.0);
}

@end

@implementation WiFiInterfaceInfo
@end

@implementation WiFiConnectionState
@end
