import SwiftUI
import WallhavenCore

struct WallpaperPreviewView: View {
    let wallpaper: WallhavenWallpaper?

    var body: some View {
        Group {
            if let wallpaper {
                AsyncImage(url: wallpaper.thumbs.original) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        Rectangle()
                            .fill(.quaternary)
                            .overlay {
                                Image(systemName: "photo.badge.exclamationmark")
                                    .foregroundStyle(.secondary)
                            }
                    case .empty:
                        Rectangle()
                            .fill(.quaternary)
                            .overlay {
                                ProgressView()
                                    .controlSize(.small)
                            }
                    @unknown default:
                        Rectangle()
                            .fill(.quaternary)
                    }
                }
                .frame(height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .bottomLeading) {
                    Text("\(wallpaper.resolution) - \(formattedFileSize(wallpaper.fileSize))")
                        .font(.caption2)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .foregroundStyle(.white)
                        .background(.black.opacity(0.56), in: Capsule())
                        .padding(8)
                }
            }
        }
    }

    private func formattedFileSize(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}
