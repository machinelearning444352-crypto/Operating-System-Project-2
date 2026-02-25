#import "AdvancedKernel.h"
#include <mach/mach_time.h>

@interface AdvancedKernel ()
@property(nonatomic, strong) NSMutableDictionary *internalState;
@property(nonatomic, strong) NSMutableArray<KernLogEntry *> *logBuffer;
@property(nonatomic, assign) uint64_t logSequence;
@property(nonatomic, assign) uint64_t bootTime;
@property(nonatomic, assign) uint64_t syscallCount;
@end

// ============================================================================
// Process Scheduler, IPC, and Threading Implementation
// ============================================================================

@implementation KernCPUContext
- (instancetype)init {
  self = [super init];
  if (self) {
    _rax = 0;
    _rbx = 0;
    _rcx = 0;
    _rdx = 0;
    _rsi = 0;
    _rdi = 0;
    _rbp = 0;
    _rsp = 0;
    _r8 = 0;
    _r9 = 0;
    _r10 = 0;
    _r11 = 0;
    _r12 = 0;
    _r13 = 0;
    _r14 = 0;
    _r15 = 0;
    _rip = 0;
    _rflags = 0;
    _cs = 0;
    _ds = 0;
    _es = 0;
    _fs = 0;
    _gs = 0;
    _ss = 0;
    _cr3 = 0;
  }
  return self;
}
@end

@implementation KernProcess
- (instancetype)init {
  self = [super init];
  if (self) {
    _pid = 0;
    _ppid = 0;
    _pgid = 0;
    _sid = 0;
    _name = @"";
    _executablePath = @"";
    _arguments = @[];
    _environment = @{};
    _state = KernProcReady;
    _schedPolicy = KernSchedNormal;
    _priority = 0;
    _niceness = 0;
    _dynamicPriority = 0;
    _virtualRuntime = 0;
    _cpuTimeUser = 0;
    _cpuTimeSystem = 0;
    _cpuTimeTotal = 0;
    _wallClockTime = 0;
    _contextSwitches = 0;
    _pageFaults = 0;
    _minorFaults = 0;
    _majorFaults = 0;
    _cpuAffinity = 0xFFFFFFFF;
    _currentCPU = 0;
    _cpuContext = [[KernCPUContext alloc] init];
    _memoryMaps = [NSMutableArray array];
    _heapStart = 0;
    _heapEnd = 0;
    _stackTop = 0;
    _stackBottom = 0;
    _memoryUsage = 0;
    _peakMemoryUsage = 0;
    _uid = 0;
    _gid = 0;
    _euid = 0;
    _egid = 0;
    _openFileDescriptors = [NSMutableArray array];
    _maxFDs = 1024;
    _signalHandlers = [NSMutableDictionary dictionary];
    _pendingSignals = 0;
    _blockedSignals = 0;
    _threads = [NSMutableArray array];
    _children = [NSMutableArray array];
    _exitCode = 0;
    _startTime = [NSDate date];
    _deadlineNs = 0;
    _periodNs = 0;
    _runtimeNs = 0;
    _tickets = 100;
    _stride = 0;
    _pass = 0;
    _namespaceID = 0;
    _cgroupID = 0;
  }
  return self;
}
@end

@implementation KernRunQueue
- (instancetype)init {
  self = [super init];
  if (self) {
    _cpuID = 0;
    _taskCount = 0;
    _realtimeTasks = [NSMutableArray array];
    _normalTasks = [NSMutableArray array];
    _idleTasks = [NSMutableArray array];
    _totalWeight = 0;
    _minVruntime = 0;
    _clockTicks = 0;
    _contextSwitchCount = 0;
    _loadAverage1 = 0;
    _loadAverage5 = 0;
    _loadAverage15 = 0;
  }
  return self;
}
@end

@implementation KernPipe
- (instancetype)init {
  self = [super init];
  if (self) {
    _pipeID = 0;
    _readFD = 0;
    _writeFD = 0;
    _buffer = [NSMutableData data];
    _bufferSize = 0;
    _maxBufferSize = 65536;
    _readPosition = 0;
    _writePosition = 0;
    _readerPID = 0;
    _writerPID = 0;
    _readerClosed = NO;
    _writerClosed = NO;
    _isBlocking = YES;
  }
  return self;
}
@end

