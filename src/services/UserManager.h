#import <Foundation/Foundation.h>

@interface UserManager : NSObject

+ (instancetype)sharedInstance;

- (BOOL)isSetupComplete;
- (void)markSetupComplete;

- (NSArray<NSDictionary *> *)getAllUsers;
- (NSDictionary *)getUser:(NSString *)username;
- (BOOL)createUser:(NSString *)username password:(NSString *)password isAdmin:(BOOL)isAdmin;
- (BOOL)deleteUser:(NSString *)username;
- (BOOL)changePasswordForUser:(NSString *)username newPassword:(NSString *)newPassword;

// Guest User
- (BOOL)isGuestEnabled;
- (void)setGuestEnabled:(BOOL)enabled;

// Authentication
- (BOOL)authenticateUser:(NSString *)username password:(NSString *)password;
- (void)loginUser:(NSString *)username;
- (void)logoutCurrentUser;

// Current Session
- (NSString *)currentUsername;
- (BOOL)isCurrentUserAdmin;
- (BOOL)isCurrentUserGuest;

@end
