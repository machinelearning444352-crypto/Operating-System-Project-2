#import "AdvancedKernel.h"
#include <mach/mach_time.h>

// ============================================================================
// VFS, Syscall, Security, Logging, and Core AdvancedKernel Implementation
// ============================================================================

@implementation KernInode
- (instancetype)init {
  self = [super init];
  if (self) {
    static uint64_t nextInode = 1;
    _inodeNumber = nextInode++;
    _type = KernInodeFile;
    _mode = 0644;
    _uid = 0;
    _gid = 0;
    _size = 0;
    _blocks = 0;
    _linkCount = 1;
    uint64_t now = mach_absolute_time();
    _accessTime = now;
    _modifyTime = now;
    _changeTime = now;
    _createTime = now;
    _deviceMajor = 0;
    _deviceMinor = 0;
    _dataBlocks = [NSMutableArray array];
    _extendedAttributes = [NSMutableDictionary dictionary];
    _fsType = KernFSTypeAPFS;
  }
  return self;
}
@end

@implementation KernDentry
- (instancetype)init {
  self = [super init];
  if (self) {
    _name = @"";
    _inode = nil;
    _parent = nil;
    _children = [NSMutableArray array];
    _isMountPoint = NO;
    _referenceCount = 1;
    _isNegative = NO;
  }
  return self;
}
@end

@implementation KernSuperblock
- (instancetype)init {
  self = [super init];
  if (self) {
    _fsType = KernFSTypeAPFS;
    _deviceName = @"";
    _mountPoint = @"/";
    _blockSize = 4096;
    _totalBlocks = 0;
    _freeBlocks = 0;
    _totalInodes = 0;
    _freeInodes = 0;
    _maxFilenameLength = 255;
    _maxFileSize = UINT64_MAX;
    _volumeLabel = @"";
    _uuid = [[NSUUID UUID] UUIDString];
    _mountFlags = 0;
    _readOnly = NO;
    _rootDentry = nil;
  }
  return self;
}
@end

@implementation KernMountPoint
- (instancetype)init {
  self = [super init];
  if (self) {
    _source = @"";
    _target = @"";
    _superblock = nil;
    _flags = 0;
    _options = @{};
    _mountID = 0;
    _parentMountID = 0;
  }
  return self;
}
@end

@implementation KernFileDescriptor
- (instancetype)init {
  self = [super init];
  if (self) {
    _fd = -1;
    _inode = nil;
    _offset = 0;
    _flags = 0;
    _mode = 0;
    _referenceCount = 1;
    _closeOnExec = NO;
    _nonBlocking = NO;
    _append = NO;
    _pipe = nil;
  }
  return self;
}
@end

@implementation KernSyscallResult
- (instancetype)init {
  self = [super init];
  if (self) {
    _returnValue = 0;
    _errorCode = 0;
    _errorMessage = @"";
    _success = YES;
  }
  return self;
}
@end

@implementation KernNamespace
- (instancetype)init {
  self = [super init];
  if (self) {
    _nsID = 0;
    _type = KernNSPID;
    _memberPIDs = [NSMutableArray array];
    _ownerUID = 0;
    _createTime = mach_absolute_time();
  }
  return self;
}
@end

@implementation KernSandboxProfile
- (instancetype)init {
  self = [super init];
  if (self) {
    _name = @"default";
    _allowedCapabilities = 0;
    _allowedPaths = @[];
    _deniedPaths = @[];
    _allowedSyscalls = @[];
    _deniedSyscalls = @[];
    _allowNetworking = NO;
    _allowFileCreation = NO;
    _allowProcessCreation = NO;
    _maxMemory = 256 * 1024 * 1024;
    _maxCPUTime = 60000;
    _maxFDs = 256;
    _maxProcesses = 10;
    _maxThreads = 50;
  }
  return self;
}
@end

