#pragma once
// ============================================================================
// USBDriver.h — USB Driver Interface
// IOKit-based USB device enumeration, hotplug, and data transfer
// ============================================================================

#import "USBTypes.h"
#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

@protocol USBDriverDelegate <NSObject>
@optional
- (void)usbDriverReady:(NSUInteger)deviceCount;
- (void)usbDeviceAttached:(USBDevice *)device;
- (void)usbDeviceDetached:(USBDevice *)device;
- (void)usbTransferComplete:(USBDevice *)device
                   endpoint:(uint8_t)ep
                       data:(NSData *)data
                    success:(BOOL)ok;
- (void)usbError:(NSString *)error;
@end

@interface USBDriver : NSObject

@property(nonatomic, weak) id<USBDriverDelegate> delegate;
@property(nonatomic, readonly) USBDriverState state;

+ (instancetype)sharedInstance;

// ── Lifecycle ──
- (BOOL)start;
- (void)stop;
- (BOOL)isRunning;

// ── Device Enumeration ──
- (NSArray<USBDevice *> *)allDevices;
- (NSArray<USBDevice *> *)externalDevices; // Exclude internal
- (USBDevice *)deviceWithVendor:(uint16_t)vid product:(uint16_t)pid;
- (USBDevice *)deviceAtLocation:(uint32_t)locationID;
- (void)refreshDeviceList;

// ── Hotplug ──
- (void)startHotplugMonitoring;
- (void)stopHotplugMonitoring;

// ── Device Operations ──
- (BOOL)resetDevice:(USBDevice *)device;
- (NSData *)getDescriptor:(USBDevice *)device
                     type:(USBDescriptorType)type
                    index:(uint8_t)idx;
- (NSString *)getStringDescriptor:(USBDevice *)device index:(uint8_t)idx;

// ── Data Transfer ──
- (void)controlTransfer:(USBDevice *)device
                  setup:(USBSetupPacket)setup
                   data:(NSData *)data
             completion:(USBTransferCompletion)completion;
- (void)bulkTransfer:(USBDevice *)device
            endpoint:(uint8_t)ep
                data:(NSData *)data
             timeout:(uint32_t)timeoutMs
          completion:(USBTransferCompletion)completion;
- (void)interruptTransfer:(USBDevice *)device
                 endpoint:(uint8_t)ep
                   length:(uint16_t)len
               completion:(USBTransferCompletion)completion;

// ── Diagnostics ──
- (NSDictionary *)driverDiagnostics;
- (NSArray<USBHub *> *)usbTopology;

@end
