#import "UniversalFileTypeEngine.h"

@implementation UFTMagicEntry
- (instancetype)init {
  self = [super init];
  if (self) {
    _signature = nil;
    _offset = 0;
    _mimeType = @"";
    _extension = @"";
    _fileDescription = @"";
    _fileType = 0;
  }
  return self;
}
@end

@implementation UFTMimeEntry
- (instancetype)init {
  self = [super init];
  if (self) {
    _mimeType = @"";
    _extensions = @[];
    _fileDescription = @"";
    _category = @"";
    _isText = NO;
    _isBinary = YES;
  }
  return self;
}
@end

#define MAGIC(off, mime, ext, desc, ...)                                       \
  ({                                                                           \
    UFTMagicEntry *e = [[UFTMagicEntry alloc] init];                           \
    const uint8_t b[] = {__VA_ARGS__};                                         \
    e.signature = [NSData dataWithBytes:b length:sizeof(b)];                   \
    e.offset = off;                                                            \
    e.mimeType = mime;                                                         \
    e.extension = ext;                                                         \
    e.fileDescription = desc;                                                  \
    e;                                                                         \
  })

static inline UFTMimeEntry *MakeMIME(NSString *m, NSArray *exts, NSString *d,
                                     NSString *cat, BOOL txt) {
  UFTMimeEntry *e = [[UFTMimeEntry alloc] init];
  e.mimeType = m;
  e.extensions = exts;
  e.fileDescription = d;
  e.category = cat;
  e.isText = txt;
  e.isBinary = !txt;
  return e;
}

@interface UniversalFileTypeEngine ()
@property(nonatomic, strong) NSArray<UFTMagicEntry *> *magicDatabase;
@property(nonatomic, strong) NSArray<UFTMimeEntry *> *mimeDatabase;
@property(nonatomic, strong)
    NSDictionary<NSString *, UFTMimeEntry *> *extToMime;
@property(nonatomic, strong)
    NSDictionary<NSString *, NSString *> *extToCategory;
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *extToEmoji;
@end

@implementation UniversalFileTypeEngine

+ (instancetype)sharedInstance {
  static UniversalFileTypeEngine *inst;
  static dispatch_once_t t;
  dispatch_once(&t, ^{
    inst = [[self alloc] init];
  });
  return inst;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    [self buildMagicDB];
    [self buildMimeDB];
    [self buildMaps];
  }
  return self;
}

