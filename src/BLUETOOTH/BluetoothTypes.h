#pragma once
// ============================================================================
// BluetoothTypes.h — Low-level Bluetooth type definitions
// Built from scratch — no IOBluetooth framework
// ============================================================================

#import <Foundation/Foundation.h>
#include <stdint.h>

// ─── Bluetooth Constants ────────────────────────────────────────────────

#define BT_ADDR_LEN 6
#define BT_NAME_MAX 248
#define BT_PIN_MAX 16
#define BT_CLASS_LEN 3
#define BT_UUID_16_LEN 2
#define BT_UUID_128_LEN 16
#define BT_HCI_MAX_CMD_LEN 258
#define BT_HCI_MAX_EVT_LEN 260

// ─── HCI Packet Types ──────────────────────────────────────────────────

typedef NS_ENUM(uint8_t, BTHCIPacketType) {
  BTHCIPacketCommand = 0x01,
  BTHCIPacketACLData = 0x02,
  BTHCIPacketSCOData = 0x03,
  BTHCIPacketEvent = 0x04,
  BTHCIPacketISO = 0x05,
};

// ─── HCI Command OpCode Groups (OGF) ───────────────────────────────────

typedef NS_ENUM(uint8_t, BTHCIOGFGroup) {
  BTOGFLinkControl = 0x01,
  BTOGFLinkPolicy = 0x02,
  BTOGFControllerBaseband = 0x03,
  BTOGFInformational = 0x04,
  BTOGFStatusParams = 0x05,
  BTOGFTesting = 0x06,
  BTOGFLEController = 0x08,
};

// ─── HCI Command OpCodes (OGF << 10 | OCF) ─────────────────────────────

#define BT_HCI_OP(ogf, ocf) ((uint16_t)((ogf) << 10) | (ocf))

// Link Control
#define HCI_OP_INQUIRY BT_HCI_OP(0x01, 0x0001)
#define HCI_OP_INQUIRY_CANCEL BT_HCI_OP(0x01, 0x0002)
#define HCI_OP_CREATE_CONN BT_HCI_OP(0x01, 0x0005)
#define HCI_OP_DISCONNECT BT_HCI_OP(0x01, 0x0006)
#define HCI_OP_ACCEPT_CONN_REQ BT_HCI_OP(0x01, 0x0009)
#define HCI_OP_REJECT_CONN_REQ BT_HCI_OP(0x01, 0x000A)
#define HCI_OP_LINK_KEY_REPLY BT_HCI_OP(0x01, 0x000B)
#define HCI_OP_PIN_CODE_REPLY BT_HCI_OP(0x01, 0x000D)
#define HCI_OP_AUTH_REQUESTED BT_HCI_OP(0x01, 0x0011)
#define HCI_OP_SET_CONN_ENCRYPT BT_HCI_OP(0x01, 0x0013)
#define HCI_OP_REMOTE_NAME_REQ BT_HCI_OP(0x01, 0x0019)
#define HCI_OP_READ_REMOTE_FEATURES BT_HCI_OP(0x01, 0x001B)

// Controller & Baseband
#define HCI_OP_RESET BT_HCI_OP(0x03, 0x0003)
#define HCI_OP_WRITE_SCAN_ENABLE BT_HCI_OP(0x03, 0x001A)
#define HCI_OP_WRITE_CLASS_OF_DEVICE BT_HCI_OP(0x03, 0x0024)
#define HCI_OP_WRITE_LOCAL_NAME BT_HCI_OP(0x03, 0x0013)
#define HCI_OP_READ_LOCAL_NAME BT_HCI_OP(0x03, 0x0014)
#define HCI_OP_WRITE_PAGE_TIMEOUT BT_HCI_OP(0x03, 0x0018)
#define HCI_OP_WRITE_INQ_MODE BT_HCI_OP(0x03, 0x0045)

// Informational
#define HCI_OP_READ_BD_ADDR BT_HCI_OP(0x04, 0x0009)
#define HCI_OP_READ_LOCAL_VERSION BT_HCI_OP(0x04, 0x0001)
#define HCI_OP_READ_LOCAL_FEATURES BT_HCI_OP(0x04, 0x0003)
#define HCI_OP_READ_BUFFER_SIZE BT_HCI_OP(0x04, 0x0005)

