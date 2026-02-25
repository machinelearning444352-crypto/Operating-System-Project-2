#pragma once
#import <Cocoa/Cocoa.h>

// ============================================================================
// CPU ARCHITECTURE MANAGER — Comprehensive CPU Database
// ============================================================================

// CPU Architecture Types
typedef NS_ENUM(NSInteger, CPUArchType) {
  CPUArchUnknown = 0,
  CPUArchX86,
  CPUArchX86_64,
  CPUArchARM,
  CPUArchARM64,
  CPUArchRISCV32,
  CPUArchRISCV64,
  CPUArchMIPS,
  CPUArchMIPS64,
  CPUArchPowerPC,
  CPUArchPowerPC64,
  CPUArchSPARC,
  CPUArchSPARC64,
  CPUArchIA64,
  CPUArchS390X,
  CPUArchPA_RISC,
  CPUArchAlpha,
  CPUArchM68K,
  CPUArchSuperH,
  CPUArchARC,
  CPUArchXtensa,
  CPUArchLoongArch,
  CPUArchOpenRISC,
  CPUArchMicroBlaze,
  CPUArchNios2
};

// CPU Vendors
typedef NS_ENUM(NSInteger, CPUVendor) {
  CPUVendorUnknown = 0,
  CPUVendorIntel,
  CPUVendorAMD,
  CPUVendorARM,
  CPUVendorApple,
  CPUVendorQualcomm,
  CPUVendorSamsung,
  CPUVendorMediaTek,
  CPUVendorHiSilicon,
  CPUVendorBroadcom,
  CPUVendorNVIDIA,
  CPUVendorMarvell,
  CPUVendorCavium,
  CPUVendorAmpere,
  CPUVendorFujitsu,
  CPUVendorIBM,
  CPUVendorOracle,
  CPUVendorSiFive,
  CPUVendorTHead,
  CPUVendorVIA,
  CPUVendorCentaur,
  CPUVendorZhaoxin,
  CPUVendorHygon,
  CPUVendorMIPS_Tech,
  CPUVendorLoongson,
  CPUVendorElbrus,
  CPUVendorBaikal,
  CPUVendorRISC_V_Intl,
  CPUVendorAspeed,
  CPUVendorMicrochip
};

