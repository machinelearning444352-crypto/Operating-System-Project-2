#import "SystemInfoHelper.h"
#include <sys/sysctl.h>
#include <mach/mach.h>

@implementation SystemInfoHelper

+ (NSString *)cpuModel {
    char buffer[256];
    size_t size = sizeof(buffer);
    if (sysctlbyname("machdep.cpu.brand_string", buffer, &size, NULL, 0) == 0) {
        return [NSString stringWithUTF8String:buffer];
    }
    return @"Unknown CPU";
}

+ (NSString *)memorySize {
    int64_t memSize;
    size_t size = sizeof(memSize);
    if (sysctlbyname("hw.memsize", &memSize, &size, NULL, 0) == 0) {
        double gb = memSize / (1024.0 * 1024.0 * 1024.0);
        return [NSString stringWithFormat:@"%.0f GB", gb];
    }
    return @"Unknown";
}

+ (NSString *)osVersion {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSOperatingSystemVersion version = [processInfo operatingSystemVersion];
    
    NSString *versionName;
    if (version.majorVersion >= 14) {
        versionName = @"Sonoma";
    } else if (version.majorVersion == 13) {
        versionName = @"Ventura";
    } else if (version.majorVersion == 12) {
        versionName = @"Monterey";
    } else if (version.majorVersion == 11) {
        versionName = @"Big Sur";
    } else {
        versionName = @"macOS";
    }
    
    return [NSString stringWithFormat:@"macOS %@ %ld.%ld.%ld",
            versionName,
            (long)version.majorVersion,
            (long)version.minorVersion,
            (long)version.patchVersion];
}

+ (NSString *)computerName {
    return [[NSHost currentHost] localizedName];
}

+ (NSString *)serialNumber {
    io_service_t platformExpert = IOServiceGetMatchingService(kIOMasterPortDefault,
                                                               IOServiceMatching("IOPlatformExpertDevice"));
    if (platformExpert) {
        CFTypeRef serialNumberAsCFString = IORegistryEntryCreateCFProperty(platformExpert,
                                                                            CFSTR(kIOPlatformSerialNumberKey),
                                                                            kCFAllocatorDefault, 0);
        IOObjectRelease(platformExpert);
        if (serialNumberAsCFString) {
            NSString *serial = (__bridge_transfer NSString *)serialNumberAsCFString;
            return serial;
        }
    }
    return @"XXXX-XXXX-XXXX";
}

+ (NSString *)uptime {
    NSProcessInfo *processInfo = [NSProcessInfo processInfo];
    NSTimeInterval uptime = [processInfo systemUptime];
    
    int days = (int)(uptime / 86400);
    int hours = (int)((uptime - days * 86400) / 3600);
    int minutes = (int)((uptime - days * 86400 - hours * 3600) / 60);
    
    if (days > 0) {
        return [NSString stringWithFormat:@"%d days, %d hours, %d minutes", days, hours, minutes];
    } else if (hours > 0) {
        return [NSString stringWithFormat:@"%d hours, %d minutes", hours, minutes];
    } else {
        return [NSString stringWithFormat:@"%d minutes", minutes];
    }
}

+ (NSString *)gpuModel {
    // Try to get GPU info from system profiler
    io_iterator_t iterator;
    if (IOServiceGetMatchingServices(kIOMasterPortDefault,
                                     IOServiceMatching("IOPCIDevice"),
                                     &iterator) == kIOReturnSuccess) {
        io_service_t device;
        while ((device = IOIteratorNext(iterator))) {
            CFTypeRef model = IORegistryEntryCreateCFProperty(device,
                                                               CFSTR("model"),
                                                               kCFAllocatorDefault, 0);
            if (model) {
                NSData *data = (__bridge_transfer NSData *)model;
                NSString *modelString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                if (modelString && [modelString containsString:@"GPU"]) {
                    IOObjectRelease(device);
                    IOObjectRelease(iterator);
                    return modelString;
                }
            }
            IOObjectRelease(device);
        }
        IOObjectRelease(iterator);
    }
    
    // Fallback based on CPU
    NSString *cpu = [self cpuModel];
    if ([cpu containsString:@"Apple"]) {
        if ([cpu containsString:@"M3"]) return @"Apple M3 GPU (10-core)";
        if ([cpu containsString:@"M2"]) return @"Apple M2 GPU (10-core)";
        if ([cpu containsString:@"M1"]) return @"Apple M1 GPU (8-core)";
    }
    return @"Integrated Graphics";
}

+ (NSUInteger)cpuCoreCount {
    return [[NSProcessInfo processInfo] processorCount];
}

+ (double)memoryUsagePercent {
    vm_size_t pageSize;
    mach_port_t machPort = mach_host_self();
    vm_statistics64_data_t vmStats;
    mach_msg_type_number_t count = sizeof(vmStats) / sizeof(natural_t);
    
    if (host_page_size(machPort, &pageSize) == KERN_SUCCESS &&
        host_statistics64(machPort, HOST_VM_INFO64, (host_info64_t)&vmStats, &count) == KERN_SUCCESS) {
        
        int64_t totalMem;
        size_t size = sizeof(totalMem);
        sysctlbyname("hw.memsize", &totalMem, &size, NULL, 0);
        
        uint64_t usedMem = (vmStats.active_count + vmStats.wire_count) * pageSize;
        return (double)usedMem / (double)totalMem * 100.0;
    }
    return 0.0;
}

@end