@implementation KernCgroup
- (instancetype)init {
  self = [super init];
  if (self) {
    _cgroupID = 0;
    _name = @"";
    _path = @"/";
    _children = [NSMutableArray array];
    _memberPIDs = [NSMutableArray array];
    _cpuQuotaUs = UINT64_MAX;
    _cpuPeriodUs = 100000;
    _cpuShares = 1024;
    _memoryLimitBytes = UINT64_MAX;
    _memorySwapLimit = UINT64_MAX;
    _memoryUsage = 0;
    _ioReadBps = UINT64_MAX;
    _ioWriteBps = UINT64_MAX;
    _ioReadIOps = UINT64_MAX;
    _ioWriteIOps = UINT64_MAX;
    _pidsMax = UINT32_MAX;
    _pidsCurrent = 0;
  }
  return self;
}
@end

@implementation KernLogEntry
- (instancetype)init {
  self = [super init];
  if (self) {
    _sequenceNumber = 0;
    _level = KernLogInfo;
    _facility = KernLogKernel;
    _subsystem = @"";
    _message = @"";
    _timestampNs = 0;
    _processID = 0;
    _threadID = 0;
    _cpuID = 0;
    _functionName = @"";
    _fileName = @"";
    _lineNumber = 0;
  }
  return self;
}
@end

// ============================================================================
// Core AdvancedKernel singleton + VFS + Syscalls + Security + Logging
// ============================================================================

@interface AdvancedKernel ()
@property(nonatomic, strong) NSMutableDictionary *internalState;
@property(nonatomic, strong) NSMutableArray<KernLogEntry *> *logBuffer;
@property(nonatomic, assign) uint64_t logSequence;
@property(nonatomic, assign) uint64_t bootTime;
@property(nonatomic, assign) uint64_t syscallCount;
@end

@implementation AdvancedKernel

+ (instancetype)sharedInstance {
  static AdvancedKernel *instance = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    instance = [[AdvancedKernel alloc] init];
  });
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _internalState = [NSMutableDictionary dictionary];
    _logBuffer = [NSMutableArray array];
    _logSequence = 0;
    _bootTime = mach_absolute_time();
    _syscallCount = 0;

    _internalState[@"processes"] = [NSMutableArray array];
    _internalState[@"pipes"] = [NSMutableArray array];
    _internalState[@"messageQueues"] = [NSMutableArray array];
    _internalState[@"sharedMemory"] = [NSMutableArray array];
    _internalState[@"semaphores"] = [NSMutableArray array];
    _internalState[@"threads"] = [NSMutableArray array];
    _internalState[@"mountPoints"] = [NSMutableArray array];
    _internalState[@"namespaces"] = [NSMutableArray array];
    _internalState[@"cgroups"] = [NSMutableArray array];
    _internalState[@"sandboxProfiles"] = [NSMutableDictionary dictionary];
    _internalState[@"capabilities"] = [NSMutableDictionary dictionary];

    [self kernelLog:KernLogInfo
           facility:KernLogKernel
            message:@"Advanced Kernel initializing"];
    [self initializeVirtualMemory];
    [self initializeVFS];

    // Create init process (PID 1)
    [self createProcess:@"init"
         executablePath:@"/sbin/init"
              arguments:@[]
              parentPID:0];
    // Create kernel threads (PID 2+)
    [self createProcess:@"kthreadd"
         executablePath:@""
              arguments:@[]
              parentPID:0];
    [self createProcess:@"ksoftirqd/0"
         executablePath:@""
              arguments:@[]
              parentPID:2];
    [self createProcess:@"kworker/0:0"
         executablePath:@""
              arguments:@[]
              parentPID:2];
    [self createProcess:@"migration/0"
         executablePath:@""
              arguments:@[]
              parentPID:2];
    [self createProcess:@"rcu_sched"
         executablePath:@""
              arguments:@[]
              parentPID:2];

    [self kernelLog:KernLogInfo
           facility:KernLogKernel
            message:@"Advanced Kernel initialized successfully"];
  }
  return self;
}

// --- VFS ---

