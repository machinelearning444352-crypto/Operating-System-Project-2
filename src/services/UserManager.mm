#import "UserManager.h"

@interface UserManager ()
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *users;
@property(nonatomic, strong) NSString *currentUser;
@property(nonatomic, assign) BOOL isSetup;
@property(nonatomic, assign) BOOL guestEnabled;
@end

@implementation UserManager

+ (instancetype)sharedInstance {
  static UserManager *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[UserManager alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _users = [NSMutableArray array];
    _currentUser = nil;
    [self loadUsers];
  }
  return self;
}

- (NSString *)appDataPath {
  NSString *appSupport = [NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
  NSString *folder =
      [appSupport stringByAppendingPathComponent:@"macOSDesktop"];
  [[NSFileManager defaultManager] createDirectoryAtPath:folder
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  return folder;
}

- (NSString *)usersFilePath {
  return [[self appDataPath] stringByAppendingPathComponent:@"users.plist"];
}

- (void)loadUsers {
  NSDictionary *data =
      [NSDictionary dictionaryWithContentsOfFile:[self usersFilePath]];
  if (data) {
    self.users = [data[@"users"] mutableCopy] ?: [NSMutableArray array];
    self.isSetup = [data[@"isSetup"] boolValue];
    self.guestEnabled = [data[@"guestEnabled"] boolValue];
  } else {
    self.isSetup = NO;
    self.guestEnabled = YES; // Default
  }
}

- (void)saveUsers {
  NSDictionary *data = @{
    @"users" : self.users,
    @"isSetup" : @(self.isSetup),
    @"guestEnabled" : @(self.guestEnabled)
  };
  [data writeToFile:[self usersFilePath] atomically:YES];
}

- (BOOL)isSetupComplete {
  return self.isSetup;
}

- (void)markSetupComplete {
  self.isSetup = YES;
  [self saveUsers];
}

// Basic Caesar cipher for demonstration (Since CommonCrypto sometimes requires
// extra headers)
- (NSString *)hashPassword:(NSString *)password {
  if (!password)
    return @"";
  NSMutableString *hashed = [NSMutableString string];
  for (NSUInteger i = 0; i < password.length; i++) {
    unichar c = [password characterAtIndex:i];
    [hashed appendFormat:@"%C", (unichar)(c + 7)]; // Shift by 7
  }
  return hashed;
}

- (NSArray<NSDictionary *> *)getAllUsers {
  return [self.users copy];
}

- (NSDictionary *)getUser:(NSString *)username {
  for (NSDictionary *u in self.users) {
    if ([u[@"username"] isEqualToString:username]) {
      return u;
    }
  }
  return nil;
}

- (BOOL)createUser:(NSString *)username
          password:(NSString *)password
           isAdmin:(BOOL)isAdmin {
  if (!username || username.length == 0 || [self getUser:username]) {
    return NO;
  }
  NSDictionary *newUser = @{
    @"username" : username,
    @"passwordHash" : [self hashPassword:password],
    @"isAdmin" : @(isAdmin)
  };
  [self.users addObject:newUser];
  [self saveUsers];
  return YES;
}

- (BOOL)deleteUser:(NSString *)username {
  NSDictionary *u = [self getUser:username];
  if (u) {
    [self.users removeObject:u];
    [self saveUsers];
    return YES;
  }
  return NO;
}

- (BOOL)changePasswordForUser:(NSString *)username
                  newPassword:(NSString *)newPassword {
  for (NSUInteger i = 0; i < self.users.count; i++) {
    if ([self.users[i][@"username"] isEqualToString:username]) {
      NSMutableDictionary *u = [self.users[i] mutableCopy];
      u[@"passwordHash"] = [self hashPassword:newPassword];
      self.users[i] = [u copy];
      [self saveUsers];
      return YES;
    }
  }
  return NO;
}

- (BOOL)isGuestEnabled {
  return self.guestEnabled;
}

- (void)setGuestEnabled:(BOOL)enabled {
  _guestEnabled = enabled;
  [self saveUsers];
}

- (BOOL)authenticateUser:(NSString *)username password:(NSString *)password {
  NSDictionary *u = [self getUser:username];
  if (!u)
    return NO;
  NSString *hash = [self hashPassword:password];
  return [u[@"passwordHash"] isEqualToString:hash];
}

- (void)loginUser:(NSString *)username {
  if ([username isEqualToString:@"Guest User"] && self.guestEnabled) {
    self.currentUser = username;
  } else if ([self getUser:username]) {
    self.currentUser = username;
  }
}

- (void)logoutCurrentUser {
  self.currentUser = nil;
}

- (NSString *)currentUsername {
  return self.currentUser;
}

- (BOOL)isCurrentUserAdmin {
  if ([self isCurrentUserGuest])
    return NO;
  NSDictionary *u = [self getUser:self.currentUser];
  return [u[@"isAdmin"] boolValue];
}

- (BOOL)isCurrentUserGuest {
  return [self.currentUser isEqualToString:@"Guest User"];
}

@end
