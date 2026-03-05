#pragma once
// ============================================================================
// BluetoothHCI.h — HCI (Host Controller Interface) Layer
// Builds and parses HCI commands/events for direct controller communication
// ============================================================================

#import "BluetoothTypes.h"
#import <Foundation/Foundation.h>

@protocol BluetoothHCIDelegate <NSObject>
@optional
- (void)hciDidReceiveEvent:(BTHCIEventCode)code data:(NSData *)data;
- (void)hciDeviceDiscovered:(BTDevice *)device;
- (void)hciConnectionComplete:(uint16_t)handle
                      address:(NSString *)addr
                       status:(uint8_t)status;
- (void)hciDisconnectComplete:(uint16_t)handle reason:(uint8_t)reason;
- (void)hciPINCodeRequest:(NSString *)address;
- (void)hciUserConfirmRequest:(NSString *)address passkey:(uint32_t)passkey;
- (void)hciPairingComplete:(NSString *)address success:(BOOL)success;
- (void)hciError:(NSString *)message;
@end

@interface BluetoothHCI : NSObject

@property(nonatomic, weak) id<BluetoothHCIDelegate> delegate;
@property(nonatomic, readonly) BOOL isOpen;
@property(nonatomic, readonly, strong) BTControllerInfo *controllerInfo;

// ── Lifecycle ──
- (BOOL)open;
- (void)close;

// ── Command Building ──
+ (NSData *)buildCommand:(uint16_t)opcode params:(NSData *)params;
+ (NSData *)buildInquiryCommand:(uint32_t)lap
                   maxResponses:(uint8_t)max
                  durationUnits:(uint8_t)dur;
+ (NSData *)buildInquiryCancelCommand;
+ (NSData *)buildCreateConnectionCommand:(const uint8_t[6])addr;
+ (NSData *)buildDisconnectCommand:(uint16_t)handle reason:(uint8_t)reason;
+ (NSData *)buildRemoteNameRequest:(const uint8_t[6])addr;
+ (NSData *)buildPINCodeReply:(const uint8_t[6])addr pin:(NSString *)pin;
+ (NSData *)buildResetCommand;
+ (NSData *)buildReadBDAddrCommand;
+ (NSData *)buildReadLocalVersionCommand;
+ (NSData *)buildReadLocalFeaturesCommand;
+ (NSData *)buildWriteLocalName:(NSString *)name;
+ (NSData *)buildWriteScanEnable:(uint8_t)mode;
+ (NSData *)buildWriteClassOfDevice:(uint32_t)cod;

// LE Commands
+ (NSData *)buildLESetScanParams:(uint8_t)type
                        interval:(uint16_t)interval
                          window:(uint16_t)window
                     ownAddrType:(uint8_t)own
                    filterPolicy:(uint8_t)filter;
+ (NSData *)buildLESetScanEnable:(BOOL)enable filterDuplicates:(BOOL)filterDup;
+ (NSData *)buildLECreateConnection:(const uint8_t[6])addr
                           addrType:(uint8_t)type;

// ── Event Parsing ──
+ (BTHCIEventCode)parseEventCode:(NSData *)event;
+ (NSData *)parseEventParams:(NSData *)event;
+ (BTInquiryResult)parseInquiryResult:(NSData *)params;
+ (BTInquiryResultRSSI)parseInquiryResultRSSI:(NSData *)params;
+ (BTConnectionComplete)parseConnectionComplete:(NSData *)params;
+ (BTControllerInfo *)parseLocalVersion:(NSData *)params;
+ (NSString *)parseBDAddr:(NSData *)params;
+ (NSString *)parseRemoteName:(NSData *)params;
+ (NSArray<BTDevice *> *)parseLEAdvertisingReport:(NSData *)params;

// ── Send Command ──
- (BOOL)sendCommand:(NSData *)command;
- (BOOL)sendCommand:(uint16_t)opcode params:(NSData *)params;

// ── IOKit HCI Transport ──
- (BTControllerInfo *)readControllerInfo;
- (NSString *)readBDAddress;

// ── Utility ──
+ (NSString *)addressToString:(const uint8_t[6])addr;
+ (void)stringToAddress:(NSString *)str output:(uint8_t[6])addr;
+ (NSString *)opcodeDescription:(uint16_t)opcode;
+ (NSString *)eventDescription:(BTHCIEventCode)code;

@end
