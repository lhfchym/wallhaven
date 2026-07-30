cmake_minimum_required(VERSION 3.24)

project(WallhavenWindows VERSION 0.1.0 LANGUAGES CXX RC)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.8 REQUIRED COMPONENTS Core Gui Network Qml Quick QuickControls2 Widgets)

qt_standard_project_setup(REQUIRES 6.8)

set(WALLHAVEN_ICON_PATH "${CMAKE_CURRENT_SOURCE_DIR}/assets/wallhaven-icon.ico")
file(SHA256 "${WALLHAVEN_ICON_PATH}" WALLHAVEN_ICON_HASH)
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/src/resources.rc.in"
    "${CMAKE_CURRENT_BINARY_DIR}/resources.rc"
    @ONLY
)

qt_add_executable(WallhavenWindows WIN32
    "${CMAKE_CURRENT_BINARY_DIR}/resources.rc"
    src/main.cpp
    src/WallpaperController.cpp
    src/WallpaperController.h
    src/WindowsCredentialStore.cpp
    src/WindowsCredentialStore.h
    src/WindowsDesktopWallpaperService.cpp
    src/WindowsDesktopWallpaperService.h
)

qt_add_qml_module(WallhavenWindows
    URI Wallhaven.Windows
    VERSION 1.0
    QML_FILES
        qml/Main.qml
)

qt_add_resources(WallhavenWindows "wallhaven_assets"
    PREFIX "/"
    BASE "${CMAKE_CURRENT_SOURCE_DIR}/assets"
    FILES
        "${CMAKE_CURRENT_SOURCE_DIR}/assets/wallhaven-icon.png"
)

target_link_libraries(WallhavenWindows
    PRIVATE
        Qt6::Core
        Qt6::Gui
        Qt6::Network
        Qt6::Qml
        Qt6::Quick
        Qt6::QuickControls2
        Qt6::Widgets
        Advapi32
        Ole32
)

install(TARGETS WallhavenWindows BUNDLE DESTINATION . RUNTIME DESTINATION bin)
install(FILES "${WALLHAVEN_ICON_PATH}" DESTINATION bin)

qt_generate_deploy_qml_app_script(
    TARGET WallhavenWindows
    OUTPUT_SCRIPT deploy_script
    NO_TRANSLATIONS
)
install(SCRIPT ${deploy_script})
