#import "NetworkEngine.h"
#import <CoreWLAN/CoreWLAN.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <mach/mach_time.h>
#import <net/if.h>
#import <net/if_dl.h>
#import <net/route.h>
#import <netdb.h>
#import <netinet/in.h>
#import <netinet/ip.h>
#import <netinet/ip_icmp.h>
#import <netinet/tcp.h>
#import <sys/socket.h>
#import <sys/sysctl.h>

// ============================================================================
// Data Model Implementations
// ============================================================================

@implementation WiFiNetworkEntry
@end

@implementation NetworkInterfaceInfo
@end

@implementation WiFiConnectionDetails
@end

@implementation PingResult
@end

@implementation DNSResult
@end

// ============================================================================
// NETWORK ENGINE — Full Implementation
// ============================================================================

@interface NetworkEngine ()
@property(nonatomic, strong) CWWiFiClient *wifiClient;
@property(nonatomic, strong) CWInterface *wifiInterface;
@property(nonatomic, strong) NSTimer *throughputTimer;
@property(nonatomic, assign) uint64_t lastBytesIn;
@property(nonatomic, assign) uint64_t lastBytesOut;
@property(nonatomic, copy) ThroughputCallback throughputCallback;
@property(nonatomic, strong) dispatch_queue_t networkQueue;
@end

@implementation NetworkEngine

+ (instancetype)sharedInstance {
  static NetworkEngine *inst;
  static dispatch_once_t t;
  dispatch_once(&t, ^{
    inst = [[self alloc] init];
  });
  return inst;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.wifiClient = [CWWiFiClient sharedWiFiClient];
    self.wifiInterface = self.wifiClient.interface;
    self.networkQueue = dispatch_queue_create("com.os.networkengine",
                                              DISPATCH_QUEUE_CONCURRENT);
  }
  return self;
}

// ============================================================================
#pragma mark - WiFi Control (Real CoreWLAN)
// ============================================================================

- (void)scanForNetworks:(NetworkScanCompletion)completion {
  dispatch_async(self.networkQueue, ^{
    NSMutableArray<WiFiNetworkEntry *> *entries = [NSMutableArray array];
    NSString *currentSSID = self.wifiInterface.ssid;

    // Try active scan first, fall back to cached
    NSSet<CWNetwork *> *scanResults = nil;
    NSError *scanError = nil;

    @try {
      scanResults = [self.wifiInterface scanForNetworksWithName:nil
                                                          error:&scanError];
    } @catch (NSException *e) {
      NSLog(@"[NetworkEngine] Active scan exception: %@", e.reason);
    }

    if (!scanResults || scanResults.count == 0) {
      scanResults = [self.wifiInterface cachedScanResults];
    }

    if (scanResults) {
      // Sort by signal strength
      NSArray *sorted = [scanResults.allObjects
          sortedArrayUsingComparator:^NSComparisonResult(CWNetwork *a,
                                                         CWNetwork *b) {
            return [@(b.rssiValue) compare:@(a.rssiValue)];
          }];

      for (CWNetwork *net in sorted) {
        if (net.ssid.length == 0)
          continue;

        WiFiNetworkEntry *entry = [[WiFiNetworkEntry alloc] init];
        entry.ssid = net.ssid;
        entry.bssid = net.bssid ?: @"Unknown";
        entry.rssi = net.rssiValue;
        entry.noiseMeasurement = net.noiseMeasurement;
        entry.channel = net.wlanChannel.channelNumber;
        entry.isCurrentNetwork = [net.ssid isEqualToString:currentSSID];
        entry.rawNetwork = net;

        // Determine band from channel
        if (net.wlanChannel.channelNumber <= 14) {
          entry.band = @"2.4 GHz";
        } else if (net.wlanChannel.channelNumber <= 177) {
          entry.band = @"5 GHz";
        } else {
          entry.band = @"6 GHz";
        }

        // Determine security
        entry.isSecured = NO;
        if ([net supportsSecurity:kCWSecurityWPA3Personal] ||
            [net supportsSecurity:kCWSecurityWPA3Enterprise]) {
          entry.securityType = @"WPA3";
          entry.isSecured = YES;
        } else if ([net supportsSecurity:kCWSecurityWPA2Personal] ||
                   [net supportsSecurity:kCWSecurityWPA2Enterprise]) {
          entry.securityType = @"WPA2";
          entry.isSecured = YES;
        } else if ([net supportsSecurity:kCWSecurityWPAPersonal] ||
                   [net supportsSecurity:kCWSecurityWPAEnterprise]) {
          entry.securityType = @"WPA";
          entry.isSecured = YES;
        } else if ([net supportsSecurity:kCWSecurityWEP]) {
          entry.securityType = @"WEP";
          entry.isSecured = YES;
        } else {
          entry.securityType = @"Open";
        }

        // PHY mode
        NSInteger band = net.wlanChannel.channelBand;
        if (band == kCWChannelBand6GHz) {
          entry.phyMode = @"802.11ax (Wi-Fi 6E)";
        } else if (net.wlanChannel.channelNumber > 14) {
          entry.phyMode = @"802.11ac/ax";
        } else {
          entry.phyMode = @"802.11n/ax";
        }

        [entries addObject:entry];
      }
    }

    // Fallback: use system command if CoreWLAN scan failed
    if (entries.count == 0) {
      [self scanWithSystemCommand:entries];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if (completion)
        completion(entries, scanError);
    });
  });
}

