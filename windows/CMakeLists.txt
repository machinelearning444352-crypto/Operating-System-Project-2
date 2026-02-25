cmake_minimum_required(VERSION 3.15)
project(VirtualOS_Windows LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# GDI+ and Win32 libraries
set(WIN32_LIBS
    gdi32
    gdiplus
    user32
    comctl32
    dwmapi
    uxtheme
    ole32
    shell32
    comdlg32
)

# Collect all source files
file(GLOB_RECURSE SOURCES "src/*.cpp")
file(GLOB_RECURSE HEADERS "src/*.h")

# Create Windows GUI application (WIN32 flag prevents console window)
add_executable(VirtualOS WIN32 ${SOURCES} ${HEADERS})

target_link_libraries(VirtualOS PRIVATE ${WIN32_LIBS})

# Enable DPI awareness
target_compile_definitions(VirtualOS PRIVATE
    UNICODE
    _UNICODE
    WIN32_LEAN_AND_MEAN
    NOMINMAX
)
