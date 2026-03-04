#import "WiFi80211.h"
#include <string.h>

// ============================================================================
// WiFi80211.mm — 802.11 Protocol Handler Implementation
// Builds and parses 802.11 frames from raw bytes
// ============================================================================

@implementation WiFi80211

#pragma mark - Frame Building

+ (NSData *)buildFrameControl:(WiFiFrameType)type subtype:(uint8_t)subtype {
  // Frame Control: Protocol V0 | Type | Subtype
  uint16_t fc = 0;
  fc |= (type & 0x03) << 2;
  fc |= (subtype & 0x0F) << 4;
  return [NSData dataWithBytes:&fc length:2];
}

+ (NSData *)buildProbeRequest:(NSString *)ssid
                    sourceMAC:(const uint8_t[6])src
                      channel:(uint16_t)channel {
  NSMutableData *frame = [NSMutableData data];

  // ── MAC Header ──
  WiFi80211Header hdr;
  memset(&hdr, 0, sizeof(hdr));
  // FC: Management frame, Probe Request subtype
  hdr.frameControl =
      (WiFiFrameTypeManagement << 2) | (WiFiMgmtSubtypeProbeReq << 4);
  hdr.durationID = 0;
  // DA: broadcast
  memset(hdr.addr1, 0xFF, 6);
  // SA: our MAC
  memcpy(hdr.addr2, src, 6);
  // BSSID: broadcast
  memset(hdr.addr3, 0xFF, 6);
  hdr.seqControl = 0;
  [frame appendBytes:&hdr length:sizeof(hdr)];

  // ── IEs ──
  // SSID IE
  WiFiInfoElement ssidIE;
  ssidIE.elementID = WiFiElementID_SSID;
  const char *ssidBytes = ssid ? ssid.UTF8String : "";
  ssidIE.length = ssid ? (uint8_t)strlen(ssidBytes) : 0;
  [frame appendBytes:&ssidIE length:2];
  if (ssidIE.length > 0) {
    [frame appendBytes:ssidBytes length:ssidIE.length];
  }

  // Supported Rates IE
  uint8_t rates[] = {0x82, 0x84, 0x8B, 0x96,
                     0x0C, 0x12, 0x18, 0x24}; // 1,2,5.5,11,6,9,12,18 Mbps
  WiFiInfoElement ratesIE;
  ratesIE.elementID = WiFiElementID_SupportedRates;
  ratesIE.length = sizeof(rates);
  [frame appendBytes:&ratesIE length:2];
  [frame appendBytes:rates length:sizeof(rates)];

  // DS Parameter Set (channel)
  WiFiInfoElement dsIE;
  dsIE.elementID = WiFiElementID_DSParamSet;
  dsIE.length = 1;
  uint8_t ch = (uint8_t)channel;
  [frame appendBytes:&dsIE length:2];
  [frame appendBytes:&ch length:1];

  // Extended Supported Rates
  uint8_t extRates[] = {0x30, 0x48, 0x60, 0x6C}; // 24,36,48,54 Mbps
  WiFiInfoElement extIE;
  extIE.elementID = WiFiElementID_ExtSupportedRates;
  extIE.length = sizeof(extRates);
  [frame appendBytes:&extIE length:2];
  [frame appendBytes:extRates length:sizeof(extRates)];

  // HT Capabilities (WiFi 4+)
  WiFiInfoElement htIE;
  htIE.elementID = WiFiElementID_HT_Capabilities;
  uint8_t htCap[] = {0x2D, 0x00, 0x1B, 0xFF, 0xFF, 0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};
  htIE.length = sizeof(htCap);
  [frame appendBytes:&htIE length:2];
  [frame appendBytes:htCap length:sizeof(htCap)];

  return frame;
}

+ (NSData *)buildAuthRequest:(const uint8_t[6])bssid
                   sourceMAC:(const uint8_t[6])src
                   algorithm:(WiFiAuthAlgorithm)alg
                      seqNum:(uint16_t)seq {
  NSMutableData *frame = [NSMutableData data];

  WiFi80211Header hdr;
  memset(&hdr, 0, sizeof(hdr));
  hdr.frameControl =
      (WiFiFrameTypeManagement << 2) | (WiFiMgmtSubtypeAuth << 4);
  memcpy(hdr.addr1, bssid, 6); // DA = BSSID
  memcpy(hdr.addr2, src, 6);   // SA = our MAC
  memcpy(hdr.addr3, bssid, 6); // BSSID
  [frame appendBytes:&hdr length:sizeof(hdr)];

  WiFiAuthBody body;
  body.authAlgorithm = alg;
  body.authSeqNum = seq;
  body.statusCode = 0; // Success
  [frame appendBytes:&body length:sizeof(body)];

  return frame;
}

