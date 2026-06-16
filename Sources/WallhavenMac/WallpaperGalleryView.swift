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
                defaultDownloadDirectoryURL: viewModel.downloadDirectoryURL,
                onSave: { apiKey, downloadDirectoryPath, strictAspectRatio in
                    viewModel.updateSettings(
                        apiKey: apiKey,
                        downloadDirectoryPath: downloadDirectoryPath,
                        strictAspectRatio: strictAspectRatio
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
                    title: "最热",
                    systemImageName: "sparkles",
                    isSelected: viewModel.preferences.sorting == .toplist
                ) {
                    viewModel.updateSorting(.toplist)
                }

                SidebarNavigationButton(
                    title: "最新",
                    systemImageName: "clock",
                    isSelected: viewModel.preferences.sorting == .dateAdded
                ) {
                    viewModel.updateSorting(.dateAdded)
                }

                SidebarNavigationButton(
                    title: "收藏排行",
                    systemImageName: "star",
                    isSelected: viewModel.preferences.sorting == .favorites
                ) {
                    viewModel.updateSorting(.favorites)
                }

                SidebarNavigationButton(
                    title: "已下载",
                    systemImageName: "arrow.down.square",
                    isSelected: false
                ) {
                    viewModel.openDownloadDirectory()
                }
            }

            sidebarSection(title: "分类&色调") {
                Picker("分类", selection: categoryBinding) {
                    ForEach(WallhavenCategoryPreset.allCases) { category in
                        Text(category.localizedLabel).tag(category)
                    }
                }
                .labelsHidden()

                Picker("色调", selection: purityBinding) {
                    ForEach(WallhavenPurityPreset.allCases) { purity in
                        Text(purity.localizedLabel).tag(purity)
                    }
                }
                .labelsHidden()
            }

            sidebarSection(title: "排序") {
                Picker("排序", selection: sortingBinding) {
                    ForEach(WallhavenSorting.allCases) { sorting in
                        Text(sorting.localizedLabel).tag(sorting)
                    }
                }
                .labelsHidden()
            }

            MacActionButton(viewModel.isLoading ? "刷新中..." : "刷新数据", isDisabled: viewModel.isLoading) {
                viewModel.refresh()
            }
            .frame(height: 34)

            if !viewModel.preferences.apiKey.isEmpty {
                Label("API Key 已配置", systemImage: "key.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, -6)
            }

            Spacer()

            MacActionButton(systemImageName: "gearshape") {
                isShowingSettings = true
            }
            .frame(width: 42, height: 34)
            .help("设置")
        }
        .padding(18)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("今日搜索热门\"地球\"", text: $viewModel.query)
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
        }
        .overlay {
            if viewModel.wallpapers.isEmpty {
                ContentUnavailableView(
                    viewModel.isLoading ? "正在加载壁纸" : "没有壁纸",
                    systemImage: viewModel.isLoading ? "photo.stack" : "photo",
                    description: Text(viewModel.errorMessage ?? "换个关键词或者刷新试试。")
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            galleryBottomBar
        }
    }

    private var galleryBottomBar: some View {
        HStack(spacing: 14) {
            Text(viewModel.statusText)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)

            Spacer()

            MacActionButton("刷新", isDisabled: viewModel.isLoading) {
                viewModel.refresh()
            }
            .frame(width: 84, height: 32)

            MacActionButton("下一页", isDisabled: !viewModel.canLoadMore || viewModel.isLoading) {
                viewModel.loadNextPage()
            }
            .frame(width: 84, height: 32)
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
                Text("正在加载更多壁纸...")
            } else {
                Image(systemName: "arrow.down")
                Text("继续滚动加载")
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
            Text("显示器结构预览")
                .font(.system(size: 16, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .center)

            displayPreview

            selectionPanel

            statusPanel

            Spacer()

            MacActionButton("意见反馈") {
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
        ZStack {
            WallpaperPreviewView(
                wallpaper: viewModel.selectedWallpaper,
                height: 146,
                cornerRadius: 0,
                showsMetadata: false
            )

            GeometryReader { proxy in
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
                        Text("内建视网膜显示器")
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
        .frame(height: 146)
        .background(Color.black)
        .overlay {
            Rectangle()
                .stroke(.separator.opacity(0.45), lineWidth: 1)
        }
    }

    private var selectionPanel: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("选中的壁纸")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 9) {
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
                        viewModel.downloadedWallpaperURL == nil ? "下载" : "在 Finder 中显示",
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
                        viewModel.isSettingWallpaper ? "设置中..." : "设置为壁纸",
                        isDisabled: viewModel.isDownloading || viewModel.isSettingWallpaper
                    ) {
                        viewModel.setSelectedWallpaper()
                    }
                    .frame(height: 34)

                    HStack(spacing: 10) {
                        MacActionButton("打开页面") {
                            NSWorkspace.shared.open(wallpaper.url)
                        }
                        .frame(height: 32)

                        Text("\(wallpaper.category) / \(wallpaper.purity)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                } else {
                    Text("从中间选择一张壁纸")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 86)
                }
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

private extension WallhavenCategoryPreset {
    var localizedLabel: String {
        switch self {
        case .general:
            "普通"
        case .anime:
            "动漫"
        case .people:
            "人物"
        case .all:
            "全部"
        }
    }
}

private extension WallhavenPurityPreset {
    var localizedLabel: String {
        switch self {
        case .sfw:
            "安全"
        case .sfwSketchy:
            "安全+擦边"
        case .all:
            "全部"
        }
    }
}

private extension WallhavenSorting {
    var localizedLabel: String {
        switch self {
        case .dateAdded:
            "最新"
        case .favorites:
            "收藏排行"
        case .random:
            "随机"
        case .relevance:
            "相关度"
        case .toplist:
            "最热"
        case .views:
            "浏览量"
        }
    }
}

private extension WallhavenWallpaper {
    var tagsPreview: String {
        source.isEmpty ? "#\(id)" : source
    }
}
