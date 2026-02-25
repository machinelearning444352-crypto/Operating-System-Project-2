#import <Cocoa/Cocoa.h>

// File Types Enumeration
typedef NS_ENUM(NSInteger, VFSFileType) {
    VFSFileTypeUnknown = 0,
    // Documents
    VFSFileTypeText,
    VFSFileTypeRichText,
    VFSFileTypePDF,
    VFSFileTypeWord,
    VFSFileTypeExcel,
    VFSFileTypePowerPoint,
    VFSFileTypePages,
    VFSFileTypeNumbers,
    VFSFileTypeKeynote,
    // Images
    VFSFileTypeImage,
    VFSFileTypeJPEG,
    VFSFileTypePNG,
    VFSFileTypeGIF,
    VFSFileTypeBMP,
    VFSFileTypeTIFF,
    VFSFileTypeWebP,
    VFSFileTypeSVG,
    VFSFileTypeICO,
    VFSFileTypeHEIC,
    VFSFileTypeRAW,
    VFSFileTypePSD,
    // Audio
    VFSFileTypeAudio,
    VFSFileTypeMP3,
    VFSFileTypeWAV,
    VFSFileTypeAAC,
    VFSFileTypeFLAC,
    VFSFileTypeOGG,
    VFSFileTypeM4A,
    VFSFileTypeAIFF,
    VFSFileTypeMIDI,
    // Video
    VFSFileTypeVideo,
    VFSFileTypeMP4,
    VFSFileTypeMOV,
    VFSFileTypeAVI,
    VFSFileTypeMKV,
    VFSFileTypeWMV,
    VFSFileTypeFLV,
    VFSFileTypeWebM,
    VFSFileTypeM4V,
    VFSFileType3GP,
    // Archives
    VFSFileTypeArchive,
    VFSFileTypeZIP,
    VFSFileTypeRAR,
    VFSFileType7Z,
    VFSFileTypeTAR,
    VFSFileTypeGZ,
    VFSFileTypeBZ2,
    VFSFileTypeXZ,
    VFSFileTypeDMG,
    VFSFileTypeISO,
    // Executables - macOS
    VFSFileTypeApp,
    VFSFileTypePKG,
    VFSFileTypeMPKG,
    // Executables - Windows
    VFSFileTypeEXE,
    VFSFileTypeMSI,
    VFSFileTypeBAT,
    VFSFileTypeCMD,
    VFSFileTypePowerShell,
    // Executables - Linux
    VFSFileTypeDEB,
    VFSFileTypeRPM,
    VFSFileTypeAppImage,
    VFSFileTypeFlatpak,
    VFSFileTypeSnap,
    // Scripts
    VFSFileTypeShellScript,
    VFSFileTypePython,
    VFSFileTypeRuby,
    VFSFileTypePerl,
    VFSFileTypePHP,
    VFSFileTypeLua,
    VFSFileTypeR,
    VFSFileTypeJulia,
    // Web
    VFSFileTypeHTML,
    VFSFileTypeCSS,
    VFSFileTypeJavaScript,
    VFSFileTypeTypeScript,
    VFSFileTypeJSON,
    VFSFileTypeXML,
    VFSFileTypeYAML,
    VFSFileTypeTOML,
    // Programming
    VFSFileTypeC,
    VFSFileTypeCPP,
    VFSFileTypeObjectiveC,
    VFSFileTypeSwift,
    VFSFileTypeJava,
    VFSFileTypeJAR,
    VFSFileTypeKotlin,
    VFSFileTypeScala,
    VFSFileTypeGo,
    VFSFileTypeRust,
    VFSFileTypeCSharp,
    VFSFileTypeFSharp,
    VFSFileTypeVisualBasic,
    VFSFileTypeAssembly,
    VFSFileTypeHaskell,
    VFSFileTypeErlang,
    VFSFileTypeElixir,
    VFSFileTypeClojure,
    VFSFileTypeLisp,
    VFSFileTypeScheme,
    VFSFileTypeProlog,
    VFSFileTypeFortran,
    VFSFileTypeCOBOL,
    VFSFileTypePascal,
    VFSFileTypeD,
    VFSFileTypeNim,
    VFSFileTypeZig,
    VFSFileTypeV,
    VFSFileTypeCrystal,
    // Data
    VFSFileTypeCSV,
    VFSFileTypeTSV,
    VFSFileTypeSQL,
    VFSFileTypeSQLite,
    VFSFileTypeMongoDB,
    // Config
    VFSFileTypeINI,
    VFSFileTypeCONF,
    VFSFileTypePlist,
    VFSFileTypeEnv,
    VFSFileTypeDockerfile,
    VFSFileTypeMakefile,
    VFSFileTypeCMake,
    // Markup
    VFSFileTypeMarkdown,
    VFSFileTypeLaTeX,
    VFSFileTypeRST,
    VFSFileTypeASCIIDoc,
    VFSFileTypeOrg,
    // Fonts
    VFSFileTypeTTF,
    VFSFileTypeOTF,
    VFSFileTypeWOFF,
    VFSFileTypeWOFF2,
    VFSFileTypeEOT,
    // 3D
    VFSFileTypeOBJ,
    VFSFileTypeFBX,
    VFSFileTypeGLTF,
    VFSFileTypeGLB,
    VFSFileTypeSTL,
    VFSFileTypeBLEND,
    VFSFileTypeDAE,
    VFSFileType3DS,
    // CAD
    VFSFileTypeDWG,
    VFSFileTypeDXF,
    VFSFileTypeSTEP,
    VFSFileTypeIGES,
    // Design
    VFSFileTypeSketch,
    VFSFileTypeFigma,
    VFSFileTypeXD,
    VFSFileTypeAI,
    VFSFileTypeEPS,
    VFSFileTypeINDD,
    // eBooks
    VFSFileTypeEPUB,
    VFSFileTypeMOBI,
    VFSFileTypeAZW,
    VFSFileTypeFB2,
    VFSFileTypeDJVU,
    // System
    VFSFileTypeDLL,
    VFSFileTypeSO,
    VFSFileTypeDYLIB,
    VFSFileTypeSYS,
    VFSFileTypeDRV,
    VFSFileTypeKEXT,
    VFSFileTypeFRAMEWORK,
    // Certificates
    VFSFileTypeCER,
    VFSFileTypeCRT,
    VFSFileTypePEM,
    VFSFileTypeKEY,
    VFSFileTypeP12,
    VFSFileTypePFX,
    // Database
    VFSFileTypeDB,
    VFSFileTypeMDB,
    VFSFileTypeACCDB,
    // Virtual Machines
    VFSFileTypeVMDK,
    VFSFileTypeVDI,
    VFSFileTypeVHD,
    VFSFileTypeQCOW2,
    VFSFileTypeOVA,
    VFSFileTypeOVF,
    // Misc
    VFSFileTypeTorrent,
    VFSFileTypeNFO,
    VFSFileTypeSRT,
    VFSFileTypeVTT,
    VFSFileTypeASS,
    VFSFileTypeLOG,
    VFSFileTypeBAK,
    VFSFileTypeTMP,
    VFSFileTypeSWP,
    // Directory
    VFSFileTypeDirectory,
    VFSFileTypeSymlink,
    VFSFileTypeBundle
};