+ (NSData *)buildAssocRequest:(const uint8_t[6])bssid
                    sourceMAC:(const uint8_t[6])src
                         ssid:(NSString *)ssid
               supportedRates:(NSArray<NSNumber *> *)rates {
  NSMutableData *frame = [NSMutableData data];

  WiFi80211Header hdr;
  memset(&hdr, 0, sizeof(hdr));
  hdr.frameControl =
      (WiFiFrameTypeManagement << 2) | (WiFiMgmtSubtypeAssocReq << 4);
  memcpy(hdr.addr1, bssid, 6);
  memcpy(hdr.addr2, src, 6);
  memcpy(hdr.addr3, bssid, 6);
  [frame appendBytes:&hdr length:sizeof(hdr)];

  // Fixed fields
  WiFiAssocReqFixed fixed;
  fixed.capabilityInfo = 0x0431; // ESS, Short Preamble, Short Slot Time
  fixed.listenInterval = 10;
  [frame appendBytes:&fixed length:sizeof(fixed)];

  // SSID IE
  WiFiInfoElement ssidIE;
  ssidIE.elementID = WiFiElementID_SSID;
  const char *ssidStr = ssid.UTF8String;
  ssidIE.length = (uint8_t)strlen(ssidStr);
  [frame appendBytes:&ssidIE length:2];
  [frame appendBytes:ssidStr length:ssidIE.length];

  // Supported Rates IE
  WiFiInfoElement rateIE;
  rateIE.elementID = WiFiElementID_SupportedRates;
  rateIE.length = MIN((int)rates.count, 8);
  [frame appendBytes:&rateIE length:2];
  for (int i = 0; i < rateIE.length; i++) {
    uint8_t r = [rates[i] unsignedCharValue];
    [frame appendBytes:&r length:1];
  }

  return frame;
}

+ (NSData *)buildDeauthFrame:(const uint8_t[6])bssid
                   sourceMAC:(const uint8_t[6])src
                  reasonCode:(uint16_t)reason {
  NSMutableData *frame = [NSMutableData data];

  WiFi80211Header hdr;
  memset(&hdr, 0, sizeof(hdr));
  hdr.frameControl =
      (WiFiFrameTypeManagement << 2) | (WiFiMgmtSubtypeDeauth << 4);
  memcpy(hdr.addr1, bssid, 6);
  memcpy(hdr.addr2, src, 6);
  memcpy(hdr.addr3, bssid, 6);
  [frame appendBytes:&hdr length:sizeof(hdr)];
  [frame appendBytes:&reason length:2];

  return frame;
}

+ (NSData *)buildDisassocFrame:(const uint8_t[6])bssid
                     sourceMAC:(const uint8_t[6])src
                    reasonCode:(uint16_t)reason {
  NSMutableData *frame = [NSMutableData data];

  WiFi80211Header hdr;
  memset(&hdr, 0, sizeof(hdr));
  hdr.frameControl =
      (WiFiFrameTypeManagement << 2) | (WiFiMgmtSubtypeDisassoc << 4);
  memcpy(hdr.addr1, bssid, 6);
  memcpy(hdr.addr2, src, 6);
  memcpy(hdr.addr3, bssid, 6);
  [frame appendBytes:&hdr length:sizeof(hdr)];
  [frame appendBytes:&reason length:2];

  return frame;
}

#pragma mark - Frame Parsing

+ (WiFi80211Header *)parseHeader:(NSData *)frame {
  if (frame.length < sizeof(WiFi80211Header))
    return NULL;
  return (WiFi80211Header *)frame.bytes;
}

+ (WiFiFrameType)getFrameType:(NSData *)frame {
  if (frame.length < 2)
    return WiFiFrameTypeManagement;
  const uint8_t *p = (const uint8_t *)frame.bytes;
  return (WiFiFrameType)((p[0] >> 2) & 0x03);
}

+ (WiFiMgmtSubtype)getMgmtSubtype:(NSData *)frame {
  if (frame.length < 2)
    return WiFiMgmtSubtypeBeacon;
  const uint8_t *p = (const uint8_t *)frame.bytes;
  return (WiFiMgmtSubtype)((p[0] >> 4) & 0x0F);
}

