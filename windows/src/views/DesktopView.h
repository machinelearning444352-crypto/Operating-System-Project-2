#pragma once
#include "../App.h"
#include <string>
#include <vector>

class DesktopView {
public:
  DesktopView(HWND parent);
  void draw(Gdiplus::Graphics &g, int windowW, int windowH);
  bool onClick(int x, int y, int windowW, int windowH);
  void onDoubleClick(int x, int y, int windowW, int windowH);

private:
  HWND m_parent;
  int m_selectedIcon = -1;

  struct DesktopIcon {
    std::wstring name;
    std::wstring emoji;
    std::wstring path;
  };
  std::vector<DesktopIcon> m_icons;
};
