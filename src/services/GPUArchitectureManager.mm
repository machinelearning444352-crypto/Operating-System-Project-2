#import "GPUArchitectureManager.h"
#include <IOKit/IOKitLib.h>

@implementation GPUModelDefinition
- (instancetype)init {
  self = [super init];
  if (self) {
    _name = @"";
    _chip = @"";
    _vendor = GPUVendorUnknown;
    _architecture = (GPUArchFamily)0;
    _year = 0;
    _processNode = 0;
    _shaderCores = 0;
    _rtCores = 0;
    _tensorCores = 0;
    _tmus = 0;
    _rops = 0;
    _baseClockMHz = 0;
    _boostClockMHz = 0;
    _vramMB = 0;
    _memoryType = GPUMemGDDR6;
    _memoryBusWidth = 0;
    _memoryBandwidthGBs = 0;
    _tdpWatts = 0;
    _tflops_fp32 = 0;
    _tflops_fp16 = 0;
    _features = 0;
    _segment = GPUSegmentConsumer;
    _apiSupport = @"";
  }
  return self;
}
@end

#define GPU(n, ch, v, a, y, pn, sc, rt, tc, tm, ro, bc, boc, vr, mt, bw, mbw,  \
            tdp, fp32, fp16, f, seg, api)                                      \
  ({                                                                           \
    GPUModelDefinition *g = [[GPUModelDefinition alloc] init];                 \
    g.name = n;                                                                \
    g.chip = ch;                                                               \
    g.vendor = v;                                                              \
    g.architecture = a;                                                        \
    g.year = y;                                                                \
    g.processNode = pn;                                                        \
    g.shaderCores = sc;                                                        \
    g.rtCores = rt;                                                            \
    g.tensorCores = tc;                                                        \
    g.tmus = tm;                                                               \
    g.rops = ro;                                                               \
    g.baseClockMHz = bc;                                                       \
    g.boostClockMHz = boc;                                                     \
    g.vramMB = vr;                                                             \
    g.memoryType = mt;                                                         \
    g.memoryBusWidth = bw;                                                     \
    g.memoryBandwidthGBs = mbw;                                                \
    g.tdpWatts = tdp;                                                          \
    g.tflops_fp32 = fp32;                                                      \
    g.tflops_fp16 = fp16;                                                      \
    g.features = f;                                                            \
    g.segment = seg;                                                           \
    g.apiSupport = api;                                                        \
    g;                                                                         \
  })

#define NV_ADA                                                                 \
  (GPUFeatureRayTracing | GPUFeatureMeshShaders | GPUFeatureVRS |              \
   GPUFeatureDLSS | GPUFeatureTensorCores | GPUFeatureFP16 | GPUFeatureINT8 |  \
   GPUFeatureAV1Encode | GPUFeatureAV1Decode | GPUFeatureHEVCEncode |          \
   GPUFeatureVulkan | GPUFeatureDirectX12 | GPUFeatureOpenGL |                 \
   GPUFeatureOpenCL | GPUFeatureCUDA | GPUFeatureReBAR | GPUFeatureNVLink |    \
   GPUFeatureDisplayPort21 | GPUFeatureHDMI21)
#define NV_HOPPER                                                              \
  (GPUFeatureFP16 | GPUFeatureBF16 | GPUFeatureFP64 | GPUFeatureINT8 |         \
   GPUFeatureINT4 | GPUFeatureTensorCores | GPUFeatureCUDA |                   \
   GPUFeatureNVLink | GPUFeatureHWScheduling)
#define NV_BW (NV_HOPPER | GPUFeatureRayTracing | GPUFeatureMeshShaders)
#define AMD_RDNA3                                                              \
  (GPUFeatureRayTracing | GPUFeatureMeshShaders | GPUFeatureVRS |              \
   GPUFeatureFSR | GPUFeatureFP16 | GPUFeatureAV1Encode |                      \
   GPUFeatureAV1Decode | GPUFeatureVulkan | GPUFeatureDirectX12 |              \
   GPUFeatureOpenGL | GPUFeatureOpenCL | GPUFeatureROCm | GPUFeatureReBAR |    \
   GPUFeatureInfinityFabric | GPUFeatureDisplayPort21 | GPUFeatureHDMI21)
#define AMD_CDNA                                                               \
  (GPUFeatureFP16 | GPUFeatureBF16 | GPUFeatureFP64 | GPUFeatureINT8 |         \
   GPUFeatureMatrixCores | GPUFeatureROCm | GPUFeatureOpenCL |                 \
   GPUFeatureInfinityFabric)
