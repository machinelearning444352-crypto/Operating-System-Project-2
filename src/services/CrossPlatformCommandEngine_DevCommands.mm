#import "CrossPlatformCommandEngine.h"

@implementation CrossPlatformCommandEngine (DevCommands)

#pragma mark - Version Control

- (CPCommandResult *)cmdGit:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/git" args:args name:@"git"];
}

- (CPCommandResult *)cmdSvn:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/svn" args:args name:@"svn"];
}

- (CPCommandResult *)cmdHg:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/hg" args:args name:@"hg"];
}

#pragma mark - Build Systems

- (CPCommandResult *)cmdMake:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/make" args:args name:@"make"];
}

- (CPCommandResult *)cmdCmake:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/cmake" args:args name:@"cmake"];
}

- (CPCommandResult *)cmdNinja:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/ninja" args:args name:@"ninja"];
}

- (CPCommandResult *)cmdMeson:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/meson" args:args name:@"meson"];
}

- (CPCommandResult *)cmdAutoconf:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/autoconf" args:args name:@"autoconf"];
}

- (CPCommandResult *)cmdAutomake:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/automake" args:args name:@"automake"];
}

- (CPCommandResult *)cmdConfigure:(NSArray *)args {
    NSString *configPath = [self.currentSession.workingDirectory stringByAppendingPathComponent:@"configure"];
    if (![[NSFileManager defaultManager] fileExistsAtPath:configPath]) {
        return [CPCommandResult errorWithMessage:@"configure: no configure script found" code:1];
    }
    return [self runDevTool:configPath args:args name:@"configure"];
}

#pragma mark - Compilers

- (CPCommandResult *)cmdGcc:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/gcc" args:args name:@"gcc"];
}

- (CPCommandResult *)cmdGpp:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/g++" args:args name:@"g++"];
}

- (CPCommandResult *)cmdClang:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/clang" args:args name:@"clang"];
}

- (CPCommandResult *)cmdClangpp:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/clang++" args:args name:@"clang++"];
}

- (CPCommandResult *)cmdLd:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/ld" args:args name:@"ld"];
}

- (CPCommandResult *)cmdAs:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/as" args:args name:@"as"];
}

- (CPCommandResult *)cmdNasm:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/nasm" args:args name:@"nasm"];
}

#pragma mark - Binary Analysis

- (CPCommandResult *)cmdObjdump:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/objdump" args:args name:@"objdump"];
}

- (CPCommandResult *)cmdNm:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/nm" args:args name:@"nm"];
}

- (CPCommandResult *)cmdReadelf:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"readelf: Linux only, use otool on macOS" code:1];
}

- (CPCommandResult *)cmdOtool:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/otool" args:args name:@"otool"];
}

- (CPCommandResult *)cmdLdd:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"ldd: Linux only, use otool -L on macOS" code:1];
}

#pragma mark - Interpreters

- (CPCommandResult *)cmdPython:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/python" args:args name:@"python"];
}

- (CPCommandResult *)cmdPython3:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/python3" args:args name:@"python3"];
}

- (CPCommandResult *)cmdNode:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/node" args:args name:@"node"];
}

- (CPCommandResult *)cmdDeno:(NSArray *)args {
    NSString *denoPath = [NSHomeDirectory() stringByAppendingPathComponent:@".deno/bin/deno"];
    return [self runDevTool:denoPath args:args name:@"deno"];
}

- (CPCommandResult *)cmdBun:(NSArray *)args {
    NSString *bunPath = [NSHomeDirectory() stringByAppendingPathComponent:@".bun/bin/bun"];
    return [self runDevTool:bunPath args:args name:@"bun"];
}

- (CPCommandResult *)cmdRuby:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/ruby" args:args name:@"ruby"];
}

- (CPCommandResult *)cmdPerl:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/perl" args:args name:@"perl"];
}

- (CPCommandResult *)cmdPhp:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/php" args:args name:@"php"];
}

- (CPCommandResult *)cmdJava:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/java" args:args name:@"java"];
}

- (CPCommandResult *)cmdJavac:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/javac" args:args name:@"javac"];
}

- (CPCommandResult *)cmdSwift:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/swift" args:args name:@"swift"];
}

- (CPCommandResult *)cmdSwiftc:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/swiftc" args:args name:@"swiftc"];
}

- (CPCommandResult *)cmdRustc:(NSArray *)args {
    NSString *rustcPath = [NSHomeDirectory() stringByAppendingPathComponent:@".cargo/bin/rustc"];
    return [self runDevTool:rustcPath args:args name:@"rustc"];
}

- (CPCommandResult *)cmdGhc:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/ghc" args:args name:@"ghc"];
}

- (CPCommandResult *)cmdGhci:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"ghci: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdErlang:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/erl" args:args name:@"erl"];
}

- (CPCommandResult *)cmdElixir:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/elixir" args:args name:@"elixir"];
}

- (CPCommandResult *)cmdScala:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/scala" args:args name:@"scala"];
}

- (CPCommandResult *)cmdKotlin:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/kotlin" args:args name:@"kotlin"];
}

- (CPCommandResult *)cmdGroovy:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/groovy" args:args name:@"groovy"];
}

- (CPCommandResult *)cmdLua:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/lua" args:args name:@"lua"];
}

