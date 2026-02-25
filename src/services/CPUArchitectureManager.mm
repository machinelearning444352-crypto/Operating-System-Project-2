#import "CPUArchitectureManager.h"
#include <sys/sysctl.h>

@implementation CPUCacheLevel
- (instancetype)initWithLevel:(NSUInteger)l
                         type:(NSString *)t
                       sizeKB:(NSUInteger)s
                         ways:(NSUInteger)w
                     lineSize:(NSUInteger)ls {
  self = [super init];
  if (self) {
    _level = l;
    _type = t;
    _sizeKB = s;
    _ways = w;
    _lineSize = ls;
    _sets = s * 1024 / (w * ls);
    _shared = l >= 3;
    _sharedByCores = l >= 3 ? 0 : 1;
  }
  return self;
}
- (instancetype)init {
  return [self initWithLevel:1 type:@"unified" sizeKB:32 ways:8 lineSize:64];
}
@end

@implementation CPUCoreInfo
- (instancetype)init {
  self = [super init];
  if (self) {
    _coreID = 0;
    _type = @"P-core";
    _baseFreqMHz = 0;
    _boostFreqMHz = 0;
    _threads = 2;
    _caches = @[];
  }
  return self;
}
@end

@implementation CPUModelDefinition
- (instancetype)init {
  self = [super init];
  if (self) {
    _name = @"";
    _codename = @"";
    _vendor = CPUVendorUnknown;
    _architecture = CPUArchUnknown;
    _microarchitecture = (CPUMicroarch)0;
    _year = 0;
    _processNode = 0;
    _totalCores = 0;
    _performanceCores = 0;
    _efficiencyCores = 0;
    _totalThreads = 0;
    _baseFreqMHz = 0;
    _boostFreqMHz = 0;
    _l1CacheKB = 0;
    _l2CacheMB = 0;
    _l3CacheMB = 0;
    _tdpWatts = 0;
    _features = 0;
    _socket = @"";
    _segment = @"desktop";
    _cores = @[];
    _additionalInfo = @{};
  }
  return self;
}
@end

// Helper macro
#define CPU_DEF(n, cn, v, a, ma, y, pn, tc, pc, ec, tt, bf, bof, l1, l2, l3,   \
                tdp, f, so, seg)                                               \
  ({                                                                           \
    CPUModelDefinition *c = [[CPUModelDefinition alloc] init];                 \
    c.name = n;                                                                \
    c.codename = cn;                                                           \
    c.vendor = v;                                                              \
    c.architecture = a;                                                        \
    c.microarchitecture = ma;                                                  \
    c.year = y;                                                                \
    c.processNode = pn;                                                        \
    c.totalCores = tc;                                                         \
    c.performanceCores = pc;                                                   \
    c.efficiencyCores = ec;                                                    \
    c.totalThreads = tt;                                                       \
    c.baseFreqMHz = bf;                                                        \
    c.boostFreqMHz = bof;                                                      \
    c.l1CacheKB = l1;                                                          \
    c.l2CacheMB = l2;                                                          \
    c.l3CacheMB = l3;                                                          \
    c.tdpWatts = tdp;                                                          \
    c.features = f;                                                            \
    c.socket = so;                                                             \
    c.segment = seg;                                                           \
    c;                                                                         \
  })

#define INTEL_FEAT_BASE                                                        \
  (CPUFeatureFPU | CPUFeatureMMX | CPUFeatureSSE | CPUFeatureSSE2 |            \
   CPUFeatureSSE3 | CPUFeatureSSSE3 | CPUFeatureSSE4_1 | CPUFeatureSSE4_2 |    \
   CPUFeatureAES | CPUFeatureSHA)
#define INTEL_AVX (INTEL_FEAT_BASE | CPUFeatureAVX | CPUFeatureAVX2)
#define INTEL_AVX512                                                           \
  (INTEL_AVX | CPUFeatureAVX512F | CPUFeatureAVX512BW | CPUFeatureAVX512VL)
#define AMD_ZEN_BASE                                                           \
  (INTEL_FEAT_BASE | CPUFeatureAVX | CPUFeatureAVX2 | CPUFeatureAMD_V |        \
   CPUFeatureSEV)
#define ARM_BASE                                                               \
  (CPUFeatureFPU | CPUFeatureNEON | CPUFeatureAES | CPUFeatureSHA |            \
   CPUFeatureCRC32 | CPUFeatureATOMICS)
#define APPLE_M_BASE                                                           \
  (ARM_BASE | CPUFeatureSHA2 | CPUFeatureSHA3 | CPUFeatureBF16 |               \
   CPUFeatureDOTPROD | CPUFeaturePAuth | CPUFeatureBTI | CPUFeatureMTE)

@interface CPUArchitectureManager ()
@property(nonatomic, strong) NSMutableArray<CPUModelDefinition *> *cpuDatabase;
@end

@implementation CPUArchitectureManager

+ (instancetype)sharedInstance {
  static CPUArchitectureManager *inst = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    inst = [[self alloc] init];
  });
  return inst;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _cpuDatabase = [NSMutableArray array];
    [self buildDatabase];
  }
  return self;
}