- (void)scanWithSystemCommand:(NSMutableArray<WiFiNetworkEntry *> *)entries {
  NSString *ifName = self.wifiInterface.interfaceName ?: @"en0";

  // Use airport utility for detailed scan
  NSTask *task = [[NSTask alloc] init];
  task.executableURL = [NSURL
      fileURLWithPath:@"/System/Library/PrivateFrameworks/Apple80211.framework/"
                      @"Versions/Current/Resources/airport"];
  task.arguments = @[ @"-s" ];
  NSPipe *pipe = [NSPipe pipe];
  task.standardOutput = pipe;
  task.standardError = [NSPipe pipe];

  @try {
    [task launchAndReturnError:nil];
    [task waitUntilExit];

    NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data
                                             encoding:NSUTF8StringEncoding];
    NSArray *lines = [output componentsSeparatedByString:@"\n"];

    // Skip header line
    for (NSUInteger i = 1; i < lines.count; i++) {
      NSString *line = lines[i];
      if (line.length < 30)
        continue;

      // Parse airport output: SSID BSSID RSSI CHANNEL HT CC SECURITY
      NSArray *parts = [line
          componentsSeparatedByCharactersInSet:[NSCharacterSet
                                                   whitespaceCharacterSet]];
      NSMutableArray *cleanParts = [NSMutableArray array];
      for (NSString *p in parts) {
        if (p.length > 0)
          [cleanParts addObject:p];
      }

      if (cleanParts.count >= 4) {
        WiFiNetworkEntry *entry = [[WiFiNetworkEntry alloc] init];
        entry.ssid = cleanParts[0];
        entry.bssid = (cleanParts.count > 1) ? cleanParts[1] : @"Unknown";
        entry.rssi =
            (cleanParts.count > 2) ? [cleanParts[2] integerValue] : -70;
        entry.channel =
            (cleanParts.count > 3) ? [cleanParts[3] integerValue] : 0;
        entry.band = (entry.channel <= 14) ? @"2.4 GHz" : @"5 GHz";
        entry.isSecured = (cleanParts.count > 6)
                              ? ![cleanParts[6] isEqualToString:@"NONE"]
                              : NO;
        entry.securityType = entry.isSecured ? @"WPA2" : @"Open";
        entry.isCurrentNetwork = NO;
        [entries addObject:entry];
      }
    }
  } @catch (NSException *e) {
    // Fallback to networksetup
    NSTask *task2 = [[NSTask alloc] init];
    task2.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/networksetup"];
    task2.arguments = @[ @"-listpreferredwirelessnetworks", ifName ];
    NSPipe *pipe2 = [NSPipe pipe];
    task2.standardOutput = pipe2;
    @try {
      [task2 launchAndReturnError:nil];
      [task2 waitUntilExit];
      NSData *data2 = [pipe2.fileHandleForReading readDataToEndOfFile];
      NSString *output2 = [[NSString alloc] initWithData:data2
                                                encoding:NSUTF8StringEncoding];
      NSArray *lines2 = [output2 componentsSeparatedByString:@"\n"];
      NSInteger rssi = -45;
      for (NSString *line in lines2) {
        NSString *ssid =
            [line stringByTrimmingCharactersInSet:
                      [NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (ssid.length > 0 && ![ssid hasPrefix:@"Preferred"]) {
          WiFiNetworkEntry *entry = [[WiFiNetworkEntry alloc] init];
          entry.ssid = ssid;
          entry.rssi = rssi;
          entry.securityType = @"WPA2";
          entry.isSecured = YES;
          entry.band = @"Unknown";
          rssi -= 5;
          [entries addObject:entry];
          if (entries.count >= 20)
            break;
        }
      }
    } @catch (NSException *e2) {
    }
  }
}

- (void)connectToNetwork:(NSString *)ssid
                password:(NSString *)password
              completion:(NetworkConnectCompletion)completion {
  dispatch_async(self.networkQueue, ^{
    NSString *ifName = self.wifiInterface.interfaceName ?: @"en0";

    // Method 1: Try CWInterface associateToNetwork (requires scanning first)
    NSError *scanError = nil;
    NSSet<CWNetwork *> *results =
        [self.wifiInterface scanForNetworksWithName:ssid error:&scanError];

    if (results.count > 0) {
      CWNetwork *target = results.anyObject;
      NSError *connectError = nil;
      BOOL success = [self.wifiInterface associateToNetwork:target
                                                   password:password
                                                      error:&connectError];

      if (success) {
        dispatch_async(dispatch_get_main_queue(), ^{
          if (completion)
            completion(YES, nil);
        });
        return;
      }
      NSLog(@"[NetworkEngine] CoreWLAN connect failed: %@",
            connectError.localizedDescription);
    }

    // Method 2: Fall back to networksetup command
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/networksetup"];
    task.arguments = @[ @"-setairportnetwork", ifName, ssid, password ];
    NSPipe *outPipe = [NSPipe pipe];
    NSPipe *errPipe = [NSPipe pipe];
    task.standardOutput = outPipe;
    task.standardError = errPipe;

    NSError *launchError = nil;
    [task launchAndReturnError:&launchError];
    [task waitUntilExit];

    NSData *outData = [outPipe.fileHandleForReading readDataToEndOfFile];
    NSData *errData = [errPipe.fileHandleForReading readDataToEndOfFile];
    NSString *outStr = [[NSString alloc] initWithData:outData
                                             encoding:NSUTF8StringEncoding];
    NSString *errStr = [[NSString alloc] initWithData:errData
                                             encoding:NSUTF8StringEncoding];

    BOOL success = (task.terminationStatus == 0) &&
                   ![outStr containsString:@"Error"] &&
                   ![outStr containsString:@"Failed"] &&
                   ![outStr containsString:@"Could not find"];

    NSString *errorMsg = nil;
    if (!success) {
      errorMsg = errStr.length > 0 ? errStr : outStr;
      if (errorMsg.length == 0)
        errorMsg = @"Incorrect password or connection failed";
    }

    dispatch_async(dispatch_get_main_queue(), ^{
      if (completion)
        completion(success, errorMsg);
    });
  });
}

- (void)connectToOpenNetwork:(NSString *)ssid
                  completion:(NetworkConnectCompletion)completion {
  dispatch_async(self.networkQueue, ^{
    // Scan for the specific network
    NSError *scanError = nil;
    NSSet<CWNetwork *> *results =
        [self.wifiInterface scanForNetworksWithName:ssid error:&scanError];

    if (results.count > 0) {
      CWNetwork *target = results.anyObject;
      NSError *connectError = nil;
      BOOL success = [self.wifiInterface associateToNetwork:target
                                                   password:nil
                                                      error:&connectError];

      dispatch_async(dispatch_get_main_queue(), ^{
        if (completion)
          completion(success, connectError.localizedDescription);
      });
    } else {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (completion)
          completion(NO, @"Network not found");
      });
    }
  });
}