- (void)buildMagicDB {
  _magicDatabase = @[
    // Core formats
    MAGIC(0, @"image/png", @"png", @"PNG Image", 0x89, 0x50, 0x4E, 0x47, 0x0D,
          0x0A, 0x1A, 0x0A),
    MAGIC(0, @"image/jpeg", @"jpg", @"JPEG Image", 0xFF, 0xD8, 0xFF),
    MAGIC(0, @"image/gif", @"gif", @"GIF Image", 0x47, 0x49, 0x46, 0x38),
    MAGIC(0, @"image/bmp", @"bmp", @"BMP Image", 0x42, 0x4D),
    MAGIC(0, @"image/tiff", @"tiff", @"TIFF Image (LE)", 0x49, 0x49, 0x2A,
          0x00),
    MAGIC(0, @"image/tiff", @"tiff", @"TIFF Image (BE)", 0x4D, 0x4D, 0x00,
          0x2A),
    MAGIC(0, @"image/webp", @"webp", @"WebP Image", 0x52, 0x49, 0x46, 0x46),
    MAGIC(0, @"image/x-icon", @"ico", @"ICO Icon", 0x00, 0x00, 0x01, 0x00),
    // Audio
    MAGIC(0, @"audio/mpeg", @"mp3", @"MP3 Audio (ID3)", 0x49, 0x44, 0x33),
    MAGIC(0, @"audio/mpeg", @"mp3", @"MP3 Audio", 0xFF, 0xFB),
    MAGIC(0, @"audio/wav", @"wav", @"WAV Audio", 0x52, 0x49, 0x46, 0x46),
    MAGIC(0, @"audio/flac", @"flac", @"FLAC Audio", 0x66, 0x4C, 0x61, 0x43),
    MAGIC(0, @"audio/ogg", @"ogg", @"Ogg Audio", 0x4F, 0x67, 0x67, 0x53),
    MAGIC(0, @"audio/midi", @"mid", @"MIDI Audio", 0x4D, 0x54, 0x68, 0x64),
    MAGIC(0, @"audio/aiff", @"aiff", @"AIFF Audio", 0x46, 0x4F, 0x52, 0x4D),
    // Video
    MAGIC(0, @"video/x-matroska", @"mkv", @"Matroska Video", 0x1A, 0x45, 0xDF,
          0xA3),
    MAGIC(0, @"video/mp4", @"mp4", @"MP4 Video", 0x00, 0x00, 0x00, 0x1C, 0x66,
          0x74, 0x79, 0x70),
    MAGIC(0, @"video/x-flv", @"flv", @"Flash Video", 0x46, 0x4C, 0x56, 0x01),
    MAGIC(0, @"video/x-ms-wmv", @"wmv", @"WMV Video", 0x30, 0x26, 0xB2, 0x75),
    // Documents
    MAGIC(0, @"application/pdf", @"pdf", @"PDF Document", 0x25, 0x50, 0x44,
          0x46),
    MAGIC(0, @"application/zip", @"zip", @"ZIP Archive / Office Doc", 0x50,
          0x4B, 0x03, 0x04),
    MAGIC(0, @"application/msword", @"doc", @"MS Office (Legacy)", 0xD0, 0xCF,
          0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1),
    // Archives
    MAGIC(0, @"application/gzip", @"gz", @"Gzip Archive", 0x1F, 0x8B, 0x08),
    MAGIC(0, @"application/x-bzip2", @"bz2", @"Bzip2 Archive", 0x42, 0x5A,
          0x68),
    MAGIC(0, @"application/x-xz", @"xz", @"XZ Archive", 0xFD, 0x37, 0x7A, 0x58,
          0x5A, 0x00),
    MAGIC(0, @"application/x-rar", @"rar", @"RAR Archive", 0x52, 0x61, 0x72,
          0x21, 0x1A, 0x07),
    MAGIC(0, @"application/x-7z-compressed", @"7z", @"7-Zip Archive", 0x37,
          0x7A, 0xBC, 0xAF, 0x27, 0x1C),
    MAGIC(257, @"application/x-tar", @"tar", @"TAR Archive", 0x75, 0x73, 0x74,
          0x61, 0x72),
    MAGIC(0, @"application/zstd", @"zst", @"Zstandard Archive", 0x28, 0xB5,
          0x2F, 0xFD),
    MAGIC(0, @"application/x-lz4", @"lz4", @"LZ4 Archive", 0x04, 0x22, 0x4D,
          0x18),
    // Executables
    MAGIC(0, @"application/x-elf", @"elf", @"ELF Executable", 0x7F, 0x45, 0x4C,
          0x46),
    MAGIC(0, @"application/x-dosexec", @"exe", @"PE Executable", 0x4D, 0x5A),
    MAGIC(0, @"application/x-mach-binary", @"macho", @"Mach-O 32-bit", 0xCE,
          0xFA, 0xED, 0xFE),
    MAGIC(0, @"application/x-mach-binary", @"macho", @"Mach-O 64-bit", 0xCF,
          0xFA, 0xED, 0xFE),
    MAGIC(0, @"application/x-mach-binary", @"macho", @"Mach-O Universal", 0xCA,
          0xFE, 0xBA, 0xBE),
    MAGIC(0, @"application/java-archive", @"jar", @"Java class/JAR", 0xCA, 0xFE,
          0xD0, 0x0D),
    // Database
    MAGIC(0, @"application/x-sqlite3", @"sqlite", @"SQLite Database", 0x53,
          0x51, 0x4C, 0x69, 0x74, 0x65),
    // Fonts
    MAGIC(0, @"font/ttf", @"ttf", @"TrueType Font", 0x00, 0x01, 0x00, 0x00),
    MAGIC(0, @"font/otf", @"otf", @"OpenType Font", 0x4F, 0x54, 0x54, 0x4F),
    MAGIC(0, @"font/woff", @"woff", @"WOFF Font", 0x77, 0x4F, 0x46, 0x46),
    MAGIC(0, @"font/woff2", @"woff2", @"WOFF2 Font", 0x77, 0x4F, 0x46, 0x32),
    // 3D
    MAGIC(0, @"model/gltf-binary", @"glb", @"glTF Binary", 0x67, 0x6C, 0x54,
          0x46),
    MAGIC(0, @"application/x-fbx", @"fbx", @"FBX 3D Model", 0x46, 0x42, 0x58),
    MAGIC(0, @"application/x-blender", @"blend", @"Blender File", 0x42, 0x4C,
          0x45, 0x4E, 0x44, 0x45, 0x52),
    // Scientific
    MAGIC(0, @"application/x-hdf5", @"hdf5", @"HDF5 Data", 0x89, 0x48, 0x44,
          0x46),
    MAGIC(0, @"application/x-netcdf", @"nc", @"NetCDF Classic", 0x43, 0x44,
          0x46, 0x01),
    MAGIC(0, @"application/x-netcdf", @"nc", @"NetCDF 64-bit", 0x43, 0x44, 0x46,
          0x02),
    MAGIC(0, @"application/fits", @"fits", @"FITS Astronomical", 0x53, 0x49,
          0x4D, 0x50, 0x4C, 0x45),
    // ML Models
    MAGIC(0, @"application/x-onnx", @"onnx", @"ONNX Model", 0x08, 0x00, 0x00,
          0x00),
    MAGIC(0, @"application/x-pickle", @"pkl", @"Python Pickle", 0x80, 0x02),
    // WebAssembly
    MAGIC(0, @"application/wasm", @"wasm", @"WebAssembly", 0x00, 0x61, 0x73,
          0x6D),
    // Medical
    MAGIC(128, @"application/dicom", @"dcm", @"DICOM Medical Image", 0x44, 0x49,
          0x43, 0x4D),
    // Bioinformatics
    MAGIC(0, @"application/x-bam", @"bam", @"BAM Alignment", 0x42, 0x41, 0x4D,
          0x01),
    MAGIC(0, @"application/x-bcf", @"bcf", @"BCF Variant", 0x42, 0x43, 0x02),
    // Containers/Disk Images
    MAGIC(0, @"application/x-xar", @"xar", @"XAR Archive (pkg)", 0x78, 0x61,
          0x72, 0x21),
    MAGIC(0, @"application/x-apple-diskimage", @"dmg", @"Apple DMG", 0x4B, 0x44,
          0x4D),
    // Game
    MAGIC(0, @"application/x-unity", @"assets", @"Unity Asset Bundle", 0x55,
          0x6E, 0x69, 0x74, 0x79, 0x46, 0x53),
    // PCB
    MAGIC(0, @"application/x-gerber", @"gbr", @"Gerber PCB", 0x47, 0x30, 0x34),
  ];
}

