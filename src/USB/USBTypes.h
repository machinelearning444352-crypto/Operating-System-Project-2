#pragma once
// ============================================================================
// USBTypes.h — USB Type Definitions & Descriptor Structures
// Built from scratch — no IOUSBHostFamily
// ============================================================================

#import <Foundation/Foundation.h>
#include <stdint.h>

// ─── USB Constants ──────────────────────────────────────────────────────

#define USB_MAX_ENDPOINTS 32
#define USB_MAX_INTERFACES 32
#define USB_CONTROL_PIPE 0

// ─── USB Descriptor Types ───────────────────────────────────────────────

typedef NS_ENUM(uint8_t, USBDescriptorType) {
  USBDescDevice = 0x01,
  USBDescConfiguration = 0x02,
  USBDescString = 0x03,
  USBDescInterface = 0x04,
  USBDescEndpoint = 0x05,
  USBDescDeviceQual = 0x06,
  USBDescOtherSpeed = 0x07,
  USBDescInterfacePower = 0x08,
  USBDescOTG = 0x09,
  USBDescHID = 0x21,
  USBDescReport = 0x22,
  USBDescPhysical = 0x23,
  USBDescHub = 0x29,
  USBDescSuperSpeedHub = 0x2A,
  USBDescBOS = 0x0F,
};

// ─── USB Transfer Types ─────────────────────────────────────────────────

typedef NS_ENUM(uint8_t, USBTransferType) {
  USBTransferControl = 0x00,
  USBTransferIsochronous = 0x01,
  USBTransferBulk = 0x02,
  USBTransferInterrupt = 0x03,
};

// ─── USB Speed ──────────────────────────────────────────────────────────

typedef NS_ENUM(uint8_t, USBSpeed) {
  USBSpeedLow = 0,       // 1.5 Mbps
  USBSpeedFull = 1,      // 12 Mbps
  USBSpeedHigh = 2,      // 480 Mbps
  USBSpeedSuper = 3,     // 5 Gbps
  USBSpeedSuperPlus = 4, // 10 Gbps
};

// ─── USB Device Class Codes ─────────────────────────────────────────────

typedef NS_ENUM(uint8_t, USBDeviceClass) {
  USBClassPerInterface = 0x00,
  USBClassAudio = 0x01,
  USBClassCDCControl = 0x02,
  USBClassHID = 0x03,
  USBClassPhysical = 0x05,
  USBClassImage = 0x06,
  USBClassPrinter = 0x07,
  USBClassMassStorage = 0x08,
  USBClassHub = 0x09,
  USBClassCDCData = 0x0A,
  USBClassSmartCard = 0x0B,
  USBClassContentSec = 0x0D,
  USBClassVideo = 0x0E,
  USBClassHealthcare = 0x0F,
  USBClassAV = 0x10,
  USBClassBillboard = 0x11,
  USBClassTypeCBridge = 0x12,
  USBClassBulkDisplay = 0x13,
  USBClassWireless = 0xE0,
  USBClassMisc = 0xEF,
  USBClassAppSpecific = 0xFE,
  USBClassVendorSpec = 0xFF,
};

// ─── Connection State ───────────────────────────────────────────────────

typedef NS_ENUM(uint8_t, USBDeviceState) {
  USBDeviceDetached = 0,
  USBDeviceAttached = 1,
  USBDeviceAddressed = 2,
  USBDeviceConfigured = 3,
  USBDeviceSuspended = 4,
  USBDeviceError = 5,
};

typedef NS_ENUM(uint8_t, USBDriverState) {
  USBDriverOff = 0,
  USBDriverInitializing = 1,
  USBDriverReady = 2,
  USBDriverError = 3,
};

// ─── Packed Descriptor Structures ───────────────────────────────────────

#pragma pack(push, 1)

typedef struct {
  uint8_t bLength;
  uint8_t bDescriptorType;
  uint16_t bcdUSB;
  uint8_t bDeviceClass;
  uint8_t bDeviceSubClass;
  uint8_t bDeviceProtocol;
  uint8_t bMaxPacketSize0;
  uint16_t idVendor;
  uint16_t idProduct;
  uint16_t bcdDevice;
  uint8_t iManufacturer;
  uint8_t iProduct;
  uint8_t iSerialNumber;
  uint8_t bNumConfigurations;
} USBDeviceDescriptor;

