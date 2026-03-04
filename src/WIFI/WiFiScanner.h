#pragma once
// ============================================================================
// WiFiScanner.h — Active & Passive WiFi Network Scanner
// Uses the HAL to perform channel-by-channel scanning
// ============================================================================

#import "WiFi80211.h"
#import "WiFiHAL.h"
#import "WiFiTypes.h"
#import <Foundation/Foundation.h>

@protocol WiFiScannerDelegate <NSObject>
@optional
- (void)scannerFoundNetwork:(WiFiScanResult *)result;
- (void)scannerDidFinish:(NSArray<WiFiScanResult *> *)results;
- (void)scannerError:(NSString *)error;
- (void)scannerProgress:(float)pct channel:(uint16_t)ch;
@end

@interface WiFiScanner : NSObject

@property(nonatomic, weak) id<WiFiScannerDelegate> delegate;
@property(nonatomic, readonly) BOOL isScanning;
@property(nonatomic, readonly, strong) NSArray<WiFiScanResult *> *lastResults;

- (instancetype)initWithHAL:(WiFiHAL *)hal;

// ── Scanning ──
- (void)startActiveScan:(NSArray<NSNumber *> *)channels
            dwellTimeMs:(uint32_t)dwell;
- (void)startPassiveScan:(NSArray<NSNumber *> *)channels
             dwellTimeMs:(uint32_t)dwell;
- (void)startFullScan; // All bands, default dwell
- (void)stopScan;

// ── Results ──
- (NSArray<WiFiScanResult *> *)sortedBySignal;
- (WiFiScanResult *)findNetwork:(NSString *)ssid;
- (NSArray<WiFiScanResult *> *)networksOnBand:(WiFiBand)band;
- (NSArray<WiFiScanResult *> *)secureNetworks;
- (NSArray<WiFiScanResult *> *)openNetworks;

@end
