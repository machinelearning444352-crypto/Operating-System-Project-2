#import "AdvancedKernel.h"
#include <mach/mach_time.h>

// Private interface visible to all kernel category files
@interface AdvancedKernel ()
@property(nonatomic, strong) NSMutableDictionary *internalState;
@property(nonatomic, strong) NSMutableArray<KernLogEntry *> *logBuffer;
@property(nonatomic, assign) uint64_t logSequence;
@property(nonatomic, assign) uint64_t bootTime;
@property(nonatomic, assign) uint64_t syscallCount;
@end

// ============================================================================
// ADVANCED KERNEL — Virtual Memory Implementation
// ============================================================================

@implementation KernPageTableEntry
- (instancetype)init {
  self = [super init];
  if (self) {
    _physicalAddress = 0;
    _virtualAddress = 0;
    _flags = 0;
    _state = KernPageFree;
    _protection = KernMemProtRead;
    _referenceCount = 0;
    _lastAccessTime = 0;
    _present = NO;
    _dirty = NO;
    _accessed = NO;
    _swapped = NO;
    _swapOffset = 0;
  }
  return self;
}
@end

@implementation KernTLBEntry
- (instancetype)init {
  self = [super init];
  if (self) {
    _virtualPage = 0;
    _physicalFrame = 0;
    _protection = KernMemProtRead;
    _lastUsed = 0;
    _valid = NO;
    _global = NO;
    _asid = 0;
  }
  return self;
}
@end

@implementation KernVMA
- (instancetype)init {
  self = [super init];
  if (self) {
    _startAddress = 0;
    _endAddress = 0;
    _size = 0;
    _protection = KernMemProtRead;
    _flags = 0;
    _name = @"";
    _fileOffset = 0;
    _mappedFile = nil;
    _isAnonymous = YES;
    _isStack = NO;
    _isHeap = NO;
    _processID = 0;
  }
  return self;
}
@end

@implementation KernSlabCache
- (instancetype)initWithName:(NSString *)name
                  objectSize:(NSUInteger)size
                   alignment:(NSUInteger)align {
  self = [super init];
  if (self) {
    _name = name;
    _objectSize = size;
    _alignment = align;
    _objectsPerSlab = (KERN_PAGE_SIZE - sizeof(void *) * 2) / size;
    if (_objectsPerSlab == 0)
      _objectsPerSlab = 1;
    _totalSlabs = 0;
    _activeObjects = 0;
    _freeObjects = 0;
    _slabs = [NSMutableArray array];
    _freeList = [NSMutableArray array];
    _totalAllocations = 0;
    _totalFrees = 0;
    _cacheHits = 0;
    _cacheMisses = 0;
  }
  return self;
}

- (instancetype)init {
  return [self initWithName:@"default" objectSize:64 alignment:8];
}
@end

@implementation KernBuddyBlock
- (instancetype)init {
  self = [super init];
  if (self) {
    _baseAddress = 0;
    _order = 0;
    _isFree = YES;
    _zone = KernMemZoneNormal;
  }
  return self;
}
@end

// ============================================================================
// AdvancedKernel — Virtual Memory Methods
// ============================================================================

@implementation AdvancedKernel (Memory)

