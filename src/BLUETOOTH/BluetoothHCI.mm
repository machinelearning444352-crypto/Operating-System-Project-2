#import "BluetoothHCI.h"
#import <IOKit/IOKitLib.h>
#include <string.h>

// ============================================================================
// BluetoothHCI.mm — HCI Layer Implementation
// Builds/parses HCI commands and events, communicates via IOKit
// ============================================================================

@interface BluetoothHCI ()
@property(nonatomic, readwrite) BOOL isOpen;
@property(nonatomic, readwrite, strong) BTControllerInfo *controllerInfo;
@property(nonatomic, assign) io_object_t btController;
@property(nonatomic, assign) io_connect_t btConnection;
@property(nonatomic, strong) dispatch_queue_t hciQueue;
@end

@implementation BluetoothHCI

#pragma mark - Lifecycle

- (BOOL)open {
  NSLog(@"[BluetoothHCI] Opening HCI transport...");
  self.hciQueue =
      dispatch_queue_create("com.virtualos.bt.hci", DISPATCH_QUEUE_SERIAL);

  // Find Bluetooth controller in IOKit registry
  CFMutableDictionaryRef matching =
      IOServiceMatching("IOBluetoothHCIController");
  if (!matching) {
    matching = IOServiceMatching("BroadcomBluetoothHostController");
  }
  if (!matching) {
    NSLog(@"[BluetoothHCI] No matching dictionary for BT controller");
    return NO;
  }

  io_iterator_t iterator;
  kern_return_t kr =
      IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator);
  if (kr != KERN_SUCCESS) {
    NSLog(@"[BluetoothHCI] IOServiceGetMatchingServices failed: 0x%x", kr);
    return NO;
  }

  self.btController = IOIteratorNext(iterator);
  IOObjectRelease(iterator);

  if (!self.btController) {
    NSLog(@"[BluetoothHCI] No Bluetooth controller found");
    return NO;
  }

  io_name_t className;
  IOObjectGetClass(self.btController, className);
  NSLog(@"[BluetoothHCI] Found controller: %s", className);

  // Read controller properties
  self.controllerInfo = [self readControllerInfo];
  self.isOpen = YES;
  NSLog(@"[BluetoothHCI] HCI open. Address: %@", self.controllerInfo.address);
  return YES;
}

- (void)close {
  if (self.btConnection) {
    IOServiceClose(self.btConnection);
    self.btConnection = 0;
  }
  if (self.btController) {
    IOObjectRelease(self.btController);
    self.btController = 0;
  }
  self.isOpen = NO;
  NSLog(@"[BluetoothHCI] Closed");
}

#pragma mark - Controller Info (IOKit)

- (BTControllerInfo *)readControllerInfo {
  BTControllerInfo *info = [BTControllerInfo new];

  if (!self.btController)
    return info;

  CFMutableDictionaryRef props = nil;
  kern_return_t kr = IORegistryEntryCreateCFProperties(
      self.btController, &props, kCFAllocatorDefault, kNilOptions);
  if (kr != KERN_SUCCESS || !props)
    return info;

  NSDictionary *dict = (__bridge_transfer NSDictionary *)props;

  // Extract BT address
  NSData *addrData = dict[@"BluetoothAddress"] ?: dict[@"BTAddress"];
  if (addrData && addrData.length >= 6) {
    const uint8_t *bytes = (const uint8_t *)addrData.bytes;
    info.address = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
                                              bytes[5], bytes[4], bytes[3],
                                              bytes[2], bytes[1], bytes[0]];
  } else {
    info.address = @"00:00:00:00:00:00";
  }

  // Controller name
  info.name = dict[@"BluetoothDeviceName"] ?: dict[@"IOName"] ?: @"Bluetooth Controller";

  // Version info
  NSNumber *hciVer = dict[@"HCIVersion"];
  NSNumber *hciRev = dict[@"HCIRevision"];
  NSNumber *lmpVer = dict[@"LMPVersion"];
  NSNumber *lmpSub = dict[@"LMPSubversion"];
  NSNumber *mfg = dict[@"Manufacturer"];

  if (hciVer)
    info.hciVersionMajor = hciVer.unsignedCharValue;
  if (hciRev)
    info.hciRevision = hciRev.unsignedShortValue;
  if (lmpVer)
    info.lmpVersion = lmpVer.unsignedCharValue;
  if (lmpSub)
    info.lmpSubversion = lmpSub.unsignedShortValue;
  if (mfg) {
    info.manufacturer_id = mfg.unsignedShortValue;
    switch (info.manufacturer_id) {
    case 15:
      info.manufacturer = @"Broadcom";
      break;
    case 29:
      info.manufacturer = @"Qualcomm";
      break;
    case 2:
      info.manufacturer = @"Intel";
      break;
    case 18:
      info.manufacturer = @"Cypress";
      break;
    case 76:
      info.manufacturer = @"Apple";
      break;
    case 93:
      info.manufacturer = @"Realtek";
      break;
    default:
      info.manufacturer =
          [NSString stringWithFormat:@"ID %d", info.manufacturer_id];
    }
  }

  // Features
  NSData *features = dict[@"LMPFeatures"];
  if (features && features.length >= 8) {
    const uint8_t *f = (const uint8_t *)features.bytes;
    info.supportsBREDR = YES;
    info.supportsSSP = (f[6] & 0x08) != 0;
    info.supportsLE = (f[4] & 0x40) != 0;
  }

  // Buffer sizes
  NSNumber *aclBuf = dict[@"ACLPacketSize"];
  NSNumber *scoBuf = dict[@"SCOPacketSize"];
  if (aclBuf)
    info.aclBufferSize = aclBuf.unsignedShortValue;
  if (scoBuf)
    info.scoBufferSize = scoBuf.unsignedCharValue;

  NSLog(@"[BluetoothHCI] Controller: %@ (%@), HCI v%d, LMP v%d, %@", info.name,
        info.manufacturer ?: @"Unknown", info.hciVersionMajor, info.lmpVersion,
        info.supportsLE ? @"BLE supported" : @"Classic only");

  return info;
}