#define INTEL_XE                                                               \
  (GPUFeatureRayTracing | GPUFeatureMeshShaders | GPUFeatureVRS |              \
   GPUFeatureXeSS | GPUFeatureFP16 | GPUFeatureAV1Encode |                     \
   GPUFeatureAV1Decode | GPUFeatureVulkan | GPUFeatureDirectX12 |              \
   GPUFeatureOpenGL | GPUFeatureOpenCL | GPUFeatureOneAPI | GPUFeatureReBAR)
#define APPLE_GPU                                                              \
  (GPUFeatureRayTracing | GPUFeatureMeshShaders | GPUFeatureFP16 |             \
   GPUFeatureBF16 | GPUFeatureINT8 | GPUFeatureMetal | GPUFeatureMetalFX |     \
   GPUFeatureNPU)
#define MOBILE_GPU                                                             \
  (GPUFeatureVulkan | GPUFeatureOpenGL | GPUFeatureOpenCL | GPUFeatureFP16)

@interface GPUArchitectureManager ()
@property(nonatomic, strong) NSMutableArray<GPUModelDefinition *> *gpuDatabase;
@end

@implementation GPUArchitectureManager
+ (instancetype)sharedInstance {
  static GPUArchitectureManager *inst = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    inst = [[self alloc] init];
  });
  return inst;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _gpuDatabase = [NSMutableArray array];
    [self buildDatabase];
  }
  return self;
}

