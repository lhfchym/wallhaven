import SwiftUI
import WallhavenCore

struct WallpaperGalleryView: View {
    @StateObject private var viewModel = WallpaperGalleryViewModel()

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 12) {
            header
            searchBar
            preview
            gallery
            footer
        }
        .padding(14)
        .frame(minWidth: 520, minHeight: 620)
        .task {
            viewModel.loadInitialWallpapers()
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Wallhaven")
                    .font(.headline)
                Text(viewModel.statusText)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                viewModel.refresh()
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Refresh")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("Search wallpapers", text: $viewModel.query)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.submitSearch()
                }

            Button("Search") {
                viewModel.submitSearch()
            }
            .disabled(viewModel.isLoading)
        }
    }

    private var gallery: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(viewModel.wallpapers) { wallpaper in
                    WallpaperThumbnailView(
                        wallpaper: wallpaper,
                        isSelected: viewModel.selectedWallpaper?.id == wallpaper.id
                    ) {
                        viewModel.select(wallpaper)
                    }
                }

                if viewModel.canLoadMore {
                    Button {
                        viewModel.loadNextPage()
                    } label: {
                        Text(viewModel.isLoading ? "Loading..." : "Load More")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLoading)
                    .gridCellColumns(columns.count)
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 2)
        }
        .overlay {
            if viewModel.wallpapers.isEmpty {
                ContentUnavailableView(
                    viewModel.isLoading ? "Loading Wallpapers" : "No Wallpapers",
                    systemImage: viewModel.isLoading ? "photo.stack" : "photo",
                    description: Text(viewModel.errorMessage ?? "Try another search or refresh.")
                )
            }
        }
    }

    private var preview: some View {
        Group {
            if let wallpaper = viewModel.selectedWallpaper {
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

    private var footer: some View {
        HStack(spacing: 10) {
            if let wallpaper = viewModel.selectedWallpaper {
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

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(1)
            } else if let message = viewModel.successMessage {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("Open") {
                if let url = viewModel.selectedWallpaper?.url {
                    NSWorkspace.shared.open(url)
                }
            }
            .disabled(viewModel.selectedWallpaper == nil)

            Button {
                viewModel.downloadSelectedWallpaper()
            } label: {
                if viewModel.isDownloading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(viewModel.downloadedWallpaperURL == nil ? "Download" : "Downloaded")
                }
            }
            .disabled(viewModel.selectedWallpaper == nil || viewModel.isDownloading)

            Button {
                viewModel.setSelectedWallpaper()
            } label: {
                if viewModel.isSettingWallpaper {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Set Wallpaper")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(viewModel.selectedWallpaper == nil || viewModel.isSettingWallpaper)
        }
    }

    private func formattedFileSize(_ byteCount: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
    }
}

private struct WallpaperThumbnailView: View {
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
