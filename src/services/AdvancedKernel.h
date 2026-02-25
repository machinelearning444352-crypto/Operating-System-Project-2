#pragma once
#import <Cocoa/Cocoa.h>
#include <stdbool.h>
#include <stdint.h>

// ============================================================================
// ADVANCED KERNEL — Virtual Memory, IPC, Threading, Syscalls, VFS, Security
// ============================================================================

// ==========================================================================
// SECTION 1: VIRTUAL MEMORY SUBSYSTEM
// ==========================================================================

// Page size definitions
#define KERN_PAGE_SIZE_4K 4096
#define KERN_PAGE_SIZE_2M (2 * 1024 * 1024)
#define KERN_PAGE_SIZE_1G (1024 * 1024 * 1024ULL)
#define KERN_PAGE_SIZE KERN_PAGE_SIZE_4K

// Page table entry flags
#define PTE_PRESENT (1ULL << 0)
#define PTE_WRITABLE (1ULL << 1)
#define PTE_USER (1ULL << 2)
#define PTE_WRITE_THROUGH (1ULL << 3)
#define PTE_CACHE_DISABLE (1ULL << 4)
#define PTE_ACCESSED (1ULL << 5)
#define PTE_DIRTY (1ULL << 6)
#define PTE_HUGE_PAGE (1ULL << 7)
#define PTE_GLOBAL (1ULL << 8)
#define PTE_NO_EXECUTE (1ULL << 63)

// Memory protection flags
typedef NS_OPTIONS(NSUInteger, KernMemoryProtection) {
  KernMemProtNone = 0,
  KernMemProtRead = 1 << 0,
  KernMemProtWrite = 1 << 1,
  KernMemProtExec = 1 << 2,
  KernMemProtCopyOnWrite = 1 << 3,
  KernMemProtShared = 1 << 4,
  KernMemProtPrivate = 1 << 5,
  KernMemProtNoCache = 1 << 6,
  KernMemProtWriteCombine = 1 << 7,
  KernMemProtGuardPage = 1 << 8,
  KernMemProtUser = 1 << 9
};

// Memory mapping flags
typedef NS_OPTIONS(NSUInteger, KernMmapFlags) {
  KernMmapShared = 1 << 0,
  KernMmapPrivate = 1 << 1,
  KernMmapFixed = 1 << 2,
  KernMmapAnonymous = 1 << 3,
  KernMmapGrowsDown = 1 << 4,
  KernMmapHugePages = 1 << 5,
  KernMmapLocked = 1 << 6,
  KernMmapPopulate = 1 << 7,
  KernMmapNonBlock = 1 << 8,
  KernMmapStack = 1 << 9,
  KernMmapFile = 1 << 10
};

// Page fault reason
typedef NS_ENUM(NSInteger, KernPageFaultReason) {
  KernPageFaultNotPresent = 0,
  KernPageFaultProtection,
  KernPageFaultWriteAccess,
  KernPageFaultInstructionFetch,
  KernPageFaultReserved,
  KernPageFaultCopyOnWrite,
  KernPageFaultSwapIn,
  KernPageFaultDemandZero,
  KernPageFaultMemoryMapped,
  KernPageFaultStackGrowth
};

// Memory zone types
typedef NS_ENUM(NSInteger, KernMemoryZone) {
  KernMemZoneDMA = 0,
  KernMemZoneDMA32,
  KernMemZoneNormal,
  KernMemZoneHighMem,
  KernMemZoneMovable,
  KernMemZoneDevice
};

// Page state
typedef NS_ENUM(NSInteger, KernPageState) {
  KernPageFree = 0,
  KernPageAllocated,
  KernPageMapped,
  KernPageSwapped,
  KernPageLocked,
  KernPageDirty,
  KernPageWriteback,
  KernPageReserved,
  KernPageSlab,
  KernPageCompound,
  KernPageBuddy
};

// Page Table Entry
@interface KernPageTableEntry : NSObject
@property(nonatomic, assign) uint64_t physicalAddress;
@property(nonatomic, assign) uint64_t virtualAddress;
@property(nonatomic, assign) uint64_t flags;
@property(nonatomic, assign) KernPageState state;
@property(nonatomic, assign) KernMemoryProtection protection;
@property(nonatomic, assign) uint32_t referenceCount;
@property(nonatomic, assign) uint64_t lastAccessTime;
@property(nonatomic, assign) BOOL present;
@property(nonatomic, assign) BOOL dirty;
@property(nonatomic, assign) BOOL accessed;
@property(nonatomic, assign) BOOL swapped;
@property(nonatomic, assign) uint64_t swapOffset;
@end

// TLB Entry
@interface KernTLBEntry : NSObject
@property(nonatomic, assign) uint64_t virtualPage;
@property(nonatomic, assign) uint64_t physicalFrame;
@property(nonatomic, assign) KernMemoryProtection protection;
@property(nonatomic, assign) uint64_t lastUsed;
@property(nonatomic, assign) BOOL valid;
@property(nonatomic, assign) BOOL global;
@property(nonatomic, assign) uint32_t asid; // Address Space ID
@end

// Virtual Memory Area (VMA)
@interface KernVMA : NSObject
@property(nonatomic, assign) uint64_t startAddress;
@property(nonatomic, assign) uint64_t endAddress;
@property(nonatomic, assign) uint64_t size;
@property(nonatomic, assign) KernMemoryProtection protection;
@property(nonatomic, assign) KernMmapFlags flags;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, assign) uint64_t fileOffset;
@property(nonatomic, strong) NSString *mappedFile;
@property(nonatomic, assign) BOOL isAnonymous;
@property(nonatomic, assign) BOOL isStack;
@property(nonatomic, assign) BOOL isHeap;
@property(nonatomic, assign) uint32_t processID;
@end

// Slab Allocator Cache
@interface KernSlabCache : NSObject
@property(nonatomic, strong) NSString *name;
@property(nonatomic, assign) NSUInteger objectSize;
@property(nonatomic, assign) NSUInteger alignment;
@property(nonatomic, assign) NSUInteger objectsPerSlab;
@property(nonatomic, assign) NSUInteger totalSlabs;
@property(nonatomic, assign) NSUInteger activeObjects;
@property(nonatomic, assign) NSUInteger freeObjects;
@property(nonatomic, strong) NSMutableArray *slabs;
@property(nonatomic, strong) NSMutableArray *freeList;
@property(nonatomic, assign) uint64_t totalAllocations;
@property(nonatomic, assign) uint64_t totalFrees;
@property(nonatomic, assign) uint64_t cacheHits;
@property(nonatomic, assign) uint64_t cacheMisses;
@end