- (void)disconnectFromCurrentNetwork {
  [self.wifiInterface disassociate];
}

- (BOOL)isWiFiEnabled {
  return self.wifiInterface.powerOn;
}

- (void)setWiFiEnabled:(BOOL)enabled {
  NSError *error = nil;
  [self.wifiClient.interface setPower:enabled error:&error];
  if (error) {
    NSLog(@"[NetworkEngine] Failed to set WiFi power: %@",
          error.localizedDescription);
  }
}

- (NSString *)currentSSID {
  return self.wifiInterface.ssid;
}

- (WiFiConnectionDetails *)currentConnectionDetails {
  WiFiConnectionDetails *details = [[WiFiConnectionDetails alloc] init];

  CWInterface *iface = self.wifiInterface;
  details.ssid = iface.ssid ?: @"Not connected";
  details.bssid = iface.bssid ?: @"—";
  details.rssi = iface.rssiValue;
  details.noise = iface.noiseMeasurement;
  details.txRate = iface.transmitRate;
  details.channel = iface.wlanChannel.channelNumber;

  // Band
  if (iface.wlanChannel.channelBand == kCWChannelBand2GHz) {
    details.band = @"2.4 GHz";
  } else if (iface.wlanChannel.channelBand == kCWChannelBand5GHz) {
    details.band = @"5 GHz";
  } else {
    details.band = @"6 GHz";
  }

  // Security
  if (iface.security == kCWSecurityWPA3Personal ||
      iface.security == kCWSecurityWPA3Enterprise) {
    details.securityType = @"WPA3";
  } else if (iface.security == kCWSecurityWPA2Personal ||
             iface.security == kCWSecurityWPA2Enterprise) {
    details.securityType = @"WPA2";
  } else if (iface.security == kCWSecurityWPAPersonal) {
    details.securityType = @"WPA";
  } else if (iface.security == kCWSecurityNone) {
    details.securityType = @"Open";
  } else {
    details.securityType = @"Unknown";
  }

  // IP from getifaddrs
  NSString *ifName = iface.interfaceName ?: @"en0";
  struct ifaddrs *ifaddr, *ifa;
  if (getifaddrs(&ifaddr) == 0) {
    for (ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
      if (strcmp(ifa->ifa_name, [ifName UTF8String]) != 0)
        continue;
      if (ifa->ifa_addr->sa_family == AF_INET) {
        char ip[INET_ADDRSTRLEN];
        char mask[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &((struct sockaddr_in *)ifa->ifa_addr)->sin_addr, ip,
                  sizeof(ip));
        inet_ntop(AF_INET, &((struct sockaddr_in *)ifa->ifa_netmask)->sin_addr,
                  mask, sizeof(mask));
        details.ipAddress = [NSString stringWithUTF8String:ip];
        details.subnetMask = [NSString stringWithUTF8String:mask];
      }
    }
    freeifaddrs(ifaddr);
  }

  // Router/Gateway
  details.routerIP = [self defaultGateway];

  // DNS servers
  details.dnsServers = [self dnsServers];

  // MAC address
  details.macAddress = [self macAddressForInterface:ifName];

  return details;
}

