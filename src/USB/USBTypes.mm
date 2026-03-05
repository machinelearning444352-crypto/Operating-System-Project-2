#import "USBTypes.h"

// ============================================================================
// USBTypes.mm — USBDevice, USBInterface, USBEndpoint implementations
// ============================================================================

@implementation USBEndpoint
@end

@implementation USBInterface
@end

@implementation USBDevice

- (NSString *)vendorIDHex {
  return [NSString stringWithFormat:@"0x%04X", self.vendorID];
}

- (NSString *)productIDHex {
  return [NSString stringWithFormat:@"0x%04X", self.productID];
}

- (NSString *)speedString {
  switch (self.speed) {
  case USBSpeedLow:
    return @"Low Speed (1.5 Mbps)";
  case USBSpeedFull:
    return @"Full Speed (12 Mbps)";
  case USBSpeedHigh:
    return @"High Speed (480 Mbps)";
  case USBSpeedSuper:
    return @"SuperSpeed (5 Gbps)";
  case USBSpeedSuperPlus:
    return @"SuperSpeed+ (10 Gbps)";
  }
  return @"Unknown";
}

- (NSString *)classString {
  switch (self.deviceClass) {
  case USBClassPerInterface:
    return @"Composite";
  case USBClassAudio:
    return @"Audio";
  case USBClassCDCControl:
    return @"Communications";
  case USBClassHID:
    return @"Human Interface";
  case USBClassPhysical:
    return @"Physical";
  case USBClassImage:
    return @"Imaging";
  case USBClassPrinter:
    return @"Printer";
  case USBClassMassStorage:
    return @"Mass Storage";
  case USBClassHub:
    return @"Hub";
  case USBClassCDCData:
    return @"CDC Data";
  case USBClassSmartCard:
    return @"Smart Card";
  case USBClassContentSec:
    return @"Content Security";
  case USBClassVideo:
    return @"Video";
  case USBClassHealthcare:
    return @"Healthcare";
  case USBClassAV:
    return @"A/V";
  case USBClassWireless:
    return @"Wireless Controller";
  case USBClassMisc:
    return @"Miscellaneous";
  case USBClassAppSpecific:
    return @"Application Specific";
  case USBClassVendorSpec:
    return @"Vendor Specific";
  default:
    return @"Unknown";
  }
}

- (NSString *)stateString {
  switch (self.state) {
  case USBDeviceDetached:
    return @"Detached";
  case USBDeviceAttached:
    return @"Attached";
  case USBDeviceAddressed:
    return @"Addressed";
  case USBDeviceConfigured:
    return @"Configured";
  case USBDeviceSuspended:
    return @"Suspended";
  case USBDeviceError:
    return @"Error";
  }
  return @"Unknown";
}

- (NSString *)powerString {
  return [NSString stringWithFormat:@"%d mA", self.maxPower * 2];
}

- (NSString *)deviceIcon {
  switch (self.deviceClass) {
  case USBClassMassStorage:
    return @"externaldrive";
  case USBClassHID:
    return @"keyboard";
  case USBClassAudio:
    return @"headphones";
  case USBClassVideo:
    return @"video";
  case USBClassPrinter:
    return @"printer";
  case USBClassImage:
    return @"camera";
  case USBClassHub:
    return @"point.3.filled.connected.trianglepath.dotted";
  case USBClassWireless:
    return @"wifi";
  default:
    return @"cable.connector.horizontal";
  }
}

@end

@implementation USBHub
- (instancetype)init {
  if (self = [super init]) {
    _devices = [NSMutableArray array];
  }
  return self;
}
@end