// Buddy Allocator Block
@interface KernBuddyBlock : NSObject
@property(nonatomic, assign) uint64_t baseAddress;
@property(nonatomic, assign) NSUInteger order; // 2^order pages
@property(nonatomic, assign) BOOL isFree;
@property(nonatomic, assign) KernMemoryZone zone;
@end

// ==========================================================================
// SECTION 2: ADVANCED PROCESS SCHEDULER
// ==========================================================================

// Scheduling policies
typedef NS_ENUM(NSInteger, KernSchedulingPolicy) {
  KernSchedNormal = 0, // CFS - Completely Fair Scheduler
  KernSchedFIFO,       // Real-time FIFO
  KernSchedRoundRobin, // Real-time Round Robin
  KernSchedBatch,      // Batch processing
  KernSchedIdle,       // Idle priority
  KernSchedDeadline,   // Earliest Deadline First
  KernSchedMLFQ,       // Multi-Level Feedback Queue
  KernSchedLottery,    // Lottery scheduling
  KernSchedStride      // Stride scheduling
};

// Process state
typedef NS_ENUM(NSInteger, KernProcessState) {
  KernProcRunning = 0,
  KernProcReady,
  KernProcBlocked,
  KernProcSleeping,
  KernProcStopped,
  KernProcZombie,
  KernProcDead,
  KernProcWaitingIO,
  KernProcWaitingIPC,
  KernProcWaitingMutex,
  KernProcUninterruptible
};

// Signal definitions
typedef NS_ENUM(NSInteger, KernSignal) {
  KernSIGHUP = 1,
  KernSIGINT = 2,
  KernSIGQUIT = 3,
  KernSIGILL = 4,
  KernSIGTRAP = 5,
  KernSIGABRT = 6,
  KernSIGBUS = 7,
  KernSIGFPE = 8,
  KernSIGKILL = 9,
  KernSIGUSR1 = 10,
  KernSIGSEGV = 11,
  KernSIGUSR2 = 12,
  KernSIGPIPE = 13,
  KernSIGALRM = 14,
  KernSIGTERM = 15,
  KernSIGSTKFLT = 16,
  KernSIGCHLD = 17,
  KernSIGCONT = 18,
  KernSIGSTOP = 19,
  KernSIGTSTP = 20,
  KernSIGTTIN = 21,
  KernSIGTTOU = 22,
  KernSIGURG = 23,
  KernSIGXCPU = 24,
  KernSIGXFSZ = 25,
  KernSIGVTALRM = 26,
  KernSIGPROF = 27,
  KernSIGWINCH = 28,
  KernSIGIO = 29,
  KernSIGPWR = 30,
  KernSIGSYS = 31,
  KernSIGRTMIN = 34,
  KernSIGRTMAX = 64
};

// CPU Register Context
@interface KernCPUContext : NSObject
@property(nonatomic, assign) uint64_t rax, rbx, rcx, rdx;
@property(nonatomic, assign) uint64_t rsi, rdi, rbp, rsp;
@property(nonatomic, assign) uint64_t r8, r9, r10, r11;
@property(nonatomic, assign) uint64_t r12, r13, r14, r15;
@property(nonatomic, assign) uint64_t rip, rflags;
@property(nonatomic, assign) uint64_t cs, ds, es, fs, gs, ss;
@property(nonatomic, assign) uint64_t cr3;        // Page table base
@property(nonatomic, strong) NSData *fpuState;    // FPU/SSE/AVX state
@property(nonatomic, strong) NSData *vectorState; // NEON/SVE state
@end

// Advanced Process Control Block (PCB)
@interface KernProcess : NSObject
@property(nonatomic, assign) uint32_t pid;
@property(nonatomic, assign) uint32_t ppid;
@property(nonatomic, assign) uint32_t pgid; // Process group ID
@property(nonatomic, assign) uint32_t sid;  // Session ID
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSString *executablePath;
@property(nonatomic, strong) NSArray<NSString *> *arguments;
@property(nonatomic, strong) NSDictionary<NSString *, NSString *> *environment;
@property(nonatomic, assign) KernProcessState state;
@property(nonatomic, assign) KernSchedulingPolicy schedPolicy;
@property(nonatomic, assign) int32_t priority;        // Static priority
@property(nonatomic, assign) int32_t niceness;        // Nice value (-20 to 19)
@property(nonatomic, assign) int32_t dynamicPriority; // Computed priority
@property(nonatomic, assign) uint64_t virtualRuntime; // CFS vruntime
@property(nonatomic, assign) uint64_t cpuTimeUser;
@property(nonatomic, assign) uint64_t cpuTimeSystem;
@property(nonatomic, assign) uint64_t cpuTimeTotal;
@property(nonatomic, assign) uint64_t wallClockTime;
@property(nonatomic, assign) uint64_t contextSwitches;
@property(nonatomic, assign) uint64_t pageFaults;
@property(nonatomic, assign) uint64_t minorFaults;
@property(nonatomic, assign) uint64_t majorFaults;
@property(nonatomic, assign) uint32_t cpuAffinity; // CPU mask
@property(nonatomic, assign) uint32_t currentCPU;
@property(nonatomic, strong) KernCPUContext *cpuContext;
@property(nonatomic, strong) NSMutableArray<KernVMA *> *memoryMaps;
@property(nonatomic, assign) uint64_t heapStart;
@property(nonatomic, assign) uint64_t heapEnd;
@property(nonatomic, assign) uint64_t stackTop;
@property(nonatomic, assign) uint64_t stackBottom;
@property(nonatomic, assign) uint64_t memoryUsage;
@property(nonatomic, assign) uint64_t peakMemoryUsage;
@property(nonatomic, assign) uint32_t uid;
@property(nonatomic, assign) uint32_t gid;
@property(nonatomic, assign) uint32_t euid;
@property(nonatomic, assign) uint32_t egid;
@property(nonatomic, strong) NSMutableArray *openFileDescriptors;
@property(nonatomic, assign) uint32_t maxFDs;
@property(nonatomic, strong) NSMutableDictionary *signalHandlers;
@property(nonatomic, assign) uint64_t pendingSignals;
@property(nonatomic, assign) uint64_t blockedSignals;
@property(nonatomic, strong) NSMutableArray<KernProcess *> *threads;
@property(nonatomic, weak) KernProcess *parent;
@property(nonatomic, strong) NSMutableArray<KernProcess *> *children;
@property(nonatomic, assign) int32_t exitCode;
@property(nonatomic, strong) NSDate *startTime;
@property(nonatomic, strong) NSDate *endTime;
@property(nonatomic, assign) uint64_t deadlineNs; // For EDF scheduling
@property(nonatomic, assign) uint64_t periodNs;
@property(nonatomic, assign) uint64_t runtimeNs;
@property(nonatomic, assign) uint32_t tickets; // For lottery scheduling
@property(nonatomic, assign) uint32_t stride;  // For stride scheduling
@property(nonatomic, assign) uint32_t pass;
@property(nonatomic, assign) uint32_t namespaceID;
@property(nonatomic, assign) uint32_t cgroupID;
@end