@implementation KernMessageQueueMessage
- (instancetype)init {
  self = [super init];
  if (self) {
    _type = 0;
    _data = nil;
    _senderPID = 0;
    _timestamp = 0;
    _priority = 0;
  }
  return self;
}
@end

@implementation KernMessageQueue
- (instancetype)init {
  self = [super init];
  if (self) {
    _queueID = 0;
    _name = @"";
    _messages = [NSMutableArray array];
    _maxMessages = 256;
    _maxMessageSize = 8192;
    _currentSize = 0;
    _ownerPID = 0;
    _permissions = 0666;
    _sendCount = 0;
    _receiveCount = 0;
    _waitingReaders = [NSMutableArray array];
    _waitingWriters = [NSMutableArray array];
  }
  return self;
}
@end

@implementation KernSharedMemory
- (instancetype)init {
  self = [super init];
  if (self) {
    _shmID = 0;
    _name = @"";
    _data = [NSMutableData data];
    _size = 0;
    _ownerPID = 0;
    _permissions = 0666;
    _attachCount = 0;
    _attachedProcesses = [NSMutableArray array];
    _createTime = 0;
    _lastAttachTime = 0;
    _lastDetachTime = 0;
    _markedForDeletion = NO;
  }
  return self;
}
@end

@implementation KernSemaphore
- (instancetype)init {
  self = [super init];
  if (self) {
    _semID = 0;
    _name = @"";
    _value = 1;
    _initialValue = 1;
    _ownerPID = 0;
    _waitQueue = [NSMutableArray array];
    _waitCount = 0;
    _postCount = 0;
  }
  return self;
}
@end

@implementation KernThread
- (instancetype)init {
  self = [super init];
  if (self) {
    _threadID = 0;
    _processID = 0;
    _name = @"";
    _state = KernThreadReady;
    _priority = 0;
    _stackSize = 8 * 1024 * 1024;
    _stackBase = 0;
    _context = [[KernCPUContext alloc] init];
    _cpuTime = 0;
    _cpuAffinity = 0xFFFFFFFF;
    _tlsBase = 0;
    _isDetached = NO;
    _isDaemon = NO;
    _exitCode = 0;
    _startTime = [NSDate date];
  }
  return self;
}
@end

@implementation KernMutex
- (instancetype)init {
  self = [super init];
  if (self) {
    _mutexID = 0;
    _name = @"";
    _type = KernMutexNormal;
    _locked = NO;
    _ownerThreadID = 0;
    _recursionCount = 0;
    _waitQueue = [NSMutableArray array];
    _priorityCeiling = 0;
    _usePriorityInheritance = NO;
    _lockCount = 0;
    _contentionCount = 0;
  }
  return self;
}
@end

@implementation KernRWLock
- (instancetype)init {
  self = [super init];
  if (self) {
    _rwlockID = 0;
    _name = @"";
    _state = KernRWLockFree;
    _readerCount = 0;
    _writerThreadID = 0;
    _readWaitQueue = [NSMutableArray array];
    _writeWaitQueue = [NSMutableArray array];
    _preferWriters = YES;
  }
  return self;
}
@end

@implementation KernCondVar
- (instancetype)init {
  self = [super init];
  if (self) {
    _condID = 0;
    _name = @"";
    _waitQueue = [NSMutableArray array];
    _signalCount = 0;
    _broadcastCount = 0;
  }
  return self;
}
@end

@implementation KernSpinlock
- (instancetype)init {
  self = [super init];
  if (self) {
    _spinlockID = 0;
    _locked = NO;
    _ownerCPU = 0;
    _spinCount = 0;
    _interruptsDisabled = NO;
  }
  return self;
}
@end

@implementation KernBarrier
- (instancetype)init {
  self = [super init];
  if (self) {
    _barrierID = 0;
    _threshold = 0;
    _currentCount = 0;
    _generation = 0;
    _waitQueue = [NSMutableArray array];
  }
  return self;
}
@end

// ============================================================================
// Scheduler & IPC Methods
// ============================================================================

@implementation AdvancedKernel (Scheduler)