- (NSString *)readBDAddress {
  return self.controllerInfo.address;
}

#pragma mark - Command Building

+ (NSData *)buildCommand:(uint16_t)opcode params:(NSData *)params {
  NSMutableData *cmd = [NSMutableData data];
  uint8_t pktType = BTHCIPacketCommand;
  [cmd appendBytes:&pktType length:1];

  BTHCICommandHeader hdr;
  hdr.opcode = opcode;
  hdr.paramLen = params ? (uint8_t)params.length : 0;
  [cmd appendBytes:&hdr length:sizeof(hdr)];

  if (params)
    [cmd appendData:params];
  return cmd;
}

+ (NSData *)buildInquiryCommand:(uint32_t)lap
                   maxResponses:(uint8_t)max
                  durationUnits:(uint8_t)dur {
  uint8_t params[5];
  params[0] = lap & 0xFF;
  params[1] = (lap >> 8) & 0xFF;
  params[2] = (lap >> 16) & 0xFF;
  params[3] = dur; // inquiry length in 1.28s units
  params[4] = max;
  return [self buildCommand:HCI_OP_INQUIRY
                     params:[NSData dataWithBytes:params length:5]];
}

+ (NSData *)buildInquiryCancelCommand {
  return [self buildCommand:HCI_OP_INQUIRY_CANCEL params:nil];
}

+ (NSData *)buildCreateConnectionCommand:(const uint8_t[6])addr {
  uint8_t params[13];
  memcpy(params, addr, 6);
  params[6] = 0x18;  // Packet type: DM1|DH1
  params[7] = 0xCC;  // More packet types
  params[8] = 0x01;  // Page scan rep R1
  params[9] = 0x00;  // Reserved
  params[10] = 0x00; // Clock offset
  params[11] = 0x00;
  params[12] = 0x01; // Allow role switch
  return [self buildCommand:HCI_OP_CREATE_CONN
                     params:[NSData dataWithBytes:params length:13]];
}

+ (NSData *)buildDisconnectCommand:(uint16_t)handle reason:(uint8_t)reason {
  uint8_t params[3];
  params[0] = handle & 0xFF;
  params[1] = (handle >> 8) & 0x0F;
  params[2] = reason;
  return [self buildCommand:HCI_OP_DISCONNECT
                     params:[NSData dataWithBytes:params length:3]];
}

+ (NSData *)buildRemoteNameRequest:(const uint8_t[6])addr {
  uint8_t params[10];
  memcpy(params, addr, 6);
  params[6] = 0x01; // Page scan rep R1
  params[7] = 0x00; // Reserved
  params[8] = 0x00; // Clock offset
  params[9] = 0x00;
  return [self buildCommand:HCI_OP_REMOTE_NAME_REQ
                     params:[NSData dataWithBytes:params length:10]];
}