// Run Queue (per-CPU)
@interface KernRunQueue : NSObject
@property(nonatomic, assign) uint32_t cpuID;
@property(nonatomic, assign) NSUInteger taskCount;
@property(nonatomic, strong) NSMutableArray<KernProcess *> *realtimeTasks;
@property(nonatomic, strong) NSMutableArray<KernProcess *> *normalTasks;
@property(nonatomic, strong) NSMutableArray<KernProcess *> *idleTasks;
@property(nonatomic, strong) KernProcess *currentTask;
@property(nonatomic, assign) uint64_t totalWeight;
@property(nonatomic, assign) uint64_t minVruntime;
@property(nonatomic, assign) uint64_t clockTicks;
@property(nonatomic, assign) uint64_t contextSwitchCount;
@property(nonatomic, assign) uint64_t loadAverage1;
@property(nonatomic, assign) uint64_t loadAverage5;
@property(nonatomic, assign) uint64_t loadAverage15;
@end

// ==========================================================================
// SECTION 3: INTER-PROCESS COMMUNICATION (IPC)
// ==========================================================================

typedef NS_ENUM(NSInteger, KernIPCType) {
  KernIPCPipe = 0,
  KernIPCNamedPipe,
  KernIPCMessageQueue,
  KernIPCSharedMemory,
  KernIPCSemaphore,
  KernIPCSignal,
  KernIPCSocket,
  KernIPCUnixSocket,
  KernIPCMachPort,
  KernIPCEventFD,
  KernIPCSignalFD
};

// Pipe
@interface KernPipe : NSObject
@property(nonatomic, assign) uint32_t pipeID;
@property(nonatomic, assign) uint32_t readFD;
@property(nonatomic, assign) uint32_t writeFD;
@property(nonatomic, strong) NSMutableData *buffer;
@property(nonatomic, assign) NSUInteger bufferSize;
@property(nonatomic, assign) NSUInteger maxBufferSize;
@property(nonatomic, assign) NSUInteger readPosition;
@property(nonatomic, assign) NSUInteger writePosition;
@property(nonatomic, assign) uint32_t readerPID;
@property(nonatomic, assign) uint32_t writerPID;
@property(nonatomic, assign) BOOL readerClosed;
@property(nonatomic, assign) BOOL writerClosed;
@property(nonatomic, assign) BOOL isBlocking;
@property(nonatomic, strong) NSString *name; // For named pipes
@end

// Message Queue
@interface KernMessageQueueMessage : NSObject
@property(nonatomic, assign) uint64_t type;
@property(nonatomic, strong) NSData *data;
@property(nonatomic, assign) uint32_t senderPID;
@property(nonatomic, assign) uint64_t timestamp;
@property(nonatomic, assign) int32_t priority;
@end

@interface KernMessageQueue : NSObject
@property(nonatomic, assign) uint32_t queueID;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong)
    NSMutableArray<KernMessageQueueMessage *> *messages;
@property(nonatomic, assign) NSUInteger maxMessages;
@property(nonatomic, assign) NSUInteger maxMessageSize;
@property(nonatomic, assign) NSUInteger currentSize;
@property(nonatomic, assign) uint32_t ownerPID;
@property(nonatomic, assign) uint32_t permissions;
@property(nonatomic, assign) uint64_t sendCount;
@property(nonatomic, assign) uint64_t receiveCount;
@property(nonatomic, strong) NSMutableArray *waitingReaders;
@property(nonatomic, strong) NSMutableArray *waitingWriters;
@end

// Shared Memory
@interface KernSharedMemory : NSObject
@property(nonatomic, assign) uint32_t shmID;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSMutableData *data;
@property(nonatomic, assign) NSUInteger size;
@property(nonatomic, assign) uint32_t ownerPID;
@property(nonatomic, assign) uint32_t permissions;
@property(nonatomic, assign) NSUInteger attachCount;
@property(nonatomic, strong) NSMutableArray *attachedProcesses;
@property(nonatomic, assign) uint64_t createTime;
@property(nonatomic, assign) uint64_t lastAttachTime;
@property(nonatomic, assign) uint64_t lastDetachTime;
@property(nonatomic, assign) BOOL markedForDeletion;
@end

// Semaphore
@interface KernSemaphore : NSObject
@property(nonatomic, assign) uint32_t semID;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, assign) int32_t value;
@property(nonatomic, assign) int32_t initialValue;
@property(nonatomic, assign) uint32_t ownerPID;
@property(nonatomic, strong) NSMutableArray *waitQueue;
@property(nonatomic, assign) uint64_t waitCount;
@property(nonatomic, assign) uint64_t postCount;
@end

// ==========================================================================
// SECTION 4: THREADING & SYNCHRONIZATION
// ==========================================================================

typedef NS_ENUM(NSInteger, KernThreadState) {
  KernThreadRunning = 0,
  KernThreadReady,
  KernThreadBlocked,
  KernThreadSleeping,
  KernThreadTerminated,
  KernThreadJoinable,
  KernThreadDetached
};