// LE Controller
#define HCI_OP_LE_SET_SCAN_PARAMS BT_HCI_OP(0x08, 0x000B)
#define HCI_OP_LE_SET_SCAN_ENABLE BT_HCI_OP(0x08, 0x000C)
#define HCI_OP_LE_CREATE_CONN BT_HCI_OP(0x08, 0x000D)
#define HCI_OP_LE_SET_ADV_PARAMS BT_HCI_OP(0x08, 0x0006)
#define HCI_OP_LE_SET_ADV_DATA BT_HCI_OP(0x08, 0x0008)
#define HCI_OP_LE_SET_ADV_ENABLE BT_HCI_OP(0x08, 0x000A)

// ─── HCI Event Codes ────────────────────────────────────────────────────

typedef NS_ENUM(uint8_t, BTHCIEventCode) {
  BTEventInquiryComplete = 0x01,
  BTEventInquiryResult = 0x02,
  BTEventConnectionComplete = 0x03,
  BTEventConnectionRequest = 0x04,
  BTEventDisconnectComplete = 0x05,
  BTEventAuthComplete = 0x06,
  BTEventRemoteNameReqComplete = 0x07,
  BTEventEncryptionChange = 0x08,
  BTEventCommandComplete = 0x0E,
  BTEventCommandStatus = 0x0F,
  BTEventPINCodeRequest = 0x16,
  BTEventLinkKeyRequest = 0x17,
  BTEventLinkKeyNotification = 0x18,
  BTEventInquiryResultRSSI = 0x22,
  BTEventExtendedInquiryResult = 0x2F,
  BTEventLEMeta = 0x3E,
  BTEventIOCapabilityRequest = 0x31,
  BTEventUserConfirmRequest = 0x33,
  BTEventSimplePairingComplete = 0x36,
};

// LE Sub-events
typedef NS_ENUM(uint8_t, BTLESubevent) {
  BTLEConnectionComplete = 0x01,
  BTLEAdvertisingReport = 0x02,
  BTLEConnectionUpdateComplete = 0x03,
  BTLEReadRemoteFeaturesComplete = 0x04,
  BTLELongTermKeyRequest = 0x05,
};

// ─── Device Major Classes ───────────────────────────────────────────────

typedef NS_ENUM(uint8_t, BTDeviceMajorClass) {
  BTMajorMisc = 0x00,
  BTMajorComputer = 0x01,
  BTMajorPhone = 0x02,
  BTMajorNetworking = 0x03,
  BTMajorAudioVideo = 0x04,
  BTMajorPeripheral = 0x05,
  BTMajorImaging = 0x06,
  BTMajorWearable = 0x07,
  BTMajorToy = 0x08,
  BTMajorHealth = 0x09,
  BTMajorUncategorized = 0x1F,
};

// ─── Connection/Pairing State ───────────────────────────────────────────

typedef NS_ENUM(uint8_t, BTDeviceState) {
  BTDeviceStateDisconnected = 0,
  BTDeviceStateConnecting = 1,
  BTDeviceStateConnected = 2,
  BTDeviceStatePairing = 3,
  BTDeviceStatePaired = 4,
  BTDeviceStateBonded = 5,
};

typedef NS_ENUM(uint8_t, BTDriverState) {
  BTDriverStateOff = 0,
  BTDriverStateInitializing = 1,
  BTDriverStateReady = 2,
  BTDriverStateDiscovering = 3,
  BTDriverStateError = 4,
};

// BLE Address Types
typedef NS_ENUM(uint8_t, BTAddressType) {
  BTAddressPublic = 0x00,
  BTAddressRandom = 0x01,
  BTAddressPublicID = 0x02,
  BTAddressRandomStatic = 0x03,
};

// ─── HCI Packed Structures ──────────────────────────────────────────────

#pragma pack(push, 1)

typedef struct {
  uint8_t addr[6];
} BTAddress;