+ (NSData *)buildPINCodeReply:(const uint8_t[6])addr pin:(NSString *)pin {
  uint8_t params[23];
  memset(params, 0, 23);
  memcpy(params, addr, 6);
  params[6] = (uint8_t)MIN(pin.length, 16);
  strncpy((char *)&params[7], pin.UTF8String, 16);
  return [self buildCommand:HCI_OP_PIN_CODE_REPLY
                     params:[NSData dataWithBytes:params length:23]];
}

+ (NSData *)buildResetCommand {
  return [self buildCommand:HCI_OP_RESET params:nil];
}

+ (NSData *)buildReadBDAddrCommand {
  return [self buildCommand:HCI_OP_READ_BD_ADDR params:nil];
}

+ (NSData *)buildReadLocalVersionCommand {
  return [self buildCommand:HCI_OP_READ_LOCAL_VERSION params:nil];
}

+ (NSData *)buildReadLocalFeaturesCommand {
  return [self buildCommand:HCI_OP_READ_LOCAL_FEATURES params:nil];
}

+ (NSData *)buildWriteLocalName:(NSString *)name {
  uint8_t params[BT_NAME_MAX];
  memset(params, 0, BT_NAME_MAX);
  strncpy((char *)params, name.UTF8String, BT_NAME_MAX - 1);
  return [self buildCommand:HCI_OP_WRITE_LOCAL_NAME
                     params:[NSData dataWithBytes:params length:BT_NAME_MAX]];
}

+ (NSData *)buildWriteScanEnable:(uint8_t)mode {
  return [self buildCommand:HCI_OP_WRITE_SCAN_ENABLE
                     params:[NSData dataWithBytes:&mode length:1]];
}

+ (NSData *)buildWriteClassOfDevice:(uint32_t)cod {
  uint8_t params[3];
  params[0] = cod & 0xFF;
  params[1] = (cod >> 8) & 0xFF;
  params[2] = (cod >> 16) & 0xFF;
  return [self buildCommand:HCI_OP_WRITE_CLASS_OF_DEVICE
                     params:[NSData dataWithBytes:params length:3]];
}

// LE Commands

+ (NSData *)buildLESetScanParams:(uint8_t)type
                        interval:(uint16_t)interval
                          window:(uint16_t)window
                     ownAddrType:(uint8_t)own
                    filterPolicy:(uint8_t)filter {
  uint8_t params[7];
  params[0] = type;
  params[1] = interval & 0xFF;
  params[2] = (interval >> 8) & 0xFF;
  params[3] = window & 0xFF;
  params[4] = (window >> 8) & 0xFF;
  params[5] = own;
  params[6] = filter;
  return [self buildCommand:HCI_OP_LE_SET_SCAN_PARAMS
                     params:[NSData dataWithBytes:params length:7]];
}

+ (NSData *)buildLESetScanEnable:(BOOL)enable filterDuplicates:(BOOL)filterDup {
  uint8_t params[2] = {(uint8_t)(enable ? 1 : 0), (uint8_t)(filterDup ? 1 : 0)};
  return [self buildCommand:HCI_OP_LE_SET_SCAN_ENABLE
                     params:[NSData dataWithBytes:params length:2]];
}

+ (NSData *)buildLECreateConnection:(const uint8_t[6])addr
                           addrType:(uint8_t)type {
  uint8_t params[25];
  memset(params, 0, 25);
  params[0] = 0x60;
  params[1] = 0x00; // Scan interval: 96
  params[2] = 0x30;
  params[3] = 0x00;            // Scan window: 48
  params[4] = 0x00;            // Initiator filter: use addr
  params[5] = type;            // Peer address type
  memcpy(&params[6], addr, 6); // Peer address
  params[12] = 0x00;           // Own address type: public
  params[13] = 0x06;
  params[14] = 0x00; // Conn interval min: 6
  params[15] = 0x0C;
  params[16] = 0x00; // Conn interval max: 12
  params[17] = 0x00;
  params[18] = 0x00; // Latency: 0
  params[19] = 0xC8;
  params[20] = 0x00; // Supervision timeout: 200
  params[21] = 0x04;
  params[22] = 0x00; // Min CE length
  params[23] = 0x06;
  params[24] = 0x00; // Max CE length
  return [self buildCommand:HCI_OP_LE_CREATE_CONN
                     params:[NSData dataWithBytes:params length:25]];
}