// ============================================================================
#pragma mark - Network Interface Info (Real BSD/sysctl)
// ============================================================================

- (NSArray<NetworkInterfaceInfo *> *)allInterfaces {
  NSMutableArray<NetworkInterfaceInfo *> *interfaces = [NSMutableArray array];
  struct ifaddrs *ifaddr, *ifa;

  if (getifaddrs(&ifaddr) != 0)
    return interfaces;

  NSMutableDictionary<NSString *, NetworkInterfaceInfo *> *ifMap =
      [NSMutableDictionary dictionary];

  for (ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
    NSString *name = [NSString stringWithUTF8String:ifa->ifa_name];

    NetworkInterfaceInfo *info = ifMap[name];
    if (!info) {
      info = [[NetworkInterfaceInfo alloc] init];
      info.name = name;
      info.isUp = (ifa->ifa_flags & IFF_UP) != 0;
      info.isRunning = (ifa->ifa_flags & IFF_RUNNING) != 0;
      info.isLoopback = (ifa->ifa_flags & IFF_LOOPBACK) != 0;

      if ([name isEqualToString:@"en0"])
        info.displayName = @"Wi-Fi";
      else if ([name isEqualToString:@"en1"])
        info.displayName = @"Thunderbolt Ethernet";
      else if ([name isEqualToString:@"lo0"])
        info.displayName = @"Loopback";
      else if ([name hasPrefix:@"utun"])
        info.displayName = @"VPN Tunnel";
      else if ([name hasPrefix:@"awdl"])
        info.displayName = @"AirDrop";
      else if ([name hasPrefix:@"llw"])
        info.displayName = @"Low Latency WLAN";
      else if ([name hasPrefix:@"bridge"])
        info.displayName = @"Bridge";
      else
        info.displayName = name;

      ifMap[name] = info;
    }

    if (ifa->ifa_addr == NULL)
      continue;

    if (ifa->ifa_addr->sa_family == AF_INET) {
      char addr[INET_ADDRSTRLEN];
      inet_ntop(AF_INET, &((struct sockaddr_in *)ifa->ifa_addr)->sin_addr, addr,
                sizeof(addr));
      info.ipv4Address = [NSString stringWithUTF8String:addr];

      if (ifa->ifa_netmask) {
        char mask[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &((struct sockaddr_in *)ifa->ifa_netmask)->sin_addr,
                  mask, sizeof(mask));
        info.subnetMask = [NSString stringWithUTF8String:mask];
      }
      if (ifa->ifa_dstaddr) {
        char bcast[INET_ADDRSTRLEN];
        inet_ntop(AF_INET, &((struct sockaddr_in *)ifa->ifa_dstaddr)->sin_addr,
                  bcast, sizeof(bcast));
        info.broadcastAddr = [NSString stringWithUTF8String:bcast];
      }
    } else if (ifa->ifa_addr->sa_family == AF_INET6) {
      char addr[INET6_ADDRSTRLEN];
      inet_ntop(AF_INET6, &((struct sockaddr_in6 *)ifa->ifa_addr)->sin6_addr,
                addr, sizeof(addr));
      info.ipv6Address = [NSString stringWithUTF8String:addr];
    } else if (ifa->ifa_addr->sa_family == AF_LINK) {
      info.macAddress = [self macFromSockaddr:ifa->ifa_addr];
    }
  }

  freeifaddrs(ifaddr);

  // Get byte/packet counters via sysctl
  int mib[] = {CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0};
  size_t len;
  if (sysctl(mib, 6, NULL, &len, NULL, 0) == 0) {
    char *buf = (char *)malloc(len);
    if (sysctl(mib, 6, buf, &len, NULL, 0) == 0) {
      char *end = buf + len;
      char *next = buf;
      while (next < end) {
        struct if_msghdr *ifm = (struct if_msghdr *)next;
        next += ifm->ifm_msglen;

        if (ifm->ifm_type == RTM_IFINFO2) {
          struct if_msghdr2 *ifm2 = (struct if_msghdr2 *)ifm;
          char ifname[IF_NAMESIZE];
          if (if_indextoname(ifm2->ifm_index, ifname)) {
            NSString *name = [NSString stringWithUTF8String:ifname];
            NetworkInterfaceInfo *info = ifMap[name];
            if (info) {
              info.bytesIn = ifm2->ifm_data.ifi_ibytes;
              info.bytesOut = ifm2->ifm_data.ifi_obytes;
              info.packetsIn = ifm2->ifm_data.ifi_ipackets;
              info.packetsOut = ifm2->ifm_data.ifi_opackets;
            }
          }
        }
      }
    }
    free(buf);
  }

  [interfaces addObjectsFromArray:ifMap.allValues];

  // Sort: en0 first, then en*, then others, then loopback last
  [interfaces sortUsingComparator:^NSComparisonResult(NetworkInterfaceInfo *a,
                                                      NetworkInterfaceInfo *b) {
    if ([a.name isEqualToString:@"en0"])
      return NSOrderedAscending;
    if ([b.name isEqualToString:@"en0"])
      return NSOrderedDescending;
    if (a.isLoopback)
      return NSOrderedDescending;
    if (b.isLoopback)
      return NSOrderedAscending;
    return [a.name compare:b.name];
  }];

  return interfaces;
}

