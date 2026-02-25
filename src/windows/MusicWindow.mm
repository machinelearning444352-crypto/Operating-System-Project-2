#import "MusicWindow.h"
#import <AVFoundation/AVFoundation.h>

@interface MusicWindow ()
@property (nonatomic, strong) NSWindow *musicWindow;
@property (nonatomic, strong) NSTableView *songsTable;
@property (nonatomic, strong) NSMutableArray *songs;
@property (nonatomic, strong) AVAudioPlayer *audioPlayer;
@property (nonatomic, assign) NSInteger currentSongIndex;
@property (nonatomic, assign) BOOL isPlaying;
@property (nonatomic, strong) NSTextField *nowPlayingLabel;
@property (nonatomic, strong) NSTextField *artistLabel;
@property (nonatomic, strong) NSSlider *progressSlider;
@property (nonatomic, strong) NSButton *playPauseBtn;
@property (nonatomic, strong) NSTimer *progressTimer;
@end

@implementation MusicWindow

+ (instancetype)sharedInstance {
    static MusicWindow *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[MusicWindow alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.songs = [NSMutableArray array];
        self.currentSongIndex = -1;
        self.isPlaying = NO;
        [self loadMusicFromSystem];
    }
    return self;
}

- (void)loadMusicFromSystem {
    // Load music from Music folder
    NSString *musicPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Music"];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *contents = [fm contentsOfDirectoryAtPath:musicPath error:nil];
    
    NSArray *audioExtensions = @[@"mp3", @"m4a", @"wav", @"aac", @"flac", @"aiff"];
    
    for (NSString *file in contents) {
        NSString *ext = [[file pathExtension] lowercaseString];
        if ([audioExtensions containsObject:ext]) {
            NSString *fullPath = [musicPath stringByAppendingPathComponent:file];
            NSString *name = [file stringByDeletingPathExtension];
            [self.songs addObject:@{@"name": name, @"path": fullPath, @"artist": @"Unknown Artist", @"duration": @"--:--"}];
        }
    }
}