- (void)buildDatabase {
  // ========== INTEL DESKTOP ==========
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Core i9-14900K", @"Raptor Lake-S",
                        CPUVendorIntel, CPUArchX86_64,
                        CPUMicroarchIntel_RaptorLake, 2023, 10, 24, 8, 16, 32,
                        3200, 6000, 80, 2, 36, 253, INTEL_AVX | CPUFeatureVT_x,
                        @"LGA1700", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Core i7-14700K", @"Raptor Lake-S",
                        CPUVendorIntel, CPUArchX86_64,
                        CPUMicroarchIntel_RaptorLake, 2023, 10, 20, 8, 12, 28,
                        3400, 5600, 80, 2, 33, 253, INTEL_AVX | CPUFeatureVT_x,
                        @"LGA1700", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Core i5-14600K", @"Raptor Lake-S",
                        CPUVendorIntel, CPUArchX86_64,
                        CPUMicroarchIntel_RaptorLake, 2023, 10, 14, 6, 8, 20,
                        3500, 5300, 80, 2, 24, 181, INTEL_AVX | CPUFeatureVT_x,
                        @"LGA1700", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Core Ultra 9 285K", @"Arrow Lake-S",
                        CPUVendorIntel, CPUArchX86_64,
                        CPUMicroarchIntel_ArrowLake, 2024, 3, 24, 8, 16, 24,
                        3700, 5700, 80, 2, 36, 125, INTEL_AVX | CPUFeatureVT_x,
                        @"LGA1851", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Core Ultra 7 265K", @"Arrow Lake-S",
                        CPUVendorIntel, CPUArchX86_64,
                        CPUMicroarchIntel_ArrowLake, 2024, 3, 20, 8, 12, 20,
                        3900, 5500, 80, 2, 30, 125, INTEL_AVX | CPUFeatureVT_x,
                        @"LGA1851", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Core i9-13900K", @"Raptor Lake", CPUVendorIntel,
                        CPUArchX86_64, CPUMicroarchIntel_RaptorLake, 2022, 10,
                        24, 8, 16, 32, 3000, 5800, 80, 2, 36, 253,
                        INTEL_AVX | CPUFeatureVT_x, @"LGA1700", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Core i9-12900K", @"Alder Lake", CPUVendorIntel,
                        CPUArchX86_64, CPUMicroarchIntel_AlderLake, 2021, 10,
                        16, 8, 8, 24, 3200, 5200, 80, 2, 30, 241,
                        INTEL_AVX | CPUFeatureVT_x, @"LGA1700", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Core i9-11900K", @"Rocket Lake", CPUVendorIntel,
                        CPUArchX86_64, CPUMicroarchIntel_Skylake, 2021, 14, 8,
                        8, 0, 16, 3500, 5300, 80, 2, 16, 125,
                        INTEL_AVX512 | CPUFeatureVT_x, @"LGA1200", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Core i9-10900K", @"Comet Lake", CPUVendorIntel,
                        CPUArchX86_64, CPUMicroarchIntel_CometLake, 2020, 14,
                        10, 10, 0, 20, 3700, 5300, 64, 2, 20, 125,
                        INTEL_AVX | CPUFeatureVT_x, @"LGA1200", @"desktop")];

  // ========== INTEL MOBILE ==========
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Core Ultra 9 288V", @"Lunar Lake",
                        CPUVendorIntel, CPUArchX86_64,
                        CPUMicroarchIntel_LunarLake, 2024, 3, 8, 4, 4, 8, 2200,
                        5100, 64, 2, 12, 30, INTEL_AVX | CPUFeatureVT_x, @"BGA",
                        @"mobile")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Core Ultra 7 155H", @"Meteor Lake-H",
                        CPUVendorIntel, CPUArchX86_64,
                        CPUMicroarchIntel_MeteorLake, 2024, 4, 16, 6, 8, 22,
                        3800, 4800, 64, 2, 24, 45, INTEL_AVX | CPUFeatureVT_x,
                        @"BGA", @"mobile")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Core i9-13980HX", @"Raptor Lake-HX",
                        CPUVendorIntel, CPUArchX86_64,
                        CPUMicroarchIntel_RaptorLake, 2023, 10, 24, 8, 16, 32,
                        2200, 5600, 80, 2, 36, 157, INTEL_AVX | CPUFeatureVT_x,
                        @"BGA", @"mobile")];

  // ========== INTEL SERVER ==========
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Xeon w9-3595X", @"Sapphire Rapids",
                        CPUVendorIntel, CPUArchX86_64,
                        CPUMicroarchIntel_SapphireRapids, 2024, 10, 56, 56, 0,
                        112, 2000, 4800, 80, 2, 105, 350,
                        INTEL_AVX512 | CPUFeatureVT_x | CPUFeatureAMX_TILE |
                            CPUFeatureAMX_BF16 | CPUFeatureTDX | CPUFeatureSGX,
                        @"LGA4677", @"server")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Xeon Platinum 8592+", @"Emerald Rapids",
                        CPUVendorIntel, CPUArchX86_64,
                        CPUMicroarchIntel_EmeraldRapids, 2024, 10, 64, 64, 0,
                        128, 1900, 3900, 80, 2, 320, 350,
                        INTEL_AVX512 | CPUFeatureVT_x | CPUFeatureAMX_TILE |
                            CPUFeatureTDX,
                        @"LGA4677", @"server")];
  [_cpuDatabase addObject:CPU_DEF(@"Intel Xeon 6980P", @"Granite Rapids-AP",
                                  CPUVendorIntel, CPUArchX86_64,
                                  CPUMicroarchIntel_GraniteRapids, 2024, 3, 128,
                                  128, 0, 256, 2000, 3900, 80, 2, 504, 500,
                                  INTEL_AVX512 | CPUFeatureVT_x |
                                      CPUFeatureAMX_TILE | CPUFeatureTDX,
                                  @"LGA4710", @"server")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Intel Xeon 6780E", @"Sierra Forest", CPUVendorIntel,
                        CPUArchX86_64, CPUMicroarchIntel_SierraForest, 2024, 3,
                        144, 0, 144, 144, 2200, 3600, 64, 2, 108, 330,
                        INTEL_AVX | CPUFeatureVT_x | CPUFeatureAVX_VNNI,
                        @"LGA4710", @"server")];

  // ========== AMD DESKTOP ==========
  [_cpuDatabase
      addObject:CPU_DEF(@"AMD Ryzen 9 9950X", @"Granite Ridge", CPUVendorAMD,
                        CPUArchX86_64, CPUMicroarchAMD_Zen5, 2024, 4, 16, 16, 0,
                        32, 4300, 5700, 64, 1, 64, 170,
                        AMD_ZEN_BASE | CPUFeatureAVX512F, @"AM5", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"AMD Ryzen 9 9900X", @"Granite Ridge", CPUVendorAMD,
                        CPUArchX86_64, CPUMicroarchAMD_Zen5, 2024, 4, 12, 12, 0,
                        24, 4400, 5600, 64, 1, 64, 120,
                        AMD_ZEN_BASE | CPUFeatureAVX512F, @"AM5", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"AMD Ryzen 7 9700X", @"Granite Ridge", CPUVendorAMD,
                        CPUArchX86_64, CPUMicroarchAMD_Zen5, 2024, 4, 8, 8, 0,
                        16, 3800, 5500, 64, 1, 32, 65,
                        AMD_ZEN_BASE | CPUFeatureAVX512F, @"AM5", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"AMD Ryzen 9 7950X", @"Raphael", CPUVendorAMD,
                        CPUArchX86_64, CPUMicroarchAMD_Zen4, 2022, 5, 16, 16, 0,
                        32, 4500, 5700, 64, 1, 64, 170,
                        AMD_ZEN_BASE | CPUFeatureAVX512F, @"AM5", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"AMD Ryzen 9 7900X", @"Raphael", CPUVendorAMD,
                        CPUArchX86_64, CPUMicroarchAMD_Zen4, 2022, 5, 12, 12, 0,
                        24, 4700, 5600, 64, 1, 64, 170,
                        AMD_ZEN_BASE | CPUFeatureAVX512F, @"AM5", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"AMD Ryzen 7 7800X3D", @"Raphael", CPUVendorAMD,
                        CPUArchX86_64, CPUMicroarchAMD_Zen4, 2023, 5, 8, 8, 0,
                        16, 4200, 5000, 64, 1, 96, 120,
                        AMD_ZEN_BASE | CPUFeatureAVX512F, @"AM5", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"AMD Ryzen 9 5950X", @"Vermeer", CPUVendorAMD,
                        CPUArchX86_64, CPUMicroarchAMD_Zen3, 2020, 7, 16, 16, 0,
                        32, 3400, 4900, 64, 1, 64, 105, AMD_ZEN_BASE, @"AM4",
                        @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"AMD Ryzen 9 5900X", @"Vermeer", CPUVendorAMD,
                        CPUArchX86_64, CPUMicroarchAMD_Zen3, 2020, 7, 12, 12, 0,
                        24, 3700, 4800, 64, 1, 64, 105, AMD_ZEN_BASE, @"AM4",
                        @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"AMD Ryzen 9 3950X", @"Matisse", CPUVendorAMD,
                        CPUArchX86_64, CPUMicroarchAMD_Zen2, 2019, 7, 16, 16, 0,
                        32, 3500, 4700, 64, 1, 64, 105, AMD_ZEN_BASE, @"AM4",
                        @"desktop")];

  // ========== AMD SERVER ==========
  [_cpuDatabase addObject:CPU_DEF(@"AMD EPYC 9754", @"Bergamo", CPUVendorAMD,
                                  CPUArchX86_64, CPUMicroarchAMD_EPYC_Bergamo,
                                  2023, 5, 128, 128, 0, 256, 2250, 3100, 64, 1,
                                  256, 360, AMD_ZEN_BASE, @"SP5", @"server")];
  [_cpuDatabase
      addObject:CPU_DEF(@"AMD EPYC 9654", @"Genoa", CPUVendorAMD, CPUArchX86_64,
                        CPUMicroarchAMD_EPYC_Genoa, 2022, 5, 96, 96, 0, 192,
                        2400, 3700, 64, 1, 384, 360,
                        AMD_ZEN_BASE | CPUFeatureAVX512F, @"SP5", @"server")];
  [_cpuDatabase
      addObject:CPU_DEF(@"AMD EPYC 9005 Turin", @"Turin", CPUVendorAMD,
                        CPUArchX86_64, CPUMicroarchAMD_EPYC_Turin, 2024, 4, 192,
                        192, 0, 384, 2000, 3500, 64, 1, 512, 500,
                        AMD_ZEN_BASE | CPUFeatureAVX512F, @"SP5", @"server")];
  [_cpuDatabase addObject:CPU_DEF(@"AMD EPYC 7763", @"Milan", CPUVendorAMD,
                                  CPUArchX86_64, CPUMicroarchAMD_EPYC_Milan,
                                  2021, 7, 64, 64, 0, 128, 2450, 3500, 64, 1,
                                  256, 280, AMD_ZEN_BASE, @"SP3", @"server")];

  // ========== AMD MOBILE ==========
  [_cpuDatabase
      addObject:CPU_DEF(@"AMD Ryzen AI 9 HX 370", @"Strix Point", CPUVendorAMD,
                        CPUArchX86_64, CPUMicroarchAMD_Zen5, 2024, 4, 12, 4, 8,
                        24, 2000, 5100, 64, 1, 24, 28,
                        AMD_ZEN_BASE | CPUFeatureAVX512F, @"FP8", @"mobile")];
  [_cpuDatabase
      addObject:CPU_DEF(@"AMD Ryzen 9 7945HX", @"Dragon Range", CPUVendorAMD,
                        CPUArchX86_64, CPUMicroarchAMD_Zen4, 2023, 5, 16, 16, 0,
                        32, 2500, 5400, 64, 1, 64, 55,
                        AMD_ZEN_BASE | CPUFeatureAVX512F, @"FL1", @"mobile")];

  // ========== APPLE SILICON ==========
  [_cpuDatabase
      addObject:CPU_DEF(@"Apple M4 Ultra", @"M4 Ultra", CPUVendorApple,
                        CPUArchARM64, CPUMicroarchApple_M4Ultra, 2025, 3, 32,
                        16, 16, 32, 0, 4400, 192, 2, 64, 0,
                        APPLE_M_BASE | CPUFeatureSVE2 | CPUFeatureSME2, @"SoC",
                        @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Apple M4 Max", @"M4 Max", CPUVendorApple,
                        CPUArchARM64, CPUMicroarchApple_M4Max, 2024, 3, 16, 12,
                        4, 16, 0, 4400, 192, 2, 48, 0,
                        APPLE_M_BASE | CPUFeatureSVE2 | CPUFeatureSME2, @"SoC",
                        @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Apple M4 Pro", @"M4 Pro", CPUVendorApple,
                        CPUArchARM64, CPUMicroarchApple_M4Pro, 2024, 3, 14, 10,
                        4, 14, 0, 4300, 192, 2, 24, 0,
                        APPLE_M_BASE | CPUFeatureSVE2 | CPUFeatureSME2, @"SoC",
                        @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Apple M4", @"M4", CPUVendorApple, CPUArchARM64,
                        CPUMicroarchApple_M4, 2024, 3, 10, 4, 6, 10, 0, 4400,
                        192, 2, 16, 0,
                        APPLE_M_BASE | CPUFeatureSVE2 | CPUFeatureSME2, @"SoC",
                        @"mobile")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Apple M3 Ultra", @"M3 Ultra", CPUVendorApple,
                        CPUArchARM64, CPUMicroarchApple_M3Ultra, 2024, 3, 32,
                        16, 16, 32, 0, 4100, 192, 2, 96, 0,
                        APPLE_M_BASE | CPUFeatureSVE2, @"SoC", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Apple M3 Max", @"M3 Max", CPUVendorApple,
                        CPUArchARM64, CPUMicroarchApple_M3Max, 2023, 3, 16, 12,
                        4, 16, 0, 4100, 192, 2, 48, 0,
                        APPLE_M_BASE | CPUFeatureSVE2, @"SoC", @"desktop")];
  [_cpuDatabase addObject:CPU_DEF(@"Apple M3 Pro", @"M3 Pro", CPUVendorApple,
                                  CPUArchARM64, CPUMicroarchApple_M3Pro, 2023,
                                  3, 12, 6, 6, 12, 0, 4100, 192, 2, 18, 0,
                                  APPLE_M_BASE, @"SoC", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Apple M3", @"M3", CPUVendorApple, CPUArchARM64,
                        CPUMicroarchApple_M3, 2023, 3, 8, 4, 4, 8, 0, 4100, 192,
                        2, 8, 0, APPLE_M_BASE, @"SoC", @"mobile")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Apple M2 Ultra", @"M2 Ultra", CPUVendorApple,
                        CPUArchARM64, CPUMicroarchApple_M2Ultra, 2023, 5, 24,
                        16, 8, 24, 0, 3500, 192, 2, 192, 0, APPLE_M_BASE,
                        @"SoC", @"desktop")];
  [_cpuDatabase addObject:CPU_DEF(@"Apple M2 Max", @"M2 Max", CPUVendorApple,
                                  CPUArchARM64, CPUMicroarchApple_M2Max, 2023,
                                  5, 12, 8, 4, 12, 0, 3500, 192, 2, 96, 0,
                                  APPLE_M_BASE, @"SoC", @"desktop")];
  [_cpuDatabase addObject:CPU_DEF(@"Apple M2 Pro", @"M2 Pro", CPUVendorApple,
                                  CPUArchARM64, CPUMicroarchApple_M2Pro, 2023,
                                  5, 12, 8, 4, 12, 0, 3500, 192, 2, 32, 0,
                                  APPLE_M_BASE, @"SoC", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Apple M2", @"M2", CPUVendorApple, CPUArchARM64,
                        CPUMicroarchApple_M2, 2022, 5, 8, 4, 4, 8, 0, 3500, 192,
                        2, 8, 0, APPLE_M_BASE, @"SoC", @"mobile")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Apple M1 Ultra", @"M1 Ultra", CPUVendorApple,
                        CPUArchARM64, CPUMicroarchApple_M1Ultra, 2022, 5, 20,
                        16, 4, 20, 0, 3200, 192, 2, 128, 0, APPLE_M_BASE,
                        @"SoC", @"desktop")];
  [_cpuDatabase addObject:CPU_DEF(@"Apple M1 Max", @"M1 Max", CPUVendorApple,
                                  CPUArchARM64, CPUMicroarchApple_M1Max, 2021,
                                  5, 10, 8, 2, 10, 0, 3200, 192, 2, 64, 0,
                                  APPLE_M_BASE, @"SoC", @"desktop")];
  [_cpuDatabase addObject:CPU_DEF(@"Apple M1 Pro", @"M1 Pro", CPUVendorApple,
                                  CPUArchARM64, CPUMicroarchApple_M1Pro, 2021,
                                  5, 10, 8, 2, 10, 0, 3200, 192, 2, 32, 0,
                                  APPLE_M_BASE, @"SoC", @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Apple M1", @"M1", CPUVendorApple, CPUArchARM64,
                        CPUMicroarchApple_M1, 2020, 5, 8, 4, 4, 8, 0, 3200, 192,
                        2, 8, 0, APPLE_M_BASE, @"SoC", @"mobile")];
  [_cpuDatabase addObject:CPU_DEF(@"Apple A18 Pro", @"A18 Pro", CPUVendorApple,
                                  CPUArchARM64, CPUMicroarchApple_A18Pro, 2024,
                                  3, 6, 2, 4, 6, 0, 4050, 128, 2, 8, 0,
                                  APPLE_M_BASE, @"SoC", @"mobile")];
  [_cpuDatabase addObject:CPU_DEF(@"Apple A17 Pro", @"A17 Pro", CPUVendorApple,
                                  CPUArchARM64, CPUMicroarchApple_A17Pro, 2023,
                                  3, 6, 2, 4, 6, 0, 3780, 128, 2, 8, 0,
                                  APPLE_M_BASE, @"SoC", @"mobile")];
  [_cpuDatabase addObject:CPU_DEF(@"Apple A16 Bionic", @"A16", CPUVendorApple,
                                  CPUArchARM64, CPUMicroarchApple_A16, 2022, 4,
                                  6, 2, 4, 6, 0, 3460, 128, 2, 8, 0,
                                  APPLE_M_BASE, @"SoC", @"mobile")];

  // ========== QUALCOMM ==========
  [_cpuDatabase
      addObject:CPU_DEF(@"Qualcomm Snapdragon X Elite X1E-84-100", @"Oryon",
                        CPUVendorQualcomm, CPUArchARM64,
                        CPUMicroarchQualcomm_Oryon, 2024, 4, 12, 12, 0, 12,
                        3400, 4200, 96, 2, 42, 80, ARM_BASE | CPUFeatureSVE2,
                        @"SoC", @"mobile")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Qualcomm Snapdragon X Plus X1P-64-100", @"Oryon",
                        CPUVendorQualcomm, CPUArchARM64,
                        CPUMicroarchQualcomm_Oryon, 2024, 4, 10, 10, 0, 10,
                        3200, 3400, 96, 2, 42, 45, ARM_BASE | CPUFeatureSVE2,
                        @"SoC", @"mobile")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Qualcomm Snapdragon 8 Gen 3", @"SM8650",
                        CPUVendorQualcomm, CPUArchARM64,
                        CPUMicroarchQualcomm_Kryo7xx, 2023, 4, 8, 1, 7, 8, 3300,
                        3300, 96, 2, 12, 0, ARM_BASE, @"SoC", @"mobile")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Qualcomm Snapdragon 8 Gen 2", @"SM8550",
                        CPUVendorQualcomm, CPUArchARM64,
                        CPUMicroarchQualcomm_Kryo7xx, 2022, 4, 8, 1, 7, 8, 3200,
                        3200, 96, 2, 8, 0, ARM_BASE, @"SoC", @"mobile")];

  // ========== SAMSUNG ==========
  [_cpuDatabase
      addObject:CPU_DEF(@"Samsung Exynos 2400", @"Exynos 2400",
                        CPUVendorSamsung, CPUArchARM64,
                        CPUMicroarchARM_CortexX4, 2024, 4, 10, 1, 9, 10, 3200,
                        3200, 64, 1, 8, 0, ARM_BASE, @"SoC", @"mobile")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Samsung Exynos 2200", @"Exynos 2200",
                        CPUVendorSamsung, CPUArchARM64,
                        CPUMicroarchARM_CortexX2, 2022, 4, 8, 1, 7, 8, 2800,
                        2800, 64, 1, 4, 0, ARM_BASE, @"SoC", @"mobile")];

  // ========== MEDIATEK ==========
  [_cpuDatabase
      addObject:CPU_DEF(@"MediaTek Dimensity 9300", @"MT6989",
                        CPUVendorMediaTek, CPUArchARM64,
                        CPUMicroarchARM_CortexX4, 2023, 4, 8, 4, 4, 8, 3250,
                        3250, 64, 1, 12, 0, ARM_BASE, @"SoC", @"mobile")];
  [_cpuDatabase
      addObject:CPU_DEF(@"MediaTek Dimensity 9200", @"MT6985",
                        CPUVendorMediaTek, CPUArchARM64,
                        CPUMicroarchARM_CortexX3, 2022, 4, 8, 1, 7, 8, 3050,
                        3050, 64, 1, 8, 0, ARM_BASE, @"SoC", @"mobile")];

  // ========== ARM SERVER ==========
  [_cpuDatabase addObject:CPU_DEF(@"Ampere AmpereOne A192-32X", @"AmpereOne",
                                  CPUVendorAmpere, CPUArchARM64,
                                  CPUMicroarchAmpere_AmpereOne, 2023, 5, 192,
                                  192, 0, 192, 3000, 3000, 64, 2, 96, 350,
                                  ARM_BASE | CPUFeatureSVE, @"LGA", @"server")];
  [_cpuDatabase addObject:CPU_DEF(@"Ampere Altra Max M128-30", @"Altra Max",
                                  CPUVendorAmpere, CPUArchARM64,
                                  CPUMicroarchAmpere_AltraMax, 2022, 7, 128,
                                  128, 0, 128, 3000, 3000, 64, 2, 128, 250,
                                  ARM_BASE, @"LGA", @"server")];
  [_cpuDatabase
      addObject:CPU_DEF(@"AWS Graviton4", @"Graviton4", CPUVendorARM,
                        CPUArchARM64, CPUMicroarchARM_NeoverseV2, 2024, 5, 96,
                        96, 0, 96, 2800, 2800, 64, 2, 96, 0,
                        ARM_BASE | CPUFeatureSVE2, @"SoC", @"server")];
  [_cpuDatabase
      addObject:CPU_DEF(@"AWS Graviton3", @"Graviton3", CPUVendorARM,
                        CPUArchARM64, CPUMicroarchARM_NeoverseV1, 2022, 5, 64,
                        64, 0, 64, 2600, 2600, 64, 2, 64, 0,
                        ARM_BASE | CPUFeatureSVE, @"SoC", @"server")];
  [_cpuDatabase addObject:CPU_DEF(@"Fujitsu A64FX", @"A64FX", CPUVendorFujitsu,
                                  CPUArchARM64, CPUMicroarchFujitsu_A64FX, 2020,
                                  7, 48, 48, 0, 48, 2200, 2200, 64, 2, 32, 0,
                                  ARM_BASE | CPUFeatureSVE, @"SoC", @"server")];

  // ========== IBM ==========
  [_cpuDatabase
      addObject:CPU_DEF(@"IBM POWER10", @"Power10", CPUVendorIBM,
                        CPUArchPowerPC64, CPUMicroarchIBM_Power10, 2021, 7, 15,
                        15, 0, 120, 3500, 4000, 64, 2, 120, 300,
                        CPUFeatureFPU | CPUFeatureAltiVec | CPUFeatureVSX,
                        @"Custom", @"server")];
  [_cpuDatabase
      addObject:CPU_DEF(@"IBM POWER9", @"Power9", CPUVendorIBM,
                        CPUArchPowerPC64, CPUMicroarchIBM_Power9, 2017, 14, 24,
                        24, 0, 96, 3000, 3800, 64, 2, 120, 190,
                        CPUFeatureFPU | CPUFeatureAltiVec | CPUFeatureVSX,
                        @"Custom", @"server")];
  [_cpuDatabase addObject:CPU_DEF(@"IBM z16", @"Telum", CPUVendorIBM,
                                  CPUArchS390X, CPUMicroarchIBM_Z16, 2022, 7, 8,
                                  8, 0, 16, 5200, 5200, 128, 2, 256, 0,
                                  CPUFeatureFPU | CPUFeatureVirtualization,
                                  @"Custom", @"server")];

  // ========== RISC-V ==========
  [_cpuDatabase
      addObject:CPU_DEF(@"SiFive P670", @"P670", CPUVendorSiFive,
                        CPUArchRISCV64, CPUMicroarchRISCV_P670, 2023, 5, 4, 4,
                        0, 4, 2000, 2000, 32, 1, 4, 0,
                        CPUFeatureFPU | CPUFeatureRISCV_M | CPUFeatureRISCV_A |
                            CPUFeatureRISCV_F | CPUFeatureRISCV_D |
                            CPUFeatureRISCV_C | CPUFeatureRISCV_V,
                        @"SoC", @"embedded")];
  [_cpuDatabase addObject:CPU_DEF(@"SiFive P550", @"P550", CPUVendorSiFive,
                                  CPUArchRISCV64, CPUMicroarchRISCV_P550, 2022,
                                  5, 4, 4, 0, 4, 1800, 1800, 32, 1, 2, 0,
                                  CPUFeatureFPU | CPUFeatureRISCV_M |
                                      CPUFeatureRISCV_A | CPUFeatureRISCV_F |
                                      CPUFeatureRISCV_D | CPUFeatureRISCV_C,
                                  @"SoC", @"embedded")];
  [_cpuDatabase addObject:CPU_DEF(@"SiFive X280", @"X280", CPUVendorSiFive,
                                  CPUArchRISCV64, CPUMicroarchRISCV_X280, 2021,
                                  7, 1, 1, 0, 1, 1000, 1000, 32, 0, 0, 0,
                                  CPUFeatureFPU | CPUFeatureRISCV_M |
                                      CPUFeatureRISCV_A | CPUFeatureRISCV_F |
                                      CPUFeatureRISCV_D | CPUFeatureRISCV_V,
                                  @"SoC", @"embedded")];
  [_cpuDatabase addObject:CPU_DEF(@"T-Head C920", @"C920", CPUVendorTHead,
                                  CPUArchRISCV64, CPUMicroarchRISCV_C920, 2023,
                                  5, 8, 8, 0, 8, 2000, 2000, 64, 1, 8, 0,
                                  CPUFeatureFPU | CPUFeatureRISCV_M |
                                      CPUFeatureRISCV_A | CPUFeatureRISCV_F |
                                      CPUFeatureRISCV_D | CPUFeatureRISCV_V,
                                  @"SoC", @"embedded")];

  // ========== LOONGSON ==========
  [_cpuDatabase
      addObject:CPU_DEF(@"Loongson 3A6000", @"LA664", CPUVendorLoongson,
                        CPUArchLoongArch, CPUMicroarchLoongson_3A6000, 2023, 12,
                        4, 4, 0, 8, 2500, 2500, 64, 1, 16, 0,
                        CPUFeatureFPU | CPUFeatureVirtualization, @"LGA",
                        @"desktop")];
  [_cpuDatabase
      addObject:CPU_DEF(@"Loongson 3A5000", @"LA464", CPUVendorLoongson,
                        CPUArchLoongArch, CPUMicroarchLoongson_3A5000, 2021, 14,
                        4, 4, 0, 4, 2300, 2500, 64, 1, 16, 0, CPUFeatureFPU,
                        @"LGA", @"desktop")];
}