- (void)buildMimeDB {
  _mimeDatabase = @[
    // Documents
    MakeMIME(@"text/plain", @[ @"txt", @"text", @"log", @"cfg", @"conf", @"ini" ],
         @"Plain Text", @"document", YES),
    MakeMIME(@"text/html", @[ @"html", @"htm", @"xhtml" ], @"HTML Document", @"web",
         YES),
    MakeMIME(@"text/css", @[ @"css", @"scss", @"sass", @"less" ], @"CSS Stylesheet",
         @"web", YES),
    MakeMIME(@"text/javascript", @[ @"js", @"mjs", @"cjs" ], @"JavaScript", @"code",
         YES),
    MakeMIME(@"application/json", @[ @"json", @"jsonl", @"geojson" ], @"JSON Data",
         @"data", YES),
    MakeMIME(@"application/xml", @[ @"xml", @"xsd", @"xsl", @"xslt", @"svg" ],
         @"XML Document", @"data", YES),
    MakeMIME(@"text/yaml", @[ @"yml", @"yaml" ], @"YAML Data", @"data", YES),
    MakeMIME(@"text/markdown", @[ @"md", @"markdown", @"mdown" ], @"Markdown",
         @"document", YES),
    MakeMIME(@"application/pdf", @[ @"pdf" ], @"PDF Document", @"document", NO),
    MakeMIME(@"application/rtf", @[ @"rtf" ], @"Rich Text", @"document", NO),
    MakeMIME(@"application/msword", @[ @"doc" ], @"Word Document", @"document", NO),
    MakeMIME(@"application/"
         @"vnd.openxmlformats-officedocument.wordprocessingml.document",
         @[ @"docx" ], @"Word Document (OOXML)", @"document", NO),
    MakeMIME(@"application/vnd.ms-excel", @[ @"xls" ], @"Excel Spreadsheet",
         @"document", NO),
    MakeMIME(@"application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
         @[ @"xlsx" ], @"Excel Spreadsheet (OOXML)", @"document", NO),
    MakeMIME(@"application/vnd.ms-powerpoint", @[ @"ppt" ],
         @"PowerPoint Presentation", @"document", NO),
    MakeMIME(@"application/"
         @"vnd.openxmlformats-officedocument.presentationml.presentation",
         @[ @"pptx" ], @"PowerPoint (OOXML)", @"document", NO),
    MakeMIME(@"application/epub+zip", @[ @"epub" ], @"EPUB eBook", @"ebook", NO),
    MakeMIME(@"text/csv", @[ @"csv", @"tsv" ], @"CSV Data", @"data", YES),
    MakeMIME(@"application/sql", @[ @"sql" ], @"SQL Script", @"data", YES),
    MakeMIME(@"text/x-latex", @[ @"tex", @"latex", @"sty", @"cls" ],
         @"LaTeX Document", @"document", YES),
    MakeMIME(@"text/x-rst", @[ @"rst" ], @"reStructuredText", @"document", YES),
    // Images
    MakeMIME(@"image/jpeg", @[ @"jpg", @"jpeg", @"jpe", @"jfif" ], @"JPEG Image",
         @"image", NO),
    MakeMIME(@"image/png", @[ @"png" ], @"PNG Image", @"image", NO),
    MakeMIME(@"image/gif", @[ @"gif" ], @"GIF Image", @"image", NO),
    MakeMIME(@"image/webp", @[ @"webp" ], @"WebP Image", @"image", NO),
    MakeMIME(@"image/svg+xml", @[ @"svg", @"svgz" ], @"SVG Image", @"image", YES),
    MakeMIME(@"image/bmp", @[ @"bmp", @"dib" ], @"BMP Image", @"image", NO),
    MakeMIME(@"image/tiff", @[ @"tif", @"tiff" ], @"TIFF Image", @"image", NO),
    MakeMIME(@"image/x-icon", @[ @"ico", @"cur" ], @"Icon", @"image", NO),
    MakeMIME(@"image/heic", @[ @"heic", @"heif" ], @"HEIC Image", @"image", NO),
    MakeMIME(@"image/avif", @[ @"avif" ], @"AVIF Image", @"image", NO),
    MakeMIME(@"image/jxl", @[ @"jxl" ], @"JPEG XL Image", @"image", NO),
    MakeMIME(@"image/vnd.adobe.photoshop", @[ @"psd", @"psb" ],
         @"Photoshop Document", @"image", NO),
    MakeMIME(@"image/x-xcf", @[ @"xcf" ], @"GIMP Image", @"image", NO),
    MakeMIME(@"image/x-tga", @[ @"tga" ], @"Targa Image", @"image", NO),
    MakeMIME(@"image/x-exr", @[ @"exr" ], @"OpenEXR Image", @"image", NO),
    MakeMIME(@"image/vnd.dxf", @[ @"dxf" ], @"DXF Drawing", @"cad", YES),
    MakeMIME(@"image/vnd.dwg", @[ @"dwg" ], @"DWG Drawing", @"cad", NO),
    // Audio
    MakeMIME(@"audio/mpeg", @[ @"mp3" ], @"MP3 Audio", @"audio", NO),
    MakeMIME(@"audio/wav", @[ @"wav" ], @"WAV Audio", @"audio", NO),
    MakeMIME(@"audio/aac", @[ @"aac" ], @"AAC Audio", @"audio", NO),
    MakeMIME(@"audio/flac", @[ @"flac" ], @"FLAC Audio", @"audio", NO),
    MakeMIME(@"audio/ogg", @[ @"ogg", @"oga", @"opus" ], @"Ogg Audio", @"audio",
         NO),
    MakeMIME(@"audio/midi", @[ @"mid", @"midi" ], @"MIDI Audio", @"audio", NO),
    MakeMIME(@"audio/x-aiff", @[ @"aiff", @"aif" ], @"AIFF Audio", @"audio", NO),
    MakeMIME(@"audio/mp4", @[ @"m4a", @"m4b" ], @"M4A Audio", @"audio", NO),
    MakeMIME(@"audio/x-ms-wma", @[ @"wma" ], @"WMA Audio", @"audio", NO),
    // Video
    MakeMIME(@"video/mp4", @[ @"mp4", @"m4v" ], @"MP4 Video", @"video", NO),
    MakeMIME(@"video/quicktime", @[ @"mov", @"qt" ], @"QuickTime Video", @"video",
         NO),
    MakeMIME(@"video/x-msvideo", @[ @"avi" ], @"AVI Video", @"video", NO),
    MakeMIME(@"video/x-matroska", @[ @"mkv" ], @"Matroska Video", @"video", NO),
    MakeMIME(@"video/webm", @[ @"webm" ], @"WebM Video", @"video", NO),
    MakeMIME(@"video/x-flv", @[ @"flv" ], @"Flash Video", @"video", NO),
    MakeMIME(@"video/x-ms-wmv", @[ @"wmv" ], @"WMV Video", @"video", NO),
    MakeMIME(@"video/3gpp", @[ @"3gp", @"3gpp" ], @"3GP Video", @"video", NO),
    // Code
    MakeMIME(@"text/x-c", @[ @"c", @"h" ], @"C Source", @"code", YES),
    MakeMIME(@"text/x-c++", @[ @"cpp", @"cxx", @"cc", @"hpp", @"hxx", @"hh" ],
         @"C++ Source", @"code", YES),
    MakeMIME(@"text/x-objc", @[ @"m", @"mm" ], @"Objective-C Source", @"code", YES),
    MakeMIME(@"text/x-swift", @[ @"swift" ], @"Swift Source", @"code", YES),
    MakeMIME(@"text/x-java", @[ @"java" ], @"Java Source", @"code", YES),
    MakeMIME(@"text/x-kotlin", @[ @"kt", @"kts" ], @"Kotlin Source", @"code", YES),
    MakeMIME(@"text/x-python", @[ @"py", @"pyw", @"pyi" ], @"Python Source",
         @"code", YES),
    MakeMIME(@"text/x-ruby", @[ @"rb", @"erb" ], @"Ruby Source", @"code", YES),
    MakeMIME(@"text/x-go", @[ @"go" ], @"Go Source", @"code", YES),
    MakeMIME(@"text/x-rust", @[ @"rs" ], @"Rust Source", @"code", YES),
    MakeMIME(@"text/x-csharp", @[ @"cs" ], @"C# Source", @"code", YES),
    MakeMIME(@"text/x-fsharp", @[ @"fs", @"fsx" ], @"F# Source", @"code", YES),
    MakeMIME(@"text/x-scala", @[ @"scala" ], @"Scala Source", @"code", YES),
    MakeMIME(@"text/x-haskell", @[ @"hs", @"lhs" ], @"Haskell Source", @"code",
         YES),
    MakeMIME(@"text/x-erlang", @[ @"erl", @"hrl" ], @"Erlang Source", @"code", YES),
    MakeMIME(@"text/x-elixir", @[ @"ex", @"exs" ], @"Elixir Source", @"code", YES),
    MakeMIME(@"text/x-clojure", @[ @"clj", @"cljs", @"cljc", @"edn" ],
         @"Clojure Source", @"code", YES),
    MakeMIME(@"text/x-lua", @[ @"lua" ], @"Lua Source", @"code", YES),
    MakeMIME(@"text/x-perl", @[ @"pl", @"pm" ], @"Perl Source", @"code", YES),
    MakeMIME(@"text/x-php", @[ @"php" ], @"PHP Source", @"code", YES),
    MakeMIME(@"text/x-r", @[ @"r", @"R" ], @"R Source", @"code", YES),
    MakeMIME(@"text/x-julia", @[ @"jl" ], @"Julia Source", @"code", YES),
    MakeMIME(@"text/x-zig", @[ @"zig" ], @"Zig Source", @"code", YES),
    MakeMIME(@"text/x-nim", @[ @"nim" ], @"Nim Source", @"code", YES),
    MakeMIME(@"text/x-d", @[ @"d" ], @"D Source", @"code", YES),
    MakeMIME(@"text/x-v", @[ @"v" ], @"V Source", @"code", YES),
    MakeMIME(@"text/x-crystal", @[ @"cr" ], @"Crystal Source", @"code", YES),
    MakeMIME(@"text/x-dart", @[ @"dart" ], @"Dart Source", @"code", YES),
    MakeMIME(@"text/typescript", @[ @"ts", @"tsx" ], @"TypeScript Source", @"code",
         YES),
    MakeMIME(@"text/jsx", @[ @"jsx" ], @"JSX Source", @"code", YES),
    MakeMIME(@"text/x-shellscript", @[ @"sh", @"bash", @"zsh", @"fish" ],
         @"Shell Script", @"code", YES),
    MakeMIME(@"text/x-powershell", @[ @"ps1", @"psm1" ], @"PowerShell Script",
         @"code", YES),
    MakeMIME(@"text/x-fortran", @[ @"f", @"f90", @"f95" ], @"Fortran Source",
         @"code", YES),
    MakeMIME(@"text/x-cobol", @[ @"cob", @"cbl" ], @"COBOL Source", @"code", YES),
    MakeMIME(@"text/x-pascal", @[ @"pas", @"pp" ], @"Pascal Source", @"code", YES),
    MakeMIME(@"text/x-assembly", @[ @"asm", @"s", @"S" ], @"Assembly Source",
         @"code", YES),
    MakeMIME(@"text/x-protobuf", @[ @"proto" ], @"Protobuf Schema", @"data", YES),
    MakeMIME(@"text/x-thrift", @[ @"thrift" ], @"Thrift IDL", @"data", YES),
    MakeMIME(@"text/x-graphql", @[ @"graphql", @"gql" ], @"GraphQL Schema", @"data",
         YES),
    MakeMIME(@"text/x-solidity", @[ @"sol" ], @"Solidity Source", @"code", YES),
    // Archives
    MakeMIME(@"application/zip", @[ @"zip" ], @"ZIP Archive", @"archive", NO),
    MakeMIME(@"application/x-rar-compressed", @[ @"rar" ], @"RAR Archive",
         @"archive", NO),
    MakeMIME(@"application/x-7z-compressed", @[ @"7z" ], @"7-Zip Archive",
         @"archive", NO),
    MakeMIME(@"application/gzip", @[ @"gz", @"gzip" ], @"Gzip Archive", @"archive",
         NO),
    MakeMIME(@"application/x-bzip2", @[ @"bz2" ], @"Bzip2 Archive", @"archive", NO),
    MakeMIME(@"application/x-xz", @[ @"xz" ], @"XZ Archive", @"archive", NO),
    MakeMIME(@"application/x-tar", @[ @"tar" ], @"TAR Archive", @"archive", NO),
    MakeMIME(@"application/zstd", @[ @"zst" ], @"Zstandard Archive", @"archive",
         NO),
    MakeMIME(@"application/x-apple-diskimage", @[ @"dmg" ], @"Apple Disk Image",
         @"archive", NO),
    MakeMIME(@"application/x-iso9660-image", @[ @"iso" ], @"ISO Disk Image",
         @"archive", NO),
    // System
    MakeMIME(@"application/x-executable", @[ @"elf", @"bin" ], @"Executable",
         @"system", NO),
    MakeMIME(@"application/x-dosexec", @[ @"exe", @"dll", @"sys" ],
         @"Windows Executable", @"system", NO),
    MakeMIME(@"application/x-mach-binary", @[ @"dylib", @"so" ], @"Shared Library",
         @"system", NO),
    MakeMIME(@"application/vnd.debian.binary-package", @[ @"deb" ],
         @"Debian Package", @"system", NO),
    MakeMIME(@"application/x-rpm", @[ @"rpm" ], @"RPM Package", @"system", NO),
    MakeMIME(@"application/x-ms-installer", @[ @"msi" ], @"Windows Installer",
         @"system", NO),
    MakeMIME(@"application/vnd.appimage", @[ @"AppImage" ], @"AppImage", @"system",
         NO),
    MakeMIME(@"application/flatpak", @[ @"flatpak" ], @"Flatpak Package", @"system",
         NO),
    MakeMIME(@"application/x-snap", @[ @"snap" ], @"Snap Package", @"system", NO),
    // Fonts
    MakeMIME(@"font/ttf", @[ @"ttf" ], @"TrueType Font", @"font", NO),
    MakeMIME(@"font/otf", @[ @"otf" ], @"OpenType Font", @"font", NO),
    MakeMIME(@"font/woff", @[ @"woff" ], @"WOFF Font", @"font", NO),
    MakeMIME(@"font/woff2", @[ @"woff2" ], @"WOFF2 Font", @"font", NO),
    // 3D Models
    MakeMIME(@"model/gltf+json", @[ @"gltf" ], @"glTF 3D Model", @"3d", YES),
    MakeMIME(@"model/gltf-binary", @[ @"glb" ], @"glTF Binary", @"3d", NO),
    MakeMIME(@"model/obj", @[ @"obj" ], @"Wavefront OBJ", @"3d", YES),
    MakeMIME(@"model/stl", @[ @"stl" ], @"STL 3D Model", @"3d", NO),
    MakeMIME(@"application/x-blender", @[ @"blend" ], @"Blender File", @"3d", NO),
    MakeMIME(@"application/x-fbx", @[ @"fbx" ], @"FBX 3D Model", @"3d", NO),
    MakeMIME(@"model/vnd.collada+xml", @[ @"dae" ], @"COLLADA 3D", @"3d", YES),
    // Scientific
    MakeMIME(@"application/x-hdf5", @[ @"hdf5", @"h5", @"he5" ], @"HDF5 Data",
         @"scientific", NO),
    MakeMIME(@"application/x-netcdf", @[ @"nc", @"nc4", @"cdf" ], @"NetCDF Data",
         @"scientific", NO),
    MakeMIME(@"application/fits", @[ @"fits", @"fit" ], @"FITS Astronomical Data",
         @"scientific", NO),
    MakeMIME(@"application/x-root", @[ @"root" ], @"ROOT Data", @"scientific", NO),
    MakeMIME(@"application/x-matlab-data", @[ @"mat" ], @"MATLAB Data",
         @"scientific", NO),
    MakeMIME(@"application/x-parquet", @[ @"parquet" ], @"Apache Parquet", @"data",
         NO),
    MakeMIME(@"application/x-avro", @[ @"avro" ], @"Apache Avro", @"data", NO),
    // ML
    MakeMIME(@"application/x-onnx", @[ @"onnx" ], @"ONNX Model", @"ml", NO),
    MakeMIME(@"application/x-pytorch", @[ @"pt", @"pth" ], @"PyTorch Model", @"ml",
         NO),
    MakeMIME(@"application/x-safetensors", @[ @"safetensors" ],
         @"SafeTensors Model", @"ml", NO),
    MakeMIME(@"application/x-gguf", @[ @"gguf" ], @"GGUF Model", @"ml", NO),
    MakeMIME(@"application/x-coreml", @[ @"mlmodel", @"mlpackage" ],
         @"Core ML Model", @"ml", NO),
    MakeMIME(@"application/x-tflite", @[ @"tflite" ], @"TensorFlow Lite", @"ml",
         NO),
    // Medical
    MakeMIME(@"application/dicom", @[ @"dcm", @"dicom" ], @"DICOM Medical Image",
         @"medical", NO),
    MakeMIME(@"application/x-nifti", @[ @"nii", @"nii.gz" ], @"NIfTI Neuroimaging",
         @"medical", NO),
    // GIS
    MakeMIME(@"application/geo+json", @[ @"geojson" ], @"GeoJSON Data", @"gis",
         YES),
    MakeMIME(@"application/vnd.google-earth.kml+xml", @[ @"kml" ], @"KML Geodata",
         @"gis", YES),
    MakeMIME(@"application/vnd.google-earth.kmz", @[ @"kmz" ], @"KMZ Geodata",
         @"gis", NO),
    MakeMIME(@"application/gpx+xml", @[ @"gpx" ], @"GPX Track Data", @"gis", YES),
    MakeMIME(@"application/x-shapefile", @[ @"shp" ], @"Shapefile", @"gis", NO),
    MakeMIME(@"image/tiff", @[ @"geotiff" ], @"GeoTIFF", @"gis", NO),
    // Bioinformatics
    MakeMIME(@"text/x-fasta", @[ @"fasta", @"fa", @"fna", @"faa" ],
         @"FASTA Sequence", @"bio", YES),
    MakeMIME(@"text/x-fastq", @[ @"fastq", @"fq" ], @"FASTQ Sequence", @"bio", YES),
    MakeMIME(@"text/x-sam", @[ @"sam" ], @"SAM Alignment", @"bio", YES),
    MakeMIME(@"application/x-bam", @[ @"bam" ], @"BAM Alignment", @"bio", NO),
    MakeMIME(@"text/x-vcf", @[ @"vcf" ], @"VCF Variant", @"bio", YES),
    MakeMIME(@"text/x-bed", @[ @"bed" ], @"BED Genomic Regions", @"bio", YES),
    MakeMIME(@"chemical/x-pdb", @[ @"pdb" ], @"PDB Protein Structure", @"bio", YES),
    // Misc
    MakeMIME(@"application/wasm", @[ @"wasm" ], @"WebAssembly", @"code", NO),
    MakeMIME(@"text/x-wat", @[ @"wat" ], @"WebAssembly Text", @"code", YES),
    MakeMIME(@"application/x-sqlite3", @[ @"sqlite", @"db", @"sqlite3" ],
         @"SQLite Database", @"data", NO),
    MakeMIME(@"application/toml", @[ @"toml" ], @"TOML Config", @"data", YES),
    MakeMIME(@"text/x-ini", @[ @"ini" ], @"INI Config", @"data", YES),
    MakeMIME(@"application/x-plist", @[ @"plist" ], @"Property List", @"data", YES),
    MakeMIME(@"text/x-dockerfile", @[ @"Dockerfile" ], @"Dockerfile", @"devops",
         YES),
    MakeMIME(@"application/x-terraform", @[ @"tf", @"tfvars" ], @"Terraform Config",
         @"devops", YES),
    MakeMIME(@"application/x-jupyter", @[ @"ipynb" ], @"Jupyter Notebook",
         @"notebook", YES),
    MakeMIME(@"text/x-rmarkdown", @[ @"Rmd" ], @"R Markdown", @"notebook", YES),
    MakeMIME(@"application/x-lottie", @[ @"lottie", @"lottie.json" ],
         @"Lottie Animation", @"animation", YES),
    MakeMIME(@"application/x-torrent", @[ @"torrent" ], @"BitTorrent Metainfo",
         @"misc", NO),
    MakeMIME(@"text/x-srt", @[ @"srt" ], @"SRT Subtitles", @"subtitle", YES),
    MakeMIME(@"text/vtt", @[ @"vtt" ], @"WebVTT Subtitles", @"subtitle", YES),
  ];
}

