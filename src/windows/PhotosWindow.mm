#import "PhotosWindow.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@interface PhotosWindow ()
@property (nonatomic, strong) NSWindow *photosWindow;
@property (nonatomic, strong) NSMutableArray *photos;
@property (nonatomic, strong) NSCollectionView *collectionView;
@end

@implementation PhotosWindow

+ (instancetype)sharedInstance {
    static PhotosWindow *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[PhotosWindow alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.photos = [NSMutableArray array];
        [self loadPhotosFromSystem];
    }
    return self;
}

- (void)loadPhotosFromSystem {
    // Load actual photos from Pictures folder
    NSString *picturesPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Pictures"];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:picturesPath error:nil];
    
    NSArray *imageExtensions = @[@"jpg", @"jpeg", @"png", @"gif", @"heic", @"tiff", @"bmp"];
    
    for (NSString *file in contents) {
        NSString *ext = [[file pathExtension] lowercaseString];
        if ([imageExtensions containsObject:ext]) {
            NSString *fullPath = [picturesPath stringByAppendingPathComponent:file];
            [self.photos addObject:@{@"name": file, @"path": fullPath}];
        }
    }
}

- (void)showWindow {
    if (self.photosWindow) {
        [self.photosWindow makeKeyAndOrderFront:nil];
        return;
    }
    
    NSRect frame = NSMakeRect(0, 0, 900, 650);
    self.photosWindow = [[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    [self.photosWindow setTitle:@"Photos"];
    [self.photosWindow center];
    
    NSView *contentView = [[NSView alloc] initWithFrame:frame];
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];
    [self.photosWindow setContentView:contentView];
    
    // Sidebar
    NSView *sidebar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 180, frame.size.height)];
    sidebar.wantsLayer = YES;
    sidebar.layer.backgroundColor = [[NSColor controlBackgroundColor] CGColor];
    [contentView addSubview:sidebar];
    
    // Sidebar title
    NSTextField *libTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(15, frame.size.height - 45, 150, 20)];
    libTitle.stringValue = @"Library";
    libTitle.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    libTitle.textColor = [NSColor grayColor];
    libTitle.bezeled = NO;
    libTitle.editable = NO;
    libTitle.drawsBackground = NO;
    [sidebar addSubview:libTitle];
    
    // Sidebar items
    NSArray *sidebarItems = @[@"📷 All Photos", @"❤️ Favorites", @"🎬 Videos", @"👤 People", @"📍 Places", @"📅 Recents"];
    CGFloat yPos = frame.size.height - 75;
    
    for (NSString *item in sidebarItems) {
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(8, yPos, 164, 28)];
        btn.title = item;
        btn.bezelStyle = NSBezelStyleRecessed;
        btn.alignment = NSTextAlignmentLeft;
        btn.font = [NSFont systemFontOfSize:13];
        btn.contentTintColor = [NSColor whiteColor];
        [sidebar addSubview:btn];
        yPos -= 32;
    }
    
    // Import button
    NSButton *importBtn = [[NSButton alloc] initWithFrame:NSMakeRect(10, 20, 160, 32)];
    importBtn.title = @"📥 Import Photos";
    importBtn.bezelStyle = NSBezelStyleRounded;
    importBtn.target = self;
    importBtn.action = @selector(importPhotos:);
    [sidebar addSubview:importBtn];
    
    // Main content area
    NSView *mainArea = [[NSView alloc] initWithFrame:NSMakeRect(180, 0, frame.size.width - 180, frame.size.height)];
    mainArea.wantsLayer = YES;
    mainArea.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];
    [contentView addSubview:mainArea];
    
    // Header
    NSTextField *headerTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(20, frame.size.height - 50, 300, 30)];
    headerTitle.stringValue = @"All Photos";
    headerTitle.font = [NSFont boldSystemFontOfSize:24];
    headerTitle.textColor = [NSColor whiteColor];
    headerTitle.bezeled = NO;
    headerTitle.editable = NO;
    headerTitle.drawsBackground = NO;
    [mainArea addSubview:headerTitle];
    
    // Photo count
    NSTextField *countLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, frame.size.height - 75, 300, 20)];
    countLabel.stringValue = [NSString stringWithFormat:@"%lu Photos", (unsigned long)self.photos.count];
    countLabel.font = [NSFont systemFontOfSize:13];
    countLabel.textColor = [NSColor grayColor];
    countLabel.bezeled = NO;
    countLabel.editable = NO;
    countLabel.drawsBackground = NO;
    [mainArea addSubview:countLabel];
    
    // Photo grid scroll view
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, mainArea.bounds.size.width, frame.size.height - 90)];
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.backgroundColor = [NSColor clearColor];
    scrollView.drawsBackground = NO;
    
    // Photo grid container
    NSView *gridContainer = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, mainArea.bounds.size.width, frame.size.height - 90)];
    
    if (self.photos.count == 0) {
        // Empty state
        NSTextField *emptyLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(0, gridContainer.bounds.size.height / 2 - 40, gridContainer.bounds.size.width, 80)];
        emptyLabel.stringValue = @"📷\n\nNo Photos\nImport photos or add images to your Pictures folder";
        emptyLabel.font = [NSFont systemFontOfSize:14];
        emptyLabel.textColor = [NSColor grayColor];
        emptyLabel.alignment = NSTextAlignmentCenter;
        emptyLabel.bezeled = NO;
        emptyLabel.editable = NO;
        emptyLabel.drawsBackground = NO;
        [gridContainer addSubview:emptyLabel];
    } else {
        // Display photos in grid
        CGFloat photoSize = 150;
        CGFloat padding = 8;
        NSInteger cols = (mainArea.bounds.size.width - 40) / (photoSize + padding);
        NSInteger rows = (self.photos.count + cols - 1) / cols;
        CGFloat gridHeight = rows * (photoSize + padding) + 20;
        
        [gridContainer setFrameSize:NSMakeSize(mainArea.bounds.size.width, MAX(gridHeight, scrollView.bounds.size.height))];
        
        for (NSInteger i = 0; i < (NSInteger)self.photos.count; i++) {
            NSDictionary *photo = self.photos[i];
            NSInteger col = i % cols;
            NSInteger row = i / cols;
            
            CGFloat x = 20 + col * (photoSize + padding);
            CGFloat y = gridContainer.bounds.size.height - 20 - (row + 1) * (photoSize + padding);
            
            NSImageView *imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(x, y, photoSize, photoSize)];
            NSImage *image = [[NSImage alloc] initWithContentsOfFile:photo[@"path"]];
            imageView.image = image;
            imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
            imageView.wantsLayer = YES;
            imageView.layer.cornerRadius = 4;
            imageView.layer.masksToBounds = YES;
            [gridContainer addSubview:imageView];
        }
    }
    
    scrollView.documentView = gridContainer;
    [mainArea addSubview:scrollView];
    
    [self.photosWindow makeKeyAndOrderFront:nil];
}

- (void)importPhotos:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = YES;
    panel.canChooseDirectories = NO;
    panel.canChooseFiles = YES;
    panel.allowedContentTypes = @[
        [UTType typeWithFilenameExtension:@"jpg"],
        [UTType typeWithFilenameExtension:@"jpeg"],
        [UTType typeWithFilenameExtension:@"png"],
        [UTType typeWithFilenameExtension:@"gif"],
        [UTType typeWithFilenameExtension:@"heic"]
    ];
    
    [panel beginSheetModalForWindow:self.photosWindow completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            for (NSURL *url in panel.URLs) {
                [self.photos addObject:@{@"name": url.lastPathComponent, @"path": url.path}];
            }
            // Refresh window
            [self.photosWindow close];
            self.photosWindow = nil;
            [self showWindow];
        }
    }];
}

@end