- (KernProcess *)createProcess:(NSString *)name
                executablePath:(NSString *)path
                     arguments:(NSArray<NSString *> *)args
                     parentPID:(uint32_t)ppid {
  static uint32_t nextPID = 1;

  KernProcess *proc = [[KernProcess alloc] init];
  proc.pid = nextPID++;
  proc.ppid = ppid;
  proc.pgid = proc.pid;
  proc.sid = proc.pid;
  proc.name = name;
  proc.executablePath = path ?: @"";
  proc.arguments = args ?: @[];
  proc.state = KernProcReady;
  proc.startTime = [NSDate date];
  proc.heapStart = 0x400000;
  proc.heapEnd = 0x400000;
  proc.stackTop = 0x7FFFFFFFE000ULL;
  proc.stackBottom = 0x7FFFFFFFE000ULL - (8 * 1024 * 1024);

  NSMutableArray *processes = self.internalState[@"processes"];
  if (!processes) {
    processes = [NSMutableArray array];
    self.internalState[@"processes"] = processes;
  }
  [processes addObject:proc];

  // Add to run queue
  KernRunQueue *rq = self.internalState[@"runQueue_0"];
  if (!rq) {
    rq = [[KernRunQueue alloc] init];
    rq.cpuID = 0;
    self.internalState[@"runQueue_0"] = rq;
  }
  [rq.normalTasks addObject:proc];
  rq.taskCount++;

  // Link parent
  if (ppid > 0) {
    KernProcess *parent = [self processForPID:ppid];
    if (parent) {
      proc.parent = parent;
      [parent.children addObject:proc];
    }
  }

  [self
      kernelLog:KernLogInfo
       facility:KernLogProcess
        message:[NSString
                    stringWithFormat:@"Process created: PID=%u name=%@ ppid=%u",
                                     proc.pid, name, ppid]];

  return proc;
}

- (void)terminateProcess:(uint32_t)pid exitCode:(int32_t)code {
  KernProcess *proc = [self processForPID:pid];
  if (!proc)
    return;

  proc.state = KernProcZombie;
  proc.exitCode = code;
  proc.endTime = [NSDate date];

  // Re-parent children to init (PID 1)
  for (KernProcess *child in proc.children) {
    child.ppid = 1;
    child.parent = [self processForPID:1];
  }

  // Remove from run queue
  KernRunQueue *rq = self.internalState[@"runQueue_0"];
  [rq.normalTasks removeObject:proc];
  [rq.realtimeTasks removeObject:proc];
  [rq.idleTasks removeObject:proc];
  rq.taskCount =
      rq.normalTasks.count + rq.realtimeTasks.count + rq.idleTasks.count;

  // Signal parent
  if (proc.parent) {
    [self sendSignal:KernSIGCHLD toProcess:proc.ppid];
  }

  [self
      kernelLog:KernLogInfo
       facility:KernLogProcess
        message:[NSString
                    stringWithFormat:@"Process terminated: PID=%u exit_code=%d",
                                     pid, code]];
}

- (void)killProcess:(uint32_t)pid signal:(KernSignal)signal {
  [self sendSignal:signal toProcess:pid];
  if (signal == KernSIGKILL || signal == KernSIGTERM) {
    [self terminateProcess:pid exitCode:128 + (int32_t)signal];
  }
}

- (void)schedule {
  KernRunQueue *rq = self.internalState[@"runQueue_0"];
  if (!rq)
    return;

  rq.clockTicks++;

  // Priority 1: Real-time FIFO/RR tasks
  for (KernProcess *proc in rq.realtimeTasks) {
    if (proc.state == KernProcReady) {
      if (rq.currentTask != proc) {
        KernProcess *old = rq.currentTask;
        [self contextSwitch:old to:proc];
        rq.currentTask = proc;
      }
      return;
    }
  }

  // Priority 2: CFS for normal tasks — pick lowest vruntime
  KernProcess *next = nil;
  uint64_t minVruntime = UINT64_MAX;

  for (KernProcess *proc in rq.normalTasks) {
    if (proc.state == KernProcReady || proc.state == KernProcRunning) {
      // Weight based on nice value: weight = 1024 / (1.25^nice)
      double weight = 1024.0;
      if (proc.niceness != 0) {
        weight = 1024.0 / pow(1.25, proc.niceness);
      }

      // Virtual runtime = actual_runtime * (NICE_0_WEIGHT / weight)
      uint64_t effectiveVruntime = proc.virtualRuntime;
      if (weight > 0) {
        effectiveVruntime = (uint64_t)(proc.virtualRuntime * (1024.0 / weight));
      }

      if (effectiveVruntime < minVruntime) {
        minVruntime = effectiveVruntime;
        next = proc;
      }
    }
  }

  if (next && next != rq.currentTask) {
    KernProcess *old = rq.currentTask;
    [self contextSwitch:old to:next];
    rq.currentTask = next;
  }

  // Update vruntime for current task
  if (rq.currentTask) {
    rq.currentTask.virtualRuntime += 1000000; // 1ms time slice in ns
    rq.currentTask.cpuTimeTotal += 1000000;
  }

  // Update load averages (exponential weighted moving average)
  uint64_t activeCount = 0;
  for (KernProcess *p in rq.normalTasks) {
    if (p.state == KernProcRunning || p.state == KernProcReady)
      activeCount++;
  }
  rq.loadAverage1 = (rq.loadAverage1 * 95 + activeCount * 100 * 5) / 100;
  rq.loadAverage5 = (rq.loadAverage5 * 99 + activeCount * 100 * 1) / 100;
  rq.loadAverage15 = (rq.loadAverage15 * 997 + activeCount * 1000 * 3) / 1000;
}

