#pragma once
#include "../App.h"
#include <ctime>
#include <string>

class MenuBarView {
public:
  MenuBarView(HWND parent);
  void draw(Gdiplus::Graphics &g, int windowW, int windowH);
  bool onMouseMove(int x, int y, int windowH);
  bool onMouseLeave();
  bool onClick(int x, int y, int windowH);
  void updateClock();
  void invalidate();

  static const int HEIGHT = 25;

private:
  HWND m_parent;
  int m_hoveredItem = -1;
  std::wstring m_timeString;

  struct MenuItem {
    std::wstring name;
    RECT rect;
  };
  std::vector<MenuItem> m_menuItems;
  RECT m_appleRect = {};

  void updateTimeString();
};
