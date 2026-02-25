#ifndef GRAPHICS_H
#define GRAPHICS_H

#include <stdbool.h>
#include <stdint.h>

// Color representation (ARGB)
typedef struct {
  uint8_t alpha;
  uint8_t red;
  uint8_t green;
  uint8_t blue;
} Color;

// Rectangle for bounds
typedef struct {
  int32_t x;
  int32_t y;
  int32_t width;
  int32_t height;
} OSRect;

// Vector2D
typedef struct {
  float x;
  float y;
} Vector2D;

// Graphics context
typedef struct {
  uint32_t width;
  uint32_t height;
  uint32_t bits_per_pixel;
  void *framebuffer;
} GraphicsContext;

// Texture for images/sprites
typedef struct {
  uint32_t texture_id;
  uint32_t width;
  uint32_t height;
  void *data;
} Texture;

// Initialization
GraphicsContext *graphics_init(uint32_t width, uint32_t height);
void graphics_shutdown(void);

// Drawing primitives
void draw_rect(GraphicsContext *ctx, OSRect rect, Color color);
void draw_rounded_rect(GraphicsContext *ctx, OSRect rect, int radius,
                       Color color);
void draw_rect_outline(GraphicsContext *ctx, OSRect rect, int thickness,
                       Color color);
void draw_circle(GraphicsContext *ctx, int32_t x, int32_t y, uint32_t radius,
                 Color color);
void draw_line(GraphicsContext *ctx, int32_t x1, int32_t y1, int32_t x2,
               int32_t y2, Color color);

// Texture operations
Texture *texture_create(uint32_t width, uint32_t height);
void texture_destroy(Texture *texture);
void draw_texture(GraphicsContext *ctx, Texture *texture, int32_t x, int32_t y);

// Effects and filters
void apply_blur(GraphicsContext *ctx, OSRect bounds, float radius);
void apply_shadow(GraphicsContext *ctx, OSRect bounds, Color shadow_color,
                  float blur_radius);
void apply_gradient(GraphicsContext *ctx, OSRect bounds, Color start_color,
                    Color end_color, bool horizontal);

// Display update
void graphics_present(GraphicsContext *ctx);

#endif // GRAPHICS_H
#ifdef __cplusplus
extern "C" {
#endif
void graphics_render_frame();
#ifdef __cplusplus
}
#endif

#ifdef __cplusplus
extern "C" {
#endif
#ifdef __cplusplus
}
#endif

