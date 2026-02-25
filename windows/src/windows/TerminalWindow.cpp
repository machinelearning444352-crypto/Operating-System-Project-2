#include "TerminalWindow.h"

TerminalWindow::TerminalWindow() : BaseWindow(L"Terminal", 720, 480) {}

void TerminalWindow::onCreate() {
  // Dark background for terminal feel
  // Terminal output (read-only multiline edit)
  m_output = CreateWindowExW(0, L"EDIT",
                             L"VirtualOS Terminal v1.0\r\n"
                             L"Type 'help' for available commands.\r\n\r\n"
                             L"guest@virtualos ~ % ",
                             WS_CHILD | WS_VISIBLE | WS_VSCROLL | ES_MULTILINE |
                                 ES_READONLY | ES_AUTOVSCROLL,
                             0, 0, 720, 440, m_hwnd, (HMENU)100,
                             App::instance().getHInstance(), nullptr);

  // Set dark background and monospace font
  HFONT monoFont =
      CreateFontW(14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE, DEFAULT_CHARSET,
                  OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                  FIXED_PITCH, L"Consolas");
  SendMessageW(m_output, WM_SETFONT, (WPARAM)monoFont, TRUE);

  // Command input
  m_input = CreateWindowExW(0, L"EDIT", L"",
                            WS_CHILD | WS_VISIBLE | ES_AUTOHSCROLL | WS_BORDER,
                            0, 440, 720, 24, m_hwnd, (HMENU)101,
                            App::instance().getHInstance(), nullptr);
  SendMessageW(m_input, WM_SETFONT, (WPARAM)monoFont, TRUE);

  SetFocus(m_input);
}

void TerminalWindow::onResize(int w, int h) {
  int inputH = 24;
  if (m_output)
    MoveWindow(m_output, 0, 0, w, h - inputH, TRUE);
  if (m_input)
    MoveWindow(m_input, 0, h - inputH, w, inputH, TRUE);
}
