#include "FinderWindow.h"
#include <commctrl.h>

FinderWindow::FinderWindow() : BaseWindow(L"Finder", 960, 620) {}

void FinderWindow::onCreate() {
  // ─── TOOLBAR area (back, forward, path, search) ───
  addButton(L"\u25C0", 78, 10, 30, 28, 100);  // Back
  addButton(L"\u25B6", 110, 10, 30, 28, 101); // Forward
  addButton(L"\u2191", 150, 10, 30, 28, 102); // Upload
  addButton(L"\u2193", 182, 10, 30, 28, 103); // Download

  // Path bar
  m_pathBar = addEdit(m_currentPath.c_str(), 222, 12, 500, 24, 110);

  // ─── SIDEBAR (ListBox acting as source list) ───
  m_sidebar = addListBox(0, 50, 200, 520, 200);
  populateSidebar();

  // ─── FILE LIST (ListView for modern look) ───
  m_listView = CreateWindowExW(
      0, WC_LISTVIEW, nullptr,
      WS_CHILD | WS_VISIBLE | LVS_REPORT | LVS_SINGLESEL | WS_BORDER, 200, 50,
      740, 500, m_hwnd, (HMENU)300, App::instance().getHInstance(), nullptr);

  // Enable extended styles
  ListView_SetExtendedListViewStyle(m_listView, LVS_EX_FULLROWSELECT |
                                                    LVS_EX_GRIDLINES |
                                                    LVS_EX_DOUBLEBUFFER);

  // Add columns
  LVCOLUMN col = {};
  col.mask = LVCF_TEXT | LVCF_WIDTH | LVCF_FMT;

  col.pszText = (LPWSTR)L"";
  col.cx = 30;
  col.fmt = LVCFMT_CENTER;
  ListView_InsertColumn(m_listView, 0, &col);

  col.pszText = (LPWSTR)L"Name";
  col.cx = 320;
  col.fmt = LVCFMT_LEFT;
  ListView_InsertColumn(m_listView, 1, &col);

  col.pszText = (LPWSTR)L"Size";
  col.cx = 80;
  col.fmt = LVCFMT_RIGHT;
  ListView_InsertColumn(m_listView, 2, &col);

  col.pszText = (LPWSTR)L"Date Modified";
  col.cx = 150;
  col.fmt = LVCFMT_LEFT;
  ListView_InsertColumn(m_listView, 3, &col);

  populateFileList();

  // ─── STATUS BAR ───
  addLabel(L"  Virtual OS File System", 200, 552, 740, 20);
}

void FinderWindow::populateSidebar() {
  SendMessageW(m_sidebar, LB_RESETCONTENT, 0, 0);

  // Section headers and items
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"── Favorites ──");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"  \U0001F5A5  Desktop");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"  \U0001F4C4  Documents");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"  \U00002B07  Downloads");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"  \U0001F3E0  Home");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0,
               (LPARAM)L"  \U0001F4E6  Applications");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0,
               (LPARAM)L"  \U0001F4BB  Macintosh HD");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"── iCloud ──");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0,
               (LPARAM)L"  \U00002601  iCloud Drive");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"── Tags ──");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"  \U0001F534  Red");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"  \U0001F7E0  Orange");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"  \U0001F7E1  Yellow");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"  \U0001F7E2  Green");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"  \U0001F535  Blue");
  SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)L"  \U0001F7E3  Purple");

  // Set font
  HFONT font =
      CreateFontW(15, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                  OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                  DEFAULT_PITCH, L"Segoe UI");
  SendMessageW(m_sidebar, WM_SETFONT, (WPARAM)font, TRUE);
}

void FinderWindow::populateFileList() {
  ListView_DeleteAllItems(m_listView);

  // Virtual file system entries
  struct FileEntry {
    const wchar_t *icon;
    const wchar_t *name;
    const wchar_t *size;
    const wchar_t *date;
  };

  FileEntry entries[] = {
      {L"\U0001F4C1", L"Applications", L"--", L"Oct 15, 2025"},
      {L"\U0001F4C1", L"System", L"--", L"Sep 20, 2025"},
      {L"\U0001F4C1", L"Users", L"--", L"Nov 1, 2025"},
      {L"\U0001F4C1", L"Library", L"--", L"Aug 12, 2025"},
      {L"\U0001F4C1", L"Desktop", L"--", L"Feb 24, 2026"},
      {L"\U0001F4C1", L"Documents", L"--", L"Feb 20, 2026"},
      {L"\U0001F4C1", L"Downloads", L"--", L"Feb 24, 2026"},
      {L"\U0001F4C1", L"Pictures", L"--", L"Jan 15, 2026"},
      {L"\U0001F4C1", L"Music", L"--", L"Dec 10, 2025"},
  };

  for (int i = 0; i < 9; i++) {
    LVITEM item = {};
    item.mask = LVIF_TEXT;
    item.iItem = i;
    item.iSubItem = 0;
    item.pszText = (LPWSTR)entries[i].icon;
    ListView_InsertItem(m_listView, &item);

    ListView_SetItemText(m_listView, i, 1, (LPWSTR)entries[i].name);
    ListView_SetItemText(m_listView, i, 2, (LPWSTR)entries[i].size);
    ListView_SetItemText(m_listView, i, 3, (LPWSTR)entries[i].date);
  }

  // Set font
  HFONT font =
      CreateFontW(14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                  OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                  DEFAULT_PITCH, L"Segoe UI");
  SendMessageW(m_listView, WM_SETFONT, (WPARAM)font, TRUE);
}

void FinderWindow::onResize(int w, int h) {
  if (m_sidebar)
    MoveWindow(m_sidebar, 0, 50, 200, h - 70, TRUE);
  if (m_listView)
    MoveWindow(m_listView, 200, 50, w - 200, h - 70, TRUE);
  if (m_pathBar)
    MoveWindow(m_pathBar, 222, 12, w - 350, 24, TRUE);
}
