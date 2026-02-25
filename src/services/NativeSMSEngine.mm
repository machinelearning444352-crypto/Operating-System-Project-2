#import "NativeSMSEngine.h"

@implementation NativeSMSMessage

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
  self = [super init];
  if (self) {
    _messageId = [coder decodeObjectOfClass:[NSString class]
                                     forKey:@"messageId"];
    _text = [coder decodeObjectOfClass:[NSString class] forKey:@"text"];
    _recipientNumber = [coder decodeObjectOfClass:[NSString class]
                                           forKey:@"recipientNumber"];
    _carrier = (SMSCarrierType)[coder decodeIntegerForKey:@"carrier"];
    _timestamp = [coder decodeObjectOfClass:[NSDate class] forKey:@"timestamp"];
    _isFromMe = [coder decodeBoolForKey:@"isFromMe"];
    _isDelivered = [coder decodeBoolForKey:@"isDelivered"];
    _errorString = [coder decodeObjectOfClass:[NSString class]
                                       forKey:@"errorString"];
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
  [coder encodeObject:self.messageId forKey:@"messageId"];
  [coder encodeObject:self.text forKey:@"text"];
  [coder encodeObject:self.recipientNumber forKey:@"recipientNumber"];
  [coder encodeInteger:self.carrier forKey:@"carrier"];
  [coder encodeObject:self.timestamp forKey:@"timestamp"];
  [coder encodeBool:self.isFromMe forKey:@"isFromMe"];
  [coder encodeBool:self.isDelivered forKey:@"isDelivered"];
  [coder encodeObject:self.errorString forKey:@"errorString"];
}
@end

@interface NativeSMSEngine ()
@property(nonatomic, strong) NSInputStream *inputStream;
@property(nonatomic, strong) NSOutputStream *outputStream;
@property(nonatomic, strong) NSMutableArray<NativeSMSMessage *> *messageHistory;
@property(nonatomic, assign) SMTPConnectionState state;
@property(nonatomic, copy) SMSSendCompletion currentCompletion;
@property(nonatomic, strong) NativeSMSMessage *currentMessage;
@property(nonatomic, strong) NSString *currentRecipientEmail;
@end

@implementation NativeSMSEngine

+ (instancetype)sharedInstance {
  static NativeSMSEngine *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[NativeSMSEngine alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _smtpServer = @"smtp.gmail.com";
    _smtpPort = 587;
    _useTLS = YES;
    _messageHistory = [NSMutableArray array];
    _state = SMTPStateDisconnected;
    [self loadConfig];
    [self loadHistory];
  }
  return self;
}

- (void)loadConfig {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  self.userEmail = [defaults stringForKey:@"NativeSMSEmail"];
  self.appPassword = [defaults stringForKey:@"NativeSMSAppPassword"];
  NSString *server = [defaults stringForKey:@"NativeSMSServer"];
  if (server.length > 0) {
    self.smtpServer = server;
    self.smtpPort = [defaults integerForKey:@"NativeSMSPort"];
  }
}

- (void)saveConfig {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  [defaults setObject:self.userEmail forKey:@"NativeSMSEmail"];
  [defaults setObject:self.appPassword forKey:@"NativeSMSAppPassword"];
  [defaults setObject:self.smtpServer forKey:@"NativeSMSServer"];
  [defaults setInteger:self.smtpPort forKey:@"NativeSMSPort"];
  [defaults synchronize];
}

- (BOOL)isConfigured {
  return self.userEmail.length > 0 && self.appPassword.length > 0;
}

+ (NSString *)gatewayForCarrier:(SMSCarrierType)carrier {
  switch (carrier) {
  case CarrierATT:
    return @"txt.att.net";
  case CarrierVerizon:
    return @"vtext.com";
  case CarrierTMobile:
    return @"tmomail.net";
  case CarrierSprint:
    return @"messaging.sprintpcs.com";
  case CarrierBoostMobile:
    return @"sms.myboostmobile.com";
  case CarrierCricket:
    return @"mms.cricketwireless.net";
  case CarrierUSCellular:
    return @"email.uscc.net";
  default:
    return @"txt.att.net";
  }
}

