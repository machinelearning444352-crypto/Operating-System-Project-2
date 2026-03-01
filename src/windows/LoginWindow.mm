#import "LoginWindow.h"
#import "../services/UserManager.h"
#import <QuartzCore/QuartzCore.h>

@interface LoginNSWindow : NSWindow
@end

@implementation LoginNSWindow
- (BOOL)canBecomeKeyWindow {
  return YES;
}
- (BOOL)canBecomeMainWindow {
  return YES;
}
@end

@interface LoginWindow ()
@property(nonatomic, strong) NSWindow *loginWindow;
@property(nonatomic, strong) NSView *contentView;
@property(nonatomic, strong) NSSecureTextField *passwordField;
@property(nonatomic, strong) NSButton *loginButton;
@property(nonatomic, strong) NSTextField *errorLabel;
@property(nonatomic, strong) NSImageView *avatarView;
@property(nonatomic, strong) NSTextField *nameLabel;
@property(nonatomic, strong) NSTextField *roleLabel;
@property(nonatomic, copy) void (^successCallback)(void);
@property(nonatomic, strong) NSArray<NSDictionary *> *users;
@property(nonatomic, assign) NSInteger selectedUserIndex;

// Guest login flow
@property(nonatomic, strong) NSButton *guestButton;

- (void)drawGuestOnlyFallback:(CGFloat)w height:(CGFloat)h;
@end

@implementation LoginWindow

+ (instancetype)sharedInstance {
  static LoginWindow *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[LoginWindow alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _selectedUserIndex = 0;
  }
  return self;
}

- (void)loginSuccessCallback:(void (^)(void))callback {
  self.successCallback = callback;
}

- (void)showWindow {
  if (self.loginWindow) {
    [self.loginWindow makeKeyAndOrderFront:nil];
    return;
  }

  // Cover the entire screen
  NSRect screenRect = [[NSScreen mainScreen] frame];
  self.loginWindow =
      [[LoginNSWindow alloc] initWithContentRect:screenRect
                                       styleMask:NSWindowStyleMaskBorderless
                                         backing:NSBackingStoreBuffered
                                           defer:NO];

  self.loginWindow.level = NSScreenSaverWindowLevel;
  self.loginWindow.backgroundColor = [NSColor blackColor];
  self.loginWindow.canHide = NO;
  self.loginWindow.hasShadow = NO;
  self.loginWindow.ignoresMouseEvents = NO;

  self.contentView = [[NSView alloc] initWithFrame:screenRect];
  self.contentView.wantsLayer = YES;

  // Background gradient/wallpaper effect
  NSImageView *bgImageView =
      [[NSImageView alloc] initWithFrame:self.contentView.bounds];
  bgImageView.imageScaling = NSImageScaleAxesIndependently;

  // Create a nice gradient image explicitly for the lock screen
  NSGradient *gradient =
      [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithRed:0.0
                                                                     green:0.02
                                                                      blue:0.1
                                                                     alpha:1.0],
                                                     0.0,
                                                     [NSColor colorWithRed:0.05
                                                                     green:0.1
                                                                      blue:0.25
                                                                     alpha:1.0],
                                                     0.5,
                                                     [NSColor colorWithRed:0.1
                                                                     green:0.2
                                                                      blue:0.35
                                                                     alpha:1.0],
                                                     1.0, nil];

  NSImage *bgImage = [[NSImage alloc] initWithSize:screenRect.size];
  [bgImage lockFocus];
  [gradient
      drawInRect:NSMakeRect(0, 0, screenRect.size.width, screenRect.size.height)
           angle:90];
  [bgImage unlockFocus];
  bgImageView.image = bgImage;
  [self.contentView addSubview:bgImageView];

  // Visual Effect View overlay
  NSVisualEffectView *vev =
      [[NSVisualEffectView alloc] initWithFrame:self.contentView.bounds];
  vev.material = NSVisualEffectMaterialDark;
  vev.blendingMode = NSVisualEffectBlendingModeBehindWindow;
  vev.state = NSVisualEffectStateActive;
  [self.contentView addSubview:vev];

  [self.loginWindow setContentView:self.contentView];

  [self setupLoginUI];

  [self.loginWindow makeMainWindow];
  [self.loginWindow makeKeyAndOrderFront:nil];
  [NSApp activateIgnoringOtherApps:YES];
}

