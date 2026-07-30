# Wallhaven

Wallhaven wallpaper browser for macOS, KDE Plasma on Linux, and Windows.

- `Sources/` contains the original macOS SwiftUI client.
- `Linux/` contains the Qt 6 / QML client for Kubuntu 26.04 LTS, KDE Plasma and Wayland.
- `Windows/` contains the Qt 6 / QML client using Windows desktop and credential APIs.

The first milestone is a focused loop:

1. Open the app from the Dock or menu bar shortcut.
2. Browse a compact grid of wallpapers matched to the current Mac display.
3. Preview a wallpaper.
4. Set it as the desktop wallpaper.

## macOS development

This project is intentionally SwiftPM-first, so the early prototype can build without a full Xcode project.

```sh
swift build
swift test
swift run WallhavenMac
```

To refresh the Launchpad/Xcode `.app` entry, regenerate and build the Xcode project:

```sh
xcodegen generate
xcodebuild -project WallhavenMac.xcodeproj -scheme WallhavenMac -configuration Debug build
```

To build a local test DMG:

```sh
Scripts/package_dmg.sh
```

The DMG is written to `dist/` using the version in `project.yml`. This local test build is signed for local
running, not notarized.

By default, packaging increments the patch component of `MARKETING_VERSION` and mirrors it to
`CURRENT_PROJECT_VERSION`. For example, `0.1.1` becomes `0.1.2`; after manually setting `0.2.0`,
the next package build becomes `0.2.1`.

Useful local tools:

```sh
swiftformat .
```

SwiftLint is configured in the repo, but installing it through Homebrew currently requires full Xcode on this
machine. Full Xcode is still recommended for day-to-day SwiftUI work. If Xcode is installed later, run:

```sh
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
brew install swiftlint
xcodegen generate
```

## macOS scope

- macOS only.
- Dock app with a menu bar shortcut.
- SwiftUI + AppKit.
- wallhaven API integration.
- Automatic display-aware wallpaper matching.
- Local cache and history.

## Linux: Kubuntu / KDE Plasma

The Linux client is a separate Qt 6 / QML application designed for KDE Plasma on Wayland. Its visual layer is Bluecurve-inspired and uses the active Bluecurve icon theme for action buttons when that theme is selected in Plasma.

```sh
cmake -S Linux -B Linux/build -G Ninja
cmake --build Linux/build
Linux/build/WallhavenLinux
```

The application should be launched from the graphical Plasma session. It supports display-aware Wallhaven search, Chinese/English UI, KDE Wallet API-key storage, downloaded-wallpaper management, automatic next-page loading that preserves the gallery position, Plasma wallpaper application, and an XDG Wallpaper Portal fallback.

For Flatpak installation and further Linux details, see [Linux/README.md](Linux/README.md).