- (void)initializeVFS {
  [self kernelLog:KernLogInfo
         facility:KernLogVFS
          message:@"Initializing Virtual File System"];

  // Create root dentry
  KernDentry *rootDentry = [[KernDentry alloc] init];
  rootDentry.name = @"/";
  KernInode *rootInode = [[KernInode alloc] init];
  rootInode.type = KernInodeDirectory;
  rootInode.mode = 0755;
  rootDentry.inode = rootInode;
  self.internalState[@"rootDentry"] = rootDentry;

  // Create root file system superblock
  KernSuperblock *rootSB = [[KernSuperblock alloc] init];
  rootSB.fsType = KernFSTypeAPFS;
  rootSB.deviceName = @"/dev/disk0s1";
  rootSB.mountPoint = @"/";
  rootSB.blockSize = 4096;
  rootSB.totalBlocks = 250000000;
  rootSB.freeBlocks = 100000000;
  rootSB.totalInodes = 62500000;
  rootSB.freeInodes = 50000000;
  rootSB.volumeLabel = @"Macintosh HD";
  rootSB.rootDentry = rootDentry;

  // Create standard directories
  NSArray *dirs = @[
    @"bin", @"sbin", @"etc", @"usr", @"var", @"tmp", @"home", @"dev", @"proc",
    @"sys", @"lib", @"opt", @"mnt", @"run", @"boot", @"srv"
  ];
  for (NSString *dir in dirs) {
    KernDentry *dentry = [[KernDentry alloc] init];
    dentry.name = dir;
    dentry.parent = rootDentry;
    KernInode *inode = [[KernInode alloc] init];
    inode.type = KernInodeDirectory;
    inode.mode = 0755;
    dentry.inode = inode;
    [rootDentry.children addObject:dentry];
  }

  // Mount root
  KernMountPoint *rootMount = [[KernMountPoint alloc] init];
  rootMount.source = @"/dev/disk0s1";
  rootMount.target = @"/";
  rootMount.superblock = rootSB;
  rootMount.mountID = 1;

  NSMutableArray *mounts = self.internalState[@"mountPoints"];
  [mounts addObject:rootMount];

  // Mount virtual file systems
  NSArray *vfsMounts = @[
    @[ @"proc", @"/proc", @(KernFSTypeProcFS) ],
    @[ @"sysfs", @"/sys", @(KernFSTypeSysFS) ],
    @[ @"devfs", @"/dev", @(KernFSTypeDevFS) ],
    @[ @"tmpfs", @"/tmp", @(KernFSTypeTmpFS) ],
    @[ @"tmpfs", @"/run", @(KernFSTypeTmpFS) ]
  ];

  uint32_t nextMountID = 2;
  for (NSArray *vfs in vfsMounts) {
    KernSuperblock *sb = [[KernSuperblock alloc] init];
    sb.fsType = (KernFileSystemType)[vfs[2] integerValue];
    sb.deviceName = vfs[0];
    sb.mountPoint = vfs[1];
    sb.blockSize = 4096;
    sb.volumeLabel = vfs[0];

    KernMountPoint *mp = [[KernMountPoint alloc] init];
    mp.source = vfs[0];
    mp.target = vfs[1];
    mp.superblock = sb;
    mp.mountID = nextMountID++;
    mp.parentMountID = 1;
    [mounts addObject:mp];
  }

  [self kernelLog:KernLogInfo
         facility:KernLogVFS
          message:[NSString
                      stringWithFormat:@"VFS initialized with %lu mount points",
                                       (unsigned long)mounts.count]];
}

- (KernSuperblock *)mountFileSystem:(KernFileSystemType)type
                             device:(NSString *)device
                         mountPoint:(NSString *)mountPoint
                            options:(NSDictionary *)options {
  KernSuperblock *sb = [[KernSuperblock alloc] init];
  sb.fsType = type;
  sb.deviceName = device;
  sb.mountPoint = mountPoint;
  sb.blockSize = 4096;

  KernDentry *mpDentry = [[KernDentry alloc] init];
  mpDentry.name = [mountPoint lastPathComponent];
  mpDentry.isMountPoint = YES;
  KernInode *mpInode = [[KernInode alloc] init];
  mpInode.type = KernInodeDirectory;
  mpDentry.inode = mpInode;
  sb.rootDentry = mpDentry;

  static uint32_t nextMountID = 100;
  KernMountPoint *mp = [[KernMountPoint alloc] init];
  mp.source = device;
  mp.target = mountPoint;
  mp.superblock = sb;
  mp.mountID = nextMountID++;
  mp.options = options;

  NSMutableArray *mounts = self.internalState[@"mountPoints"];
  [mounts addObject:mp];

  [self kernelLog:KernLogInfo
         facility:KernLogVFS
          message:[NSString stringWithFormat:@"Mounted %@ on %@", device,
                                             mountPoint]];
  return sb;
}

