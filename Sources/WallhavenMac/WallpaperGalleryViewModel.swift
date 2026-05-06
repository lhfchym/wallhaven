import Foundation
import WallhavenCore

@MainActor
final class WallpaperGalleryViewModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var display: DisplayProfile
    @Published private(set) var wallpapers: [WallhavenWallpaper] = []
    @Published var selectedWallpaper: WallhavenWallpaper?
    @Published private(set) var isLoading = false
    @Published private(set) var isDownloading = false
    @Published private(set) var isSettingWallpaper = false
    @Published private(set) var downloadedWallpaperURL: URL?
    @Published private(set) var errorMessage: String?
    @Published private(set) var successMessage: String?
    @Published private(set) var meta: WallhavenMeta?
    @Published private(set) var preferences = WallhavenUserPreferences()

    private let client: WallhavenFetching
    private let fileStore: WallpaperFileStoring
    private let wallpaperSetter: DesktopWallpaperSetting
    private let historyStore: WallpaperHistoryStoring
    private let preferencesStore: WallhavenUserPreferencesStoring
    private var currentPage = 1
    private var currentSeed: String?

    init(
        client: WallhavenFetching = WallhavenClient(),
        fileStore: WallpaperFileStoring = WallpaperFileStore(),
        wallpaperSetter: DesktopWallpaperSetting = DesktopWallpaperSetter(),
        historyStore: WallpaperHistoryStoring = WallpaperHistoryStore(),
        preferencesStore: WallhavenUserPreferencesStoring = WallhavenUserPreferencesStore(),
        display: DisplayProfile = DisplayProfileProvider.current()
    ) {
        self.client = client
        self.fileStore = fileStore
        self.wallpaperSetter = wallpaperSetter
        self.historyStore = historyStore
        self.preferencesStore = preferencesStore
        self.display = display
    }

    var canLoadMore: Bool {
        guard let meta else { return false }
        return meta.currentPage < meta.lastPage
    }

    var statusText: String {
        if let meta {
            return "\(wallpapers.count) of \(meta.total) - \(display.resolutionQuery) - \(display.aspectRatioQuery)"
        }

        return "\(display.resolutionQuery) - \(display.aspectRatioQuery)"
    }

    func refreshDisplay() {
        display = DisplayProfileProvider.current()
    }

    func loadInitialWallpapers() {
        guard wallpapers.isEmpty, !isLoading else { return }

        Task {
            preferences = await preferencesStore.load()
            query = preferences.query
            await load(reset: true)
        }
    }

    func refresh() {
        Task {
            await saveCurrentPreferences()
            await load(reset: true)
        }
    }

    func submitSearch() {
        Task {
            await saveCurrentPreferences()
            await load(reset: true)
        }
    }

    func updateCategory(_ category: WallhavenCategoryPreset) {
        preferences.categories = category
        savePreferencesAndReload()
    }

    func updatePurity(_ purity: WallhavenPurityPreset) {
        preferences.purity = purity
        savePreferencesAndReload()
    }

    func updateSorting(_ sorting: WallhavenSorting) {
        preferences.sorting = sorting
        savePreferencesAndReload()
    }

    func updateAPIKey(_ apiKey: String) {
        preferences.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await preferencesStore.save(preferences)
        }
    }

    func loadNextPage() {
        guard canLoadMore, !isLoading else { return }

        Task {
            await load(reset: false)
        }
    }

    func select(_ wallpaper: WallhavenWallpaper) {
        selectedWallpaper = wallpaper
        downloadedWallpaperURL = nil
        successMessage = nil
        updateCachedDownloadStatus(for: wallpaper)
    }

    func downloadSelectedWallpaper() {
        guard let selectedWallpaper, !isDownloading else { return }

        Task {
            await download(wallpaper: selectedWallpaper)
        }
    }

    func setSelectedWallpaper() {
        guard let selectedWallpaper, !isSettingWallpaper else { return }

        Task {
            await setWallpaper(selectedWallpaper)
        }
    }

    private func load(reset: Bool) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil

        if reset {
            refreshDisplay()
            currentPage = 1
            currentSeed = nil
        } else {
            currentPage += 1
        }

        let request = WallpaperSearchRequest(
            preferences: WallpaperSearchPreferences(
                query: query.trimmingCharacters(in: .whitespacesAndNewlines),
                categories: preferences.categories.categories,
                purity: preferences.purity.purity,
                sorting: preferences.sorting
            ),
            display: display,
            page: currentPage,
            seed: currentSeed
        )

        do {
            let response = try await client.search(request, apiKey: preferences.apiKey)
            let displayWallpapers = await prioritizedWallpapers(from: response.data)
            meta = response.meta
            currentSeed = response.meta.seed

            if reset {
                wallpapers = displayWallpapers
                selectedWallpaper = displayWallpapers.first
                if let selectedWallpaper {
                    downloadedWallpaperURL = await fileStore.cachedURL(for: selectedWallpaper)
                } else {
                    downloadedWallpaperURL = nil
                }
            } else {
                wallpapers.append(contentsOf: displayWallpapers.filter { candidate in
                    !wallpapers.contains(where: { $0.id == candidate.id })
                })
            }

            await historyStore.recordDisplayed(displayWallpapers)
        } catch {
            if !reset {
                currentPage = max(currentPage - 1, 1)
            }
            errorMessage = readableMessage(for: error)
        }

        isLoading = false
    }

    private func download(wallpaper: WallhavenWallpaper) async {
        isDownloading = true
        errorMessage = nil
        successMessage = nil

        do {
            downloadedWallpaperURL = try await fileStore.downloadedURL(for: wallpaper)
            successMessage = "Downloaded #\(wallpaper.id)."
        } catch {
            errorMessage = readableMessage(for: error)
        }

        isDownloading = false
    }

    private func setWallpaper(_ wallpaper: WallhavenWallpaper) async {
        isSettingWallpaper = true
        errorMessage = nil
        successMessage = nil

        do {
            let imageURL: URL
            if let downloadedWallpaperURL {
                imageURL = downloadedWallpaperURL
            } else {
                isDownloading = true
                imageURL = try await fileStore.downloadedURL(for: wallpaper)
                downloadedWallpaperURL = imageURL
                isDownloading = false
            }

            try wallpaperSetter.setDesktopWallpaper(at: imageURL)
            await historyStore.recordSet(wallpaper)
            successMessage = "Set #\(wallpaper.id) as wallpaper."
        } catch {
            isDownloading = false
            errorMessage = readableMessage(for: error)
        }

        isSettingWallpaper = false
    }

    private func prioritizedWallpapers(from candidates: [WallhavenWallpaper]) async -> [WallhavenWallpaper] {
        let recentIDs = await historyStore.recentWallpaperIDs()
        let freshWallpapers = candidates.filter { !recentIDs.contains($0.id) }
        let recentWallpapers = candidates.filter { recentIDs.contains($0.id) }
        return freshWallpapers + recentWallpapers
    }

    private func savePreferencesAndReload() {
        Task {
            await saveCurrentPreferences()
            await load(reset: true)
        }
    }

    private func saveCurrentPreferences() async {
        preferences.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        await preferencesStore.save(preferences)
    }

    private func updateCachedDownloadStatus(for wallpaper: WallhavenWallpaper) {
        Task {
            let cachedURL = await fileStore.cachedURL(for: wallpaper)

            guard selectedWallpaper?.id == wallpaper.id else { return }

            downloadedWallpaperURL = cachedURL
        }
    }

    private func readableMessage(for error: Error) -> String {
        if let clientError = error as? WallhavenClientError {
            switch clientError {
            case .unexpectedResponse:
                return "Unexpected wallhaven response."
            case let .unexpectedStatus(statusCode):
                return "wallhaven returned HTTP \(statusCode)."
            }
        }

        if let fileStoreError = error as? WallpaperFileStoreError {
            switch fileStoreError {
            case .unexpectedResponse:
                return "Unexpected image download response."
            case let .unexpectedStatus(statusCode):
                return "Image download returned HTTP \(statusCode)."
            }
        }

        return error.localizedDescription
    }
}