- (void)sendSMS:(NSString *)text
       toNumber:(NSString *)phoneNumber
        carrier:(SMSCarrierType)carrier
     completion:(SMSSendCompletion)completion {

  if (![self isConfigured]) {
    if (completion)
      completion(NO, nil,
                 [NSError errorWithDomain:@"NativeSMSEngineErrorDomain"
                                     code:1
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Email or App Password not configured."
                                 }]);
    return;
  }

  // Clean up phone number
  NSString *cleanNumber = [[phoneNumber
      componentsSeparatedByCharactersInSet:[[NSCharacterSet
                                               decimalDigitCharacterSet]
                                               invertedSet]]
      componentsJoinedByString:@""];

  if (cleanNumber.length < 10) {
    if (completion)
      completion(NO, nil,
                 [NSError errorWithDomain:@"NativeSMSEngineErrorDomain"
                                     code:2
                                 userInfo:@{
                                   NSLocalizedDescriptionKey :
                                       @"Invalid phone number format."
                                 }]);
    return;
  }

  // Format recipient
  if (cleanNumber.length == 11 && [cleanNumber hasPrefix:@"1"]) {
    cleanNumber = [cleanNumber substringFromIndex:1];
  }

  self.currentRecipientEmail =
      [NSString stringWithFormat:@"%@@%@", cleanNumber,
                                 [NativeSMSEngine gatewayForCarrier:carrier]];

  self.currentMessage = [[NativeSMSMessage alloc] init];
  self.currentMessage.messageId = [[NSUUID UUID] UUIDString];
  self.currentMessage.text = text;
  self.currentMessage.recipientNumber = cleanNumber;
  self.currentMessage.carrier = carrier;
  self.currentMessage.timestamp = [NSDate date];
  self.currentMessage.isFromMe = YES;

  self.currentCompletion = completion;

  [self startSMTPConnection];
}

- (void)startSMTPConnection {
  CFReadStreamRef readStream;
  CFWriteStreamRef writeStream;

  CFStreamCreatePairWithSocketToHost(
      NULL, (__bridge CFStringRef)self.smtpServer, (UInt32)self.smtpPort,
      &readStream, &writeStream);

  self.inputStream = (__bridge_transfer NSInputStream *)readStream;
  self.outputStream = (__bridge_transfer NSOutputStream *)writeStream;

  self.inputStream.delegate = self;
  self.outputStream.delegate = self;

  [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                              forMode:NSDefaultRunLoopMode];
  [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                               forMode:NSDefaultRunLoopMode];

  self.state = SMTPStateConnecting;

  [self.inputStream open];
  [self.outputStream open];
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
  switch (eventCode) {
  case NSStreamEventOpenCompleted:
    if (aStream == self.inputStream) {
      // Connection opened, wait for server greeting
    }
    break;

  case NSStreamEventHasBytesAvailable:
    if (aStream == self.inputStream) {
      [self processServerResponse];
    }
    break;

  case NSStreamEventErrorOccurred:
    [self finishWithError:[aStream streamError]];
    break;

  case NSStreamEventEndEncountered:
    if (self.state != SMTPStateWaitingQuit &&
        self.state != SMTPStateDisconnected) {
      [self finishWithError:[NSError
                                errorWithDomain:@"NativeSMSEngineErrorDomain"
                                           code:3
                                       userInfo:@{
                                         NSLocalizedDescriptionKey :
                                             @"Connection closed unexpectedly."
                                       }]];
    }
    break;

  default:
    break;
  }
}

- (void)processServerResponse {
  uint8_t buffer[1024];
  NSInteger len = [self.inputStream read:buffer maxLength:sizeof(buffer)];
  if (len > 0) {
    NSString *response = [[NSString alloc] initWithBytes:buffer
                                                  length:len
                                                encoding:NSUTF8StringEncoding];

    NSArray *lines = [response
        componentsSeparatedByCharactersInSet:[NSCharacterSet
                                                 newlineCharacterSet]];

    for (NSString *line in lines) {
      if (line.length < 3)
        continue;

      NSInteger code = [[line substringToIndex:3] integerValue];
      [self handleSMTPCode:code line:line];
    }
  }
}

