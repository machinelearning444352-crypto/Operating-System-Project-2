#pragma once
// ============================================================================
// WiFiConnection.h — Connection Manager
// Handles authentication, association, DHCP, and link maintenance
// ============================================================================

#import "WiFi80211.h"
#import "WiFiHAL.h"
#import "WiFiTypes.h"
#import <Foundation/Foundation.h>

@protocol WiFiConnectionDelegate <NSObject>
@optional
- (void)connectionStateChanged:(WiFiDriverState)newState;
- (void)connectionEstablished:(WiFiConnectionState *)info;
- (void)connectionLost:(NSString *)reason;
- (void)connectionFailed:(NSString *)error;
- (void)dhcpCompleted:(NSString *)ip gateway:(NSString *)gw dns:(NSArray *)dns;
@end

@interface WiFiConnection : NSObject

@property(nonatomic, weak) id<WiFiConnectionDelegate> delegate;
@property(nonatomic, readonly) WiFiDriverState state;
@property(nonatomic, readonly, strong) WiFiConnectionState *currentConnection;
@property(nonatomic, readonly, strong) WiFiScanResult *targetNetwork;

- (instancetype)initWithHAL:(WiFiHAL *)hal;

// ── Connection lifecycle ──
- (void)connectToNetwork:(WiFiScanResult *)network
                password:(NSString *)password;
- (void)connectToOpenNetwork:(WiFiScanResult *)network;
- (void)disconnect;

// ── 802.11 Authentication state machine ──
- (void)startAuthentication:(WiFiAuthAlgorithm)algorithm;
- (void)handleAuthResponse:(NSData *)frame;
- (void)startAssociation;
- (void)handleAssocResponse:(NSData *)frame;

// ── DHCP (built from scratch) ──
- (void)startDHCP;
- (void)handleDHCPResponse:(NSData *)packet;

// ── 4-Way Handshake (WPA2/WPA3) ──
- (void)startFourWayHandshake:(NSData *)pmk;
- (void)handleEAPOLFrame:(NSData *)frame;
- (NSData *)derivePMK:(NSString *)password ssid:(NSString *)ssid;
- (NSData *)derivePTK:(NSData *)pmk
               anonce:(NSData *)anonce
               snonce:(NSData *)snonce
                   aa:(const uint8_t[6])aa
                  spa:(const uint8_t[6])spa;

// ── Link maintenance ──
- (void)sendKeepAlive;
- (BOOL)isLinkAlive;
- (double)currentRSSI;
- (WiFiConnectionState *)getConnectionInfo;

@end
