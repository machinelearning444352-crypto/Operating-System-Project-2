#import "FileSystemManager.h"

@interface FileSystemManager (TypesPrivate)
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSString *, NSString *> *mimeTypeMap;
@end

@implementation FileSystemManager (Types)

- (VFSFileType)fileTypeForExtension:(NSString *)extension {
    NSString *ext = extension.lowercaseString;
    if (!ext.length) return VFSFileTypeUnknown;
    // Documents
    if ([ext isEqualToString:@"txt"] || [ext isEqualToString:@"text"]) return VFSFileTypeText;
    if ([ext isEqualToString:@"rtf"]) return VFSFileTypeRichText;
    if ([ext isEqualToString:@"pdf"]) return VFSFileTypePDF;
    if ([ext isEqualToString:@"doc"] || [ext isEqualToString:@"docx"]) return VFSFileTypeWord;
    if ([ext isEqualToString:@"xls"] || [ext isEqualToString:@"xlsx"]) return VFSFileTypeExcel;
    if ([ext isEqualToString:@"ppt"] || [ext isEqualToString:@"pptx"]) return VFSFileTypePowerPoint;
    // Images
    if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"]) return VFSFileTypeJPEG;
    if ([ext isEqualToString:@"png"]) return VFSFileTypePNG;
    if ([ext isEqualToString:@"gif"]) return VFSFileTypeGIF;
    if ([ext isEqualToString:@"bmp"]) return VFSFileTypeBMP;
    if ([ext isEqualToString:@"tiff"] || [ext isEqualToString:@"tif"]) return VFSFileTypeTIFF;
    if ([ext isEqualToString:@"svg"]) return VFSFileTypeSVG;
    if ([ext isEqualToString:@"ico"]) return VFSFileTypeICO;
    // Audio
    if ([ext isEqualToString:@"mp3"]) return VFSFileTypeMP3;
    if ([ext isEqualToString:@"wav"]) return VFSFileTypeWAV;
    if ([ext isEqualToString:@"aac"]) return VFSFileTypeAAC;
    if ([ext isEqualToString:@"flac"]) return VFSFileTypeFLAC;
    if ([ext isEqualToString:@"ogg"]) return VFSFileTypeOGG;
    if ([ext isEqualToString:@"m4a"]) return VFSFileTypeM4A;
    // Video
    if ([ext isEqualToString:@"mp4"]) return VFSFileTypeMP4;
    if ([ext isEqualToString:@"mov"]) return VFSFileTypeMOV;
    if ([ext isEqualToString:@"avi"]) return VFSFileTypeAVI;
    if ([ext isEqualToString:@"mkv"]) return VFSFileTypeMKV;
    if ([ext isEqualToString:@"wmv"]) return VFSFileTypeWMV;
    if ([ext isEqualToString:@"webm"]) return VFSFileTypeWebM;
    // Archives
    if ([ext isEqualToString:@"zip"]) return VFSFileTypeZIP;
    if ([ext isEqualToString:@"rar"]) return VFSFileTypeRAR;
    if ([ext isEqualToString:@"7z"]) return VFSFileType7Z;
    if ([ext isEqualToString:@"tar"]) return VFSFileTypeTAR;
    if ([ext isEqualToString:@"gz"] || [ext isEqualToString:@"tgz"]) return VFSFileTypeGZ;
    if ([ext isEqualToString:@"dmg"]) return VFSFileTypeDMG;
    if ([ext isEqualToString:@"iso"]) return VFSFileTypeISO;
    // Executables
    if ([ext isEqualToString:@"app"]) return VFSFileTypeApp;
    if ([ext isEqualToString:@"pkg"]) return VFSFileTypePKG;
    if ([ext isEqualToString:@"exe"]) return VFSFileTypeEXE;
    if ([ext isEqualToString:@"msi"]) return VFSFileTypeMSI;
    if ([ext isEqualToString:@"deb"]) return VFSFileTypeDEB;
    if ([ext isEqualToString:@"rpm"]) return VFSFileTypeRPM;
    // Scripts
    if ([ext isEqualToString:@"sh"] || [ext isEqualToString:@"bash"]) return VFSFileTypeShellScript;
    if ([ext isEqualToString:@"py"] || [ext isEqualToString:@"pyw"]) return VFSFileTypePython;
    if ([ext isEqualToString:@"rb"]) return VFSFileTypeRuby;
    if ([ext isEqualToString:@"pl"] || [ext isEqualToString:@"pm"]) return VFSFileTypePerl;
    if ([ext isEqualToString:@"php"]) return VFSFileTypePHP;
    if ([ext isEqualToString:@"lua"]) return VFSFileTypeLua;
    if ([ext isEqualToString:@"r"]) return VFSFileTypeR;
    // Web
    if ([ext isEqualToString:@"htm"] || [ext isEqualToString:@"html"]) return VFSFileTypeHTML;
    if ([ext isEqualToString:@"css"]) return VFSFileTypeCSS;
    if ([ext isEqualToString:@"js"]) return VFSFileTypeJavaScript;
    if ([ext isEqualToString:@"ts"]) return VFSFileTypeTypeScript;
    if ([ext isEqualToString:@"json"]) return VFSFileTypeJSON;
    if ([ext isEqualToString:@"xml"]) return VFSFileTypeXML;
    if ([ext isEqualToString:@"yaml"] || [ext isEqualToString:@"yml"]) return VFSFileTypeYAML;
    if ([ext isEqualToString:@"toml"]) return VFSFileTypeTOML;
    // Programming
    if ([ext isEqualToString:@"c"] || [ext isEqualToString:@"h"]) return VFSFileTypeC;
    if ([ext isEqualToString:@"cpp"] || [ext isEqualToString:@"cxx"] || [ext isEqualToString:@"hpp"]) return VFSFileTypeCPP;
    if ([ext isEqualToString:@"m"] || [ext isEqualToString:@"mm"]) return VFSFileTypeObjectiveC;
    if ([ext isEqualToString:@"swift"]) return VFSFileTypeSwift;
    if ([ext isEqualToString:@"java"]) return VFSFileTypeJava;
    if ([ext isEqualToString:@"jar"]) return VFSFileTypeJAR;
    if ([ext isEqualToString:@"kt"] || [ext isEqualToString:@"kts"]) return VFSFileTypeKotlin;
    if ([ext isEqualToString:@"scala"]) return VFSFileTypeScala;
    if ([ext isEqualToString:@"go"]) return VFSFileTypeGo;
    if ([ext isEqualToString:@"rs"]) return VFSFileTypeRust;
    if ([ext isEqualToString:@"cs"]) return VFSFileTypeCSharp;
    // Data
    if ([ext isEqualToString:@"csv"]) return VFSFileTypeCSV;
    if ([ext isEqualToString:@"tsv"]) return VFSFileTypeTSV;
    if ([ext isEqualToString:@"sql"]) return VFSFileTypeSQL;
    if ([ext isEqualToString:@"sqlite"] || [ext isEqualToString:@"db"] || [ext isEqualToString:@"sqlite3"]) return VFSFileTypeSQLite;
    // Config
    if ([ext isEqualToString:@"ini"]) return VFSFileTypeINI;
    if ([ext isEqualToString:@"conf"] || [ext isEqualToString:@"config"]) return VFSFileTypeCONF;
    if ([ext isEqualToString:@"plist"]) return VFSFileTypePlist;
    if ([ext isEqualToString:@"env"]) return VFSFileTypeEnv;
    if ([ext isEqualToString:@"dockerfile"]) return VFSFileTypeDockerfile;
    if ([ext isEqualToString:@"makefile"] || [ext isEqualToString:@"mk"]) return VFSFileTypeMakefile;
    if ([ext isEqualToString:@"cmake"]) return VFSFileTypeCMake;
    // Markup
    if ([ext isEqualToString:@"md"] || [ext isEqualToString:@"markdown"]) return VFSFileTypeMarkdown;
    if ([ext isEqualToString:@"tex"] || [ext isEqualToString:@"latex"]) return VFSFileTypeLaTeX;
    if ([ext isEqualToString:@"rst"]) return VFSFileTypeRST;
    if ([ext isEqualToString:@"adoc"] || [ext isEqualToString:@"asciidoc"]) return VFSFileTypeASCIIDoc;
    if ([ext isEqualToString:@"org"]) return VFSFileTypeOrg;
    // Fonts
    if ([ext isEqualToString:@"ttf"]) return VFSFileTypeTTF;
    if ([ext isEqualToString:@"otf"]) return VFSFileTypeOTF;
    if ([ext isEqualToString:@"woff"]) return VFSFileTypeWOFF;
    if ([ext isEqualToString:@"woff2"]) return VFSFileTypeWOFF2;
    // eBooks
    if ([ext isEqualToString:@"epub"]) return VFSFileTypeEPUB;
    if ([ext isEqualToString:@"mobi"]) return VFSFileTypeMOBI;
    if ([ext isEqualToString:@"azw"]) return VFSFileTypeAZW;
    if ([ext isEqualToString:@"djvu"]) return VFSFileTypeDJVU;
    // System
    if ([ext isEqualToString:@"dll"]) return VFSFileTypeDLL;
    if ([ext isEqualToString:@"so"]) return VFSFileTypeSO;
    if ([ext isEqualToString:@"dylib"]) return VFSFileTypeDYLIB;
    if ([ext isEqualToString:@"sys"]) return VFSFileTypeSYS;
    if ([ext isEqualToString:@"drv"]) return VFSFileTypeDRV;
    if ([ext isEqualToString:@"kext"]) return VFSFileTypeKEXT;
    // Misc
    if ([ext isEqualToString:@"torrent"]) return VFSFileTypeTorrent;
    if ([ext isEqualToString:@"nfo"]) return VFSFileTypeNFO;
    if ([ext isEqualToString:@"srt"]) return VFSFileTypeSRT;
    if ([ext isEqualToString:@"vtt"]) return VFSFileTypeVTT;
    if ([ext isEqualToString:@"ass"]) return VFSFileTypeASS;
    if ([ext isEqualToString:@"log"]) return VFSFileTypeLOG;
    if ([ext isEqualToString:@"bak"]) return VFSFileTypeBAK;
    if ([ext isEqualToString:@"tmp"]) return VFSFileTypeTMP;
    if ([ext isEqualToString:@"swp"]) return VFSFileTypeSWP;
    return VFSFileTypeUnknown;
}

