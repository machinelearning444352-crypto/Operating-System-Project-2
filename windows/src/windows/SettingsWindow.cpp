#include "SettingsWindow.h"

SettingsWindow::SettingsWindow() : BaseWindow(L"System Settings", 780, 560) {}

void SettingsWindow::onCreate() {
  // ─── SIDEBAR (Settings categories) ───
  m_sidebar = addListBox(0, 0, 220, 560, 200);

  const wchar_t *items[] = {
      L"  \U0001F4F6  Wi-Fi",
      L"  \U0001F50A  Sound",
      L"  \U0001F50B  Battery",
      L"  \U0001F5A5  Displays",
      L"  \U0001F3A8  Appearance",
      L"  \U0001F512  Privacy & Security",
      L"  \U0001F310  Network",
      L"  \U0001F4E6  Software Update",
      L"  \U0001F464  Users & Groups",
      L"  \U00002328  Keyboard",
      L"  \U0001F5B1  Mouse & Trackpad",
      L"  \U0001F5A8  Printers & Scanners",
      L"  \U0001F4C0  Storage",
      L"  \U0001F552  Date & Time",
      L"  \U0001F310  Language & Region",
      L"  \U0000267F  Accessibility",
  };

  for (auto &item : items) {
    SendMessageW(m_sidebar, LB_ADDSTRING, 0, (LPARAM)item);
  }

  HFONT font =
      CreateFontW(15, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                  OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                  DEFAULT_PITCH, L"Segoe UI");
  SendMessageW(m_sidebar, WM_SETFONT, (WPARAM)font, TRUE);

  // ─── DETAIL PANEL ───
  addLabel(L"System Settings", 240, 20, 300, 28);
  addLabel(L"macOS Tahoe", 240, 50, 300, 20);
  addLabel(L"Version 26.0", 240, 70, 300, 20);
  addLabel(L"", 240, 100, 500, 1); // Separator

  // Wi-Fi section (default)
  addLabel(L"\U0001F4F6  Wi-Fi", 240, 120, 300, 28);
  addLabel(L"Status: Connected", 260, 150, 300, 20);
  addLabel(L"Network: VirtualOS-WiFi", 260, 172, 300, 20);
  addLabel(L"IP Address: 192.168.1.42", 260, 194, 300, 20);
  addLabel(L"Signal Strength: Excellent", 260, 216, 300, 20);

  // Some toggle buttons
  addButton(L"Turn Wi-Fi Off", 260, 260, 140, 30, 300);
  addButton(L"Forget Network", 410, 260, 140, 30, 301);

  // System info at bottom
  addLabel(L"──────────────────────────────", 240, 320, 500, 20);
  addLabel(L"\U0001F4BB  About This Mac", 240, 350, 300, 28);
  addLabel(L"MacBook Pro", 260, 380, 300, 20);
  addLabel(L"Chip: Apple M3 Pro (Virtual)", 260, 402, 300, 20);
  addLabel(L"Memory: 16 GB", 260, 424, 300, 20);
  addLabel(L"macOS Tahoe 26.0", 260, 446, 300, 20);
}

void SettingsWindow::onResize(int w, int h) {
  if (m_sidebar)
    MoveWindow(m_sidebar, 0, 0, 220, h, TRUE);
}