- (void)initializeVirtualMemory {
  [self kernelLog:KernLogInfo
         facility:KernLogMemory
          message:@"Initializing virtual memory subsystem"];

  // Initialize page frame allocator
  uint64_t totalPhys = [self totalPhysicalMemory];
  uint64_t totalPages = totalPhys / KERN_PAGE_SIZE;

  NSMutableArray *pageFrameArray =
      [NSMutableArray arrayWithCapacity:totalPages];
  for (uint64_t i = 0; i < MIN(totalPages, 1048576ULL); i++) {
    KernPageTableEntry *pte = [[KernPageTableEntry alloc] init];
    pte.physicalAddress = i * KERN_PAGE_SIZE;
    pte.state = KernPageFree;
    [pageFrameArray addObject:pte];
  }

  [self.internalState setObject:pageFrameArray forKey:@"pageFrames"];
  [self.internalState setObject:@(0) forKey:@"allocatedPages"];
  [self.internalState setObject:@(pageFrameArray.count) forKey:@"freePages"];

  // Initialize TLB
  NSMutableArray *tlb = [NSMutableArray arrayWithCapacity:4096];
  for (int i = 0; i < 4096; i++) {
    KernTLBEntry *entry = [[KernTLBEntry alloc] init];
    entry.valid = NO;
    [tlb addObject:entry];
  }
  [self.internalState setObject:tlb forKey:@"tlb"];

  // Initialize buddy allocator free lists (orders 0-10, for 4KB to 4MB)
  NSMutableDictionary *buddyFreeList = [NSMutableDictionary dictionary];
  for (int order = 0; order <= 10; order++) {
    buddyFreeList[@(order)] = [NSMutableArray array];
  }
  [self.internalState setObject:buddyFreeList forKey:@"buddyFreeList"];

  // Populate initial buddy blocks at max order
  NSMutableArray *maxOrderList = buddyFreeList[@(10)];
  uint64_t blocksAtMaxOrder = MIN(totalPages, 1048576ULL) / (1 << 10);
  for (uint64_t i = 0; i < blocksAtMaxOrder; i++) {
    KernBuddyBlock *block = [[KernBuddyBlock alloc] init];
    block.baseAddress = i * (1 << 10) * KERN_PAGE_SIZE;
    block.order = 10;
    block.isFree = YES;
    block.zone = KernMemZoneNormal;
    [maxOrderList addObject:block];
  }

  // Initialize slab caches for common kernel objects
  NSMutableDictionary *slabCaches = [NSMutableDictionary dictionary];
  NSArray *sizes =
      @[ @(32), @(64), @(128), @(256), @(512), @(1024), @(2048), @(4096) ];
  for (NSNumber *size in sizes) {
    NSString *name = [NSString stringWithFormat:@"kmalloc-%@", size];
    KernSlabCache *cache =
        [[KernSlabCache alloc] initWithName:name
                                 objectSize:size.unsignedIntegerValue
                                  alignment:8];
    slabCaches[name] = cache;
  }
  [self.internalState setObject:slabCaches forKey:@"slabCaches"];

  [self kernelLog:KernLogInfo
         facility:KernLogMemory
          message:[NSString
                      stringWithFormat:@"Virtual memory initialized: %llu "
                                       @"pages, %llu MB total",
                                       (unsigned long long)pageFrameArray.count,
                                       (unsigned long long)(totalPhys /
                                                            1048576)]];
}

- (KernPageTableEntry *)allocatePage {
  NSMutableArray *pageFrames = self.internalState[@"pageFrames"];
  for (KernPageTableEntry *pte in pageFrames) {
    if (pte.state == KernPageFree) {
      pte.state = KernPageAllocated;
      pte.present = YES;
      pte.referenceCount = 1;
      pte.lastAccessTime = mach_absolute_time();

      NSUInteger allocated =
          [self.internalState[@"allocatedPages"] unsignedIntegerValue] + 1;
      NSUInteger free =
          [self.internalState[@"freePages"] unsignedIntegerValue] - 1;
      [self.internalState setObject:@(allocated) forKey:@"allocatedPages"];
      [self.internalState setObject:@(free) forKey:@"freePages"];
      return pte;
    }
  }
  [self kernelLog:KernLogError
         facility:KernLogMemory
          message:@"Out of memory: no free pages"];
  return nil;
}

- (void)freePage:(KernPageTableEntry *)page {
  if (!page)
    return;
  page.state = KernPageFree;
  page.present = NO;
  page.dirty = NO;
  page.accessed = NO;
  page.referenceCount = 0;
  page.flags = 0;

  NSUInteger allocated =
      [self.internalState[@"allocatedPages"] unsignedIntegerValue] - 1;
  NSUInteger free = [self.internalState[@"freePages"] unsignedIntegerValue] + 1;
  [self.internalState setObject:@(allocated) forKey:@"allocatedPages"];
  [self.internalState setObject:@(free) forKey:@"freePages"];
}