- (VFSFileCategory)categoryForFileType:(VFSFileType)type {
    switch (type) {
        case VFSFileTypeText:
        case VFSFileTypeRichText:
        case VFSFileTypePDF:
        case VFSFileTypeWord:
        case VFSFileTypeExcel:
        case VFSFileTypePowerPoint:
        case VFSFileTypePages:
        case VFSFileTypeNumbers:
        case VFSFileTypeKeynote:
            return VFSFileCategoryDocument;
        case VFSFileTypeImage:
        case VFSFileTypeJPEG:
        case VFSFileTypePNG:
        case VFSFileTypeGIF:
        case VFSFileTypeBMP:
        case VFSFileTypeTIFF:
        case VFSFileTypeWebP:
        case VFSFileTypeSVG:
        case VFSFileTypeICO:
        case VFSFileTypeHEIC:
        case VFSFileTypeRAW:
        case VFSFileTypePSD:
            return VFSFileCategoryImage;
        case VFSFileTypeAudio:
        case VFSFileTypeMP3:
        case VFSFileTypeWAV:
        case VFSFileTypeAAC:
        case VFSFileTypeFLAC:
        case VFSFileTypeOGG:
        case VFSFileTypeM4A:
        case VFSFileTypeAIFF:
        case VFSFileTypeMIDI:
            return VFSFileCategoryAudio;
        case VFSFileTypeVideo:
        case VFSFileTypeMP4:
        case VFSFileTypeMOV:
        case VFSFileTypeAVI:
        case VFSFileTypeMKV:
        case VFSFileTypeWMV:
        case VFSFileTypeFLV:
        case VFSFileTypeWebM:
        case VFSFileTypeM4V:
        case VFSFileType3GP:
            return VFSFileCategoryVideo;
        case VFSFileTypeArchive:
        case VFSFileTypeZIP:
        case VFSFileTypeRAR:
        case VFSFileType7Z:
        case VFSFileTypeTAR:
        case VFSFileTypeGZ:
        case VFSFileTypeBZ2:
        case VFSFileTypeXZ:
        case VFSFileTypeDMG:
        case VFSFileTypeISO:
            return VFSFileCategoryArchive;
        case VFSFileTypeApp:
        case VFSFileTypePKG:
        case VFSFileTypeMPKG:
        case VFSFileTypeEXE:
        case VFSFileTypeMSI:
        case VFSFileTypeBAT:
        case VFSFileTypeCMD:
        case VFSFileTypePowerShell:
        case VFSFileTypeDEB:
        case VFSFileTypeRPM:
        case VFSFileTypeAppImage:
        case VFSFileTypeFlatpak:
        case VFSFileTypeSnap:
            return VFSFileCategoryExecutable;
        case VFSFileTypeShellScript:
        case VFSFileTypePython:
        case VFSFileTypeRuby:
        case VFSFileTypePerl:
        case VFSFileTypePHP:
        case VFSFileTypeLua:
        case VFSFileTypeR:
        case VFSFileTypeJulia:
            return VFSFileCategoryScript;
        case VFSFileTypeHTML:
        case VFSFileTypeCSS:
        case VFSFileTypeJavaScript:
        case VFSFileTypeTypeScript:
        case VFSFileTypeJSON:
        case VFSFileTypeXML:
        case VFSFileTypeYAML:
        case VFSFileTypeTOML:
        case VFSFileTypeC:
        case VFSFileTypeCPP:
        case VFSFileTypeObjectiveC:
        case VFSFileTypeSwift:
        case VFSFileTypeJava:
        case VFSFileTypeJAR:
        case VFSFileTypeKotlin:
        case VFSFileTypeScala:
        case VFSFileTypeGo:
        case VFSFileTypeRust:
        case VFSFileTypeCSharp:
        case VFSFileTypeFSharp:
        case VFSFileTypeVisualBasic:
        case VFSFileTypeAssembly:
        case VFSFileTypeHaskell:
        case VFSFileTypeErlang:
        case VFSFileTypeElixir:
        case VFSFileTypeClojure:
        case VFSFileTypeLisp:
        case VFSFileTypeScheme:
        case VFSFileTypeProlog:
        case VFSFileTypeFortran:
        case VFSFileTypeCOBOL:
        case VFSFileTypePascal:
        case VFSFileTypeD:
        case VFSFileTypeNim:
        case VFSFileTypeZig:
        case VFSFileTypeV:
        case VFSFileTypeCrystal:
            return VFSFileCategoryCode;
        case VFSFileTypeCSV:
        case VFSFileTypeTSV:
        case VFSFileTypeSQL:
        case VFSFileTypeSQLite:
        case VFSFileTypeMongoDB:
        case VFSFileTypeDB:
        case VFSFileTypeMDB:
        case VFSFileTypeACCDB:
            return VFSFileCategoryData;
        case VFSFileTypeINI:
        case VFSFileTypeCONF:
        case VFSFileTypePlist:
        case VFSFileTypeEnv:
        case VFSFileTypeDockerfile:
        case VFSFileTypeMakefile:
        case VFSFileTypeCMake:
            return VFSFileCategoryConfig;
        case VFSFileTypeTTF:
        case VFSFileTypeOTF:
        case VFSFileTypeWOFF:
        case VFSFileTypeWOFF2:
        case VFSFileTypeEOT:
            return VFSFileCategoryFont;
        case VFSFileTypeOBJ:
        case VFSFileTypeFBX:
        case VFSFileTypeGLTF:
        case VFSFileTypeGLB:
        case VFSFileTypeSTL:
        case VFSFileTypeBLEND:
        case VFSFileTypeDAE:
        case VFSFileType3DS:
        case VFSFileTypeDWG:
        case VFSFileTypeDXF:
        case VFSFileTypeSTEP:
        case VFSFileTypeIGES:
            return VFSFileCategory3D;
        case VFSFileTypeSketch:
        case VFSFileTypeFigma:
        case VFSFileTypeXD:
        case VFSFileTypeAI:
        case VFSFileTypeEPS:
        case VFSFileTypeINDD:
            return VFSFileCategoryDesign;
        case VFSFileTypeEPUB:
        case VFSFileTypeMOBI:
        case VFSFileTypeAZW:
        case VFSFileTypeFB2:
        case VFSFileTypeDJVU:
            return VFSFileCategoryEBook;
        case VFSFileTypeDLL:
        case VFSFileTypeSO:
        case VFSFileTypeDYLIB:
        case VFSFileTypeSYS:
        case VFSFileTypeDRV:
        case VFSFileTypeKEXT:
        case VFSFileTypeFRAMEWORK:
            return VFSFileCategorySystem;
        case VFSFileTypeMarkdown:
        case VFSFileTypeLaTeX:
        case VFSFileTypeRST:
        case VFSFileTypeASCIIDoc:
        case VFSFileTypeOrg:
            return VFSFileCategoryDocument;
        case VFSFileTypeCER:
        case VFSFileTypeCRT:
        case VFSFileTypePEM:
        case VFSFileTypeKEY:
        case VFSFileTypeP12:
        case VFSFileTypePFX:
            return VFSFileCategorySystem;
        case VFSFileTypeVMDK:
        case VFSFileTypeVDI:
        case VFSFileTypeVHD:
        case VFSFileTypeQCOW2:
        case VFSFileTypeOVA:
        case VFSFileTypeOVF:
            return VFSFileCategorySystem;
        case VFSFileTypeTorrent:
        case VFSFileTypeNFO:
        case VFSFileTypeSRT:
        case VFSFileTypeVTT:
        case VFSFileTypeASS:
        case VFSFileTypeLOG:
        case VFSFileTypeBAK:
        case VFSFileTypeTMP:
        case VFSFileTypeSWP:
            return VFSFileCategoryUnknown;
        case VFSFileTypeDirectory:
        case VFSFileTypeSymlink:
        case VFSFileTypeBundle:
            return VFSFileCategoryDirectory;
        default:
            return VFSFileCategoryUnknown;
    }
}