#pragma mark - Event Parsing

+ (BTHCIEventCode)parseEventCode:(NSData *)event {
  if (event.length < 2)
    return BTEventCommandComplete;
  const uint8_t *p = (const uint8_t *)event.bytes;
  return (BTHCIEventCode)p[0];
}

+ (NSData *)parseEventParams:(NSData *)event {
  if (event.length < 2)
    return nil;
  const uint8_t *p = (const uint8_t *)event.bytes;
  uint8_t paramLen = p[1];
  if (event.length < (NSUInteger)(2 + paramLen))
    return nil;
  return [event subdataWithRange:NSMakeRange(2, paramLen)];
}

+ (BTInquiryResult)parseInquiryResult:(NSData *)params {
  BTInquiryResult result;
  memset(&result, 0, sizeof(result));
  if (params.length >= sizeof(result)) {
    memcpy(&result, params.bytes, sizeof(result));
  }
  return result;
}

+ (BTInquiryResultRSSI)parseInquiryResultRSSI:(NSData *)params {
  BTInquiryResultRSSI result;
  memset(&result, 0, sizeof(result));
  if (params.length >= sizeof(result)) {
    memcpy(&result, params.bytes, sizeof(result));
  }
  return result;
}

+ (BTConnectionComplete)parseConnectionComplete:(NSData *)params {
  BTConnectionComplete result;
  memset(&result, 0, sizeof(result));
  if (params.length >= sizeof(result)) {
    memcpy(&result, params.bytes, sizeof(result));
  }
  return result;
}

+ (BTControllerInfo *)parseLocalVersion:(NSData *)params {
  BTControllerInfo *info = [BTControllerInfo new];
  if (params.length >= 9) {
    const uint8_t *p = (const uint8_t *)params.bytes;
    // Skip status byte
    info.hciVersionMajor = p[1];
    info.hciRevision = p[2] | (p[3] << 8);
    info.lmpVersion = p[4];
    info.manufacturer_id = p[5] | (p[6] << 8);
    info.lmpSubversion = p[7] | (p[8] << 8);
  }
  return info;
}

+ (NSString *)parseBDAddr:(NSData *)params {
  if (params.length < 7)
    return @"00:00:00:00:00:00";
  const uint8_t *p = (const uint8_t *)params.bytes;
  // Skip status byte, address is in reverse order
  return [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", p[6],
                                    p[5], p[4], p[3], p[2], p[1]];
}

+ (NSString *)parseRemoteName:(NSData *)params {
  if (params.length < 8)
    return @"Unknown";
  const uint8_t *p = (const uint8_t *)params.bytes;
  // Status(1) + BD_ADDR(6) + Name(248)
  return
      [[NSString alloc] initWithBytes:&p[7]
                               length:MIN(BT_NAME_MAX, (int)params.length - 7)
                             encoding:NSUTF8StringEncoding]
          ?: @"Unknown";
}

+ (NSArray<BTDevice *> *)parseLEAdvertisingReport:(NSData *)params {
  NSMutableArray *devices = [NSMutableArray array];
  if (params.length < 2)
    return devices;

  const uint8_t *p = (const uint8_t *)params.bytes;
  uint8_t numReports = p[1]; // Skip subevent byte
  size_t offset = 2;

  for (uint8_t i = 0; i < numReports && offset < params.length; i++) {
    BTDevice *dev = [BTDevice new];
    dev.isBLE = YES;

    if (offset + 8 > params.length)
      break;

    uint8_t eventType = p[offset++];
    (void)eventType;
    dev.addressType = (BTAddressType)p[offset++];

    uint8_t addr[6];
    memcpy(addr, &p[offset], 6);
    dev.rawAddress = [NSData dataWithBytes:addr length:6];
    dev.address = [self addressToString:addr];
    offset += 6;

    uint8_t dataLen = p[offset++];
    if (offset + dataLen > params.length)
      break;

    // Parse AD structures for name
    [self parseADStructures:[NSData dataWithBytes:&p[offset] length:dataLen]
                     device:dev];
    offset += dataLen;

    if (offset < params.length) {
      dev.rssi = (int8_t)p[offset++];
    }

    dev.lastSeen = [NSDate date];
    dev.state = BTDeviceStateDisconnected;
    [devices addObject:dev];
  }
  return devices;
}