// File Category
typedef NS_ENUM(NSInteger, VFSFileCategory) {
    VFSFileCategoryUnknown = 0,
    VFSFileCategoryDocument,
    VFSFileCategoryImage,
    VFSFileCategoryAudio,
    VFSFileCategoryVideo,
    VFSFileCategoryArchive,
    VFSFileCategoryExecutable,
    VFSFileCategoryScript,
    VFSFileCategoryCode,
    VFSFileCategoryData,
    VFSFileCategoryConfig,
    VFSFileCategoryFont,
    VFSFileCategory3D,
    VFSFileCategoryDesign,
    VFSFileCategoryEBook,
    VFSFileCategorySystem,
    VFSFileCategoryDirectory
};

// Platform Type
typedef NS_ENUM(NSInteger, VFSPlatformType) {
    VFSPlatformUniversal = 0,
    VFSPlatformMacOS,
    VFSPlatformWindows,
    VFSPlatformLinux,
    VFSPlatformAndroid,
    VFSPlatformiOS,
    VFSPlatformWeb,
    VFSPlatformCrossPlatform
};

// File Permissions
typedef NS_OPTIONS(NSUInteger, VFSFilePermissions) {
    VFSFilePermissionNone      = 0,
    VFSFilePermissionRead      = 1 << 0,
    VFSFilePermissionWrite     = 1 << 1,
    VFSFilePermissionExecute   = 1 << 2,
    VFSFilePermissionOwnerRead = 1 << 3,
    VFSFilePermissionOwnerWrite = 1 << 4,
    VFSFilePermissionOwnerExecute = 1 << 5,
    VFSFilePermissionGroupRead = 1 << 6,
    VFSFilePermissionGroupWrite = 1 << 7,
    VFSFilePermissionGroupExecute = 1 << 8,
    VFSFilePermissionOtherRead = 1 << 9,
    VFSFilePermissionOtherWrite = 1 << 10,
    VFSFilePermissionOtherExecute = 1 << 11,
    VFSFilePermissionSetUID    = 1 << 12,
    VFSFilePermissionSetGID    = 1 << 13,
    VFSFilePermissionSticky    = 1 << 14
};