// ========== DETECTION ==========

- (CPUModelDefinition *)detectCurrentCPU {
  NSString *brand = [self currentCPUBrand];
  for (CPUModelDefinition *cpu in _cpuDatabase) {
    if ([brand containsString:cpu.codename] || [brand containsString:cpu.name])
      return cpu;
  }
  // Build from system info
  CPUModelDefinition *detected = [[CPUModelDefinition alloc] init];
  detected.name = brand;
  detected.totalCores = [[NSProcessInfo processInfo] processorCount];
  detected.totalThreads = [[NSProcessInfo processInfo] activeProcessorCount];
#if __arm64__
  detected.architecture = CPUArchARM64;
  detected.vendor = CPUVendorApple;
#elif __x86_64__
  detected.architecture = CPUArchX86_64;
#endif
  return detected;
}

- (CPUArchType)currentArchitecture {
#if __arm64__
  return CPUArchARM64;
#elif __x86_64__
  return CPUArchX86_64;
#else
  return CPUArchUnknown;
#endif
}

- (CPUVendor)currentVendor {
#if __arm64__
  return CPUVendorApple;
#else
  NSString *brand = [self currentCPUBrand];
  if ([brand containsString:@"Intel"])
    return CPUVendorIntel;
  if ([brand containsString:@"AMD"])
    return CPUVendorAMD;
  return CPUVendorUnknown;
#endif
}