- (uint64_t)mapVirtualAddress:(uint64_t)virtualAddr
                   toPhysical:(uint64_t)physAddr
                   protection:(KernMemoryProtection)prot
                   forProcess:(uint32_t)pid {
  NSString *key = [NSString stringWithFormat:@"pageTable_%u", pid];
  NSMutableDictionary *pageTable = self.internalState[key];
  if (!pageTable) {
    pageTable = [NSMutableDictionary dictionary];
    self.internalState[key] = pageTable;
  }

  uint64_t pageNum = virtualAddr / KERN_PAGE_SIZE;
  KernPageTableEntry *pte = [[KernPageTableEntry alloc] init];
  pte.virtualAddress = virtualAddr;
  pte.physicalAddress = physAddr;
  pte.protection = prot;
  pte.present = YES;
  pte.state = KernPageMapped;
  pte.flags = PTE_PRESENT;
  if (prot & KernMemProtWrite)
    pte.flags |= PTE_WRITABLE;
  if (prot & KernMemProtUser)
    pte.flags |= PTE_USER;
  if (!(prot & KernMemProtExec))
    pte.flags |= PTE_NO_EXECUTE;

  pageTable[@(pageNum)] = pte;

  // Update TLB
  NSMutableArray *tlb = self.internalState[@"tlb"];
  NSUInteger tlbIndex = pageNum % tlb.count;
  KernTLBEntry *tlbEntry = tlb[tlbIndex];
  tlbEntry.virtualPage = pageNum;
  tlbEntry.physicalFrame = physAddr / KERN_PAGE_SIZE;
  tlbEntry.protection = prot;
  tlbEntry.valid = YES;
  tlbEntry.lastUsed = mach_absolute_time();
  tlbEntry.asid = pid;

  return physAddr;
}

- (void)unmapVirtualAddress:(uint64_t)virtualAddr forProcess:(uint32_t)pid {
  NSString *key = [NSString stringWithFormat:@"pageTable_%u", pid];
  NSMutableDictionary *pageTable = self.internalState[key];
  if (!pageTable)
    return;

  uint64_t pageNum = virtualAddr / KERN_PAGE_SIZE;
  KernPageTableEntry *pte = pageTable[@(pageNum)];
  if (pte) {
    pte.state = KernPageFree;
    pte.present = NO;
    [pageTable removeObjectForKey:@(pageNum)];
  }

  [self flushTLBEntry:virtualAddr];
}

- (KernPageTableEntry *)translateAddress:(uint64_t)virtualAddr
                              forProcess:(uint32_t)pid {
  // Check TLB first
  NSMutableArray *tlb = self.internalState[@"tlb"];
  uint64_t pageNum = virtualAddr / KERN_PAGE_SIZE;
  NSUInteger tlbIndex = pageNum % tlb.count;
  KernTLBEntry *tlbEntry = tlb[tlbIndex];

  if (tlbEntry.valid && tlbEntry.virtualPage == pageNum &&
      tlbEntry.asid == pid) {
    tlbEntry.lastUsed = mach_absolute_time();
    // TLB hit — construct PTE from TLB
    KernPageTableEntry *pte = [[KernPageTableEntry alloc] init];
    pte.virtualAddress = virtualAddr;
    pte.physicalAddress = tlbEntry.physicalFrame * KERN_PAGE_SIZE +
                          (virtualAddr % KERN_PAGE_SIZE);
    pte.protection = tlbEntry.protection;
    pte.present = YES;
    return pte;
  }

  // TLB miss — walk page table
  NSString *key = [NSString stringWithFormat:@"pageTable_%u", pid];
  NSMutableDictionary *pageTable = self.internalState[key];
  if (!pageTable)
    return nil;

  return pageTable[@(pageNum)];
}

