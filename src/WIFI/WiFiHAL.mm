#import "WiFiHAL.h"
#import <IOKit/IOKitLib.h>
#import <arpa/inet.h>
#import <fcntl.h>
#import <ifaddrs.h>
#import <net/bpf.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <net/route.h>
#import <resolv.h>
#import <sys/ioctl.h>
#import <sys/socket.h>
#import <sys/sysctl.h>

// ============================================================================
// WiFiHAL.mm — Hardware Abstraction Layer Implementation
// Direct IOKit/BSD interface to the WiFi controller
// ============================================================================

@interface WiFiHAL ()
@property(nonatomic, readwrite) BOOL isInitialized;
@property(nonatomic, readwrite) BOOL isPowered;
@property(nonatomic, readwrite, strong) NSString *interfaceName;
@property(nonatomic, readwrite, strong) NSString *chipsetName;
@property(nonatomic, readwrite, strong) NSString *firmwareVersion;
@property(nonatomic, readwrite, strong) NSString *hardwareAddress;
@property(nonatomic, assign) io_object_t wifiController;
@property(nonatomic, assign) io_connect_t connection;
@end

@implementation WiFiHAL

#pragma mark - Initialization

- (BOOL)initialize {
  NSLog(@"[WiFiHAL] Initializing hardware abstraction layer...");

  // ── Step 1: Find the WiFi interface name via BSD ──
  self.interfaceName = [self detectWiFiInterface];
  if (!self.interfaceName) {
    NSLog(@"[WiFiHAL] ERROR: No WiFi interface detected");
    [self.delegate halError:@"No WiFi interface found" code:-1];
    return NO;
  }
  NSLog(@"[WiFiHAL] Detected WiFi interface: %@", self.interfaceName);

  // ── Step 2: Query IOKit for the WiFi controller ──
  [self findWiFiController];

  // ── Step 3: Read hardware MAC address ──
  self.hardwareAddress = [self getMACAddress];
  NSLog(@"[WiFiHAL] Hardware MAC: %@", self.hardwareAddress);

  // ── Step 4: Get chipset info from IOKit ──
  NSDictionary *hwProps = [self getHardwareProperties];
  self.chipsetName = hwProps[@"IOModel"] ?: hwProps[@"IOClass"] ?: @"Unknown";
  self.firmwareVersion = hwProps[@"IOFirmwareVersion"] ?: @"N/A";
  NSLog(@"[WiFiHAL] Chipset: %@, FW: %@", self.chipsetName,
        self.firmwareVersion);

  // ── Step 5: Check power state ──
  self.isPowered = [self getPowerState];

  self.isInitialized = YES;
  [self.delegate halDidDetectHardware:self.chipsetName
                            interface:self.interfaceName];
  NSLog(@"[WiFiHAL] Initialization complete. Powered: %@",
        self.isPowered ? @"YES" : @"NO");
  return YES;
}

- (void)shutdown {
  if (self.connection) {
    IOServiceClose(self.connection);
    self.connection = 0;
  }
  if (self.wifiController) {
    IOObjectRelease(self.wifiController);
    self.wifiController = 0;
  }
  self.isInitialized = NO;
  NSLog(@"[WiFiHAL] Shutdown complete");
}

#pragma mark - Interface Detection (BSD layer)

- (NSString *)detectWiFiInterface {
  // Walk all network interfaces using getifaddrs and find the WiFi one.
  // On macOS, the WiFi interface is typically en0 or en1.
  // We check which one has the BROADCAST and MULTICAST flags typical of WiFi.
  struct ifaddrs *ifap, *ifa;
  if (getifaddrs(&ifap) != 0)
    return nil;

  NSMutableSet *candidates = [NSMutableSet set];
  for (ifa = ifap; ifa; ifa = ifa->ifa_next) {
    if (!ifa->ifa_name)
      continue;
    NSString *name = @(ifa->ifa_name);

    // WiFi interfaces are named en0, en1, etc.
    if (![name hasPrefix:@"en"])
      continue;

    // Must support broadcast and multicast (typical WiFi flags)
    uint32_t flags = ifa->ifa_flags;
    if ((flags & IFF_BROADCAST) && (flags & IFF_MULTICAST) &&
        (flags & IFF_RUNNING) && !(flags & IFF_LOOPBACK)) {
      [candidates addObject:name];
    }
  }
  freeifaddrs(ifap);

  // Prefer en0 (primary WiFi on most Macs), then en1
  if ([candidates containsObject:@"en0"])
    return @"en0";
  if ([candidates containsObject:@"en1"])
    return @"en1";
  return candidates.anyObject;
}