typedef NS_ENUM(NSInteger, KernMutexType) {
  KernMutexNormal = 0,
  KernMutexRecursive,
  KernMutexErrorCheck,
  KernMutexAdaptive,
  KernMutexRobust
};

typedef NS_ENUM(NSInteger, KernRWLockState) {
  KernRWLockFree = 0,
  KernRWLockReadLocked,
  KernRWLockWriteLocked
};

// Thread
@interface KernThread : NSObject
@property(nonatomic, assign) uint32_t threadID;
@property(nonatomic, assign) uint32_t processID;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, assign) KernThreadState state;
@property(nonatomic, assign) int32_t priority;
@property(nonatomic, assign) uint64_t stackSize;
@property(nonatomic, assign) uint64_t stackBase;
@property(nonatomic, strong) KernCPUContext *context;
@property(nonatomic, assign) uint64_t cpuTime;
@property(nonatomic, assign) uint32_t cpuAffinity;
@property(nonatomic, assign) uint64_t tlsBase; // Thread-local storage
@property(nonatomic, assign) BOOL isDetached;
@property(nonatomic, assign) BOOL isDaemon;
@property(nonatomic, assign) int32_t exitCode;
@property(nonatomic, strong) NSDate *startTime;
@end

// Mutex
@interface KernMutex : NSObject
@property(nonatomic, assign) uint32_t mutexID;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, assign) KernMutexType type;
@property(nonatomic, assign) BOOL locked;
@property(nonatomic, assign) uint32_t ownerThreadID;
@property(nonatomic, assign) uint32_t recursionCount;
@property(nonatomic, strong) NSMutableArray *waitQueue;
@property(nonatomic, assign) int32_t priorityCeiling;
@property(nonatomic, assign) BOOL usePriorityInheritance;
@property(nonatomic, assign) uint64_t lockCount;
@property(nonatomic, assign) uint64_t contentionCount;
@end

// Read-Write Lock
@interface KernRWLock : NSObject
@property(nonatomic, assign) uint32_t rwlockID;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, assign) KernRWLockState state;
@property(nonatomic, assign) uint32_t readerCount;
@property(nonatomic, assign) uint32_t writerThreadID;
@property(nonatomic, strong) NSMutableArray *readWaitQueue;
@property(nonatomic, strong) NSMutableArray *writeWaitQueue;
@property(nonatomic, assign) BOOL preferWriters;
@end

// Condition Variable
@interface KernCondVar : NSObject
@property(nonatomic, assign) uint32_t condID;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSMutableArray *waitQueue;
@property(nonatomic, assign) uint64_t signalCount;
@property(nonatomic, assign) uint64_t broadcastCount;
@end

// Spinlock
@interface KernSpinlock : NSObject
@property(nonatomic, assign) uint32_t spinlockID;
@property(nonatomic, assign) volatile BOOL locked;
@property(nonatomic, assign) uint32_t ownerCPU;
@property(nonatomic, assign) uint64_t spinCount;
@property(nonatomic, assign) BOOL interruptsDisabled;
@end

// Barrier
@interface KernBarrier : NSObject
@property(nonatomic, assign) uint32_t barrierID;
@property(nonatomic, assign) uint32_t threshold;
@property(nonatomic, assign) uint32_t currentCount;
@property(nonatomic, assign) uint32_t generation;
@property(nonatomic, strong) NSMutableArray *waitQueue;
@end

// ==========================================================================
// SECTION 5: SYSTEM CALL INTERFACE
// ==========================================================================

