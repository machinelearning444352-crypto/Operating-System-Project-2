#include "DockView.h"

DockView::DockView(HWND parent) : m_parent(parent) {
  m_items = {
      {L"Finder", L"\U0001F4C1", Gdiplus::Color(255, 51, 128, 242)},
      {L"Safari", L"\U0001F9ED", Gdiplus::Color(255, 51, 153, 242)},
      {L"Messages", L"\U0001F4AC", Gdiplus::Color(255, 52, 199, 89)},
      {L"Mail", L"\U00002709", Gdiplus::Color(255, 51, 140, 242)},
      {L"Music", L"\U0001F3B5", Gdiplus::Color(255, 242, 64, 89)},
      {L"Photos", L"\U0001F308", Gdiplus::Color(255, 242, 102, 77)},
      {L"Notes", L"\U0001F4DD", Gdiplus::Color(255, 242, 209, 64)},
      {L"Calendar", L"\U0001F4C5", Gdiplus::Color(255, 242, 77, 77)},
      {L"Terminal", L"\U00002B1B", Gdiplus::Color(255, 38, 38, 38)},
      {L"Activity Monitor", L"\U0001F4CA", Gdiplus::Color(255, 52, 204, 102)},
      {L"Settings", L"\U00002699", Gdiplus::Color(255, 140, 140, 148)},
      {L"Antivirus", L"\U0001F6E1", Gdiplus::Color(255, 26, 153, 77)},
      {L"Downloads", L"\U00002B07", Gdiplus::Color(255, 102, 102, 230)},
  };
}