- (NetworkInterfaceInfo *)primaryInterface {
  NSArray *all = [self allInterfaces];
  for (NetworkInterfaceInfo *info in all) {
    if ([info.name isEqualToString:@"en0"] && info.isUp && info.ipv4Address)
      return info;
  }
  for (NetworkInterfaceInfo *info in all) {
    if (info.isUp && !info.isLoopback && info.ipv4Address)
      return info;
  }
  return all.firstObject;
}

- (NSString *)localIPAddress {
  NetworkInterfaceInfo *primary = [self primaryInterface];
  return primary.ipv4Address ?: @"Not connected";
}

- (NSString *)defaultGateway {
  // Read routing table via sysctl for default gateway
  int mib[] = {CTL_NET, PF_ROUTE, 0, AF_INET, NET_RT_FLAGS, RTF_GATEWAY};
  size_t len;
  if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0)
    return @"Unknown";

  char *buf = (char *)malloc(len);
  if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
    free(buf);
    return @"Unknown";
  }

  NSString *gateway = @"Unknown";
  char *ptr = buf;
  char *end = buf + len;

  while (ptr < end) {
    struct rt_msghdr *rtm = (struct rt_msghdr *)ptr;
    struct sockaddr *sa = (struct sockaddr *)(rtm + 1);

    if (sa->sa_family == AF_INET) {
      struct sockaddr_in *dst = (struct sockaddr_in *)sa;
      if (dst->sin_addr.s_addr == INADDR_ANY) {
        // This is default route — next hop is gateway
#ifndef ROUNDUP
#define ROUNDUP(a)                                                             \
  ((a) > 0 ? (1 + (((a) - 1) | (sizeof(long) - 1))) : sizeof(long))
#endif
        sa = (struct sockaddr *)((char *)sa + ROUNDUP(sa->sa_len));
        if (sa->sa_family == AF_INET) {
          struct sockaddr_in *gw = (struct sockaddr_in *)sa;
          char ip[INET_ADDRSTRLEN];
          inet_ntop(AF_INET, &gw->sin_addr, ip, sizeof(ip));
          gateway = [NSString stringWithUTF8String:ip];
          break;
        }
      }
    }

    ptr += rtm->rtm_msglen;
  }

  free(buf);

  // Fallback: use netstat
  if ([gateway isEqualToString:@"Unknown"]) {
    gateway = [self gatewayFromNetstat];
  }

  return gateway;
}

- (NSString *)gatewayFromNetstat {
  NSTask *task = [[NSTask alloc] init];
  task.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/netstat"];
  task.arguments = @[ @"-rn", @"-f", @"inet" ];
  NSPipe *pipe = [NSPipe pipe];
  task.standardOutput = pipe;
  task.standardError = [NSPipe pipe];

  @try {
    [task launchAndReturnError:nil];
    [task waitUntilExit];
    NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
    NSString *output = [[NSString alloc] initWithData:data
                                             encoding:NSUTF8StringEncoding];

    for (NSString *line in [output componentsSeparatedByString:@"\n"]) {
      if ([line hasPrefix:@"default"]) {
        NSArray *parts = [line
            componentsSeparatedByCharactersInSet:[NSCharacterSet
                                                     whitespaceCharacterSet]];
        NSMutableArray *clean = [NSMutableArray array];
        for (NSString *p in parts) {
          if (p.length > 0)
            [clean addObject:p];
        }
        if (clean.count >= 2)
          return clean[1];
      }
    }
  } @catch (NSException *e) {
  }
  return @"Unknown";
}