// Transfer Status
typedef NS_ENUM(NSInteger, VFSTransferStatus) {
    VFSTransferStatusPending = 0,
    VFSTransferStatusPreparing,
    VFSTransferStatusTransferring,
    VFSTransferStatusProcessing,
    VFSTransferStatusCompleted,
    VFSTransferStatusFailed,
    VFSTransferStatusCancelled,
    VFSTransferStatusPaused
};

// Execution Result
typedef NS_ENUM(NSInteger, VFSExecutionResult) {
    VFSExecutionResultSuccess = 0,
    VFSExecutionResultFailed,
    VFSExecutionResultPermissionDenied,
    VFSExecutionResultFileNotFound,
    VFSExecutionResultInvalidFormat,
    VFSExecutionResultUnsupportedPlatform,
    VFSExecutionResultMissingDependency,
    VFSExecutionResultCrashed,
    VFSExecutionResultTimeout,
    VFSExecutionResultUserCancelled
};

@class VFSFile;
@class VFSTransferOperation;
@class VFSExecutionContext;

// Delegate Protocols
@protocol VFSTransferDelegate <NSObject>
@optional
- (void)transferDidStart:(VFSTransferOperation *)operation;
- (void)transfer:(VFSTransferOperation *)operation didUpdateProgress:(double)progress;
- (void)transfer:(VFSTransferOperation *)operation didUpdateSpeed:(NSUInteger)bytesPerSecond;
- (void)transferDidComplete:(VFSTransferOperation *)operation;
- (void)transfer:(VFSTransferOperation *)operation didFailWithError:(NSError *)error;
- (void)transferDidCancel:(VFSTransferOperation *)operation;
@end

@protocol VFSExecutionDelegate <NSObject>
@optional
- (void)executionDidStart:(VFSExecutionContext *)context;
- (void)execution:(VFSExecutionContext *)context didOutputText:(NSString *)text;
- (void)execution:(VFSExecutionContext *)context didOutputError:(NSString *)error;
- (void)executionDidComplete:(VFSExecutionContext *)context withResult:(VFSExecutionResult)result;
@end