#pragma mark - IOKit WiFi Controller Discovery

- (void)findWiFiController {
  // Search the IOKit registry for the WiFi controller
  // The WiFi controller is typically an IO80211Controller

  CFMutableDictionaryRef matching = IOServiceMatching("IO80211Controller");
  if (!matching) {
    // Fallback: try AirPort
    matching = IOServiceMatching("AirPort_Brcm43xx");
  }
  if (!matching) {
    NSLog(@"[WiFiHAL] No IOKit matching dictionary for WiFi");
    return;
  }

  io_iterator_t iterator;
  kern_return_t kr =
      IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator);
  if (kr != KERN_SUCCESS) {
    NSLog(@"[WiFiHAL] IOServiceGetMatchingServices failed: 0x%x", kr);
    return;
  }

  self.wifiController = IOIteratorNext(iterator);
  IOObjectRelease(iterator);

  if (!self.wifiController) {
    NSLog(@"[WiFiHAL] No WiFi controller found in IOKit registry");
    return;
  }

  io_name_t className;
  IOObjectGetClass(self.wifiController, className);
  NSLog(@"[WiFiHAL] Found WiFi controller: %s", className);
}

#pragma mark - Hardware Properties (IOKit)

- (NSDictionary *)getHardwareProperties {
  if (!self.wifiController)
    return @{};

  CFMutableDictionaryRef props = nil;
  kern_return_t kr = IORegistryEntryCreateCFProperties(
      self.wifiController, &props, kCFAllocatorDefault, kNilOptions);
  if (kr != KERN_SUCCESS || !props)
    return @{};

  NSDictionary *dict = (__bridge_transfer NSDictionary *)props;
  return dict ?: @{};
}

- (NSString *)getChipsetInfo {
  NSDictionary *props = [self getHardwareProperties];
  NSString *model = props[@"IOModel"];
  NSString *vendor = props[@"IOVendor"];
  NSString *cls = props[@"IOClass"];

  NSMutableString *info = [NSMutableString string];
  if (vendor)
    [info appendFormat:@"Vendor: %@\n", vendor];
  if (model)
    [info appendFormat:@"Model: %@\n", model];
  if (cls)
    [info appendFormat:@"Driver: %@\n", cls];
  return info.length > 0 ? info : @"Unknown WiFi chipset";
}

- (NSArray<NSNumber *> *)getSupportedChannels {
  // Build the standard channel list for regulatory domain
  NSMutableArray *channels = [NSMutableArray array];

  // 2.4 GHz: channels 1-14
  for (int ch = 1; ch <= 14; ch++) {
    [channels addObject:@(ch)];
  }
  // 5 GHz: UNII-1, UNII-2, UNII-2e, UNII-3
  int ch5[] = {36,  40,  44,  48,  52,  56,  60,  64,  100, 104, 108, 112, 116,
               120, 124, 128, 132, 136, 140, 144, 149, 153, 157, 161, 165};
  for (int i = 0; i < 25; i++) {
    [channels addObject:@(ch5[i])];
  }
  // 6 GHz: channels 1-233 (step 4)
  for (int ch = 1; ch <= 233; ch += 4) {
    [channels addObject:@(ch + 1000)]; // offset to distinguish from 5GHz
  }
  return channels;
}

- (NSArray<NSNumber *> *)getSupportedPHYModes {
  return @[
    @(WiFiPHYMode_b), @(WiFiPHYMode_g), @(WiFiPHYMode_n), @(WiFiPHYMode_ac),
    @(WiFiPHYMode_ax)
  ];
}

#pragma mark - Power Control

