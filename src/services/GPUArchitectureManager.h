#pragma once
#import <Cocoa/Cocoa.h>

// ============================================================================
// GPU ARCHITECTURE MANAGER — Comprehensive GPU Database
// ============================================================================

typedef NS_ENUM(NSInteger, GPUVendor) {
  GPUVendorUnknown = 0,
  GPUVendorNVIDIA,
  GPUVendorAMD,
  GPUVendorIntel,
  GPUVendorApple,
  GPUVendorQualcomm,
  GPUVendorARM,
  GPUVendorImaginationTech,
  GPUVendorSamsung,
  GPUVendorBroadcom,
  GPUVendorMooreThreads,
  GPUVendorLoongson
};

typedef NS_ENUM(NSInteger, GPUArchFamily) {
  // NVIDIA Architectures
  GPUArchNV_Kepler = 100,
  GPUArchNV_Maxwell,
  GPUArchNV_Pascal,
  GPUArchNV_Volta,
  GPUArchNV_Turing,
  GPUArchNV_Ampere,
  GPUArchNV_Ada,
  GPUArchNV_Hopper,
  GPUArchNV_Blackwell,
  // AMD Architectures
  GPUArchAMD_GCN1 = 200,
  GPUArchAMD_GCN2,
  GPUArchAMD_GCN3,
  GPUArchAMD_GCN4,
  GPUArchAMD_GCN5,
  GPUArchAMD_RDNA1,
  GPUArchAMD_RDNA2,
  GPUArchAMD_RDNA3,
  GPUArchAMD_RDNA3_5,
  GPUArchAMD_RDNA4,
  GPUArchAMD_CDNA1,
  GPUArchAMD_CDNA2,
  GPUArchAMD_CDNA3,
  GPUArchAMD_CDNA4,
  // Intel Architectures
  GPUArchIntel_Gen9 = 300,
  GPUArchIntel_Gen11,
  GPUArchIntel_Gen12,
  GPUArchIntel_Xe_LP,
  GPUArchIntel_Xe_HPG,
  GPUArchIntel_Xe_HPC,
  GPUArchIntel_Xe2_LPG,
  GPUArchIntel_Xe2_HPG,
  GPUArchIntel_Xe3,
  // Apple Architectures
  GPUArchApple_G13 = 400,
  GPUArchApple_G14,
  GPUArchApple_G15,
  GPUArchApple_G15X,
  // Mobile
  GPUArchAdreno_700 = 500,
  GPUArchAdreno_750,
  GPUArchAdreno_X1,
  GPUArchMali_G700 = 550,
  GPUArchMali_G720,
  GPUArchMali_5thGen,
  GPUArchXclipse_900 = 580,
  GPUArchXclipse_940,
  GPUArchImgBXT = 590,
  GPUArchImgDXT
};

typedef NS_OPTIONS(uint64_t, GPUFeatureFlags) {
  GPUFeatureRayTracing = 1ULL << 0,
  GPUFeatureMeshShaders = 1ULL << 1,
  GPUFeatureVRS = 1ULL << 2,
  GPUFeatureSamplerFeedback = 1ULL << 3,
  GPUFeatureDLSS = 1ULL << 4,
  GPUFeatureFSR = 1ULL << 5,
  GPUFeatureXeSS = 1ULL << 6,
  GPUFeatureMetalFX = 1ULL << 7,
  GPUFeatureFP16 = 1ULL << 8,
  GPUFeatureBF16 = 1ULL << 9,
  GPUFeatureFP64 = 1ULL << 10,
  GPUFeatureINT4 = 1ULL << 11,
  GPUFeatureINT8 = 1ULL << 12,
  GPUFeatureTensorCores = 1ULL << 13,
  GPUFeatureMatrixCores = 1ULL << 14,
  GPUFeatureNPU = 1ULL << 15,
  GPUFeatureAV1Encode = 1ULL << 16,
  GPUFeatureAV1Decode = 1ULL << 17,
  GPUFeatureHEVCEncode = 1ULL << 18,
  GPUFeatureH264Encode = 1ULL << 19,
  GPUFeatureVulkan = 1ULL << 20,
  GPUFeatureDirectX12 = 1ULL << 21,
  GPUFeatureMetal = 1ULL << 22,
  GPUFeatureOpenGL = 1ULL << 23,
  GPUFeatureOpenCL = 1ULL << 24,
  GPUFeatureCUDA = 1ULL << 25,
  GPUFeatureROCm = 1ULL << 26,
  GPUFeatureOneAPI = 1ULL << 27,
  GPUFeatureNVLink = 1ULL << 28,
  GPUFeatureInfinityFabric = 1ULL << 29,
  GPUFeatureReBAR = 1ULL << 30,
  GPUFeatureDisplayPort21 = 1ULL << 31,
  GPUFeatureHDMI21 = 1ULL << 32,
  GPUFeature8KOutput = 1ULL << 33,
  GPUFeatureMultiGPU = 1ULL << 34,
  GPUFeatureHWScheduling = 1ULL << 35,
  GPUFeatureFlexibleRender = 1ULL << 36,
  GPUFeatureReactiveMask = 1ULL << 37
};