- (void)contextSwitch:(KernProcess *)from to:(KernProcess *)to {
  if (from) {
    from.state = KernProcReady;
    from.contextSwitches++;
  }
  if (to) {
    to.state = KernProcRunning;
    to.contextSwitches++;
  }

  KernRunQueue *rq = self.internalState[@"runQueue_0"];
  rq.contextSwitchCount++;
}

- (void)setSchedulingPolicy:(KernSchedulingPolicy)policy
                 forProcess:(uint32_t)pid {
  KernProcess *proc = [self processForPID:pid];
  if (!proc)
    return;
  proc.schedPolicy = policy;

  KernRunQueue *rq = self.internalState[@"runQueue_0"];
  [rq.normalTasks removeObject:proc];
  [rq.realtimeTasks removeObject:proc];
  [rq.idleTasks removeObject:proc];

  switch (policy) {
  case KernSchedFIFO:
  case KernSchedRoundRobin:
  case KernSchedDeadline:
    [rq.realtimeTasks addObject:proc];
    break;
  case KernSchedIdle:
    [rq.idleTasks addObject:proc];
    break;
  default:
    [rq.normalTasks addObject:proc];
    break;
  }
}

- (void)setNiceness:(int32_t)nice forProcess:(uint32_t)pid {
  KernProcess *proc = [self processForPID:pid];
  if (proc) {
    proc.niceness = MAX(-20, MIN(19, nice));
  }
}

- (void)setCPUAffinity:(uint32_t)mask forProcess:(uint32_t)pid {
  KernProcess *proc = [self processForPID:pid];
  if (proc)
    proc.cpuAffinity = mask;
}

- (KernProcess *)processForPID:(uint32_t)pid {
  NSArray *processes = self.internalState[@"processes"];
  for (KernProcess *proc in processes) {
    if (proc.pid == pid)
      return proc;
  }
  return nil;
}

- (NSArray<KernProcess *> *)allProcesses {
  return [self.internalState[@"processes"] copy] ?: @[];
}

- (NSArray<KernProcess *> *)processesForUser:(uint32_t)uid {
  NSMutableArray *result = [NSMutableArray array];
  for (KernProcess *proc in self.internalState[@"processes"]) {
    if (proc.uid == uid)
      [result addObject:proc];
  }
  return result;
}

- (void)sendSignal:(KernSignal)signal toProcess:(uint32_t)pid {
  KernProcess *proc = [self processForPID:pid];
  if (!proc)
    return;

  if (proc.blockedSignals & (1ULL << signal))
    return;
  proc.pendingSignals |= (1ULL << signal);

  if (proc.state == KernProcSleeping || proc.state == KernProcBlocked) {
    proc.state = KernProcReady;
  }

  [self kernelLog:KernLogDebug
         facility:KernLogProcess
          message:[NSString stringWithFormat:@"Signal %ld sent to PID %u",
                                             (long)signal, pid]];
}

// --- IPC: Pipes ---