typedef NS_ENUM(NSInteger, KernSyscallNumber) {
  // Process management
  KSYS_EXIT = 0,
  KSYS_FORK,
  KSYS_VFORK,
  KSYS_EXEC,
  KSYS_WAIT,
  KSYS_WAITPID,
  KSYS_GETPID,
  KSYS_GETPPID,
  KSYS_GETUID,
  KSYS_GETGID,
  KSYS_SETUID,
  KSYS_SETGID,
  KSYS_SETSID,
  KSYS_GETPGID,
  KSYS_SETPGID,
  KSYS_KILL,
  KSYS_SIGNAL,
  KSYS_SIGACTION,
  KSYS_SIGPROCMASK,
  KSYS_ALARM,
  KSYS_PAUSE,
  KSYS_NANOSLEEP,
  KSYS_CLONE,
  KSYS_NICE,
  KSYS_SCHED_SETPARAM,
  KSYS_SCHED_GETPARAM,
  KSYS_SCHED_YIELD,
  KSYS_PRCTL,
  KSYS_ARCH_PRCTL,
  // File operations
  KSYS_OPEN = 50,
  KSYS_CLOSE,
  KSYS_READ,
  KSYS_WRITE,
  KSYS_LSEEK,
  KSYS_STAT,
  KSYS_FSTAT,
  KSYS_LSTAT,
  KSYS_POLL,
  KSYS_SELECT,
  KSYS_EPOLL_CREATE,
  KSYS_EPOLL_CTL,
  KSYS_EPOLL_WAIT,
  KSYS_DUP,
  KSYS_DUP2,
  KSYS_PIPE,
  KSYS_PIPE2,
  KSYS_FCNTL,
  KSYS_IOCTL,
  KSYS_ACCESS,
  KSYS_MKDIR,
  KSYS_RMDIR,
  KSYS_UNLINK,
  KSYS_RENAME,
  KSYS_LINK,
  KSYS_SYMLINK,
  KSYS_READLINK,
  KSYS_CHMOD,
  KSYS_CHOWN,
  KSYS_TRUNCATE,
  KSYS_FSYNC,
  KSYS_FDATASYNC,
  KSYS_GETDENTS,
  KSYS_GETCWD,
  KSYS_CHDIR,
  KSYS_CHROOT,
  KSYS_MOUNT,
  KSYS_UMOUNT,
  KSYS_STATFS,
  KSYS_FSTATFS,
  KSYS_OPENAT,
  KSYS_MKDIRAT,
  KSYS_UNLINKAT,
  KSYS_RENAMEAT,
  KSYS_FCHMOD,
  KSYS_FCHOWN,
  KSYS_UTIMES,
  KSYS_SENDFILE,
  KSYS_SPLICE,
  KSYS_TEE,
  // Memory management
  KSYS_MMAP = 150,
  KSYS_MUNMAP,
  KSYS_MPROTECT,
  KSYS_MADVISE,
  KSYS_MREMAP,
  KSYS_MSYNC,
  KSYS_MLOCK,
  KSYS_MUNLOCK,
  KSYS_MLOCKALL,
  KSYS_MUNLOCKALL,
  KSYS_BRK,
  KSYS_SBRK,
  KSYS_MINCORE,
  // IPC
  KSYS_MSGGET = 200,
  KSYS_MSGSND,
  KSYS_MSGRCV,
  KSYS_MSGCTL,
  KSYS_SEMGET,
  KSYS_SEMOP,
  KSYS_SEMCTL,
  KSYS_SHMGET,
  KSYS_SHMAT,
  KSYS_SHMDT,
  KSYS_SHMCTL,
  // Networking
  KSYS_SOCKET = 250,
  KSYS_BIND,
  KSYS_LISTEN,
  KSYS_ACCEPT,
  KSYS_CONNECT,
  KSYS_SEND,
  KSYS_RECV,
  KSYS_SENDTO,
  KSYS_RECVFROM,
  KSYS_SENDMSG,
  KSYS_RECVMSG,
  KSYS_SHUTDOWN,
  KSYS_GETSOCKNAME,
  KSYS_GETPEERNAME,
  KSYS_SETSOCKOPT,
  KSYS_GETSOCKOPT,
  KSYS_SOCKETPAIR,
  // Time
  KSYS_GETTIMEOFDAY = 300,
  KSYS_SETTIMEOFDAY,
  KSYS_CLOCK_GETTIME,
  KSYS_CLOCK_SETTIME,
  KSYS_CLOCK_GETRES,
  KSYS_TIMER_CREATE,
  KSYS_TIMER_SETTIME,
  KSYS_TIMER_GETTIME,
  KSYS_TIMER_DELETE,
  // System info
  KSYS_UNAME = 350,
  KSYS_SYSINFO,
  KSYS_SYSLOG,
  KSYS_GETRUSAGE,
  KSYS_GETRLIMIT,
  KSYS_SETRLIMIT,
  KSYS_PRLIMIT,
  KSYS_TIMES,
  // Thread / futex
  KSYS_FUTEX = 400,
  KSYS_SET_TID_ADDRESS,
  KSYS_SET_ROBUST_LIST,
  KSYS_GET_ROBUST_LIST,
  KSYS_TKILL,
  KSYS_TGKILL,
  // Misc
  KSYS_REBOOT = 450,
  KSYS_SYNC,
  KSYS_ACCT,
  KSYS_PTRACE,
  KSYS_PERF_EVENT_OPEN,
  KSYS_GETRANDOM,
  KSYS_MEMFD_CREATE,
  KSYS_COPY_FILE_RANGE,
  KSYS_PREADV2,
  KSYS_PWRITEV2,
  KSYS_IO_URING_SETUP,
  KSYS_IO_URING_ENTER,
  KSYS_IO_URING_REGISTER,
  KSYS_PIDFD_OPEN,
  KSYS_CLOSE_RANGE,
  KSYS_OPENAT2,
  KSYS_FACCESSAT2,

  KSYS_MAX_SYSCALL = 512
};

// Syscall result
@interface KernSyscallResult : NSObject
@property(nonatomic, assign) int64_t returnValue;
@property(nonatomic, assign) int32_t errorCode;
@property(nonatomic, strong) NSString *errorMessage;
@property(nonatomic, assign) BOOL success;
@end

// ==========================================================================
// SECTION 6: VIRTUAL FILE SYSTEM (VFS) LAYER
// ==========================================================================

typedef NS_ENUM(NSInteger, KernFileSystemType) {
  KernFSTypeExt4 = 0,
  KernFSTypeXFS,
  KernFSTypeBtrfs,
  KernFSTypeZFS,
  KernFSTypeNTFS,
  KernFSTypeFAT32,
  KernFSTypeExFAT,
  KernFSTypeHFS,
  KernFSTypeAPFS,
  KernFSTypeTmpFS,
  KernFSTypeProcFS,
  KernFSTypeSysFS,
  KernFSTypeDevFS,
  KernFSTypeNFS,
  KernFSTypeCIFS,
  KernFSTypeOverlayFS,
  KernFSTypeSquashFS,
  KernFSTypeF2FS,
  KernFSTypeFUSE,
  KernFSTypeISO9660,
  KernFSTypeUDF,
  KernFSTypeJFS,
  KernFSTypeReiserFS,
  KernFSTypeMinix
};

typedef NS_ENUM(NSInteger, KernInodeType) {
  KernInodeFile = 0,
  KernInodeDirectory,
  KernInodeSymlink,
  KernInodeCharDevice,
  KernInodeBlockDevice,
  KernInodePipe,
  KernInodeSocket
};

// Inode
@interface KernInode : NSObject
@property(nonatomic, assign) uint64_t inodeNumber;
@property(nonatomic, assign) KernInodeType type;
@property(nonatomic, assign) uint32_t mode;
@property(nonatomic, assign) uint32_t uid;
@property(nonatomic, assign) uint32_t gid;
@property(nonatomic, assign) uint64_t size;
@property(nonatomic, assign) uint64_t blocks;
@property(nonatomic, assign) uint32_t linkCount;
@property(nonatomic, assign) uint64_t accessTime;
@property(nonatomic, assign) uint64_t modifyTime;
@property(nonatomic, assign) uint64_t changeTime;
@property(nonatomic, assign) uint64_t createTime;
@property(nonatomic, assign) uint32_t deviceMajor;
@property(nonatomic, assign) uint32_t deviceMinor;
@property(nonatomic, strong) NSMutableArray *dataBlocks;
@property(nonatomic, strong) NSMutableDictionary *extendedAttributes;
@property(nonatomic, assign) KernFileSystemType fsType;
@end

// Directory Entry (dentry)
@interface KernDentry : NSObject
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) KernInode *inode;
@property(nonatomic, weak) KernDentry *parent;
@property(nonatomic, strong) NSMutableArray<KernDentry *> *children;
@property(nonatomic, assign) BOOL isMountPoint;
@property(nonatomic, assign) uint32_t referenceCount;
@property(nonatomic, assign) BOOL isNegative; // Cached negative lookup
@end

