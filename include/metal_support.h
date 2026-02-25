// Metal GPU Acceleration Support for macOS
// Provides GPU-accelerated rendering using Apple Metal

#ifndef METAL_SUPPORT_H
#define METAL_SUPPORT_H

#include <stdint.h>
#include <stddef.h>

#ifdef __APPLE__

// Metal types (opaque, actual types in .mm)
typedef void *MTLDevice;
typedef void *MTLCommandQueue;
typedef void *MTLRenderPipeline;
typedef void *MTLBuffer;
typedef void *MTLTexture;
typedef void *MTLCommandBuffer;
typedef void *MTLRenderCommandEncoder;

// GPU Buffer
typedef struct
{
    MTLBuffer buffer;
    size_t size;
    void *mapped_data;
} GPUBuffer;

// GPU Texture
typedef struct
{
    MTLTexture texture;
    uint32_t width;
    uint32_t height;
    uint32_t format;
} GPUTexture;

// GPU Context
typedef struct
{
    MTLDevice device;
    MTLCommandQueue command_queue;
    MTLRenderPipeline pipeline;
    uint8_t is_initialized;
} GPUContext;

// Function declarations
GPUContext *gpu_context_create(void);
void gpu_context_destroy(GPUContext *ctx);

GPUBuffer *gpu_buffer_create(GPUContext *ctx, size_t size);
void gpu_buffer_destroy(GPUBuffer *buf);
void gpu_buffer_write(GPUBuffer *buf, const void *data, size_t size);

GPUTexture *gpu_texture_create(GPUContext *ctx, uint32_t width, uint32_t height);
void gpu_texture_destroy(GPUTexture *tex);
void gpu_texture_write(GPUTexture *tex, const void *data, size_t size);

void gpu_render_begin(GPUContext *ctx);
void gpu_render_end(GPUContext *ctx);

void gpu_draw_vertices(GPUContext *ctx, GPUBuffer *vertices, uint32_t count);
void gpu_draw_textured_quad(GPUContext *ctx, GPUTexture *texture, float x, float y, float width, float height);

#else
// CPU fallback stubs for non-Apple platforms
typedef void *GPUContext;
typedef void *GPUBuffer;
typedef void *GPUTexture;
#endif

#endif // METAL_SUPPORT_H
