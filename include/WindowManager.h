#ifndef WINDOW_MANAGER_H
#define WINDOW_MANAGER_H

#include <vector>
#include <string>

class Window;

class WindowManager {
public:
    WindowManager() = default;
    ~WindowManager() = default;

    void registerWindow(std::shared_ptr<Window> window);
    std::shared_ptr<Window> createWindow(const std::string& title, int x, int y, int width, int height);
    void setFocused(std::shared_ptr<Window> window);
    void removeWindow(std::shared_ptr<Window> window);
    const std::vector<std::shared_ptr<Window>>& getAllWindows() const;

private:
    std::vector<std::shared_ptr<Window>> windows;
    std::shared_ptr<Window> focusedWindow;
};

#endif // WINDOW_MANAGER_H
