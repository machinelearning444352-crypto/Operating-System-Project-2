#import "CrossPlatformCommandEngine.h"

@implementation CrossPlatformCommandEngine (PackageCommands)

#pragma mark - macOS Package Managers

- (CPCommandResult *)cmdBrew:(NSArray *)args {
    if (args.count == 0) {
        return [CPCommandResult errorWithMessage:@"brew: missing command" code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/opt/homebrew/bin/brew";
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:task.launchPath]) {
        task.launchPath = @"/usr/local/bin/brew";
    }
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:task.launchPath]) {
        return [CPCommandResult errorWithMessage:@"brew: Homebrew is not installed" code:1];
    }
    
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
        return [CPCommandResult errorWithMessage:@"brew: failed" code:1];
    }
}

- (CPCommandResult *)cmdPort:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"port: MacPorts not installed" code:1];
}

- (CPCommandResult *)cmdMas:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"mas: not installed, install via 'brew install mas'" code:1];
}

- (CPCommandResult *)cmdSoftwareupdate:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/sbin/softwareupdate";
    task.arguments = args.count > 0 ? args : @[@"-l"];
    
    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *data = [[pipe fileHandleForReading] readDataToEndOfFile];
        NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return [CPCommandResult successWithOutput:output ?: @""];
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:@"softwareupdate: failed" code:1];
    }
}

#pragma mark - Debian/Ubuntu

- (CPCommandResult *)cmdApt:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"apt: Linux only, use 'brew' on macOS" code:1];
}

- (CPCommandResult *)cmdAptGet:(NSArray *)args {
    return [self cmdApt:args];
}

- (CPCommandResult *)cmdAptCache:(NSArray *)args {
    return [self cmdApt:args];
}

- (CPCommandResult *)cmdDpkg:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"dpkg: Linux only" code:1];
}

#pragma mark - Red Hat/Fedora

- (CPCommandResult *)cmdYum:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"yum: Linux only, use 'brew' on macOS" code:1];
}

- (CPCommandResult *)cmdDnf:(NSArray *)args {
    return [self cmdYum:args];
}

- (CPCommandResult *)cmdRpm:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"rpm: Linux only" code:1];
}

#pragma mark - Arch Linux

- (CPCommandResult *)cmdPacman:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"pacman: Arch Linux only" code:1];
}

- (CPCommandResult *)cmdYay:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"yay: Arch Linux only" code:1];
}

#pragma mark - Other Linux

- (CPCommandResult *)cmdZypper:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"zypper: openSUSE only" code:1];
}

- (CPCommandResult *)cmdEmerge:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"emerge: Gentoo only" code:1];
}

- (CPCommandResult *)cmdPkg:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"pkg: FreeBSD only" code:1];
}

- (CPCommandResult *)cmdPkgng:(NSArray *)args {
    return [self cmdPkg:args];
}

- (CPCommandResult *)cmdApk:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"apk: Alpine Linux only" code:1];
}

- (CPCommandResult *)cmdSnap:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"snap: Linux only" code:1];
}

- (CPCommandResult *)cmdFlatpak:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"flatpak: Linux only" code:1];
}

- (CPCommandResult *)cmdAppimage:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"appimage: Linux only" code:1];
}

#pragma mark - Language Package Managers

- (CPCommandResult *)cmdPip:(NSArray *)args {
    return [self runPackageManager:@"/usr/bin/pip" fallback:@"/usr/local/bin/pip" args:args name:@"pip"];
}

- (CPCommandResult *)cmdPip3:(NSArray *)args {
    return [self runPackageManager:@"/usr/bin/pip3" fallback:@"/usr/local/bin/pip3" args:args name:@"pip3"];
}

- (CPCommandResult *)cmdNpm:(NSArray *)args {
    return [self runPackageManager:@"/usr/local/bin/npm" fallback:@"/opt/homebrew/bin/npm" args:args name:@"npm"];
}

- (CPCommandResult *)cmdYarn:(NSArray *)args {
    return [self runPackageManager:@"/usr/local/bin/yarn" fallback:@"/opt/homebrew/bin/yarn" args:args name:@"yarn"];
}

- (CPCommandResult *)cmdPnpm:(NSArray *)args {
    return [self runPackageManager:@"/usr/local/bin/pnpm" fallback:@"/opt/homebrew/bin/pnpm" args:args name:@"pnpm"];
}

- (CPCommandResult *)cmdGem:(NSArray *)args {
    return [self runPackageManager:@"/usr/bin/gem" fallback:@"/usr/local/bin/gem" args:args name:@"gem"];
}

- (CPCommandResult *)cmdCargo:(NSArray *)args {
    NSString *cargoPath = [NSHomeDirectory() stringByAppendingPathComponent:@".cargo/bin/cargo"];
    return [self runPackageManager:cargoPath fallback:@"/usr/local/bin/cargo" args:args name:@"cargo"];
}

- (CPCommandResult *)cmdGo:(NSArray *)args {
    return [self runPackageManager:@"/usr/local/go/bin/go" fallback:@"/opt/homebrew/bin/go" args:args name:@"go"];
}

- (CPCommandResult *)cmdComposer:(NSArray *)args {
    return [self runPackageManager:@"/usr/local/bin/composer" fallback:@"/opt/homebrew/bin/composer" args:args name:@"composer"];
}

- (CPCommandResult *)cmdMaven:(NSArray *)args {
    return [self runPackageManager:@"/usr/local/bin/mvn" fallback:@"/opt/homebrew/bin/mvn" args:args name:@"mvn"];
}

- (CPCommandResult *)cmdGradle:(NSArray *)args {
    return [self runPackageManager:@"/usr/local/bin/gradle" fallback:@"/opt/homebrew/bin/gradle" args:args name:@"gradle"];
}

- (CPCommandResult *)cmdNuget:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"nuget: not installed" code:1];
}

- (CPCommandResult *)cmdVcpkg:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"vcpkg: not installed" code:1];
}

- (CPCommandResult *)cmdConan:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"conan: not installed" code:1];
}

- (CPCommandResult *)cmdConda:(NSArray *)args {
    NSString *condaPath = [NSHomeDirectory() stringByAppendingPathComponent:@"miniconda3/bin/conda"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:condaPath]) {
        condaPath = [NSHomeDirectory() stringByAppendingPathComponent:@"anaconda3/bin/conda"];
    }
    return [self runPackageManager:condaPath fallback:@"/usr/local/bin/conda" args:args name:@"conda"];
}

#pragma mark - Windows Package Managers

- (CPCommandResult *)cmdChoco:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"choco: Windows only" code:1];
}

- (CPCommandResult *)cmdScoop:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"scoop: Windows only" code:1];
}

- (CPCommandResult *)cmdWinget:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"winget: Windows only" code:1];
}

#pragma mark - Helper

- (CPCommandResult *)runPackageManager:(NSString *)primaryPath fallback:(NSString *)fallbackPath args:(NSArray *)args name:(NSString *)name {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *path = primaryPath;
    
    if (![fm fileExistsAtPath:path]) {
        path = fallbackPath;
    }
    
    if (![fm fileExistsAtPath:path]) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"%@: not installed", name] code:1];
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = path;
    task.arguments = args;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    
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
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"%@: failed to execute", name] code:1];
    }
}

@end