- (CPUFeatureFlags)currentFeatures {
  CPUFeatureFlags flags = CPUFeatureFPU;
#if __arm64__
  flags |= CPUFeatureNEON | CPUFeatureAES | CPUFeatureSHA | CPUFeatureCRC32 |
           CPUFeatureATOMICS;
#elif __x86_64__
  flags |= CPUFeatureSSE | CPUFeatureSSE2 | CPUFeatureSSE3 | CPUFeatureSSSE3 |
           CPUFeatureSSE4_1 | CPUFeatureSSE4_2;
#endif
  return flags;
}

- (NSString *)currentCPUBrand {
  char buf[256];
  size_t len = sizeof(buf);
  if (sysctlbyname("machdep.cpu.brand_string", buf, &len, NULL, 0) == 0)
    return @(buf);
  return @"Unknown CPU";
}

// ========== DATABASE QUERIES ==========

- (NSArray<CPUModelDefinition *> *)allCPUs {
  return [_cpuDatabase copy];
}

- (NSArray<CPUModelDefinition *> *)cpusForVendor:(CPUVendor)vendor {
  NSMutableArray *r = [NSMutableArray array];
  for (CPUModelDefinition *c in _cpuDatabase)
    if (c.vendor == vendor)
      [r addObject:c];
  return r;
}
- (NSArray<CPUModelDefinition *> *)cpusForArchitecture:(CPUArchType)arch {
  NSMutableArray *r = [NSMutableArray array];
  for (CPUModelDefinition *c in _cpuDatabase)
    if (c.architecture == arch)
      [r addObject:c];
  return r;
}
- (NSArray<CPUModelDefinition *> *)cpusForMicroarch:(CPUMicroarch)microarch {
  NSMutableArray *r = [NSMutableArray array];
  for (CPUModelDefinition *c in _cpuDatabase)
    if (c.microarchitecture == microarch)
      [r addObject:c];
  return r;
}
- (NSArray<CPUModelDefinition *> *)cpusForSegment:(NSString *)segment {
  NSMutableArray *r = [NSMutableArray array];
  for (CPUModelDefinition *c in _cpuDatabase)
    if ([c.segment isEqualToString:segment])
      [r addObject:c];
  return r;
}
- (NSArray<CPUModelDefinition *> *)cpusWithFeature:(CPUFeatureFlags)feature {
  NSMutableArray *r = [NSMutableArray array];
  for (CPUModelDefinition *c in _cpuDatabase)
    if (c.features & feature)
      [r addObject:c];
  return r;
}
- (CPUModelDefinition *)cpuByName:(NSString *)name {
  for (CPUModelDefinition *c in _cpuDatabase)
    if ([c.name isEqualToString:name])
      return c;
  return nil;
}