// VFS File Object
@interface VFSFile : NSObject

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *virtualPath;
@property (nonatomic, strong) NSString *storagePath;
@property (nonatomic, strong) NSString *originalPath;
@property (nonatomic, assign) VFSFileType fileType;
@property (nonatomic, assign) VFSFileCategory category;
@property (nonatomic, assign) VFSPlatformType platform;
@property (nonatomic, assign) VFSFilePermissions permissions;
@property (nonatomic, assign) BOOL isDirectory;
@property (nonatomic, assign) BOOL isSymlink;
@property (nonatomic, assign) BOOL isHidden;
@property (nonatomic, assign) BOOL isReadOnly;
@property (nonatomic, assign) BOOL isExecutable;
@property (nonatomic, assign) BOOL isSystem;
@property (nonatomic, assign) NSUInteger size;
@property (nonatomic, strong) NSDate *createdDate;
@property (nonatomic, strong) NSDate *modifiedDate;
@property (nonatomic, strong) NSDate *accessedDate;
@property (nonatomic, strong) NSString *mimeType;
@property (nonatomic, strong) NSString *fileExtension;
@property (nonatomic, strong) NSString *fileUTI;
@property (nonatomic, strong) NSString *checksum;
@property (nonatomic, strong) NSString *owner;
@property (nonatomic, strong) NSString *group;
@property (nonatomic, strong) NSDictionary *metadata;
@property (nonatomic, strong) NSDictionary *extendedAttributes;
@property (nonatomic, strong) NSImage *icon;
@property (nonatomic, strong) NSImage *thumbnail;
@property (nonatomic, strong) NSString *symlinkTarget;
@property (nonatomic, strong) NSArray<VFSFile *> *children;
@property (nonatomic, weak) VFSFile *parent;

+ (instancetype)fileWithPath:(NSString *)path;
+ (instancetype)fileWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)toDictionary;
- (NSString *)formattedSize;
- (NSString *)formattedDate;
- (NSString *)iconEmoji;
- (BOOL)isRunnable;
- (BOOL)isViewable;
- (BOOL)isEditable;

@end

// Transfer Operation
@interface VFSTransferOperation : NSObject

@property (nonatomic, strong) NSString *operationID;
@property (nonatomic, strong) VFSFile *sourceFile;
@property (nonatomic, strong) NSString *sourcePath;
@property (nonatomic, strong) NSString *destinationPath;
@property (nonatomic, assign) VFSTransferStatus status;
@property (nonatomic, assign) NSUInteger totalBytes;
@property (nonatomic, assign) NSUInteger transferredBytes;
@property (nonatomic, assign) double progress;
@property (nonatomic, assign) NSUInteger bytesPerSecond;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) NSDate *endTime;
@property (nonatomic, strong) NSError *error;
@property (nonatomic, assign) BOOL isUpload;
@property (nonatomic, assign) BOOL isCancelled;
@property (nonatomic, assign) BOOL isPaused;
@property (nonatomic, weak) id<VFSTransferDelegate> delegate;

- (void)start;
- (void)pause;
- (void)resume;
- (void)cancel;
- (NSTimeInterval)elapsedTime;
- (NSTimeInterval)estimatedTimeRemaining;
- (NSString *)formattedSpeed;
- (NSString *)formattedProgress;

@end

// Execution Context
@interface VFSExecutionContext : NSObject

