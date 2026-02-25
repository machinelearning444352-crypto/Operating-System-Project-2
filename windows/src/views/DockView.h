#pragma once
#include "../App.h"
#include <cmath>
#include <string>
#include <vector>

class DockView {
public:
  DockView(HWND parent);
  void draw(Gdiplus::Graphics &g, int windowW, int windowH);
  bool onMouseMove(int x, int y, int windowW, int windowH);
  bool onMouseLeave();
  bool onClick(int x, int y, int windowW, int windowH);

  static const int HEIGHT = 75;

private:
  HWND m_parent;
  int m_hoveredItem = -1;

  struct DockItem {
    std::wstring name;
    std::wstring icon;
    Gdiplus::Color color;
  };
  std::vector<DockItem> m_items;

  static const int ITEM_SIZE = 46;
  static const int SPACING = 4;
};
