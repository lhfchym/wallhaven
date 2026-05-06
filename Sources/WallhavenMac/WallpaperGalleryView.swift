import SwiftUI
import WallhavenCore

struct WallpaperGalleryView: View {
    @StateObject private var viewModel = WallpaperGalleryViewModel()
    @State private var isShowingSettings = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        VStack(spacing: 12) {
            header
            searchBar
            filterBar
            WallpaperPreviewView(wallpaper: viewModel.selectedWallpaper)
            gallery
            WallpaperActionFooterView(
                wallpaper: viewModel.selectedWallpaper,
                errorMessage: viewModel.errorMessage,
                successMessage: viewModel.successMessage,
                isDownloading: viewModel.isDownloading,
                isSettingWallpaper: viewModel.isSettingWallpaper,
                downloadedWallpaperURL: viewModel.downloadedWallpaperURL,
                onDownload: viewModel.downloadSelectedWallpaper,
                onSetWallpaper: viewModel.setSelectedWallpaper
            )
        }
        .padding(14)
        .frame(minWidth: 520, minHeight: 620)
        .task {
            viewModel.loadInitialWallpapers()
        }
        .sheet(isPresented: $isShowingSettings) {
            WallhavenSettingsView(
                apiKey: viewModel.preferences.apiKey,
                onSave: { apiKey in
                    viewModel.updateAPIKey(apiKey)
                    isShowingSettings = false
                },
                onCancel: {
                    isShowingSettings = false
                }
            )
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

            WallhavenActionButton(
                role: .primary,
                isDisabled: viewModel.isLoading
            ) {
                viewModel.refresh()
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Refresh")
                }
            }

            WallhavenActionButton(role: .icon) {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .help("Settings")
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            TextField("Search wallpapers", text: $viewModel.query)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.submitSearch()
                }

            WallhavenActionButton(isDisabled: viewModel.isLoading) {
                viewModel.submitSearch()
            } label: {
                Text("Search")
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Picker("Category", selection: categoryBinding) {
                ForEach(WallhavenCategoryPreset.allCases) { category in
                    Text(category.label).tag(category)
                }
            }
            .labelsHidden()
            .frame(width: 120)

            Picker("Purity", selection: purityBinding) {
                ForEach(WallhavenPurityPreset.allCases) { purity in
                    Text(purity.label).tag(purity)
                }
            }
            .labelsHidden()
            .frame(width: 145)

            Picker("Sorting", selection: sortingBinding) {
                ForEach(WallhavenSorting.allCases) { sorting in
                    Text(sorting.label).tag(sorting)
                }
            }
            .labelsHidden()
            .frame(width: 130)

            Spacer()

            if !viewModel.preferences.apiKey.isEmpty {
                Label("API Key", systemImage: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .labelStyle(.iconOnly)
                    .help("API key configured")
            }
        }
    }

    private var categoryBinding: Binding<WallhavenCategoryPreset> {
        Binding(
            get: { viewModel.preferences.categories },
            set: { viewModel.updateCategory($0) }
        )
    }

    private var purityBinding: Binding<WallhavenPurityPreset> {
        Binding(
            get: { viewModel.preferences.purity },
            set: { viewModel.updatePurity($0) }
        )
    }

    private var sortingBinding: Binding<WallhavenSorting> {
        Binding(
            get: { viewModel.preferences.sorting },
            set: { viewModel.updateSorting($0) }
        )
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
                    WallhavenActionButton(isDisabled: viewModel.isLoading) {
                        viewModel.loadNextPage()
                    } label: {
                        Text(viewModel.isLoading ? "Loading..." : "Load More")
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
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
}