- (void)showWindow {
    if (self.musicWindow) {
        [self.musicWindow makeKeyAndOrderFront:nil];
        return;
    }
    
    NSRect frame = NSMakeRect(0, 0, 900, 600);
    self.musicWindow = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    [self.musicWindow setTitle:@"Music"];
    [self.musicWindow center];
    
    NSView *contentView = [[NSView alloc] initWithFrame:frame];
    contentView.wantsLayer = YES;
    contentView.layer.backgroundColor = [[NSColor colorWithRed:0.15 green:0.0 blue:0.1 alpha:1.0] CGColor];
    [self.musicWindow setContentView:contentView];
    
    // Sidebar
    NSView *sidebar = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 200, frame.size.height)];
    sidebar.wantsLayer = YES;
    sidebar.layer.backgroundColor = [[NSColor colorWithWhite:0.0 alpha:0.3] CGColor];
    [contentView addSubview:sidebar];
    
    // Library section
    NSTextField *libLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(15, frame.size.height - 45, 170, 18)];
    libLabel.stringValue = @"Library";
    libLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    libLabel.textColor = [NSColor grayColor];
    libLabel.bezeled = NO;
    libLabel.editable = NO;
    libLabel.drawsBackground = NO;
    [sidebar addSubview:libLabel];
    
    NSArray *libraryItems = @[@"🎵 Songs", @"💿 Albums", @"👤 Artists", @"🎼 Playlists", @"⬇️ Downloaded"];
    CGFloat yPos = frame.size.height - 75;
    
    for (NSString *item in libraryItems) {
        NSButton *btn = [[NSButton alloc] initWithFrame:NSMakeRect(8, yPos, 184, 28)];
        btn.title = item;
        btn.bezelStyle = NSBezelStyleRecessed;
        btn.alignment = NSTextAlignmentLeft;
        btn.font = [NSFont systemFontOfSize:13];
        btn.contentTintColor = [NSColor whiteColor];
        [sidebar addSubview:btn];
        yPos -= 32;
    }
    
    // Add music button
    NSButton *addBtn = [[NSButton alloc] initWithFrame:NSMakeRect(10, 20, 180, 32)];
    addBtn.title = @"➕ Add Music";
    addBtn.bezelStyle = NSBezelStyleRounded;
    addBtn.target = self;
    addBtn.action = @selector(addMusic:);
    [sidebar addSubview:addBtn];
    
    // Main content area
    NSView *mainArea = [[NSView alloc] initWithFrame:NSMakeRect(200, 90, frame.size.width - 200, frame.size.height - 90)];
    mainArea.wantsLayer = YES;
    [contentView addSubview:mainArea];
    
    // Header
    NSTextField *headerTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(20, mainArea.bounds.size.height - 50, 300, 30)];
    headerTitle.stringValue = @"Songs";
    headerTitle.font = [NSFont boldSystemFontOfSize:26];
    headerTitle.textColor = [NSColor whiteColor];
    headerTitle.bezeled = NO;
    headerTitle.editable = NO;
    headerTitle.drawsBackground = NO;
    [mainArea addSubview:headerTitle];
    
    // Song count
    NSTextField *countLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(20, mainArea.bounds.size.height - 75, 300, 18)];
    countLabel.stringValue = [NSString stringWithFormat:@"%lu songs", (unsigned long)self.songs.count];
    countLabel.font = [NSFont systemFontOfSize:13];
    countLabel.textColor = [NSColor grayColor];
    countLabel.bezeled = NO;
    countLabel.editable = NO;
    countLabel.drawsBackground = NO;
    [mainArea addSubview:countLabel];
    
    // Songs table
    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, mainArea.bounds.size.width, mainArea.bounds.size.height - 90)];
    scrollView.hasVerticalScroller = YES;
    scrollView.autohidesScrollers = YES;
    scrollView.drawsBackground = NO;
    
    self.songsTable = [[NSTableView alloc] initWithFrame:scrollView.bounds];
    self.songsTable.dataSource = self;
    self.songsTable.delegate = self;
    self.songsTable.rowHeight = 50;
    self.songsTable.headerView = nil;
    self.songsTable.backgroundColor = [NSColor clearColor];
    self.songsTable.doubleAction = @selector(playSong:);
    self.songsTable.target = self;
    
    NSTableColumn *songCol = [[NSTableColumn alloc] initWithIdentifier:@"song"];
    songCol.width = mainArea.bounds.size.width;
    [self.songsTable addTableColumn:songCol];
    
    scrollView.documentView = self.songsTable;
    [mainArea addSubview:scrollView];
    
    // Player bar at bottom
    NSView *playerBar = [[NSView alloc] initWithFrame:NSMakeRect(200, 0, frame.size.width - 200, 90)];
    playerBar.wantsLayer = YES;
    playerBar.layer.backgroundColor = [[NSColor colorWithWhite:0.0 alpha:0.5] CGColor];
    [contentView addSubview:playerBar];
    
    // Album art placeholder
    NSView *albumArt = [[NSView alloc] initWithFrame:NSMakeRect(15, 15, 60, 60)];
    albumArt.wantsLayer = YES;
    albumArt.layer.backgroundColor = [[NSColor colorWithWhite:0.3 alpha:1.0] CGColor];
    albumArt.layer.cornerRadius = 6;
    [playerBar addSubview:albumArt];
    
    NSTextField *artIcon = [[NSTextField alloc] initWithFrame:NSMakeRect(15, 15, 30, 30)];
    artIcon.stringValue = @"🎵";
    artIcon.font = [NSFont systemFontOfSize:24];
    artIcon.bezeled = NO;
    artIcon.editable = NO;
    artIcon.drawsBackground = NO;
    [albumArt addSubview:artIcon];
    
    // Now playing info
    self.nowPlayingLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(90, 45, 200, 20)];
    self.nowPlayingLabel.stringValue = @"Not Playing";
    self.nowPlayingLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    self.nowPlayingLabel.textColor = [NSColor whiteColor];
    self.nowPlayingLabel.bezeled = NO;
    self.nowPlayingLabel.editable = NO;
    self.nowPlayingLabel.drawsBackground = NO;
    [playerBar addSubview:self.nowPlayingLabel];
    
    self.artistLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(90, 25, 200, 18)];
    self.artistLabel.stringValue = @"";
    self.artistLabel.font = [NSFont systemFontOfSize:11];
    self.artistLabel.textColor = [NSColor grayColor];
    self.artistLabel.bezeled = NO;
    self.artistLabel.editable = NO;
    self.artistLabel.drawsBackground = NO;
    [playerBar addSubview:self.artistLabel];
    
    // Playback controls
    CGFloat controlsX = playerBar.bounds.size.width / 2 - 80;
    
    NSButton *prevBtn = [[NSButton alloc] initWithFrame:NSMakeRect(controlsX, 30, 40, 30)];
    prevBtn.title = @"⏮";
    prevBtn.bezelStyle = NSBezelStyleRounded;
    prevBtn.target = self;
    prevBtn.action = @selector(previousSong:);
    [playerBar addSubview:prevBtn];
    
    self.playPauseBtn = [[NSButton alloc] initWithFrame:NSMakeRect(controlsX + 50, 30, 60, 30)];
    self.playPauseBtn.title = @"▶️";
    self.playPauseBtn.bezelStyle = NSBezelStyleRounded;
    self.playPauseBtn.target = self;
    self.playPauseBtn.action = @selector(togglePlayPause:);
    [playerBar addSubview:self.playPauseBtn];
    
    NSButton *nextBtn = [[NSButton alloc] initWithFrame:NSMakeRect(controlsX + 120, 30, 40, 30)];
    nextBtn.title = @"⏭";
    nextBtn.bezelStyle = NSBezelStyleRounded;
    nextBtn.target = self;
    nextBtn.action = @selector(nextSong:);
    [playerBar addSubview:nextBtn];
    
    // Progress slider
    self.progressSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(300, 8, playerBar.bounds.size.width - 400, 16)];
    self.progressSlider.minValue = 0;
    self.progressSlider.maxValue = 100;
    self.progressSlider.doubleValue = 0;
    self.progressSlider.target = self;
    self.progressSlider.action = @selector(seekTo:);
    [playerBar addSubview:self.progressSlider];
    
    // Volume
    NSSlider *volumeSlider = [[NSSlider alloc] initWithFrame:NSMakeRect(playerBar.bounds.size.width - 120, 35, 100, 20)];
    volumeSlider.minValue = 0;
    volumeSlider.maxValue = 1;
    volumeSlider.doubleValue = 0.8;
    [playerBar addSubview:volumeSlider];
    
    NSTextField *volIcon = [[NSTextField alloc] initWithFrame:NSMakeRect(playerBar.bounds.size.width - 145, 35, 20, 20)];
    volIcon.stringValue = @"🔊";
    volIcon.font = [NSFont systemFontOfSize:12];
    volIcon.bezeled = NO;
    volIcon.editable = NO;
    volIcon.drawsBackground = NO;
    [playerBar addSubview:volIcon];
    
    [self.musicWindow makeKeyAndOrderFront:nil];
}

