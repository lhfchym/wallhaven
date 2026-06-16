import AppKit
import SwiftUI
import WallhavenCore

struct WallpaperPreviewView: View {
    let wallpaper: WallhavenWallpaper?
    var height: CGFloat = 150
    var cornerRadius: CGFloat = 6
    var showsMetadata = true

    @State private var image: NSImage?
    @State private var imageWallpaperID: String?
    @State private var isLoadingImage = false
    @State private var didFailLoadingImage = false

    var body: some View {
        Group {
            if let wallpaper {
                previewContent
                    .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .allowsHitTesting(false)
                    .overlay(alignment: .bottomLeading) {
                        if showsMetadata {
                            Text("\(wallpaper.resolution) - \(formattedFileSize(wallpaper.fileSize))")
                                .font(.caption2)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 5)
                                .foregroundStyle(.white)
                                .background(.black.opacity(0.56), in: Capsule())
                                .padding(8)
                        }
                    }
                    .task(id: wallpaper.id) {
                        await loadPreview(for: wallpaper)
                    }
            } else {
                Rectangle()
                    .fill(.quaternary)
                    .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 24, weight: .regular))
                            Text("选择一张壁纸")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
            }
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    if didFailLoadingImage {
                        Image(systemName: "photo.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
        }
    }

    private func loadPreview(for wallpaper: WallhavenWallpaper) async {
        if imageWallpaperID != wallpaper.id {
            image = nil
            imageWallpaperID = wallpaper.id
        }

        isLoadingImage = true
        didFailLoadingImage = false

        do {
            image = try await WallpaperThumbnailImageLoader.loadPreviewImage(for: wallpaper)
        } catch is CancellationError {
        } catch {
            didFailLoadingImage = true
            WallhavenDebugLog.recordError(
                "Preview image failed",
                error: error,
                details: details(for: wallpaper)
            )
        }

        isLoadingImage = false
    }

    private func formattedFileSize(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
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