- (void)buildDatabase {
  // ========== NVIDIA GeForce (Consumer) ==========
  [_gpuDatabase
      addObject:GPU(@"NVIDIA GeForce RTX 5090", @"GB202", GPUVendorNVIDIA,
                    GPUArchNV_Blackwell, 2025, 4, 21760, 192, 768, 680, 176,
                    2010, 2407, 32768, GPUMemGDDR7, 512, 1792, 575, 104.8,
                    209.6, NV_ADA, GPUSegmentConsumer,
                    @"DX12U/Vulkan1.4/OpenGL4.6")];
  [_gpuDatabase
      addObject:GPU(@"NVIDIA GeForce RTX 5080", @"GB203", GPUVendorNVIDIA,
                    GPUArchNV_Blackwell, 2025, 4, 10752, 84, 336, 336, 112,
                    2310, 2617, 16384, GPUMemGDDR7, 256, 960, 360, 56.3, 112.6,
                    NV_ADA, GPUSegmentConsumer, @"DX12U/Vulkan1.4/OpenGL4.6")];
  [_gpuDatabase
      addObject:GPU(@"NVIDIA GeForce RTX 5070 Ti", @"GB203", GPUVendorNVIDIA,
                    GPUArchNV_Blackwell, 2025, 4, 8960, 70, 280, 280, 96, 2162,
                    2452, 16384, GPUMemGDDR7, 256, 896, 300, 43.9, 87.8, NV_ADA,
                    GPUSegmentConsumer, @"DX12U/Vulkan1.4/OpenGL4.6")];
  [_gpuDatabase
      addObject:GPU(@"NVIDIA GeForce RTX 5070", @"GB205", GPUVendorNVIDIA,
                    GPUArchNV_Blackwell, 2025, 4, 6144, 48, 192, 192, 80, 1980,
                    2512, 12288, GPUMemGDDR7, 192, 672, 250, 30.9, 61.8, NV_ADA,
                    GPUSegmentConsumer, @"DX12U/Vulkan1.4/OpenGL4.6")];
  [_gpuDatabase
      addObject:GPU(@"NVIDIA GeForce RTX 4090", @"AD102", GPUVendorNVIDIA,
                    GPUArchNV_Ada, 2022, 4, 16384, 128, 512, 512, 176, 2235,
                    2520, 24576, GPUMemGDDR6X, 384, 1008, 450, 82.6, 165.2,
                    NV_ADA, GPUSegmentConsumer, @"DX12U/Vulkan1.3/OpenGL4.6")];
  [_gpuDatabase
      addObject:GPU(@"NVIDIA GeForce RTX 4080 SUPER", @"AD103", GPUVendorNVIDIA,
                    GPUArchNV_Ada, 2024, 4, 10240, 80, 320, 320, 112, 2295,
                    2550, 16384, GPUMemGDDR6X, 256, 736, 320, 52.2, 104.4,
                    NV_ADA, GPUSegmentConsumer, @"DX12U/Vulkan1.3")];
  [_gpuDatabase
      addObject:GPU(@"NVIDIA GeForce RTX 4070 Ti SUPER", @"AD103",
                    GPUVendorNVIDIA, GPUArchNV_Ada, 2024, 4, 8448, 66, 264, 264,
                    96, 2340, 2610, 16384, GPUMemGDDR6X, 256, 672, 285, 44.1,
                    88.2, NV_ADA, GPUSegmentConsumer, @"DX12U/Vulkan1.3")];
  [_gpuDatabase
      addObject:GPU(@"NVIDIA GeForce RTX 4070", @"AD104", GPUVendorNVIDIA,
                    GPUArchNV_Ada, 2023, 4, 5888, 46, 184, 184, 64, 1920, 2475,
                    12288, GPUMemGDDR6X, 192, 504, 200, 29.1, 58.3, NV_ADA,
                    GPUSegmentConsumer, @"DX12U/Vulkan1.3")];
  [_gpuDatabase
      addObject:GPU(@"NVIDIA GeForce RTX 4060 Ti", @"AD106", GPUVendorNVIDIA,
                    GPUArchNV_Ada, 2023, 4, 4352, 34, 136, 136, 48, 2310, 2535,
                    8192, GPUMemGDDR6, 128, 288, 160, 22.1, 44.1, NV_ADA,
                    GPUSegmentConsumer, @"DX12U/Vulkan1.3")];
  [_gpuDatabase
      addObject:GPU(@"NVIDIA GeForce RTX 3090 Ti", @"GA102", GPUVendorNVIDIA,
                    GPUArchNV_Ampere, 2022, 8, 10752, 84, 336, 336, 112, 1560,
                    1860, 24576, GPUMemGDDR6X, 384, 1008, 450, 40.0, 80.0,
                    NV_ADA & ~GPUFeatureDLSS | GPUFeatureDLSS,
                    GPUSegmentConsumer, @"DX12U/Vulkan1.3")];
  [_gpuDatabase
      addObject:GPU(@"NVIDIA GeForce RTX 3080", @"GA102", GPUVendorNVIDIA,
                    GPUArchNV_Ampere, 2020, 8, 8704, 68, 272, 272, 96, 1440,
                    1710, 10240, GPUMemGDDR6X, 320, 760, 320, 29.8, 59.5,
                    NV_ADA & ~GPUFeatureDLSS | GPUFeatureDLSS,
                    GPUSegmentConsumer, @"DX12U/Vulkan1.3")];
  [_gpuDatabase
      addObject:GPU(@"NVIDIA GeForce RTX 2080 Ti", @"TU102", GPUVendorNVIDIA,
                    GPUArchNV_Turing, 2018, 12, 4352, 68, 544, 272, 88, 1350,
                    1545, 11264, GPUMemGDDR6, 352, 616, 250, 13.4, 26.9,
                    NV_ADA & ~(GPUFeatureAV1Encode | GPUFeatureAV1Decode),
                    GPUSegmentConsumer, @"DX12U/Vulkan1.2")];

  // ========== NVIDIA Datacenter ==========
  [_gpuDatabase
      addObject:GPU(@"NVIDIA B200", @"GB200", GPUVendorNVIDIA,
                    GPUArchNV_Blackwell, 2024, 4, 18432, 0, 1152, 0, 0, 0, 1800,
                    196608, GPUMemHBM3e, 8192, 8000, 1000, 72.0, 144.0, NV_BW,
                    GPUSegmentDatacenter, @"CUDA/NVLink6")];
  [_gpuDatabase
      addObject:GPU(@"NVIDIA H200", @"GH200", GPUVendorNVIDIA, GPUArchNV_Hopper,
                    2024, 4, 16896, 0, 528, 0, 0, 0, 1980, 147456, GPUMemHBM3e,
                    6144, 4800, 700, 66.9, 133.8, NV_HOPPER,
                    GPUSegmentDatacenter, @"CUDA/NVLink4")];
  [_gpuDatabase
      addObject:GPU(@"NVIDIA H100 SXM", @"GH100", GPUVendorNVIDIA,
                    GPUArchNV_Hopper, 2022, 4, 16896, 0, 528, 0, 0, 0, 1830,
                    81920, GPUMemHBM3, 5120, 3350, 700, 66.9, 133.8, NV_HOPPER,
                    GPUSegmentDatacenter, @"CUDA/NVLink4")];
  [_gpuDatabase addObject:GPU(@"NVIDIA A100 80GB", @"GA100", GPUVendorNVIDIA,
                              GPUArchNV_Ampere, 2020, 7, 6912, 0, 432, 0, 0, 0,
                              1410, 81920, GPUMemHBM2e, 5120, 2039, 400, 19.5,
                              78.0, NV_HOPPER & ~GPUFeatureBF16,
                              GPUSegmentDatacenter, @"CUDA/NVLink3")];
  [_gpuDatabase
      addObject:GPU(@"NVIDIA L40S", @"AD102", GPUVendorNVIDIA, GPUArchNV_Ada,
                    2023, 4, 18176, 142, 568, 568, 192, 2070, 2520, 49152,
                    GPUMemGDDR6, 384, 864, 350, 91.6, 183.2, NV_ADA,
                    GPUSegmentDatacenter, @"CUDA/vGPU")];

  // ========== NVIDIA Professional ==========
  [_gpuDatabase
      addObject:GPU(@"NVIDIA RTX 6000 Ada", @"AD102", GPUVendorNVIDIA,
                    GPUArchNV_Ada, 2022, 4, 18176, 142, 568, 568, 192, 2070,
                    2505, 49152, GPUMemGDDR6, 384, 960, 300, 91.1, 182.2,
                    NV_ADA | GPUFeatureNVLink, GPUSegmentProfessional,
                    @"DX12U/Vulkan/OpenGL/CUDA")];

  // ========== AMD Radeon (Consumer) ==========
  [_gpuDatabase
      addObject:GPU(@"AMD Radeon RX 9070 XT", @"Navi 48", GPUVendorAMD,
                    GPUArchAMD_RDNA4, 2025, 4, 4096, 64, 0, 256, 96, 2002, 2450,
                    16384, GPUMemGDDR6, 256, 512, 200, 20.1, 40.1,
                    AMD_RDNA3 | GPUFeatureRayTracing, GPUSegmentConsumer,
                    @"DX12U/Vulkan1.4")];
  [_gpuDatabase addObject:GPU(@"AMD Radeon RX 9070", @"Navi 48", GPUVendorAMD,
                              GPUArchAMD_RDNA4, 2025, 4, 3584, 56, 0, 224, 80,
                              1854, 2376, 16384, GPUMemGDDR6, 256, 512, 180,
                              17.0, 34.0, AMD_RDNA3 | GPUFeatureRayTracing,
                              GPUSegmentConsumer, @"DX12U/Vulkan1.4")];
  [_gpuDatabase
      addObject:GPU(@"AMD Radeon RX 7900 XTX", @"Navi 31", GPUVendorAMD,
                    GPUArchAMD_RDNA3, 2022, 5, 6144, 96, 0, 384, 192, 1855,
                    2500, 24576, GPUMemGDDR6, 384, 960, 355, 61.4, 122.8,
                    AMD_RDNA3, GPUSegmentConsumer, @"DX12U/Vulkan1.3")];
  [_gpuDatabase
      addObject:GPU(@"AMD Radeon RX 7900 XT", @"Navi 31", GPUVendorAMD,
                    GPUArchAMD_RDNA3, 2022, 5, 5376, 84, 0, 336, 192, 1500,
                    2400, 20480, GPUMemGDDR6, 320, 800, 315, 51.5, 103.0,
                    AMD_RDNA3, GPUSegmentConsumer, @"DX12U/Vulkan1.3")];
  [_gpuDatabase
      addObject:GPU(@"AMD Radeon RX 7800 XT", @"Navi 32", GPUVendorAMD,
                    GPUArchAMD_RDNA3, 2023, 5, 3840, 60, 0, 240, 96, 1295, 2430,
                    16384, GPUMemGDDR6, 256, 624, 263, 37.3, 74.6, AMD_RDNA3,
                    GPUSegmentConsumer, @"DX12U/Vulkan1.3")];
  [_gpuDatabase
      addObject:GPU(@"AMD Radeon RX 7600", @"Navi 33", GPUVendorAMD,
                    GPUArchAMD_RDNA3, 2023, 6, 2048, 32, 0, 128, 64, 1720, 2655,
                    8192, GPUMemGDDR6, 128, 288, 165, 10.9, 21.8, AMD_RDNA3,
                    GPUSegmentConsumer, @"DX12U/Vulkan1.3")];
  [_gpuDatabase
      addObject:GPU(@"AMD Radeon RX 6950 XT", @"Navi 21", GPUVendorAMD,
                    GPUArchAMD_RDNA2, 2022, 7, 5120, 80, 0, 320, 128, 1860,
                    2310, 16384, GPUMemGDDR6, 256, 576, 335, 23.7, 47.3,
                    AMD_RDNA3 & ~GPUFeatureAV1Encode, GPUSegmentConsumer,
                    @"DX12U/Vulkan1.3")];

  // ========== AMD Datacenter ==========
  [_gpuDatabase addObject:GPU(@"AMD Instinct MI300X", @"MI300X", GPUVendorAMD,
                              GPUArchAMD_CDNA3, 2023, 5, 19456, 0, 0, 0, 0,
                              1000, 2100, 196608, GPUMemHBM3, 8192, 5300, 750,
                              163.4, 653.7, AMD_CDNA | GPUFeatureINT4,
                              GPUSegmentDatacenter, @"ROCm/OpenCL")];
  [_gpuDatabase
      addObject:GPU(@"AMD Instinct MI250X", @"MI250X", GPUVendorAMD,
                    GPUArchAMD_CDNA2, 2021, 6, 14080, 0, 0, 0, 0, 1500, 1700,
                    131072, GPUMemHBM2e, 8192, 3277, 560, 47.9, 383.0, AMD_CDNA,
                    GPUSegmentDatacenter, @"ROCm/OpenCL")];

  // ========== Intel Arc (Consumer) ==========
  [_gpuDatabase
      addObject:GPU(@"Intel Arc B580", @"BMG-G21", GPUVendorIntel,
                    GPUArchIntel_Xe2_HPG, 2024, 4, 2560, 20, 0, 160, 80, 1740,
                    2670, 12288, GPUMemGDDR6, 192, 456, 150, 13.7, 27.4,
                    INTEL_XE, GPUSegmentConsumer, @"DX12U/Vulkan1.3")];
  [_gpuDatabase
      addObject:GPU(@"Intel Arc A770", @"ACM-G10", GPUVendorIntel,
                    GPUArchIntel_Xe_HPG, 2022, 6, 4096, 32, 0, 256, 128, 2100,
                    2400, 16384, GPUMemGDDR6, 256, 560, 225, 19.7, 39.3,
                    INTEL_XE, GPUSegmentConsumer, @"DX12U/Vulkan1.3")];
  [_gpuDatabase
      addObject:GPU(@"Intel Arc A750", @"ACM-G10", GPUVendorIntel,
                    GPUArchIntel_Xe_HPG, 2022, 6, 3584, 28, 0, 224, 112, 2050,
                    2400, 8192, GPUMemGDDR6, 256, 512, 225, 17.2, 34.4,
                    INTEL_XE, GPUSegmentConsumer, @"DX12U/Vulkan1.3")];

  // ========== Intel Datacenter ==========
  [_gpuDatabase addObject:GPU(@"Intel Gaudi 3", @"Gaudi3", GPUVendorIntel,
                              GPUArchIntel_Xe_HPC, 2024, 5, 0, 0, 0, 0, 0, 0, 0,
                              131072, GPUMemHBM2e, 4096, 3700, 900, 0, 1835.0,
                              GPUFeatureBF16 | GPUFeatureFP16 | GPUFeatureINT8 |
                                  GPUFeatureOneAPI,
                              GPUSegmentDatacenter, @"OneAPI/PyTorch")];
  [_gpuDatabase
      addObject:GPU(@"Intel Data Center GPU Max 1550", @"Ponte Vecchio",
                    GPUVendorIntel, GPUArchIntel_Xe_HPC, 2023, 7, 8192, 0, 0, 0,
                    0, 900, 1600, 131072, GPUMemHBM2e, 8192, 3277, 600, 52.4,
                    104.8,
                    GPUFeatureFP16 | GPUFeatureBF16 | GPUFeatureFP64 |
                        GPUFeatureINT8 | GPUFeatureOneAPI | GPUFeatureOpenCL,
                    GPUSegmentDatacenter, @"OneAPI/OpenCL/SYCL")];

  // ========== Apple GPUs ==========
  [_gpuDatabase
      addObject:GPU(@"Apple M4 Max GPU (40-core)", @"M4Max", GPUVendorApple,
                    GPUArchApple_G15X, 2024, 3, 5120, 0, 0, 0, 0, 0, 1398, 0,
                    GPUMemUnifiedMemory, 0, 546, 0, 17.4, 34.8, APPLE_GPU,
                    GPUSegmentIntegrated, @"Metal3.2")];
  [_gpuDatabase
      addObject:GPU(@"Apple M4 Pro GPU (20-core)", @"M4Pro", GPUVendorApple,
                    GPUArchApple_G15, 2024, 3, 2560, 0, 0, 0, 0, 0, 1398, 0,
                    GPUMemUnifiedMemory, 0, 273, 0, 8.7, 17.4, APPLE_GPU,
                    GPUSegmentIntegrated, @"Metal3.2")];
  [_gpuDatabase addObject:GPU(@"Apple M4 GPU (10-core)", @"M4", GPUVendorApple,
                              GPUArchApple_G15, 2024, 3, 1280, 0, 0, 0, 0, 0,
                              1398, 0, GPUMemUnifiedMemory, 0, 120, 0, 4.6, 9.2,
                              APPLE_GPU, GPUSegmentIntegrated, @"Metal3.2")];
  [_gpuDatabase
      addObject:GPU(@"Apple M3 Max GPU (40-core)", @"M3Max", GPUVendorApple,
                    GPUArchApple_G14, 2023, 3, 5120, 0, 0, 0, 0, 0, 1368, 0,
                    GPUMemUnifiedMemory, 0, 410, 0, 14.2, 28.4, APPLE_GPU,
                    GPUSegmentIntegrated, @"Metal3")];
  [_gpuDatabase addObject:GPU(@"Apple M3 GPU (10-core)", @"M3", GPUVendorApple,
                              GPUArchApple_G14, 2023, 3, 1280, 0, 0, 0, 0, 0,
                              1368, 0, GPUMemUnifiedMemory, 0, 100, 0, 3.5, 7.0,
                              APPLE_GPU, GPUSegmentIntegrated, @"Metal3")];
  [_gpuDatabase
      addObject:GPU(@"Apple M2 Ultra GPU (76-core)", @"M2Ultra", GPUVendorApple,
                    GPUArchApple_G14, 2023, 5, 9728, 0, 0, 0, 0, 0, 1398, 0,
                    GPUMemUnifiedMemory, 0, 800, 0, 27.2, 54.4, APPLE_GPU,
                    GPUSegmentIntegrated, @"Metal3")];
  [_gpuDatabase
      addObject:GPU(@"Apple M2 Max GPU (38-core)", @"M2Max", GPUVendorApple,
                    GPUArchApple_G14, 2023, 5, 4864, 0, 0, 0, 0, 0, 1398, 0,
                    GPUMemUnifiedMemory, 0, 400, 0, 13.6, 27.2, APPLE_GPU,
                    GPUSegmentIntegrated, @"Metal3")];
  [_gpuDatabase
      addObject:GPU(@"Apple M1 Ultra GPU (64-core)", @"M1Ultra", GPUVendorApple,
                    GPUArchApple_G13, 2022, 5, 8192, 0, 0, 0, 0, 0, 1296, 0,
                    GPUMemUnifiedMemory, 0, 800, 0, 21.2, 42.4,
                    APPLE_GPU & ~GPUFeatureRayTracing, GPUSegmentIntegrated,
                    @"Metal3")];

  // ========== Qualcomm Adreno ==========
  [_gpuDatabase
      addObject:GPU(@"Qualcomm Adreno X1-85", @"X1-85", GPUVendorQualcomm,
                    GPUArchAdreno_X1, 2024, 4, 0, 0, 0, 0, 0, 0, 1500, 0,
                    GPUMemLPDDR5X, 0, 135, 0, 4.6, 9.2,
                    MOBILE_GPU | GPUFeatureRayTracing | GPUFeatureVulkan,
                    GPUSegmentMobile, @"Vulkan1.3/OpenGL ES3.2/DX12")];
  [_gpuDatabase addObject:GPU(@"Qualcomm Adreno 750", @"Adreno750",
                              GPUVendorQualcomm, GPUArchAdreno_750, 2023, 4, 0,
                              0, 0, 0, 0, 0, 903, 0, GPUMemLPDDR5X, 0, 77, 0,
                              3.8, 7.6, MOBILE_GPU | GPUFeatureRayTracing,
                              GPUSegmentMobile, @"Vulkan1.3/OpenGL ES3.2")];
  [_gpuDatabase addObject:GPU(@"Qualcomm Adreno 740", @"Adreno740",
                              GPUVendorQualcomm, GPUArchAdreno_700, 2022, 4, 0,
                              0, 0, 0, 0, 0, 680, 0, GPUMemLPDDR5X, 0, 51, 0,
                              2.8, 5.6, MOBILE_GPU | GPUFeatureRayTracing,
                              GPUSegmentMobile, @"Vulkan1.3/OpenGL ES3.2")];

  // ========== ARM Mali ==========
  [_gpuDatabase addObject:GPU(@"ARM Mali-G720 MC12", @"G720", GPUVendorARM,
                              GPUArchMali_G720, 2023, 4, 0, 0, 0, 0, 0, 0, 850,
                              0, GPUMemLPDDR5, 0, 51, 0, 2.1, 4.2,
                              MOBILE_GPU | GPUFeatureRayTracing,
                              GPUSegmentMobile, @"Vulkan1.3/OpenGL ES3.2")];
  [_gpuDatabase addObject:GPU(@"ARM Mali-G715 MC10", @"G715", GPUVendorARM,
                              GPUArchMali_G700, 2022, 4, 0, 0, 0, 0, 0, 0, 750,
                              0, GPUMemLPDDR5, 0, 44, 0, 1.5, 3.0,
                              MOBILE_GPU | GPUFeatureRayTracing,
                              GPUSegmentMobile, @"Vulkan1.2/OpenGL ES3.2")];
  [_gpuDatabase
      addObject:GPU(@"ARM Immortalis-G925", @"5thGen", GPUVendorARM,
                    GPUArchMali_5thGen, 2024, 3, 0, 0, 0, 0, 0, 0, 1000, 0,
                    GPUMemLPDDR5X, 0, 60, 0, 3.0, 6.0,
                    MOBILE_GPU | GPUFeatureRayTracing | GPUFeatureMeshShaders,
                    GPUSegmentMobile, @"Vulkan1.3/OpenGL ES3.2")];

  // ========== Samsung Xclipse ==========
  [_gpuDatabase addObject:GPU(@"Samsung Xclipse 940", @"Xclipse940",
                              GPUVendorSamsung, GPUArchXclipse_940, 2024, 4, 0,
                              0, 0, 0, 0, 0, 900, 0, GPUMemLPDDR5X, 0, 51, 0,
                              2.2, 4.4, MOBILE_GPU | GPUFeatureRayTracing,
                              GPUSegmentMobile, @"Vulkan1.3/OpenGL ES3.2")];

  // ========== Imagination Technologies ==========
  [_gpuDatabase addObject:GPU(@"Imagination IMG DXT (48-core)", @"DXT-48",
                              GPUVendorImaginationTech, GPUArchImgDXT, 2023, 5,
                              0, 0, 0, 0, 0, 0, 1000, 0, GPUMemLPDDR5, 0, 40, 0,
                              1.0, 2.0, MOBILE_GPU | GPUFeatureRayTracing,
                              GPUSegmentMobile, @"Vulkan1.3/OpenGL ES3.2")];
}

