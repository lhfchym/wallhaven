# WallhavenMac

A macOS wallpaper picker for wallhaven.cc.

The first milestone is a focused loop:

1. Open the app from the Dock or menu bar shortcut.
2. Browse a compact grid of wallpapers matched to the current Mac display.
3. Preview a wallpaper.
4. Set it as the desktop wallpaper.

## Development

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

## Current Scope

- macOS only.
- Dock app with a menu bar shortcut.
- SwiftUI + AppKit.
- wallhaven API integration.
- Automatic display-aware wallpaper matching.
- Local cache and history.
