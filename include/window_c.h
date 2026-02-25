#ifndef WINDOW_C_H
#define WINDOW_C_H

#include "graphics.h"
#include <stdbool.h>
#include <stdint.h>

// Window states
typedef enum {
  WINDOW_STATE_HIDDEN,
  WINDOW_STATE_MINIMIZED,
  WINDOW_STATE_NORMAL,
  WINDOW_STATE_MAXIMIZED,
  WINDOW_STATE_FULLSCREEN
} WindowState;

// Window flags
typedef enum {
  WINDOW_FLAG_RESIZABLE = 1 << 0,
  WINDOW_FLAG_CLOSABLE = 1 << 1,
  WINDOW_FLAG_MINIMIZABLE = 1 << 2,
  WINDOW_FLAG_MAXIMIZABLE = 1 << 3,
  WINDOW_FLAG_TITLED = 1 << 4,
  WINDOW_FLAG_SHADOW = 1 << 5
} WindowFlags;

// Window handle
typedef struct CWindow {
  uint32_t window_id;
  char title[512];
  OSRect bounds;
  WindowState state;
  uint32_t flags;
  bool has_focus;
  Color background_color;
  void (*on_draw)(struct CWindow *window);
  void (*on_resize)(struct CWindow *window, uint32_t width, uint32_t height);
  void (*on_close)(struct CWindow *window);
  void *user_data;
} CWindow;

// Window Manager
typedef struct {
  CWindow **windows;
  uint32_t window_count;
  uint32_t max_windows;
  CWindow *focused_window;
} CWindowManager;

// Function declarations
CWindowManager *window_manager_create(uint32_t max_windows);
void window_manager_destroy(CWindowManager *manager);

CWindow *window_create(CWindowManager *manager, const char *title, OSRect bounds,
                      uint32_t flags);
void window_destroy(CWindowManager *manager, CWindow *window);

void window_set_title(CWindow *window, const char *title);
void window_move(CWindow *window, int32_t x, int32_t y);
void window_resize(CWindow *window, uint32_t width, uint32_t height);
void window_set_state(CWindow *window, WindowState state);
void window_focus(CWindowManager *manager, CWindow *window);

void window_draw(GraphicsContext *ctx, CWindow *window);
void window_manager_render_all(CWindowManager *manager, GraphicsContext *ctx);

#endif // WINDOW_C_H