- (BOOL)unmountFileSystem:(NSString *)mountPoint {
  NSMutableArray *mounts = self.internalState[@"mountPoints"];
  KernMountPoint *toRemove = nil;
  for (KernMountPoint *mp in mounts) {
    if ([mp.target isEqualToString:mountPoint]) {
      toRemove = mp;
      break;
    }
  }
  if (toRemove) {
    [mounts removeObject:toRemove];
    [self kernelLog:KernLogInfo
           facility:KernLogVFS
            message:[NSString stringWithFormat:@"Unmounted %@", mountPoint]];
    return YES;
  }
  return NO;
}

- (KernInode *)lookupPath:(NSString *)path {
  KernDentry *root = self.internalState[@"rootDentry"];
  if ([path isEqualToString:@"/"])
    return root.inode;

  NSArray *components = [path pathComponents];
  KernDentry *current = root;
  for (NSString *comp in components) {
    if ([comp isEqualToString:@"/"])
      continue;
    BOOL found = NO;
    for (KernDentry *child in current.children) {
      if ([child.name isEqualToString:comp]) {
        current = child;
        found = YES;
        break;
      }
    }
    if (!found)
      return nil;
  }
  return current.inode;
}

- (KernInode *)createFile:(NSString *)path mode:(uint32_t)mode {
  NSString *dirPath = [path stringByDeletingLastPathComponent];
  NSString *fileName = [path lastPathComponent];

  KernDentry *parent = [self dentryForPath:dirPath];
  if (!parent)
    return nil;

  KernDentry *newDentry = [[KernDentry alloc] init];
  newDentry.name = fileName;
  newDentry.parent = parent;
  KernInode *inode = [[KernInode alloc] init];
  inode.type = KernInodeFile;
  inode.mode = mode;
  newDentry.inode = inode;
  [parent.children addObject:newDentry];
  return inode;
}

- (KernInode *)createDirectory:(NSString *)path mode:(uint32_t)mode {
  KernInode *inode = [self createFile:path mode:mode];
  if (inode)
    inode.type = KernInodeDirectory;
  return inode;
}

- (BOOL)deleteInode:(NSString *)path {
  NSString *dirPath = [path stringByDeletingLastPathComponent];
  NSString *name = [path lastPathComponent];
  KernDentry *parent = [self dentryForPath:dirPath];
  if (!parent)
    return NO;
  KernDentry *toRemove = nil;
  for (KernDentry *child in parent.children) {
    if ([child.name isEqualToString:name]) {
      toRemove = child;
      break;
    }
  }
  if (toRemove) {
    [parent.children removeObject:toRemove];
    return YES;
  }
  return NO;
}

- (BOOL)linkPath:(NSString *)target to:(NSString *)linkPath {
  KernInode *inode = [self lookupPath:target];
  if (!inode)
    return NO;
  NSString *dirPath = [linkPath stringByDeletingLastPathComponent];
  KernDentry *parent = [self dentryForPath:dirPath];
  if (!parent)
    return NO;
  KernDentry *link = [[KernDentry alloc] init];
  link.name = [linkPath lastPathComponent];
  link.parent = parent;
  link.inode = inode;
  inode.linkCount++;
  [parent.children addObject:link];
  return YES;
}

- (BOOL)symlinkPath:(NSString *)target to:(NSString *)linkPath {
  KernInode *inode = [[KernInode alloc] init];
  inode.type = KernInodeSymlink;
  NSString *dirPath = [linkPath stringByDeletingLastPathComponent];
  KernDentry *parent = [self dentryForPath:dirPath];
  if (!parent)
    return NO;
  KernDentry *link = [[KernDentry alloc] init];
  link.name = [linkPath lastPathComponent];
  link.parent = parent;
  link.inode = inode;
  [parent.children addObject:link];
  return YES;
}