@property (nonatomic, strong) NSString *contextID;
@property (nonatomic, strong) VFSFile *file;
@property (nonatomic, strong) NSString *command;
@property (nonatomic, strong) NSArray<NSString *> *arguments;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *environment;
@property (nonatomic, strong) NSString *workingDirectory;
@property (nonatomic, strong) NSString *interpreter;
@property (nonatomic, strong) NSMutableString *standardOutput;
@property (nonatomic, strong) NSMutableString *standardError;
@property (nonatomic, assign) int exitCode;
@property (nonatomic, assign) VFSExecutionResult result;
@property (nonatomic, assign) BOOL isRunning;
@property (nonatomic, assign) BOOL usesEmulation;
@property (nonatomic, assign) VFSPlatformType targetPlatform;
@property (nonatomic, strong) NSDate *startTime;
@property (nonatomic, strong) NSDate *endTime;
@property (nonatomic, weak) id<VFSExecutionDelegate> delegate;
@property (nonatomic, strong) NSTask *task;
@property (nonatomic, strong) NSPipe *outputPipe;
@property (nonatomic, strong) NSPipe *errorPipe;
@property (nonatomic, strong) NSPipe *inputPipe;

- (void)execute;
- (void)terminate;
- (void)sendInput:(NSString *)input;
- (NSTimeInterval)runningTime;

@end

// File System Manager
@interface FileSystemManager : NSObject

@property (nonatomic, strong, readonly) NSString *virtualRootPath;
@property (nonatomic, strong, readonly) NSString *storagePath;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, VFSFile *> *fileIndex;
@property (nonatomic, strong, readonly) NSMutableArray<VFSTransferOperation *> *activeTransfers;
@property (nonatomic, strong, readonly) NSMutableArray<VFSExecutionContext *> *runningProcesses;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSArray *> *virtualFileSystem;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSDictionary *> *fileTypeHandlers;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSString *> *mimeTypeMap;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, NSString *> *interpreterMap;

+ (instancetype)sharedInstance;

// File System Operations
- (VFSFile *)fileAtPath:(NSString *)path;
- (NSArray<VFSFile *> *)filesInDirectory:(NSString *)path;
- (BOOL)fileExistsAtPath:(NSString *)path;
- (BOOL)isDirectoryAtPath:(NSString *)path;
- (BOOL)createDirectoryAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)deleteFileAtPath:(NSString *)path error:(NSError **)error;
- (BOOL)moveFileAtPath:(NSString *)sourcePath toPath:(NSString *)destPath error:(NSError **)error;
- (BOOL)copyFileAtPath:(NSString *)sourcePath toPath:(NSString *)destPath error:(NSError **)error;
- (BOOL)renameFileAtPath:(NSString *)path toName:(NSString *)newName error:(NSError **)error;
- (NSString *)uniqueNameForFile:(NSString *)name inDirectory:(NSString *)directory;

// Upload Operations
- (VFSTransferOperation *)uploadFileFromURL:(NSURL *)sourceURL 
                              toVirtualPath:(NSString *)destPath 
                                   delegate:(id<VFSTransferDelegate>)delegate;
- (VFSTransferOperation *)uploadFilesFromURLs:(NSArray<NSURL *> *)sourceURLs 
                                toVirtualPath:(NSString *)destPath 
                                     delegate:(id<VFSTransferDelegate>)delegate;
- (VFSTransferOperation *)uploadData:(NSData *)data 
                            withName:(NSString *)name 
                       toVirtualPath:(NSString *)destPath 
                            delegate:(id<VFSTransferDelegate>)delegate;

// Download Operations
- (VFSTransferOperation *)downloadFileAtPath:(NSString *)virtualPath 
                                       toURL:(NSURL *)destURL 
                                    delegate:(id<VFSTransferDelegate>)delegate;
- (VFSTransferOperation *)downloadFilesAtPaths:(NSArray<NSString *> *)virtualPaths 
                                         toURL:(NSURL *)destURL 
                                      delegate:(id<VFSTransferDelegate>)delegate;
- (NSData *)readDataFromFileAtPath:(NSString *)path error:(NSError **)error;

// Execution Operations
- (VFSExecutionContext *)executeFileAtPath:(NSString *)path 
                             withArguments:(NSArray<NSString *> *)arguments 
                                  delegate:(id<VFSExecutionDelegate>)delegate;
