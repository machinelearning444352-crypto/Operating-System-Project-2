#include "MenuBarView.h"

MenuBarView::MenuBarView(HWND parent) : m_parent(parent) { updateTimeString(); }

void MenuBarView::updateClock() { updateTimeString(); }

void MenuBarView::updateTimeString() {
  time_t now = time(nullptr);
  struct tm tm;
  localtime_s(&tm, &now);
  wchar_t buf[64];
  wcsftime(buf, 64, L"%a %b %d  %I:%M %p", &tm);
  m_timeString = buf;
}

void MenuBarView::invalidate() { InvalidateRect(m_parent, nullptr, FALSE); }

void MenuBarView::draw(Gdiplus::Graphics &g, int windowW, int windowH) {
  m_menuItems.clear();

  float barH = (float)HEIGHT;
  float barY = (float)(windowH - HEIGHT); // Top of window (Win32 y=0 is top)
  // Actually in our custom drawing, y=0 is top, menu bar is at top
  barY = 0;

  // ─── LIQUID GLASS MENU BAR ───
  // Semi-transparent white overlay
  Gdiplus::SolidBrush glassBrush(Gdiplus::Color(46, 255, 255, 255));
  g.FillRectangle(&glassBrush, 0.0f, barY, (float)windowW, barH);

  // Subtle gradient for depth
  Gdiplus::LinearGradientBrush edgeGrad(
      Gdiplus::PointF(0, barY), Gdiplus::PointF(0, barY + barH),
      Gdiplus::Color(30, 255, 255, 255), Gdiplus::Color(0, 255, 255, 255));
  g.FillRectangle(&edgeGrad, 0.0f, barY, (float)windowW, barH);

  // Bottom separator
  Gdiplus::Pen sepPen(Gdiplus::Color(30, 0, 0, 0), 0.5f);
  g.DrawLine(&sepPen, 0.0f, barY + barH, (float)windowW, barY + barH);

  // ─── APPLE LOGO ───
  Gdiplus::Font appleFont(L"Segoe UI Symbol", 13, Gdiplus::FontStyleRegular);
  Gdiplus::SolidBrush textBrush(Gdiplus::Color(224, 0, 0, 0));

  // Apple symbol (using a filled circle as placeholder since Windows doesn't
  // have )
  Gdiplus::Font logoFont(L"Segoe UI", 14, Gdiplus::FontStyleBold);
  g.DrawString(L"\x2318", -1, &logoFont, Gdiplus::PointF(12, barY + 3),
               &textBrush);

  m_appleRect = {6, (int)barY, 34, (int)(barY + barH)};

  // Hover effect for apple
  if (m_hoveredItem == -2) {
    Gdiplus::SolidBrush hlBrush(Gdiplus::Color(25, 0, 0, 0));
    Gdiplus::RectF hlRect(8, barY + 3, 24, barH - 6);
    GlassHelper::drawRoundedRect(g, hlRect, 4, &hlBrush);
  }

  // ─── LEFT: App name + Menu items ───
  float xOffset = 42;

  // Active app name (bold)
  Gdiplus::Font boldFont(L"Segoe UI", 12, Gdiplus::FontStyleBold);
  Gdiplus::Font menuFont(L"Segoe UI", 12, Gdiplus::FontStyleRegular);

  std::wstring activeApp = App::instance().getActiveApp();
  Gdiplus::RectF appNameBounds;
  g.MeasureString(activeApp.c_str(), -1, &boldFont, Gdiplus::PointF(0, 0),
                  &appNameBounds);

  MenuItem appItem;
  appItem.name = activeApp;
  appItem.rect = {(int)(xOffset - 6), (int)barY,
                  (int)(xOffset + appNameBounds.Width + 6), (int)(barY + barH)};
  m_menuItems.push_back(appItem);

  if (m_hoveredItem == 0) {
    Gdiplus::SolidBrush hlBrush(Gdiplus::Color(25, 0, 0, 0));
    Gdiplus::RectF hlRect(xOffset - 6, barY + 3, appNameBounds.Width + 12,
                          barH - 6);
    GlassHelper::drawRoundedRect(g, hlRect, 4, &hlBrush);
  }
  g.DrawString(
      activeApp.c_str(), -1, &boldFont,
      Gdiplus::PointF(xOffset, barY + (barH - appNameBounds.Height) / 2),
      &textBrush);
  xOffset += appNameBounds.Width + 18;

  // Menu items
  std::vector<std::wstring> menus = {L"File", L"Edit",   L"View",
                                     L"Go",   L"Window", L"Help"};

  for (int i = 0; i < (int)menus.size(); i++) {
    Gdiplus::RectF bounds;
    g.MeasureString(menus[i].c_str(), -1, &menuFont, Gdiplus::PointF(0, 0),
                    &bounds);

    MenuItem item;
    item.name = menus[i];
    item.rect = {(int)(xOffset - 6), (int)barY,
                 (int)(xOffset + bounds.Width + 6), (int)(barY + barH)};
    m_menuItems.push_back(item);

    if (m_hoveredItem == (i + 1)) {
      Gdiplus::SolidBrush hlBrush(Gdiplus::Color(25, 0, 0, 0));
      Gdiplus::RectF hlRect(xOffset - 6, barY + 3, bounds.Width + 12, barH - 6);
      GlassHelper::drawRoundedRect(g, hlRect, 4, &hlBrush);
    }

    Gdiplus::SolidBrush menuBrush(Gdiplus::Color(216, 0, 0, 0));
    g.DrawString(menus[i].c_str(), -1, &menuFont,
                 Gdiplus::PointF(xOffset, barY + (barH - bounds.Height) / 2),
                 &menuBrush);
    xOffset += bounds.Width + 16;
  }

  // ─── RIGHT: Status icons ───
  float rightX = (float)(windowW - 14);

  // Time
  Gdiplus::Font timeFont(L"Segoe UI", 11, Gdiplus::FontStyleRegular);
  Gdiplus::RectF timeBounds;
  g.MeasureString(m_timeString.c_str(), -1, &timeFont, Gdiplus::PointF(0, 0),
                  &timeBounds);
  rightX -= timeBounds.Width;
  g.DrawString(m_timeString.c_str(), -1, &timeFont,
               Gdiplus::PointF(rightX, barY + (barH - timeBounds.Height) / 2),
               &textBrush);

  // WiFi icon (three arcs)
  rightX -= 28;
  Gdiplus::Pen wifiPen(Gdiplus::Color(200, 0, 0, 0), 1.2f);
  float wifiCX = rightX + 8;
  float wifiBaseY = barY + barH / 2 + 2;
  // Dot
  g.FillEllipse(&textBrush, wifiCX - 1.5f, wifiBaseY, 3.0f, 3.0f);
  // Arcs
  for (int arc = 0; arc < 3; arc++) {
    float r = 4.0f + arc * 3.5f;
    g.DrawArc(&wifiPen, wifiCX - r, wifiBaseY - r + 1.5f, r * 2, r * 2, -135,
              90);
  }

  // Battery
  rightX -= 44;
  float battY = barY + (barH - 10) / 2;
  Gdiplus::Pen battPen(Gdiplus::Color(190, 0, 0, 0), 1.0f);
  Gdiplus::RectF battBody(rightX, battY, 22, 10);
  GlassHelper::drawRoundedRect(g, battBody, 2.5f, &battPen);
  // Battery tip
  Gdiplus::SolidBrush battTipBrush(Gdiplus::Color(128, 0, 0, 0));
  g.FillRectangle(&battTipBrush, rightX + 22, battY + 3, 2.0f, 4.0f);
  // Battery fill (green)
  Gdiplus::SolidBrush battFillBrush(Gdiplus::Color(230, 52, 199, 89));
  Gdiplus::RectF battFill(rightX + 1.5f, battY + 1.5f, 19, 7);
  GlassHelper::drawRoundedRect(g, battFill, 1.5f, &battFillBrush);
  // "100%"
  Gdiplus::Font battFont(L"Segoe UI", 8, Gdiplus::FontStyleRegular);
  Gdiplus::SolidBrush battTextBrush(Gdiplus::Color(190, 0, 0, 0));
  g.DrawString(L"100%", -1, &battFont,
               Gdiplus::PointF(rightX + 25, barY + (barH - 12) / 2),
               &battTextBrush);
}

