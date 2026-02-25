#import "NetworkUtilityWindow.h"
#import "../services/NetworkEngine.h"
#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <sys/socket.h>

@interface NetworkUtilityWindow () <NSTableViewDataSource, NSTableViewDelegate>
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSTabView *tabView;
@property(nonatomic, strong) NSTableView *interfaceTable;
@property(nonatomic, strong) NSMutableArray<NetworkInterfaceInfo *> *interfaces;
@property(nonatomic, strong) NSTextField *pingHostField, *pingResultField;
@property(nonatomic, strong) NSTextField *dnsHostField, *dnsResultField;
@property(nonatomic, strong) NSTextField *traceHostField, *traceResultField;
@property(nonatomic, strong) NSTextField *portScanField, *portResultField;
@property(nonatomic, strong) NSTextField *whoisField, *whoisResultField;
@property(nonatomic, strong) NetworkEngine *engine;
@end

@implementation NetworkUtilityWindow

+ (instancetype)sharedInstance {
  static NetworkUtilityWindow *inst;
  static dispatch_once_t t;
  dispatch_once(&t, ^{
    inst = [[self alloc] init];
  });
  return inst;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _interfaces = [NSMutableArray array];
    _engine = [NetworkEngine sharedInstance];
  }
  return self;
}

- (void)showWindow {
  if (self.window) {
    [self.window makeKeyAndOrderFront:nil];
    return;
  }

  self.window = [[NSWindow alloc]
      initWithContentRect:NSMakeRect(140, 100, 800, 600)
                styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                          NSWindowStyleMaskMiniaturizable |
                          NSWindowStyleMaskResizable
                  backing:NSBackingStoreBuffered
                    defer:NO];
  self.window.title = @"Network Utility";
  self.window.backgroundColor = [NSColor colorWithRed:0.12
                                                green:0.12
                                                 blue:0.14
                                                alpha:1.0];

  NSView *content = self.window.contentView;

  self.tabView = [[NSTabView alloc] initWithFrame:NSMakeRect(10, 10, 780, 580)];
  self.tabView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  NSTabViewItem *infoTab = [[NSTabViewItem alloc] initWithIdentifier:@"info"];
  infoTab.label = @"Info";
  [self setupInfoTab:infoTab.view];
  [self.tabView addTabViewItem:infoTab];

  NSTabViewItem *pingTab = [[NSTabViewItem alloc] initWithIdentifier:@"ping"];
  pingTab.label = @"Ping";
  [self setupPingTab:pingTab.view];
  [self.tabView addTabViewItem:pingTab];

  NSTabViewItem *dnsTab = [[NSTabViewItem alloc] initWithIdentifier:@"dns"];
  dnsTab.label = @"Lookup";
  [self setupLookupTab:dnsTab.view];
  [self.tabView addTabViewItem:dnsTab];

  NSTabViewItem *traceTab = [[NSTabViewItem alloc] initWithIdentifier:@"trace"];
  traceTab.label = @"Traceroute";
  [self setupTracerouteTab:traceTab.view];
  [self.tabView addTabViewItem:traceTab];

  NSTabViewItem *portTab = [[NSTabViewItem alloc] initWithIdentifier:@"port"];
  portTab.label = @"Port Scan";
  [self setupPortScanTab:portTab.view];
  [self.tabView addTabViewItem:portTab];

  NSTabViewItem *whoisTab = [[NSTabViewItem alloc] initWithIdentifier:@"whois"];
  whoisTab.label = @"Whois";
  [self setupWhoisTab:whoisTab.view];
  [self.tabView addTabViewItem:whoisTab];

  [content addSubview:self.tabView];
  [self loadInterfaces];
  [self.window makeKeyAndOrderFront:nil];
}

- (void)setupInfoTab:(NSView *)view {
  NSScrollView *scroll =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 10, 750, 500)];
  scroll.hasVerticalScroller = YES;
  scroll.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

  self.interfaceTable = [[NSTableView alloc] initWithFrame:scroll.bounds];
  self.interfaceTable.dataSource = self;
  self.interfaceTable.delegate = self;
  self.interfaceTable.rowHeight = 28;
  self.interfaceTable.backgroundColor = [NSColor colorWithRed:0.14
                                                        green:0.14
                                                         blue:0.17
                                                        alpha:1.0];

  NSArray *cols = @[
    @[ @"name", @"Interface", @(80) ], @[ @"displayName", @"Type", @(100) ],
    @[ @"ipv4", @"IPv4", @(130) ], @[ @"ipv6", @"IPv6", @(170) ],
    @[ @"mask", @"Netmask", @(120) ], @[ @"status", @"Status", @(60) ],
    @[ @"mac", @"MAC Address", @(140) ]
  ];
  for (NSArray *c in cols) {
    NSTableColumn *col = [[NSTableColumn alloc] initWithIdentifier:c[0]];
    col.title = c[1];
    col.width = [c[2] floatValue];
    [self.interfaceTable addTableColumn:col];
  }
  scroll.documentView = self.interfaceTable;
  [view addSubview:scroll];
}