+ (WiFiScanResult *)parseBeacon:(NSData *)frame {
  if (frame.length < sizeof(WiFi80211Header) + sizeof(WiFiBeaconFixed))
    return nil;

  WiFiScanResult *result = [WiFiScanResult new];

  // Parse header
  const WiFi80211Header *hdr = (const WiFi80211Header *)frame.bytes;
  result.bssid = [NSData dataWithBytes:hdr->addr3 length:6];
  result.bssidString = [self macToString:hdr->addr3];

  // Parse beacon fixed fields
  size_t offset = sizeof(WiFi80211Header);
  const WiFiBeaconFixed *beacon =
      (const WiFiBeaconFixed *)((const uint8_t *)frame.bytes + offset);
  result.beaconInterval = beacon->beaconInterval;
  offset += sizeof(WiFiBeaconFixed);

  // Parse Information Elements
  NSData *ieData =
      [frame subdataWithRange:NSMakeRange(offset, frame.length - offset)];
  result.ssid = [self parseSSID:ieData] ?: @"<Hidden>";
  result.isHidden =
      (result.ssid.length == 0 || [result.ssid isEqualToString:@"<Hidden>"]);
  result.channel = [self parseDSChannel:ieData];
  result.security = [self parseSecurityIE:ieData];
  result.lastSeen = [NSDate date];

  // Determine band from channel
  if (result.channel <= 14)
    result.band = WiFiBand_2_4GHz;
  else if (result.channel <= 196)
    result.band = WiFiBand_5GHz;
  else
    result.band = WiFiBand_6GHz;

  return result;
}

+ (WiFiScanResult *)parseProbeResponse:(NSData *)frame {
  // Same format as beacon
  return [self parseBeacon:frame];
}

+ (WiFiAuthBody)parseAuthResponse:(NSData *)frame {
  WiFiAuthBody body;
  memset(&body, 0, sizeof(body));
  size_t offset = sizeof(WiFi80211Header);
  if (frame.length >= offset + sizeof(WiFiAuthBody)) {
    memcpy(&body, (const uint8_t *)frame.bytes + offset, sizeof(body));
  }
  return body;
}

+ (WiFiAssocRespFixed)parseAssocResponse:(NSData *)frame {
  WiFiAssocRespFixed resp;
  memset(&resp, 0, sizeof(resp));
  size_t offset = sizeof(WiFi80211Header);
  if (frame.length >= offset + sizeof(resp)) {
    memcpy(&resp, (const uint8_t *)frame.bytes + offset, sizeof(resp));
  }
  return resp;
}

#pragma mark - IE Parsing

+ (NSString *)parseSSID:(NSData *)ieData {
  const uint8_t *p = (const uint8_t *)ieData.bytes;
  size_t len = ieData.length;
  size_t i = 0;

  while (i + 2 <= len) {
    uint8_t id = p[i];
    uint8_t ieLen = p[i + 1];
    if (i + 2 + ieLen > len)
      break;

    if (id == WiFiElementID_SSID) {
      if (ieLen == 0)
        return @"";
      return [[NSString alloc] initWithBytes:&p[i + 2]
                                      length:ieLen
                                    encoding:NSUTF8StringEncoding];
    }
    i += 2 + ieLen;
  }
  return nil;
}

+ (NSArray<NSNumber *> *)parseSupportedRates:(NSData *)ieData {
  NSMutableArray *rates = [NSMutableArray array];
  const uint8_t *p = (const uint8_t *)ieData.bytes;
  size_t len = ieData.length;
  size_t i = 0;

  while (i + 2 <= len) {
    uint8_t id = p[i];
    uint8_t ieLen = p[i + 1];
    if (i + 2 + ieLen > len)
      break;

    if (id == WiFiElementID_SupportedRates ||
        id == WiFiElementID_ExtSupportedRates) {
      for (uint8_t j = 0; j < ieLen; j++) {
        double rate = (p[i + 2 + j] & 0x7F) * 0.5;
        [rates addObject:@(rate)];
      }
    }
    i += 2 + ieLen;
  }
  return rates;
}