typedef NS_ENUM(NSInteger, GPUMemoryType) {
  GPUMemGDDR5 = 0,
  GPUMemGDDR5X,
  GPUMemGDDR6,
  GPUMemGDDR6X,
  GPUMemGDDR7,
  GPUMemHBM2,
  GPUMemHBM2e,
  GPUMemHBM3,
  GPUMemHBM3e,
  GPUMemLPDDR4X,
  GPUMemLPDDR5,
  GPUMemLPDDR5X,
  GPUMemUnifiedMemory
};

typedef NS_ENUM(NSInteger, GPUSegment) {
  GPUSegmentConsumer = 0,
  GPUSegmentProfessional,
  GPUSegmentDatacenter,
  GPUSegmentMobile,
  GPUSegmentIntegrated,
  GPUSegmentEmbedded
};

@interface GPUModelDefinition : NSObject
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSString *chip;
@property(nonatomic, assign) GPUVendor vendor;
@property(nonatomic, assign) GPUArchFamily architecture;
@property(nonatomic, assign) NSUInteger year;
@property(nonatomic, assign) NSUInteger processNode;
@property(nonatomic, assign) NSUInteger shaderCores;
@property(nonatomic, assign) NSUInteger rtCores;
@property(nonatomic, assign) NSUInteger tensorCores;
@property(nonatomic, assign) NSUInteger tmus;
@property(nonatomic, assign) NSUInteger rops;
@property(nonatomic, assign) NSUInteger baseClockMHz;
@property(nonatomic, assign) NSUInteger boostClockMHz;
@property(nonatomic, assign) NSUInteger vramMB;
@property(nonatomic, assign) GPUMemoryType memoryType;
@property(nonatomic, assign) NSUInteger memoryBusWidth;
@property(nonatomic, assign) NSUInteger memoryBandwidthGBs;
@property(nonatomic, assign) NSUInteger tdpWatts;
@property(nonatomic, assign) double tflops_fp32;
@property(nonatomic, assign) double tflops_fp16;
@property(nonatomic, assign) GPUFeatureFlags features;
@property(nonatomic, assign) GPUSegment segment;
@property(nonatomic, strong) NSString *apiSupport;
@end

@interface GPUArchitectureManager : NSObject
+ (instancetype)sharedInstance;
- (NSArray<GPUModelDefinition *> *)allGPUs;
- (NSArray<GPUModelDefinition *> *)gpusForVendor:(GPUVendor)vendor;
- (NSArray<GPUModelDefinition *> *)gpusForArchitecture:(GPUArchFamily)arch;
- (NSArray<GPUModelDefinition *> *)gpusForSegment:(GPUSegment)segment;
- (GPUModelDefinition *)gpuByName:(NSString *)name;
- (GPUModelDefinition *)detectCurrentGPU;
- (NSString *)vendorName:(GPUVendor)vendor;
- (NSString *)architectureName:(GPUArchFamily)arch;
- (NSArray<NSString *> *)featureListForFlags:(GPUFeatureFlags)flags;
- (NSDictionary *)systemGPUInfo;
- (NSUInteger)gpuDatabaseCount;
@end
