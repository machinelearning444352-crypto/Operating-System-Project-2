#import "SetupWizardWindow.h"

@interface SetupWizardWindow ()
@property (nonatomic, strong) NSWindow *wizardWindow;
@property (nonatomic, strong) NSView *contentView;
@property (nonatomic, assign) NSInteger currentStep;
@property (nonatomic, strong) NSString *username;
@property (nonatomic, strong) NSString *password;
@property (nonatomic, assign) BOOL adminAccount;
@property (nonatomic, assign) BOOL setupComplete;

@property (nonatomic, strong) NSTextField *usernameField;
@property (nonatomic, strong) NSButton *standardRadio;
@property (nonatomic, strong) NSButton *adminRadio;
@property (nonatomic, strong) NSSecureTextField *passwordField;
@property (nonatomic, strong) NSSecureTextField *confirmPasswordField;
@property (nonatomic, strong) NSTextField *errorLabel;
@end

@implementation SetupWizardWindow

+ (instancetype)sharedInstance {
    static SetupWizardWindow *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[SetupWizardWindow alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        self.currentStep = 0;
        self.setupComplete = [self loadSetupState];
    }
    return self;
}

- (BOOL)loadSetupState {
    NSString *path = [self settingsPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:path];
        if (settings) {
            self.username = settings[@"username"];
            self.adminAccount = [settings[@"isAdmin"] boolValue];
            return YES;
        }
    }
    return NO;
}