// ========== QUERIES ==========

- (NSArray<GPUModelDefinition *> *)allGPUs {
  return [_gpuDatabase copy];
}

- (NSArray<GPUModelDefinition *> *)gpusForVendor:(GPUVendor)vendor {
  NSMutableArray *r = [NSMutableArray array];
  for (GPUModelDefinition *g in _gpuDatabase)
    if (g.vendor == vendor)
      [r addObject:g];
  return r;
}
- (NSArray<GPUModelDefinition *> *)gpusForArchitecture:(GPUArchFamily)arch {
  NSMutableArray *r = [NSMutableArray array];
  for (GPUModelDefinition *g in _gpuDatabase)
    if (g.architecture == arch)
      [r addObject:g];
  return r;
}
- (NSArray<GPUModelDefinition *> *)gpusForSegment:(GPUSegment)segment {
  NSMutableArray *r = [NSMutableArray array];
  for (GPUModelDefinition *g in _gpuDatabase)
    if (g.segment == segment)
      [r addObject:g];
  return r;
}
- (GPUModelDefinition *)gpuByName:(NSString *)name {
  for (GPUModelDefinition *g in _gpuDatabase)
    if ([g.name isEqualToString:name])
      return g;
  return nil;
}

- (GPUModelDefinition *)detectCurrentGPU {
  // On macOS, get GPU name from IOKit
  io_iterator_t iterator;
  if (IOServiceGetMatchingServices(kIOMainPortDefault,
                                   IOServiceMatching("IOPCIDevice"),
                                   &iterator) == KERN_SUCCESS) {
    io_object_t device;
    while ((device = IOIteratorNext(iterator)) != IO_OBJECT_NULL) {
      CFMutableDictionaryRef props = NULL;
      if (IORegistryEntryCreateCFProperties(device, &props, kCFAllocatorDefault,
                                            0) == KERN_SUCCESS &&
          props) {
        NSDictionary *dict = (__bridge_transfer NSDictionary *)props;
        NSString *model = [[NSString alloc] initWithData:dict[@"model"]
                                                encoding:NSUTF8StringEncoding];
        if (model) {
          for (GPUModelDefinition *gpu in _gpuDatabase) {
            if ([model containsString:gpu.chip]) {
              IOObjectRelease(device);
              IOObjectRelease(iterator);
              return gpu;
            }
          }
        }
      }
      IOObjectRelease(device);
    }
    IOObjectRelease(iterator);
  }
// Fallback: return Apple GPU for Apple Silicon
#if __arm64__
  for (GPUModelDefinition *gpu in _gpuDatabase) {
    if (gpu.vendor == GPUVendorApple)
      return gpu;
  }
#endif
  return nil;
}