bool MenuBarView::onMouseMove(int x, int y, int windowH) {
  int oldHovered = m_hoveredItem;
  m_hoveredItem = -1;

  // Check if in menu bar area (top 25px)
  if (y < HEIGHT) {
    // Check apple
    POINT pt = {x, y};
    if (PtInRect(&m_appleRect, pt)) {
      m_hoveredItem = -2;
    } else {
      for (int i = 0; i < (int)m_menuItems.size(); i++) {
        if (PtInRect(&m_menuItems[i].rect, pt)) {
          m_hoveredItem = i;
          break;
        }
      }
    }
  }

  return m_hoveredItem != oldHovered;
}

bool MenuBarView::onMouseLeave() {
  if (m_hoveredItem != -1) {
    m_hoveredItem = -1;
    return true;
  }
  return false;
}

bool MenuBarView::onClick(int x, int y, int windowH) {
  if (y >= HEIGHT)
    return false;

  POINT pt = {x, y};

  // Apple menu click
  if (PtInRect(&m_appleRect, pt)) {
    // Show apple menu
    HMENU menu = CreatePopupMenu();
    AppendMenuW(menu, MF_STRING, 1001, L"About This Mac");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, 1002, L"System Settings...");
    AppendMenuW(menu, MF_STRING, 1003, L"Force Quit...");
    AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
    AppendMenuW(menu, MF_STRING, 1004, L"Restart");
    AppendMenuW(menu, MF_STRING, 1005, L"Shut Down");

    POINT screenPt = {x, HEIGHT};
    ClientToScreen(m_parent, &screenPt);
    int cmd = TrackPopupMenu(menu, TPM_RETURNCMD | TPM_LEFTBUTTON, screenPt.x,
                             screenPt.y, 0, m_parent, nullptr);
    DestroyMenu(menu);

    if (cmd == 1005)
      App::instance().quit();
    return true;
  }

  // Menu item clicks
  for (auto &item : m_menuItems) {
    if (PtInRect(&item.rect, pt)) {
      if (item.name == L"Finder") {
        App::instance().openApp(L"Finder");
      }
      return true;
    }
  }

  return false;
}
