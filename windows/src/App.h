#pragma once
#include <dwmapi.h>
#include <functional>
#include <gdiplus.h>
#include <map>
#include <memory>
#include <string>
#include <vector>
#include <windows.h>

#pragma comment(lib, "gdiplus.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "uxtheme.lib")
#pragma comment(lib, "comctl32.lib")

// ─── Forward declarations ───
class MenuBarView;
class DockView;
class DesktopView;
class BaseWindow;

// ─── App singleton ───
class App {
public:
  static App &instance();

  void initialize(HINSTANCE hInstance);
  int run();
  void quit();

  HINSTANCE getHInstance() const { return m_hInstance; }
  HWND getMainWindow() const { return m_mainWindow; }

  // Window management
  void openApp(const std::wstring &appName);
  void setActiveApp(const std::wstring &appName);
  std::wstring getActiveApp() const { return m_activeApp; }

  // Shell components
  MenuBarView *getMenuBar() const { return m_menuBar.get(); }
  DockView *getDock() const { return m_dock.get(); }
  DesktopView *getDesktop() const { return m_desktop.get(); }

private:
  App() = default;
  static LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);

  HINSTANCE m_hInstance = nullptr;
  HWND m_mainWindow = nullptr;
  std::wstring m_activeApp = L"Finder";

  std::unique_ptr<MenuBarView> m_menuBar;
  std::unique_ptr<DockView> m_dock;
  std::unique_ptr<DesktopView> m_desktop;

  ULONG_PTR m_gdiplusToken = 0;

  // Registered window classes
  std::map<std::wstring, std::shared_ptr<BaseWindow>> m_windows;
};

// ─── Color helpers ───
namespace Colors {
// Liquid Glass palette
inline Gdiplus::Color MenuBarBg(46, 255, 255, 255); // ~18% white
inline Gdiplus::Color DockBg(56, 255, 255, 255);    // ~22% white
inline Gdiplus::Color SidebarBg(240, 242, 245);
inline Gdiplus::Color WindowBg(246, 246, 248);
inline Gdiplus::Color SeparatorColor(220, 220, 224);
inline Gdiplus::Color LabelColor(30, 30, 32);
inline Gdiplus::Color SecondaryLabel(128, 128, 134);
inline Gdiplus::Color AccentBlue(0, 122, 255);
inline Gdiplus::Color SystemRed(255, 59, 48);
inline Gdiplus::Color SystemGreen(52, 199, 89);
inline Gdiplus::Color SystemOrange(255, 149, 0);
inline Gdiplus::Color SystemYellow(255, 204, 0);
inline Gdiplus::Color SystemPurple(175, 82, 222);

// Wallpaper Tahoe colors
inline Gdiplus::Color WallpaperTop(10, 31, 56);
inline Gdiplus::Color WallpaperMid(64, 76, 102);
inline Gdiplus::Color WallpaperBottom(245, 191, 130);
} // namespace Colors

// ─── Drawing helpers ───
namespace GlassHelper {
void drawRoundedRect(Gdiplus::Graphics &g, const Gdiplus::RectF &rect,
                     float radius, Gdiplus::Brush *brush);
void drawRoundedRect(Gdiplus::Graphics &g, const Gdiplus::RectF &rect,
                     float radius, Gdiplus::Pen *pen);
Gdiplus::GraphicsPath *createRoundedRectPath(const Gdiplus::RectF &rect,
                                             float radius);
void enableBlur(HWND hwnd); // DWM blur behind
} // namespace GlassHelper