- (NSString *)vendorName:(GPUVendor)vendor {
  switch (vendor) {
  case GPUVendorNVIDIA:
    return @"NVIDIA";
  case GPUVendorAMD:
    return @"AMD";
  case GPUVendorIntel:
    return @"Intel";
  case GPUVendorApple:
    return @"Apple";
  case GPUVendorQualcomm:
    return @"Qualcomm";
  case GPUVendorARM:
    return @"ARM";
  case GPUVendorImaginationTech:
    return @"Imagination";
  case GPUVendorSamsung:
    return @"Samsung";
  default:
    return @"Unknown";
  }
}

- (NSString *)architectureName:(GPUArchFamily)arch {
  NSDictionary *names = @{
    @(GPUArchNV_Blackwell) : @"Blackwell",
    @(GPUArchNV_Ada) : @"Ada Lovelace",
    @(GPUArchNV_Hopper) : @"Hopper",
    @(GPUArchNV_Ampere) : @"Ampere",
    @(GPUArchNV_Turing) : @"Turing",
    @(GPUArchAMD_RDNA4) : @"RDNA 4",
    @(GPUArchAMD_RDNA3) : @"RDNA 3",
    @(GPUArchAMD_RDNA2) : @"RDNA 2",
    @(GPUArchAMD_CDNA3) : @"CDNA 3",
    @(GPUArchAMD_CDNA2) : @"CDNA 2",
    @(GPUArchIntel_Xe2_HPG) : @"Xe2 (Battlemage)",
    @(GPUArchIntel_Xe_HPG) : @"Xe-HPG (Alchemist)",
    @(GPUArchIntel_Xe_HPC) : @"Xe-HPC",
    @(GPUArchApple_G15X) : @"Apple G15X",
    @(GPUArchApple_G15) : @"Apple G15",
    @(GPUArchApple_G14) : @"Apple G14",
    @(GPUArchApple_G13) : @"Apple G13",
    @(GPUArchAdreno_X1) : @"Adreno X1",
    @(GPUArchAdreno_750) : @"Adreno 750",
    @(GPUArchMali_G720) : @"Mali-G720",
    @(GPUArchMali_5thGen) : @"ARM 5th Gen",
    @(GPUArchXclipse_940) : @"Xclipse 940"
  };
  return names[@(arch)] ?: @"Unknown";
}