- (void)buildMaps {
  NSMutableDictionary *e2m = [NSMutableDictionary dictionary];
  NSMutableDictionary *e2c = [NSMutableDictionary dictionary];
  for (UFTMimeEntry *entry in _mimeDatabase) {
    for (NSString *ext in entry.extensions) {
      e2m[ext.lowercaseString] = entry;
      e2c[ext.lowercaseString] = entry.category;
    }
  }
  _extToMime = e2m;
  _extToCategory = e2c;

  _extToEmoji = @{
    @"txt" : @"📄",
    @"pdf" : @"📕",
    @"doc" : @"📘",
    @"docx" : @"📘",
    @"xls" : @"📗",
    @"xlsx" : @"📗",
    @"ppt" : @"📙",
    @"pptx" : @"📙",
    @"md" : @"📝",
    @"html" : @"🌐",
    @"css" : @"🎨",
    @"js" : @"⚡",
    @"ts" : @"💎",
    @"py" : @"🐍",
    @"rb" : @"💎",
    @"go" : @"🐹",
    @"rs" : @"🦀",
    @"swift" : @"🐦",
    @"java" : @"☕",
    @"kt" : @"🟣",
    @"c" : @"©️",
    @"cpp" : @"➕",
    @"cs" : @"🟢",
    @"jpg" : @"🖼️",
    @"jpeg" : @"🖼️",
    @"png" : @"🖼️",
    @"gif" : @"🖼️",
    @"svg" : @"🎨",
    @"psd" : @"🎨",
    @"mp3" : @"🎵",
    @"wav" : @"🎵",
    @"flac" : @"🎵",
    @"aac" : @"🎵",
    @"ogg" : @"🎵",
    @"mp4" : @"🎬",
    @"mov" : @"🎬",
    @"avi" : @"🎬",
    @"mkv" : @"🎬",
    @"webm" : @"🎬",
    @"zip" : @"📦",
    @"rar" : @"📦",
    @"7z" : @"📦",
    @"tar" : @"📦",
    @"gz" : @"📦",
    @"exe" : @"⚙️",
    @"app" : @"📱",
    @"dmg" : @"💿",
    @"iso" : @"💿",
    @"json" : @"📋",
    @"xml" : @"📋",
    @"yml" : @"📋",
    @"yaml" : @"📋",
    @"csv" : @"📊",
    @"sql" : @"🗄️",
    @"sqlite" : @"🗄️",
    @"db" : @"🗄️",
    @"ttf" : @"🔤",
    @"otf" : @"🔤",
    @"woff" : @"🔤",
    @"obj" : @"🧊",
    @"fbx" : @"🧊",
    @"glb" : @"🧊",
    @"stl" : @"🧊",
    @"blend" : @"🧊",
    @"hdf5" : @"🔬",
    @"fits" : @"🔭",
    @"nc" : @"🌊",
    @"dcm" : @"🏥",
    @"onnx" : @"🧠",
    @"pt" : @"🧠",
    @"safetensors" : @"🧠",
    @"gguf" : @"🧠",
    @"geojson" : @"🗺️",
    @"kml" : @"🗺️",
    @"shp" : @"🗺️",
    @"gpx" : @"🗺️",
    @"fasta" : @"🧬",
    @"fastq" : @"🧬",
    @"bam" : @"🧬",
    @"vcf" : @"🧬",
    @"pdb" : @"🧬",
    @"wasm" : @"🕸️",
    @"Dockerfile" : @"🐳",
    @"tf" : @"🏗️",
    @"ipynb" : @"📓",
    @"sh" : @"🐚",
    @"bat" : @"🦇",
    @"ps1" : @"💠",
    @"sol" : @"⛓️",
    @"tex" : @"📐",
    @"epub" : @"📚",
  };
}