// CPU Microarchitecture Families
typedef NS_ENUM(NSInteger, CPUMicroarch) {
  // Intel
  CPUMicroarchIntel_P6 = 100,
  CPUMicroarchIntel_NetBurst,
  CPUMicroarchIntel_Core,
  CPUMicroarchIntel_Nehalem,
  CPUMicroarchIntel_SandyBridge,
  CPUMicroarchIntel_IvyBridge,
  CPUMicroarchIntel_Haswell,
  CPUMicroarchIntel_Broadwell,
  CPUMicroarchIntel_Skylake,
  CPUMicroarchIntel_KabyLake,
  CPUMicroarchIntel_CoffeeLake,
  CPUMicroarchIntel_CometLake,
  CPUMicroarchIntel_IceLake,
  CPUMicroarchIntel_TigerLake,
  CPUMicroarchIntel_AlderLake,
  CPUMicroarchIntel_RaptorLake,
  CPUMicroarchIntel_MeteorLake,
  CPUMicroarchIntel_ArrowLake,
  CPUMicroarchIntel_LunarLake,
  CPUMicroarchIntel_PantherLake,
  CPUMicroarchIntel_NovaLake,
  CPUMicroarchIntel_SapphireRapids,
  CPUMicroarchIntel_EmeraldRapids,
  CPUMicroarchIntel_GraniteRapids,
  CPUMicroarchIntel_SierraForest,
  CPUMicroarchIntel_ClearwaterForest,
  CPUMicroarchIntel_Atom_Bonnell,
  CPUMicroarchIntel_Atom_Silvermont,
  CPUMicroarchIntel_Atom_Goldmont,
  CPUMicroarchIntel_Atom_Tremont,
  CPUMicroarchIntel_Atom_Gracemont,
  CPUMicroarchIntel_Atom_Crestmont,
  CPUMicroarchIntel_Atom_Skymont,
  // AMD
  CPUMicroarchAMD_K8 = 200,
  CPUMicroarchAMD_K10,
  CPUMicroarchAMD_Bulldozer,
  CPUMicroarchAMD_Piledriver,
  CPUMicroarchAMD_Steamroller,
  CPUMicroarchAMD_Excavator,
  CPUMicroarchAMD_Zen1,
  CPUMicroarchAMD_Zen_Plus,
  CPUMicroarchAMD_Zen2,
  CPUMicroarchAMD_Zen3,
  CPUMicroarchAMD_Zen3_Plus,
  CPUMicroarchAMD_Zen4,
  CPUMicroarchAMD_Zen4c,
  CPUMicroarchAMD_Zen5,
  CPUMicroarchAMD_Zen5c,
  CPUMicroarchAMD_Zen6,
  CPUMicroarchAMD_EPYC_Rome,
  CPUMicroarchAMD_EPYC_Milan,
  CPUMicroarchAMD_EPYC_Genoa,
  CPUMicroarchAMD_EPYC_Bergamo,
  CPUMicroarchAMD_EPYC_Turin,
  // ARM
  CPUMicroarchARM_CortexA5 = 300,
  CPUMicroarchARM_CortexA7,
  CPUMicroarchARM_CortexA8,
  CPUMicroarchARM_CortexA9,
  CPUMicroarchARM_CortexA12,
  CPUMicroarchARM_CortexA15,
  CPUMicroarchARM_CortexA17,
  CPUMicroarchARM_CortexA32,
  CPUMicroarchARM_CortexA34,
  CPUMicroarchARM_CortexA35,
  CPUMicroarchARM_CortexA53,
  CPUMicroarchARM_CortexA55,
  CPUMicroarchARM_CortexA57,
  CPUMicroarchARM_CortexA65,
  CPUMicroarchARM_CortexA72,
  CPUMicroarchARM_CortexA73,
  CPUMicroarchARM_CortexA75,
  CPUMicroarchARM_CortexA76,
  CPUMicroarchARM_CortexA77,
  CPUMicroarchARM_CortexA78,
  CPUMicroarchARM_CortexA78C,
  CPUMicroarchARM_CortexA510,
  CPUMicroarchARM_CortexA520,
  CPUMicroarchARM_CortexA710,
  CPUMicroarchARM_CortexA715,
  CPUMicroarchARM_CortexA720,
  CPUMicroarchARM_CortexA725,
  CPUMicroarchARM_CortexX1,
  CPUMicroarchARM_CortexX2,
  CPUMicroarchARM_CortexX3,
  CPUMicroarchARM_CortexX4,
  CPUMicroarchARM_CortexX925,
  CPUMicroarchARM_NeoverseN1,
  CPUMicroarchARM_NeoverseN2,
  CPUMicroarchARM_NeoverseN3,
  CPUMicroarchARM_NeoverseV1,
  CPUMicroarchARM_NeoverseV2,
  CPUMicroarchARM_NeoverseV3,
  CPUMicroarchARM_NeoverseE1,
  // Apple Silicon
  CPUMicroarchApple_A7 = 400,
  CPUMicroarchApple_A8,
  CPUMicroarchApple_A9,
  CPUMicroarchApple_A10,
  CPUMicroarchApple_A11,
  CPUMicroarchApple_A12,
  CPUMicroarchApple_A13,
  CPUMicroarchApple_A14,
  CPUMicroarchApple_A15,
  CPUMicroarchApple_A16,
  CPUMicroarchApple_A17Pro,
  CPUMicroarchApple_A18,
  CPUMicroarchApple_A18Pro,
  CPUMicroarchApple_M1,
  CPUMicroarchApple_M1Pro,
  CPUMicroarchApple_M1Max,
  CPUMicroarchApple_M1Ultra,
  CPUMicroarchApple_M2,
  CPUMicroarchApple_M2Pro,
  CPUMicroarchApple_M2Max,
  CPUMicroarchApple_M2Ultra,
  CPUMicroarchApple_M3,
  CPUMicroarchApple_M3Pro,
  CPUMicroarchApple_M3Max,
  CPUMicroarchApple_M3Ultra,
  CPUMicroarchApple_M4,
  CPUMicroarchApple_M4Pro,
  CPUMicroarchApple_M4Max,
  CPUMicroarchApple_M4Ultra,
  // Qualcomm
  CPUMicroarchQualcomm_Kryo = 500,
  CPUMicroarchQualcomm_Kryo2xx,
  CPUMicroarchQualcomm_Kryo3xx,
  CPUMicroarchQualcomm_Kryo4xx,
  CPUMicroarchQualcomm_Kryo5xx,
  CPUMicroarchQualcomm_Kryo6xx,
  CPUMicroarchQualcomm_Kryo7xx,
  CPUMicroarchQualcomm_Oryon,
  CPUMicroarchQualcomm_OryonV2,
  // Samsung
  CPUMicroarchSamsung_Mongoose = 550,
  CPUMicroarchSamsung_MongooseM3,
  CPUMicroarchSamsung_MongooseM4,
  CPUMicroarchSamsung_MongooseM5,
  // RISC-V
  CPUMicroarchRISCV_U54 = 600,
  CPUMicroarchRISCV_U74,
  CPUMicroarchRISCV_P550,
  CPUMicroarchRISCV_P670,
  CPUMicroarchRISCV_X280,
  CPUMicroarchRISCV_C920,
  CPUMicroarchRISCV_C910,
  CPUMicroarchRISCV_C906,
  // MIPS
  CPUMicroarchMIPS_P5600 = 700,
  CPUMicroarchMIPS_I6500,
  CPUMicroarchMIPS_I6400,
  // IBM
  CPUMicroarchIBM_Power8 = 800,
  CPUMicroarchIBM_Power9,
  CPUMicroarchIBM_Power10,
  CPUMicroarchIBM_Power11,
  CPUMicroarchIBM_Z15,
  CPUMicroarchIBM_Z16,
  // Fujitsu
  CPUMicroarchFujitsu_A64FX = 850,
  // Ampere
  CPUMicroarchAmpere_Altra = 870,
  CPUMicroarchAmpere_AltraMax,
  CPUMicroarchAmpere_AmpereOne,
  // Loongson
  CPUMicroarchLoongson_3A5000 = 900,
  CPUMicroarchLoongson_3A6000
};