- (NSArray<NSString *> *)featureListForFlags:(GPUFeatureFlags)flags {
  NSMutableArray *list = [NSMutableArray array];
  struct {
    GPUFeatureFlags f;
    NSString *n;
  } map[] = {{GPUFeatureRayTracing, @"Ray Tracing"},
             {GPUFeatureMeshShaders, @"Mesh Shaders"},
             {GPUFeatureVRS, @"VRS"},
             {GPUFeatureDLSS, @"DLSS"},
             {GPUFeatureFSR, @"FSR"},
             {GPUFeatureXeSS, @"XeSS"},
             {GPUFeatureMetalFX, @"MetalFX"},
             {GPUFeatureTensorCores, @"Tensor Cores"},
             {GPUFeatureMatrixCores, @"Matrix Cores"},
             {GPUFeatureFP16, @"FP16"},
             {GPUFeatureBF16, @"BF16"},
             {GPUFeatureFP64, @"FP64"},
             {GPUFeatureINT8, @"INT8"},
             {GPUFeatureINT4, @"INT4"},
             {GPUFeatureCUDA, @"CUDA"},
             {GPUFeatureROCm, @"ROCm"},
             {GPUFeatureOneAPI, @"oneAPI"},
             {GPUFeatureMetal, @"Metal"},
             {GPUFeatureVulkan, @"Vulkan"},
             {GPUFeatureDirectX12, @"DirectX 12"},
             {GPUFeatureNVLink, @"NVLink"},
             {GPUFeatureInfinityFabric, @"Infinity Fabric"},
             {GPUFeatureAV1Encode, @"AV1 Encode"},
             {GPUFeatureAV1Decode, @"AV1 Decode"},
             {GPUFeatureNPU, @"NPU"},
             {GPUFeatureReBAR, @"ReBAR"}};
  for (size_t i = 0; i < sizeof(map) / sizeof(map[0]); i++) {
    if (flags & map[i].f)
      [list addObject:map[i].n];
  }
  return list;
}

- (NSDictionary *)systemGPUInfo {
  GPUModelDefinition *gpu = [self detectCurrentGPU];
  if (!gpu)
    return @{@"error" : @"No GPU detected"};
  return @{
    @"name" : gpu.name,
    @"vendor" : [self vendorName:gpu.vendor],
    @"architecture" : [self architectureName:gpu.architecture],
    @"shader_cores" : @(gpu.shaderCores),
    @"vram_mb" : @(gpu.vramMB),
    @"tflops_fp32" : @(gpu.tflops_fp32),
    @"tdp" : @(gpu.tdpWatts),
    @"features" : [self featureListForFlags:gpu.features]
  };
}

- (NSUInteger)gpuDatabaseCount {
  return _gpuDatabase.count;
}

@end
