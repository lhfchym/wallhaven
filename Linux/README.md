# Wallhaven Linux

The Linux client targets Kubuntu 26.04 LTS running KDE Plasma on Wayland. It is a separate Qt 6 / QML application so the existing macOS SwiftUI client remains intact.

## Build

```sh
cmake -S Linux -B Linux/build -G Ninja
cmake --build Linux/build
Linux/build/WallhavenLinux
```

The application calls Plasma's session D-Bus interface directly to set the downloaded wallpaper across the current Plasma session's desktops. It must be launched from the graphical Plasma session.

## Current milestone

- Wallhaven search with category, purity, sorting and display-resolution filtering.
- Thumbnail grid and full selection preview.
- Download to `~/Pictures/WallhavenLinux`.
- Apply a downloaded image through KDE Plasma's D-Bus wallpaper service.
- Bluecurve-inspired, original QML visual system.

Later milestones add the downloaded-wallpaper gallery, persistent preferences, API key storage, Portal fallback and Flatpak packaging.