- (void)makeToolTabIn:(NSView *)view
              hostOut:(NSTextField **)hf
            resultOut:(NSTextField **)rf
          buttonTitle:(NSString *)btnTitle
               action:(SEL)action {
  NSTextField *host =
      [[NSTextField alloc] initWithFrame:NSMakeRect(20, 470, 400, 24)];
  host.placeholderString = @"Enter hostname or IP address";
  [view addSubview:host];
  *hf = host;

  NSButton *btn =
      [[NSButton alloc] initWithFrame:NSMakeRect(440, 470, 100, 28)];
  btn.title = btnTitle;
  btn.bezelStyle = NSBezelStyleRounded;
  btn.target = self;
  btn.action = action;
  [view addSubview:btn];

  NSScrollView *scroll =
      [[NSScrollView alloc] initWithFrame:NSMakeRect(20, 20, 720, 430)];
  scroll.hasVerticalScroller = YES;
  NSTextField *result =
      [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 720, 430)];
  result.editable = NO;
  result.font = [NSFont monospacedSystemFontOfSize:11
                                            weight:NSFontWeightRegular];
  result.textColor = [NSColor systemGreenColor];
  result.backgroundColor = [NSColor blackColor];
  result.bezeled = YES;
  result.drawsBackground = YES;
  scroll.documentView = result;
  [view addSubview:scroll];
  *rf = result;
}

- (void)setupPingTab:(NSView *)v {
  NSTextField *h = nil, *r = nil;
  [self makeToolTabIn:v
              hostOut:&h
            resultOut:&r
          buttonTitle:@"Ping"
               action:@selector(doPing:)];
  self.pingHostField = h;
  self.pingResultField = r;
}
- (void)setupLookupTab:(NSView *)v {
  NSTextField *h = nil, *r = nil;
  [self makeToolTabIn:v
              hostOut:&h
            resultOut:&r
          buttonTitle:@"Lookup"
               action:@selector(doLookup:)];
  self.dnsHostField = h;
  self.dnsResultField = r;
}
- (void)setupTracerouteTab:(NSView *)v {
  NSTextField *h = nil, *r = nil;
  [self makeToolTabIn:v
              hostOut:&h
            resultOut:&r
          buttonTitle:@"Trace"
               action:@selector(doTraceroute:)];
  self.traceHostField = h;
  self.traceResultField = r;
}
- (void)setupPortScanTab:(NSView *)v {
  NSTextField *h = nil, *r = nil;
  [self makeToolTabIn:v
              hostOut:&h
            resultOut:&r
          buttonTitle:@"Scan"
               action:@selector(doPortScan:)];
  self.portScanField = h;
  self.portResultField = r;
}
- (void)setupWhoisTab:(NSView *)v {
  NSTextField *h = nil, *r = nil;
  [self makeToolTabIn:v
              hostOut:&h
            resultOut:&r
          buttonTitle:@"Whois"
               action:@selector(doWhois:)];
  self.whoisField = h;
  self.whoisResultField = r;
}

// ===== Load Real Interfaces via NetworkEngine =====
- (void)loadInterfaces {
  [self.interfaces removeAllObjects];
  NSArray<NetworkInterfaceInfo *> *all = [self.engine allInterfaces];
  [self.interfaces addObjectsFromArray:all];
  [self.interfaceTable reloadData];
}

// ===== Real ICMP Ping via NetworkEngine =====
- (void)doPing:(id)sender {
  NSString *host = self.pingHostField.stringValue;
  if (host.length == 0)
    host = @"8.8.8.8";

  NSMutableString *result = [NSMutableString
      stringWithFormat:@"PING %@ — sending 5 real ICMP packets\n\n", host];
  self.pingResultField.stringValue = result;

  __block NSMutableArray<NSNumber *> *rtts = [NSMutableArray array];
  __block NSInteger received = 0;
  __block NSInteger total = 5;

  [self.engine
            ping:host
           count:5
      completion:^(PingResult *ping) {
        if (ping.success) {
          [result
              appendFormat:@"%ld bytes from %@: icmp_seq=%ld time=%.2f ms\n",
                           (long)ping.bytes, ping.resolvedIP, (long)ping.seq,
                           ping.rttMs];
          [rtts addObject:@(ping.rttMs)];
          received++;
        } else {
          [result appendFormat:@"Request seq=%ld: %@\n", (long)ping.seq,
                               ping.error];
        }

        if (ping.seq >= total - 1) {
          [result appendFormat:@"\n--- %@ ping statistics ---\n", host];
          [result appendFormat:
                      @"%ld packets transmitted, %ld received, %.1f%% loss\n",
                      (long)total, (long)received,
                      (1.0 - (double)received / total) * 100.0];

          if (rtts.count > 0) {
            double min = INFINITY, max = 0, sum = 0;
            for (NSNumber *r in rtts) {
              double v = r.doubleValue;
              if (v < min)
                min = v;
              if (v > max)
                max = v;
              sum += v;
            }
            [result
                appendFormat:@"round-trip min/avg/max = %.2f/%.2f/%.2f ms\n",
                             min, sum / rtts.count, max];
          }
        }

        self.pingResultField.stringValue = result;
      }];
}

