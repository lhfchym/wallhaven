import AppKit
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
        HStack(spacing: 0) {
            sidebar
                .frame(width: 250)

            Divider()

            gallery
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))

            Divider()

            inspector
                .frame(width: 300)
        }
        .frame(minWidth: 1160, minHeight: 720)
        .background(Color(nsColor: .controlBackgroundColor))
        .task {
            viewModel.loadInitialWallpapers()
        }
        .sheet(isPresented: $isShowingSettings) {
            WallhavenSettingsView(
                apiKey: viewModel.preferences.apiKey,
                downloadDirectoryPath: viewModel.preferences.downloadDirectoryPath,
                strictAspectRatio: viewModel.preferences.strictAspectRatio,
                language: viewModel.preferences.language,
                defaultDownloadDirectoryURL: viewModel.downloadDirectoryURL,
                onSave: { apiKey, downloadDirectoryPath, strictAspectRatio, language in
                    viewModel.updateSettings(
                        apiKey: apiKey,
                        downloadDirectoryPath: downloadDirectoryPath,
                        strictAspectRatio: strictAspectRatio,
                        language: language
                    )
                    isShowingSettings = false
                },
                onCancel: {
                    isShowingSettings = false
                }
            )
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            searchField

            VStack(spacing: 6) {
                SidebarNavigationButton(
                    title: copy.hottest,
                    systemImageName: "sparkles",
                    isSelected: viewModel.selectedSection == .online && viewModel.preferences.sorting == .toplist
                ) {
                    viewModel.updateSorting(.toplist)
                }

                SidebarNavigationButton(
                    title: copy.latest,
                    systemImageName: "clock",
                    isSelected: viewModel.selectedSection == .online && viewModel.preferences.sorting == .dateAdded
                ) {
                    viewModel.updateSorting(.dateAdded)
                }

                SidebarNavigationButton(
                    title: copy.favoriteRanking,
                    systemImageName: "star",
                    isSelected: viewModel.selectedSection == .online && viewModel.preferences.sorting == .favorites
                ) {
                    viewModel.updateSorting(.favorites)
                }

                SidebarNavigationButton(
                    title: copy.downloaded,
                    systemImageName: "arrow.down.square",
                    isSelected: viewModel.selectedSection == .downloaded
                ) {
                    viewModel.showDownloadedWallpapers()
                }
            }

            sidebarSection(title: copy.categoryAndPurity) {
                Picker(copy.category, selection: categoryBinding) {
                    ForEach(WallhavenCategoryPreset.allCases) { category in
                        Text(copy.categoryLabel(category)).tag(category)
                    }
                }
                .labelsHidden()

                Picker(copy.purity, selection: purityBinding) {
                    ForEach(WallhavenPurityPreset.allCases) { purity in
                        Text(copy.purityLabel(purity)).tag(purity)
                    }
                }
                .labelsHidden()
            }

            sidebarSection(title: copy.sorting) {
                Picker(copy.sorting, selection: sortingBinding) {
                    ForEach(WallhavenSorting.allCases) { sorting in
                        Text(copy.sortingLabel(sorting)).tag(sorting)
                    }
                }
                .labelsHidden()
            }

            MacActionButton(viewModel.isLoading ? copy.refreshing : copy.refreshData, isDisabled: viewModel.isLoading) {
                viewModel.refresh()
            }
            .frame(height: 34)

            if !viewModel.preferences.apiKey.isEmpty {
                Label(copy.apiKeyConfigured, systemImage: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, -6)
            }

            Spacer()

            MacActionButton(systemImageName: "gearshape") {
                isShowingSettings = true
            }
            .frame(width: 42, height: 34)
            .help(copy.settingsHelp)
        }
        .padding(18)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)

            TextField(copy.searchPlaceholder, text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .onSubmit {
                    viewModel.submitSearch()
                }
        }
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.separator.opacity(0.65), lineWidth: 1)
        }
    }

    private func sidebarSection(
        title: String,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                content()
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator.opacity(0.5), lineWidth: 1)
            }
        }
    }

    private var gallery: some View {
        ScrollView {
            galleryGrid
        }
        .overlay {
            galleryEmptyState
        }
        .safeAreaInset(edge: .bottom) {
            galleryBottomBar
        }
    }

    @ViewBuilder
    private var galleryGrid: some View {
        switch viewModel.selectedSection {
        case .online:
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(viewModel.wallpapers) { wallpaper in
                    WallpaperThumbnailView(
                        wallpaper: wallpaper,
                        isSelected: viewModel.selectedWallpaper?.id == wallpaper.id
                    ) {
                        viewModel.select(wallpaper)
                    }
                }

                if !viewModel.wallpapers.isEmpty, viewModel.canLoadMore || viewModel.isLoading {
                    autoLoadMoreFooter
                        .gridCellColumns(columns.count)
                        .padding(.top, 4)
                }
            }
            .padding(10)
        case .downloaded:
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(viewModel.downloadedWallpapers) { wallpaper in
                    DownloadedWallpaperThumbnailView(
                        wallpaper: wallpaper,
                        isSelected: viewModel.selectedDownloadedWallpaper?.id == wallpaper.id,
                        onSelect: {
                            viewModel.select(wallpaper)
                        },
                        onDelete: {
                            viewModel.deleteDownloadedWallpaper(wallpaper)
                        }
                    )
                }
            }
            .padding(10)
        }
    }

    @ViewBuilder
    private var galleryEmptyState: some View {
        switch viewModel.selectedSection {
        case .online:
            if viewModel.wallpapers.isEmpty {
                ContentUnavailableView(
                    viewModel.isLoading ? copy.loadingWallpapers : copy.noWallpapers,
                    systemImage: viewModel.isLoading ? "photo.stack" : "photo",
                    description: Text(viewModel.errorMessage ?? copy.emptyGalleryHelp)
                )
            }
        case .downloaded:
            if viewModel.downloadedWallpapers.isEmpty {
                ContentUnavailableView(
                    viewModel.isLoading ? copy.loadingWallpapers : copy.noDownloadedWallpapers,
                    systemImage: viewModel.isLoading ? "photo.stack" : "tray",
                    description: Text(viewModel.errorMessage ?? copy.emptyDownloadedHelp)
                )
            }
        }
    }

    private var galleryBottomBar: some View {
        HStack(spacing: 14) {
            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)

            Spacer()

            MacActionButton(copy.refresh, isDisabled: viewModel.isLoading) {
                viewModel.refresh()
            }
            .frame(width: 84, height: 32)

            if viewModel.selectedSection == .online {
                MacActionButton(copy.nextPage, isDisabled: !viewModel.canLoadMore || viewModel.isLoading) {
                    viewModel.loadNextPage()
                }
                .frame(width: 84, height: 32)
            } else {
                MacActionButton(copy.openDownloadFolder) {
                    viewModel.openDownloadDirectory()
                }
                .frame(width: 128, height: 32)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.black.opacity(0.62))
    }

    private var autoLoadMoreFooter: some View {
        HStack(spacing: 8) {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
                Text(copy.loadingMoreWallpapers)
            } else {
                Image(systemName: "arrow.down")
                Text(copy.scrollToLoadMore)
            }
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, minHeight: 38)
        .onAppear {
            guard viewModel.canLoadMore else { return }
            viewModel.loadNextPage()
        }
    }

    private var inspector: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(copy.displayPreviewTitle)
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .center)

            displayPreview

            selectionPanel

            statusPanel

            Spacer()

            MacActionButton(copy.feedback) {
                if let url = URL(string: "https://github.com") {
                    NSWorkspace.shared.open(url)
                }
            }
            .frame(height: 30)
            .opacity(0.75)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
    }

    private var displayPreview: some View {
        GeometryReader { proxy in
            ZStack {
                previewImage
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()

                let displayRatio = CGFloat(viewModel.display.pixelWidth) / CGFloat(max(
                    viewModel.display.pixelHeight,
                    1
                ))
                let previewWidth = min(proxy.size.width * 0.78, proxy.size.height * displayRatio * 0.78)
                let previewHeight = previewWidth / displayRatio

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor.opacity(0.72))
                    .frame(width: previewWidth, height: previewHeight)
                    .overlay(alignment: .top) {
                        Text(copy.builtInDisplay)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.top, 7)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 1)
                            .stroke(.red, lineWidth: 2)
                    }
                    .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 146)
        .background(Color.black)
        .clipped()
        .overlay {
            Rectangle()
                .stroke(.separator.opacity(0.45), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var previewImage: some View {
        switch viewModel.selectedSection {
        case .online:
            WallpaperPreviewView(
                wallpaper: viewModel.selectedWallpaper,
                height: 146,
                cornerRadius: 0,
                showsMetadata: false,
                emptyTitle: copy.selectWallpaper
            )
        case .downloaded:
            DownloadedWallpaperPreviewView(
                wallpaper: viewModel.selectedDownloadedWallpaper,
                height: 146,
                cornerRadius: 0,
                emptyTitle: copy.selectWallpaper
            )
        }
    }

    private var selectionPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(copy.selectedWallpaper)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 9) {
                selectionPanelContent
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(nsColor: .windowBackgroundColor).opacity(0.62), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.separator.opacity(0.5), lineWidth: 1)
            }
        }
    }

    @ViewBuilder
    private var selectionPanelContent: some View {
        switch viewModel.selectedSection {
        case .online:
            onlineSelectionPanelContent
        case .downloaded:
            downloadedSelectionPanelContent
        }
    }

    @ViewBuilder
    private var onlineSelectionPanelContent: some View {
        if let wallpaper = viewModel.selectedWallpaper {
            VStack(spacing: 3) {
                Text(wallpaper.tagsPreview)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                Text(wallpaper.resolution)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            MacActionButton(
                viewModel.downloadedWallpaperURL == nil ? copy.download : copy.revealInFinder,
                isDisabled: viewModel.isDownloading
            ) {
                if let downloadedWallpaperURL = viewModel.downloadedWallpaperURL {
                    NSWorkspace.shared.activateFileViewerSelecting([downloadedWallpaperURL])
                } else {
                    viewModel.downloadSelectedWallpaper()
                }
            }
            .frame(height: 34)

            MacActionButton(
                viewModel.isSettingWallpaper ? copy.settingWallpaper : copy.setWallpaper,
                isDisabled: viewModel.isDownloading || viewModel.isSettingWallpaper
            ) {
                viewModel.setSelectedWallpaper()
            }
            .frame(height: 34)

            HStack(spacing: 10) {
                MacActionButton(copy.openPage) {
                    NSWorkspace.shared.open(wallpaper.url)
                }
                .frame(height: 32)

                Text("\(wallpaper.category) / \(wallpaper.purity)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            selectionEmptyText
        }
    }

    @ViewBuilder
    private var downloadedSelectionPanelContent: some View {
        if let wallpaper = viewModel.selectedDownloadedWallpaper {
            VStack(spacing: 3) {
                Text(wallpaper.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)

                Text(wallpaper.displayResolution)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(copy.downloadedStatus)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 28)

            MacActionButton(
                viewModel.isSettingWallpaper ? copy.settingWallpaper : copy.setWallpaper,
                isDisabled: viewModel.isSettingWallpaper || viewModel.isDeletingDownloadedWallpaper
            ) {
                viewModel.setSelectedDownloadedWallpaper()
            }
            .frame(height: 34)

            MacActionButton(copy.showInFinder) {
                viewModel.revealSelectedDownloadedWallpaper()
            }
            .frame(height: 32)
        } else {
            selectionEmptyText
        }
    }

    private var selectionEmptyText: some View {
        Text(copy.selectWallpaperFromGallery)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 86)
    }

    @ViewBuilder
    private var statusPanel: some View {
        if let errorMessage = viewModel.errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(2)
        } else if let successMessage = viewModel.successMessage {
            Label(successMessage, systemImage: "checkmark.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
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

    private var copy: WallhavenCopy {
        WallhavenCopy(language: viewModel.preferences.language)
    }
}

private struct SidebarNavigationButton: View {
    let title: String
    let systemImageName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImageName)
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 16, weight: .semibold))

                Spacer()
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(height: 42)
            .background(isSelected ? Color.primary.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

private extension WallhavenWallpaper {
    var tagsPreview: String {
        source.isEmpty ? "#\(id)" : source
    }
}
