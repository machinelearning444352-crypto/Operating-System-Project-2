#include "App.h"

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE, LPWSTR, int) {
  // Enable DPI awareness
  SetProcessDPIAware();

  // Initialize common controls (for modern look)
  INITCOMMONCONTROLSEX icc = {};
  icc.dwSize = sizeof(icc);
  icc.dwICC = ICC_STANDARD_CLASSES | ICC_BAR_CLASSES;
  InitCommonControlsEx(&icc);

  App &app = App::instance();
  app.initialize(hInstance);

  // Start clock timer (1 second interval)
  SetTimer(app.getMainWindow(), 1, 1000, nullptr);

  return app.run();
}