- (BOOL)supportsFeature:(CPUFeatureFlags)feature {
  return ([self currentFeatures] & feature) == feature;
}

- (NSArray<NSString *> *)featureList {
  return [self featureListForFlags:[self currentFeatures]];
}

- (NSArray<NSString *> *)featureListForFlags:(CPUFeatureFlags)flags {
  NSMutableArray *list = [NSMutableArray array];
  struct {
    CPUFeatureFlags f;
    NSString *n;
  } map[] = {{CPUFeatureFPU, @"FPU"},
             {CPUFeatureMMX, @"MMX"},
             {CPUFeatureSSE, @"SSE"},
             {CPUFeatureSSE2, @"SSE2"},
             {CPUFeatureSSE3, @"SSE3"},
             {CPUFeatureSSSE3, @"SSSE3"},
             {CPUFeatureSSE4_1, @"SSE4.1"},
             {CPUFeatureSSE4_2, @"SSE4.2"},
             {CPUFeatureAVX, @"AVX"},
             {CPUFeatureAVX2, @"AVX2"},
             {CPUFeatureAVX512F, @"AVX-512"},
             {CPUFeatureAMX_TILE, @"AMX"},
             {CPUFeatureNEON, @"NEON"},
             {CPUFeatureSVE, @"SVE"},
             {CPUFeatureSVE2, @"SVE2"},
             {CPUFeatureSME, @"SME"},
             {CPUFeatureSME2, @"SME2"},
             {CPUFeatureAES, @"AES"},
             {CPUFeatureSHA, @"SHA"},
             {CPUFeatureVT_x, @"VT-x"},
             {CPUFeatureAMD_V, @"AMD-V"},
             {CPUFeatureSGX, @"SGX"},
             {CPUFeatureTDX, @"TDX"},
             {CPUFeatureSEV, @"SEV"},
             {CPUFeatureRISCV_V, @"RISC-V Vector"},
             {CPUFeatureAltiVec, @"AltiVec"},
             {CPUFeatureVSX, @"VSX"},
             {CPUFeatureMTE, @"MTE"},
             {CPUFeaturePAuth, @"PAuth"},
             {CPUFeatureBTI, @"BTI"}};
  for (size_t i = 0; i < sizeof(map) / sizeof(map[0]); i++) {
    if (flags & map[i].f)
      [list addObject:map[i].n];
  }
  return list;
}

