#pragma once
#include "BaseWindow.h"

class FinderWindow : public BaseWindow {
public:
  FinderWindow();

protected:
  void onCreate() override;
  void onResize(int w, int h) override;

private:
  HWND m_sidebar = nullptr;
  HWND m_listView = nullptr;
  HWND m_pathBar = nullptr;
  HWND m_statusBar = nullptr;

  static LRESULT CALLBACK SidebarProc(HWND, UINT, WPARAM, LPARAM, UINT_PTR,
                                      DWORD_PTR);
  void populateFileList();
  void populateSidebar();

  std::wstring m_currentPath = L"/Users/Guest";
};
