import AppKit
import SwiftUI
import WallhavenCore

struct WallpaperThumbnailView: View {
    let wallpaper: WallhavenWallpaper
    let isSelected: Bool
    let action: () -> Void

    @State private var image: NSImage?
    @State private var isLoadingImage = false
    @State private var didFailLoadingImage = false

    var body: some View {
        Button(action: action) {
            thumbnailContent
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(Rectangle())
                .overlay(alignment: .topLeading) {
                    if isSelected {
                        Text(wallpaper.tagsPreview)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    Text(wallpaper.resolution)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.58), in: Capsule())
                        .padding(6)
                }
                .overlay {
                    Rectangle()
                        .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("#\(wallpaper.id) - \(wallpaper.category) - \(wallpaper.purity)")
        .task(id: wallpaper.id) {
            await loadThumbnail()
        }
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    if didFailLoadingImage {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
        }
    }

    private func loadThumbnail() async {
        guard image == nil, !isLoadingImage else { return }

        isLoadingImage = true
        didFailLoadingImage = false

        do {
            image = try await WallpaperThumbnailImageLoader.loadImage(for: wallpaper)
        } catch is CancellationError {
        } catch {
            didFailLoadingImage = true
            WallhavenDebugLog.recordError(
                "Thumbnail image failed",
                error: error,
                details: details(for: wallpaper)
            )
        }

        isLoadingImage = false
    }

    private func details(for wallpaper: WallhavenWallpaper) -> [String: String] {
        [
            "id": wallpaper.id,
            "path": wallpaper.path.absoluteString,
            "resolution": wallpaper.resolution,
            "thumb_large": wallpaper.thumbs.large.absoluteString,
            "thumb_original": wallpaper.thumbs.original.absoluteString,
            "thumb_small": wallpaper.thumbs.small.absoluteString
        ]
    }
}

private extension WallhavenWallpaper {
    var tagsPreview: String {
        source.isEmpty ? "#\(id)" : source
    }
}
