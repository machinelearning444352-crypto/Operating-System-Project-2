#pragma once
#import <Cocoa/Cocoa.h>
#import <CoreWLAN/CoreWLAN.h>

// ============================================================================
// NETWORK ENGINE — Real WiFi, TCP/IP, DNS, ICMP from scratch
// ============================================================================

// WiFi Network Entry (from real scan)
@interface WiFiNetworkEntry : NSObject
@property(nonatomic, strong) NSString *ssid;
@property(nonatomic, strong) NSString *bssid;
@property(nonatomic, assign) NSInteger rssi;
@property(nonatomic, assign) NSInteger noiseMeasurement;
@property(nonatomic, strong) NSString *securityType;
@property(nonatomic, assign) BOOL isSecured;
@property(nonatomic, assign) NSInteger channel;
@property(nonatomic, strong) NSString *band;    // 2.4GHz, 5GHz, 6GHz
@property(nonatomic, strong) NSString *phyMode; // 802.11ax, ac, n, etc.
@property(nonatomic, assign) BOOL isCurrentNetwork;
@property(nonatomic, strong) CWNetwork *rawNetwork; // CoreWLAN object
@end

// Network Interface Info (from real system)
@interface NetworkInterfaceInfo : NSObject
@property(nonatomic, strong) NSString *name; // en0, en1, lo0...
@property(nonatomic, strong) NSString *displayName;
@property(nonatomic, strong) NSString *ipv4Address;
@property(nonatomic, strong) NSString *ipv6Address;
@property(nonatomic, strong) NSString *subnetMask;
@property(nonatomic, strong) NSString *broadcastAddr;
@property(nonatomic, strong) NSString *macAddress;
@property(nonatomic, assign) BOOL isUp;
@property(nonatomic, assign) BOOL isRunning;
@property(nonatomic, assign) BOOL isLoopback;
@property(nonatomic, assign) uint64_t bytesIn;
@property(nonatomic, assign) uint64_t bytesOut;
@property(nonatomic, assign) uint64_t packetsIn;
@property(nonatomic, assign) uint64_t packetsOut;
@end

// Connection Details (from real system)
@interface WiFiConnectionDetails : NSObject
@property(nonatomic, strong) NSString *ssid;
@property(nonatomic, strong) NSString *bssid;
@property(nonatomic, assign) NSInteger rssi;
@property(nonatomic, assign) NSInteger noise;
@property(nonatomic, assign) NSInteger channel;
@property(nonatomic, strong) NSString *band;
@property(nonatomic, strong) NSString *phyMode;
@property(nonatomic, assign) double txRate; // Mbps
@property(nonatomic, strong) NSString *securityType;
@property(nonatomic, strong) NSString *ipAddress;
@property(nonatomic, strong) NSString *subnetMask;
@property(nonatomic, strong) NSString *routerIP;
@property(nonatomic, strong) NSArray<NSString *> *dnsServers;
@property(nonatomic, strong) NSString *macAddress;
@property(nonatomic, assign) double throughputIn; // bytes/sec
@property(nonatomic, assign) double throughputOut;
@end

// Ping Result
@interface PingResult : NSObject
@property(nonatomic, strong) NSString *host;
@property(nonatomic, strong) NSString *resolvedIP;
@property(nonatomic, assign) double rttMs;
@property(nonatomic, assign) NSInteger ttl;
@property(nonatomic, assign) NSInteger seq;
@property(nonatomic, assign) NSInteger bytes;
@property(nonatomic, assign) BOOL success;
@property(nonatomic, strong) NSString *error;
@end

// DNS Result
@interface DNSResult : NSObject
@property(nonatomic, strong) NSString *hostname;
@property(nonatomic, strong) NSArray<NSString *> *ipv4Addresses;
@property(nonatomic, strong) NSArray<NSString *> *ipv6Addresses;
@property(nonatomic, strong) NSString *canonicalName;
@property(nonatomic, assign) double queryTimeMs;
@property(nonatomic, assign) BOOL success;
@property(nonatomic, strong) NSString *error;
@end

// Callbacks
typedef void (^NetworkScanCompletion)(NSArray<WiFiNetworkEntry *> *networks,
                                      NSError *error);
typedef void (^NetworkConnectCompletion)(BOOL success, NSString *errorMessage);
typedef void (^PingCompletion)(PingResult *result);
typedef void (^DNSCompletion)(DNSResult *result);
typedef void (^ThroughputCallback)(double bytesInPerSec, double bytesOutPerSec);

// ============================================================================
// NETWORK ENGINE
// ============================================================================
@interface NetworkEngine : NSObject

+ (instancetype)sharedInstance;

// === WiFi Control (Real CoreWLAN) ===
- (void)scanForNetworks:(NetworkScanCompletion)completion;
- (void)connectToNetwork:(NSString *)ssid
                password:(NSString *)password
              completion:(NetworkConnectCompletion)completion;
- (void)connectToOpenNetwork:(NSString *)ssid
                  completion:(NetworkConnectCompletion)completion;
- (void)disconnectFromCurrentNetwork;
- (BOOL)isWiFiEnabled;
- (void)setWiFiEnabled:(BOOL)enabled;
- (WiFiConnectionDetails *)currentConnectionDetails;
- (NSString *)currentSSID;

// === Network Interface Info (Real BSD/sysctl) ===
- (NSArray<NetworkInterfaceInfo *> *)allInterfaces;
- (NetworkInterfaceInfo *)primaryInterface;
- (NSString *)localIPAddress;
- (NSString *)defaultGateway;
- (NSArray<NSString *> *)dnsServers;
- (NSString *)externalIPAddress:(void (^)(NSString *ip))completion;

// === ICMP Ping (Real raw sockets) ===
- (void)ping:(NSString *)host
         count:(NSInteger)count
    completion:(PingCompletion)eachPing;
- (void)ping:(NSString *)host completion:(PingCompletion)completion;

// === DNS Resolution (Real getaddrinfo) ===
- (void)resolveDNS:(NSString *)hostname completion:(DNSCompletion)completion;
- (NSString *)reverseDNS:(NSString *)ipAddress;

// === Live Throughput Monitoring ===
- (void)startThroughputMonitoring:(ThroughputCallback)callback
                         interval:(NSTimeInterval)interval;
- (void)stopThroughputMonitoring;

// === Port Checking (Real TCP connect) ===
- (void)checkPort:(NSInteger)port
           onHost:(NSString *)host
          timeout:(NSTimeInterval)timeout
       completion:(void (^)(BOOL open, double latencyMs))completion;

// === Utilities ===
- (NSString *)macAddressForInterface:(NSString *)ifName;
- (NSDictionary *)networkStatistics;

@end