+ (void)parseADStructures:(NSData *)adData device:(BTDevice *)dev {
  const uint8_t *p = (const uint8_t *)adData.bytes;
  size_t len = adData.length;
  size_t i = 0;

  while (i < len) {
    uint8_t adLen = p[i];
    if (adLen == 0 || i + adLen >= len)
      break;

    uint8_t adType = p[i + 1];
    const uint8_t *adValue = &p[i + 2];
    uint8_t valLen = adLen - 1;

    switch (adType) {
    case 0x08: // Shortened Local Name
    case 0x09: // Complete Local Name
      dev.name = [[NSString alloc] initWithBytes:adValue
                                          length:valLen
                                        encoding:NSUTF8StringEncoding];
      break;
    case 0x01: // Flags
      break;
    case 0xFF: // Manufacturer Specific
      if (valLen >= 2) {
        uint16_t companyId = adValue[0] | (adValue[1] << 8);
        dev.manufacturerData = @{
          @"companyId" : @(companyId),
          @"data" : [NSData dataWithBytes:&adValue[2] length:valLen - 2]
        };
        // Apple company ID = 0x004C
        if (companyId == 0x004C) {
          if (!dev.name)
            dev.name = @"Apple Device";
        }
      }
      break;
    case 0x0A: // TX Power Level
      break;
    }
    i += adLen + 1;
  }
  if (!dev.name)
    dev.name = @"Unknown";
}

// ── Send ──

- (BOOL)sendCommand:(NSData *)command {
  if (!self.isOpen)
    return NO;
  NSLog(@"[BluetoothHCI] Sending HCI command (%lu bytes)",
        (unsigned long)command.length);
  // In a complete implementation, this would write to the HCI transport
  // via IOKit or a UNIX domain socket to the BT daemon
  return YES;
}

- (BOOL)sendCommand:(uint16_t)opcode params:(NSData *)params {
  NSData *cmd = [BluetoothHCI buildCommand:opcode params:params];
  return [self sendCommand:cmd];
}

#pragma mark - Utilities

+ (NSString *)addressToString:(const uint8_t[6])addr {
  return
      [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", addr[5],
                                 addr[4], addr[3], addr[2], addr[1], addr[0]];
}

+ (void)stringToAddress:(NSString *)str output:(uint8_t[6])addr {
  unsigned int vals[6] = {};
  sscanf(str.UTF8String, "%02X:%02X:%02X:%02X:%02X:%02X", &vals[5], &vals[4],
         &vals[3], &vals[2], &vals[1], &vals[0]);
  for (int i = 0; i < 6; i++)
    addr[i] = (uint8_t)vals[i];
}

+ (NSString *)opcodeDescription:(uint16_t)opcode {
  switch (opcode) {
  case HCI_OP_INQUIRY:
    return @"Inquiry";
  case HCI_OP_INQUIRY_CANCEL:
    return @"Inquiry Cancel";
  case HCI_OP_CREATE_CONN:
    return @"Create Connection";
  case HCI_OP_DISCONNECT:
    return @"Disconnect";
  case HCI_OP_REMOTE_NAME_REQ:
    return @"Remote Name Request";
  case HCI_OP_PIN_CODE_REPLY:
    return @"PIN Code Reply";
  case HCI_OP_RESET:
    return @"Reset";
  case HCI_OP_READ_BD_ADDR:
    return @"Read BD Address";
  case HCI_OP_LE_SET_SCAN_ENABLE:
    return @"LE Set Scan Enable";
  case HCI_OP_LE_CREATE_CONN:
    return @"LE Create Connection";
  default:
    return [NSString stringWithFormat:@"Op 0x%04X", opcode];
  }
}

+ (NSString *)eventDescription:(BTHCIEventCode)code {
  switch (code) {
  case BTEventInquiryComplete:
    return @"Inquiry Complete";
  case BTEventInquiryResult:
    return @"Inquiry Result";
  case BTEventConnectionComplete:
    return @"Connection Complete";
  case BTEventDisconnectComplete:
    return @"Disconnect Complete";
  case BTEventRemoteNameReqComplete:
    return @"Remote Name Complete";
  case BTEventCommandComplete:
    return @"Command Complete";
  case BTEventCommandStatus:
    return @"Command Status";
  case BTEventPINCodeRequest:
    return @"PIN Code Request";
  case BTEventLinkKeyNotification:
    return @"Link Key";
  case BTEventLEMeta:
    return @"LE Meta";
  default:
    return [NSString stringWithFormat:@"Event 0x%02X", code];
  }
}

@end