- (BOOL)setPower:(BOOL)on {
  NSLog(@"[WiFiHAL] Setting power: %@", on ? @"ON" : @"OFF");

  // Try ioctl first (requires root)
  int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
  if (sockfd >= 0) {
    struct ifreq ifr;
    memset(&ifr, 0, sizeof(ifr));
    strncpy(ifr.ifr_name, self.interfaceName.UTF8String, IFNAMSIZ - 1);

    if (ioctl(sockfd, SIOCGIFFLAGS, &ifr) >= 0) {
      if (on) {
        ifr.ifr_flags |= (IFF_UP | IFF_RUNNING);
      } else {
        ifr.ifr_flags &= ~(IFF_UP | IFF_RUNNING);
      }

      if (ioctl(sockfd, SIOCSIFFLAGS, &ifr) == 0) {
        close(sockfd);
        self.isPowered = on;
        [self.delegate halPowerStateChanged:on];
        return YES;
      }
    }
    close(sockfd);
  }

  // Fallback: use networksetup CLI (works without root)
  NSLog(@"[WiFiHAL] ioctl requires root — using networksetup fallback");
  NSTask *task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/networksetup"];
  task.arguments =
      @[ @"-setairportpower", self.interfaceName, on ? @"on" : @"off" ];
  task.standardOutput = [NSPipe pipe];
  task.standardError = [NSPipe pipe];

  @try {
    [task launchAndReturnError:nil];
    [task waitUntilExit];
    BOOL success = (task.terminationStatus == 0);
    if (success) {
      self.isPowered = on;
      [self.delegate halPowerStateChanged:on];
    }
    return success;
  } @catch (NSException *e) {
    NSLog(@"[WiFiHAL] networksetup power control failed: %@", e);
    return NO;
  }
}

- (BOOL)getPowerState {
  int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
  if (sockfd < 0)
    return NO;

  struct ifreq ifr;
  memset(&ifr, 0, sizeof(ifr));
  strncpy(ifr.ifr_name, self.interfaceName.UTF8String, IFNAMSIZ - 1);

  if (ioctl(sockfd, SIOCGIFFLAGS, &ifr) < 0) {
    close(sockfd);
    return NO;
  }
  close(sockfd);

  return (ifr.ifr_flags & IFF_UP) && (ifr.ifr_flags & IFF_RUNNING);
}

#pragma mark - MAC Address (BSD link layer)

- (NSString *)getMACAddress {
  return [self macAddressForInterface:self.interfaceName];
}

- (NSString *)macAddressForInterface:(NSString *)ifName {
  struct ifaddrs *ifap, *ifa;
  if (getifaddrs(&ifap) != 0)
    return @"00:00:00:00:00:00";

  for (ifa = ifap; ifa; ifa = ifa->ifa_next) {
    if (ifa->ifa_addr->sa_family != AF_LINK)
      continue;
    if (strcmp(ifa->ifa_name, ifName.UTF8String) != 0)
      continue;

    struct sockaddr_dl *sdl = (struct sockaddr_dl *)ifa->ifa_addr;
    if (sdl->sdl_alen != 6)
      continue;

    unsigned char *mac = (unsigned char *)LLADDR(sdl);
    NSString *result =
        [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", mac[0],
                                   mac[1], mac[2], mac[3], mac[4], mac[5]];
    freeifaddrs(ifap);
    return result;
  }
  freeifaddrs(ifap);
  return @"00:00:00:00:00:00";
}

- (uint32_t)getMTU {
  int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
  if (sockfd < 0)
    return 1500;

  struct ifreq ifr;
  memset(&ifr, 0, sizeof(ifr));
  strncpy(ifr.ifr_name, self.interfaceName.UTF8String, IFNAMSIZ - 1);

  if (ioctl(sockfd, SIOCGIFMTU, &ifr) < 0) {
    close(sockfd);
    return 1500;
  }
  close(sockfd);
  return (uint32_t)ifr.ifr_mtu;
}

#pragma mark - Interface Info Query

- (WiFiInterfaceInfo *)queryInterfaceInfo {
  WiFiInterfaceInfo *info = [WiFiInterfaceInfo new];
  info.name = self.interfaceName;
  info.hardwareMAC = self.hardwareAddress;
  info.currentMAC = [self getMACAddress];
  info.mtu = [self getMTU];
  info.isUp = self.isPowered;
  info.isRunning = self.isPowered;
  info.supportsWiFi = YES;

  // Get IPv4/IPv6 addresses using getifaddrs
  struct ifaddrs *ifap, *ifa;
  if (getifaddrs(&ifap) == 0) {
    for (ifa = ifap; ifa; ifa = ifa->ifa_next) {
      if (strcmp(ifa->ifa_name, self.interfaceName.UTF8String) != 0)
        continue;

      if (ifa->ifa_addr->sa_family == AF_INET) {
        char buf[INET_ADDRSTRLEN];
        struct sockaddr_in *sin = (struct sockaddr_in *)ifa->ifa_addr;
        inet_ntop(AF_INET, &sin->sin_addr, buf, sizeof(buf));
        info.ipv4 = @(buf);

        if (ifa->ifa_netmask) {
          struct sockaddr_in *mask = (struct sockaddr_in *)ifa->ifa_netmask;
          inet_ntop(AF_INET, &mask->sin_addr, buf, sizeof(buf));
          info.netmask = @(buf);
        }
        if (ifa->ifa_dstaddr) {
          struct sockaddr_in *bcast = (struct sockaddr_in *)ifa->ifa_dstaddr;
          inet_ntop(AF_INET, &bcast->sin_addr, buf, sizeof(buf));
          info.broadcast = @(buf);
        }
        info.flags = ifa->ifa_flags;
      } else if (ifa->ifa_addr->sa_family == AF_INET6) {
        char buf[INET6_ADDRSTRLEN];
        struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)ifa->ifa_addr;
        inet_ntop(AF_INET6, &sin6->sin6_addr, buf, sizeof(buf));
        info.ipv6 = @(buf);
      }
    }
    freeifaddrs(ifap);
  }

  info.gateway = [self getDefaultGateway];
  info.dns = [self getDNSServers];
  return info;
}