// ========== UTILITY ==========

- (NSString *)vendorName:(CPUVendor)vendor {
  switch (vendor) {
  case CPUVendorIntel:
    return @"Intel";
  case CPUVendorAMD:
    return @"AMD";
  case CPUVendorARM:
    return @"ARM";
  case CPUVendorApple:
    return @"Apple";
  case CPUVendorQualcomm:
    return @"Qualcomm";
  case CPUVendorSamsung:
    return @"Samsung";
  case CPUVendorMediaTek:
    return @"MediaTek";
  case CPUVendorNVIDIA:
    return @"NVIDIA";
  case CPUVendorAmpere:
    return @"Ampere";
  case CPUVendorIBM:
    return @"IBM";
  case CPUVendorFujitsu:
    return @"Fujitsu";
  case CPUVendorSiFive:
    return @"SiFive";
  case CPUVendorTHead:
    return @"T-Head";
  case CPUVendorLoongson:
    return @"Loongson";
  case CPUVendorHiSilicon:
    return @"HiSilicon";
  case CPUVendorMarvell:
    return @"Marvell";
  default:
    return @"Unknown";
  }
}

- (NSString *)architectureName:(CPUArchType)arch {
  switch (arch) {
  case CPUArchX86:
    return @"x86";
  case CPUArchX86_64:
    return @"x86_64";
  case CPUArchARM:
    return @"ARM";
  case CPUArchARM64:
    return @"ARM64 (AArch64)";
  case CPUArchRISCV64:
    return @"RISC-V 64";
  case CPUArchRISCV32:
    return @"RISC-V 32";
  case CPUArchMIPS:
    return @"MIPS";
  case CPUArchMIPS64:
    return @"MIPS64";
  case CPUArchPowerPC:
    return @"PowerPC";
  case CPUArchPowerPC64:
    return @"POWER";
  case CPUArchSPARC64:
    return @"SPARC";
  case CPUArchIA64:
    return @"IA-64 (Itanium)";
  case CPUArchS390X:
    return @"s390x (IBM Z)";
  case CPUArchLoongArch:
    return @"LoongArch";
  default:
    return @"Unknown";
  }
}

