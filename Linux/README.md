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
- Quick navigation for Toplist, Latest, Favorites and the downloaded-wallpaper library.
- Pagination, refresh, source-page opening, local deletion and re-applying downloaded wallpapers.
- Thumbnail grid and full selection preview.
- Download to `~/Pictures/WallhavenLinux`.
- Apply a downloaded image through KDE Plasma's D-Bus wallpaper service.
- Persistent search, display-fit and download-directory preferences.
- Bluecurve-inspired, original QML visual system.

The API key is stored in KDE Wallet; direct Plasma D-Bus wallpaper setting falls back to the XDG Wallpaper Portal when necessary.

## Flatpak

The Flatpak build uses the KDE runtime and XDG Wallpaper Portal, so a sandboxed install can request wallpaper changes without direct access to Plasma's private D-Bus service.

```sh
flatpak-builder --user --install --force-clean build-flatpak Linux/packaging/dev.local.WallhavenLinux.yml
flatpak run dev.local.WallhavenLinux
```