typedef struct {
  uint16_t opcode;
  uint8_t paramLen;
  // params follow
} BTHCICommandHeader;

typedef struct {
  uint8_t eventCode;
  uint8_t paramLen;
  // params follow
} BTHCIEventHeader;

typedef struct {
  uint16_t handle; // 12-bit handle + 2-bit PB + 2-bit BC
  uint16_t dataLen;
  // data follows
} BTHCIACLHeader;

// Inquiry Result
typedef struct {
  uint8_t numResponses;
  uint8_t bdAddr[6];
  uint8_t pageScanRepMode;
  uint8_t reserved1;
  uint8_t reserved2;
  uint8_t classOfDevice[3];
  uint16_t clockOffset;
} BTInquiryResult;

// Inquiry Result with RSSI
typedef struct {
  uint8_t numResponses;
  uint8_t bdAddr[6];
  uint8_t pageScanRepMode;
  uint8_t reserved;
  uint8_t classOfDevice[3];
  uint16_t clockOffset;
  int8_t rssi;
} BTInquiryResultRSSI;

// Connection Complete
typedef struct {
  uint8_t status;
  uint16_t handle;
  uint8_t bdAddr[6];
  uint8_t linkType;
  uint8_t encEnabled;
} BTConnectionComplete;

// LE Advertising Report
typedef struct {
  uint8_t eventType;
  uint8_t addressType;
  uint8_t address[6];
  uint8_t dataLength;
  // ad data + rssi follow
} BTLEAdvReport;

#pragma pack(pop)

// ─── High-Level Device Model ────────────────────────────────────────────

@interface BTDevice : NSObject
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSString *address; // "AA:BB:CC:DD:EE:FF"
@property(nonatomic, assign) BTDeviceMajorClass majorClass;
@property(nonatomic, assign) uint32_t classOfDevice;
@property(nonatomic, assign) int8_t rssi;
@property(nonatomic, assign) BTDeviceState state;
@property(nonatomic, assign) BTAddressType addressType;
@property(nonatomic, assign) uint16_t connectionHandle;
@property(nonatomic, assign) BOOL isBLE;
@property(nonatomic, assign) BOOL isPaired;
@property(nonatomic, assign) BOOL isConnected;
@property(nonatomic, assign) int batteryLevel; // 0-100 or -1
@property(nonatomic, strong) NSDate *lastSeen;
@property(nonatomic, strong) NSArray<NSString *> *services; // UUIDs
@property(nonatomic, strong) NSData *rawAddress;            // 6 bytes
@property(nonatomic, strong) NSDictionary *manufacturerData;

- (NSString *)majorClassName;
- (NSString *)stateString;
- (NSString *)deviceIcon; // SF Symbol name
@end

// ─── Controller Info ────────────────────────────────────────────────────

@interface BTControllerInfo : NSObject
@property(nonatomic, strong) NSString *address;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSString *manufacturer;
@property(nonatomic, assign) uint8_t hciVersionMajor;
@property(nonatomic, assign) uint16_t hciRevision;
@property(nonatomic, assign) uint8_t lmpVersion;
@property(nonatomic, assign) uint16_t lmpSubversion;
@property(nonatomic, assign) uint16_t manufacturer_id;
@property(nonatomic, assign) BOOL supportsLE;
@property(nonatomic, assign) BOOL supportsBREDR;
@property(nonatomic, assign) BOOL supportsSSP; // Secure Simple Pairing
@property(nonatomic, assign) uint16_t aclBufferSize;
@property(nonatomic, assign) uint8_t scoBufferSize;
@property(nonatomic, assign) uint16_t numACLBuffers;
@property(nonatomic, assign) uint16_t numSCOBuffers;
@end

// ─── Callbacks ──────────────────────────────────────────────────────────

typedef void (^BTScanCompletion)(NSArray<BTDevice *> *devices);
typedef void (^BTConnectCompletion)(BOOL success, NSString *error);
typedef void (^BTPairCompletion)(BOOL success, NSString *error);
typedef void (^BTDataCallback)(NSData *data, uint16_t handle);