// ========== MAGIC NUMBER DETECTION ==========

- (NSString *)detectFileTypeByMagic:(NSString *)filePath {
  NSFileHandle *fh = [NSFileHandle fileHandleForReadingAtPath:filePath];
  if (!fh)
    return @"unknown";
  NSData *header = [fh readDataOfLength:512];
  [fh closeFile];
  return [self detectMimeTypeByMagicFromData:header] ?: @"unknown";
}

- (NSString *)detectMimeTypeByMagic:(NSString *)filePath {
  return [self detectFileTypeByMagic:filePath];
}

- (NSString *)detectMimeTypeByMagicFromData:(NSData *)data {
  if (!data || data.length == 0)
    return nil;
  const uint8_t *bytes = (const uint8_t *)data.bytes;
  NSUInteger len = data.length;

  for (UFTMagicEntry *entry in _magicDatabase) {
    NSUInteger offset = entry.offset;
    NSUInteger sigLen = entry.signature.length;
    if (offset + sigLen > len)
      continue;
    if (memcmp(bytes + offset, entry.signature.bytes, sigLen) == 0) {
      return entry.mimeType;
    }
  }
  // Heuristic: check if it's text
  BOOL isText = YES;
  NSUInteger checkLen = MIN(len, 512U);
  for (NSUInteger i = 0; i < checkLen; i++) {
    uint8_t b = bytes[i];
    if (b == 0) {
      isText = NO;
      break;
    }
    if (b < 0x09 && b != 0x00) {
      isText = NO;
      break;
    }
  }
  return isText ? @"text/plain" : @"application/octet-stream";
}

