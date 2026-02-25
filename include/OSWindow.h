#ifndef OSWINDOW_H
#define OSWINDOW_H

#include <string>
#include <memory>

class OSWindow {
public:
    OSWindow(const std::string& title, int x, int y, int width, int height);
    ~OSWindow();

    void show();
    void hide();
    void close();
    void setTitle(const std::string& title);

private:
    struct Impl;
    std::unique_ptr<Impl> pImpl;
};

#endif // OSWINDOW_H
