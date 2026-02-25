#ifndef APPLICATION_MANAGER_H
#define APPLICATION_MANAGER_H

#include <vector>
#include <string>
#include <memory>

class Application;

class ApplicationManager {
public:
    ApplicationManager() = default;
    ~ApplicationManager() = default;

    std::shared_ptr<Application> launchApplication(const std::string& appName);
    void terminateApplication(std::shared_ptr<Application> app);

private:
    std::vector<std::shared_ptr<Application>> runningApps;
    std::shared_ptr<Application> createApplication(const std::string& name);
};

#endif // APPLICATION_MANAGER_H