- (KernPipe *)createPipe {
  static uint32_t nextPipeID = 1;
  KernPipe *pipe = [[KernPipe alloc] init];
  pipe.pipeID = nextPipeID++;
  pipe.readFD = nextPipeID * 2;
  pipe.writeFD = nextPipeID * 2 + 1;

  NSMutableArray *pipes = self.internalState[@"pipes"];
  if (!pipes) {
    pipes = [NSMutableArray array];
    self.internalState[@"pipes"] = pipes;
  }
  [pipes addObject:pipe];
  return pipe;
}

- (KernPipe *)createNamedPipe:(NSString *)name {
  KernPipe *pipe = [self createPipe];
  pipe.name = name;
  return pipe;
}

- (NSInteger)pipeWrite:(KernPipe *)pipe data:(NSData *)data {
  if (!pipe || pipe.writerClosed || !data)
    return -1;
  if (pipe.bufferSize + data.length > pipe.maxBufferSize)
    return -1;
  [pipe.buffer appendData:data];
  pipe.bufferSize += data.length;
  pipe.writePosition += data.length;
  return data.length;
}

- (NSData *)pipeRead:(KernPipe *)pipe length:(NSUInteger)length {
  if (!pipe || pipe.readerClosed)
    return nil;
  if (pipe.bufferSize == 0)
    return [NSData data];
  NSUInteger readLen = MIN(length, pipe.bufferSize);
  NSData *result = [pipe.buffer subdataWithRange:NSMakeRange(0, readLen)];
  NSUInteger remaining = pipe.buffer.length - readLen;
  if (remaining > 0) {
    NSData *rest =
        [pipe.buffer subdataWithRange:NSMakeRange(readLen, remaining)];
    pipe.buffer = [rest mutableCopy];
  } else {
    pipe.buffer = [NSMutableData data];
  }
  pipe.bufferSize -= readLen;
  pipe.readPosition += readLen;
  return result;
}

- (void)closePipe:(KernPipe *)pipe {
  if (!pipe)
    return;
  pipe.readerClosed = YES;
  pipe.writerClosed = YES;
  NSMutableArray *pipes = self.internalState[@"pipes"];
  [pipes removeObject:pipe];
}

// --- IPC: Message Queues ---

- (KernMessageQueue *)createMessageQueue:(NSString *)name
                             maxMessages:(NSUInteger)max
                                 maxSize:(NSUInteger)size {
  static uint32_t nextQID = 1;
  KernMessageQueue *queue = [[KernMessageQueue alloc] init];
  queue.queueID = nextQID++;
  queue.name = name;
  queue.maxMessages = max;
  queue.maxMessageSize = size;

  NSMutableArray *queues = self.internalState[@"messageQueues"];
  if (!queues) {
    queues = [NSMutableArray array];
    self.internalState[@"messageQueues"] = queues;
  }
  [queues addObject:queue];
  return queue;
}

- (BOOL)sendMessage:(KernMessageQueueMessage *)msg
            toQueue:(KernMessageQueue *)queue {
  if (!msg || !queue)
    return NO;
  if (queue.messages.count >= queue.maxMessages)
    return NO;
  if (msg.data.length > queue.maxMessageSize)
    return NO;
  msg.timestamp = mach_absolute_time();
  [queue.messages addObject:msg];
  queue.currentSize += msg.data.length;
  queue.sendCount++;
  return YES;
}

- (KernMessageQueueMessage *)receiveMessageFromQueue:(KernMessageQueue *)queue
                                                type:(uint64_t)type {
  if (!queue || queue.messages.count == 0)
    return nil;
  KernMessageQueueMessage *found = nil;
  if (type == 0) {
    found = queue.messages.firstObject;
  } else {
    for (KernMessageQueueMessage *msg in queue.messages) {
      if (msg.type == type) {
        found = msg;
        break;
      }
    }
  }
  if (found) {
    [queue.messages removeObject:found];
    queue.currentSize -= found.data.length;
    queue.receiveCount++;
  }
  return found;
}

- (void)destroyMessageQueue:(KernMessageQueue *)queue {
  NSMutableArray *queues = self.internalState[@"messageQueues"];
  [queues removeObject:queue];
}

// --- IPC: Shared Memory ---

