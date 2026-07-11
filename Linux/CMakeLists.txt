cmake_minimum_required(VERSION 3.24)

project(WallhavenLinux VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.5 REQUIRED COMPONENTS Core Gui Network Qml Quick QuickControls2 DBus)

qt_standard_project_setup(REQUIRES 6.5)

qt_add_executable(WallhavenLinux
    src/main.cpp
    src/WallpaperController.cpp
    src/WallpaperController.h
)

qt_add_qml_module(WallhavenLinux
    URI Wallhaven.Linux
    VERSION 1.0
    QML_FILES
        qml/Main.qml
)

target_link_libraries(WallhavenLinux
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Network
        Qt6::Qml
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::DBus
)

install(TARGETS WallhavenLinux BUNDLE DESTINATION . RUNTIME DESTINATION bin)
install(
    FILES packaging/dev.local.WallhavenLinux.desktop
    DESTINATION share/applications
)
install(
    FILES packaging/dev.local.WallhavenLinux.svg
    DESTINATION share/icons/hicolor/scalable/apps
)
install(
    FILES packaging/dev.local.WallhavenLinux.metainfo.xml
    DESTINATION share/metainfo
)