- (NSArray<KernDentry *> *)readDirectory:(NSString *)path {
  KernDentry *dir = [self dentryForPath:path];
  return dir ? [dir.children copy] : @[];
}

- (KernFileDescriptor *)openFile:(NSString *)path
                           flags:(uint32_t)flags
                            mode:(uint32_t)mode {
  KernInode *inode = [self lookupPath:path];
  if (!inode && (flags & 0x0200)) { // O_CREAT
    inode = [self createFile:path mode:mode];
  }
  if (!inode)
    return nil;

  static int32_t nextFD = 3; // 0,1,2 reserved for stdin/stdout/stderr
  KernFileDescriptor *fd = [[KernFileDescriptor alloc] init];
  fd.fd = nextFD++;
  fd.inode = inode;
  fd.offset = 0;
  fd.flags = flags;
  fd.mode = mode;
  inode.accessTime = mach_absolute_time();
  return fd;
}

- (void)closeFile:(KernFileDescriptor *)fd {
  if (fd) {
    fd.referenceCount--;
    fd.inode = nil;
  }
}

- (NSData *)readFile:(KernFileDescriptor *)fd length:(NSUInteger)length {
  if (!fd || !fd.inode)
    return nil;
  fd.inode.accessTime = mach_absolute_time();
  // Return empty data for simulated read
  NSUInteger readLen = MIN(length, (NSUInteger)(fd.inode.size - fd.offset));
  fd.offset += readLen;
  return [NSMutableData dataWithLength:readLen];
}

- (NSInteger)writeFile:(KernFileDescriptor *)fd data:(NSData *)data {
  if (!fd || !fd.inode || !data)
    return -1;
  if (fd.append)
    fd.offset = fd.inode.size;
  fd.inode.size = MAX(fd.inode.size, fd.offset + data.length);
  fd.inode.modifyTime = mach_absolute_time();
  fd.offset += data.length;
  return data.length;
}

- (BOOL)seekFile:(KernFileDescriptor *)fd
          offset:(int64_t)offset
          whence:(int32_t)whence {
  if (!fd)
    return NO;
  switch (whence) {
  case 0:
    fd.offset = offset;
    break; // SEEK_SET
  case 1:
    fd.offset += offset;
    break; // SEEK_CUR
  case 2:
    fd.offset = fd.inode.size + offset;
    break; // SEEK_END
  default:
    return NO;
  }
  return YES;
}

- (NSArray<KernMountPoint *> *)mountedFileSystems {
  return [self.internalState[@"mountPoints"] copy];
}

- (NSDictionary *)fileSystemStatistics:(NSString *)mountPoint {
  for (KernMountPoint *mp in self.internalState[@"mountPoints"]) {
    if ([mp.target isEqualToString:mountPoint]) {
      KernSuperblock *sb = mp.superblock;
      return @{
        @"fs_type" : @(sb.fsType),
        @"device" : sb.deviceName ?: @"",
        @"mount_point" : sb.mountPoint ?: @"",
        @"block_size" : @(sb.blockSize),
        @"total_blocks" : @(sb.totalBlocks),
        @"free_blocks" : @(sb.freeBlocks),
        @"total_inodes" : @(sb.totalInodes),
        @"free_inodes" : @(sb.freeInodes),
        @"total_space" : @(sb.totalBlocks * sb.blockSize),
        @"free_space" : @(sb.freeBlocks * sb.blockSize),
        @"volume_label" : sb.volumeLabel ?: @"",
        @"uuid" : sb.uuid ?: @""
      };
    }
  }
  return @{};
}

// Helper
- (KernDentry *)dentryForPath:(NSString *)path {
  KernDentry *root = self.internalState[@"rootDentry"];
  if ([path isEqualToString:@"/"] || path.length == 0)
    return root;
  NSArray *components = [path pathComponents];
  KernDentry *current = root;
  for (NSString *comp in components) {
    if ([comp isEqualToString:@"/"])
      continue;
    BOOL found = NO;
    for (KernDentry *child in current.children) {
      if ([child.name isEqualToString:comp]) {
        current = child;
        found = YES;
        break;
      }
    }
    if (!found)
      return nil;
  }
  return current;
}

