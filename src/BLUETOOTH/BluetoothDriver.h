#pragma once
// ============================================================================
// BluetoothDriver.h — Main Bluetooth Driver Interface
// Orchestrates HCI, device discovery, pairing, and data transfer
// ============================================================================

#import "BluetoothHCI.h"
#import "BluetoothTypes.h"
#import <Foundation/Foundation.h>

@protocol BluetoothDriverDelegate <NSObject>
@optional
- (void)bluetoothReady:(BTControllerInfo *)info;
- (void)bluetoothDeviceFound:(BTDevice *)device;
- (void)bluetoothScanComplete:(NSArray<BTDevice *> *)devices;
- (void)bluetoothConnected:(BTDevice *)device;
- (void)bluetoothDisconnected:(BTDevice *)device reason:(NSString *)reason;
- (void)bluetoothPaired:(BTDevice *)device;
- (void)bluetoothPairFailed:(BTDevice *)device error:(NSString *)error;
- (void)bluetoothPINRequested:(BTDevice *)device;
- (void)bluetoothConfirmPasskey:(BTDevice *)device passkey:(uint32_t)key;
- (void)bluetoothError:(NSString *)error;
- (void)bluetoothDataReceived:(NSData *)data from:(BTDevice *)device;
@end

@interface BluetoothDriver : NSObject <BluetoothHCIDelegate>

@property(nonatomic, weak) id<BluetoothDriverDelegate> delegate;
@property(nonatomic, readonly, strong) BluetoothHCI *hci;
@property(nonatomic, readonly) BTDriverState state;
@property(nonatomic, readonly, strong) BTControllerInfo *controllerInfo;

+ (instancetype)sharedInstance;

// ── Lifecycle ──
- (BOOL)start;
- (void)stop;
- (BOOL)isRunning;

// ── Power ──
- (BOOL)setPower:(BOOL)on;
- (BOOL)isPowered;

// ── Discovery ──
- (void)startDiscovery;
- (void)startBLEDiscovery;
- (void)stopDiscovery;
- (BOOL)isDiscovering;
- (NSArray<BTDevice *> *)discoveredDevices;
- (NSArray<BTDevice *> *)pairedDevices;

// ── Connection ──
- (void)connectDevice:(BTDevice *)device;
- (void)disconnectDevice:(BTDevice *)device;

// ── Pairing ──
- (void)pairDevice:(BTDevice *)device;
- (void)unpairDevice:(BTDevice *)device;
- (void)respondPIN:(NSString *)pin forDevice:(BTDevice *)device;
- (void)confirmPasskey:(BOOL)accept forDevice:(BTDevice *)device;

// ── Data Transfer ──
- (void)sendData:(NSData *)data toDevice:(BTDevice *)device;

// ── Info ──
- (BTDevice *)deviceWithAddress:(NSString *)address;
- (NSDictionary *)driverDiagnostics;
- (NSString *)stateDescription;

@end
