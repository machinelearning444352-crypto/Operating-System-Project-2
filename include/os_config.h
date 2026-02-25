// Configuration file for the OS
// Define system constants and settings

#ifndef OS_CONFIG_H
#define OS_CONFIG_H

// Display settings
#define DISPLAY_WIDTH 2560
#define DISPLAY_HEIGHT 1600
#define DISPLAY_REFRESH_RATE 60
#define DISPLAY_COLOR_DEPTH 32 // bits per pixel

// Memory settings
#define KERNEL_MEMORY_SIZE (512 * 1024 * 1024) // 512 MB
#define MAX_PROCESSES 1024
#define MAX_THREADS 4096

// UI settings
#define DOCK_HEIGHT 80
#define MENUBAR_HEIGHT 28
#define WINDOW_MIN_WIDTH 200
#define WINDOW_MIN_HEIGHT 150
#define WINDOW_SHADOW_BLUR 15.0f
#define WINDOW_CORNER_RADIUS 10.0f

// Graphics settings
#define ENABLE_GPU_ACCELERATION 1
#define ENABLE_BLUR_EFFECTS 1
#define ENABLE_SHADOW_EFFECTS 1
#define ENABLE_GLASS_MORPHISM 1
#define ENABLE_PARTICLE_EFFECTS 1
#define RENDER_TARGET_AA_SAMPLES 4

// Performance settings
#define TARGET_FPS 60
#define VSYNC_ENABLED 1
#define GPU_MEMORY_SIZE (2 * 1024 * 1024 * 1024) // 2 GB

// Debug settings
#define DEBUG_MODE 0
#define LOG_LEVEL 2 // 0=none, 1=error, 2=warning, 3=info, 4=debug

#endif // OS_CONFIG_H
