# Windows Build (Win32 + GDI+)

## Requirements
- Windows 10/11
- Visual Studio 2019+ or MSYS2/MinGW with CMake
- CMake 3.15+

## Build with Visual Studio
```powershell
cd windows
mkdir build && cd build
cmake .. -G "Visual Studio 17 2022"
cmake --build . --config Release
```

## Build with MinGW
```bash
cd windows
mkdir build && cd build
cmake .. -G "MinGW Makefiles"
cmake --build .
```

## Architecture
- **App** — Main window, GDI+ rendering, event dispatch
- **views/** — MenuBar (Liquid Glass), Dock (magnification), Desktop (Tahoe wallpaper)
- **windows/** — BaseWindow class + app windows (Finder, Settings, Terminal)

All rendering uses **GDI+** for anti-aliased drawing. Windows 11 features (rounded corners, DWM) are used when available.