// ===== Real DNS Lookup via NetworkEngine =====
- (void)doLookup:(id)sender {
  NSString *host = self.dnsHostField.stringValue;
  if (host.length == 0)
    host = @"apple.com";

  self.dnsResultField.stringValue =
      [NSString stringWithFormat:@"Resolving %@...\n", host];

  [self.engine
      resolveDNS:host
      completion:^(DNSResult *dns) {
        NSMutableString *result = [NSMutableString string];

        if (dns.success) {
          [result appendFormat:@"DNS lookup for: %@\n", dns.hostname];
          if (dns.canonicalName)
            [result appendFormat:@"Canonical name: %@\n", dns.canonicalName];
          [result appendFormat:@"Query time: %.2f ms\n\n", dns.queryTimeMs];

          if (dns.ipv4Addresses.count > 0) {
            [result appendString:@"IPv4 Addresses:\n"];
            for (NSString *ip in dns.ipv4Addresses) {
              NSString *rdns = [self.engine reverseDNS:ip];
              [result appendFormat:@"  %@", ip];
              if (![rdns isEqualToString:ip])
                [result appendFormat:@" → %@", rdns];
              [result appendString:@"\n"];
            }
          }

          if (dns.ipv6Addresses.count > 0) {
            [result appendString:@"\nIPv6 Addresses:\n"];
            for (NSString *ip in dns.ipv6Addresses) {
              [result appendFormat:@"  %@\n", ip];
            }
          }

          [result appendFormat:@"\nTotal: %lu IPv4, %lu IPv6 addresses\n",
                               (unsigned long)dns.ipv4Addresses.count,
                               (unsigned long)dns.ipv6Addresses.count];
        } else {
          [result appendFormat:@"DNS lookup failed: %@\n", dns.error];
        }

        self.dnsResultField.stringValue = result;
      }];
}

// ===== Real Traceroute via system command =====
- (void)doTraceroute:(id)sender {
  NSString *host = self.traceHostField.stringValue;
  if (host.length == 0)
    host = @"google.com";

  self.traceResultField.stringValue =
      [NSString stringWithFormat:@"traceroute to %@ ...\n", host];

  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        task.executableURL = [NSURL fileURLWithPath:@"/usr/sbin/traceroute"];
        task.arguments = @[ @"-m", @"15", @"-w", @"2", host ];
        NSPipe *pipe = [NSPipe pipe];
        task.standardOutput = pipe;
        task.standardError = pipe;

        @try {
          [task launchAndReturnError:nil];

          // Read output line by line
          NSFileHandle *fh = pipe.fileHandleForReading;
          NSMutableString *output = [NSMutableString string];

          NSData *data;
          while ((data = [fh availableData]) && data.length > 0) {
            NSString *line =
                [[NSString alloc] initWithData:data
                                      encoding:NSUTF8StringEncoding];
            [output appendString:line];
            dispatch_async(dispatch_get_main_queue(), ^{
              self.traceResultField.stringValue = output;
            });
          }

          [task waitUntilExit];
        } @catch (NSException *e) {
          dispatch_async(dispatch_get_main_queue(), ^{
            self.traceResultField.stringValue = [NSString
                stringWithFormat:@"traceroute failed: %@\n", e.reason];
          });
        }
      });
}

