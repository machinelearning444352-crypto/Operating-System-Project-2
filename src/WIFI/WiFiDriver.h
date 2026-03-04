#pragma once
// ============================================================================
// WiFiDriver.h — Main WiFi Driver Interface
// Orchestrates HAL, Scanner, 802.11 Protocol, and Connection Manager
// ============================================================================

#import "WiFi80211.h"
#import "WiFiConnection.h"
#import "WiFiHAL.h"
#import "WiFiScanner.h"
#import "WiFiTypes.h"
#import <Foundation/Foundation.h>

@protocol WiFiDriverDelegate <NSObject>
@optional
- (void)wifiDriverReady:(NSString *)interface chipset:(NSString *)chipset;
- (void)wifiScanCompleted:(NSArray<WiFiScanResult *> *)networks;
- (void)wifiConnected:(WiFiConnectionState *)state;
- (void)wifiDisconnected:(NSString *)reason;
- (void)wifiError:(NSString *)error;
- (void)wifiSignalChanged:(int8_t)rssi;
- (void)wifiThroughputUpdate:(uint64_t)txBps rxBps:(uint64_t)rxBps;
@end

@interface WiFiDriver
    : NSObject <WiFiHALDelegate, WiFiScannerDelegate, WiFiConnectionDelegate>

@property(nonatomic, weak) id<WiFiDriverDelegate> delegate;
@property(nonatomic, readonly, strong) WiFiHAL *hal;
@property(nonatomic, readonly, strong) WiFiScanner *scanner;
@property(nonatomic, readonly, strong) WiFiConnection *connection;
@property(nonatomic, readonly) WiFiDriverState state;

+ (instancetype)sharedInstance;

// ── Lifecycle ──
- (BOOL)start;
- (void)stop;
- (BOOL)isRunning;

// ── Power ──
- (BOOL)setPower:(BOOL)on;
- (BOOL)isPowered;

// ── Scanning ──
- (void)scanForNetworks;
- (void)scanForNetworksOnBand:(WiFiBand)band;
- (NSArray<WiFiScanResult *> *)cachedScanResults;

// ── Connection ──
- (void)connectToNetwork:(NSString *)ssid password:(NSString *)password;
- (void)connectToOpenNetwork:(NSString *)ssid;
- (void)disconnect;
- (BOOL)isConnected;
- (WiFiConnectionState *)connectionInfo;
- (NSString *)currentSSID;

// ── Network info ──
- (WiFiInterfaceInfo *)interfaceInfo;
- (NSString *)localIP;
- (NSString *)gateway;
- (NSArray<NSString *> *)dns;
- (NSDictionary *)statistics;

// ── Diagnostics ──
- (NSDictionary *)driverDiagnostics;
- (NSString *)stateDescription;

@end
