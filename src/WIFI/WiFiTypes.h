#pragma once
// ============================================================================
// WiFiTypes.h — Low-level WiFi type definitions for the VirtualOS WiFi Driver
// Built from scratch — no CoreWLAN, no Apple high-level APIs
// ============================================================================

#import <Foundation/Foundation.h>
#include <net/if.h>
#include <stdint.h>

// ─── 802.11 Constants ───────────────────────────────────────────────────────

#define WIFI_MAX_SSID_LEN 32
#define WIFI_BSSID_LEN 6
#define WIFI_MAX_CHANNELS_24 14
#define WIFI_MAX_CHANNELS_5 25
#define WIFI_MAX_CHANNELS_6 59
#define WIFI_MAX_IE_LEN 256
#define WIFI_BEACON_INTERVAL_MS 100

// 802.11 Frame Types (FC type field, bits 2-3)
typedef NS_ENUM(uint8_t, WiFiFrameType) {
  WiFiFrameTypeManagement = 0x00,
  WiFiFrameTypeControl = 0x01,
  WiFiFrameTypeData = 0x02,
  WiFiFrameTypeExtension = 0x03,
};

// 802.11 Management Frame Subtypes (FC subtype, bits 4-7)
typedef NS_ENUM(uint8_t, WiFiMgmtSubtype) {
  WiFiMgmtSubtypeAssocReq = 0x00,
  WiFiMgmtSubtypeAssocResp = 0x01,
  WiFiMgmtSubtypeReassocReq = 0x02,
  WiFiMgmtSubtypeReassocResp = 0x03,
  WiFiMgmtSubtypeProbeReq = 0x04,
  WiFiMgmtSubtypeProbeResp = 0x05,
  WiFiMgmtSubtypeBeacon = 0x08,
  WiFiMgmtSubtypeATIM = 0x09,
  WiFiMgmtSubtypeDisassoc = 0x0A,
  WiFiMgmtSubtypeAuth = 0x0B,
  WiFiMgmtSubtypeDeauth = 0x0C,
  WiFiMgmtSubtypeAction = 0x0D,
};

// Security types
typedef NS_ENUM(uint8_t, WiFiSecurityType) {
  WiFiSecurityOpen = 0,
  WiFiSecurityWEP = 1,
  WiFiSecurityWPA = 2,
  WiFiSecurityWPA2 = 3,
  WiFiSecurityWPA3 = 4,
  WiFiSecurityWPA2Enterprise = 5,
  WiFiSecurityWPA3Enterprise = 6,
};

// PHY modes (802.11 a/b/g/n/ac/ax/be)
typedef NS_ENUM(uint8_t, WiFiPHYMode) {
  WiFiPHYMode_a = 0,  // 5GHz OFDM, 54 Mbps
  WiFiPHYMode_b = 1,  // 2.4GHz DSSS, 11 Mbps
  WiFiPHYMode_g = 2,  // 2.4GHz OFDM, 54 Mbps
  WiFiPHYMode_n = 3,  // WiFi 4, HT, 600 Mbps
  WiFiPHYMode_ac = 4, // WiFi 5, VHT, 6933 Mbps
  WiFiPHYMode_ax = 5, // WiFi 6/6E, HE, 9608 Mbps
  WiFiPHYMode_be = 6, // WiFi 7, EHT, 46 Gbps
};

// Band
typedef NS_ENUM(uint8_t, WiFiBand) {
  WiFiBand_2_4GHz = 0,
  WiFiBand_5GHz = 1,
  WiFiBand_6GHz = 2,
};

// Channel width
typedef NS_ENUM(uint8_t, WiFiChannelWidth) {
  WiFiChannelWidth_20MHz = 0,
  WiFiChannelWidth_40MHz = 1,
  WiFiChannelWidth_80MHz = 2,
  WiFiChannelWidth_160MHz = 3,
  WiFiChannelWidth_320MHz = 4,
};

// Driver state machine
typedef NS_ENUM(uint8_t, WiFiDriverState) {
  WiFiDriverStateUninitialized = 0,
  WiFiDriverStateInitialized = 1,
  WiFiDriverStateScanning = 2,
  WiFiDriverStateAuthenticating = 3,
  WiFiDriverStateAssociating = 4,
  WiFiDriverStateConnected = 5,
  WiFiDriverStateDisconnecting = 6,
  WiFiDriverStatePoweredOff = 7,
  WiFiDriverStateError = 8,
};

// Auth algorithm numbers (802.11)
typedef NS_ENUM(uint16_t, WiFiAuthAlgorithm) {
  WiFiAuthAlgOpen = 0,
  WiFiAuthAlgSharedKey = 1,
  WiFiAuthAlgFastBSS = 2,
  WiFiAuthAlgSAE = 3, // WPA3
};

// ─── 802.11 Frame Structures (packed) ────────────────────────────────────

#pragma pack(push, 1)

// 802.11 MAC Header
typedef struct {
  uint16_t frameControl;
  uint16_t durationID;
  uint8_t addr1[6]; // Destination / RA
  uint8_t addr2[6]; // Source / TA
  uint8_t addr3[6]; // BSSID
  uint16_t seqControl;
} WiFi80211Header;

