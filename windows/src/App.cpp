#include "App.h"
#include "views/DesktopView.h"
#include "views/DockView.h"
#include "views/MenuBarView.h"
#include "windows/FinderWindow.h"
#include "windows/SettingsWindow.h"
#include "windows/TerminalWindow.h"
#include <iostream>

// ─── GlassHelper implementations ───
namespace GlassHelper {
Gdiplus::GraphicsPath *createRoundedRectPath(const Gdiplus::RectF &rect,
                                             float radius) {
  auto *path = new Gdiplus::GraphicsPath();
  float d = radius * 2;
  path->AddArc(rect.X, rect.Y, d, d, 180, 90);
  path->AddArc(rect.X + rect.Width - d, rect.Y, d, d, 270, 90);
  path->AddArc(rect.X + rect.Width - d, rect.Y + rect.Height - d, d, d, 0, 90);
  path->AddArc(rect.X, rect.Y + rect.Height - d, d, d, 90, 90);
  path->CloseFigure();
  return path;
}

void drawRoundedRect(Gdiplus::Graphics &g, const Gdiplus::RectF &rect,
                     float radius, Gdiplus::Brush *brush) {
  auto *path = createRoundedRectPath(rect, radius);
  g.FillPath(brush, path);
  delete path;
}

void drawRoundedRect(Gdiplus::Graphics &g, const Gdiplus::RectF &rect,
                     float radius, Gdiplus::Pen *pen) {
  auto *path = createRoundedRectPath(rect, radius);
  g.DrawPath(pen, path);
  delete path;
}

void enableBlur(HWND hwnd) {
  DWM_BLURBEHIND bb = {0};
  bb.dwFlags = DWM_BB_ENABLE;
  bb.fEnable = TRUE;
  DwmEnableBlurBehindWindow(hwnd, &bb);
}
} // namespace GlassHelper

// ─── App singleton ───
App &App::instance() {
  static App app;
  return app;
}

void App::initialize(HINSTANCE hInstance) {
  m_hInstance = hInstance;

  // Initialize GDI+
  Gdiplus::GdiplusStartupInput gdiplusStartupInput;
  Gdiplus::GdiplusStartup(&m_gdiplusToken, &gdiplusStartupInput, nullptr);

  // Register main window class
  WNDCLASSEXW wc = {};
  wc.cbSize = sizeof(WNDCLASSEXW);
  wc.style = CS_HREDRAW | CS_VREDRAW;
  wc.lpfnWndProc = WndProc;
  wc.hInstance = hInstance;
  wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
  wc.hbrBackground = nullptr; // We handle all painting
  wc.lpszClassName = L"VirtualOS_MainWindow";
  wc.hIcon = LoadIcon(nullptr, IDI_APPLICATION);
  RegisterClassExW(&wc);

  // Create main window (1440x900 like macOS version)
  m_mainWindow = CreateWindowExW(
      0, L"VirtualOS_MainWindow", L"macOS-Like Operating System",
      WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, 1440, 900, nullptr,
      nullptr, hInstance, nullptr);

  // Create shell components
  m_desktop = std::make_unique<DesktopView>(m_mainWindow);
  m_menuBar = std::make_unique<MenuBarView>(m_mainWindow);
  m_dock = std::make_unique<DockView>(m_mainWindow);

  ShowWindow(m_mainWindow, SW_SHOW);
  UpdateWindow(m_mainWindow);
}

int App::run() {
  MSG msg;
  while (GetMessage(&msg, nullptr, 0, 0)) {
    TranslateMessage(&msg);
    DispatchMessage(&msg);
  }

  Gdiplus::GdiplusShutdown(m_gdiplusToken);
  return (int)msg.wParam;
}

void App::quit() { PostQuitMessage(0); }

void App::openApp(const std::wstring &appName) {
  setActiveApp(appName);

  if (appName == L"Finder") {
    if (m_windows.find(L"Finder") == m_windows.end()) {
      m_windows[L"Finder"] = std::make_shared<FinderWindow>();
    }
    m_windows[L"Finder"]->show();
  } else if (appName == L"Settings") {
    if (m_windows.find(L"Settings") == m_windows.end()) {
      m_windows[L"Settings"] = std::make_shared<SettingsWindow>();
    }
    m_windows[L"Settings"]->show();
  } else if (appName == L"Terminal") {
    if (m_windows.find(L"Terminal") == m_windows.end()) {
      m_windows[L"Terminal"] = std::make_shared<TerminalWindow>();
    }
    m_windows[L"Terminal"]->show();
  }
  // Additional apps can be added here

  if (m_menuBar) {
    m_menuBar->invalidate();
  }
}