// Superblock
@interface KernSuperblock : NSObject
@property(nonatomic, assign) KernFileSystemType fsType;
@property(nonatomic, strong) NSString *deviceName;
@property(nonatomic, strong) NSString *mountPoint;
@property(nonatomic, assign) uint64_t blockSize;
@property(nonatomic, assign) uint64_t totalBlocks;
@property(nonatomic, assign) uint64_t freeBlocks;
@property(nonatomic, assign) uint64_t totalInodes;
@property(nonatomic, assign) uint64_t freeInodes;
@property(nonatomic, assign) uint32_t maxFilenameLength;
@property(nonatomic, assign) uint64_t maxFileSize;
@property(nonatomic, strong) NSString *volumeLabel;
@property(nonatomic, strong) NSString *uuid;
@property(nonatomic, assign) uint32_t mountFlags;
@property(nonatomic, assign) BOOL readOnly;
@property(nonatomic, strong) KernDentry *rootDentry;
@end

// Mount Point
@interface KernMountPoint : NSObject
@property(nonatomic, strong) NSString *source;
@property(nonatomic, strong) NSString *target;
@property(nonatomic, strong) KernSuperblock *superblock;
@property(nonatomic, assign) uint32_t flags;
@property(nonatomic, strong) NSDictionary *options;
@property(nonatomic, assign) uint32_t mountID;
@property(nonatomic, assign) uint32_t parentMountID;
@end

// File Descriptor
@interface KernFileDescriptor : NSObject
@property(nonatomic, assign) int32_t fd;
@property(nonatomic, strong) KernInode *inode;
@property(nonatomic, assign) uint64_t offset;
@property(nonatomic, assign) uint32_t flags;
@property(nonatomic, assign) uint32_t mode;
@property(nonatomic, assign) uint32_t referenceCount;
@property(nonatomic, assign) BOOL closeOnExec;
@property(nonatomic, assign) BOOL nonBlocking;
@property(nonatomic, assign) BOOL append;
@property(nonatomic, strong) KernPipe *pipe; // If fd is a pipe
@end

// ==========================================================================
// SECTION 7: SECURITY & SANDBOXING
// ==========================================================================

typedef NS_OPTIONS(NSUInteger, KernCapability) {
  KernCapChown = 1ULL << 0,
  KernCapDacOverride = 1ULL << 1,
  KernCapDacReadSearch = 1ULL << 2,
  KernCapFOwner = 1ULL << 3,
  KernCapFSetID = 1ULL << 4,
  KernCapKill = 1ULL << 5,
  KernCapSetGID = 1ULL << 6,
  KernCapSetUID = 1ULL << 7,
  KernCapSetPCap = 1ULL << 8,
  KernCapNetBindService = 1ULL << 10,
  KernCapNetBroadcast = 1ULL << 11,
  KernCapNetAdmin = 1ULL << 12,
  KernCapNetRaw = 1ULL << 13,
  KernCapIPCLock = 1ULL << 14,
  KernCapIPCOwner = 1ULL << 15,
  KernCapSysModule = 1ULL << 16,
  KernCapSysRawIO = 1ULL << 17,
  KernCapSysChroot = 1ULL << 18,
  KernCapSysPTrace = 1ULL << 19,
  KernCapSysPAcct = 1ULL << 20,
  KernCapSysAdmin = 1ULL << 21,
  KernCapSysBoot = 1ULL << 22,
  KernCapSysNice = 1ULL << 23,
  KernCapSysResource = 1ULL << 24,
  KernCapSysTime = 1ULL << 25,
  KernCapSysTTYConfig = 1ULL << 26,
  KernCapAuditControl = 1ULL << 30,
  KernCapAuditWrite = 1ULL << 29,
  KernCapSyslog = 1ULL << 34,
  KernCapWakeAlarm = 1ULL << 35,
  KernCapBlockSuspend = 1ULL << 36,
  KernCapAll = 0xFFFFFFFFFFFFFFFFULL
};

typedef NS_ENUM(NSInteger, KernNamespaceType) {
  KernNSMount = 0,
  KernNSUTS,
  KernNSIPC,
  KernNSPID,
  KernNSNet,
  KernNSUser,
  KernNSCgroup,
  KernNSTime
};

// Namespace
@interface KernNamespace : NSObject
@property(nonatomic, assign) uint32_t nsID;
@property(nonatomic, assign) KernNamespaceType type;
@property(nonatomic, strong) NSMutableArray *memberPIDs;
@property(nonatomic, assign) uint32_t ownerUID;
@property(nonatomic, assign) uint64_t createTime;
@end

// Sandbox Profile
@interface KernSandboxProfile : NSObject
@property(nonatomic, strong) NSString *name;
@property(nonatomic, assign) KernCapability allowedCapabilities;
@property(nonatomic, strong) NSArray<NSString *> *allowedPaths;
@property(nonatomic, strong) NSArray<NSString *> *deniedPaths;
@property(nonatomic, strong) NSArray<NSString *> *allowedSyscalls;
@property(nonatomic, strong) NSArray<NSString *> *deniedSyscalls;
@property(nonatomic, assign) BOOL allowNetworking;
@property(nonatomic, assign) BOOL allowFileCreation;
@property(nonatomic, assign) BOOL allowProcessCreation;
@property(nonatomic, assign) uint64_t maxMemory;
@property(nonatomic, assign) uint64_t maxCPUTime;
@property(nonatomic, assign) uint32_t maxFDs;
@property(nonatomic, assign) uint32_t maxProcesses;
@property(nonatomic, assign) uint32_t maxThreads;
@end

// Cgroup (Control Group)
@interface KernCgroup : NSObject
@property(nonatomic, assign) uint32_t cgroupID;
@property(nonatomic, strong) NSString *name;
@property(nonatomic, strong) NSString *path;
@property(nonatomic, weak) KernCgroup *parent;
@property(nonatomic, strong) NSMutableArray<KernCgroup *> *children;
@property(nonatomic, strong) NSMutableArray *memberPIDs;
// Resource limits
@property(nonatomic, assign) uint64_t cpuQuotaUs;
@property(nonatomic, assign) uint64_t cpuPeriodUs;
@property(nonatomic, assign) int64_t cpuShares;
@property(nonatomic, assign) uint64_t memoryLimitBytes;
@property(nonatomic, assign) uint64_t memorySwapLimit;
@property(nonatomic, assign) uint64_t memoryUsage;
@property(nonatomic, assign) uint64_t ioReadBps;
@property(nonatomic, assign) uint64_t ioWriteBps;
@property(nonatomic, assign) uint64_t ioReadIOps;
@property(nonatomic, assign) uint64_t ioWriteIOps;
@property(nonatomic, assign) uint32_t pidsMax;
@property(nonatomic, assign) uint32_t pidsCurrent;
@end

