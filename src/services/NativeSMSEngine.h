#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SMSCarrierType) {
  CarrierATT,
  CarrierVerizon,
  CarrierTMobile,
  CarrierSprint,
  CarrierBoostMobile,
  CarrierCricket,
  CarrierUSCellular
};

typedef NS_ENUM(NSInteger, SMTPConnectionState) {
  SMTPStateDisconnected,
  SMTPStateConnecting,
  SMTPStateConnected,
  SMTPStateWaitingEHLO,
  SMTPStateWaitingSTARTTLS,
  SMTPStateWaitingEHLO2,
  SMTPStateWaitingAuthLogin,
  SMTPStateWaitingAuthUser,
  SMTPStateWaitingAuthPass,
  SMTPStateWaitingMailFrom,
  SMTPStateWaitingRcptTo,
  SMTPStateWaitingData,
  SMTPStateWaitingDataContent,
  SMTPStateWaitingQuit,
  SMTPStateError
};

@class NativeSMSMessage;

typedef void (^SMSSendCompletion)(BOOL success,
                                  NativeSMSMessage *_Nullable message,
                                  NSError *_Nullable error);

@interface NativeSMSMessage : NSObject <NSSecureCoding>
@property(nonatomic, strong) NSString *messageId;
@property(nonatomic, strong) NSString *text;
@property(nonatomic, strong) NSString *recipientNumber;
@property(nonatomic, assign) SMSCarrierType carrier;
@property(nonatomic, strong) NSDate *timestamp;
@property(nonatomic, assign) BOOL isFromMe;
@property(nonatomic, assign) BOOL isDelivered;
@property(nonatomic, strong) NSString *errorString;
@end

@interface NativeSMSEngine : NSObject <NSStreamDelegate>

@property(nonatomic, strong, nullable) NSString *userEmail;
@property(nonatomic, strong, nullable) NSString *appPassword;
@property(nonatomic, strong) NSString *smtpServer;
@property(nonatomic, assign) NSInteger smtpPort;
@property(nonatomic, assign) BOOL useTLS;

+ (instancetype)sharedInstance;

- (BOOL)isConfigured;

- (void)sendSMS:(NSString *)text
       toNumber:(NSString *)phoneNumber
        carrier:(SMSCarrierType)carrier
     completion:(SMSSendCompletion)completion;

+ (NSString *)gatewayForCarrier:(SMSCarrierType)carrier;

- (NSArray<NativeSMSMessage *> *)allMessages;
- (void)clearAllMessages;

@end

NS_ASSUME_NONNULL_END