- (NSArray<NSString *> *)dnsServers {
  NSMutableArray *servers = [NSMutableArray array];

  // Read /etc/resolv.conf
  NSString *resolv = [NSString stringWithContentsOfFile:@"/etc/resolv.conf"
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
  if (resolv) {
    for (NSString *line in [resolv componentsSeparatedByString:@"\n"]) {
      NSString *trimmed =
          [line stringByTrimmingCharactersInSet:[NSCharacterSet
                                                    whitespaceCharacterSet]];
      if ([trimmed hasPrefix:@"nameserver "]) {
        NSString *server = [trimmed substringFromIndex:11];
        server = [server
            stringByTrimmingCharactersInSet:[NSCharacterSet
                                                whitespaceCharacterSet]];
        if (server.length > 0)
          [servers addObject:server];
      }
    }
  }

  // Also try scutil for macOS-specific DNS
  if (servers.count == 0) {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/scutil"];
    task.arguments = @[ @"--dns" ];
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = [NSPipe pipe];

    @try {
      [task launchAndReturnError:nil];
      [task waitUntilExit];
      NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
      NSString *output = [[NSString alloc] initWithData:data
                                               encoding:NSUTF8StringEncoding];

      for (NSString *line in [output componentsSeparatedByString:@"\n"]) {
        NSString *trimmed =
            [line stringByTrimmingCharactersInSet:[NSCharacterSet
                                                      whitespaceCharacterSet]];
        if ([trimmed hasPrefix:@"nameserver["] ||
            [trimmed hasPrefix:@"nameserver :"]) {
          NSRange colonRange = [trimmed rangeOfString:@": "];
          if (colonRange.location != NSNotFound) {
            NSString *server =
                [trimmed substringFromIndex:NSMaxRange(colonRange)];
            if (![servers containsObject:server])
              [servers addObject:server];
          }
        }
      }
    } @catch (NSException *e) {
    }
  }

  return servers;
}

- (NSString *)externalIPAddress:(void (^)(NSString *ip))completion {
  NSURL *url = [NSURL URLWithString:@"https://api.ipify.org"];
  NSURLSessionDataTask *task = [[NSURLSession sharedSession]
        dataTaskWithURL:url
      completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        NSString *ip =
            data ? [[NSString alloc] initWithData:data
                                         encoding:NSUTF8StringEncoding]
                 : @"Unavailable";
        dispatch_async(dispatch_get_main_queue(), ^{
          if (completion)
            completion(ip);
        });
      }];
  [task resume];
  return nil;
}

// ============================================================================
#pragma mark - ICMP Ping (Real raw sockets)
// ============================================================================

static uint16_t icmp_checksum(void *data, int len) {
  uint32_t sum = 0;
  uint16_t *ptr = (uint16_t *)data;
  while (len > 1) {
    sum += *ptr++;
    len -= 2;
  }
  if (len == 1)
    sum += *(uint8_t *)ptr;
  sum = (sum >> 16) + (sum & 0xFFFF);
  sum += (sum >> 16);
  return (uint16_t)(~sum);
}

- (void)ping:(NSString *)host completion:(PingCompletion)completion {
  [self ping:host count:1 completion:completion];
}

- (void)ping:(NSString *)host
         count:(NSInteger)count
    completion:(PingCompletion)eachPing {
  dispatch_async(self.networkQueue, ^{
    // Resolve hostname
    struct addrinfo hints = {0}, *res = NULL;
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_DGRAM;

    int rc = getaddrinfo([host UTF8String], NULL, &hints, &res);
    if (rc != 0 || !res) {
      PingResult *result = [[PingResult alloc] init];
      result.host = host;
      result.success = NO;
      result.error =
          [NSString stringWithFormat:@"Cannot resolve: %s", gai_strerror(rc)];
      dispatch_async(dispatch_get_main_queue(), ^{
        if (eachPing)
          eachPing(result);
      });
      return;
    }

    struct sockaddr_in *addr = (struct sockaddr_in *)res->ai_addr;
    char resolvedIP[INET_ADDRSTRLEN];
    inet_ntop(AF_INET, &addr->sin_addr, resolvedIP, sizeof(resolvedIP));

    // Create raw ICMP socket
    int sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_ICMP);
    if (sock < 0) {
      freeaddrinfo(res);
      PingResult *result = [[PingResult alloc] init];
      result.host = host;
      result.success = NO;
      result.error = @"Cannot create socket (try running as admin)";
      dispatch_async(dispatch_get_main_queue(), ^{
        if (eachPing)
          eachPing(result);
      });
      return;
    }

    // Set timeout
    struct timeval tv = {.tv_sec = 3, .tv_usec = 0};
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    uint16_t identifier = (uint16_t)getpid();

    for (NSInteger seq = 0; seq < count; seq++) {
      // Build ICMP echo request
      struct {
        uint8_t type;
        uint8_t code;
        uint16_t checksum;
        uint16_t identifier;
        uint16_t sequence;
        uint8_t payload[56];
      } packet = {0};

      packet.type = ICMP_ECHO;
      packet.code = 0;
      packet.identifier = htons(identifier);
      packet.sequence = htons((uint16_t)seq);
      memset(packet.payload, 0x42, sizeof(packet.payload));
      packet.checksum = icmp_checksum(&packet, sizeof(packet));

      struct sockaddr_in dst = *addr;
      dst.sin_port = 0;

      // Send and time
      struct timeval sendTime, recvTime;
      gettimeofday(&sendTime, NULL);

      ssize_t sent = sendto(sock, &packet, sizeof(packet), 0,
                            (struct sockaddr *)&dst, sizeof(dst));

      PingResult *result = [[PingResult alloc] init];
      result.host = host;
      result.resolvedIP = [NSString stringWithUTF8String:resolvedIP];
      result.seq = seq;
      result.bytes = sizeof(packet);

      if (sent < 0) {
        result.success = NO;
        result.error = [NSString stringWithUTF8String:strerror(errno)];
      } else {
        // Receive reply
        uint8_t recvBuf[1024];
        struct sockaddr_in from;
        socklen_t fromLen = sizeof(from);

        ssize_t received = recvfrom(sock, recvBuf, sizeof(recvBuf), 0,
                                    (struct sockaddr *)&from, &fromLen);

        gettimeofday(&recvTime, NULL);

        if (received > 0) {
          double rtt = (recvTime.tv_sec - sendTime.tv_sec) * 1000.0 +
                       (recvTime.tv_usec - sendTime.tv_usec) / 1000.0;
          result.rttMs = rtt;
          result.ttl = 64; // Default for DGRAM sockets (no IP header)
          result.success = YES;
        } else {
          result.success = NO;
          result.error = @"Request timed out";
        }
      }

      dispatch_async(dispatch_get_main_queue(), ^{
        if (eachPing)
          eachPing(result);
      });

      if (seq < count - 1) {
        [NSThread sleepForTimeInterval:1.0];
      }
    }

    close(sock);
    freeaddrinfo(res);
  });
}

