// Utility functions and data structures
#ifndef UTILS_H
#define UTILS_H

#include <stdint.h>
#include <stddef.h>
#include <limits.h>

// Logging macros
#define LOG_ERROR(fmt, ...) log_message(LOG_ERROR_LEVEL, __FILE__, __LINE__, fmt, ##__VA_ARGS__)
#define LOG_WARN(fmt, ...) log_message(LOG_WARN_LEVEL, __FILE__, __LINE__, fmt, ##__VA_ARGS__)
#define LOG_INFO(fmt, ...) log_message(LOG_INFO_LEVEL, __FILE__, __LINE__, fmt, ##__VA_ARGS__)
#define LOG_DEBUG(fmt, ...) log_message(LOG_DEBUG_LEVEL, __FILE__, __LINE__, fmt, ##__VA_ARGS__)

typedef enum {
    LOG_ERROR_LEVEL,
    LOG_WARN_LEVEL,
    LOG_INFO_LEVEL,
    LOG_DEBUG_LEVEL
} LogLevel;

// Logging function
void log_message(LogLevel level, const char* file, int line, const char* format, ...);

// Timer utilities
typedef struct {
    uint64_t start_time;
    uint64_t end_time;
} Timer;

Timer* timer_create(void);
void timer_start(Timer* timer);
void timer_stop(Timer* timer);
uint64_t timer_elapsed_ms(Timer* timer);
void timer_destroy(Timer* timer);

// String utilities
char* string_duplicate(const char* str);
int string_compare(const char* str1, const char* str2);
int string_length(const char* str);
char* string_format(const char* format, ...);

// Memory pool for efficient allocation
typedef struct {
    void* pool;
    size_t block_size;
    size_t num_blocks;
    uint8_t* bitmap; // Track allocation
} MemoryPool;

MemoryPool* pool_create(size_t block_size, size_t num_blocks);
void* pool_allocate(MemoryPool* pool);
void pool_free(MemoryPool* pool, void* ptr);
void pool_destroy(MemoryPool* pool);

// Vector data structure
typedef struct {
    void** elements;
    size_t count;
    size_t capacity;
} Vector;

Vector* vector_create(size_t initial_capacity);
void vector_push(Vector* vec, void* element);
void* vector_pop(Vector* vec);
void* vector_get(Vector* vec, size_t index);
void vector_destroy(Vector* vec);

// Hash table
typedef struct {
    uint64_t key;
    void* value;
} HashEntry;

typedef struct {
    HashEntry* entries;
    size_t capacity;
    size_t count;
} HashMap;

HashMap* hashmap_create(size_t capacity);
void hashmap_put(HashMap* map, uint64_t key, void* value);
void* hashmap_get(HashMap* map, uint64_t key);
void hashmap_remove(HashMap* map, uint64_t key);
void hashmap_destroy(HashMap* map);

// Integer bit utilities (findMSB equivalent)
int count_leading_zeros_u32(uint32_t value);
int find_msb_u32(uint32_t value);

#endif // UTILS_H