// --- Syscall Interface ---

- (KernSyscallResult *)executeSyscall:(KernSyscallNumber)number
                                 args:(NSArray *)args {
  self.syscallCount++;
  KernSyscallResult *result = [[KernSyscallResult alloc] init];
  result.success = YES;

  switch (number) {
  case KSYS_GETPID:
    result.returnValue = 1;
    break;
  case KSYS_GETPPID:
    result.returnValue = 0;
    break;
  case KSYS_GETUID:
  case KSYS_GETGID:
    result.returnValue = 0;
    break;
  case KSYS_UNAME:
    result.returnValue = 0;
    break;
  case KSYS_SYSINFO:
    result.returnValue = 0;
    break;
  case KSYS_BRK:
    result.returnValue = 0;
    break;
  case KSYS_MMAP:
    result.returnValue = 0;
    break;
  case KSYS_FORK: {
    KernProcess *parent =
        args.count > 0 ? [self processForPID:[args[0] unsignedIntValue]] : nil;
    if (parent) {
      KernProcess *child = [self createProcess:parent.name
                                executablePath:parent.executablePath
                                     arguments:parent.arguments
                                     parentPID:parent.pid];
      result.returnValue = child.pid;
    } else {
      result.success = NO;
      result.errorCode = 3;
      result.errorMessage = @"ESRCH";
    }
    break;
  }
  case KSYS_EXIT:
    if (args.count > 0) {
      [self terminateProcess:[args[0] unsignedIntValue]
                    exitCode:[args[1] intValue]];
    }
    break;
  case KSYS_KILL:
    if (args.count >= 2) {
      [self sendSignal:(KernSignal)[args[1] integerValue]
             toProcess:[args[0] unsignedIntValue]];
    }
    break;
  case KSYS_CLOCK_GETTIME:
    result.returnValue = mach_absolute_time();
    break;
  case KSYS_GETRANDOM:
    result.returnValue = arc4random();
    break;
  default:
    result.returnValue = 0;
    break;
  }

  [self kernelLog:KernLogTrace
         facility:KernLogSyscall
          message:[NSString stringWithFormat:@"syscall %@ (#%ld) -> %lld",
                                             [self syscallName:number],
                                             (long)number, result.returnValue]];
  return result;
}

- (NSString *)syscallName:(KernSyscallNumber)number {
  static NSDictionary *names = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    names = @{
      @(KSYS_EXIT) : @"exit",
      @(KSYS_FORK) : @"fork",
      @(KSYS_READ) : @"read",
      @(KSYS_WRITE) : @"write",
      @(KSYS_OPEN) : @"open",
      @(KSYS_CLOSE) : @"close",
      @(KSYS_GETPID) : @"getpid",
      @(KSYS_KILL) : @"kill",
      @(KSYS_MMAP) : @"mmap",
      @(KSYS_MUNMAP) : @"munmap",
      @(KSYS_BRK) : @"brk",
      @(KSYS_PIPE) : @"pipe",
      @(KSYS_CLONE) : @"clone",
      @(KSYS_EXEC) : @"execve",
      @(KSYS_WAIT) : @"wait",
      @(KSYS_SOCKET) : @"socket",
      @(KSYS_BIND) : @"bind",
      @(KSYS_LISTEN) : @"listen",
      @(KSYS_ACCEPT) : @"accept",
      @(KSYS_CONNECT) : @"connect",
      @(KSYS_SEND) : @"send",
      @(KSYS_RECV) : @"recv",
      @(KSYS_STAT) : @"stat",
      @(KSYS_FSTAT) : @"fstat",
      @(KSYS_MKDIR) : @"mkdir",
      @(KSYS_RMDIR) : @"rmdir",
      @(KSYS_MOUNT) : @"mount",
      @(KSYS_UMOUNT) : @"umount",
      @(KSYS_UNAME) : @"uname",
      @(KSYS_SYSINFO) : @"sysinfo",
      @(KSYS_CLOCK_GETTIME) : @"clock_gettime",
      @(KSYS_FUTEX) : @"futex",
      @(KSYS_REBOOT) : @"reboot",
      @(KSYS_GETRANDOM) : @"getrandom",
      @(KSYS_IO_URING_SETUP) : @"io_uring_setup"
    };
  });
  return names[@(number)]
             ?: [NSString stringWithFormat:@"syscall_%ld", (long)number];
}