// ============================================================================
#pragma mark - DNS Resolution (Real getaddrinfo)
// ============================================================================

- (void)resolveDNS:(NSString *)hostname completion:(DNSCompletion)completion {
  dispatch_async(self.networkQueue, ^{
    DNSResult *result = [[DNSResult alloc] init];
    result.hostname = hostname;

    NSMutableArray *ipv4 = [NSMutableArray array];
    NSMutableArray *ipv6 = [NSMutableArray array];

    struct addrinfo hints = {0}, *res = NULL, *ptr;
    hints.ai_family = AF_UNSPEC; // Both IPv4 and IPv6
    hints.ai_socktype = SOCK_STREAM;
    hints.ai_flags = AI_CANONNAME;

    struct timeval start, end;
    gettimeofday(&start, NULL);

    int rc = getaddrinfo([hostname UTF8String], NULL, &hints, &res);

    gettimeofday(&end, NULL);
    result.queryTimeMs = (end.tv_sec - start.tv_sec) * 1000.0 +
                         (end.tv_usec - start.tv_usec) / 1000.0;

    if (rc != 0) {
      result.success = NO;
      result.error = [NSString stringWithFormat:@"%s", gai_strerror(rc)];
    } else {
      result.success = YES;
      if (res->ai_canonname) {
        result.canonicalName =
            [NSString stringWithUTF8String:res->ai_canonname];
      }

      for (ptr = res; ptr != NULL; ptr = ptr->ai_next) {
        if (ptr->ai_family == AF_INET) {
          char addr[INET_ADDRSTRLEN];
          struct sockaddr_in *sin = (struct sockaddr_in *)ptr->ai_addr;
          inet_ntop(AF_INET, &sin->sin_addr, addr, sizeof(addr));
          NSString *ip = [NSString stringWithUTF8String:addr];
          if (![ipv4 containsObject:ip])
            [ipv4 addObject:ip];
        } else if (ptr->ai_family == AF_INET6) {
          char addr[INET6_ADDRSTRLEN];
          struct sockaddr_in6 *sin6 = (struct sockaddr_in6 *)ptr->ai_addr;
          inet_ntop(AF_INET6, &sin6->sin6_addr, addr, sizeof(addr));
          NSString *ip = [NSString stringWithUTF8String:addr];
          if (![ipv6 containsObject:ip])
            [ipv6 addObject:ip];
        }
      }
      freeaddrinfo(res);
    }

    result.ipv4Addresses = ipv4;
    result.ipv6Addresses = ipv6;

    dispatch_async(dispatch_get_main_queue(), ^{
      if (completion)
        completion(result);
    });
  });
}

- (NSString *)reverseDNS:(NSString *)ipAddress {
  struct sockaddr_in sa = {0};
  sa.sin_family = AF_INET;
  sa.sin_len = sizeof(sa);
  inet_pton(AF_INET, [ipAddress UTF8String], &sa.sin_addr);

  char host[NI_MAXHOST];
  int rc = getnameinfo((struct sockaddr *)&sa, sizeof(sa), host, sizeof(host),
                       NULL, 0, 0);
  if (rc == 0) {
    return [NSString stringWithUTF8String:host];
  }
  return ipAddress;
}

// ============================================================================
#pragma mark - Live Throughput Monitoring
// ============================================================================

- (void)startThroughputMonitoring:(ThroughputCallback)callback
                         interval:(NSTimeInterval)interval {
  [self stopThroughputMonitoring];

  self.throughputCallback = callback;

  // Get initial byte counts
  NetworkInterfaceInfo *primary = [self primaryInterface];
  self.lastBytesIn = primary.bytesIn;
  self.lastBytesOut = primary.bytesOut;

  self.throughputTimer = [NSTimer
      scheduledTimerWithTimeInterval:interval
                             repeats:YES
                               block:^(NSTimer *timer) {
                                 NetworkInterfaceInfo *iface =
                                     [self primaryInterface];

                                 double inPerSec = (double)(iface.bytesIn -
                                                            self.lastBytesIn) /
                                                   interval;
                                 double outPerSec =
                                     (double)(iface.bytesOut -
                                              self.lastBytesOut) /
                                     interval;

                                 self.lastBytesIn = iface.bytesIn;
                                 self.lastBytesOut = iface.bytesOut;

                                 if (self.throughputCallback) {
                                   self.throughputCallback(inPerSec, outPerSec);
                                 }
                               }];
}