- (NSString *)mimeTypeForExtension:(NSString *)extension {
    NSString *ext = extension.lowercaseString;
    if (!ext.length) return @"application/octet-stream";
    if ([ext isEqualToString:@"txt"] || [ext isEqualToString:@"text"]) return @"text/plain";
    if ([ext isEqualToString:@"html"] || [ext isEqualToString:@"htm"]) return @"text/html";
    if ([ext isEqualToString:@"css"]) return @"text/css";
    if ([ext isEqualToString:@"js"]) return @"application/javascript";
    if ([ext isEqualToString:@"json"]) return @"application/json";
    if ([ext isEqualToString:@"xml"]) return @"application/xml";
    if ([ext isEqualToString:@"pdf"]) return @"application/pdf";
    if ([ext isEqualToString:@"zip"]) return @"application/zip";
    if ([ext isEqualToString:@"jpg"] || [ext isEqualToString:@"jpeg"]) return @"image/jpeg";
    if ([ext isEqualToString:@"png"]) return @"image/png";
    if ([ext isEqualToString:@"gif"]) return @"image/gif";
    if ([ext isEqualToString:@"svg"]) return @"image/svg+xml";
    if ([ext isEqualToString:@"mp3"]) return @"audio/mpeg";
    if ([ext isEqualToString:@"wav"]) return @"audio/wav";
    if ([ext isEqualToString:@"mp4"]) return @"video/mp4";
    if ([ext isEqualToString:@"mov"]) return @"video/quicktime";
    return @"application/octet-stream";
}

