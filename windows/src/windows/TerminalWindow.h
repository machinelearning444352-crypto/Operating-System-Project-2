#pragma once
#include "BaseWindow.h"

class TerminalWindow : public BaseWindow {
public:
  TerminalWindow();

protected:
  void onCreate() override;
  void onResize(int w, int h) override;

private:
  HWND m_output = nullptr;
  HWND m_input = nullptr;
};