- (KernSharedMemory *)createSharedMemory:(NSString *)name
                                    size:(NSUInteger)size {
  static uint32_t nextShmID = 1;
  KernSharedMemory *shm = [[KernSharedMemory alloc] init];
  shm.shmID = nextShmID++;
  shm.name = name;
  shm.size = size;
  shm.data = [NSMutableData dataWithLength:size];
  shm.createTime = mach_absolute_time();

  NSMutableArray *shmList = self.internalState[@"sharedMemory"];
  if (!shmList) {
    shmList = [NSMutableArray array];
    self.internalState[@"sharedMemory"] = shmList;
  }
  [shmList addObject:shm];
  return shm;
}

- (void *)attachSharedMemory:(KernSharedMemory *)shm forProcess:(uint32_t)pid {
  if (!shm)
    return NULL;
  [shm.attachedProcesses addObject:@(pid)];
  shm.attachCount++;
  shm.lastAttachTime = mach_absolute_time();
  return shm.data.mutableBytes;
}

- (void)detachSharedMemory:(KernSharedMemory *)shm fromProcess:(uint32_t)pid {
  if (!shm)
    return;
  [shm.attachedProcesses removeObject:@(pid)];
  shm.lastDetachTime = mach_absolute_time();
  if (shm.attachedProcesses.count == 0 && shm.markedForDeletion) {
    [self destroySharedMemory:shm];
  }
}

- (void)destroySharedMemory:(KernSharedMemory *)shm {
  NSMutableArray *shmList = self.internalState[@"sharedMemory"];
  [shmList removeObject:shm];
}

// --- IPC: Semaphores ---

- (KernSemaphore *)createSemaphore:(NSString *)name
                      initialValue:(int32_t)value {
  static uint32_t nextSemID = 1;
  KernSemaphore *sem = [[KernSemaphore alloc] init];
  sem.semID = nextSemID++;
  sem.name = name;
  sem.value = value;
  sem.initialValue = value;

  NSMutableArray *sems = self.internalState[@"semaphores"];
  if (!sems) {
    sems = [NSMutableArray array];
    self.internalState[@"semaphores"] = sems;
  }
  [sems addObject:sem];
  return sem;
}

- (BOOL)semaphoreWait:(KernSemaphore *)sem {
  if (!sem)
    return NO;
  sem.waitCount++;
  if (sem.value > 0) {
    sem.value--;
    return YES;
  }
  return NO; // Would block
}

- (BOOL)semaphoreTryWait:(KernSemaphore *)sem {
  if (!sem || sem.value <= 0)
    return NO;
  sem.value--;
  return YES;
}

- (void)semaphorePost:(KernSemaphore *)sem {
  if (!sem)
    return;
  sem.value++;
  sem.postCount++;
}

- (void)destroySemaphore:(KernSemaphore *)sem {
  NSMutableArray *sems = self.internalState[@"semaphores"];
  [sems removeObject:sem];
}

// --- Threading ---

- (KernThread *)createThread:(uint32_t)processID
                        name:(NSString *)name
                    priority:(int32_t)priority
                   stackSize:(uint64_t)stackSize {
  static uint32_t nextTID = 1;
  KernThread *thread = [[KernThread alloc] init];
  thread.threadID = nextTID++;
  thread.processID = processID;
  thread.name = name;
  thread.priority = priority;
  thread.stackSize = stackSize > 0 ? stackSize : 8 * 1024 * 1024;
  thread.state = KernThreadReady;

  KernProcess *proc = [self processForPID:processID];
  if (proc)
    [proc.threads addObject:(KernProcess *)thread]; // stored in threads array

  NSMutableArray *threads = self.internalState[@"threads"];
  if (!threads) {
    threads = [NSMutableArray array];
    self.internalState[@"threads"] = threads;
  }
  [threads addObject:thread];

  return thread;
}

- (void)terminateThread:(uint32_t)threadID exitCode:(int32_t)code {
  NSArray *threads = self.internalState[@"threads"];
  for (KernThread *t in threads) {
    if (t.threadID == threadID) {
      t.state = KernThreadTerminated;
      t.exitCode = code;
      break;
    }
  }
}

- (void)joinThread:
    (uint32_t)threadID { /* blocks calling thread until target completes */
}
- (void)detachThread:(uint32_t)threadID {
  NSArray *threads = self.internalState[@"threads"];
  for (KernThread *t in threads) {
    if (t.threadID == threadID) {
      t.isDetached = YES;
      break;
    }
  }
}
- (void)sleepThread:(uint64_t)nanoseconds { /* sleep */
}

// --- Mutex ---