- (void)handlePageFault:(uint64_t)address
                 reason:(KernPageFaultReason)reason
             forProcess:(uint32_t)pid {
  KernProcess *proc = [self processForPID:pid];
  if (proc) {
    proc.pageFaults++;
  }

  NSString *reasonStr;
  switch (reason) {
  case KernPageFaultNotPresent:
    reasonStr = @"page not present";
    break;
  case KernPageFaultProtection:
    reasonStr = @"protection violation";
    break;
  case KernPageFaultWriteAccess:
    reasonStr = @"write to read-only page";
    break;
  case KernPageFaultCopyOnWrite:
    reasonStr = @"copy-on-write";
    break;
  case KernPageFaultSwapIn:
    reasonStr = @"swap-in needed";
    break;
  case KernPageFaultDemandZero:
    reasonStr = @"demand zero page";
    break;
  case KernPageFaultStackGrowth:
    reasonStr = @"stack growth";
    break;
  default:
    reasonStr = @"unknown";
    break;
  }

  [self kernelLog:KernLogDebug
         facility:KernLogMemory
          message:[NSString
                      stringWithFormat:@"Page fault at 0x%llx (%@) for PID %u",
                                       (unsigned long long)address, reasonStr,
                                       pid]];

  switch (reason) {
  case KernPageFaultDemandZero:
  case KernPageFaultNotPresent: {
    KernPageTableEntry *newPage = [self allocatePage];
    if (newPage) {
      [self mapVirtualAddress:address
                   toPhysical:newPage.physicalAddress
                   protection:KernMemProtRead | KernMemProtWrite
                   forProcess:pid];
      if (proc)
        proc.minorFaults++;
    } else {
      [self kernelLog:KernLogError
             facility:KernLogMemory
              message:@"OOM: Cannot satisfy page fault"];
      [self sendSignal:KernSIGSEGV toProcess:pid];
    }
    break;
  }
  case KernPageFaultCopyOnWrite: {
    KernPageTableEntry *oldPage = [self translateAddress:address
                                              forProcess:pid];
    KernPageTableEntry *newPage = [self allocatePage];
    if (oldPage && newPage) {
      [self mapVirtualAddress:address
                   toPhysical:newPage.physicalAddress
                   protection:KernMemProtRead | KernMemProtWrite
                   forProcess:pid];
      if (proc)
        proc.minorFaults++;
    }
    break;
  }
  case KernPageFaultStackGrowth: {
    if (proc) {
      uint64_t newStackBottom = proc.stackBottom - KERN_PAGE_SIZE;
      KernPageTableEntry *stackPage = [self allocatePage];
      if (stackPage) {
        [self mapVirtualAddress:newStackBottom
                     toPhysical:stackPage.physicalAddress
                     protection:KernMemProtRead | KernMemProtWrite
                     forProcess:pid];
        proc.stackBottom = newStackBottom;
      }
    }
    break;
  }
  case KernPageFaultProtection:
  case KernPageFaultWriteAccess:
    [self sendSignal:KernSIGSEGV toProcess:pid];
    break;
  default:
    break;
  }
}

- (void)flushTLB {
  NSMutableArray *tlb = self.internalState[@"tlb"];
  for (KernTLBEntry *entry in tlb) {
    entry.valid = NO;
  }
  [self kernelLog:KernLogDebug facility:KernLogMemory message:@"TLB flushed"];
}

- (void)flushTLBEntry:(uint64_t)virtualAddr {
  NSMutableArray *tlb = self.internalState[@"tlb"];
  uint64_t pageNum = virtualAddr / KERN_PAGE_SIZE;
  NSUInteger tlbIndex = pageNum % tlb.count;
  KernTLBEntry *entry = tlb[tlbIndex];
  if (entry.virtualPage == pageNum) {
    entry.valid = NO;
  }
}