- (NSUInteger)totalSyscallCount {
  return (NSUInteger)self.syscallCount;
}

// --- Security ---

- (BOOL)checkCapability:(KernCapability)cap forProcess:(uint32_t)pid {
  NSDictionary *caps = self.internalState[@"capabilities"];
  NSNumber *procCaps = caps[@(pid)];
  if (!procCaps)
    return (pid == 0 || pid == 1); // root has all caps
  return (procCaps.unsignedLongLongValue & cap) == cap;
}

- (void)grantCapability:(KernCapability)cap toProcess:(uint32_t)pid {
  NSMutableDictionary *caps = self.internalState[@"capabilities"];
  uint64_t current = [caps[@(pid)] unsignedLongLongValue];
  caps[@(pid)] = @(current | cap);
}

- (void)revokeCapability:(KernCapability)cap fromProcess:(uint32_t)pid {
  NSMutableDictionary *caps = self.internalState[@"capabilities"];
  uint64_t current = [caps[@(pid)] unsignedLongLongValue];
  caps[@(pid)] = @(current & ~cap);
}

- (KernNamespace *)createNamespace:(KernNamespaceType)type
                        forProcess:(uint32_t)pid {
  static uint32_t nextNSID = 1;
  KernNamespace *ns = [[KernNamespace alloc] init];
  ns.nsID = nextNSID++;
  ns.type = type;
  [ns.memberPIDs addObject:@(pid)];

  KernProcess *proc = [self processForPID:pid];
  if (proc)
    proc.namespaceID = ns.nsID;

  [self.internalState[@"namespaces"] addObject:ns];
  return ns;
}

- (void)joinNamespace:(KernNamespace *)ns process:(uint32_t)pid {
  if (!ns)
    return;
  [ns.memberPIDs addObject:@(pid)];
  KernProcess *proc = [self processForPID:pid];
  if (proc)
    proc.namespaceID = ns.nsID;
}

- (KernSandboxProfile *)createSandboxProfile:(NSString *)name {
  KernSandboxProfile *profile = [[KernSandboxProfile alloc] init];
  profile.name = name;
  self.internalState[@"sandboxProfiles"][name] = profile;
  return profile;
}

- (void)applySandbox:(KernSandboxProfile *)profile toProcess:(uint32_t)pid {
  [self kernelLog:KernLogInfo
         facility:KernLogSecurity
          message:[NSString stringWithFormat:@"Sandbox '%@' applied to PID %u",
                                             profile.name, pid]];
}

- (KernCgroup *)createCgroup:(NSString *)name parent:(KernCgroup *)parent {
  static uint32_t nextCgID = 1;
  KernCgroup *cg = [[KernCgroup alloc] init];
  cg.cgroupID = nextCgID++;
  cg.name = name;
  cg.parent = parent;
  cg.path = parent ? [NSString stringWithFormat:@"%@/%@", parent.path, name]
                   : [NSString stringWithFormat:@"/%@", name];
  if (parent)
    [parent.children addObject:cg];
  [self.internalState[@"cgroups"] addObject:cg];
  return cg;
}

- (void)addProcess:(uint32_t)pid toCgroup:(KernCgroup *)cgroup {
  if (!cgroup)
    return;
  [cgroup.memberPIDs addObject:@(pid)];
  cgroup.pidsCurrent++;
  KernProcess *proc = [self processForPID:pid];
  if (proc)
    proc.cgroupID = cgroup.cgroupID;
}

- (void)setCgroupCPULimit:(KernCgroup *)cgroup
                  quotaUs:(uint64_t)quota
                 periodUs:(uint64_t)period {
  if (!cgroup)
    return;
  cgroup.cpuQuotaUs = quota;
  cgroup.cpuPeriodUs = period;
}

