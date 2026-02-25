#ifndef GRAPHICS_ENGINE_HPP
#define GRAPHICS_ENGINE_HPP

#include <cstdint>
#include <glm/glm.hpp>
#include <memory>
#include <vector>
#ifdef __cplusplus
extern "C" {
#endif
#include "graphics.h"
#ifdef __cplusplus
}
#endif

namespace OS {
namespace Graphics {

// GPU Device Management
class GPUDevice {
public:
  GPUDevice();
  ~GPUDevice();

  void initialize();
  void shutdown();

  bool isSupported() const { return is_supported; }
  std::string getDeviceName() const { return device_name; }

private:
  bool is_supported;
  std::string device_name;
  void *metal_device;  // Metal device handle
  void *command_queue; // Command queue
};

// Shader compilation and management
class ShaderProgram {
public:
  ShaderProgram(const std::string &vertex_src, const std::string &fragment_src);
  ~ShaderProgram();

  void use();
  void setUniform(const std::string &name, const glm::mat4 &matrix);
  void setUniform(const std::string &name, const glm::vec4 &vec);

private:
  uint32_t program_id;
  uint32_t vertex_shader;
  uint32_t fragment_shader;
};

// Render target (framebuffer)
class RenderTarget {
public:
  RenderTarget(uint32_t width, uint32_t height);
  ~RenderTarget();

  void bind();
  void unbind();
  void clear(const glm::vec4 &color);

  uint32_t getColorAttachment() const { return color_texture; }

private:
  uint32_t framebuffer_id;
  uint32_t color_texture;
  uint32_t depth_texture;
  uint32_t width, height;
};

// Advanced rendering features
class AdvancedRenderer {
public:
  AdvancedRenderer();
  ~AdvancedRenderer();

  void enableBlur(float intensity);
  void enableShadow(const glm::vec3 &light_pos, float intensity);
  void enableGlassEffect(float transparency, float blur);
  void enableParticleSystem();
  void enableVignette(float intensity);

  void render_rect(OSRect rect, Color color);
  void apply_blur_to_rect(OSRect rect, float intensity);

  // Transition effects
  void transitionFade(float duration);
  void transitionSlide(float duration, const glm::vec2 &direction);
  void transitionScale(float duration, float scale);

private:
  std::unique_ptr<ShaderProgram> blur_shader;
  std::unique_ptr<ShaderProgram> shadow_shader;
  std::unique_ptr<ShaderProgram> glass_shader;
  std::unique_ptr<ShaderProgram> particle_shader;
};

// Texture management
class TextureAtlas {
public:
  TextureAtlas(uint32_t size);
  ~TextureAtlas();

  uint32_t addTexture(const std::string &path);
  void removeTexture(uint32_t texture_id);

private:
  std::vector<std::pair<uint32_t, std::string>> textures;
  uint32_t atlas_size;
};

// Vector graphics rendering
class VectorGraphics {
public:
  static void drawRoundedRect(float x, float y, float width, float height,
                              float radius);
  static void drawBlur(float x, float y, float width, float height,
                       float blur_radius);
  static void drawGlassPanel(float x, float y, float width, float height);
  static void drawSmoothShadow(float x, float y, float width, float height,
                               float blur_radius);
};
} // namespace Graphics
} // namespace OS

#endif // GRAPHICS_ENGINE_HPP