- (KernVMA *)mmapForProcess:(uint32_t)pid
                    address:(uint64_t)addr
                     length:(uint64_t)len
                 protection:(KernMemoryProtection)prot
                      flags:(KernMmapFlags)flags {
  KernProcess *proc = [self processForPID:pid];
  if (!proc)
    return nil;

  KernVMA *vma = [[KernVMA alloc] init];
  vma.startAddress = addr;
  vma.endAddress = addr + len;
  vma.size = len;
  vma.protection = prot;
  vma.flags = flags;
  vma.processID = pid;
  vma.isAnonymous = (flags & KernMmapAnonymous) != 0;

  if (!proc.memoryMaps) {
    proc.memoryMaps = [NSMutableArray array];
  }
  [proc.memoryMaps addObject:vma];

  // Allocate pages for non-lazy mappings
  if (flags & KernMmapPopulate) {
    uint64_t numPages = (len + KERN_PAGE_SIZE - 1) / KERN_PAGE_SIZE;
    for (uint64_t i = 0; i < numPages; i++) {
      KernPageTableEntry *page = [self allocatePage];
      if (page) {
        [self mapVirtualAddress:addr + i * KERN_PAGE_SIZE
                     toPhysical:page.physicalAddress
                     protection:prot
                     forProcess:pid];
      }
    }
  }

  [self kernelLog:KernLogDebug
         facility:KernLogMemory
          message:[NSString
                      stringWithFormat:
                          @"mmap: PID %u, addr=0x%llx, len=%llu, prot=0x%lx",
                          pid, (unsigned long long)addr,
                          (unsigned long long)len, (unsigned long)prot]];

  return vma;
}

- (BOOL)munmapForProcess:(uint32_t)pid
                 address:(uint64_t)addr
                  length:(uint64_t)len {
  KernProcess *proc = [self processForPID:pid];
  if (!proc)
    return NO;

  uint64_t numPages = (len + KERN_PAGE_SIZE - 1) / KERN_PAGE_SIZE;
  for (uint64_t i = 0; i < numPages; i++) {
    [self unmapVirtualAddress:addr + i * KERN_PAGE_SIZE forProcess:pid];
  }

  NSMutableArray *toRemove = [NSMutableArray array];
  for (KernVMA *vma in proc.memoryMaps) {
    if (vma.startAddress >= addr && vma.endAddress <= addr + len) {
      [toRemove addObject:vma];
    }
  }
  [proc.memoryMaps removeObjectsInArray:toRemove];

  return YES;
}

- (BOOL)mprotectForProcess:(uint32_t)pid
                   address:(uint64_t)addr
                    length:(uint64_t)len
                protection:(KernMemoryProtection)prot {
  NSString *key = [NSString stringWithFormat:@"pageTable_%u", pid];
  NSMutableDictionary *pageTable = self.internalState[key];
  if (!pageTable)
    return NO;

  uint64_t numPages = (len + KERN_PAGE_SIZE - 1) / KERN_PAGE_SIZE;
  for (uint64_t i = 0; i < numPages; i++) {
    uint64_t pageNum = (addr + i * KERN_PAGE_SIZE) / KERN_PAGE_SIZE;
    KernPageTableEntry *pte = pageTable[@(pageNum)];
    if (pte) {
      pte.protection = prot;
      pte.flags &= ~(PTE_WRITABLE | PTE_NO_EXECUTE);
      if (prot & KernMemProtWrite)
        pte.flags |= PTE_WRITABLE;
      if (!(prot & KernMemProtExec))
        pte.flags |= PTE_NO_EXECUTE;
    }
  }
  [self flushTLB];
  return YES;
}

- (KernSlabCache *)createSlabCache:(NSString *)name
                        objectSize:(NSUInteger)size
                         alignment:(NSUInteger)align {
  NSMutableDictionary *caches = self.internalState[@"slabCaches"];
  KernSlabCache *cache = [[KernSlabCache alloc] initWithName:name
                                                  objectSize:size
                                                   alignment:align];
  caches[name] = cache;
  [self kernelLog:KernLogDebug
         facility:KernLogMemory
          message:[NSString
                      stringWithFormat:@"Slab cache created: %@ (obj_size=%lu)",
                                       name, (unsigned long)size]];
  return cache;
}