- (NSString *)microarchName:(CPUMicroarch)ma {
  // Key ones
  NSDictionary *names = @{
    @(CPUMicroarchIntel_RaptorLake) : @"Raptor Lake",
    @(CPUMicroarchIntel_ArrowLake) : @"Arrow Lake",
    @(CPUMicroarchIntel_LunarLake) : @"Lunar Lake",
    @(CPUMicroarchIntel_MeteorLake) : @"Meteor Lake",
    @(CPUMicroarchIntel_AlderLake) : @"Alder Lake",
    @(CPUMicroarchIntel_SapphireRapids) : @"Sapphire Rapids",
    @(CPUMicroarchIntel_GraniteRapids) : @"Granite Rapids",
    @(CPUMicroarchIntel_SierraForest) : @"Sierra Forest",
    @(CPUMicroarchAMD_Zen5) : @"Zen 5",
    @(CPUMicroarchAMD_Zen4) : @"Zen 4",
    @(CPUMicroarchAMD_Zen3) : @"Zen 3",
    @(CPUMicroarchAMD_Zen2) : @"Zen 2",
    @(CPUMicroarchAMD_EPYC_Turin) : @"EPYC Turin",
    @(CPUMicroarchApple_M4) : @"Apple M4",
    @(CPUMicroarchApple_M3) : @"Apple M3",
    @(CPUMicroarchApple_M2) : @"Apple M2",
    @(CPUMicroarchApple_M1) : @"Apple M1",
    @(CPUMicroarchQualcomm_Oryon) : @"Qualcomm Oryon",
    @(CPUMicroarchAmpere_AmpereOne) : @"AmpereOne",
    @(CPUMicroarchIBM_Power10) : @"POWER10",
    @(CPUMicroarchIBM_Z16) : @"z16 Telum",
    @(CPUMicroarchRISCV_P670) : @"SiFive P670",
    @(CPUMicroarchRISCV_C920) : @"T-Head C920",
    @(CPUMicroarchLoongson_3A6000) : @"Loongson LA664"
  };
  return names[@(ma)] ?: @"Unknown";
}

- (NSDictionary *)systemCPUInfo {
  return @{
    @"brand" : [self currentCPUBrand],
    @"architecture" : [self architectureName:[self currentArchitecture]],
    @"vendor" : [self vendorName:[self currentVendor]],
    @"physical_cores" : @([[NSProcessInfo processInfo] processorCount]),
    @"active_cores" : @([[NSProcessInfo processInfo] activeProcessorCount]),
    @"features" : [self featureList],
    @"physical_memory_gb" :
        @([[NSProcessInfo processInfo] physicalMemory] / (1024 * 1024 * 1024))
  };
}

- (NSUInteger)cpuDatabaseCount {
  return _cpuDatabase.count;
}

@end
