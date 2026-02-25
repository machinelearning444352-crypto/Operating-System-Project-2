#include "DesktopView.h"
#include <cmath>

DesktopView::DesktopView(HWND parent) : m_parent(parent) {
  m_icons = {
      {L"Macintosh HD", L"\U0001F4BB", L"/"},
      {L"Documents", L"\U0001F4C1", L"/Users/Guest/Documents"},
      {L"Downloads", L"\U00002B07", L"/Users/Guest/Downloads"},
      {L"Applications", L"\U0001F4E6", L"/Applications"},
      {L"Trash", L"\U0001F5D1", L"/Users/Guest/.Trash"},
  };
}

void DesktopView::draw(Gdiplus::Graphics &g, int windowW, int windowH) {
  // ─── macOS TAHOE WALLPAPER ───
  // Deep teal → warm amber gradient
  Gdiplus::LinearGradientBrush baseGrad(
      Gdiplus::PointF(0, 0),
      Gdiplus::PointF((float)windowW * 0.3f, (float)windowH),
      Gdiplus::Color(255, 10, 31, 56),     // Deep teal
      Gdiplus::Color(255, 245, 191, 130)); // Warm amber
  g.FillRectangle(&baseGrad, 0, 0, windowW, windowH);

  // Second gradient layer for complexity
  Gdiplus::LinearGradientBrush midGrad(
      Gdiplus::PointF((float)windowW, 0), Gdiplus::PointF(0, (float)windowH),
      Gdiplus::Color(128, 14, 46, 82), Gdiplus::Color(128, 224, 158, 102));
  g.FillRectangle(&midGrad, 0, 0, windowW, windowH);

  // Mountain silhouette
  Gdiplus::GraphicsPath mountainPath;
  float w = (float)windowW;
  float h = (float)windowH;

  mountainPath.AddLine(0.0f, h * 0.35f, w * 0.08f, h * 0.42f);
  mountainPath.AddLine(w * 0.08f, h * 0.42f, w * 0.15f, h * 0.55f);
  mountainPath.AddLine(w * 0.15f, h * 0.55f, w * 0.22f, h * 0.50f);
  mountainPath.AddLine(w * 0.22f, h * 0.50f, w * 0.30f, h * 0.62f);
  mountainPath.AddLine(w * 0.30f, h * 0.62f, w * 0.38f, h * 0.58f);
  mountainPath.AddLine(w * 0.38f, h * 0.58f, w * 0.45f, h * 0.68f);
  mountainPath.AddLine(w * 0.45f, h * 0.68f, w * 0.55f, h * 0.72f);
  mountainPath.AddLine(w * 0.55f, h * 0.72f, w * 0.62f, h * 0.65f);
  mountainPath.AddLine(w * 0.62f, h * 0.65f, w * 0.70f, h * 0.58f);
  mountainPath.AddLine(w * 0.70f, h * 0.58f, w * 0.78f, h * 0.62f);
  mountainPath.AddLine(w * 0.78f, h * 0.62f, w * 0.85f, h * 0.52f);
  mountainPath.AddLine(w * 0.85f, h * 0.52f, w * 0.92f, h * 0.48f);
  mountainPath.AddLine(w * 0.92f, h * 0.48f, w, h * 0.40f);
  mountainPath.AddLine(w, h * 0.40f, w, h);
  mountainPath.AddLine(w, h, 0, h);
  mountainPath.CloseFigure();

  Gdiplus::LinearGradientBrush mountainGrad(
      Gdiplus::PointF(0, h * 0.3f), Gdiplus::PointF(0, h),
      Gdiplus::Color(153, 13, 26, 46), Gdiplus::Color(77, 20, 38, 64));
  g.FillPath(&mountainGrad, &mountainPath);

  // Lake reflection band
  Gdiplus::LinearGradientBrush lakeGrad(
      Gdiplus::PointF(0, h * 0.15f), Gdiplus::PointF(0, h * 0.35f),
      Gdiplus::Color(0, 46, 77, 128), Gdiplus::Color(89, 51, 89, 148));
  Gdiplus::RectF lakeRect(0, h * 0.15f, w, h * 0.20f);
  g.FillRectangle(&lakeGrad, lakeRect);

  // Light flare
  Gdiplus::GraphicsPath flarePath;
  flarePath.AddEllipse(w * 0.6f, h * 0.6f, w * 0.5f, h * 0.45f);
  Gdiplus::PathGradientBrush flareGrad(&flarePath);
  Gdiplus::Color flareCenter(30, 255, 255, 255);
  Gdiplus::Color flareSurround(0, 255, 255, 255);
  flareGrad.SetCenterColor(flareCenter);
  int count = 1;
  flareGrad.SetSurroundColors(&flareSurround, &count);
  g.FillPath(&flareGrad, &flarePath);

  // ─── DESKTOP ICONS ───
  float iconX = w - 90;
  float iconSpacing = 90;

  for (int i = 0; i < (int)m_icons.size(); i++) {
    float iconY;
    if (i == 4) {
      iconY = (float)(windowH - 110); // Trash at bottom
    } else {
      iconY = 80.0f + i * iconSpacing;
    }

    Gdiplus::RectF iconRect(iconX, iconY, 76, 85);

    // Selection highlight
    if (i == m_selectedIcon) {
      Gdiplus::SolidBrush selBrush(Gdiplus::Color(89, 64, 128, 230));
      GlassHelper::drawRoundedRect(g, iconRect, 8, &selBrush);
      Gdiplus::Pen selPen(Gdiplus::Color(128, 77, 140, 242), 1.0f);
      GlassHelper::drawRoundedRect(g, iconRect, 8, &selPen);
    }

    // Emoji icon
    Gdiplus::Font emojiFont(L"Segoe UI Emoji", 32, Gdiplus::FontStyleRegular);
    Gdiplus::SolidBrush emojiBrush(Gdiplus::Color(255, 255, 255));
    Gdiplus::StringFormat centerFmt;
    centerFmt.SetAlignment(Gdiplus::StringAlignmentCenter);
    Gdiplus::RectF emojiRect(iconX, iconY + 8, 76, 48);
    g.DrawString(m_icons[i].emoji.c_str(), -1, &emojiFont, emojiRect,
                 &centerFmt, &emojiBrush);

    // Label
    Gdiplus::Font labelFont(L"Segoe UI", 9, Gdiplus::FontStyleRegular);
    Gdiplus::SolidBrush labelBrush(Gdiplus::Color(255, 255, 255));
    Gdiplus::StringFormat labelFmt;
    labelFmt.SetAlignment(Gdiplus::StringAlignmentCenter);
    labelFmt.SetTrimming(Gdiplus::StringTrimmingEllipsisCharacter);
    Gdiplus::RectF labelRect(iconX - 10, iconY + 58, 96, 24);
    g.DrawString(m_icons[i].name.c_str(), -1, &labelFont, labelRect, &labelFmt,
                 &labelBrush);
  }
}