// ==========================================================================
// SECTION 8: KERNEL LOGGING & TRACING
// ==========================================================================

typedef NS_ENUM(NSInteger, KernLogLevel) {
  KernLogEmergency = 0,
  KernLogAlert,
  KernLogCritical,
  KernLogError,
  KernLogWarning,
  KernLogNotice,
  KernLogInfo,
  KernLogDebug,
  KernLogTrace
};

typedef NS_ENUM(NSInteger, KernLogFacility) {
  KernLogKernel = 0,
  KernLogScheduler,
  KernLogMemory,
  KernLogIPC,
  KernLogVFS,
  KernLogNetwork,
  KernLogSecurity,
  KernLogDriver,
  KernLogProcess,
  KernLogThread,
  KernLogSyscall,
  KernLogInterrupt,
  KernLogTimer,
  KernLogPower,
  KernLogAudit
};

@interface KernLogEntry : NSObject
@property(nonatomic, assign) uint64_t sequenceNumber;
@property(nonatomic, assign) KernLogLevel level;
@property(nonatomic, assign) KernLogFacility facility;
@property(nonatomic, strong) NSString *subsystem;
@property(nonatomic, strong) NSString *message;
@property(nonatomic, assign) uint64_t timestampNs;
@property(nonatomic, assign) uint32_t processID;
@property(nonatomic, assign) uint32_t threadID;
@property(nonatomic, assign) uint32_t cpuID;
@property(nonatomic, strong) NSString *functionName;
@property(nonatomic, strong) NSString *fileName;
@property(nonatomic, assign) uint32_t lineNumber;
@end

// ==========================================================================
// SECTION 9: ADVANCED KERNEL MANAGER
// ==========================================================================

@interface AdvancedKernel : NSObject

+ (instancetype)sharedInstance;

// --- Virtual Memory ---
- (void)initializeVirtualMemory;
- (KernPageTableEntry *)allocatePage;
- (void)freePage:(KernPageTableEntry *)page;
- (uint64_t)mapVirtualAddress:(uint64_t)virtualAddr
                   toPhysical:(uint64_t)physAddr
                   protection:(KernMemoryProtection)prot
                   forProcess:(uint32_t)pid;
- (void)unmapVirtualAddress:(uint64_t)virtualAddr forProcess:(uint32_t)pid;
- (KernPageTableEntry *)translateAddress:(uint64_t)virtualAddr
                              forProcess:(uint32_t)pid;
- (void)handlePageFault:(uint64_t)address
                 reason:(KernPageFaultReason)reason
             forProcess:(uint32_t)pid;
- (void)flushTLB;
- (void)flushTLBEntry:(uint64_t)virtualAddr;
- (KernVMA *)mmapForProcess:(uint32_t)pid
                    address:(uint64_t)addr
                     length:(uint64_t)len
                 protection:(KernMemoryProtection)prot
                      flags:(KernMmapFlags)flags;
- (BOOL)munmapForProcess:(uint32_t)pid
                 address:(uint64_t)addr
                  length:(uint64_t)len;
- (BOOL)mprotectForProcess:(uint32_t)pid
                   address:(uint64_t)addr
                    length:(uint64_t)len
                protection:(KernMemoryProtection)prot;

// Slab allocator
- (KernSlabCache *)createSlabCache:(NSString *)name
                        objectSize:(NSUInteger)size
                         alignment:(NSUInteger)align;
- (void *)slabAlloc:(KernSlabCache *)cache;
- (void)slabFree:(KernSlabCache *)cache object:(void *)obj;

// Buddy allocator
- (KernBuddyBlock *)buddyAllocate:(NSUInteger)order zone:(KernMemoryZone)zone;
- (void)buddyFree:(KernBuddyBlock *)block;

// Memory statistics
- (NSDictionary *)memoryStatistics;
- (uint64_t)totalPhysicalMemory;
- (uint64_t)availableMemory;
- (uint64_t)cachedMemory;
- (uint64_t)swapUsed;
- (uint64_t)swapTotal;

// --- Process Scheduler ---
- (KernProcess *)createProcess:(NSString *)name
                executablePath:(NSString *)path
                     arguments:(NSArray<NSString *> *)args
                     parentPID:(uint32_t)ppid;
- (void)terminateProcess:(uint32_t)pid exitCode:(int32_t)code;
- (void)killProcess:(uint32_t)pid signal:(KernSignal)signal;
- (void)schedule;
- (void)contextSwitch:(KernProcess *)from to:(KernProcess *)to;
- (void)setSchedulingPolicy:(KernSchedulingPolicy)policy
                 forProcess:(uint32_t)pid;
- (void)setNiceness:(int32_t)nice forProcess:(uint32_t)pid;
- (void)setCPUAffinity:(uint32_t)mask forProcess:(uint32_t)pid;
- (KernProcess *)processForPID:(uint32_t)pid;
- (NSArray<KernProcess *> *)allProcesses;
- (NSArray<KernProcess *> *)processesForUser:(uint32_t)uid;
- (void)sendSignal:(KernSignal)signal toProcess:(uint32_t)pid;

// --- IPC ---
- (KernPipe *)createPipe;
- (KernPipe *)createNamedPipe:(NSString *)name;
- (NSInteger)pipeWrite:(KernPipe *)pipe data:(NSData *)data;
- (NSData *)pipeRead:(KernPipe *)pipe length:(NSUInteger)length;
- (void)closePipe:(KernPipe *)pipe;

- (KernMessageQueue *)createMessageQueue:(NSString *)name
                             maxMessages:(NSUInteger)max
                                 maxSize:(NSUInteger)size;
- (BOOL)sendMessage:(KernMessageQueueMessage *)msg
            toQueue:(KernMessageQueue *)queue;
- (KernMessageQueueMessage *)receiveMessageFromQueue:(KernMessageQueue *)queue
                                                type:(uint64_t)type;
