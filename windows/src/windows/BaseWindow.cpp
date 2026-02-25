#include "BaseWindow.h"

int BaseWindow::s_classCounter = 0;

BaseWindow::BaseWindow(const std::wstring &title, int width, int height)
    : m_title(title), m_width(width), m_height(height) {

  m_className = L"VirtualOS_Window_" + std::to_wstring(++s_classCounter);

  WNDCLASSEXW wc = {};
  wc.cbSize = sizeof(WNDCLASSEXW);
  wc.style = CS_HREDRAW | CS_VREDRAW;
  wc.lpfnWndProc = WndProc;
  wc.hInstance = App::instance().getHInstance();
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
  wc.lpszClassName = m_className.c_str();
  RegisterClassExW(&wc);

  m_hwnd = CreateWindowExW(
      WS_EX_OVERLAPPEDWINDOW, m_className.c_str(), m_title.c_str(),
      WS_OVERLAPPEDWINDOW | WS_CLIPCHILDREN, CW_USEDEFAULT, CW_USEDEFAULT,
      m_width, m_height, nullptr, nullptr, App::instance().getHInstance(),
      this // Store this pointer for WndProc
  );

  // Enable dark mode title bar (Windows 10+)
  BOOL useDarkMode = FALSE;
  DwmSetWindowAttribute(m_hwnd, 20 /* DWMWA_USE_IMMERSIVE_DARK_MODE */,
                        &useDarkMode, sizeof(useDarkMode));

  // Round corners (Windows 11)
  int cornerPref = 2; // DWMWCP_ROUND
  DwmSetWindowAttribute(m_hwnd, 33 /* DWMWA_WINDOW_CORNER_PREFERENCE */,
                        &cornerPref, sizeof(cornerPref));

  onCreate();
}

BaseWindow::~BaseWindow() {
  if (m_hwnd)
    DestroyWindow(m_hwnd);
}

void BaseWindow::show() {
  ShowWindow(m_hwnd, SW_SHOW);
  SetForegroundWindow(m_hwnd);
}

void BaseWindow::hide() { ShowWindow(m_hwnd, SW_HIDE); }

bool BaseWindow::isVisible() const { return IsWindowVisible(m_hwnd); }

void BaseWindow::onPaint(HDC hdc, int w, int h) {
  // Default: white background
  RECT rc = {0, 0, w, h};
  FillRect(hdc, &rc, (HBRUSH)GetStockObject(WHITE_BRUSH));
}

void BaseWindow::onClose() { hide(); }

HWND BaseWindow::addButton(const wchar_t *text, int x, int y, int w, int h,
                           int id) {
  return CreateWindowExW(
      0, L"BUTTON", text, WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON, x, y, w, h,
      m_hwnd, (HMENU)(INT_PTR)id, App::instance().getHInstance(), nullptr);
}

HWND BaseWindow::addLabel(const wchar_t *text, int x, int y, int w, int h) {
  return CreateWindowExW(0, L"STATIC", text, WS_CHILD | WS_VISIBLE | SS_LEFT, x,
                         y, w, h, m_hwnd, nullptr,
                         App::instance().getHInstance(), nullptr);
}

HWND BaseWindow::addEdit(const wchar_t *text, int x, int y, int w, int h,
                         int id) {
  return CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", text,
                         WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL, x, y, w, h,
                         m_hwnd, (HMENU)(INT_PTR)id,
                         App::instance().getHInstance(), nullptr);
}

HWND BaseWindow::addListBox(int x, int y, int w, int h, int id) {
  return CreateWindowExW(WS_EX_CLIENTEDGE, L"LISTBOX", nullptr,
                         WS_CHILD | WS_VISIBLE | LBS_NOTIFY | WS_VSCROLL, x, y,
                         w, h, m_hwnd, (HMENU)(INT_PTR)id,
                         App::instance().getHInstance(), nullptr);
}

LRESULT CALLBACK BaseWindow::WndProc(HWND hwnd, UINT msg, WPARAM wParam,
                                     LPARAM lParam) {
  BaseWindow *self = nullptr;

  if (msg == WM_NCCREATE) {
    auto *cs = reinterpret_cast<CREATESTRUCT *>(lParam);
    self = reinterpret_cast<BaseWindow *>(cs->lpCreateParams);
    SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)self);
  } else {
    self =
        reinterpret_cast<BaseWindow *>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));
  }

  switch (msg) {
  case WM_PAINT: {
    if (self) {
      PAINTSTRUCT ps;
      HDC hdc = BeginPaint(hwnd, &ps);
      RECT rc;
      GetClientRect(hwnd, &rc);
      self->onPaint(hdc, rc.right, rc.bottom);
      EndPaint(hwnd, &ps);
      return 0;
    }
    break;
  }
  case WM_SIZE: {
    if (self) {
      self->onResize(LOWORD(lParam), HIWORD(lParam));
    }
    break;
  }
  case WM_CLOSE: {
    if (self) {
      self->onClose();
      return 0;
    }
    break;
  }
  }

  return DefWindowProcW(hwnd, msg, wParam, lParam);
}