void DockView::draw(Gdiplus::Graphics &g, int windowW, int windowH) {
  float dockW = (float)(m_items.size() * (ITEM_SIZE + SPACING) + 40);
  float dockH = (float)HEIGHT - 12;
  float dockX = (windowW - dockW) / 2;
  float dockY = (float)(windowH - HEIGHT + 6);
  float cornerR = dockH / 2.0f;
  if (cornerR > 22)
    cornerR = 22;

  // ─── LIQUID GLASS DOCK ───
  Gdiplus::RectF dockRect(dockX, dockY, dockW, dockH);

  // Glass fill
  Gdiplus::SolidBrush glassBrush(Gdiplus::Color(56, 255, 255, 255));
  GlassHelper::drawRoundedRect(g, dockRect, cornerR, &glassBrush);

  // Inner gradient
  Gdiplus::LinearGradientBrush innerGrad(
      Gdiplus::PointF(dockX, dockY), Gdiplus::PointF(dockX, dockY + dockH),
      Gdiplus::Color(46, 255, 255, 255), Gdiplus::Color(15, 255, 255, 255));
  GlassHelper::drawRoundedRect(g, dockRect, cornerR, &innerGrad);

  // Border
  Gdiplus::Pen borderPen(Gdiplus::Color(76, 255, 255, 255), 0.5f);
  GlassHelper::drawRoundedRect(g, dockRect, cornerR, &borderPen);

  // ─── DOCK ITEMS ───
  float totalWidth = (float)(m_items.size() * (ITEM_SIZE + SPACING) - SPACING);
  float startX = (windowW - totalWidth) / 2.0f;

  for (int i = 0; i < (int)m_items.size(); i++) {
    float size = (float)ITEM_SIZE;
    float yOff = 0;

    // Magnification on hover
    float scale = 1.0f;
    if (i == m_hoveredItem) {
      scale = 1.3f;
      yOff = -8;
    } else if (m_hoveredItem >= 0 && abs(i - m_hoveredItem) == 1) {
      scale = 1.15f;
      yOff = -4;
    } else if (m_hoveredItem >= 0 && abs(i - m_hoveredItem) == 2) {
      scale = 1.05f;
      yOff = -1;
    }

    float scaledSize = size * scale;
    float x = startX + i * (ITEM_SIZE + SPACING) + (ITEM_SIZE - scaledSize) / 2;
    float y = dockY + 10 + (ITEM_SIZE - scaledSize) / 2 + yOff;

    // Icon background
    float iconR = scaledSize * 0.22f;
    Gdiplus::RectF iconRect(x, y, scaledSize, scaledSize);

    // App color gradient
    auto &item = m_items[i];
    Gdiplus::Color colorLight(216, item.color.GetR(), item.color.GetG(),
                              item.color.GetB());
    Gdiplus::Color colorDark(166, item.color.GetR(), item.color.GetG(),
                             item.color.GetB());
    Gdiplus::LinearGradientBrush appGrad(Gdiplus::PointF(x, y),
                                         Gdiplus::PointF(x, y + scaledSize),
                                         colorLight, colorDark);
    GlassHelper::drawRoundedRect(g, iconRect, iconR, &appGrad);

    // Glass reflection on top half
    Gdiplus::RectF reflRect(x + 2, y + 2, scaledSize - 4, scaledSize * 0.4f);
    Gdiplus::LinearGradientBrush reflGrad(
        Gdiplus::PointF(x, y), Gdiplus::PointF(x, y + scaledSize * 0.5f),
        Gdiplus::Color(89, 255, 255, 255), Gdiplus::Color(0, 255, 255, 255));
    GlassHelper::drawRoundedRect(g, reflRect, iconR - 2, &reflGrad);

    // Border
    Gdiplus::Pen iconBorder(Gdiplus::Color(64, 255, 255, 255), 0.5f);
    GlassHelper::drawRoundedRect(g, iconRect, iconR, &iconBorder);

    // Icon text (emoji or symbol)
    Gdiplus::Font iconFont(L"Segoe UI Emoji", scaledSize * 0.35f,
                           Gdiplus::FontStyleRegular);
    Gdiplus::SolidBrush iconBrush(Gdiplus::Color(255, 255, 255, 255));
    Gdiplus::StringFormat fmt;
    fmt.SetAlignment(Gdiplus::StringAlignmentCenter);
    fmt.SetLineAlignment(Gdiplus::StringAlignmentCenter);
    g.DrawString(item.icon.c_str(), -1, &iconFont, iconRect, &fmt, &iconBrush);

    // Running indicator dot
    if (item.name == L"Finder") {
      float dotSize = 4;
      Gdiplus::SolidBrush dotBrush(Gdiplus::Color(216, 242, 242, 242));
      g.FillEllipse(&dotBrush, x + (scaledSize - dotSize) / 2,
                    dockY + dockH - 8, dotSize, dotSize);
    }
  }

  // Tooltip for hovered item
  if (m_hoveredItem >= 0 && m_hoveredItem < (int)m_items.size()) {
    auto &item = m_items[m_hoveredItem];
    Gdiplus::Font tipFont(L"Segoe UI", 10, Gdiplus::FontStyleRegular);
    Gdiplus::RectF tipBounds;
    g.MeasureString(item.name.c_str(), -1, &tipFont, Gdiplus::PointF(0, 0),
                    &tipBounds);

    float tipX = startX + m_hoveredItem * (ITEM_SIZE + SPACING) +
                 ITEM_SIZE / 2 - tipBounds.Width / 2 - 8;
    float tipY = dockY - tipBounds.Height - 12;
    Gdiplus::RectF tipRect(tipX, tipY, tipBounds.Width + 16,
                           tipBounds.Height + 8);

    Gdiplus::SolidBrush tipBg(Gdiplus::Color(216, 38, 38, 38));
    GlassHelper::drawRoundedRect(g, tipRect, 8, &tipBg);
    Gdiplus::Pen tipBorder(Gdiplus::Color(38, 255, 255, 255), 0.5f);
    GlassHelper::drawRoundedRect(g, tipRect, 8, &tipBorder);

    Gdiplus::SolidBrush tipText(Gdiplus::Color(242, 242, 242));
    g.DrawString(item.name.c_str(), -1, &tipFont,
                 Gdiplus::PointF(tipX + 8, tipY + 4), &tipText);
  }
}

bool DockView::onMouseMove(int x, int y, int windowW, int windowH) {
  int oldHovered = m_hoveredItem;
  m_hoveredItem = -1;

  // Check if in dock area (bottom 75px)
  if (y > windowH - HEIGHT) {
    float totalWidth =
        (float)(m_items.size() * (ITEM_SIZE + SPACING) - SPACING);
    float startX = (windowW - totalWidth) / 2.0f;

    for (int i = 0; i < (int)m_items.size(); i++) {
      float ix = startX + i * (ITEM_SIZE + SPACING);
      if (x >= ix && x < ix + ITEM_SIZE) {
        m_hoveredItem = i;
        break;
      }
    }
  }

  return m_hoveredItem != oldHovered;
}

bool DockView::onMouseLeave() {
  if (m_hoveredItem != -1) {
    m_hoveredItem = -1;
    return true;
  }
  return false;
}

bool DockView::onClick(int x, int y, int windowW, int windowH) {
  if (y <= windowH - HEIGHT)
    return false;

  float totalWidth = (float)(m_items.size() * (ITEM_SIZE + SPACING) - SPACING);
  float startX = (windowW - totalWidth) / 2.0f;

  for (int i = 0; i < (int)m_items.size(); i++) {
    float ix = startX + i * (ITEM_SIZE + SPACING);
    if (x >= ix && x < ix + ITEM_SIZE) {
      App::instance().openApp(m_items[i].name);
      return true;
    }
  }

  return false;
}