- (void)setCgroupMemoryLimit:(KernCgroup *)cgroup bytes:(uint64_t)limit {
  if (cgroup)
    cgroup.memoryLimitBytes = limit;
}

- (NSDictionary *)cgroupStatistics:(KernCgroup *)cgroup {
  if (!cgroup)
    return @{};
  return @{
    @"name" : cgroup.name,
    @"path" : cgroup.path,
    @"pids_current" : @(cgroup.pidsCurrent),
    @"pids_max" : @(cgroup.pidsMax),
    @"cpu_quota_us" : @(cgroup.cpuQuotaUs),
    @"cpu_period_us" : @(cgroup.cpuPeriodUs),
    @"cpu_shares" : @(cgroup.cpuShares),
    @"memory_limit" : @(cgroup.memoryLimitBytes),
    @"memory_usage" : @(cgroup.memoryUsage)
  };
}

// --- Logging ---

- (void)kernelLog:(KernLogLevel)level
         facility:(KernLogFacility)facility
          message:(NSString *)message {
  KernLogEntry *entry = [[KernLogEntry alloc] init];
  entry.sequenceNumber = self.logSequence++;
  entry.level = level;
  entry.facility = facility;
  entry.message = message;
  entry.timestampNs = mach_absolute_time();

  [self.logBuffer addObject:entry];
  if (self.logBuffer.count > 100000) {
    [self.logBuffer removeObjectsInRange:NSMakeRange(0, 10000)];
  }

  if (level <= KernLogWarning) {
    NSLog(@"[KERN %@] %@", [self logLevelString:level], message);
  }
}

- (NSString *)logLevelString:(KernLogLevel)level {
  switch (level) {
  case KernLogEmergency:
    return @"EMERG";
  case KernLogAlert:
    return @"ALERT";
  case KernLogCritical:
    return @"CRIT";
  case KernLogError:
    return @"ERR";
  case KernLogWarning:
    return @"WARN";
  case KernLogNotice:
    return @"NOTICE";
  case KernLogInfo:
    return @"INFO";
  case KernLogDebug:
    return @"DEBUG";
  case KernLogTrace:
    return @"TRACE";
  }
  return @"UNKNOWN";
}

- (NSArray<KernLogEntry *> *)logEntriesWithLevel:(KernLogLevel)minLevel
                                        facility:(KernLogFacility)facility
                                           count:(NSUInteger)count {
  NSMutableArray *results = [NSMutableArray array];
  for (KernLogEntry *entry in [self.logBuffer reverseObjectEnumerator]) {
    if (entry.level <= minLevel &&
        (facility == KernLogKernel || entry.facility == facility)) {
      [results addObject:entry];
      if (results.count >= count)
        break;
    }
  }
  return [[results reverseObjectEnumerator] allObjects];
}

- (void)clearLogs {
  [self.logBuffer removeAllObjects];
}
- (NSUInteger)logCount {
  return self.logBuffer.count;
}

// --- System Info ---

- (NSDictionary *)kernelInfo {
  return @{
    @"version" : [self kernelVersion],
    @"uptime_ns" : @([self uptimeNanoseconds]),
    @"uptime_seconds" : @([self uptimeNanoseconds] / 1000000000.0),
    @"process_count" : @([self allProcesses].count),
    @"syscall_count" : @(self.syscallCount),
    @"log_entries" : @(self.logBuffer.count),
    @"total_memory" : @([self totalPhysicalMemory]),
    @"boot_time" : @(self.bootTime),
    @"hostname" : [[NSProcessInfo processInfo] hostName],
    @"os_version" : [[NSProcessInfo processInfo] operatingSystemVersionString],
    @"cpu_count" : @([[NSProcessInfo processInfo] processorCount]),
    @"active_cpu_count" : @([[NSProcessInfo processInfo] activeProcessorCount])
  };
}

- (uint64_t)uptimeNanoseconds {
  return mach_absolute_time() - self.bootTime;
}

- (NSString *)kernelVersion {
  return @"AdvancedKernel 2.0.0-release (VirtualOS) #1 SMP PREEMPT";
}

@end
