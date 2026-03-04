#pragma once
// ============================================================================
// WiFi80211.h — 802.11 Protocol Handler
// Builds and parses 802.11 management/data frames from scratch
// ============================================================================

#import "WiFiTypes.h"
#import <Foundation/Foundation.h>

@interface WiFi80211 : NSObject

// ── Frame building ──
+ (NSData *)buildProbeRequest:(NSString *)ssid
                    sourceMAC:(const uint8_t[6])src
                      channel:(uint16_t)channel;

+ (NSData *)buildAuthRequest:(const uint8_t[6])bssid
                   sourceMAC:(const uint8_t[6])src
                   algorithm:(WiFiAuthAlgorithm)alg
                      seqNum:(uint16_t)seq;

+ (NSData *)buildAssocRequest:(const uint8_t[6])bssid
                    sourceMAC:(const uint8_t[6])src
                         ssid:(NSString *)ssid
               supportedRates:(NSArray<NSNumber *> *)rates;

+ (NSData *)buildDeauthFrame:(const uint8_t[6])bssid
                   sourceMAC:(const uint8_t[6])src
                  reasonCode:(uint16_t)reason;

+ (NSData *)buildDisassocFrame:(const uint8_t[6])bssid
                     sourceMAC:(const uint8_t[6])src
                    reasonCode:(uint16_t)reason;

// ── Frame parsing ──
+ (WiFi80211Header *)parseHeader:(NSData *)frame;
+ (WiFiFrameType)getFrameType:(NSData *)frame;
+ (WiFiMgmtSubtype)getMgmtSubtype:(NSData *)frame;

// ── Beacon / Probe Response parsing ──
+ (WiFiScanResult *)parseBeacon:(NSData *)frame;
+ (WiFiScanResult *)parseProbeResponse:(NSData *)frame;

// ── Auth / Assoc parsing ──
+ (WiFiAuthBody)parseAuthResponse:(NSData *)frame;
+ (WiFiAssocRespFixed)parseAssocResponse:(NSData *)frame;

// ── Information Element parsing ──
+ (NSString *)parseSSID:(NSData *)frame;
+ (NSArray<NSNumber *> *)parseSupportedRates:(NSData *)frame;
+ (uint8_t)parseDSChannel:(NSData *)frame;
+ (WiFiSecurityType)parseSecurityIE:(NSData *)frame;
+ (NSDictionary *)parseAllIEs:(NSData *)ieData;

// ── Utility ──
+ (NSString *)macToString:(const uint8_t[6])mac;
+ (void)stringToMAC:(NSString *)str output:(uint8_t[6])mac;
+ (uint16_t)calcFrameChecksum:(NSData *)frame;
+ (BOOL)isManagementFrame:(NSData *)frame;
+ (BOOL)isBeacon:(NSData *)frame;
+ (BOOL)isProbeResponse:(NSData *)frame;

@end