- (VFSExecutionContext *)executeScript:(NSString *)script 
                          withLanguage:(NSString *)language 
                              delegate:(id<VFSExecutionDelegate>)delegate;
- (BOOL)canExecuteFileAtPath:(NSString *)path;
- (NSString *)interpreterForFileType:(VFSFileType)fileType;
- (VFSPlatformType)platformForFileAtPath:(NSString *)path;

// File Type Operations
- (VFSFileType)fileTypeForExtension:(NSString *)extension;
- (VFSFileCategory)categoryForFileType:(VFSFileType)type;
- (NSString *)mimeTypeForExtension:(NSString *)extension;
- (NSString *)extensionForMimeType:(NSString *)mimeType;
- (NSImage *)iconForFileType:(VFSFileType)type;
- (NSString *)emojiForFileType:(VFSFileType)type;
- (NSString *)descriptionForFileType:(VFSFileType)type;
- (BOOL)isExecutableFileType:(VFSFileType)type;
- (BOOL)isViewableFileType:(VFSFileType)type;
- (BOOL)isEditableFileType:(VFSFileType)type;

// Search Operations
- (NSArray<VFSFile *> *)searchFilesWithQuery:(NSString *)query inPath:(NSString *)path;
- (NSArray<VFSFile *> *)searchFilesWithPredicate:(NSPredicate *)predicate inPath:(NSString *)path;
- (NSArray<VFSFile *> *)recentFiles:(NSUInteger)count;
- (NSArray<VFSFile *> *)filesWithExtension:(NSString *)extension inPath:(NSString *)path;
- (NSArray<VFSFile *> *)filesOfCategory:(VFSFileCategory)category inPath:(NSString *)path;

// Metadata Operations
- (NSDictionary *)metadataForFileAtPath:(NSString *)path;
- (BOOL)setMetadata:(NSDictionary *)metadata forFileAtPath:(NSString *)path error:(NSError **)error;
- (NSString *)checksumForFileAtPath:(NSString *)path algorithm:(NSString *)algorithm;
- (NSDictionary *)extendedAttributesForFileAtPath:(NSString *)path;
- (BOOL)setExtendedAttribute:(NSString *)name value:(NSData *)value forFileAtPath:(NSString *)path error:(NSError **)error;

// Thumbnail & Preview
- (NSImage *)thumbnailForFileAtPath:(NSString *)path size:(NSSize)size;
- (NSData *)previewDataForFileAtPath:(NSString *)path;
- (NSString *)textPreviewForFileAtPath:(NSString *)path maxLength:(NSUInteger)maxLength;

// Archive Operations
- (BOOL)extractArchiveAtPath:(NSString *)archivePath toPath:(NSString *)destPath error:(NSError **)error;
- (BOOL)createArchiveAtPath:(NSString *)archivePath withFiles:(NSArray<NSString *> *)filePaths format:(NSString *)format error:(NSError **)error;
- (NSArray<NSString *> *)listArchiveContentsAtPath:(NSString *)archivePath;

// Disk Image Operations
- (BOOL)mountDMGAtPath:(NSString *)dmgPath error:(NSError **)error;
- (BOOL)unmountDMGAtPath:(NSString *)dmgPath error:(NSError **)error;
- (BOOL)extractDMGAtPath:(NSString *)dmgPath toPath:(NSString *)destPath error:(NSError **)error;

// Package Operations
- (NSDictionary *)packageInfoForDEBAtPath:(NSString *)debPath;
- (NSDictionary *)packageInfoForRPMAtPath:(NSString *)rpmPath;
- (NSDictionary *)packageInfoForMSIAtPath:(NSString *)msiPath;
- (BOOL)installPackageAtPath:(NSString *)packagePath error:(NSError **)error;

// Persistence
- (void)saveFileSystem;
- (void)loadFileSystem;
- (void)rebuildIndex;
- (NSUInteger)totalStorageUsed;
- (NSUInteger)fileCount;

@end