- (void)setupLoginUI {
  CGFloat w = self.contentView.bounds.size.width;
  CGFloat h = self.contentView.bounds.size.height;

  self.users = [[UserManager sharedInstance] getAllUsers];
  if (self.users.count == 0) {
    // If we're somehow here without users, skip drawing the password UI
    // and rely on Guest mode if it's enabled.
    [self drawGuestOnlyFallback:w height:h];
    return;
  }

  NSDictionary *activeUser = self.users[self.selectedUserIndex];

  // Avatar Container
  NSView *avatarCircle = [[NSView alloc]
      initWithFrame:NSMakeRect((w - 120) / 2, h / 2 + 50, 120, 120)];
  avatarCircle.wantsLayer = YES;
  avatarCircle.layer.cornerRadius = 60;
  avatarCircle.layer.backgroundColor = [[NSColor colorWithWhite:1.0
                                                          alpha:0.15] CGColor];
  [self.contentView addSubview:avatarCircle];

  NSTextField *icon =
      [[NSTextField alloc] initWithFrame:NSMakeRect(0, 25, 120, 70)];
  icon.stringValue = @"👤";
  icon.font = [NSFont systemFontOfSize:60];
  icon.bezeled = NO;
  icon.editable = NO;
  icon.drawsBackground = NO;
  icon.alignment = NSTextAlignmentCenter;
  [avatarCircle addSubview:icon];

  // Name
  self.nameLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(0, h / 2, w, 40)];
  self.nameLabel.stringValue = activeUser[@"username"];
  self.nameLabel.font = [NSFont boldSystemFontOfSize:28];
  self.nameLabel.textColor = [NSColor whiteColor];
  self.nameLabel.bezeled = NO;
  self.nameLabel.editable = NO;
  self.nameLabel.drawsBackground = NO;
  self.nameLabel.alignment = NSTextAlignmentCenter;
  [self.contentView addSubview:self.nameLabel];

  self.roleLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(0, h / 2 - 25, w, 20)];
  self.roleLabel.stringValue =
      [activeUser[@"isAdmin"] boolValue] ? @"Administrator" : @"Standard User";
  self.roleLabel.font = [NSFont systemFontOfSize:14];
  self.roleLabel.textColor = [NSColor colorWithWhite:0.7 alpha:1.0];
  self.roleLabel.bezeled = NO;
  self.roleLabel.editable = NO;
  self.roleLabel.drawsBackground = NO;
  self.roleLabel.alignment = NSTextAlignmentCenter;
  [self.contentView addSubview:self.roleLabel];

  // Password Output
  self.passwordField = [[NSSecureTextField alloc]
      initWithFrame:NSMakeRect((w - 200) / 2, h / 2 - 80, 160, 32)];
  self.passwordField.placeholderString = @"Enter Password";
  self.passwordField.font = [NSFont systemFontOfSize:15];
  self.passwordField.bezelStyle = NSTextFieldRoundedBezel;
  self.passwordField.focusRingType = NSFocusRingTypeNone;
  self.passwordField.wantsLayer = YES;
  self.passwordField.layer.cornerRadius = 16;
  self.passwordField.backgroundColor = [NSColor colorWithWhite:1.0 alpha:0.2];
  self.passwordField.textColor = [NSColor whiteColor];
  self.passwordField.target = self;
  self.passwordField.action = @selector(performLogin:);
  [[self.passwordField cell] setSendsActionOnEndEditing:YES];
  [self.contentView addSubview:self.passwordField];

  // Submit Button
  self.loginButton = [[NSButton alloc]
      initWithFrame:NSMakeRect((w - 200) / 2 + 165, h / 2 - 80, 35, 32)];
  self.loginButton.title = @"→";
  self.loginButton.font = [NSFont boldSystemFontOfSize:18];
  self.loginButton.bezelStyle = NSBezelStyleInline;
  self.loginButton.target = self;
  self.loginButton.action = @selector(performLogin:);
  [self.loginWindow setDefaultButtonCell:[self.loginButton cell]];
  [self.contentView addSubview:self.loginButton];

  // Request focus on the password field immediately
  [self.loginWindow makeFirstResponder:self.passwordField];

  // Error label
  self.errorLabel =
      [[NSTextField alloc] initWithFrame:NSMakeRect(0, h / 2 - 110, w, 20)];
  self.errorLabel.stringValue = @"";
  self.errorLabel.font = [NSFont systemFontOfSize:13];
  self.errorLabel.textColor = [NSColor systemRedColor];
  self.errorLabel.bezeled = NO;
  self.errorLabel.editable = NO;
  self.errorLabel.drawsBackground = NO;
  self.errorLabel.alignment = NSTextAlignmentCenter;
  [self.contentView addSubview:self.errorLabel];

  // Guest Mode
  if ([[UserManager sharedInstance] isGuestEnabled]) {
    self.guestButton = [[NSButton alloc]
        initWithFrame:NSMakeRect((w - 120) / 2, h / 2 - 180, 120, 32)];
    self.guestButton.title = @"Guest User";
    self.guestButton.bezelStyle = NSBezelStyleRounded;
    self.guestButton.target = self;
    self.guestButton.action = @selector(loginGuest:);
    [self.contentView addSubview:self.guestButton];
  }
}