- (uint32_t)getInterfaceFlags {
  int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
  if (sockfd < 0)
    return 0;
  struct ifreq ifr;
  memset(&ifr, 0, sizeof(ifr));
  strncpy(ifr.ifr_name, self.interfaceName.UTF8String, IFNAMSIZ - 1);
  ioctl(sockfd, SIOCGIFFLAGS, &ifr);
  close(sockfd);
  return (uint32_t)ifr.ifr_flags;
}

- (BOOL)setInterfaceFlags:(uint32_t)flags {
  int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
  if (sockfd < 0)
    return NO;
  struct ifreq ifr;
  memset(&ifr, 0, sizeof(ifr));
  strncpy(ifr.ifr_name, self.interfaceName.UTF8String, IFNAMSIZ - 1);
  ifr.ifr_flags = (short)flags;
  BOOL ok = (ioctl(sockfd, SIOCSIFFLAGS, &ifr) == 0);
  close(sockfd);
  return ok;
}

#pragma mark - Raw Socket I/O

- (int)openRawSocket {
  // Open a BPF device for raw frame capture (requires root privileges)
  int fd = -1;
  for (int i = 0; i < 10; i++) {
    char bpfPath[32];
    snprintf(bpfPath, sizeof(bpfPath), "/dev/bpf%d", i);
    fd = open(bpfPath, O_RDWR);
    if (fd >= 0)
      break;
  }
  if (fd < 0) {
    NSLog(@"[WiFiHAL] BPF unavailable (not running as root) — using CLI "
          @"fallbacks");
    return -1;
  }

  struct ifreq ifr;
  memset(&ifr, 0, sizeof(ifr));
  strncpy(ifr.ifr_name, self.interfaceName.UTF8String, IFNAMSIZ - 1);
  if (ioctl(fd, BIOCSETIF, &ifr) < 0) {
    NSLog(@"[WiFiHAL] BIOCSETIF failed");
    close(fd);
    return -1;
  }

  int val = 1;
  ioctl(fd, BIOCIMMEDIATE, &val);
  int bufSize = 65536;
  ioctl(fd, BIOCSBLEN, &bufSize);
  ioctl(fd, BIOCPROMISC, NULL);

  NSLog(@"[WiFiHAL] Opened BPF device fd=%d for %@", fd, self.interfaceName);
  return fd;
}

- (void)closeRawSocket:(int)fd {
  if (fd >= 0)
    close(fd);
}

- (NSData *)readFrame:(int)fd timeout:(NSTimeInterval)timeout {
  if (fd < 0)
    return nil;

  struct timeval tv;
  tv.tv_sec = (long)timeout;
  tv.tv_usec = (int)((timeout - tv.tv_sec) * 1e6);
  ioctl(fd, BIOCSRTIMEOUT, &tv);

  uint8_t buffer[65536];
  ssize_t n = read(fd, buffer, sizeof(buffer));
  if (n <= 0)
    return nil;

  return [NSData dataWithBytes:buffer length:n];
}

- (BOOL)writeFrame:(int)fd data:(NSData *)frameData {
  if (fd < 0 || !frameData)
    return NO;
  ssize_t written = write(fd, frameData.bytes, frameData.length);
  return written == (ssize_t)frameData.length;
}

#pragma mark - System Network Info (sysctl / routing table)

