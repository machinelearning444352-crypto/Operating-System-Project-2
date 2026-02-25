#ifndef DESKTOP_ENVIRONMENT_H
#define DESKTOP_ENVIRONMENT_H

#include <memory>
#include <vector>
#include <string>

class WindowManager;
class ApplicationManager;
class EventManager;
class RenderEngine;
class OSWindow;

class DesktopEnvironment {
public:
    static DesktopEnvironment& getInstance();
    
    void initialize();
    void run();

    // Accessors for subsystems
    WindowManager& getWindowManager();
    ApplicationManager& getApplicationManager();
    EventManager& getEventManager();
    RenderEngine& getRenderEngine();

private:
    DesktopEnvironment();
    ~DesktopEnvironment() = default;
    DesktopEnvironment(const DesktopEnvironment&) = delete;
    DesktopEnvironment& operator=(const DesktopEnvironment&) = delete;

    std::unique_ptr<WindowManager> windowManager;
    std::unique_ptr<ApplicationManager> applicationManager;
    std::unique_ptr<EventManager> eventManager;
    std::unique_ptr<RenderEngine> renderEngine;

    std::vector<std::shared_ptr<OSWindow>> persistentWindows;

    void createMenuBar();
    void createDock();
    void createDesktop();
};

#endif // DESKTOP_ENVIRONMENT_H
