#import "CrossPlatformCommandEngine.h"
#import <pwd.h>
#import <grp.h>

@implementation CrossPlatformCommandEngine (UserCommands)

#pragma mark - User Management

- (CPCommandResult *)cmdUseradd:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"useradd: requires root privileges, use dscl on macOS" code:1];
}

- (CPCommandResult *)cmdAdduser:(NSArray *)args {
    return [self cmdUseradd:args];
}

- (CPCommandResult *)cmdUserdel:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"userdel: requires root privileges" code:1];
}

- (CPCommandResult *)cmdDeluser:(NSArray *)args {
    return [self cmdUserdel:args];
}

- (CPCommandResult *)cmdUsermod:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"usermod: requires root privileges" code:1];
}

- (CPCommandResult *)cmdPasswd:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"passwd: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdChage:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"chage: Linux only" code:1];
}

#pragma mark - Group Management

- (CPCommandResult *)cmdGroupadd:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"groupadd: requires root privileges" code:1];
}

- (CPCommandResult *)cmdGroupdel:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"groupdel: requires root privileges" code:1];
}

- (CPCommandResult *)cmdGroupmod:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"groupmod: requires root privileges" code:1];
}

- (CPCommandResult *)cmdGpasswd:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"gpasswd: requires root privileges" code:1];
}

- (CPCommandResult *)cmdNewgrp:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"newgrp: not supported in simulated environment" code:1];
}

#pragma mark - Privilege Elevation

- (CPCommandResult *)cmdSu:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"su: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdSudo:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"sudo: missing command" code:1];
    }
    
    return [CPCommandResult errorWithMessage:@"sudo: password required (simulated environment)" code:1];
}

- (CPCommandResult *)cmdVisudo:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"visudo: interactive editor not supported" code:1];
}

#pragma mark - Shell/User Info

- (CPCommandResult *)cmdChsh:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"chsh: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdChfn:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"chfn: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdFinger:(NSArray *)args {
    NSString *user = args.count > 0 ? args[0] : NSUserName();
    
    struct passwd *pw = getpwnam([user UTF8String]);
    if (!pw) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"finger: %@: no such user", user] code:1];
    }
    
    NSMutableString *output = [NSMutableString string];
    [output appendFormat:@"Login: %-16s\t\tName: %s\n", pw->pw_name, pw->pw_gecos];
    [output appendFormat:@"Directory: %-24s\tShell: %s\n", pw->pw_dir, pw->pw_shell];
    [output appendString:@"Never logged in.\n"];
    [output appendString:@"No mail.\n"];
    [output appendString:@"No Plan.\n"];
    
    return [CPCommandResult successWithOutput:output];
}

- (CPCommandResult *)cmdPinky:(NSArray *)args {
    return [self cmdFinger:args];
}

#pragma mark - macOS Directory Services

- (CPCommandResult *)cmdDscl:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"dscl: missing datasource" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/dscl";
    task.arguments = args;
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        CPCommandResult *result = [CPCommandResult successWithOutput:output ?: @""];
        result.exitCode = task.terminationStatus;
        result.success = (task.terminationStatus == 0);
        return result;
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"dscl: failed" code:1];
    }
}

- (CPCommandResult *)cmdDseditgroup:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"dseditgroup: requires admin privileges" code:1];
}

- (CPCommandResult *)cmdSysadminctl:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"sysadminctl: requires admin privileges" code:1];
}

#pragma mark - Windows Commands

- (CPCommandResult *)cmdNet_user:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"net user: Windows only" code:1];
}

- (CPCommandResult *)cmdNet_localgroup:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"net localgroup: Windows only" code:1];
}

- (CPCommandResult *)cmdWmic:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"wmic: Windows only" code:1];
}

- (CPCommandResult *)cmdRunas:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"runas: Windows only, use sudo on Unix" code:1];
}

@end
