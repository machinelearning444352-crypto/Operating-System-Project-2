#pragma once
#include "../App.h"
#include <string>

class BaseWindow {
public:
  BaseWindow(const std::wstring &title, int width, int height);
  virtual ~BaseWindow();

  void show();
  void hide();
  bool isVisible() const;

protected:
  virtual void onCreate() = 0;
  virtual void onPaint(HDC hdc, int w, int h);
  virtual void onResize(int w, int h) {}
  virtual void onClose();

  HWND m_hwnd = nullptr;
  std::wstring m_title;
  int m_width, m_height;

  // Helper to add controls
  HWND addButton(const wchar_t *text, int x, int y, int w, int h, int id);
  HWND addLabel(const wchar_t *text, int x, int y, int w, int h);
  HWND addEdit(const wchar_t *text, int x, int y, int w, int h, int id);
  HWND addListBox(int x, int y, int w, int h, int id);

private:
  static LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);
  static int s_classCounter;
  std::wstring m_className;
};
