#pragma once
#import <Cocoa/Cocoa.h>

// ============================================================================
// UNIVERSAL FILE TYPE ENGINE — Extended formats + Magic Number Detection
// ============================================================================

// Extended file types beyond the base FileSystemManager types
typedef NS_ENUM(NSInteger, UFTExtendedType) {
  // Scientific
  UFTTypeHDF5 = 1000,
  UFTTypeNetCDF,
  UFTTypeFITS,
  UFTTypeROOT,
  UFTTypeMATLAB,
  UFTTypeSAS,
  UFTTypeSPSS,
  UFTTypeStata,
  UFTTypeArff,
  UFTTypeParquet,
  UFTTypeAvro,
  UFTTypeORC,
  UFTTypeFeather,
  UFTTypeProtobuf,
  UFTTypeMsgPack,
  // GIS / Geospatial
  UFTTypeShapefile = 1100,
  UFTTypeGeoJSON,
  UFTTypeKML,
  UFTTypeKMZ,
  UFTTypeGeoTIFF,
  UFTTypeGPX,
  UFTTypeOSM,
  UFTTypeMBTiles,
  UFTTypeGeoPackage,
  UFTTypeWKT,
  UFTTypeTopojson,
  // Medical Imaging
  UFTTypeDICOM = 1200,
  UFTTypeNIfTI,
  UFTTypeMINC,
  UFTTypeAnalyze,
  UFTTypeMHA,
  UFTTypeNRRD,
  UFTTypeVTK_Image,
  // Music Production
  UFTTypeAbletonALS = 1300,
  UFTTypeFLStudio,
  UFTTypeLogicPro,
  UFTTypeReaper,
  UFTTypeCubase,
  UFTTypeProTools,
  UFTTypeVST,
  UFTTypeVST3,
  UFTTypeAU,
  UFTTypeLV2,
  UFTTypeSoundFont,
  UFTTypeSFZ,
  UFTTypeKontakt,
  // Game Development
  UFTTypeUnityAsset = 1400,
  UFTTypeUnityScene,
  UFTTypeUnityPrefab,
  UFTTypeUnrealUAsset,
  UFTTypeUnrealUMap,
  UFTTypeGodotScene,
  UFTTypeGodotResource,
  UFTTypeRPGMaker,
  UFTTypeGameMaker,
  // Machine Learning
  UFTTypeONNX = 1500,
  UFTTypeTFSavedModel,
  UFTTypeTFLite,
  UFTTypePyTorchPT,
  UFTTypePyTorchPTH,
  UFTTypeSafeTensors,
  UFTTypeCoreML,
  UFTTypeGGUF,
  UFTTypeGGML,
  UFTTypeBIN_Model,
  UFTTypePickle,
  UFTTypeJAX,
  // Blockchain
  UFTTypeSolidity = 1600,
  UFTTypeVyper,
  UFTTypeRust_WASM,
  // Simulation
  UFTTypeOpenFOAM = 1650,
  UFTTypeANSYS,
  UFTTypeABAQUS,
  // PCB / Electronics
  UFTTypeGerber = 1700,
  UFTTypeEagle,
  UFTTypeKiCad,
  UFTTypeAltiumPCB,
  UFTTypeLTSpice,
  // Bioinformatics
  UFTTypeFASTA = 1750,
  UFTTypeFASTQ,
  UFTTypeSAM,
  UFTTypeBAM,
  UFTTypeVCF,
  UFTTypeBED,
  UFTTypeGFF,
  UFTTypePDB_Bio,
  // Virtualization/Container
  UFTTypeDockerImage = 1800,
  UFTTypeOCI,
  UFTTypeVagrantBox,
  UFTTypeTerraform,
  UFTTypeHelm,
  UFTTypeKubernetes,
  // DevOps / CI/CD
  UFTTypeJenkinsfile = 1850,
  UFTTypeGitHubActions,
  UFTTypeGitLabCI,
  UFTTypeCircleCI,
  UFTTypeTravisCI,
  // Notebook
  UFTTypeJupyter = 1900,
  UFTTypeRMarkdown,
  UFTTypeQuarto,
  UFTTypePluto,
  UFTTypeObservable,
  // Presentation / Media
  UFTTypeLottie = 1950,
  UFTTypeRive,
  UFTTypeSVGA,
  // Misc new
  UFTTypeWASM = 2000,
  UFTTypeWAT,
  UFTTypeIR_LLVM,
  UFTTypeBitcode,
  UFTTypeDWARF
};

// Magic number (file signature) entry
@interface UFTMagicEntry : NSObject
@property(nonatomic, strong) NSData *signature;
@property(nonatomic, assign) NSUInteger offset;
@property(nonatomic, strong) NSString *mimeType;
@property(nonatomic, strong) NSString *extension;
@property(nonatomic, strong) NSString *fileDescription;
@property(nonatomic, assign) NSInteger fileType;
@end

// MIME database entry
@interface UFTMimeEntry : NSObject
@property(nonatomic, strong) NSString *mimeType;
@property(nonatomic, strong) NSArray<NSString *> *extensions;
@property(nonatomic, strong) NSString *fileDescription;
@property(nonatomic, strong) NSString *category;
@property(nonatomic, assign) BOOL isText;
@property(nonatomic, assign) BOOL isBinary;
@end

// Universal File Type Engine
@interface UniversalFileTypeEngine : NSObject

+ (instancetype)sharedInstance;

// Magic number detection
- (NSString *)detectFileTypeByMagic:(NSString *)filePath;
- (NSString *)detectMimeTypeByMagic:(NSString *)filePath;
- (NSString *)detectMimeTypeByMagicFromData:(NSData *)data;

// MIME database
- (NSString *)mimeTypeForExtension:(NSString *)ext;
- (NSArray<NSString *> *)extensionsForMimeType:(NSString *)mime;
- (NSString *)descriptionForMimeType:(NSString *)mime;
- (NSArray<UFTMimeEntry *> *)allMimeEntries;
- (NSArray<UFTMimeEntry *> *)mimeEntriesForCategory:(NSString *)category;

// Extended file type info
- (NSString *)categoryForExtension:(NSString *)ext;
- (NSString *)iconEmojiForExtension:(NSString *)ext;
- (BOOL)isTextFileExtension:(NSString *)ext;
- (BOOL)isBinaryFileExtension:(NSString *)ext;
- (BOOL)isExecutableExtension:(NSString *)ext;

// Statistics
- (NSUInteger)magicEntryCount;
- (NSUInteger)mimeEntryCount;
- (NSUInteger)totalExtensionCount;

@end