+ (uint8_t)parseDSChannel:(NSData *)ieData {
  const uint8_t *p = (const uint8_t *)ieData.bytes;
  size_t len = ieData.length;
  size_t i = 0;

  while (i + 2 <= len) {
    uint8_t id = p[i];
    uint8_t ieLen = p[i + 1];
    if (i + 2 + ieLen > len)
      break;

    if (id == WiFiElementID_DSParamSet && ieLen >= 1) {
      return p[i + 2];
    }
    i += 2 + ieLen;
  }
  return 0;
}

+ (WiFiSecurityType)parseSecurityIE:(NSData *)ieData {
  const uint8_t *p = (const uint8_t *)ieData.bytes;
  size_t len = ieData.length;
  size_t i = 0;
  BOOL hasRSN = NO;
  BOOL hasWPA = NO;

  while (i + 2 <= len) {
    uint8_t id = p[i];
    uint8_t ieLen = p[i + 1];
    if (i + 2 + ieLen > len)
      break;

    if (id == WiFiElementID_RSN) {
      hasRSN = YES;
      // Check for SAE (WPA3)
      if (ieLen >= 8) {
        // Parse AKM suite to distinguish WPA2 vs WPA3
        // AKM OUI 00:0F:AC, type 8 = SAE (WPA3)
        for (uint8_t j = 0; j + 3 < ieLen; j++) {
          if (p[i + 2 + j] == 0x00 && p[i + 2 + j + 1] == 0x0F &&
              p[i + 2 + j + 2] == 0xAC && j + 3 < ieLen &&
              p[i + 2 + j + 3] == 0x08) {
            return WiFiSecurityWPA3;
          }
        }
      }
    }
    if (id == WiFiElementID_VendorSpecific && ieLen >= 4) {
      // WPA OUI: 00:50:F2:01
      if (p[i + 2] == 0x00 && p[i + 3] == 0x50 && p[i + 4] == 0xF2 &&
          p[i + 5] == 0x01) {
        hasWPA = YES;
      }
    }
    i += 2 + ieLen;
  }

  if (hasRSN)
    return WiFiSecurityWPA2;
  if (hasWPA)
    return WiFiSecurityWPA;
  return WiFiSecurityOpen;
}

+ (NSDictionary *)parseAllIEs:(NSData *)ieData {
  NSMutableDictionary *dict = [NSMutableDictionary dictionary];
  const uint8_t *p = (const uint8_t *)ieData.bytes;
  size_t len = ieData.length;
  size_t i = 0;

  while (i + 2 <= len) {
    uint8_t id = p[i];
    uint8_t ieLen = p[i + 1];
    if (i + 2 + ieLen > len)
      break;
    dict[@(id)] = [NSData dataWithBytes:&p[i + 2] length:ieLen];
    i += 2 + ieLen;
  }
  return dict;
}

#pragma mark - Utilities

+ (NSString *)macToString:(const uint8_t[6])mac {
  return [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", mac[0],
                                    mac[1], mac[2], mac[3], mac[4], mac[5]];
}

+ (void)stringToMAC:(NSString *)str output:(uint8_t[6])mac {
  unsigned int vals[6] = {};
  sscanf(str.UTF8String, "%02X:%02X:%02X:%02X:%02X:%02X", &vals[0], &vals[1],
         &vals[2], &vals[3], &vals[4], &vals[5]);
  for (int i = 0; i < 6; i++)
    mac[i] = (uint8_t)vals[i];
}

+ (uint16_t)calcFrameChecksum:(NSData *)frame {
  // CRC-16 for basic checksum (real 802.11 uses CRC-32 FCS)
  uint16_t crc = 0xFFFF;
  const uint8_t *bytes = (const uint8_t *)frame.bytes;
  for (size_t i = 0; i < frame.length; i++) {
    crc ^= bytes[i];
    for (int j = 0; j < 8; j++) {
      if (crc & 1)
        crc = (crc >> 1) ^ 0xA001;
      else
        crc >>= 1;
    }
  }
  return crc;
}

+ (BOOL)isManagementFrame:(NSData *)frame {
  return [self getFrameType:frame] == WiFiFrameTypeManagement;
}

+ (BOOL)isBeacon:(NSData *)frame {
  return [self isManagementFrame:frame] &&
         [self getMgmtSubtype:frame] == WiFiMgmtSubtypeBeacon;
}

+ (BOOL)isProbeResponse:(NSData *)frame {
  return [self isManagementFrame:frame] &&
         [self getMgmtSubtype:frame] == WiFiMgmtSubtypeProbeResp;
}

@end
