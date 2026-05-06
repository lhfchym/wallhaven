# WallhavenMac Project Background

## Overview

WallhavenMac is a macOS-only wallpaper picker built around wallhaven.cc.

The product is not positioned as a general-purpose API wrapper or a command-line downloader. Its primary goal is to
make wallpaper discovery and setting feel fast, visual, and native on Mac.

The core experience should be:

1. Open the app from the Dock or menu bar shortcut.
2. Browse a compact grid of wallpapers matched to the current Mac display.
3. Pick one that feels right.
4. Preview it.
5. Set it as the desktop wallpaper.

## Product Positioning

Wallpapers are visual by nature, so the main interface should also be visual. A CLI can be useful for internal
debugging or future automation, but it should not be the primary user experience.

The app should feel like a lightweight Mac wallpaper gallery:

- Fast to open.
- Easy to scan.
- Focused on preview and selection.
- Aware of the current display resolution and aspect ratio.
- Native enough that it feels like part of the desktop workflow.

The target user wants to find a good wallpaper quickly without opening a browser, managing files, or manually checking
whether an image fits the screen.

## MVP Scope

The first product milestone is the smallest complete loop:

- macOS app with a standard Dock window and optional menu bar shortcut.
- Grid of wallhaven wallpaper thumbnails.
- Automatic matching by current display ratio and minimum resolution.
- Search keyword input.
- Basic category, purity, and sorting preferences.
- Click a thumbnail to preview.
- Download the original image.
- Set the image as the macOS desktop wallpaper.
- Local history to reduce repeated results.
- Local cache for thumbnails and original files.

Out of scope for the first milestone:

- Windows or Linux support.
- Full gallery management.
- Complex multi-display strategies.
- Image editing.
- Scheduled wallpaper rotation.
- App Store distribution.
- Large standalone browser-like UI.

## Technical Direction

The app is built with Swift, SwiftUI, and AppKit.

The project uses two main modules:

- `WallhavenCore`: API client, search request modeling, display matching, caching, and wallpaper-setting logic.
- `WallhavenMac`: macOS app shell, gallery view, preview flow, wallpaper setting, and app-level state.

The repository is SwiftPM-first so the core development loop can run from the terminal:

```sh
Scripts/dev.sh
```

Xcode project files are generated with XcodeGen:

```sh
xcodegen generate
open WallhavenMac.xcodeproj
```

Generated Xcode files are intentionally ignored by git.

## Wallhaven API Notes

The project targets wallhaven API v1.

Important search parameters for the first milestone:

- `q`: keyword search.
- `categories`: general, anime, people.
- `purity`: sfw, sketchy, nsfw.
- `sorting`: random, toplist, date_added, relevance, views, favorites.
- `ratios`: display aspect ratio.
- `atleast`: minimum display resolution.
- `page`: pagination.
- `apikey`: optional, required for private or NSFW access.

The preferred matching strategy is:

1. Use the current display's pixel resolution as the minimum resolution.
2. Use the reduced display aspect ratio for `ratios`.
3. Fetch pages of candidates and present them as a grid.
4. Avoid recently seen or already used wallpapers when possible.

## UX Principles

The app should optimize for scanning, not configuration.

Primary workflow:

- Open the app window from the Dock or menu bar.
- See a grid immediately.
- Search or adjust filters only when needed.
- Click one wallpaper to inspect it.
- Set it with one clear action.

UI guidelines:

- Keep the window compact but image-forward.
- Prefer thumbnails and visual feedback over text-heavy controls.
- Make `Refresh`, `Preview`, and `Set Wallpaper` easy to reach.
- Keep settings light in the MVP.
- Avoid turning the app into a browser clone.

## Development Milestones

### Milestone 1: Working Gallery Loop

- Fetch real search results from wallhaven.
- Display thumbnail grid.
- Support loading state and error state.
- Support keyword search.
- Support paging or refresh.

### Milestone 2: Preview and Download

- Open selected wallpaper in a larger preview.
- Download original image.
- Cache original files locally.
- Show resolution, category, purity, and source URL.

### Milestone 3: Set Wallpaper

- Set selected image as the desktop wallpaper using macOS APIs.
- Store current wallpaper metadata.
- Track history to avoid repeated picks.

### Milestone 4: Preferences

- Store API key locally.
- Store default category, purity, sorting, and keyword.
- Store cache location.

### Milestone 5: Polish

- Improve thumbnail prefetching.
- Add better empty states.
- Add basic multi-display choice if needed.
- Refine menu bar icon and popover sizing.

## Current Repository State

The initial skeleton already includes:

- SwiftPM package setup.
- XcodeGen configuration.
- SwiftFormat and SwiftLint configuration.
- `WallhavenCore` module.
- `WallhavenMac` app prototype.
- Basic display matching request tests.

The first committed baseline is:

```text
77c4cc9 Set up macOS wallhaven app skeleton
```