- (NSString *)extensionForMimeType:(NSString *)mimeType {
    if (!mimeType.length) return @"";
    if ([mimeType isEqualToString:@"text/plain"]) return @"txt";
    if ([mimeType isEqualToString:@"text/html"]) return @"html";
    if ([mimeType isEqualToString:@"text/css"]) return @"css";
    if ([mimeType isEqualToString:@"application/javascript"]) return @"js";
    if ([mimeType isEqualToString:@"application/json"]) return @"json";
    if ([mimeType isEqualToString:@"application/xml"]) return @"xml";
    if ([mimeType isEqualToString:@"application/pdf"]) return @"pdf";
    if ([mimeType isEqualToString:@"application/zip"]) return @"zip";
    if ([mimeType isEqualToString:@"image/jpeg"]) return @"jpg";
    if ([mimeType isEqualToString:@"image/png"]) return @"png";
    if ([mimeType isEqualToString:@"image/gif"]) return @"gif";
    if ([mimeType isEqualToString:@"image/svg+xml"]) return @"svg";
    if ([mimeType isEqualToString:@"audio/mpeg"]) return @"mp3";
    if ([mimeType isEqualToString:@"audio/wav"]) return @"wav";
    if ([mimeType isEqualToString:@"video/mp4"]) return @"mp4";
    if ([mimeType isEqualToString:@"video/quicktime"]) return @"mov";
    return @"";
}

