#ifndef EVENT_MANAGER_H
#define EVENT_MANAGER_H

class EventManager {
public:
    EventManager() = default;
    ~EventManager() = default;

    void startEventLoop();
    void processEvents();

private:
    // Placeholder for event loop internals
};

#endif // EVENT_MANAGER_H
