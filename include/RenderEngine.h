#ifndef RENDER_ENGINE_H
#define RENDER_ENGINE_H

class RenderEngine {
public:
    RenderEngine() = default;
    ~RenderEngine() = default;

    void setup();
    void render();

private:
    void renderWindow(const class Window& window);
};

#endif // RENDER_ENGINE_H