- (CPCommandResult *)cmdJulia:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/julia" args:args name:@"julia"];
}

- (CPCommandResult *)cmdR:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/R" args:args name:@"R"];
}

- (CPCommandResult *)cmdOctave:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/octave" args:args name:@"octave"];
}

#pragma mark - Debuggers

- (CPCommandResult *)cmdGdb:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"gdb: not available on modern macOS, use lldb" code:1];
}

- (CPCommandResult *)cmdLldb:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"lldb: interactive mode not supported" code:1];
}

- (CPCommandResult *)cmdValgrind:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"valgrind: not available on macOS" code:1];
}

- (CPCommandResult *)cmdProf:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"prof: use Instruments on macOS" code:1];
}

- (CPCommandResult *)cmdGprof:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"gprof: use Instruments on macOS" code:1];
}

- (CPCommandResult *)cmdPerfPerf:(NSArray *)args {
    return [CPCommandResult errorWithMessage:@"perf: Linux only, use Instruments on macOS" code:1];
}

- (CPCommandResult *)cmdInstruments:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/instruments" args:args name:@"instruments"];
}

#pragma mark - Xcode Tools

- (CPCommandResult *)cmdXcodebuild:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/xcodebuild" args:args name:@"xcodebuild"];
}

- (CPCommandResult *)cmdXcrun:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/xcrun" args:args name:@"xcrun"];
}

- (CPCommandResult *)cmdCodesign:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/codesign" args:args name:@"codesign"];
}

- (CPCommandResult *)cmdProductbuild:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/productbuild" args:args name:@"productbuild"];
}

- (CPCommandResult *)cmdPkgbuild:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/pkgbuild" args:args name:@"pkgbuild"];
}

- (CPCommandResult *)cmdInstallerTool:(NSArray *)args {
    return [self runDevTool:@"/usr/sbin/installer" args:args name:@"installer"];
}

- (CPCommandResult *)cmdLipo:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/lipo" args:args name:@"lipo"];
}

- (CPCommandResult *)cmdInstall_name_tool:(NSArray *)args {
    return [self runDevTool:@"/usr/bin/install_name_tool" args:args name:@"install_name_tool"];
}

#pragma mark - Containers/DevOps

- (CPCommandResult *)cmdDocker:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/docker" args:args name:@"docker"];
}

- (CPCommandResult *)cmdDockerCompose:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/docker-compose" args:args name:@"docker-compose"];
}

- (CPCommandResult *)cmdPodman:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/podman" args:args name:@"podman"];
}

- (CPCommandResult *)cmdKubectl:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/kubectl" args:args name:@"kubectl"];
}

- (CPCommandResult *)cmdHelm:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/helm" args:args name:@"helm"];
}

- (CPCommandResult *)cmdTerraform:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/terraform" args:args name:@"terraform"];
}

- (CPCommandResult *)cmdAnsible:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/ansible" args:args name:@"ansible"];
}

- (CPCommandResult *)cmdVagrant:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/vagrant" args:args name:@"vagrant"];
}

- (CPCommandResult *)cmdPacker:(NSArray *)args {
    return [self runDevTool:@"/usr/local/bin/packer" args:args name:@"packer"];
}

#pragma mark - Helper

- (CPCommandResult *)runDevTool:(NSString *)path args:(NSArray *)args name:(NSString *)name {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    if (![fm fileExistsAtPath:path]) {
        NSString *altPath = [@"/opt/homebrew/bin/" stringByAppendingString:name];
        if ([fm fileExistsAtPath:altPath]) {
            path = altPath;
        } else {
            altPath = [@"/usr/local/bin/" stringByAppendingString:name];
            if ([fm fileExistsAtPath:altPath]) {
                path = altPath;
            } else {
                return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"%@: not installed", name] code:127];
            }
        }
    }
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = path;
    task.arguments = args;
    task.currentDirectoryPath = self.currentSession.workingDirectory;
    task.environment = self.currentSession.environment;
    
    NSPipe *outPipe = [NSPipe pipe];
    NSPipe *errPipe = [NSPipe pipe];
    task.standardOutput = outPipe;
    task.standardError = errPipe;
    
    @try {
        [task launch];
        [task waitUntilExit];
        
        NSData *outData = [[outPipe fileHandleForReading] readDataToEndOfFile];
        NSData *errData = [[errPipe fileHandleForReading] readDataToEndOfFile];
        
        NSString *output = [[NSString alloc] initWithData:outData encoding:NSUTF8StringEncoding] ?: @"";
        NSString *error = [[NSString alloc] initWithData:errData encoding:NSUTF8StringEncoding] ?: @"";
        
        CPCommandResult *result = [[CPCommandResult alloc] init];
        result.output = output;
        result.errorOutput = error;
        result.exitCode = task.terminationStatus;
        result.success = (task.terminationStatus == 0);
        result.endTime = [NSDate date];
        result.duration = [result.endTime timeIntervalSinceDate:result.startTime];
        
        if (!result.success && output.length == 0) {
            result.output = error;
        }
        
        return result;
    } @catch (NSException *e) {
        return [CPCommandResult errorWithMessage:[NSString stringWithFormat:@"%@: failed to execute - %@", name, e.reason] code:1];
    }
}

@end