// CPU Feature Flags
typedef NS_OPTIONS(uint64_t, CPUFeatureFlags) {
  CPUFeatureFPU = 1ULL << 0,
  CPUFeatureMMX = 1ULL << 1,
  CPUFeatureSSE = 1ULL << 2,
  CPUFeatureSSE2 = 1ULL << 3,
  CPUFeatureSSE3 = 1ULL << 4,
  CPUFeatureSSSE3 = 1ULL << 5,
  CPUFeatureSSE4_1 = 1ULL << 6,
  CPUFeatureSSE4_2 = 1ULL << 7,
  CPUFeatureAVX = 1ULL << 8,
  CPUFeatureAVX2 = 1ULL << 9,
  CPUFeatureAVX512F = 1ULL << 10,
  CPUFeatureAVX512BW = 1ULL << 11,
  CPUFeatureAVX512VL = 1ULL << 12,
  CPUFeatureAVX512VNNI = 1ULL << 13,
  CPUFeatureAVX_VNNI = 1ULL << 14,
  CPUFeatureAMX_TILE = 1ULL << 15,
  CPUFeatureAMX_BF16 = 1ULL << 16,
  CPUFeatureAMX_INT8 = 1ULL << 17,
  CPUFeatureNEON = 1ULL << 18,
  CPUFeatureSVE = 1ULL << 19,
  CPUFeatureSVE2 = 1ULL << 20,
  CPUFeatureSME = 1ULL << 21,
  CPUFeatureSME2 = 1ULL << 22,
  CPUFeatureBF16 = 1ULL << 23,
  CPUFeatureDOTPROD = 1ULL << 24,
  CPUFeatureAES = 1ULL << 25,
  CPUFeatureSHA = 1ULL << 26,
  CPUFeatureSHA2 = 1ULL << 27,
  CPUFeatureSHA3 = 1ULL << 28,
  CPUFeatureCRC32 = 1ULL << 29,
  CPUFeatureATOMICS = 1ULL << 30,
  CPUFeatureVirtualization = 1ULL << 31,
  CPUFeatureVT_x = 1ULL << 32,
  CPUFeatureAMD_V = 1ULL << 33,
  CPUFeatureHyperV = 1ULL << 34,
  CPUFeatureTME = 1ULL << 35,
  CPUFeatureSGX = 1ULL << 36,
  CPUFeatureTDX = 1ULL << 37,
  CPUFeatureSEV = 1ULL << 38,
  CPUFeatureRISCV_M = 1ULL << 39,
  CPUFeatureRISCV_A = 1ULL << 40,
  CPUFeatureRISCV_F = 1ULL << 41,
  CPUFeatureRISCV_D = 1ULL << 42,
  CPUFeatureRISCV_C = 1ULL << 43,
  CPUFeatureRISCV_V = 1ULL << 44,
  CPUFeatureMIPS_MSA = 1ULL << 45,
  CPUFeatureAltiVec = 1ULL << 46,
  CPUFeatureVSX = 1ULL << 47,
  CPUFeatureMTE = 1ULL << 48,
  CPUFeaturePAuth = 1ULL << 49,
  CPUFeatureBTI = 1ULL << 50
};

