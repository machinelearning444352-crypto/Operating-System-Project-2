#ifndef WINDOW_H
#define WINDOW_H

#include <string>
#include <memory>

enum class WindowState {
    Hidden,
    Minimized,
    Normal,
    Maximized,
    Fullscreen
};

enum class WindowFlags : uint32_t {
    Resizable = 1 << 0,
    Closable = 1 << 1,
    Minimizable = 1 << 2,
    Maximizable = 1 << 3,
    Titled = 1 << 4,
    Shadow = 1 << 5
};

class Window {
public:
    Window(const std::string& title, int x, int y, int width, int height);
    ~Window() = default;

    void focus();
    void blur();

    const std::string& getTitle() const { return title; }
    int getX() const { return x; }
    int getY() const { return y; }
    int getWidth() const { return width; }
    int getHeight() const { return height; }

private:
    std::string title;
    int x, y, width, height;
    WindowState state;
    uint32_t flags;
    bool hasFocus;
};

#endif // WINDOW_H