- (void)drawGuestOnlyFallback:(CGFloat)w height:(CGFloat)h {
  NSTextField *title =
      [[NSTextField alloc] initWithFrame:NSMakeRect(0, h / 2, w, 40)];
  title.stringValue = @"No User Accounts Found";
  title.font = [NSFont boldSystemFontOfSize:28];
  title.textColor = [NSColor whiteColor];
  title.bezeled = NO;
  title.editable = NO;
  title.drawsBackground = NO;
  title.alignment = NSTextAlignmentCenter;
  [self.contentView addSubview:title];

  if ([[UserManager sharedInstance] isGuestEnabled]) {
    NSButton *guestBtn = [[NSButton alloc]
        initWithFrame:NSMakeRect((w - 150) / 2, h / 2 - 80, 150, 40)];
    guestBtn.title = @"Login as Guest";
    guestBtn.bezelStyle = NSBezelStyleRounded;
    guestBtn.target = self;
    guestBtn.action = @selector(loginGuest:);
    [self.contentView addSubview:guestBtn];
  }
}

- (void)loginGuest:(id)sender {
  [[UserManager sharedInstance] loginUser:@"Guest User"];
  [self unlockSystem];
}

- (void)performLogin:(id)sender {
  NSString *password = self.passwordField.stringValue;
  NSString *username = self.users[self.selectedUserIndex][@"username"];

  BOOL success = [[UserManager sharedInstance] authenticateUser:username
                                                       password:password];
  if (success) {
    [[UserManager sharedInstance] loginUser:username];
    [self unlockSystem];
  } else {
    self.errorLabel.stringValue = @"Incorrect password";
    self.passwordField.stringValue = @"";

    // Shake animation
    CAKeyframeAnimation *shake =
        [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    shake.duration = 0.4;
    shake.values = @[ @(-10), @(10), @(-8), @(8), @(-5), @(5), @(0) ];
    [self.passwordField.layer addAnimation:shake forKey:@"shake"];
  }
}

- (void)unlockSystem {
  // Copy callback before closing window
  void (^callback)(void) = [self.successCallback copy];
  self.successCallback = nil;
  
  // Close window immediately without animation
  [self.loginWindow orderOut:nil];
  self.loginWindow = nil;
  
  // Call callback on next run loop iteration
  if (callback) {
    dispatch_async(dispatch_get_main_queue(), ^{
      callback();
    });
  }
}

@end