// Cache Level
@interface CPUCacheLevel : NSObject
@property(nonatomic, assign) NSUInteger level; // L1, L2, L3, L4
@property(nonatomic, strong) NSString *type; // "instruction", "data", "unified"
@property(nonatomic, assign) NSUInteger sizeKB;
@property(nonatomic, assign) NSUInteger ways;
@property(nonatomic, assign) NSUInteger lineSize;
@property(nonatomic, assign) NSUInteger sets;
@property(nonatomic, assign) BOOL shared;
@property(nonatomic, assign) NSUInteger sharedByCores;
@end

// CPU Core Info
@interface CPUCoreInfo : NSObject
@property(nonatomic, assign) NSUInteger coreID;
@property(nonatomic, strong) NSString *type; // "P-core", "E-core", "S-core"
@property(nonatomic, assign) NSUInteger baseFreqMHz;
@property(nonatomic, assign) NSUInteger boostFreqMHz;
@property(nonatomic, assign) NSUInteger threads;
@property(nonatomic, strong) NSArray<CPUCacheLevel *> *caches;
@property(nonatomic, assign) CPUMicroarch microarch;
@end

// CPU Model Definition
@interface CPUModelDefinition : NSObject
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSString *codename;
@property(nonatomic, assign) CPUVendor vendor;
@property(nonatomic, assign) CPUArchType architecture;
@property(nonatomic, assign) CPUMicroarch microarchitecture;
@property(nonatomic, assign) NSUInteger year;
@property(nonatomic, assign) NSUInteger processNode; // nm
@property(nonatomic, assign) NSUInteger totalCores;
@property(nonatomic, assign) NSUInteger performanceCores;
@property(nonatomic, assign) NSUInteger efficiencyCores;
@property(nonatomic, assign) NSUInteger totalThreads;
@property(nonatomic, assign) NSUInteger baseFreqMHz;
@property(nonatomic, assign) NSUInteger boostFreqMHz;
@property(nonatomic, assign) NSUInteger l1CacheKB;
@property(nonatomic, assign) NSUInteger l2CacheMB;
@property(nonatomic, assign) NSUInteger l3CacheMB;
@property(nonatomic, assign) NSUInteger tdpWatts;
@property(nonatomic, assign) CPUFeatureFlags features;
@property(nonatomic, strong) NSString *socket;
@property(nonatomic, strong)
    NSString *segment; // "desktop", "mobile", "server", "embedded"
@property(nonatomic, strong) NSArray<CPUCoreInfo *> *cores;
@property(nonatomic, strong) NSDictionary *additionalInfo;
@end

// CPU Architecture Manager
@interface CPUArchitectureManager : NSObject

+ (instancetype)sharedInstance;

// Detection
- (CPUModelDefinition *)detectCurrentCPU;
- (CPUArchType)currentArchitecture;
- (CPUVendor)currentVendor;
- (CPUFeatureFlags)currentFeatures;
- (NSString *)currentCPUBrand;

// Database queries
- (NSArray<CPUModelDefinition *> *)allCPUs;
- (NSArray<CPUModelDefinition *> *)cpusForVendor:(CPUVendor)vendor;
- (NSArray<CPUModelDefinition *> *)cpusForArchitecture:(CPUArchType)arch;
- (NSArray<CPUModelDefinition *> *)cpusForMicroarch:(CPUMicroarch)microarch;
- (NSArray<CPUModelDefinition *> *)cpusForSegment:(NSString *)segment;
- (NSArray<CPUModelDefinition *> *)cpusWithFeature:(CPUFeatureFlags)feature;
- (CPUModelDefinition *)cpuByName:(NSString *)name;

// Feature checking
- (BOOL)supportsFeature:(CPUFeatureFlags)feature;
- (NSArray<NSString *> *)featureList;
- (NSArray<NSString *> *)featureListForFlags:(CPUFeatureFlags)flags;

// Utility
- (NSString *)vendorName:(CPUVendor)vendor;
- (NSString *)architectureName:(CPUArchType)arch;
- (NSString *)microarchName:(CPUMicroarch)microarch;
- (NSDictionary *)systemCPUInfo;
- (NSUInteger)cpuDatabaseCount;

@end