bool DesktopView::onClick(int x, int y, int windowW, int windowH) {
  float iconX = (float)(windowW - 90);
  float iconSpacing = 90;
  int oldSelected = m_selectedIcon;
  m_selectedIcon = -1;

  for (int i = 0; i < (int)m_icons.size(); i++) {
    float iconY;
    if (i == 4)
      iconY = (float)(windowH - 110);
    else
      iconY = 80.0f + i * iconSpacing;

    if (x >= iconX && x <= iconX + 76 && y >= iconY && y <= iconY + 85) {
      m_selectedIcon = i;
      break;
    }
  }

  if (m_selectedIcon != oldSelected) {
    InvalidateRect(m_parent, nullptr, FALSE);
    return true;
  }
  return false;
}

void DesktopView::onDoubleClick(int x, int y, int windowW, int windowH) {
  float iconX = (float)(windowW - 90);
  float iconSpacing = 90;

  for (int i = 0; i < (int)m_icons.size(); i++) {
    float iconY;
    if (i == 4)
      iconY = (float)(windowH - 110);
    else
      iconY = 80.0f + i * iconSpacing;

    if (x >= iconX && x <= iconX + 76 && y >= iconY && y <= iconY + 85) {
      App::instance().openApp(L"Finder");
      break;
    }
  }
}