- (void)stopThroughputMonitoring {
  [self.throughputTimer invalidate];
  self.throughputTimer = nil;
  self.throughputCallback = nil;
}

// ============================================================================
#pragma mark - Port Checking (Real TCP connect)
// ============================================================================

- (void)checkPort:(NSInteger)port
           onHost:(NSString *)host
          timeout:(NSTimeInterval)timeout
       completion:(void (^)(BOOL open, double latencyMs))completion {
  dispatch_async(self.networkQueue, ^{
    struct addrinfo hints = {0}, *res = NULL;
    hints.ai_family = AF_INET;
    hints.ai_socktype = SOCK_STREAM;

    NSString *portStr = [NSString stringWithFormat:@"%ld", (long)port];
    int rc = getaddrinfo([host UTF8String], [portStr UTF8String], &hints, &res);

    if (rc != 0 || !res) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (completion)
          completion(NO, -1);
      });
      return;
    }

    int sock = socket(res->ai_family, SOCK_STREAM, 0);
    if (sock < 0) {
      freeaddrinfo(res);
      dispatch_async(dispatch_get_main_queue(), ^{
        if (completion)
          completion(NO, -1);
      });
      return;
    }

    // Non-blocking connect with timeout
    int flags = fcntl(sock, F_GETFL, 0);
    fcntl(sock, F_SETFL, flags | O_NONBLOCK);

    struct timeval start, end;
    gettimeofday(&start, NULL);

    connect(sock, res->ai_addr, res->ai_addrlen);

    fd_set writefds;
    FD_ZERO(&writefds);
    FD_SET(sock, &writefds);

    struct timeval tv;
    tv.tv_sec = (long)timeout;
    tv.tv_usec = (long)((timeout - (long)timeout) * 1000000);

    int selectResult = select(sock + 1, NULL, &writefds, NULL, &tv);

    gettimeofday(&end, NULL);
    double latency = (end.tv_sec - start.tv_sec) * 1000.0 +
                     (end.tv_usec - start.tv_usec) / 1000.0;

    BOOL isOpen = NO;
    if (selectResult > 0) {
      int error = 0;
      socklen_t len = sizeof(error);
      getsockopt(sock, SOL_SOCKET, SO_ERROR, &error, &len);
      isOpen = (error == 0);
    }

    close(sock);
    freeaddrinfo(res);

    dispatch_async(dispatch_get_main_queue(), ^{
      if (completion)
        completion(isOpen, isOpen ? latency : -1);
    });
  });
}

// ============================================================================
#pragma mark - Utilities
// ============================================================================

- (NSString *)macAddressForInterface:(NSString *)ifName {
  struct ifaddrs *ifaddr, *ifa;
  if (getifaddrs(&ifaddr) != 0)
    return @"Unknown";

  NSString *mac = @"Unknown";
  for (ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
    if (strcmp(ifa->ifa_name, [ifName UTF8String]) != 0)
      continue;
    if (ifa->ifa_addr && ifa->ifa_addr->sa_family == AF_LINK) {
      mac = [self macFromSockaddr:ifa->ifa_addr];
      break;
    }
  }
  freeifaddrs(ifaddr);
  return mac;
}

- (NSString *)macFromSockaddr:(struct sockaddr *)addr {
  struct sockaddr_dl *sdl = (struct sockaddr_dl *)addr;
  if (sdl->sdl_alen != 6)
    return @"Unknown";
  unsigned char *mac = (unsigned char *)LLADDR(sdl);
  return [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X", mac[0],
                                    mac[1], mac[2], mac[3], mac[4], mac[5]];
}

- (NSDictionary *)networkStatistics {
  NSMutableDictionary *stats = [NSMutableDictionary dictionary];

  WiFiConnectionDetails *conn = [self currentConnectionDetails];
  stats[@"ssid"] = conn.ssid ?: @"None";
  stats[@"ip"] = conn.ipAddress ?: @"None";
  stats[@"gateway"] = conn.routerIP ?: @"Unknown";
  stats[@"dns"] = conn.dnsServers ?: @[];
  stats[@"rssi"] = @(conn.rssi);
  stats[@"txRate"] = @(conn.txRate);
  stats[@"channel"] = @(conn.channel);
  stats[@"band"] = conn.band ?: @"Unknown";
  stats[@"security"] = conn.securityType ?: @"Unknown";
  stats[@"bssid"] = conn.bssid ?: @"Unknown";
  stats[@"mac"] = conn.macAddress ?: @"Unknown";

  return stats;
}

@end