- (void)playSong:(id)sender {
    NSInteger row = self.songsTable.selectedRow;
    if (row < 0 || row >= (NSInteger)self.songs.count) return;
    
    self.currentSongIndex = row;
    NSDictionary *song = self.songs[row];
    
    NSError *error;
    NSURL *url = [NSURL fileURLWithPath:song[@"path"]];
    self.audioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
    
    if (self.audioPlayer) {
        [self.audioPlayer play];
        self.isPlaying = YES;
        self.playPauseBtn.title = @"⏸";
        self.nowPlayingLabel.stringValue = song[@"name"];
        self.artistLabel.stringValue = song[@"artist"];
        
        // Start progress timer
        [self.progressTimer invalidate];
        self.progressTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateProgress) userInfo:nil repeats:YES];
    }
}

- (void)togglePlayPause:(id)sender {
    if (self.audioPlayer) {
        if (self.isPlaying) {
            [self.audioPlayer pause];
            self.playPauseBtn.title = @"▶️";
        } else {
            [self.audioPlayer play];
            self.playPauseBtn.title = @"⏸";
        }
        self.isPlaying = !self.isPlaying;
    } else if (self.songs.count > 0) {
        self.songsTable.selectedRow == 0;
        [self playSong:nil];
    }
}

- (void)previousSong:(id)sender {
    if (self.songs.count == 0) return;
    self.currentSongIndex = (self.currentSongIndex - 1 + self.songs.count) % self.songs.count;
    [self.songsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:self.currentSongIndex] byExtendingSelection:NO];
    [self playSong:nil];
}