- (void)destroyMessageQueue:(KernMessageQueue *)queue;

- (KernSharedMemory *)createSharedMemory:(NSString *)name size:(NSUInteger)size;
- (void *)attachSharedMemory:(KernSharedMemory *)shm forProcess:(uint32_t)pid;
- (void)detachSharedMemory:(KernSharedMemory *)shm fromProcess:(uint32_t)pid;
- (void)destroySharedMemory:(KernSharedMemory *)shm;

- (KernSemaphore *)createSemaphore:(NSString *)name initialValue:(int32_t)value;
- (BOOL)semaphoreWait:(KernSemaphore *)sem;
- (BOOL)semaphoreTryWait:(KernSemaphore *)sem;
- (void)semaphorePost:(KernSemaphore *)sem;
- (void)destroySemaphore:(KernSemaphore *)sem;

// --- Threading ---
- (KernThread *)createThread:(uint32_t)processID
                        name:(NSString *)name
                    priority:(int32_t)priority
                   stackSize:(uint64_t)stackSize;
- (void)terminateThread:(uint32_t)threadID exitCode:(int32_t)code;
- (void)joinThread:(uint32_t)threadID;
- (void)detachThread:(uint32_t)threadID;
- (void)sleepThread:(uint64_t)nanoseconds;

- (KernMutex *)createMutex:(NSString *)name type:(KernMutexType)type;
- (BOOL)mutexLock:(KernMutex *)mutex;
- (BOOL)mutexTryLock:(KernMutex *)mutex;
- (void)mutexUnlock:(KernMutex *)mutex;
- (void)destroyMutex:(KernMutex *)mutex;

- (KernRWLock *)createRWLock:(NSString *)name;
- (BOOL)rwlockReadLock:(KernRWLock *)lock;
- (BOOL)rwlockWriteLock:(KernRWLock *)lock;
- (void)rwlockUnlock:(KernRWLock *)lock;
- (void)destroyRWLock:(KernRWLock *)lock;

- (KernCondVar *)createCondVar:(NSString *)name;
- (void)condVarWait:(KernCondVar *)cond mutex:(KernMutex *)mutex;
- (BOOL)condVarTimedWait:(KernCondVar *)cond
                   mutex:(KernMutex *)mutex
               timeoutNs:(uint64_t)timeout;
- (void)condVarSignal:(KernCondVar *)cond;
- (void)condVarBroadcast:(KernCondVar *)cond;
- (void)destroyCondVar:(KernCondVar *)cond;

- (KernBarrier *)createBarrier:(uint32_t)count;
- (void)barrierWait:(KernBarrier *)barrier;
- (void)destroyBarrier:(KernBarrier *)barrier;

// --- Syscall Interface ---
- (KernSyscallResult *)executeSyscall:(KernSyscallNumber)number
                                 args:(NSArray *)args;
- (NSString *)syscallName:(KernSyscallNumber)number;
- (NSUInteger)totalSyscallCount;

// --- VFS ---
- (void)initializeVFS;
- (KernSuperblock *)mountFileSystem:(KernFileSystemType)type
                             device:(NSString *)device
                         mountPoint:(NSString *)mountPoint
                            options:(NSDictionary *)options;
- (BOOL)unmountFileSystem:(NSString *)mountPoint;
- (KernInode *)lookupPath:(NSString *)path;
- (KernInode *)createFile:(NSString *)path mode:(uint32_t)mode;
- (KernInode *)createDirectory:(NSString *)path mode:(uint32_t)mode;
- (BOOL)deleteInode:(NSString *)path;
- (BOOL)linkPath:(NSString *)target to:(NSString *)linkPath;
- (BOOL)symlinkPath:(NSString *)target to:(NSString *)linkPath;
- (NSArray<KernDentry *> *)readDirectory:(NSString *)path;
- (KernFileDescriptor *)openFile:(NSString *)path
                           flags:(uint32_t)flags
                            mode:(uint32_t)mode;
- (void)closeFile:(KernFileDescriptor *)fd;
- (NSData *)readFile:(KernFileDescriptor *)fd length:(NSUInteger)length;
- (NSInteger)writeFile:(KernFileDescriptor *)fd data:(NSData *)data;
- (BOOL)seekFile:(KernFileDescriptor *)fd
          offset:(int64_t)offset
          whence:(int32_t)whence;
- (NSArray<KernMountPoint *> *)mountedFileSystems;
- (NSDictionary *)fileSystemStatistics:(NSString *)mountPoint;

// --- Security ---
- (BOOL)checkCapability:(KernCapability)cap forProcess:(uint32_t)pid;
- (void)grantCapability:(KernCapability)cap toProcess:(uint32_t)pid;
- (void)revokeCapability:(KernCapability)cap fromProcess:(uint32_t)pid;
- (KernNamespace *)createNamespace:(KernNamespaceType)type
                        forProcess:(uint32_t)pid;
- (void)joinNamespace:(KernNamespace *)ns process:(uint32_t)pid;
- (KernSandboxProfile *)createSandboxProfile:(NSString *)name;
- (void)applySandbox:(KernSandboxProfile *)profile toProcess:(uint32_t)pid;
- (KernCgroup *)createCgroup:(NSString *)name parent:(KernCgroup *)parent;
- (void)addProcess:(uint32_t)pid toCgroup:(KernCgroup *)cgroup;
- (void)setCgroupCPULimit:(KernCgroup *)cgroup
                  quotaUs:(uint64_t)quota
                 periodUs:(uint64_t)period;
- (void)setCgroupMemoryLimit:(KernCgroup *)cgroup bytes:(uint64_t)limit;
- (NSDictionary *)cgroupStatistics:(KernCgroup *)cgroup;

// --- Logging ---
- (void)kernelLog:(KernLogLevel)level
         facility:(KernLogFacility)facility
          message:(NSString *)message;
- (NSArray<KernLogEntry *> *)logEntriesWithLevel:(KernLogLevel)minLevel
                                        facility:(KernLogFacility)facility
                                           count:(NSUInteger)count;
- (void)clearLogs;
- (NSUInteger)logCount;

// --- System Info ---
- (NSDictionary *)kernelInfo;
- (uint64_t)uptimeNanoseconds;
- (NSString *)kernelVersion;

@end