- (NSImage *)iconForFileType:(VFSFileType)type {
    VFSFileCategory cat = [self categoryForFileType:type];
    switch (cat) {
        case VFSFileCategoryDocument: return [NSImage imageNamed:@"doc"];
        case VFSFileCategoryImage: return [NSImage imageNamed:@"image"];
        case VFSFileCategoryAudio: return [NSImage imageNamed:@"audio"];
        case VFSFileCategoryVideo: return [NSImage imageNamed:@"video"];
        case VFSFileCategoryArchive: return [NSImage imageNamed:@"archive"];
        case VFSFileCategoryExecutable: return [NSImage imageNamed:@"exec"];
        case VFSFileCategoryScript: return [NSImage imageNamed:@"script"];
        case VFSFileCategoryCode: return [NSImage imageNamed:@"code"];
        case VFSFileCategoryData: return [NSImage imageNamed:@"data"];
        case VFSFileCategoryConfig: return [NSImage imageNamed:@"config"];
        case VFSFileCategoryFont: return [NSImage imageNamed:@"font"];
        case VFSFileCategory3D: return [NSImage imageNamed:@"3d"];
        case VFSFileCategoryDesign: return [NSImage imageNamed:@"design"];
        case VFSFileCategoryEBook: return [NSImage imageNamed:@"ebook"];
        case VFSFileCategorySystem: return [NSImage imageNamed:@"system"];
        case VFSFileCategoryDirectory: return [NSImage imageNamed:@"folder"];
        default: return [NSImage imageNamed:@"unknown"];
    }
    return [NSImage imageNamed:@"unknown"];
}