- (void)saveSetupState {
    NSString *path = [self settingsPath];
    NSString *dir = [path stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSDictionary *settings = @{
        @"username": self.username ?: @"",
        @"isAdmin": @(self.adminAccount),
        @"setupComplete": @YES
    };
    [settings writeToFile:path atomically:YES];
}

- (NSString *)settingsPath {
    NSString *appSupport = [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
    return [[appSupport stringByAppendingPathComponent:@"VirtualOS"] stringByAppendingPathComponent:@"user_settings.plist"];
}

- (BOOL)isSetupComplete {
    return self.setupComplete;
}

- (NSString *)currentUsername {
    return self.username;
}

- (BOOL)isAdmin {
    return self.adminAccount;
}

- (void)showWizard {
    if (self.wizardWindow) {
        [self.wizardWindow makeKeyAndOrderFront:nil];
        return;
    }
    
    NSRect frame = NSMakeRect(0, 0, 700, 500);
    self.wizardWindow = [[NSWindow alloc] initWithContentRect:frame
                                                    styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskFullSizeContentView
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO];
    [self.wizardWindow setTitle:@"VirtualOS Setup"];
    [self.wizardWindow center];
    self.wizardWindow.titlebarAppearsTransparent = YES;
    self.wizardWindow.movableByWindowBackground = YES;
    self.wizardWindow.level = NSFloatingWindowLevel;
    
    self.contentView = [[NSView alloc] initWithFrame:frame];
    self.contentView.wantsLayer = YES;
    
    // Modern gradient background
    NSGradient *gradient = [[NSGradient alloc] initWithColorsAndLocations:
        [NSColor colorWithRed:0.05 green:0.05 blue:0.15 alpha:1.0], 0.0,
        [NSColor colorWithRed:0.1 green:0.08 blue:0.25 alpha:1.0], 0.5,
        [NSColor colorWithRed:0.15 green:0.1 blue:0.35 alpha:1.0], 1.0,
        nil];
    NSImage *gradientImage = [[NSImage alloc] initWithSize:frame.size];
    [gradientImage lockFocus];
    [gradient drawInRect:NSMakeRect(0, 0, frame.size.width, frame.size.height) angle:135];
    [gradientImage unlockFocus];
    self.contentView.layer.contents = gradientImage;
    
    [self.wizardWindow setContentView:self.contentView];
    
    self.currentStep = 0;
    [self showCurrentStep];
    
    [self.wizardWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)showCurrentStep {
    for (NSView *subview in [self.contentView.subviews copy]) {
        [subview removeFromSuperview];
    }
    
    switch (self.currentStep) {
        case 0:
            [self showWelcomeStep];
            break;
        case 1:
            [self showUsernameStep];
            break;
        case 2:
            [self showAccountTypeStep];
            break;
        case 3:
            [self showPasswordStep];
            break;
        case 4:
            [self showCompleteStep];
            break;
    }
}

- (void)showWelcomeStep {
    CGFloat width = self.contentView.bounds.size.width;
    
    // Animated logo area
    NSView *logoContainer = [[NSView alloc] initWithFrame:NSMakeRect((width - 120) / 2, 280, 120, 120)];
    logoContainer.wantsLayer = YES;
    logoContainer.layer.cornerRadius = 60;
    logoContainer.layer.backgroundColor = [[NSColor colorWithWhite:1.0 alpha:0.1] CGColor];
    [self.contentView addSubview:logoContainer];
    
    NSTextField *icon = [self createLabel:@"🍎" fontSize:60 bold:NO];
    icon.frame = NSMakeRect(0, 25, 120, 70);
    icon.alignment = NSTextAlignmentCenter;
    [logoContainer addSubview:icon];
    
    NSTextField *title = [self createLabel:@"Welcome to VirtualOS" fontSize:32 bold:YES];
    title.frame = NSMakeRect(0, 220, width, 45);
    title.alignment = NSTextAlignmentCenter;
    title.textColor = [NSColor whiteColor];
    [self.contentView addSubview:title];
    
    NSTextField *subtitle = [self createLabel:@"Your new virtual operating system awaits" fontSize:16 bold:NO];
    subtitle.frame = NSMakeRect(0, 190, width, 25);
    subtitle.alignment = NSTextAlignmentCenter;
    subtitle.textColor = [NSColor colorWithWhite:0.7 alpha:1.0];
    [self.contentView addSubview:subtitle];
    
    // Feature highlights
    NSArray *features = @[@"🔒 Secure", @"⚡ Fast", @"🎨 Beautiful"];
    CGFloat featureWidth = 120;
    CGFloat startX = (width - (featureWidth * 3 + 40)) / 2;
    
    for (NSUInteger i = 0; i < features.count; i++) {
        NSView *featureBox = [[NSView alloc] initWithFrame:NSMakeRect(startX + i * (featureWidth + 20), 120, featureWidth, 50)];
        featureBox.wantsLayer = YES;
        featureBox.layer.backgroundColor = [[NSColor colorWithWhite:1.0 alpha:0.08] CGColor];
        featureBox.layer.cornerRadius = 10;
        [self.contentView addSubview:featureBox];
        
        NSTextField *featureLabel = [self createLabel:features[i] fontSize:14 bold:NO];
        featureLabel.frame = NSMakeRect(0, 15, featureWidth, 20);
        featureLabel.alignment = NSTextAlignmentCenter;
        featureLabel.textColor = [NSColor whiteColor];
        [featureBox addSubview:featureLabel];
    }
    
    NSButton *continueBtn = [self createButton:@"Get Started →" action:@selector(nextStep:)];
    continueBtn.frame = NSMakeRect((width - 180) / 2, 40, 180, 44);
    [self.contentView addSubview:continueBtn];
}

- (void)showUsernameStep {
    CGFloat width = self.contentView.bounds.size.width;
    
    // Progress indicator
    [self addProgressIndicator:1 of:3];
    
    NSTextField *title = [self createLabel:@"Create Your Account" fontSize:28 bold:YES];
    title.frame = NSMakeRect(0, 380, width, 40);
    title.alignment = NSTextAlignmentCenter;
    title.textColor = [NSColor whiteColor];
    [self.contentView addSubview:title];
    
    // Avatar circle
    NSView *avatarCircle = [[NSView alloc] initWithFrame:NSMakeRect((width - 80) / 2, 280, 80, 80)];
    avatarCircle.wantsLayer = YES;
    avatarCircle.layer.cornerRadius = 40;
    avatarCircle.layer.backgroundColor = [[NSColor colorWithWhite:1.0 alpha:0.15] CGColor];
    [self.contentView addSubview:avatarCircle];
    
    NSTextField *icon = [self createLabel:@"👤" fontSize:40 bold:NO];
    icon.frame = NSMakeRect(0, 15, 80, 50);
    icon.alignment = NSTextAlignmentCenter;
    [avatarCircle addSubview:icon];
    
    // Input card
    NSView *inputCard = [[NSView alloc] initWithFrame:NSMakeRect((width - 400) / 2, 140, 400, 120)];
    inputCard.wantsLayer = YES;
    inputCard.layer.backgroundColor = [[NSColor colorWithWhite:1.0 alpha:0.08] CGColor];
    inputCard.layer.cornerRadius = 12;
    [self.contentView addSubview:inputCard];
    
    NSTextField *label = [self createLabel:@"What's your name?" fontSize:14 bold:NO];
    label.frame = NSMakeRect(20, 80, 360, 20);
    label.textColor = [NSColor colorWithWhite:0.8 alpha:1.0];
    [inputCard addSubview:label];
    
    self.usernameField = [[NSTextField alloc] initWithFrame:NSMakeRect(20, 40, 360, 32)];
    self.usernameField.placeholderString = @"Enter your full name";
    self.usernameField.font = [NSFont systemFontOfSize:15];
    self.usernameField.bezelStyle = NSTextFieldRoundedBezel;
    self.usernameField.focusRingType = NSFocusRingTypeNone;
    [inputCard addSubview:self.usernameField];
    
    self.errorLabel = [self createLabel:@"" fontSize:12 bold:NO];
    self.errorLabel.frame = NSMakeRect(20, 12, 360, 18);
    self.errorLabel.textColor = [NSColor systemRedColor];
    [inputCard addSubview:self.errorLabel];
    
    NSButton *backBtn = [self createButton:@"Back" action:@selector(prevStep:)];
    backBtn.frame = NSMakeRect(150, 50, 120, 40);
    [self.contentView addSubview:backBtn];
    
    NSButton *continueBtn = [self createButton:@"Continue" action:@selector(validateUsername:)];
    continueBtn.frame = NSMakeRect(330, 50, 120, 40);
    [self.contentView addSubview:continueBtn];
}

- (void)showAccountTypeStep {
    CGFloat width = self.contentView.bounds.size.width;
    [self addProgressIndicator:2 of:3];
    
    NSTextField *title = [self createLabel:@"Choose Account Type" fontSize:28 bold:YES];
    title.frame = NSMakeRect(0, 380, width, 40);
    title.alignment = NSTextAlignmentCenter;
    title.textColor = [NSColor whiteColor];
    [self.contentView addSubview:title];
    
    // Standard account option
    NSView *standardBox = [[NSView alloc] initWithFrame:NSMakeRect(100, 220, 400, 70)];
    standardBox.wantsLayer = YES;
    standardBox.layer.backgroundColor = [[NSColor colorWithWhite:1.0 alpha:0.1] CGColor];
    standardBox.layer.cornerRadius = 10;
    [self.contentView addSubview:standardBox];
    
    self.standardRadio = [[NSButton alloc] initWithFrame:NSMakeRect(15, 20, 30, 30)];
    [self.standardRadio setButtonType:NSButtonTypeRadio];
    self.standardRadio.state = NSControlStateValueOn;
    self.standardRadio.target = self;
    self.standardRadio.action = @selector(accountTypeChanged:);
    self.standardRadio.tag = 0;
    [standardBox addSubview:self.standardRadio];
    
    NSTextField *standardTitle = [self createLabel:@"Standard" fontSize:16 bold:YES];
    standardTitle.frame = NSMakeRect(50, 38, 150, 22);
    standardTitle.textColor = [NSColor whiteColor];
    [standardBox addSubview:standardTitle];
    
    NSTextField *standardDesc = [self createLabel:@"Can use apps and change personal settings" fontSize:12 bold:NO];
    standardDesc.frame = NSMakeRect(50, 15, 340, 18);
    standardDesc.textColor = [NSColor colorWithWhite:0.7 alpha:1.0];
    [standardBox addSubview:standardDesc];
    
    // Admin account option
    NSView *adminBox = [[NSView alloc] initWithFrame:NSMakeRect(100, 130, 400, 70)];
    adminBox.wantsLayer = YES;
    adminBox.layer.backgroundColor = [[NSColor colorWithWhite:1.0 alpha:0.1] CGColor];
    adminBox.layer.cornerRadius = 10;
    [self.contentView addSubview:adminBox];
    
    self.adminRadio = [[NSButton alloc] initWithFrame:NSMakeRect(15, 20, 30, 30)];
    [self.adminRadio setButtonType:NSButtonTypeRadio];
    self.adminRadio.state = NSControlStateValueOff;
    self.adminRadio.target = self;
    self.adminRadio.action = @selector(accountTypeChanged:);
    self.adminRadio.tag = 1;
    [adminBox addSubview:self.adminRadio];
    
    NSTextField *adminTitle = [self createLabel:@"Administrator" fontSize:16 bold:YES];
    adminTitle.frame = NSMakeRect(50, 38, 150, 22);
    adminTitle.textColor = [NSColor whiteColor];
    [adminBox addSubview:adminTitle];
    
    NSTextField *adminDesc = [self createLabel:@"Can install apps, change settings, and manage users" fontSize:12 bold:NO];
    adminDesc.frame = NSMakeRect(50, 15, 340, 18);
    adminDesc.textColor = [NSColor colorWithWhite:0.7 alpha:1.0];
    [adminBox addSubview:adminDesc];
    
    NSButton *backBtn = [self createButton:@"Back" action:@selector(prevStep:)];
    backBtn.frame = NSMakeRect(150, 50, 120, 40);
    [self.contentView addSubview:backBtn];
    
    NSButton *continueBtn = [self createButton:@"Continue" action:@selector(nextStep:)];
    continueBtn.frame = NSMakeRect(330, 50, 120, 40);
    [self.contentView addSubview:continueBtn];
}

- (void)showPasswordStep {
    CGFloat width = self.contentView.bounds.size.width;
    [self addProgressIndicator:3 of:3];
    
    NSTextField *title = [self createLabel:@"Create a Password" fontSize:28 bold:YES];
    title.frame = NSMakeRect(0, 380, width, 40);
    title.alignment = NSTextAlignmentCenter;
    title.textColor = [NSColor whiteColor];
    [self.contentView addSubview:title];
    
    // Lock icon
    NSView *lockCircle = [[NSView alloc] initWithFrame:NSMakeRect((width - 70) / 2, 300, 70, 70)];
    lockCircle.wantsLayer = YES;
    lockCircle.layer.cornerRadius = 35;
    lockCircle.layer.backgroundColor = [[NSColor colorWithWhite:1.0 alpha:0.1] CGColor];
    [self.contentView addSubview:lockCircle];
    
    NSTextField *icon = [self createLabel:@"🔐" fontSize:35 bold:NO];
    icon.frame = NSMakeRect(0, 12, 70, 45);
    icon.alignment = NSTextAlignmentCenter;
    [lockCircle addSubview:icon];
    
    // Password input card
    NSView *inputCard = [[NSView alloc] initWithFrame:NSMakeRect((width - 400) / 2, 110, 400, 170)];
    inputCard.wantsLayer = YES;
    inputCard.layer.backgroundColor = [[NSColor colorWithWhite:1.0 alpha:0.08] CGColor];
    inputCard.layer.cornerRadius = 12;
    [self.contentView addSubview:inputCard];
    
    NSTextField *passLabel = [self createLabel:@"Password" fontSize:13 bold:NO];
    passLabel.frame = NSMakeRect(150, 240, 300, 20);
    passLabel.textColor = [NSColor whiteColor];
    [self.contentView addSubview:passLabel];
    
    self.passwordField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(150, 210, 300, 28)];
    self.passwordField.placeholderString = @"Enter password";
    self.passwordField.font = [NSFont systemFontOfSize:14];
    self.passwordField.bezelStyle = NSTextFieldRoundedBezel;
    [self.contentView addSubview:self.passwordField];
    
    NSTextField *confirmLabel = [self createLabel:@"Confirm Password:" fontSize:14 bold:NO];
    confirmLabel.frame = NSMakeRect(150, 175, 300, 20);
    confirmLabel.textColor = [NSColor whiteColor];
    [self.contentView addSubview:confirmLabel];
    
    self.confirmPasswordField = [[NSSecureTextField alloc] initWithFrame:NSMakeRect(150, 145, 300, 28)];
    self.confirmPasswordField.placeholderString = @"Re-enter password";
    self.confirmPasswordField.font = [NSFont systemFontOfSize:14];
    self.confirmPasswordField.bezelStyle = NSTextFieldRoundedBezel;
    [self.contentView addSubview:self.confirmPasswordField];
    
    self.errorLabel = [self createLabel:@"" fontSize:12 bold:NO];
    self.errorLabel.frame = NSMakeRect(150, 115, 300, 20);
    self.errorLabel.textColor = [NSColor systemRedColor];
    [self.contentView addSubview:self.errorLabel];
    
    NSButton *backBtn = [self createButton:@"Back" action:@selector(prevStep:)];
    backBtn.frame = NSMakeRect(150, 50, 120, 40);
    [self.contentView addSubview:backBtn];
    
    NSButton *continueBtn = [self createButton:@"Continue" action:@selector(validatePassword:)];
    continueBtn.frame = NSMakeRect(330, 50, 120, 40);
    [self.contentView addSubview:continueBtn];
}

- (void)showCompleteStep {
    NSTextField *title = [self createLabel:@"You're All Set!" fontSize:36 bold:YES];
    title.frame = NSMakeRect(0, 320, 600, 50);
    title.alignment = NSTextAlignmentCenter;
    title.textColor = [NSColor whiteColor];
    [self.contentView addSubview:title];
    
    NSTextField *icon = [self createLabel:@"✅" fontSize:80 bold:NO];
    icon.frame = NSMakeRect(0, 200, 600, 100);
    icon.alignment = NSTextAlignmentCenter;
    [self.contentView addSubview:icon];
    
    NSString *welcomeText = [NSString stringWithFormat:@"Welcome, %@!\nYour %@ account is ready.", 
                             self.username, self.adminAccount ? @"administrator" : @"standard"];
    NSTextField *subtitle = [self createLabel:welcomeText fontSize:16 bold:NO];
    subtitle.frame = NSMakeRect(0, 150, 600, 50);
    subtitle.alignment = NSTextAlignmentCenter;
    subtitle.textColor = [NSColor colorWithWhite:0.8 alpha:1.0];
    [self.contentView addSubview:subtitle];
    
    NSButton *finishBtn = [self createButton:@"Start Using VirtualOS" action:@selector(finishSetup:)];
    finishBtn.frame = NSMakeRect(200, 50, 200, 40);
    [self.contentView addSubview:finishBtn];
}

#pragma mark - Actions

- (void)nextStep:(id)sender {
    self.currentStep++;
    [self showCurrentStep];
}

- (void)prevStep:(id)sender {
    if (self.currentStep > 0) {
        self.currentStep--;
        [self showCurrentStep];
    }
}

- (void)validateUsername:(id)sender {
    NSString *name = self.usernameField.stringValue;
    if (name.length < 2) {
        self.errorLabel.stringValue = @"Please enter a valid name (at least 2 characters)";
        return;
    }
    self.username = name;
    self.currentStep++;
    [self showCurrentStep];
}

- (void)accountTypeChanged:(NSButton *)sender {
    if (sender.tag == 0) {
        self.standardRadio.state = NSControlStateValueOn;
        self.adminRadio.state = NSControlStateValueOff;
        self.adminAccount = NO;
    } else {
        self.standardRadio.state = NSControlStateValueOff;
        self.adminRadio.state = NSControlStateValueOn;
        self.adminAccount = YES;
    }
}

- (void)validatePassword:(id)sender {
    NSString *pass1 = self.passwordField.stringValue;
    NSString *pass2 = self.confirmPasswordField.stringValue;
    
    if (pass1.length < 4) {
        self.errorLabel.stringValue = @"Password must be at least 4 characters";
        return;
    }
    
    if (![pass1 isEqualToString:pass2]) {
        self.errorLabel.stringValue = @"Passwords do not match";
        return;
    }
    
    self.password = pass1;
    self.currentStep++;
    [self showCurrentStep];
}

- (void)finishSetup:(id)sender {
    self.setupComplete = YES;
    [self saveSetupState];
    
    // Defer window close to avoid crash - we're still in button callback
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.wizardWindow orderOut:nil];
        self.wizardWindow = nil;
        self.contentView = nil;
    });
}

