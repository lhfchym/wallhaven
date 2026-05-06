import SwiftUI
import WallhavenCore

struct WallpaperThumbnailView: View {
    let wallpaper: WallhavenWallpaper
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AsyncImage(url: wallpaper.thumbs.large) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "exclamationmark.triangle")
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
            .frame(height: 92)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(alignment: .bottomLeading) {
                Text(wallpaper.resolution)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .foregroundStyle(.white)
                    .background(.black.opacity(0.54), in: Capsule())
                    .padding(6)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 3)
            }
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help("#\(wallpaper.id) - \(wallpaper.category) - \(wallpaper.purity)")
    }
}
