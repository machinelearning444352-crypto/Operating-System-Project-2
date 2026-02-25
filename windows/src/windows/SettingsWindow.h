#pragma once
#include "BaseWindow.h"

class SettingsWindow : public BaseWindow {
public:
  SettingsWindow();

protected:
  void onCreate() override;
  void onResize(int w, int h) override;

private:
  HWND m_sidebar = nullptr;
  HWND m_detailPanel = nullptr;
};