- (void)addProgressIndicator:(NSInteger)step of:(NSInteger)total {
    CGFloat width = self.contentView.bounds.size.width;
    CGFloat dotSize = 10;
    CGFloat spacing = 20;
    CGFloat totalWidth = (dotSize * total) + (spacing * (total - 1));
    CGFloat startX = (width - totalWidth) / 2;
    
    for (NSInteger i = 0; i < total; i++) {
        NSView *dot = [[NSView alloc] initWithFrame:NSMakeRect(startX + i * (dotSize + spacing), 440, dotSize, dotSize)];
        dot.wantsLayer = YES;
        dot.layer.cornerRadius = dotSize / 2;
        
        if (i < step) {
            dot.layer.backgroundColor = [[NSColor systemBlueColor] CGColor];
        } else if (i == step) {
            dot.layer.backgroundColor = [[NSColor whiteColor] CGColor];
        } else {
            dot.layer.backgroundColor = [[NSColor colorWithWhite:0.4 alpha:1.0] CGColor];
        }
        
        [self.contentView addSubview:dot];
    }
}

#pragma mark - Helpers

- (NSTextField *)createLabel:(NSString *)text fontSize:(CGFloat)size bold:(BOOL)bold {
    NSTextField *label = [[NSTextField alloc] init];
    label.stringValue = text;
    label.font = bold ? [NSFont boldSystemFontOfSize:size] : [NSFont systemFontOfSize:size];
    label.bezeled = NO;
    label.editable = NO;
    label.drawsBackground = NO;
    label.selectable = NO;
    return label;
}

- (NSButton *)createButton:(NSString *)title action:(SEL)action primary:(BOOL)primary {
    NSButton *btn = [[NSButton alloc] init];
    btn.title = title;
    btn.bezelStyle = NSBezelStyleRounded;
    btn.target = self;
    btn.action = action;
    btn.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    btn.wantsLayer = YES;
    
    if (primary) {
        btn.contentTintColor = [NSColor whiteColor];
        btn.layer.backgroundColor = [[NSColor systemBlueColor] CGColor];
        btn.layer.cornerRadius = 8;
    }
    
    return btn;
}

- (NSButton *)createButton:(NSString *)title action:(SEL)action {
    return [self createButton:title action:action primary:YES];
}

@end