// Beacon/Probe Response fixed fields
typedef struct {
  uint64_t timestamp;
  uint16_t beaconInterval;
  uint16_t capabilityInfo;
} WiFiBeaconFixed;

// Authentication frame body
typedef struct {
  uint16_t authAlgorithm;
  uint16_t authSeqNum;
  uint16_t statusCode;
} WiFiAuthBody;

// Association Request fixed fields
typedef struct {
  uint16_t capabilityInfo;
  uint16_t listenInterval;
} WiFiAssocReqFixed;

// Association Response fixed fields
typedef struct {
  uint16_t capabilityInfo;
  uint16_t statusCode;
  uint16_t associationID;
} WiFiAssocRespFixed;

// Information Element header (TLV)
typedef struct {
  uint8_t elementID;
  uint8_t length;
  // variable data follows
} WiFiInfoElement;

// Radiotap header (for raw capture)
typedef struct {
  uint8_t revision;
  uint8_t pad;
  uint16_t length;
  uint32_t presentFlags;
} WiFiRadiotapHeader;

#pragma pack(pop)

// IE Element IDs
typedef NS_ENUM(uint8_t, WiFiElementID) {
  WiFiElementID_SSID = 0,
  WiFiElementID_SupportedRates = 1,
  WiFiElementID_DSParamSet = 3,
  WiFiElementID_TIM = 5,
  WiFiElementID_Country = 7,
  WiFiElementID_BSS_Load = 11,
  WiFiElementID_PowerConstraint = 32,
  WiFiElementID_HT_Capabilities = 45,
  WiFiElementID_RSN = 48,
  WiFiElementID_ExtSupportedRates = 50,
  WiFiElementID_HT_Operation = 61,
  WiFiElementID_VHT_Capabilities = 191,
  WiFiElementID_VHT_Operation = 192,
  WiFiElementID_VendorSpecific = 221,
  WiFiElementID_Extension = 255,
};

// ─── High-Level Scan Result ─────────────────────────────────────────────

@interface WiFiScanResult : NSObject
@property(nonatomic, strong) NSString *ssid;
@property(nonatomic, copy) NSData *bssid;  // 6-byte MAC
@property(nonatomic, assign) int8_t rssi;  // dBm (-30 to -100)
@property(nonatomic, assign) int8_t noise; // dBm
@property(nonatomic, assign) uint16_t channel;
@property(nonatomic, assign) WiFiBand band;
@property(nonatomic, assign) WiFiChannelWidth channelWidth;
@property(nonatomic, assign) WiFiPHYMode phyMode;
@property(nonatomic, assign) WiFiSecurityType security;
@property(nonatomic, assign) uint16_t beaconInterval;
@property(nonatomic, assign) double txRate; // Mbps
@property(nonatomic, assign) BOOL isHidden;
@property(nonatomic, strong) NSDate *lastSeen;
@property(nonatomic, strong) NSString *countryCode;
@property(nonatomic, strong) NSString *bssidString; // "AA:BB:CC:DD:EE:FF"

- (NSString *)securityString;
- (NSString *)phyModeString;
- (NSString *)bandString;
- (NSString *)channelWidthString;
- (NSInteger)signalQuality; // 0-100%
@end

// ─── Interface Info ─────────────────────────────────────────────────────

@interface WiFiInterfaceInfo : NSObject
@property(nonatomic, strong) NSString *name;        // e.g. "en0"
@property(nonatomic, strong) NSString *hardwareMAC; // permanent MAC
@property(nonatomic, strong) NSString *currentMAC;  // current (may differ)
@property(nonatomic, assign) uint32_t mtu;
@property(nonatomic, assign) uint32_t flags; // IFF_ flags
@property(nonatomic, strong) NSString *ipv4;
@property(nonatomic, strong) NSString *ipv6;
@property(nonatomic, strong) NSString *netmask;
@property(nonatomic, strong) NSString *broadcast;
@property(nonatomic, strong) NSString *gateway;
@property(nonatomic, strong) NSArray<NSString *> *dns;
@property(nonatomic, assign) BOOL isUp;
@property(nonatomic, assign) BOOL isRunning;
@property(nonatomic, assign) BOOL supportsWiFi;
@end

// ─── Connection State ───────────────────────────────────────────────────

@interface WiFiConnectionState : NSObject
@property(nonatomic, assign) WiFiDriverState state;
@property(nonatomic, strong) WiFiScanResult *associatedNetwork;
@property(nonatomic, strong) NSString *ipAddress;
@property(nonatomic, strong) NSString *subnetMask;
@property(nonatomic, strong) NSString *gateway;
@property(nonatomic, strong) NSArray<NSString *> *dnsServers;
@property(nonatomic, assign) double txRate;
@property(nonatomic, assign) NSTimeInterval uptime;
@property(nonatomic, assign) uint64_t txBytes;
@property(nonatomic, assign) uint64_t rxBytes;
@property(nonatomic, assign) uint64_t txPackets;
@property(nonatomic, assign) uint64_t rxPackets;
@end
