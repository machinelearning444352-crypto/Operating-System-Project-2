#pragma once
// ============================================================================
// WiFiHAL.h — Hardware Abstraction Layer
// Direct IOKit/BSD interface to the WiFi controller hardware
// ============================================================================

#import "WiFiTypes.h"
#import <Foundation/Foundation.h>

@protocol WiFiHALDelegate <NSObject>
@optional
- (void)halDidDetectHardware:(NSString *)chipset interface:(NSString *)ifName;
- (void)halPowerStateChanged:(BOOL)powered;
- (void)halError:(NSString *)message code:(int)code;
@end

@interface WiFiHAL : NSObject

@property(nonatomic, weak) id<WiFiHALDelegate> delegate;
@property(nonatomic, readonly) BOOL isInitialized;
@property(nonatomic, readonly) BOOL isPowered;
@property(nonatomic, readonly, strong) NSString *interfaceName;
@property(nonatomic, readonly, strong) NSString *chipsetName;
@property(nonatomic, readonly, strong) NSString *firmwareVersion;
@property(nonatomic, readonly, strong) NSString *hardwareAddress;

// ── Initialization ──
- (BOOL)initialize;
- (void)shutdown;

// ── Power control ──
- (BOOL)setPower:(BOOL)on;
- (BOOL)getPowerState;

// ── Interface queries (raw BSD/ioctl) ──
- (WiFiInterfaceInfo *)queryInterfaceInfo;
- (uint32_t)getInterfaceFlags;
- (BOOL)setInterfaceFlags:(uint32_t)flags;
- (NSString *)getMACAddress;
- (uint32_t)getMTU;

// ── IOKit hardware queries ──
- (NSDictionary *)getHardwareProperties;
- (NSString *)getChipsetInfo;
- (NSArray<NSNumber *> *)getSupportedChannels;
- (NSArray<NSNumber *> *)getSupportedPHYModes;

// ── Raw I/O ──
- (int)openRawSocket;
- (void)closeRawSocket:(int)fd;
- (NSData *)readFrame:(int)fd timeout:(NSTimeInterval)timeout;
- (BOOL)writeFrame:(int)fd data:(NSData *)frameData;

// ── System network info (sysctl/routing) ──
- (NSString *)getDefaultGateway;
- (NSArray<NSString *> *)getDNSServers;
- (NSDictionary *)getRoutingTable;
- (NSDictionary *)getInterfaceCounters;

@end
