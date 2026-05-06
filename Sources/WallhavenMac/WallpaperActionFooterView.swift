import SwiftUI
import WallhavenCore

struct WallpaperActionFooterView: View {
    let wallpaper: WallhavenWallpaper?
    let errorMessage: String?
    let successMessage: String?
    let isDownloading: Bool
    let isSettingWallpaper: Bool
    let downloadedWallpaperURL: URL?
    let onDownload: () -> Void
    let onSetWallpaper: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            selectionSummary
            statusMessage

            Spacer()

            WallhavenActionButton(isDisabled: wallpaper == nil) {
                if let url = wallpaper?.url {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Text("Open")
            }

            WallhavenActionButton(isDisabled: wallpaper == nil || isDownloading, action: onDownload) {
                if isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(downloadedWallpaperURL == nil ? "Download" : "Downloaded")
                }
            }

            WallhavenActionButton(
                role: .primary,
                isDisabled: wallpaper == nil || isSettingWallpaper,
                action: onSetWallpaper
            ) {
                if isSettingWallpaper {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Set Wallpaper")
                }
            }
            .keyboardShortcut(.defaultAction)
        }
    }

    private var selectionSummary: some View {
        Group {
            if let wallpaper {
                VStack(alignment: .leading, spacing: 2) {
                    Text(wallpaper.resolution)
                        .font(.caption)
                    Text("#\(wallpaper.id) - \(wallpaper.category) - \(wallpaper.purity)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Select a wallpaper")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(1)
        } else if let successMessage {
            Text(successMessage)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