typedef struct {
  uint8_t bLength;
  uint8_t bDescriptorType;
  uint16_t wTotalLength;
  uint8_t bNumInterfaces;
  uint8_t bConfigurationValue;
  uint8_t iConfiguration;
  uint8_t bmAttributes;
  uint8_t bMaxPower;
} USBConfigDescriptor;

typedef struct {
  uint8_t bLength;
  uint8_t bDescriptorType;
  uint8_t bInterfaceNumber;
  uint8_t bAlternateSetting;
  uint8_t bNumEndpoints;
  uint8_t bInterfaceClass;
  uint8_t bInterfaceSubClass;
  uint8_t bInterfaceProtocol;
  uint8_t iInterface;
} USBInterfaceDescriptor;

typedef struct {
  uint8_t bLength;
  uint8_t bDescriptorType;
  uint8_t bEndpointAddress;
  uint8_t bmAttributes;
  uint16_t wMaxPacketSize;
  uint8_t bInterval;
} USBEndpointDescriptor;

typedef struct {
  uint8_t bmRequestType;
  uint8_t bRequest;
  uint16_t wValue;
  uint16_t wIndex;
  uint16_t wLength;
} USBSetupPacket;

#pragma pack(pop)

// ─── High-Level Device Model ────────────────────────────────────────────

@interface USBEndpoint : NSObject
@property(nonatomic, assign) uint8_t address;
@property(nonatomic, assign) USBTransferType transferType;
@property(nonatomic, assign) uint16_t maxPacketSize;
@property(nonatomic, assign) uint8_t interval;
@property(nonatomic, assign) BOOL isInput;
@end

@interface USBInterface : NSObject
@property(nonatomic, assign) uint8_t number;
@property(nonatomic, assign) uint8_t alternateSetting;
@property(nonatomic, assign) USBDeviceClass interfaceClass;
@property(nonatomic, assign) uint8_t subClass;
@property(nonatomic, assign) uint8_t protocol;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSArray<USBEndpoint *> *endpoints;
@end

@interface USBDevice : NSObject
@property(nonatomic, assign) uint16_t vendorID;
@property(nonatomic, assign) uint16_t productID;
@property(nonatomic, assign) uint16_t bcdDevice;
@property(nonatomic, assign) USBDeviceClass deviceClass;
@property(nonatomic, assign) uint8_t subClass;
@property(nonatomic, assign) uint8_t protocol;
@property(nonatomic, assign) USBSpeed speed;
@property(nonatomic, assign) USBDeviceState state;
@property(nonatomic, assign) uint32_t locationID;
@property(nonatomic, assign) uint8_t portNumber;
@property(nonatomic, assign) uint8_t busNumber;
@property(nonatomic, assign) uint8_t deviceAddress;
@property(nonatomic, assign) uint16_t bcdUSB;
@property(nonatomic, assign) uint8_t maxPower; // in 2mA units
@property(nonatomic, strong) NSString *manufacturer;
@property(nonatomic, strong) NSString *product;
@property(nonatomic, strong) NSString *serialNumber;
@property(nonatomic, strong) NSArray<USBInterface *> *interfaces;
@property(nonatomic, assign) io_service_t service;
@property(nonatomic, strong) NSDate *attachedAt;

- (NSString *)vendorIDHex;
- (NSString *)productIDHex;
- (NSString *)speedString;
- (NSString *)classString;
- (NSString *)stateString;
- (NSString *)powerString; // Max power in mA
- (NSString *)deviceIcon;
@end

// ─── USB Hub ────────────────────────────────────────────────────────────

@interface USBHub : NSObject
@property(nonatomic, assign) uint8_t portCount;
@property(nonatomic, assign) BOOL isPowered;
@property(nonatomic, assign) uint32_t locationID;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSMutableArray<USBDevice *> *devices;
@end

// ─── Callbacks ──────────────────────────────────────────────────────────

typedef void (^USBTransferCompletion)(NSData *data, BOOL success,
                                      NSString *error);
typedef void (^USBHotplugCallback)(USBDevice *device, BOOL attached);