- (void *)slabAlloc:(KernSlabCache *)cache {
  if (!cache)
    return NULL;
  cache.totalAllocations++;

  if (cache.freeList.count > 0) {
    cache.cacheHits++;
    NSValue *val = cache.freeList.lastObject;
    [cache.freeList removeLastObject];
    cache.activeObjects++;
    cache.freeObjects--;
    return val.pointerValue;
  }

  cache.cacheMisses++;
  void *obj = calloc(1, cache.objectSize);
  if (obj) {
    cache.activeObjects++;
  }
  return obj;
}

- (void)slabFree:(KernSlabCache *)cache object:(void *)obj {
  if (!cache || !obj)
    return;
  cache.totalFrees++;
  cache.activeObjects--;
  cache.freeObjects++;
  [cache.freeList addObject:[NSValue valueWithPointer:obj]];
}

- (KernBuddyBlock *)buddyAllocate:(NSUInteger)order zone:(KernMemoryZone)zone {
  NSMutableDictionary *buddyFreeList = self.internalState[@"buddyFreeList"];

  // Find smallest available order >= requested
  for (NSUInteger o = order; o <= 10; o++) {
    NSMutableArray *freeBlocks = buddyFreeList[@(o)];
    if (freeBlocks.count > 0) {
      KernBuddyBlock *block = freeBlocks.lastObject;
      [freeBlocks removeLastObject];

      // Split down to requested order
      while (o > order) {
        o--;
        KernBuddyBlock *buddy = [[KernBuddyBlock alloc] init];
        buddy.baseAddress = block.baseAddress + ((1ULL << o) * KERN_PAGE_SIZE);
        buddy.order = o;
        buddy.isFree = YES;
        buddy.zone = zone;
        [buddyFreeList[@(o)] addObject:buddy];
        block.order = o;
      }

      block.isFree = NO;
      return block;
    }
  }
  return nil;
}

- (void)buddyFree:(KernBuddyBlock *)block {
  if (!block)
    return;
  block.isFree = YES;
  NSMutableDictionary *buddyFreeList = self.internalState[@"buddyFreeList"];
  [buddyFreeList[@(block.order)] addObject:block];
}

- (NSDictionary *)memoryStatistics {
  NSUInteger allocated =
      [self.internalState[@"allocatedPages"] unsignedIntegerValue];
  NSUInteger free = [self.internalState[@"freePages"] unsignedIntegerValue];
  uint64_t total = [self totalPhysicalMemory];

  NSMutableDictionary *slabStats = [NSMutableDictionary dictionary];
  NSDictionary *caches = self.internalState[@"slabCaches"];
  for (NSString *name in caches) {
    KernSlabCache *cache = caches[name];
    slabStats[name] = @{
      @"active_objects" : @(cache.activeObjects),
      @"free_objects" : @(cache.freeObjects),
      @"total_allocations" : @(cache.totalAllocations),
      @"cache_hits" : @(cache.cacheHits),
      @"cache_misses" : @(cache.cacheMisses)
    };
  }

  return @{
    @"total_memory" : @(total),
    @"total_pages" : @(allocated + free),
    @"allocated_pages" : @(allocated),
    @"free_pages" : @(free),
    @"used_memory" : @(allocated * KERN_PAGE_SIZE),
    @"free_memory" : @(free * KERN_PAGE_SIZE),
    @"page_size" : @(KERN_PAGE_SIZE),
    @"slab_caches" : slabStats
  };
}

- (uint64_t)totalPhysicalMemory {
  return [[NSProcessInfo processInfo] physicalMemory];
}

- (uint64_t)availableMemory {
  NSUInteger free = [self.internalState[@"freePages"] unsignedIntegerValue];
  return free * KERN_PAGE_SIZE;
}

- (uint64_t)cachedMemory {
  NSMutableDictionary *caches = self.internalState[@"slabCaches"];
  uint64_t cached = 0;
  for (KernSlabCache *cache in caches.allValues) {
    cached += cache.freeObjects * cache.objectSize;
  }
  return cached;
}

- (uint64_t)swapUsed {
  return 0;
}
- (uint64_t)swapTotal {
  return 0;
}

@end
