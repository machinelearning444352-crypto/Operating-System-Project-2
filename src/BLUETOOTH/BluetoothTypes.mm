#import "BluetoothTypes.h"

// ============================================================================
// BluetoothTypes.mm — BTDevice and BTControllerInfo implementation
// ============================================================================

@implementation BTDevice

- (NSString *)majorClassName {
  switch (self.majorClass) {
  case BTMajorComputer:
    return @"Computer";
  case BTMajorPhone:
    return @"Phone";
  case BTMajorNetworking:
    return @"Network";
  case BTMajorAudioVideo:
    return @"Audio/Video";
  case BTMajorPeripheral:
    return @"Peripheral";
  case BTMajorImaging:
    return @"Imaging";
  case BTMajorWearable:
    return @"Wearable";
  case BTMajorToy:
    return @"Toy";
  case BTMajorHealth:
    return @"Health";
  case BTMajorMisc:
    return @"Miscellaneous";
  case BTMajorUncategorized:
    return @"Uncategorized";
  }
  return @"Unknown";
}

- (NSString *)stateString {
  switch (self.state) {
  case BTDeviceStateDisconnected:
    return @"Disconnected";
  case BTDeviceStateConnecting:
    return @"Connecting...";
  case BTDeviceStateConnected:
    return @"Connected";
  case BTDeviceStatePairing:
    return @"Pairing...";
  case BTDeviceStatePaired:
    return @"Paired";
  case BTDeviceStateBonded:
    return @"Bonded";
  }
  return @"Unknown";
}

- (NSString *)deviceIcon {
  switch (self.majorClass) {
  case BTMajorComputer:
    return @"laptopcomputer";
  case BTMajorPhone:
    return @"iphone";
  case BTMajorAudioVideo: {
    // Sub-classify based on minor class
    uint8_t minor = (self.classOfDevice >> 2) & 0x3F;
    if (minor >= 0x01 && minor <= 0x03)
      return @"headphones";
    if (minor == 0x06)
      return @"headphones";
    if (minor == 0x04)
      return @"mic";
    if (minor == 0x05)
      return @"speaker.wave.3";
    return @"hifispeaker";
  }
  case BTMajorPeripheral: {
    uint8_t minor = (self.classOfDevice >> 2) & 0x3F;
    if (minor == 0x01)
      return @"keyboard";
    if (minor == 0x02)
      return @"computermouse";
    if (minor == 0x03)
      return @"gamecontroller";
    return @"keyboard";
  }
  case BTMajorImaging:
    return @"printer";
  case BTMajorWearable:
    return @"applewatch";
  case BTMajorHealth:
    return @"heart";
  case BTMajorNetworking:
    return @"network";
  default:
    return @"wave.3.right.circle";
  }
}

@end

@implementation BTControllerInfo
@end
