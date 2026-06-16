import AppKit
import SwiftUI

struct DownloadedWallpaperThumbnailView: View {
    let wallpaper: DownloadedWallpaper
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    @State private var image: NSImage?
    @State private var didFailLoadingImage = false

    var body: some View {
        Button(action: onSelect) {
            thumbnailContent
                .aspectRatio(16 / 9, contentMode: .fit)
                .clipShape(Rectangle())
                .overlay(alignment: .bottomTrailing) {
                    if wallpaper.resolution != nil {
                        Text(wallpaper.displayResolution)
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .foregroundStyle(.white)
                            .background(.black.opacity(0.58), in: Capsule())
                            .padding(6)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                    .help("Delete")
                }
                .overlay {
                    Rectangle()
                        .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(wallpaper.fileName)
        .task(id: wallpaper.id) {
            await loadImage()
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
                        Image(systemName: "photo.badge.exclamationmark")
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
        }
    }

    private func loadImage() async {
        guard image == nil else { return }

        if let loadedImage = NSImage(contentsOf: wallpaper.url) {
            image = loadedImage
        } else {
            didFailLoadingImage = true
        }
    }
}