// ===== Real Port Scan via TCP connect =====
- (void)doPortScan:(id)sender {
  NSString *host = self.portScanField.stringValue;
  if (host.length == 0)
    host = @"localhost";

  NSArray *commonPorts = @[
    @22, @53, @80, @443, @3000, @3306, @5432, @5900, @6379, @8080, @8443, @9090
  ];
  NSDictionary *services = @{
    @22 : @"SSH",
    @53 : @"DNS",
    @80 : @"HTTP",
    @443 : @"HTTPS",
    @3000 : @"Dev Server",
    @3306 : @"MySQL",
    @5432 : @"PostgreSQL",
    @5900 : @"VNC",
    @6379 : @"Redis",
    @8080 : @"HTTP-Alt",
    @8443 : @"HTTPS-Alt",
    @9090 : @"Prometheus"
  };

  NSMutableString *result =
      [NSMutableString stringWithFormat:@"Real TCP port scan of %@\n\nPORT     "
                                        @"  STATE    SERVICE         LATENCY\n",
                                        host];
  self.portResultField.stringValue = result;

  for (NSNumber *port in commonPorts) {
    [self.engine
         checkPort:port.integerValue
            onHost:host
           timeout:1.5
        completion:^(BOOL open, double latencyMs) {
          NSString *state = open ? @"open" : @"closed";
          NSString *service = services[port] ?: @"unknown";
          NSString *latency =
              open ? [NSString stringWithFormat:@"%.1f ms", latencyMs] : @"—";

          [result appendFormat:@"%-10s %-8s %-15s %@\n",
                               [NSString stringWithFormat:@"%@/tcp", port]
                                   .UTF8String,
                               state.UTF8String, service.UTF8String, latency];

          self.portResultField.stringValue = result;
        }];
  }
}

// ===== Real Whois via whois command =====
- (void)doWhois:(id)sender {
  NSString *host = self.whoisField.stringValue;
  if (host.length == 0)
    host = @"apple.com";

  self.whoisResultField.stringValue =
      [NSString stringWithFormat:@"Looking up %@...\n", host];

  dispatch_async(
      dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSTask *task = [[NSTask alloc] init];
        task.executableURL = [NSURL fileURLWithPath:@"/usr/bin/whois"];
        task.arguments = @[ host ];
        NSPipe *pipe = [NSPipe pipe];
        task.standardOutput = pipe;
        task.standardError = pipe;

        @try {
          [task launchAndReturnError:nil];
          [task waitUntilExit];

          NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
          NSString *output =
              [[NSString alloc] initWithData:data
                                    encoding:NSUTF8StringEncoding];

          dispatch_async(dispatch_get_main_queue(), ^{
            self.whoisResultField.stringValue = output ?: @"No results";
          });
        } @catch (NSException *e) {
          dispatch_async(dispatch_get_main_queue(), ^{
            self.whoisResultField.stringValue =
                [NSString stringWithFormat:@"Whois failed: %@", e.reason];
          });
        }
      });
}

// ===== TableView with Real Data =====
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tv {
  return self.interfaces.count;
}

- (NSView *)tableView:(NSTableView *)tv
    viewForTableColumn:(NSTableColumn *)col
                   row:(NSInteger)row {
  NSTableCellView *cell = [tv makeViewWithIdentifier:col.identifier owner:self];
  if (!cell) {
    cell =
        [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, col.width, 28)];
    cell.identifier = col.identifier;
    NSTextField *tf = [[NSTextField alloc] initWithFrame:cell.bounds];
    tf.editable = NO;
    tf.bordered = NO;
    tf.drawsBackground = NO;
    tf.textColor = [NSColor whiteColor];
    tf.font = [NSFont monospacedSystemFontOfSize:10 weight:NSFontWeightRegular];
    cell.textField = tf;
    [cell addSubview:tf];
  }

  NetworkInterfaceInfo *iface = self.interfaces[row];
  NSString *colId = col.identifier;

  if ([colId isEqualToString:@"name"]) {
    cell.textField.stringValue = iface.name;
  } else if ([colId isEqualToString:@"displayName"]) {
    cell.textField.stringValue = iface.displayName ?: iface.name;
  } else if ([colId isEqualToString:@"ipv4"]) {
    cell.textField.stringValue = iface.ipv4Address ?: @"—";
  } else if ([colId isEqualToString:@"ipv6"]) {
    cell.textField.stringValue = iface.ipv6Address ?: @"—";
    cell.textField.font =
        [NSFont monospacedSystemFontOfSize:8 weight:NSFontWeightRegular];
  } else if ([colId isEqualToString:@"mask"]) {
    cell.textField.stringValue = iface.subnetMask ?: @"—";
  } else if ([colId isEqualToString:@"status"]) {
    cell.textField.stringValue = iface.isUp ? @"Up" : @"Down";
    cell.textField.textColor =
        iface.isUp ? [NSColor systemGreenColor] : [NSColor systemRedColor];
    return cell;
  } else if ([colId isEqualToString:@"mac"]) {
    cell.textField.stringValue = iface.macAddress ?: @"—";
  }

  cell.textField.textColor = [NSColor whiteColor];
  return cell;
}

@end
