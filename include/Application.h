#ifndef APPLICATION_H
#define APPLICATION_H

#include <string>
#include <memory>

class Window;

class Application {
public:
    explicit Application(const std::string& name);
    virtual ~Application() = default;

    virtual void launch();
    virtual void terminate();

    const std::string& getName() const { return name; }

protected:
    virtual void createWindow() = 0;

    std::shared_ptr<Window> window;
    std::string name;
};

// Concrete application placeholders
class FinderApp : public Application {
public:
    FinderApp();
protected:
    void createWindow() override;
};

class TerminalApp : public Application {
public:
    TerminalApp();
protected:
    void createWindow() override;
};

class SafariApp : public Application {
public:
    SafariApp();
protected:
    void createWindow() override;
};

class MailApp : public Application {
public:
    MailApp();
protected:
    void createWindow() override;
};

class CalendarApp : public Application {
public:
    CalendarApp();
protected:
    void createWindow() override;
};

class SystemPreferencesApp : public Application {
public:
    SystemPreferencesApp();
protected:
    void createWindow() override;
};

#endif // APPLICATION_H
