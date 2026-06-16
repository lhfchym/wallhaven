import AppKit
import SwiftUI

struct DownloadedWallpaperPreviewView: View {
    let wallpaper: DownloadedWallpaper?
    var height: CGFloat = 150
    var cornerRadius: CGFloat = 6
    var emptyTitle = "Select a wallpaper"

    @State private var image: NSImage?
    @State private var imageURL: URL?
    @State private var didFailLoadingImage = false

    var body: some View {
        GeometryReader { proxy in
            Group {
                if let wallpaper {
                    previewContent
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .task(id: wallpaper.id) {
                            await loadImage(for: wallpaper)
                        }
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                        .overlay {
                            VStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 24, weight: .regular))
                                Text(emptyTitle)
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
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

    private func loadImage(for wallpaper: DownloadedWallpaper) async {
        if imageURL != wallpaper.url {
            image = nil
            imageURL = wallpaper.url
        }

        if let loadedImage = NSImage(contentsOf: wallpaper.url) {
            image = loadedImage
            didFailLoadingImage = false
        } else {
            didFailLoadingImage = true
        }
    }
}