- (void)handleSMTPCode:(NSInteger)code line:(NSString *)line {
  switch (self.state) {
  case SMTPStateConnecting:
    if (code == 220) {
      self.state = SMTPStateWaitingEHLO;
      [self sendCommand:@"EHLO localhost\r\n"];
    } else {
      [self
          finishWithErrorString:[NSString
                                    stringWithFormat:@"Connection rejected: %@",
                                                     line]];
    }
    break;

  case SMTPStateWaitingEHLO:
    // EHLO response can be multiple lines (250- or 250 ). We wait for the final
    // 250(space).
    if (code == 250 && [line characterAtIndex:3] == ' ') {
      if (self.useTLS) {
        self.state = SMTPStateWaitingSTARTTLS;
        [self sendCommand:@"STARTTLS\r\n"];
      } else {
        self.state = SMTPStateWaitingAuthLogin;
        [self sendCommand:@"AUTH LOGIN\r\n"];
      }
    }
    break;

  case SMTPStateWaitingSTARTTLS:
    if (code == 220) {
      // Upgrade to TLS
      NSDictionary *settings = @{
        (__bridge NSString *)kCFStreamSSLLevel :
            (__bridge NSString *)kCFStreamSocketSecurityLevelNegotiatedSSL
      };
      [self.inputStream
          setProperty:settings
               forKey:(__bridge NSString *)kCFStreamPropertySSLSettings];
      [self.outputStream
          setProperty:settings
               forKey:(__bridge NSString *)kCFStreamPropertySSLSettings];

      self.state = SMTPStateWaitingEHLO2;
      [self sendCommand:@"EHLO localhost\r\n"];
    } else {
      [self finishWithErrorString:[NSString
                                      stringWithFormat:@"STARTTLS failed: %@",
                                                       line]];
    }
    break;

  case SMTPStateWaitingEHLO2:
    if (code == 250 && [line characterAtIndex:3] == ' ') {
      self.state = SMTPStateWaitingAuthLogin;
      [self sendCommand:@"AUTH LOGIN\r\n"];
    }
    break;

  case SMTPStateWaitingAuthLogin:
    if (code == 334) {
      self.state = SMTPStateWaitingAuthUser;
      NSData *userData =
          [self.userEmail dataUsingEncoding:NSUTF8StringEncoding];
      NSString *userBase64 = [userData base64EncodedStringWithOptions:0];
      [self sendCommand:[NSString stringWithFormat:@"%@\r\n", userBase64]];
    } else {
      [self finishWithErrorString:[NSString
                                      stringWithFormat:@"AUTH LOGIN failed: %@",
                                                       line]];
    }
    break;

  case SMTPStateWaitingAuthUser:
    if (code == 334) {
      self.state = SMTPStateWaitingAuthPass;
      NSData *passData =
          [self.appPassword dataUsingEncoding:NSUTF8StringEncoding];
      NSString *passBase64 = [passData base64EncodedStringWithOptions:0];
      [self sendCommand:[NSString stringWithFormat:@"%@\r\n", passBase64]];
    } else {
      [self
          finishWithErrorString:[NSString
                                    stringWithFormat:@"Auth failed (user): %@",
                                                     line]];
    }
    break;

  case SMTPStateWaitingAuthPass:
    if (code == 235) {
      self.state = SMTPStateWaitingMailFrom;
      [self sendCommand:[NSString stringWithFormat:@"MAIL FROM:<%@>\r\n",
                                                   self.userEmail]];
    } else {
      [self finishWithErrorString:
                [NSString
                    stringWithFormat:
                        @"Auth failed (pass) - check App Password: %@", line]];
    }
    break;

  case SMTPStateWaitingMailFrom:
    if (code == 250) {
      self.state = SMTPStateWaitingRcptTo;
      [self sendCommand:[NSString stringWithFormat:@"RCPT TO:<%@>\r\n",
                                                   self.currentRecipientEmail]];
    } else {
      [self
          finishWithErrorString:[NSString
                                    stringWithFormat:@"MAIL FROM rejected: %@",
                                                     line]];
    }
    break;

  case SMTPStateWaitingRcptTo:
    if (code == 250 || code == 251) {
      self.state = SMTPStateWaitingData;
      [self sendCommand:@"DATA\r\n"];
    } else {
      [self finishWithErrorString:[NSString
                                      stringWithFormat:@"RCPT TO rejected: %@",
                                                       line]];
    }
    break;

  case SMTPStateWaitingData:
    if (code == 354) {
      self.state = SMTPStateWaitingDataContent;

      // Construct RFC2822 email payload over SMS
      NSString *dateString = [self rfc2822DateString];
      NSString *dataContent =
          [NSString stringWithFormat:@"From: %@\r\n"
                                      "To: %@\r\n"
                                      "Date: %@\r\n"
                                      "Subject: \r\n"
                                      "\r\n"
                                      "%@\r\n.\r\n",
                                     self.userEmail, self.currentRecipientEmail,
                                     dateString, self.currentMessage.text];

      [self sendCommand:dataContent];
    } else {
      [self finishWithErrorString:
                [NSString stringWithFormat:@"DATA command rejected: %@", line]];
    }
    break;

  case SMTPStateWaitingDataContent:
    if (code == 250) {
      self.state = SMTPStateWaitingQuit;
      self.currentMessage.isDelivered = YES;
      [self.messageHistory addObject:self.currentMessage];
      [self saveHistory];

      if (self.currentCompletion) {
        dispatch_async(dispatch_get_main_queue(), ^{
          self.currentCompletion(YES, self.currentMessage, nil);
          self.currentCompletion = nil;
        });
      }
      [self sendCommand:@"QUIT\r\n"];
    } else {
      [self finishWithErrorString:
                [NSString
                    stringWithFormat:@"Message content rejected: %@", line]];
    }
    break;

  case SMTPStateWaitingQuit:
    if (code == 221) {
      [self closeConnection];
    }
    break;

  default:
    break;
  }
}