- (void)nextSong:(id)sender {
    if (self.songs.count == 0) return;
    self.currentSongIndex = (self.currentSongIndex + 1) % self.songs.count;
    [self.songsTable selectRowIndexes:[NSIndexSet indexSetWithIndex:self.currentSongIndex] byExtendingSelection:NO];
    [self playSong:nil];
}

- (void)updateProgress {
    if (self.audioPlayer && self.audioPlayer.duration > 0) {
        double progress = (self.audioPlayer.currentTime / self.audioPlayer.duration) * 100;
        self.progressSlider.doubleValue = progress;
    }
}

- (void)seekTo:(id)sender {
    if (self.audioPlayer) {
        double time = (self.progressSlider.doubleValue / 100) * self.audioPlayer.duration;
        self.audioPlayer.currentTime = time;
    }
}

- (void)addMusic:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowsMultipleSelection = YES;
    panel.canChooseDirectories = NO;
    panel.canChooseFiles = YES;
    
    [panel beginSheetModalForWindow:self.musicWindow completionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK) {
            for (NSURL *url in panel.URLs) {
                NSString *name = [[url lastPathComponent] stringByDeletingPathExtension];
                [self.songs addObject:@{@"name": name, @"path": url.path, @"artist": @"Unknown Artist", @"duration": @"--:--"}];
            }
            [self.songsTable reloadData];
        }
    }];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return self.songs.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    NSTableCellView *cell = [[NSTableCellView alloc] initWithFrame:NSMakeRect(0, 0, tableView.bounds.size.width, 50)];
    cell.wantsLayer = YES;
    
    if (row < (NSInteger)self.songs.count) {
        NSDictionary *song = self.songs[row];
        
        // Play indicator or number
        NSTextField *numLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(15, 15, 30, 20)];
        numLabel.stringValue = [NSString stringWithFormat:@"%ld", (long)row + 1];
        numLabel.font = [NSFont systemFontOfSize:13];
        numLabel.textColor = [NSColor grayColor];
        numLabel.alignment = NSTextAlignmentCenter;
        numLabel.bezeled = NO;
        numLabel.editable = NO;
        numLabel.drawsBackground = NO;
        [cell addSubview:numLabel];
        
        // Song name
        NSTextField *nameLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(55, 25, 300, 18)];
        nameLabel.stringValue = song[@"name"];
        nameLabel.font = [NSFont systemFontOfSize:13];
        nameLabel.textColor = [NSColor whiteColor];
        nameLabel.bezeled = NO;
        nameLabel.editable = NO;
        nameLabel.drawsBackground = NO;
        [cell addSubview:nameLabel];
        
        // Artist
        NSTextField *artistLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(55, 8, 300, 16)];
        artistLabel.stringValue = song[@"artist"];
        artistLabel.font = [NSFont systemFontOfSize:11];
        artistLabel.textColor = [NSColor grayColor];
        artistLabel.bezeled = NO;
        artistLabel.editable = NO;
        artistLabel.drawsBackground = NO;
        [cell addSubview:artistLabel];
    }
    
    return cell;
}

@end
