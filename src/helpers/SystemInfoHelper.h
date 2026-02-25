#import <Cocoa/Cocoa.h>

@interface SystemInfoHelper : NSObject

+ (NSString *)cpuModel;
+ (NSString *)memorySize;
+ (NSString *)osVersion;
+ (NSString *)computerName;
+ (NSString *)serialNumber;
+ (NSString *)uptime;
+ (NSString *)gpuModel;
+ (NSUInteger)cpuCoreCount;
+ (double)memoryUsagePercent;

@end