- (void)sendCommand:(NSString *)command {
  if (self.outputStream && [self.outputStream hasSpaceAvailable]) {
    NSData *data = [command dataUsingEncoding:NSUTF8StringEncoding];
    [self.outputStream write:(const uint8_t *)[data bytes]
                   maxLength:[data length]];
  }
}

- (void)finishWithErrorString:(NSString *)errorMsg {
  [self finishWithError:[NSError errorWithDomain:@"NativeSMSEngineErrorDomain"
                                            code:4
                                        userInfo:@{
                                          NSLocalizedDescriptionKey : errorMsg
                                        }]];
}

- (void)finishWithError:(NSError *)error {
  self.currentMessage.errorString = error.localizedDescription;
  self.currentMessage.isDelivered = NO;
  [self.messageHistory addObject:self.currentMessage];
  [self saveHistory];

  if (self.currentCompletion) {
    dispatch_async(dispatch_get_main_queue(), ^{
      self.currentCompletion(NO, self.currentMessage, error);
      self.currentCompletion = nil;
    });
  }
  [self closeConnection];
}

- (void)closeConnection {
  self.state = SMTPStateDisconnected;

  if (self.inputStream) {
    [self.inputStream close];
    [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop]
                                forMode:NSDefaultRunLoopMode];
    self.inputStream.delegate = nil;
    self.inputStream = nil;
  }

  if (self.outputStream) {
    [self.outputStream close];
    [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop]
                                 forMode:NSDefaultRunLoopMode];
    self.outputStream.delegate = nil;
    self.outputStream = nil;
  }
}

- (NSString *)rfc2822DateString {
  NSDateFormatter *rfc2822Formatter = [[NSDateFormatter alloc] init];
  rfc2822Formatter.locale =
      [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
  rfc2822Formatter.dateFormat = @"EEE, dd MMM yyyy HH:mm:ss Z";
  return [rfc2822Formatter stringFromDate:[NSDate date]];
}

// MARK: - History
- (NSString *)historyFilePath {
  NSString *appSupport = [NSSearchPathForDirectoriesInDomains(
      NSApplicationSupportDirectory, NSUserDomainMask, YES) firstObject];
  NSString *appFolder =
      [appSupport stringByAppendingPathComponent:@"macOSDesktop"];
  [[NSFileManager defaultManager] createDirectoryAtPath:appFolder
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
  return [appFolder stringByAppendingPathComponent:@"sms_history.dat"];
}

- (void)saveHistory {
  NSError *error = nil;
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.messageHistory
                                       requiringSecureCoding:YES
                                                       error:&error];
  if (data) {
    [data writeToFile:[self historyFilePath] atomically:YES];
  }
}

- (void)loadHistory {
  NSData *data = [NSData dataWithContentsOfFile:[self historyFilePath]];
  if (data) {
    NSError *error = nil;
    NSSet *classes =
        [NSSet setWithObjects:[NSArray class], [NativeSMSMessage class],
                              [NSString class], [NSDate class], nil];
    NSArray *saved = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                         fromData:data
                                                            error:&error];
    if (saved) {
      [self.messageHistory removeAllObjects];
      [self.messageHistory addObjectsFromArray:saved];
    }
  }
}

- (NSArray<NativeSMSMessage *> *)allMessages {
  return [self.messageHistory copy];
}

- (void)clearAllMessages {
  [self.messageHistory removeAllObjects];
  [self saveHistory];
}

@end