- (NSString *)emojiForFileType:(VFSFileType)type {
    VFSFileCategory cat = [self categoryForFileType:type];
    switch (cat) {
        case VFSFileCategoryDocument: return @"📄";
        case VFSFileCategoryImage: return @"🖼️";
        case VFSFileCategoryAudio: return @"🎵";
        case VFSFileCategoryVideo: return @"🎬";
        case VFSFileCategoryArchive: return @"📦";
        case VFSFileCategoryExecutable: return @"⚙️";
        case VFSFileCategoryScript: return @"📜";
        case VFSFileCategoryCode: return @"💻";
        case VFSFileCategoryData: return @"📊";
        case VFSFileCategoryConfig: return @"⚙️";
        case VFSFileCategoryFont: return @"🔤";
        case VFSFileCategory3D: return @"🎮";
        case VFSFileCategoryDesign: return @"🎨";
        case VFSFileCategoryEBook: return @"📚";
        case VFSFileCategorySystem: return @"🔧";
        case VFSFileCategoryDirectory: return @"📁";
        default: return @"📄";
    }
    return @"📄";
}

- (NSString *)descriptionForFileType:(VFSFileType)type {
    switch (type) {
        case VFSFileTypeText: return @"Plain Text";
        case VFSFileTypeRichText: return @"Rich Text";
        case VFSFileTypePDF: return @"PDF Document";
        case VFSFileTypeWord: return @"Microsoft Word";
        case VFSFileTypeExcel: return @"Microsoft Excel";
        case VFSFileTypePowerPoint: return @"Microsoft PowerPoint";
        case VFSFileTypeJPEG: return @"JPEG Image";
        case VFSFileTypePNG: return @"PNG Image";
        case VFSFileTypeGIF: return @"GIF Image";
        case VFSFileTypeSVG: return @"SVG Vector";
        case VFSFileTypeMP3: return @"MP3 Audio";
        case VFSFileTypeWAV: return @"WAV Audio";
        case VFSFileTypeMP4: return @"MP4 Video";
        case VFSFileTypeMOV: return @"QuickTime Video";
        case VFSFileTypeZIP: return @"ZIP Archive";
        case VFSFileTypeRAR: return @"RAR Archive";
        case VFSFileTypeApp: return @"macOS Application";
        case VFSFileTypeEXE: return @"Windows Executable";
        case VFSFileTypeShellScript: return @"Shell Script";
        case VFSFileTypePython: return @"Python Script";
        case VFSFileTypeHTML: return @"HTML Document";
        case VFSFileTypeCSS: return @"CSS Stylesheet";
        case VFSFileTypeJavaScript: return @"JavaScript";
        case VFSFileTypeJSON: return @"JSON Data";
        case VFSFileTypeXML: return @"XML Document";
        case VFSFileTypeCSV: return @"CSV Data";
        case VFSFileTypeSQL: return @"SQL Script";
        case VFSFileTypeMarkdown: return @"Markdown Document";
        default: return @"Unknown File";
    }
}

- (BOOL)isExecutableFileType:(VFSFileType)type {
    VFSFileCategory cat = [self categoryForFileType:type];
    return cat == VFSFileCategoryExecutable || cat == VFSFileCategoryScript;
}

- (BOOL)isViewableFileType:(VFSFileType)type {
    VFSFileCategory cat = [self categoryForFileType:type];
    return cat == VFSFileCategoryDocument || cat == VFSFileCategoryImage || cat == VFSFileCategoryDocument || cat == VFSFileCategoryCode;
}

- (BOOL)isEditableFileType:(VFSFileType)type {
    VFSFileCategory cat = [self categoryForFileType:type];
    return cat == VFSFileCategoryDocument || cat == VFSFileCategoryDocument || cat == VFSFileCategoryCode || cat == VFSFileCategoryConfig;
}

@end