- (KernMutex *)createMutex:(NSString *)name type:(KernMutexType)type {
  static uint32_t nextMID = 1;
  KernMutex *mtx = [[KernMutex alloc] init];
  mtx.mutexID = nextMID++;
  mtx.name = name;
  mtx.type = type;
  return mtx;
}

- (BOOL)mutexLock:(KernMutex *)mutex {
  if (!mutex)
    return NO;
  if (!mutex.locked) {
    mutex.locked = YES;
    mutex.lockCount++;
    mutex.recursionCount = 1;
    return YES;
  }
  if (mutex.type == KernMutexRecursive) {
    mutex.recursionCount++;
    mutex.lockCount++;
    return YES;
  }
  mutex.contentionCount++;
  return NO; // Would block
}

- (BOOL)mutexTryLock:(KernMutex *)mutex {
  if (!mutex || mutex.locked)
    return NO;
  mutex.locked = YES;
  mutex.lockCount++;
  mutex.recursionCount = 1;
  return YES;
}

- (void)mutexUnlock:(KernMutex *)mutex {
  if (!mutex)
    return;
  if (mutex.type == KernMutexRecursive && mutex.recursionCount > 1) {
    mutex.recursionCount--;
    return;
  }
  mutex.locked = NO;
  mutex.ownerThreadID = 0;
  mutex.recursionCount = 0;
}

- (void)destroyMutex:(KernMutex *)mutex { /* cleanup */
}

// --- RWLock ---

- (KernRWLock *)createRWLock:(NSString *)name {
  static uint32_t nextRWID = 1;
  KernRWLock *lock = [[KernRWLock alloc] init];
  lock.rwlockID = nextRWID++;
  lock.name = name;
  return lock;
}

- (BOOL)rwlockReadLock:(KernRWLock *)lock {
  if (!lock)
    return NO;
  if (lock.state == KernRWLockWriteLocked)
    return NO;
  lock.state = KernRWLockReadLocked;
  lock.readerCount++;
  return YES;
}

- (BOOL)rwlockWriteLock:(KernRWLock *)lock {
  if (!lock || lock.state != KernRWLockFree)
    return NO;
  lock.state = KernRWLockWriteLocked;
  return YES;
}

- (void)rwlockUnlock:(KernRWLock *)lock {
  if (!lock)
    return;
  if (lock.state == KernRWLockReadLocked) {
    lock.readerCount--;
    if (lock.readerCount == 0)
      lock.state = KernRWLockFree;
  } else {
    lock.state = KernRWLockFree;
    lock.writerThreadID = 0;
  }
}

- (void)destroyRWLock:(KernRWLock *)lock { /* cleanup */
}

// --- CondVar ---

- (KernCondVar *)createCondVar:(NSString *)name {
  static uint32_t nextCID = 1;
  KernCondVar *cv = [[KernCondVar alloc] init];
  cv.condID = nextCID++;
  cv.name = name;
  return cv;
}

- (void)condVarWait:(KernCondVar *)cond mutex:(KernMutex *)mutex {
  if (!cond || !mutex)
    return;
  [self mutexUnlock:mutex];
  // Thread would block here
  [self mutexLock:mutex];
}

- (BOOL)condVarTimedWait:(KernCondVar *)cond
                   mutex:(KernMutex *)mutex
               timeoutNs:(uint64_t)timeout {
  [self condVarWait:cond mutex:mutex];
  return YES;
}

- (void)condVarSignal:(KernCondVar *)cond {
  if (cond)
    cond.signalCount++;
}

- (void)condVarBroadcast:(KernCondVar *)cond {
  if (cond)
    cond.broadcastCount++;
}

- (void)destroyCondVar:(KernCondVar *)cond { /* cleanup */
}

// --- Barrier ---

- (KernBarrier *)createBarrier:(uint32_t)count {
  static uint32_t nextBID = 1;
  KernBarrier *bar = [[KernBarrier alloc] init];
  bar.barrierID = nextBID++;
  bar.threshold = count;
  return bar;
}

- (void)barrierWait:(KernBarrier *)barrier {
  if (!barrier)
    return;
  barrier.currentCount++;
  if (barrier.currentCount >= barrier.threshold) {
    barrier.currentCount = 0;
    barrier.generation++;
  }
}

- (void)destroyBarrier:(KernBarrier *)barrier { /* cleanup */
}

@end
