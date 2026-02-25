#ifndef KERNEL_H
#define KERNEL_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// Process Management
typedef struct {
  uint32_t pid;
  char name[256];
  uint32_t priority;
  uint32_t state; // 0=ready, 1=running, 2=blocked
  uint64_t cpu_time;
} OSProcess;

// Memory Management
typedef struct {
  uint64_t total_memory;
  uint64_t used_memory;
  uint64_t free_memory;
} OSMemoryInfo;

// Device Management
typedef enum {
  DEVICE_GPU,
  DEVICE_STORAGE,
  DEVICE_NETWORK,
  DEVICE_INPUT
} OSDeviceType;

typedef struct {
  uint32_t device_id;
  OSDeviceType type;
  char name[256];
  bool enabled;
} OSDevice;

// Function declarations
void kernel_init(void);
void kernel_run(void);
uint32_t process_create(const char *name, void (*entry_point)(void));
void process_destroy(uint32_t pid);
OSMemoryInfo *get_memory_info(void);
void schedule_process(void);

#endif // KERNEL_H