- (NSString *)getDefaultGateway {
  // Read the default gateway from the BSD routing table via sysctl
  int mib[] = {CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_GATEWAY};
  size_t len = 0;
  if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0)
    return @"Unknown";

  char *buf = (char *)malloc(len);
  if (!buf)
    return @"Unknown";
  if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
    free(buf);
    return @"Unknown";
  }

  struct rt_msghdr *rtm;
  for (char *ptr = buf; ptr < buf + len;) {
    rtm = (struct rt_msghdr *)ptr;
    struct sockaddr_in *sa_dst = (struct sockaddr_in *)(rtm + 1);
    struct sockaddr_in *sa_gw =
        (struct sockaddr_in *)((char *)sa_dst +
                               (sa_dst->sin_len > 0
                                    ? sa_dst->sin_len
                                    : sizeof(struct sockaddr_in)));

    // Default route: destination 0.0.0.0
    if (sa_dst->sin_family == AF_INET && sa_dst->sin_addr.s_addr == 0) {
      if (sa_gw->sin_family == AF_INET) {
        char gwStr[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &sa_gw->sin_addr, gwStr, sizeof(gwStr));
        free(buf);
        return @(gwStr);
      }
    }
    ptr += rtm->rtm_msglen;
  }
  free(buf);
  return @"Unknown";
}

- (NSArray<NSString *> *)getDNSServers {
  // Parse /etc/resolv.conf for DNS servers
  NSMutableArray *servers = [NSMutableArray array];
  NSString *resolv = [NSString stringWithContentsOfFile:@"/etc/resolv.conf"
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
  if (resolv) {
    for (NSString *line in [resolv componentsSeparatedByString:@"\n"]) {
      NSString *trimmed =
          [line stringByTrimmingCharactersInSet:[NSCharacterSet
                                                    whitespaceCharacterSet]];
      if ([trimmed hasPrefix:@"nameserver "]) {
        NSString *ip = [trimmed substringFromIndex:11];
        ip = [ip stringByTrimmingCharactersInSet:[NSCharacterSet
                                                     whitespaceCharacterSet]];
        if (ip.length > 0)
          [servers addObject:ip];
      }
    }
  }
  if (servers.count == 0)
    [servers addObject:@"8.8.8.8"];
  return servers;
}

- (NSDictionary *)getRoutingTable {
  NSMutableDictionary *table = [NSMutableDictionary dictionary];
  int mib[] = {CTL_NET, PF_ROUTE, 0, 0, NET_RT_DUMP, 0};
  size_t len = 0;
  if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0)
    return table;

  char *buf = (char *)malloc(len);
  if (!buf)
    return table;
  sysctl(mib, 6, buf, &len, NULL, 0);

  int count = 0;
  struct rt_msghdr *rtm;
  for (char *ptr = buf; ptr < buf + len;) {
    rtm = (struct rt_msghdr *)ptr;
    struct sockaddr_in *sa = (struct sockaddr_in *)(rtm + 1);
    if (sa->sin_family == AF_INET) {
      char ip[INET_ADDRSTRLEN];
      inet_ntop(AF_INET, &sa->sin_addr, ip, sizeof(ip));
      table[[NSString stringWithFormat:@"route_%d", count++]] = @(ip);
    }
    ptr += rtm->rtm_msglen;
  }
  free(buf);
  return table;
}

- (NSDictionary *)getInterfaceCounters {
  // Read TX/RX counters from the link-layer address
  NSMutableDictionary *counters = [NSMutableDictionary dictionary];
  struct ifaddrs *ifap, *ifa;
  if (getifaddrs(&ifap) != 0)
    return counters;

  for (ifa = ifap; ifa; ifa = ifa->ifa_next) {
    if (strcmp(ifa->ifa_name, self.interfaceName.UTF8String) != 0)
      continue;
    if (ifa->ifa_addr->sa_family != AF_LINK)
      continue;

    struct if_data *data = (struct if_data *)ifa->ifa_data;
    if (data) {
      counters[@"txBytes"] = @(data->ifi_obytes);
      counters[@"rxBytes"] = @(data->ifi_ibytes);
      counters[@"txPackets"] = @(data->ifi_opackets);
      counters[@"rxPackets"] = @(data->ifi_ipackets);
      counters[@"txErrors"] = @(data->ifi_oerrors);
      counters[@"rxErrors"] = @(data->ifi_ierrors);
      counters[@"collisions"] = @(data->ifi_collisions);
      counters[@"mtu"] = @(data->ifi_mtu);
      counters[@"speed"] = @(data->ifi_baudrate);
    }
    break;
  }
  freeifaddrs(ifap);
  return counters;
}

@end