void App::setActiveApp(const std::wstring &appName) { m_activeApp = appName; }

LRESULT CALLBACK App::WndProc(HWND hwnd, UINT msg, WPARAM wParam,
                              LPARAM lParam) {
  App &app = App::instance();

  switch (msg) {
  case WM_PAINT: {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);

    // Get client area
    RECT clientRect;
    GetClientRect(hwnd, &clientRect);
    int w = clientRect.right - clientRect.left;
    int h = clientRect.bottom - clientRect.top;

    // Double-buffer
    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP memBmp = CreateCompatibleBitmap(hdc, w, h);
    HBITMAP oldBmp = (HBITMAP)SelectObject(memDC, memBmp);

    Gdiplus::Graphics g(memDC);
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    g.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);

    // Draw desktop
    if (app.m_desktop)
      app.m_desktop->draw(g, w, h);

    // Draw dock
    if (app.m_dock)
      app.m_dock->draw(g, w, h);

    // Draw menu bar
    if (app.m_menuBar)
      app.m_menuBar->draw(g, w, h);

    // Blit to screen
    BitBlt(hdc, 0, 0, w, h, memDC, 0, 0, SRCCOPY);

    SelectObject(memDC, oldBmp);
    DeleteObject(memBmp);
    DeleteDC(memDC);

    EndPaint(hwnd, &ps);
    return 0;
  }

  case WM_MOUSEMOVE: {
    int x = LOWORD(lParam);
    int y = HIWORD(lParam);

    RECT rc;
    GetClientRect(hwnd, &rc);
    int h = rc.bottom;

    bool needsRedraw = false;
    if (app.m_menuBar)
      needsRedraw |= app.m_menuBar->onMouseMove(x, y, h);
    if (app.m_dock)
      needsRedraw |= app.m_dock->onMouseMove(x, y, rc.right, h);

    if (needsRedraw)
      InvalidateRect(hwnd, nullptr, FALSE);

    // Track mouse leave
    TRACKMOUSEEVENT tme = {};
    tme.cbSize = sizeof(tme);
    tme.dwFlags = TME_LEAVE;
    tme.hwndTrack = hwnd;
    TrackMouseEvent(&tme);
    return 0;
  }

  case WM_MOUSELEAVE: {
    bool needsRedraw = false;
    if (app.m_menuBar)
      needsRedraw |= app.m_menuBar->onMouseLeave();
    if (app.m_dock)
      needsRedraw |= app.m_dock->onMouseLeave();
    if (needsRedraw)
      InvalidateRect(hwnd, nullptr, FALSE);
    return 0;
  }

  case WM_LBUTTONDOWN: {
    int x = LOWORD(lParam);
    int y = HIWORD(lParam);

    RECT rc;
    GetClientRect(hwnd, &rc);
    int h = rc.bottom;

    if (app.m_menuBar && app.m_menuBar->onClick(x, y, h))
      return 0;
    if (app.m_dock && app.m_dock->onClick(x, y, rc.right, h))
      return 0;
    if (app.m_desktop && app.m_desktop->onClick(x, y, rc.right, h))
      return 0;
    return 0;
  }

  case WM_LBUTTONDBLCLK: {
    int x = LOWORD(lParam);
    int y = HIWORD(lParam);
    RECT rc;
    GetClientRect(hwnd, &rc);
    if (app.m_desktop)
      app.m_desktop->onDoubleClick(x, y, rc.right, rc.bottom);
    return 0;
  }

  case WM_TIMER: {
    if (wParam == 1) {
      // Clock timer — update menu bar
      if (app.m_menuBar) {
        app.m_menuBar->updateClock();
        InvalidateRect(hwnd, nullptr, FALSE);
      }
    }
    return 0;
  }

  case WM_DESTROY:
    PostQuitMessage(0);
    return 0;

  case WM_ERASEBKGND:
    return 1; // We handle erasing in WM_PAINT
  }

  return DefWindowProcW(hwnd, msg, wParam, lParam);
}