// ========== MIME DATABASE QUERIES ==========

- (NSString *)mimeTypeForExtension:(NSString *)ext {
  UFTMimeEntry *entry = _extToMime[ext.lowercaseString];
  return entry ? entry.mimeType : @"application/octet-stream";
}

- (NSArray<NSString *> *)extensionsForMimeType:(NSString *)mime {
  for (UFTMimeEntry *entry in _mimeDatabase) {
    if ([entry.mimeType isEqualToString:mime])
      return entry.extensions;
  }
  return @[];
}

- (NSString *)descriptionForMimeType:(NSString *)mime {
  for (UFTMimeEntry *entry in _mimeDatabase) {
    if ([entry.mimeType isEqualToString:mime])
      return entry.fileDescription;
  }
  return @"Unknown";
}

- (NSArray<UFTMimeEntry *> *)allMimeEntries {
  return _mimeDatabase;
}

- (NSArray<UFTMimeEntry *> *)mimeEntriesForCategory:(NSString *)category {
  NSMutableArray *r = [NSMutableArray array];
  for (UFTMimeEntry *e in _mimeDatabase) {
    if ([e.category isEqualToString:category])
      [r addObject:e];
  }
  return r;
}

- (NSString *)categoryForExtension:(NSString *)ext {
  return _extToCategory[ext.lowercaseString] ?: @"unknown";
}
- (NSString *)iconEmojiForExtension:(NSString *)ext {
  return _extToEmoji[ext.lowercaseString] ?: @"📄";
}
- (BOOL)isTextFileExtension:(NSString *)ext {
  UFTMimeEntry *e = _extToMime[ext.lowercaseString];
  return e ? e.isText : NO;
}
- (BOOL)isBinaryFileExtension:(NSString *)ext {
  return ![self isTextFileExtension:ext];
}

- (BOOL)isExecutableExtension:(NSString *)ext {
  static NSSet *execs;
  static dispatch_once_t t;
  dispatch_once(&t, ^{
    execs = [NSSet setWithArray:@[
      @"exe",  @"bat", @"cmd", @"com", @"msi", @"ps1", @"sh",       @"bash",
      @"zsh",  @"app", @"pkg", @"dmg", @"deb", @"rpm", @"AppImage", @"flatpak",
      @"snap", @"py",  @"rb",  @"pl",  @"lua", @"jar", @"wasm"
    ]];
  });
  return [execs containsObject:ext.lowercaseString];
}

- (NSUInteger)magicEntryCount {
  return _magicDatabase.count;
}
- (NSUInteger)mimeEntryCount {
  return _mimeDatabase.count;
}
- (NSUInteger)totalExtensionCount {
  NSUInteger c = 0;
  for (UFTMimeEntry *e in _mimeDatabase)
    c += e.extensions.count;
  return c;
}

@end
